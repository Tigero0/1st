-- ============================================================
-- سكريبت الترحيل: تحديث الأدوار ليشمل جميع الأدوار المعتمدة
-- Fix Roles Migration – Seed All Built-in Roles
-- ============================================================
-- كيفية الاستخدام:
--   1. افتح Supabase Dashboard → SQL Editor
--   2. انسخ هذا الملف بالكامل والصقه في المحرر
--   3. اضغط "Run" لتنفيذ السكريبت
-- ============================================================
-- ما يفعله هذا السكريبت:
--   - يضيف/يحدث الأدوار الأربعة المعتمدة: admin, manager, sales, collector
--   - يجعل جميعها محمية من الحذف (protected = TRUE)
--   - يضبط صلاحيات كل دور على جميع الصفحات المناسبة
-- ============================================================

-- ==============================
-- الخطوة 1: إدراج/تحديث الأدوار الأساسية الأربعة
-- ==============================
INSERT INTO roles (name, label, protected) VALUES
  ('admin',    'مدير النظام', TRUE),
  ('manager',  'مدير عام',   TRUE),
  ('sales',    'مبيعات',     TRUE),
  ('collector','حسابات',     TRUE)
ON CONFLICT (name) DO UPDATE SET
  label     = EXCLUDED.label,
  protected = TRUE;

-- ==============================
-- الخطوة 2: حذف صلاحيات الأدوار القديمة/المتعارضة
-- ==============================
DELETE FROM role_permissions WHERE role_name NOT IN (SELECT name FROM roles);

-- ==============================
-- الخطوة 3: منح مدير النظام جميع الصلاحيات
-- ==============================
INSERT INTO role_permissions (role_name, page, can_view, can_add, can_edit, can_delete) VALUES
  ('admin', 'dashboard',       TRUE,  FALSE, FALSE, FALSE),
  ('admin', 'customers',       TRUE,  TRUE,  TRUE,  TRUE),
  ('admin', 'products',        TRUE,  TRUE,  TRUE,  TRUE),
  ('admin', 'invoices',        TRUE,  TRUE,  TRUE,  TRUE),
  ('admin', 'collections',     TRUE,  TRUE,  TRUE,  TRUE),
  ('admin', 'wallet',          TRUE,  TRUE,  TRUE,  TRUE),
  ('admin', 'factoryPayments', TRUE,  TRUE,  TRUE,  TRUE),
  ('admin', 'officeIncoming',  TRUE,  TRUE,  TRUE,  TRUE),
  ('admin', 'officeOutgoing',  TRUE,  TRUE,  TRUE,  TRUE),
  ('admin', 'profits',         TRUE,  FALSE, FALSE, FALSE),
  ('admin', 'reports',         TRUE,  FALSE, FALSE, FALSE),
  ('admin', 'activityLog',     TRUE,  FALSE, FALSE, FALSE),
  ('admin', 'employeeReport',  TRUE,  FALSE, FALSE, FALSE),
  ('admin', 'orderTracking',   TRUE,  FALSE, TRUE,  FALSE),
  ('admin', 'settings',        TRUE,  FALSE, FALSE, FALSE)
ON CONFLICT (role_name, page) DO UPDATE SET
  can_view   = EXCLUDED.can_view,
  can_add    = EXCLUDED.can_add,
  can_edit   = EXCLUDED.can_edit,
  can_delete = EXCLUDED.can_delete;

-- ==============================
-- الخطوة 4: منح مدير عام صلاحيات واسعة بدون حذف
-- ==============================
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
  ('manager', 'settings',        TRUE,  FALSE, FALSE, FALSE)
ON CONFLICT (role_name, page) DO UPDATE SET
  can_view   = EXCLUDED.can_view,
  can_add    = EXCLUDED.can_add,
  can_edit   = EXCLUDED.can_edit,
  can_delete = EXCLUDED.can_delete;

-- ==============================
-- الخطوة 5: منح مبيعات صلاحيات محدودة
-- ==============================
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

-- ==============================
-- الخطوة 6: منح حسابات صلاحيات التحصيل والمحفظة
-- ==============================
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
-- الخطوة 7: تصحيح أي مستخدمين يحملون الدور القديم general_manager
-- ==============================
UPDATE users SET role = 'manager' WHERE role = 'general_manager';

-- ==============================
-- الخطوة 8: التحقق من النتيجة
-- ==============================
SELECT 'الأدوار الموجودة الآن:' AS info;
SELECT name, label, protected FROM roles ORDER BY name;

SELECT 'صلاحيات الأدوار:' AS info;
SELECT role_name, page, can_view, can_add, can_edit, can_delete
  FROM role_permissions
  ORDER BY role_name, page;

-- ============================================================
-- ملاحظات مهمة بعد تشغيل هذا السكريبت:
-- ============================================================
-- 1. الأدوار المتاحة الآن: admin (مدير النظام), manager (مدير عام),
--    sales (مبيعات), collector (حسابات)
-- 2. أي مستخدم كان يحمل الدور general_manager تم تحويله تلقائيًا إلى manager
-- 3. لضمان تسجيل دخول المدير من أي جهاز:
--    اذهب إلى الإعدادات → Supabase → "مزامنة المستخدمين"
-- ============================================================
