// Titles and descriptions of the project's pages, shown in their headers. Routes name them by key.
export default {
  overview: { title: 'Overview' },
  applications: {
    title: 'Applications',
    description: 'The apps that sign this project\'s end users in: OpenID Connect and API clients, and SAML applications.',
  },
  apis: {
    title: 'APIs',
    description: 'Your own APIs that machine-to-machine apps get access tokens for, and the scopes they define.',
  },
  endUsers: {
    title: 'End users',
    description: 'The people who sign in to this project\'s apps. Console users are managed separately, under Account.',
  },
  endUser: { title: 'End user' },
  groups: {
    title: 'Groups',
    description: 'Sets of end users. Assign apps to groups, and send group names to apps as the groups claim or a SAML attribute.',
  },
  attributes: {
    title: 'Attributes',
    description: 'Extra profile fields for this project\'s end users, optionally required, user-editable or included in ID tokens. Values are checked on sign-up, profile updates and admin changes.',
  },
  authentication: { title: 'Authentication settings' },
  identityProviders: {
    title: 'Identity providers',
    description: 'External systems end users can sign in with: social providers, OpenID Connect providers and companies\' SAML identity providers.',
  },
  identityProvider: { title: 'Identity provider' },
  testSignIn: {
    title: 'Test sign-in',
    description: 'Sign an end user in the way an app would, step through challenges, and inspect the tokens.',
  },
  auditLog: {
    title: 'Audit log',
    description: 'Sign-ins, failures and configuration changes in this project.',
  },
  settings: {
    title: 'General settings',
    description: 'The project\'s name, sign-up and email links.',
  },
  domain: {
    title: 'Custom domain',
    description: 'Serve this project\'s hosted login and endpoints on your own domain, such as login.example.com.',
  },
  members: {
    title: 'Members',
    description: 'Console users who work on this project, and their project roles. End users are under Directory.',
  },
}
