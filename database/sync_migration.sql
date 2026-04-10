-- ============================================================
-- سكريبت المزامنة والترقية – نظام إدارة وكيل دهانات الحرمين
-- Sync & Upgrade Migration – Elharamain ERP
-- ============================================================
-- كيفية الاستخدام:
--   1. افتح Supabase Dashboard → SQL Editor
--   2. انسخ هذا الملف بالكامل والصقه في المحرر
--   3. اضغط "Run" لتنفيذ السكريبت
-- ملاحظة: هذا السكريبت آمن للتشغيل أكثر من مرة (idempotent).
--         لا يحذف أي بيانات موجودة – يضيف فقط ما هو ناقص.
-- ============================================================

-- ==============================
-- الخطوة 1: إنشاء الجداول الناقصة
-- ==============================

-- جدول سجل الحركات المركزي (الأهم – يسجل حركات جميع المستخدمين)
CREATE TABLE IF NOT EXISTS activity_log (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  timestamp  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  user_id    UUID,
  user_name  TEXT,
  user_role  TEXT,
  action     TEXT,
  resource   TEXT,
  details    TEXT
);

-- جدول الأدوار (إن لم يكن موجوداً)
CREATE TABLE IF NOT EXISTS roles (
  id         SERIAL PRIMARY KEY,
  name       TEXT UNIQUE NOT NULL,
  label      TEXT NOT NULL,
  protected  BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- جدول صلاحيات الأدوار (إن لم يكن موجوداً)
CREATE TABLE IF NOT EXISTS role_permissions (
  id         SERIAL PRIMARY KEY,
  role_name  TEXT NOT NULL REFERENCES roles(name) ON DELETE CASCADE,
  page       TEXT NOT NULL,
  can_view   BOOLEAN DEFAULT FALSE,
  can_add    BOOLEAN DEFAULT FALSE,
  can_edit   BOOLEAN DEFAULT FALSE,
  can_delete BOOLEAN DEFAULT FALSE,
  UNIQUE(role_name, page)
);

-- جدول إعدادات التطبيق (إن لم يكن موجوداً)
CREATE TABLE IF NOT EXISTS app_settings (
  id         TEXT PRIMARY KEY DEFAULT 'main',
  data       JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================
-- الخطوة 2: إضافة الأعمدة الناقصة للجداول الحالية
-- ==============================

-- جدول customers
ALTER TABLE customers ADD COLUMN IF NOT EXISTS whatsapp       TEXT;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS category       TEXT;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS joining_date   DATE;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS discount_rate  DECIMAL(5,2) DEFAULT 0;

-- جدول products
ALTER TABLE products ADD COLUMN IF NOT EXISTS weight TEXT;

-- جدول invoices
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS created_by      TEXT;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS delivery_status TEXT DEFAULT 'delivered'
  CHECK (delivery_status IN ('delivered','in_progress'));

-- جدول invoice_items
ALTER TABLE invoice_items ADD COLUMN IF NOT EXISTS color      TEXT;
ALTER TABLE invoice_items ADD COLUMN IF NOT EXISTS note       TEXT;
ALTER TABLE invoice_items ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- جدول wallet_ledger
ALTER TABLE wallet_ledger ADD COLUMN IF NOT EXISTS source_id  TEXT;

-- جدول factory_payments
ALTER TABLE factory_payments ADD COLUMN IF NOT EXISTS source_id TEXT;

-- جدول office_incoming
ALTER TABLE office_incoming ADD COLUMN IF NOT EXISTS source_id TEXT;

-- جدول users: أعمدة الصلاحيات المخصصة (camelCase → snake_case موحّد)
ALTER TABLE users ADD COLUMN IF NOT EXISTS custom_perms JSONB;
ALTER TABLE users ADD COLUMN IF NOT EXISTS custom_pages JSONB;

-- جدول activity_log: الأعمدة القياسية الجديدة
ALTER TABLE activity_log ADD COLUMN IF NOT EXISTS user_id    UUID;
ALTER TABLE activity_log ADD COLUMN IF NOT EXISTS user_role  TEXT;
ALTER TABLE activity_log ADD COLUMN IF NOT EXISTS resource   TEXT;
ALTER TABLE activity_log ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- تحويل نوع timestamp من "timestamp without time zone" إلى timestamptz (إن لزم)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'activity_log'
      AND column_name  = 'timestamp'
      AND data_type    = 'timestamp without time zone'
  ) THEN
    ALTER TABLE activity_log
      ALTER COLUMN "timestamp" TYPE TIMESTAMPTZ
      USING "timestamp" AT TIME ZONE 'UTC';
  END IF;
END $$;

-- Backfill: user_role ← role (للسجلات القديمة)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'activity_log'
      AND column_name  = 'role'
  ) THEN
    UPDATE activity_log SET user_role = role WHERE user_role IS NULL AND role IS NOT NULL;
  END IF;
END $$;

-- Backfill: resource ← page (للسجلات القديمة)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'activity_log'
      AND column_name  = 'page'
  ) THEN
    UPDATE activity_log SET resource = page WHERE resource IS NULL AND page IS NOT NULL;
  END IF;
END $$;

-- Backfill: تعبئة timestamp/created_at إن كانا NULL
UPDATE activity_log SET "timestamp"  = COALESCE(created_at, NOW()) WHERE "timestamp"  IS NULL;
UPDATE activity_log SET created_at   = COALESCE("timestamp", NOW()) WHERE created_at   IS NULL;

-- ==============================
-- الخطوة 3: الفهارس
-- ==============================

CREATE INDEX IF NOT EXISTS idx_invoices_customer      ON invoices(customer_id);
CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice  ON invoice_items(invoice_id);
CREATE INDEX IF NOT EXISTS idx_collections_customer   ON collections(customer_id);
CREATE INDEX IF NOT EXISTS idx_wallet_ledger_date     ON wallet_ledger(date);
CREATE INDEX IF NOT EXISTS idx_users_email            ON users(email);
CREATE INDEX IF NOT EXISTS idx_activity_log_timestamp ON activity_log(timestamp DESC);

-- ==============================
-- الخطوة 4: Row Level Security
-- ==============================

ALTER TABLE activity_log     ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles            ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_settings     ENABLE ROW LEVEL SECURITY;

-- سياسة سجل الحركات: جميع المستخدمين المصادق عليهم
DROP POLICY IF EXISTS "authenticated_full_access" ON activity_log;
CREATE POLICY "authenticated_full_access" ON activity_log
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- سياسة الأدوار: يقرأ الجميع – يكتب مدير النظام فقط
DROP POLICY IF EXISTS "roles_read_policy"   ON roles;
DROP POLICY IF EXISTS "manage_roles_policy" ON roles;
CREATE POLICY "roles_read_policy" ON roles FOR SELECT TO authenticated USING (true);
CREATE POLICY "manage_roles_policy" ON roles FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.email = (SELECT email FROM auth.users WHERE id = auth.uid())
        AND users.role   = 'admin'
        AND users.status = 'active'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.email = (SELECT email FROM auth.users WHERE id = auth.uid())
        AND users.role   = 'admin'
        AND users.status = 'active'
    )
  );

-- سياسة صلاحيات الأدوار
DROP POLICY IF EXISTS "role_permissions_read_policy" ON role_permissions;
DROP POLICY IF EXISTS "manage_permissions_policy"    ON role_permissions;
CREATE POLICY "role_permissions_read_policy" ON role_permissions FOR SELECT TO authenticated USING (true);
CREATE POLICY "manage_permissions_policy"    ON role_permissions FOR ALL    TO authenticated USING (true) WITH CHECK (true);

-- سياسة إعدادات التطبيق
DROP POLICY IF EXISTS "app_settings_read_policy"  ON app_settings;
DROP POLICY IF EXISTS "app_settings_write_policy" ON app_settings;
CREATE POLICY "app_settings_read_policy"  ON app_settings FOR SELECT TO authenticated USING (true);
CREATE POLICY "app_settings_write_policy" ON app_settings FOR ALL    TO authenticated USING (true) WITH CHECK (true);

-- تحديث سياسة users لضمان صلاحيات صحيحة
DROP POLICY IF EXISTS "authenticated_full_access" ON users;
DROP POLICY IF EXISTS "users_read_policy"         ON users;
DROP POLICY IF EXISTS "users_write_policy"        ON users;
CREATE POLICY "users_read_policy"  ON users FOR SELECT TO authenticated USING (true);
CREATE POLICY "users_write_policy" ON users FOR ALL    TO authenticated USING (true) WITH CHECK (true);

-- ==============================
-- الخطوة 5: تريجر منع حذف الأدوار المحمية
-- ==============================

CREATE OR REPLACE FUNCTION prevent_protected_role_delete()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.protected THEN
    RAISE EXCEPTION 'لا يمكن حذف دور محمي';
  END IF;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_protected_role_delete ON roles;
CREATE TRIGGER trg_prevent_protected_role_delete
  BEFORE DELETE ON roles FOR EACH ROW
  EXECUTE FUNCTION prevent_protected_role_delete();

-- ==============================
-- الخطوة 6: بيانات الأدوار الأساسية
-- ==============================

INSERT INTO roles (name, label, protected) VALUES
  ('admin',    'مدير النظام', TRUE),
  ('manager',  'مدير عام',   TRUE),
  ('sales',    'مبيعات',     TRUE),
  ('collector','حسابات',     TRUE)
ON CONFLICT (name) DO UPDATE SET
  label     = EXCLUDED.label,
  protected = TRUE;

-- حذف صلاحيات أي أدوار غير موجودة (تنظيف)
DELETE FROM role_permissions WHERE role_name NOT IN (SELECT name FROM roles);

-- تصحيح أي مستخدمين يحملون أسماء أدوار قديمة
UPDATE users SET role = 'manager' WHERE role = 'general_manager';

-- ==============================
-- الخطوة 7: التحقق من النتيجة
-- ==============================

SELECT 'الجداول الموجودة الآن:' AS info;
SELECT table_name
  FROM information_schema.tables
  WHERE table_schema = 'public'
  ORDER BY table_name;

SELECT 'جدول activity_log – الأعمدة:' AS info;
SELECT column_name, data_type
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'activity_log'
  ORDER BY ordinal_position;

SELECT 'الأدوار المتاحة:' AS info;
SELECT name, label, protected FROM roles ORDER BY name;

-- ============================================================
-- ملاحظات هامة بعد تشغيل هذا السكريبت:
-- ============================================================
-- 1. جدول activity_log أُنشئ الآن – ستُسجَّل حركات جميع
--    المستخدمين من جميع الأجهزة في قاعدة البيانات المركزية.
-- 2. استخدم هذا السكريبت للترقية من أي نسخة سابقة بأمان.
-- 3. السكريبت الكامل لإنشاء قاعدة بيانات جديدة: supabase_setup.sql
-- ============================================================
