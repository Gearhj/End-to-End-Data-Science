
********************************************************;
*Establish connection and import data                   ;
********************************************************;

LIBNAME MYDATA BASE "C:/Users/James Gearheart/Desktop/SAS Book Stuff/Data";

FILENAME REFFILE 'C:\Users\James Gearheart\Desktop\SAS Book Stuff\Data\listings_clean.csv';

PROC IMPORT DATAFILE=REFFILE
	DBMS=CSV
	OUT= MYDATA.Listings;
	GETNAMES=YES;
RUN;



/*Example work libraries*/
DATA WORK.TEST;
  SET MYDATA.Listings;
RUN;

DATA TEST;
  SET MYDATA.LISTINGS;
RUN;

DATA MYLIB.DEMOGRAPHICS;
  SET ORG.DEMOGRAPHICS;
RUN;




/*Example connection to Teradata environment*/

%INCLUDE '~/pw/userinfo.sas';
LIBNAME MY_TERA TERADATA USER='&sysuserid' PASSWORD='&pw'
	SERVER="TERADATA_SERVER" SCHEMA=SPECIFIC_AREA
;

PROC SQL;
	CONNECT TO TERADATA(USER='&sysuserid' PASSWORD='&pw'
		SERVER="TERADATA_SERVER" SCHEMA=SPECIFIC_AREA MODE=TERADATA);
	CREATE TABLE MYLIB.WEBLOGS AS SELECT * FROM CONNECTION TO TERADATA
		(SELECT a.*
			FROM SPECIFIC_AREA.TABLE_NAME AS a
				WHERE date >= '2017-12-01'
		);
QUIT;


/*Exploring data files*/

PROC CONTENTS DATA=MYDATA.Listings; RUN;

PROC FREQ DATA=MYDATA.LISTINGS;
	TABLES neighbourhood_group_cleansed;
RUN;

PROC FREQ DATA=MYDATA.LISTINGS ORDER=FREQ;
	TABLES neighbourhood_group_cleansed;
RUN;

PROC FREQ DATA=MYDATA.LISTINGS ORDER=FREQ;
	TABLES neighbourhood_group_cleansed * room_type /
	NOCOL NOROW NOPERCENT OUT=room_freq;
RUN;

PROC UNIVARIATE DATA=MYDATA.LISTINGS;
  VAR Price;
  HISTOGRAM;
RUN;

PROC MEANS DATA=MYDATA.LISTINGS;
  VAR price accommodates bathrooms;
RUN;

PROC MEANS DATA=MYDATA.LISTINGS N NMISS MIN MAX MEAN MEDIAN STDDEV;
  CLASS room_type;
  VAR price accommodates bathrooms;
  OUTPUT OUT=list_stats;
RUN;

PROC SUMMARY DATA=MYDATA.LISTINGS;
  VAR price accommodates bathrooms;
  OUTPUT OUT=list_sum;
RUN;

PROC SORT DATA=MYDATA.LISTINGS OUT=list_sort;
  BY host_id;
RUN;

PROC SUMMARY DATA=list_sort;
  BY host_id;
  VAR price accomodates bathrooms;
  OUTPUT OUT=list_sum SUM=;
RUN;

DATA WORK.TEST;
  SET MYDATA.LISTINGS;
  WHERE accommodates le 4;
RUN;

DATA WORK.TEST;
  SET MYDATA.LISTINGS;
  IF accommodates le 4;
RUN;



/*Split data into TRAIN and TEST datasets at an 80/20 split*/
PROC SURVEYSELECT DATA=MYDATA.Listings SAMPRATE=0.20 SEED=42
	OUT=Full OUTALL METHOD=SRS;
RUN;

DATA TRAIN TEST;
    SET Full;
	IF Selected=0 THEN OUTPUT TRAIN; ELSE OUTPUT TEST;
	DROP Selected;
RUN;


FILENAME REFFILE2 'C:\Users\James Gearheart\Desktop\SAS Book Stuff\Data\calendar.csv';

PROC IMPORT DATAFILE=REFFILE2
	DBMS=CSV
	OUT= MYDATA.Calendar;
	GETNAMES=YES;
RUN;