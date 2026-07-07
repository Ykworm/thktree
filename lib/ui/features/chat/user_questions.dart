import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider, InteractiveViewer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/shared/message_bubble.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/widgets/thk_nav_bar.dart';
import 'package:thk_tree/ui/features/chat/chat_controller.dart';

/// 把消息列表按 turn 分组：
///
/// 一条 user 消息开启一个 turn，其后所有 assistant 消息（直到下一条 user 消息）
/// 归入该 turn。开头的 system / 前置 assistant 消息（无对应 user）会被丢弃。
///
/// 定义是代码分组不变量：常见情况是严格的 1 问 1 答（turn 恰好含 1 条 user +
/// 1 条 assistant），但规则不假设中间只有 1 条 assistant，以兼容重试残留 /
/// 工具调用多轮 / 流式分片等异常数据。
List<List<SessionMessage>> groupUserTurns(List<SessionMessage> messages) {
  final turns = <List<SessionMessage>>[];
  for (final m in messages) {
    if (m.role == SessionRole.user) {
      turns.add([m]);
    } else if (turns.isNotEmpty) {
      turns.last.add(m);
    }
  }
  return turns;
}

/// 同时支持 [imageData]（内存字节）与 [imagePath]（本地文件）的图片渲染辅助。
///
/// 优先用内存字节（chat controller 已把磁盘图片加载进 [SessionMessage.imageData]），
/// 退化到本地文件，避免某些场景图片不显示。
class ResolvedImage extends StatelessWidget {
  const ResolvedImage({
    super.key,
    required this.imageData,
    required this.imagePath,
    this.width,
    this.height,
    this.fit,
  });

  final Uint8List? imageData;
  final String? imagePath;
  final double? width;
  final double? height;
  final BoxFit? fit;

  @override
  Widget build(BuildContext context) {
    if (imageData != null) {
      return Image.memory(imageData!, width: width, height: height, fit: fit);
    }
    if (imagePath != null) {
      return Image.file(File(imagePath!), width: width, height: height, fit: fit);
    }
    return const SizedBox.shrink();
  }
}

/// 全屏图片预览页。X（返回）关闭后回到列表。
class UserQuestionImagePreview extends StatelessWidget {
  const UserQuestionImagePreview({
    super.key,
    required this.imageData,
    required this.imagePath,
  });

  final Uint8List? imageData;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black,
        middle: Text(
          AppLocalizations.of(context)!.myQuestionsTitle,
          style: const TextStyle(color: CupertinoColors.white),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(
            CupertinoIcons.back,
            color: CupertinoColors.white,
          ),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: InteractiveViewer(
            child: ResolvedImage(
              imageData: imageData,
              imagePath: imagePath,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

/// 列表项：缩略图（仅含图消息显示、可点开预览）+ 文本预览 + 右箭头。
///
/// 缩略图与"整行进入回复页"是两个独立 tap zone：缩略图是行外的兄弟节点，
/// 点击只触发预览，不会误触进入回复页；其余区域（CupertinoButton）点击进入回复。
class _UserQuestionListTile extends StatelessWidget {
  const _UserQuestionListTile({
    required this.message,
    required this.onOpen,
  });

  final SessionMessage message;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final hasImage = message.hasImage;
    final previewText = message.body.trim().isNotEmpty
        ? message.body
        : (hasImage ? AppLocalizations.of(context)!.myQuestionsTitle : '');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (hasImage)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => UserQuestionImagePreview(
                      imageData: message.imageData,
                      imagePath: message.imagePath,
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ResolvedImage(
                  imageData: message.imageData,
                  imagePath: message.imagePath,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        Expanded(
          child: CupertinoButton(
            padding: EdgeInsets.symmetric(
              horizontal: hasImage ? 0 : 16,
              vertical: 12,
            ),
            onPressed: onOpen,
            child: SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  previewText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Icon(
            AppIcons.chevronRight,
            size: 18,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// 单会话内「我问过的问题」列表页。
///
/// 读取 live 的 chat controller（与 chat 页共享同一 [ChatControllerParams] 实例），
/// 按顺序列出所有 user 提问，旧 → 新。点击进入对应回复页。
class UserQuestionsListPage extends ConsumerStatefulWidget {
  const UserQuestionsListPage({super.key, required this.args});

  final ChatControllerParams args;

  @override
  ConsumerState<UserQuestionsListPage> createState() =>
      _UserQuestionsListPageState();
}

class _UserQuestionsListPageState extends ConsumerState<UserQuestionsListPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final messagesAsync = ref.watch(chatControllerProvider(widget.args));

    return CupertinoPageScaffold(
      navigationBar: ThkNavBar.inline(title: l10n.myQuestionsTitle),
      child: SafeArea(
        child: messagesAsync.when(
          data: (messages) {
            final turns = groupUserTurns(messages);
            if (turns.isEmpty) {
              return Center(
                child: Text(
                  l10n.myQuestionsEmpty,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textTertiary,
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: turns.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final turn = turns[index];
                final userMsg = turn.first;
                return _UserQuestionListTile(
                  message: userMsg,
                  onOpen: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => UserQuestionReplyPage(turn: turn),
                      ),
                    );
                  },
                );
              },
            );
          },
          error: (e, _) => Center(child: Text(e.toString())),
          loading: () => const Center(child: CupertinoActivityIndicator()),
        ),
      ),
    );
  }
}

/// 单条提问的回复页：隔离渲染该 turn（user 消息 + 其后所有 assistant 消息）。
///
/// 复用 [MessageBubble]，不传交互回调（纯阅读态，仍保留复制 / 朗读等只读动作）。
class UserQuestionReplyPage extends StatelessWidget {
  const UserQuestionReplyPage({super.key, required this.turn});

  final List<SessionMessage> turn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return CupertinoPageScaffold(
      navigationBar: ThkNavBar.inline(title: l10n.myQuestionsTitle),
      child: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: turn.length,
          itemBuilder: (context, index) {
            return MessageBubble(
              message: turn[index],
              showTimestamp: index == 0,
            );
          },
        ),
      ),
    );
  }
}
