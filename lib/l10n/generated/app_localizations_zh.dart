// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'ThkTree';

  @override
  String get settingsTitle => 'ThkTree · 设置';

  @override
  String get language => '语言';

  @override
  String languageSubtitle(String name) {
    return '$name';
  }

  @override
  String get systemDefault => '跟随系统';

  @override
  String get english => 'English';

  @override
  String get chinese => '中文';

  @override
  String get noThemesYet => '开始你的第一个知识主题';

  @override
  String get newTheme => '新建主题';

  @override
  String get titleHint => '标题';

  @override
  String get titleCannotBeEmpty => '标题不能为空，请输入后再保存';

  @override
  String get cancel => '取消';

  @override
  String get create => '创建';

  @override
  String get back => '返回';

  @override
  String get tree => '树';

  @override
  String get branch => '分支';

  @override
  String get save => '保存';

  @override
  String get renameNote => '重命名笔记';

  @override
  String get delete => '删除';

  @override
  String get close => '关闭';

  @override
  String get copied => '已复制';

  @override
  String get loadingSettings => '加载设置中...';

  @override
  String get loadingLogger => '加载日志器中...';

  @override
  String get loadingPaths => '加载路径中...';

  @override
  String get logFile => '日志文件';

  @override
  String get remoteLogging => '远程日志';

  @override
  String get enabled => '已启用';

  @override
  String get disabled => '已禁用';

  @override
  String get viewLogs => '查看日志';

  @override
  String get logsTail => '日志（尾部）';

  @override
  String get emptyLogs => '（空）';

  @override
  String get llmProviderTitle => 'LLM 服务商';

  @override
  String get llmApiKey => 'API 密钥';

  @override
  String llmApiKeyTitle(String providerName) {
    return '$providerName API 密钥';
  }

  @override
  String get apiKeySet => '已设置';

  @override
  String get apiKeyNotSet => '未设置';

  @override
  String get llmModel => '模型';

  @override
  String llmModelTitle(String providerName) {
    return '$providerName 模型';
  }

  @override
  String get dataRoot => '数据根目录';

  @override
  String treeTitle(Object title) {
    return '$title · 树';
  }

  @override
  String get emptyTree => '种下第一颗种子，点击 + 开始对话';

  @override
  String get treeTitleSearchHint => '搜索节点标题';

  @override
  String get treeTitleSearchNoResults => '无匹配标题';

  @override
  String get collapseAll => '全部折叠';

  @override
  String get expandAll => '全部展开';

  @override
  String get refresh => '刷新';

  @override
  String get newSession => '新建会话';

  @override
  String get newBranch => '新建分支';

  @override
  String get deleteItem => '删除项目';

  @override
  String deleteConfirm(Object title) {
    return '删除「$title」？';
  }

  @override
  String targetNodeId(Object nodeId) {
    return '目标 nodeId：$nodeId';
  }

  @override
  String get deleteUnderstand => '我了解仅删除所选 nodeId 的子树。';

  @override
  String deleteDescWithChildren(int count) {
    return '将删除所选节点以及 $count 个子节点。';
  }

  @override
  String get deleteDescOnly => '将仅删除所选节点。';

  @override
  String keptSameTitleNodes(int count) {
    return '将保留的同名节点（$count）：';
  }

  @override
  String deletedCount(int count) {
    return '已删除 $count 个项目';
  }

  @override
  String branchFailed(String error) {
    return '分支失败：$error';
  }

  @override
  String deleteFailed(String error) {
    return '删除失败：$error';
  }

  @override
  String saveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get noMessagesYet => '暂无消息';

  @override
  String get messageHint => '消息';

  @override
  String get send => '发送';

  @override
  String get stop => '停止';

  @override
  String get polishSummary => '打磨总结';

  @override
  String get summaryHint => '修改总结...';

  @override
  String summaryBanner(Object title) {
    return '请打磨总结内容，确认后将作为新分支「$title」的起点';
  }

  @override
  String get confirmSummary => '确认使用此总结';

  @override
  String get generatingSummary => '正在生成总结...';

  @override
  String get createBranch => '创建分支';

  @override
  String get creatingBranch => '正在创建分支...';

  @override
  String get skipSummary => '携带原始上下文';

  @override
  String get blankBranch => '全新开始';

  @override
  String get pleaseGenerateSummary => '请先生成总结内容';

  @override
  String branchCreationFailed(Object error) {
    return '创建分支失败：$error';
  }

  @override
  String get userRole => '用户';

  @override
  String get assistantRole => '助手';

  @override
  String get systemRole => '系统';

  @override
  String get streamingStatus => '生成中';

  @override
  String errorStatus(Object code) {
    return '错误：$code';
  }

  @override
  String get errorUnknown => '未知';

  @override
  String get expandTable => '扩大查看表格';

  @override
  String get reasoningTitle => '思考过程';

  @override
  String get showReasoning => '查看思考过程';

  @override
  String get hideReasoning => '收起思考过程';

  @override
  String get copy => '复制';

  @override
  String get addToNote => '添加到笔记';

  @override
  String get notes => '笔记';

  @override
  String get selectNote => '选择一个笔记来追加内容...';

  @override
  String get noNotesYet => '空白页，等你落笔';

  @override
  String get newNote => '新建笔记';

  @override
  String noteCount(int count) {
    return '$count 篇笔记';
  }

  @override
  String get uncategorized => '未分类';

  @override
  String get llmProvidersTitle => '模型提供商';

  @override
  String get llmProviderCustom => '自定义';

  @override
  String get addCustomProvider => '添加自定义提供商';

  @override
  String get providerName => '提供商名称';

  @override
  String get providerBaseUrl => '访问地址';

  @override
  String get providerDefaultUrl => '默认地址';

  @override
  String get providerApiKey => 'API 密钥';

  @override
  String get apiKeyConfigured => '已配置';

  @override
  String get apiKeyNotConfigured => '未配置';

  @override
  String modelCount(int count) {
    return '$count 个提供商';
  }

  @override
  String get noModels => '暂无提供商';

  @override
  String get deleteProvider => '删除提供商';

  @override
  String get deleteProviderConfirm => '确定要删除该提供商吗？';

  @override
  String get fetchModels => '获取模型列表';

  @override
  String get fetchingModels => '正在获取模型...';

  @override
  String fetchModelsSuccess(int count) {
    return '成功获取 $count 个模型';
  }

  @override
  String fetchModelsFailed(String error) {
    return '获取模型失败：$error';
  }

  @override
  String get apiKeyInvalid => 'API Key 无效或已过期';

  @override
  String get selectModel => '选择模型';

  @override
  String get searchModels => '搜索模型...';

  @override
  String get noModelsFound => '未找到匹配的模型';

  @override
  String get currentModel => '当前模型';

  @override
  String get noModelSelected => '未选择模型';

  @override
  String contextUsagePercent(int percent) {
    return '上下文：$percent%';
  }

  @override
  String get customProviderHint => '例如：提供商名+模型名，方便识别';

  @override
  String get baseUrlHint => '请输入 API 访问地址';

  @override
  String get apiKeyHint => '请输入 API 密钥';

  @override
  String get saveProvider => '保存';

  @override
  String get editProvider => '编辑提供商';

  @override
  String get copyDefaultUrl => '复制默认地址';

  @override
  String get copiedToClipboard => '已复制到剪贴板';

  @override
  String get pleaseFetchModels => '请先在设置中配置提供商并获取模型列表';

  @override
  String get pleaseConfigureTitleModel => '请在默认模型配置中设置生成标题的模型';

  @override
  String get pleaseConfigureSummaryModel => '请在默认模型配置中设置总结文本的模型';

  @override
  String get createChatFromNote => '从笔记发起对话';

  @override
  String get selectTheme => '选择主题';

  @override
  String get selectTree => '选择 Tree';

  @override
  String get selectLocation => '选择位置';

  @override
  String get asRootChat => '作为根对话';

  @override
  String underNode(String title) {
    return '在「$title」下';
  }

  @override
  String get chatTitle => '对话标题';

  @override
  String get chatCreated => '对话创建成功';

  @override
  String get themesTabLabel => '主题';

  @override
  String get labTabLabel => 'Lab';

  @override
  String get labEmptyHint => '实验功能筹备中';

  @override
  String get keywordRankingTitle => '关键词排行榜';

  @override
  String get keywordRankingSubtitle => '回顾最近的思考脉络';

  @override
  String get keywordRankingComingSoon => 'List 视图即将上线';

  @override
  String get keywordRankingAnalyze => '分析';

  @override
  String get keywordRankingLastUpdated => '上次计算';

  @override
  String get keywordRankingEmpty => '暂无关键词，点击右上角「分析」开始抽取';

  @override
  String get keywordRankingSelectThemes => '选择主题';

  @override
  String get keywordRankingSelectThemesHint => '选择一个主题，分析其下的对话';

  @override
  String get keywordRankingSelectLeaves => '选择对话';

  @override
  String get keywordRankingSelectLeavesHint => '选择需要用 LLM 分析的对话（leaf）';

  @override
  String keywordRankingSelectLeavesSelected(int count) {
    return '已选 $count 个';
  }

  @override
  String get keywordRankingStartAnalysis => '开始分析';

  @override
  String get keywordRankingAnalyzing => '分析中...';

  @override
  String get keywordRankingAnalysisDone => '分析完成';

  @override
  String keywordRankingAnalysisFailed(String error) {
    return '分析失败：$error';
  }

  @override
  String get keywordRankingLeafStatusPending => '待分析';

  @override
  String get keywordRankingLeafStatusFresh => '新鲜';

  @override
  String get keywordRankingLeafStatusStale => '需刷新';

  @override
  String get keywordRankingNoThemes => '暂无主题';

  @override
  String get keywordRankingNoAnalyzableLeaves => '该主题暂无可分析的对话';

  @override
  String get keywordRankingSelectAll => '全选';

  @override
  String get keywordRankingDeselectAll => '取消全选';

  @override
  String get keywordRankingScoreLabel => '分数';

  @override
  String get keywordRankingStaleBadge => '含 stale';

  @override
  String keywordRankingLeafCount(int themes, int leaves, String depth) {
    return '$themes主题 · $leaves对话 · 深度 $depth';
  }

  @override
  String get keywordRankingJumpToChat => '跳转到对话';

  @override
  String get settingsTabLabel => '设置';

  @override
  String get createBranchRawFromSelection => '用所选文字直接创建';

  @override
  String get createBranchSummarizeFromSelection => '总结所选文字后创建';

  @override
  String get chooseTitle => '选择标题';

  @override
  String titleSourceBanner(String source) {
    return '从 $source 创建分支';
  }

  @override
  String get titleSourceSelection => '选中文本';

  @override
  String get titleSourceConversation => '对话';

  @override
  String get titleSourceConversationSummary => '对话总结';

  @override
  String get titleSourceNote => '笔记';

  @override
  String get titleDirectionHint => '方向引导（可选）';

  @override
  String get titleRegenerate => '重新生成';

  @override
  String get titleGenerating => '正在生成候选标题...';

  @override
  String get titleAutoGenFailed => '生成失败';

  @override
  String get titleModelSwitch => '切换模型';

  @override
  String get titleCandidatesEmpty => '暂无候选，请调整方向或重试';

  @override
  String get titleConfirm => '确定';

  @override
  String get summarizing => '正在总结对话...';

  @override
  String get summarizeFailedFallback => '总结失败，将使用原始对话作为分支起点';

  @override
  String get branchModeSheetTitle => '选择创建方式';

  @override
  String get branchModeSummarize => '总结后创建';

  @override
  String get branchModeRaw => '使用原始上下文创建';

  @override
  String get branchModeBlank => '空白分支';

  @override
  String get branchBlankInitialTitle => '临时会话';

  @override
  String get branchModeContinue => '继续';

  @override
  String get networkInterrupted => '网络中断，请重试';

  @override
  String get branchRetry => '重试';

  @override
  String get branchCancelRetry => '取消';

  @override
  String get titleModelTitle => '标题生成模型';

  @override
  String get summaryModelTitle => '对话总结模型';

  @override
  String get notConfigured => '未配置';

  @override
  String get generateTitles => '生成标题';

  @override
  String get generateTitlesHint => '点击生成标题建议';

  @override
  String contextWindowTitle(String modelName) {
    return '为 $modelName 设置上下文窗口大小';
  }

  @override
  String get sourceTypeSelectedText => '选中文本';

  @override
  String get sourceTypeConversation => '对话';

  @override
  String get sourceTypeSummary => '对话总结';

  @override
  String get sourceTypeNote => '笔记';

  @override
  String get sourceTypeUserIdea => '用户补充';

  @override
  String get sourceTypeDocSplit => '文档拆分';

  @override
  String get importDocSplit => '导入文档拆分';

  @override
  String get docSplitInputTitle => '粘贴文档';

  @override
  String get docSplitFeatureTitle => 'AI 文档拆分';

  @override
  String get docSplitStartAnalysis => '开始分析';

  @override
  String get docSplitHintTitle => '粘贴一篇文章，让 AI 帮你拆成树';

  @override
  String get docSplitHintBody => '系统会先分析结构，再在 Chat 中生成一版可调整的树状预览。';

  @override
  String get docSplitViewDetails => '查看详情';

  @override
  String get docSplitPlaceholder => '在这里粘贴文章、方案或会议纪要…\nAI 会先分析结构，再生成可调整的树状预览。';

  @override
  String get docSplitDetailsTitle => '文档拆分说明';

  @override
  String get docSplitDetailsWhatTitle => '这是什么';

  @override
  String get docSplitDetailsWhatBody =>
      '把一篇长文先交给 AI 分析，再转成可调整的树状聊天节点，确认后再创建真实节点。';

  @override
  String get docSplitDetailsFlowTitle => '接下来会发生什么';

  @override
  String get docSplitDetailsFlow1 => '粘贴文档后，AI 会先在 Chat 中分析并生成树结构预览。';

  @override
  String get docSplitDetailsFlow2 => '你可以继续对话，让它合并、重组或简化结构。';

  @override
  String get docSplitDetailsFlow3 => '只有点击“提交树结构”后，这些预览才会变成真实节点。';

  @override
  String get docSplitDetailsBestForTitle => '适合什么内容';

  @override
  String get docSplitDetailsBestForBody =>
      '方案文档、会议纪要、访谈记录、长篇 Markdown 草稿，以及任何适合按层级整理的文本。';

  @override
  String get docSplitDetailsPromptTitle => '可直接使用的提示词';

  @override
  String get docSplitDetailsPrompt1 => '请按主题维度拆分。';

  @override
  String get docSplitDetailsPrompt2 => '请控制在两层结构。';

  @override
  String get docSplitDetailsPrompt3 => '请合并重复内容，让结构更清晰。';

  @override
  String get submitTreeStructure => '提交树结构';

  @override
  String get docSplitParsingFailed => '无法解析树结构，请让 LLM 重新输出标准格式';

  @override
  String get docSplitNoAssistantMessage => '未找到 LLM 回复，请先发送消息';

  @override
  String docSplitSuccess(int count) {
    return '已创建 $count 个节点';
  }

  @override
  String get docSplitEmptyInput => '请粘贴文档文本';

  @override
  String get confirm => '确认';

  @override
  String get swipeDelete => '删除';

  @override
  String get swipeBranch => '分支';

  @override
  String get viewTree => '查看整棵树';

  @override
  String get myQuestions => '本次发言';

  @override
  String get myQuestionsTitle => '我发出的消息';

  @override
  String get myQuestionsEmpty => '本次对话中还没有发言';

  @override
  String get renameNode => '重命名节点';

  @override
  String get enterNewTitle => '输入新标题';

  @override
  String get retry => '重试';

  @override
  String get faceIdLock => 'Face ID 锁定';

  @override
  String get faceIdLockSubtitle => '打开 App 时需要 Face ID 验证';

  @override
  String get error => '错误';

  @override
  String get ok => '确定';

  @override
  String get deleteNote => '删除笔记';

  @override
  String deleteNoteConfirmTitle(String title) {
    return '确认删除「$title」？';
  }

  @override
  String get saveToNote => '存为笔记';

  @override
  String get generateTitle => '生成标题';

  @override
  String get generatingTitle => '正在生成标题…';

  @override
  String get moveNote => '转移';

  @override
  String get noteMoved => '已转移';

  @override
  String get searchTabLabel => '搜索';

  @override
  String get searchHint => '搜索笔记和对话...';

  @override
  String get searchAction => '搜索';

  @override
  String get searchIdleHint => '输入后点击「搜索」';

  @override
  String get searchEmpty => '在知识中寻找连接';

  @override
  String get searchNoResults => '换个角度试试';

  @override
  String get searchError => '搜索出错，请重试';

  @override
  String get searchIndexError => '搜索索引异常';

  @override
  String get searchIndexErrorContent =>
      '搜索索引数据可能已损坏，这不会影响您的笔记内容安全。\n\n是否立即修复索引？';

  @override
  String get repairLater => '稍后';

  @override
  String get repairNow => '立即修复';

  @override
  String get repairComplete => '修复完成';

  @override
  String get repairCompleteContent => '搜索索引已重建完成，现在可以正常搜索了。';

  @override
  String get noTitle => '无标题';

  @override
  String maxNodeDepthReached(int max) {
    return '已达到最大嵌套层级（$max）。无法再创建更深的子分支。';
  }

  @override
  String get startWriting => '开始写点什么...';

  @override
  String get justNow => '刚刚';

  @override
  String minutesAgo(int count) {
    return '$count分钟前';
  }

  @override
  String hoursAgo(int count) {
    return '$count小时前';
  }

  @override
  String daysAgo(int count) {
    return '$count天前';
  }

  @override
  String monthDay(int month, int day) {
    return '$month月$day日';
  }

  @override
  String get pin => '置顶';

  @override
  String get unpin => '取消置顶';

  @override
  String deleteThemeConfirm(String title) {
    return '确认删除主题「$title」？所有对话将被永久删除。';
  }

  @override
  String get ttsPlay => '朗读';

  @override
  String get ttsStop => '停止';

  @override
  String get ttsVoice => '朗读语音';

  @override
  String get ttsRate => '语速';

  @override
  String get ttsEngine => '语音引擎';

  @override
  String get ttsAppleSystem => 'Apple 系统语音';

  @override
  String get ttsTestPlay => '试听';

  @override
  String get ttsVoiceSettings => '语音设置';

  @override
  String get ttsVoiceSettingsSubtitle => '朗读语音、语速设置';

  @override
  String get ttsSlow => '慢';

  @override
  String get ttsFast => '快';

  @override
  String get ttsPlayerPlay => '播放';

  @override
  String get ttsPlayerStop => '停止';

  @override
  String get ttsBackToTop => '回到顶部';

  @override
  String get ttsNoVoicesAvailable => '暂无可用语音';

  @override
  String get ttsIosOnly => '语音播放仅在 iOS 上可用';

  @override
  String get backupAndRestore => '备份与恢复';

  @override
  String get storageSection => '存储';

  @override
  String get cleanImagesEntry => '清理无用图片';

  @override
  String get cleanImagesSubtitle => '扫描并删除未引用的图片';

  @override
  String get scanningImages => '扫描中…';

  @override
  String cleanImagesFound(int count, String size) {
    return '发现 $count 个无用图片，共 $size';
  }

  @override
  String get cleanImagesConfirm => '清理';

  @override
  String cleanImagesDone(int count, String size) {
    return '已清理 $count 个图片，释放 $size';
  }

  @override
  String get cleanImagesNone => '没有发现无用图片';

  @override
  String get cleanImagesSelectAll => '全选';

  @override
  String get cleanImagesDeselectAll => '取消全选';

  @override
  String cleanImagesDeleteSelected(int count) {
    return '删除（$count）';
  }

  @override
  String cleanImagesConfirmDelete(int count, String size) {
    return '确定删除选中的 $count 个无用图片？将释放 $size。此操作不可撤销。';
  }

  @override
  String cleanImagesSummary(int selected, int total) {
    return '已选 $selected / 共 $total';
  }

  @override
  String cleanImagesScanStats(int sessionFiles, int images) {
    return '扫描到 $sessionFiles 个会话、$images 张图片';
  }

  @override
  String get cleanImagesDirExists => '存在';

  @override
  String get cleanImagesDirMissing => '不存在';

  @override
  String cleanImagesDiagnostics(
    String status,
    int sessions,
    int raw,
    int hit,
    int empty,
    int fail,
  ) {
    return '诊断：数据目录 $status · 会话 $sessions · 原始图片 $raw · 命中 $hit · 空目录 $empty · 读取失败 $fail';
  }

  @override
  String get rescan => '重新扫描';

  @override
  String cleanImagesOrphanHint(int count) {
    return '发现 $count 张无用图片，勾选后可删除';
  }

  @override
  String get cleanImagesAllInUse => '未发现无用图片，以下图片均在使用中';

  @override
  String get cleanImagesEduSummary => '删除图片不可恢复。被聊天引用的图片删除后，对应对话将显示图片缺失。';

  @override
  String get cleanImagesEduUnused => '· 未使用：没有任何聊天引用，删除安全。';

  @override
  String get cleanImagesEduInUse => '· 使用中：正被某条聊天引用，删除后该消息的图片会丢失（文字仍在）。';

  @override
  String get cleanImagesEduPermanent => '· 所有删除均为永久操作，无法撤销。';

  @override
  String get cleanImagesInUse => '使用中';

  @override
  String get cleanImagesWarnTitle => '注意：将删除正在使用的图片';

  @override
  String cleanImagesConfirmInUse(int count) {
    return '其中 $count 张正被聊天引用，删除后这些对话会显示图片缺失。此操作不可撤销。';
  }

  @override
  String cleanImagesStatusLine(int unused, int total) {
    return '共 $total 张图片，其中 $unused 张未使用（删除安全），其余正被聊天引用。';
  }

  @override
  String get backupData => '备份数据';

  @override
  String get restoreData => '恢复数据';

  @override
  String get backupInProgress => '正在备份...';

  @override
  String get restoreInProgress => '正在恢复...';

  @override
  String get restoreConflictTitle => '数据冲突';

  @override
  String get restoreConflictMessage => '本地已存在数据，如何处理？';

  @override
  String get restoreOverwrite => '覆盖';

  @override
  String get restoreMerge => '合并';

  @override
  String get success => '成功';

  @override
  String get restoreSuccess => '数据恢复成功';

  @override
  String get restoreFailed => '恢复失败';

  @override
  String get contextSize => '上下文大小';

  @override
  String get contextSizeDescription =>
      '用于计算剩余可用 token，影响长对话的截断策略。如 Claude 等模型无需设置。';

  @override
  String get contextSizeNotSet => '未设置';

  @override
  String get llmSettings => '大模型';

  @override
  String get defaultModelConfig => '默认模型配置';

  @override
  String get chatDefaultModel => '聊天默认模型';

  @override
  String get notSet => '未设置';

  @override
  String get llmErrorNetwork => '网络连接中断，请检查后重试';

  @override
  String get llmErrorTimeout => '请求超时，请重试';

  @override
  String get llmErrorRateLimited => '请求过于频繁，请稍后再试';

  @override
  String get llmErrorAuthFailed => 'API Key 无效或已过期，请检查设置';

  @override
  String get llmErrorPaymentRequired => '账户余额不足，请前往服务商控制台充值';

  @override
  String get llmErrorServerError => '服务暂不可用，请稍后再试';

  @override
  String get llmErrorUnknown => '生成失败，请重试';

  @override
  String get llmErrorRetry => '重试';

  @override
  String get llmErrorCancel => '取消';

  @override
  String get clearAllDefaultModels => '清除所有默认模型';

  @override
  String get keywordScorePromptTitle => 'Score Prompt';

  @override
  String get keywordScorePromptDescription =>
      '自定义用于关键词评分的 prompt。分数决定关键词在排行榜中的排名顺序。';

  @override
  String get keywordScorePromptInputExample => '输入数据示例';

  @override
  String get keywordScorePromptEditableSection => '分数计算逻辑';

  @override
  String get keywordScorePromptOutputFormat => '输出格式';

  @override
  String get keywordScorePromptResetDefault => '恢复默认';

  @override
  String get keywordScorePromptSaveSuccess => 'Score prompt 已保存';

  @override
  String get keywordScorePromptSaveFailed => '保存失败';

  @override
  String get keywordScorePromptEntry => '关键词 Score Prompt';

  @override
  String get keywordScorePromptEntrySubtitle => '自定义关键词排行榜分数逻辑';

  @override
  String get userInputSummaryTitle => '输入总结';

  @override
  String get userInputSummarySubtitle => '回顾你最近的输入脉络';

  @override
  String get userInputSummaryScanning => '正在扫描对话记录…';

  @override
  String get userInputSummaryAnalyzing => '正在分析你的输入…';

  @override
  String userInputSummaryFoundInputs(int count) {
    return '找到 $count 条输入';
  }

  @override
  String get userInputSummaryError => '分析失败';

  @override
  String userInputSummaryEmpty(int days) {
    return '近 $days 天内暂无输入记录';
  }

  @override
  String get userInputSummaryGenerate => '生成报告';

  @override
  String userInputSummaryReportInfo(int days, int count) {
    return '近 $days 天 · 共 $count 条输入';
  }

  @override
  String get userInputSummaryCopy => '复制全部';

  @override
  String get userInputSummaryRefresh => '重新生成';

  @override
  String get thinkingCollisionTitle => '思维碰撞';

  @override
  String get thinkingCollisionSubtitle => '跨主题知识的意外连接';

  @override
  String get labComingSoon => '即将上线，敬请期待';

  @override
  String get thinkingCollisionHint => '点击碰撞对，发现知识间的隐藏联系';

  @override
  String get thinkingCollisionLoading => '正在读取关键词…';

  @override
  String get thinkingCollisionExpanding => '正在探索思维连接…';

  @override
  String get thinkingCollisionNoKeywords => '暂无关键词，请先在关键词排行榜中分析';

  @override
  String get chatOutline => '对话目录';

  @override
  String get chatSearch => '搜索对话';

  @override
  String get chatMarkdown => '原始 Markdown';

  @override
  String get chatMarkdownEmpty => '暂无对话内容';

  @override
  String get searchInChat => '搜索消息内容';

  @override
  String get noUserMessages => '暂无用户消息';

  @override
  String get noSearchResults => '没有找到匹配的结果';

  @override
  String get clearModels => '清除模型';

  @override
  String clearModelsConfirm(String providerName) {
    return '确定要清除 $providerName 的模型列表吗？API Key 不会被删除。';
  }

  @override
  String get clear => '清除';

  @override
  String get aboutTitle => '关于';

  @override
  String get aboutContactEmail => '联系邮箱';

  @override
  String get menuSettings => '设置';

  @override
  String get menuAbout => '关于';

  @override
  String get mergeChats => '合并 Chat';

  @override
  String mergeChatHint(int max) {
    return '最多选择 $max 个 chat 进行合并';
  }

  @override
  String selectedCount(int count, int max) {
    return '已选 $count/$max';
  }

  @override
  String get mergeAndCreate => '合并 & 创建新 Chat';

  @override
  String get mergeChatConfirmTitle => '合并 & 创建';

  @override
  String get selectMountLocation => '选择挂载位置';

  @override
  String get rootNode => '根节点（顶层）';

  @override
  String maxSelectionReached(int max) {
    return '最多选 $max 个';
  }

  @override
  String get multiSelect => '多选';

  @override
  String get done => '完成';

  @override
  String get mergeSelectGuideOnlyChat => '只有 Chat 类型的节点可以选择';

  @override
  String mergeSelectGuideMaxChats(int max) {
    return '最多选择 $max 个 Chat';
  }

  @override
  String get mergeSelectGuideTapMerge => '选好后点击底部「合并 & 创建新 Chat」';

  @override
  String get wikiTabLabel => 'Wiki';

  @override
  String get treeTabLabel => 'Tree';

  @override
  String get wikiEmptyTitle => '还没有 Wiki';

  @override
  String wikiEmptySubtitle(String title) {
    return '把「$title」的对话整理成一本可阅读的电子书';
  }

  @override
  String get wikiGenerateButton => '生成 Wiki';

  @override
  String get wikiGenerateAction => '生成 Wiki';

  @override
  String get wikiRegenerateAction => '重新生成 Wiki';

  @override
  String get wikiTocTitle => '目录';

  @override
  String get wikiLoadFailed => '加载 Wiki 失败';

  @override
  String get wikiDeleteTitle => '删除 Wiki';

  @override
  String get wikiDeleteConfirm => '将删除当前 theme 已生成的 Wiki 快照，tree 数据不受影响。';

  @override
  String wikiGeneratedAt(String time) {
    return '生成于 $time';
  }

  @override
  String get wikiExportAction => '导出 Wiki';

  @override
  String wikiExportFailed(String error) {
    return '导出 Wiki 失败：$error';
  }

  @override
  String get wikiPreviousChapter => '上一章';

  @override
  String get wikiNextChapter => '下一章';

  @override
  String get wikiSelectTree => '选择 Tree';

  @override
  String get backupTitle => '备份与恢复';

  @override
  String get backupDeleteTitle => '删除备份';

  @override
  String get backupDeleteContent => '确定删除这份本地备份？';

  @override
  String get backupBackingUp => '备份中';

  @override
  String get backupDataConflict => '数据冲突';

  @override
  String get backupDataConflictContent => '本地已有数据，恢复将如何处理？';

  @override
  String get backupOverwrite => '覆盖';

  @override
  String get backupMerge => '合并';

  @override
  String get backupRestoring => '恢复中';

  @override
  String get backupRestoreSuccess => '恢复成功';

  @override
  String get backupRestoreFailed => '恢复失败';

  @override
  String get backupReminderInterval => '提醒周期';

  @override
  String backupReminderDaysCurrent(int days) {
    return '每 $days 天（当前）';
  }

  @override
  String backupReminderDays(int days) {
    return '每 $days 天';
  }

  @override
  String get backupNotYet => '尚未备份';

  @override
  String get backupAutoSection => '自动备份';

  @override
  String get backupAutoTitle => '自动备份';

  @override
  String get backupAutoSubtitle => '每 24 小时备份一次到本地';

  @override
  String get backupLastBackup => '上次备份';

  @override
  String backupLocalSection(int count) {
    return '本地备份（$count）';
  }

  @override
  String get backupLocalEmpty => '还没有本地备份';

  @override
  String get backupManualSection => '手动操作';

  @override
  String get backupManualShare => '立即备份并分享';

  @override
  String get backupManualShareSubtitle => '生成一份备份并分享出去';

  @override
  String get backupManualRestore => '从备份文件恢复';

  @override
  String get backupManualRestoreSubtitle => '从 zip 文件恢复数据';

  @override
  String get backupReminderSection => '分享提醒';

  @override
  String get backupReminderToggle => '提醒开关';

  @override
  String get backupReminderToggleSubtitle => '定期提醒把备份分享出去';

  @override
  String backupReminderSubtitle(int days) {
    return '每 $days 天提醒一次';
  }

  @override
  String get clipsTitle => '碎片';

  @override
  String get clipsManage => '管理';

  @override
  String get clipsPreview => '预览';

  @override
  String get clipsEmpty => '暂无碎片';

  @override
  String get clipsEmptyHint => '长按选中文本可存入碎片';

  @override
  String get clipsClearAllTitle => '清空全部碎片';

  @override
  String get clipsClearAllContent => '确定要删除所有碎片吗？此操作不可撤销。';

  @override
  String get clipsClearAll => '清空全部';

  @override
  String get clipsManageTitle => '管理碎片';

  @override
  String get imageSourceSelect => '选择图片来源';

  @override
  String get imageFromCamera => '拍照';

  @override
  String get imageFromGallery => '从相册选择';

  @override
  String get imageModelNotSupported => '当前模型不支持图片功能';

  @override
  String imagePickFailed(String error) {
    return '选择图片失败：$error';
  }

  @override
  String get searchRecent => '最近搜索';

  @override
  String get searchClearAll => '清除全部';

  @override
  String get settingsBackupRestore => '备份与恢复';

  @override
  String get settingsBackupRestoreSubtitle => '自动备份 · 分享 · 恢复';

  @override
  String get settingsBackupReminder => '备份提醒';

  @override
  String get settingsBackupReminderSubtitle => '每 3-7 天提醒一次';

  @override
  String wikiMessageCount(int count) {
    return '$count 条消息';
  }

  @override
  String get thinkingProcess => '思考过程';

  @override
  String get daysUnit => '天';

  @override
  String get breadcrumbProviders => '提供商';

  @override
  String get breadcrumbConfig => '配置';

  @override
  String get breadcrumbLLM => '大模型';

  @override
  String get breadcrumbModelConfig => '模型配置';

  @override
  String get shareContentTooLarge => '内容过多，无法保存为单张图片，请改用「分享当前对话」或缩短会话';

  @override
  String shareFailed(String error) {
    return '分享失败：$error';
  }

  @override
  String searchRepairFailed(String error) {
    return '修复失败: $error';
  }

  @override
  String searchBackupSuggestion(int count) {
    return '你已有 $count 份本地备份，建议分享一份到 iCloud 或其他设备保存';
  }

  @override
  String get searchGoShare => '去分享';

  @override
  String get searchIgnore => '忽略';

  @override
  String get controllerDescribeImage => '描述这张图片';

  @override
  String get controllerApiKeyNotConfigured =>
      '[未配置 API Key] 请到设置 > 模型提供商中配置 API Key。';

  @override
  String ttsSampleText(String name, String action) {
    return '你好，我是$name，$action。';
  }

  @override
  String get ttsOtherHeader => '其他';

  @override
  String get ttsWaveformLabel => '语音波形';

  @override
  String get controllerVisionNotSupported => '当前模型不支持图片，请切换到支持视觉的模型后再上传图片。';

  @override
  String get deepThinking => '深度思考';

  @override
  String get deepThinkingNotSupported => '不支持深度思考';

  @override
  String get webSearch => '联网搜索';

  @override
  String get webSearchNotSupported => '不支持联网';

  @override
  String get clipsBranch => '分支';

  @override
  String get clipsSaveToDrawer => '放入抽屉';

  @override
  String get markdownBold => '粗体';

  @override
  String get markdownItalic => '斜体';

  @override
  String get markdownStrikethrough => '删除线';

  @override
  String get markdownHeading => '标题';

  @override
  String get markdownBulletList => '无序列表';

  @override
  String get markdownNumberedList => '有序列表';

  @override
  String get markdownCheckbox => '复选框';

  @override
  String get markdownCode => '代码';

  @override
  String get markdownQuote => '引用';

  @override
  String get markdownLink => '链接';

  @override
  String get markdownDivider => '分隔线';

  @override
  String get markdownTable => '表格';

  @override
  String get markdownBoldPlaceholder => '粗体文字';

  @override
  String get markdownItalicPlaceholder => '斜体文字';

  @override
  String get markdownStrikethroughPlaceholder => '删除线文字';

  @override
  String get markdownLinkPlaceholder => '链接文字';

  @override
  String get markdownTableHeader1 => '列1';

  @override
  String get markdownTableHeader2 => '列2';

  @override
  String get markdownTableHeader3 => '列3';
}
