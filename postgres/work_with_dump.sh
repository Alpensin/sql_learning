pg_dump postgresql://test:test@localhost:6541/test > before_dd_part_dump.sql
psql postgresql://test:test@localhost:6541/test < before_dd_part_dump.sql 
