import { useState, useEffect } from 'react';
import { useSupabaseClient } from '@supabase/auth-helpers-react';
import { useHasPermission } from 'hooks/useHasPermission';

import UserRow from './UserRow';

function UsersPage() {
  const supabase = useSupabaseClient();
  const [data, setData] = useState([]);

  const fetchData = async () => {
    const { data, error } = await supabase.from('user_profiles').select('*');
    if (error) {
      console.log('Error fetching data', error);
    } else {
      setData(data);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  return (
    <table>
      <thead>
        <tr>
          <td>ID</td>
          <td>Name</td>
          <td>Salutation</td>
          <td>Title</td>
          <td>Web Site</td>
          <td>Time Zone</td>
          <td>Language</td>
          <td>Birthday</td>
          <td>Phone</td>
          <td>&nbsp;</td>
          {/*edit action*/}
        </tr>
      </thead>
      <tbody>
        {data &&
          data.map(element => <UserRow key={element.id} element={element} />)}
      </tbody>
    </table>
  );
}

export default UsersPage;
