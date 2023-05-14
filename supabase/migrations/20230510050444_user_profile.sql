
--- ----------------------------------------------------------------------------
--- 'time_zone' domain
--- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION is_timezone( tz TEXT ) RETURNS boolean
    LANGUAGE plpgsql STABLE
    AS $$
    BEGIN
        PERFORM now() AT TIME ZONE tz;
        RETURN TRUE;
    EXCEPTION WHEN invalid_parameter_value THEN
        RETURN FALSE;
    END;
$$;
CREATE DOMAIN time_zone AS TEXT CHECK ( is_timezone( value ) );


-- Create a table for user public profiles
-- Access:
--    read: everyone
--    create, update, delete: /self/, profiles.edit
CREATE TABLE user_profiles (
    id             UUID REFERENCES auth.users ON DELETE CASCADE NOT NULL PRIMARY KEY,
    --- TODO: https://x-team.com/blog/automatic-timestamps-with-postgresql/
    created_at     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    first_name     TEXT,
    last_name      TEXT,
    display_name   TEXT,
    salutation     TEXT, -- 'Mr, Ms'
    title          TEXT, -- 'Medical Doctor'
    avatar_url     TEXT,
    website_url    TEXT,
    time_zone      time_zone NOT NULL DEFAULT 'Europe/London', -- 'Europe/London'
    language       TEXT NOT NULL DEFAULT 'en-US' CHECK (language ~ '^[a-z]{2}(-[A-Z]{2})?$'),
    birthday_date  TIMESTAMP WITH TIME ZONE,
    phone          TEXT
);
COMMENT ON TABLE user_profiles IS 'Public user profiles, editable by the users. These profiles are automatically created when the user is registered in the system. Alternatively, you can use "user_metadata" in "auth.users"';

--- ----------------------------------------------------------------------------
--- Automatically change 'updated_at' when the profile is modified.
--- ----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS update_profile_timestamp ON user_profiles;
CREATE TRIGGER update_profile_timestamp
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

--- ----------------------------------------------------------------------------
--- Update user claims (raw_user_meta_data) when the profile is modified.
--- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION handle_user_profiles_updated() RETURNS TRIGGER
    lANGUAGE PLPGSQL SECURITY DEFINER SET search_path = public
    AS $$
    BEGIN
        UPDATE auth.users SET raw_user_meta_data = (jsonb_strip_nulls(row_to_json(NEW)::jsonb))
            WHERE id = NEW.id;
        RETURN NEW;
    END;
$$;

CREATE TRIGGER on_user_profiles_updated
  AFTER INSERT OR UPDATE ON user_profiles
  FOR EACH ROW EXECUTE FUNCTION handle_user_profiles_updated();

--- ----------------------------------------------------------------------------
--- Creates a new public profile for each registered user.
--- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION handle_new_user() RETURNS TRIGGER
  lANGUAGE PLPGSQL SECURITY DEFINER SET search_path = public
  AS $$
  BEGIN
      RAISE NOTICE 'New User Profile Created: (%)', NEW.id;
      INSERT INTO user_profiles (id, avatar_url) VALUES
          (NEW.id, 'https://www.gravatar.com/avatar/' || md5(new.email) || '?d=mp');
          RETURN NEW;
  END;
$$;

CREATE TRIGGER on_new_users
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

--- -----------------------------------------
--- Enable RLS
--- -----------------------------------------
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow individual read access on 'user_profiles'"
    ON user_profiles
    FOR SELECT
    USING      ( auth.uid() = id );
CREATE POLICY "Allow individual update access on 'user_profiles'"
    ON user_profiles
    FOR UPDATE
    USING      ( auth.uid() = id )
    WITH CHECK ( auth.uid() = id );
CREATE POLICY "Allow (scoped) read access on 'user_profiles' to all users from the same tenant."
    ON user_profiles
    FOR SELECT
    USING ( do_users_share_tenant(id, auth.uid()) );
CREATE POLICY "Allow (scoped) update access to 'user_profiles' to users with permissions 'profiles.edit'."
    ON user_profiles
    FOR UPDATE
    USING      ( do_users_share_tenant(id, auth.uid()) AND jwt_has_permission('profiles.edit') )
    WITH CHECK ( do_users_share_tenant(id, auth.uid()) AND jwt_has_permission('profiles.edit') );
