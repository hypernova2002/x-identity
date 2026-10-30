// プロジェクトの各ページの見出しと説明。ルートからキーで参照します。
export default {
  overview: { title: '概要' },
  applications: {
    title: 'アプリケーション',
    description: 'このプロジェクトのエンドユーザーをサインインさせるアプリ: OpenID Connect クライアント、API クライアント、SAML アプリケーション。',
  },
  apis: {
    title: 'API',
    description: 'マシン間アプリがアクセストークンを取得する独自の API と、その API が定義するスコープ。',
  },
  endUsers: {
    title: 'エンドユーザー',
    description: 'このプロジェクトのアプリにサインインする人々。コンソールユーザーはアカウントで別に管理します。',
  },
  endUser: { title: 'エンドユーザー' },
  groups: {
    title: 'グループ',
    description: 'エンドユーザーの集まり。グループにアプリを割り当て、グループ名を groups クレームや SAML 属性としてアプリに送れます。',
  },
  attributes: {
    title: '属性',
    description: 'このプロジェクトのエンドユーザーの追加プロフィール項目。必須、ユーザーによる編集可、ID トークンへの追加を選べます。値はサインアップ、プロフィール更新、管理者による変更の際に検証されます。',
  },
  authentication: { title: '認証設定' },
  identityProviders: {
    title: 'ID プロバイダー',
    description: 'エンドユーザーがサインインに使える外部システム: ソーシャルプロバイダー、OpenID Connect プロバイダー、企業の SAML ID プロバイダー。',
  },
  identityProvider: { title: 'ID プロバイダー' },
  testSignIn: {
    title: 'テストサインイン',
    description: 'アプリと同じ方法でエンドユーザーをサインインさせ、チャレンジを順に進めて、トークンを確認します。',
  },
  auditLog: {
    title: '監査ログ',
    description: 'このプロジェクトのサインイン、失敗、設定変更。',
  },
  settings: {
    title: '一般設定',
    description: 'プロジェクトの名前、サインアップ、メールのリンク。',
  },
  domain: {
    title: 'カスタムドメイン',
    description: 'このプロジェクトのホスト型ログインとエンドポイントを、login.example.com のような独自ドメインで提供します。',
  },
  members: {
    title: 'メンバー',
    description: 'このプロジェクトに関わるコンソールユーザーと、そのプロジェクトロール。エンドユーザーはディレクトリにあります。',
  },
}
