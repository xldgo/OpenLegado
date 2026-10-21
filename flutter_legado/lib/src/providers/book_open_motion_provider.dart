import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 临时视觉对比选项，仅本次应用运行有效，不写入偏好或备份。— Codex + UI
enum BookOpenMotion {
  top('A：顶边平滑展开'),
  arc('B：中心上拱展开');

  const BookOpenMotion(this.label);
  final String label;
}

final bookOpenMotionProvider =
    NotifierProvider<BookOpenMotionNotifier, BookOpenMotion>(
      BookOpenMotionNotifier.new,
    );

class BookOpenMotionNotifier extends Notifier<BookOpenMotion> {
  @override
  BookOpenMotion build() => BookOpenMotion.arc;

  void select(BookOpenMotion motion) => state = motion;
}
