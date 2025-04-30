Objective:
---------
1)To determine whether any table has missing values or duplicates, I would follow a structured SQL-based and Python-based approach:

If yes, I would start by checking for Missing Values (NULLs) for each and every tables.

Handling Missing Values:

Primary Keys (e.g., customer_id, invoice_id): If NULLs exist, investigate the data source as these fields should always be populated. Missing values in primary keys indicate data integrity issues.
Foreign Keys (e.g., customer_id in invoice): If missing, it may suggest orphaned records that require further investigation. Options:
Remove records if they are not useful.
Assign a default or placeholder value (e.g., Unknown Customer).
Text Columns (e.g., company, address): Replace missing values with "Unknown" or an empty string ('').
Numeric Columns (e.g., unit_price, total): Use COALESCE(column, default_value) to replace missing values with appropriate defaults (e.g., 0 for monetary values).

Handling Duplicate Data:
Primary Key Duplicates: If primary keys have duplicates, investigate the source system. If errors exist, correct or remove the duplicate rows.
Non-Key Duplicates (e.g., duplicate invoice lines):
Keep only the latest record based on invoice_date.
If all fields are identical, remove duplicates using DISTINCT or ROW_NUMBER().
If discrepancies exist, apply aggregation methods (e.g., SUM for total values).

2) Find the top-selling tracks and top artist in the USA and identify their most famous genres. 
-- Top-selling tracks, top artist, and their most famous genres in the USA
WITH usa_sales AS (

    SELECT il.track_id, il.quantity, il.unit_price, 
           t.name AS track_name, a.artist_id, ar.name AS artist_name, g.genre_id, g.name AS genre_name, i.billing_country
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN album a ON t.album_id = a.album_id
    JOIN artist ar ON a.artist_id = ar.artist_id
    JOIN genre g ON t.genre_id = g.genre_id
    WHERE i.billing_country = 'USA'
)
SELECT 
    us.track_name AS top_selling_track, 
    us.artist_name AS top_artist,
    us.genre_name AS most_famous_genre,
    SUM(us.quantity * us.unit_price) AS total_sales,
    billing_country
FROM usa_sales us
GROUP BY us.track_id, us.artist_id, us.genre_id
ORDER BY total_sales DESC
LIMIT 10;
----------------------------------------------------------------------------------------------

3)What is the customer demographic breakdown (age, gender, location) of Chinook's customer base?

AgeGroup:
WITH cte AS (
    SELECT 
        country, 
        timestampdiff(YEAR, birthdate, curdate()) AS age
    FROM 
        employee
),
age_groups AS (
    SELECT 
        country, 
        CASE 
            WHEN age BETWEEN 51 AND 57 THEN '51-57'
            WHEN age BETWEEN 58 AND 64 THEN '58-64'
            WHEN age BETWEEN 65 AND 71 THEN '65-71'
        END AS age_group
    FROM 
        cte
 WHERE 
        age BETWEEN 51 AND 71
)
SELECT 
    ag.age_group, 
    COUNT(ct.customer_id) AS customer_count
FROM 
    age_groups ag
JOIN 
    customer ct ON ag.country = ct.country
GROUP BY 
    ag.age_group;

Location :
SELECT 
    Country,
    COUNT(*) AS Customer_Count
FROM 
    Customer
GROUP BY 
    Country
ORDER BY 
customer_count DESC
----------------------------------------------------------------------------------------------
4)

SELECT 
    c.country, 
    c.state, 
    c.city, 
    SUM(i.total) AS total_revenue, 
    COUNT(i.invoice_id) AS number_of_invoices
FROM 
    customer c
JOIN 
    invoice i ON c.customer_id = i.customer_id
GROUP BY 
    c.country, c.state, c.city
Order by number_of_invoices desc
----------------------------------------------------------------------------------------------
5)Find the top 5 customers by total revenue in each country

WITH CustomerRevenue AS (
    SELECT 
        c.customer_id,
        c.first_name,
        c.last_name,
        c.country,
        SUM(il.unit_price * il.quantity) AS total_revenue
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    GROUP BY c.customer_id, c.first_name, c.last_name, c.country
),
RankedCustomers AS (
    SELECT 
        cr.customer_id,
        cr.first_name,
        cr.last_name,
        cr.country,
        cr.total_revenue,
        ROW_NUMBER() OVER (PARTITION BY cr.country ORDER BY cr.total_revenue DESC) AS revenue_rank
    FROM CustomerRevenue cr
)
SELECT
    rc.customer_id,
    rc.first_name,
    rc.last_name,
    rc.country,
    rc.total_revenue
FROM RankedCustomers rc
WHERE rc.revenue_rank <= 5
ORDER BY rc.country,rc.total_revenue;
----------------------------------------------------------------------------------------------
6) 
WITH TrackSales AS (
    SELECT i.customer_id, 
           c.first_name, 
           c.last_name, 
           il.track_id, 
           t.name AS track_name, 
           SUM(il.quantity) AS total_purchased
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN customer c ON i.customer_id = c.customer_id
    GROUP BY i.customer_id, c.first_name, c.last_name, il.track_id, t.name
),
RankedTracks AS (
    SELECT ts.*, 
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY total_purchased DESC, track_id ASC) AS row_num
    FROM TrackSales ts
)
SELECT customer_id, 
       first_name, 
       last_name, 
       track_id, 
       track_name, 
       total_purchased
FROM RankedTracks
WHERE row_num = 1
ORDER BY customer_id;

7) Frequent purchasing :

WITH purchase_gaps AS (
    SELECT 
        i.customer_id, 
        i.invoice_date, 
        LAG(i.invoice_date) OVER (PARTITION BY i.customer_id ORDER BY i.invoice_date) AS previous_invoice_date
    FROM invoice i
)
SELECT 
    c.customer_id, 
    c.first_name, 
    c.last_name, 
    COUNT(i.invoice_id) AS total_purchases, 
    ROUND(AVG(DATEDIFF(i.invoice_date, pg.previous_invoice_date)), 2) AS avg_days_between_purchases
FROM customer c
LEFT JOIN invoice i ON c.customer_id = i.customer_id
LEFT JOIN purchase_gaps pg ON i.customer_id = pg.customer_id AND i.invoice_date = pg.invoice_date
WHERE pg.previous_invoice_date IS NOT NULL  -- Exclude first purchase (no previous date)
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_purchases DESC;

Avg_order_value :

SELECT 
    c.customer_id, 
    c.first_name, 
    c.last_name, 
    COUNT(i.invoice_id) AS total_orders, 
    SUM(i.total) AS total_spent, 
    ROUND(AVG(i.total), 2) AS avg_order_value
FROM customer c
LEFT JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY avg_order_value DESC;

----------------------------------------------------------------------------------------------
8) What is the customer churn rate?
WITH customer_activity AS (
    -- Find the last purchase date for each customer
    SELECT 
        c.customer_id, 
        MAX(i.invoice_date) AS last_purchase_date
    FROM customer c
    LEFT JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY c.customer_id
),
churned_customers AS (
    -- Identify customers who have not made a purchase in the last 6 months
    SELECT COUNT(*) AS churned_count
    FROM customer_activity
    WHERE last_purchase_date < DATE_SUB('2020-12-31 00:00:00', INTERVAL 6 MONTH)
),
total_customers AS (
    -- Count total customers at the start of the period
    SELECT COUNT(*) AS total_count FROM customer
)
-- Calculate churn rate
SELECT 
    ROUND((chc.churned_count / tc.total_count) * 100,2) AS churn_rate
FROM churned_customers chc, total_customers tc;



----------------------------------------------------------------------------------------------
9) WITH genre_sales AS (
    -- Calculate total sales per genre in the USA
    SELECT 
        g.genre_id,
        g.name AS genre_name,
        SUM(il.unit_price * il.quantity) AS total_genre_sales
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN genre g ON t.genre_id = g.genre_id
    WHERE i.billing_country = 'USA'
    GROUP BY g.genre_id, g.name
),
total_sales AS (
    -- Calculate total sales in the USA
    SELECT SUM(il.unit_price * il.quantity) AS total_usa_sales
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    WHERE i.billing_country = 'USA'
)
-- Compute percentage contribution of each genre
SELECT 
    gs.genre_name,
    ROUND((gs.total_genre_sales / ts.total_usa_sales) * 100, 2) AS sales_percentage
FROM genre_sales gs, total_sales ts
ORDER BY sales_percentage DESC;

-----
WITH artist_sales AS (
    -- Calculate total sales per artist in the USA
    SELECT 
        a.artist_id,
        a.name AS artist_name,
        SUM(il.unit_price * il.quantity) AS total_artist_sales
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN album al ON t.album_id = al.album_id
    JOIN artist a ON al.artist_id = a.artist_id
    WHERE i.billing_country = 'USA'
    GROUP BY a.artist_id, a.name
)
-- Rank artists by total sales in the USA
SELECT 
    artist_name, 
    total_artist_sales
FROM artist_sales
ORDER BY total_artist_sales DESC
LIMIT 10; -- Top 10 best-selling artists


----------------------------------------------------------------------------------------------
10)WITH customer_genre_count AS (
    -- Count unique genres each customer has purchased from
    SELECT 
        i.customer_id,
        COUNT(DISTINCT g.genre_id) AS genre_count
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN genre g ON t.genre_id = g.genre_id
    GROUP BY i.customer_id
)
-- Select customers with at least 3 different genres
SELECT 
    c.customer_id, 
    c.first_name, 
    c.last_name, 
    cg.genre_count as unique_genre_count
FROM customer_genre_count cg
JOIN customer c ON cg.customer_id = c.customer_id
WHERE cg.genre_count >= 3
ORDER BY cg.genre_count ASC;
----------------------------------------------------------------------------------------------
11) WITH genre_sales AS (
    -- Calculate total sales per genre in the USA
    SELECT 
        g.genre_id,
        g.name AS genre_name,
        SUM(il.unit_price * il.quantity) AS total_sales
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN genre g ON t.genre_id = g.genre_id
    WHERE i.billing_country = 'USA'
    GROUP BY g.genre_id, g.name
)
-- Rank genres based on total sales in descending order
SELECT 
    genre_name,
    total_sales,
    RANK() OVER (ORDER BY total_sales DESC) AS sales_rank
FROM genre_sales;

-------------------------------------------------------------------------------------------------------
12) Identify customers who have not made a purchase in the last 3 months

WITH customer_last_purchase AS (
    -- Find the last purchase date for each customer
    SELECT 
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        MAX(i.invoice_date) AS last_purchase_date
    FROM customer c
    LEFT JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY c.customer_id
)
-- Selecting  customers who haven't made a purchase in the last 3 months
SELECT 
    customer_id, 
    customer_name, 
    last_purchase_date
FROM customer_last_purchase
WHERE last_purchase_date < DATE_SUB('2020-12-30', INTERVAL 3 MONTH)
ORDER BY customer_id,last_purchase_date ASC;

-------------------------------------------------------------------------------------------------------
Subjective :
------------
1)WITH GenreSales AS (
    SELECT 
        g.genre_id, 
        g.name AS genre_name, 
        SUM(il.unit_price * il.quantity) AS total_sales
    FROM invoice_line il
    JOIN track t ON il.track_id = t.track_id
    JOIN genre g ON t.genre_id = g.genre_id
    JOIN invoice i ON il.invoice_id = i.invoice_id
    WHERE i.billing_country = 'USA'
    GROUP BY g.genre_id, g.name
), 

TopGenres AS (
    SELECT 
        genre_id, 
        genre_name
    FROM GenreSales
    ORDER BY total_sales DESC
    LIMIT 3
),

TopArtists AS (
    SELECT 
        a.artist_id, 
        a.name AS artist_name, 
        SUM(il.unit_price * il.quantity) AS artist_sales
    FROM invoice_line il
    JOIN track t ON il.track_id = t.track_id
    JOIN album al ON t.album_id = al.album_id
    JOIN artist a ON al.artist_id = a.artist_id
    JOIN invoice i ON il.invoice_id = i.invoice_id
    WHERE i.billing_country = 'USA' 
    AND t.genre_id IN (SELECT genre_id FROM TopGenres)
    GROUP BY a.artist_id, a.name
    ORDER BY artist_sales DESC
    LIMIT 3
),

TopAlbums AS (
    SELECT 
        al.album_id, 
        al.title AS album_title, 
        a.name AS artist_name, 
        SUM(il.unit_price * il.quantity) AS album_sales
    FROM invoice_line il
    JOIN track t ON il.track_id = t.track_id
    JOIN album al ON t.album_id = al.album_id
    JOIN artist a ON al.artist_id = a.artist_id
    JOIN invoice i ON il.invoice_id = i.invoice_id
    WHERE i.billing_country = 'USA'
    AND a.artist_id IN (SELECT artist_id FROM TopArtists)
    GROUP BY al.album_id, al.title, a.name
    ORDER BY album_sales DESC
    LIMIT 3
)

SELECT * FROM TopAlbums;
-------------------------------------------------------------------------------------------------------
2) SELECT
    g.name AS genre,
    SUM(il.quantity * il.unit_price) AS total_sales,
    COUNT(DISTINCT c.country) AS countries_count
FROM
    invoice_line il
JOIN
    invoice i ON il.invoice_id = i.invoice_id
JOIN
    customer c ON i.customer_id = c.customer_id
JOIN
    track t ON il.track_id = t.track_id
JOIN
    genre g ON t.genre_id = g.genre_id
WHERE
    c.country != 'USA'
GROUP BY
    g.name
HAVING
    countries_count > 0
ORDER BY
    total_sales DESC;

-------------------------------------------------------------------------------------------------------
3) Average Customer Spending by Country:

SELECT c.country, 
      --  COUNT(DISTINCT c.customer_id) AS total_customers,
       SUM(i.total) AS total_revenue,
       (SUM(i.total) / COUNT(DISTINCT c.customer_id)) AS avg_spending_per_customer
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.country
ORDER BY avg_spending_per_customer DESC;


Country wise total basket size:

SELECT  i.billing_country,
       SUM(il.quantity) AS total_basket_size
FROM invoice i
JOIN invoice_line il ON i.invoice_id = il.invoice_id
JOIN customer c ON i.customer_id = c.customer_id
GROUP BY i.billing_country 
ORDER BY total_basket_size DESC;


--Favorite Music Genres Among Customers:

--SELECT g.name AS genre, COUNT(il.track_id) AS track_purchases
--FROM invoice_line il
--JOIN track t ON il.track_id = t.track_id
--JOIN genre g ON t.genre_id = g.genre_id
--GROUP BY g.genre_id
--ORDER BY track_purchases DESC;


--country wise lifetime_value:

--SELECT c.country, 
       SUM(i.total) AS lifetime_value
--FROM customer c
--JOIN invoice i ON c.customer_id = i.customer_id
--GROUP BY c.country
--ORDER BY lifetime_value DESC;


-------------------------------------------------------------------------------------------------------
4) Genre Co-purchase count :

WITH GenrePurchases AS (
    SELECT i.invoice_id, g.name AS genre
    FROM invoice_line il
    JOIN track t ON il.track_id = t.track_id
    JOIN genre g ON t.genre_id = g.genre_id
    JOIN invoice i ON il.invoice_id = i.invoice_id
)
SELECT 
gp1.genre AS genre1, 
gp2.genre AS genre2,
CONCAT(gp1.genre, " & ", gp2.genre) AS genre_combo, 
COUNT(*) AS co_purchases
FROM GenrePurchases gp1
JOIN GenrePurchases gp2 ON gp1.invoice_id = gp2.invoice_id AND gp1.genre < gp2.genre
GROUP BY gp1.genre, gp2.genre
ORDER BY co_purchases DESC
LIMIT 10;

Artist Co-purchase count :

WITH ArtistPurchases AS (
    SELECT i.invoice_id, a.name AS artist
    FROM invoice_line il
    JOIN track t ON il.track_id = t.track_id
    JOIN album al ON t.album_id = al.album_id
    JOIN artist a ON al.artist_id = a.artist_id
    JOIN invoice i ON il.invoice_id = i.invoice_id
)
SELECT  
    ap1.artist AS artist1,  
    ap2.artist AS artist2,  
    CONCAT(ap1.artist, " & ", ap2.artist) AS artist_combo,  
    COUNT(*) AS co_purchases  
FROM ArtistPurchases ap1  
JOIN ArtistPurchases ap2  
    ON ap1.invoice_id = ap2.invoice_id  
    AND ap1.artist < ap2.artist  
GROUP BY ap1.artist, ap2.artist  
ORDER BY co_purchases DESC  
LIMIT 10;



Album Co-purchase count :

WITH AlbumPurchases AS (
    SELECT i.invoice_id, al.title AS album
    FROM invoice_line il
    JOIN track t ON il.track_id = t.track_id
    JOIN album al ON t.album_id = al.album_id
    JOIN invoice i ON il.invoice_id = i.invoice_id
)
SELECT ap1.album AS album1, ap2.album AS album2, 
CONCAT(ap1.album, " & ", ap2.album) as album_combo,
COUNT(*) AS co_purchases
FROM AlbumPurchases ap1
JOIN AlbumPurchases ap2 ON ap1.invoice_id = ap2.invoice_id AND ap1.album < ap2.album
GROUP BY ap1.album, ap2.album
ORDER BY co_purchases DESC
LIMIT 10;
-------------------------------------------------------------------------------------------------------
5)

SELECT 
    c.country, 
    c.state, 
    SUM(i.total) AS total_revenue,
    ROUND(SUM(i.total) / COUNT(DISTINCT i.invoice_id), 2) AS avg_order_value,
    ROUND(SUM(i.total) / COUNT(DISTINCT c.customer_id), 2) AS avg_revenue_per_customer
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.country, c.state
ORDER BY avg_order_value DESC;


-------------------------------------------------------------------------------------------------------
6)

Frequency in Purchase history :
WITH frequency_factors as (
SELECT c.customer_id,
       c.city,
       c.country,
       COUNT(i.invoice_id) AS purchase_frequency,
       MAX(i.invoice_date) AS last_purchase_date,
       DATEDIFF('2020-12-31 00:00:00', MAX(i.invoice_date)) AS days_since_last_purchase
FROM customer c
LEFT JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.country,c.city,c.customer_id)

select 
customer_id, 
country, 
purchase_frequency,
days_since_last_purchase
from frequency_factors
order by days_since_last_purchase,purchase_frequency asc

-- SELECT 
-- c.customer_id,
-- c.country,
-- c.state,
-- c.city,
-- SUM(i.total) AS total_spent,
-- COUNT(i.invoice_id) AS purchase_count
-- FROM customer c
-- JOIN invoice i ON c.customer_id = i.customer_id
-- GROUP BY c.customer_id,c.city, c.state, c.country
-- order by c.customer_id

-------------------------------------------------------------------------------------------------------
7) 

Purchase History Analysis:
SELECT i.customer_id,
       COUNT(i.invoice_id) AS total_orders,
       SUM(i.total) AS total_spent,
       ROUND(AVG(i.total), 2) AS avg_order_value
FROM invoice i
JOIN customer c ON i.customer_id = c.customer_id
GROUP BY i.customer_id, c.first_name, c.last_name
ORDER BY total_spent DESC;

Purchase Frequency (Days Between Orders):
WITH PurchaseDates AS (
    SELECT customer_id, invoice_date,
           LAG(invoice_date) OVER (PARTITION BY customer_id ORDER BY invoice_date) AS prev_purchase
    FROM invoice
)
SELECT customer_id, 
       ROUND(AVG(DATEDIFF(invoice_date, prev_purchase)), 2) AS avg_days_between_orders
FROM PurchaseDates
WHERE prev_purchase IS NOT NULL
GROUP BY customer_id
ORDER BY avg_days_between_orders;

-------------------------------------------------------------------------------------------------------
8)Measuring Customer Acquisition Rate
-- Assuming Campaign Period between Jan 1st 2020 - Mar 31st 2020
SELECT 
    COUNT(DISTINCT c.customer_id) AS new_customers, 
    (COUNT(DISTINCT c.customer_id) * 100.0) / 
    (SELECT COUNT(DISTINCT customer_id) FROM customer) AS new_customer_percentage
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
WHERE i.invoice_date BETWEEN '2020-01-01' AND '2020-03-31';



Promotion period orders:
SELECT 
    CASE 
        WHEN invoice_date < '2018-01-01 00:00:00' THEN 'Before Promotion'
        WHEN invoice_date BETWEEN '2018-01-01 00:00:00' AND '2018-03-31 00:00:00' THEN 'During Promotion'
        ELSE 'After Promotion'
    END AS promotion_period,
    SUM(total) AS total_revenue,
    COUNT(invoice_id) AS total_orders
FROM invoice
WHERE invoice_date BETWEEN '2017-10-01 00:00:00' AND '2018-06-30 00:00:00'  -- Analyzing a wider range
GROUP BY promotion_period

Basket Size: Average Items Per Order
SELECT ROUND(AVG(item_count), 2) AS avg_basket_size
FROM (
    SELECT invoice_id, COUNT(*) AS item_count
    FROM invoice_line
    GROUP BY invoice_id
) AS basket_sizes;


Average Order Value (AOV):
SELECT ROUND(SUM(total) / COUNT(invoice_id), 2) AS avg_order_value
FROM invoice;

-------------------------------------------------------------------------------------------------------
9)How would you approach this problem, if the objective and subjective questions weren't given?

Step 1: Understand Business Goals
Is the focus on acquisition, retention, or revenue growth?
Are promotions intended for new or existing customers?
Step 2: Data Exploration
Check historical sales trends before promotions.
Identify customer behavior patterns using cohort analysis.
Step 3: Generate Hypotheses
Example: "Did discounts increase customer retention?"
Example: "Do customers who receive promotional emails spend more?"
Step 4: Run Queries and Analyze Data
Time-series analysis of sales trends.
Segmentation of customers based on buying behavior.
Comparative analysis using A/B testing or control groups.
Step 5: Interpret Insights and Optimize Campaigns
If retention is low, improve personalized offers.
If discounts increase sales but reduce profits, adjust pricing strategy.
If email open rates are low, improve email marketing content.
-------------------------------------------------------------------------------------------------------
10)How can you alter the "Albums" table to add a new column named "ReleaseYear" of type INTEGER to store the release year of each album?

ALTER TABLE Albums
ADD COLUMN ReleaseYear INTEGER;
-------------------------------------------------------------------------------------------------------
11) Chinook is interested in understanding the purchasing behavior of customers based on their geographical location. They want to know the average total amount spent by customers from each country, along with the number of customers and the average number of tracks purchased per customer. Write an SQL query to provide this information.

SELECT 
    c.Country,
    COUNT(DISTINCT c.Customer_Id) AS NumberOfCustomers,
    AVG(t.TotalSpent) AS AverageTotalSpent,
    AVG(t.TrackCount) AS AverageTracksPurchasedPerCustomer
FROM 
    Customer c
JOIN 
    (
        SELECT 
            i.Customer_Id,
            SUM(i.Total) AS TotalSpent,
            COUNT(il.Track_Id) AS TrackCount
        FROM 
            Invoice i
        JOIN 
            Invoice_line il ON i.Invoice_Id = il.Invoice_Id
        GROUP BY 
            i.Customer_Id
    ) t ON c.Customer_Id = t.Customer_Id
GROUP BY 
    c.Country
ORDER BY 
    AverageTotalSpent DESC;


