# amd_termux

在 Android Termux 环境中，通过 `glibc-runner` 安装、运行和维护 [AppleMusicDecrypt](https://github.com/WorldObservationLog/AppleMusicDecrypt)（AMD）的脚本项目。

- 默认安装到 `~/AppleMusicDecrypt`
- 使用 `glibc-runner`（`grun`）在 Termux 内提供 glibc 运行环境
- 源码编译 [Bento4](https://github.com/axiomatic-systems/Bento4)（`mp4extract`/`mp4edit` 等），安装到 `$PREFIX/glibc/bin/`
- 通过 Poetry 在 `.venv` 中管理 AMD 的 Python 依赖
- 生成全局快捷命令 `amd`，一条命令启动

## 环境要求

- Android Termux
- 已执行 `termux-setup-storage`（脚本会检查 `/sdcard`）
- 可正常联网
- 足够空间安装 glibc 相关包、Bento4 源码和 AMD 依赖

## 快速开始

```bash
cd ~/project/amd_termux
bash ./amd.sh
```

进入交互菜单：

```
=== AppleMusicDecrypt 管理 ===
1) 安装 AMD
2) 更新 AMD
3) 编辑配置文件
0) 退出
```

## 菜单说明

### 1) 安装 AMD

首次安装会依次完成：

1. 安装 `glibc-repo` 并刷新 apt 元数据，再安装 `glibc-runner`
2. 安装 glibc 侧依赖：`python-glibc`、`python-pip-glibc`、`libsqlite-glibc`、`cmake-glibc`、`make-glibc`、`clang-glibc`
3. 安装 Termux 原生依赖：`ffmpeg`、`gpac`、`git`
4. 克隆并在 glibc 环境中编译 Bento4，安装 `mp4extract`/`mp4edit`/`mp4info`/`mp4dump`/`mp4encrypt`/`mp4decrypt` 到 `$PREFIX/glibc/bin/`
5. 克隆 AMD 源码到 `~/AppleMusicDecrypt`
6. 在 glibc 环境中创建 `.venv`，安装 Poetry 并执行 `poetry install`
7. 拷贝 `config.example.toml` 为 `config.toml`（如不存在）
8. 写入启动脚本 `~/AppleMusicDecrypt/run.sh` 和全局命令 `$PREFIX/bin/amd`

安装完成后，直接运行：

```bash
amd
```

### 2) 更新 AMD

在 glibc 环境中：

- `git checkout -f` 丢弃本地修改
- `git pull` 拉取最新源码
- `poetry update` 更新依赖
- 用 `config.example.toml` 覆盖 `config.toml`（注意：会重置本地配置）

### 3) 编辑配置文件

用 `$EDITOR`（默认 `vi`）打开 `~/AppleMusicDecrypt/config.toml`，不存在时自动从模板创建。

## 关键实现细节

- `glibc-runner` 的 `grun` 入口是 `source glibc-runner.sh $@`（无引号），直接用 `grun -s bash -c '...'` 传脚本会被 word-split。脚本将多行命令写入 `/data/data/com.termux/files/usr/tmp/` 下的无空格临时文件，再用 `grun -s bash <tmpfile>` 调用，以避免引号和换行丢失。
- `$PREFIX/bin/amd` 启动器会把 Termux 原生 `PATH` 透传给 glibc 侧的 Python，这样 AMD 调用的 `ffmpeg`、`gpac`（`MP4Box`）都能从 Termux 侧找到。
- Bento4 只走一次源码编译；已存在 `$PREFIX/glibc/bin/mp4extract` 时跳过重建。

## 目录与产物

安装后会生成：

- `~/AppleMusicDecrypt/`：AMD 仓库与 `.venv`
- `~/AppleMusicDecrypt/run.sh`：启动器调用的入口脚本
- `~/AppleMusicDecrypt/config.toml`：用户配置（首次从 `config.example.toml` 复制）
- `~/.cache/Bento4-src/`：Bento4 源码与构建目录
- `$PREFIX/glibc/bin/mp4*`：Bento4 工具
- `$PREFIX/bin/amd`：全局启动命令

## 常见问题

- **`termux-setup-storage` 未执行**：脚本会直接退出，提示先运行 `termux-setup-storage`。
- **`grun` 不可用**：意味着 `glibc-runner` 安装失败，通常是 `glibc-repo` 源未刷新。脚本内部会在首次安装时尝试 `pkg update` / `apt-get update`，失败时需手动排查网络或镜像。
- **AMD 配置被覆盖**：更新时会用 `config.example.toml` 覆盖 `config.toml`，如果有自定义配置请先备份。
