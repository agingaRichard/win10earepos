//--- EA trades in the opposite direction from a wick.
//--- There is a trailing stop. When the trailing stop is activated, the opposite trade is executed.
//--- It is also intended to do so at key levels.


//+------------------------------------------------------------------+
//|                                                   FakeoutsEA.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//#include "Functions/myFunctions.mq5"
#include <myFunctions.mqh>
#include <Trade\Trade.mqh>

//Ctrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
input int StopLoss   =  30;
input int TakeProfit =  100;
input int riskPercentage = 2; //percent

ENUM_APPLIED_PRICE applied_price  =  PRICE_CLOSE;
int EA_Magic = 132492;

double mavals[];
double bbupper[];
double bblower[];
double Lot;
int mahandle;
int bbhandle;
int STP;
int TKP;

bool Buy_Condition_1; // Bullish fakeout
bool Buy_Condition_2; // Subsequent bullish candlestick

bool Sell_Condition_1; // Beariah fakeout
bool Sell_Condition_2; // Subsequent bearish candlestick

bool SellTrailActivated;
bool BuyTrailActivated;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   mahandle = iMA(NULL, 0, 21, 0, MODE_SMA, applied_price);
   bbhandle = iBands(NULL, PERIOD_CURRENT, 20, 0, 2000, applied_price);
//---

   if(mahandle < 0 || bbhandle < 0)
     {
      Alert("Indicators failed to compile!");
      return(-1);
     }

//--- Let us handle currency pairs with 5 or 3 digit prices instead of 4
   STP = StopLoss;
   TKP = TakeProfit;
   if(_Digits == 5 || _Digits == 3)
     {
      STP = STP * 10;
      TKP = TKP * 10;
     }

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   IndicatorRelease(mahandle);
   IndicatorRelease(bbhandle);
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
        {
         IsNewBar = true; // if it isn't a first call, the new bar has appeared
         if(MQL5InfoInteger(MQL5_DEBUGGING))
            Print("We have new bar here ", New_Time[0], " old time was ", Old_Time);
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

   ArraySetAsSeries(mrate, true);
   ArraySetAsSeries(mavals, true);
   ArraySetAsSeries(bbupper, true);
   ArraySetAsSeries(bblower, true);

//--- Get the last price quote using the MQL5 MqlTick Structure
   if(!SymbolInfoTick(_Symbol,latest_price))
     {
      Alert("Error getting the latest price quote - error:",GetLastError(),"!!");
      return;
     }

//--- Get the details of the latest 5 bars
   if(CopyRates(_Symbol, _Period, 0, 5, mrate) < 0)
     {
      Alert("Error copying rates/history data - error:", GetLastError(), "!!");
      ResetLastError();
      return;
     }

//--- hold ma values
   if(CopyBuffer(mahandle, 0, 0, 3, mavals) < 0)
     {Alert("Error copying MA indicator Buffer... ", GetLastError(), "!!");}

//--- hold bb vals
   if(CopyBuffer(bbhandle, 1, 0, 2, bbupper) < 0)
     {Alert("Error populating upper bb line array");}

   if(CopyBuffer(bbhandle, 2, 0, 2, bblower) < 0)
     {Alert("Error populating lower bb line array");}


   double bidPrice = NormalizeDouble(latest_price.bid, _Digits);
   double askPrice = NormalizeDouble(latest_price.ask, _Digits);


//--- Check if we have long wicks on the 3rd last bar
   if(CheckLongWick(mrate[2].open, mrate[2].close, mrate[2].high, mrate[2].low, mavals[2]) == "Buy_Condition_1 = true")
     {
      Comment("First conditions satisfied.");
      Buy_Condition_1 = true;
     }
   else
      if(CheckLongWick(mrate[2].open, mrate[2].close, mrate[2].high, mrate[2].low, mavals[2]) == "Sell_Condition_1 = true")
        {
         Comment("First conditions satisfied.");
         Sell_Condition_1 = true;
        }


//--- Check if we have a confirming candlestick
   if(CheckBearorBullCandlestick(mrate[1].open, mrate[1].high, mrate[1].low, mrate[1].close) == "Buy_Condition_2 = true")
     {
      Comment("Second conditions satisfied. Trades will be executed.");
      Buy_Condition_2 = true;
     }
   else
      if(CheckBearorBullCandlestick(mrate[1].open, mrate[1].high, mrate[1].low, mrate[1].close) == "Sell_Condition_2 = true")
        {
         Comment("Second conditions satisfied. Trades will be executed.");
         Sell_Condition_2 = true;
        }

//---Order checks...
   bool Buy_opened = false;  // variable to hold the result of Buy opened position
   bool Sell_opened= false; // variables to hold the result of Sell opened position

//---Check if we have a selected instrument and an open trade...
   if(PositionSelect(_Symbol) == true)
     {
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
         Buy_opened = true; // It is a Buy
        }

      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
        {
         Sell_opened = true; // It is a Sell
        }
     }


//--- Enter trades on the current wick if conditions are met.
   if(!Buy_opened){if(Buy_Condition_1 == true && Buy_Condition_2 == true)
     {
      SimpleBuy(askPrice, STP, TKP, Lot, EA_Magic);
      Buy_opened=true;
     }}

   if(!Sell_opened){if(Sell_Condition_1 == true && Sell_Condition_2 == true)
     {
      SimpleSell(bidPrice, STP, TKP, Lot, EA_Magic);
      Sell_opened = true;
     }}


//TrailingStops
   if(Buy_opened || Sell_opened)
     {
      AdvancedTrailingStop(askPrice, STP, Lot, EA_Magic);//Track the trade and trail it.
     }


   if(SellTrailActivated)
     {
     SimpleBuy(askPrice, STP, TKP, Lot, EA_Magic);
      //Check if the sell trailing stop has been hit.
      //If so, we can enter a buy trade.
     }
   else
      if(BuyTrailActivated)
        {
        SimpleSell(bidPrice, STP, TKP, Lot, EA_Magic);
         //Check if the buy trailing stop has been hit.
         //if so, sell.
        }
   return;
  }
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
//---trail the trade

  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
