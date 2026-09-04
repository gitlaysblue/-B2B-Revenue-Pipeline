-- Total Revenue (all-time, matches Power BI with no filters applied)
SELECT SUM(amount) AS total_revenue
FROM fact_deals
WHERE status = 'Won';

-- Deal Count
SELECT COUNT(*) AS deal_count
FROM fact_deals;

-- Win Rate
SELECT
    SUM(CASE WHEN status = 'Won' THEN 1 ELSE 0 END) * 1.0 /
    SUM(CASE WHEN status IN ('Won', 'Lost') THEN 1 ELSE 0 END) AS win_rate
FROM fact_deals;