// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appName => 'DraconDex';

  @override
  String get nexusTitle => 'DraconDex';

  @override
  String get nexusSubtitle => '소설 데이터 관리';

  @override
  String get moduleGlobalTags => '태그';

  @override
  String get moduleColors => '색상';

  @override
  String get moduleSettings => '설정';

  @override
  String get btnNew => '새로 만들기';

  @override
  String get btnSave => '저장';

  @override
  String get btnCancel => '취소';

  @override
  String get btnDelete => '삭제';

  @override
  String get btnEdit => '편집';

  @override
  String get btnClose => '닫기';

  @override
  String get btnAdd => '추가';

  @override
  String get btnImport => 'DB 가져오기';

  @override
  String get btnExport => 'DB 내보내기';

  @override
  String get labelName => '이름';

  @override
  String get labelMemo => '메모';

  @override
  String get labelColor => '색상';

  @override
  String get labelNote => '노트';

  @override
  String get labelTags => '태그';

  @override
  String get labelSearch => '검색...';

  @override
  String get newHashtag => '새 태그';

  @override
  String get noTags => '태그가 없습니다.';

  @override
  String get noColors => '색상 팔레트가 비어 있습니다.';

  @override
  String get noResults => '결과를 찾을 수 없습니다.';

  @override
  String get confirmDeleteTitle => '삭제 확인';

  @override
  String get confirmDeleteMessage => '이 작업은 되돌릴 수 없습니다.';

  @override
  String get colorInUse => '이 색상은 사용 중이므로 삭제할 수 없습니다.';

  @override
  String get themeLabel => '테마';

  @override
  String get themeMidnight => 'Midnight';

  @override
  String get themeMoonlight => 'Moonlight';

  @override
  String get themeDaylight => 'Daylight';

  @override
  String get themeShowAll => '모두 보기';

  @override
  String get themeShowLess => '접기';

  @override
  String get pageLayout => '제목 레이아웃';

  @override
  String get titleAlign => '제목 정렬';

  @override
  String get alignLeft => '왼쪽';

  @override
  String get alignCenter => '가운데';

  @override
  String get alignRight => '오른쪽';

  @override
  String get pageIcon => '제목 위 아이콘';

  @override
  String get pageCover => '커버 이미지';

  @override
  String get pageCoverNone => '커버 없음';

  @override
  String get pageCoverEmpty => '커버로 쓰려면 이 Nexus에 이미지를 가져오세요';

  @override
  String get pageLayoutScope => '이 페이지에만 적용됩니다';

  @override
  String get languageLabel => '언어';

  @override
  String get uiScaleLabel => 'UI 크기';

  @override
  String get importSuccess => '데이터베이스를 가져왔습니다.';

  @override
  String get importFailed => '가져오기 실패. 파일을 확인해 주세요.';

  @override
  String get exportSuccess => '데이터베이스를 내보냈습니다.';

  @override
  String get selectColor => '색상 선택';

  @override
  String get recentColors => '최근 사용';

  @override
  String get version => '버전 2.1.0';

  @override
  String get btnRename => '이름 바꾸기';

  @override
  String get btnPin => '고정';

  @override
  String get btnUnpin => '고정 해제';

  @override
  String get newNexusTitle => '새 Nexus';

  @override
  String get renameNexusTitle => 'Nexus 이름 바꾸기';

  @override
  String get newModuleTitle => '새 모듈';

  @override
  String get renameModuleTitle => '모듈 이름 바꾸기';

  @override
  String get newModuleTooltip => '새 모듈';

  @override
  String get newNexusTooltip => '새 Nexus';

  @override
  String get emptyNexusMessage => '아직 Nexus가 없습니다. +를 눌러 만들어보세요.';

  @override
  String get emptyModuleMessage => '비어 있습니다. +를 눌러 모듈을 추가하세요.';

  @override
  String get deleteNexusMessage => '내부의 모든 모듈이 함께 삭제됩니다. 이 작업은 되돌릴 수 없습니다.';

  @override
  String get deleteModuleMessage => '내부에 중첩된 모든 모듈도 함께 삭제됩니다. 이 작업은 되돌릴 수 없습니다.';

  @override
  String get labelKind => '종류';

  @override
  String get kindContentUnavailable => '이 모듈 종류는 모바일에서 아직 완전히 지원되지 않습니다 — 아래 공용 메모 필드를 대신 사용합니다.';

  @override
  String get notesHint => '이 모듈에 대한 메모…';

  @override
  String get authorChapters => '챕터';

  @override
  String get authorNewChapter => '새 챕터';

  @override
  String get authorNoChapters => '아직 챕터가 없습니다';

  @override
  String get authorContentHint => '이 챕터를 작성하세요…';

  @override
  String get scribeSessions => '세션';

  @override
  String get scribeNewSession => '새 세션';

  @override
  String get scribeNoSessions => '아직 세션이 없습니다';

  @override
  String get scribeMessageHint => '메시지를 입력하세요…';

  @override
  String get scribeSwitchSide => '좌우 전환';

  @override
  String get chroniclerEvents => '이벤트';

  @override
  String get chroniclerNewEvent => '새 이벤트';

  @override
  String get chroniclerNoEvents => '아직 이벤트가 없습니다';

  @override
  String get chroniclerUntitledEvent => '제목 없는 이벤트';

  @override
  String get chroniclerStart => '시작';

  @override
  String get chroniclerYear => '년';

  @override
  String get chroniclerMonth => '월';

  @override
  String get chroniclerDay => '일';

  @override
  String get chroniclerHour => '시';

  @override
  String get chroniclerMinute => '분';

  @override
  String get chroniclerHasEnd => '종료일 있음';

  @override
  String get chroniclerStory => '이야기';

  @override
  String get classifierFields => '필드';

  @override
  String get classifierNewField => '새 필드';

  @override
  String get classifierNoFields => '아직 필드가 없습니다';

  @override
  String get classifierItems => '항목';

  @override
  String get classifierNewItem => '새 항목';

  @override
  String get classifierNoItems => '아직 항목이 없습니다';

  @override
  String get classifierDeleteFieldWarning => '각 항목이 가진 이 필드의 값도 함께 삭제됩니다.';

  @override
  String get narratorScenes => '장면';

  @override
  String get narratorNewScene => '새 장면';

  @override
  String get narratorNoScenes => '아직 장면이 없습니다';

  @override
  String get narratorScript => '스크립트';

  @override
  String get narratorNewLine => '새 줄';

  @override
  String get narratorNoLines => '아직 줄이 없습니다';

  @override
  String get narratorSpeaker => '화자';

  @override
  String get narratorLine => '줄';

  @override
  String get narratorRoutes => '경로';

  @override
  String get narratorLeadsTo => '다음으로';

  @override
  String get narratorNoRoutes => '아직 경로가 없습니다';

  @override
  String get viewerResults => '결과';

  @override
  String get viewerNoFilter => '필터가 아직 없습니다 — 필터를 열어 이 렌즈가 보여줄 것을 선택하세요.';

  @override
  String get viewerNoResults => '이 필터와 일치하는 항목이 없습니다';

  @override
  String get viewerUntitled => '제목 없음';

  @override
  String get filterTitle => '필터';

  @override
  String get filterExplain => '한 그룹 안의 규칙은 모두 일치해야 합니다. 그룹 하나만 일치해도 충분합니다.';

  @override
  String get filterAnd => '그리고';

  @override
  String get filterOr => '또는';

  @override
  String get filterAddRule => '규칙 추가';

  @override
  String get filterAddGroup => '그룹 추가';

  @override
  String get filterFieldName => '이름';

  @override
  String get filterFieldHashtag => '해시태그';

  @override
  String get filterFieldKind => '모듈 종류';

  @override
  String get filterFieldChildOf => '모듈 안';

  @override
  String get filterFieldHandle => '핸들';

  @override
  String get filterOpIs => '다음과 같음';

  @override
  String get filterOpIsNot => '다음과 다름';

  @override
  String get filterOpStartsWith => '다음으로 시작';

  @override
  String get filterOpEndsWith => '다음으로 끝남';

  @override
  String get filterOpContains => '포함';

  @override
  String get filterPickModule => '모듈 선택';

  @override
  String get connectorRelations => '관계';

  @override
  String get connectorNoRelations => '아직 관계가 없습니다';

  @override
  String get connectorAddRelation => '관계 추가';

  @override
  String get connectorFrom => '시작';

  @override
  String get connectorTo => '대상';

  @override
  String get connectorLabel => '라벨';

  @override
  String get connectorNodes => '이 렌즈의 항목';

  @override
  String get designerBoard => '보드';

  @override
  String get designerNewNode => '새 노드';

  @override
  String get designerNode => '노드';

  @override
  String get designerNodeText => '텍스트';

  @override
  String get designerEmpty => '아직 노드가 없습니다';

  @override
  String get designerLinkHint => '연결할 다른 노드를 누르세요';

  @override
  String get designerLinkCancel => '연결 취소';

  @override
  String get sketcherPages => '페이지';

  @override
  String get sketcherNewPage => '새 페이지';

  @override
  String get sketcherNoPages => '아직 페이지가 없습니다';

  @override
  String get sketcherDraw => '그리기';

  @override
  String get sketcherPan => '이동';

  @override
  String get sketcherUndo => '마지막 획 취소';

  @override
  String get sketcherClear => '페이지 지우기';

  @override
  String get sketcherClearWarning => '이 페이지의 모든 획을 지웁니다.';

  @override
  String get locatorAreas => '영역';

  @override
  String get locatorNewArea => '새 영역';

  @override
  String get locatorNoAreas => '아직 영역이 없습니다';

  @override
  String get locatorUntitledArea => '제목 없는 영역';

  @override
  String get locatorToolDraw => '그리기';

  @override
  String get locatorToolMove => '이동';

  @override
  String get locatorUndoPoint => '마지막 점 취소';

  @override
  String get locatorDrawHint => '지도를 눌러 점을 찍으세요';

  @override
  String get locatorDeleteAreaWarning => '영역과 모든 점을 삭제합니다.';

  @override
  String get wandererPins => '핀';

  @override
  String get wandererNoPins => '아직 핀이 없습니다';

  @override
  String get wandererPlacing => '배치 중';

  @override
  String get wandererPlaceHint => '지도를 눌러 핀을 놓으세요';

  @override
  String get wandererPin => '핀';

  @override
  String get wandererLabel => '라벨';

  @override
  String get wandererLinkedEvent => '연결된 이벤트';

  @override
  String get wandererNoLink => '연결 없음';

  @override
  String get wandererNoEvents => '이 Nexus에는 아직 타임라인 이벤트가 없습니다';

  @override
  String get settingsAppearance => '화면';

  @override
  String get settingsData => '데이터';

  @override
  String get settingsAbout => '정보';

  @override
  String get exportDbTitle => '데이터베이스 내보내기';

  @override
  String get exportDbSubtitle => '.db 파일을 공유하여 PC나 다른 기기로 데이터를 옮기세요';

  @override
  String get importDbTitle => '데이터베이스 가져오기';

  @override
  String get importDbSubtitle => 'DraconDex .db 파일에서 데이터를 병합합니다';

  @override
  String get checkUpdatesTitle => '업데이트 확인';

  @override
  String get checkUpdatesSubtitle => '이 프로젝트의 GitHub Releases를 확인합니다 — 설치 전에 항상 확인합니다';

  @override
  String get upToDateMessage => '최신 버전을 사용 중입니다.';

  @override
  String get importingMessage => '가져오는 중…';

  @override
  String get importCompleteMessage => '가져오기 완료.';

  @override
  String get importFailedMessage => '가져오기 실패.';

  @override
  String get exportFailedMessage => '내보내기 실패.';

  @override
  String get saveFailedMessage => '저장 실패.';

  @override
  String get webBackupUnsupportedMessage => '웹 버전에서는 사용할 수 없습니다.';

  @override
  String get driveBackupTitle => 'Google 드라이브 백업';

  @override
  String get driveConnectedAs => '연결됨:';

  @override
  String get driveNotConnected => '연결 안 됨';

  @override
  String get driveConnect => '연결';

  @override
  String get driveDisconnect => '연결 해제';

  @override
  String get driveBackupNow => '지금 백업';

  @override
  String get driveRestoreTitle => 'Google 드라이브에서 복원';

  @override
  String get driveRestoreSubtitle => 'Drive 백업을 현재 데이터와 병합합니다';

  @override
  String get driveConnectFailedMessage => '연결 실패.';

  @override
  String get driveBackingUpMessage => 'Google 드라이브에 백업 중…';

  @override
  String get driveBackupSuccessMessage => '백업이 완료되었습니다.';

  @override
  String get driveBackupFailedMessage => '백업 실패.';

  @override
  String get addColorTitle => '색상 추가';

  @override
  String get colorPaletteTitle => '색상 팔레트';

  @override
  String get hashtagsTitle => '태그';

  @override
  String get editHashtagTitle => '태그 편집';

  @override
  String get tagNameLabel => '태그 이름';

  @override
  String get removeColorConfirmTitle => '색상을 삭제할까요?';

  @override
  String get deleteHashtagConfirmTitle => '태그를 삭제할까요?';

  @override
  String get viewModeTitle => '보기 모드';

  @override
  String get viewModeList => '목록';

  @override
  String get viewModeGrid => '그리드';

  @override
  String get viewModeCompact => '간결';

  @override
  String get builderNexusRootLabel => 'Nexus 루트';

  // --- Supabase project setup (features/settings/supabase_setup_screen.dart) ---

  @override
  String get settingPageSupabase => 'Supabase 프로젝트';

  @override
  String get sbIntro => '본인의 Supabase 프로젝트를 클라우드 동기화 서버로 사용합니다. 프로젝트 URL과 publishable 키를 붙여넣으면 필요한 테이블 확인과 설치는 DraconDex가 알아서 합니다.';

  @override
  String get sbUrl => '프로젝트 URL';

  @override
  String get sbKey => 'Publishable 키';

  @override
  String get sbKeyStored => '키가 이미 저장되어 있습니다 — 그대로 두려면 비워 두세요.';

  @override
  String get sbCheck => '프로젝트 확인';

  @override
  String get sbObjects => '필요한 테이블과 함수';

  @override
  String get sbSchemaVersion => '스키마 버전';

  @override
  String get sbReady => '준비 완료 — 클라우드 동기화에 필요한 것이 모두 있습니다.';

  @override
  String get sbNeedSetup => '설치가 필요합니다 — 일부 테이블 또는 함수가 없습니다.';

  @override
  String get sbNotChecked => '아직 확인하지 않았습니다. 위 설정을 저장한 뒤 "프로젝트 확인"을 누르세요.';

  @override
  String get sbAutoInstall => '자동 설치';

  @override
  String get sbAutoInstallHint => 'publishable 키로는 테이블을 만들 수 없습니다. Supabase 개인 액세스 토큰을 붙여넣으면 DraconDex가 설치 SQL을 대신 실행합니다.';

  @override
  String get sbAccessToken => '개인 액세스 토큰';

  @override
  String get sbAccessTokenHint => '이 요청 한 번에만 사용되며 저장하지 않습니다.';

  @override
  String get sbGetToken => '토큰 발급받기';

  @override
  String get sbManualTitle => '직접 설치하려면';

  @override
  String get sbManualHint => 'SQL을 복사해 프로젝트 SQL 편집기에서 실행한 뒤 "프로젝트 확인"을 다시 누르세요.';

  @override
  String get sbCopySql => 'SQL 복사';

  @override
  String get sbOpenSqlEditor => 'SQL 편집기 열기';

  @override
  String get sbOpenApiSettings => 'API 설정 열기';

  @override
  String get sbOpenAuthProviders => '인증 제공자 열기';

  @override
  String get sbGoogleOn => '이 프로젝트는 Google 로그인이 켜져 있습니다.';

  @override
  String get sbGoogleOff => 'Google 로그인이 꺼져 있습니다 — 로그인 전에 Authentication → Providers에서 켜세요.';

  @override
  String get sbInstalled => '설치 완료';

  @override
  String get sbClear => '프로젝트 설정 삭제';

  @override
  String get sbClearConfirm => '저장된 Supabase 프로젝트 설정을 삭제할까요?';

  @override
  String get sbCleared => 'Supabase 설정을 삭제했습니다';

  @override
  String get sbErrNoConfig => '먼저 프로젝트 URL과 publishable 키를 입력하세요.';

  @override
  String get sbErrInvalidUrl => '프로젝트 URL이 올바르지 않습니다 — https만 됩니다.';

  @override
  String get sbErrBadKey => '프로젝트가 이 키를 거부했습니다.';

  @override
  String get sbErrUnreachable => '해당 프로젝트에 연결할 수 없습니다.';

  @override
  String get sbErrNeedsManual => '액세스 토큰이 없습니다 — 수동 절차를 사용하세요.';

  @override
  String get sbErrBadAccessToken => '해당 액세스 토큰이 거부되었습니다.';

  @override
  String get sbErrForbidden => '이 토큰에는 해당 프로젝트를 변경할 권한이 없습니다.';

  @override
  String get sbErrNoProjectRef => '자동 설치에는 supabase.co 프로젝트 URL이 필요합니다.';

  @override
  String get sbErrRateLimited => '요청이 너무 많습니다 — 잠시 후 다시 시도하세요.';

  @override
  String get sbErrSqlError => '설치 SQL 실행에 실패했습니다.';

  @override
  String get sbErrNetwork => '네트워크 오류 — 프로젝트에 연결하지 못했습니다.';

  @override
  String get sbCopied => '복사했습니다';

  @override
  String get sbNotConfigured => '설정된 프로젝트가 없습니다';
  @override
  String get googleAccountTitle => 'Google 계정';

  @override
  String get googleAccountNotConfigured => 'OAuth 클라이언트가 아직 설정되지 않았습니다';

  @override
  String get googleAccountSetupTitle => 'Google 로그인 설정';

  @override
  String get googleClientTypeHintNative => 'Google Cloud Console에서 Google Drive API를 사용 설정하고 "데스크톱 앱" 유형의 OAuth 클라이언트를 만든 뒤 아래에 붙여넣으세요.';

  @override
  String get googleClientTypeHintWeb => 'Google Cloud Console에서 Google Drive API를 사용 설정하고 "웹 애플리케이션" 유형의 OAuth 클라이언트를 만든 뒤 클라이언트 ID를 아래에 붙여넣으세요.';

  @override
  String get googleClientIdLabel => '클라이언트 ID';

  @override
  String get googleClientSecretLabel => '클라이언트 보안 비밀';

  @override
  String get googleClientSecretKept => '클라이언트 보안 비밀이 이미 저장되어 있습니다. 비워 두면 그대로 유지됩니다.';

  @override
  String get googleRedirectUriLabel => '승인된 리디렉션 URI';

  @override
  String get googleRedirectUriHint => '이 주소를 그대로 클라이언트의 승인된 리디렉션 URI에, 이 사이트 주소를 승인된 JavaScript 원본에 추가하세요.';

  @override
  String get googleSessionExpired => '세션이 만료되었습니다 — 다시 연결하세요';

  @override
  String get googleErrNoConfig => '먼저 OAuth 클라이언트 정보를 입력하세요.';

  @override
  String get googleErrCancelled => '로그인이 취소되었습니다.';

  @override
  String get googleErrTimeout => '로그인 시간이 초과되었습니다.';

  @override
  String get googleErrVerify => '로그인을 확인할 수 없습니다. 다시 시도하세요.';

  @override
  String get googleErrNetwork => 'Google에 연결할 수 없습니다.';

  @override
  String get googleErrAuth => 'Google이 로그인을 거부했습니다.';

  @override
  String get googleErrPopupBlocked => '로그인 창이 차단되었습니다. 이 사이트의 팝업을 허용한 뒤 다시 시도하세요.';

  @override
  String get googleErrNotConnected => 'Google 계정에 연결되어 있지 않습니다.';

  @override
  String get driveRestoreSettingsTitle => 'Drive에서 설정 복원';

  @override
  String get driveRestoreSettingsSubtitle => '테마, 언어, UI 크기를 백업된 값으로 바꿉니다.';

  @override
  String get driveSettingsRestoredMessage => 'Google Drive에서 설정을 복원했습니다.';

  @override
  String get driveNoBackupMessage => 'Google Drive에 백업이 없습니다.';

  @override
  String get driveWebDatabaseNote => '브라우저 빌드에서는 설정만 백업되며 데이터베이스는 이 기기에 남습니다.';

  @override
  String get hubNestTitle => '넥서스 둥지';

  @override
  String get hubPanelShow => '허브 패널 표시';

  @override
  String get hubPanelHide => '허브 패널 숨기기';

  @override
  String get railExpand => '레일 펼치기';

  @override
  String get railCollapse => '레일 접기';

  // --- DDX Transfer ---

  @override
  String get transferTitle => '전송';

  @override
  String get transferSubtitle => 'Nexus 전체를 다른 기기로 넘깁니다. 계정도 설정도 필요 없습니다 — 보내는 기기가 코드를 보여주고, 받는 기기가 그것을 입력하면, 중간에 있던 사본은 도착하는 즉시 삭제됩니다.';

  @override
  String get transferTabSend => '보내기';

  @override
  String get transferTabReceive => '받기';

  @override
  String get transferNexusLabel => 'Nexus';

  @override
  String get transferPickNexus => '보낼 Nexus를 먼저 여세요.';

  @override
  String get transferAllowTyped => '코드 입력으로 받기 허용';

  @override
  String get transferAllowTypedHint => '켜면 상대가 코드와 PIN을 직접 입력할 수 있지만, 대기하는 동안 서버가 PIN으로 봉인된 키를 보관합니다. 끄면 QR 코드만이 입구가 되고 서버는 파일을 전혀 읽을 수 없습니다.';

  @override
  String get transferCreate => '전송 만들기';

  @override
  String get transferCode => '전송 코드';

  @override
  String get transferPin => 'PIN';

  @override
  String get transferCopyLink => '링크 복사';

  @override
  String get transferModeTyped => 'QR을 스캔하거나 코드와 PIN을 입력하세요. 대기 중에는 서버가 PIN으로 봉인된 키를 보관합니다.';

  @override
  String get transferModeQr => 'QR 코드 전용입니다. 키가 서버에 닿지 않으므로 스캔한 기기 외에는 아무도 열 수 없습니다.';

  @override
  String get transferExpiry => '30분 후 만료되며, 수신되는 즉시 삭제됩니다.';

  @override
  String get transferWaiting => '상대 기기를 기다리는 중…';

  @override
  String get transferClaimed => '상대가 코드를 확인하고 내려받는 중…';

  @override
  String get transferDone => '수신 완료 — 서버의 사본은 삭제되었습니다.';

  @override
  String get transferExpiredNotice => '수신되기 전에 만료되었습니다.';

  @override
  String get transferVerify => '확인';

  @override
  String get transferFound => '전송을 찾았습니다';

  @override
  String get transferProject => 'Nexus';

  @override
  String get transferSize => '크기';

  @override
  String get transferCreated => '만든 시각';

  @override
  String get transferSource => '보낸 곳';

  @override
  String get transferReceiveAsNew => '새 Nexus로 들어옵니다. 기존 항목은 건드리지 않습니다.';

  @override
  String get transferReceiveAction => '받기';

  @override
  String get transferReceived => 'Nexus를 받았습니다';

  @override
  String get transferErrNetwork => '전송 서비스에 연결할 수 없습니다.';

  @override
  String get transferErrBadCode => '전송 코드 또는 PIN이 올바르지 않습니다.';

  @override
  String get transferErrLocked => 'PIN을 너무 여러 번 틀렸습니다. 이 전송은 잠시 잠깁니다.';

  @override
  String get transferErrExpired => '이 전송은 만료되었습니다. 새 코드를 요청하세요.';

  @override
  String get transferErrGone => '이 전송은 더 이상 존재하지 않습니다 — 수신되었거나 취소되었습니다.';

  @override
  String get transferErrNotReady => '상대 기기가 아직 업로드를 끝내지 않았습니다.';

  @override
  String get transferErrTooLarge => '이 Nexus는 한 번에 보낼 수 있는 크기를 넘습니다.';

  @override
  String get transferErrBadToken => '이 전송 세션은 더 이상 유효하지 않습니다. 다시 시작하세요.';

  @override
  String get transferErrBadKey => '링크가 불완전합니다 — 키 부분이 없거나 손상되었습니다.';

  @override
  String get transferErrQrOnly => '보낸 쪽이 QR 코드만 허용했습니다. 입력하지 말고 스캔하세요.';

  @override
  String get transferErrBadPayload => '받은 파일을 읽을 수 없습니다.';

  @override
  String get transferErrServer => '전송 서비스에 문제가 발생했습니다.';

  @override
  String get transferSending => '보내는 중…';

  @override
  String get transferCopied => '링크를 복사했습니다';

  @override
  String get transferCancel => '취소';

  @override
  String get transferPasteLink => '또는 전송 링크 붙여넣기';

  @override
  String get transferPasteLinkHint => '링크에는 키가 들어 있어서, 보낸 쪽이 QR만 허용했더라도 사용할 수 있습니다.';

  @override
  String get navNest => '둥지';

  @override
  String get navSearch => '검색';

  @override
  String get navOpenPages => '페이지';

  @override
  String get navTools => '도구';

  @override
  String get navMore => '더 보기';

  @override
  String get openPagesTitle => '열린 페이지';

  @override
  String get openPagesEmpty => '열린 페이지가 없습니다. 연 페이지는 닫을 때까지 여기에 남습니다.';

  @override
  String get openPagesCloseAll => '모두 닫기';

  @override
  String get openPageClose => '페이지 닫기';

  @override
  String get rowOpen => '열기';

  @override
  String get rowMore => '추가 작업';

  @override
  String get crumbEmpty => '안에 아무것도 없음';

  @override
  String get goToTitle => '이동';

  @override
  String get goToHint => '이름, 경로 또는 @handle';

  @override
  String get searchHint => '이름, 텍스트, 명령 검색';

  @override
  String get searchThings => '항목';

  @override
  String get searchContent => '내용';

  @override
  String get searchCommands => '명령';

  @override
  String get searchEmpty => '일치하는 결과 없음';

  @override
  String get elementPageSoon => '이 요소는 다음 업데이트에서 자체 페이지를 갖게 됩니다. 지금은 모듈 안에서 열립니다.';

  @override
  String get wikiUnresolved => '아직 이 이름을 가진 것이 없습니다. 이 이름으로 Drafter 페이지를 만들까요?';

  @override
  String get wikiCreateDrafter => '만들기';

  @override
  String get btnUndo => '실행 취소';

  @override
  String get pbAddBlock => '블록 추가';

  @override
  String get pbAddHere => '여기에 추가';

  @override
  String get pbAddProperty => '속성 추가';

  @override
  String get pbArrange => '페이지 정리';

  @override
  String get pbArrangeDone => '완료';

  @override
  String get pbArrangeHint => '드래그해서 순서를 바꿉니다. 열 블록은 통째로 움직입니다.';

  @override
  String get pbArrangeShared => '이것은 이 모듈의 모든 요소가 공유하는 레이아웃입니다. 이 페이지만 바꾸려면 먼저 분리하세요.';

  @override
  String get pbBacklinks => '링크된 곳';

  @override
  String get pbBlockDeleted => '블록을 삭제했습니다';

  @override
  String get pbBorrow => '다른 모듈의 보기';

  @override
  String get pbColumn => '열';

  @override
  String get pbColumns => '열';

  @override
  String get pbDivider => '구분선';

  @override
  String get pbFullScreen => '전체 화면';

  @override
  String get pbHeading => '제목';

  @override
  String get pbImage => '이미지';

  @override
  String get pbItemBody => '요소';

  @override
  String get pbItemEmpty => '아직 적힌 것이 없습니다.';

  @override
  String get pbNoRelated => '아직 링크가 없습니다';

  @override
  String get pbNotOnMobile => '이 앱에는 아직 없습니다';

  @override
  String get pbOnlyOnce => '한 페이지에 한 번만 둘 수 있습니다';

  @override
  String get pbOpenFullScreen => '열기';

  @override
  String get pbOutgoing => '링크 대상';

  @override
  String get pbPropName => '이름';

  @override
  String get pbPropType => '유형';

  @override
  String get pbProperties => '속성';

  @override
  String get pbRelated => '관련';

  @override
  String get pbRelations => '관계';

  @override
  String get pbRevert => '공유 레이아웃으로 되돌리기';

  @override
  String get pbSharedLayout => '이 모듈의 모든 요소 페이지가 공유하는 레이아웃.';

  @override
  String get pbSourceGone => '보여 주던 것이 사라졌습니다';

  @override
  String get pbSplit => '이 페이지에 고유 레이아웃 주기';

  @override
  String get pbTags => '태그';

  @override
  String get pbText => '텍스트';

  @override
  String get pbTextEmpty => '빈 텍스트 — 눌러서 쓰기';

  @override
  String get propTypeCheckbox => '체크박스';

  @override
  String get propTypeDate => '날짜';

  @override
  String get propTypeNumber => '숫자';

  @override
  String get propTypeText => '텍스트';

  @override
  String get propTypeTextarea => '긴 텍스트';

  @override
  String get propTypeUrl => '링크';

  @override
  String get viewTable => '표';

  @override
  String get viewListDetail => '목록 · 상세';

  @override
  String get viewRelations => '관계';

  @override
  String get viewGrid => '그리드';

  @override
  String get viewScene => '장면';

  @override
  String get viewGraph => '그래프';

  @override
  String get viewCards => '카드';

  @override
  String get viewBoard => '보드';

  @override
  String get viewEdges => '연결선';

  @override
  String get viewArea => '영역';

  @override
  String get viewMap => '지도';

  @override
  String get viewTimeline => '타임라인';

  @override
  String get viewCanvas => '캔버스';

  @override
  String get viewPages => '페이지';

  @override
  String get viewGallery => '갤러리';

  @override
  String get viewExport => '내보내기';

  @override
  String get viewEditor => '편집기';

  @override
  String get viewOutline => '개요';

  @override
  String get viewReading => '읽기';

  @override
  String get viewBook => '책';

  @override
  String get viewRoutes => '경로';

  @override
  String get viewReader => '리더';

  @override
  String get viewDialogue => '대화';

  @override
  String get viewOneline => '한 줄';

  @override
  String get viewDownline => '세로';

  @override
  String get viewCompare => '비교';

  @override
  String get viewCalendar => '달력';

  @override
  String get viewList => '목록';

  @override
  String get viewMatrix => '매트릭스';

  @override
  String get viewChat => '채팅';

  @override
  String get viewTranscript => '기록';

  @override
  String get clsNoRelations => '아직 이 요소들 사이에 링크가 없습니다';

  @override
  String get clsTypeText => '텍스트';

  @override
  String get clsTypeTextarea => '긴 텍스트';

  @override
  String get clsTypeNumber => '숫자';

  @override
  String get clsTypeDate => '날짜';

  @override
  String get clsTypeSelect => '선택';

  @override
  String get clsTypeMulti => '다중 선택';

  @override
  String get clsTypeCheckbox => '체크박스';

  @override
  String get clsTypeUrl => '링크 (URL)';

  @override
  String get clsTypeRelation => '관계';

  @override
  String get clsTypeFormula => '수식';

  @override
  String get clsFieldType => '필드 유형';

  @override
  String get clsChoices => '선택지 (줄마다 하나)';

  @override
  String get clsFormulaHint => '예: {HP} * 2';

  @override
  String get clsEditField => '필드 편집';

  @override
  String get clsAddLink => '링크 추가';

  @override
  String get dateDay => '일';

  @override
  String get dateMonth => '월';

  @override
  String get dateYear => '년';

  @override
  String get dateHour => '시';

  @override
  String get dateMinute => '분';

  @override
  String get btnClear => '지우기';

  @override
  String get groupBy => '그룹 기준';

  @override
  String get groupModule => '모듈';

  @override
  String get relDirected => '한 방향 (→)';

  @override
  String get exhGroup => '그룹';

  @override
  String get exhNote => '메모';

  @override
  String get exhAddElement => '요소 배치';

  @override
  String get exhAddNote => '메모 추가';

  @override
  String get exhAddGroup => '그룹 추가';

  @override
  String get exhRemoveFromScene => '장면에서 제거';

  @override
  String get exhSceneEmpty => '아직 배치된 것이 없습니다 — 요소를 배치하거나 메모를 추가하세요.';

  @override
  String get auStatusIdea => '아이디어';

  @override
  String get auStatusDraft => '초안';

  @override
  String get auStatusRevised => '수정됨';

  @override
  String get auStatusDone => '완료';

  @override
  String get auSynopsis => '시놉시스';

  @override
  String get auPov => '시점';

  @override
  String get btnPrevious => '이전';

  @override
  String get btnNext => '다음';

  @override
  String get narAddRoute => '경로 추가';

  @override
  String get narScript => '대본';

  @override
  String get narPlayTest => '플레이 테스트';

  @override
  String get narRestart => '다시 시작';

  @override
  String get narShowHidden => '숨긴 선택지 표시';

  @override
  String get narVariables => '변수';

  @override
  String get narNoVariables => '이 Nexus에는 스토리 변수가 없습니다';

  @override
  String get narPlayEnd => '끝 — 이어지는 경로가 없습니다.';

  @override
  String get narNoOptionOpen => '이 변수로는 열린 선택지가 없습니다.';

  @override
  String get narHiddenByCondition => '조건에 의해 숨김';

  @override
  String get chrCompareWith => '비교 대상';

  @override
  String get chrNoOtherLine => '이 Nexus에 비교할 다른 Chronicler가 없습니다';

  @override
  String get scribeNoMessages => '아직 메시지가 없습니다';

  @override
  String get wndLocator => '지도 (Locator)';

  @override
  String get wndNoLocator => '아직 이 Nexus에 Locator가 없습니다 — 핀은 그 영역에 놓입니다.';

  @override
  String get wndPickLocator => '이 핀들이 놓일 Locator를 고르세요.';

  @override
  String get wndNoAreas => '그 Locator에는 아직 영역이 없습니다';

  @override
  String get wndAddPin => '여기에 핀 두기';

  @override
  String get skExportPng => 'PNG로 공유';

  @override
  String get dgPanel => '칸 (만화)';

  @override
  String get dgBalloon => '말풍선';

  @override
  String get dgLinkFrom => '연결 대상…';

  @override
  String get dgPanelShows => 'Sketcher 페이지 표시';

  @override
  String get dgBalloonSpeaker => '말하는 이';

  @override
  String get dgNumberByPosition => '위치순으로 번호 매기기';

  @override
  String get dgShowOrder => '읽는 순서 표시';

  @override
  String get divNewTable => '새 표';

  @override
  String get divDice => '주사위';

  @override
  String get divDiceHelp => '비우면 = 가중치';

  @override
  String get divBadDice => '주사위 식이 아닙니다';

  @override
  String get divModePick => '하나 뽑기';

  @override
  String get divModeJoin => '모두 잇기';

  @override
  String get divWeighted => '가중치';

  @override
  String get divEntryText => '텍스트';

  @override
  String get divFrom => '부터';

  @override
  String get divTo => '까지';

  @override
  String get divWeight => '가중치';

  @override
  String get divRollsTable => '여기서 다른 표 굴리기';

  @override
  String get divLinkEntity => '무언가 지정';

  @override
  String get divUnlink => '링크 제거';

  @override
  String get divNoTables => '아직 표가 없습니다';

  @override
  String get divRoll => '굴리기';

  @override
  String get divEntries => '항목';

  @override
  String get divNoEntries => '아직 항목이 없습니다';

  @override
  String get divHistory => '기록';

  @override
  String get divQuickRoll => '그냥 굴리기: 3d6';

  @override
  String get trashTitle => '휴지통';

  @override
  String get trashMoved => '휴지통으로 이동함';

  @override
  String get trashEmptyAll => '휴지통 비우기';

  @override
  String get trashEmptyConfirm => '휴지통의 모든 항목이 영구 삭제됩니다.';

  @override
  String get trashNothing => '휴지통이 비어 있습니다';

  @override
  String get trashNote => '복원한 모듈은 안의 모든 것과 관계와 함께 돌아오지만 버전 기록은 돌아오지 않습니다.';

  @override
  String get trashRestore => '복원';

  @override
  String get trashModules => '모듈';

  @override
  String get trashDeleteForever => '영구 삭제할까요? 이후에는 복원할 수 없습니다.';

  @override
  String get problemsTitle => '문제';

  @override
  String get problemsLinks => '해결되지 않은 링크';

  @override
  String get problemsEmpty => '빈 모듈';

  @override
  String get problemsRelations => '한쪽 끝이 없는 관계';

  @override
  String get problemsNone => '문제가 없습니다';

  @override
  String get assetsTitle => '에셋';

  @override
  String get assetsFromDevice => '이 기기에서 추가';

  @override
  String get assetsAddUrl => '링크 (URL) 추가';

  @override
  String get assetsNotice => '에셋은 이 기기에 남습니다. 동기화는 이름만 옮기고 파일은 옮기지 않습니다.';

  @override
  String get assetsNone => '아직 에셋이 없습니다';

  @override
  String get assetsTooBig => '브라우저에 두기에는 너무 큽니다';

  @override
  String get pbChooseImage => '이미지 선택';

  @override
  String get csvImportTitle => 'CSV 가져오기';

  @override
  String get fromTemplate => '템플릿에서';

  @override
  String get guideTitle => '가이드';

  @override
  String get guideDesc => '모든 종류를 보여 주는 작은 세계';

  @override
  String get guideAdd => '가이드 추가';

  @override
  String get mddxImport => '모듈 파일 가져오기 (.mddx)';

  @override
  String get mddxExport => '.mddx로 내보내기';

  @override
  String get mddxNotModule => '그 파일은 DraconDex 모듈이 아닙니다';

  @override
  String get kindCatStructure => '구조';

  @override
  String get kindCatView => '보기';

  @override
  String get kindCatData => '데이터';

  @override
  String get kindGroupNotes => '메모·문서';

  @override
  String get kindGroupData => '데이터·범주';

  @override
  String get kindGroupMapTime => '지도와 시간';

  @override
  String get kindGroupStory => '이야기';

  @override
  String get kindGroupDraw => '그리기와 디자인';

  @override
  String get nexusStartWith => '시작 내용';

  @override
  String get nexusStartEmpty => '없음 — 빈 Nexus';

  @override
  String get csvPick => 'CSV 파일 선택';

  @override
  String get csvHint => '첫 행은 필드 이름, 첫 열은 요소 이름입니다.';

  @override
  String get csvCreate => 'Classifier 만들기';

  @override
  String get csvSkip => '제외';

  @override
  String get csvNameColumn => '이름';

  @override
  String get csvTruncated => '처음 5,000행만';

  @override
  String get csvTooLarge => '파일이 8MB를 넘습니다';

  @override
  String get csvEmpty => '가져올 행이 없습니다 — 머리글과 한 행 이상이 필요합니다';

  @override
  String get kindClassicCollector => '폴더';

  @override
  String get kindDescCollector => '다른 모듈을 묶는 폴더';

  @override
  String get kindClassicManager => '프로젝트';

  @override
  String get kindDescManager => '하위 모듈을 카드·목록·표로 보기';

  @override
  String get kindClassicInspector => '상세';

  @override
  String get kindDescInspector => '이 항목의 상세 내용을 담은 노트 한 장';

  @override
  String get kindClassicClassifier => '카테고리';

  @override
  String get kindDescClassifier => '커스텀 필드로 항목 분류';

  @override
  String get kindClassicLocator => '지도';

  @override
  String get kindDescLocator => '핀과 영역이 있는 지도';

  @override
  String get kindClassicChronicler => '타임라인';

  @override
  String get kindDescChronicler => '날짜별 이벤트 타임라인';

  @override
  String get kindClassicWanderer => '타임맵';

  @override
  String get kindDescWanderer => '지도 핀과 타임라인 이벤트를 연결';

  @override
  String get kindClassicNarrator => '스토리';

  @override
  String get kindDescNarrator => '대화 노드를 잇는 경로 보드';

  @override
  String get kindClassicAuthor => '북';

  @override
  String get kindDescAuthor => '챕터와 글쓰기 에디터가 있는 책';

  @override
  String get kindClassicScribe => '챗';

  @override
  String get kindDescScribe => '채팅형 세션 노트';

  @override
  String get kindClassicDrafter => '문서';

  @override
  String get kindDescDrafter => '빈 마크다운 페이지';

  @override
  String get kindClassicExhibitor => '전시';

  @override
  String get kindDescExhibitor => '연결된 항목의 장면·그래프·표 — 관계는 여기서 그립니다';

  @override
  String get kindClassicSketcher => '드로잉';

  @override
  String get kindDescSketcher => '자유롭게 그리는 캔버스';

  @override
  String get kindClassicDesigner => '그래프';

  @override
  String get kindDescDesigner => '도형과 화살표로 만드는 자유 다이어그램';

  @override
  String get kindClassicDiviner => '랜덤 표';

  @override
  String get kindDescDiviner => '랜덤 표와 주사위 굴림';

  @override
  String get moduleNameMode => '모듈 이름';

  @override
  String get moduleNameModeHint => 'Unique = Collector/Manager/… · Classic = 폴더/프로젝트/…';

  @override
  String get moduleInside => '개 포함';

  @override
  String get nameModeUnique => '고유';

  @override
  String get nameModeClassic => '클래식';

  @override
  String get kindRecent => '최근';

  @override
  String get clsLevelable => '레벨 가능';

  @override
  String get clsCondition => '조건';

  @override
  String get levelColLevel => '레벨';

  @override
  String get levelColInfo => '정보';

  @override
  String get levelAddRow => '행 추가';

  @override
  String get levelNoRows => '행이 없습니다';

  @override
  String get confirmDeleteLevelRow => '이 행을 삭제할까요?';

  @override
  String get clsLevelAndCondition => '레벨 및 조건';

  @override
  String get clsLevelAndConditionHint => '필드를 행 표(레벨)로 만들거나 값을 조건에 연결합니다.';

  @override
  String get clsInsertAbove => '위에 행 삽입';

  @override
  String get clsInsertBelow => '아래에 행 삽입';

  @override
  String get exportTitle => '내보내기…';

  @override
  String get exportPdf => 'PDF';

  @override
  String get exportPdfD => '인쇄·공유·인쇄소 전달용';

  @override
  String get exportDocx => 'Word (DOCX)';

  @override
  String get exportDocxD => 'Word·Google 문서·Pages에서 계속 편집';

  @override
  String get exportEpub => 'EPUB(전자책)';

  @override
  String get exportEpubD => 'Apple Books·Kindle·Kobo·Calibre용';

  @override
  String get exportXlsx => 'Excel (XLSX)';

  @override
  String get exportXlsxD => '표마다 시트 하나 — Excel·Sheets·Numbers용';

  @override
  String get exportCsv => 'CSV';

  @override
  String get exportCsvD => '단순한 표 — CSV 가져오기로 다시 불러올 수 있음';

  @override
  String get htmlExport => '웹사이트로 내보내기 (HTML)';

  @override
  String get exportMarkdown => 'Markdown으로 내보내기 (.zip)';

  @override
  String get exportMdAnyD => '그림이 있는 노트 — Obsidian에서 열림';

  @override
  String get exportMddxD => '이 모듈을 다른 볼트로 옮기기용';

  @override
  String get exportNoPage => '폴더에는 자체 페이지가 없습니다';

  @override
  String get exportOnlyDocs => 'Author·Classifier·Chronicler·Drafter·Inspector만';

  @override
  String get exportOnlyBooks => 'Author 책만';

  @override
  String get exportOnlyTables => 'Classifier와 Chronicler만';

  @override
  String get exportGo => '내보내기';

  @override
  String get exportScope => '포함할 범위';

  @override
  String get exportScopePage => '이 페이지';

  @override
  String get exportScopeModule => '이 모듈과 모든 요소';

  @override
  String get exportScopeInside => '이 모듈과 그 안의 모든 것';

  @override
  String get exportScopeNexus => 'Nexus 전체';

  @override
  String get exportPaper => '용지';

  @override
  String get exportOrientation => '방향';

  @override
  String get exportPortrait => '세로';

  @override
  String get exportLandscape => '가로';

  @override
  String get exportHeaderFooter => '제목과 쪽 번호';

  @override
  String get exportToc => '목차 페이지';

  @override
  String get exportCsvHint => '표 하나: Classifier의 요소 또는 Chronicler의 첫 타임라인. 수식 필드는 빠집니다. CSV 가져오기로 다시 읽을 수 있습니다.';

  @override
  String get exportXlsxHint => '표마다 시트 하나(Chronicler는 모든 타임라인), 굵게 고정된 머리글. 수식 필드는 빠집니다.';

  @override
  String get exportMdAnyHint => '요소마다 .md 하나(필드는 속성으로), 페이지의 그림은 assets/에 담깁니다. 폴더를 Obsidian 볼트로 여세요.';

  @override
  String get exportDocxHint => '장·요소·사건마다 제목(Word 탐색 창에 표시), 필드는 표로, 페이지의 그림, 장 사이 페이지 나누기.';

  @override
  String get exportEpubHint => '장마다 파일 하나와 목차, 책 페이지의 제목 표지가 표지가 됩니다.';

  @override
  String get exportMddxHint => '다른 DraconDex 볼트에서 가져올 수 있는 .mddx 파일.';

  @override
  String get exportFormulaSkipped => '제외된 수식 필드: {names}';

  @override
  String get exportMoreTimelines => 'CSV에는 타임라인 하나만 — 나머지 {n}개는 Excel 내보내기로';

  @override
  String get exportMediaMissing => '그림 {n}개를 찾지 못해 제외했습니다';

  @override
  String get exportMarkdownEmpty => '아직 내보낼 내용이 없습니다';

  @override
  String get exportWorking => '페이지를 그리는 중…';

  @override
  String get exportPictures => '그림';

  @override
  String get exportRows => '행';

  @override
  String get exportHtmlPageD => '이 페이지를 웹 페이지로 — 그림도 함께';

  @override
  String get exportHtmlPageHint => 'index.html과 media/의 그림이 든 .zip — 압축을 풀고 아무 브라우저에서 index.html을 여세요.';

  @override
  String get exportPrint => '인쇄…';
}
