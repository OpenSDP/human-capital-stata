---
title: "Inspect Teacher Characteristics by School Poverty"
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

[OpenSDP Analysis](http://opensdp.github.io/analysis) / [Human Capital Analysis: Placement](Human_Capital_Analysis_Placement.html) / Inspect Teacher Characteristics by School Poverty

![](Teacher_Char_by_School_Poverty.png)

###Preparation
####Purpose

Examine the distribution of teachers across school characteristics.

####Required analysis file variables

 - `tid`
 - `school_year`
 - `school_poverty_quartile`
 - `t_node`
 - `t_black`
 - `t_latino`
 - `t_white`
 - `t_newhire`
 - `t_adv_degree`
 - `t_certification_pathway`
 - `t_experience`


####Analysis-specific sample restrictions

 - Keep only employees whose job code is "teacher".
 - Keep only years for which new line information is available. 

####Ask yourself

 - What supports could your agency offer to high-poverty schools with large shares of novice and early-career teachers? 
 - Does your agency have a strategy for placing effective teachers in high-needs schools? What initiatives would support this goal? 

####Potential further analyses

- Other teacher characteristics to add to the table if data are available include: attended a competitive postsecondary institution; master teacher, instructional mentor, other teacher leadership role. You may wish to explore to what extent these teacher characteristics are associated with value-added estimates of teacher effectiveness.

###Analysis

####Step 1: Load data. 


```stata
use "${analysis}\Teacher_Year_Analysis.dta", clear  
isid tid school_year
```

####Step 2: Restrict the sample.


```stata
keep if t_is_teacher == 1 
keep if !missing(school_poverty_quartile)
```

####Step 3: Review variables.


```stata
tab school_year school_poverty_quartile, mi row
bysort school_code school_year: gen tag = _n == 1
tab school_year school_poverty_quartile if tag, mi
drop tag
foreach var of varlist t_male t_black t_latino t_white t_newhire ///
	t_adv_degree t_certification_pathway {
	tab school_poverty_quartile `var', mi row
} 
table school_poverty_quartile, c(mean t_experience) 
```

####Step 4: Create binary variables for each school poverty quartile.


```stata
tab school_poverty_quartile, gen(school_poverty_q)
```

####Step 5: Create a binary variable for alternative certification.
Create variable for grade-by-year fixed effects.


```stata
gen t_alternative_certification = (t_certification_pathway > 1 & ///
	t_certification_pathway != .) 
tab t_alternative_certification t_certification_pathway, mi
```

####Step 6: Get overall sample size.


```stata
summ tid
local teacher_years = string(r(N), "%9.0fc")
preserve 
	bysort tid: keep if _n == 1
	summ tid
	local unique_teachers = string(r(N), "%9.0fc")
restore

```

####Step 7: Define row titles for the table.


```stata
local t_male "Percent Male"
local t_black "Percent African American"
local t_latino "Percent Latino"
local t_white "Percent White"
local t_newhire "Percent New Hires"
local t_adv_degree "Percent with Advanced Degree"
local t_alternative_certification "Percent with Alternative Certification"
local t_experience "Average Teacher Experience"
```

####Step 8: Open output file.


```stata
putexcel set ${graphs}\Teacher_Char_by_School_Poverty.xlsx, sheet(Sheet1) replace
```

####Step 9: Create local row number variable.


```stata
local rownum = 1
```

####Step 10: Create overall and column titles.
Write title on 1st row, increment row, and write column titles with appropriate settings.

```stata
putexcel A`rownum':F`rownum' = "Teacher Characteristics by School Poverty Level", merge hcenter vcenter bold font(calibri, 20, black)
local rownum = `rownum' + 1
putexcel B`rownum' = "Agency Average", bold txtwrap hcenter
putexcel C`rownum' = "High Poverty Schools", bold txtwrap hcenter
putexcel D`rownum' = "Low Poverty Schools", bold txtwrap hcenter
putexcel E`rownum' = "Difference between High and Low Poverty Schools", bold txtwrap hcenter
```

####Step 11: Start a loop through row variables. 
Increment rownum variable at the start of each iteration.


```stata
foreach rowvar of varlist t_male t_black t_latino t_white t_newhire ///
	t_adv_degree t_alternative_certification t_experience {
	
	local rownum = `rownum' + 1	
```

####Step 12: Calculate quartile averages and difference.


```stata
  reg `rowvar' school_poverty_q4 school_poverty_q1, robust
  estimates store `rowvar'
  local highpov = _b[school_poverty_q4] + _b[_cons]
  local lowpov = _b[school_poverty_q1] + _b[_cons]
  local diff = _b[school_poverty_q4] - _b[school_poverty_q1]
```

####Step 13: Determine difference significance.
Get significance for difference between top and bottom quartile.
	

```stata
  test school_poverty_q4 = school_poverty_q1
  gen star = ""
  replace star = "*" if r(p) < .05
```

####Step 14: Calculate agency average.


```stata
  quietly summ `rowvar', meanonly
  local agencyavg = r(mean)
```

####Step 15: Add row values to table.
Write values for high, low, difference, and significance for each row variable. Close loop.


```stata
  putexcel A`rownum' = "``rowvar''", bold
  putexcel B`rownum' = `agencyavg'*100, nformat("###.#") 
  putexcel C`rownum' = `highpov'*100, nformat("###.#")
  putexcel D`rownum' = `lowpov'*100, nformat("###.#")
  putexcel E`rownum' = `diff'*100, nformat("###.#")
  putexcel F`rownum' = "`:di %3s star'"
  drop star 
}
```

####Step 16: Write footnotes.


```stata
#delimit ;
putexcel A`rownum':F`rownum' = "*Difference is statistically significant at the 95 percent
confidence level.", nobold merge;
local rownum = `rownum' + 1;
putexcel A`rownum':F`rownum' = "Notes: Sample includes teachers in the 2006-07 through 2010-11 
school years, with `teacher_years' teacher years and `unique_teachers' unique teachers. 
High (low) poverty schools are in the top (bottom) quartile of schools each year based 
on the share of students receiving free or reduced price lunch.", merge txtwrap;
#delimit cr
```

####Step 17: Format excel cells.
Use mata to fit column widths and row heights to fit text.


```stata
mata
b = xl()
b.load_book("${graphs}\Teacher_Char_by_School_Poverty.xlsx")
b.set_sheet("Sheet1")
b.set_column_width(1,1,33) //make title column widest
b.set_column_width(2,7,15) //make each column fit title
b.set_colunm_width(5,5,18) //make difference column wider to fit title
b.set_row_height(1,1,55) //make title row bigger
b.set_row_height(11,11,70) //make footnote text fully show
```

####Step 18: Close file.

```stata
b.close_book()
end
```

---

Next Analysis: [Examine Student Prior Achievement and Teacher Experience](Prior_Ach_by_Exp.html)
