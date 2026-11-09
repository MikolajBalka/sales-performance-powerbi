-- Business analyses executed in SSMS on 9 November 2026; findings in README.
USE [SalesPortfolio];
GO

-- A. Which three revenue-ranked products lead within each category?
-- DENSE_RANK keeps ties, so a category may return more than three products.
-- Includes all sales, including orders without dates.
WITH ProductSales AS (
    SELECT p.CategoryName, s.ProductID, p.ProductName,
           SUM(s.SalesAmount) AS TotalSales, SUM(s.OrderQty) AS UnitsSold
    FROM dbo.vw_Sales s
    LEFT JOIN dbo.vw_DimProduct p ON s.ProductID=p.ProductID
    GROUP BY p.CategoryName,s.ProductID,p.ProductName
), Ranked AS (
    SELECT *, DENSE_RANK() OVER
        (PARTITION BY CategoryName ORDER BY TotalSales DESC) AS RevenueRank,
        CAST(100.0*TotalSales/NULLIF(SUM(TotalSales) OVER
            (PARTITION BY CategoryName),0) AS decimal(6,2)) AS CategorySharePct
    FROM ProductSales
)
SELECT COALESCE(CategoryName,'Unassigned') AS CategoryName,
       ProductID,ProductName,RevenueRank,TotalSales,UnitsSold,CategorySharePct
FROM Ranked WHERE RevenueRank<=3
ORDER BY CategoryName,RevenueRank,ProductID;

-- B. How do monthly sales and cumulative sales within each year develop?
-- Excludes 848.76 of sales without dates. May 2011 starts on May 31.
-- Annual cumulative amounts for 2011 and 2014 cover partial years.
-- Months without recorded sales would not appear in this query.
WITH Monthly AS (
    SELECT DATEFROMPARTS(YEAR(OrderDate),MONTH(OrderDate),1) AS SalesMonth,
           SUM(SalesAmount) AS MonthlySales,
           COUNT(DISTINCT SalesOrderID) AS Orders, SUM(OrderQty) AS UnitsSold
    FROM dbo.vw_Sales WHERE OrderDate IS NOT NULL
    GROUP BY DATEFROMPARTS(YEAR(OrderDate),MONTH(OrderDate),1)
)
SELECT SalesMonth,MonthlySales,Orders,UnitsSold,
       SUM(MonthlySales) OVER (PARTITION BY YEAR(SalesMonth)
           ORDER BY SalesMonth ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
           AS SalesYTD,
       CASE WHEN SalesMonth=CONVERT(date,'20110501',112)
            THEN 'Partial first month: data starts May 31'
            ELSE 'Within recorded date range' END AS CoverageNote
FROM Monthly ORDER BY SalesMonth;

-- C. How did recorded January-June sales change across years?
-- Same calendar windows do not prove complete coverage: see June 2014 limitation.
-- Within recorded date range in query B is not a completeness certification.
-- Compare only Jan-Jun 2012, 2013, 2014. Do not compare partial full-year totals.
-- 2012 is the baseline. Unknown dates are excluded and disclosed in README.
WITH ComparablePeriods AS (
    SELECT YEAR(OrderDate) AS SalesYear,SUM(SalesAmount) AS JanJuneSales,
           COUNT(DISTINCT SalesOrderID) AS Orders
    FROM dbo.vw_Sales
    WHERE OrderDate>=CONVERT(date,'20120101',112)
      AND OrderDate<CONVERT(date,'20140701',112)
      AND MONTH(OrderDate)<=6
    GROUP BY YEAR(OrderDate)
), Previous AS (
    SELECT *,LAG(JanJuneSales) OVER (ORDER BY SalesYear) AS PriorPeriodSales,
           LAG(SalesYear) OVER (ORDER BY SalesYear) AS PriorYear
    FROM ComparablePeriods
)
SELECT SalesYear,JanJuneSales,Orders,
       CASE WHEN PriorYear=SalesYear-1 THEN PriorPeriodSales END AS PreviousJanJuneSales,
       CASE WHEN PriorYear=SalesYear-1
            THEN CAST(100.0*(JanJuneSales-PriorPeriodSales)
                 /NULLIF(PriorPeriodSales,0) AS decimal(10,2)) END AS YoYGrowthPct
FROM Previous ORDER BY SalesYear;
