#!/bin/bash

#系统信息
# 指令集
unset machine
# 系统
unset release
# 系统版本
unset systemVersion
unset apt
unset apt_no_install_recommends
unset dnf
unset dnf_no_install_recommends
# CPU线程数
unset cpu_thread_num
# 系统时区
unset timezone
# ssh service name
unset ssh_service

#安装配置信息
nginx_version="nginx-1.23.3"
openssl_version="openssl-openssl-3.0.8"
nginx_prefix="/usr/local/nginx"
nginx_config="${nginx_prefix}/conf.d/xray.conf"
nginx_service="/etc/systemd/system/nginx.service"
nginx_is_installed=""

php_version="php-8.2.3"
php_prefix="/usr/local/php"
php_service="/etc/systemd/system/php-fpm.service"
unset php_is_installed

cloudreve_version="3.7.1"
cloudreve_prefix="/usr/local/cloudreve"
cloudreve_service="/etc/systemd/system/cloudreve.service"
unset cloudreve_is_installed

nextcloud_url="https://download.nextcloud.com/server/prereleases/nextcloud-26.0.0beta4.tar.bz2"

xray_config="/usr/local/etc/xray/config.json"
unset xray_is_installed

temp_dir="/temp_install_update_xray_tls_web"
unset is_installed

#连接配置信息
# 域名列表 两个列表用来区别 www.主域名
unset domain_list
unset true_domain_list
unset domain_config_list
# 域名伪装列表，对应域名列表
unset pretend_list

# TCP configuration, 0 means disable, 1 means XTLS, 2 means TLS, 3 means XTLS TLS
unset protocol_1
# grpc使用的代理协议，0代表禁用，1代表VLESS，2代表VMess
unset protocol_2
# WebSocket使用的代理协议，0代表禁用，1代表VLESS，2代表VMess
unset protocol_3
# grpc的serviceName
unset serviceName
# ws的path
unset path
# TCP协议的vless uuid
unset xid_1
# grpc协议的vless/vmess uuid
unset xid_2
# ws协议的vless/vmess uuid
unset xid_3

# 现在有没有通过脚本启动swap
using_swap_now=0
# 在更新
unset update
# 在 install_update_xray_tls_web 函数中
in_install_update_xray_tls_web=0

#功能性函数：
#定义几个颜色
purple()                           #基佬紫
{
    echo -e "\\033[35;1m${*}\\033[0m"
}
tyblue()                           #天依蓝
{
    echo -e "\\033[36;1m${*}\\033[0m"
}
green()                            #原谅绿
{
    echo -e "\\033[32;1m${*}\\033[0m"
}
yellow()                           #鸭屎黄
{
    echo -e "\\033[33;1m${*}\\033[0m"
}
red()                              #姨妈红
{
    echo -e "\\033[31;1m${*}\\033[0m"
}
blue()                             #蓝色
{
    echo -e "\\033[34;1m${*}\\033[0m"
}
#检查基本命令
check_base_command()
{
    hash -r
    local i
    local temp_command_list=('bash' 'sh' 'command' 'type' 'hash' 'install' 'true' 'false' 'exit' 'echo' 'test' 'sort' 'sed' 'awk' 'grep' 'cut' 'cd' 'rm' 'cp' 'mv' 'head' 'tail' 'uname' 'tr' 'md5sum' 'cat' 'find' 'wc' 'ls' 'mktemp' 'swapon' 'swapoff' 'mkswap' 'chmod' 'chown' 'chgrp' 'export' 'tar' 'gzip' 'mkdir' 'arch' 'uniq' 'dd' 'env')
    for i in "${temp_command_list[@]}"
    do
        if ! command -V "${i}" > /dev/null; then
            red "命令\"${i}\"未找到"
            red "不是标准的Linux系统"
            exit 1
        fi
    done
}
check_sudo()
{
    if [ "$SUDO_GID" ] && [ "$SUDO_COMMAND" ] && [ "$SUDO_USER" ] && [ "$SUDO_UID" ]; then
        if [ "$SUDO_USER" = "root" ] && [ "$SUDO_UID" = "0" ]; then
            #it's root using sudo, no matter it's using sudo or not, just fine
            return 0
        fi
        if [ -n "$SUDO_COMMAND" ]; then
            #it's a normal user doing "sudo su", or `sudo -i` or `sudo -s`, or `sudo su acmeuser1`
            echo "$SUDO_COMMAND" | grep -- "/bin/su\$" >/dev/null 2>&1 || echo "$SUDO_COMMAND" | grep -- "/bin/su " >/dev/null 2>&1 || grep "^$SUDO_COMMAND\$" /etc/shells >/dev/null 2>&1
            return $?
        fi
        #otherwise
        return 1
    fi
    return 0
}
#版本比较函数
version_ge()
{
    test "$(echo -e "$1\\n$2" | sort -rV | head -n 1)" == "$1"
}
#检查脚本更新
check_script_update()
{
    [ "$(md5sum "${BASH_SOURCE[0]}" | awk '{print $1}')" == "$(md5sum <(wget -O - "https://github.com/kirin10000/Xray-script/raw/main/Xray-TLS+Web-setup.sh") | awk '{print $1}')" ] && return 1 || return 0
}
#更新脚本
update_script()
{
    if wget -O "${BASH_SOURCE[0]}" "https://github.com/kirin10000/Xray-script/raw/main/Xray-TLS+Web-setup.sh" || wget -O "${BASH_SOURCE[0]}" "https://github.com/mrbtmn/Xray-script/raw/main/Xray-TLS+Web-setup.sh"; then
        green "The script update is complete, please run the script again！"
        exit 0
    else
        red "update script failed！"
        exit 1
    fi
}
ask_update_script()
{
    if check_script_update; then
        green "Script can be upgraded"
        ask_if "Whether to upgrade the script？(y/n)" && update_script
    else
        green "The script is already the latest version"
    fi
}
ask_update_script_force()
{
    if check_script_update; then
        green "Script can be upgraded"
        if ask_if "Whether to upgrade the script？(y/n)"; then
            update_script
        else
            red "Please update the script first"
            exit 0
        fi
    else
        green "The script is already the latest version"
    fi
}
redhat_install()
{
    if $dnf_no_install_recommends -y install "$@"; then
        return 0
    fi


    if $dnf --help | grep -q "\\-\\-enablerepo="; then
        local enable_repo="--enablerepo="
    else
        local enable_repo="--enablerepo "
    fi
    if $dnf --help | grep -q "\\-\\-disablerepo="; then
        local disable_repo="--disablerepo="
    else
        local disable_repo="--disablerepo "
    fi
    if [ $release == centos-stream ]; then
        local epel_repo="epel,epel-next"
    elif [ $release == oracle ]; then
        if version_ge "$systemVersion" 9; then
            local epel_repo="ol9_developer_EPEL"
        elif version_ge "$systemVersion" 8; then
            local epel_repo="ol8_developer_EPEL"
        elif version_ge "$systemVersion" 7; then
            local epel_repo="ol7_developer_EPEL"
        else
            local epel_repo="epel"
        fi
    else
        local epel_repo="epel"
    fi


    if [ $release == fedora ]; then
        if $dnf_no_install_recommends -y ${enable_repo}"remi" install "$@"; then
            return 0
        fi
    else
        if $dnf_no_install_recommends -y ${enable_repo}"${epel_repo}" install "$@"; then
            return 0
        fi
        if $dnf_no_install_recommends -y ${enable_repo}"${epel_repo},powertools" install "$@" || $dnf_no_install_recommends -y ${enable_repo}"${epel_repo},PowerTools" install "$@"; then
            return 0
        fi
    fi
    if $dnf_no_install_recommends -y ${enable_repo}"*" ${disable_repo}"*-debug,*-debuginfo,*-source" install "$@"; then
        return 0
    fi
    if $dnf_no_install_recommends -y ${enable_repo}"*" install "$@"; then
        return 0
    fi
    return 1
}
#安装单个重要依赖
test_important_dependence_installed()
{
    local temp_exit_code=1
    if [ $release == "ubuntu" ] || [ $release == "debian" ] || [ $release == "deepin" ] || [ $release == "other-debian" ]; then
        if LANG="en_US.UTF-8" LANGUAGE="en_US:en" dpkg -s "$1" 2>/dev/null | grep -qi 'status[ '$'\t]*:[ '$'\t]*install[ '$'\t]*ok[ '$'\t]*installed[ '$'\t]*$'; then
            if LANG="en_US.UTF-8" LANGUAGE="en_US:en" apt-mark manual "$1" | grep -qi 'set[ '$'\t]*to[ '$'\t]*manually[ '$'\t]*installed'; then
                temp_exit_code=0
            else
                red "安装依赖 \"$1\" 出错！"
                green  "欢迎进行Bug report(https://github.com/kirin10000/Xray-script/issues)，感谢您的支持"
                yellow "按回车键继续或者Ctrl+c退出"
                read -s
            fi
        elif $apt_no_install_recommends -y install "$1"; then
            temp_exit_code=0
        else
            $apt update
            $apt_no_install_recommends -y -f install
            $apt_no_install_recommends -y install "$1" && temp_exit_code=0
        fi
    else
        if rpm -q "$2" > /dev/null 2>&1; then
            if [ "$dnf" == "microdnf" ]; then
                redhat_install dnf
                dnf="dnf"
                dnf_no_install_recommends="dnf --setopt install_weak_deps=0"
            fi
            if [ "$dnf" == "dnf" ]; then
                dnf mark install "$2" && temp_exit_code=0
            else
                yumdb set reason user "$2" && temp_exit_code=0
            fi
        elif redhat_install "$2"; then
            temp_exit_code=0
        fi
    fi
    return $temp_exit_code
}
check_important_dependence_installed()
{
    if ! test_important_dependence_installed "$@"; then
        if [ $release == "ubuntu" ] || [ $release == "debian" ] || [ $release == "deepin" ] || [ $release == "other-debian" ]; then
            red "重要组件\"$1\"安装失败！！"
        else
            red "重要组件\"$2\"安装失败！！"
        fi
        yellow "按回车键继续或者Ctrl+c退出"
        read -s
    fi
}
#安装依赖
install_dependence()
{
    if [ $release == "ubuntu" ] || [ $release == "debian" ] || [ $release == "deepin" ] || [ $release == "other-debian" ]; then
        if ! $apt_no_install_recommends -y install "$@"; then
            $apt update
            $apt_no_install_recommends -y -f install
            if ! $apt_no_install_recommends -y install "$@"; then
                yellow "Dependency installation failed！！"
                green  "Welcome to Bug report (https://github.com/kirin10000/Xray-script/issues), thank you for your support"
                yellow "Press Enter to continue or Ctrl+c to exit"
                read -s
            fi
        fi
    else
        if ! redhat_install "$@"; then
            yellow "依赖安装失败！！"
            green  "欢迎进行Bug report(https://github.com/kirin10000/Xray-script/issues)，感谢您的支持"
            yellow "按回车键继续或者Ctrl+c退出"
            read -s
        fi
    fi
}
# 防止apt卸载时自动安装替代软件
apt_purge()
{
    local ret_code=0
    mv /etc/apt/sources.list /etc/apt/sources.list.bak
    mv /etc/apt/sources.list.d /etc/apt/sources.list.d.bak
    $apt -y --allow-change-held-packages purge "$@" || ret_code=1
    mv /etc/apt/sources.list.bak /etc/apt/sources.list
    mv /etc/apt/sources.list.d.bak /etc/apt/sources.list.d
    return $ret_code
}
apt_auto_remove_purge()
{
    local ret_code=0
    mv /etc/apt/sources.list /etc/apt/sources.list.bak
    mv /etc/apt/sources.list.d /etc/apt/sources.list.d.bak
    $apt -y --auto-remove --allow-change-held-packages purge "$@" || ret_code=1
    mv /etc/apt/sources.list.bak /etc/apt/sources.list
    mv /etc/apt/sources.list.d.bak /etc/apt/sources.list.d
    return $ret_code
}
#安装epel源
install_epel()
{
    if [ $release == "ubuntu" ] || [ $release == "debian" ] || [ $release == "deepin" ] || [ $release == "other-debian" ]; then
        return
    fi

    local ret=0
    if [ $release == fedora ]; then
        return
    elif [ $release == centos-stream ]; then
        if version_ge "$systemVersion" 10; then
            ret=-1
        elif version_ge "$systemVersion" 9; then
            check_important_dependence_installed "" dnf-plugins-core
            dnf config-manager --set-enabled crb || ret=-1
            redhat_install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm" "https://dl.fedoraproject.org/pub/epel/epel-next-release-latest-9.noarch.rpm" || ret=-1
        elif version_ge "$systemVersion" 8; then
            check_important_dependence_installed "" dnf-plugins-core
            dnf config-manager --set-enabled powertools || dnf config-manager --set-enabled PowerTools || ret=-1
            redhat_install epel-release epel-next-release || ret=-1
        else
            ret=-1
        fi
    elif [ $release == centos ]; then
        if version_ge "$systemVersion" 9; then
            ret=-1
        elif version_ge "$systemVersion" 8; then
            check_important_dependence_installed "" dnf-plugins-core
            dnf config-manager --set-enabled powertools || dnf config-manager --set-enabled PowerTools || ret=-1
            redhat_install epel-release || ret=-1
        elif version_ge "$systemVersion" 7; then
            redhat_install epel-release || ret=-1
        elif version_ge "$systemVersion" 6; then
            redhat_install epel-release || ret=-1
        else
            ret=-1
        fi
    elif [ $release == oracle ]; then
        if version_ge "$systemVersion" 9; then
            ret=-1
        elif version_ge "$systemVersion" 8; then
            redhat_install oracle-epel-release-el8 || ret=-1
        elif version_ge "$systemVersion" 7; then
            redhat_install oracle-epel-release-el7 || ret=-1
        else
            ret=-1
        fi
    elif [ $release == rhel ]; then
        if version_ge "$systemVersion" 9; then
            ret=-1
        elif version_ge "$systemVersion" 8; then
            subscription-manager repos --enable "codeready-builder-for-rhel-8-$(arch)-rpms" || ret=-1
            redhat_install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm" || ret=-1
        elif version_ge "$systemVersion" 7; then
            subscription-manager repos --enable "rhel-*-optional-rpms" --enable "rhel-*-extras-rpms" --enable "rhel-ha-for-rhel-*-server-rpms" || ret=-1
            redhat_install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm" || ret=-1
        else
            ret=-1
        fi
    else
        ############
        if [ $dnf == microdnf ]; then
            check_important_dependence_installed "" dnf
            dnf="dnf"
            dnf_no_install_recommends="dnf --setopt install_weak_deps=0"
        fi
        if [ $dnf == dnf ]; then
            check_important_dependence_installed "" dnf-plugins-core
            dnf config-manager --set-enabled powertools || dnf config-manager --set-enabled PowerTools
        fi
        redhat_install epel-release || ret=-1
    fi

    if [ $ret -ne 0 ]; then
        if [ $release == other-redhat ]; then
            if $dnf repolist epel | grep -q epel; then
                return
            fi
            yellow "epel源安装失败，这可能导致之后的安装失败，也可能没有影响(取决于你的系统的repo包含软件是否丰富)"
            echo
            tyblue "除了安装epel源过程出错，也有可能是因为你使用的系统比较冷门导致安装失败"
            tyblue "这种情况下可以手动安装epel源，之后重新运行脚本"
        else
            yellow "epel源安装失败！！"
        fi
        echo
        green  "欢迎进行Bug report(https://github.com/kirin10000/Xray-script/issues)，感谢您的支持"
        yellow "按回车键继续或者Ctrl+c退出"
        read -s
    fi
}
fedora_install_remi()
{
    if [ $release != fedora ]; then
        return
    fi
    if ! redhat_install "https://rpms.remirepo.net/fedora/remi-release-$systemVersion.rpm"; then
        yellow "remi源安装失败！！"
        green  "欢迎进行Bug report(https://github.com/kirin10000/Xray-script/issues)，感谢您的支持"
        yellow "按回车键继续或者Ctrl+c退出"
        read -s
    fi
}
#进入工作目录
enter_temp_dir()
{
    local temp_exit_code=0
    cd / || temp_exit_code=1
    rm -rf "$temp_dir" || temp_exit_code=1
    mkdir "$temp_dir" || temp_exit_code=1
    cd "$temp_dir" || temp_exit_code=1
    if [ $temp_exit_code -eq 1 ]; then
        yellow "Failed to enter temp directory"
        tyblue "It may be caused by the interruption of the previous running script. It is recommended to restart the system before running the script"
        exit 1
    fi
}
#检查是否需要php
check_need_php()
{
    [ $is_installed -eq 0 ] && return 1
    local i
    for i in "${pretend_list[@]}"
    do
        [ "$i" == "2" ] && return 0
    done
    return 1
}
#检查是否需要cloudreve
check_need_cloudreve()
{
    [ $is_installed -eq 0 ] && return 1
    local i
    for i in "${pretend_list[@]}"
    do
        [ "$i" == "1" ] && return 0
    done
    return 1
}
#检查Nginx更新
check_nginx_update()
{
    local nginx_version_now
    local openssl_version_now
    nginx_version_now="nginx-$(${nginx_prefix}/sbin/nginx -V 2>&1 | grep "^nginx version:" | cut -d / -f 2)"
    openssl_version_now="openssl-openssl-$(${nginx_prefix}/sbin/nginx -V 2>&1 | grep "^built with OpenSSL" | awk '{print $4}')"
    if [ "$nginx_version_now" == "$nginx_version" ] && [ "$openssl_version_now" == "$openssl_version" ]; then
        return 1
    else
        return 0
    fi
}
#检查php更新
check_php_update()
{
    local php_version_now
    php_version_now="php-$(${php_prefix}/bin/php -v | head -n 1 | awk '{print $2}')"
    [ "$php_version_now" == "$php_version" ] && return 1
    return 0
}
swap_on()
{
    if [ $using_swap_now -ne 0 ]; then
        red    "Open swap error occurs"
        green  "欢迎进行Bug report(https://github.com/kirin10000/Xray-script/issues)，感谢您的支持"
        yellow "Press Enter to continue or Ctrl+c to exit"
        read -s
    fi
    local need_swap_size=$(( $1+$(free -m | sed -n 2p | awk '{print $3}')+$(free -m | sed -n 3p | awk '{print $3}')-$(free -m | sed -n 2p | awk '{print $2}')-$(free -m | sed -n 3p | awk '{print $2}') ))
    if [ $need_swap_size -gt 0 ]; then
        tyblue "If the available memory is less than $1M, automatically apply for swap。。"
        if dd if=/dev/zero of=${temp_dir}/swap bs=1M count=$need_swap_size && chmod 0600 ${temp_dir}/swap && mkswap ${temp_dir}/swap && swapon ${temp_dir}/swap; then
            using_swap_now=1
        else
            rm -rf ${temp_dir}/swap
            red    "Failed to open swap！"
            yellow "It may be that the machine memory and hard disk space are insufficient"
            green  "欢迎进行Bug report(https://github.com/kirin10000/Xray-script/issues)，感谢您的支持"
            yellow "Press Enter to continue or Ctrl+c to exit"
            read -s
        fi
    fi
}
swap_off()
{
    if [ $using_swap_now -eq 1 ]; then
        tyblue "Restoring swap。。。"
        if swapoff ${temp_dir}/swap && rm -rf ${temp_dir}/swap; then
            using_swap_now=0
        else
            red    "Failed to close swap！"
            green  "欢迎进行Bug report(https://github.com/kirin10000/Xray-script/issues)，感谢您的
支持"
            yellow "Press Enter to continue or Ctrl+c to exit"
            read -s
        fi
    fi
}
#启用/禁用php cloudreve
turn_on_off_php()
{
    if check_need_php; then
        systemctl start php-fpm
        systemctl enable php-fpm
    else
        systemctl stop php-fpm
        systemctl disable php-fpm
    fi
}
turn_on_off_cloudreve()
{
    if check_need_cloudreve; then
        systemctl start cloudreve
        systemctl enable cloudreve
    else
        systemctl stop cloudreve
        systemctl disable cloudreve
    fi
}
let_change_cloudreve_domain()
{
    tyblue "----------- please open\"https://${domain_list[$1]}\"Modify Cloudreve site information ---------"
    tyblue "  1. login account"
    tyblue "  2. Avatar in the upper right corner -> Admin Panel"
    tyblue "  3. Parameter settings on the left -> Site information"
    tyblue "  4. Site URL changed to\"https://${domain_list[$1]}\" -> Scroll down and click save"
    sleep 15s
    echo -e "\\n\\n"
    tyblue "Press enter twice to continue。。。"
    read -s
    read -s
}
ask_if()
{
    local choice=""
    while [ "$choice" != "y" ] && [ "$choice" != "n" ]
    do
        tyblue "$1"
        read choice
    done
    [ $choice == y ] && return 0
    return 1
}
#卸载函数
remove_xray()
{
    if ! bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge; then
        systemctl stop xray
        systemctl disable xray
        rm -rf /usr/local/bin/xray
        rm -rf /usr/local/etc/xray
        rm -rf /etc/systemd/system/xray.service
        rm -rf /etc/systemd/system/xray@.service
        rm -rf /var/log/xray
        systemctl daemon-reload
    fi
    xray_is_installed=0
    is_installed=0
}
remove_nginx()
{
    systemctl stop nginx
    systemctl disable nginx
    rm -rf $nginx_service
    systemctl daemon-reload
    rm -rf ${nginx_prefix}
    nginx_is_installed=0
    is_installed=0
}
remove_php()
{
    systemctl stop php-fpm
    systemctl disable php-fpm
    rm -rf $php_service
    systemctl daemon-reload
    rm -rf ${php_prefix}
    php_is_installed=0
}
remove_cloudreve()
{
    systemctl stop cloudreve
    systemctl disable cloudreve
    rm -rf $cloudreve_service
    systemctl daemon-reload
    rm -rf ${cloudreve_prefix}
    cloudreve_is_installed=0
}
#备份域名伪装网站
backup_domains_web()
{
    local i
    mkdir "${temp_dir}/domain_backup"
    for i in "${true_domain_list[@]}"
    do
        if [ "$1" == "cp" ]; then
            cp -rf "${nginx_prefix}/html/${i}" "${temp_dir}/domain_backup" 2>/dev/null
        else
            mv "${nginx_prefix}/html/${i}" "${temp_dir}/domain_backup" 2>/dev/null
        fi
    done
}
#获取配置信息
get_config_info()
{
    [ $is_installed -eq 0 ] && return
    local temp
    if grep -q '"network"[ '$'\t]*:[ '$'\t]*"ws"' $xray_config; then
        if [[ "$(grep -E '"protocol"[ '$'\t]*:[ '$'\t]*"(vmess|vless)"' $xray_config | tail -n 1)" =~ \"vmess\" ]]; then
            protocol_3=2
        else
            protocol_3=1
        fi
        path="$(grep '"path"' $xray_config | tail -n 1 | cut -d : -f 2 | cut -d \" -f 2)"
        xid_3="$(grep '"id"' $xray_config | tail -n 1 | cut -d : -f 2 | cut -d \" -f 2)"
    else
        protocol_3=0
    fi
    if grep -q '"network"[ '$'\t]*:[ '$'\t]*"grpc"' $xray_config; then
        if [ $protocol_3 -ne 0 ]; then
            temp=2
        else
            temp=1
        fi
        if [[ "$(grep -E '"protocol"[ '$'\t]*:[ '$'\t]*"(vmess|vless)"' $xray_config | tail -n $temp | head -n 1)" =~ \"vmess\" ]]; then
            protocol_2=2
        else
            protocol_2=1
        fi
        serviceName="$(grep '"serviceName"' $xray_config | cut -d : -f 2 | cut -d \" -f 2)"
        xid_2="$(grep '"id"' $xray_config | tail -n $temp | head -n 1 | cut -d : -f 2 | cut -d \" -f 2)"
    else
        protocol_2=0
    fi
    temp=1
    [ $protocol_2 -ne 0 ] && ((temp++))
    [ $protocol_3 -ne 0 ] && ((temp++))
    if [ $(grep -c '"clients"' $xray_config) -eq $temp ]; then
        if grep -q '"flow"[ '$'\t]*:[ '$'\t]*"xtls-rprx-vision"' $xray_config; then
            protocol_1=1
        elif ! grep -q '"flow"' $xray_config; then
            protocol_1=2
        else
            protocol_1=3
        fi
        xid_1="$(grep '"id"' $xray_config | head -n 1 | cut -d : -f 2 | cut -d \" -f 2)"
    else
        protocol_1=0
    fi
    unset domain_list
    unset true_domain_list
    unset domain_config_list
    unset pretend_list
    domain_list=($(grep "^#domain_list=" $nginx_config | cut -d = -f 2))
    true_domain_list=($(grep "^#true_domain_list=" $nginx_config | cut -d = -f 2))
    domain_config_list=($(grep "^#domain_config_list=" $nginx_config | cut -d = -f 2))
    pretend_list=($(grep "^#pretend_list=" $nginx_config | cut -d = -f 2))
}
gen_cflags()
{
    cflags=('-g0' '-O3')
    if gcc -v --help 2>&1 | grep -qw "\\-fstack\\-reuse"; then
        cflags+=('-fstack-reuse=all')
    fi
    if gcc -v --help 2>&1 | grep -qw "\\-fdwarf2\\-cfi\\-asm"; then
        cflags+=('-fdwarf2-cfi-asm')
    fi
    if gcc -v --help 2>&1 | grep -qw "\\-fplt"; then
        cflags+=('-fplt')
    fi
    if gcc -v --help 2>&1 | grep -qw "\\-ftrapv"; then
        cflags+=('-fno-trapv')
    fi
    if gcc -v --help 2>&1 | grep -qw "\\-fexceptions"; then
        cflags+=('-fno-exceptions')
    elif gcc -v --help 2>&1 | grep -qw "\\-fhandle\\-exceptions"; then
        cflags+=('-fno-handle-exceptions')
    fi
    if gcc -v --help 2>&1 | grep -qw "\\-funwind\\-tables"; then
        cflags+=('-fno-unwind-tables')
    fi
    if gcc -v --help 2>&1 | grep -qw "\\-fasynchronous\\-unwind\\-tables"; then
        cflags+=('-fno-asynchronous-unwind-tables')
    fi
    if gcc -v --help 2>&1 | grep -qw "\\-fstack\\-check"; then
        cflags+=('-fno-stack-check')
    fi
    if gcc -v --help 2>&1 | grep -qw "\\-fstack\\-clash\\-protection"; then
        cflags+=('-fno-stack-clash-protection')
    fi
    if gcc -v --help 2>&1 | grep -qw "\\-fstack\\-protector"; then
        cflags+=('-fno-stack-protector')
    fi
    if gcc -v --help 2>&1 | grep -qw "\\-fcf\\-protection="; then
        cflags+=('-fcf-protection=none')
    fi
    if gcc -v --help 2>&1 | grep -qw "\\-fsplit\\-stack"; then
        cflags+=('-fno-split-stack')
    fi
    if gcc -v --help 2>&1 | grep -qw "\\-fsanitize"; then
        > temp.c
        if gcc -E -fno-sanitize=all temp.c >/dev/null 2>&1; then
            cflags+=('-fno-sanitize=all')
        fi
        rm temp.c
    fi
    if gcc -v --help 2>&1 | grep -qw "\\-finstrument\\-functions"; then
        cflags+=('-fno-instrument-functions')
    fi
}
gen_cxxflags()
{
    cxxflags=('-g0' '-O3')
    if g++ -v --help 2>&1 | grep -qw "\\-fstack\\-reuse"; then
        cxxflags+=('-fstack-reuse=all')
    fi
    if g++ -v --help 2>&1 | grep -qw "\\-fdwarf2\\-cfi\\-asm"; then
        cxxflags+=('-fdwarf2-cfi-asm')
    fi
    if g++ -v --help 2>&1 | grep -qw "\\-fplt"; then
        cxxflags+=('-fplt')
    fi
    if g++ -v --help 2>&1 | grep -qw "\\-ftrapv"; then
        cxxflags+=('-fno-trapv')
    fi
    if g++ -v --help 2>&1 | grep -qw "\\-fstack\\-check"; then
        cxxflags+=('-fno-stack-check')
    fi
    if g++ -v --help 2>&1 | grep -qw "\\-fstack\\-clash\\-protection"; then
        cxxflags+=('-fno-stack-clash-protection')
    fi
    if g++ -v --help 2>&1 | grep -qw "\\-fstack\\-protector"; then
        cxxflags+=('-fno-stack-protector')
    fi
    if g++ -v --help 2>&1 | grep -qw "\\-fcf\\-protection="; then
        cxxflags+=('-fcf-protection=none')
    fi
    if g++ -v --help 2>&1 | grep -qw "\\-fsplit\\-stack"; then
        cxxflags+=('-fno-split-stack')
    fi
    if g++ -v --help 2>&1 | grep -qw "\\-fsanitize"; then
        > temp.cpp
        if g++ -E -fno-sanitize=all temp.cpp >/dev/null 2>&1; then
            cxxflags+=('-fno-sanitize=all')
        fi
        rm temp.cpp
    fi
    if g++ -v --help 2>&1 | grep -qw "\\-finstrument\\-functions"; then
        cxxflags+=('-fno-instrument-functions')
    fi
    if g++ -v --help 2>&1 | grep -qw "\\-fvtable\\-verify"; then
        cxxflags+=('-fvtable-verify=none')
    fi
}

check_base_command
if [[ ! -f '/etc/os-release' ]]; then
    red "The system version is too old, Xray official script does not support"
    exit 1
fi
if [[ -f /.dockerenv ]] || grep -q 'docker\|lxc' /proc/1/cgroup && [[ "$(type -P systemctl)" ]]; then
    true
elif [[ -d /run/systemd/system ]] || grep -q systemd <(ls -l /sbin/init); then
    true
else
    red "Only supported on systems using systemd！"
    exit 1
fi
if [[ ! -d /dev/shm ]]; then
    red "/dev/shm不存在，unsupported system"
    exit 1
fi
if [[ "$(type -P apt)" ]] || [ "$(type -P apt-get)" ]; then
    if [[ "$(type -P dnf)" ]] || [[ "$(type -P microdnf)" ]] || [[ "$(type -P yum)" ]]; then
        red "同时存在 apt/apt-get 和 dnf/microdnf/yum"
        red "unsupported system！"
        exit 1
    fi
    release="other-debian"
    dnf="true"
    dnf_no_install_recommends="true"
    if [[ "$(type -P apt)" ]]; then
        apt="apt"
    else
        apt="apt-get"
    fi
    apt_no_install_recommends="$apt --no-install-recommends"
elif [[ "$(type -P dnf)" ]] || [[ "$(type -P microdnf)" ]] || [[ "$(type -P yum)" ]]; then
    release="other-redhat"
    apt="true"
    apt_no_install_recommends="true"
    if [[ "$(type -P dnf)" ]]; then
        dnf="dnf"
    elif [[ "$(type -P microdnf)" ]]; then
        dnf="microdnf"
    else
        dnf="yum"
    fi
    if $dnf --help | grep -q "\\-\\-setopt="; then
        dnf_no_install_recommends="$dnf --setopt=install_weak_deps=0"
    else
        dnf_no_install_recommends="$dnf --setopt install_weak_deps=0"
    fi
else
    red "apt,apt-get,dnf,microdnf,yum命令均不存在"
    red "不支持的系统"
    exit 1
fi
if [[ -z "${BASH_SOURCE[0]}" ]]; then
    red "请以文件的形式运行脚本，或不支持的bash版本"
    exit 1
fi
if [ "$EUID" != "0" ]; then
    red "请用root用户运行此脚本！！"
    exit 1
fi
if ! check_sudo; then
    yellow "检测到正在使用sudo！"
    yellow "acme.sh不支持sudo，请使用root用户运行此脚本"
    tyblue "详情请见：https://github.com/acmesh-official/acme.sh/wiki/sudo"
    exit 1
fi
if systemctl cat ssh > /dev/null; then
    ssh_service="ssh"
else
    ssh_service="sshd"
fi
[ -e $nginx_config ] && nginx_is_installed=1 || nginx_is_installed=0
[ -e ${php_prefix}/php-fpm.service.default ] && php_is_installed=1 || php_is_installed=0
[ -e ${cloudreve_prefix}/cloudreve.db ] && cloudreve_is_installed=1 || cloudreve_is_installed=0
[ -e /usr/local/bin/xray ] && xray_is_installed=1 || xray_is_installed=0
([ $xray_is_installed -eq 1 ] && [ $nginx_is_installed -eq 1 ]) && is_installed=1 || is_installed=0
cpu_thread_num="$(grep '^processor' /proc/cpuinfo | uniq | wc -l)"
if [ -z "$cpu_thread_num" ] || [ $cpu_thread_num -lt 1 ]; then
    red "Failed to get the number of CPU threads！"
    exit 1
fi
case "$(uname -m)" in
    'amd64' | 'x86_64')
        machine='amd64'
        ;;
    'armv5tel')
        machine='armv5'
        ;;
    'armv6l')
        machine='armv6'
        ;;
    'armv7' | 'armv7l')
        machine='armv7'
        ;;
    'armv8' | 'aarch64')
        machine='arm64'
        ;;
    *)
        machine=''
        ;;
esac

#获取系统版本信息
get_system_info()
{
    timezone="$(ls -l /etc/localtime | awk -F zoneinfo/ '{print $NF}')"
    if [[ ! -L /etc/localtime ]] || [ "$timezone" == "" ]; then
        yellow "Failed to get time zone！"
        green  "欢迎进行Bug report(https://github.com/kirin10000/Xray-script/issues)，感谢您的支持"
        yellow "Press Enter to continue or Ctrl+c to exit"
        read -s
    fi
    if bash -c "echo $(grep '^[ '$'\t]*ID[ '$'\t]*=' /etc/os-release | cut -d = -f 2-)" | grep -qiw ubuntu; then
        release="ubuntu"
    elif bash -c "echo $(grep '^[ '$'\t]*ID[ '$'\t]*=' /etc/os-release | cut -d = -f 2-)" | grep -qiw debian; then
        release="debian"
    elif bash -c "echo $(grep '^[ '$'\t]*ID[ '$'\t]*=' /etc/os-release | cut -d = -f 2-)" | grep -qiw deepin; then
        release="deepin"
    elif bash -c "echo $(grep '^[ '$'\t]*ID[ '$'\t]*=' /etc/os-release | cut -d = -f 2-)" | grep -qiw centos; then
        if bash -c "echo $(grep '^[ '$'\t]*NAME[ '$'\t]*=' /etc/os-release | cut -d = -f 2-)" | grep -qiw stream; then
            release="centos-stream"
        else
            release="centos"
        fi
    elif bash -c "echo $(grep '^[ '$'\t]*ID[ '$'\t]*=' /etc/os-release | cut -d = -f 2-)" | grep -qiw fedora; then
        release="fedora"
    elif bash -c "echo $(grep '^[ '$'\t]*NAME[ '$'\t]*=' /etc/os-release | cut -d = -f 2-)" | grep -qiw oracle; then
        release="oracle"
    elif bash -c "echo $(grep '^[ '$'\t]*ID[ '$'\t]*=' /etc/os-release | cut -d = -f 2-)" | grep -qiw rhel; then
        release="rhel"
    elif bash -c "echo $(grep '^[ '$'\t]*ID[ '$'\t]*=' /etc/os-release | cut -d = -f 2-)" | grep -qiw redhatenterprise; then
        release="rhel"
    fi
    systemVersion="$(bash -c "echo $(grep '^[ '$'\t]*VERSION_ID[ '$'\t]*=' /etc/os-release | cut -d = -f 2-)")"
    if [ "$(bash -c "echo $(grep '^[ '$'\t]*ID[ '$'\t]*=' /etc/os-release | cut -d = -f 2-)")" == "" ] || [ "$systemVersion" == "" ]; then
        yellow "Failed to get system information！"
        green  "欢迎进行Bug report(https://github.com/kirin10000/Xray-script/issues)，感谢您的支持"
        yellow "Press Enter to continue or Ctrl+c to exit"
        read -s
    fi
}

#Check whether TCP port 80 and port 443 are occupied
check_port()
{
    green "Checking port usage。。。"
    local xray_status=0
    local nginx_status=0
    systemctl -q is-active xray && xray_status=1 && systemctl stop xray
    systemctl -q is-active nginx && nginx_status=1 && systemctl stop nginx
    ([ $xray_status -eq 1 ] || [ $nginx_status -eq 1 ]) && sleep 2s
    local check_list=('80' '443')
    local i
    for i in "${check_list[@]}"
    do
        if ss -natl | awk '{print $4}'  | awk -F : '{print $NF}' | grep -E "^[0-9]+$" | grep -wq "${i}"; then
            red "TCP:${i}port is occupied！"
            yellow "Please use lsof -i:${i} command check"
            exit 1
        fi
    done
    [ $xray_status -eq 1 ] && systemctl start xray
    [ $nginx_status -eq 1 ] && systemctl start nginx
}

#检查Nginx是否已通过apt/dnf/yum安装
check_nginx_installed_system()
{
    if [[ ! -f /usr/lib/systemd/system/nginx.service ]] && [[ ! -f /lib/systemd/system/nginx.service ]]; then
        return 0
    fi
    red    "------------Nginx is detected to be installed and will conflict with this script------------"
    yellow " If you don't remember installing Nginx before, it may have been installed when using another one-click script"
    yellow " It is recommended to use a clean system to run this script"
    echo
    ! ask_if "Do you try to uninstall？(y/n)" && exit 0
    apt_purge '^nginx' '^libnginx'
    $dnf -y remove 'nginx*'
    if [[ ! -f /usr/lib/systemd/system/nginx.service ]] && [[ ! -f /lib/systemd/system/nginx.service ]]; then
        return 0
    fi
    red "uninstall failed！"
    yellow "Please try to replace the system, it is recommended to use the latest version of Ubuntu system"
    green  "欢迎进行Bug report(https://github.com/kirin10000/Xray-script/issues)，感谢您的支持"
    exit 1
}

#检查SELinux
check_SELinux()
{
    turn_off_selinux()
    {
        if command -V setenforce >/dev/null 2>&1; then
            local selinux_utils_is_installed=1
        else
            local selinux_utils_is_installed=0
            check_important_dependence_installed selinux-utils libselinux-utils
        fi
        setenforce 0
        sed -i 's/^[ \t]*SELINUX[ \t]*=[ \t]*enforcing[ \t]*$/SELINUX=disabled/g' /etc/sysconfig/selinux
        sed -i 's/^[ \t]*SELINUX[ \t]*=[ \t]*enforcing[ \t]*$/SELINUX=disabled/g' /etc/selinux/config
        if [ $selinux_utils_is_installed -eq 0 ]; then
            $dnf -y remove libselinux-utils
            apt_purge selinux-utils
        fi
    }
    if getenforce 2>/dev/null | grep -wqi Enforcing || grep -Eq '^[ '$'\t]*SELINUX[ '$'\t]*=[ '$'\t]*enforcing[ '$'\t]*$' /etc/sysconfig/selinux 2>/dev/null || grep -Eq '^[ '$'\t]*SELINUX[ '$'\t]*=[ '$'\t]*enforcing[ '$'\t]*$' /etc/selinux/config 2>/dev/null; then
        yellow "检测到SELinux已开启，脚本可能无法正常运行"
        if ask_if "尝试关闭SELinux?(y/n)"; then
            turn_off_selinux
        else
            exit 0
        fi
    fi
}

#配置sshd
check_ssh_timeout()
{
    if grep -q "#This file has been edited by Xray-TLS-Web-setup-script" /etc/ssh/sshd_config; then
        return 0
    fi
    echo -e "\\n\\n\\n"
    tyblue "------------------------------------------"
    tyblue " Installation may take a long time"
    tyblue " It will be troublesome if you disconnect in the middle"
    tyblue " Setting the ssh connection timeout will effectively reduce the possibility of disconnection"
    echo
    ! ask_if "Whether to set the ssh connection timeout？(y/n)" && return 0
    sed -i '/^[ \t]*ClientAliveInterval[ \t]/d' /etc/ssh/sshd_config
    sed -i '/^[ \t]*ClientAliveCountMax[ \t]/d' /etc/ssh/sshd_config
    echo >> /etc/ssh/sshd_config
    echo "ClientAliveInterval 30" >> /etc/ssh/sshd_config
    echo "ClientAliveCountMax 60" >> /etc/ssh/sshd_config
    echo "#This file has been edited by Xray-TLS-Web-setup-script" >> /etc/ssh/sshd_config
    systemctl restart $ssh_service
    green  "----------------------configuration complete----------------------"
    tyblue " Please reconnect to the server for the configuration to take effect"
    if [ $in_install_update_xray_tls_web -eq 1 ]; then
        yellow " After reconnecting to the server, run the script again to complete the rest of the install/upgrade"
        yellow " When running the script again, repeat the previously selected options"
        yellow " press enter to exit。。。。"
        read -s
    fi
    exit 0
}

#删除防火墙和阿里云盾
uninstall_firewall()
{
    green "removing firewall。。。"
    ufw disable
    apt_purge firewalld
    apt_purge ufw
    systemctl stop firewalld
    systemctl disable firewalld
    $dnf -y remove firewalld
    green "Deleting Alibaba Cloud Shield and Tencent Cloud Shield (only valid for Alibaba Cloud and Tencent Cloud servers)。。。"
    #阿里云盾
    pkill -9 assist_daemon
    rm -rf /usr/local/share/assist-daemon
    systemctl stop CmsGoAgent
    systemctl disable CmsGoAgent
    systemctl stop cloudmonitor
    /etc/rc.d/init.d/cloudmonitor remove
    rm -rf /usr/local/cloudmonitor
    rm -rf /etc/systemd/system/CmsGoAgent.service
    systemctl daemon-reload
    #aliyun-assist
    systemctl stop AssistDaemon
    systemctl disable AssistDaemon
    systemctl stop aliyun
    systemctl disable aliyun
    apt_purge aliyun-assist
    $dnf -y remove aliyun_assist
    rm -rf /usr/local/share/aliyun-assist
    rm -rf /usr/sbin/aliyun_installer
    rm -rf /usr/sbin/aliyun-service
    rm -rf /usr/sbin/aliyun-service.backup
    rm -rf /etc/systemd/system/aliyun.service
    rm -rf /etc/systemd/system/AssistDaemon.service
    systemctl daemon-reload
    #AliYunDun aegis
    pkill -9 AliYunDunUpdate
    pkill -9 AliYunDun
    pkill -9 AliHids
    /etc/init.d/aegis uninstall
    rm -rf /usr/local/aegis
    rm -rf /etc/init.d/aegis
    rm -rf /etc/rc2.d/S80aegis
    rm -rf /etc/rc3.d/S80aegis
    rm -rf /etc/rc4.d/S80aegis
    rm -rf /etc/rc5.d/S80aegis

    #腾讯云盾
    /usr/local/qcloud/stargate/admin/uninstall.sh
    /usr/local/qcloud/YunJing/uninst.sh
    /usr/local/qcloud/monitor/barad/admin/uninstall.sh
    systemctl daemon-reload
    systemctl stop YDService
    systemctl disable YDService
    rm -rf /lib/systemd/system/YDService.service
    systemctl daemon-reload
    systemctl stop tat_agent
    systemctl disable tat_agent
    rm -rf /etc/systemd/system/tat_agent.service
    systemctl daemon-reload
    sed -i 's#/usr/local/qcloud#rcvtevyy4f5d#g' /etc/rc.local
    sed -i '/rcvtevyy4f5d/d' /etc/rc.local
    rm -rf $(find /etc/udev/rules.d -iname "*qcloud*" 2>/dev/null)
    pkill -9 watchdog.sh
    pkill -9 secu-tcs-agent
    pkill -9 YDService
    pkill -9 YDLive
    pkill -9 sgagent
    pkill -9 tat_agent
    pkill -9 /usr/local/qcloud
    pkill -9 barad_agent
    kill -s 9 "$(ps -aux | grep '/usr/local/qcloud/nv//nv_driver_install_helper\.sh' | awk '{print $2}')"
    rm -rf /usr/local/qcloud
    rm -rf /usr/local/sa
    rm -rf /usr/local/yd.socket.client
    rm -rf /usr/local/yd.socket.server
    mkdir /usr/local/qcloud
    mkdir /usr/local/qcloud/action
    mkdir /usr/local/qcloud/action/login_banner.sh
    mkdir /usr/local/qcloud/action/action.sh
    if [[ "$(type -P uname)" ]] && uname -a | grep solaris >/dev/null; then
        crontab -l | sed "/qcloud/d" | crontab --
    else
        crontab -l | sed "/qcloud/d" | crontab -
    fi

    # Huawei Cloud
    rm -rf /CloudResetPwdUpdateAgent
    rm -rf /etc/init.d/HSSInstall
    rm -rf /usr/local/uniagent
    pkill -9 uniagent
}

#升级系统组件
doupdate()
{
    updateSystem()
    {
        check_important_dependence_installed "ubuntu-release-upgrader-core"
        echo -e "\\n\\n\\n"
        tyblue "------------------Please choose to upgrade the system version--------------------"
        tyblue " 1. beta version (beta version)          current version number：22.10"
        tyblue " 2. release version (stable version)       current version number：22.10"
        tyblue " 3. LTS version (long-term support version)       current version number：22.04"
        tyblue " 0. Do not upgrade the system"
        tyblue "-------------------------Precautions-------------------------"
        yellow " 1.If you encounter a question/dialog box during the upgrade process, if you are not clear, please select yes/y/the first option"
        yellow " 2.Upgrading the system may take 15 minutes or more"
        yellow " 3.Sometimes it is not possible to update to the selected version at one time, and it may be necessary to update multiple times"
        yellow " 4.After upgrading the system, the following configurations may restore the system default configuration："
        yellow "     ssh port ssh timeout bbr speedup (revert to closed state)"
        tyblue "----------------------------------------------------------"
        green  " Your current system version is：$systemVersion"
        tyblue "----------------------------------------------------------"
        echo
        choice=""
        while [[ ! "$choice" =~ ^(0|[1-9][0-9]*)$ ]] || ((choice>3))
        do
            read -p "your choice is：" choice
        done
        if [ $choice -ne 0 ]; then
            if ! [[ "$(grep -i '^[ '$'\t]*port[ '$'\t]' /etc/ssh/sshd_config | awk '{print $2}')" =~ ^("22"|)$ ]]; then
                red "Detected that the ssh port number has been modified"
                red "After upgrading the system, the ssh port number may return to the default value (22)"
                yellow "press enter to continue。。。"
                read -s
            fi
            if [ $in_install_update_xray_tls_web -eq 1 ]; then
                echo
                tyblue "Reminder: Upgrading the system is about to start"
                yellow " After upgrading the system, the server will restart. After restarting, please run the script again to complete the installation/upgrade of the rest of Xray-TLS+Web"
                yellow " When running the script again, repeat the previously selected options"
                echo
                sleep 2s
                yellow "press enter to continue。。。"
                read -s
            fi
        fi
        local i
        for ((i=0;i<2;i++))
        do
            sed -i '/^[ \t]*Prompt[ \t]*=/d' /etc/update-manager/release-upgrades
            echo 'Prompt=normal' >> /etc/update-manager/release-upgrades
            case "$choice" in
                1)
                    do-release-upgrade -d -m server
                    do-release-upgrade -d -m server
                    sed -i 's/Prompt=normal/Prompt=lts/' /etc/update-manager/release-upgrades
                    do-release-upgrade -d -m server
                    do-release-upgrade -d -m server
                    sed -i 's/Prompt=lts/Prompt=normal/' /etc/update-manager/release-upgrades
                    do-release-upgrade -p -m server
                    do-release-upgrade -p -m server
                    sed -i 's/Prompt=normal/Prompt=lts/' /etc/update-manager/release-upgrades
                    do-release-upgrade -p -m server
                    do-release-upgrade -p -m server
                    ;;
                2)
                    do-release-upgrade -m server
                    do-release-upgrade -m server
                    ;;
                3)
                    sed -i 's/Prompt=normal/Prompt=lts/' /etc/update-manager/release-upgrades
                    do-release-upgrade -m server
                    do-release-upgrade -m server
                    ;;
            esac
            $apt -y --purge autoremove
            $apt update
            $apt -y --purge autoremove
            $apt -y --auto-remove --purge --no-install-recommends full-upgrade
            $apt -y --purge autoremove
            $apt clean
        done
    }
    while ((1))
    do
        echo -e "\\n\\n\\n"
        tyblue "-----------------------Whether to update system components？-----------------------"
        green  " 1. Update installed software and upgrade system (Ubuntu only)"
        green  " 2. Only update installed software"
        red    " 3. not update"
        if [ $release == "ubuntu" ] && (($(free -m | sed -n 2p | awk '{print $2}')<400)); then
            red "It is detected that the memory is too small, and upgrading the system may result in failure to boot, please choose carefully"
        fi
        echo
        choice=""
        while [ "$choice" != "1" ] && [ "$choice" != "2" ] && [ "$choice" != "3" ]
        do
            read -p "your choice is：" choice
        done
        if [ $release == "ubuntu" ] || [ $choice -ne 1 ]; then
            break
        fi
        echo
        yellow " The update system only supports Ubuntu！"
        sleep 3s
    done
    if [ $choice -eq 1 ]; then
        updateSystem
        $apt -y --purge autoremove
        $apt clean
    elif [ $choice -eq 2 ]; then
        tyblue "-----------------------Updating soon-----------------------"
        yellow " If you encounter a question/dialog box during the update process, if you don’t understand, select yes/y/the first option"
        yellow " press enter to continue。。。"
        read -s
        $apt -y --purge autoremove
        $apt update
        $apt -y --purge autoremove
        $apt -y --auto-remove --purge --no-install-recommends full-upgrade
        $apt -y --purge autoremove
        $apt clean
        $dnf -y autoremove
        $dnf_no_install_recommends -y upgrade
        $dnf -y autoremove
        $dnf clean all
    fi
}

#安装bbr
install_bbr()
{
    #输出：latest_kernel_version 和 your_kernel_version
    get_kernel_info()
    {
        green "Getting the latest kernel version number。。。。(If it is not successfully obtained within 60 seconds, it will be automatically skipped)"
        your_kernel_version="$(uname -r | cut -d - -f 1)"
        while [ ${your_kernel_version##*.} -eq 0 ]
        do
            your_kernel_version=${your_kernel_version%.*}
        done
        if ! timeout 60 wget -q -O "temp_kernel_version" "https://kernel.ubuntu.com/~kernel-ppa/mainline/"; then
            latest_kernel_version="error"
            return 1
        fi
        local kernel_list=()
        local kernel_list_temp
        kernel_list_temp=($(awk -F'\"v' '/v[0-9]/{print $2}' "temp_kernel_version" | cut -d '"' -f1 | cut -d '/' -f1 | sort -rV))
        if [ ${#kernel_list_temp[@]} -le 1 ]; then
            latest_kernel_version="error"
            return 1
        fi
        local i2=0
        local i3
        local kernel_rc=""
        local kernel_list_temp2
        while ((i2<${#kernel_list_temp[@]}))
        do
            if [[ "${kernel_list_temp[$i2]}" =~ -rc(0|[1-9][0-9]*)$ ]] && [ "$kernel_rc" == "" ]; then
                kernel_list_temp2=("${kernel_list_temp[$i2]}")
                kernel_rc="${kernel_list_temp[$i2]%-*}"
                ((i2++))
            elif [[ "${kernel_list_temp[$i2]}" =~ -rc(0|[1-9][0-9]*)$ ]] && [ "${kernel_list_temp[$i2]%-*}" == "$kernel_rc" ]; then
                kernel_list_temp2+=("${kernel_list_temp[$i2]}")
                ((i2++))
            elif [[ "${kernel_list_temp[$i2]}" =~ -rc(0|[1-9][0-9]*)$ ]] && [ "${kernel_list_temp[$i2]%-*}" != "$kernel_rc" ]; then
                for((i3=0;i3<${#kernel_list_temp2[@]};i3++))
                do
                    kernel_list+=("${kernel_list_temp2[$i3]}")
                done
                kernel_rc=""
            elif [ -z "$kernel_rc" ] || version_ge "${kernel_list_temp[$i2]}" "$kernel_rc"; then
                kernel_list+=("${kernel_list_temp[$i2]}")
                ((i2++))
            else
                for((i3=0;i3<${#kernel_list_temp2[@]};i3++))
                do
                    kernel_list+=("${kernel_list_temp2[$i3]}")
                done
                kernel_rc=""
            fi
        done
        if [ -n "$kernel_rc" ]; then
            for((i3=0;i3<${#kernel_list_temp2[@]};i3++))
            do
                kernel_list+=("${kernel_list_temp2[$i3]}")
            done
        fi
        latest_kernel_version="${kernel_list[0]}"
        if [ $release == "ubuntu" ] || [ $release == "debian" ] || [ $release == "deepin" ] || [ $release == "other-debian" ]; then
            local rc_version
            rc_version="$(uname -r | cut -d - -f 2)"
            if [[ $rc_version =~ rc ]]; then
                rc_version="${rc_version##*'rc'}"
                your_kernel_version="${your_kernel_version}-rc${rc_version}"
            fi
            uname -r | grep -q xanmod && your_kernel_version="${your_kernel_version}-xanmod"
        else
            latest_kernel_version="${latest_kernel_version%%-*}"
        fi
    }
    #卸载多余内核
    remove_other_kernel()
    {
        local exit_code=1
        if [ $release == "ubuntu" ] || [ $release == "debian" ] || [ $release == "deepin" ] || [ $release == "other-debian" ]; then
            dpkg --list > "temp_installed_list"
            local kernel_list_image
            kernel_list_image=($(awk '{print $2}' "temp_installed_list" | grep '^linux-image'))
            local kernel_list_modules
            kernel_list_modules=($(awk '{print $2}' "temp_installed_list" | grep '^linux-modules'))
            local kernel_now
            kernel_now="$(uname -r)"
            local ok_install=0
            for ((i=${#kernel_list_image[@]}-1;i>=0;i--))
            do
                if [[ "${kernel_list_image[$i]}" =~ "$kernel_now" ]]; then
                    unset 'kernel_list_image[$i]'
                    ((ok_install++))
                fi
            done
            if [ $ok_install -lt 1 ]; then
                red "The kernel in use was not found, it may have been uninstalled, please restart first"
                yellow "press enter to continue。。。"
                read -s
                return 1
            fi
            for ((i=${#kernel_list_modules[@]}-1;i>=0;i--))
            do
                if [[ "${kernel_list_modules[$i]}" =~ "$kernel_now" ]]; then
                    unset 'kernel_list_modules[$i]'
                fi
            done
            if [ ${#kernel_list_modules[@]} -eq 0 ] && [ ${#kernel_list_image[@]} -eq 0 ]; then
                yellow "no kernel to unload"
                return 0
            fi
            apt_purge "${kernel_list_image[@]}" "${kernel_list_modules[@]}" && exit_code=0
            [ $exit_code -eq 1 ] && $apt_no_install_recommends -y -f install
            apt-mark manual "^grub"
        else
            rpm -qa > "temp_installed_list"
            local kernel_list
            kernel_list=($(grep -E '^kernel(|-ml|-lt)-[0-9]' "temp_installed_list"))
            #local kernel_list_headers
            #kernel_list_headers=($(grep -E '^kernel(|-ml|-lt)-headers' "temp_installed_list"))
            local kernel_list_devel
            kernel_list_devel=($(grep -E '^kernel(|-ml|-lt)-devel' "temp_installed_list"))
            local kernel_list_modules
            kernel_list_modules=($(grep -E '^kernel(|-ml|-lt)-modules' "temp_installed_list"))
            local kernel_list_core
            kernel_list_core=($(grep -E '^kernel(|-ml|-lt)-core' "temp_installed_list"))
            local kernel_now
            kernel_now="$(uname -r)"
            local ok_install=0
            for ((i=${#kernel_list[@]}-1;i>=0;i--))
            do
                if [[ "${kernel_list[$i]}" =~ "$kernel_now" ]]; then
                    unset 'kernel_list[$i]'
                    ((ok_install++))
                fi
            done
            if [ $ok_install -lt 1 ]; then
                red "The kernel in use was not found, it may have been uninstalled, please restart first"
                yellow "press enter to continue。。。"
                read -s
                return 1
            fi
            #for ((i=${#kernel_list_headers[@]}-1;i>=0;i--))
            #do
            #    if [[ "${kernel_list_headers[$i]}" =~ "$kernel_now" ]]; then
            #        unset 'kernel_list_headers[$i]'
            #    fi
            #done
            for ((i=${#kernel_list_devel[@]}-1;i>=0;i--))
            do
                if [[ "${kernel_list_devel[$i]}" =~ "$kernel_now" ]]; then
                    unset 'kernel_list_devel[$i]'
                fi
            done
            for ((i=${#kernel_list_modules[@]}-1;i>=0;i--))
            do
                if [[ "${kernel_list_modules[$i]}" =~ "$kernel_now" ]]; then
                    unset 'kernel_list_modules[$i]'
                fi
            done
            for ((i=${#kernel_list_core[@]}-1;i>=0;i--))
            do
                if [[ "${kernel_list_core[$i]}" =~ "$kernel_now" ]]; then
                    unset 'kernel_list_core[$i]'
                fi
            done
            #if [ ${#kernel_list[@]} -eq 0 ] && [ ${#kernel_list_headers[@]} -eq 0 ] && [ ${#kernel_list_devel[@]} -eq 0 ] && [ ${#kernel_list_modules[@]} -eq 0 ] && [ ${#kernel_list_core[@]} -eq 0 ]; then
            if [ ${#kernel_list[@]} -eq 0 ] && [ ${#kernel_list_devel[@]} -eq 0 ] && [ ${#kernel_list_modules[@]} -eq 0 ] && [ ${#kernel_list_core[@]} -eq 0 ]; then
                yellow "no kernel to unload"
                return 0
            fi
            #$dnf -y remove "${kernel_list[@]}" "${kernel_list_headers[@]}" "${kernel_list_modules[@]}" "${kernel_list_core[@]}" "${kernel_list_devel[@]}" && exit_code=0
            $dnf -y remove "${kernel_list[@]}" "${kernel_list_modules[@]}" "${kernel_list_core[@]}" "${kernel_list_devel[@]}" && exit_code=0
        fi
        if [ $exit_code -eq 0 ]; then
            green "uninstalled successfully"
        else
            red "uninstall failed！"
            yellow "Press Enter to continue or Ctrl+c to exit"
            read -s
            return 1
        fi
    }
    change_qdisc()
    {
        local list=('fq' 'fq_pie' 'cake' 'fq_codel')
        tyblue "---------------Please select the queue algorithm you want to use---------------"
        green  " 1.fq"
        green  " 2.fq_pie"
        tyblue " 3.cake"
        tyblue " 4.fq_codel"
        choice=""
        while [[ ! "$choice" =~ ^([1-9][0-9]*)$ ]] || ((choice>4))
        do
            read -p "您的选择是：" choice
        done
        local qdisc="${list[$((choice-1))]}"
        local default_qdisc
        default_qdisc="$(sysctl net.core.default_qdisc | cut -d = -f 2 | awk '{print $1}')"
        sed -i '/^[ \t]*net.core.default_qdisc[ \t]*=/d' /etc/sysctl.conf
        echo "net.core.default_qdisc = $qdisc" >> /etc/sysctl.conf
        sysctl -p
        sleep 1s
        if [ "$(sysctl net.core.default_qdisc | cut -d = -f 2 | awk '{print $1}')" == "$qdisc" ]; then
            green "Replaced successfully！"
        else
            red "Replacement failed, kernel does not support"
            sed -i '/^[ \t]*net.core.default_qdisc[ \t]*=/d' /etc/sysctl.conf
            echo "net.core.default_qdisc = $default_qdisc" >> /etc/sysctl.conf
            return 1
        fi
    }
    enable_ecn()
    {
        if [[ ! -f /sys/module/tcp_bbr2/parameters/ecn_enable ]] || [ "$(sysctl net.ipv4.tcp_congestion_control | cut -d = -f 2 | awk '{print $1}')" != "bbr2" ]; then
            red "Please enable bbr2 first！"
            return 1
        fi
        if [ "$(cat /sys/module/tcp_bbr2/parameters/ecn_enable)" == "Y" ] && [ "$(sysctl net.ipv4.tcp_ecn | cut -d = -f 2 | awk '{print $1}')" == "1" ]; then
            green "bbr2_ECN 已启用！"
            tyblue "重启系统bbr2_ECN将自动关闭"
            return 0
        fi
        tyblue "Tip: bbr2_ECN will be automatically closed after system restart"
        tyblue " 若重启系统，可以 运行脚本 -> 安装/更新bbr -> 启用bbr2_ECN 来重新启用bbr2_ECN"
        yellow "press enter to continue。。。"
        read -s
        echo Y > /sys/module/tcp_bbr2/parameters/ecn_enable
        sysctl net.ipv4.tcp_ecn=1
        sleep 1s
        if [ "$(cat /sys/module/tcp_bbr2/parameters/ecn_enable)" == "Y" ] && [ "$(sysctl net.ipv4.tcp_ecn | cut -d = -f 2 | awk '{print $1}')" == "1" ]; then
            green "bbr2_ECN 已启用"
            return 0
        else
            red "bbr2_ECN 启用失败"
            return 1
        fi
    }
    local your_kernel_version
    local latest_kernel_version
    get_kernel_info
    if ! grep -q "#This file has been edited by Xray-TLS-Web-setup-script" /etc/sysctl.conf; then
        echo >> /etc/sysctl.conf
        echo "#This file has been edited by Xray-TLS-Web-setup-script" >> /etc/sysctl.conf
    fi
    while :
    do
        echo -e "\\n\\n\\n"
        tyblue "------------------Please select the bbr version you want to use------------------"
        green  "  1. Install/upgrade the latest stable kernel and enable bbr (recommended)"
        green  "  2. Install/upgrade latest xanmod kernel and enable bbr (recommended)"
        green  "  3. Install/upgrade latest xanmod kernel and enable bbr2 (recommended)"
        tyblue "  4. Install/upgrade the latest version of the kernel and enable bbr"
        if version_ge $your_kernel_version 4.9; then
            tyblue "  5. enable bbr"
        else
            tyblue "  5. Upgrade the kernel to enable bbr"
        fi
        tyblue "  6. enable bbr2"
        tyblue "  7. Install a third-party kernel and enable bbrplus/bbr magic revision/violent bbr magic revision/sharp speed"
        tyblue "  8. Replace Queue Algorithm"
        tyblue "  9. Enable/disable bbr2_ECN"
        tyblue " 10. Unload extra kernels"
        tyblue "  0. exit bbr install"
        tyblue "------------------Instructions for installing bbr acceleration------------------"
        green  " The bbr congestion algorithm can greatly increase the network speed, it is recommended to enable it"
        yellow " Replacing the third-party kernel may cause the system to be unstable or even unable to boot"
        tyblue "---------------------------------------------------------"
        tyblue " current kernel version：${your_kernel_version}"
        tyblue " latest kernel version：${latest_kernel_version}"
        tyblue " Does the current kernel support bbr："
        if version_ge $your_kernel_version 4.9; then
            green "     yes"
        else
            red "     No, the kernel needs to be upgraded"
        fi
        tyblue "   Current Congestion Control Algorithm："
        local tcp_congestion_control
        tcp_congestion_control=$(sysctl net.ipv4.tcp_congestion_control | cut -d = -f 2 | awk '{print $1}')
        if [[ "$tcp_congestion_control" =~ bbr|nanqinlang|tsunami ]]; then
            if [ $tcp_congestion_control == nanqinlang ]; then
                tcp_congestion_control="${tcp_congestion_control} \\033[35m(Violent bbr magic version)"
            elif [ $tcp_congestion_control == tsunami ]; then
                tcp_congestion_control="${tcp_congestion_control} \\033[35m(bbr magic revision)"
            fi
            green  "       ${tcp_congestion_control}"
        else
            tyblue "       ${tcp_congestion_control} \\033[31m(bbr is not enabled)"
        fi
        tyblue "   current queue algorithm："
        green "       $(sysctl net.core.default_qdisc | cut -d = -f 2 | awk '{print $1}')"
        tyblue "   Current bbr2_ECN："
        if [ "$(cat /sys/module/tcp_bbr2/parameters/ecn_enable 2>/dev/null)" == "Y" ] && [ "$(sysctl net.ipv4.tcp_ecn | cut -d = -f 2 | awk '{print $1}')" == "1" ]; then
            green  "       activated"
        else
            blue   "       Not Enabled"
        fi
        echo
        local choice=""
        while [[ ! "$choice" =~ ^(0|[1-9][0-9]*)$ ]] || ((choice>10))
        do
            read -p "your choice is：" choice
        done
        if (( 1<=choice&&choice<=4 )); then
            if (( choice==1 || choice==4 )) && ([ $release == "ubuntu" ] || [ $release == "debian" ] || [ $release == "deepin" ] || [ $release == "other-debian" ]) && ! dpkg-deb --help | grep -qw "zstd"; then
                red    "The current system dpkg does not support decompressing zst packages, and does not support installing this kernel！"
                green  "Please update the system, or choose to use another system, or choose to install the xanmod kernel"
            elif (( choice==2 || choice==3 )) && ([ $release == "centos" ] || [ $release == centos-stream ] || [ $release == oracle ] || [ $release == "rhel" ] || [ $release == "fedora" ] || [ $release == "other-redhat" ]); then
                red "The xanmod kernel only supports Debian-based systems, such as Ubuntu, Debian, deepin, UOS"
            else
                if (( choice==1 || choice==4 )) && ([ $release == "ubuntu" ] || [ $release == "debian" ] || [ $release == "deepin" ] || [ $release == "other-debian" ]); then
                    check_important_dependence_installed "linux-base" ""
                    if ! version_ge "$(dpkg --list | grep '^[ '$'\t]*ii[ '$'\t][ '$'\t]*linux-base[ '$'\t]' | awk '{print $3}')" "4.5ubuntu1~16.04.1"; then
                        install_dependence linux-base
                        if ! version_ge "$(dpkg --list | grep '^[ '$'\t]*ii[ '$'\t][ '$'\t]*linux-base[ '$'\t]' | awk '{print $3}')" "4.5ubuntu1~16.04.1"; then
                            if ! $apt update; then
                                red "$apt update出错"
                                green  "欢迎进行Bug report(https://github.com/kirin10000/Xray-script/issues)，thank you for your support"
                                yellow "Press Enter to continue or Ctrl+c to exit"
                                read -s
                            fi
                            install_dependence linux-base
                        fi
                    fi
                fi
                if (( choice==1 || choice==4 )) && ([ $release == "ubuntu" ] || [ $release == "debian" ] || [ $release == "deepin" ] || [ $release == "other-debian" ]) && ! version_ge "$(dpkg --list | grep '^[ '$'\t]*ii[ '$'\t][ '$'\t]*linux-base[ '$'\t]' | awk '{print $3}')" "4.5ubuntu1~16.04.1"; then
                    red    "The current system version is too low to support the installation of this kernel！"
                    green  "Please use a new system or choose to install the xanmod kernel"
                else
                    if [ $choice -eq 3 ]; then
                        local temp_bbr=bbr2
                    else
                        local temp_bbr=bbr
                    fi
                    if ! ([ "$(sysctl net.ipv4.tcp_congestion_control | cut -d = -f 2 | awk '{print $1}')" == "$temp_bbr" ] && [ "$(grep '^[ '$'\t]*net.ipv4.tcp_congestion_control[ '$'\t]*=' "/etc/sysctl.conf" | tail -n 1 | cut -d = -f 2 | awk '{print $1}')" == "$temp_bbr" ] && [ "$(sysctl net.core.default_qdisc | cut -d = -f 2 | awk '{print $1}')" == "$(grep '^[ '$'\t]*net.core.default_qdisc[ '$'\t]*=' "/etc/sysctl.conf" | tail -n 1 | cut -d = -f 2 | awk '{print $1}')" ]); then
                        sed -i '/^[ \t]*net.core.default_qdisc[ \t]*=/d' /etc/sysctl.conf
                        sed -i '/^[ \t]*net.ipv4.tcp_congestion_control[ \t]*=/d' /etc/sysctl.conf
                        echo 'net.core.default_qdisc = fq' >> /etc/sysctl.conf
                        echo "net.ipv4.tcp_congestion_control = $temp_bbr" >> /etc/sysctl.conf
                        sysctl -p
                    fi
                    if [ $in_install_update_xray_tls_web -eq 1 ]; then
                        echo
                        tyblue "hint："
                        yellow " After changing the kernel, the server will restart. After restarting, please run the script again to complete the installation/upgrade of the rest of Xray-TLS+Web"
                        yellow " When running the script again, repeat the previously selected options"
                        echo
                        sleep 2s
                        yellow "press enter to continue。。。"
                        read -s
                    fi
                    local temp_kernel_sh_url
                    if [ $choice -eq 1 ]; then
                        temp_kernel_sh_url="https://github.com/kirin10000/update-kernel/raw/master/update-kernel-stable.sh"
                    elif [ $choice -eq 4 ]; then
                        temp_kernel_sh_url="https://github.com/kirin10000/update-kernel/raw/master/update-kernel.sh"
                    else
                        temp_kernel_sh_url="https://github.com/kirin10000/xanmod-install/raw/main/xanmod-install.sh"
                    fi
                    if ! wget -O kernel.sh "$temp_kernel_sh_url"; then
                        red    "Failed to fetch kernel install script"
                        yellow "Press Enter to continue or Ctrl+c to terminate"
                        read -s
                    fi
                    chmod +x kernel.sh
                    ./kernel.sh
                    if [ "$(sysctl net.ipv4.tcp_congestion_control | cut -d = -f 2 | awk '{print $1}')" == "$temp_bbr" ] && [ "$(sysctl net.core.default_qdisc | cut -d = -f 2 | awk '{print $1}')" == "$(grep '^[ '$'\t]*net.core.default_qdisc[ '$'\t]*=' "/etc/sysctl.conf" | tail -n 1 | cut -d = -f 2 | awk '{print $1}')" ]; then
                        green "--------------------$temp_bbr Installed--------------------"
                    else
                        red "Failed to open $temp_bbr"
                        red "If you have just installed the kernel, please reboot first"
                        red "If restarting still doesn't work, try option 3"
                    fi
                fi
            fi
        elif [ $choice -eq 5 ]; then
            if [ "$(sysctl net.ipv4.tcp_congestion_control | cut -d = -f 2 | awk '{print $1}')" == "bbr" ] && [ "$(grep '^[ '$'\t]*net.ipv4.tcp_congestion_control[ '$'\t]*=' "/etc/sysctl.conf" | tail -n 1 | cut -d = -f 2 | awk '{print $1}')" == "bbr" ] && [ "$(sysctl net.core.default_qdisc | cut -d = -f 2 | awk '{print $1}')" == "$(grep '^[ '$'\t]*net.core.default_qdisc[ '$'\t]*=' "/etc/sysctl.conf" | tail -n 1 | cut -d = -f 2 | awk '{print $1}')" ]; then
                green "--------------------bbr installed--------------------"
            else
                sed -i '/^[ \t]*net.core.default_qdisc[ \t]*=/d' /etc/sysctl.conf
                sed -i '/^[ \t]*net.ipv4.tcp_congestion_control[ \t]*=/d' /etc/sysctl.conf
                echo 'net.core.default_qdisc = fq' >> /etc/sysctl.conf
                echo 'net.ipv4.tcp_congestion_control = bbr' >> /etc/sysctl.conf
                sysctl -p
                sleep 1s
                if [ "$(sysctl net.ipv4.tcp_congestion_control | cut -d = -f 2 | awk '{print $1}')" == "bbr" ] && [ "$(sysctl net.core.default_qdisc | cut -d = -f 2 | awk '{print $1}')" == "fq" ]; then
                    green "--------------------bbr installed--------------------"
                else
                    if [ $in_install_update_xray_tls_web -eq 1 ]; then
                        echo
                        tyblue "Tip: To enable bbr, you need to replace the kernel"
                        yellow " After changing the kernel, the server will restart. After restarting, please run the script again to complete the installation/upgrade of the rest of Xray-TLS+Web"
                        yellow " When running the script again, repeat the previously selected options"
                        echo
                        sleep 2s
                        yellow "press enter to continue。。。"
                        read -s
                    fi
                    if ! wget -O bbr.sh https://github.com/teddysun/across/raw/master/bbr.sh; then
                        red    "Failed to get bbr script"
                        yellow "Press Enter to continue or Ctrl+c to terminate"
                        read -s
                    fi
                    chmod +x bbr.sh
                    ./bbr.sh
                fi
            fi
        elif [ $choice -eq 6 ]; then
            if [ "$(sysctl net.ipv4.tcp_congestion_control | cut -d = -f 2 | awk '{print $1}')" == "bbr2" ] && [ "$(grep '^[ '$'\t]*net.ipv4.tcp_congestion_control[ '$'\t]*=' "/etc/sysctl.conf" | tail -n 1 | cut -d = -f 2 | awk '{print $1}')" == "bbr2" ] && [ "$(sysctl net.core.default_qdisc | cut -d = -f 2 | awk '{print $1}')" == "$(grep '^[ '$'\t]*net.core.default_qdisc[ '$'\t]*=' "/etc/sysctl.conf" | tail -n 1 | cut -d = -f 2 | awk '{print $1}')" ]; then
                green "--------------------bbr2 installed--------------------"
            else
                sed -i '/^[ \t]*net.core.default_qdisc[ \t]*=/d' /etc/sysctl.conf
                sed -i '/^[ \t]*net.ipv4.tcp_congestion_control[ \t]*=/d' /etc/sysctl.conf
                echo 'net.core.default_qdisc = fq' >> /etc/sysctl.conf
                echo 'net.ipv4.tcp_congestion_control = bbr2' >> /etc/sysctl.conf
                sysctl -p
                sleep 1s
                if [ "$(sysctl net.ipv4.tcp_congestion_control | cut -d = -f 2 | awk '{print $1}')" == "bbr2" ] && [ "$(sysctl net.core.default_qdisc | cut -d = -f 2 | awk '{print $1}')" == "fq" ]; then
                    green "--------------------bbr2 installed--------------------"
                else
                    red "Failed to enable bbr2"
                    yellow "Maybe the kernel doesn't support"
                fi
            fi
        elif [ $choice -eq 7 ]; then
            tyblue "Tips: Installing bbrplus/bbr magic revision/violent bbr magic revision/sharp kernel needs to be restarted"
            if [ $in_install_update_xray_tls_web -eq 1 ]; then
                yellow " After restarting, please："
                yellow "    1. Run the script again, repeating the previously selected options"
                yellow "    2. At this point, select this option again to complete the installation of the remaining parts of bbrplus/bbr magic revision/violent bbr magic revision/sharp speed"
                yellow "    3. choose \"exit bbr install\" option complete Xray-TLS+Web Installation/upgrade of the remainder"
            else
                yellow " After restarting, please run the script again and select this option to complete the installation of the remaining parts of bbrplus/bbr magic revision/violent bbr magic revision/sharp speed"
            fi
            sleep 2s
            yellow " press enter to continue。。。。"
            read -s
            if ! wget -O tcp.sh "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh"; then
                red    "Failed to fetch script"
                yellow "Press Enter to continue or Ctrl+c to terminate"
                read -s
            fi
            chmod +x tcp.sh
            ./tcp.sh
        elif [ $choice -eq 8 ]; then
            change_qdisc
        elif [ $choice -eq 9 ]; then
            enable_ecn
        elif [ $choice -eq 10 ]; then
            tyblue " This operation will uninstall all kernels except the one currently in use"
            tyblue "    The kernel you are using is：$(uname -r)"
            ask_if "Whether to continue？(y/n)" && remove_other_kernel
        else
            break
        fi
        sleep 3s
    done
}

#读取xray_protocol配置
readProtocolConfig()
{
    echo -e "\\n\\n\\n"
    tyblue "---------------------Please select a transfer protocol---------------------"
    tyblue " 1. TCP"
    tyblue " 2. gRPC"
    tyblue " 3. WebSocket"
    tyblue " 4. TCP + gRPC"
    tyblue " 5. TCP + WebSocket"
    tyblue " 6. gRPC + WebSocket"
    tyblue " 7. TCP + gRPC + WebSocket"
    yellow " 0. None (web service only)"
    echo
    blue   " Note："
    blue   "   1. If you don't use CDN, please choose TCP"
    blue   "   2. gRPC and WebSocket support CDN. For the difference between the two, see: https://github.com/kirin10000/Xray-script#About grpc and websocket"
    blue   "   3. Only TCP can use XTLS"
    echo
    local choice=""
    while [[ ! "$choice" =~ ^(0|[1-9][0-9]*)$ ]] || ((choice>7))
    do
        read -p "your choice is：" choice
    done
    if [ $choice -eq 1 ] || [ $choice -eq 4 ] || [ $choice -eq 5 ] || [ $choice -eq 7 ]; then
        protocol_1=1
    else
        protocol_1=0
    fi
    if [ $choice -eq 2 ] || [ $choice -eq 4 ] || [ $choice -eq 6 ] || [ $choice -eq 7 ]; then
        protocol_2=1
    else
        protocol_2=0
    fi
    if [ $choice -eq 3 ] || [ $choice -eq 5 ] || [ $choice -eq 6 ] || [ $choice -eq 7 ]; then
        protocol_3=1
    else
        protocol_3=0
    fi
    if [ $protocol_1 -eq 1 ]; then
        tyblue "-------------- Please select a TCP transport configuration --------------"
        tyblue " 1. VLESS + TCP + XTLS"
        tyblue " 2. VLESS + TCP + TLS"
        tyblue " 3. VLESS + TCP + XTLS/TLS"
        echo
        protocol_1=""
        while [[ ! "$protocol_1" =~ ^([1-9][0-9]*)$ ]] || ((protocol_1>3))
        do
            read -p "your choice is：" protocol_1
        done
    fi
    if [ $protocol_2 -eq 1 ]; then
        tyblue "-------------- Please select the proxy protocol that uses gRPC transport --------------"
        tyblue " 1. VMess"
        tyblue " 2. VLESS"
        echo
        yellow " Note: The advantage of using VMess is that the CDN can be encrypted. If VLESS is used, the CDN provider can obtain the transmission plaintext"
        echo
        choice=""
        while [[ ! "$choice" =~ ^([1-9][0-9]*)$ ]] || ((choice>2))
        do
            read -p "your choice is：" choice
        done
        [ $choice -eq 1 ] && protocol_2=2
    fi
    if [ $protocol_3 -eq 1 ]; then
        tyblue "-------------- Please select the proxy protocol that uses WebSocket transport --------------"
        tyblue " 1. VMess"
        tyblue " 2. VLESS"
        echo
        yellow " Note: The advantage of using VMess is that the CDN can be encrypted. If VLESS is used, the CDN provider can obtain the transmission plaintext"
        echo
        choice=""
        while [[ ! "$choice" =~ ^([1-9][0-9]*)$ ]] || ((choice>2))
        do
            read -p "your choice is：" choice
        done
        [ $choice -eq 1 ] && protocol_3=2
    fi
}

#读取伪装类型 输入domain 输出pretend
readPretend()
{
    local queren=0
    while [ $queren -ne 1 ]
    do
        echo -e "\\n\\n\\n"
        tyblue "------------------------------Please choose a fake website page------------------------------"
        green  " 1. Cloudreve (recommend)"
        purple "     Personal network disk"
        green  " 2. Nextcloud (recommend)"
        purple "     Personal network disk, need to install php"
        tyblue " 3. 403 page"
        purple "     Simulation website background"
        red    " 4. Custom static website (not recommended)"
        red    " 5. Custom reverse proxy web pages (not recommended)"
        echo
        green  " Memory <128MB, it is recommended to choose 403 page"
        green  " 128MB<=memory<1G, it is recommended to choose Cloudreve"
        green  " Memory>=1G It is recommended to choose Nextcloud or Cloudreve"
        echo
        yellow " For detailed instructions on choosing a camouflaged website, see：https://github.com/kirin10000/Xray-script#伪装网站说明"
        echo
        pretend=""
        while [[ "$pretend" != "1" && "$pretend" != "2" && "$pretend" != "3" && "$pretend" != "4" && "$pretend" != "5" ]]
        do
            read -p "your choice is：" pretend
        done
        queren=1
        if [ $pretend -eq 1 ]; then
            if [ -z "$machine" ]; then
                red "Your VPS instruction set does not support Cloudreve！"
                yellow "Cloudreve only supports x86_64, arm64, armv7, armv6, armv5 !"
                sleep 3s
                queren=0
            fi
        elif [ $pretend -eq 2 ]; then
            if (([ $release == "centos" ] || [ $release == centos-stream ] || [ $release == oracle ]) && ! version_ge "$systemVersion" "8" ) || ([ $release == "rhel" ] && ! version_ge "$systemVersion" "8") || ([ $release == "fedora" ] && ! version_ge "$systemVersion" "30") || ([ $release == "ubuntu" ] && ! version_ge "$systemVersion" "20.04") || ([ $release == "debian" ] && ! version_ge "$systemVersion" "11"); then
                red "The system version is too low to install php！"
                echo
                tyblue "Installing Nextcloud requires installing php"
                yellow "Only support the installation of php under the following version systems："
                yellow " 1. Ubuntu 20.04+"
                yellow " 2. Debian 11+"
                yellow " 3. 其他以 Debian 11+ 为基的系统"
                yellow " 4. Red Hat Enterprise Linux 8+"
                yellow " 5. CentOS 8+"
                yellow " 6. Fedora 30+"
                yellow " 7. Oracle Linux 8+"
                yellow " 8. 其他以 Red Hat 8+ 为基的系统"
                sleep 3s
                queren=0
                continue
            elif [ $release == "other-debian" ] || [ $release == "other-redhat" ]; then
                yellow "未知的系统，可能导致php安装失败！"
                echo
                tyblue "安装Nextcloud需要安装php"
                yellow "仅支持在以下版本系统下安装php："
                yellow " 1. Ubuntu 20.04+"
                yellow " 2. Debian 11+"
                yellow " 3. 其他以 Debian 11+ 为基的系统"
                yellow " 4. Red Hat Enterprise Linux 8+"
                yellow " 5. CentOS 8+"
                yellow " 6. Fedora 30+"
                yellow " 7. Oracle Linux 8+"
                yellow " 8. 其他以 Red Hat 8+ 为基的系统"
                ! ask_if "确定选择吗？(y/n)" && queren=0 && continue
            elif [ $release == "deepin" ]; then
                red "php暂不支持deepin，请更换其他系统"
                sleep 3s
                queren=0
                continue
            fi
            if [ $php_is_installed -eq 0 ]; then
                tyblue "安装Nextcloud需要安装php"
                yellow "编译&&安装php可能需要额外消耗15-60分钟"
                yellow "php将占用一定系统资源，不建议内存<512M的机器使用"
                ! ask_if "确定选择吗？(y/n)" && queren=0
            fi
        elif [ $pretend -eq 4 ]; then
            tyblue "安装完成后请在 \"${nginx_prefix}/html/$1\" 放置您的网站源代码"
            ! ask_if "确认并继续？(y/n)" && queren=0
        elif [ $pretend -eq 5 ]; then
            yellow "输入反向代理网址，格式如：\"https://v.qq.com\""
            pretend=""
            while [ -z "$pretend" ]
            do
                read -p "Please enter the reverse proxy URL：" pretend
            done
        fi
    done
}
readDomain()
{
    check_domain()
    {
        if [ -z "$1" ]; then
            return 1
        elif [ "${1%%.*}" == "www" ]; then
            red "Do not put www in front of the domain name！"
            return 1
        elif [ "$(echo -n "$1" | wc -c)" -gt 42 ]; then
            red "domain name too long！"
            return 1
        else
            return 0
        fi
    }
    local domain
    local domain_config=""
    local pretend
    echo -e "\\n\\n\\n"
    tyblue "--------------------Please select the domain name resolution--------------------"
    tyblue " 1. Both the main domain name and www.main domain name are resolved to this server \\033[32m(recommend)"
    green  "    like：123.com and www.123.com resolve to this server"
    tyblue " 2. Only a specific domain name resolves to this server"
    green  "    like：123.com or www.123.com or xxx.123.com One of the resolves to this server"
    echo
    while [ "$domain_config" != "1" ] && [ "$domain_config" != "2" ]
    do
        read -p "your choice is：" domain_config
    done
    local queren=0
    while [ $queren -ne 1 ]
    do
        domain=""
        echo
        if [ $domain_config -eq 1 ]; then
            tyblue '---------Please enter the primary domain name (without the preceding"www."、"http://"or"https://")---------'
            while ! check_domain "$domain"
            do
                read -p "Please enter a domain name：" domain
            done
        else
            tyblue '-------Please enter the domain name resolved to this server (without"http://"or"https://")-------'
            while [ -z "$domain" ]
            do
                read -p "Please enter a domain name：" domain
                if [ "$(echo -n "$domain" | wc -c)" -gt 46 ]; then
                    red "domain name too long！"
                    domain=""
                fi
            done
        fi
        echo
        ask_if "The domain name you entered is\"$domain\"，Are you sure?？(y/n)" && queren=1
    done
    readPretend "$domain"
    true_domain_list+=("$domain")
    [ $domain_config -eq 1 ] && domain_list+=("www.$domain") || domain_list+=("$domain")
    domain_config_list+=("$domain_config")
    pretend_list+=("$pretend")
}

install_nginx_compile_toolchains()
{
    green "Installing the Nginx compilation toolchain。。。"
    if [ $release == "centos" ] || [ $release == centos-stream ] || [ $release == oracle ] || [ $release == "rhel" ] || [ $release == "fedora" ] || [ $release == "other-redhat" ]; then
        install_dependence ca-certificates wget gcc gcc-c++ make perl-IPC-Cmd perl-Getopt-Long perl-Data-Dumper
        if ! perl -e "use FindBin" > /dev/null 2>&1; then
            install_dependence perl-FindBin
        fi
    else
        install_dependence ca-certificates wget gcc g++ make perl-base perl
    fi
}
install_php_compile_toolchains()
{
    green "Installing the php compilation toolchain。。。"
    if [ $release == "centos" ] || [ $release == centos-stream ] || [ $release == oracle ] || [ $release == "rhel" ] || [ $release == "fedora" ] || [ $release == "other-redhat" ]; then
        install_dependence ca-certificates wget xz gcc gcc-c++ make pkgconf-pkg-config autoconf git
    else
        install_dependence ca-certificates wget xz-utils gcc g++ make pkg-config autoconf git
    fi
}
install_nginx_dependence()
{
    green "Installing Nginx dependencies。。。"
    if [ $release == "centos" ] || [ $release == centos-stream ] || [ $release == oracle ] || [ $release == "rhel" ] || [ $release == "fedora" ] || [ $release == "other-redhat" ]; then
        install_dependence pcre2-devel zlib-devel libxml2-devel libxslt-devel gd-devel geoip-devel perl-ExtUtils-Embed gperftools-devel perl-devel
    else
        install_dependence libpcre2-dev zlib1g-dev libxml2-dev libxslt1-dev libgd-dev libgeoip-dev libgoogle-perftools-dev libperl-dev
    fi
}
install_php_dependence()
{
    green "Installing php dependencies。。。"
    if [ $release == "centos" ] || [ $release == centos-stream ] || [ $release == oracle ] || [ $release == "rhel" ] || [ $release == "fedora" ] || [ $release == "other-redhat" ]; then
        fedora_install_remi
        install_dependence libxml2-devel sqlite-devel systemd-devel libacl-devel openssl-devel krb5-devel pcre2-devel zlib-devel bzip2-devel libcurl-devel gdbm-devel libdb-devel tokyocabinet-devel lmdb-devel enchant-devel libffi-devel libpng-devel gd-devel libwebp-devel libjpeg-turbo-devel libXpm-devel freetype-devel gmp-devel uw-imap-devel libicu-devel openldap-devel oniguruma-devel unixODBC-devel freetds-devel libpq-devel aspell-devel libedit-devel net-snmp-devel libsodium-devel libargon2-devel libtidy-devel libxslt-devel libzip-devel ImageMagick-devel
    else
        if ! $apt_no_install_recommends -y install libxml2-dev libsqlite3-dev libsystemd-dev libacl1-dev libapparmor-dev libssl-dev libkrb5-dev libpcre2-dev zlib1g-dev libbz2-dev libcurl4-openssl-dev libqdbm-dev libdb-dev libtokyocabinet-dev liblmdb-dev libenchant-2-dev libffi-dev libpng-dev libgd-dev libwebp-dev libjpeg-dev libxpm-dev libfreetype6-dev libgmp-dev libc-client2007e-dev libicu-dev libldap2-dev libsasl2-dev libonig-dev unixodbc-dev freetds-dev libpq-dev libpspell-dev libedit-dev libmm-dev libsnmp-dev libsodium-dev libargon2-dev libtidy-dev libxslt1-dev libzip-dev libmagickwand-dev && ! $apt_no_install_recommends -y install libxml2-dev libsqlite3-dev libsystemd-dev libacl1-dev libapparmor-dev libssl-dev libkrb5-dev libpcre2-dev zlib1g-dev libbz2-dev libcurl4-openssl-dev libqdbm-dev libdb-dev libtokyocabinet-dev liblmdb-dev libenchant-dev libffi-dev libpng-dev libgd-dev libwebp-dev libjpeg-dev libxpm-dev libfreetype6-dev libgmp-dev libc-client2007e-dev libicu-dev libldap2-dev libsasl2-dev libonig-dev unixodbc-dev freetds-dev libpq-dev libpspell-dev libedit-dev libmm-dev libsnmp-dev libsodium-dev libargon2-dev libtidy-dev libxslt1-dev libzip-dev libmagickwand-dev; then
            $apt update
            $apt_no_install_recommends -y -f install
            if ! $apt_no_install_recommends -y install libxml2-dev libsqlite3-dev libsystemd-dev libacl1-dev libapparmor-dev libssl-dev libkrb5-dev libpcre2-dev zlib1g-dev libbz2-dev libcurl4-openssl-dev libqdbm-dev libdb-dev libtokyocabinet-dev liblmdb-dev libenchant-2-dev libffi-dev libpng-dev libgd-dev libwebp-dev libjpeg-dev libxpm-dev libfreetype6-dev libgmp-dev libc-client2007e-dev libicu-dev libldap2-dev libsasl2-dev libonig-dev unixodbc-dev freetds-dev libpq-dev libpspell-dev libedit-dev libmm-dev libsnmp-dev libsodium-dev libargon2-dev libtidy-dev libxslt1-dev libzip-dev libmagickwand-dev && ! $apt_no_install_recommends -y install libxml2-dev libsqlite3-dev libsystemd-dev libacl1-dev libapparmor-dev libssl-dev libkrb5-dev libpcre2-dev zlib1g-dev libbz2-dev libcurl4-openssl-dev libqdbm-dev libdb-dev libtokyocabinet-dev liblmdb-dev libenchant-dev libffi-dev libpng-dev libgd-dev libwebp-dev libjpeg-dev libxpm-dev libfreetype6-dev libgmp-dev libc-client2007e-dev libicu-dev libldap2-dev libsasl2-dev libonig-dev unixodbc-dev freetds-dev libpq-dev libpspell-dev libedit-dev libmm-dev libsnmp-dev libsodium-dev libargon2-dev libtidy-dev libxslt1-dev libzip-dev libmagickwand-dev; then
                yellow "Dependency installation failed！！"
                green  "欢迎进行Bug report(https://github.com/kirin10000/Xray-script/issues)，感谢您的支持"
                yellow "Press Enter to continue or Ctrl+c to exit"
                read -s
            fi
        fi
    fi
}
install_acme_dependence()
{
    green "Installing acme.sh dependency。。。"
    if [ $release == "centos" ] || [ $release == centos-stream ] || [ $release == oracle ] || [ $release == "rhel" ] || [ $release == "fedora" ] || [ $release == "other-redhat" ]; then
        install_dependence curl openssl crontabs
    else
        install_dependence curl openssl cron
    fi
}
install_web_dependence()
{
    green "Installing masquerade site dependencies。。。"
    if [ "$1" == "" ]; then
        for i in "${pretend_list[@]}"
        do
            if [ "$i" == "1" ]; then
                install_dependence ca-certificates wget
                break
            fi
        done
        for i in "${pretend_list[@]}"
        do
            if [ "$i" == "2" ]; then
                install_dependence ca-certificates curl bzip2
                break
            fi
        done
    else
        if [ "$1" == "1" ]; then
            install_dependence ca-certificates wget
        elif [ "$1" == "2" ]; then
            install_dependence ca-certificates curl bzip2
        fi
    fi
}

#编译&&安装php
compile_php()
{
    green "compiling php。。。。"
    local cflags
    local cxxflags
    gen_cflags
    gen_cxxflags
    if ! wget -O "${php_version}.tar.xz" "https://www.php.net/distributions/${php_version}.tar.xz"; then
        red    "Failed to fetch php"
        yellow "Press Enter to continue or Ctrl+c to terminate"
        read -s
    fi
    tar -xJf "${php_version}.tar.xz"
    rm -f "${php_version}.tar.xz"
    cd "${php_version}"
    sed -i 's#db$THIS_VERSION/db_185.h include/db$THIS_VERSION/db_185.h include/db/db_185.h#& include/db_185.h#' configure
    if [ $release == "ubuntu" ] || [ $release == "debian" ] || [ $release == "deepin" ] || [ $release == "other-debian" ]; then
        sed -i 's#if test -f $THIS_PREFIX/$PHP_LIBDIR/lib$LIB.a || test -f $THIS_PREFIX/$PHP_LIBDIR/lib$LIB.$SHLIB_SUFFIX_NAME#& || true#' configure
        sed -i 's#if test ! -r "$PDO_FREETDS_INSTALLATION_DIR/$PHP_LIBDIR/libsybdb.a" && test ! -r "$PDO_FREETDS_INSTALLATION_DIR/$PHP_LIBDIR/libsybdb.so"#& \&\& false#' configure
        ./configure --prefix=${php_prefix} --enable-embed=shared --enable-fpm --with-fpm-user=www-data --with-fpm-group=www-data --with-fpm-systemd --with-fpm-acl --with-fpm-apparmor --disable-phpdbg --with-layout=GNU --with-openssl --with-kerberos --with-external-pcre --with-zlib --enable-bcmath --with-bz2 --enable-calendar --with-curl --enable-dba --with-qdbm --with-db4 --with-db1 --with-tcadb --with-lmdb --with-enchant --enable-exif --with-ffi --enable-ftp --enable-gd --with-external-gd --with-avif --with-webp --with-jpeg --with-xpm --with-freetype --enable-gd-jis-conv --with-gettext --with-gmp --with-mhash --with-imap --with-imap-ssl --enable-intl --with-ldap --with-ldap-sasl --enable-mbstring --with-mysqli --with-mysql-sock --with-unixODBC --enable-pcntl --with-pdo-dblib --with-pdo-mysql --with-zlib-dir --with-pdo-odbc=unixODBC,/usr --with-pdo-pgsql --with-pgsql --with-pspell --with-libedit --with-mm --enable-shmop --with-snmp --enable-soap --enable-sockets --with-sodium --with-external-libcrypt --with-password-argon2 --enable-sysvmsg --enable-sysvsem --enable-sysvshm --with-tidy --with-xsl --with-zip --enable-mysqlnd --with-pear CFLAGS="${cflags[*]}" CXXFLAGS="${cxxflags[*]}"
    else
        ./configure --prefix=${php_prefix} --with-libdir=lib64 --enable-embed=shared --enable-fpm --with-fpm-user=www-data --with-fpm-group=www-data --with-fpm-systemd --with-fpm-acl --disable-phpdbg --with-layout=GNU --with-openssl --with-kerberos --with-external-pcre --with-zlib --enable-bcmath --with-bz2 --enable-calendar --with-curl --enable-dba --with-gdbm --with-db4 --with-db1 --with-tcadb --with-lmdb --with-enchant --enable-exif --with-ffi --enable-ftp --enable-gd --with-external-gd --with-avif --with-webp --with-jpeg --with-xpm --with-freetype --enable-gd-jis-conv --with-gettext --with-gmp --with-mhash --with-imap --with-imap-ssl --enable-intl --with-ldap --with-ldap-sasl --enable-mbstring --with-mysqli --with-mysql-sock --with-unixODBC --enable-pcntl --with-pdo-dblib --with-pdo-mysql --with-zlib-dir --with-pdo-odbc=unixODBC,/usr --with-pdo-pgsql --with-pgsql --with-pspell --with-libedit --enable-shmop --with-snmp --enable-soap --enable-sockets --with-sodium --with-external-libcrypt --with-password-argon2 --enable-sysvmsg --enable-sysvsem --enable-sysvshm --with-tidy --with-xsl --with-zip --enable-mysqlnd --with-pear CFLAGS="${cflags[*]}" CXXFLAGS="${cxxflags[*]}"
    fi
    swap_on 2048
    if ! make -j$cpu_thread_num; then
        swap_off
        red    "php compilation failed！"
        green  "欢迎进行Bug report(https://github.com/kirin10000/Xray-script/issues)，感谢您的支持"
        yellow "Before the bug is fixed, it is recommended to use the latest version of Ubuntu system"
        exit 1
    fi
    swap_off
    cd ..
}
instal_php_imagick()
{
    local cflags
    gen_cflags
    if ! git clone https://github.com/Imagick/imagick; then
        yellow "Failed to get php-imagick source code"
        yellow "Press Enter to continue or Ctrl+c to terminate"
        read -s
    fi
    cd imagick
    ${php_prefix}/bin/phpize
    ./configure --with-php-config=${php_prefix}/bin/php-config CFLAGS="${cflags[*]}"
    swap_on 380
    if ! make -j$cpu_thread_num; then
        swap_off
        yellow "php-imagick compilation failed"
        green  "欢迎进行Bug report(https://github.com/kirin10000/Xray-script/issues)，感谢您的支持"
        yellow "Before the bug is fixed, it is recommended to use the latest version of Ubuntu system"
        yellow "Press Enter to continue or Ctrl+c to terminate"
        read -s
    else
        swap_off
    fi
    mv modules/imagick.so "$(${php_prefix}/bin/php -i | grep "^extension_dir" | awk '{print $3}')"
    cd ..
    rm -rf imagick
}
install_php_part1()
{
    green "installing php。。。。"
    cd "${php_version}"
    make install
    mv sapi/fpm/php-fpm.service "${php_prefix}/php-fpm.service.default.temp"
    mv php.ini-production "${php_prefix}"
    mv php.ini-development "${php_prefix}"
    cd ..
    rm -rf "${php_version}"
    instal_php_imagick
    mv "${php_prefix}/php-fpm.service.default.temp" "${php_prefix}/php-fpm.service.default"
    php_is_installed=1
}
install_php_part2()
{
    useradd -r -s /bin/bash www-data
    cp ${php_prefix}/etc/php-fpm.conf.default ${php_prefix}/etc/php-fpm.conf
    cp ${php_prefix}/etc/php-fpm.d/www.conf.default ${php_prefix}/etc/php-fpm.d/www.conf
    sed -i 's/^[ \t]*listen[ \t]*=/;&/g' ${php_prefix}/etc/php-fpm.d/www.conf
    sed -i 's/^[ \t]*env\[PATH\][ \t]*=/;&/g' ${php_prefix}/etc/php-fpm.d/www.conf
cat >> ${php_prefix}/etc/php-fpm.d/www.conf << EOF

listen = /dev/shm/php-fpm/php-fpm.sock
pm = dynamic
pm.max_children = $((16*cpu_thread_num))
pm.start_servers = $cpu_thread_num
pm.min_spare_servers = $cpu_thread_num
pm.max_spare_servers = $((16*cpu_thread_num))
env[PATH] = $PATH
EOF
    rm -rf "${php_prefix}/etc/php.ini"
    cp "${php_prefix}/php.ini-production" "${php_prefix}/etc/php.ini"
cat >> ${php_prefix}/etc/php.ini << EOF

[PHP]
extension=imagick.so
zend_extension=opcache.so
opcache.enable=1
date.timezone=$timezone

;如果使用mysql，并且使用unix domain socket方式连接，请正确设置以下内容
;pdo_mysql.default_socket=/var/run/mysqld/mysqld.sock
;mysqli.default_socket=/var/run/mysqld/mysqld.sock

memory_limit=-1
post_max_size=0
upload_max_filesize=9223372036854775807
max_file_uploads=50000
max_execution_time=0
max_input_time=0
output_buffering=4096
session.auto_start=0
EOF
    install -m 644 "${php_prefix}/php-fpm.service.default" $php_service
cat >> $php_service <<EOF

[Service]
ProtectSystem=false
ExecStartPre=/bin/rm -rf /dev/shm/php-fpm
ExecStartPre=/bin/mkdir /dev/shm/php-fpm
ExecStartPre=/bin/chmod 711 /dev/shm/php-fpm
ExecStartPre=/bin/chown www-data:www-data /dev/shm/php-fpm
ExecStopPost=/bin/rm -rf /dev/shm/php-fpm
EOF
    systemctl daemon-reload
}

#编译&&安装nignx
compile_nginx()
{
    green "Compiling Nginx。。。。"
    local cflags
    gen_cflags
    if ! wget -O ${nginx_version}.tar.gz https://nginx.org/download/${nginx_version}.tar.gz; then
        red    "Failed to fetch nginx"
        yellow "Press Enter to continue or Ctrl+c to terminate"
        read -s
    fi
    tar -zxf ${nginx_version}.tar.gz
    rm -f "${nginx_version}.tar.gz"
    if ! wget -O ${openssl_version}.tar.gz https://github.com/openssl/openssl/archive/${openssl_version#*-}.tar.gz; then
        red    "Failed to get openssl"
        yellow "Press Enter to continue or Ctrl+c to terminate"
        read -s
    fi
    tar -zxf ${openssl_version}.tar.gz
    rm -f "${openssl_version}.tar.gz"
    cd ${nginx_version}
    sed -i "s/OPTIMIZE[ \\t]*=>[ \\t]*'-O'/OPTIMIZE          => '-O3'/g" src/http/modules/perl/Makefile.PL
    sed -i 's/NGX_PERL_CFLAGS="$CFLAGS `$NGX_PERL -MExtUtils::Embed -e ccopts`"/NGX_PERL_CFLAGS="`$NGX_PERL -MExtUtils::Embed -e ccopts` $CFLAGS"/g' auto/lib/perl/conf
    sed -i 's/NGX_PM_CFLAGS=`$NGX_PERL -MExtUtils::Embed -e ccopts`/NGX_PM_CFLAGS="`$NGX_PERL -MExtUtils::Embed -e ccopts` $CFLAGS"/g' auto/lib/perl/conf
    ./configure --prefix="${nginx_prefix}" --user=root --group=root --with-threads --with-file-aio --with-http_ssl_module --with-http_v2_module --with-http_realip_module --with-http_addition_module --with-http_xslt_module=dynamic --with-http_image_filter_module=dynamic --with-http_geoip_module=dynamic --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_auth_request_module --with-http_random_index_module --with-http_secure_link_module --with-http_degradation_module --with-http_slice_module --with-http_stub_status_module --with-http_perl_module=dynamic --with-mail=dynamic --with-mail_ssl_module --with-stream=dynamic --with-stream_ssl_module --with-stream_realip_module --with-stream_geoip_module=dynamic --with-stream_ssl_preread_module --with-google_perftools_module --with-compat --with-cc-opt="${cflags[*]}" --with-openssl="../$openssl_version" --with-openssl-opt="${cflags[*]}"
    #--with-select_module --with-poll_module --with-cpp_test_module --with-pcre --with-pcre-jit --with-libatomic
    #./configure --prefix=/usr/local/nginx --with-openssl=../$openssl_version --with-mail=dynamic --with-mail_ssl_module --with-stream=dynamic --with-stream_ssl_module --with-stream_realip_module --with-stream_geoip_module=dynamic --with-stream_ssl_preread_module --with-http_ssl_module --with-http_v2_module --with-http_realip_module --with-http_addition_module --with-http_xslt_module=dynamic --with-http_image_filter_module=dynamic --with-http_geoip_module=dynamic --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_auth_request_module --with-http_random_index_module --with-http_secure_link_module --with-http_degradation_module --with-http_slice_module --with-http_stub_status_module --with-http_perl_module=dynamic --with-pcre --with-libatomic --with-compat --with-cpp_test_module --with-google_perftools_module --with-file-aio --with-threads --with-poll_module --with-select_module --with-cc-opt="-Wno-error ${cflags[*]}"
    swap_on 480
    if ! make -j$cpu_thread_num; then
        swap_off
        red    "Nginx compilation failed！"
        green  "欢迎进行Bug report(https://github.com/kirin10000/Xray-script/issues)，感谢您的支持"
        yellow "Before the bug is fixed, it is recommended to use the latest version of Ubuntu system"
        exit 1
    fi
    swap_off
    cd ..
}
config_service_nginx()
{
    rm -rf $nginx_service
cat > $nginx_service << EOF
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
User=root
ExecStartPre=/bin/rm -rf /dev/shm/nginx
ExecStartPre=/bin/mkdir /dev/shm/nginx
ExecStartPre=/bin/chmod 711 /dev/shm/nginx
ExecStartPre=/bin/mkdir /dev/shm/nginx/tcmalloc
ExecStartPre=/bin/chmod 0777 /dev/shm/nginx/tcmalloc
ExecStart=${nginx_prefix}/sbin/nginx
ExecStop=${nginx_prefix}/sbin/nginx -s stop
ExecStopPost=/bin/rm -rf /dev/shm/nginx
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    chmod 644 $nginx_service
    systemctl daemon-reload
}
install_nginx_part1()
{
    green "Installing Nginx。。。"
    cd "${nginx_version}"
    make install
    cd ..
    rm -rf "${nginx_version}"
    rm -rf "$openssl_version"
}
install_nginx_part2()
{
    mkdir ${nginx_prefix}/conf.d
    touch $nginx_config
    mkdir ${nginx_prefix}/certs
    mkdir ${nginx_prefix}/html/issue_certs
cat > ${nginx_prefix}/conf/issue_certs.conf << EOF
events {
    worker_connections  1024;
}
http {
    server {
        listen [::]:80 ipv6only=off;
        root ${nginx_prefix}/html/issue_certs;
    }
}
EOF
cat > ${nginx_prefix}/conf.d/nextcloud.conf <<EOF
    client_max_body_size 0;
    #client_body_timeout 300s;
    fastcgi_buffers 64 4K;
    gzip on;
    gzip_vary on;
    gzip_comp_level 4;
    gzip_min_length 256;
    gzip_proxied expired no-cache no-store private no_last_modified no_etag auth;
    gzip_types application/atom+xml application/javascript application/json application/ld+json application/manifest+json application/rss+xml application/vnd.geo+json application/vnd.ms-fontobject application/x-font-ttf application/x-web-app-manifest+json application/xhtml+xml application/xml font/opentype image/bmp image/svg+xml image/x-icon text/cache-manifest text/css text/plain text/vcard text/vnd.rim.location.xloc text/vtt text/x-component text/x-cross-domain-policy;
    add_header Referrer-Policy                      "no-referrer"   always;
    add_header X-Content-Type-Options               "nosniff"       always;
    add_header X-Download-Options                   "noopen"        always;
    add_header X-Frame-Options                      "SAMEORIGIN"    always;
    add_header X-Permitted-Cross-Domain-Policies    "none"          always;
    add_header X-Robots-Tag                         "none"          always;
    add_header X-XSS-Protection                     "1; mode=block" always;
    fastcgi_hide_header X-Powered-By;
    index index.php index.html /index.php\$request_uri;
    location = / {
        if ( \$http_user_agent ~ ^DavClnt ) {
            return 302 https://\$host/remote.php/webdav/\$is_args\$args;
        }
    }
    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }
    location ^~ /.well-known {
        location = /.well-known/carddav { return 301 https://\$host/remote.php/dav/; }
        location = /.well-known/caldav  { return 301 https://\$host/remote.php/dav/; }
        location /.well-known/acme-challenge    { try_files \$uri \$uri/ =404; }
        location /.well-known/pki-validation    { try_files \$uri \$uri/ =404; }
        return 301 https://\$host/index.php\$request_uri;
    }
    location ~ ^/(?:build|tests|config|lib|3rdparty|templates|data)(?:$|/)  { return 404; }
    location ~ ^/(?:\\.|autotest|occ|issue|indie|db_|console)                { return 404; }
    location ~ \\.php(?:$|/) {
        rewrite ^/(?!index|remote|public|cron|core\\/ajax\\/update|status|ocs\\/v[12]|updater\\/.+|oc[ms]-provider\\/.+|.+\\/richdocumentscode\\/proxy) /index.php\$request_uri;
        fastcgi_split_path_info ^(.+?\\.php)(/.*)$;
        set \$path_info \$fastcgi_path_info;
        try_files \$fastcgi_script_name =404;
        include fastcgi.conf;
        fastcgi_param PATH_INFO \$path_info;
        fastcgi_param REMOTE_ADDR 127.0.0.1;
        fastcgi_param SERVER_PORT 443;
        fastcgi_param HTTPS on;
        fastcgi_param modHeadersAvailable true;
        fastcgi_param front_controller_active true;
        fastcgi_pass unix:/dev/shm/php-fpm/php-fpm.sock;
        fastcgi_intercept_errors on;
        fastcgi_request_buffering off;
        fastcgi_read_timeout 24h;
        fastcgi_max_temp_file_size 0;
    }
    location ~ \\.(?:css|js|svg|gif|png|jpg|ico)$ {
        try_files \$uri /index.php\$request_uri;
        expires 6M;
        access_log off;
    }
    location ~ \\.woff2?$ {
        try_files \$uri /index.php\$request_uri;
        expires 7d;
        access_log off;
    }
    location /remote {
        return 301 https://\$host/remote.php\$request_uri;
    }
    location / {
        try_files \$uri \$uri/ /index.php\$request_uri;
    }
EOF
    config_service_nginx
    systemctl enable nginx
    nginx_is_installed=1
    [ $xray_is_installed -eq 1 ] && is_installed=1 || is_installed=0
}

#安装/更新Xray
install_update_xray()
{
    green "Installing/updating Xray。。。。"
    if ! bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root --without-geodata --without-logfiles && ! bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root --without-geodata --without-logfiles; then
        red    "Installing/updating Xray fails"
        yellow "Press Enter to continue or Ctrl+c to terminate"
        read -s
        return 1
    fi
    if ! grep -q "# This file has been edited by Xray-TLS-Web setup script" /etc/systemd/system/xray.service; then
cat >> /etc/systemd/system/xray.service <<EOF

# This file has been edited by Xray-TLS-Web setup script
[Service]
ExecStartPre=/bin/rm -rf /dev/shm/xray
ExecStartPre=/bin/mkdir /dev/shm/xray
ExecStartPre=/bin/chmod 711 /dev/shm/xray
ExecStopPost=/bin/rm -rf /dev/shm/xray
EOF
        systemctl daemon-reload
        systemctl -q is-active xray && systemctl restart xray
    fi
    systemctl enable xray
    xray_is_installed=1
    [ $nginx_is_installed -eq 1 ] && is_installed=1 || is_installed=0
}

#获取证书 参数: 域名位置
get_cert()
{
    if [ ${domain_config_list[$1]} -eq 1 ]; then
        green "retrieving \"${domain_list[$1]}\"、\"${true_domain_list[$1]}\" domain name certificate"
    else
        green "retrieving \"${domain_list[$1]}\" domain name certificate"
    fi
    mv $xray_config ${xray_config}.bak
    mv ${nginx_prefix}/conf/nginx.conf ${nginx_prefix}/conf/nginx.conf.bak2
    cp ${nginx_prefix}/conf/nginx.conf.default ${nginx_prefix}/conf/nginx.conf
    echo "{}" > $xray_config
    local temp=""
    [ ${domain_config_list[$1]} -eq 1 ] && temp="-d ${domain_list[$1]}"
    if ! $HOME/.acme.sh/acme.sh --issue -d ${true_domain_list[$1]} $temp -w ${nginx_prefix}/html/issue_certs -k ec-256 -ak ec-256 --pre-hook "mv ${nginx_prefix}/conf/nginx.conf ${nginx_prefix}/conf/nginx.conf.bak && cp ${nginx_prefix}/conf/issue_certs.conf ${nginx_prefix}/conf/nginx.conf && sleep 2s && systemctl restart nginx" --post-hook "mv ${nginx_prefix}/conf/nginx.conf.bak ${nginx_prefix}/conf/nginx.conf && sleep 2s && systemctl restart nginx" --ocsp && ! $HOME/.acme.sh/acme.sh --issue -d ${true_domain_list[$1]} $temp -w ${nginx_prefix}/html/issue_certs -k ec-256 -ak ec-256 --server letsencrypt --pre-hook "mv ${nginx_prefix}/conf/nginx.conf ${nginx_prefix}/conf/nginx.conf.bak && cp ${nginx_prefix}/conf/issue_certs.conf ${nginx_prefix}/conf/nginx.conf && sleep 2s && systemctl restart nginx" --post-hook "mv ${nginx_prefix}/conf/nginx.conf.bak ${nginx_prefix}/conf/nginx.conf && sleep 2s && systemctl restart nginx" --ocsp; then
        $HOME/.acme.sh/acme.sh --issue -d ${true_domain_list[$1]} $temp -w ${nginx_prefix}/html/issue_certs -k ec-256 -ak ec-256 --pre-hook "mv ${nginx_prefix}/conf/nginx.conf ${nginx_prefix}/conf/nginx.conf.bak && cp ${nginx_prefix}/conf/issue_certs.conf ${nginx_prefix}/conf/nginx.conf && sleep 2s && systemctl restart nginx" --post-hook "mv ${nginx_prefix}/conf/nginx.conf.bak ${nginx_prefix}/conf/nginx.conf && sleep 2s && systemctl restart nginx" --ocsp --debug || $HOME/.acme.sh/acme.sh --issue -d ${true_domain_list[$1]} $temp -w ${nginx_prefix}/html/issue_certs -k ec-256 -ak ec-256 --server letsencrypt --pre-hook "mv ${nginx_prefix}/conf/nginx.conf ${nginx_prefix}/conf/nginx.conf.bak && cp ${nginx_prefix}/conf/issue_certs.conf ${nginx_prefix}/conf/nginx.conf && sleep 2s && systemctl restart nginx" --post-hook "mv ${nginx_prefix}/conf/nginx.conf.bak ${nginx_prefix}/conf/nginx.conf && sleep 2s && systemctl restart nginx" --ocsp --debug
    fi
    if ! $HOME/.acme.sh/acme.sh --installcert -d ${true_domain_list[$1]} --key-file ${nginx_prefix}/certs/${true_domain_list[$1]}.key --fullchain-file ${nginx_prefix}/certs/${true_domain_list[$1]}.cer --reloadcmd "sleep 2s && systemctl restart xray" --ecc; then
        $HOME/.acme.sh/acme.sh --remove --domain ${true_domain_list[$1]} --ecc
        rm -rf $HOME/.acme.sh/${true_domain_list[$1]}_ecc
        rm -rf "${nginx_prefix}/certs/${true_domain_list[$1]}.key" "${nginx_prefix}/certs/${true_domain_list[$1]}.cer"
        mv ${xray_config}.bak $xray_config
        mv ${nginx_prefix}/conf/nginx.conf.bak2 ${nginx_prefix}/conf/nginx.conf
        return 1
    fi
    mv ${xray_config}.bak $xray_config
    mv ${nginx_prefix}/conf/nginx.conf.bak2 ${nginx_prefix}/conf/nginx.conf
    return 0
}
get_all_certs()
{
    local i
    for ((i=0;i<${#domain_list[@]};i++))
    do
        if ! get_cert "$i"; then
            red    "domain name\"${true_domain_list[$i]}\"Certificate request failed！"
            yellow "Check, please："
            yellow "    1.Whether the domain name is resolved correctly"
            yellow "    2.Is port 80 of the vps firewall open?"
            yellow "And after the install/reset domain is complete, use the script main menu\"reset domain name\"option fix"
            yellow "press enter to continue。。。"
            read -s
        fi
    done
}

#配置nginx
config_nginx_init()
{
cat > ${nginx_prefix}/conf/nginx.conf <<EOF

user  root root;
worker_processes  auto;

#error_log  logs/error.log;
#error_log  logs/error.log  notice;
#error_log  logs/error.log  info;

#pid        logs/nginx.pid;
google_perftools_profiles /dev/shm/nginx/tcmalloc/tcmalloc;

events {
    worker_connections  1024;
}


http {
    include       mime.types;
    default_type  application/octet-stream;

    #log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
    #                  '\$status \$body_bytes_sent "\$http_referer" '
    #                  '"\$http_user_agent" "\$http_x_forwarded_for"';

    #access_log  logs/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  65;

    #gzip  on;

    include       $nginx_config;
    #server {
        #listen       80;
        #server_name  localhost;

        #charset koi8-r;

        #access_log  logs/host.access.log  main;

        #location / {
        #    root   html;
        #    index  index.html index.htm;
        #}

        #error_page  404              /404.html;

        # redirect server error pages to the static page /50x.html
        #
        #error_page   500 502 503 504  /50x.html;
        #location = /50x.html {
        #    root   html;
        #}

        # proxy the PHP scripts to Apache listening on 127.0.0.1:80
        #
        #location ~ \\.php\$ {
        #    proxy_pass   http://127.0.0.1;
        #}

        # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
        #
        #location ~ \\.php\$ {
        #    root           html;
        #    fastcgi_pass   127.0.0.1:9000;
        #    fastcgi_index  index.php;
        #    fastcgi_param  SCRIPT_FILENAME  /scripts\$fastcgi_script_name;
        #    include        fastcgi_params;
        #}

        # deny access to .htaccess files, if Apache's document root
        # concurs with nginx's one
        #
        #location ~ /\\.ht {
        #    deny  all;
        #}
    #}


    # another virtual host using mix of IP-, name-, and port-based configuration
    #
    #server {
    #    listen       8000;
    #    listen       somename:8080;
    #    server_name  somename  alias  another.alias;

    #    location / {
    #        root   html;
    #        index  index.html index.htm;
    #    }
    #}


    # HTTPS server
    #
    #server {
    #    listen       443 ssl;
    #    server_name  localhost;

    #    ssl_certificate      cert.pem;
    #    ssl_certificate_key  cert.key;

    #    ssl_session_cache    shared:SSL:1m;
    #    ssl_session_timeout  5m;

    #    ssl_ciphers  HIGH:!aNULL:!MD5;
    #    ssl_prefer_server_ciphers  on;

    #    location / {
    #        root   html;
    #        index  index.html index.htm;
    #    }
    #}

}
EOF
}
config_nginx()
{
    config_nginx_init
    local i
cat > $nginx_config<<EOF
server {
    listen 80 reuseport default_server;
    listen [::]:80 reuseport default_server;
    return 301 https://${domain_list[0]};
}
server {
    listen 80;
    listen [::]:80;
    server_name ${domain_list[@]};
    return 301 https://\$host\$request_uri;
}
EOF
    local temp_domain_list2=()
    for i in "${!domain_config_list[@]}"
    do
        [ ${domain_config_list[$i]} -eq 1 ] && temp_domain_list2+=("${true_domain_list[$i]}")
    done
    if [ ${#temp_domain_list2[@]} -ne 0 ]; then
cat >> $nginx_config<<EOF
server {
    listen 80;
    listen [::]:80;
    listen unix:/dev/shm/nginx/default.sock;
    listen unix:/dev/shm/nginx/h2.sock http2;
    server_name ${temp_domain_list2[@]};
    return 301 https://www.\$host\$request_uri;
}
EOF
    fi
cat >> $nginx_config<<EOF
server {
    listen unix:/dev/shm/nginx/default.sock default_server;
    listen unix:/dev/shm/nginx/h2.sock http2 default_server;
    return 301 https://${domain_list[0]};
}
EOF
    for ((i=0;i<${#domain_list[@]};i++))
    do
cat >> $nginx_config<<EOF
server {
    listen unix:/dev/shm/nginx/default.sock;
    listen unix:/dev/shm/nginx/h2.sock http2;
    server_name ${domain_list[$i]};
    add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload" always;
EOF
        if [ $protocol_2 -ne 0 ]; then
cat >> $nginx_config<<EOF
    #client_header_timeout 24h;
    #ignore_invalid_headers off;
    location = /$serviceName/TunMulti {
        client_max_body_size 0;
        client_body_timeout 24h;
        #keepalive_requests 1000;
        #keepalive_time 24h;
        keepalive_timeout 24h;
        send_timeout 24h;
        #grpc_buffer_size 0;
        grpc_read_timeout 24h;
        grpc_send_timeout 24h;
        #grpc_socket_keepalive off;
        lingering_close always;
        lingering_time 24h;
        lingering_timeout 24h;
        grpc_pass grpc://unix:/dev/shm/xray/grpc.sock;
    }
EOF
        fi
        if [ "${pretend_list[$i]}" == "1" ]; then
cat >> $nginx_config<<EOF
    location / {
        proxy_set_header X-Forwarded-For 127.0.0.1;
        proxy_set_header Host \$http_host;
        proxy_redirect off;
        proxy_pass http://unix:/dev/shm/cloudreve/cloudreve.sock;
        client_max_body_size 0;
    }
EOF
        elif [ "${pretend_list[$i]}" == "2" ]; then
            echo "    root ${nginx_prefix}/html/${true_domain_list[$i]};" >> $nginx_config
            echo "    include ${nginx_prefix}/conf.d/nextcloud.conf;" >> $nginx_config
        elif [ "${pretend_list[$i]}" == "3" ]; then
            if [ $protocol_2 -ne 0 ]; then
                echo "    location / {" >> $nginx_config
                echo "        return 403;" >> $nginx_config
                echo "    }" >> $nginx_config
            else
                echo "    return 403;" >> $nginx_config
            fi
        elif [ "${pretend_list[$i]}" == "4" ]; then
            echo "    root ${nginx_prefix}/html/${true_domain_list[$i]};" >> $nginx_config
        else
cat >> $nginx_config<<EOF
    location / {
        proxy_pass ${pretend_list[$i]};
        proxy_set_header referer "${pretend_list[$i]}";
    }
EOF
        fi
        echo "}" >> $nginx_config
    done
cat >> $nginx_config << EOF
#-----------------Do not modify the following----------------
#domain_list=${domain_list[@]}
#true_domain_list=${true_domain_list[@]}
#domain_config_list=${domain_config_list[@]}
#pretend_list=${pretend_list[@]}
EOF
}

#配置xray
config_xray()
{
    local i
    local temp_domain
cat > $xray_config <<EOF
{
    "log": {
        "loglevel": "none"
    },
    "inbounds": [
        {
            "port": 443,
            "protocol": "vless",
            "settings": {
EOF
    if [ $protocol_1 -ne 0 ]; then
        echo '                "clients": [' >> $xray_config
        echo '                    {' >> $xray_config
        if [ $protocol_1 -eq 1 ]; then
            echo '                        "id": "'"$xid_1"'",' >> $xray_config
            echo '                        "flow": "xtls-rprx-vision"' >> $xray_config
        elif [ $protocol_1 -eq 2 ]; then
            echo '                        "id": "'"$xid_1"'"' >> $xray_config
        else
            echo '                        "id": "'"$xid_1"'",' >> $xray_config
            echo '                        "flow": "xtls-rprx-vision,none"' >> $xray_config
        fi
        echo '                    }' >> $xray_config
        echo '                ],' >> $xray_config
    fi
    echo '                "decryption": "none",' >> $xray_config
    echo '                "fallbacks": [' >> $xray_config
    if [ $protocol_3 -ne 0 ]; then
cat >> $xray_config <<EOF
                    {
                        "path": "$path",
                        "dest": "@/dev/shm/xray/ws.sock"
                    },
EOF
    fi
cat >> $xray_config <<EOF
                    {
                        "alpn": "h2",
                        "dest": "/dev/shm/nginx/h2.sock"
                    },
                    {
                        "dest": "/dev/shm/nginx/default.sock"
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "tls",
                "tlsSettings": {
                    "alpn": [
                        "h2",
                        "http/1.1"
                    ],
                    "minVersion": "1.2",
                    "certificates": [
EOF
    for ((i=0;i<${#true_domain_list[@]};i++))
    do
cat >> $xray_config <<EOF
                        {
                            "certificateFile": "${nginx_prefix}/certs/${true_domain_list[$i]}.cer",
                            "keyFile": "${nginx_prefix}/certs/${true_domain_list[$i]}.key",
                            "ocspStapling": 3600
EOF
        ((i==${#true_domain_list[@]}-1)) && echo "                        }" >> $xray_config || echo "                        }," >> $xray_config
    done
cat >> $xray_config <<EOF
                    ]
                }
            }
EOF
    if [ $protocol_2 -ne 0 ]; then
        echo '        },' >> $xray_config
        echo '        {' >> $xray_config
        echo '            "listen": "/dev/shm/xray/grpc.sock",' >> $xray_config
        if [ $protocol_2 -eq 2 ]; then
            echo '            "protocol": "vmess",' >> $xray_config
        else
            echo '            "protocol": "vless",' >> $xray_config
        fi
        echo '            "settings": {' >> $xray_config
        echo '                "clients": [' >> $xray_config
        echo '                    {' >> $xray_config
        echo "                        \"id\": \"$xid_2\"" >> $xray_config
        echo '                    }' >> $xray_config
        if [ $protocol_2 -eq 2 ]; then
            echo '                ]' >> $xray_config
        else
            echo '                ],' >> $xray_config
            echo '                "decryption": "none"' >> $xray_config
        fi
cat >> $xray_config <<EOF
            },
            "streamSettings": {
                "network": "grpc",
                "grpcSettings": {
                    "serviceName": "$serviceName"
                }
            }
EOF
    fi
    if [ $protocol_3 -ne 0 ]; then
        echo '        },' >> $xray_config
        echo '        {' >> $xray_config
        echo '            "listen": "@/dev/shm/xray/ws.sock",' >> $xray_config
        if [ $protocol_3 -eq 2 ]; then
            echo '            "protocol": "vmess",' >> $xray_config
        else
            echo '            "protocol": "vless",' >> $xray_config
        fi
        echo '            "settings": {' >> $xray_config
        echo '                "clients": [' >> $xray_config
        echo '                    {' >> $xray_config
        echo "                        \"id\": \"$xid_3\"" >> $xray_config
        echo '                    }' >> $xray_config
        if [ $protocol_3 -eq 2 ]; then
            echo '                ]' >> $xray_config
        else
            echo '                ],' >> $xray_config
            echo '                "decryption": "none"' >> $xray_config
        fi
cat >> $xray_config <<EOF
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "$path"
                }
            }
EOF
    fi
cat >> $xray_config <<EOF
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
}
EOF
}

init_web()
{
    systemctl stop php-fpm
    systemctl stop cloudreve
    if [ "${pretend_list[$1]}" == "1" ]; then
        if [ $cloudreve_is_installed -eq 1 ]; then
            systemctl start cloudreve
            systemctl enable cloudreve
            let_change_cloudreve_domain "$1"
        else
            install_init_cloudreve "$1"
        fi
        turn_on_off_php
    elif [ "${pretend_list[$1]}" == "2" ]; then
        if ! curl -o "${nginx_prefix}/html/nextcloud.tar.bz2" "${nextcloud_url}"; then
            red    "Failed to get Nextcloud"
            yellow "Press Enter to continue or Ctrl+c to terminate"
            read -s
        fi
        rm -rf "${nginx_prefix}/html/nextcloud"
        if ! tar -xjf "${nginx_prefix}/html/nextcloud.tar.bz2" -C "${nginx_prefix}/html"; then
            red    "Unpacking Nextcloud failed"
            yellow "Press Enter to continue or Ctrl+c to terminate"
            read -s
        fi
        rm -f "${nginx_prefix}/html/nextcloud.tar.bz2"
        rm -rf "${nginx_prefix}/html/${true_domain_list[$1]}"
        mv "${nginx_prefix}/html/nextcloud" "${nginx_prefix}/html/${true_domain_list[$1]}"
        chown -R www-data:www-data "${nginx_prefix}/html/${true_domain_list[$1]}"
        systemctl start php-fpm
        systemctl enable php-fpm
        let_init_nextcloud "$1"
        turn_on_off_cloudreve
    elif [ "${pretend_list[$1]}" == "4" ]; then
        mkdir "${nginx_prefix}/html/${true_domain_list[$1]}"
        turn_on_off_php
        turn_on_off_cloudreve
    else
        turn_on_off_php
        turn_on_off_cloudreve
    fi
}

#安装/更新Cloudreve
update_cloudreve()
{
    green "Installing/updating Cloudreve。。。"
    local temp_cloudreve_status=0
    systemctl -q is-active cloudreve && temp_cloudreve_status=1
    systemctl stop cloudreve
    if ! wget -O "$cloudreve_prefix/cloudreve.tar.gz" "https://github.com/cloudreve/Cloudreve/releases/download/${cloudreve_version}/cloudreve_${cloudreve_version}_linux_${machine}.tar.gz"; then
        red "Failed to fetch Cloudreve！！"
        yellow "Press Enter to continue or Ctrl+c to terminate"
        read -s
    fi
    tar -zxf "$cloudreve_prefix/cloudreve.tar.gz" -C "$cloudreve_prefix" cloudreve
    rm -f "$cloudreve_prefix/cloudreve.tar.gz"
    chmod +x "$cloudreve_prefix/cloudreve"
cat > $cloudreve_prefix/conf.ini << EOF
[System]
Mode = master
Debug = false
[UnixSocket]
Listen = /dev/shm/cloudreve/cloudreve.sock
EOF
    rm -rf $cloudreve_service
cat > $cloudreve_service << EOF
[Unit]
Description=Cloudreve
Documentation=https://docs.cloudreve.org
After=network.target
After=mysqld.service
Wants=network.target

[Service]
WorkingDirectory=$cloudreve_prefix
ExecStartPre=/bin/rm -rf /dev/shm/cloudreve
ExecStartPre=/bin/mkdir /dev/shm/cloudreve
ExecStartPre=/bin/chmod 711 /dev/shm/cloudreve
ExecStart=$cloudreve_prefix/cloudreve
ExecStopPost=/bin/rm -rf /dev/shm/cloudreve
Restart=on-abnormal
RestartSec=5s
KillMode=mixed

StandardOutput=null
StandardError=syslog

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    [ $temp_cloudreve_status -eq 1 ] && systemctl start cloudreve
}
install_init_cloudreve()
{
    remove_cloudreve
    mkdir -p $cloudreve_prefix
    chmod 0700 $cloudreve_prefix
    update_cloudreve
    rm -rf /dev/shm/cloudreve
    local password
    password="$("$cloudreve_prefix/cloudreve" | grep "password" | awk '{print $6}')"
    sleep 1s
    systemctl start cloudreve
    systemctl enable cloudreve
    tyblue "-------- please open\"https://${domain_list[$1]}\"Perform Cloudreve initialization -------"
    tyblue "  1. login account"
    purple "    Initial administrator account：admin@cloudreve.org"
    purple "    initial admin password：$password"
    tyblue "  2. Avatar in the upper right corner -> Admin Panel"
    tyblue "  3. A dialog box will pop up \"Determine Site URL Settings\" choose \"Change\""
    tyblue "  4. Parameter settings on the left -> registration and login -> do not allow new user registration -> pull down and click save"
    sleep 15s
    echo -e "\\n\\n"
    tyblue "Press enter twice to continue。。。"
    read -s
    read -s
    cloudreve_is_installed=1
}

#初始化nextcloud 参数 1:域名在列表中的位置
let_init_nextcloud()
{
    echo -e "\\n\\n"
    yellow "please open as soon as possible\"https://${domain_list[$1]}\"Perform Nextcloud initialization settings："
    tyblue " 1. Initialize the administrator username and password"
    tyblue " 2. Select SQLite as the database type"
    tyblue " 3. Not recommended to check\"Install recommended apps\"，After the initialization is complete, it can also be installed"
    sleep 15s
    echo -e "\\n\\n"
    tyblue "Press enter twice to continue。。。"
    read -s
    read -s
    echo
}

print_share_link()
{
    if [ $protocol_1 -ne 0 ]; then
        local ip=""
        while [ -z "$ip" ]
        do
            read -p "Please enter your server IP (for generating sharing links)：" ip
        done
    fi
    if [[ "$ip" =~ : ]] && ! [[ "$ip" =~ ^\[.*:.*\]$ ]]; then
        ip="[$ip]"
    fi
    echo
    tyblue "share link："
    if [ $protocol_1 -eq 1 ] || [ $protocol_1 -eq 3 ]; then
        green  "============ VLESS-TCP-XTLS\\033[35m(don't go CDN)\\033[32m ============"
        for i in "${!domain_list[@]}"
        do
            if [ "${pretend_list[$i]}" == "1" ] || [ "${pretend_list[$i]}" == "2" ]; then
                tyblue "vless://${xid_1}@${ip}:443?security=tls&sni=${domain_list[$i]}&alpn=http%2F1.1&flow=xtls-rprx-vision"
            else
                tyblue "vless://${xid_1}@${ip}:443?security=tls&sni=${domain_list[$i]}&alpn=h2,http%2F1.1&flow=xtls-rprx-vision"
            fi
        done
    fi
    if [ $protocol_1 -eq 2 ] || [ $protocol_1 -eq 3 ]; then
        green  "============ VLESS-TCP-TLS\\033[35m(不走CDN)\\033[32m ============"
        for i in "${!domain_list[@]}"
        do
            if [ "${pretend_list[$i]}" == "1" ] || [ "${pretend_list[$i]}" == "2" ]; then
                tyblue "vless://${xid_1}@${ip}:443?security=tls&sni=${domain_list[$i]}&alpn=http%2F1.1"
            else
                tyblue "vless://${xid_1}@${ip}:443?security=tls&sni=${domain_list[$i]}&alpn=h2,http%2F1.1"
            fi
        done
    fi
    if [ $protocol_2 -eq 1 ]; then
        green  "=========== VLESS-gRPC-TLS \\033[35m(If CDN resolution is enabled for the domain name, it will connect to CDN, otherwise it will be directly connected)\\033[32m ==========="
        for i in "${domain_list[@]}"
        do
            tyblue "vless://${xid_2}@${i}:443?type=grpc&security=tls&serviceName=${serviceName}&mode=multi&alpn=h2,http%2F1.1"
        done
    elif [ $protocol_2 -eq 2 ]; then
        green  "=========== VMess-gRPC-TLS \\033[35m(If CDN resolution is enabled for the domain name, it will connect to CDN, otherwise it will be directly connected)\\033[32m ==========="
        for i in "${domain_list[@]}"
        do
            tyblue "vmess://${xid_2}@${i}:443?type=grpc&security=tls&serviceName=${serviceName}&mode=multi&alpn=h2,http%2F1.1"
        done
    fi
    if [ $protocol_3 -eq 1 ]; then
        green  "=========== VLESS-WebSocket-TLS \\033[35m(If CDN resolution is enabled for the domain name, it will connect to CDN, otherwise it will be directly connected)\\033[32m ==========="
        for i in "${domain_list[@]}"
        do
            tyblue "vless://${xid_3}@${i}:443?type=ws&security=tls&path=%2F${path#/}%3Fed=2048"
        done
    elif [ $protocol_3 -eq 2 ]; then
        green  "=========== VMess-WebSocket-TLS \\033[35m(If CDN resolution is enabled for the domain name, it will connect to CDN, otherwise it will be directly connected)\\033[32m ==========="
        for i in "${domain_list[@]}"
        do
            tyblue "vmess://${xid_3}@${i}:443?type=ws&security=tls&path=%2F${path#/}%3Fed=2048"
        done
    fi
}
print_config_info()
{
    echo -e "\\n\\n\\n"
    if [ $protocol_1 -ne 0 ]; then
        if [ $protocol_1 -eq 1 ]; then
            tyblue "--------------------- VLESS-TCP-XTLS (Do not use CDN) ---------------------"
        elif [ $protocol_1 -eq 2 ]; then
            tyblue "--------------------- VLESS-TCP-TLS (Do not use CDN) ---------------------"
        else
            tyblue "--------------------- VLESS-TCP-XTLS/TLS (Do not use CDN) ---------------------"
        fi
        tyblue " protocol(Transfer Protocol)    ：\\033[33mvless"
        purple "  (V2RayN selection\"Add [VLESS] server\";V2RayNG selection\"manual input[VLESS]\")"
        tyblue " address(address)         ：\\033[33m服务器ip"
        purple "  (Qv2ray: Host)"
        tyblue " port(port)            ：\\033[33m443"
        tyblue " id(User ID/UUID)       ：\\033[33m${xid_1}"
        if [ $protocol_1 -eq 1 ]; then
            tyblue " flow(Flow Control)            ：\\033[33mxtls-rprx-vision"
        elif [ $protocol_1 -eq 2 ]; then
            tyblue " flow(Flow Control)            ：\\033[33m空"
        else
            tyblue " flow(Flow Control)            ："
            tyblue "                         Use XTLS ：\\033[33mxtls-rprx-vision"
            tyblue "                         Use TLS  ：\\033[33m空"
        fi
        tyblue " encryption(encryption)      ：\\033[33mnone"
        tyblue " ---Transport/StreamSettings(Low-level transport/stream settings)---"
        tyblue "  network(transfer method)             ：\\033[33mtcp"
        purple "   (Shadowrocket transmission mode selection none)"
        tyblue "  type(camouflage type)                ：\\033[33mnone"
        purple "   (Qv2ray: protocol settings - type)"
        tyblue "  security(transport layer encryption)          ：\\033[33mtls"
        purple "   (V2RayN(G):Underlying transport security; Qv2ray: TLS settings - security type)"
        if [ ${#domain_list[@]} -eq 1 ]; then
            tyblue "  serverName                    ：\\033[33m${domain_list[*]}"
        else
            tyblue "  serverName                    ：\\033[33m${domain_list[*]} \\033[35m(任选其一)"
        fi
        purple "   (V2RayN(G):SNI;Qv2ray:TLS Settings - Server Address;Shadowrocket:Peer name)"
        tyblue "  allowInsecure                 ：\\033[33mfalse"
        purple "   (Qv2ray:TLS Settings - Allow insecure certificates (unchecked);Shadowrocket:Allow unsafe (off))"
        tyblue "  fingerprint                   ：\\033[33m空\\033[36m/\\033[33mchrome\\033[32m(recommend)\\033[36m/\\033[33mfirefox\\033[36m/\\033[33mios\\033[36m/\\033[33msafari\\033[36m/\\033[33mandroid\\033[36m/\\033[33medge\\033[36m/\\033[33m360\\033[36m/\\033[33mqq\\033[36m/\\033[33mrandom"
        purple "                                    (This option determines whether to forge the browser fingerprint: empty means no forgery, use the default fingerprint of the GO program；random means to randomly select a browser forged fingerprint)"
        tyblue "  alpn                          ："
        tyblue "                                  fake browser fingerprint  ：This parameter does not take effect，Can be set freely"
        tyblue "                                  Does not fake browser fingerprints：If the domain name filled in serverName corresponds to the fake website is a network disk，It is recommended to set\\033[33mhttp/1.1\\033[36m；Otherwise it is recommended to set\\033[33mh2,http/1.1 \\033[35m(When this option is empty/not configured，The default value is\"h2,http/1.1\")"
        purple "   (Qv2ray:TLS settings - ALPN) (Note that if Qv2ray wants to set alpn ash2,http/1.1，Please fill out\"h2|http/1.1\")"
        tyblue " ------------------------other-----------------------"
        tyblue "  Mux(multiplexing)                 ：It must be turned off when using XTLS; it is also recommended not to use XTLS"
        purple "   (V2RayN:Settings page - enable Mux multiplexing)"
        tyblue "------------------------------------------------------------------------"
    fi
    if [ $protocol_2 -ne 0 ]; then
        echo
        if [ $protocol_2 -eq 1 ]; then
            tyblue "---------------- VLESS-gRPC-TLS (If there is a CDN, go to the CDN, otherwise connect directly) ---------------"
            tyblue " protocol(Transfer Protocol)    ：\\033[33mvless"
            purple "  (V2RayN selection\"Add to[VLESS]server\";V2RayNG choose\"manual input[VLESS]\")"
        else
            tyblue "---------------- VMess-gRPC-TLS (If there is a CDN, go to the CDN, otherwise connect directly) ---------------"
            tyblue " protocol(Transfer Protocol)    ：\\033[33mvmess"
            purple "  (V2RayN selection\"Add to[VMess]server\";V2RayNG selection\"manual input[Vmess]\")"
        fi
        if [ ${#domain_list[@]} -eq 1 ]; then
            tyblue " address(address)         ：\\033[33m${domain_list[*]}"
        else
            tyblue " address(address)         ：\\033[33m${domain_list[*]} \\033[35m(任选其一)"
        fi
        purple "  (Qv2ray: Host)"
        tyblue " port(port)            ：\\033[33m443"
        tyblue " id(User ID/UUID)       ：\\033[33m${xid_2}"
        if [ $protocol_2 -eq 1 ]; then
            tyblue " flow(Flow Control)            ：\\033[33m空"
            tyblue " encryption(encryption)      ：\\033[33mnone"
        else
            tyblue " security(Encryption)    ：Using a CDN is recommended\\033[33mauto\\033[36m;Do not use CDN, recommended\\033[33mnone"
            purple "  (Qv2ray:Security Options; Shadowrocket: Algorithms)"
        fi
        tyblue " ---Transport/StreamSettings(Low-level transport/stream settings)---"
        tyblue "  network(transfer method)             ：\\033[33mgrpc"
        tyblue "  serviceName                   ：\\033[33m${serviceName}"
        tyblue "  multiMode                     ：\\033[33mtrue"
        purple "   (V2RayN(G)camouflage type(type)choose multi"
        tyblue "  security(transport layer encryption)          ：\\033[33mtls"
        purple "   (V2RayN(G):underlying transport security;Qv2ray:TLS Settings - Security Type)"
        tyblue "  serverName                    ：\\033[33m空"
        purple "   (V2RayN(G):SNI and cloaked domains;Qv2ray:TLS Settings - Server Address;Shadowrocket:Peer name)"
        tyblue "  allowInsecure                 ：\\033[33mfalse"
        purple "   (Qv2ray:TLS Settings - Allow insecure certificates (unchecked);Shadowrocket:Allow unsafe (off))"
        tyblue "  fingerprint                   ：\\033[33m空\\033[36m/\\033[33mchrome\\033[32m(recommend)\\033[36m/\\033[33mfirefox\\033[36m/\\033[33msafari"
        purple "                                           (This option determines whether to forge browser fingerprints, empty means no forgery)"
        tyblue "  alpn                          ：It is recommended to set\\033[33mh2,http/1.1 \\033[35m(When this option is empty/not configured, the default is\"h2,http/1.1\")"
        purple "   (Qv2ray:TLS settings - ALPN) (Pay attention to Qv2ray if you want to set alpn to h2,http/1.1，Please fill out\"h2|http/1.1\")"
        tyblue " ------------------------other-----------------------"
        tyblue "  Mux(multiplexing)                 ：Strongly recommend closing"
        purple "   (V2RayN: Settings page - enable Mux multiplexing)"
        tyblue "------------------------------------------------------------------------"
    fi
    if [ $protocol_3 -ne 0 ]; then
        echo
        if [ $protocol_3 -eq 1 ]; then
            tyblue "------------- VLESS-WebSocket-TLS (If there is a CDN, go to the CDN, otherwise connect directly) -------------"
            tyblue " protocol(Transfer Protocol)    ：\\033[33mvless"
            purple "  (V2RayN selection\"Add [VLESS] server\";V2RayNG selection\"manual input[VLESS]\")"
        else
            tyblue "------------- VMess-WebSocket-TLS (If there is a CDN, go to the CDN, otherwise connect directly) -------------"
            tyblue " protocol(Transfer Protocol)    ：\\033[33mvmess"
            purple "  (V2RayN selection\"Add [VMess] server\";V2RayNG selection\"manual input[Vmess]\")"
        fi
        if [ ${#domain_list[@]} -eq 1 ]; then
            tyblue " address(address)         ：\\033[33m${domain_list[*]}"
        else
            tyblue " address(address)         ：\\033[33m${domain_list[*]} \\033[35m(choose one)"
        fi
        purple "  (Qv2ray: Host)"
        tyblue " port(port)            ：\\033[33m443"
        tyblue " id(User ID/UUID)       ：\\033[33m${xid_3}"
        if [ $protocol_3 -eq 1 ]; then
            tyblue " flow(Flow Control)            ：\\033[33m空"
            tyblue " encryption(encryption)      ：\\033[33mnone"
        else
            tyblue " security(Encryption)    ：Using a CDN is recommended\\033[33mauto\\033[36m;Do not use CDN, recommended\\033[33mnone"
            purple "  (Qv2ray:Security Options; Shadowrocket: Algorithms)"
        fi
        tyblue " ---Transport/StreamSettings(Low-level transport/stream settings)---"
        tyblue "  network(transfer method)             ：\\033[33mws"
        purple "   (Shadowrocket transmission mode choose websocket)"
        tyblue "  path(path)                    ：\\033[33m${path}?ed=2048"
        tyblue "  Host                          ：\\033[33m空"
        purple "   (V2RayN(G):Masquerade domain name; Qv2ray: protocol setting - request header)"
        tyblue "  security(transport layer encryption)          ：\\033[33mtls"
        purple "   (V2RayN(G):underlying transport security;Qv2ray:TLS Settings - Security Type)"
        tyblue "  serverName                    ：\\033[33m空"
        purple "   (V2RayN(G):SNI and cloaked domains;Qv2ray:TLS Settings - Server Address;Shadowrocket:Peer name)"
        tyblue "  allowInsecure                 ：\\033[33mfalse"
        purple "   (Qv2ray:TLS Settings - Allow insecure certificates (unchecked);Shadowrocket:Allow unsafe (off))"
        tyblue "  fingerprint                   ：\\033[33m空\\033[32m(recommend)\\033[36m/\\033[33mchrome\\033[36m/\\033[33mfirefox\\033[36m/\\033[33msafari"
        purple "                                           (This option determines whether to forge browser fingerprints, empty means no forgery)"
        tyblue "  alpn                          ：This parameter does not take effect, you can set it freely \\033[35m(In Websocket mode alpn will be fixed as\"http/1.1\")"
        tyblue " ------------------------other-----------------------"
        tyblue "  Mux(multiplexing)                 ：recommended to close"
        purple "   (V2RayN:Settings page - enable Mux multiplexing)"
        tyblue "------------------------------------------------------------------------"
    fi
    echo
    yellow "Note: Some options may not be covered by the sharing link. If you are not afraid of trouble, it is recommended to fill in manually"
    ask_if "Whether to generate a share link？(y/n)" && print_share_link
    echo
    yellow " About fingerprint and alpn，See details：https://github.com/kirin10000/Xray-script#关于tls握手tls指纹和alpn"
    echo
    blue   " To achieve Fullcone (NAT type open), the following conditions are required："
    blue   "   If the client system is Windows，And you are using transparent proxy or TUN/Bypass LAN, please make sure the current network is set to private network"
    echo
    tyblue " script last update time：2023.1.1"
    echo
    red    " This script is only for communication and learning, please do not use this script to do illegal things。Where the Internet is illegal, if you do illegal things, you will be punished by law!!!!"
    tyblue " 2020.11"
}

install_update_xray_tls_web()
{
    in_install_update_xray_tls_web=1
    check_nginx_installed_system
    [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
    check_SELinux
    check_important_dependence_installed iproute2 iproute
    check_port
    check_important_dependence_installed tzdata tzdata
    get_system_info
    check_important_dependence_installed ca-certificates ca-certificates
    check_important_dependence_installed wget wget
    check_important_dependence_installed "procps" "procps-ng"
    install_epel
    ask_update_script
    check_ssh_timeout
    uninstall_firewall
    doupdate
    enter_temp_dir
    install_bbr
    $apt_no_install_recommends -y -f install

    #读取信息
    if [ $update -eq 0 ]; then
        readProtocolConfig
        readDomain
        path="/$(head -c 20 /dev/urandom | md5sum | head -c 10)"
        serviceName="$(head -c 20 /dev/urandom | md5sum | head -c 10)"
        xid_1="$(cat /proc/sys/kernel/random/uuid)"
        xid_2="$(cat /proc/sys/kernel/random/uuid)"
        xid_3="$(cat /proc/sys/kernel/random/uuid)"
    else
        get_config_info
    fi

    local choice

    local install_php
    if [ $update -eq 0 ]; then
        [ "${pretend_list[0]}" == "2" ] && install_php=1 || install_php=0
    else
        install_php=$php_is_installed
    fi
    local use_existed_php=0
    if [ $install_php -eq 1 ]; then
        if [ $update -eq 1 ]; then
            if check_php_update; then
                ! ask_if "It is detected that there is a new version of php, whether to update?(y/n)" && use_existed_php=1
            else
                green "PHP is already the latest version, not updated"
                use_existed_php=1
            fi
        elif [ $php_is_installed -eq 1 ]; then
            tyblue "---------------detected that php already exists---------------"
            tyblue " 1. use existing php"
            tyblue " 2. Uninstall the existing php and recompile the installation"
            echo
            choice=""
            while [ "$choice" != "1" ] && [ "$choice" != "2" ]
            do
                read -p "your choice is：" choice
            done
            [ $choice -eq 1 ] && use_existed_php=1
        fi
    fi

    local use_existed_nginx=0
    if [ $update -eq 1 ]; then
        if check_nginx_update; then
            ! ask_if "Detected that there is a new version of Nginx, whether to update?(y/n)" && use_existed_nginx=1
        else
            green "Nginx is already the latest version, not updated"
            use_existed_nginx=1
        fi
    elif [ $nginx_is_installed -eq 1 ]; then
        tyblue "---------------Detected that Nginx already exists---------------"
        tyblue " 1. Use existing Nginx"
        tyblue " 2. Uninstall the existing Nginx and recompile the installation"
        echo
        choice=""
        while [ "$choice" != "1" ] && [ "$choice" != "2" ]
        do
            read -p "your choice is：" choice
        done
        [ $choice -eq 1 ] && use_existed_nginx=1
    fi
    #此参数只在[ $update -eq 0 ]时有效
    local temp_remove_cloudreve=1
    if [ $update -eq 0 ] && [ "${pretend_list[0]}" == "1" ] && [ $cloudreve_is_installed -eq 1 ]; then
        tyblue "----------------- Cloudreve already exists -----------------"
        tyblue " 1. Use existing Cloudreve"
        tyblue " 2. uninstall and reinstall"
        echo
        red    "Warning: Uninstalling Cloudreve will delete all files and user information in the network disk"
        choice=""
        while [ "$choice" != "1" ] && [ "$choice" != "2" ]
        do
            read -p "your choice is：" choice
        done
        [ $choice -eq 1 ] && temp_remove_cloudreve=0
    fi

    if [ $update -eq 0 ]; then
        green "The installation of Xray-TLS+Web is about to start, it may take 10-20 minutes。。。"
        sleep 3s
    fi

    [ $use_existed_nginx -eq 0 ] && install_nginx_compile_toolchains
    install_nginx_dependence
    if [ $install_php -eq 1 ]; then
        [ $use_existed_php -eq 0 ] && install_php_compile_toolchains
        install_php_dependence
    fi
    install_acme_dependence
    if [ $update -eq 0 ]; then
        install_web_dependence ""
    else
        [ $cloudreve_is_installed -eq 1 ] && install_web_dependence "1"
    fi
    $apt clean
    $dnf clean all

    #编译&&安装php
    if [ $install_php -eq 1 ]; then
        if [ $use_existed_php -eq 0 ]; then
            compile_php
            remove_php
            install_php_part1
        else
            systemctl stop php-fpm
            systemctl disable php-fpm
        fi
        install_php_part2
        [ $update -eq 1 ] && turn_on_off_php
    fi

    #编译&&安装Nginx
    if [ $use_existed_nginx -eq 0 ]; then
        compile_nginx
        [ $update -eq 1 ] && backup_domains_web
        remove_nginx
        install_nginx_part1
    else
        systemctl stop nginx
        systemctl disable nginx
        rm -rf ${nginx_prefix}/conf.d
        rm -rf ${nginx_prefix}/certs
        rm -rf ${nginx_prefix}/html/issue_certs
        rm -rf ${nginx_prefix}/conf/issue_certs.conf
        cp ${nginx_prefix}/conf/nginx.conf.default ${nginx_prefix}/conf/nginx.conf
    fi
    install_nginx_part2
    [ $update -eq 1 ] && [ $use_existed_nginx -eq 0 ] && mv "${temp_dir}/domain_backup/"* ${nginx_prefix}/html 2>/dev/null

    #安装Xray
    remove_xray
    install_update_xray

    if [ $update -eq 0 ]; then
        [ -e $HOME/.acme.sh/acme.sh ] && $HOME/.acme.sh/acme.sh --uninstall
        rm -rf $HOME/.acme.sh
        curl https://get.acme.sh | sh
        $HOME/.acme.sh/acme.sh --register-account -ak ec-256 --server zerossl -m "my@example.com"
    fi
    $HOME/.acme.sh/acme.sh --upgrade --auto-upgrade
    get_all_certs

    #配置Nginx和Xray
    config_nginx
    config_xray
    sleep 2s
    systemctl stop cloudreve
    systemctl restart xray nginx
    if [ $update -eq 0 ]; then
        [ "${pretend_list[0]}" == "1" ] && [ $temp_remove_cloudreve -eq 1 ] && remove_cloudreve
        init_web 0
        green "-------------------The installation is complete-------------------"
        print_config_info
    else
        [ $cloudreve_is_installed -eq 1 ] && update_cloudreve
        turn_on_off_cloudreve
        green "-------------------update completed-------------------"
    fi
    cd /
    rm -rf "$temp_dir"
    in_install_update_xray_tls_web=0
}

#主菜单函数
full_install_php()
{
    green "Start installing/updating php。。。"
    sleep 3s
    install_php_compile_toolchains
    install_php_dependence
    enter_temp_dir
    compile_php
    remove_php
    install_php_part1
    install_php_part2
    cd /
    rm -rf "$temp_dir"
}
#安装/检查更新/更新php
install_check_update_update_php()
{
    [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
    check_SELinux
    check_important_dependence_installed tzdata tzdata
    get_system_info
    if (([ $release == "centos" ] || [ $release == centos-stream ] || [ $release == oracle ]) && ! version_ge "$systemVersion" "8" ) || ([ $release == "rhel" ] && ! version_ge "$systemVersion" "8") || ([ $release == "fedora" ] && ! version_ge "$systemVersion" "30") || ([ $release == "ubuntu" ] && ! version_ge "$systemVersion" "20.04") || ([ $release == "debian" ] && ! version_ge "$systemVersion" "11"); then
        red "The system version is too low to install php！"
        echo
        tyblue "Installing Nextcloud requires installing php"
        yellow "仅支持在以下版本系统下安装php："
        yellow " 1. Ubuntu 20.04+"
        yellow " 2. Debian 11+"
        yellow " 3. 其他以 Debian 11+ 为基的系统"
        yellow " 4. Red Hat Enterprise Linux 8+"
        yellow " 5. CentOS 8+"
        yellow " 6. Fedora 30+"
        yellow " 7. Oracle Linux 8+"
        yellow " 8. 其他以 Red Hat 8+ 为基的系统"
        return 1
    elif [ $release == "other-debian" ] || [ $release == "other-redhat" ]; then
        yellow "Unknown system may cause php installation to fail！"
        echo
        tyblue "安装Nextcloud需要安装php"
        yellow "仅支持在以下版本系统下安装php："
        yellow " 1. Ubuntu 20.04+"
        yellow " 2. Debian 11+"
        yellow " 3. 其他以 Debian 11+ 为基的系统"
        yellow " 4. Red Hat Enterprise Linux 8+"
        yellow " 5. CentOS 8+"
        yellow " 6. Fedora 30+"
        yellow " 7. Oracle Linux 8+"
        yellow " 8. 其他以 Red Hat 8+ 为基的系统"
        ! ask_if "确定选择吗？(y/n)" && return 0
    elif [ $release == "deepin" ]; then
        red "php暂不支持deepin，请选择其他系统"
        return 1
    fi
    check_important_dependence_installed ca-certificates ca-certificates
    check_important_dependence_installed wget wget
    check_important_dependence_installed "procps" "procps-ng"
    install_epel
    local php_status=0
    if [ $php_is_installed -eq 1 ]; then
        ask_update_script_force
        if check_php_update; then
            green "php有新版本"
            ! ask_if "Whether to update？(y/n)" && return 0
        else
            green "php已是最新版本"
            return 0
        fi
        systemctl -q is-active php-fpm && php_status=1
    else
        ask_update_script
        tyblue "Install php to run nextcloud network disk"
        yellow "Compiling && installing php may take 15-60 minutes"
        yellow "And php will occupy a certain amount of system resources, so it is not recommended for machines with memory <512M"
        ! ask_if "Whether to continue？(y/n)" && return 0
    fi
    check_ssh_timeout
    get_config_info
    full_install_php
    turn_on_off_php
    if [ $php_status -eq 1 ]; then
        systemctl start php-fpm
    else
        systemctl stop php-fpm
    fi
    green "Install/update complete！"
}
check_update_update_nginx()
{
    check_nginx_installed_system
    [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
    check_SELinux
    check_important_dependence_installed tzdata tzdata
    get_system_info
    check_important_dependence_installed ca-certificates ca-certificates
    check_important_dependence_installed wget wget
    check_important_dependence_installed "procps" "procps-ng"
    install_epel
    ask_update_script_force
    if check_nginx_update; then
        green "Nginx has a new version"
        ! ask_if "Whether to update？(y/n)" && return 0
    else
        green "Nginx is the latest version"
        return 0
    fi
    check_ssh_timeout
    get_config_info
    local nginx_status=0
    local xray_status=0
    systemctl -q is-active nginx && nginx_status=1
    systemctl -q is-active xray && xray_status=1
    install_nginx_compile_toolchains
    install_nginx_dependence
    enter_temp_dir
    compile_nginx
    backup_domains_web
    remove_nginx
    install_nginx_part1
    install_nginx_part2
    config_nginx
    mv "${temp_dir}/domain_backup/"* ${nginx_prefix}/html 2>/dev/null
    get_all_certs
    if [ $nginx_status -eq 1 ]; then
        systemctl restart nginx
    else
        systemctl stop nginx
    fi
    if [ $xray_status -eq 1 ]; then
        systemctl restart xray
    else
        systemctl stop xray
    fi
    cd /
    rm -rf "$temp_dir"
    green "update completed！"
}
restart_xray_tls_web()
{
    get_config_info
    systemctl restart xray nginx
    systemctl stop php-fpm cloudreve
    turn_on_off_php
    turn_on_off_cloudreve
    sleep 1s
    if ! systemctl -q is-active xray; then
        red "Xray failed to start！！"
    elif ! systemctl -q is-active nginx; then
        red "Nginx failed to start！！"
    elif check_need_php && ! systemctl -q is-active php-fpm; then
        red "php failed to start！！"
    elif check_need_cloudreve && ! systemctl -q is-active cloudreve; then
        red "Cloudreve failed to start！！"
    else
        green "Reboot/boot successfully！！"
    fi
}
reinit_domain()
{
    [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
    check_important_dependence_installed iproute2 iproute
    check_port
    check_important_dependence_installed tzdata tzdata
    get_system_info
    check_important_dependence_installed ca-certificates ca-certificates
    check_important_dependence_installed wget wget
    install_acme_dependence
    ask_update_script
    yellow "Resetting the domain name will delete all existing domain names (including domain certificates, fake websites, etc.)"
    ! ask_if "Whether to continue？(y/n)" && return 0
    get_config_info
    readDomain
    if [ "${pretend_list[-1]}" == "2" ] && [ $php_is_installed -eq 0 ]; then
        check_SELinux
        check_important_dependence_installed "procps" "procps-ng"
        install_epel
        install_web_dependence "${pretend_list[-1]}"
        in_install_update_xray_tls_web=1
        check_ssh_timeout
        in_install_update_xray_tls_web=0
        full_install_php
    else
        [ "${pretend_list[-1]}" == "1" ] && check_SELinux
        install_web_dependence "${pretend_list[-1]}"
    fi
    green "reset domain name。。。"
    local temp_domain="${domain_list[-1]}"
    local temp_true_domain="${true_domain_list[-1]}"
    local temp_domain_config="${domain_config_list[-1]}"
    local temp_pretend="${pretend_list[-1]}"
    systemctl stop xray
    systemctl stop nginx
    systemctl stop php-fpm
    systemctl disable php-fpm
    systemctl stop cloudreve
    systemctl disable cloudreve
    local i
    for i in "${true_domain_list[@]}"
    do
        rm -rf "${nginx_prefix}/html/${i}"
    done
    rm -rf "${nginx_prefix}/certs"
    mkdir "${nginx_prefix}/certs"
    $HOME/.acme.sh/acme.sh --uninstall
    rm -rf $HOME/.acme.sh
    curl https://get.acme.sh | sh
    $HOME/.acme.sh/acme.sh --register-account -ak ec-256 --server zerossl -m "my@example.com"
    $HOME/.acme.sh/acme.sh --upgrade --auto-upgrade
    unset domain_list
    unset true_domain_list
    unset domain_config_list
    unset pretend_list
    domain_list+=("$temp_domain")
    domain_config_list+=("$temp_domain_config")
    true_domain_list+=("$temp_true_domain")
    pretend_list+=("$temp_pretend")
    get_all_certs
    config_nginx
    config_xray
    sleep 2s
    systemctl restart xray nginx
    init_web 0
    green "Domain name reset complete！！"
    print_config_info
}
add_domain()
{
    [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
    check_important_dependence_installed iproute2 iproute
    check_port
    check_important_dependence_installed tzdata tzdata
    get_system_info
    check_important_dependence_installed ca-certificates ca-certificates
    check_important_dependence_installed wget wget
    ask_update_script
    get_config_info
    local need_cloudreve=0
    check_need_cloudreve && need_cloudreve=1
    readDomain
    local i
    for ((i=${#domain_list[@]}-1; i!=0;))
    do
        ((i--))
        if [ "${domain_list[-1]}" == "${domain_list[$i]}" ] || [ "${domain_list[-1]}" == "${true_domain_list[$i]}" ] || [ "${true_domain_list[-1]}" == "${domain_list[$i]}" ] || [ "${true_domain_list[-1]}" == "${true_domain_list[$i]}" ]; then
            red "Domain already exists！"
            return 1
        fi
    done
    if [ "${pretend_list[-1]}" == "1" ] && [ $need_cloudreve -eq 1 ]; then
        yellow "Cloudreve can only be used for one domain name！！"
        tyblue "Nextcloud can be used for multiple domain names"
        return 1
    fi
    if [ "${pretend_list[-1]}" == "2" ] && [ $php_is_installed -eq 0 ]; then
        check_SELinux
        check_important_dependence_installed "procps" "procps-ng"
        install_epel
        install_web_dependence "${pretend_list[-1]}"
        in_install_update_xray_tls_web=1
        check_ssh_timeout
        in_install_update_xray_tls_web=0
        full_install_php
    else
        [ "${pretend_list[-1]}" == "1" ] && check_SELinux
        install_web_dependence "${pretend_list[-1]}"
    fi
    if ! get_cert "-1"; then
        sleep 2s
        systemctl restart xray nginx
        red "Failed to apply for a certificate！！"
        red "Failed to add domain name"
        return 1
    fi
    config_nginx
    config_xray
    sleep 2s
    systemctl stop php-fpm cloudreve
    systemctl restart xray nginx
    init_web "-1"
    green "Domain name added！！"
    print_config_info
}
delete_domain()
{
    get_config_info
    if [ ${#domain_list[@]} -le 1 ]; then
        red "only one domain name"
        return 1
    fi
    local i
    tyblue "-----------------------Please select the domain name to delete-----------------------"
    for i in "${!domain_list[@]}"
    do
        if [ ${domain_config_list[$i]} -eq 1 ]; then
            tyblue " $((i+1)). ${domain_list[$i]} ${true_domain_list[$i]}"
        else
            tyblue " $((i+1)). ${domain_list[$i]}"
        fi
    done
    yellow " 0. not delete"
    local delete=""
    while ! [[ "$delete" =~ ^([1-9][0-9]*|0)$ ]] || [ $delete -gt ${#domain_list[@]} ]
    do
        read -p "your choice is：" delete
    done
    [ $delete -eq 0 ] && return 0
    ((delete--))
    if [ "${pretend_list[$delete]}" == "2" ]; then
        red "Warning: This operation may cause the Nextcloud network disk data under this domain name to be deleted"
        ! ask_if "do you want to continue？(y/n)" && return 0
    fi
    $HOME/.acme.sh/acme.sh --remove --domain ${true_domain_list[$delete]} --ecc
    rm -rf $HOME/.acme.sh/${true_domain_list[$delete]}_ecc
    rm -rf "${nginx_prefix}/certs/${true_domain_list[$delete]}.key" "${nginx_prefix}/certs/${true_domain_list[$delete]}.cer"
    rm -rf ${nginx_prefix}/html/${true_domain_list[$delete]}
    unset 'domain_list[$delete]'
    unset 'true_domain_list[$delete]'
    unset 'domain_config_list[$delete]'
    unset 'pretend_list[$delete]'
    domain_list=("${domain_list[@]}")
    true_domain_list=("${true_domain_list[@]}")
    domain_config_list=("${domain_config_list[@]}")
    pretend_list=("${pretend_list[@]}")
    config_nginx
    config_xray
    systemctl restart xray nginx
    turn_on_off_php
    turn_on_off_cloudreve
    green "Domain name deletion complete！！"
    print_config_info
}
change_pretend()
{
    [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
    check_important_dependence_installed tzdata tzdata
    get_system_info
    check_important_dependence_installed ca-certificates ca-certificates
    check_important_dependence_installed wget wget
    ask_update_script
    get_config_info
    local change=""
    if [ ${#domain_list[@]} -eq 1 ]; then
        change=0
    else
        local i
        tyblue "-----------------------Please select the domain name to modify the masquerade type-----------------------"
        for i in "${!domain_list[@]}"
        do
            if [ ${domain_config_list[$i]} -eq 1 ]; then
                tyblue " $((i+1)). ${domain_list[$i]} ${true_domain_list[$i]}"
            else
                tyblue " $((i+1)). ${domain_list[$i]}"
            fi
        done
        yellow " 0. do not modify"
        while ! [[ "$change" =~ ^([1-9][0-9]*|0)$ ]] || [ $change -gt ${#domain_list[@]} ]
        do
            read -p "your choice is：" change
        done
        [ $change -eq 0 ] && return 0
        ((change--))
    fi
    local pretend
    readPretend "${true_domain_list[$change]}"
    if [ "${pretend_list[$change]}" == "$pretend" ]; then
        yellow "Camouflage type does not change"
        return 1
    fi
    if [ "${pretend_list[$change]}" == "2" ]; then
        red "Warning: This operation may cause the Nextcloud network disk data under this domain name to be deleted"
        ! ask_if "do you want to continue？(y/n)" && return 0
    fi
    local need_cloudreve=0
    check_need_cloudreve && need_cloudreve=1
    pretend_list[$change]="$pretend"
    if [ "$pretend" == "1" ] && [ $need_cloudreve -eq 1 ]; then
        yellow "Cloudreve can only be used for one domain name！！"
        tyblue "Nextcloud can be used for multiple domain names"
        return 1
    fi
    if [ "$pretend" == "2" ] && [ $php_is_installed -eq 0 ]; then
        check_SELinux
        check_important_dependence_installed "procps" "procps-ng"
        install_epel
        install_web_dependence "$pretend"
        in_install_update_xray_tls_web=1
        check_ssh_timeout
        in_install_update_xray_tls_web=0
        full_install_php
    else
        [ "$pretend" == "1" ] && check_SELinux
        install_web_dependence "$pretend"
    fi
    config_nginx
    systemctl stop php-fpm cloudreve
    systemctl restart nginx
    init_web "$change"
    green "修改完成！"
}
reinstall_cloudreve()
{
    get_config_info
    ! check_need_cloudreve && red "Cloudreve目前没有绑定域名" && return 1
    red "Reinstalling Cloudreve will delete all network disk files and account information, and reset the administrator password"
    ! ask_if "Are you sure you want to continue?？(y/n)" && return 0
    [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
    check_SELinux
    check_important_dependence_installed ca-certificates ca-certificates
    check_important_dependence_installed wget wget
    ask_update_script
    install_web_dependence "1"
    enter_temp_dir
    local i
    for i in "${!pretend_list[@]}"
    do
        if [ "${pretend_list[$i]}" == "1" ]; then
            install_init_cloudreve "$i"
            break
        fi
    done
    cd /
    rm -rf "$temp_dir"
    green "reload complete！"
}
change_xray_protocol()
{
    get_config_info
    local protocol_1_old=$protocol_1
    local protocol_2_old=$protocol_2
    local protocol_3_old=$protocol_3
    readProtocolConfig
    if [ $protocol_1_old -eq $protocol_1 ] && [ $protocol_2_old -eq $protocol_2 ] && [ $protocol_3_old -eq $protocol_3 ]; then
        red "Transport protocol not changed"
        return 1
    fi
    [ $protocol_1_old -eq 0 ] && [ $protocol_1 -ne 0 ] && xid_1=$(cat /proc/sys/kernel/random/uuid)
    if [ $protocol_2_old -eq 0 ] && [ $protocol_2 -ne 0 ]; then
        serviceName="$(head -c 20 /dev/urandom | md5sum | head -c 10)"
        xid_2=$(cat /proc/sys/kernel/random/uuid)
    fi
    if [ $protocol_3_old -eq 0 ] && [ $protocol_3 -ne 0 ]; then
        path="/$(head -c 20 /dev/urandom | md5sum | head -c 10)"
        xid_3=$(cat /proc/sys/kernel/random/uuid)
    fi
    config_xray
    config_nginx
    systemctl -q is-active xray && systemctl restart xray
    systemctl -q is-active nginx && systemctl restart nginx
    green "Replaced successfully！！"
    print_config_info
}
change_xray_id()
{
    get_config_info
    local flag=""
    tyblue "-------------Please enter the id you want to modify-------------"
    tyblue " 1. TCP的id"
    tyblue " 2. gRPC的id"
    tyblue " 3. WebSocket的id"
    echo
    while [[ ! "$flag" =~ ^([1-9][0-9]*)$ ]] || ((flag>3))
    do
        read -p "您的选择是：" flag
    done
    local temp_protocol="protocol_$flag"
    if [ ${!temp_protocol} -eq 0 ]; then
        red "not using the protocol！"
        return 1
    fi
    local xid="xid_$flag"
    tyblue "Your current id is：${!xid}"
    ! ask_if "do you want to continue?(y/n)" && return 0
    while true
    do
        xid=""
        while [ -z "$xid" ]
        do
            tyblue "-------------Please enter a new id-------------"
            read xid
        done
        tyblue "The id you entered is：$xid"
        ask_if "Are you sure?(y/n)" && break
    done
    if [ $flag -eq 1 ]; then
        xid_1="$xid"
    elif [ $flag -eq 2 ]; then
        xid_2="$xid"
    else
        xid_3="$xid"
    fi
    config_xray
    systemctl -q is-active xray && systemctl restart xray
    green "Replaced successfully！！"
    print_config_info
}
change_xray_serviceName()
{
    get_config_info
    if [ $protocol_2 -eq 0 ]; then
        red "Not using the gRPC protocol！"
        return 1
    fi
    tyblue "Your current serviceName is：$serviceName"
    ! ask_if "do you want to continue?(y/n)" && return 0
    while true
    do
        serviceName=""
        while [ -z "$serviceName" ]
        do
            tyblue "---------------Please enter a new serviceName (alphanumeric combination)---------------"
            read serviceName
        done
        tyblue "The serviceName you entered is：$serviceName"
        ask_if "Are you sure?(y/n)" && break
    done
    config_xray
    config_nginx
    systemctl -q is-active xray && systemctl restart xray
    systemctl -q is-active nginx && systemctl restart nginx
    green "Replaced successfully！！"
    print_config_info
}
change_xray_path()
{
    get_config_info
    if [ $protocol_3 -eq 0 ]; then
        red "Not using the WebSocket protocol！"
        return 1
    fi
    tyblue "Your current path is：$path"
    ! ask_if "do you want to continue?(y/n)" && return 0
    while true
    do
        path=""
        while [ -z "$path" ]
        do
            tyblue "---------------Please enter a new path (/+ alphanumeric combination)---------------"
            read path
        done
        tyblue "The path you entered is：$path"
        ask_if "Are you sure?(y/n)" && break
    done
    config_xray
    systemctl -q is-active xray && systemctl restart xray
    green "Replaced successfully！！"
    print_config_info
}
simplify_system()
{
    if systemctl -q is-active xray || systemctl -q is-active nginx || systemctl -q is-active php-fpm; then
        yellow "Please stop Xray-TLS+Web first"
        return 1
    fi
    [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
    check_important_dependence_installed tzdata tzdata
    get_system_info
    check_important_dependence_installed "procps" "procps-ng"
    yellow "warn："
    tyblue " 1. This function cannot be guaranteed to run successfully on all systems (especially some VPS customized systems), if it fails to run, it may cause the VPS to fail to boot"
    tyblue " 2. If something other than Xray-TLS+Web is deployed on the VPS, it may be deleted by mistake"
    ! ask_if "do you want to continue?(y/n)" && return 0
    echo
    local save_ssh=0
    yellow "Tip: Streamlining the system may cause the ssh configuration file (/etc/ssh/sshd_config) to restore the default"
    tyblue "This may cause the ssh port to return to the default (22), and some systems only allow key logins by default (no password logins are allowed)"
    tyblue "You can back up the ssh files yourself or use a script to do it automatically"
    ask_if "Whether to back up the ssh configuration file?(y/n)" && save_ssh=1
    if [ $save_ssh -eq 1 ]; then
        enter_temp_dir
        cp /etc/ssh/sshd_config sshd_config
    fi
    uninstall_firewall
    if [ $release == "centos" ] || [ $release == centos-stream ] || [ $release == oracle ] || [ $release == "rhel" ] || [ $release == "fedora" ] || [ $release == "other-redhat" ]; then
        local temp_backup=()
        local temp_important=('openssh-server' 'initscripts' 'tar')
        for i in "${temp_important[@]}"
        do
            rpm -q "$i" > /dev/null 2>&1 && temp_backup+=("$i")
        done
        local temp_remove_list=('openssl' 'perl*' 'xz' 'libselinux-utils' 'zip' 'unzip' 'bzip2' 'wget' 'procps-ng' 'procps' 'iproute' 'dbus-glib' 'udisk*' 'libudisk*' 'gdisk*' 'libblock*' '*-devel' 'nginx*')
        #libxmlb
        if ! $dnf -y remove "${temp_remove_list[@]}"; then
            for i in "${temp_remove_list[@]}"
            do
                $dnf -y remove "$i"
            done
        fi
        for i in "${temp_backup[@]}"
        do
            check_important_dependence_installed "" "$i"
        done
    else
        local debian_remove_packages=('^cron$' '^anacron$' '^cups' '^foomatic' '^openssl$' '^snapd$' '^kdump-tools$' '^flex$' '^make$' '^automake$' '^cloud-init' '^pkg-config$' '^gcc-[1-9][0-9]*$' '^cpp-[1-9][0-9]*$' '^curl$' '^python' '^libpython' '^dbus$' '^at$' '^open-iscsi$' '^rsyslog$' '^acpid$' '^libnetplan0$' '^glib-networking-common$' '^bcache-tools$' '^bind([0-9]|-|$)' '^lshw$' '^thermald' '^libdbus' '^libevdev' '^libupower' '^readline-common$' '^libreadline' '^xz-utils$' '^selinux-utils$' '^wget$' '^zip$' '^unzip$' '^bzip2$' '^finalrd$' '^cryptsetup' '^libplymouth' '^lib.*-dev$' '^perl$' '^perl-modules' '^x11' '^libx11' '^qemu' '^xdg-' '^libglib' '^libicu' '^libxml' '^liburing' '^libisc' '^libdns' '^isc-' '^net-tools$' '^xxd$' '^xkb-data$' '^lsof$' '^task' '^usb' '^libusb' '^doc' '^libwrap' '^libtext' '^libmagic' '^libpci' '^liblocale' '^keyboard' '^libuni[^s]' '^libpipe' '^man-db$' '^manpages' '^liblock' '^liblog' '^libxapian' '^libpsl' '^libpap' '^libgs[0-9]' '^libpaper' '^postfix' '^nginx' '^libnginx' '^libpop' '^libslang' '^apt-utils$' '^google')
        local debian_keep_packages=('apt-utils' 'whiptail' 'initramfs-tools' 'isc-dhcp-client' 'netplan.io' 'openssh-server' 'network-manager' 'ifupdown' 'ifupdown-ng' 'ca-certificates')
        local remove_packages=()
        local keep_packages=()
        for i in "${debian_keep_packages[@]}"
        do
            LANG="en_US.UTF-8" LANGUAGE="en_US:en" dpkg -s "$i" 2>/dev/null | grep -qi 'status[ '$'\t]*:[ '$'\t]*install[ '$'\t]*ok[ '$'\t]*installed[ '$'\t]*$' && keep_packages+=("$i")
        done
        keep_packages+=($(dpkg --list 'grub*' | grep '^[ '$'\t]*ii[ '$'\t]' | awk '{print $2}'))
        dpkg -l | grep '^[ '$'\t]*ii[ '$'\t]' | awk '{print $2}' | cut -d : -f 1 > temp
        for package in "${debian_remove_packages[@]}"
        do
            if grep -q "$package" temp; then
                tyblue "will remove the package：$package"
                remove_packages+=("$package")
            fi
        done
        cp /etc/apt/sources.list sources.list.bak
        sed -i 's#https://#http://#g' /etc/apt/sources.list
        #'^libp11' '^libtasn' '^libkey' '^libnet'
        if ! apt_auto_remove_purge "${remove_packages[@]}"; then
            $apt update
            $apt -y -f --no-install-recommends install
            if ! apt_auto_remove_purge "${remove_packages[@]}"; then
                red    "An error occurred while downsizing the system (uninstallation of some packages failed）"
                echo
                tyblue "If you are a novice, it is recommended to choose n to terminate the uninstallation. If there are still errors in the future, please reinstall the system"
                echo
                tyblue "Otherwise, you can try to fix it by following the steps below："
                tyblue " 1. Read the error message to find the package that caused the uninstall error; running this command manually may help to find the wrong package： $apt -f --no-install-recommends install (在终端中运行，参考2)"
                tyblue " 2. Press ctrl+z to hang the script in the background, or try to create a new terminal (it may not be successful)"
                tyblue " 3. It's best if you can see what's causing the uninstall error and fix it; if you can't, run '$apt update && $apt --no-install-recommends install 软件包名' 手动升级该软件包"
                tyblue " 4. Run the fg command to return to the script (corresponding to the ctrl+z command)"
                tyblue " 5. After completing the above steps, select y to continue uninstalling"
                echo
                if ask_if "continue to uninstall?(y/n)"; then
                    if ! apt_auto_remove_purge "${remove_packages[@]}"; then
                        red "uninstall failed！"
                        tyblue "Press the Enter key to continue, if there are still errors, please reinstall the system"
                        read -s
                    fi
                fi
            fi
        fi
        for i in "${keep_packages[@]}"
        do
            check_important_dependence_installed "$i" ""
        done
        mv sources.list.bak /etc/apt/sources.list
    fi
    ([ $nginx_is_installed -eq 1 ] || [ $php_is_installed -eq 1 ] || [ $is_installed -eq 1 ]) && install_epel
    [ $nginx_is_installed -eq 1 ] && install_nginx_dependence
    [ $php_is_installed -eq 1 ] && install_php_dependence
    [ $is_installed -eq 1 ] && install_acme_dependence
    if [ $save_ssh -eq 1 ]; then
        cp sshd_config /etc/ssh/sshd_config
        cd /
        rm -rf "$temp_dir"
        systemctl restart $ssh_service
    fi
    green "Streamlined"
}
repair_tuige()
{
    yellow "Try to fix the abnormal problem of the backspace key, please do not fix the backspace key if it is normal"
    ! ask_if "do you want to continue?(y/n)" && return 0
    if stty -a | grep -q 'erase = ^?'; then
        stty erase '^H'
    elif stty -a | grep -q 'erase = ^H'; then
        stty erase '^?'
    fi
    green "repair completed！！"
}
change_dns()
{
    red    "Notice！！"
    red    "1.Some cloud service providers (such as Alibaba Cloud) use the local server as the package source, and need to change the source after modifying dns！！"
    red    "  If you don't understand, please modify the dns after the installation is complete, and do not reinstall after the modification"
    red    "2.The original dns may be restored after the Ubuntu system restarts"
    tyblue "This operation will modify the dns server to 1.1.1.1 and 1.0.0.1 (cloudflare public dns)"
    ! ask_if "do you want to continue?(y/n)" && return 0
    if ! grep -q "#This file has been edited by Xray-TLS-Web-setup-script" /etc/resolv.conf; then
        sed -i 's/^[ \t]*nameserver[ \t][ \t]*/#&/' /etc/resolv.conf
        {
            echo
            echo 'nameserver 1.1.1.1'
            echo 'nameserver 1.0.0.1'
            echo '#This file has been edited by Xray-TLS-Web-setup-script'
        } >> /etc/resolv.conf
    fi
    green "modification completed！！"
}
#开始菜单
start_menu()
{
    local xray_status
    [ $xray_is_installed -eq 1 ] && xray_status="\\033[32m已安装" || xray_status="\\033[31m未安装"
    systemctl -q is-active xray && xray_status+="                \\033[32m运行中" || xray_status+="                \\033[31m未运行"
    local nginx_status
    [ $nginx_is_installed -eq 1 ] && nginx_status="\\033[32m已安装" || nginx_status="\\033[31m未安装"
    systemctl -q is-active nginx && nginx_status+="                \\033[32m运行中" || nginx_status+="                \\033[31m未运行"
    local php_status
    [ $php_is_installed -eq 1 ] && php_status="\\033[32m已安装" || php_status="\\033[31m未安装"
    systemctl -q is-active php-fpm && php_status+="                \\033[32m运行中" || php_status+="                \\033[31m未运行"
    local cloudreve_status
    [ $cloudreve_is_installed -eq 1 ] && cloudreve_status="\\033[32m已安装" || cloudreve_status="\\033[31m未安装"
    systemctl -q is-active cloudreve && cloudreve_status+="                \\033[32m运行中" || cloudreve_status+="                \\033[31m未运行"
    tyblue "------------------------ Xray-TLS+Web build/admin script ------------------------"
    echo
    tyblue "           Xray   ：           ${xray_status}"
    echo
    tyblue "           Nginx  ：           ${nginx_status}"
    echo
    tyblue "           php    ：           ${php_status}"
    echo
    tyblue "        Cloudreve ：           ${cloudreve_status}"
    echo
    tyblue "       official website：https://github.com/kirin10000/Xray-script"
    echo
    tyblue "----------------------------------Precautions----------------------------------"
    yellow " 1. This script requires a domain name that resolves to this server"
    tyblue " 2. This script takes a long time to install, it is recommended to read it before installation："
    tyblue "      https://github.com/kirin10000/Xray-script#安装时长说明"
    green  " 3. It is recommended to use this script on a clean system (VPS console - reset system)"
    tyblue "----------------------------------------------------------------------------"
    echo
    echo
    tyblue " -----------Install/Update/Uninstall-----------"
    if [ $is_installed -eq 0 ]; then
        green  "   1. Install Xray-TLS+Web"
    else
        green  "   1. Reinstall Xray-TLS+Web"
    fi
    purple "         Process: [Update system components]->[Install bbr]->[Install php]->Install Nginx->Install Xray->Apply for a certificate->Configuration file->[Install/Configure Cloudreve]"
    green  "   2. Update Xray-TLS+Web"
    purple "         Process: update script -> [update system components] -> [update bbr] -> [update php] -> [update Nginx] -> update Xray -> update certificate -> update configuration file -> [update Cloudreve]"
    tyblue "   3. Check for Updates / Update Script"
    tyblue "   4. Update system components"
    tyblue "   5. install/check for updates/update bbr"
    purple "         Contains: bbr2/bbrplus/bbr magic revision/violent bbr magic revision/sharp speed"
    tyblue "   6. install/check for updates/update php"
    tyblue "   7. Check for Updates / Update Nginx"
    tyblue "   8. Update Cloudreve"
    tyblue "   9. Update Xray"
    red    "  10. Uninstall Xray-TLS+Web"
    red    "  11. uninstall php"
    red    "  12. Uninstall Cloudreve"
    echo
    tyblue " --------------start/stop-------------"
    tyblue "  13. Start/restart Xray-TLS+Web"
    tyblue "  14. Stop Xray-TLS+Web"
    echo
    tyblue " ----------------manage----------------"
    tyblue "  15. View configuration information"
    tyblue "  16. reset domain name"
    purple "         All domain name configurations will be deleted. If the domain name is entered incorrectly during installation, Xray cannot be started. This option can be used to repair it."
    tyblue "  17. add domain name"
    tyblue "  18. delete domain name"
    tyblue "  19. Modify the type of camouflaged website"
    tyblue "  20. Reinstall Cloudreve"
    purple "         All Cloudreve network disk files and account information will be deleted, if the administrator password is forgotten, this option can be used to recover"
    tyblue "  21. Modify the transport protocol"
    tyblue "  22. Modify id (user ID/UUID)"
    tyblue "  23. Modify the serviceName of gRPC"
    tyblue "  24. Modify the path (path) of WebSocket"
    echo
    tyblue " ----------------other----------------"
    tyblue "  25. streamlined system"
    purple "         Remove unnecessary system components, even if Xray-TLS+Web is installed, you can still use this feature"
    tyblue "  26. Try to fix the problem that the backspace key cannot be used"
    purple "         Some ssh tools (such as Xshell) may have such problems"
    tyblue "  27. modify dns"
    yellow "  0. exit script"
    echo
    echo
    local choice=""
    while [[ ! "$choice" =~ ^(0|[1-9][0-9]*)$ ]] || ((choice>27))
    do
        read -p "your choice is：" choice
    done
    if (( choice==2 || (7<=choice&&choice<=9) || choice==13 || (15<=choice&&choice<=24) )) && [ $is_installed -eq 0 ]; then
        red "Please install Xray-TLS+Web first！！"
        return 1
    fi
    if (( 17<=choice&&choice<=20 )) && ! (systemctl -q is-active nginx && systemctl -q is-active xray); then
        red "Please start Xray-TLS+Web first！！"
        return 1
    fi
    if [ $choice -eq 1 ]; then
        install_update_xray_tls_web
    elif [ $choice -eq 2 ]; then
        [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
        check_important_dependence_installed ca-certificates ca-certificates
        check_important_dependence_installed wget wget
        ask_update_script_force
        bash "${BASH_SOURCE[0]}" --update
    elif [ $choice -eq 3 ]; then
        [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
        check_important_dependence_installed ca-certificates ca-certificates
        check_important_dependence_installed wget wget
        ask_update_script
    elif [ $choice -eq 4 ]; then
        [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
        check_important_dependence_installed tzdata tzdata
        get_system_info
        check_ssh_timeout
        check_important_dependence_installed "procps" "procps-ng"
        doupdate
        green "update completed！"
    elif [ $choice -eq 5 ]; then
        [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
        check_important_dependence_installed ca-certificates ca-certificates
        check_important_dependence_installed wget wget
        check_important_dependence_installed "procps" "procps-ng"
        enter_temp_dir
        install_bbr
        $apt_no_install_recommends -y -f install
        rm -rf "$temp_dir"
    elif [ $choice -eq 6 ]; then
        install_check_update_update_php
    elif [ $choice -eq 7 ]; then
        check_update_update_nginx
    elif [ $choice -eq 8 ]; then
        if [ $cloudreve_is_installed -eq 0 ]; then
            red    "Please install Cloudreve first!"
            tyblue "Select Cloudreve in Modify Masquerade Website Type/Reset Domain Name/Add Domain Name"
            return 1
        fi
        [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
        check_SELinux
        install_web_dependence "1"
        ask_update_script_force
        enter_temp_dir
        update_cloudreve
        cd /
        rm -rf "$temp_dir"
        green "Cloudreve update complete！"
    elif [ $choice -eq 9 ]; then
        [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
        check_SELinux
        check_important_dependence_installed ca-certificates ca-certificates
        check_important_dependence_installed curl curl
        install_update_xray
        green "Xray update complete！"
    elif [ $choice -eq 10 ]; then
        ! ask_if "You sure you want to delete it?(y/n)" && return 0
        [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
        check_important_dependence_installed ca-certificates ca-certificates
        check_important_dependence_installed curl curl
        remove_xray
        remove_nginx
        remove_php
        remove_cloudreve
        $HOME/.acme.sh/acme.sh --uninstall
        rm -rf $HOME/.acme.sh
        green "delete complete！"
    elif [ $choice -eq 11 ]; then
        get_config_info
        [ $is_installed -eq 1 ] && check_need_php && red "有域名正在使用php" && return 1
        ! ask_if "Are you sure you want to delete php?(y/n)" && return 0
        remove_php && green "删除完成！"
    elif [ $choice -eq 12 ]; then
        get_config_info
        [ $is_installed -eq 1 ] && check_need_cloudreve && red "There are domains using Cloudreve" && return 1
        ! ask_if "Are you sure you want to delete cloudreve?(y/n)" && return 0
        remove_cloudreve && green "delete complete！"
    elif [ $choice -eq 13 ]; then
        restart_xray_tls_web
    elif [ $choice -eq 14 ]; then
        systemctl stop xray nginx
        [ $php_is_installed -eq 1 ] && systemctl stop php-fpm
        [ $cloudreve_is_installed -eq 1 ] && systemctl stop cloudreve
        green "stopped！"
    elif [ $choice -eq 15 ]; then
        get_config_info
        print_config_info
    elif [ $choice -eq 16 ]; then
        reinit_domain
    elif [ $choice -eq 17 ]; then
        add_domain
    elif [ $choice -eq 18 ]; then
        delete_domain
    elif [ $choice -eq 19 ]; then
        change_pretend
    elif [ $choice -eq 20 ]; then
        reinstall_cloudreve
    elif [ $choice -eq 21 ]; then
        change_xray_protocol
    elif [ $choice -eq 22 ]; then
        change_xray_id
    elif [ $choice -eq 23 ]; then
        change_xray_serviceName
    elif [ $choice -eq 24 ]; then
        change_xray_path
    elif [ $choice -eq 25 ]; then
        simplify_system
    elif [ $choice -eq 26 ]; then
        repair_tuige
    elif [ $choice -eq 27 ]; then
        change_dns
    fi
}

if [ "$1" == "--update" ]; then
    update=1
    install_update_xray_tls_web
else
    update=0
    start_menu
fi
