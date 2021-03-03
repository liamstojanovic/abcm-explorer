#!/bin/bash
cd ~/
progress_bar=0
ubuntu_version=""

# Verify script has been invoked as root user
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root." 
   exit 1
fi
#Check for version of ubuntu
if [[ $(lsb_release -rs) == "18.04" ]]; then 
       echo "Compatible version. Proceeding."
       ubuntu_version=$(lsb_release -rs)
elif [[ $(lsb_release -rs) == "16.04" ]]; then
       echo "Compatible version. Proceeding."
       ubuntu_version=$(lsb_release -rs) 
else
       echo "Non-compatible version of Ubuntu. Exiting..."
       exit 1
fi

# Update time. Wrong date/time will cause issues with repositories.
apt-get install ntpdate
ntpdate 0.pool.ntp.org
ntpdate 1.pool.ntp.org

#System update
apt-get update
apt-get -y upgrade

printf "\n"
sleep 5
printf "System has been successfully updated.\n\n"

#Check if git is installed. If not, install via apt
printf "Checking to see if git is installed...\n"
if [ $(dpkg-query -W -f='${Status}' git 2>/dev/null | grep -c "ok installed") -eq 0 ];
then
  apt -y install git;
  printf "Git has been installed."
fi

sleep 5
printf "\n\n"
printf "We are now installing the dependencies required to build abcmint."
sleep 5
#abcm_dependencies_headless = "make g++ build-essential libboost-all-dev libssl-dev libdb++-dev libminiupnpc-dev"
apt-get -y install make g++ build-essential libboost-all-dev libssl-dev libdb++-dev libminiupnpc-dev

printf "Global env is now ready for abc build.\n\n"
sleep 5

#Install Nodejs
printf "Installing nodejs..."
curl -sL https://deb.nodesource.com/setup_13.x | sudo -E bash -
apt-get install -y nodejs

#Install MongoDB
printf "\n\n Installing mongodb..."
wget -qO - https://www.mongodb.org/static/pgp/server-4.2.asc | apt-key add -
#Determine version and add appropriate repository
if [ "$ubuntu_version" == "20.04" ]; then
  echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.2 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.2.list
elif [ "$ubuntu_version" == "18.04" ]; then
  echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.2 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.2.list
elif [ "$ubuntu_version" == "16.04" ]; then
  echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/4.2 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.2.list
else
  echo "This version of Linux is not compatible with the installer's dependencies. Exiting..."
  exit 1
fi
apt update
apt install -y mongodb-org=4.2.3 mongodb-org-server=4.2.3 mongodb-org-shell=4.2.3 mongodb-org-mongos=4.2.3 mongodb-org-tools=4.2.3
# Forbid package manager from updating mongo
echo "mongodb-org hold" | dpkg --set-selections
echo "mongodb-org-server hold" | dpkg --set-selections
echo "mongodb-org-shell hold" | dpkg --set-selections
echo "mongodb-org-mongos hold" | dpkg --set-selections
echo "mongodb-org-tools hold" | dpkg --set-selections

echo "Enabling MongoDB at startup..."
systemctl daemon-reload
systemctl start mongod
systemctl enable mongod

exit 0