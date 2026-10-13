(() => {
  const key = 'versin_optional_cookie_consent_v1';
  const banner = document.getElementById('versin-cookie-banner');
  if (!banner) return;
  let current = null;
  try { current = localStorage.getItem(key); } catch (_) { /* Private browsing: preference may not persist. */ }
  const show = () => { banner.hidden = false; };
  const close = (value) => {
    try { localStorage.setItem(key, value); } catch (_) { /* Keep session functional. */ }
    banner.hidden = true;
    document.dispatchEvent(new CustomEvent('versin:cookie-preference', {detail:{optional:value === 'accepted'}}));
  };
  document.getElementById('versin-cookie-accept')?.addEventListener('click', () => close('accepted'));
  document.getElementById('versin-cookie-reject')?.addEventListener('click', () => close('rejected'));
  document.querySelectorAll('[data-cookie-settings]')?.forEach((link) => link.addEventListener('click', (event) => { event.preventDefault(); show(); }));
  if (current !== 'accepted' && current !== 'rejected') show();
  // No nonessential cookies/trackers are initialized by this script.
})();
