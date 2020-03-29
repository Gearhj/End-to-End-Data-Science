
ODS GRAPHICS ON;

PROC TREEBOOST DATA = mydata.bank_train
	CATEGORICALBINS = 10
	INTERVALBINS = 100
	EXHAUSTIVE = 5000
	INTERVALDECIMALS = MAX
	LEAFSIZE = 32
	MAXBRANCHES = 2
	ITERATIONS = 1000
	MINCATSIZE = 50
	MISSING = USEINSEARCH
	SEED = 42
	SHRINKAGE = 0.1
	SPLITSIZE = 100
	TRAINPROPORTION = 0.6;
	INPUT &num_vars. / LEVEL = INTERVAL;
/*	INPUT &charx. / LEVEL = NOMINAL;*/
	TARGET TARGET / LEVEL = BINARY;
	IMPORTANCE NVARS = 50 OUTFIT = BASE_VARS;
	SUBSERIES BEST;
	CODE FILE = 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data/bank_GB.bin';
	SAVE MODEL = GBS_TEST FIT = FIT_STATS 
		IMPORTANCE = IMPORTANCE RULES = RULES;
RUN;

DATA GB_SCORED;
  SET mydata.bank_train;
  %INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data/bank_GB.bin';
RUN;

%INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Projects/GainLift.sas';
%GainLift(data=GB_SCORED, response=target, p=P_TARGET1, event=1, groups=10, 
GRAPHOPTS=BAR PANEL GRID BEST BASE);

%INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Projects/separation.sas';
%separation(data = GB_SCORED, score = P_TARGET1, y = target);

DATA GB_TEST;
  SET mydata.bank_test;
  %INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data/bank_GB.bin';
RUN;


%INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Projects/GainLift.sas';
%GainLift(data=GB_TEST, response=target, p=P_TARGET1, event=1, groups=10, 
GRAPHOPTS=BAR PANEL GRID BEST BASE);


ods listing gpath="C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data/";
%INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Projects/separation.sas';
%separation(data = GB_TEST, score = P_TARGET1, y = target);