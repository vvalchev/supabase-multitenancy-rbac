import { useUser } from '@supabase/auth-helpers-react';

export function useHasPermission(permission) {
  const user = useUser();
  return user?.app_metadata?.perms?.includes(permission);
}
