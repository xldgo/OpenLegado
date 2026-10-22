import '../../data/services/native_reader_layout_transport.dart';
import '../../domain/contracts/reader_layout_transport.dart';

/// 默认仍装配正式Rust排版传输，不在领域会话内选择平台实现。— Codex + Bridge
ReaderLayoutTransport createReaderLayoutTransport() =>
    const NativeReaderLayoutTransport();
