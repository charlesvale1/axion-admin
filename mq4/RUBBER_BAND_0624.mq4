#property strict

// =====================================================
// License System
// =====================================================
string  g_ProgramName   = "RUBBER_BAND";
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
// BOLLINGER RUBBER BAND EA v9 DAILY GAP STOP
// ----------------------------------------------------------
// Bollinger Band breakout -> close re-entry strategy.
// Additional martingale entries are made only when the same
// breakout -> re-entry condition appears again.
// ==========================================================

input string SETTING_1 = "========== BOLLINGER RUBBER BAND ==========";
input int    MagicNumber              = 70701;
input double Lots                     = 0.10;

input string SETTING_2 = "========== BOLLINGER BAND ==========";
input int    BB_Period                = 20;
input double BB_Deviation             = 2.0;
input int    BB_Shift                 = 0;
input int    BB_AppliedPrice          = PRICE_CLOSE;

// Fixed logic:
// BUY  = previous candle body fully closes below lower band -> current candle closes back inside
// SELL = previous candle body fully closes above upper band -> current candle closes back inside

input string SETTING_3 = "========== MARTINGALE ==========";
input bool   UseMartingale            = true;
input double MartingaleMultiplier     = 1.5;
input int    MaxMartingaleStep        = 10;
input int    StartTradeFromMartinStep = 1;

input string SETTING_4 = "========== CLOSE SETTING ==========";
input double TARGET_PROFIT_USD        = 30.0;
input double SAFE_EXIT_EQUITY         = 0.0;
input bool   CloseOppositeBeforeEntry = false;

input string SETTING_5 = "========== TRADE FILTER ==========";
input int    MaxSpreadPoints          = 80;
input int    Slippage                 = 5;
input bool   TradeOnNewBarOnly        = true;

input string SETTING_6 = "========== DAILY GAP STOP ==========";
input bool   DailyGapStop             = false;   // true = auto close daily at 23:00 server time

input string SETTING_7 = "========== VISUAL / SAFETY ==========";
input bool   SetChartStyle            = true;
input bool   ShowKoreanRiskPopup      = true;
input int    HistoryBarsToDraw        = 1000;

datetime LastBarTime = 0;
bool RiskPopupAccepted = false;

int BuyMartinStep = 0;
int SellMartinStep = 0;

bool DailyGapPaused = false;
bool DailyGapClosePending = false;
int  DailyGapStopDateKey = 0;

int DAILY_GAP_CLOSE_HOUR = 23;
int DAILY_GAP_CLOSE_RETRIES = 5;

string GV_DAILY_GAP_PAUSED = "";
string GV_DAILY_GAP_DATE = "";

string PANEL_BG  = "BRB_PANEL_BG";
string PANEL_TOP = "BRB_PANEL_TOP";
string PANEL_TX  = "BRB_PANEL_TX_";
string HIST_PREFIX = "BRB_HIST_";

bool   ShowRiskNoticePopup();
void   ProcessNewBar();
void   SetupChart();
void   DrawUI();
void   SetPanelLine(int idx, string text, color c, int fontSize=10);
void   DeleteUI();

bool   ManageDailyGapStop();
bool   IsDailyGapCloseTime(datetime t);
bool   IsMarketReadyAfterDailyGap();
int    ServerDateKey(datetime t);
string DailyGapStatusText();
void   LoadDailyGapState();
void   SaveDailyGapState();
void   ResetAfterDailyGap();
bool   CloseAllDailyGap();

bool   BuySignal(int shift);
bool   SellSignal(int shift);
bool   IsBodyFullyBelowBand(int shift);
bool   IsBodyFullyAboveBand(int shift);

bool   OpenTrade(int type);
double NextLots(int type, int martinStep);
int    CountType(int type);
int    CountAll();
bool   ShouldEnterMartinStep(int martinStep);
double FloatingProfit();
double ProfitByType(int type);
double TodayPNL();
bool   IsSpreadOK();
void   CloseAll();
void   CloseType(int type);
double NormalizeLots(double lots);
int    LotDigitsByStep(double step);

void   DrawHistoricalSignals();
void   ClearHistoricalSignals();
void   DrawSignal(string name, datetime t, double price, string text, color c, int size);

bool ShowRiskNoticePopup()
{
   if(!ShowKoreanRiskPopup)
      return true;

   string msg = "";
   msg += "EA 시작 전 필수 투자위험 및 책임 고지\n\n";
   msg += "본 EA는 볼린저밴드 몸통 완전 이탈 후 종가 재진입 구간을 활용하는 자동매매 보조 소프트웨어이며, 수익을 보장하지 않습니다.\n\n";
   msg += "해외선물, FX마진, CFD, 가상자산 및 기타 레버리지 상품은 시장 변동성, 스프레드 확대, 슬리피지, 체결 지연, 서버 장애, 증거금 부족, 강제청산 등으로 인해 원금 손실은 물론 원금 초과 손실이 발생할 수 있는 고위험 상품입니다.\n\n";
   msg += "본 EA의 설정값, 안내값, 과거 운용 결과, 백테스트 및 시뮬레이션 자료는 참고용 정보일 뿐이며 미래 수익이나 손실 제한을 보장하지 않습니다.\n\n";
   msg += "특히 마틴게일 기능은 손실 구간에서 비중이 증가하므로 계좌 규모와 위험 감내 수준에 맞게 신중하게 설정해야 합니다.\n\n";
   msg += "DailyGapStop=true 사용 시 매일 브로커 서버시간 23:00부터 포지션을 전부 청산하고 신규 진입을 중단합니다. 다음 서버 날짜의 첫 정상 시장 틱이 확인되면 새 사이클로 자동 재개합니다.\n\n";
   msg += "위 위험을 이해했으며, 본인 판단과 책임으로 EA를 실행합니다.\n\n";
   msg += "[확인]을 누르면 EA가 시작됩니다. [취소]를 누르면 EA가 중지됩니다.";

   int res = MessageBox(msg, "볼린저 고무줄 EA 필수 투자위험 및 책임 고지", MB_OKCANCEL | MB_ICONWARNING);

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

   GV_DAILY_GAP_PAUSED = "BRB_DAILY_GAP_PAUSED_" +
                         IntegerToString(AccountNumber()) + "_" +
                         Symbol() + "_" +
                         IntegerToString(MagicNumber);
   GV_DAILY_GAP_DATE = "BRB_DAILY_GAP_DATE_" +
                       IntegerToString(AccountNumber()) + "_" +
                       Symbol() + "_" +
                       IntegerToString(MagicNumber);

   LoadDailyGapState();

   DrawHistoricalSignals();
   DrawUI();

   LastBarTime = iTime(Symbol(), Period(), 0);

   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   SaveDailyGapState();
   DeleteUI();
   ClearHistoricalSignals();
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
      DrawUI();
      return;
   }

   if(SAFE_EXIT_EQUITY > 0 && AccountEquity() <= SAFE_EXIT_EQUITY)
   {
      CloseAll();
      BuyMartinStep = 0;
      SellMartinStep = 0;
      ExpertRemove();
      return;
   }

   if(TARGET_PROFIT_USD > 0)
   {
      if(ProfitByType(OP_BUY) >= TARGET_PROFIT_USD)
      {
         CloseType(OP_BUY);
         BuyMartinStep = 0;
         DrawUI();
         return;
      }

      if(ProfitByType(OP_SELL) >= TARGET_PROFIT_USD)
      {
         CloseType(OP_SELL);
         SellMartinStep = 0;
         DrawUI();
         return;
      }
   }

   if(TradeOnNewBarOnly)
   {
      datetime bt = iTime(Symbol(), Period(), 0);

      if(bt != LastBarTime)
      {
         LastBarTime = bt;
         ProcessNewBar();
         DrawHistoricalSignals();
      }
   }
   else
   {
      ProcessNewBar();
   }

   DrawUI();
}

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

   DailyGapClosePending = DailyGapPaused && CountAll() > 0;
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

      if(CountAll() <= 0)
         return true;

      Sleep(250);
      RefreshRates();
   }

   return CountAll() <= 0;
}

void ResetAfterDailyGap()
{
   DailyGapPaused = false;
   DailyGapClosePending = false;
   DailyGapStopDateKey = 0;

   BuyMartinStep = 0;
   SellMartinStep = 0;

   // Ignore the old candle and wait for a newly completed candle.
   LastBarTime = iTime(Symbol(), Period(), 0);

   SaveDailyGapState();

   Print("BOLLINGER RUBBER BAND DAILY GAP STOP released. Fresh logic cycle resumed.");
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

         Print("BOLLINGER RUBBER BAND DAILY GAP STOP started at 23:00 server time.");
      }

      DailyGapClosePending = CountAll() > 0;

      if(DailyGapClosePending)
      {
         if(CloseAllDailyGap())
         {
            DailyGapClosePending = false;
            Print("BOLLINGER RUBBER BAND DAILY GAP close completed. Waiting for market reopen.");
         }
      }

      SaveDailyGapState();
      return true;
   }

   // A paused Friday session naturally remains paused through the weekend.
   // Resume only after the first valid tick from a later server date.
   if(DailyGapPaused || DailyGapClosePending)
   {
      if(CountAll() > 0)
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

void ProcessNewBar()
{
   if(Bars < BB_Period + 10)
      return;

   if(!IsSpreadOK())
      return;

   bool buy = BuySignal(1);
   bool sell = SellSignal(1);

   if(buy && !sell)
   {
      BuyMartinStep++;

      if(BuyMartinStep > MaxMartingaleStep)
         BuyMartinStep = MaxMartingaleStep;

      if(ShouldEnterMartinStep(BuyMartinStep) && CountType(OP_BUY) < MaxMartingaleStep)
         OpenTrade(OP_BUY);

      return;
   }

   if(sell && !buy)
   {
      SellMartinStep++;

      if(SellMartinStep > MaxMartingaleStep)
         SellMartinStep = MaxMartingaleStep;

      if(ShouldEnterMartinStep(SellMartinStep) && CountType(OP_SELL) < MaxMartingaleStep)
         OpenTrade(OP_SELL);

      return;
   }
}

bool BuySignal(int shift)
{
   // Signal candle must be a closed candle.
   // Previous candle body must be fully outside the lower band.
   // Current candle must close back inside the lower band.
   if(shift < 1)
      return false;

   int outsideShift = shift + 1;

   if(outsideShift >= Bars)
      return false;

   double lowerNow = iBands(Symbol(), Period(), BB_Period, BB_Deviation, BB_Shift, BB_AppliedPrice, MODE_LOWER, shift);

   if(lowerNow <= 0)
      return false;

   bool fullBreakout = IsBodyFullyBelowBand(outsideShift);
   bool closeReentry = iClose(Symbol(), Period(), shift) > lowerNow;

   return fullBreakout && closeReentry;
}

bool SellSignal(int shift)
{
   // Signal candle must be a closed candle.
   // Previous candle body must be fully outside the upper band.
   // Current candle must close back inside the upper band.
   if(shift < 1)
      return false;

   int outsideShift = shift + 1;

   if(outsideShift >= Bars)
      return false;

   double upperNow = iBands(Symbol(), Period(), BB_Period, BB_Deviation, BB_Shift, BB_AppliedPrice, MODE_UPPER, shift);

   if(upperNow <= 0)
      return false;

   bool fullBreakout = IsBodyFullyAboveBand(outsideShift);
   bool closeReentry = iClose(Symbol(), Period(), shift) < upperNow;

   return fullBreakout && closeReentry;
}

bool IsBodyFullyBelowBand(int shift)
{
   double lower = iBands(Symbol(), Period(), BB_Period, BB_Deviation, BB_Shift, BB_AppliedPrice, MODE_LOWER, shift);

   if(lower <= 0)
      return false;

   double bodyHigh = MathMax(iOpen(Symbol(), Period(), shift), iClose(Symbol(), Period(), shift));

   // Complete body breakout below lower band.
   return bodyHigh < lower;
}

bool IsBodyFullyAboveBand(int shift)
{
   double upper = iBands(Symbol(), Period(), BB_Period, BB_Deviation, BB_Shift, BB_AppliedPrice, MODE_UPPER, shift);

   if(upper <= 0)
      return false;

   double bodyLow = MathMin(iOpen(Symbol(), Period(), shift), iClose(Symbol(), Period(), shift));

   // Complete body breakout above upper band.
   return bodyLow > upper;
}

bool OpenTrade(int type)
{
   RefreshRates();

   int martinStep = (type == OP_BUY) ? BuyMartinStep : SellMartinStep;
   double lots = NextLots(type, martinStep);
   double price = type == OP_BUY ? Ask : Bid;

   int ticket = OrderSend(Symbol(), type, lots, NormalizeDouble(price, Digits), Slippage, 0, 0,
                          "BOLLINGER_RUBBER_BAND_GAP_STOP", MagicNumber, 0, type == OP_BUY ? clrLime : clrTomato);

   if(ticket < 0)
   {
      int err = GetLastError();
      Alert("BOLLINGER RUBBER BAND OrderSend failed. Error=", err);
      ResetLastError();
      return false;
   }

   return true;
}

double NextLots(int type, int martinStep)
{
   double lot = Lots;

   if(martinStep < 1)
      martinStep = 1;

   if(martinStep > MaxMartingaleStep)
      martinStep = MaxMartingaleStep;

   if(UseMartingale)
      lot = Lots * MathPow(MartingaleMultiplier, martinStep - 1);

   lot = MathRound(lot * 100.0) / 100.0;

   return NormalizeLots(lot);
}

int CountType(int type)
{
   int c = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() == type)
         c++;
   }

   return c;
}

int CountAll()
{
   return CountType(OP_BUY) + CountType(OP_SELL);
}

bool ShouldEnterMartinStep(int martinStep)
{
   int startStep = StartTradeFromMartinStep;

   if(startStep < 1)
      startStep = 1;

   if(startStep > MaxMartingaleStep)
      startStep = MaxMartingaleStep;

   return martinStep >= startStep;
}


double FloatingProfit()
{
   double p = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() == OP_BUY || OrderType() == OP_SELL)
         p += OrderProfit() + OrderSwap() + OrderCommission();
   }

   return p;
}

double ProfitByType(int type)
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


double TodayPNL()
{
   double p = 0;
   datetime dayStart = StrToTime(TimeToString(TimeCurrent(), TIME_DATE));

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      if(OrderCloseTime() >= dayStart)
         p += OrderProfit() + OrderSwap() + OrderCommission();
   }

   return p + FloatingProfit();
}

bool IsSpreadOK()
{
   int sp = (int)MarketInfo(Symbol(), MODE_SPREAD);

   if(MaxSpreadPoints <= 0)
      return true;

   return sp <= MaxSpreadPoints;
}

void CloseAll()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
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

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber || OrderType() != type)
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

void ClearHistoricalSignals()
{
   for(int i = ObjectsTotal() - 1; i >= 0; i--)
   {
      string name = ObjectName(i);

      if(StringFind(name, HIST_PREFIX, 0) == 0)
         ObjectDelete(0, name);
   }
}


double SimBasketProfit(int total, int &types[], double &entries[], double &lots[], double closePrice)
{
   double p = 0;
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);

   if(tickSize <= 0)
      tickSize = Point;

   for(int i = 0; i < total; i++)
   {
      if(types[i] == OP_BUY)
         p += ((closePrice - entries[i]) / tickSize) * tickValue * lots[i];

      if(types[i] == OP_SELL)
         p += ((entries[i] - closePrice) / tickSize) * tickValue * lots[i];
   }

   return p;
}

void DrawHistoricalSignals()
{
   ClearHistoricalSignals();

   int maxShift = HistoryBarsToDraw;

   if(maxShift > Bars - BB_Period - 5)
      maxShift = Bars - BB_Period - 5;

   if(maxShift < 2)
      return;

   int drawn = 0;

   int simBuyStep = 0;
   int simSellStep = 0;

   int buyTypes[50];
   double buyEntries[50];
   double buyLots[50];
   int buyTotal = 0;

   int sellTypes[50];
   double sellEntries[50];
   double sellLots[50];
   int sellTotal = 0;

   // Oldest -> newest.
   // BUY martingale and SELL martingale are calculated separately.
   for(int shift = maxShift; shift >= 1; shift--)
   {
      datetime t = iTime(Symbol(), Period(), shift);
      double closePrice = iClose(Symbol(), Period(), shift);

      bool buy = BuySignal(shift);
      bool sell = SellSignal(shift);

      if(buy && !sell)
      {
         simBuyStep++;

         if(simBuyStep > MaxMartingaleStep)
            simBuyStep = MaxMartingaleStep;

         double lot = NextLots(OP_BUY, simBuyStep);
         bool skipped = simBuyStep < StartTradeFromMartinStep;

         if(!skipped && buyTotal < 50)
         {
            buyTypes[buyTotal] = OP_BUY;
            buyEntries[buyTotal] = closePrice;
            buyLots[buyTotal] = lot;
            buyTotal++;
         }

         double buyProfit = SimBasketProfit(buyTotal, buyTypes, buyEntries, buyLots, closePrice);
         bool take = (TARGET_PROFIT_USD > 0 && buyProfit >= TARGET_PROFIT_USD);

         string tag = "BAND BUY M" + IntegerToString(simBuyStep);

         if(skipped)
            tag = tag + " SKIP";

         if(take)
            tag = tag + " TAKE";

         double price = iLow(Symbol(), Period(), shift) - Point * 35;
         DrawSignal(HIST_PREFIX + "B_" + IntegerToString(shift) + "_" + IntegerToString((int)t),
                    t,
                    price,
                    tag,
                    skipped ? clrSilver : (take ? clrGold : clrLime),
                    take ? 11 : (skipped ? 8 : 10));
         drawn++;

         if(take)
         {
            simBuyStep = 0;
            buyTotal = 0;
         }
      }

      if(sell && !buy)
      {
         simSellStep++;

         if(simSellStep > MaxMartingaleStep)
            simSellStep = MaxMartingaleStep;

         double lot2 = NextLots(OP_SELL, simSellStep);
         bool skipped2 = simSellStep < StartTradeFromMartinStep;

         if(!skipped2 && sellTotal < 50)
         {
            sellTypes[sellTotal] = OP_SELL;
            sellEntries[sellTotal] = closePrice;
            sellLots[sellTotal] = lot2;
            sellTotal++;
         }

         double sellProfit = SimBasketProfit(sellTotal, sellTypes, sellEntries, sellLots, closePrice);
         bool take2 = (TARGET_PROFIT_USD > 0 && sellProfit >= TARGET_PROFIT_USD);

         string tag2 = "BAND SELL M" + IntegerToString(simSellStep);

         if(skipped2)
            tag2 = tag2 + " SKIP";

         if(take2)
            tag2 = tag2 + " TAKE";

         double price2 = iHigh(Symbol(), Period(), shift) + Point * 35;
         DrawSignal(HIST_PREFIX + "S_" + IntegerToString(shift) + "_" + IntegerToString((int)t),
                    t,
                    price2,
                    tag2,
                    skipped2 ? clrSilver : (take2 ? clrGold : clrTomato),
                    take2 ? 11 : (skipped2 ? 8 : 10));
         drawn++;

         if(take2)
         {
            simSellStep = 0;
            sellTotal = 0;
         }
      }

      // BUY basket can reach its own target independently.
      if(!buy && buyTotal > 0)
      {
         double bp = SimBasketProfit(buyTotal, buyTypes, buyEntries, buyLots, closePrice);

         if(TARGET_PROFIT_USD > 0 && bp >= TARGET_PROFIT_USD)
         {
            DrawSignal(HIST_PREFIX + "B_TAKE_" + IntegerToString(shift) + "_" + IntegerToString((int)t),
                       t,
                       closePrice,
                       "BUY TARGET TAKE M" + IntegerToString(simBuyStep),
                       clrGold,
                       10);

            drawn++;
            simBuyStep = 0;
            buyTotal = 0;
         }
      }

      // SELL basket can reach its own target independently.
      if(!sell && sellTotal > 0)
      {
         double sp = SimBasketProfit(sellTotal, sellTypes, sellEntries, sellLots, closePrice);

         if(TARGET_PROFIT_USD > 0 && sp >= TARGET_PROFIT_USD)
         {
            DrawSignal(HIST_PREFIX + "S_TAKE_" + IntegerToString(shift) + "_" + IntegerToString((int)t),
                       t,
                       closePrice,
                       "SELL TARGET TAKE M" + IntegerToString(simSellStep),
                       clrGold,
                       10);

            drawn++;
            simSellStep = 0;
            sellTotal = 0;
         }
      }

      if(drawn >= 900)
         break;
   }
}

void DrawSignal(string name, datetime t, double price, string text, color c, int size)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, t, price);

   ObjectSetInteger(0, name, OBJPROP_TIME1, t);
   ObjectSetDouble(0, name, OBJPROP_PRICE1, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
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

void DrawUI()
{
   if(ObjectFind(0, PANEL_BG) < 0)
      ObjectCreate(0, PANEL_BG, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, PANEL_BG, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_XDISTANCE, 6);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_YDISTANCE, 18);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_XSIZE, 430);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_YSIZE, 335);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, PANEL_BG, OBJPROP_BACK, false);

   if(ObjectFind(0, PANEL_TOP) < 0)
      ObjectCreate(0, PANEL_TOP, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, PANEL_TOP, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_XDISTANCE, 6);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_YDISTANCE, 18);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_XSIZE, 430);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_YSIZE, 28);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_BGCOLOR, clrDarkOrange);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_COLOR, clrDarkOrange);
   ObjectSetInteger(0, PANEL_TOP, OBJPROP_BACK, false);

   int line = 0;

   SetPanelLine(line++, "BOLLINGER RUBBER BAND DAILY GAP", clrWhite, 13);
   SetPanelLine(line++, "SYMBOL / TF    : " + Symbol() + " / " + IntegerToString(Period()), clrWhite, 10);
   SetPanelLine(line++, "MODE           : FULL BODY OUT -> CLOSE RE-ENTRY", clrSilver, 9);
   SetPanelLine(line++, "BB SETTING     : " + IntegerToString(BB_Period) + " / " + DoubleToString(BB_Deviation, 1), clrGold, 10);
   SetPanelLine(line++, "BUY MARTIN    : M" + IntegerToString(BuyMartinStep) + " / " + IntegerToString(MaxMartingaleStep), clrLime, 10);
   SetPanelLine(line++, "SELL MARTIN   : M" + IntegerToString(SellMartinStep) + " / " + IntegerToString(MaxMartingaleStep), clrTomato, 10);
   SetPanelLine(line++, "START ENTRY    : M" + IntegerToString(StartTradeFromMartinStep), clrGold, 10);
   SetPanelLine(line++, "NEXT BUY LOT   : " + DoubleToString(NextLots(OP_BUY, BuyMartinStep + 1), 2), clrLime, 10);
   SetPanelLine(line++, "NEXT SELL LOT  : " + DoubleToString(NextLots(OP_SELL, SellMartinStep + 1), 2), clrTomato, 10);
   SetPanelLine(line++, "FLOAT P/L      : $" + DoubleToString(FloatingProfit(), 2) + " / TARGET $" + DoubleToString(TARGET_PROFIT_USD, 2), FloatingProfit() >= 0 ? clrLime : clrTomato, 10);
   SetPanelLine(line++, "TODAY'S PNL    : $" + DoubleToString(TodayPNL(), 2), TodayPNL() >= 0 ? clrLime : clrTomato, 10);
   SetPanelLine(line++, "SPREAD         : " + IntegerToString((int)MarketInfo(Symbol(), MODE_SPREAD)) + " / " + IntegerToString(MaxSpreadPoints), IsSpreadOK() ? clrLime : clrTomato, 10);
   SetPanelLine(line++, "DAILY GAP STOP : " + DailyGapStatusText(), DailyGapPaused || DailyGapClosePending ? clrTomato : (DailyGapStop ? clrLime : clrSilver), 10);
   SetPanelLine(line++, "AUTO GAP       : 23:00 CLOSE / AUTO REOPEN", clrGold, 9);
   SetPanelLine(line++, "SERVER TIME    : " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES), clrSilver, 9);
   SetPanelLine(line++, "LOGIC          : FULL BODY OUT -> RE-ENTRY", clrGold, 9);

   for(int i = line; i < 26; i++)
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

void DeleteUI()
{
   ObjectDelete(0, PANEL_BG);
   ObjectDelete(0, PANEL_TOP);

   for(int i = 0; i < 30; i++)
      ObjectDelete(0, PANEL_TX + IntegerToString(i));
}
