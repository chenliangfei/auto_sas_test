#!/bin/bash

ERROR_INFO="log/error_info.log"
INFO_LOG="log/auto_sas_performance_test.log"
CONFIG_INFO="config/auto_sas_test.ini"
FIO_CONFIG="config/fio.conf"

#
is_disk_data_comprehensive_test=`cat $CONFIG_INFO | grep -w "^is_disk_data_comprehensive_test" | awk -F '=' '{print $2}'`
#
fio_comprehensive_test_time=`cat $CONFIG_INFO | grep -w "^fio_comprehensive_test_time" | awk -F '=' '{print $2}'`
#
fio_comprehensive_test_IO_size=`cat $CONFIG_INFO | grep -w "^fio_comprehensive_test_IO_size" | awk -F '=' '{print $2}'`
#
Disk_file_consistency_test_count=`cat $CONFIG_INFO | grep -w "^Disk_file_consistency_test_count" | awk -F '=' '{print $2}'`

#
is_runing_fio_link_reset=`cat $CONFIG_INFO | grep -w "^is_runing_fio_link_reset" | awk -F '=' '{print $2}'`
#
runing_fio_link_reset_disk=`cat $CONFIG_INFO | grep -w "^runing_fio_link_reset_disk" | awk -F '=' '{print $2}'`
#
runing_fio_link_reset_time=`cat $CONFIG_INFO | grep -w "^runing_fio_link_reset_time" | awk -F '=' '{print $2}'`
#
runing_fio_link_reset_file_name=`cat $CONFIG_INFO | grep -w "^runing_fio_link_reset_file_name" | awk -F '=' '{print $2}'`

#
is_runing_fio_hard_reset=`cat $CONFIG_INFO | grep -w "^is_runing_fio_hard_reset" | awk -F '=' '{print $2}'`
#
runing_fio_hard_reset_disk=`cat $CONFIG_INFO | grep -w "^runing_fio_hard_reset_disk" | awk -F '=' '{print $2}'`
#
runing_fio_hard_reset_time=`cat $CONFIG_INFO | grep -w "^runing_fio_hard_reset_time" | awk -F '=' '{print $2}'`
#
runing_fio_hard_reset_file_name=`cat $CONFIG_INFO | grep -w "^runing_fio_hard_reset_file_name" | awk -F '=' '{print $2}'`

#
is_file_transfer_stability_test=`cat $CONFIG_INFO | grep -w "^is_file_transfer_stability_test" | awk -F '=' '{print $2}'`
#
file_transfer_stability_test_disk=`cat $CONFIG_INFO | grep -w "^file_transfer_stability_test_disk" | awk -F '=' '{print $2}'`



#Function Description:
#
#Test Case:
#
function write_log()
{
        TimeFormat="["`date "+%Y-%m-%d %H:%M:%S"`"]"
        echo "$TimeFormat" $1 $2 >> $INFO_LOG
}


#Function Description
#	 Automatic disk partition
#Test Case:
#	Nothing
function dev_partition()
{
fdisk $1 << EOF
n
p


+20M
n
p


+20M
w
EOF
}


#Function Description:
#	Disk data comprehensive test.
#Test Case:
#
function disk_data_comprehensive_test()
{
	write_log " [INFO ] " "Disk data comprehensive test begin."
	if [ ! -e fio -a ! -e $FIO_CONFIG ]
	then
		write_log " [ERROR] "  "fio and fio.conf file does not exist,exit!"
		return -1
	fi

	for dev in `fdisk -l | grep "Disk" | grep "/dev" | awk '{print $2}' | awk -F: '{print $1}'`
	do
		dev_count=`fdisk -l "$dev" | grep "$dev"|wc -l`
		if [ $dev_count -eq 1 ]
		then
			dev_partition $dev 1>/dev/null
		fi
	
        	for dev_part in `fdisk -l $dev? | grep "Disk" | awk '{print $2}' | awk -F ':' '{print $1}'`
		do
			dev_filename=`echo $dev_part | sed 's#\/#\\\/#g'`
			for bs in "${fio_comprehensive_test_IO_size[@]}"
			do
				sed -i "{s/^bs=.*/bs=$bs/g;s/^filename=.*/filename=$dev_filename/g;s/^runtime=.*/runtime=$fio_comprehensive_test_time/g;}" $FIO_CONFIG
				./fio $FIO_CONFIG 1>$ERROR_INFO 2>&1
				status=$?
				info=`grep -iw 'error' $ERROR_INFO`
				if [ x"$info" != x"" -a $status -ne 0 ]
				then
					write_log " [ERROR] " "when useing fio to read and write $dev_part partition failed."
				else
					write_log " [INFO ] " "when useing fio to read and write $dev_part partition success."
				fi
			done
			#		
			echo "y" | mkfs.ext4 $dev_part 1>/dev/null
			mount -t ext4 $dev_part /mnt 1>/dev/null
			temp_info=`mount | grep -w "^$dev_part"`
			if [ x"$temp_info" = x"" ]
			then
				write_log " [ERROR] " "Mount "$dev_part" disk failure"
				continue
			fi
			write_log " [INFO ] " "Mount "$dev_part" disk Success."		
			#
			time dd if=/dev/zero of=/mnt/test.img bs=1M count=15 1>/dev/null
			if [ $? -ne 0 ]
			then
				write_log " [ERROR] " "dd tools read data error."
			else
				write_log " [INFO ] " "dd tools read data OK."
			fi
			#
			init_value=`md5sum /mnt/test.img | awk -F ' ' '{print $1}'`
			for i in $(seq $Disk_file_consistency_test_count)
			do
				cp /mnt/test.img ~/test.img.$i
        			value=`md5sum ~/test.img.$i | awk -F ' ' '{print $1}'`
        			if [ x"$init_value" != x"$value" ]
        			then
                			write_log " [ERROR] " "The test.img($init_value) file is not equal to the MD5 value of the ~/test.img.$i($value) file."
        			fi
        			rm -f ~/test.img.$i
			done
			rm -f /mnt/test.img
			#
			umount $dev_part
			temp_info=`mount | grep -w "^$dev_part"`
                        if [ x"$temp_info" != x"" ]
                        then
                                write_log " [ERROR] " "Failed to uninstall the "$dev_part" disk"
			else
				write_log " [INFO ] " "uninstall the "$dev_part" disk success."
                        fi 
		
			rm -f $ERROR_INFO	
		done
	done
	write_log " [INFO ] " "Disk data comprehensive test end."
}

#Function Description:
#	When running the FIO service, the continuous loop reset the narrow link 
#Test Case:
#	 
function runing_fio_link_reset()
{
	write_log " [INFO ] " "When running the FIO service, the continuous loop reset the narrow link begin."
	if [ x"$runing_fio_link_reset_file_name" = x"" -o ! -e fio ]
	then
		write_log " [ERROR] " "Disk link reset file name is empty, \
                        Please check the 'runing_fio_link_reset_file_name' parameters of the configuration file, \
			Or check the current directory 'fio' file is not there, \
                        test case execution failed."
	else

		fio -filename=$runing_fio_link_reset_disk -direct=1 -iodepth 1 -thread -rw=randwrite -ioengine=psync -bs=512B -numjobs=64 -runtime=$runing_fio_link_reset_time -group_reporting -name=mytest 1>$ERROR_INFO 2>&1 &
		while true
		do 

			if [ `ps -ef | grep fio | grep -v grep | grep -v vfio-irqfd | wc -l` -eq 0 ]
			then
				break
			fi
			echo 1 > $runing_fio_link_reset_file_name
			sleep 1
		done
	
		info=`grep -iw 'error' $ERROR_INFO`
		kill_info=`ps | grep "Killed"`
        	if [ x"$info" != x"" -o x"$kill_info" != x"" ]
        	then
	        	write_log " [ERROR] " "FIO tools to run the exception,  The system runs normally, test case execution failed."
		else
	        	write_log " [INFO ] " "FIO tools to run the  normal,  The system runs normally, test case execution success."	
		fi
		rm -f $ERROR_INFO
	fi
	write_log " [INFO ] " "When running the FIO service, the continuous loop reset the narrow link end."
}


#Function Description:
#	When running the FIO service, Loop reset wide connection
#Test Case:
#	 
function runing_fio_hard_reset()
{
	write_log " [INFO ] " "When running the FIO service, Loop reset wide connection begin."
	if [ x"$runing_fio_link_reset_file_name" = x"" -o ! -e fio ]
        then    
                write_log " [ERROR] " "Disk link reset file name is empty, \
                        Please check the 'runing_fio_link_reset_file_name' parameters of the configuration file, \
			Or check the current directory 'fio' file is not there, \
                        test case execution failed."
        else
		fio -filename=$dev_file -direct=1 -iodepth 1 -thread -rw=randwrite -ioengine=psync -bs=512B -numjobs=64 -runtime=$runing_fio_hard_reset_time -group_reporting -name=mytest 1>$ERROR_INFO 2>&1 &
		
		while true
		do 

			if [ `ps -ef | grep fio | grep -v grep | grep -v vfio-irqfd | wc -l` -eq 0 ]
			then
				break
			fi
			echo 1 > $runing_fio_hard_reset_file_name
			sleep 1
		done
	
		info=`grep -iw 'error' $ERROR_INFO`
		kill_info=`ps | grep "Killed"`
        	if [ x"$info" != x"" -o x"$kill_info" != x"" ]
        	then
	        	write_log " [ERROR] " "FIO tools to run the exception,  The system runs normally, test case execution failed."
                else    
			write_log " [INFO ] " "FIO tools to run the  normal,  The system runs normally, test case execution success."
        	fi
		rm -f $ERROR_INFO
	fi
	write_log " [INFO ] " "When running the FIO service, Loop reset wide connection end."
}


#Function Description:
#	File transfer stability test
#Test Case:
#
function file_transfer_stability_test()
{
	write_log " [INFO ] " "File transfer stability test begin."
	if [ x"$file_transfer_stability_test_disk" = x"" -o ! -e iozone ]
	then
		write_log " [ERROR] " "File transfer stability test disk is empty, \
			Please check the 'file_transfer_stability_test_disk' parameters of the configuration file, \
			Or check the current directory 'iozone' file is not there, \
			test case execution failed."
	else
		echo "y" | mkfs.ext4 $file_transfer_stability_test_disk 1>/dev/null 2>&1
                mount -t ext4 $file_transfer_stability_test_disk /mnt 1>/dev/null 2>&1
                temp_info=`mount | grep -w "^$file_transfer_stability_test_disk"`
               	if [ x"$temp_info" = x"" ]
                then
                        write_log " [ERROR] " "Mount "$file_transfer_stability_test_disk" disk failure"
		else
                	write_log " [INFO ] " "Mount "$file_transfer_stability_test_disk" disk Success."
			./iozone -a -n 1g -g 10g -i 0 -i 1 -i 2 -f /mnt/iozone -V 5aa51ff1 1 > $ERROR_INFO 2>&1
			status=$?
                        info=`grep -iw 'error' $ERROR_INFO`
			if [ $status -ne 0 -a x"$info" != x"" ]
			then
				write_log " [ERROR] " "File transfer stability test, IO read and write exception, test case execution failed."
			else
				write_log " [INFO ] " "File transfer stability test, IO read and write normal, test case execution success."
			fi

			umount $file_transfer_stability_test_disk
			rm -f $ERROR_INFO
		fi
	fi
	write_log " [INFO ] " "File transfer stability test end."
}


#Function Description:
#
#Test Case:
#
function main()
{
	if [ $is_disk_data_comprehensive_test -eq 2 ]
	then
		disk_data_comprehensive_test
	fi

	if [ $is_runing_fio_link_reset -eq 1 ]
	then
		runing_fio_link_reset
	fi

	if [ $is_runing_fio_hard_reset -eq 1 ]
	then
		runing_fio_hard_reset
	fi

	if [ $is_file_transfer_stability_test -eq 1 ]
	then
		file_transfer_stability_test
	fi
}

#################################################################
#
#
#
#
#################################################################

#echo 8 > /proc/sys/kernel/printk
#cat /proc/sys/kernel/printk 1>/dev/null

if [ -e $INFO_LOG ]
then
	rm -f $INFO_LOG
fi

main

