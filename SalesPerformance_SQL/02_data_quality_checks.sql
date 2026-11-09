-- Run after 01_views.sql. Read-only checks; inspect every result set.
USE [SalesPortfolio];
GO

-- 1. Row counts. Expected for the inspected dataset: 504 / 31,465 / 121,317.
SELECT 'Products' AS Entity, COUNT_BIG(*) AS Rows FROM dbo.vw_Product
UNION ALL SELECT 'Orders', COUNT_BIG(*) FROM dbo.vw_SalesOrderHeader
UNION ALL SELECT 'Order lines', COUNT_BIG(*) FROM dbo.vw_SalesOrderDetail;

-- 2. Duplicate identifiers. Expected: no rows; do not delete automatically.
SELECT 'ProductID' AS KeyName, ProductID AS ID, COUNT(*) AS Occurrences
FROM dbo.vw_Product GROUP BY ProductID HAVING COUNT(*) > 1
UNION ALL
SELECT 'SalesOrderID', SalesOrderID, COUNT(*)
FROM dbo.vw_SalesOrderHeader GROUP BY SalesOrderID HAVING COUNT(*) > 1
UNION ALL
SELECT 'SalesOrderDetailID', SalesOrderDetailID, COUNT(*)
FROM dbo.vw_SalesOrderDetail GROUP BY SalesOrderDetailID HAVING COUNT(*) > 1;

-- 3. Required product fields. Optional subcategory NULLs are permitted.
SELECT * FROM dbo.vw_Product
WHERE ProductID IS NULL OR ProductName IS NULL
   OR LTRIM(RTRIM(ProductName)) = ''
   OR StandardCost IS NULL OR StandardCost < 0
   OR ListPrice IS NULL OR ListPrice < 0;

-- 4. A populated source subcategory that could not be parsed.
SELECT ProductID, ProductSubcategoryID
FROM dbo.Product_Raw
WHERE NULLIF(NULLIF(LTRIM(RTRIM(ProductSubcategoryID)), 'NULL'), '') IS NOT NULL
  AND TRY_CONVERT(int, ProductSubcategoryID) IS NULL;

-- 5. Orphan reference checks. Expected: every count is zero.
SELECT 'Missing order header' AS Issue, COUNT_BIG(*) AS AffectedRows
FROM dbo.vw_SalesOrderDetail d LEFT JOIN dbo.vw_SalesOrderHeader h
  ON d.SalesOrderID = h.SalesOrderID WHERE h.SalesOrderID IS NULL
UNION ALL
SELECT 'Missing product', COUNT_BIG(*)
FROM dbo.vw_SalesOrderDetail d LEFT JOIN dbo.vw_Product p
  ON d.ProductID = p.ProductID WHERE p.ProductID IS NULL
UNION ALL
SELECT 'Missing subcategory', COUNT_BIG(*)
FROM dbo.vw_Product p LEFT JOIN dbo.ProductSubCategory sc
  ON p.ProductSubcategoryID = sc.ProductSubcategoryID
WHERE p.ProductSubcategoryID IS NOT NULL AND sc.ProductSubcategoryID IS NULL
UNION ALL
SELECT 'Missing category', COUNT_BIG(*)
FROM dbo.ProductSubCategory sc LEFT JOIN dbo.ProductCategory c
  ON sc.ProductCategoryID = c.ProductCategoryID WHERE c.ProductCategoryID IS NULL;

-- 6. Invalid calculation inputs. Expected: zero.
SELECT COUNT_BIG(*) AS InvalidInputs
FROM dbo.vw_SalesOrderDetail
WHERE SalesOrderID IS NULL OR SalesOrderDetailID IS NULL OR ProductID IS NULL
   OR OrderQty IS NULL OR OrderQty <= 0
   OR UnitPrice IS NULL OR UnitPrice < 0
   OR UnitPriceDiscount IS NULL OR UnitPriceDiscount NOT BETWEEN 0 AND 1
   OR CalculatedLineTotal IS NULL;

-- 7. Required header fields, excluding dates (reported separately below).
SELECT COUNT_BIG(*) AS InvalidRequiredHeaderFields
FROM dbo.vw_SalesOrderHeader
WHERE SalesOrderID IS NULL OR CustomerID IS NULL
   OR SubTotal IS NULL OR TaxAmt IS NULL OR Freight IS NULL OR TotalDue IS NULL;

-- 8. Explain the source quantity replacement; zero residual invalid quantities
-- proves successful conversion, not correctness on its own. See reconciliation.
SELECT OrderQty AS OriginalQty,
       REPLACE(OrderQty, N'Dwa', N'2') AS CleanedQty,
       COUNT_BIG(*) AS Occurrences
FROM dbo.SalesOrderDetail_Raw
WHERE OrderQty LIKE N'%Dwa%'
GROUP BY OrderQty ORDER BY Occurrences DESC;

-- 9. Date outcomes: 164 recovered, 12 unresolved, 176 requiring conversion.
-- DateConversionRequired includes unresolved dates; it is NOT a repaired count.
SELECT COUNT_BIG(*) AS OrderCount,
       SUM(CASE WHEN OrderDate IS NULL THEN 1 ELSE 0 END) AS MissingDates,
       SUM(DateConversionRequired) AS DatesRequiringConversion,
       SUM(CASE WHEN DateConversionRequired = 1 AND OrderDate IS NOT NULL
                THEN 1 ELSE 0 END) AS RecoveredExcelDates,
       SUM(SubTotalReconstructed) AS ReconstructedSubTotals,
       MIN(OrderDate) AS FirstOrderDate, MAX(OrderDate) AS LastOrderDate
FROM dbo.vw_SalesOrderHeader;

-- 10. Preserve unresolved records; never replace 'Dzisiaj' with today's date.
SELECT h.SalesOrderID, r.OrderDate AS OriginalOrderDate,
       r.DueDate, r.ShipDate, r.ModifiedDate, h.SubTotal
FROM dbo.vw_SalesOrderHeader h
LEFT JOIN dbo.SalesOrderHeader_Raw r
  ON h.SalesOrderID = TRY_CONVERT(int, r.SalesOrderID)
WHERE h.OrderDate IS NULL ORDER BY h.SalesOrderID;

-- 11. Product joins must preserve uniqueness: 504 rows / 504 unique IDs.
SELECT COUNT_BIG(*) AS ProductRows,
       COUNT(DISTINCT ProductID) AS UniqueProducts
FROM dbo.vw_DimProduct;
