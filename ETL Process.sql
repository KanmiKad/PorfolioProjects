USE MASTER;
GO

Alter database WWIDM set single_user with rollback immediate;
GO

DROP DATABASE WWIDM;

CREATE DATABASE WWIDM;


USE [WWIDM]
GO

CREATE TABLE dbo.DimCities(
CityKey INT NOT NULL,
CityName NVARCHAR(50) NULL,
StateProvCode NVARCHAR(5) NULL,
StateProvName NVARCHAR(50) NULL,
CountryName NVARCHAR(60) NULL,
CountryFormalName NVARCHAR(60) NULL,
CONSTRAINT PK_DimCities PRIMARY KEY CLUSTERED ( CityKey )
);

CREATE TABLE dbo.DimCustomers(
CustomerKey INT NOT NULL,
CustomerName NVARCHAR(100) NULL,
CustomerCategoryName NVARCHAR(50) NULL,
DeliveryCityName NVARCHAR(50) NULL,
DeliveryStateProvCode NVARCHAR(5) NULL,
DeliveryCountryName NVARCHAR(50) NULL,
PostalCityName NVARCHAR(50) NULL,
PostalStateProvCode NVARCHAR(5) NULL,
PostalCountryName NVARCHAR(50) NULL,
StartDate DATE NOT NULL,
EndDate DATE NULL,
CONSTRAINT PK_DimCustomers PRIMARY KEY CLUSTERED ( CustomerKey )
);

CREATE TABLE dbo.DimProducts(
ProductKey INT NOT NULL,
ProductName NVARCHAR(100) NULL,
ProductColour NVARCHAR(20) NULL,
ProductBrand NVARCHAR(50) NULL,
ProductSize NVARCHAR(20) NULL,
StartDate DATE NOT NULL,
EndDate DATE NULL,
CONSTRAINT PK_DimProducts PRIMARY KEY CLUSTERED ( ProductKey )
);

CREATE TABLE dbo.DimSalesPeople(
SalespersonKey INT NOT NULL,
FullName NVARCHAR(50) NULL,
PreferredName NVARCHAR(50) NULL,
LogonName NVARCHAR(50) NULL,
PhoneNumber NVARCHAR(20) NULL,
FaxNumber NVARCHAR(20) NULL,
EmailAddress NVARCHAR(256) NULL,
CONSTRAINT PK_DimSalesPeople PRIMARY KEY CLUSTERED (SalespersonKey )
);

CREATE TABLE dbo.DimSuppliers(
SupplierKey INT NOT NULL,
SupplierName NVARCHAR(100) NULL,
SupplierCategoryName NVARCHAR(50) NULL,
PhoneNumber NVARCHAR(20) NULL,
FaxNumber NVARCHAR(20) NULL,
WebsiteURL NVARCHAR(256) NULL,
StartDate DATE NOT NULL,
EndDate DATE NULL,
CONSTRAINT PK_DimSuppliers PRIMARY KEY CLUSTERED ( SupplierKey )
);

CREATE TABLE dbo.DimDate(
DateKey INT NOT NULL,
DateValue DATE NOT NULL,
Year SMALLINT NOT NULL,
Month TINYINT NOT NULL,
Day TINYINT NOT NULL,
Quarter TINYINT NOT NULL,
StartOfMonth DATE NOT NULL,
EndOfMonth DATE NOT NULL,
MonthName VARCHAR(9) NOT NULL,
DayOfWeekName VARCHAR(9) NOT NULL,
CONSTRAINT PK_DimDate PRIMARY KEY CLUSTERED ( DateKey )
);

CREATE TABLE dbo.FactOrders(
CustomerKey INT NOT NULL,
CityKey INT NOT NULL,
ProductKey INT NOT NULL,
SalespersonKey INT NOT NULL,
SupplierKey INT NOT NULL,
DateKey INT NOT NULL,
Quantity INT NOT NULL,
UnitPrice DECIMAL(18, 2) NOT NULL,
TaxRate DECIMAL(18, 3) NOT NULL,
TotalBeforeTax DECIMAL(18, 2) NOT NULL,
TotalAfterTax DECIMAL(18, 2) NOT NULL,
CONSTRAINT FK_FactOrders_DimCities FOREIGN KEY(CityKey) REFERENCES dbo.DimCities
(CityKey),
CONSTRAINT FK_FactOrders_DimCustomers FOREIGN KEY(CustomerKey) REFERENCES
dbo.DimCustomers (CustomerKey),
CONSTRAINT FK_FactOrders_DimDate FOREIGN KEY(DateKey) REFERENCES dbo.DimDate
(DateKey),
CONSTRAINT FK_FactOrders_DimProducts FOREIGN KEY(ProductKey) REFERENCES
dbo.DimProducts (ProductKey),
CONSTRAINT FK_FactOrders_DimSalesPeople FOREIGN KEY(SalespersonKey) REFERENCES
dbo.DimSalesPeople (SalespersonKey),
CONSTRAINT FK_FactOrders_DimSuppliers FOREIGN KEY(SupplierKey) REFERENCES
dbo.DimSuppliers (SupplierKey)
);

GO
CREATE PROCEDURE dbo.DimDate_Load
@DateValue DATE
AS
BEGIN;
INSERT INTO dbo.DimDate
SELECT CAST( YEAR(@DateValue) * 10000 + MONTH(@DateValue) * 100 + DAY(@DateValue)
AS INT),
@DateValue,
YEAR(@DateValue),
MONTH(@DateValue),
DAY(@DateValue),
DATEPART(qq,@DateValue),
DATEADD(DAY,1,EOMONTH(@DateValue,-1)),
EOMONTH(@DateValue),
DATENAME(mm,@DateValue),
DATENAME(dw,@DateValue);
END

--STAGE AND EXTRACT
GO

CREATE TABLE dbo.Customers_Stage (
CustomerName NVARCHAR(100),
CustomerCategoryName NVARCHAR(50),
DeliveryCityName NVARCHAR(50),
DeliveryStateProvinceCode NVARCHAR(5),
DeliveryStateProvinceName NVARCHAR(50),
DeliveryCountryName NVARCHAR(50),
DeliveryFormalName NVARCHAR(60),
PostalCityName NVARCHAR(50),
PostalStateProvinceCode NVARCHAR(5),
PostalStateProvinceName NVARCHAR(50),
PostalCountryName NVARCHAR(50),
PostalFormalName NVARCHAR(60)
);

CREATE TABLE dbo.Products_Stage(
ProductName NVARCHAR(100) NULL,
ProductColour NVARCHAR(20) NULL,
ProductBrand NVARCHAR(50) NULL,
ProductSize NVARCHAR(20) NULL
);

CREATE TABLE dbo.SalesPeople_Stage(
FullName NVARCHAR(50) NULL,
PreferredName NVARCHAR(50) NULL,
LogonName NVARCHAR(50) NULL,
PhoneNumber NVARCHAR(20) NULL,
FaxNumber NVARCHAR(20) NULL,
EmailAddress NVARCHAR(256) NULL
);

CREATE TABLE dbo.Suppliers_Stage (
SupplierName NVARCHAR(100) NULL,
SupplierCategoryName NVARCHAR(50) NULL,
PhoneNumber NVARCHAR(20) NULL,
FaxNumber NVARCHAR(20) NULL,
WebsiteURL NVARCHAR(256) NULL,
StartDate DATE NOT NULL,
EndDate DATE NULL,
);

CREATE TABLE dbo.Orders_Stage (
OrderDate DATE,
Quantity INT,
UnitPrice DECIMAL(18,2),
TaxRate DECIMAL(18,3),
CustomerName NVARCHAR(100),
CityName NVARCHAR(50),
StateProvinceName NVARCHAR(50),
CountryName NVARCHAR(60),
StockItemName NVARCHAR(100),
SupplierName NVARCHAR(100),
LogonName NVARCHAR(50)
);

GO
CREATE PROCEDURE dbo.Customers_Extract
AS
BEGIN;

SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @RowCt INT;

TRUNCATE TABLE dbo.Customers_Stage;

WITH CityDetails AS (
SELECT ci.CityID,
ci.CityName,
sp.StateProvinceCode,
sp.StateProvinceName,
co.CountryName,
co.FormalName

FROM WideWorldImporters.Application.Cities ci
LEFT JOIN WideWorldImporters.Application.StateProvinces sp
ON ci.StateProvinceID = sp.StateProvinceID
LEFT JOIN WideWorldImporters.Application.Countries co
ON sp.CountryID = co.CountryID )

INSERT INTO dbo.Customers_Stage (
CustomerName,
CustomerCategoryName,
DeliveryCityName,
DeliveryStateProvinceCode,
DeliveryStateProvinceName,
DeliveryCountryName,
DeliveryFormalName,
PostalCityName,
PostalStateProvinceCode,
PostalStateProvinceName,
PostalCountryName,
PostalFormalName )

SELECT cust.CustomerName,
cat.CustomerCategoryName,
dc.CityName,
dc.StateProvinceCode,
dc.StateProvinceName,
dc.CountryName,
dc.FormalName,
pc.CityName,
pc.StateProvinceCode,
pc.StateProvinceName,
pc.CountryName,
pc.FormalName
FROM WideWorldImporters.Sales.Customers cust
LEFT JOIN WideWorldImporters.Sales.CustomerCategories cat
ON cust.CustomerCategoryID = cat.CustomerCategoryID
LEFT JOIN CityDetails dc
ON cust.DeliveryCityID = dc.CityID
LEFT JOIN CityDetails pc
ON cust.PostalCityID = pc.CityID;

SET @RowCt = @@ROWCOUNT;
IF @RowCt = 0
BEGIN;
THROW 50001, 'No records found. Check with source system.', 1;
END;
END;

GO

CREATE PROCEDURE dbo.Suppliers_Extract
AS
BEGIN;

SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @RowCt INT;

TRUNCATE TABLE dbo.Suppliers_Stage;

INSERT INTO dbo.Suppliers_Stage (
SupplierName,
SupplierCategoryName,
PhoneNumber,
FaxNumber,
WebsiteURL
)

SELECT sup.SupplierName,
scat.SupplierCategoryName,
sup.PhoneNumber,
sup.FaxNumber,
sup.WebsiteURL
FROM WideWorldImporters.Purchasing.Suppliers sup
LEFT JOIN WideWorldImporters.Purchasing.SupplierCategories scat
ON sup.SupplierCategoryID = scat.SupplierCategoryID;

SET @RowCt = @@ROWCOUNT;
IF @RowCt = 0
BEGIN;
THROW 50001, 'No records found. Check with source system.', 1;
END;
END;

GO

CREATE PROCEDURE dbo.Products_Extract
AS
BEGIN;

SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @RowCt INT;

TRUNCATE TABLE dbo.Products_Stage;

INSERT INTO dbo.Products_Stage (
ProductName,
ProductColour,
ProductBrand,
ProductSize)

SELECT pr.StockItemName,
cl.ColorName,
pr.Brand,
pr.Size
FROM WideWorldImporters.Warehouse.StockItems pr
LEFT JOIN WideWorldImporters.Warehouse.Colors cl
ON pr.ColorID = cl.ColorID;

SET @RowCt = @@ROWCOUNT;
IF @RowCt = 0
BEGIN;
THROW 50001, 'No records found. Check with source system.', 1;
END;
END;

GO
CREATE PROCEDURE dbo.SalesPeople_Extract
AS
BEGIN;

SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @RowCt INT;

TRUNCATE TABLE dbo.SalesPeople_Stage;

INSERT INTO dbo.SalesPeople_Stage (
FullName,
PreferredName,
LogonName,
PhoneNumber,
FaxNumber,
EmailAddress)

SELECT ap.FullName,
ap.PreferredName,
ap.LogonName,
ap.PhoneNumber,
ap.FaxNumber,
ap.EmailAddress
FROM WideWorldImporters.Application.People ap
WHERE ap.IsSalesperson = 1;

SET @RowCt = @@ROWCOUNT;
IF @RowCt = 0
BEGIN;
THROW 50001, 'No records found. Check with source system.', 1;
END;
END;

GO
CREATE PROCEDURE dbo.Orders_Extract(
@OrderDate DATE)
AS
BEGIN;

SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @RowCt INT;

TRUNCATE TABLE dbo.Orders_Stage;

WITH CityDetails AS (
SELECT ci.CityID,
ci.CityName,
sp.StateProvinceCode,
sp.StateProvinceName,
co.CountryName,
co.FormalName
FROM WideWorldImporters.Application.Cities ci
LEFT JOIN WideWorldImporters.Application.StateProvinces sp
ON ci.StateProvinceID = sp.StateProvinceID
LEFT JOIN WideWorldImporters.Application.Countries co
ON sp.CountryID = co.CountryID )

INSERT INTO dbo.Orders_Stage (
OrderDate,
Quantity,
UnitPrice,
TaxRate,
CustomerName,
CityName,
StateProvinceName,
CountryName,
StockItemName,
SupplierName,
LogonName)

SELECT so.OrderDate,
sol.Quantity,
sol.UnitPrice,
sol.TaxRate,
cust.CustomerName,
dc.CityName,
dc.StateProvinceName,
dc.CountryName,
wh.StockItemName,
sp.SupplierName,
ap.LogonName
FROM WideWorldImporters.Sales.Orders so
LEFT JOIN WideWorldImporters.Sales.OrderLines sol
ON so.OrderID = sol.OrderID
LEFT JOIN WideWorldImporters.Sales.Customers cust
ON so.CustomerID = cust.CustomerID
LEFT JOIN CityDetails dc
ON cust.DeliveryCityID = dc.CityID
LEFT JOIN WideWorldImporters.Warehouse.StockItems wh
ON sol.StockItemID = wh.StockItemID
LEFT JOIN WideWorldImporters.Purchasing.Suppliers sp
ON wh.SupplierID = sp.SupplierID
LEFT JOIN WideWorldImporters.Application.People ap
ON so.SalespersonPersonID = ap.PersonID

WHERE so.OrderDate = @OrderDate;

SET @RowCt = @@ROWCOUNT;
IF @RowCt = 0
BEGIN;
THROW 50001, 'No records found. Check with source system.', 1;
END;
END;

--PRELOAD
GO

CREATE TABLE dbo.Cities_Preload (
CityKey INT NOT NULL,
CityName NVARCHAR(50) NULL,
StateProvCode NVARCHAR(5) NULL,
StateProvName NVARCHAR(50) NULL,
CountryName NVARCHAR(60) NULL,
CountryFormalName NVARCHAR(60) NULL,
CONSTRAINT PK_Cities_Preload PRIMARY KEY CLUSTERED ( CityKey )
);

CREATE TABLE dbo.Customers_Preload (
CustomerKey INT NOT NULL,
CustomerName NVARCHAR(100) NULL,
CustomerCategoryName NVARCHAR(50) NULL,
DeliveryCityName NVARCHAR(50) NULL,
DeliveryStateProvCode NVARCHAR(5) NULL,
DeliveryCountryName NVARCHAR(50) NULL,
PostalCityName NVARCHAR(50) NULL,
PostalStateProvCode NVARCHAR(5) NULL,
PostalCountryName NVARCHAR(50) NULL,
StartDate DATE NOT NULL,
EndDate DATE NULL,
CONSTRAINT PK_Customers_Preload PRIMARY KEY CLUSTERED ( CustomerKey )
);

CREATE TABLE dbo.Products_Preload(
ProductKey INT NOT NULL,
ProductName NVARCHAR(100) NULL,
ProductColour NVARCHAR(20) NULL,
ProductBrand NVARCHAR(50) NULL,
ProductSize NVARCHAR(20) NULL,
StartDate DATE NOT NULL,
EndDate DATE NULL,
CONSTRAINT PK_DimProducts_Preload PRIMARY KEY CLUSTERED ( ProductKey )
);

CREATE TABLE dbo.SalesPeople_Preload(
SalespersonKey INT NOT NULL,
FullName NVARCHAR(50) NULL,
PreferredName NVARCHAR(50) NULL,
LogonName NVARCHAR(50) NULL,
PhoneNumber NVARCHAR(20) NULL,
FaxNumber NVARCHAR(20) NULL,
EmailAddress NVARCHAR(256) NULL,
CONSTRAINT PK_DimSalesPeople_Preload PRIMARY KEY CLUSTERED (SalespersonKey )
);

CREATE TABLE dbo.Suppliers_Preload(
SupplierKey INT NOT NULL,
SupplierName NVARCHAR(100) NULL,
SupplierCategoryName NVARCHAR(50) NULL,
PhoneNumber NVARCHAR(20) NULL,
FaxNumber NVARCHAR(20) NULL,
WebsiteURL NVARCHAR(256) NULL,
StartDate DATE NOT NULL,
EndDate DATE NULL,
CONSTRAINT PK_DimSuppliers_Preload PRIMARY KEY CLUSTERED ( SupplierKey )
);

CREATE TABLE dbo.Orders_Preload (
CustomerKey INT NOT NULL,
CityKey INT NOT NULL,
ProductKey INT NOT NULL,
SalespersonKey INT NOT NULL,
SupplierKey INT NOT NULL,
DateKey INT NOT NULL,
Quantity INT NOT NULL,
UnitPrice DECIMAL(18, 2) NOT NULL,
TaxRate DECIMAL(18, 3) NOT NULL,
TotalBeforeTax DECIMAL(18, 2) NOT NULL,
TotalAfterTax DECIMAL(18, 2) NOT NULL,
);

GO
--SEQUENCES
CREATE SEQUENCE dbo.CityKey START WITH 1;
CREATE SEQUENCE dbo.CustomerKey START WITH 1;
CREATE SEQUENCE dbo.ProductKey START WITH 1;
CREATE SEQUENCE dbo.SalespersonKey START WITH 1;
CREATE SEQUENCE dbo.SupplierKey START WITH 1;


--TRANSFORM

--TYPE 1 SCD
GO
CREATE PROCEDURE dbo.Cities_Transform
AS
BEGIN;
SET NOCOUNT ON;
SET XACT_ABORT ON;
TRUNCATE TABLE dbo.Cities_Preload;
BEGIN TRANSACTION;
INSERT INTO dbo.Cities_Preload /* Column list excluded for brevity */
SELECT NEXT VALUE FOR dbo.CityKey AS CityKey,
cu.DeliveryCityName,
cu.DeliveryStateProvinceCode,
cu.DeliveryStateProvinceName,
cu.DeliveryCountryName,
cu.DeliveryFormalName
FROM dbo.Customers_Stage cu
WHERE NOT EXISTS ( SELECT 1
FROM dbo.DimCities ci
WHERE cu.DeliveryCityName = ci.CityName
AND cu.DeliveryStateProvinceName = ci.StateProvName
AND cu.DeliveryCountryName = ci.CountryName );
INSERT INTO dbo.Cities_Preload /* Column list excluded for brevity */
SELECT ci.CityKey,
cu.DeliveryCityName,
cu.DeliveryStateProvinceCode,
cu.DeliveryStateProvinceName,
cu.DeliveryCountryName,
cu.DeliveryFormalName
FROM dbo.Customers_Stage cu
JOIN dbo.DimCities ci
ON cu.DeliveryCityName = ci.CityName
AND cu.DeliveryStateProvinceName = ci.StateProvName
AND cu.DeliveryCountryName = ci.CountryName;
COMMIT TRANSACTION;
END;

--TYPE2 SCD
GO
CREATE PROCEDURE dbo.Customers_Transform
AS
BEGIN;
SET NOCOUNT ON;
SET XACT_ABORT ON;
TRUNCATE TABLE dbo.Customers_Preload;
DECLARE @StartDate DATE = GETDATE();
DECLARE @EndDate DATE = DATEADD(dd,-1,GETDATE());
BEGIN TRANSACTION;
-- Add updated records
INSERT INTO dbo.Customers_Preload /* Column list excluded for brevity */
SELECT NEXT VALUE FOR dbo.CustomerKey AS CustomerKey,
stg.CustomerName,
stg.CustomerCategoryName,
stg.DeliveryCityName,
stg.DeliveryStateProvinceCode,
stg.DeliveryCountryName,
stg.PostalCityName,
stg.PostalStateProvinceCode,
stg.PostalCountryName,
@StartDate,
NULL
FROM dbo.Customers_Stage stg
JOIN dbo.DimCustomers cu
ON stg.CustomerName = cu.CustomerName
AND cu.EndDate IS NULL
WHERE stg.CustomerCategoryName <> cu.CustomerCategoryName
OR stg.DeliveryCityName <> cu.DeliveryCityName
OR stg.DeliveryStateProvinceCode <> cu.DeliveryStateProvCode
OR stg.DeliveryCountryName <> cu.DeliveryCountryName
OR stg.PostalCityName <> cu.PostalCityName
OR stg.PostalStateProvinceCode <> cu.PostalStateProvCode
OR stg.PostalCountryName <> cu.PostalCountryName;
-- Add existing records, and expire as necessary
INSERT INTO dbo.Customers_Preload /* Column list excluded for brevity */
SELECT cu.CustomerKey,
cu.CustomerName,
cu.CustomerCategoryName,
cu.DeliveryCityName,
cu.DeliveryStateProvCode,
cu.DeliveryCountryName,
cu.PostalCityName,
cu.PostalStateProvCode,
cu.PostalCountryName,
cu.StartDate,
CASE
WHEN pl.CustomerName IS NULL THEN NULL
ELSE @EndDate
END AS EndDate
FROM dbo.DimCustomers cu
LEFT JOIN dbo.Customers_Preload pl
ON pl.CustomerName = cu.CustomerName
AND cu.EndDate IS NULL;
-- Create new records
INSERT INTO dbo.Customers_Preload /* Column list excluded for brevity */
SELECT NEXT VALUE FOR dbo.CustomerKey AS CustomerKey,
stg.CustomerName,
stg.CustomerCategoryName,
stg.DeliveryCityName,
stg.DeliveryStateProvinceCode,
stg.DeliveryCountryName,
stg.PostalCityName,
stg.PostalStateProvinceCode,
stg.PostalCountryName,
@StartDate,
NULL
FROM dbo.Customers_Stage stg
WHERE NOT EXISTS ( SELECT 1 FROM dbo.DimCustomers cu WHERE stg.CustomerName =
cu.CustomerName );
-- Expire missing records
INSERT INTO dbo.Customers_Preload /* Column list excluded for brevity */
SELECT cu.CustomerKey,
cu.CustomerName,
cu.CustomerCategoryName,
cu.DeliveryCityName,
cu.DeliveryStateProvCode,
cu.DeliveryCountryName,
cu.PostalCityName,
cu.PostalStateProvCode,
cu.PostalCountryName,
cu.StartDate,
@EndDate
FROM dbo.DimCustomers cu
WHERE NOT EXISTS ( SELECT 1 FROM dbo.Customers_Stage stg WHERE stg.CustomerName =
cu.CustomerName )
AND cu.EndDate IS NULL;
COMMIT TRANSACTION;
END;

GO
CREATE PROCEDURE dbo.SalesPeople_Transform
AS
BEGIN;
SET NOCOUNT ON;
SET XACT_ABORT ON;
TRUNCATE TABLE dbo.SalesPeople_Preload;
BEGIN TRANSACTION;
INSERT INTO dbo.SalesPeople_Preload /* Column list excluded for brevity */
SELECT NEXT VALUE FOR dbo.SalespersonKey AS SalespersonKey,
sps.FullName,
sps.PreferredName,
sps.LogonName,
sps.PhoneNumber,
sps.FaxNumber,
sps.EmailAddress
FROM dbo.SalesPeople_Stage sps
JOIN dbo.DimSalesPeople sp
ON sps.FullName = sp.FullName
COMMIT TRANSACTION;
END;

GO
CREATE PROCEDURE dbo.Products_Transform
AS
BEGIN;
SET NOCOUNT ON;
SET XACT_ABORT ON;
TRUNCATE TABLE dbo.Products_Preload;
DECLARE @StartDate DATE = GETDATE();
DECLARE @EndDate DATE = DATEADD(dd,-1,GETDATE());
BEGIN TRANSACTION;
-- Add updated records
INSERT INTO dbo.Products_Preload /* Column list excluded for brevity */
SELECT NEXT VALUE FOR dbo.ProductKey AS ProductKey,
stg.ProductName,
stg.ProductColour,
stg.ProductBrand,
stg.ProductSize,
@StartDate,
NULL
FROM dbo.Products_Stage stg
JOIN dbo.DimProducts pu
ON stg.ProductName = pu.ProductName
AND pu.EndDate IS NULL
WHERE stg.ProductColour <> pu.ProductColour
OR stg.ProductBrand <> pu.ProductBrand
OR stg.ProductSize <> pu.ProductSize;
-- Add existing records, and expire as necessary
INSERT INTO dbo.Products_Preload /* Column list excluded for brevity */
SELECT pu.ProductKey,
pu.ProductName,
pu.ProductColour,
pu.ProductBrand,
pu.ProductSize,
pu.StartDate,
CASE
WHEN pl.ProductName IS NULL THEN NULL
ELSE @EndDate
END AS EndDate
FROM dbo.DimProducts pu
LEFT JOIN dbo.Products_Preload pl
ON pl.ProductName = pu.ProductName
AND pu.EndDate IS NULL;
-- Create new records
INSERT INTO dbo.Products_Preload /* Column list excluded for brevity */
SELECT NEXT VALUE FOR dbo.ProductKey AS ProductKey,
stg.ProductName,
stg.ProductColour,
stg.ProductBrand,
stg.ProductSize,
@StartDate,
NULL
FROM dbo.Products_Stage stg
WHERE NOT EXISTS ( SELECT 1 FROM dbo.DimProducts pu WHERE stg.ProductName =
pu.ProductName );
-- Expire missing records
INSERT INTO dbo.Products_Preload /* Column list excluded for brevity */
SELECT pu.ProductKey,
pu.ProductName,
pu.ProductColour,
pu.ProductBrand,
pu.ProductSize,
pu.StartDate,
@EndDate
FROM dbo.DimProducts pu
WHERE NOT EXISTS ( SELECT 1 FROM dbo.Products_Stage stg WHERE stg.ProductName =
pu.ProductName )
AND pu.EndDate IS NULL;
COMMIT TRANSACTION;
END;

GO
CREATE PROCEDURE dbo.Suppliers_Transform
AS
BEGIN;
SET NOCOUNT ON;
SET XACT_ABORT ON;
TRUNCATE TABLE dbo.Suppliers_Preload;
DECLARE @StartDate DATE = GETDATE();
DECLARE @EndDate DATE = DATEADD(dd,-1,GETDATE());
BEGIN TRANSACTION;
-- Add updated records
INSERT INTO dbo.Suppliers_Preload /* Column list excluded for brevity */
SELECT NEXT VALUE FOR dbo.SupplierKey AS SupplierKey,
stg.SupplierName,
stg.SupplierCategoryName,
stg.PhoneNumber,
stg.FaxNumber,
stg.WebsiteURL,
@StartDate,
NULL
FROM dbo.Suppliers_Stage stg
JOIN dbo.DimSuppliers su
ON stg.SupplierName = su.SupplierName
AND su.EndDate IS NULL
WHERE stg.SupplierCategoryName <> su.SupplierCategoryName
OR stg.PhoneNumber <> su.PhoneNumber
OR stg.FaxNumber <> su.FaxNumber
OR stg.WebsiteURL <> su.WebsiteURL;
-- Add existing records, and expire as necessary
INSERT INTO dbo.Suppliers_Preload /* Column list excluded for brevity */
SELECT su.SupplierKey,
su.SupplierName,
su.SupplierCategoryName,
su.PhoneNumber,
su.FaxNumber,
su.WebsiteURL,
su.StartDate,
CASE
WHEN pl.SupplierName IS NULL THEN NULL
ELSE @EndDate
END AS EndDate
FROM dbo.DimSuppliers su
LEFT JOIN dbo.Suppliers_Preload pl
ON pl.SupplierName = su.SupplierName
AND su.EndDate IS NULL;
-- Create new records
INSERT INTO dbo.Suppliers_Preload /* Column list excluded for brevity */
SELECT NEXT VALUE FOR dbo.SupplierKey AS SupplierKey,
stg.SupplierName,
stg.SupplierCategoryName,
stg.PhoneNumber,
stg.FaxNumber,
stg.WebsiteURL,
@StartDate,
NULL
FROM dbo.Suppliers_Stage stg
WHERE NOT EXISTS ( SELECT 1 FROM dbo.DimSuppliers su WHERE stg.SupplierName =
su.SupplierName );
-- Expire missing records
INSERT INTO dbo.Suppliers_Preload /* Column list excluded for brevity */
SELECT su.SupplierKey,
su.SupplierName,
su.SupplierCategoryName,
su.PhoneNumber,
su.FaxNumber,
su.WebsiteURL,
su.StartDate,
@EndDate
FROM dbo.DimSuppliers su
WHERE NOT EXISTS ( SELECT 1 FROM dbo.Suppliers_Stage stg WHERE stg.SupplierName =
su.SupplierName )
AND su.EndDate IS NULL;
COMMIT TRANSACTION;
END;

GO
CREATE PROCEDURE dbo.Orders_Transform
AS
BEGIN;
SET NOCOUNT ON;
SET XACT_ABORT ON;
TRUNCATE TABLE dbo.Orders_Preload;
INSERT INTO dbo.Orders_Preload
( CustomerKey ,
CityKey ,
ProductKey ,
SalespersonKey ,
SupplierKey,
DateKey ,
Quantity ,
UnitPrice ,
TaxRate ,
TotalBeforeTax ,
TotalAfterTax )

SELECT cu.CustomerKey,
ci.CityKey,
pr.ProductKey,
sp.SalespersonKey,
su.SupplierKey,
CAST(YEAR(ord.OrderDate) * 10000 + MONTH(ord.OrderDate) * 100 + DAY(ord.OrderDate) AS
INT) AS DateKey,
(ord.Quantity) AS Quantity,
(ord.UnitPrice) AS UnitPrice,
(ord.TaxRate) AS TaxRate,
(ord.Quantity * ord.UnitPrice) AS TotalBeforeTax,
(ord.Quantity * ord.UnitPrice * (1 + ord.TaxRate/100)) AS TotalAfterTax
FROM dbo.Orders_Stage ord
JOIN dbo.Customers_Preload cu
ON ord.CustomerName = cu.CustomerName
JOIN dbo.Cities_Preload ci
ON ord.CityName = ci.CityName
AND ord.StateProvinceName = ci.StateProvName
AND ord.CountryName = ci.CountryName
JOIN dbo.Products_Preload pr
ON ord.StockItemName = pr.ProductName
JOIN dbo.SalesPeople_Preload sp
ON ord.LogonName = sp.LogonName
JOIN dbo.Suppliers_Preload su
ON ord.SupplierName = su.SupplierName
;
END;
GO
--LOAD
CREATE PROCEDURE dbo.Customers_Load
AS
BEGIN;
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
DELETE cu
FROM dbo.DimCustomers cu
JOIN dbo.Customers_Preload pl
ON cu.CustomerKey = pl.CustomerKey;
INSERT INTO dbo.DimCustomers /* Columns excluded for brevity */
SELECT * /* Columns excluded for brevity */
FROM dbo.Customers_Preload;
COMMIT TRANSACTION;
END;

GO
CREATE PROCEDURE dbo.Cities_Load
AS
BEGIN;
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
DELETE ci
FROM dbo.DimCities ci
JOIN dbo.Cities_Preload pl
ON ci.CityKey = pl.CityKey;
INSERT INTO dbo.DimCities /* Columns excluded for brevity */
SELECT * /* Columns excluded for brevity */
FROM dbo.Cities_Preload;
COMMIT TRANSACTION;
END;

GO
CREATE PROCEDURE dbo.Products_Load
AS
BEGIN;
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
DELETE pr
FROM dbo.DimProducts pr
JOIN dbo.Products_Preload pl
ON pr.ProductKey = pl.ProductKey;
INSERT INTO dbo.DimProducts /* Columns excluded for brevity */
SELECT * /* Columns excluded for brevity */
FROM dbo.Products_Preload;
COMMIT TRANSACTION;
END;

GO
CREATE PROCEDURE dbo.SalesPeople_Load
AS
BEGIN;
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
DELETE sp
FROM dbo.DimSalesPeople sp
JOIN dbo.SalesPeople_Preload pl
ON sp.SalespersonKey = pl.SalespersonKey;
INSERT INTO dbo.DimSalesPeople /* Columns excluded for brevity */
SELECT * /* Columns excluded for brevity */
FROM dbo.SalesPeople_Preload;
COMMIT TRANSACTION;
END;

GO
CREATE PROCEDURE dbo.Suppliers_Load
AS
BEGIN;
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
DELETE su
FROM dbo.DimSuppliers su
JOIN dbo.Suppliers_Preload pl
ON su.SupplierKey = pl.SupplierKey;
INSERT INTO dbo.DimSuppliers /* Columns excluded for brevity */
SELECT * /* Columns excluded for brevity */
FROM dbo.Suppliers_Preload;
COMMIT TRANSACTION;
END;

GO
CREATE PROCEDURE dbo.Orders_Load
AS
BEGIN;
SET NOCOUNT ON;
SET XACT_ABORT ON;
INSERT INTO dbo.FactOrders /* Columns excluded for brevity */
SELECT * /* Columns excluded for brevity */
FROM dbo.Orders_Preload;
END;
