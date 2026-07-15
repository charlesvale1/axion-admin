//+------------------------------------------------------------------+
//|                                          Bolinger_past.mq4      |
//|        Bollinger close breakout/re-entry + direct grid Martin     |
//+------------------------------------------------------------------+
//|                                                                  |
//|  Bolinger_past - GRID LOGIC                                      |
//|  - Initial entry: Bollinger close breakout -> close re-entry.     |
//|  - Averaging: when Distance_Point is reached, next order opens.   |
//|  - No second Bollinger re-entry confirmation for averaging.       |
//|  - This is a direct-distance grid martingale structure.     |
//|                                                                  |
#property strict
#property version   "1.30"
#property description "Bolinger_past - direct LOT1~LOT10 order size settings"
#property description "Distance reached -> immediate next grid entry"

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
input bool   ShowKoreanRiskPopup = true;  // EA 시작 시 한국어 투자위험 고지
input bool   DrawBandTouchMarks = true;

input string SETTING__________12 = "============ LICENSE / SERVER ============";
input bool   SendBalance = true;          // 잔고 서버 전송
input int    SendBalanceMinutes = 5;      // 잔고 전송 주기(분)

bool     g_running = false;
datetime g_lastBarTime = 0;
bool     g_upperBreakoutArmed = false;
bool     g_lowerBreakoutArmed = false;
datetime g_upperBreakoutTime = 0;
datetime g_lowerBreakoutTime = 0;

string PANEL_BG  = "BOLINGER_PAST_PANEL_BG";
string PANEL_TOP = "BOLINGER_PAST_PANEL_TOP";
string PANEL_TX  = "BOLINGER_PAST_PANEL_TX_";
string MARK_PREFIX = "BOLINGER_PAST_MARK_";
string BAND_PREFIX = "BOLINGER_PAST_BAND_";

// =====================================================
// License System
// =====================================================
string   g_ProgramName  = "Bolinger_past";
string   g_ServerUrl    = "https://wmvnearoursbmwjqwzww.supabase.co";
string   g_ApiKey       = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indtdm5lYXJvdXJzYm13anF3end3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgxNzQ5MjEsImV4cCI6MjA5Mzc1MDkyMX0.MS4iSGIvW4dBi3sd8J3baHLT4TlgUJS5lXwlhJdWYEY";
bool     g_licenseOK    = false;
datetime g_lastLicCheck = 0;
datetime g_lastBalSend  = 0;
string   g_licStatusTxt = "확인 중...";
bool     g_riskAccepted = false;
bool     g_riskShown    = false;

bool BPShowRiskPopup()
{
   if(!ShowKoreanRiskPopup) return(true);

   string msg = "";
   msg += "EA 시작 전 필수 투자위험 및 책임 고지\n\n";
   msg += "본 EA(Bolinger_past)는 볼린저밴드 돌파 신호로 진입한 뒤, 설정 간격에 도달할 때마다 분할 주문을 적층하는 그리드 방식의 자동매매 보조 소프트웨어이며, 수익을 보장하지 않습니다.\n\n";
   msg += "본 시스템은 손실 중인 방향에 주문을 계속 추가하는 구조이므로, 한 방향 추세가 길게 이어질 경우 보유 수량과 평가손실이 빠르게 확대될 수 있습니다.\n\n";
   msg += "레버리지 상품은 시장 변동성, 스프레드 확대, 슬리피지, 체결 지연, 서버 장애, 증거금 부족, 마진콜, 강제청산 등으로 인해 원금을 초과하는 손실이 발생할 수 있습니다.\n\n";
   msg += "동시 보유 주문이 많아 증거금 소진 위험이 있으므로, 충분한 자본의 계좌에서 차수(MaxSteps)와 주문 수량을 자금 규모에 맞게 설정해 운용해야 합니다.\n\n";
   msg += "기본 설정값, 백테스트, 과거 운용 결과, 예시 수익률은 참고용 정보이며 미래 수익이나 손실 제한을 보장하지 않습니다.\n\n";
   msg += "본 시스템은 투자자문, 투자일임, 매수/매도 추천을 목적으로 하지 않으며, 설치, 설정, 실행, 중지, 청산의 최종 판단과 책임은 전적으로 이용자 본인에게 있습니다.\n\n";
   msg += "위 내용을 이해했으며 본인 판단과 책임으로 EA를 실행합니다.\n\n";
   msg += "동의하시면 예 버튼을 눌러 시작하세요.";

   int answer = MessageBox(msg, "Bolinger_past 투자위험 고지", MB_YESNO | MB_ICONWARNING);
   return(answer == IDYES);
}

bool BPCheckLicense()
{
   if(g_licenseOK && (TimeCurrent() - g_lastLicCheck) < 3600)
      return(true);

   string acct = IntegerToString(AccountNumber());

   string url = g_ServerUrl + "/rest/v1/customers"
              + "?account_no=eq." + acct
              + "&program_name=eq." + g_ProgramName
              + "&is_active=eq.true"
              + "&select=expires_at";

   string headers = "apikey: " + g_ApiKey + "\r\n"
                  + "Authorization: Bearer " + g_ApiKey + "\r\n"
                  + "Content-Type: application/json\r\n";

   char post[]; char result[]; string rh;
   ResetLastError();
   int http = WebRequest("GET", url, headers, 10000, post, result, rh);

   if(http < 0)
   {
      int err = GetLastError();
      g_licStatusTxt = (err==4060) ? "URL 미등록" : "연결 오류 (" + IntegerToString(err) + ")";
      Print("[License] Program: ", g_ProgramName, " | Account: ", acct, " | ERROR err=", IntegerToString(err));
      g_licenseOK = false;
      return(false);
   }

   string body = CharArrayToString(result);
   Print("[License] Program: ", g_ProgramName, " | Account: ", acct,
         " | HTTP: ", IntegerToString(http), " | Body: ", body);

   if(http != 200 || body == "[]" || StringFind(body, "expires_at") < 0)
   {
      g_licStatusTxt = "미등록 계좌 (HTTP=" + IntegerToString(http) + ")";
      g_licenseOK = false;
      return(false);
   }

   int s = StringFind(body, "\"expires_at\":\"") + 14;
   string exp = StringSubstr(body, s, 10);
   StringReplace(exp, "-", ".");

   if(exp < TimeToString(TimeCurrent(), TIME_DATE))
   {
      g_licStatusTxt = "만료됨 (" + exp + ")";
      g_licenseOK = false;
      return(false);
   }

   g_licenseOK    = true;
   g_lastLicCheck = TimeCurrent();
   g_licStatusTxt = "정상 (" + exp + "까지)";
   Print("[License] OK until ", exp);
   return(true);
}

// force=true 이면 주기와 무관하게 즉시 전송 (청산 직후 등)
void BPSendBalance(bool force = false)
{
   if(!SendBalance || !g_licenseOK) return;

   int interval = SendBalanceMinutes * 60;
   if(interval < 60) interval = 60;

   // 틱이 없어도 주기가 흐르도록 TimeCurrent 대신 TimeLocal 사용
   if(!force && g_lastBalSend > 0 && (TimeLocal() - g_lastBalSend) < interval)
      return;

   string acct = IntegerToString(AccountNumber());
   string body = "{\"account_no\":\"" + acct + "\""
               + ",\"balance\":" + DoubleToString(AccountBalance(), 2)
               + ",\"equity\":"  + DoubleToString(AccountEquity(), 2)
               + ",\"profit\":"  + DoubleToString(AccountEquity() - AccountBalance(), 2)
               + "}";

   string headers = "Content-Type: application/json\r\n"
                  + "apikey: " + g_ApiKey + "\r\n"
                  + "Authorization: Bearer " + g_ApiKey + "\r\n"
                  + "Prefer: return=minimal\r\n";

   char post[]; char result[]; string rh;
   StringToCharArray(body, post, 0, StringLen(body));
   ArrayResize(post, StringLen(body));

   ResetLastError();
   int http = WebRequest("POST", g_ServerUrl + "/rest/v1/balance_logs", headers, 5000, post, result, rh);

   // 실패해도 갱신 — 오류 시 매 초 재시도하는 것을 막는다
   g_lastBalSend = TimeLocal();

   if(http < 0)
      Print("[Balance] Account: ", acct, " | ERROR err=", IntegerToString(GetLastError()));
   else if(http != 200 && http != 201 && http != 204)
      Print("[Balance] Account: ", acct, " | HTTP: ", IntegerToString(http),
            " | Body: ", CharArrayToString(result));
}
// =====================================================

int OnInit()
{
   g_running = AutoStart;

   if(SetChartStyle)
      SetupChart();

   if(ShowAutoBollingerBands)
      DrawAutoBollingerBands();

   Print("Bolinger_past initialized / Symbol=", Symbol(),
         " / Magic=", MagicNumber,
         " / LOT1=", DoubleToString(LOT1, 2),
         " / BB=", BBperiod, ", ", DoubleToString(BBdeviation, 2));

   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeletePanel();
   DeleteBandObjects();
   Print("Bolinger_past deinitialized / reason=", reason);
}

void OnTimer()
{
   // 틱이 유실되거나 OnTick이 굶는 구간에서도 최소 1초 해상도로 바스켓을 관리한다.
   // MT4는 처리 중 도착한 틱을 큐잉하지 않고 버리므로, CheckSideBasket이 유일한
   // 청산 장치인 이상 이중화가 필요하다.
   CheckSideBasket(OP_BUY);
   CheckSideBasket(OP_SELL);

   // 위험 고지 (최초 1회)
   if(!g_riskShown)
   {
      g_riskAccepted = BPShowRiskPopup();
      g_riskShown    = true;
   }

   BPCheckLicense();

   BPSendBalance();
}

//+------------------------------------------------------------------+
//| 매매 허용 조건. 청산은 이 게이트와 무관하게 항상 실행된다.        |
//+------------------------------------------------------------------+
bool TradingAllowed()
{
   if(!g_running)      return false;
   if(!g_licenseOK)    return false;
   if(!g_riskAccepted) return false;
   return true;
}

void OnTick()
{
   // 이 EA는 브로커측 TP/SL을 심지 않는다(OpenOrder의 sl=0, tp=0).
   // CheckSideBasket이 유일한 청산 장치이므로 라이선스·동의 상태와 무관하게
   // 항상 실행해야 보유 그리드가 방치되지 않는다.
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

   // 청산으로 잔고가 확정되었으므로 주기와 무관하게 즉시 전송
   BPSendBalance(true);
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

   SetPanelLine(line++, "Bolinger_past", clrWhite, 15);
   SetPanelLine(line++, "LICENSE       : " + g_licStatusTxt, g_licenseOK ? clrLime : clrTomato, 9);
   SetPanelLine(line++, "SYMBOL / TF   : " + Symbol() + " / " + IntegerToString(Period()), clrWhite, 9);
   SetPanelLine(line++, "STATUS        : " + (g_running ? "RUNNING" : "PAUSED"), g_running ? clrLime : clrTomato, 9);
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
