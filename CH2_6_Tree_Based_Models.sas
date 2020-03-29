/*Create global variables for numeric variables*/
PROC CONTENTS NOPRINT DATA=TRAIN_ADJ (KEEP=_NUMERIC_ DROP=id host_id 
	price price_log)
	OUT=VAR3 (KEEP=name);
RUN;

PROC SQL NOPRINT;
	SELECT name INTO: tree_num separated by " " FROM VAR3;
QUIT;

%PUT &tree_num;

/*Create global variables for character variables*/
PROC CONTENTS NOPRINT DATA=TRAIN_ADJ (KEEP=_CHARACTER_ 
	DROP=Property_CAT)
	OUT=VAR4 (KEEP=name);
RUN;

PROC SQL NOPRINT;
	SELECT name INTO: tree_char separated by " " FROM VAR4;
QUIT;

%PUT &tree_char;

ods graphics on;

PROC HPSPLIT DATA=WORK.TRAIN_ADJ seed=42;
   CLASS &tree_char.;
   MODEL price = &tree_char. &tree_num.;
   OUTPUT OUT=hpsplout;
   CODE FILE='C:\Users\James Gearheart\Desktop\SAS Book Stuff\Data\hpsplexc.sas';
run;

DATA TEST_SCORED;
  SET TEST_ADJ;
  %INCLUDE 'C:\Users\James Gearheart\Desktop\SAS Book Stuff\Data\hpsplexc.sas';
RUN;

****************************************;
*RANDOM FOREST                          ;
****************************************;
proc hpforest data=WORK.TRAIN_ADJ
	maxtrees= 500 vars_to_try=7
	seed=42 trainfraction=0.6
	maxdepth=20 leafsize=6
	alpha= 0.1;
	target price_log/ level=interval;
	input &tree_num. / level=interval;
	input &tree_char. / level=nominal;
	ods output train_scored fitstatistics = fit;
	SAVE FILE = "C:\Users\James Gearheart\Desktop\SAS Book Stuff\Data\rfmodel_fit.bin";
run;


PROC TREEBOOST DATA=TRAIN_ADJ
	CATEGORICALBINS = 10
	INTERVALBINS = 400
	EXHAUSTIVE = 5000
	INTERVALDECIMALS = MAX
	LEAFSIZE = 100
	MAXBRANCHES = 6
	ITERATIONS = 500
	MINCATSIZE = 50
	MISSING = USEINSEARCH
	SEED = 42
	SHRINKAGE = 0.1
	SPLITSIZE = 100
	TRAINPROPORTION = 0.6;
	INPUT &tree_num. / LEVEL=INTERVAL;
	INPUT &tree_char./ LEVEL=NOMINAL;
	TARGET PRICE_LOG / LEVEL=INTERVAL;
	IMPORTANCE NVARS=50 OUTFIT=BASE_VARS;
	SUBSERIES BEST;
	CODE FILE="C:\Users\James Gearheart\Desktop\SAS Book Stuff\Data\BOOST_MODEL_FIT.sas"
	NOPREDICTION;
	SAVE MODEL=GBS_TEST FIT=FIT_STATS IMPORTANCE=IMPORTANCE RULES=RULES;
RUN;