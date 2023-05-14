
BEGIN;
SELECT plan(25);

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
        PERFORM test.logout();
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
    LANGUAGE plpgsql
    AS $$
    BEGIN
        PERFORM set_config('request.jwt.claims', null, true);
        SET role postgres;
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

CREATE OR REPLACE FUNCTION test.user_id(user_email text) RETURNS uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
        SELECT id FROM auth.users WHERE email = user_email;
$$;

CREATE OR REPLACE FUNCTION test.tenant_id(tenant_name text) RETURNS bigint
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
        SELECT id FROM tenants WHERE name = tenant_name;
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
INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), 'user3@test.com');
INSERT INTO auth.users (id, email, raw_app_meta_data) VALUES (gen_random_uuid(), 'admin@test.com', '{"tenant_access": "read"}'::jsonb);

SELECT is(raw_app_meta_data, null)
    FROM auth.users WHERE email = 'user1@test.com';

--- add user to tenant members
INSERT INTO tenant_members  (tenant_id, user_id) VALUES
    (1, test.user_id('user1@test.com')),
    (1, test.user_id('user2@test.com'));

--- -----------------------------------------
--- Test if normal users don't have access to 'tenants' table
--- -----------------------------------------
SELECT test.set_user_role('user1@test.com', 'admins');
SELECT test.login_as_user('user1@test.com');
SELECT is_empty('select * from tenants');

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


--- -----------------------------------------
--- Test if tenant members can read only their fellows and their own roles
--- -----------------------------------------
INSERT INTO tenant_members (tenant_id, user_id) VALUES
    ( (select id from tenants where name = 'hello'), test.user_id('user3@test.com') );
-- SELECT diag((select json_agg(tenant_members) from tenant_members));

SELECT test.login_as_user('user3@test.com');
SELECT is(COUNT(*), 1::bigint, 'user3 sees only one member (self)')
    FROM tenant_members;
SELECT is(COUNT(*), 0::bigint, 'user3 sees see roles for tenant "hello"')
    FROM roles;

SELECT test.login_as_user('user1@test.com');
SELECT is(COUNT(*), 2::bigint, 'user1 sees two member')
    FROM tenant_members;
SELECT is(COUNT(*), 4::bigint, 'user1 sees see roles for tenant "system"')
    FROM roles;
SELECT test.logout();

--- -----------------------------------------
--- Test 'tenant_members.assign' permission
--- -----------------------------------------
INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), 'user4@test.com');
SELECT test.set_user_role('user1@test.com', 'members_admins');
SELECT test.login_as_user('user1@test.com');

-- Cannot assign a user to the tenant, if I do not belong to it
SELECT throws_ok(
    $$
        INSERT INTO tenant_members (tenant_id, user_id) VALUES
            ( test.tenant_id('hello'), test.user_id('user4@test.com') );
    $$);
SELECT lives_ok(
    $$
        INSERT INTO tenant_members (tenant_id, user_id) VALUES
            ( 1, test.user_id('user4@test.com') );
    $$, 'Can assign a user to the tenant I belong to.');

--- -----------------------------------------
--- Test 'roles.edit' permission
--- -----------------------------------------
SELECT test.set_user_role('user1@test.com', 'permission_admins');
SELECT test.login_as_user('user1@test.com');

SELECT lives_ok(
    $$ insert into roles (tenant_id, name) values (1, 'test_role'); $$,
    'Can edit roles of own tenant.'
);
-- cannot create roles of another tenant
SELECT throws_ok(
    $$ insert into roles (tenant_id, name) values (test.tenant_id('hello'), 'test_role'); $$
);

--- -----------------------------------------
--- Test 'roles.assign' permission
--- -----------------------------------------
SELECT test.logout();
INSERT INTO roles (id, tenant_id, name) OVERRIDING SYSTEM VALUE VALUES
    (100, test.tenant_id('hello'), 'supergroup');
INSERT INTO tenant_members (tenant_id, user_id) VALUES
    ( test.tenant_id('hello'), test.user_id('admin@test.com') );
DELETE FROM tenant_members WHERE user_id = test.user_id('user4@test.com');

SELECT test.login_as_user('user1@test.com');
SELECT lives_ok(
    $$ insert into user_roles (user_id, role_id) values (test.user_id('user2@test.com'), 1); $$,
    'Can assign roles to people from the same tenant.'
);
-- cannot assign own tenant roles to users from another tenant
SELECT throws_ok(
    $$ insert into user_roles (user_id, role_id) values (test.user_id('admin@test.com'), 1); $$
);
-- cannot assign other tenant roles to users from the current tenant
SELECT throws_ok(
    $$ insert into user_roles (user_id, role_id) values (test.user_id('user4@test.com'), 100); $$
);
-- cannot assign other tenant roles to users from another tenant
SELECT throws_ok(
    $$ insert into user_roles (user_id, role_id) values (test.user_id('admin@test.com'), 100); $$
);

-- TODO: we should test how 'set_claims' works. At the moment it works perfectly within trigger
-- but if I try to log in, `set_claims` fails with missing access to `auth.users`. And that is perfect!
-- I just don't know why?!


SELECT * FROM finish();
ROLLBACK;
