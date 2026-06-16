-- ============================================================
-- latest_balances view 복구
-- Supabase SQL Editor에서 실행하세요.
-- balance_logs에 데이터가 있는데 파트너 페이지 잔고가 비어 보일 때 사용합니다.
-- ============================================================

DROP VIEW IF EXISTS latest_balances;

CREATE VIEW latest_balances
  WITH (security_invoker = on)
AS
  SELECT DISTINCT ON (account_no)
    TRIM(account_no::text) AS account_no,
    balance,
    equity,
    profit,
    logged_at
  FROM balance_logs
  WHERE account_no IS NOT NULL
  ORDER BY account_no, logged_at DESC;

GRANT SELECT ON latest_balances TO authenticated;

-- 확인용:
-- SELECT * FROM latest_balances ORDER BY logged_at DESC LIMIT 20;
