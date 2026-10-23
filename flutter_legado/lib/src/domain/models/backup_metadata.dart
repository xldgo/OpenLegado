final class BackupMetadata {
  const BackupMetadata({
    required this.deviceId,
    this.lastBackupMs = 0,
    this.remoteScope = '',
    this.seenRemote = '',
  });
  final String deviceId, remoteScope, seenRemote;
  final int lastBackupMs;
  BackupMetadata copyWith({
    int? lastBackupMs,
    String? remoteScope,
    String? seenRemote,
  }) => BackupMetadata(
    deviceId: deviceId,
    lastBackupMs: lastBackupMs ?? this.lastBackupMs,
    remoteScope: remoteScope ?? this.remoteScope,
    seenRemote: seenRemote ?? this.seenRemote,
  );
}
