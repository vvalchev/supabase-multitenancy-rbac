
--- -----------------------------------------
--- Secure defaults
--- -----------------------------------------
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON tables FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON functions FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON sequences FROM anon;
-- revoke current privileges 
REVOKE SELECT   ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE USAGE    ON ALL SEQUENCES IN SCHEMA public FROM anon;
REVOKE EXECUTE  ON ALL FUNCTIONS IN SCHEMA public FROM anon;

--- -----------------------------------------
--- Enable RLS
--- -----------------------------------------
ALTER TABLE tenants         ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_members  ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles           ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles      ENABLE ROW LEVEL SECURITY;

--- -----------------------------------------
--- tenants table policy
--- -----------------------------------------
CREATE POLICY "Allow read access on 'tenants' to operators with claim 'tenant_access' set ."
    ON tenants
    FOR SELECT
    USING ( jwt_get_claim('tenant_access') IS NOT NULL );

CREATE POLICY "Allow insert, update, delete access on 'tenants' to operators to users with claim 'tenant_access' set to 'write'."
    ON tenants
    FOR ALL
    USING      ( jwt_get_claim('tenant_access')::text = '"write"' )  -- for delete
    WITH CHECK ( jwt_get_claim('tenant_access')::text = '"write"' ); -- for insert/update


--- -----------------------------------------
--- tenant_members table policy
--- -----------------------------------------
CREATE POLICY "Allow (scoped) read access on 'tenant_members' to all users from the same tenant."
    ON tenant_members
    FOR SELECT
    USING ( jwt_get_claim('tenant_id')::bigint = tenant_id);

CREATE POLICY "Allow (scoped) insert, update, delete access to 'tenant_members' to users with permissions 'tenant_members.assign'."
    ON tenant_members
    FOR ALL
    USING      (     jwt_get_claim('tenant_id')::bigint = tenant_id
                 AND jwt_has_permission('tenant_members.assign') )  -- for delete
    WITH CHECK (     jwt_get_claim('tenant_id')::bigint = tenant_id
                 AND jwt_has_permission('tenant_members.assign') ); -- for insert/update

--- -----------------------------------------
--- roles table policy
--- -----------------------------------------
CREATE POLICY "Allow (scoped) read access on 'roles' to all users from the same tenant."
    ON roles
    FOR SELECT
    USING ( jwt_get_claim('tenant_id')::bigint = tenant_id);

CREATE POLICY "Allow (scoped) insert, update, delete access to 'roles' to users with permissions 'roles.edit'."
    ON roles
    FOR ALL
    USING      ( jwt_get_claim('tenant_id')::bigint = tenant_id
                 AND jwt_has_permission('roles.edit') )  -- for delete
    WITH CHECK ( jwt_get_claim('tenant_id')::bigint = tenant_id
                 AND jwt_has_permission('roles.edit') ); -- for insert/update

--- -----------------------------------------
--- user_roles table policy
--- -----------------------------------------
CREATE OR REPLACE FUNCTION check_role_in_current_tenant(role_id BIGINT)  RETURNS BOOLEAN
    LANGUAGE plpgsql
    AS $$
    BEGIN
        RETURN EXISTS (
            SELECT 1 FROM roles
                WHERE roles.id = role_id AND roles.tenant_id = jwt_get_claim('tenant_id')::bigint
        );
    END
$$;

CREATE POLICY "Allow (scoped) read access on 'user_roles' to all users from the same tenant."
    ON user_roles
    FOR SELECT
    USING ( is_role_in_tenant(role_id, jwt_tenant_id()) );

CREATE POLICY "Allow (scoped) insert, update, delete access to 'user_roles' to users with permissions 'roles.assign'."
    ON user_roles
    FOR ALL
    USING      ( is_role_in_tenant(role_id, jwt_tenant_id()) AND jwt_has_permission('roles.assign') )  -- for delete
    WITH CHECK ( is_role_in_tenant(role_id, jwt_tenant_id()) AND jwt_has_permission('roles.assign') ); -- for insert/update

