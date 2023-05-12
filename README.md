# Concepts

* There are tenants
    * All tables must be referring the tenant table and set the appropriate RLS policy
* The security implements a simple RBAC scheme
	* There is an enumerated type `app_permissions`:
         * `all`
         * `tenant_members.assign`
         * `claims.edit`
         * `roles.edit`
         * `roles.assign`
         * `profiles.edit`
	* Permissions are assigned to roles
	* Roles are assigned to groups
* All permission must be scoped - within the current tenant
* There are some special claims copied to `auth.users.raw_app_meta_data`
    * `perms[]` - an array of permissions
    * `tenant_id` - the tenant to which this user is assigned
    * `tenant_access` - controls access if the user can "read" or "write" the tenants table
* All fields from `user_profile` are copied to `auth.users.raw_user_meta_data`
* The public profile `user_profiles` is optional. If you don't need it, removed it from migrations.



# References
* https://www.tangramvision.com/blog/hands-on-with-postgresql-authorization-part-2-row-level-security
* https://github.com/supabase/gotrue/issues/80#issuecomment-1507168133
* https://www.thenile.dev/blog/multi-tenant-rls
* https://blog.mansueli.com/using-custom-claims-testing-rls-with-supabase
* https://github.com/lyqht/awesome-supabase
* https://usebasejump.com/blog/testing-on-supabase-with-pgtap
* https://medium.com/@jimmyruann/row-level-security-custom-permission-base-authorization-with-supabase-91389e6fc48c
* https://dev.to/supabase/supabase-custom-claims-34l2
