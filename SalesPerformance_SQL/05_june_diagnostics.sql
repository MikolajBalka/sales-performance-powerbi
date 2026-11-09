-- Read-only follow-up checks executed during review on 9 November 2026.
-- Category/date coverage cannot certify the completeness of the source extract.
USE [SalesPortfolio];
GO

SELECT DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1) AS SalesMonth,
       COUNT(*) AS OrderLines, COUNT(DISTINCT SalesOrderID) AS Orders,
       SUM(OrderQty) AS UnitsSold, SUM(SalesAmount) AS TotalSales,
       SUM(CASE WHEN UnitPrice = 0 THEN 1 ELSE 0 END) AS ZeroPriceLines,
       SUM(CASE WHEN UnitPriceDiscount = 1 THEN 1 ELSE 0 END) AS FullyDiscountedLines,
       MIN(OrderDate) AS FirstOrderDate, MAX(OrderDate) AS LastOrderDate
FROM dbo.vw_Sales
WHERE OrderDate >= '20140501' AND OrderDate < '20140701'
GROUP BY DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1)
ORDER BY SalesMonth;

SELECT MONTH(s.OrderDate) AS SalesMonth,
       COALESCE(p.CategoryName, 'Unassigned') AS CategoryName,
       COUNT(*) AS OrderLines, SUM(s.OrderQty) AS UnitsSold,
       SUM(s.SalesAmount) AS TotalSales
FROM dbo.vw_Sales AS s
LEFT JOIN dbo.vw_DimProduct AS p ON s.ProductID = p.ProductID
WHERE s.OrderDate >= '20140501' AND s.OrderDate < '20140701'
GROUP BY MONTH(s.OrderDate), p.CategoryName
ORDER BY SalesMonth, TotalSales DESC;
