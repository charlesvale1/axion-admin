# Bolinger_past_kjg3 안전성 수정 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 그리드 마틴게일 EA `mq4/Bolinger_past_kjg3.mq4`에서 라이선스·동의 게이트가 유일한 청산 장치를 가로막는 구조를 제거하고, 통신 장애 유예·고지 팝업 1회·최소 순자산 정지·짧은 타임아웃을 추가한다.

**Architecture:** `OnTick`의 게이트를 뒤집어 `CheckSideBasket`(유일한 청산 장치)을 무조건 먼저 실행하고, 새 `TradingAllowed()`가 신규·추가 진입만 차단한다. 라이선스는 `MaintainLicense()`가 주기(정상 3600초 / 실패 60초)와 유예(`LicenseGraceTries` × 60초)를 전담하고, `BPCheckLicense()`는 순수 조회 후 `g_licenseDenied`로 확정 거부와 일시 장애를 구분해 돌려준다. 라이선스 경로는 기존 Gen 1 직접 REST를 유지한다.

**Tech Stack:** MQL4 (MetaTrader 4 build 1353+), Supabase PostgREST (`/rest/v1/customers`, `/rest/v1/balance_logs`), MetaEditor CLI 컴파일

**설계 문서:** `docs/superpowers/specs/2026-07-15-bolinger-past-kjg3-safety-design.md`

## Global Constraints

- **대상 파일은 `mq4/Bolinger_past_kjg3.mq4` 하나뿐이다.** `mq4/Bolinger_past.mq4`, `mq4/Bolinger_past_kjg2.mq4`, `mq4/Bolinger_past_org.mq4`, `mq4/BB_grid_v1_1.mq4`는 건드리지 않는다.
- **범위 밖 (절대 하지 말 것):** `supabase/functions/check-license/index.ts` 등 서버 코드 수정, 백테스트 지원(`IsTesting()` 분기), anon 키 노출 제거, Gen 2 Edge Function 이전.
- **라이선스 경로는 Gen 1 직접 REST 유지.** `g_ServerUrl + "/rest/v1/customers"` GET, `apikey`/`Authorization` 헤더 유지. `/functions/v1/check-license`로 바꾸지 말 것.
- **파일 인코딩을 바꾸지 말 것.** kjg3는 **BOM 없는 UTF-8**이다(CP949로는 디코딩 불가 — 확인 완료). 기존 한글 주석·문자열이 이미 UTF-8이므로 새로 추가하는 한글도 UTF-8로 쓰고, BOM을 추가하지 말 것. 편집 도구가 CP949로 재저장하면 기존 한글이 전부 깨진다. 작업 후 `python -c "open('mq4/Bolinger_past_kjg3.mq4','rb').read().decode('utf-8')"` 가 예외 없이 통과하는지, 파일 선두 3바이트가 `efbbbf`가 **아닌지** 확인할 것.
- **한글 식별자(`프로그램명`, `서버주소` 등)를 새로 도입하지 말 것.** kjg3는 영문 `g_` 접두사 식별자만 쓴다. 한글 식별자는 BOM을 요구하므로 이 파일의 인코딩과 충돌한다(`mq4/BB_grid_v1_1.mq4`가 한글 식별자 + BOM 조합인 이유다).
- **매매 로직 함수를 수정하지 말 것:** `ProcessClosedCandleSignal`, `ManageAveraging`, `DistanceForStep`, `CheckSideBasket`, `TargetForStep`, `StepLot`, `OpenOrder`, `NormalizeLots`, `IsSpreadOK`, `IsTradeTime`, `NewFirstEntryAllowed`, `EffectiveMaxSteps`.
- **모든 청산은 기존 `CloseSide()`를 쓸 것.** `OrderSelect` + `OrderClose` 루프를 새로 쓰지 말 것 — `CloseSide`가 `IsTargetOrder()`로 Symbol·MagicNumber를 필터하므로 다른 EA·다른 심볼의 포지션을 건드리지 않는다.
- **컴파일 게이트:** 매 작업 종료 시 `Result: 0 errors, 0 warnings`여야 한다. 베이스라인(수정 전)이 0/0이므로 경고가 하나라도 늘면 실패로 간주한다.
- 새 `input` 변수는 기존 스타일(`SETTING__________N` 구분자 + 한글 주석)을 따른다.
- **줄 번호는 수정 전 원본(843줄) 기준이며 작업이 진행되면 밀린다.** Task 3 이후로는 인용된 줄 번호를 신뢰하지 말고, 각 Step이 제시하는 **찾을 코드 조각으로 위치를 특정할 것.** 줄 번호는 대략적 위치 안내일 뿐이다.
- **Task 3의 타임아웃 변경은 Task 4의 `BPCheckLicense` 전체 교체에 포함된다.** Task 4를 먼저 하거나 Task 3을 건너뛰면 안 된다 — 순서대로 진행할 것.

## 컴파일 방법 (모든 작업에서 사용)

```powershell
$me  = "C:\Program Files (x86)\Xlence MetaTrader 4 Terminal\metaeditor.exe"
$src = "C:\Users\kim52\workspace\axion-admin\mq4\Bolinger_past_kjg3.mq4"
$log = "C:\Users\kim52\workspace\axion-admin\compile.log"
& $me "/compile:$src" "/log:$log" | Out-Null
Get-Content $log -Encoding Unicode
Remove-Item $log -ErrorAction SilentlyContinue
```

기대 출력:
```
C:\Users\kim52\workspace\axion-admin\mq4\Bolinger_past_kjg3.mq4 : information: compiling 'Bolinger_past_kjg3.mq4'
Result: 0 errors, 0 warnings, NN msec elapsed
```

**주의 2가지:**
- `metaeditor.exe`의 **종료 코드는 신뢰할 수 없다** — 오류가 0건이어도 `1`을 반환한다. 반드시 로그의 `Result:` 줄을 파싱해 판정할 것.
- 로그 파일은 **UTF-16(Unicode)** 이다. `Get-Content -Encoding Unicode` 없이 읽으면 깨진다.
- 컴파일 산출물 `mq4/Bolinger_past_kjg3.ex4`가 생성된다. 커밋하지 말 것(저장소에 `mq4/Bolinger_past_kjg2.ex4`가 untracked로 있는 것은 기존 상태이며 이번 작업과 무관하다).

## File Structure

| 파일 | 역할 | 이번 작업 |
|---|---|---|
| `mq4/Bolinger_past_kjg3.mq4` | 수정 대상 EA 전체(843줄 → 약 990줄) | Task 2~7에서 수정 |
| `mq4/BB_grid_v1_1.mq4` | 복구된 참조 구현(1102줄). 배포 대상 아님, 읽기 전용 아카이브 | Task 1에서 커밋만 |
| `docs/superpowers/specs/2026-07-15-bolinger-past-kjg3-safety-design.md` | 설계 문서 | Task 1에서 커밋만 |
| `docs/superpowers/plans/2026-07-15-bolinger-past-kjg3-safety.md` | 이 문서 | Task 1에서 커밋만 |

MQL4 EA는 단일 파일이 관례이며 `#include`로 쪼개면 배포가 복잡해지므로 분할하지 않는다. 저장소의 기존 EA 12개 모두 단일 파일이다.

## 검증에 대한 중요 참고

MQL4에는 단위 테스트 프레임워크가 없고, 이 EA는 **백테스트도 불가능하다**(전략 테스터가 Timer 이벤트를 처리하지 않아 `g_licenseOK`가 영원히 false → 진입이 차단됨. 사용자 결정으로 범위 밖). 따라서 이 계획은 TDD를 쓰지 않는다. 각 작업의 자동 게이트는 **컴파일 무경고**이며, 행위 검증은 각 작업 말미의 **수동 검증 절차**로 한다. 수동 검증은 실행자가 아니라 사용자가 MT4에서 수행하므로, 실행자는 절차를 보고만 하고 완료를 가정하지 말 것.

---

### Task 1: 복구본과 문서 보존 커밋

`BB_grid_v1_1.mq4`는 어떤 커밋에도 들어간 적이 없고 dangling blob `56c7c857918a7a3133723857e4e04efa60b9e101`로만 존재한다. `git gc`가 돌면 영구 소실되므로 가장 먼저 커밋한다. 파일은 이미 작업 트리에 기록돼 있다.

**Files:**
- Commit: `mq4/BB_grid_v1_1.mq4` (이미 생성됨, 43261 bytes, UTF-8 BOM)
- Commit: `docs/superpowers/specs/2026-07-15-bolinger-past-kjg3-safety-design.md` (이미 생성됨)
- Commit: `docs/superpowers/plans/2026-07-15-bolinger-past-kjg3-safety.md` (이 문서, 이미 생성됨)

**Interfaces:**
- Consumes: 없음
- Produces: 없음 (보존 목적 전용)

- [ ] **Step 1: 파일이 blob과 바이트 동일한지 검증**

```bash
git hash-object mq4/BB_grid_v1_1.mq4
```

기대 출력: `56c7c857918a7a3133723857e4e04efa60b9e101`

해시가 다르면 **중단하고 보고할 것.** 다시 추출: `git cat-file -p 56c7c857918a7a3133723857e4e04efa60b9e101 > mq4/BB_grid_v1_1.mq4`

- [ ] **Step 2: BOM 확인**

```bash
head -c 3 mq4/BB_grid_v1_1.mq4 | xxd
```

기대 출력: `00000000: efbb bf` — BOM이 없으면 한글 식별자(`프로그램명`, `서버주소`)가 깨지므로 Step 1로 돌아가 재추출할 것.

- [ ] **Step 3: 커밋**

저장소에는 이번 작업과 무관한 스테이징 변경(mq4 파일 rename/add 등)이 이미 다수 있다. **경로를 명시해 그것만 커밋할 것** — `git add .` 이나 `git commit -a`를 쓰지 말 것.

```bash
git add mq4/BB_grid_v1_1.mq4 docs/superpowers/specs/2026-07-15-bolinger-past-kjg3-safety-design.md docs/superpowers/plans/2026-07-15-bolinger-past-kjg3-safety.md
git commit -m "$(cat <<'EOF'
Add: BB_grid_v1_1 참조 구현 복구 및 kjg3 안전성 수정 설계

BB_grid_v1_1.mq4는 커밋된 적 없이 dangling blob으로만 남아 있던
완성본이다. 매매 로직 10개 함수가 Bolinger_past_kjg3와 바이트
동일하며, kjg3에 없는 5개 안전 수정(청산 게이트 분리, 라이선스
유예, 고지 팝업 1회, 잔고 정지, 3초 타임아웃)이 구현돼 있다.
git gc로 유실되기 전에 참조 아카이브로 보존한다. 배포 대상 아님.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: 커밋 내용 확인**

```bash
git show --stat HEAD
```

기대: 파일 3개만 포함(`mq4/BB_grid_v1_1.mq4`, spec, plan). 다른 mq4 파일이 섞여 있으면 `git reset --soft HEAD~1` 후 Step 3을 다시 할 것.

---

### Task 2: 요구사항 1 — 청산을 게이트 앞으로

현재 `OnTick`(277-307행)은 라이선스·동의 게이트에서 early return 하므로 292-293행의 `CheckSideBasket`이 실행되지 않는다. 이 EA는 `OpenOrder`에 `sl=0, tp=0`으로 주문을 넣고 `OrderModify`를 하지 않아 브로커측 보호 장치가 전무하므로, 게이트가 닫히면 보유 그리드가 완전히 방치된다.

**Files:**
- Modify: `mq4/Bolinger_past_kjg3.mq4:110` (`g_licInitDone` 선언 제거)
- Modify: `mq4/Bolinger_past_kjg3.mq4:262-275` (`OnTimer` — `g_licInitDone` 대입 제거, `CheckSideBasket` 이중화 추가)
- Modify: `mq4/Bolinger_past_kjg3.mq4:277-307` (`OnTick` 재구조화)
- Create: `TradingAllowed()` 함수 (`OnTick` 바로 앞에 추가)

**Interfaces:**
- Consumes: 기존 `CheckSideBasket(int orderType)`, `DrawPanel()`, `IsNewBar()`, `ProcessClosedCandleSignal()`, `DrawAutoBollingerBands()`, `ManageAveraging(int orderType)`. 기존 전역 `g_running`, `g_licenseOK`, `g_riskAccepted`.
- Produces: `bool TradingAllowed()` — Task 6이 `g_balanceHalt` 분기를 여기에 추가한다.

- [ ] **Step 1: `g_licInitDone` 선언 제거**

110행의 다음 줄을 삭제한다.

```mql4
bool     g_licInitDone  = false;
```

`g_licenseOK`가 false로 초기화되므로 별도의 "초기화 완료" 플래그는 불필요하다 — 최초 확인 전에는 `g_licenseOK`가 false라 진입이 차단된다.

- [ ] **Step 2: `TradingAllowed()` 추가**

`void OnTick()` 정의(277행) 바로 앞에 삽입한다.

```mql4
//+------------------------------------------------------------------+
//| 매매 허용 조건. 청산은 이 게이트와 무관하게 항상 실행된다.        |
//+------------------------------------------------------------------+
bool TradingAllowed()
{
   if(!g_running)      return false;
   if(!g_licenseOK)    return false;
   if(!g_riskAccepted) return false;
   return true;
}
```

- [ ] **Step 3: `OnTick` 재구조화**

277-307행의 `OnTick` 전체를 아래로 교체한다.

```mql4
void OnTick()
{
   // 이 EA는 브로커측 TP/SL을 심지 않는다(OpenOrder의 sl=0, tp=0).
   // CheckSideBasket이 유일한 청산 장치이므로 라이선스·동의 상태와 무관하게
   // 항상 실행해야 보유 그리드가 방치되지 않는다.
   CheckSideBasket(OP_BUY);
   CheckSideBasket(OP_SELL);

   if(!TradingAllowed())   // 신규 진입·추가 진입만 차단
   {
      if(ShowPanel) DrawPanel();
      return;
   }

   if(IsNewBar())
   {
      ProcessClosedCandleSignal();

      if(ShowAutoBollingerBands)
         DrawAutoBollingerBands();
   }

   ManageAveraging(OP_BUY);
   ManageAveraging(OP_SELL);

   if(ShowPanel) DrawPanel();
}
```

- [ ] **Step 4: `OnTimer` 수정**

262-275행의 `OnTimer` 전체를 아래로 교체한다. `g_licInitDone = true;` 대입이 사라지고, 틱 유실 구간 방어용 `CheckSideBasket` 이중화가 들어간다.

```mql4
void OnTimer()
{
   // 틱이 유실되거나 OnTick이 굶는 구간에서도 최소 1초 해상도로 바스켓을 관리한다.
   // MT4는 처리 중 도착한 틱을 큐잉하지 않고 버리므로, CheckSideBasket이 유일한
   // 청산 장치인 이상 이중화가 필요하다.
   CheckSideBasket(OP_BUY);
   CheckSideBasket(OP_SELL);

   // 위험 고지 (최초 1회)
   if(!g_riskShown)
   {
      g_riskAccepted = BPShowRiskPopup();
      g_riskShown    = true;
   }

   BPCheckLicense();

   BPSendBalance();
}
```

- [ ] **Step 5: 컴파일**

Run: 위 "컴파일 방법" 스니펫
Expected: `Result: 0 errors, 0 warnings`

`g_licInitDone` 관련 `undeclared identifier` 오류가 나면 제거를 놓친 참조가 있는 것이다. `grep -n g_licInitDone mq4/Bolinger_past_kjg3.mq4`로 찾아 제거할 것 — 남아 있으면 안 된다.

- [ ] **Step 6: 커밋**

```bash
git add mq4/Bolinger_past_kjg3.mq4
git commit -m "$(cat <<'EOF'
Fix: 라이선스 실패 시 청산 로직이 중단되던 문제

OnTick의 라이선스·동의 게이트가 최상단에서 early return 하여
CheckSideBasket이 실행되지 않았다. 이 EA는 브로커에 TP/SL을 심지
않으므로(OpenOrder sl=0/tp=0) CheckSideBasket이 유일한 청산
장치이며, 통신이 끊기면 보유 그리드가 TP 가격을 지나가도 청산되지
않았다.

청산을 게이트 앞으로 옮기고 TradingAllowed()가 신규·추가 진입만
차단하도록 뒤집었다. OnTimer에도 CheckSideBasket을 이중화해 틱
유실 구간을 방어한다. g_licenseOK가 false로 초기화되므로
g_licInitDone은 제거했다.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 7: 수동 검증 절차를 사용자에게 보고**

실행자는 아래 절차를 **사용자에게 안내만 하고, 수행 결과를 가정하지 말 것.**

1. `g_ServerUrl`을 잘못된 값(예: `https://invalid.example.com`)으로 임시 변경 후 컴파일·부착 → 패널 LICENSE가 오류로 표시되는지.
2. 그 상태에서 수동으로 BUY 포지션을 열고(매직넘버를 EA와 동일하게) 평가익이 `TPamount_1`(기본 $1)을 넘기도록 대기 → EA가 청산하는지. **수정 전에는 청산되지 않았다** (회귀 대조군).
3. `g_ServerUrl` 원복.

---

### Task 3: 요구사항 5 — WebRequest 타임아웃 3초

`OnTimer`는 `OnTick`과 같은 스레드에서 디스패치되므로 WebRequest가 대기하는 동안 `CheckSideBasket`이 멈춘다. 현재 `OnTimer` 1회는 최악 15초(라이선스 10s + 잔고 5s) EA 스레드를 정지시킨다.

**Files:**
- Modify: `mq4/Bolinger_past_kjg3.mq4:153` (라이선스 GET 10000 → 3000)
- Modify: `mq4/Bolinger_past_kjg3.mq4:222` (잔고 POST 5000 → 3000)

**Interfaces:**
- Consumes: 없음
- Produces: 없음

- [ ] **Step 1: 라이선스 조회 타임아웃 변경**

153행을 찾는다.

```mql4
   int http = WebRequest("GET", url, headers, 10000, post, result, rh);
```

아래로 교체한다(주석 포함).

```mql4
   // 타임아웃을 짧게 잡는다. OnTimer는 OnTick과 같은 스레드이므로 대기하는 동안
   // 유일한 청산 장치인 CheckSideBasket이 멈춘다. 긴 타임아웃은 이득 없이
   // 무관리 구간만 늘린다.
   int http = WebRequest("GET", url, headers, 3000, post, result, rh);
```

- [ ] **Step 2: 잔고 전송 타임아웃 변경**

222행을 찾는다.

```mql4
   int http = WebRequest("POST", g_ServerUrl + "/rest/v1/balance_logs", headers, 5000, post, result, rh);
```

아래로 교체한다.

```mql4
   // 스레드 블로킹 최소화 (CheckSideBasket 정지 방지)
   int http = WebRequest("POST", g_ServerUrl + "/rest/v1/balance_logs", headers, 3000, post, result, rh);
```

- [ ] **Step 3: 다른 WebRequest 호출이 없는지 확인**

```bash
grep -n "WebRequest" mq4/Bolinger_past_kjg3.mq4
```

기대: 2건만 나오고 둘 다 `3000`. 다른 값이 남아 있으면 수정할 것.

- [ ] **Step 4: 컴파일**

Run: 위 "컴파일 방법" 스니펫
Expected: `Result: 0 errors, 0 warnings`

- [ ] **Step 5: 커밋**

```bash
git add mq4/Bolinger_past_kjg3.mq4
git commit -m "$(cat <<'EOF'
Fix: WebRequest 타임아웃 10초/5초 → 3초

OnTimer는 OnTick과 같은 스레드에서 디스패치되므로, WebRequest가
대기하는 동안 유일한 청산 장치인 CheckSideBasket이 멈춘다.
OnTimer 1회가 최악 15초 EA 스레드를 정지시키던 것을 6초로 줄인다.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: 요구사항 2 — 라이선스 통신 실패 유예

현재 `BPCheckLicense`는 실패 시 유예 없이 `g_licenseOK = false`를 즉시 대입한다. 또 168행이 `http != 200`(서버 장애)과 `body == "[]"`(미등록 계좌)를 같은 분기에 넣어 EA가 일시 장애와 확정 거부를 구분할 수 없다.

추가로 136행의 1시간 캐시는 `g_licenseOK &&` 조건이라 **실패 중에는 무력화되어 매 1초 타이머마다 WebRequest가 재발행된다.** 이 작업의 `MaintainLicense` 간격 게이트가 이를 함께 해소한다.

**Files:**
- Modify: `mq4/Bolinger_past_kjg3.mq4:107-113` (상태 변수 추가)
- Modify: `mq4/Bolinger_past_kjg3.mq4:84-86` (input 추가)
- Modify: `mq4/Bolinger_past_kjg3.mq4:134-191` (`BPCheckLicense` 재작성)
- Modify: `mq4/Bolinger_past_kjg3.mq4:195` (`BPSendBalance` 가드 변경)
- Modify: `mq4/Bolinger_past_kjg3.mq4` `OnTimer` (Task 2에서 수정됨 — `BPCheckLicense()` → `MaintainLicense()`)
- Create: `MaintainLicense()` 함수 (`BPCheckLicense` 바로 뒤에 추가)

**Interfaces:**
- Consumes: 기존 `CloseSide(int orderType, string reason)`, `CountSide(int orderType)`, `BPSendBalance(bool force)`. 기존 전역 `g_licenseOK`, `g_licStatusTxt`, `g_lastLicCheck`, `g_riskAccepted`.
- Produces:
  - `bool BPCheckLicense()` — 순수 조회. 성공 시 true. 실패 시 false이며 `g_licenseDenied`로 확정 거부(true) / 일시 장애(false)를 구분한다. **부작용으로 `g_licenseOK`를 대입하지 않는다.**
  - `void MaintainLicense()` — 주기·유예·실효 청산을 전담. `OnTimer`가 매 초 호출.
  - 전역 `bool g_licenseDenied`, `bool g_licenseChecked`, `int g_licenseFailStreak`
  - Task 5가 `MaintainLicense` 내부의 `GlobalVariableSet(RiskConsentKey(), 1)` TTL 갱신 호출을 추가한다.

- [ ] **Step 1: input 추가**

84-86행의 LICENSE / SERVER 그룹을 찾는다.

```mql4
input string SETTING__________12 = "============ LICENSE / SERVER ============";
input bool   SendBalance = true;          // 잔고 서버 전송
input int    SendBalanceMinutes = 5;      // 잔고 전송 주기(분)
```

바로 아래에 한 줄 추가한다.

```mql4
input int    LicenseGraceTries = 5;       // 일시 장애 유예: 연속 실패 이 횟수까지 매매 유지(60초 간격, 상한 30)
```

- [ ] **Step 2: 상태 변수 추가**

107-113행을 찾는다.

```mql4
bool     g_licenseOK    = false;
datetime g_lastLicCheck = 0;
datetime g_lastBalSend  = 0;
string   g_licStatusTxt = "확인 중...";
bool     g_riskAccepted = false;
bool     g_riskShown    = false;
```

(Task 2에서 `g_licInitDone`이 이미 제거된 상태다.) 아래로 교체한다.

```mql4
bool     g_licenseOK    = false;
datetime g_lastLicCheck = 0;   // TimeLocal 기준 — 틱 없는 주말에도 주기가 흘러야 한다
datetime g_lastBalSend  = 0;
string   g_licStatusTxt = "확인 중...";
bool     g_riskAccepted = false;
bool     g_riskShown    = false;

// 라이선스 유예 상태
bool     g_licenseChecked    = false;  // 최초 라이선스 확인 성공 여부
bool     g_licenseDenied     = false;  // 서버가 명시적으로 거부(일시 장애와 구분)
int      g_licenseFailStreak = 0;      // 연속 확인 실패 횟수
```

- [ ] **Step 3: `BPCheckLicense` 재작성**

134-191행의 `BPCheckLicense` 전체를 아래로 교체한다. 1시간 캐시(136-137행)가 사라지고(주기는 `MaintainLicense`가 전담), 실패 종류가 분리되며, `expires_at` null 파싱 버그가 고쳐진다.

```mql4
//+------------------------------------------------------------------+
//| 라이선스 조회 (순수 함수 — g_licenseOK를 대입하지 않는다)         |
//| g_licenseDenied: 서버가 계좌를 명시적으로 거부한 경우에만 true.   |
//| 네트워크/서버 장애는 false로 남겨 유예 로직이 즉시 청산하지 않게. |
//+------------------------------------------------------------------+
bool BPCheckLicense()
{
   g_licenseDenied = false;

   string acct = IntegerToString(AccountNumber());

   string url = g_ServerUrl + "/rest/v1/customers"
              + "?account_no=eq." + acct
              + "&program_name=eq." + g_ProgramName
              + "&is_active=eq.true"
              + "&select=expires_at";

   string headers = "apikey: " + g_ApiKey + "\r\n"
                  + "Authorization: Bearer " + g_ApiKey + "\r\n"
                  + "Content-Type: application/json\r\n";

   char post[]; char result[]; string rh;
   ResetLastError();
   // 타임아웃을 짧게 잡는다. OnTimer는 OnTick과 같은 스레드이므로 대기하는 동안
   // 유일한 청산 장치인 CheckSideBasket이 멈춘다. 긴 타임아웃은 이득 없이
   // 무관리 구간만 늘린다.
   int http = WebRequest("GET", url, headers, 3000, post, result, rh);

   // 네트워크 장애 — 확정 거부가 아니므로 유예 대상
   if(http < 0)
   {
      int err = GetLastError();
      g_licStatusTxt = (err==4060) ? "URL 미등록 (도구>옵션>EA)"
                                   : "네트워크 오류 (" + IntegerToString(err) + ")";
      Print("[License] Program: ", g_ProgramName, " | Account: ", acct,
            " | ERROR err=", IntegerToString(err));
      return(false);
   }

   string body = CharArrayToString(result);
   Print("[License] Program: ", g_ProgramName, " | Account: ", acct,
         " | HTTP: ", IntegerToString(http), " | Body: ", body);

   // 서버 장애(4xx/5xx) — 확정 거부로 취급하지 않는다. 유예 대상.
   if(http != 200)
   {
      g_licStatusTxt = "서버 오류 (HTTP=" + IntegerToString(http) + ")";
      return(false);
   }

   // HTTP 200 + expires_at 없음 → 서버가 판정한 확정 거부(미등록/비활성/EA 미할당).
   // StringFind 결과를 먼저 검사해야 한다. expires_at이 null이면 "\"expires_at\":\""
   // 패턴이 없어 -1이 반환되는데, 이를 검사 없이 +14 하면 엉뚱한 문자열이 잘려
   // 만료 검사를 우연히 통과한다.
   int q = StringFind(body, "\"expires_at\":\"");
   if(q < 0)
   {
      g_licenseDenied = true;
      g_licStatusTxt  = "미등록 계좌";
      return(false);
   }

   string exp = StringSubstr(body, q + 14, 10);
   StringReplace(exp, "-", ".");

   if(exp < TimeToString(TimeCurrent(), TIME_DATE))
   {
      g_licenseDenied = true;
      g_licStatusTxt  = "만료됨 (" + exp + ")";
      return(false);
   }

   g_licStatusTxt = "정상 (" + exp + "까지)";
   Print("[License] OK until ", exp);
   return(true);
}

//+------------------------------------------------------------------+
//| 라이선스 확인/재검증 — 주기와 유예를 전담                          |
//| 간격: 정상 3600초 / 실패 60초. 실효 확정 시 보유 포지션 청산.     |
//+------------------------------------------------------------------+
void MaintainLicense()
{
   // 정상 확인된 상태에서만 1시간 간격. 실패가 시작되면(유예 중 포함) 60초 간격으로
   // 재시도해야 LicenseGraceTries가 의도한 유예 시간(횟수 x 60초)이 된다.
   // 이 게이트가 g_licenseOK와 무관하게 동작하므로, 서버 불통 시 매 초 WebRequest가
   // 재발행되어 EA가 상시 블로킹되던 문제도 함께 해소된다.
   int intervalSec = (g_licenseOK && g_licenseFailStreak == 0) ? 3600 : 60;
   if(g_lastLicCheck != 0 && TimeLocal() - g_lastLicCheck < intervalSec) return;
   g_lastLicCheck = TimeLocal();

   if(BPCheckLicense())
   {
      g_licenseOK         = true;
      g_licenseFailStreak = 0;
      g_licenseChecked    = true;
      return;
   }

   g_licenseFailStreak++;

   // 최초 인증 전 — 매매가 시작된 적이 없으므로 청산할 포지션이 없다
   if(!g_licenseChecked) return;

   // 이미 실효 처리됨 — 직전 청산이 부분 실패했을 수 있으므로 잔여 포지션 재청산
   if(!g_licenseOK)
   {
      if(CountSide(OP_BUY)  > 0) CloseSide(OP_BUY,  "LICENSE_REVOKED");
      if(CountSide(OP_SELL) > 0) CloseSide(OP_SELL, "LICENSE_REVOKED");
      return;
   }

   int graceTries = LicenseGraceTries;
   if(graceTries < 1)  graceTries = 1;
   if(graceTries > 30) graceTries = 30;   // 상한: 무기한 유예로 라이선스를 우회하지 못하도록

   if(!g_licenseDenied && g_licenseFailStreak <= graceTries)
   {
      Print("Bolinger_past: 라이선스 확인 일시 실패 (", g_licenseFailStreak, "/", graceTries,
            ") — 매매 유지 / ", g_licStatusTxt);
      return;
   }

   g_licenseOK = false;
   Print("Bolinger_past: 라이선스 실효 — 전체 청산 후 매매 중단 / ", g_licStatusTxt);
   CloseSide(OP_BUY,  "LICENSE_REVOKED");
   CloseSide(OP_SELL, "LICENSE_REVOKED");
}
```

- [ ] **Step 4: `BPSendBalance` 가드 변경**

195행을 찾는다.

```mql4
   if(!SendBalance || !g_licenseOK) return;
```

아래로 교체한다.

```mql4
   if(!SendBalance) return;
   // g_licenseOK가 아니라 g_licenseChecked로 판정한다. MaintainLicense가 실효
   // 처리 시 g_licenseOK=false를 먼저 대입한 뒤 CloseSide를 부르므로, CloseSide
   // 말미의 BPSendBalance(true)가 g_licenseOK 가드에 걸리면 실효 청산으로 확정된
   // 잔고가 적재되지 않는다. 한 번도 인증된 적 없는 계좌는 여전히 전송하지 않는다.
   if(!g_licenseChecked) return;
```

- [ ] **Step 5: `OnTimer`가 `MaintainLicense`를 부르도록 변경**

Task 2에서 만든 `OnTimer` 안의 다음 줄을 찾는다.

```mql4
   BPCheckLicense();
```

아래로 교체한다.

```mql4
   MaintainLicense();
```

- [ ] **Step 6: 컴파일**

Run: 위 "컴파일 방법" 스니펫
Expected: `Result: 0 errors, 0 warnings`

- [ ] **Step 7: `BPCheckLicense` 직접 호출이 남아 있지 않은지 확인**

```bash
grep -n "BPCheckLicense\|MaintainLicense" mq4/Bolinger_past_kjg3.mq4
```

기대: `BPCheckLicense`는 정의 1건 + `MaintainLicense` 내부 호출 1건, 총 2건. `MaintainLicense`는 정의 1건 + `OnTimer` 호출 1건, 총 2건. `OnTimer`가 `BPCheckLicense`를 직접 부르면 유예가 우회되므로 반드시 확인할 것.

- [ ] **Step 8: 커밋**

```bash
git add mq4/Bolinger_past_kjg3.mq4
git commit -m "$(cat <<'EOF'
Add: 라이선스 서버 통신 실패 시 유예 로직

통신 실패 시 유예 없이 즉시 매매가 차단되던 것을 LicenseGraceTries
(기본 5회 x 60초)만큼 유지하도록 했다. 확정 거부(미등록/만료)는
유예 없이 즉시 실효 처리한다.

- BPCheckLicense를 순수 조회 함수로 분리하고 g_licenseDenied로
  확정 거부와 일시 장애를 구분. 기존 168행이 http!=200(서버 장애)과
  body=="[]"(미등록)를 같은 분기에 넣어 구분이 불가능했다.
- MaintainLicense가 주기(정상 3600초/실패 60초)와 유예를 전담.
  기존 1시간 캐시는 g_licenseOK 조건이라 실패 중 무력화되어 매 초
  WebRequest가 재발행되던 문제도 함께 해소된다.
- expires_at이 null일 때 StringFind의 -1을 검사 없이 +14 하여 만료
  검사를 우연히 통과하던 버그 수정. 운영 DB에 해당 레코드가 없음을
  확인했다.
- BPSendBalance 가드를 g_licenseChecked 기준으로 변경. 실효 청산으로
  확정된 잔고가 적재되지 않던 문제 수정.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 9: 수동 검증 절차를 사용자에게 보고**

실행자는 아래 절차를 **사용자에게 안내만 하고, 수행 결과를 가정하지 말 것.**

1. 정상 부착 후 라이선스 통과 확인 → 포지션이 열린 상태를 만든다.
2. 네트워크를 끊거나 `g_ServerUrl`을 무효값으로 변경 → Experts 로그에 `라이선스 확인 일시 실패 (1/5)`가 찍히고, **60초 간격**으로 `(2/5)`, `(3/5)`… 로 증가하는지. 이 동안 포지션이 유지되는지.
3. `(5/5)` 이후 다음 실패에서 `라이선스 실효 — 전체 청산 후 매매 중단`이 찍히고 포지션이 청산되는지.
4. 로그 간격이 1초가 아니라 60초인지 확인(수정 전에는 1초마다 재요청).

---

### Task 5: 요구사항 3 — 위험 고지 팝업 최초 1회

`g_riskShown`은 프로그램 전역변수라 리컴파일·심볼/주기 변경·파라미터 변경·계좌 재접속·템플릿 적용마다 리셋되어 팝업이 재발한다. 터미널 GlobalVariable로 계좌별 동의를 영구 기록한다.

또 `MessageBox`는 모달이라 사용자가 클릭할 때까지 EA의 단일 스레드를 붙잡는다. 그동안 `OnTick`이 실행되지 않아 `CheckSideBasket`이 멈추므로 — Task 2에서 고친 바로 그 문제 — 보유 포지션이 있으면 팝업을 보류한다.

**Files:**
- Modify: `mq4/Bolinger_past_kjg3.mq4` 상태 변수 블록 (`g_riskShown` → `g_riskPrompted`, `g_riskDeferred`)
- Create: `RiskConsentKey()`, `PromptRiskDisclosure()` 함수 (`BPShowRiskPopup` 바로 뒤에 추가)
- Modify: `mq4/Bolinger_past_kjg3.mq4` `OnTimer` (팝업 블록 교체)
- Modify: `mq4/Bolinger_past_kjg3.mq4` `MaintainLicense` (TTL 갱신 추가)

**Interfaces:**
- Consumes: 기존 `BPShowRiskPopup()`, `CountSide(int orderType)`. 기존 input `ShowKoreanRiskPopup`.
- Produces: `string RiskConsentKey()`, `bool PromptRiskDisclosure()`, 전역 `bool g_riskPrompted`, `bool g_riskDeferred`

- [ ] **Step 1: 상태 변수 교체**

`bool     g_riskShown    = false;` 를 찾아 아래로 교체한다.

```mql4
bool     g_riskPrompted = false;  // 위험고지 모달을 이미 띄웠는지(세션 내 재표시 방지)
bool     g_riskDeferred = false;  // 보유 포지션으로 모달을 보류한 상태
```

- [ ] **Step 2: `RiskConsentKey()`와 `PromptRiskDisclosure()` 추가**

`BPShowRiskPopup()` 함수 정의가 끝나는 곳(132행 `}` 부근) 바로 뒤에 삽입한다.

```mql4
//+------------------------------------------------------------------+
//| 위험고지 동의 — 계좌당 최초 1회만 팝업                            |
//+------------------------------------------------------------------+
string RiskConsentKey()
{
   return("BOLINGER_PAST_RISK_OK_" + IntegerToString((int)AccountNumber()));
}

bool PromptRiskDisclosure()
{
   if(g_riskAccepted) return(true);
   if(!ShowKoreanRiskPopup) { g_riskAccepted = true; return(true); }

   // 이 계좌에서 이미 동의했으면 다시 묻지 않는다.
   string key = RiskConsentKey();
   if(GlobalVariableCheck(key))
   {
      GlobalVariableSet(key, 1);   // MT4는 4주 미사용 시 삭제 — 접근 시각 갱신
      g_riskAccepted = true;
      g_riskDeferred = false;
      return(true);
   }

   if(g_riskPrompted) return(false);   // 이미 물었고 거부당했다

   // 보유 포지션이 있으면 모달을 띄우지 않는다. MessageBox는 모달이라 스레드를
   // 잡으며, 그동안 유일한 청산 장치인 CheckSideBasket이 멈춰 그리드가 방치된다.
   // 청산 관리를 계속하면서 플랫이 될 때까지 팝업을 미룬다.
   // (신규 진입은 g_riskAccepted=false 이므로 TradingAllowed()가 계속 차단한다.)
   if(CountSide(OP_BUY) + CountSide(OP_SELL) > 0)
   {
      if(!g_riskDeferred)
      {
         g_riskDeferred = true;
         Print("Bolinger_past: 보유 포지션이 있어 위험고지 팝업을 보류합니다 — 청산 관리는 계속됩니다");
         Alert("Bolinger_past: 위험고지 동의 필요 — 보유 포지션 청산 후 팝업이 표시됩니다");
      }
      return(false);
   }

   g_riskPrompted = true;
   g_riskDeferred = false;

   if(BPShowRiskPopup())
   {
      g_riskAccepted = true;
      GlobalVariableSet(key, 1);
      return(true);
   }
   return(false);
}
```

- [ ] **Step 3: `OnTimer`의 팝업 블록 교체**

Task 2에서 만든 `OnTimer` 안의 다음 블록을 찾는다.

```mql4
   // 위험 고지 (최초 1회)
   if(!g_riskShown)
   {
      g_riskAccepted = BPShowRiskPopup();
      g_riskShown    = true;
   }

   MaintainLicense();
```

아래로 교체한다. 순서가 바뀐다 — 라이선스를 먼저 확인하고, 통과한 계좌에만 고지를 묻는다.

```mql4
   MaintainLicense();

   // 라이선스 확인 후에도 미동의 상태면 계속 시도한다. 포지션 보유 중에는 팝업이
   // 보류되므로, 플랫이 되는 즉시 팝업이 뜨도록 매 초 확인한다.
   if(g_licenseOK && !g_riskAccepted)
      PromptRiskDisclosure();
```

- [ ] **Step 4: `MaintainLicense`에 TTL 갱신 추가**

Task 4에서 만든 `MaintainLicense` 안의 성공 분기를 찾는다.

```mql4
   if(BPCheckLicense())
   {
      g_licenseOK         = true;
      g_licenseFailStreak = 0;
      g_licenseChecked    = true;
      return;
   }
```

아래로 교체한다.

```mql4
   if(BPCheckLicense())
   {
      g_licenseOK         = true;
      g_licenseFailStreak = 0;
      g_licenseChecked    = true;

      // 동의 기록의 접근 시각을 주기적으로 갱신한다. 갱신이 부착 시점에만 일어나면
      // 4주 넘게 무중단 가동할 때 MT4가 변수를 삭제해, 다음 재부착에서 모달이 뜬다.
      if(g_riskAccepted) GlobalVariableSet(RiskConsentKey(), 1);
      return;
   }
```

- [ ] **Step 5: `g_riskShown` 잔존 참조 확인**

```bash
grep -n "g_riskShown" mq4/Bolinger_past_kjg3.mq4
```

기대: 출력 없음. 남아 있으면 컴파일이 깨진다.

- [ ] **Step 6: 컴파일**

Run: 위 "컴파일 방법" 스니펫
Expected: `Result: 0 errors, 0 warnings`

- [ ] **Step 7: 커밋**

```bash
git add mq4/Bolinger_past_kjg3.mq4
git commit -m "$(cat <<'EOF'
Fix: 위험 고지 팝업을 계좌당 최초 1회만 표시

g_riskShown은 프로그램 전역변수라 리컴파일·주기 변경·파라미터
변경·계좌 재접속·템플릿 적용마다 리셋되어 팝업이 재발했다.
GlobalVariable("BOLINGER_PAST_RISK_OK_"+계좌번호)로 동의를 영구
기록한다. MT4는 4주 미사용 시 변수를 삭제하므로 라이선스 확인
성공 시마다 접근 시각을 갱신한다.

보유 포지션이 있으면 팝업을 보류한다. MessageBox는 모달이라 EA의
단일 스레드를 붙잡고, 그동안 유일한 청산 장치인 CheckSideBasket이
멈춰 그리드가 방치되기 때문이다. 보류 중에는 Alert로 안내하고
플랫이 되면 팝업을 띄운다. 신규 진입은 TradingAllowed()가 계속
차단한다.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 8: 수동 검증 절차를 사용자에게 보고**

실행자는 아래 절차를 **사용자에게 안내만 하고, 수행 결과를 가정하지 말 것.**

1. 부착 → 팝업 → 예 클릭. 차트 주기를 M15로 바꿔 재초기화 → 팝업이 뜨지 않는지.
2. 터미널을 완전히 종료 후 재시작 → 팝업이 뜨지 않는지.
3. MT4 도구 > 글로벌 변수(F3)에서 `BOLINGER_PAST_RISK_OK_<계좌번호>`가 보이는지. 삭제 후 EA 재부착 → 팝업이 다시 뜨는지.
4. 포지션이 있는 상태에서 F3로 키를 삭제하고 EA 재부착 → **팝업 대신 Alert**가 뜨고, Experts 로그에 `보유 포지션이 있어 위험고지 팝업을 보류합니다`가 찍히며, 포지션 청산 관리가 계속 도는지. 청산 후 플랫이 되면 팝업이 뜨는지.

---

### Task 6: 요구사항 4 — 잔고/순자산 최소값 도달 시 청산 후 종료

`AccountBalance()`는 실현 결과만 반영하고 미결제 평가손익을 포함하지 않는다. 이 EA는 손실 중인 방향에 계속 물타기하므로, 잔고 $200에 10차수가 -$160 물린 상황에서 Balance는 $200이고 Equity는 $40이다. Balance 기준만으로는 계좌가 녹는 동안 발동하지 않으므로 Equity를 주 기준으로 하고 Balance를 병행한다.

**Files:**
- Modify: `mq4/Bolinger_past_kjg3.mq4` input 블록 (`MinEquityStop` 추가)
- Modify: `mq4/Bolinger_past_kjg3.mq4` 상태 변수 블록 (`g_balanceHalt` 추가)
- Create: `CheckBalanceStop()` 함수 (`TradingAllowed` 바로 앞에 추가)
- Modify: `mq4/Bolinger_past_kjg3.mq4` `TradingAllowed()` (halt 분기 추가)
- Modify: `mq4/Bolinger_past_kjg3.mq4` `OnTick` (최상단 호출 추가)
- Modify: `mq4/Bolinger_past_kjg3.mq4` `OnTimer` (halt 시 조기 반환)
- Modify: `mq4/Bolinger_past_kjg3.mq4:254-260` (`OnDeinit` — 종료 사유 Comment 유지)

**Interfaces:**
- Consumes: 기존 `CloseSide(int orderType, string reason)`, `CountSide(int orderType)`. Task 2의 `TradingAllowed()`.
- Produces: `void CheckBalanceStop()`, 전역 `bool g_balanceHalt`, input `double MinEquityStop`

- [ ] **Step 1: input 추가**

Task 4에서 `LicenseGraceTries`를 추가한 LICENSE / SERVER 그룹 **뒤에** 새 그룹을 추가한다.

```mql4
input string SETTING__________13 = "============ MIN EQUITY STOP ============";
input double MinEquityStop = 50.0;        // 순자산/잔고가 이 값 이하면 전체 청산 후 EA 종료 (0=비활성)
```

- [ ] **Step 2: 상태 변수 추가**

Task 4에서 추가한 라이선스 유예 상태 블록 뒤에 한 줄 추가한다.

```mql4
bool     g_balanceHalt       = false;  // MinEquityStop 도달로 정지한 상태
```

- [ ] **Step 3: `CheckBalanceStop()` 추가**

Task 2에서 만든 `TradingAllowed()` 정의 **바로 앞에** 삽입한다.

```mql4
//+------------------------------------------------------------------+
//| 순자산/잔고 최소값 도달 → 이 EA의 포지션 청산 후 EA 종료          |
//+------------------------------------------------------------------+
void CheckBalanceStop()
{
   if(!g_balanceHalt)
   {
      if(MinEquityStop <= 0) return;
      if(AccountEquity() > MinEquityStop && AccountBalance() > MinEquityStop) return;

      g_balanceHalt = true;
      g_running     = false;
      Print(">>> Bolinger_past: 순자산/잔고 ", DoubleToString(MinEquityStop, 2),
            " 이하 도달 — 전체 청산 후 EA 종료 / Equity=", DoubleToString(AccountEquity(), 2),
            " / Balance=", DoubleToString(AccountBalance(), 2));
   }

   // halt 상태에서는 잔여 포지션이 없어질 때까지 매 틱 재시도한다.
   // CloseSide는 IsTargetOrder()로 Symbol·MagicNumber를 필터하므로 다른 EA나
   // 다른 심볼의 포지션은 건드리지 않는다.
   if(CountSide(OP_BUY)  > 0) CloseSide(OP_BUY,  "MIN_EQUITY_STOP");
   if(CountSide(OP_SELL) > 0) CloseSide(OP_SELL, "MIN_EQUITY_STOP");

   // 청산이 끝나기 전에 EA를 제거하면 남은 포지션이 브로커측 TP/SL 없이 방치된다.
   if(CountSide(OP_BUY) > 0 || CountSide(OP_SELL) > 0)
   {
      Comment("Bolinger_past: 순자산/잔고 " + DoubleToString(MinEquityStop, 2) + " 이하 — 청산 재시도 중");
      return;
   }

   Comment("Bolinger_past: 순자산/잔고 " + DoubleToString(MinEquityStop, 2) + " 이하 — EA 종료됨");
   ExpertRemove();
}
```

- [ ] **Step 4: `TradingAllowed()`에 halt 분기 추가**

Task 2에서 만든 `TradingAllowed()`를 찾아 아래로 교체한다.

```mql4
bool TradingAllowed()
{
   if(!g_running)      return false;
   if(g_balanceHalt)   return false;
   if(!g_licenseOK)    return false;
   if(!g_riskAccepted) return false;
   return true;
}
```

- [ ] **Step 5: `OnTick` 최상단에 호출 추가**

Task 2에서 만든 `OnTick`의 첫 두 줄을 찾는다.

```mql4
void OnTick()
{
   // 이 EA는 브로커측 TP/SL을 심지 않는다(OpenOrder의 sl=0, tp=0).
```

아래로 교체한다. `ExpertRemove()`는 즉시 중단하지 않고 중단 플래그만 세우므로 현재 핸들러가 끝까지 실행된다 — 아래 진입 로직이 한 번 더 도는 것을 `g_balanceHalt` 반환으로 막는다.

```mql4
void OnTick()
{
   CheckBalanceStop();
   if(g_balanceHalt)
   {
      if(ShowPanel) DrawPanel();
      return;
   }

   // 이 EA는 브로커측 TP/SL을 심지 않는다(OpenOrder의 sl=0, tp=0).
```

- [ ] **Step 6: `OnTimer` 최상단에 halt 반환 추가**

Task 2/4/5를 거친 `OnTimer`의 첫 줄을 찾는다.

```mql4
void OnTimer()
{
   // 틱이 유실되거나 OnTick이 굶는 구간에서도 최소 1초 해상도로 바스켓을 관리한다.
```

아래로 교체한다.

```mql4
void OnTimer()
{
   if(g_balanceHalt) return;   // 청산·종료는 OnTick의 CheckBalanceStop이 전담한다

   // 틱이 유실되거나 OnTick이 굶는 구간에서도 최소 1초 해상도로 바스켓을 관리한다.
```

- [ ] **Step 7: `OnDeinit`에서 종료 사유 유지**

254-260행의 `OnDeinit`을 찾는다.

```mql4
void OnDeinit(const int reason)
{
   EventKillTimer();
   DeletePanel();
   DeleteBandObjects();
   Print("Bolinger_past deinitialized / reason=", reason);
}
```

아래로 교체한다. `ExpertRemove()`는 `OnDeinit`을 호출하므로, `Comment`를 무조건 지우면 `CheckBalanceStop`이 방금 쓴 안내까지 사라져 사용자에게는 EA가 이유 없이 없어진 것처럼 보인다.

```mql4
void OnDeinit(const int reason)
{
   EventKillTimer();
   DeletePanel();
   DeleteBandObjects();

   // 잔고 소진으로 스스로 종료한 경우에는 사유를 화면에 남긴다.
   Comment(g_balanceHalt
           ? "Bolinger_past: 순자산/잔고 " + DoubleToString(MinEquityStop, 2) + " 이하 — EA 종료됨"
           : "");

   Print("Bolinger_past deinitialized / reason=", reason);
}
```

- [ ] **Step 8: 컴파일**

Run: 위 "컴파일 방법" 스니펫
Expected: `Result: 0 errors, 0 warnings`

- [ ] **Step 9: 커밋**

```bash
git add mq4/Bolinger_past_kjg3.mq4
git commit -m "$(cat <<'EOF'
Add: 순자산/잔고 MinEquityStop 이하 시 청산 후 EA 종료

MinEquityStop input(기본 50.0, 0=비활성)을 추가하고 Equity 또는
Balance 중 하나라도 이하면 이 EA의 포지션을 전량 청산한 뒤
ExpertRemove()한다.

AccountBalance()는 미결제 평가손익을 포함하지 않아, 마틴게일
그리드에서 계좌가 녹는 동안에는 발동하지 않고 손실이 실현된 뒤에야
도는 사후 로직이 된다(잔고 $200 / 10차수 -$160 물림 → Balance
$200, Equity $40). 위험을 잡을 수 있는 값은 Equity뿐이므로 Equity를
주 기준으로 하고 Balance를 병행한다. 저장소의 기존 6개 EA는 Balance
기준 $50 하드코딩이며, 이는 의도된 차이다.

기존 6개 EA의 CheckBalanceStop을 복사하지 않았다. 그 구현은
Symbol/MagicNumber를 필터하지 않아 다른 EA와 다른 심볼의 포지션까지
청산하고, 청산 성공 여부를 확인하지 않고 ExpertRemove를 불러 청산
실패 시 포지션이 방치된다. 여기서는 기존 CloseSide()를 쓰고 잔여
포지션 0을 확인한 뒤에만 EA를 제거한다.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 10: 수동 검증 절차를 사용자에게 보고**

실행자는 아래 절차를 **사용자에게 안내만 하고, 수행 결과를 가정하지 말 것.**

1. **데모 계좌에서** `MinEquityStop`을 현재 Equity 바로 아래 값으로 설정하고 EA 부착 → 발동하지 않는지.
2. 다른 매직넘버로 수동 포지션을 하나 열어 둔다.
3. `MinEquityStop`을 현재 Equity 바로 **위** 값으로 변경 → EA 포지션만 청산되고 **수동 포지션은 남아 있는지**, EA가 차트에서 제거되는지, 화면에 `EA 종료됨` Comment가 남는지.
4. Experts 로그에 `순자산/잔고 … 이하 도달` 과 Equity/Balance 값이 찍히는지.
5. `MinEquityStop = 0`으로 두면 발동하지 않는지.

---

### Task 7: 패널 상태 표시 정리

패널이 `g_running`만 보고 `RUNNING`/`PAUSED`를 표시하므로, 유예 중·보류 중·halt 상태가 구분되지 않는다. 사용자가 EA 상태를 오해하지 않도록 상태 문자열을 조립한다.

**Files:**
- Create: `PanelStatusText()` 함수 (`DrawPanel` 바로 앞에 추가)
- Modify: `mq4/Bolinger_past_kjg3.mq4:731` (STATUS 줄)

**Interfaces:**
- Consumes: 전역 `g_balanceHalt`, `g_licenseOK`, `g_licenseChecked`, `g_licenseFailStreak`, `g_riskAccepted`, `g_riskDeferred`, `g_running`, `g_lastLicCheck`
- Produces: `string PanelStatusText()`

- [ ] **Step 1: `PanelStatusText()` 추가**

`void DrawPanel()` 정의 바로 앞에 삽입한다.

```mql4
//+------------------------------------------------------------------+
//| 패널 STATUS 줄 — 정지 사유를 구분해 표시한다                      |
//+------------------------------------------------------------------+
string PanelStatusText()
{
   if(g_balanceHalt)              return("HALTED (MIN EQUITY)");
   if(g_lastLicCheck == 0)        return("LICENSE 확인 중");
   if(!g_licenseChecked)          return("NO LICENSE");
   if(!g_licenseOK)               return("LICENSE 실효 - 청산됨");
   if(g_licenseFailStreak > 0)    return("LICENSE 재확인 중 (유예)");
   if(g_riskDeferred)             return("위험고지 대기 (청산만 관리)");
   if(!g_riskAccepted)            return("위험고지 미동의");
   if(!g_running)                 return("PAUSED");
   return("RUNNING");
}
```

- [ ] **Step 2: STATUS 줄 교체**

731행을 찾는다.

```mql4
   SetPanelLine(line++, "STATUS        : " + (g_running ? "RUNNING" : "PAUSED"), g_running ? clrLime : clrTomato, 9);
```

아래로 교체한다.

```mql4
   bool statusOK = (g_running && g_licenseOK && g_riskAccepted && !g_balanceHalt);
   SetPanelLine(line++, "STATUS        : " + PanelStatusText(), statusOK ? clrLime : clrTomato, 9);
```

- [ ] **Step 3: 컴파일**

Run: 위 "컴파일 방법" 스니펫
Expected: `Result: 0 errors, 0 warnings`

- [ ] **Step 4: 최종 전체 확인**

```bash
grep -n "g_licInitDone\|g_riskShown" mq4/Bolinger_past_kjg3.mq4
```

기대: 출력 없음(제거된 변수).

```bash
grep -n "WebRequest" mq4/Bolinger_past_kjg3.mq4
```

기대: 2건, 둘 다 타임아웃 `3000`.

```bash
grep -c "OrderClose" mq4/Bolinger_past_kjg3.mq4
```

기대: `1` — `CloseSide` 안의 1건뿐. 새 청산 루프를 만들지 않았음을 확인한다.

- [ ] **Step 5: 커밋**

```bash
git add mq4/Bolinger_past_kjg3.mq4
git commit -m "$(cat <<'EOF'
Add: 패널 STATUS에 정지 사유 표시

g_running만 보고 RUNNING/PAUSED를 표시하던 것을, 유예 중·고지 보류
중·MinEquityStop halt·라이선스 실효를 구분해 표시하도록 했다.
청산만 관리되는 상태와 완전 정지 상태를 사용자가 구분할 수 있어야
한다.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 6: 최종 수동 검증 절차를 사용자에게 보고**

Task 2·4·5·6의 수동 검증을 아직 수행하지 않았다면 여기서 일괄 안내한다. 특히 **실계좌 배포 전 데모 계좌에서 Task 6의 절차(다른 매직넘버 포지션 보존 확인)를 반드시 수행할 것.**

---

## 완료 조건

- Task 1~7의 모든 커밋이 완료됐다.
- `mq4/Bolinger_past_kjg3.mq4`가 `0 errors, 0 warnings`로 컴파일된다.
- `mq4/Bolinger_past.mq4`, `mq4/Bolinger_past_kjg2.mq4`, `mq4/Bolinger_past_org.mq4`, `mq4/BB_grid_v1_1.mq4`, `supabase/` 이하 파일이 수정되지 않았다(`git log --stat`로 확인).
- 수동 검증 절차가 사용자에게 보고됐다. **실행자가 수동 검증 완료를 가정하거나 대신 선언하지 말 것.**
