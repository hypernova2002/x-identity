// コンソールとホスト型ページで共通の語句: 操作、状態、補助的なメッセージ。
export default {
  actions: {
    cancel: 'キャンセル',
    save: '保存',
    continue: '続行',
    remove: '削除',
    delete: '削除',
    enable: '有効にする',
    disable: '無効にする',
    tryAgain: '再試行',
  },
  loading: '読み込み中…',
  language: {
    choose: '言語を選択',
    current: '言語: {name}。言語を選択',
  },
  duration: {
    days: '{n} 日',
    hours: '{n} 時間',
    minutes: '{n} 分',
    seconds: '{n} 秒',
    join: '{first} {second}',
  },
  loadingShort: '読み込み中',
  copy: {
    copy: 'コピー',
    copied: 'コピーしました',
    failed: 'コピーできませんでした',
    label: '{what}をコピー',
    copiedStatus: '{what}をコピーしました',
    failedStatus: '{what}をコピーできませんでした。選択して手動でコピーしてください。',
  },
  unsavedChanges: {
    title: '変更を破棄しますか?',
    message: 'このページには保存されていない変更があります。移動すると変更は失われます。',
    confirm: '変更を破棄',
    cancel: '編集を続ける',
  },
  stats: {
    loadFailed: '件数を読み込めませんでした',
  },
  createProject: {
    title: 'プロジェクトを作成',
    description: 'プロジェクトはエンドユーザーの独立したディレクトリで、独自のアプリケーション、設定、メンバーを持ちます。',
    name: 'プロジェクト名',
    nameHint: '例: Production、Staging、Development。',
    submit: 'プロジェクトを作成',
  },
}
