// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'DraconDex';

  @override
  String get nexusTitle => 'DraconDex';

  @override
  String get nexusSubtitle => 'Управление Данными Романов';

  @override
  String get moduleGlobalTags => 'Теги';

  @override
  String get moduleColors => 'Цвета';

  @override
  String get moduleSettings => 'Настройки';

  @override
  String get btnNew => 'Новый';

  @override
  String get btnSave => 'Сохранить';

  @override
  String get btnCancel => 'Отмена';

  @override
  String get btnDelete => 'Удалить';

  @override
  String get btnEdit => 'Редактировать';

  @override
  String get btnClose => 'Закрыть';

  @override
  String get btnAdd => 'Добавить';

  @override
  String get btnImport => 'Импорт БД';

  @override
  String get btnExport => 'Экспорт БД';

  @override
  String get labelName => 'Имя';

  @override
  String get labelMemo => 'Заметка';

  @override
  String get labelColor => 'Цвет';

  @override
  String get labelNote => 'Примечание';

  @override
  String get labelTags => 'Теги';

  @override
  String get labelSearch => 'Поиск...';

  @override
  String get newHashtag => 'Новый Тег';

  @override
  String get noTags => 'Пока нет тегов.';

  @override
  String get noColors => 'Нет цветов в палитре.';

  @override
  String get noResults => 'Результаты не найдены.';

  @override
  String get confirmDeleteTitle => 'Подтвердите Удаление';

  @override
  String get confirmDeleteMessage => 'Это действие нельзя отменить.';

  @override
  String get colorInUse => 'Цвет используется и не может быть удалён.';

  @override
  String get themeLabel => 'Тема';

  @override
  String get themeMidnight => 'Полночь';

  @override
  String get themeMoonlight => 'Лунный Свет';

  @override
  String get themeDaylight => 'Дневной Свет';

  @override
  String get languageLabel => 'Язык';

  @override
  String get uiScaleLabel => 'Масштаб Интерфейса';

  @override
  String get importSuccess => 'База данных успешно импортирована.';

  @override
  String get importFailed => 'Ошибка импорта. Проверьте файл.';

  @override
  String get exportSuccess => 'База данных экспортирована.';

  @override
  String get selectColor => 'Выбрать Цвет';

  @override
  String get recentColors => 'Недавние';

  @override
  String get version => 'Версия 2.1.0';

  @override
  String get btnRename => 'Переименовать';

  @override
  String get btnPin => 'Закрепить';

  @override
  String get btnUnpin => 'Открепить';

  @override
  String get newNexusTitle => 'Новый Nexus';

  @override
  String get renameNexusTitle => 'Переименовать Nexus';

  @override
  String get newModuleTitle => 'Новый модуль';

  @override
  String get renameModuleTitle => 'Переименовать модуль';

  @override
  String get newModuleTooltip => 'Новый модуль';

  @override
  String get newNexusTooltip => 'Новый Nexus';

  @override
  String get emptyNexusMessage => 'Пока нет ни одного Nexus. Нажмите +, чтобы создать.';

  @override
  String get emptyModuleMessage => 'Пусто. Нажмите +, чтобы добавить модуль.';

  @override
  String get deleteNexusMessage => 'Это удалит все модули внутри него. Это действие нельзя отменить.';

  @override
  String get deleteModuleMessage => 'Это также удалит все вложенные модули внутри. Это действие нельзя отменить.';

  @override
  String get labelKind => 'Тип';

  @override
  String get kindContentUnavailable => 'Этот тип модуля пока не полностью поддерживается на мобильных устройствах — используется общее поле заметок ниже.';

  @override
  String get notesHint => 'Заметки для этого модуля…';

  @override
  String get authorChapters => 'Главы';

  @override
  String get authorNewChapter => 'Новая глава';

  @override
  String get authorNoChapters => 'Пока нет глав';

  @override
  String get authorContentHint => 'Напишите эту главу…';

  @override
  String get scribeSessions => 'Сессии';

  @override
  String get scribeNewSession => 'Новая сессия';

  @override
  String get scribeNoSessions => 'Пока нет сессий';

  @override
  String get scribeMessageHint => 'Напишите сообщение…';

  @override
  String get scribeSwitchSide => 'Сменить сторону';

  @override
  String get chroniclerEvents => 'События';

  @override
  String get chroniclerNewEvent => 'Новое событие';

  @override
  String get chroniclerNoEvents => 'Пока нет событий';

  @override
  String get chroniclerUntitledEvent => 'Событие без названия';

  @override
  String get chroniclerStart => 'Начало';

  @override
  String get chroniclerYear => 'Год';

  @override
  String get chroniclerMonth => 'Месяц';

  @override
  String get chroniclerDay => 'День';

  @override
  String get chroniclerHour => 'Час';

  @override
  String get chroniclerMinute => 'Минута';

  @override
  String get chroniclerHasEnd => 'Есть дата окончания';

  @override
  String get chroniclerStory => 'История';

  @override
  String get classifierFields => 'Поля';

  @override
  String get classifierNewField => 'Новое поле';

  @override
  String get classifierNoFields => 'Пока нет полей';

  @override
  String get classifierItems => 'Элементы';

  @override
  String get classifierNewItem => 'Новый элемент';

  @override
  String get classifierNoItems => 'Пока нет элементов';

  @override
  String get classifierDeleteFieldWarning => 'Это также удалит значение этого поля у каждого элемента.';

  @override
  String get narratorScenes => 'Сцены';

  @override
  String get narratorNewScene => 'Новая сцена';

  @override
  String get narratorNoScenes => 'Пока нет сцен';

  @override
  String get narratorScript => 'Сценарий';

  @override
  String get narratorNewLine => 'Новая строка';

  @override
  String get narratorNoLines => 'Пока нет строк';

  @override
  String get narratorSpeaker => 'Говорящий';

  @override
  String get narratorLine => 'Строка';

  @override
  String get narratorRoutes => 'Маршруты';

  @override
  String get narratorLeadsTo => 'Ведёт к';

  @override
  String get narratorNoRoutes => 'Пока нет маршрутов';

  @override
  String get viewerResults => 'Результаты';

  @override
  String get viewerNoFilter => 'Фильтр ещё не задан — откройте фильтр, чтобы выбрать, что показывает эта линза.';

  @override
  String get viewerNoResults => 'Ничего не соответствует фильтру';

  @override
  String get viewerUntitled => 'Без названия';

  @override
  String get filterTitle => 'Фильтр';

  @override
  String get filterExplain => 'Все правила в группе должны совпасть. Достаточно совпадения одной группы.';

  @override
  String get filterAnd => 'и';

  @override
  String get filterOr => 'или';

  @override
  String get filterAddRule => 'Добавить правило';

  @override
  String get filterAddGroup => 'Добавить группу';

  @override
  String get filterFieldName => 'Имя';

  @override
  String get filterFieldHashtag => 'Хештег';

  @override
  String get filterFieldKind => 'Вид модуля';

  @override
  String get filterFieldChildOf => 'Внутри модуля';

  @override
  String get filterOpIs => 'равно';

  @override
  String get filterOpIsNot => 'не равно';

  @override
  String get filterOpStartsWith => 'начинается с';

  @override
  String get filterOpEndsWith => 'заканчивается на';

  @override
  String get filterOpContains => 'содержит';

  @override
  String get filterPickModule => 'Выберите модуль';

  @override
  String get settingsAppearance => 'Внешний вид';

  @override
  String get settingsData => 'Данные';

  @override
  String get settingsAbout => 'О программе';

  @override
  String get exportDbTitle => 'Экспорт базы данных';

  @override
  String get exportDbSubtitle => 'Поделитесь файлом .db, чтобы перенести данные на ПК или другое устройство';

  @override
  String get importDbTitle => 'Импорт базы данных';

  @override
  String get importDbSubtitle => 'Объединить данные из файла .db DraconDex';

  @override
  String get checkUpdatesTitle => 'Проверить обновления';

  @override
  String get checkUpdatesSubtitle => 'Проверяет GitHub Releases этого проекта — всегда спрашивает перед установкой';

  @override
  String get upToDateMessage => 'У вас установлена последняя версия.';

  @override
  String get importingMessage => 'Импорт…';

  @override
  String get importCompleteMessage => 'Импорт завершён.';

  @override
  String get importFailedMessage => 'Ошибка импорта.';

  @override
  String get exportFailedMessage => 'Ошибка экспорта.';

  @override
  String get saveFailedMessage => 'Ошибка сохранения.';

  @override
  String get webBackupUnsupportedMessage => 'Недоступно в веб-версии.';

  @override
  String get driveBackupTitle => 'Резервное копирование в Google Drive';

  @override
  String get driveConnectedAs => 'Подключено:';

  @override
  String get driveNotConnected => 'Не подключено';

  @override
  String get driveConnect => 'Подключить';

  @override
  String get driveDisconnect => 'Отключить';

  @override
  String get driveBackupNow => 'Создать резервную копию';

  @override
  String get driveRestoreTitle => 'Восстановить из Google Drive';

  @override
  String get driveRestoreSubtitle => 'Объединяет резервную копию Drive с текущими данными';

  @override
  String get driveConnectFailedMessage => 'Ошибка подключения.';

  @override
  String get driveBackingUpMessage => 'Резервное копирование в Google Drive…';

  @override
  String get driveBackupSuccessMessage => 'Резервное копирование завершено.';

  @override
  String get driveBackupFailedMessage => 'Ошибка резервного копирования.';

  @override
  String get addColorTitle => 'Добавить цвет';

  @override
  String get colorPaletteTitle => 'Палитра цветов';

  @override
  String get hashtagsTitle => 'Теги';

  @override
  String get editHashtagTitle => 'Изменить тег';

  @override
  String get tagNameLabel => 'Название тега';

  @override
  String get removeColorConfirmTitle => 'Удалить цвет?';

  @override
  String get deleteHashtagConfirmTitle => 'Удалить тег?';

  @override
  String get builderNavHome => 'Главная';

  @override
  String get builderNavView => 'Вид';

  @override
  String get builderNavFolders => 'Виды папок';

  @override
  String get viewModeTitle => 'Режим просмотра';

  @override
  String get viewModeList => 'Список';

  @override
  String get viewModeGrid => 'Сетка';

  @override
  String get viewModeCompact => 'Компактно';

  @override
  String get recentViewsTitle => 'Недавние виды';

  @override
  String get recentViewsEmpty => 'Пока нет недавних видов';

  @override
  String get recentViewsClear => 'Очистить всё';

  @override
  String get builderNexusRootLabel => 'Корень Nexus';

  // --- Supabase project setup (features/settings/supabase_setup_screen.dart) ---

  @override
  String get settingPageSupabase => 'Проект Supabase';

  @override
  String get sbIntro => 'Используйте свой проект Supabase как сервер облачной синхронизации. Вставьте URL проекта и publishable-ключ — DraconDex сам проверит и создаст нужные таблицы.';

  @override
  String get sbUrl => 'URL проекта';

  @override
  String get sbKey => 'Publishable-ключ';

  @override
  String get sbKeyStored => 'Ключ уже сохранён — оставьте пустым, чтобы не менять его.';

  @override
  String get sbCheck => 'Проверить проект';

  @override
  String get sbObjects => 'Нужные таблицы и функции';

  @override
  String get sbSchemaVersion => 'Версия схемы';

  @override
  String get sbReady => 'Готово — в проекте есть всё, что нужно синхронизации.';

  @override
  String get sbNeedSetup => 'Нужна установка — некоторых таблиц или функций нет.';

  @override
  String get sbNotChecked => 'Ещё не проверено. Сохраните настройки выше и нажмите «Проверить проект».';

  @override
  String get sbAutoInstall => 'Автоустановка';

  @override
  String get sbAutoInstallHint => 'Publishable-ключ не может создавать таблицы. Вставьте персональный токен доступа Supabase — и DraconDex сам выполнит установочный SQL.';

  @override
  String get sbAccessToken => 'Персональный токен доступа';

  @override
  String get sbAccessTokenHint => 'Используется только для одного запроса и нигде не сохраняется.';

  @override
  String get sbGetToken => 'Получить токен';

  @override
  String get sbManualTitle => 'Или установите вручную';

  @override
  String get sbManualHint => 'Скопируйте SQL, выполните его в SQL-редакторе проекта и снова нажмите «Проверить проект».';

  @override
  String get sbCopySql => 'Копировать SQL';

  @override
  String get sbOpenSqlEditor => 'Открыть SQL-редактор';

  @override
  String get sbOpenApiSettings => 'Открыть настройки API';

  @override
  String get sbOpenAuthProviders => 'Открыть Auth providers';

  @override
  String get sbGoogleOn => 'Вход через Google в этом проекте включён.';

  @override
  String get sbGoogleOff => 'Вход через Google выключен — включите его в Authentication → Providers перед входом.';

  @override
  String get sbInstalled => 'Установка завершена';

  @override
  String get sbClear => 'Удалить проект';

  @override
  String get sbClearConfirm => 'Удалить сохранённые настройки проекта Supabase?';

  @override
  String get sbCleared => 'Настройки Supabase удалены';

  @override
  String get sbErrNoConfig => 'Сначала укажите URL проекта и publishable-ключ.';

  @override
  String get sbErrInvalidUrl => 'Некорректный URL проекта — только https.';

  @override
  String get sbErrBadKey => 'Проект отклонил этот ключ.';

  @override
  String get sbErrUnreachable => 'Не удалось связаться с этим проектом.';

  @override
  String get sbErrNeedsManual => 'Нет токена доступа — воспользуйтесь ручной установкой.';

  @override
  String get sbErrBadAccessToken => 'Этот токен доступа отклонён.';

  @override
  String get sbErrForbidden => 'У этого токена нет прав менять данный проект.';

  @override
  String get sbErrNoProjectRef => 'Для автоустановки нужен URL проекта на supabase.co.';

  @override
  String get sbErrRateLimited => 'Слишком много запросов — попробуйте чуть позже.';

  @override
  String get sbErrSqlError => 'Не удалось выполнить установочный SQL.';

  @override
  String get sbErrNetwork => 'Ошибка сети — не удалось связаться с проектом.';

  @override
  String get sbCopied => 'Скопировано';

  @override
  String get sbNotConfigured => 'Проект ещё не настроен';
  @override
  String get googleAccountTitle => 'Аккаунт Google';

  @override
  String get googleAccountNotConfigured => 'Клиент OAuth ещё не настроен';

  @override
  String get googleAccountSetupTitle => 'Настройка входа через Google';

  @override
  String get googleClientTypeHintNative => 'В Google Cloud Console включите Google Drive API и создайте клиент OAuth типа «Десктопное приложение», затем вставьте его данные ниже.';

  @override
  String get googleClientTypeHintWeb => 'В Google Cloud Console включите Google Drive API и создайте клиент OAuth типа «Веб-приложение», затем вставьте его идентификатор ниже.';

  @override
  String get googleClientIdLabel => 'Идентификатор клиента';

  @override
  String get googleClientSecretLabel => 'Секрет клиента';

  @override
  String get googleClientSecretKept => 'Секрет клиента уже сохранён. Оставьте поле пустым, чтобы сохранить его.';

  @override
  String get googleRedirectUriLabel => 'Разрешённый URI перенаправления';

  @override
  String get googleRedirectUriHint => 'Добавьте этот адрес без изменений в разрешённые URI перенаправления клиента, а адрес этого сайта — в разрешённые источники JavaScript.';

  @override
  String get googleSessionExpired => 'Сеанс истёк — подключитесь снова';

  @override
  String get googleErrNoConfig => 'Сначала введите данные клиента OAuth.';

  @override
  String get googleErrCancelled => 'Вход отменён.';

  @override
  String get googleErrTimeout => 'Время входа истекло.';

  @override
  String get googleErrVerify => 'Не удалось проверить вход. Попробуйте ещё раз.';

  @override
  String get googleErrNetwork => 'Не удалось связаться с Google.';

  @override
  String get googleErrAuth => 'Google отклонил вход.';

  @override
  String get googleErrPopupBlocked => 'Окно входа заблокировано. Разрешите всплывающие окна для этого сайта и повторите попытку.';

  @override
  String get googleErrNotConnected => 'Аккаунт Google не подключён.';

  @override
  String get driveRestoreSettingsTitle => 'Восстановить настройки из Drive';

  @override
  String get driveRestoreSettingsSubtitle => 'Заменяет тему, язык и размер интерфейса значениями из резервной копии.';

  @override
  String get driveSettingsRestoredMessage => 'Настройки восстановлены из Google Drive.';

  @override
  String get driveNoBackupMessage => 'Резервная копия в Google Drive не найдена.';

  @override
  String get driveWebDatabaseNote => 'В браузерной версии сохраняются только настройки — база данных остаётся на этом устройстве.';

  @override
  String get hubNestTitle => 'Гнездо Нексуса';

  @override
  String get hubPanelShow => 'Показать панель хаба';

  @override
  String get hubPanelHide => 'Скрыть панель хаба';

  @override
  String get railExpand => 'Развернуть панель навигации';

  @override
  String get railCollapse => 'Свернуть панель навигации';

  // --- DDX Transfer ---

  @override
  String get transferTitle => 'Передача';

  @override
  String get transferSubtitle => 'Передайте целый Nexus на другое устройство. Без учётной записи и без настройки: отправляющее устройство показывает код, принимающее вводит его, а промежуточная копия удаляется в момент получения.';

  @override
  String get transferTabSend => 'Отправить';

  @override
  String get transferTabReceive => 'Принять';

  @override
  String get transferNexusLabel => 'Nexus';

  @override
  String get transferPickNexus => 'Сначала откройте Nexus, который хотите отправить.';

  @override
  String get transferAllowTyped => 'Разрешить приём вводом кода';

  @override
  String get transferAllowTypedHint => 'Включено — другое устройство может ввести код и PIN, но пока идёт ожидание, служба хранит ключ, запечатанный этим PIN. Выключено — единственный вход через QR-код, и служба совсем не может прочитать файл.';

  @override
  String get transferCreate => 'Создать передачу';

  @override
  String get transferCode => 'Код передачи';

  @override
  String get transferPin => 'PIN';

  @override
  String get transferCopyLink => 'Скопировать ссылку';

  @override
  String get transferModeTyped => 'Отсканируйте QR или введите код и PIN. Пока идёт ожидание, служба хранит ключ, запечатанный PIN.';

  @override
  String get transferModeQr => 'Только QR-код. Ключ никогда не попадает на сервер, поэтому открыть это может только сканирующее устройство.';

  @override
  String get transferExpiry => 'Истекает через 30 минут и удаляется в момент получения.';

  @override
  String get transferWaiting => 'Ожидание другого устройства…';

  @override
  String get transferClaimed => 'Другое устройство проверило код и скачивает…';

  @override
  String get transferDone => 'Получено. Копия на сервере удалена.';

  @override
  String get transferExpiredNotice => 'Истекло, прежде чем кто-то успел принять.';

  @override
  String get transferVerify => 'Проверить';

  @override
  String get transferFound => 'Передача найдена';

  @override
  String get transferProject => 'Nexus';

  @override
  String get transferSize => 'Размер';

  @override
  String get transferCreated => 'Создано';

  @override
  String get transferSource => 'Отправлено с';

  @override
  String get transferReceiveAsNew => 'Он придёт как новый Nexus. Ничего из того, что у вас уже есть, не затрагивается.';

  @override
  String get transferReceiveAction => 'Принять';

  @override
  String get transferReceived => 'Nexus получен';

  @override
  String get transferErrNetwork => 'Не удалось связаться со службой передачи.';

  @override
  String get transferErrBadCode => 'Этот код передачи или PIN неверен.';

  @override
  String get transferErrLocked => 'Слишком много неверных PIN. Эта передача заблокирована на время.';

  @override
  String get transferErrExpired => 'Эта передача истекла. Попросите новый код.';

  @override
  String get transferErrGone => 'Этой передачи больше нет — её приняли или отменили.';

  @override
  String get transferErrNotReady => 'Другое устройство ещё не закончило загрузку.';

  @override
  String get transferErrTooLarge => 'Этот Nexus больше, чем допускает одна передача.';

  @override
  String get transferErrBadToken => 'Эта сессия передачи больше недействительна. Начните заново.';

  @override
  String get transferErrBadKey => 'Ссылка неполная — часть с ключом отсутствует или повреждена.';

  @override
  String get transferErrQrOnly => 'Отправитель разрешил только QR-код. Отсканируйте его вместо ввода.';

  @override
  String get transferErrBadPayload => 'Не удалось прочитать полученный файл.';

  @override
  String get transferErrServer => 'В службе передачи произошла ошибка.';

  @override
  String get transferSending => 'Отправка…';

  @override
  String get transferCopied => 'Ссылка скопирована';

  @override
  String get transferCancel => 'Отмена';

  @override
  String get transferPasteLink => 'Или вставьте ссылку передачи';

  @override
  String get transferPasteLinkHint => 'Ссылка несёт ключ в себе, поэтому работает даже если отправитель разрешил только QR-код.';
}
