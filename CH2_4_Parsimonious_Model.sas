/*Variables selected by analyzing the stepwise effects entered into the model and */
/*determining the additional benefit of each variable.*/

*************************************************;
/* Linear Regression Simple MODEL */
*************************************************;
%let final_features2 =  r_private log_accom n_brooklyn n_queens r_shared n_bronx;
					
/*log_bathper log_bedrooms log_beds log_pbath log_paccom log_pguest  
log_pmin log_pmax log_pavail  require_pic r_entire n_manhattan*/

proc glmselect data=WORK.TRAIN_FINAL outdesign(addinputvars)=Work.reg_design 
	plots=(criterionpanel ASE Coefficients ASEPlot);
	model Price_Log=&final_features2. / selection=stepwise(select=sbc);
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

ods graphics on;

proc reg data=Work.reg_design PLOTS(MAXPOINTS= 50000);
  model price_log = &_GLSMOD / selection=forward VIF COLLIN;;
quit;

ods graphics off;