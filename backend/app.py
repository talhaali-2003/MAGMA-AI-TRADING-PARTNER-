import os
import re
import numpy as np
from dotenv import load_dotenv
import json
import datetime as dt
import pandas as pd
from pandas.tseries.offsets import BDay 
from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_mail import Mail
import psycopg2

from ai_interaction.ai_logic import visualization_intent, ai_analysis_intent, forecasting_intent

# Loads environment variables from .env
load_dotenv()

# Creates our Flask app
app = Flask(__name__)
CORS(app)

# Define static top symbols and timeframes used in our app
TOP_10_SYMBOLS = ["MSFT", "AAPL", "AMZN", "GOOG", "GOOGL", "FB", "VOD", "INTC", "CMCSA", "PEP"]
TIMEFRAMES = ["15min", "1W", "1M", "YTD"]

# Basic helper to connect directly to PostgreSQL
def get_db_connection():
    return psycopg2.connect(os.getenv("PSYCOPG2_DSN"))

# Configures the database connection
app.config["SQLALCHEMY_DATABASE_URI"] = os.getenv("DATABASE_URL")
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

# Configures Flask-Mail, mainly used for user authentication at the moment
app.config["MAIL_SERVER"] = os.getenv("MAIL_SERVER", "smtp.gmail.com")
app.config["MAIL_PORT"] = int(os.getenv("MAIL_PORT", 587))
app.config["MAIL_USE_TLS"] = (os.getenv("MAIL_USE_TLS", "True") == "True")
app.config["MAIL_USERNAME"] = os.getenv("MAIL_USERNAME")
app.config["MAIL_PASSWORD"] = os.getenv("MAIL_PASSWORD")
app.config["MAIL_DEFAULT_SENDER"] = os.getenv("MAIL_DEFAULT_SENDER", "noreply@example.com")

# Initializes the database and migrations
from cd.models import db, User

# Initializes the database with the app
db.init_app(app)
migrate = Migrate(app, db)
mail = Mail(app)

# Imports all of the defined classes within our database
from cd.models import *

# Imports and registers all route blueprints
from cd.routes import auth as auth_bp
app.register_blueprint(auth_bp, url_prefix="/auth")

# Makes sure .env has OPENAI_API_KEY
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
if not OPENAI_API_KEY:
    raise ValueError("OpenAI API key not found. Ensure it's in your .env file.")

# Replace any NaNs in data before saving to DB
def clean_nan_values(data):
    if isinstance(data, dict):
        return {key: clean_nan_values(value) for key, value in data.items()}
    elif isinstance(data, list):
        return [clean_nan_values(item) for item in data]
    elif isinstance(data, float) and np.isnan(data):
        return None
    return data

# ========== ROUTES START BELOW ========== #

# Endpoint to get chart data for a given stock/timeframe
@app.route("/visualization_intent", methods=["GET"])
def get_timeframe_dataframe():
    symbol = request.args.get("symbol")
    timeframe = request.args.get("timeframe")

    if not symbol or not timeframe:
        return jsonify({"error": "Both 'symbol' and 'timeframe' are required"}), 400

    today = dt.date.today()
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute(
        """
        SELECT visualization, last_updated FROM stock_insights 
        WHERE symbol = %s AND timeframe = %s
        """,
        (symbol, timeframe)
    )
    result = cursor.fetchone()

    if result and result[0]:
            last_updated = result[1]
            if isinstance(last_updated, dt.datetime):  
                last_updated = last_updated.date()  
            
            if last_updated == today:  
                stored_visualization = result[0]  
                
                if isinstance(stored_visualization, list):
                    cleaned_visualization = stored_visualization
                else:
                    cleaned_visualization = json.loads(stored_visualization)

                conn.close()
                print(f"[INFO] Successful fetched previous visualization for {symbol} ({timeframe})...")
                return jsonify(cleaned_visualization)

    print(f"[INFO] Fetching fresh visualization for {symbol} ({timeframe})...")
    visualization_data = visualization_intent(symbol, timeframe)

    if visualization_data is None or visualization_data.empty:
        conn.close()
        return jsonify({"error": f"No data found for {symbol} ({timeframe})"}), 404

    visualization_json = visualization_data.to_dict(orient="records")
    cleaned_visualization_json = clean_nan_values(visualization_json)

    cursor.execute(
        """
        INSERT INTO stock_insights (symbol, timeframe, last_updated, visualization)
        VALUES (%s, %s, %s, %s)
        ON CONFLICT (symbol, timeframe) 
        DO UPDATE SET 
            visualization = EXCLUDED.visualization,
            last_updated = EXCLUDED.last_updated
        """,
        (symbol, timeframe, today, json.dumps(cleaned_visualization_json, default=str))
    )

    conn.commit()
    cursor.close()
    conn.close()

    return jsonify(cleaned_visualization_json)

# Endpoint to get OpenAI-based AI analysis summary
@app.route("/ai_analysis_intent", methods=["GET"])
def get_ai_analysis():
    symbol = request.args.get("symbol")
    timeframe = request.args.get("timeframe")

    if not symbol or not timeframe:
        return jsonify({"error": "Both 'symbol' and 'timeframe' are required"}), 400

    today = dt.date.today()
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute(
        """
        SELECT analysis, last_updated FROM stock_insights 
        WHERE symbol = %s AND timeframe = %s
        """,
        (symbol, timeframe)
    )
    result = cursor.fetchone()

    if result:
        stored_analysis = result[0]  
        last_updated = result[1]

        if isinstance(last_updated, dt.datetime):
            last_updated = last_updated.date()

        if last_updated == today:
            if not stored_analysis or stored_analysis.strip() == "":
                conn.close()
                print(f"[WARNING] Stored analysis for {symbol} ({timeframe}) is empty.")
                return jsonify({"error": "No AI analysis available"}), 404
            
            if isinstance(stored_analysis, str) and not stored_analysis.startswith("{") and not stored_analysis.startswith("["):
                cleaned_analysis = stored_analysis
            else:
                try:
                    cleaned_analysis = json.loads(stored_analysis)
                except json.JSONDecodeError:
                    conn.close()
                    print(f"[ERROR] Failed to decode stored analysis for {symbol} ({timeframe}).")
                    return jsonify({"error": "Corrupted AI analysis data"}), 500

            cleaned_analysis = re.sub(r'[*#]', '', cleaned_analysis)

            conn.close()
            print(f"[INFO] Successful fetched previous analysis for {symbol} ({timeframe})...")
            return jsonify({"analysis": cleaned_analysis})

    print(f"[INFO] Fetching fresh AI analysis for {symbol} ({timeframe})...")
    analysis_data = ai_analysis_intent(symbol, timeframe)

    if not analysis_data:
        conn.close()
        return jsonify({"error": f"AI analysis could not be generated for {symbol} ({timeframe})"}), 500

    cleaned_analysis = re.sub(r'[*#]', '', analysis_data)

    cursor.execute(
        """
        INSERT INTO stock_insights (symbol, timeframe, last_updated, analysis)
        VALUES (%s, %s, %s, %s)
        ON CONFLICT (symbol, timeframe) 
        DO UPDATE SET 
            analysis = EXCLUDED.analysis,
            last_updated = EXCLUDED.last_updated
        """,
        (symbol, timeframe, today, json.dumps(cleaned_analysis, default=str))
    )

    conn.commit()
    cursor.close()
    conn.close()

    return jsonify({"analysis": cleaned_analysis})  

def get_next_tradingday(startDate, availableDates):
    sorted_dates = sorted(availableDates)
    for date in sorted_dates:
        if date > startDate:
            return date
    return sorted_dates[-1] if sorted_dates else None

# Get forecasted price prediction for next day
@app.route("/forecast", methods=["GET"])
def get_forecast():
    symbol = request.args.get("symbol")
    timeframe = request.args.get("timeframe")

    if not symbol or not timeframe:
        return jsonify({"error": "Both 'symbol' and 'timeframe' are required"}), 400

    today = dt.date.today()
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute(
        """
        SELECT forecasting, last_updated FROM stock_insights 
        WHERE symbol = %s AND timeframe = %s
        """,
        (symbol, timeframe)
    )
    result = cursor.fetchone()

    if result and result[0]:
        last_updated = result[1]
        if isinstance(last_updated, dt.datetime):  
            last_updated = last_updated.date()  
        
        if last_updated == today:  
            stored_forecast_data = result[0]  
            
            if isinstance(stored_forecast_data, list):
                cleaned_forecast_data = stored_forecast_data
            else:
                cleaned_forecast_data = json.loads(stored_forecast_data)

            stored_forecast_df = pd.DataFrame(cleaned_forecast_data)

            if stored_forecast_df.empty or "date" not in stored_forecast_df.columns or "predicted_price" not in stored_forecast_df.columns:
                conn.close()
                return jsonify({"error": "Invalid stored forecast data"}), 500

            stored_forecast_df["date"] = pd.to_datetime(stored_forecast_df["date"]).dt.date
            forecast_dates = set(stored_forecast_df["date"])
            selected_date = get_next_tradingday(dt.datetime.today().date(), forecast_dates)

            if not selected_date:
                conn.close()
                return jsonify({"error": "No available forecast for selected date"}), 404

            forecast_for_day = stored_forecast_df[stored_forecast_df["date"] == selected_date]

            if forecast_for_day.empty:
                conn.close()
                return jsonify({"error": "No available forecast for selected date"}), 404

            forecast_data = {
                "symbol": symbol,
                "date": str(selected_date),
                "predicted_price": forecast_for_day.iloc[0]["predicted_price"]
            }

            conn.close()
            print(f"[INFO] Successful fetched previous forecast for {symbol} ({timeframe})...")
            return jsonify(forecast_data)  

    print(f"[INFO] Fetching fresh forecast for {symbol} ({timeframe})...")
    forecastResults = forecasting_intent(symbol, timeframe)

    if not forecastResults:
        conn.close()
        return jsonify({"error": "No forecast data available"}), 404

    forecast_list = forecastResults.get("forecast")
    if not forecast_list:
        conn.close()
        return jsonify({"error": "No forecast data available"}), 404

    forecast_df = pd.DataFrame(forecast_list)

    if forecast_df.empty or "date" not in forecast_df.columns or "predicted_price" not in forecast_df.columns:
        conn.close()
        return jsonify({"error": "Missing forecast data"}), 500

    forecast_df["date"] = pd.to_datetime(forecast_df["date"]).dt.date
    forecast_dates = set(forecast_df["date"])
    selected_date = get_next_tradingday(dt.datetime.today().date(), forecast_dates)

    if not selected_date:
        conn.close()
        return jsonify({"error": "No available forecast for selected date"}), 404

    forecast_for_day = forecast_df[forecast_df["date"] == selected_date]

    if forecast_for_day.empty:
        conn.close()
        return jsonify({"error": "No available forecast for selected date"}), 404

    forecast_data = {
        "symbol": symbol,
        "date": str(selected_date),
        "predicted_price": forecast_for_day.iloc[0]["predicted_price"]
    }

    cleaned_forecast_data = clean_nan_values(forecast_list)

    cursor.execute(
        """
        INSERT INTO stock_insights (symbol, timeframe, last_updated, forecasting)
        VALUES (%s, %s, %s, %s)
        ON CONFLICT (symbol, timeframe) 
        DO UPDATE SET 
            forecasting = EXCLUDED.forecasting,
            last_updated = EXCLUDED.last_updated
        """,
        (symbol, timeframe, today, json.dumps(cleaned_forecast_data, default=str))
    )

    conn.commit()
    cursor.close()
    conn.close()

    return jsonify(forecast_data)  

# Goes through top stocks and timeframes and saves fresh data into the database
@app.route("/preprocess_stocks", methods=["GET"])
def preprocess_stocks():
    today = dt.date.today().isoformat() 
    conn = get_db_connection()
    cursor = conn.cursor()

    for symbol in TOP_10_SYMBOLS:
        for timeframe in TIMEFRAMES:
            cursor.execute(
                """
                SELECT 1 FROM stock_insights
                WHERE symbol = %s AND timeframe = %s AND last_updated = %s
                """,
                (symbol, timeframe, today)
            )
            existing_entry = cursor.fetchone()

            if existing_entry:
                print(f"[INFO] Data for {symbol} ({timeframe}) already exists for today. Skipping...")
                continue

            print(f"[INFO] Processing {symbol} ({timeframe})...")
            visualization_data = visualization_intent(symbol, timeframe)
            analysis_data = ai_analysis_intent(symbol, timeframe)
            forecast_data = forecasting_intent(symbol, timeframe)

            if visualization_data is not None and not visualization_data.empty:
                visualization_data_json = visualization_data.copy()
                visualization_data_json["date"] = visualization_data_json["date"].astype(str) 
                visualization_data_json = visualization_data_json.to_dict(orient="records")
            else:
                visualization_data_json = None

            cleaned_visualization_data = clean_nan_values(visualization_data_json)
            cleaned_analysis_data = clean_nan_values(analysis_data)
            cleaned_forecast_data = clean_nan_values(forecast_data)

            if cleaned_visualization_data and cleaned_analysis_data and cleaned_forecast_data:
                cursor.execute(
                    """
                    INSERT INTO stock_insights (symbol, timeframe, last_updated, visualization, analysis, forecasting)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    """,
                    (symbol, timeframe, today, 
                    json.dumps(cleaned_visualization_data, default=str), 
                    json.dumps(cleaned_analysis_data, default=str), 
                    json.dumps(cleaned_forecast_data, default=str))
                )
                conn.commit()
                print(f"[SUCCESS] Stored insights for {symbol} ({timeframe})")
            else:
                print(f"[WARNING] Skipped {symbol} ({timeframe}) due to missing data.")

    cursor.close()
    conn.close()
    return jsonify({"message": "Stock insights processing completed."})

# Adds a stock to the user's favorites if it isn't already
@app.route("/toggle_favorite", methods=["POST"])
def toggle_favorite():
    data = request.json
    user_email = data.get("user_email")
    symbol = data.get("symbol")
    timeframe = data.get("timeframe")

    if not user_email or not symbol or not timeframe:
        return jsonify({"error": "Missing required fields"}), 400

    conn = get_db_connection()
    cursor = conn.cursor()

    # Get the current stock insight's last_updated date
    cursor.execute(
        """
        SELECT last_updated FROM stock_insights 
        WHERE symbol = %s AND timeframe = %s
        ORDER BY last_updated DESC
        LIMIT 1
        """,
        (symbol, timeframe)
    )
    stock_insight = cursor.fetchone()
    if not stock_insight:
        conn.close()
        return jsonify({"error": "Stock insight not found"}), 404

    current_last_updated = stock_insight[0]

    # Check if this favorite already exists
    cursor.execute(
        """
        SELECT 1 FROM favorites 
        WHERE user_email = %s AND symbol = %s AND timeframe = %s AND last_updated = %s
        """,
        (user_email, symbol, timeframe, current_last_updated)
    )
    existing_favorite = cursor.fetchone()

    if existing_favorite:
        cursor.close()
        conn.close()
        return jsonify({"message": "Already in favorites"}), 200

    current_timestamp = dt.datetime.now()

    # Insert new favorite entry
    cursor.execute(
        """
        INSERT INTO favorites (user_email, symbol, timeframe, visualization, analysis, forecasting, last_updated, added_timestamp)
        SELECT 
            %s, symbol, timeframe, visualization, analysis, forecasting, last_updated, %s
        FROM stock_insights 
        WHERE symbol = %s AND timeframe = %s
        """,
        (user_email, current_timestamp, symbol, timeframe)
    )

    conn.commit()
    cursor.close()
    conn.close()

    return jsonify({"message": "Added to favorites"}), 201

# Returns all the user's saved favorite stocks
@app.route("/get_favorites", methods=["GET"])
def get_favorites():
    user_email = request.args.get("user_email")

    if not user_email:
        return jsonify({"error": "User email is required"}), 400

    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute(
        """
        SELECT symbol, timeframe, added_timestamp FROM favorites WHERE user_email = %s
        """,
        (user_email,)
    )

    favorites = cursor.fetchall()
    formatted_favorites = []
    
    for row in favorites:
        timestamp = row[2]
        formatted_favorites.append({
            "symbol": row[0], 
            "timeframe": row[1],
            "added_time": timestamp.strftime("%m/%d/%y %I:%M%p") if timestamp else None,
            "added_raw": timestamp.isoformat() if timestamp else None
        })

    cursor.close()
    conn.close()

    return jsonify(formatted_favorites), 200

# Checks if a specific stock/timeframe is already in favorites
@app.route("/check_favorite", methods=["GET"])
def check_favorite():
    user_email = request.args.get("email")
    symbol = request.args.get("symbol")
    timeframe = request.args.get("timeframe")

    if not user_email or not symbol or not timeframe:
        return jsonify({"error": "Missing required fields"}), 400

    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute(
        """
        SELECT last_updated FROM stock_insights
        WHERE symbol = %s AND timeframe = %s
        ORDER BY last_updated DESC
        LIMIT 1
        """,
        (symbol, timeframe)
    )
    result = cursor.fetchone()

    if not result:
        cursor.close()
        conn.close()
        return jsonify({"error": "No stock insight found"}), 404

    latest_last_updated = result[0]

    cursor.execute(
        """
        SELECT 1 FROM favorites 
        WHERE user_email = %s AND symbol = %s AND timeframe = %s AND last_updated = %s
        """,
        (user_email, symbol, timeframe, latest_last_updated)
    )
    existing_favorite = cursor.fetchone()

    cursor.close()
    conn.close()

    return jsonify({"is_favorite": existing_favorite is not None}), 200

# Removes a specific favorite from the database
@app.route("/remove_favorite", methods=["POST"])
def remove_favorite():
    data = request.json
    user_email = data.get("user_email")
    symbol = data.get("symbol")
    timeframe = data.get("timeframe")
    added_time = data.get("added_time")  # Expecting string

    print(f"[REMOVE REQUEST] user_email={user_email}, symbol={symbol}, timeframe={timeframe}, added_time={added_time}")

    if not user_email or not symbol or not timeframe or not added_time:
        print("[ERROR] Missing required fields.")
        return jsonify({"error": "Missing required fields"}), 400

    try:
        # Convert added_time string back into a datetime
        added_timestamp = dt.datetime.fromisoformat(added_time)
        print(f"[PARSED] added_timestamp={added_timestamp}")
    except ValueError as e:
        print(f"[ERROR] Invalid date format: {e}")
        return jsonify({"error": "Invalid date format"}), 400

    conn = get_db_connection()
    cursor = conn.cursor()

    # Previews existing records to debug mismatches
    cursor.execute(
        """
        SELECT user_email, symbol, timeframe, added_timestamp
        FROM favorites
        WHERE user_email = %s AND symbol = %s AND timeframe = %s
        """,
        (user_email, symbol, timeframe)
    )
    existing_matches = cursor.fetchall()
    print(f"[EXISTING MATCHES] {existing_matches}")

    # Attempt deletion
    cursor.execute(
        """
        DELETE FROM favorites 
        WHERE user_email = %s AND symbol = %s AND timeframe = %s AND added_timestamp = %s
        """,
        (user_email, symbol, timeframe, added_timestamp)
    )
    deleted_rows = cursor.rowcount
    print(f"[DELETE] Rows affected: {deleted_rows}")

    conn.commit()
    cursor.close()
    conn.close()

    return jsonify({"message": "Favorite removed successfully"}), 200


if __name__ == "__main__":
    app.run(debug=True)