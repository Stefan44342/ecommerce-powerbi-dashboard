# E-Commerce Growth Analytics: Revenue, Retention & Cohorts

End-to-end analytics project on one year of transactions from a UK online retailer (Dec 2010 – Dec 2011, ~400K order lines, currency **GBP**):
**Python** (EDA & cleaning) → **SQL Server** (validated analytical layer, window functions, cohort retention) → **Power BI** (2-page executive report).

---

## 📊 Dashboard

### Page 1: Performance
![Performance](Proiect_Growth_Analytics/Performance_Dashboard.png)

### Page 2: Customer Retention
![Customer Retention](Proiect_Growth_Analytics/Dashboard_Retention.png)

---

## 📈 Key results

| KPI | Value |
|---|---|
| Revenue | **£8.64M** |
| Orders | **18,530** |
| Customers | **4,337** |
| AOV (revenue / distinct orders) | **£466** |
| Orders per customer | **4.3** |

## 💡 Insights

1. **Repeat customers are the business.** 65.6% of customers ordered more than once, and they generated **93.8% of revenue**. The top 10% of customers alone bring **60% of revenue**.
2. **Cohort retention:** on average **~21%** of a monthly cohort orders again the next month, and retention then **stabilises at 20–30%** instead of decaying to zero: a solid repeat base.
3. **Reading the cohorts carefully:**
   - The Dec-2010 cohort stays at 35–40% every month. These are mostly existing customers captured when the data starts (left-censoring), not truly new ones.
   - The last diagonal of the matrix (Dec 2011) looks low only because that month has 9 days of data.
4. **Repeat cycle:** the **median** time between a customer's 1st and 2nd order is **50 days** (the mean is 76, pulled up by a few customers returning after many months). That's the natural window for a reactivation campaign.
5. **Seasonality:** Sep–Nov 2011 produced **36%** of the year's revenue. November peaked at £1.16M, driven by **more orders** (+38% vs October), not bigger baskets: AOV actually fell from £537 to £435.
6. **Concentration:** the UK makes up **81.5%** of revenue, followed by the Netherlands, Ireland, Germany and France.
7. **Timing:** no orders on Saturdays (the store doesn't trade then). Thursday is the strongest day, and late morning to early afternoon is the peak.

---

## 🧹 Data preparation

**Python (`EDA.py`):** removed rows without a customer ID, cancellation invoices (`C…`), and non-positive quantities or prices; added revenue and date features.

**SQL Server:**
- The CSV is loaded into a staging table as text and converted explicitly with `TRY_CONVERT`, so number formats don't depend on regional settings.
- Exact duplicate rows are removed with `ROW_NUMBER()`.
- Two very large orders (80,995 and 74,215 units) that were cancelled in the source data are excluded.
- Non-product codes (postage, bank charges, manual adjustments) are flagged and excluded from product rankings.
- The last month (Dec 2011, 9 days) is flagged as partial.
- Validation queries check row counts and totals, and a reconciliation query confirms that every view adds up to the same revenue.

---

## 🏗️ Architecture

```
Online_retail_cleaned.csv (Python output)
        │  BULK INSERT (text)
        ▼
stg_online_retail  ──TRY_CONVERT──►  Online_retail_typed  ──dedup + clean──►  Online_retail_cleaned
                                                                                  │
                                                                                  ▼
                                                                         analytical views
                                                                                  │
                                                                                  ▼
                                                                          Power BI report
```

**SQL views**
- `vw_KPI`: headline KPIs (revenue, orders, customers, AOV)
- `vw_TrendLunar`: monthly revenue, orders, AOV, partial-month flag
- `vw_TrendMoM`: month-over-month growth (`LAG`)
- `vw_TopProduse`: product ranking
- `VW_VANZARI_PE_TARI`: revenue and share by country
- `vw_RetentieClienti`: one-time vs repeat buyers, share of customers and revenue
- `vw_CohortRetention`: monthly cohort retention matrix
- `vw_TimeToSecondOrder`: days from 1st to 2nd order (`ROW_NUMBER`)

**Files**
- `EDA.py`: data cleaning and feature engineering
- `SQL_Scripts.sql`: SQL layer (tables, views, validation)
- `E-Commerce_Executive_Dashboard_v2.pbix`: Power BI report

---

## 🚀 How to run

1. Run `EDA.py` on the raw dataset to produce `Online_retail_cleaned.csv`.
2. In SSMS, update the CSV path in the `BULK INSERT` statement and run `SQL_Scripts.sql`.
3. Open the `.pbix` file and refresh the connection to your local SQL Server instance.

## ⚠️ Limitations

- Revenue is **gross**: cancellations and returns were removed rather than netted against the original orders.
- Many customers appear to be wholesalers, so B2C benchmarks don't apply directly.
- The data covers only 12 months, so year-over-year seasonality can't be separated from growth.
