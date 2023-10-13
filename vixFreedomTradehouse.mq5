/*
               6. How I Trade VIX 75 with Sniper Entry on M5 Timeframe | 4600 - 6000 pips in  6 hours (PRICE ACTION)
   STEP 1. Observe the D1 and get the current market direction. You can draw wicks. Draw TLs and key levels.
   STEP 2. Go to M5 and observe the behavior at a key level. If it forms lower highs, it's a bearish breakout, and vice versa.
   STEP 3. Enter at a key level. Set your sl beyond the previous candlestick and tp at the nearest key level.
   *Confirmation: Spot a divergence on a MACD with 12, 26, and 9. If the dotted red line is beyond the histogram while near the 0 line, enter.
   *Further confirmation: Go to M1 and find a pin bar or an engulfing candlestick.
   *Move your sl into profit zones regularly.
                                                               8
*/


/*
         How the support and resistance lines are plotted:
 1. Get the ohlc values for D1
 2. Generate an array for the highs
 3. Do the same for lows
 4. Sort both arrays from lowest to highest using ArraySort()
 5. Plot a line that joins the two highest values on the highs array
 6. Plot a line that joins the two lowest values on tne lows array.
 7. Extend these two points to the current date and check if they are not
*/


/*
                  Divergence logic:
1. Check the last two highs and lows of a macd signal line.
2. Find the highs or lows of price at these times.
3. Compare the highs to each other and do the same for lows. This should give you divergence.
*/
//+------------------------------------------------------------------+
//|                                       VIX Freedom Tradehouse.mq5 |
//|                        Copyright 2010, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+

#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link "http://www.mql5.com"
#property version "1.00"

//#include <Trade\Trade.mqh>

//Ctrade trade;
//--- input parameters

input int StopLoss = 30;
input int TakeProfit = 100;                           // Take Profit. Move to key level.
input int EA_Magic = 1323445;                         // EA Magic Number                                    // Lots to Trade
input ENUM_APPLIED_PRICE applied_price = PRICE_CLOSE; // type of price
input int riskPercentage = 2;                    // Risk percentage

//--- Account parameters
/*double valueAccount = fmin( fmin(
                       AccountInfoDouble( ACCOUNT_EQUITY      )  ,
                       AccountInfoDouble( ACCOUNT_BALANCE     ) ),
                       AccountInfoDouble( ACCOUNT_MARGIN_FREE ) );*/

double Lot;

//--- Other parameters
int mACDHandle;                                                // handle for our MACD indicator
int mAHandle;                                                  // handle for sma
int MACD_Params[3] = {12, 26, 9};                              // MACD Params: fast, slow and signal periods.
double mACDLine[], mAVals[], mACDSignalLine[], histogram[];    // Dynamic array to hold the values of MACD and MA for each bar (buffers).
double STP, TKP;                                                  // To be used for Stop Loss & Take Profit values
bool daily_bearish = false;                                    // store daily bias
bool daily_bullish = false;                                    // ''
MqlRates D1Buffer[];                                           // store values for top down analysis.

double quoteshighsArray[];                                     //store values to calculate  macd divergence
double quoteslowsArray[];                                      //''
double macdhighsArray[];                                       //''
double macdlowsArray[];                                        //''
bool priceHH;                                      //Is price forming hh?
bool priceLL;                                      //''ll?
bool macdHH;                                       //Is macd forming hh?
bool macdLL;                                        //''

bool bullishdivergence;                            //Confirmation
bool bearishdivergence;                            //''

bool m1bullpin;                                    //Confirmation
bool m1bearpin;                                    //''
bool m1bullengulfing;                              //''
bool m1bearengulfing;                              //''

bool bullpriceactionatkeylevel;                    //strategy
bool bearpriceactionatkeylevel;                    //''



//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {

//--- Get handle for MACD, MA indicators

   mACDHandle = iMACD(NULL, 0, MACD_Params[0], MACD_Params[1], MACD_Params[2], applied_price);
   mAHandle = iMA(NULL, 0, 21, 0, MODE_SMA, applied_price);

//--- What if handle returns Invalid Handle
   if(mACDHandle < 0 || mAHandle < 0)
     {
      Alert("Error Creating Handles for indicators - error: ", GetLastError(), "!!");
      return (-1);
     }


//--- Let us handle currency pairs with 5 or 3 digit prices instead of 4
   STP = StopLoss;
   TKP = TakeProfit;
   if(_Digits == 5 || _Digits == 3)
     {
      STP = STP * 10;
      TKP = TKP * 10;
     }


   return (0);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {

//--- Release our indicator handles
   IndicatorRelease(mACDHandle);
   IndicatorRelease(mAHandle);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {

//Dynamic lot size
   double valueAccount = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = valueAccount * riskPercentage/100;
   Lot = (riskAmount / StopLoss) / 10; //---For pairs ending in USD.

//--- Do we have enough bars to work with
   if(Bars(_Symbol, _Period) < 60)  // if total bars is less than 60 bars
     {Alert("We have less than 60 bars, EA will now exit!!");
      return;}

   datetime timeRightNow = TimeCurrent();


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
           // Print("We have new bar here ", New_Time[0], " old time was ", Old_Time);
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
   MqlRates m1rates[];       // Used to store m1 prices
   ZeroMemory(mrequest);     // Initialization of mrequest structure

   /*-------------------------------------------------------------------------------------+
    |    Let's make sure our arrays values for the Rates, MACD Values and MA values       |
    |    are stored serially similar to the timeseries array                              |
    +-------------------------------------------------------------------------------------*/

// the rates arrays
   ArraySetAsSeries(mrate, true);
// the MACD values array
   ArraySetAsSeries(mACDLine, true);
// the MACD signal line
   ArraySetAsSeries(mACDSignalLine, true);
// the ADX DI-values array
   ArraySetAsSeries(mAVals,true);
//m1 prices array
   //ArraySetAsSeries(m1rates, true);


//--- Get the last price quote using the MQL5 MqlTick Structure
   if(!SymbolInfoTick(_Symbol, latest_price))
     {
      Alert("Error getting the latest price quote - error:", GetLastError(), "!!");
      return;
     }

//--- Get the details of the latest 76 bars
   if(CopyRates(_Symbol, _Period, 0, 76, mrate) < 0)
     {
      Alert("Error copying rates/history data - error:", GetLastError(), "!!");
      ResetLastError();
      return;
     }

   /*if(CopyRates(_Symbol, _Period, 0, 3, m1rates) < 0)
     {
      Alert("Could not get M1 quotes for price action.", GetLastError(), "!!");
      ResetLastError();
      return;
     }*/
//--- Copy the new values of our indicators to buffers (arrays) using the handle
//CopyBuffer(int indicator_handle, int indicator_buffer_no, int start_pos, int amount_to_copy, int target_array)
   if(CopyBuffer(mACDHandle, 0, 0, 60, mACDLine) < 0) //<--main line
     {
      Alert("Error copying MACD indicator Buffer.. ", GetLastError(), "!!");
      ResetLastError();
      return;
     }

   if(CopyBuffer(mACDHandle, 1, 0, 60, mACDSignalLine) < 0) //<--signal line
     {
      Alert("Error copying MACD signalline Buffer.. ", GetLastError(), "!!");
      ResetLastError();
      return;
     }

   if(CopyBuffer(mAHandle, 0, 0, 3, mAVals) < 0)
     {
      Alert("Error copying MA indicator Buffer... ", GetLastError(), "!!");
     }


//-----------------------------------------------------------------------------------------------+
//                                                                                               |
//          Top-down analysis: Plotting support and resistance lines on the D1 timeframe.        |
//                                                                                               |
//-----------------------------------------------------------------------------------------------+
/*
//Copying D1 bars to buffer...
   CopyRates(_Symbol, PERIOD_D1, 0, 75, D1Buffer);
   double lowsBuffer[];
   double highsBuffer[];
// Storing D1 lows and highs in buffers...
   for(int i=0; i<ArraySize(D1Buffer); i++)
     {
      lowsBuffer.Push(D1Buffer[i].low);
      highsBuffer.Push(D1Buffer[i].high);
     }


//Sort from lowest to highest values order
   ArraySort(lowsBuffer);
   ArraySort(highsBuffer);

//Plotting the s/r lines
//First we get the times at which the key prices occurred.
//ArraySort(D1Buffer);
   datetime highTimesBuffer[];
   for(int l=0; l<ArraySize(D1Buffer); l++)
     {
      if(D1Buffer[l].high == highsBuffer[74])
        {
         highTimesBuffer.Push(D1Buffer[l].time);
        }
      if(D1Buffer[l].high == highsBuffer[73])
        {
         highTimesBuffer.Push(D1Buffer[l].time);
        }
      if(D1Buffer[l].high == highsBuffer[72])
        {
         highTimesBuffer.Push(D1Buffer[l].time);
        }
     }

//Do the same for low times.
   datetime lowTimesBuffer[];
   for(int m=0; m<ArraySize(D1Buffer); m++)
     {
      if(D1Buffer[m].low == lowsBuffer[0])
        {
         lowTimesBuffer.Push(D1Buffer[m].time);
        }
      if(D1Buffer[m].low == lowsBuffer[1])
        {
         lowTimesBuffer.Push(D1Buffer[m].time);
        }
      if(D1Buffer[m].low == lowsBuffer[2])
        {
         lowTimesBuffer.Push(D1Buffer[m].time);
        }
     }
   ObjectCreate(0, "D1 support", OBJ_TREND, 0, lowTimesBuffer[0], lowsBuffer[0], lowTimesBuffer[1], lowsBuffer[1]);
   ObjectSetInteger(0, "D1 support", OBJPROP_RAY_RIGHT, 1); // Make the line infinite

   ObjectCreate(0, "D1 resistance", OBJ_TREND, 0, highTimesBuffer[0], highsBuffer[74], highTimesBuffer[1], highsBuffer[73]);
   ObjectSetInteger(0, "D1 resistance", OBJPROP_RAY_RIGHT, 1);  //Make the line infinite

   /*Forming different use cases for horizontal vs diagonal trendlines. Edit these values for different pip-size currencies
   //Using the time values we got from the above for loops to plot points. Double check this logic.
      if(lowsBuffer[1]-lowsBuffer[0]<0.0001)//<--Plot horizontal trendlines
        {
         //Using the time values we got from the above for loops to plot points. Double check this logic.
         ObjectCreate(0, "D1 horizontal support", OBJ_TREND, 0, lowTimesBuffer[0], lowsBuffer[0], lowTimesBuffer[1], lowsBuffer[1]);
         ObjectSetInteger(0, "D1 horizontal support", OBJPROP_RAY_RIGHT, 1); // Make the line infinite

         //Look for a diagonal trendline before going on.
         ObjectCreate(0, "D1 diagonal support", OBJ_TREND, 0, lowTimesBuffer[0], lowsBuffer[0], lowTimesBuffer[2], lowsBuffer[2]); //<--be sure to fix this faulty code...
         //---...Logical reason for the error above: It plots faulty lines on the h4 or m15 because it assumes days end at midnight.
         ObjectSetInteger(0, "D1 diagonal support", OBJPROP_RAY_RIGHT, 1); // Make the line infinite
        }
      else
         if(lowsBuffer[1]-lowsBuffer[0]>=0.0001)
           {
            //Then plot the diagonal one
            ObjectCreate(0, "D1 diagonal support", OBJ_TREND, 0, lowTimesBuffer[0], lowsBuffer[0], lowTimesBuffer[1], lowsBuffer[1]);
            ObjectSetInteger(0, "D1 diagonal support", OBJPROP_RAY_RIGHT, 1); // Make the line infinite
           }


   //Now for resistance
      if(highsBuffer[74]-highsBuffer[73]<0.0001)
        {
         //Repeat for resistance.
         ObjectCreate(0, "D1 horizontal resistance", OBJ_TREND, 0, highTimesBuffer[0], highsBuffer[74], highTimesBuffer[1], highsBuffer[73]);  //<-- this is logically sound.
         ObjectSetInteger(0, "D1 horizontal resistance", OBJPROP_RAY_RIGHT, 1);  //Make the line infinite

         //Look for a diagonal one before going on.
         ObjectCreate(0, "D1 diagonal resistance", OBJ_TREND, 0, highTimesBuffer[0], highsBuffer[74], highTimesBuffer[2], highsBuffer[72]);  //<-- this is logically sound.
         ObjectSetInteger(0, "D1 diagonal resistance", OBJPROP_RAY_RIGHT, 1); // Make the line infinite
        }
      else
         if(highsBuffer[74]-highsBuffer[73]>=0.0001)
           {
            //Then plot the diagonal line
            ObjectCreate(0, "D1 diagonal resistance", OBJ_TREND, 0, highTimesBuffer[0], highsBuffer[74], highTimesBuffer[1], highsBuffer[73]);  //<-- this is logically sound.
            ObjectSetInteger(0, "D1 diagonal resistance", OBJPROP_RAY_RIGHT, 1); // Make the line infinite
           }

   
  
//Check if we are touching the trendlines
//Get the current prices that the trendlines are at
   double supportPrice= ObjectGetValueByTime(0, "D1 support", timeRightNow);
   double resistancePrice= ObjectGetValueByTime(0, "D1 resistance", timeRightNow);

//Check if our candlestick encloses the prices
   if(mrate[1].low<supportPrice && mrate[1].high>supportPrice)
     {
      Alert("We are at support!");
      if(mrate[2].high>mrate[3].high)//higher highs
        {
         daily_bullish = true;
         Comment("Bullish price action at key level.");
        }
      else
         if(mrate[2].low<mrate[3].low)//lower lows
           {
            daily_bearish = true;
            Comment("Bearish price action at key level.");
           }
     }
   else
      if(mrate[1].low<resistancePrice && mrate[1].high>resistancePrice)
        {
         Alert("We are at resistance!");
         if(mrate[2].high>mrate[3].high)//higher highs
           {
            bullpriceactionatkeylevel = true;
            Comment("Bullish price action at key level.");
           }
         else
            if(mrate[2].low<mrate[3].low)//lower lows
              {
               bearpriceactionatkeylevel = true;
               Comment("Bearish price action at key level.");
              }
        }
     //---end of D1 topdown analysis         
     */
   
   //Plotting m5 trendlines...
   double m5lowsBuffer[];
   double m5highsBuffer[];
   // Storing m5 lows and highs in buffers...
   for(int t=1; t<=75; t++)
     {
      m5lowsBuffer.Push(mrate[t].low);
      m5highsBuffer.Push(mrate[t].high);
     }
     ArraySort(m5lowsBuffer);
     ArraySort(m5highsBuffer);


//Plotting the m5 s/r lines
//First we get the times at which the key prices occurred.
   datetime m5highTimesBuffer[];
   for(int u=1; u<=75/*or ArraySize(mrate)*/; u++)
     {
      if(mrate[u].high == m5highsBuffer[74])
        {
         m5highTimesBuffer.Push(mrate[u].time);
        }
      if(mrate[u].high == m5highsBuffer[73])
        {
         m5highTimesBuffer.Push(mrate[u].time);
        }
      if(mrate[u].high == m5highsBuffer[72])
        {
         m5highTimesBuffer.Push(mrate[u].time);
        }
     }

//Do the same for m5 low times.
   datetime m5lowTimesBuffer[];
   for(int v=1; v<=75; v++)
     {

      if(mrate[v].low == m5lowsBuffer[0])
        {
         m5lowTimesBuffer.Push(mrate[v].time);
        }
      if(mrate[v].low == m5lowsBuffer[1])
        {
         m5lowTimesBuffer.Push(mrate[v].time);
        }
      if(mrate[v].low == m5lowsBuffer[2])
        {
         m5lowTimesBuffer.Push(mrate[v].time);
        }
     }
     
   ObjectCreate(0, "m5 support", OBJ_TREND, 0, m5lowTimesBuffer[0], m5lowsBuffer[0], m5lowTimesBuffer[1], m5lowsBuffer[1]);
   ObjectSetInteger(0, "m5 support", OBJPROP_RAY_LEFT, 1); // Make the line infinite
   ObjectSetInteger(0, "m5 support", OBJPROP_COLOR, clrAliceBlue); // Make the m5 line blue
   
   ObjectCreate(0, "m5 resistance", OBJ_TREND, 0, m5highTimesBuffer[0], m5highsBuffer[74], m5highTimesBuffer[1], m5highsBuffer[73]);
   ObjectSetInteger(0, "m5 resistance", OBJPROP_RAY_LEFT, 1);  //Make the line infinite
   ObjectSetInteger(0, "m5 resistance", OBJPROP_COLOR, clrAliceBlue); // Make the m5 line blue


//Check if we are touching the trendlines
//Get the current prices that the trendlines are at
   double m5supportPrice= ObjectGetValueByTime(0, "m5 support", timeRightNow);
   double m5resistancePrice= ObjectGetValueByTime(0, "m5 resistance", timeRightNow);
   

//Check if our candlestick encloses the prices
   if(mrate[1].low<m5supportPrice && mrate[1].high>m5supportPrice)
     {Alert("We are at an m5 key level(support)!");
      if(mrate[2].high>mrate[3].high)//higher highs
        {bullpriceactionatkeylevel = true;
         Comment("Bullish price action at key level.");}
      else
         if(mrate[2].low<mrate[3].low)//lower lows
           {bearpriceactionatkeylevel = true;
            Comment("Bearish price action at key level.");}}
   else
      if(mrate[1].low<m5resistancePrice && mrate[1].high>m5resistancePrice)
        {Alert("We are at an m5 key level(resistance)!");
         bullpriceactionatkeylevel = true;
         if(mrate[2].high>mrate[3].high)//higher highs
           {bullpriceactionatkeylevel = true;
            Comment("Bullish price action at key level.");}
         else
            if(mrate[2].low<mrate[3].low)//lower lows
              {bearpriceactionatkeylevel = true;
               Comment("Bearish price action at key level.");}}


//Set histogram values
   for(int i=0; i<ArraySize(mACDLine); i++)
     {//Histogram= macd line -signal line
      histogram.Push(mACDLine[i] - mACDSignalLine[i]);}
//Check for the histogram confirmation
   for(int p=0; p<1; p++)
     {if(histogram[p]<mACDSignalLine[p])
        {Comment("Histogram confirmation intact.");
         //Buy_Condition_1=true;
         }
     }

//Checking for bearish/bullish pinbar or engulfing
//Creating a temporary buffer for price
/*   for(int i=1; i<2; i++)
     {
      if(m1rates[i].open-m1rates[i].close <= (m1rates[i].high-m1rates[i].open)*3)
        {
         Comment("Bearish pinbar!!!");
         m1bearpin = true;
        }
      else
         if(m1rates[i].close-m1rates[i].open <= (m1rates[i].open-m1rates[i].low)*3)
           {
            Comment("Bullish pinbar!!!");
            m1bullpin = true;
           }
     }

   if(m1rates[2].open <= m1rates[1].close && m1rates[2].close >= m1rates[1].open)
     {
      Comment("Bullish engulfing!!!");
      m1bullengulfing = true;
     }
   else
      if(m1rates[2].close <= m1rates[1].open && m1rates[2].open >= m1rates[1].close)
        {
         Comment("Bearish engulfing!!!");
         m1bearengulfing = true;
        }*/
//--- End of check for engulfing


//-----------------------------------------------------------------------------+
//                                                                             |
//                     Define macd divergence function                         |
//                                                                             |
//-----------------------------------------------------------------------------+
//double divergenceTracker(MqlRates mrate[])
//{
   for(int q=1; q<50; q++)//Lookback for divergence
     {
      if(mrate[q-1].high<mrate[q].high && mrate[q+1].high<mrate[q].high)//...then we are at a high
        {
         quoteshighsArray.Push(mrate[q].high);//Populate highs array
        }
      if(mrate[q-1].low>mrate[q].low && mrate[q+1].low>mrate[q].low)//...then we are at a low
        {
         quoteslowsArray.Push(mrate[q].low);//Populate lows array
        }
     }

   if(quoteshighsArray[0]>quoteshighsArray[1])
     {
      Comment("Higher highs formed. Check macd for divergence.");
      priceHH=true;
     }
   else
      if(quoteslowsArray[0]<quoteslowsArray[1])
        {
         Comment("Lower lows formed. Check macd for divergence.");
         priceLL=true;
        }

   for(int r=1; r<50; r++)
     {
      if(mACDLine[r-1]<mACDLine[r] && mACDLine[r+1]<mACDLine[r])//Then we are at a macd high
        {
         macdhighsArray.Push(mACDLine[r]);
        }
      else
         if(mACDLine[r-1]>mACDLine[r] && mACDLine[r+1]>mACDLine[r])
           {
            macdlowsArray.Push(mACDLine[r]);
           }
     }
   if(macdhighsArray[0]>macdhighsArray[1])
     {
      Comment("Macd hh formed.");
      macdHH=true;
     }
   else
      if(macdlowsArray[0]<macdlowsArray[1])
        {
         Comment("Macd ll formed.");
         macdLL=true;
        }

   if(priceHH && macdLL)
     {
      bearishdivergence=true;
     }
   if(priceLL && macdHH)
     {
      bullishdivergence=true;
     }
//return;
//}
//}


//divergenceTracker(mrate);
//---          end of macd divergence tracker            ---//

   double currentAsk = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   double currentBid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   double newBuyStopLoss = NormalizeDouble(currentBid - StopLoss * _Point, _Digits);
   double newSellStopLoss= NormalizeDouble(currentAsk + StopLoss * _Point, _Digits);
   
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

   /*
       1. Check for a long/Buy Setup : MA-8 increasing upwards,
       previous price close above it, ADX > 22, +DI > -DI
   */
//--- Declare bool type variables to hold our Buy Conditions
   bool Buy_Condition_1 = (bullpriceactionatkeylevel);                    // bullish price action(higher lows) at trend line
   bool Buy_Condition_2 = (bullishdivergence);        // bullish divergenece
   bool Buy_Condition_3 = (!Buy_opened);   // m1 bullish pin bar or engulfing, changed to check for open buy pos.
   bool Buy_Condition_4 = (m1bullengulfing);                  // macd signal line beyond histogram
//--- Putting all together
   if(Buy_Condition_1)
     {
      Alert("Buy conditions 1 AND 2 satisfied.");
      if(Buy_Condition_2 && Buy_Condition_3 && daily_bullish)
        {
         Comment("Buy confirmations intact.");
         Lot *= 2;
        }
      // any opened Buy position?
      if(Buy_opened)
        {
         Alert("We already have a Buy Position!!!");
         return; // Don't open a new Buy Position
        }
      ZeroMemory(mrequest);
      mrequest.action = TRADE_ACTION_DEAL;                                     // immediate order execution
      mrequest.price = NormalizeDouble(latest_price.ask, _Digits);             // latest ask price
      mrequest.sl = NormalizeDouble(latest_price.ask - STP * _Point, _Digits); // Stop Loss                                                     // Trailing stop
      mrequest.tp = NormalizeDouble(latest_price.ask + TKP * _Point, _Digits); // Take Profit
      mrequest.symbol = _Symbol;                                               // currency pair
      mrequest.volume = Lot;                                                   // number of lots to trade
      mrequest.magic = EA_Magic;                                               // Order Magic Number
      mrequest.type = ORDER_TYPE_BUY;                                          // Buy Order
      mrequest.type_filling = ORDER_FILLING_FOK;                               // Order execution type
      mrequest.deviation = 100;                                                // Deviation from current price


      //--- send order
      if(OrderSend(mrequest, mresult) == 0)
        {
         Alert("Failed to place buy order.");
        }

      // get the result code
      if(mresult.retcode == 10009 || mresult.retcode == 10008)  // Request is completed or order placed
        {
         Alert("A Buy order has been successfully placed with Ticket#:", mresult.order, "!!");
        }
      else
        {
         Alert("The Buy order request could not be completed -error:", GetLastError());
         ResetLastError();
         return;
        }

     }
     //Trailing stop...
     if(Buy_opened && newBuyStopLoss>mrequest.sl)
       {
        Alert("New buy sl: ", newBuyStopLoss);
        mrequest.sl = newBuyStopLoss;
       }
     
   /*
       2. Check for a Short/Sell Setup : MA-8 decreasing downwards,
       previous price close below it, ADX > 22, -DI > +DI
   */
//--- Declare bool type variables to hold our Sell Conditions
   bool Sell_Condition_1 = (bearpriceactionatkeylevel);              // bearish price action (lower highs) at trend line
   bool Sell_Condition_2 = (bearishdivergence);                      // bearish divergence
   bool Sell_Condition_3 = (!Sell_opened);                              // m1 bearish pin bar, changed to check for open sell pos.
   bool Sell_Condition_4 = (m1bearengulfing);                        // macd signal line slightly beyond histogram

//--- Putting all together
   if(Sell_Condition_1)
     {
      Alert("Sell conditions 1 AND 2 satisfied.");
      if(Sell_Condition_2 && Sell_Condition_3 && daily_bearish)
        {
         Comment("Sell confirmations intact.");
         Lot *= 2;
        }
      // any opened Sell position?
      if(Sell_opened)
        {
         Alert("We already have a Sell position!!!");
         return; // Don't open a new Sell Position
        }
      ZeroMemory(mrequest);
      mrequest.action = TRADE_ACTION_DEAL;                                     // immediate order execution
      mrequest.price = NormalizeDouble(latest_price.bid, _Digits);             // latest Bid price
      mrequest.sl = NormalizeDouble(latest_price.bid + STP * _Point, _Digits); // Stop Loss
      //mrequest.sl = mAVals[0];
      mrequest.tp = NormalizeDouble(latest_price.bid - TKP * _Point, _Digits); // Take Profit
      mrequest.symbol = _Symbol;                                               // currency pair
      mrequest.volume = Lot;                                                   // number of lots to trade
      mrequest.magic = EA_Magic;                                               // Order Magic Number
      mrequest.type = ORDER_TYPE_SELL;                                         // Sell Order
      mrequest.type_filling = ORDER_FILLING_FOK;                               // Order execution type
      mrequest.deviation = 100;                                                // Deviation from current price
      //--- send order
      if(OrderSend(mrequest, mresult) == 0)
        {
         Alert("Failed to place sell order.");
        }
      // get the result code
      if(mresult.retcode == 10009 || mresult.retcode == 10008)  // Request is completed or order placed
        {
         Alert("A Sell order has been successfully placed with Ticket#:", mresult.order, "!!");
        }
      else
        {
         Alert("The Sell order request could not be completed -error:", GetLastError());
         ResetLastError();
         return;
        }

     }
     if(Sell_opened && newSellStopLoss<mrequest.sl)
                {
                 Alert("New buy sl: ", newBuyStopLoss);
                 mrequest.sl = newSellStopLoss;
                }
     
     
   return;
  }

//+------------------------------------------------------------------+
//|      Trailingstop function                                       |
//+------------------------------------------------------------------+
void CheckTrailingStop(double Ask)
  {
   double SL = NormalizeDouble(Ask-150*_Point, _Digits);

   for(int t=PositionsTotal()-1 ; t>=0; t--)
     {
      string symbol = PositionGetSymbol(t);
      if(_Symbol == symbol)
        {
         ulong PositionTIcket = PositionGetInteger(POSITION_TICKET);
         double CurrentStopLoss = PositionGetDouble(POSITION_SL);

         if(CurrentStopLoss < SL)
           {
            //Modify the stop loss by 10 points
            //trade.PositionModify(PositionTIcket, (CurrentStopLoss+10*_Point), 0);
           }
        }
     }
  }
//+---------------------------------------------------------------------------------------------------------------+
//+---------------------------------------------------------------------------------------------------------------+
