// 監査ログと、詳細ページの短いアクティビティ一覧。
export default {
  columns: { when: '日時', action: '操作', actor: '実行者', target: '対象', app: 'アプリ', ip: 'IP アドレス' },
  filters: {
    from: '開始日',
    to: '終了日',
    actor: '実行者 ID',
    target: '対象 ID',
    appClient: 'アプリクライアント ID',
    samlApp: 'SAML アプリ ID',
  },
  caption: '監査イベント',
  searchPlaceholder: 'イベントを検索…',
  searchLabel: '操作の前方一致',
  empty: 'まだ記録されたイベントはありません。',
  activity: {
    loadFailed: 'アクティビティを読み込めませんでした。{message}',
    loading: 'アクティビティを読み込み中…',
    seeAll: '監査ログで {count} 件すべてを見る',
  },
}
