/*
Chapter 1 - Schema creation and file import

Created project schemas, imported source files,
checked data types and primary keys, and previewed the tables.
*/

-- Project schemas: raw, cleaned, analytical, reporting

IF SCHEMA_ID('src') IS NULL
    EXEC('CREATE SCHEMA src');
GO

IF SCHEMA_ID('cleaned') IS NULL
    EXEC('CREATE SCHEMA cleaned');
GO

IF SCHEMA_ID('analytics') IS NULL
    EXEC('CREATE SCHEMA analytics');
GO

IF SCHEMA_ID('reporting') IS NULL
    EXEC('CREATE SCHEMA reporting');
GO

-- Row counts after import

SELECT 'Users' AS table_name, COUNT(*) AS row_count
FROM src.users

UNION ALL

SELECT 'Products', COUNT(*)
FROM src.products

UNION ALL 

SELECT 'Orders', COUNT(*) 
FROM src.orders

UNION ALL 

SELECT 'Order_items', COUNT(*)
FROM src.order_items

UNION ALL 

SELECT 'Inventory_items', COUNT(*)
FROM src.inventory_items 

UNION ALL 

SELECT 'Distribution_centers', COUNT(*)
FROM src.distribution_centers

UNION ALL 

SELECT 'Events', COUNT(*)
FROM src.events;

-- Column names, data types and keys of each source table

EXEC sp_help 'src.users';
EXEC sp_help 'src.distribution_centers';
EXEC sp_help 'src.inventory_items';
EXEC sp_help 'src.order_items';
EXEC sp_help 'src.orders';
EXEC sp_help 'src.products';
EXEC sp_help 'src.events';

-- distribution_centers.id imported as nullable.
-- The primary key has to be dropped before the column can be set NOT NULL.

ALTER TABLE src.distribution_centers
DROP CONSTRAINT PK_distribution_centers;

ALTER TABLE src.distribution_centers
ALTER COLUMN id int NOT NULL;

ALTER TABLE src.distribution_centers
ADD CONSTRAINT PK_distribution_centers
PRIMARY KEY (id);


-- Preview each source table

SELECT TOP 20 *
FROM src.users;

SELECT TOP 20 *
FROM src.products;

SELECT TOP 20 *
FROM src.orders;

SELECT TOP 20 *
FROM src.inventory_items;

SELECT TOP 20 *
FROM src.order_items;

SELECT TOP 20 *
FROM src.distribution_centers;

SELECT TOP 20 *
FROM src.events;

