CREATE DATABASE Online_Shop;

USE Online_Shop;

/*Imported file online_retail, containing 1 year of sales data from an online store.  First to make sure the data is in a good format to work with 

First to check the start and finish date of this data, if we use a monthly rolling average, partial months will skew the data*/


SELECT  MIN(InvoiceDate), MAX(InvoiceDate) FROM online_retail;


-- Datatype in price is messy and doesn't apply to the real world, we will change this to Money

ALTER TABLE online_retail
ALTER COLUMN UnitPrice MONEY;

-- Remove NULLs from CustomerID, these can be treated as Adhoc orders from unregistered customers, first allowing CustomerID to accept Adhoc as a value.

ALTER TABLE online_retail
ALTER COLUMN customerID NVARCHAR(20);

UPDATE online_retail
SET CustomerID = 'Adhoc'
WHERE CustomerId IS NULL;

/* First to look at some basic information about registered customers - we are excluding Adhoc clients as we don't have user data on these
I would use this data to plot on a scatter graph ATV and TotalOrders, do more regular clients spend more per transaction? We could also look at 
TotalOrders and TotalSpend - is customer spend correlated to number of orders. We would assume it is, but this is not always the case. */


With CustTotal as(
SELECT  COUNT(DISTINCT InvoiceNo) AS CustomerOrders, CustomerID, CAST(SUM(UnitPrice)*Quantity AS MONEY) AS OrderValue FROM online_retail

GROUP BY CustomerId, Quantity
)
Select CustomerID, SUM(CustomerOrders) As TotalOrders, SUM(OrderValue) AS TotalSpend, SUM(OrderValue)/SUM(CustomerOrders) AS ATV FROM CustTotal
WHERE CustomerId != 'Adhoc'
GROUP BY CustomerId
ORDER BY TotalSpend DESC;

/*We have set of clients who have a negative TotalSpend,  this could be worth investigating. Possibly some returns have happened, where the 
orders were placed before this dataset commenced. Definitely worth investigating to ensure there isn't a flaw in the system. 
Some clients are returning every item they order - is there an issue here? It will definitely be worth contacting these customers to see if the issue can
be resolved, in order to develop a positive net spend with these clients

Back to the data, time to look at some weekly averages, to look at spending trends . There are some NULL values in description,
in addition to some ? rows - we will remove these as they are a fraction of a percent of this data and also as we won't be using them in 
further analysis by product, we will excluse them from these results*/

WITH Date AS
(
SELECT  Description, quantity, quantity * unitprice AS Revenue, invoiceno , 
DATEPART(WEEK, InvoiceDate ) AS WEEK, DATEPART(Year, InvoiceDate ) AS Year FROM online_retail
WHERE NOT Description LIKE ('?%') AND Description IS NOT NULL 
GROUP BY Description, Quantity, unitprice, InvoiceDate, invoiceno
)
SELECT Week, Year, SUM(Revenue) AS WeeklySales, COUNT(DISTINCT InvoiceNo) AS WeeklyOrders,

  CAST(AVG(SUM(Revenue)) OVER(ORDER BY YEAR, Week
     ROWS BETWEEN 7 PRECEDING AND CURRENT ROW ) AS DECIMAL (8,2))
     AS EightWeekAverageRevenue,
	AVG(COUNT(DISTINCT InvoiceNo)) OVER (ORDER BY YEAR, WEEK
	ROWS Between 7 PRECEDING AND CURRENT ROW) AS EightWeekAverageOrders
	 
FROM Date
GROUP BY  Week, Year

HAVING  YEAR = 2011
ORDER BY Year, Week;

/* Now to look at Average Transaction Value, average basket size across the business, by week.*/


SELECT DATEPART(Week, InvoiceDate) AS Week ,DATEPART(Year, InvoiceDate ) AS Year,
CAST(SUM(Quantity*UnitPrice)/COUNT(DISTINCT InvoiceNo) AS DECIMAL (8,2)) AS ATV, 
SUM(Quantity)/COUNT(DISTINCT InvoiceNo) AS AverageBasketSize FROM  online_retail
WHERE NOT Description LIKE ('?%') AND Description IS NOT NULL AND DATEPART(Year, InvoiceDate )= 2011
GROUP BY DATEPART(Week, InvoiceDate), DATEPART(Year, InvoiceDate )
ORDER BY WEEK;


/* And Customers, retention rate is an important metric to track, in this case, a very high rate */


with customers as(
SELECT CustomerId,
ROW_Number() OVER(Partition BY CustomerId ORDER BY CustomerID) as RowNumber
 FROM Online_retail
 WHERE CustomerID != 'Adhoc'
 ), RepeatCustomers AS
	(
	 Select DISTINCT CustomerId FROM customers
	 WHERE RowNumber > 1 )
	 , New AS
		 (SELECT DISTINCT CustomerId FROM customers
		 WHERE RowNumber <= 1)

		 SELECT 
			CASE WHEN r.CustomerID IS NOT NULL
			THEN 'repeat' 	ELSE 'new' 	END AS RepeatNew,	 
			FORMAT(cast(count(*) as decimal(18,2))/cast((select count(distinct CustomerID) from customers) as decimal(18,2)), 'P') as RepeatRate,
			COUNT(*) AS NumberOfCustomer 
				FROM New n
			LEFT JOIN RepeatCustomers r ON n.CustomerID = r.CustomerID 
			GROUP BY 	CASE
			WHEN r.CustomerID IS NOT NULL	THEN 'repeat'	ELSE 'new'	END;

-- And Top 10 selling products

WITH Date AS
(
SELECT  Description, quantity, quantity * unitprice AS Revenue, 
 DATEPART(Year, InvoiceDate ) AS Year FROM online_retail
WHERE NOT Description LIKE ('?%') AND Description IS NOT NULL 
GROUP BY Description, Quantity, unitprice, InvoiceDate, invoiceno
)
SELECT TOP 10 Description, Year, SUM(Revenue) AS Sales
	 
FROM Date
GROUP BY  Description , Year


HAVING  YEAR = 2011 AND Description != 'DOTCOM POSTAGE'
-- Postage, although the highest revenue line, is not a product and best excluded from this data
ORDER BY Sales DESC;
	