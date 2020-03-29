
/*Keep variables with 30% or less missing information*/
DATA MYDATA.LOAN_LIMIT_TEST;
  SET MYDATA.LOAN_TEST;

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


PROC MEANS DATA=MYDATA.BASE (DROP=ROW_NUM BAD) 
	MIN MAX MEAN MEDIAN;
	VAR _NUMERIC_;
	OUTPUT OUT=VALUES(DROP=_type_ _freq_) 
	MIN= MAX= MEAN= MEDIAN= / AUTONAME;
RUN;

/*Create global variable for replacement algorithm*/
PROC CONTENTS NOPRINT DATA=MYDATA.BASE (KEEP=_NUMERIC_ DROP=ROW_NUM BAD) 
	OUT=VAR4 (KEEP=name);
RUN;

PROC SQL NOPRINT;
	SELECT name INTO: orig_num separated by " " FROM VAR4;
QUIT;

%PUT &orig_num;


/*Create global variable for replacement algorithm*/
PROC CONTENTS NOPRINT DATA=VALUES 
	OUT=VAR4 (KEEP=name);
RUN;

PROC SQL NOPRINT;
	SELECT name INTO: replace_num separated by " " FROM VAR4;
QUIT;

%PUT &replace_num;

DATA class(DROP=i);
	DO i = 1 TO 150000;
		DO j = 1 TO n;
			SET values NOBS=n POINT=j;
			OUTPUT;
		END;
	END;
	STOP;
RUN;

DATA MYDATA.CHK; 
	MERGE MYDATA.LOAN_LIMIT_TEST CLASS; 
RUN;

PROC MEANS DATA=mydata.chk N NMISS; VAR &orig_num; run;


/*Create base dataset that will contain all adjusted values*/
DATA mydata.update; SET mydata.loan_limit_test (KEEP=row_num); RUN;

/*Loop through variables in the TEST datset and replace the missing
  values with the summary stats MEAN value and cap any values
  greater than the MAX value with the MAX value*/
%MACRO loopit(mylist);
	%LET n = %SYSFUNC(countw(&mylist));

	%DO I=1 %TO &n;
		%LET val = %SCAN(&mylist,&I);
		data chk;
			set mydata.chk(keep=row_num &val. &val._MIN &val._MAX &val._MEAN);

			if &val. = . then &val. = &val._MEAN; ELSE &val. = &val.;
			if &val. lt &val._MIN then &val = &val._MIN; ELSE &val. = &val.;
			if &val. gt &val._MAX then &val = &val._MAX; ELSE &val. = &val.;

		RUN;

		PROC SQL;
		  CREATE TABLE MYDATA.UPDATE AS
		  SELECT *
		  FROM MYDATA.UPDATE AS a
		  LEFT JOIN chk AS b
		    ON a.ROW_NUM = b.ROW_NUM
		  ;
		  QUIT;

	%END;
%MEND;

%LET list = &orig_num;
%loopit(&list);

/*Retain only the original variables for the numeric TEST dataset
  and run a PROC MEANS to validate that everything looks correct*/
DATA MYDATA.UPDATE; SET MYDATA.UPDATE (KEEP=ROW_NUM &orig_num.); RUN;
PROC MEANS DATA=MYDATA.UPDATE N NMISS MIN MAX MEAN MEDIAN; 
VAR _NUMERIC_; RUN;


/*Adjust character variables*/

DATA char_data;
  SET MYDATA.LOAN_LIMIT_TEST (keep=row_num BAD _CHARACTER_);
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

PROC SQL;
  CREATE TABLE MYDATA.MODEL_TEST AS
  SELECT *
  FROM MYDATA.UPDATE AS a
  LEFT JOIN char_data AS b
    ON a.ROW_NUM = b.ROW_NUM
	;
QUIT;

