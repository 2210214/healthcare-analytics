
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