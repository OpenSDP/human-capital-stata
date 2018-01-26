---
title: "Compare Teacher Turnover Rates Across School Poverty Quartiles"
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

[OpenSDP Home](http://opensdp.github.io) / [Human Capital Analysis: Retention](Human_Capital_Analysis_Retention.html) / Compare Teacher Turnover Rates Across School Poverty Quartiles

![](Teacher_Turnover_by_School_Poverty_Quartile.png)

###Preparation
####Purpose

Examine the extent to which retention patterns differ according to school poverty characteristics.

####Required analysis file variables

 - `tid`
 - `school_year`
 - `t_stay`
 - `t_transfer`
 - `t_leave`
 - `school_poverty_quartile`


####Analysis-specific sample restrictions

 - Keep only years for which nexy-year retention status can be calculated.


####Ask yourself

 - How do turnover patterns vary for high-and-low poverty schools?
 - What other factors (school and district size, urban vs. rural, school closings, etc.) might help account for the differences I see?
 - Does your agency have an incentive program in place to increase recruiting and retention in high-need schools?


####Potential further analyses

You may want to use ranges of school free and reduced price lunch percentages, rather than quartiles, to make the chart easier to interpret, or use your agency's own classification of high-need schools. You can also use a graph of this type to examine teacher turnover by other school characteristics. For example, you could explore teacher turnover by school student minority share quartiles, or average test score quartiles.

###Analysis

####Step 1: Load data.


```stata
use "${analysis}\Teacher_Year_Analysis.dta", clear
isid tid school_year
```



####Step 2: Restrict sample.

Keep only teachers in years for which next-year retention status can be calculated. Keep records with non-missing values for school poverty quartile.


```stata
keep if school_year >= 2012 & school_year <= 2014 
keep if !missing(school_poverty_quartile)
assert !missing(t_stay, t_transfer, t_leave)
```


####Step 3: Review Variables.


```stata
assert t_leave + t_transfer + t_stay == 1
tab school_poverty_quartile t_stay, mi row
tab school_poverty_quartile t_transfer, mi row
tab school_poverty_quartile t_leave, mi row
```


####Step 4: Get sample sizes.


```stata
sum tid
local teacher_years = string(r(N), "%9.0fc")
preserve
	bysort tid: keep if _n == 1
	sum tid
	local unique_teachers = string(r(N), "%9.0fc")
restore
```


####Step 5: Calculate significance indicator variables by quartile.


```stata
foreach var of varlist t_leave t_transfer {
	gen sig_`var' = .
	xi: logit `var' i.school_poverty_quartile, robust
	forval quartile = 2/4 {
		replace sig_`var' = abs(_b[_Ischool_po_`quartile'] / ///
			_se[_Ischool_po_`quartile']) if school_poverty_quartile == `quartile'
		replace sig_`var' = 0 if sig_`var' <= 1.96 & ///
			school_poverty_quartile == `quartile'
		replace sig_`var' = 1 if sig_`var' > 1.96 & ///
			school_poverty_quartile == `quartile'
	}
	replace sig_`var' = 0 if school_poverty_quartile == 1
}
```


####Step 6: Collapse and calculate shares.


```stata
collapse (mean) t_leave t_transfer sig_* (count) tid, by(school_poverty_quartile)
foreach var of varlist t_leave t_transfer {
	replace `var' = `var' * 100
}
```


####Step 7: Concatenate value and significance asterisk.


```stata
foreach var of varlist t_leave t_transfer {
	tostring(sig_`var'), replace
	replace sig_`var' = "*" if sig_`var' == "1"
	replace sig_`var' = "" if sig_`var' == "0"
	gen `var'_str = string(`var', "%9.0f")
	egen `var'_label = concat(`var'_str sig_`var')
}
```


####Step 8: Generate count variable and add variables cumulatively for graphing.


```stata
gen count = _n
replace t_transfer = t_leave + t_transfer
```


####Step 9: Make chart.


```stata
#delimit ;

twoway bar t_transfer count,
	barwidth(.6) color(forest_green) finten(100) ||
	
	bar t_leave count,
	barwidth(.6) color(maroon) finten(100) ||
	
	scatter t_transfer count,
		mlabel(t_transfer_label) 
		msymbol(i) msize(tiny) mlabpos(6) mlabcolor(white) mlabgap(.001) ||
		
	scatter t_leave count,
		mlabel(t_leave_label) 
		msymbol(i) msize(tiny) mlabpos(6) mlabcolor(white) mlabgap(.001) ||,
		
	title("Average Teacher Turnover", span)
	subtitle("by School FRPL Quartile", span) 
	ytitle("Percent of Teachers", size(medsmall)) 
	yscale(range(0(10)60)) 
	ylabel(0(10)60, nogrid labsize(medsmall)) 
	xtitle("") 
	xlabel(1 "Lowest Poverty" 2 "2nd Quartile" 3 "3rd Quartile" 4 "Highest Poverty", 
		labsize(medsmall)) 
	
	legend(order(1 "Transfer Schools" 2 "Leave")
		ring(0) position(11) symxsize(2) symysize(2) rows(2) size(medsmall) 
		region(lstyle(none) lcolor(none) color(none)))
		
	graphregion(color(white) fcolor(white) lcolor(white)) plotregion(color(white) 
		fcolor(white) lcolor(white))
	
	note("*Significantly different from schools in the lowest free and reduced 
price lunch quartile, at the 95 percent confidence level." "Notes: Sample includes
`teacher_years' teacher years and `unique_teachers' unique teachers in the 2011-12
to 2013-14 school years. Retention analyses are based" "on one-year retention rates.",
span size(vsmall));

#delimit cr
```


####Step 10: Save chart.


```stata
graph save "$graphs\Retention_by_Poverty_Quartile.gph", replace
graph export "$graphs\Retention_by_Poverty_Quartile.emf", replace
```



---

Previous Analysis: [Examine Teacher Turnover Across School Years](Teacher_Turnover_by_School_Year.html)

Next Analysis: [Compare Teacher Turnover Rates Across Teacher Effectiveness Terciles](Teacher_Turnover_by_Teacher_Effectiveness_Tercile.html)
