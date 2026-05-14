// ignore_for_file: unnecessary_const, unnecessary_brace_in_string_interps, use_build_context_synchronously, prefer_function_declarations_over_variables, deprecated_member_use

import 'dart:async' show unawaited;
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/data/story_repo.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/auth/auth_session_state.dart';
import 'package:nimon/features/auth/guest_remote_draft_warning.dart';
import 'package:nimon/features/create/creator_back_policy.dart';
import 'package:nimon/features/mono/mono_content_model.dart';
import 'package:nimon/features/mono/mono_reading_layout.dart';
import 'package:nimon/features/mono/mono_reader_dock.dart';
import 'package:nimon/features/mono/mono_reader_menu_origin.dart';
import 'package:nimon/l10n/app_localizations.dart';
import 'package:nimon/ui/reading/nimon_ruby_text.dart';
import 'package:nimon/ui/reading/nimon_sentence_block.dart';
import 'package:nimon/ui/bottom_sheets/mono_story_options_sheet.dart';
import 'package:nimon/ui/quota_exceeded_dialog.dart';
import 'package:nimon/widgets/floating_dock_nav_bar.dart';
import 'package:nimon/core/design_system/nimon_typography.dart';
import 'package:nimon/core/format_social_count.dart';
import 'package:nimon/ui/shell/floating_dock_tab_handler.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/mono/data/mono_feed_item_mapper.dart';
import 'package:nimon/features/mono/data/mono_feed_providers.dart';
import 'package:nimon/features/mono/mono_feed_models.dart';
import 'package:nimon/features/mono/saved_only_ux_policy.dart';
import 'package:nimon/features/mono/share_mono_link.dart';
import 'package:nimon/features/profile/saved_library_copy.dart';
import 'package:nimon/features/profile/data/published_mono_catalog_visibility_exception.dart';
import 'package:nimon/features/profile/data/published_mono_display_contract.dart';
import 'package:nimon/features/profile/creator_profile_location.dart';
import 'package:nimon/features/profile/profile_processing_refresh.dart';
import 'package:nimon/core/design_system/nimon_color_tokens.dart';
import 'package:nimon/core/networking/network_error_mapping.dart';
import 'package:nimon/core/validation/app_quota_exceeded_exception.dart';
import 'package:nimon/core/validation/protected_action.dart';
import 'package:nimon/core/validation/protected_action_guard.dart';
import 'package:nimon/features/mono/mono_following_guest_auth_panel.dart';
import 'package:nimon/features/mono/mono_line_explanation_display.dart';
import 'package:nimon/features/settings/presentation/providers/user_preferences_notifier.dart';
import 'package:nimon/features/mono/bookmark_ownership_policy.dart';
import 'package:nimon/features/profile/data/profile_public_providers.dart';
import 'package:nimon/features/profile/presentation/providers/profile_following_pager.dart';

export 'mono_feed_models.dart';

String _monoCoverFallbackAsset(MonoCoverCategory c) {
  switch (c) {
    case MonoCoverCategory.love:
      return 'assets/images/one_short/love.png';
    case MonoCoverCategory.horror:
      return 'assets/images/one_short/horror.png';
    case MonoCoverCategory.culture:
      return 'assets/images/one_short/history.png';
    case MonoCoverCategory.comedy:
      return 'assets/images/one_short/comedy.png';
    case MonoCoverCategory.art:
      return 'assets/images/one_short/art.png';
    case MonoCoverCategory.history:
      return 'assets/images/one_short/history.png';
  }
}

MonoCoverCategory _monoDefaultCoverCategory(MonoContentType t) {
  switch (t) {
    case MonoContentType.story:
      return MonoCoverCategory.art;
    case MonoContentType.letter:
      return MonoCoverCategory.love;
    case MonoContentType.dialogue:
      return MonoCoverCategory.comedy;
    case MonoContentType.sentence:
      return MonoCoverCategory.art;
    case MonoContentType.diary:
      return MonoCoverCategory.love;
    case MonoContentType.article:
      return MonoCoverCategory.culture;
  }
}

MonoCoverCategory _monoEffectiveCoverCategory(MonoFeedItem item) =>
    item.coverCategory ?? _monoDefaultCoverCategory(item.contentType);

/// Main Mono feed scope (For You vs Following) — only used when [MonoScreen.showTopControls] is true.
enum _MonoMainFeedKind { forYou, following }

/// Mono reader–only collections (V1 mock); not wired to Profile folder screens.
class _MonoSaveFolder {
  _MonoSaveFolder({required this.id, required this.name});
  final String id;
  String name;
}

class MonoScreen extends ConsumerStatefulWidget {
  final StoryRepo repo;
  final MonoFeedItem? initialItemOverride;
  final List<MonoFeedItem>? initialItemsOverride;
  final int initialIndexOverride;
  final bool showTopControls;
  final Widget? bottomDock;
  final double? bottomDockHeight;

  /// When non-null, folder-aware reader ([/mono-reader]) menu panel uses Saved vs Uploaded actions.
  final MonoReaderMenuOrigin? readerMenuOrigin;

  /// Profile Saved tab: remove item from saved lists when reader menu Unsave is used.
  final void Function(String monoFeedItemId)? onUnsavedMonoFeedItemId;

  const MonoScreen({
    super.key,
    required this.repo,
    this.initialItemOverride,
    this.initialItemsOverride,
    this.initialIndexOverride = 0,
    this.showTopControls = true,
    this.bottomDock,
    this.bottomDockHeight,
    this.readerMenuOrigin,
    this.onUnsavedMonoFeedItemId,
  });

  @override
  ConsumerState<MonoScreen> createState() => _MonoScreenState();
}

class _MonoScreenState extends ConsumerState<MonoScreen> {
  static const _levels = <String>['All', 'N5', 'N4', 'N3', 'N2', 'N1'];

  static String _levelDisplayLabel(String v) => v == 'All' ? 'All levels' : v;

  static String _levelCompactMenuLabel(String v) =>
      v == 'All' ? 'All levels' : v;

  NimonColorTokens _nimonColors(ThemeData theme) {
    return theme.extension<NimonColorTokens>() ??
        (theme.brightness == Brightness.dark
            ? NimonColorTokens.dark
            : NimonColorTokens.light);
  }

  /// Legacy small mock set (retired from primary V1 dataset).
  // ignore: unused_field
  static const _legacyMockItems = <MonoFeedItem>[
    MonoFeedItem(
      id: 'm1',
      writerName: '読解ノート',
      writerHandle: '@yomi_n4',
      level: 'N4',
      contentType: MonoContentType.article,
      title: '町の図書館',
      coverImageUrl: 'https://picsum.photos/seed/nimon-m1/800/1000',
      content: MonoContent(
        id: 'm1',
        title: '町の図書館',
        pages: [
          MonoContentPage(
            pageId: 'p1',
            lines: [
              MonoSentenceLine(
                tokens: [
                  MonoRubyToken(text: '町'),
                  MonoRubyToken(text: 'の'),
                  MonoRubyToken(text: '図書館', reading: 'としょかん'),
                  MonoRubyToken(text: 'は'),
                  MonoRubyToken(text: '駅', reading: 'えき'),
                  MonoRubyToken(text: 'から'),
                  MonoRubyToken(text: '歩', reading: 'ある'),
                  MonoRubyToken(text: 'いて'),
                  MonoRubyToken(text: '五分'),
                  MonoRubyToken(text: 'の'),
                  MonoRubyToken(text: '場所'),
                  MonoRubyToken(text: 'にある。'),
                ],
                plainText: '町の図書館は駅から歩いて五分の場所にある。',
                explanation: MonoExplanationLine(
                  en: 'The town library is a five-minute walk from the station.',
                  my: 'မြို့ရဲ့ စာကြည့်တိုက်က ဘူတာရုံကနေ လမ်းလျှောက် ၅ မိနစ်အကွာမှာ ရှိတယ်။',
                ),
              ),
              MonoSentenceLine(
                tokens: [
                  MonoRubyToken(text: '古', reading: 'ふる'),
                  MonoRubyToken(text: 'い'),
                  MonoRubyToken(text: '商店街', reading: 'しょうてんがい'),
                  MonoRubyToken(text: 'を'),
                  MonoRubyToken(text: '抜', reading: 'ぬ'),
                  MonoRubyToken(text: 'けると、'),
                  MonoRubyToken(text: '入口'),
                  MonoRubyToken(text: 'が'),
                  MonoRubyToken(text: '見', reading: 'み'),
                  MonoRubyToken(text: 'えてくる。'),
                ],
                plainText: '古い商店街を抜けると、入口が見えてくる。',
                explanation: MonoExplanationLine(
                  en: 'After you pass through the old shopping street, you can see the entrance.',
                  my: 'ကုန်စည်လမ်းတန်းဟောင်းကို ဖြတ်ပြီးရင် ဝင်ပေါက်ကို မြင်ရတယ်။',
                ),
              ),
              MonoSentenceLine(
                tokens: const [],
                plainText: '自動ドアが開くと、紙と木の匂いがふわりと流れてくる。',
                explanation: const MonoExplanationLine(
                  en: 'When the automatic doors open, you smell paper and wood.',
                ),
              ),
              MonoSentenceLine(
                tokens: const [],
                plainText: 'ロビーの案内図には、児童書、一般書、郷土資料室、学習席が示されている。',
                explanation: const MonoExplanationLine(
                  en: 'The lobby map shows children’s books, general books, local history room, and study seats.',
                ),
              ),
            ],
          ),
          MonoContentPage(
            pageId: 'p2',
            lines: [
              MonoSentenceLine(
                tokens: [
                  MonoRubyToken(text: '開館時間', reading: 'かいかんじかん'),
                  MonoRubyToken(text: 'は'),
                  MonoRubyToken(text: '午前'),
                  MonoRubyToken(text: '九時'),
                  MonoRubyToken(text: 'から'),
                  MonoRubyToken(text: '午後'),
                  MonoRubyToken(text: '八時'),
                  MonoRubyToken(text: 'までだ。'),
                ],
                plainText: '開館時間は午前九時から午後八時までだ。',
                explanation: const MonoExplanationLine(
                  en: 'Opening hours are 9:00 to 20:00.',
                  my: 'ဖွင့်ချိန်က မနက် ၉ နာရီကနေ ည ၈ နာရီအထိပါ။',
                ),
              ),
              MonoSentenceLine(
                tokens: [
                  MonoRubyToken(text: '仕事帰', reading: 'しごとがえ'),
                  MonoRubyToken(text: 'り'),
                  MonoRubyToken(text: 'の'),
                  MonoRubyToken(text: '人'),
                  MonoRubyToken(text: 'が'),
                  MonoRubyToken(text: '寄', reading: 'よ'),
                  MonoRubyToken(text: 'れるように、'),
                  MonoRubyToken(text: '平日'),
                  MonoRubyToken(text: 'は'),
                  MonoRubyToken(text: '遅', reading: 'おそ'),
                  MonoRubyToken(text: 'くまで開いている。'),
                ],
                plainText: '仕事帰りの人が寄れるように、平日は遅くまで開いている。',
                explanation: const MonoExplanationLine(
                  en: 'On weekdays it stays open late so people can stop by after work.',
                ),
              ),
              MonoSentenceLine(
                tokens: const [],
                plainText: '混雑する日は、入口の掲示板で学習席の空き状況を確認できる。',
                explanation: const MonoExplanationLine(
                  en: 'On busy days, you can check seat availability on the entrance board.',
                ),
              ),
              MonoSentenceLine(
                tokens: const [],
                plainText: '貸出は十冊まで、期限は二週間。返却日を忘れない工夫が大切だ。',
                explanation: const MonoExplanationLine(
                  en: 'You can borrow up to 10 books for two weeks.',
                ),
              ),
            ],
          ),
        ],
      ),
      bodyText:
          'この文章は、ある町の図書館について書かれている。図書館は駅から歩いて五分の場所にあり、古い商店街を抜けた先に建っている。入口の自動ドアが開くと、紙と木の匂いがふわりと流れてくる。ロビーには案内図があり、児童書のコーナー、一般書の棚、郷土資料室、学習席の場所が示されている。\n\n'
          '開館時間は午前九時から午後八時までで、日曜と祝日は休館だ。仕事帰りの人が寄れるように、平日は遅くまで開いている。一方、夏休みの期間は子どもの利用が増えるため、午後の時間帯は特に混みやすい。混雑する日は、学習席の空き状況が入口の掲示板で確認できるようになっている。\n\n'
          '館内では静かに本を読むことが求められる。携帯電話での通話は避け、通知音が鳴らないように設定する。飲食は指定された休憩スペース以外ではできないが、ふた付きの飲み物は学習席で認められている。利用者はそれぞれの席を譲り合い、長時間席を離れる場合は荷物を片付ける決まりだ。\n\n'
          '貸出には会員証が必要で、一度に借りられる冊数は十冊まで、期限は二週間である。返却が遅れると次の貸出が制限されるため、返却日を忘れない工夫が大切だ。図書館では返却日を知らせる手段として、メール通知と紙のしおりの両方を用意している。高齢の利用者には、窓口で職員が丁寧に説明する。\n\n'
          '最近、子ども向けの読書会が毎月第一土曜日に開かれている。参加は無料で、事前の申し込みは不要だという。読み聞かせの後には、簡単な工作や感想の交換の時間があり、親子で楽しめる。さらに月に一度、地域の歴史を学ぶ講座も行われ、古い写真や地図を使って町の変化をたどる。図書館は本を借りる場所にとどまらず、人が集まり、学びを共有する拠点になっている。',
    ),
    MonoFeedItem(
      id: 'm2',
      writerName: '敬語ドリル',
      writerHandle: '@keigo_n3',
      level: 'N3',
      contentType: MonoContentType.dialogue,
      title: '来客対応',
      content: MonoContent(
        id: 'm2',
        title: '来客対応',
        pages: [
          MonoContentPage(
            pageId: 'p1',
            lines: [
              MonoSentenceLine(
                tokens: const [],
                plainText: '受付の前に立った男性は、軽く名刺入れを整えた。',
                explanation: const MonoExplanationLine(
                  en: 'At reception, he adjusted his business card holder.',
                ),
              ),
              MonoSentenceLine(
                tokens: const [],
                plainText: '来客：お忙しいところ恐れ入ります。佐藤部長はご在席でしょうか。',
                explanation: const MonoExplanationLine(
                  en: 'Visitor: Excuse me. Is Manager Sato available?',
                ),
              ),
              MonoSentenceLine(
                tokens: const [],
                plainText: '受付：承知いたしました。少々お待ちいただけますでしょうか。',
                explanation: const MonoExplanationLine(
                  en: 'Reception: Certainly. Could you please wait a moment?',
                ),
              ),
              MonoSentenceLine(
                tokens: const [],
                plainText: '受付：こちらの応接室へご案内いたします。',
                explanation: const MonoExplanationLine(
                  en: 'Reception: I will show you to the meeting room.',
                ),
              ),
            ],
          ),
        ],
      ),
      bodyText: '受付の前に立った男性は、軽く名刺入れを整え、息を整えてから声をかけた。\n'
          '来客：お忙しいところ恐れ入ります。佐藤部長はご在席でしょうか。\n'
          '受付：承知いたしました。少々お待ちいただけますでしょうか。失礼いたします。\n\n'
          '受付は内線で確認し、受話器を置くと、丁寧に頭を下げた。\n'
          '受付：お待たせいたしました。佐藤がすぐに参りますので、こちらの応接室へご案内いたします。\n'
          '来客：ありがとうございます。お手数をおかけいたします。\n\n'
          '応接室では、受付が席を示し、お茶の用意を整える。\n'
          '受付：どうぞ、こちらへおかけください。本日はお足元の悪い中、誠にありがとうございます。\n'
          '来客：いえ、とんでもございません。お時間をいただき、恐れ入ります。\n\n'
          'しばらくして佐藤が入室し、双方が名刺を交換する。名刺の向き、目線、言葉の順番に、互いの配慮が現れる。\n'
          '佐藤：お待たせいたしました。佐藤でございます。本日はご足労いただき、ありがとうございます。\n'
          '来客：こちらこそ、貴重なお時間を頂戴し、誠にありがとうございます。本日は新しい提案について、ご説明の機会をいただければと存じます。\n\n'
          '佐藤：承知いたしました。まずは概要から伺えますでしょうか。\n'
          '来客：はい。資料はお手元の一枚目をご覧ください。結論から申しますと、現行の手順を維持しつつ、確認工程のみ短縮できる見込みがございます。\n\n'
          '話が進むにつれ、来客は言い切りを避け、確度を示しながら慎重に言葉を選ぶ。佐藤も質問の前に一言添え、相手の説明を遮らない。\n'
          '佐藤：恐れ入りますが、前提条件をもう一点確認させてください。現場の人員配置に影響はございませんか。\n'
          '来客：ご懸念の点、承知しております。影響が出ないよう、段階的に切り替える案をご用意いたしました。\n\n'
          '面談の終盤、来客は深く頭を下げる。\n'
          '来客：本日はありがとうございました。ご検討のほど、何卒よろしくお願い申し上げます。\n'
          '佐藤：こちらこそ、丁寧なご説明をありがとうございました。社内で確認のうえ、改めてご連絡いたします。',
    ),
    MonoFeedItem(
      id: 'm3',
      writerName: '会議メモ',
      writerHandle: '@biz_team',
      level: 'N3',
      contentType: MonoContentType.dialogue,
      title: 'プレゼン資料の打ち合わせ',
      bodyText:
          '会議室に集まった三人は、来週のプレゼン資料の整合性を確認していた。机の上には、印刷されたスライドと、赤いペン、付せんが並んでいる。窓の外は夕方の光で、隣のビルの影が長く伸びていた。\n\n'
          '田中：まず、二枚目のグラフですが、数値の出所が部署ごとに違って見えます。ここは統一しましょう。\n'
          '鈴木：確かに。営業側の数字は今月の速報値で、企画側は先月確定のデータを使ってますね。比較するなら同じ基準にしないと誤解されます。\n'
          '山本：出典の資料名も書いておきましょう。後から質問されたとき、すぐ答えられます。\n\n'
          '鈴木：それと、クライアント側は図表そのものより、文章での根拠説明を重視する傾向があります。数字が良く見えるだけだと、逆に警戒されることもあります。\n'
          '田中：じゃあ、脚注に出典を明記して、要点は本文で簡潔に補足します。例えば、なぜこの数字が増えたのか、要因を一つ二つ書くだけでも印象が変わります。\n\n'
          '山本：四枚目の提案内容は、言葉が少し強いかもしれません。「必ず改善します」より「改善が見込めます」の方が安全です。\n'
          '鈴木：同意です。約束のように読まれると、後で困ります。代替案も一行だけ入れておきませんか。もし条件が満たせない場合は、こういう進め方もできる、みたいな。\n\n'
          '田中：いいですね。あとは締切。金曜の午後五時までに社内レビューを通して、夜に最終版を作りたいです。\n'
          '山本：問題ありません。共有ドライブに最新版を入れておきます。各自、差分だけ確認して、気になる点があれば付せんかコメントで残してください。\n\n'
          '鈴木：最後に、質疑応答の想定も作りましょう。「なぜ今なのか」「費用対効果は」「導入リスクは」あたりは必ず聞かれます。\n'
          '田中：じゃあ、私が質問集のたたき台を作ります。山本さんは導入手順、鈴木さんは効果の根拠を整理してください。\n\n'
          '会議室を出るころには、机の上の紙が色とりどりの付せんで埋まっていた。三人は疲れをにじませながらも、資料が一歩ずつ形になっていく手応えを共有していた。',
    ),
    MonoFeedItem(
      id: 'm4',
      writerName: '就活ノート',
      writerHandle: '@shukatsu_n2',
      level: 'N2',
      contentType: MonoContentType.article,
      title: '自己PR（抜粋）',
      bodyText:
          '大学では情報工学を専攻し、講義で得た知識を現場に近い形で試したいと考え、学内のプロジェクトに積極的に参加してきた。特に力を入れたのは、複数人でのチーム開発である。私は設計書のレビューと進捗管理を担当し、役割の重なりや認識のずれを早い段階で見つけることに注力した。\n\n'
          'チームには異なる専攻のメンバーもおり、専門用語の理解度や優先順位がそれぞれ異なっていた。そこで私は、設計の意図を図と短い文章でまとめ、週に二回、十分だけの確認会を設けた。長い会議ではなく、短く頻度を上げることで、作業の手戻りを減らす狙いがあった。また、課題が発生した際は責任を個人に帰さず、要因を「情報不足」「仕様の曖昧さ」「確認不足」のように分類し、次に同じことが起きない仕組みを考えた。\n\n'
          'その結果、学園祭向けのアプリを期限内に公開し、当日は多くの来場者に利用してもらうことができた。特に、受付の待ち時間を短縮する機能は好評で、現場の担当者から「運用が楽になった」と評価をいただいた。一方で、公開直前に想定外のアクセスが集中し、画面が重くなる問題も経験した。原因を分析し、不要な通信を減らす改善を行ったことで、短時間で安定化させることができた。\n\n'
          'この経験から、技術力だけでなく、関係者への説明力と調整力がプロジェクト成功に不可欠だと学んだ。自分の中で理解しているだけでは不十分で、相手が判断できる形に落とし込み、合意を取りながら進めることが重要である。貴社でも、現場のニーズを正確に把握し、設計から実装、運用まで一貫して責任を持って取り組みたい。',
    ),
    MonoFeedItem(
      id: 'm5',
      writerName: '美咲',
      writerHandle: '@misaki_note',
      level: 'N4',
      contentType: MonoContentType.diary,
      title: '忘年会の夜',
      bodyText:
          '今日は部署の忘年会があった。会場の居酒屋は駅前の路地にあって、入口ののれんが風に揺れていた。私は少し早く着いてしまい、店の前で手袋の指先を握りしめながら、深呼吸をしていた。こういう集まりは苦手だ。話題に入れずに笑うだけで終わることも多い。\n\n'
          'でも、席に着くと、上司が軽い冗談を言ってくれて場が和んだ。隣の先輩が料理を取り分けながら、「今年は大変だったね」と声をかけてくれた。私は「はい、でも助けてもらいました」と答えた。言葉にすると、胸の中に溜めていた緊張が少しずつほどけていくのがわかった。\n\n'
          '途中で、普段あまり話さない別の部署の人と、趣味の話になった。意外にも同じ作家の小説を読んでいて、好きな場面を話すうちに、時間が早く流れた。私は「この人の文章、静かなのに強いですよね」と言った。相手は「わかる。余白があるのに、後から残る」と返してくれた。その一言が嬉しくて、私は何度も頷いた。\n\n'
          '終盤、今年の振り返りを一人ずつ言う流れになった。私は迷った末に、できるだけ短く話した。「慣れない仕事で失敗も多かったですが、相談することの大切さを学びました。来年は、早めに共有して、周りの負担を減らせるようにしたいです。」言い終えたとき、拍手が起きた。形式的な拍手でも、私には十分だった。\n\n'
          '帰りの電車では、窓に映る自分の顔が少しだけ明るく見えた。冷たいガラスに指を当てながら、来年の目標を考えた。大きなことではなくていい。小さな改善を積み重ねて、気づいたら自分の歩幅で進めている、そんな一年にしたい。駅に着いたとき、外の空気が澄んでいて、遠くの街灯が柔らかく滲んでいた。',
    ),
    MonoFeedItem(
      id: 'm6',
      writerName: '初級会話',
      writerHandle: '@kaiwa_n5',
      level: 'N5',
      contentType: MonoContentType.dialogue,
      title: '本屋で',
      content: MonoContent(
        id: 'm6',
        title: '本屋で',
        pages: [
          MonoContentPage(
            pageId: 'p1',
            lines: [
              MonoSentenceLine(
                tokens: const [],
                plainText: '駅の近くに、小さな本屋があります。',
                explanation: const MonoExplanationLine(
                  en: 'There is a small bookstore near the station.',
                  my: 'ဘူတာရုံအနီးမှာ စာအုပ်ဆိုင်သေးသေးလေး တစ်ဆိုင်ရှိတယ်။',
                ),
              ),
              MonoSentenceLine(
                tokens: const [],
                plainText: 'ケン：すみません。この本、いくらですか。',
                explanation: const MonoExplanationLine(
                  en: 'Ken: Excuse me. How much is this book?',
                ),
              ),
              MonoSentenceLine(
                tokens: const [],
                plainText: '店員：千二百円です。',
                explanation: const MonoExplanationLine(
                  en: 'Clerk: It is 1,200 yen.',
                ),
              ),
              MonoSentenceLine(
                tokens: const [],
                plainText: 'ケン：じゃあ、この本をください。',
                explanation: const MonoExplanationLine(
                  en: 'Ken: Then, I’ll take this book.',
                ),
              ),
            ],
          ),
        ],
      ),
      bodyText:
          '駅の近くの小さな本屋は、入口のベルが鳴るとすぐに店員が顔を上げる。棚の間は少し狭いが、紙の匂いが落ち着く場所だ。ケンは日本語の勉強を始めてから、ここに来るのが楽しみになっていた。\n\n'
          'ケン：すみません。この本、いくらですか。\n'
          '店員：こちらですね。千二百円です。\n'
          'ケン：ありがとうございます。中を見てもいいですか。\n'
          '店員：はい、どうぞ。カバーの見本もありますので、必要でしたらお声がけください。\n\n'
          'ケンはページをめくり、ふりがなが少しだけ付いているのを見つけて安心した。棚の上に、季節のしおりが並んでいる。\n'
          'ケン：あの、しおりも買えますか。\n'
          '店員：はい。こちらは一枚百円です。雨の日の絵と、電車の絵が人気ですよ。\n\n'
          'ケン：じゃあ、この本と、電車のしおりをください。\n'
          '店員：かしこまりました。お会計はレジでお願いします。\n\n'
          'レジに並ぶ間、ケンは店内の掲示を見た。「今月のおすすめ」と書かれた紙に、短い紹介文が添えられている。読めない漢字もあるが、意味がつながる部分が増えてきたことが嬉しい。\n\n'
          '店員：お待たせしました。袋はご利用になりますか。\n'
          'ケン：はい、お願いします。\n'
          '店員：ありがとうございます。しおりは本の中に入れておきますね。\n\n'
          '店を出ると、外は夕方の冷たい風だった。ケンは袋を抱え直し、駅までの道をゆっくり歩いた。今夜はこの本を少しだけ読んで、わからない言葉をメモしよう。そう考えるだけで、足取りが軽くなった。',
    ),
    MonoFeedItem(
      id: 'm7',
      writerName: '社会記事抜粋',
      writerHandle: '@column_n2',
      level: 'N2',
      contentType: MonoContentType.article,
      title: '地方と移住',
      bodyText:
          '近年、地方自治体は人口減少に直面し、公共サービスの維持が大きな課題となっている。学校の統廃合、路線バスの減便、診療所の人手不足など、生活の基盤に関わる変化が同時に進む。人口が減れば税収も減り、自治体の財政は厳しくなる。結果として、これまで当たり前だった支援や設備を維持するだけでも、慎重な優先順位づけが必要になる。\n\n'
          '一方で、リモートワークの普及に伴い、都市部から移住する世帯も増えつつある。自然の多い環境で子育てをしたい、家賃の負担を減らしたい、通勤時間を生活に戻したい、といった理由が挙げられる。移住者の増加は地域に新しい活力をもたらす可能性があるが、受け入れ側の準備が整っていない場合、生活習慣や価値観の違いが摩擦になることもある。\n\n'
          'ある県では、空き家情報をオンラインで公開し、移住希望者と所有者を結びつける取り組みを始めた。写真だけでなく、周辺の医療機関や買い物環境、冬の積雪状況など、生活に必要な情報も一緒に掲載することで、移住後の想像がしやすくなる工夫がされている。申し込み件数は想定を上回り、地域おこし協力隊への関心も高まっているという。\n\n'
          'ただし、医療や交通の利便性への不安は依然として根強い。とくに高齢者が多い地域では、通院手段の確保が切実である。専門家は、デジタル技術による遠隔診療の拡充や、行政と民間の連携による交通ネットワークの再編が鍵になると指摘する。例えば、病院と自宅を結ぶ送迎の仕組みや、需要に応じて運行する小型車両の導入など、従来の路線中心の発想を見直す必要がある。\n\n'
          '移住政策は住居の確保だけでは完結しない。仕事、教育、医療、地域コミュニティなど、複数の要素が絡み合う。持続可能な地域社会を実現するには、住民参加型の計画づくりと、長期的な財政設計の両方が求められるだろう。短期的な成果だけを追うのではなく、地域の暮らしをどう守り、どう変えていくのかを丁寧に議論することが重要である。',
    ),
    MonoFeedItem(
      id: 'm8',
      writerName: '遥',
      writerHandle: '@haru_letters',
      level: 'N3',
      contentType: MonoContentType.letter,
      title: '季節のあいさつ',
      bodyText:
          'お元気ですか。先日はお手紙ありがとうございました。封を開けたとき、懐かしい字の並びを見て、胸の奥がふっと温かくなりました。こちらは秋が深まり、朝晩は手袋が必要なくらい冷え込んできました。駅前の並木は少しずつ色づき、帰り道の風が冬の匂いを運んできます。\n\n'
          '引っ越してから、ようやく生活のリズムが整ってきました。最初の一週間は、スーパーの場所もわからず、道を覚えるだけで疲れてしまって、夜は早く寝ていました。今は、近所の小さなパン屋を見つけて、朝に寄るのが楽しみです。店の人が「寒くなりましたね」と声をかけてくれるだけで、知らない町でも少し安心できます。\n\n'
          '仕事はまだ慣れないことばかりです。電話の取り方一つでも緊張して、終わった後にメモを見直して反省しています。でも、先輩が「最初はみんなそうだよ」と笑ってくれました。その笑い方が優しくて、私は思わず肩の力が抜けました。帰宅してから、今日の出来事を短く日記に書くようにしています。書くと、頭の中が整理されて、明日の不安が少しだけ小さくなる気がします。\n\n'
          'こちらの町は、夜になると静かです。車の音が少なく、窓を開けると遠くの踏切の音が聞こえます。たまに、昔あなたと歩いた帰り道を思い出します。あの頃は、何が大変で、何が幸せなのか、うまく言葉にできませんでした。今は、そういう小さな時間が、じわじわと大切だったのだとわかります。\n\n'
          '今年の冬は実家に帰れるかどうか、まだ分かりません。仕事の予定が直前まで決まらないので、はっきりしたらすぐ連絡します。もし帰れないとしても、写真を送りますね。こちらで見つけた景色や、冬の空の色を、あなたにも見せたいです。どうかご自愛ください。寒さが増す季節ですから、無理をせず、あたたかくして過ごしてください。',
    ),
    MonoFeedItem(
      id: 'm9',
      writerName: '蒼',
      writerHandle: '@ao_story',
      level: 'N4',
      contentType: MonoContentType.story,
      title: '時計店',
      coverCategory: MonoCoverCategory.horror,
      bodyText:
          '古い時計店の主人は、客が来ない日でも作業台の前に座っていた。店の奥には、止まったままの振り子時計がいくつも並び、時々、木のきしむ音だけが小さく響いた。窓の外を通る人の足音が、午後の店内に遠く反射して消える。主人はそれを聞きながら、細いドライバーを指先で転がし、古い油の匂いに包まれていた。\n\n'
          'ある日、雨の気配が漂う夕方、若い女性が壊れた懐中時計を差し出した。表面の金属は擦れて鈍い光を放ち、鎖の留め具は少し曲がっていた。\n'
          '女性：直せなくても構いません。大切なものなので、見ていただけるだけでも。\n'
          '主人：預かりましょう。時間はかかるかもしれませんが。\n\n'
          '女性はほっとしたように頷き、店を出る前に一度だけ振り返った。その目には、言葉にしきれない何かが映っていた。主人は時計を手のひらに乗せ、重みを確かめた。蓋を開けると、針は十二時の少し手前で止まっている。まるで、途中で息を止めたみたいだった。\n\n'
          '主人はルーペを覗き込み、歯車のひとつが歪んでいるのを見つけた。傷は小さく、素人なら気づかない程度だ。しかし、ほんのわずかな歪みが、動きを止めてしまう。主人は歪みを戻すための工具を探し、慎重に力を加えた。金属は抵抗し、やがて、ほんの少しだけ形を変えた。\n\n'
          'それから数日、主人は時計を分解し、汚れを落とし、部品を一つずつ磨いた。古い油を取り除き、新しい油をほんの少しだけ差す。多すぎると重くなる。足りないと摩耗する。経験が、量を教えてくれる。夜、店を閉めた後も、主人は作業台の灯りを消さなかった。\n\n'
          '翌週、女性が店を訪れた。主人は何も言わず、懐中時計を差し出した。女性が蓋を開けた瞬間、針が小さな音を立てて動き始めた。時計は、自分の居場所を思い出したかのように、ゆっくりと時を刻んだ。\n'
          '女性：……動いてる。\n'
          '主人：止まっていたのは、部品だけではなかったのかもしれませんね。\n\n'
          '女性は目を伏せ、短く息を吸った。そのまま深く頭を下げ、時計を胸に抱えた。店の外では、雨がやみかけていた。濡れた道路に街灯が映り、揺れる光が、さっきまで止まっていた時間の続きを照らしているように見えた。',
    ),
    MonoFeedItem(
      id: 'm10',
      writerName: '契約レビュー',
      writerHandle: '@legal_biz',
      level: 'N2',
      contentType: MonoContentType.dialogue,
      title: '法務確認',
      bodyText:
          '会議室の机の上に契約書の草案が広げられ、ページの端には付せんが何枚も貼られていた。空調の音だけが静かに響く中、担当者が指先で条文をなぞりながら話し始める。\n\n'
          '担当：契約条件の第八項について、解釈に齟齬がないか、法務と最終確認をお願いします。ここ、表現が少し曖昧で、相手に有利に読まれる可能性があります。\n'
          '法務：承知しました。具体的には、成果物の検収の条件ですね。現行のままだと、検収が遅れた場合の責任範囲が広く見えます。\n\n'
          '担当：相手は「検収に時間がかかることもある」と言っていますが、こちらとしては、受領後の期限を明確にしたいです。\n'
          '法務：そうですね。「合理的な期間」という表現は便利ですが、争点になりやすい。受領後何営業日以内に回答するか、例外をどう扱うか、ここで決めておきましょう。\n\n'
          '担当：では、受領後五営業日以内に検収結果を通知、ただし不備がある場合はその限りではない、という形にしますか。\n'
          '法務：それに加えて、不備の指摘は具体的に列挙する、と入れると良いです。抽象的な理由で差し戻されるのを防げます。\n\n'
          '担当：承知しました。明日の午前中までにドラフトを修正し、関係部門に回覧します。\n'
          '法務：ありがとうございます。もう一点、損害賠償の上限も確認したいです。上限の計算基準が「支払総額」なのか「直近一年分」なのかで、意味が変わります。\n\n'
          '担当：相手は強く出てきそうですね。\n'
          '法務：交渉の余地はあります。業務の性質とリスクを踏まえて、こちらの許容範囲を先に整理しましょう。想定事故の種類、影響範囲、保険の有無など、背景を添えると、主張が通りやすい。\n\n'
          '担当：ありがとうございます。署名締切が来週月曜ですので、金曜までに草案を確定させましょう。\n'
          '法務：了解です。リスクが残る箇所は注釈で明示しておきます。社内の承認ルートも合わせて確認し、締切に遅れないよう進めます。\n\n'
          '二人は最後にスケジュールを確認し、次の連絡のタイミングを決めた。条文の一行一行は小さいが、その積み重ねが後の安心につながる。紙の上の言葉を、現実の運用に結びつけるための作業が続いていく。',
    ),
    MonoFeedItem(
      id: 'm11',
      writerName: '蓮',
      writerHandle: '@ren_one',
      level: 'N5',
      contentType: MonoContentType.sentence,
      title: null,
      bodyText:
          'きのうより、ちょっとだけ早起きできた。目覚ましが鳴る前に目が覚めたとき、窓の外がまだ薄暗くて、部屋の空気が少し冷たかった。布団の中で迷ったけれど、今日は起きてみようと思った。\n\n'
          '顔を洗って、湯気の立つお茶をいれた。台所の静けさの中で、やかんの音だけが小さく鳴る。いつもなら慌ただしく出る時間に、まだ余裕があるのが不思議だった。\n\n'
          '机に座って、昨日のメモを見返した。うまくできなかったこともあるけれど、少しだけ前に進めたこともある。完璧じゃなくていい、と自分に言い聞かせる。小さな変化に満足できる日は、心が軽い。\n\n'
          '外が明るくなってきた。遠くで電車の音が聞こえる。今日も一日、同じように始まるのに、気持ちは昨日と少し違う。私はその違いを、大切にしてみようと思った。',
    ),
    MonoFeedItem(
      id: 'm12',
      writerName: '接客練習',
      writerHandle: '@setsu_n3',
      level: 'N3',
      contentType: MonoContentType.dialogue,
      title: 'カフェで',
      content: MonoContent(
        id: 'm12',
        title: 'カフェで',
        pages: [
          MonoContentPage(
            pageId: 'p1',
            lines: [
              MonoSentenceLine(
                tokens: const [],
                plainText: '駅前のカフェは、雨の日でも人が多い。',
                explanation: const MonoExplanationLine(
                  en: 'The cafe near the station is crowded even on rainy days.',
                ),
              ),
              MonoSentenceLine(
                tokens: const [],
                plainText: '客：すみません、カウンターの席は空いていますか。',
                explanation: const MonoExplanationLine(
                  en: 'Customer: Excuse me, is there a counter seat available?',
                ),
              ),
              MonoSentenceLine(
                tokens: const [],
                plainText: '店員：申し訳ございません。ただいま満席でございます。',
                explanation: const MonoExplanationLine(
                  en: 'Staff: Sorry, we are full right now.',
                ),
              ),
              MonoSentenceLine(
                tokens: const [],
                plainText: '店員：十五分ほどお待ちいただけますでしょうか。',
                explanation: const MonoExplanationLine(
                  en: 'Staff: Could you wait about 15 minutes?',
                ),
              ),
            ],
          ),
        ],
      ),
      bodyText:
          '駅前のカフェは、雨の日でも人が多い。窓に当たる雨粒が流れるのを眺めながら、店内ではコーヒーの香りが広がっている。入口に入った客が、少し濡れた傘をたたみながら声をかけた。\n\n'
          '客：すみません、カウンターの席は空いていますか。\n'
          '店員：申し訳ございません。ただいま満席でございます。お名前を頂戴して、十五分ほどお待ちいただけますでしょうか。\n\n'
          '客：山田です。では、順番が来たら呼んでください。\n'
          '店員：ありがとうございます。山田様ですね。お呼び出しの際はお名前と番号の両方でご案内いたします。\n\n'
          '客は入口近くの待ちスペースに移動し、壁のメニューを眺める。季節限定の飲み物が目に入り、少し迷った。\n'
          '客：あの、待っている間に注文してもいいですか。\n'
          '店員：はい、もちろんでございます。お席がご用意でき次第、お持ちいたします。\n\n'
          '客：では、温かいカフェラテをお願いします。それから、チーズケーキも。\n'
          '店員：かしこまりました。カフェラテのサイズはいかがなさいますか。\n'
          '客：普通で大丈夫です。\n'
          '店員：ありがとうございます。チーズケーキは本日分が残り二つでございますので、確保しておきますね。\n\n'
          'しばらくして、店員が呼びかける。\n'
          '店員：山田様、お待たせいたしました。こちらへどうぞ。\n'
          '客：ありがとうございます。\n\n'
          '客が席に着くと、店員はトレーを丁寧に置いた。\n'
          '店員：カフェラテでございます。熱くなっておりますので、お気をつけください。チーズケーキはこの後すぐにお持ちいたします。\n'
          '客：助かります。\n\n'
          '雨音の中で、客は湯気の立つカップを両手で包んだ。外は灰色でも、店内はあたたかい。短い休憩が、思ったより大切に感じられた。',
    ),
  ];

  // ---------------------------------------------------------------------------
  // V1 mock dataset reset pack (primary).
  //
  // This powers: For You, Following, Saved + folders. Legacy lists remain above
  // for backward safety but are no longer used by default.
  // ---------------------------------------------------------------------------

  static MonoRubyToken _rt(String text, [String? reading]) =>
      MonoRubyToken(text: text, reading: reading);

  static MonoSentenceLine _jaPlain(String text,
          {MonoExplanationLine? explain}) =>
      MonoSentenceLine(tokens: const [], plainText: text, explanation: explain);

  static MonoSentenceLine _jaRuby(
    String plainText,
    List<MonoRubyToken> tokens, {
    MonoExplanationLine? explain,
  }) =>
      MonoSentenceLine(
          tokens: tokens, plainText: plainText, explanation: explain);

  static MonoContent _content(
      String id, String title, List<MonoSentenceLine> lines) {
    return MonoContent(
      id: id,
      title: title,
      pages: [
        MonoContentPage(pageId: 'p1', lines: lines),
      ],
    );
  }

  static final List<MonoFeedItem> _mockItems =
      List<MonoFeedItem>.unmodifiable(_buildV1MonoMockItems());

  static final List<MonoFeedItem> _followingMockItems =
      List<MonoFeedItem>.unmodifiable(_buildV1FollowingMockItems(_mockItems));

  /// Seed saved state for V1 demo flows.
  static final Set<String> _seedSavedIds = <String>{
    'n5_1',
    'n5_3',
    'n4_2',
  };

  /// One optional folder per saved item (absent => default Saved only).
  static final Map<String, String> _seedFolderByItemId = <String, String>{
    'n5_1': 'mono_read_later',
    'n5_3': 'mono_favorites',
    'n4_2': 'mono_read_later',
  };

  static List<MonoFeedItem> _buildV1MonoMockItems() {
    MonoFeedItem item({
      required String id,
      required String writerName,
      required String writerHandle,
      required String level,
      required MonoContentType type,
      required String title,
      required String coverSeed,
      required List<MonoSentenceLine> lines,
    }) {
      return MonoFeedItem(
        id: id,
        writerName: writerName,
        writerHandle: writerHandle,
        level: level,
        contentType: type,
        title: title,
        coverImageUrl: 'https://picsum.photos/seed/$coverSeed/800/1000',
        content: _content(id, title, lines),
        // Legacy fallback retained for compatibility (reader uses structured first).
        bodyText: lines.map((l) => l.plainText).join('\n'),
      );
    }

    List<MonoSentenceLine> makeCoreDailyLines({
      required String place,
      required String level,
      required int extraCount,
    }) {
      final out = <MonoSentenceLine>[
        _jaRuby(
          '雨上がりの駅で、風が少し冷たかった。',
          [
            _rt('雨上がり'),
            _rt('の'),
            _rt('駅', 'えき'),
            _rt('で、'),
            _rt('風'),
            _rt('が'),
            _rt('少', 'すこ'),
            _rt('し'),
            _rt('冷', 'つめ'),
            _rt('たかった。'),
          ],
        ),
        _jaRuby(
          '図書館へ行く前に、商店街をゆっくり歩いた。',
          [
            _rt('図書館', 'としょかん'),
            _rt('へ'),
            _rt('行', 'い'),
            _rt('く'),
            _rt('前'),
            _rt('に、'),
            _rt('商店街', 'しょうてんがい'),
            _rt('を'),
            _rt('ゆっくり'),
            _rt('歩', 'ある'),
            _rt('いた。'),
          ],
        ),
        _jaRuby(
          '開館時間を見て、まだ余裕があると分かった。',
          [
            _rt('開館時間', 'かいかんじかん'),
            _rt('を'),
            _rt('見'),
            _rt('て、'),
            _rt('まだ'),
            _rt('余裕'),
            _rt('が'),
            _rt('ある'),
            _rt('と'),
            _rt('分', 'わ'),
            _rt('かった。'),
          ],
        ),
        _jaPlain('今日は${place}で小さな発見があった。'),
      ];

      for (int i = 0; i < extraCount; i++) {
        if (i % 5 == 0) {
          out.add(
            _jaRuby(
              '窓辺でコーヒーを飲みながら、朝刊を開いた。',
              [
                _rt('窓辺', 'まどべ'),
                _rt('で'),
                _rt('コーヒー'),
                _rt('を'),
                _rt('飲'),
                _rt('みながら、'),
                _rt('朝刊', 'ちょうかん'),
                _rt('を'),
                _rt('開'),
                _rt('いた。'),
              ],
            ),
          );
        } else if (i % 7 == 0 && level != 'N5') {
          out.add(
            _jaRuby(
              '仕事帰りに受付で丁寧に用件を伝えた。',
              [
                _rt('仕事帰り', 'しごとがえり'),
                _rt('に'),
                _rt('受付', 'うけつけ'),
                _rt('で'),
                _rt('丁寧', 'ていねい'),
                _rt('に'),
                _rt('用件'),
                _rt('を'),
                _rt('伝'),
                _rt('えた。'),
              ],
            ),
          );
        } else {
          out.add(_jaPlain('短いメモを${i + 1}行だけ書いた。'));
        }
      }
      return out;
    }

    List<MonoSentenceLine> makeThemeLines({
      required String themeKey,
      required String level,
      required int extraCount,
    }) {
      final base = <MonoSentenceLine>[];
      switch (themeKey) {
        case 'station':
          base.addAll([
            _jaRuby(
              '朝のホームで、電車の音が近づいてきた。',
              [
                _rt('朝'),
                _rt('の'),
                _rt('ホーム'),
                _rt('で、'),
                _rt('電車', 'でんしゃ'),
                _rt('の'),
                _rt('音', 'おと'),
                _rt('が'),
                _rt('近', 'ちか'),
                _rt('づいてきた。'),
              ],
            ),
            _jaRuby(
              '改札の前で切符を確かめ、息を整えた。',
              [
                _rt('改札'),
                _rt('の'),
                _rt('前'),
                _rt('で'),
                _rt('切符', 'きっぷ'),
                _rt('を'),
                _rt('確', 'たし'),
                _rt('かめ、'),
                _rt('息'),
                _rt('を'),
                _rt('整', 'ととの'),
                _rt('えた。'),
              ],
            ),
          ]);
          break;
        case 'library':
          base.addAll([
            _jaRuby(
              '図書館の静けさに、紙の匂いが混ざっていた。',
              [
                _rt('図書館', 'としょかん'),
                _rt('の'),
                _rt('静', 'しず'),
                _rt('けさ'),
                _rt('に、'),
                _rt('紙'),
                _rt('の'),
                _rt('匂', 'にお'),
                _rt('い'),
                _rt('が'),
                _rt('混', 'ま'),
                _rt('ざっていた。'),
              ],
            ),
            _jaRuby(
              '郷土資料室で古い地図を開き、町の名前を追った。',
              [
                _rt('郷土資料室', 'きょうどしりょうしつ'),
                _rt('で'),
                _rt('古', 'ふる'),
                _rt('い'),
                _rt('地図', 'ちず'),
                _rt('を'),
                _rt('開', 'ひら'),
                _rt('き、'),
                _rt('町'),
                _rt('の'),
                _rt('名前'),
                _rt('を'),
                _rt('追', 'お'),
                _rt('った。'),
              ],
            ),
          ]);
          break;
        case 'cafe':
          base.addAll([
            _jaRuby(
              '窓辺の席で、湯気の立つカップを両手で包んだ。',
              [
                _rt('窓辺', 'まどべ'),
                _rt('の'),
                _rt('席'),
                _rt('で、'),
                _rt('湯気', 'ゆげ'),
                _rt('の'),
                _rt('立', 'た'),
                _rt('つ'),
                _rt('カップ'),
                _rt('を'),
                _rt('両手'),
                _rt('で'),
                _rt('包', 'つつ'),
                _rt('んだ。'),
              ],
            ),
            _jaPlain('店内は静かで、外の雨だけが続いていた。'),
          ]);
          break;
        case 'office':
          base.addAll([
            _jaRuby(
              '受付で用件を伝えると、丁寧に会議室へ案内された。',
              [
                _rt('受付', 'うけつけ'),
                _rt('で'),
                _rt('用件'),
                _rt('を'),
                _rt('伝'),
                _rt('えると、'),
                _rt('丁寧', 'ていねい'),
                _rt('に'),
                _rt('会議室', 'かいぎしつ'),
                _rt('へ'),
                _rt('案内', 'あんない'),
                _rt('された。'),
              ],
            ),
            _jaPlain('資料を並べながら、言葉の順番を頭の中で確認した。'),
          ]);
          break;
        case 'travel':
          base.addAll([
            _jaRuby(
              '夜行バスの窓に、街灯の光が流れていく。',
              [
                _rt('夜行', 'やこう'),
                _rt('バス'),
                _rt('の'),
                _rt('窓'),
                _rt('に、'),
                _rt('街灯', 'がいとう'),
                _rt('の'),
                _rt('光'),
                _rt('が'),
                _rt('流', 'なが'),
                _rt('れていく。'),
              ],
            ),
            _jaRuby(
              '旅館の廊下は長く、足音だけが柔らかく響いた。',
              [
                _rt('旅館', 'りょかん'),
                _rt('の'),
                _rt('廊下', 'ろうか'),
                _rt('は'),
                _rt('長', 'なが'),
                _rt('く、'),
                _rt('足音', 'あしおと'),
                _rt('だけが'),
                _rt('柔', 'やわ'),
                _rt('らかく'),
                _rt('響', 'ひび'),
                _rt('いた。'),
              ],
            ),
          ]);
          break;
        case 'school':
          base.addAll([
            _jaRuby(
              '放課後の教室で、ノートの余白に例文を書いた。',
              [
                _rt('放課後', 'ほうかご'),
                _rt('の'),
                _rt('教室', 'きょうしつ'),
                _rt('で、'),
                _rt('ノート'),
                _rt('の'),
                _rt('余白'),
                _rt('に'),
                _rt('例文', 'れいぶん'),
                _rt('を'),
                _rt('書'),
                _rt('いた。'),
              ],
            ),
            _jaPlain('友だちは先に帰り、黒板の文字だけが残った。'),
          ]);
          break;
        default:
          base.addAll(
              makeCoreDailyLines(place: themeKey, level: level, extraCount: 0));
      }

      final out = <MonoSentenceLine>[...base];
      for (int i = 0; i < extraCount; i++) {
        final k = (i + themeKey.hashCode.abs()) % 9;
        if (k == 0) {
          out.add(_jaRuby('開館時間をメモして、次の予定を組み直した。', [
            _rt('開館時間', 'かいかんじかん'),
            _rt('を'),
            _rt('メモ'),
            _rt('して、'),
            _rt('次'),
            _rt('の'),
            _rt('予定'),
            _rt('を'),
            _rt('組'),
            _rt('み直', 'なお'),
            _rt('した。'),
          ]));
        } else if (k == 1 && level != 'N5') {
          out.add(_jaRuby('仕事帰りに寄り道をして、気持ちを切り替えた。', [
            _rt('仕事帰り', 'しごとがえり'),
            _rt('に'),
            _rt('寄', 'よ'),
            _rt('り道', 'みち'),
            _rt('を'),
            _rt('して、'),
            _rt('気持'),
            _rt('ち'),
            _rt('を'),
            _rt('切', 'き'),
            _rt('り替', 'か'),
            _rt('えた。'),
          ]));
        } else if (k == 2) {
          out.add(_jaPlain('短い文章を声に出して読んだ。'));
        } else if (k == 3) {
          out.add(_jaRuby('窓の外の雲を見て、天気の変化を想像した。', [
            _rt('窓'),
            _rt('の'),
            _rt('外'),
            _rt('の'),
            _rt('雲'),
            _rt('を'),
            _rt('見'),
            _rt('て、'),
            _rt('天気'),
            _rt('の'),
            _rt('変化'),
            _rt('を'),
            _rt('想像', 'そうぞう'),
            _rt('した。'),
          ]));
        } else if (k == 4 && level == 'N1') {
          out.add(_jaPlain('言葉の選択は、状況だけでなく関係性の設計にも影響する。'));
        } else if (k == 5 && level == 'N2') {
          out.add(_jaPlain('前提を揃えたうえで、結論の妥当性を確かめる必要がある。'));
        } else {
          out.add(_jaPlain('今日のメモを見返し、次に読む本を決めた。'));
        }
      }
      return out;
    }

    // Creators for Following realism (multiple accounts).
    const c1 = ('Nimo Daily', '@nimo_daily');
    const c2 = ('駅と天気', '@eki_weather');
    const c3 = ('図書館ログ', '@toshokan_log');
    const c4 = ('仕事の日本語', '@office_keigo');
    const c5 = ('旅の夜', '@yako_travel');
    const c6 = ('文章研究', '@bunsho_lab');
    const c7 = ('随筆', '@essay_n1');
    const c8 = ('朝の習慣', '@morning_habit');
    const c9 = ('街の記録', '@city_notes');
    const c10 = ('教室ノート', '@classroom_n3');
    const c11 = ('カフェ読書', '@cafe_reads');
    const c12 = ('ニュース短評', '@news_n2');
    const c13 = ('語感メモ', '@word_sense');
    const c14 = ('旅と駅', '@trip_platform');

    final items = <MonoFeedItem>[
      // N5 (short + medium)
      item(
        id: 'n5_1',
        writerName: c1.$1,
        writerHandle: c1.$2,
        level: 'N5',
        type: MonoContentType.diary,
        title: '朝の駅',
        coverSeed: 'mono-n5-1',
        lines: makeCoreDailyLines(place: '駅', level: 'N5', extraCount: 6),
      ),
      item(
        id: 'n5_2',
        writerName: c2.$1,
        writerHandle: c2.$2,
        level: 'N5',
        type: MonoContentType.sentence,
        title: '雨の日',
        coverSeed: 'mono-n5-2',
        lines: makeCoreDailyLines(place: '家', level: 'N5', extraCount: 5),
      ),
      item(
        id: 'n5_3',
        writerName: c3.$1,
        writerHandle: c3.$2,
        level: 'N5',
        type: MonoContentType.article,
        title: 'はじめての図書館',
        coverSeed: 'mono-n5-3',
        lines: makeCoreDailyLines(place: '図書館', level: 'N5', extraCount: 7),
      ),
      item(
        id: 'n5_4',
        writerName: c1.$1,
        writerHandle: c1.$2,
        level: 'N5',
        type: MonoContentType.dialogue,
        title: 'コンビニで',
        coverSeed: 'mono-n5-4',
        lines: makeCoreDailyLines(place: 'コンビニ', level: 'N5', extraCount: 5),
      ),
      item(
        id: 'n5_5',
        writerName: c2.$1,
        writerHandle: c2.$2,
        level: 'N5',
        type: MonoContentType.sentence,
        title: '帰り道',
        coverSeed: 'mono-n5-5',
        lines: makeCoreDailyLines(place: '帰り道', level: 'N5', extraCount: 6),
      ),
      item(
        id: 'n5_6',
        writerName: c8.$1,
        writerHandle: c8.$2,
        level: 'N5',
        type: MonoContentType.diary,
        title: 'まどの外',
        coverSeed: 'mono-n5-6',
        lines: makeThemeLines(themeKey: 'cafe', level: 'N5', extraCount: 7),
      ),
      item(
        id: 'n5_7',
        writerName: c9.$1,
        writerHandle: c9.$2,
        level: 'N5',
        type: MonoContentType.sentence,
        title: 'しずかな道',
        coverSeed: 'mono-n5-7',
        lines: makeThemeLines(themeKey: 'station', level: 'N5', extraCount: 6),
      ),
      item(
        id: 'n5_8',
        writerName: c11.$1,
        writerHandle: c11.$2,
        level: 'N5',
        type: MonoContentType.diary,
        title: 'コーヒー',
        coverSeed: 'mono-n5-8',
        lines: makeThemeLines(themeKey: 'cafe', level: 'N5', extraCount: 8),
      ),
      item(
        id: 'n5_9',
        writerName: c3.$1,
        writerHandle: c3.$2,
        level: 'N5',
        type: MonoContentType.article,
        title: '本をかりる',
        coverSeed: 'mono-n5-9',
        lines: makeThemeLines(themeKey: 'library', level: 'N5', extraCount: 8),
      ),
      item(
        id: 'n5_10',
        writerName: c14.$1,
        writerHandle: c14.$2,
        level: 'N5',
        type: MonoContentType.story,
        title: 'ホームの音',
        coverSeed: 'mono-n5-10',
        lines: makeThemeLines(themeKey: 'station', level: 'N5', extraCount: 9),
      ),

      // N4 (more descriptive + one long stress)
      item(
        id: 'n4_1',
        writerName: c3.$1,
        writerHandle: c3.$2,
        level: 'N4',
        type: MonoContentType.article,
        title: '町の図書館',
        coverSeed: 'mono-n4-1',
        lines: makeCoreDailyLines(place: '図書館', level: 'N4', extraCount: 10),
      ),
      item(
        id: 'n4_2',
        writerName: c5.$1,
        writerHandle: c5.$2,
        level: 'N4',
        type: MonoContentType.story,
        title: '夜行バスの窓',
        coverSeed: 'mono-n4-2',
        lines: makeCoreDailyLines(place: 'バス', level: 'N4', extraCount: 12),
      ),
      item(
        id: 'n4_3',
        writerName: c2.$1,
        writerHandle: c2.$2,
        level: 'N4',
        type: MonoContentType.diary,
        title: '静かな商店街',
        coverSeed: 'mono-n4-3',
        lines: makeCoreDailyLines(place: '商店街', level: 'N4', extraCount: 11),
      ),
      item(
        id: 'n4_4',
        writerName: c1.$1,
        writerHandle: c1.$2,
        level: 'N4',
        type: MonoContentType.letter,
        title: '窓辺のコーヒー',
        coverSeed: 'mono-n4-4',
        lines: makeCoreDailyLines(place: 'カフェ', level: 'N4', extraCount: 10),
      ),
      item(
        id: 'n4_long_1',
        writerName: c3.$1,
        writerHandle: c3.$2,
        level: 'N4',
        type: MonoContentType.article,
        title: '図書館の一日（長編）',
        coverSeed: 'mono-n4-long-1',
        lines: makeCoreDailyLines(place: '図書館', level: 'N4', extraCount: 36),
      ),
      item(
        id: 'n4_5',
        writerName: c11.$1,
        writerHandle: c11.$2,
        level: 'N4',
        type: MonoContentType.diary,
        title: '窓の雨',
        coverSeed: 'mono-n4-5',
        lines: makeThemeLines(themeKey: 'cafe', level: 'N4', extraCount: 14),
      ),
      item(
        id: 'n4_6',
        writerName: c14.$1,
        writerHandle: c14.$2,
        level: 'N4',
        type: MonoContentType.story,
        title: '朝のホームで',
        coverSeed: 'mono-n4-6',
        lines: makeThemeLines(themeKey: 'station', level: 'N4', extraCount: 15),
      ),
      item(
        id: 'n4_7',
        writerName: c10.$1,
        writerHandle: c10.$2,
        level: 'N4',
        type: MonoContentType.article,
        title: '放課後のノート',
        coverSeed: 'mono-n4-7',
        lines: makeThemeLines(themeKey: 'school', level: 'N4', extraCount: 16),
      ),
      item(
        id: 'n4_8',
        writerName: c4.$1,
        writerHandle: c4.$2,
        level: 'N4',
        type: MonoContentType.dialogue,
        title: '受付の練習',
        coverSeed: 'mono-n4-8',
        lines: makeThemeLines(themeKey: 'office', level: 'N4', extraCount: 14),
      ),
      item(
        id: 'n4_9',
        writerName: c5.$1,
        writerHandle: c5.$2,
        level: 'N4',
        type: MonoContentType.story,
        title: '旅館の夜',
        coverSeed: 'mono-n4-9',
        lines: makeThemeLines(themeKey: 'travel', level: 'N4', extraCount: 18),
      ),

      // N3 (richer + work/school)
      item(
        id: 'n3_1',
        writerName: c4.$1,
        writerHandle: c4.$2,
        level: 'N3',
        type: MonoContentType.dialogue,
        title: '初めての受付',
        coverSeed: 'mono-n3-1',
        lines: makeCoreDailyLines(place: '受付', level: 'N3', extraCount: 14),
      ),
      item(
        id: 'n3_2',
        writerName: c4.$1,
        writerHandle: c4.$2,
        level: 'N3',
        type: MonoContentType.article,
        title: '小さな会議室',
        coverSeed: 'mono-n3-2',
        lines: makeCoreDailyLines(place: '会議室', level: 'N3', extraCount: 18),
      ),
      item(
        id: 'n3_3',
        writerName: c5.$1,
        writerHandle: c5.$2,
        level: 'N3',
        type: MonoContentType.story,
        title: '旅館の廊下',
        coverSeed: 'mono-n3-3',
        lines: makeCoreDailyLines(place: '旅館', level: 'N3', extraCount: 17),
      ),
      item(
        id: 'n3_4',
        writerName: c2.$1,
        writerHandle: c2.$2,
        level: 'N3',
        type: MonoContentType.diary,
        title: '放課後の教室',
        coverSeed: 'mono-n3-4',
        lines: makeCoreDailyLines(place: '教室', level: 'N3', extraCount: 16),
      ),
      item(
        id: 'n3_5',
        writerName: c6.$1,
        writerHandle: c6.$2,
        level: 'N3',
        type: MonoContentType.article,
        title: '窓の外の音',
        coverSeed: 'mono-n3-5',
        lines: makeCoreDailyLines(place: '家', level: 'N3', extraCount: 20),
      ),
      item(
        id: 'n3_6',
        writerName: c12.$1,
        writerHandle: c12.$2,
        level: 'N3',
        type: MonoContentType.article,
        title: '天気と予定',
        coverSeed: 'mono-n3-6',
        lines: makeThemeLines(themeKey: 'station', level: 'N3', extraCount: 22),
      ),
      item(
        id: 'n3_7',
        writerName: c9.$1,
        writerHandle: c9.$2,
        level: 'N3',
        type: MonoContentType.story,
        title: '商店街の角',
        coverSeed: 'mono-n3-7',
        lines: makeThemeLines(themeKey: 'library', level: 'N3', extraCount: 24),
      ),
      item(
        id: 'n3_8',
        writerName: c10.$1,
        writerHandle: c10.$2,
        level: 'N3',
        type: MonoContentType.diary,
        title: '教室の余白',
        coverSeed: 'mono-n3-8',
        lines: makeThemeLines(themeKey: 'school', level: 'N3', extraCount: 26),
      ),
      item(
        id: 'n3_9',
        writerName: c11.$1,
        writerHandle: c11.$2,
        level: 'N3',
        type: MonoContentType.article,
        title: '朝刊とメモ',
        coverSeed: 'mono-n3-9',
        lines: makeThemeLines(themeKey: 'cafe', level: 'N3', extraCount: 28),
      ),
      item(
        id: 'n3_long_1',
        writerName: c6.$1,
        writerHandle: c6.$2,
        level: 'N3',
        type: MonoContentType.article,
        title: '駅から図書館まで（長編）',
        coverSeed: 'mono-n3-long-1',
        lines: makeThemeLines(themeKey: 'station', level: 'N3', extraCount: 64),
      ),

      // N2 (denser)
      item(
        id: 'n2_article_funin_1',
        writerName: '読解ノート',
        writerHandle: '@yomi_dokkai',
        level: 'N2',
        type: MonoContentType.article,
        title: '赴任して1カ月',
        coverSeed: 'mono-n2-funin-1',
        lines: [
          _jaRuby(
            '赴任して1カ月。いろいろな手続きが進まない。',
            [
              _rt('赴任', 'ふにん'),
              _rt('して'),
              _rt('1'),
              _rt('カ月', 'かげつ'),
              _rt('。'),
              _rt('いろいろな'),
              _rt('手続', 'てつづ'),
              _rt('き'),
              _rt('が'),
              _rt('進', 'すす'),
              _rt('まない。'),
            ],
          ),
          _jaRuby(
            '日本を出国する2週間前、ブラジルの警察から突然、無犯罪証明書を求められた。',
            [
              _rt('日本'),
              _rt('を'),
              _rt('出国', 'しゅっこく'),
              _rt('する'),
              _rt('2'),
              _rt('週間前', 'しゅうかんまえ'),
              _rt('、'),
              _rt('ブラジル'),
              _rt('の'),
              _rt('警察', 'けいさつ'),
              _rt('から'),
              _rt('突然', 'とつぜん'),
              _rt('、'),
              _rt('無犯罪証明書', 'むはんざいしょうめいしょ'),
              _rt('を'),
              _rt('求', 'もと'),
              _rt('められた。'),
            ],
          ),
          _jaRuby(
            'すでにビザ申請で提出したのに、「法律が変わり、追加で必要になった」と繰り返す。',
            [
              _rt('すでに'),
              _rt('ビザ'),
              _rt('申請', 'しんせい'),
              _rt('で'),
              _rt('提出', 'ていしゅつ'),
              _rt('した'),
              _rt('のに、'),
              _rt('「'),
              _rt('法律', 'ほうりつ'),
              _rt('が'),
              _rt('変', 'か'),
              _rt('わり、'),
              _rt('追加', 'ついか'),
              _rt('で'),
              _rt('必要', 'ひつよう'),
              _rt('に'),
              _rt('なった'),
              _rt('」'),
              _rt('と'),
              _rt('繰', 'く'),
              _rt('り返', 'かえ'),
              _rt('す。'),
            ],
          ),
          _jaRuby(
            '日本の警察や外務省は「証明書の再発行に2カ月かかる」と言う。困った。',
            [
              _rt('日本'),
              _rt('の'),
              _rt('警察', 'けいさつ'),
              _rt('や'),
              _rt('外務省', 'がいむしょう'),
              _rt('は'),
              _rt('「'),
              _rt('証明書', 'しょうめいしょ'),
              _rt('の'),
              _rt('再発行', 'さいはっこう'),
              _rt('に'),
              _rt('2'),
              _rt('カ月', 'かげつ'),
              _rt('かかる'),
              _rt('」'),
              _rt('と'),
              _rt('言', 'い'),
              _rt('う。'),
              _rt('困', 'こま'),
              _rt('った。'),
            ],
          ),
          _jaRuby(
            'ブラジルの領事館でも詳しいことはわからず、いったん提出した証明書を取り下げて、再提出することにした。',
            [
              _rt('ブラジル'),
              _rt('の'),
              _rt('領事館', 'りょうじかん'),
              _rt('でも'),
              _rt('詳', 'くわ'),
              _rt('しい'),
              _rt('こと'),
              _rt('は'),
              _rt('わからず、'),
              _rt('いったん'),
              _rt('提出', 'ていしゅつ'),
              _rt('した'),
              _rt('証明書', 'しょうめいしょ'),
              _rt('を'),
              _rt('取', 'と'),
              _rt('り下', 'さ'),
              _rt('げて、'),
              _rt('再提出', 'さいていしゅつ'),
              _rt('する'),
              _rt('こと'),
              _rt('に'),
              _rt('した。'),
            ],
          ),
          _jaRuby(
            'ところがサンパウロで警察に行くと「その書類は使えない」。代わりに別の書類を求められた。',
            [
              _rt('ところが'),
              _rt('サンパウロ'),
              _rt('で'),
              _rt('警察', 'けいさつ'),
              _rt('に'),
              _rt('行', 'い'),
              _rt('くと'),
              _rt('「'),
              _rt('その'),
              _rt('書類', 'しょるい'),
              _rt('は'),
              _rt('使', 'つか'),
              _rt('えない'),
              _rt('」'),
              _rt('。'),
              _rt('代', 'か'),
              _rt('わり'),
              _rt('に'),
              _rt('別', 'べつ'),
              _rt('の'),
              _rt('書類', 'しょるい'),
              _rt('を'),
              _rt('求', 'もと'),
              _rt('められた。'),
            ],
          ),
          _jaRuby(
            '支局の電話回線の名義変更を申請したが、6回線のうち変更できたのは半分だけだった。',
            [
              _rt('支局', 'しきょく'),
              _rt('の'),
              _rt('電話回線', 'でんわかいせん'),
              _rt('の'),
              _rt('名義変更', 'めいぎへんこう'),
              _rt('を'),
              _rt('申請', 'しんせい'),
              _rt('した'),
              _rt('が、'),
              _rt('6'),
              _rt('回線', 'かいせん'),
              _rt('の'),
              _rt('うち'),
              _rt('変更', 'へんこう'),
              _rt('できた'),
              _rt('のは'),
              _rt('半分', 'はんぶん'),
              _rt('だけ'),
              _rt('だった。'),
            ],
          ),
          _jaRuby(
            '残り半分は同じ書類を提出したのに、担当者が違ったため認められなかった。',
            [
              _rt('残', 'のこ'),
              _rt('り'),
              _rt('半分', 'はんぶん'),
              _rt('は'),
              _rt('同', 'おな'),
              _rt('じ'),
              _rt('書類', 'しょるい'),
              _rt('を'),
              _rt('提出', 'ていしゅつ'),
              _rt('した'),
              _rt('のに、'),
              _rt('担当者', 'たんとうしゃ'),
              _rt('が'),
              _rt('違', 'ちが'),
              _rt('った'),
              _rt('ため'),
              _rt('認', 'みと'),
              _rt('められなかった。'),
            ],
          ),
          _jaRuby(
            'こんなことが繰り返される。ブラジル人の解決策はこうだ。',
            [
              _rt('こんな'),
              _rt('こと'),
              _rt('が'),
              _rt('繰', 'く'),
              _rt('り返', 'かえ'),
              _rt('される。'),
              _rt('ブラジル人', 'ぶらじるじん'),
              _rt('の'),
              _rt('解決策', 'かいけつさく'),
              _rt('は'),
              _rt('こう'),
              _rt('だ。'),
            ],
          ),
          _jaRuby(
            '「まずは通う。だめなら通って顔と名前を覚えてもらい、アミーゴ（友人）になる」',
            [
              _rt('「'),
              _rt('まずは'),
              _rt('通', 'かよ'),
              _rt('う。'),
              _rt('だめなら'),
              _rt('通', 'かよ'),
              _rt('って'),
              _rt('顔', 'かお'),
              _rt('と'),
              _rt('名前', 'なまえ'),
              _rt('を'),
              _rt('覚', 'おぼ'),
              _rt('えてもらい、'),
              _rt('アミーゴ'),
              _rt('（'),
              _rt('友人', 'ゆうじん'),
              _rt('）'),
              _rt('に'),
              _rt('なる'),
              _rt('」'),
            ],
          ),
          _jaRuby(
            '銀行口座の開設手続きがやっと終わった。',
            [
              _rt('銀行口座', 'ぎんこうこうざ'),
              _rt('の'),
              _rt('開設手続', 'かいせつてつづ'),
              _rt('き'),
              _rt('が'),
              _rt('やっと'),
              _rt('終', 'お'),
              _rt('わった。'),
            ],
          ),
          _jaRuby(
            'この数週間、平日はほぼ毎日通った。担当者は名前も顔も覚えてくれた。',
            [
              _rt('この'),
              _rt('数週間', 'すうしゅうかん'),
              _rt('、'),
              _rt('平日', 'へいじつ'),
              _rt('は'),
              _rt('ほぼ'),
              _rt('毎日', 'まいにち'),
              _rt('通', 'かよ'),
              _rt('った。'),
              _rt('担当者', 'たんとうしゃ'),
              _rt('は'),
              _rt('名前', 'なまえ'),
              _rt('も'),
              _rt('顔', 'かお'),
              _rt('も'),
              _rt('覚', 'おぼ'),
              _rt('えてくれた。'),
            ],
          ),
          _jaRuby(
            'これだけ通えば、アミーゴにもなれる。',
            [
              _rt('これだけ'),
              _rt('通', 'かよ'),
              _rt('えば、'),
              _rt('アミーゴ'),
              _rt('に'),
              _rt('も'),
              _rt('なれる。'),
            ],
          ),
        ],
      ),
      item(
        id: 'n2_1',
        writerName: c6.$1,
        writerHandle: c6.$2,
        level: 'N2',
        type: MonoContentType.article,
        title: '資料の整理',
        coverSeed: 'mono-n2-1',
        lines: makeCoreDailyLines(place: 'オフィス', level: 'N2', extraCount: 22),
      ),
      item(
        id: 'n2_2',
        writerName: c6.$1,
        writerHandle: c6.$2,
        level: 'N2',
        type: MonoContentType.letter,
        title: '移住の手紙',
        coverSeed: 'mono-n2-2',
        lines: makeCoreDailyLines(place: '町', level: 'N2', extraCount: 24),
      ),
      item(
        id: 'n2_3',
        writerName: c4.$1,
        writerHandle: c4.$2,
        level: 'N2',
        type: MonoContentType.dialogue,
        title: '法務確認メモ',
        coverSeed: 'mono-n2-3',
        lines: makeCoreDailyLines(place: '会議', level: 'N2', extraCount: 26),
      ),
      item(
        id: 'n2_4',
        writerName: c5.$1,
        writerHandle: c5.$2,
        level: 'N2',
        type: MonoContentType.story,
        title: '夜行と朝刊',
        coverSeed: 'mono-n2-4',
        lines: makeCoreDailyLines(place: '旅', level: 'N2', extraCount: 28),
      ),
      item(
        id: 'n2_5',
        writerName: c7.$1,
        writerHandle: c7.$2,
        level: 'N2',
        type: MonoContentType.article,
        title: '余白のある文章',
        coverSeed: 'mono-n2-5',
        lines: makeCoreDailyLines(place: '机', level: 'N2', extraCount: 24),
      ),
      item(
        id: 'n2_6',
        writerName: c12.$1,
        writerHandle: c12.$2,
        level: 'N2',
        type: MonoContentType.article,
        title: '通勤と判断',
        coverSeed: 'mono-n2-6',
        lines: makeThemeLines(themeKey: 'office', level: 'N2', extraCount: 30),
      ),
      item(
        id: 'n2_7',
        writerName: c13.$1,
        writerHandle: c13.$2,
        level: 'N2',
        type: MonoContentType.letter,
        title: '言い回しの違い',
        coverSeed: 'mono-n2-7',
        lines: makeThemeLines(themeKey: 'library', level: 'N2', extraCount: 30),
      ),
      item(
        id: 'n2_8',
        writerName: c5.$1,
        writerHandle: c5.$2,
        level: 'N2',
        type: MonoContentType.story,
        title: '夜行の途中で',
        coverSeed: 'mono-n2-8',
        lines: makeThemeLines(themeKey: 'travel', level: 'N2', extraCount: 34),
      ),
      item(
        id: 'n2_9',
        writerName: c9.$1,
        writerHandle: c9.$2,
        level: 'N2',
        type: MonoContentType.article,
        title: '町の変化',
        coverSeed: 'mono-n2-9',
        lines: makeThemeLines(themeKey: 'station', level: 'N2', extraCount: 32),
      ),
      item(
        id: 'n2_long_1',
        writerName: c12.$1,
        writerHandle: c12.$2,
        level: 'N2',
        type: MonoContentType.article,
        title: '資料と合意（長編）',
        coverSeed: 'mono-n2-long-1',
        lines: makeThemeLines(themeKey: 'office', level: 'N2', extraCount: 72),
      ),

      // N1 (advanced + long stress)
      item(
        id: 'n1_1',
        writerName: c7.$1,
        writerHandle: c7.$2,
        level: 'N1',
        type: MonoContentType.article,
        title: '静けさの設計',
        coverSeed: 'mono-n1-1',
        lines: makeCoreDailyLines(place: '部屋', level: 'N1', extraCount: 30),
      ),
      item(
        id: 'n1_2',
        writerName: c7.$1,
        writerHandle: c7.$2,
        level: 'N1',
        type: MonoContentType.letter,
        title: '言葉の輪郭',
        coverSeed: 'mono-n1-2',
        lines: makeCoreDailyLines(place: '夜', level: 'N1', extraCount: 32),
      ),
      item(
        id: 'n1_3',
        writerName: c6.$1,
        writerHandle: c6.$2,
        level: 'N1',
        type: MonoContentType.article,
        title: '合意形成の現場',
        coverSeed: 'mono-n1-3',
        lines: makeCoreDailyLines(place: '現場', level: 'N1', extraCount: 34),
      ),
      item(
        id: 'n1_4',
        writerName: c6.$1,
        writerHandle: c6.$2,
        level: 'N1',
        type: MonoContentType.article,
        title: '手順と判断',
        coverSeed: 'mono-n1-4',
        lines: makeCoreDailyLines(place: '資料', level: 'N1', extraCount: 28),
      ),
      item(
        id: 'n1_long_1',
        writerName: c7.$1,
        writerHandle: c7.$2,
        level: 'N1',
        type: MonoContentType.story,
        title: '長い帰り道（ページ耐久）',
        coverSeed: 'mono-n1-long-1',
        lines: makeCoreDailyLines(place: '帰り道', level: 'N1', extraCount: 52),
      ),
      item(
        id: 'n1_5',
        writerName: c13.$1,
        writerHandle: c13.$2,
        level: 'N1',
        type: MonoContentType.article,
        title: '言葉の選択',
        coverSeed: 'mono-n1-5',
        lines: makeThemeLines(themeKey: 'office', level: 'N1', extraCount: 40),
      ),
      item(
        id: 'n1_6',
        writerName: c7.$1,
        writerHandle: c7.$2,
        level: 'N1',
        type: MonoContentType.article,
        title: '沈黙の意味',
        coverSeed: 'mono-n1-6',
        lines: makeThemeLines(themeKey: 'cafe', level: 'N1', extraCount: 42),
      ),
      item(
        id: 'n1_7',
        writerName: c12.$1,
        writerHandle: c12.$2,
        level: 'N1',
        type: MonoContentType.article,
        title: '短評：社会の速度',
        coverSeed: 'mono-n1-7',
        lines: makeThemeLines(themeKey: 'station', level: 'N1', extraCount: 44),
      ),
      item(
        id: 'n1_8',
        writerName: c6.$1,
        writerHandle: c6.$2,
        level: 'N1',
        type: MonoContentType.article,
        title: '読解の視点',
        coverSeed: 'mono-n1-8',
        lines: makeThemeLines(themeKey: 'library', level: 'N1', extraCount: 46),
      ),
      item(
        id: 'n1_9',
        writerName: c5.$1,
        writerHandle: c5.$2,
        level: 'N1',
        type: MonoContentType.story,
        title: '夜の輪郭',
        coverSeed: 'mono-n1-9',
        lines: makeThemeLines(themeKey: 'travel', level: 'N1', extraCount: 48),
      ),
    ];

    return items;
  }

  static List<MonoFeedItem> _buildV1FollowingMockItems(List<MonoFeedItem> all) {
    const followedHandles = <String>{
      '@eki_weather',
      '@toshokan_log',
      '@yako_travel',
      '@office_keigo',
      '@cafe_reads',
      '@morning_habit',
      '@classroom_n3',
      '@news_n2',
    };
    final out =
        all.where((i) => followedHandles.contains(i.writerHandle)).toList();
    // Keep Following feeling varied and non-trivial.
    return out.length <= 32 ? out : out.take(32).toList(growable: false);
  }

  /// Legacy temporary Following-only feed (retired).
  // ignore: unused_field
  static const _legacyFollowingMockItems = <MonoFeedItem>[
    MonoFeedItem(
      id: 'mf1',
      writerName: 'Rina / 旅と言葉',
      writerHandle: '@rina_travel',
      level: 'N4',
      contentType: MonoContentType.article,
      title: '朝のホームで',
      coverImageUrl: 'https://picsum.photos/seed/mf1/800/1000',
      content: MonoContent(
        id: 'mf1',
        title: '朝のホームで',
        pages: [
          MonoContentPage(
            pageId: 'p1',
            lines: [
              MonoSentenceLine(
                tokens: [
                  MonoRubyToken(text: '改札'),
                  MonoRubyToken(text: 'を'),
                  MonoRubyToken(text: '出', reading: 'で'),
                  MonoRubyToken(text: 'ると、'),
                  MonoRubyToken(text: '朝', reading: 'あさ'),
                  MonoRubyToken(text: 'の'),
                  MonoRubyToken(text: 'ホーム'),
                  MonoRubyToken(text: 'が'),
                  MonoRubyToken(text: '静', reading: 'しず'),
                  MonoRubyToken(text: 'かだった。'),
                ],
                plainText: '改札を出ると、朝のホームが静かだった。',
                explanation: const MonoExplanationLine(
                  en: 'When I passed the ticket gate, the platform was quiet in the morning.',
                  my: 'တံခါးပေါက်ကို ဖြတ်ထွက်လိုက်တော့ မနက်ခင်း ပလက်ဖောင်းက တိတ်ဆိတ်နေတယ်။',
                ),
              ),
              MonoSentenceLine(
                tokens: [
                  MonoRubyToken(text: '電光掲示板'),
                  MonoRubyToken(text: 'だけが'),
                  MonoRubyToken(text: '時刻'),
                  MonoRubyToken(text: 'を'),
                  MonoRubyToken(text: '更新', reading: 'こうしん'),
                  MonoRubyToken(text: 'している。'),
                ],
                plainText: '電光掲示板だけが時刻を更新している。',
                explanation: const MonoExplanationLine(
                  en: 'Only the electronic sign kept updating the time.',
                ),
              ),
              MonoSentenceLine(
                tokens: [
                  MonoRubyToken(text: 'コーヒー'),
                  MonoRubyToken(text: 'の'),
                  MonoRubyToken(text: '紙', reading: 'かみ'),
                  MonoRubyToken(text: 'コップ'),
                  MonoRubyToken(text: 'を'),
                  MonoRubyToken(text: '両手'),
                  MonoRubyToken(text: 'で'),
                  MonoRubyToken(text: '包', reading: 'つつ'),
                  MonoRubyToken(text: 'む。'),
                ],
                plainText: 'コーヒーの紙コップを両手で包む。',
                explanation: const MonoExplanationLine(
                  en: 'I held the paper cup with both hands.',
                  my: 'ကော်ဖီ စက္ကူခွက်ကို လက်နှစ်ဖက်နဲ့ ကိုင်ထားတယ်။',
                ),
              ),
              MonoSentenceLine(
                tokens: const [],
                plainText: '急ぐことはないのに、心だけ少し早足になる。',
                explanation: const MonoExplanationLine(
                  en: 'Even though I’m not in a hurry, my mind feels rushed.',
                ),
              ),
            ],
          ),
        ],
      ),
      bodyText:
          '改札を出ると、ホームの端に小さなベンチがあった。まだ人は少なく、電光掲示板だけが静かに時刻を更新している。コーヒーの紙コップを両手で包みながら、今日の予定を頭の中で並べ替える。特に急ぐことはないが、心は少し早足になっている。',
    ),
    MonoFeedItem(
      id: 'mf2',
      writerName: 'Studio Kumo',
      writerHandle: '@kumo_mono',
      level: 'N3',
      contentType: MonoContentType.story,
      title: '傘の置き場所',
      coverImageUrl: 'https://picsum.photos/seed/mf2/800/1000',
      bodyText:
          '玄関の傘立ては、家族四人分でいつもぎゅうぎゅうだ。朝は誰が先に出るかで順番が変わり、小さな争いが起きる。ある日、一番下の妹が自分用のフックを貼ってくれた。「ここは私」と書いてある。笑ってしまった。',
    ),
    MonoFeedItem(
      id: 'mf3',
      writerName: 'Hikari Reads',
      writerHandle: '@hikari_reads',
      level: 'N5',
      contentType: MonoContentType.dialogue,
      title: 'コンビニで',
      bodyText:
          '店員：温めますか。\n客：お願いします。\n店員：袋は分けますか。\n客：はい、お願いします。\n\nレジの横に並んだおにぎりの棚を見ながら、今日の晩ごはんを考える。買いすぎないように、と心では決めている。',
    ),
    MonoFeedItem(
      id: 'mf4',
      writerName: 'Mono Friends',
      writerHandle: '@mono_friends',
      level: 'N2',
      contentType: MonoContentType.article,
      title: '読書のメモ',
      coverImageUrl: 'https://picsum.photos/seed/mf4/800/1000',
      bodyText:
          '読み終えた本の端に付箋を貼る癖がある。付箋の色は気分で変えるが、意味のルールは決めていない。後から見返したとき、なぜ黄色だったのか思い出せないことも多い。それでも、ページを開くたびに当時の自分に会いに行ける気がする。',
    ),
  ];

  String _selectedLevel = 'All';
  _MonoMainFeedKind _mainFeedKind = _MonoMainFeedKind.forYou;

  PageController? _readerFeedController;
  PageController? _feedTabController;
  PageController? _verticalForYou;
  PageController? _verticalFollowing;
  int _feedIndex = 0;

  /// Full detail rows loaded via `GET /v1/mono/:id` for catalog items.
  final Map<String, MonoFeedItem> _hydratedRemoteItems =
      <String, MonoFeedItem>{};
  final Set<String> _detailInflight = <String>{};

  ProviderSubscription<int>? _profileCatalogSurfacesRefreshSub;

  /// Last [PageView] page index (0=Following, 1=For You) we ran settle-side-effects for.
  int _lastSettledHorizontalFeedPage = 1;
  final Map<String, ValueNotifier<bool>> _bookmarkNotifiers = {};
  final Map<String, ValueNotifier<bool>> _reactNotifiers = {};
  final Map<String, ValueNotifier<int>> _likesCountNotifiers = {};
  final Set<String> _socialTouchedIds = <String>{};

  /// At most one custom collection per saved Mono item; absent entry = default Saved only.
  final Map<String, String> _monoSingleCollectionByItemId = {};

  final List<_MonoSaveFolder> _monoSaveFolders = <_MonoSaveFolder>[
    _MonoSaveFolder(id: 'mono_favorites', name: 'Favorites'),
    _MonoSaveFolder(id: 'mono_read_later', name: 'Read later'),
    _MonoSaveFolder(id: 'mono_grammar', name: 'Grammar picks'),
  ];

  ValueNotifier<bool> _bookmarkNotifierFor(String id, {required bool initial}) {
    final n = _bookmarkNotifiers.putIfAbsent(id, () => ValueNotifier(initial));
    if (!_socialTouchedIds.contains(id)) {
      n.value = initial;
    }
    return n;
  }

  ValueNotifier<bool> _reactNotifierFor(String id, {required bool initial}) {
    final n = _reactNotifiers.putIfAbsent(id, () => ValueNotifier(initial));
    if (!_socialTouchedIds.contains(id)) {
      n.value = initial;
    }
    return n;
  }

  ValueNotifier<int> _likesCountNotifierFor(String id, {required int initial}) {
    final n =
        _likesCountNotifiers.putIfAbsent(id, () => ValueNotifier(initial));
    if (!_socialTouchedIds.contains(id)) {
      n.value = initial;
    }
    return n;
  }

  bool get _useRemoteForYouFeed =>
      RemoteBackendConfig.useRemoteMonoFeed &&
      widget.showTopControls &&
      widget.initialItemsOverride == null &&
      widget.initialItemOverride == null;

  bool get _useRemoteFollowingFeed =>
      RemoteBackendConfig.useRemoteMonoFeed &&
      widget.showTopControls &&
      widget.initialItemsOverride == null &&
      widget.initialItemOverride == null &&
      _isAuthed;

  bool get _isAuthed {
    final s = ref.read(authSessionProvider);
    return s is AuthSessionAuthenticated;
  }

  String? get _currentUserId {
    final s = ref.read(authSessionProvider);
    return s is AuthSessionAuthenticated ? s.user.id : null;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleBookmark(MonoFeedItem item) async {
    if (!canBookmarkMono(
      currentUserId: _currentUserId,
      monoOwnerId: item.writerId,
    )) {
      return;
    }
    if (!await ensureProtectedActionAllowed(
      context,
      action: ProtectedActionType.save,
    )) {
      return;
    }
    final id = item.id;
    _socialTouchedIds.add(id);
    final n = _bookmarkNotifierFor(id, initial: item.isBookmarkedByMe);
    final before = n.value;
    final next = !before;
    n.value = next;

    try {
      final repo = ref.read(remoteMonoSocialRepositoryProvider);
      final out = next
          ? await repo.bookmarkMono(item.monoIdForLearnRoutes)
          : await repo.unbookmarkMono(item.monoIdForLearnRoutes);
      n.value = out;
      bumpProfileSavedListRefresh(
        ProviderScope.containerOf(context, listen: false),
      );
      if (!mounted) return;
      _snack(
        out
            ? SavedLibraryCopy.monoSavedSnack
            : SavedLibraryCopy.monoRemovedSnack,
      );
    } on AppQuotaExceededException catch (e) {
      n.value = before;
      if (mounted) {
        await showQuotaExceededDialog(context, e);
      }
    } catch (e) {
      n.value = before;
      final offlineMsg = offlineUserMessageIfRecognized(e);
      _snack(
        offlineMsg ??
            (e is StateError ? e.message : SavedLibraryCopy.monoSaveError),
      );
    }
  }

  Future<void> _toggleReact(MonoFeedItem item) async {
    if (!await ensureProtectedActionAllowed(
      context,
      action: ProtectedActionType.react,
    )) {
      return;
    }
    final id = item.id;
    _socialTouchedIds.add(id);
    final reactedInitial = (item.myReaction ?? '').trim().isNotEmpty;
    final reactN = _reactNotifierFor(id, initial: reactedInitial);
    final likesN = _likesCountNotifierFor(id, initial: item.likesCount);

    final beforeReact = reactN.value;
    final beforeLikes = likesN.value;
    final nextReact = !beforeReact;
    reactN.value = nextReact;
    likesN.value = math.max(0, beforeLikes + (nextReact ? 1 : -1));

    try {
      final repo = ref.read(remoteMonoSocialRepositoryProvider);
      final likesOut = nextReact
          ? await repo.reactMono(item.monoIdForLearnRoutes)
          : await repo.unreactMono(item.monoIdForLearnRoutes);
      likesN.value = likesOut;
    } catch (e) {
      reactN.value = beforeReact;
      likesN.value = beforeLikes;
      final offlineMsg = offlineUserMessageIfRecognized(e);
      _snack(
        offlineMsg ??
            (e is StateError ? e.message : 'Could not update reaction.'),
      );
    }
  }

  String? _pagerLevelFromUi(String selectedLevel) =>
      selectedLevel == 'All' ? null : selectedLevel;

  List<MonoFeedItem> _remoteCatalogItemsResolved() {
    final pager = ref.read(monoFeedPagerProvider);
    return pager.items
        .map(
          (dto) =>
              _hydratedRemoteItems[dto.monoId] ??
              monoFeedItemFromMonoFeedSummary(dto),
        )
        .toList();
  }

  List<MonoFeedItem> _remoteFollowingItemsResolved() {
    final pager = ref.read(followingMonoFeedPagerProvider);
    return pager.items
        .map(
          (dto) =>
              _hydratedRemoteItems[dto.monoId] ??
              monoFeedItemFromMonoFeedSummary(dto),
        )
        .toList();
  }

  bool get _hydrateCatalogMonoDetailsInReaderDock =>
      _useRemoteForYouFeed ||
      _useRemoteFollowingFeed ||
      (!widget.showTopControls && widget.initialItemsOverride != null);

  Future<void> _ensureDetailLoaded(MonoFeedItem item) async {
    if (!_hydrateCatalogMonoDetailsInReaderDock) return;
    if (!item.needsRemoteDetailHydration) return;
    if (_hydratedRemoteItems.containsKey(item.id)) return;
    if (_detailInflight.contains(item.id)) return;
    _detailInflight.add(item.id);
    try {
      final catalogId = item.monoIdForLearnRoutes;
      final dto =
          await ref.read(remoteMonoFeedRepositoryProvider).fetchMonoDetail(
                catalogId,
              );
      if (!mounted) return;
      final merged = monoFeedItemMergePublishedDetail(item, dto);
      setState(() {
        _hydratedRemoteItems[item.id] = merged;
        _detailInflight.remove(item.id);
      });
    } catch (e) {
      _detailInflight.remove(item.id);
      if (!mounted) return;
      final msg = e is PublishedMonoHiddenWhileEditingException
          ? e.message
          : 'Could not load story: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _clearRemoteHydration() {
    _hydratedRemoteItems.clear();
    _detailInflight.clear();
  }

  Widget _remoteFeedErrorPanel(ThemeData theme, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Could not load the feed.',
              style: theme.textTheme.titleMedium?.copyWith(
                color: _nimonColors(theme).textPrimary,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              style: theme.textTheme.bodySmall?.copyWith(
                color: _nimonColors(theme).textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                unawaited(
                  ref.read(monoFeedPagerProvider.notifier).loadFirstPage(),
                );
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _remoteFeedEmptyPanel(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _selectedLevel == 'All'
              ? 'No published stories yet.'
              : '$_selectedLevel の投稿はありません',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: _nimonColors(theme).textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void _precacheCoversNear(
    BuildContext context,
    List<MonoFeedItem> items,
    int centerIndex,
  ) {
    if (!context.mounted) return;
    for (final j in [centerIndex - 1, centerIndex, centerIndex + 1]) {
      if (j < 0 || j >= items.length) continue;
      final it = items[j];
      final url = it.coverImageUrl?.trim();
      if (url != null && url.isNotEmpty) {
        precacheImage(NetworkImage(url), context);
      }
      final asset = _monoCoverFallbackAsset(_monoEffectiveCoverCategory(it));
      precacheImage(AssetImage(asset), context);
    }
  }

  @override
  void initState() {
    super.initState();
    _profileCatalogSurfacesRefreshSub = ref.listenManual<int>(
      profileProcessingListRefreshProvider,
      (previous, next) {
        if (!mounted) return;
        if (!_useRemoteForYouFeed) return;
        _clearRemoteHydration();
        unawaited(ref.read(monoFeedPagerProvider.notifier).refresh());
      },
    );
    final initialPage =
        widget.initialItemsOverride != null ? widget.initialIndexOverride : 0;
    _feedIndex = math.max(0, initialPage);
    if (widget.showTopControls) {
      _feedTabController = PageController(initialPage: 1);
      _verticalForYou = PageController();
      _verticalFollowing = PageController();
      if (monoDemoBookmarkFoldersEnabled) {
        // Debug mock only: seed Saved + fake single-folder map (no backend).
        for (final id in _seedSavedIds) {
          _bookmarkNotifierFor(id, initial: true).value = true;
        }
        _monoSingleCollectionByItemId.addAll(_seedFolderByItemId);
      }
      if (_useRemoteForYouFeed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(monoFeedPagerProvider.notifier).setFilters(
                level: _pagerLevelFromUi(_selectedLevel),
              );
          unawaited(ref.read(monoFeedPagerProvider.notifier).loadFirstPage());
        });
      }
      if (_useRemoteFollowingFeed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(
            ref.read(followingMonoFeedPagerProvider.notifier).loadFirstPage(),
          );
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_useRemoteForYouFeed) {
          _precacheCoversNear(context, _forYouFilteredItems, 0);
        }
        final followingItems = _useRemoteFollowingFeed
            ? _remoteFollowingItemsResolved()
            : _followingMockItems;
        _precacheCoversNear(context, followingItems, 0);
      });
    } else {
      _readerFeedController =
          PageController(initialPage: math.max(0, initialPage));
      if (monoDemoBookmarkFoldersEnabled) {
        for (final id in _seedSavedIds) {
          _bookmarkNotifierFor(id, initial: true).value = true;
        }
        _monoSingleCollectionByItemId.addAll(_seedFolderByItemId);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final items = widget.initialItemsOverride ??
            (widget.initialItemOverride != null
                ? <MonoFeedItem>[widget.initialItemOverride!]
                : _forYouFilteredItems);
        _precacheCoversNear(context, items, math.max(0, initialPage));
      });
    }
  }

  @override
  void dispose() {
    _profileCatalogSurfacesRefreshSub?.close();
    _profileCatalogSurfacesRefreshSub = null;
    if (!widget.showTopControls) {
      hideMonoStoryOptionsPanel();
    }
    _feedTabController?.dispose();
    _verticalForYou?.dispose();
    _verticalFollowing?.dispose();
    _readerFeedController?.dispose();
    for (final n in _bookmarkNotifiers.values) {
      n.dispose();
    }
    for (final n in _reactNotifiers.values) {
      n.dispose();
    }
    for (final n in _likesCountNotifiers.values) {
      n.dispose();
    }
    super.dispose();
  }

  List<MonoFeedItem> get _forYouFilteredItems {
    if (_useRemoteForYouFeed) {
      return _remoteCatalogItemsResolved();
    }
    if (_selectedLevel == 'All') return _mockItems;
    return _mockItems.where((i) => i.level == _selectedLevel).toList();
  }

  /// Following feed is not JLPT-filtered (level applies to For You only).
  List<MonoFeedItem> get _followingFilteredItems {
    if (_useRemoteFollowingFeed) {
      return _remoteFollowingItemsResolved();
    }
    return List<MonoFeedItem>.unmodifiable(_followingMockItems);
  }

  List<MonoFeedItem> _itemsForMainKind(_MonoMainFeedKind kind) =>
      kind == _MonoMainFeedKind.forYou
          ? _forYouFilteredItems
          : _followingFilteredItems;

  void _jumpActiveVerticalFeedToStart() {
    if (widget.showTopControls) {
      final c = _mainFeedKind == _MonoMainFeedKind.forYou
          ? _verticalForYou
          : _verticalFollowing;
      if (c != null && c.hasClients) {
        c.jumpToPage(0);
      }
      return;
    }
    final r = _readerFeedController;
    if (r != null && r.hasClients) {
      r.jumpToPage(0);
    }
  }

  void _onHorizontalFeedPageChanged(int page) {
    if (_lastSettledHorizontalFeedPage == page) return;
    _lastSettledHorizontalFeedPage = page;
    final kind =
        page == 0 ? _MonoMainFeedKind.following : _MonoMainFeedKind.forYou;
    setState(() {
      _mainFeedKind = kind;
      _feedIndex = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _jumpActiveVerticalFeedToStart();
      final list = _itemsForMainKind(kind);
      if (list.isNotEmpty) {
        _precacheCoversNear(context, list, 0);
      }
    });
  }

  Widget _monoEmptyVerticalPage(ThemeData theme, _MonoMainFeedKind kind) {
    if (kind == _MonoMainFeedKind.following) {
      return const _FollowingFeedEmptyState();
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '$_selectedLevel の投稿はありません',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: _nimonColors(theme).textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildMainMonoVerticalFeed(
    ThemeData theme,
    _MonoMainFeedKind segmentKind,
    bool showExplanationLines,
  ) {
    if (segmentKind == _MonoMainFeedKind.forYou && _useRemoteForYouFeed) {
      final ps = ref.watch(monoFeedPagerProvider);
      if (ps.isInitialLoading && ps.items.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (ps.error != null && ps.items.isEmpty && !ps.isInitialLoading) {
        return _remoteFeedErrorPanel(theme, ps.error!);
      }
      if (!ps.isInitialLoading && ps.items.isEmpty && ps.error == null) {
        return _remoteFeedEmptyPanel(theme);
      }
    }
    if (segmentKind == _MonoMainFeedKind.following &&
        RemoteBackendConfig.useRemoteMonoFeed) {
      if (!_isAuthed) {
        return const MonoFollowingGuestAuthPanel();
      }
      final ps = ref.watch(followingMonoFeedPagerProvider);
      if (ps.isInitialLoading && ps.items.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (ps.error != null && ps.items.isEmpty && !ps.isInitialLoading) {
        return _remoteFollowingFeedErrorPanel(theme, ps.error!);
      }
      if (!ps.isInitialLoading && ps.items.isEmpty && ps.error == null) {
        return const _FollowingFeedEmptyState();
      }
    }
    final data = _itemsForMainKind(segmentKind);
    final controller = segmentKind == _MonoMainFeedKind.forYou
        ? _verticalForYou!
        : _verticalFollowing!;
    if (data.isEmpty) {
      return _monoEmptyVerticalPage(theme, segmentKind);
    }
    return PageView.builder(
      controller: controller,
      scrollDirection: Axis.vertical,
      // Stable identity: do not key on feed length — length churn resets the whole
      // pager subtree (web-sensitive). Segment + JLPT filter already define the feed.
      key: ValueKey<String>(
        'v_${segmentKind.name}_'
        '${segmentKind == _MonoMainFeedKind.forYou ? _selectedLevel : 'all'}'
        '${_useRemoteForYouFeed ? '_remote' : ''}',
      ),
      onPageChanged: (i) {
        if (_mainFeedKind != segmentKind) return;
        setState(() => _feedIndex = i);
        _precacheCoversNear(context, data, i);
        if (segmentKind == _MonoMainFeedKind.forYou && _useRemoteForYouFeed) {
          ref.read(monoFeedPagerProvider.notifier).maybePrefetch(i);
          if (i >= 0 && i < data.length) {
            unawaited(_ensureDetailLoaded(data[i]));
          }
        }
        if (segmentKind == _MonoMainFeedKind.following &&
            _useRemoteFollowingFeed) {
          ref.read(followingMonoFeedPagerProvider.notifier).maybePrefetch(i);
          if (i >= 0 && i < data.length) {
            unawaited(_ensureDetailLoaded(data[i]));
          }
        }
      },
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
        final bookmarkN = _bookmarkNotifierFor(
          item.id,
          initial: item.isBookmarkedByMe,
        );
        final reactedInitial = (item.myReaction ?? '').trim().isNotEmpty;
        final reactN = _reactNotifierFor(item.id, initial: reactedInitial);
        final likesN =
            _likesCountNotifierFor(item.id, initial: item.likesCount);
        return _ReadingFeedPost(
          item: item,
          bookmarkNotifier: bookmarkN,
          reactNotifier: reactN,
          likesCountNotifier: likesN,
          onLearn: () => _openLearn(item),
          onToggleBookmark: () => unawaited(_toggleBookmark(item)),
          onToggleReact: () => unawaited(_toggleReact(item)),
          onShare: () => _share(item),
          readingBg: _nimonColors(theme).appBackground,
          readingInk: _nimonColors(theme).textPrimary,
          readingInkMuted: _nimonColors(theme).textSecondary,
          showExplanationLines: showExplanationLines,
          currentUserId: _currentUserId,
        );
      },
    );
  }

  List<MonoFeedItem> get _resolvedFeedItems {
    if (widget.initialItemsOverride != null) {
      return widget.initialItemsOverride!
          .map((it) => _hydratedRemoteItems[it.id] ?? it)
          .toList(growable: false);
    }
    if (widget.initialItemOverride != null) {
      return <MonoFeedItem>[widget.initialItemOverride!];
    }
    if (!widget.showTopControls) {
      return _forYouFilteredItems;
    }
    return _mainFeedKind == _MonoMainFeedKind.forYou
        ? _forYouFilteredItems
        : _followingFilteredItems;
  }

  Widget _monoEmptyFeed(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '$_selectedLevel の投稿はありません',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: _nimonColors(theme).textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void _setMainFeedKind(_MonoMainFeedKind next) {
    if (_mainFeedKind == next) return;
    setState(() {
      _mainFeedKind = next;
      _feedIndex = 0;
    });
    if (widget.showTopControls && _feedTabController != null) {
      final target = next == _MonoMainFeedKind.following ? 0 : 1;
      _feedTabController!.animateToPage(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _jumpActiveVerticalFeedToStart();
      final list = _itemsForMainKind(_mainFeedKind);
      if (list.isNotEmpty) {
        _precacheCoversNear(context, list, 0);
      }
    });
  }

  void _openLearn(MonoFeedItem item) {
    final p = item.publishedAccess;
    if (p != null) {
      if (p.isFullLearnPublished) {
        if (!p.learnModulesInPayload) {
          unawaited(
            showModalBottomSheet<void>(
              context: context,
              useRootNavigator: true,
              showDragHandle: true,
              builder: (ctx) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Full learn',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Full learn is published, but the server has not yet stored learn module data on this mono. The app will not show placeholder vocabulary, grammar, quiz, or listening until the backend provides it.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
          return;
        }
        // V1: when [learn] exists, fall through to the generic Learn route below.
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              p.isReadOnlyPublished
                  ? 'Learn is not included in a Read only publish. Publish full learn to add learn content.'
                  : 'Learn is not available for this published item until it is a full learn publish with server-side learn data.',
            ),
          ),
        );
        return;
      }
    }
    final url = item.coverImageUrl?.trim();
    final effectiveCategory = _monoEffectiveCoverCategory(item);
    final fallbackAsset = _monoCoverFallbackAsset(effectiveCategory);
    final categoryLabel = switch (effectiveCategory) {
      MonoCoverCategory.love => 'Love',
      MonoCoverCategory.horror => 'Horror',
      MonoCoverCategory.culture => 'Culture',
      MonoCoverCategory.comedy => 'Comedy',
      MonoCoverCategory.art => 'Art',
      MonoCoverCategory.history => 'History',
    };
    final title = (item.title ?? '').trim();
    final storyTitle = title.isNotEmpty ? title : 'Mono Story';
    final unlock =
        (item.level == 'N1' || item.level == 'N2') ? 'Premium' : 'Free';
    final basics = item.storyDescription.trim();
    final fallback = item.effectiveBodyText.trim();
    final description = basics.isNotEmpty
        ? basics
        : (fallback.isEmpty
            ? ''
            : fallback.split(RegExp(r'\n\s*\n')).first.trim());
    context.push(
      '/learn/${item.monoIdForLearnRoutes}',
      extra: <String, String?>{
        'coverImageUrl': url,
        'coverFallbackAsset': fallbackAsset,
        'storyTitle': storyTitle,
        'level': item.level,
        'category': categoryLabel,
        'unlock': unlock,
        'description': description,
      },
    );
  }

  Future<void> _share(MonoFeedItem item) async {
    await shareMonoLink(context, item);
  }

  String? _monoAssignedCollectionId(String itemId) =>
      _monoSingleCollectionByItemId[itemId];

  String? _monoCollectionDisplayName(String? folderId) {
    if (folderId == null) return null;
    for (final f in _monoSaveFolders) {
      if (f.id == folderId) return f.name;
    }
    return null;
  }

  Future<String?> _showNewMonoFolderNameDialog(BuildContext dialogContext) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: dialogContext,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('New collection'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Weekend reads',
            ),
            onSubmitted: (s) {
              final t = s.trim();
              if (t.isEmpty) return;
              Navigator.pop(ctx, t);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final t = ctrl.text.trim();
                if (t.isEmpty) return;
                Navigator.pop(ctx, t);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    ).whenComplete(ctrl.dispose);
  }

  /// Save sheet: default Saved card, collections with per-folder add, create via header action.
  // ignore: unused_element
  Future<void> _openBookmarkCollectionSheet(MonoFeedItem item) async {
    if (!monoDemoBookmarkFoldersEnabled) return;
    final theme = Theme.of(context);
    final monoContext = context;
    final bookmarkN =
        _bookmarkNotifierFor(item.id, initial: item.isBookmarkedByMe);
    final sheetMaxListHeight = MediaQuery.sizeOf(context).height * 0.42;
    final wasSavedOnOpen = bookmarkN.value;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final padBottom = MediaQuery.viewPaddingOf(sheetContext).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: padBottom),
          child: ValueListenableBuilder<bool>(
            valueListenable: bookmarkN,
            builder: (context, isSaved, _) {
              return StatefulBuilder(
                builder: (context, modalSetState) {
                  void bump() {
                    modalSetState(() {});
                    if (mounted) setState(() {});
                  }

                  final assignedId = _monoAssignedCollectionId(item.id);
                  final inFolder = (String folderId) => assignedId == folderId;

                  Future<void> onCreateCollection() async {
                    final name =
                        await _showNewMonoFolderNameDialog(sheetContext);
                    if (!mounted || name == null || name.trim().isEmpty) {
                      return;
                    }
                    final id =
                        'mono_f_${DateTime.now().microsecondsSinceEpoch}';
                    _monoSaveFolders.add(
                      _MonoSaveFolder(id: id, name: name.trim()),
                    );
                    bookmarkN.value = true;
                    _monoSingleCollectionByItemId[item.id] = id;
                    bump();
                    if (!sheetContext.mounted) return;
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Created “${name.trim()}” — saved there',
                        ),
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(16),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }

                  void onSavedCardTap() {
                    bookmarkN.value = true;
                    _monoSingleCollectionByItemId.remove(item.id);
                    bump();
                    Navigator.of(sheetContext).pop();
                    if (!mounted) return;
                    monoContext.go('/more?tab=saved');
                  }

                  final defaultSavedActive = isSaved && assignedId == null;
                  final collName = _monoCollectionDisplayName(assignedId);
                  final savedCardSubtitle = !isSaved
                      ? 'Tap for default Saved (Profile)'
                      : (defaultSavedActive
                          ? 'Default Saved · active'
                          : 'In “${collName ?? 'collection'}” · tap for default Saved');

                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                          child: Text(
                            'Save & organize',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: _nimonColors(theme).textPrimary,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          child: Material(
                            color: defaultSavedActive
                                ? theme.colorScheme.primary
                                    .withValues(alpha: 0.12)
                                : theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(12),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: onSavedCardTap,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSaved
                                          ? Icons.bookmark
                                          : Icons.bookmark_border,
                                      color: !isSaved
                                          ? _nimonColors(theme).textSecondary
                                          : (defaultSavedActive
                                              ? theme.colorScheme.primary
                                              : _nimonColors(theme)
                                                  .textSecondary),
                                      size: 26,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Saved',
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: _nimonColors(theme)
                                                  .textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            savedCardSubtitle,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: _nimonColors(theme)
                                                  .textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: _nimonColors(theme).textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Add to a collection',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: _nimonColors(theme).textPrimary,
                                  ),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  foregroundColor: theme.colorScheme.primary,
                                ),
                                onPressed: onCreateCollection,
                                child: const Text('Create'),
                              ),
                            ],
                          ),
                        ),
                        ConstrainedBox(
                          constraints:
                              BoxConstraints(maxHeight: sheetMaxListHeight),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const ClampingScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 12),
                            itemCount: _monoSaveFolders.length,
                            itemBuilder: (context, i) {
                              final f = _monoSaveFolders[i];
                              final added = inFolder(f.id);
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 0,
                                ),
                                leading: Icon(
                                  Icons.folder_outlined,
                                  color: added
                                      ? theme.colorScheme.primary
                                      : _nimonColors(theme).textSecondary,
                                ),
                                title: Text(f.name),
                                trailing: added
                                    ? Icon(
                                        Icons.check_circle_outline,
                                        color: theme.colorScheme.primary,
                                        size: 22,
                                      )
                                    : IconButton(
                                        icon: const Icon(Icons.add),
                                        color: theme.colorScheme.primary,
                                        tooltip: 'Save to this collection',
                                        onPressed: () {
                                          final prev =
                                              _monoAssignedCollectionId(
                                                  item.id);
                                          bookmarkN.value = true;
                                          _monoSingleCollectionByItemId[
                                              item.id] = f.id;
                                          bump();
                                          final moved =
                                              prev != null && prev != f.id;
                                          Navigator.of(sheetContext).pop();
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(monoContext)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                moved
                                                    ? 'Moved to ${f.name}'
                                                    : 'Saved to ${f.name}',
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              margin: const EdgeInsets.all(16),
                                              duration:
                                                  const Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                      ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );

    if (!mounted) return;
    if (!wasSavedOnOpen && !bookmarkN.value) {
      bookmarkN.value = true;
      _monoSingleCollectionByItemId.remove(item.id);
      setState(() {});
    }
  }

  /// Display-only label beside the immersive reader back control (Profile `/mono-reader`).
  String get _readerDockContextLabel {
    switch (widget.readerMenuOrigin) {
      case MonoReaderMenuOrigin.profileUploaded:
        return 'Published Mono';
      case MonoReaderMenuOrigin.profileSaved:
        return 'Saved Mono';
      case MonoReaderMenuOrigin.publicCreatorProfile:
        return 'Mono';
      case null:
        return 'Mono';
    }
  }

  /// Owner-only story options (+/- Saved collections). Hidden for learner/public readers.
  bool get _readerDockShowsOwnerStoryMenu =>
      widget.readerMenuOrigin == MonoReaderMenuOrigin.profileUploaded ||
      widget.readerMenuOrigin == MonoReaderMenuOrigin.profileSaved;

  /// Reader dock + reader header menu: dock-anchored story options (Saved vs Uploaded actions).
  void _openReaderDockStoryOptionsPanel(List<MonoFeedItem> items) {
    if (!_readerDockShowsOwnerStoryMenu) return;
    if (items.isEmpty) return;
    final idx = _feedIndex.clamp(0, math.max(0, items.length - 1)).toInt();
    final origin = widget.readerMenuOrigin!;
    final saved = origin == MonoReaderMenuOrigin.profileSaved;
    showMonoStoryOptionsPanel(
      context,
      items[idx],
      readerMenuOrigin: origin,
      onUnsavedItemId: saved ? widget.onUnsavedMonoFeedItemId : null,
      popReaderAfterUnsave: saved
          ? () {
              if (context.mounted) context.pop();
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    if (_useRemoteForYouFeed) {
      ref.watch(monoFeedPagerProvider);
      final ps = ref.read(monoFeedPagerProvider);
      if (!ps.isInitialLoading && ps.items.isNotEmpty) {
        final list = _remoteCatalogItemsResolved();
        if (list.isNotEmpty && _feedIndex < list.length) {
          final cur = list[_feedIndex];
          if (cur.needsRemoteDetailHydration) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                unawaited(_ensureDetailLoaded(cur));
              }
            });
          }
        }
      }
    }
    if (_useRemoteFollowingFeed) {
      ref.watch(followingMonoFeedPagerProvider);
    }
    final showGuestRemoteWarn =
        ref.watch(guestRemoteDraftWarningVisibleProvider);
    final items = _resolvedFeedItems;
    if (!widget.showTopControls &&
        widget.initialItemsOverride != null &&
        items.isNotEmpty) {
      final safeIdx = _feedIndex.clamp(0, items.length - 1);
      final base = widget.initialItemsOverride![safeIdx];
      if (base.needsRemoteDetailHydration &&
          !_hydratedRemoteItems.containsKey(base.id) &&
          !_detailInflight.contains(base.id)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_ensureDetailLoaded(base));
        });
      }
    }
    final showExplanation =
        ref.watch(userPreferencesNotifierProvider).prefs.showExplanations;
    final useReaderDock = widget.showTopControls == false;
    final effectiveDockHeight = useReaderDock
        ? MonoReaderDock.occupiedHeight(context)
        : FloatingDockNavBar.dockOccupiedZoneHeight(context);
    final dockH = widget.bottomDockHeight ?? effectiveDockHeight;

    /// Extra air between the meta+learn row and the floating dock (beyond dock zone height).
    const monoAboveDockExtraGap = 10.0;

    void onDockItem(int i) {
      unawaited(
        handleFloatingDockTabSelection(
          context,
          navigationShell: null,
          index: i,
          openCreate: (ctx) {
            final loc = GoRouterState.of(ctx).uri.toString();
            if (loc == '/create' || loc.startsWith('/create?')) return;
            ref.read(creatorEntryChannelProvider.notifier).state =
                CreatorEntryChannel.add;
            ctx.push('/create');
          },
        ),
      );
    }

    final scaffold = Scaffold(
      backgroundColor: _nimonColors(theme).appBackground,
      body: SafeArea(
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: dockH + monoAboveDockExtraGap),
              child: ColoredBox(
                color: _nimonColors(theme).appBackground,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.showTopControls && showGuestRemoteWarn)
                      Material(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.92),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n?.monoGuestRemoteDraftsBanner ??
                                      'Remote drafts require sign-in.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (widget.showTopControls)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 10, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _MonoFeedTextTab(
                              label: 'Following',
                              selected:
                                  _mainFeedKind == _MonoMainFeedKind.following,
                              onTap: () =>
                                  _setMainFeedKind(_MonoMainFeedKind.following),
                              ink: _nimonColors(theme).textPrimary,
                              inkMuted: _nimonColors(theme).textSecondary,
                              accent: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            _MonoFeedTextTab(
                              label: 'For You',
                              selected:
                                  _mainFeedKind == _MonoMainFeedKind.forYou,
                              onTap: () =>
                                  _setMainFeedKind(_MonoMainFeedKind.forYou),
                              ink: _nimonColors(theme).textPrimary,
                              inkMuted: _nimonColors(theme).textSecondary,
                              accent: theme.colorScheme.primary,
                            ),
                            const Spacer(),
                            if (_mainFeedKind == _MonoMainFeedKind.forYou)
                              Theme(
                                data: theme.copyWith(
                                  splashColor: theme.colorScheme.primary
                                      .withValues(alpha: 0.08),
                                  highlightColor: theme.colorScheme.primary
                                      .withValues(alpha: 0.04),
                                ),
                                child: PopupMenuButton<String>(
                                  tooltip: 'JLPT level',
                                  position: PopupMenuPosition.under,
                                  padding: EdgeInsets.zero,
                                  splashRadius: 22,
                                  color: theme.colorScheme.surfaceContainerHigh
                                      .withValues(alpha: 0.97),
                                  elevation: 1,
                                  shadowColor:
                                      Colors.black.withValues(alpha: 0.06),
                                  surfaceTintColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  onSelected: (v) {
                                    setState(() => _selectedLevel = v);
                                    if (_useRemoteForYouFeed) {
                                      _clearRemoteHydration();
                                      ref
                                          .read(monoFeedPagerProvider.notifier)
                                          .setFilters(
                                            level: _pagerLevelFromUi(v),
                                          );
                                      unawaited(
                                        ref
                                            .read(
                                                monoFeedPagerProvider.notifier)
                                            .loadFirstPage(),
                                      );
                                    }
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (!mounted) return;
                                      final fy = _verticalForYou;
                                      if (fy != null && fy.hasClients) {
                                        fy.jumpToPage(0);
                                      }
                                      setState(() => _feedIndex = 0);
                                      final list = _useRemoteForYouFeed
                                          ? _remoteCatalogItemsResolved()
                                          : _forYouFilteredItems;
                                      if (list.isNotEmpty) {
                                        _precacheCoversNear(
                                          context,
                                          list,
                                          0,
                                        );
                                      }
                                    });
                                  },
                                  itemBuilder: (context) => [
                                    for (final lv in _levels)
                                      PopupMenuItem<String>(
                                        value: lv,
                                        height: 44,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 22,
                                              child: lv == _selectedLevel
                                                  ? Icon(
                                                      Icons.check_rounded,
                                                      size: 18,
                                                      color: theme
                                                          .colorScheme.primary,
                                                    )
                                                  : const SizedBox.shrink(),
                                            ),
                                            Text(
                                              _levelDisplayLabel(lv),
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _levelCompactMenuLabel(
                                            _selectedLevel,
                                          ),
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                            color: _nimonColors(theme)
                                                .textSecondary
                                                .withValues(alpha: 0.92),
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 0.1,
                                            height: 1.1,
                                          ),
                                        ),
                                        const SizedBox(width: 1),
                                        Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 18,
                                          color: _nimonColors(theme)
                                              .textSecondary
                                              .withValues(alpha: 0.75),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            if (_mainFeedKind == _MonoMainFeedKind.forYou)
                              const SizedBox(width: 2),
                            Tooltip(
                              message: 'Search Mono',
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => context.push('/mono/search'),
                                  borderRadius: BorderRadius.circular(12),
                                  splashColor: theme.colorScheme.primary
                                      .withValues(alpha: 0.10),
                                  highlightColor: theme.colorScheme.primary
                                      .withValues(alpha: 0.05),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Icon(
                                      Icons.search_rounded,
                                      size: 22,
                                      color: _nimonColors(theme)
                                          .textPrimary
                                          .withValues(
                                            alpha: 0.88,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (useReaderDock)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            NimonCircleNavButton(
                              onPressed: () => context.pop(),
                              tooltip: 'Back',
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _readerDockContextLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: _nimonColors(theme)
                                      .textSecondary
                                      .withValues(alpha: 0.92),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: widget.showTopControls
                          ? Directionality(
                              textDirection: TextDirection.ltr,
                              child: PageView(
                                controller: _feedTabController,
                                physics: const NeverScrollableScrollPhysics(),
                                onPageChanged: _onHorizontalFeedPageChanged,
                                children: [
                                  _buildMainMonoVerticalFeed(
                                    theme,
                                    _MonoMainFeedKind.following,
                                    showExplanation,
                                  ),
                                  _buildMainMonoVerticalFeed(
                                    theme,
                                    _MonoMainFeedKind.forYou,
                                    showExplanation,
                                  ),
                                ],
                              ),
                            )
                          : (items.isEmpty
                              ? _monoEmptyFeed(theme)
                              : PageView.builder(
                                  key: ValueKey<String>(
                                    'reader_$_selectedLevel',
                                  ),
                                  controller: _readerFeedController,
                                  scrollDirection: Axis.vertical,
                                  onPageChanged: (i) {
                                    setState(() => _feedIndex = i);
                                    _precacheCoversNear(
                                      context,
                                      items,
                                      i,
                                    );
                                    final ov = widget.initialItemsOverride;
                                    if (ov != null && i >= 0 && i < ov.length) {
                                      final b = ov[i];
                                      if (b.needsRemoteDetailHydration) {
                                        unawaited(_ensureDetailLoaded(b));
                                      }
                                    }
                                  },
                                  itemCount: items.length,
                                  itemBuilder: (context, index) {
                                    final item = items[index];
                                    final bookmarkN = _bookmarkNotifierFor(
                                      item.id,
                                      initial: item.isBookmarkedByMe,
                                    );
                                    final reactedInitial =
                                        (item.myReaction ?? '')
                                            .trim()
                                            .isNotEmpty;
                                    final reactN = _reactNotifierFor(
                                      item.id,
                                      initial: reactedInitial,
                                    );
                                    final likesN = _likesCountNotifierFor(
                                      item.id,
                                      initial: item.likesCount,
                                    );
                                    return _ReadingFeedPost(
                                      item: item,
                                      bookmarkNotifier: bookmarkN,
                                      reactNotifier: reactN,
                                      likesCountNotifier: likesN,
                                      onLearn: () => _openLearn(item),
                                      onToggleBookmark: () =>
                                          unawaited(_toggleBookmark(item)),
                                      onToggleReact: () =>
                                          unawaited(_toggleReact(item)),
                                      onShare: () => _share(item),
                                      readingBg:
                                          _nimonColors(theme).appBackground,
                                      readingInk:
                                          _nimonColors(theme).textPrimary,
                                      readingInkMuted:
                                          _nimonColors(theme).textSecondary,
                                      showExplanationLines: showExplanation,
                                      currentUserId: _currentUserId,
                                    );
                                  },
                                )),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: useReaderDock
                  ? MonoReaderDock(
                      onAddMono: () {
                        hideMonoStoryOptionsPanel();
                        ref.read(creatorEntryChannelProvider.notifier).state =
                            CreatorEntryChannel.add;
                        context.push('/create');
                      },
                      onMenu: _readerDockShowsOwnerStoryMenu
                          ? () => _openReaderDockStoryOptionsPanel(items)
                          : null,
                    )
                  : (widget.bottomDock ??
                      FloatingDockNavBar(
                        selectedIndex: 0,
                        onItemTapped: onDockItem,
                        theme: theme,
                      )),
            ),
          ],
        ),
      ),
    );

    if (!useReaderDock) return scaffold;

    return ValueListenableBuilder<bool>(
      valueListenable: monoReaderStoryOptionsOpen,
      builder: (context, panelOpen, child) {
        return PopScope(
          canPop: !panelOpen,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && panelOpen) {
              hideMonoStoryOptionsPanel();
            }
          },
          child: child!,
        );
      },
      child: scaffold,
    );
  }

  Widget _remoteFollowingFeedErrorPanel(ThemeData theme, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Could not load Following.',
              style: theme.textTheme.titleMedium?.copyWith(
                color: _nimonColors(theme).textPrimary,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              style: theme.textTheme.bodySmall?.copyWith(
                color: _nimonColors(theme).textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                unawaited(
                  ref
                      .read(followingMonoFeedPagerProvider.notifier)
                      .loadFirstPage(),
                );
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Per feed page: full-width story column; footer is [footerRow] (transparent meta + action column).
class _MonoGroupedBackgroundContent extends StatelessWidget {
  final Color background;
  final Widget storyTextArea;
  final Widget footerRow;

  const _MonoGroupedBackgroundContent({
    required this.background,
    required this.storyTextArea,
    required this.footerRow,
  });

  static const _footerRowRightPad = 8.0;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background,
      child: Padding(
        padding: const EdgeInsets.only(
          left: 14,
          right: _footerRowRightPad,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: storyTextArea),
            footerRow,
          ],
        ),
      ),
    );
  }
}

class _ReadingFeedPost extends StatefulWidget {
  final MonoFeedItem item;
  final ValueNotifier<bool> bookmarkNotifier;
  final ValueNotifier<bool> reactNotifier;
  final ValueNotifier<int> likesCountNotifier;
  final VoidCallback onLearn;
  final VoidCallback onToggleBookmark;
  final VoidCallback onToggleReact;
  final VoidCallback onShare;
  final Color readingBg;
  final Color readingInk;
  final Color readingInkMuted;
  final bool showExplanationLines;
  final String? currentUserId;

  const _ReadingFeedPost({
    required this.item,
    required this.bookmarkNotifier,
    required this.reactNotifier,
    required this.likesCountNotifier,
    required this.onLearn,
    required this.onToggleBookmark,
    required this.onToggleReact,
    required this.onShare,
    required this.readingBg,
    required this.readingInk,
    required this.readingInkMuted,
    required this.showExplanationLines,
    required this.currentUserId,
  });

  @override
  State<_ReadingFeedPost> createState() => _ReadingFeedPostState();
}

// -----------------------------------------------------------------------------
// Mono feed post — story + meta + Learn in [_MonoGroupedBackgroundContent] (column, not screen-bottom overlays).
// -----------------------------------------------------------------------------

/// Leading horizontal page: blurred full-bleed cover + centered poster (contain), not full-screen.
class _MonoCoverPage extends StatelessWidget {
  final MonoFeedItem item;
  final Color background;

  const _MonoCoverPage({
    required this.item,
    required this.background,
  });

  static const _fgMaxWidthFrac = 0.85;
  static const _fgMaxHeightFrac = 0.63;
  static const _blurSigma = 24.0;
  static const _bgScale = 1.08;

  /// Vertical breathing room so the blurred layer is not flush to the top/bottom edges.
  static const _blurVerticalInset = 14.0;

  @override
  Widget build(BuildContext context) {
    final fallback = _monoCoverFallbackAsset(_monoEffectiveCoverCategory(item));
    final url = item.coverImageUrl?.trim();

    final ImageProvider<Object> coverProvider;
    if (url != null && url.isNotEmpty) {
      coverProvider = NetworkImage(url);
    } else {
      coverProvider = AssetImage(fallback);
    }

    return ColoredBox(
      color: background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cw = constraints.maxWidth;
          final ch = constraints.maxHeight;
          final maxFgW = cw * _fgMaxWidthFrac;
          final maxFgH = ch * _fgMaxHeightFrac;

          final bh = (ch - 2 * _blurVerticalInset).clamp(0.0, ch);
          // Regenerated blur from the *same* cover image: decode a dedicated
          // background-sized image and blur that (cleaner, less noisy than blurring
          // the foreground asset directly).
          final bgProvider = ResizeImage(
            coverProvider,
            width: cw.round(),
            height: bh.round(),
          );

          final Widget bgSharp = Image(
            image: bgProvider,
            fit: BoxFit.cover,
            width: cw,
            height: bh,
            alignment: Alignment.center,
            filterQuality: FilterQuality.low,
            errorBuilder: (_, __, ___) => ColoredBox(color: background),
          );

          final Widget fgSharp = Image(
            image: coverProvider,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => Image.asset(
              fallback,
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
          );

          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: _blurVerticalInset,
                  ),
                  child: ClipRect(
                    child: RepaintBoundary(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: _blurSigma,
                          sigmaY: _blurSigma,
                        ),
                        child: Opacity(
                          opacity: 0.96,
                          child: ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              background.withValues(alpha: 0.10),
                              BlendMode.srcOver,
                            ),
                            child: Transform.scale(
                              scale: _bgScale,
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: cw,
                                height: bh,
                                child: bgSharp,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        background.withOpacity(0.38),
                        background.withOpacity(0.62),
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxFgW,
                    maxHeight: maxFgH,
                  ),
                  child: fgSharp,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Read mode only: footer row is transparent meta + transparent More/React column (see [_buildReadingFooterRow]).
// (M12b3) Read-mode action rail is always visible and aligned with the footer
// meta group. The old expand/collapse arrow-FAB system was removed to match the
// cover page presentation.

/// Bottom-left account/meta block (shorter than the Learn rail). Bottom edge aligns with [_MonoLearnRailOverlay].
///
/// [_MeasureSize] on the composed footer row drives L1 [readingBottomInset] layout math.
class _ReadingFeedPostState extends State<_ReadingFeedPost>
    with AutomaticKeepAliveClientMixin {
  static const _hPad = 20.0;
  static const _footerMetaToActionGap = 8.0;

  /// Matches [_MonoGroupedBackgroundContent] right padding — rail inset from the screen edge.
  static const _footerRowRightPaddingPx = 8.0;

  /// Minimal bottom inset inside the page frame; overlays sit on top of text below.
  static const _readBottomPad = 8.0;

  /// Read mode vertical rhythm: matches Hero [_MonoCoverPage] `_blurVerticalInset` (symmetric top/bottom breath).
  static const double _readModeStandardVerticalBreath = 14.0;

  /// Read mode bottom separation from the account meta group below the reading area.
  /// This is intentional “breathing room” that should exist even when the text is short
  /// (i.e. not relying on scroll length).
  static const double _readModeMetaBreath = 18.0;

  /// Top padding for Read mode scroll content: Mono top pills clearance + same breath as Hero cover edges.
  static double _readModeScrollTopPadding(double topClearance) =>
      topClearance + _readModeStandardVerticalBreath;

  /// Flatten a structured line into ruby tokens (character-level when no readings).
  List<NimonRubyToken> _lineToLayoutTokens(MonoSentenceLine l) {
    if (l.tokens.isEmpty) {
      final out = <NimonRubyToken>[];
      for (final ch in l.plainText.characters) {
        out.add(NimonRubyToken(text: ch));
      }
      return out;
    }
    final out = <NimonRubyToken>[];
    for (final t in l.tokens) {
      final reading = (t.reading ?? '').trim();
      if (reading.isNotEmpty) {
        out.add(NimonRubyToken(text: t.text, reading: t.reading));
      } else {
        for (final ch in t.text.characters) {
          out.add(NimonRubyToken(text: ch));
        }
      }
    }
    return out;
  }

  static double _responsiveJaFontSize(double w, double h) {
    // Width is the primary signal, but slightly tighten on short screens.
    final byW = monoReadingBodyFontSize(w);
    if (h < 720) return (byW - 0.75).clamp(19.0, 24.0);
    if (h < 800) return (byW - 0.35).clamp(19.5, 24.5);
    return byW;
  }

  static double _responsiveJaLineHeight(double w, double h) {
    // Keep vertical rhythm compact (typical body ~1.35–1.45×) while avoiding overflow.
    if (w < 360 || h < 720) return 1.40;
    if (w < 400 || h < 800) return 1.42;
    return monoReadingLineHeightFactor;
  }

  int _pageIndex = 0;
  double _metaH = 0;
  int? _lastHPageLayoutKey;

  // (M12b3) Reader actions are always visible (no arrow-FAB collapse system).
  late final PageController _horizontalPageController;

  Future<void> _openMonoActionsSheet({required bool allowBookmark}) async {
    final item = widget.item;
    final tc = Theme.of(context).colors;

    final p = item.publishedAccess;
    final showLearn = p?.isFullLearnPublished == true;

    final isSaved = widget.bookmarkNotifier.value;
    final shareLink = monoShareUrlOrEmpty(item);
    final shareEnabled = shareLink.trim().isNotEmpty;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: tc.surface,
      builder: (ctx) {
        final padBottom = MediaQuery.viewPaddingOf(ctx).bottom;

        Widget row({
          required IconData icon,
          required String title,
          String? subtitle,
          required VoidCallback? onTap,
          bool enabled = true,
        }) {
          final ink = enabled ? tc.textPrimary : tc.textSecondary;
          final subInk = tc.textSecondary;
          return ListTile(
            enabled: enabled,
            leading: Icon(icon, color: ink),
            title: Text(
              title,
              style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(color: ink),
            ),
            subtitle: subtitle == null
                ? null
                : Text(
                    subtitle,
                    style: Theme.of(ctx)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: subInk),
                  ),
            onTap: enabled ? onTap : null,
          );
        }

        return Padding(
          padding: EdgeInsets.only(bottom: padBottom),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                  child: Text(
                    'Mono actions',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          color: tc.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const Divider(height: 1),
                if (showLearn)
                  row(
                    icon: Icons.school_outlined,
                    title: 'Learn this story',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      widget.onLearn();
                    },
                  ),
                if (allowBookmark)
                  row(
                    icon: isSaved ? Icons.bookmark : Icons.bookmark_outline,
                    title: isSaved ? 'Saved' : 'Save',
                    subtitle: isSaved ? 'Tap to unsave' : null,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      widget.onToggleBookmark();
                    },
                  ),
                row(
                  icon: Icons.ios_share,
                  title: 'Share',
                  subtitle: shareEnabled ? null : 'Share link unavailable',
                  enabled: shareEnabled,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    widget.onShare();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _horizontalPageController = PageController(viewportFraction: 1.0);
  }

  @override
  void dispose() {
    _horizontalPageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ReadingFeedPost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _pageIndex = 0;
      _lastHPageLayoutKey = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _horizontalPageController.hasClients) {
          _horizontalPageController.jumpToPage(0);
        }
      });
    }
  }

  Widget _buildReadingFooterRow({required Widget meta}) {
    final allowBookmark = canBookmarkMono(
      currentUserId: widget.currentUserId,
      monoOwnerId: widget.item.writerId,
    );
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.bookmarkNotifier,
        widget.reactNotifier,
        widget.likesCountNotifier,
      ]),
      builder: (context, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: meta),
            SizedBox(width: _footerMetaToActionGap),
            _MonoFooterTransparentActionColumn(
              isReacted: widget.reactNotifier.value,
              likesCount: widget.likesCountNotifier.value,
              onToggleReact: widget.onToggleReact,
              onMore: () => unawaited(
                _openMonoActionsSheet(allowBookmark: allowBookmark),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final item = widget.item;
    final effectiveText = item.effectiveBodyText;
    final structured = item.content;

    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final theme = Theme.of(context);
          // Top pills live in [MonoScreen]’s Column above the PageView — only a small inset here.
          const topClearance = 8.0;
          final metaForLayout = _metaH > 0 ? _metaH : 78.0;
          // Story sits above footer row — full padded width for layout math.
          final contentH = (constraints.maxHeight - metaForLayout)
              .clamp(0.0, double.infinity);
          final paddedW =
              (constraints.maxWidth - 14.0 - _footerRowRightPaddingPx)
                  .clamp(0.0, constraints.maxWidth);

          final phoneW = MediaQuery.sizeOf(context).width;
          final phoneH = MediaQuery.sizeOf(context).height;
          final fontSize = _responsiveJaFontSize(phoneW, phoneH);
          final base = theme.textTheme.bodyLarge ?? const TextStyle();
          final bodyStyle = base.copyWith(
            fontSize: fontSize,
            height: _responsiveJaLineHeight(phoneW, phoneH),
            color: widget.readingInk,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.02,
          );
          final scaler = MediaQuery.textScalerOf(context);

          final structuredPages = structured == null
              ? const <MonoContentPage>[]
              : structured.pages
                  .where((p) => p.lines.isNotEmpty)
                  .toList(growable: false);
          final useStructured = structuredPages.isNotEmpty;

          if (useStructured) {
            final allLines = <MonoSentenceLine>[
              for (final p in structuredPages) ...p.lines,
            ];
            final rubyStyleForMeasure = Theme.of(context).type.furigana(
                  Theme.of(context),
                  context.widthClass,
                );
            // One continuous token stream with line breaks between sentences.
            final allTokens = <NimonRubyToken>[];
            for (int i = 0; i < allLines.length; i++) {
              allTokens.addAll(_lineToLayoutTokens(allLines[i]));
              if (i != allLines.length - 1) {
                allTokens.add(const NimonRubyToken(text: '\n'));
              }
            }

            final hasReadingBody = allTokens.isNotEmpty;
            final horizontalCount = hasReadingBody ? 2 : 1;
            if (_pageIndex >= horizontalCount) {
              _pageIndex = math.max(0, horizontalCount - 1);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _horizontalPageController.hasClients) {
                  _horizontalPageController.jumpToPage(_pageIndex);
                }
              });
            }

            final readingColumnMaxW =
                (constraints.maxWidth - _hPad * 2).clamp(0.0, double.infinity);
            final readingTopPad = _readModeScrollTopPadding(topClearance);
            final readingBottomInset = _readBottomPad +
                _readModeStandardVerticalBreath +
                _readModeMetaBreath +
                MediaQuery.paddingOf(context).bottom;

            Widget structuredReadingScroll() {
              Widget rubyScroll(Widget body) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    _hPad,
                    readingTopPad,
                    _hPad,
                    readingBottomInset,
                  ),
                  child: SelectionArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(maxWidth: readingColumnMaxW),
                        child: body,
                      ),
                    ),
                  ),
                );
              }

              if (!widget.showExplanationLines) {
                return rubyScroll(
                  NimonRubyText(
                    tokens: allTokens,
                    baseStyle: bodyStyle,
                    rubyStyle: rubyStyleForMeasure,
                    rubyColor: widget.readingInkMuted.withValues(alpha: 0.92),
                    textAlign: TextAlign.start,
                  ),
                );
              }

              final explanationMutedStyle =
                  theme.textTheme.bodyMedium?.copyWith(
                        color: widget.readingInkMuted.withValues(alpha: 0.95),
                        height: 1.38,
                        fontWeight: FontWeight.w400,
                      ) ??
                      TextStyle(
                        color: widget.readingInkMuted.withValues(alpha: 0.95),
                        height: 1.38,
                      );
              final explanationSecondaryStyle = explanationMutedStyle.copyWith(
                fontSize: (explanationMutedStyle.fontSize ?? 14) - 0.5,
                color: widget.readingInkMuted.withValues(alpha: 0.82),
              );

              return rubyScroll(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < allLines.length; i++) ...[
                      if (i > 0) const SizedBox(height: 14),
                      NimonRubyText(
                        tokens: _lineToLayoutTokens(allLines[i]),
                        baseStyle: bodyStyle,
                        rubyStyle: rubyStyleForMeasure,
                        rubyColor:
                            widget.readingInkMuted.withValues(alpha: 0.92),
                        textAlign: TextAlign.start,
                      ),
                      Builder(
                        builder: (context) {
                          final disp = monoLineExplanationDisplay(
                            allLines[i].explanation,
                          );
                          if (disp == null || disp.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  disp.primary,
                                  style: explanationMutedStyle,
                                ),
                                if (disp.secondary != null &&
                                    disp.secondary!.trim().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      disp.secondary!,
                                      style: explanationSecondaryStyle,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              );
            }

            return _MonoGroupedBackgroundContent(
              background: widget.readingBg,
              storyTextArea: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fill(
                    child: PageView.builder(
                      controller: _horizontalPageController,
                      clipBehavior: Clip.hardEdge,
                      physics: horizontalCount > 1
                          ? const PageScrollPhysics(
                              parent: ClampingScrollPhysics(),
                            )
                          : const NeverScrollableScrollPhysics(),
                      onPageChanged: (i) => setState(() {
                        _pageIndex = i;
                      }),
                      itemCount: horizontalCount,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return RepaintBoundary(
                            child: _MonoCoverPage(
                              item: item,
                              background: widget.readingBg,
                            ),
                          );
                        }
                        return RepaintBoundary(
                          child: structuredReadingScroll(),
                        );
                      },
                    ),
                  ),
                ],
              ),
              footerRow: _MeasureSize(
                onChange: (s) {
                  final h = s.height;
                  if ((h - _metaH).abs() < 0.5) return;
                  if (!mounted) return;
                  setState(() => _metaH = h);
                },
                child: _buildReadingFooterRow(
                  meta: _PostFooterMeta(
                    writerId: (item.writerId ?? '').trim(),
                    currentUserId: widget.currentUserId,
                    writerDisplayName: item.writerName,
                    writerAvatarUrl: item.writerAvatarUrl,
                    level: item.level,
                    publishedAccess: item.publishedAccess,
                    title: item.title,
                    ink: widget.readingInk,
                    inkMuted: widget.readingInkMuted,
                    onTapCreator: () {
                      final loc = creatorProfileLocation(
                        userId: item.writerId,
                        handle: item.writerHandle,
                        allowLegacyHandle: false,
                      );
                      if (loc == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Creator profile is not available yet.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      context.push(loc);
                    },
                  ),
                ),
              ),
            );
          }

          final trimmedBody = effectiveText.trim();
          final hasReadingBody = trimmedBody.isNotEmpty;
          final horizontalCount = hasReadingBody ? 2 : 1;

          final pageKey = Object.hash(
            item.id,
            effectiveText.hashCode,
            fontSize.round(),
            (scaler.scale(1.0) * 100).round(),
            paddedW.round(),
            contentH.round(),
          );

          if (_lastHPageLayoutKey != null && pageKey != _lastHPageLayoutKey) {
            _pageIndex = 0;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _horizontalPageController.hasClients) {
                _horizontalPageController.jumpToPage(0);
              }
            });
          }
          _lastHPageLayoutKey = pageKey;

          if (_pageIndex >= horizontalCount) {
            _pageIndex = math.max(0, horizontalCount - 1);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _horizontalPageController.hasClients) {
                _horizontalPageController.jumpToPage(_pageIndex);
              }
            });
          }

          final readingTopPad = _readModeScrollTopPadding(topClearance);
          final readingBottomInset = _readBottomPad +
              _readModeStandardVerticalBreath +
              _readModeMetaBreath +
              MediaQuery.paddingOf(context).bottom;

          final plainMaxW =
              (constraints.maxWidth - _hPad * 2).clamp(0.0, double.infinity);

          Widget plainReadingScroll() {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                _hPad,
                readingTopPad,
                _hPad,
                readingBottomInset,
              ),
              child: SelectionArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: plainMaxW),
                    child: Text(
                      trimmedBody,
                      style: bodyStyle,
                      textAlign: TextAlign.start,
                    ),
                  ),
                ),
              ),
            );
          }

          return _MonoGroupedBackgroundContent(
            background: widget.readingBg,
            storyTextArea: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: PageView.builder(
                    controller: _horizontalPageController,
                    clipBehavior: Clip.hardEdge,
                    physics: horizontalCount > 1
                        ? const PageScrollPhysics(
                            parent: ClampingScrollPhysics(),
                          )
                        : const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() {
                      _pageIndex = i;
                    }),
                    itemCount: horizontalCount,
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return RepaintBoundary(
                          child: _MonoCoverPage(
                            item: item,
                            background: widget.readingBg,
                          ),
                        );
                      }
                      return RepaintBoundary(
                        child: plainReadingScroll(),
                      );
                    },
                  ),
                ),
              ],
            ),
            footerRow: _MeasureSize(
              onChange: (s) {
                final h = s.height;
                if ((h - _metaH).abs() < 0.5) return;
                if (!mounted) return;
                setState(() => _metaH = h);
              },
              child: _buildReadingFooterRow(
                meta: _PostFooterMeta(
                  writerId: (item.writerId ?? '').trim(),
                  currentUserId: widget.currentUserId,
                  writerDisplayName: item.writerName,
                  writerAvatarUrl: item.writerAvatarUrl,
                  level: item.level,
                  publishedAccess: item.publishedAccess,
                  title: item.title,
                  ink: widget.readingInk,
                  inkMuted: widget.readingInkMuted,
                  onTapCreator: () {
                    final loc = creatorProfileLocation(
                      userId: item.writerId,
                      handle: item.writerHandle,
                      allowLegacyHandle: false,
                    );
                    if (loc == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Creator profile is not available yet.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    context.push(loc);
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MeasureSize extends StatefulWidget {
  final Widget child;
  final ValueChanged<Size> onChange;

  const _MeasureSize({required this.child, required this.onChange});

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  final _key = GlobalKey();
  Size? _last;

  void _report() {
    final ctx = _key.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final s = box.size;
    if (_last == s) return;
    _last = s;
    widget.onChange(s);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  void didUpdateWidget(covariant _MeasureSize oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: widget.child,
    );
  }
}

// ignore: unused_element
class _MonoStructuredLineBlock extends StatelessWidget {
  const _MonoStructuredLineBlock({
    required this.line,
    required this.jaStyle,
    required this.explainStyle,
    required this.preferredExplainLang,
    required this.readingInkMuted,
    required this.showExplanation,
  });

  final MonoSentenceLine line;
  final TextStyle jaStyle;
  final TextStyle explainStyle;
  final String preferredExplainLang; // 'en' | 'my'
  final Color readingInkMuted;
  final bool showExplanation;

  String? _pickExplanation(MonoExplanationLine? e) {
    if (e == null) return null;
    final en = (e.en ?? '').trim();
    final my = (e.my ?? '').trim();
    if (preferredExplainLang == 'my') {
      if (my.isNotEmpty) return my;
      if (en.isNotEmpty) return en;
      return null;
    }
    if (en.isNotEmpty) return en;
    if (my.isNotEmpty) return my;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final toks = line.tokens;
    final explain = _pickExplanation(line.explanation);
    final rubyTokens = toks.isEmpty
        ? null
        : toks
            .map(
              (t) => NimonRubyToken(text: t.text, reading: t.reading),
            )
            .toList(growable: false);

    return DefaultTextStyle(
      style: jaStyle,
      child: NimonSentenceBlock(
        tokens: rubyTokens,
        plainJapanese: toks.isEmpty ? line.plainText : null,
        translation: explain,
        showTranslation: false,
        padding: EdgeInsets.zero,
        textAlign: TextAlign.start,
      ),
    );
  }
}

class _MonoPageView extends StatefulWidget {
  final List<String> pages;
  final TextStyle bodyStyle;
  final double textMaxWidth;
  final double horizontalPaddingLeft;
  final double horizontalPaddingRight;
  final double readTopPad;
  final double readBottomPad;
  final double maxTextHeight;
  final TextScaler textScaler;
  final ValueChanged<int> onPageChanged;

  const _MonoPageView({
    required this.pages,
    required this.bodyStyle,
    required this.textMaxWidth,
    required this.horizontalPaddingLeft,
    required this.horizontalPaddingRight,
    required this.readTopPad,
    required this.readBottomPad,
    required this.maxTextHeight,
    required this.textScaler,
    required this.onPageChanged,
  });

  @override
  State<_MonoPageView> createState() => _MonoPageViewState();
}

class _MonoPageViewState extends State<_MonoPageView> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 1.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// One full-viewport reading surface per internal page (no horizontal offset canvas).
  Widget _readingPage(String t) {
    final pad = EdgeInsets.fromLTRB(
      widget.horizontalPaddingLeft,
      widget.readTopPad,
      widget.horizontalPaddingRight,
      widget.readBottomPad,
    );
    final innerH =
        (widget.maxTextHeight - pad.vertical).clamp(0.0, widget.maxTextHeight);

    final framed = Padding(
      padding: pad,
      child: ClipRect(
        child: SizedBox(
          height: innerH,
          width: double.infinity,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: widget.textMaxWidth),
              child: SelectionArea(
                child: Text(
                  t,
                  style: widget.bodyStyle,
                  textAlign: TextAlign.start,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return ClipRect(
      child: SizedBox.expand(
        child: framed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final multi = widget.pages.length > 1;

    return PageView.builder(
      clipBehavior: Clip.hardEdge,
      controller: _controller,
      physics: multi
          ? const PageScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      onPageChanged: widget.onPageChanged,
      itemCount: widget.pages.length,
      itemBuilder: (context, i) => _readingPage(widget.pages[i]),
    );
  }
}

/// Premium lightweight text tab for Mono feed switching (Following / For You).
class _MonoFeedTextTab extends StatelessWidget {
  const _MonoFeedTextTab({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.ink,
    required this.inkMuted,
    required this.accent,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color ink;
  final Color inkMuted;
  final Color accent;

  static double _indicatorTargetWidth(String label) =>
      (label.length * 9.2 + 10).clamp(36.0, 88.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetW = _indicatorTargetWidth(label);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: accent.withValues(alpha: 0.10),
        highlightColor: accent.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: selected ? -0.35 : -0.2,
                  height: 1.15,
                  color: selected
                      ? ink.withValues(alpha: 0.96)
                      : inkMuted.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 7),
              SizedBox(
                height: 2.5,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    height: 2.5,
                    width: selected ? targetW : 0,
                    decoration: BoxDecoration(
                      color: selected
                          ? accent.withValues(alpha: 0.92)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(1.25),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state when Following feed has no posts (V1).
class _FollowingFeedEmptyState extends StatelessWidget {
  const _FollowingFeedEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nothing here yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Follow creators to see their Mono in this feed.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _WriterFooterAvatar extends StatelessWidget {
  const _WriterFooterAvatar({
    this.url,
    required this.ink,
    required this.inkMuted,
  });

  final String? url;
  final Color ink;
  final Color inkMuted;

  @override
  Widget build(BuildContext context) {
    final u = (url ?? '').trim();
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: ink.withOpacity(0.06),
        shape: BoxShape.circle,
        border: Border.all(color: ink.withOpacity(0.11)),
      ),
      clipBehavior: Clip.antiAlias,
      child: u.isEmpty
          ? Icon(Icons.person_outline, size: 20, color: inkMuted)
          : Image.network(
              u,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.person_outline, size: 20, color: inkMuted),
            ),
    );
  }
}

class _PostFooterMeta extends StatelessWidget {
  /// Breathing room above the username row (balances with action column height).
  static const _metaColumnTopInset = 6.0;

  /// Username row → story title.
  static const _metaNameToTitleGap = 6.0;

  /// Story title → level/status chip.
  static const _metaTitleToChipGap = 5.0;

  final String writerId;
  final String? currentUserId;
  final String writerDisplayName;
  final String? writerAvatarUrl;
  final String level;
  final PublishedMonoAccess? publishedAccess;
  final String? title;
  final Color ink;
  final Color inkMuted;
  final VoidCallback? onTapCreator;

  const _PostFooterMeta({
    required this.writerId,
    required this.currentUserId,
    required this.writerDisplayName,
    this.writerAvatarUrl,
    required this.level,
    required this.publishedAccess,
    this.title,
    required this.ink,
    required this.inkMuted,
    this.onTapCreator,
  });

  String _statusLabel() {
    final isFullLearn = publishedAccess?.isFullLearnPublished == true;
    final mode = isFullLearn ? 'Full Learn' : 'Read only';
    final lv = level.trim();
    if (lv.isEmpty) return mode;
    return '$lv · $mode';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tc = theme.colors;

    final trimmedTitle = (title ?? '').trim();

    final showFollow = writerId.trim().isNotEmpty &&
        (currentUserId ?? '').trim() != writerId.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          label: 'View creator profile',
          button: true,
          child: Material(
            key: const ValueKey('monoReaderCreatorAvatar'),
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTapCreator,
              customBorder: const CircleBorder(),
              splashColor: ink.withValues(alpha: 0.10),
              highlightColor: ink.withValues(alpha: 0.04),
              child: _WriterFooterAvatar(
                url: writerAvatarUrl,
                ink: ink,
                inkMuted: inkMuted,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: _metaColumnTopInset),
              Row(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Semantics(
                      label: 'View creator profile',
                      button: true,
                      container: true,
                      child: InkWell(
                        key: const ValueKey('monoReaderCreatorUsername'),
                        onTap: onTapCreator,
                        borderRadius: BorderRadius.circular(8),
                        splashColor: ink.withValues(alpha: 0.10),
                        highlightColor: ink.withValues(alpha: 0.04),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 2,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              writerDisplayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                height: 1.12,
                                letterSpacing: -0.15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (showFollow) ...[
                    const SizedBox(width: 6),
                    _FooterFollowButton(
                      targetUserId: writerId,
                      currentUserId: currentUserId,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: _metaNameToTitleGap),
              if (trimmedTitle.isNotEmpty)
                Text(
                  trimmedTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: ink.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    height: 1.2,
                  ),
                ),
              const SizedBox(height: _metaTitleToChipGap),
              _MonoStatusChip(
                label: _statusLabel(),
                ink: tc.textSecondary,
                border: tc.border,
                background:
                    tc.surface.withValues(alpha: _MonoStatusChip.kSurfaceAlpha),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonoStatusChip extends StatelessWidget {
  /// Shared with [_FooterFollowButtonState] “Following” outline style.
  static const double kSurfaceAlpha = 0.55;
  static const double kBorderAlpha = 0.7;

  final String label;
  final Color ink;
  final Color border;
  final Color background;

  const _MonoStatusChip({
    required this.label,
    required this.ink,
    required this.border,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = label.trim();
    if (t.isEmpty) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border.withValues(alpha: kBorderAlpha)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          t,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: ink,
            fontWeight: FontWeight.w600,
            fontSize: 10,
            height: 1.0,
            letterSpacing: 0.08,
          ),
        ),
      ),
    );
  }
}

class _FooterFollowButton extends ConsumerStatefulWidget {
  final String targetUserId;
  final String? currentUserId;

  const _FooterFollowButton({
    required this.targetUserId,
    required this.currentUserId,
  });

  @override
  ConsumerState<_FooterFollowButton> createState() =>
      _FooterFollowButtonState();
}

class _FooterFollowButtonState extends ConsumerState<_FooterFollowButton> {
  bool _loading = false;
  bool? _isFollowing;

  bool get _isAuthed =>
      ref.read(authSessionProvider) is AuthSessionAuthenticated;

  bool get _isSelf {
    final me = (widget.currentUserId ?? '').trim();
    final target = widget.targetUserId.trim();
    if (me.isEmpty || target.isEmpty) return false;
    return me == target;
  }

  Future<void> _loadInitialIfNeeded() async {
    if (!mounted) return;
    if (!RemoteBackendConfig.useRemoteDrafts) return;
    if (!_isAuthed) return;
    if (_isSelf) return;
    if (_isFollowing != null) return;
    final target = widget.targetUserId.trim();
    if (target.isEmpty) return;
    try {
      final repo = ref.read(remotePublicCreatorProfileRepositoryProvider);
      final p = await repo.fetchPublicCreatorProfile(target);
      if (!mounted) return;
      setState(() => _isFollowing = p.isFollowingByMe);
    } catch (_) {
      // If this fails, we still allow the user to attempt Follow.
      if (!mounted) return;
      setState(() => _isFollowing = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _toggleFollow() async {
    if (_loading) return;
    if (!RemoteBackendConfig.useRemoteDrafts) return;
    if (_isSelf) return;
    if (!await ensureProtectedActionAllowed(
      context,
      action: ProtectedActionType.follow,
    )) {
      return;
    }

    final target = widget.targetUserId.trim();
    if (target.isEmpty) return;

    final before = _isFollowing ?? false;
    final next = !before;
    setState(() {
      _loading = true;
      _isFollowing = next;
    });

    try {
      final repo = ref.read(remoteUserFollowRepositoryProvider);
      final out = next
          ? await repo.followUser(target)
          : await repo.unfollowUser(target);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _isFollowing = out.isFollowing;
      });
      // Refresh the key surfaces that depend on follow state.
      unawaited(ref.read(followingMonoFeedPagerProvider.notifier).refresh());
      unawaited(
          ref.read(profileFollowingPagerProvider.notifier).loadFirstPage());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _isFollowing = before;
      });
      final offlineMsg = offlineUserMessageIfRecognized(e);
      _snack(offlineMsg ??
          (e is StateError ? e.message : 'Could not update follow.'));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_loadInitialIfNeeded());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tc = theme.colors;

    final target = widget.targetUserId.trim();
    if (target.isEmpty) return const SizedBox.shrink();
    if (_isSelf) return const SizedBox.shrink();

    final isFollowing = _isFollowing ?? false;

    final baseStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w800,
      fontSize: 12,
      height: 1.0,
      letterSpacing: 0.1,
    );

    const followRadius = 10.0;
    final minSize = const Size(0, 28);
    final minWidth = isFollowing ? 84.0 : 68.0;
    final followBg = tc.textPrimary.withValues(alpha: 0.88);
    final followFg = tc.appBackground;
    final disabledBg = tc.textPrimary.withValues(alpha: 0.45);
    final disabledFg = tc.appBackground.withValues(alpha: 0.9);

    final followingBg =
        tc.surface.withValues(alpha: _MonoStatusChip.kSurfaceAlpha);
    final followingFg = tc.textSecondary;
    final followingBorder =
        tc.border.withValues(alpha: _MonoStatusChip.kBorderAlpha);
    final followingDisabledBg = tc.surface.withValues(alpha: 0.35);
    final followingDisabledFg = tc.textSecondary.withValues(alpha: 0.45);

    if (isFollowing) {
      return Semantics(
        button: true,
        label: 'Following',
        child: ConstrainedBox(
          key: const ValueKey('monoReaderFollowButton'),
          constraints: BoxConstraints(minWidth: minWidth),
          child: OutlinedButton(
            onPressed: _loading ? null : _toggleFollow,
            style: OutlinedButton.styleFrom(
              minimumSize: minSize,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              elevation: 0,
              foregroundColor: followingFg,
              backgroundColor: followingBg,
              disabledForegroundColor: followingDisabledFg,
              disabledBackgroundColor: followingDisabledBg,
              side: BorderSide(color: followingBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(followRadius),
              ),
            ),
            child: Text(
              'Following',
              style: baseStyle?.copyWith(color: followingFg),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'Follow',
      child: ConstrainedBox(
        key: const ValueKey('monoReaderFollowButton'),
        constraints: BoxConstraints(minWidth: minWidth),
        child: FilledButton(
          onPressed: _loading ? null : _toggleFollow,
          style: FilledButton.styleFrom(
            minimumSize: minSize,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: followBg,
            foregroundColor: followFg,
            disabledForegroundColor: disabledFg,
            disabledBackgroundColor: disabledBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(followRadius),
            ),
          ),
          child: Text(
            'Follow',
            style: baseStyle?.copyWith(color: followFg),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
        ),
      ),
    );
  }
}

/// Transparent vertical column: More then React + count; no background.
class _MonoFooterTransparentActionColumn extends StatelessWidget {
  static const columnWidth = 52.0;
  static const betweenActions = 5.0;
  static const _countFontSize = 11.0;

  final bool isReacted;
  final int likesCount;
  final VoidCallback onToggleReact;
  final VoidCallback onMore;

  const _MonoFooterTransparentActionColumn({
    required this.isReacted,
    required this.likesCount,
    required this.onToggleReact,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tc = theme.colors;
    final reactIcon = isReacted ? tc.react : tc.textPrimary;
    final showCount = likesCount > 0;
    return SizedBox(
      width: columnWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _FooterReaderIconActionButton(
            semanticsLabel: 'More actions',
            icon: Icons.more_horiz,
            foregroundColor: tc.textSecondary,
            onPressed: onMore,
          ),
          const SizedBox(height: betweenActions),
          _FooterReaderIconActionButton(
            semanticsLabel: monoReactRailSemanticsLabel(likesCount),
            icon: isReacted ? Icons.favorite : Icons.favorite_border,
            foregroundColor: reactIcon,
            onPressed: onToggleReact,
          ),
          if (showCount)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '$likesCount',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: tc.textSecondary,
                  fontSize: _countFontSize,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shared square tap target for Mono reader footer icon actions (More + React).
class _FooterReaderIconActionButton extends StatelessWidget {
  static const kSlotSize = 44.0;
  static const kIconSize = 24.0;

  final String semanticsLabel;
  final IconData icon;
  final Color foregroundColor;
  final VoidCallback onPressed;

  const _FooterReaderIconActionButton({
    required this.semanticsLabel,
    required this.icon,
    required this.foregroundColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).colors;
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          splashFactory: NoSplash.splashFactory,
          highlightColor: tc.textPrimary.withValues(alpha: 0.05),
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          borderRadius: BorderRadius.circular(kSlotSize / 2),
          child: SizedBox(
            width: kSlotSize,
            height: kSlotSize,
            child: Center(
              child: Icon(
                icon,
                size: kIconSize,
                color: foregroundColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
