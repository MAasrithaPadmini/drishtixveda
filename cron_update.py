import firebase_admin
from firebase_admin import credentials, firestore, messaging
from datetime import datetime, timezone
import requests
import time

# =========================
# 🔥 INIT FIREBASE
# =========================
cred = credentials.Certificate("/home/drishtixveda/backend/serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

print("PROJECT:", firebase_admin.get_app().project_id)

# =========================
# 📡 LIVE PRICE
# =========================
def get_live_price(symbol, retries=3):
    url = f"http://127.0.0.1:8000/live_price?symbol={symbol}"

    for i in range(retries):
        try:
            res = requests.get(url, timeout=5)
            if res.status_code == 200:
                price = res.json().get("price")
                if price:
                    return price
        except Exception as e:
            print(f"Retry {i+1} failed for {symbol}: {e}")

        time.sleep(1)

    return None

# =========================
# 🔔 SEND NOTIFICATION
# =========================
def send_notification(token, symbol, predicted, actual, user_id):
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=f"{symbol} Prediction Ready 📊",
                body=f"Predicted: {predicted} | Actual: {actual}",
            ),
            data={
                "symbol": symbol,
                "screen": "stock"
            },
            token=token,
        )

        messaging.send(message)

        # 💾 SAVE TO FIRESTORE
        db.collection("users").document(user_id).collection("notifications").add({
            "symbol": symbol,
            "predicted": predicted,
            "actual": actual,
            "timestamp": firestore.SERVER_TIMESTAMP,
            "read": False
        })

        print("✅ Notification stored")

    except Exception as e:
        print("❌ Notification failed:", e)

# =========================
# 🔥 MAIN CRON FUNCTION
# =========================
def update_actual_prices():
    print("🚀 CRON STARTED")

    users = list(db.collection("users").stream())
    print(f"👤 USERS FOUND: {len(users)}")

    price_cache = {}

    for user in users:
        print(f"➡️ USER ID: {user.id}")

        preds = list(
            db.collection("users")
            .document(user.id)
            .collection("predictions")
            .stream()
        )

        print(f"📊 PREDICTIONS: {len(preds)}")

        for p in preds:
            data = p.to_dict()

            symbol = data.get("symbol")
            target_date = data.get("target_date")

            if not symbol:
                continue

            print(f"🔍 Checking: {symbol}")

            # =========================
            # 🔥 GET PRICE (CACHE)
            # =========================
            if symbol in price_cache:
                actual = price_cache[symbol]
            else:
                actual = get_live_price(symbol)
                price_cache[symbol] = actual

            print(f"{symbol} → {actual}")

            if not actual:
                print(f"❌ Failed for {symbol}")
                continue

            # =========================
            # 📊 DAILY PRICE TRACKING
            # =========================
            now = datetime.now(timezone.utc)

            p.reference.collection("daily_prices").add({
                "price": actual,
                "timestamp": now
            })

            # =========================
            # 🧠 UPDATE DATA
            # =========================
            predicted = data.get("predicted_price")
            entry_price = data.get("entry_price")  # ✅ FIXED
            update_data = {}

            # ✅ latest price (correct)
            update_data["latest_price"] = actual

            # =========================
            # 📈 LIVE ACCURACY (ALWAYS)
            # =========================
            if predicted and actual:
                accuracy = 100 - abs((actual - predicted) / actual * 100)
                update_data["accuracy"] = round(accuracy, 2)

            # =========================
            # 💰 PROFIT (FIXED)
            # =========================
            if entry_price is not None and actual is not None:
                profit = actual - entry_price
                update_data["profit"] = round(profit, 2)

            # =========================
            # 🎯 FINAL ACTUAL (ON TARGET DATE)
            # =========================
            if data.get("actual_price") is None and target_date:
                try:
                    target_dt = datetime.fromisoformat(target_date).date()
                    today = datetime.now().date()

                    if today >= target_dt:
                        update_data["actual_price"] = actual
                        print(f"✅ FINAL UPDATED {symbol}")

                        # 🔔 NOTIFICATION
                        user_doc = db.collection("users").document(user.id).get()
                        user_data = user_doc.to_dict()

                        token = user_data.get("fcm_token")

                        if token:
                            send_notification(
                                token,
                                symbol,
                                predicted,
                                actual,
                                user.id
                            )

                except Exception as e:
                    print(f"Date error: {e}")

            # =========================
            # 🔥 FINAL WRITE
            # =========================
            if update_data:
                p.reference.update(update_data)

# =========================
# ▶ RUN
# =========================
if __name__ == "__main__":
    update_actual_prices()
