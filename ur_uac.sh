#!/bin/bash

#-----------------------------------------------------------------------
# Get the parameters from INI file
ini_file=/vagrant/ur_uac.ini

target_number=$(crudini --get $ini_file '' target_number)
if [ $target_number"empty" = "empty" ]; then
    echo "Error: Parameter 'target_number' is not defined in file: '"$ini_file"'"
	exit 99
fi

target_mail=$(crudini --get $ini_file '' target_mail)
if [[ $target_mail"empty" == "empty" ]]; then
    echo "Error: Parameter 'target_mail' is not defined in file: '"$ini_file"'"
	exit 99
fi
#-----------------------------------------------------------------------

sipp_script=/vagrant/ur_uac.xml
now_date=$(date +%Y%m%d)
log_date=$(date +%F" "%R)

log_directory=/vagrant/

call_filename=$log_directory"call.log"
curr_err_file=$log_directory"error.log"

errtmp_filename=$log_directory"error.tmp"

var_file=$log_directory"ur_call.tmp"
body_email=$log_directory"email_body.tmp"
credential_file=$log_directory"ur_uac.csv"

# Number of times of succesfull test that the service is deemed to be restored
restored_counter=5

# The local IP addressof this machine
machine_ip=10.0.2.15

#-----------------------------------------------------------------------
# Init report file names

now_hour=$(echo $(date +%H) | sed 's/^0//g')
# now_hour=0

let prd_start=$(echo $now_hour/3)*3
prd_start=$(printf "%02d\n" $prd_start)

let prd_end=$(echo $(echo $now_hour/3)+1)
let prd_end=$prd_end*3
prd_end=$(printf "%02d\n" $prd_end)

cal_log=$(echo $log_directory"ur_cal_"$now_date"_"$prd_start"_"$prd_end".log")
err_log=$(echo $log_directory"ur_err_"$now_date"_"$prd_start"_"$prd_end".log")
rpt_log=$(echo $log_directory"ur_rpt_"$now_date"_"$prd_start"_"$prd_end".log")

#-----------------------------------------------------------------------
# Create a body email to send
function email_body {

	if [ $error_end"empty" = "empty" ]; then
		printf "ERROR\n=====\n"> $body_email
		echo "Error start: "$error_start >> $body_email
	else
		printf "Service Restored\n================\n" > $body_email
		echo "Error start: "$error_start >> $body_email
		echo "Error end  : "$error_end >> $body_email
	fi
	
	echo "Destination: "$target_number >> $body_email
	printf "\n\nCall Log\n========\n" >> $body_email
	cat $call_filename >> $body_email
	printf "\n\nError Log\n==============================================================\n" >> $body_email
	cat $curr_err_file >> $body_email
	
	# tr -d '\015' < $body_email
}

#-----------------------------------------------------------------------
# Initialise counters and variables from INI file

counter_error=$(crudini --get $var_file '' counter_error)
if [ $counter_error"empty" = "empty" ]; then
    counter_error=0
fi

counter_ok=$(crudini --get $var_file '' counter_ok)
if [ $counter_ok"empty" = "empty" ]; then
    counter_ok=0
fi

counter_notif=$(crudini --get $var_file '' counter_notif)
if [ $counter_notif"empty" = "empty" ]; then
    counter_notif=0
fi

error_start=$(crudini --get $var_file '' error_start)

counter_call=$(crudini --get $var_file '' counter_call)
if [ $counter_call"empty" = "empty" ]; then
    counter_call=0
fi

reset_flag=$(crudini --get $var_file '' reset_flag)

if [ $reset_flag"empty" = "empty" ]; then
    reset_flag=1
fi

if [ $reset_flag -gt 0 ]; then
	counter_error=0
	counter_ok=0
	counter_notif=0
	error_start=
	counter_call=0

	> $call_filename
	> $curr_err_file
fi

# Making the test call
sudo /home/vagrant/sipp-3.5.1/sipp -sf $sipp_script 5901.ur.mundio.com \
  -s $target_number \
  -m 1 \
  -i $machine_ip \
  -trace_err -error_file $errtmp_filename -error_overwrite true \
  -inf $credential_file

exit_code="${?}"

# exit_code=99

let counter_call++

if [ $exit_code -eq 0 ]; then
	echo $log_date "==> Call test OK" >> $call_filename
	echo $log_date "==> Call test OK" >> $cal_log
	echo "==============================================="
	echo $log_date "==> Call test OK"

	# Service is restored if there are X nb of consecutive OK 
	let counter_ok++
	
	if [ $counter_ok -eq $restored_counter ]; then
	
		counter_error=0
	
		# Do not send if error notification was never sent, in case of unsynced data in temp file
		if [ $reset_flag -eq 0 && $counter_notif -gt 1 ]; then
			error_end=$(echo $(date +%Hh%M"_"%d"-"%m"-"%Y))

			# Send email if the service is restored
			email_subject=$(echo "[URING] Service Restored at " )$error_end

			echo $error_start > $body_email
			email_body

			sudo mutt -s "$email_subject" -- $target_mail < $body_email
			
			echo $log_date "==> Service restored notification is sent" >> $call_filename
			echo $log_date "==> Service restored notification is sent"

			> $curr_err_file
			> $call_filename

			# counter_error=0  15/10: moved up to avoid sending error notif below
			counter_notif=0
			error_start=
		fi
	fi
	
else
    # Error occurs
    
    # Cancel counter of OK
	counter_ok=0
	
	let counter_error++
	
	# This is the first error
	if [ $counter_error -eq 1 ]; then
		error_start=$(echo $(date +%Hh%M"_"%d"-"%m"-"%Y))
		counter_call=0
		> $call_filename
		> $curr_err_file
	fi

    # Record it in Call Log
	echo $log_date "==> Call test ERROR" >> $call_filename
	echo $log_date "==> Call test ERROR" >> $cal_log
	echo "==============================================="
	echo $log_date "==> Call test ERROR"
    
    # Copy the content of current error to the 3-hours-error-log and to the current log
	echo "=========================================================" >> $errtmp_filename
    cat $errtmp_filename >> $err_log
	cat $errtmp_filename >> $curr_err_file
	
 
	# To send notification on error nb 3, 9, 27, 81 ...
	error_to_send=$((3**counter_notif))
	
	# Reset from start if the variable saved in the file is not synched
	if [ $counter_error -gt $error_to_send ]; then
		counter_error=1
		counter_notif=0
		error_to_send=1
	fi
	
	if [ $counter_error -eq $error_to_send ]; then
		let counter_notif++
	
		# Do not send if this is the first error
		if [ $counter_error -gt 1 ]; then
			
			let counter_to_display=$counter_notif-1

			email_subject=$(echo "[URING] ERROR ("$counter_to_display"). Since " )$error_start
			
			email_body

			sudo mutt -s "$email_subject" -- $target_mail < $body_email
			
			echo $log_date "==> Error notification is sent" >> $call_filename
			echo $log_date "==> Error notification is sent"
		fi
	fi
fi

#-----------------------------------------------------------------------
# Is this to send report?

# Find out the previous report
let prd_prev=$(echo $now_hour | sed 's/^0$/24/g')
let prd_prev=$(echo $(echo $prd_prev/3)-1)
let prd_prev=$prd_prev*3
prd_prev=$(printf "%02d\n" $prd_prev)

# If now time is 00hxx, previous date is yesterday
if [ "$prd_prev" == "21" ]; then
	prev_date=$(echo $(date +%Y%m%d -d "yesterday"))
	disp_date=$(echo $(date +%d-%m-%Y -d "yesterday"))
else
	prev_date=$now_date
	disp_date=$(echo $(date +%d-%m-%Y))
fi
	
prev_rpt=$(echo $log_directory"ur_rpt_"$prev_date"_"$prd_prev"_"$prd_start".log")

# If report was not created previously
if [ -e $prev_rpt ]; then
	echo "Report was already created and sent previously"
else
	# Sending report

	# Create the report
	sudo echo "Test Period  : $disp_date "\("$prd_prev""h to $prd_start""h)"  >> $prev_rpt
	sudo echo "=================================" >> $prev_rpt

	## If no files to send, then skip
	prev_cal=$(echo $log_directory"ur_cal_"$prev_date"_"$prd_prev"_"$prd_start".log")

	if [ ! -e "$prev_cal" ]; then
		echo $log_date "==> There is No Log Report to send."
		echo $log_date "==> There is No Log Report to send." >> $cal_log
		echo $log_date "==> There is No Log Report to send." >> $prev_rpt
	else
		echo $log_date "==> Sending Report"
		echo $log_date "==> Sending Report" >> $cal_log

		prev_err=$(echo $log_directory"ur_err_"$prev_date"_"$prd_prev"_"$prd_start".log")
	
		sudo echo "Nb of Calls  : "$(cat $prev_cal | wc -l)  >> $prev_rpt
	
		nb_errors=$(cat $prev_cal | grep ERROR | wc -l)

        # Build the email subject
		if [ $nb_errors -eq 0 ]; then
			sudo echo "Nb of Errors : "$nb_errors >> $prev_rpt
			email_subject=$(echo "[URING] Summary Report "$prd_prev"h-"$prd_start"h.")

		else
			sudo echo "Nb of Errors : "$nb_errors" (see attachment)" >> $prev_rpt
			email_subject=$(echo "[URING] Summary Report "$prd_prev"h-"$prd_start"h. Nb Errors: "$nb_errors)"."
		fi

        # Send the email
        if [ ! -e "$prev_err" ]; then
			# Send the report in email with attachment only call log
			sudo mutt -s "$email_subject" -a $prev_cal -- $target_mail < $prev_rpt
        else
			# Send the report in email with attachments of call log and call error
			sudo mutt -s "$email_subject" -a $prev_cal $prev_err -- $target_mail < $prev_rpt
        fi

	fi
fi

# DEBUG ^%!%$^"%*&^*&!"*^%%&^&&^%&^
# sudo rm $prev_rpt


#-----------------------------------------------------------------------
# Update the Init file
echo "reset_flag=0" > $var_file
echo "counter_call="$counter_call >> $var_file
echo "counter_ok="$counter_ok >> $var_file
echo "counter_error="$counter_error >> $var_file
echo "counter_notif="$counter_notif >> $var_file
echo "error_start="$error_start >> $var_file

# Debuging Variables
echo "==============================================="
echo "xxx - Debug counter_call     :" $counter_call       # Nb of test calls after the 1st error. Used to decide when to send error email
echo "xxx - Debug counter_ok       :" $counter_ok         # Nb of success test calls. Used to decide when to send restored service email
echo "xxx - Debug counter_error    :" $counter_error      # Nb of error calls
echo "xxx - Debug counter_notif    :" $counter_notif      # Nb of error notification sent
echo "xxx - Debug error_to_send    :" $error_to_send      # 3^counter_notif = The number of error when the error notif is to send
echo "xxx - Debug error_start      :" $error_start        # Date of first error
echo "."
echo "xxx - Debug email_subject    :" $email_subject
echo "xxx - Debug cal_log          :" $cal_log
echo "xxx - Debug err_log          :" $err_log
echo "xxx - Debug rpt_log          :" $rpt_log
echo "xxx - Debug prev_rpt         :" $prev_rpt
echo "==============================================="

# Kill all hung process of SIPp tool
sudo ps -ef | sudo pkill -f sipp

echo $log_date "==> Call Test completed-."

