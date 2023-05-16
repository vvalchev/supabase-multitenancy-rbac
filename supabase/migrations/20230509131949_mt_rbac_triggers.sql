

--- ----------------------------------------------------------------------------
--- Add tenant_id claim
--- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION handle_tenant_members_change() RETURNS TRIGGER
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public'
    AS $$
    BEGIN
        RAISE NOTICE 'Tenant Membership: (%) -> (%)', OLD, NEW;
        IF (TG_OP = 'DELETE') THEN
            PERFORM delete_claim(OLD.user_id, 'tenant_id');
        ELSE
            PERFORM set_claim(NEW.user_id, 'tenant_id', NEW.tenant_id::text::jsonb);
        END IF;
        return null;
    END;
$$;

DROP TRIGGER IF EXISTS on_tenant_members_change ON tenant_members;
CREATE TRIGGER on_tenant_members_change
    AFTER INSERT OR UPDATE OR DELETE ON tenant_members
    FOR EACH ROW EXECUTE FUNCTION handle_tenant_members_change();


--- ----------------------------------------------------------------------------
--- Update user claims, when the user is assigned a new role
--- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION handle_user_role_change() RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $$
    DECLARE
        id uuid := coalesce(new.user_id, old.user_id);
        perms jsonb := null;
    BEGIN
        SELECT jsonb_agg(permission) FROM user_permissions WHERE user_id = id INTO perms;
        RAISE NOTICE 'User Permissions: (%) has (%)', id, perms;
        IF perms IS NULL THEN
            PERFORM delete_claim(id, 'perms');
        ELSE
            PERFORM set_claim(id, 'perms', perms);
        END IF;
        return null;
    END;
$$;

DROP TRIGGER IF EXISTS on_user_role_change ON user_roles;
CREATE TRIGGER on_user_role_change
    AFTER INSERT OR UPDATE OR DELETE ON user_roles
    FOR EACH ROW EXECUTE FUNCTION handle_user_role_change();

--- ----------------------------------------------------------------------------
--- Update user claims, when role permissions are updated
--- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION handle_role_change() RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $$
    DECLARE
        target_role_id bigint := coalesce(new.id, old.id);
        f record;
        perms jsonb := null;
    BEGIN
        FOR F IN SELECT DISTINCT user_id FROM user_roles WHERE role_id = target_role_id
        LOOP
            SELECT jsonb_agg(permission) FROM user_permissions WHERE user_id = f.user_id INTO perms;
            RAISE NOTICE 'User Permissions [RC]: (%) has (%)', f.user_id, perms;
            IF perms IS NULL THEN
                PERFORM delete_claim(f.user_id, 'perms');
            ELSE
                PERFORM set_claim(f.user_id, 'perms', perms);
            END IF;
        END LOOP;
        return null;
    END;
$$;

DROP TRIGGER IF EXISTS on_role_change ON roles;
CREATE TRIGGER on_role_change
    AFTER UPDATE OR DELETE ON roles
    FOR EACH ROW EXECUTE FUNCTION handle_role_change();

--- ----------------------------------------------------------------------------
--- Automatically assign the user to a tenant, based on email rule
--- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION handle_auto_assign_user() RETURNS TRIGGER
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public'
    AS $$
    DECLARE
        T record;
    BEGIN
        -- loop through all tenants with auto-assign feature set
        FOR T IN SELECT DISTINCT id, members_email_regex FROM tenants WHERE members_email_regex IS NOT NULL
        LOOP
            -- use case-insensitive match for emails
            IF NEW.email ~* T.members_email_regex THEN
              INSERT INTO tenant_members (user_id, tenant_id) VALUES (NEW.id, T.id);
              EXIT;
            END IF;
        END LOOP;
        return null;
    END;
$$;


CREATE TRIGGER on_new_user1
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_auto_assign_user();
