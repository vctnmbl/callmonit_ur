

echo ---------------------------------------
# if the time comes to generate or listen heartbeat

var_tmp_file=$log_directory"heartbeat_listener_var.tmp"

enable=$(crudini --get $ini_file 'Heartbeat Listener' enable)
if [[ $enable"empty" == 1"empty" ]]; then

    heartbeat_src=$(crudini --get $ini_file 'Heartbeat Listener' heartbeat_source)
    if [[ $heartbeat_src"empty" == "empty" ]]; then
        echo ==\> \[Beat Listener\] Aborted. Source of heartbeat is not defined in \'$ini_file\' file.
        exit 99
    fi

    # Heartbeat minutes
    listen_minute=$(crudini --get $ini_file 'Heartbeat Listener' listen_minute)
    if [[ $listen_minute"empty" == "empty" ]]; then
        listen_minute=5 #default
    fi
    
    # Minutes since the last heartbeat
    last_heartbeat_time=$(crudini --get $var_tmp_file '' last_heartbeat_time)
    if [[ $last_heartbeat_time"empty" == "empty" ]]; then
        check_heartbeat_flag=1
        echo ==\> \[Beat Listener\] Last heartbeat of \<$heartbeat_src\> not known.
        last_heartbeat_time=$(echo $(date +%Y-%m-%d" "%H:%M:%S))
    else
        last_heartbeat_sec=$(date -d "$last_heartbeat_time" +%s)
        now_sec=$(date -d "$(date +%F" "%H":"%M":"%S)" +%s)
        min_from_last=$(((now_sec-last_heartbeat_sec)/60))
        
        if [ $min_from_last -ge $listen_minute ]; then
            echo ==\> \[Beat Listener\] Last heartbeat of \<$heartbeat_src\> was $min_from_last min ago \(\>\= $listen_minute min\).
            
            check_heartbeat_flag=1
            # Reset heartbeat time
            last_heartbeat_time=$(echo $(date +%Y-%m-%d" "%H:%M:%S))
        else
            check_heartbeat_flag=0
            echo ==\> \[Beat Listener\] Last heartbeat of \<$heartbeat_src\> was $min_from_last min ago \(\< $listen_minute min\). Waiting...
        fi
    fi
    
    # DEBUG
    # echo DEBUG check_heartbeat_flag=1 Bypassed !
    # check_heartbeat_flag=1
    
    #--------------------------------------------------
    # Variables
    
    nb_no_heartbeat=$(crudini --get $var_tmp_file '' nb_no_heartbeat)
    if [[ $nb_no_heartbeat"empty" == "empty" ]]; then
        nb_no_heartbeat=0
    fi
    
    body_mail_file=$log_directory"heartbeat.tmp"
    alarm_no_heartbeat=3

# =================================
# Heartbeat Listener
# =================================

    # Time to check heartbeat
    if [ $check_heartbeat_flag -eq 1 ]; then
        emails_folder=Maildir/new

        # Fetching emails emails
        echo ==\> \[Beat Listener\] Fetching emails...
        fetchmail --showdots --silent
        exit_code="${?}"
        # echo Fetchmail Exit Code:$exit_code:
        
        if [ $exit_code -ne 0 ]; then
            let nb_no_heartbeat++
            echo ==\> \[Beat Listener\] \<$heartbeat_src\> Heartbeat emails are not received \($nb_no_heartbeat/$alarm_no_heartbeat attempts\). 
        else
            echo ==\> \[Beat Listener\] \<$heartbeat_src\> Heartbeat emails are received. OK.
        fi
              
        # Send notification if there is no heartbeat for 3 times
        if [ $nb_no_heartbeat -ge $alarm_no_heartbeat ]; then
            subject_mail=$(echo \<$heartbeat_src\> is Not Working!!)
            echo $subject_mail > $body_mail_file
            echo $(date +%F" "%H":"%M) >> $body_mail_file
          
            mutt -s $subject_mail $target_mail < $body_mail_file

            # Reset
            nb_no_heartbeat=0
            
            echo ==\> \[Beat Listener\] Alarm: "$subject_mail" sent to: \<$target_mail\>
        fi
    fi
else
    echo ==\> \[Beat Listener\] Heartbeat listener is Disabled
fi



# -------------------------------------------


# Update Variables
echo "" > $var_tmp_file
echo last_heartbeat_time = $last_heartbeat_time >> $var_tmp_file
echo nb_no_heartbeat = $nb_no_heartbeat >> $var_tmp_file

#echo ---------------------------------------
#echo DEBUG monitor_name: $monitor_name
#echo DEBUG log_directory: $log_directory
#echo DEBUG file_pattern: "$file_pattern"
#echo DEBUG elapsed_minute: $elapsed_minute
#echo DEBUG nb_file: $nb_file
#
#echo DEBUG body_mail: $body_mail_file
#echo ---------------------------------------

 

