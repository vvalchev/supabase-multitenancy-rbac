function TenantEditor({ data, onClose, onSave }) {
  const handleSubmit = (e, form) => {
    e.preventDefault();
    const val = Object.fromEntries(
      Array.from(e.target.elements)
        .filter(e => e.value)
        .map(e => [e.name, e.value])
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
            {data ? 'Update Tenant "' + data.name + '"' : 'Create New Tenant'}
          </header>

          <label htmlFor="name">Name</label>
          <input
            type="text"
            name="name"
            placeholder="Name"
            required
            defaultValue={data?.name}
          />
          <small>
            The tenant name should be lowercase, with no special characters, and
            3-to-10 symbols.
          </small>

          <label htmlFor="notes">Notes</label>
          <input
            type="text"
            name="notes"
            placeholder="Notes"
            defaultValue={data?.notes}
          />
          <small>Optional tenant notes.</small>

          <label htmlFor="members_email_regex">Members</label>
          <input
            type="text"
            name="members_email_regex"
            placeholder="Members Email Regex"
            defaultValue={data?.members_email_regex}
          />
          <small>
            You can type in a regex here. If a new user, is registered with that
            email it will be automatically assigned to the tenant.
          </small>

          <footer>
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

export default TenantEditor;
