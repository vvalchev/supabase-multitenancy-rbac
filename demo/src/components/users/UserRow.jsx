import { useState, useEffect } from 'react';
import { useSupabaseClient, useUser } from '@supabase/auth-helpers-react';
import { useHasPermission } from 'hooks/useHasPermission';
import getCountryFlag from 'util/getCountryFlag';

import UserEditor from './UserEditor';

function UserRow({ element }) {
  const user = useUser();
  const supabase = useSupabaseClient();
  const [data, setData] = useState(element);
  const [dialogVisible, setDialogVisible] = useState(false);

  const flag = getCountryFlag(data.language);

  const handleSave = async updated => {
      console.log('updated', updated);
    const { data, error } = await supabase
      .from('user_profiles')
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
      <td>
        <img src={data.avatar_url} alt={data.id} title={data.id} width="24px" />
      </td>
      <td>{data.display_name || data.first_name || data.last_name}</td>
      <td>{data.salutation}</td>
      <td>{data.title}</td>
      <td>{data.website_url}</td>
      <td>{data.time_zone}</td>
      <td>
        {data.language} {flag}
      </td>
      <td>{data.birthday_date}</td>
      <td>{data.phone}</td>
      <td className="action_buttons">
        {console.log(data, user.id == data?.id)}
        {/*edit action*/}
        {(useHasPermission('profiles.edit') || user.id == data?.id) && (
          <button className="outline" onClick={() => setDialogVisible(true)}>
            Edit
          </button>
        )}
        {dialogVisible && (
          <UserEditor
            data={data}
            onClose={() => setDialogVisible(false)}
            onSave={handleSave}
          />
        )}
      </td>
    </tr>
  );
}

export default UserRow;
