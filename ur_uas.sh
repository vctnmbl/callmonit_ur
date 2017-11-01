#!/bin/bash

clear

# Server side, to receive calls

#-----------------------------------------------------------------------
# Get the parameters from INI file

# INI file    
ini_file=/vagrant/ur_callmonit.ini

domain=$(crudini --get $ini_file 'target' domain)
if [ $domain"empty" = "empty" ]; then
    echo ERROR: \"domain\" parameter is not defined in \"$ini_file\"
    exit 99
fi

receiver=$(crudini --get $ini_file 'target' receiver)
if [ $receiver"empty" = "empty" ]; then
    echo ERROR: \"receiver\" parameter is not defined in \"$ini_file\"
    exit 99
fi

password=$(crudini --get $ini_file 'target' password)
if [ $password"empty" = "empty" ]; then
    echo ERROR: \"password\" parameter is not defined in \"$ini_file\"
    exit 99
fi

echo "================================================="
echo "= UAS - Call Receiver                           ="
echo "= Receiver: "$receiver"@"$domain
echo "================================================="

# read -p "Press [Enter] key to continue to PJSUA..." key

#-----------------------------------------------------------------------

/home/vagrant/pjproject-2.7/pjsip-apps/bin/pjsua-x86_64-unknown-linux-gnu \
    --local-port=5068 \
    --id sip:$receiver"@"$domain \
    --registrar sip:$domain \
    --proxy sip:$domain \
    --realm \* \
    --username $receiver \
    --password $password \
    --auto-answer 200 \
    --auto-loop \
    --duration=1200 \
    --app-log-level=3 \
    --log-level=4 \
    --null-audio \

#    --log-file=/vagrant/pjsua.log \
#    --auto-play \
#    --play-file=/vagrant/file02.wav \
#    --playback-dev=0 \
#    --dis-codec=speex/16000 \
#    --dis-codec=speex/8000 \
#    --dis-codec=speex/32000 \
#    --dis-codec=iLBC/8000 \
#    --dis-codec=GSM/8000 \
#    --dis-codec=G722/16000 \



#    --dis-codec=L16/44100 \
#    --dis-codec=L16/44100 \
   
#    
#    --capture-dev=-1 \
#    --auto-loop \ 


#List of audio codecs:
#    --dis-codec=PCMU/8000 
#    --dis-codec=PCMA/8000 
