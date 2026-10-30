// The audit log, and the short activity lists on detail pages.
export default {
  columns: { when: 'When', action: 'Action', actor: 'Actor', target: 'Target', app: 'App', ip: 'IP address' },
  filters: {
    from: 'From',
    to: 'To',
    actor: 'Actor ID',
    target: 'Target ID',
    appClient: 'App client ID',
    samlApp: 'SAML app ID',
  },
  caption: 'Audit events',
  searchPlaceholder: 'Search events…',
  searchLabel: 'Action starts with',
  empty: 'No events recorded yet.',
  activity: {
    loadFailed: "We couldn't load the activity. {message}",
    loading: 'Loading activity…',
    seeAll: 'See all {count} in the audit log',
  },
}
