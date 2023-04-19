-- Postgres bootstrap - For automation/testing purposes only!

-- Canton domain and participants user and databases

CREATE ROLE domain WITH PASSWORD 'umn2uAR3byW4uDERUWD4s19RebC6eb2_pr6eCmfa' LOGIN;
ALTER ROLE domain SET statement_timeout=60000;
COMMENT ON ROLE domain IS 'Canton - Domain topology manager role';

CREATE ROLE mediator WITH PASSWORD 'eFDW5kY5y2sThMnrD14BVajGdrJQK1zpjXBs49_m' LOGIN;
ALTER ROLE mediator SET statement_timeout=60000;
COMMENT ON ROLE mediator IS 'Canton - Mediator role';

CREATE ROLE sequencer WITH PASSWORD 'mfd?f=mVDrtKwL=UjDGJXAEbkWm22Zgu5QBEz=UJ' LOGIN;
ALTER ROLE sequencer SET statement_timeout=60000;
COMMENT ON ROLE sequencer IS 'Canton - Sequencer role';

CREATE ROLE participant1 WITH PASSWORD 'EQY#QPmnUbx_eXp1HzJmK98fKcUVryLCa31xq6NR' LOGIN;
ALTER ROLE participant1 SET statement_timeout=60000;
COMMENT ON ROLE participant1 IS 'Canton - Participant role';

CREATE ROLE participant2 WITH PASSWORD 'iAZfuP27a2GRci1jWdzXPWcDJ4Y1KtHY59XvapiJ' LOGIN;
ALTER ROLE participant2 SET statement_timeout=60000;
COMMENT ON ROLE participant2 IS 'Canton - Participant role';

CREATE DATABASE domain OWNER domain;
COMMENT ON DATABASE domain IS 'Canton - Domain topology manager database';
REVOKE ALL ON DATABASE domain FROM public;
GRANT CONNECT ON DATABASE domain TO domain;
\c domain
REVOKE ALL ON schema public FROM public;
ALTER SCHEMA public OWNER TO domain;

CREATE DATABASE mediator OWNER mediator;
COMMENT ON DATABASE mediator IS 'Canton - Mediator database';
REVOKE ALL ON DATABASE mediator FROM public;
GRANT CONNECT ON DATABASE mediator TO mediator;
\c mediator
REVOKE ALL ON schema public FROM public;
ALTER SCHEMA public OWNER TO mediator;

CREATE DATABASE sequencer OWNER sequencer;
COMMENT ON DATABASE sequencer IS 'Canton - Sequencer database';
REVOKE ALL ON DATABASE sequencer FROM public;
GRANT CONNECT ON DATABASE sequencer TO sequencer;
\c sequencer
REVOKE ALL ON schema public FROM public;
ALTER SCHEMA public OWNER TO sequencer;

CREATE DATABASE participant1 OWNER participant1;
COMMENT ON DATABASE participant1 IS 'Canton - Participant database';
REVOKE ALL ON DATABASE participant1 FROM public;
GRANT CONNECT ON DATABASE participant1 TO participant1;
\c participant1
REVOKE ALL ON schema public FROM public;
ALTER SCHEMA public OWNER TO participant1;

CREATE DATABASE participant2 OWNER participant2;
COMMENT ON DATABASE participant2 IS 'Canton - Participant database';
REVOKE ALL ON DATABASE participant2 FROM public;
GRANT CONNECT ON DATABASE participant2 TO participant2;
\c participant2
REVOKE ALL ON schema public FROM public;
ALTER SCHEMA public OWNER TO participant2;

-- HTTP JSON API service user and database

CREATE ROLE json WITH PASSWORD 'dvpKN3tNBV9SBZ19qNFJqWPtHzKiZXp9Vn?#i1eU' LOGIN;
ALTER ROLE json SET statement_timeout=60000;
COMMENT ON ROLE json IS 'Daml - HTTP JSON API service role';

CREATE DATABASE json OWNER json;
COMMENT ON DATABASE json IS 'Daml - HTTP JSON API service database';
REVOKE ALL ON DATABASE json FROM public;
GRANT CONNECT ON DATABASE json TO json;
\c json
REVOKE ALL ON schema public FROM public;
ALTER SCHEMA public OWNER TO json;

-- Trigger service user and database

CREATE ROLE trigger WITH PASSWORD 'h68M#M1uL4pGgwU1dXN9zN7j+KBhQprNBbA9NJHP' LOGIN;
ALTER ROLE trigger SET statement_timeout=60000;
COMMENT ON ROLE trigger IS 'Daml - Trigger service role';

CREATE DATABASE trigger OWNER trigger;
COMMENT ON DATABASE trigger IS 'Daml - Trigger service database';
REVOKE ALL ON DATABASE trigger FROM public;
GRANT CONNECT ON DATABASE trigger TO trigger;
\c trigger
REVOKE ALL ON schema public FROM public;
ALTER SCHEMA public OWNER TO trigger;

-- (Optional) Revoke all default privileges in databases if needed (check with \ddp)

-- ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON FUNCTIONS  FROM public;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON PROCEDURES FROM public;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON ROUTINES   FROM public;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SCHEMAS    FROM public;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES  FROM public;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES     FROM public;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TYPES      FROM public;
