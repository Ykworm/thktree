// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'ThkTree';

  @override
  String get settingsTitle => 'ThkTree · Settings';

  @override
  String get language => 'Language';

  @override
  String languageSubtitle(String name) {
    return '$name';
  }

  @override
  String get systemDefault => 'System Default';

  @override
  String get english => 'English';

  @override
  String get chinese => '中文';

  @override
  String get noThemesYet => 'No themes yet';

  @override
  String get newTheme => 'New Theme';

  @override
  String get titleHint => 'Title';

  @override
  String get cancel => 'Cancel';

  @override
  String get create => 'Create';

  @override
  String get back => 'Back';

  @override
  String get tree => 'Tree';

  @override
  String get branch => 'Branch';

  @override
  String get save => 'Save';

  @override
  String get renameNote => 'Rename Note';

  @override
  String get delete => 'Delete';

  @override
  String get close => 'Close';

  @override
  String get copied => 'Copied';

  @override
  String get loadingSettings => 'Loading settings...';

  @override
  String get loadingLogger => 'Loading logger...';

  @override
  String get loadingPaths => 'Loading paths...';

  @override
  String get logFile => 'Log File';

  @override
  String get remoteLogging => 'Remote Logging';

  @override
  String get enabled => 'enabled';

  @override
  String get disabled => 'disabled';

  @override
  String get viewLogs => 'View Logs';

  @override
  String get logsTail => 'Logs (tail)';

  @override
  String get emptyLogs => '(empty)';

  @override
  String get llmProviderTitle => 'LLM Provider';

  @override
  String get llmApiKey => 'API Key';

  @override
  String llmApiKeyTitle(String providerName) {
    return '$providerName API Key';
  }

  @override
  String get apiKeySet => 'Set';

  @override
  String get apiKeyNotSet => 'Not set';

  @override
  String get llmModel => 'Model';

  @override
  String llmModelTitle(String providerName) {
    return '$providerName Model';
  }

  @override
  String get dataRoot => 'Data Root';

  @override
  String treeTitle(Object title) {
    return '$title · Tree';
  }

  @override
  String get emptyTree =>
      'Session Tree is empty.\nTap + to create a root session.';

  @override
  String get newSession => 'New Session';

  @override
  String get newBranch => 'New Branch';

  @override
  String get deleteItem => 'Delete Item';

  @override
  String deleteConfirm(Object title) {
    return 'Delete \"$title\"?';
  }

  @override
  String targetNodeId(Object nodeId) {
    return 'Target nodeId: $nodeId';
  }

  @override
  String get deleteUnderstand =>
      'I understand only the selected nodeId subtree will be deleted.';

  @override
  String deleteDescWithChildren(int count) {
    return 'This will delete 1 selected node and $count child item(s).';
  }

  @override
  String get deleteDescOnly => 'This will delete only the selected node.';

  @override
  String keptSameTitleNodes(int count) {
    return 'Same-title nodes that will be kept ($count):';
  }

  @override
  String deletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'items',
      one: 'item',
    );
    return 'Deleted $count $_temp0';
  }

  @override
  String branchFailed(String error) {
    return 'Branch failed: $error';
  }

  @override
  String deleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String saveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get messageHint => 'Message';

  @override
  String get send => 'Send';

  @override
  String get stop => 'Stop';

  @override
  String get polishSummary => 'Polish Summary';

  @override
  String get summaryHint => 'Modify summary...';

  @override
  String summaryBanner(Object title) {
    return 'Polish the summary content. After confirmation, it will be used as the starting point for the new branch \"$title\"';
  }

  @override
  String get confirmSummary => 'Confirm this summary';

  @override
  String get generatingSummary => 'Generating summary...';

  @override
  String get createBranch => 'Create Branch';

  @override
  String get creatingBranch => 'Creating branch...';

  @override
  String get skipSummary => 'Use Original Context';

  @override
  String get blankBranch => 'Start Fresh';

  @override
  String get pleaseGenerateSummary =>
      'Please generate the summary content first';

  @override
  String branchCreationFailed(Object error) {
    return 'Branch creation failed: $error';
  }

  @override
  String get userRole => 'user';

  @override
  String get assistantRole => 'assistant';

  @override
  String get systemRole => 'system';

  @override
  String get streamingStatus => 'streaming';

  @override
  String errorStatus(Object code) {
    return 'error:$code';
  }

  @override
  String get errorUnknown => 'unknown';

  @override
  String get expandTable => 'Expand Table';

  @override
  String get copy => 'Copy';

  @override
  String get addToNote => 'Add to Note';

  @override
  String get notes => 'Notes';

  @override
  String get selectNote => 'Select a note to append to...';

  @override
  String get noNotesYet => 'No notes yet. Tap + to create one.';

  @override
  String get newNote => 'New Note';

  @override
  String noteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
      zero: '0 notes',
    );
    return '$_temp0';
  }

  @override
  String get uncategorized => 'Uncategorized';

  @override
  String get llmProvidersTitle => 'Model Providers';

  @override
  String get llmProviderCustom => 'Custom';

  @override
  String get addCustomProvider => 'Add Custom Provider';

  @override
  String get providerName => 'Provider Name';

  @override
  String get providerBaseUrl => 'Base URL';

  @override
  String get providerDefaultUrl => 'Default URL';

  @override
  String get providerApiKey => 'API Key';

  @override
  String get apiKeyConfigured => 'Configured';

  @override
  String get apiKeyNotConfigured => 'Not configured';

  @override
  String modelCount(int count) {
    return '$count models';
  }

  @override
  String get noModels => 'No models';

  @override
  String get deleteProvider => 'Delete Provider';

  @override
  String get deleteProviderConfirm =>
      'Are you sure you want to delete this provider?';

  @override
  String get fetchModels => 'Fetch Models';

  @override
  String get fetchingModels => 'Fetching models...';

  @override
  String fetchModelsSuccess(int count) {
    return 'Successfully fetched $count models';
  }

  @override
  String fetchModelsFailed(String error) {
    return 'Failed to fetch models: $error';
  }

  @override
  String get apiKeyInvalid => 'API Key is invalid or expired';

  @override
  String get selectModel => 'Select Model';

  @override
  String get currentModel => 'Current Model';

  @override
  String get noModelSelected => 'No model selected';

  @override
  String contextUsagePercent(int percent) {
    return 'Context: $percent%';
  }

  @override
  String get customProviderHint =>
      'e.g. ProviderName + ModelName for easy identification';

  @override
  String get baseUrlHint => 'Enter the API base URL';

  @override
  String get apiKeyHint => 'Enter the API Key';

  @override
  String get saveProvider => 'Save';

  @override
  String get editProvider => 'Edit Provider';

  @override
  String get copyDefaultUrl => 'Copy default URL';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get pleaseFetchModels =>
      'Please configure a provider and fetch models in settings first';

  @override
  String get createChatFromNote => 'Start Chat from Note';

  @override
  String get selectTheme => 'Select Theme';

  @override
  String get selectLocation => 'Select Location';

  @override
  String get asRootChat => 'As root conversation';

  @override
  String underNode(String title) {
    return 'Under \"$title\"';
  }

  @override
  String get chatTitle => 'Chat Title';

  @override
  String get chatCreated => 'Chat created successfully';

  @override
  String get themesTabLabel => 'Themes';

  @override
  String get settingsTabLabel => 'Settings';

  @override
  String get createBranchRawFromSelection => 'Create Branch from Selection';

  @override
  String get createBranchSummarizeFromSelection =>
      'Summarize Selection, then Create Branch';

  @override
  String get chooseTitle => 'Choose Title';

  @override
  String titleSourceBanner(String source) {
    return 'Branch from $source';
  }

  @override
  String get titleSourceSelection => 'Selected Text';

  @override
  String get titleSourceConversation => 'Conversation';

  @override
  String get titleSourceConversationSummary => 'Conversation Summary';

  @override
  String get titleSourceNote => 'Note';

  @override
  String get titleDirectionHint => 'Direction (optional)';

  @override
  String get titleRegenerate => 'Regenerate';

  @override
  String get titleGenerating => 'Generating titles...';

  @override
  String get titleAutoGenFailed => 'Generation failed';

  @override
  String get titleModelSwitch => 'Switch Model';

  @override
  String get titleCandidatesEmpty =>
      'No candidates yet. Try a different direction.';

  @override
  String get titleConfirm => 'Confirm';

  @override
  String get summarizing => 'Summarizing conversation...';

  @override
  String get summarizeFailedFallback =>
      'Summarization failed, using raw conversation as branch source';

  @override
  String get branchModeSheetTitle => 'Choose how to create the branch';

  @override
  String get branchModeSummarize => 'Summarize, then create';

  @override
  String get branchModeRaw => 'Use the original context';

  @override
  String get branchModeContinue => 'Continue';

  @override
  String get networkInterrupted => 'Network interrupted. Please retry.';

  @override
  String get branchRetry => 'Retry';

  @override
  String get branchCancelRetry => 'Cancel';

  @override
  String get titleModelTitle => 'Title Generation Model';

  @override
  String get summaryModelTitle => 'Summary Model';

  @override
  String get notConfigured => 'Not configured';

  @override
  String get generateTitles => 'Generate Titles';

  @override
  String get generateTitlesHint => 'Tap to generate title suggestions';

  @override
  String contextWindowTitle(String modelName) {
    return 'Set context window for $modelName';
  }

  @override
  String get sourceTypeSelectedText => 'Selected Text';

  @override
  String get sourceTypeConversation => 'Conversation';

  @override
  String get sourceTypeSummary => 'Summary';

  @override
  String get sourceTypeNote => 'Note';

  @override
  String get swipeDelete => 'Delete';

  @override
  String get swipeBranch => 'Branch';

  @override
  String get renameNode => 'Rename Node';

  @override
  String get enterNewTitle => 'Enter new title';

  @override
  String get retry => 'Retry';

  @override
  String get faceIdLock => 'Face ID Lock';

  @override
  String get faceIdLockSubtitle => 'Require Face ID to open the app';

  @override
  String get ok => 'OK';

  @override
  String get deleteNote => 'Delete Note';

  @override
  String deleteNoteConfirmTitle(String title) {
    return 'Delete \"$title\"?';
  }
}
