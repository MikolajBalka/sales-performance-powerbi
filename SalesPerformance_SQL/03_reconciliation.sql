-- Read-only reconciliation. Currency comparison tolerance: 0.01.
USE [SalesPortfolio];
GO

-- 1. Calculated lines versus available source LineTotal.
-- Previously observed: 121,251 compared, 66 missing source amounts, max diff 0.
-- Missing source amounts are disclosed rather than counted as matched.
SELECT COUNT_BIG(*) AS TotalRows,
       SUM(CASE WHEN SourceLineTotal IS NULL THEN 1 ELSE 0 END) AS MissingSourceLineTotal,
       SUM(CASE WHEN CalculatedLineTotal IS NULL THEN 1 ELSE 0 END) AS MissingCalculatedLineTotal,
       SUM(CASE WHEN SourceLineTotal IS NOT NULL AND CalculatedLineTotal IS NOT NULL
                THEN 1 ELSE 0 END) AS ComparedRows,
       SUM(CASE WHEN ABS(SourceLineTotal - CalculatedLineTotal) > 0.01
                THEN 1 ELSE 0 END) AS DifferencesOverOneCent,
       MAX(ABS(SourceLineTotal - CalculatedLineTotal)) AS MaxDifference
FROM dbo.vw_SalesOrderDetail;

-- 2. Verify reconstruction against an independent header calculation.
-- Previously observed: 1,769 affected, no missing comparisons, max diff 0.
WITH DetailTotals AS (
    SELECT SalesOrderID, SUM(CalculatedLineTotal) AS DetailTotal
    FROM dbo.vw_SalesOrderDetail GROUP BY SalesOrderID
)
SELECT COUNT_BIG(*) AS AffectedOrders,
       SUM(CASE WHEN d.DetailTotal IS NULL OR h.TotalDue IS NULL
                     OR h.TaxAmt IS NULL OR h.Freight IS NULL
                THEN 1 ELSE 0 END) AS MissingComparison,
       SUM(CASE WHEN ABS(d.DetailTotal - (h.TotalDue-h.TaxAmt-h.Freight)) > 0.01
                THEN 1 ELSE 0 END) AS DifferencesOverOneCent,
       MAX(ABS(d.DetailTotal - (h.TotalDue-h.TaxAmt-h.Freight))) AS MaxDifference
FROM dbo.vw_SalesOrderHeader h
LEFT JOIN DetailTotals d ON h.SalesOrderID = d.SalesOrderID
WHERE h.SourceSubTotal IS NULL;

-- 3. All orders: report NULLs explicitly as well as numeric differences.
-- Comparing a reconstructed SubTotal with the detail sum alone is not
-- independent evidence; check 2 supplies the separate header comparison.
WITH DetailTotals AS (
    SELECT SalesOrderID, SUM(CalculatedLineTotal) AS DetailTotal
    FROM dbo.vw_SalesOrderDetail GROUP BY SalesOrderID
)
SELECT h.SalesOrderID, h.SubTotal, d.DetailTotal,
       h.SubTotal-d.DetailTotal AS Difference,
       CASE WHEN h.SubTotal IS NULL THEN 'Missing subtotal'
            WHEN d.SalesOrderID IS NULL THEN 'Missing order lines'
            WHEN d.DetailTotal IS NULL THEN 'Missing detail total'
            ELSE 'Amount mismatch' END AS Issue
FROM dbo.vw_SalesOrderHeader h
LEFT JOIN DetailTotals d ON h.SalesOrderID=d.SalesOrderID
WHERE h.SubTotal IS NULL OR d.SalesOrderID IS NULL OR d.DetailTotal IS NULL
   OR ABS(h.SubTotal-d.DetailTotal)>0.01
ORDER BY h.SalesOrderID;

-- 4. Grain and global KPIs. One sales row = one order line.
-- Do not sum header tax/freight across order-line rows.
SELECT COUNT_BIG(*) AS SalesRows,
       COUNT(DISTINCT SalesOrderDetailID) AS UniqueLines,
       COUNT(DISTINCT SalesOrderID) AS Orders,
       SUM(OrderQty) AS UnitsSold,
       SUM(SalesAmount) AS TotalSales,
       SUM(CASE WHEN MissingOrderDate=1 THEN SalesAmount ELSE 0 END) AS SalesWithoutDate
FROM dbo.vw_Sales;

-- 5. Values previously displayed in the SQL-backed Power BI validation page.
-- These are a fixed recorded snapshot, not a live query of the PBIX/CSV report.
WITH Actual AS (
    SELECT YEAR(OrderDate) AS SalesYear, SUM(SalesAmount) AS TotalSales
    FROM dbo.vw_Sales GROUP BY YEAR(OrderDate)
), Recorded AS (
    SELECT SalesYear, CAST(Amount AS decimal(19,2)) AS PowerBISales
    FROM (VALUES (0,848.76), (2011,12641672.21), (2012,33524301.32),
                 (2013,43622479.05), (2014,20057080.05)) v(SalesYear,Amount)
)
SELECT COALESCE(a.SalesYear,r.SalesYear) AS SalesYear,
       a.TotalSales AS SQLSales, r.PowerBISales AS RecordedPowerBISales,
       CAST(a.TotalSales AS decimal(19,2))-r.PowerBISales AS RoundedDifference,
       CASE WHEN a.TotalSales IS NULL OR r.PowerBISales IS NULL THEN 'MISSING'
            WHEN CAST(a.TotalSales AS decimal(19,2))=r.PowerBISales THEN 'MATCH'
            ELSE 'DIFFERENCE' END AS Status
FROM Actual a FULL OUTER JOIN Recorded r
  ON COALESCE(a.SalesYear,0)=r.SalesYear
ORDER BY COALESCE(a.SalesYear,r.SalesYear);

-- 6. Category totals, including unassigned values if any.
-- DISTINCT orders are non-additive across categories.
SELECT COALESCE(p.CategoryName,'Unassigned') AS CategoryName,
       SUM(s.SalesAmount) AS TotalSales, SUM(s.OrderQty) AS UnitsSold,
       COUNT(DISTINCT s.SalesOrderID) AS Orders,
       CAST(100.0*SUM(s.SalesAmount)
            /NULLIF(SUM(SUM(s.SalesAmount)) OVER (),0) AS decimal(6,2)) AS SalesSharePct
FROM dbo.vw_Sales s LEFT JOIN dbo.vw_DimProduct p ON s.ProductID=p.ProductID
GROUP BY p.CategoryName ORDER BY TotalSales DESC;
