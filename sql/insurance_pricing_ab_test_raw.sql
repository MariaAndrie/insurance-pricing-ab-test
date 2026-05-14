select count(*) from insurance_pricing_ab_test_raw;
rename table insurance_pricing_ab_test_raw to insurance_raw;

select * from insurance_raw
limit 20;
 
-- ===================================================================
-- Data quality checks and cleaning preparation
-- Purpose:
-- Inspect the raw dataset for duplicates, inconsistent categories,
-- missing values, and invalid numeric ranges before creating
-- the final cleaned analysis table.
-- ===================================================================


-- Compare total rows vs distinct users.

select count(*) from insurance_raw;
-- 50500

select count(distinct user_id) as dist from insurance_raw;
-- 50000

-- Inspect raw city values for inconsistent city naming, casing, spacing, and missing values.

select distinct city from insurance_raw;
/*
city
Other
Gothenburg
Stockholm
Gbg
Uppsala
Malmo

malmo 
*/

select city, count(*) as total_rows 
from insurance_raw
group by city;

/*
city		total_rows
Other		10877
Gothenburg	8524
Stockholm	16018
Gbg			2010
Uppsala		4457
Malmo		6597
			504
malmo 		1513
*/

-- Apply TRIM to check whether extra spaces affect city categories.

select trim(city) as city_clean, count(*) as total_rows 
from insurance_raw
group by city_clean;

/*
city_clean	total_rows
Other		10877
Gothenburg	8524
Stockholm	16018
Gbg			2010
Uppsala		4457
Malmo		8110
			504
*/
    
    
-- Standardize city names using LOWER, TRIM, and CASE logic.
    
select count(*) as total_rows,
	case
		when lower(trim(city)) = 'gbg' then 'Gothenburg'
        when lower(trim(city)) = 'Gothenburg' then 'Gothenburg'
        when lower(trim(city)) = 'Stockholm' then 'Stockholm'
        when lower(trim(city)) = 'Uppsala' then 'Uppsala'
        when lower(trim(city)) = 'Malmo' then 'Malmo'	
        when lower(trim(city)) = 'Other' then 'Other'
		else 'Unknown' 
    end as city_clean
from insurance_raw
group by city_clean;

/*
total_rows	city_clean
10877		Other
10534		Gothenburg
16018		Stockholm
4457		Uppsala
8110		Malmo
504			Unknown
*/

-- Identify duplicated users.

select user_id, count(*) as total_rows
from insurance_raw
group by user_id
having count(*)>1;

/*
user_id	total_rows
200		2
293		2
470		2
660		2
726		2
822		2
999		2
1004	2
1031	2
1813	3
6233	3
7754	3
8271	3
11077	3
...
*/

-- Inspect one duplicated user manually.
-- Purpose:
-- Understand how duplicate records differ before choosing
-- a deduplication rule.


select * 
from insurance_raw 
where user_id = 1813;


-- Assign row numbers to duplicate users.
-- Purpose:
-- Keep one record per user by ranking records within each user_id.
-- The record with the highest revenue is kept for analysis. 

select user_id, revenue,
	row_number() over (
		partition by user_id 
		order by revenue desc
    ) as rn
from insurance_raw;

/*
user_id	revenue	rn
1		479		1
2		0		1
3		0		1
4		0		1
5		0		1
6		0		1
...
199		279		1
200		479		1
200		479		2
201		0		1
202		0		1
..
*/

-- Preview the deduplicated result.

select * 
from (
	select user_id, revenue,
		row_number() over (
			partition by user_id 
            order by revenue desc
		) as rn
	from insurance_raw
) as t
where rn=1;


-- Preview raw table structure and sample records.
select * from insurance_raw limit 10;


-- Check numeric ranges for invalid values.
-- Identify unrealistic ages and risk scores before filtering.

select 
	max(age) as max_age, 
	min(age) as min_age,
	min(risk_score) as min_risk,
    max(risk_score) as max_risk,
    min(price) as min_price,
    max(price) as max_price
from insurance_raw;

-- max_age	min_age	min_risk	max_risk	min_price	max_price
-- 125		-30		-0.2		1.2			279			479


-- Review age distribution.
-- Confirm the presence of invalid or unrealistic age values.

select age, count(*) as total_rows
from insurance_raw
group by age
order by age;

/*
age	total_rows
-30	44
17	39
18	943
19	903
20	1008
..
69	933
90	26
95	37
125	58
*/

-- Inspect income level categories.

select income_level, count(*) as total_rows 
from insurance_raw 
group by income_level;

/*
income_level	total_rows
medium			19756
low				19810
high			9937
				997
*/

-- Inspect acquisition channel categories.

select channel, count(*) as total_rows
from insurance_raw 
group by channel;

 /*
channel		total_rows
agent		18951
online		28575
 AGENT 		1145
  AGENT  	24
 ONLINE 	1785
  ONLINE  	20
  
  */
  
-- Inspect test group values.
-- Confirm that the experiment contains only the expected groups.

select test_group, count(*) as total_rows 
from insurance_raw 
group by test_group;

/*
test_group	total_rows
B_premium	25245
A_basic		25255
*/

-- Inspect billing period values.
-- Confirm consistency in billing period categories.

select billing_period, count(*) as total_rows 
from insurance_raw 
group by billing_period;

/*
billing_period	total_rows
monthly			50500
*/

-- Test the cleaning logic before creating the final table.
-- Validate standardization, deduplication, and filtering rules.

with cleaned as (
	select
		user_id, test_group, age,
        case
			when income_level is null or trim(income_level) = '' then 'unknown'
            else lower(trim(income_level))
		end as income_level,
		risk_score, previous_claim,
        lower(trim(channel)) as channel,
        case
			when lower(trim(city)) = 'gbg' then 'Gothenburg'
			when lower(trim(city)) = 'Gothenburg' then 'Gothenburg'
			when lower(trim(city)) = 'Stockholm' then 'Stockholm'
			when lower(trim(city)) = 'Uppsala' then 'Uppsala'
			when lower(trim(city)) = 'Malmo' then 'Malmo'	
			when lower(trim(city)) = 'Other' then 'Other'
			else 'Unknown' 
		end as city,
        price, price_currency, billing_period, converted, revenue,
        row_number() over (partition by user_id order by revenue desc) as rn
	from insurance_raw
)
select * from cleaned
where rn=1
and age between 17 and 95
and risk_score between 0 and 1;


/*
user_id	test_group	age	income_level	risk_score			previous_claim	channel	city		price	price_currency	billing_period	converted	revenue	rn
1		B_premium	57	medium			0.3285759987753159	1				agent	Other		479		SEK				monthly			1			479		1
2		B_premium	45	medium			0.25310531068755965	0				agent	Gothenburg	479		SEK				monthly			0			0		1
3		B_premium	51	low				0.2728086532090246	0				agent	Stockholm	479		SEK				monthly			0			0		1
4		B_premium	35	low				0.3147910973302285	0				agent	Gothenburg	479		SEK				monthly			0			0		1
5		A_basic		39	low				0.07466547448788748	0				online	Gothenburg	279		SEK				monthly			0			0		1
6		B_premium	37	high			0.26452301520921806	0				online	Gothenburg	479		SEK				monthly			0			0		1
7		A_basic		29	medium			0.18657432822315223	0				online	Other		279		SEK				monthly			0			0		1
...
*/


-- ===================================================================
-- Create final cleaned analysis table
-- Purpose:
-- Build a clean, analysis-ready table with one row per user,
-- standardized categorical fields, and valid numeric ranges.
-- ===================================================================


create table insurance_clean as
with cleaned as (
	select
		user_id, test_group, age,
        case
			when income_level is null or trim(income_level) = '' then 'unknown'
            else lower(trim(income_level))
		end as income_level,
		risk_score, previous_claim,
        lower(trim(channel)) as channel,
        case
			when lower(trim(city)) = 'gbg' then 'Gothenburg'
			when lower(trim(city)) = 'Gothenburg' then 'Gothenburg'
			when lower(trim(city)) = 'Stockholm' then 'Stockholm'
			when lower(trim(city)) = 'Uppsala' then 'Uppsala'
			when lower(trim(city)) = 'Malmo' then 'Malmo'	
			when lower(trim(city)) = 'Other' then 'Other'
			else 'Unknown' 
		end as city,
        price, price_currency, billing_period, converted, revenue,
        row_number() over (partition by user_id order by revenue desc) as rn
	from insurance_raw
)
select user_id, 
    test_group,
    age,
    income_level,
    risk_score,
    previous_claim,
    channel,
    city,
    price,
    price_currency,
    billing_period,
    converted,
    revenue
from cleaned
where rn=1
and age between 17 and 95
and risk_score between 0 and 1;


-- Validate final cleaned table size.

select count(*) as total_rows from insurance_clean;
-- 49701

select count(distinct user_id) as unique_users from insurance_clean;
-- 49701

-- Preview final cleaned dataset.
select * from insurance_clean limit 5;

/*
user_id	test_group	age	income_level	risk_score			previous_claim	channel	city		price	price_currency	billing_period	converted	revenue
1		B_premium	57	medium			0.3285759987753159	1				agent	Other		479		SEK				monthly			1			479
2		B_premium	45	medium			0.25310531068755965	0				agent	Gothenburg	479		SEK				monthly			0			0
3		B_premium	51	low				0.2728086532090246	0				agent	Stockholm	479		SEK				monthly			0			0
4		B_premium	35	low				0.3147910973302285	0				agent	Gothenburg	479		SEK				monthly			0			0
5		A_basic		39	low				0.07466547448788748	0				online	Gothenburg	279		SEK				monthly			0			0

*/
