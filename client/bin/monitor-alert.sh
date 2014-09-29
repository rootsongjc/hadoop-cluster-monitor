#!/bin/bash
#####################
#Author: jcsong
#Date: 2014-09-23
#####################
#Log file path.
logfile=../log/monitor-alert.log
echo "[INFO] $(date "+%Y-%m-%d %H:%M:%S") Hadoop monitor start running." >> $logfile
Hefei_send_num=0
Beijing_send_num=0
Guangzhou_send_num=0

function getconf(){
	item=$1
	value=`sed -n "s/.*$item *= *\([^ ]*.*\)/\1/p" ../conf/conf.ini|sed 's/ //g'|tr -d "\r"`
	echo $value
	return 1
}

function sendSMS(){
time=$(date "+%Y-%m-%d %H:%M:%S")
level=$1
body=$2
content="${time} ${level} ${body}"
#send SMS
python alarm.py message -b "${content}" -s "科大讯飞" -a $appid -p "$phones" -u "${content}" -i "Hadoop Monitor"
}

function sendmail(){
time=$(date "+%Y-%m-%d %H:%M:%S")
cluster=$1
IP=$2
hostname=$3
state=$4
duty=$5
phones=$6
mails=$7
content="'"'<table style="padding: 4px 0px; border: 1px solid; border-color:rgb(222, 237, 206); font-size: 14px; vertical-align: baseline; color: rgb(85, 85, 85);">    <tbody>      <tr style="padding: 0.5em; border-width: 1px; border-color: rgb(193, 218, 215); font-weight:bold; vertical-align: middle; color: #444444; text-align: center; height: 18px; background-color: rgb(222, 237, 206);">        <td style="min-width: 100px;">集群</td>        <td style="min-width: 100px;">IP</td>        <td style="min-width: 100px;">域名</td>        <td style="min-width: 100px;">状态</td>        <td style="min-width: 100px;">值班人员</td>    <td style="min-width: 100px;">手机</td>    <td style="min-width: 100px;">邮箱</td>      </tr>      <tr style="padding: 0.5em 0.5em 0.5em 5px; border: 1px solid rgb(204, 204, 204); font-size: 12px; vertical-align: middle; text-align:center; background-color: rgb(248, 248, 248); color: #444444; ">        <td style="min-width: 100px;">'$cluster'</td>        <td style="min-width: 100px;">'$IP'</td>        <td style="min-width: 100px;">'$hostname'</td>        <td style="min-width: 100px;">'$state'</td>        <td style="min-width: 100px;">'$duty'</td>        <td style="min-width: 100px;">'$phones'</td>        <td style="min-width: 100px;">'$mails'</td>      </tr>    </tbody></table>'"'"
python alarm.py mail -s "${sender_mail}" -r "${receiver_mails}" -e "$mail_server" -t "Hadoop Monitor Report" -b "${content}" -n "${sender_name}" -p "${sender_passwd}"
}

function delay_sender(){
cluster=$1
num=$2
status=$3
echo "Cluster $cluster Deadnodes:$status"
remainder=$(( $num%6 ))
if [ $num -lt $threshold ];then
    rec_num=`echo ${status}|tr -s " " "\n"|wc -l`
    i=1
    while ((i<=${rec_num}))
    do
    deadhostname=`echo $status| cut -d " " -f$i`
    deadip=`nslookup $deadhostname|tail -n2|head -n1|cut -d " " -f2`
    echo "$time [ERROR] $cluster $deadhostname:$deadip is dead!" >> $logfile
    #send SMS
    sendSMS "[ERROR]" "$cluster $deadhostname:$deadip is dead!"

    #send email
    sendmail $cluster "$deadip" "$deadhostname" "DEAD" "$duty" "$phones" "$receiver_mails"
    ((i+=1))
    done
elif [ $num -gt $threshold ] && [ $remainder -eq 0 ];then
    rec_num=`echo ${status}|tr -s " " "\n"|wc -l`
    i=1
    while ((i<=${rec_num}))
    do
    deadhostname=`echo $status| cut -d " " -f$i`
    deadip=`nslookup $deadhostname|tail -n2|head -n1|cut -d " " -f2`
    echo "$time [ERROR] $cluster $deadhostname:$deadip is dead!" >> $logfile
    #send SMS
    sendSMS "[ERROR]" "$cluster $deadhostname:$deadip is dead!"

    #send email
    sendmail $cluster "$deadip" "$deadhostname" "DEAD" "$duty" "$phones" "$receiver_mails"
    ((i+=1))
    done
fi
}

appid=$(getconf appid)
phones=$(getconf phones)
interval=$(getconf interval)
receiver_mails=`echo $(getconf receiver_mails)|tr "," " "`
sender_mail=$(getconf sender_mail)
sender_name=$(getconf sender_name)
sender_passwd=$(getconf passwd)
mail_server=$(getconf mail_server)
hf_jmx=$(getconf hf_jmx)
bj_jmx=$(getconf bj_jmx)
gz_jmx=$(getconf gz_jmx)
threshold=$(getconf threshold)
duty=$(getconf duty)

#start monitor the service and send SMS text message the phones if the service down.
function start_monitor(){
deadnode_excluded=$(getconf deadnode_excluded)
time=$(date "+%Y-%m-%d %H:%M:%S")
jmx=$1
cluster=$2
upLine=`grep -n "$cluster hadoop cluster is up" $logfile|cut -d ":" -f1|tail -n1`
downLine=`grep -n "$cluster hadoop cluster is down" $logfile|cut -d ":" -f1|tail -n1`
lastdead=`cat ../log/$cluster-deadnodes.out`  
if [ "${donwLine}" == "" ];then
downLine=-1
fi
status=`python get_deadnode.py $jmx "${deadnode_excluded}"|tr -s "\n" " "`
#Hadoop is unalbe to use.
if [ "${status}" == 'DOWN' ];then
    echo "[ERROR] $time $cluster hadoop service is down!" >> $logfile
    #send SMS
    sendSMS "[ERROR]" "$cluster hadoop cluster is down."
    #send email
    sendmail $cluster "-" "-" "DOWN" "$duty" "$phones" "receiver_mails"

#Some datanode dead and or some of recovery just now.
elif [ "${status}" != '' ] && [ "${status}" != "DOWN" ] && [ "${status}" != "${lastdead}" ]; then
    echo "Some datanode dead and some recovery."
    num=`echo ${status}|tr -s " " "\n"|wc -l`
    nowdead=$status
    echo $status > ../log/$cluster-deadnodes.out
    recovery=`python get_recovery.py "$lastdead" "$nowdead"`
	echo "******************************"
	echo "lastdead:$lastdead  nowdead:$nowdead"
	echo "recorvery:$recovery"
	echo "******************************"
	#The same nodes dead.
	if [ "${recovery}" == '' ];then
	    if [ "${cluster}" == "Hefei" ];then
        ((Hefei_resent+=1))
        echo "Hefei resent num:$Hefei_resent"
	    delay_sender $cluster $Hefei_resent "${status}"
		elif [ "${cluster}" == "Beijing" ];then
            ((Beijing_resent+=1))
		echo "Beijing resent num:$Beijing_resent"
		delay_sender $cluster $Beijing_resent "${status}"
		elif [ "${cluster}" == "Guangzhou" ];then
            ((Guangzhou_resent+=1))
		echo "Guangzhou resent num:$Guangzhou_resent"
			delay_sender $cluster $Guangzhou_resent "${status}"
		fi
	#Some nodes recovery.
	elif [ "${recovery}" != '' ];then
        rec_num=`echo ${recovery}|tr -s " " "\n"|wc -l`
		i=1
		while ((i<=${rec_num}))
		do
        deadhostname=`echo $recovery| cut -d " " -f$i`
        deadip=`nslookup $deadhostname|tail -n2|head -n1|cut -d " " -f2`
        echo "$time [INFO] $cluster $deadhostname:$deadip is up!" >> $logfile
        #send SMS
        sendSMS "[INFO]" "$cluster $deadhostname:$deadip is up."

        #send email
        sendmail $cluster "$deadip" "$deadhostname" "UP" "$duty" "$phones" "$receiver_mails"
		((i+=1))
		done
	fi

#Hadoop cluster recovery.
elif [ $upLine -lt $downLine ];then
    echo "$time [INFO] $cluster hadoop cluster is up." >> $logfile

    #send SMS
    python alarm.py message -b "$time [INFO] $cluster hadoop cluster is up." -s "科大讯飞" -a $appid -p "$phones" -u "$time-$status" -i "Hadoop Monitor"
    
    #send email
    sendmail $cluster "-" "-" "UP" "$duty" "$phones" "$receiver_mails"

#All dead nodes rocovery.
elif [ "${status}" == "" ] && [ "${lastdead}" != "" ];then
    if [ "${cluster}" == "Hefei" ];then
        Hefei_resent=0
        echo "Hefei resent num reset to $Hefei_resent"
    elif [ "${cluster}" == "Beijing" ];then
        Beijing_resent=0
        echo "Beijing resent num reset to $Beijing_resent"
    elif [ "${cluster}" == "Guangzhou" ];then
        Guangzhou_resent=0
        echo "Guangzhou resent num reset to $Guangzhou_resent"
    fi
    echo "lastdead:$lastdead,nowdead:$status".
    num=`echo ${lasdead}|tr -s " " "\n"|wc -l`
    echo "******************************"
    echo "$num datanode(s) recovery."
    i=1
    while ((i<=$num))
    do
        deadhostname=`echo $lastdead | cut -d " " -f$i`
        deadip=`nslookup $deadhostname|tail -n2|head -n1|cut -d " " -f2`
        echo "$time [INFO] $cluster $deadhostname:$deadip is up." >> $logfile
        #send SMS
		sendSMS "[INFO]" "$cluster $deadhostname:$deadip is up."

        #send email
        sendmail $cluster "$deadip" "$deadhostname" "UP" "$duty" "$phones" "$receiver_mails"
        ((i+=1))
    done
	
#The same dead nodes.
elif [ "${status}" == "${lastdead}" ] && [ "${status}" != "" ];then
    if [ "${cluster}" == "Hefei" ];then
        ((Hefei_resent+=1))
        echo "Hefei resent num:$Hefei_resent"
        delay_sender $cluster $Hefei_resent "${status}"
    elif [ "${cluster}" == "Beijing" ];then
        ((Beijing_resent+=1))
        echo "Beijing resent num:$Beijing_resent"
        delay_sender $cluster $Beijing_resent "${status}"
    elif [ "${cluster}" == "Guangzhou" ];then
        ((Guangzhou_resent+=1))
        echo "Guangzhou resent num:$Guangzhou_resent"
        delay_sender $cluster $Guangzhou_resent "${status}"
    fi
fi
echo $status > ../log/$cluster-deadnodes.out
}

while true
do
    start_monitor $hf_jmx "Hefei"
    start_monitor $bj_jmx "Beijing"
    start_monitor $gz_jmx "Guangzhou"
    echo "=========================================="
    sleep $interval
done


