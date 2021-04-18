
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import csv
import os
from itertools import chain
from datetime import date
from datetime import datetime as DateTime
from sklearn.linear_model import LinearRegression
from sklearn.ensemble import RandomForestClassifier
import pandas_market_calendars as mcal

#reading in and structuring stock data frames
def get (dirPath, startdate, enddate):
    ISIN = [f.split('.')[0] for f in os.listdir(dirPath) if os.path.isfile(os.path.join(dirPath, f))]
    temp = {'ISIN': ISIN}
    data = [pd.read_csv(os.path.join(dirPath, f), sep=',', header =0, names=['Date', 'Open','High', 'Low', 'Close', 'Adjusted_close', 'Volume'], encoding = 'utf-8') for f in os.listdir(dirPath) if os.path.isfile(os.path.join(dirPath, f))]
    df=pd.concat(data, keys=ISIN, names=['ISIN','RowID'])
    df = df.dropna()
    df[["Date"]]=[DateTime.strptime(date, "%Y-%m-%d").date() for date in df['Date']]
    #df.assign(Date=pd.to_datetime(df.Date, errors='coerce'))
    df = df.loc[df["Date"]>startdate]
    df = df.loc[df["Date"]<enddate]
    return (df)

#linear regression for the next n days
def linear_regression(data, n):
    df = data[['Adjusted_close']] 
    df['Prediction'] = df[['Adjusted_close']].shift(-n)
    X = np.array(df.drop(['Prediction'],1))[:-n]
    y = np.array(df['Prediction'])[:-n]
    lr = LinearRegression()
    lr.fit(X, y)
    x_forecast = np.array(df.drop(['Prediction'],1))[-n:] 
    lr_prediction = lr.predict(x_forecast)
    return(lr_prediction)

#dropping columns that do not have at least 2*n rows
def drop_data(df, n):
    for ISIN in list(set( df.index.get_level_values(0).tolist())):
        if len(df.loc[ISIN].index) < 2*n:
            df=df.drop(ISIN)
    return(df)

#getting predicted data for n days
def prediction(df,n):
    data = pd.DataFrame(list(range(n)), columns=['Date'])
    df = drop_data(df, n) 
    for ISIN in list(set(df.index.get_level_values(0).tolist())):
        data[ISIN]=linear_regression(df.loc[ISIN], n).tolist()
    return data

#get dates for the next n trading days
def get_trading_days(df, startdate, enddate):
    #Creating prediction trading year
    xetra = mcal.get_calendar('XETR')
    trading_yr = xetra.schedule(start_date=startdate, end_date=enddate) 
    mcal.date_range(trading_yr, frequency='1D')
    trading_yr['market_open'] = pd.to_datetime(trading_yr['market_open']).dt.date
    trading_yr = trading_yr.drop(columns=['market_close'])
    return(trading_yr)

#Input:
##path: Path where the historical stock data can be found
##date1: first day of historical training data 
##date2: first day of predicted prices (one day after last date of historical training data)
##date3: last day of  predicted prices
##testdata: if True a dataframe with the real observed prices for the predicted period will be saved (for testing the model)
def get_prediction_dataset(path, date1, date2, date3, testdata=True):
    #get historical data
    df = get(path,date1, date2)
    #get future trading dates
    trading_dates = get_trading_days(df, date2, date3)
    #create predictions
    df=prediction(df, n=len(trading_dates["market_open"]))
    df["Date"]= [Date for Date in  trading_dates["market_open"]]
    #save predictions as .csv file
    df.to_csv(r'predicted1920.csv', index=False)
    #save real dataset for testing
    if testdata:
        test_df = get(path,date2, date3)
        # converting historical data to wide csv format
        test_df = test_df.reset_index(level=[0])
        test_df = test_df.set_index("Date")
        test_df= test_df.drop(columns=['Open','High', 'Low', 'Close', 'Volume'])
        test_df = test_df.pivot(columns='ISIN', values='Adjusted_close')
        test_df.to_csv(r'historical1920.csv', index= True)

get_prediction_dataset(r"../1.- raw_data/daily_stock_data_germany", date(1987, 12, 31), date(2019,12,2), date(2020,12,2))


## It will create two csv files : 'predicted1920.csv' contains predicted prices for one year in future using all historical data previous to that year
## and 'historical1920.csv' contains actual observed prices for that year. These files are required to run further code in R.
