//+------------------------------------------------------------------+
//| ShootingStar v1.2 KR                                             |
//| MT4 Expert Advisor                                               |
//| TP/SL 고정 선택형 스위칭 마틴 EA                                  |
//+------------------------------------------------------------------+
#property strict

//==============================
// 입력값 - 기본 설정
//==============================
extern string   __기본설정________________ = "===== 기본 설정 =====";
extern double   시작랏                     = 0.01;
extern double   익절값                     = 10.0;
extern double   손절값                     = 10.0;
extern bool     달러기준사용               = true;   // true: 달러 기준, false: pip 기준
extern int      슬리피지                   = 30;
extern int      매직넘버                   = 26052111;
extern string   주문코멘트                 = "ShootingStar";
extern double   사용자Pip배수              = 0.0;    // 0=자동, 필요 시 수동 보정

//==============================
// 입력값 - 시작 / 마틴 설정
//==============================
extern string   __시작및마틴설정__________ = "===== 시작 / 마틴 설정 =====";
extern bool     시작하자마자진입           = true;
extern int      시작방향모드               = 1;      // 1=퀵트렌드, 2=직전캔들방향, 3=EMA20방향
extern bool     마틴사용                   = true;
extern double   마틴배수                   = 1.7;
extern int      최대마틴차수               = 5;
extern bool     손익거리고정모드           = true;   // true: TP/SL 고정, false: TP/SL도 마틴배수 적용
extern int      최대마틴후동작             = 0;      // 0=오늘중지, 1=초기화후재시작, 2=최대차수유지

//==============================
// 입력값 - 리스크 설정
//==============================
extern string   __리스크설정______________ = "===== 리스크 설정 =====";
extern double   최소증거금률               = 200.0;  // 0=사용안함
extern double   일최대손실                 = 0.0;    // 0=사용안함
extern double   일목표수익                 = 0.0;    // 0=사용안함
extern bool     평가손익포함               = false;

//==============================
// 입력값 - 시간 설정
//==============================
extern string   __시간설정________________ = "===== 시간 설정 =====";
extern string   거래시작시간               = "09:00";
extern string   거래종료시간               = "22:00";
extern bool     종료시간전체청산           = true;

//==============================
// 입력값 - UI 설정
//==============================
extern string   __UI설정__________________ = "===== UI 설정 =====";
extern bool     UI패널표시                 = true;
extern int      패널X위치                  = 15;
extern int      패널Y위치                  = 20;
extern bool     차트TP_SL라인표시           = true;

//==============================
// 입력값 - 라이센스 설정
//==============================
extern string   __라이센스설정____________ = "===== 라이센스 설정 =====";
extern bool     라이센스체크사용           = true;   // Axion Research 파트너 페이지 라이센스 체크
extern string   라이센스계좌번호           = "";     // 비우면 현재 계좌 사용
extern string   프로그램이름               = "ShootingStar";

//==============================
// 런타임 상태
//==============================
int      현재차수               = 1;
int      현재티켓               = -1;
int      현재방향               = 0;     // 1=BUY, -1=SELL, 0=없음
bool     사이클활성             = false;
bool     오늘거래중지           = false;
bool     세션종료               = false;
int      마지막일자키           = 0;
string   패널접두사             = "SS_UI_";
bool     라이센스OK             = false;
string   라이센스상태           = "확인 중...";
datetime 마지막라이센스체크     = 0;


//+------------------------------------------------------------------+
//| 라이센스 체크 (Axion Research 파트너 페이지)
//+------------------------------------------------------------------+
bool CheckLicense()
{
   if(!라이센스체크사용)
   {
      라이센스OK = true;
      라이센스상태 = "라이센스 체크 안 함";
      return(true);
   }

   // 1시간마다 재확인
   if(라이센스OK && TimeCurrent() - 마지막라이센스체크 < 3600)
      return(true);

   string acct = 라이센스계좌번호;
   if(StringLen(acct) == 0)
      acct = IntegerToString(AccountNumber());

   string supabaseURL = "https://wmvnearoursbmwjqwzww.supabase.co";
   string anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indtdm5lYXJvdXJzYm13anF3end3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgxNzQ5MjEsImV4cCI6MjA5Mzc1MDkyMX0.MS4iSGIvW4dBi3sd8J3baHLT4TlgUJS5lXwlhJdWYEY";
   string headers = "apikey: " + anonKey + "\r\n"
                  + "Authorization: Bearer " + anonKey + "\r\n"
                  + "Content-Type: application/json";

   // ── 1단계: 계좌 활성 여부 + 만료일 + customer id ──
   string url1 = supabaseURL + "/rest/v1/customers"
               + "?account_no=eq." + acct
               + "&is_active=eq.true"
               + "&select=id,expires_at";

   char req[], res1[];
   string resHeaders;
   int ret1 = WebRequest("GET", url1, headers, 5000, req, res1, resHeaders);

   if(ret1 < 0)
   {
      int err = GetLastError();
      if(err == 4060)
      {
         라이센스상태 = "WebRequest URL 미등록. MT4 설정 필요.";
         Print("라이센스 ERROR: ", 라이센스상태);
         Print("MT4 → 도구 → 옵션 → Expert Advisors → WebRequest URL 추가: ", supabaseURL);
      }
      else
      {
         라이센스상태 = "네트워크 오류 (err=" + IntegerToString(err) + ")";
         Print("라이센스 ERROR: ", 라이센스상태);
      }
      라이센스OK = false;
      return(false);
   }

   string body1 = CharArrayToString(res1);
   Print("라이센스 1단계 응답: ", body1);

   if(ret1 != 200 || body1 == "[]" || StringFind(body1, "expires_at") < 0)
   {
      라이센스상태 = "미등록 계좌 또는 라이센스 정지 (HTTP " + IntegerToString(ret1) + ")";
      Print("라이센스 ERROR: ", 라이센스상태, " | 계좌=", acct);
      라이센스OK = false;
      return(false);
   }

   // 만료일 파싱
   int    _ps  = StringFind(body1, "\"expires_at\":\"") + 14;
   string _exp = StringSubstr(body1, _ps, 10);
   StringReplace(_exp, "-", ".");
   string _today = TimeToString(TimeCurrent(), TIME_DATE);
   if(_exp < _today)
   {
      라이센스상태 = "라이센스 만료됨 (" + _exp + ")";
      Print("라이센스 ERROR: ", 라이센스상태);
      라이센스OK = false;
      return(false);
   }

   // customer id 파싱
   int    _si     = StringFind(body1, "\"id\":\"") + 6;
   int    _ei     = StringFind(body1, "\"", _si);
   string _custId = StringSubstr(body1, _si, _ei - _si);

   // ── 2단계: customer_programs 에서 EA 권한 확인 ──
   string url2 = supabaseURL + "/rest/v1/customer_programs"
               + "?customer_id=eq." + _custId
               + "&select=programs(name)";

   char res2[];
   string resHeaders2;
   int ret2 = WebRequest("GET", url2, headers, 5000, req, res2, resHeaders2);
   string body2 = CharArrayToString(res2);
   Print("라이센스 2단계 응답: ", body2);

   string body2L = body2;
   string progL  = 프로그램이름;
   StringToLower(body2L);
   StringToLower(progL);

   if(ret2 != 200 || StringFind(body2L, progL) < 0)
   {
      라이센스상태 = "이 EA 권한 없음 (" + 프로그램이름 + ") - 파트너 페이지에서 권한 신청 필요";
      Print("라이센스 ERROR: ", 라이센스상태, " | 계좌=", acct);
      라이센스OK = false;
      return(false);
   }

   라이센스OK = true;
   라이센스상태 = "라이센스 OK (만료: " + _exp + ")";
   마지막라이센스체크 = TimeCurrent();
   Print("라이센스 OK: ", 라이센스상태);
   return(true);
}

//+------------------------------------------------------------------+
//| 초기화                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   라이센스OK = false;
   라이센스상태 = "확인 중...";
   
   Comment("ShootingStar: 라이센스 확인 중...");
   Sleep(300);
   
   if(!CheckLicense())
   {
      Comment("ShootingStar: " + 라이센스상태 + "\nAxion Research 파트너 페이지에서 권한을 신청하세요.");
      Alert("ShootingStar: 라이센스 없음. Axion Research 파트너 페이지에서 권한 신청 필요.");
      return(INIT_FAILED);
   }
   
   마지막일자키 = GetDayKey(TimeCurrent());

   int existingTicket = FindLatestOpenTicket();
   if(existingTicket > 0)
   {
      현재티켓   = existingTicket;
      사이클활성 = true;
      if(OrderSelect(existingTicket, SELECT_BY_TICKET))
         현재방향 = (OrderType() == OP_BUY) ? 1 : -1;
   }

   if(UI패널표시)
      CreatePanelObjects();

   // 즉시 진입형
   if(시작하자마자진입 && CountOpenOrders() == 0 && IsTradingTime() && CanOpenNewTrade())
      OpenInitialTrade();

   Print("ShootingStar v1.2 KR initialized. Symbol=", Symbol());
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| 종료                                                             |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeletePanelObjects();
   DeleteTradeLevelLines();
   Comment("");
}

//+------------------------------------------------------------------+
//| 메인 틱                                                          |
//+------------------------------------------------------------------+
void OnTick()
{
   RefreshRates();
   
   // 라이센스 체크 (1시간마다)
   if(라이센스체크사용)
   {
      if(TimeCurrent() - 마지막라이센스체크 >= 3600)
      {
         if(!CheckLicense())
         {
            오늘거래중지 = true;
            Comment("ShootingStar: " + 라이센스상태);
            return;
         }
      }
      
      if(!라이센스OK)
      {
         Comment("ShootingStar: 라이센스 없음. 거래 중지.");
         return;
      }
   }

   CheckNewDay();

   if(IsTradingTime() && 세션종료)
   {
      세션종료 = false;
      Print("새 거래 세션 시작");
   }

   CheckDailyLimits();
   ManageEndTimeClose();
   RecoverOpenTicketIfNeeded();
   ManageClosedOrder();

   if(UI패널표시)
      UpdatePanelObjects();

   if(오늘거래중지 || 세션종료)
      return;

   if(!IsTradingTime())
      return;

   if(!CanOpenNewTrade())
      return;

   if(CountOpenOrders() > 0)
      return;

   if(!사이클활성)
      OpenInitialTrade();
}

//+------------------------------------------------------------------+
//| 첫 진입                                                          |
//+------------------------------------------------------------------+
void OpenInitialTrade()
{
   int orderType = DecideInitialDirection();
   if(orderType != OP_BUY && orderType != OP_SELL)
      return;

   OpenTrade(orderType, 1);
}

int DecideInitialDirection()
{
   RefreshRates();

   // 충분한 캔들 부족 시 현재 캔들 방향 사용
   if(Bars < 25)
      return((Close[1] >= Open[1]) ? OP_BUY : OP_SELL);

   if(시작방향모드 == 2)
   {
      return((Close[1] >= Open[1]) ? OP_BUY : OP_SELL);
   }

   double ema20 = iMA(NULL, 0, 20, 0, MODE_EMA, PRICE_CLOSE, 1);

   if(시작방향모드 == 3)
   {
      return((Close[1] >= ema20) ? OP_BUY : OP_SELL);
   }

   // 기본: 퀵트렌드
   int upScore = 0;
   int downScore = 0;

   if(Close[1] > Open[1]) upScore++; else downScore++;
   if(Close[1] > Close[2]) upScore++; else downScore++;
   if(Close[2] > Close[3]) upScore++; else downScore++;
   if(Close[1] >= ema20) upScore++; else downScore++;

   if(upScore >= downScore)
      return(OP_BUY);

   return(OP_SELL);
}

//+------------------------------------------------------------------+
//| 청산 처리                                                        |
//+------------------------------------------------------------------+
void ManageClosedOrder()
{
   if(현재티켓 <= 0)
      return;

   if(IsTicketOpen(현재티켓))
      return;

   double closedProfit = 0.0;
   int    closedType   = -1;

   if(!GetClosedInfoByTicket(현재티켓, closedProfit, closedType))
      return;

   int previousDirection = (closedType == OP_BUY) ? 1 : -1;

   Print("주문 종료. Ticket=", 현재티켓,
         " Profit=", DoubleToString(closedProfit, 2),
         " Level=", 현재차수);

   현재티켓 = -1;
   현재방향 = 0;

   // 수익 종료: 차수 초기화 후 즉시 재시작
   if(closedProfit >= 0.0)
   {
      ResetCycle();
      Print("수익 종료. 차수 초기화 후 즉시 재진입 대기.");

      if(IsTradingTime() && CanOpenNewTrade() && !오늘거래중지)
         OpenInitialTrade();
      return;
   }

   // 손실 종료: 반대 방향 마틴
   if(!마틴사용)
   {
      ResetCycle();
      if(IsTradingTime() && CanOpenNewTrade() && !오늘거래중지)
         OpenInitialTrade();
      return;
   }

   int nextLevel = 현재차수 + 1;

   if(nextLevel > 최대마틴차수)
   {
      if(최대마틴후동작 == 0)
      {
         ResetCycle();
         오늘거래중지 = true;
         Print("최대 마틴 차수 도달. 오늘 거래 중지.");
         return;
      }
      else if(최대마틴후동작 == 1)
      {
         ResetCycle();
         Print("최대 마틴 차수 도달. 초기화 후 즉시 재시작.");
         if(IsTradingTime() && CanOpenNewTrade() && !오늘거래중지)
            OpenInitialTrade();
         return;
      }
      else
      {
         nextLevel = 최대마틴차수;
         Print("최대 마틴 차수 유지 후 계속 진행.");
      }
   }

   if(!IsTradingTime() || !CanOpenNewTrade())
   {
      ResetCycle();
      return;
   }

   int reverseType = (previousDirection == 1) ? OP_SELL : OP_BUY;
   OpenTrade(reverseType, nextLevel);
}

//+------------------------------------------------------------------+
//| 주문 실행                                                        |
//+------------------------------------------------------------------+
bool OpenTrade(int orderType, int level)
{
   RefreshRates();

   double lot = CalculateLot(level);
   if(lot <= 0.0)
      return(false);

   double tpValue = 익절값;
   double slValue = 손절값;

   double multiplierPower = 1.0;
   if(마틴사용 && level > 1)
      multiplierPower = MathPow(마틴배수, level - 1);

   // 손익거리고정모드 = true  : TP/SL 거리는 항상 입력값으로 고정, 랏만 마틴 증가
   // 손익거리고정모드 = false : TP/SL 거리도 마틴배수에 따라 증가
   if(!손익거리고정모드)
   {
      tpValue = 익절값 * multiplierPower;
      slValue = 손절값 * multiplierPower;
   }

   double tpPips = tpValue;
   double slPips = slValue;

   if(달러기준사용)
   {
      tpPips = MoneyToPips(tpValue, lot);
      slPips = MoneyToPips(slValue, lot);
   }

   AdjustPipsToStopLevel(tpPips);
   AdjustPipsToStopLevel(slPips);

   double price = 0.0;
   double tp    = 0.0;
   double sl    = 0.0;
   double pip   = GetPipSize();

   if(orderType == OP_BUY)
   {
      price = Ask;
      if(tpPips > 0.0) tp = NormalizeDouble(price + tpPips * pip, Digits);
      if(slPips > 0.0) sl = NormalizeDouble(price - slPips * pip, Digits);
   }
   else if(orderType == OP_SELL)
   {
      price = Bid;
      if(tpPips > 0.0) tp = NormalizeDouble(price - tpPips * pip, Digits);
      if(slPips > 0.0) sl = NormalizeDouble(price + slPips * pip, Digits);
   }
   else
   {
      return(false);
   }

   string comment = 주문코멘트 + " " + IntegerToString(level) + "차";
   color arrowColor = (orderType == OP_BUY) ? clrDodgerBlue : clrTomato;

   // 브로커 호환성을 위해 최초 주문은 SL/TP 없이 체결 후,
   // 체결가 기준으로 TP/SL을 OrderModify로 별도 적용한다.
   int ticket = OrderSend(Symbol(), orderType, lot, price, 슬리피지, 0, 0, comment, 매직넘버, 0, arrowColor);

   if(ticket < 0)
   {
      int err = GetLastError();
      Print("OrderSend 실패. Error=", err,
            " Type=", orderType,
            " Lot=", DoubleToString(lot, 2),
            " TPpips=", DoubleToString(tpPips, 2),
            " SLpips=", DoubleToString(slPips, 2));
      ResetLastError();
      return(false);
   }

   double appliedTP = 0.0;
   double appliedSL = 0.0;
   bool stopApplied = ApplyStopsToTicket(ticket, orderType, tpPips, slPips, appliedTP, appliedSL);

   if(!stopApplied)
   {
      Print("TP/SL 수정 실패. 주문은 체결됐지만 손익 라인이 비어 있을 수 있습니다. Ticket=", ticket);
   }

   DeleteTradeLevelLines();
   DrawTradeLevelLines(ticket, appliedTP, appliedSL);

   현재티켓   = ticket;
   현재방향   = (orderType == OP_BUY) ? 1 : -1;
   현재차수   = level;
   사이클활성 = true;

   Print("주문 진입. Ticket=", ticket,
         " Direction=", (orderType == OP_BUY ? "BUY" : "SELL"),
         " Level=", level,
         " Lot=", DoubleToString(lot, 2),
         " TPpips=", DoubleToString(tpPips, 2),
         " SLpips=", DoubleToString(slPips, 2));

   return(true);
}


//+------------------------------------------------------------------+
//| TP/SL 별도 적용 및 차트 보조선                                    |
//+------------------------------------------------------------------+
bool ApplyStopsToTicket(int ticket, int orderType, double tpPips, double slPips, double &appliedTP, double &appliedSL)
{
   if(ticket <= 0)
      return(false);

   RefreshRates();

   if(!OrderSelect(ticket, SELECT_BY_TICKET))
      return(false);

   double openPrice = OrderOpenPrice();
   double pip       = GetPipSize();

   appliedTP = 0.0;
   appliedSL = 0.0;

   if(orderType == OP_BUY)
   {
      if(tpPips > 0.0) appliedTP = NormalizeDouble(openPrice + tpPips * pip, Digits);
      if(slPips > 0.0) appliedSL = NormalizeDouble(openPrice - slPips * pip, Digits);
   }
   else if(orderType == OP_SELL)
   {
      if(tpPips > 0.0) appliedTP = NormalizeDouble(openPrice - tpPips * pip, Digits);
      if(slPips > 0.0) appliedSL = NormalizeDouble(openPrice + slPips * pip, Digits);
   }
   else
   {
      return(false);
   }

   for(int i = 0; i < 3; i++)
   {
      RefreshRates();
      bool result = OrderModify(ticket, openPrice, appliedSL, appliedTP, 0, clrNONE);
      if(result)
         return(true);

      int err = GetLastError();
      Print("OrderModify TP/SL 실패. Retry=", i + 1, " Error=", err,
            " TP=", DoubleToString(appliedTP, Digits),
            " SL=", DoubleToString(appliedSL, Digits));
      ResetLastError();
      Sleep(300);
   }

   return(false);
}

void DeleteTradeLevelLines()
{
   string tpName = 패널접두사 + "TRADE_TP";
   string slName = 패널접두사 + "TRADE_SL";

   if(ObjectFind(0, tpName) >= 0)
      ObjectDelete(0, tpName);

   if(ObjectFind(0, slName) >= 0)
      ObjectDelete(0, slName);
}

void DrawTradeLevelLines(int ticket, double tp, double sl)
{
   if(!차트TP_SL라인표시)
      return;

   string tpName = 패널접두사 + "TRADE_TP";
   string slName = 패널접두사 + "TRADE_SL";

   if(tp > 0.0)
   {
      ObjectCreate(0, tpName, OBJ_HLINE, 0, 0, tp);
      ObjectSetDouble(0, tpName, OBJPROP_PRICE1, tp);
      ObjectSetInteger(0, tpName, OBJPROP_COLOR, C'40,220,140');
      ObjectSetInteger(0, tpName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, tpName, OBJPROP_WIDTH, 1);
      ObjectSetString(0, tpName, OBJPROP_TEXT, "ShootingStar TP");
      ObjectSetInteger(0, tpName, OBJPROP_SELECTABLE, false);
   }

   if(sl > 0.0)
   {
      ObjectCreate(0, slName, OBJ_HLINE, 0, 0, sl);
      ObjectSetDouble(0, slName, OBJPROP_PRICE1, sl);
      ObjectSetInteger(0, slName, OBJPROP_COLOR, C'255,90,90');
      ObjectSetInteger(0, slName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, slName, OBJPROP_WIDTH, 1);
      ObjectSetString(0, slName, OBJPROP_TEXT, "ShootingStar SL");
      ObjectSetInteger(0, slName, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
//| 리스크/제한                                                      |
//+------------------------------------------------------------------+
bool CanOpenNewTrade()
{
   if(최소증거금률 > 0.0)
   {
      double marginLevel = GetMarginLevel();
      if(marginLevel <= 최소증거금률)
      {
         Print("신규 진입 차단 - 증거금률 부족: ", DoubleToString(marginLevel, 2), "%");
         return(false);
      }
   }

   double dailyPnl = GetDailyPnL();

   if(일목표수익 > 0.0 && dailyPnl >= 일목표수익)
      return(false);

   if(일최대손실 > 0.0 && dailyPnl <= -일최대손실)
      return(false);

   return(true);
}

void CheckDailyLimits()
{
   if(오늘거래중지)
      return;

   double dailyPnl = GetDailyPnL();

   if(일목표수익 > 0.0 && dailyPnl >= 일목표수익)
   {
      CloseAllOrders("일 목표수익 도달");
      ResetCycle();
      오늘거래중지 = true;
      return;
   }

   if(일최대손실 > 0.0 && dailyPnl <= -일최대손실)
   {
      CloseAllOrders("일 최대손실 도달");
      ResetCycle();
      오늘거래중지 = true;
      return;
   }
}

//+------------------------------------------------------------------+
//| 시간 로직                                                        |
//+------------------------------------------------------------------+
bool IsTradingTime()
{
   int startMin = 0;
   int endMin   = 0;

   if(!ParseHHMM(거래시작시간, startMin)) startMin = 0;
   if(!ParseHHMM(거래종료시간, endMin))   endMin   = 24 * 60 - 1;

   int nowMin = TimeHour(TimeCurrent()) * 60 + TimeMinute(TimeCurrent());

   if(startMin == endMin)
      return(true);

   if(startMin < endMin)
      return(nowMin >= startMin && nowMin < endMin);

   return(nowMin >= startMin || nowMin < endMin);
}

void ManageEndTimeClose()
{
   if(!종료시간전체청산)
      return;

   if(IsTradingTime())
      return;

   if(CountOpenOrders() <= 0)
      return;

   CloseAllOrders("거래 시간 종료");
   ResetCycle();
   세션종료 = true;
}

bool ParseHHMM(string text, int &minutes)
{
   int colon = StringFind(text, ":");
   if(colon < 0)
      return(false);

   int h = (int)StrToInteger(StringSubstr(text, 0, colon));
   int m = (int)StrToInteger(StringSubstr(text, colon + 1));

   if(h < 0 || h > 23 || m < 0 || m > 59)
      return(false);

   minutes = h * 60 + m;
   return(true);
}

//+------------------------------------------------------------------+
//| 일자 리셋                                                        |
//+------------------------------------------------------------------+
void CheckNewDay()
{
   int todayKey = GetDayKey(TimeCurrent());
   if(todayKey == 마지막일자키)
      return;

   마지막일자키 = todayKey;
   오늘거래중지 = false;
   세션종료     = false;

   if(CountOpenOrders() == 0)
      ResetCycle();
}

int GetDayKey(datetime t)
{
   return(TimeYear(t) * 1000 + TimeDayOfYear(t));
}

//+------------------------------------------------------------------+
//| 주문 유틸                                                        |
//+------------------------------------------------------------------+
int CountOpenOrders()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != 매직넘버)
         continue;

      if(OrderType() == OP_BUY || OrderType() == OP_SELL)
         count++;
   }
   return(count);
}

int FindLatestOpenTicket()
{
   int latestTicket = -1;
   datetime latestTime = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != 매직넘버)
         continue;

      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      if(OrderOpenTime() >= latestTime)
      {
         latestTime   = OrderOpenTime();
         latestTicket = OrderTicket();
      }
   }
   return(latestTicket);
}

bool IsTicketOpen(int ticket)
{
   if(ticket <= 0)
      return(false);

   if(!OrderSelect(ticket, SELECT_BY_TICKET))
      return(false);

   return(OrderCloseTime() == 0);
}

bool GetClosedInfoByTicket(int ticket, double &profit, int &closedType)
{
   if(ticket <= 0)
      return(false);

   if(!OrderSelect(ticket, SELECT_BY_TICKET))
      return(false);

   if(OrderCloseTime() <= 0)
      return(false);

   if(OrderSymbol() != Symbol() || OrderMagicNumber() != 매직넘버)
      return(false);

   if(OrderType() != OP_BUY && OrderType() != OP_SELL)
      return(false);

   profit     = OrderProfit() + OrderSwap() + OrderCommission();
   closedType = OrderType();
   return(true);
}

void RecoverOpenTicketIfNeeded()
{
   if(현재티켓 > 0 && IsTicketOpen(현재티켓))
      return;

   if(현재티켓 > 0)
      return;

   int ticket = FindLatestOpenTicket();
   if(ticket <= 0)
      return;

   현재티켓   = ticket;
   사이클활성 = true;

   if(OrderSelect(ticket, SELECT_BY_TICKET))
      현재방향 = (OrderType() == OP_BUY) ? 1 : -1;
}

bool CloseAllOrders(string reason)
{
   bool allClosed = true;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != 매직넘버)
         continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL)
         continue;

      RefreshRates();
      double closePrice = (type == OP_BUY) ? Bid : Ask;

      bool result = OrderClose(OrderTicket(), OrderLots(), closePrice, 슬리피지, clrGray);
      if(!result)
      {
         int err = GetLastError();
         Print("OrderClose 실패. Ticket=", OrderTicket(), " Error=", err, " Reason=", reason);
         ResetLastError();
         allClosed = false;
      }
   }

   현재티켓 = -1;
   현재방향 = 0;
   return(allClosed);
}

//+------------------------------------------------------------------+
//| 계산 유틸                                                        |
//+------------------------------------------------------------------+
double GetPipSize()
{
   if(사용자Pip배수 > 0.0)
      return(Point * 사용자Pip배수);

   if(Digits == 3 || Digits == 5)
      return(Point * 10.0);

   return(Point);
}

double MoneyToPips(double money, double lot)
{
   if(money <= 0.0 || lot <= 0.0)
      return(0.0);

   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);

   if(tickValue <= 0.0 || tickSize <= 0.0)
      return(money);

   double priceMove = money * tickSize / (tickValue * lot);
   double pips      = priceMove / GetPipSize();

   return(MathAbs(pips));
}

void AdjustPipsToStopLevel(double &pips)
{
   if(pips <= 0.0)
      return;

   double minStopPrice = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
   double minPips      = minStopPrice / GetPipSize();

   if(minPips > 0.0 && pips < minPips)
      pips = minPips;
}

double CalculateLot(int level)
{
   double lot = 시작랏;

   if(마틴사용 && level > 1)
      lot = 시작랏 * MathPow(마틴배수, level - 1);

   return(NormalizeLot(lot));
}

double NormalizeLot(double lot)
{
   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

   if(lotStep <= 0.0)
      lotStep = 0.01;

   if(lot < minLot)
      lot = minLot;

   if(lot > maxLot)
      lot = maxLot;

   double steps = MathFloor((lot - minLot) / lotStep + 0.0000001);
   double normalized = minLot + steps * lotStep;

   return(NormalizeDouble(normalized, LotDigits(lotStep)));
}

int LotDigits(double lotStep)
{
   int digits = 0;
   double step = lotStep;

   while(step < 1.0 && digits < 8)
   {
      step *= 10.0;
      digits++;
   }

   return(digits);
}

double GetMarginLevel()
{
   if(AccountMargin() <= 0.0)
      return(999999.0);

   return(AccountEquity() / AccountMargin() * 100.0);
}

double GetDailyPnL()
{
   double pnl = GetClosedPnLToday();

   if(평가손익포함)
      pnl += GetFloatingPnL();

   return(pnl);
}

double GetClosedPnLToday()
{
   double pnl = 0.0;
   datetime dayStart = StrToTime(TimeToString(TimeCurrent(), TIME_DATE));

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != 매직넘버)
         continue;

      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      if(OrderCloseTime() < dayStart)
         continue;

      pnl += OrderProfit() + OrderSwap() + OrderCommission();
   }

   return(pnl);
}

double GetFloatingPnL()
{
   double pnl = 0.0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != 매직넘버)
         continue;

      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      pnl += OrderProfit() + OrderSwap() + OrderCommission();
   }

   return(pnl);
}

//+------------------------------------------------------------------+
//| 상태 초기화                                                      |
//+------------------------------------------------------------------+
void ResetCycle()
{
   사이클활성 = false;
   현재차수   = 1;
   현재티켓   = -1;
   현재방향   = 0;
   DeleteTradeLevelLines();
}

//+------------------------------------------------------------------+
//| UI 패널                                                          |
//+------------------------------------------------------------------+
void CreatePanelObjects()
{
   string bg = 패널접두사 + "BG";
   if(ObjectFind(0, bg) < 0)
   {
      ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, 패널X위치);
      ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, 패널Y위치);
      ObjectSetInteger(0, bg, OBJPROP_XSIZE, 360);
      ObjectSetInteger(0, bg, OBJPROP_YSIZE, 210);
      ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, C'12,24,46');
      ObjectSetInteger(0, bg, OBJPROP_COLOR, C'60,82,120');
      ObjectSetInteger(0, bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, bg, OBJPROP_BACK, false);
      ObjectSetInteger(0, bg, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, bg, OBJPROP_HIDDEN, true);
   }

   CreateLabel(패널접두사 + "TITLE", 18, 10, "SHOOTINGSTAR", 12, clrWhite, true);
   CreateLabel(패널접두사 + "SUB",   18, 30, "Trend Recovery Engine", 9, C'180,196,220', false);
   CreateLabel(패널접두사 + "L1",    18, 58, "", 9, clrWhite, false);
   CreateLabel(패널접두사 + "L2",    18, 78, "", 9, clrWhite, false);
   CreateLabel(패널접두사 + "L3",    18, 98, "", 9, clrWhite, false);
   CreateLabel(패널접두사 + "L4",    18,118, "", 9, clrWhite, false);
   CreateLabel(패널접두사 + "L5",    18,138, "", 9, clrWhite, false);
   CreateLabel(패널접두사 + "L6",    18,158, "", 9, clrWhite, false);
   CreateLabel(패널접두사 + "L7",    18,178, "", 9, clrWhite, false);
}

void CreateLabel(string name, int x, int y, string text, int size, color clr, bool bold)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 패널X위치 + x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 패널Y위치 + y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void UpdatePanelObjects()
{
   if(!UI패널표시)
      return;

   string 방향텍스트 = "대기";
   color  방향색상  = C'200,200,200';

   if(현재방향 == 1)
   {
      방향텍스트 = "매수";
      방향색상 = C'64,156,255';
   }
   else if(현재방향 == -1)
   {
      방향텍스트 = "매도";
      방향색상 = C'255,110,110';
   }

   double pnl = GetDailyPnL();
   color pnlColor = (pnl >= 0.0) ? C'40,220,140' : C'255,110,110';

   string 손익방식 = 손익거리고정모드 ? "고정 TP/SL · 랏만 마틴" : "TP/SL 배수 증가";
   string 기준방식 = 달러기준사용 ? "달러 기준" : "PIP 기준";
   string 시작모드 = "퀵트렌드";
   if(시작방향모드 == 2) 시작모드 = "직전캔들";
   if(시작방향모드 == 3) 시작모드 = "EMA20";
   string 운영상태 = 오늘거래중지 ? "오늘중지" : (세션종료 ? "세션종료" : "운영중");

   SetLabelText(패널접두사 + "L1", "종목: " + Symbol() + "   |   방향: " + 방향텍스트 + "   |   상태: " + 운영상태, 방향색상);
   SetLabelText(패널접두사 + "L2", "차수: " + IntegerToString(현재차수) + " / " + IntegerToString(최대마틴차수) + "   |   주문: " + IntegerToString(CountOpenOrders()) + "   |   마틴: x" + DoubleToString(마틴배수, 2), clrWhite);
   SetLabelText(패널접두사 + "L3", "손익 방식: " + 손익방식 + "   |   " + 기준방식, C'180,196,220');
   SetLabelText(패널접두사 + "L4", "TP/SL 입력값: " + DoubleToString(익절값, 1) + " / " + DoubleToString(손절값, 1), C'180,196,220');
   SetLabelText(패널접두사 + "L5", "일 손익: " + DoubleToString(pnl, 2) + "   |   증거금률: " + DoubleToString(GetMarginLevel(), 1) + "%", pnlColor);
   SetLabelText(패널접두사 + "L6", "시작 방향: " + 시작모드 + "   |   시작랏: " + DoubleToString(시작랏, 2), C'180,196,220');
   SetLabelText(패널접두사 + "L7", "거래시간: " + 거래시작시간 + " ~ " + 거래종료시간 + "   |   MaxLoss: " + DoubleToString(일최대손실, 1), C'180,196,220');
}

void SetLabelText(string name, string text, color clr)
{
   if(ObjectFind(0, name) < 0)
      return;

   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void DeletePanelObjects()
{
   string names[10];
   names[0] = 패널접두사 + "BG";
   names[1] = 패널접두사 + "TITLE";
   names[2] = 패널접두사 + "SUB";
   names[3] = 패널접두사 + "L1";
   names[4] = 패널접두사 + "L2";
   names[5] = 패널접두사 + "L3";
   names[6] = 패널접두사 + "L4";
   names[7] = 패널접두사 + "L5";
   names[8] = 패널접두사 + "L6";
   names[9] = 패널접두사 + "L7";

   for(int i = 0; i < ArraySize(names); i++)
   {
      if(ObjectFind(0, names[i]) >= 0)
         ObjectDelete(0, names[i]);
   }
}
//+------------------------------------------------------------------+
