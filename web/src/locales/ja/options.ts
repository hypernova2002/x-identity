// utils/options.ts の選択肢のラベル。キーは各選択肢が送る値です。
export default {
  identityProviderKind: {
    google: 'Google',
    apple: 'Apple',
    oidc: 'その他の OpenID Connect プロバイダー',
    saml: 'SAML 2.0 (企業の ID プロバイダー)',
  },
  accountRole: { owner: 'オーナー', admin: '管理者', member: 'メンバー' },
  projectRole: { admin: '管理者', developer: '開発者', viewer: '閲覧者' },
  mfaRequirement: {
    off: 'オフ — コードを求めない',
    optional: '任意 — ユーザーが選ぶ',
    required: '必須 — 全員が MFA を使う',
  },
  passkeys: {
    off: 'オフ',
    optional: '任意: ユーザーはパスキーを追加できる',
    required: '必須: サインインにはパスキーを使う',
  },
  signingAlgorithm: { ES256: 'ES256 (ECDSA P-256)', RS256: 'RS256 (RSA PKCS#1)', PS256: 'PS256 (RSA-PSS)' },
  appClientType: {
    public: 'パブリック — ブラウザーやモバイルアプリ、シークレットなし',
    confidential: 'コンフィデンシャル — シークレットを持つサーバー側アプリ',
  },
  attributeDataType: { string: 'テキスト', number: '数値', boolean: 'はい / いいえ', date: '日付' },
  otpMethod: {
    totp: '認証アプリ (時間ベースのコード)',
    hotp: 'ハードウェアトークン (カウンターベースのコード)',
  },
  userStatus: { active: '有効', disabled: '無効' },
  yesNo: { true: 'はい', false: 'いいえ' },
}
