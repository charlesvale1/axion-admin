//+------------------------------------------------------------------+
//| MachineGun_AXION_v2.mq4                                          |
//| AXION Trading System                                             |
//| - License check via Supabase on startup                         |
//| - Balance reporting every N minutes                             |
//| - MT4 chart dashboard                                           |
//+------------------------------------------------------------------+
#property strict
#property copyright "AXION"
#property version   "2.00"

//==============================
// EA Identity
//==============================
input string EA_Label             = "AXION MachineGun v2";
input int    MagicNumber          = 20260508;
input string EA_ProgramName       = "MachineGun";

//==============================
// Lot & Slippage
//==============================
input double BaseLots             = 0.01;
input int    Slippage             = 5;
input int    MaxSpreadPoints      = 80;

//==============================
// Risk Management
//==============================
input double DailyProfitTargetPct  = 3.0;
input double DailyLossLimitPct     = 10.0;
input double EmergencyStopPct      = 15.0;
input bool   CloseAllAtDailyTarget = false;

//==============================
// Session Filter
//==============================
input bool   UseSessionFilter     = true;
input int    SessionStartHour     = 8;
input int    SessionEndHour       = 20;

//==============================
// Entry Timing
//==============================
input int    MinMinutesBetweenTrades = 3;
input int    MaxPositionsPerSymbol   = 8;

//==============================
// Indicators
//==============================
input int    BB_Period            = 20;
input double BB_Deviation         = 2.0;
input int    FastMA_Period        = 20;
input int    SlowMA_Period        = 50;
input int    RSI_Period           = 14;
input double RSI_BuyLevel         = 45.0;
input double RSI_SellLevel        = 55.0;
input int    Ichimoku_Tenkan      = 9;
input int    Ichimoku_Kijun       = 26;
input int    Ichimoku_Senkou      = 52;
input int    ADX_Period           = 14;
input double ADX_MinLevel         = 15.0;

input bool   UseADXFilter         = true;
input bool   UseIchimokuFilter    = true;
input bool   UseMAFilter          = true;
input bool   UseRSIFilter         = true;
input bool   UseBBSignal          = true;

//==============================
// TP / SL / Trailing
//==============================
input int    TakeProfitPoints     = 300;
input int    StopLossPoints       = 600;
input bool   UseTrailingStop      = true;
input int    TrailingStartPoints  = 150;
input int    TrailingStepPoints   = 80;
input bool   UseBasketTP          = true;
input double BasketProfitPct      = 2.0;

//==============================
// Martingale
//==============================
input bool   UseMartingale        = true;
input double MartinMultiplier     = 1.5;
input int    MaxMartinStep        = 4;
input int    GridStepPoints       = 250;

//==============================
// Supabase 서버 설정
//==============================
input string SupabaseURL          = "https://wmvnearoursbmwjqwzww.supabase.co";
input string SupabaseAnonKey      = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indtdm5lYXJvdXJzYm13anF3end3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgxNzQ5MjEsImV4cCI6MjA5Mzc1MDkyMX0.MS4iSGIvW4dBi3sd8J3baHLT4TlgUJS5lXwlhJdWYEY";
input bool   SendBalanceToServer  = true;
input int    BalanceSendMinutes   = 5;

//==============================
// Internal
//==============================
datetime lastTradeTime   = 0;
datetime currentDay      = 0;
double   dayStartEquity  = 0;
bool     licenseValid    = false;
string   licenseStatus   = "확인 중...";

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   licenseValid  = false;
   licenseStatus = "라이선스 확인 중...";
   UpdateDashboard();
   Sleep(300);

   if(!CheckLicense())
   {
      UpdateDashboard();
      Print("AXION: License FAILED. EA stopped.");
      return(INIT_FAILED);
   }

   licenseValid   = true;
   currentDay     = iTime(Symbol(), PERIOD_D1, 0);
   dayStartEquity = AccountEquity();

   if(SendBalanceToServer)
      EventSetTimer(BalanceSendMinutes * 60);

   Print("AXION: License OK. Status=", licenseStatus);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   Comment("");
}

//+------------------------------------------------------------------+
//| License Check                                                    |
//+------------------------------------------------------------------+
bool CheckLicense()
{
   string account = IntegerToString((int)AccountNumber());

   string url = SupabaseURL
      + "/rest/v1/customer_program_access"
      + "?account_no=eq." + account
      + "&is_active=eq.true"
      + "&program_name=eq." + EA_ProgramName
      + "&select=expires_at";

   string reqHeaders = "apikey: " + SupabaseAnonKey + "\r\n"
                     + "Authorization: Bearer " + SupabaseAnonKey;

   char post[]; char result[]; string resHeaders;
   int http = WebRequest("GET", url, reqHeaders, 8000, post, result, resHeaders);

   if(http != 200)
   {
      licenseStatus = "서버 연결 실패 (HTTP " + IntegerToString(http) + ") | WinErr=" + IntegerToString(GetLastError());
      Print("License HTTP=", http, " Err=", GetLastError());
      return false;
   }

   string body = CharArrayToString(result);
   Print("License body: ", body);

   // 빈 배열이면 미등록
   if(body == "[]" || StringFind(body, "expires_at") < 0)
   {
      licenseStatus = "미등록 계좌 — 관리자에게 문의";
      return false;
   }

   // expires_at 파싱: "expires_at":"2026-07-08T..."
   int s = StringFind(body, "\"expires_at\":\"");
   if(s < 0) { licenseStatus = "응답 파싱 오류"; return false; }
   s += 14;
   int e = StringFind(body, "\"", s);
   string expiresAt = StringSubstr(body, s, e - s); // "2026-07-08T00:00:00+00:00"

   // 날짜 앞 10글자 "2026-07-08" → "2026.07.08"
   string expDate = StringSubstr(expiresAt, 0, 10);
   StringReplace(expDate, "-", ".");

   // 오늘 날짜 "2026.05.08"
   string today = TimeToString(TimeCurrent(), TIME_DATE);

   if(expDate < today)
   {
      licenseStatus = "만료됨 (" + expDate + "까지였음)";
      return false;
   }

   licenseStatus = "유효  |  " + expDate + "까지";
   return true;
}

//+------------------------------------------------------------------+
//| Timer                                                            |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(SendBalanceToServer && licenseValid)
      SendBalance();
}

//+------------------------------------------------------------------+
//| Tick                                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!licenseValid) return;

   RefreshRates();
   ResetDailyIfNeeded();
   UpdateDashboard();

   if(!IsTradeAllowed()) return;
   if(!RiskGate())       return;
   if(!SessionGate())    return;

   double spread = MarketInfo(Symbol(), MODE_SPREAD);
   if(spread > MaxSpreadPoints) return;

   if(UseBasketTP)     CheckBasketTP();
   if(UseTrailingStop) DoTrailingStop();

   int openCount = CountOpen();
   if(openCount >= MaxPositionsPerSymbol) return;

   if(UseMartingale && openCount > 0) { TryMartinEntry(); return; }
   if(!CanOpenByTime()) return;

   int sig = GetSignal();
   if(sig == OP_BUY)  OpenOrder(OP_BUY,  BaseLots, "AXION BUY");
   if(sig == OP_SELL) OpenOrder(OP_SELL, BaseLots, "AXION SELL");
}

//+------------------------------------------------------------------+
//| Dashboard                                                        |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   double equity    = AccountEquity();
   double balance   = AccountBalance();
   double dayPnL    = equity - dayStartEquity;
   double dayPnLPct = dayStartEquity > 0 ? dayPnL / dayStartEquity * 100.0 : 0;
   string sign      = dayPnL >= 0 ? "+" : "";

   string status = "";
   if(!licenseValid)                        status = "✖ " + licenseStatus;
   else if(dayPnLPct >= DailyProfitTargetPct) status = "★ 일일 목표 달성";
   else if(dayPnLPct <= -DailyLossLimitPct)   status = "✖ 손실 한도 도달";
   else                                        status = "● 정상 운영 중";

   string d = "";
   d += "┌────────────────────────────────┐\n";
   d += "│  " + EA_Label + "\n";
   d += "├────────────────────────────────┤\n";
   d += "│  계 좌 : " + IntegerToString((int)AccountNumber()) + "\n";
   d += "│  라이선스 : " + licenseStatus + "\n";
   d += "├────────────────────────────────┤\n";
   d += "│  잔  고 : $" + DoubleToString(balance, 2) + "\n";
   d += "│  순자산 : $" + DoubleToString(equity,  2) + "\n";
   d += "│  오늘PnL: " + sign + DoubleToString(dayPnL, 2) + " (" + sign + DoubleToString(dayPnLPct,2) + "%)\n";
   d += "│  포지션 : " + IntegerToString(CountOpen()) + "개  미실현: $" + DoubleToString(equity-balance,2) + "\n";
   d += "├────────────────────────────────┤\n";
   d += "│  목표 +" + DoubleToString(DailyProfitTargetPct,1) + "%  │  한도 -" + DoubleToString(DailyLossLimitPct,1) + "%\n";
   d += "│  세션 : " + (SessionGate() ? "런던/뉴욕 ● ON" : "세션 외 ○ 대기") + "\n";
   d += "│  마틴 : " + (UseMartingale?"ON":"OFF") + "  트레일: " + (UseTrailingStop?"ON":"OFF") + "\n";
   d += "│  상태 : " + status + "\n";
   d += "└────────────────────────────────┘";
   Comment(d);
}

//+------------------------------------------------------------------+
//| Risk / Session / Daily                                           |
//+------------------------------------------------------------------+
bool SessionGate()
{
   if(!UseSessionFilter) return true;
   int h = TimeHour(TimeCurrent());
   return (h >= SessionStartHour && h < SessionEndHour);
}

void ResetDailyIfNeeded()
{
   datetime d = iTime(Symbol(), PERIOD_D1, 0);
   if(d != currentDay)
   { currentDay = d; dayStartEquity = AccountEquity(); }
}

bool RiskGate()
{
   if(dayStartEquity <= 0) return true;
   double pct = (AccountEquity() - dayStartEquity) / dayStartEquity * 100.0;
   if(pct >= DailyProfitTargetPct) { if(CloseAllAtDailyTarget) CloseAll(); return false; }
   if(pct <= -EmergencyStopPct)    { CloseAll(); return false; }
   if(pct <= -DailyLossLimitPct)   return false;
   return true;
}

//+------------------------------------------------------------------+
//| Signal                                                           |
//+------------------------------------------------------------------+
int GetSignal()
{
   double close0  = iClose(Symbol(), PERIOD_CURRENT, 0);
   double close1  = iClose(Symbol(), PERIOD_CURRENT, 1);
   double upper   = iBands(Symbol(), PERIOD_CURRENT, BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_UPPER, 1);
   double lower   = iBands(Symbol(), PERIOD_CURRENT, BB_Period, BB_Deviation, 0, PRICE_CLOSE, MODE_LOWER, 1);
   double fastMA  = iMA(Symbol(), PERIOD_CURRENT, FastMA_Period, 0, MODE_EMA, PRICE_CLOSE, 0);
   double slowMA  = iMA(Symbol(), PERIOD_CURRENT, SlowMA_Period, 0, MODE_EMA, PRICE_CLOSE, 0);
   double rsi     = iRSI(Symbol(), PERIOD_CURRENT, RSI_Period, PRICE_CLOSE, 1);
   double adx     = iADX(Symbol(), PERIOD_CURRENT, ADX_Period, PRICE_CLOSE, MODE_MAIN,   0);
   double diP     = iADX(Symbol(), PERIOD_CURRENT, ADX_Period, PRICE_CLOSE, MODE_PLUSDI, 0);
   double diM     = iADX(Symbol(), PERIOD_CURRENT, ADX_Period, PRICE_CLOSE, MODE_MINUSDI,0);
   double tenkan  = iIchimoku(Symbol(),PERIOD_CURRENT,Ichimoku_Tenkan,Ichimoku_Kijun,Ichimoku_Senkou,MODE_TENKANSEN, 0);
   double kijun   = iIchimoku(Symbol(),PERIOD_CURRENT,Ichimoku_Tenkan,Ichimoku_Kijun,Ichimoku_Senkou,MODE_KIJUNSEN,  0);
   double spanA   = iIchimoku(Symbol(),PERIOD_CURRENT,Ichimoku_Tenkan,Ichimoku_Kijun,Ichimoku_Senkou,MODE_SENKOUSPANA,26);
   double spanB   = iIchimoku(Symbol(),PERIOD_CURRENT,Ichimoku_Tenkan,Ichimoku_Kijun,Ichimoku_Senkou,MODE_SENKOUSPANB,26);
   double cTop    = MathMax(spanA,spanB);
   double cBot    = MathMin(spanA,spanB);

   int buyScore = 0, sellScore = 0;
   if(!UseBBSignal       || close1 <= lower)                        buyScore++;
   if(!UseMAFilter       || fastMA > slowMA)                        buyScore++;
   if(!UseRSIFilter      || rsi <= RSI_BuyLevel)                    buyScore++;
   if(!UseADXFilter      || (adx >= ADX_MinLevel && diP > diM))     buyScore++;
   if(!UseIchimokuFilter || (close0 > cTop && tenkan > kijun))      buyScore++;

   if(!UseBBSignal       || close1 >= upper)                        sellScore++;
   if(!UseMAFilter       || fastMA < slowMA)                        sellScore++;
   if(!UseRSIFilter      || rsi >= RSI_SellLevel)                   sellScore++;
   if(!UseADXFilter      || (adx >= ADX_MinLevel && diM > diP))     sellScore++;
   if(!UseIchimokuFilter || (close0 < cBot && tenkan < kijun))      sellScore++;

   if(buyScore >= 3 && buyScore > sellScore)  return OP_BUY;
   if(sellScore >= 3 && sellScore > buyScore) return OP_SELL;
   return -1;
}

//+------------------------------------------------------------------+
//| Trailing Stop                                                    |
//+------------------------------------------------------------------+
void DoTrailingStop()
{
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol()||OrderMagicNumber()!=MagicNumber) continue;
      if(OrderType()==OP_BUY && Bid-OrderOpenPrice()>=TrailingStartPoints*Point)
      {
         double nsl=NormalizeDouble(Bid-TrailingStepPoints*Point,Digits);
         if(nsl>OrderStopLoss()+Point)
            OrderModify(OrderTicket(),OrderOpenPrice(),nsl,OrderTakeProfit(),0,clrAqua);
      }
      else if(OrderType()==OP_SELL && OrderOpenPrice()-Ask>=TrailingStartPoints*Point)
      {
         double nsl=NormalizeDouble(Ask+TrailingStepPoints*Point,Digits);
         if(OrderStopLoss()==0||nsl<OrderStopLoss()-Point)
            OrderModify(OrderTicket(),OrderOpenPrice(),nsl,OrderTakeProfit(),0,clrOrange);
      }
   }
}

//+------------------------------------------------------------------+
//| Basket TP                                                        |
//+------------------------------------------------------------------+
void CheckBasketTP()
{
   if(GetBasketProfit() >= AccountBalance()*BasketProfitPct/100.0)
   { Print("BasketTP hit. Closing."); CloseAll(); }
}

//+------------------------------------------------------------------+
//| Martingale                                                       |
//+------------------------------------------------------------------+
void TryMartinEntry()
{
   int dir=GetBasketDirection(); if(dir<0) return;
   int steps=CountOpen(); if(steps>=MaxMartinStep+1) return;
   double last=GetLastOpenPrice(dir); if(last<=0) return;
   bool go=false;
   if(dir==OP_BUY  && Bid<=last-GridStepPoints*Point) go=true;
   if(dir==OP_SELL && Ask>=last+GridStepPoints*Point)  go=true;
   if(!go||!CanOpenByTime()) return;
   OpenOrder(dir,NormalizeLot(BaseLots*MathPow(MartinMultiplier,steps)),"AXION MARTIN");
}

//+------------------------------------------------------------------+
//| Send Balance to Supabase                                         |
//+------------------------------------------------------------------+
void SendBalance()
{
   string account = IntegerToString((int)AccountNumber());
   string body = "{\"account_no\":\"" + account + "\","
               + "\"balance\":"  + DoubleToString(AccountBalance(),2) + ","
               + "\"equity\":"   + DoubleToString(AccountEquity(),2)  + ","
               + "\"profit\":"   + DoubleToString(AccountEquity()-AccountBalance(),2) + "}";

   string h = "Content-Type: application/json\r\n"
            + "apikey: " + SupabaseAnonKey + "\r\n"
            + "Authorization: Bearer " + SupabaseAnonKey + "\r\n"
            + "Prefer: return=minimal";

   char post[]; char res[]; string rh;
   StringToCharArray(body,post,0,StringLen(body));
   ArrayResize(post,StringLen(body));
   int r=WebRequest("POST",SupabaseURL+"/rest/v1/balance_logs",h,5000,post,res,rh);
   if(r==201) Print("Balance sent OK");
   else Print("Balance send failed HTTP=",r," Err=",GetLastError());
}

//+------------------------------------------------------------------+
//| OpenOrder                                                        |
//+------------------------------------------------------------------+
bool OpenOrder(int type,double lots,string comment)
{
   RefreshRates(); lots=NormalizeLot(lots);
   double price,sl,tp;
   if(type==OP_BUY) { price=Ask; sl=price-StopLossPoints*Point; tp=price+TakeProfitPoints*Point; }
   else if(type==OP_SELL) { price=Bid; sl=price+StopLossPoints*Point; tp=price-TakeProfitPoints*Point; }
   else return false;

   int t=OrderSend(Symbol(),type,lots,price,Slippage,
                   NormalizeDouble(sl,Digits),NormalizeDouble(tp,Digits),
                   comment,MagicNumber,0,type==OP_BUY?clrDodgerBlue:clrOrangeRed);
   if(t<0){ Print("OrderSend Err=",GetLastError()); return false; }
   lastTradeTime=TimeCurrent();
   Print("Opened ",comment," T=",t," Lots=",DoubleToString(lots,2));
   if(SendBalanceToServer) SendBalance();
   return true;
}

//+------------------------------------------------------------------+
//| Utilities                                                        |
//+------------------------------------------------------------------+
int CountOpen()
{ int n=0; for(int i=OrdersTotal()-1;i>=0;i--) if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) if(OrderSymbol()==Symbol()&&OrderMagicNumber()==MagicNumber) n++; return n; }

double GetBasketProfit()
{ double t=0; for(int i=OrdersTotal()-1;i>=0;i--) if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) if(OrderSymbol()==Symbol()&&OrderMagicNumber()==MagicNumber) t+=OrderProfit()+OrderSwap()+OrderCommission(); return t; }

int GetBasketDirection()
{ for(int i=OrdersTotal()-1;i>=0;i--) if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) if(OrderSymbol()==Symbol()&&OrderMagicNumber()==MagicNumber) if(OrderType()==OP_BUY||OrderType()==OP_SELL) return OrderType(); return -1; }

double GetLastOpenPrice(int dir)
{ datetime lt=0; double p=0; for(int i=OrdersTotal()-1;i>=0;i--) if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) if(OrderSymbol()==Symbol()&&OrderMagicNumber()==MagicNumber&&OrderType()==dir) if(OrderOpenTime()>lt){lt=OrderOpenTime();p=OrderOpenPrice();} return p; }

bool CanOpenByTime()
{ if(lastTradeTime==0) return true; return (int)(TimeCurrent()-lastTradeTime)>=MinMinutesBetweenTrades*60; }

double NormalizeLot(double lots)
{ double mn=MarketInfo(Symbol(),MODE_MINLOT),mx=MarketInfo(Symbol(),MODE_MAXLOT),st=MarketInfo(Symbol(),MODE_LOTSTEP); return NormalizeDouble(MathMax(mn,MathMin(mx,MathFloor(lots/st)*st)),2); }

void CloseAll()
{ for(int i=OrdersTotal()-1;i>=0;i--){ if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue; if(OrderSymbol()!=Symbol()||OrderMagicNumber()!=MagicNumber) continue; RefreshRates(); if(OrderType()==OP_BUY) OrderClose(OrderTicket(),OrderLots(),Bid,Slippage,clrWhite); if(OrderType()==OP_SELL) OrderClose(OrderTicket(),OrderLots(),Ask,Slippage,clrWhite); } if(SendBalanceToServer) SendBalance(); }
//+------------------------------------------------------------------+
