#!/bin/bash
function setup() {
  dpkg -l curl
  if [ ! $? == 0 ]; then
    sudo apt-get install -y curl
  fi

  dpkg -l curl
  if [ ! $? == 0 ]; then
    echo dpkg curl fail
    exit -1
  fi

  dpkg -l npm
  if [ ! $? == 0 ]; then
    apt-get update
    apt-get install nodejs -y
    apt-get install npm -y
    npm install -g pm2
    pm2 install pm2-logrotate
    pm2 set pm2-logrotate:max_size 1M
  fi

  pm2 -V
  if [ ! $? == 0 ]; then
    echo pm2 geth fail
    exit -1
  fi

  dpkg -l jq
  if [ ! $? == 0 ]; then
    apt install jq -y
  fi

  dpkg -l jq
  if [ ! $? == 0 ]; then
    echo jq get fail
    exit -1
  fi
}

function init() {
  local i
  databak
  stopall
  if [ -e ${configdir} ]; then
    echo "config dir exists,now remove"
    rm -rf ${configdir}
    mkdir ${configdir} -p
  else
    mkdir ${configdir} -p
  fi
  if [ -e ${datadir} ]; then
    echo "data dir exists,now backup and remove"
    rm -rf ${datadir}
    mkdir ${datadir} -p
  else
    mkdir ${datadir} -p
  fi
  for ((i = 1; i <= $1; i++)); do
    if [ $i -le 9 ]; then
      startnode 0$i
    else
      startnode $i
    fi
  done
}

function databak() {
  pm2 stop all
  local nodeaccount
  local i
  nodeaccount=$(find ${datadir} -name keys | wc -l)
  if [ -e ${databak} ]; then
    echo "${databak} dir exists,now remove"
    rm -rf ${databak}/*
  else
    mkdir ${databak} -p
  fi
  cp $passwdfile ${databak}/
  for ((i = 1; i <= ${nodeaccount}; i++)); do
    if [ $i -le 9 ]; then
      mkdir ${databak}/bee0$i
      cp -r ${datadir}/bee0$i/keys ${databak}/bee0$i
      cp -r ${datadir}/bee0$i/statestore ${databak}/bee0$i
      cp -r ${datadir}/bee0$i/.passwd.txt ${databak}/bee0$i
    else
      mkdir ${databak}/bee$i
      cp -r ${datadir}/bee$i/keys ${databak}/bee$i
      cp -r ${datadir}/bee$i/statestore ${databak}/bee$i
      cp -r ${datadir}/bee$i/.passwd.txt ${databak}/bee$i
    fi
  done
  if [ -e ${databaktar} ]; then
    echo "${databak} dir exists,now databak"
    cp -r ${databaktar}/new/* ${databaktar}/old/$(date "+%Y-%m-%d_%H:%M:%S").tar.gz
    rm -rf ${databaktar}/new/*
  else
    mkdir ${databaktar}/new -p
    mkdir ${databaktar}/old -p
  fi
  cd ${databak}
  tar zcPvf ${databaktar}/new/new.tar.gz *

  cd ${databaktar}/old
  if [ $(ls -l | wc -l) -gt 3 ]; then
    echo "file > 2"
    rm -r $(ls -rt | head -n1)
  fi

  pm2 start all
}

function startnode() {
  if [ -e ${configdir}/bee$1.yaml ]; then
    echo "bee$1.yaml exists,now remove"
    rm -rf ${configdir}/bee$1.yaml
    touch ${configdir}/bee$1.yaml
  else
    touch ${configdir}/bee$1.yaml
  fi

  if [ -e ${datadir}/bee$1 ]; then
    echo "bee$1 exists"
  else
    mkdir ${datadir}/bee$1 -p
    password=$(openssl rand -base64 32)
    echo $password >${datadir}/bee$1/.passwd.txt
  fi
  if [ -e ${datadir}/bee$1/.passwd.txt ]; then
    password=$(cat ${datadir}/bee$1/.passwd.txt)
  else
    echo bee$1 not have passwd file
  fi
  cat >${configdir}/bee$1.yaml <<EOF
data-dir: ${datadir}/bee$1
debug-api-addr: 0.0.0.0:16$1
password: "$password"
verbosity: info
debug-api-enable: true
swap-endpoint: $goerlinode
swap-initial-deposit: $initialdeposit
p2p-addr: :17$1
api-addr: :18$1
full-node: true
db-open-files-limit: 20000
network-id: 1
EOF

  pm2 start ${beepath} --name bee$1 -- start --config ${configdir}/bee$1.yaml --mainnet

  pm2 startup
  pm2 save
}

function start() {
  local i
  stopall
  for ((i = 1; i <= $1; i++)); do
    if [ $i -le 9 ]; then
      startnode 0$i
    else
      startnode $i
    fi
  done
}

function restart() {
  local i
  stopall
  nodeaccount=$(ls -l ${datadir} | grep "^d" | wc -l)
  for ((i = 1; i <= ${nodeaccount}; i++)); do
    if [ $i -le 9 ]; then
      startnode 0$i
    else
      startnode $i
    fi
  done
}

function addnode() {
  local i
  local j
  local nodeaccount
  nodeaccount=$(find ${datadir} -name keys | wc -l)

  for ((i = 1; i <= $1; i++)); do
    j=$(expr $nodeaccount + $i)
    if [ $j -le 9 ]; then
      startnode 0$j
    else
      startnode $j
    fi
  done
}

function stopall() {
  pm2 delete all -f
  sleep 5
  pm2 delete all -f
}

function getpassword() {
  local passwd
  if [ -e ${passwdfile} ]; then
    passwd=$(cat ${passwdfile})
  else
    touch ${passwdfile}
    chmod 777 ${passwdfile}
    passwd=$(openssl rand -base64 32)
    echo $passwd >${passwdfile}
  fi
  echo $passwd

}
function getgoerlinode() {
  local goerlinode
  if [ -e ${goerlinodefile} ]; then
    goerlinode=$(cat ${goerlinodefile})
  else
    touch ${goerlinodefile}
    chmod 777 ${goerlinodefile}
    goerlinode="http://45.58.141.210:8545"
    echo $goerlinode >${goerlinodefile}
  fi
  echo $goerlinode

}
function getethadd() {
  local debugapi
  local filename
  local ethaddress
  local publicip
  publicip=$(getpublicip)
  if [ -e ${ethaddressfile} ]; then
    rm ${ethaddressfile}
  fi
  nodeaccount=$(ls -l ${datadir} | grep "^d" | wc -l)
  for ((i = 1; i <= ${nodeaccount}; i++)); do
    if [ $i -le 9 ]; then
      debugapi=http://$publicip://160$i
      filename=${datadir}/bee0$i/keys/swarm.key
    else
      debugapi=http://$publicip://16$i
      filename=${datadir}/bee$i/keys/swarm.key
    fi
    ethaddress=$(jq .address ${filename} | sed 's/[[:punct:]]//g')
    echo $debugapi, $ethaddress >>${ethaddressfile}
  done

  if [ $? == 0 ]; then
    echo "get ${ethaddressfile} is ok"
  else
    echo "get ${ethaddressfile} fail"
  fi

}

function setulimit() {
  local ulimitcount
  ulimitcount=$(ulimit -n)
  if [[ $ulimitcount -le 10000 ]]; then
    echo ulimit -SHn 200000 >>/etc/profile
    source /etc/profile
  fi
}

function getpublicip() {
  ip=$(ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1)
  if [[ "$ip" == "" ]]; then
    ip=$(wget -qO- -t1 -T2 ipv4.icanhazip.com)
  fi
  echo $ip
}

function help() {
  echo "          "setup "安装基础软件pm2、jq、curl等"
  echo "          "databak "备份信息，当可以获得所有chequebook余额的时候，备份当keys和storage目录，放在tmp下面"
  echo "          "init "先执行备份，然后进行新建节点,需要跟启动节点的参数"
  echo "          "startnode "需要跟启动节点的参数，根据参数启动多少个节点"
  echo "          "restart "依据目录个数，重启所有节点"
  echo "          "stopall "停掉所有节点"
  echo "          "getethadd "获取当前节点eth地址"
  echo "          "addnode "添加节点"
}
passwdfile=/home/.passwd.txt
goerlinodefile=/home/.goerlinode.txt
password=$(getpassword)
goerlinode=$(getgoerlinode)
beepath=/home/swarm/bee
configdir=/mnt/config
if [ ! -e ${configdir} ]; then
  mkdir ${configdir} -p
fi
filedir=/home/file
if [ ! -e ${filedir} ]; then
  echo "config dir not exists,now remove"
  mkdir ${filedir} -p
fi
ethaddressfile=$filedir/ethadd.csv
if [ -e ${ethaddressfile} ]; then
  rm ${ethaddressfile}
fi
initialdeposit=0
datadir=/mnt/data
databak=/tmp/databak
databaktar=/tmp/databaktar
swapoff -a

setulimit
case $1 in
init | start | restart | databak | stopall | setup | help | startgoerlinode | addnode | getethadd) "$1" "$2" ;;
esac
