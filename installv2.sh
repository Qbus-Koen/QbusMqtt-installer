#!/bin/bash

# ============================== Define variables ==============================
IUSER=''
PASSWORD=''
MQTTIP='localhost'
MQTTPORT='1883'
MOSQUITTO=''
INSTMOS=''
OH=''
OH2=''
OH3=''
OH4V=''
DISPLTEXT=''
DISPLCOLOR=''
BITS=''
VENDOR=''
GW2USE=''
PROC=''
NR=''
INSTNR=''

# ============================== Define colors ==============================
DISPLTEXT=''
DISPLCOLOR=''

BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# ============================== Define functions ==============================
spin(){
  spinner="/|\\-/|\\-"
  while :
  do
    for i in `seq 0 7`
    do
      echo -n "${spinner:$i:1}"
      echo -en "\010"
      sleep 0.1
    done
  done
}

echoInColor(){
	echo -e "$DISPLCOLOR$DISPLTEXT"
}

echoInColorP(){
	echo -en "$DISPLCOLOR$DISPLTEXT"
}

installDependencies(){
	spin &
	SPIN_PID=$!
	trap "kill -9 $SPIN_PID" `seq 0 15`

	sudo apt-get install -y wget tftp unzip curl openjdk-17-jdk-headless > /dev/null 2>&1
	
	
	kill -9 $SPIN_PID
}


checkPocessor() {
	BITS=$(getconf LONG_BIT)
	VENDOR=$(lscpu | grep 'Vendor')
	
	if [[ "$VENDOR" == *"ARM"* ]]; then
		# ARM detected
		GW2USE='qbusMqttGw-arm'
		if [[ "$BITS" == 64 ]]; then
			# 64 BITS ARM
			DISPLTEXT='  We detected a 64 bit ARM processor. We do noet support this kind of processor.'
			DISPLCOLOR=${RED}
			echoInColor
			DISPLTEXT='  It is possible to install libraries that makes it possible to run our 32 bit version on your 64 bit system,'
			DISPLCOLOR=${RED}
			echoInColor
			read -p "$(echo -e $RED"  but we do not recommend this. Do you want to continue (on your own risk)? (y/n) "$NC)" CONTLIB
			if [[ "$CONTLIB" == *"y"* ]]; then
				DISPLTEXT='  -Installing 64bit dependencies.'
				DISPLCOLOR=${YELLOW}
				echoInColor
				sudo dpkg --add-architecture armhf > /dev/null 2>&1
				sudo apt-get update -y > /dev/null 2>&1
				sudo apt-get install -y libc6:armhf libdbus-1-3:armhf libstdc++6:armhf > /dev/null 2>&1
				sudo ln -s /lib/./arm-linux-gnueabihf/ld-2.31.so /lib/ld-linux.so.3 > /dev/null 2>&1
				sudo ln -s /lib/./arm-linux-gnueabihf/libdbus-1.so.3 /lib/libdbus-1.so.3 > /dev/null 2>&1
				sudo ln -s /lib/./arm-linux-gnueabihf/libstdc++.so.6 /lib/libstdc++.so.6 > /dev/null 2>&1
			else
				DISPLTEXT='Aborting installation, we do not have a client that supports your kind of processor.'
				DISPLCOLOR=${RED}
				echoInColor
				exit 0
			fi
		fi
	elif [[ "$BITS" == 64 ]]; then
		# 64 BITS
		GW2USE='qbusMqttGw-x64'
	elif [[ "$BITS" == 32 ]]; then
		# 32 BITS
		GW2USE='qbusMqttGw-x86'
	else
		DISPLTEXT='We could not detect the processor type...'
		DISPLCOLOR=${RED}
		echoInColor
		read -p "$(echo -e $YELLOW"-Please enter your processor type ( ARM - for raspberry, 64 - for 64 bit, 32 - for 32 bit: "$NC)" PROC
		if [[ "$PROC" == *"ARM"* ]]; then
			GW2USE='qbusMqttGw-arm'
		elif [[ "$PROC" == 64 ]]; then
			GW2USE='qbusMqttGw-x64'
		elif [[ "$PROC" == 32 ]]; then
			GW2USE='qbusMqttGw-x86'
		else
			DISPLTEXT='Unknown processor type, aborting installation'
			DISPLCOLOR=${RED}
			echoInColor
			exit 0
		fi
	fi
}


installQbusMqttGw(){
	spin &
	SPIN_PID=$!
	trap "kill -9 $SPIN_PID" `seq 0 15`
	
	sudo systemctl stop qbusmqtt > /dev/null 2>&1
	
	checkPocessor
	
	DISPLTEXT='  -Start installation of QbusMQTTGW.'
	DISPLCOLOR=${YELLOW}
	echoInColor
	
	sudo rm /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	
	git clone https://github.com/QbusKoen/qbusMqtt > /dev/null 2>&1
	tar -xf qbusMqtt/qbusMqtt/qbusMqttGw/$GW2USE.tar  -C qbusMqtt/qbusMqtt/qbusMqttGw/ > /dev/null 2>&1
	
	sudo mkdir /usr/bin/qbus > /dev/null 2>&1
	sudo mkdir /opt/qbus > /dev/null 2>&1
	sudo rm -r /var/log/qbus > /dev/null 2>&1
	
	sudo cp -R qbusMqtt/qbusMqtt/fw/ /opt/qbus/ > /dev/null 2>&1
	sudo cp qbusMqtt/qbusMqtt/puttftp /opt/qbus/ > /dev/null 2>&1
	sudo cp qbusMqtt/qbusMqtt/qbusMqttGw/qbusMqttGw /usr/bin/qbus/ > /dev/null 2>&1
	
	sudo chmod +x /usr/bin/qbus/qbusMqttGw
	sudo chmod +x /opt/qbus/puttftp
	
	echo '[Unit]' | sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	echo 'Description=MQTT client for Qbus communication' | sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	echo 'After=user.target networking.service' | sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	echo '' | sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	echo '[Service]' | sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	echo 'Type=simple' | sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	echo 'ExecStart= /usr/bin/qbus/./qbusMqttGw -serial="QBUSMQTTGW" -daemon true -logbuflevel -1 -logtostderr true -storagedir /opt/qbus -mqttbroker "tcp://'$MQTTIP':'$MQTTPORT'" -mqttuser '$IUSER' -mqttpassword '$PASSWORD''| sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	echo 'PIDFile=/var/run/qbusmqttgw.pid' | sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	echo 'Restart=on-failure' | sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	echo 'RemainAfterExit=no' | sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	echo 'RestartSec=5s' | sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	echo '' | sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	echo '[Install]' | sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	echo 'WantedBy=multi-user.target' | sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	
	sudo systemctl daemon-reload > /dev/null 2>&1
	sudo systemctl enable qbusmqtt.service > /dev/null 2>&1
	sudo systemctl restart qbusmqtt.service > /dev/null 2>&1

 
	kill -9 $SPIN_PID
}

checkOH(){
	DISPLTEXT='-- Checking openHAB...'
	DISPLCOLOR=${YELLOW}
	echoInColor
	OH2=$(ls /usr/share/openhab2 2>/dev/null)
	OH3=$(ls /usr/share/openhab 2>/dev/null)
	OHtemp=''
	OHtemp=$(openhab-cli info | grep Version 2>/dev/null)

	read -a strarr <<<"$OHtemp"
	IFS='.'
	read -a OHt <<<"${strarr[1]}"
  


	if [[ $OH2 != "" ]]; then
		# OH2 found
		OH="OH2"
		read -p "$(echo -e $YELLOW"     -We have detected openHAB2 running on your device. The Qbus Binding is developped for the newest version of openHAB (4). Do you agree that we remove openHAB2 and install openHAB4? (y/n)? " $NC)" OH2UPDATE

	elif [[ $OHt == "3" ]]; then
		# OH3 or 4 found, checking release
		OH="OH3"
		read -p "$(echo -e $YELLOW"     -We have detected openHAB3 running on your device. The Qbus Binding is developped for the newest version of openHAB (4). Do you agree that we remove openHAB2 and install openHAB4? (y/n)? " $NC)" OH3UPDATE
	elif [[ $OHt == "4" ]]; then
		OH4V=$(cat /etc/apt/sources.list.d/openhab.list)
		if [[ $OH4V =~ "unstable" ]]; then
			DISPLTEXT='     -We have detected openHAB running the snapshot (4.x.x-SNAPSHOT) version. The Qbus Binding is included in this version, but does not work with MQTT. We will copy a JAR file to your current installation. After the installation process, you will need to remove the released Binding if installed. Keep in mind that this binding also works with the stable version.'
			DISPLCOLOR=${GREEN}
			echoInColor
			DISPLTEXT='     -This release of the Qbus Binding was developed for the 4.0.2 release. We could not test this binding for your current setup'
			DISPLCOLOR=${RED}
			echoInColor
		elif [[ $OH4V =~ "testing" ]]; then
			DISPLTEXT='     -We have detected openHAB running the milestone (3.x.xMx) version. The Qbus Binding is included in this version, but does not work with MQTT. We will copy a JAR file to your current installation. After the installation process, you will need to remove the released Binding if installed. Keep in mind that this binding also works with the stable version.'
			DISPLCOLOR=${GREEN}
			echoInColor
			DISPLTEXT='     -This release of the Qbus Binding was developed for the 4.0.2 release. We could not test this binding for your current setup'
			DISPLCOLOR=${RED}
			echoInColor
		elif [[ $OH4V =~ "stable" ]]; then
			DISPLTEXT='     -We have detected openHAB running the stable (4.0.2) version. The Qbus Binding is included in this version, but does not work with MQTT. We will copy a JAR file to your current installation. After the installation process, you will need to remove the released Binding if installed.'
			DISPLCOLOR=${GREEN}
			echoInColor
		fi
	else
		read -p "$(echo -e $YELLOW"     -We did not detected openHAB running on your system. Do you want to install openHAB? ' (y/n)? " $NC)" OHINSTALL
	fi
}

updateNodejs() {
  DISPLTEXT='-- Updating nodejs...'
  DISPLCOLOR=${YELLOW}
  
  spin &
  SPIN_PID=$!
  trap "kill -9 $SPIN_PID" `seq 0 15`
  
  # Update npm
  sudo npm install -g n > /dev/null 2>&1
  sudo n latest > /dev/null 2>&1
  hash -r > /dev/null 2>&1
  sudo npm install -g npm@latest > /dev/null 2>&1
  nvm install node > /dev/null 2>&1
  
  kill -9 $SPIN_PID
}

checkNodeRed() {
  DISPLTEXT='-- Checking node-RED...'
  DISPLCOLOR=${YELLOW}
  echoInColor
  
  NPM=''
  NPM=$(npm -v 2>/dev/null)
  if [[ "$NPM" == "" ]]; then
    read -p "$(echo -e $YELLOW"     -We did not found an installation of node-red. Do you want to install node-red? (y/n)")" INSTNR
  else
    NR=$(npm list -g node-red) > /dev/null 2>&1
    if [[ "$NR" == *"node-red"* ]]; then
      DISPLTEXT='     ->node-RED is installed!'
      DISPLCOLOR=${GREEN}
      echoInColor
    else
      read -p "$(echo -e $YELLOW"     -We did not found an installation of node-red. Do you want to install node-red? (y/n)")" INSTNR
    fi
  fi
}

backupOpenhabFiles(){
	if [[ $OH="OH2" ]]; then
		sudo cp -R /etc/openhab2 /tmp/ > /dev/null 2>&1
	else
		sudo cp -R /etc/openhab /tmp/ > /dev/null 2>&1
	fi
}

restoreOpenhabFiles(){
	if [[ $OH="OH2" ]]; then
		sudo rm /etc/openhab2
		sudo mv /tmp/openhab2 /tmp/openhab
		sudo cp -R /tmp/openhab2 /etc/
	else
		sudo rm /etc/openhab
		sudo cp -R /tmp/openhab /etc/
	fi
}

copyJar(){
	spin &
	SPIN_PID=$!
	trap "kill -9 $SPIN_PID" `seq 0 15`
	
	sudo rm /usr/share/openhab/addons/org.openhab.binding.qbus* > /dev/null 2>&1
	sudo cp qbusMqtt/openHAB/org.openhab.binding.qbus-4.0.0-SNAPSHOT.jar /usr/share/openhab/addons/ > /dev/null 2>&1
	sudo chown openhab:openhab  /usr/share/openhab/addons/org.openhab.binding.qbus-4.0.0-SNAPSHOT.jar > /dev/null 2>&1
	
	sudo systemctl stop openhab.service > /dev/null 2>&1
	
	kill -9 $SPIN_PID
	
	DISPLCOLOR=${ORANGE}
	DISPLTEXT="Please enter \"y\" en press enter to continue."
	echoInColor
	sudo openhab-cli clean-cache
	
	sudo systemctl start openhab.service > /dev/null 2>&1
}

copyNodeRedQbus() {
  spin &
  SPIN_PID=$!
  trap "kill -9 $SPIN_PID" `seq 0 15`

  npm install node-red-contrib-qbus

  kill -9 $SPIN_PID
}

checkSamba(){
  DISPLTEXT='-- Checking SMB...'
  DISPLCOLOR=${YELLOW}
  echoInColor
  
  SAMBA=$(ls /etc/samba/ 2>/dev/null)
  if [[ $SAMBA != "" ]]; then
  	DISPLTEXT='     -Samba Share is installed.'
  	DISPLCOLOR=${GREEN}
  	echoInColor
  	
  	SMB=$(cat /etc/samba/smb.conf)
  
    if [[ $SMB =~ "path=/etc/openhab2" ]]; then
      DISPLTEXT='     -Samba Share is configured for openhab2, changing to openhab...'
	    DISPLCOLOR=${GREEN}
	    echoInColor
      sed -i "s|path=/etc/openhab2|path=/etc/openhab|g" /etc/samba/smb.conf
    fi

    SMBUSER=$(sudo pdbedit -L 2>/dev/null)

    if [[ $SMBUSER =~ "openhab" ]]; then
      DISPLTEXT='     -openHAB user is already configured for Samba Share'
      DISPLCOLOR=${GREEN}
      echoInColor
    else
      DISPLTEXT='     -openHAB user is not configured for Samba Share.'
      DISPLCOLOR=${RED}
      echoInColor
  
      DISPLTEXT='     -Enter a password for the Samba Share for the user openhab & repeat it: '
      DISPLCOLOR=${YELLOW}
      echoInColor

      echo -e -n "$NC"
      sudo smbpasswd -a openhab
    fi
  else
  	read -p "$(echo -e $YELLOW"     -We did not detect Samba Share on your system. You don not really need SMB, but it makes it easier to configure openHAB things. Do you agree to install Samba share (y/n)? " $NC)" INSTSAMBA
          
  	if [[ $INSTSAMBA == "n" ]]; then
  		DISPLTEXT='     -You choose not to install Samba Share. This means you have to configure openHAB things on this device.'
  		DISPLCOLOR=${RED}
  		echoInColor
  	fi
  fi
}

installSamba(){
	spin &
	SPIN_PID=$!
	trap "kill -9 $SPIN_PID" `seq 0 15`
	
	sudo apt-get --assume-yes install samba samba-common-bin > /dev/null 2>&1
	echo '# Windows Internet Name Serving Support Section:' | sudo tee -a /etc/samba/smb.conf > /dev/null 2>&1
	echo '# WINS Support - Tells the NMBD component of Samba to enable its WINS Server' | sudo tee -a /etc/samba/smb.conf > /dev/null 2>&1
	echo 'wins support = yes' | sudo tee -a /etc/samba/smb.conf > /dev/null 2>&1
	echo '' | sudo tee -a /etc/samba/smb.conf > /dev/null 2>&1
	echo '[openHAB]' | sudo tee -a /etc/samba/smb.conf > /dev/null 2>&1
	echo ' comment=openHAB Share' | sudo tee -a /etc/samba/smb.conf > /dev/null 2>&1
	echo ' path=/etc/openhab' | sudo tee -a /etc/samba/smb.conf > /dev/null 2>&1
	echo ' browseable=Yes' | sudo tee -a /etc/samba/smb.conf > /dev/null 2>&1
	echo ' writeable=Yes' | sudo tee -a /etc/samba/smb.conf > /dev/null 2>&1
	echo ' only guest=no' | sudo tee -a /etc/samba/smb.conf > /dev/null 2>&1
	echo ' create mask=0777' | sudo tee -a /etc/samba/smb.conf > /dev/null 2>&1
	echo ' directory mask=0777' | sudo tee -a /etc/samba/smb.conf > /dev/null 2>&1
	echo ' public=no' | sudo tee -a /etc/samba/smb.conf > /dev/null 2>&1
	
	kill -9 $SPIN_PID
}

installOpenhab4(){
  spin &
  SPIN_PID=$!
  trap "kill -9 $SPIN_PID" `seq 0 15`

  curl -fsSL "https://openhab.jfrog.io/artifactory/api/gpg/key/public" | gpg --dearmor > openhab.gpg > /dev/null 2>&1
  sudo mkdir /usr/share/keyrings > /dev/null 2>&1
  sudo mv openhab.gpg /usr/share/keyrings > /dev/null 2>&1
  sudo chmod u=rw,g=r,o=r /usr/share/keyrings/openhab.gpg > /dev/null 2>&1
  echo 'deb [signed-by=/usr/share/keyrings/openhab.gpg] https://openhab.jfrog.io/artifactory/openhab-linuxpkg stable main' | sudo tee /etc/apt/sources.list.d/openhab.list > /dev/null 2>&1
  sudo apt-get --assume-yes update && sudo apt-get install openhab > /dev/null 2>&1

  sudo systemctl daemon-reload > /dev/null 2>&1
  sudo systemctl enable openhab > /dev/null 2>&1
  sudo systemctl start openhab > /dev/null 2>&1
  kill -9 $SPIN_PID
}

installNodeRed() {
  if [[ "$VENDOR" == *"ARM"* ]]; then
    DISPLTEXT='ARM system detected'
    DISPLCOLOR=${YELLOW}
    echoInColor
    DISPLTEXT='Installing node-RED with dependencies'
    DISPLCOLOR=${YELLOW}
    echoInColor

    spin &
    SPIN_PID=$!
    trap "kill -9 $SPIN_PID" `seq 0 15`
  
    sudo apt install -y build-essential git curl nodejs npm> /dev/null 2>&1
    updateNodejs
    kill -9 $SPIN_PID
    bash <(curl -sL https://raw.githubusercontent.com/node-red/linux-installers/master/deb/update-nodejs-and-nodered)
    sudo systemctl enable nodered.service > /dev/null 2>&1
    sudo systemctl start nodered.service > /dev/null 2>&1
  else
    OS=$(lsb_release -a)
    if [[ "$OS" == *"ebian"* ]]; then
      DISPLTEXT='Debian system detected'
      DISPLCOLOR=${YELLOW}
      echoInColor
      DISPLTEXT='Installing node-RED with dependencies'
      DISPLCOLOR=${YELLOW}
      echoInColor

      spin &
      SPIN_PID=$!
      trap "kill -9 $SPIN_PID" `seq 0 15`

      sudo apt install -y build-essential git curl nodejs npm> /dev/null 2>&1
      updateNodejs
      kill -9 $SPIN_PID
	  
      bash <(curl -sL https://raw.githubusercontent.com/node-red/linux-installers/master/deb/update-nodejs-and-nodered)
      sudo systemctl enable nodered.service > /dev/null 2>&1
      sudo systemctl start nodered.service > /dev/null 2>&1

      kill -9 $SPIN_PID
    else
      # sudo apt-get install -y nodejs npm > /dev/null 2>&1
      # sudo npm install -g --unsafe-perm node-red
      DISPLTEXT='Could not install node-red. Please check https://nodered.org/docs/getting-started/local to install.'
      DISPLCOLOR=${YELLOW}
      echoInColor
    fi
  fi
}

checkMosquitto(){
  DISPLTEXT='-- Checking Mosquitto...'
  DISPLCOLOR=${YELLOW}
  echoInColor
  MOSQUITTO=$(cat /etc/mosquitto/mosquitto.conf 2>/dev/null)
  if [[ $MOSQUITTO != "" ]]; then
		DISPLTEXT='     - We have found an installation of Mosquitto.'
		DISPLCOLOR=${GREEN}
		echoInColor
  else
    read -p "$(echo -e $YELLOW"     - We didn't found an installation of Mosquitto. We reccomend using Mosquitto as MQTT server. Do you want us to install Mosquitto (1), use your own MQTT server (2) or continue without a MQTT server (3)? " $NC)" INSTMOS

	if [[ $INSTMOS == "2" ]]; then
		read -p "$(echo -e $GREEN"         -Please enter the ip address of your MQTT server:  " $NC)" MQTTIP
		read -p "$(echo -e $GREEN"         -Please enter the port of your MQTT server (1883):  " $NC)" MQTTPORT
	fi
	if [[ $INSTMOS == "3" ]]; then
   		DISPLTEXT='     - You choose to not install Mosquitto. The Qbus MQTT Gateway requires a MQTT server.'
		  DISPLCOLOR=${RED}
		  echoInColor
    fi
  fi
}

installMosquitto(){
	spin &
	SPIN_PID=$!
	trap "kill -9 $SPIN_PID" `seq 0 15`
 
	sudo apt-get install -y mosquitto > /dev/null 2>&1
  
	kill -9 $SPIN_PID
	
	DISPLTEXT='     -Enter a password for the MQTT server and repeat it: '
	DISPLCOLOR=${YELLOW}
	echoInColor
  
	sudo mosquitto_passwd -c /etc/mosquitto/pass $IUSER
 
 	spin &
	SPIN_PID=$!
	trap "kill -9 $SPIN_PID" `seq 0 15`
 
	echo '' | sudo tee -a /etc/mosquitto/mosquitto.conf > /dev/null 2>&1
	echo 'per_listener_settings true' | sudo tee -a /etc/mosquitto/mosquitto.conf > /dev/null 2>&1
	echo 'allow_anonymous false' | sudo tee -a /etc/mosquitto/mosquitto.conf > /dev/null 2>&1
	echo 'password_file /etc/mosquitto/pass' | sudo tee -a /etc/mosquitto/mosquitto.conf > /dev/null 2>&1
	sudo systemctl restart mosquitto > /dev/null 2>&1
	
	kill -9 $SPIN_PID
}

removeOpenHAB3(){
	spin &
	SPIN_PID=$!
	trap "kill -9 $SPIN_PID" `seq 0 15`
	
	sudo apt-get --assume-yes purge openhab > /dev/null 2>&1
	
	kill -9 $SPIN_PID
}

removeOpenHAB2(){
	spin &
	SPIN_PID=$!
	trap "kill -9 $SPIN_PID" `seq 0 15`
	
	sudo apt-get --assume-yes purge openhab2 > /dev/null 2>&1
	
	kill -9 $SPIN_PID
}

updateRpi(){
	spin &
	SPIN_PID=$!
	trap "kill -9 $SPIN_PID" `seq 0 15`
	
	sudo apt-get  --assume-yes update > /dev/null 2>&1
	
	kill -9 $SPIN_PID
}

cleanup() {
	sudo rm -r QbusMqtt-installer
	sudo rm -r qbusMqtt
}

# ============================== Start installation ==============================

DISPLCOLOR=${ORANGE}
DISPLTEXT='   ____  _               ___  __  __  ____ _______ _______ '
echoInColor
DISPLTEXT='  / __ \| |             |__ \|  \/  |/ __ \__   __|__   __|'
echoInColor
DISPLTEXT=' | |  | | |__  _   _ ___   ) | \  / | |  | | | |     | |   '
echoInColor
DISPLTEXT=' | |  | |  _ \| | | / __| / /| |\/| | |  | | | |     | |   '
echoInColor
DISPLTEXT=' | |__| | |_) | |_| \__ \/ /_| |  | | |__| | | |     | |   '
echoInColor
DISPLTEXT='  \___\_\_.__/ \__,_|___/____|_|  |_|\___\_\ |_|     |_|   '
echoInColor
DISPLTEXT=""
echoInColor
DISPLCOLOR=${NC}
DISPLTEXT="Release date 02/10/2023 by ks@qbus.be"
echoInColor
echo ''
DISPLTEXT="Welcome to the Qbus2MQTT installer."
echoInColor
echo ""

checkMosquitto
checkOH
checkNodeRed
checkSamba


read -p "$(echo -e $YELLOW"-Enter the username you want to use for the Qbus Client to connect to the MQTT server: "$NC)" IUSER

DISPLTEXT='-Enter the password you want to use for the Qbus Client to connect to the MQTT server: '
DISPLCOLOR=${YELLOW}
echoInColor

echo -e -n "$NC"
unset pass;
while IFS= read -r -s -n1 pass; do
  if [[ -z $pass ]]; then
     echo
     break
  else
     echo -n '*'
     PASSWORD+=$pass
  fi
done

DISPLTEXT='****************************************************************************************************************'
DISPLCOLOR=${ORANGE}
echoInColor

DISPLTEXT='* Everything is set, we will start the installation. As they say: Now it is time to relax and drink a coffee... *'
DISPLCOLOR=${ORANGE}
echoInColor

DISPLTEXT='****************************************************************************************************************'
DISPLCOLOR=${ORANGE}
echoInColor

echo ''

DISPLTEXT='* Updating your system.'
DISPLCOLOR=${YELLOW}
echoInColor
updateRpi

DISPLTEXT='* Installing dependencies.'
echoInColor
installDependencies

if [[ $INSTMOS == 1 ]]; then
  DISPLTEXT='* Installing Mosquitto.'
  echoInColor
  installMosquitto
fi

DISPLTEXT='* Installing Qbus MQTT Gateway.'
echoInColor
installQbusMqttGw

# Install openHAB
if [[ $OH2UPDATE == "y" ]]; then
	DISPLTEXT='* Making backup of openHAB...'
	DISPLCOLOR=${YELLOW}
	echoInColor
	backupOpenhabFiles
	DISPLTEXT='* Purging openHAB...'
	echoInColor
	removeOpenHAB2
	DISPLTEXT='* Install openHAB Stable (4.x.x)...'
	echoInColor
	installOpenhab4
	restoreOpenhabFiles
	sudo chown --recursive openhab:openhab /etc/openhab /var/lib/openhab /var/log/openhab /usr/share/openhab
	sudo chmod --recursive ug+wX /opt /etc/openhab /var/lib/openhab /var/log/openhab /usr/share/openhab
	echo ''
	DISPLTEXT='* Copy JAR file and restarting openHAB.'
	echoInColor
	copyJar
fi

if [[ $OH3UPDATE == "y" ]]; then
	DISPLTEXT='* Making backup of openHAB...'
	DISPLCOLOR=${YELLOW}
	echoInColor
	backupOpenhabFiles
	DISPLTEXT='* Purging openHAB...'
	echoInColor
	removeOpenHAB3
	DISPLTEXT='* Install openHAB Stable (4.x.x)...'
	echoInColor
	installOpenhab4
	restoreOpenhabFiles
	sudo chown --recursive openhab:openhab /etc/openhab /var/lib/openhab /var/log/openhab /usr/share/openhab
	sudo chmod --recursive ug+wX /opt /etc/openhab /var/lib/openhab /var/log/openhab /usr/share/openhab
	echo ''
	DISPLTEXT='* Copy JAR file and restarting openHAB.'
	echoInColor
	copyJar
fi

if [[ $OHINSTALL == "y" ]]; then
  # Install openHAB stable (4.x.x)
  DISPLTEXT='* Install openHAB Stable (4.x.x)...'
  DISPLCOLOR=${YELLOW}
  echoInColor
  installOpenhab4
  sudo chown --recursive openhab:openhab /etc/openhab /var/lib/openhab /var/log/openhab /usr/share/openhab
  sudo chmod --recursive ug+wX /opt /etc/openhab /var/lib/openhab /var/log/openhab /usr/share/openhab
  echo ''
  DISPLTEXT='* Copy JAR file and restarting openHAB.'
  echoInColor
  copyJar
fi

# Install node-RED
if [[ $INSTNR == "y" ]]; then
  DISPLTEXT='* Install node-RED...'
  DISPLCOLOR=${YELLOW}
  echoInColor
  installNodeRed
  copyNodeRedQbus
  echo ''
else
  copyNodeRedQbus
  sudo systemctl restart nodered.service > /dev/null 2>&1
  echo ''
fi

# Install SMB
if [[ $INSTSAMBA == "y" ]]; then
	DISPLTEXT='* Install SMB...'
	echoInColor
	installSamba
	DISPLTEXT='- Enter a password for the SMB share for the user openhab & repeat it (attention: the password will not be shown): '
	echoInColor
	sudo smbpasswd -a openhab
	echo ''
fi

# Finishing installation
cleanup
DISPLTEXT='The installation is finished now. To make sure everything is set up correctly and to avoid problems, we suggest to do a reboot.'
echoInColor

echo ''

read -p "$(echo -e $YELLOW"Do you want to reboot now? (y/n) " $NC)" REBOOT

if [[ $REBOOT == "y" ]]; then
	DISPLTEXT='Rebooting the system...'
	echoInColor
	sudo reboot
else
	DISPLTEXT='You choose to not reboot your system. If you run into problems, first trys to reboot!'
	echoInColor
	DISPLTEXT='We did a Clean Cache for openHAB. Please be patient and give openHAB some time to enable the bindings.'
	echoInColor
	exit 0
fi

