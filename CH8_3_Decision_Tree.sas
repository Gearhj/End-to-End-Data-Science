/*Reload the full dataset*/

LIBNAME MYDATA BASE "C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data";

FILENAME REFFILE 'C:\Users\James Gearheart\Desktop\SAS Book Stuff\Data\Bank_Loan\BankFull.xlsx';

PROC DELETE DATA=MYDATA.Bankfull; RUN;
PROC IMPORT DATAFILE=REFFILE
	DBMS=XLSX
	OUT= MYDATA.BankFull;
	GETNAMES=YES;
RUN;

PROC CONTENTS DATA=MYDATA.BankFull; RUN;

/*Determine significant variables to build a reduced example tree*/
proc logistic data=mydata.bankfull descending;
  class contact day_of_week default education housing job loan marital month poutcome ;
  model y = contact day_of_week default education housing job loan marital month poutcome
  			age campaign pdays previous ;
run;

%let num_vars = age campaign duration pdays previous ;

%let char_vars = contact day_of_week default education housing
job loan marital month poutcome ;


/*Example Decision Tree Dataset Creation*/
proc freq data=mydata.bankfull; tables pdays; run;

data x; 
  set mydata.bankfull;
  if month in ('jan', 'feb', 'mar', 'apr', 'may', 'jun') then year = '1st half'; else year = '2nd half';
  if campaign le 2 then campaigns = '1 or 2        '; else campaigns = 'Greater than 2'; 
  if age le 45 then age_cat = 'LE 45'; else age_cat = '45+ ';

keep contact year campaigns age_cat y;
run;

proc freq data=x; tables contact year campaigns age_cat y; run;
proc freq data=x; tables (contact year campaigns age_cat)* y /nocol norow nopercent; run;

proc surveyselect data=x(where=(y='no')) out=neg sampsize=4640 seed=42; run;
data pos; set x; where y='yes'; keep contact year campaigns age_cat y;run;
data balance; set neg pos; run;
proc freq data=balance; tables y; run;

proc surveyselect data=balance out=samp sampsize=20 ; run;

proc freq data=balance; tables (contact year campaigns age_cat)* y /nocol norow nopercent; run;





ods graphics on;
proc hpsplit data=mydata.bankfull;
   class y contact month;
   model y(event='yes') = contact month campaign pdays age;
/*   prune costcomplexity;*/
   partition fraction(validate=0.3 seed=123);
      OUTPUT OUT = SCORED;
run;

%INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Projects/separation.sas';
%separation(data = scored, score = P_TARGET1, y = target);



ODS GRAPHICS ON;
PROC HPSPLIT DATA=mydata.bank_train(DROP=row_num);
   CLASS TARGET _CHARACTER_;
   MODEL TARGET(event='1') = _NUMERIC_ _CHARACTER_;
   PRUNE costcomplexity;
   PARTITION FRACTION(VALIDATE=0.3 SEED=42);
   CODE FILE='C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data/bank_tree.sas';
   OUTPUT OUT = SCORED;
run;

DATA test_scored;
  SET MYDATA.bank_test;
  %INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data/bank_tree.sas';
RUN;

ods listing gpath="C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data/";
%INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Projects/separation.sas';
%separation(data = test_scored, score = P_TARGET1, y = target);

proc freq data=test_scored; tables P_TARGET1; run;


