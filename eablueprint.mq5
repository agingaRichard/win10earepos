//+------------------------------------------------------------------+
//|                                                  eablueprint.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//---
// Input parameters such as sl, tp, lot size, etc
// Other parameters eg null values for eahandlers
//---

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
// Initaialize handlers and check their return values
// Edit sl and tp values for 3 and 5 digit pairs
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
// de-initialize handlers
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
// Check if we have enough bars
// Check if we are on a new bar
// Define mql5 stuctures
// Make sure the indicator value arrays are stored similarly to timeseries arrays
// Get the last price quote
// Get the last 3 bars
// Copy indicator values to arrays
// Check for open positions
// Copy the bar close price for the previous bar prior to the current bar, that is Bar 1
// Declare check our buy/sell Conditions
// Execute trades
//---
  }
//+------------------------------------------------------------------+
