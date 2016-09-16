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

os.chdir('/Users/hhooi/Work/personal/hanstox')

class Quote:
    Weights = [1/15.0, 2/15.0,3/15.0,4/15.0,5/15.0]

    def __init__(self, quote):
        self.quote = quote
        self.load_csv_files(self.quote)

    def load_data(self, filepath, quote):
        ratios = p.read_csv(filepath, sep="\t", na_values=["?"])
        ratios.pDate = p.to_datetime(ratios.Date)
        ratios.index = ratios.pDate
        return ratios
            
    def load_csv_files(self, quote):
        self.raw_close, self.close = self.read_close(quote)        
        
        #Yearly stats
        self.raw_ratios = self.load_data("data/raw/morningstar/key_ratios/%s.csv" % (quote), quote)
        self.raw_financials = self.load_data("data/raw/morningstar/financials/%s.csv" % (quote), quote)
        
        #Quarterly stats
        self.raw_fcf = self.load_data("data/raw/fcf/%s.csv" % (quote), quote)
        self.raw_shares_o = self.load_data("data/raw/shares_o/%s.csv" % (quote), quote)
        self.raw_eps = p.read_csv("data/raw/eps/%s.csv" % (quote), sep="\t", na_values=["?","NA","NaN"], quotechar='"', quoting=2, escapechar='\\')
        self.eps, self.padded_eps = self.eps()

    def read_close(self, quote):
        csv = p.read_csv("data/raw/%s.csv" % (quote), sep=",", na_values=["?","NA","NaN"], quotechar='"', quoting=2, escapechar='\\')

        csv.pDate = p.to_datetime(csv.Date)
        fe = csv['Adj. Close']
        fe.index = csv.pDate
        return (csv, fe)

    def max_date(self):
        return max(self.close.index)
        

    def eps(self):
        eps = self.raw_eps.copy()
        eps.pDate = p.to_datetime(eps.Date)
        ep = eps.eps
        ep.index = eps.pDate
        epfill = ep.append(p.Series(ep[-1], index=[self.max_date()]))
        return (ep, epfill.asfreq(BDay(), method='pad'))

    def convert(self,val):
        lookup = {'K': 1000, 'M': 1000000, 'B': 1000000000}
        unit = val[-1]
        try:
            number = float(val[:-1])
            if unit in lookup:
                return lookup[unit] * number
        except ValueError:
            print("Value error %s" % val)
        return val

    def fc(self):
        fc = self.raw_fcf.fcf
        fc.index = self.raw_fcf.pDate
        fc = fc.apply(lambda x: self.convert(x))
        return fc

    def shares(self):
        shares = self.raw_shares_o.shares_o
        shares.index = self.raw_shares_o.pDate
        shares = shares.apply(lambda x: self.convert(x))
        shares_pad = self.pad(shares, shares[-1], self.max_date())
        return shares_pad

    def pad(self,seri, last_value, max_date):
        app = seri.append(p.Series(last_value, index=[max_date]))
        fep = app.asfreq(DateOffset(), method='pad')
        return fep

    def fcf_per_share(self):
        return (self.fc() / self.shares()).dropna()

    def yearly_fcf(self):
        return rolling_sum(self.fcf_per_share(), 4, min_periods=4)

    def yearly_fcf_growth(self):
        past_year_fc = self.yearly_fcf()
        return self.pct_growth(past_year_fc)

    def yearly_eps(self):
        return rolling_sum(self.eps, 4, min_periods=4)

    def yearly_eps_growth(self):
        past_year_eps = self.yearly_eps()
        return self.pct_growth(past_year_eps)

    def weighted_fcf_growth(self):
        fc_growth = self.yearly_fcf_growth()
        # print(fc_growth.tail(5) * Quote.Weights)
        grow = sum(fc_growth.tail(21)[::4].tail(5) * Quote.Weights)
        print("Past 5 year FCF Growth Rate: %.3f" % (grow))
        return grow

    def weighted_eps_growth(self):
        eps_growth = self.yearly_eps_growth()
        # print(eps_growth.tail(5) * Quote.Weights)
        grow = sum(eps_growth.tail(21)[::4].tail(5) * Quote.Weights)
        print("Past 5 year EPS Growth Rate: %.3f" % (grow))
        return grow

    def pct_growth(self, seri):
        return (seri - seri.shift(1)) / seri.shift(1)

    def past_mg_value(self, growth=None):
        sz = self.yearly_eps().index.date.size
        cnt = 0
        df = p.DataFrame()
        for i in self.yearly_eps().index.date[-(sz-20):]:
            cur_date, epsmg, eps_growth, value = self.calculate_mg_value(i)
            ndf = p.DataFrame({'Date': cur_date, 'EPSmg': epsmg, 'EPSmg Growth (%)': eps_growth,'Valuemg': value}, index=[cnt])
            df = df.append(ndf)
            cnt += 1
        df.index = p.to_datetime(df['Date'])
        print(df)
        return df

    def calculate_epsmg(self,yearly_eps):
        return sum(yearly_eps.tail(5) * Quote.Weights)
    
    def calculate_eps_growthmg(self,yearly_eps):
        growth_pct = (yearly_eps - yearly_eps.shift(1)) / yearly_eps.shift(1)
        eps_growth = np.nansum(growth_pct.tail(5) * Quote.Weights)
        safety = 0.75
        safe = eps_growth * safety
        return min(safe * 100, 15)
        
    def calculate_yearly_growth(self, yearly_eps):
        (yearly_eps - yearly_eps.shift(1)) / yearly_eps.shift(1)
        

    def calculate_mg_value(self,cur_date,growth=None):
        cur_dt = p.to_datetime(cur_date)
        yearly_eps = self.yearly_eps()[cur_dt - datetime.timedelta(days=365*5):cur_dt] #Why does this say 21?
        epsmg = self.calculate_epsmg(yearly_eps)
        eps_growth = growth or self.calculate_eps_growthmg(yearly_eps)
        value = epsmg * (8.5 + 2 * eps_growth)
        #print("Date: %s; EPSmg: %f; EPSmg Growth:%f; Valuemg: %f" % (cur_date, epsmg, eps_growth, value))
        return (cur_date, epsmg, eps_growth, value)

    def add_series(self, df, name, ser):
        padded = self.pad(ser, ser[-1], self.max_date())
        df[name] = padded
        
    def plot_financials_with_fcf(self):
        df = DataFrame({'close' : self.close})
    
        growth = self.calculate_eps_growthmg(self.yearly_fcf())
        print("Plotting financials using growth: %.2f" % growth)
        mg_df = self.past_mg_value(growth=growth)
        self.add_series(df, 'Valuemg Sell', mg_df['Valuemg'] * 1.1)
        self.add_series(df, 'Valuemg Buy', mg_df['Valuemg'] * 0.75)
        sub = df[df['Valuemg Sell'] > -1000].copy()
        sub['mavg_50day'] = rolling_mean(sub.close, 50, min_periods=1).shift(1)
        sub['mavg_200day'] = rolling_mean(sub.close, 200, min_periods=1).shift(1)
        sub.plot()

    def plot_financials(self):
        df = DataFrame({'close' : self.close})
    
        growth = self.calculate_eps_growthmg(self.yearly_eps())
        print("Plotting financials using growth: %.2f" % growth)
        mg_df = self.past_mg_value(growth=growth)
        self.add_series(df, 'Valuemg Sell', mg_df['Valuemg'] * 1.1)
        self.add_series(df, 'Valuemg Buy', mg_df['Valuemg'] * 0.75)
        sub = df[df['Valuemg Sell'] > -1000].copy()
        sub['mavg_50day'] = rolling_mean(sub.close, 50, min_periods=1).shift(1)
        sub['mavg_200day'] = rolling_mean(sub.close, 200, min_periods=1).shift(1)
        sub.plot()
q = Quote("GOOGL")
#print(q.past_mg_value(growth=4.5))
q.plot_financials_with_fcf()







