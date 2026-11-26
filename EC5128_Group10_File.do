*****
* EC5128 Group Practical Assignment
* Group 10
* Babcock International Group plc
* Babcock's Yahoo ticker, plus the FTSE 100's
* 17 Nov 2026
*****

************************************************
* DATA: download, save and prepare
************************************************
clear all

* Set Stata's working folder to the folder where you want to save the raw data.
* Download daily adjusted closing prices from Yahoo Finance, 1 Oct 2016 to 30 Sep 2026.
getsymbols ^FTSE BAB.L, fd(1) fm(10) fy(2016)  ld(30) lm(9) ly(2026) freq(d) yahoo clear price(adjclose)

* Save a copy of the raw data (Stata format and CSV)
save babcock_ftse_raw, replace
export delimited using babcock_ftse_raw.csv, replace

* Missing data check: the FTSE 100 price is missing on 22 Dec 2020 (left as missing)
list if missing(p_adjclose__FTSE )

* Trading-day time index: weekends are not treated as zero-return days;
* the calendar date (period) is kept for graphs and day-of-the-week analysis
sort period
generate trading_day = _n
tsset trading_day

************************************************
* QUESTION 1: Exploring the data
************************************************

* Daily log returns: ln(P_t) - ln(P_t-1)
generate return_bab = ln(p_adjclose_BAB_L) - ln(L.p_adjclose_BAB_L)
generate return_ftse = ln(p_adjclose__FTSE) - ln(L.p_adjclose__FTSE)

* Check: our log returns match the log returns created by getsymbols (r_)
summarize return_bab r_BAB_L return_ftse r__FTSE

* Figure 1.1: Babcock adjusted closing price
twoway line p_adjclose_BAB_L period, title("Babcock: Daily Adjusted Closing Price") ytitle("Price (pence)") xtitle("Date") xlabel(#10, format(%tdCCYY)) ylabel(200(200)1600)

* Figure 1.2: FTSE 100 closing level
twoway line p_adjclose__FTSE  period, title("FTSE 100: Daily Adjusted Closing Level") ytitle("Index Level (points)") xtitle("Date") xlabel(#10, format(%tdCCYY))

* Figure 1.3: Babcock daily log return
twoway line return_bab  period, title("Babcock Daily Log Return") ytitle("Log Return (in decimal)") xtitle("Date") xlabel(#10, format(%tdCCYY)) ylabel(-.2(.1).3)

* Figure 1.4: FTSE 100 daily log return
twoway line return_ftse  period, title("FTSE 100 Daily Log Return") ytitle("Log Return (in decimal)") xtitle("Date") xlabel(#10, format(%tdCCYY)) ylabel(-.2(.1).3)

* Unusual observations: Babcock days with a move larger than 15%
list period return_bab return_ftse if abs(return_bab) > 0.15 & !missing(return_bab)

* Summary statistics on the common sample (days where both returns exist, N = 2,522)
summarize return_bab return_ftse if !missing(return_bab, return_ftse)

************************************************
* QUESTION 2: Market model
************************************************

* OLS market model: Babcock return on FTSE 100 return (Table 2.1)
regress return_bab return_ftse

* Q2(3): test whether beta equals 1 (H0: beta = 1)
test return_ftse = 1

************************************************
* QUESTION 3: Day-of-the-week effects
************************************************

* Weekday variable: dow() gives 0 = Sunday ... 6 = Saturday; only 1 (Mon) to 5 (Fri) appear
gen weekdays = dow(period)

* Number of observations on each weekday
tab weekdays

* Market model with weekday dummies; Monday (1) is the omitted reference category (Table 3.1)
regress return_bab return_ftse i.weekdays

* Joint F-test: H0: Tuesday to Friday coefficients are all zero
test 2.weekdays 3.weekdays 4.weekdays 5.weekdays

************************************************
* QUESTION 4: Model diagnostics
************************************************

* Re-estimate the Question 3 model and save residuals and fitted values
reg return_bab return_ftse i.weekdays
predict u, residuals
predict yhat, xb

* Heteroskedasticity: residuals vs fitted values graph
rvfplot, yline(0) title("Residuals vs Fitted Values") ytitle("Residual") xtitle("Fitted value")


* Heteroskedasticity: Breusch-Pagan test (H0: constant variance)
estat hettest, iid

* Heteroskedasticity: White's test (H0: homoskedasticity)
estat imtest, white

* --- Autocorrelation ---
* Re-estimate the Question 3 model so the tests below use it
reg return_bab return_ftse i.weekdays

* Graph: residuals over time (look for waves or zig-zags)
twoway line u period, title("Residuals Over Time") ytitle("Residual") xtitle("Date") xlabel(#10, format(%tdCCYY))

* Graph: today's residual against yesterday's residual (a sloping cloud = autocorrelation)
scatter u L.u

* Durbin-Watson test: first-order autocorrelation only (DW close to 2 = no autocorrelation)
estat dwatson

* Breusch-Godfrey test, 1 lag (yesterday); H0: no autocorrelation
estat bgodfrey, lags(1) nomiss0

* Breusch-Godfrey test, 5 lags (one trading week); H0: no autocorrelation
estat bgodfrey, lags(5) nomiss0

* --- Distribution of the residuals ---
* Histogram of residuals with a normal curve on top
hist u, normal title("Distribution of Residuals") xtitle("Residual") ytitle("Density")

* Jarque-Bera test (H0: residuals are normal), if jb is installed
capture which jb
if _rc == 0 {
    jb u
}

* Skewness and kurtosis test (another normality test)
sktest u

* Skewness and kurtosis values
summarize u, detail

* --- Functional form ---
* Re-estimate the Question 3 model
reg return_bab return_ftse i.weekdays

* Ramsey RESET test (H0: no omitted variables / functional form is correct)
estat ovtest

* --- Response: robust standard errors ---
* Q3 model with White's heteroskedasticity-robust standard errors
reg return_bab return_ftse i.weekdays, robust

* Re-test: is beta different from 1? (robust SEs)
test return_ftse = 1

* Re-test: joint F-test of the weekday dummies (robust SEs)
test 2.weekdays 3.weekdays 4.weekdays 5.weekdays

* Check: Newey-West standard errors (5 lags); force handles the 22-23 Dec 2020 gap
newey return_bab return_ftse i.weekdays, lag(5) force

test 2.weekdays 3.weekdays 4.weekdays 5.weekdays

* --- Preferred final specification ---
* Market model without weekday dummies (weekdays jointly insignificant), White robust SEs
reg return_bab return_ftse, robust

* Is beta different from 1? (robust SEs)
test return_ftse = 1

* Robustness check: Newey-West SEs (5 lags); force handles the 22-23 Dec 2020 gap
newey return_bab return_ftse, lag(5) force

************************************************
* QUESTION 5: Stationarity
************************************************

* --- Part 2: 80:20 training/test split ---
* Training = first 80% of Babcock returns (trading_day 2 to 2,020); test = final 20% (2,021 to 2,525)
gen train = (trading_day <= 2020)
gen test  = (trading_day >= 2021)

* Check the sample sizes: should be 2,019 and 505
count if train == 1 & !missing(return_bab)
count if test == 1 & !missing(return_bab)

* Check the split dates: 1 Oct 2024 (last training day) and 2 Oct 2024 (first test day)
list period trading_day if trading_day == 2020 | trading_day == 2021

* Figure 5.1: Babcock adjusted closing price, training sample
twoway line p_adjclose_BAB_L period if train == 1, title("Babcock Adjusted Closing Price (Training Sample)") ytitle("Price (pence)") xtitle("Date") xlabel(#8, format(%tdCCYY))

* Figure 5.2: Babcock daily log return, training sample
twoway line return_bab period if train == 1, title("Babcock Daily Log Return (Training Sample)") ytitle("Log Return (in decimal)") xtitle("Date") xlabel(#8, format(%tdCCYY))

* --- Dickey-Fuller tests on the training sample (H0: unit root = non-stationary) ---
* Price: constant + trend version (clear downward trend); lags 0, 1, 2
dfuller p_adjclose_BAB_L if train == 1, regress trend lags(0)
dfuller p_adjclose_BAB_L if train == 1, regress trend lags(1)
dfuller p_adjclose_BAB_L if train == 1, regress trend lags(2)

* Return: no constant, no trend version (moves around 0); lags 0, 1, 2
dfuller return_bab if train == 1, regress noconstant lags(0)
dfuller return_bab if train == 1, regress noconstant lags(1)
dfuller return_bab if train == 1, regress noconstant lags(2)

* --- Lag choice: DF regressions by hand on the same sample (trading_day >= 5), then AIC/BIC ---
* Return (no constant): lags 0, 1, 2
reg D.return_bab L.return_bab if train == 1 & trading_day >= 5, noconstant
estat ic
reg D.return_bab L.return_bab L(1/1)D.return_bab if train == 1 & trading_day >= 5, noconstant
estat ic
reg D.return_bab L.return_bab L(1/2)D.return_bab if train == 1 & trading_day >= 5, noconstant
estat ic

* Price (constant + trend; trading_day is the trend term): lags 0, 1, 2
reg D.p_adjclose_BAB_L L.p_adjclose_BAB_L trading_day if train == 1 & trading_day >= 5
estat ic
reg D.p_adjclose_BAB_L L.p_adjclose_BAB_L L(1/1)D.p_adjclose_BAB_L trading_day if train == 1 & trading_day >= 5
estat ic
reg D.p_adjclose_BAB_L L.p_adjclose_BAB_L L(1/2)D.p_adjclose_BAB_L trading_day if train == 1 & trading_day >= 5
estat ic

************************************************
* QUESTION 6: Modelling the conditional mean
************************************************

* Figure 6.1: Babcock return ACF and PACF, training sample
corrgram return_bab if train == 1 & !missing(return_bab), lags(20)
ac return_bab if train == 1 & !missing(return_bab), lags(20) name(q6_acf, replace) ytitle("Autocorrelation") nodraw
pac return_bab if train == 1 & !missing(return_bab), lags(20) name(q6_pacf, replace) ytitle("Partial autocorrelation") nodraw
graph combine q6_acf q6_pacf, cols(2) xcommon ycommon xsize(10) ysize(4) ///
    title("ACF and PACF of Babcock Daily Log Returns") name(q6_figure61, replace)

* Constant mean (ARMA(0,0))
arima return_bab if train == 1 & !missing(return_bab), arima(0,0,0)
estimates store q6_mean
predict q6_resid_mean if train == 1 & !missing(return_bab), residuals
corrgram q6_resid_mean, lags(20)

* AR(1)
arima return_bab if train == 1 & !missing(return_bab), arima(1,0,0)
estimates store q6_ar1
predict q6_resid_ar1 if train == 1 & !missing(return_bab), residuals
corrgram q6_resid_ar1, lags(20)

* AR with lag 14 only
arima return_bab if train == 1 & !missing(return_bab), ar(14)
estimates store q6_ar_l14
predict q6_resid_ar14 if train == 1 & !missing(return_bab), residuals
corrgram q6_resid_ar14, lags(20)

* MA with lag 14 only
arima return_bab if train == 1 & !missing(return_bab), ma(14)
estimates store q6_ma_l14
predict q6_resid_ma14 if train == 1 & !missing(return_bab), residuals
corrgram q6_resid_ma14, lags(20)

* Table 6.1: use the residual ACF at lag 14 and Q(20) p-values above.
* Compare AIC and BIC on the common training sample.
estimates stats q6_mean q6_ar1 q6_ar_l14 q6_ma_l14

************************************************
* QUESTION 7: Can you forecast stock returns?
************************************************

* --- One-step-ahead forecasts ---
* Estimate the selected lag-14 model on the Q5 training sample.
arima return_bab if train == 1 & !missing(return_bab), ar(14)

* Predict on the full series so early test forecasts use the training history.
predict forecast_ar14, xb

* Figure 7.1: compare actual and forecast daily returns in the test sample.
tsline return_bab forecast_ar14 if test == 1, title("Babcock Actual Returns and AR Forecasts") ///
    xtitle("Trading day") ytitle("Daily log return") ///
    legend(label(1 "Actual return") label(2 "Lag-14 AR forecast")) name(q7_figure71, replace)

* --- Forecast errors and RMSE ---
* Forecast error is actual return minus forecast. Evaluate on the test sample.
gen sq_error_ar14 = (return_bab - forecast_ar14)^2 if test == 1
gen sq_error_zero = return_bab^2 if test == 1

* Use the training-sample mean as the constant forecast.
summarize return_bab if train == 1, meanonly
gen forecast_mean = r(mean) if test == 1
gen sq_error_mean = (return_bab - forecast_mean)^2 if test == 1

* Table 7.1: RMSE on the common test sample
summarize sq_error_ar14 if test == 1, meanonly
display "RMSE - AR lag 14: " %9.6f sqrt(r(mean))

summarize sq_error_zero if test == 1, meanonly
display "RMSE - Zero return: " %9.6f sqrt(r(mean))

summarize sq_error_mean if test == 1, meanonly
display "RMSE - Training mean: " %9.6f sqrt(r(mean))

************************************************
* QUESTION 8: Is volatility predictable?
************************************************

* Use the Q6 lag-14 mean model and the same training sample.
arima return_bab if train == 1 & !missing(return_bab), ar(14)
predict q8_resid if train == 1 & !missing(return_bab), residuals

* Figure 8.1: plot the residuals to look for volatility clustering.
tsline q8_resid if train == 1, title("Babcock Lag-14 AR Residuals") ///
    xtitle("Trading day") ytitle("Daily log return residual") name(q8_figure81, replace)

* Use the Class 6 intercept-only regression to test the ARIMA residuals.
* Lag 1 checks the previous trading day. Lags 1 to 5 jointly cover one trading week.
regress q8_resid
estat archlm, lags(1 5)
