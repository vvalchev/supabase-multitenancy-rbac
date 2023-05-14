INSERT INTO tenants (id, name, notes) 
    OVERRIDING SYSTEM VALUE 
    VALUES
        (1, 'system', 'This is the system tenant.');

INSERT INTO roles (id, tenant_id, name, permissions, notes) 
    OVERRIDING SYSTEM VALUE
    VALUES
        (1, 1, 'admins',
            ARRAY['all'::app_permission],
            'People in this group have access to the whole system, but cannot create/update tenants.'
        ),
        -- (2, 1, 'system_admins',
        --     ARRAY['all'::app_permission, 'tenants.read'::app_permission, 'tenants.edit'::app_permission],
        --     'People in this group have access to the whole system and can create/update tenants.'
        -- ),
        (3, 1, 'permission_admins',
            ARRAY['roles.edit'::app_permission, 'roles.assign'::app_permission],
            'People in this group can create/edit roles and assign them to users.'
        ),
        (4, 1, 'profile_editors',
            ARRAY['profiles.edit'::app_permission],
            'People in this group can edit the public profile of other persons.'
        );
