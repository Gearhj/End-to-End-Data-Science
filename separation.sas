%macro separation(data = , score = , y = );
***********************************************************;
* THE MACRO IS TO EVALUATE THE SEPARATION POWER OF A      *;
* SCORECARD                                               *; 
* ------------------------------------------------------- *;
* PARAMETERS:                                             *;
*  DATA : INPUT DATASET                                   *;
*  SCORE: SCORECARD VARIABLE                              *;
*  Y    : RESPONSE VARIABLE IN (0, 1)                     *;
* ------------------------------------------------------- *;
* OUTPUTS:                                                *;
*  SEPARATION_REPORT.TXT                                  *;
*  A SEPARATION SUMMARY REPORT IN TXT FORMAT              *;
*  NAMED AS THE ABOVE WITH PREDICTIVE MEASURES INCLUDING  *;
*  KS, AUC, GINI, AND DIVERGENCE                          *;
* ------------------------------------------------------- *;
* CONTACT:                                                *;
*  WENSUI.LIU@53.COM                                      *;
***********************************************************;
 
options nonumber nodate orientation = landscape linesize = 160 nocenter 
        formchar = "|----|+|---+=|-/\<>*" formdlim=' ' ls = 150; 
 
*** DEFAULT GROUP NUMBER FOR REPORT ***;
%let grp = 10;
 
data _tmp1 (keep = &y &score);
  set &data;
  where &y in (1, 0)  and &score ~= .;
run;
 
filename lst_out temp;
 
proc printto new print = lst_out;
run;
 
*** CONDUCT NON-PARAMETRIC TESTS ***; 
ods output wilcoxonscores = _wx;
ods output KolSmir2Stats = _ks;
proc npar1way wilcoxon edf data = _tmp1;
  class &y;
  var &score;
run;
 
proc printto;
run;
 
proc sort data = _wx;
  by class;
run;
 
*** CALCULATE ROC AND GINI ***;
data _null_;
  set _wx end = eof;
  by class;
 
  array a{2, 3} _temporary_;
  if _n_ = 1 then do;
    a[1, 1] = n;
    a[1, 2] = sumofscores;
    a[1, 3] = expectedsum;
  end;
  else do;
    a[2, 1] = n;
  end;
  if eof then do;
    auc  = (a[1, 2] - a[1, 3]) / (a[1, 1] * a[2, 1])  + 0.5;
    if auc <= 0.5 then auc = 1 - auc;
    gini = 2 * (auc - 0.5);  
    call execute('%let auc = '||put(auc, 10.4)||';');
    call execute('%let gini = '||put(gini, 10.4)||';');
  end;
run;
 
*** CALCULATE KS ***;
data _null_;
  set _ks;
 
  if _n_ = 1 then do;
    ks = nvalue2 * 100;
    call execute('%let ks = '||put(ks, 10.4)||';');
  end;
run;
 
*** CAPTURE SCORE POINT FOR MAX KS ***;
data _null_;
  infile lst_out;
  input @" at Maximum = " ks_score;
  output;
  call execute('%let ks_score = '||put(ks_score, 10.4)||';');
  stop;
run;
 
proc summary data = _tmp1 nway;
  class &y;
  output out = _data_ (drop = _type_ _freq_)
  mean(&score.) = mean var(&score.) = variance;
run;
 
*** CALCULATE DIVERGENCE ***;
data _null_;
  set _last_ end = eof;
  array a{2, 2} _temporary_;
  if _n_ = 1 then do;
    a[1, 1] = mean;
    a[1, 2] = variance;
  end;
  else do;
    a[2, 1] = mean;
    a[2, 2] = variance;
  end;
  if eof then do;
    divergence = (a[1, 1] - a[2, 1]) ** 2 / ((a[1, 2] + a[2, 2]) / 2);
    call execute('%let divergence = '||put(divergence, 10.4)||';'); 
  end; 
run;
 
*** CAPTURE THE DIRECTION OF SCORE ***;
ods listing close;
ods output spearmancorr = _cor;
proc corr data = _tmp1 spearman;
  var &y;
  with &score;
run;
ods listing;
  
data _null_;
  set _cor;
  if &y >= 0 then do;
    call symput('desc', 'descending');
  end;
  else do;
    call symput('desc', ' ');
  end;
run;
%put &desc;
 
proc rank data = _tmp1 out = _tmp2 groups = &grp ties = low;
  var &score;
  ranks rank;
run;
 
proc summary data = _last_ nway;
  class rank;
  output out = _data_ (drop = _type_ rename = (_freq_ = freq))
  min(&score) = min_score max(&score) = max_score
  sum(&y) = bads;
run;
 
proc sql noprint;
  select sum(bads) into :bcnt from _last_;
  select sum(freq) - sum(bads) into :gcnt from _last_;
quit;
 
proc sort data = _last_ (drop = rank);
  by &desc min_score;
run;
 
data _data_;
  set _last_;
  by &desc min_score;
 
  i + 1; 
  percent = i / 100; 
  good  = freq - bads;
  odds  = good / bads;
 
  hit_rate = bads / freq;
  retain cum_bads cum_freq;
  cum_bads + bads;
  cum_freq + freq;
  cum_hit_rate = cum_bads / cum_freq;
 
  cat_rate = bads / &bcnt;
  retain cum_cat_rate;
  cum_cat_rate + cat_rate; 
 
  format symbol $4.;
  if i = 1 then symbol = 'BAD';
  else if i = &grp - 1 then symbol = 'V';
  else if i = &grp then symbol = 'GOOD';
  else symbol = '|';
run;
 
proc printto print = "%upcase(%trim(&score))_SEPARATION_REPORT.TXT" new;
run;
 
proc report data = _last_ spacing = 1 split = "/" headline nowd;
  column("GOOD BAD SEPARATION REPORT FOR %upcase(%trim(&score)) IN DATA %upcase(%trim(&data))/
          MAXIMUM KS = %trim(&ks) AT SCORE POINT %trim(&ks_score)/   
          ( AUC STATISTICS = %trim(&auc), GINI COEFFICIENT = %trim(&gini), DIVERGENCE = %trim(&divergence) )/ /"
         percent symbol min_score max_score good bads freq odds hit_rate cum_hit_rate cat_rate cum_cat_rate);
 
  define percent      / noprint order order = data;
  define symbol       / "" center               width = 5 center;
  define min_score    / "MIN/SCORE"             width = 10 format = 9.4        analysis min center;
  define max_score    / "MAX/SCORE"             width = 10 format = 9.4        analysis max center;
  define good         / "GOOD/#"                width = 10 format = comma9.    analysis sum;
  define bads         / "BAD/#"                 width = 10 format = comma9.    analysis sum;
  define freq         / "TOTAL/#"               width = 10 format = comma9.    analysis sum;
  define odds         / "ODDS"                  width = 10 format = 8.2        order;
  define hit_rate     / "BAD/RATE"              width = 10 format = percent9.2 order center;
  define cum_hit_rate / "CUMULATIVE/BAD RATE"   width = 10 format = percent9.2 order;
  define cat_rate     / "BAD/PERCENT"           width = 10 format = percent9.2 order center;
  define cum_cat_rate / "CUMU. BAD/PERCENT"     width = 10 format = percent9.2 order; 
 
  rbreak after / summarize dol skip;
run; 
 
proc printto;
run;
 
***********************************************************;
*                     END OF THE MACRO                    *;
***********************************************************; 
%mend separation;
 
