/* =====================================================================
   E-Commerce Growth Analytics  -  SQL Server  -  v2 (audited & fixed)
   ---------------------------------------------------------------------
   Layers:  stg_online_retail (raw text)  ->  Online_retail_cleaned (typed + clean)  ->  views
   View names and column names are the SAME as in v1, so the Power BI
   report keeps working after Refresh. New views are added on top.

   Fixes vs v1 (see README "Data audit"):
   1. UnitPrice was imported with the wrong decimal separator
      ("2.55" -> 255), inflating revenue ~92x (821.5M instead of 8.9M).
   2. Exact duplicate rows removed (5,192).
   3. Two orders fully cancelled in the source data removed
      (581483: 80,995 units / 541431: 74,215 units).
   4. Non-product codes (POST, M, DOT, C2, BANK CHARGES, PADS) flagged.
   5. AOV = revenue / distinct orders (v1 used the average order LINE).
   6. Month trend has a real date column + partial-month flag.
   7. Days between orders computed at ORDER level (v1 numbered lines).
   8. NEW views: vw_KPI, vw_CohortRetention, vw_TimeToSecondOrder.

   Run it block by block (select a block -> F5), top to bottom.
   ===================================================================== */

USE ECommerceDB;
GO

/* ---------------------------------------------------------------------
   BLOCK 1 - Staging table: every column as TEXT (no conversion yet)
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS dbo.stg_online_retail;

CREATE TABLE dbo.stg_online_retail (
    InvoiceNo     NVARCHAR(50),
    StockCode     NVARCHAR(50),
    Description   NVARCHAR(255),
    Quantity      NVARCHAR(50),
    InvoiceDate   NVARCHAR(50),
    UnitPrice     NVARCHAR(50),
    CustomerID    NVARCHAR(50),
    Country       NVARCHAR(100),
    TotalRevenue  NVARCHAR(50),
    YearMonth     NVARCHAR(20),
    dayOfTheWeek  NVARCHAR(20),
    [Hour]        NVARCHAR(20)
);
GO

/* ---------------------------------------------------------------------
   BLOCK 2 - Load the CSV into staging
   >>> Change the path to where YOUR file is. <<<
   --------------------------------------------------------------------- */
BULK INSERT dbo.stg_online_retail
FROM 'C:\Data\Online_retail_cleaned.csv'
WITH (
    FORMAT          = 'CSV',      -- understands "quoted, values"
    FIRSTROW        = 2,          -- skip header
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0a',
    CODEPAGE        = '65001',    -- UTF-8
    TABLOCK
);
GO

SELECT COUNT(*) AS staging_rows FROM dbo.stg_online_retail;   -- expected: 397,884
GO

/* ---------------------------------------------------------------------
   BLOCK 3 - Typed + clean table (same name as v1)
   TRY_CONVERT on text always reads '.' as the decimal point,
   whatever the Windows regional settings are.
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS dbo.Online_retail_typed;

SELECT
    LTRIM(RTRIM(InvoiceNo))                                     AS InvoiceNo,
    LTRIM(RTRIM(StockCode))                                     AS StockCode,
    Description,
    TRY_CONVERT(INT, Quantity)                                  AS Quantity,
    TRY_CONVERT(DATETIME2(0), InvoiceDate, 120)                 AS InvoiceDate,
    TRY_CONVERT(DECIMAL(12,3), UnitPrice)                       AS UnitPrice,
    TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(12,1), CustomerID))    AS CustomerID,   -- "17850.0" -> 17850
    Country,
    REPLACE(REPLACE(dayOfTheWeek, CHAR(13), ''), CHAR(10), '')  AS dayOfTheWeek
INTO dbo.Online_retail_typed
FROM dbo.stg_online_retail;
GO

-- CHECKPOINT 1: all four "bad_" columns must be 0 and revenue ~8,911,408
SELECT
    COUNT(*)                                                    AS row_count,      -- 397,884
    SUM(CASE WHEN Quantity    IS NULL THEN 1 ELSE 0 END)        AS bad_quantity,   -- 0
    SUM(CASE WHEN InvoiceDate IS NULL THEN 1 ELSE 0 END)        AS bad_dates,      -- 0
    SUM(CASE WHEN UnitPrice   IS NULL THEN 1 ELSE 0 END)        AS bad_prices,     -- 0
    SUM(CASE WHEN CustomerID  IS NULL THEN 1 ELSE 0 END)        AS bad_customers,  -- 0
    MAX(UnitPrice)                                              AS max_price,      -- 8142.750
    SUM(Quantity * UnitPrice)                                   AS total_revenue   -- 8,911,407.904 (NOT 821M!)
FROM dbo.Online_retail_typed;
GO

/* ---------------------------------------------------------------------
   BLOCK 4 - Final clean table, SAME NAME as v1 -> Power BI keeps working
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS dbo.Online_retail_cleaned;

WITH dedup AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY InvoiceNo, StockCode, Description, Quantity,
                            InvoiceDate, UnitPrice, CustomerID, Country
               ORDER BY (SELECT NULL)) AS rn
    FROM dbo.Online_retail_typed
)
SELECT
    InvoiceNo, StockCode, Description, Quantity, InvoiceDate, UnitPrice,
    CustomerID, Country,
    CAST(Quantity * UnitPrice AS DECIMAL(14,3))                 AS TotalRevenue,
    CONVERT(CHAR(7), InvoiceDate, 120)                          AS YearMonth,
    DATEFROMPARTS(YEAR(InvoiceDate), MONTH(InvoiceDate), 1)     AS MonthStart,
    dayOfTheWeek,
    DATEPART(HOUR, InvoiceDate)                                 AS [Hour],
    CASE WHEN StockCode IN ('POST','DOT','M','C2','BANK CHARGES','PADS')
         THEN 0 ELSE 1 END                                      AS IsProduct
INTO dbo.Online_retail_cleaned
FROM dedup
WHERE rn = 1                                                    -- remove exact duplicates
  AND InvoiceNo NOT IN ('581483', '541431');                    -- orders fully cancelled in source data
GO

-- CHECKPOINT 2
SELECT
    COUNT(*)                                                    AS row_count,      -- 392,690
    COUNT(DISTINCT InvoiceNo)                                   AS orders,         -- 18,530
    COUNT(DISTINCT CustomerID)                                  AS customers,      -- 4,337
    SUM(TotalRevenue)                                           AS revenue         -- 8,641,555.69
FROM dbo.Online_retail_cleaned;
GO

/* ---------------------------------------------------------------------
   BLOCK 5 - Views used by the dashboard (v1 names + v1 columns kept)
   --------------------------------------------------------------------- */

-- Headline KPIs (NEW) - use this for the cards
CREATE OR ALTER VIEW dbo.vw_KPI AS
SELECT
    SUM(TotalRevenue)                                           AS Revenue,
    COUNT(DISTINCT InvoiceNo)                                   AS Orders,
    COUNT(DISTINCT CustomerID)                                  AS Customers,
    SUM(TotalRevenue) / COUNT(DISTINCT InvoiceNo)               AS AOV,
    1.0 * COUNT(DISTINCT InvoiceNo) / COUNT(DISTINCT CustomerID) AS OrdersPerCustomer
FROM dbo.Online_retail_cleaned;
GO

-- Monthly trend (v1 columns kept; Valoare_Medie_Tranzactie is now a real AOV)
CREATE OR ALTER VIEW dbo.vw_TrendLunar AS
SELECT
    YearMonth,
    MonthStart,
    COUNT(DISTINCT InvoiceNo)                                   AS Numar_Comenzi,
    SUM(TotalRevenue)                                           AS Venit_Lunar,
    CAST(SUM(TotalRevenue) / COUNT(DISTINCT InvoiceNo) AS DECIMAL(12,2)) AS Valoare_Medie_Tranzactie,
    COUNT(DISTINCT CustomerID)                                  AS Clienti_Activi,
    CASE WHEN YearMonth = '2011-12' THEN 1 ELSE 0 END           AS Luna_Partiala    -- only 9 days of data
FROM dbo.Online_retail_cleaned
GROUP BY YearMonth, MonthStart;
GO

-- Month-over-month growth (NEW, window function)
CREATE OR ALTER VIEW dbo.vw_TrendMoM AS
SELECT
    YearMonth, MonthStart, Venit_Lunar, Numar_Comenzi, Valoare_Medie_Tranzactie,
    LAG(Venit_Lunar) OVER (ORDER BY MonthStart)                 AS Venit_Luna_Anterioara,
    CAST(100.0 * (Venit_Lunar - LAG(Venit_Lunar) OVER (ORDER BY MonthStart))
         / NULLIF(LAG(Venit_Lunar) OVER (ORDER BY MonthStart), 0) AS DECIMAL(6,1)) AS Crestere_MoM_Pct
FROM dbo.vw_TrendLunar
WHERE Luna_Partiala = 0;
GO

-- Top products (grouped by code only; non-product codes excluded)
CREATE OR ALTER VIEW dbo.vw_TopProduse AS
SELECT
    StockCode,
    MAX(Description)                                            AS Description,
    SUM(Quantity)                                               AS Total_Bucati_Vandute,
    SUM(TotalRevenue)                                           AS Venit_Total_Generat
FROM dbo.Online_retail_cleaned
WHERE IsProduct = 1
GROUP BY StockCode;
GO

-- Country share (v1 columns kept)
CREATE OR ALTER VIEW dbo.VW_VANZARI_PE_TARI AS
WITH COMENZI_PER_TARA AS (
    SELECT Country,
           SUM(TotalRevenue)            AS VENIT_TARA,
           COUNT(DISTINCT InvoiceNo)    AS NUMAR_COMENZI,
           COUNT(DISTINCT CustomerID)   AS NUMAR_CLIENTI
    FROM dbo.Online_retail_cleaned
    GROUP BY Country
),
COMENZI_GLOBALE AS (
    SELECT SUM(TotalRevenue) AS VENIT_GLOBALE
    FROM dbo.Online_retail_cleaned
)
SELECT
    A.Country                                                   AS COUNTRY,
    A.VENIT_TARA,
    B.VENIT_GLOBALE,
    CAST(100.0 * A.VENIT_TARA / B.VENIT_GLOBALE AS DECIMAL(6,2)) AS PROCENTUAL,
    A.NUMAR_COMENZI,
    A.NUMAR_CLIENTI
FROM COMENZI_PER_TARA A
CROSS JOIN COMENZI_GLOBALE B;
GO

-- One-time vs repeat (v1 columns kept + revenue share)
CREATE OR ALTER VIEW dbo.vw_RetentieClienti AS
WITH ClientComenzi AS (
    SELECT CustomerID,
           COUNT(DISTINCT InvoiceNo) AS Numar_Comenzi_Total,
           SUM(TotalRevenue)         AS Venit_Client
    FROM dbo.Online_retail_cleaned
    GROUP BY CustomerID
)
SELECT
    CASE WHEN Numar_Comenzi_Total = 1
         THEN 'Client cu o singură comandă (One-Time)'
         ELSE 'Client fidel (Repeat Buyer)' END                 AS Tip_Client,
    COUNT(CustomerID)                                           AS Numar_De_Clienti,
    SUM(Venit_Client)                                           AS Venit,
    CAST(100.0 * SUM(Venit_Client) / SUM(SUM(Venit_Client)) OVER () AS DECIMAL(5,2)) AS Procent_Din_Venit
FROM ClientComenzi
GROUP BY CASE WHEN Numar_Comenzi_Total = 1
              THEN 'Client cu o singură comandă (One-Time)'
              ELSE 'Client fidel (Repeat Buyer)' END;
GO

/* ---------------------------------------------------------------------
   BLOCK 6 - NEW: Monthly cohort retention
   Cohort = month of the customer's FIRST order.
   MonthNumber = months since the first order (0 = acquisition month).
   --------------------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_CohortRetention AS
WITH orders AS (                      -- one row per order
    SELECT InvoiceNo, CustomerID, MIN(InvoiceDate) AS OrderDate
    FROM dbo.Online_retail_cleaned
    GROUP BY InvoiceNo, CustomerID
),
first_order AS (                      -- cohort of each customer
    SELECT CustomerID,
           DATEFROMPARTS(YEAR(MIN(OrderDate)), MONTH(MIN(OrderDate)), 1) AS CohortMonth
    FROM orders
    GROUP BY CustomerID
),
activity AS (                         -- months in which each customer was active
    SELECT DISTINCT
           o.CustomerID,
           f.CohortMonth,
           DATEDIFF(MONTH, f.CohortMonth, o.OrderDate) AS MonthNumber
    FROM orders o
    JOIN first_order f ON f.CustomerID = o.CustomerID
),
cohort_size AS (
    SELECT CohortMonth, COUNT(*) AS CohortSize
    FROM first_order
    GROUP BY CohortMonth
)
SELECT
    a.CohortMonth,
    CONVERT(CHAR(7), a.CohortMonth, 120)                        AS Cohort,
    a.MonthNumber,
    s.CohortSize,
    COUNT(*)                                                    AS ActiveCustomers,
    CAST(100.0 * COUNT(*) / s.CohortSize AS DECIMAL(5,1))       AS RetentionPct
FROM activity a
JOIN cohort_size s ON s.CohortMonth = a.CohortMonth
GROUP BY a.CohortMonth, a.MonthNumber, s.CohortSize;
GO

-- CHECKPOINT 3: Dec-2010 cohort -> M1 = 36.6, M2 = 32.3, M3 = 38.4
SELECT Cohort, MonthNumber, CohortSize, RetentionPct
FROM dbo.vw_CohortRetention
WHERE Cohort = '2010-12' AND MonthNumber <= 3
ORDER BY MonthNumber;
GO

/* ---------------------------------------------------------------------
   BLOCK 7 - Days between 1st and 2nd ORDER (order level, not line level)
   --------------------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_TimeToSecondOrder AS
WITH orders AS (
    SELECT InvoiceNo, CustomerID, MIN(InvoiceDate) AS OrderDate
    FROM dbo.Online_retail_cleaned
    GROUP BY InvoiceNo, CustomerID
),
numbered AS (
    SELECT CustomerID, OrderDate,
           ROW_NUMBER() OVER (PARTITION BY CustomerID ORDER BY OrderDate, InvoiceNo) AS OrderNumber
    FROM orders
)
SELECT
    f.CustomerID,
    f.OrderDate                                                 AS FirstOrder,
    s.OrderDate                                                 AS SecondOrder,
    DATEDIFF(DAY, f.OrderDate, s.OrderDate)                     AS DaysToSecondOrder
FROM numbered f
JOIN numbered s ON s.CustomerID = f.CustomerID
WHERE f.OrderNumber = 1 AND s.OrderNumber = 2;
GO

/* ---------------------------------------------------------------------
   BLOCK 8 - Reconciliation test: every view must add up to the same total
   --------------------------------------------------------------------- */
SELECT 'KPI'         AS sursa, Revenue                   AS venit FROM dbo.vw_KPI
UNION ALL SELECT 'Luni',       SUM(Venit_Lunar)          FROM dbo.vw_TrendLunar
UNION ALL SELECT 'Tari',       SUM(VENIT_TARA)           FROM dbo.VW_VANZARI_PE_TARI
UNION ALL SELECT 'Clienti',    SUM(Venit)                FROM dbo.vw_RetentieClienti;
-- All four rows must show 8,641,555.69.

-- Clean up helper tables once everything checks out (optional)
-- DROP TABLE dbo.stg_online_retail;
-- DROP TABLE dbo.Online_retail_typed;
