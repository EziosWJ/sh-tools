# tmux-helper

tmux 辅助工具集，提供快捷键帮助、会话管理和模板功能。

## 功能特性

### 1. 帮助显示 (`tmux-help`)

快速查看 tmux 快捷键帮助信息。

```bash
tmux-help [分类]           # 显示指定分类帮助
tmux-help -i, --interactive    # 交互模式
tmux-help -s, --search 关键词  # 搜索快捷键
tmux-help -h, --help           # 显示帮助
```

**分类：**
- `session` - 会话管理
- `window` - 窗口操作
- `pane` - 面板操作
- `copy` - 复制模式
- `layout` - 布局管理
- `resize` - 调整大小
- `all` - 显示全部（默认）

### 2. 会话管理 (`tmux-session`)

管理 tmux 会话，支持保存/恢复布局。

```bash
tmux-session create <名称> [目录]  # 创建会话
tmux-session list                  # 列出所有会话
tmux-session switch                # 交互式切换会话
tmux-session kill <名称>           # 终止会话
tmux-session save [名称]           # 保存当前会话布局
tmux-session restore <名称>        # 恢复会话布局
tmux-session template list         # 列出预设模板
tmux-session template create       # 从模板创建会话
tmux-session status                # 显示当前状态
```

### 3. 项目模板系统

预设常用项目模板，快速创建开发环境。

**配置文件位置：** `~/.config/tmux-helper/templates.conf`

```bash
# 格式: 模板名称|工作目录|启动命令
web-project|~/projects/webapp|npm run dev
python-api|~/projects/api|python manage.py runserver
node-server|~/projects/node-app|node server.js
```

### 4. 环境检测

自动检测 tmux 环境，动态显示相关信息。

- tmux 内：显示当前状态信息
- tmux 外：显示可用命令和连接提示

## 安装

### 本地安装

```bash
git clone <repository-url>
cd sh-tools/add-tmux-help
bash add-tmux-help.sh
```

### 一键安装

```bash
curl -fsSL <raw-url>/add-tmux-help.sh | bash
```

### 卸载

```bash
bash add-tmux-help.sh uninstall
```

## 配置

### 配置文件

配置文件位于 `~/.config/tmux-helper/config`：

```bash
# 自动扫描的项目目录（逗号分隔）
TMUX_HELPER_SCAN_DIRS="~/projects,~/work,~/code"

# 会话保存目录
TMUX_HELPER_SESSION_DIR="~/.config/tmux-helper/sessions"

# 模板文件
TMUX_HELPER_TEMPLATE_FILE="~/.config/tmux-helper/templates.conf"

# 默认编辑器
TMUX_HELPER_DEFAULT_EDITOR="vim"

# 交互界面工具（fzf 或 select）
TMUX_HELPER_SELECTOR="fzf"
```

### 可选依赖

- **fzf** - 提供更好的交互式选择界面
- **jq** - 提供 JSON 处理能力

安装可选依赖：
```bash
# Ubuntu/Debian
sudo apt install fzf jq

# macOS
brew install fzf jq
```

## 使用示例

### 帮助显示

```bash
# 显示所有快捷键
tmux-help

# 显示面板操作帮助
tmux-help pane

# 交互模式选择分类
tmux-help -i

# 搜索包含"copy"的快捷键
tmux-help -s copy
```

### 会话管理

```bash
# 创建新会话
tmux-session create myproject ~/projects/myapp

# 列出所有会话
tmux-session list

# 保存当前会话布局
tmux-session save

# 恢复会话布局
tmux-session restore myproject

# 从模板创建会话
tmux-session template create web-project
```

### 模板系统

```bash
# 列出可用模板
tmux-session template list

# 从模板创建会话
tmux-session template create python-api

# 创建自定义模板
# 编辑 ~/.config/tmux-helper/templates.conf
```

## 目录结构

```
add-tmux-help/
├── add-tmux-help.sh          # 安装脚本
├── lib/
│   ├── tmux-help.sh          # 帮助显示模块
│   ├── tmux-session.sh       # session 管理模块
│   └── utils.sh              # 工具函数
├── tmux.conf.example         # 示例配置文件
└── README.md                 # 文档
```

## 兼容性

- **Shell**: bash 4.0+, zsh
- **tmux**: 2.1+
- **操作系统**: Linux, macOS

## 故障排除

### 命令未找到

如果安装后命令未找到，请执行：

```bash
source ~/.bashrc   # bash
source ~/.zshrc    # zsh
```

### 权限问题

如果遇到权限问题：

```bash
chmod +x add-tmux-help.sh
chmod +x lib/*.sh
```

### 配置文件损坏

删除配置目录重新安装：

```bash
rm -rf ~/.config/tmux-helper
bash add-tmux-help.sh
```

## 开发

### 添加新模块

1. 在 `lib/` 目录创建新的 `.sh` 文件
2. 实现 `_main` 函数作为入口
3. 在 `add-tmux-help.sh` 中添加模块安装逻辑

### 代码规范

- 使用 `set -Eeuo pipefail`
- 函数命名：小写+连字符
- 变量命名：大写+下划线
- 添加必要的注释

## 许可证

MIT License