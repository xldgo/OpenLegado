import '../../../../theme/app_motion.dart';
import 'comic_image_fit.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/services/comic_image_decode_cache.dart';
import '../../../../domain/contracts/book_image_repository.dart';
import '../../../../domain/contracts/local_book_service.dart';
import '../../../../domain/contracts/network_service.dart';
import '../../../../models/models.dart';
import '../../../../utils/comic_image_utils.dart';
import '../../../../utils/manga_epaper.dart';
import '../../../../widgets/app_progress_indicator.dart';

/// 漫画图片项：分发字节来源、加载/重试、缩放适配及图像效果。— Codex + UI
class ComicImageItem extends StatelessWidget {
  const ComicImageItem({
    super.key,
    required this.url,
    required this.book,
    required this.source,
    required this.bookUrl,
    required this.images,
    required this.localBooks,
    required this.network,
    required this.failed,
    required this.headers,
    required this.fit,
    this.smartFit = false,
    this.onReady,
    required this.colorFilter,
    required this.enableEInk,
    required this.eInkThreshold,
    required this.disableCrossFade,
    required this.onError,
    required this.onRetry,
    required this.onLongPress,
  });
  final String url, bookUrl;
  final Book? book;
  final BookSource? source;
  final BookImageRepository images;
  final LocalBookService localBooks;
  final NetworkService network;
  final bool failed, enableEInk, disableCrossFade;
  final int eInkThreshold;
  final Map<String, String> headers;
  final BoxFit fit;
  final bool smartFit;
  final VoidCallback? onReady;
  final ColorFilter? colorFilter;
  final VoidCallback onError, onRetry, onLongPress;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onLongPress: onLongPress,
    child: _buildImageWithContext(context),
  );

  Widget _wrapImageFilter(Widget child) => colorFilter == null
      ? child
      : ColorFiltered(colorFilter: colorFilter!, child: child);

  /// 图片项本体（占位 / FFI 解码 / 直连网络分发）
  Widget _buildImageWithContext(BuildContext context) {
    final book = this.book;
    final source = this.source;
    final isFailed = failed;

    if (isFailed) {
      // 图片加载失败，显示重试按钮
      return _buildImageErrorPlaceholder(context);
    }

    // [cbz 批 D | 2026-10-03] 本地 cbz 页：`cbz://<条目名>` 伪 URL 优先于
    // 书源判定分发（本地书 origin=loc_book，source 恒 null；若落下方
    //「有 origin 却未命中书源」分支会直接进失败占位）。
    // 渲染挂接与 _DecodedComicImage 同构：_wrapImageFilter（灰度/色彩滤镜
    // 外层包裹）与可选电子纸；只有新图片首帧就绪后淡入，缓存直接显示。
    if (url.startsWith('cbz://')) {
      if (book == null) {
        return _buildImageErrorPlaceholder(context);
      }
      return _wrapImageFilter(
        _LocalCbzImage(
          localBooks: localBooks,
          crossFade: !disableCrossFade,
          path: book.bookUrl,
          entry: url,
          // 缓存键 = 活跃 bookUrl（本地书无书源；bookUrl 唯一标识 cbz 包，
          // 避免不同包同名条目命中同一内存缓存）
          cacheKey: bookUrl,
          // [P4-3 E2] 分页适配类型映射的 BoxFit（条漫恒 fitWidth）
          fit: fit,
          smartFit: smartFit,
          onReady: onReady,
          eInkThreshold: enableEInk ? eInkThreshold : null,
          onError: onError,
        ),
      );
    }

    // 统一走 FFI 下载：Rust fetchImageWithDecode 支持书源 header 防盗链与
    // `url,{json headers}` 复合格式（favcomic 等漫画站图片 URL 内嵌防盗链
    // header，对齐原版 AnalyzeUrl），且无 imageDecode 规则时原样返回 bytes。
    // CachedNetworkImage 直连无法解析复合 URL / 会把 AES 密文送进
    // FlutterImageDecoder →「图片加载失败」（51漫画设备实测）。
    // 漫画阅读器只要能解析到书源就禁止直连 CDN。— Reasonix
    if (source != null) {
      return _wrapImageFilter(
        _DecodedComicImage(
          images: images,
          crossFade: !disableCrossFade,
          url: url,
          sourceJson: jsonEncode(source.toJson()),
          bookSourceUrl: book!.origin,
          // [P4-3 M3 修2] 活跃 bookUrl（磁盘缓存目录键随换源切换）
          bookUrl: bookUrl,
          // [P4-3 E2] 分页适配类型映射的 BoxFit（条漫恒 fitWidth）
          fit: fit,
          smartFit: smartFit,
          onReady: onReady,
          eInkThreshold: enableEInk ? eInkThreshold : null,
          onError: onError,
        ),
      );
    }
    // 有 origin 却未命中书源：勿直连（密文/防盗链），直接失败可重试
    if (book != null && book.origin.isNotEmpty) {
      return _buildImageErrorPlaceholder(context);
    }

    if (enableEInk) {
      return _EpaperNetworkImage(
        network: network,
        url: url,
        headers: headers,
        threshold: eInkThreshold,
        // [P4-3 E2] 分页适配类型映射的 BoxFit（条漫恒 fitWidth）
        fit: fit,
        smartFit: smartFit,
        onReady: onReady,
        onError: onError,
      );
    }

    return _wrapImageFilter(
      CachedNetworkImage(
        imageUrl: url,
        fadeInDuration: disableCrossFade || AppMotion.reduced(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        fadeOutDuration: Duration.zero,
        httpHeaders: headers, // 防盗链 header（对齐原版）— Reasonix
        // [P4-3 E2] 分页适配类型映射的 BoxFit（条漫恒 fitWidth）
        fit: fit,
        width: double.infinity,
        imageBuilder: (context, provider) => ComicImageFit(
          image: provider,
          fit: fit,
          smartFit: smartFit,
          onReady: onReady,
          builder: (effectiveFit) =>
              Image(image: provider, fit: effectiveFit, width: double.infinity),
        ),
        // 漫画页按屏宽全分辨率显示，不限制 memCacheWidth（磁盘缓存默认开启）
        progressIndicatorBuilder: (context, _, progress) =>
            _buildImageLoadingPlaceholder(context, progress.progress),
        errorWidget: (context, _, _) => _buildImageErrorPlaceholder(context),
        errorListener: (_) => onError(),
      ),
    );
  }

  /// 图片加载占位符（骨架屏效果，[progress] 为下载进度 0.0~1.0）
  Widget _buildImageLoadingPlaceholder(BuildContext context, double? progress) {
    // [STAGE-UI-P43UNIFY1 B2] 加载态去整面硬编码底色：参考版 #2082 后
    // MangaImageLoadOverlay loading 分支不再整页压黑（MangaReaderScreen.kt
    // 1618-1647 注释），我方同步去除 0xFF1A1A1A 整面底色
    final colorScheme = Theme.of(context).colorScheme;
    // 保留 Container 作 widget 测试取证位（断言 color == null 即证明
    // 「加载态无整面硬编码底色」，B2 测试依赖），故不以 SizedBox 替换
    // ignore: sized_box_for_whitespace
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 骨架屏动画效果
            // [STAGE-UI-P43UNIFY1 B2] 块底 0xFF2A2A2A → 主题槽
            // surfaceContainerHighest（参考版 SkeletonPlaceholders.kt:54-56
            // 骨架块 surfaceContainerHighest→High→Highest 级联取证 + 我方
            // SkeletonBox 同口径；参考版漫画场景无骨架（grep 零命中），
            // 「同场景固定深灰」不可证 → 按主题槽等价表达）
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              // [STAGE-UI-P43UNIFY1 B1] 图标位改真实素材图：参考版图片加载
              // 形态直接显示该素材（ImageProvider.kt:39 errorBitmap =
              // R.drawable.image_loading_error；调研报告 §2.4），我方此前用
              // Icons.image 图标代替 → 统一为同名素材（字节级一致）
              child: Image.asset(
                'assets/images/image_loading_error.png',
                width: 64,
                height: 64,
              ),
            ),
            const SizedBox(height: 16),
            // 进度条
            // [STAGE-UI-P43UNIFY1 B2] 轨 0xFF2A2A2A → surfaceContainerHighest、
            // 填充 0xFF666666 → 主题槽 primary
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: 8),
              // [STAGE-UI-P43UNIFY1 B2] % 文案 0xFF888888 → 主题槽 onSurfaceVariant
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 图片加载失败占位符（显示重试按钮）
  Widget _buildImageErrorPlaceholder(BuildContext context) {
    // [STAGE-UI-P43UNIFY1 B1] 底色 0xFF1A1A1A → 55% 黑：参考版失败态为
    // Color.Black.copy(alpha = 0.55f) 整面覆盖（MangaReaderScreen.kt
    // MangaImageLoadOverlay failed 分支，调研报告 §2.5）
    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // [STAGE-UI-P43UNIFY1 B1] 同 B1 素材图（参考版失败占位即该素材，
            // 调研报告 §2.4）
            Image.asset(
              'assets/images/image_loading_error.png',
              width: 64,
              height: 64,
            ),
            const SizedBox(height: 12),
            // [STAGE-UI-P43UNIFY2 B4] 文案 0xFF888888 → 主题槽 onSurfaceVariant
            Text(
              '图片加载失败',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            // [STAGE-UI-P43UNIFY2 B4] 重试按钮 0xFF444444 硬编码底色 → MD3
            // 主题化 OutlinedButton（对齐参考版 MangaImageLoadOverlay 失败分支的
            // MediumOutlinedButton，SeriesButton Outlined 风格，调研报告 §2.5）
            OutlinedButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MangaImageFade extends StatefulWidget {
  final Widget child;

  const _MangaImageFade({required this.child});

  @override
  State<_MangaImageFade> createState() => _MangaImageFadeState();
}

class _MangaImageFadeState extends State<_MangaImageFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _ctrl.value = 1;
    } else if (!_ctrl.isCompleted && !_ctrl.isAnimating) {
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      key: const ValueKey('mangaImageFade'),
      opacity: _ctrl,
      child: widget.child,
    );
  }
}

class _DecodedComicImage extends StatefulWidget {
  final bool crossFade;
  final String url;
  final String sourceJson;
  final BookImageRepository images;
  final String bookSourceUrl;

  /// 书籍 URL（图片磁盘缓存目录按书隔离，契约 §2.46）— P4-2a
  final String bookUrl;
  final VoidCallback onError;

  /// 非 null 时做真像素电子纸二值化（对齐 EpaperTransformation）
  final int? eInkThreshold;

  /// [P4-3 E2] 图片渲染 BoxFit（调用方按分页适配类型映射传入，
  /// 条漫恒 fitWidth；见 [MangaPageScaleType.fitFor] 取证注释）
  final BoxFit fit;
  final bool smartFit;
  final VoidCallback? onReady;

  const _DecodedComicImage({
    required this.images,
    required this.crossFade,
    required this.url,
    required this.sourceJson,
    required this.bookSourceUrl,
    required this.bookUrl,
    required this.onError,
    this.eInkThreshold,
    this.fit = BoxFit.fitWidth,
    this.smartFit = false,
    this.onReady,
  });

  @override
  State<_DecodedComicImage> createState() => _DecodedComicImageState();
}

class _DecodedComicImageState extends State<_DecodedComicImage> {
  bool _loading = true;
  bool _fadeOnLoad = true;
  Uint8List? _bytes;
  ui.Image? _epaperImage;
  String? _error;

  @override
  void initState() {
    super.initState();
    final hit = ComicImageDecodeCache.get(widget.bookSourceUrl, widget.url);
    if (hit != null) {
      _bytes = hit;
      _fadeOnLoad = false;
      _loading = false;
      unawaited(_applyEpaperIfNeeded(hit));
    } else {
      unawaited(_load());
    }
  }

  @override
  void didUpdateWidget(covariant _DecodedComicImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eInkThreshold != widget.eInkThreshold && _bytes != null) {
      unawaited(_applyEpaperIfNeeded(_bytes!));
    }
  }

  @override
  void dispose() {
    _epaperImage?.dispose();
    super.dispose();
  }

  Future<void> _applyEpaperIfNeeded(Uint8List bytes) async {
    final thr = widget.eInkThreshold;
    if (thr == null) {
      _epaperImage?.dispose();
      if (mounted) setState(() => _epaperImage = null);
      return;
    }
    try {
      final img = await mangaEpaperFromBytes(bytes, threshold: thr);
      if (!mounted) {
        img.dispose();
        return;
      }
      _epaperImage?.dispose();
      setState(() => _epaperImage = img);
    } catch (e) {
      debugPrint('电子纸二值化失败: $e');
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final images = widget.images;
      // [P4-2a | 契约 §2.46] 图片磁盘缓存优先（对齐原版 MangaVH.mangaImagePath
      // 本地优先语义）：命中 → 直接本地字节渲染，跳过网络解码链；未命中/
      // 读失败降级走下方网络链路（读失败已由 Rust 侧降级 null，不影响在线）。
      final cached = await images.getImageCache(widget.bookUrl, widget.url);
      if (cached != null && cached.isNotEmpty && looksLikeImageBytes(cached)) {
        final cachedBytes = cached is Uint8List
            ? cached
            : Uint8List.fromList(cached);
        if (!mounted) return;
        ComicImageDecodeCache.put(
          widget.bookSourceUrl,
          widget.url,
          cachedBytes,
        );
        setState(() {
          _bytes = cachedBytes;
          _fadeOnLoad = false;
          _loading = false;
        });
        await _applyEpaperIfNeeded(cachedBytes);
        return;
      }
      final bytes = await images.fetchImageWithDecode(
        widget.url,
        widget.sourceJson,
      );
      if (bytes.isEmpty) {
        throw Exception('解码结果为空（imageDecode 未返回有效图片数据）');
      }
      if (!looksLikeImageBytes(bytes)) {
        throw Exception('解码结果不是有效图片（可能 imageDecode/createSymmetricCrypto 失败）');
      }
      if (!mounted) return;
      ComicImageDecodeCache.put(widget.bookSourceUrl, widget.url, bytes);
      // [P4-2a] 网络成功后回写磁盘缓存：fire-and-forget，写失败静默降级
      // （不影响在线加载，对齐原版 saveImage catch 仅记日志不抛异常语义）
      unawaited(_saveDiskCache(images, bytes));
      setState(() {
        _bytes = bytes;
        _fadeOnLoad = true;
        _loading = false;
      });
      await _applyEpaperIfNeeded(bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
      widget.onError();
    }
  }

  /// [P4-2a | 契约 §2.46] 将图片字节写入磁盘缓存（fire-and-forget）。
  ///
  /// 写盘失败/输入非法时 `saveImageCache` 返回 false（Rust 侧静默降级），
  /// 此处再兜底捕获任何异常——缓存是加速器不是数据源，失败必须不影响
  /// 在线加载（对齐原版 `BookHelp.saveImage` catch 仅记日志语义）。
  Future<void> _saveDiskCache(
    BookImageRepository images,
    List<int> bytes,
  ) async {
    try {
      await images.saveImageCache(
        bookUrl: widget.bookUrl,
        url: widget.url,
        bytes: bytes,
      );
    } catch (_) {
      // 磁盘缓存写失败静默降级：不影响在线加载（契约 §2.46 降级语义）
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      // [STAGE-UI-P43UNIFY1 B2] 加载态：去整面 0xFF1A1A1A 底色（参考版 #2082
      // 不整页压黑）；环色 0xFF666666 → 主题槽（color 省略 → 主题 primary，
      // 参考版 MangaReaderOverlays.kt:754 加载环为裸 CircularProgressIndicator）；
      // [STAGE-UI-P43UNIFY2 B3] 换接统一封装 AppCircularProgressIndicator；
      // 线宽口径（B4 裁决）：参考版 34 处调用 0 覆盖 strokeWidth → 主流默认
      // 4dp，本处保留 2dp 实参（避免既有细环视觉抖动）。深底上主题
      // primary 可见性沿用参考版取舍（dark 主题 primary 为浅紫，可见；
      // light 主题 primary 为深紫，深底可见性有限——与参考版一致，如实遵循）
      // 保留 Container 作 widget 测试取证位（断言 color == null 即证明
      // 「加载态无整面硬编码底色」，B2 测试依赖），故不以 SizedBox 替换
      // ignore: sized_box_for_whitespace
      return Container(
        height: MediaQuery.of(context).size.height * 0.6,
        child: const Center(
          child: AppCircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final epaper = _epaperImage;
    if (widget.eInkThreshold != null && epaper != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onReady?.call();
      });
      return RawImage(
        image: epaper,
        // [P4-3 E2] 分页适配类型映射的 BoxFit
        fit: ComicImageFit.forSize(
          widget.fit,
          widget.smartFit,
          epaper.width,
          epaper.height,
        ),
        width: double.infinity,
      );
    }
    final bytes = _bytes;
    if (bytes != null) {
      return ComicImageFit(
        image: MemoryImage(bytes),
        fit: widget.fit,
        smartFit: widget.smartFit,
        onReady: widget.onReady,
        builder: (effectiveFit) => Image.memory(
          bytes,
          // [P4-3 E2] 分页适配类型映射的 BoxFit
          fit: effectiveFit,
          width: double.infinity,
          gaplessPlayback: true,
          frameBuilder: (_, child, frame, synchronous) =>
              frame == null || synchronous || !widget.crossFade || !_fadeOnLoad
              ? child
              : _MangaImageFade(child: child),
          errorBuilder: (context, _, _) => _errorPlaceholder(),
        ),
      );
    }
    return _errorPlaceholder();
  }

  Widget _errorPlaceholder() {
    // [STAGE-UI-P43UNIFY1 B1] 底色 0xFF1A1A1A → 55% 黑（参考版失败态
    // Color.Black.copy(alpha = 0.55f)，同 _buildImageErrorPlaceholder）
    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // [STAGE-UI-P43UNIFY1 B1] 图标位改真实素材图（调研报告 §2.4）
            Image.asset(
              'assets/images/image_loading_error.png',
              width: 64,
              height: 64,
            ),
            const SizedBox(height: 12),
            // [STAGE-UI-P43UNIFY2 B4] 文案 0xFF888888 → 主题槽 onSurfaceVariant
            Text(
              _error ?? '图片加载失败',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            // [STAGE-UI-P43UNIFY2 B4] 重试按钮 0xFF444444 → MD3 主题化
            // OutlinedButton（对齐参考版 MediumOutlinedButton，调研报告 §2.5）
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 本地 cbz 漫画页图片项（[cbz 批 D | 2026-10-03]）
///
/// 图片 URL 为 `cbz://<ZIP 条目名>` 伪 URL（Rust `get_chapter_content` 对
/// `.cbz` 本地书产出）：经 [LocalBookService.cbzReadPage]（FFI `cbz_read_page`）读取
/// 条目字节 → base64 解码 → [looksLikeImageBytes] 魔数校验 → [Image.memory]
/// 显示（校验不过的字节不送图片解码器）。
///
/// 与 [_DecodedComicImage] 同构：
/// - 内存缓存 [ComicImageDecodeCache] 优先（预载
///   [ComicImageDecodeCache.preloadCbz] 与正式渲染共用，命中零重复 FFI）；
/// - 加载态 = 0.6 屏高 + 主题加载环；失败态 = 55% 黑罩错误占位 + 重试，
///   并同时经 [onError] 回调节点进屏幕 [_failedIndices] 失败占位重试链路；
/// - [eInkThreshold] 非 null 时做真像素电子纸二值化（对齐 _DecodedComicImage）。
/// — 全栈工程师 + UI
class _LocalCbzImage extends StatefulWidget {
  const _LocalCbzImage({
    required this.localBooks,
    required this.crossFade,
    required this.path,
    required this.entry,
    required this.cacheKey,
    required this.onError,
    this.eInkThreshold,
    this.fit = BoxFit.fitWidth,
    this.smartFit = false,
    this.onReady,
  });

  final bool crossFade;
  final LocalBookService localBooks;

  /// 本地 cbz 文件路径（book.bookUrl；FFI 侧兼容绝对路径与相对可迁移标识）
  final String path;

  /// ZIP 条目名（`cbz://` 伪 URL；FFI 侧兼容带/不带前缀）
  final String entry;

  /// 内存缓存键（本地书无书源，用活跃 bookUrl 隔离不同 cbz 包的同名条目）
  final String cacheKey;

  final VoidCallback onError;

  /// 非 null 时做真像素电子纸二值化（对齐 EpaperTransformation）
  final int? eInkThreshold;

  /// [P4-3 E2] 图片渲染 BoxFit（调用方按分页适配类型映射传入）
  final BoxFit fit;
  final bool smartFit;
  final VoidCallback? onReady;

  @override
  State<_LocalCbzImage> createState() => _LocalCbzImageState();
}

class _LocalCbzImageState extends State<_LocalCbzImage> {
  bool _loading = true;
  bool _fadeOnLoad = true;
  Uint8List? _bytes;
  ui.Image? _epaperImage;
  String? _error;

  @override
  void initState() {
    super.initState();
    final hit = ComicImageDecodeCache.get(widget.cacheKey, widget.entry);
    if (hit != null) {
      _bytes = hit;
      _fadeOnLoad = false;
      _loading = false;
      unawaited(_applyEpaperIfNeeded(hit));
    } else {
      unawaited(_load());
    }
  }

  @override
  void didUpdateWidget(covariant _LocalCbzImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry != widget.entry ||
        oldWidget.cacheKey != widget.cacheKey) {
      // 条目/缓存键变化（切章/换书复用同索引元素）：重置重载
      final hit = ComicImageDecodeCache.get(widget.cacheKey, widget.entry);
      if (hit != null) {
        _bytes = hit;
        _fadeOnLoad = false;
        _loading = false;
        _error = null;
        unawaited(_applyEpaperIfNeeded(hit));
      } else {
        _bytes = null;
        unawaited(_load());
      }
    } else if (oldWidget.eInkThreshold != widget.eInkThreshold &&
        _bytes != null) {
      unawaited(_applyEpaperIfNeeded(_bytes!));
    }
  }

  @override
  void dispose() {
    _epaperImage?.dispose();
    super.dispose();
  }

  Future<void> _applyEpaperIfNeeded(Uint8List bytes) async {
    final thr = widget.eInkThreshold;
    if (thr == null) {
      _epaperImage?.dispose();
      if (mounted) setState(() => _epaperImage = null);
      return;
    }
    try {
      final img = await mangaEpaperFromBytes(bytes, threshold: thr);
      if (!mounted) {
        img.dispose();
        return;
      }
      _epaperImage?.dispose();
      setState(() => _epaperImage = img);
    } catch (e) {
      debugPrint('电子纸二值化失败: $e');
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 内存缓存（预载/其它实例已解码）命中 → 直接渲染，零重复 FFI 调用
      final hit = ComicImageDecodeCache.get(widget.cacheKey, widget.entry);
      if (hit != null) {
        if (!mounted) return;
        setState(() {
          _bytes = hit;
          _fadeOnLoad = false;
          _loading = false;
        });
        await _applyEpaperIfNeeded(hit);
        return;
      }
      final bytes = await widget.localBooks.cbzReadPage(
        path: widget.path,
        entry: widget.entry,
      );
      if (bytes.isEmpty) {
        throw Exception('CBZ 页数据为空');
      }
      if (!looksLikeImageBytes(bytes)) {
        throw Exception('CBZ 页数据不是有效图片');
      }
      if (!mounted) return;
      ComicImageDecodeCache.put(widget.cacheKey, widget.entry, bytes);
      setState(() {
        _bytes = bytes;
        _fadeOnLoad = true;
        _loading = false;
      });
      await _applyEpaperIfNeeded(bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
      widget.onError();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      // 加载态与 _DecodedComicImage 同口径（B2：无整面硬编码底色 + 主题环）
      // 保留 Container 作 widget 测试取证位，见该处注释
      // ignore: sized_box_for_whitespace
      return Container(
        height: MediaQuery.of(context).size.height * 0.6,
        child: const Center(
          child: AppCircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final epaper = _epaperImage;
    if (widget.eInkThreshold != null && epaper != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onReady?.call();
      });
      return RawImage(
        image: epaper,
        fit: ComicImageFit.forSize(
          widget.fit,
          widget.smartFit,
          epaper.width,
          epaper.height,
        ),
        width: double.infinity,
      );
    }
    final bytes = _bytes;
    if (bytes != null) {
      return ComicImageFit(
        image: MemoryImage(bytes),
        fit: widget.fit,
        smartFit: widget.smartFit,
        onReady: widget.onReady,
        builder: (effectiveFit) => Image.memory(
          bytes,
          fit: effectiveFit,
          width: double.infinity,
          gaplessPlayback: true,
          frameBuilder: (_, child, frame, synchronous) =>
              frame == null || synchronous || !widget.crossFade || !_fadeOnLoad
              ? child
              : _MangaImageFade(child: child),
          errorBuilder: (context, _, _) => _errorPlaceholder(),
        ),
      );
    }
    return _errorPlaceholder();
  }

  Widget _errorPlaceholder() {
    // 失败态与 _DecodedComicImage._errorPlaceholder 同口径（55% 黑罩 +
    // 素材图 + 重试；屏幕 _failedIndices 链路随后接管为页面级失败占位）
    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/image_loading_error.png',
              width: 64,
              height: 64,
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? '图片加载失败',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 无书源时的网络图电子纸渲染
class _EpaperNetworkImage extends StatefulWidget {
  const _EpaperNetworkImage({
    required this.network,
    required this.url,
    required this.headers,
    required this.threshold,
    required this.onError,
    this.fit = BoxFit.fitWidth,
    this.smartFit = false,
    this.onReady,
  });

  final NetworkService network;
  final String url;
  final Map<String, String>? headers;
  final int threshold;
  final VoidCallback onError;

  /// [P4-3 E2] 图片渲染 BoxFit（见 [MangaPageScaleType.fitFor] 取证注释）
  final BoxFit fit;
  final bool smartFit;
  final VoidCallback? onReady;

  @override
  State<_EpaperNetworkImage> createState() => _EpaperNetworkImageState();
}

class _EpaperNetworkImageState extends State<_EpaperNetworkImage> {
  bool _loading = true;
  ui.Image? _image;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _EpaperNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.threshold != widget.threshold) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.network.httpGetBytes(
        widget.url,
        headers: widget.headers,
        timeout: const Duration(seconds: 30),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError('HTTP ${res.statusCode}');
      }
      final img = await mangaEpaperFromBytes(
        res.bytes,
        threshold: widget.threshold,
      );
      if (!mounted) {
        img.dispose();
        return;
      }
      _image?.dispose();
      setState(() {
        _image = img;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
      widget.onError();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      // [STAGE-UI-P43UNIFY1 B2] 电子纸加载态与 _DecodedComicImage 同口径：
      // 去整面 0xFF1A1A1A 底色 + 环色走主题槽（详见该处取证注释）
      // [STAGE-UI-P43UNIFY2 B3] 换接统一封装（线宽口径 B4 裁决：保留 2dp 实参）
      // 保留 Container 作 widget 测试取证位（断言 color == null 即证明
      // 「加载态无整面硬编码底色」，B2 测试依赖），故不以 SizedBox 替换
      // ignore: sized_box_for_whitespace
      return Container(
        height: MediaQuery.of(context).size.height * 0.6,
        child: const Center(
          child: AppCircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final img = _image;
    if (img != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onReady?.call();
      });
      return RawImage(
        image: img,
        // [P4-3 E2] 分页适配类型映射的 BoxFit
        fit: ComicImageFit.forSize(
          widget.fit,
          widget.smartFit,
          img.width,
          img.height,
        ),
        width: double.infinity,
      );
    }
    // [STAGE-UI-P43UNIFY1 B1] 电子纸错误分支底色同语义 → 55% 黑
    //（参考版失败态 Color.Black.copy(alpha = 0.55f)，调研报告 §2.5）
    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Text(
          _error ?? '图片加载失败',
          // [STAGE-UI-P43UNIFY2 B4] 文案 0xFF888888 → 主题槽 onSurfaceVariant
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
