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
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_qd.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_th.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_uk.dart';
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
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('nl'),
    Locale('pl'),
    Locale('pt'),
    Locale('qd'),
    Locale('ru'),
    Locale('th'),
    Locale('tr'),
    Locale('uk'),
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
  /// No description provided for @navNest.
  ///
  /// In en, this message translates to:
  /// **'Nest'**
  String get navNest;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navOpenPages.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get navOpenPages;

  /// No description provided for @navTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get navTools;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @openPagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Open pages'**
  String get openPagesTitle;

  /// No description provided for @openPagesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pages open. Every page you open stays here until you close it.'**
  String get openPagesEmpty;

  /// No description provided for @openPagesCloseAll.
  ///
  /// In en, this message translates to:
  /// **'Close all'**
  String get openPagesCloseAll;

  /// No description provided for @openPageClose.
  ///
  /// In en, this message translates to:
  /// **'Close page'**
  String get openPageClose;

  /// No description provided for @rowOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get rowOpen;

  /// No description provided for @rowMore.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get rowMore;

  /// No description provided for @crumbEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing inside'**
  String get crumbEmpty;

  /// No description provided for @goToTitle.
  ///
  /// In en, this message translates to:
  /// **'Go to'**
  String get goToTitle;

  /// No description provided for @goToHint.
  ///
  /// In en, this message translates to:
  /// **'A name, a path or @handle'**
  String get goToHint;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search names, text and commands'**
  String get searchHint;

  /// No description provided for @searchThings.
  ///
  /// In en, this message translates to:
  /// **'Things'**
  String get searchThings;

  /// No description provided for @searchContent.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get searchContent;

  /// No description provided for @searchCommands.
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get searchCommands;

  /// No description provided for @searchEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches'**
  String get searchEmpty;

  /// No description provided for @elementPageSoon.
  ///
  /// In en, this message translates to:
  /// **'This element gets its own page in a coming update. For now it opens inside its module.'**
  String get elementPageSoon;

  /// No description provided for @wikiUnresolved.
  ///
  /// In en, this message translates to:
  /// **'Nothing has this name yet. Make a Drafter page for it?'**
  String get wikiUnresolved;

  /// No description provided for @wikiCreateDrafter.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get wikiCreateDrafter;

  /// No description provided for @btnUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get btnUndo;

  /// No description provided for @pbAddBlock.
  ///
  /// In en, this message translates to:
  /// **'Add block'**
  String get pbAddBlock;

  /// No description provided for @pbAddHere.
  ///
  /// In en, this message translates to:
  /// **'Add here'**
  String get pbAddHere;

  /// No description provided for @pbAddProperty.
  ///
  /// In en, this message translates to:
  /// **'Add property'**
  String get pbAddProperty;

  /// No description provided for @pbArrange.
  ///
  /// In en, this message translates to:
  /// **'Arrange page'**
  String get pbArrange;

  /// No description provided for @pbArrangeDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get pbArrangeDone;

  /// No description provided for @pbArrangeHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder. A column block moves as one.'**
  String get pbArrangeHint;

  /// No description provided for @pbArrangeShared.
  ///
  /// In en, this message translates to:
  /// **'This is the layout every element of this module shares. Split the page off first to change only this one.'**
  String get pbArrangeShared;

  /// No description provided for @pbBacklinks.
  ///
  /// In en, this message translates to:
  /// **'Linked from'**
  String get pbBacklinks;

  /// No description provided for @pbBlockDeleted.
  ///
  /// In en, this message translates to:
  /// **'Block removed'**
  String get pbBlockDeleted;

  /// No description provided for @pbBorrow.
  ///
  /// In en, this message translates to:
  /// **'A view from another module'**
  String get pbBorrow;

  /// No description provided for @pbColumn.
  ///
  /// In en, this message translates to:
  /// **'Column'**
  String get pbColumn;

  /// No description provided for @pbColumns.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get pbColumns;

  /// No description provided for @pbDivider.
  ///
  /// In en, this message translates to:
  /// **'Divider'**
  String get pbDivider;

  /// No description provided for @pbFullScreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get pbFullScreen;

  /// No description provided for @pbHeading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get pbHeading;

  /// No description provided for @pbImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get pbImage;

  /// No description provided for @pbItemBody.
  ///
  /// In en, this message translates to:
  /// **'Element'**
  String get pbItemBody;

  /// No description provided for @pbItemEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing written here yet.'**
  String get pbItemEmpty;

  /// No description provided for @pbNoRelated.
  ///
  /// In en, this message translates to:
  /// **'No links yet'**
  String get pbNoRelated;

  /// No description provided for @pbNotOnMobile.
  ///
  /// In en, this message translates to:
  /// **'not in this app yet'**
  String get pbNotOnMobile;

  /// No description provided for @pbOnlyOnce.
  ///
  /// In en, this message translates to:
  /// **'can be on a page only once'**
  String get pbOnlyOnce;

  /// No description provided for @pbOpenFullScreen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get pbOpenFullScreen;

  /// No description provided for @pbOutgoing.
  ///
  /// In en, this message translates to:
  /// **'Links to'**
  String get pbOutgoing;

  /// No description provided for @pbPropName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get pbPropName;

  /// No description provided for @pbPropType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get pbPropType;

  /// No description provided for @pbProperties.
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get pbProperties;

  /// No description provided for @pbRelated.
  ///
  /// In en, this message translates to:
  /// **'Related'**
  String get pbRelated;

  /// No description provided for @pbRelations.
  ///
  /// In en, this message translates to:
  /// **'Relations'**
  String get pbRelations;

  /// No description provided for @pbRevert.
  ///
  /// In en, this message translates to:
  /// **'Back to the shared layout'**
  String get pbRevert;

  /// No description provided for @pbSharedLayout.
  ///
  /// In en, this message translates to:
  /// **'The shared layout of every element page of this module.'**
  String get pbSharedLayout;

  /// No description provided for @pbSourceGone.
  ///
  /// In en, this message translates to:
  /// **'what this showed is gone'**
  String get pbSourceGone;

  /// No description provided for @pbSplit.
  ///
  /// In en, this message translates to:
  /// **'Give this page its own layout'**
  String get pbSplit;

  /// No description provided for @pbTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get pbTags;

  /// No description provided for @pbText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get pbText;

  /// No description provided for @pbTextEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty text — tap to write'**
  String get pbTextEmpty;

  /// No description provided for @propTypeCheckbox.
  ///
  /// In en, this message translates to:
  /// **'Checkbox'**
  String get propTypeCheckbox;

  /// No description provided for @propTypeDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get propTypeDate;

  /// No description provided for @propTypeNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get propTypeNumber;

  /// No description provided for @propTypeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get propTypeText;

  /// No description provided for @propTypeTextarea.
  ///
  /// In en, this message translates to:
  /// **'Long text'**
  String get propTypeTextarea;

  /// No description provided for @propTypeUrl.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get propTypeUrl;

  /// No description provided for @viewTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get viewTable;

  /// No description provided for @viewListDetail.
  ///
  /// In en, this message translates to:
  /// **'List · detail'**
  String get viewListDetail;

  /// No description provided for @viewRelations.
  ///
  /// In en, this message translates to:
  /// **'Relations'**
  String get viewRelations;

  /// No description provided for @viewGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get viewGrid;

  /// No description provided for @viewScene.
  ///
  /// In en, this message translates to:
  /// **'Scene'**
  String get viewScene;

  /// No description provided for @viewGraph.
  ///
  /// In en, this message translates to:
  /// **'Graph'**
  String get viewGraph;

  /// No description provided for @viewCards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get viewCards;

  /// No description provided for @viewBoard.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get viewBoard;

  /// No description provided for @viewEdges.
  ///
  /// In en, this message translates to:
  /// **'Edges'**
  String get viewEdges;

  /// No description provided for @viewArea.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get viewArea;

  /// No description provided for @viewMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get viewMap;

  /// No description provided for @viewTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get viewTimeline;

  /// No description provided for @viewCanvas.
  ///
  /// In en, this message translates to:
  /// **'Canvas'**
  String get viewCanvas;

  /// No description provided for @viewPages.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get viewPages;

  /// No description provided for @viewGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get viewGallery;

  /// No description provided for @viewExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get viewExport;

  /// No description provided for @viewEditor.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get viewEditor;

  /// No description provided for @viewOutline.
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get viewOutline;

  /// No description provided for @viewReading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get viewReading;

  /// No description provided for @viewBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get viewBook;

  /// No description provided for @viewRoutes.
  ///
  /// In en, this message translates to:
  /// **'Routes'**
  String get viewRoutes;

  /// No description provided for @viewReader.
  ///
  /// In en, this message translates to:
  /// **'Reader'**
  String get viewReader;

  /// No description provided for @viewDialogue.
  ///
  /// In en, this message translates to:
  /// **'Dialogue'**
  String get viewDialogue;

  /// No description provided for @viewOneline.
  ///
  /// In en, this message translates to:
  /// **'One line'**
  String get viewOneline;

  /// No description provided for @viewDownline.
  ///
  /// In en, this message translates to:
  /// **'Down the page'**
  String get viewDownline;

  /// No description provided for @viewCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get viewCompare;

  /// No description provided for @viewCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get viewCalendar;

  /// No description provided for @viewList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get viewList;

  /// No description provided for @viewMatrix.
  ///
  /// In en, this message translates to:
  /// **'Matrix'**
  String get viewMatrix;

  /// No description provided for @viewChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get viewChat;

  /// No description provided for @viewTranscript.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get viewTranscript;

  /// No description provided for @clsNoRelations.
  ///
  /// In en, this message translates to:
  /// **'No links between these elements yet'**
  String get clsNoRelations;

  /// No description provided for @clsTypeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get clsTypeText;

  /// No description provided for @clsTypeTextarea.
  ///
  /// In en, this message translates to:
  /// **'Long text'**
  String get clsTypeTextarea;

  /// No description provided for @clsTypeNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get clsTypeNumber;

  /// No description provided for @clsTypeDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get clsTypeDate;

  /// No description provided for @clsTypeSelect.
  ///
  /// In en, this message translates to:
  /// **'Choice'**
  String get clsTypeSelect;

  /// No description provided for @clsTypeMulti.
  ///
  /// In en, this message translates to:
  /// **'Multiple choice'**
  String get clsTypeMulti;

  /// No description provided for @clsTypeCheckbox.
  ///
  /// In en, this message translates to:
  /// **'Checkbox'**
  String get clsTypeCheckbox;

  /// No description provided for @clsTypeUrl.
  ///
  /// In en, this message translates to:
  /// **'Link (URL)'**
  String get clsTypeUrl;

  /// No description provided for @clsTypeRelation.
  ///
  /// In en, this message translates to:
  /// **'Relation'**
  String get clsTypeRelation;

  /// No description provided for @clsTypeFormula.
  ///
  /// In en, this message translates to:
  /// **'Formula'**
  String get clsTypeFormula;

  /// No description provided for @clsFieldType.
  ///
  /// In en, this message translates to:
  /// **'Field type'**
  String get clsFieldType;

  /// No description provided for @clsChoices.
  ///
  /// In en, this message translates to:
  /// **'Choices (one per line)'**
  String get clsChoices;

  /// No description provided for @clsFormulaHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. {HP} * 2'**
  String get clsFormulaHint;

  /// No description provided for @clsEditField.
  ///
  /// In en, this message translates to:
  /// **'Edit field'**
  String get clsEditField;

  /// No description provided for @clsAddLink.
  ///
  /// In en, this message translates to:
  /// **'Add a link'**
  String get clsAddLink;

  /// No description provided for @dateDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get dateDay;

  /// No description provided for @dateMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get dateMonth;

  /// No description provided for @dateYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get dateYear;

  /// No description provided for @dateHour.
  ///
  /// In en, this message translates to:
  /// **'Hour'**
  String get dateHour;

  /// No description provided for @dateMinute.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get dateMinute;

  /// No description provided for @btnClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get btnClear;

  /// No description provided for @groupBy.
  ///
  /// In en, this message translates to:
  /// **'Group by'**
  String get groupBy;

  /// No description provided for @groupModule.
  ///
  /// In en, this message translates to:
  /// **'Module'**
  String get groupModule;

  /// No description provided for @relDirected.
  ///
  /// In en, this message translates to:
  /// **'One direction (→)'**
  String get relDirected;

  /// No description provided for @exhGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get exhGroup;

  /// No description provided for @exhNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get exhNote;

  /// No description provided for @exhAddElement.
  ///
  /// In en, this message translates to:
  /// **'Place an element'**
  String get exhAddElement;

  /// No description provided for @exhAddNote.
  ///
  /// In en, this message translates to:
  /// **'Add a note'**
  String get exhAddNote;

  /// No description provided for @exhAddGroup.
  ///
  /// In en, this message translates to:
  /// **'Add a group'**
  String get exhAddGroup;

  /// No description provided for @exhRemoveFromScene.
  ///
  /// In en, this message translates to:
  /// **'Remove from the scene'**
  String get exhRemoveFromScene;

  /// No description provided for @exhSceneEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing placed yet — place an element or add a note.'**
  String get exhSceneEmpty;

  /// No description provided for @auStatusIdea.
  ///
  /// In en, this message translates to:
  /// **'Idea'**
  String get auStatusIdea;

  /// No description provided for @auStatusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get auStatusDraft;

  /// No description provided for @auStatusRevised.
  ///
  /// In en, this message translates to:
  /// **'Revised'**
  String get auStatusRevised;

  /// No description provided for @auStatusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get auStatusDone;

  /// No description provided for @auSynopsis.
  ///
  /// In en, this message translates to:
  /// **'Synopsis'**
  String get auSynopsis;

  /// No description provided for @auPov.
  ///
  /// In en, this message translates to:
  /// **'Point of view'**
  String get auPov;

  /// No description provided for @btnPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get btnPrevious;

  /// No description provided for @btnNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get btnNext;

  /// No description provided for @narAddRoute.
  ///
  /// In en, this message translates to:
  /// **'Add route'**
  String get narAddRoute;

  /// No description provided for @narScript.
  ///
  /// In en, this message translates to:
  /// **'Script'**
  String get narScript;

  /// No description provided for @narPlayTest.
  ///
  /// In en, this message translates to:
  /// **'Play-test'**
  String get narPlayTest;

  /// No description provided for @narRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get narRestart;

  /// No description provided for @narShowHidden.
  ///
  /// In en, this message translates to:
  /// **'Show hidden options'**
  String get narShowHidden;

  /// No description provided for @narVariables.
  ///
  /// In en, this message translates to:
  /// **'Variables'**
  String get narVariables;

  /// No description provided for @narNoVariables.
  ///
  /// In en, this message translates to:
  /// **'No story variables in this Nexus'**
  String get narNoVariables;

  /// No description provided for @narPlayEnd.
  ///
  /// In en, this message translates to:
  /// **'The end — no route leads on.'**
  String get narPlayEnd;

  /// No description provided for @narNoOptionOpen.
  ///
  /// In en, this message translates to:
  /// **'No option is open with these variables.'**
  String get narNoOptionOpen;

  /// No description provided for @narHiddenByCondition.
  ///
  /// In en, this message translates to:
  /// **'hidden by its condition'**
  String get narHiddenByCondition;

  /// No description provided for @chrCompareWith.
  ///
  /// In en, this message translates to:
  /// **'Compare with'**
  String get chrCompareWith;

  /// No description provided for @chrNoOtherLine.
  ///
  /// In en, this message translates to:
  /// **'No other Chronicler in this Nexus to compare with'**
  String get chrNoOtherLine;

  /// No description provided for @scribeNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get scribeNoMessages;

  /// No description provided for @wndLocator.
  ///
  /// In en, this message translates to:
  /// **'Map (Locator)'**
  String get wndLocator;

  /// No description provided for @wndNoLocator.
  ///
  /// In en, this message translates to:
  /// **'No Locator in this Nexus yet — its areas are what pins stand in.'**
  String get wndNoLocator;

  /// No description provided for @wndPickLocator.
  ///
  /// In en, this message translates to:
  /// **'Pick the Locator whose areas these pins stand in.'**
  String get wndPickLocator;

  /// No description provided for @wndNoAreas.
  ///
  /// In en, this message translates to:
  /// **'That Locator has no areas yet'**
  String get wndNoAreas;

  /// No description provided for @wndAddPin.
  ///
  /// In en, this message translates to:
  /// **'Put a pin here'**
  String get wndAddPin;

  /// No description provided for @skExportPng.
  ///
  /// In en, this message translates to:
  /// **'Share as PNG'**
  String get skExportPng;

  /// No description provided for @dgPanel.
  ///
  /// In en, this message translates to:
  /// **'Panel (comic)'**
  String get dgPanel;

  /// No description provided for @dgBalloon.
  ///
  /// In en, this message translates to:
  /// **'Speech balloon'**
  String get dgBalloon;

  /// No description provided for @dgLinkFrom.
  ///
  /// In en, this message translates to:
  /// **'Connect to…'**
  String get dgLinkFrom;

  /// No description provided for @dgPanelShows.
  ///
  /// In en, this message translates to:
  /// **'Show a Sketcher page'**
  String get dgPanelShows;

  /// No description provided for @dgBalloonSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Who speaks'**
  String get dgBalloonSpeaker;

  /// No description provided for @dgNumberByPosition.
  ///
  /// In en, this message translates to:
  /// **'Number by position'**
  String get dgNumberByPosition;

  /// No description provided for @dgShowOrder.
  ///
  /// In en, this message translates to:
  /// **'Show reading order'**
  String get dgShowOrder;

  /// No description provided for @divNewTable.
  ///
  /// In en, this message translates to:
  /// **'New table'**
  String get divNewTable;

  /// No description provided for @divDice.
  ///
  /// In en, this message translates to:
  /// **'Dice'**
  String get divDice;

  /// No description provided for @divDiceHelp.
  ///
  /// In en, this message translates to:
  /// **'Empty = weighted'**
  String get divDiceHelp;

  /// No description provided for @divBadDice.
  ///
  /// In en, this message translates to:
  /// **'Not a dice expression'**
  String get divBadDice;

  /// No description provided for @divModePick.
  ///
  /// In en, this message translates to:
  /// **'Pick one'**
  String get divModePick;

  /// No description provided for @divModeJoin.
  ///
  /// In en, this message translates to:
  /// **'Join all'**
  String get divModeJoin;

  /// No description provided for @divWeighted.
  ///
  /// In en, this message translates to:
  /// **'Weighted'**
  String get divWeighted;

  /// No description provided for @divEntryText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get divEntryText;

  /// No description provided for @divFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get divFrom;

  /// No description provided for @divTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get divTo;

  /// No description provided for @divWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get divWeight;

  /// No description provided for @divRollsTable.
  ///
  /// In en, this message translates to:
  /// **'Roll another table here'**
  String get divRollsTable;

  /// No description provided for @divLinkEntity.
  ///
  /// In en, this message translates to:
  /// **'Name something'**
  String get divLinkEntity;

  /// No description provided for @divUnlink.
  ///
  /// In en, this message translates to:
  /// **'Remove the link'**
  String get divUnlink;

  /// No description provided for @divNoTables.
  ///
  /// In en, this message translates to:
  /// **'No tables yet'**
  String get divNoTables;

  /// No description provided for @divRoll.
  ///
  /// In en, this message translates to:
  /// **'Roll'**
  String get divRoll;

  /// No description provided for @divEntries.
  ///
  /// In en, this message translates to:
  /// **'Entries'**
  String get divEntries;

  /// No description provided for @divNoEntries.
  ///
  /// In en, this message translates to:
  /// **'No entries yet'**
  String get divNoEntries;

  /// No description provided for @divHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get divHistory;

  /// No description provided for @divQuickRoll.
  ///
  /// In en, this message translates to:
  /// **'Just roll: 3d6'**
  String get divQuickRoll;

  /// No description provided for @trashTitle.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get trashTitle;

  /// No description provided for @trashMoved.
  ///
  /// In en, this message translates to:
  /// **'Moved to the Trash'**
  String get trashMoved;

  /// No description provided for @trashEmptyAll.
  ///
  /// In en, this message translates to:
  /// **'Empty the Trash'**
  String get trashEmptyAll;

  /// No description provided for @trashEmptyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Everything in the Trash is deleted for good.'**
  String get trashEmptyConfirm;

  /// No description provided for @trashNothing.
  ///
  /// In en, this message translates to:
  /// **'The Trash is empty'**
  String get trashNothing;

  /// No description provided for @trashNote.
  ///
  /// In en, this message translates to:
  /// **'A restored module comes back with everything that was in it and its relations — but not its version history.'**
  String get trashNote;

  /// No description provided for @trashRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get trashRestore;

  /// No description provided for @trashModules.
  ///
  /// In en, this message translates to:
  /// **'modules'**
  String get trashModules;

  /// No description provided for @trashDeleteForever.
  ///
  /// In en, this message translates to:
  /// **'Delete this for good? It cannot be restored after this.'**
  String get trashDeleteForever;

  /// No description provided for @problemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Problems'**
  String get problemsTitle;

  /// No description provided for @problemsLinks.
  ///
  /// In en, this message translates to:
  /// **'Unresolved links'**
  String get problemsLinks;

  /// No description provided for @problemsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty modules'**
  String get problemsEmpty;

  /// No description provided for @problemsRelations.
  ///
  /// In en, this message translates to:
  /// **'Relations with a missing end'**
  String get problemsRelations;

  /// No description provided for @problemsNone.
  ///
  /// In en, this message translates to:
  /// **'No problems found'**
  String get problemsNone;

  /// No description provided for @assetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get assetsTitle;

  /// No description provided for @assetsFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Add from this device'**
  String get assetsFromDevice;

  /// No description provided for @assetsAddUrl.
  ///
  /// In en, this message translates to:
  /// **'Add a link (URL)'**
  String get assetsAddUrl;

  /// No description provided for @assetsNotice.
  ///
  /// In en, this message translates to:
  /// **'Assets stay on this device: sync carries their names, not the files.'**
  String get assetsNotice;

  /// No description provided for @assetsNone.
  ///
  /// In en, this message translates to:
  /// **'No assets yet'**
  String get assetsNone;

  /// No description provided for @assetsTooBig.
  ///
  /// In en, this message translates to:
  /// **'Too big to keep in the browser'**
  String get assetsTooBig;

  /// No description provided for @pbChooseImage.
  ///
  /// In en, this message translates to:
  /// **'Choose an image'**
  String get pbChooseImage;

  /// No description provided for @csvImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import a CSV'**
  String get csvImportTitle;

  /// No description provided for @fromTemplate.
  ///
  /// In en, this message translates to:
  /// **'From a template'**
  String get fromTemplate;

  /// No description provided for @guideTitle.
  ///
  /// In en, this message translates to:
  /// **'The guide'**
  String get guideTitle;

  /// No description provided for @guideDesc.
  ///
  /// In en, this message translates to:
  /// **'A small working world that shows every kind'**
  String get guideDesc;

  /// No description provided for @guideAdd.
  ///
  /// In en, this message translates to:
  /// **'Add the guide'**
  String get guideAdd;

  /// No description provided for @mddxImport.
  ///
  /// In en, this message translates to:
  /// **'Import a module file (.mddx)'**
  String get mddxImport;

  /// No description provided for @mddxExport.
  ///
  /// In en, this message translates to:
  /// **'Export as .mddx'**
  String get mddxExport;

  /// No description provided for @mddxNotModule.
  ///
  /// In en, this message translates to:
  /// **'That file is not a DraconDex module'**
  String get mddxNotModule;

  /// No description provided for @kindCatStructure.
  ///
  /// In en, this message translates to:
  /// **'Structure'**
  String get kindCatStructure;

  /// No description provided for @kindCatView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get kindCatView;

  /// No description provided for @kindCatData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get kindCatData;

  /// No description provided for @kindGroupNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes & documents'**
  String get kindGroupNotes;

  /// No description provided for @kindGroupData.
  ///
  /// In en, this message translates to:
  /// **'Data & categories'**
  String get kindGroupData;

  /// No description provided for @kindGroupMapTime.
  ///
  /// In en, this message translates to:
  /// **'Maps & time'**
  String get kindGroupMapTime;

  /// No description provided for @kindGroupStory.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get kindGroupStory;

  /// No description provided for @kindGroupDraw.
  ///
  /// In en, this message translates to:
  /// **'Drawing & design'**
  String get kindGroupDraw;

  /// No description provided for @nexusStartWith.
  ///
  /// In en, this message translates to:
  /// **'Start with'**
  String get nexusStartWith;

  /// No description provided for @nexusStartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing — an empty Nexus'**
  String get nexusStartEmpty;

  /// No description provided for @csvPick.
  ///
  /// In en, this message translates to:
  /// **'Choose a CSV file'**
  String get csvPick;

  /// No description provided for @csvHint.
  ///
  /// In en, this message translates to:
  /// **'The first row names the fields, the first column names the elements.'**
  String get csvHint;

  /// No description provided for @csvCreate.
  ///
  /// In en, this message translates to:
  /// **'Create the Classifier'**
  String get csvCreate;

  /// No description provided for @csvSkip.
  ///
  /// In en, this message translates to:
  /// **'Leave out'**
  String get csvSkip;

  /// No description provided for @csvNameColumn.
  ///
  /// In en, this message translates to:
  /// **'Names'**
  String get csvNameColumn;

  /// No description provided for @csvTruncated.
  ///
  /// In en, this message translates to:
  /// **'only the first 5,000 rows'**
  String get csvTruncated;

  /// No description provided for @csvTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That file is over 8 MB'**
  String get csvTooLarge;

  /// No description provided for @csvEmpty.
  ///
  /// In en, this message translates to:
  /// **'No rows to import — a header and at least one row are needed'**
  String get csvEmpty;

  /// No description provided for @kindClassicCollector.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get kindClassicCollector;

  /// No description provided for @kindDescCollector.
  ///
  /// In en, this message translates to:
  /// **'Folder that groups other modules'**
  String get kindDescCollector;

  /// No description provided for @kindClassicManager.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get kindClassicManager;

  /// No description provided for @kindDescManager.
  ///
  /// In en, this message translates to:
  /// **'Browse child modules as cards, list or table'**
  String get kindDescManager;

  /// No description provided for @kindClassicInspector.
  ///
  /// In en, this message translates to:
  /// **'Detail'**
  String get kindClassicInspector;

  /// No description provided for @kindDescInspector.
  ///
  /// In en, this message translates to:
  /// **'One note page for this item'**
  String get kindDescInspector;

  /// No description provided for @kindClassicClassifier.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get kindClassicClassifier;

  /// No description provided for @kindDescClassifier.
  ///
  /// In en, this message translates to:
  /// **'Categorize items with custom fields'**
  String get kindDescClassifier;

  /// No description provided for @kindClassicLocator.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get kindClassicLocator;

  /// No description provided for @kindDescLocator.
  ///
  /// In en, this message translates to:
  /// **'Map with pins and areas'**
  String get kindDescLocator;

  /// No description provided for @kindClassicChronicler.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get kindClassicChronicler;

  /// No description provided for @kindDescChronicler.
  ///
  /// In en, this message translates to:
  /// **'Timeline of dated events'**
  String get kindDescChronicler;

  /// No description provided for @kindClassicWanderer.
  ///
  /// In en, this message translates to:
  /// **'TimeMap'**
  String get kindClassicWanderer;

  /// No description provided for @kindDescWanderer.
  ///
  /// In en, this message translates to:
  /// **'Map pins linked to timeline events'**
  String get kindDescWanderer;

  /// No description provided for @kindClassicNarrator.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get kindClassicNarrator;

  /// No description provided for @kindDescNarrator.
  ///
  /// In en, this message translates to:
  /// **'Dialogue nodes on a connected route board'**
  String get kindDescNarrator;

  /// No description provided for @kindClassicAuthor.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get kindClassicAuthor;

  /// No description provided for @kindDescAuthor.
  ///
  /// In en, this message translates to:
  /// **'Book with chapters and a writing editor'**
  String get kindDescAuthor;

  /// No description provided for @kindClassicScribe.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get kindClassicScribe;

  /// No description provided for @kindDescScribe.
  ///
  /// In en, this message translates to:
  /// **'Chat-style session notes'**
  String get kindDescScribe;

  /// No description provided for @kindClassicDrafter.
  ///
  /// In en, this message translates to:
  /// **'Doc'**
  String get kindClassicDrafter;

  /// No description provided for @kindDescDrafter.
  ///
  /// In en, this message translates to:
  /// **'Blank markdown page'**
  String get kindDescDrafter;

  /// No description provided for @kindClassicExhibitor.
  ///
  /// In en, this message translates to:
  /// **'Exhibit'**
  String get kindClassicExhibitor;

  /// No description provided for @kindDescExhibitor.
  ///
  /// In en, this message translates to:
  /// **'Scene, graph and tables of linked items — where relations are drawn'**
  String get kindDescExhibitor;

  /// No description provided for @kindClassicSketcher.
  ///
  /// In en, this message translates to:
  /// **'Drawing'**
  String get kindClassicSketcher;

  /// No description provided for @kindDescSketcher.
  ///
  /// In en, this message translates to:
  /// **'Freehand drawing canvas'**
  String get kindDescSketcher;

  /// No description provided for @kindClassicDesigner.
  ///
  /// In en, this message translates to:
  /// **'Graph'**
  String get kindClassicDesigner;

  /// No description provided for @kindDescDesigner.
  ///
  /// In en, this message translates to:
  /// **'Free-form diagram with shapes and arrows'**
  String get kindDescDesigner;

  /// No description provided for @kindClassicDiviner.
  ///
  /// In en, this message translates to:
  /// **'Random table'**
  String get kindClassicDiviner;

  /// No description provided for @kindDescDiviner.
  ///
  /// In en, this message translates to:
  /// **'Random tables and dice rolls'**
  String get kindDescDiviner;

  /// No description provided for @moduleNameMode.
  ///
  /// In en, this message translates to:
  /// **'Module names'**
  String get moduleNameMode;

  /// No description provided for @moduleNameModeHint.
  ///
  /// In en, this message translates to:
  /// **'Unique = Collector/Manager/… · Classic = Folder/Project/…'**
  String get moduleNameModeHint;

  /// No description provided for @moduleInside.
  ///
  /// In en, this message translates to:
  /// **'inside'**
  String get moduleInside;

  /// No description provided for @nameModeUnique.
  ///
  /// In en, this message translates to:
  /// **'Unique'**
  String get nameModeUnique;

  /// No description provided for @nameModeClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get nameModeClassic;

  /// No description provided for @kindRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get kindRecent;

  /// No description provided for @clsLevelable.
  ///
  /// In en, this message translates to:
  /// **'Levelable'**
  String get clsLevelable;

  /// No description provided for @clsCondition.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get clsCondition;

  /// No description provided for @levelColLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get levelColLevel;

  /// No description provided for @levelColInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get levelColInfo;

  /// No description provided for @levelAddRow.
  ///
  /// In en, this message translates to:
  /// **'Add row'**
  String get levelAddRow;

  /// No description provided for @levelNoRows.
  ///
  /// In en, this message translates to:
  /// **'No rows yet'**
  String get levelNoRows;

  /// No description provided for @confirmDeleteLevelRow.
  ///
  /// In en, this message translates to:
  /// **'Delete this row?'**
  String get confirmDeleteLevelRow;

  /// No description provided for @clsLevelAndCondition.
  ///
  /// In en, this message translates to:
  /// **'Level & Condition'**
  String get clsLevelAndCondition;

  /// No description provided for @clsLevelAndConditionHint.
  ///
  /// In en, this message translates to:
  /// **'Turn a field into a table of rows (levels), or tie its value to a condition.'**
  String get clsLevelAndConditionHint;

  /// No description provided for @clsInsertAbove.
  ///
  /// In en, this message translates to:
  /// **'Insert row above'**
  String get clsInsertAbove;

  /// No description provided for @clsInsertBelow.
  ///
  /// In en, this message translates to:
  /// **'Insert row below'**
  String get clsInsertBelow;

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
    'it',
    'ja',
    'ko',
    'nl',
    'pl',
    'pt',
    'qd',
    'ru',
    'th',
    'tr',
    'uk',
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
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'nl':
      return AppLocalizationsNl();
    case 'pl':
      return AppLocalizationsPl();
    case 'pt':
      return AppLocalizationsPt();
    case 'qd':
      return AppLocalizationsQd();
    case 'ru':
      return AppLocalizationsRu();
    case 'th':
      return AppLocalizationsTh();
    case 'tr':
      return AppLocalizationsTr();
    case 'uk':
      return AppLocalizationsUk();
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
