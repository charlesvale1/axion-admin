
// =====================================================
// License System
// =====================================================
string  g_ProgramName   = "DQL_EA";
bool    g_licenseOK     = false;
int     g_licCheckCount = 0;
datetime g_lastLicCheck = 0;
bool     g_riskAccepted = false;
bool     g_riskShown    = false;
bool     g_licInitDone  = false;
string   g_licStatusTxt = "확인 중...";

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
//must set MagicNumber up by tens
//SELLLIMIT be deleted automatically after 5 mins.
//EquityStart & EquityUp need to be set only on 1 symbol chart
//Recommend to update EquityStart frome time to time

//5: Total Close & individual close
//4: Multi Averaging variable Lot
//3: variable Distance 
//2: Multi Averaging
//1: Two-way Averaging



//사용자외부변수 설정
extern string EA_setting = "============ JARVIS ULTRA v1.0 ============";

//extern string EA__setting = "============ EA__setting ============";
extern int MAGIC_No = 10;
extern double Lots = 0.01;

//extern string EA___setting = "============ EA___setting ============";
extern int SpreadBlock = 35;

//extern string EA____setting = "============ EA____setting ============";
extern int EquityLimit = 0; //must set the same
extern double MarginLevelEntryStop = 500; //below this margin level, EA stops new entries


//광역(글로벌)변수 설정
 int NextLevel = 4; 

 int Distance_0 = 25,Distance_1 = 24,Distance_2 = 23,Distance_3 = 22,Distance_4 = 21;
 int Distance_5 = 20,Distance_6 = 19,Distance_7 = 18,Distance_8 = 17,Distance_9 = 16;

//START / STOP button variables
bool EA_ManualRun = true;
string BTN_START = "JARVIS_ULTRA_START";
string BTN_STOP  = "JARVIS_ULTRA_STOP";

//margin level calculation
double GetMarginLevel()
{
   if(AccountMargin() <= 0) return(999999);
   return(AccountEquity() / AccountMargin() * 100.0);
}

//button creation
void CreateButton(string name,string text,int x,int y,color bg)
{
   if(ObjectFind(0,name) < 0)
      ObjectCreate(0,name,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,80);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,24);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,10);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
}

bool JarvisShowRiskPopup()
{
   string msg = "";
   msg += "EA 시작 전 필수 투자위험 및 책임 고지\n\n";
   msg += "본 EA는 자동매매 보조 프로그램이며 수익을 보장하지 않습니다.\n\n";
   msg += "레버리지 상품은 시장 변동성, 스프레드 확대, 슬리피지, 체결 지연, 서버 장애, 증거금 부족, 마진콜, 강제청산 등으로 인해 큰 손실이 발생할 수 있습니다.\n\n";
   msg += "기본 설정값, 백테스트, 과거 운용 결과, 예시 수익률, 시뮬레이션 자료는 참고용 정보이며 미래 수익이나 손실 제한을 보장하지 않습니다.\n\n";
   msg += "본 프로그램은 투자권유, 투자자문, 투자일임, 대리매매, 계좌운용을 목적으로 하지 않습니다.\n\n";
   msg += "EA의 설치, 설정, 실행, 중지, 포지션 청산, 운용 여부에 대한 최종 판단과 책임은 전적으로 이용자 본인에게 있습니다.\n\n";
   msg += "본인의 투자 경험, 재무상태, 위험 감내 수준, 계좌 상황을 충분히 고려한 뒤 사용 여부를 결정해야 합니다.\n\n";
   msg += "위 내용을 이해했으며 본인 판단과 책임으로 EA를 실행합니다.\n\n";
   msg += "동의하시면 예 버튼을 눌러 시작하세요.";

   int answer = MessageBox(msg, "JARVIS ULTRA 투자위험 고지", MB_YESNO | MB_ICONWARNING);
   return(answer == IDYES);
}

void DrawControlButtons()
{
   CreateButton(BTN_START,"START",10,80,clrDodgerBlue);
   CreateButton(BTN_STOP,"STOP",95,80,clrCrimson);
}

int init()
{
   DrawControlButtons();
   EventSetTimer(1);
   return(0);
}

void deinit()
{
   EventKillTimer();
   ObjectDelete(0,BTN_START);
   ObjectDelete(0,BTN_STOP);
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

void OnTimer()
{
   CheckBalanceStop();   if(g_balanceHalt) return;

   // 위험 고지 (최초 1회)
   if(!g_riskShown)
   {
      g_riskAccepted = JarvisShowRiskPopup();
      g_riskShown    = true;
   }

   // 라이센스 확인 (함수 내부에서 1시간 캐싱)
   AxionCheckLicense();
   g_licInitDone = true;

   if(!g_riskAccepted)        g_licStatusTxt = "위험고지 미동의 - 정지";
   else if(!g_licenseOK)      g_licStatusTxt = "라이센스 오류 - 계좌 " + IntegerToString(AccountNumber());
   else                       g_licStatusTxt = "정상";
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(sparam == BTN_START)
        {
         EA_ManualRun = true;
         ObjectSetInteger(0,BTN_START,OBJPROP_STATE,false);
        }
      if(sparam == BTN_STOP)
        {
         EA_ManualRun = false;
         ObjectSetInteger(0,BTN_STOP,OBJPROP_STATE,false);
        }
     }
}



 

 
 
//start구문 시작
int start()
{
DrawControlButtons();

   // 위험고지 미동의 또는 라이센스 미확인/오류 시 매매 차단
   if(!g_licInitDone || !g_riskAccepted || !g_licenseOK)
   {
      Comment(
      "+++++++++++++++++++++++++++++++","\n",
      "JARVIS RANDOMWALK EA","\n",
      "상태= ", g_licStatusTxt,"\n",
      "+++++++++++++++++++++++++++++++","\n"
      );
      return(0);
   }

//계좌번호지정 
/*
if(AccountNumber() != 346953)
  {
   Comment(
   "Please check your MT4 account number.""\n"
   );    
   return(0);
  }
*/

//EA구동시간봉챠트 지정
if(Period() != PERIOD_H1)
  {
   Comment(
   "Please change the timeframe to H1.""\n"
   );     
   return(0);
  }

//데모/라이브계좌전용 지정
if(IsTesting() == true)
  {
   return(0);
  }
     

//랏사이즈 결정 변수 정의
double Lot_0 = Lots;
double Lot_1 = Lots+Lots;
double Lot_2 = Lots+Lots+Lots;
double Lot_3 = Lots+Lots+Lots+Lots;
double Lot_4 = Lots+Lots+Lots+Lots+Lots;
double Lot_5 = Lots+Lots+Lots+Lots+Lots+Lots;
double Lot_6 = Lots+Lots+Lots+Lots+Lots+Lots+Lots;
double Lot_7 = Lots+Lots+Lots+Lots+Lots+Lots+Lots+Lots;
double Lot_8 = Lots+Lots+Lots+Lots+Lots+Lots+Lots+Lots+Lots;
double Lot_9 = Lots+Lots+Lots+Lots+Lots+Lots+Lots+Lots+Lots+Lots;


//내부변수들 정의
int ticket;
bool SelectCheck;

//매수오더 내부변수들 정의
double Bcount_0=0,Scount_0=0,Bcount_1=0,Scount_1=0,Bcount_2=0,Scount_2=0,Bcount_3=0,Scount_3=0,Bcount_4=0,Scount_4=0,Bcount_5=0,Scount_5=0;
double Bprofit_0=0,Sprofit_0=0,Bprofit_1=0,Sprofit_1=0,Bprofit_2=0,Sprofit_2=0,Bprofit_3=0,Sprofit_3=0,Bprofit_4=0,Sprofit_4=0,Bprofit_5=0,Sprofit_5=0;
double Bopen_0=0,Sopen_0=0,Bopen_1=0,Sopen_1=0,Bopen_2=0,Sopen_2=0,Bopen_3=0,Sopen_3=0,Bopen_4=0,Sopen_4=0,Bopen_5=0,Sopen_5=0;

//매도오더 내부변수들 정의
double Bcount_6=0,Scount_6=0,Bcount_7=0,Scount_7=0,Bcount_8=0,Scount_8=0,Bcount_9=0,Scount_9=0;
double Bprofit_6=0,Sprofit_6=0,Bprofit_7=0,Sprofit_7=0,Bprofit_8=0,Sprofit_8=0,Bprofit_9=0,Sprofit_9=0;
double Bopen_6=0,Sopen_6=0,Bopen_7=0,Sopen_7=0,Bopen_8=0,Sopen_8=0,Bopen_9=0,Sopen_9=0;

//예약가(펜딩/지정가)오더 카운팅을 위한 내부변수 정의
int SLcount=0;


//오더 정보 관리를 위한for구문
for(int i=0; i<OrdersTotal(); i++)
  {
   SelectCheck=OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
   if(OrderMagicNumber()==MAGIC_No)
     {
      if(OrderType()==OP_BUY)
        {
         Bcount_0++; //매수오더개수
         Bprofit_0 = Bprofit_0 + OrderProfit() + OrderSwap() + OrderCommission(); //매수오더손익합
         Bopen_0 = OrderOpenPrice(); //최근 매수오더 가격
        }
      if(OrderType()==OP_SELL)
        {
         Scount_0++;
         Sprofit_0 = Sprofit_0 + OrderProfit() + OrderSwap() + OrderCommission();
         Sopen_0 = OrderOpenPrice();
        }
     }
   if(OrderMagicNumber()==MAGIC_No+1)
     {
      if(OrderType()==OP_BUY)
        {
         Bcount_1++;
         Bprofit_1 = Bprofit_1 + OrderProfit() + OrderSwap() + OrderCommission();
         Bopen_1 = OrderOpenPrice();
        }
      if(OrderType()==OP_SELL)
        {
         Scount_1++;
         Sprofit_1 = Sprofit_1 + OrderProfit() + OrderSwap() + OrderCommission();
         Sopen_1 = OrderOpenPrice();
        }
     }   
   if(OrderMagicNumber()==MAGIC_No+2)
     {
      if(OrderType()==OP_BUY)
        {
         Bcount_2++;
         Bprofit_2 = Bprofit_2 + OrderProfit() + OrderSwap() + OrderCommission();
         Bopen_2 = OrderOpenPrice();
        }
      if(OrderType()==OP_SELL)
        {
         Scount_2++;
         Sprofit_2 = Sprofit_2 + OrderProfit() + OrderSwap() + OrderCommission();
         Sopen_2 = OrderOpenPrice();
        }
     } 
   if(OrderMagicNumber()==MAGIC_No+3)
     {
      if(OrderType()==OP_BUY)
        {
         Bcount_3++;
         Bprofit_3 = Bprofit_3 + OrderProfit() + OrderSwap() + OrderCommission();
         Bopen_3 = OrderOpenPrice();
        }
      if(OrderType()==OP_SELL)
        {
         Scount_3++;
         Sprofit_3 = Sprofit_3 + OrderProfit() + OrderSwap() + OrderCommission();
         Sopen_3 = OrderOpenPrice();
        }
     }    
   if(OrderMagicNumber()==MAGIC_No+4)
     {
      if(OrderType()==OP_BUY)
        {
         Bcount_4++;
         Bprofit_4 = Bprofit_4 + OrderProfit() + OrderSwap() + OrderCommission();
         Bopen_4 = OrderOpenPrice();
        }
      if(OrderType()==OP_SELL)
        {
         Scount_4++;
         Sprofit_4 = Sprofit_4 + OrderProfit() + OrderSwap() + OrderCommission();
         Sopen_4 = OrderOpenPrice();
        }
     }    
   if(OrderMagicNumber()==MAGIC_No+5)
     {
      if(OrderType()==OP_BUY)
        {
         Bcount_5++;
         Bprofit_5 = Bprofit_5 + OrderProfit() + OrderSwap() + OrderCommission();
         Bopen_5 = OrderOpenPrice();
        }
      if(OrderType()==OP_SELL)
        {
         Scount_5++;
         Sprofit_5 = Sprofit_5 + OrderProfit() + OrderSwap() + OrderCommission();
         Sopen_5 = OrderOpenPrice();
        }
     }    
   if(OrderMagicNumber()==MAGIC_No+6)
     {
      if(OrderType()==OP_BUY)
        {
         Bcount_6++;
         Bprofit_6 = Bprofit_6 + OrderProfit() + OrderSwap() + OrderCommission();
         Bopen_6 = OrderOpenPrice();
        }
      if(OrderType()==OP_SELL)
        {
         Scount_6++;
         Sprofit_6 = Sprofit_6 + OrderProfit() + OrderSwap() + OrderCommission();
         Sopen_6 = OrderOpenPrice();
        }
     }    
   if(OrderMagicNumber()==MAGIC_No+7)
     {
      if(OrderType()==OP_BUY)
        {
         Bcount_7++;
         Bprofit_7 = Bprofit_7 + OrderProfit() + OrderSwap() + OrderCommission();
         Bopen_7 = OrderOpenPrice();
        }
      if(OrderType()==OP_SELL)
        {
         Scount_7++;
         Sprofit_7 = Sprofit_7 + OrderProfit() + OrderSwap() + OrderCommission();
         Sopen_7 = OrderOpenPrice();
        }
     }    
   if(OrderMagicNumber()==MAGIC_No+8)
     {
      if(OrderType()==OP_BUY)
        {
         Bcount_8++;
         Bprofit_8 = Bprofit_8 + OrderProfit() + OrderSwap() + OrderCommission();
         Bopen_8 = OrderOpenPrice();
        }
      if(OrderType()==OP_SELL)
        {
         Scount_8++;
         Sprofit_8 = Sprofit_8 + OrderProfit() + OrderSwap() + OrderCommission();
         Sopen_8 = OrderOpenPrice();
        }
     }    
   if(OrderMagicNumber()==MAGIC_No+9)
     {
      if(OrderType()==OP_BUY)
        {
         Bcount_9++;
         Bprofit_9 = Bprofit_9 + OrderProfit() + OrderSwap() + OrderCommission();
         Bopen_9 = OrderOpenPrice();
        }
      if(OrderType()==OP_SELL)
        {
         Scount_9++;
         Sprofit_9 = Sprofit_9 + OrderProfit() + OrderSwap() + OrderCommission();
         Sopen_9 = OrderOpenPrice();
        }
     }  
   
   
   //selllimit지정가오더 카운팅  
   if(OrderType() == OP_SELLLIMIT)
     {
      SLcount++;
     }                                              
  }



//챠트 좌측상단에 표시되는 코멘트
Comment(
"+++++++++++++++++++++++++++++++","\n",
"JARVIS RANDOMWALK EA","\n",
"License= ", g_licStatusTxt,"\n",
"EA Status= ",(EA_ManualRun ? "RUNNING" : "MANUAL STOP"),"\n",
"Margin Level= ",DoubleToString(GetMarginLevel(),2),"%","\n",
"Entry Block Level= ",DoubleToString(MarginLevelEntryStop,0),"%","\n",
"+++++++++++++++++++++++++++++++","\n"
/*
"EA total P/L= ",Bprofit_0+Bprofit_1+Bprofit_2+Bprofit_3+Bprofit_4+Bprofit_5+Bprofit_6+Bprofit_7+Bprofit_8+Bprofit_9+Sprofit_0+Sprofit_1+Sprofit_2+Sprofit_3+Sprofit_4+Sprofit_5+Sprofit_6+Sprofit_7+Sprofit_8+Sprofit_9,"\n",
"EA BUY P/L= ",Bprofit_0+Bprofit_1+Bprofit_2+Bprofit_3+Bprofit_4+Bprofit_5+Bprofit_6+Bprofit_7+Bprofit_8+Bprofit_9,"\n",
"EA SELL P/L= ",Sprofit_0+Sprofit_1+Sprofit_2+Sprofit_3+Sprofit_4+Sprofit_5+Sprofit_6+Sprofit_7+Sprofit_8+Sprofit_9,"\n",
"Account total P/L= ",AccountProfit(),"\n",
"AccountBalance= ",AccountBalance(),"\n",
"AccountEquity= ",AccountEquity(),"\n"
*/
);  



//EquityLimit 전체청산 구문
if(AccountEquity() < EquityLimit)
  {
   CloseAll_All();
   Comment(
   "EquityLimit is on.""\n"
   );       
   return(0);
  } 



//selllimit지정가오더 존재 시 진입제한
if(SLcount > 0)
  {
   return(0);
  }





//total set close
//전체세트에 대한 청산구문
if(iVolume(Symbol(),PERIOD_M5,0) < 5)
  {
   if(Bprofit_0+Bprofit_1+Bprofit_2+Bprofit_3+Bprofit_4+Bprofit_5+Bprofit_6+Bprofit_7+Bprofit_8+Bprofit_9 > Lots*100)
     {
      CloseAll_B();
      return(0);
     }
   if(Sprofit_0+Sprofit_1+Sprofit_2+Sprofit_3+Sprofit_4+Sprofit_5+Sprofit_6+Sprofit_7+Sprofit_8+Sprofit_9 > Lots*100)
     {
      CloseAll_S();
      return(0);
     }
  }


//individual set close
//개별세트에 대한 청산구문
if(iVolume(Symbol(),PERIOD_M15,0) < 5)
  {
   if(Bprofit_0 > Lots*100)
     {
      CloseAll_0_B();
     }
   if(Sprofit_0 > Lots*100)
     {
      CloseAll_0_S();
     }

   if(Bprofit_1 > Lots*100)
     {
      CloseAll_1_B();
     }
   if(Sprofit_1 > Lots*100)
     {
      CloseAll_1_S();
     } 

   if(Bprofit_2 > Lots*100)
     {
      CloseAll_2_B();
     }
   if(Sprofit_2 > Lots*100)
     {
      CloseAll_2_S();
     }        

   if(Bprofit_3 > Lots*100)
     {
      CloseAll_3_B();
     }
   if(Sprofit_3 > Lots*100)
     {
      CloseAll_3_S();
     }  

   if(Bprofit_4 > Lots*100)
     {
      CloseAll_4_B();
     }
   if(Sprofit_4 > Lots*100)
     {
      CloseAll_4_S();
     }  
     
   if(Bprofit_5 > Lots*100)
     {
      CloseAll_5_B();
     }
   if(Sprofit_5 > Lots*100)
     {
      CloseAll_5_S();
     }   
     
   if(Bprofit_6 > Lots*100)
     {
      CloseAll_6_B();
     }
   if(Sprofit_6 > Lots*100)
     {
      CloseAll_6_S();
     } 
     
   if(Bprofit_7 > Lots*100)
     {
      CloseAll_7_B();
     }
   if(Sprofit_7 > Lots*100)
     {
      CloseAll_7_S();
     }  
     
   if(Bprofit_8 > Lots*100)
     {
      CloseAll_8_B();
     }
   if(Sprofit_8 > Lots*100)
     {
      CloseAll_8_S();
     }   
     
   if(Bprofit_9 > Lots*100)
     {
      CloseAll_9_B();
     }
   if(Sprofit_9 > Lots*100)
     {
      CloseAll_9_S();
     }  
                                                   
  }


//스프레드 진입제한
if(MarketInfo(Symbol(),MODE_SPREAD) > SpreadBlock) 
  {
   return(0);    
  }    

//START / STOP button entry control
//STOP 상태에서는 기존 포지션 청산 로직은 유지하고, 신규/추가 진입만 중단
if(EA_ManualRun == false)
  {
   Comment(
   "EA Status= MANUAL STOP","\n",
   "No new entries until START button is pressed.","\n",
   "Margin Level= ",DoubleToString(GetMarginLevel(),2),"%","\n"
   );
   return(0);
  }

//Margin Level entry protection
//마진레벨이 설정값 이하이면 신규/추가 진입 중단, 설정값 위로 회복되면 자동 재개
if(GetMarginLevel() <= MarginLevelEntryStop)
  {
   Comment(
   "EA Status= MARGIN LEVEL ENTRY BLOCK","\n",
   "No new entries while margin level is below limit.","\n",
   "Margin Level= ",DoubleToString(GetMarginLevel(),2),"%","\n",
   "Entry Block Level= ",DoubleToString(MarginLevelEntryStop,0),"%","\n"
   );
   return(0);
  }
  
  
//0
//0번째 세트 첫오더 진입 구문
if(Bcount_0 == 0)
  {
   ticket = OrderSend(Symbol(),OP_BUY,Lot_0,Ask,10,0,0,"AutoTradingRobot",MAGIC_No,0,clrBlue);  
  }
if(Scount_0 == 0)
  {
   ticket = OrderSend(Symbol(),OP_SELL,Lot_0,Bid,10,0,0,"AutoTradingRobot",MAGIC_No,0,clrRed);  
  }  

//1  
if(Bcount_0 >= NextLevel && Bcount_1 == 0)
  {
   ticket = OrderSend(Symbol(),OP_BUY,Lot_1,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+1,0,clrBlue);  
  }
if(Scount_0 >= NextLevel && Scount_1 == 0)
  {
   ticket = OrderSend(Symbol(),OP_SELL,Lot_1,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+1,0,clrRed);  
  }  
  
//2
if(Bcount_1 >= NextLevel && Bcount_2 == 0)
  {
   ticket = OrderSend(Symbol(),OP_BUY,Lot_2,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+2,0,clrBlue);  
  }
if(Scount_1 >= NextLevel && Scount_2 == 0)
  {
   ticket = OrderSend(Symbol(),OP_SELL,Lot_2,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+2,0,clrRed);  
  }       

//3
if(Bcount_2 >= NextLevel && Bcount_3 == 0)
  {
   ticket = OrderSend(Symbol(),OP_BUY,Lot_3,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+3,0,clrBlue);  
  }
if(Scount_2 >= NextLevel && Scount_3 == 0)
  {
   ticket = OrderSend(Symbol(),OP_SELL,Lot_3,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+3,0,clrRed);  
  }  
  
//4
if(Bcount_3 >= NextLevel && Bcount_4 == 0)
  {
   ticket = OrderSend(Symbol(),OP_BUY,Lot_4,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+4,0,clrBlue);  
  }
if(Scount_3 >= NextLevel && Scount_4 == 0)
  {
   ticket = OrderSend(Symbol(),OP_SELL,Lot_4,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+4,0,clrRed);  
  }  
  
//5
if(Bcount_4 >= NextLevel && Bcount_5 == 0)
  {
   ticket = OrderSend(Symbol(),OP_BUY,Lot_5,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+5,0,clrBlue);  
  }
if(Scount_4 >= NextLevel && Scount_5 == 0)
  {
   ticket = OrderSend(Symbol(),OP_SELL,Lot_5,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+5,0,clrRed);  
  }  

//6
if(Bcount_5 >= NextLevel && Bcount_6 == 0)
  {
   ticket = OrderSend(Symbol(),OP_BUY,Lot_6,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+6,0,clrBlue);  
  }
if(Scount_5 >= NextLevel && Scount_6 == 0)
  {
   ticket = OrderSend(Symbol(),OP_SELL,Lot_6,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+6,0,clrRed);  
  }                   

//7
if(Bcount_6 >= NextLevel && Bcount_7 == 0)
  {
   ticket = OrderSend(Symbol(),OP_BUY,Lot_7,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+7,0,clrBlue);  
  }
if(Scount_6 >= NextLevel && Scount_7 == 0)
  {
   ticket = OrderSend(Symbol(),OP_SELL,Lot_7,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+7,0,clrRed);  
  }    
  
//8
if(Bcount_7 >= NextLevel && Bcount_8 == 0)
  {
   ticket = OrderSend(Symbol(),OP_BUY,Lot_8,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+8,0,clrBlue);  
  }
if(Scount_7 >= NextLevel && Scount_8 == 0)
  {
   ticket = OrderSend(Symbol(),OP_SELL,Lot_8,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+8,0,clrRed);  
  }      
  
//9
if(Bcount_8 >= NextLevel && Bcount_9 == 0)
  {
   ticket = OrderSend(Symbol(),OP_BUY,Lot_9,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+9,0,clrBlue);  
  }
if(Scount_8 >= NextLevel && Scount_9 == 0)
  {
   ticket = OrderSend(Symbol(),OP_SELL,Lot_9,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+9,0,clrRed);  
  }      
     
     
//추가오더 진입 구문
if(iVolume(Symbol(),PERIOD_H1,0) < 4)
  {
   //0
   if(Bcount_0 > 0)
     {
      if(Ask <= Bopen_0 - Distance_0*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_BUY,Lot_0,Ask,10,0,0,"AutoTradingRobot",MAGIC_No,0,clrBlue);  
         return(0);
        }
     }
   if(Scount_0 > 0)
     {
      if(Bid >= Sopen_0 + Distance_0*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_SELL,Lot_0,Bid,10,0,0,"AutoTradingRobot",MAGIC_No,0,clrRed);  
         return(0);
        }
     } 
     
   //1  
   if(Bcount_1 > 0)
     {
      if(Ask <= Bopen_1 - Distance_1*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_BUY,Lot_1,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+1,0,clrBlue);  
         return(0);
        }
     }
   if(Scount_1 > 0)
     {
      if(Bid >= Sopen_1 + Distance_1*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_SELL,Lot_1,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+1,0,clrRed);  
         return(0);
        }
     }    
     
   //2
   if(Bcount_2 > 0)
     {
      if(Ask <= Bopen_2 - Distance_2*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_BUY,Lot_2,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+2,0,clrBlue);  
         return(0);
        }
     }
   if(Scount_2 > 0)
     {
      if(Bid >= Sopen_2 + Distance_2*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_SELL,Lot_2,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+2,0,clrRed);  
         return(0);
        }
     }    
     
   //3
   if(Bcount_3 > 0)
     {
      if(Ask <= Bopen_3 - Distance_3*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_BUY,Lot_3,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+3,0,clrBlue);  
         return(0);
        }
     }
   if(Scount_3 > 0)
     {
      if(Bid >= Sopen_3 + Distance_3*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_SELL,Lot_3,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+3,0,clrRed);  
         return(0);
        }
     }   
     
   //4
   if(Bcount_4 > 0)
     {
      if(Ask <= Bopen_4 - Distance_4*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_BUY,Lot_4,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+4,0,clrBlue);  
         return(0);
        }
     }
   if(Scount_4 > 0)
     {
      if(Bid >= Sopen_4 + Distance_4*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_SELL,Lot_4,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+4,0,clrRed);  
         return(0);
        }
     }   
     
   //5
   if(Bcount_5 > 0)
     {
      if(Ask <= Bopen_5 - Distance_5*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_BUY,Lot_5,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+5,0,clrBlue);  
         return(0);
        }
     }
   if(Scount_5 > 0)
     {
      if(Bid >= Sopen_5 + Distance_5*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_SELL,Lot_5,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+5,0,clrRed);  
         return(0);
        }
     }   
     
   //6
   if(Bcount_6 > 0)
     {
      if(Ask <= Bopen_6 - Distance_6*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_BUY,Lot_6,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+6,0,clrBlue);  
         return(0);
        }
     }
   if(Scount_6 > 0)
     {
      if(Bid >= Sopen_6 + Distance_6*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_SELL,Lot_6,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+6,0,clrRed);  
         return(0);
        }
     }   
     
   //7
   if(Bcount_7 > 0)
     {
      if(Ask <= Bopen_7 - Distance_7*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_BUY,Lot_7,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+7,0,clrBlue);  
         return(0);
        }
     }
   if(Scount_7 > 0)
     {
      if(Bid >= Sopen_7 + Distance_7*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_SELL,Lot_7,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+7,0,clrRed);  
         return(0);
        }
     }   
     
   //8
   if(Bcount_8 > 0)
     {
      if(Ask <= Bopen_8 - Distance_8*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_BUY,Lot_8,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+8,0,clrBlue);  
         return(0);
        }
     }
   if(Scount_8 > 0)
     {
      if(Bid >= Sopen_8 + Distance_8*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_SELL,Lot_8,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+8,0,clrRed);  
         return(0);
        }
     }   
     
   //9
   if(Bcount_9 > 0)
     {
      if(Ask <= Bopen_9 - Distance_9*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_BUY,Lot_9,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+9,0,clrBlue);  
         return(0);
        }
     }
   if(Scount_9 > 0)
     {
      if(Bid >= Sopen_9 + Distance_9*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_SELL,Lot_9,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+9,0,clrRed);  
         return(0);
        }
     }                                             
  } 



return(0);
}

















//------------------------------------------------------------------------------------------------------------------------------------------------------

//전체매수오더 청산 사용자함수
void CloseAll_B(int op_mode = -1) 
{
 bool CloseCheck;
 for(int i=0;i<10;i++) 
{
 int total = OrdersTotal();
 if(total==0) return;
 RefreshRates();
 for(int cnt = total-1; cnt>=0; cnt--) 
   {
   if (OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) == TRUE) 
     {
     if(OrderMagicNumber()==MAGIC_No || OrderMagicNumber()==MAGIC_No+1 || OrderMagicNumber()==MAGIC_No+2 || OrderMagicNumber()==MAGIC_No+3 || OrderMagicNumber()==MAGIC_No+4 || OrderMagicNumber()==MAGIC_No+5 || OrderMagicNumber()==MAGIC_No+6 || OrderMagicNumber()==MAGIC_No+7 || OrderMagicNumber()==MAGIC_No+8 || OrderMagicNumber()==MAGIC_No+9)
       {
        if(OrderType() == OP_BUY) 
          {
           CloseCheck=OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(),MODE_BID), 10, clrWhite);
          }
       }
     }
   }
}
return;
}


//전체매도오더 청산 사용자함수
void CloseAll_S(int op_mode = -1) 
{
 bool CloseCheck;
 for(int i=0;i<10;i++) 
{
 int total = OrdersTotal();
 if(total==0) return;
 RefreshRates();
 for(int cnt = total-1; cnt>=0; cnt--) 
   {
   if (OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) == TRUE) 
     {
     if(OrderMagicNumber()==MAGIC_No || OrderMagicNumber()==MAGIC_No+1 || OrderMagicNumber()==MAGIC_No+2 || OrderMagicNumber()==MAGIC_No+3 || OrderMagicNumber()==MAGIC_No+4 || OrderMagicNumber()==MAGIC_No+5 || OrderMagicNumber()==MAGIC_No+6 || OrderMagicNumber()==MAGIC_No+7 || OrderMagicNumber()==MAGIC_No+8 || OrderMagicNumber()==MAGIC_No+9)
       {
        if(OrderType() == OP_SELL) 
          {
           CloseCheck=OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(),MODE_ASK), 10, clrWhite);
          }
       }
     }
   }
}
return;
}


//------------------------------------------------------------------

//0번째 세트 매수오더 청산 사용자함수
void CloseAll_0_B(int op_mode = -1) 
{
 bool CloseCheck;
 for(int i=0;i<10;i++) 
{
 int total = OrdersTotal();
 if(total==0) return;
 RefreshRates();
 for(int cnt = total-1; cnt>=0; cnt--) 
   {
   if (OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) == TRUE) 
     {
     if(OrderMagicNumber()==MAGIC_No)
       {
        if(OrderType() == OP_BUY) 
          {
           CloseCheck=OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(),MODE_BID), 10, clrWhite);
          }
       }
     }
   }
}
return;
}

//0번째 세트 매도오더 청산 사용자함수
void CloseAll_0_S(int op_mode = -1) 
{
 bool CloseCheck;
 for(int i=0;i<10;i++) 
{
 int total = OrdersTotal();
 if(total==0) return;
 RefreshRates();
 for(int cnt = total-1; cnt>=0; cnt--) 
   {
   if (OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) == TRUE) 
     {
     if(OrderMagicNumber()==MAGIC_No)
       {
        if(OrderType() == OP_SELL) 
          {
           CloseCheck=OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(),MODE_ASK), 10, clrWhite);
          }
       }
     }
   }
}
return;
}


//1번째 세트 매수오더 청산 사용자함수
void CloseAll_1_B(int op_mode = -1) 
{
 bool CloseCheck;
 for(int i=0;i<10;i++) 
{
 int total = OrdersTotal();
 if(total==0) return;
 RefreshRates();
 for(int cnt = total-1; cnt>=0; cnt--) 
   {
   if (OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) == TRUE) 
     {
     if(OrderMagicNumber()==MAGIC_No+1)
       {
        if(OrderType() == OP_BUY) 
          {
           CloseCheck=OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(),MODE_BID), 10, clrWhite);
          }
       }
     }
   }
}
return;
}

//1번째 세트 매도오더 청산 사용자함수
void CloseAll_1_S(int op_mode = -1) 
{
 bool CloseCheck;
 for(int i=0;i<10;i++) 
{
 int total = OrdersTotal();
 if(total==0) return;
 RefreshRates();
 for(int cnt = total-1; cnt>=0; cnt--) 
   {
   if (OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) == TRUE) 
     {
     if(OrderMagicNumber()==MAGIC_No+1)
       {
        if(OrderType() == OP_SELL) 
          {
           CloseCheck=OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(),MODE_ASK), 10, clrWhite);
          }
       }
     }
   }
}
return;
}



void CloseAll_2_B(int op_mode = -1) 
{
 bool CloseCheck;
 for(int i=0;i<10;i++) 
{
 int total = OrdersTotal();
 if(total==0) return;
 RefreshRates();
 for(int cnt = total-1; cnt>=0; cnt--) 
   {
   if (OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) == TRUE) 
     {
     if(OrderMagicNumber()==MAGIC_No+2)
       {
        if(OrderType() == OP_BUY) 
          {
           CloseCheck=OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(),MODE_BID), 10, clrWhite);
          }
       }
     }
   }
}
return;
}


void CloseAll_2_S(int op_mode = -1) 
{
 bool CloseCheck;
 for(int i=0;i<10;i++) 
{
 int total = OrdersTotal();
 if(total==0) return;
 RefreshRates();
 for(int cnt = total-1; cnt>=0; cnt--) 
   {
   if (OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) == TRUE) 
     {
     if(OrderMagicNumber()==MAGIC_No+2)
       {
        if(OrderType() == OP_SELL) 
          {
           CloseCheck=OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(),MODE_ASK), 10, clrWhite);
          }
       }
     }
   }
}
return;
}


void CloseAll_3_B(int op_mode = -1) 
{
 bool CloseCheck;
 for(int i=0;i<10;i++) 
{
 int total = OrdersTotal();
 if(total==0) return;
 RefreshRates();
 for(int cnt = total-1; cnt>=0; cnt--) 
   {
   if (OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) == TRUE) 
     {
     if(OrderMagicNumber()==MAGIC_No+3)
       {
        if(OrderType() == OP_BUY) 
          {
           CloseCheck=OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(),MODE_BID), 10, clrWhite);
          }
       }
     }
   }
}
return;
}


void CloseAll_3_S(int op_mode = -1) 
{
 bool CloseCheck;
 for(int i=0;i<10;i++) 
{
 int total = OrdersTotal();
 if(total==0) return;
 RefreshRates();
 for(int cnt = total-1; cnt>=0; cnt--) 
   {
   if (OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) == TRUE) 
     {
     if(OrderMagicNumber()==MAGIC_No+3)
       {
        if(OrderType() == OP_SELL) 
          {
           CloseCheck=OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(),MODE_ASK), 10, clrWhite);
          }
       }
     }
   }
}
return;
}


void CloseAll_4_B(int op_mode = -1) 
{
 bool CloseCheck;
 for(int i=0;i<10;i++) 
{
 int total = OrdersTotal();
 if(total==0) return;
 RefreshRates();
 for(int cnt = total-1; cnt>=0; cnt--) 
   {
   if (OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) == TRUE) 
     {
     if(OrderMagicNumber()==MAGIC_No+4)
       {
        if(OrderType() == OP_BUY) 
          {
           CloseCheck=OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(),MODE_BID), 10, clrWhite);
          }
       }
     }
   }
}
return;
}


void CloseAll_4_S(int op_mode = -1) 
{
 bool CloseCheck;
 for(int i=0;i<10;i++) 
{
 int total = OrdersTotal();
 if(total==0) return;
 RefreshRates();
 for(int cnt = total-1; cnt>=0; cnt--) 
   {
   if (OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) == TRUE) 
     {
     if(OrderMagicNumber()==MAGIC_No+4)
       {
        if(OrderType() == OP_SELL) 
          {
           CloseCheck=OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(),MODE_ASK), 10, clrWhite);
          }
       }
     }
   }
}
return;
}



void CloseAll_5_B(int op_mode = -1) 
{
 bool CloseCheck;
 for(int i=0;i<10;i++) 
{
 int total = OrdersTotal();
 if(total==0) return;
 RefreshRates();
 for(int cnt = total-1; cnt>=0; cnt--) 
   {
   if (OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) == TRUE) 
     {
     if(OrderMagicNumber()==MAGIC_No+5)
       {
        if(OrderType() == OP_BUY) 
          {
           CloseCheck=OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(),MODE_BID), 10, clrWhite);
          }
       }
     }
   }
}
return;
}


void CloseAll_5_S(int op_mode = -1) 
{
 bool CloseCheck;
 for(int i=0;i<10;i++) 
{
 int total = OrdersTotal();
 if(total==0) return;
 RefreshRates();
 for(int cnt = total-1; cnt>=0; cnt--) 
   {
   if (OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) == TRUE) 
     {
     if(OrderMagicNumber()==MAGIC_No+5)
       {
        if(OrderType() == OP_SELL) 
          {
           CloseCheck=OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(),MODE_ASK), 10, clrWhite);
          }
       }
     }
   }
}
return;
}




void CloseAll_6_B(int op_mode = -1) 
{
 bool CloseCheck;
 for(int i=0;i<10;i++) 
{
 int total = OrdersTotal();
 if(total==0) return;
 RefreshRates();
 for(int cnt = total-1; cnt>=0; cnt--) 
   {
   if (OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) == TRUE) 
     {
     if(OrderMagicNumber()==MAGIC_No+6)
       {
        if(OrderType() == OP_BUY) 
          {
           CloseCheck=OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(),MODE_BID), 10, clrWhite);
          }
       }
     }
   }
}
return;
}


void CloseAll_6_S(int op_mode = -1) 
{
 bool CloseCheck;
 for(int i=0;i<10;i++) 
{
 int total = OrdersTotal();
 if(total==0) return;
 RefreshRates();
 for(int cnt = total-1; cnt>=0; cnt--) 
   {
   if (OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) == TRUE) 
     {
     if(OrderMagicNumber()==MAGIC_No+6)
       {
        if(OrderType() == OP_SELL) 
          {
           CloseCheck=OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(),MODE_ASK), 10, clrWhite);
          }
       }
     }
   }
}
return;
}



void CloseAll_7_B(int op_mode = -1) 
{
 bool CloseCheck;
 for(int i=0;i<10;i++) 
{
 int total = OrdersTotal();
 if(total==0) return;
 RefreshRates();
 for(int cnt = total-1; cnt>=0; cnt--) 
   {
   if (OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) == TRUE) 
     {
     if(OrderMagicNumber()==MAGIC_No+7)
       {
        if(OrderType() == OP_BUY) 
          {
           CloseCheck=OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(),MODE_BID), 10, clrWhite);
          }
       }
     }
   }
}
return;
}


void CloseAll_7_S(int op_mode = -1) 
{
 bool CloseCheck;
 for(int i=0;i<10;i++) 
{
 int total = OrdersTotal();
 if(total==0) return;
 RefreshRates();
 for(int cnt = total-1; cnt>=0; cnt--) 
   {
   if (OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) == TRUE) 
     {
     if(OrderMagicNumber()==MAGIC_No+7)
       {
        if(OrderType() == OP_SELL) 
          {
           CloseCheck=OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(),MODE_ASK), 10, clrWhite);
          }
       }
     }
   }
}
return;
}



void CloseAll_8_B(int op_mode = -1) 
{
 bool CloseCheck;
 for(int i=0;i<10;i++) 
{
 int total = OrdersTotal();
 if(total==0) return;
 RefreshRates();
 for(int cnt = total-1; cnt>=0; cnt--) 
   {
   if (OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) == TRUE) 
     {
     if(OrderMagicNumber()==MAGIC_No+8)
       {
        if(OrderType() == OP_BUY) 
          {
           CloseCheck=OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(),MODE_BID), 10, clrWhite);
          }
       }
     }
   }
}
return;
}


void CloseAll_8_S(int op_mode = -1) 
{
 bool CloseCheck;
 for(int i=0;i<10;i++) 
{
 int total = OrdersTotal();
 if(total==0) return;
 RefreshRates();
 for(int cnt = total-1; cnt>=0; cnt--) 
   {
   if (OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) == TRUE) 
     {
     if(OrderMagicNumber()==MAGIC_No+8)
       {
        if(OrderType() == OP_SELL) 
          {
           CloseCheck=OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(),MODE_ASK), 10, clrWhite);
          }
       }
     }
   }
}
return;
}



void CloseAll_9_B(int op_mode = -1) 
{
 bool CloseCheck;
 for(int i=0;i<10;i++) 
{
 int total = OrdersTotal();
 if(total==0) return;
 RefreshRates();
 for(int cnt = total-1; cnt>=0; cnt--) 
   {
   if (OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) == TRUE) 
     {
     if(OrderMagicNumber()==MAGIC_No+9)
       {
        if(OrderType() == OP_BUY) 
          {
           CloseCheck=OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(),MODE_BID), 10, clrWhite);
          }
       }
     }
   }
}
return;
}


void CloseAll_9_S(int op_mode = -1) 
{
 bool CloseCheck;
 for(int i=0;i<10;i++) 
{
 int total = OrdersTotal();
 if(total==0) return;
 RefreshRates();
 for(int cnt = total-1; cnt>=0; cnt--) 
   {
   if (OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) == TRUE) 
     {
     if(OrderMagicNumber()==MAGIC_No+9)
       {
        if(OrderType() == OP_SELL) 
          {
           CloseCheck=OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(),MODE_ASK), 10, clrWhite);
          }
       }
     }
   }
}
return;
}










//전체오더 청산 사용자함수
void CloseAll_All(int op_mode = -1)
  {
   bool CloseCheck;
   for(int i=0; i<10; i++)
     {
      int total = OrdersTotal();
      if(total==0)
         return;
      RefreshRates();
      for(int cnt = total-1; cnt>=0; cnt--)
        {
         if(OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) == TRUE)
           {
            //if(OrderMagicNumber() == MagicNumber)
              {
               if(OrderType() == OP_BUY) CloseCheck=OrderClose(OrderTicket(), OrderLots(), MarketInfo(Symbol(),MODE_BID), 10, clrWhite);
               if(OrderType() == OP_SELL) CloseCheck=OrderClose(OrderTicket(), OrderLots(), MarketInfo(Symbol(),MODE_ASK), 10, clrWhite);
              }
           }
        }
     }
   return;
  }
