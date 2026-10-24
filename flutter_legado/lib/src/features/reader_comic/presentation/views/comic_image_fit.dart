import 'package:flutter/widgets.dart';

import '../../../../models/manga_page_scale_type.dart';

/// 智能适配读取正式ImageProvider的尺寸，和图片展示共用解码缓存。
/// 只保留宽窄分类，不另存像素或修改图片获取链。— Codex + UI
class ComicImageFit extends StatefulWidget {
  const ComicImageFit({
    super.key,
    required this.image,
    required this.fit,
    required this.smartFit,
    required this.builder,
    this.onReady,
  });
  final ImageProvider image;
  final VoidCallback? onReady;
  final BoxFit fit;
  final bool smartFit;
  final Widget Function(BoxFit fit) builder;

  static BoxFit forSize(BoxFit fallback, bool smart, int width, int height) =>
      smart
      ? MangaPageScaleType.fitFor(
          type: MangaPageScaleType.smartFit,
          isWidePage: width > height,
        )
      : fallback;

  @override
  State<ComicImageFit> createState() => _ComicImageFitState();
}

class _ComicImageFitState extends State<ComicImageFit> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  bool _wide = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ComicImageFit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image != oldWidget.image ||
        widget.smartFit != oldWidget.smartFit) {
      _wide = false;
      _resolve();
    }
  }

  void _resolve() {
    _unsubscribe();
    if (!widget.smartFit && widget.onReady == null) return;
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    _stream = stream;
    _listener = ImageStreamListener(
      (info, synchronous) {
        final wide = info.image.width > info.image.height;
        info.dispose();
        if (wide != _wide) setState(() => _wide = wide);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onReady?.call();
        });
      },
      // 正式Image仍负责展示原有失败占位及重试。
      onError: (Object error, StackTrace? stack) {},
    );
    stream.addListener(_listener!);
  }

  void _unsubscribe() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    widget.smartFit
        ? MangaPageScaleType.fitFor(
            type: MangaPageScaleType.smartFit,
            isWidePage: _wide,
          )
        : widget.fit,
  );
}
