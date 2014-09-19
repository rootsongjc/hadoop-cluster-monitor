#!/bin/bash
###I##################
#Author: jcsong
#Date: 2014-09-19
#####################
#Log file path.
logfile=../log/monitor-alert.log
echo "[INFO] $(date "+%Y-%m-%d %H:%M:%S") Hadoop monitor start running." >> $logfile
function getconf(){
	item=$1
	value=`sed -n "s/.*$item *= *\([^ ]*.*\)/\1/p" ../conf/conf.ini|sed 's/ //g'|tr -d "\r"`
	echo $value
	return 1
}

appid=$(getconf appid)
phones=$(getconf phones)
services=$(getconf services)
interval=$(getconf interval)
receiver_mails=`echo $(getconf receiver_mails)|tr "," " "`
sender_mail=$(getconf sender_mail)
sender_name=$(getconf sender_name)
sender_passwd=$(getconf passwd)
mail_server=$(getconf mail_server)
deadnode_excluded=$(getconf deadnode_excluded)
hf_jmx=$(getconf hf_jmx)
bj_jmx=$(getconf bj_jmx)
gz_jmx=$(getconf gz_jmx)

#start monitor the service and send SMS text message the phones if the service down.
function start_monitor(){
time=$(date "+%Y-%m-%d %H:%M:%S")
jmx=$1
cluster=$2
status=`python get_deadnode.py $jmx "${deadnode_excluded}"`
echo $status
#Hadoop is unalbe to use.
if [ "${status}" == 'DOWN' ];then
    echo "[ERROR] $time $cluster hadoop service is dead!" >> $logfile
    #send SMS
    python alarm.py message -b "[ERROR] $time $cluster hadoop cluster is down." -s "科大讯飞" -a $appid -p "$phones" -u "$time-$status" -i "Hadoop Monitor"

    #send email
    python alarm.py mail -s "${sender_mail}" -r "${receiver_mails}" -e "$mail_server" -t "Hadoop Monitor Report" -b "[ERROR] $time $cluster hadoop cluster is down." -n "${sender_name}" -p "${sender_passwd}"
#Some datanode dead.
elif [ "${status}" != '' ]; then
    num=`echo ${status}|tr -s " " "\n"|wc -l`
    i=1
    while ((i<=$num))
    do
        deadhostname=`echo $status | cut -d " " -f$i`
        deadip=`nslookup $deadhostname|tail -n2|head -n1|cut -d " " -f2`

        echo "[ERROR] $time $cluster $deadhostname:$deadip is dead!" >> $logfile

        #send SMS
        python alarm.py message -b "[ERROR] $time $cluster $deadhostname:$deadip is dead." -s "科大讯飞" -a $appid -p "$phones" -u "$time-$deadip" -i "Hadoop Monitor" 

	#send email
        python alarm.py mail -s "${sender_mail}" -r "${receiver_mails}" -e "$mail_server" -t "Hadoop Monitor Report" -b "[ERROR] $time $cluster ${deadhostname}:${deadip} is dead." -n "${sender_name}" -p "${sender_passwd}"

        ((i+=1))
    done
fi
}

while true
do
    start_monitor $hf_jmx "Hefei"
    start_monitor $bj_jmx "Beijing"
    start_monitor $gz_jmx "Guangzhou"
    sleep $interval
done
