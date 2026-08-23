
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
