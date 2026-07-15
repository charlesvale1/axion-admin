# Bolinger_past_kjg3 안전성 수정 설계

작성일: 2026-07-15
대상 파일: `mq4/Bolinger_past_kjg3.mq4`

## 배경

`Bolinger_past_kjg3.mq4`는 볼린저밴드 돌파로 진입한 뒤 설정 간격마다 주문을 적층하는 그리드 마틴게일 EA다. **브로커측 TP/SL을 심지 않으므로**(`OpenOrder`의 `sl=0, tp=0`, `OrderModify` 없음) `CheckSideBasket`이 유일한 청산 장치다. 현재 `OnTick`은 라이선스·동의 게이트를 최상단에 두고 early return 하므로, 게이트를 통과하지 못하면 청산이 실행되지 않는다. 인터넷이 잠시 끊기면 10차수 물린 그리드가 TP 가격을 지나가도 아무도 닫지 않는다.

이 문서는 5개 수정 사항의 설계를 기술한다.

### 조사에서 확인된 사실

- `mq4/Bolinger_past_kjg2.mq4`는 참조 구현이 **아니다** — kjg3와 바이트 동일한 사본이다(sha256 `6722380850b5a2…`).
- 5건이 모두 구현된 완성본 `BB_grid_v1_1.mq4`(1102줄)가 존재하나 **커밋된 적이 없어** git dangling blob `56c7c857918a7a3133723857e4e04efa60b9e101` 로만 남아 있다. 매매 로직 10개 함수가 kjg3와 바이트 동일하다. 이 문서의 설계는 해당 blob을 참조 원본으로 삼는다.
- kjg3의 Gen 1 직접 REST 방식은 **잔고 전송·라이선스 조회 모두 현재 정상 동작한다**(2026-07-15 실측 확인). `supabase/rls-setup.sql:165-166`의 anon INSERT 정책이 파일상 주석 처리돼 있으나 라이브 DB에는 적용돼 있다 — 저장소 SQL 파일은 실행 대기 스크립트이지 DB 상태가 아니다.

## 설계 결정

### 기반: kjg3 + Gen 1 직접 REST 유지

복구본은 Gen 2 Edge Function(`/functions/v1/check-license`)을 쓰지만 채택하지 않는다. Gen 2에는 미해결 서버 결함이 둘 있다.

1. `check-license`가 DB 오류를 `HTTP 200 + authorized:false`로 반환한다(`index.ts`의 `err1`/`err2` 분기). 거부 사유 문자열도 미등록 계좌와 동일해 EA에서 일시 장애와 확정 거부를 구분할 수 없다. **즉 EA에 유예 로직을 넣어도 서버가 무력화한다** — 요구사항 2번이 성립하지 않는다.
2. `.maybeSingle()`이 `customers` 뷰(복수 행 반환)와 충돌해 EA를 2개 이상 보유한 고객은 인증이 통과되지 않는다.

Gen 1 직접 REST는 서버가 상태 코드를 그대로 돌려주므로 일시 장애와 확정 거부가 EA에서 구분 가능하고, `program_name=eq.` 필터로 행이 1개로 좁혀져 복수 EA 문제도 없다. Gen 1의 단점은 anon 키가 EA에 노출된다는 점이나(`customers` 뷰에 `security_invoker`가 없어 전 고객 정보 열람 가능), 이는 이번 5건과 별개의 보안 사안으로 범위 밖이다.

**범위 밖**: 서버(`supabase/functions/check-license/index.ts`) 수정, 백테스트 지원, anon 키 노출.

### 복구본 보존

`BB_grid_v1_1.mq4`를 `mq4/BB_grid_v1_1.mq4`로 커밋해 blob GC로 인한 영구 소실을 막는다. 배포 대상이 아닌 참조 아카이브다. UTF-8 BOM을 유지해야 한다(한글 식별자 `프로그램명`/`서버주소` 사용 — BOM 없이는 MetaEditor가 CP949로 읽어 컴파일이 깨진다).

## 상태 변수

기존 `g_licenseOK`, `g_licStatusTxt`, `g_riskAccepted`를 유지하고 다음을 추가한다. `g_licInitDone`과 `g_riskShown`은 제거한다 — 전자는 `g_licenseOK`가 false로 초기화되므로 불필요하고, 후자는 `g_riskPrompted` + GlobalVariable 영속 기록으로 대체된다. `g_lastLicCheck`는 유지하되 기준 시각을 바꾼다.

| 변수 | 용도 |
|---|---|
| `g_licenseChecked` | 최초 라이선스 확인 성공 여부. 최초 인증 전에는 청산할 포지션이 없으므로 실효 처리를 건너뛰는 데 쓴다 |
| `g_licenseDenied` | 서버가 **명시적으로** 거부한 경우에만 true. 네트워크·서버 장애는 false로 남겨 유예가 동작하게 한다 |
| `g_licenseFailStreak` | 연속 확인 실패 횟수 |
| `g_riskPrompted` | 위험고지 모달을 이미 띄웠는지(세션 내 재표시 방지) |
| `g_riskDeferred` | 보유 포지션 때문에 모달을 보류한 상태 |
| `g_balanceHalt` | `MinEquityStop` 도달로 정지한 상태 |
| `g_lastLicCheck` | `TimeLocal()` 기준으로 변경 — 틱이 없는 주말에도 주기가 흘러야 한다 |

## 1. 청산을 게이트 앞으로

`OnTick`의 구조를 뒤집는다. 청산은 무조건 실행하고, 게이트는 신규·추가 진입만 막는다.

```mql4
void OnTick()
{
   CheckBalanceStop();
   if(g_balanceHalt) { if(ShowPanel) DrawPanel(); return; }

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
      if(ShowAutoBollingerBands) DrawAutoBollingerBands();
   }

   ManageAveraging(OP_BUY);
   ManageAveraging(OP_SELL);

   if(ShowPanel) DrawPanel();
}

bool TradingAllowed()
{
   if(!g_running)      return false;
   if(g_balanceHalt)   return false;
   if(!g_licenseOK)    return false;
   if(!g_riskAccepted) return false;
   return true;
}
```

`g_licenseOK`는 false로 초기화되므로 `g_licInitDone` 플래그는 불필요하다 — 최초 확인 전에는 `g_licenseOK`가 false라 진입이 차단된다.

`OnTimer`에도 `CheckSideBasket`을 이중화한다. 틱이 유실되거나 `OnTick`이 굶는 구간에서도 최소 1초 해상도로 바스켓을 관리하기 위함이다(MT4는 처리 중 도착한 틱을 큐잉하지 않고 버린다).

## 2. 라이선스 통신 실패 시 유예

### 입력

```mql4
input int LicenseGraceTries = 5;   // 일시 장애 유예: 연속 실패 이 횟수까지 매매 유지(60초 간격, 상한 30)
```

### 실패 종류 분리

현재 `BPCheckLicense`의 168행은 `http != 200`과 `body == "[]"`를 같은 분기에 넣어 서버 장애를 "미등록 계좌 (HTTP=500)"로 오표기한다. 유예 판정이 불가능하므로 분리한다.

| 응답 | 판정 | `g_licenseDenied` |
|---|---|---|
| `http < 0`, err 4060 | WebRequest URL 미등록(설정 오류) | false → 유예 |
| `http < 0`, 기타 err | 네트워크 장애 | false → 유예 |
| `http != 200` (4xx/5xx) | 서버 장애 | false → 유예 |
| `http == 200`, `expires_at` 없음 | 미등록/비활성/EA 미할당 — 확정 거부 | **true** |
| `http == 200`, `expires_at` 과거 | 만료 — 확정 거부 | **true** |
| `http == 200`, `expires_at` 미래 | 정상 | — |

`BPCheckLicense`의 자체 1시간 캐시(136행)는 제거한다. 주기 판정은 `MaintainLicense`가 전담한다.

### `expires_at` null 파싱 버그 동반 수정

현재 175행은 `StringFind(body, "\"expires_at\":\"") + 14`를 검사 없이 사용한다. `expires_at`이 `null`이면 `StringFind`가 `-1`을 반환해 `s = 13`이 되고, 엉뚱하게 잘린 문자열이 날짜 비교를 우연히 통과해 **만료 검사 없이 라이선스가 승인된다.** `StringFind` 결과가 `< 0`인지 먼저 확인하고, 그 경우 확정 거부로 처리한다.

`customers` 뷰의 `expires_at`은 `cb.expires_at`로 `customers_base`에서 직접 오며(LEFT JOIN 산출물이 아님), 관리자 페이지는 고객 등록 시 항상 값을 설정한다(`axion-admin.html:1323`). 따라서 null은 "무제한"이 아니라 데이터 이상이며 fail-closed가 맞다.

**주의**: 이 수정은 동작 변경이다. 현재는 null이 우연히 통과하므로, 운영 DB에 `expires_at`이 null이면서 `is_active=true`인 고객이 실재한다면 그 계좌는 이 수정 이후 확정 거부로 바뀌어 보유 포지션이 청산된다.

2026-07-15 운영 DB에서 `SELECT account_no FROM customers WHERE expires_at IS NULL AND is_active = true` 실행 결과 **행이 없음을 확인했다.** 해당 레코드가 없으므로 이 수정은 기존 고객에게 영향이 없다.

### 재검증 주기와 유예 판정

```mql4
void MaintainLicense()
{
   // 정상 확인된 상태에서만 1시간 간격. 실패가 시작되면(유예 중 포함) 60초 간격으로
   // 재시도해야 LicenseGraceTries가 의도한 유예 시간(횟수 x 60초)이 된다.
   int intervalSec = (g_licenseOK && g_licenseFailStreak == 0) ? 3600 : 60;
   if(g_lastLicCheck != 0 && TimeLocal() - g_lastLicCheck < intervalSec) return;
   g_lastLicCheck = TimeLocal();

   if(BPCheckLicense())
   {
      g_licenseOK         = true;
      g_licenseFailStreak = 0;
      g_licenseChecked    = true;
      if(g_riskAccepted) GlobalVariableSet(RiskConsentKey(), 1);   // 4주 TTL 갱신
      return;
   }

   g_licenseFailStreak++;

   if(!g_licenseChecked) return;   // 최초 인증 전 — 청산할 포지션이 없다

   if(!g_licenseOK)   // 이미 실효 — 직전 청산이 부분 실패했을 수 있으므로 잔여분 재청산
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

확정 거부(`g_licenseDenied=true`)는 유예 없이 즉시 실효 처리한다.

### 실효 청산의 잔고가 적재되지 않는 문제

`BPSendBalance`는 현재 `if(!SendBalance || !g_licenseOK) return;`으로 시작한다(195행). `MaintainLicense`가 `g_licenseOK = false`를 먼저 대입한 뒤 `CloseSide`를 부르므로, `CloseSide` 말미의 `BPSendBalance(true)`(553행)가 이 가드에 걸려 **실효 청산으로 확정된 잔고가 서버에 적재되지 않는다.** 관리자 페이지에는 청산 전 잔고가 마지막 값으로 남는다.

가드를 `g_licenseChecked` 기준으로 바꾼다. 한 번도 인증된 적 없는 계좌는 여전히 전송하지 않으면서, 실효 직후의 청산 잔고는 적재된다.

```mql4
if(!SendBalance) return;
if(!g_licenseChecked) return;   // g_licenseOK가 아니라 g_licenseChecked로 판정
```

## 3. 위험 고지 팝업 최초 1회

### 영속 동의 기록

`g_riskShown`은 프로그램 전역변수라 리컴파일·심볼/주기 변경·파라미터 변경·계좌 재접속·템플릿 적용마다 리셋되어 팝업이 재발한다. 터미널 GlobalVariable로 계좌별 동의를 영구 기록한다.

```mql4
string RiskConsentKey() { return "BOLINGER_PAST_RISK_OK_" + IntegerToString((int)AccountNumber()); }
```

GlobalVariable은 디스크에 저장되어 터미널 재시작·PC 재부팅을 넘어 유지되며, 마지막 접근 후 4주가 지나면 자동 삭제된다. `MaintainLicense`가 확인 성공 시마다 `GlobalVariableSet`으로 접근 시각을 갱신해, 4주 넘게 무중단 가동해도 동의가 사라지지 않게 한다.

계좌 단위로 범위를 잡는다(심볼·매직 미포함). 요구사항이 "EA 최초 시작 시 한 번"이므로, 같은 계좌의 여러 차트에 붙여도 한 번만 물어야 한다.

### 보유 포지션 중 팝업 보류

`MessageBox`는 모달이라 사용자가 클릭할 때까지 EA의 단일 스레드를 붙잡는다. 그동안 `OnTick`이 실행되지 않아 `CheckSideBasket`이 멈춘다 — 1번에서 고치려는 바로 그 문제다. 따라서 **보유 포지션이 있으면 모달을 띄우지 않고 플랫이 될 때까지 미룬다.** 신규 진입은 `g_riskAccepted=false`이므로 `TradingAllowed()`가 계속 차단하고, 청산 관리는 그대로 돈다. 사용자에게는 `Alert`(비모달)로 안내한다.

```mql4
bool PromptRiskDisclosure()
{
   if(g_riskAccepted) return true;
   if(!ShowKoreanRiskPopup) { g_riskAccepted = true; return true; }

   string key = RiskConsentKey();
   if(GlobalVariableCheck(key))
   {
      GlobalVariableSet(key, 1);   // 4주 미사용 삭제 방지 — 접근 시각 갱신
      g_riskAccepted = true;
      g_riskDeferred = false;
      return true;
   }

   if(g_riskPrompted) return false;   // 이미 물었고 거부당함

   // 모달이 스레드를 잡으면 CheckSideBasket이 멈춰 그리드가 방치된다.
   if(CountSide(OP_BUY) + CountSide(OP_SELL) > 0)
   {
      if(!g_riskDeferred)
      {
         g_riskDeferred = true;
         Print("Bolinger_past: 보유 포지션이 있어 위험고지 팝업을 보류합니다 — 청산 관리는 계속됩니다");
         Alert("Bolinger_past: 위험고지 동의 필요 — 보유 포지션 청산 후 팝업이 표시됩니다");
      }
      return false;
   }

   g_riskPrompted = true;
   g_riskDeferred = false;
   if(BPShowRiskPopup())
   {
      g_riskAccepted = true;
      GlobalVariableSet(key, 1);
      return true;
   }
   return false;
}
```

`OnTimer`에서 `g_licenseOK && !g_riskAccepted`일 때 매 초 호출한다. 포지션 보유로 보류 중이면 플랫이 되는 즉시 팝업이 뜬다.

백테스트 가드(`IsTesting()`)는 두지 않는다. MT4 전략 테스터는 Timer 이벤트를 처리하지 않으므로 `OnTimer`에서 호출되는 이 함수는 테스터에서 실행되지 않고, 따라서 백테스트가 동의 플래그를 기록해 실계좌 고지를 누락시킬 경로가 없다.

## 4. 잔고 $50 이하 청산 후 종료

### 입력

```mql4
input string SETTING__________13 = "============ MIN EQUITY STOP ============";
input double MinEquityStop = 50.0;   // 이하시 전체 청산 후 EA 종료 (0=비활성)
```

기존 6개 EA(`JARVIS_ULTRA`, `RUBBER_BAND_0624`, `RACEHORSE_0624`, `HYPER_BARCODE_SYSTEM_0624`, `GOLD_PRIVATE`, `GOLDRUN_EA`)는 `CheckBalanceStop()`을 `50.0` 하드코딩으로 갖고 있으나, kjg3는 모든 임계값을 input으로 빼는 스타일이므로 input화한다. 기본값 50.0은 기존 동작과 동일하다.

### Equity·Balance 병행 판정

```mql4
if(AccountEquity() <= MinEquityStop || AccountBalance() <= MinEquityStop)
```

`AccountBalance()`는 실현 결과만 반영하고 미결제 포지션의 평가손익을 포함하지 않는다. 이 EA는 손실 중인 방향에 계속 물타기하는 구조라, 잔고 $200에 10차수가 -$160 물린 상황에서 Balance는 여전히 $200이고 Equity가 $40이다. Balance 기준만으로는 계좌가 녹는 동안 발동하지 않고 손실이 실현된 뒤에야 도는 사후 로직이 된다. 마틴게일에서 위험을 잡을 수 있는 값은 Equity뿐이므로 Equity를 주 기준으로 하고, Balance는 무포지션 상태의 소진 계좌를 잡기 위해 병행한다.

기존 6개 파일과 동작이 달라지는 의도된 차이다.

### 기존 구현을 복사하지 않는 이유

기존 `CheckBalanceStop()`의 청산 루프는 `OrderSelect` 후 `OrderSymbol()`/`OrderMagicNumber()`를 확인하지 않아 **같은 계좌에서 도는 다른 EA와 다른 심볼의 포지션까지 전부 청산한다.** 게다가 청산가로 현재 차트의 `Bid`/`Ask`를 쓰므로 다른 심볼 주문에는 잘못된 가격이 들어가 error 129로 실패한다. kjg3에는 `IsTargetOrder()`(Symbol + MagicNumber 필터)와 `CloseSide()`가 이미 있으므로 그것을 쓴다.

또 기존 구현은 `OrderClose` 성공 여부를 확인하지 않고 곧바로 `ExpertRemove()`를 부른다. 리쿼트·시장 마감·슬리피지로 청산이 실패해도 EA가 사라져 남은 포지션이 브로커측 TP/SL 없이 방치된다 — 1번과 같은 성격의 위험이다.

### 설계

```mql4
void CheckBalanceStop()
{
   if(!g_balanceHalt)
   {
      if(MinEquityStop <= 0) return;
      if(AccountEquity() > MinEquityStop && AccountBalance() > MinEquityStop) return;
      g_balanceHalt = true;
      g_running     = false;
      Print(">>> Bolinger_past: 잔고/순자산 ", DoubleToString(MinEquityStop, 2),
            " 이하 도달 — 전체 청산 후 EA 종료 / Equity=", DoubleToString(AccountEquity(), 2),
            " / Balance=", DoubleToString(AccountBalance(), 2));
   }

   // halt 상태에서는 잔여 포지션이 없어질 때까지 매 틱 재시도한다.
   if(CountSide(OP_BUY)  > 0) CloseSide(OP_BUY,  "MIN_EQUITY_STOP");
   if(CountSide(OP_SELL) > 0) CloseSide(OP_SELL, "MIN_EQUITY_STOP");

   // 청산이 끝나기 전에 EA를 제거하면 남은 포지션이 브로커측 TP/SL 없이 방치된다.
   if(CountSide(OP_BUY) > 0 || CountSide(OP_SELL) > 0)
   {
      Comment("Bolinger_past: 잔고 ", DoubleToString(MinEquityStop, 2), " 이하 — 청산 재시도 중");
      return;
   }

   Comment("Bolinger_past: 잔고 ", DoubleToString(MinEquityStop, 2), " 이하 — EA 종료됨");
   ExpertRemove();
}
```

`ExpertRemove()`는 즉시 중단하지 않는다 — 중단 플래그만 세우고 현재 핸들러는 끝까지 실행된다. 따라서 호출부(`OnTick` 최상단)에서 `if(g_balanceHalt) return;`으로 아래 진입 로직이 한 번 더 도는 것을 막는다. 실제 재진입을 막는 것은 `ExpertRemove`가 아니라 `g_balanceHalt` 플래그다.

`ExpertRemove()`는 `OnDeinit`을 호출하므로 현재 `OnDeinit`이 종료 사유 `Comment`를 지운다. 사용자에게 EA가 이유 없이 사라진 것처럼 보이지 않도록 다음과 같이 바꾼다.

```mql4
Comment(g_balanceHalt ? "Bolinger_past: 잔고 " + DoubleToString(MinEquityStop, 2) + " 이하 — EA 종료됨" : "");
```

패널에는 `HALTED (MIN EQUITY)` 상태를 표시한다.

## 5. WebRequest 타임아웃 3초

라이선스 조회 10000ms → 3000ms(153행), 잔고 전송 5000ms → 3000ms(222행).

`OnTimer`는 `OnTick`과 같은 스레드에서 디스패치되므로, WebRequest가 대기하는 동안 유일한 청산 장치인 `CheckSideBasket`이 멈춘다. 현재 `OnTimer` 1회는 최악 15초(라이선스 10s + 잔고 5s) EA 스레드를 정지시킨다.

여기에 실제 병리가 있다. 136행의 조기 반환은 `g_licenseOK`가 true일 때만 1시간 스로틀로 동작한다. 서버가 느리거나 불통이면 `g_licenseOK`가 false로 남아 스로틀이 무력화되고, **매 1초 타이머마다 10초 타임아웃 WebRequest가 재발행되어 EA가 사실상 상시 블로킹된다.** 2번의 `MaintainLicense` 간격 게이트(실패 시 60초)가 이 문제를 함께 해소한다 — 스로틀이 `g_licenseOK`와 무관하게 `g_lastLicCheck`만으로 동작하기 때문이다.

## 오류 처리 요약

| 상황 | 청산 | 신규 진입 | EA 생존 |
|---|---|---|---|
| 정상 | 정상 | 허용 | 유지 |
| 네트워크·서버 장애 (유예 내) | 정상 | 허용 | 유지 |
| 네트워크·서버 장애 (유예 초과) | 전량 청산 | 차단 | 유지(복구 시 재개) |
| 확정 거부(미등록·만료) | 전량 청산 | 차단 | 유지(복구 시 재개) |
| 위험고지 미동의 | 정상 | 차단 | 유지 |
| 위험고지 보류(포지션 보유) | 정상 | 차단 | 유지 |
| `MinEquityStop` 도달 | 전량 청산(성공까지 재시도) | 차단 | 청산 확정 후 제거 |

모든 행에서 청산이 죽지 않는 것이 이 설계의 핵심이다.

## 검증

MQL4는 자동화 테스트 수단이 없고 백테스트도 범위 밖이므로, MetaEditor 컴파일과 수동 검증으로 확인한다.

1. **컴파일**: MetaEditor에서 경고 0건으로 컴파일되는지.
2. **청산 게이트 분리**(1번): `서버주소`를 잘못된 값으로 바꿔 라이선스를 실패시킨 뒤, 수동으로 포지션을 열고 TP 금액을 넘겨 `CheckSideBasket`이 청산하는지 확인. 수정 전에는 청산되지 않아야 한다(회귀 대조군).
3. **유예**(2번): 네트워크를 끊고 `LicenseGraceTries`(기본 5) × 60초 동안 매매가 유지되다가 이후 `LICENSE_REVOKED`로 청산되는지. Experts 로그에 `일시 실패 (n/5)`가 60초 간격으로 찍히는지.
4. **팝업 1회**(3번): 동의 후 차트 주기를 바꿔 재초기화해도 팝업이 뜨지 않는지. 터미널을 재시작해도 뜨지 않는지. `GlobalVariableDel`로 키를 지우면 다시 뜨는지. 포지션 보유 중 EA를 재부착하면 팝업 대신 `Alert`가 뜨고 청산이 계속 도는지.
5. **MinEquityStop**(4번): `MinEquityStop`을 현재 Equity 바로 아래 값으로 설정해 발동시키고, 다른 매직넘버 포지션은 건드리지 않는지, 청산 후에만 EA가 제거되는지, `Comment`가 남는지 확인.
6. **타임아웃**(5번): 서버 불통 상태에서 Experts 로그의 라이선스 오류가 60초 간격으로만 찍히는지(수정 전에는 1초 간격).

## 배포 전 확인

- ~~운영 DB에 `expires_at IS NULL AND is_active = true`인 고객이 없을 것(2번 참조).~~ 2026-07-15 확인 완료 — 해당 행 없음.
- 파일 인코딩: kjg3는 영문 식별자만 쓰므로 BOM 요구는 없으나, 기존 인코딩을 바꾸지 말 것.

## 미해결 사안 (범위 밖, 별도 처리 필요)

- `check-license` Edge Function의 DB 오류 → `authorized:false` 계약 결함. Gen 2로 이전하려면 선행 수정 필요.
- `check-license`의 `maybeSingle()` 복수 EA 고객 인증 실패.
- kjg3의 하드코딩 anon 키가 `customers` 뷰를 통해 전 고객 정보 열람을 허용하는 문제.
- kjg3는 백테스트가 불가능하다(전략 테스터가 Timer 이벤트를 처리하지 않아 `g_licenseOK`가 영원히 false). 사용자 결정으로 이번 범위에서 제외.
