#!/bin/bash
# By one

# 颜色输出函数
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}

# 检查相应组件是否安装
check_system(){
    if [ ! -f "/usr/bin/sudo" ]; then
        apt install -y sudo
    fi
    if [ ! -f "/usr/bin/wget" ]; then
        apt install -y wget
    fi
    if ! command -v curl &> /dev/null; then
        apt install -y curl
    fi
    green "相应组件已安装。"
}

# 系统参数优化
sysctl_check(){
    if [ -f /etc/debian_version ]; then
        echo "检测到Debian系统。"
    else
        echo "非Debian系统，终止操作！"
        exit 1
    fi
    VERSION_CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d'=' -f2)
    if [ -z "$VERSION_CODENAME" ]; then
        DEBIAN_VERSION=$(cat /etc/debian_version)
        case "$DEBIAN_VERSION" in
            13*) VERSION_CODENAME="trixie";;
            12*) VERSION_CODENAME="bookworm";;
            11*) VERSION_CODENAME="bullseye";;
            10*) VERSION_CODENAME="buster";;
            *) echo "未知Debian系统"; exit 1 ;;
        esac
    fi
    echo "检测到 Debian 版本代号：$VERSION_CODENAME"
    # 备份现有的sources.list文件
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
    echo "已完成备份sources.list文件"
    # 更新sources.list
    cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian $VERSION_CODENAME main contrib non-free
deb-src http://deb.debian.org/debian $VERSION_CODENAME main contrib non-free
deb http://deb.debian.org/debian-security $VERSION_CODENAME-security main contrib non-free
deb-src http://deb.debian.org/debian-security $VERSION_CODENAME-security main contrib non-free
deb http://deb.debian.org/debian $VERSION_CODENAME-updates main contrib non-free
deb-src http://deb.debian.org/debian $VERSION_CODENAME-updates main contrib non-free
EOF

    echo "已经更新 $VERSION_CODENAME 版本的源"
    apt update -y 
}

# 优化参数
sysctl_Optimization(){
    if [ ! -f "/root/sysctl_optimization.sh" ]; then
        yellow "未找到参数优化文件，正在开始下载参数优化脚本。"
        wget -O "/root/sysctl_optimization.sh" "https://raw.githubusercontent.com/pulicajexa/myshell/refs/heads/main/Auxiliary/sysctl_optimization.sh"
        chmod +x "/root/sysctl_optimization.sh"
        green "参数优化文件下载完成，开始执行系统优化......"
    fi
    bash "/root/sysctl_optimization.sh"
}

# 增加虚拟内存
swap_add(){
    if [ ! -f "/root/swap.sh" ]; then
        yellow "未发现脚本，执行下载脚本...."
        wget -O "/root/swap.sh" "https://raw.githubusercontent.com/pulicajexa/myshell/refs/heads/main/Auxiliary/swap.sh"
        chmod +x "/root/swap.sh"
        green "下载完成，开始执行增加虚拟内存"
    fi
    bash "/root/swap.sh"
}

# 开启root
root_add(){
    if [ ! -f "/root/ssh_root" ]; then
        yellow "未发现脚本，执行下载脚本...."
        wget -O "/root/ssh_root" "https://raw.githubusercontent.com/pulicajexa/test/refs/heads/main/main/ssh_root.sh"
        chmod +x "/root/ssh_root"
        green "下载完成，开启root...."
    fi
    bash "/root/ssh_root"
}

#添加ip转发脚本
udp_ip(){
    if [ ! -f "/root/udp.sh" ]; then
        yello "未发现配置脚本，正在下载脚本....."
        wget -O "/root/udp.sh" "https://raw.githubusercontent.com/2024mingliuwang/myshell/refs/heads/main/Auxiliary/udp.sh"
        chmod +x /root/udp.sh
        green "执行脚本....."
    fi
    bash /root/udp.sh
}

# 添加warp脚本
install_warp() {
    green "开始安装warp"
    if [ ! -f "/root/menu.sh" ]; then
        green "检查到root文件夹下没有menu.sh文件，开始下载"
        wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh -O /root/menu.sh && bash /root/menu.sh
    else
        bash /root/menu.sh
    fi
}

# 主菜单
main_menu() {
    green "====================================="
    green " 欢迎使用one的一键脚本"
    green " 介绍：一键优化系统脚本"
    green " 系统：Debian"
    green " 作者：one"
    green "====================================="
    green " 1.设置root密码"
    green " 2.增加虚拟内存"
    green " 3.添加warp"
    green " 4.ip转发"
    green " 0.退出脚本"
    read -r -p "请输入数字:" num
    case "$num" in
        1)
            root_add
            ;;
        2)
            swap_add
            ;;
        3)  
            install_warp
            ;;
        4)
            udp.sh
            ;;

        0)
            exit 1
            ;;
        *)
            clear
            red "请输入正确数字"
            sleep 1s
            main_menu
            ;;
    esac
}

# 脚本开始
sysctl_check
check_system
sysctl_Optimization
main_menu
