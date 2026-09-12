import requests
from fastapi import FastAPI, Depends
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.database import get_db
from datetime import datetime, timedelta, timezone
from app.models import PriceObservation

coinGeckoUrl = "https://api.coingecko.com/api/v3/simple/price"
goldUrl = "https://api.goldprice.dev/v1/prices?symbol=XAU-USD-SPOT"
BTCSymbol = {
    "ids": "bitcoin",
    "vs_currencies": "usd"
}

app = FastAPI()
app.mount("/display", StaticFiles(directory="display"), name="display")

@app.get("/")
async def health():
    app.mount("/display", StaticFiles(directory="display"), name="display")
    return FileResponse("display/index.html")

@app.get("/prices")
async def current(db: Session = Depends(get_db)):
    result = ""
    dictPrices = {}
    try:
        response = requests.get(coinGeckoUrl, params=BTCSymbol, timeout=5)
        response.raise_for_status()
        data = response.json()

        if "bitcoin" not in data or "usd" not in data["bitcoin"]:
            result += "Error: Unexpected API Response"

        dictPrices.update({"BTC":str(float(data["bitcoin"]["usd"]))})

    except requests.exceptions.RequestException as e:
        result += ("Network/API Error: " + str(e))
    except ValueError as e:
        result += ("Data Parsing Error:" + str(e))

    try:
        data = requests.get(goldUrl).json()
        gold_price = str(data["symbols"][0]["price"])

        dictPrices.update({"Gold" : gold_price})

    except Exception as e:
        result += "Gold Data Retrieval Error" + str(e)

    result = dictPrices
    #return result
    return result

@app.get("/prices/{asset}/history")
async def assetHistory(asset: str, db: Session = Depends(get_db), limit: int = None):
    try:
        observations = db.query(PriceObservation).filter(func.lower(PriceObservation.asset) == asset.lower()).limit(limit).all()
        result = []
        for obs in observations:
            result.append({
                "id": obs.id,
                "asset": obs.asset,
                "price": obs.price,
                "timestamp": obs.timestamp.isoformat(),
                "source": obs.source
            })
        return result
    except Exception as e:
        return {"message": f"Error retrieving {asset} price history", "error": str(e)}

@app.get("/prices/{asset}/trend")
async def assetTrend(asset: str, db: Session = Depends(get_db), days: int = None):
    try:
        if days:
            cutoff = (datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=days))
        else:
            cutoff = (datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(weeks=260))

        print(cutoff)

        observations = db.query(PriceObservation).filter(func.lower(PriceObservation.asset) == asset.lower()).order_by(PriceObservation.timestamp.desc()).where(PriceObservation.timestamp >= cutoff).all()

        prices = []

        for ob in observations:
            prices.append([ob.timestamp, ob.price])

        return prices
    except Exception as e:
        return {"message": f"Error determining trend for {asset}", "error": str(e)}