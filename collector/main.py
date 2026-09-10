from sqlalchemy.orm import Session
from sqlalchemy import func
from app.database import get_db
from datetime import datetime, timezone
from app.models import PriceObservation
import requests
import time as timer

coinGeckoUrl = "https://api.coingecko.com/api/v3/simple/price"
goldUrl = "https://api.goldprice.dev/v1/prices?symbol=XAU-USD-SPOT"
BTCSymbol = {
    "ids": "bitcoin",
    "vs_currencies": "usd"
}

def collect_prices():
    db = next(get_db())  # Get a database session

    try:
        response = requests.get(coinGeckoUrl, params=BTCSymbol, timeout=5)
        response.raise_for_status()
        data = response.json()

        if "bitcoin" not in data or "usd" not in data["bitcoin"]:
            print("Error: Unexpected API Response")

        observation = PriceObservation(
            asset="BTC",
            price=float(data["bitcoin"]["usd"]),
            timestamp=datetime.now(timezone.utc),
            source="CoinGecko"
        )
        db.add(observation)
        db.commit()

    except requests.exceptions.RequestException as e:
        print("Network/API Error: " + str(e))
    except ValueError as e:
        print("Data Parsing Error:" + str(e))

    try:
        data = requests.get(goldUrl).json()
        gold_price = str(data["symbols"][0]["price"])

        observation = PriceObservation(
            asset="Gold",
            price=float(gold_price),
            timestamp=datetime.now(timezone.utc),
            source="GoldPriceAPI"
        )
        db.add(observation)
        db.commit()

    except Exception as e:
        print("Gold Data Retrieval Error: " + str(e))

while True:
    collect_prices()
    print("Prices collected and stored in the database. Waiting for 5 minutes before the next collection...")
    timer.sleep(300)  

