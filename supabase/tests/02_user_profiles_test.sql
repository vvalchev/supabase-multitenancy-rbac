
BEGIN;
SELECT plan(18);

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
    end;
$$;

CREATE OR REPLACE FUNCTION test.logout() RETURNS void
    LANGUAGE plpgsql
    AS $$
    BEGIN
        PERFORM set_config('request.jwt.claims', null, true);
        SET role postgres;
    END;
$$;

CREATE OR REPLACE FUNCTION test.user_id(user_email text) RETURNS uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$ SELECT id FROM auth.users WHERE email = user_email; $$;


--- -----------------------------------------
--- Insert some test data
--- -----------------------------------------
INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), 'user1@test.com');

SELECT is(raw_app_meta_data, null)
    FROM auth.users WHERE email = 'user1@test.com';

--- -----------------------------------------
--- Test user existence
--- -----------------------------------------
SELECT is(COUNT(*), 1::bigint, 'user exists in auth.users')
    FROM auth.users;

--- -----------------------------------------
--- Test 'handle_new_user' trigger: insert
--- -----------------------------------------
SELECT is(COUNT(*), 1::bigint, 'user exists in user_profile')
    FROM user_profiles;
-- test if default values are set correctly
SELECT ok(created_at IS NOT NULL)
    FROM user_profiles LIMIT 1;
SELECT ok(time_zone = 'Europe/London')
    FROM user_profiles LIMIT 1;
SELECT ok(language = 'en-US')
    FROM user_profiles LIMIT 1;

--- -----------------------------------------
--- Test 'handle_user_profiles_updated' trigger
--- -----------------------------------------
-- test if default fields are set
SELECT ok(raw_user_meta_data -> 'created_at' IS NOT NULL)
    FROM auth.users LIMIT 1;
SELECT ok(raw_user_meta_data -> 'time_zone' = '"Europe/London"')
    FROM auth.users LIMIT 1;
SELECT ok(raw_user_meta_data -> 'language' = '"en-US"')
    FROM auth.users LIMIT 1;
SELECT ok(raw_user_meta_data -> 'first_name' IS NULL)
    FROM auth.users LIMIT 1;

UPDATE user_profiles SET first_name = 'Ivan';
UPDATE user_profiles SET last_name = 'Ivanov';
SELECT ok(raw_user_meta_data -> 'first_name' = '"Ivan"')
    FROM auth.users LIMIT 1;
SELECT ok(raw_user_meta_data -> 'last_name' = '"Ivanov"')
    FROM auth.users LIMIT 1;

UPDATE user_profiles SET first_name = null;
SELECT ok(raw_user_meta_data -> 'first_name' IS NULL)
    FROM auth.users LIMIT 1;

--- -----------------------------------------
--- BEGIN 'profile.editors' permission test
--- -----------------------------------------

--- Add new user, become a member of the tenant and login
INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), 'user2@test.com');
INSERT INTO tenant_members (tenant_id, user_id)  VALUES
    (1, test.user_id('user1@test.com'));
SELECT test.login_as_user('user1@test.com');

--- -----------------------------------------
--- Can update my own profile
--- -----------------------------------------
SELECT lives_ok(
    $$ UPDATE user_profiles SET title = 'Dr.' WHERE id = test.user_id('user1@test.com'); $$
);
--- -----------------------------------------
--- Cannot see profiles from other tenants
--- -----------------------------------------
SELECT is(COUNT(*), 1::bigint, 'cannot see other tenant profiles')
    FROM user_profiles;
--- -----------------------------------------
--- Cannot update another person's profile, if it is not from the same tenant.
--- -----------------------------------------
--- updates don't fail with exception, so you need to check if actual update happened
UPDATE user_profiles SET title = 'Md.' WHERE id = test.user_id('user2@test.com');
SELECT is(title, null, 'Cannot update another person profile, if it is not from the same tenant.')
    FROM user_profiles WHERE id = test.user_id('user2@test.com');

--- -----------------------------------------
--- Cannot update another's profile, even if it is from the same tenant.
--- -----------------------------------------
SELECT test.logout();
INSERT INTO tenant_members (tenant_id, user_id)  VALUES
    (1, test.user_id('user2@test.com'));
SELECT test.login_as_user('user1@test.com');
SELECT is(COUNT(*), 2::bigint, 'can see 2 profiles')
    FROM user_profiles;
UPDATE user_profiles SET title = 'Md.' WHERE id = test.user_id('user2@test.com');
SELECT is(title, null, 'Cannot update another profile, even if it is from the same tenant.')
    FROM user_profiles WHERE id = test.user_id('user2@test.com');
-- SELECT diag((select json_agg(user_profiles) from user_profiles));

--- -----------------------------------------
--- Update as profile editor should succeed.
--- -----------------------------------------
--- Now make me a profile editor
SELECT test.logout();
SELECT add_role_to_user(test.user_id('user1@test.com'), 'profile_editors');
SELECT test.login_as_user('user1@test.com');
--- can update profiles from the same tenant
UPDATE user_profiles SET title = 'Md.' WHERE id = test.user_id('user2@test.com');
SELECT is(title, 'Md.', 'Update as profile editor should succeed.')
    FROM user_profiles WHERE id = test.user_id('user2@test.com');

--- -----------------------------------------
--- Profile editors cannot touch users from another tenant.
--- -----------------------------------------
SELECT test.logout();
DELETE FROM tenant_members WHERE user_id = test.user_id('user2@test.com');
SELECT test.login_as_user('user1@test.com');
--- can not update profiles from another tenant
UPDATE user_profiles SET title = 'Dear' WHERE id = test.user_id('user2@test.com');
SELECT is(title, 'Md.', 'Profile editors cannot touch users from another tenant.')
    FROM user_profiles WHERE id = test.user_id('user2@test.com');


SELECT * FROM finish();
ROLLBACK;
