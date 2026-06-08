-- ============================================================
-- DB 마이그레이션: 복수 EA 라이센스 동시 지원
-- ============================================================
-- 목적: 기존 배포된 EA가 쿼리하는 /rest/v1/customers 엔드포인트를
--        뷰(VIEW)로 교체하여, 한 고객이 여러 EA를 동시에 가져도
--        각 EA의 라이센스 체크가 모두 통과되도록 함.
--
-- 실행 방법: Supabase 대시보드 → SQL Editor에 전체 붙여넣고 실행
-- ============================================================

-- ── Step 1: customers 테이블을 customers_base로 이름 변경 ─────────
-- 기존 인덱스, FK, RLS 정책, 시퀀스가 자동으로 customers_base에 따라 이동

ALTER TABLE customers RENAME TO customers_base;


-- ── Step 2: customers VIEW 생성 ──────────────────────────────────
-- LEFT JOIN: customer_programs 항목이 있으면 EA당 1행 반환 (복수 라이센스)
--            customer_programs 항목이 없으면 기존 program_name 열 그대로 사용 (하위 호환)
--
-- 결과: ?program_name=eq.CROSSOVER&account_no=eq.X&is_active=eq.true → 1행 매칭
--       동시에 ?program_name=eq.ELDORADO&account_no=eq.X&is_active=eq.true → 1행 매칭
--       두 EA 라이센스가 동시에 유효

CREATE OR REPLACE VIEW customers AS
SELECT
  cb.id,
  cb.account_no,
  cb.name,
  COALESCE(p.name, cb.program_name)  AS program_name,
  COALESCE(p.id,   cb.program_id)    AS program_id,
  cb.is_active,
  cb.created_at,
  cb.expires_at,
  cb.memo,
  cb.team_name,
  cb.registered_by
  -- ⚠️ customers_base에 balance, balance_updated_at 컬럼이 있으면 아래 주석 해제:
  -- , cb.balance
  -- , cb.balance_updated_at
FROM customers_base cb
LEFT JOIN customer_programs cp ON cp.customer_id = cb.id
LEFT JOIN programs p            ON p.id = cp.program_id;


-- ── Step 3: 권한 설정 ────────────────────────────────────────────
-- anon  : 기존 EA가 사용하는 역할 → VIEW SELECT 허용
-- authenticated: 웹 페이지가 사용하는 역할

GRANT SELECT ON customers TO anon;
GRANT SELECT ON customers TO authenticated;

-- customers_base 직접 쓰기 권한 (웹 페이지 INSERT/UPDATE/DELETE)
GRANT ALL ON customers_base TO authenticated;


-- ── Step 4: 검증 쿼리 ────────────────────────────────────────────
-- 실행 후 아래 쿼리로 뷰가 올바르게 동작하는지 확인

-- 1) VIEW가 복수 EA를 올바르게 확장하는지
-- SELECT id, account_no, name, program_name, is_active
-- FROM customers
-- ORDER BY account_no, program_name
-- LIMIT 20;

-- 2) 특정 EA 라이센스 체크 시뮬레이션
-- SELECT * FROM customers
-- WHERE program_name = 'EA이름을여기에'
--   AND account_no   = '계좌번호를여기에'
--   AND is_active    = true;
