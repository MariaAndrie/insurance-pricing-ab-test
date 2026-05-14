select database();
-- ===================================================================
-- Insurance Pricing A/B Test Analysis
-- Goal:
-- Compare a lower-priced Basic plan vs a higher-priced Premium plan
-- to understand the trade-off between conversion rate and revenue.
-- ===================================================================


-- 1. Baseline A/B comparison
-- Purpose:
-- Compare conversion performance between pricing groups.
-- This answers: Which plan converts more users?

select 
	test_group, 
    count(user_id) as total_users, 
    sum(converted)  as total_converted, 
    round(sum(converted)/count(user_id)*100,2)  as conversion_rate
from insurance_clean
group by test_group
order by total_converted desc;

/*
test_group	total_users	total_converted	conversion_rate
A_basic		24850		4673			18.80
B_premium	24851		3817			15.36
*/


-- Purpose:
-- Compare revenue performance between pricing groups.
-- This answers: Which plan generates more revenue per user?

select 
	test_group, 
    count(user_id) as total_users, 
    sum(revenue) as total_revenue, 
    round(sum(revenue)/count(user_id),2) as revenue_per_user
from insurance_clean
group by test_group
order by total_revenue desc;

/*
test_group	total_users	total_revenue	revenue_per_user
B_premium	24851		1828343			73.57
A_basic		24850		1303767			52.47
*/


-- Key insight:
-- The lower-priced Basic plan achieved a higher conversion rate,
-- while the Premium plan generated significantly higher revenue per user.
-- This highlights the pricing trade-off between customer acquisition
-- and revenue optimization.


-- 2. Income level segmentation
-- Purpose:
-- Evaluate whether pricing performance differs by income segment.
-- This helps identify where Premium pricing is most effective.

select 
	income_level, 
	test_group, 
    count(user_id) as total_users, 
    sum(converted) as total_converted, 
    round(sum(converted)/count(user_id)*100,2) as conversion_rate
from insurance_clean
group by income_level, test_group
order by income_level, test_group;

/*
income_level	test_group	total_users	total_converted	conversion_rate
high			A_basic		4918		1181			24.01
high			B_premium	4859		947				19.49
low				A_basic		9609		1530			15.92
low				B_premium	9873		1264			12.80
medium			A_basic		9822		1878			19.12
medium			B_premium	9635		1522			15.80
unknown			A_basic		501			84				16.77
unknown			B_premium	484			84				17.36
*/


-- Purpose:
-- Compare revenue per user by income segment and pricing group.
-- This shows whether Premium pricing creates stronger revenue gains
-- in specific income segments.

select 
	income_level, 
	test_group, 
	count(user_id) as total_user, 
	sum(revenue) as total_revenue, 
	round(sum(revenue)/count(user_id),2) as revenue_per_user
from insurance_clean
group by income_level, test_group
order by income_level, test_group;

/*
income_level	test_group	total_user	total_revenue	revenue_per_user
high			A_basic		4918		329499			67.00
high			B_premium	4859		453613			93.36
low				A_basic		9609		426870			44.42
low				B_premium	9873		605456			61.32
medium			A_basic		9822		523962			53.35
medium			B_premium	9635		729038			75.67
unknown			A_basic		501			23436			46.78
unknown			B_premium	484			40236			83.13
*/

-- 3. Channel segmentation
-- Purpose:
-- Compare pricing performance across acquisition channels.
-- This answers: Does Premium pricing perform better with agent-assisted sales?

select 
	test_group, 
    channel, 
    count(user_id) as total_user, 
    round(sum(converted)/count(user_id)*100,2) as conversion_rate, 
    round(sum(revenue)/count(user_id),2) as revenue_per_user
from insurance_clean
group by test_group, channel
order by revenue_per_user desc;

/*
test_group	channel	total_user	conversion_rate	revenue_per_user
B_premium	agent	9910		16.63			79.66
B_premium	online	14941		14.52			69.54
A_basic		agent	9901		20.92			58.36
A_basic		online	14949		17.41			48.56

-- Key insight:
-- Premium pricing performs especially well in the agent-assisted channel,
-- suggesting that higher-priced plans may benefit from human-led sales
-- interactions rather than purely online acquisition.

*/


-- 4. City segmentation
-- Purpose:
-- Compare pricing performance across Swedish city segments.
-- This answers: Which markets are most receptive to Premium pricing?

select 
	test_group, 
    city, 
    count(user_id) as total_user, 
    round(sum(converted)/count(user_id)*100,2) as conversion_rate, 
    sum(revenue)/count(user_id) as revenue_per_user
from insurance_clean
group by test_group, city
order by revenue_per_user desc;

/*
test_group	city		total_user	conversion_rate	revenue_per_user
B_premium	Stockholm	7905		16.66			79.8030
B_premium	Unknown		281			16.37			78.4128
B_premium	Gothenburg	5176		16.04			76.8103
B_premium	Malmo		3992		14.75			70.6741
B_premium	Uppsala		2220		14.32			68.6135
B_premium	Other		5277		13.59			65.0830
A_basic		Unknown		216			21.76			60.7083
A_basic		Stockholm	7858		19.92			55.5657
A_basic		Gothenburg	5193		19.45			54.2634
A_basic		Malmo		3985		18.34			51.1792
A_basic		Other		5435		17.44			48.6646
A_basic		Uppsala		2163		17.20			47.9834

*/

-- Key insight:
-- Stockholm shows the strongest Premium revenue per user among known cities,
-- suggesting that Premium pricing may perform best in large metropolitan markets.


-- 5. Statistical significance preparation
-- Purpose:
-- Create the contingency table needed for a chi-square test in Python.
-- The test checks whether the conversion-rate difference between
-- A_basic and B_premium is statistically significant.

select 
	test_group, 
	sum(converted) as converted, 
    count(converted)-sum(converted) as not_converted
from insurance_clean
group by test_group
order by test_group;

/*
test_group	converted	not_converted
A_basic		4673		20177
B_premium	3817		21034
*/

