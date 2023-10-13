//+------------------------------------------------------------------+
//|                                                 FractalCHoCH.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

//---This ea uses fractals to draw lows and highs before implementing 
//---trend following and CHoCH logic.

#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>
#include <Trade/OrderInfo.mqh>
#include <Trade/PositionInfo.mqh>
#include <myFunctions.mqh>

//Inputs
input int riskPercentage = 2;
input int StopLoss = 15;
input int TakeProfit = 100;
input int EA_Magic = 46546;

//Holders

//Buffers


bool Sellstopplaced, Buystopplaced;
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
  {CTrade trade;
   COrderInfo order;
   CPositionInfo position;
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
   int copied = CopyTime(_Symbol, PERIOD_H1, 0, 1, New_Time);
   if(copied > 0)  // ok, the data has been copied successfully
     {if(Old_Time != New_Time[0])  // if old time isn't equal to new bar time
        {IsNewBar = true; // if it isn't a first call, the new bar has appeared
         Old_Time = New_Time[0];}} // saving bar time
      else
        {Alert("Error in copying historical times data, error =", GetLastError());
         ResetLastError();
         return;}


//--- EA should only check for new trade if we have a new bar
   if(IsNewBar == false){return;}


//--- Do we have enough bars to work with
   int Mybars = Bars(_Symbol, _Period);
   if(Mybars < 60)  // if total bars is less than 60 bars
     {Alert("We have less than 60 bars, EA will now exit!!");
      return;}


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


//--- Get the last price quote using the MQL5 MqlTick Structure
   if(!SymbolInfoTick(_Symbol, latest_price))
     {Alert("Error getting the latest price quote - error:", GetLastError(), "!!");
      return;}


//--- Get the details of the latest 3 bars
   if(CopyRates(_Symbol, _Period, 0, 3, mrate) < 0)
     {Alert("Error copying rates/history data - error:", GetLastError(), "!!");
      ResetLastError();
      return;}


//--- Entry prices
   double bidPrice = NormalizeDouble(latest_price.bid, _Digits);
   double askPrice = NormalizeDouble(latest_price.ask, _Digits);
   
   
//--- Sls and TPs
   double sellsl = NormalizeDouble(bidPrice + StopLoss * _Point, _Digits);
   double buysl = NormalizeDouble(askPrice - StopLoss * _Point, _Digits);
   double selltp = NormalizeDouble(bidPrice - TakeProfit * _Point, _Digits);
   double buytp = NormalizeDouble(askPrice + TakeProfit * _Point, _Digits);

//--- Do we have positions opened already?
   bool Buy_opened = false;                                       // variable to hold the result of Buy opened position
   bool Sell_opened = false;        
   
   if(PositionSelect(_Symbol) == true)
     {if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE){Buy_opened = true;}
      else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){Sell_opened = true;}}
   
   /*for(int i=0;i<ArraySize(fractUp);i++)
     {Alert("UpperFract ", i+1, ": ", NormalizeDouble(fractUp[i], 5));
      Alert("LowerFract ", i+1, ": ", NormalizeDouble(fractDn[i], 5));}*/

   
//---Check for trend continuation or CHoCH and enter accordingly.
   if(Buystopplaced == false)//Uptrend
     {Alert("Placing Buy...");
       //trade.BuyStop(volume, price , symbol,                sl         ,           tp  ,     time,   expiry,   comment)
      trade.BuyStop(Lot, mrate[0].high, NULL, mrate[0].low, NULL, ORDER_TIME_GTC, 0, "Buystop.");
      Buystopplaced = true;}
    
    
   if(Sellstopplaced == false)//Downtrend
     {Alert("Placing Sell...");
       //trade.SellStop(volume, price , symbol,                sl                  , tp  ,     time     ,expiry, comment)
         trade.SellStop(Lot, mrate[0].low, NULL, mrate[0].high, NULL, ORDER_TIME_GTC, 0, "Sellstop.");
         Sellstopplaced = true;}
    
    
//--- After we cross the buy level, we set the buystopplaced opened velue to false again.
   if(latest_price.last>mrate[0].high)
    {//The buy stop has been executed.
     Buystopplaced = false;}
    if(latest_price.last<mrate[0].low)
    {//The sell stop has been executed.
     Sellstopplaced = false;}
    
//--- TRAIL
    if(Buy_opened || Sell_opened){AdvancedTrailingStop(askPrice, bidPrice, StopLoss, Lot, EA_Magic);}
    
//--- HEDGE
    //if(Buy_opened || Sell_opened){HedgeLosingPositions(askPrice, bidPrice, StopLoss, TakeProfit, Lot, EA_Magic);}
     return;
  }
//+------------------------------------------------------------------+