# 🚀 E-Commerce End-to-End Analytics & Executive Dashboard

An end-to-end Data Analytics and Business Intelligence project that transforms raw retail transaction data into actionable executive insights. This project covers the full data lifecycle: Exploratory Data Analysis (EDA) in Python, database modeling and optimization in SQL Server, and interactive executive reporting in Power BI.

---

## 🏗️ Project Architecture & Workflow


### 1. Data Preparation & EDA (Python)
* **Exploratory Data Analysis (EDA):** Inspected raw transaction records to understand data distribution, identify missing values, and handle data anomalies (e.g., negative quantities/returns, null customer IDs).
* **Feature Engineering & Cleaning:** Processed dates into structured temporal features (YearMonth, Day of the Week, Hour), calculated total revenue per line item (`Quantity * UnitPrice`), and prepared a clean baseline dataset (`Online_retail_cleaned`).

### 2. Database Optimization & ETL (SQL Server)
To ensure lightning-fast dashboard performance and eliminate heavy load in Power BI, custom SQL views were created for specific business aggregations:
* `vw_TrendLunar`: Aggregates monthly revenue, total orders, and Average Order Value (AOV).
* `vw_TopProduse`: Identifies top-performing products by total revenue and sales volume.
* `vw_VanzariPeTari`: Calculates country-level revenue breakdown and market share percentages.
* `vw_RetentieClienti`: Segments customers into one-time buyers versus repeat customers based on order frequency.

### 3. Data Visualization & UI/UX (Power BI)
* Built an executive-level single-page dashboard designed for C-level stakeholders.
* Implemented dynamic formatting, clean card layouts, custom tooltips, and global cross-filtering (Slicers).

---

## 📊 Key Dashboard Features & Business Insights

### 🔹 1. Executive KPI Cards
* **Total Revenue:** ~$821.5M global earnings.
* **Total Orders:** ~18.5K transactions processed.
* **AOV (Average Order Value):** ~2.14K per transaction.
* **Unique Customers:** ~4.3K active buyers.

### 🌍 2. Geographic Dominance (Bubble Map)
* **Insight:** Sales distribution shows an overwhelming concentration in the **United Kingdom**, accounting for the vast majority (~82%) of total revenue. Other European markets (Netherlands, EIRE, Germany, France) form secondary clusters.

### 📈 3. Temporal Trends & Seasonality (Line Chart)
* **Insight:** Monthly revenue trends reveal a massive, aggressive surge in sales volume during **Quarter 4 (specifically November and December)**, driven by seasonal holiday shopping and year-end retail peaks.

### 👥 4. Customer Retention & CRM (Donut Chart)
* **Insight:** Customer segmentation highlights a strong loyalty baseline, with **~65.58% repeat buyers** compared to **~34.42% one-time buyers**, indicating healthy long-term customer engagement and brand stickiness.

### 🏆 5. Product Performance (Bar Chart)
* **Insight:** The product catalog features clear winners. Most notably, **Product ID `23843`** stands out as the ultimate top-performing best-seller, driving significant revenue compared to the rest of the catalog.
