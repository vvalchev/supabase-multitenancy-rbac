
BEGIN;

SELECT plan(19);

--- -----------------------------------------
--- Check table structure
--- -----------------------------------------
SELECT has_table('public', 'tenants', 'tenants table exists');
SELECT columns_are('public', 'tenants', array ['id', 'name', 'notes'],
                   'tenants table should have the correct columns');
SELECT has_table('public', 'user_roles', 'user_roles table exists');
SELECT columns_are('public', 'user_roles', array ['user_id', 'role_id'],
                   'user_roles table should have the correct columns');
SELECT has_table('public', 'tenant_members', 'tenant_members table exists');
SELECT columns_are('public', 'tenant_members', array ['user_id', 'tenant_id'],
                  'tenant_members table should have the correct columns');

SELECT has_table('public', 'roles', 'roles table exists');
SELECT columns_are('public', 'roles', array ['id', 'tenant_id', 'name', 'notes', 'permissions'],
                'roles table should have the correct columns');
SELECT has_view('public', 'user_permissions', 'user_permissions table exists');
SELECT columns_are('public', 'user_permissions', array ['user_id', 'permission'],
                  'user_permissions table should have the correct columns');


--- -----------------------------------------
--- Check if the table is exported outside
--- -----------------------------------------
SAVEPOINT before_anon;
    SET ROLE anon;
    SELECT throws_ok('select * from tenants');
    SELECT throws_ok('insert into tenants (name) values ("hello");');
ROLLBACK TO SAVEPOINT before_anon;

SAVEPOINT before_authenticated;
    SET ROLE authenticated;
    SELECT is_empty('select * from tenants');
    SELECT throws_ok('insert into tenants (name) values ("hello");');
ROLLBACK TO SAVEPOINT before_authenticated;

 
--- -----------------------------------------
--- Test validation
--- -----------------------------------------
SELECT throws_like($$ INSERT INTO tenants (name) VALUES ('xy') $$,
    '%violates check constraint%',
    'Tenant name must not be shorter than 2 symbols.');
SELECT throws_like($$ INSERT INTO tenants (name) VALUES ('abcdefghjkl') $$,
    '%violates check constraint%',
    'Tenant name must not be longer than 10 symbols.');
SELECT throws_like($$ INSERT INTO tenants (name) VALUES ('x0y') $$,
    '%violates check constraint%',
    'Tenant name must not contain numbers.');
SELECT throws_like($$ INSERT INTO tenants (name) VALUES ('x-y') $$,
    '%violates check constraint%',
    'Tenant name must not contain special symbols.');
SELECT throws_like($$ INSERT INTO tenants (name) VALUES ('heLLo') $$,
    '%%violates check constraint%',
    'Tenant name must be all lowercase.');



SELECT * FROM finish();
ROLLBACK;
