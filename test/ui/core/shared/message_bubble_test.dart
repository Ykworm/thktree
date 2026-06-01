import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/ui/core/shared/message_bubble.dart';

void main() {
  group('MessageBubble', () {
    Widget buildBubble(SessionMessage message) {
      return CupertinoApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: CupertinoPageScaffold(
          child: MessageBubble(message: message),
        ),
      );
    }

    SessionMessage makeMessage({
      required SessionRole role,
      String body = 'Hello',
      SessionMessageStatus status = SessionMessageStatus.done,
      String? errorCode,
    }) {
      return SessionMessage(
        role: role,
        timestampUtcIso8601: '2026-01-01T00:00:00.000Z',
        msgId: 'msg_01JFFFFFFFFFFFFFFFFFFFFFFFF',
        body: body,
        status: status,
        errorCode: errorCode,
      );
    }

    testWidgets('renders user message with correct alignment and title', (tester) async {
      final message = makeMessage(role: SessionRole.user, body: 'Hi there');
      await tester.pumpWidget(buildBubble(message));

      expect(find.text('user'), findsOneWidget);
      expect(find.text('Hi there'), findsOneWidget);

      final align = tester.widget<Align>(find.byType(Align).first);
      expect(align.alignment, Alignment.centerRight);
    });

    testWidgets('renders assistant message aligned left', (tester) async {
      final message = makeMessage(role: SessionRole.assistant, body: 'I can help');
      await tester.pumpWidget(buildBubble(message));

      expect(find.text('assistant'), findsOneWidget);
      expect(find.text('I can help'), findsOneWidget);

      final align = tester.widget<Align>(find.byType(Align).first);
      expect(align.alignment, Alignment.centerLeft);
    });

    testWidgets('renders system message aligned left', (tester) async {
      final message = makeMessage(role: SessionRole.system, body: 'System note');
      await tester.pumpWidget(buildBubble(message));

      expect(find.text('system'), findsOneWidget);
      expect(find.text('System note'), findsOneWidget);
    });

    testWidgets('shows streaming status when message is streaming', (tester) async {
      final message = makeMessage(
        role: SessionRole.assistant,
        body: 'Thinking...',
        status: SessionMessageStatus.streaming,
      );
      await tester.pumpWidget(buildBubble(message));

      expect(find.textContaining('streaming'), findsOneWidget);
    });

    testWidgets('shows error status with error code', (tester) async {
      final message = makeMessage(
        role: SessionRole.assistant,
        status: SessionMessageStatus.error,
        errorCode: 'timeout',
      );
      await tester.pumpWidget(buildBubble(message));

      expect(find.textContaining('error:timeout'), findsOneWidget);
    });

    testWidgets('shows error status with unknown when no error code', (tester) async {
      final message = makeMessage(
        role: SessionRole.assistant,
        status: SessionMessageStatus.error,
      );
      await tester.pumpWidget(buildBubble(message));

      expect(find.textContaining('error:unknown'), findsOneWidget);
    });

    testWidgets('does not show status text for done messages', (tester) async {
      final message = makeMessage(role: SessionRole.assistant, status: SessionMessageStatus.done);
      await tester.pumpWidget(buildBubble(message));

      final titleFinder = find.descendant(
        of: find.byType(MessageBubble),
        matching: find.byType(Text),
      );
      final titles = tester.widgetList<Text>(titleFinder).map((t) => t.data).toList();
      expect(titles, isNot(contains('done')));
    });

    testWidgets('renders markdown body even when body is empty', (tester) async {
      final message = makeMessage(role: SessionRole.user, body: '');
      await tester.pumpWidget(buildBubble(message));

      expect(find.byType(MarkdownBody), findsOneWidget);
    });

    testWidgets('shows expand button only when message has a table', (tester) async {
      final tableMsg = makeMessage(
        role: SessionRole.assistant,
        body: '| A | B |\n|---|---|\n| 1 | 2 |',
      );
      await tester.pumpWidget(buildBubble(tableMsg));

      expect(find.byIcon(CupertinoIcons.arrow_up_left_arrow_down_right), findsOneWidget);

      await tester.tap(find.byIcon(CupertinoIcons.arrow_up_left_arrow_down_right));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoNavigationBar), findsOneWidget);
    });

    testWidgets('renders markdown bold text correctly', (tester) async {
      final message = makeMessage(role: SessionRole.assistant, body: 'This is **bold** text');
      await tester.pumpWidget(buildBubble(message));

      expect(find.textContaining('bold'), findsOneWidget);
    });
  });
}
