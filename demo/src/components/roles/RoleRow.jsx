import { useState, useEffect } from 'react';
import { useSupabaseClient } from '@supabase/auth-helpers-react';
import { useHasPermission } from 'hooks/useHasPermission';

import RoleEditor from './RoleEditor';

function RoleRow({ element, onDelete }) {
  const supabase = useSupabaseClient();
  const [data, setData] = useState(element);
  const [dialogVisible, setDialogVisible] = useState(false);

  const handleSave = async updated => {
    const { data, error } = await supabase
      .from('roles')
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
      <td>{data.permissions && data.permissions.join(', ')}</td>
      <td className="action_buttons">
        {/*edit action*/}
        {useHasPermission('roles.edit') && (
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
          <RoleEditor
            data={data}
            onClose={() => setDialogVisible(false)}
            onSave={handleSave}
          />
        )}
      </td>
    </tr>
  );
}

export default RoleRow;
