// Words and messages shared across the console and hosted pages: actions, states and helpers.
export default {
  actions: {
    cancel: 'Cancel',
    save: 'Save',
    continue: 'Continue',
    remove: 'Remove',
    delete: 'Delete',
    enable: 'Enable',
    disable: 'Disable',
    tryAgain: 'Try again',
  },
  loading: 'Loading…',
  language: {
    choose: 'Choose a language',
    current: 'Language: {name}. Choose a language',
  },
  duration: {
    days: '{n} day | {n} days',
    hours: '{n} hour | {n} hours',
    minutes: '{n} minute | {n} minutes',
    seconds: '{n} seconds | {n} second | {n} seconds',
    join: '{first} {second}',
  },
  loadingShort: 'Loading',
  copy: {
    copy: 'Copy',
    copied: 'Copied',
    failed: 'Copy failed',
    label: 'Copy {what}',
    copiedStatus: '{what} copied',
    failedStatus: "Couldn't copy {what}; select it and copy it yourself.",
  },
  unsavedChanges: {
    title: 'Discard changes?',
    message: "You have changes on this page that haven't been saved. If you leave, they'll be lost.",
    confirm: 'Discard changes',
    cancel: 'Keep editing',
  },
  stats: {
    loadFailed: "We couldn't load these counts",
  },
  createProject: {
    title: 'Create project',
    description: 'A project is a separate directory of end users, with its own applications, settings and members.',
    name: 'Project name',
    nameHint: 'For example Production, Staging or Development.',
    submit: 'Create project',
  },
}
