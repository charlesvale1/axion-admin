//+------------------------------------------------------------------+
//|                                          BB_grid_v1_1.mq4       |
//|        Bollinger close breakout/re-entry + direct grid Martin     |
//+------------------------------------------------------------------+
//|                                                                  |
//|  HIGH-RISK BB GRID LOGIC                                         |
//|  - Initial entry: Bollinger close breakout -> close re-entry.     |
//|  - Averaging: when Distance_Point is reached, next order opens.   |
//|  - No second Bollinger re-entry confirmation for averaging.       |
//|  - This is a direct-distance grid martingale structure.     |
//|                                                                  |
#property strict
#property version   "1.30"
#property description "BB_grid v1.3 - direct LOT1~LOT10 order size settings"
#property description "High risk version: distance reached -> immediate next grid entry"

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
input bool   DrawBandTouchMarks = true;

//===================================================
// [12] AXION 라이선스 (변경 금지)
//===================================================
input string SETTING__________12 = "============ [AXION 라이선스] 변경금지 ============";
input string _121_ = "관리자페이지 등록 프로그램명과 일치해야 함";
input string 프로그램명 = "Bolinger_past";
input string _122_ = "서버 주소 (변경금지)";
input string 서버주소 = "https://wmvnearoursbmwjqwzww.supabase.co";
input bool   SendBalance = true;        // 잔고를 서버에 주기적으로 적재
input int    SendBalanceMinutes = 5;    // 잔고 전송 주기(분) / 최소 1분
input int    LicenseGraceTries = 5;     // 일시 장애 유예: 연속 실패 이 횟수까지 매매 유지(60초 간격, 상한 30)

bool     g_running = false;
datetime g_lastBarTime = 0;
bool     g_upperBreakoutArmed = false;
bool     g_lowerBreakoutArmed = false;
datetime g_upperBreakoutTime = 0;
datetime g_lowerBreakoutTime = 0;

// AXION 라이선스 / 잔고 적재 상태
bool     g_licenseOK        = false;
bool     g_licenseChecked   = false;  // 최초 라이선스 확인 성공 여부
bool     g_riskAccepted     = false;  // 위험고지 동의 여부
bool     g_riskPrompted     = false;  // 위험고지 팝업 표시 여부 (1회만)
bool     g_licenseDenied    = false;  // 서버가 명시적으로 거부(일시 장애와 구분)
int      g_licenseFailStreak= 0;      // 연속 확인 실패 횟수
bool     g_riskDeferred     = false;  // 포지션 보유로 위험고지 팝업을 보류한 상태
bool     g_balanceDirty     = false;  // 청산이 발생해 확정 잔고 적재가 필요한 상태
string   g_licenseStatus    = "확인 중...";
datetime g_lastLicenseCheck = 0;      // TimeLocal 기준 (틱 없는 주말에도 진행)
datetime g_lastBalanceSend  = 0;      // TimeLocal 기준
bool     g_balanceHalt      = false;

string PANEL_BG  = "BBGRID_PANEL_BG";
string PANEL_TOP = "BBGRID_PANEL_TOP";
string PANEL_TX  = "BBGRID_PANEL_TX_";
string MARK_PREFIX = "BBGRID_MARK_";
string BAND_PREFIX = "BBGRID_BAND_";

//+------------------------------------------------------------------+
//| AXION 라이선스 — Edge Function 방식 (anon 키를 EA에 노출하지 않음) |
//+------------------------------------------------------------------+
//| g_licenseDenied: 서버가 계좌를 명시적으로 거부한 경우에만 true.
//| 네트워크/서버 장애는 false로 남겨 유예 로직이 즉시 청산하지 않도록 한다.
bool CheckLicense()
{
   g_licenseDenied = false;

   string acc  = IntegerToString((int)AccountNumber());
   string body = "{\"account_no\":\"" + acc + "\",\"program_name\":\"" + 프로그램명 + "\"}";

   char req[]; char res[]; string rhs;
   int reqLen = StringToCharArray(body, req, 0, WHOLE_ARRAY, CP_UTF8) - 1;  // 종료 널 제외
   if(reqLen < 0) reqLen = 0;
   ArrayResize(req, reqLen);

   ResetLastError();
   // 타임아웃을 짧게 잡는다. 이 호출은 OnTimer(=OnTick과 같은 스레드)에서 나가므로
   // 대기하는 동안 유일한 청산 장치인 CheckSideBasket이 멈춘다. 재시도는 60초 주기로
   // 이미 존재하므로 긴 타임아웃은 이득 없이 무관리 구간만 늘린다.
   int http = WebRequest("POST",
                         서버주소 + "/functions/v1/check-license",
                         "Content-Type: application/json\r\n",
                         3000, req, res, rhs);

   if(http < 0)
   {
      int err = GetLastError();
      if(err == 4060)
         g_licenseStatus = "WebRequest URL 미등록 (도구>옵션>EA)";
      else
         g_licenseStatus = "네트워크 오류 (err=" + IntegerToString(err) + ")";
      Print("BB_grid 라이선스 ERROR: ", g_licenseStatus);
      return false;
   }

   string resp = CharArrayToString(res, 0, WHOLE_ARRAY, CP_UTF8);
   Print("BB_grid 라이선스 HTTP=", http, " body=", resp);

   if(http == 200 && StringFind(resp, "\"authorized\":true") >= 0)
   {
      string expStr = "";
      int ep = StringFind(resp, "\"expires_at\":\"");
      if(ep >= 0) expStr = StringSubstr(resp, ep + 14, 10);

      g_licenseStatus = "정상 (" + expStr + "까지)";
      Print("BB_grid 라이선스 OK: ", g_licenseStatus);
      return true;
   }

   // HTTP 200 + authorized:false → 서버가 판정한 확정 거부 (미등록/만료/미할당)
   // 그 외 상태코드(500 등)는 서버 장애로 보고 확정 거부로 취급하지 않는다.
   if(http == 200 && StringFind(resp, "\"authorized\":false") >= 0)
      g_licenseDenied = true;

   string reason = "라이선스 없음";
   int rp = StringFind(resp, "\"reason\":\"");
   if(rp >= 0)
   {
      rp += 10;
      int re = StringFind(resp, "\"", rp);
      if(re > rp) reason = StringSubstr(resp, rp, re - rp);
   }
   if(!g_licenseDenied) reason = reason + " (HTTP=" + IntegerToString(http) + ")";

   g_licenseStatus = reason;
   Print("BB_grid 라이선스 ERROR: ", g_licenseStatus);
   return false;
}

//+------------------------------------------------------------------+
//| 잔고 적재 — submit-balance Edge Function                          |
//| force=true 면 주기와 무관하게 즉시 전송 (청산 직후 등)            |
//+------------------------------------------------------------------+
void SendBalanceToSupabase(bool force = false)
{
   if(!SendBalance) return;
   // g_licenseOK가 아니라 g_licenseChecked로 판정한다. 라이선스 실효 직후의
   // 청산 잔고도 적재해야 하며, 한 번도 인증된 적 없는 계좌는 여전히 전송하지 않는다.
   if(!g_licenseChecked) return;

   int intervalSec = SendBalanceMinutes * 60;
   if(intervalSec < 60) intervalSec = 60;   // 서버 부하 방지: 최소 1분

   if(!force && g_lastBalanceSend != 0 && TimeLocal() - g_lastBalanceSend < intervalSec) return;
   g_lastBalanceSend = TimeLocal();

   string acc  = IntegerToString((int)AccountNumber());
   string body = "{\"account_no\":\"" + acc +
                 "\",\"balance\":" + DoubleToString(AccountBalance(), 2) +
                 ",\"equity\":"    + DoubleToString(AccountEquity(), 2) +
                 ",\"profit\":"    + DoubleToString(AccountEquity() - AccountBalance(), 2) + "}";

   char p[]; char r[]; string rh;
   int bodyLen = StringToCharArray(body, p, 0, WHOLE_ARRAY, CP_UTF8) - 1;  // 종료 널 제외
   if(bodyLen < 0) bodyLen = 0;
   ArrayResize(p, bodyLen);

   ResetLastError();
   int http = WebRequest("POST",
                         서버주소 + "/functions/v1/submit-balance",
                         "Content-Type: application/json\r\n",
                         3000, p, r, rh);   // 스레드 블로킹 최소화 (CheckSideBasket 정지 방지)

   // submit-balance는 insert 실패 시에도 HTTP 200 + {"ok":false}를 반환하므로
   // 상태코드만으로는 적재 실패를 감지할 수 없다.
   string resp = (http < 0) ? "" : CharArrayToString(r, 0, WHOLE_ARRAY, CP_UTF8);
   if(http != 200 || StringFind(resp, "\"ok\":true") < 0)
      Print("BB_grid 잔고 전송 실패 / HTTP=", http,
            " / err=", GetLastError(), " / body=", resp);
}

//+------------------------------------------------------------------+
//| 청산으로 잔고가 변했을 때 1회만 적재한다.                          |
//| 청산 루프 안에서 HTTP를 기다리지 않도록 호출부에서 마지막에 부른다.|
//+------------------------------------------------------------------+
void FlushBalance()
{
   if(!g_balanceDirty) return;
   g_balanceDirty = false;
   SendBalanceToSupabase(true);
}

//+------------------------------------------------------------------+
//| 화면 Comment의 단일 소유자. 여러 함수가 각자 Comment를 쓰면        |
//| 서로 덮어써서 안내가 사라지므로, 상태에서 한 줄을 조립해 출력한다. |
//+------------------------------------------------------------------+
string StatusLine()
{
   if(g_balanceHalt)                     return "BB_grid: 잔고 $50 이하 — 청산 후 종료";
   if(g_lastLicenseCheck == 0)           return "BB_grid: 라이선스 확인 중...";
   if(!g_licenseChecked)                 return "BB_grid: 라이선스 없음 — " + g_licenseStatus;
   if(!g_licenseOK)                      return "BB_grid: 라이선스 오류 — " + g_licenseStatus;
   if(g_licenseFailStreak > 0)           return "BB_grid: 라이선스 재확인 중 — " + g_licenseStatus;
   if(g_riskAccepted)                    return "";   // 정상 가동 — 화면은 패널이 담당
   if(g_riskDeferred)                    return "BB_grid: 위험고지 동의 대기 (보유 포지션 청산 관리 중) — 신규 진입 차단";
   if(g_riskPrompted)                    return "BB_grid: 위험고지 미동의 — 거래가 중지되었습니다 (재부착 시 재확인)";
   return "";
}

//+------------------------------------------------------------------+
//| 위험고지 동의 — 계좌당 최초 1회만 팝업                            |
//+------------------------------------------------------------------+
string RiskConsentKey()
{
   return "BBGRID_RISK_OK_" + IntegerToString((int)AccountNumber());
}

bool PromptRiskDisclosure()
{
   if(g_riskAccepted) return true;

   // 이 계좌에서 이미 동의했으면 다시 묻지 않는다.
   // MessageBox는 모달이라 떠 있는 동안 OnTick/OnTimer가 멈춘다. 이 EA는 브로커측
   // TP/SL이 없어 CheckSideBasket이 유일한 청산 장치이므로, 재부착할 때마다 팝업을
   // 띄우면 보유 그리드가 그동안 무방비로 방치된다.
   string key = RiskConsentKey();
   if(GlobalVariableCheck(key))
   {
      GlobalVariableSet(key, 1);   // MT4는 4주 미사용 시 삭제 — 접근 시각 갱신
      g_riskAccepted = true;
      g_riskDeferred = false;
      Print("BB_grid: 위험고지 동의 기록 확인 / Acc=", AccountNumber());
      return true;
   }

   if(g_riskPrompted) return false;   // 이미 물었고 거부됨 — 재부착 전까지 다시 묻지 않음

   // 보유 포지션이 있으면 모달을 띄우지 않는다. 모달이 스레드를 잡으면 CheckSideBasket이
   // 멈춰 그리드가 방치되므로, 청산 관리를 계속하면서 플랫이 될 때까지 팝업을 미룬다.
   // (신규 진입은 g_riskAccepted=false 이므로 TradingAllowed()가 계속 차단한다.)
   if(CountSide(OP_BUY) + CountSide(OP_SELL) > 0)
   {
      if(!g_riskDeferred)
      {
         g_riskDeferred = true;
         Print("BB_grid: 보유 포지션이 있어 위험고지 팝업을 보류합니다 — 청산 관리는 계속됩니다");
         Alert("BB_grid: 위험고지 동의 필요 — 보유 포지션 청산 후 팝업이 표시됩니다");
      }
      return false;   // 화면 안내는 StatusLine()이 담당
   }

   g_riskDeferred = false;
   g_riskPrompted = true;

   string riskMsg =
      "EA 시작 전 필수 투자위험 및 책임 고지\n\n"
      "본 EA는 자동매매 보조 프로그램이며 수익을 보장하지 않습니다\n\n"
      "본 EA는 마틴게일 그리드 구조로 손실이 급격히 확대될 수 있습니다\n\n"
      "레버리지 상품은 시장 변동성 스프레드 확대 슬리피지 체결 지연 서버 장애 증거금 부족 마진콜 강제청산 등으로 인해 큰 손실이 발생할 수 있습니다\n\n"
      "기본 설정값 안내값 백테스트 과거 운용 결과 예시 수익률 시뮬레이션 자료는 참고용 정보이며 미래 수익이나 손실 제한을 보장하지 않습니다\n\n"
      "본 프로그램은 투자권유 투자자문 투자일임 대리매매 계좌운용을 목적으로 하지 않습니다\n\n"
      "EA의 설치 설정 실행 중지 포지션 청산 운용 여부에 대한 최종 판단과 책임은 전적으로 이용자 본인에게 있습니다\n\n"
      "본인의 투자 경험 재무상태 위험 감내 수준 계좌 상황을 충분히 고려한 뒤 사용 여부를 결정해야 합니다\n\n"
      "위 내용을 이해했으며 본인 판단과 책임으로 EA를 실행합니다\n\n"
      "동의하시면 예 버튼을 눌러 시작하세요";

   if(MessageBox(riskMsg, "BB_grid", MB_YESNO|MB_ICONWARNING) != IDYES)
   {
      g_riskAccepted = false;
      Print("BB_grid: 위험고지 미동의 — 거래가 중지됩니다.");
      return false;
   }

   g_riskAccepted = true;
   GlobalVariableSet(key, 1);   // 계좌별 동의 기록 — 재부착 시 팝업 생략
   Print("BB_grid 시작 / Acc=", AccountNumber(), " / ", g_licenseStatus);
   return true;
}

//+------------------------------------------------------------------+
//| 라이선스 확인/재검증 — 최초 확인과 재검증을 같은 간격 게이트로 처리 |
//| 간격: 정상 1시간 / 실패 1분. 실효 확정 시 보유 포지션 청산.        |
//| 일시적 네트워크·서버 장애로 실제 포지션을 청산하지 않도록,         |
//| 확정 거부(authorized:false)가 아니면 LicenseGraceTries 회까지 유예.|
//+------------------------------------------------------------------+
void MaintainLicense()
{
   // 정상 확인된 상태에서만 1시간 간격. 실패가 시작되면(유예 중 포함) 60초 간격으로
   // 재시도해야 LicenseGraceTries가 의도한 유예 시간(회수 x 60초)이 된다.
   int intervalSec = (g_licenseOK && g_licenseFailStreak == 0) ? 3600 : 60;
   if(g_lastLicenseCheck != 0 && TimeLocal() - g_lastLicenseCheck < intervalSec) return;
   g_lastLicenseCheck = TimeLocal();

   if(CheckLicense())
   {
      g_licenseOK         = true;
      g_licenseFailStreak = 0;
      g_licenseChecked    = true;

      // 동의 기록의 접근 시각을 주기적으로 갱신한다. 갱신이 부착 시점에만 일어나면
      // 4주 넘게 무중단 가동할 때 MT4가 변수를 삭제해, 다음 재부착에서 모달이 뜬다.
      if(g_riskAccepted) GlobalVariableSet(RiskConsentKey(), 1);
      return;
   }

   g_licenseFailStreak++;

   // 최초 인증 전 — 매매가 시작된 적이 없으므로 재시도만 계속
   if(!g_licenseChecked) return;

   // 이미 실효 처리됨 — 복구 시도만 계속.
   // 직전 실효 청산이 부분 실패했을 수 있으므로 잔여 포지션이 있으면 재청산한다.
   if(!g_licenseOK)
   {
      if(CountSide(OP_BUY)  > 0) CloseSide(OP_BUY,  "LICENSE_REVOKED");
      if(CountSide(OP_SELL) > 0) CloseSide(OP_SELL, "LICENSE_REVOKED");
      FlushBalance();
      return;
   }

   int graceTries = LicenseGraceTries;
   if(graceTries < 1)  graceTries = 1;
   if(graceTries > 30) graceTries = 30;   // 상한: 무기한 유예로 라이선스를 우회하지 못하도록

   if(!g_licenseDenied && g_licenseFailStreak <= graceTries)
   {
      Print("BB_grid: 라이선스 확인 일시 실패 (", g_licenseFailStreak, "/", graceTries,
            ") — 매매 유지 / ", g_licenseStatus);
      return;
   }

   g_licenseOK = false;
   Print("BB_grid: 라이선스 실효 — 전체 청산 후 매매 중단 / ", g_licenseStatus);

   // 양쪽을 모두 청산한 뒤 잔고를 1회만 적재한다.
   CloseSide(OP_BUY,  "LICENSE_REVOKED");
   CloseSide(OP_SELL, "LICENSE_REVOKED");
   FlushBalance();
}

//+------------------------------------------------------------------+
//| 잔고 $50 이하 → BB_grid 포지션 청산 후 EA 종료                    |
//+------------------------------------------------------------------+
void CheckBalanceStop()
{
   if(!g_balanceHalt)
   {
      if(AccountBalance() > 50.0) return;
      g_balanceHalt = true;
      Print(">>> BB_grid: 잔고 $50 이하 도달 — 전체 청산 후 EA 종료");
   }

   // halt 상태에서는 잔여 포지션이 없어질 때까지 매 틱 재시도한다.
   if(CountSide(OP_BUY)  > 0) CloseSide(OP_BUY,  "BALANCE_HALT");
   if(CountSide(OP_SELL) > 0) CloseSide(OP_SELL, "BALANCE_HALT");

   // 청산이 끝나기 전에 EA를 제거하면 남은 포지션이 브로커측 TP/SL 없이 방치된다.
   if(CountSide(OP_BUY) > 0 || CountSide(OP_SELL) > 0)
   {
      Comment("BB_grid: 잔고 $50 이하 — 청산 재시도 중");
      return;
   }

   // ExpertRemove 이후에는 OnTimer가 돌지 않으므로 최종 잔고를 여기서 직접 적재한다.
   g_balanceDirty = true;
   FlushBalance();

   Comment("BB_grid: 잔고 $50 이하 — EA 종료됨");
   ExpertRemove();
}

//+------------------------------------------------------------------+
//| 매매 허용 조건: 실행중 + 잔고정지 아님 + 라이선스/동의 완료        |
//+------------------------------------------------------------------+
bool TradingAllowed()
{
   if(!g_running)      return false;
   if(g_balanceHalt)   return false;
   if(!g_licenseOK)    return false;
   if(!g_riskAccepted) return false;
   return true;
}

string PanelStatusText()
{
   if(g_balanceHalt)            return "HALTED (잔고 $50 이하)";
   if(g_lastLicenseCheck == 0)  return "LICENSE 확인 중";   // 아직 첫 시도 전
   if(!g_licenseOK)             return "NO LICENSE";
   if(!g_riskAccepted)          return "위험고지 미동의";
   if(!g_running)               return "PAUSED";
   return "RUNNING";
}

// 패널 폭(390px)을 넘지 않도록 상태 문자열을 자른다
string PanelLicenseText()
{
   string s = g_licenseStatus;
   if(StringLen(s) > 36) s = StringSubstr(s, 0, 33) + "...";
   return s;
}

int OnInit()
{
   g_running = AutoStart;

   g_licenseOK         = false;
   g_licenseChecked    = false;
   g_riskAccepted      = false;
   g_riskPrompted      = false;
   g_licenseDenied     = false;
   g_licenseFailStreak = 0;
   g_riskDeferred      = false;
   g_balanceDirty      = false;
   g_licenseStatus     = "확인 중...";
   g_lastLicenseCheck  = 0;
   g_lastBalanceSend   = 0;
   g_balanceHalt       = false;

   if(SetChartStyle)
      SetupChart();

   if(ShowAutoBollingerBands)
      DrawAutoBollingerBands();

   EventSetTimer(1);   // OnTimer에서 라이선스 확인 / 잔고 적재
   Comment("BB_grid: 라이선스 확인 중...");

   Print("BB_grid v1.3 initialized / Symbol=", Symbol(),
         " / Magic=", MagicNumber,
         " / LOT1=", DoubleToString(LOT1, 2),
         " / BB=", BBperiod, ", ", DoubleToString(BBdeviation, 2),
         " / Program=", 프로그램명, " / Acc=", AccountNumber());

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeletePanel();
   DeleteBandObjects();

   // 잔고 소진으로 스스로 종료한 경우에는 사유를 화면에 남긴다.
   // ExpertRemove()는 OnDeinit을 부르므로, 무조건 지우면 CheckBalanceStop이 방금 쓴
   // 안내까지 사라져 사용자에게는 EA가 이유 없이 없어진 것처럼 보인다.
   Comment(g_balanceHalt ? "BB_grid: 잔고 $50 이하 — EA 종료됨" : "");

   Print("BB_grid v1.3 deinitialized / reason=", reason);
}

//+------------------------------------------------------------------+
//| 1초 타이머: 라이선스 확인 / 위험고지 / 재검증 / 잔고 적재          |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(g_balanceHalt) return;

   // 틱이 유실되거나 OnTick이 굶는 구간에서도 최소 1초 해상도로 바스켓을 관리한다.
   // CheckSideBasket이 유일한 청산 장치이므로 이중화한다.
   CheckSideBasket(OP_BUY);
   CheckSideBasket(OP_SELL);
   FlushBalance();   // 양쪽 청산이 끝난 뒤에만 적재 — 청산 사이에 HTTP를 끼우지 않는다

   MaintainLicense();

   // 라이선스 확인 후에도 미동의 상태면 계속 시도한다. 포지션 보유 중에는 팝업이
   // 보류되므로, 플랫이 되는 즉시 팝업이 뜨도록 매 초 확인한다.
   if(g_licenseOK && !g_riskAccepted)
      PromptRiskDisclosure();

   // 위험고지를 거부한 계좌의 재무정보는 수집하지 않는다. 보류(g_riskDeferred) 상태의
   // 포지션은 과거에 동의를 받고 진입한 것이므로 주기 적재를 유지한다.
   if(g_licenseOK && (g_riskAccepted || g_riskDeferred))
      SendBalanceToSupabase();

   Comment(StatusLine());
}

void OnTick()
{
   CheckBalanceStop();
   if(g_balanceHalt) return;

   // 이 EA는 브로커측 TP/SL을 심지 않는다(OpenOrder의 sl=0, tp=0).
   // CheckSideBasket이 유일한 청산 장치이므로 라이선스·동의 상태와 무관하게
   // 항상 실행해야 보유 그리드가 방치되지 않는다.
   // 잔고 적재는 OnTimer가 처리한다(최대 1초 지연) — 틱 스레드에서 네트워크를 기다리지 않는다.
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
   bool closedAny = false;

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
            closedAny = true;
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

   // 여기서 직접 전송하지 않는다. CloseSide는 BUY/SELL 양쪽에 대해 연속 호출되므로,
   // 이 자리에서 HTTP를 기다리면 반대편 청산이 그만큼 지연된다. 호출부가 양쪽 처리를
   // 끝낸 뒤 FlushBalance()로 1회만 적재한다.
   if(closedAny) g_balanceDirty = true;
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

   SetPanelLine(line++, "BB_grid", clrWhite, 15);
   SetPanelLine(line++, "SYMBOL / TF   : " + Symbol() + " / " + IntegerToString(Period()), clrWhite, 9);
   SetPanelLine(line++, "STATUS        : " + PanelStatusText(), TradingAllowed() ? clrLime : clrTomato, 9);
   SetPanelLine(line++, "LICENSE       : " + PanelLicenseText(), g_licenseOK ? clrLime : clrTomato, 9);
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
