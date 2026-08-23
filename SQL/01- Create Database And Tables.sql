-- ==============================================================================================================================================
                                  -- Project: Healthcare Analytics Database
                                           -- Step 1: Create Database
-- ==============================================================================================================================================
-- NOTE: Wrapped with existence checks so this script is safe to re-run (idempotent).

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
