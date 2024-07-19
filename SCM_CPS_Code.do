
clear
set more off

if "`c(username)'" == "Jerzyk" {

global do = "/Volumes/Jerzy/Casual Inference /AI_Influence/do"
global rawdata = "/Volumes/Jerzy/Casual Inference /AI_Influence/rawdata"
global workdata = "/Volumes/Jerzy/Casual Inference /AI_Influence/workdata"
global log = "/Volumes/Jerzy/Casual Inference /AI_Influence/log"
global pic = "/Volumes/Jerzy/Casual Inference /AI_Influence/pic"

}

if "`c(username)'" == "" {

global do = "/do"
global rawdata = "/rawdata"
global workdata = "workdata"
global log = "/log"
global pic = "/pic"

}


use "$rawdata/cps_00008.dta", clear
use year serial month hwtfinl cpsid gqtype metfips cpsidp age sex race marst occ uhrsworkt educ using "$rawdata/cps_00008.dta", replace
order year month serial cpsid cpsidp hwtfinl metfips




//////////////////////////// DATA CLEANING

replace uhrsworkt =. if uhrsworkt == 999 | uhrsworkt == 997 | uhrsworkt > 168
replace marst =. if marst == 9
recode uhrsworkt (41/max=1) (else=0), gen(overtime)
gen artist = 1 if occ == 2600


* Usuwanie pozostalych obserwacji
keep if inlist(occ, 0010, 0102, 0136, 0140, 0205, 0520, 0530, 0540, 0565, ///
                    0725, 0726, 1600, 1610, 1821, 1822, 1825, 1910, 1920, 1935, ///
                    2011, 2012, 2014, 2040, 2300, 2310, 2320, 2600, 2633, 2700, ///
                    2721, 2722, 2723, 2740, 3010, 3030, 3040, 3050, 3100, 3160, ///
                    3250, 3255, 3402, 3421, 3801, 3820, 3870, 3940, 4000, 4020, ///
                    4030, 4040, 4055, 4110, 4140, 4220, 4230, 4240, 4251, 4340, ///
                    4350, 4465, 4500, 4510, 5510, 6115, 6120, 6130, 6220, 6230, ///
                    6260, 6305, 6355, 6400, 6410, 6441, 6442, 6515, 6700, 6850, ///
                    7040, 7100, 7120, 7130, 7140, 7150, 7160, 7315, 7350, 7720, ///
                    7730, 7740, 7760, 7800, 7810, 7855, 8030, 8100, 8140, 8225, ///
                    8255, 8256, 8300, 8310, 8320, 8335, 8350, 8365, 8450, 8465, ///
                    8500, 8510, 8530, 8540, 8555, 8600, 8620, 8640, 8650, 8710, ///
                    8740, 8750, 8810, 8940, 8990, 9030, 9050, 9110, 9121, 9122, ///
                    9130, 9142, 9150, 9210, 9240, 9300, 9310, 9510)
					
* sortowanie danych i zapisanie
order year month occ 
sort occ year month
save "$workdata/FV_indiviudal_data.dta", replace



//////////////////////////// DATA PREPROCESSING

* dane indywidualne full
use "$workdata/FV_indiviudal_data", replace
gen temp1 = 1
egen monthly_occ_count = total(temp1), by(occ year month)
order year month occ monthly_occ_count
save "$workdata/FV_indiviudal_data_final.dta", replace

*dane zagregowane
use "$workdata/FV_indiviudal_data", replace
gen date = mdy(month,1, year)
gen num = 1
collapse (sum) employment = num, by (occ year month)
save "$workdata/FV_agregated_data.dta", replace


/////////////////* employment growth change
use "$workdata/FV_agregated_data", replace
gen date = mdy(month,1, year)
format date %td
sort occ date

by occ (date): gen first_period_employment = employment[1]
gen monthly_employment_growth = (employment / first_period_employment) * 100

/*
by occ (date): gen previous_period_employment = employment[_n-1]
replace previous_period_employment = employment if _n == 1
gen monthly_employment_growth = (employment - previous_period_employment) / previous_period_employment * 100
*/

list monthly_employment_growth if missing(monthly_employment_growth)
drop first_period_employment
order date
save "$workdata/FV_growth.dta", replace


/////////* charactercitsc monthly


* ZMIENNE
use "$workdata/FV_indiviudal_data_final", clear
egen mode_gqtype = mode(gqtype), by(occ year month)
egen mode_sex = mode(sex), by(occ year month)
egen mode_race = mode(race), by(occ year month)
egen mode_marst = mode(marst), by (occ year month)
egen mode_overtime = mode(overtime), by (occ year month)
egen mode_metfips = mode (metfips), by (occ year month)



* ŚREDNIE
// use "$workdata/workers_indiviudal_data_final", clear
collapse (mean) age uhrsworkt, by(occ year month mode_gqtype mode_sex mode_race mode_marst mode_overtime mode_metfips)
replace uhrsworkt = 0 if uhrsworkt ==.
save "$workdata/FV_charactercistics.dta", replace




* EDUC
/*
Chce policzyć następująca charakterystykę: zagregowac kazda grupe zawodowa co miesiac (occ year month) i policzyc jaka czesc tej grupy (procentowy udział) ma education co najmniej bachelor (>=111)
*/
use "$workdata/FV_indiviudal_data_final", clear
gen bachelor = 1 if educ >= 111
replace bachelor = 0 if bachelor ==.
collapse (sum) bachelor, by(occ year month monthly_occ_count)
gen bachelor_share = bachelor/monthly_occ_count
save "$workdata/FV_bachelor_share.dta", replace


* MERGE

use "$workdata/FV_growth.dta", clear
merge 1:1 year month occ using "$workdata/FV_charactercistics.dta"
sort occ date

drop _merge
merge 1:1 year month occ using "$workdata/FV_bachelor_share.dta"
drop monthly_occ_count

gen ai = 1 if date > mdy(11, 1, 2022)
replace ai = 0 if ai==.
tab ai

order year month occ employment age
sort occ date
save "$workdata/FV_full_data_merged", replace




*LABELS
/*
label define gq_label ///
                    1 "Married primary holder" ///
                    3 "Unmarried male primary holder" ///
                    4 "Unmarried female primary holder" ///
                    6 "Primary indiviudal male" ///
					7 "Primary indiviudal female" ///
					10 "Group quarters" 
label values mode_gqtype gq_label


label define sex_label ///
                    1 "Male" ///
                    2 "Female"
label values mode_sex sex_label
label variable mode_sex "Sex"

label define race_label ///
                    100 "White" ///
                    200 "Black" ///
					300 "American Indian/Aleut/Eskimo"
label values mode_race race_label
label variable mode_race "Race"

label define marst_label ///
                    1 "Married, spouse present" ///
                    2 "Married, spouse absent" ///
                    3 "Separated" ///
                    4 "Divorced" ///					
                    5 "Widowed" ///
					6 "Never married/single"
label values mode_marst marst_label
label variable mode_marst "Martial status"

label define overtime_label ///
                    1 "Overtime" ///
                    0 "No overtime"
label values mode_overtime overtime_label
label variable mode_overtime "Works overtime"

label variable employment "Monthly employment"
label variable age "Mean age"
label variable monthly_employment_growth "Monthly employment growth rate"
label variable mode_gqtype "Household type"
label variable mode_metfips "Metropolitan area"
label variable uhrsworkt "Mean weekly hourse worked"
label variable bachelor "Number of bachelor degree or higher"
label variable bachelor_share "Percent of bachelor degree or higher"
label variable ai "Dummy for AI"

save "$workdata/FINAL_full_data_merged", replace
*/



////////////////////////////SCM

use "$workdata/FV_full_data_merged", clear

sort occ date
by occ: gen period = _n

drop if period>34
tsset occ period


synth monthly_employment_growth age mode_gqtype mode_sex mode_race mode_marst ///
mode_overtime mode_metfips bachelor_share uhrsworkt ///
monthly_employment_growth(2) monthly_employment_growth(3) monthly_employment_growth(4) monthly_employment_growth(5) monthly_employment_growth(6) monthly_employment_growth(7) monthly_employment_growth(8) monthly_employment_growth(9) monthly_employment_growth(10) monthly_employment_growth(11) monthly_employment_growth(12) monthly_employment_growth(13) monthly_employment_growth(14) monthly_employment_growth(15) monthly_employment_growth(16) monthly_employment_growth(17) monthly_employment_growth(18) monthly_employment_growth(19) monthly_employment_growth(20) monthly_employment_growth(21) monthly_employment_growth(22) monthly_employment_growth(23) monthly_employment_growth(24) monthly_employment_growth(25) monthly_employment_growth(26) monthly_employment_growth(27) monthly_employment_growth(28) monthly_employment_growth(29) monthly_employment_growth(30) monthly_employment_growth(31) monthly_employment_growth(32) monthly_employment_growth(33) monthly_employment_growth(34) ///
,trunit(2600) trperiod(24) figure keep("synth_ch") replace

synth_runner monthly_employment_growth age mode_gqtype mode_sex mode_race mode_marst ///
mode_overtime mode_metfips bachelor_share uhrsworkt ///
monthly_employment_growth(2) monthly_employment_growth(3) monthly_employment_growth(4) monthly_employment_growth(5) monthly_employment_growth(6) monthly_employment_growth(7) monthly_employment_growth(8) monthly_employment_growth(9) monthly_employment_growth(10) monthly_employment_growth(11) monthly_employment_growth(12) monthly_employment_growth(13) monthly_employment_growth(14) monthly_employment_growth(15) monthly_employment_growth(16) monthly_employment_growth(17) monthly_employment_growth(18) monthly_employment_growth(19) monthly_employment_growth(20) monthly_employment_growth(21) monthly_employment_growth(22) monthly_employment_growth(23) monthly_employment_growth(24) monthly_employment_growth(25) monthly_employment_growth(26) monthly_employment_growth(27) monthly_employment_growth(28) monthly_employment_growth(29) monthly_employment_growth(30) monthly_employment_growth(31) monthly_employment_growth(32) monthly_employment_growth(33) monthly_employment_growth(34) ///
,trunit(2600) trperiod(24) keep("synth_ch_rmspe") replace




////////////////////////////POST-ANALYSIS

clear
set more off

use "$workdata/FV_full_data_merged", clear

by occ: gen period = _n
gen treat = occ == 2600
gen _Co_Number = occ
	drop _merge
	merge m:1 _Co_Number using "$do/synth_ch.dta"
	drop if _merge == 2
	drop _merge
	rename _W_Weight weight
	replace weight = 1 if treat == 1
	collapse (mean) monthly_employment_growth age mode_gqtype mode_sex mode_race ///
	mode_marst mode_overtime mode_metfips bachelor_share uhrsworkt [aweight = weight] ///
	, by(period treat)
	
save "$workdata/FV_SCM_control_comparison", replace

use "$workdata/FV_SCM_control_comparison", clear

twoway (line monthly_employment_growth period if treat == 1, lcolor(blue) lpattern(solid) lwidth(medium)) ///
       (line monthly_employment_growth period if treat == 0, lcolor(red) lpattern(dash) lwidth(medium)), ///
	   xlabel(1 "01.2021" 6 "06.2021" 12 "12.2021" 18 "06.2022" 23 "11.2022" ///
	   30 "06.2023" 36 "12.2024" 39 "03.2024", labs(vsmall)) ///
       legend(label(1 "Artists") label(2 "Synthetic Artists")) ///
       title("Monthly employment growth rate") ///
       xtitle("") ///
       ytitle("Growth rate m/m (%)") ///
       xline(23, lcolor(black) lpattern(dash)) ///
       text(115 23 "Chat GPT Inception", place(f) size(small))
	   graph export "$pic/comparioson_graph_FINAL.png", replace width(3000)


	   
	   
	   
//////////////////////////TESTING

*TIME DUMMY
use "$workdata/FV_full_data_merged", clear

sort occ date
by occ: gen period = _n
drop if period>34
tsset occ period

synth monthly_employment_growth age mode_gqtype mode_sex mode_race mode_marst ///
mode_overtime mode_metfips bachelor_share uhrsworkt ///
monthly_employment_growth(2) monthly_employment_growth(3) monthly_employment_growth(4) monthly_employment_growth(5) monthly_employment_growth(6) monthly_employment_growth(7) monthly_employment_growth(8) monthly_employment_growth(9) monthly_employment_growth(10) monthly_employment_growth(11) monthly_employment_growth(12) monthly_employment_growth(13) monthly_employment_growth(14) monthly_employment_growth(15) monthly_employment_growth(16) monthly_employment_growth(17) monthly_employment_growth(18) monthly_employment_growth(19) monthly_employment_growth(20) monthly_employment_growth(21) monthly_employment_growth(22) monthly_employment_growth(23) monthly_employment_growth(24) monthly_employment_growth(25) monthly_employment_growth(26) monthly_employment_growth(27) monthly_employment_growth(28) monthly_employment_growth(29) monthly_employment_growth(30) monthly_employment_growth(31) monthly_employment_growth(32) monthly_employment_growth(33) monthly_employment_growth(34) ///
,trunit(2600) trperiod(18) figure keep("synth_ch_dummy_time") replace


use "$workdata/FV_full_data_merged", clear

by occ: gen period = _n
gen treat = occ == 2600
gen _Co_Number = occ
	drop _merge
	merge m:1 _Co_Number using "$do/synth_ch_dummy_time.dta"
	drop if _merge == 2
	drop _merge
	rename _W_Weight weight
	replace weight = 1 if treat == 1
	collapse (mean) monthly_employment_growth age mode_gqtype mode_sex mode_race ///
	mode_marst mode_overtime mode_metfips bachelor_share uhrsworkt [aweight = weight] ///
	, by(period treat)
	
save "$workdata/FV_time_dummy_comparison", replace
use "$workdata/FV_time_dummy_comparison", clear

twoway (line monthly_employment_growth period if treat == 1, lcolor(blue) lpattern(solid) lwidth(medium)) ///
       (line monthly_employment_growth period if treat == 0, lcolor(red) lpattern(dash) lwidth(medium)), ///
	   xlabel(1 "01.2021" 6 "06.2021" 12 "12.2021" 18 "06.2022" 23 "11.2022" ///
	   30 "06.2023" 36 "12.2024" 39 "03.2024", labs(vsmall)) ///
       legend(label(1 "Artists") label(2 "Synthetic Artists")) ///
       title("Monthly employment cumulative growth rate") ///
       xtitle("") ///
       ytitle("Cummulative employment growth rate") ///
	   xline(18, lcolor(purple) lpattern(dash)) ///
       text(120 10 "Dummy Chat GPT", place(f) size(small)) ///
       xline(23, lcolor(black) lpattern(dash)) ///
       text(120 23 "Real Chat GPT", place(f) size(small))
	   graph export "$pic/time_dummy_comparioson_graph_FINAL.png", replace width(3000)



*OCC DUMMY
use "$workdata/FV_full_data_merged", clear

sort occ date
by occ: gen period = _n
drop if period>34
tsset occ period

synth monthly_employment_growth age mode_gqtype mode_sex mode_race mode_marst ///
mode_overtime mode_metfips bachelor_share uhrsworkt ///
monthly_employment_growth(2) monthly_employment_growth(3) monthly_employment_growth(4) monthly_employment_growth(5) monthly_employment_growth(6) monthly_employment_growth(7) monthly_employment_growth(8) monthly_employment_growth(9) monthly_employment_growth(10) monthly_employment_growth(11) monthly_employment_growth(12) monthly_employment_growth(13) monthly_employment_growth(14) monthly_employment_growth(15) monthly_employment_growth(16) monthly_employment_growth(17) monthly_employment_growth(18) monthly_employment_growth(19) monthly_employment_growth(20) monthly_employment_growth(21) monthly_employment_growth(22) monthly_employment_growth(23) monthly_employment_growth(24) monthly_employment_growth(25) monthly_employment_growth(26) monthly_employment_growth(27) monthly_employment_growth(28) monthly_employment_growth(29) monthly_employment_growth(30) monthly_employment_growth(31) monthly_employment_growth(32) monthly_employment_growth(33) monthly_employment_growth(34) ///
,trunit(2740) trperiod(24) figure keep("synth_ch_dummy_occ") replace	   


*TIME DUMMY
use "$workdata/FV_full_data_merged", clear

by occ: gen period = _n
gen treat = occ == 2740
gen _Co_Number = occ
	drop _merge
	merge m:1 _Co_Number using "$pic/synth_ch_dummy_occ.dta"
	drop if _merge == 2
	drop _merge
	rename _W_Weight weight
	replace weight = 1 if treat == 1
	collapse (mean) monthly_employment_growth age mode_gqtype mode_sex mode_race ///
	mode_marst mode_overtime mode_metfips bachelor_share uhrsworkt [aweight = weight] ///
	, by(period treat)
	
save "$workdata/FV_time_time_comparison", replace
use "$workdata/FV_time_time_comparison", clear

drop if period > 36
twoway (line monthly_employment_growth period if treat == 1, lcolor(blue) lpattern(solid) lwidth(medium)) ///
       (line monthly_employment_growth period if treat == 0, lcolor(red) lpattern(dash) lwidth(medium)), ///
	   xlabel(1 "01.2021" 6 "06.2021" 12 "12.2021" 18 "06.2022" 23 "11.2022" ///
	   30 "06.2023" 36 "12.2024" 39 "03.2024", labs(vsmall)) ///
       legend(label(1 "Dancers") label(2 "Synthetic dancers")) ///
       title("Monthly employment growth rate") ///
       xtitle("") ///
       ytitle("Growth rate m/m (%)") ///
       xline(23, lcolor(black) lpattern(dash)) ///
       text(500 23 "Chat GPT Inception", place(f) size(small))
	   graph export "$pic/occ_dummy_comparioson_graph_FINAL.png", replace width(3000)
	   
	   

use "synth_ch_rmspe", replace  // synth_ch_taxed_rmspe

drop if post_rmspe > 20
twoway 	(line effect period if occ == 0010, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 0102, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 0136, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 0140, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 0205, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 0520, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 0530, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 0540, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 0565, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 0725, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 0726, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 1600, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 1610, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 1821, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 1822, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 1825, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 1910, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 1920, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 1935, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 2011, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 2012, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 2014, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 2040, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 2300, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 2310, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 2320, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 2600, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 2633, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 2700, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 2721, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 2722, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 2723, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 2740, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 3010, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 3030, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 3040, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 3050, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 3100, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 3160, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 3250, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 3255, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 3402, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 3421, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 3801, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 3820, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 3870, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 3940, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 4000, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 4020, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 4030, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 4040, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 4055, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 4110, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 4140, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 4220, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 4230, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 4240, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 4251, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 4340, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 4350, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 4465, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 4500, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 4510, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 5510, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 6115, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 6120, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 6130, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 6220, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 6230, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 6260, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 6305, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 6355, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 6400, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 6410, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 6441, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 6442, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 6515, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 6700, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 6850, lc(gs14) lw(vthin)) ///
			(line effect period if occ == 2600, lc(red) lw(medthin)) ///
			,xline(23, lp(dash) lc(black) lw(medthin)) ///
			text(200 23 "Chat GPT Inception", place(f) size(small)) ///
			legend(order(1 "Placebo Estimates" 2 "Artists" ) region(lwidth(none))) ///
			xlabel(1 "01.2021" 6 "06.2021" 12 "12.2021" 18 "06.2022" 23 "11.2022" ///
			30 "06.2023", labs(vsmall)) ////
			ylabel(, angle(0)) ///
			xtitle("") ytitle("SCM Estimates") 


			
////////////////////////////////////////////////END




