import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/learn/learn_explanation_language.dart';
import 'package:nimon/features/learn/listening_pronunciation_screen.dart';
import 'package:nimon/features/learn/listening_transcript_models.dart';
import 'package:nimon/features/mono/mono_content_model.dart';
import 'package:nimon/ui/reading/nimon_ruby_text.dart';

void main() {
  testWidgets('showTranslation off hides support text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListeningTranscriptSentenceBlock(
            line: ListeningTranscriptLine(
              japanese: 'こんにちは。',
              translationEnglish: 'Hello.',
              publishedExplanation: const MonoExplanationLine(
                en: 'Hello.',
                my: 'မင်္ဂလာပါ။',
              ),
            ),
            explanationLanguage: LearnExplanationLanguage.english,
            showTranslation: false,
          ),
        ),
      ),
    );
    expect(find.textContaining('Hello'), findsNothing);
    expect(find.textContaining('こんにちは'), findsOneWidget);
  });

  testWidgets('showTranslation on shows published explanation primary',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListeningTranscriptSentenceBlock(
            line: ListeningTranscriptLine(
              japanese: 'こんにちは。',
              publishedExplanation: const MonoExplanationLine(
                en: 'Hello.',
                my: 'မင်္ဂလာပါ။',
              ),
            ),
            explanationLanguage: LearnExplanationLanguage.english,
            showTranslation: true,
          ),
        ),
      ),
    );
    expect(find.textContaining('မင်္ဂလာပါ'), findsOneWidget);
  });

  testWidgets('furigana path uses NimonRubyText for tokenized line',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListeningTranscriptSentenceBlock(
            line: ListeningTranscriptLine(
              japanese: '天気',
              rubyTokens: const [
                MonoRubyToken(text: '天気', reading: 'てんき'),
              ],
            ),
            explanationLanguage: LearnExplanationLanguage.english,
            showTranslation: false,
          ),
        ),
      ),
    );
    expect(find.byType(NimonRubyText), findsOneWidget);
  });
}
