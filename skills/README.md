# skills

统一收口各类 skills 安装脚本。

当前包含：

- `karpathy`：下载 `CLAUDE.md`，并在当前目录创建 `AGENTS.md -> ./CLAUDE.md` 软链接。
- `mattpocock`：执行 `npx skills@latest add mattpocock/skills`，安装过程保持前台交互，由用户自行操作。

## 用法

```bash
# 交互选择 provider
bash skills/skills.sh

# 直接安装 karpathy skills
bash skills/skills.sh karpathy

# 直接运行 mattpocock provider
bash skills/skills.sh mattpocock
```
