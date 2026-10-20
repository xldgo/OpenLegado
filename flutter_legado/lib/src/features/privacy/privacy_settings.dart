/// 验证策略与平台能力分别建模。— Codex + UI
enum PrivacyUnlockScope { everyTime, appSession, untilBackground }

class PrivacySettings {
  const PrivacySettings({
    this.enabled = false,
    this.biometricEnabled = false,
    this.verifyOnEnterGroup = true,
    this.verifyOnOpenBook = true,
    this.verifyOnAppStart = false,
    this.scope = PrivacyUnlockScope.appSession,
    this.graceSeconds = 0,
  });
  final bool biometricEnabled;
  final bool enabled, verifyOnEnterGroup, verifyOnOpenBook, verifyOnAppStart;
  final PrivacyUnlockScope scope;
  final int graceSeconds;
  PrivacySettings copyWith({
    bool? enabled,
    bool? biometricEnabled,
    bool? verifyOnEnterGroup,
    bool? verifyOnOpenBook,
    bool? verifyOnAppStart,
    PrivacyUnlockScope? scope,
    int? graceSeconds,
  }) => PrivacySettings(
    enabled: enabled ?? this.enabled,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    verifyOnEnterGroup: verifyOnEnterGroup ?? this.verifyOnEnterGroup,
    verifyOnOpenBook: verifyOnOpenBook ?? this.verifyOnOpenBook,
    verifyOnAppStart: verifyOnAppStart ?? this.verifyOnAppStart,
    scope: scope ?? this.scope,
    graceSeconds: graceSeconds ?? this.graceSeconds,
  );
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'biometricEnabled': biometricEnabled,
    'verifyOnEnterGroup': verifyOnEnterGroup,
    'verifyOnOpenBook': verifyOnOpenBook,
    'verifyOnAppStart': verifyOnAppStart,
    'scope': scope.name,
    'graceSeconds': graceSeconds,
  };
  factory PrivacySettings.fromJson(Map<String, dynamic> value) =>
      PrivacySettings(
        enabled: value['enabled'] == true,
        biometricEnabled: value['biometricEnabled'] == true,
        verifyOnEnterGroup: value['verifyOnEnterGroup'] != false,
        verifyOnOpenBook: value['verifyOnOpenBook'] != false,
        verifyOnAppStart: value['verifyOnAppStart'] == true,
        scope: PrivacyUnlockScope.values.firstWhere(
          (s) => s.name == value['scope'],
          orElse: () => PrivacyUnlockScope.appSession,
        ),
        graceSeconds:
            const [0, 30, 120, 180, 300].contains(value['graceSeconds'])
            ? value['graceSeconds'] as int
            : 0,
      );
}
