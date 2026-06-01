import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/shared/chat_composer.dart';

void main() {
  group('ChatComposer', () {
    Widget buildComposer({
      String hintText = 'Type a message',
      bool isStreaming = false,
      bool enabled = true,
      Future<void> Function(String)? onSend,
      Future<void> Function()? onStopStreaming,
    }) {
      return CupertinoApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: CupertinoPageScaffold(
          child: ChatComposer(
            hintText: hintText,
            isStreaming: isStreaming,
            enabled: enabled,
            onSend: onSend ?? (_) async {},
            onStopStreaming: onStopStreaming ?? () async {},
          ),
        ),
      );
    }

    testWidgets('renders CupertinoTextField with hint text', (tester) async {
      await tester.pumpWidget(buildComposer(hintText: 'Enter text'));

      expect(find.byType(CupertinoTextField), findsOneWidget);
      final textField = tester.widget<CupertinoTextField>(find.byType(CupertinoTextField));
      expect(textField.placeholder, 'Enter text');
    });

    testWidgets('renders Send button when not streaming', (tester) async {
      await tester.pumpWidget(buildComposer(isStreaming: false));

      expect(find.byIcon(AppIcons.send), findsOneWidget);
      expect(find.byIcon(AppIcons.stop), findsNothing);
    });

    testWidgets('renders Stop button when streaming', (tester) async {
      await tester.pumpWidget(buildComposer(isStreaming: true));

      expect(find.byIcon(AppIcons.stop), findsOneWidget);
      expect(find.byIcon(AppIcons.send), findsNothing);
    });

    testWidgets('button is disabled when enabled is false', (tester) async {
      await tester.pumpWidget(buildComposer(enabled: false));

      final button = tester.widget<CupertinoButton>(find.byType(CupertinoButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('calls onSend when text is entered and Send is tapped', (tester) async {
      String? sentText;
      await tester.pumpWidget(buildComposer(
        onSend: (text) async {
          sentText = text;
        },
      ));

      await tester.enterText(find.byType(CupertinoTextField), 'Hello world');
      await tester.tap(find.byIcon(AppIcons.send));
      await tester.pump();

      expect(sentText, 'Hello world');
    });

    testWidgets('does not call onSend when text is empty', (tester) async {
      bool called = false;
      await tester.pumpWidget(buildComposer(
        onSend: (_) async {
          called = true;
        },
      ));

      await tester.tap(find.byIcon(AppIcons.send));
      await tester.pump();

      expect(called, isFalse);
    });

    testWidgets('does not call onSend when text is only whitespace', (tester) async {
      bool called = false;
      await tester.pumpWidget(buildComposer(
        onSend: (_) async {
          called = true;
        },
      ));

      await tester.enterText(find.byType(CupertinoTextField), '   ');
      await tester.tap(find.byIcon(AppIcons.send));
      await tester.pump();

      expect(called, isFalse);
    });

    testWidgets('calls onStopStreaming when Stop is tapped', (tester) async {
      bool stopped = false;
      await tester.pumpWidget(buildComposer(
        isStreaming: true,
        onStopStreaming: () async {
          stopped = true;
        },
      ));

      await tester.tap(find.byIcon(AppIcons.stop));
      await tester.pump();

      expect(stopped, isTrue);
    });

    testWidgets('clears text field after successful send', (tester) async {
      await tester.pumpWidget(buildComposer());

      await tester.enterText(find.byType(CupertinoTextField), 'Hello');
      await tester.tap(find.byIcon(AppIcons.send));
      await tester.pump();

      final textField = tester.widget<CupertinoTextField>(find.byType(CupertinoTextField));
      expect(textField.controller?.text, isEmpty);
    });
  });
}
