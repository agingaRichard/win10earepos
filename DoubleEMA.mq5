//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+

//---                   Wednesday, 14th June 2023
/*

**Make a ma or ema trailing bot
-Define a mechanism to confirm that we are in a trending, not sideways, market.(If the rsi is between 40 to 60, it is a sideways market.)
1. Define the ma(ema or sma)
2. Trade in the direction of the trend(the side on which the price is)
3. Introduce a trailing stop and a compounding mechanism
4. Find an exiting strategy.

The 200 EMA Confluence Trading Strategy You’ve Been Waiting For
...The Secret Mindset
Use Nick Shawn’s [break and bounce or just bounce] strategy combined with the 200 ema channel 
to make s.r zones stronger. The channel is composed of 2 200 emas: one based on high and the 
other based on low prices.
*example displayed on M30 chart


*editing to use open and close prices.
*/

//+------------------------------------------------------------------+
//|                                            MA Trend Follower.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <myFunctions.mqh>

// Inputs
input int StopLoss = 30;     // Stop Loss
input int TakeProfit = 100;  // Take Profit
input int EMA_Period = 200;     // Exponential Moving Average Period
input int rsiMA_Period = 14; // Rsi MA Period
input int EA_Magic = 15985;  // EA Magic Number
input int riskPercentage=2;

double Lot;
int rsihandle;
int upperemahandle, loweremahandle;

int STP, TKP;
double rsiVal[];
double upperemaVal[];
double loweremaVal[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
  
//--- Get the handle for Moving Average indicator
   upperemahandle = iMA(_Symbol, _Period, EMA_Period, 0, MODE_EMA, PRICE_HIGH);
   loweremahandle = iMA(_Symbol, _Period, EMA_Period, 0, MODE_EMA, PRICE_LOW);
//--- Get the handle for the RSI
   rsihandle = iRSI(_Symbol, _Period, rsiMA_Period, PRICE_CLOSE);

//--- Indicators error handling
   if(upperemahandle < 0 || loweremahandle < 0 || rsihandle < 0/* || adxHandle < 0*/)
     {
      Alert("Error Creating Handles for indicators - error: ", GetLastError(), "!!");
      return (-1);
     }
   else{Comment("No errors in initiating indicator handles.");}

//--- Let us handle currency pairs with 5 or 3 digit prices instead of 4
   STP = StopLoss;
   TKP = TakeProfit;
   if(_Digits == 5 || _Digits == 3)
     {
      STP = STP * 10;
      TKP = TKP * 10;
     }
   //return (0);
//---
   return (INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   IndicatorRelease(upperemahandle);
   IndicatorRelease(loweremahandle);
   IndicatorRelease(rsihandle);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
  
//Dynamic lot size
   double valueAccount = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = valueAccount * riskPercentage/100;
   double myLot = (riskAmount / StopLoss) / 10; //---For pairs ending in USD.
   Lot = NormalizeDouble(myLot, 2);
   
  
//--- Do we have enough bars to work with
   if(Bars(_Symbol, _Period) < 60)  // if total bars is less than 60 bars
     {
      Alert("We have less than 60 bars, EA will now exit!!");
      return;
     }

// We will use the static Old_Time variable to serve the bar time.
// At each OnTick execution we will check the current bar time with the saved one.
// If the bar time isn't equal to the saved time, it indicates that we have a new tick.

   static datetime Old_Time;
   datetime New_Time[1];
   bool IsNewBar = false;

// copying the last bar time to the element New_Time[0]
   int copied = CopyTime(_Symbol, _Period, 0, 1, New_Time);
   if(copied > 0)  // ok, the data has been copied successfully
     {
      if(Old_Time != New_Time[0])  // if old time isn't equal to new bar time
        {IsNewBar = true; // if it isn't a first call, the new bar has appeared
         if(MQL5InfoInteger(MQL5_DEBUGGING))
          //  Print("We have new bar here ", New_Time[0], " old time was ", Old_Time);
         Old_Time = New_Time[0]; // saving bar time
        }
     }
   else
     {
      Alert("Error in copying historical times data, error =", GetLastError());
      ResetLastError();
      return;
     }

//--- EA should only check for new trade if we have a new bar
   if(IsNewBar == false)
     {
      return;
     }

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
// the ma arrays
   ArraySetAsSeries(upperemaVal, true);
   ArraySetAsSeries(loweremaVal, true);
// rsi   
   ArraySetAsSeries(rsiVal, true);

//--- Get the last price quote using the MQL5 MqlTick Structure
   if(!SymbolInfoTick(_Symbol, latest_price))
     {Alert("Error getting the latest price quote - error:", GetLastError(), "!!");
      return;}

//--- Get the details of the latest 3 bars
   if(CopyRates(_Symbol, _Period, 0, 3, mrate) < 0)
     {Alert("Error copying rates/history data - error:", GetLastError(), "!!");
      ResetLastError();
      return;}

   if(CopyBuffer(upperemahandle, 0, 0, 3, upperemaVal) < 0)
     {Alert("Error copying slow MA buffer - error: ", GetLastError());
      ResetLastError();
      return;}
     
   if(CopyBuffer(loweremahandle, 0, 0, 3, loweremaVal) < 0)
     {Alert("Error copying fast MA buffer - error: ", GetLastError());
      ResetLastError();
      return;}
// RSI
   if(CopyBuffer(rsihandle, 0, 0, 3, rsiVal)<0)
     {Alert("RSI array failed to populate.");
     return;}
     
     //--- we have no errors, so continue
     
   double bidPrice = NormalizeDouble(latest_price.bid, _Digits);
   double askPrice = NormalizeDouble(latest_price.ask, _Digits);

//--- Do we have positions opened already?
   bool Buy_opened = false;                                       // variable to hold the result of Buy opened position
   bool Sell_opened = false;                                      // variables to hold the result of Sell opened position

   if(PositionSelect(_Symbol) == true)
     {if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){Buy_opened = true;}
      else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){Sell_opened = true;}}

//--- Declare bool type variables to hold our Buy Conditions
   bool Buy_Condition_1 = false;                                  // Price crossing above sma
   bool Buy_Condition_2 = (!(rsiVal[0]>30 && rsiVal[0]<70));      // Ensure we are not in a sideways market.. RSI must be outside the 40-60 range ... it works.
   bool Buy_Condition_3 = !Buy_opened;                          //ensure we do not have open buy positions

//--- Declare bool type variables to hold our Sell Conditions
   bool Sell_Condition_1 = false;                                 // Price crossing below sma
   bool Sell_Condition_2 = (!(rsiVal[0]>30 && rsiVal[0]<70));     // Ensure we are not in a sideways market.. RSI must be outside the 40-60 range ... it works.
   bool Sell_Condition_3 = !Sell_opened;                        // Confirm that we are not stagnant


// If RSI enters the forbidden zone, exit all trades.


   if((upperemaVal[1]>mrate[1].high && loweremaVal[1]<mrate[1].high) || (upperemaVal[1]>mrate[1].low && loweremaVal[1]<mrate[1].low))//we are inside the channel
    {if(mrate[0].close>upperemaVal[0]){Buy_Condition_1 = true;}       //we break out above
      else if(mrate[0].close<loweremaVal[0]){Sell_Condition_1 = true;} //"below
      }


   //--- Putting all together
   if(Buy_Condition_1 && Buy_Condition_2 && Buy_Condition_3){SimpleBuy(askPrice, StopLoss, TakeProfit, Lot, EA_Magic, "Going long.");}
   
   //--- Check for a sell setup
   if(Sell_Condition_1 && Sell_Condition_2 && Sell_Condition_3){SimpleSell(bidPrice, StopLoss, TakeProfit, Lot, EA_Magic, "Shorting.");}
    
   //..TRAIL
   if(Buy_opened || Sell_opened){AdvancedTrailingStop(askPrice, StopLoss, Lot, EA_Magic);}
   
   //..HEDGE
   HedgeLosingPositions(bidPrice, askPrice, StopLoss, TakeProfit, Lot, EA_Magic);
      
      return;
  }
//+------------------------------------------------------------------+
