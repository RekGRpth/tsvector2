CREATE EXTENSION rum;
CREATE EXTENSION tsvector2;

CREATE TABLE test_rum_hash( t text, a tsvector2 );

CREATE TRIGGER tsvector2update
BEFORE UPDATE OR INSERT ON test_rum_hash
FOR EACH ROW EXECUTE PROCEDURE tsvector2_update_trigger('a', 'pg_catalog.english', 't');
CREATE INDEX rumhashidx ON test_rum_hash USING rum (a rum_tsvector2_hash_ops);

\copy test_rum_hash(t) from 'data/rum.data';

CREATE INDEX failed_rumidx ON test_rum_hash USING rum (a rum_tsvector2_addon_ops);

SET enable_seqscan=off;
SET enable_indexscan=off;

explain (costs off)
SELECT count(*) FROM test_rum_hash WHERE a @@ to_tsquery('pg_catalog.english', 'ever|wrote');
explain (costs off)
SELECT * FROM test_rum_hash WHERE a @@ to_tsquery('pg_catalog.english', 'ever|wrote')
ORDER BY a <=> to_tsquery('pg_catalog.english', 'ever|wrote');
explain (costs off)
SELECT count(*) FROM test_rum_hash WHERE a @@ to_tsquery('pg_catalog.english',
													'def <-> fgr');

SELECT count(*) FROM test_rum_hash WHERE a @@ to_tsquery('pg_catalog.english', 'ever|wrote');
SELECT count(*) FROM test_rum_hash WHERE a @@ to_tsquery('pg_catalog.english', 'have&wish');
SELECT count(*) FROM test_rum_hash WHERE a @@ to_tsquery('pg_catalog.english', 'knew&brain');
SELECT count(*) FROM test_rum_hash WHERE a @@ to_tsquery('pg_catalog.english', 'among');
SELECT count(*) FROM test_rum_hash WHERE a @@ to_tsquery('pg_catalog.english', 'structure&ancient');
SELECT count(*) FROM test_rum_hash WHERE a @@ to_tsquery('pg_catalog.english', '(complimentary|sight)&(sending|heart)');
SELECT count(*) FROM test_rum_hash WHERE a @@ to_tsquery('pg_catalog.english', '(gave | half) <-> way');
SELECT count(*) FROM test_rum_hash WHERE a @@ to_tsquery('pg_catalog.english', '(gave | !half) <-> way');
SELECT count(*) FROM test_rum_hash WHERE a @@ to_tsquery('pg_catalog.english', '!gave & way');
SELECT count(*) FROM test_rum_hash WHERE a @@ to_tsquery('pg_catalog.english', '!gave & wooded & !look');
SELECT count(*) FROM test_rum_hash WHERE a @@ to_tsquery('pg_catalog.english',
													'def <-> fgr');
SELECT count(*) FROM test_rum_hash WHERE a @@ to_tsquery('pg_catalog.english',
													'def <2> fgr');
SELECT rum_ts_distance(a, to_tsquery('pg_catalog.english', 'way')),
	   rum_ts_score(a, to_tsquery('pg_catalog.english', 'way')),
	   *
	FROM test_rum_hash
	WHERE a @@ to_tsquery('pg_catalog.english', 'way')
	ORDER BY a <=> to_tsquery('pg_catalog.english', 'way');
SELECT rum_ts_distance(a, to_tsquery('pg_catalog.english', 'way & (go | half)')),
	   rum_ts_score(a, to_tsquery('pg_catalog.english', 'way & (go | half)')),
	   *
	FROM test_rum_hash
	WHERE a @@ to_tsquery('pg_catalog.english', 'way & (go | half)')
	ORDER BY a <=> to_tsquery('pg_catalog.english', 'way & (go | half)');
SELECT
	a <=> to_tsquery('pg_catalog.english', 'way & (go | half)'), 
	rum_ts_distance(a, to_tsquery('pg_catalog.english', 'way & (go | half)')),
	rum_ts_score(a, to_tsquery('pg_catalog.english', 'way & (go | half)')),
	*
	FROM test_rum_hash
	ORDER BY a <=> to_tsquery('pg_catalog.english', 'way & (go | half)') limit 2;

-- Check ranking normalization
SELECT rum_ts_distance(a, to_tsquery('pg_catalog.english', 'way'), 0),
	   rum_ts_score(a, to_tsquery('pg_catalog.english', 'way'), 0),
	   *
	FROM test_rum_hash
	WHERE a @@ to_tsquery('pg_catalog.english', 'way')
	ORDER BY a <=> to_tsquery('pg_catalog.english', 'way');
SELECT rum_ts_distance(a, row(to_tsquery('pg_catalog.english', 'way & (go | half)'), 0)::rum_distance_query),
	   rum_ts_score(a, row(to_tsquery('pg_catalog.english', 'way & (go | half)'), 0)::rum_distance_query),
	   *
	FROM test_rum_hash
	WHERE a @@ to_tsquery('pg_catalog.english', 'way & (go | half)')
	ORDER BY a <=> to_tsquery('pg_catalog.english', 'way & (go | half)');

INSERT INTO test_rum_hash (t) VALUES ('foo bar foo the over foo qq bar');
INSERT INTO test_rum_hash (t) VALUES ('345 qwerty copyright');
INSERT INTO test_rum_hash (t) VALUES ('345 qwerty');
INSERT INTO test_rum_hash (t) VALUES ('A fat cat has just eaten a rat.');

SELECT count(*) FROM test_rum_hash WHERE a @@ to_tsquery('pg_catalog.english', 'bar');
SELECT count(*) FROM test_rum_hash WHERE a @@ to_tsquery('pg_catalog.english', 'qwerty&345');
SELECT count(*) FROM test_rum_hash WHERE a @@ to_tsquery('pg_catalog.english', '345');
SELECT count(*) FROM test_rum_hash WHERE a @@ to_tsquery('pg_catalog.english', 'rat');

SELECT a FROM test_rum_hash WHERE a @@ to_tsquery('pg_catalog.english', 'bar') ORDER BY a;

-- Check full-index scan with order by
SELECT a <=> to_tsquery('pg_catalog.english', 'ever|wrote') FROM test_rum_hash ORDER BY a <=> to_tsquery('pg_catalog.english', 'ever|wrote');

CREATE TABLE tst_hash (i int4, t tsvector2);
INSERT INTO tst_hash SELECT i%10, to_tsvector2('simple', substr(md5(i::text), 1, 1)) FROM generate_series(1,100000) i;
CREATE INDEX tst_hashidx ON tst_hash USING rum (t rum_tsvector2_hash_ops);

DELETE FROM tst_hash WHERE i = 1;
VACUUM tst_hash;
INSERT INTO tst_hash SELECT i%10, to_tsvector2('simple', substr(md5(i::text), 1, 1)) FROM generate_series(10001,11000) i;

DELETE FROM tst_hash WHERE i = 2;
VACUUM tst_hash;
INSERT INTO tst_hash SELECT i%10, to_tsvector2('simple', substr(md5(i::text), 1, 1)) FROM generate_series(11001,12000) i;

DELETE FROM tst_hash WHERE i = 3;
VACUUM tst_hash;
INSERT INTO tst_hash SELECT i%10, to_tsvector2('simple', substr(md5(i::text), 1, 1)) FROM generate_series(12001,13000) i;

DELETE FROM tst_hash WHERE i = 4;
VACUUM tst_hash;
INSERT INTO tst_hash SELECT i%10, to_tsvector2('simple', substr(md5(i::text), 1, 1)) FROM generate_series(13001,14000) i;

DELETE FROM tst_hash WHERE i = 5;
VACUUM tst_hash;
INSERT INTO tst_hash SELECT i%10, to_tsvector2('simple', substr(md5(i::text), 1, 1)) FROM generate_series(14001,15000) i;

set enable_bitmapscan=off;
SET enable_indexscan=on;
explain (costs off)
SELECT a <=> to_tsquery('pg_catalog.english', 'w:*'), *
	FROM test_rum_hash
	WHERE a @@ to_tsquery('pg_catalog.english', 'w:*')
	ORDER BY a <=> to_tsquery('pg_catalog.english', 'w:*');
SELECT a <=> to_tsquery('pg_catalog.english', 'w:*'), *
	FROM test_rum_hash
	WHERE a @@ to_tsquery('pg_catalog.english', 'w:*')
	ORDER BY a <=> to_tsquery('pg_catalog.english', 'w:*');

DROP TABLE tst_hash CASCADE;
DROP TABLE test_rum_hash CASCADE;
DROP EXTENSION tsvector2 CASCADE;
DROP EXTENSION rum CASCADE;
