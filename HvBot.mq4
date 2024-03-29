//+------------------------------------------------------------------+
//|                                                        HvBot.mq4 |
//|                                                        khiemvn18 |
//|                                              khiemvn18@yahoo.com |
//+------------------------------------------------------------------+
#property copyright "khiemvn18"
#property link      "khiemvn18@yahoo.com"
#property version   "1.0"
#property strict

#define URL "https://script.google.com/macros/s/AKfycbzTEZ8Ix_dbds7GCdu4iWlZelv5aDvPc3kXmYxMxBcWiHHwXH2iBQyPI1umxCODWdGy/exec"

#define CLOSE_ALL          "CLOSE_ALL"
#define CLOSE_PROFIT       "CLOSE_PROFIT"
#define CLOSE_SELL         "CLOSE_SELL"
#define CLOSE_SELL_PROFIT  "CLOSE_SELL_PROFIT"
#define CLOSE_BUY          "CLOSE_BUY"
#define CLOSE_BUY_PROFIT   "CLOSE_BUY_PROFIT"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
extern double ASIA_LOT           = 0.3                        ;   // lot phien A/Uc
extern double EURP_LOT           = 0.1                        ;   // lot phien Au
extern double AMRC_LOT           = 0.1                        ;   // lot phien My
extern int    ASIA_RSI           = 5                          ;   // chu ky RSI phien A/UC
extern int    EURP_RSI           = 5                          ;   // chu ky RSI phien Au
extern int    AMRC_RSI           = 7                          ;   // chu ky RSI phien My
extern double ASIA_PCT           = 0.02                       ;   // % thay doi phien A/Uc
extern double EURP_PCT           = 0.02                       ;   // % thay doi phien Au
extern double AMRC_PCT           = 0.02                       ;   // % thay doi phien My
extern string ASIA_SSN           = "18 19 20 21 22 23 1 2 3 4";   // gio phien A/Uc (GMT)
extern string EURP_SSN           = "5 6 7 8 9 10 11"          ;   // gio phien Au (GMT)
extern string AMRC_SSN           = "12 13 14 15 16 17"        ;   // gio phien My (GMT)
extern string STOP_SSN           = "21 22"                    ;   // gio bot nghi (GMT)

string asia_time[];
string amrc_time[];
string eurp_time[];
string stop_time[];

string run_hour;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
extern double TOTAL_LOT          = 100    ; // tong so lot toi da (lot)
//extern double PERCENT_CHANGE     = 0.02   ; // thay doi (% so voi lenh cung loai truoc do)
extern double STOP_PROFIT        = 0.001  ; // loi nhuan toi thieu (% tai khoan)
extern int    SLIPPAGE           = 5     ; // khoang gia cho phep (point)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//double start_lot          = 0.3    ; // so lot khoi diem (lot)
//double TOTAL_LOT          = 100    ; // tong so lot toi da (lot)
//double PERCENT_CHANGE     = 0.0003 ; // thay doi (%)
//int    RSI_PERIOD         = 5      ; // chu ky rsi (m/h/d...)
//double STOP_PROFIT        = 0.1     ; // loi nhuan toi thieu (%)
//int    SLIPPAGE           = 30     ; // khoang gia cho phep (poin


bool first_run = true;  // lần đầu chạy sell và buy đồng thời
double stop_loss = 0;
double take_profit = 0;

double start_lot = 0.3;
double buy_lot = start_lot;
double sell_lot = start_lot;
int rsi_period = 5;
double percent_change = 0.02;

// đếm số lệnh sell và buy trước đó để tính số lot phù hợp
int isell = 1;
int ibuy = 1;
int ticket = -1;
double avail_lot = TOTAL_LOT;

// 2 pointer tính % thay đổi giá. curr giá hiện tại, prev giá lệnh trước đó
double curr_price = 0;
double prev_price = 0;

double curr_bid, prev_bid, curr_ask, prev_ask;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
void OnTick()
{
   run_hour = IntegerToString(Hour());
   if (array_contains(stop_time, run_hour))
   {
      Comment("SLEEP HOUR");
      return;
   }
   else if (array_contains(asia_time, run_hour))
   {
      Comment("");
      start_lot = ASIA_LOT;
      rsi_period = ASIA_RSI;
      percent_change = ASIA_PCT;
   }
   else if (array_contains(amrc_time, run_hour))
   {
      Comment("");
      start_lot = AMRC_LOT;
      rsi_period = AMRC_RSI;
      percent_change = AMRC_PCT;
   }
   else if (array_contains(eurp_time, run_hour))
   {
      Comment("");
      start_lot = EURP_LOT;
      rsi_period = EURP_RSI;
      percent_change = EURP_PCT;
   }

// lần đầu chạy hoặc ngay sau khi đóng lệnh
   if (first_run)
   {
//    đưa lot về mặc định và đếm order lại từ đầu sau khi đóng
      buy_lot = start_lot;
      sell_lot = start_lot;
      avail_lot = TOTAL_LOT;
      ibuy = 1;
      isell = 1;

//    mở buy và sell đồng thời
      ticket = OrderSend(Symbol(), OP_BUY, buy_lot, Ask, SLIPPAGE, stop_loss, take_profit);
      ticket = OrderSend(Symbol(), OP_SELL, sell_lot, Bid, SLIPPAGE, stop_loss, take_profit);
      avail_lot -= (buy_lot+sell_lot);

//    lưu lại giá cho mọi order để sau này tính %thay đổi
      //prev_price = Bid;
      prev_ask = Ask;
      prev_bid = Bid;

//    chỉ chạy một lần
      first_run = false;
      return;
   }

// chốt khi rsi quá bán/mua và lợi nhuận đạt tối thiểu, sau đó chạy từ đầu
   double rsi = iRSI(Symbol(), PERIOD_CURRENT, rsi_period, PRICE_CLOSE, 0);
   double profit = total_profit();
   double percent_profit = profit/AccountBalance();

   //Print("RSI: ", ceil(rsi), " Profit: ", ceil(profit), " ~ ", percent_profit, "%");

   if ((rsi >= 70 || rsi <= 30) && percent_profit >= STOP_PROFIT)
   {
      Alert("Dong tat ca order, loi nhuan: ", profit, " ~ ", percent_profit, "%");
      close_all_orders();
      return;
   }

// tỉ lệ thay đổi kích hoạt lệnh mới
   //curr_price = Bid;
   curr_ask = Ask;
   curr_bid = Bid;
   double ask_changes = (curr_ask - prev_ask) / prev_ask;
   double bid_changes = (curr_bid - prev_bid) / prev_bid;

   //double changes = (curr_price - prev_price) / prev_price;
   //Comment("Changes: ", changes, "\nProfit: ", total_profit());

   if (ask_changes <= -percent_change/100)
   {
      buy_lot = get_lot(OP_BUY);
      if (avail_lot-buy_lot >= 0)
      {
         RefreshRates();

         ticket = OrderSend(Symbol(), OP_BUY, buy_lot, curr_ask, SLIPPAGE, stop_loss, take_profit);
         avail_lot -= buy_lot;
         prev_ask = curr_ask;
         ibuy++;
      }
      else
      {
         Print("tong so lot vuot gioi han, khong mo them order moi!");
      }
   }

   if (bid_changes >= percent_change/100)
   {
      sell_lot = get_lot(OP_SELL);
      if (avail_lot-sell_lot >= 0)
      {
         RefreshRates();

         ticket = OrderSend(Symbol(), OP_SELL, sell_lot, curr_bid, SLIPPAGE, stop_loss, take_profit);
         avail_lot -= sell_lot;
         prev_bid = curr_bid;
         isell++;
      }
      else
      {
         Print("tong so lot vuot gioi han, khong mo them order moi!");
      }
   }
   
   
   double average_price = (curr_ask*buy_lot + curr_bid*sell_lot) / (buy_lot+sell_lot);
   Comment("\ngia trung binh : " + myround(average_price) + "\nloi nhuan        : " + myround(total_profit(false)));

   //Comment("Ask changes:", ask_changes, "\nBid changes: ", bid_changes, "\nLot: ", lot, "\nAvaillot: ", avail_lot, "\nProfit: ", profit);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectDelete(CLOSE_ALL);
   ObjectDelete(CLOSE_PROFIT);
   ObjectDelete(CLOSE_SELL);
   ObjectDelete(CLOSE_SELL_PROFIT);
   ObjectDelete(CLOSE_BUY);
   ObjectDelete(CLOSE_BUY_PROFIT);
   //close_all_orders();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
{
   verify(AccountNumber());
   
   SLIPPAGE = GetSLIPPAGE(Symbol(), SLIPPAGE);

   string sep = " ";
   ushort u_sep = StringGetCharacter(sep, 0);

   StringSplit(ASIA_SSN, u_sep, asia_time);
   StringSplit(AMRC_SSN, u_sep, amrc_time);
   StringSplit(EURP_SSN, u_sep, eurp_time);
   StringSplit(STOP_SSN, u_sep, stop_time);

   create_button(CLOSE_ALL         ,   15    ,    60    , "CLOSE ALL"  );
   create_button(CLOSE_PROFIT      ,   150   ,    60    , "CLOSE ALL+" );
   create_button(CLOSE_SELL        ,   15    ,    110   , "CLOSE SELL" );
   create_button(CLOSE_SELL_PROFIT ,   150   ,    110   , "CLOSE SELL+");
   create_button(CLOSE_BUY         ,   15    ,    160   , "CLOSE BUY"  );
   create_button(CLOSE_BUY_PROFIT  ,   150   ,    160   , "CLOSE BUY+" );

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
   if      (sparam == CLOSE_ALL)          close_all_orders(-1);
   else if (sparam == CLOSE_PROFIT)       close_all_orders(-1, true);
   else if (sparam == CLOSE_SELL)         close_all_orders(OP_SELL);
   else if (sparam == CLOSE_SELL_PROFIT)  close_all_orders(OP_SELL, true);
   else if (sparam == CLOSE_BUY)          close_all_orders(OP_BUY);
   else if (sparam == CLOSE_BUY_PROFIT)   close_all_orders(OP_BUY, true);
}

//+------------------------------------------------------------------+
//| Close all orders                                                 |
//+------------------------------------------------------------------+
void close_all_orders(int OP = -1, bool profit_needed=false)
{
   RefreshRates();

   // The loop starts from the last order, proceeding backwards; Otherwise it would skip some orders.
   for (int i = (OrdersTotal() - 1); i >= 0; i--)
   {
      // If the order cannot be selected, throw and log an error.
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false)
      {
         Print("LOI - khong the xu ly order - ", GetLastError());
         break;
      }
      
      if (OrderSymbol() != Symbol()) continue;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      // Result variable - to check if the operation is successful or not.
      bool res = false;
      // Bid and Ask prices for the instrument of the order.
      double BidPrice = MarketInfo(OrderSymbol(), MODE_BID);
      double AskPrice = MarketInfo(OrderSymbol(), MODE_ASK);

      if (OP == -1 || OP == OP_BUY)
      {
         if (OrderType() == OP_BUY)
         {
            if (profit_needed)
            {
               if (profit > 0) res = OrderClose(OrderTicket(), OrderLots(), BidPrice, SLIPPAGE);
               else res = true;
            }
            else res = OrderClose(OrderTicket(), OrderLots(), BidPrice, SLIPPAGE);
         }
      }

      if (OP == -1 || OP == OP_SELL)
      {
         if (OrderType() == OP_SELL)
         {
            if (profit_needed)
            {
               if (profit > 0) res = OrderClose(OrderTicket(), OrderLots(), AskPrice, SLIPPAGE);
               else res = true;
            }
            else res = OrderClose(OrderTicket(), OrderLots(), AskPrice, SLIPPAGE);
         }
      }
      if (res == false) Print("LOI - khong the close order ", OrderTicket(), " - ", GetLastError());
   }

// chạy và đếm lot lại từ đầu sau khi đóng tất cả (tự đóng hoặc bấm nút)
   first_run = true;
}

//+------------------------------------------------------------------+
//| tổng lợi nhuận trừ phí cho tới hiện tại                          |
//+------------------------------------------------------------------+
double total_profit(bool all=true)
{
   RefreshRates();

   double profit = 0.0;
   for (int i = (OrdersTotal() - 1); i >= 0; i--)
   {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false)
      {
         Print("LOI - khong the xu ly order - ", GetLastError());
         break;
      }
      
//    tách profit từng chart, kiểm tra symbol của order giống symbol hiện tại không
      if (!all && OrderSymbol() != Symbol()) continue;
      
      profit += (OrderProfit() + OrderCommission() + OrderSwap());
   }

   return(profit);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetSLIPPAGE(string Currency, int SLIPPAGEPips)
{
   int CalcSLIPPAGE = 4;
   int CalcDigits = (int)MarketInfo(Currency, MODE_DIGITS);
   if(CalcDigits == 2 || CalcDigits == 4) CalcSLIPPAGE = SLIPPAGEPips;
   else if(CalcDigits == 3 || CalcDigits == 5) CalcSLIPPAGE = SLIPPAGEPips * 10;
   return(CalcSLIPPAGE);
}

//+------------------------------------------------------------------+
//| tính số lot dựa trên số đơn cùng loại trước đó                   |
//| đơn i có lot = startlot * 2 * (i-1)^2                            |
//| isell/ibuy luôn đếm chậm hơn 1 nên không cần trừ 1 ở đây         |
//+------------------------------------------------------------------+
double get_lot(int OP)
{
   int index = (OP == OP_SELL) ? isell : ibuy;
   return(start_lot * 2 * pow(index, 2));
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void create_button(string name, int x, int y, string label, int h=35, int w=130)
{
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, label);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool array_contains(string &arr[], string s)
{
   bool res = false;

   for (int i = 0; i < ArraySize(arr); ++i)
   {
      if (s == arr[i])
      {
         res = true;
         break;
      }
   }
   return res;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string get_license_info()
{
   string headers = "Content-Type: application/JSON";
   char post[], result[];
   int res;

   ResetLastError();
   int timeout=5000;
   res = WebRequest("GET", URL, headers, timeout, post, result, headers);
   string code = CharArrayToString(post, 0, WHOLE_ARRAY, CP_UTF8);
   if (res == -1)
   {
      MessageBox("Cho phep EA truy cap https://script.google.com", "INFO", MB_ICONINFORMATION);
      //Print("Error in Webrequest. Error =", GetLastError());
   }
   string data = CharArrayToString(result);
   return(data);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void verify(int id)
{
   string userid = IntegerToString(id);
   string s = get_license_info();
   Print(s);
   string result[];

   string sep = ",";
   ushort u_sep = StringGetCharacter(sep, 0);
   int k = StringSplit(s, u_sep, result);

   bool user_exists = false;
   int uid = 0;
   for (uid; uid < k/2; ++uid)
   {
      if (userid == result[uid])
      {
         user_exists = true;
         break;
      }
   }

   if (user_exists == false)
   {
      Comment("Tai khoan chua dang ky" + "\nLien he duytue2396@gmail.com hoac telegram @duytue56");
      ExpertRemove();
      return;
   }

   string expiration_gmt = result[uid+k/2];
   long t = StringToInteger(expiration_gmt);

   if (t < TimeCurrent())
   {
      Comment("Tai khoan da het han" + "\nLien he duytue2396@gmail.com hoac telegram @duytue56");
      ExpertRemove();
      return;
   }
}

//+------------------------------------------------------------------+
//| làm tròn đến 4 chữ số thập phân                                  |
//+------------------------------------------------------------------+
double myround(double n)
{
   return floor(n*10000)/10000;
}
