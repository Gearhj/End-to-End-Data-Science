
%LET num_vars = acc_open_past_24mths annual_inc app_individual app_joint 
bc_util dti emp_10 emp_0to4 emp_5to9 emp_NA grade_A grade_B grade_C grade_D 
grade_E grade_F grade_G home_mort home_own home_rent inq_last_6mths int_rate 
loan_amnt mo_sin_old_il_acct mo_sin_rcnt_tl mort_acc mths_since_recent_bc 
mths_since_recent_inq num_actv_bc_tl num_bc_tl num_il_tl open_acc 
pct_tl_nvr_dlq purpose_cc purpose_dc purpose_hi purpose_other revol_bal term_36 
term_60 tot_hi_cred_lim total_bc_limit ver_not ver_source ver_verified;

DATA TRAIN; 
  SET MYDATA.MODEL_TRAIN;
  WHERE '01JAN2015'd le issue_date le '01DEC2015'd;
RUN;


/*Filter the hold-out TEST dataset*/
DATA TEST; 
  SET MYDATA.MODEL_TEST;
  WHERE '01JAN2015'd le issue_date le '01DEC2015'd;
RUN;

%LET log_vars = int_rate acc_open_past_24mths dti emp_NA total_bc_limit
tot_hi_cred_lim loan_amnt num_actv_bc_tl home_mort term_36 inq_last_6mths
grade_A grade_C mort_acc ver_not home_own grade_D ;


PROC DISCRIM DATA=TRAIN OUTSTAT=DIS out=discrim_out 
	TESTDATA=TEST TESTOUT=TEST_OUT;
	CLASS BAD;
	VAR &log_vars.;
RUN;

PROC MEANS DATA=DISCRIM_OUT N NMISS MIN MAX MEAN;
CLASS _INTO_;
VAR '1'N;
RUN;

PROC MEANS DATA=TEST_OUT N NMISS MIN MAX MEAN;
CLASS _INTO_;
VAR '1'N;
RUN;

%INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Projects/separation.sas';
%separation(data = TEST_OUT, score = '1'N, y = BAD);



proc discrim data=TRAIN testdata=TEST testout=fake_out out=discrim_out canonical;
  class BAD;
  var int_rate acc_open_past_24mths dti;
run;


data plotclass;
  merge fake_out discrim_out;
run;


proc template;
  define statgraph classify;
    begingraph;
      layout overlay;
        contourplotparm x=Can1 y=Can2 z=_into_ / contourtype=fill  
						 nhint = 30 gridded = false;
        scatterplot x=Can1 y=Can2 / group=BAD includemissinggroup=false
	                 	    markercharactergroup = BAD;
      endlayout;
    endgraph;
  end;
run;

proc sgrender data = plotclass template = classify;
run;