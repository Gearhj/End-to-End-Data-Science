%ICEPlot( ICEVar=horsepower, samples=10, YHatVar=p_MSRP );


%macro ICEPlot(
			ICEVar=, 
			samples=10, 
			YHatVar=
			);
	/*Select a small number of individuals at random*/
	proc summary data = replicates;
		class obsID;
		output out=individuals (where=(_type_ = 1));
	run;

	data individuals;
		set individuals;
		random = ranuni(12345);
	run;

	proc sort data = individuals;
		by random;
	run;

	data sampledIndividuals;
		set individuals;

		if _N_ LE &samples.;
	run;

	proc sort data = sampledIndividuals;
		by obsID;
	run;

	proc sort data = replicates;
		by obsID;
	run;

	data ICEReplicates;
		merge replicates sampledIndividuals (in = s);
		by obsID;

		if s;
	run;

	/*Plot the ICE curves for the sampled individuals*/
	title "ICE Plot (&samples. Samples)";

	proc sgplot data = ICEReplicates;
		series x=&ICEVar. y = &yHatVar. / group=obsID;
	run;

%mend ICEPlot;

