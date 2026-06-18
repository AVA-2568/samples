#!/usr/bin/env bash
set -Eeuo pipefail

XMG_URL="${XMG_URL:-https://github.com/AVA-2568/samples/main/xmg}"
XMG_BIN="/usr/local/bin/xmg"

red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }

need_root() {
  [[ "${EUID}" -eq 0 ]] || { red "请使用 root 执行安装。"; exit 1; }
}

detect_os() {
  [[ -f /etc/os-release ]] || { red "无法识别系统，仅支持 Debian / Ubuntu。"; exit 1; }

  # shellcheck disable=SC1091
  . /etc/os-release

  OS_ID="${ID:-}"
  OS_CODENAME="${VERSION_CODENAME:-}"

  case "$OS_ID" in
    debian|ubuntu)
      green "检测到系统：${PRETTY_NAME:-$OS_ID}"
      ;;
    *)
      red "仅支持 Debian / Ubuntu，当前：${OS_ID:-unknown}"
      exit 1
      ;;
  esac
}

backup_apt_sources() {
  local backup_dir="/root/apt-sources-backup-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$backup_dir"

  [[ -f /etc/apt/sources.list ]] && cp -a /etc/apt/sources.list "$backup_dir/sources.list"
  [[ -d /etc/apt/sources.list.d ]] && cp -a /etc/apt/sources.list.d "$backup_dir/sources.list.d"

  green "APT 源已备份到：$backup_dir"
}

comment_bad_apt_lines() {
  find /etc/apt/sources.list.d /etc/apt -maxdepth 2 -type f \( -name "*.list" -o -name "sources.list" \) 2>/dev/null \
    -exec sed -i \
      -e 's|^deb cdrom:|# deb cdrom:|' \
      -e 's|^deb .*bullseye/updates|# &|' \
      -e 's|^deb .*deb.debian.org/debian bullseye-backports|# &|' \
      -e 's|^deb .*security.debian.org bullseye/updates|# &|' \
      {} \;
}

repair_debian_bullseye_sources() {
  yellow "检测到 Debian 11 bullseye，正在修复常见 APT 源错误..."

  backup_apt_sources
  comment_bad_apt_lines

  cat > /etc/apt/sources.list <<'EOF'
deb http://deb.debian.org/debian bullseye main contrib non-free
deb http://deb.debian.org/debian bullseye-updates main contrib non-free
deb http://security.debian.org/debian-security bullseye-security main contrib non-free
deb http://archive.debian.org/debian bullseye-backports main contrib non-free
EOF

  cat > /etc/apt/apt.conf.d/99xmg-archive <<'EOF'
Acquire::Check-Valid-Until "false";
EOF

  green "Debian bullseye APT 源修复完成。"
}

repair_debian_bookworm_sources() {
  yellow "检测到 Debian 12 bookworm，正在修复基础 APT 源..."

  backup_apt_sources
  comment_bad_apt_lines

  cat > /etc/apt/sources.list <<'EOF'
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
EOF

  green "Debian bookworm APT 源修复完成。"
}

repair_ubuntu_sources_basic() {
  yellow "检测到 Ubuntu，尝试修复常见无效源..."

  backup_apt_sources
  comment_bad_apt_lines

  if [[ -n "${OS_CODENAME:-}" ]]; then
    cat > /etc/apt/sources.list <<EOF
deb http://archive.ubuntu.com/ubuntu ${OS_CODENAME} main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu ${OS_CODENAME}-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu ${OS_CODENAME}-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu ${OS_CODENAME}-security main restricted universe multiverse
EOF
  fi

  green "Ubuntu APT 源基础修复完成。"
}

apt_update_safe() {
  yellow "正在执行 apt-get update..."

  if apt-get update -y; then
    green "APT 更新成功。"
    return 0
  fi

  yellow "APT 更新失败，尝试自动修复已知源错误。"

  case "${OS_ID}:${OS_CODENAME}" in
    debian:bullseye)
      repair_debian_bullseye_sources
      ;;
    debian:bookworm)
      repair_debian_bookworm_sources
      ;;
    ubuntu:*)
      repair_ubuntu_sources_basic
      ;;
    *)
      red "当前系统版本暂不支持自动修复 APT 源：${OS_ID}:${OS_CODENAME}"
      return 1
      ;;
  esac

  apt-get clean
  rm -rf /var/lib/apt/lists/*

  yellow "重新执行 apt-get update..."
  apt-get update -y
}

install_deps() {
  export DEBIAN_FRONTEND=noninteractive

  apt_update_safe

  apt-get install -y \
    curl ca-certificates gnupg lsb-release jq openssl uuid-runtime \
    git unzip tar cron ufw python3 dnsutils iproute2
}

install_xmg() {
  curl -fsSL "$XMG_URL" -o "$XMG_BIN"
  chmod 0755 "$XMG_BIN"
  green "xmg 已安装到 $XMG_BIN"
}

main() {
  need_root
  detect_os
  install_deps
  install_xmg
  green "安装完成，请执行：xmg"
}

main "$@"
