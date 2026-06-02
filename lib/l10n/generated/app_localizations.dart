import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
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
/// import 'generated/app_localizations.dart';
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
    Locale('en'),
    Locale('zh'),
  ];

  /// Application name
  ///
  /// In en, this message translates to:
  /// **'ThkTree'**
  String get appName;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'ThkTree · Settings'**
  String get settingsTitle;

  /// Language settings tile title
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Current language display name
  ///
  /// In en, this message translates to:
  /// **'{name}'**
  String languageSubtitle(String name);

  /// System default language option
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// English language name
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// Chinese language name
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get chinese;

  /// Empty state for theme list
  ///
  /// In en, this message translates to:
  /// **'No themes yet'**
  String get noThemesYet;

  /// Dialog title for creating a new theme
  ///
  /// In en, this message translates to:
  /// **'New Theme'**
  String get newTheme;

  /// Hint text for title input field
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleHint;

  /// Cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Create button label
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Back button tooltip/label
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Tree button tooltip/label
  ///
  /// In en, this message translates to:
  /// **'Tree'**
  String get tree;

  /// Branch button tooltip/label
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get branch;

  /// Save button label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Delete button label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Close button label
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// SnackBar message after copying to clipboard
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// Loading state for settings
  ///
  /// In en, this message translates to:
  /// **'Loading settings...'**
  String get loadingSettings;

  /// Loading state for logger
  ///
  /// In en, this message translates to:
  /// **'Loading logger...'**
  String get loadingLogger;

  /// Loading state for paths
  ///
  /// In en, this message translates to:
  /// **'Loading paths...'**
  String get loadingPaths;

  /// Settings tile for log file
  ///
  /// In en, this message translates to:
  /// **'Log File'**
  String get logFile;

  /// Settings tile for remote logging
  ///
  /// In en, this message translates to:
  /// **'Remote Logging'**
  String get remoteLogging;

  /// Enabled state label
  ///
  /// In en, this message translates to:
  /// **'enabled'**
  String get enabled;

  /// Disabled state label
  ///
  /// In en, this message translates to:
  /// **'disabled'**
  String get disabled;

  /// Settings tile to view logs
  ///
  /// In en, this message translates to:
  /// **'View Logs'**
  String get viewLogs;

  /// Dialog title for viewing log tail
  ///
  /// In en, this message translates to:
  /// **'Logs (tail)'**
  String get logsTail;

  /// Empty log content placeholder
  ///
  /// In en, this message translates to:
  /// **'(empty)'**
  String get emptyLogs;

  /// Settings tile for LLM provider selection
  ///
  /// In en, this message translates to:
  /// **'LLM Provider'**
  String get llmProviderTitle;

  /// Settings tile for API key
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get llmApiKey;

  /// API key dialog title
  ///
  /// In en, this message translates to:
  /// **'{providerName} API Key'**
  String llmApiKeyTitle(String providerName);

  /// API key is configured
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get apiKeySet;

  /// API key is not configured
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get apiKeyNotSet;

  /// Settings tile for model name
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get llmModel;

  /// Model dialog title
  ///
  /// In en, this message translates to:
  /// **'{providerName} Model'**
  String llmModelTitle(String providerName);

  /// Settings tile for data root directory
  ///
  /// In en, this message translates to:
  /// **'Data Root'**
  String get dataRoot;

  /// Tree screen title with theme name
  ///
  /// In en, this message translates to:
  /// **'{title} · Tree'**
  String treeTitle(Object title);

  /// Empty state for tree screen
  ///
  /// In en, this message translates to:
  /// **'Session Tree is empty.\nTap + to create a root session.'**
  String get emptyTree;

  /// Dialog title for creating a new session
  ///
  /// In en, this message translates to:
  /// **'New Session'**
  String get newSession;

  /// Dialog title for creating a new branch
  ///
  /// In en, this message translates to:
  /// **'New Branch'**
  String get newBranch;

  /// Dialog title for deleting an item
  ///
  /// In en, this message translates to:
  /// **'Delete Item'**
  String get deleteItem;

  /// Confirmation message for deletion
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"?'**
  String deleteConfirm(Object title);

  /// Shows the target node ID in delete dialog
  ///
  /// In en, this message translates to:
  /// **'Target nodeId: {nodeId}'**
  String targetNodeId(Object nodeId);

  /// Checkbox label for delete confirmation
  ///
  /// In en, this message translates to:
  /// **'I understand only the selected nodeId subtree will be deleted.'**
  String get deleteUnderstand;

  /// Delete dialog description when there are descendants
  ///
  /// In en, this message translates to:
  /// **'This will delete 1 selected node and {count} child item(s).'**
  String deleteDescWithChildren(int count);

  /// Delete dialog description when there are no descendants
  ///
  /// In en, this message translates to:
  /// **'This will delete only the selected node.'**
  String get deleteDescOnly;

  /// Section title listing nodes with same title that will not be deleted
  ///
  /// In en, this message translates to:
  /// **'Same-title nodes that will be kept ({count}):'**
  String keptSameTitleNodes(int count);

  /// SnackBar message after deletion
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} {count, plural, =1{item} other{items}}'**
  String deletedCount(int count);

  /// Error message when branching fails
  ///
  /// In en, this message translates to:
  /// **'Branch failed: {error}'**
  String branchFailed(String error);

  /// Error message when deletion fails
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String deleteFailed(String error);

  /// Error message when saving fails
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String saveFailed(String error);

  /// Empty state for chat list
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// Hint text for chat input
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageHint;

  /// Send button label
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// Stop streaming button label
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// Summary chat screen title
  ///
  /// In en, this message translates to:
  /// **'Polish Summary'**
  String get polishSummary;

  /// Hint text for summary input
  ///
  /// In en, this message translates to:
  /// **'Modify summary...'**
  String get summaryHint;

  /// Banner text on summary screen
  ///
  /// In en, this message translates to:
  /// **'Polish the summary content. After confirmation, it will be used as the starting point for the new branch \"{title}\"'**
  String summaryBanner(Object title);

  /// Button to confirm summary
  ///
  /// In en, this message translates to:
  /// **'Confirm this summary'**
  String get confirmSummary;

  /// Button text while generating summary
  ///
  /// In en, this message translates to:
  /// **'Generating summary...'**
  String get generatingSummary;

  /// Button to create branch from summary
  ///
  /// In en, this message translates to:
  /// **'Create Branch'**
  String get createBranch;

  /// Button text while creating branch
  ///
  /// In en, this message translates to:
  /// **'Creating branch...'**
  String get creatingBranch;

  /// Button to create branch with raw parent context
  ///
  /// In en, this message translates to:
  /// **'Use Original Context'**
  String get skipSummary;

  /// Button to create branch with no context at all
  ///
  /// In en, this message translates to:
  /// **'Start Fresh'**
  String get blankBranch;

  /// SnackBar when confirming without summary
  ///
  /// In en, this message translates to:
  /// **'Please generate the summary content first'**
  String get pleaseGenerateSummary;

  /// Error when branch creation fails
  ///
  /// In en, this message translates to:
  /// **'Branch creation failed: {error}'**
  String branchCreationFailed(Object error);

  /// User role label in message bubble
  ///
  /// In en, this message translates to:
  /// **'user'**
  String get userRole;

  /// Assistant role label in message bubble
  ///
  /// In en, this message translates to:
  /// **'assistant'**
  String get assistantRole;

  /// System role label in message bubble
  ///
  /// In en, this message translates to:
  /// **'system'**
  String get systemRole;

  /// Streaming status label in message bubble
  ///
  /// In en, this message translates to:
  /// **'streaming'**
  String get streamingStatus;

  /// Error status label in message bubble
  ///
  /// In en, this message translates to:
  /// **'error:{code}'**
  String errorStatus(Object code);

  /// Unknown error code
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get errorUnknown;

  /// Button to open table in full-screen view
  ///
  /// In en, this message translates to:
  /// **'Expand Table'**
  String get expandTable;

  /// Copy selected text action
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// Add selected text to a note action
  ///
  /// In en, this message translates to:
  /// **'Add to Note'**
  String get addToNote;

  /// Notes screen title
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// Select note subtitle on note picker page
  ///
  /// In en, this message translates to:
  /// **'Select a note to append to...'**
  String get selectNote;

  /// Empty state for notes list
  ///
  /// In en, this message translates to:
  /// **'No notes yet. Tap + to create one.'**
  String get noNotesYet;

  /// Dialog title for creating a new note
  ///
  /// In en, this message translates to:
  /// **'New Note'**
  String get newNote;

  /// Shows note count per theme
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 notes} =1{1 note} other{{count} notes}}'**
  String noteCount(int count);

  /// Display name of the catch-all theme used for notes created from the notes tab
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get uncategorized;

  /// Title for model providers management screen
  ///
  /// In en, this message translates to:
  /// **'Model Providers'**
  String get llmProvidersTitle;

  /// Label for custom LLM provider
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get llmProviderCustom;

  /// Button to add a custom LLM provider
  ///
  /// In en, this message translates to:
  /// **'Add Custom Provider'**
  String get addCustomProvider;

  /// Label for provider name field
  ///
  /// In en, this message translates to:
  /// **'Provider Name'**
  String get providerName;

  /// Label for provider base URL field
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get providerBaseUrl;

  /// Label showing the default URL for a provider
  ///
  /// In en, this message translates to:
  /// **'Default URL'**
  String get providerDefaultUrl;

  /// Label for provider API key field
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get providerApiKey;

  /// API key is configured
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get apiKeyConfigured;

  /// API key is not configured
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get apiKeyNotConfigured;

  /// Shows the number of models available for a provider
  ///
  /// In en, this message translates to:
  /// **'{count} models'**
  String modelCount(int count);

  /// No models available for a provider
  ///
  /// In en, this message translates to:
  /// **'No models'**
  String get noModels;

  /// Button to delete a provider
  ///
  /// In en, this message translates to:
  /// **'Delete Provider'**
  String get deleteProvider;

  /// Confirmation message for deleting a provider
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this provider?'**
  String get deleteProviderConfirm;

  /// Button to fetch models from a provider
  ///
  /// In en, this message translates to:
  /// **'Fetch Models'**
  String get fetchModels;

  /// Loading state while fetching models
  ///
  /// In en, this message translates to:
  /// **'Fetching models...'**
  String get fetchingModels;

  /// Success message after fetching models
  ///
  /// In en, this message translates to:
  /// **'Successfully fetched {count} models'**
  String fetchModelsSuccess(int count);

  /// Error message when fetching models fails
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch models: {error}'**
  String fetchModelsFailed(String error);

  /// Message when API key is invalid or expired
  ///
  /// In en, this message translates to:
  /// **'API Key is invalid or expired'**
  String get apiKeyInvalid;

  /// Title for model selection panel
  ///
  /// In en, this message translates to:
  /// **'Select Model'**
  String get selectModel;

  /// Label showing the currently selected model
  ///
  /// In en, this message translates to:
  /// **'Current Model'**
  String get currentModel;

  /// Placeholder when no model is selected
  ///
  /// In en, this message translates to:
  /// **'No model selected'**
  String get noModelSelected;

  /// Shows context window usage percentage
  ///
  /// In en, this message translates to:
  /// **'Context: {percent}%'**
  String contextUsagePercent(int percent);

  /// Hint text for custom provider name input
  ///
  /// In en, this message translates to:
  /// **'e.g. ProviderName + ModelName for easy identification'**
  String get customProviderHint;

  /// Hint text for base URL input
  ///
  /// In en, this message translates to:
  /// **'Enter the API base URL'**
  String get baseUrlHint;

  /// Hint text for API key input
  ///
  /// In en, this message translates to:
  /// **'Enter the API Key'**
  String get apiKeyHint;

  /// Button to save provider configuration
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveProvider;

  /// Button to edit a provider
  ///
  /// In en, this message translates to:
  /// **'Edit Provider'**
  String get editProvider;

  /// Button to copy the default URL to clipboard
  ///
  /// In en, this message translates to:
  /// **'Copy default URL'**
  String get copyDefaultUrl;

  /// SnackBar message after copying to clipboard
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// Hint shown when no configured provider is available in model selector
  ///
  /// In en, this message translates to:
  /// **'Please configure a provider and fetch models in settings first'**
  String get pleaseFetchModels;

  /// Button or menu item to start a chat from a note
  ///
  /// In en, this message translates to:
  /// **'Start Chat from Note'**
  String get createChatFromNote;

  /// Title for theme selection
  ///
  /// In en, this message translates to:
  /// **'Select Theme'**
  String get selectTheme;

  /// Title for chat location selection
  ///
  /// In en, this message translates to:
  /// **'Select Location'**
  String get selectLocation;

  /// Option to create chat as a root node
  ///
  /// In en, this message translates to:
  /// **'As root conversation'**
  String get asRootChat;

  /// Option to create chat under a specific node
  ///
  /// In en, this message translates to:
  /// **'Under \"{title}\"'**
  String underNode(String title);

  /// Label for chat title input
  ///
  /// In en, this message translates to:
  /// **'Chat Title'**
  String get chatTitle;

  /// SnackBar message after chat is created
  ///
  /// In en, this message translates to:
  /// **'Chat created successfully'**
  String get chatCreated;

  /// Tab bar label for the themes/tree tab
  ///
  /// In en, this message translates to:
  /// **'Themes'**
  String get themesTabLabel;

  /// Tab bar label for the settings tab
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTabLabel;

  /// Menu item shown when text is selected to create a new branch directly from the selection (raw mode)
  ///
  /// In en, this message translates to:
  /// **'Create Branch from Selection'**
  String get createBranchRawFromSelection;

  /// Menu item shown when text is selected to create a new branch by first LLM-summarizing the selection
  ///
  /// In en, this message translates to:
  /// **'Summarize Selection, then Create Branch'**
  String get createBranchSummarizeFromSelection;

  /// Title of the title-suggestion screen for creating a new branch
  ///
  /// In en, this message translates to:
  /// **'Choose Title'**
  String get chooseTitle;

  /// Banner showing the source of the new branch on the title-suggestion screen
  ///
  /// In en, this message translates to:
  /// **'Branch from {source}'**
  String titleSourceBanner(String source);

  /// Source label when the branch is created from a text selection
  ///
  /// In en, this message translates to:
  /// **'Selected Text'**
  String get titleSourceSelection;

  /// Source label when the branch is created from the raw conversation
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get titleSourceConversation;

  /// Source label when the branch is created from an LLM-summarized conversation
  ///
  /// In en, this message translates to:
  /// **'Conversation Summary'**
  String get titleSourceConversationSummary;

  /// Source label when the branch is created from a note
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get titleSourceNote;

  /// Hint text for the optional direction input used when regenerating candidate titles
  ///
  /// In en, this message translates to:
  /// **'Direction (optional)'**
  String get titleDirectionHint;

  /// Button to regenerate LLM candidate titles
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get titleRegenerate;

  /// Loading state while LLM is generating candidate titles
  ///
  /// In en, this message translates to:
  /// **'Generating titles...'**
  String get titleGenerating;

  /// Label shown when LLM candidate title generation fails
  ///
  /// In en, this message translates to:
  /// **'Generation failed'**
  String get titleAutoGenFailed;

  /// Action to switch to a different LLM model when generation fails
  ///
  /// In en, this message translates to:
  /// **'Switch Model'**
  String get titleModelSwitch;

  /// Empty state hint on the title-suggestion screen
  ///
  /// In en, this message translates to:
  /// **'No candidates yet. Try a different direction.'**
  String get titleCandidatesEmpty;

  /// Confirm button on the title-suggestion screen
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get titleConfirm;

  /// Loading state while LLM is summarizing the source conversation
  ///
  /// In en, this message translates to:
  /// **'Summarizing conversation...'**
  String get summarizing;

  /// Fallback message when conversation summarization fails
  ///
  /// In en, this message translates to:
  /// **'Summarization failed, using raw conversation as branch source'**
  String get summarizeFailedFallback;

  /// Title of the action sheet that lets the user pick raw vs summarized branch creation
  ///
  /// In en, this message translates to:
  /// **'Choose how to create the branch'**
  String get branchModeSheetTitle;

  /// Action sheet option: create a branch from an LLM summary of the source context
  ///
  /// In en, this message translates to:
  /// **'Summarize, then create'**
  String get branchModeSummarize;

  /// Action sheet option: create a branch from the raw (un-summarized) source context
  ///
  /// In en, this message translates to:
  /// **'Use the original context'**
  String get branchModeRaw;

  /// Action sheet submit button: must be enabled only after the user picks one of the two modes
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get branchModeContinue;

  /// Friendly message when a streaming LLM request is interrupted by app backgrounding
  ///
  /// In en, this message translates to:
  /// **'Network interrupted. Please retry.'**
  String get networkInterrupted;

  /// Action button to retry the failed LLM summary call
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get branchRetry;

  /// Action button to dismiss the retry prompt and abort the branch flow
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get branchCancelRetry;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
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
