
/*Reduce the size of the population*/
PROC SURVEYSELECT DATA=MYDATA.LOAN OUT=LOAN_SAMP 
	METHOD=SRS SAMPSIZE=500000 SEED=42;
RUN;


PROC FREQ DATA=LOAN_SAMP ORDER=FREQ; TABLES loan_status; RUN;

DATA LOAN_DATA;
  SET LOAN_SAMP;

  IF loan_status in ("Charged Off", "Default",
  "Does not meet the credit policy. Status:Charged Off") 
  then bad = 1; else bad = 0;

  ROW_NUM = _N_;

RUN;

PROC FREQ DATA=LOAN_DATA ORDER=FREQ; TABLES loan_status*bad / NOCOL NOROW NOPERCENT; RUN;

/*Create TRAIN and TEST datasets*/
PROC SURVEYSELECT DATA=LOAN_DATA RATE=0.3 OUTALL OUT=CLASS SEED=42; RUN;
PROC FREQ DATA=CLASS; TABLES selected; RUN;


DATA MYDATA.LOAN_TRAIN MYDATA.LOAN_TEST;
  SET CLASS;
  IF selected = 0 THEN OUTPUT MYDATA.LOAN_TRAIN; 
  ELSE OUTPUT MYDATA.LOAN_TEST;
RUN;

PROC FREQ DATA=MYDATA.LOAN_TRAIN; TABLES BAD; RUN;
PROC FREQ DATA=MYDATA.LOAN_TEST; TABLES BAD; RUN;



/*Explore numeric data*/

PROC MEANS DATA=MYDATA.LOAN_TRAIN N NMISS MIN MAX MEAN STDDEV;
	VAR _NUMERIC_;
	OUTPUT OUT=LOAN_MEANS;
RUN;


/*Explore character data*/

DATA char;
  SET MYDATA.LOAN_TRAIN (OBS=100);
  KEEP _CHARACTER_;
RUN;


PROC FREQ DATA=MYDATA.LOAN_TRAIN (DROP=id member_id url emp_title zip_code 
	earliest_cr_line sec_app_earliest_cr_line desc issue_d title 
	last_pymnt_d next_pymnt_d last_credit_pull_d debt_settlement_flag_date 
	settlement_date hardship_start_date hardship_end_date payment_plan_start_date); 
	TABLES _CHARACTER_; 
RUN;


/*Keep variables with 30% or less missing information*/
DATA MYDATA.LOAN_LIMIT;
  SET MYDATA.LOAN_TRAIN;

   issue_date = input(issue_d,monyy10.);
   last_pymnt_date = input(last_pymnt_d,monyy10.);
   put issue_date=date9.;
   put last_pymnt_date=date9.;
   months_since_issue = intck('month', issue_date, last_pymnt_date, 'd');
   format issue_date date8. last_pymnt_date date8.;

  keep ROW_NUM bad loan_amnt funded_amnt funded_amnt_inv int_rate installment 
	   revol_bal out_prncp out_prncp_inv total_pymnt total_pymnt_inv total_rec_prncp
       total_rec_int total_rec_late_fee recoveries collection_recovery_fee
       last_pymnt_amnt policy_code annual_inc delinq_2yrs open_acc pub_rec
       total_acc acc_now_delinq delinq_amnt inq_last_6mths tax_liens
       pub_rec_bankruptcies dti revol_util acc_open_past_24mths mort_acc 
	   total_bal_ex_mort total_bc_limit num_bc_sats num_sats tot_coll_amt tot_cur_bal
       total_rev_hi_lim mo_sin_rcnt_tl num_accts_ever_120_pd num_actv_bc_tl
       num_actv_rev_tl num_bc_tl num_il_tl num_op_rev_tl num_rev_tl_bal_gt_0
       num_tl_30dpd num_tl_90g_dpd_24m num_tl_op_past_12m tot_hi_cred_lim
       mo_sin_old_rev_tl_op mo_sin_rcnt_rev_tl_op num_rev_accts avg_cur_bal 
	   pct_tl_nvr_dlq mths_since_recent_bc bc_open_to_buy percent_bc_gt_75 
	   bc_util mo_sin_old_il_acct num_tl_120dpd_2m mths_since_recent_inq term grade 
	   sub_grade emp_length home_ownership verification_status pymnt_plan purpose 
	   addr_state initial_list_status application_type hardship_flag 
	   disbursement_method debt_settlement_flag issue_date last_pymnt_date months_since_issue
  ; 
RUN;


/*Infer missing numeric data with global mean*/
PROC STDIZE DATA=MYDATA.LOAN_LIMIT REPONLY METHOD=mean OUT=Complete_data;
	VAR _NUMERIC_;
RUN;


/*Verify missing data has been inferred*/
PROC MEANS DATA=MYDATA.LOAN_LIMIT N NMISS MIN MAX MEAN MEDIAN STDDEV;
	VAR _NUMERIC_;
RUN;


/*Create global variables for variables to be included in outlier macro*/
PROC CONTENTS NOPRINT DATA=MYDATA.LOAN_LIMIT (KEEP=_NUMERIC_ drop=bad ROW_NUM
/*These variables have low volumes and would be interpreted as outliers*/
acc_now_delinq
collection_recovery_fee
delinq_2yrs
delinq_amnt
num_accts_ever_120_pd
num_tl_120dpd_2m
num_tl_30dpd
num_tl_90g_dpd_24m
pub_rec
pub_rec_bankruptcies
recoveries
tax_liens
tot_coll_amt
total_rec_late_fee
)
	OUT=VAR4 (KEEP=name);
RUN;

PROC SQL NOPRINT;
	SELECT name INTO: outliers separated by " " FROM VAR4;
QUIT;

%PUT &outliers;


PROC STDIZE DATA=MYDATA.LOAN_LIMIT (keep=ROW_NUM &outliers.)
	REPONLY METHOD=median OUT=Outlier_adjust;
	VAR _NUMERIC_;
RUN;

DATA MYDATA.LOAN_ADJUST;
	MERGE Complete_data (drop= &outliers. in=a) Outlier_adjust (in=b);
	by ROW_NUM;
RUN;


PROC FREQ DATA=MYDATA.LOAN_ADJUST ORDER=FREQ;
	TABLES verification_status*(_CHARACTER_);
RUN;



/*Step 1: Create BASE and OUTLIER datasets*/
DATA MYDATA.BASE; 
	SET MYDATA.LOAN_ADJUST (DROP=&outliers.); 
RUN;

DATA outliers; 
	SET MYDATA.LOAN_ADJUST (KEEP=&outliers. ROW_NUM); 
RUN;

/*Step 2: Create loop and apply the 1.5 IQR rule*/
%MACRO loopit(mylist);
	%LET n = %SYSFUNC(countw(&mylist));

	%DO I=1 %TO &n;
		%LET val = %SCAN(&mylist,&I);

		PROC UNIVARIATE DATA = outliers ;
			VAR &val.;
			OUTPUT OUT=boxStats MEDIAN=median QRANGE=iqr;
		run;

		data _NULL_;
			SET boxStats;
			CALL symput ('median',median);
			CALL symput ('iqr', iqr);
		run;

		%PUT &median;
		%PUT &iqr;

		DATA out_&val.(KEEP=ROW_NUM &val.);
			SET outliers;

			IF &val. ge &median + 1.5 * &iqr THEN
				&val. = &median + 1.5 * &iqr;
		RUN;

/*Step 3: Merge restricted value to BASE dataset*/
		PROC SQL;
		    CREATE TABLE MYDATA.BASE AS
			SELECT *
			FROM MYDATA.BASE AS a
			LEFT JOIN out_&val. as b
			  on a.ROW_NUM = b.ROW_NUM;
		QUIT;

	%END;
%MEND;

%LET list = &outliers;
%loopit(&list);

 

/*Step 1: Create REPLACE Dataset*/
PROC MEANS DATA=MYDATA.BASE (DROP=ROW_NUM BAD) MIN MAX MEAN MEDIAN maxdec=4 STACKODS;
	VAR _NUMERIC_;
	OUTPUT OUT=VALUES(DROP=_type_ _freq_) MIN= MAX= MEAN= MEDIAN=;
	ods output summary = MYDATA.REPLACE;
RUN;


/*Adjust character variables*/

proc freq data=MYDATA.BASE(DROP=addr_state) ORDER=FREQ; tables _CHARACTER_*bad 
/ nocol norow nopercent; run;


DATA EXAMPLE;
  SET MYDATA.BASE (KEEP=purpose);
  if _N_ ge 349500 then purpose = '';
RUN;

PROC FREQ DATA=EXAMPLE ORDER=FREQ; TABLES purpose; RUN;

DATA EXAMPLE_INFERRED;
  SET EXAMPLE;
  IF purpose = '' THEN purpose = 'debt_consolidation';
RUN;

PROC FREQ DATA=EXAMPLE_INFERRED ORDER=FREQ; TABLES purpose; RUN;

PROC FREQ DATA=MYDATA.BASE (KEEP=purpose) ORDER=FREQ; TABLES purpose; RUN;
PROC FREQ DATA=MYDATA.BASE ORDER=FREQ; TABLES purpose*bad / nocol norow nopercent; RUN;



DATA char_data;
  SET MYDATA.BASE (keep=row_num _CHARACTER_);
  IF purpose = 'debt_consolidation' then purpose_dc = 1; else purpose_dc = 0;
  IF purpose = 'credit_card' then purpose_cc = 1; else purpose_cc = 0;
  IF purpose = 'home_improvement' then purpose_hi = 1; else purpose_hi = 0;
  IF purpose NOT IN ('debt_consolidation', 'credit_card', 'home_improvement') 
                                  then purpose_other = 1; else purpose_other = 0;

  IF term = '36 months' THEN term_36 = 1; else term_36 = 0;
  IF term = '60 months' THEN term_60 = 1; else term_60 = 0;

  IF grade = 'A' then grade_A = 1; else grade_A = 0;
  IF grade = 'B' then grade_B = 1; else grade_B = 0;
  IF grade = 'C' then grade_C = 1; else grade_C = 0;
  IF grade = 'D' then grade_D = 1; else grade_D = 0;
  IF grade = 'E' then grade_E = 1; else grade_E = 0;
  IF grade = 'F' then grade_F = 1; else grade_F = 0;
  IF grade = 'G' then grade_G = 1; else grade_G = 0;

  IF emp_length IN ('< 1 year', '1 year', '2 years', '3 years',
					'4 years') THEN emp_0to4 = 1; else emp_0to4 = 0;
  IF emp_length IN ('5 years', '6 years', '7 years', '8 years',
					'9 years') THEN emp_5to9 = 1; else emp_5to9 = 0;
  IF emp_length = '10+ years' THEN emp_10 = 1; else emp_10 = 0;
  IF emp_length = 'n/a' THEN emp_NA = 1; ELSE emp_NA = 0;

  IF home_ownership = 'MORTGAGE' THEN home_mort = 1; else home_mort = 0;
  IF home_ownership = 'OWN' THEN home_own = 1; else home_own = 0;
  IF home_ownership NOT IN ('MORTGAGE', 'OWN') THEN home_rent = 1; else home_rent = 1;

  IF application_type = 'Individual' THEN app_individual = 1; else app_individual = 0;
  IF application_type = 'Joint App' THEN app_joint = 1; else app_joint = 0;

  IF verification_status = 'Not Verified' THEN ver_not = 1; else ver_not = 0;
  IF verification_status = 'Source Verified' THEN ver_source = 1; else ver_source = 0;
  IF verification_status = 'Verified' THEN ver_verified = 1; else ver_verified = 0;

  KEEP _NUMERIC_;

RUN;

PROC FREQ DATA=char_data ; TABLES purpose_dc--ver_verified; RUN;


PROC SQL;
  CREATE TABLE MYDATA.MODEL_TRAIN (KEEP= _NUMERIC_) AS
  SELECT *
  FROM MYDATA.BASE AS a
  LEFT JOIN char_data AS b
    ON a.ROW_NUM = b.ROW_NUM
	;
QUIT;




/*Change variable formats*/
DATA num_to_char;
  SET MYDATA.LOAN_LIMIT (OBS=1000 KEEP=loan_amnt);
  char_loan = put(loan_amnt, $8.);
  DROP loan_amnt;
RUN;


DATA char_to_num;
  SET num_to_char;
  num_loan = input(char_loan, 8.);
  DROP char_loan;
RUN;


DATA date_values;
  SET dataset;
  year  = year(date);
  month = month(date);
  day   = day(date);
  week  = week(date);
RUN;


/*Feature Engineering*/

DATA new_features;
  SET MYDATA.LOAN_LIMIT (OBS=1000 KEEP=installment annual_inc int_rate term);

  /*Create new variable: debt to income ratio*/
  dti = installment / (annual_inc / 12);

  /*Polynomial*/
  int_rate_sq = int_rate**2;

  /*Dummy variables*/
  IF term = '36 months' THEN t36 = 1; ELSE t36 = 0;
  IF term = '60 months' THEN t60 = 1; ELSE t60 = 0;

RUN;


PROC STDIZE DATA=MYDATA.Loan_limit(obs=10 KEEP=annual_inc int_rate) 
	METHOD=STD PSTAT OUT=std_vars;
	VAR annual_inc int_rate;
RUN;


/*Weight of Evidence and Information Value*/
PROC HPBIN DATA=MYDATA.BASE (KEEP=total_pymnt) NUMBIN=10;
	INPUT total_pymnt ;
	ODS OUTPUT MAPPING=MAPPING;
RUN;

PROC HPBIN DATA=MYDATA.BASE (KEEP=bad total_pymnt) 
	WOE BINS_META=MAPPING;
	TARGET BAD / LEVEL=BINARY ORDER=DESC;
RUN;

proc univariate data=mydata.loan_limit; var total_pymnt; run;

