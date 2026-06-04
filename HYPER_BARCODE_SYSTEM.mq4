#property strict

// ==========================================================
// 하이퍼 바코드 시스템 - Premium UI V1
// ----------------------------------------------------------
// Logic based on the provided reference:
// 1) Golden cross between two moving averages => BUY entry
//    Death cross between two moving averages  => SELL entry
// 2) If a BUY was entered by golden cross but not closed,
//    and a death cross appears, open SELL with martingale lot.
// 3) If positions remain open and crosses keep changing,
//    continue alternating BUY/SELL entries with martingale lots.
// 4) Close all EA positions when total floating P/L reaches TARGET_PROFIT.
// 5) Close all EA positions and stop when account equity reaches SAFE_EXIT.
// 6) Optional trading-hour filter, spread limit, magic number.
// ----------------------------------------------------------
// This EA can hold BUY and SELL positions at the same time.
// Martingale is high-risk. Demo test first.
// ==========================================================


// =========================
// Internal
// =========================
bool   UsePassword      = false;
int    Password         = 201021;


// =========================
// License - Axion Research
// =========================
extern string LICENSE_SETTING = "========== License Setting (Axion Research) ==========";
extern bool   UseLicenseCheck    = true;             // Axion Research 파트너 라이센스 체크
extern string LicenseAccountNo   = "";               // 비우면 현재 계좌 사용
extern string ProgramName        = "HYPER_BARCODE_SYSTEM"; // Supabase 프로그램명
extern bool   SendBalance        = true;             // 잔고 전송 여부
extern int    SendBalanceMinutes = 3;                // 전송 주기 (분)

bool     LicenseOK = false;
string   LicenseStatus = "확인 중...";
datetime LastLicenseCheck = 0;
datetime LastBalanceSend  = 0;


// =========================
// Order Setting
// =========================
input string SETTING_________2 = "========== Order Setting ==========";
input int    MagicNumber      = 10;
input double Lots             = 0.01;


// =========================
// Hidden Signal Core
// =========================
// Signal formula is hidden from user inputs.
// Internal baseline: 5 / 20 EMA.
int    MAperiod_1       = 5;
int    MAperiod_2       = 20;
int    MAMethod         = MODE_EMA;
int    MAPrice          = PRICE_CLOSE;


// =========================
// Close Setting
// =========================
input string SETTING_________4 = "========== Close Setting ==========";
input double TARGET_PROFIT    = 10.0;     // TARGET PROFIT
input double SAFE_EXIT        = 0.0;      // SAFE EXIT


// =========================
// Martingale Setting
// =========================
input string SETTING_________5 = "========== Martingale Setting ==========";
input double LotMulti         = 2.0;      // Martingale multiplier
input int    InitialBarcodeStartLine = 1; // Initial start line, 1~5
int BarcodeStartLine = 1;                 // Runtime value changed by chart buttons


// =========================
// Hidden Execution Settings
// =========================
int    SpreadLimit      = 999999;       // hidden / disabled


int    StartHour        = 0;            // hidden / always open
int    EndHour          = 24;           // hidden / always open
bool   ForceCloseAtEndHour = false;     // hidden / disabled


int    Slippage         = 5;            // hidden
bool   TradeOnNewBarOnly = true;         // hidden
bool   ShowRiskPopup    = true;          // hidden
bool   SetChartStyle    = true;          // hidden

// Hidden visual settings
bool   DrawMovingAverages = false;
int    DrawBarsCount      = 250;
color  FastMAColor        = clrNONE;
color  SlowMAColor        = clrNONE;
bool   DrawCrossMarks     = true;
int    CrossLookbackBars  = 600;


// =========================
// Runtime
// =========================
bool EAStopped = false;
datetime LastBarTime = 0;
datetime LastSignalBarTime = 0;
int HYPERSystemCount = 0;
double SessionStartBalance = 0;
bool SystemEnabled = true;

enum BARCODE_MODE
{
   MODE_HYPER = 0,
   MODE_NORMAL = 1,
   MODE_STRADA = 2
};

BARCODE_MODE CurrentBarcodeMode = MODE_HYPER;

int LastBarcodeSignal = 0;
datetime LastBarcodeSignalTime = 0;
datetime LastExecutedSignalTime = 0;
datetime LastHitBarcodeTime = 0;
int LastHitBarcodeSignal = 0;

string PANEL_BG     = "MACM_PANEL_BG";
string PANEL_TOP    = "MACM_PANEL_TOP";
string PANEL_PREFIX = "MACM_PANEL_LINE_";
string PANEL_ROW_PREFIX = "MACM_PANEL_ROW_";
string BTN_ON  = "BARCODE_BTN_ON";
string BTN_OFF = "BARCODE_BTN_OFF";
string BTN_HYPER  = "BARCODE_BTN_HYPER";
string BTN_NORMAL = "BARCODE_BTN_NORMAL";
string BTN_STRADA = "BARCODE_BTN_STRADA";
string BTN_SHOT   = "BARCODE_BTN_SHOT";
string BTN_START_PREFIX = "BARCODE_START_";
string TARGET_LINE = "BARCODE_TARGET_LINE";
string TARGET_TEXT = "BARCODE_TARGET_TEXT";

string GV_HIT_TIME;
string GV_HIT_SIGNAL;

string FAST_MA_PREFIX = "MACM_FAST_MA_";
string SLOW_MA_PREFIX = "MACM_SLOW_MA_";
string CROSS_PREFIX   = "MACM_CROSS_";
string CROSS_TX_PREFIX= "MACM_CROSS_TX_";


// =========================
// Forward Declarations
// =========================
int    GetSignal();
string SignalText(int sig);
color  SignalColor(int sig);

void   ProcessEA();
bool   IsNewBar();
bool   IsTradingTime();
bool   IsSpreadOK();

double GetMA(int period, int shift);
double NextLot();
double NormalizeLots(double lots);

bool   OpenOrderBySignal(int sig);
void   CloseAllEAOrders();
bool   CloseOrderByTicket(int ticket);

int    CountEAOrders();
int    CountEAOrdersByType(int type);
double TotalLots();
double TotalProfit();
double TotalProfitByType(int type);
double TodayClosedProfit();
double TodayTotalProfit();
double LastOpenPrice();
string LastOrderTypeText();

void   SetupChart();
void   DrawVisualObjects();
void   DrawMovingAverageLines();
void   DrawCrossSignals();
bool   IsHistoricalHitShift(int targetShift);
void   CalculateHitLineStats(int &hit1, int &hit2, int &hit3, int &hit4, int &hit5, int &hitMore, int &totalHits);
void   CalculateHitLineDirectionStats(int &b1, int &s1, int &b2, int &s2, int &b3, int &s3, int &b4, int &s4, int &b5, int &s5, int &bm, int &sm, int &totalHits);
void   ClearVisualObjects();
void   DrawPanel();
void   DrawControlButtons();
void   ApplyBarcodeMode();
string BarcodeModeText();
void   DrawTargetLine();
void   DeleteTargetLine();
void   TryEnterLastSignal();
bool   GetLatestBarcodeSignal(int &sig, datetime &sigTime);
void   ShotEntry();
void   SetPanelLine(int idx, string text, color c, int fontSize=10);
void   SetPanelRow(int idx, color bg, color border);
void   SetButton(string name, string text, int x, int y, int w, int h, color bg);
void   DeletePanel();

string Money(double v);
string Dbl(double v, int d);
bool   CheckLicense();


// =========================
// Init / Deinit
// =========================
int OnInit()
{
   LicenseOK = false;
   LicenseStatus = "확인 중...";
   
   Comment("HYPER BARCODE: 라이센스 확인 중...");
   Sleep(300);
   
   if(!CheckLicense())
   {
      Comment("HYPER BARCODE: " + LicenseStatus + "\nAxion Research 파트너 페이지에서 권한을 신청하세요.");
      Alert("HYPER BARCODE: 라이센스 없음. Axion Research 파트너 페이지에서 권한 신청 필요.");
      return(INIT_FAILED);
   }
   
   Comment("");  // 라이센스 확인 메시지 제거
   
   if(ShowRiskPopup)
   {
      string riskText = "";
      riskText = riskText + "EA 시작 전 필수 투자위험 및 책임 고지\n\n";
      riskText = riskText + "본 EA는 자동매매 보조 프로그램이며 수익을 보장하지 않습니다\n\n";
      riskText = riskText + "레버리지 상품은 시장 변동성 스프레드 확대 슬리피지 체결 지연 서버 장애 증거금 부족 마진콜 강제청산 등으로 인해 큰 손실이 발생할 수 있습니다\n\n";
      riskText = riskText + "기본 설정값 안내값 백테스트 과거 운용 결과 예시 수익률 시뮬레이션 자료는 참고용 정보이며 미래 수익이나 손실 제한을 보장하지 않습니다\n\n";
      riskText = riskText + "본 프로그램은 투자권유 투자자문 투자일임 대리매매 계좌운용을 목적으로 하지 않습니다\n\n";
      riskText = riskText + "EA의 설치 설정 실행 중지 포지션 청산 운용 여부에 대한 최종 판단과 책임은 전적으로 이용자 본인에게 있습니다\n\n";
      riskText = riskText + "본인의 투자 경험 재무상태 위험 감내 수준 계좌 상황을 충분히 고려한 뒤 사용 여부를 결정해야 합니다\n\n";
      riskText = riskText + "위 내용을 이해했으며 본인 판단과 책임으로 EA를 실행합니다\n\n";
      riskText = riskText + "동의하시면 예 버튼을 눌러 시작하세요";

      int answer = MessageBox(riskText, "하이퍼 바코드 시스템", MB_YESNO | MB_ICONWARNING);

      if(answer != IDYES)
         return(INIT_FAILED);
   }

   if(SetChartStyle)
      SetupChart();

   SessionStartBalance = AccountBalance();

   GV_HIT_TIME = "BARCODE_LAST_HIT_TIME_" + Symbol() + "_" + IntegerToString(MagicNumber);
   GV_HIT_SIGNAL = "BARCODE_LAST_HIT_SIGNAL_" + Symbol() + "_" + IntegerToString(MagicNumber);

   if(GlobalVariableCheck(GV_HIT_TIME))
      LastHitBarcodeTime = (datetime)GlobalVariableGet(GV_HIT_TIME);

   if(GlobalVariableCheck(GV_HIT_SIGNAL))
      LastHitBarcodeSignal = (int)GlobalVariableGet(GV_HIT_SIGNAL);

   BarcodeStartLine = InitialBarcodeStartLine;
   if(BarcodeStartLine < 1) BarcodeStartLine = 1;
   if(BarcodeStartLine > 5) BarcodeStartLine = 5;

   CurrentBarcodeMode = MODE_HYPER;
   ApplyBarcodeMode();

   LastBarTime = iTime(Symbol(), Period(), 0);
   DrawVisualObjects();
   DrawControlButtons();
   DrawTargetLine();
   DrawPanel();
   EventSetTimer(1);

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeletePanel();
   ClearVisualObjects();
}


void SendBalanceToSupabase()
{
   string anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indtdm5lYXJvdXJzYm13anF3end3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgxNzQ5MjEsImV4cCI6MjA5Mzc1MDkyMX0.MS4iSGIvW4dBi3sd8J3baHLT4TlgUJS5lXwlhJdWYEY";
   string acc  = IntegerToString((int)AccountNumber());
   string body = "{\"account_no\":\""+acc+"\",\"balance\":"+DoubleToString(AccountBalance(),2)+
                 ",\"equity\":"+DoubleToString(AccountEquity(),2)+
                 ",\"profit\":"+DoubleToString(AccountEquity()-AccountBalance(),2)+"}";
   string h = "Content-Type: application/json\r\napikey: "+anonKey+
              "\r\nAuthorization: Bearer "+anonKey+"\r\nPrefer: return=minimal";
   char p[]; char r[]; string rh;
   StringToCharArray(body,p,0,StringLen(body)); ArrayResize(p,StringLen(body));
   WebRequest("POST","https://wmvnearoursbmwjqwzww.supabase.co/rest/v1/balance_logs",h,5000,p,r,rh);
}

//+------------------------------------------------------------------+
//| 라이센스 체크 함수 (Axion Research 파트너 페이지)
//+------------------------------------------------------------------+
bool CheckLicense()
{
   if(!UseLicenseCheck)
   {
      LicenseOK = true;
      LicenseStatus = "라이센스 체크 안 함";
      return(true);
   }

   // 1시간마다 재확인
   if(LicenseOK && TimeCurrent() - LastLicenseCheck < 3600)
      return(true);

   string acct = LicenseAccountNo;
   if(StringLen(acct) == 0)
      acct = IntegerToString(AccountNumber());

   string anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indtdm5lYXJvdXJzYm13anF3end3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgxNzQ5MjEsImV4cCI6MjA5Mzc1MDkyMX0.MS4iSGIvW4dBi3sd8J3baHLT4TlgUJS5lXwlhJdWYEY";
   string baseURL = "https://wmvnearoursbmwjqwzww.supabase.co";
   string headers = "apikey: " + anonKey + "\r\n"
                  + "Authorization: Bearer " + anonKey + "\r\n"
                  + "Content-Type: application/json";
   char req[], res1[];
   string resHeaders;

   // ── Step 1: account_no + is_active 확인, id + expires_at 취득 ──
   string url1 = baseURL + "/rest/v1/customers"
               + "?account_no=eq." + acct
               + "&is_active=eq.true"
               + "&select=id,expires_at";

   int ret1 = WebRequest("GET", url1, headers, 5000, req, res1, resHeaders);
   if(ret1 < 0)
   {
      int err = GetLastError();
      if(err == 4060)
      {
         LicenseStatus = "WebRequest URL 미등록. MT4 설정 필요.";
         Print("라이센스 ERROR: ", LicenseStatus);
         Print("라이센스 ERROR: MT4 → 도구 → 옵션 → Expert Advisors → WebRequest URL 추가:");
         Print("라이센스 ERROR: ", baseURL);
      }
      else
         LicenseStatus = "네트워크 오류 (err=" + IntegerToString(err) + ")";
      Print("라이센스 ERROR: ", LicenseStatus);
      LicenseOK = false;
      return(false);
   }

   string body1 = CharArrayToString(res1);
   Print("라이센스 Step1 HTTP=", ret1, " body=", body1);

   if(ret1 != 200 || body1 == "[]" || StringFind(body1, "expires_at") < 0)
   {
      LicenseStatus = "미등록/비활성 계좌 (HTTP=" + IntegerToString(ret1) + ")";
      Print("라이센스 ERROR: ", LicenseStatus, " | 계좌=", acct);
      LicenseOK = false;
      return(false);
   }

   // 만료일 파싱
   int es = StringFind(body1, "\"expires_at\":\"") + 14;
   string expStr = StringSubstr(body1, es, 10);
   StringReplace(expStr, "-", ".");
   if(expStr < TimeToString(TimeCurrent(), TIME_DATE))
   {
      LicenseStatus = "라이센스 만료됨 (" + expStr + ")";
      Print("라이센스 ERROR: ", LicenseStatus);
      LicenseOK = false;
      return(false);
   }

   // customer id 파싱 (UUID 문자열 / 정수형 모두 처리)
   string custId = "";
   int idPos = StringFind(body1, "\"id\":");
   if(idPos >= 0)
   {
      int vStart = idPos + 5;
      if(StringGetCharacter(body1, vStart) == '"')
      {
         // UUID 타입: "id":"xxxxxxxx-..."
         vStart++;
         int vEnd = StringFind(body1, "\"", vStart);
         if(vEnd > vStart) custId = StringSubstr(body1, vStart, vEnd - vStart);
      }
      else
      {
         // 정수 타입: "id":12345
         int vEnd = vStart;
         while(vEnd < StringLen(body1))
         {
            ushort c = StringGetCharacter(body1, vEnd);
            if(c < '0' || c > '9') break;
            vEnd++;
         }
         if(vEnd > vStart) custId = StringSubstr(body1, vStart, vEnd - vStart);
      }
   }
   if(custId == "")
   {
      LicenseStatus = "ID 파싱 실패";
      Print("라이센스 ERROR: ", LicenseStatus);
      LicenseOK = false;
      return(false);
   }

   // ── Step 2: customer_programs에서 이 EA 할당 여부 확인 ──
   string url2 = baseURL + "/rest/v1/customer_programs"
               + "?customer_id=eq." + custId
               + "&select=programs(name)";

   char res2[];
   string resHeaders2;
   int ret2 = WebRequest("GET", url2, headers, 5000, req, res2, resHeaders2);
   string body2 = CharArrayToString(res2);
   Print("라이센스 Step2 HTTP=", ret2, " body=", body2);

   if(ret2 != 200 || body2 == "[]")
   {
      LicenseStatus = "할당된 EA 없음";
      Print("라이센스 ERROR: ", LicenseStatus);
      LicenseOK = false;
      return(false);
   }

   string body2L = body2; StringToLower(body2L);
   string progL  = ProgramName; StringToLower(progL);
   if(StringFind(body2L, progL) < 0)
   {
      LicenseStatus = "이 EA 미할당 (" + ProgramName + ")";
      Print("라이센스 ERROR: ", LicenseStatus, " | 계좌=", acct);
      LicenseOK = false;
      return(false);
   }

   LicenseOK = true;
   LicenseStatus = "라이센스 OK (만료: " + expStr + ")";
   LastLicenseCheck = TimeCurrent();
   Print("라이센스 OK: ", LicenseStatus);
   return(true);
}

void OnTick()
{
   // 라이센스 체크 (OK 상태: 1시간마다 / 실패 상태: 60초마다 재확인)
   if(UseLicenseCheck)
   {
      int reCheckSec = LicenseOK ? 3600 : 60;
      if(TimeCurrent() - LastLicenseCheck >= reCheckSec)
      {
         if(!CheckLicense())
         {
            Comment("HYPER BARCODE: " + LicenseStatus + "\n(60초마다 자동 재확인 중...)");
            return;
         }
         Comment("");  // 성공 시 메시지 제거
      }

      if(!LicenseOK)
      {
         Comment("HYPER BARCODE: 라이센스 없음. 거래 중지.");
         return;
      }
   }
   
   ProcessEA();
   DrawVisualObjects();
   DrawControlButtons();
   DrawTargetLine();
   DrawPanel();
}

void OnTimer()
{
   ProcessEA();
   DrawVisualObjects();
   DrawControlButtons();
   DrawTargetLine();
   DrawPanel();
   if(LicenseOK && SendBalance && TimeCurrent()-LastBalanceSend >= SendBalanceMinutes*60)
   {
      LastBalanceSend = TimeCurrent();
      SendBalanceToSupabase();
   }
}



// =========================
// Chart Event
// =========================
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK)
      return;

   if(sparam == BTN_ON)
   {
      SystemEnabled = true;
      ObjectSetInteger(0, BTN_ON, OBJPROP_STATE, false);
      DrawControlButtons();
      TryEnterLastSignal();
      return;
   }

   if(sparam == BTN_OFF)
   {
      SystemEnabled = false;
      ObjectSetInteger(0, BTN_OFF, OBJPROP_STATE, false);
      DrawControlButtons();
      return;
   }

   if(sparam == BTN_HYPER)
   {
      CurrentBarcodeMode = MODE_HYPER;
      ApplyBarcodeMode();
      ObjectSetInteger(0, BTN_HYPER, OBJPROP_STATE, false);
      DrawControlButtons();
      return;
   }

   if(sparam == BTN_NORMAL)
   {
      CurrentBarcodeMode = MODE_NORMAL;
      ApplyBarcodeMode();
      ObjectSetInteger(0, BTN_NORMAL, OBJPROP_STATE, false);
      DrawControlButtons();
      return;
   }

   if(sparam == BTN_STRADA)
   {
      CurrentBarcodeMode = MODE_STRADA;
      ApplyBarcodeMode();
      ObjectSetInteger(0, BTN_STRADA, OBJPROP_STATE, false);
      DrawControlButtons();
      return;
   }

   if(sparam == BTN_SHOT)
   {
      ShotEntry();
      ObjectSetInteger(0, BTN_SHOT, OBJPROP_STATE, false);
      DrawControlButtons();
      return;
   }

   for(int i = 1; i <= 5; i++)
   {
      string name = BTN_START_PREFIX + IntegerToString(i);

      if(sparam == name)
      {
         BarcodeStartLine = i;
         ObjectSetInteger(0, name, OBJPROP_STATE, false);
         DrawControlButtons();
         TryEnterLastSignal();
         return;
      }
   }
}


// =========================
// Main Process
// =========================
void ProcessEA()
{
   if(EAStopped)
      return;

   if(SAFE_EXIT > 0 && AccountEquity() >= SAFE_EXIT)
   {
      CloseAllEAOrders();
      HYPERSystemCount = 0;
      LastExecutedSignalTime = 0;
      DeleteTargetLine();
      EAStopped = true;
      Alert("Target equity reached. All positions closed and EA stopped.");
      return;
   }

   if(TARGET_PROFIT > 0 && TotalProfit() >= TARGET_PROFIT && CountEAOrders() > 0)
   {
      LastHitBarcodeTime = LastExecutedSignalTime;
      LastHitBarcodeSignal = LastBarcodeSignal;

      if(LastHitBarcodeTime <= 0)
         LastHitBarcodeTime = LastBarcodeSignalTime;

      if(LastHitBarcodeSignal == 0)
         LastHitBarcodeSignal = LastBarcodeSignal;

      if(LastHitBarcodeTime > 0)
         GlobalVariableSet(GV_HIT_TIME, (double)LastHitBarcodeTime);

      if(LastHitBarcodeSignal != 0)
         GlobalVariableSet(GV_HIT_SIGNAL, (double)LastHitBarcodeSignal);

      CloseAllEAOrders();
      HYPERSystemCount = 0;
      LastExecutedSignalTime = 0;
      DeleteTargetLine();
      return;
   }

   if(ForceCloseAtEndHour && EndHour >= 0 && EndHour < 24)
   {
      int h = TimeHour(TimeCurrent());
      if(h >= EndHour && CountEAOrders() > 0)
      {
         CloseAllEAOrders();
         return;
      }
   }

   if(!IsTradingTime())
      return;

   if(!IsSpreadOK())
      return;

   if(TradeOnNewBarOnly && !IsNewBar())
      return;

   int sig = GetSignal();

   if(sig == 0)
      return;

   datetime sigTime = iTime(Symbol(), Period(), 1);
   if(sigTime == LastSignalBarTime)
      return;

   HYPERSystemCount++;
   LastSignalBarTime = sigTime;
   LastBarcodeSignal = sig;
   LastBarcodeSignalTime = sigTime;

   TryEnterLastSignal();
}


// =========================
// Signal
// =========================
int GetSignal()
{
   // Golden cross: MA1 crosses above MA2 on the last closed candle.
   // Death cross: MA1 crosses below MA2 on the last closed candle.
   double fastPrev = GetMA(MAperiod_1, 2);
   double slowPrev = GetMA(MAperiod_2, 2);
   double fastNow  = GetMA(MAperiod_1, 1);
   double slowNow  = GetMA(MAperiod_2, 1);

   if(fastPrev <= slowPrev && fastNow > slowNow)
      return 1;  // BUY

   if(fastPrev >= slowPrev && fastNow < slowNow)
      return -1; // SELL

   return 0;
}

double GetMA(int period, int shift)
{
   return iMA(Symbol(), Period(), period, 0, MAMethod, MAPrice, shift);
}

string SignalText(int sig)
{
   if(sig > 0)
      return "BARCODE BUY LINE";
   if(sig < 0)
      return "BARCODE SELL LINE";
   return "WAITING";
}

color SignalColor(int sig)
{
   if(sig > 0)
      return clrLime;
   if(sig < 0)
      return clrTomato;
   return clrSilver;
}


// =========================
// Filters
// =========================
bool IsNewBar()
{
   datetime nowBar = iTime(Symbol(), Period(), 0);

   if(nowBar != LastBarTime)
   {
      LastBarTime = nowBar;
      return true;
   }

   return false;
}

bool IsTradingTime()
{
   if(StartHour < 0 || EndHour < 0)
      return true;

   if(EndHour >= 24)
      return true;

   int h = TimeHour(TimeCurrent());

   if(StartHour <= EndHour)
   {
      if(h >= StartHour && h < EndHour)
         return true;
      return false;
   }

   // Overnight session, e.g. 22 to 5
   if(h >= StartHour || h < EndHour)
      return true;

   return false;
}

bool IsSpreadOK()
{
   int sp = (int)MarketInfo(Symbol(), MODE_SPREAD);

   if(sp > SpreadLimit)
      return false;

   return true;
}




bool GetLatestBarcodeSignal(int &sig, datetime &sigTime)
{
   sig = 0;
   sigTime = 0;

   int lookback = CrossLookbackBars;
   if(lookback > Bars - 3)
      lookback = Bars - 3;

   if(lookback < 3)
      return false;

   // Search from the most recent closed candle backwards.
   for(int shift = 1; shift <= lookback; shift++)
   {
      double fastPrev = GetMA(MAperiod_1, shift + 1);
      double slowPrev = GetMA(MAperiod_2, shift + 1);
      double fastNow  = GetMA(MAperiod_1, shift);
      double slowNow  = GetMA(MAperiod_2, shift);

      if(fastPrev <= slowPrev && fastNow > slowNow)
      {
         sig = 1;
         sigTime = iTime(Symbol(), Period(), shift);
         return true;
      }

      if(fastPrev >= slowPrev && fastNow < slowNow)
      {
         sig = -1;
         sigTime = iTime(Symbol(), Period(), shift);
         return true;
      }
   }

   return false;
}

void ShotEntry()
{
   if(EAStopped)
   {
      Alert("SHOT blocked: EA is stopped.");
      return;
   }

   int sig = 0;
   datetime sigTime = 0;

   if(!GetLatestBarcodeSignal(sig, sigTime))
   {
      Alert("SHOT failed: no recent barcode line found.");
      return;
   }

   LastBarcodeSignal = sig;
   LastBarcodeSignalTime = sigTime;

   // SHOT means immediate entry regardless of current START LINE.
   // It uses the latest barcode direction and the current TARGET_PROFIT.
   if(OpenOrderBySignal(sig))
   {
      LastExecutedSignalTime = sigTime;
      if(HYPERSystemCount < 1)
         HYPERSystemCount = 1;

      DrawTargetLine();
      Alert("SHOT entry executed from latest barcode line: ", sig > 0 ? "B" : "S");
   }
}


void TryEnterLastSignal()
{
   if(!SystemEnabled)
      return;

   if(EAStopped)
      return;

   if(LastBarcodeSignal == 0 || LastBarcodeSignalTime <= 0)
      return;

   if(LastExecutedSignalTime == LastBarcodeSignalTime)
      return;

   if(HYPERSystemCount < BarcodeStartLine)
      return;

   if(OpenOrderBySignal(LastBarcodeSignal))
      LastExecutedSignalTime = LastBarcodeSignalTime;
}


// =========================
// Trading
// =========================
bool OpenOrderBySignal(int sig)
{
   int type = sig > 0 ? OP_BUY : OP_SELL;

   double lots = NextLot();
   lots = NormalizeLots(lots);

   if(lots <= 0)
      return false;

   if(AccountFreeMarginCheck(Symbol(), type, lots) <= 0)
   {
      Alert("Not enough margin for next lot: ", DoubleToString(lots, 2));
      return false;
   }

   RefreshRates();

   double price = type == OP_BUY ? Ask : Bid;
   price = NormalizeDouble(price, Digits);

   string comment = sig > 0 ? "HYPERSystem_BUY" : "HYPERSystem_SELL";

   int ticket = OrderSend(Symbol(),
                          type,
                          lots,
                          price,
                          Slippage,
                          0,
                          0,
                          comment,
                          MagicNumber,
                          0,
                          clrYellow);

   if(ticket < 0)
   {
      int err = GetLastError();
      Alert("OrderSend failed. Error: ", err);
      ResetLastError();
      return false;
   }

   return true;
}

double NextLot()
{
   int count = CountEAOrders();

   double lot = Lots;

   for(int i = 0; i < count; i++)
      lot *= LotMulti;

   return NormalizeLots(lot);
}

double NormalizeLots(double lots)
{
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double step   = MarketInfo(Symbol(), MODE_LOTSTEP);

   if(lots < minLot)
      lots = minLot;

   if(lots > maxLot)
      lots = maxLot;

   lots = MathFloor(lots / step) * step;
   return NormalizeDouble(lots, 2);
}

void CloseAllEAOrders()
{
   for(int pass = 0; pass < 5; pass++)
   {
      bool anyClosed = false;

      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;

         if(OrderSymbol() != Symbol())
            continue;

         if(OrderMagicNumber() != MagicNumber)
            continue;

         if(OrderType() != OP_BUY && OrderType() != OP_SELL)
            continue;

         CloseOrderByTicket(OrderTicket());
         anyClosed = true;
      }

      if(!anyClosed)
         break;

      Sleep(250);
   }
}

bool CloseOrderByTicket(int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
      return false;

   RefreshRates();

   int type = OrderType();
   double price = 0;

   if(type == OP_BUY)
      price = Bid;
   else if(type == OP_SELL)
      price = Ask;
   else
      return false;

   bool ok = OrderClose(ticket,
                        OrderLots(),
                        NormalizeDouble(price, Digits),
                        Slippage,
                        clrWhite);

   if(!ok)
   {
      int err = GetLastError();
      Print("OrderClose failed. Error=", err, " ticket=", ticket);
      ResetLastError();
   }

   return ok;
}


// =========================
// Stats
// =========================
int CountEAOrders()
{
   int count = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() == OP_BUY || OrderType() == OP_SELL)
         count++;
   }

   return count;
}

int CountEAOrdersByType(int type)
{
   int count = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() == type)
         count++;
   }

   return count;
}

double TotalLots()
{
   double lots = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() == OP_BUY || OrderType() == OP_SELL)
         lots += OrderLots();
   }

   return lots;
}

double TotalProfit()
{
   double p = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() == OP_BUY || OrderType() == OP_SELL)
         p += OrderProfit() + OrderSwap() + OrderCommission();
   }

   return p;
}

double TotalProfitByType(int type)
{
   double p = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() == type)
         p += OrderProfit() + OrderSwap() + OrderCommission();
   }

   return p;
}

double TodayClosedProfit()
{
   datetime now = TimeCurrent();
   string d = TimeToString(now, TIME_DATE);
   datetime dayStart = StrToTime(d + " 00:00");

   double p = 0;

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      if(OrderCloseTime() < dayStart)
         break;

      p += OrderProfit() + OrderSwap() + OrderCommission();
   }

   return p;
}

double TodayTotalProfit()
{
   return TodayClosedProfit() + TotalProfit();
}

double LastOpenPrice()
{
   datetime latest = 0;
   double price = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      if(OrderOpenTime() > latest)
      {
         latest = OrderOpenTime();
         price = OrderOpenPrice();
      }
   }

   return price;
}

string LastOrderTypeText()
{
   datetime latest = 0;
   int type = -1;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      if(OrderOpenTime() > latest)
      {
         latest = OrderOpenTime();
         type = OrderType();
      }
   }

   if(type == OP_BUY)
      return "BUY";
   if(type == OP_SELL)
      return "SELL";

   return "NONE";
}



// =========================
// MA / Cross Visuals
// =========================
void DrawVisualObjects()
{
   // Moving average lines are intentionally hidden.
   if(DrawCrossMarks)
      DrawCrossSignals();
}

void DrawMovingAverageLines()
{
   int bars = Bars;
   int drawBars = DrawBarsCount;

   if(drawBars < 10)
      drawBars = 10;

   if(drawBars > bars - 2)
      drawBars = bars - 2;

   if(drawBars <= 2)
      return;

   for(int i = 0; i < drawBars - 1; i++)
   {
      int s1 = drawBars - i;
      int s2 = drawBars - i - 1;

      datetime t1 = iTime(Symbol(), Period(), s1);
      datetime t2 = iTime(Symbol(), Period(), s2);

      double fast1 = GetMA(MAperiod_1, s1);
      double fast2 = GetMA(MAperiod_1, s2);
      double slow1 = GetMA(MAperiod_2, s1);
      double slow2 = GetMA(MAperiod_2, s2);

      string fastName = FAST_MA_PREFIX + IntegerToString(i);
      string slowName = SLOW_MA_PREFIX + IntegerToString(i);

      if(ObjectFind(0, fastName) < 0)
         ObjectCreate(0, fastName, OBJ_TREND, 0, t1, fast1, t2, fast2);

      ObjectSetInteger(0, fastName, OBJPROP_TIME1, t1);
      ObjectSetDouble(0, fastName, OBJPROP_PRICE1, fast1);
      ObjectSetInteger(0, fastName, OBJPROP_TIME2, t2);
      ObjectSetDouble(0, fastName, OBJPROP_PRICE2, fast2);
      ObjectSetInteger(0, fastName, OBJPROP_COLOR, FastMAColor);
      ObjectSetInteger(0, fastName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, fastName, OBJPROP_RAY, false);
      ObjectSetInteger(0, fastName, OBJPROP_BACK, true);

      if(ObjectFind(0, slowName) < 0)
         ObjectCreate(0, slowName, OBJ_TREND, 0, t1, slow1, t2, slow2);

      ObjectSetInteger(0, slowName, OBJPROP_TIME1, t1);
      ObjectSetDouble(0, slowName, OBJPROP_PRICE1, slow1);
      ObjectSetInteger(0, slowName, OBJPROP_TIME2, t2);
      ObjectSetDouble(0, slowName, OBJPROP_PRICE2, slow2);
      ObjectSetInteger(0, slowName, OBJPROP_COLOR, SlowMAColor);
      ObjectSetInteger(0, slowName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, slowName, OBJPROP_RAY, false);
      ObjectSetInteger(0, slowName, OBJPROP_BACK, true);
   }

   for(int j = drawBars - 1; j < DrawBarsCount + 100; j++)
   {
      ObjectDelete(0, FAST_MA_PREFIX + IntegerToString(j));
      ObjectDelete(0, SLOW_MA_PREFIX + IntegerToString(j));
   }
}

void DrawCrossSignals()
{
   int bars = Bars;
   int lookback = CrossLookbackBars;

   if(lookback > bars - 3)
      lookback = bars - 3;

   if(lookback < 5)
      return;

   for(int d = 0; d < CrossLookbackBars + 50; d++)
   {
      ObjectDelete(0, CROSS_PREFIX + IntegerToString(d));
      ObjectDelete(0, CROSS_TX_PREFIX + IntegerToString(d));
   }

   int markIndex = 0;

   for(int shift = lookback; shift >= 1; shift--)
   {
      double fastPrev = GetMA(MAperiod_1, shift + 1);
      double slowPrev = GetMA(MAperiod_2, shift + 1);
      double fastNow  = GetMA(MAperiod_1, shift);
      double slowNow  = GetMA(MAperiod_2, shift);

      int sig = 0;

      if(fastPrev <= slowPrev && fastNow > slowNow)
         sig = 1;
      else if(fastPrev >= slowPrev && fastNow < slowNow)
         sig = -1;

      if(sig == 0)
         continue;

      datetime t = iTime(Symbol(), Period(), shift);
      bool isHit = false;
      if(LastHitBarcodeTime > 0)
      {
         int ps = PeriodSeconds(Period());
         if(t == LastHitBarcodeTime || MathAbs((int)(t - LastHitBarcodeTime)) <= ps / 2)
            isHit = true;
      }

      // Historical virtual HIT calculation:
      // Even if the EA was not running at that time, mark the barcode line
      // that would have produced TARGET_PROFIT under current settings.
      if(!isHit)
         isHit = IsHistoricalHitShift(shift);

      double h = iHigh(Symbol(), Period(), shift);
      double l = iLow(Symbol(), Period(), shift);
      double offset = MathMax((h - l) * 1.8, Point * 50);

      color lineColor = isHit ? clrRed : clrYellow;
      string barcodeText = isHit ? (sig > 0 ? "B HIT" : "S HIT") : (sig > 0 ? "B" : "S");

      string vName = CROSS_PREFIX + IntegerToString(markIndex);
      string txName = CROSS_TX_PREFIX + IntegerToString(markIndex);

      if(ObjectFind(0, vName) < 0)
         ObjectCreate(0, vName, OBJ_VLINE, 0, t, 0);

      ObjectSetInteger(0, vName, OBJPROP_TIME1, t);
      ObjectSetInteger(0, vName, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, vName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, vName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, vName, OBJPROP_BACK, true);

      double textPrice = sig > 0 ? l - offset : h + offset;
      string text = barcodeText;

      if(ObjectFind(0, txName) < 0)
         ObjectCreate(0, txName, OBJ_TEXT, 0, t, textPrice);

      ObjectSetInteger(0, txName, OBJPROP_TIME1, t);
      ObjectSetDouble(0, txName, OBJPROP_PRICE1, textPrice);
      ObjectSetString(0, txName, OBJPROP_TEXT, text);
      ObjectSetString(0, txName, OBJPROP_FONT, "Arial Black");
      ObjectSetInteger(0, txName, OBJPROP_FONTSIZE, isHit ? 16 : 14);
      ObjectSetInteger(0, txName, OBJPROP_COLOR, lineColor);

      markIndex++;
   }
}


bool IsHistoricalHitShift(int targetShift)
{
   if(TARGET_PROFIT <= 0)
      return false;

   int bars = Bars;
   int lookback = CrossLookbackBars;

   if(lookback > bars - 5)
      lookback = bars - 5;

   if(lookback < 5)
      return false;

   int sigShift[512];
   int sigDir[512];
   int sigCount = 0;

   // Collect barcode signals from old to new.
   for(int shift = lookback; shift >= 1; shift--)
   {
      double fastPrev = GetMA(MAperiod_1, shift + 1);
      double slowPrev = GetMA(MAperiod_2, shift + 1);
      double fastNow  = GetMA(MAperiod_1, shift);
      double slowNow  = GetMA(MAperiod_2, shift);

      int sig = 0;

      if(fastPrev <= slowPrev && fastNow > slowNow)
         sig = 1;
      else if(fastPrev >= slowPrev && fastNow < slowNow)
         sig = -1;

      if(sig == 0)
         continue;

      if(sigCount >= 512)
         break;

      sigShift[sigCount] = shift;
      sigDir[sigCount] = sig;
      sigCount++;
   }

   if(sigCount <= 0)
      return false;

   int    posType[512];
   double posLot[512];
   double posPrice[512];
   int    posSignalShift[512];
   int    posCount = 0;

   int lineCount = 0;

   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);

   if(tickValue <= 0 || tickSize <= 0)
      return false;

   for(int i = 0; i < sigCount; i++)
   {
      int shiftNow = sigShift[i];
      int sigNow = sigDir[i];

      lineCount++;

      if(lineCount >= BarcodeStartLine)
      {
         if(posCount < 512)
         {
            posType[posCount] = sigNow > 0 ? OP_BUY : OP_SELL;

            double lot = Lots;
            for(int m = 0; m < posCount; m++)
               lot *= LotMulti;

            posLot[posCount] = NormalizeLots(lot);

            // Historical approximation:
            // signal confirmed on the closed barcode candle.
            posPrice[posCount] = iClose(Symbol(), Period(), shiftNow);

            posSignalShift[posCount] = shiftNow;
            posCount++;
         }
      }

      if(posCount <= 0)
         continue;

      int nextSignalShift = 0;

      if(i + 1 < sigCount)
         nextSignalShift = sigShift[i + 1];

      // Check every candle after this barcode line until before the next barcode line.
      int endShift = nextSignalShift > 0 ? nextSignalShift + 1 : 0;

      bool hit = false;

      for(int s = shiftNow - 1; s >= endShift; s--)
      {
         double hi = iHigh(Symbol(), Period(), s);
         double lo = iLow(Symbol(), Period(), s);

         double profitAtHigh = 0;
         double profitAtLow = 0;

         for(int p = 0; p < posCount; p++)
         {
            if(posType[p] == OP_BUY)
            {
               profitAtHigh += (hi - posPrice[p]) / tickSize * tickValue * posLot[p];
               profitAtLow  += (lo - posPrice[p]) / tickSize * tickValue * posLot[p];
            }
            else
            {
               profitAtHigh += (posPrice[p] - hi) / tickSize * tickValue * posLot[p];
               profitAtLow  += (posPrice[p] - lo) / tickSize * tickValue * posLot[p];
            }
         }

         if(profitAtHigh >= TARGET_PROFIT || profitAtLow >= TARGET_PROFIT)
         {
            hit = true;
            break;
         }
      }

      if(hit)
      {
         int lastEntryShift = posSignalShift[posCount - 1];

         if(lastEntryShift == targetShift)
            return true;

         // After target profit, virtual basket closes and line count resets.
         posCount = 0;
         lineCount = 0;
      }
   }

   return false;
}



void CalculateHitLineStats(int &hit1, int &hit2, int &hit3, int &hit4, int &hit5, int &hitMore, int &totalHits)
{
   hit1 = 0;
   hit2 = 0;
   hit3 = 0;
   hit4 = 0;
   hit5 = 0;
   hitMore = 0;
   totalHits = 0;

   if(TARGET_PROFIT <= 0)
      return;

   int bars = Bars;
   int lookback = CrossLookbackBars;

   if(lookback > bars - 5)
      lookback = bars - 5;

   if(lookback < 5)
      return;

   int sigShift[512];
   int sigDir[512];
   int sigCount = 0;

   // Collect barcode signals from old to new.
   for(int shift = lookback; shift >= 1; shift--)
   {
      double fastPrev = GetMA(MAperiod_1, shift + 1);
      double slowPrev = GetMA(MAperiod_2, shift + 1);
      double fastNow  = GetMA(MAperiod_1, shift);
      double slowNow  = GetMA(MAperiod_2, shift);

      int sig = 0;

      if(fastPrev <= slowPrev && fastNow > slowNow)
         sig = 1;
      else if(fastPrev >= slowPrev && fastNow < slowNow)
         sig = -1;

      if(sig == 0)
         continue;

      if(sigCount >= 512)
         break;

      sigShift[sigCount] = shift;
      sigDir[sigCount] = sig;
      sigCount++;
   }

   if(sigCount <= 0)
      return;

   int    posType[512];
   double posLot[512];
   double posPrice[512];
   int    posCount = 0;

   int lineCount = 0;

   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);

   if(tickValue <= 0 || tickSize <= 0)
      return;

   for(int i = 0; i < sigCount; i++)
   {
      int shiftNow = sigShift[i];
      int sigNow = sigDir[i];

      lineCount++;

      // For the statistics table, always simulate from line 1.
      // This shows after how many barcode switches a HIT generally appears.
      if(posCount < 512)
      {
         posType[posCount] = sigNow > 0 ? OP_BUY : OP_SELL;

         double lot = Lots;
         for(int m = 0; m < posCount; m++)
            lot *= LotMulti;

         posLot[posCount] = NormalizeLots(lot);
         posPrice[posCount] = iClose(Symbol(), Period(), shiftNow);
         posCount++;
      }

      int nextSignalShift = 0;

      if(i + 1 < sigCount)
         nextSignalShift = sigShift[i + 1];

      int endShift = nextSignalShift > 0 ? nextSignalShift + 1 : 0;

      bool hit = false;

      for(int s = shiftNow - 1; s >= endShift; s--)
      {
         double hi = iHigh(Symbol(), Period(), s);
         double lo = iLow(Symbol(), Period(), s);

         double profitAtHigh = 0;
         double profitAtLow = 0;

         for(int p = 0; p < posCount; p++)
         {
            if(posType[p] == OP_BUY)
            {
               profitAtHigh += (hi - posPrice[p]) / tickSize * tickValue * posLot[p];
               profitAtLow  += (lo - posPrice[p]) / tickSize * tickValue * posLot[p];
            }
            else
            {
               profitAtHigh += (posPrice[p] - hi) / tickSize * tickValue * posLot[p];
               profitAtLow  += (posPrice[p] - lo) / tickSize * tickValue * posLot[p];
            }
         }

         if(profitAtHigh >= TARGET_PROFIT || profitAtLow >= TARGET_PROFIT)
         {
            hit = true;
            break;
         }
      }

      if(hit)
      {
         if(lineCount == 1) hit1++;
         else if(lineCount == 2) hit2++;
         else if(lineCount == 3) hit3++;
         else if(lineCount == 4) hit4++;
         else if(lineCount == 5) hit5++;
         else hitMore++;

         totalHits++;

         // Reset virtual cycle after HIT.
         posCount = 0;
         lineCount = 0;
      }
   }
}



void CalculateHitLineDirectionStats(int &b1, int &s1, int &b2, int &s2, int &b3, int &s3, int &b4, int &s4, int &b5, int &s5, int &bm, int &sm, int &totalHits)
{
   b1 = 0; s1 = 0;
   b2 = 0; s2 = 0;
   b3 = 0; s3 = 0;
   b4 = 0; s4 = 0;
   b5 = 0; s5 = 0;
   bm = 0; sm = 0;
   totalHits = 0;

   if(TARGET_PROFIT <= 0)
      return;

   int bars = Bars;
   int lookback = CrossLookbackBars;

   if(lookback > bars - 5)
      lookback = bars - 5;

   if(lookback < 5)
      return;

   int sigShift[512];
   int sigDir[512];
   int sigCount = 0;

   for(int shift = lookback; shift >= 1; shift--)
   {
      double fastPrev = GetMA(MAperiod_1, shift + 1);
      double slowPrev = GetMA(MAperiod_2, shift + 1);
      double fastNow  = GetMA(MAperiod_1, shift);
      double slowNow  = GetMA(MAperiod_2, shift);

      int sig = 0;

      if(fastPrev <= slowPrev && fastNow > slowNow)
         sig = 1;
      else if(fastPrev >= slowPrev && fastNow < slowNow)
         sig = -1;

      if(sig == 0)
         continue;

      if(sigCount >= 512)
         break;

      sigShift[sigCount] = shift;
      sigDir[sigCount] = sig;
      sigCount++;
   }

   if(sigCount <= 0)
      return;

   int    posType[512];
   double posLot[512];
   double posPrice[512];
   int    posSignalDir[512];
   int    posCount = 0;

   int lineCount = 0;

   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);

   if(tickValue <= 0 || tickSize <= 0)
      return;

   for(int i = 0; i < sigCount; i++)
   {
      int shiftNow = sigShift[i];
      int sigNow = sigDir[i];

      lineCount++;

      if(posCount < 512)
      {
         posType[posCount] = sigNow > 0 ? OP_BUY : OP_SELL;

         double lot = Lots;
         for(int m = 0; m < posCount; m++)
            lot *= LotMulti;

         posLot[posCount] = NormalizeLots(lot);
         posPrice[posCount] = iClose(Symbol(), Period(), shiftNow);
         posSignalDir[posCount] = sigNow;
         posCount++;
      }

      int nextSignalShift = 0;

      if(i + 1 < sigCount)
         nextSignalShift = sigShift[i + 1];

      int endShift = nextSignalShift > 0 ? nextSignalShift + 1 : 0;

      bool hit = false;

      for(int s = shiftNow - 1; s >= endShift; s--)
      {
         double hi = iHigh(Symbol(), Period(), s);
         double lo = iLow(Symbol(), Period(), s);

         double profitAtHigh = 0;
         double profitAtLow = 0;

         for(int p = 0; p < posCount; p++)
         {
            if(posType[p] == OP_BUY)
            {
               profitAtHigh += (hi - posPrice[p]) / tickSize * tickValue * posLot[p];
               profitAtLow  += (lo - posPrice[p]) / tickSize * tickValue * posLot[p];
            }
            else
            {
               profitAtHigh += (posPrice[p] - hi) / tickSize * tickValue * posLot[p];
               profitAtLow  += (posPrice[p] - lo) / tickSize * tickValue * posLot[p];
            }
         }

         if(profitAtHigh >= TARGET_PROFIT || profitAtLow >= TARGET_PROFIT)
         {
            hit = true;
            break;
         }
      }

      if(hit)
      {
         int lastDir = posSignalDir[posCount - 1]; // 1=B, -1=S

         if(lineCount == 1)
         {
            if(lastDir > 0) b1++; else s1++;
         }
         else if(lineCount == 2)
         {
            if(lastDir > 0) b2++; else s2++;
         }
         else if(lineCount == 3)
         {
            if(lastDir > 0) b3++; else s3++;
         }
         else if(lineCount == 4)
         {
            if(lastDir > 0) b4++; else s4++;
         }
         else if(lineCount == 5)
         {
            if(lastDir > 0) b5++; else s5++;
         }
         else
         {
            if(lastDir > 0) bm++; else sm++;
         }

         totalHits++;

         posCount = 0;
         lineCount = 0;
      }
   }
}


void ClearVisualObjects()
{
   for(int i = 0; i < DrawBarsCount + 200; i++)
   {
      ObjectDelete(0, FAST_MA_PREFIX + IntegerToString(i));
      ObjectDelete(0, SLOW_MA_PREFIX + IntegerToString(i));
   }

   for(int j = 0; j < CrossLookbackBars + 200; j++)
   {
      ObjectDelete(0, CROSS_PREFIX + IntegerToString(j));
      ObjectDelete(0, CROSS_TX_PREFIX + IntegerToString(j));
   }
}




// =========================
// Barcode Mode
// =========================
void ApplyBarcodeMode()
{
   if(CurrentBarcodeMode == MODE_HYPER)
   {
      MAperiod_1 = 5;
      MAperiod_2 = 20;
   }
   else if(CurrentBarcodeMode == MODE_NORMAL)
   {
      MAperiod_1 = 20;
      MAperiod_2 = 100;
   }
   else
   {
      MAperiod_1 = 60;
      MAperiod_2 = 120;
   }
}

string BarcodeModeText()
{
   if(CurrentBarcodeMode == MODE_HYPER)
      return "HYPER";

   if(CurrentBarcodeMode == MODE_NORMAL)
      return "NORMAL";

   return "STRADA";
}


// =========================
// Target Line
// =========================
void DrawTargetLine()
{
   if(CountEAOrders() <= 0)
   {
      DeleteTargetLine();
      return;
   }

   double currentProfit = TotalProfit();
   double needed = TARGET_PROFIT - currentProfit;

   if(TARGET_PROFIT <= 0)
   {
      DeleteTargetLine();
      return;
   }

   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);

   if(tickValue <= 0 || tickSize <= 0)
   {
      DeleteTargetLine();
      return;
   }

   double sensitivity = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() == OP_BUY)
         sensitivity += OrderLots() * tickValue / tickSize;

      if(OrderType() == OP_SELL)
         sensitivity -= OrderLots() * tickValue / tickSize;
   }

   if(MathAbs(sensitivity) <= 0.0000001)
   {
      DeleteTargetLine();
      return;
   }

   RefreshRates();

   double refPrice = Bid;
   double priceMove = needed / sensitivity;
   double targetPrice = NormalizeDouble(refPrice + priceMove, Digits);

   if(ObjectFind(0, TARGET_LINE) < 0)
      ObjectCreate(0, TARGET_LINE, OBJ_HLINE, 0, 0, targetPrice);

   ObjectSetDouble(0, TARGET_LINE, OBJPROP_PRICE1, targetPrice);
   ObjectSetInteger(0, TARGET_LINE, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, TARGET_LINE, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, TARGET_LINE, OBJPROP_WIDTH, 2);
   ObjectSetString(0, TARGET_LINE, OBJPROP_TEXT, "TARGET PROFIT LINE");

   if(ObjectFind(0, TARGET_TEXT) < 0)
      ObjectCreate(0, TARGET_TEXT, OBJ_TEXT, 0, Time[0], targetPrice);

   ObjectSetInteger(0, TARGET_TEXT, OBJPROP_TIME1, Time[0]);
   ObjectSetDouble(0, TARGET_TEXT, OBJPROP_PRICE1, targetPrice);
   ObjectSetString(0, TARGET_TEXT, OBJPROP_TEXT, "TARGET $" + DoubleToString(TARGET_PROFIT, 2));
   ObjectSetString(0, TARGET_TEXT, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, TARGET_TEXT, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, TARGET_TEXT, OBJPROP_COLOR, clrRed);
}

void DeleteTargetLine()
{
   ObjectDelete(0, TARGET_LINE);
   ObjectDelete(0, TARGET_TEXT);
}


// =========================
// Chart / UI
// =========================
void SetupChart()
{
   ChartSetInteger(0, CHART_MODE, CHART_CANDLES);

   ChartSetInteger(0, CHART_COLOR_BACKGROUND, clrBlack);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, clrWhite);
   ChartSetInteger(0, CHART_COLOR_GRID, clrDimGray);

   ChartSetInteger(0, CHART_COLOR_CHART_UP, clrRed);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, clrDodgerBlue);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrRed);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrDodgerBlue);

   ChartSetInteger(0, CHART_COLOR_BID, clrWhite);
   ChartSetInteger(0, CHART_COLOR_ASK, clrSilver);
   ChartSetInteger(0, CHART_COLOR_STOP_LEVEL, clrDarkGray);
   ChartSetInteger(0, CHART_SHOW_GRID, true);
}

void DrawPanel()
{
   int panelX = 14;
   int panelY = 18;
   int panelW = 470;
   int rowH = 28;
   int rows = 15;

   if(ObjectFind(0, PANEL_BG) < 0)
      ObjectCreate(0, PANEL_BG, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, PANEL_BG, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_XDISTANCE, panelX);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_YDISTANCE, panelY);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_XSIZE, panelW);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_YSIZE, rowH * rows + 10);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_BORDER_COLOR, clrWhite);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_BACK, false);

   if(ObjectFind(0, PANEL_TOP) < 0)
      ObjectCreate(0, PANEL_TOP, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, PANEL_TOP, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_XDISTANCE, panelX);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_YDISTANCE, panelY);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_XSIZE, panelW);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_YSIZE, rowH);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_BGCOLOR, clrDimGray);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_BORDER_COLOR, clrWhite);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_BACK, false);

   for(int r = 1; r < rows; r++)
      SetPanelRow(r, r % 2 == 0 ? clrBlack : clrMidnightBlue, clrDimGray);

   string sys = SystemEnabled ? "ON" : "OFF";

   int line = 0;
   SetPanelLine(line++, "하이퍼 바코드 시스템", clrWhite, 13);
   SetPanelLine(line++, "SYSTEM      : " + sys + " / " + BarcodeModeText(), SystemEnabled ? clrWhite : clrGray, 11);
   SetPanelLine(line++, "BALANCE     : " + Money(SessionStartBalance) + "  ->  " + Money(AccountBalance()), clrWhite, 11);
   SetPanelLine(line++, "TODAY P/L   : " + Money(TodayTotalProfit()), TodayTotalProfit() >= 0 ? clrWhite : clrDodgerBlue, 11);
   SetPanelLine(line++, "LINES       : " + IntegerToString(HYPERSystemCount), clrWhite, 11);
   SetPanelLine(line++, "START LINE  : " + IntegerToString(BarcodeStartLine), clrWhite, 11);
   string hitText = LastHitBarcodeTime > 0 ? TimeToString(LastHitBarcodeTime, TIME_DATE|TIME_MINUTES) : "NONE";
   SetPanelLine(line++, "LAST HIT    : " + hitText, LastHitBarcodeTime > 0 ? clrRed : clrGray, 10);

   int h1 = 0, h2 = 0, h3 = 0, h4 = 0, h5 = 0, hm = 0, ht = 0;
   CalculateHitLineStats(h1, h2, h3, h4, h5, hm, ht);

   SetPanelLine(line++, "HIT TABLE   : TOTAL " + IntegerToString(ht), clrWhite, 10);
   SetPanelLine(line++, "LINE 1 HIT  : " + IntegerToString(h1), clrSilver, 10);
   SetPanelLine(line++, "LINE 2 HIT  : " + IntegerToString(h2), clrSilver, 10);
   SetPanelLine(line++, "LINE 3 HIT  : " + IntegerToString(h3), clrSilver, 10);
   SetPanelLine(line++, "LINE 4 HIT  : " + IntegerToString(h4), clrSilver, 10);
   SetPanelLine(line++, "LINE 5 HIT  : " + IntegerToString(h5), clrSilver, 10);
   SetPanelLine(line++, "LINE 6+ HIT : " + IntegerToString(hm), clrSilver, 10);

   for(int i = line; i < 30; i++)
      SetPanelLine(i, "", clrWhite);
}

void SetPanelLine(int idx, string text, color c, int fontSize=10)
{
   string name = PANEL_PREFIX + IntegerToString(idx);

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 28);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 24 + idx * 28);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}


void SetPanelRow(int idx, color bg, color border)
{
   string name = PANEL_ROW_PREFIX + IntegerToString(idx);

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 14);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 18 + idx * 28);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, 470);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 28);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, border);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

void SetButton(string name, string text, int x, int y, int w, int h, color bg)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
}

void DrawControlButtons()
{
   SetButton(BTN_ON, "ON", 500, 20, 80, 34, SystemEnabled ? clrGreen : clrDimGray);
   SetButton(BTN_OFF, "OFF", 590, 20, 80, 34, !SystemEnabled ? clrRed : clrDimGray);

   SetButton(BTN_HYPER, "HYPER", 700, 20, 95, 34, CurrentBarcodeMode == MODE_HYPER ? clrWhite : clrDimGray);
   ObjectSetInteger(0, BTN_HYPER, OBJPROP_COLOR, CurrentBarcodeMode == MODE_HYPER ? clrBlack : clrWhite);

   SetButton(BTN_NORMAL, "NORMAL", 805, 20, 95, 34, CurrentBarcodeMode == MODE_NORMAL ? clrWhite : clrDimGray);
   ObjectSetInteger(0, BTN_NORMAL, OBJPROP_COLOR, CurrentBarcodeMode == MODE_NORMAL ? clrBlack : clrWhite);

   SetButton(BTN_STRADA, "STRADA", 910, 20, 95, 34, CurrentBarcodeMode == MODE_STRADA ? clrWhite : clrDimGray);
   ObjectSetInteger(0, BTN_STRADA, OBJPROP_COLOR, CurrentBarcodeMode == MODE_STRADA ? clrBlack : clrWhite);

   SetButton(BTN_SHOT, "SHOT", 1020, 20, 95, 34, clrRed);
   ObjectSetInteger(0, BTN_SHOT, OBJPROP_COLOR, clrWhite);

   int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   int y = chartHeight > 0 ? chartHeight - 44 : 650;

   for(int i = 1; i <= 5; i++)
   {
      color bg = (BarcodeStartLine == i) ? clrWhite : clrDimGray;
      string name = BTN_START_PREFIX + IntegerToString(i);
      SetButton(name, IntegerToString(i), 20 + (i - 1) * 78, y, 68, 32, bg);
      ObjectSetInteger(0, name, OBJPROP_COLOR, BarcodeStartLine == i ? clrBlack : clrWhite);
   }
}


void DeletePanel()
{
   ObjectDelete(0, PANEL_BG);
   ObjectDelete(0, PANEL_TOP);
   ObjectDelete(0, BTN_ON);
   ObjectDelete(0, BTN_OFF);
   ObjectDelete(0, BTN_HYPER);
   ObjectDelete(0, BTN_NORMAL);
   ObjectDelete(0, BTN_STRADA);
   ObjectDelete(0, BTN_SHOT);
   DeleteTargetLine();

   for(int b = 1; b <= 5; b++)
      ObjectDelete(0, BTN_START_PREFIX + IntegerToString(b));

   for(int r = 0; r < 20; r++)
      ObjectDelete(0, PANEL_ROW_PREFIX + IntegerToString(r));

   for(int i = 0; i < 40; i++)
      ObjectDelete(0, PANEL_PREFIX + IntegerToString(i));
}


// =========================
// Format Helpers
// =========================
string Money(double v)
{
   return "$" + DoubleToString(v, 2);
}

string Dbl(double v, int d)
{
   return DoubleToString(v, d);
}
