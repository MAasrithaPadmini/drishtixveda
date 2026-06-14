from kiteconnect import KiteConnect
from datetime import date, timedelta
import pandas as pd
import os

kite = KiteConnect(api_key=os.getenv("g2w464qxhrntsyh2"))

def set_access_token(token):
    kite.set_access_token(token)

def get_history(instrument_token):
    from_date = date.today() - timedelta(days=365)
    to_date = date.today()

    candles = kite.historical_data(
        instrument_token,
        from_date,
        to_date,
        interval="day"
    )

    df = pd.DataFrame(candles)
    return df[["date", "close"]]
