#!/bin/bash

CONFIG_INFO="config/auto_sas_test.ini"
ERROR_INFO="log/fio_errno.info"
INFO_LOG="log/auto_sas_pressure_test.log"

#D03
phy_addr_value=("0xa2002000" "0xa2002400" "0xa2002800" "0xa2002c00" "0xa2003000" "0xa2003400" "0xa2003800" "0xa2003c00")

#
is_fio_run_phy_frequently_flash=`cat $CONFIG_INFO | grep -w "^is_fio_run_phy_frequently_flash" | awk -F '=' '{print $2}'`
frequently_phy_addr=`cat $CONFIG_INFO | grep -w "^frequently_phy_addr" | awk -F '=' '{print $2}'`
frequently_fio_time=`cat $CONFIG_INFO | grep -w "^frequently_fio_time" | awk -F '=' '{print $2}'`
frequently_fio_disk=`cat $CONFIG_INFO | grep -w "^frequently_fio_disk" | awk -F '=' '{print $2}'`
#
is_reset_link_loop=`cat $CONFIG_INFO | grep -w "^is_reset_link_loop" | awk -F '=' '{print $2}'`
reset_link_loop_more=`cat $CONFIG_INFO | grep -w "^reset_link_loop_more" | awk -F '=' '{print $2}'`
loop_rest_link_file=`cat $CONFIG_INFO | grep -w "^loop_reset_link_file" | awk -F '=' '{print $2}'`
loop_rest_hard_file=`cat $CONFIG_INFO | grep -w "^loop_reset_hard_file" | awk -F '=' '{print $2}'`
#
is_fio_long_time_run=`cat $CONFIG_INFO | grep -w "^is_fio_long_time_run" | awk -F '=' '{print $2}'`
fio_long_run_time=`cat $CONFIG_INFO | grep -w "^fio_long_run_time" | awk -F '=' '{print $2}'`
fio_long_run_disk=`cat $CONFIG_INFO | grep -w "^fio_long_run_disk" | awk -F '=' '{print $2}'`
#
is_fio_loop_run=`cat $CONFIG_INFO | grep -w "^is_fio_loop_run" | awk -F '=' '{print $2}'`
fio_loop_run_time=`cat $CONFIG_INFO | grep -w "^fio_loop_time" | awk -F '=' '{print $2}'`
fio_loop_run_more=`cat $CONFIG_INFO | grep -w "^fio_loop_run_more" | awk -F '=' '{print $2}'`
fio_loop_run_disk=`cat $CONFIG_INFO | grep -w "^fio_loop_run_disk" | awk -F '=' '{print $2}'`

#
is_run_business_repeatedly_disk_hot_plug=`cat $CONFIG_INFO | grep -w "^is_run_business_repeatedly_disk_hot_plug" | awk -F '=' '{print $2}'`
#
hot_plug_disk_enable_file=`cat $CONFIG_INFO | grep -w "^hot_plug_disk_enable_file" | awk -F '=' '{print $2}'`
if [ ! -e $hot_plug_disk_enable_file ]
then
	echo "###$hot_plug_disk_enable_file"
fi
exit
#Function Description:
#
#Test Case:
#
function write_log()
{
        TimeFormat="["`date "+%Y-%m-%d %H:%M:%S"`"]"
        echo "$TimeFormat" $1 $2 >> $INFO_LOG
}

#Function Description:
#
#Test Case:
#
function fdisk_query()
{
        write_log " [INFO]  " "Query disk information Begin"
        disk_info=`fdisk -l 2>/dev/null`

        if [ x"$disk_info" = x"" ]
        then
                write_log " [ERROR] " "Use the \"fdisk -l\" command to query dissk failure!"
        else
                write_log " [INFO]  " "Use the \"fdisk -l\" command to query dissk success!"
        fi
        write_log " [INFO]  " "Query disk information ends"
}

#Function Description:
#
#Test Case:
#
function open_all_phy()
{
        #write_log " [INFO]  " "open all phy Begin"
        for addr in "${phy_addr_value[@]}"
        do
                devmem2 $addr w 0x07 1>/dev/null 2>&1
        done

        #write_log " [INFO]  " "open all phy End"
}

#Function Description:
#
#Test Case:
#
function close_all_phy()
{
        #write_log " [INFO]  " "close all phy Begin"
        for addr in "${phy_addr_value[@]}"
        do
                devmem2 $addr w 0x06 1>/dev/null 2>&1
        done

        #write_log " [INFO]  " "close all phy End"
}

#Function Description:
# Run FIO business, the frequent turn off open phy.
#Test condition  
# 
#Test Case:
#	
function fio_run_phy_frequently_flash()
{
	write_log " [INFO ] " "Run FIO business,the frequent turn off open phy begin."
	if [ x"$frequently_phy_addr" = x"" ]
	then 
		write_log " [ERROR] " "When the \"fio_run_phy_frequently_flash\" test, the PHY address is empty, exit the test, please check the value of the \"frequently_phy_addr\" parameter"
		return 
	fi

	fio -filename=$frequently_fio_disk -direct=1 -iodepth 1 -thread -rw=randwrite -ioengine=psync -bs=512B -numjobs=64 -runtime=$frequently_fio_time -group_reporting -name=mytest 1>$ERROR_INFO 2>&1 &
	while true
	do
		if [ `ps -ef | grep fio | grep -v grep | grep -v vfio-irqfd | wc -l` -eq 0 ]
                then
                        break
                fi
		for phy_addr in `echo $frequently_phy_addr | sed 's/|/ /g'`
		do
			devmem2 $phy_addr w 0x06 1>/dev/null 2>&1
			devmem2 $phy_addr w 0x07 1>/dev/null 2>&1
		done
		sleep 10
	done

        info=`grep -iw 'error' $ERROR_INFO`
        if [ x"" != x"" ]
        then
		write_log " [ERROR] " " Business is not interrupted, the system is normal, test case execution failed."
	else
        	write_log " [INFO ] " "Business interruption, normal system, test case execution success."
        fi
	rm -f $ERROR_INFO
	write_log " [INFO ] " "Run FIO business,the frequent turn off open phy end."
}	


#Function Description:
#	Frequent link reset, disk check
#Test Case:
#
function reset_link_loop()
{
	write_log " [INFO ] " "Frequent link reset, disk check Begin"
	for i in `seq $reset_link_loop_more`
	do
		echo 1 > $loop_link_reset_file
		echo 1 > $loop_hard_reset_file

		sleep 10
		if [ x"`fdisk -l`" = x"" ]
		then
			write_log " [ERROR] " "After repeating the reset link, the query disk failed, test case execution failed."
			return
		fi
	done
	write_log " [INFO ] " "After repeated reset link, the query disk is normal, test case execution success."
	write_log " [INFO ] " "Frequent link reset, disk check end."
}


#Function Description:
#	Long time PHY port occupancy test
#Test Case:
#
function fio_long_time_run()
{
	write_log " [INFO ] "  "Long time PHY port occupancy test begin."
	./fio -filename=$fio_long_run_disk -direct=1 -iodepth 1 -thread -rw=randwrite -ioengine=psync -bs=512B -numjobs=64 -runtime=$fio_long_run_time -group_reporting -name=mytest 1>$ERROR_INFO 2>&1
	results=$?
	info=`grep -iw 'error' $ERROR_INFO`
        if [ x"" != x"" -a $results -ne 0 ]
        then
                write_log " [ERROR] " "fio long time run, fio Abnormal operation, test case execution failed."
	else
		write_log " [INFO ] " "fio long time run, fio Normal operation, test case execution success."
        fi
        rm -f $ERROR_INFO
	write_log " [INFO ] " "Long time PHY port occupancy test end."
}

#Function Description:
#	Frequently read and write tests on disk
#Test Case:
#
function fio_loop_run()
{
	write_log " [INFO ] " "Frequently read and write tests on disk begin."
	for i in `seq $fio_loop_run_more`
	do
		./fio -filename=$fio_loop_run_disk -direct=1 -iodepth 1 -thread -rw=randwrite -ioengine=psync -bs=4K -numjobs=64 -runtime=$fio_loop_run_time -group_reporting -name=mytest 1>$ERROR_INFO 2>&1
		results=$?
		
        	info=`grep -iw 'error' $ERROR_INFO`
       		if [ x"$info" != x"" -a $results -ne 0 ]
        	then
                	write_log " [ERROR] " "fio loop ruing, fio Abnormal operation, test case execution failed."
        		return -1
		fi
	done
        rm -f $ERROR_INFO
	write_log " [INFO ] " "fio loop runing, fio Normal operation, test case execution success."
	write_log " [INFO ] " "Frequently read and write tests on disk end."
}

#Function Description:
#       Run the business, repeatedly disk hot plug
#Test Case:
#
function run_business_repeatedly_disk_hot_plug()
{

}

#Function Description:
# 
#Test Case:
#
function main()
{
	if [ $is_fio_run_phy_frequently_flash -eq 1 ]
	then
		fio_run_phy_frequently_flash
	fi

	if [ $is_reset_link_loop -eq 1 ]
	then
		reset_link_loop
	fi

	if [ $is_fio_long_time_run -eq 1 ]
	then
		fio_long_time_run
	fi

	if [ $is_fio_loop_run -eq 1 ]
	then
		fio_loop_run
	fi

}


#######################################################################
#
#
#
#
######################################################################

echo 8 > /proc/sys/kernel/printk
cat /proc/sys/kernel/printk 1>/dev/null

if [ -e $INFO_LOG ]
then
	rm -rf $INFO_LOG
fi

main

