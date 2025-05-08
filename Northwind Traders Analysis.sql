--Calculate Total Revenue for Each Product
--We need unitPrice, quantity, and discount from order_details
--Join products and categories to get product and category info
--Group by productID within each categoryID
--Compute total_revenue for each product

--Question 1: Second-Best Selling Product by Category

WITH product_revenue AS (
    SELECT
        c."categoryName",
        p."productName",
        c."categoryID",
        p."productID",
        SUM(od."unitPrice" * od."quantity" * (1 - od."discount")) AS total_revenue --Total Revenue for Each Product
    FROM
        northwind_traders."order_details" AS od
        JOIN northwind_traders."products" AS p ON od."productID" = p."productID"
        JOIN northwind_traders."categories" AS c ON p."categoryID" = c."categoryID"
    GROUP BY
        c."categoryName", c."categoryID", p."productID", p."productName"
),

ranked_products AS (
    SELECT
        "categoryName",
        "productName",
        total_revenue,
RANK() OVER (PARTITION BY "categoryID" ORDER BY total_revenue DESC) AS revenue_rank ----Rank Products Within Each Category by Revenue
    FROM
        product_revenue
)
--Select Only the Second-Best
SELECT
    "categoryName",
    "productName",
    total_revenue,
	revenue_rank
FROM
    ranked_products
WHERE
    revenue_rank = 2  --Filter to revenue_rank = 2
ORDER BY
    "categoryName";   -- second-highest grossing products per category

	
--Calculate total revenue per customer
--Rank customers using RANK() 
--top 3 ranks — including ties at 3rd

--Question 2: Top 3 Customers by Total Sales

WITH customer_revenue AS (
    SELECT
        c."companyName" AS customer_name, -- taking company name as a customer name bcz customer name is not given in the schema 
        o."customerID",
SUM(od."unitPrice" * od."quantity" * (1 - od."discount")) AS total_spent --The portion of the price that is paid (1 - od."discount")
    FROM
        northwind_traders."order_details" AS od
        JOIN northwind_traders."orders" AS o ON od."orderID" = o."orderID"
        JOIN northwind_traders."customers" AS c ON o."customerID" = c."customerID"
    GROUP BY
        o."customerID", c."companyName"
),
--Rank customers using RANK()
ranked_customers AS (
    SELECT
        customer_name,
        total_spent,
        DENSE_RANK() OVER (ORDER BY total_spent DESC) AS sales_rank
    FROM
        customer_revenue
)
--top 3 ranks — including ties at 3rd
SELECT
    customer_name,
    total_spent,
    sales_rank
FROM
    ranked_customers
WHERE
    sales_rank <= 3
ORDER BY
    sales_rank;

--Question 3: Top Suppliers by Product Variety

WITH supplier_product_count AS (
    SELECT
        s."companyName" AS supplier_name,
        COUNT(p."productID") AS product_count
    FROM
        northwind_traders."products" AS p
        JOIN northwind_traders."suppliers" AS s ON p."supplierID" = s."supplierID"
    GROUP BY
        s."companyName"     --Count of Products per Supplier
),
--Rank Suppliers by Product Count
ranked_suppliers AS (
    SELECT
        supplier_name,
        product_count,
        DENSE_RANK() OVER (ORDER BY product_count DESC) AS supplier_rank
    FROM
        supplier_product_count
)
SELECT
    supplier_name,
    product_count,
    supplier_rank
FROM
    ranked_suppliers
ORDER BY
    supplier_rank;


--Question 4: Most Recent Order per Customer

--Join Customers with Orders
WITH ranked_orders AS (
    SELECT
        c."companyName" AS customer_name,
        o."orderDate",
--Window Function to Rank Orders per Customer
        RANK() OVER ( PARTITION BY o."customerID" ORDER BY o."orderDate" DESC ) AS order_rank
    FROM
        northwind_traders."orders" AS o
        JOIN northwind_traders."customers" AS c
        ON o."customerID" = c."customerID"
)
SELECT
    customer_name,
    "orderDate"
FROM
    ranked_orders
WHERE
    order_rank = 1 --to get only the latest order for each customer
ORDER BY
    "orderDate" ASC;  -- oldest recent orders first


--Question 5: Cumulative Sales by Month

WITH monthly_sales AS (
    SELECT
        DATE_TRUNC('month', o."orderDate") AS month,
--monthly sales
        SUM(od."unitPrice" * od."quantity" * (1 - od."discount")) AS monthly_revenue
    FROM
        northwind_traders."orders" AS o
        JOIN northwind_traders."order_details" AS od
        ON o."orderID" = od."orderID"
    WHERE
        EXTRACT(YEAR FROM o."orderDate") = 1997
    GROUP BY
        DATE_TRUNC('month', o."orderDate")
)
SELECT
    TO_CHAR(month, 'YYYY-MM') AS month,
    ROUND(monthly_revenue, 2) AS monthly_sales,
--to get the cumulative sum
    ROUND(SUM(monthly_revenue) OVER (ORDER BY month), 2) AS cumulative_sales
FROM
    monthly_sales
ORDER BY
    month;

--Question 6: Days Between Customer Orders

WITH customer_orders AS (
    SELECT
        c."companyName" AS customer_name,
        o."orderDate",
--get the previous order’s date for the same customer
LAG(o."orderDate") OVER (PARTITION BY o."customerID" ORDER BY o."orderDate") AS previous_order_date
    FROM
        northwind_traders."orders" AS o
        JOIN northwind_traders."customers" AS c
        ON o."customerID" = c."customerID"
)
SELECT
    customer_name,
    "orderDate",
--This gives the number of days since the last order
    ("orderDate" - previous_order_date) AS days_since_last_order
FROM
    customer_orders
WHERE
    previous_order_date IS NOT NULL
ORDER BY
    customer_name, "orderDate";

--Question 7: Next Order Date and Reorder Interval

WITH customer_orders AS (
    SELECT
        c."companyName" AS customer_name,
        o."orderDate" AS current_order_date,
--to get the next order date
        LEAD(o."orderDate") OVER (
            PARTITION BY o."customerID"
            ORDER BY o."orderDate"
        ) AS next_order_date
    FROM
        northwind_traders."orders" o
        JOIN northwind_traders."customers" c
            ON o."customerID" = c."customerID"
)
SELECT
    customer_name,
    current_order_date,
    next_order_date,
    -- Calculate the gap in days  number of days until the next order
    next_order_date - current_order_date AS days_until_next_order
FROM
    customer_orders
WHERE
    next_order_date IS NOT NULL
ORDER BY
    customer_name,
    current_order_date;
	
--Question 8: Highest-Value Order and Its Salesperson	

WITH order_totals AS (   --calculating the total revenue per order.
    SELECT
        o."orderID",
        e."firstName" || ' ' || e."lastName" AS employee_name,
        SUM(od."unitPrice" * od."quantity" * (1 - od."discount")) AS total_order_value
    FROM
        northwind_traders."orders" o
        JOIN northwind_traders."order_details" od ON o."orderID" = od."orderID"
        JOIN northwind_traders."employees" e ON o."employeeID" = e."employeeID"
    GROUP BY
        o."orderID", e."firstName", e."lastName"  -- to get totals per order.
),
--This part finds the maximum order value across all orders from the previous step.
max_order AS (
    SELECT
        MAX(total_order_value) AS max_value
    FROM
        order_totals
)
--join the order_totals CTE with the max_order CTE.
SELECT
    ot."orderID",
    ot.total_order_value,
    ot.employee_name
FROM
    order_totals ot
    JOIN max_order mo ON ot.total_order_value = mo.max_value;


