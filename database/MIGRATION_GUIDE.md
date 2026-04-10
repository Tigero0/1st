# دليل ترقية قاعدة البيانات – نظام الحرمين ERP
# Migration Guide – Elharamain ERP

## المخطط المرجعي (Canonical Schema)

### جدول `activity_log` (سجل الحركات)

```sql
CREATE TABLE activity_log (
  id         UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  timestamp  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  user_id    UUID,
  user_name  TEXT,
  user_role  TEXT,
  action     TEXT,
  resource   TEXT,
  details    TEXT
);
CREATE INDEX idx_activity_log_timestamp ON activity_log(timestamp DESC);
```

| عمود | النوع | الوصف |
|------|-------|-------|
| `id` | UUID PK | معرّف فريد تلقائي |
| `timestamp` | TIMESTAMPTZ NOT NULL | وقت الحدث |
| `created_at` | TIMESTAMPTZ NOT NULL | وقت الإدراج (احتياطي) |
| `user_id` | UUID | معرّف المستخدم في Supabase Auth |
| `user_name` | TEXT | اسم المستخدم |
| `user_role` | TEXT | دور المستخدم (admin/sales/…) |
| `action` | TEXT | الإجراء المنفذ (مثال: إضافة فاتورة) |
| `resource` | TEXT | الصفحة/المورد المرتبط (مثال: الفواتير) |
| `details` | TEXT | تفاصيل إضافية |

### جدول `users` (المستخدمون)

```sql
CREATE TABLE users (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  email        TEXT UNIQUE NOT NULL,
  name         TEXT,
  role         TEXT DEFAULT 'sales',
  status       TEXT DEFAULT 'active' CHECK (status IN ('active','inactive')),
  custom_perms JSONB,
  custom_pages JSONB,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);
```

> **ملاحظة أمنية**: لا يُخزَّن `password` مطلقاً في جدول `users`.
> كلمات المرور تُدار حصرياً عبر Supabase Auth.

---

## كيفية تشغيل سكريبتات الترقية

### 1. إعداد أولي (قاعدة بيانات جديدة)

```
Supabase Dashboard → SQL Editor → New Query
```

انسخ محتوى `database/supabase_setup.sql` والصقه، ثم اضغط **Run**.

### 2. ترقية قاعدة بيانات موجودة

```
Supabase Dashboard → SQL Editor → New Query
```

انسخ محتوى `database/sync_migration.sql` والصقه، ثم اضغط **Run**.

هذا السكريبت:
- يضيف الجداول الناقصة
- يضيف الأعمدة الناقصة للجداول الموجودة
- يُنشئ الفهارس المطلوبة
- لا يحذف أي بيانات موجودة

### 3. ترقية `activity_log` من مخطط قديم

إن كان جدول `activity_log` لديك يحتوي على أعمدة قديمة
(`user_email`, `role`, `page`) بدلاً من (`user_id`, `user_role`, `resource`)،
شغّل سكريبت الترقية المخصص:

```
Supabase Dashboard → SQL Editor → New Query
```

انسخ محتوى `database/activity_log_migration.sql` والصقه، ثم اضغط **Run**.

هذا السكريبت:
- يضيف الأعمدة الجديدة إن لم تكن موجودة
- يُرحِّل البيانات (مثلاً `role` → `user_role`, `page` → `resource`)
- يبقي الأعمدة القديمة للتوافق مع الإصدارات السابقة

---

## ملاحظات للمطورين

### تسجيل الدخول (Authentication)

- يعتمد التطبيق على **Supabase Auth** (`signInWithPassword`) كمصدر حقيقة
- بعد نجاح Auth، يُجلب ملف المستخدم من `public.users` ويُتحقق من `status = 'active'`
- لا تُخزَّن كلمات المرور في جدول `users` أبداً
- في حالة عدم توفر Supabase (offline)، يُستخدم `localStorage` كبديل للتطوير فقط

### كتابة سجل الحركات (Activity Log)

الدالة `logActivity(action, resource, details)` في `index.html` تُسجِّل تلقائياً:
- `user_id` من `appState.currentUser.id`
- `user_name` من `appState.currentUser.name`
- `user_role` من `appState.currentUser.role`
- `timestamp` و `created_at` من التوقيت الحالي

### خرائط الأعمدة (Column Mapping)

الكود يستخدم `snake_case` مطابقاً للقاعدة:

| في الكود | في قاعدة البيانات |
|----------|------------------|
| `custom_perms` | `custom_perms` |
| `custom_pages` | `custom_pages` |

الدالة `normalizeUserForDB(u)` تتعامل مع تحويل أي سجلات قديمة
`camelCase` → `snake_case` عند الاستيراد.
