SELECT 
	*
FROM
	shipment.dirty_shipments;
    
-- trimming whitespaces
SELECT
	shipment_id,
    TRIM(origin_warehouse) AS origin_warehouse,
    TRIM(destination_city) AS destination_city,
    TRIM(destination_state) AS destination_state,
    TRIM(carrier) AS carrier
FROM shipment.dirty_shipments;

-- standardize text casing
SELECT 
    shipment_id,
    CONCAT(
        'Warehouse ', 
        UPPER(TRIM(REPLACE(REPLACE(LOWER(origin_warehouse), 'warehouse', ''), 'w', '')))
    ) AS origin_warehouse,

    -- Column 1: Properly Capitalized City
    CONCAT(
        -- 1. Always capitalize the first letter
        UPPER(LEFT(TRIM(destination_city), 1)),
        -- 2. Grab everything ELSE until the first space (if it exists)
        LOWER(SUBSTRING(TRIM(destination_city), 2, 
            IF(LOCATE(' ', TRIM(destination_city)) > 0, 
               LOCATE(' ', TRIM(destination_city)) - 2, 
               CHAR_LENGTH(TRIM(destination_city))
            )
        )),
        -- 3. Capitalize the letter after the space
        IF(LOCATE(' ', TRIM(destination_city)) > 0,
            CONCAT(' ', 
                UPPER(SUBSTRING(TRIM(destination_city), LOCATE(' ', TRIM(destination_city)) + 1, 1)),
                LOWER(SUBSTRING(TRIM(destination_city), LOCATE(' ', TRIM(destination_city)) + 2))
            ),
            ''
        )
    ) AS destination_city,
    -- Column 2: State in all caps
    UPPER(TRIM(destination_state)) AS destination_state,
    CONCAT(UPPER(LEFT(TRIM(carrier), 1)), LOWER(SUBSTRING(TRIM(carrier), 2))) AS carrier
FROM shipment.dirty_shipments;

-- Replace string "NULL" and handle true NULLS
SELECT
	shipment_id,
    CASE
		WHEN damage_reported = "NULL" THEN null
	ELSE CONCAT(UPPER(LEFT(TRIM(damage_reported), 1)), LOWER(SUBSTRING(TRIM(damage_reported), 2)))
		END AS damage_reported,
	COALESCE(NULLIF(TRIM(destination_city), ''), "Uknown") AS destination_city,
    COALESCE(NULLIF(TRIM(delivery_date), ""), "Not Yet Delivered") AS delivery_date
FROM shipment.dirty_shipments;

-- Remove Exact Duplicate Rows

WITH ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER(
            PARTITION BY origin_warehouse, destination_city, carrier, ship_date, 
                         CAST(weight_kg AS CHAR), CAST(freight_cost AS CHAR)
            ORDER BY shipment_id
        ) AS row_num
    FROM shipment.dirty_shipments
)
-- You must list the actual column names here instead of using *
SELECT 
    shipment_id, 
    origin_warehouse, 
    destination_city, 
    carrier, 
    ship_date, 
    weight_kg, 
    freight_cost
FROM ranked
WHERE row_num = 1;

-- Fix Negative and Suspicious Values
SELECT
	shipment_id,
	CASE
		WHEN weight_kg < 0 THEN ABS(weight_kg)
        WHEN weight_kg = 0 THEN null
	ELSE weight_kg
    END AS weight_kg_cleaned,
    CASE
		WHEN freight_cost < 0 THEN ABS(freight_cost)
        WHEN freight_cost = 0 THEN null
	ELSE freight_cost
    END AS freight_cost_cleaned,
    CASE
		WHEN items_count < 0 THEN ABS(items_count)
        WHEN items_count = 0 THEN null
	ELSE items_count
    END AS items_count_cleaned
FROM shipment.dirty_shipments;

-- validate Date Logic(Delivery After Ship Date)
SELECT
    shipment_id,
    ship_date,
    delivery_date,
    DATEDIFF(
        COALESCE(
            STR_TO_DATE(TRIM(delivery_date), '%Y-%m-%d'), 
            STR_TO_DATE(TRIM(delivery_date), '%m/%d/%Y'),
            STR_TO_DATE(TRIM(delivery_date), '%b %d %Y')  -- Handles "Feb 15 2024"
        ),
        COALESCE(
            STR_TO_DATE(TRIM(ship_date), '%Y-%m-%d'), 
            STR_TO_DATE(TRIM(ship_date), '%m/%d/%Y'),
            STR_TO_DATE(TRIM(ship_date), '%b %d %Y')      -- Handles "Feb 10 2024"
        )
    ) AS transit_days,
    CASE 
		WHEN STR_TO_DATE(TRIM(delivery_date), '%Y-%m-%d') < STR_TO_DATE(TRIM(ship_date), '%Y-%m-%d') THEN "INVALID"
        WHEN STR_TO_DATE(TRIM(delivery_date), '%Y-%m-%d') = STR_TO_DATE(TRIM(ship_date), '%Y-%m-%d') THEN "SAME_DAY_DELIVERY"
	ELSE "VALID"
    END AS data_quality_flag
FROM shipment.dirty_shipments;

-- Detect And Cap Outliers(Using Percentiles and IQR)
WITH ranked_costs AS (
    SELECT 
        freight_cost,
        PERCENT_RANK() OVER (ORDER BY freight_cost) AS p_rank
    FROM shipment.dirty_shipments
    WHERE freight_cost > 0
),
stats AS (
    SELECT 
        MIN(CASE WHEN p_rank >= 0.25 THEN freight_cost END) AS q1,
        MIN(CASE WHEN p_rank >= 0.75 THEN freight_cost END) AS q3
    FROM ranked_costs
),
bounds AS(
SELECT
	q1 - 1.5 * (q3 - q1) AS lower_bound,
    q3 + 1.5 * (q3 - q1) AS upper_bound
FROM stats
)
SELECT 
    shipment_id,
    freight_cost AS original_cost,
    CASE
		WHEN freight_cost > (SELECT upper_bound FROM bounds) THEN (SELECT upper_bound from bounds)
        WHEN freight_cost < (SELECT lower_bound FROM bounds) THEN (SELECT lower_bound from bounds)
	ELSE freight_cost
    END AS cleaned_cost,
    CASE
		WHEN freight_cost > (SELECT upper_bound FROM bounds) OR
        freight_cost < (SELECT lower_bound FROM bounds) THEN TRUE
	ELSE FALSE
    END AS was_outlier
    
FROM shipment.dirty_shipments;



    








