#!/bin/bash

# ============================== Define variables ==============================
USER=''
PASSWORD=''
MQTTIP='localhost'
MQTTPORT='1883'
MOSQUITTO=''
INSTMOS=''
OH=''
OH2=''
OH3=''
OH3V=''
DISPLTEXT=''
DISPLCOLOR=''

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

	sudo apt-get install -y tftp > /dev/null 2>&1
	
	
	kill -9 $SPIN_PID
}





installQbusMqttGw(){
	spin &
	SPIN_PID=$!
	trap "kill -9 $SPIN_PID" `seq 0 15`
	
	git clone https://github.com/QbusKoen/qbusMqtt > /dev/null 2>&1
	tar -xf qbusMqtt/qbusMqtt/qbusMqttGw-arm.tar > /dev/null 2>&1
	sudo mkdir /usr/bin/qbus > /dev/null 2>&1
	sudo mkdir /opt/qbus > /dev/null 2>&1
	sudo mkdir /var/log/qbus > /dev/null 2>&1
	sudo cp -R qbusMqtt/qbusMqtt/qbusMqttGw-arm/fw/ /opt/qbus/ > /dev/null 2>&1
	sudo cp qbusMqtt/qbusMqtt/qbusMqttGw-arm/puttftp /opt/qbus/ > /dev/null 2>&1
	sudo cp qbusMqtt/qbusMqtt/qbusMqttGw-arm/qbusMqttGw /usr/bin/qbus/ > /dev/null 2>&1
	echo '[Unit]' | sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	echo 'Description=MQTT client for Qbus communication' | sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	echo 'After=user.target networking.service' | sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	echo '' | sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	echo '[Service]' | sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	echo 'Type=simple' | sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	echo 'ExecStart= /usr/bin/qbus/qbusMqttGw/./qbusMqttGw -serial="QBUSMQTTGW" -logbuflevel -1 -log_dir /var/log/qbus -max_log_size=10 -storagedir /opt/qbus -mqttbroker "tcp://'$MQTTIP':'$MQTTPORT'" -mqttuser '$USER' -mqttpassword '$PASSWORD''| sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	echo 'PIDFile=/var/run/qbusmqttgw.pid' | sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	echo 'Restart=on-failure' | sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	echo 'RemainAfterExit=no' | sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	echo 'RestartSec=5s' | sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	echo '' | sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	echo '[Install]' | sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	echo 'WantedBy=multi-user.target' | sudo tee -a /lib/systemd/system/qbusmqtt.service > /dev/null 2>&1
	# Create directory for logging
	LOG=$(cat /etc/logrotate.d/qbus 2>/dev/null)
	if [[ $LOG != "" ]]; then
		sudo mkdir /var/log/qbus/ > /dev/null 2>&1
		sudo touch /etc/logrotate.d/qbus > /dev/null 2>&1
		echo '/var/log/qbus/*.log {' | sudo tee -a /etc/logrotate.d/qbus > /dev/null 2>&1
		echo '        daily' | sudo tee -a /etc/logrotate.d/qbus > /dev/null 2>&1
		echo '        rotate 7' | sudo tee -a /etc/logrotate.d/qbus > /dev/null 2>&1
		echo '        size 10M' | sudo tee -a /etc/logrotate.d/qbus > /dev/null 2>&1
		echo '        compress' | sudo tee -a /etc/logrotate.d/qbus > /dev/null 2>&1
		echo '        delaycompress' | sudo tee -a /etc/logrotate.d/qbus > /dev/null 2>&1
	fi
 
	kill -9 $SPIN_PID
}

checkOH(){
  DISPLTEXT='-- Checking openHAB...'
  DISPLCOLOR=${YELLOW}
  echoInColor
	OH2=$(ls /usr/share/openhab2 2>/dev/null)
	OH3=$(ls /usr/share/openhab 2>/dev/null)

	if [[ $OH2 != "" ]]; then
	  # OH2 found
	  OH="OH2"
    read -p "$(echo -e $YELLOW"     -We have detected openHAB2 running on your device. The Qbus Binding is developped for the newest version of openHAB (3). Do you agree that we remove openHAB2 and install openHAB3? (y/n)? " $NC)" OH2UPDATE

	elif [[ $OH3 != "" ]]; then
	  # OH3 found, checking release
	  OH3V=$(cat /etc/apt/sources.list.d/openhab.list)
	  if [[ $OH3V =~ "unstable" ]]; then
  		DISPLTEXT='     -We have detected openHAB running the snapshot (3.2.0-SNAPSHOT) version. The Qbus Binding is included in this version, but does not work with MQTT. We will copy a JAR file to your current installation. After the installation process, you will need to remove the released Binding if installed. Keep in mind that this binding also works with the stable version.'
  		DISPLCOLOR=${GREEN}
  		echoInColor
	  elif [[ $OH3V =~ "testing" ]]; then
  		DISPLTEXT='     -We have detected openHAB running the milestone (3.2.0Mx) version. The Qbus Binding is included in this version, but does not work with MQTT. We will copy a JAR file to your current installation. After the installation process, you will need to remove the released Binding if installed. Keep in mind that this binding also works with the stable version.'
  		DISPLCOLOR=${GREEN}
  		echoInColor
	  elif [[ $OH3V =~ "stable" ]]; then
  		DISPLTEXT='     -We have detected openHAB running the stable (3.1.0) version. The Qbus Binding is included in this version, but does not work with MQTT. We will copy a JAR file to your current installation. After the installation process, you will need to remove the released Binding if installed.'
  		DISPLCOLOR=${GREEN}
  		echoInColor
	  fi
	else
		read -p "$(echo -e $YELLOW"     -We did not detected openHAB running on your system. Do you want to install openHAB? ' (y/n)? " $NC)" OHINSTALL

	fi
}

backupOpenhabFiles(){
	if [[$OH="OH2"]]; then
			sudo cp -R /etc/openhab2 /tmp/ > /dev/null 2>&1
	else
			sudo cp -R /etc/openhab /tmp/ > /dev/null 2>&1
	fi
}

restoreOpenhabFiles(){
	if [[$OH="OH2"]]; then
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
	
	sudo rm /usr/share/openhab/addons/org.openhab.binding.qbus* 
	sudo cp qbusMqtt/openHAB/org.openhab.binding.qbus-3.2.0-SNAPSHOT.jar /usr/share/openhab/addons/ 
	sudo chown openhab:openhab  /usr/share/openhab/addons/org.openhab.binding.qbus-3.2.0-SNAPSHOT.jar
	
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
  	read -p "$(echo -e $YELLOW"     -We did not detect Samba Share on your system. You don not really need SMB, but it makes it easier to configure certain openHAB things. Do you agree to install Samba share (y/n)? " $NC)" INSTSAMBA
          
  	if [[ $INSTSAMBA == "n" ]]; then
  		DISPLTEXT='     -You choose not to install Samba Share. This means you have to configure certain openHAB things on this device.'
  		DISPLCOLOR=${RED}
  		echoInColor
  	fi
  fi
}

installSamba(){
	spin &
	SPIN_PID=$!
	trap "kill -9 $SPIN_PID" `seq 0 15`
	
	sudo apt-get --assume-yes install samba samba-common-bin
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

installOpenhab3(){
	spin &
	SPIN_PID=$!
	trap "kill -9 $SPIN_PID" `seq 0 15`
	
	sudo apt-get install apt-transport-https > /dev/null 2>&1
	wget -qO - 'https://openhab.jfrog.io/artifactory/api/gpg/key/public' | sudo apt-key add - > /dev/null 2>&1
	sudo rm /etc/apt/sources.list.d/openhab.list > /dev/null 2>&1
	echo 'deb https://openhab.jfrog.io/artifactory/openhab-linuxpkg stable main' | sudo tee /etc/apt/sources.list.d/openhab.list > /dev/null 2>&1
	sudo apt-get --assume-yes update && sudo apt-get --assume-yes install openhab > /dev/null 2>&1
	
	kill -9 $SPIN_PID
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
  
	sudo mosquitto_passwd -c /etc/mosquitto/pass $USER
 
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
	sudo rm -r qbusMqtt
	sudo rm -r QbusMqtt-Installer
	sudo rm -r qbusMqttGw-arm
}

# ============================== Start installation ==============================

DISPLCOLOR=${ORANGE}
DISPLTEXT='   ____  _                 ___                           _    _          ____  '
echoInColor
DISPLTEXT='  / __ \| |               |__ \                         | |  | |   /\   |  _ \ '
echoInColor
DISPLTEXT=" | |  | | |__  _   _ ___     ) |   ___  _ __   ___ _ __ | |__| |  /  \  | |_) |"
echoInColor
DISPLTEXT=" | |  | | '_ \| | | / __|   / /   / _ \| '_ \ / _ \ '_ \|  __  | / /\ \ |  _ < "
echoInColor
DISPLTEXT=" | |__| | |_) | |_| \__ \  / /_  | (_) | |_) |  __/ | | | |  | |/ ____ \| |_) |"
echoInColor
DISPLTEXT="  \___\_\_.__/ \__,_|___/ |____|  \___/| .__/ \___|_| |_|_|  |_/_/    \_\____/ "
echoInColor
DISPLTEXT="                                       | |                                     "
echoInColor
DISPLTEXT="                                       |_|                                     "
echoInColor
DISPLTEXT=""
echoInColor
DISPLCOLOR=${NC}
DISPLTEXT="Release date 30/11/2021 by ks@qbus.be"
echoInColor
echo ''
DISPLTEXT="Welcome to the Qbus2openHAB (MQTT version) installer."
echoInColor
echo ""




checkOH
checkMosquitto
checkSamba


read -p "$(echo -e $YELLOW"-Enter the username you want to use for the Qbus Client to connect to the MQTT server: "$NC)" USER

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
  # Upgrade from openHAB2 to openHAB stable (3.1.0)
  DISPLTEXT='* Making backup of openHAB2...'
	echoInColor
  backupOpenhabFiles
	DISPLTEXT='* Purging openHAB...'
	echoInColor
	removeOpenHAB2
	DISPLTEXT='* Install openHAB Stable (3.1.0)...'
	echoInColor
	installOpenhab3
	restoreOpenhabFiles
	copyJar
	sudo chown --recursive openhab:openhab /etc/openhab /var/lib/openhab /var/log/openhab /usr/share/openhab
	sudo chmod --recursive ug+wX /opt /etc/openhab /var/lib/openhab /var/log/openhab /usr/share/openhab
	echo ''
fi

if [[ $OHINSTALL == "y" ]]; then
  # Install openHAB stable (3.1.0)
	DISPLTEXT='* Install openHAB Stable (3.1.0)...'
	echoInColor
	installOpenhab3
	copyJar
	sudo chown --recursive openhab:openhab /etc/openhab /var/lib/openhab /var/log/openhab /usr/share/openhab
	sudo chmod --recursive ug+wX /opt /etc/openhab /var/lib/openhab /var/log/openhab /usr/share/openhab
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
fi

