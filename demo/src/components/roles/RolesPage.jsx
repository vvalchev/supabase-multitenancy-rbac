import { useState, useEffect } from 'react';
import { useSupabaseClient, useUser } from '@supabase/auth-helpers-react';
import { useHasPermission } from 'hooks/useHasPermission';

import RoleEditor from './RoleEditor';
import RoleRow from './RoleRow';

function RolesPage() {
  const user = useUser();
  const supabase = useSupabaseClient();
  const [data, setData] = useState([]);
  const [dialogVisible, setDialogVisible] = useState(false);

  const fetchData = async () => {
    const { data, error } = await supabase.from('roles').select('*');
    if (error) {
      console.log('Error fetching data', error);
    } else {
      setData(data);
    }
  };

  const handleNewRole = async updated => {
    updated.tenant_id = user.app_metadata.tenant_id;
    const { data, error } = await supabase.from('roles').insert(updated);
    if (error) {
      console.log('Error inserting data', error);
    } else {
      fetchData();
      setDialogVisible(false);
    }
  };

  const handleDelete = async id => {
    const { data, error } = await supabase.from('roles').delete().eq('id', id);
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
            <td>Description</td>
            <td>Permissions</td>
            <td>&nbsp;</td>
            {/*edit action*/}
          </tr>
        </thead>
        <tbody>
          {data &&
            data.map(element => (
              <RoleRow
                key={element.id}
                element={element}
                onDelete={handleDelete}
              />
            ))}
        </tbody>
      </table>
      {useHasPermission('roles.edit') && (
        <button onClick={() => setDialogVisible(true)}>New Role</button>
      )}
      {dialogVisible && (
        <RoleEditor
          onClose={() => setDialogVisible(false)}
          onSave={handleNewRole}
        />
      )}
    </>
  );
}

export default RolesPage;
