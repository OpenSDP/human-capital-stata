---
title: "Calculate Average Annual Teacher Retention"
output: 
  html_document:
    theme: simplex
    css: styles.css
    highlight: NULL
    keep_md: true
    toc: true
    toc_depth: 4
    toc_float: true
    number_sections: false
---






<div class="navbar navbar-default navbar-fixed-top" id="logo">
<div class="container">
<img src="OpenSDP-Banner_crimson.jpg" style="display: block; margin: 0 auto; height: 115px;">
</div>
</div>

[OpenSDP Home](http://opensdp.github.io) / [Human Capital Analysis: Retention](Human_Capital_Analysis_Retention.html) / Calculate Average Annual Teacher Retention

![](Average_Annual_Teacher_Retention.png)

###Preparation
####Purpose

Examine basic novice teacher retention patterns for years in the agency.

####Required analysis file variables

 - `tid`
 - `school_year`
 - `t_stay`
 - `t_transfer`
 - `t_leave`


####Analysis-specific sample restrictions

 - Keep only years for which next-year retention status can be calculated.


####Ask yourself

 - Are transfer and attrition rates what you expected?
 - What is the optimal balance for your agency between retaining experienced teachers and recruiting, hiring, and training new teachers?


####Potential further analyses

You can add a category for retirees, if you have explicit retirement data, or for "likely retirees," teachers who left teaching and were above a cutoff age.

###Analysis

####Step 1: Load data.


```stata
use "${analysis}\Teacher_Year_Analysis.dta", clear
isid tid school_year
```


####Step 2: Restrict the analysis sample.

Keep only teachers in years for which next-year retention status can be calculated.


```stata
keep if school_year >= 2012 & school_year <= 2014 
assert !missing(t_stay, t_transfer, t_leave)
```


####Step 3: Review variables.


```stata
assert t_leave + t_transfer + t_stay == 1
tab school_year t_stay, mi
tab school_year t_transfer, mi
tab school_year t_leave, mi
```


####Step 4: Get sample size.


```stata
summ tid
local teacher_years = string(r(N), "%9.0fc")
preserve
	bysort tid: keep if _n == 1
	summ tid
	local unique_teachers = string(r(N), "%9.0fc")
restore
```


####Step 5: Collapse data and calculate shares.


```stata
collapse (mean) t_stay t_transfer t_leave (count) tid

foreach var of varlist t_stay t_transfer t_leave {
	replace `var' = `var' * 100
}
```


####Step 6: Make chart.


```stata
#delimit ;
graph pie t_stay t_transfer t_leave, 
	angle0
		(330) 
	title
		("Average Teacher Retention", span) 
	pie
		(1, color(navy)) 
	pie
		(2, color(forest_green)) 
	pie
		(3, color(maroon)) 		
	pie 
		(4, color(dkorange))
	
	plabel
		(1 percent, gap(5) format("%2.0f") color(white) size(medsmall) placement(3)) 
	plabel
		(2 percent, gap(5) format("%2.0f") color(white) size(medsmall) placement(0)) 
	plabel
		(3 percent, gap(5) format("%2.0f") color(white) size(medsmall) placement(3)) 
	plabel
		(4 percent, gap(5) format("%2.0f") color(white) size(medsmall) placement(3)) 
	plabel
		(1 "Stay", 
			color(black) size(medsmall) placement(9) gap(20))  
	plabel
		(2 "Transfer Schools", 
			color(black) size(medsmall) placement(4) gap(20))  
	plabel
		(3 "Leave",
			color(black) size(medsmall) placement(4) gap(20)) 
	legend
		(off) 
	graphregion(color(white) fcolor(white) lcolor(white)) plotregion(color(white) 
		fcolor(white) lcolor(white))
		
	note(" " "Notes: Sample includes `teacher_years' teacher years and
`unique_teachers' unique teachers in the 2011-12 to 2013-14 school years. Retention
analyses are based" "on one-year retention rates.", span size(vsmall)) ; 
#delimit cr
```


####Step 7: Save chart.


```stata
graph save "$graphs\Average_Teacher_Retention.gph", replace
graph export "$graphs\Average_Teacher_Retention.emf", replace
```


---

Next Analysis: [Examine Teacher Turnover Across School Years](Teacher_Turnover_by_School_Year.html)
