PROC CONTENTS NOPRINT DATA=TRAIN_ADJ (KEEP= accommodates availability_30 availability_60
availability_90 availability_365 bathrooms bedrooms beds cleaning_fee extra_people
guests_included host_listings_count maximum_nights minimum_nights
security_deposit) OUT=var1 (KEEP= name); RUN;
PROC SQL NOPRINT; 
SELECT name INTO:var2 separated by " " FROM var1;
SELECT compress(name||"_2") INTO:var3 separated by " " from var1;
QUIT;
%PUT &var3.; RUN;

DATA TRAIN_2;
    SET TRAIN_ADJ (KEEP= _NUMERIC_);
/* Create an array and loop through the variables to make polynomials */
    ARRAY prob{*} &var2;
	    ARRAY prob2{*} &var3;
	        DO i=1 TO 15;
	        prob2(i) = prob(i)**2;
    END;
    DROP i;
RUN;

PROC SQL;
    CREATE TABLE poly_train AS
    SELECT*
    FROM TRAIN_ADJ as A 
    LEFT JOIN TRAIN_2 as B 
        ON a.id=b.id
            WHERE a.id IS NOT NULL;
QUIT;

DATA TEST_2;
    SET TEST_ADJ (KEEP= _NUMERIC_);
/* Create an array and loop through the variables to make polynomials */
    ARRAY prob{*} &var2;
	    ARRAY prob2{*} &var3;
	        DO i=1 TO 15;
	        prob2(i) = prob(i)**2;
    END;
    DROP i;
RUN;

PROC SQL;
    CREATE TABLE poly_test AS
    SELECT*
    FROM TEST_ADJ as A 
    LEFT JOIN TEST_2 as B 
        ON a.id=b.id
            WHERE a.id IS NOT NULL;
QUIT;


*************************************************;
/* Linear Regression POLYNOMIAL MODEL */
*************************************************;
%let POLY_full = &Full_full. accommodates_2 availability_30_2 availability_365_2 availability_60_2
                 availability_90_2 bathrooms_2 bedrooms_2 beds_2 cleaning_fee_2 extra_people_2 
                 guests_included_2 host_listings_count_2 maximum_nights_2 minimum_nights_2 
                 security_deposit_2;

ods noproctitle;
ods graphics / imagemap=on;

%macro mod(name, class, pred);
	proc glmselect data=WORK.poly_TRAIN outdesign(addinputvars)=Work.reg_design 
			plots=(criterionpanel ASE) seed=1;
		class &class. / param=glm;
		model Price_Log=&pred. / selection=forward(stop=CV) cvMethod=RANDOM(5) ;
		output out = train_score;
		score data=poly_TEST PREDICTED RESIDUAL out=test_score;
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

proc append base=train_rmse  data=train_rmse_sum (KEEP=RMSE true_RMSE); run;


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

proc append base=test_rmse  data=test_rmse_sum (KEEP=RMSE true_RMSE); run;

%mend mod;

%mod(simple_LR, &simple_cat., &simple_full.) 
%mod(extended_LR, &extended_cat., &extended_full.)
%mod(full_LR, &Full_cat., &Full_full.)

/* proc delete data=train_rmse;run; */
/* proc delete data=test_rmse;run; */