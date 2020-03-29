
/*Create global variables for variables to be included in outlier macro*/
PROC CONTENTS NOPRINT DATA=MYDATA.MODEL_TRAIN (KEEP=_NUMERIC_ drop=bad ROW_NUM
acc_now_delinq delinq_amnt policy_code tot_coll_amt total_rec_prncp
total_rev_hi_lim revol_util total_bal_ex_mort num_op_rev_tl num_rev_accts
num_rev_tl_bal_gt_0 funded_amnt_inv funded_amnt total_pymnt_inv num_actv_rev_tl
tot_cur_bal total_acc tax_liens out_prncp out_prncp_inv total_rec_late_fee
collection_recovery_fee num_accts_ever_120_pd pub_rec pub_rec_bankruptcies 
delinq_2yrs last_pymnt_amnt num_sats total_pymnt installment avg_cur_bal num_bc_sats 
bc_open_to_buy percent_bc_gt_75 num_tl_op_past_12m num_tl_120dpd_2m num_tl_30dpd
num_tl_90g_dpd_24m mo_sin_rcnt_rev_tl_op mo_sin_old_rev_tl_op issue_date 
last_pymnt_date recoveries months_since_issue total_rec_int
total_pymnt total_pymnt_inv total_rec_int total_rec_late_fee total_rec_prncp
)
	OUT=VAR4 (KEEP=name);
RUN;

PROC SQL NOPRINT;
	SELECT name INTO: num_vars separated by " " FROM VAR4;
QUIT;

%PUT &num_vars;


%LET num_vars = acc_open_past_24mths annual_inc app_individual app_joint 
bc_util dti emp_10 emp_0to4 emp_5to9 emp_NA grade_A grade_B grade_C grade_D 
grade_E grade_F grade_G home_mort home_own home_rent inq_last_6mths int_rate 
loan_amnt mo_sin_old_il_acct mo_sin_rcnt_tl mort_acc mths_since_recent_bc 
mths_since_recent_inq num_actv_bc_tl num_bc_tl num_il_tl open_acc 
pct_tl_nvr_dlq purpose_cc purpose_dc purpose_hi purpose_other revol_bal term_36 
term_60 tot_hi_cred_lim total_bc_limit ver_not ver_source ver_verified;



proc freq data=mydata.model_train; tables issue_date*bad / nocol norow nopercent; run;

DATA TRAIN; 
  SET MYDATA.MODEL_TRAIN;
  WHERE '01JAN2015'd le issue_date le '01DEC2015'd;
RUN;

PROC FREQ DATA=TRAIN; TABLES BAD; RUN;
PROC FREQ DATA=MYDATA.MODEL_TRAIN; TABLES BAD; RUN;


ods graphics / attrpriority=none;
proc sgplot data=TRAIN (obs=1000);
styleattrs datasymbols=(circlefilled trianglefilled) ;
	scatter x=loan_amnt y=int_rate / group=bad;
	title 'Scatter Plot of Loan Data';
run;


proc sgscatter data=TRAIN (obs=250);
  title "Scatterplot Matrix for Loan Data";
  matrix loan_amnt total_bc_limit dti int_rate / group=bad;
run;

/*PROC FREQ DATA=TRAIN; TABLES bad; RUN;*/
/*PROC SURVEYSELECT DATA=TRAIN METHOD=SRS SAMPSIZE=50000 OUT=TRAIN2; RUN;*/
/*PROC FREQ DATA=TRAIN2; TABLES bad; RUN;*/

ODS GRAPHICS ON;
PROC LOGISTIC DATA=TRAIN DESCENDING PLOTS=ALL;
	MODEL BAD = &num_vars. / SELECTION=STEPWISE SLE=0.01 SLS=0.01 
	CORRB OUTROC=performance;
	OUTPUT OUT=MYDATA.LOG_REG_PROB PROB=score;
RUN;


/*Filter the hold-out TEST dataset*/
DATA TEST; 
  SET MYDATA.MODEL_TEST;
  WHERE '01JAN2015'd le issue_date le '01DEC2015'd;
RUN;

PROC FREQ DATA=TEST; TABLES BAD; RUN;
PROC FREQ DATA=MYDATA.MODEL_TEST; TABLES BAD; RUN;


/*Score the TEST dataset with the SCORE option*/
PROC LOGISTIC DATA=TRAIN DESCENDING PLOTS=NONE;
	MODEL BAD = &num_vars. / SELECTION=STEPWISE SLE=0.01 SLS=0.01;
	SCORE DATA=TEST OUT=TEST_SCORE;
RUN;

/*Evaluate TEST_SCORE separation power*/
PROC MEANS DATA=TEST_SCORE N NMISS MIN MAX MEAN;
	VAR BAD P_0 P_1;
RUN;

%INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Projects/separation.sas';
%separation(data = TEST_SCORE, score = P_1, y = bad);


/*Score the TEST dataset with hardcoded scoring algorithm*/
DATA TEST_SCORE;
	SET MYDATA.MODEL_TEST;
	WHERE '01JAN2015'd le issue_date le '01DEC2015'd;

	/*Model variables and coefficients from TRAIN model output*/
	xb = (-3.541800) +
		int_rate * 0.114400 +
		acc_open_past_24mths * 0.074400 +
		dti * 0.013000 +
		emp_NA * 0.431200 +
		(total_bc_limit / 10000) * -0.084800 +
		(tot_hi_cred_lim / 10000) * -0.009900 +
		(loan_amnt / 10000) * 0.120000 +
		num_actv_bc_tl * 0.044000 +
		home_mort * -0.180200 +
		term_36 * -0.145100 +
		inq_last_6mths * 0.090300 +
		grade_A	* -0.229100 +
		grade_C	* 0.109000 +
		mort_acc * -0.040000 +
		ver_not * -0.083200 +
		home_own * -0.106700 +
		grade_D * 0.077600;
	score = exp(xb)/(1+exp(xb));
RUN;


/*Evaluate TEST_SCORE separation power*/
PROC MEANS DATA=TEST_SCORE N NMISS MIN MAX MEAN;
	VAR BAD score;
RUN;

%INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Projects/separation.sas';
%separation(data = TEST_SCORE, score = score, y = bad);





/* Precision Recall Curve SAS */
data precision_recall;
	set performance;
	precision = _POS_/(_POS_ + _FALPOS_);
	recall = _POS_/(_POS_ + _FALNEG_);
	F_stat = harmean(precision,recall);
run;

proc sort data=precision_recall;
	by recall;
run;

proc iml;
	use precision_recall;
	read all var {recall} into sensitivity;
	read all var {precision} into precision;
	N  = 2 : nrow(sensitivity);
	tpr = sensitivity[N] - sensitivity[N-1];
	prec = precision[N] + precision[N-1];
	AUPRC = tpr`*prec/2;
	print AUPRC;
	title1 "Area under Precision Recall Curve";
	symbol1 interpol=join value=dot;

proc gplot data=precision_recall;
	plot precision*recall /  haxis=0 to 1 by .2
		vaxis=0 to 1 by .2;
run;

quit;





%INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Projects/GainLift.sas';
%INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Projects/separation.sas';
%GainLift(data=MYDATA.LOG_REG_PROB, response=bad, p=score, event=1, groups=10, 
GRAPHOPTS=BAR PANEL GRID BEST BASE);
%separation(data = MYDATA.LOG_REG_PROB, score = score, y = bad);













%LET var_limit = 
int_rate
acc_open_past_24mths
dti
emp_NA
total_bc_limit
loan_amnt
tot_hi_cred_lim
home_mort
num_actv_bc_tl
;

ODS GRAPHICS ON;
PROC LOGISTIC DATA=TRAIN DESCENDING PLOTS=ALL;
	MODEL BAD = &var_limit. / SELECTION=STEPWISE SLE=0.01 SLS=0.01 CORRB;
	OUTPUT OUT=MYDATA.LOG_REG_PROB PROB=score;
RUN;

PROC FREQ DATA=MYDATA.LOG_REG_PROB; TABLES bad; RUN;

%INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Projects/GainLift.sas';
%INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Projects/separation.sas';
%GainLift(data=MYDATA.LOG_REG_PROB, response=bad, p=score, event=1, groups=10, 
GRAPHOPTS=BAR PANEL GRID BEST BASE);
%separation(data = MYDATA.LOG_REG_PROB, score = score, y = bad);

DATA chk; 
  SET MYDATA.LOG_REG_PROB; 
  IF SCORE ge 0.5 then pred = 1; 
  else pred = 0;
RUN;

PROC FREQ DATA=chk; TABLES bad*pred / NOCOL NOROW NOPERCENT; RUN;


*******************************************************;
*Balanced Dataset                                      ;
*******************************************************;
PROC FREQ DATA=TRAIN; TABLES bad / NOCOL NOROW NOPERCENT; RUN;
DATA pos neg;
  SET TRAIN;
  IF bad = 1 THEN OUTPUT pos; ELSE OUTPUT neg;
RUN;

PROC SURVEYSELECT DATA=neg METHOD=SRS SAMPSIZE=11754 OUT=neg2; RUN;

DATA balance;
  set pos neg2;
RUN;

PROC FREQ DATA=balance; TABLES bad / NOCOL NOROW NOPERCENT; RUN;


/*ODS GRAPHICS ON;*/
/*PROC LOGISTIC DATA=balance DESCENDING PLOTS=ALL;*/
/*	MODEL BAD = &num_vars. / SELECTION=STEPWISE SLE=0.01 SLS=0.01 CORRB;*/
/*	OUTPUT OUT=MYDATA.LOG_REG_BAL PROB=score;*/
/*RUN;*/


%LET var_limit2 = 
int_rate
acc_open_past_24mths
dti
tot_hi_cred_lim
emp_NA
total_bc_limit
loan_amnt
inq_last_6mths
home_mort
;

ODS GRAPHICS ON;
PROC LOGISTIC DATA=balance DESCENDING PLOTS=ALL;
	MODEL BAD = &var_limit2. / SELECTION=STEPWISE SLE=0.01 SLS=0.01 CORRB;
	OUTPUT OUT=MYDATA.LOG_REG_BAL PROB=score;
RUN;

%INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Projects/GainLift.sas';
%INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Projects/separation.sas';
%GainLift(data=MYDATA.LOG_REG_BAL, response=bad, p=score, event=1, groups=10, 
GRAPHOPTS=BAR PANEL GRID BEST BASE);
%separation(data = MYDATA.LOG_REG_BAL, score = score, y = bad);


DATA chk; 
  SET MYDATA.LOG_REG_BAL; 
  IF SCORE ge 0.5 then pred = 1; 
  else pred = 0;
RUN;

PROC FREQ DATA=chk; TABLES bad*pred / NOCOL NOROW NOPERCENT; RUN;






data xx; set TRAIN ; if bad = 0 then bad2 = 1; else bad2 = 0; run;
proc freq data=xx; tables bad2; run;

ODS GRAPHICS ON; 
PROC HPSPLIT DATA=TRAIN SEED=42 PLOTS=ALL;
	CLASS BAD;
    MODEL BAD = &num_vars.;
	partition fraction(validate=0.3 seed=1234);
	OUTPUT OUT = tree_score;
	PRUNE COSTCOMPLEXITY;
RUN;

%INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Projects/GainLift.sas';
%GainLift(data=MYDATA.LOG_REG_PROB, response=bad, p=score, event=1, groups=10);

data x; set MYDATA.MODEL_TRAIN; keep &num_vars bad; run;