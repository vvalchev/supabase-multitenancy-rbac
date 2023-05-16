import { useState } from 'react';

function RoleEditor({ data, onClose, onSave }) {
  const handleSubmit = (e, form) => {
    e.preventDefault();
    const val = Object.fromEntries(
      Array.from(e.target.elements)
        .filter(e => e.value)
        .map(e => {
          if (e.multiple) {
            return [e.name, Array.from(e.selectedOptions).map(e => e.value)];
          }
          return [e.name, e.value];
        })
    );
    onSave(val);
  };

  return (
    <form onSubmit={handleSubmit}>
      <dialog open>
        <article>
          <header>
            <a
              href="#close"
              aria-label="Close"
              className="close"
              onClick={onClose}
            ></a>
            {data ? 'Update Role "' + data.name + '"' : 'Create New Role'}
          </header>

          <label htmlFor="name">Name</label>
          <input
            type="text"
            name="name"
            placeholder="Name"
            required
            defaultValue={data?.name}
          />
          <small>User-friendly name of the role.</small>

          <label htmlFor="notes">Description</label>
          <input
            type="text"
            name="notes"
            placeholder="Notes"
            defaultValue={data?.notes}
          />
          <small>Description of the role.</small>

          <label htmlFor="permissions">Permissions</label>
          <select name="permissions" multiple defaultValue={data?.permissions}>
            <option value="all">All</option>
            <option value="tenant_members.assign">
              Can assign members to the tenant.
            </option>
            <option value="roles.edit">Can edit roles.</option>
            <option value="roles.assign">Can assign roles to users.</option>
            <option value="profiles.edit">
              Can edit other member profiles.
            </option>
          </select>
          <small>The permissions assigned to that role.</small>

          <footer className="action_buttons">
            <button className="secondary" onClick={onClose}>
              Cancel
            </button>
            <button type="submit">Confirm</button>
          </footer>
        </article>
      </dialog>
    </form>
  );
}

export default RoleEditor;
