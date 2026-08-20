#!/bin/sh
# ttpos CLI 安装脚本。
#
#   curl -fsSL https://raw.githubusercontent.com/ZonEaseTech/ttpos-cli/main/install.sh | sh
#
# 重复运行即升级；卸载用 `sh install.sh --uninstall`。
#
# 用 POSIX sh 而不是 bash：目标机可能是精简容器（Alpine 只有 busybox ash），
# 装个 CLI 不该先要求装 bash。因此下面不使用数组、[[ ]]、local 等 bashism。
set -eu

REPO="ZonEaseTech/ttpos-cli"
BIN="ttpos"
INSTALL_DIR="${TTPOS_INSTALL_DIR:-$HOME/.local/bin}"
VERSION="${VERSION:-latest}"

info() { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "缺少 $1，请先安装"; }

detect_platform() {
	os=$(uname -s)
	arch=$(uname -m)
	case "$os" in
		Linux)  os=linux ;;
		Darwin) os=darwin ;;
		*) die "暂不支持的系统: $os（当前提供 Linux 与 macOS；Windows 尚未发布）" ;;
	esac
	case "$arch" in
		x86_64|amd64)  arch=amd64 ;;
		arm64|aarch64) arch=arm64 ;;
		*) die "暂不支持的架构: $arch（当前提供 amd64 与 arm64）" ;;
	esac
	printf '%s_%s' "$os" "$arch"
}

# resolve_version 把 latest 解析成具体版本号。走 GitHub API 而不是猜测
# releases/latest 的重定向地址：重定向形式不是稳定契约。
resolve_version() {
	if [ "$VERSION" != "latest" ]; then
		printf '%s' "${VERSION#v}"
		return
	fi
	tag=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
		| sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n 1)
	[ -n "$tag" ] || die "取不到最新版本号，可显式指定：VERSION=0.1.0 sh install.sh"
	printf '%s' "${tag#v}"
}

# verify_checksum 校验后才解压。SHA256SUMS 与产物同源（同一 Release），
# 这挡的是传输损坏与镜像被替换，不是"发布者被攻破"——后者要签名才能解决，
# 当前未做，如实说明而不是假装有。
verify_checksum() {
	file=$1; sums=$2
	# 先确认有校验工具再去读 SHA256SUMS：反过来的话，缺工具的机器会先撞上
	# "SHA256SUMS 里没有记录"，把用户指向完全错误的方向。
	if command -v sha256sum >/dev/null 2>&1; then
		got=$(sha256sum "$file" | awk '{print $1}')
	elif command -v shasum >/dev/null 2>&1; then
		got=$(shasum -a 256 "$file" | awk '{print $1}')
	else
		die "找不到 sha256sum 或 shasum，无法校验完整性；拒绝在不校验的情况下安装"
	fi
	want=$(grep " $(basename "$file")\$" "$sums" | awk '{print $1}')
	[ -n "$want" ] || die "SHA256SUMS 里没有 $(basename "$file") 的记录"
	[ "$want" = "$got" ] || die "校验和不符，已中止安装（期望 $want，实得 $got）"
}

# check_path 在装完后提示 PATH 问题。macOS 的默认 PATH 不含 ~/.local/bin，
# 装完敲不出命令是很打击人的开场，所以这里给出可直接粘贴的补救命令。
check_path() {
	case ":$PATH:" in
		*":$INSTALL_DIR:"*) return 0 ;;
	esac
	warn ""
	warn "⚠️  $INSTALL_DIR 不在 PATH 里，现在直接敲 $BIN 会提示 command not found。"
	warn "   加进去（按你用的 shell 选一条，然后重开终端）："
	warn "     echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.zshrc     # zsh（macOS 默认）"
	warn "     echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.bashrc    # bash"
	warn "   或直接用完整路径：$INSTALL_DIR/$BIN"
}

uninstall() {
	if [ -f "$INSTALL_DIR/$BIN" ]; then
		rm -f "$INSTALL_DIR/$BIN"
		info "已删除 $INSTALL_DIR/$BIN"
	else
		info "$INSTALL_DIR/$BIN 不存在，无需删除"
	fi
	info ""
	info "以下内容**保留**，需要时请自行删除："
	info "  ~/.ttpos/          凭证、默认商户配置、gateway 本地数据"
	info "  agent skills       如果装过，在各 agent 自己的 skills 目录下"
	info "（不自动删除是因为它们含登录状态与本地配置，误删需要重新登录。）"
}

main() {
	if [ "${1:-}" = "--uninstall" ]; then
		uninstall
		return
	fi

	need curl
	need tar

	platform=$(detect_platform)
	version=$(resolve_version)
	asset="${BIN}_${version}_${platform}.tar.gz"
	base="https://github.com/$REPO/releases/download/v$version"

	info "安装 $BIN $version ($platform) → $INSTALL_DIR"

	tmp=$(mktemp -d)
	# 任何路径退出都清理临时目录，包括 set -e 触发的中途失败。
	trap 'rm -rf "$tmp"' EXIT INT TERM

	curl -fsSL "$base/$asset"      -o "$tmp/$asset"    || die "下载失败: $base/$asset"
	curl -fsSL "$base/SHA256SUMS"  -o "$tmp/SHA256SUMS" || die "下载 SHA256SUMS 失败"
	verify_checksum "$tmp/$asset" "$tmp/SHA256SUMS"

	tar -xzf "$tmp/$asset" -C "$tmp"
	[ -f "$tmp/$BIN" ] || die "归档里没有 $BIN"

	mkdir -p "$INSTALL_DIR"
	# 先写同目录临时文件再 mv：mv 在同一文件系统内是原子的，避免"正在运行的
	# 旧二进制被写坏"以及中途失败留下半个文件。
	cp "$tmp/$BIN" "$INSTALL_DIR/.$BIN.new"
	chmod 755 "$INSTALL_DIR/.$BIN.new"
	mv -f "$INSTALL_DIR/.$BIN.new" "$INSTALL_DIR/$BIN"

	info "✅ 已安装: $("$INSTALL_DIR/$BIN" --version)"
	check_path
	info ""
	info "下一步："
	info "  1. $BIN auth login        浏览器打开打印出的网址并登录（命令会等待，完成后退出）"
	info "  2. $BIN shop use <店名>   选默认商户"
	info "  3. $BIN order list        开始查"
	info ""
	info "不用另开窗口跑 gateway serve。远端/Coder 才需要："
	info "  $BIN gateway serve --public-url https://..."
	info "  $BIN auth login --gateway https://..."
	info ""
	info "随时可运行 $BIN doctor 自查环境。"
}

main "$@"
