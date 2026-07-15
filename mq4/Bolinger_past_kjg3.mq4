//+------------------------------------------------------------------+
//|                                          Bolinger_past.mq4      |
//|        Bollinger close breakout/re-entry + direct grid Martin     |
//+------------------------------------------------------------------+
//|                                                                  |
//|  Bolinger_past - GRID LOGIC                                      |
//|  - Initial entry: Bollinger close breakout -> close re-entry.     |
//|  - Averaging: when Distance_Point is reached, next order opens.   |
//|  - No second Bollinger re-entry confirmation for averaging.       |
//|  - This is a direct-distance grid martingale structure.     |
//|                                                                  |
#property strict
#property version   "1.30"
#property description "Bolinger_past - direct LOT1~LOT10 order size settings"
#property description "Distance reached -> immediate next grid entry"

input string SETTING__________1 = "============ ORDER SETTING ============";
input int    MagicNumber = 1;

input string SETTING__________3 = "============ BBands Setting ============";
input int    BBperiod = 20;
input double BBdeviation = 2.0;
input bool   ShowAutoBollingerBands = true; // EA가 볼린저밴드 라인을 자동 표시
input int    BandDrawBars = 180;            // 차트에 그릴 볼밴 길이

input string SETTING__________5 = "============ TPamount Setting ============";
input double TPamount_1 = 1.0;
input double TPamount_2 = 2.0;
input double TPamount_3 = 3.0;
input double TPamount_4 = 4.0;
input double TPamount_5 = 5.0;
input double TPamount_6 = 6.0;
input double TPamount_7 = 7.0;
input double TPamount_8 = 8.0;
input double TPamount_9 = 9.0;
input double TPamount_10 = 10.0;

input string SETTING__________6 = "============ SpreadLimit Setting ============";
input int    SpreadLimit = 30;

input string SETTING__________7 = "============ STEP LOT SETTING ============";
input double LOT1 = 0.01;  // 1단계 실제 진입 랏
input double LOT2 = 0.02;  // 2단계 실제 진입 랏
input double LOT3 = 0.03;
input double LOT4 = 0.04;
input double LOT5 = 0.05;
input double LOT6 = 0.06;
input double LOT7 = 0.07;
input double LOT8 = 0.08;
input double LOT9 = 0.09;
input double LOT10 = 0.10;

input string SETTING__________8 = "============ SIDE STOP LOSS SETTING ============";
input double SLamount = 10000000;

input string SETTING__________9 = "============ DISTANCE POINT SETTING ============";
input int    Distance_Point_1 = 500;  // 1차 추가진입 간격
input int    Distance_Point_2 = 500;  // 2차 추가진입 간격
input int    Distance_Point_3 = 500;
input int    Distance_Point_4 = 500;
input int    Distance_Point_5 = 500;
input int    Distance_Point_6 = 500;
input int    Distance_Point_7 = 500;
input int    Distance_Point_8 = 500;
input int    Distance_Point_9 = 500;
input int    Distance_Point_10 = 500; // 10차 설정 / 최종 fallback

input string SETTING__________10 = "============ TRADING TIME SETTING ============";
input int    StartTime = 0;
input int    CloseTime = 23;

input string SETTING__________11 = "============ Extra Safety / Visual ============";
input bool   AutoStart = true;
input bool   AllowBuy = true;
input bool   AllowSell = true;
input int    MaxSteps = 10;
input int    Slippage = 10;
input bool   CloseSignalStateAfterEntry = true;
input bool   SetChartStyle = true;
input bool   ShowPanel = true;
input bool   ShowKoreanRiskPopup = true;  // EA 시작 시 한국어 투자위험 고지
input bool   DrawBandTouchMarks = true;

input string SETTING__________12 = "============ LICENSE / SERVER ============";
input bool   SendBalance = true;          // 잔고 서버 전송
input int    SendBalanceMinutes = 5;      // 잔고 전송 주기(분)
input int    LicenseGraceTries = 5;       // 일시 장애 유예: 연속 실패 이 횟수까지 매매 유지(60초 간격, 상한 30)

input string SETTING__________13 = "============ MIN EQUITY STOP ============";
input double MinEquityStop = 50.0;        // 순자산/잔고가 이 값 이하면 전체 청산 후 EA 종료 (0=비활성)

bool     g_running = false;
datetime g_lastBarTime = 0;
bool     g_upperBreakoutArmed = false;
bool     g_lowerBreakoutArmed = false;
datetime g_upperBreakoutTime = 0;
datetime g_lowerBreakoutTime = 0;

string PANEL_BG  = "BOLINGER_PAST_PANEL_BG";
string PANEL_TOP = "BOLINGER_PAST_PANEL_TOP";
string PANEL_TX  = "BOLINGER_PAST_PANEL_TX_";
string MARK_PREFIX = "BOLINGER_PAST_MARK_";
string BAND_PREFIX = "BOLINGER_PAST_BAND_";

// =====================================================
// License System
// =====================================================
string   g_ProgramName  = "Bolinger_past";
string   g_ServerUrl    = "https://wmvnearoursbmwjqwzww.supabase.co";
string   g_ApiKey       = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indtdm5lYXJvdXJzYm13anF3end3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgxNzQ5MjEsImV4cCI6MjA5Mzc1MDkyMX0.MS4iSGIvW4dBi3sd8J3baHLT4TlgUJS5lXwlhJdWYEY";
bool     g_licenseOK    = false;
datetime g_lastLicCheck = 0;   // TimeLocal 기준 — 틱 없는 주말에도 주기가 흘러야 한다
datetime g_lastBalSend  = 0;
string   g_licStatusTxt = "확인 중...";
bool     g_riskAccepted = false;
bool     g_riskPrompted = false;  // 위험고지 모달을 이미 띄웠는지(세션 내 재표시 방지)
bool     g_riskDeferred = false;  // 보유 포지션으로 모달을 보류한 상태

// 라이선스 유예 상태
bool     g_licenseChecked    = false;  // 최초 라이선스 확인 성공 여부
bool     g_licenseDenied     = false;  // 서버가 명시적으로 거부(일시 장애와 구분)
int      g_licenseFailStreak = 0;      // 연속 확인 실패 횟수
bool     g_balanceHalt       = false;  // MinEquityStop 도달로 정지한 상태

bool BPShowRiskPopup()
{
   if(!ShowKoreanRiskPopup) return(true);

   string msg = "";
   msg += "EA 시작 전 필수 투자위험 및 책임 고지\n\n";
   msg += "본 EA(Bolinger_past)는 볼린저밴드 돌파 신호로 진입한 뒤, 설정 간격에 도달할 때마다 분할 주문을 적층하는 그리드 방식의 자동매매 보조 소프트웨어이며, 수익을 보장하지 않습니다.\n\n";
   msg += "본 시스템은 손실 중인 방향에 주문을 계속 추가하는 구조이므로, 한 방향 추세가 길게 이어질 경우 보유 수량과 평가손실이 빠르게 확대될 수 있습니다.\n\n";
   msg += "레버리지 상품은 시장 변동성, 스프레드 확대, 슬리피지, 체결 지연, 서버 장애, 증거금 부족, 마진콜, 강제청산 등으로 인해 원금을 초과하는 손실이 발생할 수 있습니다.\n\n";
   msg += "동시 보유 주문이 많아 증거금 소진 위험이 있으므로, 충분한 자본의 계좌에서 차수(MaxSteps)와 주문 수량을 자금 규모에 맞게 설정해 운용해야 합니다.\n\n";
   msg += "기본 설정값, 백테스트, 과거 운용 결과, 예시 수익률은 참고용 정보이며 미래 수익이나 손실 제한을 보장하지 않습니다.\n\n";
   msg += "본 시스템은 투자자문, 투자일임, 매수/매도 추천을 목적으로 하지 않으며, 설치, 설정, 실행, 중지, 청산의 최종 판단과 책임은 전적으로 이용자 본인에게 있습니다.\n\n";
   msg += "위 내용을 이해했으며 본인 판단과 책임으로 EA를 실행합니다.\n\n";
   msg += "동의하시면 예 버튼을 눌러 시작하세요.";

   int answer = MessageBox(msg, "Bolinger_past 투자위험 고지", MB_YESNO | MB_ICONWARNING);
   return(answer == IDYES);
}

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

      // 동의 기록의 접근 시각을 주기적으로 갱신한다. 갱신이 부착 시점에만 일어나면
      // 4주 넘게 무중단 가동할 때 MT4가 변수를 삭제해, 다음 재부착에서 모달이 뜬다.
      // 이미 존재하는 동의 기록의 접근 시각만 갱신한다. GlobalVariableCheck 없이
      // 쓰면 ShowKoreanRiskPopup=false로 돌린 계좌(동의 절차를 거치지 않아
      // g_riskAccepted만 true인 상태)에 동의 기록이 새로 생겨, 나중에 팝업을
      // 다시 켜도 고지가 표시되지 않는다.
      if(g_riskAccepted && GlobalVariableCheck(RiskConsentKey()))
         GlobalVariableSet(RiskConsentKey(), 1);
      return;
   }

   g_licenseFailStreak++;

   // 최초 인증 전에는 확정 거부와 기동 시 네트워크 장애를 구분할 수 없다.
   // 여기서 청산하면 부팅 중 통신 장애만으로 정상 고객 포지션이 청산되므로,
   // 신규 진입만 차단(TradingAllowed)하고 기존 포지션은 CheckSideBasket에 맡긴다.
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
   if(CountSide(OP_BUY)  > 0) CloseSide(OP_BUY,  "LICENSE_REVOKED");
   if(CountSide(OP_SELL) > 0) CloseSide(OP_SELL, "LICENSE_REVOKED");
}

// force=true 이면 주기와 무관하게 즉시 전송 (청산 직후 등)
void BPSendBalance(bool force = false)
{
   if(!SendBalance) return;
   // g_licenseOK가 아니라 g_licenseChecked로 판정한다. MaintainLicense가 실효
   // 처리 시 g_licenseOK=false를 먼저 대입한 뒤 CloseSide를 부르므로, CloseSide
   // 말미의 BPSendBalance(true)가 g_licenseOK 가드에 걸리면 실효 청산으로 확정된
   // 잔고가 적재되지 않는다. 한 번도 인증된 적 없는 계좌는 여전히 전송하지 않는다.
   if(!g_licenseChecked) return;

   int interval = SendBalanceMinutes * 60;
   if(interval < 60) interval = 60;

   // 틱이 없어도 주기가 흐르도록 TimeCurrent 대신 TimeLocal 사용
   if(!force && g_lastBalSend > 0 && (TimeLocal() - g_lastBalSend) < interval)
      return;

   string acct = IntegerToString(AccountNumber());
   string body = "{\"account_no\":\"" + acct + "\""
               + ",\"balance\":" + DoubleToString(AccountBalance(), 2)
               + ",\"equity\":"  + DoubleToString(AccountEquity(), 2)
               + ",\"profit\":"  + DoubleToString(AccountEquity() - AccountBalance(), 2)
               + "}";

   string headers = "Content-Type: application/json\r\n"
                  + "apikey: " + g_ApiKey + "\r\n"
                  + "Authorization: Bearer " + g_ApiKey + "\r\n"
                  + "Prefer: return=minimal\r\n";

   char post[]; char result[]; string rh;
   StringToCharArray(body, post, 0, StringLen(body));
   ArrayResize(post, StringLen(body));

   ResetLastError();
   // 스레드 블로킹 최소화 (CheckSideBasket 정지 방지)
   int http = WebRequest("POST", g_ServerUrl + "/rest/v1/balance_logs", headers, 3000, post, result, rh);

   // 실패해도 갱신 — 오류 시 매 초 재시도하는 것을 막는다
   g_lastBalSend = TimeLocal();

   if(http < 0)
      Print("[Balance] Account: ", acct, " | ERROR err=", IntegerToString(GetLastError()));
   else if(http != 200 && http != 201 && http != 204)
      Print("[Balance] Account: ", acct, " | HTTP: ", IntegerToString(http),
            " | Body: ", CharArrayToString(result));
}
// =====================================================

int OnInit()
{
   g_running = AutoStart;

   if(SetChartStyle)
      SetupChart();

   if(ShowAutoBollingerBands)
      DrawAutoBollingerBands();

   Print("Bolinger_past initialized / Symbol=", Symbol(),
         " / Magic=", MagicNumber,
         " / LOT1=", DoubleToString(LOT1, 2),
         " / BB=", BBperiod, ", ", DoubleToString(BBdeviation, 2));

   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}

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

void OnTimer()
{
   if(g_balanceHalt) return;   // 청산·종료는 OnTick의 CheckBalanceStop이 전담한다

   // 틱이 유실되거나 OnTick이 굶는 구간에서도 최소 1초 해상도로 바스켓을 관리한다.
   // MT4는 처리 중 도착한 틱을 큐잉하지 않고 버리므로, CheckSideBasket이 유일한
   // 청산 장치인 이상 이중화가 필요하다.
   CheckSideBasket(OP_BUY);
   CheckSideBasket(OP_SELL);

   MaintainLicense();

   // 라이선스 확인 후에도 미동의 상태면 계속 시도한다. 포지션 보유 중에는 팝업이
   // 보류되므로, 플랫이 되는 즉시 팝업이 뜨도록 매 초 확인한다.
   if(g_licenseOK && !g_riskAccepted)
      PromptRiskDisclosure();

   BPSendBalance();
}

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

//+------------------------------------------------------------------+
//| 매매 허용 조건. 청산은 이 게이트와 무관하게 항상 실행된다.        |
//+------------------------------------------------------------------+
bool TradingAllowed()
{
   if(!g_running)      return false;
   if(g_balanceHalt)   return false;
   if(!g_licenseOK)    return false;
   if(!g_riskAccepted) return false;
   return true;
}

void OnTick()
{
   CheckBalanceStop();
   if(g_balanceHalt)
   {
      if(ShowPanel) DrawPanel();
      return;
   }

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

void ProcessClosedCandleSignal()
{
   if(Bars < BBperiod + 5) return;

   int shift = 1;
   double upper = iBands(Symbol(), Period(), BBperiod, BBdeviation, 0, PRICE_CLOSE, MODE_UPPER, shift);
   double lower = iBands(Symbol(), Period(), BBperiod, BBdeviation, 0, PRICE_CLOSE, MODE_LOWER, shift);
   double close1 = iClose(Symbol(), Period(), shift);

   if(upper <= 0 || lower <= 0 || close1 <= 0) return;

   // Clean chart: only actual entry/close events are printed.
   // Break-out detection still happens internally, but no BREAK text is drawn.
   if(close1 > upper)
   {
      g_upperBreakoutArmed = true;
      g_upperBreakoutTime = iTime(Symbol(), Period(), shift);
   }

   if(close1 < lower)
   {
      g_lowerBreakoutArmed = true;
      g_lowerBreakoutTime = iTime(Symbol(), Period(), shift);
   }

   if(!IsSpreadOK()) return;

   if(g_upperBreakoutArmed && close1 <= upper && AllowSell && NewFirstEntryAllowed(OP_SELL))
   {
      if(OpenOrder(OP_SELL, StepLot(1), "BB_UPPER_REENTRY_SELL"))
      {
         if(DrawBandTouchMarks) DrawSignalMark("SELL_OPEN", iTime(Symbol(), Period(), shift), close1, clrGold, "SELL OPEN");
         if(CloseSignalStateAfterEntry) g_upperBreakoutArmed = false;
      }
   }

   if(g_lowerBreakoutArmed && close1 >= lower && AllowBuy && NewFirstEntryAllowed(OP_BUY))
   {
      if(OpenOrder(OP_BUY, StepLot(1), "BB_LOWER_REENTRY_BUY"))
      {
         if(DrawBandTouchMarks) DrawSignalMark("BUY_OPEN", iTime(Symbol(), Period(), shift), close1, clrAqua, "BUY OPEN");
         if(CloseSignalStateAfterEntry) g_lowerBreakoutArmed = false;
      }
   }
}

bool NewFirstEntryAllowed(int orderType)
{
   if(!IsTradeTime()) return false;
   if(orderType == OP_BUY && CountSide(OP_BUY) > 0) return false;
   if(orderType == OP_SELL && CountSide(OP_SELL) > 0) return false;
   return true;
}

void ManageAveraging(int orderType)
{
   int count = CountSide(orderType);
   if(count <= 0 || count >= EffectiveMaxSteps()) return;
   if(!IsSpreadOK()) return;

   double lastPrice = LastEntryPrice(orderType);
   if(lastPrice <= 0) return;

   int nextStep = count + 1;
   int gapPoints = DistanceForStep(nextStep);

   RefreshRates();

   double distancePoints = 0;
   if(orderType == OP_BUY)
      distancePoints = (lastPrice - Bid) / PointValue();
   else
      distancePoints = (Ask - lastPrice) / PointValue();

   if(distancePoints < gapPoints) return;

   string reason = orderType == OP_BUY ? "BUY_AVERAGING_STEP_" : "SELL_AVERAGING_STEP_";
   OpenOrder(orderType, StepLot(nextStep), reason + IntegerToString(nextStep));
}

int DistanceForStep(int step)
{
   // step is the next total position step.
   // Step 2 uses Distance_Point_1, Step 3 uses Distance_Point_2, etc.
   if(step <= 2) return Distance_Point_1;
   if(step == 3) return Distance_Point_2;
   if(step == 4) return Distance_Point_3;
   if(step == 5) return Distance_Point_4;
   if(step == 6) return Distance_Point_5;
   if(step == 7) return Distance_Point_6;
   if(step == 8) return Distance_Point_7;
   if(step == 9) return Distance_Point_8;
   if(step == 10) return Distance_Point_9;
   return Distance_Point_10;
}

int EffectiveMaxSteps()
{
   int maxSteps = MaxSteps;
   if(maxSteps < 1) maxSteps = 1;
   if(maxSteps > 10) maxSteps = 10;
   return maxSteps;
}

void CheckSideBasket(int orderType)
{
   int count = CountSide(orderType);
   if(count <= 0) return;

   double profit = ProfitBySide(orderType);
   double target = TargetForStep(count);

   if(target > 0 && profit >= target)
   {
      Print("Side basket TP reached / Side=", OrderTypeName(orderType),
            " / Count=", count, " / Profit=", DoubleToString(profit, 2),
            " / Target=", DoubleToString(target, 2));
      CloseSide(orderType, "SIDE_TP_STEP_" + IntegerToString(count));
      return;
   }

   if(SLamount > 0 && profit <= -SLamount)
   {
      Print("Side basket SL reached / Side=", OrderTypeName(orderType),
            " / Profit=", DoubleToString(profit, 2), " / SL=", DoubleToString(SLamount, 2));
      CloseSide(orderType, "SIDE_SL");
   }
}

double TargetForStep(int count)
{
   if(count <= 1) return TPamount_1;
   if(count == 2) return TPamount_2;
   if(count == 3) return TPamount_3;
   if(count == 4) return TPamount_4;
   if(count == 5) return TPamount_5;
   if(count == 6) return TPamount_6;
   if(count == 7) return TPamount_7;
   if(count == 8) return TPamount_8;
   if(count == 9) return TPamount_9;
   return TPamount_10;
}

double StepLot(int step)
{
   double rawLot = LOT1;

   if(step <= 1) rawLot = LOT1;
   else if(step == 2) rawLot = LOT2;
   else if(step == 3) rawLot = LOT3;
   else if(step == 4) rawLot = LOT4;
   else if(step == 5) rawLot = LOT5;
   else if(step == 6) rawLot = LOT6;
   else if(step == 7) rawLot = LOT7;
   else if(step == 8) rawLot = LOT8;
   else if(step == 9) rawLot = LOT9;
   else rawLot = LOT10;

   if(rawLot <= 0)
      rawLot = LOT1;

   return NormalizeLots(rawLot);
}

bool OpenOrder(int orderType, double lots, string reason)
{
   RefreshRates();
   double normalizedLots = NormalizeLots(lots);
   if(normalizedLots <= 0) return false;

   double price = orderType == OP_BUY ? Ask : Bid;
   color arrowColor = orderType == OP_BUY ? clrAqua : clrGold;

   ResetLastError();
   int ticket = OrderSend(Symbol(), orderType, normalizedLots, NormalizeDouble(price, Digits),
                          Slippage, 0, 0, reason, MagicNumber, 0, arrowColor);

   if(ticket < 0)
   {
      int err = GetLastError();
      Print("OrderSend failed / type=", OrderTypeName(orderType),
            " / lot=", DoubleToString(normalizedLots, 2),
            " / reason=", reason, " / error=", err);
      return false;
   }

   Print("Open ", OrderTypeName(orderType), " / ticket=", ticket,
         " / lot=", DoubleToString(normalizedLots, 2),
         " / price=", DoubleToString(price, Digits), " / reason=", reason);
   return true;
}

void CloseSide(int orderType, string reason)
{
   bool printedCloseLabel = false;

   for(int pass=0; pass<10; pass++)
   {
      bool found = false;
      RefreshRates();

      for(int i=OrdersTotal()-1; i>=0; i--)
      {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
         if(!IsTargetOrder()) continue;
         if(OrderType() != orderType) continue;

         found = true;
         int ticket = OrderTicket();
         double lots = OrderLots();
         double profit = OrderProfit() + OrderSwap() + OrderCommission();
         double price = orderType == OP_BUY ? Bid : Ask;

         ResetLastError();
         bool ok = OrderClose(ticket, lots, NormalizeDouble(price, Digits), Slippage, clrWhite);

         if(!ok)
         {
            Print("OrderClose failed / ticket=", ticket, " / reason=", reason, " / error=", GetLastError());
         }
         else
         {
            Print("Closed / ticket=", ticket, " / reason=", reason,
                  " / lots=", DoubleToString(lots, 2),
                  " / profit=", DoubleToString(profit, 2));

            if(DrawBandTouchMarks && !printedCloseLabel)
            {
               string closeText = StringFind(reason, "SIDE_TP") >= 0 ? "PROFIT" : "CLOSE";
               DrawSignalMark(OrderTypeName(orderType) + "_CLOSE",
                              TimeCurrent(),
                              price,
                              StringFind(reason, "SIDE_TP") >= 0 ? clrLime : clrOrange,
                              closeText);
               printedCloseLabel = true;
            }
         }
      }

      if(!found) break;
      Sleep(150);
   }

   // 청산으로 잔고가 확정되었으므로 주기와 무관하게 즉시 전송
   BPSendBalance(true);
}

bool IsTargetOrder()
{
   if(OrderSymbol() != Symbol()) return false;
   if(OrderMagicNumber() != MagicNumber) return false;
   int type = OrderType();
   return type == OP_BUY || type == OP_SELL;
}

int CountSide(int orderType)
{
   int count = 0;
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsTargetOrder()) continue;
      if(OrderType() == orderType) count++;
   }
   return count;
}

double ProfitBySide(int orderType)
{
   double profit = 0.0;
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsTargetOrder()) continue;
      if(OrderType() == orderType) profit += OrderProfit() + OrderSwap() + OrderCommission();
   }
   return profit;
}

double LotsBySide(int orderType)
{
   double lots = 0.0;
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsTargetOrder()) continue;
      if(OrderType() == orderType) lots += OrderLots();
   }
   return lots;
}

double LastEntryPrice(int orderType)
{
   datetime latest = 0;
   double price = 0.0;
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsTargetOrder()) continue;
      if(OrderType() != orderType) continue;
      if(OrderOpenTime() >= latest)
      {
         latest = OrderOpenTime();
         price = OrderOpenPrice();
      }
   }
   return price;
}

bool IsSpreadOK()
{
   if(SpreadLimit <= 0) return true;
   double spread = MarketInfo(Symbol(), MODE_SPREAD);
   return spread <= SpreadLimit;
}

bool IsTradeTime()
{
   int h = TimeHour(TimeCurrent());
   if(StartTime == CloseTime) return true;
   if(StartTime < CloseTime) return h >= StartTime && h < CloseTime;
   return h >= StartTime || h < CloseTime;
}

bool IsNewBar()
{
   datetime t = iTime(Symbol(), Period(), 0);
   if(t <= 0) return false;
   if(t != g_lastBarTime)
   {
      g_lastBarTime = t;
      return true;
   }
   return false;
}

double PointValue()
{
   double p = MarketInfo(Symbol(), MODE_POINT);
   if(p <= 0) p = Point;
   return p;
}

double NormalizeLots(double rawLots)
{
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double step = MarketInfo(Symbol(), MODE_LOTSTEP);
   if(step <= 0) step = 0.01;

   double lots = rawLots;
   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;

   lots = MathFloor(lots / step + 0.0000001) * step;
   lots = NormalizeDouble(lots, LotDigits(step));

   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;
   return lots;
}

int LotDigits(double step)
{
   if(step >= 1.0) return 0;
   if(step >= 0.1) return 1;
   if(step >= 0.01) return 2;
   if(step >= 0.001) return 3;
   return 4;
}

string OrderTypeName(int type)
{
   if(type == OP_BUY) return "BUY";
   if(type == OP_SELL) return "SELL";
   return "UNKNOWN";
}

void SetupChart()
{
   ChartSetInteger(0, CHART_MODE, CHART_CANDLES);
   ChartSetInteger(0, CHART_SHOW_GRID, true);
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, clrBlack);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, clrWhite);
   ChartSetInteger(0, CHART_COLOR_GRID, clrDimGray);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrRed);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrDodgerBlue);
   ChartSetInteger(0, CHART_COLOR_CHART_UP, clrRed);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, clrDodgerBlue);
}

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

void DrawPanel()
{
   int panelX = 8, panelY = 24, panelW = 390, panelH = 280, topH = 30;

   if(ObjectFind(0, PANEL_BG) < 0) ObjectCreate(0, PANEL_BG, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_XDISTANCE, panelX);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_YDISTANCE, panelY);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_XSIZE, panelW);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_YSIZE, panelH);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_COLOR, clrSlateGray);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_BACK, false);

   if(ObjectFind(0, PANEL_TOP) < 0) ObjectCreate(0, PANEL_TOP, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_XDISTANCE, panelX);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_YDISTANCE, panelY);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_XSIZE, panelW);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_YSIZE, topH);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_BGCOLOR, clrMidnightBlue);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_COLOR, clrMidnightBlue);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_BACK, false);

   int buyCount = CountSide(OP_BUY);
   int sellCount = CountSide(OP_SELL);
   int line = 0;

   SetPanelLine(line++, "Bolinger_past", clrWhite, 15);
   SetPanelLine(line++, "LICENSE       : " + g_licStatusTxt, g_licenseOK ? clrLime : clrTomato, 9);
   SetPanelLine(line++, "SYMBOL / TF   : " + Symbol() + " / " + IntegerToString(Period()), clrWhite, 9);
   bool statusOK = (g_running && g_licenseOK && g_riskAccepted && !g_balanceHalt);
   SetPanelLine(line++, "STATUS        : " + PanelStatusText(), statusOK ? clrLime : clrTomato, 9);
   SetPanelLine(line++, "BB PERIOD/DEV : " + IntegerToString(BBperiod) + " / " + DoubleToString(BBdeviation, 2), clrGold, 9);
   SetPanelLine(line++, "UPPER ARMED   : " + (g_upperBreakoutArmed ? "READY" : "NO"), g_upperBreakoutArmed ? clrGold : clrSilver, 9);
   SetPanelLine(line++, "LOWER ARMED   : " + (g_lowerBreakoutArmed ? "READY" : "NO"), g_lowerBreakoutArmed ? clrDodgerBlue : clrSilver, 9);
   SetPanelLine(line++, "BUY STEPS     : " + IntegerToString(buyCount) + " / " + IntegerToString(EffectiveMaxSteps()), clrRed, 9);
   SetPanelLine(line++, "SELL STEPS    : " + IntegerToString(sellCount) + " / " + IntegerToString(EffectiveMaxSteps()), clrDodgerBlue, 9);
   SetPanelLine(line++, "BUY LOTS      : " + DoubleToString(LotsBySide(OP_BUY), 2), clrRed, 9);
   SetPanelLine(line++, "SELL LOTS     : " + DoubleToString(LotsBySide(OP_SELL), 2), clrDodgerBlue, 9);
   SetPanelLine(line++, "NEXT BUY LOT  : " + DoubleToString(StepLot(buyCount + 1), 2), clrRed, 9);
   SetPanelLine(line++, "NEXT SELL LOT : " + DoubleToString(StepLot(sellCount + 1), 2), clrDodgerBlue, 9);
   SetPanelLine(line++, "BUY P/L       : $" + DoubleToString(ProfitBySide(OP_BUY), 2) + " / TP $" + DoubleToString(TargetForStep(buyCount), 2), ProfitBySide(OP_BUY) >= 0 ? clrLime : clrTomato, 9);
   SetPanelLine(line++, "SELL P/L      : $" + DoubleToString(ProfitBySide(OP_SELL), 2) + " / TP $" + DoubleToString(TargetForStep(sellCount), 2), ProfitBySide(OP_SELL) >= 0 ? clrLime : clrTomato, 9);
   SetPanelLine(line++, "SPREAD        : " + IntegerToString((int)MarketInfo(Symbol(), MODE_SPREAD)) + " / " + IntegerToString(SpreadLimit), IsSpreadOK() ? clrLime : clrTomato, 9);
   SetPanelLine(line++, "TRADE TIME    : " + (IsTradeTime() ? "OPEN" : "FIRST ENTRY BLOCKED"), IsTradeTime() ? clrLime : clrTomato, 9);
   SetPanelLine(line++, "BB VISUAL     : " + (ShowAutoBollingerBands ? "AUTO DRAW" : "OFF"), ShowAutoBollingerBands ? clrGold : clrSilver, 9);

   for(int i=line; i<24; i++) SetPanelLine(i, "", clrWhite, 9);
}

void SetPanelLine(int idx, string text, color c, int fontSize=10)
{
   string name = PANEL_TX + IntegerToString(idx);
   int panelX = 8, panelY = 24;

   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, panelX + 10);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, panelY + 5 + idx * 15);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, idx == 0 ? "Arial Bold" : "Arial Bold");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void DrawSignalMark(string key, datetime when, double price, color c, string label)
{
   string name = MARK_PREFIX + key + "_" + IntegerToString((int)when);
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_TEXT, 0, when, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetString(0, name, OBJPROP_TEXT, label);
}

void DrawAutoBollingerBands()
{
   int barsToDraw = BandDrawBars;

   if(barsToDraw < 20) barsToDraw = 20;
   if(barsToDraw > 300) barsToDraw = 300;
   if(barsToDraw > Bars - BBperiod - 5) barsToDraw = Bars - BBperiod - 5;
   if(barsToDraw < 5) return;

   for(int i=barsToDraw; i>=1; i--)
   {
      DrawBandSegment("UPPER_", i, MODE_UPPER, clrSeaGreen);
      DrawBandSegment("MID_", i, MODE_MAIN, clrDarkSlateGray);
      DrawBandSegment("LOWER_", i, MODE_LOWER, clrSeaGreen);
   }

   for(int d=barsToDraw+1; d<=320; d++)
   {
      ObjectDelete(0, BAND_PREFIX + "UPPER_" + IntegerToString(d));
      ObjectDelete(0, BAND_PREFIX + "MID_" + IntegerToString(d));
      ObjectDelete(0, BAND_PREFIX + "LOWER_" + IntegerToString(d));
   }
}

void DrawBandSegment(string part, int shift, int mode, color c)
{
   string name = BAND_PREFIX + part + IntegerToString(shift);

   datetime t1 = iTime(Symbol(), Period(), shift);
   datetime t2 = iTime(Symbol(), Period(), shift - 1);

   double p1 = iBands(Symbol(), Period(), BBperiod, BBdeviation, 0, PRICE_CLOSE, mode, shift);
   double p2 = iBands(Symbol(), Period(), BBperiod, BBdeviation, 0, PRICE_CLOSE, mode, shift - 1);

   if(t1 <= 0 || t2 <= 0 || p1 <= 0 || p2 <= 0)
      return;

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);

   ObjectSetInteger(0, name, OBJPROP_TIME1, t1);
   ObjectSetDouble(0, name, OBJPROP_PRICE1, p1);
   ObjectSetInteger(0, name, OBJPROP_TIME2, t2);
   ObjectSetDouble(0, name, OBJPROP_PRICE2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_STYLE, part == "MID_" ? STYLE_DOT : STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
}

void DeleteBandObjects()
{
   for(int i=0; i<=340; i++)
   {
      ObjectDelete(0, BAND_PREFIX + "UPPER_" + IntegerToString(i));
      ObjectDelete(0, BAND_PREFIX + "MID_" + IntegerToString(i));
      ObjectDelete(0, BAND_PREFIX + "LOWER_" + IntegerToString(i));
   }
}

void DeletePanel()
{
   ObjectDelete(0, PANEL_BG);
   ObjectDelete(0, PANEL_TOP);
   for(int i=0; i<50; i++) ObjectDelete(0, PANEL_TX + IntegerToString(i));
}
//+------------------------------------------------------------------+
