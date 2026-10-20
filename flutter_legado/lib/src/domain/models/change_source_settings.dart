/// 换源普通设置的类型化快照，存储键仅由数据层解释。— Codex + UI
enum ChangeSourceOption { checkAuthor, loadWordCount, loadInfo, loadToc }

extension ChangeSourceSettingsOption on ChangeSourceSettings {
  ChangeSourceSettings withOption(ChangeSourceOption option, bool enabled) =>
      switch (option) {
        ChangeSourceOption.checkAuthor => copyWith(checkAuthor: enabled),
        ChangeSourceOption.loadWordCount => copyWith(loadWordCount: enabled),
        ChangeSourceOption.loadInfo => copyWith(loadInfo: enabled),
        ChangeSourceOption.loadToc => copyWith(loadToc: enabled),
      };
}

final class ChangeSourceSettings {
  const ChangeSourceSettings({
    this.checkAuthor = false,
    this.loadWordCount = false,
    this.loadInfo = false,
    this.loadToc = false,
  });
  final bool checkAuthor;
  final bool loadWordCount;
  final bool loadInfo;
  final bool loadToc;
  ChangeSourceSettings copyWith({
    bool? checkAuthor,
    bool? loadWordCount,
    bool? loadInfo,
    bool? loadToc,
  }) => ChangeSourceSettings(
    checkAuthor: checkAuthor ?? this.checkAuthor,
    loadWordCount: loadWordCount ?? this.loadWordCount,
    loadInfo: loadInfo ?? this.loadInfo,
    loadToc: loadToc ?? this.loadToc,
  );
}
