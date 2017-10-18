#!/usr/bin/env bash

sudo yum -y update

sudo echo "nameserver 8.8.8.8" >> /etc/resolv.conf

sudo timedatectl set-timezone Europe/London

echo "XXX START of the script" > /vagrant/provision-script.log 2>&1

# ======================= Provisioning Packages  ==============================
# wget -c https://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-10.noarch.rpm >> /vagrant/provision-script.log 2>&1
#sudo rpm -ivh epel-release-7-10.noarch.rpm >> /vagrant/provision-script.log 2>&1
sudo yum -y install epel-release
sudo yum repolist

# ======================= Provisioning various tools ==============================
sudo yum install -y wget >> /vagrant/provision-script.log 2>&1
sudo yum install -y net-tools >> /vagrant/provision-script.log 2>&1
sudo yum install -y sharutils >> /vagrant/provision-script.log 2>&1
# sudo yum install -y git >> /vagrant/provision-script.log 2>&1
sudo yum install -y crudini >> /vagrant/provision-script.log 2>&1
sudo yum install -y mutt >> /vagrant/provision-script.log 2>&1

# ======================= Provisioning SIPp ==============================
echo "XXX PROVISIONING SIPp..."
yum install -y make gcc gcc-c++ ncurses ncurses.x86_64 ncurses-devel ncurses-devel.x86_64 openssl libnet libpcap libpcap-devel libpcap.x86_64 libpcap-devel.x86_64 gsl gsl-devel >> /vagrant/provision-script.log 2>&1

yum install -y openssl-devel.i686 >> /vagrant/provision-script.log 2>&1
yum install -y lksctp* >> /vagrant/provision-script.log 2>&1
yum install -y lksctp-tools-devel.i686 -y >> /vagrant/provision-script.log 2>&1


wget https://github.com/SIPp/sipp/releases/download/v3.5.1/sipp-3.5.1.tar.gz >> /vagrant/provision-script.log 2>&1
tar zvxf sipp-3.5.1.tar.gz >> /vagrant/provision-script.log 2>&1

cd sipp-3.5.1 >> /vagrant/provision-script.log 2>&1
sudo ./configure --with-sctp --with-pcap >> /vagrant/provision-script.log 2>&1

make >> /vagrant/provision-script.log 2>&1


# ======================= Provisioning SIPp ==============================

echo "ERROR LOG:" > /vagrant/provision-error.log
grep -in "error" /vagrant/provision-script.log >> /vagrant/provision-error.log
echo "XXX DONE - Check /vagrant/provision-script.log AND /vagrant/provision-error.log"

mutt -s "A Vagrant box has just been provisioned." -a /vagrant/provision-script.log -- andoko@mundio.com < /vagrant/provision-error.log

