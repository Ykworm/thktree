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
    return '$count 个模型';
  }

  @override
  String get noModels => '暂无模型';

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
  String get swipeDelete => '删除';

  @override
  String get swipeBranch => '分支';

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
  String get searchTabLabel => '搜索';

  @override
  String get searchHint => '搜索笔记和对话...';

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
  String get llmErrorServerError => '服务暂不可用，请稍后再试';

  @override
  String get llmErrorUnknown => '生成失败，请重试';

  @override
  String get llmErrorRetry => '重试';

  @override
  String get llmErrorCancel => '取消';

  @override
  String get clearAllDefaultModels => '清除所有默认模型';
}
