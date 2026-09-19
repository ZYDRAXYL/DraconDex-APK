// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'DraconDex';

  @override
  String get nexusTitle => 'DraconDex';

  @override
  String get nexusSubtitle => 'Novel Data Management';

  @override
  String get moduleGlobalTags => 'Tags';

  @override
  String get moduleColors => 'Colors';

  @override
  String get moduleSettings => 'Settings';

  @override
  String get btnNew => 'New';

  @override
  String get btnSave => 'Save';

  @override
  String get btnCancel => 'Cancel';

  @override
  String get btnDelete => 'Delete';

  @override
  String get btnEdit => 'Edit';

  @override
  String get btnClose => 'Close';

  @override
  String get btnAdd => 'Add';

  @override
  String get btnImport => 'Import DB';

  @override
  String get btnExport => 'Export DB';

  @override
  String get labelName => 'Name';

  @override
  String get labelMemo => 'Memo';

  @override
  String get labelColor => 'Color';

  @override
  String get labelNote => 'Note';

  @override
  String get labelTags => 'Tags';

  @override
  String get labelSearch => 'Search...';

  @override
  String get newHashtag => 'New Tag';

  @override
  String get noTags => 'No tags yet.';

  @override
  String get noColors => 'No colors in the palette.';

  @override
  String get noResults => 'No results found.';

  @override
  String get confirmDeleteTitle => 'Confirm Delete';

  @override
  String get confirmDeleteMessage => 'This action cannot be undone.';

  @override
  String get colorInUse => 'Color is in use and cannot be deleted.';

  @override
  String get themeLabel => 'Theme';

  @override
  String get themeMidnight => 'Midnight';

  @override
  String get themeMoonlight => 'Moonlight';

  @override
  String get themeDaylight => 'Daylight';

  @override
  String get languageLabel => 'Language';

  @override
  String get uiScaleLabel => 'UI Scale';

  @override
  String get importSuccess => 'Database imported successfully.';

  @override
  String get importFailed => 'Import failed. Please check the file.';

  @override
  String get exportSuccess => 'Database exported.';

  @override
  String get selectColor => 'Select Color';

  @override
  String get recentColors => 'Recent';

  @override
  String get version => 'Version 2.1.0';

  @override
  String get btnRename => 'Rename';

  @override
  String get btnPin => 'Pin';

  @override
  String get btnUnpin => 'Unpin';

  @override
  String get newNexusTitle => 'New Nexus';

  @override
  String get renameNexusTitle => 'Rename Nexus';

  @override
  String get newModuleTitle => 'New Module';

  @override
  String get renameModuleTitle => 'Rename Module';

  @override
  String get newModuleTooltip => 'New Module';

  @override
  String get newNexusTooltip => 'New Nexus';

  @override
  String get emptyNexusMessage => 'No Nexus yet. Tap + to create one.';

  @override
  String get emptyModuleMessage => 'Empty. Tap + to add a module.';

  @override
  String get deleteNexusMessage => 'This deletes every module inside it. This action cannot be undone.';

  @override
  String get deleteModuleMessage => 'This deletes every module nested inside it too. This action cannot be undone.';

  @override
  String get labelKind => 'Kind';

  @override
  String get kindContentUnavailable => 'This module kind isn\'t fully supported on mobile yet — using the shared notes field below.';

  @override
  String get notesHint => 'Notes for this module…';

  @override
  String get authorChapters => 'Chapters';

  @override
  String get authorNewChapter => 'New chapter';

  @override
  String get authorNoChapters => 'No chapters yet';

  @override
  String get authorContentHint => 'Write this chapter…';

  @override
  String get scribeSessions => 'Sessions';

  @override
  String get scribeNewSession => 'New session';

  @override
  String get scribeNoSessions => 'No sessions yet';

  @override
  String get scribeMessageHint => 'Write a message…';

  @override
  String get scribeSwitchSide => 'Switch side';

  @override
  String get chroniclerEvents => 'Events';

  @override
  String get chroniclerNewEvent => 'New event';

  @override
  String get chroniclerNoEvents => 'No events yet';

  @override
  String get chroniclerUntitledEvent => 'Untitled event';

  @override
  String get chroniclerStart => 'Start';

  @override
  String get chroniclerYear => 'Year';

  @override
  String get chroniclerMonth => 'Month';

  @override
  String get chroniclerDay => 'Day';

  @override
  String get chroniclerHour => 'Hour';

  @override
  String get chroniclerMinute => 'Minute';

  @override
  String get chroniclerHasEnd => 'Has an end date';

  @override
  String get chroniclerStory => 'Story';

  @override
  String get classifierFields => 'Fields';

  @override
  String get classifierNewField => 'New field';

  @override
  String get classifierNoFields => 'No fields yet';

  @override
  String get classifierItems => 'Items';

  @override
  String get classifierNewItem => 'New item';

  @override
  String get classifierNoItems => 'No items yet';

  @override
  String get classifierDeleteFieldWarning => 'This also deletes the value every item holds for it.';

  @override
  String get narratorScenes => 'Scenes';

  @override
  String get narratorNewScene => 'New scene';

  @override
  String get narratorNoScenes => 'No scenes yet';

  @override
  String get narratorScript => 'Script';

  @override
  String get narratorNewLine => 'New line';

  @override
  String get narratorNoLines => 'No lines yet';

  @override
  String get narratorSpeaker => 'Speaker';

  @override
  String get narratorLine => 'Line';

  @override
  String get narratorRoutes => 'Routes';

  @override
  String get narratorLeadsTo => 'Leads to';

  @override
  String get narratorNoRoutes => 'No routes yet';

  @override
  String get viewerResults => 'Results';

  @override
  String get viewerNoFilter => 'No filter set yet — open the filter to choose what this lens shows.';

  @override
  String get viewerNoResults => 'Nothing matches this filter';

  @override
  String get viewerUntitled => 'Untitled';

  @override
  String get filterTitle => 'Filter';

  @override
  String get filterExplain => 'Rules inside a group must all match. Any one group matching is enough.';

  @override
  String get filterAnd => 'and';

  @override
  String get filterOr => 'or';

  @override
  String get filterAddRule => 'Add rule';

  @override
  String get filterAddGroup => 'Add group';

  @override
  String get filterFieldName => 'Name';

  @override
  String get filterFieldHashtag => 'Hashtag';

  @override
  String get filterFieldKind => 'Module kind';

  @override
  String get filterFieldChildOf => 'Inside module';

  @override
  String get filterOpIs => 'is';

  @override
  String get filterOpIsNot => 'is not';

  @override
  String get filterOpStartsWith => 'starts with';

  @override
  String get filterOpEndsWith => 'ends with';

  @override
  String get filterOpContains => 'contains';

  @override
  String get filterPickModule => 'Pick a module';

  @override
  String get connectorRelations => 'Relations';

  @override
  String get connectorNoRelations => 'No relations yet';

  @override
  String get connectorAddRelation => 'Add relation';

  @override
  String get connectorFrom => 'From';

  @override
  String get connectorTo => 'To';

  @override
  String get connectorLabel => 'Label';

  @override
  String get connectorNodes => 'Items in this lens';

  @override
  String get designerBoard => 'Board';

  @override
  String get designerNewNode => 'New node';

  @override
  String get designerNode => 'Node';

  @override
  String get designerNodeText => 'Text';

  @override
  String get designerEmpty => 'No nodes yet';

  @override
  String get designerLinkHint => 'Tap another node to connect it';

  @override
  String get designerLinkCancel => 'Cancel link';

  @override
  String get sketcherPages => 'Pages';

  @override
  String get sketcherNewPage => 'New page';

  @override
  String get sketcherNoPages => 'No pages yet';

  @override
  String get sketcherDraw => 'Draw';

  @override
  String get sketcherPan => 'Pan';

  @override
  String get sketcherUndo => 'Undo last stroke';

  @override
  String get sketcherClear => 'Clear page';

  @override
  String get sketcherClearWarning => 'This erases every stroke on this page.';

  @override
  String get locatorAreas => 'Areas';

  @override
  String get locatorNewArea => 'New area';

  @override
  String get locatorNoAreas => 'No areas yet';

  @override
  String get locatorUntitledArea => 'Untitled area';

  @override
  String get locatorToolDraw => 'Draw';

  @override
  String get locatorToolMove => 'Move';

  @override
  String get locatorUndoPoint => 'Undo last point';

  @override
  String get locatorDrawHint => 'Tap the map to place points';

  @override
  String get locatorDeleteAreaWarning => 'This deletes the area and all its points.';

  @override
  String get wandererPins => 'Pins';

  @override
  String get wandererNoPins => 'No pins yet';

  @override
  String get wandererPlacing => 'Placing';

  @override
  String get wandererPlaceHint => 'Tap the map to place a pin';

  @override
  String get wandererPin => 'Pin';

  @override
  String get wandererLabel => 'Label';

  @override
  String get wandererLinkedEvent => 'Linked event';

  @override
  String get wandererNoLink => 'No link';

  @override
  String get wandererNoEvents => 'No timeline events in this Nexus yet';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsAbout => 'About';

  @override
  String get exportDbTitle => 'Export Database';

  @override
  String get exportDbSubtitle => 'Share the .db file to transfer data to PC or another device';

  @override
  String get importDbTitle => 'Import Database';

  @override
  String get importDbSubtitle => 'Merge data from a DraconDex .db file';

  @override
  String get checkUpdatesTitle => 'Check for Updates';

  @override
  String get checkUpdatesSubtitle => 'Looks at this project\'s GitHub Releases — always asks before installing';

  @override
  String get upToDateMessage => 'You\'re on the latest version.';

  @override
  String get importingMessage => 'Importing…';

  @override
  String get importCompleteMessage => 'Import complete.';

  @override
  String get importFailedMessage => 'Import failed.';

  @override
  String get exportFailedMessage => 'Export failed.';

  @override
  String get saveFailedMessage => 'Save failed.';

  @override
  String get webBackupUnsupportedMessage => 'Not available in the web version.';

  @override
  String get driveBackupTitle => 'Google Drive Backup';

  @override
  String get driveConnectedAs => 'Connected:';

  @override
  String get driveNotConnected => 'Not connected';

  @override
  String get driveConnect => 'Connect';

  @override
  String get driveDisconnect => 'Disconnect';

  @override
  String get driveBackupNow => 'Backup Now';

  @override
  String get driveRestoreTitle => 'Restore from Google Drive';

  @override
  String get driveRestoreSubtitle => 'Merges the Drive backup into your current data';

  @override
  String get driveConnectFailedMessage => 'Connect failed.';

  @override
  String get driveBackingUpMessage => 'Backing up to Google Drive…';

  @override
  String get driveBackupSuccessMessage => 'Backup complete.';

  @override
  String get driveBackupFailedMessage => 'Backup failed.';

  @override
  String get addColorTitle => 'Add Color';

  @override
  String get colorPaletteTitle => 'Color Palette';

  @override
  String get hashtagsTitle => 'Hashtags';

  @override
  String get editHashtagTitle => 'Edit Hashtag';

  @override
  String get tagNameLabel => 'Tag Name';

  @override
  String get removeColorConfirmTitle => 'Remove color?';

  @override
  String get deleteHashtagConfirmTitle => 'Delete hashtag?';

  @override
  String get builderNavHome => 'Home';

  @override
  String get builderNavView => 'View';

  @override
  String get builderNavFolders => 'Folder Views';

  @override
  String get viewModeTitle => 'View mode';

  @override
  String get viewModeList => 'List';

  @override
  String get viewModeGrid => 'Grid';

  @override
  String get viewModeCompact => 'Compact';

  @override
  String get recentViewsTitle => 'Recent Views';

  @override
  String get recentViewsEmpty => 'No recent views yet';

  @override
  String get recentViewsClear => 'Clear all';

  @override
  String get builderNexusRootLabel => 'Nexus root';

  // --- Supabase project setup (features/settings/supabase_setup_screen.dart) ---

  @override
  String get settingPageSupabase => 'Supabase Project';

  @override
  String get sbIntro => 'Use your own Supabase project as the Cloud Sync backend. Paste the project URL and publishable key, then let DraconDex check and install the tables it needs.';

  @override
  String get sbUrl => 'Project URL';

  @override
  String get sbKey => 'Publishable key';

  @override
  String get sbKeyStored => 'A key is already saved — leave this empty to keep it.';

  @override
  String get sbCheck => 'Check project';

  @override
  String get sbObjects => 'Required tables & functions';

  @override
  String get sbSchemaVersion => 'Schema version';

  @override
  String get sbReady => 'Ready — this project has everything Cloud Sync needs.';

  @override
  String get sbNeedSetup => 'Setup needed — some tables or functions are missing.';

  @override
  String get sbNotChecked => 'Not checked yet. Save the settings above, then press Check project.';

  @override
  String get sbAutoInstall => 'Auto setup';

  @override
  String get sbAutoInstallHint => 'A publishable key cannot create tables. Paste a Supabase personal access token and DraconDex will run the setup SQL for you.';

  @override
  String get sbAccessToken => 'Personal access token';

  @override
  String get sbAccessTokenHint => 'Used for this one request only — never saved.';

  @override
  String get sbGetToken => 'Get a token';

  @override
  String get sbManualTitle => 'Or set it up by hand';

  @override
  String get sbManualHint => 'Copy the SQL, run it in your project SQL editor, then press Check project again.';

  @override
  String get sbCopySql => 'Copy SQL';

  @override
  String get sbOpenSqlEditor => 'Open SQL Editor';

  @override
  String get sbOpenApiSettings => 'Open API settings';

  @override
  String get sbOpenAuthProviders => 'Open Auth providers';

  @override
  String get sbGoogleOn => 'Google sign-in is enabled on this project.';

  @override
  String get sbGoogleOff => 'Google sign-in is off — turn it on under Authentication → Providers before signing in.';

  @override
  String get sbInstalled => 'Setup complete';

  @override
  String get sbClear => 'Remove project';

  @override
  String get sbClearConfirm => 'Remove the saved Supabase project settings?';

  @override
  String get sbCleared => 'Supabase settings removed';

  @override
  String get sbErrNoConfig => 'Enter the project URL and publishable key first.';

  @override
  String get sbErrInvalidUrl => 'That project URL is not valid — https only.';

  @override
  String get sbErrBadKey => 'The project rejected this key.';

  @override
  String get sbErrUnreachable => 'Could not reach that project.';

  @override
  String get sbErrNeedsManual => 'No access token — use the manual steps instead.';

  @override
  String get sbErrBadAccessToken => 'That access token was rejected.';

  @override
  String get sbErrForbidden => 'This token is not allowed to change that project.';

  @override
  String get sbErrNoProjectRef => 'Automatic setup needs a supabase.co project URL.';

  @override
  String get sbErrRateLimited => 'Too many requests — try again in a moment.';

  @override
  String get sbErrSqlError => 'The setup SQL failed to run.';

  @override
  String get sbErrNetwork => 'Network error — could not reach the project.';

  @override
  String get sbCopied => 'Copied';

  @override
  String get sbNotConfigured => 'No project set up yet';
  @override
  String get googleAccountTitle => 'Google account';

  @override
  String get googleAccountNotConfigured => 'No OAuth client set up yet';

  @override
  String get googleAccountSetupTitle => 'Google sign-in setup';

  @override
  String get googleClientTypeHintNative => 'In Google Cloud Console, enable the Google Drive API and create an OAuth client of type "Desktop app", then paste its details below.';

  @override
  String get googleClientTypeHintWeb => 'In Google Cloud Console, enable the Google Drive API and create an OAuth client of type "Web application", then paste its client ID below.';

  @override
  String get googleClientIdLabel => 'Client ID';

  @override
  String get googleClientSecretLabel => 'Client secret';

  @override
  String get googleClientSecretKept => 'A client secret is already saved. Leave this blank to keep it.';

  @override
  String get googleRedirectUriLabel => 'Authorized redirect URI';

  @override
  String get googleRedirectUriHint => 'Add this exact address to the client\'s authorized redirect URIs, and this site\'s address to its authorized JavaScript origins.';

  @override
  String get googleSessionExpired => 'Session expired — connect again';

  @override
  String get googleErrNoConfig => 'Enter your OAuth client details first.';

  @override
  String get googleErrCancelled => 'Sign-in was cancelled.';

  @override
  String get googleErrTimeout => 'Sign-in timed out.';

  @override
  String get googleErrVerify => 'The sign-in could not be verified. Please try again.';

  @override
  String get googleErrNetwork => 'Could not reach Google.';

  @override
  String get googleErrAuth => 'Google refused the sign-in.';

  @override
  String get googleErrPopupBlocked => 'The sign-in window was blocked. Allow pop-ups for this site and try again.';

  @override
  String get googleErrNotConnected => 'Not connected to a Google account.';

  @override
  String get driveRestoreSettingsTitle => 'Restore settings from Drive';

  @override
  String get driveRestoreSettingsSubtitle => 'Replaces theme, language and UI size with the backed-up ones.';

  @override
  String get driveSettingsRestoredMessage => 'Settings restored from Google Drive.';

  @override
  String get driveNoBackupMessage => 'No backup found on Google Drive.';

  @override
  String get driveWebDatabaseNote => 'In the browser build only the settings are backed up — the database stays on this device.';

  @override
  String get hubNestTitle => 'Nexus Nest';

  @override
  String get hubPanelShow => 'Show hub panel';

  @override
  String get hubPanelHide => 'Hide hub panel';

  @override
  String get railExpand => 'Expand rail';

  @override
  String get railCollapse => 'Collapse rail';

  // --- DDX Transfer ---

  @override
  String get transferTitle => 'Transfer';

  @override
  String get transferSubtitle => 'Hand a whole Nexus to another device. No account and no setup — the sending device shows a code, the receiving one takes it, and the copy in between is deleted the moment it arrives.';

  @override
  String get transferTabSend => 'Send';

  @override
  String get transferTabReceive => 'Receive';

  @override
  String get transferNexusLabel => 'Nexus';

  @override
  String get transferPickNexus => 'Open a Nexus to send it.';

  @override
  String get transferAllowTyped => 'Allow receiving by typed code';

  @override
  String get transferAllowTypedHint => 'On, the other device can type the code and PIN, and the service holds the key sealed under that PIN while it waits. Off, the QR code is the only way in and the service cannot read the file at all.';

  @override
  String get transferCreate => 'Create transfer';

  @override
  String get transferCode => 'Transfer code';

  @override
  String get transferPin => 'PIN';

  @override
  String get transferCopyLink => 'Copy link';

  @override
  String get transferModeTyped => 'Scan the QR, or type the code and PIN. While this is waiting, the service holds the key sealed under the PIN.';

  @override
  String get transferModeQr => 'QR code only. The key never reaches the service, so nobody but the scanning device can open this.';

  @override
  String get transferExpiry => 'This expires in 30 minutes, and is deleted the moment it is received.';

  @override
  String get transferWaiting => 'Waiting for the other device…';

  @override
  String get transferClaimed => 'The other device has verified the code and is downloading…';

  @override
  String get transferDone => 'Received. The copy on the service has been deleted.';

  @override
  String get transferExpiredNotice => 'This expired before it was received.';

  @override
  String get transferVerify => 'Verify';

  @override
  String get transferFound => 'Transfer found';

  @override
  String get transferProject => 'Nexus';

  @override
  String get transferSize => 'Size';

  @override
  String get transferCreated => 'Created';

  @override
  String get transferSource => 'Sent from';

  @override
  String get transferReceiveAsNew => 'This arrives as a new Nexus. Nothing you already have is touched.';

  @override
  String get transferReceiveAction => 'Receive';

  @override
  String get transferReceived => 'Nexus received';

  @override
  String get transferErrNetwork => 'Could not reach the transfer service.';

  @override
  String get transferErrBadCode => 'That transfer code or PIN is not right.';

  @override
  String get transferErrLocked => 'Too many wrong PINs. This transfer is locked for a while.';

  @override
  String get transferErrExpired => 'This transfer has expired. Ask for a new code.';

  @override
  String get transferErrGone => 'This transfer no longer exists — it was received or cancelled.';

  @override
  String get transferErrNotReady => 'The other device has not finished uploading yet.';

  @override
  String get transferErrTooLarge => 'This Nexus is larger than a single transfer allows.';

  @override
  String get transferErrBadToken => 'This transfer session is no longer valid. Start again.';

  @override
  String get transferErrBadKey => 'That link is incomplete — the key part is missing or damaged.';

  @override
  String get transferErrQrOnly => 'The sender allowed the QR code only. Scan it instead of typing.';

  @override
  String get transferErrBadPayload => 'The received file could not be read.';

  @override
  String get transferErrServer => 'The transfer service had a problem.';

  @override
  String get transferSending => 'Sending…';

  @override
  String get transferCopied => 'Link copied';

  @override
  String get transferCancel => 'Cancel';

  @override
  String get transferPasteLink => 'Or paste a transfer link';

  @override
  String get transferPasteLinkHint => 'A link carries the key in it, so it works even when the sender allowed the QR code only.';
}
