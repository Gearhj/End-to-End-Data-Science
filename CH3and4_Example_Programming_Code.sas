
/*ODS Graphics Map*/
ODS GRAPHICS / RESET WIDTH=6.4in HEIGHT=4.8in;

PROC SMAP plotdata=WORK.Listings;
	openstreetmap;
	scatter x=longitude y=latitude / markerattrs=(size=3 symbol=circle);
RUN;

ODS GRAPHICS / RESET;

/*Neighborhood Group Map View*/
ODS GRAPHICS / RESET WIDTH=6.4in HEIGHT=4.8in;

PROC SMAP plotdata=WORK.Listings;
	openstreetmap;
	scatter x=longitude y=latitude / group=neighbourhood_group_cleansed
		name="scatterPlot" markerattrs=(size=3 symbol=circle);
	keylegend "scatterPlot" / title='neighbourhood_group_cleansed';
RUN;

ODS GRAPHICS / RESET;




/*Example WORK datasets*/
DATA WORK.TEST;
	SET MYDATA.Listings;
RUN;

DATA TEST;
	SET MYDATA.LISTINGS;
RUN;


/*Example data exploration*/

PROC UNIVARIATE DATA=MYDATA.Listings;
	VAR price;
	HISTOGRAM;
RUN;

PROC MEANS DATA=MYDATA.Listings N NMISS MIN MAX MEAN MEDIAN STDDEV;
	CLASS room_type;
	VAR price accommodates bathrooms;
	OUTPUT OUT= list_stats;
RUN;

/*Example data manipulation*/

DATA WORK.TEST;
  SET MYDATA.LISTINGS;

  /*Specify length of new character variable*/
  LENGTH bath_count $8.;

  /*Limit the data imported into memory with a 
  symbol operand*/
  WHERE accommodates ^= 0;

  /*IF-THEN statement with mnemonic operand*/
  IF bathrooms EQ 1 THEN bath_count = 'Single';
  ELSE bath_count = 'Multiple';

  /*Calculation with arithmetic operand*/
  poly_bath = bathrooms**2;

  /*IF-THEN with logical condition*/
  IF (accommodates >= 5 AND bathrooms GE 2) 
  THEN big_house = 1; ELSE big_house = 0;
RUN;


/*Example feature engineering*/

DATA dates;
	set MYDATA.Listings;

	WHERE first_review BETWEEN '01JAN2018'd AND '30APR2018'd;

	date_fmt1 = first_review;
	date_fmt2 = first_review;
	date_fmt3 = first_review;
	day   = day  (first_review);
	week  = week (first_review);
	month = month(first_review);
	year  = year (first_review);

	btw_dates = DATDIF(first_review, last_review, 'ACT/ACT');

	KEEP date_fmt1 date_fmt2 date_fmt3 first_review last_review 
		 day week month year btw_dates;
	FORMAT date_fmt1 DATE. date_fmt2 DATE9. date_fmt3 WEEKDATE.;
RUN;



/*Example SQL code*/

PROC SQL;
	CREATE TABLE MYDATA.Combine AS     
	SELECT  a.host_id,                 
			a.room_type,               
			a.price AS base_price,     
			b.price AS calendar_price, 
			CASE                       
				WHEN a.price GE 150 THEN 'Expensive'
				ELSE 'Cheap'           
				END 
				AS price_cat,          

			b.date AS calendar_date    

		FROM MYDATA.Listings AS a      
		LEFT JOIN MYDATA.Calendar AS b 
			ON a.listing_id = b.listing_id 
				WHERE a.host_id IS NOT NULL
				AND a.bedrooms GT 1        
				AND b.date BETWEEN '01JAN2019'd AND '30JAN2019'd;
QUIT;

/*Example SAS match merge*/

PROC SORT DATA=MYDATA.LISTINGS;
  BY listing_id; 
RUN;

PROC SORT DATA=MYDATA.CALENDAR;
  BY listing_id;
RUN;

DATA Left Right Left_Outer Inner;
  MERGE MYDATA.LISTINGS (IN=a) MYDATA.CALENDAR (IN=b);
  BY listing_id;

  IF a THEN OUTPUT left;
  IF b THEN OUTPUT Right;
  IF a AND NOT b THEN OUTPUT Left_Outer;
  IF a AND b THEN OUTPUT Inner;

RUN;

/*Example unduplicated sort*/

PROC SORT NODUPKEY DATA=MYDATA.LISTINGS OUT=list_sort;
  BY DESCENDING listing_id;
RUN;


/*Example file export*/

PROC EXPORT DATA=MYDATA.list_sort
	OUTFILE="C:\Users\James Gearheart\Data\list.xls"
	DBMS=EXCEL REPLACE;
	SHEET="list";;
RUN;


/*Example macro export dataset to csv*/
%ds2csv(DATA=MYDATA.Listings, runmode=b, 
csvfile="C:\Users\James Gearheart\Data\listings.csv");


/*Example report*/

PROC REPORT DATA=MYDATA.LISTINGS ;
  title 'Summarized AirBnB Report';
  COLUMN bed_type room_type price;
  DEFINE bed_type / GROUP 'Bed Type';
  DEFINE room_type / GROUP ORDER=FREQ DESCENDING'Room Type';
  DEFINE price / MEAN FORMAT=DOLLAR10.2 'Average Price';
RUN;


/*Example plots*/

PROC SGPLOT DATA=WORK.TRAIN_ADJ;
  HISTOGRAM Price_Log / BINWIDTH= 0.25;
  DENSITY Price_Log;
  TITLE 'Distribution of Price';
RUN;


PROC SGPLOT DATA=WORK.TRAIN_ADJ;
  VBAR neighbourhood_group_cleansed / 
  RESPONSE=Price_Log GROUP= room_type STAT=MEAN;
  YAXIS LABEL='Mean Log Price';
  XAXIS LABEL='Neighbourhood Group';
  TITLE 'Mean Log Price of Room Type by Neighbourhood Group';
RUN;


DATA CAL; 
  SET MYDATA.Calendar;
  WHERE Listing_id in (21456, 2539, 5178);
  IF listing_id = 21456 THEN price_1 = price;
  IF listing_id = 2539 THEN price_2 = price;
  IF listing_id = 5178 THEN price_3 = price;
run;

PROC SORT DATA=CAL; BY listing_id date; run;

PROC SGPLOT DATA=CAL ;
  SERIES X=date Y=price_1 / LEGENDLABEL='Listing 21456';
  SERIES X=date Y=price_2 / LEGENDLABEL='Listing 2539';
  SERIES X=date Y=price_3 / LEGENDLABEL='Listing 5178';
  YAXIS LABEL= 'Daily Price';
  XAXIS LABEL= 'Date';
  TITLE 'Price Per Night';
RUN;


PROC MEANS DATA=MYDATA.LISTINGS;
VAR price;
CLASS review_scores_rating;
OUTPUT OUT= AVG; 
RUN;

PROC SGPLOT DATA=AVG (WHERE=(_STAT_='MEAN' and _FREQ_ GE 20));
  SCATTER X = review_scores_rating Y = price;
  YAXIS LABEL= 'Average Price';
  XAXIS LABEL= 'Review Score';
  TITLE 'Average Price by Review Score';
RUN; 


/*Example SQL code*/

PROC SQL;
	CONNECT TO teradata(user="user_id" pass="password" tdpid="environment" 
		database=specific_database mode=teradata);
	CREATE TABLE MYDATA.Tera_table AS SELECT * FROM connection to teradata
		(SELECT a.ID,
			b.*
		FROM Libname.TableName AS a
			LEFT JOIN Libname.OtherTableName AS b
				ON a.ID = b.ID
			WHERE a.ID IS NOT NULL
		);
QUIT;

PROC FREQ DATA=MYDATA.Listings ORDER=FREQ;
	TABLES neighbourhood_group_cleansed;
RUN;

PROC UNIVARIATE DATA=MYDATA.Listings;
	VAR Price;
	HISTOGRAM;
RUN;


/*Example DO loops*/

DATA X;
	DO i = 1 to 10;
		y = i*2;
		OUTPUT;
	END;
RUN;

DATA X;
	DO i = 1 to 10 BY 2 WHILE y < 15;
		y = i*2;
		OUTPUT;
	END;
RUN;

/*Example ARRAY statements*/

DATA convert;
	SET boxers;
	ARRAY weight_array {100} weight1-weight100;

	DO i = 1 TO 100;
		weight_array{i} = weight_array{i} * 0.45;
	END;
RUN;


DATA convert;
	SET boxers;
	ARRAY weight_array {100} weight1-weight100;
	ARRAY kilo_array {100} kilo_weight1-kilo_weight100;

	DO i = 1 TO 100;
		kilo_array{i} = weight_array{i} * 0.45;
	END;
RUN;


/*Example SCAN statements*/
DATA names;
  SET dataset;
  first_name = SCAN(customer_name, 2);
  last_name = SCAN(customer_name, 1);
RUN;


/*Example FIND statements*/
DATA chk;
	pos_1 = FIND ("Data Science","nce");
	pos_2 = FIND ("Data Science","sci");
	pos_3 = FIND ("Data Science","sci","i");
	pos_4 = FIND ("Data Science","ata",42);
RUN;

PROC PRINT DATA = chk; 
RUN;

/*Example convert character to numeric*/
DATA temp;
  SET dataset;
  id_char = PUT(id_num, $8.);
RUN;


/*Example FIRST. and LAST. statements*/
PROC SORT DATA=MYDATA.LISTINGS;
  BY room_type;
RUN;

DATA count;
  SET MYDATA.LISTINGS;
  BY room_type;

  IF FIRST.room_type THEN
      count = 0;
  count + 1;

  IF LAST.room_type;
RUN;

PROC PRINT DATA=count NOOBS;
  FORMAT count comma10.;
  VAR room_type count;
RUN;

/*Example MACRO variable*/
%LET date = '01MAY2019'd;

DATA POP;
  SET DATASET;
  IF start_date = &date.;
RUN;

/*Example REPORT footnote*/

PROC REPORT DATA=MYDATA.LISTINGS ;
  title 'Summarized AirBnB Report';
  COLUMN bed_type room_type price;
  DEFINE bed_type / GROUP 'Bed Type';
  DEFINE room_type / GROUP ORDER=FREQ DESCENDING'Room Type';
  DEFINE price / MEAN FORMAT=DOLLAR10.2 'Average Price';
  FOOTNOTE "Report for &sysday., &sysdate9.";
RUN;

%PUT FOOTNOTE "Report for &sysday., &sysdate9.";


/*Example MACRO*/

%let OHpop=25;
%let state = OH;
&&&state.pop

%MACRO POWER(x,y);
	%LET result = %EVAL(&x.**&y.);
	%PUT &x. raised to the power &y. is &result.;
%MEND;

%POWER(8,2);


%MACRO <macro_name>;
    programming code;
%MEND;

%<macro_name>;