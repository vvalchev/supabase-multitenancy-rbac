
BEGIN;
SELECT plan(13);

--- -----------------------------------------
--- Authentication helpers
--- -----------------------------------------
CREATE SCHEMA IF NOT EXISTS test;
GRANT USAGE ON SCHEMA test TO anon, authenticated;

CREATE OR REPLACE FUNCTION test.login_as_user(user_email text) RETURNS void
    LANGUAGE plpgsql
    AS $$
    DECLARE
        auth_user auth.users;
    BEGIN
        SELECT * into auth_user FROM auth.users WHERE email = user_email;
        PERFORM set_config('request.jwt.claims',
            json_strip_nulls(
                json_build_object(
                    'exp', extract(epoch FROM NOW() + INTERVAL '1 day')::bigint,
                    'sub', (auth_user).id::text,
                    'role', coalesce((auth_user).role, 'authenticated'),
                    'email', (auth_user).email,
                    'app_metadata', (auth_user).raw_app_meta_data
                )
            )::text,
            true
        );
        EXECUTE format('set role %I', coalesce((auth_user).role, 'authenticated'));
        RAISE NOTICE '---> LOGIN %', auth.jwt();
    end;
$$;

CREATE OR REPLACE FUNCTION test.login_as_anon() RETURNS void
    LANGUAGE plpgsql
    AS $$
    BEGIN
        PERFORM set_config('request.jwt.claims', null, true);
        SET role anon;
    END;
$$;

CREATE OR REPLACE FUNCTION test.logout() RETURNS void
    language plpgsql
    AS $$
    BEGIN
        PERFORM set_config('request.jwt.claims', null, true);
        SET role postgres;
        RAISE NOTICE '---> LOGOUT';
    END;
$$;

CREATE OR REPLACE FUNCTION test.set_user_role(user_email text, role_name text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
    DECLARE 
        target_user_id uuid;
    BEGIN
        SELECT id FROM auth.users WHERE email = user_email INTO target_user_id;
        DELETE FROM user_roles WHERE user_id = target_user_id;
        PERFORM public.add_role_to_user(target_user_id, role_name);
    END;
$$;



--- -----------------------------------------
--- Check if table is exported outside
--- -----------------------------------------
SELECT test.login_as_anon();
SELECT throws_ok('select * from tenants');
SELECT throws_ok('insert into tenants (name) values (''hello'');');
SELECT throws_ok('select * from tenant_members');
SELECT throws_ok('select * from roles');
SELECT throws_ok('select * from user_roles');
SELECT throws_ok('select * from user_permissions');
SELECT test.logout();

--- -----------------------------------------
--- Insert some test data
--- -----------------------------------------
INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), 'user1@test.com');
INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), 'user2@test.com');
INSERT INTO auth.users (id, email, raw_app_meta_data) VALUES (gen_random_uuid(), 'admin@test.com', '{"tenant_access": "read"}'::jsonb);

SELECT is(raw_app_meta_data, null)
    FROM auth.users WHERE email = 'user1@test.com';

--- add user to tenant members
INSERT INTO tenant_members  (tenant_id, user_id) VALUES
    (1, (select id from auth.users where email = 'user1@test.com')),
    (1, (select id from auth.users where email = 'user2@test.com'));

--- -----------------------------------------
--- Test if normal users don't have access to 'tenants' table
--- -----------------------------------------
SELECT test.set_user_role('user1@test.com', 'admins');
SELECT test.login_as_user('user1@test.com');
SELECT is_empty('select * from tenants');
SELECT test.logout();

--- -----------------------------------------
--- Test if '"tenant_access/read"' have read-only to 'tenants' table
--- -----------------------------------------
SELECT test.login_as_user('admin@test.com');

SELECT is(COUNT(*), 1::bigint, 'can read "tenants_table"')
    FROM tenants;
    
SELECT throws_ok('insert into tenants (name) values ("hello");');

SELECT test.logout();

--- -----------------------------------------
--- Test if '"tenant_access/write"' have read/write to 'tenants' table
--- -----------------------------------------
UPDATE auth.users SET raw_app_meta_data = raw_app_meta_data || '{"tenant_access":"write"}'
    WHERE email = 'admin@test.com';
SELECT test.login_as_user('admin@test.com');

SELECT is(COUNT(*), 1::bigint, 'can read "tenants_table"')
    FROM tenants;

SELECT lives_ok('insert into tenants (name) values (''hello'')');

SELECT is(COUNT(*), 2::bigint, 'insert works')
    FROM tenants;

SELECT test.logout();

-- TODO: we should test how 'set_claims' works. At the moment it works perfectly within trigger
-- but if I try to log in, `set_claims` fails with missing access to `auth.users`. And that is perfect!
-- I just don't know why?!


SELECT * FROM finish();
ROLLBACK;
