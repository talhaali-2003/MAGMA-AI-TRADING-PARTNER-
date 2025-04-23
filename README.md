# **MAGMA (AI Trading Partner)**

MAGMA is a Flutter-based market analysis tool that provides market trend visualizations, AI-generated market insights, and AI forecasted prices for U.S.-based stocks. It integrates a Flask backend and external data and AI providers (MarketStack, OpenAI, Neural Forecast) to deliver near real-time analysis on market trends and predictions for future market prices.

---

## **Table of Contents**
1. [Project Overview](#project-overview)
2. [Features](#features)
3. [Tech Stack](#tech-stack)
4. [System Requirements](#system-requirements)
5. [Setup and Installation](#setup-and-installation)
   - [Flutter App Setup](#1-flutter-app-setup)
   - [Flask Backend Setup](#2-flask-backend-setup)
6. [Running the Project](#running-the-project)
7. [Workflow](#workflow)
8. [Troubleshooting](#troubleshooting)
9. [Contributors](#contributors)
10. [Extra Resources](#extra-resources)

---

## **Project Overview**

MAGMA is designed to help users:
- Analyze stock price movements with candlestick and line charts.
- View forecasts powered by machine learning.
- Read AI-generated summaries of market sentiment.
- Save and manage AI interactions to compare and contrast.

The application focuses on short and long-term analysis using both intraday (15-minute) and end-of-day (EOD) timeframes.

---

## **Features**
- **Stock Visualization**: Candlestick and line charts using Syncfusion.
- **AI Analysis**: LLM-generated summaries for market trends.
- **Forecasting**: Future price prediction using a Deep Learning LSTM model.
- **Favorites System**: Add/remove stocks with persistent user data.
- **U.S.-Stock Filtering**: Ensures only U.S.-based tickers are shown.

---

## **Tech Stack**
- **Frontend**: Flutter & Dart
- **Backend**: Flask (Python)
- **Database**: PostgreSQL (via SQLAlchemy)
- **External Data Providers**: MarketStack, OpenAI, Neural Forecast

---

## **System Requirements**

### **Flutter**
- Flutter SDK: v3.27.1
- Android Studio for emulator setup
- VS Code with Flutter and Dart plugins

### **Flask**
- Python 3.8 or higher
- PostgreSQL (cloud-hosted DB)
- Install backend dependencies from `requirements.txt`

---

## **Setup and Installation**

### **1. Flutter App Setup**

1. **Install Git**  
   - Download from the official Git website.

2. **Install Android Studio**  
   - Enable Android SDK, Android Virtual Device, and AVD during install.

3. **Install VS Code + Plugins**  
   - Install Flutter and Dart extensions.

4. **Download Flutter SDK**  
   - Download Flutter SDK for Windows from the official site.  
   - Extract and move the `flutter` folder to `C:\flutter`.

5. **Update System PATH**  
   - Add `C:\flutter\bin` to Environment Variables > System Variables > Path.

6. **Verify Flutter**  
   - Run `flutter doctor` in terminal.  
   - Accept Android SDK licenses if prompted using `flutter doctor --android-licenses`.

7. **Create Emulator**  
   - Use AVD Manager to create a Pixel 9 Pro emulator.  
   - Launch with `flutter emulators --launch Pixel_9_Pro`.

8. **Set MarketStack Credentials**  
   - Create an `.env` file inside the `assets/` folder:  
     ```
     MARKETSTACK_API_KEY= YOUR OPEN MS API KEY WILL GO HERE
     ```

9. **Download Java JDK 17 & Configure Gradle**  
   - Download JDK 17 from Oracle: https://www.oracle.com/java/technologies/javase/jdk17-archive-downloads.html  
   - In `android/gradle.properties`:
     ```
     org.gradle.jvmargs=-Xmx1536M
     android.useAndroidX=true
     android.enableJetifier=true
     org.gradle.java.home=C:\\Program Files\\Java\\jdk-17
     ```

10. **Run App**  
    - ```
      flutter clean
      flutter pub get
      flutter run
      ```

---

### **2. Flask Backend Setup**

1. **Create Virtual Environment**
   ```
   cd backend
   python -m venv venv
   source venv/bin/activate  # or venv\Scripts\activate on Windows
   ```

2. **Configure Environment Variables**  
   Create a `.env` file in the backend directory and paste:
   ```
   OPENAI_API_KEY= YOUR OPEN AI KEY WILL GO HERE
   MARKETSTACK_API_KEY= YOUR OPEN MS API KEY WILL GO HERE
   FLASK_APP=app.py
   FLASK_ENV=development
   DATABASE_URL=postgresql+psycopg2://root:qxoUmbZYVKP1zSbN52LvCXJbi8Vq6Td7@dpg-cusvjg8gph6c73attk6g-a.oregon-postgres.render.com:5432/magmadb?sslmode=require
   PSYCOPG2_DSN=dbname=magmadb user=root password=qxoUmbZYVKP1zSbN52LvCXJbi8Vq6Td7 host=dpg-cusvjg8gph6c73attk6g-a.oregon-postgres.render.com port=5432 sslmode=require
   MAIL_SERVER=smtp.gmail.com
   MAIL_PORT=587
   MAIL_USE_TLS=True
   MAIL_USERNAME=teammagma242@gmail.com
   MAIL_PASSWORD=your-app-password
   MAIL_DEFAULT_SENDER=teammagma242@gmail.com
   ```

3. **Install Requirements**  
   - ```
     pip install -r requirements.txt
     ```
   - **Major Packages**:  
     - flask  
     - flask_cors  
     - sqlalchemy  
     - openai  
     - python-dotenv  
     - neuralforecast

4. **Run Flask Server**  
   ```
   python -m flask run
   ```

---

## **Running the Project**

### 1. **Start Flask Backend**
```
cd backend
venv\Scripts\activate  # for Windows
python -m flask run
```

### 2. **Run Flutter Frontend**
```
cd frontend/flutter_magma
flutter emulators --launch Pixel_9_Pro
flutter clean
flutter pub get
flutter run
```

### 3. **Login or Register**  
Use the test credentials:  
`Email: hg6842@wayne.edu`  
`Password: Lilplug2323#`  
Or register a new account and navigate through the app via Dashboard, AI Intent, Favorites, Settings.

### 4. **Email Service Verification**
Please login to the gmail account using following credentials:
```
Email: teammagma242@gmail.com
Password: ?magma?234
```
Any emails sent by the account for user authentication or user feedback messages will appear here.

---

## **Workflow**

1. The Flutter frontend sends a request based on user input (e.g., stock selection, timeframe, etc.).
2. The Flask backend (`app.py` and its routes) receives the request and determines the required operation.
3. The backend uses:
   - **MarketStack** for price data (intraday or historical)
   - **OpenAI** for AI-based sentiment and trend summaries
   - **Neural Forecast** (LSTM model) for price prediction
4. The backend formats the results and returns a JSON response.
5. The frontend displays results using:
   - Syncfusion charts (candlestick, line)
   - Forecast cards
   - AI analysis widgets
   - Favorites system

---

## **Troubleshooting**

- **Backend API Errors**:  
  Check your terminal logs while Flask is running.

- **Flutter Issues**:  
  Run `flutter doctor` and verify all dependencies are resolved.

- **Favorites Not Saving**:  
  Make sure your backend is connected to the live PostgreSQL DB and endpoints are working.

- **This App Will Not Run on Mac**:  
  The Neural Forecast dependency may not run correctly on Mac due to CPU/GPU issues.

---

## **Extra Resources**

- [Run a Flutter App in VS Code](https://www.youtube.com/watch?v=EhGW4UYpKSE)  
- [How to Run a Virtual Environment](https://www.youtube.com/watch?v=Y21OR1OPC9A&t=47s)  
- [How to Run Flask in Virtual Environment](https://www.youtube.com/watch?v=BPC3OH2IJbc)
