/*****************************************************************************************
* SDP Version 1.0
* Last Updated: March 8, 2018
* File name: Analyze_Recruitment.do
* Author(s): Strategic Data Project
*
* Description: This program produces analyses that show recruiting practices 
* and the distribution of new hires by: 
* 1. Describing the overall share of novice and experienced new hires.
* 2. Describing the share of novice and experienced new hires by year.
* 3. Examining the extent to which new hires are distributed unevenly across
*    the agency according to school poverty characteristics. 
* 4. Estimating the difference in teacher effectiveness between teachers 
*    with traditional and alternative certifications.
* 5. Comparing the shares of all teachers, newly hired teachers, and students
*    by race.
*
* Inputs: 	Teacher_Year_Analysis.dta
*			Stuent_School_Year.dta
*
*****************************************************************************************/

	// Close log file if open and set up environment
	
	capture log close
	clear all
	set mem 1000m
	set more off
	set scheme s1color

	// Edit the file path below to point to the directory with folders for data, logs,
	// programs, and tables and figures. Change to that directory.
	
	cd "C:\working_files"

	// Define file locations
	
	global analysis ".\data\analysis"
	global graphs 	".\tables_figures"
	global log 		".\logs"

	// Open log file
	
	log using "${log}\Analyze_Recruitment.txt", text replace

	// Set program switches for recruitment analyses. Set switch to 0 to skip the 
	// section of code that runs a given analysis, and to 1 to run the analysis.
	
	global new_hires_pie	 			= 1
	global new_hires_year				= 1
	global new_hires_school_poverty 	= 1
	global share_teachers_stu_race		= 1

/*** A1. Share of Teachers Who Are New Hires ***/ 

if ${new_hires_pie}==1 { 

	// Step 1: Load the Teacher_Year_Analysis data file.
	
	use "${analysis}\Teacher_Year_Analysis", clear
	isid tid school_year
	
	// Step 2: Restrict the analysis sample. Keep only employees who are teachers. Drop
	// the first year of data, since new hires are not defined for that year. Drop 
	// records with missing values for variables important to the analysis.
	
	keep if (school_year > 2010)
	keep if !missing(t_new_hire)
	keep if !missing(t_novice)
	keep if !missing(t_experience)
	
	// Step 3: Review the values of variables to be used in the analysis.
	
	tab t_new_hire, mi
	tab t_novice, mi
	tab t_novice t_new_hire, mi col
	
	// Step 4: Define a new variable which includes both novice and experienced 
	// new hires.
	
	gen pie_hire = .
	replace pie_hire = 1 if t_new_hire == 0
	replace pie_hire = 2 if t_new_hire == 1 & t_novice == 1
	replace pie_hire = 3 if t_new_hire == 1 & t_novice == 0
	tab pie_hire, mi
	
	// Step 5: Calculate and store sample sizes for the chart footnote.
	
	summ tid
	local teacher_years = string(r(N), "%9.0fc")
	preserve 
		bys tid: keep if _n == 1
		summ tid
		local unique_teachers = string(r(N), "%9.0fc")
	restore
	
	// Step 6: Create a pie chart. Footnote text is flush left to allow 
	// wrapping lines without inserting tabs in footnote.
	
	#delimit ;
	graph pie, over (pie_hire) angle(-50) 	
		pie(1, color(dknavy))
		pie(2, color(maroon))
		pie(3, color(forest_green))
		plabel(_all percent, format(%3.0f) color(white) size(*1.2))
		plabel(1 "Experienced" "Teachers", gap(30) color(black) size(medsmall))
		plabel(2 "Novice" "New Hires", gap(30) color(black) size(medsmall))
		plabel(3 "Experienced" "New Hires", gap(30) color(black) size(medsmall))
		legend(off)
		graphregion(color(white) fcolor(white) lcolor(white))
		plotregion(color(white) fcolor(white) lcolor(white) margin(1 1 3 3))
		title("Share of Teachers Who Are New Hires", span)
		note(" " "Notes: Sample includes teachers in the 2010-11 through 2014-15 
school years, with `teacher_years' teacher years and `unique_teachers' unique 
teachers." "Novices were in their first year of teaching.", size(vsmall) span);
	#delimit cr
	
	// Step 7: Save the chart in Stata Graph and EMF formats.
	
	graph export "${graphs}/Share_of_Teachers_New_Hires.emf", replace 
	graph save "${graphs}/Share_of_Teachers_New_Hires.gph", replace 
	
}

/*** A2. Share of Teachers Who Are New Hires by School Year ***/ 

if ${new_hires_year}==1 { 
	
	// Step 1: Load the Teacher_Year_Analysis data file.
	
	use "${analysis}\Teacher_Year_Analysis.dta", clear
	isid tid school_year
		
	// Step 2: Restrict the analysis sample.
	
	keep if school_year > 2010
	keep if !missing(t_new_hire)
	keep if !missing(t_novice)
	keep if !missing(t_experience)
	
	// Generate missing t_veteran_new_hire variable
	gen t_veteran_new_hire = 0 if !missing(t_experience)
	replace t_veteran_new_hire = 1 if t_new_hire == 1 & t_novice == 0 & !missing(t_experience)
	
	assert !missing(t_experience, t_veteran_new_hire)
	
	// Step 3: Review variables to be used in the analysis.
	
	tab school_year t_novice, mi row
	tab school_year t_veteran_new_hire, mi row
	tab t_novice t_veteran_new_hire
	
	// Step 4: Calculate sample size. 
	
	summ tid
	local teacher_years = string(r(N), "%9.0fc")
	preserve 
		bys tid: keep if _n == 1
		summ tid
		local unique_teachers = string(r(N), "%9.0fc")
	restore
	
	// Step 5: Calculate significance indicator variables by year.
	
	foreach var in t_novice t_veteran_new_hire {
		gen sig_`var' = .
		xi: reg `var' i.school_year, robust
	
		forvalues year = 2012/2015 {
			replace sig_`var' = abs(_b[_Ischool_ye_`year'] / _se[_Ischool_ye_`year']) ///
				if school_year == `year'
			replace sig_`var' = 0 if sig_`var' <= 1.96 & school_year == `year'
			replace sig_`var' = 1 if sig_`var' > 1.96 & school_year == `year'
		}
		replace sig_`var' = 0 if school_year == 2011
	}
		
	// Step 6: Collapse the teacher-level data file to calculate percent of new hires
	// by year.
	
	collapse (mean) t_novice t_veteran_new_hire sig_*, by(school_year)
	foreach var in t_novice t_veteran_new_hire {
		replace `var' = 100 * `var'
	}
	
	// Step 7: Concatenate values and significance asterisks to make value labels.
	
	foreach var of varlist t_novice t_veteran_new_hire {
		tostring(sig_`var'), replace
		replace sig_`var' = "*" if sig_`var' == "1"
		replace sig_`var' = "" if sig_`var' == "0"
		gen `var'_str = string(`var', "%9.0f")
		egen `var'_label = concat(`var'_str sig_`var')
	}
	
	// Step 8: Get the total new hire percent for each year for graphing.
	
	gen t_total = t_novice + t_veteran_new_hire
		
	// Step 9: Create a stacked bar graph using overlaid bars. Use scatter plots with
	// invisible symbols for the value labels. 
	
	#delimit ;
	twoway (bar t_total school_year, 
			fcolor(forest_green) lcolor(forest_green) lwidth(0) barwidth(0.75))
		(bar t_novice school_year, 
			fcolor(maroon) lcolor(maroon) lwidth(0) barwidth(0.75)) 
		(scatter t_total school_year, 
			mcolor(none) mlabel(t_veteran_new_hire_label) mlabcolor(white) mlabpos(6)  
			mlabsize(small)) 
		(scatter t_novice school_year, 
			mcolor(none) mlabel(t_novice_label) mlabcolor(white) mlabpos(6)  
			mlabsize(small)), 
		title("Share of Teachers Who Are New Hires", span) 
		subtitle("by School Year", span) 
		ytitle("Percent of Teachers") 
		ylabel(0(10)30, nogrid labsize(medsmall)) 
		xtitle("") 
		xlabel(2011 "2010-11" 2012 "2011-12" 2013 "2012-13" 2014 "2013-14" 2015 "2014-15", 
			labsize(medsmall)) 
		legend(order(1 "Experienced New Hires" 2 "Novice New Hires")
			ring(0) position(11) symxsize(2) symysize(2) rows(2) size(medsmall) 
			region(lstyle(none) lcolor(none) color(none))) 
		graphregion(color(white) fcolor(white) lcolor(white)) 
		plotregion(color(white) fcolor(white) lcolor(white) margin(2 0 2 0))
		note(" " "*Significantly different from 2010-2011 value, at the 95 percent confidence level."
			"Notes: Sample includes teachers in the 2009-10 through 2014-15 school years, with `teacher_years' teacher years and `unique_teachers' unique teachers." 
			"Novices were in their first year of teaching.", size(vsmall) span);
	#delimit cr
	
	// Step 10: Save the chart in Stata Graph and EMF formats.
	
	graph export "${graphs}/New Hires_by_School_Year.emf", replace 
	graph save "${graphs}/New Hires_by_School_Year.gph", replace 
	
}
	
/*** A3. Share of Teachers Who Are New Hires by School Poverty Level ***/
 
if ${new_hires_school_poverty}==1 { 
	
	// Step 1: Load the Teacher_Year_Analysis data file. 
	
	use "${analysis}\Teacher_Year_Analysis.dta", clear 
	isid tid school_year
	
	// Generate missing t_veteran_new_hire, school_poverty_quartile
	gen t_veteran_new_hire = 0 if !missing(t_experience)
	replace t_veteran_new_hire = 1 if t_new_hire == 1 & t_novice == 0 & !missing(t_experience)
	
	preserve
	
		keep school_code school_year sch_frpl_pct
		drop if mi(school_code) | mi(school_year) | mi(sch_frpl_pct)
		collapse (mean) sch_frpl_pct, by(school_code school_year)
		isid school_code school_year
		gen school_poverty_quartile = .
		forval year = 2010/2015 {
			xtile temp_poverty_quartile = sch_frpl_pct if school_year == `year', nq(4)
			replace school_poverty_quartile = temp_poverty_quartile if school_year == `year'
			drop temp_poverty_quartile
		}
		assert !missing(school_poverty_quartile)
		label define pvt 1 "Lowest percentage of FRPL-eligible students"
		label define pvt 2 "Second-lowest percentage of FRPL-eligible students" , add
		label define pvt 3 "Second-highest percentage of FRPL-eligible students" , add
		label define pvt 4 "Highest percentage of FRPL-eligible students", add
		label values school_poverty_quartile pvt
		drop sch_frpl_pct

		tempfile school_poverty_qrt
		save `school_poverty_qrt'
	
	restore
	merge m:1 school_code school_year using `school_poverty_qrt', keep(1 2 3) nogen	
	
	// Step 2: Restrict the analysis sample.
	
	keep if school_year > 2010
	keep if !missing(t_new_hire)
	keep if !missing(t_novice)

	keep if !missing(school_poverty_quartile)
	keep if !missing(t_experience, t_veteran_new_hire)
	
	// Step 3: Review variables used in the analysis.
	
	tab school_poverty_quartile, mi
	tab school_poverty_quartile t_novice, mi row
	tab school_poverty_quartile t_veteran_new_hire, mi row
	
	// Step 4: Calculate sample size. 
	
	summ tid
	local teacher_years = string(r(N), "%9.0fc")
	preserve 
		bys tid: keep if _n == 1
		summ tid
		local unique_teachers = string(r(N), "%9.0fc")
	restore
	
	// Step 5: Calculate significance indicator variables by school poverty quartile.
	
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

	// Step 6: Collapse to calculate shares of new hires in each quartile.
	
	collapse (mean) t_novice t_veteran_new_hire sig_*, by(school_poverty_quartile)
	foreach var of varlist t_novice t_veteran_new_hire {
		replace `var' = 100 * `var'
	}

	// Step 7: Concatenate values and significance asterisks to make value labels.
	
	foreach var of varlist t_novice t_veteran_new_hire {
		tostring(sig_`var'), replace
		replace sig_`var' = "*" if sig_`var' == "1"
		replace sig_`var' = "" if sig_`var' == "0"
		gen `var'_str = string(`var', "%9.0f")
		egen `var'_label = concat(`var'_str sig_`var')
	}
	
	// Step 8: Get the total new hire percent for each year for graphing.
	
	gen t_total = t_novice + t_veteran_new_hire

	// Step 9: Create a bar graph using twoway bar and scatter for the labels.
	
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
		title("Share of Teachers Who Are New Hires", span) 
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
and `unique_teachers' unique teachers. Novices were" "in their first year of teaching.", 
	size(vsmall) span);
	#delimit cr
	
	// Step 10: Save the chart in Stata Graph and EMF formats. If marker labels need to be
	// moved by hand using Stata Graph Editor, re-save .gph and .emf files after editing.
	
	graph export "${graphs}/New_Hires_by_Poverty_Quartile.emf", replace 
	graph save "${graphs}/New_Hires_by_Poverty_Quartile.gph", replace 
	
}
	

/*** A4. Share of Teachers and Students by Race ***/ 

if ${share_teachers_stu_race}==1 {

	// Step 1: Set up matrix to hold teacher, new teacher, and student results.
	
	matrix race = J(4, 4, .)
	matrix colnames race = race teacher new_teacher student
	
	// Step 2: Load the Teacher_Year_Analysis data file. 
	
	use "${analysis}\Teacher_Year_Analysis.dta", clear
	isid tid school_year
	
	// Generate missing teacher race/ethnicity variables
	
	gen t_black = (t_race_ethnicity == 1)
	gen t_asian = (t_race_ethnicity == 2)
	gen t_latino = (t_race_ethnicity == 3)
	gen t_naam = (t_race_ethnicity == 4)
	gen t_white = (t_race_ethnicity == 5)
	gen t_mult = (t_race_ethnicity == 6)
	gen t_racemiss = (t_race_ethnicity == 7) | (t_race_ethnicity == .)
	
	// Step 3: Restrict the teacher sample.
	
	keep if school_year == 2015
	keep if !missing(t_race_ethnicity)
	keep if !missing(t_new_hire)
	
	// Step 4: Review teacher variables.
	
	tab school_year t_race_ethnicity, mi
	tab t_new_hire t_white, mi row
	tab t_new_hire t_black, mi row
	tab t_new_hire t_latino, mi row
	tab t_new_hire t_asian, mi row
		
	// Step 5: Get teacher sample sizes.
	
	summ tid
	local teacher_years = string(r(N), "%6.0fc")
	preserve 
		bys tid: keep if _n == 1
		summ tid
		local unique_teachers = string(r(N), "%6.0fc")
	restore
	
	// Step 6: Store percentages by race for all teachers and newly hired teachers. 
	
	local i = 1
	foreach race of varlist t_white t_black t_latino t_asian {
		matrix race[`i', 1] = `i'
		summ `race'
		matrix race[`i', 2] = 100 * r(mean)
		summ `race' if t_new_hire == 1
		matrix race[`i', 3] = 100 * r(mean)
		local i = `i' + 1
	}
	
	// Step 7: Load the Connect_Step1 data file to get student data.
	
	use "${analysis}\Student_School_Year.dta", clear
	
	// Step 8: Make the file unique by sid and school_year.
	
	keep sid school_year s_race_ethnicity
	duplicates drop
	isid sid school_year
	
	// Step 9: Restrict the student sample.
	
	keep if school_year == 2015
	keep if !missing(s_race_ethnicity)
	
	// Step 10: Review student variables.
	tab school_year s_race_ethnicity, mi
	
	// Step 11: Create dummy variables for major student race/ethnicity categories.
	
	gen s_black = (s_race_ethnicity == 1)
	gen s_asian = (s_race_ethnicity == 2)
	gen s_latino = (s_race_ethnicity == 3)
	gen s_white = (s_race_ethnicity == 5)
	
	// Step 12: Get student sample sizes.
	
	summ sid
	local student_years = string(r(N), "%9.0fc")
	preserve
		bys sid: keep if _n == 1
		summ sid
		local unique_students = string(r(N), "%9.0fc")
	restore
	
	// Step 13: Store percentages by race for students.
	
	local i = 1
	foreach race of varlist s_white s_black s_latino s_asian{
		summ `race'
		matrix race[`i', 4] = 100 * r(mean)
		local i = `i' + 1
	}
	
	// Step 14: Replace the dataset with the matrix of results.
	
	clear 
	svmat race, names(col)
	
	// Step 15: Graph the results.
	
	#delimit ;
	graph bar teacher new_teacher student, 
		bar(1, fcolor(dknavy) lcolor(dknavy)) 
		bar(2, fcolor(dknavy*.7) lcolor(dknavy*.7)) 
		bar(3, fcolor(maroon) lcolor(maroon))
		blabel(bar, position(outside) color(black) format(%10.0f))
		over(race, relabel(1 "White" 2 "Black" 3 "Latino" 4 "Asian") 
			label(labsize(medsmall)))
		title("Share of Teachers and Students", span)
		subtitle("by Race", span)
		ytitle("Percent", size(medsmall))
		ylabel(0(20)100, labsize(medsmall) nogrid)
		legend(order(1 "All Teachers" 2 "Newly Hired Teachers" 3 "Students")
			position(6) symxsize(2) symysize(2) rows(1)
			size(medsmall) region(lstyle(none) lcolor(none) color(none)))
		graphregion(color(white) fcolor(white) lcolor(white))
		plotregion(color(white) fcolor(white) lcolor(white) margin(5 5 2 0))
		note(" " "Notes: Sample includes teachers and students in the 2014-15 school year, 
with `unique_teachers' unique teachers and `unique_students' unique students.", size(vsmall) 
span);		
	#delimit cr
	
	// Step 16: Save the chart.
	
	graph export "${graphs}/Share_Teachers_Students_by_Race.emf", replace 
	graph save "${graphs}/Share_Teachers_Students_by_Race.gph", replace 
	
}

log close
