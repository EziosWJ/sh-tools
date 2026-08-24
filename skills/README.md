# skills

统一收口各类 skills 安装脚本。

当前包含：

- `agents-template`：在新项目中创建中文通用 `AGENTS.md`，并创建内容为 `@AGENTS.md` 的 `CLAUDE.md`。默认拒绝覆盖已有文件，可传 `--force` 明确覆盖。
- `karpathy`：下载 `CLAUDE.md`，并在当前目录创建 `AGENTS.md -> ./CLAUDE.md` 软链接。
- `mattpocock`：执行 `npx skills@latest add mattpocock/skills`，安装过程保持前台交互，由用户自行操作。

## 用法

```bash
# 交互选择 provider
bash skills/skills.sh

# 在当前目录初始化项目规则
bash skills/skills.sh agents-template

# 初始化指定项目目录；已有文件时明确覆盖
bash skills/skills.sh agents-template --force /path/to/project

# 直接安装 karpathy skills
bash skills/skills.sh karpathy

# 直接运行 mattpocock provider
bash skills/skills.sh mattpocock
```
