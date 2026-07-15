#property strict

// =====================================================
// License System
// =====================================================
string  g_ProgramName   = "RACEHORSE_EA";
bool    g_licenseOK     = false;
int     g_licCheckCount = 0;
datetime g_lastLicCheck = 0;

bool AxionCheckLicense()
{
   if(g_licenseOK && (TimeCurrent() - g_lastLicCheck) < 3600)
      return(true);

   string key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indtdm5lYXJvdXJzYm13anF3end3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgxNzQ5MjEsImV4cCI6MjA5Mzc1MDkyMX0.MS4iSGIvW4dBi3sd8J3baHLT4TlgUJS5lXwlhJdWYEY";

   string acct = IntegerToString(AccountNumber());

   string url = "https://wmvnearoursbmwjqwzww.supabase.co/rest/v1/customers"
              + "?account_no=eq." + acct
              + "&program_name=eq." + g_ProgramName
              + "&is_active=eq.true"
              + "&select=expires_at";

   string headers = "apikey: " + key + "\r\n"
                  + "Authorization: Bearer " + key + "\r\n"
                  + "Content-Type: application/json\r\n";

   char post[]; char result[]; string rh;
   ResetLastError();
   int http = WebRequest("GET", url, headers, 10000, post, result, rh);

   if(http < 0)
   {
      int err = GetLastError();
      Print("[License] Program: ", g_ProgramName, " | Account: ", acct,
            " | ERROR err=", IntegerToString(err),
            (err==4060 ? " (URL 미등록: 도구>옵션>EA에 추가)" : ""));
      g_licenseOK = false;
      return(false);
   }

   string body = CharArrayToString(result);
   Print("[License] Program: ", g_ProgramName, " | Account: ", acct,
         " | HTTP: ", IntegerToString(http), " | Body: ", body);

   if(http != 200 || body == "[]" || StringFind(body, "expires_at") < 0)
   {
      g_licenseOK = false;
      return(false);
   }

   int s = StringFind(body, "\"expires_at\":\"") + 14;
   string exp = StringSubstr(body, s, 10);
   StringReplace(exp, "-", ".");

   if(exp < TimeToString(TimeCurrent(), TIME_DATE))
   {
      Print("[License] EXPIRED: ", exp);
      g_licenseOK = false;
      return(false);
   }

   g_licenseOK    = true;
   g_lastLicCheck = TimeCurrent();
   Print("[License] OK until ", exp);
   return(true);
}
// =====================================================


// ==========================================================
// 경주마 EA v4 DAILY GAP STOP
// ----------------------------------------------------------
// Convergence candle breakout EA
// 1) Find compressed / inside convergence candle
// 2) Draw upper/lower breakout rail
// 3) Enter in breakout direction
// 4) If price breaks opposite side, close current side and reverse with martingale lot
// ----------------------------------------------------------
// Rebuilt from 230928_YYJ_Trading_v3 logic.
// ==========================================================


// =========================
// User Settings
// =========================
input string SETTING_1 = "========== 경주마 BASIC ==========";
input int    MagicNumber              = 92801;
input double Lots                     = 0.10;
input int    Slippage                 = 10;

input string SETTING_2 = "========== CONVERGENCE CANDLE ==========";
input int    HighLowSize              = 100;     // max mother candle range in points
input bool   UseNewBarOnly            = true;
input bool   UseOpenBreakout          = true;    // true: current bar open breakout / false: close breakout

input string SETTING_3 = "========== MARTINGALE REVERSAL ==========";
input bool   UseMartingale            = true;
input double MartingaleMultiplier     = 2.0;
input int    MaxEntryCount            = 10;

input string SETTING_4 = "========== PROFIT / RISK ==========";
input double TargetProfitUSD          = 0.0;     // 0 = off
input double SafeExitEquity           = 0.0;     // 0 = off
input int    MaxSpreadPoints          = 80;

input string SETTING_5 = "========== TIME FILTER ==========";
input bool   UseHourFilter            = false;
input int    StartHour                = 0;       // MT4 server time
input int    EndHour                  = 23;      // MT4 server time

input string SETTING_6 = "========== DAILY GAP STOP ==========";
input bool   DailyGapStop             = false;   // true = auto close daily at 23:00 server time

input string SETTING_7 = "========== VISUAL / SAFETY ==========";
input bool   SetChartStyle            = true;
input bool   ShowKoreanRiskPopup      = true;


// =========================
// Runtime
// =========================
datetime LastBarTime = 0;
bool RiskPopupAccepted = false;
bool HadPositionBefore = false;

bool EntrySignal = true;
double TopPrice = 0;
double BottomPrice = 0;
double FinalLot = 0;
int EntryCount = 0;
datetime SetupTime = 0;

bool DailyGapPaused = false;
bool DailyGapClosePending = false;
int  DailyGapStopDateKey = 0;

int DAILY_GAP_CLOSE_HOUR = 23;
int DAILY_GAP_CLOSE_RETRIES = 5;

string GV_DAILY_GAP_PAUSED = "";
string GV_DAILY_GAP_DATE = "";

string EA_NAME = "경주마 DAILY GAP STOP";
string ORDER_COMMENT = "RACEHORSE_DAILY_GAP_EA";

string PANEL_BG  = "RH_PANEL_BG";
string PANEL_TOP = "RH_PANEL_TOP";
string PANEL_TX  = "RH_PANEL_TX_";
string TOP_LINE  = "RH_TOP_RAIL";
string BOT_LINE  = "RH_BOTTOM_RAIL";


// =========================
// Forward
// =========================
bool   ShowRiskNoticePopup();
bool   ManageDailyGapStop();
bool   IsDailyGapCloseTime(datetime t);
bool   IsMarketReadyAfterDailyGap();
int    ServerDateKey(datetime t);
string DailyGapStatusText();
void   LoadDailyGapState();
void   SaveDailyGapState();
void   ResetAfterDailyGap();
bool   CloseAllDailyGap();

int CountRacehorsePositions()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != MagicNumber) continue;
      count++;
   }
   return(count);
}
void   CheckExternalCloseReset();
void   ProcessLogic();
void   FindConvergenceCandle();
bool   TradeTimeOK();
bool   IsSpreadOK();

bool   HasPosition();
int    CurrentPositionType();
double CurrentProfit();
double TodayPNL();

bool   OpenTrade(int type, double lots);
void   CloseAll();
void   CloseType(int type);
double TradeLots();
double NormalizeLots(double lots);
int    LotDigitsByStep(double step);

double BreakoutValue();
bool   BreakTop();
bool   BreakBottom();

void   ResetSetup();
void   SetupChart();
void   DrawRails();
void   DrawUI();
void   SetPanelLine(int idx, string text, color c, int fontSize=10);
void   DeleteObjects();


// =========================
// Init / Deinit / Tick
// =========================
bool ShowRiskNoticePopup()
{
   if(!ShowKoreanRiskPopup)
      return true;

   string msg = "";
   msg += "EA 시작 전 필수 투자위험 및 책임 고지\n\n";
   msg += "본 EA는 수렴캔들 이후 돌파 방향을 추종하는 자동매매 보조 소프트웨어이며, 수익을 보장하지 않습니다.\n\n";
   msg += "시장은 돌파 이후에도 급격한 되돌림, 반대 돌파, 스프레드 확대, 슬리피지, 체결 지연, 서버 장애, 증거금 부족, 강제청산 등이 발생할 수 있습니다.\n\n";
   msg += "본 EA는 반대 돌파 시 기존 포지션을 정리하고 마틴게일 방식으로 방향을 전환할 수 있으므로, 계좌 규모와 위험 감내 수준에 맞게 신중하게 설정해야 합니다.\n\n";
   msg += "DailyGapStop=true 사용 시 매일 브로커 서버시간 23:00부터 현재 경주마 포지션을 전부 청산하고 신규 탐색과 진입을 중단합니다. 다음 서버 날짜의 첫 정상 시장 틱부터 새 수렴 탐색으로 자동 재개합니다.\n\n";
   msg += "본 시스템은 투자자문, 투자일임, 매수·매도 추천, 대리매매 또는 계좌 운용을 목적으로 하지 않습니다.\n\n";
   msg += "EA의 설치, 설정, 실행, 중지, 포지션 청산 및 운용 여부에 대한 최종 판단과 책임은 전적으로 이용자 본인에게 있습니다.\n\n";
   msg += "위 위험을 이해했으며, 본인 판단과 책임으로 EA를 실행합니다.\n\n";
   msg += "[확인]을 누르면 EA가 시작됩니다. [취소]를 누르면 EA가 중지됩니다.";

   int res = MessageBox(msg, "경주마 EA 필수 투자위험 및 책임 고지", MB_OKCANCEL | MB_ICONWARNING);

   if(res == IDOK)
      return true;

   return false;
}

int OnInit()
{
   RiskPopupAccepted = ShowRiskNoticePopup();

   if(!RiskPopupAccepted)
      return(INIT_FAILED);

   if(SetChartStyle)
      SetupChart();

   LastBarTime = iTime(Symbol(), Period(), 0);
   FinalLot = Lots;

   GV_DAILY_GAP_PAUSED = "RACEHORSE_DAILY_GAP_PAUSED_" +
                         IntegerToString(AccountNumber()) + "_" +
                         Symbol() + "_" +
                         IntegerToString(MagicNumber);
   GV_DAILY_GAP_DATE = "RACEHORSE_DAILY_GAP_DATE_" +
                       IntegerToString(AccountNumber()) + "_" +
                       Symbol() + "_" +
                       IntegerToString(MagicNumber);

   LoadDailyGapState();

   DrawRails();
   DrawUI();

   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   SaveDailyGapState();
   DeleteObjects();
}

void OnTimer()
{

// --- License Check ---
   AxionCheckLicense();
   if(!g_licenseOK)
      Comment("[ License Error ] Account: " + IntegerToString(AccountNumber()));
   else
      Comment("");
// --- End License Check ---
}


//+------------------------------------------------------------------+
//| 잔고 $50 이하 → 전체 청산 후 EA 즉시 종료                          |
//+------------------------------------------------------------------+
bool g_balanceHalt = false;
void CheckBalanceStop()
{
   if(g_balanceHalt) return;
   if(AccountBalance() <= 50.0)
   {
      g_balanceHalt = true;
      // 보유 포지션 전체 청산
      for(int i = OrdersTotal()-1; i >= 0; i--)
      {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         {
            if(OrderType()==OP_BUY)
               OrderClose(OrderTicket(), OrderLots(), Bid, 50, clrRed);
            else if(OrderType()==OP_SELL)
               OrderClose(OrderTicket(), OrderLots(), Ask, 50, clrRed);
            else
               OrderDelete(OrderTicket());
         }
      }
      Print(">>> 잔고 $50 이하 도달 - EA 종료");
      Comment("잔고 $50 이하 - EA 종료됨");
      ExpertRemove();   // EA를 차트에서 즉시 제거 (서버 부하 제거)
   }
}

void OnTick()
{
   CheckBalanceStop();   if(g_balanceHalt) return;

   if(!RiskPopupAccepted)
      return;
   if(!g_licenseOK) { return; }

   if(ManageDailyGapStop())
   {
      DrawRails();
      DrawUI();
      return;
   }

   CheckExternalCloseReset();

   if(SafeExitEquity > 0 && AccountEquity() <= SafeExitEquity)
   {
      CloseAll();
      ResetSetup();
      HadPositionBefore = false;
      ExpertRemove();
      return;
   }

   if(TargetProfitUSD > 0 && CurrentProfit() >= TargetProfitUSD)
   {
      CloseAll();
      ResetSetup();
      HadPositionBefore = false;
      DrawUI();
      return;
   }

   if(UseNewBarOnly)
   {
      datetime bt = iTime(Symbol(), Period(), 0);

      if(bt != LastBarTime)
      {
         LastBarTime = bt;
         ProcessLogic();
      }
   }
   else
   {
      ProcessLogic();
   }

   DrawRails();
   DrawUI();
}


// =========================
// Main Logic
// =========================
int ServerDateKey(datetime t)
{
   return TimeYear(t) * 10000 + TimeMonth(t) * 100 + TimeDay(t);
}

bool IsDailyGapCloseTime(datetime t)
{
   // Fixed internal policy: every day from 23:00 broker server time.
   return TimeHour(t) >= DAILY_GAP_CLOSE_HOUR;
}

bool IsMarketReadyAfterDailyGap()
{
   datetime lastTickTime = (datetime)MarketInfo(Symbol(), MODE_TIME);

   if(lastTickTime <= 0)
      return false;

   // The market must deliver a tick from a later server date.
   if(ServerDateKey(lastTickTime) == DailyGapStopDateKey)
      return false;

   if(Bid <= 0 || Ask <= Bid)
      return false;

   if(MarketInfo(Symbol(), MODE_TRADEALLOWED) <= 0)
      return false;

   if(!IsSpreadOK())
      return false;

   return true;
}

string DailyGapStatusText()
{
   if(!DailyGapStop)
      return "OFF";

   if(DailyGapClosePending)
      return "CLOSING";

   if(DailyGapPaused)
   {
      if(ServerDateKey(TimeCurrent()) != DailyGapStopDateKey &&
         !IsMarketReadyAfterDailyGap())
         return "WAIT MARKET";

      return "PAUSED";
   }

   return "READY";
}

void LoadDailyGapState()
{
   DailyGapPaused = false;
   DailyGapClosePending = false;
   DailyGapStopDateKey = 0;

   if(!DailyGapStop)
      return;

   if(GlobalVariableCheck(GV_DAILY_GAP_PAUSED))
      DailyGapPaused = GlobalVariableGet(GV_DAILY_GAP_PAUSED) > 0.5;

   if(GlobalVariableCheck(GV_DAILY_GAP_DATE))
      DailyGapStopDateKey = (int)GlobalVariableGet(GV_DAILY_GAP_DATE);

   datetime now = TimeCurrent();

   if(IsDailyGapCloseTime(now))
   {
      DailyGapPaused = true;
      DailyGapStopDateKey = ServerDateKey(now);
   }

   if(DailyGapPaused && DailyGapStopDateKey <= 0)
      DailyGapStopDateKey = ServerDateKey(now);

   DailyGapClosePending = DailyGapPaused && CountRacehorsePositions() > 0;
}

void SaveDailyGapState()
{
   if(StringLen(GV_DAILY_GAP_PAUSED) <= 0 ||
      StringLen(GV_DAILY_GAP_DATE) <= 0)
      return;

   if(DailyGapStop && (DailyGapPaused || DailyGapClosePending))
   {
      GlobalVariableSet(GV_DAILY_GAP_PAUSED, 1.0);
      GlobalVariableSet(GV_DAILY_GAP_DATE, (double)DailyGapStopDateKey);
   }
   else
   {
      if(GlobalVariableCheck(GV_DAILY_GAP_PAUSED))
         GlobalVariableDel(GV_DAILY_GAP_PAUSED);

      if(GlobalVariableCheck(GV_DAILY_GAP_DATE))
         GlobalVariableDel(GV_DAILY_GAP_DATE);
   }
}

bool CloseAllDailyGap()
{
   for(int retry = 0; retry < DAILY_GAP_CLOSE_RETRIES; retry++)
   {
      CloseAll();

      if(CountRacehorsePositions() <= 0)
         return true;

      Sleep(250);
      RefreshRates();
   }

   return CountRacehorsePositions() <= 0;
}

void ResetAfterDailyGap()
{
   DailyGapPaused = false;
   DailyGapClosePending = false;
   DailyGapStopDateKey = 0;

   ResetSetup();
   HadPositionBefore = false;
   ObjectDelete(0, TOP_LINE);
   ObjectDelete(0, BOT_LINE);

   // Ignore old candles and wait for a new completed candle.
   LastBarTime = iTime(Symbol(), Period(), 0);

   SaveDailyGapState();

   Print("RACEHORSE DAILY GAP STOP released. Fresh logic cycle resumed.");
}

bool ManageDailyGapStop()
{
   if(!DailyGapStop)
   {
      if(DailyGapPaused || DailyGapClosePending)
         ResetAfterDailyGap();

      return false;
   }

   datetime now = TimeCurrent();
   int todayKey = ServerDateKey(now);

   // At or after 23:00 server time, close and pause for the daily market gap.
   if(IsDailyGapCloseTime(now))
   {
      if(!DailyGapPaused || DailyGapStopDateKey != todayKey)
      {
         DailyGapPaused = true;
         DailyGapClosePending = true;
         DailyGapStopDateKey = todayKey;

         Print("RACEHORSE DAILY GAP STOP started at 23:00 server time.");
      }

      DailyGapClosePending = CountRacehorsePositions() > 0;

      if(DailyGapClosePending)
      {
         if(CloseAllDailyGap())
         {
            DailyGapClosePending = false;
            Print("RACEHORSE DAILY GAP close completed. Waiting for market reopen.");
         }
      }

      SaveDailyGapState();
      return true;
   }

   // A paused Friday session naturally remains paused through the weekend.
   // Resume only after the first valid tick from a later server date.
   if(DailyGapPaused || DailyGapClosePending)
   {
      if(CountRacehorsePositions() > 0)
      {
         DailyGapClosePending = true;
         CloseAllDailyGap();
         SaveDailyGapState();
         return true;
      }

      DailyGapClosePending = false;

      if(!IsMarketReadyAfterDailyGap())
      {
         SaveDailyGapState();
         return true;
      }

      ResetAfterDailyGap();
      return false;
   }

   return false;
}

void CheckExternalCloseReset()
{
   bool hasPos = HasPosition();

   // If a global TP manager or manual action closed the position,
   // reset old convergence rails and search a new convergence candle.
   if(HadPositionBefore && !hasPos)
   {
      ResetSetup();
      ObjectDelete(0, TOP_LINE);
      ObjectDelete(0, BOT_LINE);
   }

   HadPositionBefore = hasPos;
}

void ProcessLogic()
{
   if(Bars < 10)
      return;

   if(!IsSpreadOK())
      return;

   if(EntrySignal)
      FindConvergenceCandle();

   if(TopPrice <= 0 || BottomPrice <= 0)
      return;

   int posType = CurrentPositionType();

   // First entry after breakout.
   if(posType < 0)
   {
      if(BreakTop())
      {
         EntryCount = 1;
         FinalLot = TradeLots();
         if(OpenTrade(OP_BUY, FinalLot))
         {
            EntrySignal = false;
            if(UseMartingale)
               FinalLot = NormalizeLots(FinalLot * MartingaleMultiplier);
         }
         return;
      }

      if(BreakBottom())
      {
         EntryCount = 1;
         FinalLot = TradeLots();
         if(OpenTrade(OP_SELL, FinalLot))
         {
            EntrySignal = false;
            if(UseMartingale)
               FinalLot = NormalizeLots(FinalLot * MartingaleMultiplier);
         }
         return;
      }

      return;
   }

   // Trail the breakout rail while trend extends.
   if(posType == OP_BUY)
   {
      if(iClose(Symbol(), Period(), 0) > TopPrice)
         TopPrice = iClose(Symbol(), Period(), 0);

      // Opposite breakout: close BUY, reverse SELL with martingale lot.
      if(BreakBottom())
      {
         if(EntryCount >= MaxEntryCount)
            return;

         CloseType(OP_BUY);
         EntryCount++;

         if(OpenTrade(OP_SELL, FinalLot))
         {
            if(UseMartingale)
               FinalLot = NormalizeLots(FinalLot * MartingaleMultiplier);
         }

         return;
      }
   }

   if(posType == OP_SELL)
   {
      if(iClose(Symbol(), Period(), 0) < BottomPrice)
         BottomPrice = iClose(Symbol(), Period(), 0);

      // Opposite breakout: close SELL, reverse BUY with martingale lot.
      if(BreakTop())
      {
         if(EntryCount >= MaxEntryCount)
            return;

         CloseType(OP_SELL);
         EntryCount++;

         if(OpenTrade(OP_BUY, FinalLot))
         {
            if(UseMartingale)
               FinalLot = NormalizeLots(FinalLot * MartingaleMultiplier);
         }

         return;
      }
   }
}

void FindConvergenceCandle()
{
   if(!TradeTimeOK())
      return;

   // Original concept:
   // Candle[1] is inside Candle[2].
   // Candle[2] range must be compressed under HighLowSize points.
   bool inside = iHigh(Symbol(), Period(), 2) > iHigh(Symbol(), Period(), 1) &&
                 iLow(Symbol(), Period(), 2)  < iLow(Symbol(), Period(), 1);

   double range = iHigh(Symbol(), Period(), 2) - iLow(Symbol(), Period(), 2);

   if(inside && range < HighLowSize * Point)
   {
      TopPrice = iHigh(Symbol(), Period(), 1);
      BottomPrice = iLow(Symbol(), Period(), 1);
      SetupTime = iTime(Symbol(), Period(), 1);
      EntrySignal = false;
      FinalLot = Lots;
      EntryCount = 0;
   }
}

bool BreakTop()
{
   return BreakoutValue() > TopPrice;
}

bool BreakBottom()
{
   return BreakoutValue() < BottomPrice;
}

double BreakoutValue()
{
   if(UseOpenBreakout)
      return iOpen(Symbol(), Period(), 0);

   return iClose(Symbol(), Period(), 1);
}

bool TradeTimeOK()
{
   if(!UseHourFilter)
      return true;

   int h = Hour();

   if(StartHour == EndHour)
      return true;

   if(StartHour < EndHour)
      return h >= StartHour && h <= EndHour;

   return h >= StartHour || h <= EndHour;
}

bool IsSpreadOK()
{
   int sp = (int)MarketInfo(Symbol(), MODE_SPREAD);

   if(MaxSpreadPoints <= 0)
      return true;

   return sp <= MaxSpreadPoints;
}


// =========================
// Trade Functions
// =========================
bool OpenTrade(int type, double lots)
{
   RefreshRates();

   double price = type == OP_BUY ? Ask : Bid;

   int ticket = OrderSend(Symbol(),
                          type,
                          NormalizeLots(lots),
                          NormalizeDouble(price, Digits),
                          Slippage,
                          0,
                          0,
                          ORDER_COMMENT,
                          MagicNumber,
                          0,
                          type == OP_BUY ? clrBlue : clrRed);

   if(ticket < 0)
   {
      int err = GetLastError();
      Alert("경주마 OrderSend 실패. Error=", err);
      ResetLastError();
      return false;
   }

   HadPositionBefore = true;
   return true;
}

double TradeLots()
{
   if(FinalLot <= 0)
      FinalLot = Lots;

   return NormalizeLots(FinalLot);
}

bool HasPosition()
{
   return CurrentPositionType() >= 0;
}

int CurrentPositionType()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() == OP_BUY || OrderType() == OP_SELL)
         return OrderType();
   }

   return -1;
}

double CurrentProfit()
{
   double p = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
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

double TodayPNL()
{
   double p = 0;
   datetime dayStart = StrToTime(TimeToString(TimeCurrent(), TIME_DATE));

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

      if(OrderCloseTime() >= dayStart)
         p += OrderProfit() + OrderSwap() + OrderCommission();
   }

   return p + CurrentProfit();
}

void CloseAll()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      RefreshRates();

      bool ok = false;

      if(OrderType() == OP_BUY)
         ok = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrWhite);

      if(OrderType() == OP_SELL)
         ok = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrWhite);

      if(!ok)
      {
         int err = GetLastError();
         Print("CloseAll failed. ticket=", OrderTicket(), " error=", err);
         ResetLastError();
      }
   }
}

void CloseType(int type)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() != type)
         continue;

      RefreshRates();

      bool ok = false;

      if(OrderType() == OP_BUY)
         ok = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrWhite);

      if(OrderType() == OP_SELL)
         ok = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrWhite);

      if(!ok)
      {
         int err = GetLastError();
         Print("CloseType failed. ticket=", OrderTicket(), " error=", err);
         ResetLastError();
      }
   }
}

double NormalizeLots(double lots)
{
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double step = MarketInfo(Symbol(), MODE_LOTSTEP);

   if(step <= 0)
      step = 0.01;

   lots = MathRound(lots * 100.0) / 100.0;

   if(lots < minLot)
      lots = minLot;

   if(lots > maxLot)
      lots = maxLot;

   lots = MathRound(lots / step) * step;

   if(lots < minLot)
      lots = minLot;

   if(lots > maxLot)
      lots = maxLot;

   return NormalizeDouble(lots, LotDigitsByStep(step));
}

int LotDigitsByStep(double step)
{
   if(step >= 1.0)
      return 0;

   if(step >= 0.1)
      return 1;

   if(step >= 0.01)
      return 2;

   return 3;
}


// =========================
// Reset / Visual
// =========================
void ResetSetup()
{
   EntrySignal = true;
   TopPrice = 0;
   BottomPrice = 0;
   FinalLot = Lots;
   EntryCount = 0;
   SetupTime = 0;
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

void DrawRails()
{
   if(TopPrice > 0)
   {
      if(ObjectFind(0, TOP_LINE) < 0)
         ObjectCreate(0, TOP_LINE, OBJ_HLINE, 0, TimeCurrent(), TopPrice);

      ObjectSetDouble(0, TOP_LINE, OBJPROP_PRICE1, TopPrice);
      ObjectSetInteger(0, TOP_LINE, OBJPROP_COLOR, clrGold);
      ObjectSetInteger(0, TOP_LINE, OBJPROP_WIDTH, 2);
   }
   else
   {
      ObjectDelete(0, TOP_LINE);
   }

   if(BottomPrice > 0)
   {
      if(ObjectFind(0, BOT_LINE) < 0)
         ObjectCreate(0, BOT_LINE, OBJ_HLINE, 0, TimeCurrent(), BottomPrice);

      ObjectSetDouble(0, BOT_LINE, OBJPROP_PRICE1, BottomPrice);
      ObjectSetInteger(0, BOT_LINE, OBJPROP_COLOR, clrGold);
      ObjectSetInteger(0, BOT_LINE, OBJPROP_WIDTH, 2);
   }
   else
   {
      ObjectDelete(0, BOT_LINE);
   }
}

void DrawUI()
{
   if(ObjectFind(0, PANEL_BG) < 0)
      ObjectCreate(0, PANEL_BG, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, PANEL_BG, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_XDISTANCE, 6);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_YDISTANCE, 18);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_XSIZE, 420);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_YSIZE, 372);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_BACK, false);

   if(ObjectFind(0, PANEL_TOP) < 0)
      ObjectCreate(0, PANEL_TOP, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, PANEL_TOP, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_XDISTANCE, 6);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_YDISTANCE, 18);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_XSIZE, 420);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_YSIZE, 28);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_BGCOLOR, clrDarkOrange);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_COLOR, clrDarkOrange);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_BACK, false);

   string pos = "NONE";
   int pt = CurrentPositionType();

   if(pt == OP_BUY)
      pos = "BUY";

   if(pt == OP_SELL)
      pos = "SELL";

   int line = 0;

   SetPanelLine(line++, "경주마 DAILY GAP STOP", clrWhite, 14);
   SetPanelLine(line++, "SYMBOL / TF   : " + Symbol() + " / " + IntegerToString(Period()), clrWhite, 10);
   SetPanelLine(line++, "STATUS        : " + (EntrySignal ? "FINDING NEW CONVERGENCE" : "BREAKOUT READY"), EntrySignal ? clrSilver : clrGold, 10);
   SetPanelLine(line++, "POSITION      : " + pos, pt == OP_BUY ? clrLime : (pt == OP_SELL ? clrTomato : clrSilver), 10);
   SetPanelLine(line++, "TOP RAIL      : " + DoubleToString(TopPrice, Digits), clrGold, 10);
   SetPanelLine(line++, "BOTTOM RAIL   : " + DoubleToString(BottomPrice, Digits), clrGold, 10);
   SetPanelLine(line++, "ENTRY COUNT   : " + IntegerToString(EntryCount) + " / " + IntegerToString(MaxEntryCount), clrWhite, 10);
   SetPanelLine(line++, "NEXT LOT      : " + DoubleToString(TradeLots(), 2), clrGold, 10);
   SetPanelLine(line++, "FLOAT P/L     : $" + DoubleToString(CurrentProfit(), 2), CurrentProfit() >= 0 ? clrLime : clrTomato, 10);
   SetPanelLine(line++, "TODAY'S PNL   : $" + DoubleToString(TodayPNL(), 2), TodayPNL() >= 0 ? clrLime : clrTomato, 10);
   SetPanelLine(line++, "SPREAD        : " + IntegerToString((int)MarketInfo(Symbol(), MODE_SPREAD)) + " / " + IntegerToString(MaxSpreadPoints), IsSpreadOK() ? clrLime : clrTomato, 10);
   SetPanelLine(line++, "DAILY GAP STOP: " + DailyGapStatusText(), DailyGapPaused || DailyGapClosePending ? clrTomato : (DailyGapStop ? clrLime : clrSilver), 10);
   SetPanelLine(line++, "AUTO GAP      : 23:00 CLOSE / AUTO REOPEN", clrGold, 9);
   SetPanelLine(line++, "SERVER TIME   : " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES), clrSilver, 9);
   SetPanelLine(line++, "LOGIC         : NEW CONVERGENCE AFTER CLOSE", clrGold, 9);
   SetPanelLine(line++, "BREAK MODE    : " + (UseOpenBreakout ? "OPEN BREAK" : "CLOSE BREAK"), clrSilver, 9);

   for(int i = line; i < 30; i++)
      SetPanelLine(i, "", clrWhite, 9);
}

void SetPanelLine(int idx, string text, color c, int fontSize=10)
{
   string name = PANEL_TX + IntegerToString(idx);

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 14);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 22 + idx * 18);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void DeleteObjects()
{
   ObjectDelete(0, PANEL_BG);
   ObjectDelete(0, PANEL_TOP);
   ObjectDelete(0, TOP_LINE);
   ObjectDelete(0, BOT_LINE);

   for(int i = 0; i < 40; i++)
      ObjectDelete(0, PANEL_TX + IntegerToString(i));
}
