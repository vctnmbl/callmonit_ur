#!/usr/bin/env bash

# ======================= Provisioning crontab ==============================
echo "* * * * * /vagrant/ur_uac.sh" > mycron.tmp
echo "*/60 * * * * /vagrant/ur_heartbeat.sh" >> mycron.tmp
sudo crontab mycron.tmp
sudo rm mycron.tmp

echo "==> OK"
sudo crontab -l
