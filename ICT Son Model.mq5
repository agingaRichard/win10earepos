//+------------------------------------------------------------------+
//|                                                      ICT Son.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

//1.  M15/M5 Sweep of Liquidity
//2.  Draw on Liquidity?
//3.  1min/30sec 
//4.  Displacement/Extreem FVG entry
//5.  Target opposing liquidity
//*   Avoid red folder news
#include <Trade/Trade.mqh>
#include <Trade/OrderInfo.mqh>
#include <Trade/PositionInfo.mqh>
#include <myFunctions.mqh>


//---
input int TakeProfit = 50;
input int StopLoss = 15;
input int riskPercentage = 2;
// Other parameters eg null values for eahandlers

int EA_Magic = 340005;
//---
int rsi, bb, ma;

//ICT variables
double upperfvg, lowerfvg;
double bullsideliquidity, bearsideliquidity;    //store the liquidity levels of the previous session
double highsarr[], lowsarr[];                   //store the candlestick highs and lows
bool ascendingfvg, descendingfvg;
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

//--- Only check for new trade if we have a new bar
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
   if(CopyRates(_Symbol, _Period, 0, 5, mrate) < 0)
     {Alert("Error copying rates/history data - error:", GetLastError(), "!!");
      ResetLastError();
      return;}
      
   if(CopyRates(_Symbol, PERIOD_M15, 0, 12, htf) < 0)
     {Alert("Error copying rates/history data - error:", GetLastError(), "!!");
      ResetLastError();
      return;}

//-- Entry prices     
   double bidPrice = NormalizeDouble(latest_price.bid, _Digits);
   double askPrice = NormalizeDouble(latest_price.ask, _Digits);

//-- Stoplosses and tps
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
   
   

      //FVG
         if(mrate[0].low>mrate[2].high && ascendingfvg == false)//ascending fvg
           {upperfvg = mrate[0].low;
            lowerfvg = mrate[2].high;
            ascendingfvg = true;}
         if(mrate[0].high<mrate[2].low && descendingfvg == false)//descending fvg
           {upperfvg = mrate[2].low;
            lowerfvg = mrate[0].high;
            descendingfvg = true;}
       
      //liquidity sweep
         for(int i=1; i<ArraySize(htf); i++)//We will be using the last 1hrs of price data until we figure out how to simulate liq using m5 and m15
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
         {bullliqtaken = true;
          Comment("Bull gone!");}
      if(mrate[0].low<bearsideliquidity)//bearish liq taken out
         {bearliqtaken = true;
          Comment("Bear gone!!");}
      
      
      if(bullliqtaken || bearliqtaken)
        {Comment("Liq is gone!");}
        
      if(ascendingfvg || descendingfvg)
        {Comment("Bullside: ", bullsideliquidity, "\nBearside: ", bearsideliquidity);}

        
      //Trades
      if(bullliqtaken && descendingfvg)
       {if(latest_price.last > lowerfvg && latest_price.last < upperfvg)
        {if(!Sell_opened)
         {descendingfvg = false;
          bullliqtaken = false; //reset liquidity check and fvg
          trade.Sell(Lot, NULL, bidPrice, sellsl, bearsideliquidity, "ICT Son sell.");
          Alert("ICT Selling.");
          }}}
         
      else if(bearliqtaken && ascendingfvg)
       {if(latest_price.last > lowerfvg && latest_price.last < upperfvg)
        {if(!Buy_opened)
         {ascendingfvg = false;
          bearliqtaken = false; //reset liquidity check and fvg
          trade.Buy(Lot, NULL, askPrice, buysl, bullsideliquidity, "ICT Son buy.");
          Alert("ICT Buying.");}}}
         
      else
       {Comment("Please ensure that you are on m1. \n Searching...");}
        
     
 //..TRAIL and HEDGE
    if(Buy_opened || Sell_opened)
        {Alert("====================There's a trade underway. Atempting to modify position with trailing stop and hedging.");
         //AdvancedTrailingStop(askPrice, bidPrice, StopLoss, Lot, EA_Magic);
         HedgeLosingPositions(askPrice, bidPrice, StopLoss, TakeProfit, Lot, EA_Magic);
         } 
   
   
     return;
  }
//+------------------------------------------------------------------+