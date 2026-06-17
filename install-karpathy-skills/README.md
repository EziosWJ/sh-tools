# install-karpathy-skills

在当前目录下载 Andrej Karpathy 的 `CLAUDE.md`，并创建与本仓库相同形式的软链接：

```bash
AGENTS.md -> ./CLAUDE.md
```

## 使用方式

### 本地执行

```bash
bash install-karpathy-skills.sh
```

### 一键远程执行

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/EziosWJ/sh-tools/master/install-karpathy-skills/install-karpathy-skills.sh)
```

## 脚本行为

脚本会执行两步：

```bash
curl -fsSL -o CLAUDE.md https://raw.githubusercontent.com/forrestchang/andrej-karpathy-skills/main/CLAUDE.md
ln -sfn ./CLAUDE.md AGENTS.md
```

说明：

- 会覆盖当前目录已有的 `CLAUDE.md`
- 会将 `AGENTS.md` 重建为指向 `./CLAUDE.md` 的软链接
