CREATE TABLE student_courses (
	id serial PRIMARY KEY,
	student_id int REFERENCES students (id),
	course_id int REFERENCES courses (id),
	UNIQUE (student_id, course_id)
	
);

CREATE TABLE group_courses (
	id serial PRIMARY KEY,
	group_id int REFERENCES groups (id),
	course_id int REFERENCES courses (id),
	UNIQUE (group_id, course_id)
);

INSERT INTO student_courses (student_id, course_id) VALUES 
	(1, 1), (1, 2),
	(2, 2),
	(3, 1), (3, 3),
	(4, 1), (4, 2);

INSERT INTO group_courses (group_id, course_id) VALUES
	(1, 1), (1, 2), (1, 3),
	(2, 1), (2, 2), (2, 3);

ALTER TABLE groups DROP COLUMN student_ids;
ALTER TABLE students DROP COLUMN courses_ids;

ALTER TABLE courses ADD UNIQUE (name);

CREATE INDEX group_id_idx ON students (group_id);
-- Индексирование позволяет ускорить выполнение запросов путем заведомого исключения неподходящих фрагментов данных 

SELECT s.first_name, s.last_name, c.name
FROM students s
LEFT JOIN student_courses sc ON s.id = sc.student_id
LEFT JOIN courses c ON sc.course_id = c.id
LIMIT 5;

-- Добавим данных
INSERT INTO students (first_name, last_name, group_id) VALUES
	('Павел', 'Алимов', 1),
	('Всеволод', 'Битепаж', 1),
	('Григорьев', 'Николай', 1),
	('Артур', 'Сахаров', 2),
	('Роман', 'Павлов', 2),
	('Анна', 'Цветкова', 2);

INSERT INTO student_courses (student_id, course_id) VALUES
	(5, 1), (5, 2),
	(6, 1), (6, 2), (6, 3),
	(7, 2),
	(8, 1), (8, 2),
	(9, 2),
	(10, 2), (10, 3);
	
CREATE TABLE english (
	student_id int REFERENCES students (id),
	grade int,
	grade_str varchar (15)
);

CREATE FUNCTION check_english_grade()
RETURNS TRIGGER AS $$
BEGIN
	DECLARE
		min_g int;
		max_g int;
	BEGIN
		SELECT min_grade, max_grade
		INTO min_g, max_g
		FROM courses
		WHERE name = 'Английский';
	
		IF NEW.grade < min_g OR NEW.grade > max_g THEN 
			RAISE EXCEPTION 'Оценка должна быть между % и %', min_g, max_g;
		END IF;
	END;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_english_grade
BEFORE INSERT ON english
FOR EACH ROW
EXECUTE FUNCTION check_english_grade();

INSERT INTO english VALUES
	(1, 1, 'Bad');

INSERT INTO english VALUES 
	(1, 5, 'Excellent'),
	(2, 5, 'Excellent'),
	(4, 4, 'Good'),
	(5, 3, 'Fair'),
	(6, 4, 'Good'),
	(7, 4, 'Good'),
	(8, 2, 'Poor'),
	(9, 5, 'Excellent'),
	(10, 3, 'Fair');

-- Поправляю данные в испанском
DELETE FROM spanish WHERE student_id = 2;
INSERT INTO spanish VALUES 
	(5, 9, 'Muy bien'),
	(6, 6, 'Bien'),
	(8, 3, 'Insuficiente');

SELECT s.first_name, s.last_name, s.group_id, m.avg_grade
FROM students s
JOIN (SELECT DISTINCT ON (group_id) id, avg_grade
	FROM (SELECT s.id, s.group_id, AVG(grade) AS avg_grade
		FROM students s
		LEFT JOIN (
			SELECT student_id, grade
			FROM spanish
			UNION ALL
			SELECT student_id, grade
			FROM english
		) ON s.id = student_id
		GROUP BY s.id
	) ORDER BY group_id, avg_grade DESC
) AS m ON s.id = m.id
LIMIT 5;

SELECT 'Испанский' AS name, COUNT(student_id), AVG(grade)
FROM spanish
UNION ALL
SELECT 'Английский' AS name, COUNT(student_id), AVG(grade)
FROM english
LIMIT 5;