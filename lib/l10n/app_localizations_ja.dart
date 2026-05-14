// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsLanguageSection => '言語';

  @override
  String get settingsAppearanceSection => '外観';

  @override
  String get settingsAccountSection => 'アカウント';

  @override
  String get settingsNotificationsSection => '通知';

  @override
  String get settingsAboutSection => '情報';

  @override
  String get settingsAppLanguage => 'アプリの言語';

  @override
  String get settingsContentCommunity => 'コミュニティ';

  @override
  String get settingsLearningLanguage => '学習言語';

  @override
  String get settingsTheme => 'テーマ';

  @override
  String get settingsComingSoon => '近日公開';

  @override
  String get settingsEditProfile => 'プロフィールを編集';

  @override
  String get settingsSignOut => 'サインアウト';

  @override
  String get settingsSignOutSubtitle => 'この端末からサインアウトします';

  @override
  String get settingsSignInRequiredTitle => 'サインインが必要です';

  @override
  String get settingsSignInRequiredBody => '設定はサインイン後に利用できます。';

  @override
  String get settingsSignInCta => 'サインイン';

  @override
  String get settingsAppVersion => 'アプリのバージョン';

  @override
  String get settingsAppVersionPlaceholder => 'V1 シェル（バージョン表示は後で対応）';

  @override
  String get settingsSystem => 'システム';

  @override
  String get settingsEnglish => '英語';

  @override
  String get settingsJapanese => '日本語';

  @override
  String get settingsMyanmar => 'ミャンマー語';

  @override
  String get settingsInternationalEnglish => '国際 / 英語';

  @override
  String get settingsSignOutDialogTitle => 'サインアウトしますか？';

  @override
  String get settingsSignOutDialogBody => 'この端末からサインアウトしてログイン画面に戻ります。';

  @override
  String get settingsCancel => 'キャンセル';

  @override
  String get settingsReadingSection => '読書';

  @override
  String get settingsReadingTextSize => '文字サイズ';

  @override
  String get settingsReadingTextSizeSmall => '小';

  @override
  String get settingsReadingTextSizeStandard => '標準';

  @override
  String get settingsReadingTextSizeLarge => '大';

  @override
  String get settingsShowExplanationSentence => '解説文';

  @override
  String get settingsShowExplanationSentenceSubtitle => 'Monoリーダーで文ごとの解説を表示';

  @override
  String get validationPublishSheetTitle => '公開前の確認';

  @override
  String get validationPublishSectionBlocking => '必須の修正';

  @override
  String get validationPublishSectionRecommended => '推奨';

  @override
  String get validationPublishFixIssuesCta => '修正する';

  @override
  String get validationPublishAnywayCta => 'このまま公開';

  @override
  String get validationCtaSignIn => 'ログイン';

  @override
  String get validationCtaNotNow => '今はしない';

  @override
  String get validationCtaOk => 'OK';

  @override
  String get validationMediaUploadGenericImage =>
      '画像をアップロードできませんでした。もう一度お試しください。';

  @override
  String get validationMediaUploadGenericAudio =>
      '音声をアップロードできませんでした。もう一度お試しください。';

  @override
  String get validationFieldStoryTitle => 'ストーリーのタイトル';

  @override
  String get validationFieldStoryDescription => '説明';

  @override
  String get validationFieldStorySentences => '本文の文';

  @override
  String get validationFieldStoryBody => 'ストーリー本文';

  @override
  String get validationFieldStoryLevel => 'JLPTレベル';

  @override
  String get validationFieldStoryDuration => '長さ';

  @override
  String get validationFieldLearnVocabCount => '語彙';

  @override
  String get validationFieldLearnGrammarCount => '文法';

  @override
  String get validationFieldLearnQuizCount => 'クイズ';

  @override
  String get validationFieldLearnVocabulary => '語彙';

  @override
  String get validationFieldLearnGrammar => '文法';

  @override
  String get validationFieldLearnQuiz => 'クイズ';

  @override
  String get validationFieldModuleVocabularyKanji => '語彙・漢字モジュール';

  @override
  String get validationFieldModuleGrammar => '文法モジュール';

  @override
  String get validationFieldModuleQuiz => 'クイズモジュール';

  @override
  String get validationFieldModuleAudio => 'リスニングモジュール';

  @override
  String get validationFieldLearnModule => '学習モジュール';

  @override
  String validationLearnModuleNotCompletedWithLabel(String moduleLabel) {
    return '公開する前に$moduleLabelモジュールを完了してください。';
  }

  @override
  String get validationLearnModuleLabelLearn => '学習';

  @override
  String get validationLearnModuleLabelVocabularyKanji => '語彙・漢字';

  @override
  String get validationLearnModuleLabelGrammar => '文法';

  @override
  String get validationLearnModuleLabelQuiz => 'クイズ';

  @override
  String get validationLearnModuleLabelAudio => 'リスニング';

  @override
  String get validationLearnFuriganaInvalid => 'ふりがなの内容が正しくありません。';

  @override
  String get validationLearnFuriganaOverlap => 'ふりがなの範囲が重なっています。';

  @override
  String get validationProfileDisplayNameRequired => '表示名を入力してください。';

  @override
  String get validationProfileDisplayNameLength => '表示名は1〜30文字にしてください。';

  @override
  String get validationProfileDisplayNameUnsafe => '表示名に使用できない内容が含まれています。';

  @override
  String get validationProfileHandleNoEmoji => 'ユーザー名に絵文字は使えません。';

  @override
  String get validationProfileHandleLength => 'ユーザー名は3〜24文字にしてください。';

  @override
  String get validationProfileHandleInvalidChars =>
      'ユーザー名は英小文字・数字・アンダースコア・ピリオドのみ使用できます。';

  @override
  String get validationProfileHandlePeriodEdge => 'ユーザー名の先頭・末尾にピリオドは使えません。';

  @override
  String get validationProfileHandlePeriodRepeat => 'ユーザー名に連続したピリオドは使えません。';

  @override
  String get validationProfileHandleReserved => 'このユーザー名は予約されています。';

  @override
  String get validationProfileBioTooLong => '自己紹介は150文字以内にしてください。';

  @override
  String get validationProfileBioUnsafe => '自己紹介に使用できない内容が含まれています。';

  @override
  String get validationProfileBioTooManyLines => '自己紹介は3行以内にしてください。';

  @override
  String get validationStoryTitleRequired => '公開にはタイトルが必要です。';

  @override
  String get validationStoryTitleRecommended => 'ストーリーにタイトルを追加してください。';

  @override
  String get validationStoryTitleTooShort => 'タイトルは5文字以上にしてください。';

  @override
  String get validationStoryTitleTooLong => 'タイトルは80文字以内にしてください。';

  @override
  String get validationStoryTitleUnsafe => 'タイトルに使用できない内容が含まれています。';

  @override
  String get validationStoryTitleLineBreak => 'タイトルに改行は使えません。';

  @override
  String get validationStoryTitleTooManyEmoji => 'タイトルの絵文字は1つまでです。';

  @override
  String get validationStoryTitleOnlyNumbers => 'タイトルを数字だけにすることはできません。';

  @override
  String get validationStoryTitleOnlySymbols => 'タイトルを記号だけにすることはできません。';

  @override
  String get validationStoryTitleExcessiveRepeat => 'タイトルに同じ文字の繰り返しが多すぎます。';

  @override
  String get validationStoryDescriptionRecommended => '公開前に短い説明を追加してください。';

  @override
  String get validationStoryDescriptionTooLong => '説明は160文字以内にしてください。';

  @override
  String get validationStoryDescriptionUnsafe => '説明に使用できない内容が含まれています。';

  @override
  String get validationStoryDescriptionLineBreak => '説明に改行は使えません。';

  @override
  String get validationStoryDescriptionTooManyUrls => '説明に含められるリンクは1つまでです。';

  @override
  String get validationStoryDescriptionHashtagStuffing => 'ハッシュタグが多すぎます。';

  @override
  String get validationStoryDescriptionTooManyEmoji => '説明の絵文字は2つまでです。';

  @override
  String get validationStoryDescriptionExcessiveRepeat => '説明に同じ文字の繰り返しが多すぎます。';

  @override
  String get validationCollectionTitleRequired => 'コレクション名を入力してください。';

  @override
  String get validationCollectionTitleLength => 'コレクション名は1〜40文字にしてください。';

  @override
  String get validationCollectionTitleUnsafe => 'コレクション名に使用できない内容が含まれています。';

  @override
  String get validationCollectionTitleLineBreak => 'コレクション名に改行は使えません。';

  @override
  String get validationCollectionTitleNoUrl => 'コレクション名にリンクは含められません。';

  @override
  String get validationCollectionTitleTooManyEmoji => 'コレクション名の絵文字は1つまでです。';

  @override
  String get validationCollectionTitleOnlyNumbers => 'コレクション名を数字だけにすることはできません。';

  @override
  String get validationCollectionTitleOnlySymbols => 'コレクション名を記号だけにすることはできません。';

  @override
  String get validationCollectionTitleOnlySpaces => 'コレクション名には文字または数字を含めてください。';

  @override
  String get validationCollectionTitleExcessiveRepeat =>
      'コレクション名に同じ文字の繰り返しが多すぎます。';

  @override
  String get validationCollectionNameRequired => 'コレクション名を入力してください。';

  @override
  String get validationCollectionNameLength => 'コレクション名は1〜40文字にしてください。';

  @override
  String get validationCollectionNameUnsafe => 'コレクション名に使用できない内容が含まれています。';

  @override
  String get validationCollectionNameLineBreak => 'コレクション名に改行は使えません。';

  @override
  String get validationCollectionNameNoUrl => 'コレクション名にリンクは含められません。';

  @override
  String get validationCollectionNameTooManyEmoji => 'コレクション名の絵文字は1つまでです。';

  @override
  String get validationCollectionNameOnlyNumbers => 'コレクション名を数字だけにすることはできません。';

  @override
  String get validationCollectionNameOnlySymbols => 'コレクション名を記号だけにすることはできません。';

  @override
  String get validationCollectionNameOnlySpaces => 'コレクション名には文字または数字を含めてください。';

  @override
  String get validationCollectionNameExcessiveRepeat =>
      'コレクション名に同じ文字の繰り返しが多すぎます。';

  @override
  String get validationAuthEmailRequired => 'メールアドレスを入力してください。';

  @override
  String get validationAuthEmailLength => 'メールアドレスは5〜254文字にしてください。';

  @override
  String get validationAuthEmailInvalid => '正しいメールアドレス形式で入力してください。';

  @override
  String get validationAuthEmailUnsafe => 'メールアドレスに使用できない内容が含まれています。';

  @override
  String get validationAuthPasswordLength => 'パスワードは8〜64文字にしてください。';

  @override
  String get validationAuthPasswordWeak =>
      'このパスワードは一般的すぎます。より強いパスワードを設定してください。';

  @override
  String get validationAuthPasswordLineBreak => 'パスワードに改行は含められません。';

  @override
  String get validationAuthPasswordRequiredLogin => 'パスワードを入力してください。';

  @override
  String get validationAuthConfirmPasswordMismatch => 'パスワードが一致しません。';

  @override
  String get validationAuthLoginFailed => 'メールアドレスまたはパスワードが正しくありません。';

  @override
  String get validationLearnVocabMeaningRequired => 'この公開モードでは意味の入力が必要です。';

  @override
  String get validationLearnVocabMeaningLength => '意味は1〜80文字にしてください。';

  @override
  String get validationLearnVocabMeaningNoEmoji => '意味に絵文字は含められません。';

  @override
  String get validationLearnVocabMeaningLineBreak => '意味に改行は含められません。';

  @override
  String get validationLearnVocabMeaningUnsafe => '意味に使用できない内容が含まれています。';

  @override
  String get validationLearnVocabMeaningNoUrl => '意味にリンクは含められません。';

  @override
  String get validationLearnVocabMeaningNoHashtag => '意味にハッシュタグは含められません。';

  @override
  String get validationLearnVocabReadingRequired => '読みを入力してください。';

  @override
  String get validationLearnVocabReadingTooLong => '読みは40文字以内にしてください。';

  @override
  String get validationLearnVocabReadingTooManyAlternatives => '読みの候補が多すぎます。';

  @override
  String get validationLearnVocabReadingInvalidChars =>
      '読みはひらがな・カタカナ・「・」「/」のみ使用できます。';

  @override
  String get validationLearnVocabReadingUnsafe => '読みに使用できない内容が含まれています。';

  @override
  String get validationLearnGrammarTitleRequired => '文法タイトルを入力してください。';

  @override
  String get validationLearnGrammarTitleLength => '文法タイトルは2〜40文字にしてください。';

  @override
  String get validationLearnGrammarTitleNoEmoji => '文法タイトルに絵文字は含められません。';

  @override
  String get validationLearnGrammarTitleLineBreak => '文法タイトルに改行は含められません。';

  @override
  String get validationLearnGrammarTitleUnsafe => '文法タイトルに使用できない内容が含まれています。';

  @override
  String get validationLearnGrammarTitleNoUrl => '文法タイトルにリンクは含められません。';

  @override
  String get validationLearnQuizCategoryInvalid => 'クイズのカテゴリを選んでください。';

  @override
  String get validationLearnQuizQuestionRequired => '問題文を入力してください。';

  @override
  String get validationLearnQuizQuestionLength => '問題文は5〜120文字にしてください。';

  @override
  String get validationLearnQuizQuestionUnsafe => '問題文に使用できない内容が含まれています。';

  @override
  String get validationLearnQuizQuestionDuplicate => '同じ問題がすでにこのストーリーにあります。';

  @override
  String get validationLearnQuizOptionsCount => '選択肢は2〜4個にしてください。';

  @override
  String get validationLearnQuizOptionsDuplicate => '選択肢が重複しています。';

  @override
  String get validationLearnQuizAnswerRequired => '正解を選んでください。';

  @override
  String get validationLearnQuizAnswerNotInOptions => '正解は選択肢のいずれかと一致させてください。';

  @override
  String get validationLearnQuizAnswerSingleCorrect => '正解は1つだけ指定してください。';

  @override
  String get validationStorySentencesRequired => '日本語の文を1つ以上追加してください。';

  @override
  String validationStorySentencesTooFew(int min, int actual) {
    return 'レベルと長さに対して文が足りません（最低$min文・現在$actual文）。';
  }

  @override
  String validationStorySentencesTooMany(int max, int actual) {
    return 'レベルと長さに対して文が多すぎます（最大$max文・現在$actual文）。';
  }

  @override
  String validationStoryBodyTooLong(int max, int actual) {
    return '本文が長すぎます（最大$max文字・現在$actual文字）。';
  }

  @override
  String get validationStoryLimitsSkippedNoJlpt =>
      'JLPTレベルが未設定のため、文の長さ制限は適用されませんでした。';

  @override
  String get validationStoryLimitsSkippedNoBand =>
      '長さの区分が未設定のため、文の長さ制限は適用されませんでした。';

  @override
  String validationLearnCountVocabRange(int min, int max, int actual) {
    return '語彙の数は$min〜$max個にしてください（現在$actual個）。';
  }

  @override
  String validationLearnCountGrammarRange(int min, int max, int actual) {
    return '文法の数は$min〜$max個にしてください（現在$actual個）。';
  }

  @override
  String validationLearnCountQuizRange(int min, int max, int actual) {
    return 'クイズの数は$min〜$max個にしてください（現在$actual個）。';
  }

  @override
  String get validationProtectedReactLogin => 'ストーリーにリアクションするにはログインしてください。';

  @override
  String get validationProtectedFollowLogin => 'クリエイターをフォローするにはログインしてください。';

  @override
  String get validationProtectedSaveLogin => 'ストーリーを保存するにはログインしてください。';

  @override
  String get validationProtectedCreateStoryLogin => 'ストーリーを作成するにはログインしてください。';

  @override
  String get validationProtectedPublishStoryLogin => 'ストーリーを公開するにはログインしてください。';

  @override
  String get validationProtectedCreateCollectionLogin =>
      'コレクションを作成するにはログインしてください。';

  @override
  String get validationProtectedUploadMediaLogin =>
      'メディアをアップロードするにはログインしてください。';

  @override
  String get validationProtectedEditProfileLogin => 'プロフィールを編集するにはログインしてください。';

  @override
  String get validationProtectedGenericForbidden => 'この操作は利用できません。';

  @override
  String get validationProtectedGenericDisabled => 'このアカウントではこの操作は無効です。';

  @override
  String get validationMediaFileRequired => 'アップロードするファイルを選んでください。';

  @override
  String get validationMediaFileEmpty => 'このファイルは空です。別のファイルを選んでください。';

  @override
  String get validationMediaFileTooLarge => 'ファイルが大きすぎます。';

  @override
  String get validationMediaFileInvalidType => 'このファイル形式には対応していません。';

  @override
  String get validationMediaFileInvalidExtension => 'この拡張子には対応していません。';

  @override
  String get validationMediaFileInvalidField => 'アップロードに必要な項目がありません。';

  @override
  String get validationMediaImageInvalidType => 'JPG・PNG・WebPの画像を選んでください。';

  @override
  String get validationMediaImageTooLarge => '画像が大きすぎます。';

  @override
  String get validationMediaAudioInvalidType => '対応している音声ファイルを選んでください。';

  @override
  String get validationMediaAudioTooLarge => '音声ファイルが大きすぎます。';

  @override
  String get validationNetworkOffline =>
      'インターネットに接続されていません。接続を確認してから再度お試しください。';

  @override
  String get quotaDialogOk => 'OK';

  @override
  String get quotaPremiumComingLaterCta => 'プレミアムは近日対応';

  @override
  String get quotaUnknownLimitTitle => '無料プランの上限に達しました';

  @override
  String get quotaUnknownLimitMessage =>
      '無料プランの上限に達しました。古い項目を削除してからもう一度お試しください。';

  @override
  String get publishedMonoLimitReachedTitle => '無料プランの上限に達しました';

  @override
  String publishedMonoLimitReachedMessage(int limit) {
    return '無料プランではMonoを最大$limit件まで公開できます。古いMonoを削除するか、プレミアムが利用可能になったらアップグレードしてください。';
  }

  @override
  String get savedMonoLimitReachedTitle => '保存の上限に達しました';

  @override
  String savedMonoLimitReachedMessage(int limit) {
    return '無料プランではMonoを最大$limit件まで保存できます。新しく保存する前に保存済みのMonoを削除してください。';
  }

  @override
  String get collectionLimitReachedTitle => 'コレクション数の上限に達しました';

  @override
  String collectionLimitReachedMessage(int limit) {
    return '無料プランではコレクションを最大$limit個まで作成できます。プレミアム向けコレクションはV2で予定しています。';
  }

  @override
  String get collectionItemLimitReachedTitle => 'コレクションが満杯です';

  @override
  String collectionItemLimitReachedMessage(int limit) {
    return '無料プランでは1つのコレクションにMonoを最大$limit件まで入れられます。追加する前に項目を削除してください。';
  }

  @override
  String get draftStoryLimitReachedTitle => '下書きの上限に達しました';

  @override
  String draftStoryLimitReachedMessage(int limit) {
    return '無料プランでは下書きを最大$limit件まで保持できます。新しく作成する前に古い下書きを削除してください。';
  }
}
