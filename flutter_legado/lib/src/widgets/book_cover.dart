import '../providers/media_provider.dart';
import '../features/book_sources/book_source_repository_provider.dart';

import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter/rendering.dart'
    show RenderClipRRect, RenderImage, RenderObject;

import '../services/cover_decode_loader.dart';
import '../utils/comic_image_utils.dart';

/// 书籍封面组件 — 支持网络图片 + 默认封面 + coverDecodeJs 解密
///
/// 无封面 / 加载中 / 加载失败时显示默认封面图（assets/images/default_book_cover.jpg，
/// 对标原版 res/drawable/image_cover_default.jpg）。
///
/// 对齐原版 `CoverImageView` + Glide 列表行为：
/// - 无 `coverDecodeJs`：`CachedNetworkImageProvider` 直连（限制解码宽度）
/// - 有 `coverDecodeJs`：经 [CoverDecodeLoader] 限流/缓存/取消后走 FFI
///
/// [UI-FIX v2.0.32 | 2026-08-11] 搜索列表封面解密卡顿 — Reasonix + UI
class BookCover extends ConsumerWidget {
  final String? coverUrl;
  final double width;
  final double height;
  final double borderRadius;

  /// 书源 origin（用于拉取 coverDecodeJs / header）
  final String? sourceOrigin;

  /// 已序列化的书源 JSON（优先于 [sourceOrigin] 查询）
  final String? sourceJson;

  /// Hero 过渡标签（书架↔详情封面过渡，UI_MD3_PLAN.md Batch 1；
  /// 约定 `cover:<book url>`，空/null 不启用 Hero）
  final String? heroTag;

  const BookCover({
    super.key,
    this.coverUrl,
    this.width = 80,
    this.height = 110,
    this.borderRadius = 4,
    this.sourceOrigin,
    this.sourceJson,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget cover = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: (coverUrl != null && coverUrl!.isNotEmpty)
            ? _CoverImage(
                coverUrl: coverUrl!,
                width: width,
                sourceOrigin: sourceOrigin,
                sourceJson: sourceJson,
                placeholder: _defaultCover(),
              )
            : _defaultCover(),
      ),
    );
    final tag = heroTag;
    if (tag != null && tag.isNotEmpty) {
      cover = BookCoverHero(tag: tag, child: cover);
    }
    return cover;
  }

  /// 默认封面（对标原版 image_cover_default.jpg）：无封面 / 加载中 / 加载失败时显示
  Widget _defaultCover() {
    return Image.asset(
      'assets/images/default_book_cover.jpg',
      fit: BoxFit.cover,
      width: width,
      height: height,
    );
  }
}

/// 封面两端保留同一图片子树，飞行期间不重新开始加载或解密。
class BookCoverHero extends StatefulWidget {
  const BookCoverHero({super.key, required this.tag, required this.child});

  final Object tag;
  final Widget child;

  @override
  State<BookCoverHero> createState() => _BookCoverHeroState();
}

class _BookCoverHeroState extends State<BookCoverHero> {
  final _contentKey = GlobalKey();

  @override
  Widget build(BuildContext context) => Hero(
    tag: widget.tag,
    flightShuttleBuilder: coverFlightShuttleBuilder,
    // SDK 的占位与正常内容处在不同包装层，局部 key 保留图片加载状态。
    child: KeyedSubtree(key: _contentKey, child: widget.child),
    placeholderBuilder: (_, size, child) => SizedBox.fromSize(
      size: size,
      child: Offstage(child: TickerMode(enabled: false, child: child)),
    ),
  );
}

/// 读取当前绘制的封面帧，不把有加载状态的 Widget 再挂到飞行层。
({ui.Image? image, BorderRadius radius}) _coverFrame(BuildContext context) {
  ui.Image? image;
  BorderRadius? radius;
  final direction = Directionality.of(context);
  void visit(RenderObject object) {
    if (object is RenderClipRRect && radius == null) {
      radius = object.borderRadius.resolve(object.textDirection ?? direction);
    }
    if (object is RenderImage && object.image != null) {
      image = object.image;
    }
    object.visitChildren(visit);
  }

  final root = context.findRenderObject();
  if (root != null) visit(root);
  // 网格封面的内层可能没有圆角，实际裁剪来自外层卡片。
  if (radius == null || radius == BorderRadius.zero) {
    final outer = context.findAncestorRenderObjectOfType<RenderClipRRect>();
    radius =
        outer?.borderRadius.resolve(outer.textDirection ?? direction) ?? radius;
  }
  return (image: image, radius: radius ?? BorderRadius.zero);
}

/// 复用出发侧已解码的图片帧，进出动画都不显示新的加载占位。
Widget coverFlightShuttleBuilder(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final from = _coverFrame(fromHeroContext);
  final to = _coverFrame(toHeroContext);
  return _BookCoverFlight(
    image: from.image,
    fromRadius: from.radius,
    toRadius: to.radius,
    animation: animation,
    direction: flightDirection,
  );
}

class _BookCoverFlight extends StatefulWidget {
  const _BookCoverFlight({
    required this.image,
    required this.fromRadius,
    required this.toRadius,
    required this.animation,
    required this.direction,
  });

  final ui.Image? image;
  final BorderRadius fromRadius;
  final BorderRadius toRadius;
  final Animation<double> animation;
  final HeroFlightDirection direction;

  @override
  State<_BookCoverFlight> createState() => _BookCoverFlightState();
}

class _BookCoverFlightState extends State<_BookCoverFlight> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    // clone 只保留同一像素资源的独立引用，不复制像素或重新解码。
    _image = widget.image?.clone();
  }

  @override
  void didUpdateWidget(_BookCoverFlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.image, widget.image)) {
      final previous = _image;
      _image = widget.image?.clone();
      previous?.dispose();
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.animation,
    builder: (_, child) {
      final progress = widget.direction == HeroFlightDirection.push
          ? widget.animation.value
          : 1.0 - widget.animation.value;
      return ClipRRect(
        borderRadius: BorderRadius.lerp(
          widget.fromRadius,
          widget.toRadius,
          progress,
        )!,
        child: child,
      );
    },
    child: _image == null
        ? Image.asset('assets/images/default_book_cover.jpg', fit: BoxFit.cover)
        : RawImage(image: _image, fit: BoxFit.cover),
  );
}

class _CoverImage extends ConsumerStatefulWidget {
  final String coverUrl;
  final double width;
  final String? sourceOrigin;
  final String? sourceJson;
  final Widget placeholder;

  const _CoverImage({
    required this.coverUrl,
    required this.width,
    required this.placeholder,
    this.sourceOrigin,
    this.sourceJson,
  });

  @override
  ConsumerState<_CoverImage> createState() => _CoverImageState();
}

/// 图片来源先同步选路，再交给同一个 Image 消费 Flutter 的图片缓存。— Codex + UI
class _CoverImageState extends ConsumerState<_CoverImage> {
  ImageProvider? _provider;
  bool _hasFrame = false;
  int _loadGen = 0;
  int _sourceRevision = 0;
  CoverDecodeTicket? _ticket;

  @override
  void initState() {
    super.initState();
    unawaited(_startLoad());
  }

  @override
  void dispose() {
    _loadGen++;
    _ticket?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _CoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl != widget.coverUrl ||
        oldWidget.sourceOrigin != widget.sourceOrigin ||
        oldWidget.sourceJson != widget.sourceJson ||
        _sourceRevision != CoverDecodeLoader.sourceRevision) {
      _ticket?.cancel();
      _ticket = null;
      unawaited(_startLoad());
    }
  }

  ImageProvider? _cachedOrDirectProvider(String patched) {
    final origin = widget.sourceOrigin?.trim() ?? '';
    final url = widget.coverUrl;
    final cached = CoverDecodeLoader.getCached(
      origin,
      url,
      patchedSourceJson: patched,
    );
    if (cached != null) return MemoryImage(cached);
    if (CoverDecodeLoader.needsFfiDecode(
      coverUrl: url,
      patchedSourceJson: patched,
    )) {
      return null;
    }
    return CachedNetworkImageProvider(
      stripCompositeImageUrl(url),
      cacheKey: CoverDecodeLoader.cacheKey(
        origin,
        url,
        patchedSourceJson: patched,
      ),
    );
  }

  Future<void> _startLoad() async {
    final gen = ++_loadGen;
    _sourceRevision = CoverDecodeLoader.sourceRevision;
    _provider = null;
    _hasFrame = false;
    var patched = CoverDecodeLoader.peekPatchedSourceJson(
      sourceJson: widget.sourceJson,
      sourceOrigin: widget.sourceOrigin,
    );
    if (patched != null) {
      _provider = _cachedOrDirectProvider(patched);
      if (_provider != null) return;
    }

    try {
      patched ??=
          await CoverDecodeLoader.resolvePatchedSourceJson(
            sources: ref.read(bookSourceRepositoryProvider),
            sourceJson: widget.sourceJson,
            sourceOrigin: widget.sourceOrigin,
          ) ??
          '';
      if (!mounted || gen != _loadGen) return;
      var provider = _cachedOrDirectProvider(patched);
      if (provider == null) {
        final bytes = await CoverDecodeLoader.load(
          images: ref.read(bookImageRepositoryProvider),
          coverUrl: widget.coverUrl,
          patchedSourceJson: patched,
          originOrEmpty: widget.sourceOrigin?.trim() ?? '',
          isCancelled: () => gen != _loadGen || !mounted,
          onTicket: (ticket) {
            if (!mounted || gen != _loadGen) {
              ticket?.cancel();
            } else {
              _ticket = ticket;
            }
          },
        );
        if (!mounted || gen != _loadGen) return;
        if (bytes != null) provider = MemoryImage(bytes);
      }
      setState(() => _provider = provider);
    } catch (e) {
      debugPrint('封面加载失败: $e');
      if (!mounted || gen != _loadGen) return;
      setState(() => _provider = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    if (provider == null) return widget.placeholder;
    final pixelRatio = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    final thumb = (widget.width * pixelRatio).round().clamp(1, 512);
    return Image(
      // 只在真实来源变化时重置帧，宽度或选择态变化沿用现有图片。
      key: ValueKey((
        widget.coverUrl,
        widget.sourceOrigin,
        widget.sourceJson,
        _sourceRevision,
      )),
      image: ResizeImage.resizeIfNeeded(thumb, null, provider),
      fit: BoxFit.cover,
      width: widget.width,
      gaplessPlayback: true,
      frameBuilder: (_, child, frame, synchronous) {
        // 同一来源只改变缩略尺寸时，gaplessPlayback 仍持有上一帧。
        _hasFrame = _hasFrame || synchronous || frame != null;
        return _hasFrame ? child : widget.placeholder;
      },
      errorBuilder: (_, _, _) => widget.placeholder,
    );
  }
}
