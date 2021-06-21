#!/bin/sh
FILENAME=/tmp/plugstatus
state_log_null=0
state_log_init=1
state_log_regist=2
state_log_login=3
state_log_update=4
state_log_forcequit=5
state_log_init_err=101
state_log_regist_err=102
state_log_login_err=103
state_log_update_err=104
bak_file=/tmp/plug_bak
download_file=/tmp/plug_download
program_file=/usr/share/datacenter/appdata/notuninstallable/plugin/Plugin
i=0
login=0
state=0
read_line(){
	cat $FILENAME | while read LINE
	do
		echo "read":$LINE
		state1=$LINE
		return $state1
		echo $state1

	done
#       return $state1 
}

judge_is_run(){
	ret=0
	count=`ps |grep Plugin|grep -v grep`
  	if [ "$?" != "0" ];then
		login=0
		echo    ">>>>no plug,run it"
		killall -SIGTERM Plugin
		$program_file&
		sleep 1
		return 0
	else
		echo ">>>plug is runing..."
		return 1
	fi
}

bak_to_pro(){
	i=`expr $i + 1`;
	#echo $i
	if [ $i -gt 20 ];then
		echo 000 > $FILENAME
		echo "[ running error copy backfile to programfile]"
	fi
}


count=`ps |grep Plugin|grep -v grep`
if [ "$?" != "0" ];then
	echo 000 > $FILENAME
	killall -SIGTERM Plugin
	$program_file&
	sleep 2
fi

while true;do
	read_line
	state=$?
#	echo $state


	if [ "$state" != "$state_log_login" ];then
		login=0
	fi

	if [ "$state" = "$state_log_null" ];then
		echo "[ state_log_null]" 
		echo 010 > $FILENAME
		chmod 777 $bak_file
		cp -f $bak_file $program_file
		killall -SIGTERM Plugin
		$program_file&
		i=0
		sleep 2

		read_line
		state=$?
		if [ "$state" = "10" ];then
			echo 000 > $FILENAME
			echo "[ state_log_bak_start_failure]" 
		fi
	fi

	if [ "$state" = "$state_log_init" ] || [ "$state" = "$state_log_regist" ] || [ "$state" = "$state_log_login" ] || [ "$state" = "$state_log_update_err" ];then
		case $state in
		$state_log_init) echo "[ state_log_init]";;
		$state_log_regist) echo "[ state_log_regist]";;
		$state_log_login) 
			i=0
			if [ $login -eq 0 ];then
				login=1
				cp -f $program_file $bak_file

				echo "[ state_log_login copy programfile to backfile]"
			fi
		;;	
		$state_log_update_err) 
			echo "[ state_log_update_err]"
			echo 003 > $FILENAME
			;;
		esac

		judge_is_run
		if [ "$?" = "0" ];then
			bak_to_pro
		fi
		
	fi

	if [ "$state" = "$state_log_update" ];then
		echo "[ state_log_update copy downloadfile to programfile]"
		login=0
		echo 000 > $FILENAME
		chmod 777 $download_file
		cp -f $download_file $program_file
		killall -SIGTERM Plugin
		$program_file&
		sleep 2
	fi

	if [ "$state" = "$state_log_init_err" ] || [ "$state" = "$state_log_regist_err" ] || [ "$state" = "$state_log_login_err" ];then
		case $state in
			$state_log_init_err) echo "[ state_log_init_err]";;
			$state_log_regist_err) echo "[ state_log_regist_err]";;
			$state_log_login_err) echo "[ state_log_login_err]";;
		esac

		bak_to_pro
	fi

	if [ "$state" = "$state_log_forcequit" ];then
		echo "[ = state_log_forcequit]"
	fi

	sleep 1 
done
