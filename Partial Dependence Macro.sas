
PROC HPNEURAL DATA=MYDATA.BANK_TRAIN;
   ARCHITECTURE MLP;
   INPUT age pdays pout_succ contact_tele pout_non contact_cell previous;
   TARGET target / LEVEL=nom;
   HIDDEN 10;
   HIDDEN 5;
   TRAIN;
   SCORE OUT=scored_NN;
   CODE FILE= 'C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data/NN_Model.sas';
run;

%PDFunction( dataset=mydata.bank_train, target=target, PDVars=age, 
otherIntervalInputs= pdays pout_succ contact_tele pout_non contact_cell previous, 
otherClassInputs=, 
scorecodeFile='C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data/NN_Model.sas', outPD=partialDependence );

proc sgplot data=partialDependence;
	series x = age y = AvgYHat;
run;


proc hpsplit data=MYDATA.BANK_TRAIN leafsize = 10;
	target target / level = interval;
	input age pdays pout_succ contact_tele pout_non contact_cell previous / level = int;
/*	input make driveTrain type / level = nominal;*/
	code file='C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data/treecode.sas';
run;

%PDFunction( dataset=MYDATA.BANK_TRAIN, target=target, PDVars=age, 
otherIntervalInputs=pdays pout_succ contact_tele pout_non contact_cell previous, 
otherClassInputs=, 
scorecodeFile='C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data/treecode.sas', outPD=partialDependence );


proc sgplot data=partialDependence;
	series x = age y = AvgYHat;
run;



/*Categorical bar charts*/
%PDFunction(dataset=sashelp.cars, target=MSRP, PDVars=make, 
otherIntervalInputs=horsepower engineSize length cylinders weight MPG_highway MPG_city wheelbase, 
otherClassInputs=origin driveTrain type, 
scorecodeFile='C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data/treecode.sas', outPD=partialDependence
);
proc sgplot data=partialDependence;
	vbar make / response = AvgYHat categoryorder = respdesc;
run;

quit;


/*Two variable PD plot*/
%PDFunction(dataset=sashelp.cars, target=MSRP, PDVars=horsepower origin, 
otherIntervalInputs=engineSize length cylinders weight MPG_highway MPG_city wheelbase, 
otherClassInputs=make driveTrain type, 
scorecodeFile='C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data/treecode.sas', outPD=partialDependence
);
proc sgplot data=partialDependence;
	series x = horsepower y = AvgYHat / group = origin;
run;

quit;


/*Scatter plot*/
%PDFunction(dataset=sashelp.cars, target=MSRP, PDVars= horsepower MPG_City, 
otherIntervalInputs= engineSize cylinders MPG_highway wheelbase length weight, 
otherClassInputs= make origin type driveTrain, 
scorecodeFile='C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data/treecode.sas', outPD=partialDependence
);
proc sgplot data=partialDependence;
	scatter x = horsepower y = MPG_City / colorresponse = avgYHat colormodel=(blue green orange red) markerattrs=(symbol=CircleFilled size=10);
run;

quit;






%macro PDfunction(
			dataset=,
			target=,
			PDVars= ,
			otherIntervalInputs= ,
			otherClassInputs=,
			scoreCodeFile=,
			outPD=
			);
	%let PDVar1 = %sysfunc(scan(&PDVars,1));
	%let PDVar2 = %sysfunc(scan(&PDVars,2));
	%let numPDVars = 1;

	%if &PDVar2 ne %str() %then
		%let numPDVars = 2;

	/*Obtain the unique values of the PD variable */
	proc summary data = &dataset.;
		class &PDVar1. &PDVar2.;
		output out=uniqueXs
		%if &numPDVars = 1 %then

			%do;
				(where=(_type_ = 1))
			%end;

		%if &numPDVars = 2 %then
			%do;
				(where=(_type_ = 3))
			%end;
		;
	run;

	/*Create data set of complementary Xs */
	data complementaryXs;
		set &dataset(keep= &otherIntervalInputs. &otherClassInputs.);
		obsID = _n_;
	run;

	/*For every observation in uniqueXs, read in each observation
	from complementaryXs */
	data replicates;
		set uniqueXs (drop=_type_ _freq_);

		do i=1 to n;
			set complementaryXs point=i nobs=n;

			%include "&scoreCodeFile.";
			output;
		end;
	run;

	/*Compute average yHat by replicate*/
	proc summary data = replicates;
		class &PDVar1. &PDVar2.;
		output out=&outPD.
		%if &numPDVars = 1 %then

			%do;
				(where=(_type_ = 1))
			%end;

		%if &numPDVars = 2 %then
			%do;
				(where=(_type_ = 3))
			%end;

		mean(p_&target.) = AvgYHat;
	run;

%mend PDFunction;
