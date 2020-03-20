CREATE DATABASE MTUCI_labs;

USE MTUCI_labs;

DROP TABLE IF EXISTS students;

CREATE TABLE students (
	id INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	first_name VARCHAR(50) NOT NULL,
	second_name VARCHAR(50),
	last_name VARCHAR(50) NOT NULL,
	email VARCHAR(120) UNIQUE KEY,
	phone VARCHAR(120) UNIQUE KEY,
	status_id INT UNSIGNED NOT NULL,
	created_at DATETIME DEFAULT CURRENT_TIMESTAMP,  
	updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE = InnoDB DEFAULT CHARSET=utf8;

UPDATE students SET status_id  = 3 WHERE id IN(300, 299, 298, 230, 105);
SELECT * FROM students s LIMIT 10;

CREATE UNIQUE INDEX index_email ON students (email);
CREATE INDEX index_last_name ON students (last_name);

-- Таблица возможных статусов студента: активен/отчислен/академический отпуск
CREATE TABLE student_statuses (
	id INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	name VARCHAR(50) NOT NULL
) ENGINE = InnoDB DEFAULT CHARSET = utf8;

ALTER TABLE students
ADD FOREIGN KEY (status_id)
REFERENCES student_statuses (id)
ON UPDATE CASCADE;

CREATE TABLE labs (
	id INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	name CHAR(4) UNIQUE,
	description VARCHAR(255),
	created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
	updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- преподаватели кафедры
CREATE TABLE teachers (
	id INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	first_name VARCHAR(50) NOT NULL,
	second_name VARCHAR(50),
	last_name VARCHAR(50) NOT NULL,
	email VARCHAR(120) UNIQUE KEY,
	phone VARCHAR(120) UNIQUE KEY,
	created_at DATETIME DEFAULT CURRENT_TIMESTAMP,  
	updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE = InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `groups` (
	id INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	name CHAR(7) UNIQUE KEY,
	specialization_id INT UNSIGNED NOT NULL,
	resp_student_id INT UNSIGNED NOT NULL COMMENT 'староста группы',  
	started_at DATE,
	FOREIGN KEY (resp_student_id) REFERENCES students (id) ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET=utf8;

ALTER TABLE `groups` 
ADD FOREIGN KEY (specialization_id)
REFERENCES specializations (id)
ON UPDATE CASCADE;

-- специализация группы - к ней привязана продолжительность курса физики и когда начало курса: осенью или весной  
CREATE TABLE specializations (
	id INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	name CHAR(3) UNIQUE NOT NULL,
	course_duration INT UNSIGNED NOT NULL COMMENT 'количество семестров в курсе',
	started_at_period CHAR(6) NOT NULL COMMENT 'время года, когда у данной специализации начинается курс физики - autumn/spring'
) ENGINE = InnoDB DEFAULT CHARSET=utf8;

-- количество лаб. работ для данной специальности по семестрам
CREATE TABLE num_labs_spec_per_semesrt (
	specialization_id INT UNSIGNED NOT NULL,
	semestr_num INT UNSIGNED NOT NULL,
	labs_count INT UNSIGNED NOT NULL,
	PRIMARY KEY (specialization_id, semestr_num)
) ENGINE = InnoDB DEFAULT CHARSET=utf8 COMMENT 'количество лабораторных работ в семестрах';

ALTER TABLE num_labs_spec_per_semesrt
ADD FOREIGN KEY (specialization_id) 
REFERENCES specializations (id)
ON UPDATE CASCADE;

CREATE OR REPLACE VIEW group_live_data AS 
	SELECT
		id,
		name,
		(SELECT course_duration FROM specializations s WHERE s.id = g.specialization_id) AS course_duration,
		DATE_FORMAT(started_at, '%Y%m') AS started_at,
		finish_time_obtain_1 ((SELECT course_duration FROM specializations s WHERE s.id = g.specialization_id), started_at) AS finished_at,
		group_status_obtain(DATE_FORMAT(started_at, '%Y%m'), finish_time_obtain_1 ((SELECT course_duration FROM specializations s WHERE s.id = g.specialization_id), started_at)) AS group_status,
		semestr_num_now_obtain((SELECT course_duration FROM specializations s WHERE s.id = g.specialization_id), started_at) AS semestr_num_now,
		(SELECT labs_count FROM num_labs_spec_per_semesrt nlsps WHERE g.specialization_id = nlsps.specialization_id AND nlsps.semestr_num  = semestr_num_now_obtain((SELECT course_duration FROM specializations s WHERE s.id = g.specialization_id), started_at))AS num_labs_this_semestr
	FROM 
		`groups` g;

-- таблица связи групп-студентов--учетелей
DROP TABLE IF EXISTS groups_students_teachers;
CREATE TABLE groups_students_teachers (
	teacher_id INT UNSIGNED NOT NULL,
	group_id INT UNSIGNED NOT NULL,
	student_id INT UNSIGNED NOT NULL,
	PRIMARY KEY (student_id),
	FOREIGN KEY (teacher_id) REFERENCES teachers (id) ON UPDATE CASCADE,
	FOREIGN KEY (group_id) REFERENCES `groups` (id) ON UPDATE CASCADE,
	FOREIGN KEY (student_id) REFERENCES students (id) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE INDEX teacher_id_group_id ON groups_students_teachers (teacher_id, group_id);
DROP INDEX teacher_id_group_id ON groups_students_teachers;

-- основная таблица контроля работы
DROP TABLE IF EXISTS labs_accounting;
CREATE TABLE labs_accounting (
	student_id INT UNSIGNED NOT NULL,
	lab_id INT UNSIGNED NOT NULL,
	lab_status_id INT UNSIGNED NOT NULL,
	teacher_id INT UNSIGNED NOT NULL,
	semestr_name CHAR(9) NOT NULL COMMENT 'варианты осеньyyyy/веснаyyyy',
	PRIMARY KEY (student_id, lab_id),
	FOREIGN KEY (lab_id) REFERENCES labs (id) ON UPDATE CASCADE,
	FOREIGN KEY (lab_status_id) REFERENCES labs_statuses (id) ON UPDATE CASCADE,
	FOREIGN KEY (teacher_id) REFERENCES teachers (id) ON UPDATE CASCADE
)	ENGINE=InnoDB DEFAULT CHARSET=utf8;

ALTER TABLE labs_accounting 
ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE labs_accounting 
ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

UPDATE labs_accounting SET created_at = DEFAULT;
UPDATE labs_accounting SET updated_at = DEFAULT;

-- таблица статусов лабораторной работы студента: назначена/получен допуск/выполнена/защищена
CREATE TABLE labs_statuses (
	id INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	name VARCHAR(40) NOT NULL
)	ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- представление в котором проводится оценка текущей успеваемости студентов. alarm_status - индикатор (принимает значения 0/1), если 1 - то студент считается неуспевающим
CREATE OR REPLACE VIEW students_progress AS 
	SELECT DISTINCT
		student_id AS st_id,
		SUM(IF(lab_status_id = (SELECT id FROM labs_statuses ls WHERE name = 'защищена'), 1, 0)) OVER(PARTITION BY student_id) AS labs_done,
		FLOOR(weeks_spend () * (SELECT num_labs_this_semestr FROM group_live_data gld JOIN groups_students_teachers gst ON gld.id = gst.group_id WHERE gst.student_id = st_id) / (SELECT weeks_num FROM weeks_num_per_semestr WHERE name = LEFT(semestr_name_now (), 5))) AS labs_should_be_done_for_this_time,
		IF(SUM(IF(lab_status_id = (SELECT id FROM labs_statuses ls WHERE name = 'защищена'), 1, 0)) OVER(PARTITION BY student_id) < FLOOR(weeks_spend () * (SELECT num_labs_this_semestr FROM group_live_data gld JOIN groups_students_teachers gst ON gld.id = gst.group_id WHERE gst.student_id = st_id) / (SELECT weeks_num FROM weeks_num_per_semestr WHERE name = LEFT(semestr_name_now (), 5))), 1, 0) AS alarm_status -- IF(labs_done < labs_should_be_done_for_this_time, 1, 0)
	FROM labs_accounting la JOIN students s ON la.student_id =  s.id 
	WHERE semestr_name = semestr_name_now () AND s.status_id = 1;

-- справочная таблица - сейчас 14 учебных недель и в первом и во втором семестре
CREATE TABLE weeks_num_per_semestr (
	id INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	name CHAR(5) NOT NULL,
	weeks_num INT UNSIGNED NOT NULL
) ENGINE=Archive DEFAULT CHARSET=utf8;
	