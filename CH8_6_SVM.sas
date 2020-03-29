
/*Visualize the data distribution*/

ods graphics / attrpriority=none;
proc sgplot data=mydata.bank_train (where=(pdays ne 999));
styleattrs datasymbols=(circlefilled trianglefilled) ;
	scatter x=pdays y=age / group=target;
	title 'Scatter Plot of Bank Marketing Data';
run;




/*Polynomial */
 PROC HPSVM DATA=mydata.bank_train;
 	 KERNAL POLYNOM;
     INPUT pdays age pout_succ previous contact_tele / LEVEL=interval;
     TARGET target / LEVEL=binary;
     PENALTY C=0.1 to 0.5 by 0.05;
     SELECT FOLD=3 CV=SPLIT;
	 OUTPUT OUTCLASS=outclass OUTFIT=outfit OUTTEST=outest;
 RUN;

 proc svmscore data=mydata.bank_test out=score
     inclass=outclass infit=outfit inest=outest;
 run;


ods listing gpath="C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data/";
%INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Projects/separation.sas';
%separation(data = sout1, score = _ALPHA_, y = target);


/*RBF */
PROC HPSVM DATA=mydata.bank_train METHOD=activeset;
     KERNAL RBF / K_PAR = 1.5;
     INPUT pdays age pout_succ previous contact_tele  /LEVEL=interval;
     TARGET target / LEVEL=binary;
     OUTPUT OUTCLASS=outclass OUTFIT=outfit OUTEST=outest;
RUN;

  proc svmscore data=mydata.bank_test out=score
     inclass=outclass infit=outfit inest=outest;
 run;


ods listing gpath="C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data/";
%INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Projects/separation.sas';
%separation(data = sout1, score = _ALPHA_, y = target);