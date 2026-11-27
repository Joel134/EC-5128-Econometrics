*****
* EC5128 Group Practical Assignment
* Group 10
* Babcock International Group plc (BAB.L) and the FTSE 100 (^FTSE)
* 17 Nov 2026
*****

clear all

* Download daily adjusted closing prices from Yahoo Finance, 1 Oct 2016 to 30 Sep 2026
getsymbols ^FTSE BAB.L, fd(1) fm(10) fy(2016)  ld(30) lm(9) ly(2026) freq(d) yahoo clear price(adjclose)

* Save a copy of the raw data
save babcock_ftse_raw, replace
export delimited using babcock_ftse_raw.csv, replace

* Missing data: FTSE 100 price is missing on 22 Dec 2020 (left as missing)
list if missing(p_adjclose__FTSE )

* The date period is kept for graphs and weekdays.
sort period
generate trading_day = _n
tsset trading_day

* QUESTION 1

* Get daily log returns
generate return_bab = ln(p_adjclose_BAB_L) - ln(L.p_adjclose_BAB_L)
generate return_ftse = ln(p_adjclose__FTSE) - ln(L.p_adjclose__FTSE)

* summarizes the table
summarize return_bab r_BAB_L return_ftse r__FTSE

* Figure 1.1 Babcock price
twoway line p_adjclose_BAB_L period, title("Babcock: Daily Adjusted Closing Price") ytitle("Price (pence)") xtitle("Date") xlabel(#10, format(%tdCCYY)) ylabel(200(200)1600)

* Figure 1.2 FTSE 100 level
twoway line p_adjclose__FTSE  period, title("FTSE 100: Daily Adjusted Closing Level") ytitle("Index Level (points)") xtitle("Date") xlabel(#10, format(%tdCCYY))

* Figure 1.3 Babcock returns
twoway line return_bab  period, title("Babcock Daily Log Return") ytitle("Log Return (in decimal)") xtitle("Date") xlabel(#10, format(%tdCCYY)) ylabel(-.2(.1).3)

* Figure 1.4 FTSE 100 returns
twoway line return_ftse  period, title("FTSE 100 Daily Log Return") ytitle("Log Return (in decimal)") xtitle("Date") xlabel(#10, format(%tdCCYY)) ylabel(-.2(.1).3)

* Days when Babcock moved more than 15%
list period return_bab return_ftse if abs(return_bab) > 0.15 & !missing(return_bab)

* Summary statistics on days where both returns exist (N = 2,522)
summarize return_bab return_ftse if !missing(return_bab, return_ftse)


* QUESTION 2

* regression
regress return_bab return_ftse

test return_ftse = 1


* QUESTION 3
gen weekdays = dow(period)
tab weekdays

* Market model Monday taken as base
regress return_bab return_ftse i.weekdays

test 2.weekdays 3.weekdays 4.weekdays 5.weekdays

* QUESTION 4: Model diagnostics
reg return_bab return_ftse i.weekdays
predict u, residuals
predict yhat, xb

* Heteroskedasticity
rvfplot, yline(0) title("Residuals vs Fitted Values") ytitle("Residual") xtitle("Fitted value")
estat hettest, iid
estat imtest, white

* Autocorrelation
reg return_bab return_ftse i.weekdays
twoway line u period, title("Residuals Over Time") ytitle("Residual") xtitle("Date") xlabel(#10, format(%tdCCYY))
scatter u L.u
estat dwatson
estat bgodfrey, lags(1) nomiss0
estat bgodfrey, lags(5) nomiss0

* Normality
hist u, normal title("Distribution of Residuals") xtitle("Residual") ytitle("Density")
jb u
sktest u
summarize u, detail

* Functional form
reg return_bab return_ftse i.weekdays
estat ovtest

* Response
reg return_bab return_ftse i.weekdays, robust
test return_ftse = 1
test 2.weekdays 3.weekdays 4.weekdays 5.weekdays

* Newey-West check 
* force because 22-23 Dec 2020 data are missing from yahoo finance
newey return_bab return_ftse i.weekdays, lag(5) force
test 2.weekdays 3.weekdays 4.weekdays 5.weekdays
reg return_bab return_ftse, robust
test return_ftse = 1
newey return_bab return_ftse, lag(5) force

* QUESTION 5 Stationarity
gen train = (trading_day <= 2020)
gen test  = (trading_day >= 2021)
count if train == 1 & !missing(return_bab)
count if test == 1 & !missing(return_bab)
list period trading_day if trading_day == 2020 | trading_day == 2021

* Figure 5.1 price, training sample
twoway line p_adjclose_BAB_L period if train == 1, title("Babcock Adjusted Closing Price (Training Sample)") ytitle("Price (pence)") xtitle("Date") xlabel(#8, format(%tdCCYY))

* Figure 5.2 returns, training sample
twoway line return_bab period if train == 1, title("Babcock Daily Log Return (Training Sample)") ytitle("Log Return (in decimal)") xtitle("Date") xlabel(#8, format(%tdCCYY))

* Dickey-Fuller tests(price with constant and trend)
dfuller p_adjclose_BAB_L if train == 1, regress trend lags(0)
dfuller p_adjclose_BAB_L if train == 1, regress trend lags(1)
dfuller p_adjclose_BAB_L if train == 1, regress trend lags(2)
* Dickey-Fuller tests(returns with no constant)
dfuller return_bab if train == 1, regress noconstant lags(0)
dfuller return_bab if train == 1, regress noconstant lags(1)
dfuller return_bab if train == 1, regress noconstant lags(2)

* Lag choice
reg D.return_bab L.return_bab if train == 1 & trading_day >= 5, noconstant
estat ic
reg D.return_bab L.return_bab L(1/1)D.return_bab if train == 1 & trading_day >= 5, noconstant
estat ic
reg D.return_bab L.return_bab L(1/2)D.return_bab if train == 1 & trading_day >= 5, noconstant
estat ic

reg D.p_adjclose_BAB_L L.p_adjclose_BAB_L trading_day if train == 1 & trading_day >= 5
estat ic
reg D.p_adjclose_BAB_L L.p_adjclose_BAB_L L(1/1)D.p_adjclose_BAB_L trading_day if train == 1 & trading_day >= 5
estat ic
reg D.p_adjclose_BAB_L L.p_adjclose_BAB_L L(1/2)D.p_adjclose_BAB_L trading_day if train == 1 & trading_day >= 5
estat ic

* QUESTION 6: ARMA models
* Figure 6.1 ACF and PACF
corrgram return_bab if train == 1 & !missing(return_bab), lags(20)
ac return_bab if train == 1 & !missing(return_bab), lags(20) name(q6_acf, replace) ytitle("Autocorrelation") nodraw
pac return_bab if train == 1 & !missing(return_bab), lags(20) name(q6_pacf, replace) ytitle("Partial autocorrelation") nodraw
graph combine q6_acf q6_pacf, cols(2) xcommon ycommon xsize(10) ysize(4) ///
    title("ACF and PACF of Babcock Daily Log Returns") name(q6_figure61, replace)

* Model 1: constant mean
arima return_bab if train == 1 & !missing(return_bab), arima(0,0,0)
estimates store q6_mean
predict q6_resid_mean if train == 1 & !missing(return_bab), residuals
corrgram q6_resid_mean, lags(20)

* Model 2: AR(1)
arima return_bab if train == 1 & !missing(return_bab), arima(1,0,0)
estimates store q6_ar1
predict q6_resid_ar1 if train == 1 & !missing(return_bab), residuals
corrgram q6_resid_ar1, lags(20)

* Model 3: AR with lag 14 only
arima return_bab if train == 1 & !missing(return_bab), ar(14)
estimates store q6_ar_l14
predict q6_resid_ar14 if train == 1 & !missing(return_bab), residuals
corrgram q6_resid_ar14, lags(20)

* Model 4: MA with lag 14 only
arima return_bab if train == 1 & !missing(return_bab), ma(14)
estimates store q6_ma_l14
predict q6_resid_ma14 if train == 1 & !missing(return_bab), residuals
corrgram q6_resid_ma14, lags(20)

* Table 6.1: AIC and BIC for all four models
estimates stats q6_mean q6_ar1 q6_ar_l14 q6_ma_l14


* QUESTION 7: Forecasting returns
arima return_bab if train == 1 & !missing(return_bab), ar(14)

* forecasting with past returns
predict forecast_ar14, xb

* Figure 7.1 actual returns and forecasts, test sample
tsline return_bab forecast_ar14 if test == 1, title("Babcock Actual Returns and AR Forecasts") ///
    xtitle("Trading day") ytitle("Daily log return") ///
    legend(label(1 "Actual return") label(2 "Lag-14 AR forecast")) name(q7_figure71, replace)

* Squared forecast errors
gen sq_error_ar14 = (return_bab - forecast_ar14)^2 if test == 1
gen sq_error_zero = return_bab^2 if test == 1

* Training-sample mean as a constant forecast
summarize return_bab if train == 1, meanonly
gen forecast_mean = r(mean) if test == 1
gen sq_error_mean = (return_bab - forecast_mean)^2 if test == 1

* Table 7.1 RMSE for each model on the same 505 test days
summarize sq_error_ar14 if test == 1, meanonly
display "RMSE - AR lag 14: " %9.6f sqrt(r(mean))

summarize sq_error_zero if test == 1, meanonly
display "RMSE - Zero return: " %9.6f sqrt(r(mean))

summarize sq_error_mean if test == 1, meanonly
display "RMSE - Training mean: " %9.6f sqrt(r(mean))


* QUESTION 8: Volatility (ARCH effects)
reg return_bab L14.return_bab if train == 1

* ARCHLM tests
estat archlm, lags(1 5)

di invchi2tail(1,0.05)
di invchi2tail(5,0.05)

* Figure 8.1 residuals over time
predict q8_resid if e(sample), residuals
tsline q8_resid if train == 1, title("Babcock Lag-14 AR Residuals") xtitle("Trading day") ytitle("Residual") name(q8_figure81, replace)
