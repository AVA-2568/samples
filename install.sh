#!/usr/bin/env bash
set -Eeuo pipefail

XMG_URL="${XMG_URL:-https://github.com/AVA-2568/samples/blob/main/xmg}"
XMG_BIN="/usr/local/bin/xmg"

red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    red "请使用 root 执行安装。"
    exit 1
  fi
}

detect_os() {
  if [[ ! -f /etc/os-release ]]; then
    red "无法识别系统，仅支持 Debian / Ubuntu。"
    exit 1
  fi

  . /etc/os-release

  case "${ID:-}" in
    debian|ubuntu)
      green "检测到系统：${PRETTY_NAME:-$ID}"
      ;;
    *)
      red "当前系统 ${ID:-unknown} 不受支持，仅支持 Debian / Ubuntu。"
      exit 1
      ;;
  esac
}

install_base_deps() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y curl ca-certificates gnupg lsb-release jq openssl uuid-runtime git unzip tar cron ufw python3
}

install_xmg() {
  curl -fsSL "$XMG_URL" -o "$XMG_BIN"
  chmod 0755 "$XMG_BIN"
  green "xmg 已安装到 $XMG_BIN"
}

main() {
  need_root
  detect_os
  install_base_deps
  install_xmg

  green "安装完成。"
  yellow "请执行：xmg"
}

main "$@"
