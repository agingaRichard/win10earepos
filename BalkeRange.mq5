//+------------------------------------------------------------------+
//|                                                   BalkeRange.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

//---https://www.youtube.com/watch?v=OU5x8sUWumI

#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>
#include <Trade/OrderInfo.mqh>
#include <myFunctions.mqh>

//Inputs
input int riskPercentage = 2;
input int StopLoss = 15;
input int TakeProfit = 100;
input int EA_Magic = 23942;

//Holders
double PriceHighs[];
double PriceLows[];
double sessionbuystop, sessionsellstop;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
  
   CTrade trade;
   COrderInfo order;
   
//Dynamic lot size
   double valueAccount = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = valueAccount * riskPercentage/100;
   double myLot = (riskAmount / StopLoss) /10; //---For pairs ending in USD.
   double Lot = NormalizeDouble(myLot, 2);
   
  
//--- Do we have enough bars to work with
   if(Bars(_Symbol, _Period) < 60)  // if total bars is less than 60 bars
     {Alert("We have less than 60 bars, EA will now exit!!");
      return;}
// We will use the static Old_Time variable to serve the bar time.
// At each OnTick execution we will check the current bar time with the saved one.
// If the bar time isn't equal to the saved time, it indicates that we have a new tick.

   static datetime Old_Time;
   datetime New_Time[1];
   bool IsNewBar = false;

// copying the last bar time to the element New_Time[0]
   int copied = CopyTime(_Symbol, _Period, 0, 1, New_Time);
   if(copied > 0)  // ok, the data has been copied successfully
     {if(Old_Time != New_Time[0])  // if old time isn't equal to new bar time
        {IsNewBar = true; // if it isn't a first call, the new bar has appeared
         if(MQL5InfoInteger(MQL5_DEBUGGING))
          //  Print("We have new bar here ", New_Time[0], " old time was ", Old_Time);
         Old_Time = New_Time[0]; // saving bar time
        }}
   else
     {Alert("Error in copying historical times data, error =", GetLastError());
      ResetLastError();
      return;}

//--- EA should only check for new trade if we have a new bar
   if(IsNewBar == false)
     {return;}

//--- Do we have enough bars to work with
   int Mybars = Bars(_Symbol, _Period);
   if(Mybars < 60)  // if total bars is less than 60 bars
     {
      Alert("We have less than 60 bars, EA will now exit!!");
      return;
     }

//--- Define some MQL5 Structures we will use for our trade
   MqlTick latest_price;     // To be used for getting recent/latest price quotes
   MqlTradeRequest mrequest; // To be used for sending our trade requests
   MqlTradeResult mresult;   // To be used to get our trade results
   MqlRates mrate[];         // To be used to store the prices, volumes and spread of each bar
   ZeroMemory(mrequest);     // Initialization of mrequest structure

   /*Let's make sure our arrays values for the Rates and MA values
        is stored serially similar to the timeseries array*/
        
// the rates arrays
   ArraySetAsSeries(mrate, true);
// the ma, fract arrays
   //ArraySetAsSeries(fractUp, true);
   //ArraySetAsSeries(fractDn, true);
   //ArraySetAsSeries(mavals, true);
// rsi   
   //ArraySetAsSeries(rsiVal, true);


//--- Get the last price quote using the MQL5 MqlTick Structure
   if(!SymbolInfoTick(_Symbol, latest_price))
     {Alert("Error getting the latest price quote - error:", GetLastError(), "!!");
      return;}

//--- Get the details of the latest 3 bars
   if(CopyRates(_Symbol, PERIOD_M5, 0, 18, mrate) < 0)
     {Alert("Error copying rates/history data - error:", GetLastError(), "!!");
      ResetLastError();
      return;}

   
//--- Entry prices...
   double bidPrice = NormalizeDouble(latest_price.bid, _Digits);
   double askPrice = NormalizeDouble(latest_price.ask, _Digits);
   
   
//-- Sls and Tps
   double sellsl = NormalizeDouble(bidPrice + StopLoss * _Point, _Digits);
   double buysl = NormalizeDouble(askPrice - StopLoss * _Point, _Digits);
   double selltp = NormalizeDouble(bidPrice - TakeProfit * _Point, _Digits);
   double buytp = NormalizeDouble(askPrice + TakeProfit * _Point, _Digits);


//---Order checks...
   bool Buy_opened = false;  // variable to hold the result of Buy opened position
   bool Sell_opened= false; // variables to hold the result of Sell opened position
   // Check if we have a selected instrument and an open trade...
   if(PositionSelect(_Symbol) == true)
     {if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){Buy_opened = true;} // It is a Buy
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){Sell_opened = true;}} // It is a Sell   


//--- Setting time boundaries   
   MqlDateTime now;
   TimeCurrent(now);
   
   MqlDateTime expiry;
   expiry.hour = 19;
   expiry.min  = 55;
   datetime expirytime = StructToTime(expiry);
   
   
   if(now.hour == 3 && now.min == 30)
     {for(int i=0; i<ArraySize(mrate); i++)
       {PriceHighs.Push(mrate[i].high);
        PriceLows.Push(mrate[i].low);}
        
         ArraySort(PriceHighs); //Lowest to highest
         ArraySort(PriceLows);

         sessionbuystop = NormalizeDouble(PriceHighs[ArraySize(PriceHighs)-1], _Digits);//Highest price in the range
         sessionsellstop = NormalizeDouble(PriceLows[0], _Digits);//Lowest...
         
         if(!trade.BuyStop(Lot, sessionbuystop, NULL, sessionsellstop, 0, ORDER_TIME_SPECIFIED, expirytime, "Buy Stop."))
           {Alert("Error placing buy stop: ", GetLastError(), "!!");
            ResetLastError();}
         if(!trade.SellStop(Lot, sessionsellstop, NULL, sessionbuystop, 0, ORDER_TIME_SPECIFIED, expirytime, "Sell stop."))
           {Alert("Error placing sell stop: ", GetLastError(), "!!");
            ResetLastError();}
   
         
   SetBuyStop(sessionbuystop, Lot);
   SetSellStop(sessionsellstop, Lot);
        }
   /*if(!Buy_opened){
   if(latest_price.last >= sessionbuystop){SimpleBuy(askPrice, StopLoss, NULL, Lot, EA_Magic, "Hard buy.");}}
   if(!Sell_opened){
   if(latest_price.last <= sessionsellstop){SimpleSell(bidPrice, StopLoss, NULL, Lot, EA_Magic, "Hard sell.");}}
     */
       
           
   if(now.hour == 19 && now.min == 55){
   for(int i=OrdersTotal()-1; i==0; i--)          // loop all orders available
         if(order.SelectByIndex(i))             // select an order
           {trade.OrderDelete(order.Ticket());  // delete it --Period
            trade.PositionClose(order.Ticket(), -1);
            }}
return;
  }
//+------------------------------------------------------------------+
