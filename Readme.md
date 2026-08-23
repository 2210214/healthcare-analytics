# Healthcare Analytics — SQL Server Relational Database & Analytics

A SQL Server analytics project that transforms raw healthcare operational data into a validated relational database and reusable business reporting layer.

The project covers the full workflow from CSV ingestion and data quality validation through relational modeling, analytical views, reporting queries, and stored procedures.

## Project Overview

This project demonstrates a small-scale healthcare reporting pipeline:

**CSV Source Data → Staging Layer (stg) → Data Quality Validation & Quarantine → Normalized Relational Database (dbo) → Views & Analytical Reports → Stored Procedures & Business KPIs**

The dataset contains:

- 50 patients
- 10 doctors
- 200 appointments
- 200 treatments
- 200 bills

The project is intentionally designed as a normalized relational database, not a data warehouse. It uses a single SQL Server database with staging, validation, and reporting layers.

## Business Problem

A healthcare provider maintains operational information across separate CSV files containing patients, doctors, appointments, treatments, and billing.

Without a structured database and reusable analytical queries, answering basic business questions requires manual spreadsheet work.

This project provides a reliable SQL-based reporting foundation for answering questions such as:

- Which doctors generate the highest billed revenue?
- Which patients generate the most spending?
- How is billed revenue changing over time?
- What percentage of appointments are completed, cancelled, or no-show?
- Which treatment types generate the most revenue?
- How much billed revenue has been collected versus remaining pending?
- What does the patient population look like by age and gender?

## Objectives

- Load and validate raw healthcare CSV data before it reaches the reporting layer.
- Build a normalized relational database with enforced primary and foreign keys.
- Implement data-quality checks and quarantine invalid records.
- Create reusable SQL views for recurring business analysis.
- Build analytical reports using CTEs, window functions, ranking, and conditional aggregation.
- Create parameterized stored procedures for reusable reporting.
- Produce business insights directly from the validated dataset.

## Architecture

| Layer | Schema | Purpose |
|---|---|---|
| Staging | `stg` | Raw CSV data loaded through `BULK INSERT` |
| Data Quality / Quarantine | `stg` | Invalid records are logged with error reasons |
| Core Database | `dbo` | Clean normalized tables with PK/FK constraints |
| Analytics | `dbo` | Views, reports, and stored procedures |

Invalid records are quarantined rather than deleted, allowing the data-quality process to preserve the original problem information.

## Data Model

```text
Patients
   │
   ├──< Appointments >── Doctors
   │          │
   │          └──< Treatments
   │
   └──────────────< Billing
```

The current dataset contains:

- 200 appointments
- 200 treatments
- 200 bills

The validated dataset contains no duplicate or orphaned relationships.

## Core Tables

| Table | Purpose |
|---|---|
| `Patients` | Patient demographic and insurance information |
| `Doctors` | Doctor specialization, experience, and branch |
| `Appointments` | Patient appointments and appointment status |
| `Treatments` | Treatments associated with appointments |
| `Billing` | Treatment billing, payment method, and payment status |

## Data Quality & Validation

The staging layer performs validation before records are loaded into the core database.

Checks include:

- Duplicate primary keys
- Missing required fields
- Invalid or future dates
- Negative billing amounts
- Orphaned foreign keys

Invalid records are written to dedicated quarantine tables with:

- `ID`
- `Error_Reason`
- `Logged_At`

The provided dataset passed the implemented validation checks with no invalid records remaining in the quarantine layer.

## ETL Workflow

### Extract & Load

`BULK INSERT` loads the five CSV files into their corresponding staging tables.

The CSV directory is controlled through a SQLCMD variable rather than being hardcoded throughout the scripts.

### Validate

Staging data is checked for structural, financial, date, and referential-integrity issues.

### Quarantine

Records that fail validation are logged in the corresponding `_Errors` tables and excluded from the core load.

### Transform & Load

Validated records are loaded from `stg` into the normalized `dbo` tables.

The migration uses transaction control with `TRY...CATCH` so a failed load can be rolled back.

### Verify

Post-load row-count checks verify that the core tables were loaded as expected.

## Database Design

The normalized database uses:

- Primary keys
- Foreign keys
- Non-clustered indexes
- Referential integrity
- Transaction-controlled loading
- Re-runnable staging loads

Foreign-key relationships include:

- `Appointments → Patients`
- `Appointments → Doctors`
- `Treatments → Appointments`
- `Billing → Patients`
- `Billing → Treatments`

## Analytical SQL

### Views

The project includes analytical views for:

#### Patient Analysis

- Visits
- Treatment cost
- Billed amount
- Last visit date

#### Doctor Performance

- Visits
- Treatments
- Revenue by doctor

#### Revenue Analysis

- Revenue by treatment type
- Payment success rate

#### Appointment Analysis

- Completion rate
- Cancellation rate
- No-show rate

### Analytical Reports

The reporting layer uses SQL techniques including:

- CTEs
- Window functions
- `DENSE_RANK`
- `LAG`
- `SUM() OVER()`
- Conditional aggregation

Reports include:

- Top doctors by revenue
- Top patients by spending
- Monthly revenue trends
- Month-over-month growth
- New vs. returning patients
- Patient segmentation
- Doctor performance ranking
- Treatment performance
- Appointment status distribution
- Payment method analysis
- Patient demographics
- Executive KPI summary

## Stored Procedures

### `sp_Patient_Analysis`

Returns a patient-level summary including visits, treatments, and spending.

### `sp_Doctor_Performance`

Returns doctor-level visit and revenue performance.

### `sp_Revenue_Report`

Returns billing performance for a specified date range.

## Key KPIs

The project calculates:

- Total Patients
- Total Doctors
- Total Appointments
- Completed Appointments
- No-Show Appointments
- Cancelled Appointments
- Total Billed Revenue
- Total Revenue Collected
- Total Revenue Pending

## Revenue Definition

The dataset contains billing records for cancelled and no-show appointments.

Therefore, the project's revenue figures represent **billed revenue**, not automatically earned revenue.

Collected revenue is defined as bills where:

```text
Payment_Status = 'Paid'
```

This distinction is preserved intentionally because changing the revenue definition based on appointment status would represent a business-rule decision rather than a data-quality correction.

## Business Insights

The analysis provides visibility into:

- Doctor revenue performance
- Patient spending and value
- Revenue trends
- Appointment outcomes
- Treatment performance
- Payment collection
- Patient retention
- Patient demographics

Detailed findings and data-backed conclusions are available in `Insights.md`.

## Skills Demonstrated

- T-SQL
- SQL Server
- Relational database design
- Staging-based ETL
- Data quality validation
- Data quarantine
- Primary and foreign key constraints
- Index design
- SQL Views
- CTEs
- Window Functions
- `DENSE_RANK`
- `LAG`
- Conditional Aggregation
- Stored Procedures
- Transaction Control
- Business KPI development
- SQL reporting and analytics
- Data validation and debugging

## Repository Structure

```text
Healthcare-Analytics/

├── SQL/
│   ├── 01- Create Database And Tables.sql
│   ├── 02-Load data , Create dbo.tables And Transform dat .sql
│   ├── 03- Views.sql
│   ├── 04- Analytical_Reports.sql
│   ├── 05- Stored Procedures.sql
│   └── healthcaresql.sql
│
├── Dataset/
│   ├── Patients.csv
│   ├── Doctors.csv
│   ├── Appointments.csv
│   ├── Treatments.csv
│   └── Billing.csv
│
├── Insights.md
│
└── README.md
```

## Setup & Usage

### Prerequisites

- Microsoft SQL Server 2017+ or Azure SQL Database
- SQL Server Management Studio (SSMS) or Azure Data Studio
- SQLCMD Mode enabled in SSMS

### Steps

1. Place the five CSV files in a location accessible by SQL Server.
2. Open `02-Load data , Create dbo.tables And Transform dat .sql`.
3. Update the `CsvFolder` SQLCMD variable with the local CSV path.
4. Run the scripts individually in the following order:

```text
01 → 02 → 03 → 04 → 05
```

Alternatively, execute:

```text
healthcaresql.sql
```

The master script contains the project scripts in execution order.

5. Review the data-quality and quarantine results after loading.
6. Query the analytical views and reports to explore the business results.

## Example Queries

```sql
SELECT *
FROM dbo.vw_Doctor_Performance
ORDER BY Total_Revenue DESC;
```

```sql
EXEC dbo.sp_Patient_Analysis 'P012';
```

```sql
EXEC dbo.sp_Doctor_Performance 'D005';
```

```sql
EXEC dbo.sp_Revenue_Report
    @Start_Date = '2023-01-01',
    @End_Date = '2023-06-30';
```

## Portfolio Note

This project demonstrates how raw operational healthcare data can be transformed into a validated relational database and reusable analytical reporting layer using SQL Server.

It focuses on data quality, relational modeling, ETL workflow design, analytical SQL, and business-oriented reporting rather than relying on one-off queries.

## Author

**Eslam Eid**