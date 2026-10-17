import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localization.dart';
import '../../audio/application/read_aloud_position.dart';

/// 拖动只预览原文位置，松手才定位；不拥有播放会话或重新计算朗读单元。— Codex + UI
class ReadAloudProgressSlider extends StatefulWidget {
  const ReadAloudProgressSlider({
    super.key,
    required this.bookUrl,
    required this.chapterIndex,
    required this.sourceText,
    required this.position,
    required this.enabled,
    required this.onSeek,
  });

  final String bookUrl, sourceText;
  final int chapterIndex;
  final ReadAloudPosition? position;
  final bool enabled;
  final ValueChanged<int> onSeek;

  @override
  State<ReadAloudProgressSlider> createState() =>
      _ReadAloudProgressSliderState();
}

class _ReadAloudProgressSliderState extends State<ReadAloudProgressSlider> {
  double? _preview;
  Object? _dragIdentity;

  Object get _identity => (
    widget.bookUrl,
    widget.chapterIndex,
    widget.sourceText,
    widget.position?.session,
  );

  bool get _hasPosition =>
      widget.sourceText.isNotEmpty &&
      widget.position?.bookUrl == widget.bookUrl &&
      widget.position?.chapterIndex == widget.chapterIndex;

  @override
  void didUpdateWidget(covariant ReadAloudProgressSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || !_hasPosition || _dragIdentity != _identity) {
      _preview = null;
      _dragIdentity = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = _identity;
    final length = widget.sourceText.length;
    final canSeek = widget.enabled && _hasPosition;
    final offset =
        (_preview ?? (_hasPosition ? widget.position!.offset : 0).toDouble())
            .clamp(0.0, length.toDouble());
    final percentage = length == 0 ? 0 : (offset * 100 / length).floor();
    String format(double value) {
      final position = value.round().clamp(0, length);
      final percent = length == 0 ? 0 : (position * 100 / length).floor();
      return '${context.l10n.readAloudSourceProgress(position, length)} · $percent%';
    }

    final label = format(offset);
    return Row(
      children: [
        Expanded(
          child: Slider(
            min: 0,
            max: length > 0 ? length.toDouble() : 1,
            value: offset,
            label: label,
            semanticFormatterCallback: format,
            onChangeStart: canSeek
                ? (value) {
                    if (!mounted ||
                        !widget.enabled ||
                        !_hasPosition ||
                        _identity != identity) {
                      return;
                    }
                    setState(() {
                      _dragIdentity = identity;
                      _preview = value;
                    });
                  }
                : null,
            onChanged: canSeek
                ? (value) {
                    if (!mounted ||
                        _dragIdentity != identity ||
                        _identity != identity) {
                      return;
                    }
                    setState(() => _preview = value);
                  }
                : null,
            onChangeEnd: canSeek
                ? (value) {
                    if (!mounted ||
                        !widget.enabled ||
                        !_hasPosition ||
                        _dragIdentity != identity ||
                        _identity != identity) {
                      return;
                    }
                    setState(() {
                      _preview = null;
                      _dragIdentity = null;
                    });
                    widget.onSeek(value.round().clamp(0, length));
                  }
                : null,
          ),
        ),
        Text(
          _hasPosition ? '$percentage%' : '—',
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }
}
