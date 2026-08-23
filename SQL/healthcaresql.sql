-- =============================================================================================================================================
-- Healthcare Analytics Database — Combined Master Script
-- Generated from files 01-05. Run this single file (with SQLCMD Mode enabled) to build the entire project end-to-end.
-- =============================================================================================================================================

-- ==============================================================================================================================================
                                  -- Project: Healthcare Analytics Database
                                           -- Step 1: Create Database
-- ==============================================================================================================================================

IF DB_ID(N'Healthcare_Analytics') IS NULL
BEGIN
    CREATE DATABASE Healthcare_Analytics;
END
GO

USE Healthcare_Analytics;
GO


-- ==============================================================================================================================================
                                           -- Step 2: Create Schemas
-- ==============================================================================================================================================

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'stg')
BEGIN
    EXEC('CREATE SCHEMA stg');
END
GO


-- ==============================================================================================================================================
                                       -- Step 3: Create Staging Tables
-- ==============================================================================================================================================


-- Patients
-- ===========================================================

IF OBJECT_ID(N'stg.Patients', N'U') IS NULL
CREATE TABLE stg.Patients
(
    Patient_ID           VARCHAR(50),
    First_Name           VARCHAR(50),
    Last_Name            VARCHAR(50),
    Gender               VARCHAR(20),
    date_of_birth        DATE,
    Contact_Number       VARCHAR(20),
    Address              VARCHAR(200),
    Registration_Date    DATE,
    Insurance_Provider   VARCHAR(100),
    Insurance_Number     VARCHAR(100),
    Email                VARCHAR(100)
);

GO


-- ===========================================================
-- Doctors
-- ===========================================================

IF OBJECT_ID(N'stg.Doctors', N'U') IS NULL
CREATE TABLE stg.Doctors
(
    Doctor_ID            VARCHAR(50),
    First_Name           VARCHAR(50),
    Last_Name            VARCHAR(50),
    Specialization       VARCHAR(100),
    Phone_Number         VARCHAR(20),
    Years_Experience     INT,
    Hospital_Branch      VARCHAR(100),
    Email                VARCHAR(100)
);

GO


-- ===========================================================
-- Appointments
-- ===========================================================

IF OBJECT_ID(N'stg.Appointments', N'U') IS NULL
CREATE TABLE stg.Appointments
(
    Appointment_ID       VARCHAR(50),
    Patient_ID           VARCHAR(50),
    Doctor_ID            VARCHAR(50),
    Appointment_Date     DATE,
    Appointment_Time     TIME,
    Reason_For_Visit     VARCHAR(200),
    Status               VARCHAR(50)
);

GO


-- ===========================================================
-- Treatments
-- ===========================================================

IF OBJECT_ID(N'stg.Treatments', N'U') IS NULL
CREATE TABLE stg.Treatments
(
    Treatment_ID        VARCHAR(50),
    Appointment_ID       VARCHAR(50),
    Treatment_Type       VARCHAR(100),
    Description          VARCHAR(500),
    Cost                 DECIMAL(10,2),
    Treatment_Date       DATE
);

GO


-- ===========================================================
-- Billing
-- ===========================================================

IF OBJECT_ID(N'stg.Billing', N'U') IS NULL
CREATE TABLE stg.Billing
(
    Bill_ID              VARCHAR(50),
    Patient_ID           VARCHAR(50),
    Treatment_ID        VARCHAR(50),
    Bill_Date            DATE,
    Amount               DECIMAL(10,2),
    Payment_Method       VARCHAR(50),
    Payment_Status       VARCHAR(50)
);

GO


USE Healthcare_Analytics ;
GO

-- ==============================================================================================================================================
                                        -- Step 4: Load Data into Staging Tables
                                           -- Import CSV Files
-- ==============================================================================================================================================

:setvar CsvFolder "D:\user\Desktop\Healthcare\"

-- Clear staging tables before reload to keep the ETL re-runnable
TRUNCATE TABLE stg.Billing;
TRUNCATE TABLE stg.Treatments;
TRUNCATE TABLE stg.Appointments;
TRUNCATE TABLE stg.Doctors;
TRUNCATE TABLE stg.Patients;
GO

-- ===========================================================
-- Load Patients Data
-- ===========================================================

BULK INSERT stg.Patients
FROM '$(CsvFolder)Patients.csv'
WITH
(
    FORMAT ='CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO

-- ===========================================================
-- Load Doctors Data
-- ===========================================================

BULK INSERT stg.Doctors
FROM '$(CsvFolder)Doctors.csv'
WITH
(
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO

-- ===========================================================
-- Load Appointments Data
-- ===========================================================

BULK INSERT stg.Appointments
FROM '$(CsvFolder)Appointments.csv'
WITH
(
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO

-- ===========================================================
-- Load Treatments Data
-- ===========================================================

BULK INSERT stg.Treatments
FROM '$(CsvFolder)Treatments.csv'
WITH
(
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO

-- ===========================================================
-- Load Billing Data
-- ===========================================================

BULK INSERT stg.Billing
FROM '$(CsvFolder)Billing.csv'
WITH
(
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO


--==============================================================================================================================================
                                              --Step 5: Data Quality — Quarantine Layer
--===============================================================================================================================================


-- ===========================================================
-- 5.1 Create Quarantine ("_Errors") Tables
-- ===========================================================

IF OBJECT_ID(N'stg.Patients_Errors', N'U') IS NULL
CREATE TABLE stg.Patients_Errors
(
    Patient_ID      VARCHAR(50),
    Error_Reason    VARCHAR(200),
    Logged_At       DATETIME2 DEFAULT SYSDATETIME()
);
GO

IF OBJECT_ID(N'stg.Doctors_Errors', N'U') IS NULL
CREATE TABLE stg.Doctors_Errors
(
    Doctor_ID       VARCHAR(50),
    Error_Reason    VARCHAR(200),
    Logged_At       DATETIME2 DEFAULT SYSDATETIME()
);
GO

IF OBJECT_ID(N'stg.Appointments_Errors', N'U') IS NULL
CREATE TABLE stg.Appointments_Errors
(
    Appointment_ID  VARCHAR(50),
    Error_Reason    VARCHAR(200),
    Logged_At       DATETIME2 DEFAULT SYSDATETIME()
);
GO

IF OBJECT_ID(N'stg.Treatments_Errors', N'U') IS NULL
CREATE TABLE stg.Treatments_Errors
(
    Treatment_ID    VARCHAR(50),
    Error_Reason    VARCHAR(200),
    Logged_At       DATETIME2 DEFAULT SYSDATETIME()
);
GO

IF OBJECT_ID(N'stg.Billing_Errors', N'U') IS NULL
CREATE TABLE stg.Billing_Errors
(
    Bill_ID         VARCHAR(50),
    Error_Reason    VARCHAR(200),
    Logged_At       DATETIME2 DEFAULT SYSDATETIME()
);
GO

-- Clear previous run's quarantine log before re-evaluating (keeps this script idempotent/re-runnable)
TRUNCATE TABLE stg.Patients_Errors;
TRUNCATE TABLE stg.Doctors_Errors;
TRUNCATE TABLE stg.Appointments_Errors;
TRUNCATE TABLE stg.Treatments_Errors;
TRUNCATE TABLE stg.Billing_Errors;
GO

-- ===========================================================
-- 5.2 Patients — Duplicate / NULL / Invalid Date Checks
-- ===========================================================

INSERT INTO stg.Patients_Errors (Patient_ID, Error_Reason)
SELECT Patient_ID, 'Duplicate Patient_ID'
FROM
(
    SELECT Patient_ID,
           ROW_NUMBER() OVER (PARTITION BY Patient_ID ORDER BY (SELECT NULL)) AS rn
    FROM stg.Patients
    WHERE Patient_ID IS NOT NULL
) d
WHERE rn > 1;

INSERT INTO stg.Patients_Errors (Patient_ID, Error_Reason)
SELECT Patient_ID, 'Missing required field (ID/Name/Registration_Date)'
FROM stg.Patients
WHERE Patient_ID IS NULL
   OR First_Name IS NULL
   OR Last_Name IS NULL
   OR Registration_Date IS NULL;

INSERT INTO stg.Patients_Errors (Patient_ID, Error_Reason)
SELECT Patient_ID, 'Date_Of_Birth is in the future'
FROM stg.Patients
WHERE date_of_birth > GETDATE();
GO

-- ===========================================================
-- 5.3 Doctors — NULL ID Check
-- ===========================================================

INSERT INTO stg.Doctors_Errors (Doctor_ID, Error_Reason)
SELECT Doctor_ID, 'Missing Doctor_ID'
FROM stg.Doctors
WHERE Doctor_ID IS NULL;
GO

-- ===========================================================
-- 5.4 Appointments — Duplicate / NULL / Future Date / Orphan FK Checks
-- ===========================================================

INSERT INTO stg.Appointments_Errors (Appointment_ID, Error_Reason)
SELECT Appointment_ID, 'Duplicate Appointment_ID'
FROM
(
    SELECT Appointment_ID,
           ROW_NUMBER() OVER (PARTITION BY Appointment_ID ORDER BY (SELECT NULL)) AS rn
    FROM stg.Appointments
    WHERE Appointment_ID IS NOT NULL
) d
WHERE rn > 1;

INSERT INTO stg.Appointments_Errors (Appointment_ID, Error_Reason)
SELECT Appointment_ID, 'Missing required field (ID/Patient/Doctor/Date)'
FROM stg.Appointments
WHERE Appointment_ID IS NULL
   OR Patient_ID IS NULL
   OR Doctor_ID IS NULL
   OR Appointment_Date IS NULL;

INSERT INTO stg.Appointments_Errors (Appointment_ID, Error_Reason)
SELECT Appointment_ID, 'Appointment_Date is in the future'
FROM stg.Appointments
WHERE Appointment_Date > GETDATE();

INSERT INTO stg.Appointments_Errors (Appointment_ID, Error_Reason)
SELECT a.Appointment_ID, 'References a Patient_ID not found in stg.Patients'
FROM stg.Appointments a
LEFT JOIN stg.Patients p ON a.Patient_ID = p.Patient_ID
WHERE p.Patient_ID IS NULL;

INSERT INTO stg.Appointments_Errors (Appointment_ID, Error_Reason)
SELECT a.Appointment_ID, 'References a Doctor_ID not found in stg.Doctors'
FROM stg.Appointments a
LEFT JOIN stg.Doctors d ON a.Doctor_ID = d.Doctor_ID
WHERE d.Doctor_ID IS NULL;
GO

-- ===========================================================
-- 5.5 Treatments — Duplicate / NULL / Orphan FK Checks
-- ===========================================================

INSERT INTO stg.Treatments_Errors (Treatment_ID, Error_Reason)
SELECT Treatment_ID, 'Duplicate Treatment_ID'
FROM
(
    SELECT Treatment_ID,
           ROW_NUMBER() OVER (PARTITION BY Treatment_ID ORDER BY (SELECT NULL)) AS rn
    FROM stg.Treatments
    WHERE Treatment_ID IS NOT NULL
) d
WHERE rn > 1;

INSERT INTO stg.Treatments_Errors (Treatment_ID, Error_Reason)
SELECT Treatment_ID, 'Missing required field (ID/Appointment_ID)'
FROM stg.Treatments
WHERE Treatment_ID IS NULL
   OR Appointment_ID IS NULL;

INSERT INTO stg.Treatments_Errors (Treatment_ID, Error_Reason)
SELECT t.Treatment_ID, 'References an Appointment_ID not found in stg.Appointments'
FROM stg.Treatments t
LEFT JOIN stg.Appointments a ON t.Appointment_ID = a.Appointment_ID
WHERE a.Appointment_ID IS NULL;
GO

-- ===========================================================
-- 5.6 Billing — Negative Amount / Orphan FK Checks
-- ===========================================================

INSERT INTO stg.Billing_Errors (Bill_ID, Error_Reason)
SELECT Bill_ID, 'Negative Amount'
FROM stg.Billing
WHERE Amount < 0;

INSERT INTO stg.Billing_Errors (Bill_ID, Error_Reason)
SELECT b.Bill_ID, 'References a Patient_ID not found in stg.Patients'
FROM stg.Billing b
LEFT JOIN stg.Patients p ON b.Patient_ID = p.Patient_ID
WHERE p.Patient_ID IS NULL;

INSERT INTO stg.Billing_Errors (Bill_ID, Error_Reason)
SELECT b.Bill_ID, 'References a Treatment_ID not found in stg.Treatments'
FROM stg.Billing b
LEFT JOIN stg.Treatments t ON b.Treatment_ID = t.Treatment_ID
WHERE t.Treatment_ID IS NULL;
GO

-- ===========================================================
-- 5.7 Quarantine Summary (quick health check of the load)
-- ===========================================================

SELECT 'Patients'     AS Table_Name, COUNT(DISTINCT Patient_ID)     AS Quarantined_Rows FROM stg.Patients_Errors
UNION ALL
SELECT 'Doctors',      COUNT(DISTINCT Doctor_ID)      FROM stg.Doctors_Errors
UNION ALL
SELECT 'Appointments',  COUNT(DISTINCT Appointment_ID) FROM stg.Appointments_Errors
UNION ALL
SELECT 'Treatments',    COUNT(DISTINCT Treatment_ID)   FROM stg.Treatments_Errors
UNION ALL
SELECT 'Billing',       COUNT(DISTINCT Bill_ID)        FROM stg.Billing_Errors;
GO


-- ==============================================================================================================================================
                                            -- Step 6: Create dbo Tables
-- ==============================================================================================================================================

-- ===========================================================
-- Patients Table
-- ===========================================================

IF OBJECT_ID(N'dbo.Patients', N'U') IS NULL
CREATE TABLE dbo.Patients
(
    Patient_ID VARCHAR(20) PRIMARY KEY,
    First_Name VARCHAR(50),
    Last_Name VARCHAR(50),
    Gender VARCHAR(10),
    Date_Of_Birth DATE,
    Contact_Number VARCHAR(20),
    Address VARCHAR(200),
    Registration_Date DATE,
    Insurance_Provider VARCHAR(100),
    Insurance_Number VARCHAR(50),
    Email VARCHAR(100)
);
GO


-- ===========================================================
-- Doctors Table
-- ===========================================================

IF OBJECT_ID(N'dbo.Doctors', N'U') IS NULL
CREATE TABLE dbo.Doctors
(
    Doctor_ID VARCHAR(20) PRIMARY KEY,
    First_Name VARCHAR(50),
    Last_Name VARCHAR(50),
    Specialization VARCHAR(100),
    Phone_Number VARCHAR(20),
    Years_Experience INT,
    Hospital_Branch VARCHAR(100),
    Email VARCHAR(100)
);
GO


-- ===========================================================
-- Appointments Table
-- ===========================================================

IF OBJECT_ID(N'dbo.Appointments', N'U') IS NULL
CREATE TABLE dbo.Appointments
(
    Appointment_ID VARCHAR(20) PRIMARY KEY,
    Patient_ID VARCHAR(20),
    Doctor_ID VARCHAR(20),
    Appointment_Date DATE,
    Appointment_Time TIME,
    Reason_For_Visit VARCHAR(200),
    Status VARCHAR(50),

    CONSTRAINT FK_Appointments_Patients
    FOREIGN KEY (Patient_ID)
    REFERENCES dbo.Patients(Patient_ID),

    CONSTRAINT FK_Appointments_Doctors
    FOREIGN KEY (Doctor_ID)
    REFERENCES dbo.Doctors(Doctor_ID)
);
GO


-- ===========================================================
-- Treatments Table
-- ===========================================================

IF OBJECT_ID(N'dbo.Treatments', N'U') IS NULL
CREATE TABLE dbo.Treatments
(
    Treatment_ID VARCHAR(20) PRIMARY KEY,
    Appointment_ID VARCHAR(20),
    Treatment_Type VARCHAR(100),
    Description VARCHAR(500),
    Cost DECIMAL(10,2),
    Treatment_Date DATE,

    CONSTRAINT FK_Treatments_Appointments
    FOREIGN KEY (Appointment_ID)
    REFERENCES dbo.Appointments(Appointment_ID)
);
GO


-- ===========================================================
-- Billing Table
-- ===========================================================

IF OBJECT_ID(N'dbo.Billing', N'U') IS NULL
CREATE TABLE dbo.Billing
(
    Bill_ID VARCHAR(20) PRIMARY KEY,
    Patient_ID VARCHAR(20),
    Treatment_ID VARCHAR(20),
    Bill_Date DATE,
    Amount DECIMAL(10,2),
    Payment_Method VARCHAR(50),
    Payment_Status VARCHAR(50),

    CONSTRAINT FK_Billing_Patients
    FOREIGN KEY (Patient_ID)
    REFERENCES dbo.Patients(Patient_ID),

    CONSTRAINT FK_Billing_Treatments
    FOREIGN KEY (Treatment_ID)
    REFERENCES dbo.Treatments(Treatment_ID)
);
GO


-- ==============================================================================================================================================
                                            -- Step 7: ETL Process (Staging ➜ dbo)
                                -- Load clean data only (quarantined rows from Step 5 are excluded)
-- ==============================================================================================================================================

-- Basic staging load validation before replacing dbo data
IF NOT EXISTS (SELECT 1 FROM stg.Patients)
    THROW 50001, 'Staging Patients table is empty.', 1;

IF NOT EXISTS (SELECT 1 FROM stg.Doctors)
    THROW 50002, 'Staging Doctors table is empty.', 1;

IF NOT EXISTS (SELECT 1 FROM stg.Appointments)
    THROW 50003, 'Staging Appointments table is empty.', 1;

IF NOT EXISTS (SELECT 1 FROM stg.Treatments)
    THROW 50004, 'Staging Treatments table is empty.', 1;

IF NOT EXISTS (SELECT 1 FROM stg.Billing)
    THROW 50005, 'Staging Billing table is empty.', 1;


BEGIN TRY
    BEGIN TRANSACTION;

    DELETE FROM dbo.Billing;
    DELETE FROM dbo.Treatments;
    DELETE FROM dbo.Appointments;
    DELETE FROM dbo.Doctors;
    DELETE FROM dbo.Patients;

    -- Load Patients Data (excluding quarantined rows)
    INSERT INTO dbo.Patients
    (
        Patient_ID, First_Name, Last_Name, Gender, Date_Of_Birth,
        Contact_Number, Address, Registration_Date, Insurance_Provider,
        Insurance_Number, Email
    )
    SELECT
        Patient_ID, First_Name, Last_Name, Gender, date_of_birth,
        Contact_Number, Address, Registration_Date, Insurance_Provider,
        Insurance_Number, Email
    FROM stg.Patients p
    WHERE NOT EXISTS (SELECT 1 FROM stg.Patients_Errors e WHERE e.Patient_ID = p.Patient_ID);

    -- Load Doctors Data (excluding quarantined rows)
    INSERT INTO dbo.Doctors
    (
        Doctor_ID, First_Name, Last_Name, Specialization,
        Phone_Number, Years_Experience, Hospital_Branch, Email
    )
    SELECT
        Doctor_ID, First_Name, Last_Name, Specialization,
        Phone_Number, Years_Experience, Hospital_Branch, Email
    FROM stg.Doctors d
    WHERE NOT EXISTS (SELECT 1 FROM stg.Doctors_Errors e WHERE e.Doctor_ID = d.Doctor_ID);

    -- Load Appointments Data (excluding quarantined rows)
    INSERT INTO dbo.Appointments
    (
        Appointment_ID, Patient_ID, Doctor_ID, Appointment_Date,
        Appointment_Time, Reason_For_Visit, Status
    )
    SELECT
        Appointment_ID, Patient_ID, Doctor_ID, Appointment_Date,
        Appointment_Time, Reason_For_Visit, Status
    FROM stg.Appointments a
    WHERE NOT EXISTS (SELECT 1 FROM stg.Appointments_Errors e WHERE e.Appointment_ID = a.Appointment_ID);

    -- Load Treatments Data (excluding quarantined rows)
    INSERT INTO dbo.Treatments
    (
        Treatment_ID, Appointment_ID, Treatment_Type, Description, Cost, Treatment_Date
    )
    SELECT
        Treatment_ID, Appointment_ID, Treatment_Type, Description, Cost, Treatment_Date
    FROM stg.Treatments t
    WHERE NOT EXISTS (SELECT 1 FROM stg.Treatments_Errors e WHERE e.Treatment_ID = t.Treatment_ID);

    -- Load Billing Data (excluding quarantined rows)
    INSERT INTO dbo.Billing
    (
        Bill_ID, Patient_ID, Treatment_ID, Bill_Date, Amount, Payment_Method, Payment_Status
    )
    SELECT
        Bill_ID, Patient_ID, Treatment_ID, Bill_Date, Amount, Payment_Method, Payment_Status
    FROM stg.Billing b
    WHERE NOT EXISTS (SELECT 1 FROM stg.Billing_Errors e WHERE e.Bill_ID = b.Bill_ID);

    COMMIT TRANSACTION;
    PRINT 'ETL load committed successfully.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrLine INT = ERROR_LINE();
    PRINT 'ETL load failed and was rolled back. Line ' + CAST(@ErrLine AS VARCHAR(10)) + ': ' + @ErrMsg;
    THROW;
END CATCH
GO


-- ===========================================================
-- Verify ETL Load
-- Check Row Counts
-- ===========================================================

SELECT 'Patients' AS Table_Name, COUNT(*) AS Row_Count
FROM dbo.Patients

UNION ALL

SELECT 'Doctors', COUNT(*)
FROM dbo.Doctors

UNION ALL

SELECT 'Appointments', COUNT(*)
FROM dbo.Appointments

UNION ALL

SELECT 'Treatments', COUNT(*)
FROM dbo.Treatments

UNION ALL

SELECT 'Billing', COUNT(*)
FROM dbo.Billing;

GO


-- ==============================================================================================================================================
                                            -- Step 8: Create Indexes
                                            -- Performance Optimization
-- ==============================================================================================================================================

-- ===========================================================
-- Patients Indexes
-- ===========================================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Patients_Last_Name' AND object_id = OBJECT_ID('dbo.Patients'))
    CREATE INDEX IX_Patients_Last_Name ON dbo.Patients(Last_Name);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Patients_Insurance_Provider' AND object_id = OBJECT_ID('dbo.Patients'))
    CREATE INDEX IX_Patients_Insurance_Provider ON dbo.Patients(Insurance_Provider);
GO


-- ===========================================================
-- Doctors Indexes
-- ===========================================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Doctors_Specialization' AND object_id = OBJECT_ID('dbo.Doctors'))
    CREATE INDEX IX_Doctors_Specialization ON dbo.Doctors(Specialization);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Doctors_Hospital_Branch' AND object_id = OBJECT_ID('dbo.Doctors'))
    CREATE INDEX IX_Doctors_Hospital_Branch ON dbo.Doctors(Hospital_Branch);
GO


-- ===========================================================
-- Appointments Indexes
-- ===========================================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Appointments_Patient_ID' AND object_id = OBJECT_ID('dbo.Appointments'))
    CREATE INDEX IX_Appointments_Patient_ID ON dbo.Appointments(Patient_ID);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Appointments_Doctor_ID' AND object_id = OBJECT_ID('dbo.Appointments'))
    CREATE INDEX IX_Appointments_Doctor_ID ON dbo.Appointments(Doctor_ID);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Appointments_Date' AND object_id = OBJECT_ID('dbo.Appointments'))
    CREATE INDEX IX_Appointments_Date ON dbo.Appointments(Appointment_Date);
GO


-- ===========================================================
-- Treatments Indexes
-- ===========================================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Treatments_Appointment_ID' AND object_id = OBJECT_ID('dbo.Treatments'))
    CREATE INDEX IX_Treatments_Appointment_ID ON dbo.Treatments(Appointment_ID);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Treatments_Type' AND object_id = OBJECT_ID('dbo.Treatments'))
    CREATE INDEX IX_Treatments_Type ON dbo.Treatments(Treatment_Type);
GO


-- ===========================================================
-- Billing Indexes
-- ===========================================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Billing_Patient_ID' AND object_id = OBJECT_ID('dbo.Billing'))
    CREATE INDEX IX_Billing_Patient_ID ON dbo.Billing(Patient_ID);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Billing_Treatment_ID' AND object_id = OBJECT_ID('dbo.Billing'))
    CREATE INDEX IX_Billing_Treatment_ID ON dbo.Billing(Treatment_ID);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Billing_Date' AND object_id = OBJECT_ID('dbo.Billing'))
    CREATE INDEX IX_Billing_Date ON dbo.Billing(Bill_Date);
GO


USE Healthcare_Analytics;
GO 

-- ==============================================================================================================================================
                                            -- Step 9: Create Analysis Views
                                           
-- ==============================================================================================================================================

--9.1 Patient Analysis Views
-- ===========================================================

CREATE OR ALTER VIEW dbo.vw_Patient_Analysis
AS
WITH TreatmentTotals AS
(
    SELECT
        a.Patient_ID,
        COUNT(DISTINCT a.Appointment_ID) AS Total_Appointments,
        ISNULL(SUM(t.Cost), 0) AS Total_Treatment_Cost,
        MAX(a.Appointment_Date) AS Last_Visit_Date
    FROM dbo.Appointments a
    LEFT JOIN dbo.Treatments t
        ON a.Appointment_ID = t.Appointment_ID
    GROUP BY
        a.Patient_ID
),
BillingTotals AS
(
    SELECT
        p.Patient_ID,
        ISNULL(SUM(b.Amount), 0) AS Total_Paid_Amount
    FROM dbo.Patients p
    LEFT JOIN dbo.Billing b
        ON p.Patient_ID = b.Patient_ID
    GROUP BY
        p.Patient_ID
)
SELECT
    p.Patient_ID,
    CONCAT(p.First_Name, ' ', p.Last_Name) AS Patient_Name,
    p.Gender,
    p.Insurance_Provider,
    ISNULL(tt.Total_Appointments, 0) AS Total_Appointments,
    ISNULL(tt.Total_Treatment_Cost, 0) AS Total_Treatment_Cost,
    ISNULL(bt.Total_Paid_Amount, 0) AS Total_Paid_Amount,
    tt.Last_Visit_Date
FROM dbo.Patients p
LEFT JOIN TreatmentTotals tt
    ON p.Patient_ID = tt.Patient_ID
LEFT JOIN BillingTotals bt
    ON p.Patient_ID = bt.Patient_ID;
GO


--9.2: Doctor Performance Analysis View
-- ========================================================


CREATE OR ALTER VIEW dbo.vw_Doctor_Performance
AS
WITH DoctorVisits AS
(
    SELECT
        a.Doctor_ID,
        COUNT(DISTINCT a.Appointment_ID) AS Total_Visits
    FROM dbo.Appointments a
    GROUP BY
        a.Doctor_ID
),
DoctorTreatments AS
(
    SELECT
        a.Doctor_ID,
        COUNT(DISTINCT t.Treatment_ID) AS Total_Treatments
    FROM dbo.Appointments a
    INNER JOIN dbo.Treatments t
        ON a.Appointment_ID = t.Appointment_ID
    GROUP BY
        a.Doctor_ID
),
DoctorRevenue AS
(
    SELECT
        a.Doctor_ID,
        ISNULL(SUM(b.Amount), 0) AS Total_Revenue
    FROM dbo.Appointments a
    INNER JOIN dbo.Treatments t
        ON a.Appointment_ID = t.Appointment_ID
    INNER JOIN dbo.Billing b
        ON t.Treatment_ID = b.Treatment_ID
    GROUP BY
        a.Doctor_ID
)
SELECT
    d.Doctor_ID,
    CONCAT(d.First_Name, ' ', d.Last_Name) AS Doctor_Name,
    d.Specialization,
    ISNULL(dv.Total_Visits, 0) AS Total_Visits,
    ISNULL(dt.Total_Treatments, 0) AS Total_Treatments,
    ISNULL(dr.Total_Revenue, 0) AS Total_Revenue
FROM dbo.Doctors d
LEFT JOIN DoctorVisits dv
    ON d.Doctor_ID = dv.Doctor_ID
LEFT JOIN DoctorTreatments dt
    ON d.Doctor_ID = dt.Doctor_ID
LEFT JOIN DoctorRevenue dr
    ON d.Doctor_ID = dr.Doctor_ID;
GO


-- 9.3: Revenue Analysis View
-- ===================================================================

CREATE OR ALTER VIEW dbo.vw_Revenue_Analysis
AS

SELECT


    t.Treatment_Type,


    COUNT(DISTINCT t.Treatment_ID) AS Total_Treatments,


    SUM(b.Amount) AS Total_Revenue,


    AVG(t.Cost) AS Avg_Treatment_Cost,


    COUNT
    (
        CASE 
            WHEN b.Payment_Status = 'Paid' 
            THEN b.Bill_ID
        END
    ) AS Paid_Count,


    COUNT
    (
        CASE 
            WHEN b.Payment_Status = 'Pending'
            THEN b.Bill_ID
        END
    ) AS Pending_Count ,


	 COUNT
    (
        CASE 
            WHEN b.Payment_Status = 'Failed'
            THEN b.Bill_ID
        END
    ) AS Failed_Count ,


	CAST(
COUNT(CASE WHEN b.Payment_Status='Paid' THEN 1 END) *100.0
/
NULLIF(COUNT(b.Bill_ID), 0)
AS DECIMAL(5,2)
) AS Payment_Success_Rate




FROM dbo.Treatments t


JOIN dbo.Billing b

ON t.Treatment_ID = b.Treatment_ID


GROUP BY

    t.Treatment_Type;

GO



-- Step 9.4: Appointment Analysis View
-- ==========================================================

CREATE OR ALTER VIEW dbo.vw_Appointment_Analysis
AS

SELECT


    a.Appointment_Date,


    DATENAME(WEEKDAY,a.Appointment_Date) AS Day_Name,


    COUNT(a.Appointment_ID) AS Total_Appointments,


    COUNT
    (
        CASE 
            WHEN a.Status = 'Completed'
            THEN a.Appointment_ID
        END
    ) AS Completed_Count,


    COUNT
    (
        CASE 
            WHEN a.Status = 'Cancelled'
            THEN a.Appointment_ID
        END
    ) AS Cancelled_Count,


    COUNT
    (
        CASE 
            WHEN a.Status = 'No-show'
            THEN a.Appointment_ID
        END
    ) AS No_Show_Count,


    COUNT
    (
        CASE 
            WHEN a.Status = 'Scheduled'
            THEN a.Appointment_ID
        END
    ) AS Scheduled_Count,


    CAST
    (
        COUNT
        (
            CASE 
                WHEN a.Status = 'Completed'
                THEN a.Appointment_ID
            END
        ) * 100.0
        /
        COUNT(a.Appointment_ID)
        AS DECIMAL(5,2)
    ) AS Completion_Rate,


    CAST
    (
        COUNT
        (
            CASE 
                WHEN a.Status = 'No-show'
                THEN a.Appointment_ID
            END
        ) * 100.0
        /
        COUNT(a.Appointment_ID)
        AS DECIMAL(5,2)
    ) AS No_Show_Rate,


    CAST
    (
        COUNT
        (
            CASE 
                WHEN a.Status = 'Cancelled'
                THEN a.Appointment_ID
            END
        ) * 100.0
        /
        COUNT(a.Appointment_ID)
        AS DECIMAL(5,2)
    ) AS Cancellation_Rate


FROM dbo.Appointments a


GROUP BY

    a.Appointment_Date;

GO
USE Healthcare_Analytics;
GO 

-- ==============================================================================================================================================
                                            --Step 10 : Analytical_Reports
-- ==============================================================================================================================================


-- 10.1: Top Doctors by Revenue Ranking
-- =======================================================


WITH DoctorRevenue AS
(

SELECT

    d.Doctor_ID,

    CONCAT(d.First_Name,' ',d.Last_Name) AS Doctor_Name,

    d.Specialization,


    COUNT(DISTINCT a.Appointment_ID) AS Total_Visits,


    COUNT(DISTINCT a.Patient_ID) AS Total_Patients,


    SUM(b.Amount) AS Total_Revenue


FROM dbo.Doctors d


JOIN dbo.Appointments a
ON d.Doctor_ID = a.Doctor_ID


JOIN dbo.Treatments t
ON a.Appointment_ID = t.Appointment_ID


JOIN dbo.Billing b
ON t.Treatment_ID = b.Treatment_ID


GROUP BY

    d.Doctor_ID,
    d.First_Name,
    d.Last_Name,
    d.Specialization

)


SELECT

    *,

    DENSE_RANK() OVER
    (
        ORDER BY Total_Revenue DESC
    ) AS Revenue_Rank


FROM DoctorRevenue;


--10.2: Top Patients by Spending
-- ===========================================================


WITH PatientSpending AS
(

SELECT


    p.Patient_ID,


    CONCAT(p.First_Name,' ',p.Last_Name) AS Patient_Name,


    COUNT(DISTINCT a.Appointment_ID) AS Total_Visits,


    COUNT(DISTINCT t.Treatment_ID) AS Total_Treatments,


    SUM(b.Amount) AS Total_Spending,

	CAST ( SUM(b.Amount)/COUNT(DISTINCT a.Appointment_ID) AS DECIMAL (10,2)) AS Average_Spend

FROM dbo.Patients p


JOIN dbo.Appointments a

ON p.Patient_ID = a.Patient_ID


JOIN dbo.Treatments t

ON a.Appointment_ID = t.Appointment_ID


JOIN dbo.Billing b

ON t.Treatment_ID = b.Treatment_ID



GROUP BY

    p.Patient_ID,
    p.First_Name,
    p.Last_Name

)



SELECT


    *,


    DENSE_RANK() OVER
    (
        ORDER BY Total_Spending DESC
    ) AS Spending_Rank



FROM PatientSpending;

GO



--10.3: Monthly Revenue Trend Analysis
-- ===========================================================

WITH MonthlyRevenue AS
(

SELECT


    YEAR(b.Bill_Date) AS Revenue_Year,


    MONTH(b.Bill_Date) AS Revenue_Month,

	DATENAME(MONTH,b.Bill_Date) AS Revenue_Month_Name,

    SUM(b.Amount) AS Total_Revenue


FROM dbo.Billing b


GROUP BY

    YEAR(b.Bill_Date),
    MONTH(b.Bill_Date),
	DATENAME(MONTH,b.Bill_Date)

)



SELECT


    Revenue_Year,

    Revenue_Month,

	Revenue_Month_Name,

    Total_Revenue,


    LAG(Total_Revenue) OVER ( ORDER BY Revenue_Year, Revenue_Month )
                     
					 AS Previous_Month_Revenue ,


   ( Total_Revenue 

             - LAG(Total_Revenue) OVER (  ORDER BY Revenue_Year, Revenue_Month )
                  
				  ) AS  Revenue_Difference ,
       
    CAST
    (
      (   Total_Revenue - LAG(Total_Revenue) OVER ( ORDER BY Revenue_Year, Revenue_Month ) )

               * 100.0 / NULLIF (
                              LAG(Total_Revenue) OVER (  ORDER BY Revenue_Year, Revenue_Month ) , 0)
        
		AS DECIMAL(10,2) ) AS Growth_Percentage

        

    


FROM MonthlyRevenue;


--10.4: Patient Retention Analysis
-- =========================================================


WITH PatientVisits AS
(

SELECT


    p.Patient_ID,


    CONCAT(p.First_Name,' ',p.Last_Name) AS Patient_Name,


    a.Appointment_Date,


    LAG(a.Appointment_Date) OVER
    (
        PARTITION BY p.Patient_ID
        ORDER BY a.Appointment_Date
    ) AS Previous_Visit_Date



FROM dbo.Patients p


JOIN dbo.Appointments a

ON p.Patient_ID = a.Patient_ID

)



SELECT


    Patient_ID,


    Patient_Name,


    Appointment_Date,


    Previous_Visit_Date,


    CASE

        WHEN Previous_Visit_Date IS NULL

        THEN 'New Patient'


        ELSE 'Returning Patient'

    END AS Patient_Status



FROM PatientVisits;


GO




-- 10.5: Patient Segmentation
-- ============================================================

WITH PatientMetrics AS
(

SELECT

    p.Patient_ID,

    CONCAT(p.First_Name,' ',p.Last_Name) AS Patient_Name,


    COUNT(DISTINCT a.Appointment_ID) AS Total_Visits,


    COUNT(DISTINCT t.Treatment_ID) AS Total_Treatments,


    SUM(b.Amount) AS Total_Spending,


    MAX(a.Appointment_Date) AS Last_Visit_Date



FROM dbo.Patients p

JOIN dbo.Appointments a
ON p.Patient_ID = a.Patient_ID


JOIN dbo.Treatments t
ON a.Appointment_ID = t.Appointment_ID


JOIN dbo.Billing b
ON t.Treatment_ID = b.Treatment_ID


GROUP BY

    p.Patient_ID,
    p.First_Name,
    p.Last_Name

),



PatientAnalysis AS

(

SELECT

    *,


    AVG(Total_Spending) OVER() AS Avg_Patient_Spending,


    DENSE_RANK() OVER
    (
        ORDER BY Total_Spending DESC
    ) AS Spending_Rank


FROM PatientMetrics

)



SELECT


    Patient_ID,

    Patient_Name,

    Total_Visits,

    Total_Treatments,

    Total_Spending,

    Avg_Patient_Spending,

    Spending_Rank,


    CASE

        WHEN Total_Visits = 1

        THEN 'One-Time Patient'


        WHEN  Total_Visits >=3 AND  Total_Spending > Avg_Patient_Spending

        THEN 'VIP Patient'


        ELSE 'Regular Patient'


    END AS Patient_Segment



FROM PatientAnalysis ;

GO


--10.6: Doctor Performance Analysis
-- ============================================================


WITH DoctorMetrics AS
(

SELECT


    d.Doctor_ID,


    CONCAT(d.First_Name,' ',d.Last_Name) AS Doctor_Name,


    d.Specialization,


    COUNT(DISTINCT a.Patient_ID) AS Total_Patients,


    COUNT(DISTINCT a.Appointment_ID) AS Total_Visits,


    SUM(b.Amount) AS Total_Revenue,


   CAST ( AVG(t.Cost) AS decimal (10,2)) AS Avg_Treatment_Cost



FROM dbo.Doctors d


JOIN dbo.Appointments a

ON d.Doctor_ID = a.Doctor_ID


JOIN dbo.Treatments t

ON a.Appointment_ID = t.Appointment_ID


JOIN dbo.Billing b

ON t.Treatment_ID = b.Treatment_ID



GROUP BY

    d.Doctor_ID,
    d.First_Name,
    d.Last_Name,
    d.Specialization

)



SELECT


    *,


    DENSE_RANK() OVER
    (
        ORDER BY Total_Revenue DESC
    ) AS Revenue_Rank



FROM DoctorMetrics;


GO


-- 10.7: Treatment Performance Analysis
-- =============================================================


WITH TreatmentMetrics AS
(

SELECT


    t.Treatment_Type,


    COUNT(DISTINCT t.Treatment_ID) AS Total_Treatments,


    SUM(b.Amount) AS Total_Revenue,


    CAST (AVG(t.Cost) AS DECIMAL (10,2)) AS Avg_Treatment_Cost



FROM dbo.Treatments t


JOIN dbo.Billing b

ON t.Treatment_ID = b.Treatment_ID


GROUP BY

    t.Treatment_Type

)



SELECT


    Treatment_Type,


    Total_Treatments,


    Total_Revenue,


    Avg_Treatment_Cost,


    DENSE_RANK() OVER
    (
        ORDER BY Total_Revenue DESC
    ) AS Revenue_Rank



FROM TreatmentMetrics;


GO


-- 10.8: Appointment Status Analysis
-- ==================================================

WITH AppointmentStatus AS
(

SELECT


    Status,


    COUNT(*) AS Total_Appointments



FROM dbo.Appointments


GROUP BY

    Status

)



SELECT


    Status,


    Total_Appointments,


    SUM(Total_Appointments) OVER() AS Overall_Appointments,


    CAST
    (
        Total_Appointments * 100.0
        /
        NULLIF(SUM(Total_Appointments) OVER(), 0)

        AS DECIMAL(5,2)

    ) AS Status_Percentage



FROM AppointmentStatus;


GO



-- 10.9: Payment Methods Percentage
-- ==================================================

SELECT
    Payment_Method,

    COUNT(*) AS Bill_Count,

    SUM(Amount) AS Total_Amount,

    CAST(100.0 * COUNT(*) / NULLIF((SELECT COUNT(*) FROM dbo.Billing), 0) AS DECIMAL(5,1)) AS Pct_Of_Bills

FROM dbo.Billing

GROUP BY Payment_Method

ORDER BY Total_Amount DESC;
GO


-- 10.10: Patient distribution by age group and gender
-- ==================================================

WITH PatientAges AS
(
    SELECT
        Patient_ID,
        Gender,
        Date_Of_Birth,
        DATEDIFF(YEAR, Date_Of_Birth, GETDATE())
        -
        CASE
            WHEN DATEADD(
                    YEAR,
                    DATEDIFF(YEAR, Date_Of_Birth, GETDATE()),
                    Date_Of_Birth
                 ) > CAST(GETDATE() AS DATE)
            THEN 1
            ELSE 0
        END AS Age
    FROM dbo.Patients
)
SELECT
    CASE
        WHEN Age < 18 THEN 'Under 18'
        WHEN Age BETWEEN 18 AND 35 THEN '18-35'
        WHEN Age BETWEEN 36 AND 50 THEN '36-50'
        WHEN Age BETWEEN 51 AND 65 THEN '51-65'
        ELSE 'Over 65'
    END AS Age_Group,
    Gender,
    COUNT(*) AS Patient_Count
FROM PatientAges
GROUP BY
    CASE
        WHEN Age < 18 THEN 'Under 18'
        WHEN Age BETWEEN 18 AND 35 THEN '18-35'
        WHEN Age BETWEEN 36 AND 50 THEN '36-50'
        WHEN Age BETWEEN 51 AND 65 THEN '51-65'
        ELSE 'Over 65'
    END,
    Gender
ORDER BY
    Age_Group,
    Gender;
GO


-- 10.11: KPI Summary
-- ==================================================

SELECT
    (SELECT COUNT(*) FROM dbo.Patients)                                   AS Total_Patients,
    (SELECT COUNT(*) FROM dbo.Doctors)                                    AS Total_Doctors,
    (SELECT COUNT(*) FROM dbo.Appointments)                               AS Total_Appointments,
    (SELECT COUNT(*) FROM dbo.Appointments WHERE Status = 'Completed')    AS Completed_Appointments,
    (SELECT COUNT(*) FROM dbo.Appointments WHERE Status = 'No-show')      AS No_Show_Appointments,
    (SELECT COUNT(*) FROM dbo.Appointments WHERE Status = 'Cancelled')    AS Cancelled_Appointments,
    (SELECT SUM(Amount) FROM dbo.Billing)                                 AS Total_Revenue_Billed,
    (SELECT SUM(Amount) FROM dbo.Billing WHERE Payment_Status = 'Paid')   AS Total_Revenue_Collected,
    (SELECT SUM(Amount) FROM dbo.Billing WHERE Payment_Status = 'Pending') AS Total_Revenue_Pending;
GO


USE Healthcare_Analytics
GO


-- ==============================================================================================================================================
                            -- Step 11: Create Stored Procedures
-- ==============================================================================================================================================
-
-- 11.1 : Stored Procedure - Patient Analysis
-- =======================================================

CREATE OR ALTER PROCEDURE dbo.sp_Patient_Analysis
    @Patient_ID VARCHAR(20)
AS
BEGIN

    SELECT

        p.Patient_ID,

        CONCAT(p.First_Name,' ',p.Last_Name) AS Patient_Name,

        COUNT(DISTINCT a.Appointment_ID) AS Total_Visits,

        COUNT(DISTINCT t.Treatment_ID) AS Total_Treatments,

        SUM(b.Amount) AS Total_Paid_Amount,

        MAX(a.Appointment_Date) AS Last_Visit_Date

    FROM dbo.Patients p

    JOIN dbo.Appointments a
    ON p.Patient_ID = a.Patient_ID

    JOIN dbo.Treatments t
    ON a.Appointment_ID = t.Appointment_ID

    JOIN dbo.Billing b
    ON t.Treatment_ID = b.Treatment_ID

    WHERE p.Patient_ID = @Patient_ID

    GROUP BY
        p.Patient_ID,
        p.First_Name,
        p.Last_Name;

END;
GO

-- Usage example:
-- EXEC dbo.sp_Patient_Analysis 'P012';


-- ==============================================================================================================================================
                         -- Step 11.2: Stored Procedure - Doctor Performance
-- ==============================================================================================================================================

CREATE OR ALTER PROCEDURE dbo.sp_Doctor_Performance
    @Doctor_ID VARCHAR(20)
AS
BEGIN

    SELECT

        d.Doctor_ID,

        CONCAT(d.First_Name,' ',d.Last_Name) AS Doctor_Name,

        d.Specialization,

        COUNT(DISTINCT a.Patient_ID) AS Total_Patients,

        COUNT(DISTINCT a.Appointment_ID) AS Total_Visits,

        SUM(b.Amount) AS Total_Revenue,

        AVG(t.Cost) AS Avg_Treatment_Cost

    FROM dbo.Doctors d

    JOIN dbo.Appointments a
    ON d.Doctor_ID = a.Doctor_ID

    JOIN dbo.Treatments t
    ON a.Appointment_ID = t.Appointment_ID

    JOIN dbo.Billing b
    ON t.Treatment_ID = b.Treatment_ID

    WHERE d.Doctor_ID = @Doctor_ID

    GROUP BY
        d.Doctor_ID,
        d.First_Name,
        d.Last_Name,
        d.Specialization;

END;
GO

-- Usage example:
-- EXEC dbo.sp_Doctor_Performance 'D005';


-- 11.3: Stored Procedure - Revenue Report
-- ===========================================================

CREATE OR ALTER PROCEDURE dbo.sp_Revenue_Report
    @Start_Date DATE,
    @End_Date DATE
AS
BEGIN

    SELECT

        @Start_Date AS Start_Date,
        @End_Date AS End_Date,
        COUNT(Bill_ID) AS Total_Bills,
        SUM(Amount) AS Total_Revenue,
        AVG(Amount) AS Average_Bill_Amount,
        MAX(Amount) AS Highest_Bill,
        MIN(Amount) AS Lowest_Bill

    FROM dbo.Billing

    WHERE Bill_Date BETWEEN @Start_Date AND @End_Date;

END;
GO

-- Usage example:
-- EXEC dbo.sp_Revenue_Report @Start_Date = '2023-01-01', @End_Date = '2023-06-30';
