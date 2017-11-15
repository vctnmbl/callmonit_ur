#!/usr/bin/env bash

sudo nmcli con add type ethernet con-name MyVagrant0 ifname eth0 ip4 10.0.2.15/24 gw4 10.0.2.2
sudo nmcli con mod MyVagrant0 ipv4.dns '8.8.8.8 8.8.4.4'
sudo nmcli con up MyVagrant0

sudo yum -y update

# sudo bash -c "echo 'nameserver 8.8.8.8' > /etc/resolv.conf"

sudo timedatectl set-timezone Europe/London

echo "XXX START of the script" > /vagrant/provision-script.log 2>&1

# ======================= Provisioning Packages  ==============================
# wget -c https://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-10.noarch.rpm >> /vagrant/provision-script.log 2>&1
#sudo rpm -ivh epel-release-7-10.noarch.rpm >> /vagrant/provision-script.log 2>&1
sudo yum -y install epel-release
sudo yum repolist

# ======================= Provisioning various tools ==============================
sudo yum install -y wget >> /vagrant/provision-script.log 2>&1
# sudo yum install -y net-tools >> /vagrant/provision-script.log 2>&1
sudo yum install -y sharutils >> /vagrant/provision-script.log 2>&1
sudo yum install -y git >> /vagrant/provision-script.log 2>&1
sudo yum install -y crudini >> /vagrant/provision-script.log 2>&1
sudo yum install -y mutt >> /vagrant/provision-script.log 2>&1

# ======================= SNMP ==============================

sudo yum -y install net-snmp net-snmp-utils
sudo sed -i.bak 's/.1.3.6.1.2.1.1/.1.3.6.1/' /etc/snmp/snmpd.conf   # correction for PRTG
sudo service snmpd restart # Restart
sudo chkconfig snmpd on  # start on booting


# ======================= Provisioning SIPp ==============================
echo "XXX PROVISIONING SIPp..."
yum install -y make gcc gcc-c++ ncurses ncurses.x86_64 ncurses-devel ncurses-devel.x86_64 openssl libnet libpcap libpcap-devel libpcap.x86_64 libpcap-devel.x86_64 gsl gsl-devel >> /vagrant/provision-script.log 2>&1

yum install -y openssl-devel.i686 >> /vagrant/provision-script.log 2>&1
yum install -y lksctp* >> /vagrant/provision-script.log 2>&1
yum install -y lksctp-tools-devel.i686 -y >> /vagrant/provision-script.log 2>&1


wget https://github.com/SIPp/sipp/releases/download/v3.5.1/sipp-3.5.1.tar.gz >> /vagrant/provision-script.log 2>&1
tar zvxf sipp-3.5.1.tar.gz >> /vagrant/provision-script.log 2>&1

cd /home/vagrant/sipp-3.5.1
sudo ./configure --with-sctp --with-pcap >> /vagrant/provision-script.log 2>&1

make >> /vagrant/provision-script.log 2>&1

cd /home/vagrant/

# ======================= Provision PJSIP ==============================

sudo yum install -y alsa-lib-devel alsa-lib  >> /vagrant/provision-script.log 2>&1
sudo yum install -y jack-audio-connection-kit >> /vagrant/provision-script.log 2>&1
sudo yum install -y jack-audio-connection-kit-devel >> /vagrant/provision-script.log 2>&1
sudo yum install -y pulseaudio-libs-devel  

wget http://www.pjsip.org/release/2.7/pjproject-2.7.tar.bz2  >> /vagrant/provision-script.log 2>&1
tar jvxf pjproject-2.7.tar.bz2  >> /vagrant/provision-script.log 2>&1

cd /home/vagrant/pjproject-2.7
sudo ./configure  >> /vagrant/provision-script.log 2>&1
sudo make dep  >> /vagrant/provision-script.log 2>&1
sudo make clean  >> /vagrant/provision-script.log 2>&1
sudo make  >> /vagrant/provision-script.log 2>&1
sudo make install >> /vagrant/provision-script.log 2>&1

/home/vagrant/pjproject-2.7/pjsip-apps/bin/pjsua-x86_64-unknown-linux-gnu -version >> /vagrant/provision-script.log 2>&1

cd /home/vagrant/

# ======================= Provision Fetchmail ==============================

sudo yum install -y fetchmail
sudo yum install -y procmail

echo "|/usr/bin/procmail" > /home/vagrant/.forward
chown vagrant:vagrant /home/vagrant/.forward

#--- .fetchmailrc file

echo set no bouncemail > /home/vagrant/.fetchmailrc
echo poll imap.gmail.com proto IMAP user \"mundiomobile@gmail.com\" is vagrant here pass \"super99man\" ssl folder 'URM'  >> /home/vagrant/.fetchmailrc
echo mda \"/usr/bin/procmail -d \%T\"  >> /home/vagrant/.fetchmailrc

# echo # set daemon 10 > /home/vagrant/.fetchmailrc
# echo # set logfile /home/vagrant/fetchmail.log  > /home/vagrant/.fetchmailrc
# echo # poll pop.gmail.com proto POP3 auth password no dns user "mundiomobile@gmail.com" pass "super99man" is vagrant keep ssl

chmod 700 /home/vagrant/.fetchmailrc
chown vagrant:vagrant /home/vagrant/.fetchmailrc

# ---- .procmailrc file
echo SHELL=/bin/bash > /home/vagrant/.procmailrc
echo PATH=/usr/sbin:/usr/bin >> /home/vagrant/.procmailrc
echo MAILDIR=\$HOME/Maildir/ >> /home/vagrant/.procmailrc
echo DEFAULT=\$MAILDIR >> /home/vagrant/.procmailrc
echo LOGFILE=\$HOME/.procmail.log >> /home/vagrant/.procmailrc
echo LOG="" >> /home/vagrant/.procmailrc
echo VERBOSE=yes >> /home/vagrant/.procmailrc

chown vagrant:vagrant /home/vagrant/.procmailrc

mkdir /home/vagrant/Maildir
mkdir /home/vagrant/Maildir/cur
mkdir /home/vagrant/Maildir/new
mkdir /home/vagrant/Maildir/tmp


# ======================= Wrapping ==============================

echo "ERROR LOG:" > /vagrant/provision-error.log
grep -in "error" /vagrant/provision-script.log >> /vagrant/provision-error.log
echo "XXX DONE - Check /vagrant/provision-script.log AND /vagrant/provision-error.log"

echo set from=\"UR-Monitor \<noreply@unifiedring\>\" > /home/vagrant/.muttrc
sudo cp /home/vagrant/.muttrc /root/
chown vagrant:vagrant /home/vagrant/.muttrc



mutt -s "A Vagrant box has just been provisioned." -a /vagrant/provision-script.log -- andoko@mundio.com < /vagrant/provision-error.log


