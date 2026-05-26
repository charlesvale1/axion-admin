//+------------------------------------------------------------------+
//| Soluni_EA_TossUI.mq4                                           |
//| Soluni Trading System                      |
//| Soluni v1.0 — Simple Toss Style UI                    |
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
#property copyright "Soluni Trading System"
#property version   "1.00"

//===================================================
// [기본]
//===================================================
extern string SET_00                  = "======= EA 설정 =======";
extern string EA_Name                 = "======= Soluni =======";
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
extern string _80_ = "=== [8] Soluni 라이선스 ===";
extern string _81_ = "관리자페이지 등록 프로그램명과 일치해야 함";
extern string 프로그램명             = "Soluni";
extern string _82_ = "서버 주소 (변경금지)";
extern string 서버주소               = "https://wmvnearoursbmwjqwzww.supabase.co";
extern string _83_ = "인증키 (변경금지)";
extern string 인증키                 = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indtdm5lYXJvdXJzYm13anF3end3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgxNzQ5MjEsImV4cCI6MjA5Mzc1MDkyMX0.MS4iSGIvW4dBi3sd8J3baHLT4TlgUJS5lXwlhJdWYEY";
extern bool   SendBalance             = true;
extern int    SendBalanceMinutes      = 5;

//===================================================
// 내부 변수
//===================================================
datetime g_lastBuyAdd        = 0;
datetime g_lastSellAdd       = 0;
datetime g_lastBuyClose      = 0;
datetime g_lastSellClose     = 0;
datetime g_dayStart          = 0;
double   g_dayStartEq        = 0;
double   g_sessionStartEq    = 0;
bool     licenseOK           = false;
string   licenseStatus       = "확인 중...";
datetime 마지막라이센스체크  = 0;
bool     buyStopped      = false;
bool     sellStopped     = false;
bool     finalStopped    = false;
string   finalReason     = "";
datetime finalStopTime   = 0;
int      totalCycles     = 0;

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
void Dbg(string s){ if(PrintDebug) Print("[Soluni] ",s); }
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
   if(d!=g_dayStart){ g_dayStart=d; g_dayStartEq=AccountEquity(); }
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

void TriggerFinalStop(string reason)
{
   if(finalStopped) return;
   finalStopped  = true;
   finalReason   = reason;
   finalStopTime = TimeCurrent();
   if(CloseAllOnFinalStop){ CloseSide(OP_BUY); CloseSide(OP_SELL); }
   if(StopEAAfterFinal){ buyStopped=true; sellStopped=true; }
   if(AlertOnFinalStop)
      Alert("Soluni STOP: ",reason," / Session P&L=",DoubleToString(SessionPnL(),2));
   Print("Soluni FINAL STOP: ",reason,
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

   // ── 1단계: 계좌 활성 여부 + 만료일 + customer id ──
   string _url1 = 서버주소+"/rest/v1/customers"
                + "?account_no=eq."+_acc
                + "&is_active=eq.true"
                + "&select=id,expires_at";
   int _http1 = WebRequest("GET",_url1,_rh,8000,_p,_r,_rhs);
   string _body1 = CharArrayToString(_r);
   Print("Soluni License step1 HTTP=",_http1," body=",_body1);

   if(_http1!=200||_body1=="[]"||StringFind(_body1,"expires_at")<0)
   { licenseStatus="미등록 계좌 또는 라이선스 정지 (HTTP="+IntegerToString(_http1)+")"; return false; }

   // 만료일 파싱
   int    _ps  = StringFind(_body1,"\"expires_at\":\"")+14;
   string _exp = StringSubstr(_body1,_ps,10);
   StringReplace(_exp,"-",".");
   if(_exp<TimeToString(TimeCurrent(),TIME_DATE))
   { licenseStatus="만료됨 ("+_exp+")"; return false; }

   // customer id 파싱
   int    _si     = StringFind(_body1,"\"id\":\"")+6;
   int    _ei     = StringFind(_body1,"\"",_si);
   string _custId = StringSubstr(_body1,_si,_ei-_si);

   // ── 2단계: customer_programs 에서 EA 권한 확인 ──
   char _r2[]; string _rhs2;
   string _url2 = 서버주소+"/rest/v1/customer_programs"
                + "?customer_id=eq."+_custId
                + "&select=programs(name)";
   int _http2 = WebRequest("GET",_url2,_rh,8000,_p,_r2,_rhs2);
   string _body2  = CharArrayToString(_r2);
   string _body2L = _body2;
   string _progL  = 프로그램명;
   StringToLower(_body2L);
   StringToLower(_progL);
   Print("Soluni License step2 HTTP=",_http2," body=",_body2);

   if(_http2!=200||StringFind(_body2L,_progL)<0)
   { licenseStatus="이 EA 권한 없음 ("+프로그램명+") - 관리자 페이지에서 권한 신청 필요"; return false; }

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
int PW = 286;
int PH = 430;   // Soluni Toss-style compact UI

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
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,  sz);
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

string MoneyStr(double v)
{
   return (v>=0 ? "+$" : "-$") + DoubleToString(MathAbs(v),2);
}
color MoneyClr(double v) { return v>=0 ? CLR_GREEN : CLR_RED; }

//--- 버튼 생성 (OnInit에서 한 번만 호출)
void CreateButtons()
{
   int bw = 90;   // 버튼 너비
   int bh = 30;   // 버튼 높이
   int gap = 6;   // 버튼 간격

   // 버튼 Y 위치: 패널 하단
   int btnY = CY(PH - 39);  // 패널 하단
   bool rightSide = (DashboardCorner==1 || DashboardCorner==3);

   // SELL STOP (왼쪽)
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

   // BUY STOP (가운데)
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

   // CLOSE ALL (오른쪽)
   if(ObjectFind(0,BTN_CLOSE)<0) ObjectCreate(0,BTN_CLOSE,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,BTN_CLOSE,OBJPROP_CORNER,    GetCorner());
   ObjectSetInteger(0,BTN_CLOSE,OBJPROP_XDISTANCE, rightSide ? DashboardX + bw + gap : DashboardX + (bw+gap)*2);
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
         Print("Soluni: SELL ", sellStopped?"STOPPED":"RESUMED");
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
         Print("Soluni: BUY ", buyStopped?"STOPPED":"RESUMED");
      }
      RefreshButtonLabels();
   }
   // CLOSE ALL
   if(ObjectFind(0,BTN_CLOSE)>=0 && (bool)ObjectGetInteger(0,BTN_CLOSE,OBJPROP_STATE))
   {
      ObjectSetInteger(0,BTN_CLOSE,OBJPROP_STATE,false);
      if(!finalStopped)
      {
         Print("Soluni: CLOSE ALL 실행");
         CloseSide(OP_BUY);
         CloseSide(OP_SELL);
         buyStopped   = true;
         sellStopped  = true;
         finalStopped = true;
         finalReason  = "MANUAL CLOSE ALL";
         finalStopTime= TimeCurrent();
         if(AlertOnFinalStop) Alert("Soluni: 전체 청산 완료. 신규 진입 중단.");
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

   // Soluni UI는 핵심만 표시합니다.
   // MDD/ADX 등 복잡한 장세 지표는 표시하지 않지만, 매매 로직은 그대로 유지됩니다.
   Comment("");

   double equity  = AccountEquity();
   double balance = AccountBalance();
   double dayPnL  = equity - g_dayStartEq;
   double sessPnL = equity - g_sessionStartEq;
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
   double tFL  = bFL + sFL;

   string ft = FinalTakeProfitDollars>0 ? "$"+DoubleToString(FinalTakeProfitDollars,0) : "OFF";
   string fs = FinalStopLossDollars>0   ? "$"+DoubleToString(FinalStopLossDollars,0)   : "OFF";

   string stTxt = "Running";
   color  stClr = C'0,178,90';
   if(!licenseOK)                   { stTxt="No License";  stClr=C'239,68,68';  }
   else if(finalStopped)            { stTxt=finalReason;   stClr=C'239,68,68';  }
   else if(buyStopped&&sellStopped) { stTxt="All Stopped"; stClr=C'107,114,128';}
   else if(buyStopped)              { stTxt="Buy Stopped"; stClr=C'107,114,128';}
   else if(sellStopped)             { stTxt="Sell Stopped";stClr=C'107,114,128';}

   // Toss-style palette
   color BG      = C'246,248,252';
   color CARD    = C'255,255,255';
   color LINE    = C'229,234,242';
   color TEXT    = C'25,31,40';
   color SUB     = C'107,114,128';
   color BLUE    = C'49,130,246';
   color BLUE2   = C'232,241,255';
   color GREEN   = C'0,178,90';
   color RED     = C'239,68,68';
   color AMBER   = C'245,158,11';

   int y = 0;

   // Main background
   R("bg", 0, y, PW+2, PH, BG, LINE);

   // Header
   R("hd", 0, y, PW+2, 72, CARD, LINE);
   L("T1","Soluni", 22, y+14, 22, BLUE, "Arial Bold");
   L("T2","Gold Auto Trading", 24, y+43, 9, SUB, "Arial");
   L("T3",licenseOK ? "License OK" : "License NO", 260, y+18, 8, licenseOK?GREEN:RED, "Arial Bold");
   L("T4","v1.0", 312, y+43, 8, SUB, "Arial");
   y += 78;

   // Symbol row
   R("sym", 14, y, PW-28, 38, CARD, LINE);
   L("SY", Symbol(), 28, y+9, 11, TEXT, "Arial Bold");
   L("TI", TimeToString(TimeCurrent(),TIME_SECONDS), 134, y+10, 10, SUB, "Arial");
   L("SP", "Spread "+DoubleToString(spread,0), 242, y+10, 9, spread>60?RED:SUB, "Arial");
   y += 48;

   // Account summary card
   R("acc", 14, y, PW-28, 88, CARD, LINE);
   L("AH", "Account", 28, y+12, 9, SUB, "Arial Bold");
   L("AB1","Balance", 28, y+34, 8, SUB, "Arial");
   L("AB2","$"+DoubleToString(balance,0), 28, y+51, 13, TEXT, "Arial Bold");

   L("AE1","Equity", 132, y+34, 8, SUB, "Arial");
   L("AE2","$"+DoubleToString(equity,0), 132, y+51, 13, equity>=balance?GREEN:RED, "Arial Bold");

   L("AP1","Live P&L", 238, y+34, 8, SUB, "Arial");
   L("AP2",MoneyStr(dayPnL), 238, y+51, 13, MoneyClr(dayPnL), "Arial Bold");
   y += 100;

   // Position summary card
   R("pos", 14, y, PW-28, 126, CARD, LINE);
   L("PH", "Positions", 28, y+12, 9, SUB, "Arial Bold");

   // BUY
   R("buyTag", 28, y+34, 58, 20, BLUE2, BLUE2);
   L("BT", "BUY", 43, y+37, 8, BLUE, "Arial Bold");
   L("BO", "Orders  "+IntegerToString(bc), 28, y+64, 8, SUB, "Arial");
   L("BL", "Lots    "+DoubleToString(bl,2), 28, y+82, 8, SUB, "Arial");
   L("BF", MoneyStr(bFL), 28, y+100, 10, MoneyClr(bFL), "Arial Bold");

   // SELL
   R("sellTag", 198, y+34, 58, 20, C'255,235,238', C'255,235,238');
   L("STG", "SELL", 213, y+37, 8, RED, "Arial Bold");
   L("SO", "Orders  "+IntegerToString(sc), 198, y+64, 8, SUB, "Arial");
   L("SLT", "Lots    "+DoubleToString(sl,2), 198, y+82, 8, SUB, "Arial");
   L("SF", MoneyStr(sFL), 198, y+100, 10, MoneyClr(sFL), "Arial Bold");
   y += 138;

   // Trade info row
   R("info", 14, y, PW-28, 58, CARD, LINE);
   L("IH", "Basket", 28, y+10, 8, SUB, "Arial Bold");
   L("IA", "Avg  " + (bAvg>0?DoubleToString(bAvg,Dig()):"-") + " / " + (sAvg>0?DoubleToString(sAvg,Dig()):"-"), 28, y+29, 8, SUB, "Arial");
   L("IT", "TP   " + (bTP>0?DoubleToString(bTP,Dig()):"-") + " / " + (sTP>0?DoubleToString(sTP,Dig()):"-"), 180, y+29, 8, SUB, "Arial");
   y += 70;

   // Status row
   R("stat", 14, y, PW-28, 48, CARD, LINE);
   L("RUN", stTxt, 28, y+10, 11, stClr, "Arial Bold");
   L("FL", "Float " + MoneyStr(tFL), 138, y+11, 10, MoneyClr(tFL), "Arial Bold");
   L("FS", "TP " + ft + " / SL " + fs, 28, y+30, 8, SUB, "Arial");
   L("SS", "Session " + MoneyStr(sessPnL), 190, y+30, 8, MoneyClr(sessPnL), "Arial");
   y += 58;

   // Button area background
   R("bb", 14, y, PW-28, 46, CARD, LINE);

   RefreshButtonLabels();
   ChartRedraw(0);
}
//+------------------------------------------------------------------+
//| MT4 이벤트
//+------------------------------------------------------------------+
int OnInit()
{
   licenseOK=false; licenseStatus="확인 중...";
   buyStopped=false; sellStopped=false;
   finalStopped=false; finalReason=""; finalStopTime=0; totalCycles=0;
   DeleteAllObjects();
   Comment("Soluni: 라이선스 확인 중...");
   Sleep(300);

   if(!CheckLicense())
   { Comment("Soluni: "+licenseStatus); return(INIT_FAILED); }

   licenseOK      = true;
   g_dayStart     = iTime(Symbol(),PERIOD_D1,0);
   g_dayStartEq   = AccountEquity();
   g_sessionStartEq= AccountEquity();

   CreateButtons();   // 버튼은 여기서 딱 한 번만 생성
   EventSetTimer(1);
   Print("Soluni v1.0 OK | Acc=",AccountNumber()," | ",licenseStatus);
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

   // 1시간마다 라이선스 재확인 (정지/만료 감지)
   if(TimeCurrent()-마지막라이센스체크 >= 3600)
   {
      마지막라이센스체크 = TimeCurrent();
      if(!CheckLicense())
      {
         if(licenseOK)
         {
            licenseOK = false;
            Print("Soluni: 라이선스 정지됨. 전체 청산.");
            CloseSide(OP_BUY);
            CloseSide(OP_SELL);
            buyStopped=true; sellStopped=true;
         }
         return;
      }
      licenseOK = true;
   }

   ProcessTrading();
   if(licenseOK && SendBalance) SendBalanceToSupabase();
}
//+------------------------------------------------------------------+
