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
  String get noThemesYet => '暂无主题';

  @override
  String get newTheme => '新建主题';

  @override
  String get titleHint => '标题';

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
  String get emptyTree => '会话树为空。\n点击 + 创建根会话。';

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
  String get noNotesYet => '暂无笔记，点击 + 创建一个。';

  @override
  String get newNote => '新建笔记';

  @override
  String noteCount(int count) {
    return '$count 篇笔记';
  }

  @override
  String get uncategorized => '未分类';

  @override
  String get llmProvidersTitle => 'LLM 提供商';

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
}
