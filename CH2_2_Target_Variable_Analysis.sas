
/* Explore the target variable */
PROC UNIVARIATE DATA=TRAIN; VAR Price; HISTOGRAM ; RUN;


/* Eliminate outliers and create log transformed price variable */
DATA Price;
	SET TRAIN;
	WHERE 30 le Price le 750;
	Price_Log = LOG(Price);
RUN;


PROC UNIVARIATE DATA=WORK.Price; 
	VAR Price; 
	HISTOGRAM; 
RUN;

PROC UNIVARIATE DATA=WORK.Price; VAR Price_Log; HISTOGRAM; RUN;


PROC MEANS DATA=Price (KEEP = _NUMERIC_) N NMISS MIN MAX MEAN MEDIAN STD; RUN;

/* Analyze the relationship between neighbourhood and zipcode variables */

PROC FREQ NOPRINT DATA=Price; TABLES neighbourhood_cleansed*zipcode / MISSING NOCOL NOROW NOPERCENT OUT=zip_freq; run;
PROC SORT DATA=zip_freq; BY neighbourhood_cleansed descending Count; RUN;
PROC SORT NODUPKEY DATA= zip_freq OUT=zip_out; by neighbourhood_cleansed; run;


PROC SQL;
    CREATE TABLE Zip AS
    SELECT a.*,
           b.zipcode AS new_zip
    FROM Price AS a
    LEFT JOIN zip_out AS b
        ON a.neighbourhood_cleansed = b.neighbourhood_cleansed
            WHERE a.neighbourhood_cleansed ne '';
RUN;

DATA Chk;
    SET zip;
    WHERE zipcode = . and new_zip = .;
RUN;

PROC FREQ DATA=Zip ORDER=FREQ; TABLES host_listings_count; RUN;
PROC MEANS DATA=Zip;
	CLASS host_listings_count;
	VAR Price;
RUN;

PROC UNIVARIATE DATA=zip; VAR beds bedrooms bathrooms; histogram; run;
PROC UNIVARIATE DATA=zip; VAR availability_30; histogram; run;

DATA Clean;
	LENGTH zip $5.;
    SET Zip;
    IF zipcode = . then zipcode = new_zip;
    IF neighbourhood_cleansed = 'Civic Center' and zipcode = . THEN zipcode = 10038;
    IF neighbourhood_cleansed = 'Westerleigh' and zipcode = . THEN zipcode = 10314; 
    zip = put(zipcode, $5.); /*Convert zipcode to character variable*/

    IF security_deposit = . THEN security_deposit = 0;
    IF cleaning_fee = . THEN cleaning_fee = 0;

    IF bathrooms = . THEN bathrooms = 1;
    IF bathrooms ge 4 then bathrooms = 4;
    IF bedrooms = . THEN bedrooms = 1;
    IF bedrooms ge 5 then bedrooms = 5;
    IF beds = . THEN beds = 1;
    IF beds ge 5 THEN beds = 5;

    IF host_listings_count = . THEN host_listings_count = 1;
    IF host_listings_count le 1 then host_count_cat = 'Level 1'; else 
    IF 2 le host_listings_count le 10 then host_count_cat = 'Level 2'; else
    IF host_listings_count gt 10 then host_count_cat = 'Level 3';

    IF maximum_nights gt 1125 then maximum_nights =1125;
    IF minimum_nights gt 31 then minimum_nights = 31;
  
	IF availability_30 = . then availability_30 = 0;
	IF availability_60 = . then availability_60 = 0;
	IF availability_90 = . then availability_90 = 0;	
	IF availability_365 = . then availability_365 = 0;

	/* 	Feature Engineering */
	IF beds not in (., 0) then beds_per_accom = accommodates / beds; else beds_per_accom = 0;
	IF bathrooms not in (., 0) then bath_per_accom = accommodates / bathrooms; else bath_per_accom = 0;
	
	/* Create polynomials	 */
	poly_accom = accommodates**2;
	poly_bath = bathrooms**2;
	poly_guests = guests_included**2;
	poly_min = minimum_nights**2;
	poly_max = maximum_nights**2;
	poly_avail = availability_30**2;
  
    DROP review_scores_accuracy review_scores_checkin review_scores_cleanliness first_review last_review
		 review_scores_communication review_scores_location review_scores_rating
		 review_scores_value reviews_per_month number_of_reviews calculated_host_listings_count
		 square_feet new_zip zipcode cleaning_fee extra_people host_since monthly_price
		 host_listings_count weekly_price security_deposit;  
RUN;


/* proc univariate data=clean; var maximum_nights minimum_nights; run; */

/* proc univariate data=clean; var bedrooms bathrooms beds; run; */
PROC FREQ DATA=Clean; TABLES host_count_cat; RUN;

PROC MEANS DATA=Clean;
	CLASS host_count_cat;
	VAR Price Price_Log;
RUN;

/* Create global numeric variables */
PROC CONTENTS NOPRINT DATA=Clean (KEEP=_NUMERIC_ DROP=id host_id 
latitude longitude Price Price_Log) OUT=var1 (KEEP=name);
RUN;

PROC SQL NOPRINT;
	SELECT name INTO:varx separated by " " FROM var1;
QUIT;

%PUT &varx;

/* Create correlation analysis */
PROC CORR DATA=Clean;
	VAR &varx.;
RUN;


PROC MEANS DATA=Clean (KEEP = &varx.) N NMISS MIN MAX MEAN MEDIAN STD; RUN;

PROC REG DATA=WORK.CLEAN PLOTS=ALL;
	model Price_Log= &varx / 
	selection=forward VIF COLLIN;
RUN;

PROC REG DATA=WORK.CLEAN PLOTS=ALL;
	model Price_Log= accommodates availability_30 bathrooms 
					 guests_included maximum_nights minimum_nights/ 
		selection=forward VIF COLLIN;
RUN;

/* Create global numeric variables */
PROC CONTENTS NOPRINT DATA=Clean (KEEP=_NUMERIC_ DROP=id host_id latitude 
availability_60 availability_90 availability_365 longitude Price Price_Log) 
OUT=var2 (KEEP=name); RUN;
PROC SQL NOPRINT; SELECT name INTO:numvar separated by " " FROM var2; QUIT;
%PUT &numvar; RUN; 




PROC SGSCATTER DATA=Clean;
    TITLE 'Scatter Plot Matrix';
    MATRIX Price_Log bedrooms bathrooms beds/ START=TOPLEFT ELLIPSE = (ALPHA=0.05 TYPE=PREDICTED) NOLEGEND;
RUN;

PROC SGSCATTER DATA=Clean;
    TITLE 'Scatter Plot Matrix';
    MATRIX Price_Log accommodates guests_included minimum_nights maximum_nights/ 
	START=TOPLEFT ELLIPSE = (ALPHA=0.05 TYPE=PREDICTED) NOLEGEND;
RUN;


PROC SGSCATTER DATA=Clean;
    TITLE 'Scatter Plot Matrix';
    MATRIX Price_Log availability_30 availability_60 availability_90 availability_365/ START=TOPLEFT ELLIPSE = (ALPHA=0.05 TYPE=PREDICTED) NOLEGEND;
RUN;

/* -------------------------------------------------------------------
   Run the standardize procedure
   ------------------------------------------------------------------- */
PROC STANDARD DATA=Clean OUT=Stnd_Clean
	MEAN=0 STD=1 REPLACE;
	VAR accommodates bathrooms bedrooms beds guests_included 
        minimum_nights maximum_nights availability_30 beds_per_accom bath_per_accom 
		poly_accom poly_bath poly_guests poly_min poly_max poly_avail ;
RUN;

PROC SGSCATTER DATA=Stnd_Clean;
    TITLE 'Scatter Plot Matrix';
    MATRIX Price_Log accommodates guests_included minimum_nights maximum_nights/ 
	START=TOPLEFT ELLIPSE = (ALPHA=0.05 TYPE=PREDICTED) NOLEGEND;
RUN;



***********************************;
/* Analyze character variables */
***********************************;

PROC FREQ DATA=Stnd_Clean (KEEP= _CHARACTER_) ORDER=FREQ; RUN;

PROC MEANS DATA=Stnd_Clean;
	CLASS Property_Type;
	VAR Price;
RUN;

PROC MEANS DATA=Stnd_Clean;
	CLASS bed_type;
	VAR Price;
RUN;


DATA TRAIN_ADJ;
	SET Stnd_Clean;

	IF Property_Type in ('Apartment', 'House', 'Townhouse', 'Loft', 
		'Condominium') THEN
		Property_CAT = Property_Type;
	ELSE
		IF Property_Type in ('Houseboat', 'Resort', 'Tent', 'Serviced ap', 
			'Aparthotel', 'Hotel', 'Boat', 'Other', 'Boutique ho') 
		THEN
		Property_CAT = 'Group 1';
	ELSE Property_CAT = 'Group 2';

	IF host_has_profile_pic = ' ' then
		host_has_profile_pic = 'f';

	IF host_identity_verified = ' ' then
		host_identity_verified = 'f';

	IF host_is_superhost = ' ' then
		host_is_superhost = 'f';
	DROP Property_Type is_location_exact calendar_updated host_response_rate 
		host_response_time;
RUN;
                  
                  
/* Create global variables for character variables */
PROC CONTENTS NOPRINT DATA=TRAIN_ADJ (KEEP= _CHARACTER_ ) 
OUT=var1 (KEEP=name); RUN;
PROC SQL NOPRINT; SELECT name INTO:var_char separated by " " FROM var1; QUIT;
%PUT &var_char; RUN;                   
                  
PROC FREQ DATA=TRAIN_ADJ; TABLES &var_char; RUN;                  
                  

*********************************************;
/* Prepare the TEST dataset for modeling */
*********************************************;

/* Analyze the relationship between neighbourhood and zipcode variables */

PROC FREQ NOPRINT DATA=TEST; TABLES neighbourhood_cleansed*zipcode / 
MISSING NOCOL NOROW NOPERCENT OUT=zip_freq; run;
PROC SORT DATA=zip_freq; BY neighbourhood_cleansed descending Count; RUN;
PROC SORT NODUPKEY DATA= zip_freq OUT=zip_out; by neighbourhood_cleansed; run;


PROC SQL;
    CREATE TABLE TEST_Zip AS
    SELECT a.*,
           b.zipcode AS new_zip
    FROM TEST AS a
    LEFT JOIN zip_out AS b
        ON a.neighbourhood_cleansed = b.neighbourhood_cleansed
            WHERE a.neighbourhood_cleansed ne '';
RUN;

/* Make adjustments to the TEST dataset */
DATA TEST_2;
    SET TEST_Zip;
    WHERE 30 le Price le 750;
	Price_Log = LOG(Price);
    IF zipcode = . then zipcode = new_zip;
    IF neighbourhood_cleansed = 'Civic Center' and zipcode = . THEN zipcode = 10038;
    IF neighbourhood_cleansed = 'Westerleigh' and zipcode = . THEN zipcode = 10314;   
    zip = put(zipcode, $5.); /*Convert zipcode to character variable*/
    IF security_deposit = . THEN security_deposit = 0;
    IF cleaning_fee = . THEN cleaning_fee = 0;
    IF bathrooms = . THEN bathrooms = 1;
    IF bathrooms ge 4 then bathrooms = 4;
    IF bedrooms = . THEN bedrooms = 1;
    IF bedrooms ge 5 then bedrooms = 5;
    IF beds = . THEN beds = 1;
    IF beds ge 5 THEN beds = 5;
    IF host_listings_count = . THEN host_listings_count = 1;
    IF host_listings_count le 1 then host_count_cat = 'Level 1'; else 
    IF 2 le host_listings_count le 10 then host_count_cat = 'Level 2'; else
    IF host_listings_count gt 10 then host_count_cat = 'Level 3';
    IF maximum_nights gt 1125 then maximum_nights =1125;
    IF minimum_nights gt 31 then minimum_nights = 31;
    
	IF availability_30 = . then availability_30 = 0;
	IF availability_60 = . then availability_60 = 0;
	IF availability_90 = . then availability_90 = 0;	
	IF availability_365 = . then availability_365 = 0;
	IF number_of_reviews = . then number_of_reviews = 0;
	IF reviews_per_month = . then reviews_per_month = 0;
	    
	/* 	Feature Engineering */
	IF beds not in (., 0) then beds_per_accom = accommodates / beds; else beds_per_accom = 0;
	IF bathrooms not in (., 0) then bath_per_accom = accommodates / bathrooms; else bath_per_accom = 0;
	
	/* Create polynomials	 */
	poly_accom = accommodates**2;
	poly_bath = bathrooms**2;
	poly_guests = guests_included**2;
	poly_min = minimum_nights**2;
	poly_max = maximum_nights**2;
	poly_avail = availability_30**2;


	IF Property_Type in ('Apartment', 'House', 'Townhouse', 'Loft', 'Condominium') 
	   	THEN Property_CAT = Property_Type; ELSE
	IF Property_Type in ('Houseboat', 'Resort', 'Tent', 'Serviced ap', 'Aparthotel', 
	   					 'Hotel', 'Boat', 'Other', 'Boutique ho') 
	   	THEN Property_CAT = 'Group 1'; ELSE Property_CAT = 'Group 2';
 
    IF host_has_profile_pic = ' ' then host_has_profile_pic = 'f';
	IF host_identity_verified = ' ' then host_identity_verified = 'f';
	IF host_is_superhost = ' ' then host_is_superhost = 'f';
 
    DROP review_scores_accuracy review_scores_checkin review_scores_cleanliness
		 review_scores_communication review_scores_location review_scores_rating
		 review_scores_value reviews_per_month number_of_reviews calculated_host_listings_count
		 square_feet new_zip zipcode weekly_price monthly_price first_review last_review;  
RUN;   

PROC STANDARD DATA=TEST_2 OUT=TEST_ADJ
	MEAN=0 STD=1 REPLACE;
	VAR accommodates bathrooms bedrooms beds guests_included 
        minimum_nights maximum_nights availability_30 beds_per_accom bath_per_accom 
		poly_accom poly_bath poly_guests poly_min poly_max poly_avail ;
RUN;

proc means data=test_adj; run;               
                                   
proc freq data = train_adj (keep = _CHARACTER_ drop=city zip neighbourhood_cleansed); run;    

/* Create binary indicators for category levels */
data train_final; 
	set train_adj;
	IF neighbourhood_group_cleansed = 'Bronx' then n_bronx = 1; else n_bronx = 0; 
	IF neighbourhood_group_cleansed = 'Brooklyn' then n_brooklyn = 1; else n_brooklyn = 0; 	
	IF neighbourhood_group_cleansed = 'Manhattan' then n_manhattan = 1; else n_manhattan = 0; 	
	IF neighbourhood_group_cleansed = 'Queens' then n_queens = 1; else n_queens = 0; 		
	IF neighbourhood_group_cleansed = 'Staten Is' then n_staten = 1; else n_staten = 0;
	
	IF room_type = 'Entire home/apt' then r_entire = 1; else r_entire = 0; 
	IF room_type = 'Private room' then r_private = 1; else r_private = 0; 	
	IF room_type = 'Shared room' then r_shared = 1; else r_shared = 0; 
	
	IF host_is_superhost = 't' then h_super = 1; else h_super = 0;
	IF host_has_profile_pic = 't' then h_profile = 1; else h_profile = 0;
	IF host_identity_verified = 't' then h_verified = 1; else h_verified = 0;
	
	IF bed_type = 'Airbed' then b_air = 1; else b_air = 0; 
	IF bed_type = 'Couch' then b_couch = 1; else b_couch = 0; 
	IF bed_type = 'Futon' then b_futon = 1; else b_futon = 0; 
	IF bed_type = 'Pull-out Sofa' then b_pullout = 1; else b_pullout = 0;
	IF bed_type = 'Real Bed' then b_real = 1; else b_real = 0;
	
	IF instant_bookable = 't' then instant = 1; else instant = 0;
	IF require_guest_profile_picture = 't' then require_pic = 1; else require_pic = 0;
	IF require_guest_phone_verification = 't' then require_phone = 1; else require_phone = 0;
	
	IF host_count_cat = 'Level 1' then hcount_level1 = 1; else hcount_level1 = 0; 
	IF host_count_cat = 'Level 2' then hcount_level2 = 1; else hcount_level2 = 0; 
	IF host_count_cat = 'Level 3' then hcount_level3 = 1; else hcount_level3 = 0;	
	
	IF Property_CAT = 'Apartment' then p_apart = 1; else p_apart = 0; 
	IF Property_CAT = 'Condominium' then p_condo = 1; else p_condo = 0; 
	IF Property_CAT = 'Group 1' then p_group1 = 1; else p_group1 = 0; 
	IF Property_CAT = 'Group 2' then p_group2 = 1; else p_group2 = 0; 
	IF Property_CAT = 'House' then p_house = 1; else p_house = 0; 
	IF Property_CAT = 'Loft' then p_loft = 1; else p_loft = 0; 	
	IF Property_CAT = 'Townhouse' then p_townhouse = 1; else p_townhouse = 0; 
	
	DROP Property_CAT host_count_cat require_guest_phone_verification require_guest_profile_picture
		 instant_bookable bed_type host_identity_verified host_has_profile_pic host_is_superhost
		 room_type neighbourhood_group_cleansed host_listings_count latitude longitude ;

RUN;	

data test_final; 
	set test_adj;
	IF neighbourhood_group_cleansed = 'Bronx' then n_bronx = 1; else n_bronx = 0; 
	IF neighbourhood_group_cleansed = 'Brooklyn' then n_brooklyn = 1; else n_brooklyn = 0; 	
	IF neighbourhood_group_cleansed = 'Manhattan' then n_manhattan = 1; else n_manhattan = 0; 	
	IF neighbourhood_group_cleansed = 'Queens' then n_queens = 1; else n_queens = 0; 		
	IF neighbourhood_group_cleansed = 'Staten Is' then n_staten = 1; else n_staten = 0;
	
	IF room_type = 'Entire home/apt' then r_entire = 1; else r_entire = 0; 
	IF room_type = 'Private room' then r_private = 1; else r_private = 0; 	
	IF room_type = 'Shared room' then r_shared = 1; else r_shared = 0; 
	
	IF host_is_superhost = 't' then h_super = 1; else h_super = 0;
	IF host_has_profile_pic = 't' then h_profile = 1; else h_profile = 0;
	IF host_identity_verified = 't' then h_verified = 1; else h_verified = 0;
	
	IF bed_type = 'Airbed' then b_air = 1; else b_air = 0; 
	IF bed_type = 'Couch' then b_couch = 1; else b_couch = 0; 
	IF bed_type = 'Futon' then b_futon = 1; else b_futon = 0; 
	IF bed_type = 'Pull-out Sofa' then b_pullout = 1; else b_pullout = 0;
	IF bed_type = 'Real Bed' then b_real = 1; else b_real = 0;
	
	IF instant_bookable = 't' then instant = 1; else instant = 0;
	IF require_guest_profile_picture = 't' then require_pic = 1; else require_pic = 0;
	IF require_guest_phone_verification = 't' then require_phone = 1; else require_phone = 0;
	
	IF host_count_cat = 'Level 1' then hcount_level1 = 1; else hcount_level1 = 0; 
	IF host_count_cat = 'Level 2' then hcount_level2 = 1; else hcount_level2 = 0; 
	IF host_count_cat = 'Level 3' then hcount_level3 = 1; else hcount_level3 = 0;	
	
	IF Property_CAT = 'Apartment' then p_apart = 1; else p_apart = 0; 
	IF Property_CAT = 'Condominium' then p_condo = 1; else p_condo = 0; 
	IF Property_CAT = 'Group 1' then p_group1 = 1; else p_group1 = 0; 
	IF Property_CAT = 'Group 2' then p_group2 = 1; else p_group2 = 0; 
	IF Property_CAT = 'House' then p_house = 1; else p_house = 0; 
	IF Property_CAT = 'Loft' then p_loft = 1; else p_loft = 0; 	
	IF Property_CAT = 'Townhouse' then p_townhouse = 1; else p_townhouse = 0; 	
	
	DROP Property_CAT host_count_cat require_guest_phone_verification require_guest_profile_picture
		 instant_bookable bed_type host_identity_verified host_has_profile_pic host_is_superhost
		 room_type neighbourhood_group_cleansed
		 host_listings_count latitude longitude ;

RUN;	

/* proc contents data= train_final; run; */

proc means data=train_final;run;
proc means data=test_final;run;

******************************************************;
*Simple averages;
******************************************************;

/*Create global average price*/
PROC MEANS DATA=TRAIN_ADJ;
	VAR PRICE;
RUN;

/*Create neighbourhood group avg price*/
PROC SORT DATA=TRAIN_ADJ; BY neighbourhood_group_cleansed; RUN;
PROC MEANS DATA=TRAIN_ADJ;
	VAR PRICE;
	BY neighbourhood_group_cleansed;
RUN;

/*Create neighbourhood avg price*/
PROC SORT DATA=TRAIN_ADJ; BY neighbourhood_cleansed; RUN;
PROC MEANS DATA=TRAIN_ADJ;
	VAR PRICE;
	BY neighbourhood_cleansed;
	OUTPUT OUT=neigh;
RUN;

DATA neigh; SET neigh; WHERE _STAT_ = 'MEAN'; neigh_avg_price = price;
DROP price _FREQ_ _TYPE_ _STAT_; RUN;

PROC SQL;
    CREATE TABLE AVG AS
	SELECT *
	FROM TRAIN_ADJ AS a 
	LEFT JOIN neigh AS b 
	   ON a.neighbourhood_cleansed = b.neighbourhood_cleansed
	       WHERE a.neighbourhood_cleansed IS NOT NULL;
QUIT;


DATA AVG;
  SET AVG;

/*Create global avg price as baseline*/
    base_avg = (price - 139.26);

/*Create neighbourhood_group price as second baseline*/
	IF neighbourhood_group_cleansed = 'Bronx    ' then neigh_price = 84.93 ; else
	IF neighbourhood_group_cleansed = 'Brooklyn ' then neigh_price = 115.82 ; else
	IF neighbourhood_group_cleansed = 'Manhattan' then neigh_price = 173.52 ; else
	IF neighbourhood_group_cleansed = 'Queens   ' then neigh_price = 94.18 ; else
	IF neighbourhood_group_cleansed = 'Staten Is' then neigh_price = 92.72 ; else

	neigh_group_avg = (price - neigh_price)**2;

	neigh_avg = (price - neigh_avg_price)**2;
RUN;

PROC SUMMARY DATA=AVG;
    VAR base_avg neigh_group_avg neigh_avg_price;
	OUTPUT OUT=sum_out SUM=;
RUN;

