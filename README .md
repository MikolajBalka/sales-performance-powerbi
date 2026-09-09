# Sales Performance Dashboard | Power BI

An interactive **Power BI** portfolio project analysing **sales performance, customer behaviour, salesperson effectiveness and product performance** using AdventureWorks sales data.

The report was designed to answer a practical business question: **where is revenue generated, which customers and products drive performance, and how consistently is the sales team achieving its targets?**

[Live Power BI Dashboard](https://app.powerbi.com/view?r=eyJrIjoiMzUxM2M5OGMtMmUxZS00MzQ4LWE0ZDAtMmQ0OTVmMWFlOTUxIiwidCI6IjNkZmU5YWI2LTgxYmYtNDkxYy1iNjcwLTAxYzgyNGEwOWUxOSJ9&pageName=f8466582b259c3bdab82)

---

## Project overview

The dashboard combines transaction-level sales data with customer, salesperson, territory, product and calendar information. It moves from a high-level sales overview into focused analyses of customers, salespeople and products, then closes with a dedicated page summarising the most important business findings.

The final report contains six pages:

1. **Overview Dashboard** - landing page and report navigation.
2. **Sales Overview** - sales KPIs, time trend, geography, top products and order details.
3. **Customer Analysis** - customer value, segmentation, repeat customers and top accounts.
4. **Salesperson Performance** - sales ranking, goal achievement and salesperson details.
5. **Product Analysis** - category mix, product sales trend, price-vs-sales analysis and product details.
6. **Key Objectives** - executive summary of the most important findings.

![Dashboard landing page](assets/landing.png)

---

## 1. Business problem

The analysis was built around the following questions:

- How did sales develop over the available historical period?
- Which products and product categories generate the highest revenue?
- Which customer segments and accounts contribute most to sales?
- How many customers make repeat purchases?
- Which salespeople generate the highest sales?
- How consistently do salespeople achieve their assigned goals?
- How concentrated is revenue across products, customers and sales representatives?
- Where should the business focus further investigation or improvement activity?

The goal was to create a report that supports both **executive monitoring** and **drill-down analysis**, rather than a collection of disconnected charts.

---

## 2. Data used

The semantic model separates order-level and order-line facts from descriptive business dimensions.

| Table | Purpose |
|---|---|
| `SalesOrderHeader` | Order-level transaction data, dates and business references |
| `SalesOrderDetail` | Order-line quantities, prices, discounts and line sales values |
| `Customer` | Customer-level attributes used for segmentation and customer analysis |
| `SalesPerson` | Salesperson attributes, quota, bonus and commission information |
| `SalesTerritory` | Geographic / territory information used for regional analysis |
| `Production Product` | Product-level descriptive attributes |
| `Production ProductSubCategory` | Category and subcategory structure used in product analysis |
| `Calendar` | Shared date dimension used for year, quarter and month filtering |
| `Measures (2)` | Dedicated table containing DAX business measures |

### Scope

- **Dataset:** AdventureWorks sales data
- **Historical period visible in the report:** 2011-2014
- **Analysis levels:** order, customer, salesperson, territory and product
- **Main analytical tools:** Power Query, DAX, semantic modelling and interactive Power BI visuals

---

## 3. Data preparation and ETL

Data preparation was performed in **Power Query** before the data was used in the semantic model.

The preparation process included:

- importing and shaping the transaction and dimension tables,
- assigning appropriate data types,
- preparing fields used in reporting and filtering,
- using a dedicated calendar structure for year, quarter and month analysis,
- validating sales values before building the final business measures,
- organising the model so the report can be filtered consistently by time, customer, salesperson, territory and product context.

### Data quality challenge: discount locale conversion

One of the most important technical issues identified during development involved the `SalesOrderDetail[UnitPriceDiscount]` field.

Discount values such as `0,02`, `0,05` or `0,35` were initially converted using an **en-US locale**, which could interpret them as `2`, `5` or `35` instead of decimal discount rates. This distorted downstream calculations and produced unrealistic `LineTotal` values, including negative sales results.

The Power Query transformation was corrected by changing the locale used in the relevant type-conversion step to **pl-PL**. After the fix:

- discount values were restored to their correct decimal form,
- `LineTotal` calculations were corrected,
- downstream sales metrics were revalidated before finalising the report.

This debugging step became an important part of the project because it demonstrated that **data validation is as important as visualisation** when building trustworthy BI reporting.

---

## 4. Data model and analytical logic

The report uses a relational semantic model built around the two sales transaction tables and shared dimensions.

```text
FACT / TRANSACTION TABLES
- SalesOrderHeader
- SalesOrderDetail

BUSINESS DIMENSIONS
- Calendar
- Customer
- SalesPerson
- SalesTerritory
- Production Product
- Production ProductSubCategory

MEASURES
- Measures (2)
```

A dedicated measures table keeps business calculations separate from descriptive columns and makes the model easier to maintain.

The final PBIX also uses:

- **page navigation** between analytical sections,
- **bookmark-based reset buttons** for filters,
- selected **visual interaction settings** to control how visuals affect one another,
- reusable time and business dimensions across multiple report pages.

---

## 5. Key metrics and measures

The report is measure-driven. Selected measures used across the dashboard include:

| Measure | Analytical purpose |
|---|---|
| `TotalSales` | Overall sales value used in KPIs, trends, rankings and tables |
| `TotalOrders` | Number of orders in the active filter context |
| `AverageOrderValue` | Average sales value per order |
| `TotalTax` | Total tax amount associated with sales |
| `TopCustomer` | Identifies the highest-value customer in the active context |
| `TotalCustomers` | Number of analysed customers |
| `AvgOrderValuePerCustomer` | Customer-level average order value |
| `RepeatCustomers` | Number of customers with repeat purchasing behaviour |
| `CustomerLifetimeValueProxy` | Proxy measure used to monitor customer value over time |
| `Salesperson Sales` | Sales attributed to salespeople |
| `Top Salesperson` | Identifies the leading salesperson |
| `Avg Goal Achievement` | Average sales goal achievement across the team |
| `CurrentTargetPct` | Salesperson-level target achievement percentage |
| `Product Sales` | Sales analysed in product context |
| `Top Selling Product` | Identifies the highest-selling product |
| `Average Product Price` | Average product price in the current context |
| `Units Sold` | Product units sold |

> The exact DAX expressions are stored in the Power BI semantic model. This README documents the role of the measures and how they are used in the analysis rather than recreating formulas that cannot be reliably extracted from the report definition alone.

---

## 6. Visualisations and report pages

### Sales Overview

| Visual | Purpose | Main measures / fields |
|---|---|---|
| KPI cards | Monitor headline sales performance | `TotalSales`, `TotalOrders`, `AverageOrderValue`, `TotalTax` |
| Line chart | Track sales over time | `TotalSales` by `Year` |
| Map | Compare sales geographically | `TotalSales` by country / territory |
| Bar chart | Identify the highest-selling products | `TotalSales` by product |
| Sales details table | Inspect order-level details | order number, date, quantity, product, sales |
| Slicers | Interactive filtering | year, quarter, month, region |

### Customer Analysis

| Visual | Purpose | Main measures / fields |
|---|---|---|
| KPI cards | Highlight top customer, customer count, average order value and repeat customers | customer measures |
| Line chart | Track customer value over time | `CustomerLifetimeValueProxy` |
| Donut chart | Compare customer segments | customer segment and `TotalSales` |
| Customer ranking | Highlight the largest customer accounts | customer and `TotalSales` |
| Customer details table | Compare customer-level sales behaviour | account, segment, region, orders, sales, average order, last order |
| Slicers | Interactive filtering | year, quarter, month, region |

![Customer Analysis](assets/customer-analysis.png)

### Salesperson Performance

| Visual | Purpose | Main measures / fields |
|---|---|---|
| KPI cards | Highlight top salesperson, salesperson sales and average goal achievement | salesperson measures |
| Ranking chart | Compare top salespeople by sales | `Salesperson Sales` |
| Goal achievement chart | Compare performance against target | `CurrentTargetPct` |
| Salesperson details table | Review sales, quota, goal %, bonus and commission | salesperson fields and measures |
| Slicers | Interactive filtering | salesperson, quarter, year |

![Salesperson Performance](assets/salesperson-performance.png)

### Product Analysis

| Visual | Purpose | Main measures / fields |
|---|---|---|
| KPI cards | Highlight top product, total product sales and average product price | product measures |
| Category / subcategory bar chart | Compare revenue contribution across product groups | `Product Sales` |
| Line chart | Track product sales over time | `Product Sales` by month |
| Scatter chart | Explore relationship between average price and product sales | `Average Product Price`, `Product Sales` |
| Product details table | Compare product sales, units and average price | product fields and measures |
| Slicers | Interactive product filtering | category, subcategory, product |

![Product Analysis](assets/product-analysis.png)

---

## 7. Key business insights

The final **Key Objectives** page summarises four main findings.

### 1. Strong sales growth through 2013

Sales increased from roughly **$13M in 2011** to more than **$40M in 2013**, showing strong commercial growth over the main historical period. Overall, the business generated approximately **$110M from 31K orders**, with an average order value of about **$3K**.

### 2. Customer revenue is store-led

**Store customers generate 73% of customer-segment sales**, compared with **27% from Individual customers**. At the same time, only around **7K of 19K customers are repeat customers (~37%)**, suggesting meaningful potential to increase repeat purchasing and customer retention.

### 3. Sales team performance is highly uneven

Average goal achievement is **96%**, but performance among leading salespeople ranges from approximately **58% to 170%**. The top five representatives generate roughly **57% of the $80M salesperson sales**, highlighting both strong top performers and a sizeable performance gap across the team.

### 4. Product revenue is highly concentrated

**Bikes generate approximately $95M of $110M product sales (~86%)**. Components contribute about **$12M**, while Clothing and Accessories together contribute only around **$3M**. This creates significant dependence on the Bikes category and suggests an opportunity to diversify revenue across the wider product portfolio.

---

## 8. Skills demonstrated

This project demonstrates practical use of:

- **Power BI** multi-page dashboard development,
- **Power Query** data cleaning, transformation and locale handling,
- **DAX** business measures and filter context,
- relational **data modelling**,
- KPI definition and business metric design,
- sales, customer, salesperson and product analysis,
- ranking, time-series, geographic and scatter analysis,
- interactive slicers, bookmarks and page navigation,
- visual interaction configuration,
- data-quality validation and root-cause debugging,
- business storytelling and executive insight summarisation.

---

## 9. Repository structure

```text
sales-performance-powerbi/
│
├── README.md
└── assets/
    ├── landing.png
    ├── customer-analysis.png
    ├── salesperson-performance.png
    └── product-analysis.png
```

The `.pbix` file does not need to be published in the repository because the **Power BI Service link** above provides the interactive version of the project. It can be added later if sharing the full semantic model is desirable.

---

## 10. Possible future improvements

Potential extensions include:

- adding year-over-year and period-over-period growth metrics,
- introducing gross margin or profitability analysis if cost data is available,
- extending customer segmentation with retention / frequency metrics,
- adding deeper sales-target variance analysis,
- automating data refresh from a production-ready source,
- adding a dedicated technical data-model screenshot and selected DAX code once the model is exported to a version-control-friendly format.

---

## Tools

**Power BI | Power Query | DAX | Data Modelling | Data Visualisation | Data Quality Validation**
