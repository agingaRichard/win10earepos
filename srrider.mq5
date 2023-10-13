//+------------------------------------------------------------------+
//|                                            ICT Silver Bullet.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+


/*
        When the sr lines are tested, we hedge.
*/
#include <Trade/Trade.mqh>
#include <Trade/OrderInfo.mqh>
#include <Trade/PositionInfo.mqh>
#include <myFunctions.mqh>


//---
input int TakeProfit = 50;
input int StopLoss = 15;
input int riskPercentage = 2;
// Other parameters eg null values for eahandlers

int EA_Magic = 340105;
//---
//int rsi, bb, ma;

double upperfvg, lowerfvg;
double bullsideliquidity, bearsideliquidity;    //store the liquidity levels of the previous session
double highsarr[], lowsarr[];                   //store the candlestick highs and lows
bool bearliqtaken, bullliqtaken;


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
     
   static datetime Old_Time;
   datetime New_Time[1];
   bool IsNewBar = false;

// copying the last bar time to the element New_Time[0]
   int copied = CopyTime(_Symbol, _Period, 0, 1, New_Time);
   if(copied > 0)  // ok, the data has been copied successfully
     {if(Old_Time != New_Time[0])  // if old time isn't equal to new bar time
        {IsNewBar = true; // if it isn't a first call, the new bar has appeared
         Old_Time = New_Time[0];}} // saving bar time
      else {Alert("Error in copying historical times data, error =", GetLastError());
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
   MqlRates htf[];           // For storing m15 candlesticks
   ZeroMemory(mrequest);     // Initialization of mrequest structure
//---


   /*Let's make sure our arrays values for the Rates and MA values
        is stored serially similar to the timeseries array*/
       
// the rates arrays
   ArraySetAsSeries(mrate, true);
   ArraySetAsSeries(htf, true);
// rsi  
   //ArraySetAsSeries(rsiVal, true);


//--- Get the last price quote using the MQL5 MqlTick Structure
   if(!SymbolInfoTick(_Symbol, latest_price))
     {Alert("Error getting the latest price quote - error:", GetLastError(), "!!");
      return;}

//--- Get the details of the latest 3 bars
   if(CopyRates(_Symbol, _Period, 0, 59, mrate) < 0)
     {Alert("Error copying rates/history data - error:", GetLastError(), "!!");
      ResetLastError();
      return;}
      
   if(CopyRates(_Symbol, PERIOD_M15, 0, 30, htf) < 0)
     {Alert("Error copying rates/history data - error:", GetLastError(), "!!");
      ResetLastError();
      return;}
   
   //Generic entry prices
   double bidPrice = NormalizeDouble(latest_price.bid, _Digits);
   double askPrice = NormalizeDouble(latest_price.ask, _Digits);

   //Stoplosses and tps
   double sellsl = NormalizeDouble(bidPrice + StopLoss * _Point, _Digits);
   double buysl = NormalizeDouble(askPrice - StopLoss * _Point, _Digits);
   double selltp = NormalizeDouble(bidPrice - TakeProfit * _Point, _Digits);
   double buytp = NormalizeDouble(askPrice + TakeProfit * _Point, _Digits);

//--- Do we have positions opened already?
   bool Buy_opened = false;                                       // variable to hold the result of Buy opened position
   bool Sell_opened = false;        
   
   
   if(PositionSelect(_Symbol) == true)
     {if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){Buy_opened = true;}
      else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){Sell_opened = true;}}
   
   
      //define liquidity levels

      for(int i=1; i<29; i++)//We will be using the last 1hrs of price data until we figure out how to simulate liq using m5 and m15
           {highsarr.Push(htf[i].high);
            lowsarr.Push(htf[i].low);}
            
      
      //Sort arrays in ascending order
      ArraySort(highsarr);
      ArraySort(lowsarr);
     
      //Get highest and lowest values
      bearsideliquidity = lowsarr[0];
      bullsideliquidity = highsarr[ArraySize(highsarr)-1];
      
      
      
      
      
      
      
      
      //Check for liquidity sweep
         if(mrate[0].high > bullsideliquidity)
           {bullliqtaken = true;}
         if(mrate[0].low < bearsideliquidity)
           {bearliqtaken = true;}
       
       
      //liquidity sweep
         for(int i=1; i<29; i++)//We will be using the last 1hrs of price data until we figure out how to simulate liq using m5 and m15
           {highsarr.Push(htf[i].high);
            lowsarr.Push(htf[i].low);}
            
      
      //Sort arrays in ascending order
      ArraySort(highsarr);
      ArraySort(lowsarr);
     
      //Get highest and lowest values
      bearsideliquidity = lowsarr[0];
      bullsideliquidity = highsarr[ArraySize(highsarr)-1];
   
     
      //Entry conditions
      if(mrate[0].high>bullsideliquidity)//bullish liq taken out
         {bullliqtaken = true;}
      if(mrate[0].low<bearsideliquidity)//bearish liq taken out
         {bearliqtaken = true;}
      
      
      if(bullliqtaken || bearliqtaken)
        {Alert("Liq is gone!");}

        
      //Trades
      if(bullliqtaken)
       {if(!Sell_opened)
         {trade.SellStop(Lot, bullsideliquidity, NULL, sellsl, selltp, ORDER_TIME_GTC, "Liquidity sell stop.");
          Alert("ICT Selling.");}}
         
      else if(bearliqtaken)
       {if(!Buy_opened)
         {trade.BuyStop(Lot, bearsideliquidity, NULL, buysl, buytp, ORDER_TIME_GTC, "Liquidity buy stop.");
          Alert("ICT Buying.");}}
         
      else
       {Comment("Please ensure that you are on m1. \n Searching...");}
        
     
 //..TRAIL and HEDGE
    if(Buy_opened || Sell_opened)
        {Alert("====================There's a trade underway. Atempting to modify position with trailing stop and hedging.");
         AdvancedTrailingStop(askPrice, bidPrice, StopLoss, Lot, EA_Magic);
         HedgeLosingPositions(askPrice, bidPrice, StopLoss, TakeProfit, Lot, EA_Magic);
         } 
   
   
     return;
  }
