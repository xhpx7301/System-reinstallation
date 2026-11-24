#!/usr/bin/env sh
# One-click installer for SR (Interactive menu for https://github.com/bin456789/reinstall)
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/<YOUR_USER>/<YOUR_REPO>/main/install.sh | bash
#   bash install.sh [--cn] [--force] [--no-prefetch] [--user] [--uninstall]

set -eu

# Replace with your repository's raw base URL after pushing to GitHub
DEFAULT_REPO_RAW="https://raw.githubusercontent.com/<YOUR_USER>/<YOUR_REPO>/main"
SR_REPO_RAW="${SR_REPO_RAW:-$DEFAULT_REPO_RAW}"
SR_REPO_RAW_CN="${SR_REPO_RAW_CN:-}"

OPT_FORCE=0
OPT_CN=0
OPT_NO_PREFETCH=0
OPT_USER=0
OPT_UNINSTALL=0
OPT_REMOTE=0

info() { printf '[SR-INSTALL] %s\n' "$*"; }
warn() { printf '[SR-WARN   ] %s\n' "$*" >&2; }
err()  { printf '[SR-ERROR  ] %s\n' "$*" >&2; exit 1; }

show_help() {
    cat <<EOF
SR 一键安装脚本

用法:
  curl -fsSL <RAW_URL>/install.sh | bash
  curl -fsSL <RAW_URL>/install.sh | bash -s -- [选项]

选项:
  --raw-url URL   指定托管 sr 脚本的 Raw 基础 URL
  --cn            优先使用国内镜像 (cnb.cool) 预拉取 reinstall.sh
  --no-prefetch   安装时不预拉取上游 reinstall.sh
  --force, -f     若系统已有同名 sr/SR 命令则强制覆盖
  --user          强制安装到用户目录 (~/.local/bin)
  --remote        即使本地存在 ./sr 也从远程拉取
  --uninstall     卸载已安装的 sr / SR
  -h, --help      显示此帮助
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --raw-url)
            [ "$#" -ge 2 ] || err "--raw-url 需要参数"
            SR_REPO_RAW="$2"
            OPT_REMOTE=1
            shift 2
            ;;
        --cn)
            OPT_CN=1
            shift
            ;;
        --no-prefetch)
            OPT_NO_PREFETCH=1
            shift
            ;;
        -f|--force)
            OPT_FORCE=1
            shift
            ;;
        --user)
            OPT_USER=1
            shift
            ;;
        --remote)
            OPT_REMOTE=1
            shift
            ;;
        --uninstall)
            OPT_UNINSTALL=1
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            err "未知参数: $1 (使用 --help 查看用法)"
            ;;
    esac
done

# Determine install directories & privilege wrapper
SUDO=""
if [ "$OPT_USER" -eq 1 ]; then
    BIN_DIR="$HOME/.local/bin"
    DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/sr"
    CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sr"
elif [ "$(id -u)" -eq 0 ]; then
    BIN_DIR="/usr/local/bin"
    DATA_DIR="/usr/local/share/sr"
    CONF_DIR="/etc/sr"
elif command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
    BIN_DIR="/usr/local/bin"
    DATA_DIR="/usr/local/share/sr"
    CONF_DIR="/etc/sr"
else
    warn "当前非 root 且未检测到 sudo，将安装到用户目录 $HOME/.local/bin (实际重装时仍需 root 权限)。"
    BIN_DIR="$HOME/.local/bin"
    DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/sr"
    CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sr"
fi

SR_BIN="$BIN_DIR/sr"
SR_ALIAS="$BIN_DIR/SR"

if [ "$OPT_UNINSTALL" -eq 1 ]; then
    info "正在卸载 SR ..."
    $SUDO rm -f "$SR_BIN" "$SR_ALIAS"
    $SUDO rm -rf "$DATA_DIR" "$CONF_DIR"
    info "卸载完成。"
    exit 0
fi

# Ensure required tools (bash + curl/wget)
install_missing_deps() {
    need_bash=0
    need_dl=0
    command -v bash >/dev/null 2>&1 || need_bash=1
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        need_dl=1
    fi

    [ "$need_bash" -eq 0 ] && [ "$need_dl" -eq 0 ] && return 0

    pkgs=""
    [ "$need_bash" -eq 1 ] && pkgs="$pkgs bash"
    [ "$need_dl" -eq 1 ] && pkgs="$pkgs curl"

    if [ "$(id -u)" -ne 0 ] && [ -z "$SUDO" ]; then
        err "缺少必要工具:$pkgs，且无 root/sudo 权限自动安装，请先手动安装。"
    fi

    info "正在安装缺少的依赖:$pkgs ..."
    if command -v apk >/dev/null 2>&1; then
        $SUDO apk add --no-cache $pkgs
    elif command -v apt-get >/dev/null 2>&1; then
        $SUDO apt-get update -qq && $SUDO apt-get install -y -qq $pkgs
    elif command -v dnf >/dev/null 2>&1; then
        $SUDO dnf install -y -q $pkgs
    elif command -v yum >/dev/null 2>&1; then
        $SUDO yum install -y -q $pkgs
    elif command -v pacman >/dev/null 2>&1; then
        $SUDO pacman -Sy --noconfirm $pkgs
    else
        err "无法识别包管理器，请手动安装:$pkgs"
    fi
}

download_to() {
    dl_url="$1"
    dl_dest="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout 10 --max-time 60 "$dl_url" -o "$dl_dest"
    elif command -v wget >/dev/null 2>&1; then
        wget -q --timeout=15 -O "$dl_dest" "$dl_url"
    else
        return 1
    fi
}

ask_overwrite_tty() {
    existing_path="$1"
    if [ "$OPT_FORCE" -eq 1 ]; then
        return 0
    fi
    # Check if existing file is already our SR script
    if grep -q "bin456789/reinstall" "$existing_path" 2>/dev/null; then
        return 0
    fi
    warn "检测到已有非 SR 的同名命令: $existing_path"
    if [ -r /dev/tty ]; then
        printf '是否覆盖 %s？[y/N]: ' "$existing_path" >/dev/tty
        ans=""
        IFS= read -r ans </dev/tty || true
        case "$ans" in
            [yY]|[yY][eE][sS]) return 0 ;;
        esac
    fi
    err "为避免误覆盖已有命令，已中止安装（如需覆盖请加 --force 参数）。"
}

check_conflicts() {
    for name in sr SR; do
        found=""
        found=$(command -v "$name" 2>/dev/null || true)
        if [ -n "$found" ] && [ "$found" != "$SR_BIN" ] && [ "$found" != "$SR_ALIAS" ]; then
            if ! grep -q "bin456789/reinstall" "$found" 2>/dev/null; then
                warn "系统中存在另一处命令 '$name' ($found)，可能影响快捷调用优先级。"
            fi
        fi
    done
    [ -e "$SR_BIN" ] && ask_overwrite_tty "$SR_BIN"
    [ -e "$SR_ALIAS" ] && [ ! -L "$SR_ALIAS" ] && ask_overwrite_tty "$SR_ALIAS"
    return 0
}

install_missing_deps
check_conflicts

TMP_SR="/tmp/sr.install.$$"
trap 'rm -f "$TMP_SR"' EXIT INT TERM

SCRIPT_DIR=""
if [ -n "${0:-}" ] && [ -f "$0" ] && grep -q "SR-INSTALL" "$0" 2>/dev/null; then
    SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
fi

INSTALLED_FROM_URL=""
if [ "$OPT_REMOTE" -eq 0 ] && [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/sr" ]; then
    info "使用本地脚本: $SCRIPT_DIR/sr"
    cp "$SCRIPT_DIR/sr" "$TMP_SR"
else
    case "$SR_REPO_RAW" in
        *"<YOUR_USER>"*|*"<YOUR_REPO>"*)
            err "请先将 install.sh 中的 DEFAULT_REPO_RAW 替换为你的仓库地址，或通过 --raw-url / SR_REPO_RAW 指定下载地址。"
            ;;
    esac
    SR_URL="${SR_REPO_RAW%/}/sr"
    info "正在下载 sr 脚本: $SR_URL"
    if ! download_to "$SR_URL" "$TMP_SR"; then
        if [ -n "$SR_REPO_RAW_CN" ]; then
            SR_URL_CN="${SR_REPO_RAW_CN%/}/sr"
            warn "主源下载失败，尝试备用源: $SR_URL_CN"
            download_to "$SR_URL_CN" "$TMP_SR" || err "无法下载 sr 脚本。"
            INSTALLED_FROM_URL="$SR_URL_CN"
        else
            err "无法下载 sr 脚本: $SR_URL"
        fi
    else
        INSTALLED_FROM_URL="$SR_URL"
    fi
fi

# Normalize CRLF just in case and verify content
sed -i 's/\r$//' "$TMP_SR" 2>/dev/null || true
grep -q "SR_VERSION=" "$TMP_SR" 2>/dev/null || err "获取到的 sr 文件内容校验失败。"

$SUDO mkdir -p "$BIN_DIR" "$DATA_DIR" "$CONF_DIR"
$SUDO cp "$TMP_SR" "$SR_BIN"
$SUDO chmod 755 "$SR_BIN"
# On case-sensitive filesystems (standard Linux), register uppercase SR symlink
if ! [ "$SR_BIN" -ef "$SR_ALIAS" ] 2>/dev/null; then
    $SUDO ln -sf "$SR_BIN" "$SR_ALIAS"
fi

# Save initial config if needed (--cn or remote self-update URL)
CONF_FILE="$CONF_DIR/config"
if [ ! -f "$CONF_FILE" ]; then
    MIRROR_VAL="auto"
    [ "$OPT_CN" -eq 1 ] && MIRROR_VAL="cn"
    $SUDO sh -c "umask 077 && cat > '$CONF_FILE' <<EOF
# SR Configuration File
CFG_MIRROR=$MIRROR_VAL
CFG_SSH_KEY=
CFG_SSH_PORT=
CFG_WEB_PORT=
CFG_USERNAME=
CFG_NO_CLOUD_KERNEL=0
CFG_MINIMAL=0
CFG_FORCE_CN=$OPT_CN
CFG_UPSTREAM_COMMIT=main
CFG_SELF_URL=$INSTALLED_FROM_URL
EOF"
    $SUDO chmod 600 "$CONF_FILE" 2>/dev/null || true
fi

# Non-fatal prefetch of upstream reinstall.sh
if [ "$OPT_NO_PREFETCH" -eq 0 ]; then
    info "正在预拉取上游 bin456789/reinstall 脚本..."
    if ! $SUDO "$SR_BIN" update; then
        warn "预拉取 reinstall.sh 失败（不影响 sr 安装，首次进入菜单时会自动重试）。"
    fi
fi

info "安装完成！已注册快捷命令: $SR_BIN 和 $SR_ALIAS"
case ":$PATH:" in
    *":$BIN_DIR:"*)
        info "现在可以直接在终端输入 SR 或 sr 调出管理菜单。"
        ;;
    *)
        warn "$BIN_DIR 不在当前 PATH 中，请执行: export PATH=\"$BIN_DIR:\$PATH\""
        ;;
esac
