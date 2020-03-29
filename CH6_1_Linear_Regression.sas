
/*Examine target variable*/
PROC UNIVARIATE DATA=MYDATA.MODEL_TRAIN; VAR revol_bal; HISTOGRAM; RUN;

/*Limit outliers of target variable and transform the target variable*/
DATA base_reg;
  SET MYDATA.MODEL_TRAIN;
  WHERE 10 le revol_bal le 30000;
  sqrt_revol_bal = sqrt(revol_bal);
  DROP revol_bal;
RUN;

PROC UNIVARIATE DATA=base_reg;
	VAR sqrt_revol_bal;
	HISTOGRAM;
RUN;


/*Create global variables for character variables*/
PROC CONTENTS NOPRINT DATA=base_reg (KEEP=_NUMERIC_ drop=bad sqrt_revol_bal
ROW_NUM acc_now_delinq delinq_amnt policy_code tot_coll_amt total_rec_prncp
total_rev_hi_lim revol_util total_bal_ex_mort num_op_rev_tl num_rev_accts
num_rev_tl_bal_gt_0 funded_amnt_inv funded_amnt total_pymnt_inv num_actv_rev_tl
tot_cur_bal total_acc tax_liens out_prncp out_prncp_inv total_rec_late_fee
collection_recovery_fee num_accts_ever_120_pd pub_rec pub_rec_bankruptcies 
delinq_2yrs last_pymnt_amnt num_sats total_pymnt installment avg_cur_bal num_bc_sats 
bc_open_to_buy percent_bc_gt_75 num_tl_op_past_12m num_tl_120dpd_2m num_tl_30dpd
num_tl_90g_dpd_24m mo_sin_rcnt_rev_tl_op mo_sin_old_rev_tl_op)
	OUT=VAR4 (KEEP=name);
RUN;

PROC SQL NOPRINT;
	SELECT name INTO: reg_num separated by " " FROM VAR4;
QUIT;

%PUT &reg_num;



/*Analyze the continuous variables*/
%let cont = annual_inc bc_util dti loan_amnt mo_sin_old_il_acct 
			mths_since_recent_bc pct_tl_nvr_dlq tot_hi_cred_lim 
			total_bc_limit total_rec_int;

PROC UNIVARIATE DATA=base_reg;
	VAR &cont.;
	HISTOGRAM;
RUN;

/*Create scatter plots for the continuous variables*/
%MACRO loopit(mylist);
	%LET n = %SYSFUNC(countw(&mylist));

	%DO I=1 %TO &n;
		%LET val = %SCAN(&mylist,&I);
			proc sgplot data=base_reg (obs=5000);
			  SCATTER X=&val.
			  		  Y=sqrt_revol_bal;
			RUN;
	%END;
%MEND;

%LET list = &cont.;
%loopit(&list);

/*Transform the continusous variables*/
data change;
  set base_reg;

  sqrt_annual_inc = sqrt(annual_inc);
  sqrt_bc_util = sqrt(bc_util);
  sqrt_dti = sqrt(dti);
  sqrt_loan_amnt = sqrt(loan_amnt);
  sqrt_mo_sin_old_il_acct = sqrt(mo_sin_old_il_acct);
  sqrt_mths_since_recent_bc = sqrt(mths_since_recent_bc);
  sqrt_pct_tl_nvr_dlq = sqrt(pct_tl_nvr_dlq);
  sqrt_tot_hi_cred_lim = sqrt(tot_hi_cred_lim);
  sqrt_total_bc_limit = sqrt(total_bc_limit);
  sqrt_total_rec_int = sqrt(total_rec_int);

  DROP annual_inc bc_util dti loan_amnt mo_sin_old_il_acct mths_since_recent_bc 
	   pct_tl_nvr_dlq tot_hi_cred_lim total_bc_limit total_rec_int;
run;


proc univariate data=base_reg; var bc_util; histogram; run;

data x; set base_reg (keep=row_num bc_util);
  sqrt_bc_util = sqrt(bc_util);
  sqr_bc_util = bc_util**2;
  log_bc_util = log(bc_util);
  arc_bc_util = ARSIN(SQRT(bc_util));
  log10_bc_util = log10(bc_util);

  logit_bc_util = logit(bc_util);

run;

proc univariate data=x; var sqrt_bc_util sqr_bc_util log_bc_util arc_bc_util 
log10_bc_util logit_bc_util; histogram; run;


proc transreg data=base_reg maxiter=0 nozeroconstant;
	model BoxCox(sqrt_revol_bal) = identity(bc_util);
	output out=box_out;
run;

proc univariate data=box_out;
	var Tbc_util;
	histogram ;
run;

%let trans = sqrt_annual_inc sqrt_bc_util sqrt_dti sqrt_loan_amnt 
			 sqrt_mo_sin_old_il_acct sqrt_mths_since_recent_bc
			 sqrt_pct_tl_nvr_dlq sqrt_tot_hi_cred_lim sqrt_total_bc_limit 
			 sqrt_total_rec_int;


PROC UNIVARIATE DATA=change;
	VAR &trans.;
	HISTOGRAM;
RUN;


%MACRO loopit(mylist);
	%LET n = %SYSFUNC(countw(&mylist));

	%DO I=1 %TO &n;
		%LET val = %SCAN(&mylist,&I);
			proc sgplot data=change (obs=5000);
			  SCATTER X=&val.
			  		  Y=sqrt_revol_bal;
			RUN;
	%END;
%MEND;

%LET list = &trans.;
%loopit(&list);



/*Create box plots for interval variables*/

%let box = acc_open_past_24mths app_individual app_joint emp_10 emp_0to4 emp_5to9 emp_NA
		   grade_A grade_B grade_C grade_D grade_E grade_F grade_G home_mort home_own home_rent
		   inq_last_6mths int_rate mo_sin_rcnt_tl months_since_issue mort_acc 
		   mths_since_recent_inq num_actv_bc_tl num_bc_tl open_acc purpose_cc purpose_dc
		   purpose_hi purpose_other recoveries term_36 term_60 ver_not ver_source ver_verified;

%MACRO loopit(mylist);
	%LET n = %SYSFUNC(countw(&mylist));

	%DO I=1 %TO &n;
		%LET val = %SCAN(&mylist,&I);

		proc sort data=change (keep=sqrt_revol_bal &val.) out=out; by &val.;

		proc boxplot data=out ;
			plot sqrt_revol_bal*&val.;
			inset min mean max stddev /
				header = 'Overall Statistics'
				pos    = tm;
			insetgroup min max /
				header = "Revol_Bal by &val.";
		run;
	%END;
%MEND;
%LET list = &box;
%loopit(&list);


DATA MYDATA.CHANGE; SET change (keep=row_num sqrt_revol_bal &trans.); RUN;
%MACRO loopit(mylist);
	%LET n = %SYSFUNC(countw(&mylist));

	%DO I=1 %TO &n;
		%LET val = %SCAN(&mylist,&I);
		DATA int_&val.;
		  set change (keep=ROW_NUM &val.);
		  sqrt_&val. = sqrt(&val.);
		  drop &val.;
		run;

		PROC SQL;
		    CREATE TABLE MYDATA.CHANGE AS
			SELECT *
			FROM MYDATA.CHANGE AS a
			LEFT JOIN int_&val. as b
			  on a.ROW_NUM = b.ROW_NUM;
	%END;
%MEND;
%LET list = &box;
%loopit(&list);


%let sqrt_box = sqrt_acc_open_past_24mths sqrt_app_individual sqrt_app_joint sqrt_emp_10 sqrt_emp_0to4 sqrt_emp_5to9 sqrt_emp_NA
		   sqrt_grade_A sqrt_grade_B sqrt_grade_C sqrt_grade_D sqrt_grade_E sqrt_grade_F sqrt_grade_G sqrt_home_mort sqrt_home_own sqrt_home_rent
		   sqrt_inq_last_6mths sqrt_int_rate sqrt_mo_sin_rcnt_tl sqrt_months_since_issue sqrt_mort_acc 
		   sqrt_mths_since_recent_inq sqrt_num_actv_bc_tl sqrt_num_bc_tl sqrt_open_acc sqrt_purpose_cc sqrt_purpose_dc
		   sqrt_purpose_hi sqrt_purpose_other sqrt_recoveries sqrt_term_36 sqrt_term_60 sqrt_ver_not sqrt_ver_source sqrt_ver_verified;

%MACRO loopit(mylist);
	%LET n = %SYSFUNC(countw(&mylist));

	%DO I=1 %TO &n;
		%LET val = %SCAN(&mylist,&I);

		proc sort data=mydata.change (keep=sqrt_revol_bal &val.) out=out; by &val.;

		proc boxplot data=out ;
			plot sqrt_revol_bal*&val.;
			inset min mean max stddev /
				header = 'Overall Statistics'
				pos    = tm;
			insetgroup min max /
				header = "Revol_Bal by &val.";
		run;
	%END;
%MEND;
%LET list = &sqrt_box.;
%loopit(&list);


proc univariate data=change; var sqrt_bc_util; histogram; run;



/*Create simple linear regression*/
ODS GRAPHICS ON;
PROC REG DATA=change (obs=5000)
	PLOTS(ONLY)=ALL;
	MODEL sqrt_revol_bal = sqrt_total_bc_limit /
		SLE=0.1
		SLS=0.1
		INCLUDE=0;
	OUTPUT OUT=WORK.REG_PRED PREDICTED=P RESIDUAL=R;
RUN;



/*Create multiple linear regression*/
ODS GRAPHICS ON;
PROC REG DATA=change (obs=5000)
		PLOTS(ONLY)=ALL	;
	MODEL sqrt_revol_bal = &trans. &box. / SELECTION=STEPWISE
		SLE=0.1
		SLS=0.1
		INCLUDE=0
		COLLIN VIF ;
	OUTPUT OUT=WORK.REG_PRED PREDICTED=P RESIDUAL=R;
RUN;



/*Create parsimonious linear regression*/
ODS GRAPHICS ON;
PROC REG DATA=change (obs=5000)
		PLOTS(ONLY)=ALL	;
	MODEL sqrt_revol_bal = sqrt_total_bc_limit sqrt_bc_util
						   open_acc sqrt_loan_amnt sqrt_dti
						   sqrt_annual_inc 
	   / SELECTION=STEPWISE
		SLE=0.1
		SLS=0.1
		INCLUDE=0
		COLLIN VIF;
	OUTPUT OUT=WORK.REG_PRED PREDICTED=P RESIDUAL=R;
RUN;



/*Transform the hold-out test dataset*/
DATA test_reg;
  SET MYDATA.MODEL_TEST;
  WHERE 10 le revol_bal le 30000;
  sqrt_revol_bal = sqrt(revol_bal);
  sqrt_annual_inc = sqrt(annual_inc);
  sqrt_bc_util = sqrt(bc_util);
  sqrt_dti = sqrt(dti);
  sqrt_loan_amnt = sqrt(loan_amnt);
  sqrt_mo_sin_old_il_acct = sqrt(mo_sin_old_il_acct);
  sqrt_mths_since_recent_bc = sqrt(mths_since_recent_bc);
  sqrt_pct_tl_nvr_dlq = sqrt(pct_tl_nvr_dlq);
  sqrt_tot_hi_cred_lim = sqrt(tot_hi_cred_lim);
  sqrt_total_bc_limit = sqrt(total_bc_limit);
  sqrt_total_rec_int = sqrt(total_rec_int);
RUN;


/*Apply simple linear regression to the hold-out TEST dataset*/
PROC REG DATA=change OUTEST=RegOut	;
	MODEL sqrt_revol_bal = sqrt_total_bc_limit / SELECTION=STEPWISE;
	OUTPUT OUT=WORK.REG_PRED PREDICTED=P RESIDUAL=R;
RUN;

/*Apply parsimonious model to the TEST dataset*/
PROC SCORE DATA=test_reg SCORE=RegOut OUT=RScoreP TYPE=parms;
   var sqrt_total_bc_limit;
RUN;

/*Calculate RMSE for the TEST dataset*/
DATA eval;
  SET RScoreP;
  RESIDUAL = (MODEL1-sqrt_revol_bal)**2;
  sqrt_residual = sqrt(residual);
  KEEP row_num model1 sqrt_revol_bal residual sqrt_residual;
RUN;

PROC MEANS DATA=eval N MEAN;
  VAR RESIDUAL sqrt_residual;
RUN;



/*Apply the parsimonious model to the full TRAIN dataset*/
%LET parsi_vars = sqrt_total_bc_limit sqrt_bc_util open_acc 
				  sqrt_loan_amnt sqrt_dti sqrt_annual_inc;

PROC REG DATA=change OUTEST=RegOut	;
	MODEL sqrt_revol_bal = &parsi_vars. / SELECTION=STEPWISE;
	OUTPUT OUT=WORK.REG_PRED PREDICTED=P RESIDUAL=R;
RUN;

/*Apply parsimonious model to the TEST dataset*/
PROC SCORE DATA=test_reg SCORE=RegOut OUT=RScoreP TYPE=parms;
   VAR &parsi_vars.;
run;

/*Calculate RMSE for the TEST dataset*/
DATA eval;
  SET RScoreP;
  RESIDUAL = (MODEL1-sqrt_revol_bal)**2;
  sqrt_residual = sqrt(residual);
  KEEP row_num model1 sqrt_revol_bal residual sqrt_residual;
RUN;

PROC MEANS DATA=eval N MEAN;
  VAR RESIDUAL sqrt_residual;
RUN;


/*Create Ridge Regression model*/
ODS GRAPHICS ON;
PROC REG DATA=change outest=ridge_parms ridge=0 to 1 by .05
	OUTVIF PLOTS(ONLY)=ALL	;
	MODEL sqrt_revol_bal = &trans. &box.;
	OUTPUT OUT=WORK.RIDGE_PRED PREDICTED=P RESIDUAL=R;
RUN;


/*Score the TEST dataset with Ridge Regression parameters*/
proc score data=test_reg score=ridge_parms out=RScoreP type=parms;
   var &trans. &box.;
run;

/*Calculate RMSE for the TEST dataset*/
DATA eval;
  SET RScoreP;
  RESIDUAL = (MODEL1-sqrt_revol_bal)**2;
  sqrt_residual = sqrt(residual);
  KEEP row_num model1 sqrt_revol_bal residual sqrt_residual;
RUN;

PROC MEANS DATA=eval N MEAN;
  VAR RESIDUAL sqrt_residual;
RUN;



/*Create Lasso Regression Model*/
PROC GLMSELECT DATA=change PLOTS(UNPACK)=ALL ;
	MODEL sqrt_revol_bal = &trans. &box. 
	/ SELECTION=lasso(CHOOSE=CP STEPS=10) STATS=ALL;
	SCORE DATA=test_reg OUT=test_pred PREDICTED RESIDUAL;
RUN;



DATA eval;
  SET test_pred;
  RESIDUAL = (p_sqrt_revol_bal-sqrt_revol_bal)**2;
  sqrt_residual = sqrt(residual);
  KEEP row_num model1 sqrt_revol_bal residual sqrt_residual;
RUN;

PROC MEANS DATA=eval N MEAN;
  VAR RESIDUAL sqrt_residual;
RUN;