import 'package:flutter/cupertino.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

/// Material Icons → SF Symbols 映射
///
/// 使用 SFIcons 提供 IconData，可通过 Icon() 或 SFIcon() 渲染。
/// 后续 PR 迁移 features/ 时替换 Icons.xxx 为 AppIcons.xxx。
class AppIcons {
  AppIcons._();

  // ── 通用操作 ──

  /// Icons.add
  static const IconData add = SFIcons.sf_plus;

  /// Icons.close
  static const IconData close = SFIcons.sf_xmark;

  /// Icons.check
  static const IconData check = SFIcons.sf_checkmark;

  /// Icons.check_circle
  static const IconData checkCircle = SFIcons.sf_checkmark_circle_fill;

  /// Icons.delete / Icons.delete_outline
  static const IconData delete = SFIcons.sf_trash;

  /// Icons.edit
  static const IconData edit = SFIcons.sf_pencil;

  /// Icons.copy
  static const IconData copy = SFIcons.sf_square_on_square;

  /// Icons.refresh
  static const IconData refresh = SFIcons.sf_arrow_clockwise;

  /// Icons.search
  static const IconData search = SFIcons.sf_magnifyingglass;

  /// Icons.more_vert
  static const IconData more = SFIcons.sf_ellipsis;

  // ── 导航 ──

  /// Icons.arrow_back
  static const IconData back = SFIcons.sf_chevron_left;

  /// Icons.chevron_right
  static const IconData chevronRight = SFIcons.sf_chevron_right;

  /// Icons.chevron_left
  static const IconData chevronLeft = SFIcons.sf_chevron_left;

  // ── 通信 / 聊天 ──

  /// Icons.send (iOS 风格发送)
  static const IconData send = SFIcons.sf_arrow_up_circle_fill;

  /// Icons.stop
  static const IconData stop = SFIcons.sf_stop_circle_fill;

  /// Icons.chat / Icons.chat_bubble_outline
  static const IconData chat = SFIcons.sf_bubble_left;

  /// Icons.forum
  static const IconData forum = SFIcons.sf_bubble_left_and_bubble_right;

  /// 模型选择入口（带加号的圆形图标）
  static const IconData modelSelector = SFIcons.sf_plus_circle_fill;

  // ── 内容 / 文件 ──

  /// Icons.note / Icons.description
  static const IconData note = SFIcons.sf_list_clipboard;

  /// Icons.folder
  static const IconData folder = SFIcons.sf_folder;

  /// Icons.download
  static const IconData download = SFIcons.sf_square_and_arrow_down;

  /// Share (square.and.arrow.up)
  static const IconData share = SFIcons.sf_square_and_arrow_up;

  /// Icons.star
  static const IconData star = SFIcons.sf_star;

  // ── 设置 / 提供商 ──

  /// Icons.settings
  static const IconData settings = SFIcons.sf_gearshape;

  /// Icons.extension
  static const IconData extensionIcon = SFIcons.sf_puzzlepiece_extension;

  /// Icons.cloud
  static const IconData cloud = SFIcons.sf_cloud;

  /// 语言 (globe)
  static const IconData globe = SFIcons.sf_globe;

  /// Cloud fill (remote logging on)
  static const IconData cloudFill = SFIcons.sf_cloud_fill;

  /// Document (view logs)
  static const IconData document = SFIcons.sf_document;

  /// Moon fill (dark mode on)
  static const IconData moonFill = SFIcons.sf_moon_fill;

  /// Sun max fill (dark mode off)
  static const IconData sunMaxFill = SFIcons.sf_sun_max_fill;

  /// Lock shield (Face ID)
  static const IconData lockShield = SFIcons.sf_lock_shield;

  // ── 树 / 分支 ──

  /// Icons.account_tree / Icons.account_tree_outlined
  static const IconData accountTree = SFIcons.sf_circle_hexagonpath;

  /// Icons.call_split
  static const IconData callSplit = SFIcons.sf_arrow_turn_down_right;

  /// Icons.subdirectory_arrow_right
  static const IconData subdirectoryArrowRight =
      SFIcons.sf_arrow_turn_down_right;

  /// 分支操作（iOS 风格的分支箭头）
  static const IconData branch = SFIcons.sf_arrow_trianglehead_branch;

  /// AI / 模型选择（iOS 18+ AI 风格闪光图标）
  static const IconData sparkles = SFIcons.sf_sparkles;

  /// 实验室 tab 占位 icon（flask，iOS 14+）
  /// 后续迭代可换为 SVG（参考主题 tab 的 theme_unselect.svg 模式）
  static const IconData lab = SFIcons.sf_flask;

  // ── TTS（语音播放） ──

  /// 滚动到顶部（用于 player 页浮按钮）
  static const IconData chevronUp = SFIcons.sf_chevron_up;

  /// TTS 播放按钮·空闲态（play.fill 三角形）— 主播放器大按钮
  static const IconData ttsPlay = SFIcons.sf_play_fill;

  /// TTS 播放按钮·播放中态（pause.fill 两竖）— 主播放器大按钮
  static const IconData ttsPause = SFIcons.sf_pause_fill;

  /// 朗读入口·空闲态（speaker.wave.2.fill 喇叭）— chat 气泡小按钮
  /// 设计意图见 docs/modules/chat/design-tokens.yaml
  static const IconData ttsSpeak = SFIcons.sf_speaker_wave_2_fill;

  /// 语速·慢（tortoise.fill，iOS 17+）
  static const IconData ttsSlow = SFIcons.sf_tortoise_fill;

  /// 语速·快（hare.fill，iOS 17+）
  static const IconData ttsFast = SFIcons.sf_hare_fill;
}
