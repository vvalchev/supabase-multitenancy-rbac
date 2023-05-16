import { Outlet } from 'react-router-dom';

import Nav from './Nav';

function Root() {
  return (
    <>
      <Nav />
      <main className="container">
        <Outlet />
      </main>
    </>
  );
}

export default Root;
