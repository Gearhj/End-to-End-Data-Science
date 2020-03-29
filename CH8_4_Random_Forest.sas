/*proc contents data=mydata.bank_train; run;*/

PROC HPFOREST DATA=mydata.bank_train 
	VARS_TO_TRY=8 MAXTREES=300 TRAINFRACTION=0.6
	MAXDEPTH=15 LEAFSIZE=10
	ALPHA=0.1;
	TARGET target/LEVEL=binary;
	INPUT &num_vars. / LEVEL=interval;
/*	INPUT &char_vars. / LEVEL=nominal;*/
	SAVE FILE = 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data/bank_RF.bin';
	ODS OUTPUT FITSTATISTICS = FITSTATS(rename=(Ntrees=Trees));
run;


PROC HP4SCORE DATA=mydata.bank_test;
  ID ROW_NUM;
  SCORE FILE = 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data/bank_RF.bin'
  OUT = RF_SCORED;
RUN;

%INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Projects/GainLift.sas';
%GainLift(data=RF_SCORED, response=target, p=P_TARGET1, event=1, groups=10, 
GRAPHOPTS=BAR PANEL GRID BEST BASE);

ods listing gpath="C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data/";
%INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Projects/separation.sas';
%separation(data = RF_SCORED, score = P_TARGET1, y = target);


data fitstats;
   set fitstats;
   label Trees = 'Number of Trees';
   label MiscAll = 'Full Data';
   label Miscoob = 'OOB';
run;

proc sgplot data=fitstats;
   title "OOB vs Training";
   series x=Trees y=MiscAll;
   series x=Trees y=MiscOob/lineattrs=(pattern=shortdash thickness=2);
   yaxis label='Misclassification Rate';
run;

%INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Projects/separation.sas';
%separation(data = RF_SCORED&iteration., score = P_TARGET1, y = target);



%macro hpforest(Vars=);
proc hpforest data=mydata.bank_train  maxtrees=300
   vars_to_try=&Vars.;
	TARGET target/LEVEL=binary;
	INPUT &num_vars. / LEVEL=interval;
   ods output
   FitStatistics = fitstats_vars&Vars.(rename=(Miscoob=VarsToTry&Vars.));
run;
%mend;

%hpforest(vars=all);
%hpforest(vars=40);
%hpforest(vars=26);
%hpforest(vars=7);
%hpforest(vars=2);

data fitstats;
   merge
   fitstats_varsall fitstats_vars40 fitstats_vars26 fitstats_vars7 fitstats_vars2;
   rename Ntrees=Trees;
   label VarsToTryAll = "Vars=All";
   label VarsToTry40 = "Vars=40";
   label VarsToTry26 = "Vars=26";
   label VarsToTry7 = "Vars=7";
   label VarsToTry2 = "Vars=2";
run;

proc sgplot data=fitstats;
   title "Misclassification Rate for Various VarsToTry Values";
   series x=Trees y = VarsToTryAll/lineattrs=(Color=black);
   series x=Trees y=VarsToTry40/lineattrs=(Pattern=ShortDash Thickness=2);
   series x=Trees y=VarsToTry26/lineattrs=(Pattern=ShortDash Thickness=2);
   series x=Trees y=VarsToTry7/lineattrs=(Pattern=MediumDashDotDot Thickness=2);
   series x=Trees y=VarsToTry2/lineattrs=(Pattern=LongDash Thickness=2);
   yaxis label='OOB Misclassification Rate';
run;











/*Hyperparameter tuning*/
%MACRO forest(iteration, maxtrees, vars_to_try, maxdepth, leafsize, alpha);
PROC HPFOREST DATA=mydata.bank_train 
	VARS_TO_TRY=&vars_to_try. MAXTREES=&maxtrees. TRAINFRACTION=0.6
	MAXDEPTH=&maxdepth. LEAFSIZE=&leafsize.
	ALPHA=&alpha.;
	TARGET target/LEVEL=binary;
	INPUT &num_vars. / LEVEL=interval;
/*	INPUT &char_vars. / LEVEL=nominal;*/
	SAVE FILE = "C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data/bank_RF_&iteration.bin";
	ODS OUTPUT FITSTATISTICS = FIT;
run;

PROC HP4SCORE DATA=mydata.bank_train;
    ID ROW_NUM;
    SCORE FILE = 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data/bank_RF_&iteration.bin'
    OUT = RF_TRAIN_&iteration;
RUN;

PROC HP4SCORE DATA=mydata.bank_test;
    ID ROW_NUM;
    SCORE FILE = 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data/bank_RF_&iteration.bin'
    OUT = RF_TEST_&iteration;
RUN;

%INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Projects/separation.sas';
%separation(data = RF_TRAIN_&iteration., score = P_TARGET1, y = target);

PROC APPEND BASE=MYDATA.RF_GINI_BASE DATA=GINIOUT; RUN;

%INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Projects/separation.sas';
%separation(data = RF_TEST_&iteration., score = P_TARGET1, y = target);

PROC APPEND BASE=MYDATA.RF_GINI_BASE DATA=GINIOUT; RUN;

%MEND;
%forest(1, 250, 10, 5, 5, 0.01);
%forest(2, 350, 8, 7, 10, 0.1);
%forest(3, 500, 5, 10, 15, 0.1);








%macro hpforestStudy (nVarsList=57,maxTrees=200);
	%let nTries = %sysfunc(countw(&nVarsList.));

	/* Loop over all specified number of variables to try */
	%do i = 1 %to &nTries.;
		%let thisTry = %sysfunc(scan(&nVarsList.,&i));

		/* Run HP Forest for this number of variables */
		proc hpforest data=mydata.bank_train maxtrees=&maxTrees. vars_to_try=&thisTry.;
			input &num_vars. /level=interval;
			target TARGET / level=binary;
			ods output fitstatistics=fitstats_vars&thisTry.;
		run;

		/* Add the value of varsToTry for these fit stats */
		data fitstats_vars&thisTry.;
			length varsToTry $ 8;
			set fitstats_vars&thisTry.;
			varsToTry = "&thisTry.";
		run;

		/* Append to the single cumulative fit statistics table */
		proc append base=fitStats data=fitstats_vars&thisTry.;
		run;

	%end;
%mend hpforestStudy;

%hpforestStudy(nVarsList=5 10 25 50 all,maxTrees=100);

