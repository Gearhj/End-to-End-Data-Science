
LIBNAME MYDATA BASE "C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data";

FILENAME REFFILE 'C:\Users\James Gearheart\Desktop\SAS Book Stuff\Data\loan.csv';

PROC IMPORT DATAFILE=REFFILE
	DBMS=CSV
	OUT= MYDATA.Loan;
	GETNAMES=YES;
RUN;

PROC CONTENTS DATA=MYDATA.Loan; RUN;

DATA WORK.LOAN;
  SET MYDATA.Loan;

  keep loan_amnt loan_status term int_rate installment grade emp_length annual_inc home_ownership
       verification_status issue_d loan_status purpose dti delinq_2yrs inq_last_12m
	   delinq_2yrs pub_rec revol_bal mths_since_last_delinq mths_since_recent_bc revol_bal total_acc
	   tot_cur_bal open_acc op num_tl_30dpd num_tl_90g_dpd_24m num_tl_op_past_12m open_acc open_acc_6m
	   open_il_12m open_il_24m open_act_il open_rv_12m open_rv_24m out_prncp out_prncp_inv
	   pct_tl_nvr_dlq percent_bc_gt_75 chargeoff_within_12_mths fico_range_high fico_range_low
	   acc_now_delinq;
RUN;

PROC MEANS DATA=WORK.LOAN N NMISS MIN MAX MEAN MEDIAN STDDEV;
	VAR _NUMERIC_;
	OUTPUT OUT=LOAN_MEANS;
RUN;

PROC FREQ DATA=WORK.LOAN ORDER=FREQ; TABLES _CHARACTER_; RUN;


