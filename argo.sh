#!/usr/bin/env bash
#
# CloudFlare Argo Tunnel 一键配置脚本
# Repo: https://github.com/74496870/CloudFlare-Argo-Tunnel
#
# 使用方法：
#   wget -N --no-check-certificate \
#     https://raw.githubusercontent.com/74496870/CloudFlare-Argo-Tunnel/main/argo.sh \
#     && bash argo.sh

# ---------- 颜色输出 ----------
red()    { echo -e "\033[31m\033[01m$1\033[0m"; }
green()  { echo -e "\033[32m\033[01m$1\033[0m"; }
yellow() { echo -e "\033[33m\033[01m$1\033[0m"; }

# ---------- 全局常量 ----------
readonly REPO_RAW="https://raw.githubusercontent.com/74496870/CloudFlare-Argo-Tunnel/main"
readonly CF_RELEASE_URL="https://github.com/cloudflare/cloudflared/releases/latest/download"
readonly CF_CERT_FILE="/root/.cloudflared/cert.pem"

# 系统匹配表（索引严格一一对应）
REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "amazon linux" "alpine")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Alpine")
PACKAGE_UPDATE=("apt -y update"   "apt -y update"   "yum -y makecache" "yum -y makecache" "apk update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install"   "yum -y install"   "apk add -f")
PACKAGE_REMOVE=("apt -y remove"   "apt -y remove"   "yum -y remove"    "yum -y remove"    "apk del -f")

# 运行期变量
cpuArch=""
int=""
SYSTEM=""
cloudflaredStatus="未安装"
loginStatus="未登录"

# ---------- 前置检查 ----------
[[ $EUID -ne 0 ]] && yellow "请在 root 用户下运行脚本" && exit 1

detect_system() {
	local sys_candidates=(
		"$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)"
		"$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)"
		"$(lsb_release -sd 2>/dev/null)"
		"$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)"
		"$(grep . /etc/redhat-release 2>/dev/null)"
		"$(grep . /etc/issue 2>/dev/null | cut -d '\' -f1 | sed '/^[ ]*$/d')"
	)
	local SYS=""
	for i in "${sys_candidates[@]}"; do
		if [[ -n "$i" ]]; then SYS="$i"; break; fi
	done

	for ((idx = 0; idx < ${#REGEX[@]}; idx++)); do
		if [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[idx]} ]]; then
			SYSTEM="${RELEASE[idx]}"
			int="$idx"
			break
		fi
	done

	[[ -z "$SYSTEM" ]] && red "不支持当前系统，请使用 Debian/Ubuntu/CentOS/Alma/Rocky/Alpine" && exit 1
}

ensure_cmd() {
	# 用法：ensure_cmd <命令> [安装包名（省略则同命令名）]
	local cmd="$1"
	local pkg="${2:-$1}"
	if ! command -v "$cmd" >/dev/null 2>&1; then
		yellow "未检测到 $cmd，正在安装 $pkg ..."
		${PACKAGE_UPDATE[int]} >/dev/null 2>&1
		${PACKAGE_INSTALL[int]} "$pkg"
	fi
}

archAffix() {
	cpuArch="$(uname -m)"
	case "$cpuArch" in
		i686 | i386)                       cpuArch='386' ;;
		x86_64 | amd64)                    cpuArch='amd64' ;;
		armv5tel | armv6l | armv7 | armv7l) cpuArch='arm' ;;
		armv8 | aarch64)                   cpuArch='aarch64' ;;
		*) red "不支持的 CPU 架构：$cpuArch" && exit 1 ;;
	esac
}

checkCentOS8() {
	if grep -q "CentOS Linux 8" /etc/os-release 2>/dev/null; then
		yellow "检测到 CentOS 8，官方仓库已 EOL。是否升级到 CentOS Stream 8 以确保软件包可安装？"
		read -rp "请输入 [y/N]：" confirmStream
		if [[ "$confirmStream" =~ ^[Yy]$ ]]; then
			yellow "正在升级到 CentOS Stream 8，大约需 10~30 分钟 ..."
			sleep 1
			sed -i -e "s|mirrorlist|#mirrorlist|g" \
			       -e "s|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g" \
			       /etc/yum.repos.d/CentOS-*.repo
			yum clean all && yum makecache
			dnf swap centos-linux-repos centos-stream-repos distro-sync -y
		else
			yellow "已跳过升级，若软件包安装失败请自行处理。"
		fi
	fi
}

checkStatus() {
	if command -v cloudflared >/dev/null 2>&1; then
		cloudflaredStatus="已安装"
	else
		cloudflaredStatus="未安装"
	fi
	if [[ -f "$CF_CERT_FILE" ]]; then
		loginStatus="已登录"
	else
		loginStatus="未登录"
	fi
}

back2menu() {
	green "所选操作执行完成"
	read -rp "请输入 y 退出，或按任意键回到主菜单：" choice
	case "$choice" in
		y | Y) exit 0 ;;
		*) menu ;;
	esac
}

# ---------- 业务函数 ----------
installCloudFlared() {
	if [[ "$cloudflaredStatus" == "已安装" ]]; then
		red "检测到已安装 cloudflared，若需重装请先执行 [8. 卸载]"
		back2menu
		return
	fi
	ensure_cmd wget
	local arch="$cpuArch"
	if [[ "$SYSTEM" == "CentOS" ]]; then
		[[ "$arch" == "amd64" ]] && arch="x86_64"
		local pkg="cloudflared-linux-${arch}.rpm"
		wget -N "${CF_RELEASE_URL}/${pkg}" && rpm -i "$pkg"
		rm -f "$pkg"
	elif [[ "$SYSTEM" == "Alpine" ]]; then
		[[ "$arch" == "aarch64" ]] && arch="arm64"
		local pkg="cloudflared-linux-${arch}"
		wget -N -O /usr/local/bin/cloudflared "${CF_RELEASE_URL}/${pkg}" && chmod +x /usr/local/bin/cloudflared
	else
		[[ "$arch" == "aarch64" ]] && arch="arm64"
		local pkg="cloudflared-linux-${arch}.deb"
		wget -N "${CF_RELEASE_URL}/${pkg}" && dpkg -i "$pkg"
		rm -f "$pkg"
	fi
	if ! command -v cloudflared >/dev/null 2>&1; then
		red "cloudflared 安装失败，请检查网络是否可访问 GitHub"
		back2menu
		return
	fi
	green "请访问下方提示的链接，登录你的 CloudFlare 账号，"
	green "并授权需要使用的域名给 CloudFlare Argo Tunnel。"
	cloudflared tunnel login
	back2menu
}

uninstallCloudFlared() {
	if [[ "$cloudflaredStatus" == "未安装" ]]; then
		red "检测到未安装 cloudflared，无需卸载"
		back2menu
		return
	fi
	${PACKAGE_REMOVE[int]} cloudflared
	rm -f /usr/local/bin/cloudflared
	rm -rf /root/.cloudflared
	green "cloudflared 已卸载完成"
	back2menu
}

makeTunnel() {
	if [[ "$cloudflaredStatus" == "未安装" || "$loginStatus" == "未登录" ]]; then
		red "请先完成 [1. 安装并登录] 再执行本操作"
		back2menu
		return
	fi
	local tunnelName tunnelDomain tunnelUUID tunnelProtocol tunnelPort tunnelFileName
	read -rp "请输入需要创建的隧道名称：" tunnelName
	[[ -z "$tunnelName" ]] && red "隧道名称不能为空" && back2menu && return
	cloudflared tunnel create "$tunnelName"

	read -rp "请输入域名：" tunnelDomain
	[[ -z "$tunnelDomain" ]] && red "域名不能为空" && back2menu && return
	cloudflared tunnel route dns "$tunnelName" "$tunnelDomain"

	cloudflared tunnel list
	read -rp "请输入隧道 UUID（复制 ID 栏的内容）：" tunnelUUID
	[[ -z "$tunnelUUID" ]] && red "UUID 不能为空" && back2menu && return

	read -rp "请输入传输协议 [默认 http]：" tunnelProtocol
	tunnelProtocol="${tunnelProtocol:-http}"

	read -rp "请输入反代端口 [默认 80]：" tunnelPort
	tunnelPort="${tunnelPort:-80}"

	read -rp "请输入配置文件名（保存到 /root/<名称>.yml）：" tunnelFileName
	[[ -z "$tunnelFileName" ]] && tunnelFileName="$tunnelName"

	cat >"/root/${tunnelFileName}.yml" <<EOF
tunnel: ${tunnelName}
credentials-file: /root/.cloudflared/${tunnelUUID}.json
originRequest:
  connectTimeout: 30s
  noTLSVerify: true
ingress:
  - hostname: ${tunnelDomain}
    service: ${tunnelProtocol}://localhost:${tunnelPort}
  - service: http_status:404
EOF
	green "配置文件生成成功：/root/${tunnelFileName}.yml"
	back2menu
}

listTunnel() {
	if [[ "$cloudflaredStatus" == "未安装" || "$loginStatus" == "未登录" ]]; then
		red "请先完成 [1. 安装并登录] 再执行本操作"
		back2menu
		return
	fi
	cloudflared tunnel list
	back2menu
}

runTunnel() {
	if [[ "$cloudflaredStatus" == "未安装" || "$loginStatus" == "未登录" ]]; then
		red "请先完成 [1. 安装并登录] 再执行本操作"
		back2menu
		return
	fi
	ensure_cmd screen
	local ymlLocation screenName
	read -rp "请输入配置文件路径（例：/root/tunnel.yml）：" ymlLocation
	[[ ! -f "$ymlLocation" ]] && red "找不到配置文件：$ymlLocation" && back2menu && return
	read -rp "请输入 Screen 会话名称：" screenName
	[[ -z "$screenName" ]] && red "Screen 会话名不能为空" && back2menu && return
	screen -USdm "$screenName" cloudflared tunnel --config "$ymlLocation" run
	green "隧道已在 Screen 会话 [$screenName] 中运行，请等待 1-3 分钟启动并解析完毕"
	green "可使用 'screen -r $screenName' 查看运行状态；Ctrl+A 再按 D 退出会话而不中断进程"
	back2menu
}

killTunnel() {
	if [[ "$cloudflaredStatus" == "未安装" || "$loginStatus" == "未登录" ]]; then
		red "请先完成 [1. 安装并登录] 再执行本操作"
		back2menu
		return
	fi
	ensure_cmd screen
	local screenName
	read -rp "请输入需要停止的 Screen 会话名称：" screenName
	[[ -z "$screenName" ]] && red "Screen 会话名不能为空" && back2menu && return
	screen -S "$screenName" -X quit
	green "Screen 会话 [$screenName] 已停止"
	back2menu
}

deleteTunnel() {
	if [[ "$cloudflaredStatus" == "未安装" || "$loginStatus" == "未登录" ]]; then
		red "请先完成 [1. 安装并登录] 再执行本操作"
		back2menu
		return
	fi
	local tunnelName
	read -rp "请输入需要删除的隧道名称：" tunnelName
	[[ -z "$tunnelName" ]] && red "隧道名称不能为空" && back2menu && return
	cloudflared tunnel delete "$tunnelName"
	back2menu
}

argoCert() {
	if [[ "$cloudflaredStatus" == "未安装" || "$loginStatus" == "未登录" ]]; then
		red "请先完成 [1. 安装并登录] 再执行本操作"
		back2menu
		return
	fi
	# 重新生成，避免重复追加
	: >/root/private.key
	: >/root/cert.crt
	sed -n "1,5p"  "$CF_CERT_FILE" >>/root/private.key
	sed -n "6,24p" "$CF_CERT_FILE" >>/root/cert.crt
	green "CloudFlare Argo Tunnel 证书已提取："
	yellow "  证书：/root/cert.crt"
	yellow "  私钥：/root/private.key"
	green "提示："
	yellow "  1. 证书仅对已授权的 Argo Tunnel 域名有效"
	yellow "  2. 服务端使用 Argo Tunnel 域名时须使用此证书"
	back2menu
}

updateScript() {
	ensure_cmd wget
	yellow "正在从官方仓库下载最新脚本 ..."
	if wget -N --no-check-certificate -O argo.sh "${REPO_RAW}/argo.sh"; then
		green "脚本更新完毕，即将以新脚本替换当前会话"
		exec bash argo.sh
	else
		red "脚本更新失败，请检查网络"
		back2menu
	fi
}

menu() {
	clear
	checkStatus
	red "=================================="
	red "   CloudFlare Argo Tunnel 一键脚本   "
	red "   Repo: github.com/74496870/CloudFlare-Argo-Tunnel"
	red "=================================="
	green "cloudflared 客户端状态：$cloudflaredStatus"
	green "账户登录状态         ：$loginStatus"
	echo
	echo "1. 安装并登录 cloudflared 客户端"
	echo "2. 配置 Argo Tunnel 隧道"
	echo "3. 列出 Argo Tunnel 隧道"
	echo "4. 运行 Argo Tunnel 隧道（Screen 后台）"
	echo "5. 停止 Argo Tunnel 隧道（Screen 会话）"
	echo "6. 删除 Argo Tunnel 隧道"
	echo "7. 获取 Argo Tunnel 证书"
	echo "8. 卸载 cloudflared 客户端"
	echo "9. 更新本脚本"
	echo "0. 退出脚本"
	echo
	local choice
	read -rp "请输入选项：" choice
	case "$choice" in
		1) installCloudFlared ;;
		2) makeTunnel ;;
		3) listTunnel ;;
		4) runTunnel ;;
		5) killTunnel ;;
		6) deleteTunnel ;;
		7) argoCert ;;
		8) uninstallCloudFlared ;;
		9) updateScript ;;
		0) exit 0 ;;
		*) red "无效选项：$choice"; sleep 1; menu ;;
	esac
}

# ---------- 入口 ----------
detect_system
ensure_cmd curl
ensure_cmd wget
archAffix
checkCentOS8
menu
