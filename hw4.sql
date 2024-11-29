CREATE TABLE IF NOT EXISTS employees (
    employee_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    position VARCHAR(50) NOT NULL,
    department VARCHAR(50) NOT NULL,
    salary NUMERIC(10, 2) NOT NULL,
    manager_id INT REFERENCES employees(employee_id)
);

-- Пример данных
INSERT INTO employees (name, position, department, salary, manager_id)
VALUES
    ('Alice Johnson', 'Manager', 'Sales', 85000, NULL),
    ('Bob Smith', 'Sales Associate', 'Sales', 50000, 1),
    ('Carol Lee', 'Sales Associate', 'Sales', 48000, 1),
    ('David Brown', 'Sales Intern', 'Sales', 30000, 2),
    ('Eve Davis', 'Developer', 'IT', 75000, NULL),
    ('Frank Miller', 'Intern', 'IT', 35000, 5);


SELECT * FROM employees LIMIT 5;

CREATE TABLE IF NOT EXISTS sales(
    sale_id SERIAL PRIMARY KEY,
    employee_id INT REFERENCES employees(employee_id),
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    sale_date DATE NOT NULL
);

-- Пример данных
INSERT INTO sales (employee_id, product_id, quantity, sale_date)
VALUES
    (2, 1, 20, '2024-10-15'),
    (2, 2, 15, '2024-10-16'),
    (3, 1, 10, '2024-10-17'),
    (3, 3, 5, '2024-10-20'),
    (4, 2, 8, '2024-10-21'),
    (2, 1, 12, '2024-11-01');

SELECT * FROM sales LIMIT 5;


CREATE TABLE IF NOT EXISTS products (
    product_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    price NUMERIC(10, 2) NOT NULL
);

-- Пример данных
INSERT INTO products (name, price)
VALUES
    ('Product A', 150.00),
    ('Product B', 200.00),
    ('Product C', 100.00);
    
-- Триггеры

CREATE FUNCTION check_salary()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.salary > 500000 THEN
        RAISE EXCEPTION 'Слишком большая зарплата';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_insert_employee
BEFORE INSERT ON employees
FOR EACH ROW
EXECUTE FUNCTION check_salary();

CREATE FUNCTION log_salary_update()
RETURNS TRIGGER AS $$
BEGIN
    RAISE NOTICE 'Изменение зарплаты сотрудника % с % до %', OLD.name, OLD.salary, NEW.salary;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION prevent_boss_deletion()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.position = 'Boss' THEN
        RAISE EXCEPTION 'Невозможно удалить босса';
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_delete_employee
BEFORE DELETE ON employees
FOR EACH ROW
EXECUTE FUNCTION prevent_boss_deletion();

-- Триггер AFTER INSERT: логирование добавления продаж
CREATE FUNCTION log_sales_insert()
RETURNS TRIGGER AS $$
BEGIN
    RAISE NOTICE 'Сотрудником с id % был продан товар с id %', NEW.employee_id, NEW.product_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_insert_sale
AFTER INSERT ON sales
FOR EACH ROW
EXECUTE FUNCTION log_sales_insert();

CREATE FUNCTION prevent_truncate()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Нельзя использовать оператор TRUNCATE на этой таблице';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_truncate_employees
BEFORE TRUNCATE ON employees
FOR EACH STATEMENT
EXECUTE FUNCTION prevent_truncate();

CREATE VIEW employees_view AS
SELECT *
FROM employees;

CREATE FUNCTION instead_of_delete()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM employees
    WHERE employee_id = OLD.employee_id;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER instead_of_delete
INSTEAD OF DELETE ON employees_view
FOR EACH ROW
EXECUTE FUNCTION instead_of_delete();

-- Этот триггер позволяет при удалении данных из представления так же удалять их в оригинальной таблице

-- Транзакции

BEGIN;

INSERT INTO employees (name, position, department, salary, manager_id)
VALUES ('David Asaturov', 'Boss', 'IT', 500000, NULL);

INSERT INTO sales (employee_id, product_id, quantity, sale_date)
VALUES (3, 1, 5, '2024-11-24');

COMMIT;

-- Успешная транзакция

BEGIN;

INSERT INTO employees (name, position, department, salary, manager_id)
VALUES ('Hank Wilson', 'Sales Associate', 'Sales', 500001, NULL);

INSERT INTO sales (employee_id, product_id, quantity, sale_date)
VALUES (4, 2, 10, '2024-11-25');

ROLLBACK;

-- Ошибка из-за триггера before_insert_employee

BEGIN;

DELETE FROM employees WHERE position = 'Boss';

INSERT INTO sales (employee_id, product_id, quantity, sale_date)
VALUES (3, 2, 10, '2024-11-26');

ROLLBACK;

-- Ошибка из-за триггера before_delete_employee