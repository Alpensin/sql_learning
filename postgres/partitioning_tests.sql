--- TEST1. Чистые таблицы
CREATE TABLE test_table (
    a INTEGER,
    b INTEGER,
    c INTEGER
) PARTITION BY LIST (c);

CREATE TABLE test_table_1 PARTITION OF test_table FOR VALUES IN (1);
CREATE TABLE test_table_2 PARTITION OF test_table FOR VALUES IN (2);
CREATE TABLE test_table_3 PARTITION OF test_table FOR VALUES IN (3);

DROP TABLE test_table_1;

INSERT INTO test_table (a, b, c) SELECT generate_series(1, 500), generate_series(1, 500), 1 FROM generate_series(1, 5000);
/* После запуска, пока идет вставка, вставлял данные через другой клиент в другие секции. И делал запрос на просмотр данных
INSERT INTO test_table (a, b, c) SELECT generate_series(1, 50), generate_series(1, 50), 2 FROM generate_series(1, 50);
INSERT INTO test_table (a, b, c) SELECT generate_series(1, 50), generate_series(1, 50), 3 FROM generate_series(1, 50);
select c, count(c) from test_table group by c;
НЕТ БЛОКИРОВОК
*/

--- TEST2 - есть PK (a, c)

DROP TABLE test_table;

CREATE TABLE test_table (
    a INTEGER,
    b INTEGER,
    c INTEGER,
    PRIMARY KEY(a, c)
) PARTITION BY LIST (c);
CREATE TABLE test_table_1 PARTITION OF test_table FOR VALUES IN (1);
CREATE TABLE test_table_2 PARTITION OF test_table FOR VALUES IN (2);
CREATE TABLE test_table_3 PARTITION OF test_table FOR VALUES IN (3);
INSERT INTO test_table (a, b, c) SELECT generate_series(1, 1000000), 444, 1;
/* После запуска, пока идет вставка, вставлял данные через другой клиент в другие секции. И делал запрос на просмотр данных
INSERT INTO test_table (a, b, c) SELECT generate_series(1, 50), 444, 2;
INSERT INTO test_table (a, b, c) SELECT generate_series(1, 50), 444, 3;
select c, count(c) from test_table group by c;
НЕТ БЛОКИРОВОК
*/


--- TEST3 - есть PK (a, c) и есть общий sequence

DROP TABLE test_table;
DROP SEQUENCE IF EXISTS test_table_a_seq_1;
CREATE SEQUENCE test_table_a_seq_1 START 1;
CREATE TABLE test_table (
    a INTEGER DEFAULT nextval('test_table_a_seq_1'),
    b INTEGER,
    c INTEGER,
    PRIMARY KEY(a, c)
) PARTITION BY LIST (c);
CREATE TABLE test_table_1 PARTITION OF test_table FOR VALUES IN (1);
CREATE TABLE test_table_2 PARTITION OF test_table FOR VALUES IN (2);
CREATE TABLE test_table_3 PARTITION OF test_table FOR VALUES IN (3);
INSERT INTO test_table (b, c) SELECT generate_series(1, 1000000), 1;
/* После запуска, пока идет вставка, вставлял данные через другой клиент в другие секции. И делал запрос на просмотр данных
INSERT INTO test_table (b, c) SELECT generate_series(1, 100), 2;
INSERT INTO test_table (b, c) SELECT generate_series(1, 100), 3;
select c, count(c) from test_table group by c;
НЕТ БЛОКИРОВОК. Общий ключ отрабатывает корректно.
*/

--- TEST4 - есть PK (a, c) и есть общий sequence. Есть общий индекс

DROP TABLE test_table;
DROP SEQUENCE IF EXISTS test_table_a_seq_1;
CREATE SEQUENCE test_table_a_seq_1 START 1;
CREATE TABLE test_table (
    a INTEGER DEFAULT nextval('test_table_a_seq_1'),
    b INTEGER NOT NULL,
    c INTEGER,
    d INTEGER NOT NULL,
    PRIMARY KEY(a, c)
) PARTITION BY LIST (c);
CREATE INDEX test_table_b_d_index ON test_table (b, d);
CREATE TABLE test_table_1 PARTITION OF test_table FOR VALUES IN (1);
CREATE TABLE test_table_2 PARTITION OF test_table FOR VALUES IN (2);
CREATE TABLE test_table_3 PARTITION OF test_table FOR VALUES IN (3);
INSERT INTO test_table (b, c, d) SELECT generate_series(1, 1000000), 1, 50;
/* После запуска, пока идет вставка, вставлял данные через другой клиент в другие секции. И делал запрос на просмотр данных
INSERT INTO test_table (b, c, d) SELECT generate_series(1, 100), 2, 60;
INSERT INTO test_table (b, c, d) SELECT generate_series(1, 100), 3, 70;
select c, count(c) from test_table group by c;
НЕТ БЛОКИРОВОК. Общий ключ отрабатывает корректно.
*/

--- TEST5 - есть PK (a, c) и есть общий sequence. Есть общий индекс. Работа в транзакции. Создание секций в ходе транзакций.

DROP TABLE test_table;
DROP SEQUENCE IF EXISTS test_table_a_seq_1;
CREATE SEQUENCE test_table_a_seq_1 START 1;
CREATE TABLE test_table (
    a INTEGER DEFAULT nextval('test_table_a_seq_1'),
    b INTEGER NOT NULL,
    c INTEGER,
    d INTEGER NOT NULL,
    PRIMARY KEY(a, c)
) PARTITION BY LIST (c);
CREATE INDEX test_table_b_d_index ON test_table (b, d);
BEGIN;
CREATE TABLE test_table_1 PARTITION OF test_table FOR VALUES IN (1);
INSERT INTO test_table (b, c, d) SELECT generate_series(1, 3000000), 1, 50;
COMMIT;

/* После запуска, пока идет вставка, вставлял данные через другой клиент в другие секции. И делал запрос на просмотр данных
CREATE TABLE test_table_2 PARTITION OF test_table FOR VALUES IN (2);
INSERT INTO test_table (b, c, d) SELECT generate_series(1, 100), 2, 60;
CREATE TABLE test_table_3 PARTITION OF test_table FOR VALUES IN (3);
INSERT INTO test_table (b, c, d) SELECT generate_series(1, 100), 3, 70;
select c, count(c) from test_table group by c;
БЛОКИРОВКА!!! Создание секции в транзакции для c = 1 блокирует всю таблицу и держит блокировку до завершения транзакции!
*/
