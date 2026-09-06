import requests
from fastapi import FastAPI, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func
from database import get_db
from datetime import datetime, timezone
from models import PriceObservation

coinGeckoUrl = "https://api.coingecko.com/api/v3/simple/price"
goldUrl = "https://api.goldprice.dev/v1/prices?symbol=XAU-USD-SPOT"
BTCSymbol = {
    "ids": "bitcoin",
    "vs_currencies": "usd"
}

app = FastAPI()

@app.get("/")
async def health():
    return {"status": "Healthy"}

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
        observation = PriceObservation(
            asset="BTC",
            price=float(data["bitcoin"]["usd"]),
            timestamp=datetime.now(timezone.utc),
            source="CoinGecko"
        )
        db.add(observation)
        db.commit()

    except requests.exceptions.RequestException as e:
        result += ("Network/API Error: " + str(e))
    except ValueError as e:
        result += ("Data Parsing Error:" + str(e))

    try:
        data = requests.get(goldUrl).json()
        gold_price = str(data["symbols"][0]["price"])

        dictPrices.update({"Gold" : gold_price})
        observation = PriceObservation(
            asset="Gold",
            price=float(gold_price),
            timestamp=datetime.now(timezone.utc),
            source="GoldPriceAPI"
        )
        db.add(observation)
        db.commit()

    except Exception as e:
        result += "Gold Data Retrieval Error" + str(e)

    result = dictPrices
    #return result
    return {"message": "Success", "data": result}

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

