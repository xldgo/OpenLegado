import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/app_bookshelf_settings_repository.dart';
import '../../../domain/contracts/bookshelf_settings_repository.dart';
import '../../../providers/app_settings_provider.dart';
import '../../../domain/models/bookshelf_settings.dart';

final bookshelfSettingsRepositoryProvider =
    Provider<BookshelfSettingsRepository>(
      (ref) =>
          AppBookshelfSettingsRepository(ref.watch(appSettingsServiceProvider)),
    );

final bookshelfSettingsProvider = StreamProvider<BookshelfSettings>((
  ref,
) async* {
  final repository = ref.watch(bookshelfSettingsRepositoryProvider);
  await repository.load();
  yield* repository.watch();
});
