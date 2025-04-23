import os
import datetime as dt
import requests
import pkg_resources
import pytz
import pandas as pd
import pandas_ta as ta
from flask import request, jsonify
from dotenv import load_dotenv
from openai import OpenAI
from neuralforecast import NeuralForecast
from neuralforecast.models import LSTM
from neuralforecast.utils import AirPassengersDF

# Load environment variables
load_dotenv()
MARKETSTACK_API_KEY = os.getenv("MARKETSTACK_API_KEY")
MARKETSTACK_BASE_URL = "http://api.marketstack.com/v1"
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

#Setup Open AI Client
client = OpenAI(
    api_key=os.getenv("OPENAI_API_KEY"),
)

# This function fetches stock data depending on the timeframe passed (15min, weekly, monthly)
def visualization_intent(symbol, timeframe):
    # Determine which data function to call based on timeframe
    if timeframe == "15min":
        dataframe = get_intraday_data(symbol=symbol, interval="15min")
    elif timeframe == "1W":
        dataframe = get_weekly_data(symbol)
    elif timeframe == "1M":
        dataframe = get_monthly_data(symbol)
    elif timeframe == "YTD":
        dataframe = get_yearly_data(symbol)
    elif timeframe == "1D":
        end_date = dt.datetime.now().date()
        start_date = end_date - dt.timedelta(days=60)
        dataframe = get_historical_data(symbol, date_from=str(start_date), date_to=str(end_date))
    else:
        print("Invalid timeframe. Use '15min', '1W', '1M', 'YTD', or '1D'.")
        return None

    if dataframe is None or dataframe.empty:
        print(f"Error: No data retrieved for {symbol} ({timeframe})")
        return None

    print(f"DataFrame for {symbol} ({timeframe}) loaded successfully.")
    return dataframe

# This computes common technical indicators like SMA, RSI, MACD, Fibonacci
# I'm using pandas_ta and some math here to prep data to be passed to Open AI
def compute_technical_indicators(df):
    df = df.copy()

    df["SMA_10"] = df["close"].rolling(window=10).mean()
    df["SMA_50"] = df["close"].rolling(window=50).mean()

    df["EMA_10"] = df["close"].ewm(span=10, adjust=False).mean()
    df["EMA_50"] = df["close"].ewm(span=50, adjust=False).mean()

    df["RSI"] = ta.rsi(df["close"], length=14)

    df["MACD"] = df["close"].ewm(span=12, adjust=False).mean() - df["close"].ewm(span=26, adjust=False).mean()

    df["ATR"] = ta.atr(df["high"], df["low"], df["close"], length=14)

    high = df["high"].max()
    low = df["low"].min()
    fib_levels = {
        "23.6%": high - (0.236 * (high - low)),
        "38.2%": high - (0.382 * (high - low)),
        "50%":  high - (0.50  * (high - low)),
        "61.8%": high - (0.618 * (high - low)),
        "78.6%": high - (0.786 * (high - low)),
    }

    return df, fib_levels

# This function sends the computed data to GPT and asks it to summarize the technical analysis in plain English
def ai_analysis_intent(symbol, timeframe):
    try:
        # Handle timeframe
        if timeframe == "15min":
            df = get_intraday_data(symbol=symbol, interval="15min")
        elif timeframe == "1W":
            df = get_weekly_data(symbol)
        elif timeframe == "1M":
            df = get_monthly_data(symbol)
        elif timeframe == "YTD":
            df = get_yearly_data(symbol)
        elif timeframe == "1D":
            end_date = dt.datetime.now().date()
            start_date = end_date - dt.timedelta(days=60)
            df = get_historical_data(symbol, date_from=str(start_date), date_to=str(end_date))
        else:
            print("Invalid timeframe. Use '15min', '1W', '1M', 'YTD', or '1D'.")
            return None

        if df is None or df.empty:
            print(f"No valid data available for {symbol} ({timeframe})")
            return None

        print("DataFrame loaded successfully.")
        print(df)

    except Exception as e:
        print(f"Error loading stock data: {e}")
        return None

    # Compute technical indicators
    df, fib_levels = compute_technical_indicators(df)
    dataframe_string = df.to_string(index=False)
    fib_string = "\n".join([f"{k}: {v:.2f}" for k, v in fib_levels.items()])

    prompt_template = f"""
    You are a financial analysis assistant. Your goal is to analyze stock market data and provide a simple, non-technical summary that anyone can understand. Follow these steps:

    Step 1: Explain Market Concepts in a Simple Way
    Describe the key technical indicators and why they matter in plain language:
    - Simple Moving Average (SMA): Tracks the stock's average price over time to show trends.
    - Exponential Moving Average (EMA): Similar to SMA, but reacts faster to price changes.
    - Relative Strength Index (RSI): Shows whether a stock is overbought (above 70) or oversold (below 30).
    - MACD (Moving Average Convergence Divergence): Helps identify if a trend is strengthening or weakening.
    - Fibonacci Retracement Levels: Helps find price points where a stock might reverse direction.
    - Average True Range (ATR): Measures volatility—how much a stock's price moves.

    Step 2: Analyze the Provided Data
    - Identify trends using SMA and EMA.
    - Check RSI to determine if the stock is overbought or oversold.
    - Use MACD to confirm whether the trend is gaining strength.
    - Examine Fibonacci levels to detect key support and resistance levels.
    - Assess volatility using ATR.

    Step 3: Provide a Short Market Outlook
    - Summarize if the stock is trending up (bullish), down (bearish), or sideways (neutral).
    - Mention if the trend is strong or weak.
    - Avoid complex numbers—keep the explanation clear and general.

    Here is the stock data you need to analyze:
    ```
    {dataframe_string}
    ```
    Fibonacci Levels:
    ```
    {fib_string}
    ```

    Generate a short, **easy-to-read** summary in plain text format. Keep it brief and clear, avoiding unnecessary technical details.
    """

    try:
        response = client.chat.completions.create(
            model="gpt-4-turbo",
            messages=[
                {"role": "system", "content": "You are a financial market analyst providing easy-to-understand stock insights"},
                {"role": "user", "content": prompt_template}
            ],
            max_tokens=700,
            temperature=0.7
        )
        generated_code = response.choices[0].message.content
        return generated_code

    except Exception as e:
        print(f"Error in AI Visualization Intent: {e}")
        return None

# Forecasting logic using NeuralForecast's LSTM model
def forecasting_intent(symbol, timeframe):
    try:
        print(f"\n[DEBUG] Starting Forecasting for {symbol} on {timeframe}...\n")

        # Determine which data function to call based on timeframe
        if timeframe == "15min":
            df = get_intraday_data(symbol=symbol, interval="15min")
        elif timeframe == "1W":
            df = get_weekly_data(symbol)
        elif timeframe == "1M":
            df = get_monthly_data(symbol)
        elif timeframe == "YTD":
            df = get_yearly_data(symbol)
        elif timeframe == "1D":
            end_date = dt.datetime.now().date()
            start_date = end_date - dt.timedelta(days=60)
            df = get_historical_data(symbol, date_from=str(start_date), date_to=str(end_date))
        else:
            print("[ERROR] Invalid timeframe. Use '15min', '1W', '1M', 'YTD', or '1D'.")
            return None

        if df is None or df.empty:
            print(f"[ERROR] No valid data available for {symbol} ({timeframe})")
            return None

        print("[DEBUG] DataFrame loaded successfully:")
        print(df.head())

    except Exception as e:
        print(f"[ERROR] Error loading stock data: {e}")
        return None

    # Preprocess DataFrame
    try:
        print("\n[DEBUG] Preprocessing DataFrame...")
        df = preprocess_dataframe(df, symbol)
        print("[DEBUG] Preprocessed DataFrame:")
        print(df.head())
    except Exception as e:
        print(f"[ERROR] Error during preprocessing: {e}")
        return None

    # Define forecasting model
    try:
        print("\n[DEBUG] Initializing LSTM Model...")
        forecast_model = NeuralForecast(
            models=[LSTM(h=10, input_size=60)],
            freq="D"
        )
        print("[DEBUG] Model initialized successfully.")
    except Exception as e:
        print(f"[ERROR] Error initializing LSTM model: {e}")
        return None

    # Train model on historical data
    try:
        print("\n[DEBUG] Training the model...")
        forecast_model.fit(df)
        print("[DEBUG] Model training completed.")
    except Exception as e:
        print(f"[ERROR] Error during model training: {e}")
        return None

    # Generate predictions
    try:
        print("\n[DEBUG] Generating predictions...")
        predictions = forecast_model.predict()
        print("[DEBUG] Predictions generated successfully.")
        print(predictions.head())
    except Exception as e:
        print(f"[ERROR] Error generating predictions: {e}")
        return None

    # Format predictions
    try:
        print("\n[DEBUG] Formatting predictions...")
        forecast_results = format_predictions(predictions)
        print("[DEBUG] Formatted Forecast:")
        print(forecast_results)
    except Exception as e:
        print(f"[ERROR] Error formatting predictions: {e}")
        return None

    print("\n[DEBUG] Forecasting completed successfully.")

    return {
        "symbol": symbol,
        "timeframe": timeframe,
        "forecast": forecast_results
    }

# Clean and rename columns so the LSTM model understands the format
def preprocess_dataframe(df, symbol):
    if "date" in df.columns:
        df = df.rename(columns={"date": "ds"})
        df["ds"] = pd.to_datetime(df["ds"])

    if "close" in df.columns:
        df = df.rename(columns={"close": "y"})

    df["unique_id"] = str(symbol)

    non_numeric_cols = ["symbol", "exchange", "last"]
    df.drop(columns=[col for col in non_numeric_cols if col in df.columns], inplace=True, errors='ignore')

    df = df.fillna(method="ffill")  
    df = df.fillna(method="bfill")
    return df

# Converts model predictions into something we can return to frontend
def format_predictions(predictions):
    return [
        {"date": str(date), "predicted_price": float(price)}
        for date, price in zip(predictions['ds'], predictions['LSTM'])
    ]

# =========== MARKETSTACK API UTILS ===========

# This part is where the Marketstack API is utilized and called for timeframe historical market data
# It loops to get as much data as allowed by pagination
def get_historical_data(symbol, date_from=None, date_to=None, limit=1000):
    endpoint = "https://api.marketstack.com/v1/eod"
    all_data = pd.DataFrame()
    offset = 0

    while True:
        params = {
            "access_key": MARKETSTACK_API_KEY,
            "symbols": symbol,
            "date_from": date_from,
            "date_to": date_to,
            "limit": limit,
            "offset": offset,
        }

        try:
            response = requests.get(endpoint, params=params)
            print(f"Request URL: {response.url}")
            print(f"Response Status Code: {response.status_code}")
            response.raise_for_status()

            data = response.json()
            if "data" in data and data["data"]:
                current_page = pd.DataFrame(data["data"])
                all_data = pd.concat([all_data, current_page], ignore_index=True)
                print(f"Fetched {len(current_page)} rows. Total so far: {len(all_data)}.")

                pagination = data.get("pagination", {})
                if pagination.get("count", 0) < pagination.get("limit", 0):
                    print("No more data available.")
                    break

                offset += limit
            else:
                print("No valid data returned.")
                break
        except requests.exceptions.RequestException as e:
            print(f"API request error: {e}")
            break

    return all_data

# These helper functions just wrap the historical fetcher with pre-built date ranges
def get_weekly_data(symbol):
    today = dt.datetime.now().date()
    week_ago = today - dt.timedelta(days=10)
    return get_historical_data(symbol, date_from=str(week_ago), date_to=str(today))

def get_monthly_data(symbol):
    today = dt.datetime.now().date()
    month_ago = today - dt.timedelta(days=45)
    return get_historical_data(symbol, date_from=str(month_ago), date_to=str(today))

def get_yearly_data(symbol):
    today = dt.datetime.now().date()
    year_ago = today - dt.timedelta(days=519)
    return get_historical_data(symbol, date_from=str(year_ago), date_to=str(today))


# Market is closed if it's weekend or not between 9:30am and 4pm EST
def is_market_closed():
    est = pytz.timezone('America/New_York')
    now = dt.datetime.now(est)
    market_open_time = now.replace(hour=9, minute=30, second=0, microsecond=0)
    market_close_time = now.replace(hour=16, minute=0, second=0, microsecond=0)

    # If weekend
    if now.weekday() > 4:
        return True
    # If before open or after close
    return now < market_open_time or now >= market_close_time

# This grabs intraday data like 15min candles, and falls back to previous day if market is closed
def get_intraday_data(symbol, interval="15min", limit=100):
    today = dt.datetime.now().date()

    if is_market_closed():
        # Use current date if market is closed
        last_trading_day = today - dt.timedelta(days=1)
        print("Market is closed, pulling current day's data.")
    else:
        # Use previous trading day if market is open
        last_trading_day = today - dt.timedelta(days=1)
        print("Market is open, pulling most recent completed trading day.")

    while last_trading_day.weekday() > 4:  # Roll back if weekend
        last_trading_day -= dt.timedelta(days=1)

    last_trading_day_str = last_trading_day.strftime("%Y-%m-%d")

    def fetch_data(trading_day):
        endpoint = f"https://api.marketstack.com/v1/intraday/{trading_day}"
        params = {
            "access_key": MARKETSTACK_API_KEY,
            "symbols": symbol,
            "interval": interval,
            "limit": limit,
        }
        try:
            response = requests.get(endpoint, params=params)
            print(f"Request URL: {response.url}")
            print(f"Response Status Code: {response.status_code}")
            response.raise_for_status()

            data = response.json()
            if "data" in data and data["data"]:
                intraday_data = pd.DataFrame(data["data"])
                if not intraday_data.empty and "date" in intraday_data.columns:
                    intraday_data["date"] = pd.to_datetime(intraday_data["date"])
                return intraday_data.sort_values(by="date").reset_index(drop=True)
        except requests.exceptions.RequestException as e:
            print(f"API request error: {e}")
            return pd.DataFrame()

        return pd.DataFrame()

    data = fetch_data(last_trading_day_str)
    if data.empty:
        print(f"No data found for {last_trading_day_str}. Trying previous trading day...")
        last_trading_day -= dt.timedelta(days=1)
        last_trading_day_str = last_trading_day.strftime("%Y-%m-%d")
        data = fetch_data(last_trading_day_str)

    return data
