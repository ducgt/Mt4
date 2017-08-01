//+------------------------------------------------------------------+
//|                                  Ichimoku EA(only USD&JPY pairs) |
//|                                           Copyright 2017, Shk0da |
//|                                       https://github.com/Shk0da/ |
//+------------------------------------------------------------------+
#include <stdlib.mqh>
#include <stderror.mqh> 
#property copyright ""
#property link ""

// ------------------------------------------------------------------------------------------------
// EXTERNAL VARIABLES
// ------------------------------------------------------------------------------------------------

extern int magic=19274;
// Configuration
extern string CommonSettings="---------------------------------------------";
extern int user_slippage=0;
extern int user_tp=20;
extern int user_sl=100;
extern bool use_tp_sl=0;
extern bool use_basic_tp=1;
extern bool use_basic_sl=0;
extern bool use_dynamic_tp=1;
extern bool use_dynamic_sl=1;
extern string MoneyManagementSettings="---------------------------------------------";
// Money Management
extern double min_lots=0.01;
extern int risk=7;
extern double profit_lock=0.9;
extern double balance_limit=50;
extern int expire_days=10;
extern double drow_down=50.0;
// Indicators
int shift=1;
int atr_period=14;
// Trailing stop
extern string TrailingStopSettings="---------------------------------------------";
extern bool ts_enable=0;
extern int ts_val=10;
extern int ts_step=1;
extern bool ts_only_profit=1;
// Average
extern string TAverage="-------------------------------------------";
extern bool av_enable=1;
int TradeDirection=4; //0 - одновременно откроются и покупки и продажи, 1 – советник будет продавать, 2 – будет покупать, 3 – чередовать ордера на покупку и продажу, 4 – советник будет открывать позиции по своему алгоритму.

                             // ------------------------------------------------------------------------------------------------
// GLOBAL VARIABLES
// ------------------------------------------------------------------------------------------------

string key="Ichimoku EA: ";
int DAY=86400;
int order_ticket;
double order_lots;
double order_price;
double order_profit;
int order_time;
double signal;
int orders=0;
int direction=0;
double max_profit=0;
double close_profit=0;
double last_order_profit=0;
double last_order_lots=0;
color c=Black;
double balance;
double equity;
int slippage=0;
// OrderReliable
int retry_attempts= 10;
double sleep_time = 4.0;
double sleep_maximum=25.0;  // in seconds
string OrderReliable_Fname="OrderReliable fname unset";
static int _OR_err=0;
string OrderReliableVersion="V1_1_1";
// ------------------------------------------------------------------------------------------------
// START
// ------------------------------------------------------------------------------------------------
int start()
  {

   if(AccountBalance()<=balance_limit)
     {
      Alert("Balance: "+AccountBalance());
      return(0);
     }

   int ticket,i,n;
   double price;
   bool cerrada,encontrada;

   if(MarketInfo(Symbol(),MODE_DIGITS)==4)
     {
      slippage=user_slippage;
     }
   else if(MarketInfo(Symbol(),MODE_DIGITS)==5)
     {
      slippage=10*user_slippage;
     }

   if(IsTradeAllowed()==false)
     {
      Comment("Trade not allowed.");
      return;
     }

   Comment("\nIchimoku EA is running.");

   InicializarVariables();
   ActualizarOrdenes();

   encontrada=FALSE;
   if(OrdersHistoryTotal()>0)
     {
      i=1;

      while(i<=100 && encontrada==FALSE)
        {
         n=OrdersHistoryTotal()-i;
         if(OrderSelect(n,SELECT_BY_POS,MODE_HISTORY)==TRUE)
           {
            if(OrderMagicNumber()==magic)
              {
               encontrada=TRUE;
               last_order_profit=OrderProfit();
               last_order_lots=OrderLots();
              }
           }
         i++;
        }
     }

   if(ts_enable) TrailingStop();
   Trade();

   return(0);
  }
//+------------------------------------------------------------------+
//| Суммарный профит открытых позиций                                |
//+------------------------------------------------------------------+
double GetPfofit(int op)
  {
   double profit=0;
   int i;

   for(i=0; i<OrdersTotal(); i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         if(OrderSymbol()==Symbol() && OrderMagicNumber()==magic && OrderType()==op)
           {
            profit+=OrderProfit()+OrderSwap()-OrderCommission();
           }
        }
     }
   return(profit);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void TrailingStop()
  {
   for(int i=0; i<OrdersTotal(); i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         if(OrderSymbol()==Symbol() && OrderMagicNumber()==magic)
           {
            TrailingPositions();
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| Position maintenance simple trawl                             |
//+------------------------------------------------------------------+
void TrailingPositions()
  {
   double pBid,pAsk,pp;
//----
   pp=MarketInfo(OrderSymbol(),MODE_POINT);

   double val;
   int stop_level=MarketInfo(Symbol(),MODE_STOPLEVEL)+MarketInfo(Symbol(),MODE_SPREAD);
   if(use_dynamic_sl==1)
     {
      double atr=iATR(Symbol(),0,atr_period,shift)/0.00001;
      if(atr<stop_level) atr=stop_level;
      val=atr;
        } else {
      if(ts_val<stop_level) ts_val=stop_level;
      val=ts_val;
     }

   if(OrderType()==OP_BUY)
     {
      pBid=MarketInfo(OrderSymbol(),MODE_BID);
      if(!ts_only_profit || (pBid-OrderOpenPrice())>val*pp)
        {
         if(OrderStopLoss()<pBid-(val+ts_step-1)*pp)
           {
            ModifyStopLoss(pBid-val*pp);
            return;
           }
        }
     }
   if(OrderType()==OP_SELL)
     {
      pAsk=MarketInfo(OrderSymbol(),MODE_ASK);
      if(!ts_only_profit || OrderOpenPrice()-pAsk>val*pp)
        {
         if(OrderStopLoss()>pAsk+(val+ts_step-1)*pp || OrderStopLoss()==0)
           {
            ModifyStopLoss(pAsk+val*pp);
            return;
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| The transfer of the StopLoss level                                          |
//| Settings:                                                       |
//|   ldStopLoss - level StopLoss                                  |
//+------------------------------------------------------------------+
void ModifyStopLoss(double ldStopLoss)
  {
   OrderModify(OrderTicket(),OrderOpenPrice(),ldStopLoss,OrderTakeProfit(),0,CLR_NONE);
  }
//+------------------------------------------------------------------+

// ------------------------------------------------------------------------------------------------
// INITIALIZE VARIABLES
// ------------------------------------------------------------------------------------------------
void InicializarVariables()
  {
   orders=0;
   direction=0;
   order_ticket=0;
   order_lots=0;
   order_price= 0;
   order_time = 0;
   order_profit=0;
   last_order_profit=0;
   last_order_lots=0;
  }
// ------------------------------------------------------------------------------------------------
// ACTUALIZAR ORDENES
// ------------------------------------------------------------------------------------------------
void ActualizarOrdenes()
  {
   int ordenes=0;

   for(int i=0; i<OrdersTotal(); i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true)
        {
         if(OrderSymbol()==Symbol() && OrderMagicNumber()==magic)
           {
            order_ticket=OrderTicket();
            order_lots=OrderLots();
            order_price= OrderOpenPrice();
            order_time = OrderOpenTime();
            order_profit=OrderProfit();
            ordenes++;
            if(OrderType()==OP_BUY) direction=1;
            if(OrderType()==OP_SELL) direction=2;
           }
        }
     }

   orders=ordenes;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetMaxLot(int Risk)
  {
   double Free=AccountFreeMargin();
   double margin=MarketInfo(Symbol(),MODE_MARGINREQUIRED);
   double Step= MarketInfo(Symbol(),MODE_LOTSTEP);
   double Lot = MathFloor(Free*Risk/100/margin/Step)*Step;
   if(Lot*margin>Free) return(0);
   return(Lot);
  }
// ------------------------------------------------------------------------------------------------
// CALCULATE VOLUME
// ------------------------------------------------------------------------------------------------
double CalcularVolumen()
  {
   int n;
   double aux;
   if(last_order_profit<0)
     {
      aux=last_order_lots*2;
     }
   else
     {
      aux= risk*AccountFreeMargin();
      aux= aux/100000;
      n=MathFloor(aux/min_lots);
      if(n>GetMaxLot(risk)) n=GetMaxLot(risk);
      aux=n*min_lots;
     }

   if(aux<min_lots) aux=min_lots;

   if(aux>MarketInfo(Symbol(),MODE_MAXLOT))
      aux=MarketInfo(Symbol(),MODE_MAXLOT);

   if(aux<MarketInfo(Symbol(),MODE_MINLOT))
      aux=MarketInfo(Symbol(),MODE_MINLOT);

   return(aux);
  }
// ------------------------------------------------------------------------------------------------
// CALCULATES PIP VALUE
// ------------------------------------------------------------------------------------------------
double CalculaValorPip(double lotes)
  {
   double aux_mm_valor=0;

   double aux_mm_tick_value= MarketInfo(Symbol(),MODE_TICKVALUE);
   double aux_mm_tick_size = MarketInfo(Symbol(),MODE_TICKSIZE);
   int aux_mm_digits=MarketInfo(Symbol(),MODE_DIGITS);
   double aux_mm_veces_lots=1/lotes;

   if(aux_mm_digits==5)
     {
      aux_mm_valor=aux_mm_tick_value*10;
     }
   else if(aux_mm_digits==4)
     {
      aux_mm_valor=aux_mm_tick_value;
     }

   if(aux_mm_digits==3)
     {
      aux_mm_valor=aux_mm_tick_value*10;
     }
   else if(aux_mm_digits==2)
     {
      aux_mm_valor=aux_mm_tick_value;
     }

   aux_mm_valor=aux_mm_valor/aux_mm_veces_lots;

   return(aux_mm_valor);
  }
// ------------------------------------------------------------------------------------------------
// CALCULATED TAKE PROFIT
// ------------------------------------------------------------------------------------------------
double GetTakeProfit(int op)
  {
   if(use_basic_tp == 0) return(0);

   double aux_take_profit=0;
   double spread=Ask-Bid;
   double val;

   int stop_level=MarketInfo(Symbol(),MODE_STOPLEVEL)+MarketInfo(Symbol(),MODE_SPREAD);
   if(use_dynamic_tp==1)
     {
      double atr=iATR(Symbol(),0,atr_period,shift)/0.00001;
      if(atr<stop_level) atr=stop_level;
      val=atr*Point;
        } else {
      if(user_tp<stop_level) user_tp=stop_level;
      val=user_tp*Point;
     }

   if(op==OP_BUY)
     {
      aux_take_profit=MarketInfo(Symbol(),MODE_ASK)+spread+val;
        } else if(op==OP_SELL) {
      aux_take_profit=MarketInfo(Symbol(),MODE_BID)-spread-val;
     }

   return(aux_take_profit);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CalculaTakeProfit()
  {
   int aux_take_profit;
   int val;

   if(use_dynamic_tp==1)
     {
      val=MathRound(iATR(Symbol(),0,atr_period,shift)/0.00001);
        } else {
      val=user_tp;
     }

   aux_take_profit=MathRound(CalculaValorPip(order_lots)*val);

   return(aux_take_profit);
  }
// ------------------------------------------------------------------------------------------------
// CALCULATES STOP LOSS
// ------------------------------------------------------------------------------------------------
double GetStopLoss(int op)
  {
   if(use_basic_sl == 0) return(0);

   double aux_stop_loss=0;

   double val;
   int stop_level=MarketInfo(Symbol(),MODE_STOPLEVEL)+MarketInfo(Symbol(),MODE_SPREAD);
   if(use_dynamic_sl==1)
     {
      double atr=iATR(Symbol(),0,atr_period,shift)/0.00001;
      if(atr<stop_level) atr=stop_level;
      val=atr*Point;
        } else {
      if(user_sl<stop_level) user_sl=stop_level;
      val=user_sl*Point;
     }

   if(op==OP_BUY)
     {
      aux_stop_loss=MarketInfo(Symbol(),MODE_ASK)-val;
        } else if(op==OP_SELL) {
      aux_stop_loss=MarketInfo(Symbol(),MODE_BID)+val;
     }

   return(aux_stop_loss);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CalculaStopLoss()
  {
   int aux_stop_loss;
   int val;

   if(use_dynamic_sl==1)
     {
      val=MathRound(iATR(Symbol(),0,atr_period,shift)/0.00001);
        } else {
      val=user_sl;
     }

   aux_stop_loss=-1*CalculaValorPip(order_lots)*val;

   return(aux_stop_loss);
  }
// ------------------------------------------------------------------------------------------------
// CALCULATED SIGNAL 
// ------------------------------------------------------------------------------------------------
int CalculaSignal()
  {
   if(AccountBalance()<=balance_limit)
     {
      return(0);
     }

   int aux_tenkan_sen=9;
   double aux_kijun_sen=26;
   double aux_senkou_span=52;
   int aux_shift=1;
   int aux=0;
   double kt1=0,kb1=0,kt2=0,kb2=0;
   double ts1,ts2,ks1,ks2,ssA1,ssA2,ssB1,ssB2,close1,close2;

   ts1 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_TENKANSEN, aux_shift);
   ks1 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_KIJUNSEN, aux_shift);
   ssA1 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_SENKOUSPANA, aux_shift);
   ssB1 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_SENKOUSPANB, aux_shift);
   close1=iClose(Symbol(),0,aux_shift);

   ts2 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_TENKANSEN, aux_shift+1);
   ks2 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_KIJUNSEN, aux_shift+1);
   ssA2 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_SENKOUSPANA, aux_shift+1);
   ssB2 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_SENKOUSPANB, aux_shift+1);
   close2=iClose(Symbol(),0,aux_shift+1);

   if(ssA1 >= ssB1) kt1 = ssA1;
   else kt1 = ssB1;

   if(ssA1 <= ssB1) kb1 = ssA1;
   else kb1 = ssB1;

   if(ssA2 >= ssB2) kt2 = ssA2;
   else kt2 = ssB2;

   if(ssA2 <= ssB2) kb2 = ssA2;
   else kb2 = ssB2;

   if((ts1>ks1 && ts2<ks2 && ks1>kt1) || (close1>ks1 && close2<ks2 && ks1>kt1) || (close1>kt1 && close2<kt2))
     {
      aux=1;
     }

   if((ts1<ks1 && ts2>ks2 && ts1<kb1) || (close1<ks1 && close2>ks2 && ks1<kb1) || (close1<kb1 && close2>kb2))
     {
      aux=2;
     }

   int aux2=0;
   int rsi_period=14;
   int macd_signal_period1=12;
   int macd_signal_period2=26;
   int macd_signal_period3=9;

   int osma_fast_ema=12;
   int osma_slow_ema=26;
   int osma_signal_sma=9;

   double rsi=iRSI(Symbol(),0,14,PRICE_CLOSE,aux_shift);
   double macd1 = iMACD(Symbol(), 0, macd_signal_period1, macd_signal_period2, macd_signal_period3, PRICE_CLOSE, MODE_SIGNAL, aux_shift);
   double macd2 = iMACD(Symbol(), 0, macd_signal_period1, macd_signal_period2, macd_signal_period3, PRICE_CLOSE, MODE_SIGNAL, aux_shift+2);
   double osma=iOsMA(Symbol(),0,osma_fast_ema,osma_slow_ema,osma_signal_sma,PRICE_CLOSE,aux_shift);

   int kg              =2;
   int Slow_MACD       =18;      //Период медленной скользящей средней (час)                       //
   int Alfa_min        =2;       //Минимальный угол наклона МА (пт/час)                            //
   int Alfa_delta      =34;      //Дельта максимального угла наклона МА (пт/час)                   //
   int Fast_MACD       =1;       //Период быстрой скользящей средней (час)                         //)        

   int j=0;
   int r=60/Period();
   double MA_0=iMA(NULL,0,Slow_MACD*r*kg,0,MODE_SMA,PRICE_OPEN,j);
   double MA_1=iMA(NULL,0,Slow_MACD*r*kg,0,MODE_SMA,PRICE_OPEN,j+1);
   double Alfa=((MA_0-MA_1)/Point)*r;
   double Fast_0=iOsMA(NULL,0,Fast_MACD*r       ,Slow_MACD*r,Slow_MACD*r,PRICE_OPEN,j);
   double Fast_1=iOsMA(NULL,0,Fast_MACD*r       ,Slow_MACD*r,Slow_MACD*r,PRICE_OPEN,j+1);
   double Slow_0=iOsMA(NULL,0,(Fast_MACD+slippage)*r,Slow_MACD*r,Slow_MACD*r,PRICE_OPEN,j);
   double Slow_1=iOsMA(NULL,0,(Fast_MACD+slippage)*r,Slow_MACD*r,Slow_MACD*r,PRICE_OPEN,j+1);

   int trend_up=0;
   int trend_dn=0;
   if(Alfa> Alfa_min && Alfa< (Alfa_min+Alfa_delta)) trend_up=1;
   if(Alfa<-Alfa_min && Alfa>-(Alfa_min+Alfa_delta)) trend_dn=1;
   int longsignal=0;
   int shortsignal=0;
   if((Fast_0-Slow_0)>0.0 && (Fast_1-Slow_1)<=0.0) longsignal=1;
   if((Fast_0-Slow_0)<0.0 && (Fast_1-Slow_1)>=0.0) shortsignal=1;

   int aux3= aux3();
   if(((aux==1 && osma>0 && rsi>=40 && macd1<macd2)||(trend_up && longsignal) && aux3>0)|| aux3>1) aux2=1;
   else if(((aux==2 && osma<0 && rsi<=60 && macd1>macd2) || (trend_dn && shortsignal) && aux3<0) || aux3<-1) aux2=2;
   else aux2=0;

   return(aux2);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int aux3()
  {
   int     TimeFrame1     = 15;
   int     TimeFrame2     = 60;
   int     TimeFrame3     = 240;
   int     TrendPeriod1   = 5;
   int     TrendPeriod2   = 8;
   int     TrendPeriod3   = 13;
   int     TrendPeriod4   = 21;
   int     TrendPeriod5   = 34;

   double MaH11v,MaH41v,MaD11v,MaH1pr1v,MaH4pr1v,MaD1pr1v;
   double MaH12v,MaH42v,MaD12v,MaH1pr2v,MaH4pr2v,MaD1pr2v;
   double MaH13v,MaH43v,MaD13v,MaH1pr3v,MaH4pr3v,MaD1pr3v;
   double MaH14v,MaH44v,MaD14v,MaH1pr4v,MaH4pr4v,MaD1pr4v;
   double MaH15v,MaH45v,MaD15v,MaH1pr5v,MaH4pr5v,MaD1pr5v;

   double u1x5v,u1x8v,u1x13v,u1x21v,u1x34v;
   double u2x5v,u2x8v,u2x13v,u2x21v,u2x34v;
   double u3x5v,u3x8v,u3x13v,u3x21v,u3x34v;
   double u1acv,u2acv,u3acv;

   double d1x5v,d1x8v,d1x13v,d1x21v,d1x34v;
   double d2x5v,d2x8v,d2x13v,d2x21v,d2x34v;
   double d3x5v,d3x8v,d3x13v,d3x21v,d3x34v;
   double d1acv,d2acv,d3acv;

   MaH11v=iMA(NULL,TimeFrame1,TrendPeriod1,0,MODE_SMA,PRICE_CLOSE,0);   MaH1pr1v=iMA(NULL,TimeFrame1,TrendPeriod1,0,MODE_SMA,PRICE_CLOSE,1);
   MaH12v=iMA(NULL,TimeFrame1,TrendPeriod2,0,MODE_SMA,PRICE_CLOSE,0);   MaH1pr2v=iMA(NULL,TimeFrame1,TrendPeriod2,0,MODE_SMA,PRICE_CLOSE,1);
   MaH13v=iMA(NULL,TimeFrame1,TrendPeriod3,0,MODE_SMA,PRICE_CLOSE,0);   MaH1pr3v=iMA(NULL,TimeFrame1,TrendPeriod3,0,MODE_SMA,PRICE_CLOSE,1);
   MaH14v=iMA(NULL,TimeFrame1,TrendPeriod4,0,MODE_SMA,PRICE_CLOSE,0);   MaH1pr4v=iMA(NULL,TimeFrame1,TrendPeriod4,0,MODE_SMA,PRICE_CLOSE,1);
   MaH15v=iMA(NULL,TimeFrame1,TrendPeriod5,0,MODE_SMA,PRICE_CLOSE,0);   MaH1pr5v=iMA(NULL,TimeFrame1,TrendPeriod5,0,MODE_SMA,PRICE_CLOSE,1);

   MaH41v=iMA(NULL,TimeFrame2,TrendPeriod1,0,MODE_SMA,PRICE_CLOSE,0);   MaH4pr1v=iMA(NULL,TimeFrame2,TrendPeriod1,0,MODE_SMA,PRICE_CLOSE,1);
   MaH42v=iMA(NULL,TimeFrame2,TrendPeriod2,0,MODE_SMA,PRICE_CLOSE,0);   MaH4pr2v=iMA(NULL,TimeFrame2,TrendPeriod2,0,MODE_SMA,PRICE_CLOSE,1);
   MaH43v=iMA(NULL,TimeFrame2,TrendPeriod3,0,MODE_SMA,PRICE_CLOSE,0);   MaH4pr3v=iMA(NULL,TimeFrame2,TrendPeriod3,0,MODE_SMA,PRICE_CLOSE,1);
   MaH44v=iMA(NULL,TimeFrame2,TrendPeriod4,0,MODE_SMA,PRICE_CLOSE,0);   MaH4pr4v=iMA(NULL,TimeFrame2,TrendPeriod4,0,MODE_SMA,PRICE_CLOSE,1);
   MaH45v=iMA(NULL,TimeFrame2,TrendPeriod5,0,MODE_SMA,PRICE_CLOSE,0);   MaH4pr5v=iMA(NULL,TimeFrame2,TrendPeriod5,0,MODE_SMA,PRICE_CLOSE,1);

   MaD11v=iMA(NULL,TimeFrame3,TrendPeriod1,0,MODE_SMA,PRICE_CLOSE,0);   MaD1pr1v=iMA(NULL,TimeFrame3,TrendPeriod1,0,MODE_SMA,PRICE_CLOSE,1);
   MaD12v=iMA(NULL,TimeFrame3,TrendPeriod2,0,MODE_SMA,PRICE_CLOSE,0);   MaD1pr2v=iMA(NULL,TimeFrame3,TrendPeriod2,0,MODE_SMA,PRICE_CLOSE,1);
   MaD13v=iMA(NULL,TimeFrame3,TrendPeriod3,0,MODE_SMA,PRICE_CLOSE,0);   MaD1pr3v=iMA(NULL,TimeFrame3,TrendPeriod3,0,MODE_SMA,PRICE_CLOSE,1);
   MaD14v=iMA(NULL,TimeFrame3,TrendPeriod4,0,MODE_SMA,PRICE_CLOSE,0);   MaD1pr4v=iMA(NULL,TimeFrame3,TrendPeriod4,0,MODE_SMA,PRICE_CLOSE,1);
   MaD15v=iMA(NULL,TimeFrame3,TrendPeriod5,0,MODE_SMA,PRICE_CLOSE,0);   MaD1pr5v=iMA(NULL,TimeFrame3,TrendPeriod5,0,MODE_SMA,PRICE_CLOSE,1);

   if(MaH11v < MaH1pr1v) {u1x5v = 0; d1x5v = 1;}
   if(MaH11v > MaH1pr1v) {u1x5v = 1; d1x5v = 0;}
   if(MaH11v == MaH1pr1v){u1x5v = 0; d1x5v = 0;}
   if(MaH41v < MaH4pr1v) {u2x5v = 0; d2x5v = 1;}
   if(MaH41v > MaH4pr1v) {u2x5v = 1; d2x5v = 0;}
   if(MaH41v == MaH4pr1v){u2x5v = 0; d2x5v = 0;}
   if(MaD11v < MaD1pr1v) {u3x5v = 0; d3x5v = 1;}
   if(MaD11v > MaD1pr1v) {u3x5v = 1; d3x5v = 0;}
   if(MaD11v == MaD1pr1v){u3x5v = 0; d3x5v = 0;}

   if(MaH12v < MaH1pr2v) {u1x8v = 0; d1x8v = 1;}
   if(MaH12v > MaH1pr2v) {u1x8v = 1; d1x8v = 0;}
   if(MaH12v == MaH1pr2v){u1x8v = 0; d1x8v = 0;}
   if(MaH42v < MaH4pr2v) {u2x8v = 0; d2x8v = 1;}
   if(MaH42v > MaH4pr2v) {u2x8v = 1; d2x8v = 0;}
   if(MaH42v == MaH4pr2v){u2x8v = 0; d2x8v = 0;}
   if(MaD12v < MaD1pr2v) {u3x8v = 0; d3x8v = 1;}
   if(MaD12v > MaD1pr2v) {u3x8v = 1; d3x8v = 0;}
   if(MaD12v == MaD1pr2v){u3x8v = 0; d3x8v = 0;}

   if(MaH13v < MaH1pr3v) {u1x13v = 0; d1x13v = 1;}
   if(MaH13v > MaH1pr3v) {u1x13v = 1; d1x13v = 0;}
   if(MaH13v == MaH1pr3v){u1x13v = 0; d1x13v = 0;}
   if(MaH43v < MaH4pr3v) {u2x13v = 0; d2x13v = 1;}
   if(MaH43v > MaH4pr3v) {u2x13v = 1; d2x13v = 0;}
   if(MaH43v == MaH4pr3v){u2x13v = 0; d2x13v = 0;}
   if(MaD13v < MaD1pr3v) {u3x13v = 0; d3x13v = 1;}
   if(MaD13v > MaD1pr3v) {u3x13v = 1; d3x13v = 0;}
   if(MaD13v == MaD1pr3v){u3x13v = 0; d3x13v = 0;}

   if(MaH14v < MaH1pr4v) {u1x21v = 0; d1x21v = 1;}
   if(MaH14v > MaH1pr4v) {u1x21v = 1; d1x21v = 0;}
   if(MaH14v == MaH1pr4v){u1x21v = 0; d1x21v = 0;}
   if(MaH44v < MaH4pr4v) {u2x21v = 0; d2x21v = 1;}
   if(MaH44v > MaH4pr4v) {u2x21v = 1; d2x21v = 0;}
   if(MaH44v == MaH4pr4v){u2x21v = 0; d2x21v = 0;}
   if(MaD14v < MaD1pr4v) {u3x21v = 0; d3x21v = 1;}
   if(MaD14v > MaD1pr4v) {u3x21v = 1; d3x21v = 0;}
   if(MaD14v == MaD1pr4v){u3x21v = 0; d3x21v = 0;}

   if(MaH15v < MaH1pr5v) {u1x34v = 0; d1x34v = 1;}
   if(MaH15v > MaH1pr5v) {u1x34v = 1; d1x34v = 0;}
   if(MaH15v == MaH1pr5v){u1x34v = 0; d1x34v = 0;}
   if(MaH45v < MaH4pr5v) {u2x34v = 0; d2x34v = 1;}
   if(MaH45v > MaH4pr5v) {u2x34v = 1; d2x34v = 0;}
   if(MaH45v == MaH4pr5v){u2x34v = 0; d2x34v = 0;}
   if(MaD15v < MaD1pr5v) {u3x34v = 0; d3x34v = 1;}
   if(MaD15v > MaD1pr5v) {u3x34v = 1; d3x34v = 0;}
   if(MaD15v == MaD1pr5v){u3x34v = 0; d3x34v = 0;}

   double  acv  = iAC(NULL, TimeFrame1, 0);
   double  ac1v = iAC(NULL, TimeFrame1, 1);
   double  ac2v = iAC(NULL, TimeFrame1, 2);
   double  ac3v = iAC(NULL, TimeFrame1, 3);

   if((ac1v>ac2v && ac2v>ac3v && acv<0 && acv>ac1v)||(acv>ac1v && ac1v>ac2v && acv>0)) {u1acv = 3; d1acv = 0;}
   if((ac1v<ac2v && ac2v<ac3v && acv>0 && acv<ac1v)||(acv<ac1v && ac1v<ac2v && acv<0)) {u1acv = 0; d1acv = 3;}
   if((((ac1v<ac2v || ac2v<ac3v) && acv<0 && acv>ac1v) || (acv>ac1v && ac1v<ac2v && acv>0))
      || (((ac1v>ac2v || ac2v>ac3v) && acv>0 && acv<ac1v) || (acv<ac1v && ac1v>ac2v && acv<0)))
     {u1acv=0; d1acv=0;}

   double  ac03v = iAC(NULL, TimeFrame3, 0);
   double  ac13v = iAC(NULL, TimeFrame3, 1);
   double  ac23v = iAC(NULL, TimeFrame3, 2);
   double  ac33v = iAC(NULL, TimeFrame3, 3);

   if((ac13v>ac23v && ac23v>ac33v && ac03v<0 && ac03v>ac13v)||(ac03v>ac13v && ac13v>ac23v && ac03v>0)) {u3acv = 3; d3acv = 0;}
   if((ac13v<ac23v && ac23v<ac33v && ac03v>0 && ac03v<ac13v)||(ac03v<ac13v && ac13v<ac23v && ac03v<0)) {u3acv = 0; d3acv = 3;}
   if((((ac13v<ac23v || ac23v<ac33v) && ac03v<0 && ac03v>ac13v) || (ac03v>ac13v && ac13v<ac23v && ac03v>0))
      || (((ac13v>ac23v || ac23v>ac33v) && ac03v>0 && ac03v<ac13v) || (ac03v<ac13v && ac13v>ac23v && ac03v<0)))
     {u3acv=0; d3acv=0;}

   double uitog1v = (u1x5v + u1x8v + u1x13v + u1x21v + u1x34v + u1acv) * 12.5;
   double uitog2v = (u2x5v + u2x8v + u2x13v + u2x21v + u2x34v + u2acv) * 12.5;
   double uitog3v = (u3x5v + u3x8v + u3x13v + u3x21v + u3x34v + u3acv) * 12.5;

   double ditog1v = (d1x5v + d1x8v + d1x13v + d1x21v + d1x34v + d1acv) * 12.5;
   double ditog2v = (d2x5v + d2x8v + d2x13v + d2x21v + d2x34v + d2acv) * 12.5;
   double ditog3v = (d3x5v + d3x8v + d3x13v + d3x21v + d3x34v + d3acv) * 12.5;

   int Signal=0;                                                 Comment("Signal is zero.");
   if(uitog1v>50  && uitog2v>50  && uitog3v>50)  {Signal=1; Comment("Signal is one   BUY");}
   if(ditog1v>50  && ditog2v>50  && ditog3v>50)  {Signal=-1;Comment("Signal, is minus one, SELL");}
   if(uitog1v>=75 && uitog2v>=75 && uitog3v>=75) {Signal=2; Comment("Signal is two, BUY");}
   if(ditog1v>=75 && ditog2v>=75 && ditog3v>=75) {Signal=-2;Comment("Signal is minus two, SELL");}
   return(Signal);
  }
// ------------------------------------------------------------------------------------------------
// Trade
// ------------------------------------------------------------------------------------------------
void Trade()
  {
   bool cerrada;
   int ticket=-1,i;

   if(orders==0 && direction==0)
     {
      signal=CalculaSignal();
      if(signal==1)
        {
         ticket=OrderSendReliable(Symbol(),OP_BUY,CalcularVolumen(),MarketInfo(Symbol(),MODE_ASK),slippage,GetStopLoss(OP_BUY),GetTakeProfit(OP_BUY),key,magic,0,Blue);
        }

      if(signal==2)
        {
         ticket=OrderSendReliable(Symbol(),OP_SELL,CalcularVolumen(),MarketInfo(Symbol(),MODE_BID),slippage,GetStopLoss(OP_SELL),GetTakeProfit(OP_SELL),key,magic,0,Red);
        }
     }

   if(orders>0 && use_tp_sl==1)
     {
      if(order_profit>CalculaTakeProfit() && max_profit==0)
        {
         max_profit=order_profit;
         close_profit=profit_lock*order_profit;
        }

      if(max_profit>0 && order_profit>max_profit)
        {
         max_profit=order_profit;
         close_profit=profit_lock*order_profit;
        }

      if(max_profit>0 && close_profit>0 && max_profit>close_profit && order_profit<close_profit && order_profit>0)
        {
         if(direction==1)
            cerrada=OrderCloseReliable(order_ticket,order_lots,MarketInfo(Symbol(),MODE_BID),slippage,Blue);
         if(direction==2)
            cerrada=OrderCloseReliable(order_ticket,order_lots,MarketInfo(Symbol(),MODE_ASK),slippage,Blue);
         max_profit=0;
         close_profit=0;
        }

      if(order_profit<=CalculaStopLoss() && order_profit>=0)
        {
         if(direction==1)
            cerrada=OrderCloseReliable(order_ticket,order_lots,MarketInfo(Symbol(),MODE_BID),slippage,Blue);
         if(direction==2)
            cerrada=OrderCloseReliable(order_ticket,order_lots,MarketInfo(Symbol(),MODE_ASK),slippage,Blue);
         max_profit=0;
         close_profit=0;
        }

      if(av_enable && order_profit<=CalculaStopLoss()) 
        {
         if(signal==1) TradeDirection=1;
         else if(signal==2) TradeDirection=2;
         else TradeDirection=4;
         Average();
        }
     }

   if(orders>0 && use_tp_sl==0)
     {
      signal=CalculaSignal();

      if(signal==2 && direction==1 && order_profit>0)
        {
         cerrada=OrderCloseReliable(order_ticket,order_lots,MarketInfo(Symbol(),MODE_BID),slippage,Blue);
         max_profit=0;
         close_profit=0;
        }
      if(signal==1 && direction==2 && order_profit>0)
        {
         cerrada=OrderCloseReliable(order_ticket,order_lots,MarketInfo(Symbol(),MODE_ASK),slippage,Red);
         max_profit=0;
         close_profit=0;
        }

      if(av_enable && order_profit<0) 
        {
         if(signal==1) TradeDirection=1;
         else if(signal==2) TradeDirection=2;
         else TradeDirection=4;
         Average();
        }
     }

   double profit=GetPfofit(OP_SELL)+GetPfofit(OP_BUY);
   double dd=100.0*(AccountBalance()-AccountEquity())/AccountBalance();
   if((profit>=0 || (dd>drow_down)) && order_time<(TimeCurrent()-DAY*expire_days))
     {
      if(direction==1)
         cerrada=OrderCloseReliable(order_ticket,order_lots,MarketInfo(Symbol(),MODE_BID),slippage,Blue);
      if(direction==2)
         cerrada=OrderCloseReliable(order_ticket,order_lots,MarketInfo(Symbol(),MODE_ASK),slippage,Blue);
      max_profit=0;
      close_profit=0;
     }
  }
//=============================================================================
//							 OrderSendReliable()
//
//	This is intended to be a drop-in replacement for OrderSend() which, 
//	one hopes, is more resistant to various forms of errors prevalent 
//	with MetaTrader.
//			  
//	RETURN VALUE: 
//
//	Ticket number or -1 under some error conditions.  Check
// final error returned by Metatrader with OrderReliableLastErr().
// This will reset the value from GetLastError(), so in that sense it cannot
// be a total drop-in replacement due to Metatrader flaw. 
//
//	FEATURES:
//
//		 * Re-trying under some error conditions, sleeping a random 
//		   time defined by an exponential probability distribution.
//
//		 * Automatic normalization of Digits
//
//		 * Automatically makes sure that stop levels are more than
//		   the minimum stop distance, as given by the server. If they
//		   are too close, they are adjusted.
//
//		 * Automatically converts stop orders to market orders 
//		   when the stop orders are rejected by the server for 
//		   being to close to market.  NOTE: This intentionally
//       applies only to OP_BUYSTOP and OP_SELLSTOP, 
//       OP_BUYLIMIT and OP_SELLLIMIT are not converted to market
//       orders and so for prices which are too close to current
//       this function is likely to loop a few times and return
//       with the "invalid stops" error message. 
//       Note, the commentary in previous versions erroneously said
//       that limit orders would be converted.  Note also
//       that entering a BUYSTOP or SELLSTOP new order is distinct
//       from setting a stoploss on an outstanding order; use
//       OrderModifyReliable() for that. 
//
//		 * Displays various error messages on the log for debugging.
//
//
//	Matt Kennel, 2006-05-28 and following
//
//=============================================================================
int OrderSendReliable(string symbol,int cmd,double volume,double price,
                      int slippage,double stoploss,double takeprofit,
                      string comment,int magic,datetime expiration=0,
                      color arrow_color=CLR_NONE)
  {

// ------------------------------------------------
// Check basic conditions see if trade is possible. 
// ------------------------------------------------
   OrderReliable_Fname="OrderSendReliable";
   OrderReliablePrint(" attempted "+OrderReliable_CommandString(cmd)+" "+volume+
                      " lots @"+price+" sl:"+stoploss+" tp:"+takeprofit);

   if(IsStopped())
     {
      OrderReliablePrint("error: IsStopped() == true");
      _OR_err=ERR_COMMON_ERROR;
      return(-1);
     }

   int cnt=0;
   while(!IsTradeAllowed() && cnt<retry_attempts)
     {
      OrderReliable_SleepRandomTime(sleep_time,sleep_maximum);
      cnt++;
     }

   if(!IsTradeAllowed())
     {
      OrderReliablePrint("error: no operation possible because IsTradeAllowed()==false, even after retries.");
      _OR_err=ERR_TRADE_CONTEXT_BUSY;

      return(-1);
     }

// Normalize all price / stoploss / takeprofit to the proper # of digits.
   int digits=MarketInfo(symbol,MODE_DIGITS);
   if(digits>0)
     {
      price=NormalizeDouble(price,digits);
      stoploss=NormalizeDouble(stoploss,digits);
      takeprofit=NormalizeDouble(takeprofit,digits);
     }

   if(stoploss!=0)
      OrderReliable_EnsureValidStop(symbol,price,stoploss);

   int err=GetLastError(); // clear the global variable.  
   err=0;
   _OR_err=0;
   bool exit_loop=false;
   bool limit_to_market=false;

// limit/stop order. 
   int ticket=-1;

   if((cmd==OP_BUYSTOP) || (cmd==OP_SELLSTOP) || (cmd==OP_BUYLIMIT) || (cmd==OP_SELLLIMIT))
     {
      cnt=0;
      while(!exit_loop)
        {
         if(IsTradeAllowed())
           {
            ticket=OrderSend(symbol,cmd,volume,price,slippage,stoploss,
                             takeprofit,comment,magic,expiration,arrow_color);
            err=GetLastError();
            _OR_err=err;
           }
         else
           {
            cnt++;
           }

         switch(err)
           {
            case ERR_NO_ERROR:
               exit_loop=true;
               break;

               // retryable errors
            case ERR_SERVER_BUSY:
            case ERR_NO_CONNECTION:
            case ERR_INVALID_PRICE:
            case ERR_OFF_QUOTES:
            case ERR_BROKER_BUSY:
            case ERR_TRADE_CONTEXT_BUSY:
               cnt++;
               break;

            case ERR_PRICE_CHANGED:
            case ERR_REQUOTE:
               RefreshRates();
               continue;   // we can apparently retry immediately according to MT docs.

            case ERR_INVALID_STOPS:
               double servers_min_stop=MarketInfo(symbol,MODE_STOPLEVEL)*MarketInfo(symbol,MODE_POINT);
               if(cmd==OP_BUYSTOP)
                 {
                  // If we are too close to put in a limit/stop order so go to market.
                  if(MathAbs(MarketInfo(symbol,MODE_ASK)-price)<=servers_min_stop)
                     limit_to_market=true;

                 }
               else if(cmd==OP_SELLSTOP)
                 {
                  // If we are too close to put in a limit/stop order so go to market.
                  if(MathAbs(MarketInfo(symbol,MODE_BID)-price)<=servers_min_stop)
                     limit_to_market=true;
                 }
               exit_loop=true;
               break;

            default:
               // an apparently serious error.
               exit_loop=true;
               break;

           }  // end switch 

         if(cnt>retry_attempts)
            exit_loop=true;

         if(exit_loop)
           {
            if(err!=ERR_NO_ERROR)
              {
               OrderReliablePrint("non-retryable error: "+OrderReliableErrTxt(err));
              }
            if(cnt>retry_attempts)
              {
               OrderReliablePrint("retry attempts maxed at "+retry_attempts);
              }
           }

         if(!exit_loop)
           {
            OrderReliablePrint("retryable error ("+cnt+"/"+retry_attempts+
                               "): "+OrderReliableErrTxt(err));
            OrderReliable_SleepRandomTime(sleep_time,sleep_maximum);
            RefreshRates();
           }
        }

      // We have now exited from loop. 
      if(err==ERR_NO_ERROR)
        {
         OrderReliablePrint("apparently successful OP_BUYSTOP or OP_SELLSTOP order placed, details follow.");
         OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES);
         OrderPrint();
         return(ticket); // SUCCESS! 
        }
      if(!limit_to_market)
        {
         OrderReliablePrint("failed to execute stop or limit order after "+cnt+" retries");
         OrderReliablePrint("failed trade: "+OrderReliable_CommandString(cmd)+" "+symbol+
                            "@"+price+" tp@"+takeprofit+" sl@"+stoploss);
         OrderReliablePrint("last error: "+OrderReliableErrTxt(err));
         return(-1);
        }
     }  // end	  

   if(limit_to_market)
     {
      OrderReliablePrint("going from limit order to market order because market is too close.");
      if((cmd==OP_BUYSTOP) || (cmd==OP_BUYLIMIT))
        {
         cmd=OP_BUY;
         price=MarketInfo(symbol,MODE_ASK);
        }
      else if((cmd==OP_SELLSTOP) || (cmd==OP_SELLLIMIT))
        {
         cmd=OP_SELL;
         price=MarketInfo(symbol,MODE_BID);
        }
     }

// we now have a market order.
   err=GetLastError(); // so we clear the global variable.  
   err= 0;
   _OR_err= 0;
   ticket = -1;

   if((cmd==OP_BUY) || (cmd==OP_SELL))
     {
      cnt=0;
      while(!exit_loop)
        {
         if(IsTradeAllowed())
           {
            ticket=OrderSend(symbol,cmd,volume,price,slippage,
                             stoploss,takeprofit,comment,magic,
                             expiration,arrow_color);
            err=GetLastError();
            _OR_err=err;
           }
         else
           {
            cnt++;
           }
         switch(err)
           {
            case ERR_NO_ERROR:
               exit_loop=true;
               break;

            case ERR_SERVER_BUSY:
            case ERR_NO_CONNECTION:
            case ERR_INVALID_PRICE:
            case ERR_OFF_QUOTES:
            case ERR_BROKER_BUSY:
            case ERR_TRADE_CONTEXT_BUSY:
               cnt++; // a retryable error
               break;

            case ERR_PRICE_CHANGED:
            case ERR_REQUOTE:
               RefreshRates();
               continue; // we can apparently retry immediately according to MT docs.

            default:
               // an apparently serious, unretryable error.
               exit_loop=true;
               break;

           }  // end switch 

         if(cnt>retry_attempts)
            exit_loop=true;

         if(!exit_loop)
           {
            OrderReliablePrint("retryable error ("+cnt+"/"+
                               retry_attempts+"): "+OrderReliableErrTxt(err));
            OrderReliable_SleepRandomTime(sleep_time,sleep_maximum);
            RefreshRates();
           }

         if(exit_loop)
           {
            if(err!=ERR_NO_ERROR)
              {
               OrderReliablePrint("non-retryable error: "+OrderReliableErrTxt(err));
              }
            if(cnt>retry_attempts)
              {
               OrderReliablePrint("retry attempts maxed at "+retry_attempts);
              }
           }
        }

      // we have now exited from loop. 
      if(err==ERR_NO_ERROR)
        {
         OrderReliablePrint("apparently successful OP_BUY or OP_SELL order placed, details follow.");
         OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES);
         OrderPrint();
         return(ticket); // SUCCESS! 
        }
      OrderReliablePrint("failed to execute OP_BUY/OP_SELL, after "+cnt+" retries");
      OrderReliablePrint("failed trade: "+OrderReliable_CommandString(cmd)+" "+symbol+
                         "@"+price+" tp@"+takeprofit+" sl@"+stoploss);
      OrderReliablePrint("last error: "+OrderReliableErrTxt(err));
      return(-1);
     }
  }
//=============================================================================
//							 OrderCloseReliable()
//
//	This is intended to be a drop-in replacement for OrderClose() which, 
//	one hopes, is more resistant to various forms of errors prevalent 
//	with MetaTrader.
//			  
//	RETURN VALUE: 
//
//		TRUE if successful, FALSE otherwise
//
//
//	FEATURES:
//
//		 * Re-trying under some error conditions, sleeping a random 
//		   time defined by an exponential probability distribution.
//
//		 * Displays various error messages on the log for debugging.
//
//
//	Derk Wehler, ashwoods155@yahoo.com  	2006-07-19
//
//=============================================================================
bool OrderCloseReliable(int ticket,double lots,double price,
                        int slippage,color arrow_color=CLR_NONE)
  {
   int nOrderType;
   string strSymbol;
   OrderReliable_Fname="OrderCloseReliable";

   OrderReliablePrint(" attempted close of #"+ticket+" price:"+price+
                      " lots:"+lots+" slippage:"+slippage);

// collect details of order so that we can use GetMarketInfo later if needed
   if(!OrderSelect(ticket,SELECT_BY_TICKET))
     {
      _OR_err=GetLastError();
      OrderReliablePrint("error: "+ErrorDescription(_OR_err));
      return(false);
     }
   else
     {
      nOrderType= OrderType();
      strSymbol = OrderSymbol();
     }

   if(nOrderType!=OP_BUY && nOrderType!=OP_SELL)
     {
      _OR_err=ERR_INVALID_TICKET;
      OrderReliablePrint("error: trying to close ticket #"+ticket+", which is "+OrderReliable_CommandString(nOrderType)+", not OP_BUY or OP_SELL");
      return(false);
     }

   if(IsStopped())
     {
      OrderReliablePrint("error: IsStopped() == true");
      return(false);
     }

   int cnt=0;

   int err=GetLastError(); // so we clear the global variable.  
   err=0;
   _OR_err=0;
   bool exit_loop=false;
   cnt=0;
   bool result=false;

   while(!exit_loop)
     {
      if(IsTradeAllowed())
        {
         result=OrderClose(ticket,lots,price,slippage,arrow_color);
         err=GetLastError();
         _OR_err=err;
        }
      else
         cnt++;

      if(result==true)
         exit_loop=true;

      switch(err)
        {
         case ERR_NO_ERROR:
            exit_loop=true;
            break;

         case ERR_SERVER_BUSY:
         case ERR_NO_CONNECTION:
         case ERR_INVALID_PRICE:
         case ERR_OFF_QUOTES:
         case ERR_BROKER_BUSY:
         case ERR_TRADE_CONTEXT_BUSY:
         case ERR_TRADE_TIMEOUT:      // for modify this is a retryable error, I hope. 
            cnt++;    // a retryable error
            break;

         case ERR_PRICE_CHANGED:
         case ERR_REQUOTE:
            continue;    // we can apparently retry immediately according to MT docs.

         default:
            // an apparently serious, unretryable error.
            exit_loop=true;
            break;

        }  // end switch 

      if(cnt>retry_attempts)
         exit_loop=true;

      if(!exit_loop)
        {
         OrderReliablePrint("retryable error ("+cnt+"/"+retry_attempts+
                            "): "+OrderReliableErrTxt(err));
         OrderReliable_SleepRandomTime(sleep_time,sleep_maximum);
         // Added by Paul Hampton-Smith to ensure that price is updated for each retry
         if(nOrderType == OP_BUY)  price = NormalizeDouble(MarketInfo(strSymbol,MODE_BID),MarketInfo(strSymbol,MODE_DIGITS));
         if(nOrderType == OP_SELL) price = NormalizeDouble(MarketInfo(strSymbol,MODE_ASK),MarketInfo(strSymbol,MODE_DIGITS));
        }

      if(exit_loop)
        {
         if((err!=ERR_NO_ERROR) && (err!=ERR_NO_RESULT))
            OrderReliablePrint("non-retryable error: "+OrderReliableErrTxt(err));

         if(cnt>retry_attempts)
            OrderReliablePrint("retry attempts maxed at "+retry_attempts);
        }
     }

// we have now exited from loop. 
   if((result==true) || (err==ERR_NO_ERROR))
     {
      OrderReliablePrint("apparently successful close order, updated trade details follow.");
      OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES);
      OrderPrint();
      return(true); // SUCCESS! 
     }

   OrderReliablePrint("failed to execute close after "+cnt+" retries");
   OrderReliablePrint("failed close: Ticket #"+ticket+", Price: "+
                      price+", Slippage: "+slippage);
   OrderReliablePrint("last error: "+OrderReliableErrTxt(err));

   return(false);
  }
//=============================================================================
//=============================================================================
//								Utility Functions
//=============================================================================
//=============================================================================



int OrderReliableLastErr()
  {
   return (_OR_err);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string OrderReliableErrTxt(int err)
  {
   return ("" + err + ":" + ErrorDescription(err));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OrderReliablePrint(string s)
  {
// Print to log prepended with stuff;
   if(!(IsTesting() || IsOptimization())) Print(OrderReliable_Fname+" "+OrderReliableVersion+":"+s);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string OrderReliable_CommandString(int cmd)
  {
   if(cmd==OP_BUY)
      return("OP_BUY");

   if(cmd==OP_SELL)
      return("OP_SELL");

   if(cmd==OP_BUYSTOP)
      return("OP_BUYSTOP");

   if(cmd==OP_SELLSTOP)
      return("OP_SELLSTOP");

   if(cmd==OP_BUYLIMIT)
      return("OP_BUYLIMIT");

   if(cmd==OP_SELLLIMIT)
      return("OP_SELLLIMIT");

   return("(CMD==" + cmd + ")");
  }
//=============================================================================
//
//						 OrderReliable_EnsureValidStop()
//
// 	Adjust stop loss so that it is legal.
//
//	Matt Kennel 
//
//=============================================================================
void OrderReliable_EnsureValidStop(string symbol,double price,double &sl)
  {
// Return if no S/L
   if(sl==0)
      return;

   double servers_min_stop=MarketInfo(symbol,MODE_STOPLEVEL)*MarketInfo(symbol,MODE_POINT);

   if(MathAbs(price-sl)<=servers_min_stop)
     {
      // we have to adjust the stop.
      if(price>sl)
         sl=price-servers_min_stop;   // we are long

      else if(price<sl)
         sl=price+servers_min_stop;   // we are short

      else
         OrderReliablePrint("EnsureValidStop: error, passed in price == sl, cannot adjust");

      sl=NormalizeDouble(sl,MarketInfo(symbol,MODE_DIGITS));
     }
  }
//=============================================================================
//
//						 OrderReliable_SleepRandomTime()
//
//	This sleeps a random amount of time defined by an exponential 
//	probability distribution. The mean time, in Seconds is given 
//	in 'mean_time'.
//
//	This is the back-off strategy used by Ethernet.  This will 
//	quantize in tenths of seconds, so don't call this with a too 
//	small a number.  This returns immediately if we are backtesting
//	and does not sleep.
//
//	Matt Kennel mbkennelfx@gmail.com.
//
//=============================================================================
void OrderReliable_SleepRandomTime(double mean_time,double max_time)
  {
   if(IsTesting())
      return;    // return immediately if backtesting.

   double tenths=MathCeil(mean_time/0.1);
   if(tenths<=0)
      return;

   int maxtenths=MathRound(max_time/0.1);
   double p=1.0-1.0/tenths;

   Sleep(100);    // one tenth of a second PREVIOUS VERSIONS WERE STUPID HERE. 

   for(int i=0; i<maxtenths; i++)
     {
      if(MathRand()>p*32768)
         break;

      // MathRand() returns in 0..32767
      Sleep(100);
     }
  }
//+------------------------------------------------------------------+

void Average()
  {
   initAV();
   double ld_0;
   int li_8;
   bool li_12;
   f0_9();
   f0_19();
   if(StopWhenProfitReached && ControlBalance>0.0 && LockInProfits>0.0 && gd_872>0.0)
     {
      if(AccountEquity()>=ControlBalance+LockInProfits)
        {
         Print("Close of all trades due to profit target reached");
         f0_25(OP_BUY);
         f0_25(OP_SELL);
         return (0);
        }
     }
   g_bool_772=FALSE;
   if(DoTrades==TRUE && ((DayOfWeek()==1 && MONDAY) || (DayOfWeek()==2 && TUESDAY) || (DayOfWeek()==3 && WEDNESDAY) || (DayOfWeek()==4 && THURSDAY) || (DayOfWeek()==5 && FRIDAY) || (DayOfWeek()==0 && SUNDAY))) g_bool_772=TRUE;
   f0_30();
   f0_29();
   if(!UseMartingaleDisrupter) f0_0();
   if(UseMartingaleDisrupter) f0_5();
   if(CloseAllBuyTrades) f0_25(OP_BUY);
   if(CloseAllSellTrades) f0_25(OP_SELL);
   if(!gi_448) f0_28();
   if(gi_448)
     {
      ld_0=gi_700;
      f0_28();
      if(gi_160 && gi_700<ld_0) gi_700=ld_0;
     }
   f0_4();
   if(g_count_800 > g_global_var_812) g_global_var_812 = g_count_800;
   if(g_count_796 > g_global_var_808) g_global_var_808 = g_count_796;
   f0_24();
   f0_20();
   if(gi_488>=0)
     {
      gd_500=gd_532*gi_148;
      if(ModifyMartingale && g_count_796==1) gd_500=gd_564;
      gd_500 = NormalizeDouble(gd_500, gi_748);
      gi_476 = gi_704;
      if(UseGridExpander && OnlyAfterLevel!=0 && g_count_796>=OnlyAfterLevel) gi_476=gi_704+ExpandPips;
      if(UseGridExpander && OnlyAfterLevel2!=0 && g_count_796>=OnlyAfterLevel2) gi_476=gi_704+ExpandPips2;
      if(UseGridExpander && gi_256!=0 && g_count_796>=gi_256) gi_476=gi_704+gi_300;
      gd_776 = gd_500;
      gd_756 = g_order_open_price_548 - gi_476 * Point;
     }
   if(gi_488<=0)
     {
      gd_500=gd_524*gi_148;
      if(ModifyMartingale && g_count_800==1) gd_500=gd_564;
      gd_500 = NormalizeDouble(gd_500, gi_748);
      gi_480 = gi_708;
      if(UseGridExpander && OnlyAfterLevel!=0 && g_count_800>=OnlyAfterLevel) gi_480=gi_708+ExpandPips;
      if(UseGridExpander && OnlyAfterLevel2!=0 && g_count_800>=OnlyAfterLevel2) gi_480=gi_708+ExpandPips2;
      if(UseGridExpander && gi_256!=0 && g_count_800>=gi_256) gi_480=gi_708+gi_300;
      gd_784 = gd_500;
      gd_764 = g_order_open_price_540 + gi_480 * Point;
     }
   if(gd_532==0.0 && gi_488>=0 && WaitPips>0 && gd_1120==0.0) gd_1120=Ask-WaitPips*Point;
   if(g_bool_772==TRUE && MonitorAndClose==FALSE && gi_488>=0 && gd_532==0.0 && (WaitPips==0 || Ask<=gd_1120))
     {
      if(gd_1148!=0.0)
        {
         Print("Max Margin Utilization Percentage vs. Equity For Last Trade Sequence = "+DoubleToStr(100.0*gd_1148,2));
         gd_1148=0.0;
        }
      f0_28();
      gi_1028=gi_704;
      if(!IsTesting())
        {
         gi_1164=TRUE;
         //   gi_1164 = f0_1();
         if(gi_1164!=TRUE)
           {
            if(Send_Email && gi_1116==FALSE) f0_15();
            gi_1116=TRUE;
            Comment("This EA is not licensed for this account");
            return (-1);
           }
        }
      if(f0_10()==1) f0_7(gd_564,MagicNumber);
      gi_1116 = FALSE;
      gd_1120 = 0.0;
      ArrayInitialize(gda_908, 0.0);
      ArrayInitialize(gda_912, 0.0);
      ArrayInitialize(gda_916, 0.0);
      ArrayInitialize(gda_920, 0.0);
      gi_1004=FALSE;
      gi_unused_1112 = 0;
      gi_unused_1012 = 30;
     }
   if(gd_524==0.0 && gi_488<=0 && WaitPips>0 && gd_1128==0.0) gd_1128=Bid+WaitPips*Point;
   if(g_bool_772==TRUE && MonitorAndClose==FALSE && gi_488<=0 && gd_524==0.0 && (WaitPips==0 || Bid>=gd_1128))
     {
      if(gd_1148!=0.0)
        {
         Print("Max Margin Utilization Percentage vs. Equity For Last Trade Sequence = "+DoubleToStr(100.0*gd_1148,2));
         gd_1148=0.0;
        }
      f0_28();
      gi_1028=gi_708;
      if(!IsTesting())
        {
         gi_1164=TRUE;
         //  gi_1164 = f0_1();
         if(gi_1164!=TRUE)
           {
            if(Send_Email && gi_1116==FALSE) f0_15();
            gi_1116=TRUE;
            Comment("This EA is not licensed for this account");
            return (-1);
           }
        }
      if(f0_10()==1) f0_22(gd_564,MagicNumber);
      gd_1128 = 0;
      gi_1116 = FALSE;
      ArrayInitialize(gda_908, 0.0);
      ArrayInitialize(gda_912, 0.0);
      ArrayInitialize(gda_916, 0.0);
      ArrayInitialize(gda_920, 0.0);
      gi_1008=FALSE;
      gi_unused_1112 = 0;
      gi_unused_1012 = 30;
     }
   if((g_bool_772==TRUE || MonitorAndClose==TRUE) && gi_488>=0 && gd_532>0.0)
     {
      if((!gi_164 && Ask<=gd_756) || (gi_164 && Ask<=gd_756 && Ask>=gd_756-gd_168*Point))
        {
         g_count_796=f0_6(2);
         g_count_796++;
         f0_14(gd_776);
         if(g_count_792>g_count_796) g_count_796=g_count_792;
         if(MaxBuyMartingaleLevel==0 || (g_count_796<=MaxBuyMartingaleLevel && MaxBuyMartingaleLevel>0))
           {
            if(f0_10()==1) f0_7(gd_776,MagicNumber);
            if(g_count_796==2) gi_unused_1156=TRUE;
            ArrayInitialize(gda_908, 0.0);
            ArrayInitialize(gda_912, 0.0);
            ArrayInitialize(gda_916, 0.0);
            ArrayInitialize(gda_920, 0.0);
            if(g_count_796 == 4) g_count_1088++;
            if(g_count_796 == 5) g_count_1092++;
            if(g_count_796 == 6) g_count_1096++;
            if(g_count_796 == 7) g_count_1100++;
            if(g_count_796 == 8) g_count_1104++;
            if(g_count_796 == 9) g_count_1108++;
            gi_1004=FALSE;
            gi_unused_1112 = 0;
            gi_unused_1012 = 30;
           }
         if(UseMartingaleDisrupter && MaxBuyMartingaleLevel>0 && g_count_796>MaxBuyMartingaleLevel && CloseBuyBeyondMax)
           {
            Print("Close of all buy trades due to max martingale level surpassed.");
            f0_25(OP_BUY);
           }
        }
     }
   if((g_bool_772==TRUE || MonitorAndClose==TRUE) && gi_488<=0 && gd_524>0.0)
     {
      if((!gi_164 && Bid>=gd_764) || (gi_164 && Bid>=gd_764 && Bid<=gd_764+gd_168*Point))
        {
         g_count_800=f0_6(1);
         g_count_800++;
         f0_14(gd_784);
         if(g_count_792>g_count_800) g_count_800=g_count_792;
         if(MaxSellMartingaleLevel==0 || (g_count_800<=MaxSellMartingaleLevel && MaxSellMartingaleLevel>0))
           {
            if(f0_10()==1) f0_22(gd_784,MagicNumber);
            if(g_count_800==2) gi_unused_1156=TRUE;
            ArrayInitialize(gda_908, 0.0);
            ArrayInitialize(gda_912, 0.0);
            ArrayInitialize(gda_916, 0.0);
            ArrayInitialize(gda_920, 0.0);
            if(g_count_800 == 4) g_count_1088++;
            if(g_count_800 == 5) g_count_1092++;
            if(g_count_800 == 6) g_count_1096++;
            if(g_count_800 == 7) g_count_1100++;
            if(g_count_800 == 8) g_count_1104++;
            if(g_count_800 == 9) g_count_1108++;
            gi_1008=FALSE;
            gi_unused_1112 = 0;
            gi_unused_1012 = 30;
           }
         if(UseMartingaleDisrupter && MaxSellMartingaleLevel>0 && g_count_800>MaxSellMartingaleLevel && CloseSellBeyondMax)
           {
            Print("Close of all sell trades due to max martingale level surpassed.");
            f0_25(OP_SELL);
           }
        }
     }
   f0_3();
   f0_26();
   f0_21();
   if(Send_Email)
     {
      li_8=Send_Minute+15;
      if(li_8>59) li_8-=60;
      if(Minute()>li_8) gi_804=FALSE;
      if(gi_804==FALSE)
        {
         li_12=FALSE;
         if(Send_Frequency == 60 && Minute() >= Send_Minute && Minute() < li_8) li_12 = TRUE;
         if(Send_Frequency == 240 && Minute() >= Send_Minute && Minute() < li_8 && (Hour() == 0 || Hour() == 4 || Hour() == 8 || Hour() == 12 || Hour() == 16 || Hour() == 20)) li_12 = TRUE;
         if(Send_Frequency == 480 && Minute() >= Send_Minute && Minute() < li_8 && (Hour() == 0 || Hour() == 8 || Hour() == 16)) li_12 = TRUE;
         if(Send_Frequency == 720 && Minute() >= Send_Minute && Minute() < li_8 && (Hour() == 0 || Hour() == 12)) li_12 = TRUE;
         if(Send_Frequency == 1440 && Minute() >= Send_Minute && Minute() < li_8 && Hour() == 0) li_12 = TRUE;
         if(gi_804==TRUE) li_12=FALSE;
         if(li_12)
           {
            f0_18();
            gi_804=TRUE;
           }
        }
     }
   if(IsTesting())
     {
      if(Day()!=g_day_820) gi_816 =FALSE;
      if(gi_816==FALSE)
        {
         f0_23();
         Print("Min TradeRange Used = "+gi_1052);
         Print("Max TradeRange Used = "+gi_1048);
         Print("Max DrawDown Percent For Past Day = "+DoubleToStr(100.0*gd_1140,2));
         Print("Max DrawDown Percent Ever Reached is "+DoubleToStr(100.0*gd_1040,2));
         Print("Max Buy Martingale Level Reached is "+g_global_var_808);
         Print("Max Sell Martingale Level Reached is "+g_global_var_812);
         Print(gs_1080+DoubleToStr(100.0*gd_1072,2));
         Print("Current Buy TradeRange = "+gi_704);
         Print("Current Sell TradeRange = "+gi_708);
         Print("Current Buy Martingale Level is "+g_count_796);
         Print("Current Sell Martingale Level is "+g_count_800);
         if(g_count_1088>0) Print("Level 4 Counter = "+g_count_1088);
         if(g_count_1092>0) Print("Level 5 Counter = "+g_count_1092);
         if(g_count_1096>0) Print("Level 6 Counter = "+g_count_1096);
         if(g_count_1100>0) Print("Level 7 Counter = "+g_count_1100);
         if(g_count_1104>0) Print("Level 8 Counter = "+g_count_1104);
         if(g_count_1108>0) Print("Level 9 Counter = "+g_count_1108);
         Print("Working Balance is "+DoubleToStr(gd_864,2));
         Print("Funds Withdrawn is "+DoubleToStr(gd_872,2));
         gi_816=TRUE;
         g_day_820=Day();
         gd_1140=0.0;
        }
     }

   return (0);
  }

bool gi_76=TRUE;
string gs_84="PipStrider v_1.34 ";
string version2="PipStrider v_1.34 ";
string OWN="Copyright © 2010-2011, Forex-Goldmine, Inc.";
bool gi_unused_108=TRUE;
string _Comment="PipStrider ";
bool DoTrades=TRUE;
bool MonitorAndClose=FALSE;
bool StealthMode=FALSE;
bool AutoStealthMode=TRUE;
bool AllowLotsBeyondMaxSize=FALSE;
bool ModifyMartingale=TRUE;
bool gi_144= TRUE;
int gi_148 = 2;
int TradeRange=40;
bool gi_160 = TRUE;
bool gi_164 = FALSE;
double gd_168= 5.0;
int WaitPips = 0;
bool gi_180=TRUE;
int StopLoss=0;
string a1 = "----------------------------------------------";
string a2 = " Martingale Disrupter (tm) Technology";
bool UseMartingaleDisrupter=TRUE;
bool AdjustTakeProfit = FALSE;
double DisrupterClose = 0.75;
double DisrupterClose2= 0.75;
double gd_228=-10.0;
bool gi_236 = TRUE;
bool gi_240 = TRUE;
bool gi_244 = FALSE;
int OnlyAfterLevel=5;
int OnlyAfterLevel2=6;
int gi_256=0;
int MaxBuyMartingaleLevel=5; //6
int MaxSellMartingaleLevel=5; //6
bool CloseBuyBeyondMax=FALSE;
bool CloseSellBeyondMax=FALSE;
double MaxDrawDownPct=100.0; //100.0
bool LimitToThisPair = FALSE;
bool UseGridExpander = TRUE;
int ExpandPips=0;
int ExpandPips2=0;
int gi_300=100;
int gi_unused_304 = 0;
int gi_unused_308 = 0;
string a3="----------------------------------------------";
double TradeLots=CalcularVolumen();
double BalanceFactor=AccountBalance();
double ControlBalance= 0.0;
double LockInProfits = 0.0;
bool StopWhenProfitReached=FALSE;
string a4="Set to -1 to set 0 or a positive number to set actual value";
double ResetFundsWithdrawn=0.0;
double MaxLots=1000.0;
int MagicNumber = magic;
bool Send_Email = FALSE;
int Send_Frequency=0;
int Send_Minute=0;
bool SUNDAY = TRUE;
bool MONDAY = TRUE;
bool TUESDAY= TRUE;
bool WEDNESDAY= TRUE;
bool THURSDAY = TRUE;
bool FRIDAY=TRUE;
bool ResetMaximums=FALSE;
int LookBackDays=5;
double CenterPrice=0.0;
int LookBackMinimumPips=125;
double gd_440=2.0;
bool gi_448=TRUE;
int g_period_452=7;
string note1="---- Caution! For Emergency Closing of Trades ---";
bool CloseAllBuyTrades=FALSE;
bool CloseAllSellTrades=FALSE;
int gi_unused_472=40;
int gi_476 = 40;
int gi_480 = 40;
int gi_484 = 30;
int gi_488 = 0;
double gd_unused_492=20.0;
double gd_500=0.01;
bool gi_508 = FALSE;
bool gi_512 = FALSE;
string gs_unused_516=" ";
double gd_524 = 0.0;
double gd_532 = 0.0;
double g_order_open_price_540 = 0.0;
double g_order_open_price_548 = 0.0;
double gd_556 = 0.0;
double gd_564 = 0.0;
double gd_unused_572=0.0;
int gi_580=0;
int g_error_584=0/* NO_ERROR */;
double g_order_open_price_588=0.0;
double gd_unused_596=0.0;
int gi_604 = 0;
int gi_608 = 0;
string g_comment_612=" ";
int gi_620=3;
int g_color_624 = CLR_NONE;
int g_color_628 = CLR_NONE;
bool gi_632=FALSE;
double gd_unused_636 = 0.0;
double gd_unused_644 = 0.0;
string gs_unused_652 = " ";
int gi_unused_660 = 0;
int gi_unused_664 = 0;
int gi_unused_668 = 0;
double gd_unused_672=0.0;
int gi_unused_680 = 0;
int gi_unused_684 = 0;
int gi_unused_688 = 0;
double gd_unused_692=0.0;
int gi_700 = 0;
int gi_704 = 0;
int gi_708 = 0;
int gi_unused_712 = 0;
int gi_unused_716 = 0;
int gi_unused_720 = 0;
int gi_unused_724 = 0;
int gi_unused_728 = 0;
double gd_unused_732 = 98765.43;
double gd_unused_740 = 98765.43;
int gi_748=2;
int g_slippage_752=10;
double gd_756 = 0.0;
double gd_764 = 0.0;
bool g_bool_772=TRUE;
double gd_776 = 0.0;
double gd_784 = 0.0;
int g_count_792 = 0;
int g_count_796 = 0;
int g_count_800 = 0;
int gi_804=0;
int g_global_var_808 = 0;
int g_global_var_812 = 0;
int gi_816=0;
int g_day_820=0;
string g_dbl2str_824="";
double gd_832 = 0.0;
double gd_840 = 0.0;
double g_order_lots_848 = 0.0;
double g_order_lots_856 = 0.0;
double gd_864 = 0.0;
double gd_872 = 0.0;
bool gi_880=FALSE;
double gd_884 = 0.0;
double gd_892 = 0.0;
double gd_900 = 0.0;
double gda_908[3];
double gda_912[3];
double gda_916[3];
double gda_920[3];
double gd_924=0.0;
double gd_unused_932=0.0;
double gd_940 = 0.0;
double gd_948 = 0.0;
double gd_unused_956=0.0;
double gd_964=0.0;
int gi_972=0;
double gd_976 = 0.0;
double gd_984 = 0.0;
bool gi_992= FALSE;
int gi_996 = 0;
int gi_1000 = 30;
int gi_1004 = 0;
int gi_1008 = 0;
int gi_unused_1012=0;
int gi_1016=0;
double gd_1020=0.0;
int gi_1028=0;
double gd_1032 = 0.0;
double gd_1040 = 0.0;
int gi_1048 = 0;
int gi_1052 = 0;
double gd_unused_1056 = 0.0;
double gd_unused_1064 = 0.0;
double gd_1072 = 0.0;
string gs_1080 = " ";
int g_count_1088 = 0;
int g_count_1092 = 0;
int g_count_1096 = 0;
int g_count_1100 = 0;
int g_count_1104 = 0;
int g_count_1108 = 0;
int gi_unused_1112=0;
int gi_1116=0;
double gd_1120 = 0.0;
double gd_1128 = 0.0;
int gi_1136=0;
double gd_1140 = 0.0;
double gd_1148 = 0.0;
bool gi_unused_1156= FALSE;
int gi_unused_1160 = 0;
int gi_1164=0;
int g_acc_number_1168=0;
int gi_1172=7;
int gi_unused_1176 = 0;
int gi_unused_1180 = 0;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int initAV()
  {
  TradeLots=CalcularVolumen();
   gi_1164=TRUE;
   f0_20();
   gi_1116= FALSE;
   gi_700 = TradeRange;
   gi_704 = TradeRange;
   gi_708 = TradeRange;
   gd_892 = 0.0;
   gd_900 = 0.0;
   gi_unused_1012=30;
   gi_996 = FALSE;
   gi_256 = 0;
   gi_300 = 100;
   gd_228 = -10.0;
   gi_992 = StealthMode;
   gi_1052 = 10000;
   gi_1048 = 0;
   gd_unused_1056 = 0.0;
   gd_unused_1064 = 0.0;
   g_count_1088 = 0;
   g_count_1092 = 0;
   g_count_1096 = 0;
   g_count_1100 = 0;
   g_count_1104 = 0;
   g_count_1108 = 0;
   gi_unused_1112=0;
   double lotsize_0=MarketInfo(Symbol(),MODE_LOTSIZE);
   DisrupterClose/=100000/lotsize_0;
   DisrupterClose2/=100000/lotsize_0;
   gd_228/=100000/lotsize_0;
   ArrayInitialize(gda_908, 0.0);
   ArrayInitialize(gda_912, 0.0);
   ArrayInitialize(gda_916, 0.0);
   ArrayInitialize(gda_920, 0.0);
   if(StringSubstr(a1,0,1)=="3")
     {
      gi_256 = 6;
      gi_300 = 100;
      gd_228 = -10.0;
     }
   g_dbl2str_824 = DoubleToStr(MagicNumber, 0);
   g_dbl2str_824 = StringSubstr(g_dbl2str_824, 0, 2);
   if(!GlobalVariableCheck("GVMaxBuyLevel"+g_dbl2str_824+Symbol())) GlobalVariableSet("GVMaxBuyLevel"+g_dbl2str_824+Symbol(),0);
   if(!GlobalVariableCheck("GVMaxSellLevel"+g_dbl2str_824+Symbol())) GlobalVariableSet("GVMaxSellLevel"+g_dbl2str_824+Symbol(),0);
   if(!GlobalVariableCheck("GVFundsWithdrawn"+g_dbl2str_824+Symbol())) GlobalVariableSet("GVFundsWithdrawn"+g_dbl2str_824+Symbol(),0.0);
   if(!GlobalVariableCheck("GVStealthMode"+g_dbl2str_824+Symbol())) GlobalVariableSet("GVStealthMode"+g_dbl2str_824+Symbol(),StealthMode);
   f0_9();
   gd_864=AccountBalance()-gd_872;
   if(gd_864<ControlBalance) gd_864+=gd_872;
   if(ResetFundsWithdrawn>0.0)
     {
      gd_872=ResetFundsWithdrawn;
      GlobalVariableSet("GVFundsWithdrawn"+g_dbl2str_824+Symbol(),ResetFundsWithdrawn);
      ResetFundsWithdrawn=0.0;
      f0_21();
     }
   if(ResetFundsWithdrawn<0.0)
     {
      gd_872=0.0;
      GlobalVariableSet("GVFundsWithdrawn"+g_dbl2str_824+Symbol(),0.0);
      ResetFundsWithdrawn=0.0;
      f0_21();
     }
   gd_864=AccountBalance()-gd_872;
   if(gd_864<ControlBalance) gd_864+=gd_872;
   g_bool_772=DoTrades;
   if(MarketInfo(Symbol(), MODE_MINLOT) < 1.0) gi_748 = 1;
   if(MarketInfo(Symbol(), MODE_MINLOT) < 0.1) gi_748 = 2;
   if(MarketInfo(Symbol(),MODE_MINLOT) < 0.01) gi_748 = 3;
   if(MarketInfo(Symbol(),MODE_MINLOT)< 0.001) gi_748 = 4;
   if(MarketInfo(Symbol(),MODE_MINLOT)<0.0001) gi_748 = 5;
   gi_1000=30;
   f0_28();
   if(Digits==5 || Digits==3)
     {
      StopLoss=10*StopLoss;
      ExpandPips=10*ExpandPips;
      ExpandPips2=10*ExpandPips2;
      gi_300=10*gi_300;
      gi_1000=300;
      WaitPips=10*WaitPips;
      gd_168=10.0*gd_168;
      LookBackMinimumPips=10*LookBackMinimumPips;
     }
   gi_1028=gi_700;
   gi_unused_472=gi_700;
   gi_476 = gi_700;
   gi_480 = gi_700;
   gi_484 = gi_700;
   f0_30();
   f0_29();
   gd_unused_732 = 98765.43;
   gd_unused_740 = 98765.43;
   f0_4();
   f0_20();
   if(ResetMaximums)
     {
      g_global_var_812 = 0;
      g_global_var_808 = 0;
      f0_21();
     }
   if(gi_488>=0)
     {
      gd_500=gd_532*gi_148;
      if(ModifyMartingale && g_count_796==1) gd_500=gd_564;
      gd_500 = NormalizeDouble(gd_500, gi_748);
      gi_476 = gi_704;
      if(UseGridExpander && OnlyAfterLevel!=0 && g_count_796>=OnlyAfterLevel) gi_476=gi_704+ExpandPips;
      if(UseGridExpander && OnlyAfterLevel2!=0 && g_count_796>=OnlyAfterLevel2) gi_476=gi_704+ExpandPips2;
      if(UseGridExpander && gi_256!=0 && g_count_796>=gi_256) gi_476=gi_704+gi_300;
      gd_776 = gd_500;
      gd_756 = g_order_open_price_548 - gi_476 * Point;
     }
   if(gi_488<=0)
     {
      gd_500=gd_524*gi_148;
      if(ModifyMartingale && g_count_800==1) gd_500=gd_564;
      gd_500 = NormalizeDouble(gd_500, gi_748);
      gi_480 = gi_708;
      if(UseGridExpander && OnlyAfterLevel!=0 && g_count_800>=OnlyAfterLevel) gi_480=gi_708+ExpandPips;
      if(UseGridExpander && OnlyAfterLevel2!=0 && g_count_800>=OnlyAfterLevel2) gi_480=gi_708+ExpandPips2;
      if(UseGridExpander && gi_256!=0 && g_count_800>=gi_256) gi_480=gi_708+gi_300;
      gd_784 = gd_500;
      gd_764 = g_order_open_price_540 + gi_480 * Point;
     }
   if(gd_524 == 0.0) g_count_800 = 0;
   if(gd_532 == 0.0) g_count_796 = 0;
   if(g_count_800 > g_global_var_812) g_global_var_812 = g_count_800;
   if(g_count_796 > g_global_var_808) g_global_var_808 = g_count_796;
   f0_24();
   f0_21();
   if(gi_512 || StringSubstr(a1,0,1)=="m") f0_18();

   return (0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double f0_11(string a_symbol_0,int ai_8)
  {
   double ld_ret_12=0.0;
   gi_580=OrdersTotal();
   for(int pos_20=gi_580-1; pos_20>=0; pos_20--)
     {
      if(!OrderSelect(pos_20,SELECT_BY_POS,MODE_TRADES))
        {
         g_error_584=GetLastError();
         Print("OrderSelect( ",pos_20,", SELECT_BY_POS ) - Error #",g_error_584);
           } else {
         if(OrderSymbol()==a_symbol_0)
           {
            if(OrderMagicNumber()==MagicNumber)
              {
               if(ai_8 == 1 && OrderType() == OP_BUY) continue;
               if(ai_8 == 2 && OrderType() == OP_SELL) continue;
               if(OrderCloseTime()==0) ld_ret_12+=OrderLots();
              }
           }
        }
     }
   return (ld_ret_12);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double f0_31(int ai_0)
  {
   double ld_ret_4=0.0;
   bool li_12=FALSE;
   gi_580=OrdersTotal();
   for(int pos_16=0; pos_16<=gi_580-1; pos_16++)
     {
      if(!OrderSelect(pos_16,SELECT_BY_POS,MODE_TRADES))
        {
         g_error_584=GetLastError();
         Print("OrderSelect( ",pos_16,", SELECT_BY_POS ) - Error #",g_error_584);
           } else {
         if(OrderSymbol()==Symbol())
           {
            if(OrderMagicNumber()==MagicNumber)
              {
               if(ai_0 == 1 && OrderType() == OP_BUY) continue;
               if(ai_0 == 2 && OrderType() == OP_SELL) continue;
               if(OrderCloseTime()==0)
                 {
                  li_12=FALSE;
                  if(gi_236 && ai_0 == 2) li_12 = TRUE;
                  if(gi_240 && ai_0 == 1) li_12 = TRUE;
                  if(gi_244 && ai_0 == 2 && g_count_796 >= OnlyAfterLevel2 && OrderSwap() < 0.0) li_12 = FALSE;
                  if(gi_244 && ai_0 == 1 && g_count_800 >= OnlyAfterLevel2 && OrderSwap() < 0.0) li_12 = FALSE;
                  ld_ret_4+=OrderProfit();
                  if(li_12) ld_ret_4+=OrderSwap();
                 }
              }
           }
        }
     }
   return (ld_ret_4);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void f0_24()
  {
   int li_0=LookBackDays;
   double ihigh_4 = iHigh(Symbol(), PERIOD_D1, iHighest(Symbol(), PERIOD_D1, MODE_HIGH, li_0, 0));
   double ilow_12 = iLow(Symbol(), PERIOD_D1, iLowest(Symbol(), PERIOD_D1, MODE_LOW, li_0, 0));
   gd_556=(ihigh_4+ilow_12)/2.0;
   for(gd_556=NormalizeDouble(gd_556,Digits);(ihigh_4-ilow_12)/Point<LookBackMinimumPips && li_0<365; gd_556=NormalizeDouble(gd_556,Digits))
     {
      li_0++;
      ihigh_4 = iHigh(Symbol(), PERIOD_D1, iHighest(Symbol(), PERIOD_D1, MODE_HIGH, li_0, 0));
      ilow_12 = iLow(Symbol(), PERIOD_D1, iLowest(Symbol(), PERIOD_D1, MODE_LOW, li_0, 0));
      gd_556=(ihigh_4+ilow_12)/2.0;
     }
   if(CenterPrice!=0.0)
     {
      gd_556 = CenterPrice;
      gd_556 = NormalizeDouble(gd_556, Digits);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void f0_17()
  {
   string name_4;
   int objs_total_0=ObjectsTotal();
   for(int li_12=0; li_12<objs_total_0; li_12++)
     {
      name_4=ObjectName(li_12);
      if(name_4!="") ObjectDelete(name_4);
     }
   ObjectDelete("FLP_txt");
   ObjectDelete("P_txt");
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void f0_25(int a_cmd_0)
  {
   int cmd_16;
   int ticket_20;
   double order_lots_24;
   string symbol_32;
   int order_total_4=OrdersTotal();
   for(int count_8=0; count_8<5; count_8++)
     {
      for(int pos_12=0; pos_12<order_total_4; pos_12++)
        {
         while(!IsTradeAllowed())
           {
           }
         OrderSelect(pos_12,SELECT_BY_POS,MODE_TRADES);
         cmd_16=OrderType();
         ticket_20=OrderTicket();
         order_lots_24=OrderLots();
         symbol_32=OrderSymbol();
         if(symbol_32 == Symbol() && cmd_16 == OP_BUY && cmd_16 == a_cmd_0 && OrderMagicNumber() == MagicNumber) OrderClose(ticket_20, order_lots_24, MarketInfo(symbol_32, MODE_BID), 3, CLR_NONE);
         if(symbol_32 == Symbol() && cmd_16 == OP_SELL && cmd_16 == a_cmd_0 && OrderMagicNumber() == MagicNumber) OrderClose(ticket_20, order_lots_24, MarketInfo(symbol_32, MODE_ASK), 3, CLR_NONE);
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double f0_8(int ai_0)
  {
   double ld_ret_4=0.0;
   double order_open_price_12=0.0;
   gi_580=OrdersTotal();
   double ld_unused_20 = 0.0;
   double ld_unused_28 = 0.0;
   double ld_36=MathFloor(gi_704/2)*Point;
   if(ai_0==1) ld_36=MathFloor(gi_708/2)*Point;
   bool li_44 = FALSE;
   bool li_48 = FALSE;
   if(ai_0 == 1) gd_840 = 0.0;
   if(ai_0 == 2) gd_832 = 0.0;
   if(ai_0 == 1) g_order_lots_856 = 0.0;
   if(ai_0 == 2) g_order_lots_848 = 0.0;
   int li_unused_52=0;
   for(int pos_56=gi_580-1; pos_56>=0; pos_56--)
     {
      if(!OrderSelect(pos_56,SELECT_BY_POS,MODE_TRADES))
        {
         g_error_584=GetLastError();
         Print("OrderSelect( ",pos_56,", SELECT_BY_POS ) - Error #",g_error_584);
           } else {
         if(OrderSymbol()==Symbol())
           {
            if(OrderMagicNumber()==MagicNumber)
              {
               if(OrderCloseTime()==0)
                 {
                  if(ai_0 == 1 && OrderType() == OP_BUY) continue;
                  if(ai_0 == 2 && OrderType() == OP_SELL) continue;
                  if(ai_0==2 && order_open_price_12!=0.0 && (OrderOpenPrice()>order_open_price_12+ld_36 || (!AllowLotsBeyondMaxSize)))
                    {
                     if(li_48==FALSE) gd_832=OrderOpenPrice();
                     gd_832=NormalizeDouble(gd_832,Digits);
                     g_order_lots_848=OrderLots();
                     li_48=TRUE;
                     continue;
                    }
                  if(ai_0==1 && order_open_price_12!=0.0 && (OrderOpenPrice()<order_open_price_12-ld_36 || (!AllowLotsBeyondMaxSize)))
                    {
                     if(li_44==FALSE) gd_840=OrderOpenPrice();
                     gd_840=NormalizeDouble(gd_840,Digits);
                     g_order_lots_856=OrderLots();
                     li_44=TRUE;
                     continue;
                    }
                  if(MathAbs(order_open_price_12 - OrderOpenPrice())> ld_36 ||(!AllowLotsBeyondMaxSize)) ld_ret_4 = OrderLots();
                  if(MathAbs(order_open_price_12 - OrderOpenPrice()) < ld_36 && AllowLotsBeyondMaxSize) ld_ret_4 += OrderLots();
                  g_order_open_price_588=OrderOpenPrice();
                  order_open_price_12=OrderOpenPrice();
                 }
              }
           }
        }
     }
   return (ld_ret_4);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void f0_16(int ai_0,double ad_4)
  {
   double ld_unused_12=0.0;
   gi_580=OrdersTotal();
   double ld_20=0.0;
   double ld_unused_28=0.0;
   for(int pos_36=gi_580-1; pos_36>=0; pos_36--)
     {
      if(!OrderSelect(pos_36,SELECT_BY_POS,MODE_TRADES))
        {
         g_error_584=GetLastError();
         Print("OrderSelect( ",pos_36,", SELECT_BY_POS ) - Error #",g_error_584);
           } else {
         if(OrderSymbol()==Symbol())
           {
            if(OrderMagicNumber()==MagicNumber)
              {
               if(OrderCloseTime()==0)
                 {
                  if(ai_0 == 1 && OrderType() == OP_BUY) continue;
                  if(ai_0 == 2 && OrderType() == OP_SELL) continue;
                  if(ai_0 == 2 && ad_4 != 0.0) ld_20 = NormalizeDouble(ad_4, Digits);
                  if(ai_0 == 1 && ad_4 != 0.0) ld_20 = NormalizeDouble(ad_4, Digits);
                  if(gi_992==FALSE)
                     if(NormalizeDouble(OrderTakeProfit(),Digits)!=ld_20 && ld_20!=0.0) OrderModify(OrderTicket(),OrderOpenPrice(),OrderStopLoss(),NormalizeDouble(ld_20,Digits),0,CLR_NONE);
                  if(gi_992==TRUE)
                     if(OrderTakeProfit()!=0.0) OrderModify(OrderTicket(),OrderOpenPrice(),OrderStopLoss(),0.0,0,CLR_NONE);
                 }
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void f0_27(int ai_0)
  {
   double ld_unused_4=0.0;
   gi_580=OrdersTotal();
   double ld_unused_12=0.0;
   double ld_20=0.0;
   for(int pos_28=gi_580-1; pos_28>=0; pos_28--)
     {
      if(!OrderSelect(pos_28,SELECT_BY_POS,MODE_TRADES))
        {
         g_error_584=GetLastError();
         Print("OrderSelect( ",pos_28,", SELECT_BY_POS ) - Error #",g_error_584);
           } else {
         if(OrderSymbol()==Symbol())
           {
            if(OrderMagicNumber()==MagicNumber)
              {
               if(OrderCloseTime()==0)
                 {
                  if(ai_0 == 1 && OrderType() == OP_BUY) continue;
                  if(ai_0 == 2 && OrderType() == OP_SELL) continue;
                  if(ai_0 == 2 && StopLoss != 0) ld_20 = NormalizeDouble(OrderOpenPrice() - StopLoss * Point, Digits);
                  if(ai_0 == 1 && StopLoss != 0) ld_20 = NormalizeDouble(OrderOpenPrice() + StopLoss * Point, Digits);
                  if(gi_992==FALSE)
                     if(StopLoss!=0 && NormalizeDouble(OrderStopLoss(),Digits)!=ld_20 && ld_20!=0.0) OrderModify(OrderTicket(),OrderOpenPrice(),NormalizeDouble(ld_20,Digits),OrderTakeProfit(),0,CLR_NONE);
                  if(gi_992==TRUE)
                    {
                     if(OrderStopLoss()!=0.0) OrderModify(OrderTicket(),OrderOpenPrice(),0.0,OrderTakeProfit(),0,CLR_NONE);
                     if(ld_20 != 0.0 && StopLoss != 0 && ai_0 == 2 && Bid <= ld_20) OrderClose(OrderTicket(), OrderLots(), MarketInfo(Symbol(), MODE_BID), 3, CLR_NONE);
                     if(ld_20 != 0.0 && StopLoss != 0 && ai_0 == 1 && Ask >= ld_20) OrderClose(OrderTicket(), OrderLots(), MarketInfo(Symbol(), MODE_ASK), 3, CLR_NONE);
                    }
                 }
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int f0_10()
  {
   int li_4;
   int li_0=30;
   if(!IsTradeAllowed())
     {
      li_4=GetTickCount();
      Print("Trade context is busy! Wait until it is free...");
      while(true)
        {
         if(IsStopped())
           {
            Print("The expert was terminated by the user!");
            return (-1);
           }
         int e=GetTickCount()-li_4;
         if(e>1000*li_0)
           {
            Print("The waiting limit exceeded ("+li_0+" ???.)!");
            return (-2);
           }
         if(IsTradeAllowed())
           {
            Print("Trade context has become free!");
            RefreshRates();
            return (1);
           }
         Sleep(100);
        }
     }
   return (1);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int f0_7(double a_lots_0,int a_magic_8)
  {
   int slippage_44;
   int count_48;
   int ticket_52;
   double price_56;
   double ld_12 = MarketInfo(Symbol(), MODE_MAXLOT);
   double ld_20 = MarketInfo(Symbol(), MODE_MINLOT);
   double ld_28 = a_lots_0;
   double price_36=0.0;
   if(!AllowLotsBeyondMaxSize && ld_28>ld_12) ld_28=ld_12;
   price_36 = 0.0;
   price_36 = NormalizeDouble(price_36, Digits);
   while(true)
     {
      while(ld_28>0.0)
        {
         a_lots_0=ld_28;
         if(a_lots_0 > ld_12) a_lots_0 = ld_12;
         if(a_lots_0 < ld_20) a_lots_0 = ld_20;
         a_lots_0=NormalizeDouble(a_lots_0,gi_748);
         ld_28-=a_lots_0;
         slippage_44=g_slippage_752;
         count_48=0;
         ticket_52= -1;
         price_56 = 0.0;
         if(gi_144==TRUE && gi_604!=0)
           {
            price_56 = Ask + gi_604 * Point;
            price_56 = NormalizeDouble(price_56, Digits);
           }
         if(gi_144==FALSE && gi_608!=0 && gi_604!=0)
           {
            price_56 = Ask + (gi_604 + gi_608) * Point;
            price_56 = NormalizeDouble(price_56, Digits);
           }
         price_56 = 0.0;
         price_56 = NormalizeDouble(price_56, Digits);
         g_comment_612=_Comment+" "+DoubleToStr(a_magic_8,0);
         while(ticket_52==-1 && count_48<=gi_620)
           {
            ticket_52=OrderSend(Symbol(),OP_BUY,a_lots_0,Ask,slippage_44,price_36,price_56,g_comment_612,a_magic_8,0,g_color_624);
            count_48++;
            if(ticket_52>=0) break;
            if(count_48>gi_620) break;
            Sleep(1000);
           }
         if(ticket_52!=0)
           {
            g_error_584=GetLastError();
            if(gi_632==TRUE) Alert("Error OrderSend # ",g_error_584);
           }
         if(ld_28>0.0) continue;
        }
      break;
     }
   return (0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int f0_22(double a_lots_0,int a_magic_8)
  {
   int slippage_44;
   int count_48;
   int ticket_52;
   double price_56;
   double ld_12 = MarketInfo(Symbol(), MODE_MAXLOT);
   double ld_20 = MarketInfo(Symbol(), MODE_MINLOT);
   double ld_28 = a_lots_0;
   double price_36=0.0;
   if(!AllowLotsBeyondMaxSize && ld_28>ld_12) ld_28=ld_12;
   price_36 = 0.0;
   price_36 = NormalizeDouble(price_36, Digits);
   while(true)
     {
      while(ld_28>0.0)
        {
         a_lots_0=ld_28;
         if(a_lots_0 > ld_12) a_lots_0 = ld_12;
         if(a_lots_0 < ld_20) a_lots_0 = ld_20;
         a_lots_0=NormalizeDouble(a_lots_0,gi_748);
         ld_28-=a_lots_0;
         slippage_44=g_slippage_752;
         count_48=0;
         ticket_52= -1;
         price_56 = 0.0;
         if(gi_144==TRUE && gi_604!=0)
           {
            price_56 = Bid - gi_604 * Point;
            price_56 = NormalizeDouble(price_56, Digits);
           }
         if(gi_144==FALSE && gi_608!=0 && gi_604!=0)
           {
            price_56 = Bid - (gi_604 + gi_608) * Point;
            price_56 = NormalizeDouble(price_56, Digits);
           }
         price_56 = 0.0;
         price_56 = NormalizeDouble(price_56, Digits);
         g_comment_612=_Comment+" "+DoubleToStr(a_magic_8,0);
         while(ticket_52==-1 && count_48<=gi_620)
           {
            ticket_52=OrderSend(Symbol(),OP_SELL,a_lots_0,Bid,slippage_44,price_36,price_56,g_comment_612,a_magic_8,0,g_color_628);
            count_48++;
            if(ticket_52>=0) break;
            if(count_48>gi_620) break;
            Sleep(1000);
           }
         if(ticket_52!=0)
           {
            g_error_584=GetLastError();
            if(gi_632==TRUE) Alert("Error OrderSend # ",g_error_584);
           }
         if(ld_28>0.0) continue;
        }
      break;
     }
   return (0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double f0_12(int ai_0)
  {
   gi_580=OrdersHistoryTotal();
   int datetime_4=0;
   bool li_8=FALSE;
   int ticket_12=0;
   int li_unused_16=0;
   for(int pos_20=gi_580-1; pos_20>=0; pos_20--)
     {
      if(!OrderSelect(pos_20,SELECT_BY_POS,MODE_HISTORY))
        {
         g_error_584=GetLastError();
         Print("OrderSelect( ",pos_20,", SELECT_BY_POS ) - Error #",g_error_584);
           } else {
         if(OrderMagicNumber()==MagicNumber)
           {
            if(OrderSymbol()==Symbol())
              {
               if(OrderCloseTime()!=0)
                 {
                  if(ai_0 == 1 && OrderType() == OP_BUY) continue;
                  if(ai_0 == 2 && OrderType() == OP_SELL) continue;
                  if(OrderCloseTime()>datetime_4)
                    {
                     datetime_4= OrderCloseTime();
                     ticket_12 = OrderTicket();
                     li_8=TRUE;
                    }
                 }
              }
           }
        }
     }
   if(li_8==TRUE)
     {
      for(pos_20=gi_580-1; pos_20>=0; pos_20--)
        {
         if(!OrderSelect(pos_20,SELECT_BY_POS,MODE_HISTORY))
           {
            g_error_584=GetLastError();
            Print("OrderSelect( ",pos_20,", SELECT_BY_POS ) - Error #",g_error_584);
              } else {
            if(OrderSymbol()==Symbol())
               if(OrderTicket() == ticket_12) return (OrderProfit());
           }
        }
     }
   return (0.0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void f0_29()
  {
   double ld_8;
   double lotsize_0=MarketInfo(Symbol(),MODE_LOTSIZE);
   if(TradeLots!=0.0)
     {
      gd_500=TradeLots;
      if(gd_500 < MarketInfo(Symbol(), MODE_MINLOT)) gd_500 = MarketInfo(Symbol(), MODE_MINLOT);
      if(gd_500 > MarketInfo(Symbol(), MODE_MAXLOT)) gd_500 = MarketInfo(Symbol(), MODE_MAXLOT);
      gd_500 = NormalizeDouble(gd_500, gi_748);
      gd_564 = NormalizeDouble(gd_500, gi_748);
     }
   if(TradeLots==0.0)
     {
      ld_8 = BalanceFactor;
      ld_8/= 100000 / lotsize_0;
      gd_500=MathFloor(gd_864/ld_8)/100.0;
      if(gd_500>MaxLots) gd_500=MaxLots;
      if(gd_500 < MarketInfo(Symbol(), MODE_MINLOT)) gd_500 = MarketInfo(Symbol(), MODE_MINLOT);
      if(gd_500 > MarketInfo(Symbol(), MODE_MAXLOT)) gd_500 = MarketInfo(Symbol(), MODE_MAXLOT);
      gd_500 = NormalizeDouble(gd_500, gi_748);
      gd_564 = NormalizeDouble(gd_500, gi_748);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void f0_14(double ad_0)
  {
   g_count_792=0;
   if(ad_0 == gd_564) g_count_792 = 0;
   if(ad_0 == gd_564 * gi_148) g_count_792 = 1;
   if(ad_0 == gd_564 * MathPow(gi_148, 2)) g_count_792 = 2;
   if(ad_0 == gd_564 * MathPow(gi_148, 3)) g_count_792 = 3;
   if(ad_0 == gd_564 * MathPow(gi_148, 4)) g_count_792 = 4;
   if(ad_0 == gd_564 * MathPow(gi_148, 5)) g_count_792 = 5;
   if(ad_0 == gd_564 * MathPow(gi_148, 6)) g_count_792 = 6;
   if(ad_0 == gd_564 * MathPow(gi_148, 7)) g_count_792 = 7;
   if(ad_0 == gd_564 * MathPow(gi_148, 8)) g_count_792 = 8;
   if(ad_0 == gd_564 * MathPow(gi_148, 9)) g_count_792 = 9;
   if(ad_0 == gd_564 * MathPow(gi_148, 10)) g_count_792 = 10;
   if(ad_0 == gd_564 * MathPow(gi_148, 11)) g_count_792 = 11;
   if(ad_0 == gd_564 * MathPow(gi_148, 12)) g_count_792 = 12;
   if(ad_0 == gd_564 * MathPow(gi_148, 13)) g_count_792 = 13;
   if(ad_0 == gd_564 * MathPow(gi_148, 14)) g_count_792 = 14;
   if(ad_0 == gd_564 * MathPow(gi_148, 15)) g_count_792 = 15;
   if(ad_0 == gd_564 * MathPow(gi_148, 16)) g_count_792 = 16;
   if(ad_0 == gd_564 * MathPow(gi_148, 17)) g_count_792 = 17;
   g_count_792++;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double f0_6(int ai_0)
  {
   gi_580=OrdersTotal();
   int count_4 = 0;
   double ld_8 = MathFloor(gi_704 / 2) * Point;
   if(ai_0==1) ld_8=MathFloor(gi_708/2)*Point;
   double order_open_price_16=0.0;
   for(int pos_24=gi_580-1; pos_24>=0; pos_24--)
     {
      if(!OrderSelect(pos_24,SELECT_BY_POS,MODE_TRADES))
        {
         g_error_584=GetLastError();
         Print("OrderSelect( ",pos_24,", SELECT_BY_POS ) - Error #",g_error_584);
           } else {
         if(OrderSymbol()==Symbol())
           {
            if(OrderMagicNumber()==MagicNumber)
              {
               if(OrderCloseTime()==0)
                 {
                  if(ai_0 == 1 && OrderType() == OP_BUY) continue;
                  if(ai_0 == 2 && OrderType() == OP_SELL) continue;
                  if(AllowLotsBeyondMaxSize && (order_open_price_16==0.0 || MathAbs(order_open_price_16-OrderOpenPrice())>=ld_8)) count_4++;
                  if(!AllowLotsBeyondMaxSize) count_4++;
                  order_open_price_16=OrderOpenPrice();
                 }
              }
           }
        }
     }
   return (count_4);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void f0_18()
  {
   if(gi_508)
     {
      SendMail("PipStrider Report"," "+Symbol()+" account = "+DoubleToStr(AccountNumber(),0)+" BuyLevel = "+DoubleToStr(g_count_796,0)+" SellLevel = "+DoubleToStr(g_count_800,
               0)+" BuySide = "+DoubleToStr(f0_31(2),2)+" SellSide = "+DoubleToStr(f0_31(1),2));
      Sleep(5000);
      SendMail("PipStrider Report-2"," "+Symbol()+" account = "+DoubleToStr(AccountNumber(),0)+" MaxBuyLevel Reached = "+DoubleToStr(g_global_var_808,0)+" MaxSellLevel Reached = "+
               DoubleToStr(g_global_var_812,0)+" Balance = "+DoubleToStr(AccountBalance(),2)+" Equity = "+DoubleToStr(AccountEquity(),2));
     }
   if(!gi_508)
     {
      SendMail("PipStrider Rpt."," "+Symbol()+" account = "+DoubleToStr(AccountNumber(),0)+" BuyLevel = "+DoubleToStr(g_count_796,0)+", "+DoubleToStr(g_global_var_808,
               0)+" SellLevel = "+DoubleToStr(g_count_800,0)+", "+DoubleToStr(g_global_var_812,0)+" BuySide = "+DoubleToStr(f0_31(2),2)+" SellSide = "+DoubleToStr(f0_31(1),
               2)+" Balance = "+DoubleToStr(AccountBalance(),2)+" Equity = "+DoubleToStr(AccountEquity(),2));
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void f0_13()
  {
   SendMail("PipStrider Rpt."," "+Symbol()+" account = "+DoubleToStr(AccountNumber(),0)+" Your profit goal has been reached and you have money waiting to withdraw from your account. "+
            " Balance = "+DoubleToStr(AccountBalance(),2)+" Equity = "+DoubleToStr(AccountEquity(),2));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void f0_15()
  {
   SendMail("PipStrider Notice:"," "+Symbol()+" account = "+DoubleToStr(AccountNumber(),0)+" Something has happened. This account is not enabled for the PipStrider."+
            " Please restart the EA.");
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void f0_5()
  {
   if(!LimitToThisPair)
     {
      gd_1032=(AccountBalance()-AccountEquity())/AccountBalance();
      if(100.0*gd_1032>MaxDrawDownPct)
        {
         f0_25(OP_BUY);
         f0_25(OP_SELL);
         f0_29();
        }
     }
   if(LimitToThisPair)
     {
      gd_1032=(AccountBalance() -(AccountBalance()+f0_31(1)+f0_31(2)))/AccountBalance();
      if(100.0*gd_1032>MaxDrawDownPct)
        {
         f0_25(OP_BUY);
         f0_25(OP_SELL);
         f0_29();
        }
     }
   if(gd_1032 > gd_1040) gd_1040 = gd_1032;
   if(gd_1032 > gd_1140) gd_1140 = gd_1032;
   double ld_0=AccountMargin()/AccountEquity();
   if(ld_0>gd_1148) gd_1148=ld_0;
   gi_880=FALSE;
   if(DisrupterClose!=0.0 && g_count_796>=OnlyAfterLevel && g_count_796<OnlyAfterLevel2 && f0_31(2)>=DisrupterClose) gi_880=TRUE;
   if(DisrupterClose2!=0.0 && g_count_796>=OnlyAfterLevel2 && f0_31(2)>=DisrupterClose2) gi_880=TRUE;
   if(gi_880)
     {
      f0_25(OP_BUY);
      gi_880=FALSE;
     }
   gi_880=FALSE;
   if(DisrupterClose!=0.0 && g_count_800>=OnlyAfterLevel && g_count_800<OnlyAfterLevel2 && f0_31(1)>=DisrupterClose) gi_880=TRUE;
   if(DisrupterClose2!=0.0 && g_count_800>=OnlyAfterLevel2 && f0_31(1)>=DisrupterClose2) gi_880=TRUE;
   if(gi_880)
     {
      f0_25(OP_SELL);
      gi_880=FALSE;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void f0_4()
  {
   gd_532=f0_8(2);
   g_count_796=f0_6(2);
   f0_14(gd_532);
   if(g_count_792>g_count_796) g_count_796=g_count_792;
   if(gd_532==0.0) g_count_796=0;
   g_order_open_price_548=g_order_open_price_588;
   gd_524=f0_8(1);
   g_count_800=f0_6(1);
   f0_14(gd_524);
   if(g_count_792>g_count_800) g_count_800=g_count_792;
   if(gd_524==0.0) g_count_800=0;
   g_order_open_price_540=g_order_open_price_588;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void f0_3()
  {
   f0_4();
   if(gi_488>=0)
     {
      gi_unused_1156=FALSE;
      gi_476=gi_1028;
      if(UseGridExpander && OnlyAfterLevel!=0 && g_count_796>=OnlyAfterLevel) gi_476=gi_1028+ExpandPips;
      if(UseGridExpander && OnlyAfterLevel2!=0 && g_count_796>=OnlyAfterLevel2) gi_476=gi_1028+ExpandPips2;
      if(UseGridExpander && gi_256!=0 && g_count_796>=gi_256) gi_476=gi_1028+gi_300;
      gd_884 = 0.0;
      gi_484 = gi_476;
      gd_884 = g_order_open_price_548 + gi_484 * Point;
      if(gi_180 && g_count_796>1 && gd_832!=0.0) gd_884=gd_832;
      if(gd_940!=0.0 && gd_884<gd_940 && gd_940>gd_892 && MathAbs(gd_940-gd_884)<gi_1000*Point && AdjustTakeProfit) gd_884=gd_940;
      gd_884=NormalizeDouble(gd_884,Digits);
      if(g_count_796==0) gd_892=0.0;
      if(AdjustTakeProfit && g_count_796>0 && (gi_1004==FALSE || gd_892==0.0 || gd_884>gd_892)) gd_892=gd_884;
      if(!AdjustTakeProfit && g_count_796>0) gd_892=gd_884;
      if(gi_992) gd_unused_1064=0.0;
      if(g_count_796>0)
        {
         f0_16(2,gd_892);
         f0_27(2);
         gi_1004=TRUE;
        }
     }
   if(gi_488<=0)
     {
      gi_unused_1156=FALSE;
      gi_480=gi_1028;
      if(UseGridExpander && OnlyAfterLevel!=0 && g_count_800>=OnlyAfterLevel) gi_480=gi_1028+ExpandPips;
      if(UseGridExpander && OnlyAfterLevel2!=0 && g_count_800>=OnlyAfterLevel2) gi_480=gi_1028+ExpandPips2;
      if(UseGridExpander && gi_256!=0 && g_count_800>=gi_256) gi_480=gi_1028+gi_300;
      gd_884 = 0.0;
      gi_484 = gi_480;
      gd_884 = g_order_open_price_540 - gi_484 * Point;
      if(gi_180 && g_count_800>1 && gd_840!=0.0) gd_884=gd_840;
      if(gd_964!=0.0 && gd_884>gd_964 && gd_964<gd_900 && MathAbs(gd_884-gd_964)<gi_1000*Point && AdjustTakeProfit) gd_884=gd_964;
      gd_884=NormalizeDouble(gd_884,Digits);
      if(g_count_800==0) gd_900=0.0;
      if(AdjustTakeProfit && g_count_800>0 && (gi_1008==FALSE || gd_900==0.0 || gd_884<gd_900)) gd_900=gd_884;
      if(!AdjustTakeProfit && g_count_800>0) gd_900=gd_884;
      if(gi_992) gd_unused_1056=0.0;
      if(g_count_800>0)
        {
         f0_16(1,gd_900);
         f0_27(1);
         gi_1008=TRUE;
        }
     }
   if(gi_992 && gd_892!=0.0 && Bid>=gd_892)
     {
      f0_25(OP_BUY);
      gi_unused_1112=1;
      g_count_796=0;
     }
   if(gi_992 && gd_900!=0.0 && Ask<=gd_900)
     {
      f0_25(OP_SELL);
      g_count_800=0;
      gi_unused_1112=1;
     }
   if(gd_892!=0.0 && Bid>=gd_892)
     {
      f0_25(OP_BUY);
      g_count_796=0;
      gi_unused_1112=1;
     }
   if(gd_900!=0.0 && Ask<=gd_900)
     {
      f0_25(OP_SELL);
      g_count_800=0;
      gi_unused_1112=1;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void f0_19()
  {
   double ld_0;
   if(ControlBalance!=0.0 && LockInProfits!=0.0)
     {
      ld_0=AccountEquity()-gd_872;
      if(ld_0>=ControlBalance+LockInProfits)
        {
         if(AccountEquity()-ControlBalance<2.0*LockInProfits)
           {
            Print("All trades being closed due to Profit Target Reached.");
            f0_25(OP_BUY);
            f0_25(OP_SELL);
            g_count_796 = 0;
            g_count_800 = 0;
            Print("All trades were closed due to Profit Target Reached.");
            if(Send_Email) f0_13();
           }
         gd_872+=LockInProfits;
        }
     }
   gd_864=AccountBalance()-gd_872;
   if(gd_864<ControlBalance) gd_864+=gd_872;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void f0_9()
  {
   g_global_var_808 = GlobalVariableGet("GVMaxBuyLevel" + g_dbl2str_824 + Symbol());
   g_global_var_812 = GlobalVariableGet("GVMaxSellLevel" + g_dbl2str_824 + Symbol());
   gd_872=GlobalVariableGet("GVFundsWithdrawn"+g_dbl2str_824+Symbol());
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void f0_21()
  {
   GlobalVariableSet("GVMaxBuyLevel"+g_dbl2str_824+Symbol(),g_global_var_808);
   GlobalVariableSet("GVMaxSellLevel"+g_dbl2str_824+Symbol(),g_global_var_812);
   GlobalVariableSet("GVFundsWithdrawn"+g_dbl2str_824+Symbol(),gd_872);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void f0_26()
  {
   double ld_0;
   int li_8;
   int li_12;
   if(gda_908[1]==0.0 && gda_908[2]==0.0)
     {
      gda_908[1] = Bid;
      gda_916[1] = f0_31(2);
     }
   if(Bid!=gda_908[1] && gda_908[1]!=0.0)
     {
      gda_908[2] = Bid;
      gda_916[2] = f0_31(2);
     }
   gd_924=0.0;
   gd_unused_932=0.0;
   gd_940 = 0.0;
   gi_972 = FALSE;
   gd_976 = 0.0;
   gd_984 = 0.0;
   if(gda_908[2]!=0.0 && gda_908[1]!=0.0)
     {
      gd_924 = MathAbs(gda_916[2]-gda_916[1]);
      gd_924/= MathAbs(gda_908[2] / Point-gda_908[1] / Point);
     }
   gd_976=0.0;
   if(OnlyAfterLevel!=0 && g_count_796>=OnlyAfterLevel) gd_976=DisrupterClose;
   if(OnlyAfterLevel2!=0 && g_count_796>=OnlyAfterLevel2) gd_976=DisrupterClose2;
   if(gi_256!=0 && g_count_796>=gi_256) gd_976=gd_228;
   if(gd_976!=0.0 && gd_924!=0.0)
     {
      ld_0=f0_31(2);
      if(ld_0 < 0.0) gd_984 = MathAbs(gd_976 - MathAbs(ld_0));
      if(ld_0 > 0.0) gd_984 = gd_976 - ld_0;
      gi_972 = gd_984 / gd_924;
      gd_940 = Bid + gi_972 * Point;
     }
   if(gda_912[1]==0.0 && gda_912[2]==0.0)
     {
      gda_912[1] = Ask;
      gda_920[1] = f0_31(1);
     }
   if(Ask!=gda_912[1] && gda_912[1]!=0.0)
     {
      gda_912[2] = Ask;
      gda_920[2] = f0_31(1);
     }
   gd_948=0.0;
   gd_unused_956=0.0;
   gd_964 = 0.0;
   gi_972 = FALSE;
   gd_976 = 0.0;
   gd_984 = 0.0;
   if(gda_912[2]!=0.0 && gda_912[1]!=0.0)
     {
      gd_948 = MathAbs(gda_920[2]-gda_920[1]);
      gd_948/= MathAbs(gda_912[2] / Point-gda_912[1] / Point);
     }
   gd_976=0.0;
   if(OnlyAfterLevel!=0 && g_count_800>=OnlyAfterLevel) gd_976=DisrupterClose;
   if(OnlyAfterLevel2!=0 && g_count_800>=OnlyAfterLevel2) gd_976=DisrupterClose2;
   if(gi_256!=0 && g_count_800>=gi_256) gd_976=gd_228;
   if(gd_976!=0.0 && gd_948!=0.0)
     {
      ld_0=f0_31(1);
      if(ld_0 < 0.0) gd_984 = MathAbs(gd_976 - MathAbs(ld_0));
      if(ld_0 > 0.0) gd_984 = gd_976 - ld_0;
      gi_972 = gd_984 / gd_948;
      gd_964 = Ask - gi_972 * Point;
      if(gi_996==FALSE) gi_996=TRUE;
     }
   if(gd_964!=0.0)
     {
      li_8=gi_708;
      if(UseGridExpander && OnlyAfterLevel!=0 && g_count_800>=OnlyAfterLevel) li_8=gi_708+ExpandPips;
      if(UseGridExpander && OnlyAfterLevel2!=0 && g_count_800>=OnlyAfterLevel2) li_8=gi_708+ExpandPips2;
      if(UseGridExpander && gi_256!=0 && g_count_800>=gi_256) li_8=gi_708+gi_300;
      li_8+=gi_1000;
      if(MathAbs(Ask-gd_964)>li_8*Point)
        {
         ArrayInitialize(gda_912, 0.0);
         ArrayInitialize(gda_920, 0.0);
        }
     }
   if(gd_940!=0.0)
     {
      li_12=gi_704;
      if(UseGridExpander && OnlyAfterLevel!=0 && g_count_796>=OnlyAfterLevel) li_12=gi_704+ExpandPips;
      if(UseGridExpander && OnlyAfterLevel2!=0 && g_count_796>=OnlyAfterLevel2) li_12=gi_704+ExpandPips2;
      if(UseGridExpander && gi_256!=0 && g_count_796>=gi_256) li_12=gi_704+gi_300;
      li_12+=gi_1000;
      if(MathAbs(gd_940-Bid)>li_12*Point)
        {
         ArrayInitialize(gda_908, 0.0);
         ArrayInitialize(gda_916, 0.0);
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void f0_30()
  {
   if(!AutoStealthMode) gi_992=StealthMode;
   if(AutoStealthMode && DayOfWeek()==5 && Hour()>=16)
     {
      gi_992=TRUE;
      if(gi_1016==FALSE) gi_unused_1012=30;
      gi_1016=TRUE;
     }
   if(AutoStealthMode && ((DayOfWeek()==0 && Hour()>=23) || (DayOfWeek()==1 && Hour()>1) || (DayOfWeek()>1 && DayOfWeek()<5) || (DayOfWeek()==5 && Hour()<16)))
     {
      if(gi_1016==TRUE) gi_unused_1012=30;
      gi_992=FALSE;
      gi_1016=FALSE;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void f0_20()
  {
   f0_4();
   gi_488=9;
   if(gd_532>0.0 && gd_524>0.0 && (TradeDirection==2 || TradeDirection==3 || TradeDirection==4)) gi_488=0;
   if(TradeDirection==3)
     {
      if(gd_524 == 0.0 && gd_532 == 0.0 && TradeDirection == 3 && Bid <= gd_556) gi_488 = 1;
      if(gd_524 == 0.0 && gd_532 == 0.0 && TradeDirection == 3 && Bid >= gd_556) gi_488 = -1;
      if(gd_524 == 0.0 && TradeDirection == 3 && Bid <= gd_556 && gi_488 != 0) gi_488 = 1;
      if(gd_524>0.0 && TradeDirection==3 && gi_488!=0) gi_488=-1;
      if(gd_532==0.0 && TradeDirection==3 && Bid>=gd_556 && gi_488!=0) gi_488=-1;
      if(gd_532>0.0 && TradeDirection==3 && gi_488!=0) gi_488=1;
     }
   if(TradeDirection==4)
     {
      if(gd_524 == 0.0 && gd_532 == 0.0 && TradeDirection == 4 && Bid <= gd_556) gi_488 = -1;
      if(gd_524 == 0.0 && gd_532 == 0.0 && TradeDirection == 4 && Bid >= gd_556) gi_488 = 1;
      if(gd_532 == 0.0 && TradeDirection == 4 && Bid <= gd_556 && gi_488 != 0) gi_488 = -1;
      if(gd_524>0.0 && TradeDirection==4 && gi_488!=0) gi_488=-1;
      if(gd_524==0.0 && TradeDirection==4 && Bid>=gd_556 && gi_488!=0) gi_488=1;
      if(gd_532>0.0 && TradeDirection==4 && gi_488!=0) gi_488=1;
     }
   if(TradeDirection==2)
     {
      if(gd_524>0.0 && gd_532==0.0 && TradeDirection==2)
        {
         gi_488=-1;
         gi_1136=-1;
        }
      if(gd_524==0.0 && gd_532>0.0 && TradeDirection==2)
        {
         gi_488=1;
         gi_1136=1;
        }
      if(gd_524==0.0 && gd_532==0.0 && TradeDirection==2 && (gi_1136==-1 || gi_1136==0))
        {
         gi_488=1;
         gi_1136=1;
        }
      if(gd_524==0.0 && gd_532==0.0 && TradeDirection==2 && gi_1136==1 && gi_488==9)
        {
         gi_488=-1;
         gi_1136=-1;
        }
     }
   if(TradeDirection==1)
     {
      gi_488=1;
      if(gd_524>0.0 && gd_532==0.0) gi_488=-1;
      if(gd_532>0.0 && gd_524>0.0) gi_488=0;
     }
   if(TradeDirection==-1)
     {
      gi_488=-1;
      if(gd_532>0.0 && gd_524==0.0) gi_488=1;
      if(gd_532>0.0 && gd_524>0.0) gi_488=0;
     }
   if(TradeDirection==0) gi_488=0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void f0_28()
  {
   double ld_0;
   gi_700=TradeRange;
   if(TradeRange>0 && (Digits==5 || Digits==3)) gi_700=10*TradeRange;
   gd_1020=iATR(Symbol(),PERIOD_D1,g_period_452,0);
   gd_1020 *= MathPow(10,Digits);
   if(gi_700== 0) gi_700 = MathFloor(gd_1020/gd_440);
   gi_704 = gi_700;
   gi_708 = gi_700;
   if(ExpandPips==0 && ExpandPips2==0)
     {
      if(f0_8(1)>0.0 && ExpandPips==0 && ExpandPips2==0)
        {
         if(gd_840>0.0)
           {
            ld_0=MathAbs(g_order_open_price_588-gd_840)/Point;
            if(gi_160 && gi_700<ld_0) gi_700=ld_0;
            gi_708=gi_700;
           }
        }
      if(f0_8(2)>0.0 && ExpandPips==0 && ExpandPips2==0)
        {
         if(gd_832>0.0)
           {
            ld_0=MathAbs(gd_832-g_order_open_price_588)/Point;
            if(gi_160 && gi_700<ld_0) gi_700=ld_0;
            gi_704=gi_700;
           }
        }
     }
   if(gi_700 < gi_1052) gi_1052 = gi_700;
   if(gi_704 < gi_1052) gi_1052 = gi_704;
   if(gi_708 < gi_1052) gi_1052 = gi_708;
   if(gi_700 > gi_1048) gi_1048 = gi_700;
   if(gi_704 > gi_1048) gi_1048 = gi_704;
   if(gi_708 > gi_1048) gi_1048 = gi_708;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void f0_23()
  {
   if(!LimitToThisPair) gd_1072=(AccountBalance()-AccountEquity())/AccountBalance();
   if(LimitToThisPair) gd_1072 =(AccountBalance() -(AccountBalance()+f0_31(1)+f0_31(2)))/AccountBalance();
   if(gd_1072>=0.0) gs_1080="Current Equity DrawDown Percent = ";
   if(gd_1072 > gd_1040) gd_1040 = gd_1072;
   if(gd_1072 > gd_1140) gd_1140 = gd_1072;
   double ld_0=AccountMargin()/AccountEquity();
   if(ld_0>gd_1148) gd_1148=ld_0;
   if(gd_1072<0.0)
     {
      gs_1080 = "Current Equity Profit Percent = ";
      gd_1072 = -1.0 * gd_1072;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void f0_0()
  {
   if(!LimitToThisPair)
     {
      gd_1032=(AccountBalance()-AccountEquity())/AccountBalance();
      if(100.0*gd_1032>MaxDrawDownPct)
        {
         f0_25(OP_BUY);
         f0_25(OP_SELL);
         f0_29();
        }
     }
   if(LimitToThisPair)
     {
      gd_1032=(AccountBalance() -(AccountBalance()+f0_31(1)+f0_31(2)))/AccountBalance();
      if(100.0*gd_1032>MaxDrawDownPct)
        {
         f0_25(OP_BUY);
         f0_25(OP_SELL);
         f0_29();
        }
     }
   if(gd_1032 > gd_1040) gd_1040 = gd_1032;
   if(gd_1032 > gd_1140) gd_1140 = gd_1032;
   double ld_0=AccountMargin()/AccountEquity();
   if(ld_0>gd_1148) gd_1148=ld_0;
  }
//+------------------------------------------------------------------+
