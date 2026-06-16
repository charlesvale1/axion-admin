-- ============================================================
-- latest_balances 뷰 수정 — SECURITY DEFINER 복구
-- Supabase SQL Editor에서 실행하세요.
--
-- 문제: 이전 버전에서 security_invoker=on 으로 생성하여
--       balance_logs RLS가 적용되어 팀별로만 잔고가 보임.
-- 해결: security_invoker 없이(=SECURITY DEFINER 기본값) 재생성
--       → 뷰 소유자(postgres) 권한으로 실행 → RLS 우회 → 전체 반환
-- ============================================================

-- 1) balance_logs RLS 활성화 및 정책 설정
ALTER TABLE public.balance_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ballog_select ON public.balance_logs;

CREATE POLICY ballog_select
ON public.balance_logs
FOR SELECT
TO authenticated
USING (
  public.axion_is_super()
  OR TRIM(account_no::text) IN (
    SELECT TRIM(account_no::text)
    FROM public.customers_base
    WHERE team_name = public.axion_team_name()
  )
);

-- 2) latest_balances 뷰 재생성 — security_invoker 제거 (SECURITY DEFINER 기본값)
--    SECURITY DEFINER = 뷰 소유자(postgres) 권한으로 실행 → balance_logs RLS 우회
--    → 전체 계좌 잔고 반환 (웹페이지 JS에서 allCustomers 필터로 본인 팀만 표시)
DROP VIEW IF EXISTS latest_balances;

CREATE VIEW latest_balances AS
  SELECT DISTINCT ON (TRIM(account_no::text))
    TRIM(account_no::text) AS account_no,
    balance,
    equity,
    profit,
    logged_at
  FROM balance_logs
  WHERE account_no IS NOT NULL
  ORDER BY TRIM(account_no::text), logged_at DESC;

GRANT SELECT ON latest_balances TO anon;
GRANT SELECT ON latest_balances TO authenticated;

-- PostgREST 스키마 캐시 갱신
NOTIFY pgrst, 'reload schema';

-- 3) 확인용:
-- SELECT count(*) FROM latest_balances;   -- SQL Editor에서는 전체 행 수 표시되어야 함
-- SELECT relname, reloptions FROM pg_class WHERE relname = 'latest_balances';  -- reloptions 없어야 함

-- 고객은 있는데 최신 잔고가 없는 계좌 찾기:
-- SELECT cb.account_no, cb.name, cb.team_name
-- FROM customers_base cb
-- LEFT JOIN latest_balances lb ON TRIM(lb.account_no) = TRIM(cb.account_no::text)
-- WHERE lb.account_no IS NULL
-- ORDER BY cb.team_name, cb.name;
