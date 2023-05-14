
--- -----------------------------------------
--- JWT functions
--- -----------------------------------------

CREATE OR REPLACE FUNCTION jwt_is_expired() RETURNS BOOLEAN
    LANGUAGE sql STABLE
    AS $$
        SELECT extract(epoch FROM now()) > coalesce(auth.jwt()->>'exp', '0')::numeric;
$$;


CREATE OR REPLACE FUNCTION jwt_get_claim(claim TEXT) RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$
        SELECT coalesce(
            nullif(current_setting('request.jwt.claims', true), '')::jsonb -> 'app_metadata' -> claim, null
        )
$$;

CREATE OR REPLACE FUNCTION jwt_tenant_id() RETURNS BIGINT
    LANGUAGE sql STABLE
    AS $$
        SELECT coalesce(jwt_get_claim('tenant_id')::bigint, -1);
$$;

CREATE OR REPLACE FUNCTION jwt_has_permission(perm TEXT, strict BOOLEAN DEFAULT FALSE) RETURNS BOOLEAN
    LANGUAGE plpgsql
    AS $$
    DECLARE
        perms jsonb;
    BEGIN
        IF current_user != 'authenticated' THEN
            -- not a user session, probably being called from a trigger or something
            RETURN true;
        END IF;

        IF jwt_is_expired()
            THEN RAISE EXCEPTION 'invalid_jwt' USING HINT = 'JWT is expired or missing';
        END IF;

        SELECT coalesce(jwt_get_claim('perms'), '[]'::jsonb) INTO perms;
        
        IF strict THEN
            RETURN (jsonb_build_array(perm) <@ perms);
        ELSE
            RETURN ('"all"'::jsonb <@ perms OR jsonb_build_array(perm) <@ perms);
        END IF;
    END;
$$;


--- -----------------------------------------
--- Claim Management functions
--- based on https://github.com/supabase-community/supabase-custom-claims
--- -----------------------------------------
CREATE OR REPLACE FUNCTION is_claims_admin() RETURNS "bool"
  LANGUAGE sql STABLE
  AS $$
      -- We don't want users to change claims. Our roles and permissions are assigned through tables and triggers.
      SELECT (session_user != 'authenticator');
$$;

CREATE OR REPLACE FUNCTION get_claims(uid uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
    AS $$
    DECLARE
        retval jsonb;
    BEGIN
        IF NOT is_claims_admin() THEN
            RAISE EXCEPTION 'access denied' USING HINT = 'The current user is not allowed to set permission.';
        ELSE
            SELECT raw_app_meta_data
                FROM auth.users INTO retval
                WHERE id = uid::uuid;
            RETURN retval;
        END IF;
    END;
$$;

CREATE OR REPLACE FUNCTION get_claim(uid uuid, claim TEXT) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
    AS $$
    DECLARE
        retval jsonb;
    BEGIN
        IF NOT is_claims_admin() THEN
            RAISE EXCEPTION 'access denied' USING HINT = 'The current user is not allowed to set permission.';
        ELSE
            SELECT coalesce(raw_app_meta_data->claim, null)
                FROM auth.users INTO retval
                WHERE id = uid::uuid;
            RETURN retval;
        END IF;
    END;
$$;

CREATE OR REPLACE FUNCTION set_claim(uid uuid, claim TEXT, value jsonb) RETURNS BOOLEAN
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
    AS $$
    BEGIN
        IF NOT is_claims_admin() THEN
            RAISE EXCEPTION 'access denied' USING HINT = 'The current user is not allowed to set permission.';
        ELSE
            UPDATE auth.users
                SET raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || json_build_object(claim, value)::jsonb
                WHERE id = uid;
            RETURN true;
        END IF;
    END;
$$;

CREATE OR REPLACE FUNCTION delete_claim(uid uuid, claim TEXT) RETURNS BOOLEAN
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
    AS $$
    BEGIN
        IF NOT is_claims_admin() THEN
            RAISE EXCEPTION 'access denied' USING HINT = 'The current user is not allowed to set permission.';
        ELSE
            UPDATE auth.users
                SET raw_app_meta_data = raw_app_meta_data - claim
                WHERE id = uid;
            RETURN true;
        END IF;
    END;
$$;


--- -----------------------------------------
--- Helpers
--- -----------------------------------------

-- Based on https://x-team.com/blog/automatic-timestamps-with-postgresql/
-- Usage:
-- CREATE TRIGGER update_profile_timestamp
--     BEFORE UPDATE ON roles
--     FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
CREATE OR REPLACE FUNCTION trigger_set_updated_at() RETURNS TRIGGER 
    LANGUAGE plpgsql
    AS $$
    BEGIN
        NEW.updated_at = timezone('utc'::text, now());
        RETURN NEW;
    END;
$$;

CREATE OR REPLACE FUNCTION do_users_share_tenant(id1 uuid, id2 uuid) RETURNS BOOLEAN 
    LANGUAGE sql SECURITY DEFINER SET search_path = public
    AS $$
    SELECT
        EXISTS(
            SELECT 1
            FROM
              tenant_members tm1,
              tenant_members tm2
            WHERE
              tm1.tenant_id = tm2.tenant_id
              AND tm1.user_id = id1
              AND tm2.user_id = id2
          )
$$;

CREATE OR REPLACE FUNCTION is_role_in_tenant(role_id BIGINT, tenant_id BIGINT) RETURNS BOOLEAN
    LANGUAGE sql SECURITY DEFINER SET search_path = public
    AS $$
    SELECT EXISTS (
        SELECT 1 
            FROM roles
            WHERE 
                roles.id = role_id 
                AND roles.tenant_id = tenant_id
        )
$$;

-- returns 1 is user is added or null on failure
CREATE OR REPLACE FUNCTION add_role_to_user(uid uuid, role_name TEXT) RETURNS INT
    LANGUAGE sql
    AS $$
    INSERT INTO user_roles(user_id, role_id)
        SELECT DISTINCT user_id, R.id AS role_id FROM tenant_members TM
            JOIN roles R ON user_id = uid
            WHERE TM.tenant_id = R.tenant_id AND R.name = role_name RETURNING 1;
$$;
