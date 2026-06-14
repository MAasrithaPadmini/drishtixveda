from kiteconnect import KiteConnect
import os

kite = KiteConnect(api_key=os.getenv("KITE_API_KEY"))
kite.set_access_token(os.getenv("KITE_ACCESS_TOKEN"))

instruments = kite.instruments("NSE")

# find RELIANCE as test
for i in instruments:
    if i["tradingsymbol"] == "RELIANCE":
        print(i["instrument_token"])
        break
