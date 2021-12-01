# QbusMqtt-installer

This script will install everything as descibed on https://github.com/QbusKoen/qbusMqtt
It uses the arm version of the Qbus Mqtt Gateway. If you're installing on another Linux platform change lines 85, 89, 90 and 91 with the correct versions.

## Install
To run this script on your device, first make sure you've got git installed:
```
sudo apt-get install git
```

Then download this repo:
```
git clone https://github.com/QbusKoen/QbusMqtt-installer
```

Make the installer executable:
```
chmod +x QbusMqtt-installer/install.sh
```

Finnaly, run the installer:
```
QbusMqtt-installer/./install.sh
```
