# Investment-strategy-and-evaluation

Investment Strategy:
The strategy utilizes linear regression to predict the prices of stocks one year in the future. To do so,
it uses all the historical adjusted closing price data available except for the prediction year, and then
it fits a model. The result is a set of predicted prices for the following year. Using these predicted
prices, the predicted returns are calculated, and a portfolio of the top 30 performing stocks is created.
Afterward, the individual weights of stocks in the portfolio are calculated by optimizing for maximum
returns and minimum risk. Finally, this new portfolio is tested with the actual data.

Python:
The first inputs are the required dates for historical data (training data) and the prediction period. In
the case of a prediction from 02-12-2019 to 02-12-2020, all historical data of the adjusted closing
prices available from 31-12-1987 to 01-12-2019 is used to fit a model. The pandas market calendar
library was used to merge the data with future trading dates. Stocks containing less than one year of
data were dropped, as it was not enough to create a prediction. The code creates two csv files that
contain the predicted prices on its trading days and the historical data, which is the real data used to
test the model.

R:
1. The DAX Information about the test period is stored in a data frame to be used as a benchmark.
2. The predicted stock prices for the period are read from the Python files, their annual returns
calculated, and the top 30 stocks are selected.
3. The Portfolio Analytics package optimizes the portfolio’s individual stock weights.
4. Our portfolio of 30 selected stocks with optimized weights is tested on the real data.
5. The returns of the new portfolio are saved on the file “Portfolio Returns on Real Data.”
6. The returns are compared to the benchmark data of the DAX, and Jensen’s alpha is calculated.
