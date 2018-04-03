---
title: "Compare the Shares of New Hires Across School Poverty Quartiles"
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

[OpenSDP Analysis](http://opensdp.github.io/analysis) / [Human Capital Analysis: Recruitment](Human_Capital_Analysis_Recruitment.html) / Compare the Shares of New Hires Across School Poverty Quartiles

![](Share_of_Teachers_Who_Are_New_Hires_by_School_Poverty_Level.png)

###Preparation
####Purpose

Examine the extent to which new hires are distributed unevenly across the agency according to school characteristics.

####Required analysis file variables

 - `tid`
 - `school_year`
 - `t_new_hire`
 - `t_novice`
 - `school_poverty_quartile`


####Analysis-specific sample restrictions

 - Keep only years for which new hire information is available.


####Ask yourself

 - How do hiring patterns differ between high and low-poverty schools?
 - Are the shares of novice and veteran hires distributed equitably and strategically across school poverty quartiles?


####Potential further analyses

You can use a version of this graph to look at how new hires are distributed across other quartiles of school characteristics. For example, you can examine new hiring by school average test score quartile, or school minority percent quartile.


###Analysis

####Step 1: Load the Teacher_Year_Analysis data file.


```stata
use "${analysis}\Teacher_Year_Analysis.dta", clear
isid tid school_year
```



####Step 2: Restrict the analysis sample.


```stata
keep if school_year > 2010
keep if !missing(t_new_hire)
keep if !missing(t_novice)
keep if !missing(school_poverty_quartile)
keep if !missing(t_experience, t_veteran_new_hire)	

```


####Step 3: Review variables used in the analysis.


```stata
tab school_poverty_quartile, mi
tab school_poverty_quartile t_novice, mi row
tab school_poverty_quartile t_veteran_new_hire, mi row
```


####Step 4: Calculate sample size.


```stata
summ tid
local teacher_years = string(r(N), "%9.0fc")
preserve 
	bys tid: keep if _n == 1
	summ tid
	local unique_teachers = string(r(N), "%9.0fc")
restore
```


####Step 5: Calculate significance indicator variables by school poverty quartile.


```stata
foreach var of varlist t_novice t_veteran_new_hire {
	gen sig_`var' = .
	xi: reg `var' i.school_poverty_quartile, robust
	forval quart = 2/4 {
		replace sig_`var' = abs(_b[_Ischool_po_`quart']/_se[_Ischool_po_`quart']) ///
			if school_poverty_quartile == `quart'
		replace sig_`var' = 0 if sig_`var' <= 1.96 & school_poverty_quartile ==`quart'
		replace sig_`var' = 1 if sig_`var' > 1.96 & school_poverty_quartile == `quart'
	}
	replace sig_`var' = 0 if school_poverty_quartile == 1
}	
```


####Step 6: Collapse to calculate shares of new hires in each quartile.


```stata
collapse (mean) t_novice t_veteran_new_hire sig_*, by(school_poverty_quartile)
foreach var of varlist t_novice t_veteran_new_hire {
	replace `var' = 100 * `var'
}
```


####Step 7: Concatenate values and significance asterisks to value labels.


```stata
foreach var of varlist t_novice t_veteran_new_hire {
	tostring(sig_`var'), replace
	replace sig_`var' = "*" if sig_`var' == "1"
	replace sig_`var' = "" if sig_`var' == "0"
	gen `var'_str = string(`var', "%9.0f")
	egen `var'_label = concat(`var'_str sig_`var')
}
```


####Step 8: Get the total new hire percent for each year for graphing.


```stata
gen t_total = t_novice + t_veteran_new_hire
```


####Step 9: Create a bar graph.

Use twoway bar and scatter for the labels.


```stata
#delimit ;
twoway (bar t_total school_poverty_quartile, 
		fcolor(forest_green) lcolor(forest_green) lwidth(0) barwidth(0.75))
	(bar t_novice school_poverty_quartile, 
		fcolor(maroon) lcolor(maroon) lwidth(0) barwidth(0.75)) 
	(scatter t_total school_poverty_quartile, 
		mcolor(none) mlabel(t_veteran_new_hire_label) mlabcolor(white) mlabpos(6)  
		mlabsize(small)) 
	(scatter t_novice school_poverty_quartile, 
		mcolor(none) mlabel(t_novice_label) mlabcolor(white) mlabpos(6)  
		mlabsize(small)), 
	title("Calculate the Share of Teachers Who Are New Hires", span) 
	subtitle("by School FRPL Quartile", span) 
	ytitle("Percent of Teachers") 
	ylabel(0(10)30, nogrid labsize(medsmall)) 
	xtitle("") 
	xlabel(1 "Lowest Poverty" 2 "2nd Quartile" 3 "3rd Quartile" 4 "Highest Poverty", 
		labsize(medsmall)) 
	legend(order(1 "Experienced New Hires" 2 "Novice New Hires")
		ring(0) position(11) symxsize(2) symysize(2) rows(2) size(medsmall) 
		region(lstyle(none) lcolor(none) color(none))) 
	graphregion(color(white) fcolor(white) lcolor(white)) 
	plotregion(color(white) fcolor(white) lcolor(white) margin(2 0 2 0))
	note(" " "*Significantly different from schools in the lowest free and reduced 
price lunch quartile, at the 95 percent confidence level." "Notes: Sample includes 
teachers in the 2010-11 through 2014-15 school years, with `teacher_years' teacher years 
and `unique_teachers' unique teachers."
"Novices were in their first year of teaching.", size(vsmall) span);
#delimit cr
```


####Step 10: Save the chart in Stata Graph and EMF formats.

If marker labels need to be moved by hand using Stata Graph Editor, re-save .gph and .emf files after editing.


```stata
	graph export "${graphs}/New_Hires_by_Poverty_Quartile.emf", replace 
	graph save "${graphs}/New_Hires_by_Poverty_Quartile.gph", replace 
```



---

Previous Analysis: [Examine the Share of New Hires Across School Years](Share_of_Teachers_Who_Are_New_Hires_by_School_Year.html)

Next Analysis: [Examine the Distribution of Teachers and Students by Race](Share_of_Teachers_and_Students_by_Race.html)
