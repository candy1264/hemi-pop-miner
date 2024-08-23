wget https://github.com/hemilabs/heminetwork/releases/download/v0.3.2/heminetwork_v0.3.2_linux_amd64.tar.gz
tar xvf heminetwork_v0.3.2_linux_amd64.tar.gz
cd '/$HOME/heminetwork_v0.3.2_linux_amd64'
./popmd --help
cat ~/popm-address.json
export POPM_BTC_PRIVKEY=<private_key>
export POPM_STATIC_FEE=<fee_per_vB_integer>
export POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public
