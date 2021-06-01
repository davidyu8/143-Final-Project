*******************************************************************************
*			Analysis of FoodAPS Data
*******************************************************************************

version 16
set more off, permanently
clear all
capture log close
set linesize 255

global project "//Client/C$/Users/david/Documents/UCLA/2020-2021/Spring Course Materials/Econ 143"
global data "$project/CSV data files"
cd "$data"

ssc install estout

log using "$project/output.log", replace

*******************************************************************************
*			Set Up Data
*******************************************************************************

/* import delimited "$data/faps_household_puf.csv"
keep hhnum hhsize inchhavg_r
save "$project/temp_household.dta", replace */

/* import delimited "$data/faps_fahevent_puf.csv"
keep eventid hhnum placetype totalpaid cash itemstot placedist_d placedist_s placedist_w
save "$project/temp_fahevent.dta", replace */

/* clear
use "$project/temp_household.dta"
merge 1:m hhnum using "$project/temp_fahevent.dta"
save "$project/core.dta", replace */

*******************************************************************************
*			Load and Clean Data
*******************************************************************************

clear
use "$project/core.dta"

* remove low-quality observations
drop if cash == -996
drop if _merge == 1
drop if placedist_d == -996
drop if totalpaid == . | placedist_d == . | cash == . | itemstot == .

rename totalpaid bill
rename inchhavg_r inc
rename itemstot items

keep if placetype == 102 | placetype == 107 | placetype == 109 | placetype == 111 | placetype == 112 | placetype == 113 | placetype == 114 | placetype == 121 | placetype == 122 | placetype == 123 | placetype == 124

*******************************************************************************
*			Core Analysis
*******************************************************************************

* core regression
regress bill hhsize inc placedist_d items cash

*******************************************************************************
*			Issue 1: Nonlinear Terms
*******************************************************************************

* RESET
ovtest

* confirm
predict yhat
gen yhat2 = yhat^2
gen yhat3 = yhat^3
regress bill hhsize inc placedist_d items cash yhat2 yhat3

// generate nonlinear terms
gen inc2 = inc^2
gen hh2 = hhsize^2 // P>|t| = 0.971
gen dist2 = placedist_d^2
gen item2 = items^2

gen inc_hh = inc * hhsize // P>|t| = 0.440
gen inc_dist = inc * placedist_d
gen inc_item = inc * items
gen hh_dist = hhsize * placedist_d // P>|t| = 0.167
gen hh_item = hhsize * items // P>|t| = 0.798
gen dist_item = placedist_d * items // P>|t| = 0.337

regress bill hhsize inc placedist_d items cash inc2 hh2 dist2 item2 inc_hh inc_dist inc_item hh_dist hh_item dist_item // test these terms

regress bill hhsize inc placedist_d items cash inc2 dist2 item2 inc_dist inc_item // keep significant terms

regress bill hhsize inc placedist_d items cash inc2 inc_dist // keep terms that make theoretical sense

*******************************************************************************
*			Issue 2: Omitted Variable Bias
*******************************************************************************

rvfplot, yline(0) msize(vtiny)
rvpplot inc, msize(vtiny)
rvpplot hhsize, msize(vtiny)
rvpplot placedist_d, msize(vtiny) // evidence of heteroskedasticity
rvpplot items, msize(vtiny)
rvpplot cash, msize(vtiny)

*******************************************************************************
*			Issue 3: Collinearity
*******************************************************************************

* run auxiliary regressions to search for collinearity. R^2 in the comment
reg inc hhsize placedist_d items cash // 0.0314
reg hhsize placedist_d items cash inc // 0.0348
reg placedist_d items cash inc hhsize // 0.0057
reg items cash inc hhsize placedist_d // 0.0293
reg cash inc hhsize placedist_d items // 0.0271

// R^2 below 0.8 so we do not worry about collinearity

*******************************************************************************
*			Issue 4: Heteroskedasticity
*******************************************************************************

* check for heteroskedasticity
estat imtest, white // use white test
estat hettest // breusch pagan

regress bill hhsize inc placedist_d items cash inc2 inc_dist, vce(robust) // robust SE
hetregress bill hhsize inc placedist_d items cash inc2 inc_dist, het(hhsize inc placedist_d items cash inc2 inc_dist) twostep // use FGLS