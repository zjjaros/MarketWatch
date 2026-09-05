import requests
from fastapi import FastAPI

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
async def current():
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
    return result