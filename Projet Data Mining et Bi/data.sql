-- Début du script
SET DEFINE OFF

-- Configuration pour afficher les erreurs immédiatement
SET ECHO ON;
SET FEEDBACK ON;
SET SERVEROUTPUT ON;
WHENEVER SQLERROR EXIT SQL.SQLCODE;

-- Nettoyage pour éviter des erreurs de suppression
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE FACT_BOOKING CASCADE CONSTRAINTS';
    EXECUTE IMMEDIATE 'DROP TABLE DIM_TIME CASCADE CONSTRAINTS';
    EXECUTE IMMEDIATE 'DROP TABLE DIM_HOTEL CASCADE CONSTRAINTS';
    EXECUTE IMMEDIATE 'DROP TABLE DIM_GUEST CASCADE CONSTRAINTS';
    EXECUTE IMMEDIATE 'DROP TABLE DIM_ROOM CASCADE CONSTRAINTS';
    EXECUTE IMMEDIATE 'DROP TABLE DIM_MEAL CASCADE CONSTRAINTS';
    EXECUTE IMMEDIATE 'DROP TABLE DIM_AGENT CASCADE CONSTRAINTS';
    EXECUTE IMMEDIATE 'DROP TABLE DIM_SALES_CHANNEL CASCADE CONSTRAINTS';
    EXECUTE IMMEDIATE 'DROP TABLE DIM_DEPOSIT CASCADE CONSTRAINTS';
    EXECUTE IMMEDIATE 'DROP TABLE DIM_BOOKING_STATUTS CASCADE CONSTRAINTS';
EXCEPTION
    WHEN OTHERS THEN
        NULL; -- Ignore les erreurs si la table n'existe pas
END;
/


-- Création de la table FACT_BOOKING
CREATE TABLE FACT_BOOKING (
    id_arrival_date INT,
    id_reservation_status_date INT,
    id_hotel INT,
    id_guest INT,
    id_reserved_room INT,
    id_assigned_room INT,
    id_sales_channel INT,
    id_meal INT,
    id_agent INT,
    id_deposit INT,
    id_booking_status INT,
    lead_time INT,
    adults INT,
    children INT,
    babies INT,
    adr DECIMAL,
    weekend_nights INT,
    week_nights INT,
    days_in_waiting INT,
    booking_changes INT,
    parking_spaces INT,
    special_requests INT
);

-- Création de la table DIM_TIME
CREATE TABLE DIM_TIME (
    id_date INT PRIMARY KEY,
    day INT,
    month INT,
    month_name VARCHAR2(50),
    year INT,
    week_number INT,
    day_of_month INT
);

-- Création de la table DIM_HOTEL
CREATE TABLE DIM_HOTEL (
    id_hotel INT PRIMARY KEY,
    hotel_type VARCHAR2(50)
);

-- Création de la table DIM_GUEST
CREATE TABLE DIM_GUEST (
    id_guest INT PRIMARY KEY,
    country VARCHAR2(50),
    is_rep NUMBER(1), 
    prev_cancellations INT,  
    prev_not_cancelled INT 
);

-- Création de la table DIM_ROOM
CREATE TABLE DIM_ROOM (
    id_room INT PRIMARY KEY,
    room_type VARCHAR2(50)
);

-- Création de la table DIM_MEAL
CREATE TABLE DIM_MEAL (
    id_meal INT PRIMARY KEY,
    meal_code VARCHAR2(50),
    meal_type VARCHAR2(50)
);

-- Création de la table DIM_AGENT
CREATE TABLE DIM_AGENT (
    id_agent INT PRIMARY KEY,
    agent_code VARCHAR2(50),
    company_code VARCHAR2(50)
);

-- Création de la table DIM_SALES_CHANNEL
CREATE TABLE DIM_SALES_CHANNEL (
    id_channel INT PRIMARY KEY,
    distribution_channel VARCHAR2(50),
    market_segment VARCHAR2(50)
);

-- Création de la table DIM_DEPOSIT
CREATE TABLE DIM_DEPOSIT (
    id_deposit INT PRIMARY KEY,
    deposit_type VARCHAR2(50)
);

-- Création de la table DIM_BOOKING_STATUTS
CREATE TABLE DIM_BOOKING_STATUTS (
    id_status INT PRIMARY KEY,
    booking_status VARCHAR2(50)
);
-- Ajout des contraintes de clé étrangère
ALTER TABLE FACT_BOOKING ADD CONSTRAINT fk_arrival_date 
    FOREIGN KEY (id_arrival_date) REFERENCES DIM_TIME(id_date);

ALTER TABLE FACT_BOOKING ADD CONSTRAINT fk_reservation_date 
    FOREIGN KEY (id_reservation_status_date) REFERENCES DIM_TIME(id_date);

ALTER TABLE FACT_BOOKING ADD CONSTRAINT fk_hotel 
    FOREIGN KEY (id_hotel) REFERENCES DIM_HOTEL(id_hotel);

ALTER TABLE FACT_BOOKING ADD CONSTRAINT fk_guest 
    FOREIGN KEY (id_guest) REFERENCES DIM_GUEST(id_guest);

ALTER TABLE FACT_BOOKING ADD CONSTRAINT fk_reserved_room 
    FOREIGN KEY (id_reserved_room) REFERENCES DIM_ROOM(id_room);

ALTER TABLE FACT_BOOKING ADD CONSTRAINT fk_assigned_room 
    FOREIGN KEY (id_assigned_room) REFERENCES DIM_ROOM(id_room);

ALTER TABLE FACT_BOOKING ADD CONSTRAINT fk_sales_channel 
    FOREIGN KEY (id_sales_channel) REFERENCES DIM_SALES_CHANNEL(id_channel);

ALTER TABLE FACT_BOOKING ADD CONSTRAINT fk_meal 
    FOREIGN KEY (id_meal) REFERENCES DIM_MEAL(id_meal);

ALTER TABLE FACT_BOOKING ADD CONSTRAINT fk_agent 
    FOREIGN KEY (id_agent) REFERENCES DIM_AGENT(id_agent);

ALTER TABLE FACT_BOOKING ADD CONSTRAINT fk_deposit 
    FOREIGN KEY (id_deposit) REFERENCES DIM_DEPOSIT(id_deposit);

ALTER TABLE FACT_BOOKING ADD CONSTRAINT fk_booking_status 
    FOREIGN KEY (id_booking_status) REFERENCES DIM_BOOKING_STATUTS(id_status);
    
  SELECT * FROM RAW_DATA WHERE ROWNUM <= 10;  -- Aperçu des 10 premières lignes
SELECT COUNT(*) FROM RAW_DATA;              -- Nombre total de lignes

SELECT * FROM DIM_HOTEL;

-- Insertion des types d'hôtels
INSERT INTO DIM_HOTEL (id_hotel, hotel_type)
SELECT 
    ROW_NUMBER() OVER (ORDER BY hotel),
    hotel
FROM (
    SELECT DISTINCT hotel FROM RAW_DATA
);

COMMIT;

-- Vérification
SELECT * FROM DIM_HOTEL;

-- Création d'une vue pour toutes les dates uniques
CREATE OR REPLACE VIEW ALL_DATES AS
SELECT 
    TO_DATE(arrival_date_year || '-' || INITCAP(TRIM(arrival_date_month)) || '-' || arrival_date_day_of_month, 'YYYY-Month-DD', 'NLS_DATE_LANGUAGE=ENGLISH') AS full_date
FROM RAW_DATA
WHERE REGEXP_LIKE(arrival_date_month, '^[A-Za-z]+$')
AND arrival_date_month IS NOT NULL
AND arrival_date_day_of_month IS NOT NULL
AND arrival_date_year IS NOT NULL
UNION
SELECT 
    TO_DATE(reservation_status_date, 'YYYY-MM-DD')
FROM RAW_DATA
WHERE reservation_status_date IS NOT NULL;



-- Insertion dans DIM_TIME
INSERT INTO DIM_TIME (id_date, day, month, month_name, year, week_number, day_of_month)
SELECT DISTINCT
    TO_NUMBER(TO_CHAR(full_date, 'YYYYMMDD')) AS id_date,
    EXTRACT(DAY FROM full_date),
    EXTRACT(MONTH FROM full_date),
    TO_CHAR(full_date, 'Month'),
    EXTRACT(YEAR FROM full_date),
    TO_NUMBER(TO_CHAR(full_date, 'WW')),
    EXTRACT(DAY FROM full_date)
FROM ALL_DATES
WHERE full_date IS NOT NULL
AND TO_NUMBER(TO_CHAR(full_date, 'YYYYMMDD')) NOT IN (
    SELECT id_date FROM DIM_TIME
);



COMMIT;

-- Vérification
SELECT COUNT(*) FROM DIM_TIME;

-- Insertion des clients
INSERT INTO DIM_GUEST (id_guest, country, is_rep, prev_cancellations, prev_not_cancelled)
SELECT 
    ROW_NUMBER() OVER (ORDER BY country),
    country,
    CASE WHEN country = 'PRT' THEN 1 ELSE 0 END,
    previous_cancellations,
    previous_bookings_not_canceled
FROM (
    SELECT DISTINCT 
        country,
        previous_cancellations,
        previous_bookings_not_canceled
    FROM RAW_DATA
);

COMMIT;
-- Insertion des types de chambres
INSERT INTO DIM_ROOM (id_room, room_type)
SELECT 
    ROW_NUMBER() OVER (ORDER BY reserved_room_type),
    reserved_room_type
FROM (
    SELECT DISTINCT reserved_room_type FROM RAW_DATA
);

COMMIT;
-- Insertion des types de repas
INSERT INTO DIM_MEAL (id_meal, meal_code, meal_type)
SELECT 
    ROW_NUMBER() OVER (ORDER BY meal),
    meal,
    CASE meal
        WHEN 'SC' THEN 'No Meal'
        WHEN 'BB' THEN 'Bed & Breakfast'
        WHEN 'HB' THEN 'Half Board'
        WHEN 'FB' THEN 'Full Board'
        ELSE 'Undefined'
    END
FROM (
    SELECT DISTINCT meal FROM RAW_DATA
);

COMMIT;
-- Insertion des agents
INSERT INTO DIM_AGENT (id_agent, agent_code, company_code)
SELECT 
    ROW_NUMBER() OVER (ORDER BY agent),
    NVL(TO_CHAR(agent), 'NULL'),
    NVL(TO_CHAR(company), 'NULL')
FROM (
    SELECT DISTINCT agent, company FROM RAW_DATA
);

COMMIT;
-- Insertion des canaux de vente
INSERT INTO DIM_SALES_CHANNEL (id_channel, distribution_channel, market_segment)
SELECT 
    ROW_NUMBER() OVER (ORDER BY distribution_channel, market_segment),
    distribution_channel,
    market_segment
FROM (
    SELECT DISTINCT distribution_channel, market_segment FROM RAW_DATA
);

COMMIT;
-- Insertion des types de dépôt
INSERT INTO DIM_DEPOSIT (id_deposit, deposit_type)
SELECT 
    ROW_NUMBER() OVER (ORDER BY deposit_type),
    deposit_type
FROM (
    SELECT DISTINCT deposit_type FROM RAW_DATA
);

COMMIT;
-- Insertion des statuts de réservation
INSERT INTO DIM_BOOKING_STATUTS (id_status, booking_status)
SELECT 
    ROW_NUMBER() OVER (ORDER BY reservation_status),
    reservation_status
FROM (
    SELECT DISTINCT reservation_status FROM RAW_DATA
);

COMMIT;
-- Insertion des réservations (version complète)
INSERT INTO FACT_BOOKING (
    id_arrival_date,
    id_reservation_status_date,
    id_hotel,
    id_guest,
    id_reserved_room,
    id_assigned_room,
    id_sales_channel,
    id_meal,
    id_agent,
    id_deposit,
    id_booking_status,
    lead_time,
    adults,
    children,
    babies,
    adr,
    weekend_nights,
    week_nights,
    days_in_waiting,
    booking_changes,
    parking_spaces,
    special_requests
)
SELECT
    TO_NUMBER(TO_CHAR(TO_DATE(r.arrival_date_year || '-' || r.arrival_date_month || '-' || r.arrival_date_day_of_month, 'YYYY-Month-DD'), 'YYYYMMDD')),
    TO_NUMBER(TO_CHAR(TO_DATE(r.reservation_status_date, 'YYYY-MM-DD'), 'YYYYMMDD')),
    h.id_hotel,
    g.id_guest,
    rr.id_room,
    ar.id_room,
    sc.id_channel,
    m.id_meal,
    ag.id_agent,
    d.id_deposit,
    bs.id_status,
    r.lead_time,
    r.adults,
    NVL(r.children, 0),
    r.babies,
    r.adr,
    r.stays_in_weekend_nights,
    r.stays_in_week_nights,
    r.days_in_waiting_list,
    r.booking_changes,
    NVL(r.required_car_parking_spaces, 0),
    r.total_of_special_requests
FROM RAW_DATA r
JOIN DIM_HOTEL h ON r.hotel = h.hotel_type
JOIN DIM_GUEST g ON r.country = g.country AND r.previous_cancellations = g.prev_cancellations AND r.previous_bookings_not_canceled = g.prev_not_cancelled
JOIN DIM_ROOM rr ON r.reserved_room_type = rr.room_type
JOIN DIM_ROOM ar ON r.assigned_room_type = ar.room_type
JOIN DIM_SALES_CHANNEL sc ON r.distribution_channel = sc.distribution_channel AND r.market_segment = sc.market_segment
JOIN DIM_MEAL m ON r.meal = m.meal_code
JOIN DIM_AGENT ag ON NVL(TO_CHAR(r.agent), 'NULL') = ag.agent_code AND NVL(TO_CHAR(r.company), 'NULL') = ag.company_code
JOIN DIM_DEPOSIT d ON r.deposit_type = d.deposit_type
JOIN DIM_BOOKING_STATUTS bs ON r.reservation_status = bs.booking_status;

COMMIT;
-- Comptage des enregistrements
SELECT 'DIM_HOTEL' AS table_name, COUNT(*) FROM DIM_HOTEL
UNION ALL SELECT 'DIM_TIME', COUNT(*) FROM DIM_TIME
UNION ALL SELECT 'DIM_GUEST', COUNT(*) FROM DIM_GUEST
UNION ALL SELECT 'DIM_ROOM', COUNT(*) FROM DIM_ROOM
UNION ALL SELECT 'DIM_MEAL', COUNT(*) FROM DIM_MEAL
UNION ALL SELECT 'DIM_AGENT', COUNT(*) FROM DIM_AGENT
UNION ALL SELECT 'DIM_SALES_CHANNEL', COUNT(*) FROM DIM_SALES_CHANNEL
UNION ALL SELECT 'DIM_DEPOSIT', COUNT(*) FROM DIM_DEPOSIT
UNION ALL SELECT 'DIM_BOOKING_STATUTS', COUNT(*) FROM DIM_BOOKING_STATUTS
UNION ALL SELECT 'FACT_BOOKING', COUNT(*) FROM FACT_BOOKING;

-- Vérifiez les clés étrangères manquantes
SELECT COUNT(*) FROM FACT_BOOKING f
LEFT JOIN DIM_HOTEL h ON f.id_hotel = h.id_hotel
WHERE h.id_hotel IS NULL;


-- Créez des index pour les requêtes fréquentes
CREATE INDEX idx_fact_arrival_date ON FACT_BOOKING(id_arrival_date);
CREATE INDEX idx_fact_hotel_status ON FACT_BOOKING(id_hotel, id_booking_status);

-- Ajoutez une colonne calculée pour le revenu (si utile)
ALTER TABLE FACT_BOOKING ADD revenue NUMBER GENERATED ALWAYS AS (
    (weekend_nights + week_nights) * adr
) VIRTUAL;

-- Vérifier les valeurs manquantes critiques
SELECT COUNT(*) 
FROM RAW_DATA 
WHERE hotel IS NULL OR arrival_date_year IS NULL OR is_canceled IS NULL;

-- Vérifier les incohérences temporelles
SELECT COUNT(*) 
FROM RAW_DATA 
WHERE TO_DATE(reservation_status_date, 'YYYY-MM-DD') < 
      TO_DATE(arrival_date_year || '-' || arrival_date_month || '-' || arrival_date_day_of_month, 'YYYY-Month-DD');
-- Remplacer les NULL par des valeurs par défaut
UPDATE RAW_DATA 
SET children = 0 
WHERE children IS NULL;

UPDATE RAW_DATA 
SET country = 'UNK' 
WHERE country IS NULL;

SELECT id_hotel
FROM FACT_BOOKING
WHERE id_hotel NOT IN (SELECT id_hotel FROM DIM_HOTEL);

-- Fin du script
EXIT;

-- Voir toutes les tables disponibles dans DATA_RAW
SELECT table_name
FROM all_tables
WHERE owner = 'DATA_RAW'; -- Mets bien DATA_RAW en majuscules

-- Voir combien de lignes il y a dans chaque table
SELECT table_name, num_rows
FROM all_tables
WHERE owner = 'DATA_RAW';

SELECT * FROM DATA_RAW.FACT_BOOKING FETCH FIRST 10 ROWS ONLY;
SELECT * FROM RAW_DATA FETCH FIRST 5 ROWS ONLY;
SELECT count(*) FROM user_tables WHERE table_name = 'RAW_DATA';
SELECT * FROM RAW_DATA WHERE ROWNUM <= 10;
DESC RAW_DATA;
SELECT COUNT(*) 
FROM RAW_DATA 
WHERE HOTEL IS NULL OR ARRIVAL_DATE_YEAR IS NULL OR COUNTRY IS NULL;

-- Vérification complète des données
SELECT 
    (SELECT COUNT(*) FROM DIM_HOTEL) as dim_hotel,
    (SELECT COUNT(*) FROM DIM_TIME) as dim_time,
    (SELECT COUNT(*) FROM DIM_GUEST) as dim_guest,
    (SELECT COUNT(*) FROM DIM_ROOM) as dim_room,
    (SELECT COUNT(*) FROM DIM_MEAL) as dim_meal,
    (SELECT COUNT(*) FROM DIM_AGENT) as dim_agent,
    (SELECT COUNT(*) FROM DIM_SALES_CHANNEL) as dim_sales_channel,
    (SELECT COUNT(*) FROM DIM_DEPOSIT) as dim_deposit,
    (SELECT COUNT(*) FROM DIM_BOOKING_STATUTS) as dim_booking_status,
    (SELECT COUNT(*) FROM FACT_BOOKING) as fact_booking
FROM dual;

--verifier la join
SELECT COUNT(*) 
FROM FACT_BOOKING f
LEFT JOIN DIM_HOTEL h ON f.id_hotel = h.id_hotel
WHERE h.id_hotel IS NULL;

--verif de doublons
SELECT id_hotel, COUNT(*) 
FROM DIM_HOTEL 
GROUP BY id_hotel 
HAVING COUNT(*) > 1;

--verif de relation
SELECT COUNT(*) 
FROM FACT_BOOKING f 
LEFT JOIN DIM_HOTEL h ON f.id_hotel = h.id_hotel 
WHERE h.id_hotel IS NULL;
--test tot
SELECT 'DIM_HOTEL' AS table_name, COUNT(*) FROM DIM_HOTEL
UNION ALL 
SELECT 'DIM_TIME', COUNT(*) FROM DIM_TIME
UNION ALL 
SELECT 'DIM_GUEST', COUNT(*) FROM DIM_GUEST
UNION ALL 
SELECT 'DIM_ROOM', COUNT(*) FROM DIM_ROOM
UNION ALL 
SELECT 'DIM_MEAL', COUNT(*) FROM DIM_MEAL
UNION ALL 
SELECT 'DIM_AGENT', COUNT(*) FROM DIM_AGENT
UNION ALL 
SELECT 'DIM_SALES_CHANNEL', COUNT(*) FROM DIM_SALES_CHANNEL
UNION ALL 
SELECT 'DIM_DEPOSIT', COUNT(*) FROM DIM_DEPOSIT
UNION ALL 
SELECT 'DIM_BOOKING_STATUTS', COUNT(*) FROM DIM_BOOKING_STATUTS
UNION ALL 
SELECT 'FACT_BOOKING', COUNT(*) FROM FACT_BOOKING;

SELECT h.hotel_type, SUM(f.revenue) AS total_revenue
FROM FACT_BOOKING f
JOIN DIM_HOTEL h ON f.id_hotel = h.id_hotel
JOIN DIM_HOTEL_DETAILS d ON h.id_hotel = d.id_hotel  -- Remplace DIM_HOTEL_DETAILS par le nom réel de la table
GROUP BY h.hotel_type
ORDER BY total_revenue DESC;

SELECT table_name
FROM all_tables
WHERE owner = 'system';
