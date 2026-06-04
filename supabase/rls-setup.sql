-- ============================================================
-- Axion Research — RLS 보안 설정
-- Supabase SQL Editor에서 실행하세요
-- ============================================================
-- 주의: SUPER_ADMIN_EMAIL을 실제 슈퍼 관리자 이메일로 변경하세요
-- ============================================================

-- ── 기존 정책 전부 삭제 (충돌 방지) ──────────────────────────

DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('customers','customer_programs','programs','partners','balance_logs')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I',
                   pol.policyname, pol.schemaname, pol.tablename);
  END LOOP;
END $$;


-- ── RLS 활성화 ────────────────────────────────────────────────

ALTER TABLE customers         ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_programs ENABLE ROW LEVEL SECURITY;
ALTER TABLE programs          ENABLE ROW LEVEL SECURITY;
ALTER TABLE partners          ENABLE ROW LEVEL SECURITY;
ALTER TABLE balance_logs      ENABLE ROW LEVEL SECURITY;


-- ── 헬퍼: 현재 로그인 사용자의 team_name 조회 ──────────────────

CREATE OR REPLACE FUNCTION axion_team_name()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT team_name FROM public.partners WHERE email = auth.email() LIMIT 1;
$$;

-- ── 헬퍼: 슈퍼 관리자 여부 ────────────────────────────────────
-- 실제 슈퍼 관리자 이메일로 변경하세요!

CREATE OR REPLACE FUNCTION axion_is_super()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT auth.email() = 'admin@axion.com';
$$;


-- ══════════════════════════════════════════
--  customers
-- ══════════════════════════════════════════

CREATE POLICY "customers_select" ON customers
  FOR SELECT TO authenticated
  USING (axion_is_super() OR team_name = axion_team_name());

CREATE POLICY "customers_insert" ON customers
  FOR INSERT TO authenticated
  WITH CHECK (axion_is_super() OR team_name = axion_team_name());

CREATE POLICY "customers_update" ON customers
  FOR UPDATE TO authenticated
  USING  (axion_is_super() OR team_name = axion_team_name())
  WITH CHECK (axion_is_super() OR team_name = axion_team_name());

CREATE POLICY "customers_delete" ON customers
  FOR DELETE TO authenticated
  USING (axion_is_super() OR team_name = axion_team_name());


-- ══════════════════════════════════════════
--  customer_programs
-- ══════════════════════════════════════════

CREATE POLICY "cprog_select" ON customer_programs
  FOR SELECT TO authenticated
  USING (
    axion_is_super()
    OR customer_id IN (
      SELECT id FROM customers WHERE team_name = axion_team_name()
    )
  );

CREATE POLICY "cprog_insert" ON customer_programs
  FOR INSERT TO authenticated
  WITH CHECK (
    axion_is_super()
    OR customer_id IN (
      SELECT id FROM customers WHERE team_name = axion_team_name()
    )
  );

CREATE POLICY "cprog_delete" ON customer_programs
  FOR DELETE TO authenticated
  USING (
    axion_is_super()
    OR customer_id IN (
      SELECT id FROM customers WHERE team_name = axion_team_name()
    )
  );


-- ══════════════════════════════════════════
--  programs  (EA 프로그램 목록)
-- ══════════════════════════════════════════

-- 인증된 모든 사용자가 읽기 가능 (파트너도 EA 이름 필요)
CREATE POLICY "programs_select" ON programs
  FOR SELECT TO authenticated USING (true);

-- 생성·수정·삭제는 슈퍼 관리자만
CREATE POLICY "programs_insert" ON programs
  FOR INSERT TO authenticated WITH CHECK (axion_is_super());

CREATE POLICY "programs_update" ON programs
  FOR UPDATE TO authenticated USING (axion_is_super());

CREATE POLICY "programs_delete" ON programs
  FOR DELETE TO authenticated USING (axion_is_super());


-- ══════════════════════════════════════════
--  partners
-- ══════════════════════════════════════════

-- 슈퍼 관리자: 전부 / 일반 파트너: 자기 행만
CREATE POLICY "partners_select" ON partners
  FOR SELECT TO authenticated
  USING (axion_is_super() OR email = auth.email());

CREATE POLICY "partners_insert" ON partners
  FOR INSERT TO authenticated WITH CHECK (axion_is_super());

CREATE POLICY "partners_update" ON partners
  FOR UPDATE TO authenticated USING (axion_is_super());

CREATE POLICY "partners_delete" ON partners
  FOR DELETE TO authenticated USING (axion_is_super());


-- ══════════════════════════════════════════
--  balance_logs
-- ══════════════════════════════════════════

-- 읽기: 인증된 사용자만, 자기 팀 계좌만
CREATE POLICY "ballog_select" ON balance_logs
  FOR SELECT TO authenticated
  USING (
    axion_is_super()
    OR account_no IN (
      SELECT account_no FROM customers WHERE team_name = axion_team_name()
    )
  );

-- 쓰기: EA는 submit-balance Edge Function(service_role)이 처리 → anon 직접 접근 차단
-- (아래 주석 해제 시 anon INSERT 허용 — Edge Function 배포 전 임시 허용에 사용)
-- CREATE POLICY "ballog_anon_insert" ON balance_logs
--   FOR INSERT TO anon WITH CHECK (true);


-- ══════════════════════════════════════════
--  partner_programs (파트너별 EA 허용 목록)
-- ══════════════════════════════════════════

ALTER TABLE partner_programs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "pp_select" ON partner_programs
  FOR SELECT TO authenticated
  USING (
    axion_is_super()
    OR partner_id IN (SELECT id FROM partners WHERE email = auth.email())
  );

CREATE POLICY "pp_insert" ON partner_programs
  FOR INSERT TO authenticated WITH CHECK (axion_is_super());

CREATE POLICY "pp_delete" ON partner_programs
  FOR DELETE TO authenticated USING (axion_is_super());


-- ══════════════════════════════════════════
--  latest_balances (VIEW)
--  뷰는 기본적으로 SECURITY DEFINER → RLS 미적용
--  아래 명령으로 security_invoker=on 전환하면 balance_logs RLS 상속
-- ══════════════════════════════════════════

-- Supabase에서 latest_balances 뷰를 SECURITY INVOKER로 재생성 필요:
-- DROP VIEW IF EXISTS latest_balances;
-- CREATE VIEW latest_balances
--   WITH (security_invoker = on)
-- AS
--   SELECT DISTINCT ON (account_no) account_no, balance, equity, profit, logged_at
--   FROM balance_logs
--   ORDER BY account_no, logged_at DESC;
