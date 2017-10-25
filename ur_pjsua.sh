#!/bin/bash

#-----------------------------------------------------------------------
# Get the parameters from INI file
ini_file=/vagrant/ur_callmonit.ini

# The extension number to call to for testing
target_number=$(crudini --get $ini_file '' target_number)
if [ $target_number"empty" = "empty" ]; then
    echo "Error: Parameter 'target_number' is not defined in file: '"$ini_file"'"
	exit 99
fi

# The extension number to call to for testing
target_password=$(crudini --get $ini_file '' target_password)
if [ $target_password"empty" = "empty" ]; then
    echo "Error: Parameter 'target_password' is not defined in file: '"$ini_file"'"
	exit 99
fi

#-----------------------------------------------------------------------

/home/vagrant/pjproject-2.7/pjsip-apps/bin/pjsua-x86_64-unknown-linux-gnu \
    --local-port=5068 \
    --id sip:$target_number"@5901.ur.mundio.com" \
    --registrar sip:5901.ur.mundio.com \
    --proxy sip:5901.ur.mundio.com \
    --realm \* \
    --username $target_number \
    --password $target_password \
    --auto-answer 200 \
    --auto-loop \
    --duration=1200 \
    --app-log-level=3 \
    --log-level=3 \
    --null-audio \

#    --auto-play \
#    --play-file=/vagrant/file02.wav \
#    --playback-dev=0 \
#    --dis-codec=speex/16000 \
#    --dis-codec=speex/8000 \
#    --dis-codec=speex/32000 \
#    --dis-codec=iLBC/8000 \
#    --dis-codec=GSM/8000 \
#    --dis-codec=G722/16000 \

#    --log-file=/vagrant/pjsua.log \

#    --dis-codec=L16/44100 \
#    --dis-codec=L16/44100 \
   
#    
#    --capture-dev=-1 \
#    --auto-loop \ 


#List of audio codecs:
#    --dis-codec=PCMU/8000 
#    --dis-codec=PCMA/8000 
