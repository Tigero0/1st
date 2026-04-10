-- ============================================================
-- سكريبت إنشاء قاعدة البيانات – نظام وكيل دهانات الحرمين
-- الإصدار: 3.0 (الملف الموحّد)
-- ============================================================
-- كيفية الاستخدام:
--   1. افتح Supabase Dashboard → SQL Editor
--   2. انسخ هذا الملف بالكامل والصقه في المحرر
--   3. اضغط "Run" لتنفيذ السكريبت
-- ملاحظة: هذا السكريبت آمن للتشغيل أكثر من مرة (idempotent).
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

-- جدول صلاحيات الأدوار (الصفحات)
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

-- جدول سجل الحركات المركزي
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
-- الجزء الخامس (أ): صلاحيات الأدوار على الصفحات
-- ==============================

-- حذف صلاحيات أي أدوار محذوفة
DELETE FROM role_permissions WHERE role_name NOT IN (SELECT name FROM roles);

-- مدير النظام: صلاحيات كاملة على جميع الصفحات
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

-- مدير عام: صلاحيات واسعة بدون حذف
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

-- مبيعات: صلاحيات محدودة
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

-- حسابات: صلاحيات التحصيل والمحفظة
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

-- تصحيح أي مستخدمين يحملون الدور القديم general_manager
UPDATE users SET role = 'manager' WHERE role = 'general_manager';

-- ==============================
-- الجزء السادس: بيانات تجريبية
-- ==============================

-- ---- 6.1 المستخدمون ----
-- ملاحظة: كلمات المرور يجب إدخالها عبر Supabase Authentication → Users
INSERT INTO users (id, email, name, role, status) VALUES
  ('a1b2c3d4-0001-0001-0001-000000000001', 'admin@haramain.com',   'مدير النظام',  'admin',     'active'),
  ('a1b2c3d4-0005-0005-0005-000000000005', 'manager@haramain.com', 'المدير العام', 'manager',   'active'),
  ('a1b2c3d4-0002-0002-0002-000000000002', 'ahmed@haramain.com',   'أحمد المندوب', 'sales',     'active'),
  ('a1b2c3d4-0003-0003-0003-000000000003', 'mahmoud@haramain.com', 'محمود السيد',  'sales',     'active'),
  ('a1b2c3d4-0004-0004-0004-000000000004', 'khaled@haramain.com',  'خالد المحصل',  'collector', 'active')
ON CONFLICT (email) DO NOTHING;

-- ---- 6.2 العملاء ----
INSERT INTO customers (id, name, phone, whatsapp, area, address, opening_balance, discount_rate, status, created_at) VALUES
  ('c1000001-0000-0000-0000-000000000001', 'مقاولات النيل',          '01001234567', '01001234567', 'القاهرة',     'مدينة نصر',       5000.00, 5.00,  'active',   '2025-01-01 00:00:00+00'),
  ('c1000001-0000-0000-0000-000000000002', 'محمد أحمد للمقاولات',   '01112345678', '01112345678', 'الجيزة',      'الهرم',            0.00,    0.00,  'active',   '2025-01-01 00:00:00+00'),
  ('c1000001-0000-0000-0000-000000000003', 'شركة البناء الحديث',    '01223456789', NULL,          'الإسكندرية', 'المنتزه',         12000.00, 10.00, 'active',   '2025-01-01 00:00:00+00'),
  ('c1000001-0000-0000-0000-000000000004', 'مؤسسة الإعمار',         '01534567890', '01534567890', 'القاهرة',     'التجمع الخامس',    0.00,    0.00,  'active',   '2025-01-01 00:00:00+00'),
  ('c1000001-0000-0000-0000-000000000005', 'علي حسن للدهانات',      '01045678901', '01045678901', 'الجيزة',      '6 أكتوبر',        3500.00,  8.00,  'active',   '2025-01-01 00:00:00+00'),
  ('c1000001-0000-0000-0000-000000000006', 'مشروع أبراج النيل',     '01156789012', NULL,          'القاهرة',     'كورنيش النيل',     0.00,    0.00,  'inactive', '2025-01-01 00:00:00+00'),
  ('c1000001-0000-0000-0000-000000000007', 'مقاولات الدلتا',        '01267890123', '01267890123', 'المنصورة',    'شارع الجمهورية', 7800.00,  5.00,  'active',   '2025-01-01 00:00:00+00'),
  ('c1000001-0000-0000-0000-000000000008', 'أحمد فؤاد للبناء',      '01378901234', '01378901234', 'أسيوط',       'وسط البلد',        0.00,    0.00,  'active',   '2025-01-01 00:00:00+00'),
  ('c1000001-0000-0000-0000-000000000009', 'شركة النور للمقاولات',  '01489012345', NULL,          'طنطا',        'شارع البحر',      2200.00,  3.00,  'active',   '2025-02-01 00:00:00+00'),
  ('c1000001-0000-0000-0000-000000000010', 'مصطفى كمال للدهانات',   '01590123456', '01590123456', 'الإسماعيلية','حي الفردان',        0.00,    0.00,  'active',   '2025-02-01 00:00:00+00')
ON CONFLICT (name) DO NOTHING;

-- ---- 6.3 المنتجات ----
INSERT INTO products (id, name, category, unit, factory_price, agent_price, description, created_at) VALUES
  ('d1000001-0000-0000-0000-000000000001', 'دهان خارجي ممتاز',  'خارجي',  'لتر',  45.00,  55.00, 'دهان خارجي مقاوم للعوامل الجوية – جودة ممتازة', '2025-01-01 00:00:00+00'),
  ('d1000001-0000-0000-0000-000000000002', 'دهان خارجي عادي',   'خارجي',  'لتر',  30.00,  38.00, 'دهان خارجي اقتصادي للاستخدام العام',            '2025-01-01 00:00:00+00'),
  ('d1000001-0000-0000-0000-000000000003', 'دهان داخلي ممتاز',  'داخلي',  'لتر',  35.00,  43.00, 'دهان داخلي ناعم مقاوم للرطوبة',                 '2025-01-01 00:00:00+00'),
  ('d1000001-0000-0000-0000-000000000004', 'دهان داخلي عادي',   'داخلي',  'لتر',  22.00,  28.00, 'دهان داخلي اقتصادي',                             '2025-01-01 00:00:00+00'),
  ('d1000001-0000-0000-0000-000000000005', 'بوية زيتية أبيض',   'زيتي',   'كجم',  60.00,  75.00, 'بوية زيتية ناعمة للأسطح المعدنية والخشب',       '2025-01-01 00:00:00+00'),
  ('d1000001-0000-0000-0000-000000000006', 'بلاستيك ملون',       'ملون',   'لتر',  40.00,  50.00, 'بلاستيك مائي بألوان متعددة',                     '2025-01-01 00:00:00+00'),
  ('d1000001-0000-0000-0000-000000000007', 'ديكوري تكسير',       'ديكوري', 'كجم',  85.00, 105.00, 'دهان ديكوري بتأثير التكسير للواجهات',           '2025-01-01 00:00:00+00'),
  ('d1000001-0000-0000-0000-000000000008', 'برايمر',             'أساس',   'لتر',  18.00,  24.00, 'طبقة أساس لجميع أنواع الدهانات',                 '2025-01-01 00:00:00+00'),
  ('d1000001-0000-0000-0000-000000000009', 'انشائي واجهات',      'انشائي', 'كجم',  20.00,  26.00, 'دهان انشائي للواجهات الخارجية',                 '2025-01-01 00:00:00+00'),
  ('d1000001-0000-0000-0000-000000000010', 'مينا بلاستيك',       'داخلي',  'لتر',  48.00,  60.00, 'مينا بلاستيك فاخرة للأسطح الداخلية',            '2025-01-01 00:00:00+00'),
  ('d1000001-0000-0000-0000-000000000011', 'طلاء مائي أبيض',     'داخلي',  'لتر',  25.00,  32.00, 'طلاء أبيض ناصع للجدران الداخلية',               '2025-01-01 00:00:00+00'),
  ('d1000001-0000-0000-0000-000000000012', 'دهان مضاد للصدأ',    'خارجي',  'لتر',  55.00,  68.00, 'دهان حماية من الصدأ للأسطح المعدنية',           '2025-01-01 00:00:00+00')
ON CONFLICT DO NOTHING;

-- ---- 6.4 الفواتير وبنودها ----

INSERT INTO invoices (id, serial, date, customer_id, customer_name, sales_rep, gross_amount, discount_amount, net_amount, factory_amount, notes, created_by, status, created_at) VALUES
  ('e1000001-0000-0000-0000-000000000001', 'INV-20250110-0001', '2025-01-10', 'c1000001-0000-0000-0000-000000000001', 'مقاولات النيل',          'أحمد المندوب', 3850.00,  192.50, 3657.50, 3150.00, '',                    'أحمد المندوب', 'active',    '2025-01-10 09:00:00+00'),
  ('e1000001-0000-0000-0000-000000000002', 'INV-20250115-0002', '2025-01-15', 'c1000001-0000-0000-0000-000000000002', 'محمد أحمد للمقاولات',   'محمود السيد',  4760.00,    0.00, 4760.00, 3920.00, '',                    'محمود السيد',  'active',    '2025-01-15 10:30:00+00'),
  ('e1000001-0000-0000-0000-000000000003', 'INV-20250120-0003', '2025-01-20', 'c1000001-0000-0000-0000-000000000003', 'شركة البناء الحديث',    'أحمد المندوب', 7875.00,  787.50, 7087.50, 6375.00, 'عميل VIP خصم 10%',   'أحمد المندوب', 'active',    '2025-01-20 11:00:00+00'),
  ('e1000001-0000-0000-0000-000000000004', 'INV-20250201-0004', '2025-02-01', 'c1000001-0000-0000-0000-000000000004', 'مؤسسة الإعمار',         'محمود السيد',  2700.00,    0.00, 2700.00, 2200.00, '',                    'محمود السيد',  'active',    '2025-02-01 09:30:00+00'),
  ('e1000001-0000-0000-0000-000000000005', 'INV-20250210-0005', '2025-02-10', 'c1000001-0000-0000-0000-000000000005', 'علي حسن للدهانات',      'أحمد المندوب', 5040.00,  403.20, 4636.80, 4200.00, '',                    'أحمد المندوب', 'active',    '2025-02-10 10:00:00+00'),
  ('e1000001-0000-0000-0000-000000000006', 'INV-20250218-0006', '2025-02-18', 'c1000001-0000-0000-0000-000000000007', 'مقاولات الدلتا',        'محمود السيد',  3420.00,    0.00, 3420.00, 2800.00, '',                    'محمود السيد',  'active',    '2025-02-18 08:00:00+00'),
  ('e1000001-0000-0000-0000-000000000007', 'INV-20250301-0007', '2025-03-01', 'c1000001-0000-0000-0000-000000000001', 'مقاولات النيل',          'أحمد المندوب', 6600.00,  330.00, 6270.00, 5400.00, 'طلبية كبيرة',        'أحمد المندوب', 'active',    '2025-03-01 09:00:00+00'),
  ('e1000001-0000-0000-0000-000000000008', 'INV-20250308-0008', '2025-03-08', 'c1000001-0000-0000-0000-000000000008', 'أحمد فؤاد للبناء',      'محمود السيد',  2250.00,    0.00, 2250.00, 1800.00, '',                    'محمود السيد',  'active',    '2025-03-08 11:00:00+00'),
  ('e1000001-0000-0000-0000-000000000009', 'INV-20250315-0009', '2025-03-15', 'c1000001-0000-0000-0000-000000000009', 'شركة النور للمقاولات',  'أحمد المندوب', 4320.00,  129.60, 4190.40, 3540.00, '',                    'أحمد المندوب', 'active',    '2025-03-15 09:30:00+00'),
  ('e1000001-0000-0000-0000-000000000010', 'INV-20250320-0010', '2025-03-20', 'c1000001-0000-0000-0000-000000000010', 'مصطفى كمال للدهانات',  'محمود السيد',  3900.00,    0.00, 3900.00, 3120.00, '',                    'محمود السيد',  'active',    '2025-03-20 10:00:00+00'),
  ('e1000001-0000-0000-0000-000000000011', 'INV-20250322-0011', '2025-03-22', 'c1000001-0000-0000-0000-000000000002', 'محمد أحمد للمقاولات',  'أحمد المندوب', 1520.00,    0.00, 1520.00, 1200.00, 'ملغية – خطأ في الكمية','أحمد المندوب','cancelled', '2025-03-22 08:00:00+00'),
  ('e1000001-0000-0000-0000-000000000012', 'INV-20250324-0012', '2025-03-24', 'c1000001-0000-0000-0000-000000000003', 'شركة البناء الحديث',   'أحمد المندوب', 5250.00,  525.00, 4725.00, 4350.00, '',                    'أحمد المندوب', 'active',    '2025-03-24 09:00:00+00')
ON CONFLICT (serial) DO NOTHING;

INSERT INTO invoice_items (id, invoice_id, product_id, product_name, unit, qty, unit_price, discount, total) VALUES
  ('f1000001-0000-0000-0000-000000000001', 'e1000001-0000-0000-0000-000000000001', 'd1000001-0000-0000-0000-000000000001', 'دهان خارجي ممتاز', 'لتر', 40,  55.00,  5.00, 2090.00),
  ('f1000001-0000-0000-0000-000000000002', 'e1000001-0000-0000-0000-000000000001', 'd1000001-0000-0000-0000-000000000008', 'برايمر',            'لتر', 75,  24.00,  0.00, 1800.00),
  ('f1000001-0000-0000-0000-000000000003', 'e1000001-0000-0000-0000-000000000002', 'd1000001-0000-0000-0000-000000000003', 'دهان داخلي ممتاز', 'لتر', 60,  43.00,  0.00, 2580.00),
  ('f1000001-0000-0000-0000-000000000004', 'e1000001-0000-0000-0000-000000000002', 'd1000001-0000-0000-0000-000000000006', 'بلاستيك ملون',      'لتر', 44,  50.00,  0.00, 2200.00),
  ('f1000001-0000-0000-0000-000000000005', 'e1000001-0000-0000-0000-000000000003', 'd1000001-0000-0000-0000-000000000001', 'دهان خارجي ممتاز', 'لتر', 50,  55.00, 10.00, 2475.00),
  ('f1000001-0000-0000-0000-000000000006', 'e1000001-0000-0000-0000-000000000003', 'd1000001-0000-0000-0000-000000000007', 'ديكوري تكسير',      'كجم', 30, 105.00, 10.00, 2835.00),
  ('f1000001-0000-0000-0000-000000000007', 'e1000001-0000-0000-0000-000000000003', 'd1000001-0000-0000-0000-000000000005', 'بوية زيتية أبيض',   'كجم', 25,  75.00, 10.00, 1687.50),
  ('f1000001-0000-0000-0000-000000000008', 'e1000001-0000-0000-0000-000000000004', 'd1000001-0000-0000-0000-000000000004', 'دهان داخلي عادي',  'لتر', 50,  28.00,  0.00, 1400.00),
  ('f1000001-0000-0000-0000-000000000009', 'e1000001-0000-0000-0000-000000000004', 'd1000001-0000-0000-0000-000000000002', 'دهان خارجي عادي',  'لتر', 35,  38.00,  0.00, 1330.00),
  ('f1000001-0000-0000-0000-000000000010', 'e1000001-0000-0000-0000-000000000005', 'd1000001-0000-0000-0000-000000000010', 'مينا بلاستيك',      'لتر', 42,  60.00,  8.00, 2318.40),
  ('f1000001-0000-0000-0000-000000000011', 'e1000001-0000-0000-0000-000000000005', 'd1000001-0000-0000-0000-000000000009', 'انشائي واجهات',      'كجم', 60,  26.00,  8.00, 1435.20),
  ('f1000001-0000-0000-0000-000000000012', 'e1000001-0000-0000-0000-000000000005', 'd1000001-0000-0000-0000-000000000008', 'برايمر',             'لتر', 38,  24.00,  8.00,  883.20),
  ('f1000001-0000-0000-0000-000000000013', 'e1000001-0000-0000-0000-000000000006', 'd1000001-0000-0000-0000-000000000002', 'دهان خارجي عادي',  'لتر', 45,  38.00,  0.00, 1710.00),
  ('f1000001-0000-0000-0000-000000000014', 'e1000001-0000-0000-0000-000000000006', 'd1000001-0000-0000-0000-000000000011', 'طلاء مائي أبيض',   'لتر', 54,  32.00,  0.00, 1728.00),
  ('f1000001-0000-0000-0000-000000000015', 'e1000001-0000-0000-0000-000000000007', 'd1000001-0000-0000-0000-000000000001', 'دهان خارجي ممتاز', 'لتر', 60,  55.00,  5.00, 3135.00),
  ('f1000001-0000-0000-0000-000000000016', 'e1000001-0000-0000-0000-000000000007', 'd1000001-0000-0000-0000-000000000003', 'دهان داخلي ممتاز', 'لتر', 60,  43.00,  5.00, 2451.00),
  ('f1000001-0000-0000-0000-000000000017', 'e1000001-0000-0000-0000-000000000007', 'd1000001-0000-0000-0000-000000000008', 'برايمر',            'لتر', 30,  24.00,  5.00,  684.00),
  ('f1000001-0000-0000-0000-000000000018', 'e1000001-0000-0000-0000-000000000008', 'd1000001-0000-0000-0000-000000000004', 'دهان داخلي عادي',  'لتر', 30,  28.00,  0.00,  840.00),
  ('f1000001-0000-0000-0000-000000000019', 'e1000001-0000-0000-0000-000000000008', 'd1000001-0000-0000-0000-000000000006', 'بلاستيك ملون',      'لتر', 20,  50.00,  0.00, 1000.00),
  ('f1000001-0000-0000-0000-000000000020', 'e1000001-0000-0000-0000-000000000008', 'd1000001-0000-0000-0000-000000000008', 'برايمر',            'لتر', 17,  24.00,  0.00,  408.00),
  ('f1000001-0000-0000-0000-000000000021', 'e1000001-0000-0000-0000-000000000009', 'd1000001-0000-0000-0000-000000000001', 'دهان خارجي ممتاز', 'لتر', 40,  55.00,  3.00, 2134.00),
  ('f1000001-0000-0000-0000-000000000022', 'e1000001-0000-0000-0000-000000000009', 'd1000001-0000-0000-0000-000000000009', 'انشائي واجهات',     'كجم', 80,  26.00,  3.00, 2017.60),
  ('f1000001-0000-0000-0000-000000000023', 'e1000001-0000-0000-0000-000000000010', 'd1000001-0000-0000-0000-000000000010', 'مينا بلاستيك',      'لتر', 35,  60.00,  0.00, 2100.00),
  ('f1000001-0000-0000-0000-000000000024', 'e1000001-0000-0000-0000-000000000010', 'd1000001-0000-0000-0000-000000000012', 'دهان مضاد للصدأ',   'لتر', 26,  68.00,  0.00, 1768.00),
  ('f1000001-0000-0000-0000-000000000025', 'e1000001-0000-0000-0000-000000000011', 'd1000001-0000-0000-0000-000000000002', 'دهان خارجي عادي',  'لتر', 40,  38.00,  0.00, 1520.00),
  ('f1000001-0000-0000-0000-000000000026', 'e1000001-0000-0000-0000-000000000012', 'd1000001-0000-0000-0000-000000000007', 'ديكوري تكسير',      'كجم', 25, 105.00, 10.00, 2362.50),
  ('f1000001-0000-0000-0000-000000000027', 'e1000001-0000-0000-0000-000000000012', 'd1000001-0000-0000-0000-000000000001', 'دهان خارجي ممتاز', 'لتر', 50,  55.00, 10.00, 2475.00);

-- ---- 6.5 التحصيلات ----
INSERT INTO collections (id, date, customer_id, customer_name, invoice_serial, amount, method, employee, notes, created_at) VALUES
  ('b1000001-0000-0000-0000-000000000001', '2025-01-15', 'c1000001-0000-0000-0000-000000000001', 'مقاولات النيل',          'INV-20250110-0001', 2000.00, 'cash',     'خالد المحصل', '',               '2025-01-15 10:00:00+00'),
  ('b1000001-0000-0000-0000-000000000002', '2025-01-20', 'c1000001-0000-0000-0000-000000000002', 'محمد أحمد للمقاولات',   'INV-20250115-0002', 3000.00, 'bank',     'خالد المحصل', 'تحويل بنكي',     '2025-01-20 11:00:00+00'),
  ('b1000001-0000-0000-0000-000000000003', '2025-01-25', 'c1000001-0000-0000-0000-000000000003', 'شركة البناء الحديث',    'INV-20250120-0003', 4000.00, 'check',    'خالد المحصل', 'شيك بنكي',       '2025-01-25 09:30:00+00'),
  ('b1000001-0000-0000-0000-000000000004', '2025-02-05', 'c1000001-0000-0000-0000-000000000001', 'مقاولات النيل',          '',                  1500.00, 'vodafone', 'خالد المحصل', 'دفعة جزئية',    '2025-02-05 10:00:00+00'),
  ('b1000001-0000-0000-0000-000000000005', '2025-02-08', 'c1000001-0000-0000-0000-000000000004', 'مؤسسة الإعمار',         'INV-20250201-0004', 2700.00, 'bank',     'خالد المحصل', 'سداد كامل',      '2025-02-08 08:00:00+00'),
  ('b1000001-0000-0000-0000-000000000006', '2025-02-12', 'c1000001-0000-0000-0000-000000000005', 'علي حسن للدهانات',      'INV-20250210-0005', 2500.00, 'cash',     'خالد المحصل', '',               '2025-02-12 11:00:00+00'),
  ('b1000001-0000-0000-0000-000000000007', '2025-02-20', 'c1000001-0000-0000-0000-000000000007', 'مقاولات الدلتا',        'INV-20250218-0006', 1800.00, 'cash',     'خالد المحصل', '',               '2025-02-20 10:00:00+00'),
  ('b1000001-0000-0000-0000-000000000008', '2025-03-03', 'c1000001-0000-0000-0000-000000000001', 'مقاولات النيل',          'INV-20250301-0007', 3000.00, 'bank',     'خالد المحصل', 'تحويل بنكي',     '2025-03-03 09:00:00+00'),
  ('b1000001-0000-0000-0000-000000000009', '2025-03-10', 'c1000001-0000-0000-0000-000000000003', 'شركة البناء الحديث',    '',                  2000.00, 'vodafone', 'خالد المحصل', '',               '2025-03-10 10:00:00+00'),
  ('b1000001-0000-0000-0000-000000000010', '2025-03-12', 'c1000001-0000-0000-0000-000000000008', 'أحمد فؤاد للبناء',      'INV-20250308-0008', 1200.00, 'cash',     'خالد المحصل', '',               '2025-03-12 11:00:00+00'),
  ('b1000001-0000-0000-0000-000000000011', '2025-03-14', 'c1000001-0000-0000-0000-000000000007', 'مقاولات الدلتا',        'INV-20250218-0006', 1620.00, 'check',    'خالد المحصل', 'شيك بنكي',       '2025-03-14 09:00:00+00'),
  ('b1000001-0000-0000-0000-000000000012', '2025-03-16', 'c1000001-0000-0000-0000-000000000009', 'شركة النور للمقاولات',  'INV-20250315-0009', 2500.00, 'bank',     'خالد المحصل', '',               '2025-03-16 10:00:00+00'),
  ('b1000001-0000-0000-0000-000000000013', '2025-03-18', 'c1000001-0000-0000-0000-000000000010', 'مصطفى كمال للدهانات',  'INV-20250320-0010', 2000.00, 'vodafone', 'خالد المحصل', '',               '2025-03-18 09:00:00+00'),
  ('b1000001-0000-0000-0000-000000000014', '2025-03-20', 'c1000001-0000-0000-0000-000000000002', 'محمد أحمد للمقاولات',  '',                  1760.00, 'cash',     'خالد المحصل', 'باقي الفاتورة',  '2025-03-20 10:00:00+00'),
  ('b1000001-0000-0000-0000-000000000015', '2025-03-22', 'c1000001-0000-0000-0000-000000000005', 'علي حسن للدهانات',      '',                  2136.80, 'bank',     'خالد المحصل', 'باقي الفاتورة',  '2025-03-22 11:00:00+00'),
  ('b1000001-0000-0000-0000-000000000016', '2025-03-24', 'c1000001-0000-0000-0000-000000000003', 'شركة البناء الحديث',   '',                  3087.50, 'check',    'خالد المحصل', 'شيك بنكي',       '2025-03-24 09:00:00+00'),
  ('b1000001-0000-0000-0000-000000000017', '2025-03-24', 'c1000001-0000-0000-0000-000000000001', 'مقاولات النيل',          '',                  3270.00, 'cash',     'خالد المحصل', 'باقي الفاتورة 7','2025-03-24 11:00:00+00'),
  ('b1000001-0000-0000-0000-000000000018', '2025-03-25', 'c1000001-0000-0000-0000-000000000009', 'شركة النور للمقاولات',  '',                  1690.40, 'vodafone', 'خالد المحصل', '',               '2025-03-25 08:00:00+00'),
  ('b1000001-0000-0000-0000-000000000019', '2025-03-25', 'c1000001-0000-0000-0000-000000000010', 'مصطفى كمال للدهانات',  '',                  1900.00, 'bank',     'خالد المحصل', '',               '2025-03-25 09:00:00+00'),
  ('b1000001-0000-0000-0000-000000000020', '2025-03-25', 'c1000001-0000-0000-0000-000000000008', 'أحمد فؤاد للبناء',      '',                  1050.00, 'cash',     'خالد المحصل', '',               '2025-03-25 10:00:00+00')
ON CONFLICT DO NOTHING;

-- ---- 6.6 المحفظة الإلكترونية (فودافون كاش) ----
INSERT INTO wallet_ledger (id, date, direction, category, counterparty, invoice_serial, amount, method, balance, notes, created_at) VALUES
  ('g1000001-0000-0000-0000-000000000001', '2024-12-29', 'in',  'إيداع أولي',    'المدير',              '',                   5000.00, 'cash',     5000.00,  'رصيد افتتاحي',       '2024-12-29 09:00:00+00'),
  ('g1000001-0000-0000-0000-000000000002', '2025-01-05', 'in',  'تحصيل عميل',   'مقاولات النيل',       'INV-20250110-0001',  1500.00, 'vodafone', 6500.00,  '',                    '2025-01-05 10:00:00+00'),
  ('g1000001-0000-0000-0000-000000000003', '2025-01-08', 'out', 'مصروف شحن',    'شركة الشحن',          '',                    450.00, 'vodafone', 6050.00,  'شحن بضاعة للعملاء',  '2025-01-08 11:00:00+00'),
  ('g1000001-0000-0000-0000-000000000004', '2025-01-12', 'in',  'تحصيل عميل',   'محمد أحمد للمقاولات','INV-20250115-0002',  2000.00, 'vodafone', 8050.00,  '',                    '2025-01-12 09:00:00+00'),
  ('g1000001-0000-0000-0000-000000000005', '2025-01-18', 'out', 'سداد مصنع',    'مصنع الحرمين',        '',                  3000.00, 'vodafone', 5050.00,  'دفعة جزئية للمصنع',  '2025-01-18 10:00:00+00'),
  ('g1000001-0000-0000-0000-000000000006', '2025-01-22', 'in',  'تحصيل عميل',   'شركة البناء الحديث',  'INV-20250120-0003', 2500.00, 'vodafone', 7550.00,  '',                    '2025-01-22 11:00:00+00'),
  ('g1000001-0000-0000-0000-000000000007', '2025-01-28', 'out', 'مصروف تشغيل',  'متنوع',               '',                    800.00, 'vodafone', 6750.00,  'مصروفات متنوعة',     '2025-01-28 09:00:00+00'),
  ('g1000001-0000-0000-0000-000000000008', '2025-02-03', 'in',  'تحويل وارد',   'البنك',               '',                  4000.00, 'bank',    10750.00,  'تحويل من الحساب',    '2025-02-03 10:00:00+00'),
  ('g1000001-0000-0000-0000-000000000009', '2025-02-06', 'out', 'سداد مصنع',    'مصنع الحرمين',        '',                  5000.00, 'vodafone', 5750.00,  '',                    '2025-02-06 08:00:00+00'),
  ('g1000001-0000-0000-0000-000000000010', '2025-02-10', 'in',  'تحصيل عميل',   'علي حسن للدهانات',    'INV-20250210-0005', 1800.00, 'vodafone', 7550.00,  '',                    '2025-02-10 11:00:00+00'),
  ('g1000001-0000-0000-0000-000000000011', '2025-02-14', 'out', 'رسوم بنكية',   'البنك',               '',                    120.00, 'bank',    7430.00,  '',                    '2025-02-14 09:00:00+00'),
  ('g1000001-0000-0000-0000-000000000012', '2025-02-18', 'in',  'تحصيل عميل',   'مقاولات الدلتا',      'INV-20250218-0006', 1500.00, 'vodafone', 8930.00,  '',                    '2025-02-18 10:00:00+00'),
  ('g1000001-0000-0000-0000-000000000013', '2025-02-22', 'out', 'مصروف شحن',    'شركة الشحن',          '',                    600.00, 'vodafone', 8330.00,  '',                    '2025-02-22 11:00:00+00'),
  ('g1000001-0000-0000-0000-000000000014', '2025-02-26', 'in',  'تحصيل عميل',   'مقاولات النيل',       '',                  2000.00, 'vodafone',10330.00,  '',                    '2025-02-26 09:00:00+00'),
  ('g1000001-0000-0000-0000-000000000015', '2025-03-02', 'out', 'سداد مصنع',    'مصنع الحرمين',        '',                  4000.00, 'vodafone', 6330.00,  '',                    '2025-03-02 10:00:00+00'),
  ('g1000001-0000-0000-0000-000000000016', '2025-03-06', 'in',  'إيداع',        'المدير',              '',                  3000.00, 'cash',    9330.00,  'إيداع نقدي',           '2025-03-06 08:00:00+00'),
  ('g1000001-0000-0000-0000-000000000017', '2025-03-10', 'in',  'تحصيل عميل',   'شركة النور للمقاولات','INV-20250315-0009', 1500.00, 'vodafone',10830.00,  '',                    '2025-03-10 11:00:00+00'),
  ('g1000001-0000-0000-0000-000000000018', '2025-03-14', 'out', 'مصروف تشغيل',  'متنوع',               '',                    950.00, 'vodafone', 9880.00,  '',                    '2025-03-14 09:00:00+00'),
  ('g1000001-0000-0000-0000-000000000019', '2025-03-18', 'in',  'تحصيل عميل',   'مصطفى كمال للدهانات', '',                 1500.00, 'vodafone',11380.00,  '',                    '2025-03-18 10:00:00+00'),
  ('g1000001-0000-0000-0000-000000000020', '2025-03-22', 'out', 'سداد مصنع',    'مصنع الحرمين',        '',                  3500.00, 'bank',    7880.00,  '',                    '2025-03-22 11:00:00+00'),
  ('g1000001-0000-0000-0000-000000000021', '2025-03-25', 'in',  'تحصيل عميل',   'أحمد فؤاد للبناء',    '',                 1000.00, 'vodafone', 8880.00,  '',                    '2025-03-25 09:00:00+00')
ON CONFLICT DO NOTHING;

-- ---- 6.7 دفعات المصنع ----
INSERT INTO factory_payments (id, date, amount, method, notes, reference, created_at) VALUES
  ('h1000001-0000-0000-0000-000000000001', '2025-01-18', 10000.00, 'bank',     'دفعة للمصنع – يناير', 'REF-1001', '2025-01-18 10:00:00+00'),
  ('h1000001-0000-0000-0000-000000000002', '2025-01-25',  5000.00, 'vodafone', 'دفعة فودافون كاش',     'REF-1002', '2025-01-25 11:00:00+00'),
  ('h1000001-0000-0000-0000-000000000003', '2025-02-06',  8000.00, 'bank',     'دفعة للمصنع – فبراير', 'REF-1003', '2025-02-06 09:00:00+00'),
  ('h1000001-0000-0000-0000-000000000004', '2025-02-15', 12000.00, 'check',    'شيك دفعة مصنع',        'REF-1004', '2025-02-15 10:00:00+00'),
  ('h1000001-0000-0000-0000-000000000005', '2025-02-28',  7500.00, 'bank',     'دفعة نهاية فبراير',    'REF-1005', '2025-02-28 08:00:00+00'),
  ('h1000001-0000-0000-0000-000000000006', '2025-03-05',  9000.00, 'bank',     'دفعة للمصنع – مارس',   'REF-1006', '2025-03-05 09:00:00+00'),
  ('h1000001-0000-0000-0000-000000000007', '2025-03-15',  6000.00, 'vodafone', 'دفعة فودافون كاش',     'REF-1007', '2025-03-15 11:00:00+00'),
  ('h1000001-0000-0000-0000-000000000008', '2025-03-22', 11000.00, 'bank',     'دفعة نهاية مارس',      'REF-1008', '2025-03-22 10:00:00+00')
ON CONFLICT DO NOTHING;

-- ---- 6.8 صادر المكتب (المصروفات) ----
INSERT INTO office_payments (id, date, amount, category, method, notes, reference, created_at) VALUES
  ('i1000001-0000-0000-0000-000000000001', '2025-01-05',  3500.00, 'إيجار مكتب',    'cash', 'إيجار مكتب يناير',      '', '2025-01-05 09:00:00+00'),
  ('i1000001-0000-0000-0000-000000000002', '2025-01-10',  8000.00, 'رواتب',         'bank', 'رواتب الموظفين يناير',  '', '2025-01-10 10:00:00+00'),
  ('i1000001-0000-0000-0000-000000000003', '2025-01-15',   600.00, 'فواتير خدمات', 'cash', 'فاتورة كهرباء + انترنت','', '2025-01-15 11:00:00+00'),
  ('i1000001-0000-0000-0000-000000000004', '2025-01-20',   350.00, 'مصروفات تشغيل','cash', 'متنوع',                 '', '2025-01-20 09:00:00+00'),
  ('i1000001-0000-0000-0000-000000000005', '2025-02-05',  3500.00, 'إيجار مكتب',    'cash', 'إيجار مكتب فبراير',     '', '2025-02-05 09:00:00+00'),
  ('i1000001-0000-0000-0000-000000000006', '2025-02-10',  8500.00, 'رواتب',         'bank', 'رواتب الموظفين فبراير', '', '2025-02-10 10:00:00+00'),
  ('i1000001-0000-0000-0000-000000000007', '2025-02-15',   550.00, 'فواتير خدمات', 'cash', 'فاتورة كهرباء',         '', '2025-02-15 11:00:00+00'),
  ('i1000001-0000-0000-0000-000000000008', '2025-02-22',  1200.00, 'مصروفات شحن',  'cash', 'شحن بضاعة',             '', '2025-02-22 09:00:00+00'),
  ('i1000001-0000-0000-0000-000000000009', '2025-03-05',  3500.00, 'إيجار مكتب',    'cash', 'إيجار مكتب مارس',       '', '2025-03-05 09:00:00+00'),
  ('i1000001-0000-0000-0000-000000000010', '2025-03-10',  9000.00, 'رواتب',         'bank', 'رواتب الموظفين مارس',   '', '2025-03-10 10:00:00+00')
ON CONFLICT DO NOTHING;

-- ---- 6.9 وارد المكتب ----
INSERT INTO office_incoming (id, date, amount, category, method, notes, reference, created_at) VALUES
  ('j1000001-0000-0000-0000-000000000001', '2025-01-10', 2500.00, 'تحصيل نقدي من عميل', 'cash',     'من مقاولات النيل',      '', '2025-01-10 10:00:00+00'),
  ('j1000001-0000-0000-0000-000000000002', '2025-01-16', 3000.00, 'تحويل بنكي من عميل', 'bank',     'من محمد أحمد للمقاولات','', '2025-01-16 11:00:00+00'),
  ('j1000001-0000-0000-0000-000000000003', '2025-01-22', 4500.00, 'تحصيل نقدي من عميل', 'cash',     'من شركة البناء الحديث', '', '2025-01-22 09:00:00+00'),
  ('j1000001-0000-0000-0000-000000000004', '2025-02-02', 2700.00, 'تحويل بنكي من عميل', 'bank',     'من مؤسسة الإعمار',      '', '2025-02-02 10:00:00+00'),
  ('j1000001-0000-0000-0000-000000000005', '2025-02-10', 2000.00, 'إيداع فودافون',       'vodafone', 'من علي حسن للدهانات',   '', '2025-02-10 11:00:00+00'),
  ('j1000001-0000-0000-0000-000000000006', '2025-02-19', 1800.00, 'تحصيل نقدي من عميل', 'cash',     'من مقاولات الدلتا',     '', '2025-02-19 09:00:00+00'),
  ('j1000001-0000-0000-0000-000000000007', '2025-02-25',  500.00, 'عمولة بيع',           'cash',     'عمولة مبيعات',          '', '2025-02-25 10:00:00+00'),
  ('j1000001-0000-0000-0000-000000000008', '2025-03-03', 3200.00, 'تحويل بنكي من عميل', 'bank',     'من مقاولات النيل',      '', '2025-03-03 11:00:00+00'),
  ('j1000001-0000-0000-0000-000000000009', '2025-03-11', 2000.00, 'تحصيل نقدي من عميل', 'cash',     'من شركة البناء الحديث', '', '2025-03-11 09:00:00+00'),
  ('j1000001-0000-0000-0000-000000000010', '2025-03-13', 1200.00, 'إيداع فودافون',       'vodafone', 'من أحمد فؤاد للبناء',   '', '2025-03-13 10:00:00+00'),
  ('j1000001-0000-0000-0000-000000000011', '2025-03-17', 2600.00, 'تحويل بنكي من عميل', 'bank',     'من شركة النور',         '', '2025-03-17 11:00:00+00'),
  ('j1000001-0000-0000-0000-000000000012', '2025-03-24', 1900.00, 'تحصيل نقدي من عميل', 'cash',     'من مصطفى كمال',         '', '2025-03-24 09:00:00+00')
ON CONFLICT DO NOTHING;

-- ============================================================
-- ملاحظات نهائية:
-- 1. بعد تشغيل هذا السكريبت، أضف المستخدمين إلى Supabase Auth:
--    Dashboard → Authentication → Users → Add user
--    استخدم نفس البريد الإلكتروني الموجود في جدول users أعلاه.
-- 2. كلمات المرور المقترحة للاختبار:
--    admin@haramain.com     → Admin@2025
--    ahmed@haramain.com     → Ahmed@2025
--    mahmoud@haramain.com   → Mahmoud@2025
--    khaled@haramain.com    → Khaled@2025
-- 3. تأكد من تعطيل "Confirm email" في:
--    Authentication → Providers → Email → Confirm email: OFF
-- ============================================================
