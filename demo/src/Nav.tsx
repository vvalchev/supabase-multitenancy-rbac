import { NavLink } from 'react-router-dom';
import { useUser } from '@supabase/auth-helpers-react';

import { useHasPermission } from './hooks/useHasPermission';

function Nav() {
  const checkActive = ({ isActive }) => (isActive ? 'focus' : '');
  const user = useUser();

  return (
    <nav className="container-fluid">
      <ul>
        <li>
          <strong>RBAC/Multi-Tenancy Demo</strong>
        </li>
      </ul>
      <ul>
        {user?.app_metadata?.tenant_access && (
          <li>
            <NavLink to="/tenants" className={checkActive}>
              Tenants
            </NavLink>
          </li>
        )}
        {useHasPermission('roles.edit') && (
          <li>
            <NavLink to="/roles" className={checkActive}>
              Roles
            </NavLink>
          </li>
        )}
        {user != null && (
          <li>
            <NavLink to="/users" className={checkActive}>
              Users
            </NavLink>
          </li>
        )}
        <li>
          {user == null ? (
            <NavLink to="/login" className={checkActive}>
              Login
            </NavLink>
          ) : (
            <NavLink to="/login" className={checkActive}>
              Logout
            </NavLink>
          )}
        </li>
      </ul>
    </nav>
  );
}

export default Nav;
