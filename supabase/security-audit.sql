-- ============================================================
-- Axion 전체 보안 점검 & RLS 일괄 수정
-- Supabase SQL Editor에서 실행하세요.
-- ============================================================

-- ── STEP 1: 현재 RLS 상태 확인 ─────────────────────────────
-- 실행 후 rowsecurity = false 인 테이블이 있으면 문제
SELECT
  tablename,
  rowsecurity AS rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;


-- ── STEP 2: RLS 일괄 활성화 ────────────────────────────────
-- 이미 활성화된 테이블에 실행해도 안전 (오류 없음)

ALTER TABLE public.customers_base     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_programs  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.programs           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partners           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.balance_logs       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partner_programs   ENABLE ROW LEVEL SECURITY;


-- ── STEP 3: partner_programs 정책 보강 ─────────────────────
-- rls-setup.sql에 있었지만 실행 여부 불확실 → 재실행 안전

DROP POLICY IF EXISTS pp_select ON public.partner_programs;
DROP POLICY IF EXISTS pp_insert ON public.partner_programs;
DROP POLICY IF EXISTS pp_delete ON public.partner_programs;

CREATE POLICY pp_select ON public.partner_programs
  FOR SELECT TO authenticated
  USING (
    public.axion_is_super()
    OR partner_id IN (SELECT id FROM public.partners WHERE email = auth.email())
  );

CREATE POLICY pp_insert ON public.partner_programs
  FOR INSERT TO authenticated
  WITH CHECK (public.axion_is_super());

CREATE POLICY pp_delete ON public.partner_programs
  FOR DELETE TO authenticated
  USING (public.axion_is_super());


-- ── STEP 4: balance_logs 정책 확인 및 보강 ─────────────────

DROP POLICY IF EXISTS ballog_select ON public.balance_logs;

CREATE POLICY ballog_select ON public.balance_logs
  FOR SELECT TO authenticated
  USING (
    public.axion_is_super()
    OR TRIM(account_no::text) IN (
      SELECT TRIM(account_no::text)
      FROM public.customers_base
      WHERE team_name = public.axion_team_name()
    )
  );


-- ── STEP 5: 결과 재확인 ────────────────────────────────────
-- 아래 쿼리로 모든 테이블의 rls_enabled = true 인지 확인

SELECT
  t.tablename,
  t.rowsecurity AS rls_enabled,
  COUNT(p.policyname) AS policy_count
FROM pg_tables t
LEFT JOIN pg_policies p
  ON p.schemaname = t.schemaname AND p.tablename = t.tablename
WHERE t.schemaname = 'public'
GROUP BY t.tablename, t.rowsecurity
ORDER BY t.tablename;
