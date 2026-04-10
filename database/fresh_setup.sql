-- ============================================================
-- سكريبت إنشاء قاعدة البيانات – نظام وكيل دهانات الحرمين
-- Fresh Setup – الإصدار 2.0
-- مناسب لقاعدة بيانات جديدة فارغة تماماً
-- ============================================================
-- كيفية الاستخدام:
--   1. افتح Supabase Dashboard → SQL Editor
--   2. انسخ هذا الملف بالكامل والصقه في المحرر
--   3. اضغط "Run" لتنفيذ السكريبت
-- ============================================================

-- ==============================
-- الجزء الأول: إنشاء الجداول
-- ==============================

-- جدول العملاء
CREATE TABLE IF NOT EXISTS customers (
  id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name             TEXT NOT NULL UNIQUE,
  phone            TEXT,
  whatsapp         TEXT,
  area             TEXT,
  address          TEXT,
  category         TEXT,
  joining_date     DATE,
  opening_balance  DECIMAL(15,2) DEFAULT 0,
  discount_rate    DECIMAL(5,2)  DEFAULT 0 CHECK (discount_rate >= 0 AND discount_rate <= 100),
  status           TEXT DEFAULT 'active' CHECK (status IN ('active','inactive')),
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- جدول المنتجات
CREATE TABLE IF NOT EXISTS products (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name          TEXT NOT NULL,
  category      TEXT,
  unit          TEXT DEFAULT 'لتر',
  weight        TEXT,
  factory_price DECIMAL(15,2) DEFAULT 0 CHECK (factory_price >= 0),
  agent_price   DECIMAL(15,2) DEFAULT 0 CHECK (agent_price >= 0),
  description   TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- جدول الفواتير
CREATE TABLE IF NOT EXISTS invoices (
  id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  serial           TEXT UNIQUE NOT NULL,
  date             DATE NOT NULL,
  customer_id      UUID REFERENCES customers(id) ON DELETE SET NULL,
  customer_name    TEXT,
  sales_rep        TEXT,
  gross_amount     DECIMAL(15,2) DEFAULT 0,
  discount_amount  DECIMAL(15,2) DEFAULT 0,
  net_amount       DECIMAL(15,2) DEFAULT 0,
  factory_amount   DECIMAL(15,2) DEFAULT 0,
  notes            TEXT,
  created_by       TEXT,
  edited_by        TEXT,
  edited_at        TIMESTAMPTZ,
  status           TEXT DEFAULT 'active' CHECK (status IN ('active','cancelled')),
  delivery_status  TEXT DEFAULT 'delivered' CHECK (delivery_status IN ('delivered','in_progress')),
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- جدول بنود الفواتير
CREATE TABLE IF NOT EXISTS invoice_items (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  invoice_id    UUID REFERENCES invoices(id) ON DELETE CASCADE,
  product_id    UUID REFERENCES products(id) ON DELETE SET NULL,
  product_name  TEXT,
  unit          TEXT,
  qty           DECIMAL(10,3) DEFAULT 0,
  unit_price    DECIMAL(15,2) DEFAULT 0,
  factory_price DECIMAL(15,2) DEFAULT 0,
  discount      DECIMAL(5,2)  DEFAULT 0,
  total         DECIMAL(15,2) DEFAULT 0,
  color         TEXT,
  note          TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- جدول التحصيلات
CREATE TABLE IF NOT EXISTS collections (
  id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  date           DATE NOT NULL,
  customer_id    UUID REFERENCES customers(id) ON DELETE SET NULL,
  customer_name  TEXT,
  invoice_serial TEXT,
  amount         DECIMAL(15,2) NOT NULL CHECK (amount > 0),
  method         TEXT DEFAULT 'cash',
  employee       TEXT,
  notes          TEXT,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- جدول المحفظة الإلكترونية (فودافون كاش)
CREATE TABLE IF NOT EXISTS wallet_ledger (
  id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  date           DATE NOT NULL,
  direction      TEXT NOT NULL CHECK (direction IN ('in','out')),
  category       TEXT,
  counterparty   TEXT,
  invoice_serial TEXT,
  amount         DECIMAL(15,2) NOT NULL CHECK (amount > 0),
  method         TEXT,
  balance        DECIMAL(15,2) DEFAULT 0,
  notes          TEXT,
  source_id      TEXT,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- جدول دفعات المصنع
CREATE TABLE IF NOT EXISTS factory_payments (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  date       DATE NOT NULL,
  amount     DECIMAL(15,2) NOT NULL CHECK (amount > 0),
  method     TEXT DEFAULT 'bank',
  notes      TEXT,
  reference  TEXT,
  source_id  TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- جدول صادر المكتب (المصروفات)
CREATE TABLE IF NOT EXISTS office_payments (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  date       DATE NOT NULL,
  amount     DECIMAL(15,2) NOT NULL CHECK (amount > 0),
  category   TEXT,
  method     TEXT DEFAULT 'cash',
  notes      TEXT,
  reference  TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- جدول وارد المكتب
CREATE TABLE IF NOT EXISTS office_incoming (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  date       DATE NOT NULL,
  amount     DECIMAL(15,2) NOT NULL CHECK (amount > 0),
  category   TEXT,
  method     TEXT DEFAULT 'cash',
  notes      TEXT,
  reference  TEXT,
  source_id  TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- جدول مديونيات معدومة (تصفية حسابات)
CREATE TABLE IF NOT EXISTS writeoffs (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  date          DATE NOT NULL,
  customer_id   UUID REFERENCES customers(id) ON DELETE SET NULL,
  customer_name TEXT,
  amount        DECIMAL(15,2) NOT NULL,
  notes         TEXT,
  created_by    TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- جدول الفروع
CREATE TABLE IF NOT EXISTS branches (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name       TEXT NOT NULL,
  location   TEXT,
  manager    TEXT,
  status     TEXT DEFAULT 'active' CHECK (status IN ('active','inactive')),
  notes      TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- جدول المستخدمين
CREATE TABLE IF NOT EXISTS users (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  email        TEXT UNIQUE NOT NULL,
  name         TEXT,
  role         TEXT DEFAULT 'sales',
  status       TEXT DEFAULT 'active' CHECK (status IN ('active','inactive')),
  custom_perms JSONB,
  custom_pages JSONB,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- جدول الأدوار
CREATE TABLE IF NOT EXISTS roles (
  id         SERIAL PRIMARY KEY,
  name       TEXT UNIQUE NOT NULL,
  label      TEXT NOT NULL,
  protected  BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- جدول صلاحيات الأدوار
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

-- جدول إعدادات التطبيق
CREATE TABLE IF NOT EXISTS app_settings (
  id         TEXT PRIMARY KEY DEFAULT 'main',
  data       JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- جدول سجل الحركات
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

-- ==============================
-- الجزء الثاني: الفهارس
-- ==============================

CREATE INDEX IF NOT EXISTS idx_invoices_customer      ON invoices(customer_id);
CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice  ON invoice_items(invoice_id);
CREATE INDEX IF NOT EXISTS idx_collections_customer   ON collections(customer_id);
CREATE INDEX IF NOT EXISTS idx_wallet_ledger_date     ON wallet_ledger(date);
CREATE INDEX IF NOT EXISTS idx_users_email            ON users(email);
CREATE INDEX IF NOT EXISTS idx_activity_log_timestamp ON activity_log(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_writeoffs_customer     ON writeoffs(customer_id);
CREATE INDEX IF NOT EXISTS idx_branches_name          ON branches(name);

-- ==============================
-- الجزء الثالث: Row Level Security
-- ==============================

ALTER TABLE customers        ENABLE ROW LEVEL SECURITY;
ALTER TABLE products         ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices         ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_items    ENABLE ROW LEVEL SECURITY;
ALTER TABLE collections      ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_ledger    ENABLE ROW LEVEL SECURITY;
ALTER TABLE factory_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_payments  ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_incoming  ENABLE ROW LEVEL SECURITY;
ALTER TABLE writeoffs        ENABLE ROW LEVEL SECURITY;
ALTER TABLE users            ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles            ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_settings     ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_log     ENABLE ROW LEVEL SECURITY;
ALTER TABLE branches         ENABLE ROW LEVEL SECURITY;

-- REPLICA IDENTITY FULL مطلوب لكي يعمل Supabase Realtime مع RLS
ALTER TABLE customers        REPLICA IDENTITY FULL;
ALTER TABLE products         REPLICA IDENTITY FULL;
ALTER TABLE invoices         REPLICA IDENTITY FULL;
ALTER TABLE invoice_items    REPLICA IDENTITY FULL;
ALTER TABLE collections      REPLICA IDENTITY FULL;
ALTER TABLE wallet_ledger    REPLICA IDENTITY FULL;
ALTER TABLE factory_payments REPLICA IDENTITY FULL;
ALTER TABLE office_payments  REPLICA IDENTITY FULL;
ALTER TABLE office_incoming  REPLICA IDENTITY FULL;
ALTER TABLE writeoffs        REPLICA IDENTITY FULL;
ALTER TABLE users            REPLICA IDENTITY FULL;
ALTER TABLE roles            REPLICA IDENTITY FULL;
ALTER TABLE role_permissions REPLICA IDENTITY FULL;
ALTER TABLE app_settings     REPLICA IDENTITY FULL;
ALTER TABLE activity_log     REPLICA IDENTITY FULL;
ALTER TABLE branches         REPLICA IDENTITY FULL;

-- سياسات الوصول للجداول العامة (جميع المستخدمين المصادق عليهم)
DROP POLICY IF EXISTS "authenticated_full_access" ON customers;
CREATE POLICY "authenticated_full_access" ON customers        FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "authenticated_full_access" ON products;
CREATE POLICY "authenticated_full_access" ON products         FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "authenticated_full_access" ON invoices;
CREATE POLICY "authenticated_full_access" ON invoices         FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "authenticated_full_access" ON invoice_items;
CREATE POLICY "authenticated_full_access" ON invoice_items    FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "authenticated_full_access" ON collections;
CREATE POLICY "authenticated_full_access" ON collections      FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "authenticated_full_access" ON wallet_ledger;
CREATE POLICY "authenticated_full_access" ON wallet_ledger    FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "authenticated_full_access" ON factory_payments;
CREATE POLICY "authenticated_full_access" ON factory_payments FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "authenticated_full_access" ON office_payments;
CREATE POLICY "authenticated_full_access" ON office_payments  FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "authenticated_full_access" ON office_incoming;
CREATE POLICY "authenticated_full_access" ON office_incoming  FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "authenticated_full_access" ON writeoffs;
CREATE POLICY "authenticated_full_access" ON writeoffs        FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "authenticated_full_access" ON branches;
CREATE POLICY "authenticated_full_access" ON branches         FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- سياسة جدول users
DROP POLICY IF EXISTS "authenticated_full_access" ON users;
DROP POLICY IF EXISTS "users_read_policy"          ON users;
DROP POLICY IF EXISTS "users_write_policy"         ON users;
CREATE POLICY "users_read_policy"  ON users FOR SELECT TO authenticated USING (true);
CREATE POLICY "users_write_policy" ON users FOR ALL    TO authenticated USING (true) WITH CHECK (true);

-- سياسة الأدوار
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

-- سياسة سجل الحركات
DROP POLICY IF EXISTS "authenticated_full_access" ON activity_log;
CREATE POLICY "authenticated_full_access" ON activity_log FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ==============================
-- الجزء الرابع: التريجرات
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
-- الجزء الخامس: بيانات الأدوار الأساسية
-- ==============================

INSERT INTO roles (name, label, protected) VALUES
  ('admin',    'مدير النظام', TRUE),
  ('manager',  'مدير عام',   TRUE),
  ('sales',    'مبيعات',     TRUE),
  ('collector','حسابات',     TRUE)
ON CONFLICT (name) DO UPDATE SET label = EXCLUDED.label, protected = TRUE;

-- ==============================
-- الجزء الخامس (أ): صلاحيات الأدوار
-- ==============================

DELETE FROM role_permissions WHERE role_name NOT IN (SELECT name FROM roles);

-- مدير النظام: صلاحيات كاملة
INSERT INTO role_permissions (role_name, page, can_view, can_add, can_edit, can_delete) VALUES
  ('admin', 'dashboard',       TRUE,  FALSE, FALSE, FALSE),
  ('admin', 'customers',       TRUE,  TRUE,  TRUE,  TRUE),
  ('admin', 'products',        TRUE,  TRUE,  TRUE,  TRUE),
  ('admin', 'invoices',        TRUE,  TRUE,  TRUE,  TRUE),
  ('admin', 'collections',     TRUE,  TRUE,  TRUE,  TRUE),
  ('admin', 'wallet',          TRUE,  TRUE,  FALSE, TRUE),
  ('admin', 'factoryPayments', TRUE,  TRUE,  TRUE,  TRUE),
  ('admin', 'officeIncoming',  TRUE,  TRUE,  TRUE,  TRUE),
  ('admin', 'officeOutgoing',  TRUE,  TRUE,  TRUE,  TRUE),
  ('admin', 'profits',         TRUE,  FALSE, FALSE, FALSE),
  ('admin', 'reports',         TRUE,  FALSE, FALSE, FALSE),
  ('admin', 'activityLog',     TRUE,  FALSE, FALSE, FALSE),
  ('admin', 'employeeReport',  TRUE,  FALSE, FALSE, FALSE),
  ('admin', 'orderTracking',   TRUE,  FALSE, TRUE,  FALSE),
  ('admin', 'writeoffs',       TRUE,  TRUE,  FALSE, TRUE),
  ('admin', 'settings',        TRUE,  FALSE, FALSE, FALSE)
ON CONFLICT (role_name, page) DO UPDATE SET
  can_view   = EXCLUDED.can_view,
  can_add    = EXCLUDED.can_add,
  can_edit   = EXCLUDED.can_edit,
  can_delete = EXCLUDED.can_delete;

-- مدير عام
INSERT INTO role_permissions (role_name, page, can_view, can_add, can_edit, can_delete) VALUES
  ('manager', 'dashboard',       TRUE,  FALSE, FALSE, FALSE),
  ('manager', 'customers',       TRUE,  TRUE,  TRUE,  FALSE),
  ('manager', 'products',        TRUE,  FALSE, FALSE, FALSE),
  ('manager', 'invoices',        TRUE,  TRUE,  TRUE,  FALSE),
  ('manager', 'collections',     TRUE,  TRUE,  TRUE,  FALSE),
  ('manager', 'wallet',          TRUE,  TRUE,  FALSE, FALSE),
  ('manager', 'factoryPayments', TRUE,  TRUE,  TRUE,  FALSE),
  ('manager', 'officeIncoming',  TRUE,  TRUE,  TRUE,  FALSE),
  ('manager', 'officeOutgoing',  TRUE,  TRUE,  TRUE,  FALSE),
  ('manager', 'profits',         TRUE,  FALSE, FALSE, FALSE),
  ('manager', 'reports',         TRUE,  FALSE, FALSE, FALSE),
  ('manager', 'employeeReport',  TRUE,  FALSE, FALSE, FALSE),
  ('manager', 'orderTracking',   TRUE,  FALSE, TRUE,  FALSE),
  ('manager', 'writeoffs',       TRUE,  TRUE,  FALSE, FALSE),
  ('manager', 'settings',        TRUE,  FALSE, FALSE, FALSE)
ON CONFLICT (role_name, page) DO UPDATE SET
  can_view   = EXCLUDED.can_view,
  can_add    = EXCLUDED.can_add,
  can_edit   = EXCLUDED.can_edit,
  can_delete = EXCLUDED.can_delete;

-- مبيعات
INSERT INTO role_permissions (role_name, page, can_view, can_add, can_edit, can_delete) VALUES
  ('sales', 'dashboard',   TRUE,  FALSE, FALSE, FALSE),
  ('sales', 'customers',   TRUE,  TRUE,  TRUE,  FALSE),
  ('sales', 'products',    TRUE,  FALSE, FALSE, FALSE),
  ('sales', 'invoices',    TRUE,  TRUE,  TRUE,  FALSE),
  ('sales', 'collections', TRUE,  TRUE,  FALSE, FALSE)
ON CONFLICT (role_name, page) DO UPDATE SET
  can_view   = EXCLUDED.can_view,
  can_add    = EXCLUDED.can_add,
  can_edit   = EXCLUDED.can_edit,
  can_delete = EXCLUDED.can_delete;

-- حسابات
INSERT INTO role_permissions (role_name, page, can_view, can_add, can_edit, can_delete) VALUES
  ('collector', 'dashboard',      TRUE,  FALSE, FALSE, FALSE),
  ('collector', 'customers',      TRUE,  FALSE, FALSE, FALSE),
  ('collector', 'collections',    TRUE,  TRUE,  FALSE, FALSE),
  ('collector', 'officeIncoming', TRUE,  TRUE,  FALSE, FALSE),
  ('collector', 'wallet',         TRUE,  FALSE, FALSE, FALSE)
ON CONFLICT (role_name, page) DO UPDATE SET
  can_view   = EXCLUDED.can_view,
  can_add    = EXCLUDED.can_add,
  can_edit   = EXCLUDED.can_edit,
  can_delete = EXCLUDED.can_delete;

-- ==============================
-- الجزء السادس: إنشاء مستخدم المدير الأول
-- ==============================
-- ملاحظة مهمة:
--   قبل تشغيل هذا الجزء، أنشئ المستخدم أولاً في:
--   Supabase Dashboard → Authentication → Users → Add user
--   ثم انسخ الـ UUID الخاص به واستبدله هنا.
--
--   البديل: أدخل البيانات من خلال التطبيق مباشرةً بعد تسجيل الدخول.
-- ============================================================
-- مثال (استبدل UUID بالقيمة الحقيقية من Supabase Auth):
-- INSERT INTO users (id, email, name, role, status) VALUES
--   ('<UUID-من-Supabase-Auth>', 'admin@yourcompany.com', 'مدير النظام', 'admin', 'active')
-- ON CONFLICT (email) DO NOTHING;

-- ============================================================
-- انتهى السكريبت – القاعدة جاهزة للاستخدام
-- ============================================================
