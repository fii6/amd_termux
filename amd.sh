#!/usr/bin/env bash
set -euo pipefail

AMD_DIR="$HOME/AppleMusicDecrypt"
BENTO4_SRC="$HOME/.cache/Bento4-src"
GLIBC_BIN="$PREFIX/glibc/bin"

menu() {
    echo "=== AppleMusicDecrypt 管理 ==="
    echo "1) 安装 AMD"
    echo "2) 更新 AMD"
    echo "3) 编辑配置文件"
    echo "0) 退出"
    printf "请选择: "
}

ensure_pkg() {
    local p
    for p in "$@"; do
        if dpkg -s "$p" >/dev/null 2>&1; then
            echo "[skip] $p 已安装"
        else
            echo "[install] $p"
            pkg install -y "$p"
        fi
    done
}

# grun 的 shebang 是 `source glibc-runner.sh $@`（无引号），传给 -s 的字符串
# 会被 word-split，引号和多行结构全丢。唯一可靠方式是把脚本写到无空格路径的
# 临时文件，再用 `grun -s bash /tmp/x.sh` 调用。
run_in_glibc() {
    local tmp rc
    tmp=$(mktemp /data/data/com.termux/files/usr/tmp/amd-grun.XXXXXX.sh)
    cat >"$tmp"
    chmod +x "$tmp"
    grun -s bash "$tmp"
    rc=$?
    rm -f "$tmp"
    return $rc
}

ensure_glibc_runner() {
    # glibc-runner 在 glibc-repo 提供的 apt 源里，要先装 glibc-repo 并刷新元数据
    if dpkg -s glibc-runner >/dev/null 2>&1 && command -v grun >/dev/null 2>&1; then
        echo "[skip] glibc-runner 已安装"
        return 0
    fi
    ensure_pkg glibc-repo
    if ! apt-cache show glibc-runner >/dev/null 2>&1; then
        echo "[update] 刷新 apt 元数据以识别 glibc-repo"
        pkg update -y || apt-get update -y || true
    fi
    ensure_pkg glibc-runner
    command -v grun >/dev/null 2>&1 || { echo "grun 不可用，安装失败"; exit 1; }
}

install_amd() {
    [ -d /sdcard ] || { echo "请先执行: termux-setup-storage"; exit 1; }

    ensure_glibc_runner
    ensure_pkg python-glibc python-pip-glibc \
        libsqlite-glibc \
        cmake-glibc make-glibc clang-glibc \
        ffmpeg gpac git

    # Bento4: Termux-glibc 仓库没有，源码编译 mp4extract/mp4edit
    if [ ! -x "$GLIBC_BIN/mp4extract" ]; then
        rm -rf "$BENTO4_SRC"
        git clone --depth=1 https://github.com/axiomatic-systems/Bento4 "$BENTO4_SRC"
        run_in_glibc <<EOF
set -euo pipefail
cd '$BENTO4_SRC'
mkdir -p cmakebuild && cd cmakebuild
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j\$(nproc)
EOF
        install -m755 "$BENTO4_SRC"/cmakebuild/mp4{extract,edit,info,dump,encrypt,decrypt} "$GLIBC_BIN/" 2>/dev/null || true
    fi

    # AMD 源码
    if [ ! -d "$AMD_DIR" ]; then
        git clone https://github.com/WorldObservationLog/AppleMusicDecrypt "$AMD_DIR"
    fi

    # 在 glibc 环境里建 venv + 装 poetry + poetry install
    run_in_glibc <<EOF
set -euo pipefail
cd '$AMD_DIR'
[ -d .venv ] || python3 -m venv .venv
. .venv/bin/activate
pip install -U pip setuptools wheel
pip install poetry
poetry config virtualenvs.in-project true
poetry env use python3
poetry install
[ -f config.toml ] || cp config.example.toml config.toml
EOF

    # 固定的 run.sh，供启动器 exec；避免启动器里再往 grun 传多 token 字符串
    cat > "$AMD_DIR/run.sh" <<EOF
#!/usr/bin/env bash
set -e
cd '$AMD_DIR'
exec .venv/bin/python main.py
EOF
    chmod +x "$AMD_DIR/run.sh"

    # 启动器：Termux 原生 ffmpeg/gpac 的 PATH 透给 glibc python
    cat > "$PREFIX/bin/amd" <<EOF
#!/usr/bin/env bash
export PATH="\$PATH:$PREFIX/bin"
exec grun -s bash '$AMD_DIR/run.sh'
EOF
    chmod +x "$PREFIX/bin/amd"

    echo "安装完成，可运行: amd"
}

update_amd() {
    run_in_glibc <<EOF
set -euo pipefail
cd '$AMD_DIR'
git checkout -f
git pull
poetry update
cp config.example.toml config.toml
EOF
    echo "更新完成"
}

edit_config() {
    cd "$AMD_DIR" || { echo "尚未安装"; return 1; }
    [ -f config.toml ] || cp config.example.toml config.toml
    "${EDITOR:-vi}" config.toml
}

while true; do
    menu
    read -r c
    case "$c" in
        1) install_amd ;;
        2) update_amd ;;
        3) edit_config ;;
        0) exit 0 ;;
        *) echo "无效选择" ;;
    esac
done
