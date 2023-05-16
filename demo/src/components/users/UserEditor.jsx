import languages from 'util/languages';
import getCountryFlag from 'util/getCountryFlag';

function UserEditor({ data, onClose, onSave }) {
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
            {`Update User ${data.id}`}
          </header>

          <input type="hidden" name="id" value={data?.id} />

          <label htmlFor="first_name">First Name</label>
          <input
            type="text"
            name="first_name"
            placeholder="First Name"
            defaultValue={data?.first_name}
          />
          <small>The first name of the user.</small>

          <label htmlFor="last_name">Last Name</label>
          <input
            type="text"
            name="last_name"
            placeholder="Last Name"
            defaultValue={data?.last_name}
          />
          <small>The last name of the user.</small>

          <label htmlFor="display_name">Display Name</label>
          <input
            type="text"
            name="display_name"
            placeholder="Display Name"
            defaultValue={data?.display_name}
          />
          <small>
            Display name. Set this if you don''t want to display you as
            "First_Name Last_Name".
          </small>

          <label htmlFor="salutation">Salutation</label>
          <input
            type="text"
            name="salutation"
            placeholder="Mr. or Mrs."
            defaultValue={data?.salutation}
          />
          <small>How would you like people to refer you.</small>

          <label htmlFor="title">Title</label>
          <input
            type="text"
            name="title"
            placeholder="Dr.|Md.|Eng."
            defaultValue={data?.title}
          />
          <small>Your professional title.</small>

          <label htmlFor="avatar_url">Avatar URL</label>
          <input
            type="text"
            name="avatar_url"
            defaultValue={data?.avatar_url}
          />
          <small>Do you have an avatar image?</small>

          <label htmlFor="website_url">Web Site URL</label>
          <input
            type="text"
            name="website_url"
            defaultValue={data?.website_url}
          />
          <small>Do you have a web site?</small>

          <label htmlFor="phone">Phone</label>
          <input type="text" name="phone" defaultValue={data?.phone} />
          <small>Do you have a web site?</small>

          <label htmlFor="birthday_date">Birthday Date</label>
          <input
            type="date"
            name="birthday_date"
            defaultValue={data?.birthday_date}
          />
          <small>Will you share your birthday?</small>

          <label htmlFor="time_zone">Time Zone</label>
          <select name="time_zone" defaultValue={data?.time_zone}>
            {Intl.supportedValuesOf('timeZone')
              .sort()
              .map(el => (
                <option key={el}>{el}</option>
              ))}
          </select>
          <small>What is your time zone?</small>

          <label htmlFor="language">Language</label>
          <select name="language" defaultValue={data?.language}>
            {languages.map(el => (
              <option key={el.code} value={el.code}>
                {el.name} {getCountryFlag(el.code)}
              </option>
            ))}
          </select>
          <small>What is your language?</small>

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

export default UserEditor;
