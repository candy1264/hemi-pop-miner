#!/bin/bash

# 功能：自动安装缺少的依赖项 (git 和 make)
install_dependencies() {
    for cmd in git make; do
        if ! command -v $cmd &> /dev/null; then
            echo "$cmd 未安装。正在自动安装 $cmd..."

            # 检测操作系统类型并执行相应的安装命令
            if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                sudo apt update
                sudo apt install -y $cmd
            elif [[ "$OSTYPE" == "darwin"* ]]; then
                brew install $cmd
            else
                echo "不支持的操作系统。请手动安装 $cmd。"
                exit 1
            fi
        fi
    done
    echo "已安装所有依赖项。"
}

# 功能：检查 Go 版本是否 >= 1.22.2
check_go_version() {
    if command -v go >/dev/null 2>&1; then
        CURRENT_GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
        MINIMUM_GO_VERSION="1.22.2"

        if [ "$(printf '%s\n' "$MINIMUM_GO_VERSION" "$CURRENT_GO_VERSION" | sort -V | head -n1)" = "$MINIMUM_GO_VERSION" ]; then
            echo "当前 Go 版本满足要求: $CURRENT_GO_VERSION"
        else
            echo "当前 Go 版本 ($CURRENT_GO_VERSION) 低于要求的版本 ($MINIMUM_GO_VERSION)，将安装最新的 Go。"
            install_go
        fi
    else
        echo "未检测到 Go，正在安装 Go。"
        install_go
    fi
}

install_go() {
    wget https://go.dev/dl/go1.22.2.linux-amd64.tar.gz
    sudo tar -C /usr/local -xzf go1.22.2.linux-amd64.tar.gz
    export PATH=$PATH:/usr/local/go/bin
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    source ~/.bashrc
    echo "Go 安装完成，版本: $(go version)"
}

# 检查并自动安装 git, make 和 Go
install_dependencies
check_go_version

# 功能1：下载、解压缩并运行帮助命令
download_and_setup() {
    wget https://github.com/hemilabs/heminetwork/releases/download/v0.3.2/heminetwork_v0.3.2_linux_amd64.tar.gz

    # 解压并将文件夹名称更改为 heminetwork
    tar --transform 's/^heminetwork_v0.3.2_linux_amd64/heminetwork/' -xvf heminetwork_v0.3.2_linux_amd64.tar.gz

    cd "$HOME/heminetwork"
    ./popmd --help
    ./keygen -secp256k1 -json -net="testnet" > ~/popm-address.json
}

# 功能2：设置环境变量
setup_environment() {
    cd "$HOME/heminetwork"
    cat ~/popm-address.json

    # 提示用户输入 private_key 值
    read -p "填入上面输出的private_key值: " POPM_BTC_PRIVKEY
    export POPM_BTC_PRIVKEY=$POPM_BTC_PRIVKEY

    # 提示用户输入 fee_per_vB 值
    read -p "在https://mempool.space/zh/testnet中查看sat/vB的值并填入: " POPM_STATIC_FEE
    export POPM_STATIC_FEE=$POPM_STATIC_FEE

    export POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public
}

# 功能3：使用 pm2 启动 popmd
start_popmd() {
    pm2 start ./popmd
}

# 主菜单
main_menu() {
    while true; do
        echo "请选择一个选项:"
        echo "1. 下载并设置 Heminetwork"
        echo "2. 设置钱包以及sats/vB"
        echo "3. 启动 popmd"
        echo "4. 退出"

        read -p "请输入选项 (1-4): " choice

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
                echo "退出脚本。"
                exit 0
                ;;
            *)
                echo "无效选项，请重新输入。"
                ;;
        esac
    done
}

# 启动主菜单
main_menu
