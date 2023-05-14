DROP TYPE IF EXISTS app_permission;
CREATE TYPE app_permission AS ENUM (
    'all', -- get access to everything, scope: tenant
    'tenant_members.assign',
    'roles.edit',
    'roles.assign',
    'profiles.edit'
);

COMMENT ON TYPE app_permission IS 'Enumeration of all available application permissions.';

-- Contains the available tenants.
-- This table could be extended with other fields that can be used as tenant settings.
-- Access: (is_tenant_admin claim)
--    read: tenants.read
--    create, update, delete: tenants.edit
CREATE TABLE tenants (
    id             BIGINT GENERATED ALWAYS AS IDENTITY (INCREMENT BY 50 START 50) PRIMARY KEY,
    name           TEXT UNIQUE NOT NULL CHECK (name ~ '^[a-z]{3,10}$'),
    notes          TEXT
);
COMMENT ON TABLE tenants IS 'Contains all available tenants.';
COMMENT ON COLUMN tenants.id IS 'Tenant unique identifier. This identifier is usually referred by every other table, that contains tenant-specific data.';
COMMENT ON COLUMN tenants.name IS 'Tenant short name. This field can contain only lowercase symbols and should be 3 to 10 symbols in length. It might be used as a subdomain name.';
COMMENT ON COLUMN tenants.notes IS 'Additional notes about the tenant.';


-- Associates users with tenants.
-- Access:
--    read: everyone (from the same tenant)
--    create, update, delete: tenant_members.assign
-- Scope: tenant
CREATE TABLE tenant_members (
    tenant_id      BIGINT REFERENCES tenants ON DELETE CASCADE NOT NULL,
    user_id        UUID REFERENCES auth.users ON DELETE CASCADE NOT NULL,
    UNIQUE         (tenant_id, user_id)
);
COMMENT ON TABLE tenant_members IS 'Association between users and tenants.';
COMMENT ON COLUMN tenant_members.tenant_id IS 'Tenant unique identifier.';
COMMENT ON COLUMN tenant_members.user_id IS 'User unique identifier. References "auth.users" table.';

-- Defines the groups.
-- Each tenant can define their own set of roles.
-- Access:
--    read: everyone
--    create, update, delete: roles.edit
-- Scope: tenant
CREATE TABLE roles (
    id             BIGINT GENERATED ALWAYS AS IDENTITY (INCREMENT BY 50 START 50)  PRIMARY KEY,
    tenant_id      BIGINT REFERENCES tenants ON DELETE CASCADE NOT NULL,
    name           TEXT NOT NULL,
    notes          TEXT,
    permissions    app_permission[],
    UNIQUE         (tenant_id, name)
);
COMMENT ON TABLE roles IS 'Defines tenant-specific roles/groups and their permissions.';
COMMENT ON COLUMN roles.id IS 'Role unique identifier.';
COMMENT ON COLUMN roles.tenant_id IS 'Tenant unique identifier. This role is defined only within specified tenant scope.';
COMMENT ON COLUMN roles.name IS 'Role name. Unique within the specified tenant.';
COMMENT ON COLUMN roles.notes IS 'User-friendly description of this role/group.';
COMMENT ON COLUMN roles.permissions IS 'The permissions associated with this role.';

-- Associates user with Role(s)
-- Access:
--    read: everyone
--    create, update, delete: roles.assign
-- Scope: tenant
CREATE TABLE user_roles (
    user_id        UUID REFERENCES auth.users ON DELETE CASCADE NOT NULL,
    role_id        BIGINT REFERENCES roles ON DELETE CASCADE NOT NULL,
    UNIQUE         (user_id, role_id)
);
COMMENT ON TABLE user_roles IS 'Association between users and roles.';
COMMENT ON COLUMN user_roles.user_id IS 'User unique identifier.';
COMMENT ON COLUMN user_roles.role_id IS 'Role unique identifier.';

-- User permissions view
-- Access:
--    read: everyone
-- Scope: tenant
CREATE OR REPLACE VIEW user_permissions WITH (security_invoker) AS
   SELECT DISTINCT user_roles.user_id, unnest(permissions) as permission
   FROM user_roles
       JOIN roles ON user_roles.role_id = roles.id;
COMMENT ON VIEW user_permissions IS 'A read-only view that exposes user permissions.';
COMMENT ON COLUMN user_permissions.user_id IS 'User unique identifier.';
COMMENT ON COLUMN user_permissions.permission IS 'Application Permission.';
