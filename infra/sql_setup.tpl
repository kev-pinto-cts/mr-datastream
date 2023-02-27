-- This Bit is to Setup Logical Replication on the DB
DO
\$do$
DECLARE
 rs1 character varying(255);
 rs2 character varying(255);
BEGIN
    ALTER USER ${user} with REPLICATION;

    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'pub1') THEN
        RAISE NOTICE 'Creating Pubication pub1';
        CREATE PUBLICATION pub1 FOR ALL TABLES  WITH (publish = 'insert,update,delete') ;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'pub2') THEN
        RAISE NOTICE 'Creating Pubication pub2';
        CREATE PUBLICATION pub2 FOR ALL TABLES  WITH (publish = 'insert,update,delete') ;
    END IF;

    COMMIT;
    IF NOT EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = 'rs1') THEN
        RAISE NOTICE 'Creating Replication Slot rs1';
        rs1 := (SELECT PG_CREATE_LOGICAL_REPLICATION_SLOT('rs1', 'pgoutput'));
    END IF;
    COMMIT;

    IF NOT EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = 'rs2') THEN
        RAISE NOTICE 'Creating Replication Slot rs2';
        rs2:= (SELECT PG_CREATE_LOGICAL_REPLICATION_SLOT('rs2', 'pgoutput'));
    END IF;

    CREATE SCHEMA IF NOT EXISTS ${schema};
    GRANT SELECT ON ALL TABLES IN SCHEMA ${schema} TO ${user};
    GRANT USAGE ON SCHEMA ${schema} TO ${user};
    ALTER DEFAULT PRIVILEGES IN SCHEMA ${schema} GRANT SELECT ON TABLES TO ${user};

END
\$do$;
