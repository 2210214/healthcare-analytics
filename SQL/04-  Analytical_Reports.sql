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
-- FIX: this query and 10.8 below were previously tangled together into a single malformed,
-- non-executable block (a second "WITH" was nested inside this CTE's FROM clause, and this
-- CTE's own GROUP BY / closing SELECT had ended up appended after 10.8's query). Split back
-- into two independent, correct statements.

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
-- NOTE: Total_Revenue_Billed reflects every bill regardless of the linked appointment's status.
-- In this dataset every appointment (including Cancelled/No-show) has a matching Treatment and
-- Billing row, so "billed" revenue is not the same as "collected" revenue — see Total_Revenue_Collected
-- (Payment_Status = 'Paid') for the actual cash collected.

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
