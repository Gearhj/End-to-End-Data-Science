
/*Dataset location:  http://archive.ics.uci.edu/ml/datasets/Bank+Marketing#*/

LIBNAME MYDATA BASE "C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data";

FILENAME REFFILE 'C:\Users\James Gearheart\Desktop\SAS Book Stuff\Data\Bank_Loan\BankFull.xlsx';

PROC DELETE DATA=MYDATA.Bankfull; RUN;
PROC IMPORT DATAFILE=REFFILE
	DBMS=XLSX
	OUT= MYDATA.BankFull;
	GETNAMES=YES;
RUN;

PROC CONTENTS DATA=MYDATA.BankFull; RUN;

DATA MYDATA.BANKFULL;
  SET MYDATA.BANKFULL;
  IF y = 'yes' then TARGET = 1; ELSE TARGET = 0;
  ROW_NUM = _N_;

  /*Create dummy variables for categorical variables*/
  if job = "admin." then job_admin = 1; else job_admin = 0;
  if job = "blue-collar" then job_blue = 1; else job_blue = 0;
  if job = "technician" then job_tech = 1; else job_tech = 0;
  if job = "services" then job_serv = 1; else job_serv = 0;
  if job = "management" then job_manage = 1; else job_manage = 0;
  if job = "retired" then job_retire = 1; else job_retire = 0;
  if job = "entrepreneur" then job_entre = 1; else job_entre = 0;
  if job = "self-employed" then job_self = 1; else job_self = 0;
  if job = "housemaid" then job_maid = 1; else job_maid = 0;
  if job = "unemployed" then job_unem = 1; else job_unem = 0;
  if job = "student" then job_student = 1; else job_student = 0;
  if job = "unknown" then job_unkn = 1 ; else job_unkn = 0;

  if marital = "married" then mar_married = 1; else mar_married = 0;
  if marital = "single" then mar_single = 1; else mar_single = 0;
  if marital = "divorced" then mar_div = 1; else mar_div = 0;
  if marital = "unknown" then mar_unkn = 1; else mar_unkn = 0;
 
  if education = "university.degree" then edu_uni = 1; else edu_uni = 0;
  if education = "high.school" then edu_high = 1; else edu_high = 0;
  if education = "basic.9y" then edu_basic9 = 1; else edu_basic9 = 0;
  if education = "professional.course" then edu_pro = 1; else edu_pro = 0;
  if education = "basic.4y" then edu_basic4 = 1; else edu_basic4 = 0;
  if education = "basic.6y" then edu_basic6 = 1; else edu_basic6 = 0;
  if education = "unknown" then edu_unkn = 1; else edu_unkn = 0;
  if education = "illiterate" then edu_ill = 1; else edu_ill = 0;

  if default = "no" then default_no = 1; else default_no = 0;
  if default = "unknown" then default_unkn = 1; else default_unkn = 0;
  if default = "yes" then default_yes = 1; else default_yes = 0;

  if housing = "no" then housing_no = 1; else housing_no = 0;
  if housing = "unknown" then housing_unkn = 1; else housing_unkn = 0;
  if housing = "yes" then housing_yes = 1; else housing_yes = 0;

  if loan = "no" then loan_no = 1; else loan_no = 0;
  if loan = "unknown" then loan_unkn = 1; else loan_unkn = 0;
  if loan = "yes" then loan_yes = 1; else loan_yes = 0;

  if contact = "cellular" then contact_cell = 1; else contact_cell = 0;
  if contact = "telephone" then contact_tele = 1; else contact_tele = 0;

  if month = "may" then month_may = 1; else month_may = 0;
  if month = "jul" then month_jul = 1; else month_jul = 0;
  if month = "aug" then month_aug = 1; else month_aug = 0;
  if month = "jun" then month_jun = 1; else month_jun = 0;
  if month = "nov" then month_nov = 1; else month_nov = 0;
  if month = "apr" then month_apr = 1; else month_apr = 0;
  if month = "oct" then month_oct = 1; else month_oct = 0;
  if month = "sep" then month_sep = 1; else month_sep = 0;
  if month = "mar" then month_mar = 1; else month_mar = 0;
  if month = "dec" then month_dec = 1; else month_dec = 0;

  if day_of_week = "thu" then day_thu = 1; else day_thu = 0;
  if day_of_week = "mon" then day_mon = 1; else day_mon = 0;
  if day_of_week = "wed" then day_wed = 1; else day_wed = 0;
  if day_of_week = "tue" then day_tue = 1; else day_tue = 0;
  if day_of_week = "fri" then day_fri = 1; else day_fri = 0;

  if poutcome = "nonexistent" then pout_non = 1; else pout_non = 0;
  if poutcome = "failure" then pout_fail = 1; else pout_fail = 0;
  if poutcome = "success" then pout_succ = 1; else pout_succ = 0;

  DROP y duration job marital education default housing loan contact month day_of_week poutcome;
RUN;


PROC MEANS DATA=MYDATA.BankFull (drop=row_num) N NMISS MIN MAX MEAN MEDIAN STDDEV;
	VAR _NUMERIC_;
	OUTPUT OUT=BANK_MEANS;
RUN;

/*proc freq data=mydata.bankfull; tables pdays; run;*/

PROC FREQ DATA=MYDATA.BankFull ORDER=FREQ; TABLES _CHARACTER_; RUN;


/*Create a balanced dataset*/
PROC FREQ DATA=MYDATA.BankFull; TABLES TARGET; RUN;

PROC SURVEYSELECT DATA=MYDATA.BankFull(where=(TARGET=0)) OUT=neg SAMPSIZE=4640 SEED=42; RUN;
DATA pos; SET MYDATA.BankFull; WHERE TARGET=1; RUN;
DATA balance; SET neg pos; RUN;
PROC FREQ  DATA=balance; TABLES TARGET; RUN;


/*Split the modeling data into 70/30 ratio*/
PROC SURVEYSELECT DATA=balance RATE=0.3 OUTALL OUT=class SEED=42; RUN;
PROC FREQ DATA=class; TABLES selected; RUN;

DATA MYDATA.BANK_TRAIN MYDATA.BANK_TEST;
  SET class;
  IF selected = 0 THEN OUTPUT MYDATA.BANK_TRAIN; ELSE OUTPUT MYDATA.BANK_TEST;
  DROP selected;
RUN;

PROC FREQ DATA=MYDATA.BANK_TRAIN; TABLES TARGET; RUN;
PROC FREQ DATA=MYDATA.BANK_TEST; TABLES TARGET; RUN;

