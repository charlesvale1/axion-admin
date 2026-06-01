#property copyright "DQL(diplomat quant logic) by HERITAGE ASSET"
#property version   "2.00"
#property description "Soluni v2 | DQL by HERITAGE ASSET | Axion Research"

//============================================================
// 기본 설정
//============================================================
extern string EA_setting   = "======= Soluni v2 | DQL by HERITAGE ASSET =======";
extern int    MAGIC_No     = 10;
extern double Lots         = 0.01;
extern int    SpreadBlock  = 35;
extern int    EquityLimit  = 0;

//============================================================
// Axion Research 라이센스 설정
//============================================================
extern string LIC_SET        = "------- Axion Research License -------";
extern bool   UseLicenseCheck = true;
extern string LicenseAccountNo= "";
extern string ProgramName     = "Soluni_v2";

//============================================================
// 종목명 설정 (UI 표시용)
//============================================================
extern string SYM_SET  = "------- 종목명 설정 (6개) -------";
extern string Sym_0    = "XAUUSD";
extern string Sym_1    = "EURUSD";
extern string Sym_2    = "GBPUSD";
extern string Sym_3    = "USDJPY";
extern string Sym_4    = "NAS100";
extern string Sym_5    = "US30";

//============================================================
// 전역 변수
//============================================================
bool     LicenseOK        = false;
string   LicenseStatus    = "확인 중...";
datetime LastLicenseCheck = 0;
bool     RiskNoticeAccepted = false;
int      NextLevel = 4;

int Distance_0=25,Distance_1=24,Distance_2=23,Distance_3=22,Distance_4=21;
int Distance_5=20,Distance_6=19,Distance_7=18,Distance_8=17,Distance_9=16;


//============================================================
// Axion Research 라이센스 체크
//============================================================
bool CheckLicense()
{
   if(!UseLicenseCheck)
   { LicenseOK=true; LicenseStatus="체크 안 함"; return(true); }
   if(LicenseOK && TimeCurrent()-LastLicenseCheck < 3600)
      return(true);

   string acct = LicenseAccountNo;
   if(StringLen(acct)==0) acct = IntegerToString(AccountNumber());

   string ak  = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indtdm5lYXJvdXJzYm13anF3end3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgxNzQ5MjEsImV4cCI6MjA5Mzc1MDkyMX0.MS4iSGIvW4dBi3sd8J3baHLT4TlgUJS5lXwlhJdWYEY";
   string base= "https://wmvnearoursbmwjqwzww.supabase.co";
   string hdr = "apikey: "+ak+"\r\nAuthorization: Bearer "+ak+"\r\nContent-Type: application/json";
   char req[], res1[]; string rh;

   // ── Step 1: 계좌 활성 확인 + id, expires_at 취득 ──
   string url1 = base+"/rest/v1/customers?account_no=eq."+acct+"&is_active=eq.true&select=id,expires_at";
   int ret1 = WebRequest("GET",url1,hdr,5000,req,res1,rh);
   if(ret1<0)
   {
      int err=GetLastError();
      LicenseStatus=(err==4060)?"WebRequest URL 미등록 (MT4 옵션에서 추가 필요)":"네트워크 오류 err="+IntegerToString(err);
      Print("[Soluni v2] 라이센스 ERROR: ",LicenseStatus);
      if(err==4060) Print("[Soluni v2] 추가 URL: ",base);
      LicenseOK=false; return(false);
   }
   string body1=CharArrayToString(res1);
   Print("[Soluni v2] Step1 HTTP=",ret1," body=",body1);
   if(ret1!=200||body1=="[]"||StringFind(body1,"expires_at")<0)
   { LicenseStatus="미등록/비활성 계좌"; Print("[Soluni v2] ERROR: ",LicenseStatus," 계좌=",acct); LicenseOK=false; return(false); }

   // 만료일 파싱
   int es=StringFind(body1,"\"expires_at\":\"")+14;
   string expStr=StringSubstr(body1,es,10); StringReplace(expStr,"-",".");
   if(expStr<TimeToString(TimeCurrent(),TIME_DATE))
   { LicenseStatus="만료됨 ("+expStr+")"; LicenseOK=false; return(false); }

   // id 파싱 (정수/UUID 모두 처리)
   string custId="";
   int idp=StringFind(body1,"\"id\":");
   if(idp>=0)
   {
      int vs=idp+5;
      if(StringGetCharacter(body1,vs)=='"')
      { vs++; int ve=StringFind(body1,"\"",vs); if(ve>vs) custId=StringSubstr(body1,vs,ve-vs); }
      else
      { int ve=vs; while(ve<StringLen(body1)){ ushort c=StringGetCharacter(body1,ve); if(c<'0'||c>'9') break; ve++; } if(ve>vs) custId=StringSubstr(body1,vs,ve-vs); }
   }
   if(custId=="") { LicenseStatus="ID 파싱 실패"; LicenseOK=false; return(false); }

   // ── Step 2: customer_programs에서 이 EA 할당 여부 확인 ──
   char res2[]; string rh2;
   string url2=base+"/rest/v1/customer_programs?customer_id=eq."+custId+"&select=programs(name)";
   int ret2=WebRequest("GET",url2,hdr,5000,req,res2,rh2);
   string body2=CharArrayToString(res2);
   Print("[Soluni v2] Step2 HTTP=",ret2," body=",body2);
   if(ret2!=200||body2=="[]")
   { LicenseStatus="할당된 EA 없음"; LicenseOK=false; return(false); }
   string b2L=body2; StringToLower(b2L);
   string pL=ProgramName; StringToLower(pL);
   if(StringFind(b2L,pL)<0)
   { LicenseStatus="이 EA 미할당 ("+ProgramName+")"; Print("[Soluni v2] ERROR: ",LicenseStatus," 계좌=",acct); LicenseOK=false; return(false); }

   LicenseOK=true;
   LicenseStatus="OK (만료: "+expStr+")";
   LastLicenseCheck=TimeCurrent();
   Print("[Soluni v2] 라이센스 OK 만료: ",expStr);
   return(true);
}


//============================================================
// Soluni v2 대시보드 (우측 상단)
//============================================================
string DPFX = "SOL2_";

void DL(string id, string txt, int x, int y, int sz, color clr, string font)
{
   string n = DPFX+id;
   if(ObjectFind(0,n)<0)
   {
      ObjectCreate(0,n,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,n,OBJPROP_BACK,false);
   }
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,sz);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetString(0,n,OBJPROP_TEXT,txt);
   ObjectSetString(0,n,OBJPROP_FONT,font);
}

void DR(string id, int x, int y, int w, int h, color bg, color bd)
{
   string n = DPFX+"R_"+id;
   if(ObjectFind(0,n)<0)
   {
      ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,n,OBJPROP_BACK,true);
   }
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,n,OBJPROP_COLOR,bd);
   ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);
}

void DrawDashboard(double p0,double p1,double p2,double p3,double p4,double p5)
{
   int PW=270, x=14, y=14;
   color CB=C'10,8,3', CH=C'20,15,4', CL=C'65,50,8', CL2=C'35,28,4';
   color W=clrWhite, G=clrGold, G2=C'180,140,30';

   // 배경 + 헤더
   DR("bg",  x,y,PW+2,292,CB,CL);
   DR("hd",  x,y,PW+2,46, CH,CL);
   DL("T1","S O L U N I   v 2",         x+14,y+6, 15,G, "Times New Roman Bold");
   DL("T2","DQL by HERITAGE ASSET  |  Axion Research",x+8,y+30,7,G2,"Arial");

   // 계좌 정보
   int ay=y+50;
   DR("ab",x,ay,PW+2,40,C'14,11,3',CL2);
   DR("d1",x+90, ay,1,40,CL2,CL2);
   DR("d2",x+183,ay,1,40,CL2,CL2);
   DL("AL","BALANCE",  x+8,  ay+4, 7,G2,"Arial");
   DL("AE","EQUITY",   x+98, ay+4, 7,G2,"Arial");
   DL("AF","FLOAT P&L",x+190,ay+4, 7,G2,"Arial");
   DL("AV1","$"+DoubleToString(AccountBalance(),0),x+8,  ay+18,11,W,"Arial Bold");

   color eqc = AccountEquity()>=AccountBalance() ? clrLimeGreen : clrTomato;
   DL("AV2","$"+DoubleToString(AccountEquity(),0),x+98,ay+18,11,eqc,"Arial Bold");

   double fp = AccountEquity()-AccountBalance();
   string fps = (fp>=0?"+$":"-$")+DoubleToString(MathAbs(fp),2);
   DL("AV3",fps,x+190,ay+18,10,fp>=0?clrLimeGreen:clrTomato,"Arial Bold");

   // 종목별 수익 헤더
   int ty=ay+44;
   DR("th",x,ty,PW+2,18,C'18,14,4',CL2);
   DL("TH","종목별 수익 현황",x+8, ty+3,9,G,"Arial Bold");
   DL("THL","Lic: "+(LicenseOK?"OK":"없음"),x+204,ty+3,7,LicenseOK?clrLimeGreen:clrTomato,"Arial");

   // 6개 종목 행
   string syms[6]; syms[0]=Sym_0;syms[1]=Sym_1;syms[2]=Sym_2;syms[3]=Sym_3;syms[4]=Sym_4;syms[5]=Sym_5;
   double pnls[6]; pnls[0]=p0;pnls[1]=p1;pnls[2]=p2;pnls[3]=p3;pnls[4]=p4;pnls[5]=p5;
   int rh=22;
   for(int i=0;i<6;i++)
   {
      int ry=ty+20+i*rh;
      DR("rw"+IntegerToString(i),x,ry,PW+2,rh,i%2==0?CB:C'14,11,3',CL2);
      DR("rv"+IntegerToString(i),x+152,ry,1,rh,CL2,CL2);
      DL("SN"+IntegerToString(i),syms[i],x+8,ry+4,9,W,"Arial Bold");

      int bc=0,sc=0;
      for(int j=0;j<OrdersTotal();j++)
      {
         if(!OrderSelect(j,SELECT_BY_POS,MODE_TRADES)) continue;
         if(OrderMagicNumber()!=MAGIC_No+i) continue;
         if(OrderType()==OP_BUY) bc++;
         if(OrderType()==OP_SELL) sc++;
      }
      DL("PS"+IntegerToString(i),"B:"+IntegerToString(bc)+" S:"+IntegerToString(sc),
         x+100,ry+4,8,G2,"Arial");

      string pstr=(pnls[i]>=0?"+$":"-$")+DoubleToString(MathAbs(pnls[i]),2);
      DL("PL"+IntegerToString(i),pstr,x+163,ry+4,10,pnls[i]>=0?clrLimeGreen:clrTomato,"Arial Bold");
   }

   // 총 실현손익
   double tot=p0+p1+p2+p3+p4+p5;
   int bot=ty+20+6*rh+2;
   DR("tt",x,bot,PW+2,26,tot>=0?C'8,28,8':C'28,8,8',CL);
   DL("TTL","총 실현손익",x+8,bot+6,9,W,"Arial Bold");
   string tstr=(tot>=0?"+$":"-$")+DoubleToString(MathAbs(tot),2);
   DL("TTV",tstr,x+163,bot+5,12,tot>=0?clrLimeGreen:clrTomato,"Arial Bold");

   // 계좌 총손익 + 시간
   int bot2=bot+28;
   DR("ap",x,bot2,PW+2,20,C'14,11,3',CL2);
   string apstr=(AccountProfit()>=0?"$+":"$-")+DoubleToString(MathAbs(AccountProfit()),2);
   DL("APL","계좌 총손익  "+apstr,x+8,bot2+3,8,AccountProfit()>=0?clrLimeGreen:clrTomato,"Arial Bold");
   DL("APT",TimeToString(TimeCurrent(),TIME_SECONDS),x+200,bot2+3,7,G2,"Arial");

   Comment("");
}

int init()
{
   LicenseOK = false;
   LicenseStatus = "확인 중...";
   RiskNoticeAccepted = false;

   Comment("Soluni v2: Axion Research 라이센스 확인 중...");
   Sleep(300);
   if(!CheckLicense())
   {
      Comment("Soluni v2: "+LicenseStatus+"\nAxion Research 파트너 페이지에서 권한을 신청하세요.");
      Alert("Soluni v2: 라이센스 없음. Axion Research 파트너 페이지에서 권한 신청 필요.");
      ExpertRemove();
      return(-1);
   }
   Comment("");

   string RiskNotice = "";
   RiskNotice += "EA 시작 전 필수 투자위험 및 책임 고지\n\n";
   RiskNotice += "본 EA는 자동매매 보조 프로그램이며 수익을 보장하지 않습니다.\n\n";
   RiskNotice += "레버리지 상품은 시장 변동성, 스프레드 확대, 슬리피지, 체결 지연, 서버 장애,\n";
   RiskNotice += "증거금 부족, 마진콜, 강제청산 등으로 큰 손실이 발생할 수 있습니다.\n\n";
   RiskNotice += "기본 설정값, 백테스트, 과거 수익률은 참고용이며 미래 수익을 보장하지 않습니다.\n\n";
   RiskNotice += "본 프로그램은 투자권유, 투자자문, 투자일임, 대리매매를 목적으로 하지 않습니다.\n\n";
   RiskNotice += "EA 설치, 설정, 실행, 운용에 대한 최종 판단과 책임은 전적으로 이용자 본인에게 있습니다.\n\n";
   RiskNotice += "위 내용을 이해했으며 본인 판단과 책임으로 EA를 실행합니다.\n\n";
   RiskNotice += "동의하시면 예(Yes) 버튼을 눌러 시작하세요.";

   int result = MessageBox(RiskNotice, "Soluni v2 - 필수 투자위험 및 책임 고지", MB_YESNO|MB_ICONWARNING);
   if(result != IDYES)
   {
      RiskNoticeAccepted = false;
      Print("[Soluni v2] EA 실행이 취소되었습니다.");
      Comment("Soluni v2: 투자위험 고지 미동의. EA 종료.");
      ExpertRemove();
      return(-1);
   }
   RiskNoticeAccepted = true;
   return(0);
}

int start()
{
// Axion Research 라이센스 1시간마다 재확인
if(UseLicenseCheck)
{
   if(TimeCurrent()-LastLicenseCheck >= 3600)
   {
      if(!CheckLicense()) { Comment("Soluni v2: "+LicenseStatus); return(0); }
      Comment("");
   }
   if(!LicenseOK) { Comment("Soluni v2: 라이센스 없음. 거래 중지."); return(0); }
}

//위험고지 취소/미동의 시 매매 로직 실행 차단
if(RiskNoticeAccepted != true)
  {
   Comment("EA 실행 취소: 투자위험 및 책임 고지 확인이 필요합니다.");
   return(0);
  }

//비밀번호 설정
// [Soluni v2] 비밀번호 방식 제거 - Axion Research 라이센스로 대체 

//계좌번호지정 

// [Soluni v2] 계좌번호 제한 제거 - Axion Research 라이센스로 대체


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
// Soluni v2 대시보드
DrawDashboard(
   Bprofit_0+Sprofit_0, Bprofit_1+Sprofit_1,
   Bprofit_2+Sprofit_2, Bprofit_3+Sprofit_3,
   Bprofit_4+Sprofit_4, Bprofit_5+Sprofit_5
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
  
  
//0
//0번째 세트 첫오더 진입 구문
if(Bcount_0 == 0)
  {
   ticket = OrderSend(Symbol(),OP_BUY,Lot_0,Ask,10,0,0,"AutoTradingRobot",MAGIC_No,0,clrBlue);  
   Print("ASK = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_ASK),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
  }
if(Scount_0 == 0)
  {
   ticket = OrderSend(Symbol(),OP_SELL,Lot_0,Bid,10,0,0,"AutoTradingRobot",MAGIC_No,0,clrRed);  
   Print("BID = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_BID),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
  }  

//1  
if(Bcount_0 >= NextLevel && Bcount_1 == 0)
  {
   ticket = OrderSend(Symbol(),OP_BUY,Lot_1,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+1,0,clrBlue);  
   Print("ASK = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_ASK),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
  }
if(Scount_0 >= NextLevel && Scount_1 == 0)
  {
   ticket = OrderSend(Symbol(),OP_SELL,Lot_1,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+1,0,clrRed);  
   Print("BID = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_BID),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
  }  
  
//2
if(Bcount_1 >= NextLevel && Bcount_2 == 0)
  {
   ticket = OrderSend(Symbol(),OP_BUY,Lot_2,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+2,0,clrBlue);  
   Print("ASK = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_ASK),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
  }
if(Scount_1 >= NextLevel && Scount_2 == 0)
  {
   ticket = OrderSend(Symbol(),OP_SELL,Lot_2,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+2,0,clrRed);  
   Print("BID = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_BID),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
  }       

//3
if(Bcount_2 >= NextLevel && Bcount_3 == 0)
  {
   ticket = OrderSend(Symbol(),OP_BUY,Lot_3,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+3,0,clrBlue); 
   Print("ASK = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_ASK),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));   
  }
if(Scount_2 >= NextLevel && Scount_3 == 0)
  {
   ticket = OrderSend(Symbol(),OP_SELL,Lot_3,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+3,0,clrRed);  
   Print("BID = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_BID),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
  }  
  
//4
if(Bcount_3 >= NextLevel && Bcount_4 == 0)
  {
   ticket = OrderSend(Symbol(),OP_BUY,Lot_4,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+4,0,clrBlue);  
   Print("ASK = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_ASK),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
  }
if(Scount_3 >= NextLevel && Scount_4 == 0)
  {
   ticket = OrderSend(Symbol(),OP_SELL,Lot_4,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+4,0,clrRed);  
   Print("BID = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_BID),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
  }  
  
//5
if(Bcount_4 >= NextLevel && Bcount_5 == 0)
  {
   ticket = OrderSend(Symbol(),OP_BUY,Lot_5,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+5,0,clrBlue);  
   Print("ASK = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_ASK),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
  }
if(Scount_4 >= NextLevel && Scount_5 == 0)
  {
   ticket = OrderSend(Symbol(),OP_SELL,Lot_5,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+5,0,clrRed);  
   Print("BID = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_BID),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
  }  

//6
if(Bcount_5 >= NextLevel && Bcount_6 == 0)
  {
   ticket = OrderSend(Symbol(),OP_BUY,Lot_6,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+6,0,clrBlue);  
   Print("ASK = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_ASK),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
  }
if(Scount_5 >= NextLevel && Scount_6 == 0)
  {
   ticket = OrderSend(Symbol(),OP_SELL,Lot_6,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+6,0,clrRed);  
   Print("BID = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_BID),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
  }                   

//7
if(Bcount_6 >= NextLevel && Bcount_7 == 0)
  {
   ticket = OrderSend(Symbol(),OP_BUY,Lot_7,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+7,0,clrBlue);  
   Print("ASK = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_ASK),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
  }
if(Scount_6 >= NextLevel && Scount_7 == 0)
  {
   ticket = OrderSend(Symbol(),OP_SELL,Lot_7,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+7,0,clrRed);  
   Print("BID = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_BID),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
  }    
  
//8
if(Bcount_7 >= NextLevel && Bcount_8 == 0)
  {
   ticket = OrderSend(Symbol(),OP_BUY,Lot_8,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+8,0,clrBlue);  
   Print("ASK = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_ASK),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
  }
if(Scount_7 >= NextLevel && Scount_8 == 0)
  {
   ticket = OrderSend(Symbol(),OP_SELL,Lot_8,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+8,0,clrRed);  
   Print("BID = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_BID),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
  }      
  
//9
if(Bcount_8 >= NextLevel && Bcount_9 == 0)
  {
   ticket = OrderSend(Symbol(),OP_BUY,Lot_9,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+9,0,clrBlue);  
   Print("ASK = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_ASK),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
  }
if(Scount_8 >= NextLevel && Scount_9 == 0)
  {
   ticket = OrderSend(Symbol(),OP_SELL,Lot_9,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+9,0,clrRed);  
   Print("BID = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_BID),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
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
         Print("ASK = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_ASK),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
         return(0);
        }
     }
   if(Scount_0 > 0)
     {
      if(Bid >= Sopen_0 + Distance_0*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_SELL,Lot_0,Bid,10,0,0,"AutoTradingRobot",MAGIC_No,0,clrRed);  
         Print("BID = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_BID),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
         return(0);
        }
     } 
     
   //1  
   if(Bcount_1 > 0)
     {
      if(Ask <= Bopen_1 - Distance_1*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_BUY,Lot_1,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+1,0,clrBlue);  
         Print("ASK = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_ASK),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
         return(0);
        }
     }
   if(Scount_1 > 0)
     {
      if(Bid >= Sopen_1 + Distance_1*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_SELL,Lot_1,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+1,0,clrRed);  
         Print("BID = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_BID),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
         return(0);
        }
     }    
     
   //2
   if(Bcount_2 > 0)
     {
      if(Ask <= Bopen_2 - Distance_2*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_BUY,Lot_2,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+2,0,clrBlue);  
         Print("ASK = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_ASK),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
         return(0);
        }
     }
   if(Scount_2 > 0)
     {
      if(Bid >= Sopen_2 + Distance_2*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_SELL,Lot_2,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+2,0,clrRed);  
         Print("BID = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_BID),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
         return(0);
        }
     }    
     
   //3
   if(Bcount_3 > 0)
     {
      if(Ask <= Bopen_3 - Distance_3*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_BUY,Lot_3,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+3,0,clrBlue);  
         Print("ASK = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_ASK),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
         return(0);
        }
     }
   if(Scount_3 > 0)
     {
      if(Bid >= Sopen_3 + Distance_3*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_SELL,Lot_3,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+3,0,clrRed);  
         Print("BID = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_BID),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
         return(0);
        }
     }   
     
   //4
   if(Bcount_4 > 0)
     {
      if(Ask <= Bopen_4 - Distance_4*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_BUY,Lot_4,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+4,0,clrBlue);  
         Print("ASK = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_ASK),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
         return(0);
        }
     }
   if(Scount_4 > 0)
     {
      if(Bid >= Sopen_4 + Distance_4*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_SELL,Lot_4,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+4,0,clrRed);  
         Print("BID = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_BID),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
         return(0);
        }
     }   
     
   //5
   if(Bcount_5 > 0)
     {
      if(Ask <= Bopen_5 - Distance_5*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_BUY,Lot_5,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+5,0,clrBlue);  
         Print("ASK = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_ASK),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
         return(0);
        }
     }
   if(Scount_5 > 0)
     {
      if(Bid >= Sopen_5 + Distance_5*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_SELL,Lot_5,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+5,0,clrRed);  
         Print("BID = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_BID),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
         return(0);
        }
     }   
     
   //6
   if(Bcount_6 > 0)
     {
      if(Ask <= Bopen_6 - Distance_6*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_BUY,Lot_6,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+6,0,clrBlue);  
         Print("ASK = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_ASK),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
         return(0);
        }
     }
   if(Scount_6 > 0)
     {
      if(Bid >= Sopen_6 + Distance_6*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_SELL,Lot_6,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+6,0,clrRed);  
         Print("BID = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_BID),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
         return(0);
        }
     }   
     
   //7
   if(Bcount_7 > 0)
     {
      if(Ask <= Bopen_7 - Distance_7*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_BUY,Lot_7,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+7,0,clrBlue);  
         Print("ASK = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_ASK),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
         return(0);
        }
     }
   if(Scount_7 > 0)
     {
      if(Bid >= Sopen_7 + Distance_7*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_SELL,Lot_7,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+7,0,clrRed);  
         Print("BID = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_BID),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
         return(0);
        }
     }   
     
   //8
   if(Bcount_8 > 0)
     {
      if(Ask <= Bopen_8 - Distance_8*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_BUY,Lot_8,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+8,0,clrBlue);  
         Print("ASK = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_ASK),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
         return(0);
        }
     }
   if(Scount_8 > 0)
     {
      if(Bid >= Sopen_8 + Distance_8*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_SELL,Lot_8,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+8,0,clrRed);  
         Print("BID = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_BID),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
         return(0);
        }
     }   
     
   //9
   if(Bcount_9 > 0)
     {
      if(Ask <= Bopen_9 - Distance_9*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_BUY,Lot_9,Ask,10,0,0,"AutoTradingRobot",MAGIC_No+9,0,clrBlue);  
         Print("ASK = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_ASK),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
         return(0);
        }
     }
   if(Scount_9 > 0)
     {
      if(Bid >= Sopen_9 + Distance_9*Point*10)
        {
         ticket = OrderSend(Symbol(),OP_SELL,Lot_9,Bid,10,0,0,"AutoTradingRobot",MAGIC_No+9,0,clrRed);  
         Print("BID = ",DoubleToStr(NormalizeDouble(MarketInfo(Symbol(),MODE_BID),5),5)," / SPREAD = ",MarketInfo(Symbol(),MODE_SPREAD));  
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
