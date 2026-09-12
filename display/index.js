document.getElementById("health").innerHTML = "Healthy";
fetch("/prices")
    .then(response => response.json())
    .then(data => {
        document.getElementById("bitcoin-current").innerHTML = "$" + data.BTC;
        document.getElementById("gold-current").innerHTML = "$" + data.Gold;
    });

updateTrend("BTC", 7, "bitcoin-day", "bitcoin-high", "bitcoin-low");
updateTrend("Gold", 7, "gold-day", "gold-high", "gold-low");

function updateTrend(asset, days, changeElement, highElement, lowElement) {
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

                let percentChange = ((data[data.length - 1][1] - data[0][1]) / data[0][1]) * 100;
                let sign="+";
                if ((data[data.length - 1][1] - data[0][1]) < 0) {
                    document.getElementById(changeElement).style.color = "red";
                    sign = "-";
                }
                else {
                    document.getElementById(changeElement).style.color = "green";
                }
                document.getElementById(changeElement).innerHTML =
                    sign + percentChange.toFixed(2) + "%";

                document.getElementById(highElement).innerHTML =
                    "$" + data[highIndex][1] + " (" + data[highIndex][0] + ")";

                document.getElementById(lowElement).innerHTML =
                    "$" + data[lowIndex][1] + " (" + data[lowIndex][0] + ")";
            }
        })
        .catch(error => {
            console.error("Error retrieving trend:", error);
        });
}