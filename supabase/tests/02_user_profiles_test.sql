
BEGIN;
SELECT plan(13);

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
--- TODO: Test 'profile_editors' permission
--- -----------------------------------------

SELECT * FROM finish();
ROLLBACK;
