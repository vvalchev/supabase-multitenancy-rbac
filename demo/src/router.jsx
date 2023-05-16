import { createBrowserRouter, Navigate } from 'react-router-dom';
import { useUser } from '@supabase/auth-helpers-react';

import Root from './Root';
import LoginPage from './components/login/LoginPage';
import UsersPage from './components/users/UsersPage';
import RolesPage from './components/roles/RolesPage';
import TenantsPage from './components/tenants/TenantsPage';

import { useHasPermission } from './hooks/useHasPermission';

function Protected({ permission, children }) {
  const user = useUser();
  if (null == user) {
    return <Navigate to="/login" />;
  }
  if (permission != null && !useHasPermission(permission)) {
    return <Navigate to="/login" />;
  }
  return children;
}

export const router = createBrowserRouter([
  {
    path: '/',
    element: <Root />,
    children: [
      {
        path: 'tenants/',
        element: <TenantsPage />,
      },
      {
        path: 'roles/',
        element: (
          <Protected>
            <RolesPage />
          </Protected>
        ),
      },
      {
        path: 'users/',
        element: (
          <Protected>
            <UsersPage />
          </Protected>
        ),
      },
      {
        path: 'login/',
        element: <LoginPage />,
      },
    ],
  },
]);
