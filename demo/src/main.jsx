import React from 'react';
import ReactDOM from 'react-dom/client';
import { RouterProvider } from 'react-router-dom';
import { router } from './router';
import './index.scss';

import { SessionContextProvider } from '@supabase/auth-helpers-react';
import { createBrowserSupabaseClient } from '@supabase/auth-helpers-shared';

const supabaseClient = createBrowserSupabaseClient({
  supabaseUrl: import.meta.env.VITE_SUPABASE_URL,
  supabaseKey: import.meta.env.VITE_SUPABASE_ANON_KEY,
});

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <SessionContextProvider supabaseClient={supabaseClient}>
      <RouterProvider router={router} />
    </SessionContextProvider>
  </React.StrictMode>
);
