-- =============================
-- ETL PROCESS : CLEANING & LOADING INTO DWH
-- =============================

-- 1. Nettoyage des données dans la table source "bookings"
UPDATE bookings SET children = 0 WHERE children IS NULL;
UPDATE bookings SET country = 'UNKNOWN' WHERE country IS NULL;
UPDATE bookings SET agent = 0 WHERE agent IS NULL;
UPDATE bookings SET company = 0 WHERE company IS NULL;

UPDATE bookings SET 
    meal = UPPER(TRIM(meal)),
    hotel = INITCAP(TRIM(hotel)),
    market_segment = INITCAP(TRIM(market_segment)),
    deposit_type = INITCAP(TRIM(deposit_type)),
    reservation_status = INITCAP(TRIM(reservation_status)),
    reserved_room_type = INITCAP(TRIM(reserved_room_type)),
    assigned_room_type = INITCAP(TRIM(assigned_room_type)),
    customer_type = INITCAP(TRIM(customer_type)),
    country = UPPER(TRIM(country));

-- 2. Création de la dimension "dim_hotel"
DROP TABLE IF EXISTS dim_hotel CASCADE;

CREATE TABLE dim_hotel (
    hotel_id BIGINT PRIMARY KEY,
    hotel_name TEXT,
    hotel_category TEXT
);

INSERT INTO dim_hotel (hotel_id, hotel_name, hotel_category)
SELECT 
    ROW_NUMBER() OVER (ORDER BY hotel) AS hotel_id,
    hotel AS hotel_name,
    NULL AS hotel_category
FROM (
    SELECT DISTINCT hotel FROM bookings WHERE hotel IS NOT NULL
) AS distinct_hotels;

-- 3. Création de la dimension "dim_meal"
DROP TABLE IF EXISTS dim_meal CASCADE;

CREATE TABLE dim_meal (
    meal_id SERIAL PRIMARY KEY,
    meal_code TEXT,
    meal_type TEXT
);

INSERT INTO dim_meal (meal_code, meal_type)
SELECT DISTINCT
    meal AS meal_code,
    CASE meal
        WHEN 'SC' THEN 'No Meal'
        WHEN 'BB' THEN 'Bed & Breakfast'
        WHEN 'HB' THEN 'Half Board'
        WHEN 'FB' THEN 'Full Board'
        ELSE 'Undefined'
    END AS meal_type
FROM bookings;

-- 4. Création de la table de faits "fact_booking"
DROP TABLE IF EXISTS fact_booking CASCADE;

CREATE TABLE fact_booking (
    booking_id SERIAL PRIMARY KEY,
    hotel_id BIGINT REFERENCES dim_hotel(hotel_id),
    meal_id BIGINT REFERENCES dim_meal(meal_id),
    lead_time BIGINT,
    adults BIGINT,
    children DOUBLE PRECISION,
    babies BIGINT,
    adr DOUBLE PRECISION,
    stays_in_weekend_nights BIGINT,
    stays_in_week_nights BIGINT,
    booking_changes BIGINT,
    total_guests INT,
    total_stays INT
);

-- 5. Chargement dans la table de faits
INSERT INTO fact_booking (
    hotel_id,
    meal_id,
    lead_time,
    adults,
    children,
    babies,
    adr,
    stays_in_weekend_nights,
    stays_in_week_nights,
    booking_changes,
    total_guests,
    total_stays
)
SELECT
    h.hotel_id,
    m.meal_id,
    b.lead_time,
    b.adults,
    b.children,
    b.babies,
    b.adr,
    b.stays_in_weekend_nights,
    b.stays_in_week_nights,
    b.booking_changes,
    b.adults + b.children + b.babies AS total_guests,
    b.stays_in_weekend_nights + b.stays_in_week_nights AS total_stays
FROM bookings b
JOIN dim_hotel h ON b.hotel = h.hotel_name
JOIN dim_meal m ON b.meal = m.meal_code;

-- 6. Validation de l'intégrité (exemples)
-- Nombre de lignes chargées
SELECT COUNT(*) AS total_bookings FROM bookings;
SELECT COUNT(*) AS total_dim_hotel FROM dim_hotel;
SELECT COUNT(*) AS total_dim_meal FROM dim_meal;
SELECT COUNT(*) AS total_fact_booking FROM fact_booking;

-- Vérification des correspondances de clés étrangères
SELECT COUNT(*) AS meal_id_missing 
FROM fact_booking f 
LEFT JOIN dim_meal m ON f.meal_id = m.meal_id 
WHERE m.meal_id IS NULL;

SELECT COUNT(*) AS hotel_id_missing 
FROM fact_booking f 
LEFT JOIN dim_hotel h ON f.hotel_id = h.hotel_id 
WHERE h.hotel_id IS NULL;