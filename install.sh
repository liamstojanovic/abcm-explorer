#!/bin/bash
current_dir=$PWD
current_user=$USER
explorer_dir=""
abcm_dir =""

# Verify the installer has NOT been invoked as root user
if [[ $EUID == 0 ]]; then
   echo "Do not run this script as a root user!" 
   exit 1
fi

printf "Welcome to the ABCMint explorer server deployer!\n"
printf "This script has been tested for Ubuntu 18.04 server.\n"
printf "To ensure there are no package conflicts, it is recommended to run this script on a fresh install.\n"
printf "First we will check that our prerequisite packages are installed.\n"
read -p "Press enter to continue..."

sudo nohup bash dependencies.sh > dependencies.log &
dependencies_pid=$!
printf "\nThe installer is running, with a PID of ${dependencies_pid}."
printf "\nOnce this process is completed, the environment will be initialized.\n"
wait $dependencies_pid
# Check if exit status was non-zero. 
retVal=$?
if [ $retVal -ne 0 ]; then
    echo "Installing dependencies failed. Check the dependencies.log file for more information."
    exit 1
fi

read -p "Two directories will be generated in the abc-explorer directory: abcmint, and explorer. Press enter to continue..."
cd $current_dir

#Clone repositories
git clone https://github.com/abcmint/abcmint.git
git clone https://github.com/iquidus/explorer.git

#Build ABCmint
printf "\n\nBuilding ABCMint... This may take a while."
sleep 5
cd $current_dir/abcmint/src
make -f makefile.unix

# cp the config file (abcmint.conf) to the .abc directory
mkdir ~/.abc
cd $current_dir
cp config/abcmint.conf ~/.abc/abcmint.conf

#Run ABCMint
printf "\nStarting ABCMint, waiting for blockchain to be read..."
cd $current_dir/abcmint/src
abcm_dir = $PWD
./abcmint -txindex=1 -server -daemon
sleep 360

#Use mongoDB CLI to create default database and user.
cd $current_dir
mongo < config/mongo_init.js

#Install node modules
cd ~/
cd explorer 
explorer_dir=$PWD
npm install --production

# cp the settings.json file into the explorer directory.
cd $current_dir
cp config/settings.json $explorer_dir/settings.json

# Create a systemctl entry for Iquidus
cp config/systemd.service config/systemd.service.copy
sed -i -e "s|WORKINGDIRECTORYVAR|$explorer_dir|g" config/systemd.service.copy
sed -i -e "s|USERVAR|$USER|g" config/systemd.service.copy
sudo cp config/systemd.service.copy /etc/systemd/system/iquidus.service

# Create a systemctl entry for ABCmint
cp config/abcm.service config/abcm.service.copy
sed -i -e "s|WORKINGDIRECTORYVAR|$abcm_dir|g"  config/abcm.service.copy
sed -i -e "s|USERVAR|$USER|g" config/abcm.service.copy
sudo cp config/abcm.service.copy /etc/systemd/system/abcm.service


# Enable the ABCM and Iquidus service at Startup
sudo systemctl enable iquidus
sudo systemctl enable abcm


# Create crontab entries for Iquidus explorer node scripts
(crontab -l 2>/dev/null; echo "*/1 * * * * cd $explorer_dir && /usr/bin/nodejs scripts/sync.js index update > /dev/null 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "*/5 * * * * cd $explorer_dir && /usr/bin/nodejs scripts/peers.js > /dev/null 2>&1") | crontab -
