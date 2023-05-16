const getCountryFlag = countryCode => {
  return countryCode
    ?.toUpperCase()
    .replace(/^([A-Z]{2}-)?([A-Z]{2})$/, '$2')
    .replace(/./g, char => String.fromCodePoint(127397 + char.charCodeAt()));
};

export default getCountryFlag;
