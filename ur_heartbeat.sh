#!/bin/bash

target_mail=andoko@mundio.com

subject_mail=$(echo $(date +%F) "-" $(date +%T) "SIPp Heartbeat OK")

echo "-" | mail -s "$subject_mail" $target_mail