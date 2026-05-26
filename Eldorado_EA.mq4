//+------------------------------------------------------------------+
//| Eldorado_EA_Official_UI.mq4                                           |
//| DQL(Diplomat Quant Logic) by HERITAGE ASSET                      |
//| ELDORADO EA v9.1 — Official UI + Final Stop Safety                    |
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
#property copyright "Made by 어쩌다전업"
#property version   "9.10"

//===================================================
// [기본]
//===================================================
extern string SET_00                  = "======= EA 설정 =======";
extern string EA_Name                 = "======= ELDORADO EA =======";
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
extern string 프로그램명             = "Eldorado_EA";
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
bool     licenseOK           = false;
string   licenseStatus       = "확인 중...";
datetime 마지막라이센스체크  = 0;
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
void Dbg(string s){ if(PrintDebug) Print("[ELDORADO EA] ",s); }
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
      Alert("ELDORADO EA STOP: ",reason," / Session P&L=",DoubleToString(SessionPnL(),2));
   Print("ELDORADO FINAL STOP: ",reason,
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

   // ── 1단계: 계좌 활성 여부 + 만료일 + customer id ──
   string _url1 = 서버주소+"/rest/v1/customers"
                + "?account_no=eq."+_acc
                + "&is_active=eq.true"
                + "&select=id,expires_at";
   int _http1 = WebRequest("GET",_url1,_rh,8000,_p,_r,_rhs);
   string _body1 = CharArrayToString(_r);
   Print("Eldorado License step1 HTTP=",_http1," body=",_body1);

   if(_http1!=200||_body1=="[]"||StringFind(_body1,"expires_at")<0)
   { licenseStatus="미등록 계좌 또는 라이선스 정지 (HTTP="+IntegerToString(_http1)+")"; return false; }

   int    _ps  = StringFind(_body1,"\"expires_at\":\"")+14;
   string _exp = StringSubstr(_body1,_ps,10);
   StringReplace(_exp,"-",".");
   if(_exp<TimeToString(TimeCurrent(),TIME_DATE))
   { licenseStatus="만료됨 ("+_exp+")"; return false; }

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
   Print("Eldorado License step2 HTTP=",_http2," body=",_body2);

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
int PW = 360;
int PH = 545;   // UI 확대 + MDD 표시 + 버튼영역

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

string MoneyStr(double v)
{
   return (v>=0 ? "+$" : "-$") + DoubleToString(MathAbs(v),2);
}
color MoneyClr(double v) { return v>=0 ? CLR_GREEN : CLR_RED; }

//--- 버튼 생성 (OnInit에서 한 번만 호출)
void CreateButtons()
{
   int bw = 110;  // 버튼 너비(UI 확대)
   int bh = 34;   // 버튼 높이(UI 확대)
   int gap = 8;   // 버튼 간격

   // 버튼 Y 위치: 패널 하단
   int btnY = CY(PH - 33);  // 패널 최하단 (콘텐츠 396 이후)
   bool rightSide = (DashboardCorner==1 || DashboardCorner==3);

   // SELL STOP (왼쪽)
   if(ObjectFind(0,BTN_SELL)<0) ObjectCreate(0,BTN_SELL,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,BTN_SELL,OBJPROP_CORNER,    GetCorner());
   ObjectSetInteger(0,BTN_SELL,OBJPROP_XDISTANCE, rightSide ? DashboardX + bw*3 + gap*2 : DashboardX);
   ObjectSetInteger(0,BTN_SELL,OBJPROP_YDISTANCE, btnY);
   ObjectSetInteger(0,BTN_SELL,OBJPROP_XSIZE,     bw);
   ObjectSetInteger(0,BTN_SELL,OBJPROP_YSIZE,     bh);
   ObjectSetString (0,BTN_SELL,OBJPROP_FONT,      "Arial Bold");
   ObjectSetInteger(0,BTN_SELL,OBJPROP_FONTSIZE,  11);
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
   ObjectSetInteger(0,BTN_BUY,OBJPROP_FONTSIZE,  11);
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
         Print("ELDORADO: SELL ", sellStopped?"STOPPED":"RESUMED");
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
         Print("ELDORADO: BUY ", buyStopped?"STOPPED":"RESUMED");
      }
      RefreshButtonLabels();
   }
   // CLOSE ALL
   if(ObjectFind(0,BTN_CLOSE)>=0 && (bool)ObjectGetInteger(0,BTN_CLOSE,OBJPROP_STATE))
   {
      ObjectSetInteger(0,BTN_CLOSE,OBJPROP_STATE,false);
      if(!finalStopped)
      {
         Print("ELDORADO: CLOSE ALL 실행");
         CloseSide(OP_BUY);
         CloseSide(OP_SELL);
         buyStopped   = true;
         sellStopped  = true;
         finalStopped = true;
         finalReason  = "MANUAL CLOSE ALL";
         finalStopTime= TimeCurrent();
         if(AlertOnFinalStop) Alert("ELDORADO EA: 전체 청산 완료. 신규 진입 중단.");
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
   double sessPnL = equity - g_sessionStartEq;
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
   double tFL  = bFL + sFL;

   datetime today  = iTime(Symbol(),PERIOD_D1,0);
   MqlDateTime md; TimeToStruct(today,md);
   md.day=1; md.hour=0; md.min=0; md.sec=0;
   datetime mon1 = StructToTime(md);

   double todayP = GetHistoryProfit(today, today+86400);
   double yestP  = GetHistoryProfit(today-86400, today);
   double monP   = GetHistoryProfit(mon1, today+86400);
   double todayL = GetHistoryLots(today, today+86400);
   double yestL  = GetHistoryLots(today-86400, today);

   double adx = iADX(Symbol(),PERIOD_CURRENT,PulsePeriod,PRICE_CLOSE,MODE_MAIN,0);
   double diP = iADX(Symbol(),PERIOD_CURRENT,PulsePeriod,PRICE_CLOSE,MODE_PLUSDI,0);
   double diM = iADX(Symbol(),PERIOD_CURRENT,PulsePeriod,PRICE_CLOSE,MODE_MINUSDI,0);
   string trend = adx>=PulseRangeLevel ? (diP>diM?"BULL TREND":"BEAR TREND") : "RANGE";
   color  tc    = trend=="BULL TREND" ? CLR_GREEN : (trend=="BEAR TREND" ? CLR_RED : CLR_GOLD);

   string ft = FinalTakeProfitDollars>0 ? "$"+DoubleToString(FinalTakeProfitDollars,0) : "OFF";
   string fs = FinalStopLossDollars>0   ? "$"+DoubleToString(FinalStopLossDollars,0)   : "OFF";

   string stTxt = "RUNNING";
   color  stClr = CLR_GREEN;
   if(!licenseOK)                   { stTxt="NO LICENSE";   stClr=CLR_RED;  }
   else if(finalStopped)            { stTxt=finalReason;    stClr=CLR_RED;  }
   else if(buyStopped&&sellStopped) { stTxt="ALL STOPPED";  stClr=CLR_GRAY; }
   else if(buyStopped)              { stTxt="BUY STOPPED";  stClr=CLR_GRAY; }
   else if(sellStopped)             { stTxt="SELL STOPPED"; stClr=CLR_GRAY; }

   color CB = C'7,5,1';     // 배경
   color CH = C'18,13,3';   // 헤더 배경
   color CS = C'13,10,2';   // 섹션 배경
   color CL = C'60,45,5';   // 테두리
   color CL2= C'40,30,3';   // 얇은 구분선
   color W  = CLR_WHITE;
   color G  = CLR_GOLD;
   color G2 = CLR_GOLD2;
   color GR = CLR_GREEN;
   color RD = CLR_RED;

   // ─── 행 Y 위치 정의 (위→아래, py=0이 패널 최상단) ───
   int y = 0;   // 현재 y 커서

   // [A] 패널 배경
   R("bg", 0, y, PW+2, PH, CB, CL);

   // [B] 헤더
   R("hd", 0, y, PW+2, 50, CH, CL);
   L("T1","E L D O R A D O",        42, y+6,  18, G,  "Times New Roman Bold");
   L("T2","Made by 어쩌다전업",             88, y+32, 8, G2, "Malgun Gothic");
   L("T3","v9.2",                   315,y+32,  7, G2, "Arial");
   y += 50;

   // [C] 심볼 / 시간 / 스프레드 바
   R("sb", 0, y, PW+2, 22, CS, CL2);
   L("SY",Symbol(),                         8, y+5,  10, W,  "Arial Bold");
   L("TI",TimeToString(TimeCurrent(),TIME_SECONDS), 96, y+6, 9, G2, "Arial");
   L("SP","Spd "+DoubleToString(spread,0),  212,y+6,  9, spread>60?RD:G2, "Arial");
   y += 22;

   // 구분선
   R("l0",0,y,PW+2,1,CL,CL); y+=1;

   // [D] BALANCE / EQUITY / DAY P&L 3분할
   R("ca",  0,  y, PW+2, 40, CS, CL2);
   R("cd1", 93, y, 1,    40, CL2, CL2);
   R("cd2", 188,y, 1,    40, CL2, CL2);
   L("H1","BALANCE",  8,  y+4,  7, G2,"Arial");
   L("H2","EQUITY",  100, y+4,  7, G2,"Arial");
   L("H3","DAY P&L", 196, y+4,  7, G2,"Arial");
   L("V1","$"+DoubleToString(balance,0), 8,  y+18, 11, W, "Arial Bold");
   L("V2","$"+DoubleToString(equity,0),  100,y+18, 11, equity>=balance?GR:RD,"Arial Bold");
   L("V3",MoneyStr(dayPnL),              196,y+18, 11, MoneyClr(dayPnL),"Arial Bold");
   y += 40;

   // [D-2] 오늘 최대 MDD
   R("mdd", 0, y, PW+2, 24, dayPnL>=0?C'10,8,2':C'22,6,6', CL2);
   L("MD1","TODAY MAX MDD", 8, y+5, 8, G2, "Arial Bold");
   L("MD2",MDDStr(),        190, y+5, 10, g_todayMaxMDD>0?RD:G2, "Arial Bold");
   y += 24;

   // 구분선
   R("l1",0,y,PW+2,1,CL,CL); y+=2;

   // [E] LONG / SHORT 테이블 헤더
   R("th", 0, y, PW+2, 20, C'15,11,3', CL2);
   R("tv", 138,y, 1, 20, CL2, CL2);
   L("LH","LONG  (BUY)",  8,  y+4, 9, GR,"Arial Bold");
   L("SH","SHORT (SELL)", 148,y+4, 9, RD,"Arial Bold");
   y += 20;

   // 테이블 행 간격
   int rh = 21;

   // Orders
   R("r0",0,y,PW+2,rh, CB,CL2); R("rv0",138,y,1,rh,CL2,CL2);
   L("L0","Orders",  8,  y+2, 8, G2,"Arial"); L("LV0",IntegerToString(bc),90, y+2,9,W,"Arial Bold");
   L("R0","Orders",148,  y+2, 8, G2,"Arial"); L("RV0",IntegerToString(sc),230,y+2,9,W,"Arial Bold");
   y += rh;

   // Lots
   R("r1",0,y,PW+2,rh,CB,CL2); R("rv1",138,y,1,rh,CL2,CL2);
   L("L1","Lots",    8,  y+2, 8, G2,"Arial"); L("LV1",DoubleToString(bl,2),90, y+2,9,W,"Arial Bold");
   L("R1","Lots",  148,  y+2, 8, G2,"Arial"); L("RV1",DoubleToString(sl,2),230,y+2,9,W,"Arial Bold");
   y += rh;

   // Avg Price
   R("r2",0,y,PW+2,rh,CB,CL2); R("rv2",138,y,1,rh,CL2,CL2);
   L("L2","Avg",     8,  y+2, 8, G2,"Arial"); L("LV2",bAvg>0?DoubleToString(bAvg,Dig()):"-",90, y+2,8,G,"Arial");
   L("R2","Avg",   148,  y+2, 8, G2,"Arial"); L("RV2",sAvg>0?DoubleToString(sAvg,Dig()):"-",230,y+2,8,G,"Arial");
   y += rh;

   // Basket TP
   R("r3",0,y,PW+2,rh,CB,CL2); R("rv3",138,y,1,rh,CL2,CL2);
   L("L3","Basket TP",8,  y+2, 8, G,"Arial"); L("LV3",bTP>0?DoubleToString(bTP,Dig()):"-",90, y+2,8,G,"Arial");
   L("R3","Basket TP",148,y+2, 8, G,"Arial"); L("RV3",sTP>0?DoubleToString(sTP,Dig()):"-",230,y+2,8,G,"Arial");
   y += rh;

   // Float P&L
   R("r4",0,y,PW+2,rh,CB,CL2); R("rv4",138,y,1,rh,CL2,CL2);
   L("L4","Float P&L",8,  y+2, 8, G2,"Arial Bold"); L("LV4",MoneyStr(bFL),90, y+2,10,MoneyClr(bFL),"Arial Bold");
   L("R4","Float P&L",148,y+2, 8, G2,"Arial Bold"); L("RV4",MoneyStr(sFL),230,y+2,10,MoneyClr(sFL),"Arial Bold");
   y += rh;

   // Total Float 강조
   R("rt",0,y,PW+2,20, tFL>=0?C'8,28,8':C'28,6,6', CL);
   L("TF","TOTAL FLOAT P&L", 8,y+3, 9,W,"Arial Bold");
   L("TV",MoneyStr(tFL),      185,y+3,11,MoneyClr(tFL),"Arial Bold");
   y += 20;

   R("l2",0,y,PW+2,1,CL,CL); y+=2;

   // [F] 장세 분석
   R("ab",0,y,PW+2,20,CS,CL2);
   L("A1","ADX "+DoubleToString(adx,1), 8,  y+3, 8, W,"Arial");
   L("A2","DI+ "+DoubleToString(diP,1)+" / DI- "+DoubleToString(diM,1), 88,y+3,8,diP>=diM?GR:RD,"Arial");
   L("A3",trend, 210,y+3, 9,tc,"Arial Bold");
   y += 20;

   R("l3",0,y,PW+2,1,CL,CL); y+=2;

   // [G] PERFORMANCE
   L("PH","PERFORMANCE", 8,y+2, 9,W,"Arial Bold"); y+=20;
   L("PM","Month  "+MoneyStr(monP),  8,y,8,MoneyClr(monP),"Arial");  y+=20;
   L("PY","Yest   "+TimeToString(today-86400,TIME_DATE)+"  "+MoneyStr(yestP)+"  "+DoubleToString(yestL,2)+"lot", 8,y,8,MoneyClr(yestP),"Arial"); y+=20;
   L("PD","Today  "+TimeToString(today,TIME_DATE)+"  "+MoneyStr(todayP)+"  "+DoubleToString(todayL,2)+"lot",     8,y,8,MoneyClr(todayP),"Arial"); y+=20;
   L("PS","Session P&L  "+MoneyStr(sessPnL), 8,y,9,MoneyClr(sessPnL),"Arial Bold"); y+=22;

   R("l4",0,y,PW+2,1,CL,CL); y+=2;

   // [H] 상태 / Final TP·SL
   R("sb2",0,y,PW+2,34,CS,CL2);
   L("ST",stTxt,                          8,y+3, 10,stClr,"Arial Bold");
   L("LI","Lic "+(licenseOK?"OK":"NO"),  210,y+3,  8,licenseOK?GR:RD,"Arial");
   L("FT","FinalTP "+ft+"  /  SL "+fs,    8,y+18, 7, G2,"Arial");
   y += 34;

   R("l5",0,y,PW+2,2,CL,CL); y+=4;

   // 버튼 영역 배경 (버튼은 CreateButtons에서 y 위치 갱신)
   R("bb",0,y,PW+2,36,C'10,7,1',CL);

   // PH를 실제 높이에 맞게 업데이트
   // (버튼은 아래 CreateButtons/RefreshButtonLabels에서 위치 설정)
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
   Comment("ELDORADO EA: 라이선스 확인 중...");
   Sleep(300);

   if(!CheckLicense())
   { Comment("ELDORADO EA: "+licenseStatus); return(INIT_FAILED); }

   licenseOK      = true;
   g_dayStart      = iTime(Symbol(),PERIOD_D1,0);
   g_dayStartEq    = AccountEquity();
   g_sessionStartEq= AccountEquity();
   g_todayPeakEq   = AccountEquity();
   g_todayMaxMDD   = 0.0;
   g_todayMaxMDDPct= 0.0;

   CreateButtons();   // 버튼은 여기서 딱 한 번만 생성
   EventSetTimer(1);
   Print("ELDORADO EA v9.1 OK | Acc=",AccountNumber()," | ",licenseStatus);
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
            Print("Eldorado: 라이선스 정지됨. 전체 청산.");
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
