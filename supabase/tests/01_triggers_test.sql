
BEGIN;
SELECT plan(12);

--- -----------------------------------------
--- Insert some test data
--- -----------------------------------------
INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), 'user1@test.com');

SELECT is(raw_app_meta_data, null)
    FROM auth.users WHERE email = 'user1@test.com';

--- add user to tenant and set member
INSERT INTO tenant_members  (tenant_id, user_id) VALUES
    (1, (select id from auth.users where email = 'user1@test.com'));
SELECT add_role_to_user((select id from auth.users where email = 'user1@test.com'), 'permission_admins');


--- -----------------------------------------
--- Test user existence
--- -----------------------------------------
SELECT is(COUNT(*), 1::bigint, 'user exists in auth.users')
    FROM auth.users;

--- -----------------------------------------
--- Test 'on_tenant_members_change' trigger: insert
--- -----------------------------------------
SELECT is(raw_app_meta_data -> 'tenant_id',  '1')
    FROM auth.users WHERE email = 'user1@test.com';

--- -----------------------------------------
--- Test 'on_user_role_change' trigger: insert
--- -----------------------------------------
SELECT isnt(raw_app_meta_data, null)
    FROM auth.users WHERE email = 'user1@test.com';
-- To compare JSON arrays use: A contains B and B contains A 
SELECT ok(raw_app_meta_data -> 'perms' <@ jsonb_build_array('claims.edit','roles.edit', 'roles.assign'))
    FROM auth.users WHERE email = 'user1@test.com';
SELECT ok(raw_app_meta_data -> 'perms' @> jsonb_build_array('claims.edit','roles.edit', 'roles.assign'))
    FROM auth.users WHERE email = 'user1@test.com';

--- -----------------------------------------
--- Test 'on_user_role_change' trigger: update
--- -----------------------------------------
SELECT add_role_to_user((select id from auth.users where email = 'user1@test.com'), 'profile_editors');
SELECT ok(raw_app_meta_data -> 'perms' @> jsonb_build_array('profiles.edit'))
    FROM auth.users WHERE email = 'user1@test.com';

--- -----------------------------------------
--- Test 'on_role_change' trigger: update
--- -----------------------------------------
UPDATE roles SET permissions =  ARRAY['all'::app_permission] WHERE name = 'profile_editors';
SELECT ok(NOT raw_app_meta_data -> 'perms' @> jsonb_build_array('profiles.edit'))
    FROM auth.users WHERE email = 'user1@test.com';
UPDATE roles SET permissions =  ARRAY['profiles.edit'::app_permission] WHERE name = 'profile_editors';
SELECT ok(raw_app_meta_data -> 'perms' @> jsonb_build_array('profiles.edit'))
    FROM auth.users WHERE email = 'user1@test.com';

--- -----------------------------------------
--- Test 'on_role_change' trigger: delete
--- -----------------------------------------
DELETE FROM roles WHERE name = 'profile_editors';
SELECT ok(NOT raw_app_meta_data -> 'perms' @> jsonb_build_array('profiles.edit'))
    FROM auth.users WHERE email = 'user1@test.com';

--- -----------------------------------------
--- Test 'on_user_role_change' trigger: delete
--- -----------------------------------------
DELETE FROM user_roles WHERE user_id = (select id from auth.users where email = 'user1@test.com');
SELECT is(raw_app_meta_data -> 'perms',  null)
    FROM auth.users WHERE email = 'user1@test.com';

--- -----------------------------------------
--- Test 'on_tenant_members_change' trigger: delete
--- -----------------------------------------
DELETE FROM tenant_members WHERE user_id = (select id from auth.users where email = 'user1@test.com');
SELECT is(raw_app_meta_data -> 'tenant_id',  null)
    FROM auth.users WHERE email = 'user1@test.com';


SELECT * FROM finish();
ROLLBACK;
