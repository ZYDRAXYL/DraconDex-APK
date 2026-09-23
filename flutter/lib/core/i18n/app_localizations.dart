import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_id.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_qd.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_th.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'i18n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('id'),
    Locale('ja'),
    Locale('ko'),
    Locale('pt'),
    Locale('qd'),
    Locale('ru'),
    Locale('th'),
    Locale('vi'),
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'DraconDex'**
  String get appName;

  /// No description provided for @nexusTitle.
  ///
  /// In en, this message translates to:
  /// **'DraconDex'**
  String get nexusTitle;

  /// No description provided for @nexusSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Novel Data Management'**
  String get nexusSubtitle;

  /// No description provided for @moduleGlobalTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get moduleGlobalTags;

  /// No description provided for @moduleColors.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get moduleColors;

  /// No description provided for @moduleSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get moduleSettings;

  /// No description provided for @btnNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get btnNew;

  /// No description provided for @btnSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get btnSave;

  /// No description provided for @btnCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get btnCancel;

  /// No description provided for @btnDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get btnDelete;

  /// No description provided for @btnEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get btnEdit;

  /// No description provided for @btnClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get btnClose;

  /// No description provided for @btnAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get btnAdd;

  /// No description provided for @btnImport.
  ///
  /// In en, this message translates to:
  /// **'Import DB'**
  String get btnImport;

  /// No description provided for @btnExport.
  ///
  /// In en, this message translates to:
  /// **'Export DB'**
  String get btnExport;

  /// No description provided for @labelName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get labelName;

  /// No description provided for @labelMemo.
  ///
  /// In en, this message translates to:
  /// **'Memo'**
  String get labelMemo;

  /// No description provided for @labelColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get labelColor;

  /// No description provided for @labelNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get labelNote;

  /// No description provided for @labelTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get labelTags;

  /// No description provided for @labelSearch.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get labelSearch;

  /// No description provided for @newHashtag.
  ///
  /// In en, this message translates to:
  /// **'New Tag'**
  String get newHashtag;

  /// No description provided for @noTags.
  ///
  /// In en, this message translates to:
  /// **'No tags yet.'**
  String get noTags;

  /// No description provided for @noColors.
  ///
  /// In en, this message translates to:
  /// **'No colors in the palette.'**
  String get noColors;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results found.'**
  String get noResults;

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get confirmDeleteTitle;

  /// No description provided for @confirmDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get confirmDeleteMessage;

  /// No description provided for @colorInUse.
  ///
  /// In en, this message translates to:
  /// **'Color is in use and cannot be deleted.'**
  String get colorInUse;

  /// No description provided for @themeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// No description provided for @themeMidnight.
  ///
  /// In en, this message translates to:
  /// **'Midnight'**
  String get themeMidnight;

  /// No description provided for @themeMoonlight.
  ///
  /// In en, this message translates to:
  /// **'Moonlight'**
  String get themeMoonlight;

  /// No description provided for @themeDaylight.
  ///
  /// In en, this message translates to:
  /// **'Daylight'**
  String get themeDaylight;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @uiScaleLabel.
  ///
  /// In en, this message translates to:
  /// **'UI Scale'**
  String get uiScaleLabel;

  /// No description provided for @importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Database imported successfully.'**
  String get importSuccess;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed. Please check the file.'**
  String get importFailed;

  /// No description provided for @exportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Database exported.'**
  String get exportSuccess;

  /// No description provided for @selectColor.
  ///
  /// In en, this message translates to:
  /// **'Select Color'**
  String get selectColor;

  /// No description provided for @recentColors.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recentColors;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version 2.1.0'**
  String get version;

  /// No description provided for @btnRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get btnRename;

  /// No description provided for @btnPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get btnPin;

  /// No description provided for @btnUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get btnUnpin;

  /// No description provided for @newNexusTitle.
  ///
  /// In en, this message translates to:
  /// **'New Nexus'**
  String get newNexusTitle;

  /// No description provided for @renameNexusTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename Nexus'**
  String get renameNexusTitle;

  /// No description provided for @newModuleTitle.
  ///
  /// In en, this message translates to:
  /// **'New Module'**
  String get newModuleTitle;

  /// No description provided for @renameModuleTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename Module'**
  String get renameModuleTitle;

  /// No description provided for @newModuleTooltip.
  ///
  /// In en, this message translates to:
  /// **'New Module'**
  String get newModuleTooltip;

  /// No description provided for @newNexusTooltip.
  ///
  /// In en, this message translates to:
  /// **'New Nexus'**
  String get newNexusTooltip;

  /// No description provided for @emptyNexusMessage.
  ///
  /// In en, this message translates to:
  /// **'No Nexus yet. Tap + to create one.'**
  String get emptyNexusMessage;

  /// No description provided for @emptyModuleMessage.
  ///
  /// In en, this message translates to:
  /// **'Empty. Tap + to add a module.'**
  String get emptyModuleMessage;

  /// No description provided for @deleteNexusMessage.
  ///
  /// In en, this message translates to:
  /// **'This deletes every module inside it. This action cannot be undone.'**
  String get deleteNexusMessage;

  /// No description provided for @deleteModuleMessage.
  ///
  /// In en, this message translates to:
  /// **'This deletes every module nested inside it too. This action cannot be undone.'**
  String get deleteModuleMessage;

  /// No description provided for @labelKind.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get labelKind;

  /// No description provided for @kindContentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This module kind isn't fully supported on mobile yet — using the shared notes field below.'**
  String get kindContentUnavailable;

  /// No description provided for @notesHint.
  ///
  /// In en, this message translates to:
  /// **'Notes for this module…'**
  String get notesHint;

  /// No description provided for @authorChapters.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get authorChapters;

  /// No description provided for @authorNewChapter.
  ///
  /// In en, this message translates to:
  /// **'New chapter'**
  String get authorNewChapter;

  /// No description provided for @authorNoChapters.
  ///
  /// In en, this message translates to:
  /// **'No chapters yet'**
  String get authorNoChapters;

  /// No description provided for @authorContentHint.
  ///
  /// In en, this message translates to:
  /// **'Write this chapter…'**
  String get authorContentHint;

  /// No description provided for @scribeSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get scribeSessions;

  /// No description provided for @scribeNewSession.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get scribeNewSession;

  /// No description provided for @scribeNoSessions.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet'**
  String get scribeNoSessions;

  /// No description provided for @scribeMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Write a message…'**
  String get scribeMessageHint;

  /// No description provided for @scribeSwitchSide.
  ///
  /// In en, this message translates to:
  /// **'Switch side'**
  String get scribeSwitchSide;

  /// No description provided for @chroniclerEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get chroniclerEvents;

  /// No description provided for @chroniclerNewEvent.
  ///
  /// In en, this message translates to:
  /// **'New event'**
  String get chroniclerNewEvent;

  /// No description provided for @chroniclerNoEvents.
  ///
  /// In en, this message translates to:
  /// **'No events yet'**
  String get chroniclerNoEvents;

  /// No description provided for @chroniclerUntitledEvent.
  ///
  /// In en, this message translates to:
  /// **'Untitled event'**
  String get chroniclerUntitledEvent;

  /// No description provided for @chroniclerStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get chroniclerStart;

  /// No description provided for @chroniclerYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get chroniclerYear;

  /// No description provided for @chroniclerMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get chroniclerMonth;

  /// No description provided for @chroniclerDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get chroniclerDay;

  /// No description provided for @chroniclerHour.
  ///
  /// In en, this message translates to:
  /// **'Hour'**
  String get chroniclerHour;

  /// No description provided for @chroniclerMinute.
  ///
  /// In en, this message translates to:
  /// **'Minute'**
  String get chroniclerMinute;

  /// No description provided for @chroniclerHasEnd.
  ///
  /// In en, this message translates to:
  /// **'Has an end date'**
  String get chroniclerHasEnd;

  /// No description provided for @chroniclerStory.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get chroniclerStory;

  /// No description provided for @classifierFields.
  ///
  /// In en, this message translates to:
  /// **'Fields'**
  String get classifierFields;

  /// No description provided for @classifierNewField.
  ///
  /// In en, this message translates to:
  /// **'New field'**
  String get classifierNewField;

  /// No description provided for @classifierNoFields.
  ///
  /// In en, this message translates to:
  /// **'No fields yet'**
  String get classifierNoFields;

  /// No description provided for @classifierItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get classifierItems;

  /// No description provided for @classifierNewItem.
  ///
  /// In en, this message translates to:
  /// **'New item'**
  String get classifierNewItem;

  /// No description provided for @classifierNoItems.
  ///
  /// In en, this message translates to:
  /// **'No items yet'**
  String get classifierNoItems;

  /// No description provided for @classifierDeleteFieldWarning.
  ///
  /// In en, this message translates to:
  /// **'This also deletes the value every item holds for it.'**
  String get classifierDeleteFieldWarning;

  /// No description provided for @narratorScenes.
  ///
  /// In en, this message translates to:
  /// **'Scenes'**
  String get narratorScenes;

  /// No description provided for @narratorNewScene.
  ///
  /// In en, this message translates to:
  /// **'New scene'**
  String get narratorNewScene;

  /// No description provided for @narratorNoScenes.
  ///
  /// In en, this message translates to:
  /// **'No scenes yet'**
  String get narratorNoScenes;

  /// No description provided for @narratorScript.
  ///
  /// In en, this message translates to:
  /// **'Script'**
  String get narratorScript;

  /// No description provided for @narratorNewLine.
  ///
  /// In en, this message translates to:
  /// **'New line'**
  String get narratorNewLine;

  /// No description provided for @narratorNoLines.
  ///
  /// In en, this message translates to:
  /// **'No lines yet'**
  String get narratorNoLines;

  /// No description provided for @narratorSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get narratorSpeaker;

  /// No description provided for @narratorLine.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get narratorLine;

  /// No description provided for @narratorRoutes.
  ///
  /// In en, this message translates to:
  /// **'Routes'**
  String get narratorRoutes;

  /// No description provided for @narratorLeadsTo.
  ///
  /// In en, this message translates to:
  /// **'Leads to'**
  String get narratorLeadsTo;

  /// No description provided for @narratorNoRoutes.
  ///
  /// In en, this message translates to:
  /// **'No routes yet'**
  String get narratorNoRoutes;

  /// No description provided for @viewerResults.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get viewerResults;

  /// No description provided for @viewerNoFilter.
  ///
  /// In en, this message translates to:
  /// **'No filter set yet — open the filter to choose what this lens shows.'**
  String get viewerNoFilter;

  /// No description provided for @viewerNoResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches this filter'**
  String get viewerNoResults;

  /// No description provided for @viewerUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get viewerUntitled;

  /// No description provided for @filterTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filterTitle;

  /// No description provided for @filterExplain.
  ///
  /// In en, this message translates to:
  /// **'Rules inside a group must all match. Any one group matching is enough.'**
  String get filterExplain;

  /// No description provided for @filterAnd.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get filterAnd;

  /// No description provided for @filterOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get filterOr;

  /// No description provided for @filterAddRule.
  ///
  /// In en, this message translates to:
  /// **'Add rule'**
  String get filterAddRule;

  /// No description provided for @filterAddGroup.
  ///
  /// In en, this message translates to:
  /// **'Add group'**
  String get filterAddGroup;

  /// No description provided for @filterFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get filterFieldName;

  /// No description provided for @filterFieldHashtag.
  ///
  /// In en, this message translates to:
  /// **'Hashtag'**
  String get filterFieldHashtag;

  /// No description provided for @filterFieldKind.
  ///
  /// In en, this message translates to:
  /// **'Module kind'**
  String get filterFieldKind;

  /// No description provided for @filterFieldChildOf.
  ///
  /// In en, this message translates to:
  /// **'Inside module'**
  String get filterFieldChildOf;

  /// No description provided for @filterFieldHandle.
  ///
  /// In en, this message translates to:
  /// **'Handle'**
  String get filterFieldHandle;

  /// No description provided for @filterOpIs.
  ///
  /// In en, this message translates to:
  /// **'is'**
  String get filterOpIs;

  /// No description provided for @filterOpIsNot.
  ///
  /// In en, this message translates to:
  /// **'is not'**
  String get filterOpIsNot;

  /// No description provided for @filterOpStartsWith.
  ///
  /// In en, this message translates to:
  /// **'starts with'**
  String get filterOpStartsWith;

  /// No description provided for @filterOpEndsWith.
  ///
  /// In en, this message translates to:
  /// **'ends with'**
  String get filterOpEndsWith;

  /// No description provided for @filterOpContains.
  ///
  /// In en, this message translates to:
  /// **'contains'**
  String get filterOpContains;

  /// No description provided for @filterPickModule.
  ///
  /// In en, this message translates to:
  /// **'Pick a module'**
  String get filterPickModule;

  /// No description provided for @connectorRelations.
  ///
  /// In en, this message translates to:
  /// **'Relations'**
  String get connectorRelations;

  /// No description provided for @connectorNoRelations.
  ///
  /// In en, this message translates to:
  /// **'No relations yet'**
  String get connectorNoRelations;

  /// No description provided for @connectorAddRelation.
  ///
  /// In en, this message translates to:
  /// **'Add relation'**
  String get connectorAddRelation;

  /// No description provided for @connectorFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get connectorFrom;

  /// No description provided for @connectorTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get connectorTo;

  /// No description provided for @connectorLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get connectorLabel;

  /// No description provided for @connectorNodes.
  ///
  /// In en, this message translates to:
  /// **'Items in this lens'**
  String get connectorNodes;

  /// No description provided for @designerBoard.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get designerBoard;

  /// No description provided for @designerNewNode.
  ///
  /// In en, this message translates to:
  /// **'New node'**
  String get designerNewNode;

  /// No description provided for @designerNode.
  ///
  /// In en, this message translates to:
  /// **'Node'**
  String get designerNode;

  /// No description provided for @designerNodeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get designerNodeText;

  /// No description provided for @designerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No nodes yet'**
  String get designerEmpty;

  /// No description provided for @designerLinkHint.
  ///
  /// In en, this message translates to:
  /// **'Tap another node to connect it'**
  String get designerLinkHint;

  /// No description provided for @designerLinkCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel link'**
  String get designerLinkCancel;

  /// No description provided for @sketcherPages.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get sketcherPages;

  /// No description provided for @sketcherNewPage.
  ///
  /// In en, this message translates to:
  /// **'New page'**
  String get sketcherNewPage;

  /// No description provided for @sketcherNoPages.
  ///
  /// In en, this message translates to:
  /// **'No pages yet'**
  String get sketcherNoPages;

  /// No description provided for @sketcherDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get sketcherDraw;

  /// No description provided for @sketcherPan.
  ///
  /// In en, this message translates to:
  /// **'Pan'**
  String get sketcherPan;

  /// No description provided for @sketcherUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo last stroke'**
  String get sketcherUndo;

  /// No description provided for @sketcherClear.
  ///
  /// In en, this message translates to:
  /// **'Clear page'**
  String get sketcherClear;

  /// No description provided for @sketcherClearWarning.
  ///
  /// In en, this message translates to:
  /// **'This erases every stroke on this page.'**
  String get sketcherClearWarning;

  /// No description provided for @locatorAreas.
  ///
  /// In en, this message translates to:
  /// **'Areas'**
  String get locatorAreas;

  /// No description provided for @locatorNewArea.
  ///
  /// In en, this message translates to:
  /// **'New area'**
  String get locatorNewArea;

  /// No description provided for @locatorNoAreas.
  ///
  /// In en, this message translates to:
  /// **'No areas yet'**
  String get locatorNoAreas;

  /// No description provided for @locatorUntitledArea.
  ///
  /// In en, this message translates to:
  /// **'Untitled area'**
  String get locatorUntitledArea;

  /// No description provided for @locatorToolDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get locatorToolDraw;

  /// No description provided for @locatorToolMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get locatorToolMove;

  /// No description provided for @locatorUndoPoint.
  ///
  /// In en, this message translates to:
  /// **'Undo last point'**
  String get locatorUndoPoint;

  /// No description provided for @locatorDrawHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the map to place points'**
  String get locatorDrawHint;

  /// No description provided for @locatorDeleteAreaWarning.
  ///
  /// In en, this message translates to:
  /// **'This deletes the area and all its points.'**
  String get locatorDeleteAreaWarning;

  /// No description provided for @wandererPins.
  ///
  /// In en, this message translates to:
  /// **'Pins'**
  String get wandererPins;

  /// No description provided for @wandererNoPins.
  ///
  /// In en, this message translates to:
  /// **'No pins yet'**
  String get wandererNoPins;

  /// No description provided for @wandererPlacing.
  ///
  /// In en, this message translates to:
  /// **'Placing'**
  String get wandererPlacing;

  /// No description provided for @wandererPlaceHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the map to place a pin'**
  String get wandererPlaceHint;

  /// No description provided for @wandererPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get wandererPin;

  /// No description provided for @wandererLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get wandererLabel;

  /// No description provided for @wandererLinkedEvent.
  ///
  /// In en, this message translates to:
  /// **'Linked event'**
  String get wandererLinkedEvent;

  /// No description provided for @wandererNoLink.
  ///
  /// In en, this message translates to:
  /// **'No link'**
  String get wandererNoLink;

  /// No description provided for @wandererNoEvents.
  ///
  /// In en, this message translates to:
  /// **'No timeline events in this Nexus yet'**
  String get wandererNoEvents;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsData;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @exportDbTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Database'**
  String get exportDbTitle;

  /// No description provided for @exportDbSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share the .db file to transfer data to PC or another device'**
  String get exportDbSubtitle;

  /// No description provided for @importDbTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Database'**
  String get importDbTitle;

  /// No description provided for @importDbSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Merge data from a DraconDex .db file'**
  String get importDbSubtitle;

  /// No description provided for @checkUpdatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get checkUpdatesTitle;

  /// No description provided for @checkUpdatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Looks at this project's GitHub Releases — always asks before installing'**
  String get checkUpdatesSubtitle;

  /// No description provided for @upToDateMessage.
  ///
  /// In en, this message translates to:
  /// **'You're on the latest version.'**
  String get upToDateMessage;

  /// No description provided for @importingMessage.
  ///
  /// In en, this message translates to:
  /// **'Importing…'**
  String get importingMessage;

  /// No description provided for @importCompleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Import complete.'**
  String get importCompleteMessage;

  /// No description provided for @importFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Import failed.'**
  String get importFailedMessage;

  /// No description provided for @exportFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Export failed.'**
  String get exportFailedMessage;

  /// No description provided for @saveFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Save failed.'**
  String get saveFailedMessage;

  /// No description provided for @webBackupUnsupportedMessage.
  ///
  /// In en, this message translates to:
  /// **'Not available in the web version.'**
  String get webBackupUnsupportedMessage;

  /// No description provided for @driveBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Google Drive Backup'**
  String get driveBackupTitle;

  /// No description provided for @driveConnectedAs.
  ///
  /// In en, this message translates to:
  /// **'Connected:'**
  String get driveConnectedAs;

  /// No description provided for @driveNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get driveNotConnected;

  /// No description provided for @driveConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get driveConnect;

  /// No description provided for @driveDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get driveDisconnect;

  /// No description provided for @driveBackupNow.
  ///
  /// In en, this message translates to:
  /// **'Backup Now'**
  String get driveBackupNow;

  /// No description provided for @driveRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from Google Drive'**
  String get driveRestoreTitle;

  /// No description provided for @driveRestoreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Merges the Drive backup into your current data'**
  String get driveRestoreSubtitle;

  /// No description provided for @driveConnectFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Connect failed.'**
  String get driveConnectFailedMessage;

  /// No description provided for @driveBackingUpMessage.
  ///
  /// In en, this message translates to:
  /// **'Backing up to Google Drive…'**
  String get driveBackingUpMessage;

  /// No description provided for @driveBackupSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Backup complete.'**
  String get driveBackupSuccessMessage;

  /// No description provided for @driveBackupFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Backup failed.'**
  String get driveBackupFailedMessage;

  /// No description provided for @addColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Color'**
  String get addColorTitle;

  /// No description provided for @colorPaletteTitle.
  ///
  /// In en, this message translates to:
  /// **'Color Palette'**
  String get colorPaletteTitle;

  /// No description provided for @hashtagsTitle.
  ///
  /// In en, this message translates to:
  /// **'Hashtags'**
  String get hashtagsTitle;

  /// No description provided for @editHashtagTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Hashtag'**
  String get editHashtagTitle;

  /// No description provided for @tagNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Tag Name'**
  String get tagNameLabel;

  /// No description provided for @removeColorConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove color?'**
  String get removeColorConfirmTitle;

  /// No description provided for @deleteHashtagConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete hashtag?'**
  String get deleteHashtagConfirmTitle;

  /// No description provided for @builderNavHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get builderNavHome;

  /// No description provided for @builderNavView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get builderNavView;

  /// No description provided for @builderNavFolders.
  ///
  /// In en, this message translates to:
  /// **'Folder Views'**
  String get builderNavFolders;

  /// No description provided for @viewModeTitle.
  ///
  /// In en, this message translates to:
  /// **'View mode'**
  String get viewModeTitle;

  /// No description provided for @viewModeList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get viewModeList;

  /// No description provided for @viewModeGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get viewModeGrid;

  /// No description provided for @viewModeCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get viewModeCompact;

  /// No description provided for @recentViewsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Views'**
  String get recentViewsTitle;

  /// No description provided for @recentViewsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recent views yet'**
  String get recentViewsEmpty;

  /// No description provided for @recentViewsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get recentViewsClear;

  /// No description provided for @builderNexusRootLabel.
  ///
  /// In en, this message translates to:
  /// **'Nexus root'**
  String get builderNexusRootLabel;

  // --- Supabase project setup (features/settings/supabase_setup_screen.dart) ---

  /// No description provided for @settingPageSupabase.
  ///
  /// In en, this message translates to:
  /// **'Supabase Project'**
  String get settingPageSupabase;

  /// No description provided for @sbIntro.
  ///
  /// In en, this message translates to:
  /// **'Use your own Supabase project as the Cloud Sync backend. Paste the project URL and publishable key, then let DraconDex check and install the tables it needs.'**
  String get sbIntro;

  /// No description provided for @sbUrl.
  ///
  /// In en, this message translates to:
  /// **'Project URL'**
  String get sbUrl;

  /// No description provided for @sbKey.
  ///
  /// In en, this message translates to:
  /// **'Publishable key'**
  String get sbKey;

  /// No description provided for @sbKeyStored.
  ///
  /// In en, this message translates to:
  /// **'A key is already saved — leave this empty to keep it.'**
  String get sbKeyStored;

  /// No description provided for @sbCheck.
  ///
  /// In en, this message translates to:
  /// **'Check project'**
  String get sbCheck;

  /// No description provided for @sbObjects.
  ///
  /// In en, this message translates to:
  /// **'Required tables & functions'**
  String get sbObjects;

  /// No description provided for @sbSchemaVersion.
  ///
  /// In en, this message translates to:
  /// **'Schema version'**
  String get sbSchemaVersion;

  /// No description provided for @sbReady.
  ///
  /// In en, this message translates to:
  /// **'Ready — this project has everything Cloud Sync needs.'**
  String get sbReady;

  /// No description provided for @sbNeedSetup.
  ///
  /// In en, this message translates to:
  /// **'Setup needed — some tables or functions are missing.'**
  String get sbNeedSetup;

  /// No description provided for @sbNotChecked.
  ///
  /// In en, this message translates to:
  /// **'Not checked yet. Save the settings above, then press Check project.'**
  String get sbNotChecked;

  /// No description provided for @sbAutoInstall.
  ///
  /// In en, this message translates to:
  /// **'Auto setup'**
  String get sbAutoInstall;

  /// No description provided for @sbAutoInstallHint.
  ///
  /// In en, this message translates to:
  /// **'A publishable key cannot create tables. Paste a Supabase personal access token and DraconDex will run the setup SQL for you.'**
  String get sbAutoInstallHint;

  /// No description provided for @sbAccessToken.
  ///
  /// In en, this message translates to:
  /// **'Personal access token'**
  String get sbAccessToken;

  /// No description provided for @sbAccessTokenHint.
  ///
  /// In en, this message translates to:
  /// **'Used for this one request only — never saved.'**
  String get sbAccessTokenHint;

  /// No description provided for @sbGetToken.
  ///
  /// In en, this message translates to:
  /// **'Get a token'**
  String get sbGetToken;

  /// No description provided for @sbManualTitle.
  ///
  /// In en, this message translates to:
  /// **'Or set it up by hand'**
  String get sbManualTitle;

  /// No description provided for @sbManualHint.
  ///
  /// In en, this message translates to:
  /// **'Copy the SQL, run it in your project SQL editor, then press Check project again.'**
  String get sbManualHint;

  /// No description provided for @sbCopySql.
  ///
  /// In en, this message translates to:
  /// **'Copy SQL'**
  String get sbCopySql;

  /// No description provided for @sbOpenSqlEditor.
  ///
  /// In en, this message translates to:
  /// **'Open SQL Editor'**
  String get sbOpenSqlEditor;

  /// No description provided for @sbOpenApiSettings.
  ///
  /// In en, this message translates to:
  /// **'Open API settings'**
  String get sbOpenApiSettings;

  /// No description provided for @sbOpenAuthProviders.
  ///
  /// In en, this message translates to:
  /// **'Open Auth providers'**
  String get sbOpenAuthProviders;

  /// No description provided for @sbGoogleOn.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in is enabled on this project.'**
  String get sbGoogleOn;

  /// No description provided for @sbGoogleOff.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in is off — turn it on under Authentication → Providers before signing in.'**
  String get sbGoogleOff;

  /// No description provided for @sbInstalled.
  ///
  /// In en, this message translates to:
  /// **'Setup complete'**
  String get sbInstalled;

  /// No description provided for @sbClear.
  ///
  /// In en, this message translates to:
  /// **'Remove project'**
  String get sbClear;

  /// No description provided for @sbClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove the saved Supabase project settings?'**
  String get sbClearConfirm;

  /// No description provided for @sbCleared.
  ///
  /// In en, this message translates to:
  /// **'Supabase settings removed'**
  String get sbCleared;

  /// No description provided for @sbErrNoConfig.
  ///
  /// In en, this message translates to:
  /// **'Enter the project URL and publishable key first.'**
  String get sbErrNoConfig;

  /// No description provided for @sbErrInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'That project URL is not valid — https only.'**
  String get sbErrInvalidUrl;

  /// No description provided for @sbErrBadKey.
  ///
  /// In en, this message translates to:
  /// **'The project rejected this key.'**
  String get sbErrBadKey;

  /// No description provided for @sbErrUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach that project.'**
  String get sbErrUnreachable;

  /// No description provided for @sbErrNeedsManual.
  ///
  /// In en, this message translates to:
  /// **'No access token — use the manual steps instead.'**
  String get sbErrNeedsManual;

  /// No description provided for @sbErrBadAccessToken.
  ///
  /// In en, this message translates to:
  /// **'That access token was rejected.'**
  String get sbErrBadAccessToken;

  /// No description provided for @sbErrForbidden.
  ///
  /// In en, this message translates to:
  /// **'This token is not allowed to change that project.'**
  String get sbErrForbidden;

  /// No description provided for @sbErrNoProjectRef.
  ///
  /// In en, this message translates to:
  /// **'Automatic setup needs a supabase.co project URL.'**
  String get sbErrNoProjectRef;

  /// No description provided for @sbErrRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests — try again in a moment.'**
  String get sbErrRateLimited;

  /// No description provided for @sbErrSqlError.
  ///
  /// In en, this message translates to:
  /// **'The setup SQL failed to run.'**
  String get sbErrSqlError;

  /// No description provided for @sbErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error — could not reach the project.'**
  String get sbErrNetwork;

  /// No description provided for @sbCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get sbCopied;

  /// No description provided for @sbNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'No project set up yet'**
  String get sbNotConfigured;
  /// No description provided for @googleAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Google account'**
  String get googleAccountTitle;

  /// No description provided for @googleAccountNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'No OAuth client set up yet'**
  String get googleAccountNotConfigured;

  /// No description provided for @googleAccountSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in setup'**
  String get googleAccountSetupTitle;

  /// No description provided for @googleClientTypeHintNative.
  ///
  /// In en, this message translates to:
  /// **'In Google Cloud Console, enable the Google Drive API and create an OAuth client of type "Desktop app", then paste its details below.'**
  String get googleClientTypeHintNative;

  /// No description provided for @googleClientTypeHintWeb.
  ///
  /// In en, this message translates to:
  /// **'In Google Cloud Console, enable the Google Drive API and create an OAuth client of type "Web application", then paste its client ID below.'**
  String get googleClientTypeHintWeb;

  /// No description provided for @googleClientIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Client ID'**
  String get googleClientIdLabel;

  /// No description provided for @googleClientSecretLabel.
  ///
  /// In en, this message translates to:
  /// **'Client secret'**
  String get googleClientSecretLabel;

  /// No description provided for @googleClientSecretKept.
  ///
  /// In en, this message translates to:
  /// **'A client secret is already saved. Leave this blank to keep it.'**
  String get googleClientSecretKept;

  /// No description provided for @googleRedirectUriLabel.
  ///
  /// In en, this message translates to:
  /// **'Authorized redirect URI'**
  String get googleRedirectUriLabel;

  /// No description provided for @googleRedirectUriHint.
  ///
  /// In en, this message translates to:
  /// **'Add this exact address to the client\'s authorized redirect URIs, and this site\'s address to its authorized JavaScript origins.'**
  String get googleRedirectUriHint;

  /// No description provided for @googleSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired — connect again'**
  String get googleSessionExpired;

  /// No description provided for @googleErrNoConfig.
  ///
  /// In en, this message translates to:
  /// **'Enter your OAuth client details first.'**
  String get googleErrNoConfig;

  /// No description provided for @googleErrCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sign-in was cancelled.'**
  String get googleErrCancelled;

  /// No description provided for @googleErrTimeout.
  ///
  /// In en, this message translates to:
  /// **'Sign-in timed out.'**
  String get googleErrTimeout;

  /// No description provided for @googleErrVerify.
  ///
  /// In en, this message translates to:
  /// **'The sign-in could not be verified. Please try again.'**
  String get googleErrVerify;

  /// No description provided for @googleErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not reach Google.'**
  String get googleErrNetwork;

  /// No description provided for @googleErrAuth.
  ///
  /// In en, this message translates to:
  /// **'Google refused the sign-in.'**
  String get googleErrAuth;

  /// No description provided for @googleErrPopupBlocked.
  ///
  /// In en, this message translates to:
  /// **'The sign-in window was blocked. Allow pop-ups for this site and try again.'**
  String get googleErrPopupBlocked;

  /// No description provided for @googleErrNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected to a Google account.'**
  String get googleErrNotConnected;

  /// No description provided for @driveRestoreSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore settings from Drive'**
  String get driveRestoreSettingsTitle;

  /// No description provided for @driveRestoreSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replaces theme, language and UI size with the backed-up ones.'**
  String get driveRestoreSettingsSubtitle;

  /// No description provided for @driveSettingsRestoredMessage.
  ///
  /// In en, this message translates to:
  /// **'Settings restored from Google Drive.'**
  String get driveSettingsRestoredMessage;

  /// No description provided for @driveNoBackupMessage.
  ///
  /// In en, this message translates to:
  /// **'No backup found on Google Drive.'**
  String get driveNoBackupMessage;

  /// No description provided for @driveWebDatabaseNote.
  ///
  /// In en, this message translates to:
  /// **'In the browser build only the settings are backed up — the database stays on this device.'**
  String get driveWebDatabaseNote;

  /// No description provided for @hubNestTitle.
  ///
  /// In en, this message translates to:
  /// **'Nexus Nest'**
  String get hubNestTitle;

  /// No description provided for @hubPanelShow.
  ///
  /// In en, this message translates to:
  /// **'Show hub panel'**
  String get hubPanelShow;

  /// No description provided for @hubPanelHide.
  ///
  /// In en, this message translates to:
  /// **'Hide hub panel'**
  String get hubPanelHide;

  /// No description provided for @railExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand rail'**
  String get railExpand;

  /// No description provided for @railCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse rail'**
  String get railCollapse;

  // --- DDX Transfer (features/settings/transfer_screen.dart) ---

  /// No description provided for @transferTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transferTitle;

  /// No description provided for @transferSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hand a whole Nexus to another device. No account and no setup — the sending device shows a code, the receiving one takes it, and the copy in between is deleted the moment it arrives.'**
  String get transferSubtitle;

  /// No description provided for @transferTabSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get transferTabSend;

  /// No description provided for @transferTabReceive.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get transferTabReceive;

  /// No description provided for @transferNexusLabel.
  ///
  /// In en, this message translates to:
  /// **'Nexus'**
  String get transferNexusLabel;

  /// No description provided for @transferPickNexus.
  ///
  /// In en, this message translates to:
  /// **'Open a Nexus to send it.'**
  String get transferPickNexus;

  /// No description provided for @transferAllowTyped.
  ///
  /// In en, this message translates to:
  /// **'Allow receiving by typed code'**
  String get transferAllowTyped;

  /// No description provided for @transferAllowTypedHint.
  ///
  /// In en, this message translates to:
  /// **'On, the other device can type the code and PIN, and the service holds the key sealed under that PIN while it waits. Off, the QR code is the only way in and the service cannot read the file at all.'**
  String get transferAllowTypedHint;

  /// No description provided for @transferCreate.
  ///
  /// In en, this message translates to:
  /// **'Create transfer'**
  String get transferCreate;

  /// No description provided for @transferCode.
  ///
  /// In en, this message translates to:
  /// **'Transfer code'**
  String get transferCode;

  /// No description provided for @transferPin.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get transferPin;

  /// No description provided for @transferCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get transferCopyLink;

  /// No description provided for @transferModeTyped.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR, or type the code and PIN. While this is waiting, the service holds the key sealed under the PIN.'**
  String get transferModeTyped;

  /// No description provided for @transferModeQr.
  ///
  /// In en, this message translates to:
  /// **'QR code only. The key never reaches the service, so nobody but the scanning device can open this.'**
  String get transferModeQr;

  /// No description provided for @transferExpiry.
  ///
  /// In en, this message translates to:
  /// **'This expires in 30 minutes, and is deleted the moment it is received.'**
  String get transferExpiry;

  /// No description provided for @transferWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the other device…'**
  String get transferWaiting;

  /// No description provided for @transferClaimed.
  ///
  /// In en, this message translates to:
  /// **'The other device has verified the code and is downloading…'**
  String get transferClaimed;

  /// No description provided for @transferDone.
  ///
  /// In en, this message translates to:
  /// **'Received. The copy on the service has been deleted.'**
  String get transferDone;

  /// No description provided for @transferExpiredNotice.
  ///
  /// In en, this message translates to:
  /// **'This expired before it was received.'**
  String get transferExpiredNotice;

  /// No description provided for @transferVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get transferVerify;

  /// No description provided for @transferFound.
  ///
  /// In en, this message translates to:
  /// **'Transfer found'**
  String get transferFound;

  /// No description provided for @transferProject.
  ///
  /// In en, this message translates to:
  /// **'Nexus'**
  String get transferProject;

  /// No description provided for @transferSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get transferSize;

  /// No description provided for @transferCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get transferCreated;

  /// No description provided for @transferSource.
  ///
  /// In en, this message translates to:
  /// **'Sent from'**
  String get transferSource;

  /// No description provided for @transferReceiveAsNew.
  ///
  /// In en, this message translates to:
  /// **'This arrives as a new Nexus. Nothing you already have is touched.'**
  String get transferReceiveAsNew;

  /// No description provided for @transferReceiveAction.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get transferReceiveAction;

  /// No description provided for @transferReceived.
  ///
  /// In en, this message translates to:
  /// **'Nexus received'**
  String get transferReceived;

  /// No description provided for @transferErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the transfer service.'**
  String get transferErrNetwork;

  /// No description provided for @transferErrBadCode.
  ///
  /// In en, this message translates to:
  /// **'That transfer code or PIN is not right.'**
  String get transferErrBadCode;

  /// No description provided for @transferErrLocked.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong PINs. This transfer is locked for a while.'**
  String get transferErrLocked;

  /// No description provided for @transferErrExpired.
  ///
  /// In en, this message translates to:
  /// **'This transfer has expired. Ask for a new code.'**
  String get transferErrExpired;

  /// No description provided for @transferErrGone.
  ///
  /// In en, this message translates to:
  /// **'This transfer no longer exists — it was received or cancelled.'**
  String get transferErrGone;

  /// No description provided for @transferErrNotReady.
  ///
  /// In en, this message translates to:
  /// **'The other device has not finished uploading yet.'**
  String get transferErrNotReady;

  /// No description provided for @transferErrTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This Nexus is larger than a single transfer allows.'**
  String get transferErrTooLarge;

  /// No description provided for @transferErrBadToken.
  ///
  /// In en, this message translates to:
  /// **'This transfer session is no longer valid. Start again.'**
  String get transferErrBadToken;

  /// No description provided for @transferErrBadKey.
  ///
  /// In en, this message translates to:
  /// **'That link is incomplete — the key part is missing or damaged.'**
  String get transferErrBadKey;

  /// No description provided for @transferErrQrOnly.
  ///
  /// In en, this message translates to:
  /// **'The sender allowed the QR code only. Scan it instead of typing.'**
  String get transferErrQrOnly;

  /// No description provided for @transferErrBadPayload.
  ///
  /// In en, this message translates to:
  /// **'The received file could not be read.'**
  String get transferErrBadPayload;

  /// No description provided for @transferErrServer.
  ///
  /// In en, this message translates to:
  /// **'The transfer service had a problem.'**
  String get transferErrServer;

  /// No description provided for @transferSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get transferSending;

  /// No description provided for @transferCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get transferCopied;

  /// No description provided for @transferCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get transferCancel;

  /// No description provided for @transferPasteLink.
  ///
  /// In en, this message translates to:
  /// **'Or paste a transfer link'**
  String get transferPasteLink;

  /// No description provided for @transferPasteLinkHint.
  ///
  /// In en, this message translates to:
  /// **'A link carries the key in it, so it works even when the sender allowed the QR code only.'**
  String get transferPasteLinkHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'id',
    'ja',
    'ko',
    'pt',
    'qd',
    'ru',
    'th',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'id':
      return AppLocalizationsId();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'pt':
      return AppLocalizationsPt();
    case 'qd':
      return AppLocalizationsQd();
    case 'ru':
      return AppLocalizationsRu();
    case 'th':
      return AppLocalizationsTh();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
