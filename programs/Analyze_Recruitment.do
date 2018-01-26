/*****************************************************************************************
* SDP Version 1.0
* Last Updated: April 3, 2014
* File name: Analyze_A_Recruitment.do
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
*			Student_Teacher_Year_Analysis.dta
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
	
	cd "C:\working_files\human-capital-stata"

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
	global teacher_effects_cert_pathway	= 0
	global share_teachers_stu_race		= 1

/*** A1. Share of Teachers Who Are New Hires ***/ 

if ${new_hires_pie}==1 { 

	// Step 1: Load the Teacher_Year_Analysis data file.
	
	use "${analysis}\Teacher_Year_Analysis.dta", clear
	isid tid school_year
	
	// Step 2: Restrict the analysis sample. Keep only employees who are teachers. Drop
	// the first year of data, since new hires are not defined for that year. Drop 
	// records with missing values for variables important to the analysis.
	
	keep if school_year > 2012
	keep if !missing(t_new_hire)
	keep if !missing(t_novice)
	assert !missing(t_experience)
	
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
		note(" " "Notes: Sample includes teachers in the 2012-13 through 2014-15 
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
	
	keep if school_year > 2012
	keep if !missing(t_new_hire)
	keep if !missing(t_novice)
	
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
		xi: logit `var' i.school_year, robust
	
		forvalues year = 2014/2015 {
			replace sig_`var' = abs(_b[_Ischool_ye_`year'] / _se[_Ischool_ye_`year']) ///
				if school_year == `year'
			replace sig_`var' = 0 if sig_`var' <= 1.96 & school_year == `year'
			replace sig_`var' = 1 if sig_`var' > 1.96 & school_year == `year'
		}
		replace sig_`var' = 0 if school_year == 2013
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
		ylabel(0(10)60, nogrid labsize(medsmall)) 
		xtitle("") 
		xlabel(2013 "2012-13" 2014 "2013-14" 2015 "2014-15", 
			labsize(medsmall)) 
		legend(order(1 "Experienced New Hires" 2 "Novice New Hires")
			ring(0) position(11) symxsize(2) symysize(2) rows(2) size(medsmall) 
			region(lstyle(none) lcolor(none) color(none))) 
		graphregion(color(white) fcolor(white) lcolor(white)) 
		plotregion(color(white) fcolor(white) lcolor(white) margin(2 0 2 0))
		note(" " "*Significantly different from 2012-2013 value, at the 95 percent confidence level."
			"Notes: Sample includes teachers in the 2012-13 through 2014-15 school years, with `teacher_years' teacher years and `unique_teachers' unique teachers." 
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
		forval year = 2012/2015 {
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
	
	keep if school_year > 2012
	keep if !missing(t_new_hire)
	keep if !missing(t_novice)

	keep if !missing(school_poverty_quartile)
	assert !missing(t_experience, t_veteran_new_hire)
	
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
		ylabel(0(10)60, nogrid labsize(medsmall)) 
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
teachers in the 2012-13 through 2014-15 school years, with `teacher_years' teacher years 
and `unique_teachers' unique teachers. Novices were" "in their first year of teaching.", 
	size(vsmall) span);
	#delimit cr
	
	// Step 10: Save the chart in Stata Graph and EMF formats. If marker labels need to be
	// moved by hand using Stata Graph Editor, re-save .gph and .emf files after editing.
	
	graph export "${graphs}/New Hires_by_Poverty_Quartile.emf", replace 
	graph save "${graphs}/New Hires_by_Poverty_Quartile.gph", replace 

}
	
/*** A4. Teacher Effectiveness for Alternatively Certified Teachers ***/ 
	
if ${teacher_effects_cert_pathway}==1{

	// Step 1: Choose a subject for the analysis. Note: To change from math to ELA,
	// switch the subjects in the next two lines. To generate ELA and math charts
	// at the same time, enclose the analysis code within a loop.
	
	local subject math
	local alt_subject ela
	
	// Step 2. Load the Student_Teacher_Year_Analysis data file.
	
	use "${analysis}\Student_Teacher_Year_Analysis.dta", clear  
	isid sid school_year
	
	// Step 3: Restrict the sample. Keep only teachers in their first five years of
	// teaching. Keep grades and years for which prior-year test scores are available. 
	// Keep students with teachers with non-missing values for experience and 
	// certification pathway. Keep students with a single identified core course 
	// and current and prior-year test scores in the given subject.
	
	keep if school_year >= 2008 & school_year <= 2011
	keep if grade_level >= 5 & grade_level <= 8
	keep if t_is_teacher == 1
	keep if t_experience <= 5
	keep if !missing(t_certification_pathway)
	keep if !missing(cid_`subject')
	keep if !missing(std_scaled_score_`subject', std_scaled_score_`subject'_tm1)
	
	// Step 4: Review teacher variables.
	
	tab school_year
	unique tid_`subject'
	unique tid_`subject' school_year
	bysort tid_`subject' school_year: gen tag = (_n == 1)
	tab t_experience t_certification_pathway if tag == 1, mi
	drop tag
	
	// Step 5: Create a dummy variable for alternative certification. 
	
	gen alternative_certification = (t_certification_pathway > 1 & ///
		t_certification_pathway != .) 
	tab alternative_certification t_certification_pathway, mi 	
		
	// Step 6: Create dummy variables for each year of teaching experience.
	
	tab t_experience, gen(exp)
		
	// Step 7: Create variable for grade-by-year fixed effects. 
	
	egen grade_by_year = group(grade_level school_year)
	
	// Step 8: Create variables for previous year's score squared and cubed.
	
	gen std_scaled_score_`subject'_tm1_sq = std_scaled_score_`subject'_tm1^2
	gen std_scaled_score_`subject'_tm1_cu = std_scaled_score_`subject'_tm1^3
		
	// Step 9: Create indicator for whether student is missing prior achievement 
	// for alternate subject. Make a replacement variable that imputes score to 
	// zero if missing.
	
	gen miss_std_scaled_score_`alt_subject'_tm1 = ///
		missing(std_scaled_score_`alt_subject'_tm1)
	gen _IMPstd_scaled_score_`alt_subject'_tm1 = std_scaled_score_`alt_subject'_tm1
	replace _IMPstd_scaled_score_`alt_subject'_tm1 = 0 ///
		if miss_std_scaled_score_`alt_subject'_tm1 == 1
		
	// Step 10: Identify prior achievement variables to use as controls.
	
	#delimit ;
	local prior_achievement 
		"std_scaled_score_`subject'_tm1 
		std_scaled_score_`subject'_tm1_sq
		std_scaled_score_`subject'_tm1_cu 
		_IMPstd_scaled_score_`alt_subject'_tm1 
		miss_std_scaled_score_`alt_subject'_tm1";
	#delimit cr
	
	// Step 11: Identify other student variables to use as controls.
	
	#delimit;
	local student_controls 
		"s_male 
		s_black 
		s_asian 
		s_latino 
		s_naam 
		s_mult 
		s_racemiss 
		s_reducedlunch 
		s_freelunch 
		s_lunch_miss
		s_retained
		s_retained_miss
		s_gifted
		s_gifted_miss
		s_iep
		s_iep_miss
		s_ell
		s_ell_miss
		s_absence_high
		s_absence_miss";
	#delimit cr
	
	// Step 12: Review all variables to be included in the teacher effectiveness models.
	// Class and cohort (grade/school/year) variables should include means of all 
	// student variables, and means, standard deviations, and percent missing for 
	// prior-year test scores for both main and alternate subject. Class and 
	// cohort size should also be included as controls.
	
	codebook std_scaled_score_`subject' alternative_certification exp2-exp5
	codebook `prior_achievement' 
	codebook `student_controls' 
	codebook _CL*`subject'* 
	codebook _CO*
	codebook grade_by_year cid_`subject'
	
	// Step 13: Estimate differences in teacher effectiveness between alternatively 
	// and traditionally certified teachers, without teacher experience controls.
	
	reg std_scaled_score_`subject' alternative_certification ///
		`student_controls' `prior_achievement' _CL*`subject'* _CO* ///
		i.grade_by_year, cluster(cid_`subject')
		
	// Step 14: Store coefficient and standard error.
	
	gen coef_noexp = _b[alternative_certification]
	gen se_noexp = _se[alternative_certification]
			
	// Step 15: Get teacher sample size for this model.
	
	egen teachers_in_sample_noexp = nvals(tid_`subject') if e(sample)
	summ teachers_in_sample_noexp
	local teachers_in_sample_noexp = r(mean)	

	// Step 16: Estimate differences in teacher effectiveness between alternatively 
	// and traditionally certified teachers, with teacher experience controls.
	
	reg std_scaled_score_`subject' alternative_certification exp2-exp5 ///
		`student_controls' `prior_achievement' _CL*`subject'* _CO* ///
		i.grade_by_year, cluster(cid_`subject')
	
	// Step 17: Store coefficient and standard error.
	
	gen coef_wexp = _b[alternative_certification]
	gen se_wexp = _se[alternative_certification]
			
	// Step 18: Get teacher sample size for this model and compare sample size
	// for the two models.
	
	egen teachers_in_sample_wexp = nvals(tid_`subject') if e(sample)
	summ teachers_in_sample_wexp
	local teachers_in_sample_wexp = r(mean)
	assert `teachers_in_sample_wexp' == `teachers_in_sample_noexp'
	
	// Step 19: Store teacher sample size for footnote.
	
	egen teacher_years = nvals(tid_`subject' school_year) if e(sample)
	summ teacher_years
	local teacher_years = string(r(mean), "%9.0fc")
	egen unique_teachers = nvals(tid_`subject') if e(sample)
	summ unique_teachers
	local unique_teachers = string(r(mean), "%9.0fc")
	
	// Step 20: Collapse dataset for graphing.
	
	collapse(max) coef* se*
		
	// Step 21: Get signficance.
	
	foreach spec in noexp wexp {
		gen sig_`spec' = abs(coef_`spec') - 1.96 * se_`spec' > 0
	}	
			
	// Step 22: Reshape for graphing.
	
	gen results = 1 
	reshape long coef_ se_ sig_, i(results) j(spec) string
	rename coef_ coef
	rename se_ se
	rename sig_ sig
	replace spec = "1" if spec == "noexp"
	replace spec = "2" if spec == "wexp"
	destring spec, replace
	
	// Step 23: Make value labels with significance indicator.
	
	tostring sig, replace
	replace sig = "*" if sig == "1"
	replace sig = ""  if sig == "0"
	replace coef = round(coef,.001)
	egen coef_label = concat(coef sig)
		
	// Step 24: Define subject titles for graph.
	
	if "`subject'" == "math" {
		local subject_foot "math"
		local subject_title "Math"
	}
	
	if "`subject'" == "ela" {
		local subject_foot "English/Language Arts"
		local subject_title "ELA"
	}

	// Step 25: Create a bar graph of the estimation results.
	
	#delimit ;
	graph twoway (bar coef spec,
			fcolor(dknavy) lcolor(dknavy) lwidth(0) barwidth(0.7))
		(scatter coef spec,
			mcolor(none) mlabel(coef_label) mlabcolor(black) mlabpos(12)  
			mlabsize(small)),
		yline(0, style(extended) lpattern(dash) lwidth(medthin) lcolor(black))
		title("Effectiveness of `subject_title' Teachers with Alternative Certification", 
		span) 
		subtitle("Relative to Teachers without Alternative Certification", span) 
		ytitle("Difference in Teacher Effects", size(medsmall)) 
		yscale(range(-.05 .2)) 
		ytick(-.05(.05).2) 
		ylabel(-.05(.05).2, nogrid) 
		xlabel("", notick)
		xtitle("") 
		xlabel(1 `""Without Teacher" "Experience Controls""' 
			2 `""With Teacher" "Experience Controls""', labsize(medsmall)) 
		legend(off) 
		graphregion(color(white) fcolor(white) lcolor(white))
		plotregion(color(white) fcolor(white) lcolor(white) margin(5 5 2 0))
		note(" " "*Significantly different from zero, at the 95 percent confidence level." 
"Notes: Sample includes 2007-08 through 2010-11 5th through 8th grade `subject_foot'
teachers who were in their first five years" "of teaching, with `teacher_years' teacher
years and `unique_teachers' unique teachers. Teacher effects are measured in student test
score standard deviations.", 
	size(vsmall) span);	
	#delimit cr
	
	// Step 26: Save chart.
	
	graph export "${graphs}/A4_Teacher_Effects_Cert_Pathway_`subject_title'.emf", replace 
	graph save "${graphs}/A4_Teacher_Effects_Cert_Pathway_`subject_title'.gph", replace 
	
}		

/*** A5. Share of Teachers and Students by Race ***/ 

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
	
	keep if school_year > 2011
	keep if school_year < 2014
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
	
	keep if school_year > 2011
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
		blabel(bar, position(inside) color(white) format(%10.0f))
		over(race, relabel(1 "White" 2 "Black" 3 "Latino" 4 "Asian") 
			label(labsize(medsmall)))
		title("Share of Teachers and Students", span)
		subtitle("by Race", span)
		ytitle("Percent", size(medsmall))
		ylabel(0(20)100, labsize(medsmall) nogrid)
		legend(order(1 "All Teachers" 2 "Newly Hired Teachers" 3 "Students")
			ring(0) position(11) symxsize(2) symysize(2) rows(3)
			size(medsmall) region(lstyle(none) lcolor(none) color(none)))
		graphregion(color(white) fcolor(white) lcolor(white))
		plotregion(color(white) fcolor(white) lcolor(white) margin(5 5 2 0))
		note(" " "Notes: Sample includes teachers in the 2011-12 through 2012-13 school 
years, with `teacher_years' teacher years, `unique_teachers' unique teachers," 
"`student_years' student years, and `unique_students' unique students.", size(vsmall) 
span);		
	#delimit cr
	
	// Step 16: Save the chart.
	
	graph export "${graphs}/Share_Teachers_Students_by_Race.emf", replace 
	graph save "${graphs}/Share_Teachers_Students_by_Race.gph", replace 
}

log close
