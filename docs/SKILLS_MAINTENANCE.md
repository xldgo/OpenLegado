# Skills 来源与本地入口

仓库只维护 `.agents/skills/` 中的一份上游 skills。
`.claude/skills/`、`.qoder/skills/` 是本地共享入口，不进入版本控制。
其他 agent 配置仍留在各自目录，不随 skills 初始化改写。

从仓库根目录执行：

```powershell
python scripts/setup_skills.py
```

Windows 创建目录联接；其他平台使用相对符号链接。
脚本可重复执行，已经正确连接的入口保持原样；发现独立目录或错误链接时停止，
不自动删除已有内容。新克隆、移动仓库或需要恢复入口时重新执行。
Windows 联接使用绝对目标，移动仓库后若旧链接仍存在，先核对并移除旧入口再初始化。

各工具读取入口下的 `SKILL.md`。本轮在 Windows 核对了两个入口的目标及全部
当时的 53 个入口文件，并验证初始化重复执行；未宣称其他平台或各编辑器的实际加载已经验收。

## 上游更新

来源、固定提交和各 skill 的目录记录于
[`scripts/skills_sources.json`](../scripts/skills_sources.json)。
它是仓库的来源清单，不是 `npx skills` 的锁文件。

| 内容 | 上游 |
|---|---|
| Dart / Flutter 通用 skills | [Flutter 官方 agent-plugins](https://github.com/flutter/agent-plugins/tree/main/skills) |
| Flutter MCP skills | [作者维护的 mcp_flutter](https://github.com/Arenukvern/mcp_flutter/tree/main/plugin/skills) |
| 工程治理 skills | [作者维护的 Skill Steward](https://github.com/arenukvern/skill_steward/tree/main/skills) |
| Apple UI Designer | [作者维护的 atelier-ui](https://github.com/heyman333/atelier-ui/tree/main/skills/apple-ui-designer) |

更新时先查询这些来源的最新提交，再比较已安装 skill 的完整目录，包括参考资料、
脚本及其他资源。只同步对应上游内容至 `.agents/skills/`，同步记录提交号；
不安装本项目未选择的新 skills，不向另外两个入口复制文件。
按下载提交的 Git blob 摘要核对内容，文本允许 Git 工作区的 LF/CRLF 换行转换。

项目特有的设计库、验证和执行约束维护于 `AGENTS.md` 与 `docs/design_system.md`，
不自行修改上游 skills 示例。上游仍使用旧 Material 导入时保留原文，实际编码按项目
已选用的 `material_ui` / `cupertino_ui` 接线处理。
用户当前指令优先于 skills；更新不改变用户对提交、推送、测试或子代理的授权。

编写者：Codex｜2026-10-11

2026-10-18：按用户要求移除六项 GitNexus skills 及其来源记录；共享入口自动同步。
