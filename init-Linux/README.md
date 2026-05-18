# init-Linux

Linux / WSL 开发环境初始化脚本，支持交互式菜单和命令行参数两种使用方式。

## 功能

- 检测系统环境（Ubuntu / Debian / WSL）
- 配置软件源（清华镜像等）
- 安装基础依赖（curl、wget、git 等）
- 安装 zsh + Oh My Zsh + Powerlevel10k
- 安装 nvm + Node.js LTS
- 安装 uv
- 修复 nvm / uv 环境变量

脚本设计为幂等，可重复执行，不会破坏已有配置。

## 使用方式

### 本地执行

```bash
bash init-linux.sh
```

无参数进入交互式菜单，也可传入子命令直接执行特定步骤：

```bash
bash init-linux.sh all      # 一键安装全部
bash init-linux.sh zsh      # 仅安装 zsh
bash init-linux.sh nvm      # 仅安装 nvm
bash init-linux.sh node     # 仅安装 Node.js LTS
```

### 一键远程执行

```bash
curl -fsSL https://raw.githubusercontent.com/EziosWJ/sh-tools/master/init-Linux/init-linux.sh | bash
```

## 支持范围

- Ubuntu
- Debian
- WSL Ubuntu

其他没有 `apt` 的系统不在主要支持范围内。
