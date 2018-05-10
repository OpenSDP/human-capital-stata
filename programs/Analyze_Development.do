/*****************************************************************************************
* SDP Version 1.0
* Last Updated: May 8, 2018
* File Name: Analyze_Development.do
* Author(s): Strategic Data Project
*
* Description: This program produces analyses that show the development of the teacher
* workforce by:
* 1. Describing the growth in effectiveness for early-career teachers.
* 2. Examining the difference in effectiveness for teachers with and without advanced 
*    degrees.
*
* Inputs: 	Teacher_Year_Analysis.dta
*			Student_Teacher_Year_Analysis.dta
*
*****************************************************************************************/

	// Close log file if open and set up environment.
	
	capture log close
	clear all
	set mem 1000m
	set more off
	set scheme s1color

	// Edit the file path below to point to the directory with folders for data, logs,
	// programs, and tables and figures. Change to that directory.
	
	cd "C:\working_files"

	// Define file locations
	
	global analysis ".\data\analysis_toolkit"
	global graphs 	".\tables_figures"
	global log 		".\logs"
	global docs		".\docs"

	// Open log file
	
	log using "${log}\Analyze_Development.txt", text replace

	// Set program switches for development analyses. Set switch to 0 to skip the 
	// section of code that runs a given analysis, and to 1 to run the analysis.

	// Switches
	global returns_to_experience	= 1
	global return_to_adv_degree		= 1

	
/*** C1. Growth in Teacher Effects for Early Career Teachers ***/

if ${returns_to_experience} == 1 {
		
	// Step 1: Choose the subject (math or ela) and school level (elem or 
	// middle) for the analysis. Note: To change from math to ELA,
	// switch the subjects in the next two lines. To make multiple charts 
	// at the same time, put loops for subject and level around the analysis 
	// and graphing code. To include all grade levels in the analysis, 
	// comment out the local level command below.
	
	local subject math
	local alt_subject ela
	*local level middle
	
	// Step 2. Load the Student_Teacher_Year_Analysis data file.
	
	use "${analysis}\Student_Teacher_Year_Analysis.dta", clear  
	isid sid school_year
	
	// Step 3: Restrict the sample. Keep grades and years for which prior-year test scores
	// are available. Keep students with teachers with non-missing values for experience. 
	// Keep students with a single identified core course and current and prior-year test 
	// scores in the given subject. If school level restriction is chosen, keep only 
	// records from either elementary or middle school grades.
	
	keep if school_year >= 2008 & school_year <= 2011
	keep if grade_level >= 5 & grade_level <= 8
	keep if t_is_teacher == 1
	keep if !missing(t_experience)
	keep if !missing(cid_`subject')
	keep if !missing(std_scaled_score_`subject', std_scaled_score_`subject'_tm1)
	if "`level'" == "elem" {	
		keep if grade_level == 5
	}
	if "`level'" == "middle" {
		keep if grade_level >= 6 & grade_level <= 8
	}
	
	// Step 4: Review teacher variables.
	
	tab school_year
	unique tid_`subject'
	unique tid_`subject' school_year
	tab t_experience t_novice, mi
	bysort tid_`subject' school_year: gen tag = (_n == 1)
	tab t_experience if tag == 1, mi
	drop tag
	
	// Step 5: Create dummy variables for each year of teaching experience, putting all
	// teachers with 10 or more years of experience in one group.
	
	replace t_experience = 10 if t_experience >= 10
	tab t_experience, gen(exp)
		
	// Step 6: Create variable for grade-by-year fixed effects. 
	
	egen grade_by_year = group(grade_level school_year)
	
	// Step 7: Create variables for previous year's score squared and cubed.
	
	gen std_scaled_score_`subject'_tm1_sq = std_scaled_score_`subject'_tm1^2
	gen std_scaled_score_`subject'_tm1_cu = std_scaled_score_`subject'_tm1^3
		
	// Step 8: Create indicator for whether student is missing prior achievement 
	// for alternate subject. Make a replacement variable that imputes score to 
	// zero if missing.
	
	gen miss_std_scaled_score_`alt_subject'_tm1 = ///
		missing(std_scaled_score_`alt_subject'_tm1)
	gen _IMPstd_scaled_score_`alt_subject'_tm1 = std_scaled_score_`alt_subject'_tm1
	replace _IMPstd_scaled_score_`alt_subject'_tm1 = 0 ///
		if miss_std_scaled_score_`alt_subject'_tm1 == 1
		
	// Step 9: Identify prior achievement variables to use as controls.
	
	#delimit ;
	local prior_achievement 
		"std_scaled_score_`subject'_tm1 
		std_scaled_score_`subject'_tm1_sq
		std_scaled_score_`subject'_tm1_cu 
		_IMPstd_scaled_score_`alt_subject'_tm1 
		miss_std_scaled_score_`alt_subject'_tm1";
	#delimit cr
	
	// Step 10: Identify other student variables to use as controls.
	
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
	
	// Step 11: Review all variables to be included in the teacher effectiveness model.
	// Class and cohort (grade/school/year) variables should include means of all 
	// student variables, and means, standard deviations, and percent missing for 
	// prior-year test scores for both main and alternate subject. Class and 
	// cohort size should also be included as controls.
	
	codebook std_scaled_score_`subject' exp1-exp10
	codebook `prior_achievement' 
	codebook `student_controls' 
	codebook _CL*`subject'* 
	codebook _CO*
	codebook grade_by_year cid_`subject'
	
	// Step 12: Estimate growth in teacher effectiveness relative to novice teachers,
	// using within-teacher fixed effects.

	areg std_scaled_score_`subject' exp2-exp10 `prior_achievement' `student_controls' ///
		 _CL*`subject'* _CO* i.grade_by_year, absorb(tid_`subject') cluster(cid_`subject')
		 
	// Step 13: Store coefficients and standard errors.
	
	forval year = 2/10 {
		gen coef_exp`year' = _b[exp`year']
		gen se_exp`year' = _se[exp`year']
	}
	
	// Step 14: Set values to zero for novice comparison teachers.
	
	gen coef_exp1 = 0 if exp1 == 1
	gen se_exp1 = 0 if exp1 == 1
	
	// Step 15: Get teacher sample size.

	egen teacher_years = nvals(tid_`subject' school_year) if e(sample)
	summ teacher_years
	local teacher_years = string(r(mean), "%9.0fc")
	egen unique_teachers = nvals(tid_`subject') if e(sample)
	summ unique_teachers
	local unique_teachers = string(r(mean), "%9.0fc")
	
	// Step 16: Collapse and reshape data for graph.
	
	collapse (max) coef_exp* se_exp*
	gen results = 1
	reshape long coef_exp se_exp, i(results) j(year_teaching)
	rename coef_exp coef
	rename se_exp se
	
	// Step 17: Generate confidence intervals of the estimated returns to experience.
	
	gen conf_hi = coef + (se * 1.96)
	gen conf_low = coef - (se * 1.96)	
	replace coef = round(coef,.01)
		
	// Step 18: Define subject and school level titles for graph.
	
	if "`subject'" == "math" {
		local subj_foot "math"
		local subj_title "Math"
	}
	
	if "`subject'" == "ela" {
		local subj_foot "English/Language Arts"
		local subj_title "ELA"
	}
	local gradespan "5th through 8th"

	if "`level'" == "middle" {
		local subj_title "Middle School `subj_title'"
		local gradespan "6th through 8th"
	}
	
	if "`level'" == "elem" {
		local subj_title "Elementary School `subj_title'"
		local gradespan "5th"
	}
	
	// Step 19: Make chart.
	
	#delimit ;
	
	twoway rarea conf_hi conf_low year_teaching if year_teaching <= 10,
		sort
		color(ltblue) ||
		
		scatter coef year_teaching,
			mlab(coef) mlabposition(12) mcolor(dknavy) mlabcolor(dknavy)
			yline(0, lcolor(gs7) lpattern(dash)) 
			yscale(range(-.05(.05).3))
			ylabel(0(.1).4, labsize(medsmall) nogrid)
			ytick(0(.1).4) ||,
		
		graphregion(color(white) fcolor(white) lcolor(white)) 
		plotregion(color(white) fcolor(white) lcolor(white)) 
		
		title("Growth in `subj_title' Teacher Effects", span)
		subtitle("Compared to First Year of Teaching", span)
		ytitle("Difference in Teacher Effects", size(medsmall))
		legend(order(2 1 3) 
		label(2 "Teacher Effect")  
		label(1 "95% Confidence Interval")) 
		legend(cols(2) symxsize(5) ring(1) region(lstyle(none) lcolor(none) color(none))) 
	
		xtitle("Year Teaching") 
		xtick(1(1)10) 
		xscale(range(1(1)10)) 
		xlabel(1 "1" 2 "2" 3 "3" 4 "4" 5 "5" 6 "6" 7 "7" 8 "8" 9 "9" 10 "10+") 
		
		note(" " "Notes: Sample includes `gradespan' grade `subj_foot' teachers
in the 2007-08 through 2011-12 school years, with `teacher_years' teacher years and" 
"`unique_teachers' unique teachers. Teacher effects are average within-teacher
year-to-year changes, measured in student test score standard deviations.", size(vsmall) 
span);
	#delimit cr

	// Step 20: Save chart. If marker labels need to be moved by hand using Stata 
	// Graph Editor, re-save .gph and .emf files after editing.
	
	graph export "${graphs}/Returns_to_Teaching_Experience_`subj_title'.emf", replace 
	graph save "${graphs}/Returns_to_Teaching_Experience_`subj_title'.gph", replace
	graph export "${docs}/Returns_to_Teaching_Experience_`subj_title'.png", replace
	
}
/*** C2. Difference in Teacher Effects for Teachers with and without Advanced Degrees  ***/

if ${return_to_adv_degree} == 1 {
		
	// Step 1: Choose a subject for the analysis. Note: To change from math to ELA,
	// switch the subjects in the next two lines. To generate ELA and math charts
	// at the same time, enclose the analysis code within a loop.
	
	local subject math
	local alt_subject ela
	
	// Step 2. Load the Student_Teacher_Year_Analysis data file.
	
	use "${analysis}\Student_Teacher_Year_Analysis.dta", clear  
	isid sid school_year
	
	// Step 3: Restrict the sample. Keep grades and years for which prior-year test scores
	// are available. Keep students with teachers with non-missing values for experience 
	// and degree information. Keep students with a single identified core course 
	// and current and prior-year test scores in the given subject.
	
	keep if school_year >= 2008 & school_year <= 2011
	keep if grade_level >= 5 & grade_level <= 8
	keep if t_is_teacher == 1
	keep if !missing(t_adv_degree)
	keep if !missing(cid_`subject')
	keep if !missing(std_scaled_score_`subject', std_scaled_score_`subject'_tm1)
	
	// Step 4: Review teacher variables.
	
	tab school_year
	unique tid_`subject'
	unique tid_`subject' school_year
	bysort tid_`subject' school_year: gen tag = (_n == 1)
	tab t_experience t_adv_degree if tag == 1, mi
	drop tag
	
	// Step 5: Create dummy variables for each year of teaching experience.
	
	tab t_experience, gen(exp)
		
	// Step 6: Create variable for grade-by-year fixed effects. 
	
	egen grade_by_year = group(grade_level school_year)
	
	// Step 7: Create variables for previous year's score squared and cubed.
	
	gen std_scaled_score_`subject'_tm1_sq = std_scaled_score_`subject'_tm1^2
	gen std_scaled_score_`subject'_tm1_cu = std_scaled_score_`subject'_tm1^3
		
	// Step 8: Create indicator for whether student is missing prior achievement 
	// for alternate subject. Make a replacement variable that imputes score to 
	// zero if missing.
	
	gen miss_std_scaled_score_`alt_subject'_tm1 = ///
		missing(std_scaled_score_`alt_subject'_tm1)
	gen _IMPstd_scaled_score_`alt_subject'_tm1 = std_scaled_score_`alt_subject'_tm1
	replace _IMPstd_scaled_score_`alt_subject'_tm1 = 0 ///
		if miss_std_scaled_score_`alt_subject'_tm1 == 1
		
	// Step 9: Identify prior achievement variables to use as controls.
	
	#delimit ;
	local prior_achievement 
		"std_scaled_score_`subject'_tm1 
		std_scaled_score_`subject'_tm1_sq
		std_scaled_score_`subject'_tm1_cu 
		_IMPstd_scaled_score_`alt_subject'_tm1 
		miss_std_scaled_score_`alt_subject'_tm1";
	#delimit cr
	
	// Step 10: Identify other student variables to use as controls.
	
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
	
	// Step 11: Review all variables to be included in the teacher effectiveness models.
	// Class and cohort (grade/school/year) variables should include means of all 
	// student variables, and means, standard deviations, and percent missing for 
	// prior-year test scores for both main and alternate subject. Class and 
	// cohort size should also be included as controls.
	
	codebook std_scaled_score_`subject' t_adv_degree exp*
	codebook `prior_achievement' 
	codebook `student_controls' 
	codebook _CL*`subject'* 
	codebook _CO*
	codebook grade_by_year cid_`subject'
	
	// Step 12: Estimate differences in teacher effectiveness between teachers
	// with and without advanced degrees, without teacher experience controls.
	
	reg std_scaled_score_`subject' t_adv_degree ///
		`student_controls' `prior_achievement' _CL*`subject'* _CO* ///
		i.grade_by_year, cluster(cid_`subject')
		
	// Step 13: Store coefficient and standard error.
	
	gen coef_noexp = _b[t_adv_degree]
	gen se_noexp = _se[t_adv_degree]
			
	// Step 14: Get teacher sample size for this model.
	
	egen teachers_in_sample_noexp = nvals(tid_`subject') if e(sample)
	summ teachers_in_sample_noexp
	local teachers_in_sample_noexp = r(mean)	

	// Step 15: Estimate differences in teacher effectiveness between teachers
	// with and without advanced degrees, with teacher experience controls.
	
	reg std_scaled_score_`subject' t_adv_degree exp* ///
		`student_controls' `prior_achievement' _CL*`subject'* _CO* ///
		i.grade_by_year, cluster(cid_`subject')
	
	// Step 16: Store coefficient and standard error.
	
	gen coef_wexp = _b[t_adv_degree]
	gen se_wexp = _se[t_adv_degree]
			
	// Step 17: Get teacher sample size for this model and compare sample size
	// for the two models.
	
	egen teachers_in_sample_wexp = nvals(tid_`subject') if e(sample)
	summ teachers_in_sample_wexp
	local teachers_in_sample_wexp = r(mean)
	assert `teachers_in_sample_wexp' == `teachers_in_sample_noexp'
	
	// Step 18: Store teacher sample size for footnote.
	
	egen teacher_years = nvals(tid_`subject' school_year) if e(sample)
	summ teacher_years
	local teacher_years = string(r(mean), "%9.0fc")
	egen unique_teachers = nvals(tid_`subject') if e(sample)
	summ unique_teachers
	local unique_teachers = string(r(mean), "%9.0fc")
	
	// Step 19: Collapse dataset for graphing.
	
	collapse(max) coef* se*
		
	// Step 20: Get significance.
	
	foreach spec in noexp wexp {
		gen sig_`spec' = abs(coef_`spec') - 1.96 * se_`spec' > 0
	}	
			
	// Step 21: Reshape for graphing.
	
	gen results = 1 
	reshape long coef_ se_ sig_, i(results) j(spec) string
	rename coef_ coef
	rename se_ se
	rename sig_ sig
	replace spec = "1" if spec == "noexp"
	replace spec = "2" if spec == "wexp"
	destring spec, replace
	
	// Step 22: Make value labels with significance indicator.
	
	tostring sig, replace
	replace sig = "*" if sig == "1"
	replace sig = ""  if sig == "0"
	replace coef = round(coef,.001)
	egen coef_label = concat(coef sig)
		
	// Step 23: Define subject titles for graph.
	
	if "`subject'" == "math" {
		local subject_foot "math"
		local subj_title "Math"
	}
	
	if "`subject'" == "ela" {
		local subject_foot "English/Language Arts"
		local subj_title "ELA"
	}

	// Step 24: Create a bar graph of the estimation results.
	
	#delimit ;
	graph twoway (bar coef spec,
			fcolor(dknavy) lcolor(dknavy) lwidth(0) barwidth(0.7))
		(scatter coef spec,
			mcolor(none) mlabel(coef_label) mlabcolor(black) mlabpos(12)  
			mlabsize(small)),
		yline(0, style(extended) lpattern(dash) lwidth(medthin) lcolor(black))
		title("Effectiveness of `subj_title' Teachers with Advanced Degrees", 
		span) 
		subtitle("Relative to Teachers without Advanced Degrees", span) 
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
		note(" " "*Significantly different from zero, at the 95 percent confidence 
level." "Notes: Sample includes 2007-08 through 2010-11 5th through 8th grade `subj_foot'
teachers, with `teacher_years' teacher years and `unique_teachers' unique teachers." 
"Teacher effects are measured in student test score standard deviations. Advanced degrees
are master's or higher.", size(vsmall) span);	
	#delimit cr
	
	// Step 25: Save chart. If marker labels need to be moved by hand using Stata 
	// Graph Editor, re-save .gph and .emf files after editing.
	
	graph export "${graphs}/Teacher_Effects_Advanced_Degree_`subj_title'.emf", replace 
	graph save "${graphs}/Teacher_Effects_Advanced_Degree_`subj_title'.gph", replace 
	graph export "${docs}/Teacher_Effects_Advanced_Degree_`subj_title'.png", replace
			
}

log close
