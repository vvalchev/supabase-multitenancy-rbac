import { Auth } from '@supabase/auth-ui-react';
import { ThemeMinimal } from '@supabase/auth-ui-shared';
import { useUser, useSupabaseClient } from '@supabase/auth-helpers-react';

import './LoginPage.css';

function LoginPage() {
  const supabaseClient = useSupabaseClient();
  const user = useUser();

  if (!user)
    return (
      <div
        style={{ maxWidth: '20em', marginLeft: 'auto', marginRight: 'auto' }}
      >
        <Auth
          supabaseClient={supabaseClient}
          redirectTo="http://localhost:3000/"
          appearance={{ extend: false }}
          providers={['google', 'github']}
          socialLayout="horizontal"
        />
      </div>
    );

  return (
    <>
      <button onClick={() => supabaseClient.auth.signOut()} className="outline">
        Sign out
      </button>
      <pre>{JSON.stringify(user, null, 2)}</pre>
    </>
  );
}

export default LoginPage;
