SELECT * FROM sales_data

--Checking Unique Values

SELECT DISTINCT [Status] FROM sales_data
SELECT DISTINCT YEAR_ID FROM sales_data
SELECT DISTINCT PRODUCTLINE FROM sales_data
SELECT DISTINCT COUNTRY FROM sales_data
SELECT DISTINCT DEALSIZE FROM sales_data
SELECT DISTINCT TERRITORY FROM sales_data

SELECT MAX(ORDERDATE)
FROM sales_data
WHERE YEAR_ID  = 2004

--Analysis
--Grouping sales by product line

SELECT PRODUCTLINE, SUM(Sales) AS Revenue
FROM sales_data
GROUP BY PRODUCTLINE
ORDER BY 2 DESC


SELECT YEAR_ID, SUM(Sales) AS Revenue
FROM sales_data
GROUP BY YEAR_ID
ORDER BY 2 DESC

SELECT DEALSIZE, SUM(Sales) AS Revenue
FROM sales_data
GROUP BY DEALSIZE
ORDER BY 2 DESC

--What was the best month for sales in a specific year? How much was earned that month?

SELECT MONTH_ID as SalesMonth, SUM(Sales) AS Revenue, COUNT(ORDERNUMBER) AS Frequency 
FROM sales_data
WHERE YEAR_ID = 2003 --Change year to see next rest
GROUP BY MONTH_ID
ORDER BY 2 DESC


--November seems to be the month, What product do they sell in November? Should be Classic Cars.

SELECT PRODUCTLINE, MONTH_ID as SalesMonth, SUM(Sales) AS Revenue, COUNT(ORDERNUMBER) AS Frequency 
FROM sales_data
WHERE YEAR_ID = 2003 AND MONTH_ID = 11  --Change year to see next rest
GROUP BY MONTH_ID, PRODUCTLINE
ORDER BY 3 DESC

-- Who is our best customer (Applying RFM)

DROP TABLE IF EXISTS #RFM;
WITH RFM AS 
(
	SELECT
		CUSTOMERNAME,
		SUM(SALES) AS MonetaryValue,
		AVG(SALES) AS AvgMonetaryValue,
		COUNT(ORDERNUMBER) AS Frequency,
		MAX(ORDERDATE) AS LastOrderDate,
		(SELECT MAX(ORDERDATE) FROM sales_data) max_order_date,
		DATEDIFF(DD, MAX(ORDERDATE), (SELECT MAX(ORDERDATE) FROM sales_data)) AS Recency
	FROM
		sales_data
	GROUP BY
		CUSTOMERNAME
),

RFM_CALC AS
(
	SELECT R.*,
		   NTILE(4) OVER(ORDER BY Recency DESC) RFM_Recency,
		   NTILE(4) OVER(ORDER BY Frequency) RFM_Frequency,
		   NTILE(4) OVER(ORDER BY MonetaryValue) RFM_Monetary
	FROM
		RFM R
)

SELECT
	C.*, RFM_Recency + RFM_Frequency + RFM_Monetary AS RFM_Cell,
	CAST(RFM_Recency AS varchar) + CAST(RFM_Frequency AS varchar) + CAST(RFM_Monetary AS varchar) AS RFM_Cell_STR
INTO #RFM
FROM
	RFM_CALC C

SELECT
	CUSTOMERNAME, RFM_Recency, RFM_Frequency, RFM_Monetary,
CASE 
	WHEN RFM_Cell_STR IN (111, 112, 121, 122, 123, 132, 211, 212, 114, 141) THEN 'Lost_Customers'  --Lost Customers
	WHEN RFM_Cell_STR IN (133, 134, 143, 244, 334, 343, 344) THEN 'Slipping away, cannot lose' --(Big Spenders who haven't purchased lately)
	WHEN RFM_Cell_STR IN (311, 411, 331) THEN 'New Customers'
	WHEN RFM_Cell_STR IN (222, 223, 233, 322) THEN 'Potential Churners'
	WHEN RFM_Cell_STR IN (323, 333, 321, 422, 332, 432) THEN 'Active' --(Customers who buy often & recently)
	WHEN RFM_Cell_STR IN (433, 434, 443, 444) THEN 'Loyal'
END 
	AS RFM_Segment
FROM
	#RFM


--What Products are most often sold together?

SELECT DISTINCT ORDERNUMBER, STUFF(

	(SELECT ', ' + PRODUCTCODE
	FROM sales_data P
	WHERE ORDERNUMBER IN 
	(
		SELECT ORDERNUMBER
		FROM (
				SELECT ORDERNUMBER, COUNT(*) AS RN
				FROM sales_data
				WHERE [STATUS] = 'Shipped'
				GROUP BY ORDERNUMBER
			 ) A
		WHERE RN = 3
	)
	AND P.ORDERNUMBER = S.ORDERNUMBER
	 FOR XML PATH(''))
	 , 1, 1, '') AS ProductCodes

FROM sales_data S
ORDER BY 2 DESC