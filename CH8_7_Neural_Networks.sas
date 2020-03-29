

PROC HPNEURAL DATA=MYDATA.BANK_TRAIN;
   ARCHITECTURE MLP;
   INPUT &num_vars.;
   TARGET target / LEVEL=nom;
   HIDDEN 10;
   HIDDEN 5;
   TRAIN;
   SCORE OUT=scored_NN;
   CODE FILE= 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data/NN_Model.sas';
run;

ods listing gpath="C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data/";
%INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Projects/separation.sas';
%separation(data = scored_NN, score = P_TARGET1, y = target);




DATA test_scored;
  SET MYDATA.bank_test;
  %INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data/NN_Model.sas';
RUN;

ods listing gpath="C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data/";
%INCLUDE 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Projects/separation.sas';
%separation(data = test_scored, score = P_TARGET1, y = target);



