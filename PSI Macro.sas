

*** Part I: Define Data Set and Variables ****;
%let inputset= modeling_sample; /* The modeling sample */
%let compareset=validation_sample; /* The validation sample */
%let varnum=num1 num2 num3 num4 num5 num6; /* list of numeric variables */
%let binnum=10; /* number of bins for numeric variables */
%let vartxt=char1 char2 char3 char4; /* list of character variables */
%let imtxt=____; /* label for missing character values */
%let missnum=-999999999; /* label for missing character values */
%let yaxislabel=% Accounts; /* label for distribution */
%let labelmod=Modeling Sample; /* label for modeling sample */
%let labeloot=Validation Sample; /* label for validation sample */

********* Part II: Numeric Variables *********;
%macro dealnum;
	%if %sysfunc(countw(&varnum dummyfill)) > 0 %then
		%do;

			data check_contents;
				retain &varnum;
				set &inputset(keep=&varnum obs=1);
			run;

			proc contents data=check_contents varnum out=check_contents2 noprint;
			run;

			proc sort data=check_contents2(keep=name varnum)
				out=checkfreq(rename=(name=tablevar));
				by varnum;
			run;

			data varcnt;
				set checkfreq;
				varcnt+1;
			run;

			proc sql noprint;
				select tablevar into :varmore separated by ' ' from varcnt;
			quit;

			proc sql;
				create table vcnt as select count(*) as vcnt from varcnt;
			quit;

			data _null_;
				set vcnt;
				call symputx('vmcnt', vcnt);
			run;

			proc sql noprint;
				select tablevar into :v1-:v&vmcnt from varcnt;
			quit;

			proc rank data=&inputset group=&binnum out=check_rank ties=low;
				var &varnum;
				ranks rank1-rank&vmcnt;
			run;

			data check_rank;
				set check_rank;
				array fillmiss(*) rank1-rank&vmcnt;

				do j=1 to dim(fillmiss);
					if fillmiss(j)=. then
						fillmiss(j)=-1;
					fillmiss(j)=fillmiss(j)+1;
				end;

				drop j;
			run;

%macro meannum;
	%do i=1 %to &vmcnt;

		proc means data=check_rank nway min max median noprint;
			class rank&i;
			var &&v&i;
			output out=check&i(drop=_type_ rename=(_freq_=freq_&i))
				min=min_v&i
				max=max_v&i
				median=&&v&i;
		run;

		data check&i;
			set check&i;
			rank_num_&i+1;
		run;

		proc sql noprint;
			select max(rank_num_&i) into :maxrank from check&i;
		quit;

		data check&i;
			length sas_code $ 256.;
			set check&i;

			if rank_num_&i=1 then sas_code="if &&v&i le "||max_v&i||" then
				rank_num_&i=1;";
			else sas_code="else if &&v&i le "||max_v&i||" then
				rank_num_&i="||rank_num_&i||";";

			if rank_num_&i=&maxrank then
				sas_code="else rank_num_&i="||rank_num_&i||";";
			sas_code=compbl(sas_code);
		run;

		proc sort data=check&i;
			by rank_num_&i;
		run;

		proc sql noprint;
			select sas_code into :algnum&i separated by ' ' from check&i;
		quit;

		data check_mod_sample;
			set check_rank;
			&&algnum&i;
		run;

		data check_oot_sample;
			set &compareset;
			&&algnum&i;
		run;

		proc freq data=check_mod_sample noprint;
			tables
				rank_num_&i/out=modeling_freq(rename=(count=count_mod percent=freq_mod));
		run;

		proc freq data=check_oot_sample noprint;
			tables
				rank_num_&i/out=oot_freq(rename=(count=count_oot percent=freq_oot));
		run;

		proc sort data=modeling_freq;
			by rank_num_&i;
		run;

		proc sort data=oot_freq;
			by rank_num_&i;
		run;

		proc sort data=check&i;
			by rank_num_&i;
		run;

		proc sql noprint;
			select count(*) into :totcntoot from check_oot_sample;
		quit;

		proc sql noprint;
			select sum(count_mod) into :totcntmod from modeling_freq;
		quit;

		proc sql noprint;
			select sum(count_oot) into :totcntoot from oot_freq;
		quit;

		proc sql noprint;
			select sum(freq_mod) into :totfreqmod from modeling_freq;
		quit;

		proc sql noprint;
			select sum(freq_oot) into :totfreqoot from oot_freq;
		quit;

		data modeling_oot_freq;
			merge modeling_freq oot_freq check&i(keep=rank_num_&i &&v&i sas_code);
			by rank_num_&i;

			if count_oot=. then
				count_oot=0;

			if freq_oot=. then
				freq_oot=1/&totcntoot;
			freq_mod=freq_mod/100;
			freq_oot=freq_oot/100;

			if freq_mod > freq_oot then
				PSI=(freq_oot-freq_mod)*log(freq_oot/freq_mod);
			else PSI=(freq_mod-freq_oot)*log(freq_mod/freq_oot);
			order_rank=put(rank_num_&i, 5.);
		run;

		proc sql noprint;
			select sum(PSI) into :psi from modeling_oot_freq;
		quit;

		data for_total;
			order_rank="Total";
			PSI=&psi;
			count_mod=&totcntmod;
			count_oot=&totcntoot;
			freq_mod=&totfreqmod/100;
			freq_oot=&totfreqoot/100;
		run;

		data modeling_oot_&i;
			retain order_rank &&v&i count_mod count_oot freq_mod freq_oot PSI;
			set modeling_oot_freq for_total;
			drop rank_num_&i;
			format freq_mod 6.4;
			format freq_oot 6.4;
			informat freq_mod 6.4;
			format freq_oot 6.4;
		run;

		proc print data=modeling_oot_&i(drop=sas_code) noobs;
			title "&&v&i";
		run;

		data modeling_oot_for_graph;
			set modeling_oot_&i;

			if compress(order_rank)='1' and &&v&i=. then
				&&v&i=&missnum;
		run;

		proc sgplot data=modeling_oot_for_graph subpixel noborder;
			vbar &&v&i / response=freq_mod transparency=0.4 FILLATTRS=(color=yellow);
			vbar &&v&i / response=freq_oot transparency=0.4 FILLATTRS=(color=blue) barwidth=0.7;
			keylegend / down=2 location=outside position=top /* noborder */
	title="&&v&i:
			PSI=&psi";
			label freq_mod="&labelmod";
			label freq_oot="&labeloot";
			yaxis label="&yaxislabel";
		run;

	%end;
%mend meannum;

%meannum;
%end;
%mend dealnum;

%dealnum;

******* Part III: Character Variables ********;
%macro dealtxt;
	%if %sysfunc(countw(&vartxt dummyfill)) > 0 %then
		%do;

			data check_contents;
				retain &vartxt;
				set &inputset(keep=&vartxt obs=1);
			run;

			proc contents data=check_contents varnum out=check_contents2 noprint;
			run;

			proc sort data=check_contents2(keep=name varnum)
				out=checkfreq(rename=(name=tablevar));
				by varnum;
			run;

			data varcnt;
				set checkfreq;
				varcnt+1;
			run;

			proc sql noprint;
				select tablevar into :varmore separated by ' ' from varcnt;
			quit;

			proc sql;
				create table vcnt as select count(*) as vcnt from varcnt;
			quit;

			data _null_;
				set vcnt;
				call symputx('vxcnt', vcnt);
			run;

			proc sql noprint;
				select tablevar into :v1-:v&vxcnt from varcnt;
			quit;

			data check_rank;
				length &vartxt $20.;
				set &inputset;
				array fillmiss(*) &vartxt;

				do j=1 to dim(fillmiss);
					if missing(fillmiss(j)) then
						fillmiss(j)="&imtxt";
				end;
			run;

%macro freqmodel;
	%do i=1 %to &vxcnt;

		proc freq data=check_rank noprint;
			tables
				&&v&i/out=modeling_freq(rename=(count=count_mod percent=freq_mod &&v&i=var_label));
		run;

		data check&i;
			set modeling_freq;
			rank_txt_&i+1;
		run;

		proc sql noprint;
			select max(rank_txt_&i) into :maxrank from check&i;
		quit;

		data check&i;
			length sas_code $ 256.;
			set check&i;

			if rank_txt_&i=1 then sas_code="if &&v&i="||strip("'"||var_label||"'")||" then
				rank_txt_&i=1;";
			else sas_code="else if &&v&i="||strip("'"||var_label||"'")||" then
				rank_txt_&i="||rank_txt_&i||";";
		run;

		data fillallothers;
			rank_txt_&i=&maxrank+1;
			var_label="z.allothers";
			sas_code="else do; rank_txt_&i="||rank_txt_&i||"; var_label='z.allothers'; end;";
		run;

		data check&i;
			set check&i fillallothers;
			sas_code=compbl(sas_code);
		run;

		proc sort data=check&i;
			by rank_txt_&i;
		run;

		proc sql noprint;
			select sas_code into :algtxt&i separated by ' ' from check&i;
		quit;

		data check_mod_sample;
			set check_rank;
			&&algtxt&i;
		run;

		data check_oot_sample;
			set &compareset;

			if &&v&i=' ' then
				&&v&i="&imtxt";
			&&algtxt&i;
		run;

		proc freq data=check_mod_sample noprint;
			tables
				rank_txt_&i/out=modeling_freq(rename=(count=count_mod percent=freq_mod));
		run;

		proc freq data=check_oot_sample noprint;
			tables
				rank_txt_&i/out=oot_freq(rename=(count=count_oot percent=freq_oot));
		run;

		proc sort data=modeling_freq;
			by rank_txt_&i;
		run;

		proc sort data=oot_freq;
			by rank_txt_&i;
		run;

		proc sort data=check&i;
			by rank_txt_&i;
		run;

		proc sql noprint;
			select count(*) into :totcntoot from check_oot_sample;
		quit;

		data modeling_oot_freq;
			merge modeling_freq oot_freq check&i(keep=rank_txt_&i var_label sas_code);
			by rank_txt_&i;

			if count_oot=. then
				count_oot=0;

			if freq_oot=. then
				freq_oot=1/&totcntoot;

			if count_mod in (0, .) and count_oot > 0 then
				do;
					count_mod=0;
					freq_mod=1/&totcntoot;
				end;

			freq_mod=freq_mod/100;
			freq_oot=freq_oot/100;

			if freq_mod > freq_oot then
				PSI=(freq_oot-freq_mod)*log(freq_oot/freq_mod);
			else PSI=(freq_mod-freq_oot)*log(freq_mod/freq_oot);
			order_rank=put(rank_txt_&i, 5.);
		run;

		proc sql noprint;
			select sum(PSI) into :psi from modeling_oot_freq;
		quit;

		proc sql noprint;
			select sum(count_mod) into :totcntmod from modeling_oot_freq;
		quit;

		proc sql noprint;
			select sum(count_oot) into :totcntoot from modeling_oot_freq;
		quit;

		proc sql noprint;
			select sum(freq_mod) into :totfreqmod from modeling_oot_freq;
		quit;

		proc sql noprint;
			select sum(freq_oot) into :totfreqoot from modeling_oot_freq;
		quit;

		data for_total;
			order_rank="Total";
			PSI=&psi;
			count_mod=&totcntmod;
			count_oot=&totcntoot;
			freq_mod=&totfreqmod/100;
			freq_oot=&totfreqoot/100;
		run;

		data modeling_oot_char&i;
			retain order_rank var_label count_mod count_oot freq_mod freq_oot PSI;
			set modeling_oot_freq for_total;
			drop rank_txt_&i;
		run;

		data modeling_oot_char;
			set modeling_oot_char&i;

			if order_rank ne 'Total' and count_mod in (0, .) and count_oot in (0, .) then
				delete;
			format freq_mod 6.4;
			format freq_oot 6.4;
			informat freq_mod 6.4;
			format freq_oot 6.4;
		run;

		proc print data=modeling_oot_char(drop=sas_code) noobs;
			title "&&v&i";
		run;

		proc sgplot data=modeling_oot_char subpixel noborder;
			vbar var_label / response=freq_mod transparency=0.4 FILLATTRS=(color=yellow);
			vbar var_label / response=freq_oot transparency=0.4 FILLATTRS=(color=blue)
				barwidth=0.7;
			keylegend / down=2 location=outside position=top /* noborder */
	title="&&v&i:
			PSI=&psi";
			label freq_mod="&labelmod";
			label freq_oot="&labeloot";
			yaxis label="&yaxislabel";
		run;

	%end;
%mend freqmodel;

%freqmodel;
%end;
%mend dealtxt;

%dealtxt;
ods pdf close;