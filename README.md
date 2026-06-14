# DrishtiXVeda — AI Stock Prediction Platform

> **Drishti** (दृष्टि) = Vision. **Veda** (वेद) = Knowledge.
> The stock market is volatile. You need both to navigate it.

DrishtiXVeda is an AI-powered stock market decision-support platform that uses a Temporal Fusion Transformer (TFT) to forecast stock price ranges, trends, confidence scores, and investment signals for Indian equities listed on NSE and BSE.

Live at: [drishtixveda.com](https://drishtixveda.com)

---

## What it does

- Predicts next-day, next-week, next-month, and 6-month stock price ranges
- Generates BUY / SELL / HOLD signals with confidence scores
- Detects UPTREND / DOWNTREND using SMA crossover
- Tracks prediction accuracy against actual realized prices
- Scans portfolio screenshots via OCR to extract and predict multiple stocks at once
- Refreshes live prices daily via Zerodha Kite Connect API

---

## Architecture

```
Flutter Mobile App (Android)
        │
        ▼
FastAPI Backend — self-hosted VPS (Hostinger)
        │
        ├── Zerodha Kite Connect API (live NSE/BSE prices)
        │
        ├── Historical OHLC Data (5 years via Kite)
        │
        ├── Log Return Transformation
        │
        ├── Temporal Fusion Transformer (TFT via Darts)
        │       └── Probabilistic forecast (200 Monte Carlo samples)
        │
        ├── Price Range Estimation (P10 / P50 / P90 percentiles)
        │
        ├── Statistical Confidence Scoring
        │
        └── Firebase Firestore (user prediction history + accuracy tracking)
```

---

## Model

- **Architecture:** Temporal Fusion Transformer (TFT) via the Darts library
- **Training data:** NSE and BSE historical OHLC data from 2000 to present via yfinance
- **Input features:** Log returns of daily closing prices
- **Forecast:** Probabilistic — 200 Monte Carlo samples per prediction
- **Output:** P10 lower bound, P50 median price, P90 upper bound
- **Training:** Google Colab (see `model/New_TFT.ipynb`)
- **Separate models trained for NSE and BSE**

---

## Accuracy

Accuracy is calculated as:

```
Accuracy = (1 - |actual_price - predicted_price| / actual_price) × 100
```

A prediction with 0.15% deviation corresponds to 99.85% accuracy. The platform tracks this for every prediction made by every user against the realized stock price on the target date.

**Average accuracy across tracked predictions: 98.28%**

Separately, **Range Hit** indicates whether the actual stock price fell within the model's predicted confidence interval (lower bound to upper bound) on the target date.

> These metrics are calculated on historical predictions and should not be interpreted as a guarantee of future returns.

---

## Key Features

### Predict any stock
Search any NSE or BSE symbol. Select a target date. Run prediction. Get price range, trend, signal, and confidence score instantly.

### Portfolio OCR scanning
Upload a screenshot of any stock portfolio (Zerodha, Groww, Upstox). OCR extracts ticker symbols automatically and runs predictions on all detected stocks in one shot.

### Accuracy tracking
Every prediction is stored with entry price and target date. When the target date arrives, the actual price is fetched and accuracy is computed automatically via a daily cron job.

### Daily token refresh
Zerodha access tokens expire every 24 hours. A cron job running on the VPS regenerates and updates the token automatically every morning so the app stays live without manual intervention.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile app | Flutter (Android) |
| Backend | FastAPI (Python) |
| ML framework | Darts (PyTorch) |
| Model | Temporal Fusion Transformer |
| Live prices | Zerodha Kite Connect API |
| Database | Firebase Firestore |
| Auth | Firebase Auth |
| Hosting | Hostinger VPS |
| Domain | drishtixveda.com |
| OCR | Tesseract via pytesseract + OpenCV |

---

## Repo Structure

```
drishtixveda/
├── lib/                  # Flutter app source code
├── android/              # Android build config
├── model/
│   └── New_TFT.ipynb     # TFT model training notebook (Google Colab)
├── app.py                # FastAPI backend — main application
├── auth.py               # Authentication logic
├── cron_update.py        # Daily cron: token refresh + actual price updates
├── generate_token.py     # Zerodha token generation
├── utils/
│   ├── ppo_policy.py     # PPO policy utilities
│   ├── prophet_trend.py  # Prophet trend analysis
│   └── zerodha.py        # Zerodha API helpers
├── requirements.txt      # Python dependencies
└── .env.example          # Environment variable template
```

---

## Environment Variables

Copy `.env.example` to `.env` and fill in your values:

```
KITE_API_KEY=your_zerodha_api_key_here
KITE_ACCESS_TOKEN=your_zerodha_access_token_here_refreshed_daily_via_cron
```

Firebase credentials are loaded from `serviceAccountKey.json` (not included in repo — kept on VPS only).

---

## Setup

```bash
# Clone the repo
git clone https://github.com/MAasrithaPadmini/drishtixveda.git

# Backend
pip install -r requirements.txt
uvicorn app:app --reload

# Flutter
cd lib
flutter pub get
flutter run
```

---

## Engineering Decisions

### Why portfolio OCR instead of direct Zerodha multi-user login

The original design allowed users to connect their own Zerodha accounts directly 
through Kite Connect OAuth — so the app could fetch their live portfolio holdings 
automatically.

In March 2026, Zerodha rejected the multi-user access request. Their policy requires 
a SEBI Research Analyst (RA) licence for platforms serving multiple retail users 
through a single Kite Connect app. As a student without an RA licence, that path 
was closed.

Instead of dropping the portfolio feature, I built OCR-based portfolio scanning.
Users screenshot their holdings from any broker app — Zerodha, Groww, Upstox, 
Angel One — and upload it. Tesseract extracts ticker symbols automatically via 
OpenCV preprocessing, validates them against the full NSE/BSE instrument list, 
and runs TFT predictions on every detected stock in one shot.

The result is broker-agnostic. No OAuth dependency, no licence requirement, 
works with any Indian broker app.

### Why async news calls after the presentation crash

During the final year project presentation, a news API integration added the 
night before caused the entire FastAPI server to crash under load. The news 
feed was making synchronous HTTP calls on the main prediction thread — when 
the external API timed out, it blocked and killed the server.

Fixed by moving all external API calls to async background tasks. A failed 
news request now never touches the prediction pipeline.

Built by [Aasritha Padmini](https://github.com/MAasrithaPadmini) — final year project turned live product.
