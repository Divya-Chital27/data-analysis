<div align="center">

# 🧪 Data Analysis Playground

### One problem, two toolkits — every dataset here is cleaned and explored in *both* Pandas and pure SQL.

![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Pandas](https://img.shields.io/badge/Pandas-150458?style=for-the-badge&logo=pandas&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=for-the-badge&logo=mysql&logoColor=white)
![NumPy](https://img.shields.io/badge/NumPy-013243?style=for-the-badge&logo=numpy&logoColor=white)
![Seaborn](https://img.shields.io/badge/Seaborn-4C72B0?style=for-the-badge)

<br>

<table>
<tr>
<td align="center">🗂️<br><b>5</b><br>projects</td>
<td align="center">🐍<br><b>2</b><br>languages</td>
<td align="center">📊<br><b>980+</b><br>rows cleaned</td>
<td align="center">🧹<br><b>4</b><br>cleaning pipelines</td>
<td align="center">🔍<br><b>13+</b><br>business questions solved</td>
</tr>
</table>

</div>

<br>

> *Knowing when to reach for a DataFrame and when to reach for a `JOIN` is half the job of being an analyst — this repo is where that instinct gets built, one messy dataset at a time.*

---

## 🗺️ What's Inside

<table>
<tr>
<th align="left">Project</th>
<th align="left">What it does</th>
<th align="left">Toolkit</th>
</tr>
<tr>
<td>📱&nbsp;<b>Smartphone EDA</b></td>
<td>Pricing skew, brand market share, spec-vs-price relationships, KNN missing-value imputation across 980 phone listings</td>
<td><code>Python</code> <code>Pandas</code> <code>Seaborn</code> <code>Scikit-learn</code></td>
</tr>
<tr>
<td>💻&nbsp;<b>Laptop Data Cleaning</b></td>
<td>Turns messy free-text specs — <code>"8GB"</code>, <code>"1.5Kg"</code>, <code>"256GB SSD + 1TB HDD"</code> — into clean, typed columns</td>
<td><code>SQL</code></td>
</tr>
<tr>
<td>💻&nbsp;<b>Laptop EDA</b></td>
<td>Price distribution, brand comparisons, three missing-value strategies compared, feature engineering (PPI, screen-size buckets)</td>
<td><code>SQL</code></td>
</tr>
<tr>
<td>🍔&nbsp;<b>Zomato Case Study</b></td>
<td>13 real business questions — customer behavior, restaurant performance, delivery partner payouts</td>
<td><code>SQL</code></td>
</tr>
<tr>
<td>✈️&nbsp;<b>Flights Case Study</b></td>
<td>Engineers real datetime fields from raw text, then analyzes seasonality, route duration, and pricing patterns</td>
<td><code>SQL</code></td>
</tr>
</table>

---

## ⚖️ Why Both Pandas *and* SQL

<table>
<tr>
<td width="50%" valign="top">

### 🐼 Pandas
Best for exploratory, iterative work — fast statistics, visualizations, and imputation with `sklearn`. Great when you're still figuring out what the data is telling you.

</td>
<td width="50%" valign="top">

### 🗃️ SQL
The same cleaning/EDA logic, done as pure queries — `CASE WHEN` for standardizing categories, `REGEXP`/`SUBSTRING_INDEX` for parsing text, aggregation for missing-value treatment. Built for when the data already lives in a database.

</td>
</tr>
</table>

---

## 🧰 Core Techniques Practiced

```
🧹 Cleaning         Missing-value handling · Type correction · Parsing compound
                     text fields · Standardizing inconsistent categories

🔍 EDA              Univariate & bivariate analysis · Skewness & outlier
                     detection · ASCII histograms in SQL · Feature engineering

🗃️ SQL              Joins · CTEs · Correlated subqueries · HAVING ·
                     Date/time functions · REGEXP · Window-style aggregation
```

---

## 📁 Structure

```
data-analysis/
├── Data-Cleaning/
│   └── Laptopdata_cleaning_sql.sql
├── EDA/
│   ├── Eda_on_SmartPhone_Dataset.ipynb
│   └── Eda_on_laptopdata.sql
├── SQL/
│   ├── Zomato_case_study.sql
│   └── casestudy_on_flights.sql
├── datasets/
│   └── (raw CSVs used across the above)
└── README.md
```

---

<div align="center">

✨ *Part of my broader portfolio — check out* [**github.com/Divya-Chital27**](https://github.com/Divya-Chital27) *for Power BI dashboards and end-to-end projects.*

</div>
