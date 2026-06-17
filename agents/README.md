# agents

统一收口常用 AI agent 工具安装脚本。

当前包含：

- `codex`：支持 `curl` / `npm`
- `claude-code`：支持 `curl` / `npm`（官方已标记 `npm` 为 deprecated）
- `opencode`：支持 `curl` / `npm`
- `hermes`：支持 `curl`
- `pi-agent`：支持 `curl` / `npm`

除安装外，provider 还支持：

- `doctor`：检查命令是否已安装、是否能读到版本
- `update`：更新到最新版本
- `remove-info`：输出卸载建议和常见数据目录，不自动删除

## 用法

```bash
# 交互选择 agent 和安装方式
bash agents/agents.sh

# 查看全部 agent 安装摘要
bash agents/agents.sh status

# 逐个执行 doctor
bash agents/agents.sh doctor-all

# 直接进入某个 agent
bash agents/agents.sh codex

# 直接执行某个安装方式
bash agents/agents.sh codex curl
bash agents/agents.sh pi-agent npm

# 检查安装状态
bash agents/agents.sh codex doctor
bash agents/agents.sh hermes doctor

# 更新
bash agents/agents.sh codex update-curl
bash agents/agents.sh pi-agent update-npm
bash agents/agents.sh hermes update

# 查看卸载建议
bash agents/agents.sh codex remove-info
bash agents/agents.sh hermes remove-info
```
