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
| 源名称 / 地址 / 分组 | `source_name` / `source_url` / `source_group` | Source name / Source URL / Source group |
| 编辑器页签 | `source_tab_base` / `source_tab_info` / `source_tab_toc` / `source_tab_content` | Basic / Details / Chapters / Content |
| 书籍与章节字段 | `r_book_list` / `r_book_name` / `r_author` / `rule_chapter_list` | Book list / Book title / Author / Chapter list |
| 订阅规则字段 | `r_articles` / `r_title` / `r_description` / `r_content` | Article list / Title / Description / Content |
| 搜索范围 / 精准搜索 | `search_scope` / `precision_search` | Search scope / Precise search |
| 搜索结果与书源进度 | `search_result_count` / `search_source_progress` | Results / Progress |
| 清空搜索历史 | `sure_clear_search_history` | Clear all search history? |
| 空结果范围引导 | `search_empty_scope_disable_precision` / `search_empty_scope_switch_all` | Disable precise search? / Search all groups? |
| 正文搜索 | `search_content` / `search_content_size` | Search content / Search results |
| 发现 / 订阅 / RSS 收藏 | `discovery` / `rss` / `rss_star` | Discovery / RSS Feeds / RSS Favorites |
| 调试 / 调试结束 | `debug` / `debug_source` / `debug_finished` | Debug / Debug source / Debug finished |
| 登录源 / 登录错误 | `login_source` / `source_no_login` / `login_error` | Log in to / No login URL / Login error |
| 查看 / 删除登录头 | `show_login_header` / `del_login_header` / `login_header` | View / Delete login headers |
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

搜索与正文搜索的菜单值、范围标识及屏蔽词不随语言改变；用户输入的历史关键词、
书源名称和自定义分组仍是数据。搜索计数、失败计数与正文匹配数使用完整的 ICU
句子，避免拼接英文单位；失败原因保留底层原文，仅本地化外围提示。

源编辑器的字段描述在构建界面时使用当前资源；控制器仍按原字段键保留输入。
初始化、快照和保存使用稳定键，不依赖译文。字段括号内的协议标识、URL 示例的
规则变量、JSON/JS/CSS 内容保持原样；必填反馈使用完整句子模板。
源提供的注释或变量说明按用户数据显示，仅应用自带的兜底说明进行本地化。

经典与 V2 登录表单的行名、选择项及默认值来自书源协议，保持原文与稳定键。
只翻译应用自身的外围标题、菜单、校验及兜底提示；不能按表单文字猜译或修改 JS。
Cookie/Header/Token、源提示、网页内容和 Rust 日志同样保持原样。应用自带调试
日志在执行前固定语言快照，计数和文章提示使用完整模板与英文复数。

阅读器与高级设置按用户要求，只补齐能与上游明确对应的文案。除字符串外，
同时核对固定版本的 [英文数组](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/res/values/arrays.xml)
及 [中文数组](https://github.com/HapeLee/legado-with-MD3/blob/070ca1a9b2e491654f70c105bca9939968023940/app/src/main/res/values-zh-rCN/arrays.xml)。
本批新增阅读设置 90 条、高级设置 46 条资源，合计 911 个中英文键。

| 语境 | 对应的上游键或数组 |
|---|---|
| 翻页动画、字号、字重及斜体 | `page_anim`、`font_size`、`font_weight`、`read_config_italic`、`text_font_weight` |
| 页眉页脚、四侧边距及提示项 | `header`、`footer`、`padding_top/bottom/left/right`、`read_tip` |
| 屏幕方向、亮屏时长、双页与简繁转换 | `screen_direction`、`screen_time_out`、`double_page_title`、`chinese_mode` |
| 状态栏、导航栏及刘海区域 | `pt_hide_status_bar`、`pt_hide_navigation_bar`、`read_body_to_lh`、`padding_display_cutouts` |
| 进度条、工具栏与亮度方向 | `progress_bar_behavior`、`adjust_chapter_page/index`、`read_bar_style_follow_page`、`brightness_bar_off/horizontal` |
| 首页行为、本地密码及源编辑器 | `main_activity`、`pt_auto_refresh`、`pt_default_read`、`default_home_page`、`set_local_password`、`source_edit_text_max_line` |
| 缓存、朗读、搜索数据与日志 | `bitmap_cache_size`、`image_retain_number`、`pre_download`、`ignore_audio_focus_title`、`auto_clear_expired`、`record_log`、`record_heap_dump_t` |

字重的 Regular 对应字重数组，不能复用朗读设置中的 General；页眉页脚提示项
按实际含义对应数组，不能照搬上游数组下标覆盖已有配置编号。字号、边距、字重、
缩进、方向、超时与提示项的数值和偏好键保持原样；首页显示名与稳定 ID 分离。
默认字体只在渲染时取译文，真实字体名与用户数据不变，不在初始化阶段读取本地化上下文。

暂留阅读设置重新设计的分类标题与说明、中文排版说明、九宫格位置与扩展动作、
章节进度组合、竖向亮度左右组合、本应用特有服务说明及部分异步操作反馈。
这些内容没有完整对应或仍需核对行为，本轮不猜译；英文模式仍可能出现这些中文。
后续获得明确语义后继续补齐，不将本批视为阅读器或全应用国际化完成。

本次继续对照外观、书源管理、替换规则、TXT 目录规则、字典规则、WebDAV、
阅读目录与菜单、漫画设置；共对齐 224 个文案，接入 356 处显示位置，新增 146 条、
复用 78 条现有资源，中英文合计 1057 个键。通用取消、保存、导入、分组等操作
复用已有资源；不同语境的匹配规则、主题封面规则和阅读替换规则使用各自对应项。

| 页面语境 | HapeLee 参考键 |
|---|---|
| 外观、纯黑、顶栏／底栏、容器 | `pure_black`、`top_bar_button_style`、`top_bar_opacity`、`bottom_bar_opacity`、`base_card_corner_radius` |
| 书源筛选、批量操作与排序 | `book_source_manage`、`enabled_explore`、`disabled_explore`、`enable_selection`、`disable_selection`、`sort_manual`、`sort_by_name`、`sort_by_respondTime` |
| 规则编辑与默认导入 | `rule_name`、`match_pattern`、`replace_to`、`specific_scope`、`exclude_scope`、`copy_rule`、`import_default_rule`、`dict_rule` |
| WebDAV 与备份选项 | `web_dav_set`、`web_dav_url`、`web_dav_account`、`web_dav_pw`、`webdav_device_name`、`restore_ignore`、`only_latest_backup_t`、`auto_check_new_backup_t` |
| 目录、书签及阅读菜单 | `chapter_list`、`bookmark`、`locate_current_reading`、`use_replace_rule`、`load_word_count`、`edit_content`、`disable_source`、`book_change_source` |
| 漫画显示与交互 | `manga_setting`、`enable_manga_gray`、`disable_manga_scale`、`disable_manga_scroll_animation`、`manga_cross_fade`、`manga_reader_hide_footer` |

本应用“复制规则”对应上游“拷贝规则”、“发现已启用”对应“已启用发现”，属于
同一操作或状态的标签变体；保留本应用中文，使用已核对功能的英文术语。目录页签、
默认规则导入和选中状态的显示同样接入资源。完整逐项索引及原始中英文参考保存在
本 worktree 的忽略目录 `flutter_legado/build/localization-align-plan.json`。

书源“未分组”用于旧筛选的内部值保持中文，只有显示标签本地化；菜单动作值、
规则 JSON 字段、查询地址、凭据、分组名和书籍数据不改。原有漫画预览章节名与
数字也不在本批改动中。弹窗优先使用弹窗上下文，默认、选中与取消选中分支分别核对。

继续暂留本应用 JSON 主题导出说明（上游完整主题包包含图片、字体等，行为不同）、
电子纸近似效果、同步增强说明、规则即时预览和超时说明，以及未核对的异步反馈。
中文相同不代表功能等价，不将原始错误或服务返回文本按词条猜译。

订阅源管理的筛选控制值保持旧中文兼容，显示词来自 ARB；英文输入别名也从
生成资源读取。禁止把菜单动作值、配置键或书源规则字段翻译成当前界面语言。
现有 `AppStrings` 其他译文先迁移保存，再按功能审阅术语与语境，不视为全应用译文已验收。

补充来源为 [Rimchars/legado 固定版本资源目录](https://github.com/Rimchars/legado/tree/e111bf666199505d783e6910d8609f0e5cb043e0/app/src/main/res)。
日语、西班牙语、葡萄牙语、越南语等可用于后续参考。
该版本的 `values` 有 2471 个 `<string>` 条目，日/西/葡各 1198、越南语 1197，
按键比较各缺少 1271 / 1272 个基础可翻译字符串；繁体 1212，缺少 1257 个。
这些数值只统计 `<string>`，不代表数组、复数、占位符或译文质量；不能据此直接开放语言。

Flutter 生成配置与 ICU 语法依据 [官方国际化说明](https://docs.flutter.dev/ui/internationalization)。

### 书签、阅读记录与书架分组的补充对应

基线更新到 `74dda3c7b` 后，四个页面文件继续接入 41 项文案、49 个显示位置；
新增 29 项资源，复用 12 项，中英文共 1086 个键。上游来源仍为前述固定版本，
组合的搜索、加载及计数句子按本页面实际行为组成完整资源，不照搬拆分词序。

| 本应用语境 | HapeLee 参考键 |
|---|---|
| 书签搜索、空态及删除确认 | `action_search`、`bookmark`、`no_bookmark`、`confirm_delete_bookmark`、`delete_bookmark_message` |
| 书签的章节序号及备注 | `chapter_index_format`、`bookmark_mark_note` |
| 阅读记录选项、排序和启用 | `read_record_options`、`bookshelf_px_2`、`reading_time_sort`、`last_read_time_sort`、`enable_read_record` |
| 阅读记录删除及时间标签 | `delete_read_record_message`、`clear_read_records_message`、`reading_time_with_value`、`last_read_time_tag` |
| 累计已读和时长 | `read_books_prefix/suffix`、`total_reading_time_format` |
| 分组编辑、新建、名称与书籍计数 | `group_edit`、`group_add`、`group_name`、`book_count` |

保留本应用中文标签及确认语义：原来带书名或章节名的确认继续保留参数，
不新增删除范围或不可撤销承诺；备注内容、书籍数据与自定义分组名保持原文。
英文书籍计数使用 ICU 单复数。分组显示/隐藏的提示只描述已有开关状态。

本批不改 `formatDuring` 时长算法及中文输出，也不改 `groupDailyByDay` 的
中文内部标识与分组顺序。按书／按天视图及日期分组标签、分组封面 URL 说明、
分配与删除分组的长说明和未核对的异步反馈继续保留，后续核对行为再处理。
当前英文界面仍可能出现这些中文，不视为阅读记录或全应用国际化完成。

编写者：Codex｜2026-10-12
