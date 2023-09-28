#!/bin/bash
export LANG=zh_CN.UTF-8
###############################################################以下脚本内容，勿动#######################################################################
proxygithub="https://ghproxy.com/" #反代github加速地址，如果不需要可以将引号内容删除，如需修改请确保/结尾 例如"https://ghproxy.com/"
Threads=1024 #线程数

update_gengxinzhi=0
apt_update() {
    if [ "$update_gengxinzhi" -eq 0 ]; then
        sudo apt update
        update_gengxinzhi=$((update_gengxinzhi + 1))
    fi
}

# 检测并安装软件函数
apt_install() {
    if ! command -v "$1" &> /dev/null; then
        echo "$1 未安装，开始安装..."
        apt_update
        sudo apt install "$1" -y
        echo "$1 安装完成！"
    fi
}

apt_install curl

# 检测是否已经安装了geoiplookup
if ! command -v geoiplookup &> /dev/null; then
    echo "geoiplookup 未安装，开始安装..."
    apt_update
    sudo apt install geoip-bin -y
    echo "geoiplookup 安装完成！"
else
    echo "geoiplookup ok."
fi

# 检测GeoLite2-Country.mmdb文件是否存在
if [ ! -f "/usr/share/GeoIP/GeoLite2-Country.mmdb" ]; then
    echo "文件 /usr/share/GeoIP/GeoLite2-Country.mmdb 不存在。正在下载..."
    
    # 使用curl命令下载文件
    curl -L -o /usr/share/GeoIP/GeoLite2-Country.mmdb "${proxygithub}https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-Country.mmdb"
    
    # 检查下载是否成功
    if [ $? -eq 0 ]; then
        echo "下载完成。"
    else
        echo "下载失败。脚本终止。"
        exit 1
    fi
fi

if [ -e CloudFlareIP.txt ]; then
  #echo "清理旧的CloudFlareIP.txt文件."
  rm -f CloudFlareIP.txt
fi

# 检测temp文件夹是否存在
if [ ! -d "temp" ]; then
    #echo "temp文件夹不存在，正在创建..."
    mkdir temp
else
    #echo "temp文件夹已存在，正在删除文件..."
    rm -f temp/*  # 删除temp文件夹内的所有文件
fi

gogogo(){
if [ -e "temp/ip0.txt" ]; then
    #echo "扫描IP文件库80端口开始..."
    ./Pscan -F temp/ip0.txt -P 80 -T $Threads -O temp/d80.txt -timeout 1s > /dev/null 2>&1
else
    echo "无有效IP内容，脚本终止。请重新编写ip.txt文件"
    exit 1  # 终止脚本，1 表示出现了错误
fi

if [ -e "temp/d80.txt" ]; then
    #echo "扫描IP文件库80端口完成."
    awk 'NF' temp/d80.txt | sed 's/:80$//' >> temp/80.txt
else
    echo "无IP开启80端口，脚本终止。请增加ip.txt文件内IP数"
    exit 1  # 终止脚本，1 表示出现了错误
fi

if [ -e "temp/80.txt" ]; then
    #echo "扫描IP文件库443端口开始..."
    ./Pscan -F temp/80.txt -P 443 -T $Threads -O temp/d443.txt -timeout 1s > /dev/null 2>&1
else
    echo "无IP开启443端口，脚本终止。请增加ip.txt文件内IP数"
    exit 1  # 终止脚本，1 表示出现了错误
fi

if [ -e "temp/d443.txt" ]; then
    #echo "扫描IP文件库443端口完成."
    awk 'NF' temp/d443.txt | sed 's/:443$//' >> temp/443.txt
else
    echo "无IP开启443端口，脚本终止。请增加ip.txt文件内IP数"
    exit 1  # 终止脚本，1 表示出现了错误
fi

#echo "开始验证CloudFlareIP"
python3 TestCloudFlareIP.py
}

if [ -e "ip.txt" ]; then
    echo "开始整理IP文件库"
    
    # 删除temp文件夹内的所有文件
    rm -f temp/*

    # 检查ip.txt是否为空行，并将每行内容作为ips参数传递给process_ip.py
    while IFS= read -r line; do
        if [ -n "$line" ]; then
	    echo "Scan $line"
            python3 process_ip.py "$line"
	    gogogo
        fi
    done < "ip.txt"

    echo "ip库全部处理完成"
else
    echo "ip.txt 文件不存在，脚本结束。"
    exit 1  # 退出脚本，1 表示出现了错误
fi

# 检查CloudFlareIP.txt文件是否存在
if [ -f "CloudFlareIP.txt" ]; then

	# 检测ip文件夹是否存在
	if [ -d "ip" ]; then
		echo "开始清理IP地区文件"
		rm -f ip/*
		echo "清理IP地区文件完成。"
	else
		echo "创建IP地区文件。"
		mkdir -p ip
	fi

echo "正在将IP按国家代码保存到ip文件夹内..."
    # 逐行处理CloudFlareIP.txt文件
    while read -r line; do
        ip=$(echo $line | cut -d ' ' -f 1)  # 提取IP地址部分
		result=$(mmdblookup --file /usr/share/GeoIP/GeoLite2-Country.mmdb --ip $ip country iso_code)
		country_code=$(echo $result | awk -F '"' '{print $2}')
		echo $ip >> "ip/${country_code}-443.txt"  # 写入对应的国家文件
    done < CloudFlareIP.txt

    echo "IP已按国家分类保存到ip文件夹内。"
else
    echo "CloudFlareIP.txt文件不存在，脚本终止。"
    exit 1
fi
