// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'DraconDex';

  @override
  String get nexusTitle => 'DraconDex';

  @override
  String get nexusSubtitle => 'Gestion des Données de Romans';

  @override
  String get moduleGlobalTags => 'Tags';

  @override
  String get moduleColors => 'Couleurs';

  @override
  String get moduleSettings => 'Paramètres';

  @override
  String get btnNew => 'Nouveau';

  @override
  String get btnSave => 'Enregistrer';

  @override
  String get btnCancel => 'Annuler';

  @override
  String get btnDelete => 'Supprimer';

  @override
  String get btnEdit => 'Modifier';

  @override
  String get btnClose => 'Fermer';

  @override
  String get btnAdd => 'Ajouter';

  @override
  String get btnImport => 'Importer la BD';

  @override
  String get btnExport => 'Exporter la BD';

  @override
  String get labelName => 'Nom';

  @override
  String get labelMemo => 'Mémo';

  @override
  String get labelColor => 'Couleur';

  @override
  String get labelNote => 'Note';

  @override
  String get labelTags => 'Tags';

  @override
  String get labelSearch => 'Rechercher...';

  @override
  String get newHashtag => 'Nouveau Tag';

  @override
  String get noTags => 'Aucun tag pour le moment.';

  @override
  String get noColors => 'Aucune couleur dans la palette.';

  @override
  String get noResults => 'Aucun résultat trouvé.';

  @override
  String get confirmDeleteTitle => 'Confirmer la Suppression';

  @override
  String get confirmDeleteMessage => 'Cette action est irréversible.';

  @override
  String get colorInUse => 'La couleur est utilisée et ne peut pas être supprimée.';

  @override
  String get themeLabel => 'Thème';

  @override
  String get themeMidnight => 'Minuit';

  @override
  String get themeMoonlight => 'Clair de Lune';

  @override
  String get themeDaylight => 'Lumière du Jour';

  @override
  String get languageLabel => 'Langue';

  @override
  String get uiScaleLabel => 'Échelle de l\'Interface';

  @override
  String get importSuccess => 'Base de données importée avec succès.';

  @override
  String get importFailed => 'Échec de l\'importation. Veuillez vérifier le fichier.';

  @override
  String get exportSuccess => 'Base de données exportée.';

  @override
  String get selectColor => 'Sélectionner une Couleur';

  @override
  String get recentColors => 'Récentes';

  @override
  String get version => 'Version 2.1.0';

  @override
  String get btnRename => 'Renommer';

  @override
  String get btnPin => 'Épingler';

  @override
  String get btnUnpin => 'Détacher';

  @override
  String get newNexusTitle => 'Nouveau Nexus';

  @override
  String get renameNexusTitle => 'Renommer le Nexus';

  @override
  String get newModuleTitle => 'Nouveau Module';

  @override
  String get renameModuleTitle => 'Renommer le Module';

  @override
  String get newModuleTooltip => 'Nouveau Module';

  @override
  String get newNexusTooltip => 'Nouveau Nexus';

  @override
  String get emptyNexusMessage => 'Aucun Nexus pour l\'instant. Appuyez sur + pour en créer un.';

  @override
  String get emptyModuleMessage => 'Vide. Appuyez sur + pour ajouter un module.';

  @override
  String get deleteNexusMessage => 'Cela supprime tous les modules qu\'il contient. Cette action est irréversible.';

  @override
  String get deleteModuleMessage => 'Cela supprime aussi tous les modules imbriqués à l\'intérieur. Cette action est irréversible.';

  @override
  String get labelKind => 'Type';

  @override
  String get kindContentUnavailable => 'Ce type de module n\'est pas encore entièrement pris en charge sur mobile — le champ de notes partagé ci-dessous est utilisé à la place.';

  @override
  String get notesHint => 'Notes pour ce module…';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get settingsData => 'Données';

  @override
  String get settingsAbout => 'À propos';

  @override
  String get exportDbTitle => 'Exporter la base de données';

  @override
  String get exportDbSubtitle => 'Partagez le fichier .db pour transférer les données vers un PC ou un autre appareil';

  @override
  String get importDbTitle => 'Importer la base de données';

  @override
  String get importDbSubtitle => 'Fusionner les données depuis un fichier .db DraconDex';

  @override
  String get checkUpdatesTitle => 'Vérifier les mises à jour';

  @override
  String get checkUpdatesSubtitle => 'Consulte les GitHub Releases de ce projet — demande toujours confirmation avant d\'installer';

  @override
  String get upToDateMessage => 'Vous avez la dernière version.';

  @override
  String get importingMessage => 'Importation…';

  @override
  String get importCompleteMessage => 'Importation terminée.';

  @override
  String get importFailedMessage => 'Échec de l\'importation.';

  @override
  String get exportFailedMessage => 'Échec de l\'exportation.';

  @override
  String get saveFailedMessage => 'Échec de l\'enregistrement.';

  @override
  String get webBackupUnsupportedMessage => 'Non disponible dans la version web.';

  @override
  String get driveBackupTitle => 'Sauvegarde Google Drive';

  @override
  String get driveConnectedAs => 'Connecté :';

  @override
  String get driveNotConnected => 'Non connecté';

  @override
  String get driveConnect => 'Connecter';

  @override
  String get driveDisconnect => 'Déconnecter';

  @override
  String get driveBackupNow => 'Sauvegarder maintenant';

  @override
  String get driveRestoreTitle => 'Restaurer depuis Google Drive';

  @override
  String get driveRestoreSubtitle => 'Fusionne la sauvegarde Drive avec vos données actuelles';

  @override
  String get driveConnectFailedMessage => 'Échec de la connexion.';

  @override
  String get driveBackingUpMessage => 'Sauvegarde vers Google Drive…';

  @override
  String get driveBackupSuccessMessage => 'Sauvegarde terminée.';

  @override
  String get driveBackupFailedMessage => 'Échec de la sauvegarde.';

  @override
  String get addColorTitle => 'Ajouter une couleur';

  @override
  String get colorPaletteTitle => 'Palette de couleurs';

  @override
  String get hashtagsTitle => 'Tags';

  @override
  String get editHashtagTitle => 'Modifier le tag';

  @override
  String get tagNameLabel => 'Nom du tag';

  @override
  String get removeColorConfirmTitle => 'Supprimer la couleur ?';

  @override
  String get deleteHashtagConfirmTitle => 'Supprimer le tag ?';

  @override
  String get builderNavHome => 'Accueil';

  @override
  String get builderNavView => 'Vue';

  @override
  String get builderNavFolders => 'Vues de dossier';

  @override
  String get viewModeTitle => 'Mode d\'affichage';

  @override
  String get viewModeList => 'Liste';

  @override
  String get viewModeGrid => 'Grille';

  @override
  String get viewModeCompact => 'Compact';

  @override
  String get recentViewsTitle => 'Vues récentes';

  @override
  String get recentViewsEmpty => 'Aucune vue récente';

  @override
  String get recentViewsClear => 'Tout effacer';

  @override
  String get builderNexusRootLabel => 'Racine du Nexus';

  // --- Supabase project setup (features/settings/supabase_setup_screen.dart) ---

  @override
  String get settingPageSupabase => 'Projet Supabase';

  @override
  String get sbIntro => 'Utilisez votre propre projet Supabase comme serveur de Cloud Sync. Collez l\'URL du projet et la clé publishable, et laissez DraconDex vérifier puis installer les tables nécessaires.';

  @override
  String get sbUrl => 'URL du projet';

  @override
  String get sbKey => 'Clé publishable';

  @override
  String get sbKeyStored => 'Une clé est déjà enregistrée — laissez vide pour la conserver.';

  @override
  String get sbCheck => 'Vérifier le projet';

  @override
  String get sbObjects => 'Tables et fonctions requises';

  @override
  String get sbSchemaVersion => 'Version du schéma';

  @override
  String get sbReady => 'Prêt — ce projet a tout ce dont Cloud Sync a besoin.';

  @override
  String get sbNeedSetup => 'Installation nécessaire — certaines tables ou fonctions manquent.';

  @override
  String get sbNotChecked => 'Pas encore vérifié. Enregistrez les réglages ci-dessus, puis appuyez sur « Vérifier le projet ».';

  @override
  String get sbAutoInstall => 'Installation automatique';

  @override
  String get sbAutoInstallHint => 'Une clé publishable ne peut pas créer de tables. Collez un jeton d\'accès personnel Supabase et DraconDex exécutera le SQL d\'installation pour vous.';

  @override
  String get sbAccessToken => 'Jeton d\'accès personnel';

  @override
  String get sbAccessTokenHint => 'Utilisé pour cette seule requête — jamais enregistré.';

  @override
  String get sbGetToken => 'Obtenir un jeton';

  @override
  String get sbManualTitle => 'Ou installez-le à la main';

  @override
  String get sbManualHint => 'Copiez le SQL, exécutez-le dans l\'éditeur SQL de votre projet, puis appuyez de nouveau sur « Vérifier le projet ».';

  @override
  String get sbCopySql => 'Copier le SQL';

  @override
  String get sbOpenSqlEditor => 'Ouvrir l\'éditeur SQL';

  @override
  String get sbOpenApiSettings => 'Ouvrir les réglages API';

  @override
  String get sbOpenAuthProviders => 'Ouvrir les fournisseurs Auth';

  @override
  String get sbGoogleOn => 'La connexion Google est activée sur ce projet.';

  @override
  String get sbGoogleOff => 'La connexion Google est désactivée — activez-la dans Authentication → Providers avant de vous connecter.';

  @override
  String get sbInstalled => 'Installation terminée';

  @override
  String get sbClear => 'Retirer le projet';

  @override
  String get sbClearConfirm => 'Retirer les réglages enregistrés du projet Supabase ?';

  @override
  String get sbCleared => 'Réglages Supabase retirés';

  @override
  String get sbErrNoConfig => 'Saisissez d\'abord l\'URL du projet et la clé publishable.';

  @override
  String get sbErrInvalidUrl => 'Cette URL de projet n\'est pas valide — https uniquement.';

  @override
  String get sbErrBadKey => 'Le projet a refusé cette clé.';

  @override
  String get sbErrUnreachable => 'Impossible de joindre ce projet.';

  @override
  String get sbErrNeedsManual => 'Pas de jeton d\'accès — utilisez la procédure manuelle.';

  @override
  String get sbErrBadAccessToken => 'Ce jeton d\'accès a été refusé.';

  @override
  String get sbErrForbidden => 'Ce jeton n\'a pas le droit de modifier ce projet.';

  @override
  String get sbErrNoProjectRef => 'L\'installation automatique nécessite une URL de projet supabase.co.';

  @override
  String get sbErrRateLimited => 'Trop de requêtes — réessayez dans un instant.';

  @override
  String get sbErrSqlError => 'L\'exécution du SQL d\'installation a échoué.';

  @override
  String get sbErrNetwork => 'Erreur réseau — impossible de joindre le projet.';

  @override
  String get sbCopied => 'Copié';

  @override
  String get sbNotConfigured => 'Aucun projet configuré pour le moment';
  @override
  String get googleAccountTitle => 'Compte Google';

  @override
  String get googleAccountNotConfigured => 'Aucun client OAuth configuré';

  @override
  String get googleAccountSetupTitle => 'Configuration de la connexion Google';

  @override
  String get googleClientTypeHintNative => 'Dans Google Cloud Console, activez l\'API Google Drive et créez un client OAuth de type « Application de bureau », puis collez ses informations ci-dessous.';

  @override
  String get googleClientTypeHintWeb => 'Dans Google Cloud Console, activez l\'API Google Drive et créez un client OAuth de type « Application Web », puis collez son ID client ci-dessous.';

  @override
  String get googleClientIdLabel => 'ID client';

  @override
  String get googleClientSecretLabel => 'Code secret du client';

  @override
  String get googleClientSecretKept => 'Un code secret est déjà enregistré. Laissez ce champ vide pour le conserver.';

  @override
  String get googleRedirectUriLabel => 'URI de redirection autorisé';

  @override
  String get googleRedirectUriHint => 'Ajoutez cette adresse exacte aux URI de redirection autorisés du client, et l\'adresse de ce site à ses origines JavaScript autorisées.';

  @override
  String get googleSessionExpired => 'Session expirée — reconnectez-vous';

  @override
  String get googleErrNoConfig => 'Saisissez d\'abord les informations du client OAuth.';

  @override
  String get googleErrCancelled => 'La connexion a été annulée.';

  @override
  String get googleErrTimeout => 'Le délai de connexion a expiré.';

  @override
  String get googleErrVerify => 'La connexion n\'a pas pu être vérifiée. Réessayez.';

  @override
  String get googleErrNetwork => 'Impossible de joindre Google.';

  @override
  String get googleErrAuth => 'Google a refusé la connexion.';

  @override
  String get googleErrPopupBlocked => 'La fenêtre de connexion a été bloquée. Autorisez les pop-ups pour ce site et réessayez.';

  @override
  String get googleErrNotConnected => 'Aucun compte Google connecté.';

  @override
  String get driveRestoreSettingsTitle => 'Restaurer les réglages depuis Drive';

  @override
  String get driveRestoreSettingsSubtitle => 'Remplace le thème, la langue et la taille de l\'interface par ceux de la sauvegarde.';

  @override
  String get driveSettingsRestoredMessage => 'Réglages restaurés depuis Google Drive.';

  @override
  String get driveNoBackupMessage => 'Aucune sauvegarde trouvée sur Google Drive.';

  @override
  String get driveWebDatabaseNote => 'Dans la version navigateur, seuls les réglages sont sauvegardés — la base de données reste sur cet appareil.';

  @override
  String get hubNestTitle => 'Nid Nexus';

  @override
  String get hubPanelShow => 'Afficher le panneau du hub';

  @override
  String get hubPanelHide => 'Masquer le panneau du hub';

  @override
  String get railExpand => 'Étendre la barre';

  @override
  String get railCollapse => 'Réduire la barre';
}
