//+------------------------------------------------------------------+
//| AUTO_LOGIC_3_AxionLicense.mq4                                           |
//| AUTO LOGIC 3                      |
//| AUTO LOGIC 3 — Same Logic / New UI                    |
//|                                                                  |
//| 거래 로직: Eldorado_XAU_Clone_v1_6_Final_UI_Sync 완전 동일       |
//| v1.6 핵심:                                                        |
//|  - SellGridPoints = 300 (v1.3의 330에서 수정)                    |
//|  - MaxStepsPerSide = 99 (원본 설정 복원)                          |
//|  - BuyActualMinGridPoints 이중체크 제거                           |
//|  - StartupGate 제거 (단순화)                                      |
//|  - TPMode 0=포인트 / 1=달러 선택 가능                             |
//+------------------------------------------------------------------+
#property strict
#property copyright "AUTO LOGIC 3"
#property version   "3.01"

//===================================================
// [기본]
//===================================================
extern string SET_00                  = "======= EA 설정 =======";
extern string EA_Name                 = "======= AUTO LOGIC 3 =======";
extern int    MagicNumber             = 123456;   // 매직넘버
extern string SET_01                  = "--- [1] 거래 방향 ---";
extern bool   AllowBuy                = true;     // 매수(Long) 허용
extern bool   AllowSell               = true;     // 매도(Short) 허용
extern bool   ShowDashboard           = true;     // 대시보드 표시
extern string SET_02                  = "--- [2] 초기 설정 ---";
extern double BaseLot                 = 0.01;     // 시작 랏
extern string SET_03                  = "--- [3] 수익 설정 ---";
extern int    BasketTPPoints          = 300;      // 익절 포인트 (tpMode=POINTS일 때)
extern int    TPMode                  = 0;        // TP 모드: 0=포인트 기준 / 1=달러 기준
extern double BasketTakeProfitDollars = 10.0;     // 통합 익절 금액 ($, tpMode=DOLLAR일 때)
extern string SET_04                  = "--- [4] 마틴게일 설정 ---";
extern double LotMultiplier           = 1.50;     // 랏 배수
extern int    GridPoints              = 300;      // 추가진입 간격 (포인트)
extern int    BuyGridPoints           = 300;      // 0이면 GridPoints 사용
extern int    SellGridPoints          = 300;      // 0이면 GridPoints 사용
extern int    MaxStepsPerSide         = 99;       // 방향별 최대주문수
extern int    MinSecondsBetweenAdds   = 5;
extern int    ReEntryDelaySeconds     = 0;        // 정산 후 쿨타임 (초, 0=사용안함)
extern string SET_05                  = "--- [5] 청산 모드 ---";
extern bool   UseServerTP             = true;     // 통합 익절(TP) 사용
extern double CloseProfitDollars      = 0.0;      // 통합 수익 금액 ($, 0=미사용)
extern double BasketStopLossDollars   = 0.0;      // 통합 손절 금액 ($, 0=미사용)
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
extern int    PulsePeriod             = 14;       // ADX 기간
extern int    FluxPeriod              = 14;       // ATR 기간
extern double PulseRangeLevel         = 25.0;     // 추세/횡보 기준 (ADX)
extern bool   UsePulseFluxFilter      = false;    // 복제 모드: false 권장
extern string SET_07                  = "--- [7] UI 설정 ---";
extern int    DashboardCorner         = 1;        // 패널 위치: 0=좌상단 1=우상단 2=좌하단 3=우하단
extern int    DashboardX              = 50;       // 패널 X 여백
extern int    DashboardY              = 0;        // 패널 Y 여백
extern int    DashboardFontBoost       = 0;        // 폰트 크기 보정
extern string DashboardFontName        = "Consolas"; // 폰트 이름
extern bool   UIAutoScale              = false;    // UI 자동 스케일링 (해상도 반응형)
extern double UIManualScale            = 1.0;      // 수동 스케일 (0.7~2.0)
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
extern string _81_ = "AUTO_LOGIC_3 권한으로 라이선스 체크";
extern string 프로그램명             = "AUTO_LOGIC_3";
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

datetime 마지막라이센스체크 = 0;

string PFX       = "ALG3_";
string BTN_BUY   = "ALG3_BTN_BUY";
string BTN_SELL  = "ALG3_BTN_SELL";
string BTN_CLOSE = "ALG3_BTN_CLOSE";

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
void Dbg(string s){ if(PrintDebug) Print("[AUTO LOGIC 3] ",s); }
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
      Alert("AUTO LOGIC 3 STOP: ",reason," / Session P&L=",DoubleToString(SessionPnL(),2));
   Print("AUTO LOGIC 3 FINAL STOP: ",reason,
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
   if(!licenseOK) return;

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
   string _acc = IntegerToString((int)AccountNumber());
   string _rh  = "apikey: "+인증키+"\r\nAuthorization: Bearer "+인증키;
   char _p[]; char _r[]; string _rhs;

   // Step 1: account_no + is_active 확인, id + expires_at 취득
   string _url1 = 서버주소+"/rest/v1/customers?account_no=eq."+_acc+"&is_active=eq.true&select=id,expires_at";
   int _http1 = WebRequest("GET",_url1,_rh,8000,_p,_r,_rhs);
   string _body1 = CharArrayToString(_r);
   Print("AUTO LOGIC 3 License Step1 HTTP=",_http1," body=",_body1);
   if(_http1!=200||_body1=="[]"||StringFind(_body1,"expires_at")<0)
   { licenseStatus="미등록/비활성 계좌 (HTTP="+IntegerToString(_http1)+")"; return false; }

   // 만료일 파싱
   int _es = StringFind(_body1,"\"expires_at\":\"")+14;
   string _exp = StringSubstr(_body1,_es,10); StringReplace(_exp,"-",".");
   if(_exp < TimeToString(TimeCurrent(),TIME_DATE))
   { licenseStatus="만료됨 ("+_exp+")"; return false; }

   // customer_id 파싱
   int _is = StringFind(_body1,"\"id\":\"")+6;
   string _custId = "";
   if(_is > 5) {
      int _ie = StringFind(_body1,"\"",_is);
      if(_ie > _is) _custId = StringSubstr(_body1,_is,_ie-_is);
   }
   if(_custId == "") { licenseStatus="ID 파싱 실패"; return false; }

   // Step 2: customer_programs에서 이 EA 할당 여부 확인
   char _r2[]; string _rhs2;
   string _url2 = 서버주소+"/rest/v1/customer_programs?customer_id=eq."+_custId+"&select=programs(name)";
   int _http2 = WebRequest("GET",_url2,_rh,8000,_p,_r2,_rhs2);
   string _body2 = CharArrayToString(_r2);
   Print("AUTO LOGIC 3 License Step2 HTTP=",_http2," body=",_body2);
   if(_http2!=200||_body2=="[]")
   { licenseStatus="미할당 프로그램"; return false; }

   string _body2L = _body2; StringToLower(_body2L);
   string _progL  = 프로그램명; StringToLower(_progL);
   if(StringFind(_body2L,_progL)<0)
   { licenseStatus="이 EA 미할당 ("+프로그램명+")"; return false; }

   licenseStatus = "정상 ("+_exp+"까지)";
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
int PH = 510;   // AUTO LOGIC 3 panel height

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
      ObjectSetInteger(0,n,OBJPROP_BACK,      true);
   }
   ObjectSetInteger(0,n,OBJPROP_CORNER,    GetCorner());
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE, CX(px));
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE, CY(py));
   ObjectSetInteger(0,n,OBJPROP_XSIZE,     w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,     h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,   bg);
   ObjectSetInteger(0,n,OBJPROP_COLOR,     border);
   ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,0);   // 배경: ZORDER 최하위
}

// 구분선
void HR(string id, int py, color clr)
{
   R(id, 0, py, PW+2, 1, clr, clr);
}


string DateShort(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   string mm = (dt.mon < 10 ? "0" : "") + IntegerToString(dt.mon);
   string dd = (dt.day < 10 ? "0" : "") + IntegerToString(dt.day);
   return(mm + "/" + dd);
}

string MoneyStr(double v)
{
   return (v>=0 ? "+$" : "-$") + DoubleToString(MathAbs(v),2);
}
color MoneyClr(double v) { return v>=0 ? CLR_GREEN : CLR_RED; }

//--- 버튼 생성 (OnInit에서 한 번만 호출)
void CreateButtons()
{
   int bw = 92;
   int bh = 26;
   int gap = 5;

   int btnY = CY(PH - 34);
   bool rightSide = (DashboardCorner==1 || DashboardCorner==3);

   if(ObjectFind(0,BTN_SELL)<0) ObjectCreate(0,BTN_SELL,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,BTN_SELL,OBJPROP_CORNER,    GetCorner());
   ObjectSetInteger(0,BTN_SELL,OBJPROP_XDISTANCE, rightSide ? DashboardX + bw*3 + gap*2 : DashboardX);
   ObjectSetInteger(0,BTN_SELL,OBJPROP_YDISTANCE, btnY);
   ObjectSetInteger(0,BTN_SELL,OBJPROP_XSIZE,     bw);
   ObjectSetInteger(0,BTN_SELL,OBJPROP_YSIZE,     bh);
   ObjectSetString (0,BTN_SELL,OBJPROP_FONT,      "Arial Bold");
   ObjectSetInteger(0,BTN_SELL,OBJPROP_FONTSIZE,  9);
   ObjectSetInteger(0,BTN_SELL,OBJPROP_COLOR,     clrWhite);
   ObjectSetInteger(0,BTN_SELL,OBJPROP_STATE,     false);
   ObjectSetInteger(0,BTN_SELL,OBJPROP_ZORDER,    100);
   ObjectSetInteger(0,BTN_SELL,OBJPROP_BACK,      false);

   if(ObjectFind(0,BTN_BUY)<0) ObjectCreate(0,BTN_BUY,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,BTN_BUY,OBJPROP_CORNER,    GetCorner());
   ObjectSetInteger(0,BTN_BUY,OBJPROP_XDISTANCE, rightSide ? DashboardX + bw*2 + gap : DashboardX + bw + gap);
   ObjectSetInteger(0,BTN_BUY,OBJPROP_YDISTANCE, btnY);
   ObjectSetInteger(0,BTN_BUY,OBJPROP_XSIZE,     bw);
   ObjectSetInteger(0,BTN_BUY,OBJPROP_YSIZE,     bh);
   ObjectSetString (0,BTN_BUY,OBJPROP_FONT,      "Arial Bold");
   ObjectSetInteger(0,BTN_BUY,OBJPROP_FONTSIZE,  9);
   ObjectSetInteger(0,BTN_BUY,OBJPROP_COLOR,     clrWhite);
   ObjectSetInteger(0,BTN_BUY,OBJPROP_STATE,     false);
   ObjectSetInteger(0,BTN_BUY,OBJPROP_ZORDER,    100);
   ObjectSetInteger(0,BTN_BUY,OBJPROP_BACK,      false);

   if(ObjectFind(0,BTN_CLOSE)<0) ObjectCreate(0,BTN_CLOSE,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,BTN_CLOSE,OBJPROP_CORNER,    GetCorner());
   ObjectSetInteger(0,BTN_CLOSE,OBJPROP_XDISTANCE, rightSide ? DashboardX + bw : DashboardX + (bw+gap)*2);
   ObjectSetInteger(0,BTN_CLOSE,OBJPROP_YDISTANCE, btnY);
   ObjectSetInteger(0,BTN_CLOSE,OBJPROP_XSIZE,     bw);
   ObjectSetInteger(0,BTN_CLOSE,OBJPROP_YSIZE,     bh);
   ObjectSetString (0,BTN_CLOSE,OBJPROP_FONT,      "Arial Bold");
   ObjectSetInteger(0,BTN_CLOSE,OBJPROP_FONTSIZE,  9);
   ObjectSetInteger(0,BTN_CLOSE,OBJPROP_COLOR,     clrWhite);
   ObjectSetInteger(0,BTN_CLOSE,OBJPROP_STATE,     false);
   ObjectSetInteger(0,BTN_CLOSE,OBJPROP_ZORDER,    100);
   ObjectSetInteger(0,BTN_CLOSE,OBJPROP_BACK,      false);

   RefreshButtonLabels();
   ChartRedraw(0);
}

void RefreshButtonLabels()
{
   // SELL STOP 버튼
   if(ObjectFind(0,BTN_SELL)>=0)
   {
      string t  = finalStopped ? "STOPPED" : (sellStopped ? "SELL  ON" : "SELL STOP");
      color  bg = finalStopped ? C'50,10,10' : (sellStopped ? C'20,110,45' : C'170,35,35');
      ObjectSetString (0,BTN_SELL,OBJPROP_TEXT,   t);
      ObjectSetInteger(0,BTN_SELL,OBJPROP_BGCOLOR, bg);
   }
   // BUY STOP 버튼
   if(ObjectFind(0,BTN_BUY)>=0)
   {
      string t  = finalStopped ? "STOPPED" : (buyStopped ? "BUY   ON" : "BUY  STOP");
      color  bg = finalStopped ? C'50,10,10' : (buyStopped ? C'20,110,45' : C'25,75,180');
      ObjectSetString (0,BTN_BUY,OBJPROP_TEXT,   t);
      ObjectSetInteger(0,BTN_BUY,OBJPROP_BGCOLOR, bg);
   }
   // CLOSE ALL 버튼
   if(ObjectFind(0,BTN_CLOSE)>=0)
   {
      string t  = finalStopped ? "CLOSED" : "CLOSE ALL";
      color  bg = finalStopped ? C'40,40,40' : C'120,25,25';
      ObjectSetString (0,BTN_CLOSE,OBJPROP_TEXT,   t);
      ObjectSetInteger(0,BTN_CLOSE,OBJPROP_BGCOLOR, bg);
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
         Print("AUTO LOGIC 3: SELL ", sellStopped?"STOPPED":"RESUMED");
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
         Print("AUTO LOGIC 3: BUY ", buyStopped?"STOPPED":"RESUMED");
      }
      RefreshButtonLabels();
   }
   // CLOSE ALL
   if(ObjectFind(0,BTN_CLOSE)>=0 && (bool)ObjectGetInteger(0,BTN_CLOSE,OBJPROP_STATE))
   {
      ObjectSetInteger(0,BTN_CLOSE,OBJPROP_STATE,false);
      if(!finalStopped)
      {
         Print("AUTO LOGIC 3: CLOSE ALL 실행");
         CloseSide(OP_BUY);
         CloseSide(OP_SELL);
         buyStopped   = true;
         sellStopped  = true;
         finalStopped = true;
         finalReason  = "MANUAL CLOSE ALL";
         finalStopTime= TimeCurrent();
         if(AlertOnFinalStop) Alert("AUTO LOGIC 3: 전체 청산 완료. 신규 진입 중단.");
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
   Comment("");
   UpdateTodayMDD();

   double equity  = AccountEquity();
   double balance = AccountBalance();
   double dayPnL  = equity - g_dayStartEq;
   double pnlPct  = balance>0 ? dayPnL/balance*100.0 : 0;
   double spread  = MarketInfo(Symbol(),MODE_SPREAD);

   int    bc   = CountSide(OP_BUY);
   int    sc   = CountSide(OP_SELL);
   double bl   = TotalLotsSide(OP_BUY);
   double sl   = TotalLotsSide(OP_SELL);
   double bAvg = WeightedAvgSide(OP_BUY);
   double sAvg = WeightedAvgSide(OP_SELL);
   double bTP  = BasketTPPrice(OP_BUY);
   double sTP  = BasketTPPrice(OP_SELL);
   double bFL  = BasketProfitSide(OP_BUY);
   double sFL  = BasketProfitSide(OP_SELL);

   datetime today  = iTime(Symbol(),PERIOD_D1,0);
   MqlDateTime md; TimeToStruct(today,md);
   md.day=1; md.hour=0; md.min=0; md.sec=0;
   datetime mon1 = StructToTime(md);

   double todayP = GetHistoryProfit(today, today+86400);
   double yestP  = GetHistoryProfit(today-86400, today);
   double monP   = GetHistoryProfit(mon1, today+86400);
   double todayL = GetHistoryLots(today, today+86400);
   double yestL  = GetHistoryLots(today-86400, today);
   double monL   = GetHistoryLots(mon1, today+86400);

   double adx = iADX(Symbol(),PERIOD_CURRENT,PulsePeriod,PRICE_CLOSE,MODE_MAIN,0);
   double diP = iADX(Symbol(),PERIOD_CURRENT,PulsePeriod,PRICE_CLOSE,MODE_PLUSDI,0);
   double diM = iADX(Symbol(),PERIOD_CURRENT,PulsePeriod,PRICE_CLOSE,MODE_MINUSDI,0);
   double atr = iATR(Symbol(),PERIOD_CURRENT,FluxPeriod,0);

   string direction = diP>=diM ? "v BULLISH" : "v BEARISH";
   color  dirClr    = diP>=diM ? CLR_GREEN : CLR_RED;
   string status    = adx>=PulseRangeLevel ? "TREND" : "RANGE";
   color  statusClr = adx>=PulseRangeLevel ? CLR_GOLD : CLR_GREEN;

   string stTxt = "RUNNING";
   color  stClr = CLR_GREEN;
   if(!licenseOK)                   { stTxt="NO LICENSE";   stClr=CLR_RED;  }
   else if(finalStopped)            { stTxt=finalReason;    stClr=CLR_RED;  }
   else if(buyStopped&&sellStopped) { stTxt="ALL STOPPED";  stClr=CLR_GRAY; }
   else if(buyStopped)              { stTxt="BUY STOPPED";  stClr=CLR_GRAY; }
   else if(sellStopped)             { stTxt="SELL STOPPED"; stClr=CLR_GRAY; }

   color BG  = C'6,6,6';
   color BD  = C'55,55,55';
   color W   = C'235,235,235';
   color DIM = C'135,135,135';
   color CY  = C'90,220,255';
   color G   = CLR_GREEN;
   color RDE = CLR_RED;
   color Y   = CLR_GOLD;

   string F = DashboardFontName;

   R("bg", 0, 0, PW+2, PH, BG, BD);

   int y = 6;

   L("T0", "=== AUTO LOGIC 3 ===", 58, y, 10, Y, F); y += 25;

   L("S1", "Symbol :", 18, y, 8, W, F);
   L("S2", Symbol(), 108, y, 8, CY, F); y += 20;

   L("TM1", "Time   :", 18, y, 8, W, F);
   L("TM2", TimeToString(TimeCurrent(),TIME_SECONDS), 108, y, 8, CY, F); y += 20;

   L("SP1", "Spread :", 18, y, 8, W, F);
   L("SP2", DoubleToString(spread,1) + " | Max:" + DoubleToString(MaxSpreadPoints,1), 108, y, 8, CY, F); y += 24;

   L("H_ACC", "--- ACCOUNT INFO ---", 72, y, 8, DIM, F); y += 20;

   L("B1", "Balance :", 18, y, 8, W, F);
   L("B2", "$" + DoubleToString(balance,2), 108, y, 8, G, F); y += 20;

   L("E1", "Equity  :", 18, y, 8, W, F);
   L("E2", "$" + DoubleToString(equity,2), 108, y, 8, equity>=balance?G:RDE, F); y += 20;

   L("P1", "PnL     :", 18, y, 8, W, F);
   L("P2", MoneyStr(dayPnL) + " (" + (pnlPct>=0?"+":"") + DoubleToString(pnlPct,1) + "%)", 108, y, 8, MoneyClr(dayPnL), F); y += 20;

   L("V1", "Volume  :", 18, y, 8, W, F);
   L("V2", DoubleToString(bl+sl,2) + " Lots", 108, y, 8, CY, F); y += 24;

   L("H_TR", "--- TRADE ---", 96, y, 8, DIM, F); y += 20;

   L("TR1", "Trade :", 18, y, 8, W, F);
   L("TR2", "Buy:" + IntegerToString(bc) + " | Sell:" + IntegerToString(sc), 108, y, 8, CY, F); y += 20;

   L("MS1", "Martin Step :", 18, y, 8, W, F);
   L("MS2", "B:" + IntegerToString(bc) + "/" + IntegerToString(MaxStepsPerSide) + " | S:" + IntegerToString(sc) + "/" + IntegerToString(MaxStepsPerSide), 108, y, 8, CY, F); y += 24;

   L("H_MA", "--- MARKET ANALYSIS ---", 58, y, 8, DIM, F); y += 20;

   L("A1", "ADX       :", 18, y, 8, W, F);
   L("A2", DoubleToString(adx,1), 108, y, 8, adx>=PulseRangeLevel?Y:CY, F); y += 18;

   L("DI1", "+DI       :", 18, y, 8, W, F);
   L("DI2", DoubleToString(diP,1), 108, y, 8, G, F); y += 18;

   L("DM1", "-DI       :", 18, y, 8, W, F);
   L("DM2", DoubleToString(diM,1), 108, y, 8, RDE, F); y += 18;

   L("AT1", "ATR       :", 18, y, 8, W, F);
   L("AT2", DoubleToString(atr,2), 108, y, 8, CY, F); y += 18;

   L("DR1", "Direction :", 18, y, 8, W, F);
   L("DR2", direction, 108, y, 8, dirClr, F); y += 18;

   L("ST1", "Status    :", 18, y, 8, W, F);
   L("ST2", status, 108, y, 8, statusClr, F); y += 24;

   L("H_TP", "--- TP INFO ---", 90, y, 8, DIM, F); y += 20;

   L("AV1", "Avg Price :", 18, y, 8, W, F);
   L("AV2", "B:" + (bAvg>0?DoubleToString(bAvg,Dig()):"----") + " | S:" + (sAvg>0?DoubleToString(sAvg,Dig()):"----"), 108, y, 8, CY, F); y += 18;

   L("TP1", "TP Price  :", 18, y, 8, W, F);
   L("TP2", "B:" + (bTP>0?DoubleToString(bTP,Dig()):"----") + " | S:" + (sTP>0?DoubleToString(sTP,Dig()):"----"), 108, y, 8, CY, F); y += 18;

   L("FL1", "Floating  :", 18, y, 8, W, F);
   L("FL2", "B:" + MoneyStr(bFL) + " | S:" + MoneyStr(sFL), 108, y, 8, MoneyClr(bFL+sFL), F); y += 24;

   L("H_PF", "--- PERFORMANCE ---", 65, y, 8, DIM, F); y += 20;

   L("PF1", DateShort(today), 18, y, 8, W, F);
   L("PF2", MoneyStr(todayP) + "  " + DoubleToString(todayP/(balance>0?balance:1)*100,2) + "%", 108, y, 8, MoneyClr(todayP), F);
   L("PF3", DoubleToString(todayL,2) + " L", 235, y, 8, CY, F); y += 18;

   L("PF4", DateShort(today-86400), 18, y, 8, W, F);
   L("PF5", MoneyStr(yestP) + "  " + DoubleToString(yestP/(balance>0?balance:1)*100,2) + "%", 108, y, 8, MoneyClr(yestP), F);
   L("PF6", DoubleToString(yestL,2) + " L", 235, y, 8, CY, F); y += 18;

   L("PF7", "Monthly:", 18, y, 8, W, F);
   L("PF8", MoneyStr(monP) + "  " + DoubleToString(monP/(balance>0?balance:1)*100,2) + "%", 108, y, 8, MoneyClr(monP), F);
   L("PF9", DoubleToString(monL,2) + " L", 235, y, 8, CY, F); y += 24;

   L("RUN", stTxt, 18, y, 9, stClr, F);
   L("LIC", licenseOK ? "Lic OK" : "Lic NO", 215, y, 8, licenseOK?G:RDE, F); y += 18;

   string fs = FinalStopLossDollars>0 ? "SL $" + DoubleToString(FinalStopLossDollars,0) : "SL OFF";
   string ft = FinalTakeProfitDollars>0 ? "FinalTP $" + DoubleToString(FinalTakeProfitDollars,0) : "FinalTP OFF";
   L("FN", ft + " / " + fs, 18, y, 7, Y, F);

   R("btn_bg", 0, PH-44, PW+2, 38, BG, BD);

   RefreshButtonLabels();
   ChartRedraw(0);
}
int OnInit()
{
   licenseOK=false; licenseStatus="확인 중...";
   buyStopped=false; sellStopped=false;
   finalStopped=false; finalReason=""; finalStopTime=0; totalCycles=0;
   Comment("AUTO LOGIC 3: 라이선스 확인 중...");
   Sleep(300);

   if(!CheckLicense())
   { Comment("AUTO LOGIC 3: "+licenseStatus); return(INIT_FAILED); }

   licenseOK      = true;
   g_dayStart      = iTime(Symbol(),PERIOD_D1,0);
   g_dayStartEq    = AccountEquity();
   g_sessionStartEq= AccountEquity();
   g_todayPeakEq   = AccountEquity();
   g_todayMaxMDD   = 0.0;
   g_todayMaxMDDPct= 0.0;

   CreateButtons();   // 버튼은 여기서 딱 한 번만 생성
   EventSetTimer(1);
   Print("AUTO LOGIC 3 v3.01 Axion License OK | Acc=",AccountNumber()," | ",licenseStatus);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){ EventKillTimer(); DeleteAllObjects(); Comment(""); }

void OnTick()
{
   PollButtons();       // 버튼 폴링 먼저
   ProcessTrading();
}

void OnTimer()
{
   PollButtons();
   int _reCheckSec = licenseOK ? 3600 : 60;
   if(TimeCurrent()-마지막라이센스체크 >= _reCheckSec) {
      마지막라이센스체크 = TimeCurrent();
      if(!CheckLicense()) {
         if(licenseOK) { licenseOK=false; CloseSide(OP_BUY); CloseSide(OP_SELL); buyStopped=true; sellStopped=true; }
         return;
      }
      licenseOK = true;
   }
   ProcessTrading();
   if(licenseOK && SendBalance) SendBalanceToSupabase();
}
//+------------------------------------------------------------------+
