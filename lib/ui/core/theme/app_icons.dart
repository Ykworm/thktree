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

  // ── 内容 / 文件 ──

  /// Icons.note / Icons.description
  static const IconData note = SFIcons.sf_list_clipboard;

  /// Icons.folder
  static const IconData folder = SFIcons.sf_folder;

  /// Icons.download
  static const IconData download = SFIcons.sf_square_and_arrow_down;

  /// Icons.star
  static const IconData star = SFIcons.sf_star;

  // ── 设置 / 提供商 ──

  /// Icons.settings
  static const IconData settings = SFIcons.sf_gearshape;

  /// Icons.extension
  static const IconData extensionIcon = SFIcons.sf_puzzlepiece_extension;

  /// Icons.cloud
  static const IconData cloud = SFIcons.sf_cloud;

  // ── 树 / 分支 ──

  /// Icons.account_tree / Icons.account_tree_outlined
  static const IconData accountTree = SFIcons.sf_circle_hexagonpath;

  /// Icons.call_split
  static const IconData callSplit = SFIcons.sf_arrow_turn_down_right;

  /// Icons.subdirectory_arrow_right
  static const IconData subdirectoryArrowRight =
      SFIcons.sf_arrow_turn_down_right;
}
