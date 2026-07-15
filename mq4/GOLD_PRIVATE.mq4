//+------------------------------------------------------------------+
//| GOLD_PRIVATE_Official_UI.mq4                                           |
//| DQL(Diplomat Quant Logic) by HERITAGE ASSET                      |
//| GOLD PRIVATE v9.1 — Official UI + Final Stop Safety                    |
//|                                                                  |
//| 거래 로직: GOLD_PRIVATE base logic (v1_6_Final) 완전 동일       |
//| v1.6 핵심:                                                        |
//|  - SellGridPoints = 300 (v1.3의 330에서 수정)                    |
//|  - MaxStepsPerSide = 99 (원본 설정 복원)                          |
//|  - BuyActualMinGridPoints 이중체크 제거                           |
//|  - StartupGate 제거 (단순화)                                      |
//|  - TPMode 0=포인트 / 1=달러 선택 가능                             |
//+------------------------------------------------------------------+
#property strict
#property copyright "made by gold_private"
#property version   "9.10"

//===================================================
// [기본]
//===================================================
extern string SET_00                  = "======= EA 설정 =======";
extern string EA_Name                 = "======= GOLD PRIVATE =======";
extern int    MagicNumber             = 123456;
extern string SET_01                  = "--- [1] 거래 방향 ---";
extern bool   AllowBuy                = true;
extern bool   AllowSell               = true;
extern bool   ShowDashboard           = true;
extern string SET_02                  = "--- [2] 초기 설정 ---";
extern double BaseLot                 = 0.01;
extern string SET_03                  = "--- [3] 수익 설정 ---";
extern int    BasketTPPoints          = 300;
extern int    TPMode                  = 0;        // 0=포인트 기준 / 1=달러 기준
extern double BasketTakeProfitDollars = 10.0;     // TPMode=1일 때 사용
extern string SET_04                  = "--- [4] 마틴게일 설정 ---";
extern double LotMultiplier           = 1.50;
extern int    GridPoints              = 300;
extern int    BuyGridPoints           = 300;      // 0이면 GridPoints 사용
extern int    SellGridPoints          = 300;      // 0이면 GridPoints 사용
extern int    MaxStepsPerSide         = 99;
extern string SET_TREND               = "--- [추세장 방어 - 공격형: 극단 추세만 차단] ---";
extern bool   UseTrendFilter          = true;     // 추세 필터 사용
extern int    TrendADXPeriod          = 14;       // 추세 판단 ADX 기간
extern double TrendADXLevel           = 55.0;     // 공격형: 55 (극단 폭주만 차단, 추세 수익 최대 보존)
extern double TrendDIGap              = 12.0;     // DI+/DI- 격차 (방향 확신 매우 클 때만)
extern bool   TrendBlockReverse       = true;     // 추세 반대방향 신규 마틴 추가 중단
extern int    MinSecondsBetweenAdds   = 5;
extern int    ReEntryDelaySeconds     = 0;
extern string SET_05                  = "--- [5] 청산 모드 ---";
extern bool   UseServerTP             = true;
extern double CloseProfitDollars      = 0.0;      // 전체 합산 수익($) 청산 / 0=미사용
extern double BasketStopLossDollars   = 0.0;
extern double DailyStopLossDollars    = 0.0;
extern double DailyTakeProfitDollars  = 0.0;
extern string SET_05A                 = "--- [5-A] 최종 종료 설정 ---";
extern double FinalTakeProfitDollars  = 0.0;      // EA 실행 이후 총손익이 이 금액 이상이면 전체 청산 후 정지 / 0=미사용
extern double FinalStopLossDollars    = 0.0;      // EA 실행 이후 총손익이 -이 금액 이하이면 전체 청산 후 정지 / 0=미사용
extern bool   CloseAllOnFinalStop     = true;     // 최종 목표/손절 도달 시 전체 포지션 청산
extern bool   StopEAAfterFinal        = true;     // 최종 목표/손절 도달 후 신규 진입 차단
extern bool   RemoveEAOnFinalStop     = false;    // true면 최종 종료 후 차트에서 EA 제거
extern bool   AlertOnFinalStop        = true;     // 최종 종료 알림
extern string SET_06                  = "--- [6] 시장분석 ---";
extern int    PulsePeriod             = 14;
extern int    FluxPeriod              = 14;
extern double PulseRangeLevel         = 25.0;
extern bool   UsePulseFluxFilter      = false;    // 복제 모드: false 권장
extern string SET_07                  = "--- [7] UI 설정 ---";
extern int    DashboardCorner         = 1;        // 0=좌상단 1=우상단 2=좌하단 3=우하단
extern int    DashboardX              = 14;       // 모서리에서 가로 여백(px)
extern int    DashboardY              = 14;       // 모서리에서 세로 여백(px)
extern int    DashboardFontBoost       = 2;        // 대시보드 글씨 확대값(기본 +2)
extern bool   StopButtonCloseSide     = false;    // BUY/SELL STOP 클릭 시 해당 방향 포지션도 함께 청산
extern int    MaxSpreadPoints         = 80;
extern int    SlippagePoints          = 5;
extern bool   StartBothSides          = true;
extern bool   UseEmergencyTouchClose  = true;
extern bool   SellGridUseAsk          = true;
extern bool   BuyGridUseAsk           = true;
extern bool   PrintDebug              = false;

//===================================================
// [8] AXION 라이선스 (변경 금지)
//===================================================
extern string _80_ = "=== [8] AXION 라이선스 (변경금지) ===";
extern string _81_ = "관리자페이지 등록 프로그램명과 일치해야 함";
extern string 프로그램명             = "GOLDRUN_EA";
extern string _82_ = "서버 주소 (변경금지)";
extern string 서버주소               = "https://wmvnearoursbmwjqwzww.supabase.co";
extern string _83_ = "인증키 (변경금지)";
extern string 인증키                 = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indtdm5lYXJvdXJzYm13anF3end3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgxNzQ5MjEsImV4cCI6MjA5Mzc1MDkyMX0.MS4iSGIvW4dBi3sd8J3baHLT4TlgUJS5lXwlhJdWYEY";
extern bool   SendBalance             = true;
extern int    SendBalanceMinutes      = 5;

//===================================================
// 내부 변수
//===================================================
datetime g_lastBuyAdd    = 0;
datetime g_lastSellAdd   = 0;
datetime g_lastBuyClose  = 0;
datetime g_lastSellClose = 0;
datetime g_dayStart      = 0;
double   g_dayStartEq    = 0;
double   g_sessionStartEq= 0;
bool     licenseOK       = false;
bool     licenseChecked  = false;   // 라이센스 체크 완료 여부
bool     riskAccepted    = false;   // 위험고지 동의 여부
string   licenseStatus   = "확인 중...";
bool     buyStopped      = false;
bool     sellStopped     = false;
bool     finalStopped    = false;
string   finalReason     = "";
datetime finalStopTime   = 0;
int      totalCycles     = 0;
double   g_todayPeakEq   = 0.0;   // 오늘 장중 최고 Equity
double   g_todayMaxMDD   = 0.0;   // 오늘 최대 MDD 금액
double   g_todayMaxMDDPct= 0.0;   // 오늘 최대 MDD 비율

string PFX       = "GLD_";
string BTN_BUY   = "GLD_BTN_BUY";
string BTN_SELL  = "GLD_BTN_SELL";
string BTN_CLOSE = "GLD_BTN_CLOSE";

color CLR_GOLD  = C'255,215,0';
color CLR_GOLD2 = C'160,120,8';
color CLR_GREEN = C'70,190,90';
color CLR_RED   = C'210,50,50';
color CLR_WHITE = C'230,224,205';
color CLR_GRAY  = C'150,136,96';
color CLR_BLUE  = C'70,130,210';
color CLR_DIM   = C'18,14,4';
color CLR_DARK  = C'6,5,2';

//+------------------------------------------------------------------+
//| 유틸리티 — v1.6 완전 동일                                         |
//+------------------------------------------------------------------+
void Dbg(string s){ if(PrintDebug) Print("[GOLD PRIVATE] ",s); }
double Pt(){ return MarketInfo(Symbol(),MODE_POINT); }
int    Dig(){ return (int)MarketInfo(Symbol(),MODE_DIGITS); }
double NPrice(double p){ return NormalizeDouble(p,Dig()); }

double NormalizeLotDown(double lots)
{
   double mn=MarketInfo(Symbol(),MODE_MINLOT);
   double mx=MarketInfo(Symbol(),MODE_MAXLOT);
   double st=MarketInfo(Symbol(),MODE_LOTSTEP);
   if(st<=0) st=0.01;
   lots=MathMax(mn,MathMin(mx,lots));
   return NormalizeDouble(MathFloor(lots/st+0.0000001)*st,2);
}

bool IsOurOrder(int typeFilter=-1)
{
   if(OrderSymbol()!=Symbol()) return false;
   if(OrderMagicNumber()!=MagicNumber) return false;
   if(typeFilter>=0&&OrderType()!=typeFilter) return false;
   return true;
}

int CountSide(int type)
{
   int c=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   { if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue; if(IsOurOrder(type)) c++; }
   return c;
}

double TotalLotsSide(int type)
{
   double t=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   { if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue; if(IsOurOrder(type)) t+=OrderLots(); }
   return t;
}

double BasketProfitSide(int type)
{
   double p=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   { if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue; if(IsOurOrder(type)) p+=OrderProfit()+OrderSwap()+OrderCommission(); }
   return p;
}

double BasketProfitAll(){ return BasketProfitSide(OP_BUY)+BasketProfitSide(OP_SELL); }

double WeightedAvgSide(int type)
{
   double val=0,lots=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   { if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue; if(!IsOurOrder(type)) continue; val+=OrderOpenPrice()*OrderLots(); lots+=OrderLots(); }
   return lots>0?val/lots:0;
}

double LastOpenPriceSide(int type)
{
   datetime lt=0;double price=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   { if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue; if(!IsOurOrder(type)) continue; if(OrderOpenTime()>lt){lt=OrderOpenTime();price=OrderOpenPrice();} }
   return price;
}

double NextLotSide(int type)
{ return NormalizeLotDown(BaseLot*MathPow(LotMultiplier,CountSide(type))); }

double BasketTPPrice(int type)
{
   int count=CountSide(type); if(count<=0) return 0;
   double avg=WeightedAvgSide(type); if(avg<=0) return 0;
   double offset=(BasketTPPoints/(double)count)*Pt();
   if(type==OP_BUY)  return NPrice(avg+offset);
   if(type==OP_SELL) return NPrice(avg-offset);
   return 0;
}

bool ModifyOrderTP(int ticket, double newTP)
{
   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES)) return false;
   if(MathAbs(OrderTakeProfit()-newTP)<Pt()*0.5) return true;
   bool ok=OrderModify(OrderTicket(),OrderOpenPrice(),OrderStopLoss(),newTP,0,clrNONE);
   if(!ok) Dbg("ModifyTP Err="+IntegerToString(GetLastError()));
   return ok;
}

void SyncBasketTP(int type)
{
   if(!UseServerTP) return;
   if(TPMode==1) return;
   int count=CountSide(type); if(count<=0) return;
   double tp=BasketTPPrice(type); if(tp<=0) return;
   for(int i=OrdersTotal()-1;i>=0;i--)
   { if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue; if(!IsOurOrder(type)) continue; ModifyOrderTP(OrderTicket(),tp); }
}

bool CloseSide(int type)
{
   bool allOk=true;
   RefreshRates();
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(!IsOurOrder(type)) continue;
      double price=(type==OP_BUY)?Bid:Ask;
      color  clr  =(type==OP_BUY)?clrBlue:clrRed;
      bool ok=OrderClose(OrderTicket(),OrderLots(),price,SlippagePoints,clr);
      if(!ok){ Dbg("Close Err="+IntegerToString(GetLastError())); allOk=false; }
   }
   if(type==OP_BUY){ g_lastBuyClose=TimeCurrent(); g_lastBuyAdd=TimeCurrent(); }
   else            { g_lastSellClose=TimeCurrent();g_lastSellAdd=TimeCurrent(); }
   totalCycles++;
   if(SendBalance) SendBalanceToSupabase();
   return allOk;
}

bool SendMarketOrder(int type, double lots, string comment)
{
   RefreshRates();
   double price=(type==OP_BUY)?Ask:Bid;
   color  clr  =(type==OP_BUY)?clrBlue:clrRed;
   int ticket=OrderSend(Symbol(),type,lots,price,SlippagePoints,0,0,comment,MagicNumber,0,clr);
   if(ticket<0){ Dbg("Send Err="+IntegerToString(GetLastError())); return false; }
   if(type==OP_BUY)  g_lastBuyAdd=TimeCurrent();
   if(type==OP_SELL) g_lastSellAdd=TimeCurrent();
   Dbg("OK ticket="+IntegerToString(ticket)+" "+comment+" lots="+DoubleToString(lots,2));
   SyncBasketTP(type);
   return true;
}

void ResetDailyIfNeeded()
{
   datetime d=iTime(Symbol(),PERIOD_D1,0);
   if(d!=g_dayStart)
   {
      g_dayStart      = d;
      g_dayStartEq    = AccountEquity();
      g_todayPeakEq   = AccountEquity();
      g_todayMaxMDD   = 0.0;
      g_todayMaxMDDPct= 0.0;
   }
}

bool SpreadOK()
{ return MarketInfo(Symbol(),MODE_SPREAD)<=MaxSpreadPoints; }


double GetHistoryProfit(datetime from, datetime to)
{
   double t=0;
   for(int i=OrdersHistoryTotal()-1;i>=0;i--)
   { if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)) continue;
     if(OrderSymbol()!=Symbol()||OrderMagicNumber()!=MagicNumber) continue;
     datetime ct=OrderCloseTime();
     if(ct>=from&&ct<to) t+=OrderProfit()+OrderSwap()+OrderCommission(); }
   return t;
}

double GetHistoryLots(datetime from, datetime to)
{
   double t=0; int c=0;
   for(int i=OrdersHistoryTotal()-1;i>=0;i--)
   { if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)) continue;
     if(OrderSymbol()!=Symbol()||OrderMagicNumber()!=MagicNumber) continue;
     datetime ct=OrderCloseTime();
     if(ct>=from&&ct<to){ t+=OrderLots(); c++; } }
   return c>0?t/c:0;
}

double SessionPnL()
{
   if(g_sessionStartEq<=0) return(0.0);
   return(AccountEquity()-g_sessionStartEq);
}

void UpdateTodayMDD()
{
   double eq = AccountEquity();
   if(g_todayPeakEq <= 0.0) g_todayPeakEq = eq;

   if(eq > g_todayPeakEq)
      g_todayPeakEq = eq;

   double dd = g_todayPeakEq - eq;
   if(dd > g_todayMaxMDD)
   {
      g_todayMaxMDD = dd;
      g_todayMaxMDDPct = (g_todayPeakEq > 0.0) ? (dd / g_todayPeakEq * 100.0) : 0.0;
   }
}

string MDDStr()
{
   if(g_todayMaxMDD <= 0.0) return "$0.00 (0.00%)";
   return "-$" + DoubleToString(g_todayMaxMDD,2) + " (" + DoubleToString(g_todayMaxMDDPct,2) + "%)";
}

void TriggerFinalStop(string reason)
{
   if(finalStopped) return;
   finalStopped  = true;
   finalReason   = reason;
   finalStopTime = TimeCurrent();
   if(CloseAllOnFinalStop){ CloseSide(OP_BUY); CloseSide(OP_SELL); }
   if(StopEAAfterFinal){ buyStopped=true; sellStopped=true; }
   if(AlertOnFinalStop)
      Alert("GOLD PRIVATE STOP: ",reason," / Session P&L=",DoubleToString(SessionPnL(),2));
   Print("GOLD PRIVATE FINAL STOP: ",reason,
         " SessionPnL=",DoubleToString(SessionPnL(),2));
   if(RemoveEAOnFinalStop) ExpertRemove();
}

bool CheckFinalStop()
{
   if(finalStopped) return(true);
   double sPnL=SessionPnL();
   double dPnL=AccountEquity()-g_dayStartEq;
   if(FinalTakeProfitDollars>0&&sPnL>=FinalTakeProfitDollars)
   { TriggerFinalStop("FINAL TAKE PROFIT"); return(true); }
   if(FinalStopLossDollars>0&&sPnL<=-FinalStopLossDollars)
   { TriggerFinalStop("FINAL STOP LOSS"); return(true); }
   if(DailyTakeProfitDollars>0&&dPnL>=DailyTakeProfitDollars)
   { TriggerFinalStop("DAILY TAKE PROFIT"); return(true); }
   if(DailyStopLossDollars>0&&dPnL<=-DailyStopLossDollars)
   { TriggerFinalStop("DAILY STOP LOSS"); return(true); }
   return(false);
}

//+------------------------------------------------------------------+
//| 거래 로직 — v1.6 완전 동일                                        |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| 추세장 방어 — 극단 추세 시 역방향 마틴 차단 (공격형 C안)          |
//+------------------------------------------------------------------+
// 추세 방향: 1=상승추세, -1=하락추세, 0=추세없음(횡보)
int TrendDirection()
{
   if(!UseTrendFilter) return 0;
   double adx = iADX(Symbol(),PERIOD_CURRENT,TrendADXPeriod,PRICE_CLOSE,MODE_MAIN,0);
   double diP = iADX(Symbol(),PERIOD_CURRENT,TrendADXPeriod,PRICE_CLOSE,MODE_PLUSDI,0);
   double diM = iADX(Symbol(),PERIOD_CURRENT,TrendADXPeriod,PRICE_CLOSE,MODE_MINUSDI,0);
   if(adx < TrendADXLevel) return 0;                  // 추세 약함 → 양방향 정상
   if(diP > diM + TrendDIGap) return 1;               // 상승 추세
   if(diM > diP + TrendDIGap) return -1;              // 하락 추세
   return 0;
}

// 해당 방향 신규 마틴이 추세 필터에 막히는지
bool ReverseMartinBlocked(int type)
{
   if(!UseTrendFilter || !TrendBlockReverse) return false;
   int dir = TrendDirection();
   if(dir == 1  && type == OP_SELL) return true;      // 상승추세 → 매도 마틴 차단
   if(dir == -1 && type == OP_BUY)  return true;      // 하락추세 → 매수 마틴 차단
   return false;
}

void ManageBuy()
{
   if(finalStopped) return;
   if(!AllowBuy||buyStopped) return;
   int count=CountSide(OP_BUY);
   if(count<=0)
   {
      if(ReEntryDelaySeconds>0&&g_lastBuyClose>0&&(TimeCurrent()-g_lastBuyClose)<ReEntryDelaySeconds) return;
      SendMarketOrder(OP_BUY,NormalizeLotDown(BaseLot),"InitialBuy");
      return;
   }
   SyncBasketTP(OP_BUY);
   if(count>=MaxStepsPerSide) return;
   if(g_lastBuyAdd>0&&(TimeCurrent()-g_lastBuyAdd)<MinSecondsBetweenAdds) return;
   if(ReverseMartinBlocked(OP_BUY)) return;   // [추세 방어] 하락 추세 시 매수 마틴 중단
   double lastPrice=LastOpenPriceSide(OP_BUY); if(lastPrice<=0) return;
   double buyCheckPrice=BuyGridUseAsk?Ask:Bid;
   int    buyGrid=(BuyGridPoints>0?BuyGridPoints:GridPoints);
   double adversePoints=(lastPrice-buyCheckPrice)/Pt();
   if(adversePoints>=buyGrid)
      SendMarketOrder(OP_BUY,NextLotSide(OP_BUY),"MartinBuy");
}

void ManageSell()
{
   if(finalStopped) return;
   if(!AllowSell||sellStopped) return;
   int count=CountSide(OP_SELL);
   if(count<=0)
   {
      if(ReEntryDelaySeconds>0&&g_lastSellClose>0&&(TimeCurrent()-g_lastSellClose)<ReEntryDelaySeconds) return;
      SendMarketOrder(OP_SELL,NormalizeLotDown(BaseLot),"InitialSell");
      return;
   }
   SyncBasketTP(OP_SELL);
   if(count>=MaxStepsPerSide) return;
   if(g_lastSellAdd>0&&(TimeCurrent()-g_lastSellAdd)<MinSecondsBetweenAdds) return;
   if(ReverseMartinBlocked(OP_SELL)) return;   // [추세 방어] 상승 추세 시 매도 마틴 중단
   double lastPrice=LastOpenPriceSide(OP_SELL); if(lastPrice<=0) return;
   double sellCheckPrice=SellGridUseAsk?Ask:Bid;
   int    sellGrid=(SellGridPoints>0?SellGridPoints:GridPoints);
   double adversePoints=(sellCheckPrice-lastPrice)/Pt();
   if(adversePoints>=sellGrid)
      SendMarketOrder(OP_SELL,NextLotSide(OP_SELL),"MartinSell");
}

void EmergencyTouchClose()
{
   if(!UseEmergencyTouchClose) return;
   if(CountSide(OP_BUY)>0){ double btp=BasketTPPrice(OP_BUY); if(btp>0&&Bid>=btp){ Dbg("Emergency BUY close"); CloseSide(OP_BUY); } }
   if(CountSide(OP_SELL)>0){ double stp=BasketTPPrice(OP_SELL); if(stp>0&&Ask<=stp){ Dbg("Emergency SELL close"); CloseSide(OP_SELL); } }
}

void RiskChecks()
{
   if(TPMode==1&&BasketTakeProfitDollars>0)
   {
      if(BasketProfitSide(OP_BUY)>=BasketTakeProfitDollars){ Dbg("BUY dollar TP"); CloseSide(OP_BUY); }
      if(BasketProfitSide(OP_SELL)>=BasketTakeProfitDollars){ Dbg("SELL dollar TP"); CloseSide(OP_SELL); }
   }

   if(CloseProfitDollars>0&&BasketProfitAll()>=CloseProfitDollars)
   {
      CloseSide(OP_BUY);
      CloseSide(OP_SELL);
      return;
   }

   if(BasketStopLossDollars>0&&BasketProfitAll()<=-BasketStopLossDollars)
   {
      CloseSide(OP_BUY);
      CloseSide(OP_SELL);
      return;
   }

   CheckFinalStop();
}

void ProcessTrading()
{
   RefreshRates();
   ResetDailyIfNeeded();
   UpdateTodayMDD();
   DrawDashboard();

   // 목표수익/최종손절 도달 후에는 신규 진입 금지
   if(CheckFinalStop()) return;

   if(!IsTradeAllowed()) return;
   if(!SpreadOK()) return;

   RiskChecks();
   if(finalStopped) return;

   EmergencyTouchClose();
   if(finalStopped) return;

   if(StartBothSides)
   {
      ManageBuy();
      ManageSell();
   }
   else
   {
      if(AllowBuy)  ManageBuy();
      if(AllowSell) ManageSell();
   }
}

//+------------------------------------------------------------------+
//| AXION 라이선스                                                    |
//+------------------------------------------------------------------+
bool CheckLicense()
{
   string _acc=IntegerToString((int)AccountNumber());
   string _pg=프로그램명;
   StringReplace(_pg," ","%20"); StringReplace(_pg,"(","%28"); StringReplace(_pg,")","%29");
   string _url=서버주소+"/rest/v1/customers?account_no=eq."+_acc+"&program_name=eq."+_pg+"&is_active=eq.true&select=expires_at";
   string _rh="apikey: "+인증키+"\r\nAuthorization: Bearer "+인증키;
   char _p[];char _r[];string _rhs;
   int _http=WebRequest("GET",_url,_rh,8000,_p,_r,_rhs);
   string _body=CharArrayToString(_r);
   Print("GOLD PRIVATE License HTTP=",_http," body=",_body);
   if(_http!=200||_body=="[]"||StringFind(_body,"expires_at")<0)
   { licenseStatus="미등록 계좌 (HTTP="+IntegerToString(_http)+")"; return false; }
   int _s=StringFind(_body,"\"expires_at\":\"")+14;
   string _exp=StringSubstr(_body,_s,10); StringReplace(_exp,"-",".");
   if(_exp<TimeToString(TimeCurrent(),TIME_DATE))
   { licenseStatus="만료됨 ("+_exp+")"; return false; }
   licenseStatus="정상 ("+_exp+"까지)";
   return true;
}

void SendBalanceToSupabase()
{
   string acc=IntegerToString((int)AccountNumber());
   string body="{\"account_no\":\""+acc+"\",\"balance\":"+DoubleToString(AccountBalance(),2)+",\"equity\":"+DoubleToString(AccountEquity(),2)+",\"profit\":"+DoubleToString(AccountEquity()-AccountBalance(),2)+"}";
   string h="Content-Type: application/json\r\napikey: "+인증키+"\r\nAuthorization: Bearer "+인증키+"\r\nPrefer: return=minimal";
   char p[];char r[];string rh;
   StringToCharArray(body,p,0,StringLen(body));ArrayResize(p,StringLen(body));
   WebRequest("POST",서버주소+"/rest/v1/balance_logs",h,5000,p,r,rh);
}

//+------------------------------------------------------------------+
//| UI / 버튼 시스템 (우측 하단 고정, 버튼 폴링 방식)
//+------------------------------------------------------------------+

// ── 패널 좌표계 ──────────────────────────────────────────────
// 내부 좌표 (px, py): 패널 좌상단 기준
// DashboardCorner: 0=CORNER_LEFT_UPPER  1=CORNER_RIGHT_UPPER
//                  2=CORNER_LEFT_LOWER  3=CORNER_RIGHT_LOWER
// 우측 코너일 때: XDISTANCE = (가로여백+패널너비) - px
// 좌측 코너일 때: XDISTANCE = 가로여백 + px
// 상단 코너일 때: YDISTANCE = 세로여백 + py
// 하단 코너일 때: YDISTANCE = (세로여백+패널높이) - py
int PW = 300;
int PH = 352;   // GOLD PRIVATE 미니멀 레이아웃

int GetCorner() { return DashboardCorner; }

int CX(int px)
{
   bool rightSide = (DashboardCorner==1 || DashboardCorner==3);
   if(rightSide) return DashboardX + PW - px;
   return DashboardX + px;
}

int CY(int py)
{
   bool bottomSide = (DashboardCorner==2 || DashboardCorner==3);
   if(bottomSide) return DashboardY + PH - py;
   return DashboardY + py;
}

// 버튼 X 좌표 (idx: 0=왼쪽 1=가운데 2=오른쪽). 좌/우 코너 모두 균등 정렬
int BtnX(int idx, int bw, int gap, int margin)
{
   // 카드(R함수)와 동일한 CX 좌표계 사용 → 패널 안에 정확히 정렬
   int leftPx = margin + idx*(bw+gap);     // 패널 좌측 기준 버튼 왼쪽 X
   return CX(leftPx);                       // CX가 코너에 맞게 자동 변환
}

void L(string id, string txt, int px, int py, int sz, color clr, string font="Arial Bold")
{
   string n = PFX + id;
   if(ObjectFind(0,n)<0)
   {
      ObjectCreate(0,n,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,n,OBJPROP_BACK,      false);
   }
   ObjectSetInteger(0,n,OBJPROP_CORNER,    GetCorner());
   ObjectSetString (0,n,OBJPROP_TEXT,      txt);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE, CX(px));
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE, CY(py));
   int finalSize = sz + DashboardFontBoost;
   if(finalSize < 6) finalSize = 6;
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,  finalSize);
   ObjectSetInteger(0,n,OBJPROP_COLOR,     clr);
   ObjectSetString (0,n,OBJPROP_FONT,      font);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,    1);   // 라벨: 배경 위
}

void R(string id, int px, int py, int w, int h, color bg, color border)
{
   string n = PFX+"R_"+id;
   if(ObjectFind(0,n)<0)
   {
      ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,n,OBJPROP_BACK,      false);  // 불투명 → 다크 패널/골드 프레임 항상 표시
   }
   ObjectSetInteger(0,n,OBJPROP_CORNER,    GetCorner());
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE, CX(px));
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE, CY(py));
   ObjectSetInteger(0,n,OBJPROP_XSIZE,     w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,     h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,   bg);
   ObjectSetInteger(0,n,OBJPROP_COLOR,     border);
   ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,0);   // 배경/프레임: 텍스트보다 아래
}

// 초대장식 플로리시 구분선 (좌선—◆—우선)
void Flourish(string id, int py, color lineClr, color diaClr)
{
   int cx = PW/2;
   R(id+"L", 34,     py, (cx-34)-10, 1, lineClr, lineClr);
   R(id+"R", cx+10,  py, (PW-34)-(cx+10), 1, lineClr, lineClr);
   LC(id+"D", "◆", cx, py, 6, diaClr, "Arial");
}

// 구분선
void HR(string id, int py, color clr)
{
   R(id, 0, py, PW+2, 1, clr, clr);
}

// 중앙정렬 라벨 (cx_px = 패널 좌측 기준 중심 X)
void LC(string id, string txt, int cx_px, int py, int sz, color clr, string font="Arial Bold")
{
   string n = PFX + id;
   if(ObjectFind(0,n)<0)
   {
      ObjectCreate(0,n,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,n,OBJPROP_BACK,      false);
   }
   ObjectSetInteger(0,n,OBJPROP_CORNER,    GetCorner());
   ObjectSetInteger(0,n,OBJPROP_ANCHOR,    ANCHOR_CENTER);
   ObjectSetString (0,n,OBJPROP_TEXT,      txt);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE, CX(cx_px));
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE, CY(py));
   int finalSize = sz + DashboardFontBoost;
   if(finalSize < 6) finalSize = 6;
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,  finalSize);
   ObjectSetInteger(0,n,OBJPROP_COLOR,     clr);
   ObjectSetString (0,n,OBJPROP_FONT,      font);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,    1);
}

// 콤마 + 소수 2자리 ($2,068.15 형태)
string FmtMoney2(double v)
{
   bool neg = v<0; v=MathAbs(v);
   string ip = DoubleToString(MathFloor(v),0);
   int len=StringLen(ip); string out="";
   for(int i=0;i<len;i++){ if(i>0 && (len-i)%3==0) out+=","; out+=StringSubstr(ip,i,1); }
   int cents=(int)MathRound((v-MathFloor(v))*100.0);
   string cs=IntegerToString(cents); if(StringLen(cs)<2) cs="0"+cs;
   return (neg?"-":"")+out+"."+cs;
}


// 천단위 콤마 포맷 ($410,369 형태)
string FmtK(double v)
{
   string s = DoubleToString(MathAbs(v), 0);
   int len = StringLen(s);
   string out = "";
   for(int i=0; i<len; i++)
   {
      if(i>0 && (len-i)%3==0) out += ",";
      out += StringSubstr(s, i, 1);
   }
   return (v<0?"-":"") + out;
}

string MoneyStr(double v)
{
   return (v>=0 ? "+$" : "-$") + DoubleToString(MathAbs(v),2);
}
color MoneyClr(double v) { return v>=0 ? CLR_GREEN : CLR_RED; }

//--- 버튼 생성 (OnInit에서 한 번만 호출)
void CreateButtons()
{
   int M2  = 14;   // 카드와 동일한 좌우 여백
   int gap = 6;    // 버튼 간격
   int bw  = (PW - M2*2 - gap*2) / 3;  // 카드 폭에 맞춘 버튼 너비
   int bh  = 34;   // 버튼 높이

   // 버튼 Y 위치: 패널 하단 (미니멀 레이아웃)
   int btnY = CY(PH - 40);

   // SELL STOP (왼쪽)
   if(ObjectFind(0,BTN_SELL)<0) ObjectCreate(0,BTN_SELL,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,BTN_SELL,OBJPROP_CORNER,    GetCorner());
   ObjectSetInteger(0,BTN_SELL,OBJPROP_XDISTANCE, BtnX(0, bw, gap, M2));
   ObjectSetInteger(0,BTN_SELL,OBJPROP_YDISTANCE, btnY);
   ObjectSetInteger(0,BTN_SELL,OBJPROP_XSIZE,     bw);
   ObjectSetInteger(0,BTN_SELL,OBJPROP_YSIZE,     bh);
   ObjectSetString (0,BTN_SELL,OBJPROP_FONT,      "Segoe UI Semibold");
   ObjectSetInteger(0,BTN_SELL,OBJPROP_FONTSIZE,  11);
   ObjectSetInteger(0,BTN_SELL,OBJPROP_COLOR,     clrWhite);
   ObjectSetInteger(0,BTN_SELL,OBJPROP_STATE,     false);
   ObjectSetInteger(0,BTN_SELL,OBJPROP_ZORDER,    100);
   ObjectSetInteger(0,BTN_SELL,OBJPROP_BACK,      false);

   // BUY STOP (가운데)
   if(ObjectFind(0,BTN_BUY)<0) ObjectCreate(0,BTN_BUY,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,BTN_BUY,OBJPROP_CORNER,    GetCorner());
   ObjectSetInteger(0,BTN_BUY,OBJPROP_XDISTANCE, BtnX(1, bw, gap, M2));
   ObjectSetInteger(0,BTN_BUY,OBJPROP_YDISTANCE, btnY);
   ObjectSetInteger(0,BTN_BUY,OBJPROP_XSIZE,     bw);
   ObjectSetInteger(0,BTN_BUY,OBJPROP_YSIZE,     bh);
   ObjectSetString (0,BTN_BUY,OBJPROP_FONT,      "Segoe UI Semibold");
   ObjectSetInteger(0,BTN_BUY,OBJPROP_FONTSIZE,  11);
   ObjectSetInteger(0,BTN_BUY,OBJPROP_COLOR,     clrWhite);
   ObjectSetInteger(0,BTN_BUY,OBJPROP_STATE,     false);
   ObjectSetInteger(0,BTN_BUY,OBJPROP_ZORDER,    100);
   ObjectSetInteger(0,BTN_BUY,OBJPROP_BACK,      false);

   // CLOSE ALL (오른쪽)
   if(ObjectFind(0,BTN_CLOSE)<0) ObjectCreate(0,BTN_CLOSE,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,BTN_CLOSE,OBJPROP_CORNER,    GetCorner());
   ObjectSetInteger(0,BTN_CLOSE,OBJPROP_XDISTANCE, BtnX(2, bw, gap, M2));
   ObjectSetInteger(0,BTN_CLOSE,OBJPROP_YDISTANCE, btnY);
   ObjectSetInteger(0,BTN_CLOSE,OBJPROP_XSIZE,     bw);
   ObjectSetInteger(0,BTN_CLOSE,OBJPROP_YSIZE,     bh);
   ObjectSetString (0,BTN_CLOSE,OBJPROP_FONT,      "Segoe UI Semibold");
   ObjectSetInteger(0,BTN_CLOSE,OBJPROP_FONTSIZE,  11);
   ObjectSetInteger(0,BTN_CLOSE,OBJPROP_COLOR,     clrWhite);
   ObjectSetInteger(0,BTN_CLOSE,OBJPROP_STATE,     false);
   ObjectSetInteger(0,BTN_CLOSE,OBJPROP_ZORDER,    100);
   ObjectSetInteger(0,BTN_CLOSE,OBJPROP_BACK,      false);

   RefreshButtonLabels();
   ChartRedraw(0);
}

void RefreshButtonLabels()
{
   // SELL STOP (딥 레드)
   if(ObjectFind(0,BTN_SELL)>=0)
   {
      string t  = finalStopped ? "STOPPED" : (sellStopped ? "SELL  ON" : "SELL STOP");
      color  bg = finalStopped ? C'40,20,22' : (sellStopped ? C'40,62,44' : C'122,21,24');
      ObjectSetString (0,BTN_SELL,OBJPROP_TEXT,    t);
      ObjectSetInteger(0,BTN_SELL,OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0,BTN_SELL,OBJPROP_COLOR,   C'243,217,201');
   }
   // BUY STOP (다크 + 골드 글씨)
   if(ObjectFind(0,BTN_BUY)>=0)
   {
      string t  = finalStopped ? "STOPPED" : (buyStopped ? "BUY   ON" : "BUY  STOP");
      color  bg = finalStopped ? C'40,20,22' : (buyStopped ? C'40,62,44' : C'20,18,16');
      color  fg = (finalStopped||buyStopped) ? C'243,217,201' : C'217,180,90';
      ObjectSetString (0,BTN_BUY,OBJPROP_TEXT,    t);
      ObjectSetInteger(0,BTN_BUY,OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0,BTN_BUY,OBJPROP_COLOR,   fg);
   }
   // CLOSE ALL (다크 루비)
   if(ObjectFind(0,BTN_CLOSE)>=0)
   {
      string t  = finalStopped ? "CLOSED" : "CLOSE ALL";
      color  bg = finalStopped ? C'40,18,18' : C'74,15,16';
      ObjectSetString (0,BTN_CLOSE,OBJPROP_TEXT,    t);
      ObjectSetInteger(0,BTN_CLOSE,OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0,BTN_CLOSE,OBJPROP_COLOR,   C'232,201,176');
   }
   ChartRedraw(0);
}

// 매 틱/타이머마다 버튼 눌림 상태 폴링
void PollButtons()
{
   // SELL STOP
   if(ObjectFind(0,BTN_SELL)>=0 && (bool)ObjectGetInteger(0,BTN_SELL,OBJPROP_STATE))
   {
      ObjectSetInteger(0,BTN_SELL,OBJPROP_STATE,false);
      if(!finalStopped)
      {
         sellStopped = !sellStopped;
         Print("GOLD PRIVATE: SELL ", sellStopped?"STOPPED":"RESUMED");
      }
      RefreshButtonLabels();
   }
   // BUY STOP
   if(ObjectFind(0,BTN_BUY)>=0 && (bool)ObjectGetInteger(0,BTN_BUY,OBJPROP_STATE))
   {
      ObjectSetInteger(0,BTN_BUY,OBJPROP_STATE,false);
      if(!finalStopped)
      {
         buyStopped = !buyStopped;
         Print("GOLD PRIVATE: BUY ", buyStopped?"STOPPED":"RESUMED");
      }
      RefreshButtonLabels();
   }
   // CLOSE ALL
   if(ObjectFind(0,BTN_CLOSE)>=0 && (bool)ObjectGetInteger(0,BTN_CLOSE,OBJPROP_STATE))
   {
      ObjectSetInteger(0,BTN_CLOSE,OBJPROP_STATE,false);
      if(!finalStopped)
      {
         Print("GOLD PRIVATE: CLOSE ALL 실행");
         CloseSide(OP_BUY);
         CloseSide(OP_SELL);
         buyStopped   = true;
         sellStopped  = true;
         finalStopped = true;
         finalReason  = "MANUAL CLOSE ALL";
         finalStopTime= TimeCurrent();
         if(AlertOnFinalStop) Alert("GOLD PRIVATE: 전체 청산 완료. 신규 진입 중단.");
      }
      RefreshButtonLabels();
   }
}

void DeleteAllObjects()
{
   int total=ObjectsTotal(0,0,-1);
   for(int i=total-1;i>=0;i--)
   {
      string n=ObjectName(0,i,0,-1);
      if(StringFind(n,PFX)==0) ObjectDelete(0,n);
   }
   ObjectDelete(0,BTN_BUY);
   ObjectDelete(0,BTN_SELL);
   ObjectDelete(0,BTN_CLOSE);
}

void OnChartEvent(const int id,const long &lp,const double &dp,const string &sp)
{
   PollButtons(); // 클릭 이벤트에서도 즉시 폴링
}

//+------------------------------------------------------------------+
//| DrawDashboard — 위에서 아래로 깔끔하게 정렬
//+------------------------------------------------------------------+
void DrawDashboard()
{
   if(!ShowDashboard){ Comment(""); return; }
   UpdateTodayMDD();

   // ─── 데이터 수집 ───────────────────────────────────
   double equity  = AccountEquity();
   double balance = AccountBalance();
   double dayPnL  = equity - g_dayStartEq;
   double dayPct  = balance>0 ? dayPnL/balance*100.0 : 0;

   int    bc = CountSide(OP_BUY);
   int    sc = CountSide(OP_SELL);
   double bFL = BasketProfitSide(OP_BUY);
   double sFL = BasketProfitSide(OP_SELL);
   double tFL = bFL + sFL;                       // 현재 플로팅 손익
   double curPct = balance>0 ? tFL/balance*100.0 : 0;

   // ─── VIP 팔레트 ───────────────────────────────────
   color DARK   = C'11,9,10';
   color GOLD   = C'217,180,90';
   color GOLDL  = C'138,111,46';
   color REDBAR = C'139,20,22';
   color REDLN  = C'74,32,32';
   color REDDIA = C'138,53,53';
   color CREAM  = C'243,236,218';
   color LBL    = C'154,143,116';
   color GRN    = C'111,191,134';
   color REDV   = C'224,115,106';

   string F  = "Segoe UI";
   string FB = "Segoe UI Semibold";

   int CXc = PW/2;
   int CL  = (int)(PW*0.34);
   int CR  = (int)(PW*0.66);

   // ── 다크 패널 + 골드 프레임 + 안쪽 레드 프레임 + 상단 레드바 ──
   R("panel",  0, 0, PW,   PH-40, DARK,   GOLD);
   R("inset",  3, 3, PW-6, PH-46, DARK,   REDLN);
   R("accent", 0, 0, PW,   3,     REDBAR, REDBAR);

   // ── [1] 타이틀 ──
   LC("T1","Private", CXc, 26, 16, GOLD, FB);
   Flourish("fl0", 46, GOLDL, GOLD);

   // ── [2] BALANCE ──
   LC("BLBL","BALANCE", CXc, 62, 7, LBL, F);
   LC("BVAL","$"+FmtMoney2(balance), CXc, 81, 15, CREAM, FB);
   string sub = (dayPnL>=0?"+$":"-$")+DoubleToString(MathAbs(dayPnL),2)
              + "   ·   " + (dayPct>=0?"+":"")+DoubleToString(dayPct,2)+"%"
              + "   ·   Monthly";
   LC("BSUB", sub, CXc, 101, 7, LBL, F);

   Flourish("fl1", 120, REDLN, REDDIA);

   // ── [3] CURRENT PnL ──
   LC("CPV", (curPct>=0?"+":"")+DoubleToString(curPct,1)+"%", CXc, 143, 19,
      tFL>=0 ? CREAM : REDV, FB);
   LC("CPL","CURRENT PnL", CXc, 168, 7, LBL, F);

   Flourish("fl2", 186, REDLN, REDDIA);

   // ── [4] ORDERS ──
   LC("OBV", IntegerToString(bc), CL, 206, 13, GOLD, FB);
   LC("OBL","BUY",  CL, 226, 7, LBL, F);
   LC("OSEP","|",   CXc, 210, 12, REDLN, F);
   LC("OSV", IntegerToString(sc), CR, 206, 13, REDV, FB);
   LC("OSL","SELL", CR, 226, 7, LBL, F);
   LC("OLBL","ORDERS", CXc, 244, 7, LBL, F);

   Flourish("fl3", 262, REDLN, REDDIA);

   // ── [5] 상태 ──
   datetime lastAdd = (g_lastBuyAdd>g_lastSellAdd)?g_lastBuyAdd:g_lastSellAdd;
   bool cooling = (MinSecondsBetweenAdds>0 && lastAdd>0
                   && (TimeCurrent()-lastAdd) < MinSecondsBetweenAdds);
   string w1 = cooling ? "COOLING" : "ACTIVE";
   color  c1 = cooling ? GOLD : GRN;

   string w2; color c2;
   if(!licenseOK)             { w2="NO LICENSE"; c2=REDV; }
   else if(finalStopped)      { w2="STOPPED";    c2=REDV; }
   else if(!riskAccepted)     { w2="WAIT";       c2=LBL;  }
   else                       { w2="READY";      c2=GRN;  }

   LC("ST1", w1, (int)(PW*0.30), 282, 9, c1, FB);
   LC("ST2", w2, (int)(PW*0.70), 282, 9, c2, FB);

   // ── 버튼 ──
   RefreshButtonLabels();
   ChartRedraw(0);
}
//+------------------------------------------------------------------+
//| MT4 이벤트
//+------------------------------------------------------------------+
int OnInit()
{
   licenseOK      = false;
   licenseChecked = false;
   riskAccepted   = false;
   buyStopped=false; sellStopped=false;
   finalStopped=false; finalReason=""; finalStopTime=0; totalCycles=0;

   g_dayStart      = iTime(Symbol(),PERIOD_D1,0);
   g_dayStartEq    = AccountEquity();
   g_sessionStartEq= AccountEquity();
   g_todayPeakEq   = AccountEquity();
   g_todayMaxMDD   = 0.0;
   g_todayMaxMDDPct= 0.0;

   CreateButtons();
   EventSetTimer(1);   // 1초 타이머 → OnTimer에서 라이센스 체크
   Comment("GOLD PRIVATE: 잠시 후 라이센스 확인...");
   Print("GOLD PRIVATE v9.1 초기화 | Acc=",AccountNumber());
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){ EventKillTimer(); DeleteAllObjects(); Comment(""); }


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

   PollButtons();
   if(!licenseChecked || !riskAccepted) return;  // 라이센스/동의 전엔 거래 안 함
   ProcessTrading();
}

void OnTimer()
{
   PollButtons();

   // ── 라이센스 + 위험고지: 아직 안 됐으면 여기서 처리
   if(!licenseChecked)
   {
      Comment("GOLD PRIVATE: 라이센스 확인 중...");
      if(!CheckLicense())
      {
         Comment("GOLD PRIVATE: 라이센스 없음 — " + licenseStatus);
         Print("GOLD PRIVATE 라이센스 실패: ", licenseStatus);
         return;
      }
      licenseOK      = true;
      licenseChecked = true;
      Comment("");

      // 위험고지 팝업 (라이센스 확인 직후 1회만)
      string riskMsg =
         "EA 시작 전 필수 투자위험 및 책임 고지\n\n"
         "본 EA는 자동매매 보조 프로그램이며 수익을 보장하지 않습니다\n\n"
         "레버리지 상품은 시장 변동성 스프레드 확대 슬리피지 체결 지연 서버 장애 증거금 부족 마진콜 강제청산 등으로 인해 큰 손실이 발생할 수 있습니다\n\n"
         "기본 설정값 안내값 백테스트 과거 운용 결과 예시 수익률 시뮬레이션 자료는 참고용 정보이며 미래 수익이나 손실 제한을 보장하지 않습니다\n\n"
         "본 프로그램은 투자권유 투자자문 투자일임 대리매매 계좌운용을 목적으로 하지 않습니다\n\n"
         "EA의 설치 설정 실행 중지 포지션 청산 운용 여부에 대한 최종 판단과 책임은 전적으로 이용자 본인에게 있습니다\n\n"
         "본인의 투자 경험 재무상태 위험 감내 수준 계좌 상황을 충분히 고려한 뒤 사용 여부를 결정해야 합니다\n\n"
         "위 내용을 이해했으며 본인 판단과 책임으로 EA를 실행합니다\n\n"
         "동의하시면 예 버튼을 눌러 시작하세요";

      int res = MessageBox(riskMsg, "GOLD PRIVATE", MB_YESNO|MB_ICONWARNING);
      if(res != IDYES)
      {
         Comment("GOLD PRIVATE: 위험고지 미동의. 거래가 중지됩니다.");
         Print("GOLD PRIVATE: 위험고지 미동의.");
         riskAccepted = false;
         return;
      }
      riskAccepted = true;
      Print("GOLD PRIVATE v9.1 시작 | Acc=",AccountNumber()," | ",licenseStatus);
      return;
   }

   // ── 라이센스/동의 안 됐으면 매매 중단
   if(!licenseOK || !riskAccepted) return;

   ProcessTrading();
   if(licenseOK && SendBalance) SendBalanceToSupabase();
}
//+------------------------------------------------------------------+
