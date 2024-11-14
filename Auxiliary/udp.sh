#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查是否为root用户
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}错误：此脚本需要root权限运行！${NC}"
        exit 1
    fi
}

# 检查是否为Debian系统
check_debian() {
    if ! grep -qi "debian" /etc/os-release && ! grep -qi "ubuntu" /etc/os-release; then
        echo -e "${RED}错误：此脚本仅支持Debian/Ubuntu系统！${NC}"
        exit 1
    fi
}

# 安装必要的软件包
install_packages() {
    echo -e "${YELLOW}正在安装必要的软件包...${NC}"
    apt update
    apt install -y iptables ip6tables net-tools
}

# 检测IP版本
detect_ip_version() {
    local ip=$1
    # 检查是否为IPv4地址
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a OCTETS <<< "$ip"
        for octet in "${OCTETS[@]}"; do
            if [[ $octet -gt 255 || $octet -lt 0 ]]; then
                echo "invalid"
                return
            fi
        done
        echo "ipv4"
        return
    fi
    
    # 检查是否为IPv6地址
    if [[ $ip =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$ ]]; then
        echo "ipv6"
        return
    fi
    
    echo "invalid"
}

# 配置IPv4到IPv4的转发
configure_ipv4_to_ipv4() {
    local src_ip=$1
    local dst_ip=$2
    
    echo -e "${YELLOW}配置IPv4到IPv4的转发...${NC}"
    
    # 配置NAT规则
    iptables -t nat -C PREROUTING -p udp --dst "$src_ip" -j DNAT --to-destination "$dst_ip" 2>/dev/null || \
    iptables -t nat -A PREROUTING -p udp --dst "$src_ip" -j DNAT --to-destination "$dst_ip"
    
    iptables -t nat -C POSTROUTING -s "$dst_ip" -j SNAT --to-source "$dst_ip" 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s "$dst_ip" -j SNAT --to-source "$dst_ip"
    
    # 保存规则
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4
    
    # 创建规则脚本
    create_rules_script "v4-v4" "$src_ip" "$dst_ip"
}

# 配置IPv6到IPv6的转发
configure_ipv6_to_ipv6() {
    local src_ip=$1
    local dst_ip=$2
    
    echo -e "${YELLOW}配置IPv6到IPv6的转发...${NC}"
    
    # 启用IPv6 NAT
    modprobe nf_nat_ipv6
    
    # 配置NAT规则
    ip6tables -t nat -C PREROUTING -p udp --dst "$src_ip" -j DNAT --to-destination "$dst_ip" 2>/dev/null || \
    ip6tables -t nat -A PREROUTING -p udp --dst "$src_ip" -j DNAT --to-destination "$dst_ip"
    
    ip6tables -t nat -C POSTROUTING -s "$dst_ip" -j SNAT --to-source "$src_ip" 2>/dev/null || \
    ip6tables -t nat -A POSTROUTING -s "$dst_ip" -j SNAT --to-source "$src_ip"
    
    # 保存规则
    mkdir -p /etc/iptables
    ip6tables-save > /etc/iptables/rules.v6
    
    # 创建规则脚本
    create_rules_script "v6-v6" "$src_ip" "$dst_ip"
}

# 配置IPv6到IPv4的转发
configure_ipv6_to_ipv4() {
    local src_ip=$1
    local dst_ip=$2
    
    echo -e "${YELLOW}配置IPv6到IPv4的转发...${NC}"
    
    # 启用IPv6 NAT
    modprobe nf_nat_ipv6
    
    # 配置NAT规则
    ip6tables -t nat -C PREROUTING -p udp --dst "$src_ip" -j DNAT --to-destination "$dst_ip" 2>/dev/null || \
    ip6tables -t nat -A PREROUTING -p udp --dst "$src_ip" -j DNAT --to-destination "$dst_ip"
    
    iptables -t nat -C POSTROUTING -s "$dst_ip" -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s "$dst_ip" -j MASQUERADE
    
    # 保存规则
    mkdir -p /etc/iptables
    ip6tables-save > /etc/iptables/rules.v6
    iptables-save > /etc/iptables/rules.v4
    
    # 创建规则脚本
    create_rules_script "v6-v4" "$src_ip" "$dst_ip"
}

# 配置IPv4到IPv6的转发
configure_ipv4_to_ipv6() {
    local src_ip=$1
    local dst_ip=$2
    
    echo -e "${YELLOW}配置IPv4到IPv6的转发...${NC}"
    
    # 启用IPv6 NAT
    modprobe nf_nat_ipv6
    
    # 配置NAT规则
    iptables -t nat -C PREROUTING -p udp --dst "$src_ip" -j DNAT --to-destination "$dst_ip" 2>/dev/null || \
    iptables -t nat -A PREROUTING -p udp --dst "$src_ip" -j DNAT --to-destination "$dst_ip"
    
    ip6tables -t nat -C POSTROUTING -s "$dst_ip" -j MASQUERADE 2>/dev/null || \
    ip6tables -t nat -A POSTROUTING -s "$dst_ip" -j MASQUERADE
    
    # 保存规则
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4
    ip6tables-save > /etc/iptables/rules.v6
    
    # 创建规则脚本
    create_rules_script "v4-v6" "$src_ip" "$dst_ip"
}

# 创建统一的规则脚本
create_rules_script() {
    local type=$1
    local src_ip=$2
    local dst_ip=$3
    local script_path="/usr/local/bin/UDP-rules-${type}.sh"
    
    case $type in
        "v4-v4")
            cat <<EOF >$script_path
#!/bin/bash
iptables -t nat -C PREROUTING -p udp --dst $src_ip -j DNAT --to-destination $dst_ip || \
iptables -t nat -A PREROUTING -p udp --dst $src_ip -j DNAT --to-destination $dst_ip

iptables -t nat -C POSTROUTING -s $dst_ip -j SNAT --to-source $dst_ip || \
iptables -t nat -A POSTROUTING -s $dst_ip -j SNAT --to-source $dst_ip

iptables-save > /etc/iptables/rules.v4
EOF
            ;;
        
        "v6-v6")
            cat <<EOF >$script_path
#!/bin/bash
modprobe nf_nat_ipv6

ip6tables -t nat -C PREROUTING -p udp --dst $src_ip -j DNAT --to-destination $dst_ip || \
ip6tables -t nat -A PREROUTING -p udp --dst $src_ip -j DNAT --to-destination $dst_ip

ip6tables -t nat -C POSTROUTING -s $dst_ip -j SNAT --to-source $src_ip || \
ip6tables -t nat -A POSTROUTING -s $dst_ip -j SNAT --to-source $src_ip

ip6tables-save > /etc/iptables/rules.v6
EOF
            ;;
            
        "v6-v4")
            cat <<EOF >$script_path
#!/bin/bash
modprobe nf_nat_ipv6

ip6tables -t nat -C PREROUTING -p udp --dst $src_ip -j DNAT --to-destination $dst_ip || \
ip6tables -t nat -A PREROUTING -p udp --dst $src_ip -j DNAT --to-destination $dst_ip

iptables -t nat -C POSTROUTING -s $dst_ip -j MASQUERADE || \
iptables -t nat -A POSTROUTING -s $dst_ip -j MASQUERADE

ip6tables-save > /etc/iptables/rules.v6
iptables-save > /etc/iptables/rules.v4
EOF
            ;;
            
        "v4-v6")
            cat <<EOF >$script_path
#!/bin/bash
modprobe nf_nat_ipv6

iptables -t nat -C PREROUTING -p udp --dst $src_ip -j DNAT --to-destination $dst_ip || \
iptables -t nat -A PREROUTING -p udp --dst $src_ip -j DNAT --to-destination $dst_ip

ip6tables -t nat -C POSTROUTING -s $dst_ip -j MASQUERADE || \
ip6tables -t nat -A POSTROUTING -s $dst_ip -j MASQUERADE

iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6
EOF
            ;;
    esac
    
    chmod +x $script_path
}

# 创建systemd服务
create_systemd_service() {
    local type=$1
    
    cat <<EOF >/etc/systemd/system/UDP-rules-${type}.service
[Unit]
Description=UDP NAT Rules for ${type}
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/UDP-rules-${type}.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "/etc/systemd/system/UDP-rules-${type}.service"
    systemctl daemon-reload
    systemctl enable "UDP-rules-${type}.service"
    systemctl start "UDP-rules-${type}.service"
}

# 启用IP转发
enable_ip_forwarding() {
    echo 1 > /proc/sys/net/ipv4/ip_forward
    echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
    
    # 持久化配置
    cat <<EOF >/etc/sysctl.d/60-ip-forwarding.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
    sysctl -p /etc/sysctl.d/60-ip-forwarding.conf
}

# 主程序
clear
echo -e "${GREEN}Debian IP转发配置脚本${NC}"
echo -e "${GREEN}====================${NC}"

# 检查环境
check_root
check_debian
install_packages
enable_ip_forwarding

# 获取用户输入
read -p "请输入源IP: " src_ip
read -p "请输入目标IP: " dst_ip

# 检测IP版本
src_version=$(detect_ip_version "$src_ip")
dst_version=$(detect_ip_version "$dst_ip")

# 验证IP地址格式
if [[ $src_version == "invalid" || $dst_version == "invalid" ]]; then
    echo -e "${RED}错误：无效的IP地址格式！${NC}"
    exit 1
fi

# 根据IP版本自动配置转发
if [[ $src_version == "ipv4" && $dst_version == "ipv4" ]]; then
    configure_ipv4_to_ipv4 "$src_ip" "$dst_ip"
    create_systemd_service "v4-v4"
elif [[ $src_version == "ipv6" && $dst_version == "ipv4" ]]; then
    configure_ipv6_to_ipv4 "$src_ip" "$dst_ip"
    create_systemd_service "v6-v4"
elif [[ $src_version == "ipv4" && $dst_version == "ipv6" ]]; then
    configure_ipv4_to_ipv6 "$src_ip" "$dst_ip"
    create_systemd_service "v4-v6"
elif [[ $src_version == "ipv6" && $dst_version == "ipv6" ]]; then
    configure_ipv6_to_ipv6 "$src_ip" "$dst_ip"
    create_systemd_service "v6-v6"
else
    echo -e "${RED}错误：不支持的IP版本组合！${NC}"
    exit 1
fi

echo -e "${GREEN}配置完成！${NC}"
echo -e "${YELLOW}转发类型：${src_version} -> ${dst_version}${NC}"
echo -e "${YELLOW}源IP：${src_ip}${NC}"
echo -e "${YELLOW}目标IP：${dst_ip}${NC}"
echo -e "${YELLOW}系统将在重启后自动应用规则。${NC}"
echo -e "${YELLOW}您可以使用以下命令查看服务状态：${NC}"
echo "systemctl status UDP-rules-*.service"