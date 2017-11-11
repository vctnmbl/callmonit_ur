#Timer set to 10 seconds
delay=10


while :
do
    # From ur_uac.sh
    ini_file=/vagrant/ur_callmonit.ini
    log_directory=/vagrant/

    #-----------------------------------------------------------------------
    # Get the parameters from INI file

    # Monitor Name
    monitor_name=$(crudini --get $ini_file '' monitor_name)
    if [[ $monitor_name"empty" == "empty" ]]; then
        echo "Error: Parameter 'monitor_name' is not defined in file: '"$ini_file"'"
        exit 99
    fi

    # Email addresses to send the notification & report to
    target_mail=$(crudini --get $ini_file '' target_mail)
    if [[ $target_mail"empty" == "empty" ]]; then
        echo "Error: Parameter 'target_mail' is not defined in file: '"$ini_file"'"
        exit 99
    fi

    echo 
    echo 
    echo 
    echo 
    echo 
    echo "======================================================================="
    echo "= HEARTBEAT GENERATOR/LISTENER "
    echo "= 'q' to quit, or 'r' to run immediately"
    echo "= ---------------------------------------------------------------------"
    
    # Display the progress bar
    press_key=x
    
    timer=$delay
    
    # Timer between each test
    while [ $timer -ge 0 ]
    do
        bar_len=$timer
        bar_head=""
        
        while [ $bar_len -gt 0 ]
        do
            bar_head=$bar_head"___"
            let bar_len--
        done

        bar_len=0
        bar_tail=""

        while [ $bar_len -lt $(( delay-timer )) ]
        do
            bar_tail=$bar_tail"___"
            let bar_len++
        done
        bar_tail=$(tput bold)$(tput rev)$bar_tail$(tput sgr0)
        
        echo -ne "=     Test No ("$index") will run in: " $timer  [$bar_tail$bar_head]"\033[0K\r"

        read -t1 -s -n 1 press_key
        case $press_key in
            r) break ;;
            q) echo; exit ;;
        esac

        let timer--
    done
    
    echo 
    echo
    echo
    sleep 1
        
    # --------------------------------------
    
    source $log_directory/heartbeat_generator.sh
    echo 
    source $log_directory/heartbeat_listener.sh

    sleep 1
    echo "======================================================================="
done