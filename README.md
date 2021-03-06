# DB_MTUCI_labs
БД для автоматизации учета успеваемости студентов по лабораторным работам, проводимым в рамках курса общей физики на 1 и 2 курсах Московского технического университета связи и информатики.

### Цель проекта:
Спроектировать БД, которая будет содержать данные по всем студентам и преподавателям кафедры, по текущей работе студентов. Создать индикатор, который в режиме live позволит вычислять неуспевающих студентов. Сформулировать критерии "неуспеваемости". Надстроить над БД аналитику, которая позволит оценивать работу кафедры и студентов, находить и информировать неуспевающих студентов по различным каналам связи.

### Краткое описание процесса:
Курс физики может длиться 2 или 3 семестра в зависимости от специальности. Так же в зависимости от специальности, в каждом семестре студенту необходимо выполнить определенное количество лабораторных работ. В начале семестра каждому студенту назначаются номера работ, которые необходимо выполнить. Далее по каждой работе он должен получить сначала допуск к выполнению, затем выполнить, затем защитить. В каждую группу для приема работ назначаются двое или один преподаватель.

#### Порядок деплоя:
1) labs_functions.sql - создание всех функций
2) labs.sql - создание таблиц и представлений (представления используют функции из labs_functions.sql)
3) labs_DB_fill.sql - заполнение БД тестовыми данными
4) labs_queries.sql - аналитика БД
