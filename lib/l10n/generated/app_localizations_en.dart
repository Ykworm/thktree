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
  String get noThemesYet => 'Start your first knowledge theme';

  @override
  String get newTheme => 'New Theme';

  @override
  String get titleHint => 'Title';

  @override
  String get titleCannotBeEmpty =>
      'Title cannot be empty, please enter a title before saving';

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
  String get emptyTree => 'Plant the first seed — tap + to start';

  @override
  String get treeTitleSearchHint => 'Search node titles';

  @override
  String get treeTitleSearchNoResults => 'No matching titles';

  @override
  String get collapseAll => 'Collapse All';

  @override
  String get expandAll => 'Expand All';

  @override
  String get refresh => 'Refresh';

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
  String get reasoningTitle => 'Reasoning';

  @override
  String get showReasoning => 'Show Reasoning';

  @override
  String get hideReasoning => 'Hide Reasoning';

  @override
  String get copy => 'Copy';

  @override
  String get addToNote => 'Add to Note';

  @override
  String get notes => 'Notes';

  @override
  String get selectNote => 'Select a note to append to...';

  @override
  String get noNotesYet => 'A blank page awaits your thoughts';

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
    return '$count providers';
  }

  @override
  String get noModels => 'No providers';

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
  String get searchModels => 'Search models...';

  @override
  String get noModelsFound => 'No matching models found';

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
  String get pleaseConfigureTitleModel =>
      'Please configure the title generation model in Default Model Config';

  @override
  String get pleaseConfigureSummaryModel =>
      'Please configure the summary model in Default Model Config';

  @override
  String get createChatFromNote => 'Start Chat from Note';

  @override
  String get selectTheme => 'Select Theme';

  @override
  String get selectTree => 'Select Tree';

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
  String get labTabLabel => 'Lab';

  @override
  String get labEmptyHint => 'Experimental features are coming soon';

  @override
  String get keywordRankingTitle => 'Keyword Ranking';

  @override
  String get keywordRankingSubtitle => 'Reflect on recent thinking patterns';

  @override
  String get keywordRankingComingSoon => 'List view is coming soon';

  @override
  String get keywordRankingAnalyze => 'Analyze';

  @override
  String get keywordRankingLastUpdated => 'Last updated';

  @override
  String get keywordRankingEmpty => 'No keywords yet. Tap Analyze to start.';

  @override
  String get keywordRankingSelectThemes => 'Select Theme';

  @override
  String get keywordRankingSelectThemesHint =>
      'Pick a theme to analyze its chats';

  @override
  String get keywordRankingSelectLeaves => 'Select Chats';

  @override
  String get keywordRankingSelectLeavesHint => 'Pick chats to analyze with LLM';

  @override
  String keywordRankingSelectLeavesSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
      zero: 'None selected',
    );
    return '$_temp0';
  }

  @override
  String get keywordRankingStartAnalysis => 'Start Analysis';

  @override
  String get keywordRankingAnalyzing => 'Analyzing...';

  @override
  String get keywordRankingAnalysisDone => 'Analysis complete';

  @override
  String keywordRankingAnalysisFailed(String error) {
    return 'Analysis failed: $error';
  }

  @override
  String get keywordRankingLeafStatusPending => 'Pending';

  @override
  String get keywordRankingLeafStatusFresh => 'Fresh';

  @override
  String get keywordRankingLeafStatusStale => 'Stale';

  @override
  String get keywordRankingNoThemes => 'No themes yet';

  @override
  String get keywordRankingNoAnalyzableLeaves =>
      'No chats to analyze in this theme';

  @override
  String get keywordRankingSelectAll => 'Select all';

  @override
  String get keywordRankingDeselectAll => 'Clear';

  @override
  String get keywordRankingScoreLabel => 'Score';

  @override
  String get keywordRankingStaleBadge => 'stale';

  @override
  String keywordRankingLeafCount(int themes, int leaves, String depth) {
    return '${themes}T · ${leaves}L · depth $depth';
  }

  @override
  String get keywordRankingJumpToChat => 'Go to chat';

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
  String get branchModeBlank => 'Blank Branch';

  @override
  String get branchBlankInitialTitle => 'Temporary Chat';

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
  String get sourceTypeUserIdea => 'User Idea';

  @override
  String get sourceTypeDocSplit => 'Doc Split';

  @override
  String get importDocSplit => 'Import & Split Document';

  @override
  String get docSplitInputTitle => 'Paste Document';

  @override
  String get docSplitFeatureTitle => 'AI Doc Split';

  @override
  String get docSplitStartAnalysis => 'Start Analysis';

  @override
  String get docSplitHintTitle =>
      'Paste a document and let AI turn it into a tree';

  @override
  String get docSplitHintBody =>
      'The app first analyzes the structure, then generates an adjustable tree preview in chat.';

  @override
  String get docSplitViewDetails => 'View Details';

  @override
  String get docSplitPlaceholder =>
      'Paste a document, plan, or meeting notes here...\nAI will analyze the structure first, then generate an adjustable tree preview.';

  @override
  String get docSplitDetailsTitle => 'How Doc Split Works';

  @override
  String get docSplitDetailsWhatTitle => 'What It Does';

  @override
  String get docSplitDetailsWhatBody =>
      'Turn one long document into a structured tree of chat nodes with AI, then refine it before creating the real nodes.';

  @override
  String get docSplitDetailsFlowTitle => 'What Happens Next';

  @override
  String get docSplitDetailsFlow1 =>
      'After pasting the document, AI first analyzes the structure in chat.';

  @override
  String get docSplitDetailsFlow2 =>
      'You can continue chatting to merge, regroup, or simplify the tree.';

  @override
  String get docSplitDetailsFlow3 =>
      'Only after tapping \"Submit Tree\" will the preview become real nodes.';

  @override
  String get docSplitDetailsBestForTitle => 'Best For';

  @override
  String get docSplitDetailsBestForBody =>
      'Plans, meeting notes, interview notes, long markdown drafts, and any text that benefits from hierarchical grouping.';

  @override
  String get docSplitDetailsPromptTitle => 'Prompt Ideas';

  @override
  String get docSplitDetailsPrompt1 => 'Please split this by topic.';

  @override
  String get docSplitDetailsPrompt2 => 'Keep it within two levels.';

  @override
  String get docSplitDetailsPrompt3 =>
      'Merge repeated ideas and make the structure cleaner.';

  @override
  String get submitTreeStructure => 'Submit Tree';

  @override
  String get docSplitParsingFailed =>
      'Cannot parse tree structure. Please ask the LLM to reformat.';

  @override
  String get docSplitNoAssistantMessage =>
      'No LLM response found. Please send a message first.';

  @override
  String docSplitSuccess(int count) {
    return 'Created $count nodes';
  }

  @override
  String get docSplitEmptyInput => 'Please paste document text';

  @override
  String get confirm => 'Confirm';

  @override
  String get swipeDelete => 'Delete';

  @override
  String get swipeBranch => 'Branch';

  @override
  String get viewTree => 'View Tree';

  @override
  String get myQuestions => 'Session Messages';

  @override
  String get myQuestionsTitle => 'My Sent Messages';

  @override
  String get myQuestionsEmpty => 'No messages sent in this chat yet';

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
  String get error => 'Error';

  @override
  String get ok => 'OK';

  @override
  String get deleteNote => 'Delete Note';

  @override
  String deleteNoteConfirmTitle(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String get saveToNote => 'Save to Note';

  @override
  String get generateTitle => 'Generate Title';

  @override
  String get generatingTitle => 'Generating title…';

  @override
  String get moveNote => 'Move';

  @override
  String get noteMoved => 'Moved';

  @override
  String get searchTabLabel => 'Search';

  @override
  String get searchHint => 'Search notes and conversations...';

  @override
  String get searchAction => 'Search';

  @override
  String get searchIdleHint => 'Tap Search after typing';

  @override
  String get searchEmpty => 'Find connections in your knowledge';

  @override
  String get searchNoResults => 'Try a different angle';

  @override
  String get searchError => 'Search error, please try again';

  @override
  String get searchIndexError => 'Search Index Error';

  @override
  String get searchIndexErrorContent =>
      'The search index may be corrupted. This does not affect your note content safety.\n\nWould you like to repair the index now?';

  @override
  String get repairLater => 'Later';

  @override
  String get repairNow => 'Repair Now';

  @override
  String get repairComplete => 'Repair Complete';

  @override
  String get repairCompleteContent =>
      'Search index has been rebuilt. You can now search normally.';

  @override
  String get noTitle => 'No title';

  @override
  String maxNodeDepthReached(int max) {
    return 'Reached the maximum nesting level ($max). Cannot create a deeper branch.';
  }

  @override
  String get startWriting => 'Start writing...';

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String hoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String daysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String monthDay(int month, int day) {
    return '$month/$day';
  }

  @override
  String get pin => 'Pin';

  @override
  String get unpin => 'Unpin';

  @override
  String deleteThemeConfirm(String title) {
    return 'Delete theme \"$title\"? All conversations will be permanently deleted.';
  }

  @override
  String get ttsPlay => 'Read Aloud';

  @override
  String get ttsStop => 'Stop';

  @override
  String get ttsVoice => 'Voice';

  @override
  String get ttsRate => 'Speech Rate';

  @override
  String get ttsEngine => 'TTS Engine';

  @override
  String get ttsAppleSystem => 'Apple System Voice';

  @override
  String get ttsTestPlay => 'Preview';

  @override
  String get ttsVoiceSettings => 'Voice Settings';

  @override
  String get ttsVoiceSettingsSubtitle => 'Voice and speech rate settings';

  @override
  String get ttsSlow => 'Slow';

  @override
  String get ttsFast => 'Fast';

  @override
  String get ttsPlayerPlay => 'Play';

  @override
  String get ttsPlayerStop => 'Stop';

  @override
  String get ttsBackToTop => 'Back to top';

  @override
  String get ttsNoVoicesAvailable => 'No voices available';

  @override
  String get ttsIosOnly => 'Voice playback is iOS only';

  @override
  String get backupAndRestore => 'Backup & Restore';

  @override
  String get storageSection => 'Storage';

  @override
  String get cleanImagesEntry => 'Clean Unused Images';

  @override
  String get cleanImagesSubtitle => 'Scan and remove unreferenced images';

  @override
  String get scanningImages => 'Scanning…';

  @override
  String cleanImagesFound(int count, String size) {
    return 'Found $count unused image(s), $size total';
  }

  @override
  String get cleanImagesConfirm => 'Clean';

  @override
  String cleanImagesDone(int count, String size) {
    return 'Cleaned $count image(s), freed $size';
  }

  @override
  String get cleanImagesNone => 'No unused images found';

  @override
  String get cleanImagesSelectAll => 'Select All';

  @override
  String get cleanImagesDeselectAll => 'Deselect All';

  @override
  String cleanImagesDeleteSelected(int count) {
    return 'Delete ($count)';
  }

  @override
  String cleanImagesConfirmDelete(int count, String size) {
    return 'Delete $count selected unused image(s)? This will free $size and cannot be undone.';
  }

  @override
  String cleanImagesSummary(int selected, int total) {
    return 'Selected $selected / $total';
  }

  @override
  String cleanImagesScanStats(int sessionFiles, int images) {
    return 'Scanned $sessionFiles session(s), $images image(s)';
  }

  @override
  String get cleanImagesDirExists => 'present';

  @override
  String get cleanImagesDirMissing => 'missing';

  @override
  String cleanImagesDiagnostics(
    String status,
    int sessions,
    int raw,
    int hit,
    int empty,
    int fail,
  ) {
    return 'Diagnostics: data dir $status · sessions $sessions · raw images $raw · dirs hit $hit · empty $empty · list failed $fail';
  }

  @override
  String get rescan => 'Rescan';

  @override
  String cleanImagesOrphanHint(int count) {
    return 'Found $count unused image(s), select to delete';
  }

  @override
  String get cleanImagesAllInUse =>
      'No unused images; the following are all in use';

  @override
  String get cleanImagesEduSummary =>
      'Deleting images cannot be undone. Images referenced by a chat will appear missing in that conversation after deletion.';

  @override
  String get cleanImagesEduUnused =>
      '· Unused: not referenced by any chat — safe to delete.';

  @override
  String get cleanImagesEduInUse =>
      '· In use: referenced by a chat — deleting removes the image from that message (text stays).';

  @override
  String get cleanImagesEduPermanent =>
      '· All deletions are permanent and cannot be undone.';

  @override
  String get cleanImagesInUse => 'In use';

  @override
  String get cleanImagesWarnTitle => 'Warning: deleting images in use';

  @override
  String cleanImagesConfirmInUse(int count) {
    return 'Of these, $count is/are referenced by a chat and will appear missing after deletion. This cannot be undone.';
  }

  @override
  String cleanImagesStatusLine(int unused, int total) {
    return '$total image(s) total, $unused unused (safe to delete), the rest are in use.';
  }

  @override
  String get backupData => 'Backup Data';

  @override
  String get restoreData => 'Restore Data';

  @override
  String get backupInProgress => 'Backing up...';

  @override
  String get restoreInProgress => 'Restoring...';

  @override
  String get restoreConflictTitle => 'Data Conflict';

  @override
  String get restoreConflictMessage =>
      'Local data already exists. How would you like to proceed?';

  @override
  String get restoreOverwrite => 'Overwrite';

  @override
  String get restoreMerge => 'Merge';

  @override
  String get success => 'Success';

  @override
  String get restoreSuccess => 'Data restored successfully';

  @override
  String get restoreFailed => 'Restore failed';

  @override
  String get contextSize => 'Context Size';

  @override
  String get contextSizeDescription =>
      'Used to compute remaining available tokens. Affects truncation strategy for long conversations. Not required for models like Claude.';

  @override
  String get contextSizeNotSet => 'Not set';

  @override
  String get llmSettings => 'LLM';

  @override
  String get defaultModelConfig => 'Default Model Config';

  @override
  String get chatDefaultModel => 'Chat Default Model';

  @override
  String get notSet => 'Not set';

  @override
  String get llmErrorNetwork =>
      'Network error. Please check your connection and retry.';

  @override
  String get llmErrorTimeout => 'Request timed out. Please try again.';

  @override
  String get llmErrorRateLimited =>
      'Too many requests. Please try again later.';

  @override
  String get llmErrorAuthFailed =>
      'API key invalid or expired. Check settings.';

  @override
  String get llmErrorPaymentRequired =>
      'Insufficient balance. Please top up in the provider\'s console.';

  @override
  String get llmErrorServerError =>
      'Service temporarily unavailable. Please try again.';

  @override
  String get llmErrorUnknown => 'Generation failed. Please try again.';

  @override
  String get llmErrorRetry => 'Retry';

  @override
  String get llmErrorCancel => 'Cancel';

  @override
  String get clearAllDefaultModels => 'Clear All Default Models';

  @override
  String get keywordScorePromptTitle => 'Score Prompt';

  @override
  String get keywordScorePromptDescription =>
      'Customize the prompt used to score keywords. The score determines ranking order in the keyword list.';

  @override
  String get keywordScorePromptInputExample => 'Input Data Example';

  @override
  String get keywordScorePromptEditableSection => 'Score Calculation Logic';

  @override
  String get keywordScorePromptOutputFormat => 'Output Format';

  @override
  String get keywordScorePromptResetDefault => 'Reset to Default';

  @override
  String get keywordScorePromptSaveSuccess => 'Score prompt saved';

  @override
  String get keywordScorePromptSaveFailed => 'Save failed';

  @override
  String get keywordScorePromptEntry => 'Keyword Score Prompt';

  @override
  String get keywordScorePromptEntrySubtitle =>
      'Customize keyword ranking score logic';

  @override
  String get userInputSummaryTitle => 'Input Summary';

  @override
  String get userInputSummarySubtitle => 'Review your recent input patterns';

  @override
  String get userInputSummaryScanning => 'Scanning conversations…';

  @override
  String get userInputSummaryAnalyzing => 'Analyzing your inputs…';

  @override
  String userInputSummaryFoundInputs(int count) {
    return '$count inputs found';
  }

  @override
  String get userInputSummaryError => 'Analysis failed';

  @override
  String userInputSummaryEmpty(int days) {
    return 'No input records found in the last $days days';
  }

  @override
  String get userInputSummaryGenerate => 'Generate Report';

  @override
  String userInputSummaryReportInfo(int days, int count) {
    return 'Last $days days · $count inputs';
  }

  @override
  String get userInputSummaryCopy => 'Copy All';

  @override
  String get userInputSummaryRefresh => 'Regenerate';

  @override
  String get thinkingCollisionTitle => 'Thinking Collision';

  @override
  String get thinkingCollisionSubtitle =>
      'Unexpected connections across themes';

  @override
  String get labComingSoon => 'Coming soon. Stay tuned!';

  @override
  String get thinkingCollisionHint =>
      'Tap a pair to discover hidden connections';

  @override
  String get thinkingCollisionLoading => 'Loading keywords…';

  @override
  String get thinkingCollisionExpanding => 'Exploring connections…';

  @override
  String get thinkingCollisionNoKeywords =>
      'No keywords yet. Run keyword analysis first!';

  @override
  String get chatOutline => 'Chat Outline';

  @override
  String get chatSearch => 'Search Chat';

  @override
  String get chatMarkdown => 'Raw Markdown';

  @override
  String get chatMarkdownEmpty => 'No chat content yet';

  @override
  String get searchInChat => 'Search message content';

  @override
  String get noUserMessages => 'No user messages yet';

  @override
  String get noSearchResults => 'No matching results found';

  @override
  String get clearModels => 'Clear Models';

  @override
  String clearModelsConfirm(String providerName) {
    return 'Clear the model list for $providerName? API Key will not be deleted.';
  }

  @override
  String get clear => 'Clear';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutContactEmail => 'Contact Email';

  @override
  String get menuSettings => 'Settings';

  @override
  String get menuAbout => 'About';

  @override
  String get mergeChats => 'Merge Chats';

  @override
  String mergeChatHint(int max) {
    return 'Select up to $max chats to merge';
  }

  @override
  String selectedCount(int count, int max) {
    return '$count/$max selected';
  }

  @override
  String get mergeAndCreate => 'Merge & Create New Chat';

  @override
  String get mergeChatConfirmTitle => 'Merge & Create';

  @override
  String get selectMountLocation => 'Select Mount Location';

  @override
  String get rootNode => 'Root (Top Level)';

  @override
  String maxSelectionReached(int max) {
    return 'Maximum $max selections';
  }

  @override
  String get multiSelect => 'Select';

  @override
  String get done => 'Done';

  @override
  String get mergeSelectGuideOnlyChat => 'Only chat-type nodes can be selected';

  @override
  String mergeSelectGuideMaxChats(int max) {
    return 'Select up to $max chats';
  }

  @override
  String get mergeSelectGuideTapMerge =>
      'Tap \"Merge & Create New Chat\" at the bottom when done';
}
