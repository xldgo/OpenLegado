import 'package:flutter/widgets.dart';

import '../../../l10n/app_localization.dart';
import '../../../models/models.dart';
import '../bookshelf_state.dart';

/// 内置分类只翻译显示名称，不回写数据；自定义分组保留用户原名。
String bookshelfGroupLabel(BuildContext context, BookGroup group) =>
    switch (group.groupId) {
      BookGroupId.all => context.l10n.allBooks,
      BookGroupId.local => context.l10n.localBooks,
      BookGroupId.audio => context.l10n.audioBooks,
      BookGroupId.video => context.l10n.videoBooks,
      BookGroupId.netNone => context.l10n.ungroupedOnlineBooks,
      BookGroupId.localNone => context.l10n.ungroupedLocalBooks,
      _ => group.groupName,
    };
