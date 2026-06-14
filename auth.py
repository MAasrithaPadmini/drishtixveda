from fastapi import APIRouter, HTTPException
from kiteconnect import KiteConnect
import os

router = APIRouter()

API_KEY = os.getenv("KITE_API_KEY")
API_SECRET = os.getenv("KITE_API_SECRET")

kite = KiteConnect(api_key=API_KEY)

@router.post("/zerodha/connect")
def zerodha_connect(request_token: str):
    try:
        data = kite.generate_session(
            request_token=request_token,
            api_secret=API_SECRET
        )
        kite.set_access_token(data["access_token"])

        return {"status": "Zerodha connected"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
