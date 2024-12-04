CREATE TABLE pool (
  id SERIAL PRIMARY KEY,
  title VARCHAR(70),
  alias VARCHAR(20) NOT NULL
);

CREATE TABLE rarity (
  id SERIAL PRIMARY KEY,
  title VARCHAR(5),
  chance FLOAT,
  pool_id INT REFERENCES pool (id)
);

CREATE TABLE item (
  id SERIAL PRIMARY KEY,
  title VARCHAR(100) NOT NULL UNIQUE,
  rarity_id INT REFERENCES rarity (id)
);

CREATE TABLE account (
  id SERIAL PRIMARY KEY,
  name VARCHAR(50) UNIQUE,
  email VARCHAR(50) UNIQUE,
  date_created DATE DEFAULT CURRENT_DATE,
  current_level INT DEFAULT 1
);

CREATE TABLE pull (
  id SERIAL PRIMARY KEY,
  account_id INT REFERENCES account (id),
  item_id INT REFERENCES item (id),
  pulled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO pool (title, alias) VALUES 
  ('Стандарт', 'standard'),
  ('Новогодний 2024', 'new_year_2024_event'),
  ('Иван Купала 2024', 'ivan_2024_event');

INSERT INTO rarity (title, chance, pool_id) VALUES 
  ('B', 0.7, 1),
  ('A', 0.2, 1),
  ('S', 0.1, 1),
  ('B', 0.65, 2),
  ('A', 0.3, 2),
  ('S', 0.04, 2),
  ('SS', 0.009, 2),
  ('SSS', 0.001, 2),
  ('B', 0.65, 3),
  ('A', 0.3, 3),
  ('S', 0.04, 3),
  ('SS', 0.009, 3),
  ('SSS', 0.001, 3);

-- Стандарт
INSERT INTO item (title, rarity_id) VALUES 
  ('Катамаран', 1),
  ('Мухобойка', 1),
  ('Отбойный молоток', 1),
  ('Чебупицца', 2),
  ('Конфеты "Степ"', 2),
  ('Черноголовка "Красный виноград"', 3);

-- Новогодний 2024
INSERT INTO item (title, rarity_id) VALUES 
  ('Гирлянда', 4),
  ('Бенгальский огонь', 4),
  ('Обращение президента', 4),
  ('Елка', 4),
  ('Дед Мороз', 4),
  ('Оливье', 5),
  ('Селедка под шубой', 5),
  ('Шампанское', 6),
  ('Мандарины', 7),
  ('Новогодний зачет', 8);
  
-- Иван Купала 2024
INSERT INTO item (title, rarity_id) VALUES 
  ('Прыжки через костер', 9),
  ('Ритуальные бесчинства', 9),
  ('Венок', 9),
  ('Блины', 10),
  ('Клецки', 10),
  ('Вареники с вишней', 11),
  ('Иван-чай', 12),
  ('Квас', 13);
  
INSERT INTO account (name, email) VALUES
  ('Леша Алексей', 'leshaalexey@mail.ru'),
  ('XxX_душой_не_стареть_XxX', 'pridumivaynaobum97686@gmail.com');

INSERT INTO account (name, email, current_level, date_created) VALUES
  ('Давид', 'gachakakrabota@mail.ru', 98, CURRENT_DATE - '8 months 3 days'::interval),
  ('ataev2808', 'ataev2808@mail.ru', 28, CURRENT_DATE - '3 months 7 days'::interval);

-- Заполнение таблицы pull с помощью рандома
-- В будущем хотелось бы переписать с учетом вероятности каждой из редкостей, но пока просто так (не успеваю разобраться)
INSERT INTO pull (account_id, item_id, pulled_at)
SELECT 
    trunc(random() * (SELECT COUNT(*) FROM account) + 1)::INT AS account_id,
    trunc(random() * (SELECT COUNT(*) FROM item) + 1)::INT AS item_id,
    NOW() - (random() * '365 days'::interval) AS pulled_at
FROM generate_series(1, 10000);

--
-- Селекты
--

SELECT *
FROM pull
LIMIT 20;

CREATE OR REPLACE VIEW pretty_pull AS (
	SELECT p.id, a.name AS "Аккаунт", a.current_level AS "Уровень аккаунта", i.title AS "Предмет", r.title AS "Редкость", r.chance AS "Шанс редкости", p2.title AS "Пул", p.pulled_at AS "Время"
	FROM account a 
	JOIN pull p 
	ON a.id = p.account_id 
	JOIN item i 
	ON p.item_id = i.id 
	JOIN rarity r 
	ON i.rarity_id = r.id 
	JOIN pool p2 
	ON r.pool_id = p2.id 
);

SELECT *
FROM pretty_pull
LIMIT 20;

-- Только SSS
SELECT *
FROM pretty_pull
WHERE "Редкость" = 'SSS'
LIMIT 20;

-- Количество SSS предметов у каждого аккаунта
SELECT "Аккаунт", "Предмет", count("Предмет") 
FROM pretty_pull
WHERE "Редкость" = 'SSS'
GROUP BY "Аккаунт", "Предмет"
LIMIT 20;

-- View с рассчитанным шансом для каждого конкретного предмета (А не для редкости в целом)
CREATE OR REPLACE VIEW items_with_right_chances AS (
	SELECT i.id AS item_id, i.title AS item_title, r.title AS rarity, rc.right_chance AS chance, p.title AS pool_title
	FROM item i
	JOIN rarity r 
	ON i.rarity_id = r.id
	JOIN pool p 
	ON r.pool_id = p.id
	JOIN (
		SELECT r.title, r.pool_id , avg(r.chance) / count(i.title) AS right_chance
		FROM item i
		JOIN rarity r ON i.rarity_id = r.id
		GROUP BY r.title, r.pool_id
	) rc 
	ON r.title = rc.title AND r.pool_id = rc.pool_id
);

SELECT *
FROM items_with_right_chances
LIMIT 30;

-- Таблица с правильными шансами
SELECT p.id, "Аккаунт", "Уровень аккаунта", "Предмет", "Редкость", i.chance AS "Шанс редкости", "Пул", "Время" 
FROM pretty_pull p
JOIN items_with_right_chances i
ON p."Предмет" = i.item_title
LIMIT 30;

-- За февраль 2024
SELECT p.id, "Аккаунт", "Уровень аккаунта", "Предмет", "Редкость", i.chance AS "Шанс редкости", "Пул", "Время" 
FROM pretty_pull p
JOIN items_with_right_chances i
ON p."Предмет" = i.item_title
WHERE "Время" BETWEEN '2024-02-01' AND '2024-03-01'
LIMIT 30;