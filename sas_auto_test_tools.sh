#!/bin/bash

# 
# SAS test cases for Plinth
# 
# Copyright (C) 2016 - 2020, chenliangfei Limited. 
# 
# This program is free software; you can redistribute it and/or 
# modify it under the terms of the GNU General Public License 
# as published by the Free Software Foundation; either version 2 
# of the License, or (at your option) any later version. 
# 
# This program is distributed in the hope that it will be useful, 
# but WITHOUT ANY WARRANTY; without even the implied warranty of 
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the 
# GNU General Public License for more details. 
# 
# You should have received a copy of the GNU General Public License 
# along with this program; if not, write to the Free Software 
# Foundation, Inc.,Shenzhen, China
# 
# Author: chenliangfei <liangfei2015@foxmail.com> 

# loading library
. include/auto_test_lib

## ATA and NCQ key words query
function key_words_query()
{
    TEST="key_words_query"

    flag=0
    ATA_info=`dmesg | grep ATA`
    NCQ_info=`dmesg | grep NCQ`

    if [ x"ATA_$info" == x"" ]
    then
        flag=1
        fail_test "Get information ATA failed."
    fi
    if [ x"$NCQ_info" == x"" ]
    then
        flag=1
        fail_test "Get information NCQ failed."
    fi

    if [ $flag -eq 1 ]
    then
        return 1
    fi
    pass_test
}

# disk negotiated link rate query 
function disk_negotiated_link_rate_query()
{
    TEST="disk_negotiated_link_rate_query"
 
    for dir in `ls ${PHY_FILE_PATH}`
    do
        str=`cat ${PHY_FILE_PATH}/${dir}/device_type`
        if test "$str" == "end device"
        then
            rate_value=`cat ${PHY_FILE_PATH}/${dir}/negotiated_linkrate | awk -F '.' '{print $1}'`
            BRate=1
            for rate in `echo $DISK_NEGOTIATED_LINKRATE_VALUE | sed 's/|/ /g'`
            do
                if test $rate_value -eq $rate
                then
                    BRate=0
                    break
                fi
            done

            if test $BRate -eq 1
            then
                fail_test "negotiated link rate query ERROR, 
                \"disk_negotiated_link_rate_query\" \"disk_negotiated_link_rate_query\"."
                return 1
            fi
        fi
    done

    pass_test   
}

# Wide link reset
function hard_reset()
{
    TEST="hard_reset"
  
    count_init=`fdisk -l | grep "Disk identifier:" | wc -l`
    change_sas_phy_file 1 "hard_reset"
    count_curr=`fdisk -l | grep "Disk identifier:" | wc -l`
    fdisk_query
    status=$?
    if test $status -eq 1 -o $count_init -ne $count_curr
    then
        fail_test "Disk wide connection reset ERROR."
        return 1
    fi

    pass_test
}

## Narrow link reset
function link_reset()
{
    TEST="link_reset"
    
    count_init=`fdisk -l | grep "Disk identifier:" | wc -l`
    change_sas_phy_file 1 "link_reset"
    count_curr=`fdisk -l | grep "Disk identifier:" | wc -l`
    fdisk_query

    status=$?
    if test $status -eq 1 -o $count_init -ne $count_curr
    then
        fail_test "Disk narrow connection reset ERROR"
        return 1
    fi

    pass_test
}

# Frequent link reset, disk check
function reset_link_loop()
{
    TEST="reset_link_loop"

    for i in `seq $reset_link_loop_more`
    do
        count_init=`fdisk -l | grep "Disk identifier:" | wc -l`
        change_sas_phy_file 1 "link_reset"
        change_sas_phy_file 1 "hard_reset"

        sleep 5
        count_curr=`fdisk -l | grep "Disk identifier:" | wc -l`
        fdisk_query
        status=$?
        if [ $status -eq 1 -o $count_init -ne $count_curr ]
        then
            fail_test "After repeating the reset link, the query disk failed."
            return 1
        fi
    done
    pass_test
}

#
function reset_phy_file()
{
    count_init=`fdisk -l | grep "Disk identifier:" | wc -l`
    for dev in `fdisk -l | grep "Disk" | grep "/dev" | awk '{print $2}' | awk -F: '{print $1}'`
    do
        dev_count=`fdisk -l "$dev" | grep "$dev" | wc -l`
        if [ $dev_count -eq 1 ]
        then
            dev_partition $dev 1>/dev/null
        fi
    
        for dev_part in `fdisk -l $dev? | grep "Disk" | awk '{print $2}' | awk -F ':' '{print $1}'`
        do
            dev_filename=`echo $dev_part | sed 's#\/#\\\/#g'`
            for rw in "${FIO_RW[@]}"
            do
                ./fio -filename=$dev_filename -direct=1 -iodepth 1 -thread \
                -rw=$rw -ioengine=psync -bs=512B -numjobs=64 -runtime=$FIO_RUN_TIME \
                -group_reporting -norandommap -name=mytest 1>$ERROR_INFO 2>&1 &
                
                while :
                do 
                    if [ `ps -ef | grep fio | grep -v grep | grep -v vfio-irqfd | wc -l` -eq 0 ]
                    then
                        break
                    fi

                    change_sas_phy_file $1 $2
                    sleep 1
                done

                info=`grep -iw 'error' $ERROR_INFO`
                count_curr=`fdisk -l | grep "Disk identifier:" | wc -l`
                if [ x"$info" == x"" -o $count_init -ne $count_curr ]
                then
                    return 1
                fi
            done
        done
    done 

    rm -f $ERROR_INFO
    return 0
}

# When running FIO business, the continuous loop reset the narrow link  
function runing_fio_link_reset()
{
    TEST="runing_fio_link_reset"

    status=reset_phy_file 1 "link_reset"
    if [ $status -eq 1 ]
    then
        fail_test "Continuous loop reset of a narrow link fails when running FIO services."
        return 1
    fi
    pass_test
}

# When running FIO business, the continuous Loop reset wide link
function runing_fio_hard_reset()
{
    TEST="runing_fio_hard_reset"

    status=reset_phy_file 1 "hard_reset"
    if [ $status -eq 1 ]
    then
        fail_test "Continuous loop reset of a wide link fails when running FIO services"
        return 1
    fi
    pass_test
}

# When running FIO business, enable Disconnect disk.
function fio_run_enable_disk()
{
    TEST="fio_run_close_all_phy"

    for dev in `fdisk -l | grep "Disk" | grep "/dev" | awk '{print $2}' | awk -F: '{print $1}'`
    do
        dev_count=`fdisk -l "$dev" | grep "$dev" | wc -l`
        if [ $dev_count -eq 1 ]
        then
            dev_partition $dev 1>/dev/null
        fi
    
        for dev_part in `fdisk -l $dev? | grep "Disk" | awk '{print $2}' | awk -F ':' '{print $1}'`
        do
            dev_filename=`echo $dev_part | sed 's#\/#\\\/#g'`
            for rw in "${FIO_RW[@]}"
            do
                ./fio -filename=$dev_filename -direct=1 -iodepth 1 -thread \
                -rw=$rw -ioengine=psync -bs=512B -numjobs=64 -runtime=$FIO_RUN_TIME \
                -group_reporting -norandommap -name=mytest 1>$ERROR_INFO 2>&1 &
                
                change_sas_phy_file 0 "enable"
                while :
                do 
                    if [ `ps -ef | grep fio | grep -v grep | grep -v vfio-irqfd | wc -l` -eq 0 ]
                    then
                        break
                    fi
                done

                info=`grep -iw 'error' $ERROR_INFO`
                if [ x"$info" == x"" ]
                then
                    rm -f $ERROR_INFO
                    change_sas_phy_file 1 "enable"
                    fail_test "When you run the FIO tool,, enable disconnects the disk connection fail."

                    return 1
                fi
                change_sas_phy_file 1 "enable"
            done
        done
    done 

    rm -f $ERROR_INFO
    pass_test
}

# When running FIO business, repeatedly disk hot plug
function run_business_repeatedly_disk_enable()
{
    TEST="run_business_repeatedly_disk_enable"

    count_init=`fdisk -l | grep "Disk identifier:" | wc -l`
    for dev in `fdisk -l | grep "Disk" | grep "/dev" | awk '{print $2}' | awk -F: '{print $1}'`
    do
        dev_count=`fdisk -l "$dev" | grep "$dev" | wc -l`
        if [ $dev_count -eq 1 ]
        then
            dev_partition $dev 1>/dev/null
        fi
    
        for dev_part in `fdisk -l $dev? | grep "Disk" | awk '{print $2}' | awk -F ':' '{print $1}'`
        do
            dev_filename=`echo $dev_part | sed 's#\/#\\\/#g'`
            for rw in "${FIO_RW[@]}"
            do
                ./fio -filename=$dev_filename -direct=1 -iodepth 1 -thread \
                -rw=$rw -ioengine=psync -bs=512B -numjobs=64 -runtime=$FIO_RUN_TIME \
                -group_reporting -norandommap -name=mytest 1>$ERROR_INFO 2>&1 &
                
                while :
                do 
                    if [ `ps -ef | grep fio | grep -v grep | grep -v vfio-irqfd | wc -l` -eq 0 ]
                    then
                        break
                    fi
                    
                    change_sas_phy_file 0 "enable"
                    sleep 5
                    change_sas_phy_file 1 "enable"
                    sleep 5
                done

                info=`grep -iw 'error' $ERROR_INFO`
                count_curr=`fdisk -l | grep "Disk identifier:" | wc -l`
                if [ x"$info" == x"" -o $count_init -ne $count_curr ]
                then
                    rm -f $ERROR_INFO
                    fail_test "When running the FIO tool, looping on enable to close the enable disk failed."
                    return 1
                fi
            done
        done
    done 

    rm -f $ERROR_INFO
    pass_test
}

# Close and open the phy, check the disk output information
function inquire_open_phy_info()
{
    TEST="inquire_open_phy_info"

    open_init_number=`dmesg | grep -w "Write\ Protect\ is\ off" | wc -l`
    close_init_numbe=`dmesg | grep -w "found\ dev" | wc -l`

    close_all_phy
    open_all_phy
    
    #Waiting for phy open successfully.
    sleep 60

    open_curr_number=`dmesg | grep -w "Write\ Protect\ is\ off" | wc -l`
    close_curr_number=`dmesg | grep -w "found\ dev" | wc -l`

    if test $open_init_number -eq $open_curr_number -o $close_init_number -eq $close_curr_number
    then
        fail_test "phy value close, dmesg has no 'Write Protect is off' or 'found dev' info."
        return 1
    fi

    pass_test
}

## When running FIO business, close all phy.
function fio_run_close_all_phy()
{
    TEST="fio_run_close_all_phy"
    
    for dev in `fdisk -l | grep "Disk" | grep "/dev" | awk '{print $2}' | awk -F: '{print $1}'`
    do
        dev_count=`fdisk -l "$dev" | grep "$dev" | wc -l`
        if [ $dev_count -eq 1 ]
        then
            dev_partition $dev 1>/dev/null
        fi
    
        for dev_part in `fdisk -l $dev? | grep "Disk" | awk '{print $2}' | awk -F ':' '{print $1}'`
        do
            dev_filename=`echo $dev_part | sed 's#\/#\\\/#g'`
            for rw in "${FIO_RW[@]}"
            do
                ./fio -filename=$dev_filename -direct=1 -iodepth 1 -thread \
                -rw=$rw -ioengine=psync -bs=512B -numjobs=64 -runtime=$FIO_RUN_TIME \
                -group_reporting -norandommap -name=mytest 1>$ERROR_INFO 2>&1 &
                
                close_all_phy
                while :
                do 
                    if [ `ps -ef | grep fio | grep -v grep | grep -v vfio-irqfd | wc -l` -eq 0 ]
                    then
                        break
                    fi
                done

                info=`grep -iw 'error' $ERROR_INFO`
                if [ x"$info" == x"" ]
                then
                    rm -f $ERROR_INFO
                    open_all_phy
                    fail_test "When running FIO business, close all phy failed."

                    return 1
                fi
                open_all_phy
            done
        done
    done 

    rm -f $ERROR_INFO
    pass_test

}

## When running FIO business, the frequent turn off open phy.
function fio_run_phy_frequently_flash()
{
    TEST="fio_run_phy_frequently_flash"

    count_init=`fdisk -l | grep "Disk identifier:" | wc -l`
    for dev in `fdisk -l | grep "Disk" | grep "/dev" | awk '{print $2}' | awk -F: '{print $1}'`
    do
        dev_count=`fdisk -l "$dev" | grep "$dev" | wc -l`
        if [ $dev_count -eq 1 ]
        then
            dev_partition $dev 1>/dev/null
        fi
    
        for dev_part in `fdisk -l $dev? | grep "Disk" | awk '{print $2}' | awk -F ':' '{print $1}'`
        do
            dev_filename=`echo $dev_part | sed 's#\/#\\\/#g'`
            for rw in "${FIO_RW[@]}"
            do
                ./fio -filename=$dev_filename -direct=1 -iodepth 1 -thread \
                -rw=$rw -ioengine=psync -bs=512B -numjobs=64 -runtime=$FIO_RUN_TIME \
                -group_reporting -norandommap -name=mytest 1>$ERROR_INFO 2>&1 &
                
                while :
                do 
                    if [ `ps -ef | grep fio | grep -v grep | grep -v vfio-irqfd | wc -l` -eq 0 ]
                    then
                        break
                    fi
                    
                    close_all_phy
                    sleep 5
                    open_all_phy
                    sleep 5
                done

                info=`grep -iw 'error' $ERROR_INFO`
                count_curr=`fdisk -l | grep "Disk identifier:" | wc -l`
                if [ x"$info" == x"" -o $count_init -ne $count_curr ]
                then
                    rm -f $ERROR_INFO
                    fail_test "When running FIO business, the frequent turn off open phy failed."
                    return 1
                fi
            done
        done
    done 

    rm -f $ERROR_INFO
    pass_test

}

# File transfer stability test
function file_transfer_stability_test()
{
    TEST="file_transfer_stability_test"

    for dev in `fdisk -l | grep "Disk" | grep "/dev" | awk '{print $2}' | awk -F: '{print $1}'`
    do
        dev_count=`fdisk -l "$dev" | grep "$dev" | wc -l`
        if [ $dev_count -eq 1 ]
        then
            dev_partition $dev 1>/dev/null
        fi
    
        for dev_part in `fdisk -l $dev? | grep "Disk" | awk '{print $2}' | awk -F ':' '{print $1}'`
        do
            dev_filename=`echo $dev_part | sed 's#\/#\\\/#g'`
            echo "y" | mkfs.ext4 $dev_filename 1>/dev/null 2>&1
            mount -t ext4 $dev_filename /mnt 1>/dev/null 2>&1
            temp_info=`mount | grep -w "^$dev_filename"`

            if [ x"$temp_info" == x"" ]
            then
                fail_test "Mount "$dev_filename" disk failure."
                return 1
            fi

            ./iozone -a -n 1g -g 10g -i 0 -i 1 -i 2 -f /mnt/iozone -V 5aa51ff1 1 > $ERROR_INFO 2>&1
            status=$?
            info=`grep -iw 'error' $ERROR_INFO`
            if [ x"$info" == x"" -a $status -ne 0 ]
            then
                fail_test "File transfer stability test,IO read and write exception."
                umount $dev_filename
                return 1
            fi

            umount $dev_filename
            rm -f $ERROR_INFO
        done
    done 

    pass_test
}

# The FIO tool loops through the disk read and write
function fio_loop_run()
{
    TEST="fio_loop_run"

    for i in `seq $FIO_LOOP_RUN_MORE`
    do
        for dev in `fdisk -l | grep "Disk" | grep "/dev" | awk '{print $2}' | awk -F: '{print $1}'`
        do
            dev_count=`fdisk -l "$dev" | grep "$dev" | wc -l`
            if [ $dev_count -eq 1 ]
            then
                dev_partition $dev 1>/dev/null
            fi
    
            for dev_part in `fdisk -l $dev? | grep "Disk" | awk '{print $2}' | awk -F ':' '{print $1}'`
            do
                dev_filename=`echo $dev_part | sed 's#\/#\\\/#g'`
                ./fio -filename=$dev_filename -direct=1 -iodepth 1 -thread \
                -rw=$rw -ioengine=psync -bs=512B -numjobs=64 -runtime=$FIO_LOOP_RUN_TIME \
                -group_reporting -norandommap -name=mytest 1>$ERROR_INFO 2>&1

                results=$?
                info=`grep -iw 'error' $ERROR_INFO`
                if [ x"$info" != x"" -a $results -ne 0 ]
                then
                    rm -f $ERROR_INFO
                    fail_test "fio loop ruing, fio Abnormal operation."
                    return 1
                fi
            done
        done
    done

    rm -f $ERROR_INFO
    pass_test
}

# Disk read and write for a long time
function fio_long_time_run()
{
    TEST="fio_long_time_run"

    for dev in `fdisk -l | grep "Disk" | grep "/dev" | awk '{print $2}' | awk -F: '{print $1}'`
    do
        dev_count=`fdisk -l "$dev" | grep "$dev" | wc -l`
        if [ $dev_count -eq 1 ]
        then
            dev_partition $dev 1>/dev/null
        fi
    
        for dev_part in `fdisk -l $dev? | grep "Disk" | awk '{print $2}' | awk -F ':' '{print $1}'`
        do
            dev_filename=`echo $dev_part | sed 's#\/#\\\/#g'`
            ./fio -filename=$dev_filename -direct=1 -iodepth 1 -thread -rw=randwrite \
            -ioengine=psync -bs=512B -numjobs=64 -runtime=$FIO_LONG_RUN_TIME -group_reporting \
            -norandommap -name=mytest 1>$ERROR_INFO 2>&1

            results=$?
            info=`grep -iw 'error' $ERROR_INFO`
            if [ x"$info" != x"" -a $results -ne 0 ]
            then
                rm -f $ERROR_INFO
                fail_test "fio long time run, fio Abnormal operation."
                return 1
            fi
        done
    done

    rm -f $ERROR_INFO
    pass_test
}

# Disk data comprehensive test.
function disk_data_comprehensive_test()
{
    TEST="disk_data_comprehensive_test"

    if [ ! -e $FIO_CONFIG ]
    then
        fail_test "fio and fio.conf file does not exist."
        return 1
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
            #       
            echo "y" | mkfs.ext4 $dev_part 1>/dev/null
            mount -t ext4 $dev_part /mnt 1>/dev/null
            temp_info=`mount | grep -w "^$dev_part"`
            if [ "$temp_info" = x"" ]
            then
                fail_test "Mount "$dev_part" disk failure."
                return 1
            fi
        
            #
            time dd if=/dev/zero of=/mnt/test.img bs=10M count=200 conv=fsync 1>/dev/null
            if [ $? -ne 0 ]
            then
                umount $dev_part
                fail_test "dd tools read data error."
                return 1
            fi

            #
            init_value=`md5sum /mnt/test.img | awk -F ' ' '{print $1}'`
            for i in $(seq $Disk_file_consistency_test_count)
            do
                cp /mnt/test.img ~/test.img.$i
                value=`md5sum ~/test.img.$i | awk -F ' ' '{print $1}'`
                if [ "$init_value" != x"$value" ]
                then
                    umount $dev_part
                    rm -f /mnt/test.img
                    fail_test "The test.img($init_value) file is not equal to the MD5 value of \
                        the ~/test.img.$i($value) file."
                    return 1
                fi
                rm -f ~/test.img.$i
            done
            rm -f /mnt/test.img

            #
            umount $dev_part
            temp_info=`mount | grep -w "^$dev_part"`
            if [ x"$temp_info" != x"" ]
            then
                fail_test "Failed to uninstall the "$dev_part" disk."
                return 1
            fi

            #
            dev_filename=`echo $dev_part | sed 's#\/#\\\/#g'`
            for bs in "${FIO_BS[@]}"
            do
                sed -i "{s/^bs=.*/bs=$bs/g;s/^filename=.*/filename=$dev_filename/g;\
                s/^runtime=.*/runtime=$fio_comprehensive_test_time/g;}" $FIO_CONFIG

                ./fio $FIO_CONFIG 1>$ERROR_INFO 2>&1
                status=$?
                info=`grep -iw 'error' $ERROR_INFO`
                if [ x"$info" != x"" -a $status -ne 0 ]
                then
                    fail_test "when useing fio to read and write $dev_part partition failed."
                    return 1
                fi
            done

            rm -f $ERROR_INFO   
        done
    done

    pass_test
} 

# 
function output_info()
{
    echo
    echo
    echo
    echo "***********************Welcome to the SAS Automated Test Tool************************"
    echo "[1]    ATA and NCQ key words query test."
    echo "[2]    Disk negotiated link rate query test."
    echo "[3]    Wide link reset test."
    echo "[4]    Narrow link reset test."
    echo "[5]    Close and open the phy, check the disk output information"
    echo "[6]    When running FIO business, close all phy."
    echo "[7]    When running FIO business, enable Disconnect disk."
    echo "[8]    When running FIO business, the continuous loop reset the narrow link."
    echo "[9]    When running FIO business, the continuous Loop reset wide link."
    echo "[10]   When running FIO business, repeatedly disk hot plug."
    echo "[11]   File transfer stability test."
    echo "[12]   The FIO tool loops through the disk read and write."
    echo "[13]   Disk read and write for a long time."
    echo "[14]   Frequent link reset, disk check."
    echo "[15]   When running FIO business, the frequent turn off open phy."
    echo "[16]   Disk data comprehensive test."
    echo "[ALL]  Run all test cases."
    echo "[exit] Exit the automated test tool."
    echo "************************************************************************************"
    echo -e "input[1-16 | ALL | exit]: \c"
}




# main
while :
do
    output_info
    read option

    case "$option" in
        [1-9]|[1-1][0-6])
            ${cases_arrary[$option]}
            ;;
        "ALL" | "all")
            index=1
            while [ $index -le "${#cases_arrary[*]}" ]
            do
                # Check the test environment
                fdisk_query
                status=$?
                if [ $status -eq 1 ]
                then
                    fail_test "When executing an ${cases_arrary[$index]} test case,The test environment \
                    checks that there is no disk, exit the test."
                    exit 1
                fi

                ${cases_arrary[$index]}
                let index=$index+1
            done
            ;;
        "exit")
            echo "Exit the automated test tool."
            break
            ;;
        * )
            echo -e "Input parameters are wrong, please choose whether to exit the test (y / n): \c"
            while :
            do
                read decide
                if [ x"$decide" = x"y" -o x"$decide" = x"n" ]
                then
                    break
                fi
                echo -e "Input errors, please re-enter(y / n): \c"
            done
        
            if [ x"$decide" = x"y" ]
            then
                echo "Exit the automated test tool."
                break
            fi
            continue
            ;;
    esac
done

# clean exit so lava-test can trust the results
exit 0

