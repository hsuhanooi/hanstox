# -*- coding: utf-8 -*-
"""
Created on Mon Aug  3 22:54:39 2015

@author: hsooi
"""

from __future__ import print_function

import pandas as p
import numpy as np
from pandas import DataFrame

from pandas.tseries.offsets import BDay
from pandas.tseries.offsets import DateOffset
from pandas.stats.moments import rolling_mean
from pandas.stats.moments import rolling_sum
import matplotlib.pyplot as plt

import os

os.chdir('/Users/hsooi/Work/personal/hanstox')

def pad(seri, last_value, max_date):
    app = seri.append(p.Series(last_value, index=[max_date]))
    fep = app.asfreq(DateOffset(), method='pad')
    return fep
    
Weights = [1/15.0, 2/15.0,3/15.0,4/15.0,5/15.0]
def calculate_epsmg(ser):
    return sum(ser.tail(5) * Weights)

def calculate_eps_growthmg(ser):
    growth_pct = (ser - ser.shift(1)) / ser.shift(1)
    eps_growth = np.nansum(growth_pct.tail(5) * Weights)
    safety = 0.75    
    safe = eps_growth * safety
    return min(safe * 100, 15)

def calculate_mg_value(ser,cur_date,growth=None):
    cur_dt = p.to_datetime(cur_date)
    yearly_eps = ser[:cur_dt].tail(21)[::4] #Why does this say 21?
    epsmg = calculate_epsmg(yearly_eps)
    eps_growth = growth or calculate_eps_growthmg(yearly_eps)
    value = epsmg * (8.5 + 2 * eps_growth)
    print("Date: %s; EPSmg: %f; EPSmg Growth:%f; Valuemg: %f" % (cur_date, epsmg, eps_growth, value))
    return (cur_date, epsmg, eps_growth, value)
    
def calculate_value_no_growth(ser):
    epsmg = calculate_epsmg(ser)
    return epsmg * 8.5
    
def calculate_value_slow_growth(ser):
    epsmg = calculate_epsmg(ser)
    growth = 3 #Guessing 3% growth
    return epsmg * (8.5 + 2 * growth)

def past_mg_value(past_year_eps, growth=None):
    sz = past_year_eps.index.date.size
    cnt = 0
    df = p.DataFrame()
    for i in past_year_eps.index.date[-(sz-20):]:
        cur_date, epsmg, eps_growth, value = calculate_mg_value(past_year_eps, i, growth=growth)
        ndf = p.DataFrame({'Date': cur_date, 'EPSmg': epsmg, 'EPSmg Growth (%)': eps_growth,'Valuemg': value}, index=[cnt])
        df = df.append(ndf)
        cnt += 1
    df.index = df['Date']
    return df
    
def calculate_eps_growth(past_year_eps):
    fc_growth = pct_growth(past_year_eps)
    grow = sum(fc_growth.tail(21)[::4].tail(5) * Weights)
    print("Past 5 year EPS Growth Rate: %f" % (grow))
    return grow
    
    
def calculate_fc_growth(fcf_shares):
    past_year_fc = rolling_sum(fcf_shares, 4, min_periods=4)
    fc_growth = pct_growth(past_year_fc)
    grow = sum(fc_growth.tail(21)[::4].tail(5) * Weights)
    print("Past 5 year FCF Growth Rate: %f" % (grow))
    return grow

def add_series(df, name, ser, max_date):
    padded = pad(ser, ser[-1], max_date)
    df[name] = padded

def convert(val):
    lookup = {'K': 1000, 'M': 1000000, 'B': 1000000000}
    unit = val[-1]
    try:
        number = float(val[:-1])
        if unit in lookup:
            return lookup[unit] * number
    except ValueError:
        print("Value error %s" % val)
    return val
    
def load_data(filepath, quote):
    ratios = p.read_csv(filepath, sep="\t", na_values=["?"])
    ratios.pDate = p.to_datetime(ratios.Date)
    ratios.index = ratios.pDate
    return ratios
    
def read_close(quote):
    csv = p.read_csv("data/raw/%s.csv" % (quote), sep=",", na_values=["?","NA","NaN"], quotechar='"', quoting=2, escapechar='\\')
    #print(csv.info())    
    csv.pDate = p.to_datetime(csv.Date)
    fe = csv['Adj. Close']
    fe.index = csv.pDate
    return fe
    
def plot_fcf_eps(financials):
    financials.iloc[:,[6,14]].plot()    
    
def pct_growth(seri):
    return (seri - seri.shift(1)) / seri.shift(1)

def load_csv_files(quote):
    ratios = load_data("data/raw/morningstar/key_ratios/%s.csv" % (quote), quote)
    financials = load_data("data/raw/morningstar/financials/%s.csv" % (quote), quote)
    
    fcf = load_data("data/raw/fcf/%s.csv" % (quote), quote)
    shares_o = load_data("data/raw/shares_o/%s.csv" % (quote), quote)

    eps = p.read_csv("data/raw/eps/%s.csv" % (quote), sep="\t", na_values=["?","NA","NaN"], quotechar='"', quoting=2, escapechar='\\')
    return (ratios, financials, fcf, eps, shares_o)

def parse_eps(eps, max_date):
    eps.pDate = p.to_datetime(eps.Date)            
    ep = eps.eps
    ep.index = eps.pDate
    epfill = ep.append(p.Series(ep[-1], index=[max_date]))
    return (ep, epfill.asfreq(BDay(), method='pad'))
    
def parse_fcf(fc):
    return 0

def read_quote(quote):
    fe = read_close(quote)
    
    ratios, financials, fcf, eps, shares_o = load_csv_files(quote)

    ep, fep = parse_eps(eps, max(fe.index))

    fc = fcf.fcf
    fc.index = fcf.pDate
    fc = fc.apply(lambda x: convert(x))
    #fc_pad = pad(fc, fc[-1], max(fe.index))
    
    shares = shares_o.shares_o
    shares.index = shares_o.pDate
    shares = shares.apply(lambda x: convert(x))
    shares_pad = pad(shares, shares[-1], max(fe.index))
    #past_year_fcf = rolling_sum(fc, 4, min_periods=4)
    
    fcf_shares = (fc / shares_pad).dropna()
    fcf_growth_rate = calculate_fc_growth(fcf_shares)

    past_year_eps = rolling_sum(ep, 4, min_periods=4)
    calculate_eps_growth(past_year_eps)
    

    #py_fc_pad = pad(past_year_fc, past_year_fc[-1], max(fe.index))    
    fcf_growth_rate = 0.06
    growth=fcf_growth_rate * 0.75 * 100
    mg_df = past_mg_value(past_year_eps, growth=growth)
    
    #past_2year_eps = rolling_sum(ep, 8, min_periods=8)
    #past_3year_eps = rolling_sum(ep, 12, min_periods=12)
    #past_4year_eps = rolling_sum(ep, 16, min_periods=16)
    #past_5year_eps = rolling_sum(ep, 20, min_periods=20)
    
    #past_year_eps_ewma = ewma(ep, span=3, min_periods=4)
    #past_5year_eps_ewma = ewma(ep, span=19, min_periods=20)
    #ep.tshift(1, freq='D') #Need to adjust because earnings happens EOD. Actually you don't dates aren't exact
        
    df = DataFrame({'close' : fe, 'fep': fep})
    
    #df['last_qtr_eps'] = fep
    add_series(df, 'Valuemg Sell', mg_df['Valuemg'] * 1.1, max(fe.index))
    add_series(df, 'Valuemg Buy', mg_df['Valuemg'] * 0.75, max(fe.index))
    sub = df[df['Valuemg Sell'] > -1000].copy()
    sub['mavg_50day'] = rolling_mean(sub.close, 50, min_periods=1).shift(1)
    sub['mavg_200day'] = rolling_mean(sub.close, 200, min_periods=1).shift(1)
    sub.plot()
    
    #sub['ewma_s50'] = ewma(sub.close, span=50)
    #sub['ewma_s20'] = ewma(sub.close, span=20)
    plot_2015(sub, quote)
    return sub

def plot_2015(sub, quote):
    fig = plt.figure()
    cols = ['close', 'Valuemg Sell', 'Valuemg Buy', 'mavg_50day', 'mavg_200day']
    plt.plot(sub[cols])
    fig.suptitle("Quote %s" % (quote), fontsize=20)
    plt.ylabel('$', fontsize=16)
    plt.savefig("plots/%s.png" % (quote))
    

#aapl = read_quote("AAPL")
fb = read_quote("ATVI")
#amzn = read_quote("AMZN")
#msft = read_quote("MSFT")

#plot_2015(aapl, 'AAPL')
#plot_2015(fb, 'FB')
#plot_2015(amzn, 'AMZN')
