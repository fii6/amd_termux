#!/usr/bin/env bash
set -euo pipefail

menu() {
    echo "=== AppleMusicDecrypt 管理 ==="
    echo "1) 安装 AMD"
    echo "2) 更新 AMD"
    echo "3) 编辑配置文件"
    echo "0) 退出"
    printf "请选择: "
}

install_amd() {
    [ -d /sdcard ] || { echo "请先执行: termux-setup-storage"; exit 1; }

    pkg update -y
    pkg install -y proot-distro git

    cat > "$PREFIX/bin/amd" <<'EOF'
#!/usr/bin/env bash
proot-distro login debian -- bash -lc "cd ~/AppleMusicDecrypt && poetry run python main.py"
EOF
    chmod +x "$PREFIX/bin/amd"

    proot-distro install debian || true

    DEB_ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/debian"

    cat > "$DEB_ROOTFS/root/deploy-inside-debian.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
apt update -y
apt install -y wget build-essential zlib1g-dev libffi-dev libssl-dev libsqlite3-dev libbz2-dev libreadline-dev libncursesw5-dev libgdbm-dev libc6-dev tk-dev uuid-dev git python3-venv vim

cd /root
wget -O py311.tgz https://www.python.org/ftp/python/3.11.9/Python-3.11.9.tgz
tar xf py311.tgz
cd Python-3.11.9
./configure --prefix=/usr/local --enable-optimizations
make -j"$(nproc)"
make altinstall
cd /root
rm -rf Python-3.11.9 py311.tgz

python3.11 -m ensurepip
python3.11 -m pip install -U pip setuptools wheel poetry
ln -sf /usr/local/bin/poetry /usr/bin/poetry || true

cd /root
[ -d AppleMusicDecrypt ] || git clone https://github.com/WorldObservationLog/AppleMusicDecrypt
cd AppleMusicDecrypt

bash ./tools/install-deps.sh || true
poetry env use python3.11
poetry install

[ -f config.toml ] || cp config.example.toml config.toml
EOF

    chmod +x "$DEB_ROOTFS/root/deploy-inside-debian.sh"
    proot-distro login debian -- bash /root/deploy-inside-debian.sh
    echo "安装完成，可运行: amd"
}

update_amd() {
    proot-distro login debian -- bash -lc "
        cd ~/AppleMusicDecrypt
        git checkout -f
        git pull
        poetry update
        cp config.example.toml config.toml
    "
    echo "更新完成"
}

edit_config() {
    proot-distro login debian -- bash -lc "
        cd ~/AppleMusicDecrypt
        [ -f config.toml ] || cp config.example.toml config.toml
        vim config.toml
    "
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
