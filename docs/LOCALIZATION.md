# Flutter 文案与多语言资源

中文是默认与主语言。应用文案由 Flutter ARB 管理；支持语言从生成的
`AppLocalizations.supportedLocales` 读取，不能只添加语言切换选项而缺少资源。
当前页面覆盖与验收进度只记录在 [Active 计划](REFACTORING_ACTIVE_PLAN.md)。

## 资源与接线

- `flutter_legado/lib/src/l10n/arb/app_zh.arb`：中文模板，含说明与占位符定义。
- `flutter_legado/lib/src/l10n/arb/app_en.arb`：对应英文资源。
- `flutter_legado/l10n.yaml`：生成配置，优先中文，输出到 `lib/src/l10n/generated/`。
- `appLocaleProvider`：沿用 `app_locale` 偏好与跟随系统行为；不支持的系统语言回退中文。
- `MaterialApp`：应用代理 `AppLocalizations.delegate` 与独立 `material_ui` 的
  `GlobalMaterialLocalizations.delegates` 一起注册。不要直接使用生成类的
  `localizationsDelegates` 列表覆盖独立设计库代理。

新页面导入 `app_localization.dart`，在渲染时用 `context.l10n`，使语言变化通知页面重建。
对话框和弹出菜单优先用其 builder 提供的上下文；异步操作在等待前固定所需的文案快照。

`AppStrings` 暂时作为未迁移页面的兼容入口，所有 getter 都转发到生成资源，不再维护
独立中英文字符串表。独立旧页面或历史测试没有注册应用代理时，`context.l10n` 回退
这个入口；正式应用必须注册代理。后续按功能移除静态调用，最终删除兼容入口。

书名、作者、章节、书源名称和用户自定义分组是数据，不翻译、不回写。内置书架分类
按固定 ID 在显示层取文案；不会因切换语言改变数据库内容。Rust 返回的业务错误和
服务状态原文暂沿用现有接口，不在 UI 中根据文本猜译。

## 修改与生成

在 Flutter 工程目录执行，使用 PATH 中选定的 Flutter SDK：

```powershell
cd flutter_legado
flutter pub get --enforce-lockfile
flutter gen-l10n
```

修改文案时同步中文模板、英文资源及生成文件。生成目录不手工编辑。
固定文案使用有含义的键，参数在中文模板的 `placeholders` 中声明类型。
英文书籍数量和分钟使用 ICU 复数；不要拼接中文单位或拆分整句的语序。
生成两次应当没有额外差异；新增语言前核对键集合、占位符及实际语境。

已有资源有部分重复的旧 getter，先保留名称以兼容页面；新文案优先复用含义一致的键。
不为了覆盖率把整仓中文日志、规则默认值或用户数据批量替换。

## 上游来源与术语

主要参考 [HapeLee/legado-with-MD3 固定版本的资源目录](https://github.com/HapeLee/legado-with-MD3/tree/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/res)，
使用 `values/strings.xml` 的英文和 `values-zh-rCN/strings.xml` 的简体中文逐项对照。
繁体参考 `values-zh-rTW` / `values-zh-rHK`，需要匹配本应用功能语境后再迁入。

| 本应用文案 | HapeLee 键 | 英文参考 |
|---|---|---|
| 发现 / 订阅 / RSS 收藏 | `discovery` / `rss` / `rss_star` | Discovery / RSS Feeds / RSS Favorites |
| 登录 / 源变量 | `login` / `set_source_variable` | Log in / Set source variable |
| 保留原名 / 分组 / 启用状态 | `keep_original_name` / `keep_group` / `keep_enable` | Keep existing names / groups / enabled state |
| 本地 / 网络导入 | `import_local` / `import_on_line` | Import from file / URL |
| 首页 / 书架 / 我的 | `home` / `bookshelf` / `my` | Home / Bookshelf / Me |
| 发现 / 订阅 | `discovery` / `rss` | Discovery / RSS Feeds |
| 累计阅读 / 今日阅读目标 | `home_total_read_books` / `home_today_reading_goal` | Books Read / Today's Reading Goal |
| 分组管理 / 远程书籍 | `group_manage` / `add_remote_book` | Group Management / Remote Books |
| 导入书单 / 导出书单 | `import_bookshelf` / `export_bookshelf` | Import Book List / Export Book List |
| 备份与恢复 / TXT 目录规则 | `backup_restore` / `txt_toc_rule` | Backup and Restore / Text Catalog Rules |

本应用重新组织的分组标题与功能说明按实际页面翻译；不照搬上游独有功能文案。
例如本应用“高级”按语义使用 Advanced，“替换净化”使用 Replacement Rules。
订阅源导入选项中的“保留”指保留本地已有值，英文补充 existing 避免歧义；
网络导入按实际 URL 输入行为使用 Import from URL。参考原意，不机械照抄不自然的译文。

订阅源管理的筛选控制值保持旧中文兼容，显示词来自 ARB；英文输入别名也从
生成资源读取。禁止把菜单动作值、配置键或书源规则字段翻译成当前界面语言。
现有 `AppStrings` 其他译文先迁移保存，再按功能审阅术语与语境，不视为全应用译文已验收。

补充来源为 [Rimchars/legado 固定版本资源目录](https://github.com/Rimchars/legado/tree/e111bf666199505d783e6910d8609f0e5cb043e0/app/src/main/res)。
日语、西班牙语、葡萄牙语、越南语等可用于后续参考。
该版本的 `values` 有 2471 个 `<string>` 条目，日/西/葡各 1198、越南语 1197，
按键比较各缺少 1271 / 1272 个基础可翻译字符串；繁体 1212，缺少 1257 个。
这些数值只统计 `<string>`，不代表数组、复数、占位符或译文质量；不能据此直接开放语言。

Flutter 生成配置与 ICU 语法依据 [官方国际化说明](https://docs.flutter.dev/ui/internationalization)。

编写者：Codex｜2026-10-12
