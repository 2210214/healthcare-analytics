# Business Insights — Healthcare Analytics Database

All figures below were computed directly from the provided CSV dataset containing 50 patients, 10 doctors, 200 appointments, 200 treatments, and 200 bills by replicating the final SQL logic in `03- Views.sql` and `04- Analytical_Reports.sql`.

No numbers were estimated or invented. Where the data does not support a definitive conclusion, that is stated explicitly.

---

## Executive Summary

Total billed revenue across all 200 bills: **$551,249.85**.

Of that amount:

- **$173,424.90 (31.5%)** has been collected (`Payment_Status = 'Paid'`).
- **$184,612.01 (33.5%)** is Pending.
- **$193,212.94 (35.0%)** is Failed.

Appointment outcomes are distributed across four statuses:

- Scheduled: **25.5%**
- No-show: **26.0%**
- Cancelled: **25.5%**
- Completed: **23.0%**

Only **46 of 200 appointments (23%)** are marked as completed.

**51.5%** of appointments are either No-show or Cancelled, representing a significant operational issue in this dataset.

### Important Revenue Caveat

Every appointment in the dataset, including Cancelled and No-show appointments, has a linked Treatment and Billing record.

Therefore, total billed revenue includes amounts associated with appointments that were not marked as completed.

Revenue should therefore be interpreted as **billed revenue**, not automatically as earned or collected revenue.

---

## Patient Insights

- **48 of the 50** registered patients have at least one appointment.
- **2 patients** have never had an appointment.
- Patients with an appointment history average **4.17 appointments** each.
- None of the 48 active patients has only a single visit; every patient with appointment activity is a repeat visitor in this dataset.
- The top spender is **Laura Davis (P012)**, with **$30,053.08** across 10 visits.
- The next-highest patients are **David Moore, Michael Taylor, and Michael Wilson**, each generating approximately **$21,500–$23,600** across 7 visits.

---

## Doctor Performance

The highest-revenue doctor is **Dr. Sarah Taylor (D005, Dermatology)**, generating **$82,696.48** across 29 visits and 23 distinct patients.

The top three doctors by revenue — **Sarah Taylor, Alex Davis, and David Taylor** — are also among the doctors with the highest visit volumes.

This suggests that, within this dataset, revenue differences are primarily associated with visit volume rather than clearly different treatment pricing or treatment mixes.

Doctors are concentrated across three specializations:

- Pediatrics: **5 doctors**
- Dermatology: **3 doctors**
- Oncology: **2 doctors**

---

## Revenue Insights

Monthly billed revenue ranges from a low of **$27,569.71 in December 2023** to a high of **$64,271.54 in April 2023**.

The 12 monthly totals do not show a consistent upward or downward trend.

Payment methods are relatively balanced by bill count:

- Credit Card: **37.5%**
- Insurance: **32.0%**
- Cash: **30.5%**

Credit Card transactions are slightly ahead in total billed amount, generating **$201,382.43**.

---

## Appointment Insights

Appointment statuses are relatively evenly distributed:

| Status | Percentage |
|---|---:|
| Scheduled | 25.5% |
| No-show | 26.0% |
| Cancelled | 25.5% |
| Completed | 23.0% |

No-show and Cancelled appointments together represent **51.5%** of all appointments.

This means approximately half of the appointments in the dataset do not reach a completed encounter status.

---

## Treatment Insights

The highest-revenue treatment types are:

| Treatment | Revenue | Cases |
|---|---:|---:|
| Chemotherapy | $128,855.68 | 49 |
| MRI | $116,098.16 | 36 |
| X-Ray | $110,653.67 | 41 |

Average treatment costs are relatively close across treatment types, ranging from approximately **$2,530 for ECG** to **$3,225 for MRI**.

No treatment type represents an extreme outlier in average cost within this dataset.

---

## Demographic Insights

### Gender Distribution

- Male: **31**
- Female: **19**

### Age Distribution

- 18–35: **18 patients**
- 36–50: **13 patients**
- 51–65: **12 patients**
- Over 65: **7 patients**

No patients under 18 are present in the dataset.

### Insurance Providers

Four insurance providers are represented:

- MedCare Plus: **18 patients**
- WellnessCorp: **16 patients**
- PulseSecure: **10 patients**
- HealthIndia: **6 patients**

---

## Executive KPIs

| KPI | Value |
|---|---:|
| Total Patients | 50 |
| Total Doctors | 10 |
| Total Appointments | 200 |
| Completed Appointments | 46 |
| No-show Appointments | 52 |
| Cancelled Appointments | 51 |
| Total Revenue Billed | $551,249.85 |
| Total Revenue Collected (Paid) | $173,424.90 |
| Total Revenue Pending | $184,612.01 |
| Total Revenue Failed | $193,212.94 |

### Payment Status Breakdown

| Payment Status | Amount | % of Billed Revenue |
|---|---:|---:|
| Paid | $173,424.90 | 31.5% |
| Pending | $184,612.01 | 33.5% |
| Failed | $193,212.94 | 35.0% |
| **Total** | **$551,249.85** | **100.0%** |

This makes the collection gap explicit: **68.5% of billed revenue is currently either Pending or Failed**.

---

## Business Recommendations

### 1. Investigate the No-show and Cancelled Rate

**51.5%** of appointments are either No-show or Cancelled.

This represents the clearest operational issue in the dataset.

Management should investigate possible causes such as:

- Appointment reminders
- Scheduling conflicts
- Patient availability
- Appointment lead time
- Overbooking or scheduling practices

The dataset alone cannot determine the root cause, so further operational data would be required.

### 2. Investigate the Billing Collection Gap

Only **31.5%** of billed revenue has been collected, while **68.5%** remains Pending or Failed.

Management should investigate whether this is caused by:

- Insurance-processing delays
- Failed payment attempts
- Outstanding patient balances
- Billing associated with cancelled/no-show appointments

Additional payment and insurance-processing data would be required to determine the underlying causes.

### 3. Review Billing for Non-Completed Appointments

Cancelled and No-show appointments currently have associated treatment and billing records.

Management should confirm whether this represents an actual billing policy, such as late-cancellation fees, or whether it is simply a characteristic of the dataset.

This distinction is important because it directly affects how billed revenue should be interpreted.

### 4. Re-engage Patients With No Appointment History

Two registered patients have no appointment history.

These patients can be identified directly through the existing patient analysis view and represent a small but actionable opportunity for patient engagement.

---

## Key Takeaways

- Billed revenue totals **$551K**, but only **31.5%** has been collected.
- **68.5%** of billed revenue is either Pending or Failed.
- No-show and Cancelled appointments account for **51.5%** of all appointments.
- Only **23%** of appointments are marked as Completed.
- **Dr. Sarah Taylor** is the highest-revenue doctor at **$82.7K**.
- **Chemotherapy, MRI, and X-Ray** generate the highest treatment revenue.
- Two registered patients have no appointment history.
- Billing associated with non-completed appointments is an important business-rule consideration before treating billed revenue as earned revenue.