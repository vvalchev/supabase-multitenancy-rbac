import { useState, useEffect } from 'react';
import { useSupabaseClient, useUser } from '@supabase/auth-helpers-react';
import { useHasPermission } from 'hooks/useHasPermission';

import TenantEditor from './TenantEditor';
import TenantRow from './TenantRow';

function TenantsPage() {
  const user = useUser();
  const supabase = useSupabaseClient();
  const [data, setData] = useState([]);
  const [dialogVisible, setDialogVisible] = useState(false);

  const fetchData = async () => {
    const { data, error } = await supabase.from('tenants').select('*');
    if (error) {
      console.log('Error fetching data', error);
    } else {
      setData(data);
    }
  };

  const handleNewTenant = async updated => {
    const { data, error } = await supabase.from('tenants').insert(updated);
    if (error) {
      console.log('Error inserting data', error);
    } else {
      fetchData();
      setDialogVisible(false);
    }
  };

  const handleDelete = async id => {
    const { data, error } = await supabase
      .from('tenants')
      .delete()
      .eq('id', id);
    if (error) {
      console.log('Error deleting data', error);
    } else {
      setData(data => data.filter(role => role.id != id));
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  return (
    <>
      <table>
        <thead>
          <tr>
            <td>Name</td>
            <td>Notes</td>
            <td>Email Template</td>
            <td>&nbsp;</td>
            {/*edit action*/}
          </tr>
        </thead>
        <tbody>
          {data.length > 0 &&
            data.map(element => (
              <TenantRow
                key={element.id}
                element={element}
                onDelete={handleDelete}
              />
            ))}
        </tbody>
      </table>
      {'write' == user?.app_metadata?.tenant_access && (
        <button onClick={() => setDialogVisible(true)}>New Tenant</button>
      )}
      {dialogVisible && (
        <TenantEditor
          onClose={() => setDialogVisible(false)}
          onSave={handleNewTenant}
        />
      )}
    </>
  );
}

export default TenantsPage;
