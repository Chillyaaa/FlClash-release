import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:material_ui/material_ui.dart';

import '../profiles.dart';

/// 文件夹视图：支持将订阅按文件夹/分类组织，折叠/展开展示
class ProfileFolderView extends ConsumerStatefulWidget {
  const ProfileFolderView({
    super.key,
    required this.profiles,
    required this.currentProfileId,
    required this.spacing,
  });

  final List<Profile> profiles;
  final int? currentProfileId;
  final double spacing;

  @override
  ConsumerState<ProfileFolderView> createState() => _ProfileFolderViewState();
}

class _ProfileFolderViewState extends ConsumerState<ProfileFolderView> {
  // 记录每个文件夹的展开状态（默认全部展开）
  final Map<String, bool> _expandedState = {};

  /// 从订阅名称提取文件夹名字
  /// 支持格式：[免费] 节点A、(付费) 节点B、【常用】节点C、@游戏 节点D
  /// 未匹配到的统一归类为 "未分类"
  static String extractFolderName(Profile profile) {
    final label = profile.realLabel.trim();
    final match = RegExp(r'^[\[【\(@](.*?)[\]】\)]').firstMatch(label);
    if (match != null && match.group(1) != null) {
      final name = match.group(1)!.trim();
      if (name.isNotEmpty) return name;
    }
    return '未分类';
  }

  /// 获取纯净的订阅显示名称（去除文件夹前缀）
  static String cleanProfileLabel(Profile profile) {
    final label = profile.realLabel.trim();
    return label.replaceFirst(RegExp(r'^[\[【\(@].*?[\]】\)]\s*'), '').trim();
  }

  Map<String, List<Profile>> _getGroupedProfiles() {
    final Map<String, List<Profile>> groups = {};
    for (final profile in widget.profiles) {
      final folder = extractFolderName(profile);
      groups.putIfAbsent(folder, () => []).add(profile);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _getGroupedProfiles();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView.builder(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: context.contentTopPadding,
        bottom: 16 + context.bottomInset,
      ),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final folderName = groups.keys.elementAt(index);
        final folderProfiles = groups[folderName]!;
        final isExpanded = _expandedState[folderName] ?? true;

        // 当前选中的活动节点是否位于该文件夹内
        final hasActiveProfile = folderProfiles.any((p) => p.id == widget.currentProfileId);

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          elevation: 0,
          color: colorScheme.surfaceVariant.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: hasActiveProfile
                  ? colorScheme.primary.withOpacity(0.55)
                  : colorScheme.outlineVariant.withOpacity(0.3),
              width: hasActiveProfile ? 1.5 : 1.0,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- 文件夹头部栏 ---
              InkWell(
                onTap: () {
                  setState(() {
                    _expandedState[folderName] = !isExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        isExpanded ? Icons.folder_open_rounded : Icons.folder_rounded,
                        color: hasActiveProfile ? colorScheme.primary : colorScheme.onSurfaceVariant,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                folderName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: hasActiveProfile ? colorScheme.primary : null,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 订阅计数药丸
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: hasActiveProfile
                                    ? colorScheme.primaryContainer
                                    : colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${folderProfiles.length}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: hasActiveProfile
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 旋转折叠箭头
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: colorScheme.onSurfaceVariant,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- 展开后的订阅卡片网格 ---
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                firstChild: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: WidthBuilder(
                    builder: (context, width) {
                      final columns = getProfilesColumns(
                        width - 24,
                        spacing: widget.spacing,
                        minItemWidth: profileItemMinWidth.ap(context),
                      );

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: widget.spacing,
                          crossAxisSpacing: widget.spacing,
                          mainAxisExtent: profileItemHeight,
                        ),
                        itemCount: folderProfiles.length,
                        itemBuilder: (context, pIndex) {
                          final profile = folderProfiles[pIndex];
                          // 在文件夹内展示时自动去除前缀，呈现清爽标题
                          final displayProfile = profile.copyWith(
                            label: cleanProfileLabel(profile),
                          );
                          return ProfileItem(
                            key: ValueKey(profile.id),
                            profile: displayProfile,
                            groupValue: widget.currentProfileId,
                            onChanged: (profileId) {
                              ref.read(currentProfileIdProvider.notifier).value = profileId;
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                secondChild: const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}
