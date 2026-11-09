-- Sales Performance: final view definitions extracted from the supplied scripts.
-- Prerequisite: import the five source tables described in README.md.
-- Run in SSMS; GO separates view definitions into batches.
-- CREATE OR ALTER preserves the ability to rerun this script.
-- This updates view definitions; it does not change source table rows.
USE [SalesPortfolio];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
-- vw_Product
CREATE OR ALTER VIEW dbo.vw_Product AS
SELECT
    TRY_CONVERT(int, ProductID) AS ProductID,
    Name AS ProductName,

    TRY_CONVERT(
        decimal(19,4),
        REPLACE(StandardCost, ',', '.')
    ) AS StandardCost,

    TRY_CONVERT(
        decimal(19,4),
        REPLACE(ListPrice, ',', '.')
    ) AS ListPrice,

    TRY_CONVERT(
        int,
        NULLIF(
            NULLIF(LTRIM(RTRIM(ProductSubcategoryID)), 'NULL'),
            ''
        )
    ) AS ProductSubcategoryID

FROM dbo.Product_Raw;
GO

-- vw_SalesOrderDetail
CREATE OR ALTER VIEW dbo.vw_SalesOrderDetail AS
WITH Cleaned AS (
    SELECT
        TRY_CONVERT(int, SalesOrderID) AS SalesOrderID,
        TRY_CONVERT(int, SalesOrderDetailID) AS SalesOrderDetailID,
        TRY_CONVERT(int, ProductID) AS ProductID,

        TRY_CONVERT(
            int,
            NULLIF(
                LTRIM(RTRIM(REPLACE(OrderQty, N'Dwa', N'2'))),
                ''
            )
        ) AS OrderQty,

        TRY_CONVERT(
            decimal(19,4),
            REPLACE(NULLIF(LTRIM(RTRIM(UnitPrice)), ''), ',', '.')
        ) AS UnitPrice,

        TRY_CONVERT(
            decimal(9,4),
            REPLACE(
                NULLIF(LTRIM(RTRIM(UnitPriceDiscount)), ''),
                ',', '.'
            )
        ) AS UnitPriceDiscount,

        TRY_CONVERT(
            decimal(19,6),
            REPLACE(
                NULLIF(
                    NULLIF(LTRIM(RTRIM(LineTotal)), 'NULL'),
                    ''
                ),
                ',', '.'
            )
        ) AS SourceLineTotal

    FROM dbo.SalesOrderDetail_Raw
)
SELECT
    *,
    CAST(
        OrderQty * UnitPrice * (1 - UnitPriceDiscount)
        AS decimal(19,6)
    ) AS CalculatedLineTotal
FROM Cleaned;
GO

-- vw_SalesOrderHeader
CREATE OR ALTER VIEW [dbo].[vw_SalesOrderHeader] AS
WITH Parsed AS (
    SELECT
        TRY_CONVERT(int, SalesOrderID) AS SalesOrderID,
        TRY_CONVERT(date, OrderDate, 121) AS ParsedDate,
        TRY_CONVERT(
            decimal(10,2),
            REPLACE(OrderDate, ',', '.')
        ) AS ExcelDateNumber,

        TRY_CONVERT(int, CustomerID) AS CustomerID,
        TRY_CONVERT(
            int, NULLIF(NULLIF(SalesPersonID, 'NULL'), '')
        ) AS SalesPersonID,
        TRY_CONVERT(
            int, NULLIF(NULLIF(TerritoryID, 'NULL'), '')
        ) AS TerritoryID,

        TRY_CONVERT(
            decimal(19,4), REPLACE(NULLIF(SubTotal, ''), ',', '.')
        ) AS SourceSubTotal,
        TRY_CONVERT(
            decimal(19,4), REPLACE(NULLIF(TaxAmt, ''), ',', '.')
        ) AS TaxAmt,
        TRY_CONVERT(
            decimal(19,4), REPLACE(NULLIF(Freight, ''), ',', '.')
        ) AS Freight,
        TRY_CONVERT(
            decimal(19,4), REPLACE(NULLIF(TotalDue, ''), ',', '.')
        ) AS TotalDue
    FROM dbo.SalesOrderHeader_Raw
),
DetailTotals AS (
    SELECT
        SalesOrderID,
        SUM(CalculatedLineTotal) AS DetailTotal
    FROM dbo.vw_SalesOrderDetail
    GROUP BY SalesOrderID
)
SELECT
    h.SalesOrderID,
    COALESCE(
        h.ParsedDate,
        DATEADD(
            day,
            CASE
                WHEN h.ExcelDateNumber BETWEEN 30000 AND 60000
                 AND h.ExcelDateNumber = FLOOR(h.ExcelDateNumber)
                THEN CONVERT(int, h.ExcelDateNumber)
            END,
            CONVERT(date, '18991230', 112)
        )
    ) AS OrderDate,
    h.CustomerID,
    h.SalesPersonID,
    h.TerritoryID,
    h.SourceSubTotal,

    COALESCE(
        h.SourceSubTotal,
        CASE
            WHEN ABS(
                d.DetailTotal - (h.TotalDue - h.TaxAmt - h.Freight)
            ) <= 0.01
            THEN CAST(d.DetailTotal AS decimal(19,4))
        END
    ) AS SubTotal,

    h.TaxAmt,
    h.Freight,
    h.TotalDue,
    CASE WHEN h.ParsedDate IS NULL
         THEN 1 ELSE 0 END AS DateConversionRequired,
    CASE WHEN h.SourceSubTotal IS NULL
              AND d.DetailTotal IS NOT NULL
              AND ABS(
                  d.DetailTotal - (h.TotalDue - h.TaxAmt - h.Freight)
              ) <= 0.01
         THEN 1 ELSE 0 END AS SubTotalReconstructed
FROM Parsed AS h
LEFT JOIN DetailTotals AS d
    ON h.SalesOrderID = d.SalesOrderID;
GO

-- vw_Sales
CREATE OR ALTER VIEW [dbo].[vw_Sales] AS
SELECT
    d.SalesOrderDetailID,
    d.SalesOrderID,
    h.OrderDate,
    h.CustomerID,
    h.SalesPersonID,
    h.TerritoryID,
    d.ProductID,
    d.OrderQty,
    d.UnitPrice,
    d.UnitPriceDiscount,
    d.CalculatedLineTotal AS SalesAmount,
    CASE
        WHEN h.OrderDate IS NULL THEN 1
        ELSE 0
    END AS MissingOrderDate
FROM dbo.vw_SalesOrderDetail AS d
LEFT JOIN dbo.vw_SalesOrderHeader AS h
    ON d.SalesOrderID = h.SalesOrderID;
GO

-- vw_DimProduct
CREATE OR ALTER VIEW dbo.vw_DimProduct AS
SELECT
    p.ProductID,
    p.ProductName,
    p.StandardCost,
    p.ListPrice,
    p.ProductSubcategoryID,
    sc.Name AS SubcategoryName,
    sc.ProductCategoryID,
    c.Name AS CategoryName
FROM dbo.vw_Product AS p
LEFT JOIN dbo.ProductSubCategory AS sc
    ON p.ProductSubcategoryID = sc.ProductSubcategoryID
LEFT JOIN dbo.ProductCategory AS c
    ON sc.ProductCategoryID = c.ProductCategoryID;
GO
