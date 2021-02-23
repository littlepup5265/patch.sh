#!/bin/bash

function help_func {
  echo "Usage:
	Example:  ./patch.sh -e -r -s -v  # Patch server.sh and reboot, restart services and validate_db
	-e  stop services 
	-r  Reboot server after patching
	-s  Restart services
	-v  Validate services
	-h  Print help message
           "
  exit
}

while getopts 'ersvh' opt; do
  case ${opt} in
    e )
      STOP=yes
      ;;
    r )
      REBOOT=yes
      ;;
    s )
      START=yes
      ;;
    v )
      Validate=yes
      ;;
    h ) help_func
      ;;
esac
done
for options in $(echo $@)
do
  SERVERLIST=$options
done
if [ ! -s "$SERVERLIST" ]
then
  echo "ERROR: $SERVERLIST does not exist"
  exit 1
fi

for i in $(cat $SERVERLIST)
do 
	echo ~~~~~~~~~~~~~~~~~~~~~
	echo $i
     
        if [ "$STOP" = "yes" ]
        then
        rosh -l root -n $i -t '/bbtscripts/unix/shutdown_jvm.sh'
        rosh -l root -n $i -t '/bbtscripts/unix/shutdown_db.sh'
     
    echo "services stopped........."
        fi
        rosh -l root -n $i -t '/bbtscripts/stopesp.sh'
    echo -n "Clearing yum cache..."
        rosh -l root -n $i -t 'yum clean all; rm -rf /var/cache/yum'
    echo "*************[DONE]***********"
    echo -n "Executing yum upgrade..."
        rosh -l root -n $i -t 'yum -y upgrade --disablerepo=centrify --exclude=nfs* --nogpgcheck'
    echo "                  [DONE]"
     
        if [ "$REBOOT" = "yes" ]
        then
    echo -n "Rebooting ${i}..."
        rosh -l root -n $i -t 'shutdown -r now'
        sleep 120
        UPCHECK=0
        while [ "$UPCHECK" -ne 3 ]
    do
    echo "Waiting for $i to come back online..."
        if rosh -l root -n $i -t "uptime" &> /dev/null
        then
    echo "                    [DONE]"
        UPCHECK=3
        else
        sleep 10
        UPCHECK=$((UPCHECK + 1))
        fi
        done
        if [ "UPCHECK" -eq 3 ]
        then
	echo "ERROR:  Reboot failed!!!"
        exit 1
    
        fi
        fi
        if [ "$START" = "yes" ]
        then
        rosh -l root -n $i -t '/bbtscripts/unix/startup_jvm.sh'
        rosh -l root -n $i -t '/bbtscripts/unix/startup_db.sh'
	echo "Services Started........."
        fi
        if [ "$Validate" = "yes" ]
        then
        rosh -l root -n $i -t '/bbtscripts/unix/validate_jvm.sh'
        rosh -l root -n $i -t '/bbtscripts/unix/validate_db.sh'	
	echo "Services Validate.........."
						
        fi
        rosh -l root -n $i -t '/etc/vmware-tools/services.sh restart'
        rosh -l root -n $i -t '/bbtscripts/startesp.sh'
		rosh -l root -n $i -t 'mount -a'
	echo "Vmware and ESP services started.........."
    echo "*************Done********************"
   done



