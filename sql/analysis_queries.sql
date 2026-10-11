-- AppForge Labs – iOS App Strategy Analysis
-- Dialect: SQLite. Tables: AppleStore, appleStore_description_combined.
-- Cleaning rule: apps with rating_count_tot = 0 have user_rating = 0 (not a real rating),
-- so they are excluded from rating averages.

---------------------------------------------------------------
-- 0. DATA CHECKS (run first and record the results in docs/)
---------------------------------------------------------------
SELECT COUNT(*) AS total_apps,
       COUNT(DISTINCT id) AS unique_ids,
       SUM(rating_count_tot = 0) AS apps_without_ratings
FROM AppleStore;

SELECT COUNT(*) AS desc_rows, COUNT(DISTINCT id) AS desc_unique_ids
FROM appleStore_description_combined;

---------------------------------------------------------------
-- 1. PAID vs FREE
---------------------------------------------------------------
SELECT
    CASE WHEN price > 0 THEN 'Paid' ELSE 'Free' END AS app_type,
    COUNT(*)                          AS n_apps,
    ROUND(AVG(user_rating), 2)        AS avg_rating,
    ROUND(AVG(rating_count_tot), 0)   AS avg_rating_count
FROM AppleStore
WHERE rating_count_tot > 0
GROUP BY app_type;

---------------------------------------------------------------
-- 2. LANGUAGE BUCKETS
-- Note: the column name contains a dot, so it must be quoted.
---------------------------------------------------------------
SELECT
    CASE
        WHEN "lang.num" < 10             THEN '1) <10'
        WHEN "lang.num" BETWEEN 10 AND 30 THEN '2) 10-30'
        ELSE                                  '3) 31+'
    END AS language_bucket,
    COUNT(*)                   AS n_apps,
    ROUND(AVG(user_rating), 2) AS avg_rating
FROM AppleStore
WHERE rating_count_tot > 0
GROUP BY language_bucket
ORDER BY avg_rating DESC;

---------------------------------------------------------------
-- 3. CATEGORY OPPORTUNITY: low rating + low share of catalog
-- Share uses all apps. Rating averages use rated apps only.
-- Genres need at least 10 rated apps (this excludes Catalogs, 5 rated apps).
---------------------------------------------------------------
SELECT prime_genre,
       COUNT(*) AS n_apps,
       SUM(rating_count_tot > 0) AS n_rated,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM AppleStore), 1) AS share_of_catalog_pct,
       ROUND(AVG(CASE WHEN rating_count_tot > 0 THEN user_rating END), 2) AS avg_rating,
       ROUND(AVG(CASE WHEN rating_count_tot > 0 THEN rating_count_tot END), 0) AS avg_rating_count
FROM AppleStore
GROUP BY prime_genre
HAVING SUM(rating_count_tot > 0) >= 10
ORDER BY avg_rating ASC
LIMIT 8;

---------------------------------------------------------------
-- 4. DESCRIPTION LENGTH (characters)
---------------------------------------------------------------
SELECT
    CASE
        WHEN LENGTH(TRIM(b.app_desc)) < 500   THEN '1) Short (<500)'
        WHEN LENGTH(TRIM(b.app_desc)) <= 1000 THEN '2) Medium (500-1000)'
        ELSE                                       '3) Long (>1000)'
    END AS desc_length,
    COUNT(*)                     AS n_apps,
    ROUND(AVG(a.user_rating), 2) AS avg_rating
FROM AppleStore a
JOIN appleStore_description_combined b ON a.id = b.id
WHERE a.rating_count_tot > 0
GROUP BY desc_length
ORDER BY desc_length;

---------------------------------------------------------------
-- 5. TOP APP PER GENRE (min. 100 ratings to avoid 5.0 apps with a single review)
-- ROW_NUMBER guarantees exactly one app per genre.
---------------------------------------------------------------
SELECT track_name, prime_genre, user_rating, rating_count_tot
FROM (
    SELECT track_name, prime_genre, user_rating, rating_count_tot,
           ROW_NUMBER() OVER (
               PARTITION BY prime_genre
               ORDER BY user_rating DESC, rating_count_tot DESC
           ) AS rn
    FROM AppleStore
    WHERE rating_count_tot >= 100
) t
WHERE rn = 1;
