-- неуспевающие студенты
SELECT first_name, second_name, last_name, email, phone
  FROM students s 
  JOIN students_progress sp ON s.id = sp.st_id 
 WHERE alarm_status = 1; 

-- подробная информация по работе неуспевающих студентов
SELECT
	student_id,
	first_name, 
	second_name, 
	last_name,
	(SELECT name FROM labs l WHERE l.id = lab_id) AS lab_name,
	(SELECT description FROM labs l WHERE l.id = lab_id) AS lab_desc,
	(SELECT name FROM labs_statuses ls WHERE ls.id = lab_status_id) AS lab_status
  FROM students s 
  JOIN students_progress sp ON s.id = sp.st_id 
  JOIN labs_accounting la ON s.id = la.student_id 
 WHERE alarm_status = 1 AND semestr_name  = semestr_name_now (); 


-- общая статистика успеваемости по группам
SELECT DISTINCT 
-- gld.id AS group_id,
	gld.name AS group_name,
	COUNT(*) OVER(PARTITION BY gld.id) AS count_students,
	SUM(IF(sp.alarm_status = 1, 1, 0)) OVER(PARTITION BY gld.id) AS problem_students_count,
	ROUND((SUM(IF(sp.alarm_status = 1, 1, 0)) OVER(PARTITION BY gld.id) * 100 ) / (COUNT(*) OVER(PARTITION BY gld.id))) AS percents,
	(SELECT last_name FROM teachers t WHERE t.id = gst.teacher_id) AS teacher_last_name,
	semestr_name_now()
  FROM group_live_data gld 
  JOIN groups_students_teachers gst ON gld.id = gst.group_id 
  LEFT JOIN students_progress sp ON gst.student_id = sp.st_id
 WHERE gld.group_status = 'active'
 ORDER BY percents DESC;

-- показатели по группам в динамике
CREATE TABLE groups_statistics_evolution (
	id INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT, 
	group_name CHAR(7) NOT NULL,
	count_studnets INT UNSIGNED NOT NULL,
	problem_student_count INT UNSIGNED NOT NULL,
	persents INT UNSIGNED NOT NULL,
	teacher_last_name VARCHAR(50) NOT NULL,
	semestr_name CHAR(9) NOT NULL, 
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	) ENGINE=Archive DEFAULT CHARSET=utf8;

-- создаем задачу по вставки в талбицу, по расписанию, на уровне ОС. В итоге можно смотреть статистику по преподавателям, по группам и по работе кафедры в целом в динамике.
INSERT INTO groups_statistics_evolution (group_name, count_studnets, problem_student_count, persents, teacher_last_name, semestr_name) 
SELECT DISTINCT 
	gld.name AS group_name,
	COUNT(*) OVER(PARTITION BY gld.id) AS count_students,
	SUM(IF(sp.alarm_status = 1, 1, 0)) OVER(PARTITION BY gld.id) AS problem_students_count,
	ROUND((SUM(IF(sp.alarm_status = 1, 1, 0)) OVER(PARTITION BY gld.id) * 100 ) / (COUNT(*) OVER(PARTITION BY gld.id))) AS percents,
	(SELECT last_name FROM teachers t WHERE t.id = gst.teacher_id) AS teacher_last_name,
	semestr_name_now()
  FROM group_live_data gld 
  JOIN groups_students_teachers gst ON gld.id = gst.group_id 
  LEFT JOIN students_progress sp ON gst.student_id = sp.st_id
 WHERE gld.group_status = 'active';

SELECT * FROM groups_statistics_evolution;

-- топ 3 самых сложных работы в итории (не в этом семестре)
SELECT DISTINCT 
	(SELECT name FROM labs l WHERE la.lab_id = l.id) AS lab_name, 
	COUNT(*) OVER(PARTITION BY la.lab_id)  AS count_students,
	SUM(IF(la.lab_status_id  = (SELECT id FROM labs_statuses ls WHERE name = 'защищена'), 1, 0)) OVER(PARTITION BY la.lab_id) AS count_students_comleted,
	ROUND((SUM(IF(la.lab_status_id  = (SELECT id FROM labs_statuses ls WHERE name = 'защищена'), 1, 0)) OVER(PARTITION BY la.lab_id)) * 100 / (COUNT(*) OVER(PARTITION BY la.lab_id))) AS persents
FROM labs_accounting la 
WHERE semestr_name != semestr_name_now ()
ORDER BY persents LIMIT 3;

-- Выборка проблемных студентов конретной группы (например для БИН1907) для рассылки старосте
SELECT
	g.name AS group_name,
	(SELECT first_name FROM students s WHERE s.id = g.resp_student_id) AS resp_student_first_name,
	(SELECT last_name FROM students s WHERE s.id = g.resp_student_id) AS resp_student_last_name,
	(SELECT email FROM students s WHERE s.id = g.resp_student_id) AS resp_student_email,
	first_name, 
	second_name, 
	last_name,
	(SELECT name FROM labs l WHERE l.id = lab_id) AS lab_name,
	(SELECT description FROM labs l WHERE l.id = lab_id) AS lab_desc,
	(SELECT name FROM labs_statuses ls WHERE ls.id = lab_status_id) AS lab_status
  FROM students s 
  JOIN students_progress sp ON s.id = sp.st_id 
  JOIN labs_accounting la ON s.id = la.student_id 
  JOIN groups_students_teachers gst ON s.id = gst.student_id
  JOIN `groups` g ON g.id = gst.group_id 
 WHERE alarm_status = 1 AND semestr_name  = semestr_name_now () AND g.name = 'БИН1907'; 


