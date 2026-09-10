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
  String get builderNavHome => '홈';

  @override
  String get builderNavView => '보기';

  @override
  String get builderNavFolders => '폴더 보기';

  @override
  String get viewModeTitle => '보기 모드';

  @override
  String get viewModeList => '목록';

  @override
  String get viewModeGrid => '그리드';

  @override
  String get viewModeCompact => '간결';

  @override
  String get recentViewsTitle => '최근 본 항목';

  @override
  String get recentViewsEmpty => '최근 본 항목이 없습니다';

  @override
  String get recentViewsClear => '모두 지우기';

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
}
