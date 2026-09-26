// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'DraconDex';

  @override
  String get nexusTitle => 'DraconDex';

  @override
  String get nexusSubtitle => '小说数据管理';

  @override
  String get moduleGlobalTags => '标签';

  @override
  String get moduleColors => '颜色';

  @override
  String get moduleSettings => '设置';

  @override
  String get btnNew => '新建';

  @override
  String get btnSave => '保存';

  @override
  String get btnCancel => '取消';

  @override
  String get btnDelete => '删除';

  @override
  String get btnEdit => '编辑';

  @override
  String get btnClose => '关闭';

  @override
  String get btnAdd => '添加';

  @override
  String get btnImport => '导入数据库';

  @override
  String get btnExport => '导出数据库';

  @override
  String get labelName => '名称';

  @override
  String get labelMemo => '备注';

  @override
  String get labelColor => '颜色';

  @override
  String get labelNote => '笔记';

  @override
  String get labelTags => '标签';

  @override
  String get labelSearch => '搜索...';

  @override
  String get newHashtag => '新建标签';

  @override
  String get noTags => '还没有标签。';

  @override
  String get noColors => '颜色面板为空。';

  @override
  String get noResults => '未找到结果。';

  @override
  String get confirmDeleteTitle => '确认删除';

  @override
  String get confirmDeleteMessage => '此操作无法撤销。';

  @override
  String get colorInUse => '此颜色正在使用中，无法删除。';

  @override
  String get themeLabel => '主题';

  @override
  String get themeMidnight => 'Midnight';

  @override
  String get themeMoonlight => 'Moonlight';

  @override
  String get themeDaylight => 'Daylight';

  @override
  String get themeShowAll => '显示全部';

  @override
  String get themeShowLess => '收起';

  @override
  String get pageLayout => '标题布局';

  @override
  String get titleAlign => '标题对齐';

  @override
  String get alignLeft => '左';

  @override
  String get alignCenter => '居中';

  @override
  String get alignRight => '右';

  @override
  String get pageIcon => '标题上方的图标';

  @override
  String get pageCover => '封面图片';

  @override
  String get pageCoverNone => '无封面';

  @override
  String get pageCoverEmpty => '先将图片导入此 Nexus，才能用作封面';

  @override
  String get pageLayoutScope => '仅应用于此页面';

  @override
  String get languageLabel => '语言';

  @override
  String get uiScaleLabel => '界面缩放';

  @override
  String get importSuccess => '数据库导入成功。';

  @override
  String get importFailed => '导入失败，请检查文件。';

  @override
  String get exportSuccess => '数据库已导出。';

  @override
  String get selectColor => '选择颜色';

  @override
  String get recentColors => '最近使用';

  @override
  String get version => '版本 2.1.0';

  @override
  String get btnRename => '重命名';

  @override
  String get btnPin => '置顶';

  @override
  String get btnUnpin => '取消置顶';

  @override
  String get newNexusTitle => '新建 Nexus';

  @override
  String get renameNexusTitle => '重命名 Nexus';

  @override
  String get newModuleTitle => '新建模块';

  @override
  String get renameModuleTitle => '重命名模块';

  @override
  String get newModuleTooltip => '新建模块';

  @override
  String get newNexusTooltip => '新建 Nexus';

  @override
  String get emptyNexusMessage => '还没有 Nexus，点击 + 创建一个。';

  @override
  String get emptyModuleMessage => '空空如也，点击 + 添加模块。';

  @override
  String get deleteNexusMessage => '这将删除其中的所有模块，此操作无法撤销。';

  @override
  String get deleteModuleMessage => '这也会删除其中嵌套的所有模块，此操作无法撤销。';

  @override
  String get labelKind => '类型';

  @override
  String get kindContentUnavailable => '此模块类型在移动端尚未完全支持 — 将使用下方的共用备注字段。';

  @override
  String get notesHint => '为此模块添加备注…';

  @override
  String get authorChapters => '章节';

  @override
  String get authorNewChapter => '新建章节';

  @override
  String get authorNoChapters => '还没有章节';

  @override
  String get authorContentHint => '撰写本章…';

  @override
  String get scribeSessions => '会话';

  @override
  String get scribeNewSession => '新建会话';

  @override
  String get scribeNoSessions => '还没有会话';

  @override
  String get scribeMessageHint => '输入消息…';

  @override
  String get scribeSwitchSide => '切换左右';

  @override
  String get chroniclerEvents => '事件';

  @override
  String get chroniclerNewEvent => '新建事件';

  @override
  String get chroniclerNoEvents => '还没有事件';

  @override
  String get chroniclerUntitledEvent => '未命名事件';

  @override
  String get chroniclerStart => '开始';

  @override
  String get chroniclerYear => '年';

  @override
  String get chroniclerMonth => '月';

  @override
  String get chroniclerDay => '日';

  @override
  String get chroniclerHour => '时';

  @override
  String get chroniclerMinute => '分';

  @override
  String get chroniclerHasEnd => '有结束日期';

  @override
  String get chroniclerStory => '故事';

  @override
  String get classifierFields => '字段';

  @override
  String get classifierNewField => '新建字段';

  @override
  String get classifierNoFields => '还没有字段';

  @override
  String get classifierItems => '条目';

  @override
  String get classifierNewItem => '新建条目';

  @override
  String get classifierNoItems => '还没有条目';

  @override
  String get classifierDeleteFieldWarning => '这也会删除每个条目在该字段中的值。';

  @override
  String get narratorScenes => '场景';

  @override
  String get narratorNewScene => '新建场景';

  @override
  String get narratorNoScenes => '还没有场景';

  @override
  String get narratorScript => '剧本';

  @override
  String get narratorNewLine => '新建台词';

  @override
  String get narratorNoLines => '还没有台词';

  @override
  String get narratorSpeaker => '说话者';

  @override
  String get narratorLine => '台词';

  @override
  String get narratorRoutes => '路线';

  @override
  String get narratorLeadsTo => '通向';

  @override
  String get narratorNoRoutes => '还没有路线';

  @override
  String get viewerResults => '结果';

  @override
  String get viewerNoFilter => '尚未设置筛选 — 打开筛选以选择此视图显示的内容。';

  @override
  String get viewerNoResults => '没有内容符合此筛选';

  @override
  String get viewerUntitled => '未命名';

  @override
  String get filterTitle => '筛选';

  @override
  String get filterExplain => '同一组内的规则必须全部符合，任意一组符合即可。';

  @override
  String get filterAnd => '并且';

  @override
  String get filterOr => '或者';

  @override
  String get filterAddRule => '添加规则';

  @override
  String get filterAddGroup => '添加分组';

  @override
  String get filterFieldName => '名称';

  @override
  String get filterFieldHashtag => '标签';

  @override
  String get filterFieldKind => '模块类型';

  @override
  String get filterFieldChildOf => '位于模块内';

  @override
  String get filterFieldHandle => '句柄';

  @override
  String get filterOpIs => '等于';

  @override
  String get filterOpIsNot => '不等于';

  @override
  String get filterOpStartsWith => '开头为';

  @override
  String get filterOpEndsWith => '结尾为';

  @override
  String get filterOpContains => '包含';

  @override
  String get filterPickModule => '选择模块';

  @override
  String get connectorRelations => '关系';

  @override
  String get connectorNoRelations => '还没有关系';

  @override
  String get connectorAddRelation => '添加关系';

  @override
  String get connectorFrom => '从';

  @override
  String get connectorTo => '到';

  @override
  String get connectorLabel => '标签';

  @override
  String get connectorNodes => '此视图中的条目';

  @override
  String get designerBoard => '画板';

  @override
  String get designerNewNode => '新建节点';

  @override
  String get designerNode => '节点';

  @override
  String get designerNodeText => '文本';

  @override
  String get designerEmpty => '还没有节点';

  @override
  String get designerLinkHint => '点按另一个节点以连接';

  @override
  String get designerLinkCancel => '取消连接';

  @override
  String get sketcherPages => '页面';

  @override
  String get sketcherNewPage => '新建页面';

  @override
  String get sketcherNoPages => '还没有页面';

  @override
  String get sketcherDraw => '绘制';

  @override
  String get sketcherPan => '平移';

  @override
  String get sketcherUndo => '撤销上一笔';

  @override
  String get sketcherClear => '清空页面';

  @override
  String get sketcherClearWarning => '这会清除本页所有笔画。';

  @override
  String get locatorAreas => '区域';

  @override
  String get locatorNewArea => '新建区域';

  @override
  String get locatorNoAreas => '还没有区域';

  @override
  String get locatorUntitledArea => '未命名区域';

  @override
  String get locatorToolDraw => '绘制';

  @override
  String get locatorToolMove => '移动';

  @override
  String get locatorUndoPoint => '撤销上一个点';

  @override
  String get locatorDrawHint => '点按地图放置点';

  @override
  String get locatorDeleteAreaWarning => '这会删除该区域及其所有点。';

  @override
  String get wandererPins => '图钉';

  @override
  String get wandererNoPins => '还没有图钉';

  @override
  String get wandererPlacing => '放置中';

  @override
  String get wandererPlaceHint => '点按地图放置图钉';

  @override
  String get wandererPin => '图钉';

  @override
  String get wandererLabel => '标签';

  @override
  String get wandererLinkedEvent => '关联事件';

  @override
  String get wandererNoLink => '未关联';

  @override
  String get wandererNoEvents => '此 Nexus 中还没有时间线事件';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsData => '数据';

  @override
  String get settingsAbout => '关于';

  @override
  String get exportDbTitle => '导出数据库';

  @override
  String get exportDbSubtitle => '分享 .db 文件以将数据转移到电脑或其他设备';

  @override
  String get importDbTitle => '导入数据库';

  @override
  String get importDbSubtitle => '合并来自 DraconDex .db 文件的数据';

  @override
  String get checkUpdatesTitle => '检查更新';

  @override
  String get checkUpdatesSubtitle => '查看此项目的 GitHub Releases — 安装前总会先询问';

  @override
  String get upToDateMessage => '您使用的已是最新版本。';

  @override
  String get importingMessage => '导入中…';

  @override
  String get importCompleteMessage => '导入完成。';

  @override
  String get importFailedMessage => '导入失败。';

  @override
  String get exportFailedMessage => '导出失败。';

  @override
  String get saveFailedMessage => '保存失败。';

  @override
  String get webBackupUnsupportedMessage => '网页版不支持此功能。';

  @override
  String get driveBackupTitle => 'Google 云端硬盘备份';

  @override
  String get driveConnectedAs => '已连接:';

  @override
  String get driveNotConnected => '未连接';

  @override
  String get driveConnect => '连接';

  @override
  String get driveDisconnect => '断开连接';

  @override
  String get driveBackupNow => '立即备份';

  @override
  String get driveRestoreTitle => '从 Google 云端硬盘恢复';

  @override
  String get driveRestoreSubtitle => '将 Drive 备份合并到当前数据';

  @override
  String get driveConnectFailedMessage => '连接失败。';

  @override
  String get driveBackingUpMessage => '正在备份到 Google 云端硬盘…';

  @override
  String get driveBackupSuccessMessage => '备份完成。';

  @override
  String get driveBackupFailedMessage => '备份失败。';

  @override
  String get addColorTitle => '添加颜色';

  @override
  String get colorPaletteTitle => '调色板';

  @override
  String get hashtagsTitle => '标签';

  @override
  String get editHashtagTitle => '编辑标签';

  @override
  String get tagNameLabel => '标签名称';

  @override
  String get removeColorConfirmTitle => '移除该颜色？';

  @override
  String get deleteHashtagConfirmTitle => '删除该标签？';

  @override
  String get viewModeTitle => '视图模式';

  @override
  String get viewModeList => '列表';

  @override
  String get viewModeGrid => '网格';

  @override
  String get viewModeCompact => '紧凑';

  @override
  String get builderNexusRootLabel => 'Nexus 根目录';

  // --- Supabase project setup (features/settings/supabase_setup_screen.dart) ---

  @override
  String get settingPageSupabase => 'Supabase 项目';

  @override
  String get sbIntro => '把你自己的 Supabase 项目当作云同步的后端。粘贴项目 URL 和 publishable 密钥，DraconDex 会自动检查并安装所需的数据表。';

  @override
  String get sbUrl => '项目 URL';

  @override
  String get sbKey => 'Publishable 密钥';

  @override
  String get sbKeyStored => '已保存一个密钥 — 留空即保持不变。';

  @override
  String get sbCheck => '检查项目';

  @override
  String get sbObjects => '所需的表与函数';

  @override
  String get sbSchemaVersion => '架构版本';

  @override
  String get sbReady => '已就绪 — 该项目具备云同步所需的一切。';

  @override
  String get sbNeedSetup => '需要安装 — 缺少部分表或函数。';

  @override
  String get sbNotChecked => '尚未检查。请先保存上面的设置，再点击"检查项目"。';

  @override
  String get sbAutoInstall => '自动安装';

  @override
  String get sbAutoInstallHint => 'publishable 密钥无法创建数据表。粘贴 Supabase 个人访问令牌，DraconDex 会替你执行安装 SQL。';

  @override
  String get sbAccessToken => '个人访问令牌';

  @override
  String get sbAccessTokenHint => '仅用于这一次请求，不会保存。';

  @override
  String get sbGetToken => '获取令牌';

  @override
  String get sbManualTitle => '或者手动安装';

  @override
  String get sbManualHint => '复制 SQL，在项目的 SQL 编辑器中执行，然后再次点击"检查项目"。';

  @override
  String get sbCopySql => '复制 SQL';

  @override
  String get sbOpenSqlEditor => '打开 SQL 编辑器';

  @override
  String get sbOpenApiSettings => '打开 API 设置';

  @override
  String get sbOpenAuthProviders => '打开身份验证提供方';

  @override
  String get sbGoogleOn => '该项目已启用 Google 登录。';

  @override
  String get sbGoogleOff => 'Google 登录未启用 — 登录前请在 Authentication → Providers 中开启。';

  @override
  String get sbInstalled => '安装完成';

  @override
  String get sbClear => '移除项目设置';

  @override
  String get sbClearConfirm => '要移除已保存的 Supabase 项目设置吗？';

  @override
  String get sbCleared => '已移除 Supabase 设置';

  @override
  String get sbErrNoConfig => '请先填写项目 URL 和 publishable 密钥。';

  @override
  String get sbErrInvalidUrl => '项目 URL 无效 — 只支持 https。';

  @override
  String get sbErrBadKey => '项目拒绝了该密钥。';

  @override
  String get sbErrUnreachable => '无法连接到该项目。';

  @override
  String get sbErrNeedsManual => '没有访问令牌 — 请改用手动步骤。';

  @override
  String get sbErrBadAccessToken => '该访问令牌被拒绝。';

  @override
  String get sbErrForbidden => '该令牌无权修改这个项目。';

  @override
  String get sbErrNoProjectRef => '自动安装需要 supabase.co 的项目 URL。';

  @override
  String get sbErrRateLimited => '请求过于频繁 — 请稍后再试。';

  @override
  String get sbErrSqlError => '安装 SQL 执行失败。';

  @override
  String get sbErrNetwork => '网络错误 — 无法连接到项目。';

  @override
  String get sbCopied => '已复制';

  @override
  String get sbNotConfigured => '尚未设置项目';
  @override
  String get googleAccountTitle => 'Google 帐户';

  @override
  String get googleAccountNotConfigured => '尚未设置 OAuth 客户端';

  @override
  String get googleAccountSetupTitle => 'Google 登录设置';

  @override
  String get googleClientTypeHintNative => '在 Google Cloud Console 中启用 Google Drive API，创建类型为“桌面应用”的 OAuth 客户端，然后将信息粘贴到下方。';

  @override
  String get googleClientTypeHintWeb => '在 Google Cloud Console 中启用 Google Drive API，创建类型为“Web 应用”的 OAuth 客户端，然后将客户端 ID 粘贴到下方。';

  @override
  String get googleClientIdLabel => '客户端 ID';

  @override
  String get googleClientSecretLabel => '客户端密钥';

  @override
  String get googleClientSecretKept => '已保存客户端密钥。留空则保持不变。';

  @override
  String get googleRedirectUriLabel => '已获授权的重定向 URI';

  @override
  String get googleRedirectUriHint => '请将此地址原样添加到客户端的“已获授权的重定向 URI”，并将本站地址添加到“已获授权的 JavaScript 来源”。';

  @override
  String get googleSessionExpired => '会话已过期 — 请重新连接';

  @override
  String get googleErrNoConfig => '请先填写 OAuth 客户端信息。';

  @override
  String get googleErrCancelled => '登录已取消。';

  @override
  String get googleErrTimeout => '登录超时。';

  @override
  String get googleErrVerify => '无法验证此次登录，请重试。';

  @override
  String get googleErrNetwork => '无法连接到 Google。';

  @override
  String get googleErrAuth => 'Google 拒绝了此次登录。';

  @override
  String get googleErrPopupBlocked => '登录窗口被拦截。请允许本站弹出式窗口后重试。';

  @override
  String get googleErrNotConnected => '尚未连接 Google 帐户。';

  @override
  String get driveRestoreSettingsTitle => '从 Drive 恢复设置';

  @override
  String get driveRestoreSettingsSubtitle => '用备份中的主题、语言和界面大小覆盖当前设置。';

  @override
  String get driveSettingsRestoredMessage => '已从 Google Drive 恢复设置。';

  @override
  String get driveNoBackupMessage => '在 Google Drive 上找不到备份。';

  @override
  String get driveWebDatabaseNote => '浏览器版本只备份设置，数据库仍保留在本设备上。';

  @override
  String get hubNestTitle => '枢纽巢';

  @override
  String get hubPanelShow => '显示枢纽面板';

  @override
  String get hubPanelHide => '隐藏枢纽面板';

  @override
  String get railExpand => '展开导航栏';

  @override
  String get railCollapse => '收起导航栏';

  // --- DDX Transfer ---

  @override
  String get transferTitle => '传输';

  @override
  String get transferSubtitle => '把整个 Nexus 交给另一台设备。无需账号、无需设置 — 发送方显示一组代码，接收方输入它，中转的副本在送达的那一刻被删除。';

  @override
  String get transferTabSend => '发送';

  @override
  String get transferTabReceive => '接收';

  @override
  String get transferNexusLabel => 'Nexus';

  @override
  String get transferPickNexus => '请先打开要发送的 Nexus。';

  @override
  String get transferAllowTyped => '允许通过手动输入代码接收';

  @override
  String get transferAllowTypedHint => '开启后对方可以手动输入代码和 PIN，代价是等待期间服务器会保管用该 PIN 封装的密钥。关闭后只能通过二维码接收，服务器完全无法读取文件。';

  @override
  String get transferCreate => '创建传输';

  @override
  String get transferCode => '传输代码';

  @override
  String get transferPin => 'PIN';

  @override
  String get transferCopyLink => '复制链接';

  @override
  String get transferModeTyped => '扫描二维码，或输入代码和 PIN。等待期间服务器保管用 PIN 封装的密钥。';

  @override
  String get transferModeQr => '仅限二维码。密钥从不抵达服务器，因此除扫描的设备外无人能打开。';

  @override
  String get transferExpiry => '30 分钟后过期，并在被接收的那一刻删除。';

  @override
  String get transferWaiting => '正在等待对方设备…';

  @override
  String get transferClaimed => '对方已验证代码，正在下载…';

  @override
  String get transferDone => '已接收 — 服务器上的副本已删除。';

  @override
  String get transferExpiredNotice => '在被接收之前就已过期。';

  @override
  String get transferVerify => '验证';

  @override
  String get transferFound => '已找到该传输';

  @override
  String get transferProject => 'Nexus';

  @override
  String get transferSize => '大小';

  @override
  String get transferCreated => '创建于';

  @override
  String get transferSource => '来自';

  @override
  String get transferReceiveAsNew => '它会作为一个新的 Nexus 进来，不会改动你已有的任何内容。';

  @override
  String get transferReceiveAction => '接收';

  @override
  String get transferReceived => '已接收 Nexus';

  @override
  String get transferErrNetwork => '无法连接传输服务。';

  @override
  String get transferErrBadCode => '传输代码或 PIN 不正确。';

  @override
  String get transferErrLocked => 'PIN 错误次数过多，此传输已被暂时锁定。';

  @override
  String get transferErrExpired => '此传输已过期，请索取新的代码。';

  @override
  String get transferErrGone => '此传输已不存在 — 已被接收或已取消。';

  @override
  String get transferErrNotReady => '对方设备尚未完成上传。';

  @override
  String get transferErrTooLarge => '此 Nexus 超过了单次传输的上限。';

  @override
  String get transferErrBadToken => '此传输会话已失效，请重新开始。';

  @override
  String get transferErrBadKey => '链接不完整 — 密钥部分缺失或已损坏。';

  @override
  String get transferErrQrOnly => '发送方仅允许二维码。请扫描而不是输入。';

  @override
  String get transferErrBadPayload => '无法读取收到的文件。';

  @override
  String get transferErrServer => '传输服务出现问题。';

  @override
  String get transferSending => '发送中…';

  @override
  String get transferCopied => '已复制链接';

  @override
  String get transferCancel => '取消';

  @override
  String get transferPasteLink => '或粘贴传输链接';

  @override
  String get transferPasteLinkHint => '链接本身带着密钥，所以即使发送方只允许二维码也能用。';

  @override
  String get navNest => '巢';

  @override
  String get navSearch => '搜索';

  @override
  String get navOpenPages => '页面';

  @override
  String get navTools => '工具';

  @override
  String get navMore => '更多';

  @override
  String get openPagesTitle => '已打开的页面';

  @override
  String get openPagesEmpty => '没有打开的页面。打开的每个页面都会留在这里，直到你关闭它。';

  @override
  String get openPagesCloseAll => '全部关闭';

  @override
  String get openPageClose => '关闭页面';

  @override
  String get rowOpen => '打开';

  @override
  String get rowMore => '更多操作';

  @override
  String get crumbEmpty => '里面没有内容';

  @override
  String get goToTitle => '转到';

  @override
  String get goToHint => '名称、路径或 @handle';

  @override
  String get searchHint => '搜索名称、文本和命令';

  @override
  String get searchThings => '事物';

  @override
  String get searchContent => '内容';

  @override
  String get searchCommands => '命令';

  @override
  String get searchEmpty => '没有匹配结果';

  @override
  String get elementPageSoon => '此元素将在后续更新中拥有自己的页面。目前它在所属模块内打开。';

  @override
  String get wikiUnresolved => '还没有叫这个名字的内容。要为它创建一个 Drafter 页面吗？';

  @override
  String get wikiCreateDrafter => '创建';

  @override
  String get btnUndo => '撤销';

  @override
  String get pbAddBlock => '添加区块';

  @override
  String get pbAddHere => '添加到这里';

  @override
  String get pbAddProperty => '添加属性';

  @override
  String get pbArrange => '编排页面';

  @override
  String get pbArrangeDone => '完成';

  @override
  String get pbArrangeHint => '拖动以重新排序。分栏区块整体移动。';

  @override
  String get pbArrangeShared => '这是本模块所有元素共享的布局。若只想改这一页，请先把它分离出来。';

  @override
  String get pbBacklinks => '被链接自';

  @override
  String get pbBlockDeleted => '已移除区块';

  @override
  String get pbBorrow => '来自其他模块的视图';

  @override
  String get pbColumn => '栏';

  @override
  String get pbColumns => '分栏';

  @override
  String get pbDivider => '分隔线';

  @override
  String get pbFullScreen => '全屏';

  @override
  String get pbHeading => '标题';

  @override
  String get pbImage => '图片';

  @override
  String get pbItemBody => '元素';

  @override
  String get pbItemEmpty => '这里还没有内容。';

  @override
  String get pbNoRelated => '还没有链接';

  @override
  String get pbNotOnMobile => '本应用暂不支持';

  @override
  String get pbOnlyOnce => '每页只能放一次';

  @override
  String get pbOpenFullScreen => '打开';

  @override
  String get pbOutgoing => '链接到';

  @override
  String get pbPropName => '名称';

  @override
  String get pbPropType => '类型';

  @override
  String get pbProperties => '属性';

  @override
  String get pbRelated => '相关';

  @override
  String get pbRelations => '关系';

  @override
  String get pbRevert => '恢复共享布局';

  @override
  String get pbSharedLayout => '本模块所有元素页共享的布局。';

  @override
  String get pbSourceGone => '显示的内容已不存在';

  @override
  String get pbSplit => '让此页使用自己的布局';

  @override
  String get pbTags => '标签';

  @override
  String get pbText => '文本';

  @override
  String get pbTextEmpty => '空文本 — 轻点以书写';

  @override
  String get propTypeCheckbox => '复选框';

  @override
  String get propTypeDate => '日期';

  @override
  String get propTypeNumber => '数字';

  @override
  String get propTypeText => '文本';

  @override
  String get propTypeTextarea => '长文本';

  @override
  String get propTypeUrl => '链接';

  @override
  String get viewTable => '表格';

  @override
  String get viewListDetail => '列表 · 详情';

  @override
  String get viewRelations => '关系';

  @override
  String get viewGrid => '网格';

  @override
  String get viewScene => '场景';

  @override
  String get viewGraph => '关系图';

  @override
  String get viewCards => '卡片';

  @override
  String get viewBoard => '看板';

  @override
  String get viewEdges => '连线';

  @override
  String get viewArea => '区域';

  @override
  String get viewMap => '地图';

  @override
  String get viewTimeline => '时间线';

  @override
  String get viewCanvas => '画布';

  @override
  String get viewPages => '页面';

  @override
  String get viewGallery => '画廊';

  @override
  String get viewExport => '导出';

  @override
  String get viewEditor => '编辑器';

  @override
  String get viewOutline => '大纲';

  @override
  String get viewReading => '阅读';

  @override
  String get viewBook => '书本';

  @override
  String get viewRoutes => '路线';

  @override
  String get viewReader => '阅读器';

  @override
  String get viewDialogue => '对话';

  @override
  String get viewOneline => '单线';

  @override
  String get viewDownline => '纵向';

  @override
  String get viewCompare => '对比';

  @override
  String get viewCalendar => '日历';

  @override
  String get viewList => '列表';

  @override
  String get viewMatrix => '矩阵';

  @override
  String get viewChat => '聊天';

  @override
  String get viewTranscript => '记录';

  @override
  String get clsNoRelations => '这些元素之间还没有链接';

  @override
  String get clsTypeText => '文本';

  @override
  String get clsTypeTextarea => '长文本';

  @override
  String get clsTypeNumber => '数字';

  @override
  String get clsTypeDate => '日期';

  @override
  String get clsTypeSelect => '单选';

  @override
  String get clsTypeMulti => '多选';

  @override
  String get clsTypeCheckbox => '复选框';

  @override
  String get clsTypeUrl => '链接 (URL)';

  @override
  String get clsTypeRelation => '关系';

  @override
  String get clsTypeFormula => '公式';

  @override
  String get clsFieldType => '字段类型';

  @override
  String get clsChoices => '选项（每行一个）';

  @override
  String get clsFormulaHint => '例如 {HP} * 2';

  @override
  String get clsEditField => '编辑字段';

  @override
  String get clsAddLink => '添加链接';

  @override
  String get dateDay => '日';

  @override
  String get dateMonth => '月';

  @override
  String get dateYear => '年';

  @override
  String get dateHour => '时';

  @override
  String get dateMinute => '分';

  @override
  String get btnClear => '清除';

  @override
  String get groupBy => '分组依据';

  @override
  String get groupModule => '模块';

  @override
  String get relDirected => '单向 (→)';

  @override
  String get exhGroup => '分组';

  @override
  String get exhNote => '便签';

  @override
  String get exhAddElement => '放置元素';

  @override
  String get exhAddNote => '添加便签';

  @override
  String get exhAddGroup => '添加分组';

  @override
  String get exhRemoveFromScene => '从场景移除';

  @override
  String get exhSceneEmpty => '尚未放置任何内容 — 放置元素或添加便签。';

  @override
  String get auStatusIdea => '构思';

  @override
  String get auStatusDraft => '草稿';

  @override
  String get auStatusRevised => '已修订';

  @override
  String get auStatusDone => '完成';

  @override
  String get auSynopsis => '梗概';

  @override
  String get auPov => '视角';

  @override
  String get btnPrevious => '上一个';

  @override
  String get btnNext => '下一个';

  @override
  String get narAddRoute => '添加路线';

  @override
  String get narScript => '剧本';

  @override
  String get narPlayTest => '试玩';

  @override
  String get narRestart => '重新开始';

  @override
  String get narShowHidden => '显示隐藏选项';

  @override
  String get narVariables => '变量';

  @override
  String get narNoVariables => '此 Nexus 中没有故事变量';

  @override
  String get narPlayEnd => '结束 — 没有后续路线。';

  @override
  String get narNoOptionOpen => '在这些变量下没有可选项。';

  @override
  String get narHiddenByCondition => '因条件隐藏';

  @override
  String get chrCompareWith => '对比';

  @override
  String get chrNoOtherLine => '此 Nexus 中没有可对比的其他 Chronicler';

  @override
  String get scribeNoMessages => '暂无消息';

  @override
  String get wndLocator => '地图 (Locator)';

  @override
  String get wndNoLocator => '此 Nexus 中还没有 Locator — 图钉位于其区域中。';

  @override
  String get wndPickLocator => '选择这些图钉所在区域的 Locator。';

  @override
  String get wndNoAreas => '该 Locator 还没有区域';

  @override
  String get wndAddPin => '在此放置图钉';

  @override
  String get skExportPng => '以 PNG 分享';

  @override
  String get dgPanel => '分格（漫画）';

  @override
  String get dgBalloon => '对话气泡';

  @override
  String get dgLinkFrom => '连接到…';

  @override
  String get dgPanelShows => '显示 Sketcher 页面';

  @override
  String get dgBalloonSpeaker => '说话者';

  @override
  String get dgNumberByPosition => '按位置编号';

  @override
  String get dgShowOrder => '显示阅读顺序';

  @override
  String get divNewTable => '新表';

  @override
  String get divDice => '骰子';

  @override
  String get divDiceHelp => '留空 = 按权重';

  @override
  String get divBadDice => '不是骰子表达式';

  @override
  String get divModePick => '抽一个';

  @override
  String get divModeJoin => '全部连接';

  @override
  String get divWeighted => '按权重';

  @override
  String get divEntryText => '文本';

  @override
  String get divFrom => '从';

  @override
  String get divTo => '到';

  @override
  String get divWeight => '权重';

  @override
  String get divRollsTable => '在此掷另一张表';

  @override
  String get divLinkEntity => '指向某物';

  @override
  String get divUnlink => '移除链接';

  @override
  String get divNoTables => '还没有表';

  @override
  String get divRoll => '掷骰';

  @override
  String get divEntries => '条目';

  @override
  String get divNoEntries => '还没有条目';

  @override
  String get divHistory => '历史';

  @override
  String get divQuickRoll => '直接掷: 3d6';

  @override
  String get trashTitle => '回收站';

  @override
  String get trashMoved => '已移到回收站';

  @override
  String get trashEmptyAll => '清空回收站';

  @override
  String get trashEmptyConfirm => '回收站中的所有内容将被永久删除。';

  @override
  String get trashNothing => '回收站是空的';

  @override
  String get trashNote => '恢复的模块会带回其全部内容和关系——但不包括版本历史。';

  @override
  String get trashRestore => '恢复';

  @override
  String get trashModules => '个模块';

  @override
  String get trashDeleteForever => '永久删除？之后将无法恢复。';

  @override
  String get problemsTitle => '问题';

  @override
  String get problemsLinks => '未解析的链接';

  @override
  String get problemsEmpty => '空模块';

  @override
  String get problemsRelations => '缺少一端的关系';

  @override
  String get problemsNone => '未发现问题';

  @override
  String get assetsTitle => '资源';

  @override
  String get assetsFromDevice => '从此设备添加';

  @override
  String get assetsAddUrl => '添加链接 (URL)';

  @override
  String get assetsNotice => '资源保留在此设备上：同步只带名称，不带文件。';

  @override
  String get assetsNone => '暂无资源';

  @override
  String get assetsTooBig => '太大，无法保存在浏览器中';

  @override
  String get pbChooseImage => '选择图片';

  @override
  String get csvImportTitle => '导入 CSV';

  @override
  String get fromTemplate => '从模板';

  @override
  String get guideTitle => '指南';

  @override
  String get guideDesc => '展示每种类型的小世界';

  @override
  String get guideAdd => '添加指南';

  @override
  String get mddxImport => '导入模块文件 (.mddx)';

  @override
  String get mddxExport => '导出为 .mddx';

  @override
  String get mddxNotModule => '该文件不是 DraconDex 模块';

  @override
  String get kindCatStructure => '结构';

  @override
  String get kindCatView => '视图';

  @override
  String get kindCatData => '数据';

  @override
  String get kindGroupNotes => '笔记与文档';

  @override
  String get kindGroupData => '数据与分类';

  @override
  String get kindGroupMapTime => '地图与时间';

  @override
  String get kindGroupStory => '故事';

  @override
  String get kindGroupDraw => '绘图与设计';

  @override
  String get nexusStartWith => '开始内容';

  @override
  String get nexusStartEmpty => '无 — 空的 Nexus';

  @override
  String get csvPick => '选择 CSV 文件';

  @override
  String get csvHint => '第一行为字段名，第一列为元素名。';

  @override
  String get csvCreate => '创建 Classifier';

  @override
  String get csvSkip => '跳过';

  @override
  String get csvNameColumn => '名称';

  @override
  String get csvTruncated => '仅前 5,000 行';

  @override
  String get csvTooLarge => '文件超过 8 MB';

  @override
  String get csvEmpty => '没有可导入的行 — 需要表头和至少一行';

  @override
  String get kindClassicCollector => '文件夹';

  @override
  String get kindDescCollector => '用于归类其他模块的文件夹';

  @override
  String get kindClassicManager => '项目';

  @override
  String get kindDescManager => '以卡片、列表或表格浏览子模块';

  @override
  String get kindClassicInspector => '详情';

  @override
  String get kindDescInspector => '该项目的单页详情笔记';

  @override
  String get kindClassicClassifier => '分类';

  @override
  String get kindDescClassifier => '用自定义字段对项目分类';

  @override
  String get kindClassicLocator => '地图';

  @override
  String get kindDescLocator => '带图钉和区域的地图';

  @override
  String get kindClassicChronicler => '时间线';

  @override
  String get kindDescChronicler => '带日期事件的时间线';

  @override
  String get kindClassicWanderer => '时间地图';

  @override
  String get kindDescWanderer => '把地图图钉与时间线事件关联';

  @override
  String get kindClassicNarrator => '故事';

  @override
  String get kindDescNarrator => '以路线板连接的对话节点';

  @override
  String get kindClassicAuthor => '书';

  @override
  String get kindDescAuthor => '带章节和写作编辑器的书';

  @override
  String get kindClassicScribe => '聊天';

  @override
  String get kindDescScribe => '聊天式会话笔记';

  @override
  String get kindClassicDrafter => '文档';

  @override
  String get kindDescDrafter => '空白 Markdown 页面';

  @override
  String get kindClassicExhibitor => '展台';

  @override
  String get kindDescExhibitor => '关联项目的场景、图和表格 — 在这里绘制关系';

  @override
  String get kindClassicSketcher => '绘图';

  @override
  String get kindDescSketcher => '自由绘画画布';

  @override
  String get kindClassicDesigner => '图表';

  @override
  String get kindDescDesigner => '用形状和箭头绘制的自由图表';

  @override
  String get kindClassicDiviner => '随机表';

  @override
  String get kindDescDiviner => '随机表与掷骰';

  @override
  String get moduleNameMode => '模块名称';

  @override
  String get moduleNameModeHint => 'Unique = Collector/Manager/… · Classic = 文件夹/项目/…';

  @override
  String get moduleInside => '项';

  @override
  String get nameModeUnique => '独有';

  @override
  String get nameModeClassic => '经典';

  @override
  String get kindRecent => '最近';

  @override
  String get clsLevelable => '可升级';

  @override
  String get clsCondition => '条件';

  @override
  String get levelColLevel => '等级';

  @override
  String get levelColInfo => '信息';

  @override
  String get levelAddRow => '添加行';

  @override
  String get levelNoRows => '暂无行';

  @override
  String get confirmDeleteLevelRow => '删除此行？';

  @override
  String get clsLevelAndCondition => '等级与条件';

  @override
  String get clsLevelAndConditionHint => '将字段变成多行表（等级），或将其值与条件关联。';

  @override
  String get clsInsertAbove => '在上方插入行';

  @override
  String get clsInsertBelow => '在下方插入行';

  @override
  String get exportTitle => '导出…';

  @override
  String get exportPdf => 'PDF';

  @override
  String get exportPdfD => '用于打印、分享或交付印刷';

  @override
  String get exportDocx => 'Word（DOCX）';

  @override
  String get exportDocxD => '在 Word、Google 文档或 Pages 中继续编辑';

  @override
  String get exportEpub => 'EPUB（电子书）';

  @override
  String get exportEpubD => '用于 Apple Books、Kindle、Kobo 或 Calibre';

  @override
  String get exportXlsx => 'Excel（XLSX）';

  @override
  String get exportXlsxD => '每个表一张工作表，可用 Excel、Sheets 或 Numbers 打开';

  @override
  String get exportCsv => 'CSV';

  @override
  String get exportCsvD => '纯表格 — 可通过“导入 CSV”再导回';

  @override
  String get htmlExport => '导出为网站 (HTML)';

  @override
  String get exportMarkdown => '导出为 Markdown (.zip)';

  @override
  String get exportMdAnyD => '带图片的笔记 — 可在 Obsidian 打开';

  @override
  String get exportMddxD => '此模块，用于移到另一个库';

  @override
  String get exportNoPage => '文件夹没有自己的页面';

  @override
  String get exportOnlyDocs => '仅限 Author、Classifier、Chronicler、Drafter 和 Inspector';

  @override
  String get exportOnlyBooks => '仅限 Author 的书';

  @override
  String get exportOnlyTables => '仅限 Classifier 和 Chronicler';

  @override
  String get exportGo => '导出';

  @override
  String get exportScope => '包含范围';

  @override
  String get exportScopePage => '此页';

  @override
  String get exportScopeModule => '此模块及所有元素';

  @override
  String get exportScopeInside => '此模块及其中所有内容';

  @override
  String get exportScopeNexus => '整个 Nexus';

  @override
  String get exportPaper => '纸张';

  @override
  String get exportOrientation => '方向';

  @override
  String get exportPortrait => '纵向';

  @override
  String get exportLandscape => '横向';

  @override
  String get exportHeaderFooter => '标题和页码';

  @override
  String get exportToc => '目录页';

  @override
  String get exportCsvHint => '单个表格：Classifier 的元素，或 Chronicler 的第一条时间线。不含公式字段。可通过“导入 CSV”读回。';

  @override
  String get exportXlsxHint => '每个表一张工作表（Chronicler 的每条时间线），表头加粗并冻结。不含公式字段。';

  @override
  String get exportMdAnyHint => '每个元素一个 .md（字段为属性），页面图片放在 assets/。可在 Obsidian 中将文件夹作为库打开。';

  @override
  String get exportDocxHint => '每章、每个元素或事件一个标题（显示在 Word 导航窗格），字段为表格，含页面图片，章与章之间分页。';

  @override
  String get exportEpubHint => '每章一个文件并附目录；书页标题封面即为封面。';

  @override
  String get exportMddxHint => '另一个 DraconDex 库可导入的 .mddx 文件。';

  @override
  String get exportFormulaSkipped => '未包含的公式字段：{names}';

  @override
  String get exportMoreTimelines => 'CSV 只含一条时间线 — 其余 {n} 条请用 Excel 导出';

  @override
  String get exportMediaMissing => '有 {n} 张图片找不到，已略过';

  @override
  String get exportMarkdownEmpty => '还没有可导出的内容';

  @override
  String get exportWorking => '正在绘制页面…';

  @override
  String get exportPictures => '图片';

  @override
  String get exportRows => '行';

  @override
  String get exportHtmlPageD => '将此页导出为网页，图片一并附带';

  @override
  String get exportHtmlPageHint => '包含 index.html 及 media/ 中图片的 .zip — 解压后用任意浏览器打开 index.html。';

  @override
  String get exportPrint => '打印…';

  @override
  String get pcVideo => '视频';

  @override
  String get pcAudio => '音频';

  @override
  String get pcPdf => 'PDF';

  @override
  String get pcModel3d => '3D 模型';

  @override
  String get pcMedia => '混合媒体';

  @override
  String get pcMediaEmpty => '暂无文件。';

  @override
  String get pbChooseFile => '选择文件';

  @override
  String get pcAddFile => '添加文件';

  @override
  String get pcOpenIn => '用其他应用打开';

  @override
  String get mediaOpenFailed => '无法打开此文件';
}
