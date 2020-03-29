
*************************************************;
/* GLM Linear Regression MODEL                  */
*************************************************;
%let lasso_var = log_accom log_bath log_guest log_min log_max log_avil30 log_bedsper
n_bronx n_brooklyn n_manhattan n_queens r_entire r_private h_super h_profile
h_verified b_couch b_futon b_pullout b_real instant require_pic require_phone
hcount_level1 hcount_level2 hcount_level3 p_apart p_condo p_group2 p_house
p_loft p_townhouse n_staten r_shared b_air p_group1 poly_accom poly_bath
poly_guests poly_min poly_max poly_avail;
					
%macro doglm;
%do k=3 %to 5;
PROC GLMSELECT DATA=WORK.TRAIN_FINAL OUTDESIGN(ADDINPUTVARS)=Work.reg_design 
	PLOTS(stepaxis=normb)=all;
	MODEL Price_Log=&lasso_var. / selection=lasso(stop=&k choose=SBC);
	OUTPUT OUT = train_score;
	SCORE DATA=TEST_FINAL PREDICTED RESIDUAL OUT=test_score;
run;
%end;
%mend;
%doglm




ODS GRAPHICS ON;

PROC GLMSELECT DATA=WORK.TRAIN_FINAL OUTDESIGN(ADDINPUTVARS)=Work.reg_design 
	PLOTS(stepaxis=normb)=all;
	MODEL Price_Log=&lasso_var. / selection=lasso(stop=none choose=sbc);
	OUTPUT OUT = train_score;
	SCORE DATA=TEST_FINAL PREDICTED RESIDUAL OUT=test_score;
run;
/*	PLOTS=(criterionpanel ASE Coefficients ASEPlot);*/
*************************************************************************;
/* Calculate performance metrics for the TRAIN dataset */
*************************************************************************;

DATA train_measure;
  set train_score;  
	  residual_error = Price_Log - p_Price_Log;
	  squared_error = residual_error*residual_error;
	  trans_price = exp(price_log);
	  trans_error = exp(residual_error);
	  squared_prediction = p_Price_Log*p_Price_Log;
	  trans_predicted_price = exp(p_Price_Log);  
	  true_error = trans_price - trans_predicted_price;
  KEEP residual_error squared_error trans_price trans_error 
	   squared_prediction trans_predicted_price true_error ;  
RUN;

proc summary data=train_measure;
var squared_error trans_error true_error;
output out = train_sum_out sum=;
run;

data train_rmse_sum;
  set train_sum_out;
  RMSE = SQRT(squared_error/_FREQ_);
  trans_RMSE = SQRT(trans_error/_FREQ_);  
  true_RMSE = (true_error/_FREQ_);
RUN;
proc print data = train_rmse_sum; run;


*************************************************************************;
/* Calculate performance metrics for the TEST dataset */
*************************************************************************;

DATA measure;
  set test_score;  
	  residual_error = Price_Log - p_Price_Log;
	  squared_error = residual_error*residual_error;
	  trans_price = exp(price_log);
	  trans_error = exp(residual_error);
	  squared_prediction = p_Price_Log*p_Price_Log;
	  trans_predicted_price = exp(p_Price_Log);  
	  true_error = trans_price - trans_predicted_price;
  KEEP residual_error squared_error trans_price trans_error 
	   squared_prediction trans_predicted_price true_error ;  
RUN;

proc summary data=measure;
var squared_error trans_error true_error;
output out = sum_out sum=;
run;

data test_rmse_sum;
  set sum_out;
  RMSE = SQRT(squared_error/_FREQ_);
  trans_RMSE = SQRT(trans_error/_FREQ_);  
  true_RMSE = (true_error/_FREQ_);
RUN;
proc print data = test_rmse_sum; run;

ods graphics on;

proc reg data=Work.reg_design PLOTS(MAXPOINTS= 50000);
  model price_log = &_GLSMOD / selection=forward VIF COLLIN;;
quit;



*******************************************************;
*BOOTSTRAPPED MODEL                                    ;
*******************************************************;

ods noproctitle;
ods graphics / imagemap=on;


proc glmselect data=WORK.TRAIN_FINAL outdesign(addinputvars)=Work.reg_design 
	plots=(EffectSelectPct ParmDistribution criterionpanel ASE) seed=1;
	MODEL Price_Log=&lasso_var. / selection=lasso(steps=42 choose=sbc);
	modelAverage nsamples=1000 tables=(EffectSelectPct(all) ParmEst(all));
	output out = train_score;
	score data=TEST_FINAL PREDICTED RESIDUAL out=test_score;
run;
	

*************************************************************************;
/* Calculate performance metrics for the TRAIN dataset */
*************************************************************************;

DATA train_measure;
  set train_score;  
	  residual_error = Price_Log - p_Price_Log;
	  squared_error = residual_error*residual_error;
	  trans_price = exp(price_log);
	  trans_error = exp(residual_error);
	  squared_prediction = p_Price_Log*p_Price_Log;
	  trans_predicted_price = exp(p_Price_Log);  
	  true_error = trans_price - trans_predicted_price;
  KEEP residual_error squared_error trans_price trans_error 
	   squared_prediction trans_predicted_price true_error ;  
RUN;

proc summary data=train_measure;
var squared_error trans_error true_error;
output out = train_sum_out sum=;
run;

data train_rmse_sum;
  set train_sum_out;
  RMSE = SQRT(squared_error/_FREQ_);
  trans_RMSE = SQRT(trans_error/_FREQ_);  
  true_RMSE = (true_error/_FREQ_);
RUN;
proc print data = train_rmse_sum; run;


*************************************************************************;
/* Calculate performance metrics for the TEST dataset */
*************************************************************************;

DATA measure;
  set test_score;  
	  residual_error = Price_Log - p_Price_Log;
	  squared_error = residual_error*residual_error;
	  trans_price = exp(price_log);
	  trans_error = exp(residual_error);
	  squared_prediction = p_Price_Log*p_Price_Log;
	  trans_predicted_price = exp(p_Price_Log);  
	  true_error = trans_price - trans_predicted_price;
  KEEP residual_error squared_error trans_price trans_error 
	   squared_prediction trans_predicted_price true_error ;  
RUN;

proc summary data=measure;
var squared_error trans_error true_error;
output out = sum_out sum=;
run;

data test_rmse_sum;
  set sum_out;
  RMSE = SQRT(squared_error/_FREQ_);
  trans_RMSE = SQRT(trans_error/_FREQ_);  
  true_RMSE = (true_error/_FREQ_);
RUN;
proc print data = test_rmse_sum; run;



