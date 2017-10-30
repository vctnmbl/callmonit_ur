#!/bin/bash

#-----------------------------------------------------------------------
# Using this infinite loop instead of crontab
while :
do
    # Number of seconds before each test session
    timer=10

    # set to 1 to display the variables
    debug_flag=1
  
    clear
    
    #-----------------------------------------------------------------------
    # Get the parameters from INI file
    
    ini_file=/vagrant/ur_callmonit.ini
    
    
    uac=($(crudini --get $ini_file '' clients))
    pwd=($(crudini --get $ini_file '' passwords))
    scenario=($(crudini --get $ini_file '' scenarios))
    
    nb_uac=${#uac[*]}
    nb_pwd=${#pwd[*]}
    nb_scenario=${#scenario[*]}
    
    if [ $nb_uac -eq 0 ]; then
        echo ERROR: \"clients\" parameter is not defined in \"$ini_file\"
        exit 99
    fi
    
    if [ $nb_pwd -eq 0 ]; then
        echo ERROR: \"passwords\" parameter is not defined in \"$ini_file\"
        exit 99
    fi
    
    if [ $nb_scenario -eq 0 ]; then
        echo ERROR: \"scenarios\" parameter is not defined in \"$ini_file\"
        exit 99
    fi
    
    # The extension number to call to for testing
    # target_number=$(crudini --get $ini_file '' target_number)
    # if [ $target_number"empty" = "empty" ]; then
    #     echo "Error: Parameter 'target_number' is not defined in file: '"$ini_file"'"
    # 	exit 99
    # fi
    
    # Email addresses to send the notification & report to
    target_mail=$(crudini --get $ini_file '' target_mail)
    if [[ $target_mail"empty" == "empty" ]]; then
        echo "Error: Parameter 'target_mail' is not defined in file: '"$ini_file"'"
        exit 99
    fi
    
    #-----------------------------------------------------------------------
    # Initialize the variables
    
    sipp_script=/vagrant/ur_uac.xml
    now_date=$(date +%Y%m%d)
    now_time=$(date +%F" "%H":"%M":"%S)
    
    log_directory=/vagrant/
    error_end=
    body_email=
    error_start=
    caller=
    password=
    target=
    curr_call_file=
    
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
        
        echo "Destination: "$target >> $body_email
        printf "\n\nCall Log\n========\n" >> $body_email
        cat $curr_call_file >> $body_email
    }


    # Display the title
    echo "=========================================================="
    echo "= CALL TEST"
    echo "= Scenarios:"

    # Display the scenarios
    index=0
    while [ $index -lt $nb_scenario ]
    do
        caller=${uac[$(echo ${scenario[$index]} | sed 's/->.*$//g')]}
        target=${uac[$(echo ${scenario[$index]} | sed 's/^.*->//g')]}
        
        echo "=          Call No "$((index+1))": Caller:"$caller"    Target:"$target
        let index++
    done
    echo "="
    echo "= Next test session will run in:"

    # Timer between each test
    while [ $timer -gt 0 ]
    do
        echo -ne "=                                "$timer" seconds (Ctrl-C to quit)"\\r
        sleep 1
        let timer--
    done


    #-----------------------------------------------------------------------
    # The Main Loop
    index=0
    
    # Main loop
    while [ $index -lt $nb_scenario ]
    do
        caller=${uac[$(echo ${scenario[$index]} | sed 's/->.*$//g')]}
        password=${pwd[$(echo ${scenario[$index]} | sed 's/->.*$//g')]}
        target=${uac[$(echo ${scenario[$index]} | sed 's/^.*->//g')]}
    
        # ---------------------------------
        # Temporary files
        file_id="cm-"$caller"-"$target"-"
        
        curr_call_file=$log_directory$file_id"call.log"
        
        tmp_err_file=$log_directory$file_id"error.tmp"
        > $tmp_err_file
        
        tmp_msg_file=$log_directory$file_id"msg.tmp"
        > $tmp_msg_file
        
        tmp_sms_file=$log_directory$file_id"shortmsg.tmp"
        > $tmp_sms_file
        
        var_file=$log_directory$file_id"uacvar.tmp"
        body_email=$log_directory$file_id"email_body.tmp"
        credential_file=$log_directory$file_id"ur_uac_csv.tmp"
        
        # Error number/ID in during the 3h period
        error_id_3h_log=0
        
        # Number of times of succesfull test that the service is deemed to be restored
        restored_counter=5
        
        # The local IP addressof this machine
        machine_ip=10.0.2.15
        
        result=$now_time"Call aborted"
    
        #-----------------------------------------------------------------------
        # Creates a credential file (CSV) to be used by SIPp for the SIP Challenge in ur_uac.xml
    
        echo "SEQUENTIAL" > $credential_file
        echo $caller";[authentication username="$caller" password="$password"]" >> $credential_file
    
        #-----------------------------------------------------------------------
        # Initialise report file names
        
        now_hour=$(echo $(date +%H) | sed 's/^0//g')
        # now_hour=0
        
        # Hour the period starts e.g 03
        let prd_start=$(echo $now_hour/3)*3
        prd_start=$(printf "%02d\n" $prd_start)
        
        # Hour the period ends e.g 06
        let prd_end=$(echo $(echo $now_hour/3)+1)
        let prd_end=$prd_end*3
        prd_end=$(printf "%02d\n" $prd_end)
        
        # Files to attached in 3 hourly report
        call_3h_log=$(echo $log_directory$file_id"calls_"$now_date"_"$prd_start"_"$prd_end".log")
        err_3h_log=$(echo $log_directory$file_id"errors_"$now_date"_"$prd_start"_"$prd_end".log")
        rpt_3h_log=$(echo $log_directory$file_id"reports_"$now_date"_"$prd_start"_"$prd_end".log")
    
        #-----------------------------------------------------------------------
        # Initialise counters and variables from variables temporary file
    
        counter_err_3h_log=$(crudini --get $var_file '' counter_err_3h_log)
        if [ $counter_err_3h_log"empty" = "empty" ]; then
            counter_err_3h_log=0
        fi
    
        # Current period e.g. 03-06
        prd_current=$(crudini --get $var_file '' prd_current)
        if [ $prd_current"empty" = "empty" ]; then
            prd_current=empty
        fi
    
        if [ $prd_current != $prd_start"-"$prd_end ]; then
            # If last period is different, reset the error counter
            counter_err_3h_log=0
            prd_current=$prd_start"-"$prd_end
        fi
    
        # Current error counter 
        counter_err_curr=$(crudini --get $var_file '' counter_err_curr)
        if [ $counter_err_curr"empty" = "empty" ]; then
            counter_err_curr=0
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
    
    #-----------------------------------------------------------------------
    # Start the call
    sudo /home/vagrant/sipp-3.5.1/sipp -sf $sipp_script 5901.ur.mundio.com \
    -s $target \
    -m 1 \
    -i $machine_ip \
    -inf $credential_file \
    -trace_err -error_file $tmp_err_file -error_overwrite true \
    -trace_msg -message_file $tmp_msg_file -message_overwrite true \
    -trace_shortmsg -shortmessage_file $tmp_sms_file -shortmessage_overwrite true \
    
    
        #  -trace_stat \
        #  -trace_rtt \
        #  -stf $tmp_stat_file \
        
        exit_code="${?}"
        
        # exit_code=99
        
        let counter_call++
        
        if [ $exit_code -eq 0 ]; then
            result=$now_time" ==> Call test OK"
            
            echo $result >> $curr_call_file
            echo $result >> $call_3h_log
            echo "==============================================="
            echo $now_time "==> Call test OK"
        
            # Service is restored if there are X nb of consecutive OK 
            let counter_ok++
        
            if [ $counter_ok -eq $restored_counter ]; then
        
                counter_err_curr=0
            
                # Do not send if error notification was never sent, in case of unsynced data in temp file
                if [ $counter_notif -gt 1 ]; then
                    error_end=$(echo $(date +%Hh%M"_"%d"-"%m"-"%Y))
        
                    # Send email if the service is restored
                    # email_subject=$(echo "[UR] Service Restored at " )$error_end
                    email_subject=$(echo "[UR] Service is Restored" )
        
                    echo $error_start > $body_email
                    email_body
        
                    # sudo mutt -s "$email_subject" -- $target_mail < $body_email
                    sudo mutt -s "$email_subject" -a $err_3h_log $call_3h_log -- $target_mail < $body_email
        
                    echo $now_time "==> Service restored notification is sent" >> $curr_call_file
                    echo $now_time "==> Service restored notification is sent" >> $call_3h_log
                    echo $now_time "==> Service restored notification is sent" 
        
                    > $curr_call_file
        
                    # counter_err_curr=0  15/10: moved up to avoid sending error notif below
                    counter_notif=0
                    error_start=
                fi
            fi
            
        else
            # Error occurs
            
            # Cancel counter of OK
            counter_ok=0
            
            let counter_err_curr++
            let counter_err_3h_log++
            
            # This is the first error
            if [ $counter_err_curr -eq 1 ]; then
                # error_start=$(echo $(date +%Hh%M"_"%d"-"%m"-"%Y))
                error_start=$(echo $(date +%Y-%m-%d" "%H:%M:%S))
                counter_call=1
                > $curr_call_file
            fi
        
            # Record it in Call Log
            result=$now_time" ==> Call test ERROR (error no: "$counter_err_3h_log")"
            
            echo $result >> $curr_call_file
            echo $result >> $call_3h_log
            echo "==============================================="
            echo $now_time "==> Call test ERROR"
            
            # Error appended to the 3-hours-error-log
            echo "================================================================" >> $err_3h_log
            echo "= ERROR No: "$counter_err_3h_log >> $err_3h_log
            echo "================================================================" >> $err_3h_log
            cat $tmp_err_file | sed -n '/\t/p' >> $err_3h_log
        
            # SIP Messages appended to the 3-hours-error-log
            echo "----------------------------------------------------------------" >> $err_3h_log
            echo "- SIP Messages: (error no: "$counter_err_3h_log")" >> $err_3h_log
            echo "----------------------------------------------------------------" >> $err_3h_log
            # cat $tmp_sms_file >> $err_3h_log
            cat $tmp_sms_file | sed 's/[0-9,-]*\t//;s/\t.*S\t.*CSeq.*\t/ (A-->B) /; s/\t.*R\t.*CSeq.*\t/ (A<--B) /; s/ SIP\/2.0//g'
        
            # ------------------------------------------------------------------------
            # To send notification on minutes 3, 9, 27, 81 ... etc
            error_start_sec=$(date -d "$error_start" +%s)
            error_now_sec=$(date -d "$now_time" +%s)
            sec_from_start=$((error_now_sec-error_start_sec))
            sec_to_send=$((3**counter_notif*60))
            sec_next_to_send=$((3**(counter_notif+1)*60))
        
            # Reset from start if the variable saved in the file is not synched
            if [ $sec_from_start -gt $sec_next_to_send ]; then
                counter_err_curr=1
                counter_notif=0
                #error_to_send=1
            fi
        
            # Skip notification if this the first error
            if [ $counter_notif -eq 0 ]; then
                let counter_notif++
            else
                # Time to send notification
                if [ $sec_from_start -gt $sec_to_send ]; then
                    let counter_notif++
        
                    let counter_to_display=$counter_notif-1
            
                    # email_subject=$(echo "[UR] ERROR ("$counter_to_display"). Since " )$error_start
                    email_subject=$(echo "[UR] ERROR ("$counter_to_display")" )
                    
                    email_body
            
                    sudo mutt -s "$email_subject" -a $err_3h_log $call_3h_log -- $target_mail < $body_email
                    
                    echo $now_time "==> Error notification is sent" >> $curr_call_file
                    echo $now_time "==> Error notification is sent"
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
            
        prev_rpt=$(echo $log_directory$file_id"ur_rpt_"$prev_date"_"$prd_prev"_"$prd_start".log")
        
        # If report was not created previously
        if [ ! -e $prev_rpt ]; then
            # Sending report
        
            # Create the report
            sudo echo "Test Period  : $disp_date "\("$prd_prev""h to $prd_start""h)"  >> $prev_rpt
            sudo echo "=================================" >> $prev_rpt
        
            ## If no files to send, then skip
            prev_cal=$(echo $log_directory$file_id"ur_cal_"$prev_date"_"$prd_prev"_"$prd_start".log")
        
            if [ ! -e "$prev_cal" ]; then
                echo $now_time "==> There is No Log Report to send."
                echo $now_time "==> There is No Log Report to send." >> $call_3h_log
                echo $now_time "==> There is No Log Report to send." >> $prev_rpt
            else
                echo $now_time "==> Sending Report"
                echo $now_time "==> Sending Report" >> $call_3h_log
                
                email_subject=$(echo "[UR] Report")
        
                prev_err=$(echo $log_directory$file_id"ur_err_"$prev_date"_"$prd_prev"_"$prd_start".log")
            
                sudo echo "Nb of Calls  : "$(cat $prev_cal | wc -l)  >> $prev_rpt
            
                nb_errors=$(cat $prev_cal | grep ERROR | wc -l)
                sudo echo "Nb of Errors : "$nb_errors >> $prev_rpt
                
                # Build the email subject
                # if [ $nb_errors -eq 0 ]; then
                # 	sudo echo "Nb of Errors : "$nb_errors >> $prev_rpt
                # 	 email_subject=$(echo "[UR] Report "$prd_prev"h-"$prd_start"h.")
                # 
                # else
                # 	sudo echo "Nb of Errors : "$nb_errors" (see attachment)" >> $prev_rpt
                # 	email_subject=$(echo "[UR] Report "$prd_prev"h-"$prd_start"h. Nb Errors: "$nb_errors)"."
                # fi
        
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
        echo "# Temporary file accessed by callmonit during the calls" > $var_file
        echo "counter_call="$counter_call >> $var_file
        echo "counter_ok="$counter_ok >> $var_file
        echo "counter_err_curr="$counter_err_curr >> $var_file
        echo "counter_notif="$counter_notif >> $var_file
        echo "error_start="$error_start >> $var_file
        echo "counter_err_3h_log="$counter_err_3h_log >> $var_file
        echo "prd_current="$prd_current >> $var_file
    
        # Debuging Variables
        if [ $debug_flag -eq 1 ]; then
            echo "==============================================="
            echo "= SIP Messages"
            echo "==============================================="
            # cat $tmp_sms_file | sed 's/^.*\tS\t.*CSeq.*\t/ A-->B: /g ; s/^.*\tR\t.*CSeq.*\t/ A<--B: /g ; s/ SIP\/2.0//g'
            cat $tmp_sms_file | sed 's/[0-9,-]*\t//;s/\t.*S\t.*CSeq.*\t/ (A-->B) /; s/\t.*R\t.*CSeq.*\t/ (A<--B) /; s/ SIP\/2.0//g'
            echo "==============================================="
            cat $tmp_err_file | sed -n '/\t/p'
            echo "==============================================="
            echo $result
            echo "==============================================="
            echo "xxx - Debug caller_number     :" $caller
            echo "xxx - Debug target_number     :" $target
            echo "."
            
            echo "xxx - Debug counter_call      :" $counter_call       # Nb of test calls after the 1st error. Used to decide when to send error email
            echo "xxx - Debug counter_ok        :" $counter_ok         # Nb of success test calls. Used to decide when to send restored service email
            echo "xxx - Debug counter_err_curr  :" $counter_err_curr      # Nb of error calls
            echo "xxx - Debug counter_notif     :" $counter_notif      # Nb of error notification sent
            # echo "xxx - Debug error_to_send     :" $error_to_send      # 3^counter_notif = The number of error when the error notif is to send
            echo "xxx - Debug error_start       :" $error_start        # Date of first error
            echo "xxx - Debug error_start_sec   :" $error_start_sec
            echo "xxx - Debug now_time          :" $now_time
            echo "xxx - Debug error_now_sec     :" $error_now_sec
            echo "xxx - Debug sec_from_start    :" $sec_from_start
            echo "xxx - Debug sec_next_to_send  :" $sec_next_to_send
            echo "xxx - Debug sec_to_send       :" $sec_to_send
            echo "."
            echo "xxx - Debug email_subject     :" $email_subject
            echo "xxx - Debug ini_file          :" $ini_file
            echo "xxx - Debug call_3h_log       :" $call_3h_log
            echo "xxx - Debug err_3h_log        :" $err_3h_log
            echo "xxx - Debug rpt_3h_log        :" $rpt_3h_log
            echo "xxx - Debug prev_rpt          :" $prev_rpt
            echo "xxx - Debug counter_err_3h_log:" $counter_err_3h_log
            echo "xxx - Debug prd_current       :" $prd_current
            echo "==============================================="
        fi
    
    
        #-----------------------------------------------------------------------
        # Next Scenario
        let index++
    done
    
    # Kill all hung process of SIPp tool
    sudo ps -ef | sudo pkill -f sipp
    
    echo $now_time "==> Call Test completed-."
done
