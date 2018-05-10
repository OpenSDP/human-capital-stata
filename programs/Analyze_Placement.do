/*****************************************************************************************
* SDP Version 1.0
* Last Updated: May 8, 2018
* File name: Analyze_Placement.do
* Author(s): Strategic Data Project
*  
* Description: This program produces analyses that show teacher placement practices by: 
* 1. Reporting the characteristics of teachers in the highest- and lowest-poverty schools.
* 2. Comparing the prior-year test scores of students in early career teachers' classrooms
*    with those of veteran teachers' students.  
*
* Inputs: Teacher_Year_Analysis.dta
*		  Student_Teacher_Year_Analysis.dta 
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

	// Define file locations.
	
	global analysis ".\data\analysis_toolkit"
	global graphs 	".\tables_figures"
	global log 		".\logs"
	global docs		".\docs"

	// Open log file.
	
	log using "${log}\Analyze_Placement.txt", text replace

	// Set program switches for placement analyses. Set switch to 0 to skip the 
	// section of code that runs a given analysis, and to 1 to run the analysis.
	
	global teacher_char_by_school_poverty	= 1
	global student_prior_ach_by_tchr_exp	= 1

/*** 1. Teacher Characteristics by School Poverty ***/ 

if ${teacher_char_by_school_poverty} == 1 { 
	
	// Step 1: Load the Teacher_Year_Analysis data file. 
	
	use "${analysis}\Teacher_Year_Analysis.dta", clear
	isid tid school_year

	// Step 2: Restrict the sample.
	
	keep if t_is_teacher == 1 
	keep if !missing(school_poverty_quartile)
		
	// Step 3: Review variables.
	
	tab school_year school_poverty_quartile, mi row
	bysort school_code school_year: gen tag = _n == 1
	tab school_year school_poverty_quartile if tag, mi
	drop tag
	foreach var of varlist t_male t_black t_latino t_white t_newhire ///
		t_adv_degree t_certification_pathway {
		tab school_poverty_quartile `var', mi row
	}
	table school_poverty_quartile, c(mean t_experience)
	
	// Step 4: Create binary variables for each school poverty quartile.
	
	tab school_poverty_quartile, gen(school_poverty_q)
	
	// Step 5: Create a binary variable for alternative certification. 
	
	gen t_alternative_certification = (t_certification_pathway > 1 & ///
		t_certification_pathway != .) 
	tab t_alternative_certification t_certification_pathway, mi 	

	// Step 6: Get overall sample size.
	
	summ tid
	local teacher_years = string(r(N), "%9.0fc")
	preserve 
		bysort tid: keep if _n == 1
		summ tid
		local unique_teachers = string(r(N), "%9.0fc")
	restore

	// Step 7: Define row titles for the table.
	
	local t_male "Percent Male"
	local t_black "Percent African American"
	local t_latino "Percent Latino"
	local t_white "Percent White"
	local t_newhire "Percent New Hires"
	local t_adv_degree "Percent with Advanced Degree"
	local t_alternative_certification "Percent with Alternative Certification"
	local t_experience "Average Teacher Experience"
	
	// Step 8: Open output file.

	putexcel set ${graphs}\Teacher_Char_by_School_Poverty.xlsx, sheet(Sheet1) replace
		
	// Step 9: Create local row number variable.
	
	local rownum = 1
	
	// Step 10: Write overall and column titles in appropriate cells.
	
	putexcel A`rownum':F`rownum' = "Teacher Characteristics by School Poverty Level", merge hcenter vcenter bold font(calibri, 20, black)
	local rownum = `rownum' + 1
	putexcel B`rownum' = "Agency Average", bold txtwrap hcenter
	putexcel C`rownum' = "High Poverty Schools", bold txtwrap hcenter
	putexcel D`rownum' = "Low Poverty Schools", bold txtwrap hcenter
	putexcel E`rownum' = "Difference between High and Low Poverty Schools", bold txtwrap hcenter
	
	// Step 11: Start a loop through row variables, incrementing rownum.
	
	foreach rowvar of varlist t_male t_black t_latino t_white t_newhire ///
		t_adv_degree t_alternative_certification t_experience {
		
		local rownum = `rownum' + 1		

		// Step 12: Calculate quartile averages and difference.
		
		reg `rowvar' school_poverty_q4 school_poverty_q1, robust
		estimates store `rowvar'
		local highpov = _b[school_poverty_q4] + _b[_cons]
		local lowpov = _b[school_poverty_q1] + _b[_cons]
		local diff = _b[school_poverty_q4] - _b[school_poverty_q1]
		
		// Step 13: Get significance for difference between top and bottom quartile.
		
		test school_poverty_q4 = school_poverty_q1
		gen star = ""
		replace star = "*" if r(p) < .05
		
		// Step 14: Caclulate agency average.
		
		quietly summ `rowvar', meanonly
		local agencyavg = r(mean)

		// Step 15: Write values for high, low, difference, and significance for each 
		//row variable.
		
		putexcel A`rownum' = "``rowvar''", bold
		putexcel B`rownum' = `agencyavg'*100, nformat("###.#") 
		putexcel C`rownum' = `highpov'*100, nformat("###.#")
		putexcel D`rownum' = `lowpov'*100, nformat("###.#")
		putexcel E`rownum' = `diff'*100, nformat("###.#")
		putexcel F`rownum' = "`:di %3s star'"
		drop star 
		
	}
	
	// Step 16: Write footnote including sample sizes.
	
	#delimit ;
	putexcel A`rownum':F`rownum' = "*Difference is statistically significant at the 95 percent
confidence level.", nobold merge;
	local rownum = `rownum' + 1;
	putexcel A`rownum':F`rownum' = "Notes: Sample includes teachers in the 2006-07 through 2010-11 
school years, with `teacher_years' teacher years and `unique_teachers' unique teachers. 
High (low) poverty schools are in the top (bottom) quartile of schools each year based 
on the share of students receiving free or reduced price lunch.", merge txtwrap;
	#delimit cr
	
	// Step 17: Format column widths and heights to fit text.
	
	mata
	b = xl()
	b.load_book("${graphs}\Teacher_Char_by_School_Poverty.xlsx")
	b.set_sheet("Sheet1")
	b.set_column_width(1,1,33) //make title column widest
	b.set_column_width(2,7,15) //make each column fit title
	b.set_column_width(5,5,18) //make difference column wider to fit title
	b.set_row_height(1,1,55) //make title row bigger
	b.set_row_height(11,11,70)
	
	
	// Step 18: Close file.
	
	b.close_book()
	end
	
	// If desired, manually save file as png in excel.
	
}

/*** 2. Student Prior Achievement by Teacher Experience ***/

if ${student_prior_ach_by_tchr_exp} == 1 { 
	
	// Step 1: Choose the subject (math or ela) and school level (elem or 
	// middle) for the analysis. Note: to make multiple charts at the same time, 
	// put loops for subject and level around the analysis and graphing code.
	// To include all grade levels in the analysis, comment out the local level 
	// command below.
	
	local subject math
	local level middle
	
	// Step 2: Load the Student_Teacher_Year_Analysis data file. 
	
	use "${analysis}\Student_Teacher_Year_Analysis.dta", clear
	isid sid school_year

	// Step 3: Restrict the sample. Keep grades and years for which prior-year test scores
	// are available. Keep students with teachers with non-missing values for experience. 
	// Keep students with a single identified current-year core course and prior-year test 
	// score in the given subject. If school level restriction is chosen, keep only 
	// records from either elementary or middle school grades.
	
	keep if school_year >= 2008 & school_year <= 2011
	keep if grade_level >= 5 & grade_level <= 8
	keep if t_is_teacher == 1
	keep if !missing(t_experience)
	keep if !missing(cid_`subject')
	keep if !missing(std_scaled_score_`subject'_tm1)
	if "`level'" == "elem" {	
		keep if grade_level == 5
	}
	if "`level'" == "middle" {
		keep if grade_level >= 6 & grade_level <= 8
	}
	
	// Step 4: Review teacher and student variables.
	
	tab school_year grade_level, mi
	unique tid_`subject'
	unique tid_`subject' school_year
	bysort tid_`subject' school_year: gen tag = (_n == 1)
	tab t_experience if tag == 1, mi
	drop tag
	table t_experience, c(mean std_scaled_score_`subject'_tm1)
	codebook cid_`subject' tid_`subject' school_year t_experience ///
		std_scaled_score_`subject' std_scaled_score_`subject'_tm1 ///
		grade_level school_code 
	
	// Step 5: Define dummy variables for teaching experience. Put teachers
	// with six or more years of experience into one category.
	
	replace t_experience = 6 if t_experience > 5 & !missing(t_experience)
	tab t_experience, gen(exp)
	
	// Step 6: Define grade-by-year variable for fixed effects.	
	
	egen grade_year = group(grade_level school_year)
	
	// Step 7: Define grade-by-year-by-school variable for fixed effects.
	
	egen grade_year_school = group(school_code grade_level school_year)
	
	// Step 8: Define 5 x 4 matrix to store results.
	
	matrix results = J(5, 4, .)
	matrix colnames results = across_school_coef across_school_se ///
		within_school_coef within_school_se

	// Step 9: Do regression of prior student math score on teacher experience. 
	// Sixth plus year teachers are comparison group.
	
	areg std_scaled_score_`subject'_tm1 exp1-exp5, robust cluster(cid_`subject') ///
		absorb(grade_year)
	
	// Step 10: Get student and teacher sample sizes.
	
	egen teacher_years = nvals(tid_`subject' school_year) if e(sample)
	summ teacher_years
	local teacher_years = string(r(mean), "%9.0fc")
	egen unique_teachers = nvals(tid_`subject') if e(sample)
	summ unique_teachers
	local unique_teachers = string(r(mean), "%9.0fc")
	
	egen student_years = nvals(sid school_year) if e(sample)
	summ student_years
	local student_years = string(r(mean), "%9.0fc")
	egen unique_students = nvals(sid) if e(sample)
	summ unique_students
	local unique_students = string(r(mean), "%9.0fc")
	
	// Step 11: Store coefficients in the first column and and standard errors in 
	// the second column of the results matrix.
	
	matrix results[1, 1] = _b[exp1]
	matrix results[2, 1] = _b[exp2]
	matrix results[3, 1] = _b[exp3]
	matrix results[4, 1] = _b[exp4]
	matrix results[5, 1] = _b[exp5]
	
	matrix results[1, 2] = _se[exp1]
	matrix results[2, 2] = _se[exp2]
	matrix results[3, 2] = _se[exp3]
	matrix results[4, 2] = _se[exp4]
	matrix results[5, 2] = _se[exp5]

	// Step 12: Add school fixed effects to prior model to generate within school 
	// comparison.
	
	areg std_scaled_score_`subject'_tm1 exp1-exp5, robust cluster(cid_`subject') ///
		absorb(grade_year_school)
		
	// Step 13: Store coefficients and standard errors in columns 3 and 4 of results 
	// matrix.
	
	matrix results[1, 3] = _b[exp1]
	matrix results[2, 3] = _b[exp2]
	matrix results[3, 3] = _b[exp3]
	matrix results[4, 3] = _b[exp4]
	matrix results[5, 3] = _b[exp5]
	
	matrix results[1, 4] = _se[exp1]
	matrix results[2, 4] = _se[exp2]
	matrix results[3, 4] = _se[exp3]
	matrix results[4, 4] = _se[exp4]
	matrix results[5, 4] = _se[exp5]

	// Step 14: Clear data and replace with matrix contents. Add variable for year 
	// teaching.
	
	clear
	svmat results, names(col)
	gen year_teaching = _n
	
	// Step 15: Get and store significance. Concatenate coefficient and asterisk 
	// to use as value label.
	
	foreach model in across_school within_school {
		gen `model'_sig = abs(`model'_coef / `model'_se)
	}
	foreach var of varlist across_school_sig within_school_sig {
		replace `var' = 0 if `var' < =1.96
		replace `var' = 1 if `var' > 1.96
		tostring `var', replace
		replace `var' = "" if `var' == "0"
		replace `var' = "*" if `var' == "1"
	}
	
	foreach model in across_school within_school {
		gen `model'_string = string(`model'_coef, "%9.2f")
		egen `model'_label = concat(`model'_string `model'_sig)
	}
				
	// Step 16: Define titles for subject and school level.
	
	if "`subject'" == "math" { 
		local subj_title "Math" 
		local subj_foot "math" 
	}
	if "`subject'"=="ela" {
		local subj_title "ELA"
		local subj_foot "English/Language Arts"
	} 
	
	local gradespan "5th through 8th"
	
	if "`level'" == "middle" {
		local level_title "Middle "
		local gradespan "6th through 8th"
	}
	
	if "`level'" == "elem" {
		local level_title "Elementary "
		local gradespan "5th"
	}
	
	// Step 17: Start loop through models to make and save across and within schools 
	// charts.
	
	foreach model in across within {
				
		// Step 18: Define subtitle.
		
		if "`model'" == "across" {
			local subtitle "Across `level_title'Schools"
		}
		if "`model'" == "within" {
			local subtitle "Within `level_title'Schools"
		}
	
		// Step 19: Make chart. Bar chart gives average score difference relative to 6th 
		// plus year teachers, while scatter plot places value and significance asterisk 
		// as marker label below bar. Marker symbol is invisible.
	
		#delimit ;
		
		twoway bar `model'_school_coef year_teaching, 
			barwidth(.6) color(navy) finten(100) ||
			
		scatter `model'_school_coef year_teaching, 
			mlabel(`model'_school_label) 
			msymbol(i) 
			mlabpos(6) 
			mlabcolor(black) ||,
			
			ytitle("Difference in Prior-Year Test Scores", size(medsmall)) 
			title("Difference in Average Prior `subj_title' Performance"
				"of Students Assigned to Early-Career Teachers"
				"Compared to Teachers with Six or More Years of Teaching", span) 
			subtitle("`subtitle'", span) 
			xtitle("Year Teaching", size(medsmall)) 
			xlabel(,labsize(medsmall))
			legend(off) 

			yline(0, lpattern(dash) lcolor(black)) 
			yscale(range(-.4 .2)) 
			ylabel(-.4(.1).2, nogrid labsize(medsmall)) 
			ytick(-.4(.1).2) 
			graphregion(color(white) fcolor(white) lcolor(white))
			plotregion(color(white) fcolor(white) lcolor(white) margin(5 5 2 0))
			
			note(" " "*Significantly different from zero, at the 95 percent confidence 
level." "Notes: Sample includes `gradespan' grade `subj_foot' teachers and students in
the 2007-08 through 2010-11 school years," "with `teacher_years' teacher years, 
`unique_teachers' unique teachers, `student_years' student years, and `unique_students'
unique students. Test scores are measured in standard deviations.", size(vsmall) span);	
	
		#delimit cr
	
		// Step 20: Save chart. If marker labels need to be moved by hand using Stata 
		// Graph Editor, re-save .gph and .emf files after editing.
		
		graph export "${graphs}/Prior_Ach_by_Exp_`subtitle'_`subj_title'.emf", replace 
		graph save "${graphs}/Prior_Ach_by_Exp_`subtitle'_`subj_title'.gph", replace
		graph export "${docs}/Prior_Ach_by_Exp_`subtitle'_`subj_title'.png", replace
		
	}

}

log close
