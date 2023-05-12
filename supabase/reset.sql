DO $$DECLARE r record;
BEGIN
    FOR r IN SELECT * FROM information_schema.triggers
             WHERE trigger_schema = 'public'
    LOOP EXECUTE 'DROP TRIGGER IF EXISTS "' || r.trigger_name || '" ON "' || r.event_object_table || '"';
    END LOOP;

    FOR r IN SELECT * FROM information_schema.routines
             WHERE routine_type = 'FUNCTION' AND routine_schema = 'public'
    LOOP EXECUTE 'DROP FUNCTION "' || r.routine_name || '" CASCADE';
    END LOOP;

    FOR r IN SELECT * FROM information_schema.views
             WHERE table_schema = 'public'
    LOOP EXECUTE 'DROP VIEW "' || r.table_name || '" CASCADE';
    END LOOP;

    FOR r IN SELECT * FROM information_schema.tables
                WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
    LOOP EXECUTE 'DROP TABLE "' || r.table_name || '" CASCADE';
    END LOOP;

    FOR r IN SELECT * FROM information_schema.domains
                WHERE domain_schema = 'public'
    LOOP EXECUTE 'DROP DOMAIN "' || r.domain_name || '"';
    END LOOP;

    FOR r IN SELECT * FROM pg_policies
                WHERE schemaname = 'public'
    LOOP EXECUTE 'DROP POLICY "' || r.policyname || '" ON "' || r.tablename || '" CASCADE' ;
    END LOOP;

END$$;

DROP TYPE IF EXISTS app_permission;
