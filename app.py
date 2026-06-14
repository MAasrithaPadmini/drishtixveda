# =========================
# ENV LOAD
# =========================
from dotenv import load_dotenv
load_dotenv()

import torch
import numpy as np

_original_torch_load = torch.load
def cpu_load(*args, **kwargs):
    kwargs["map_location"] = torch.device("cpu")
    return _original_torch_load(*args, **kwargs)

torch.load = cpu_load

# =========================
# LOAD MODEL
# =========================
from darts.models import TFTModel
model = TFTModel.load("global_return_model")
model.model.eval()

torch.manual_seed(42)
np.random.seed(42)

# =========================
# IMPORTS
# =========================
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import pandas as pd
import os
import cv2
import pytesseract
import re
from PIL import Image
from io import BytesIO
from datetime import datetime, timedelta
from darts import TimeSeries
from darts.dataprocessing.transformers import Scaler
from kiteconnect import KiteConnect
import traceback
# 🔥 FIREBASE
import firebase_admin
from firebase_admin import credentials, firestore

cred = credentials.Certificate("/home/drishtixveda/backend/serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# =========================
# FASTAPI INIT
# =========================
app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# =========================
# ZERODHA
# =========================
API_KEY = os.getenv("KITE_API_KEY")
MASTER_ACCESS_TOKEN = os.getenv("KITE_ACCESS_TOKEN")

kite = KiteConnect(api_key=API_KEY)
kite.set_access_token(MASTER_ACCESS_TOKEN)

print("✅ Zerodha connected")

# =========================
# LOAD INSTRUMENTS
# =========================
ALL_INSTRUMENTS = kite.instruments()

SEARCHABLE_STOCKS = [
    {
        "tradingsymbol": i["tradingsymbol"],
        "exchange": i["exchange"],
        "instrument_token": i["instrument_token"],
        "symbol_lower": i["tradingsymbol"].lower()
    }
    for i in ALL_INSTRUMENTS
    if i["exchange"] in ["NSE", "BSE"]
]
VALID_STOCKS = set([s["tradingsymbol"] for s in SEARCHABLE_STOCKS])

# =========================
# HELPERS
# =========================
def calendar_to_trading_days(days: int):
    return max(1, min(int(days * 5 / 7), 252))

def get_history(symbol_token: int):
    to_date = datetime.now()
    from_date = to_date - timedelta(days=365 * 5)

    candles = kite.historical_data(
        instrument_token=symbol_token,
        from_date=from_date,
        to_date=to_date,
        interval="day"
    )

    if len(candles) < 200:
        raise HTTPException(400, "Not enough data")

    return pd.DataFrame(candles)

def get_trend(df):
    sma20 = df["close"].rolling(20).mean().iloc[-1]
    sma50 = df["close"].rolling(50).mean().iloc[-1]
    return "UPTREND" if sma20 > sma50 else "DOWNTREND"

def generate_signal(current, predicted):
    change = (predicted - current) / current * 100
    if change > 1:
        return "BUY"
    elif change < -1:
        return "SELL"
    return "HOLD"

def statistical_confidence(forecast_returns, lower, upper, median):
    vol = np.std(forecast_returns.values())
    spread = abs(upper - lower) / abs(median)
    raw = 1 / (1 + vol * 20 + spread * 5)
    return float(round(max(35, min(raw * 100, 92)), 2))

def returns_to_price_bounds(current_price, forecast_returns):
    returns = forecast_returns.values()
    prices = []

    for sample in returns:
        price = current_price
        for r in sample:
            price *= np.exp(r)
        prices.append(price)

    prices = np.array(prices)

    return (
        float(np.percentile(prices, 10)),
        float(np.percentile(prices, 50)),
        float(np.percentile(prices, 90))
    )

# =========================
# ROOT
# =========================
@app.get("/")
def root():
    return {"status": "running"}

# =========================
# SEARCH
# =========================
@app.get("/search")
def search_stock(query: str):
    q = query.lower()

    exact = []
    starts = []
    contains = []

    for s in SEARCHABLE_STOCKS:
        symbol = s["symbol_lower"]

        if symbol == q:
            exact.append(s)
        elif symbol.startswith(q):
            starts.append(s)
        elif q in symbol:
            contains.append(s)

    results = (exact + starts + contains)[:20]

    return {
        "stocks": [
            {
                "tradingsymbol": s["tradingsymbol"],
                "exchange": s["exchange"],
                "instrument_token": s["instrument_token"]
            }
            for s in results
        ]
    }
# =========================
# LIVE PRICE
# =========================
@app.get("/live_price")
def live_price(symbol: str):
    try:
        instrument = None
        exchange = None

        for ins in ALL_INSTRUMENTS:
            if ins["tradingsymbol"] == symbol:
                instrument = ins
                exchange = ins["exchange"]
                break

        if not instrument:
            return {"price": None}

        tradingsymbol = f"{exchange}:{symbol}"
        ltp = kite.ltp(tradingsymbol)
        price = ltp[tradingsymbol]["last_price"]

        return {"price": price}

    except Exception as e:
        print("LIVE PRICE ERROR:", e)
        return {"price": None}

# =========================
# OCR
# =========================
@app.post("/portfolio-ocr")
async def portfolio_ocr(file: UploadFile = File(...)):
    contents = await file.read()

    img = Image.open(BytesIO(contents))
    img = np.array(img)

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    text = pytesseract.image_to_string(gray)

    symbols = []
    matches = re.findall(r"[A-Z]{2,15}", text)

    for m in matches:
        if m in VALID_STOCKS:
            symbols.append(m)

    symbols = list(set(symbols))
    results = []

    for s in symbols:
        stock = next(
            (x for x in SEARCHABLE_STOCKS if x["tradingsymbol"] == s),
            None
        )

        if not stock:
            continue

        try:
            df = get_history(stock["instrument_token"])
            current_price = float(df["close"].iloc[-1])
            trend = get_trend(df)

            df["log_return"] = np.log(df["close"] / df["close"].shift(1))
            df = df.dropna()

            ts = TimeSeries.from_values(df["log_return"].values)
            scaler = Scaler()
            ts_scaled = scaler.fit_transform(ts)

            forecast_scaled = model.predict(
                n=20,
                series=ts_scaled,
                num_samples=200
            )

            forecast_returns = scaler.inverse_transform(forecast_scaled)

            lower, median, upper = returns_to_price_bounds(
                current_price, forecast_returns
            )

            confidence = statistical_confidence(
                forecast_returns, lower, upper, median
            )

            results.append({
                "symbol": s,
                "instrument_token": stock["instrument_token"],
                "exchange": stock["exchange"],
                "current_price": current_price,
                "predicted_price": median,
                "lower_bound": lower,
                "upper_bound": upper,
                "trend": trend,
                "signal": generate_signal(current_price, median),
                "confidence": confidence
            })

        except Exception as e:
          import traceback
          print("OCR ERROR:", e)
          traceback.print_exc()
          continue

    return {
        "symbols_detected": symbols,
        "predictions": results
    }

# =========================
# PREDICT (WITH SAVE)
# =========================
@app.get("/predict")
def predict(symbol_token: int, market: str, days: int, user_id: str):
    try:
        print("🔥 API HIT:", symbol_token)

        df = get_history(symbol_token)

        if df is None or df.empty:
            raise Exception("No historical data")

        current_price = float(df["close"].iloc[-1])
        trend = get_trend(df)
        trading_days = calendar_to_trading_days(days)

        df["log_return"] = np.log(df["close"] / df["close"].shift(1))
        df = df.dropna()

        if len(df) < 50:
            raise Exception("Not enough data after processing")

        ts = TimeSeries.from_values(df["log_return"].values)

        scaler = Scaler()
        ts_scaled = scaler.fit_transform(ts)

        forecast_scaled = model.predict(
            n=trading_days,
            series=ts_scaled,
            num_samples=200
        )

        forecast_returns = scaler.inverse_transform(forecast_scaled)

        lower, median, upper = returns_to_price_bounds(
            current_price, forecast_returns
        )

        confidence = statistical_confidence(
            forecast_returns, lower, upper, median
        )

        stock_info = next(
            (s for s in SEARCHABLE_STOCKS if int(s["instrument_token"]) == int(symbol_token)),
            None
        )

        if stock_info is None:
            symbol = "UNKNOWN"
            exchange = "NSE"
        else:
            symbol = stock_info["tradingsymbol"]
            exchange = stock_info["exchange"]

        # 🔥 FIRESTORE (SAFE)
        try:
            db.collection("users").document(user_id).collection("predictions").add({
                "symbol": symbol,
                "exchange": exchange.upper(),
                "current_price": current_price,
                "entry_price": current_price,
                "predicted_price": median,
                "lower_bound": lower,
                "upper_bound": upper,
                "trend": trend,
                "signal": generate_signal(current_price, median),
                "confidence": confidence,
                "days": days,
                "created_at": firestore.SERVER_TIMESTAMP,
                "target_date": (datetime.now() + timedelta(days=days)).isoformat(),
                "actual_price": None,
                "instrument_token": symbol_token,
                "notified": False,
                "read": False
            })
        except Exception as e:
            print("⚠️ FIRESTORE FAILED:", e)

        # ✅ ALWAYS RETURN (VERY IMPORTANT)
        return {
            "current_price": current_price,
            "predicted_price": median,
            "lower_bound": lower,
            "upper_bound": upper,
            "trend": trend,
            "signal": generate_signal(current_price, median),
            "confidence": confidence
        }

    except Exception as e:
        print("❌ FULL ERROR:")
        traceback.print_exc()
        return {"error": str(e)}

@app.get("/update_actual_prices")
def update_actual_prices():
    users = db.collection("users").stream()

    for user in users:
        user_id = user.id

        preds = db.collection("users") \
            .document(user_id) \
            .collection("predictions") \
            .stream()

        for doc in preds:
            data = doc.to_dict()

            # ✅ only update if not filled
            if data.get("actual_price") is None:

                symbol = data["symbol"]

                try:
                    instrument = next(
                        (i for i in ALL_INSTRUMENTS if i["tradingsymbol"] == symbol),
                        None
                    )

                    if not instrument:
                        continue

                    exchange = instrument["exchange"]
                    tradingsymbol = f"{exchange}:{symbol}"

                    ltp = kite.ltp(tradingsymbol)
                    price = ltp[tradingsymbol]["last_price"]

                    doc.reference.update({
                        "actual_price": price
                    })

                    print(f"✅ UPDATED {symbol} → {price}")

                except Exception as e:
                    print("❌ ERROR:", e)

    return {"status": "done"}


@app.get("/candles")
def get_candles(token: int, exchange: str, days: int = 30):
    from datetime import datetime, timedelta

    try:
        to_date = datetime.now()
        from_date = to_date - timedelta(days=days)

        data = kite.historical_data(
            instrument_token=token,
            from_date=from_date,
            to_date=to_date,
            interval="day"
        )

        return data

    except Exception as e:
        return {"error": str(e)}
