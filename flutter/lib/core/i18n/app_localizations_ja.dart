// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'DraconDex';

  @override
  String get nexusTitle => 'DraconDex';

  @override
  String get nexusSubtitle => '小説データ管理';

  @override
  String get moduleGlobalTags => 'タグ';

  @override
  String get moduleColors => 'カラー';

  @override
  String get moduleSettings => '設定';

  @override
  String get btnNew => '新規';

  @override
  String get btnSave => '保存';

  @override
  String get btnCancel => 'キャンセル';

  @override
  String get btnDelete => '削除';

  @override
  String get btnEdit => '編集';

  @override
  String get btnClose => '閉じる';

  @override
  String get btnAdd => '追加';

  @override
  String get btnImport => 'DBインポート';

  @override
  String get btnExport => 'DBエクスポート';

  @override
  String get labelName => '名前';

  @override
  String get labelMemo => 'メモ';

  @override
  String get labelColor => 'カラー';

  @override
  String get labelNote => 'ノート';

  @override
  String get labelTags => 'タグ';

  @override
  String get labelSearch => '検索...';

  @override
  String get newHashtag => '新しいタグ';

  @override
  String get noTags => 'タグがありません。';

  @override
  String get noColors => 'カラーパレットが空です。';

  @override
  String get noResults => '結果が見つかりません。';

  @override
  String get confirmDeleteTitle => '削除の確認';

  @override
  String get confirmDeleteMessage => 'この操作は元に戻せません。';

  @override
  String get colorInUse => 'このカラーは使用中のため削除できません。';

  @override
  String get themeLabel => 'テーマ';

  @override
  String get themeMidnight => 'Midnight';

  @override
  String get themeMoonlight => 'Moonlight';

  @override
  String get themeDaylight => 'Daylight';

  @override
  String get languageLabel => '言語';

  @override
  String get uiScaleLabel => 'UIスケール';

  @override
  String get importSuccess => 'データベースをインポートしました。';

  @override
  String get importFailed => 'インポートに失敗しました。ファイルを確認してください。';

  @override
  String get exportSuccess => 'データベースをエクスポートしました。';

  @override
  String get selectColor => 'カラーを選択';

  @override
  String get recentColors => '最近使用';

  @override
  String get version => 'バージョン 2.1.0';

  @override
  String get btnRename => '名前を変更';

  @override
  String get btnPin => 'ピン留め';

  @override
  String get btnUnpin => 'ピン留め解除';

  @override
  String get newNexusTitle => '新しいNexus';

  @override
  String get renameNexusTitle => 'Nexus名を変更';

  @override
  String get newModuleTitle => '新しいモジュール';

  @override
  String get renameModuleTitle => 'モジュール名を変更';

  @override
  String get newModuleTooltip => '新しいモジュール';

  @override
  String get newNexusTooltip => '新しいNexus';

  @override
  String get emptyNexusMessage => 'まだNexusがありません。+をタップして作成しましょう。';

  @override
  String get emptyModuleMessage => '空です。+をタップしてモジュールを追加してください。';

  @override
  String get deleteNexusMessage => '内部のすべてのモジュールも削除されます。この操作は取り消せません。';

  @override
  String get deleteModuleMessage => 'その中に入れ子になっているモジュールもすべて削除されます。この操作は取り消せません。';

  @override
  String get labelKind => '種類';

  @override
  String get kindContentUnavailable => 'このモジュール種類はモバイルではまだ完全に対応していません — 下の共有メモ欄を使用します。';

  @override
  String get notesHint => 'このモジュールのメモ…';

  @override
  String get authorChapters => '章';

  @override
  String get authorNewChapter => '新しい章';

  @override
  String get authorNoChapters => 'まだ章がありません';

  @override
  String get authorContentHint => 'この章を書く…';

  @override
  String get scribeSessions => 'セッション';

  @override
  String get scribeNewSession => '新しいセッション';

  @override
  String get scribeNoSessions => 'まだセッションがありません';

  @override
  String get scribeMessageHint => 'メッセージを入力…';

  @override
  String get scribeSwitchSide => '左右を切り替え';

  @override
  String get chroniclerEvents => 'イベント';

  @override
  String get chroniclerNewEvent => '新しいイベント';

  @override
  String get chroniclerNoEvents => 'まだイベントがありません';

  @override
  String get chroniclerUntitledEvent => '無題のイベント';

  @override
  String get chroniclerStart => '開始';

  @override
  String get chroniclerYear => '年';

  @override
  String get chroniclerMonth => '月';

  @override
  String get chroniclerDay => '日';

  @override
  String get chroniclerHour => '時';

  @override
  String get chroniclerMinute => '分';

  @override
  String get chroniclerHasEnd => '終了日あり';

  @override
  String get chroniclerStory => 'ストーリー';

  @override
  String get classifierFields => 'フィールド';

  @override
  String get classifierNewField => '新しいフィールド';

  @override
  String get classifierNoFields => 'まだフィールドがありません';

  @override
  String get classifierItems => '項目';

  @override
  String get classifierNewItem => '新しい項目';

  @override
  String get classifierNoItems => 'まだ項目がありません';

  @override
  String get classifierDeleteFieldWarning => '各項目が持つこのフィールドの値もすべて削除されます。';

  @override
  String get narratorScenes => 'シーン';

  @override
  String get narratorNewScene => '新しいシーン';

  @override
  String get narratorNoScenes => 'まだシーンがありません';

  @override
  String get narratorScript => 'スクリプト';

  @override
  String get narratorNewLine => '新しい行';

  @override
  String get narratorNoLines => 'まだ行がありません';

  @override
  String get narratorSpeaker => '話者';

  @override
  String get narratorLine => '行';

  @override
  String get narratorRoutes => 'ルート';

  @override
  String get narratorLeadsTo => '次へ';

  @override
  String get narratorNoRoutes => 'まだルートがありません';

  @override
  String get settingsAppearance => '外観';

  @override
  String get settingsData => 'データ';

  @override
  String get settingsAbout => '情報';

  @override
  String get exportDbTitle => 'データベースをエクスポート';

  @override
  String get exportDbSubtitle => '.dbファイルを共有してPCや他の端末にデータを移動します';

  @override
  String get importDbTitle => 'データベースをインポート';

  @override
  String get importDbSubtitle => 'DraconDexの.dbファイルからデータを統合します';

  @override
  String get checkUpdatesTitle => 'アップデートを確認';

  @override
  String get checkUpdatesSubtitle => 'このプロジェクトのGitHub Releasesを確認します — インストール前に必ず確認します';

  @override
  String get upToDateMessage => '最新バージョンです。';

  @override
  String get importingMessage => 'インポート中…';

  @override
  String get importCompleteMessage => 'インポートが完了しました。';

  @override
  String get importFailedMessage => 'インポートに失敗しました。';

  @override
  String get exportFailedMessage => 'エクスポートに失敗しました。';

  @override
  String get saveFailedMessage => '保存に失敗しました。';

  @override
  String get webBackupUnsupportedMessage => 'Web版では利用できません。';

  @override
  String get driveBackupTitle => 'Google Drive バックアップ';

  @override
  String get driveConnectedAs => '接続中:';

  @override
  String get driveNotConnected => '未接続';

  @override
  String get driveConnect => '接続';

  @override
  String get driveDisconnect => '接続解除';

  @override
  String get driveBackupNow => '今すぐバックアップ';

  @override
  String get driveRestoreTitle => 'Google Drive から復元';

  @override
  String get driveRestoreSubtitle => 'Drive のバックアップを現在のデータにマージします';

  @override
  String get driveConnectFailedMessage => '接続に失敗しました。';

  @override
  String get driveBackingUpMessage => 'Google Drive にバックアップ中…';

  @override
  String get driveBackupSuccessMessage => 'バックアップが完了しました。';

  @override
  String get driveBackupFailedMessage => 'バックアップに失敗しました。';

  @override
  String get addColorTitle => '色を追加';

  @override
  String get colorPaletteTitle => 'カラーパレット';

  @override
  String get hashtagsTitle => 'タグ';

  @override
  String get editHashtagTitle => 'タグを編集';

  @override
  String get tagNameLabel => 'タグ名';

  @override
  String get removeColorConfirmTitle => 'この色を削除しますか?';

  @override
  String get deleteHashtagConfirmTitle => 'このタグを削除しますか?';

  @override
  String get builderNavHome => 'ホーム';

  @override
  String get builderNavView => '表示';

  @override
  String get builderNavFolders => 'フォルダビュー';

  @override
  String get viewModeTitle => '表示モード';

  @override
  String get viewModeList => 'リスト';

  @override
  String get viewModeGrid => 'グリッド';

  @override
  String get viewModeCompact => 'コンパクト';

  @override
  String get recentViewsTitle => '最近のビュー';

  @override
  String get recentViewsEmpty => '最近のビューはまだありません';

  @override
  String get recentViewsClear => 'すべて消去';

  @override
  String get builderNexusRootLabel => 'Nexus のルート';

  // --- Supabase project setup (features/settings/supabase_setup_screen.dart) ---

  @override
  String get settingPageSupabase => 'Supabase プロジェクト';

  @override
  String get sbIntro => '自分の Supabase プロジェクトをクラウド同期のサーバーとして使います。プロジェクト URL と publishable キーを貼り付ければ、必要なテーブルの確認と作成は DraconDex が行います。';

  @override
  String get sbUrl => 'プロジェクト URL';

  @override
  String get sbKey => 'Publishable キー';

  @override
  String get sbKeyStored => 'キーは保存済みです — そのままにするなら空欄で。';

  @override
  String get sbCheck => 'プロジェクトを確認';

  @override
  String get sbObjects => '必要なテーブルと関数';

  @override
  String get sbSchemaVersion => 'スキーマのバージョン';

  @override
  String get sbReady => '準備完了 — このプロジェクトにはクラウド同期に必要なものが揃っています。';

  @override
  String get sbNeedSetup => 'セットアップが必要です — 一部のテーブルまたは関数がありません。';

  @override
  String get sbNotChecked => 'まだ確認していません。上の設定を保存してから「プロジェクトを確認」を押してください。';

  @override
  String get sbAutoInstall => '自動セットアップ';

  @override
  String get sbAutoInstallHint => 'publishable キーではテーブルを作成できません。Supabase の個人アクセストークンを貼り付ければ、DraconDex がセットアップ SQL を実行します。';

  @override
  String get sbAccessToken => '個人アクセストークン';

  @override
  String get sbAccessTokenHint => 'この 1 回のリクエストにのみ使用し、保存はしません。';

  @override
  String get sbGetToken => 'トークンを取得';

  @override
  String get sbManualTitle => '手動でセットアップする場合';

  @override
  String get sbManualHint => 'SQL をコピーしてプロジェクトの SQL エディタで実行し、もう一度「プロジェクトを確認」を押してください。';

  @override
  String get sbCopySql => 'SQL をコピー';

  @override
  String get sbOpenSqlEditor => 'SQL エディタを開く';

  @override
  String get sbOpenApiSettings => 'API 設定を開く';

  @override
  String get sbOpenAuthProviders => '認証プロバイダを開く';

  @override
  String get sbGoogleOn => 'このプロジェクトでは Google ログインが有効です。';

  @override
  String get sbGoogleOff => 'Google ログインが無効です — ログイン前に Authentication → Providers で有効にしてください。';

  @override
  String get sbInstalled => 'セットアップ完了';

  @override
  String get sbClear => 'プロジェクト設定を削除';

  @override
  String get sbClearConfirm => '保存された Supabase プロジェクトの設定を削除しますか？';

  @override
  String get sbCleared => 'Supabase の設定を削除しました';

  @override
  String get sbErrNoConfig => '先にプロジェクト URL と publishable キーを入力してください。';

  @override
  String get sbErrInvalidUrl => 'プロジェクト URL が正しくありません — https のみ対応です。';

  @override
  String get sbErrBadKey => 'プロジェクトがこのキーを拒否しました。';

  @override
  String get sbErrUnreachable => 'そのプロジェクトに接続できませんでした。';

  @override
  String get sbErrNeedsManual => 'アクセストークンがありません — 手動の手順をご利用ください。';

  @override
  String get sbErrBadAccessToken => 'そのアクセストークンは拒否されました。';

  @override
  String get sbErrForbidden => 'このトークンにはそのプロジェクトを変更する権限がありません。';

  @override
  String get sbErrNoProjectRef => '自動セットアップには supabase.co のプロジェクト URL が必要です。';

  @override
  String get sbErrRateLimited => 'リクエストが多すぎます — 少し待ってからお試しください。';

  @override
  String get sbErrSqlError => 'セットアップ SQL の実行に失敗しました。';

  @override
  String get sbErrNetwork => 'ネットワークエラー — プロジェクトに接続できませんでした。';

  @override
  String get sbCopied => 'コピーしました';

  @override
  String get sbNotConfigured => 'プロジェクトが未設定です';
  @override
  String get googleAccountTitle => 'Google アカウント';

  @override
  String get googleAccountNotConfigured => 'OAuth クライアントが未設定です';

  @override
  String get googleAccountSetupTitle => 'Google ログインの設定';

  @override
  String get googleClientTypeHintNative => 'Google Cloud Console で Google Drive API を有効にし、種類が「デスクトップ アプリ」の OAuth クライアントを作成して、その情報を下に貼り付けてください。';

  @override
  String get googleClientTypeHintWeb => 'Google Cloud Console で Google Drive API を有効にし、種類が「ウェブ アプリケーション」の OAuth クライアントを作成して、クライアント ID を下に貼り付けてください。';

  @override
  String get googleClientIdLabel => 'クライアント ID';

  @override
  String get googleClientSecretLabel => 'クライアント シークレット';

  @override
  String get googleClientSecretKept => 'クライアント シークレットは保存済みです。空欄のままにすると現在の値を保持します。';

  @override
  String get googleRedirectUriLabel => '承認済みのリダイレクト URI';

  @override
  String get googleRedirectUriHint => 'この URI をそのままクライアントの「承認済みのリダイレクト URI」に、このサイトのアドレスを「承認済みの JavaScript 生成元」に追加してください。';

  @override
  String get googleSessionExpired => 'セッションの有効期限が切れました — 接続し直してください';

  @override
  String get googleErrNoConfig => '先に OAuth クライアントの情報を入力してください。';

  @override
  String get googleErrCancelled => 'ログインはキャンセルされました。';

  @override
  String get googleErrTimeout => 'ログインがタイムアウトしました。';

  @override
  String get googleErrVerify => 'ログインを検証できませんでした。もう一度お試しください。';

  @override
  String get googleErrNetwork => 'Google に接続できませんでした。';

  @override
  String get googleErrAuth => 'Google がログインを拒否しました。';

  @override
  String get googleErrPopupBlocked => 'ログイン用のウィンドウがブロックされました。このサイトのポップアップを許可して、もう一度お試しください。';

  @override
  String get googleErrNotConnected => 'Google アカウントに接続していません。';

  @override
  String get driveRestoreSettingsTitle => 'Drive から設定を復元';

  @override
  String get driveRestoreSettingsSubtitle => 'テーマ・言語・UI サイズをバックアップの内容で置き換えます。';

  @override
  String get driveSettingsRestoredMessage => 'Google Drive から設定を復元しました。';

  @override
  String get driveNoBackupMessage => 'Google Drive にバックアップが見つかりません。';

  @override
  String get driveWebDatabaseNote => 'ブラウザ版では設定のみをバックアップします。データベースはこの端末に残ります。';

  @override
  String get hubNestTitle => 'ネクサスの巣';

  @override
  String get hubPanelShow => 'ハブパネルを表示';

  @override
  String get hubPanelHide => 'ハブパネルを非表示';

  @override
  String get railExpand => 'レールを広げる';

  @override
  String get railCollapse => 'レールを畳む';

  // --- DDX Transfer ---

  @override
  String get transferTitle => '転送';

  @override
  String get transferSubtitle => 'Nexus をまるごと別の端末へ渡します。アカウントも設定も不要 — 送る側がコードを表示し、受け取る側がそれを入力すると、中継されたコピーは受信と同時に削除されます。';

  @override
  String get transferTabSend => '送る';

  @override
  String get transferTabReceive => '受け取る';

  @override
  String get transferNexusLabel => 'Nexus';

  @override
  String get transferPickNexus => '送りたい Nexus を開いてください。';

  @override
  String get transferAllowTyped => 'コード入力での受信を許可する';

  @override
  String get transferAllowTypedHint => 'オンにすると相手はコードと PIN を手入力できますが、待機中サーバーが PIN で封じた鍵を預かります。オフにすると QR コードだけが入口になり、サーバーはファイルを一切読めません。';

  @override
  String get transferCreate => '転送を作成';

  @override
  String get transferCode => '転送コード';

  @override
  String get transferPin => 'PIN';

  @override
  String get transferCopyLink => 'リンクをコピー';

  @override
  String get transferModeTyped => 'QR を読み取るか、コードと PIN を入力してください。待機中はサーバーが PIN で封じた鍵を預かります。';

  @override
  String get transferModeQr => 'QR コードのみ。鍵はサーバーに届かないため、読み取った端末以外はこれを開けません。';

  @override
  String get transferExpiry => '30 分で期限切れになり、受信された瞬間に削除されます。';

  @override
  String get transferWaiting => '相手の端末を待っています…';

  @override
  String get transferClaimed => '相手がコードを確認し、ダウンロード中です…';

  @override
  String get transferDone => '受信完了 — サーバー上のコピーは削除されました。';

  @override
  String get transferExpiredNotice => '受信される前に期限切れになりました。';

  @override
  String get transferVerify => '確認';

  @override
  String get transferFound => '転送が見つかりました';

  @override
  String get transferProject => 'Nexus';

  @override
  String get transferSize => 'サイズ';

  @override
  String get transferCreated => '作成日時';

  @override
  String get transferSource => '送信元';

  @override
  String get transferReceiveAsNew => '新しい Nexus として取り込まれます。既存のものには一切触れません。';

  @override
  String get transferReceiveAction => '受け取る';

  @override
  String get transferReceived => 'Nexus を受け取りました';

  @override
  String get transferErrNetwork => '転送サービスに接続できませんでした。';

  @override
  String get transferErrBadCode => '転送コードまたは PIN が違います。';

  @override
  String get transferErrLocked => 'PIN の誤りが多すぎます。この転送はしばらくロックされます。';

  @override
  String get transferErrExpired => 'この転送は期限切れです。新しいコードをもらってください。';

  @override
  String get transferErrGone => 'この転送はもう存在しません — 受信済みかキャンセルされました。';

  @override
  String get transferErrNotReady => '相手の端末がまだアップロードを終えていません。';

  @override
  String get transferErrTooLarge => 'この Nexus は 1 回の転送の上限を超えています。';

  @override
  String get transferErrBadToken => 'この転送セッションは無効になりました。やり直してください。';

  @override
  String get transferErrBadKey => 'リンクが不完全です — 鍵の部分が欠けているか壊れています。';

  @override
  String get transferErrQrOnly => '送信側は QR コードのみを許可しています。入力ではなく読み取ってください。';

  @override
  String get transferErrBadPayload => '受け取ったファイルを読み込めませんでした。';

  @override
  String get transferErrServer => '転送サービスで問題が発生しました。';

  @override
  String get transferSending => '送信中…';

  @override
  String get transferCopied => 'リンクをコピーしました';

  @override
  String get transferCancel => 'キャンセル';

  @override
  String get transferPasteLink => 'または転送リンクを貼り付け';

  @override
  String get transferPasteLinkHint => 'リンクには鍵が含まれているため、送信側が QR のみを許可していても使えます。';
}
