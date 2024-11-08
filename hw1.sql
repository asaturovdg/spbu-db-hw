create table courses (
	id serial primary key,
	name varchar(30),
	is_exam bool,
	min_grade int,
	max_grade int
);

create table groups (
	id serial primary key,
	full_name varchar(70),
	short_name varchar(15),
	student_ids int[]
);

create table students (
	id serial primary key,
	first_name varchar(15),
	last_name varchar(20),
	group_id int references groups(id),
	courses_ids int[]
); 

create table spanish (
	student_id int references students(id),
	grade int,
	grade_str varchar(15)
); 

create function check_spanish_grade()
returns trigger as $$
begin
	declare
		min_g int;
		max_g int;
	begin
		select min_grade, max_grade
		into min_g, max_g
		from courses
		where name = 'Испанский';
		
		if new.grade < min_g or new.grade > max_g then
			raise exception 'Оценка должна быть между % и %', min_g, max_g;
		end if;
	end;
	return new;
end;
$$ language plpgsql;

create trigger check_spanish_grade
	before insert on spanish
	for each row 
	execute function check_spanish_grade();

insert into courses(name, is_exam, min_grade, max_grade) values
('Испанский', false, 1, 10), ('Английский', true, 2, 5), ('Русский', true, 1, 5);

insert into groups(full_name, short_name, student_ids) values 
	('Искуственный интеллект и наука о данных, магистры 1 курс, группа 1', '24.М81-мм', '{1, 3}'),
	('Искуственный интеллект и наука о данных, магистры 1 курс, группа 2', '24.М82-мм', '{2, 4}')

insert into students(first_name, last_name, group_id, courses_ids) values 
	('Давид', 'Асатуров', 1, '{1, 2}'),
	('Анна', 'Платонова', 2, '{2}'),
	('Махамат', 'Калет', 1, '{1, 3}'),
	('Артем', 'Чекалев', 2, '{1, 2}')
	
insert into spanish values (1, 12, 'Perfectamente');

insert into spanish values 
	(1, 10, 'Perfectamente'),
	(2, 9, 'Muy bien'),
	(3, 6, 'Bien'),
	(4, 2, 'Insuficiente')
	
select * from spanish;

select * from groups where full_name like '%2';

select name, is_exam from courses where max_grade < 8;

select count(grade), avg(grade) from spanish;