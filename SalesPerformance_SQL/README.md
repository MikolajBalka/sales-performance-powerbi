# Sales Performance — SQL extension

SQL Server / T-SQL extension of the existing Sales Performance Power BI portfolio.
The existing dashboard remains based on CSV. This folder adds data preparation,
quality checks, reconciliation and business analysis on the same source dataset.
It does not claim a migration of the dashboard to SQL.

## Results at a glance

- Prepared and checked 121,317 order lines across 31,465 orders and 504 products.
- Calculated net sales of 109,846,381.40; all recorded annual Power BI totals match at two decimals.
- Compared 121,251 available source line totals: no differences; 66 source totals are missing.
- Recovered 164 Excel dates and reconstructed 1,769 subtotals with a separate header-equation check.
- Retained 848.76 of sales on 12 orders with unresolved dates, outside dated trends.
- Investigated unusually low June 2014 sales: only Accessories and Clothing occur in that month's extract. Source completeness remains unconfirmed.

## Purpose

Can the supplied sales data be converted into reliable order-line sales, and can
its figures be reconciled before interpreting product and time trends?

## Files and execution

1. Create/use a database named `SalesPortfolio` in SQL Server.
2. Import the source CSVs below with SSMS Import Flat File. Preserve the originals.
3. Run `01_views.sql` in SSMS, then `02_data_quality_checks.sql`,
   `03_reconciliation.sql`, and `04_business_analysis.sql`.
4. Optionally run `05_june_diagnostics.sql` to inspect the June 2014 limitation.
5. Inspect every result set; an empty anomaly result means no rows were detected,
   not that every possible data-quality issue has been ruled out.

`GO` is an SSMS batch separator. `01_views.sql` uses CREATE OR ALTER VIEW and can
update existing view definitions; the other scripts only read data. No source
rows are updated or deleted. An existing experimental `dbo.Product` table is not
used. SQL Server must support CREATE OR ALTER VIEW (2016 SP1 or later).

### Data source and access

The source is the BI Developer paid training platform, lesson
[Zestaw Ćwiczeń 2 – Power Query](https://bideveloper.elms.pl/next/public/lesson/96),
attachment **DANE**, as identified from the course page used for this project.
Access requires an account with the relevant course entitlement. This repository
contains SQL and documented aggregate results; course files are not redistributed.
An evaluator can review the logic and findings without course access, but cannot
reproduce identical results without the same input extracts. The dataset uses
AdventureWorks-style sales tables with training data-quality issues.

### Import contract

| Source file | Destination table | Minimum required columns |
|---|---|---|
| Production.Product.csv | dbo.Product_Raw | ProductID, Name, StandardCost, ListPrice, ProductSubcategoryID |
| Production.ProductCategory.csv | dbo.ProductCategory | ProductCategoryID, Name |
| Production.ProductSubCategory.csv | dbo.ProductSubCategory | ProductSubcategoryID, ProductCategoryID, Name |
| SalesOrderDetail.csv | dbo.SalesOrderDetail_Raw | SalesOrderID, SalesOrderDetailID, ProductID, OrderQty, UnitPrice, UnitPriceDiscount, LineTotal |
| SalesOrderHeader.csv | dbo.SalesOrderHeader_Raw | SalesOrderID, OrderDate, CustomerID, SalesPersonID, TerritoryID, SubTotal, TaxAmt, Freight, TotalDue, DueDate, ShipDate, ModifiedDate |

The supplied files use UTF-8 with BOM, semicolon delimiters, mixed decimal comma
and dot, and missing-value text such as `NULL`. The three `_Raw` tables preserve
source strings. For this project's required raw columns nvarchar(50) was used;
check lengths before importing additional columns or other files. Category and
subcategory IDs in the inspected lookup tables are numeric, with text names.
Retain CSV column headers. Validate import row counts before creating views.

The CSV source files are not included in this package. To reproduce the exact
findings, use the same supplied extracts, not an unmodified AdventureWorks
installation: these extracts contain additional data-quality problems.
This package is not a fully automated ingestion pipeline.

### View dependencies

- Product_Raw → vw_Product → vw_DimProduct (with category lookups)
- SalesOrderDetail_Raw → vw_SalesOrderDetail
- SalesOrderHeader_Raw + vw_SalesOrderDetail → vw_SalesOrderHeader
- vw_SalesOrderDetail + vw_SalesOrderHeader → vw_Sales

The grain of vw_Sales is one sales order line. Header tax and freight must not be
summed across repeated order-line rows. SalesAmount is net of line discounts,
excluding tax and freight. Amounts are reported in source monetary units; no
currency conversion is performed.

## Cleaning decisions and evidence

| Issue | Handling | Execution evidence |
|---|---|---|
| Text `Dwa` embedded in quantities | Replace with digit 2, then convert to integer | No residual invalid quantities; available line totals agreed with calculations |
| Mixed decimal separators | Replace comma with dot, convert to DECIMAL | Numeric input checks passed |
| 66 missing source line totals | Calculate quantity × price × (1 − discount) | All 121,251 available source totals matched calculated totals |
| Excel serial order dates | Convert integer serials in the accepted range using 1899-12-30 | 164 dates recovered |
| 1,769 unparseable SubTotal values | Reconstruct from details only when matching TotalDue − TaxAmt − Freight within 0.01 | All 1,769 comparisons matched; maximum difference 0 |
| 12 orders with `Dzisiaj` as date | Leave dates NULL; preserve sales | 848.76 sales retained outside dated trends |
| Products without subcategories | Preserve optional NULL values | Not treated as failed joins merely because a category is absent |

These are dataset-specific rules. Successful conversion alone does not prove
that a repaired value is correct. Line-total comparisons support the quantity
rule; the separate header equation supports subtotal reconstruction. Subtotal
reconciliation against the same details used to reconstruct it is not an
independent check. The 66 missing source line totals cannot be validated against
their own absent source values.

The existing Excel-date expression parses decimal(10,2) before checking integer
status. It is retained from the working view for this dataset, not presented as
a universal parser for arbitrary Excel serials or fractional timestamps.
DateConversionRequired counts 176 records: 164 recovered plus 12 unresolved.
No current date is substituted for historical `Dzisiaj` values.

## Recorded validation results

Scripts 01–04 were executed in SSMS against SQL Server Express on the local
`SalesPortfolio` database on 8–9 November 2026. Results below were recorded from
that execution. No separate execution in another environment is claimed.

Duplicate identifier, required product-field, subcategory parsing and order
subtotal anomaly queries returned no rows. Required line/header input checks and
all four orphan checks returned zero affected rows. These checks do not certify
source completeness or every possible business rule.

| Metric | Recorded result |
|---|---:|
| Products / unique product IDs | 504 / 504 |
| Sales rows / unique order-line IDs | 121,317 / 121,317 |
| Orders | 31,465 |
| Units sold | 274,914 |
| Total sales (6 decimals) | 109,846,381.399888 |
| Power BI displayed total sales | 109,846,381.40 |
| Sales without an assigned order date | 848.76 |
| Missing order headers / missing products in order lines | 0 / 0 |
| Source line totals compared | 121,251 |
| Maximum source/calculated line difference | 0.000000 |

### Sales by category

| Category | Sales (6 decimals) | Share |
|---|---:|---:|
| Bikes | 94,651,172.704731 | 86.17% |
| Components | 11,802,593.286430 | 10.74% |
| Clothing | 2,120,542.524801 | 1.93% |
| Accessories | 1,272,072.883926 | 1.16% |

Bikes account for 86.17% of sales value. This indicates revenue concentration;
it does not establish profitability or future growth. Category order counts
must not be added: an order can contain products from multiple categories.

### Sales by year

| Year | SQL sales (6 decimals) | Power BI displayed sales |
|---|---:|---:|
| Unknown date | 848.760000 | 848.76 |
| 2011 | 12,641,672.212954 | 12,641,672.21 |
| 2012 | 33,524,301.324434 | 33,524,301.32 |
| 2013 | 43,622,479.051635 | 43,622,479.05 |
| 2014 | 20,057,080.050865 | 20,057,080.05 |

SQL/Power BI comparisons above verify the SQL-backed import, relationships and
aggregation. They are not an independent reconciliation against all legacy CSV
report measures. The recorded annual amounts in 03_reconciliation.sql are a
fixed snapshot, not a live connection to Power BI. Compare monetary amounts at
the agreed reporting precision rather than expecting floating-point equality.

## Business analyses and findings

`04_business_analysis.sql` contains three read-only analyses:

1. Top three revenue ranks within each category, with category shares. Ties are
   retained, so more than three products may be returned.
2. Monthly sales and cumulative sales within each year.
3. January–June sales growth for comparable periods in 2012–2014.

### Product and category findings

| Category | Revenue leader | Sales | Share of category sales |
|---|---|---:|---:|
| Accessories | Hitch Rack - 4-Bike | 237,096.16 | 18.64% |
| Bikes | Mountain-200 Black, 38 | 4,400,592.80 | 4.65% |
| Clothing | Long-Sleeve Logo Jersey, L | 198,754.98 | 9.37% |
| Components | HL Mountain Frame - Silver, 38 | 930,780.68 | 7.89% |

The three leading Accessories products account for approximately 44.29% of
category sales (sum of displayed shares). This supports monitoring concentration;
it does not show margin or prove that these products should receive promotions.

### January–June comparison

| Year | Recorded sales | Orders | Change versus previous January–June |
|---|---:|---:|---:|
| 2012 | 17,230,360.40 | 1,811 | Baseline |
| 2013 | 18,675,822.38 | 2,741 | +8.39% |
| 2014 | 20,057,080.05 | 11,749 | +7.40% |

These are changes in the supplied extract. Matching calendar windows alone does
not establish comparable source coverage, particularly for June 2014.

### June 2014 investigation and limitation

Monthly sales fall from 5,366,674.969338 in May to 48,157.080000 in June.
The follow-up queries are retained in `05_june_diagnostics.sql`.

| Month / category | Order lines | Units | Sales |
|---|---:|---:|---:|
| May / Bikes | 2,325 | 4,321 | 4,565,082.564414 |
| May / Components | 1,067 | 2,553 | 577,138.554700 |
| May / Clothing | 1,490 | 3,967 | 119,667.835508 |
| May / Accessories | 3,744 | 5,043 | 104,786.014716 |
| June / Accessories | 1,687 | 1,687 | 32,044.390000 |
| June / Clothing | 412 | 412 | 16,112.690000 |

June contains 927 orders and 2,099 lines, with no Bikes or Components rows.
Neither May nor June contains zero-price or fully discounted lines. Recorded
dates span each month, but that does not establish complete extraction.
The category mix explains the composition of the observed total; whether it
reflects real trading or incomplete training data cannot be determined here.
Do not interpret the decline as a confirmed business event. Confirm extract
coverage before using the 2014 growth figure for a business decision.

Known dates span 2011-05-31 to 2014-06-30. 2011 and 2014 are partial years, so
full-year totals must not be used to claim a comparable annual decline/growth.
May 2011 is a partial first month. Unknown-date sales are included in global and
product totals but excluded from dated analyses; their period cannot be inferred.
Monthly output covers months with observed rows, not a filled calendar series.

## Power BI boundary

The original report pages remain CSV-based. SQL Validation was a development
page using vw_Sales, vw_DimProduct and a separate SQL Calendar. It is technical
supporting evidence, not a new business dashboard. No migration of the original
report or commercially deployed SQL solution is claimed.
