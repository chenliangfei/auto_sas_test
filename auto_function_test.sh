#!/bin/bash

CONFIG_INFO="config/auto_sas_test.ini"
INFO_LOG="log/auto_sas_function_test.log"


#D03
phy_addr_value=("0xa2002000" "0xa2002400" "0xa2002800" "0xa2002c00" "0xa2003000" "0xa2003400" "0xa2003800" "0xa2003c00")

is_insmod_and_rmmod_module=`cat $CONFIG_INFO | grep -w "^is_insmod_and_rmmod_module" | awk -F '=' '{print $2}'`
mod_version=`cat $CONFIG_INFO | grep -w "^mod_version" | awk -F '=' '{print $2}'`
mod_v1_file=`cat $CONFIG_INFO | grep -w "^mod_v1_file" | awk -F '=' '{print $2}'`
mod_v2_file=`cat $CONFIG_INFO | grep -w "^mod_v2_file" | awk -F '=' '{print $2}'`
mod_main_file=`cat $CONFIG_INFO | grep -w "^mod_main_file" | awk -F '=' '{print $2}'`

#
is_hard_reset=`cat $CONFIG_INFO | grep -w "^is_hard_reset" | awk -F '=' '{print $2}'`
hard_reset_file_name=`cat $CONFIG_INFO | grep -w "^hard_reset_file_name" | awk -F '=' '{print $2}'`

#
is_link_reset=`cat $CONFIG_INFO | grep -w "^is_link_reset" | awk -F '=' '{print $2}'`
link_reset_file_name=`cat $CONFIG_INFO | grep -w "^link_reset_file_name" | awk -F '=' '{print $2}'`

#
is_insert_sata=`cat $CONFIG_INFO | grep -w "^is_insert_sata" | awk -F '=' '{print $2}'`

#
is_inquire_open_close_phy_info=`cat $CONFIG_INFO | grep -w "^is_inquire_open_close_phy_info" | awk -F '=' '{print $2}'`

#
disk_negotiated_link_rate_query=`cat $CONFIG_INFO | grep -w "^disk_negotiated_link_rate_query" | awk -F '=' '{print $2}'`
disk_negotiated_link_rate_file_name=`cat $CONFIG_INFO | grep -w "^disk_negotiated_link_rate_file_name" | awk -F '=' '{print $2}'`
disk_negotiated_link_rate_value=`cat $CONFIG_INFO | grep -w "^disk_negotiated_link_rate_value" | awk -F '=' '{print $2}'`

#
is_Key_words_query=`cat $CONFIG_INFO | grep -w "^is_Key_words_query" | awk -F '=' '{print $2}'`


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
	write_log " [INFO ] " "Query disk information Begin"
	disk_info=`fdisk -l 2>/dev/null`
	
	if [ x"$disk_info" = x"" ]
	then
		write_log " [ERROR] " "Use the \"fdisk -l\" command to query disk failure!"
	else
		write_log " [INFO ] " "Use the \"fdisk -l\" command to query disk success!"
	fi
	write_log " [INFO ] " "Query disk information ends"
}

#Function Description:
#
#Test Case:
#
function close_all_phy()
{
#	write_log " [INFO]  " "close all phy Begin"
	for addr in "${phy_addr_value[@]}"
	do
		devmem2 $addr w 0x06 1>/dev/null 2>&1
	done

#	write_log " [INFO]  " "close all phy End"
}

#Function Description:
#
#Test Case:
#
function open_all_phy()
{
#	write_log " [INFO]  " "open all phy Begin"
	for addr in "${phy_addr_value[@]}"
        do
                devmem2 $addr w 0x07 1>/dev/null 2>&1
        done

#	write_log " [INFO]  " "open all phy End"
}

#Function Description:
#	Turn off and turn on the PHY port to check if there is a disk log output
#Test Case:
#
function inquire_open_close_phy_info()
{
	wirte_log " [INFO ] " "Turn off and turn on the PHY port to check if there is a disk log output begin."
	close_init_number=`dmesg | grep -w "found\ dev" | wc -l`
	open_init_number=`dmesg | grep -w "Write\ Protect\ is\ off" | wc -l`

	close_all_phy
	open_all_phy
	
	#Waiting for phy open successfully.
	sleep 20

	close_curr_number=`dmesg | grep -w "found\ dev" | wc -l`
	open_curr_number=`dmesg | grep -w "Write\ Protect\ is\ off" | wc -l`

	if [ $close_init_number -eq $close_curr_number ]
        then
        	write_log " [ERROR] " "phy value close, dmesg has no 'found dev' info, test case execution failed."
	else
		write_log " [INFO ] " "phy value close, dmesg contains 'found dev' info, test case execution success."
        fi

	if [ $open_init_number -eq $open_curr_number ]
        then
        	write_log " [ERROR] " "phy value close, dmesg has no 'Write Protect is off' info, test case execution failed."
	else
		write_log " [INFO ] " "phy value close, dmesg contains 'Write Protect is off' info, test case execution success."
        fi

	fdisk_query
	write_log " [INFO ] " "Turn off and turn on the PHY port to check if there is a disk log output end."
}


#Function Description:
#	Wide link reset
#Test Case:
#
function hard_reset()
{
	write_log " [INFO ] " "Wide link reset begin."
	if [ x"$hard_reset_file_name" = x"" ]
	then
		write_log " [ERROR] " "Disk wide connection file is empty,\
			Please check the 'link_reset_file_name' parameters of the configuration file, \
			test case execution failed."
	else
		echo 1 > $hard_reset_file_name 1>/dev/null
		if [ $? -eq 0 ]
		then
			echo " [INFO ] " "Disk wide connection reset OK, test case execution success." 
		else
			echo " [ERROR] " "Disk wide connection reset ERROR, test case execution failed."
		fi
		fdisk_query
	fi
	write_log " [INFO ] " "Wide link reset end."
}


#Function Description:
#	Narrow link reset
#Test Case:
#
function link_reset()
{
	write_log " [INFO ] " "Narrow link reset begin."
	if [ x"$link_reset_file_name" = x"" ]
	then
		write_log " [ERROR] " "Disk narrow connection file is empty, \
			Please check the 'link_reset_file_name' parameters of the configuration file, \
			test case execution failed."
	else
		echo 1 > $link_reset_file 1>/dev/null
		if [ $? -eq 0 ]
		then
			write_log " [INFO ] " "Disk narrow connection reset OK, test case execution success."
		else
			write_log " [ERROR] " "Disk narrow connection reset ERROR, test case execution failed."
		fi
		fdisk_query
	fi
	write_log " [INFO ] " "Narrow link reset end."
}


#Function Description:
#      disk negotiated link rate query 
#Test Case:
#
function disk_negotiated_link_rate_query()
{
	write_log " [INFO] " "negotiated link rate query begin."
	if [ x"$disk_negotiated_link_rate_file_name" = x"" ]
	then
		write_log " [ERROR] " "negotiated link rate file name is empty, \
			Please check the 'disk_negotiated_link_rate_file_name' parameters of the configuration file, \
                        test case execution failed."
	else
		rate_value=`cat $disk_negotiated_link_rate_file_name | awk -F '.' '{print $1}'`
		BRate=0
		for rate in `echo $disk_negotiated_link_rate_value | sed 's/|/ /g'`
		do
			if [ $rate_value -eq $rate ]
			then
				write_log " [INFO ] " "negotiated link rate query OK, test case execution success."
				BRate=1
				break
			fi
		done
		if [ $BRate -eq 1 ]
		then
			write_log " [ERROR] " "negotiated link rate query ERROR, test case execution failed."
		fi
	fi
	write_log " [INFO] " "negotiated link rate query end."
}


#Function Description:
#	
#Test Case:
#
function mod_version_query()
{
	write_log " [INFO ] " "modle version query begin."
	if [ ! -e $mod_main_file]
	then
		write_log " [ERROR] " "$mod_main_file Module file does not exist, \
			test case execution failed."
		return -1
	fi
	info=`modinfo $mod_main_file | grep vermagic: | awk -F ' ' '{print $2}' | awk -F '-' '{print $1}'`
	
	if [ x"$info" == x"$mod_version" ]
	then
		write_log " [INFO ] " "Driver version information is consistent with the actual release version, \
			test case execution success."
	else
		write_log " [ERROR] " " Driver version information is not consistent with the actual release version, \
			Check the correctness of the 'mod_version' configuration item value of the configuration file, \
			test case execution failed."
	fi
	write_log " [INFO ] " "modle version query end."
}

#Function Description:
#
#Test Case:
#
function rmmod_module()
{
	write_log " [INFO ] " "rmmod modle begin."
	if [ -e $mod_v1_file -a -e $mod_v2_file -a -e $mod_main_file ]
	then
        	rmmod $mod_v2_file 1>/dev/null 2>&1
        	rmmod $mod_v1_file 1>/dev/null 2>&1
        	rmmod $mod_main_file 1>/dev/null 2>&1
	else
		write_log " [ERROR] "  "$mod_v1_file|$mod_v2_file|$mod_main_file Module file does not exist,Exit test, \
			test case execution failed."
		return -1
	fi

	mod_file_name=`echo $mod_main_file | awk -F '.' '{print $1}'`
	cmd_info=`lsmod | grep -w $mod_file_name`
	if [ x"$cmd_info" != x"" ]
	then
        	write_log " [ERROR] " "System uninstall module failed,Exit test, test case execution failed."
	else
		write_log " [INFO ] " "System uninstall module successfully, test case execution success."
	fi
	write_log " [INFO ] " "rmmod modle end."
}

#Function Description:
#
#Test Case:
#
function insmod_and_rmmod_module()
{
	write_log " [INFO ] " "Load module test begin"
	if [ -e $mod_v1_file -a -e $mod_v2_file -a -e $mod_main_file ]
        then
                insmod $mod_main_file 1>/dev/null 2>&1
                insmod $mod_v1_file 1>/dev/null 2>&1
                insmod $mod_v2_file 1>/dev/null 2>&1
        else
                write_log " [ERROR] " "$mod_v1_file|$mod_v2_file|$mod_main_file Module file does not exist,Exit test, \
				test case execution failed."
                return -1
        fi

        cmd_info=`lsmod | grep -w "hisi_sas_main"`
        if [ x"$cmd_info" = x"" ]
        then
                write_log " [ERROR] "  "System loading module failed,Exit test, \
			test case execution failed."
        else
                write_log " [INFO ] "  "System loading module successfully, \
			test case execution success."
		fdisk_query
		
		mod_version_query
		
		rmmod_module
        fi
}
 
#Function Description:
#	ATA and NCQ key words query
#Test Case:
#
function Key_words_query()
{
	write_log " [INFO ] " "ATA and NCQ key words query begin."
	info=`dmesg | grep ATA`
	if [ x"$info" != x"" ]
	then
		write_log " [INFO ] " "Get information ATA success, test case execution success."
	else
		write_log " [ERROR] " "Get information ATA failed, test case execution failed."
	fi

	info=`dmesg | grep NCQ`
	if [ x"$info" != x"" ]
	then
		write_log " [INFO ] " "Get information NCQ success, test case execution success."
	else
		write_log " [ERROR] " "Get information NCQ failed, test case execution failed."
	fi
	write_log " [INFO ] " "ATA and NCQ key words query end."
}

#Function Description:
#
#Test Case:
#
function main()
{

	if [ $is_inquire_open_close_phy_info -eq 1 ]
	then
		inquire_open_close_phy_info
	fi

	if [ $is_link_reset -eq 1 ]
	then
		link_reset
	fi

	if [ $is_hard_reset -eq 1 ]
	then
		hard_reset
	fi
	
	if [ $is_insmod_and_rmmod_module -eq 1 ]
	then
		insmod_and_rmmod_module
	fi

	if [ $is_Key_words_query -eq 1 ]
	then
		Key_words_query
	fi
}

#########################################################
#
#
#
#
#########################################################

#echo 8 > /proc/sys/kernel/printk
#cat /proc/sys/kernel/printk 1>/dev/null

if [ -e $INFO_LOG ]
then
	rm -f $INFO_LOG
fi

main
