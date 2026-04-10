-- ============================================================
-- سكريبت ترقية جدول سجل الحركات – Elharamain ERP
-- activity_log Upgrade Migration
-- ============================================================
-- الغرض: ترقية جدول activity_log الموجود من الشكل القديم
--         إلى الشكل القياسي (canonical schema).
--
-- الشكل القديم (قد يحتوي على):
--   id, user_email, user_name, role, action, page, details,
--   timestamp (timestamp without time zone), created_at
--
-- الشكل القياسي المطلوب:
--   id uuid pk
--   timestamp timestamptz not null default now()
--   created_at timestamptz not null default now()
--   user_id uuid
--   user_name text
--   user_role text
--   action text
--   resource text
--   details text
--
-- ملاحظة: هذا السكريبت آمن للتشغيل أكثر من مرة (idempotent).
--         لا يحذف أي بيانات موجودة ولا يحذف الأعمدة القديمة.
-- ============================================================
-- كيفية الاستخدام:
--   1. افتح Supabase Dashboard → SQL Editor
--   2. انسخ هذا الملف بالكامل والصقه في المحرر
--   3. اضغط "Run" لتنفيذ السكريبت
-- ============================================================

-- ==============================
-- الخطوة 1: إنشاء الجدول إن لم يكن موجوداً (للتثبيت الجديد)
-- ==============================
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
-- الخطوة 2: إضافة الأعمدة الجديدة إن لم تكن موجودة
--           (للترقية من النسخة القديمة)
-- ==============================
ALTER TABLE activity_log ADD COLUMN IF NOT EXISTS user_id    UUID;
ALTER TABLE activity_log ADD COLUMN IF NOT EXISTS user_role  TEXT;
ALTER TABLE activity_log ADD COLUMN IF NOT EXISTS resource   TEXT;
ALTER TABLE activity_log ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- ==============================
-- الخطوة 3: تحويل نوع عمود timestamp من
--           "timestamp without time zone" إلى timestamptz
--           (آمن – يُعامل التوقيت المحلي المحفوظ على أنه UTC)
-- ==============================
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

-- ==============================
-- الخطوة 4: ملء البيانات التراجعية (Backfill)
--           من الأعمدة القديمة إلى الأعمدة القياسية
-- ==============================

-- user_role ← role (إن كان user_role فارغاً)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'activity_log'
      AND column_name  = 'role'
  ) THEN
    UPDATE activity_log
       SET user_role = role
     WHERE user_role IS NULL AND role IS NOT NULL;
  END IF;
END $$;

-- resource ← page (إن كان resource فارغاً)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'activity_log'
      AND column_name  = 'page'
  ) THEN
    UPDATE activity_log
       SET resource = page
     WHERE resource IS NULL AND page IS NOT NULL;
  END IF;
END $$;

-- timestamp: إن كان NULL، تعبئة من created_at أو now()
UPDATE activity_log
   SET "timestamp" = COALESCE(created_at, NOW())
 WHERE "timestamp" IS NULL;

-- created_at: إن كان NULL، تعبئة من timestamp أو now()
UPDATE activity_log
   SET created_at = COALESCE("timestamp", NOW())
 WHERE created_at IS NULL;

-- ==============================
-- الخطوة 5: الفهرس على timestamp DESC
-- ==============================
CREATE INDEX IF NOT EXISTS idx_activity_log_timestamp ON activity_log("timestamp" DESC);

-- ==============================
-- الخطوة 6: Row Level Security
-- ==============================
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "authenticated_full_access" ON activity_log;
CREATE POLICY "authenticated_full_access" ON activity_log
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ==============================
-- الخطوة 7: التحقق من النتيجة
-- ==============================
SELECT 'جدول activity_log – الأعمدة بعد الترقية:' AS info;
SELECT column_name, data_type, is_nullable, column_default
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'activity_log'
  ORDER BY ordinal_position;

SELECT 'عدد السجلات في activity_log:' AS info;
SELECT COUNT(*) AS total_rows FROM activity_log;

-- ============================================================
-- ملاحظات هامة:
-- ============================================================
-- 1. الأعمدة القديمة (user_email, role, page) لم تُحذف لضمان
--    سلامة البيانات التاريخية. التطبيق يكتب الآن في الأعمدة
--    القياسية فقط: user_id/user_name/user_role/action/resource/details.
-- 2. تم تحويل timestamp إلى timestamptz (مع افتراض UTC).
-- 3. يمكن تشغيل هذا السكريبت بأمان أكثر من مرة دون تأثير.
-- 4. السكريبت الشامل للمزامنة الكاملة: sync_migration.sql
-- ============================================================
