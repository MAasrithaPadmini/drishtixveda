from kiteconnect import KiteConnect

API_KEY = "g2w464qxhrntsyh2"
API_SECRET = "p8q3f8kj0f3xrovft1m2kml07q73dz9o"

kite = KiteConnect(api_key=API_KEY)

print("Login URL:", kite.login_url())
request_token = input("Paste request_token here: ")

data = kite.generate_session(request_token, api_secret=API_SECRET)
print("ACCESS TOKEN:", data["access_token"])
