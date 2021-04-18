library(tidyverse)
library(lubridate)
library(readxl)
library(highcharter)
library(tidyquant)
library(timetk)
library(tibbletime)
library(quantmod)
library(PerformanceAnalytics)
library(scales)
#Portfolio Analytics Libraries
library(PortfolioAnalytics)
library(ROI)
library(ROI.plugin.quadprog)
library(ROI.plugin.glpk)
library(DEoptim)
library(iterators)
library(fGarch)
library(Rglpk)
library(quadprog)
library(ROI.plugin.symphony)
library(pso)
library(GenSA)
library(corpcor)
library(testthat)
library(nloptr)
library(MASS)
library(robustbase)

#We recommend to clear the environment before every iteration run

#Reading of DAX Information for the predicted period
dax <- read_csv("_GDAXI.INDX.csv", 
                col_types = cols(Date = col_date(format = "%d/%m/%Y"), 
                                 Open = col_skip(), High = col_skip(), 
                                 Low = col_skip(), Close = col_skip(), 
                                 Volume = col_skip())) %>% 
  tk_xts(date_var = Date) %>%
  `colnames<-`("prices")

dax <- dax["2019-12-02/2020-12-02"]

dax_returns <- Return.calculate(dax,
                                method ="discrete") %>%
  na.omit() %>%
  `colnames<-`("DAX Returns")

#Read predicted prices from Python output files
prices <-
  read_csv("predicted1920.csv",
           col_types =
             cols(Date =
                    col_date(format = "%Y-%m-%d"))) %>%
  tk_xts(date_var = date)

prices[prices < 0] <- NA

prices <- prices[,colSums(is.na(prices)) == 0]

symbols <- colnames(prices)

#Calculate returns on predicted stock prices
asset_returns_xts <- Return.calculate(prices,
                                      method ="discrete") %>%
  na.omit()

#Calculate annualized returns of each asset
asset_anual_returns <- Return.annualized(asset_returns_xts)

asset_anual_returns <- data.frame(asset_anual_returns)

asset_anual_returns <- asset_anual_returns[,colSums(is.na(asset_anual_returns)) == 0]

#Selecting top 30 performing stocks
order <- apply(asset_anual_returns, 2, sort, decreasing=TRUE)

order <- data.frame(order)

order <- order %>% arrange(desc(order))

top30 <- head(order,30)

#Calculate predicted annualized returns of top performing stocks
asset_returns_xts <- asset_returns_xts[, rownames(top30),
                                       drop = FALSE]

symbols <- colnames(asset_returns_xts)

#Creating an equal-weighted portfolio
w <- rep(1/ncol(asset_returns_xts),ncol(asset_returns_xts))

#Check portfolio weights equal 1
tibble(w,symbols) %>%
  summarise(total_weight = sum(w))

#Create equal weights portfolio
equal_weights_portfolio <- 
  Return.portfolio(asset_returns_xts,
                   weights = w) %>%
  `colnames<-`("Equal Weights Portfolio Returns")

equal_portfolio_returns <- table.AnnualizedReturns(equal_weights_portfolio)

#Calculate beta and Jensen´s alpha of the predicted data portfolio
beta <- CAPM.beta(equal_weights_portfolio,
                  dax_returns,
                  Rf = 0.0001)

beta <- data.frame(beta, row.names = "CAPM Beta")      

names(beta) <- c("Equal Weights Portfolio Returns")  

jensen_alpha <- CAPM.jensenAlpha(equal_weights_portfolio,
                                 dax_returns,
                                 Rf = 0.0001)

jensen_alpha <- data.frame(jensen_alpha, row.names = "Jensen Alpha")  

names(jensen_alpha) <- c("Equal Weights Portfolio Returns")  

#Save the results of the predicted data on a CSV file
equal_portfolio_returns <- rbind(equal_portfolio_returns, beta, jensen_alpha)  

write.csv(equal_portfolio_returns,"Equal Weight Portfolio Returns on Predicted Data 19-20.csv", row.names = TRUE)

#Create a portfolio object to be optimized
optimized_portfolio <- portfolio.spec(symbols)

#Add constraints to the portfolio
optimized_portfolio <- 
  add.constraint(optimized_portfolio,
                 type = "weight_sum",
                 min_sum = .99,
                 max_sum = 1.01)

optimized_portfolio <- 
  add.constraint(optimized_portfolio,
                 type = "box",
                 min = .005,
                 max = 0.5)

optimized_portfolio <- 
  add.objective(optimized_portfolio,
                type = "return",
                name ="mean")

optimized_portfolio <- 
  add.objective(optimized_portfolio,
                type = "risk",
                name ="StdDev")

#Optimized the newly constrained portfolio
optimized_portfolio_final <-
  optimize.portfolio(asset_returns_xts,
                     optimized_portfolio,
                     optimize_method='ROI',
                     trace = TRUE)    

opt_fin <- optimize.portfolio(asset_returns_xts, 
                              optimized_portfolio,
                              optimize_method = "ROI",
                              trace = TRUE)

#Obtain the new optimized weights
rebal_weights <- extractWeights(opt_fin)

rebal_returns <- Return.portfolio(asset_returns_xts, 
                                  weights = rebal_weights)

returns_df <- cbind(rebal_returns, 
                    equal_weights_portfolio,
                    dax_returns)

#Testing the strategy on real data

#Read historical prices from Python output files
real_prices <-
  read_csv("historical1920.csv",
           col_types =
             cols(Date =
                    col_date(format = "%Y-%m-%d"))) %>%
  tk_xts(date_var = date)

real_prices <- real_prices[,colnames(real_prices) %in% symbols]

delete.na <- function(DF, n=0) {
  DF[rowSums(is.na(DF)) <= n,]
}

real_prices= delete.na(real_prices,10)

#Calculate returns on historical stock prices
real_returns_xts <- Return.calculate(real_prices,
                                     method ="discrete") %>%
  na.omit()

#Create a portfolio object using the previously calculated optimal weights
optimized_portfolio <- 
  Return.portfolio(real_returns_xts,
                   weights = rebal_weights,
  ) %>%
  `colnames<-`("Real Portfolio Returns")

real_portfolio_returns <- table.AnnualizedReturns(optimized_portfolio)

#Calculate beta and Jensen´s alpha of the predicted data portfolio
beta <- CAPM.beta(optimized_portfolio,
                  dax_returns,
                  Rf = 0.0001)

beta <- data.frame(beta, row.names = "CAPM Beta")      

names(beta) <- c("Real Portfolio Returns")  

jensen_alpha <- CAPM.jensenAlpha(optimized_portfolio,
                                 dax_returns,
                                 Rf = 0.0001)

jensen_alpha <- data.frame(jensen_alpha, row.names = "Jensen Alpha")  

names(jensen_alpha) <- c("Real Portfolio Returns")  

real_portfolio_returns <- rbind(real_portfolio_returns, beta, jensen_alpha)  

#Save the results of the real data on a CSV file
write.csv(real_portfolio_returns,"Portfolio Returns on Real Data 19-20.csv", row.names = TRUE)

print(optimized_portfolio_final[["weights"]])

print(real_portfolio_returns)

returns_df <- cbind(optimized_portfolio,
                    dax_returns)
charts.PerformanceSummary(returns_df,
                          main = "Returns on Real Data")