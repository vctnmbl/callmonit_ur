#!/usr/bin/env bash

# ======================= Provisioning crontab ==============================
echo "* * * * * ( /vagrant/test01.sh ) " > mycron.tmp
echo "* * * * * ( sleep 10 ; /vagrant/test01.sh ) " >> mycron.tmp
echo "* * * * * ( sleep 20 ; /vagrant/test01.sh ) " >> mycron.tmp
echo "* * * * * ( sleep 30 ; /vagrant/test01.sh ) " >> mycron.tmp
echo "* * * * * ( sleep 40 ; /vagrant/test01.sh ) " >> mycron.tmp
echo "* * * * * ( sleep 50 ; /vagrant/test01.sh ) " >> mycron.tmp
echo "*/60 * * * * /vagrant/ur_heartbeat.sh" >> mycron.tmp

sudo crontab mycron.tmp
sudo rm mycron.tmp

echo "==> OK"
sudo crontab -l
