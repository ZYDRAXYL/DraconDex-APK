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
  String get viewerResults => '結果';

  @override
  String get viewerNoFilter => 'フィルタが未設定です — フィルタを開いて表示内容を選んでください。';

  @override
  String get viewerNoResults => 'このフィルタに一致するものはありません';

  @override
  String get viewerUntitled => '無題';

  @override
  String get filterTitle => 'フィルタ';

  @override
  String get filterExplain => 'グループ内のルールはすべて一致する必要があります。いずれか1グループが一致すれば十分です。';

  @override
  String get filterAnd => 'かつ';

  @override
  String get filterOr => 'または';

  @override
  String get filterAddRule => 'ルールを追加';

  @override
  String get filterAddGroup => 'グループを追加';

  @override
  String get filterFieldName => '名前';

  @override
  String get filterFieldHashtag => 'ハッシュタグ';

  @override
  String get filterFieldKind => 'モジュール種別';

  @override
  String get filterFieldChildOf => 'モジュール内';

  @override
  String get filterFieldHandle => 'ハンドル';

  @override
  String get filterOpIs => 'が次と等しい';

  @override
  String get filterOpIsNot => 'が次と等しくない';

  @override
  String get filterOpStartsWith => 'で始まる';

  @override
  String get filterOpEndsWith => 'で終わる';

  @override
  String get filterOpContains => 'を含む';

  @override
  String get filterPickModule => 'モジュールを選択';

  @override
  String get connectorRelations => '関係';

  @override
  String get connectorNoRelations => 'まだ関係がありません';

  @override
  String get connectorAddRelation => '関係を追加';

  @override
  String get connectorFrom => '開始';

  @override
  String get connectorTo => '終了';

  @override
  String get connectorLabel => 'ラベル';

  @override
  String get connectorNodes => 'このレンズ内の項目';

  @override
  String get designerBoard => 'ボード';

  @override
  String get designerNewNode => '新しいノード';

  @override
  String get designerNode => 'ノード';

  @override
  String get designerNodeText => 'テキスト';

  @override
  String get designerEmpty => 'まだノードがありません';

  @override
  String get designerLinkHint => '接続するノードをタップしてください';

  @override
  String get designerLinkCancel => '接続をキャンセル';

  @override
  String get sketcherPages => 'ページ';

  @override
  String get sketcherNewPage => '新しいページ';

  @override
  String get sketcherNoPages => 'まだページがありません';

  @override
  String get sketcherDraw => '描く';

  @override
  String get sketcherPan => '移動';

  @override
  String get sketcherUndo => '最後の線を取り消す';

  @override
  String get sketcherClear => 'ページを消去';

  @override
  String get sketcherClearWarning => 'このページのすべての線を消します。';

  @override
  String get locatorAreas => 'エリア';

  @override
  String get locatorNewArea => '新しいエリア';

  @override
  String get locatorNoAreas => 'まだエリアがありません';

  @override
  String get locatorUntitledArea => '無題のエリア';

  @override
  String get locatorToolDraw => '描く';

  @override
  String get locatorToolMove => '移動';

  @override
  String get locatorUndoPoint => '最後の点を取り消す';

  @override
  String get locatorDrawHint => '地図をタップして点を置きます';

  @override
  String get locatorDeleteAreaWarning => 'エリアとそのすべての点を削除します。';

  @override
  String get wandererPins => 'ピン';

  @override
  String get wandererNoPins => 'まだピンがありません';

  @override
  String get wandererPlacing => '配置中';

  @override
  String get wandererPlaceHint => '地図をタップしてピンを置きます';

  @override
  String get wandererPin => 'ピン';

  @override
  String get wandererLabel => 'ラベル';

  @override
  String get wandererLinkedEvent => 'リンクされたイベント';

  @override
  String get wandererNoLink => 'リンクなし';

  @override
  String get wandererNoEvents => 'この Nexus にはまだタイムラインイベントがありません';

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
  String get viewModeTitle => '表示モード';

  @override
  String get viewModeList => 'リスト';

  @override
  String get viewModeGrid => 'グリッド';

  @override
  String get viewModeCompact => 'コンパクト';

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

  @override
  String get navNest => '巣';

  @override
  String get navSearch => '検索';

  @override
  String get navOpenPages => 'ページ';

  @override
  String get navTools => 'ツール';

  @override
  String get navMore => 'その他';

  @override
  String get openPagesTitle => '開いているページ';

  @override
  String get openPagesEmpty => '開いているページはありません。開いたページは閉じるまでここに残ります。';

  @override
  String get openPagesCloseAll => 'すべて閉じる';

  @override
  String get openPageClose => 'ページを閉じる';

  @override
  String get rowOpen => '開く';

  @override
  String get rowMore => 'その他の操作';

  @override
  String get crumbEmpty => '中身はありません';

  @override
  String get goToTitle => '移動';

  @override
  String get goToHint => '名前、パス、または @handle';

  @override
  String get searchHint => '名前・本文・コマンドを検索';

  @override
  String get searchThings => 'もの';

  @override
  String get searchContent => '内容';

  @override
  String get searchCommands => 'コマンド';

  @override
  String get searchEmpty => '一致するものはありません';

  @override
  String get elementPageSoon => 'この要素は今後のアップデートで専用ページを持ちます。今はモジュールの中で開きます。';

  @override
  String get wikiUnresolved => 'この名前のものはまだありません。この名前で Drafter ページを作りますか？';

  @override
  String get wikiCreateDrafter => '作成';

  @override
  String get btnUndo => '元に戻す';

  @override
  String get pbAddBlock => 'ブロックを追加';

  @override
  String get pbAddHere => 'ここに追加';

  @override
  String get pbAddProperty => 'プロパティを追加';

  @override
  String get pbArrange => 'ページを配置';

  @override
  String get pbArrangeDone => '完了';

  @override
  String get pbArrangeHint => 'ドラッグで並べ替え。列ブロックはまとめて動きます。';

  @override
  String get pbArrangeShared => 'これはこのモジュールの全要素が共有するレイアウトです。このページだけ変えるには先に分離してください。';

  @override
  String get pbBacklinks => 'リンク元';

  @override
  String get pbBlockDeleted => 'ブロックを削除しました';

  @override
  String get pbBorrow => '別モジュールのビュー';

  @override
  String get pbColumn => '列';

  @override
  String get pbColumns => '列';

  @override
  String get pbDivider => '区切り線';

  @override
  String get pbFullScreen => '全画面';

  @override
  String get pbHeading => '見出し';

  @override
  String get pbImage => '画像';

  @override
  String get pbItemBody => '要素';

  @override
  String get pbItemEmpty => 'まだ何も書かれていません。';

  @override
  String get pbNoRelated => 'まだリンクはありません';

  @override
  String get pbNotOnMobile => 'このアプリではまだ使えません';

  @override
  String get pbOnlyOnce => '1ページに1つだけ置けます';

  @override
  String get pbOpenFullScreen => '開く';

  @override
  String get pbOutgoing => 'リンク先';

  @override
  String get pbPropName => '名前';

  @override
  String get pbPropType => '種類';

  @override
  String get pbProperties => 'プロパティ';

  @override
  String get pbRelated => '関連';

  @override
  String get pbRelations => '関係';

  @override
  String get pbRevert => '共有レイアウトに戻す';

  @override
  String get pbSharedLayout => 'このモジュールの全要素ページが共有するレイアウト。';

  @override
  String get pbSourceGone => '表示していたものはありません';

  @override
  String get pbSplit => 'このページに独自のレイアウトを持たせる';

  @override
  String get pbTags => 'タグ';

  @override
  String get pbText => 'テキスト';

  @override
  String get pbTextEmpty => '空のテキスト — タップして書く';

  @override
  String get propTypeCheckbox => 'チェックボックス';

  @override
  String get propTypeDate => '日付';

  @override
  String get propTypeNumber => '数値';

  @override
  String get propTypeText => 'テキスト';

  @override
  String get propTypeTextarea => '長いテキスト';

  @override
  String get propTypeUrl => 'リンク';

  @override
  String get viewTable => '表';

  @override
  String get viewListDetail => 'リスト・詳細';

  @override
  String get viewRelations => '関係';

  @override
  String get viewGrid => 'グリッド';

  @override
  String get viewScene => 'シーン';

  @override
  String get viewGraph => 'グラフ';

  @override
  String get viewCards => 'カード';

  @override
  String get viewBoard => 'ボード';

  @override
  String get viewEdges => 'エッジ';

  @override
  String get viewArea => 'エリア';

  @override
  String get viewMap => '地図';

  @override
  String get viewTimeline => 'タイムライン';

  @override
  String get viewCanvas => 'キャンバス';

  @override
  String get viewPages => 'ページ';

  @override
  String get viewGallery => 'ギャラリー';

  @override
  String get viewExport => '書き出し';

  @override
  String get viewEditor => 'エディタ';

  @override
  String get viewOutline => 'アウトライン';

  @override
  String get viewReading => '読む';

  @override
  String get viewBook => '本';

  @override
  String get viewRoutes => 'ルート';

  @override
  String get viewReader => 'リーダー';

  @override
  String get viewDialogue => '会話';

  @override
  String get viewOneline => '一本線';

  @override
  String get viewDownline => '縦';

  @override
  String get viewCompare => '比較';

  @override
  String get viewCalendar => 'カレンダー';

  @override
  String get viewList => 'リスト';

  @override
  String get viewMatrix => 'マトリクス';

  @override
  String get viewChat => 'チャット';

  @override
  String get viewTranscript => 'ログ';

  @override
  String get clsNoRelations => 'これらの要素間のリンクはまだありません';

  @override
  String get clsTypeText => 'テキスト';

  @override
  String get clsTypeTextarea => '長文';

  @override
  String get clsTypeNumber => '数値';

  @override
  String get clsTypeDate => '日付';

  @override
  String get clsTypeSelect => '選択';

  @override
  String get clsTypeMulti => '複数選択';

  @override
  String get clsTypeCheckbox => 'チェックボックス';

  @override
  String get clsTypeUrl => 'リンク (URL)';

  @override
  String get clsTypeRelation => '関係';

  @override
  String get clsTypeFormula => '数式';

  @override
  String get clsFieldType => 'フィールドの種類';

  @override
  String get clsChoices => '選択肢（1行に1つ）';

  @override
  String get clsFormulaHint => '例: {HP} * 2';

  @override
  String get clsEditField => 'フィールドを編集';

  @override
  String get clsAddLink => 'リンクを追加';

  @override
  String get dateDay => '日';

  @override
  String get dateMonth => '月';

  @override
  String get dateYear => '年';

  @override
  String get dateHour => '時';

  @override
  String get dateMinute => '分';

  @override
  String get btnClear => 'クリア';

  @override
  String get groupBy => 'グループ化';

  @override
  String get groupModule => 'モジュール';

  @override
  String get relDirected => '一方向 (→)';

  @override
  String get exhGroup => 'グループ';

  @override
  String get exhNote => 'メモ';

  @override
  String get exhAddElement => '要素を配置';

  @override
  String get exhAddNote => 'メモを追加';

  @override
  String get exhAddGroup => 'グループを追加';

  @override
  String get exhRemoveFromScene => 'シーンから外す';

  @override
  String get exhSceneEmpty => 'まだ何も配置されていません — 要素を配置するかメモを追加します。';

  @override
  String get auStatusIdea => 'アイデア';

  @override
  String get auStatusDraft => '下書き';

  @override
  String get auStatusRevised => '推敲済み';

  @override
  String get auStatusDone => '完成';

  @override
  String get auSynopsis => 'あらすじ';

  @override
  String get auPov => '視点';

  @override
  String get btnPrevious => '前へ';

  @override
  String get btnNext => '次へ';

  @override
  String get narAddRoute => 'ルートを追加';

  @override
  String get narScript => '台本';

  @override
  String get narPlayTest => 'テストプレイ';

  @override
  String get narRestart => '最初から';

  @override
  String get narShowHidden => '隠れた選択肢を表示';

  @override
  String get narVariables => '変数';

  @override
  String get narNoVariables => 'このNexusにはストーリー変数がありません';

  @override
  String get narPlayEnd => '終わり — 続くルートはありません。';

  @override
  String get narNoOptionOpen => 'この変数では選べる選択肢がありません。';

  @override
  String get narHiddenByCondition => '条件により非表示';

  @override
  String get chrCompareWith => '比較対象';

  @override
  String get chrNoOtherLine => 'このNexusに比較できる他のChroniclerはありません';

  @override
  String get scribeNoMessages => 'まだメッセージはありません';

  @override
  String get wndLocator => '地図 (Locator)';

  @override
  String get wndNoLocator => 'このNexusにはまだLocatorがありません — ピンはそのエリアに置かれます。';

  @override
  String get wndPickLocator => 'これらのピンが置かれるLocatorを選びます。';

  @override
  String get wndNoAreas => 'そのLocatorにはまだエリアがありません';

  @override
  String get wndAddPin => 'ここにピンを置く';

  @override
  String get skExportPng => 'PNGで共有';

  @override
  String get dgPanel => 'コマ';

  @override
  String get dgBalloon => '吹き出し';

  @override
  String get dgLinkFrom => '接続先…';

  @override
  String get dgPanelShows => 'Sketcherのページを表示';

  @override
  String get dgBalloonSpeaker => '話し手';

  @override
  String get dgNumberByPosition => '位置で番号付け';

  @override
  String get dgShowOrder => '読む順を表示';

  @override
  String get divNewTable => '新しい表';

  @override
  String get divDice => 'ダイス';

  @override
  String get divDiceHelp => '空欄 = 重み付き';

  @override
  String get divBadDice => 'ダイス式ではありません';

  @override
  String get divModePick => '1つ選ぶ';

  @override
  String get divModeJoin => 'すべて連結';

  @override
  String get divWeighted => '重み付き';

  @override
  String get divEntryText => 'テキスト';

  @override
  String get divFrom => 'から';

  @override
  String get divTo => 'まで';

  @override
  String get divWeight => '重み';

  @override
  String get divRollsTable => 'ここで別の表を振る';

  @override
  String get divLinkEntity => '何かを指す';

  @override
  String get divUnlink => 'リンクを外す';

  @override
  String get divNoTables => 'まだ表がありません';

  @override
  String get divRoll => '振る';

  @override
  String get divEntries => '項目';

  @override
  String get divNoEntries => 'まだ項目がありません';

  @override
  String get divHistory => '履歴';

  @override
  String get divQuickRoll => '振るだけ: 3d6';

  @override
  String get trashTitle => 'ゴミ箱';

  @override
  String get trashMoved => 'ゴミ箱に移動しました';

  @override
  String get trashEmptyAll => 'ゴミ箱を空にする';

  @override
  String get trashEmptyConfirm => 'ゴミ箱の中身はすべて完全に削除されます。';

  @override
  String get trashNothing => 'ゴミ箱は空です';

  @override
  String get trashNote => '復元したモジュールは中身と関係ごと戻りますが、バージョン履歴は戻りません。';

  @override
  String get trashRestore => '復元';

  @override
  String get trashModules => 'モジュール';

  @override
  String get trashDeleteForever => '完全に削除しますか？以後は復元できません。';

  @override
  String get problemsTitle => '問題';

  @override
  String get problemsLinks => '未解決のリンク';

  @override
  String get problemsEmpty => '空のモジュール';

  @override
  String get problemsRelations => '端が失われた関係';

  @override
  String get problemsNone => '問題は見つかりませんでした';

  @override
  String get assetsTitle => 'アセット';

  @override
  String get assetsFromDevice => 'この端末から追加';

  @override
  String get assetsAddUrl => 'リンク (URL) を追加';

  @override
  String get assetsNotice => 'アセットはこの端末に残ります。同期されるのは名前だけで、ファイルは送られません。';

  @override
  String get assetsNone => 'まだアセットはありません';

  @override
  String get assetsTooBig => 'ブラウザに保存するには大きすぎます';

  @override
  String get pbChooseImage => '画像を選ぶ';

  @override
  String get csvImportTitle => 'CSVを取り込む';

  @override
  String get fromTemplate => 'テンプレートから';

  @override
  String get guideTitle => 'ガイド';

  @override
  String get guideDesc => 'すべての種類を見せる小さな世界';

  @override
  String get guideAdd => 'ガイドを追加';

  @override
  String get mddxImport => 'モジュールファイルを取り込む (.mddx)';

  @override
  String get mddxExport => '.mddxで書き出す';

  @override
  String get mddxNotModule => 'そのファイルはDraconDexのモジュールではありません';

  @override
  String get kindCatStructure => '構造';

  @override
  String get kindCatView => 'ビュー';

  @override
  String get kindCatData => 'データ';

  @override
  String get kindGroupNotes => 'メモ・文書';

  @override
  String get kindGroupData => 'データ・カテゴリ';

  @override
  String get kindGroupMapTime => '地図と時間';

  @override
  String get kindGroupStory => '物語';

  @override
  String get kindGroupDraw => '描画とデザイン';

  @override
  String get nexusStartWith => '開始内容';

  @override
  String get nexusStartEmpty => 'なし — 空のNexus';

  @override
  String get csvPick => 'CSVファイルを選ぶ';

  @override
  String get csvHint => '1行目がフィールド名、1列目が要素名です。';

  @override
  String get csvCreate => 'Classifierを作成';

  @override
  String get csvSkip => '取り込まない';

  @override
  String get csvNameColumn => '名前';

  @override
  String get csvTruncated => '最初の5,000行のみ';

  @override
  String get csvTooLarge => 'ファイルが8MBを超えています';

  @override
  String get csvEmpty => '取り込む行がありません — 見出しと少なくとも1行が必要です';
}
