import { useState } from 'react';
import { useSupabaseClient, useUser } from '@supabase/auth-helpers-react';

function TenantRow({ element, onDelete }) {
  const user = useUser();
  const supabase = useSupabaseClient();
  const [data, setData] = useState(element);
  const [dialogVisible, setDialogVisible] = useState(false);

  const handleSave = async updated => {
    const { data, error } = await supabase
      .from('tenants')
      .update(updated)
      .eq('id', element.id);
    if (error) {
      console.log('Error updating data', error);
    } else {
      setData(updated);
      setDialogVisible(false);
    }
  };

  return (
    <tr>
      <td>{data.name}</td>
      <td>{data.notes}</td>
      <td>{data.members_email_regex}</td>
      <td className="action_buttons">
        {/*edit action*/}
        {'write' == user?.app_metadata?.tenant_access && (
          <>
            <button className="outline" onClick={() => setDialogVisible(true)}>
              Edit
            </button>
            <button
              className="outline secondary"
              onClick={() => onDelete(element.id)}
            >
              Delete
            </button>
          </>
        )}
        {dialogVisible && (
          <TenantEditor
            data={data}
            onClose={() => setDialogVisible(false)}
            onSave={handleSave}
          />
        )}
      </td>
    </tr>
  );
}

export default TenantRow;
