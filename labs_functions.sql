-- порядок деплоя БД
-- 1) labs_functions.sql - создание всех функций
-- 2) labs.sql - создание таблиц и представлений (представления используют функции из labs_functions.sql)
-- 3) labs_DB_fill.sql - заполнение БД тестовыми данными
-- 4*) labs_queries.sql - аналитика БД

CREATE DATABASE MTUCI_labs;
USE MTUCI_labs;

SET GLOBAL log_bin_trust_function_creators = 1; -- позволяет создавать функции NOT DETERMINISTIC в mysql 8

-- функция вычисляет дату окончания курса физики данной группы
DELIMITER //
CREATE FUNCTION finish_time_obtain_1 (d INT, started_at DATE)
RETURNS INT DETERMINISTIC
BEGIN
	DECLARE res int;
	IF MONTH(started_at) = 9 THEN
		case d 
			when 2 THEN SET res = PERIOD_ADD(DATE_FORMAT(started_at, '%Y%m'), 9);
			when 3 THEN SET res = PERIOD_ADD(DATE_FORMAT(started_at, '%Y%m'), 16);
			else SIGNAL SQLSTATE '11000' SET MESSAGE_TEXT = 'Ошибка данных (количество семестров может быть либо 2 либо 3)';
		end case;
	ELSEIF MONTH(started_at) = 2 THEN
		case d 
			when 2 then SET res = PERIOD_ADD(DATE_FORMAT(started_at, '%Y%m'), 11);
			when 3 then SET res = PERIOD_ADD(DATE_FORMAT(started_at, '%Y%m'), 16);
			else SIGNAL SQLSTATE '11000' SET MESSAGE_TEXT = 'Ошибка данных (количество семестров может быть либо 2 либо 3)';
		end case;
	ELSE 
		SIGNAL SQLSTATE '11000' SET MESSAGE_TEXT = 'Ошибка данных (семестр начинается либо в сентябре либо в феврале)';
	END IF;
	RETURN res;
END//

-- функция выставляет статус группы - активная/закнчила курс физики
DELIMITER //
CREATE FUNCTION group_status_obtain (year_month_started_course INT, year_month_finished_course INT)
RETURNS CHAR(8) NOT DETERMINISTIC
BEGIN
	DECLARE res CHAR(8);
	SET res = IF(DATE_FORMAT(NOW(), '%Y%m') BETWEEN year_month_started_course AND year_month_finished_course, 'active', 'finished');
	RETURN res;
END//

-- функция возращает текущий семест изучения физики группы
DELIMITER //
CREATE FUNCTION semestr_num_now_obtain (d INT, started_at DATE)
RETURNS INT DETERMINISTIC
BEGIN
	DECLARE res INT DEFAULT 0;
	IF MONTH(started_at) = 9 THEN
		CASE 
			WHEN DATE_FORMAT(NOW(), '%Y%m') BETWEEN DATE_FORMAT(started_at, '%Y%m') AND CONCAT(YEAR(started_at) + 1, '01') THEN SET res = 1;
			WHEN DATE_FORMAT(NOW(), '%Y%m') BETWEEN CONCAT(YEAR(started_at) + 1, '02') AND CONCAT(YEAR(started_at) + 1, '08') THEN SET res = 2;
			WHEN d = 3 AND (DATE_FORMAT(NOW(), '%Y%m') BETWEEN CONCAT(YEAR(started_at) + 1, '09') AND CONCAT(YEAR(started_at) + 2, '01')) THEN SET res = 3;
			ELSE RETURN NULL;
		END CASE;
	ELSEIF MONTH(started_at) = 2 THEN
		CASE 
			WHEN DATE_FORMAT(NOW(), '%Y%m') BETWEEN DATE_FORMAT(started_at, '%Y%m') AND CONCAT(YEAR(started_at), '08') THEN SET res = 1;
			WHEN DATE_FORMAT(NOW(), '%Y%m') BETWEEN CONCAT(YEAR(started_at), '09') AND CONCAT(YEAR(started_at) + 1, '01') THEN SET res = 2;
			WHEN d = 3 AND (DATE_FORMAT(NOW(), '%Y%m') BETWEEN CONCAT(YEAR(started_at) + 1, '02') AND CONCAT(YEAR(started_at) + 1, '08')) THEN SET res = 3;
			ELSE RETURN NULL;
		END CASE;
	ELSE 
		SIGNAL SQLSTATE '11000' SET MESSAGE_TEXT = 'Ошибка данных (семестр начинается либо в сентябре либо в феврале)';
	END IF;
	RETURN res;
END//

-- функция возращает название семестра в формате осеньXXXX/веснаXXXX
DELIMITER //
CREATE FUNCTION semestr_name_now ()
RETURNS CHAR(9) NOT DETERMINISTIC
BEGIN
	DECLARE res CHAR(9);
	IF MONTH(NOW()) IN (9, 10, 11, 12, 1) THEN
		SET res = CONCAT('осень', YEAR (NOW())); 
	ELSE 
		SET res = CONCAT('весна', YEAR (NOW()));
	END IF;
	RETURN res;
END//

-- Функция возвращает прошедшее количество учебных недель текущего семестра на данный момент
DELIMITER //
CREATE FUNCTION weeks_spend ()
RETURNS INT NOT DETERMINISTIC
BEGIN
	DECLARE res INT DEFAULT 0;
	DECLARE total_weeks_this_sem INT;
	SET total_weeks_this_sem = (SELECT weeks_num FROM weeks_num_per_semestr WHERE name = LEFT(semestr_name_now (), 5));
	IF LEFT(semestr_name_now (), 5) = 'весна' THEN
		SET res = IF(WEEK(NOW()) - WEEK(CONCAT(RIGHT(semestr_name_now (), 4), '-02-01')) < 14, WEEK(NOW()) - WEEK(CONCAT(RIGHT(semestr_name_now (), 4), '-02-01')), 14); 
	ELSE 
		SET res = IF(ABS(WEEK(NOW()) - WEEK(CONCAT(RIGHT(semestr_name_now (), 4), '-09-01'))) < 14, WEEK(NOW()) - WEEK(CONCAT(RIGHT(semestr_name_now (), 4), '-09-01')), 14);
	END IF;
	RETURN res;
END//

