
USE Healthcare_Analytics
GO


-- ==============================================================================================================================================
                            -- Step 11: Create Stored Procedures
-- ==============================================================================================================================================
-- NOTE (Improvement): switched to CREATE OR ALTER so this script can be re-run without dropping
-- procedures first. The sample EXEC calls are kept as commented-out "usage examples" instead of
-- running automatically, since they reference specific IDs (e.g. 'P012') that may not exist in your data.

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
