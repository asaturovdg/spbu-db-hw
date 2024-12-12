CREATE TEMP TABLE last_month_pulls AS
SELECT * FROM pull
WHERE pulled_at BETWEEN CURRENT_DATE - '1 months'::INTERVAL AND CURRENT_DATE;

SELECT a.name, p.*
FROM pull p
JOIN account a
ON p.account_id = a.id
WHERE a.name LIKE '%е%'
LIMIT 10;

EXPLAIN ANALYZE 
SELECT a.name, p.*
FROM pull p
JOIN account a
ON p.account_id = a.id
WHERE a.name LIKE '%е%'
LIMIT 10;

--Limit  (cost=0.16..2.23 rows=10 width=138) (actual time=0.026..0.036 rows=10 loops=1)
--  ->  Nested Loop  (cost=0.16..414.36 rows=2000 width=138) (actual time=0.026..0.035 rows=10 loops=1)
--        ->  Seq Scan on pull p  (cost=0.00..164.00 rows=10000 width=20) (actual time=0.010..0.011 rows=26 loops=1)
--        ->  Memoize  (cost=0.16..0.18 rows=1 width=122) (actual time=0.001..0.001 rows=0 loops=26)
--              Cache Key: p.account_id
--              Cache Mode: logical
--              Hits: 22  Misses: 4  Evictions: 0  Overflows: 0  Memory Usage: 1kB
--              ->  Index Scan using account_pkey on account a  (cost=0.15..0.17 rows=1 width=122) (actual time=0.003..0.003 rows=0 loops=4)
--                    Index Cond: (id = p.account_id)
--                    Filter: ((name)::text ~~ '%е%'::text)
--                    Rows Removed by Filter: 0
--Planning Time: 0.110 ms
--Execution Time: 0.053 ms

CREATE INDEX account_name_index ON account (name);

EXPLAIN ANALYZE 
SELECT a.name, p.*
FROM pull p
JOIN account a
ON p.account_id = a.id
WHERE a.name LIKE '%е%'
LIMIT 10;

--Limit  (cost=0.00..1.16 rows=10 width=138) (actual time=0.020..0.024 rows=10 loops=1)
--  ->  Nested Loop  (cost=0.00..290.05 rows=2500 width=138) (actual time=0.019..0.023 rows=10 loops=1)
--        Join Filter: (a.id = p.account_id)
--        Rows Removed by Join Filter: 22
--        ->  Seq Scan on account a  (cost=0.00..1.05 rows=1 width=122) (actual time=0.012..0.012 rows=1 loops=1)
--              Filter: ((name)::text ~~ '%е%'::text)
--        ->  Seq Scan on pull p  (cost=0.00..164.00 rows=10000 width=20) (actual time=0.005..0.006 rows=32 loops=1)
--Planning Time: 0.130 ms
--Execution Time: 0.038 ms

WITH popular_last_month_items AS (
	SELECT item_id, count(item_id) AS item_count
	FROM last_month_pulls
	GROUP BY item_id
)
SELECT i.id, i.title AS "Предмет", r.title AS "Редкость", item_count AS "Частота выпадения"
FROM item i
JOIN rarity r
ON i.rarity_id = r.id
JOIN popular_last_month_items p
ON i.id = p.item_id
ORDER BY item_count DESC
LIMIT 10;

CREATE MATERIALIZED VIEW accounts_before_new_banner AS (
	SELECT *
	FROM account
	WHERE date_created < '12-12-2024'
)

SELECT *
FROM accounts_before_new_banner
LIMIT 10;

-- Новые данные не отобразятся в materialized view
INSERT INTO account (name, email) VALUES
  ('джунгарик', 'filippushka@mail.ru'),
  ('9Lrik_Lapa', 'rassadinyv@mail.ru');
-- Даже если будут удовлетворять условию фильтрации
INSERT INTO account (name, email, current_level, date_created) VALUES
  ('ExemptLoki', 'denchik_slaziet@gmail.com', 57, '12-03-2022');
  
SELECT *
FROM accounts_before_new_banner
LIMIT 10;

SELECT *
FROM account a 
LIMIT 10;