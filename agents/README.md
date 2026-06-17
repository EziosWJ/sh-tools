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

## Claude Code profile 管理

`claude-code config` 用于管理供应商 / 中转站 profile。profile 保存为 env 文件，不会直接修改全局 shell 环境。

配置目录：

```text
~/.config/sh-tools/agents/claude-code/
├── profiles/
├── wrappers/
└── default
```

常用命令：

```bash
# 列出 profiles
bash agents/agents.sh claude-code config list

# 交互创建 profile，适合 NewAPI / 小米 / 自建中转站
bash agents/agents.sh claude-code config add

# 查看 profile
bash agents/agents.sh claude-code config status newapi

# 从 ANTHROPIC_BASE_URL/v1/models 拉取模型列表
bash agents/agents.sh claude-code config models newapi

# 从模型列表选择或手动设置 ANTHROPIC_MODEL
bash agents/agents.sh claude-code config set-model newapi

# 编辑完整 env profile
bash agents/agents.sh claude-code config edit newapi

# 生成 ~/.local/bin/claude-newapi wrapper
bash agents/agents.sh claude-code config wrapper newapi

# 记录默认 profile，仅写入 sh-tools 配置，不污染全局 shell
bash agents/agents.sh claude-code config use newapi
```

profile 支持任意 Claude Code 环境变量，例如：

```bash
ANTHROPIC_BASE_URL="https://your-newapi.example.com"
ANTHROPIC_AUTH_TOKEN="sk-xxx"
ANTHROPIC_MODEL="mimo-v2.5-pro-ultraspeed"
ANTHROPIC_DEFAULT_HAIKU_MODEL="mimo-v2.5-pro"
ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME="mimo-v2.5-pro"
ANTHROPIC_DEFAULT_SONNET_MODEL="claude-sonnet-4-6[1M]"
ANTHROPIC_DEFAULT_SONNET_MODEL_NAME="claude-sonnet-4-6"
ANTHROPIC_DEFAULT_OPUS_MODEL="mimo-v2.5-pro-ultraspeed[1M]"
ANTHROPIC_DEFAULT_OPUS_MODEL_NAME="mimo-v2.5-pro-ultraspeed"
CLAUDE_CODE_ATTRIBUTION_HEADER="0"
CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY="1"
ANTHROPIC_CUSTOM_HEADERS='{"x-custom-header":"value"}'
```
