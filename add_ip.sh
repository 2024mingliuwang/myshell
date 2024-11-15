#!/bin/bash

# 颜色输出函数
red() {
    echo -e "\033[31m\033[01m$1\033[0m"
}
green() {
    echo -e "\033[32m\033[01m$1\033[0m"
}
yellow() {
    echo -e "\033[33m\033[01m$1\033[0m"
}

# 检查是否为root用户
check_root() {
    if [ "$(id -u)" != "0" ]; then
        red "错误：此脚本需要root权限运行！"
        exit 1
    fi
}

# 检查netplan配置文件是否存在
check_netplan() {
    if [ ! -f "/etc/netplan/50-cloud-init.yaml" ]; then
        red "错误：未找到netplan配置文件！"
        exit 1
    fi
}

# 备份原配置文件
backup_config() {
    cp /etc/netplan/50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml.bak
    green "已备份原配置文件到 50-cloud-init.yaml.bak"
}

# 获取原配置信息
get_original_config() {
    # 获取第一个IPv4地址的子网掩码
    local first_ip=$(grep -A1 'addresses:' /etc/netplan/50-cloud-init.yaml | grep -v 'addresses:' | grep -v '2409:' | head -n 1)
    SUBNET_MASK=$(echo "$first_ip" | grep -o '/[0-9]*' | grep -o '[0-9]*')
    
    # 获取MAC地址
    MAC_ADDRESS=$(grep 'macaddress:' /etc/netplan/50-cloud-init.yaml | awk '{print $2}')
    
    # 获取IPv6地址
    IPV6_ADDRESS=$(grep '2409:' /etc/netplan/50-cloud-init.yaml | tr -d ' ' | tr -d '-')
    
    if [ -z "$SUBNET_MASK" ] || [ -z "$MAC_ADDRESS" ] || [ -z "$IPV6_ADDRESS" ]; then
        red "错误：无法从原配置文件获取必要信息！"
        exit 1
    fi
}

# 更新网络配置
update_config() {
    local ip1=$1
    local ip2=$2
    
    # 创建新的配置文件
    cat > /etc/netplan/50-cloud-init.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      addresses:
        - ${ip1}/${SUBNET_MASK}
        - ${ip2}/${SUBNET_MASK}
        - ${IPV6_ADDRESS}
      routes:
        - to: default
          via: 36.151.65.1
        - to: default
          via: 2409:8720:5200:5::1
          on-link: true
      match:
        macaddress: ${MAC_ADDRESS}
      nameservers:
        addresses:
          - 223.5.5.5
          - 223.6.6.6
          - 2400:3200::1
      set-name: eth0
EOF
    
    green "配置文件已更新"
}

# 应用新配置
apply_config() {
    yellow "正在应用新配置..."
    netplan apply
    if [ $? -eq 0 ]; then
        green "网络配置已成功应用"
    else
        red "应用配置时出错"
        yellow "正在还原备份..."
        cp /etc/netplan/50-cloud-init.yaml.bak /etc/netplan/50-cloud-init.yaml
        netplan apply
    fi
}

# 主程序
main() {
    clear
    green "====================================="
    green "      Netplan 配置修改脚本"
    green "====================================="
    
    # 检查权限和文件
    check_root
    check_netplan
    
    # 获取原配置信息
    get_original_config
    
    # 显示当前配置信息
    yellow "当前配置信息："
    yellow "子网掩码: /${SUBNET_MASK}"
    yellow "MAC地址: ${MAC_ADDRESS}"
    
    # 获取用户输入
    read -p "请输入第一个IP地址: " ip1
    read -p "请输入第二个IP地址: " ip2
    
    # 验证IP地址格式
    if [[ ! $ip1 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || \
       [[ ! $ip2 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        red "错误：无效的IP地址格式！"
        exit 1
    fi
    
    # 执行配置更新
    backup_config
    update_config "$ip1" "$ip2"
    
    # 确认是否应用配置
    read -p "是否立即应用新配置？(y/n): " confirm
    if [[ $confirm == [Yy] ]]; then
        apply_config
    else
        yellow "配置文件已更新但未应用，请手动执行 'netplan apply' 使配置生效"
    fi
}

# 执行主程序
main