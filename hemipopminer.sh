#!/bin/bash

# 发生错误时退出脚本
set -e

# 捕获错误并提示
trap 'echo "发生错误，脚本已退出。/ An error occurred, the script has exited.";' ERR

# 功能：自动安装缺少的依赖项 (git 和 make)
install_dependencies() {
    for cmd in git make; do
        if ! command -v $cmd &> /dev/null; then
            echo "$cmd 未安装。正在自动安装 $cmd... / $cmd is not installed. Installing $cmd..."

            # 检测操作系统类型并执行相应的安装命令
            if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                sudo apt update
                sudo apt install -y $cmd
            elif [[ "$OSTYPE" == "darwin"* ]]; then
                brew install $cmd
            else
                echo "不支持的操作系统。请手动安装 $cmd。/ Unsupported OS. Please manually install $cmd."
                exit 1
            fi
        fi
    done
    echo "已安装所有依赖项。/ All dependencies have been installed."
}

# 功能：检查 Go 版本是否 >= 1.22.2
check_go_version() {
    if command -v go >/dev/null 2>&1; then
        CURRENT_GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
        MINIMUM_GO_VERSION="1.22.2"

        if [ "$(printf '%s\n' "$MINIMUM_GO_VERSION" "$CURRENT_GO_VERSION" | sort -V | head -n1)" = "$MINIMUM_GO_VERSION" ]; then
            echo "当前 Go 版本满足要求: $CURRENT_GO_VERSION / Current Go version meets the requirement: $CURRENT_GO_VERSION"
        else
            echo "当前 Go 版本 ($CURRENT_GO_VERSION) 低于要求的版本 ($MINIMUM_GO_VERSION)，将安装最新的 Go。/ Current Go version ($CURRENT_GO_VERSION) is below the required version ($MINIMUM_GO_VERSION). Installing the latest Go."
            install_go
        fi
    else
        echo "未检测到 Go，正在安装 Go。/ Go is not detected. Installing Go."
        install_go
    fi
}

install_go() {
    wget https://go.dev/dl/go1.22.2.linux-amd64.tar.gz
    sudo tar -C /usr/local -xzf go1.22.2.linux-amd64.tar.gz
    export PATH=$PATH:/usr/local/go/bin
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    source ~/.bashrc
    echo "Go 安装完成，版本: $(go version) / Go installation completed, version: $(go version)"
}

# 功能：检查并安装 Node.js 和 npm
install_node() {
    echo "检测到未安装 npm。正在安装 Node.js 和 npm... / npm is not installed. Installing Node.js and npm..."

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl -fsSL https://deb.nodesource.com/setup_current.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install node
    else
        echo "不支持的操作系统。请手动安装 Node.js 和 npm。/ Unsupported OS. Please manually install Node.js and npm."
        exit 1
    fi

    echo "Node.js 和 npm 安装完成。/ Node.js and npm installation completed."
}

# 功能：安装 pm2
install_pm2() {
    if ! command -v npm &> /dev/null; then
        echo "npm 未安装。/ npm is not installed."
        install_node
    fi

    if ! command -v pm2 &> /dev/null; then
        echo "pm2 未安装。正在安装 pm2... / pm2 is not installed. Installing pm2..."
        npm install -g pm2
    else
        echo "pm2 已安装。/ pm2 is already installed."
    fi
}

# 功能1：下载、解压缩并运行帮助命令
download_and_setup() {
    wget https://github.com/hemilabs/heminetwork/releases/download/v0.11.5/heminetwork_v0.11.5_linux_amd64.tar.gz -O heminetwork_v0.11.5_linux_amd64.tar.gz

    # 创建目标文件夹 (如果不存在)
    TARGET_DIR="$HOME/heminetwork"
    mkdir -p "$TARGET_DIR"

    # 解压文件到目标文件夹
    tar -xvf heminetwork_v0.11.5_linux_amd64.tar.gz -C "$TARGET_DIR"

    # 移动文件到 heminetwork 目录
    mv "$TARGET_DIR/heminetwork_v0.11.5_linux_amd64/"* "$TARGET_DIR/"
    rmdir "$TARGET_DIR/heminetwork_v0.11.5_linux_amd64"

    # 切换到目标文件夹
    cd $HOME/heminetwork
    ./keygen -secp256k1 -json -net="testnet" > ~/popm-address.json
    ./popmd --help
    
}

# 功能2：设置环境变量
setup_environment() {
    cd "$HOME/heminetwork"
    cat ~/popm-address.json

    # 自动抓取 private_key
    POPM_BTC_PRIVKEY=$(jq -r '.private_key' ~/popm-address.json)
    read -p "检查 https://mempool.space/zh/testnet 上的 sats/vB 值并输入 / Check the sats/vB value on https://mempool.space/zh/testnet and input: " POPM_STATIC_FEE

    export POPM_BTC_PRIVKEY=$POPM_BTC_PRIVKEY
    export POPM_STATIC_FEE=$POPM_STATIC_FEE
    export POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public
}

# 功能3：使用 pm2 启动 popmd
start_popmd() {
    cd "$HOME/heminetwork"
    pm2 start ./popmd --name popmd
    pm2 save
    echo "popmd 已通过 pm2 启动。/ popmd has been started with pm2."
}

# 功能4：备份 popm-address.json
backup_address() {
    echo "请保存到本地：/ Please save the following locally:"
    cat ~/popm-address.json
}

# 功能5：查看日志
view_logs() {
    cd "$HOME/heminetwork"
    pm2 logs popmd
}

# 功能6：更新到 v0.11.5
update_to_v038() {
    echo "开始更新到 v0.11.5 / Starting update to v0.11.5"

    # 停止并删除 pm2 中的 popmd 进程（如果存在）
    echo "尝试停止并删除 pm2 中的 popmd 进程... / Attempting to stop and delete popmd process in pm2..."
    pm2 delete popmd || {
        echo "pm2 删除 popmd 进程失败或进程不存在。/ Failed to delete popmd process or process does not exist in pm2."
    }

    # 删除旧的 heminetwork 文件夹
    echo "删除旧的 heminetwork 文件夹... / Deleting old heminetwork folder..."
    rm -rf "$HOME/heminetwork"

    # 下载并解压 v0.11.5 版本
    echo "下载 v0.11.5 版本的压缩包... / Downloading v0.11.5 version archive..."
    wget https://github.com/hemilabs/heminetwork/releases/download/v0.11.5/heminetwork_v0.11.5_linux_amd64.tar.gz -O /tmp/heminetwork_v0.11.5_linux_amd64.tar.gz

    echo "解压 v0.11.5 版本的压缩包到 heminetwork 文件夹... / Extracting v0.11.5 version archive to heminetwork folder..."
    mkdir -p "$HOME/heminetwork"
    tar -xzf /tmp/heminetwork_v0.11.5_linux_amd64.tar.gz -C "$HOME/heminetwork" --strip-components=1

    # 执行主菜单2的功能：设置环境变量
    echo "执行主菜单2的功能：设置环境变量 / Running function 2 from main menu: Setup environment"
    setup_environment

    # 启动 popmd
    echo "启动 popmd... / Starting popmd..."
    start_popmd

    echo "更新到 v0.11.5 完成，并重新启动 popmd。/ Update to v0.11.5 completed and popmd restarted."
}

# 主菜单
main_menu() {
    while true; do
        clear
        echo "=======================创建自 https://x.com/ccaannddyy11 来自社区 https://t.me/niuwuriji======================="
        echo "=======================Created by https://x.com/ccaannddyy11 from the community https://t.me/niuwuriji======================="
        echo "请选择一个选项: / Please select an option:"
        echo "1. 下载并设置 Heminetwork / Download and setup Heminetwork"
        echo "2. 输入 private_key 和 sats/vB / Input private_key and sats/vB"
        echo "3. 启动 popmd / Start popmd"
        echo "4. 备份地址信息 / Backup address information"
        echo "5. 查看日志 / View logs"
        echo "6. 更新到 v0.11.5 / Update to v0.11.5"
        echo "7. 退出 / Exit"

        read -p "请输入选项 (1-7): / Enter your choice (1-7): " choice

        case $choice in
            1)
                download_and_setup
                ;;
            2)
                setup_environment
                ;;
            3)
                start_popmd
                ;;
            4)
                backup_address
                ;;
            5)
                view_logs
                ;;
            6)
                update_to_v038
                ;;
            7)
                echo "退出脚本。/ Exiting the script."
                exit 0
                ;;
            *)
                echo "无效选项，请重新输入。/ Invalid option, please try again."
                ;;
        esac
    done
}

# 启动主菜单
echo "准备启动主菜单... / Preparing to launch the main menu..."
main_menu
