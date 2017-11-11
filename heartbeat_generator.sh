
echo ---------------------------------------
# if the time comes to generate or listen heartbeat

var_tmp_file=$log_directory"heartbeat_generator_var.tmp"

# =================================
# Heartbeat Generator
# =================================

enable=$(crudini --get $ini_file 'Heartbeat Generator' enable)
if [[ $enable"empty" == 1"empty" ]]; then

    # Heartbeat minutes
    heartbeat_minute=$(crudini --get $ini_file 'Heartbeat Generator' heartbeat_minute)
    if [[ $heartbeat_minute"empty" == "empty" ]]; then
        heartbeat_minute=5 #default
    fi
    
    # Minutes since the last heartbeat
    last_heartbeat_time=$(crudini --get $var_tmp_file '' last_heartbeat_time)
    if [[ $last_heartbeat_time"empty" == "empty" ]]; then
        echo ==\> \[Beat Generator\] Last heartbeat of \<$monitor_name\> is not known. Resetting ...
        last_heartbeat_time=$(echo $(date +%Y-%m-%d" "%H:%M:%S))
        check_heartbeat_flag=1
    else
        last_heartbeat_sec=$(date -d "$last_heartbeat_time" +%s)
        now_sec=$(date -d "$(date +%F" "%H":"%M":"%S)" +%s)
        min_from_last=$(((now_sec-last_heartbeat_sec)/60))
        
        if [ $min_from_last -ge $heartbeat_minute ]; then
            echo ==\> \[Beat Generator\] Last heartbeat of \<$monitor_name\> was $min_from_last min ago \(\>\= $heartbeat_minute min\). Checking Heartbeat...
            
            check_heartbeat_flag=1
            # Reset heartbeat time
            last_heartbeat_time=$(echo $(date +%Y-%m-%d" "%H:%M:%S))
        else
            check_heartbeat_flag=0
            echo ==\> \[Beat Generator\] Last heartbeat of \<$monitor_name\> was $min_from_last min ago \(\< $heartbeat_minute min\). No need to send heartbeat.
        fi
    fi
    
    # DEBUG
    # echo DEBUG check_heartbeat_flag=1 Bypassed !
    # check_heartbeat_flag=1
    
    #--------------------------------------------------
    # Variables
    # Generated Heartbeat Sequence Number
    seq_number=$(crudini --get $var_tmp_file '' seq_number)
    if [[ $seq_number"empty" == "empty" ]]; then
        seq_number=0
    fi
    
    body_mail_file=$log_directory"heartbeat.tmp"
    alarm_no_heartbeat=3

    # Time to generate heartbeat
    if [ $check_heartbeat_flag -eq 1 ]; then

        # Heartbeat by monitoring file dates or by timer
        monitor_files=$(crudini --get $ini_file 'Heartbeat Generator' monitor_files)
        if [[ $monitor_files"empty" == "yesempty" ]]; then
            # Monitor file to generate heartbeat
        
            # The file pattern to use
            file_pattern=$(crudini --get $ini_file 'Heartbeat Generator' file_pattern)
            if [[ $file_pattern"empty" == "empty" ]]; then
                file_pattern=*
            fi
            
            # The email to send the heartbeat to
            listener_email=$(crudini --get $ini_file 'Heartbeat Generator' listener_email)
            if [[ $listener_email"empty" == "empty" ]]; then
                listener_email=andoko@mundio.com #default
            fi
        
            # The files were modified x minutes ago?
            file_mod_minute=$(crudini --get $ini_file 'Heartbeat Generator' file_mod_minute)
            if [[ $file_mod_minute"empty" == "empty" ]]; then
                file_mod_minute=$heartbeat_minute #default
            fi

            # Number of files created in the last x minutes
            nb_file=$(find $log_directory -maxdepth 1 -mmin -$file_mod_minute -iname "$file_pattern" -type f | wc -l)
            
            if [ $nb_file -gt 0 ]; then
                send_heartbeat_flag=1
            else
                # No heartbeat. Dead!
                send_heartbeat_flag=0
            fi
        else
            # Timer to generate heartbeat
            send_heartbeat_flag=1
        fi
        
        # Sending heartbeat by email
        if [ $send_heartbeat_flag -eq 1 ]; then
        
            # Listener email
            listener_email=$(crudini --get $ini_file 'Heartbeat Generator' listener_email)
            if [[ $listener_email"empty" == "empty" ]]; then
                listener_email=andoko@mundio.com #default
            fi
        
            let seq_number++
            
            subject_mail=$(echo \<$monitor_name\> Heartbeat $seq_number)
            echo $subject_mail  @ $(date +%H":"%M":"%S) > $body_mail_file

            # Sending the email
            mutt -s $subject_mail $listener_email < $body_mail_file
        
            echo ==\> \[Beat Generator\] $subject_mail sent to \<$listener_email\>
        else
            echo ==\> \[Beat Generator\] \[$monitor_name\] is DEAD!! No Heartbeat \($file_pattern files\) for the last $file_mod_minute minutes.
        fi
    fi
else
    echo ==\> \[Beat Generator\] \<$monitor_name\> Heartbeat is Disabled
fi

# -------------------------------------------
# Update Variables
echo "" > $var_tmp_file
echo last_heartbeat_time = $last_heartbeat_time >> $var_tmp_file
echo seq_number = $seq_number >> $var_tmp_file

#echo ---------------------------------------
#echo DEBUG monitor_name: $monitor_name
#echo DEBUG log_directory: $log_directory
#echo DEBUG file_pattern: "$file_pattern"
#echo DEBUG elapsed_minute: $elapsed_minute
#echo DEBUG nb_file: $nb_file
#
#echo DEBUG body_mail: $body_mail_file
#echo ---------------------------------------
