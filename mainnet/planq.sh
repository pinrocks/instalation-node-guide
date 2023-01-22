#!/bin/bash


echo -e "\033[0;35m"
echo " .----------------.  .----------------.  .----------------.  .----------------.  .----------------.   ";
echo " | .--------------. || .--------------. || .--------------. || .--------------. || .--------------. |  ";
echo " | |  ___  ____   | || |     ____     | || |  ________    | || |     ____     | || |  ___  ____   | |  ";
echo " | | |_  ||_  _|  | || |   .'    `.   | || | |_   ___ `.  | || |   .'    `.   | || | |_  ||_  _|  | |  ";
echo " | |   | |_/ /    | || |  /  .--.  \  | || |   | |   `. \ | || |  /  .--.  \  | || |   | |_/ /    | |  ";
echo " | |   |  __'.    | || |  | |    | |  | || |   | |    | | | || |  | |    | |  | || |   |  __'.    | |  ";
echo " | |  _| |  \ \_  | || |  \  `--'  /  | || |  _| |___.' / | || |  \  `--'  /  | || |  _| |  \ \_  | |  ";
echo " | | |____||____| | || |   `.____.'   | || | |________.'  | || |   `.____.'   | || | |____||____| | |  ";
echo " | |              | || |              | || |              | || |              | || |              | |  ";
echo " | '--------------' || '--------------' || '--------------' || '--------------' || '--------------' |  ";
echo "  '----------------'  '----------------'  '----------------'  '----------------'  '----------------'   ";
echo -e "\e[0m"

sleep 2

# set vars
if [ ! $NODENAME ]; then
	read -p "Enter node name: " NODENAME
	echo 'export NODENAME='$NODENAME >> $HOME/.bash_profile
fi
PLANQ_PORT=35
if [ ! $WALLET ]; then
	echo "export WALLET=wallet" >> $HOME/.bash_profile
fi
echo "export PLANQ_CHAIN_ID=planq_7070-2" >> $HOME/.bash_profile
echo "export PLANQ_PORT=${PLANQ_PORT}" >> $HOME/.bash_profile
source $HOME/.bash_profile

echo '================================================='
echo -e "Your node name: \e[1m\e[32m$NODENAME\e[0m"
echo -e "Your wallet name: \e[1m\e[32m$WALLET\e[0m"
echo -e "Your chain name: \e[1m\e[32m$PLANQ_CHAIN_ID\e[0m"
echo -e "Your port: \e[1m\e[32m$PLANQ_PORT\e[0m"
echo '================================================='
sleep 2

echo -e "\e[1m\e[32m1. Updating packages... \e[0m" && sleep 1
# update
sudo apt update && sudo apt upgrade -y

echo -e "\e[1m\e[32m2. Installing dependencies... \e[0m" && sleep 1
# packages
sudo apt install curl build-essential git wget jq make gcc tmux chrony -y

# install go
if ! [ -x "$(command -v go)" ]; then
  ver="1.18.2"
  cd $HOME
  wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz"
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
  rm "go$ver.linux-amd64.tar.gz"
  echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> ~/.bash_profile
  source ~/.bash_profile
fi

echo -e "\e[1m\e[32m3. Downloading and building binaries... \e[0m" && sleep 1
# download binary
cd $HOME
git clone https://github.com/planq-network/planq.git
cd haqq
git fetch

echo "Build binaries.."
    git checkout v1.0.2
    make build
	mkdir -p $HOME/.planqd/cosmovisor/genesis/bin
	mkdir -p ~/.planqd/cosmovisor/upgrades
	cp ~/go/bin/planqd ~/.planqd/cosmovisor/genesis/bin

echo "Install and building Cosmovisor..."
    go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.4.0

# config
planqd config chain-id $PLANQ_CHAIN_ID
planqd config keyring-backend file
planqd config node tcp://localhost:${PLANQ_PORT}657

# init
planqd init $NODENAME --chain-id $PLANQ_CHAIN_ID

# download genesis and addrbook
wget -qO $HOME/.planqd/config/genesis.json "https://raw.githubusercontent.com/elangrr/testnet_guide/main/planq/addrbook.json"

# Add seeds
seeds=`curl -sL https://raw.githubusercontent.com/planq-network/networks/main/mainnet/seeds.txt | awk '{print $1}' | paste -s -d, -`
sed -i.bak -e "s/^seeds =.*/seeds = \"$seeds\"/" ~/.planqd/config/config.toml
sed -i 's/max_num_inbound_peers =.*/max_num_inbound_peers = 100/g' $HOME/.planqd/config/config.toml
sed -i 's/max_num_outbound_peers =.*/max_num_outbound_peers = 100/g' $HOME/.planqd/config/config.toml

# set custom ports
sed -i.bak -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:${PLANQ_PORT}658\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:${PLANQ_PORT}657\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:${PLANQ_PORT}060\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:${PLANQ_PORT}656\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":${PLANQ_PORT}660\"%" $HOME/.planqd/config/config.toml
sed -i.bak -e "s%^address = \"tcp://0.0.0.0:1317\"%address = \"tcp://0.0.0.0:${PLANQ_PORT}317\"%; s%^address = \":8080\"%address = \":${PLANQ_PORT}080\"%; s%^address = \"0.0.0.0:9090\"%address = \"0.0.0.0:${PLANQ_PORT}090\"%; s%^address = \"0.0.0.0:9091\"%address = \"0.0.0.0:${PLANQ_PORT}091\"%" $HOME/.planqd/config/app.toml

# config pruning
pruning="custom"
pruning_keep_recent="100"
pruning_keep_every="0"
pruning_interval="50"
sed -i -e "s/^pruning *=.*/pruning = \"$pruning\"/" $HOME/.planqd/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"$pruning_keep_recent\"/" $HOME/.planqd/config/app.toml
sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"$pruning_keep_every\"/" $HOME/.planqd/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"$pruning_interval\"/" $HOME/.planqd/config/app.toml

# set minimum gas price and timeout commit
sed -i -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0aISLM\"/" $HOME/.planqd/config/app.toml

# enable prometheus
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.planqd/config/config.toml

# Set Indexer Null
   indexer="null" && \
   sed -i -e "s/^indexer *=.*/indexer = \"$indexer\"/" $HOME/.planqd/config/config.toml

# reset
planqd tendermint unsafe-reset-all --home $HOME/.planqd

echo -e "\e[1m\e[32m4. Starting service... \e[0m" && sleep 1
# create service
sudo tee /etc/systemd/system/planqd.service > /dev/null <<EOF
[Unit]
Description=planq
After=network-online.target

[Service]
User=$USER
ExecStart=$(which planqd) start --home $HOME/.planqd
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# start service
sudo systemctl daemon-reload
sudo systemctl enable planqd
sudo systemctl restart planqd

echo '=============== SETUP FINISHED ==================='
echo -e 'To check logs: \e[1m\e[32mjournalctl -u planqd -f -o cat\e[0m'
echo -e "To check sync status: \e[1m\e[32mcurl -s localhost:${PLANQ_PORT}657/status | jq .result.sync_info\e[0m"