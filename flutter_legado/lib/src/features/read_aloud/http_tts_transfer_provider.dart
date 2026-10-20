import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/bootstrap/application_dependencies.dart'
    show networkServiceProvider;
import '../../data/services/http_tts_transfer_service.dart';
import '../../platform/files/http_tts_file_service.dart';
import 'http_tts_repository_provider.dart';

final httpTtsTransferProvider = Provider<HttpTtsTransferService>(
  (ref) => HttpTtsTransferService(
    ref.watch(httpTtsRepositoryProvider),
    ref.watch(networkServiceProvider),
  ),
);
final httpTtsFileServiceProvider = Provider<HttpTtsFileService>(
  (ref) => HttpTtsFileService(),
);
