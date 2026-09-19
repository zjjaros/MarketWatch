document.getElementById("health").innerHTML = "Healthy";
fetch("/prices")
    .then(response => response.json())
    .then(data => {
        document.getElementById("bitcoin-current").innerHTML = "$" + data.BTC;
        document.getElementById("gold-current").innerHTML = "$" + data.Gold;
        updateTrend("BTC", 7, "bitcoin-day", "bitcoin-high", "bitcoin-low", data.BTC);
        updateTrend("Gold", 7, "gold-day", "gold-high", "gold-low", data.Gold);
    });



function updateTrend(asset, days, changeElement, highElement, lowElement, currentElement) {
    document.querySelectorAll(`.${asset}-d`).forEach(element => {
        element.innerHTML = days;
    });
    fetch(`/prices/${asset}/trend?days=${days}`)
        .then(response => {
            if (!response.ok) {
                throw new Error(`HTTP error: ${response.status}`);
            }
            return response.json();
        })
        .then(data => {
            if (data && data.length > 0) {
                let highIndex = 0;
                let lowIndex = 0;

                let tempHigh = data[0][1];
                let tempLow = data[0][1];

                for (let i = 0; i < data.length; i++) {

                    if (data[i][1] > tempHigh) {
                        tempHigh = data[i][1];
                        highIndex = i;
                    }

                    if (data[i][1] < tempLow) {
                        tempLow = data[i][1];
                        lowIndex = i;
                    }
                }

                let percentChange = ((data[0][1] - data[data.length - 1][1]) / data[data.length - 1][1]) * 100;
                let highString = "$" + data[highIndex][1] + " (" + data[highIndex][0] + ")";
                if (currentElement > data[highIndex][1]) {
                    highString = "$" + currentElement + " (now)";
                }
                let lowString = "$" + data[lowIndex][1] + " (" + data[lowIndex][0] + ")";
                if (currentElement < data[lowIndex][1]) {
                    lowString = "$" + currentElement + " (now)";
                }
                if (percentChange < 0) {
                    document.getElementById(changeElement).style.color = "red";
                }
                else {
                    document.getElementById(changeElement).style.color = "green";
                }
                document.getElementById(changeElement).innerHTML =
                    (percentChange >= 0 ? "+" : "") + percentChange.toFixed(2) + "%";

                document.getElementById(highElement).innerHTML =
                    highString;

                document.getElementById(lowElement).innerHTML =
                    lowString;
            }
        })
        .catch(error => {
            console.error("Error retrieving trend:", error);
        });
}