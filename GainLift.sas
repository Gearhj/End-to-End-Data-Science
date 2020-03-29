%macro oneplot(oneplot);
     %if %upcase(%substr(&oneplot,1,2))=GA %then %do;
       %let _title="Gain"; %let _yvar=Gain;
       %let _baseline=BaseGain;
       %let _best=BestGain;
     %end;
     %else %if %upcase(%substr(&oneplot,1,2))=CL %then %do;
       %let _title="Cumulative Lift"; %let _yvar=CumLift;
       %let _baseline=BaseCumLift;
       %let _best=BestCumLift;
     %end;
     %else %if %upcase(%substr(&oneplot,1,2))=LI %then %do;
       %let _title="Lift"; %let _yvar=Lift;
       %let _baseline=BaseLift;
       %let _best=BestLift;
     %end;
     %else %if %upcase(%substr(&oneplot,1,2))=CC %then %do;
       %let _title="Cumulative Percent Captured"; %let _yvar=CumPctCaptured;
       %let _baseline=BaseCumPctCaptured;
       %let _best=BestCumPctCaptured;
     %end;
     %else %if %upcase(%substr(&oneplot,1,2))=PC %then %do;
       %let _title="Percent Captured"; %let _yvar=PctCaptured;
       %let _baseline=BasePctCaptured;
       %let _best=BestPctCaptured;
     %end;
     %else %if %upcase(%substr(&oneplot,1,2))=CR %then %do;
       %let _title="Cumulative Percent Response"; %let _yvar=CumPctResp;
       %let _baseline=BaseCumPctResp;
       %let _best=BestCumPctResp;
     %end;
     %else %if %upcase(%substr(&oneplot,1,2))=PR %then %do;
       %let _title="Percent Response"; %let _yvar=PctResp;
       %let _baseline=BasePctResp;
       %let _best=BestPctResp;
     %end;
     %else %do;
       %put ERROR: Valid PLOTS= values are GAIN, CLIFT, LIFT, CCAPT, PCAPT, CRESP, or PRESP;
       %goto exit;
     %end;
     proc sgrender data=&out template=GainLiftPlot;
       run;
     %exit:
%mend oneplot;

/* ------------------------------------------------------------------------------ */

%macro GainLift(version, data=_last_, response=, p=, event=, 
       plots=, groups=20, xaxis=SelectedPct, tableopts=TABLE NOBEST NOBASE,
       graphopts=LINE PANEL GRID BEST BASE, out=_GainLift);

%let time = %sysfunc(datetime());
%let _version=1.1;
%if &version ne %then %put GainLift macro Version &_version;

%if &data=_last_ %then %let data=&syslast;
%let _opts = %sysfunc(getoption(notes)) 
            _last_=%sysfunc(getoption(_last_));
%if &version ne debug %then %str(options nonotes;);

/* Check for newer version */
 %if %sysevalf(&sysver >= 8.2) %then %do;
  %let _notfound=0;
  filename _ver url 'http://ftp.sas.com/techsup/download/stat/versions.dat' termstr=crlf;
  data _null_;
    infile _ver end=_eof;
    input name:$15. ver;
    if upcase(name)="&sysmacroname" then do;
       call symput("_newver",ver); stop;
    end;
    if _eof then call symput("_notfound",1);
    run;
  %if &syserr ne 0 or &_notfound=1 %then
    %put &sysmacroname: Unable to check for newer version;
  %else %if %sysevalf(&_newver > &_version) %then %do;
    %put &sysmacroname: A newer version of the &sysmacroname macro is available.;
    %put %str(         ) You can get the newer version at this location:;
    %put %str(         ) http://support.sas.com/ctx/samples/index.jsp;
  %end;
 %end;

  /* DATA= data set option must be specified and must exist */
  %if &data= or %sysfunc(exist(&data)) ne 1 %then %do;
    %put ERROR: DATA= data set not specified or not found.;
    %goto exit;
  %end;
  /* RESPONSE= check */
  %if &response= %then %do;
    %put ERROR: The RESPONSE= parameter is required.;
    %goto exit;
  %end;
  /* P= check */
  %if &p= %then %do;
    %put ERROR: The P= parameter is required.;
    %goto exit;
  %end;
  /* EVENT= check */
  %if &EVENT= %then %do;
    %put ERROR: The EVENT= parameter is required.;
    %goto exit;
  %end;
  /* GROUPS= check */
  %if &groups ne 10 and &groups ne 20 %then %do;
    %put ERROR: GROUPS= must be 10 or 20;
    %goto exit;
  %end;
  /* XAXIS check */
  %if       %upcase(%substr(&xaxis,1,1))=G %then %let _xvar=_grp;
  %else %if %upcase(%substr(&xaxis,1,1))=S %then %let _xvar=SelectedPct;
  %else %if %upcase(%substr(&xaxis,1,1))=P %then %let _xvar=Percentile;
  %else %do;
    %put ERROR: XAXIS= must be GROUPNUM or PERCENTILE or SELECTEDPCT;
    %goto exit;
  %end;
  /* GRAPHOPTS */
  %let graph=L;
  %let grid=ON;
  %let panel=Y;
  %let base=1;
  %let best=1;
  %let i=1;
  %do %while (%scan(&graphopts,&i) ne %str() );
     %let arg&i=%scan(&graphopts,&i);
     %if %upcase(&&arg&i)=PANEL %then %let panel=Y;
     %else %if %upcase(&&arg&i)=NOPANEL %then %let panel=N;
     %else %if %upcase(&&arg&i)=GRID %then %let grid=ON;
     %else %if %upcase(&&arg&i)=NOGRID %then %let grid=OFF;
     %else %if %upcase(&&arg&i)=BASE %then %let base=1;
     %else %if %upcase(&&arg&i)=NOBASE %then %let base=0;
     %else %if %upcase(&&arg&i)=BEST %then %let best=1;
     %else %if %upcase(&&arg&i)=NOBEST %then %let best=0;
     %else %if %upcase(&&arg&i)=NOGRAPH %then %let graph=N;
     %else %if %upcase(&&arg&i)=LINE %then %let graph=L;
     %else %if %upcase(&&arg&i)=BAR %then %let graph=B;
     %else %do;
       %put ERROR: Valid GRAPHOPTS= values are LINE, BAR, NOGRAPH, PANEL, NOPANEL, GRID, NOGRID, BASE, NOBASE, BEST, NOBEST;
       %goto exit;
     %end;
     %let i=%eval(&i+1);
  %end;
  /* TABLEOPTS */
  %let table=1;
  %let tabbase=0;
  %let tabbest=0;
  %let i=1;
  %do %while (%scan(&tableopts,&i) ne %str() );
     %let arg&i=%scan(&tableopts,&i);
     %if %upcase(&&arg&i)=TABLE %then %let table=1;
     %else %if %upcase(&&arg&i)=NOTABLE %then %let table=0;
     %else %if %upcase(&&arg&i)=BASE %then %let tabbase=1;
     %else %if %upcase(&&arg&i)=NOBASE %then %let tabbase=0;
     %else %if %upcase(&&arg&i)=BEST %then %let tabbest=1;
     %else %if %upcase(&&arg&i)=NOBEST %then %let tabbest=0;
     %else %do;
       %put ERROR: Valid TABLEOPTS= values are TABLE, NOTABLE, BASE, NOBASE, BEST, NOBEST;
       %goto exit;
     %end;
     %let i=%eval(&i+1);
  %end;
  %if &plots ne %then %let panel=N;

/* ----------------- Compute group statistics ----------------- */
  ods exclude all;
  ods output nlevels=_nlvls;
  proc freq data=&data nlevels;
   where missing(&response) ne 1;
   table &response;
   run;
  ods select all;
  data _null_;
   set _nlvls;
   call symput ("nlvls",nlevels);
   run;
  %if &nlvls ne 2 %then %do;
   %put ERROR: Response variable, &response, must have exactly two levels.;
   %goto exit;
  %end;
  proc rank data=&data out=_ranks groups=&groups;
   var &p; ranks _rp;
   run;
  data _ranks;
   set _ranks;
   if &response=&event then _y=1; else _y=0;
   _grp=&groups-_rp;                  
   run;
  proc summary data=_ranks;
   class _grp; var _y;
   output out=_EvntProp mean=EvntProp sum=EvntCnt;
   run;
  data _missgrps;                     * Add any missing groups and set;
   do _grp=.,1 to &groups;            * statistics to zero in missing groups;
     _freq_=0; EvntProp=0; EvntCnt=0; output;
   end;
   run;
  data _EvntProp;
   merge _missgrps _EvntProp;
   by _grp;
   run;
  data &out;
   set _EvntProp nobs=_n;
   length PctRange $ 8;
   retain NObs TotEvntpct TotEvntCnt NumGroups EvntsLeft;
   if _n_=1 then do;
    NObs=_freq_; TotEvntPct=EvntProp*100; TotEvntCnt=EvntCnt;
    NumGroups=_n-1; 
    EvntsLeft=TotEvntCnt;
    delete;
   end;
   else do;
    SelectedPct=_grp*100/NumGroups;
    Percentile=100-(_grp-1)*100/NumGroups; 
    PctRange=cats(Percentile," - ",Percentile-100/NumGroups);
    CumEvntCnt+EvntCnt;
    CumGrpCnt+_freq_;
    BestEvntCnt=ifn(EvntsLeft>_freq_,_freq_,EvntsLeft); 
    CumBestEvntCnt+BestEvntCnt;
    EvntsLeft=EvntsLeft-BestEvntCnt;

    /* Percent Response */
    PctResp=100*EvntProp;                  
    BasePctResp=TotEvntPct;                
    if _freq_=0 then BestPctResp=0; else
    BestPctResp=100*BestEvntCnt/_freq_;                  

    /* Cumulative Percent Response */
    if CumGrpCnt=0 then CumPctResp=0; else
    CumPctResp=100*(CumEvntCnt/CumGrpCnt); 
    BaseCumPctResp=TotEvntPct;             
    BestCumPctResp=100*(CumBestEvntCnt/CumGrpCnt); 

    /* Percent Captured */
    PctCaptured=100*(EvntCnt/TotEvntCnt);  
    BasePctCaptured=100*_freq_/NObs;
    BestPctCaptured=100*(BestEvntCnt/TotEvntCnt);  

    /* Cumulative Percent Captured */
    CumPctCaptured=100*(CumEvntCnt/TotEvntCnt);
    BaseCumPctCaptured=100*CumGrpCnt/NObs;
    BestCumPctCaptured=100*(CumBestEvntCnt/TotEvntCnt);

    /* Lift */
    Lift=PctResp/TotEvntPct;  
    BaseLift=1;
    BestLift=BestPctResp/TotEvntPct;                   
    
    /* Cumulative Lift */
    CumLift=CumPctResp/TotEvntPct; 
    BaseCumLift=1;
    BestCumLift=BestCumPctResp/TotEvntPct;             

    /* Gain */
    Gain=100*abs(CumLift-1);  
    BaseGain=0;
    BestGain=100*abs(BestCumLift-1);                         

    drop _type_;
   end;
   label selectedpct="Depth"
         PctRange="Percentile Range"
         CumLift="Cumulative Lift"
         PctCaptured="Percent Captured"
         _grp="Group"
         _freq_="Group Size"
         EvntCnt="Number of Events"
          BestEvntCnt="Best Possible Number of Events"
          CumEvntCnt="Cumulative Number of Events"
          CumBestEvntCnt="Best Possible Cumulative Number of Events"
         PctResp="Percent Response"
          BasePctResp="Baseline Percent Response"
          BestPctResp="Best Possible Percent Response"
         CumPctResp="Cumulative Percent Response"
          BaseCumPctResp="Baseline Cumulative Percent Response"
          BestCumPctResp="Best Possible Cumulative Percent Response"
         PctCaptured="Percent Captured"
          BasePctCaptured="Baseline Percent Captured"
          BestPctCaptured="Best Possible Percent Captured"
         CumPctCaptured="Cumulative Percent Captured"
          BaseCumPctCaptured="Baseline Cumulative Percent Captured"
          BestCumPctCaptured="Best Possible Cumulative Percent Captured"
         CumLift="Cumulative Lift"
          BaseCumLift="Baseline Cumulative Lift"
          BestCumLift="Best Possible Cumulative Lift"
          BaseLift="Baseline Lift"
          BestLift="Best Possible Lift"
          BaseGain="Baseline Gain"
          BestGain="Best Possible Gain"
         ;
   run;
   options notes;
   %put NOTE: The data set %upcase(&out) was created.;
   %if &version ne debug %then options nonotes;;

/* Statistics table */  
%if &table %then %do;
proc print data=&out label;
  id SelectedPct;
  var PctRange _freq_ 
    EvntCnt CumEvntCnt
      %if &tabbest %then BestEvntCnt;
    PctResp
      %if &tabbase %then BasePctResp;
      %if &tabbest %then BestPctResp;
    CumPctResp
      %if &tabbase %then BaseCumPctResp;
      %if &tabbest %then BestCumPctResp;
    PctCaptured
      %if &tabbase %then BasePctCaptured;
      %if &tabbest %then BestPctCaptured;
    CumPctCaptured
      %if &tabbase %then BaseCumPctCaptured;
      %if &tabbest %then BestCumPctCaptured;
    Lift
      %if &tabbase %then BaseLift;
      %if &tabbest %then BestLift;
    CumLift
      %if &tabbase %then BaseCumLift;
      %if &tabbest %then BestCumLift;
    Gain
      %if &tabbase %then BaseGain;
      %if &tabbest %then BestGain;
  ;
  sum _freq_ EvntCnt;
  run;
%end;
   
/* ----------------- Graph templates ----------------- */   
   %if %upcase(%substr(&graph,1,1))=N %then %goto exit;
   proc template;
      define statgraph GainLiftPanel;
      mvar _xvar;
      begingraph / designheight=defaultdesignwidth;
         layout lattice / rows=4 columns=2 columndatarange=union;

            column2headers;
              entry textattrs=(weight=bold) "Cumulative";
              entry textattrs=(weight=bold) "NonCumulative";
            endcolumn2headers;
            rowheaders;
              entry textattrs=(weight=bold) '%Response';
              entry textattrs=(weight=bold) '%Captured';
              entry textattrs=(weight=bold) "Lift";
              entry textattrs=(weight=bold) "Gain";
            endrowheaders;

            columnaxes;
              columnaxis / griddisplay=&grid 
                           discreteopts=(tickvaluefitpolicy=thin);
              columnaxis / griddisplay=&grid
                           discreteopts=(tickvaluefitpolicy=thin);
            endcolumnaxes;

         *Row 1 - %Response;
            layout overlay / yaxisopts=(display=(line ticks tickvalues) 
                   griddisplay=&grid);
              %if %upcase(%substr(&graph,1,1))=L %then %do;
                %if &Base %then
                 seriesplot y=BaseCumPctResp x=_xvar / lineattrs=GraphData2;;
                %if &Best %then
                 seriesplot y=BestCumPctResp x=_xvar / lineattrs=GraphData3;;
                seriesplot y=CumPctResp     x=_xvar / lineattrs=GraphData1; 
              %end;
              %else %do;
                barchartparm y=CumPctResp     x=_xvar;
                %if &Base %then
                 seriesplot y=BaseCumPctResp x=_xvar / lineattrs=GraphData2;;
                %if &Best %then
                 seriesplot y=BestCumPctResp x=_xvar / lineattrs=GraphData3;;
              %end;
              endlayout;

            layout overlay / yaxisopts=(display=(line ticks tickvalues) 
                   griddisplay=&grid);
              %if %upcase(%substr(&graph,1,1))=L %then %do;
                %if &Base %then
                 seriesplot y=BasePctResp x=_xvar / name="Baseline" legendlabel="Baseline" lineattrs=GraphData2;;
                %if &Best %then
                 seriesplot y=BestPctResp x=_xvar / name="Best" legendlabel="Best Possible" lineattrs=GraphData3;;
                seriesplot y=PctResp     x=_xvar / lineattrs=GraphData1; 
              %end;
              %else %do;
                barchartparm y=PctResp     x=_xvar;
                %if &Base %then
                 seriesplot y=BasePctResp x=_xvar / name="Baseline" legendlabel="Baseline" lineattrs=GraphData2;;
                %if &Best %then
                 seriesplot y=BestPctResp x=_xvar / name="Best" legendlabel="Best Possible" lineattrs=GraphData3;;
              %end;
              endlayout;

         *Row 2 - %Captured;
            layout overlay / yaxisopts=(display=(line ticks tickvalues) 
                   griddisplay=&grid);
              %if %upcase(%substr(&graph,1,1))=L %then %do;
                %if &Base %then
                 seriesplot y=BaseCumPctCaptured x=_xvar / lineattrs=GraphData2;;
                %if &Best %then
                 seriesplot y=BestCumPctCaptured x=_xvar / lineattrs=GraphData3;;
                seriesplot y=CumPctCaptured     x=_xvar / lineattrs=GraphData1; 
              %end;
              %else %do;
                barchartparm y=CumPctCaptured     x=_xvar;
                %if &Base %then
                 seriesplot y=BaseCumPctCaptured x=_xvar / lineattrs=GraphData2;;
                %if &Best %then
                 seriesplot y=BestCumPctCaptured x=_xvar / lineattrs=GraphData3;;
              %end;
              endlayout;

            layout overlay / yaxisopts=(display=(line ticks tickvalues) 
                   griddisplay=&grid);
              %if %upcase(%substr(&graph,1,1))=L %then %do;
                %if &Base %then
                 seriesplot y=BasePctCaptured x=_xvar / lineattrs=GraphData2;;
                %if &Best %then
                 seriesplot y=BestPctCaptured x=_xvar / lineattrs=GraphData3;;
                seriesplot y=PctCaptured     x=_xvar / lineattrs=GraphData1; 
              %end;
              %else %do;
                barchartparm y=PctCaptured     x=_xvar;
                %if &Base %then
                 seriesplot y=BasePctCaptured x=_xvar / lineattrs=GraphData2;;
                %if &Best %then
                 seriesplot y=BestPctCaptured x=_xvar / lineattrs=GraphData3;;
              %end;
              endlayout;

         *Row 3 - Lift;
            layout overlay / yaxisopts=(display=(line ticks tickvalues) 
                   griddisplay=&grid);
              %if %upcase(%substr(&graph,1,1))=L %then %do;
                %if &Base %then
                 seriesplot y=BaseCumLift x=_xvar / lineattrs=GraphData2;;
                %if &Best %then
                 seriesplot y=BestCumLift x=_xvar / lineattrs=GraphData3;;
                seriesplot y=CumLift     x=_xvar / lineattrs=GraphData1; 
              %end;
              %else %do;
                barchartparm y=CumLift     x=_xvar;
                %if &Base %then
                 seriesplot y=BaseCumLift x=_xvar / lineattrs=GraphData2;;
                %if &Best %then
                 seriesplot y=BestCumLift x=_xvar / lineattrs=GraphData3;;
              %end;
              endlayout;

            layout overlay / yaxisopts=(display=(line ticks tickvalues) 
                   griddisplay=&grid);
              %if %upcase(%substr(&graph,1,1))=L %then %do;
                %if &Base %then
                 seriesplot y=BaseLift x=_xvar / lineattrs=GraphData2;;
                %if &Best %then
                 seriesplot y=BestLift x=_xvar / lineattrs=GraphData3;;
                seriesplot y=Lift     x=_xvar / lineattrs=GraphData1; 
              %end;
              %else %do;
                barchartparm y=Lift     x=_xvar;
                %if &Base %then
                 seriesplot y=BaseLift x=_xvar / lineattrs=GraphData2;;
                %if &Best %then
                 seriesplot y=BestLift x=_xvar / lineattrs=GraphData3;;
              %end;
              endlayout;

         *Row 4 - Gain;
            layout overlay / yaxisopts=(display=(line ticks tickvalues) 
                   griddisplay=&grid);
              %if %upcase(%substr(&graph,1,1))=L %then %do;
                %if &Base %then
                 seriesplot y=BaseGain x=_xvar / lineattrs=GraphData2;;
                %if &Best %then
                 seriesplot y=BestGain x=_xvar / lineattrs=GraphData3;;
                seriesplot y=Gain     x=_xvar / lineattrs=GraphData1; 
              %end;
              %else %do;
                barchartparm y=Gain     x=_xvar;
                %if &Base %then
                 seriesplot y=BaseGain x=_xvar / lineattrs=GraphData2;;
                %if &Best %then
                 seriesplot y=BestGain x=_xvar / lineattrs=GraphData3;;
              %end;
              endlayout;
              
              layout overlay;
                discretelegend "Baseline" "Best";
              endlayout;

         endlayout;
      endgraph;
      end;
      run;

   proc template;
      define statgraph GainLiftPlot;
      mvar _title _yvar _xvar _baseline _best;
      begingraph;
         entrytitle _title;
         layout overlay / xaxisopts=(griddisplay=&grid)
                yaxisopts=(display=(line ticks tickvalues) griddisplay=&grid);
           %if %upcase(%substr(&graph,1,1))=L %then %do;
             %if &Base %then
               seriesplot y=_baseline x=_xvar / name="Baseline" legendlabel="Baseline" lineattrs=GraphData2;;
             %if &Best %then
               seriesplot y=_best x=_xvar / name="Best" legendlabel="Best Possible" lineattrs=GraphData3;;
             seriesplot y=_yvar x=_xvar / lineattrs=GraphData1; 
           %end;
           %else %do;
             barchartparm y=_yvar x=_xvar;
             %if &Base %then
               seriesplot y=_baseline x=_xvar / name="Baseline" legendlabel="Baseline" lineattrs=GraphData2;;
             %if &Best %then
               seriesplot y=_best x=_xvar / name="Best" legendlabel="Best Possible" lineattrs=GraphData3;;
           %end;
           discretelegend "Baseline" "Best";
         endlayout;
      endgraph;
      end;
      run;

   /* Panel of plots requested */
   %if %upcase(%substr(&panel,1,1))=Y %then %do;
      proc sgrender data=&out template=GainLiftPanel;
        run;
   %end;

   /* Specific plots requested */
   %else %if &plots ne %then %do;
     %let i=1;
     %do %while (%scan(&plots,&i) ne %str() );
        %let arg&i=%scan(&plots,&i);
        %oneplot(&&arg&i)
       %let i=%eval(&i+1);
     %end;
   %end;

   /* All plots, unpaneled, requested */
   %else %do;
      %oneplot(GA)
      %oneplot(CL)
      %oneplot(LI)
      %oneplot(CC)
      %oneplot(PC)
      %oneplot(CR)
      %oneplot(PR)
   %end;

   %exit:
   options &_opts;
   %let time = %sysfunc(round(%sysevalf(%sysfunc(datetime()) - &time), 0.01));
   %put NOTE: The GainLift macro used &time seconds.;
  %mend GainLift;
