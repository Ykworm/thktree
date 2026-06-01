import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/ui/core/shared/chat_list_view.dart';

void main() {
  group('ChatListView', () {
    Widget buildListView(List<SessionMessage> messages) {
      return CupertinoApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: CupertinoPageScaffold(
          child: ChatListView(
            messages: messages,
            messageBuilder: (context, message) => Text(message.body),
          ),
        ),
      );
    }

    SessionMessage makeMessage(String body) {
      return SessionMessage(
        role: SessionRole.user,
        timestampUtcIso8601: '2026-01-01T00:00:00.000Z',
        msgId: 'msg_${body.hashCode}',
        body: body,
        status: SessionMessageStatus.done,
      );
    }

    testWidgets('shows empty state when no messages', (tester) async {
      await tester.pumpWidget(buildListView([]));

      expect(find.text('No messages yet'), findsOneWidget);
    });

    testWidgets('renders messages using messageBuilder', (tester) async {
      final messages = [
        makeMessage('Hello'),
        makeMessage('World'),
      ];
      await tester.pumpWidget(buildListView(messages));

      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('World'), findsOneWidget);
    });

    testWidgets('renders single message', (tester) async {
      final messages = [makeMessage('Only one')];
      await tester.pumpWidget(buildListView(messages));

      expect(find.text('Only one'), findsOneWidget);
    });

    testWidgets('renders many messages in a ListView', (tester) async {
      final messages = List.generate(20, (i) => makeMessage('Msg $i'));
      await tester.pumpWidget(buildListView(messages));

      expect(find.byType(ListView), findsOneWidget);
    });
  });
}
