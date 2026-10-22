import '../../bridge/ffi.dart' as bridge;
import '../../bridge/layout_bridge.dart' as native;
import '../../bridge/layout_dto.dart' as dto;
import '../bridge/rust_errors.dart';
import '../bridge/layout_dto_mapping.dart';
import '../../domain/contracts/reader_layout_transport.dart';
import '../../domain/errors/reader_layout_cancelled.dart';
import '../../domain/models/reader_layout_reply.dart';

class _NativeLayoutHandle {
  final native.LayoutSession session;
  bool disposed = false;
  _NativeLayoutHandle(this.session);
  void release() {
    if (!disposed) {
      disposed = true;
      rustCall(() => session.dispose(), operation: 'readerLayoutDispose');
    }
  }
}

class NativeReaderLayoutTransport implements ReaderLayoutTransport {
  const NativeReaderLayoutTransport();
  @override
  Future<ReaderLayoutReply> begin(Map<String, Object?> config) async {
    final session = await rustFuture(
      () => bridge.readerLayoutBegin(config: configToDto(config)),
      operation: 'readerLayoutBegin',
    );
    final handle = _NativeLayoutHandle(session);
    return ReaderLayoutReply.empty(handle);
  }

  @override
  Future<ReaderLayoutReply> push(
    Object sessionId,
    List<Map<String, Object?>> blocks,
  ) async {
    final handle = sessionId as _NativeLayoutHandle;
    if (handle.disposed) throw const ReaderLayoutCancelled();
    final reply = await rustFuture(
      () => handle.session.push(blocks: blocks.map(blockToDto).toList()),
      operation: 'readerLayoutPush',
    );
    return _replyFromNative(reply, handle);
  }

  @override
  Future<ReaderLayoutReply> finish(Object sessionId) async {
    final handle = sessionId as _NativeLayoutHandle;
    if (handle.disposed) throw const ReaderLayoutCancelled();
    try {
      return _replyFromNative(
        await rustFuture(
          () => handle.session.finish(),
          operation: 'readerLayoutFinish',
        ),
        handle,
      );
    } finally {
      handle.release();
    }
  }

  @override
  Future<void> cancel(Object sessionId) async {
    final handle = sessionId as _NativeLayoutHandle;
    if (!handle.disposed) {
      rustCall(() => handle.session.cancel(), operation: 'readerLayoutCancel');
      handle.release();
    }
  }
}

ReaderLayoutReply _replyFromNative(dto.LayoutReplyDto value, Object handle) =>
    ReaderLayoutReply.fromMap({
      'schemaVersion': 1,
      'sessionId': handle,
      'rustMicros': value.rustMicros.toInt(),
      'pages': value.pages
          .map(
            (page) => <String, dynamic>{
              ...page.metadata.map(
                (key, value) => MapEntry(key, layoutValueFromDto(value)),
              ),
              'elements': page.elements
                  .map(
                    (element) =>
                        element.glyphIndex?.toInt() ??
                        layoutValueFromDto(element.other!),
                  )
                  .toList(),
            },
          )
          .toList(),
      'textStyles': value.textStyles.map(textStyleFromDto).toList(),
      'glyphs': <String, dynamic>{
        'count': value.count.toInt(),
        'text': value.text,
        'geometry': value.geometry,
        'positions': value.positions,
        'extras': value.extras.map(
          (key, value) => MapEntry(key, layoutValueFromDto(value)),
        ),
      },
    });
