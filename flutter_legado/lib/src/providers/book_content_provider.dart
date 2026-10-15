import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import '../domain/contracts/local_book_service.dart';
import '../domain/contracts/book_archive_service.dart';
import '../domain/contracts/book_export_service.dart';
import '../domain/contracts/review_service.dart';

/// 内容能力从同一应用装配读取，可逐领域替换。— Codex + UI
final localBookServiceProvider = Provider<LocalBookService>(
  (ref) => ref.watch(bookApiProvider).localBookService,
);
final bookArchiveServiceProvider = Provider<BookArchiveService>(
  (ref) => ref.watch(bookApiProvider).bookArchiveService,
);
final bookExportServiceProvider = Provider<BookExportService>(
  (ref) => ref.watch(bookApiProvider).bookExportService,
);
final reviewServiceProvider = Provider<ReviewService>(
  (ref) => ref.watch(bookApiProvider).reviewService,
);
