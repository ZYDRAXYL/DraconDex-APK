// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'DraconDex';

  @override
  String get nexusTitle => 'DraconDex';

  @override
  String get nexusSubtitle => 'Roman-Datenverwaltung';

  @override
  String get moduleGlobalTags => 'Tags';

  @override
  String get moduleColors => 'Farben';

  @override
  String get moduleSettings => 'Einstellungen';

  @override
  String get btnNew => 'Neu';

  @override
  String get btnSave => 'Speichern';

  @override
  String get btnCancel => 'Abbrechen';

  @override
  String get btnDelete => 'Löschen';

  @override
  String get btnEdit => 'Bearbeiten';

  @override
  String get btnClose => 'Schließen';

  @override
  String get btnAdd => 'Hinzufügen';

  @override
  String get btnImport => 'DB Importieren';

  @override
  String get btnExport => 'DB Exportieren';

  @override
  String get labelName => 'Name';

  @override
  String get labelMemo => 'Memo';

  @override
  String get labelColor => 'Farbe';

  @override
  String get labelNote => 'Notiz';

  @override
  String get labelTags => 'Tags';

  @override
  String get labelSearch => 'Suchen...';

  @override
  String get newHashtag => 'Neuer Tag';

  @override
  String get noTags => 'Noch keine Tags.';

  @override
  String get noColors => 'Keine Farben in der Palette.';

  @override
  String get noResults => 'Keine Ergebnisse gefunden.';

  @override
  String get confirmDeleteTitle => 'Löschen Bestätigen';

  @override
  String get confirmDeleteMessage => 'Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get colorInUse => 'Die Farbe wird verwendet und kann nicht gelöscht werden.';

  @override
  String get themeLabel => 'Design';

  @override
  String get themeMidnight => 'Mitternacht';

  @override
  String get themeMoonlight => 'Mondlicht';

  @override
  String get themeDaylight => 'Tageslicht';

  @override
  String get languageLabel => 'Sprache';

  @override
  String get uiScaleLabel => 'UI-Skalierung';

  @override
  String get importSuccess => 'Datenbank erfolgreich importiert.';

  @override
  String get importFailed => 'Import fehlgeschlagen. Bitte Datei überprüfen.';

  @override
  String get exportSuccess => 'Datenbank exportiert.';

  @override
  String get selectColor => 'Farbe Auswählen';

  @override
  String get recentColors => 'Kürzlich';

  @override
  String get version => 'Version 2.1.0';

  @override
  String get btnRename => 'Umbenennen';

  @override
  String get btnPin => 'Anheften';

  @override
  String get btnUnpin => 'Loslösen';

  @override
  String get newNexusTitle => 'Neuer Nexus';

  @override
  String get renameNexusTitle => 'Nexus umbenennen';

  @override
  String get newModuleTitle => 'Neues Modul';

  @override
  String get renameModuleTitle => 'Modul umbenennen';

  @override
  String get newModuleTooltip => 'Neues Modul';

  @override
  String get newNexusTooltip => 'Neuer Nexus';

  @override
  String get emptyNexusMessage => 'Noch kein Nexus vorhanden. Tippe auf +, um einen zu erstellen.';

  @override
  String get emptyModuleMessage => 'Leer. Tippe auf +, um ein Modul hinzuzufügen.';

  @override
  String get deleteNexusMessage => 'Dies löscht alle darin enthaltenen Module. Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get deleteModuleMessage => 'Dies löscht auch alle verschachtelten Module darin. Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get labelKind => 'Art';

  @override
  String get kindContentUnavailable => 'Diese Modulart wird auf Mobilgeräten noch nicht vollständig unterstützt — das gemeinsame Notizfeld unten wird stattdessen verwendet.';

  @override
  String get notesHint => 'Notizen für dieses Modul…';

  @override
  String get settingsAppearance => 'Erscheinungsbild';

  @override
  String get settingsData => 'Daten';

  @override
  String get settingsAbout => 'Über';

  @override
  String get exportDbTitle => 'Datenbank exportieren';

  @override
  String get exportDbSubtitle => 'Teile die .db-Datei, um Daten auf einen PC oder ein anderes Gerät zu übertragen';

  @override
  String get importDbTitle => 'Datenbank importieren';

  @override
  String get importDbSubtitle => 'Daten aus einer DraconDex-.db-Datei zusammenführen';

  @override
  String get checkUpdatesTitle => 'Nach Updates suchen';

  @override
  String get checkUpdatesSubtitle => 'Prüft die GitHub Releases dieses Projekts — fragt vor der Installation immer nach Bestätigung';

  @override
  String get upToDateMessage => 'Du hast die neueste Version.';

  @override
  String get importingMessage => 'Importiere…';

  @override
  String get importCompleteMessage => 'Import abgeschlossen.';

  @override
  String get importFailedMessage => 'Import fehlgeschlagen.';

  @override
  String get exportFailedMessage => 'Export fehlgeschlagen.';

  @override
  String get saveFailedMessage => 'Speichern fehlgeschlagen.';

  @override
  String get webBackupUnsupportedMessage => 'In der Web-Version nicht verfügbar.';

  @override
  String get driveBackupTitle => 'Google Drive-Sicherung';

  @override
  String get driveConnectedAs => 'Verbunden:';

  @override
  String get driveNotConnected => 'Nicht verbunden';

  @override
  String get driveConnect => 'Verbinden';

  @override
  String get driveDisconnect => 'Trennen';

  @override
  String get driveBackupNow => 'Jetzt sichern';

  @override
  String get driveRestoreTitle => 'Von Google Drive wiederherstellen';

  @override
  String get driveRestoreSubtitle => 'Führt die Drive-Sicherung mit den aktuellen Daten zusammen';

  @override
  String get driveConnectFailedMessage => 'Verbindung fehlgeschlagen.';

  @override
  String get driveBackingUpMessage => 'Sicherung auf Google Drive…';

  @override
  String get driveBackupSuccessMessage => 'Sicherung abgeschlossen.';

  @override
  String get driveBackupFailedMessage => 'Sicherung fehlgeschlagen.';

  @override
  String get addColorTitle => 'Farbe hinzufügen';

  @override
  String get colorPaletteTitle => 'Farbpalette';

  @override
  String get hashtagsTitle => 'Tags';

  @override
  String get editHashtagTitle => 'Tag bearbeiten';

  @override
  String get tagNameLabel => 'Tag-Name';

  @override
  String get removeColorConfirmTitle => 'Farbe entfernen?';

  @override
  String get deleteHashtagConfirmTitle => 'Tag löschen?';

  @override
  String get builderNavHome => 'Start';

  @override
  String get builderNavView => 'Ansicht';

  @override
  String get builderNavFolders => 'Ordneransichten';

  @override
  String get viewModeTitle => 'Ansichtsmodus';

  @override
  String get viewModeList => 'Liste';

  @override
  String get viewModeGrid => 'Raster';

  @override
  String get viewModeCompact => 'Kompakt';

  @override
  String get recentViewsTitle => 'Letzte Ansichten';

  @override
  String get recentViewsEmpty => 'Noch keine letzten Ansichten';

  @override
  String get recentViewsClear => 'Alle löschen';

  @override
  String get builderNexusRootLabel => 'Nexus-Wurzel';

  // --- Supabase project setup (features/settings/supabase_setup_screen.dart) ---

  @override
  String get settingPageSupabase => 'Supabase-Projekt';

  @override
  String get sbIntro => 'Nutze dein eigenes Supabase-Projekt als Server für Cloud Sync. Projekt-URL und Publishable Key einfügen — DraconDex prüft und installiert die nötigen Tabellen selbst.';

  @override
  String get sbUrl => 'Projekt-URL';

  @override
  String get sbKey => 'Publishable Key';

  @override
  String get sbKeyStored => 'Es ist bereits ein Key gespeichert — leer lassen, um ihn zu behalten.';

  @override
  String get sbCheck => 'Projekt prüfen';

  @override
  String get sbObjects => 'Benötigte Tabellen & Funktionen';

  @override
  String get sbSchemaVersion => 'Schema-Version';

  @override
  String get sbReady => 'Bereit — dieses Projekt hat alles, was Cloud Sync braucht.';

  @override
  String get sbNeedSetup => 'Einrichtung nötig — einige Tabellen oder Funktionen fehlen.';

  @override
  String get sbNotChecked => 'Noch nicht geprüft. Speichere die Einstellungen oben und drücke „Projekt prüfen".';

  @override
  String get sbAutoInstall => 'Automatisch einrichten';

  @override
  String get sbAutoInstallHint => 'Mit einem Publishable Key lassen sich keine Tabellen anlegen. Füge ein persönliches Supabase-Zugriffstoken ein, dann führt DraconDex das Setup-SQL für dich aus.';

  @override
  String get sbAccessToken => 'Persönliches Zugriffstoken';

  @override
  String get sbAccessTokenHint => 'Nur für diese eine Anfrage — wird nie gespeichert.';

  @override
  String get sbGetToken => 'Token holen';

  @override
  String get sbManualTitle => 'Oder von Hand einrichten';

  @override
  String get sbManualHint => 'SQL kopieren, im SQL-Editor des Projekts ausführen und erneut „Projekt prüfen" drücken.';

  @override
  String get sbCopySql => 'SQL kopieren';

  @override
  String get sbOpenSqlEditor => 'SQL-Editor öffnen';

  @override
  String get sbOpenApiSettings => 'API-Einstellungen öffnen';

  @override
  String get sbOpenAuthProviders => 'Auth-Provider öffnen';

  @override
  String get sbGoogleOn => 'Google-Anmeldung ist in diesem Projekt aktiviert.';

  @override
  String get sbGoogleOff => 'Google-Anmeldung ist aus — schalte sie unter Authentication → Providers ein, bevor du dich anmeldest.';

  @override
  String get sbInstalled => 'Einrichtung abgeschlossen';

  @override
  String get sbClear => 'Projekt entfernen';

  @override
  String get sbClearConfirm => 'Die gespeicherten Supabase-Projekteinstellungen entfernen?';

  @override
  String get sbCleared => 'Supabase-Einstellungen entfernt';

  @override
  String get sbErrNoConfig => 'Bitte zuerst Projekt-URL und Publishable Key eingeben.';

  @override
  String get sbErrInvalidUrl => 'Diese Projekt-URL ist ungültig — nur https.';

  @override
  String get sbErrBadKey => 'Das Projekt hat diesen Key abgelehnt.';

  @override
  String get sbErrUnreachable => 'Dieses Projekt war nicht erreichbar.';

  @override
  String get sbErrNeedsManual => 'Kein Zugriffstoken — nutze stattdessen die manuellen Schritte.';

  @override
  String get sbErrBadAccessToken => 'Dieses Zugriffstoken wurde abgelehnt.';

  @override
  String get sbErrForbidden => 'Dieses Token darf das Projekt nicht ändern.';

  @override
  String get sbErrNoProjectRef => 'Die automatische Einrichtung braucht eine supabase.co-Projekt-URL.';

  @override
  String get sbErrRateLimited => 'Zu viele Anfragen — bitte gleich noch einmal versuchen.';

  @override
  String get sbErrSqlError => 'Das Setup-SQL konnte nicht ausgeführt werden.';

  @override
  String get sbErrNetwork => 'Netzwerkfehler — Projekt nicht erreichbar.';

  @override
  String get sbCopied => 'Kopiert';

  @override
  String get sbNotConfigured => 'Noch kein Projekt eingerichtet';
  @override
  String get googleAccountTitle => 'Google-Konto';

  @override
  String get googleAccountNotConfigured => 'Noch kein OAuth-Client eingerichtet';

  @override
  String get googleAccountSetupTitle => 'Google-Anmeldung einrichten';

  @override
  String get googleClientTypeHintNative => 'Aktiviere in der Google Cloud Console die Google-Drive-API, erstelle einen OAuth-Client vom Typ „Desktop-App“ und füge die Daten unten ein.';

  @override
  String get googleClientTypeHintWeb => 'Aktiviere in der Google Cloud Console die Google-Drive-API, erstelle einen OAuth-Client vom Typ „Webanwendung“ und füge die Client-ID unten ein.';

  @override
  String get googleClientIdLabel => 'Client-ID';

  @override
  String get googleClientSecretLabel => 'Client-Schlüssel';

  @override
  String get googleClientSecretKept => 'Ein Client-Schlüssel ist bereits gespeichert. Leer lassen, um ihn zu behalten.';

  @override
  String get googleRedirectUriLabel => 'Autorisierter Weiterleitungs-URI';

  @override
  String get googleRedirectUriHint => 'Trage genau diese Adresse bei den autorisierten Weiterleitungs-URIs des Clients ein und die Adresse dieser Seite bei den autorisierten JavaScript-Quellen.';

  @override
  String get googleSessionExpired => 'Sitzung abgelaufen – erneut verbinden';

  @override
  String get googleErrNoConfig => 'Gib zuerst die Daten des OAuth-Clients ein.';

  @override
  String get googleErrCancelled => 'Die Anmeldung wurde abgebrochen.';

  @override
  String get googleErrTimeout => 'Zeitüberschreitung bei der Anmeldung.';

  @override
  String get googleErrVerify => 'Die Anmeldung konnte nicht überprüft werden. Bitte erneut versuchen.';

  @override
  String get googleErrNetwork => 'Google konnte nicht erreicht werden.';

  @override
  String get googleErrAuth => 'Google hat die Anmeldung abgelehnt.';

  @override
  String get googleErrPopupBlocked => 'Das Anmeldefenster wurde blockiert. Erlaube Pop-ups für diese Seite und versuche es erneut.';

  @override
  String get googleErrNotConnected => 'Mit keinem Google-Konto verbunden.';

  @override
  String get driveRestoreSettingsTitle => 'Einstellungen aus Drive wiederherstellen';

  @override
  String get driveRestoreSettingsSubtitle => 'Ersetzt Design, Sprache und UI-Größe durch die gesicherten Werte.';

  @override
  String get driveSettingsRestoredMessage => 'Einstellungen aus Google Drive wiederhergestellt.';

  @override
  String get driveNoBackupMessage => 'Keine Sicherung in Google Drive gefunden.';

  @override
  String get driveWebDatabaseNote => 'In der Browser-Version werden nur die Einstellungen gesichert – die Datenbank bleibt auf diesem Gerät.';

  @override
  String get hubNestTitle => 'Nexus-Nest';

  @override
  String get hubPanelShow => 'Hub-Leiste anzeigen';

  @override
  String get hubPanelHide => 'Hub-Leiste ausblenden';

  @override
  String get railExpand => 'Leiste erweitern';

  @override
  String get railCollapse => 'Leiste einklappen';
}
