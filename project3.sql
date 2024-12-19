--
-- Триггеры
--

-- Увеличение уровня аккаунта при совершении pull
CREATE OR REPLACE FUNCTION update_account_level()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE account
    SET current_level = current_level + 1
    WHERE id = NEW.account_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_account_level
AFTER INSERT ON pull
FOR EACH ROW
EXECUTE FUNCTION update_account_level();

-- Соблюдаем свойства вероятности
CREATE OR REPLACE FUNCTION check_rarity_chances()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.chance < 0 OR NEW.chance > 1) THEN
        RAISE EXCEPTION 'Значение поля chance должно быть числом между 0 и 1';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_rarity_chances
BEFORE INSERT OR UPDATE ON rarity
FOR EACH ROW
EXECUTE FUNCTION check_rarity_chances();

-- При каждом изменении таблицы pull убеждаемся, что соблюдаем аксиоматику вероятностной логики
-- (Используем FOR EACH STATEMENT, т. к. при создании редкостей для нового пула FOR EACH ROW будет ругаться уже на первой редкости не успеев отсмотреть остальные
CREATE OR REPLACE FUNCTION check_rarity_chances_across_pool()
RETURNS TRIGGER AS $$
DECLARE
    invalid_pool_id INT;
BEGIN
    SELECT pool_id
    INTO invalid_pool_id
    FROM rarity
    GROUP BY pool_id
	-- Какой-то косяк в подсчете, сумму вероятностей первого пула (0.7 + 0.2 + 0.1) назначают как 0.9999999, поэтому пришлось помягче ограничение сделать 
    HAVING SUM(chance) < 0.9999 OR SUM(chance) > 1.0001
    LIMIT 1;

    IF FOUND THEN
        RAISE EXCEPTION 'Сумма шансов редокстей pool_id % должна быть равна 1', invalid_pool_id;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_rarity_chances_across_pool
AFTER INSERT OR UPDATE ON rarity
FOR EACH STATEMENT
EXECUTE FUNCTION check_rarity_chances_across_pool();

-- Логирование информации об удалении pull
CREATE OR REPLACE FUNCTION log_pull_delete()
RETURNS TRIGGER AS $$
BEGIN
    RAISE NOTICE 'Был удален pull с id %', OLD.id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER log_pull_delete
BEFORE DELETE ON pull
FOR EACH ROW
EXECUTE FUNCTION log_pull_delete();

--
-- Транзакции
--

-- Неудачное добавление нового пула (Сумма вероятностей не равна 1)
BEGIN;

INSERT INTO pool (title, alias) VALUES ('Летний 2024', 'summer_2024_event');

DO $$
DECLARE
    new_pool_id INT;
	new_pool_b_id INT;
BEGIN
	-- Получаем id только что добавленного пула
    SELECT id INTO new_pool_id FROM pool WHERE alias = 'summer_2024_event';

    INSERT INTO rarity (title, chance, pool_id) VALUES 
        ('B', 0.58, new_pool_id),
        ('A', 0.25, new_pool_id),
        ('S', 0.01, new_pool_id),
        ('SS', 0.15, new_pool_id);

	-- Получаем id только что добавленной редкости (в данном случае только B, так как предметов остальных редкостей по 1 штуке)
	SELECT id INTO new_pool_b_id FROM rarity WHERE title = 'B' AND pool_id = new_pool_id;

    INSERT INTO item (title, rarity_id) VALUES
        ('Яхта', new_pool_b_id),
		('Катамаран 2.0', new_pool_b_id),
        ('Солнцезащитные очки', (SELECT id FROM rarity WHERE title = 'A' AND pool_id = new_pool_id)),
        ('Арбуз', (SELECT id FROM rarity WHERE title = 'S' AND pool_id = new_pool_id)),
        ('Чурчхела', (SELECT id FROM rarity WHERE title = 'SS' AND pool_id = new_pool_id));
END $$;

COMMIT;

ROLLBACK;


-- Неудачное добавление нового пула (Предмет с существующим названием)
BEGIN;

INSERT INTO pool (title, alias) VALUES ('Летний 2024', 'summer_2024_event');

DO $$
DECLARE
    new_pool_id INT;
	new_pool_b_id INT;
BEGIN
	-- Получаем id только что добавленного пула
    SELECT id INTO new_pool_id FROM pool WHERE alias = 'summer_2024_event';

    INSERT INTO rarity (title, chance, pool_id) VALUES 
        ('B', 0.6, new_pool_id),
        ('A', 0.25, new_pool_id),
        ('S', 0.1, new_pool_id),
        ('SS', 0.05, new_pool_id);

	-- Получаем id только что добавленной редкости (в данном случае только B, так как предметов остальных редкостей по 1 штуке)
	SELECT id INTO new_pool_b_id FROM rarity WHERE title = 'B' AND pool_id = new_pool_id;

    INSERT INTO item (title, rarity_id) VALUES
        ('Яхта', new_pool_b_id),
		('Катамаран', new_pool_b_id),
        ('Солнцезащитные очки', (SELECT id FROM rarity WHERE title = 'A' AND pool_id = new_pool_id)),
        ('Арбуз', (SELECT id FROM rarity WHERE title = 'S' AND pool_id = new_pool_id)),
        ('Чурчхела', (SELECT id FROM rarity WHERE title = 'SS' AND pool_id = new_pool_id));
END $$;

COMMIT;

ROLLBACK;


-- Успешное добавление нового пула
BEGIN;

INSERT INTO pool (title, alias) VALUES ('Летний 2024', 'summer_2024_event');

DO $$
DECLARE
    new_pool_id INT;
	new_pool_b_id INT;
BEGIN
	-- Получаем id только что добавленного пула
    SELECT id INTO new_pool_id FROM pool WHERE alias = 'summer_2024_event';

    INSERT INTO rarity (title, chance, pool_id) VALUES 
        ('B', 0.6, new_pool_id),
        ('A', 0.25, new_pool_id),
        ('S', 0.1, new_pool_id),
        ('SS', 0.05, new_pool_id);

	-- Получаем id только что добавленной редкости (в данном случае только B, так как предметов остальных редкостей по 1 штуке)
	SELECT id INTO new_pool_b_id FROM rarity WHERE title = 'B' AND pool_id = new_pool_id;

    INSERT INTO item (title, rarity_id) VALUES
        ('Яхта', new_pool_b_id),
		('Катамаран 2.0', new_pool_b_id),
        ('Солнцезащитные очки', (SELECT id FROM rarity WHERE title = 'A' AND pool_id = new_pool_id)),
        ('Арбуз', (SELECT id FROM rarity WHERE title = 'S' AND pool_id = new_pool_id)),
        ('Чурчхела', (SELECT id FROM rarity WHERE title = 'SS' AND pool_id = new_pool_id));
END $$;

-- Интересный прецедент возникает если запустить предыдущую транзакцию еще раз, поэтому исправляем свои прошлые косяки и добавляем уникальность

-- Запустить если повторно проводилась предыдущая транзакция
--ROLLBACK;
--
--DELETE
--FROM pool 
--WHERE id IN (
--	SELECT id
--	FROM pool 
--	WHERE alias = 'summer_2024_event'
--	ORDER BY id DESC 
--	LIMIT 1
--);

ALTER TABLE pool ADD UNIQUE (alias);

COMMIT;

-- Неудачное изменение email (Уже существует)
BEGIN;

UPDATE account
SET email = 'leshaalexey@mail.ru'
WHERE name = 'XxX_душой_не_стареть_XxX';

COMMIT;

ROLLBACK;


-- Удачное изменение email
BEGIN;

UPDATE account
SET email = 'il4aResPekt@mail.ru'
WHERE name = 'XxX_душой_не_стареть_XxX';

COMMIT;

SELECT pool_id, sum(chance)
FROM rarity
GROUP BY pool_id
HAVING SUM(chance) < 0.9999 OR SUM(chance) > 1.0001;

-- Посмотрим работу увеличения уровня
SELECT *
FROM 
account
ORDER BY id 
LIMIT 10;

-- (В связи с поломками моей базы данных в процессе неправильного написания триггеров научился генерировать случайное число из конкретной выборки
INSERT INTO pull (account_id, item_id, pulled_at)
SELECT 
    (SELECT id FROM account ORDER BY RANDOM() LIMIT 1) AS account_id,
    (SELECT id FROM item ORDER BY RANDOM() LIMIT 1) AS item_id,
    NOW() - (random() * '365 days'::interval) AS pulled_at
FROM generate_series(1, 10000);

-- А тут понял, что не очень хорошо научился их генерировать
-- Понял в чем ошибка, но сейчас не успеваю научиться нормально
-- Главное что уровень увеличился
SELECT *
FROM 
account
ORDER BY id 
LIMIT 10;

-- Заодно посмотрим работу логирования
DELETE
FROM pull 
WHERE id > (SELECT id FROM pull ORDER BY id DESC LIMIT 1) - 10000