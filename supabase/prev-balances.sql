-- ============================================================
-- prev_balances 뷰 생성
-- 전일(KST 기준 어제 자정~오늘 자정) 계좌별 마지막 잔고 1행
-- Supabase SQL Editor에서 실행하세요.
-- ============================================================

DROP VIEW IF EXISTS prev_balances;

CREATE VIEW prev_balances AS
SELECT DISTINCT ON (TRIM(account_no::text))
    TRIM(account_no::text) AS account_no,
    balance,
    logged_at
FROM balance_logs
WHERE logged_at >= (date_trunc('day', NOW() AT TIME ZONE 'Asia/Seoul') - INTERVAL '1 day') AT TIME ZONE 'Asia/Seoul'
  AND logged_at <  date_trunc('day', NOW() AT TIME ZONE 'Asia/Seoul') AT TIME ZONE 'Asia/Seoul'
ORDER BY TRIM(account_no::text), logged_at DESC;

GRANT SELECT ON prev_balances TO anon;
GRANT SELECT ON prev_balances TO authenticated;

NOTIFY pgrst, 'reload schema';

-- 확인용:
-- SELECT count(*) FROM prev_balances;
