#!/bin/bash

#
# This script finally resets the xattrs of all the fragments of a file
# which can be healed as per gfid_needing_heal_parallel.sh.
# gfid_needing_heal_parallel.sh will produce two files, heal and noheal.
# This script takes heal as input and resets xattrs of all the fragments
# of those files present in this file (heal).
#


function _init ()
{
    if [ $# -ne 1 ]
    then
        echo "usage: $0 heal";
        echo "This script finally resets the xattrs of all the fragments of a file
which can be healed as per gfid_needing_heal_parallel.sh.
gfid_needing_heal_parallel.sh will produce two files, heal and noheal.
This script takes heal as input and resets xattrs of all the fragments
of those files present in this file (heal)."
        exit 2;
    else
        echo "This script finally resets the xattrs of all the fragments of a file
              which can be healed as per gfid_needing_heal_parallel.sh.
              gfid_needing_heal_parallel.sh will produce two files, heal and noheal.
              This script takes heal as input and resets xattrs of all the fragments
              of those files present in this file (heal)."
    fi  

    heal=$1;
}


function total_file_size_in_hex()
{
    size=$((${1} * 4))
    base=0x0000000000000000
    hex_size=`printf '%x' $size`
    length=${#hex_size}
    temp=`echo 0x0000000000000000 | cut -c 1-$((18 - $length))`
    new_size="$temp$hex_size"
    echo $new_size
}

function set_frag_xattr_as_sink ()
{
    file_host=$1
    file_entry=$2
    size=0x0000000000000000
    zero_version=0x00000000000000000000000000000000
    dirty=0x00000000000000010000000000000001

    cmd="mkdir -p /tmp/${file_entry} && cp ${file_entry} /tmp/${file_entry} 2>/dev/null"

    ssh -n "${file_host}" "${cmd}"
    cmd="setfattr -n trusted.ec.size -v ${size} ${file_entry}"
    ssh -n "${file_host}" "${cmd}"
    cmd="setfattr -n trusted.ec.version -v ${version} ${file_entry}"
    ssh -n "${file_host}" "${cmd}"
    cmd="setfattr -n trusted.ec.dirty -v ${dirty} ${file_entry}"
    ssh -n "${file_host}" "${cmd}"
}

function set_frag_xattr_as_source ()
{
    file_host=$1
    file_entry=$2
    size=$3
    version=0x00000000000000010000000000000001
    dirty=0x00000000000000010000000000000001

    cmd="mkdir -p /tmp/${file_entry} && cp ${file_entry} /tmp/${file_entry} 2>/dev/null"

    ssh -n "${file_host}" "${cmd}"
    cmd="setfattr -n trusted.ec.size -v ${size} ${file_entry}"
    ssh -n "${file_host}" "${cmd}"
    cmd="setfattr -n trusted.ec.version -v ${version} ${file_entry}"
    ssh -n "${file_host}" "${cmd}"
    cmd="setfattr -n trusted.ec.dirty -v ${dirty} ${file_entry}"
    ssh -n "${file_host}" "${cmd}"
}

function check_and_correct_fragment ()
{

    bpath=$1
    size=$2
    file_stat=$3
    file_host=`echo $bpath | cut -d ":" -f 1`
    file_entry=`echo $bpath | cut -d ":" -f 2`

    cmd="stat --format=%F:%b:%B:%s $file_entry 2>/dev/null"
    stat_output=$(ssh -n "${file_host}" "${cmd}")
    echo $stat_output | grep ${file_stat} 
    if [[ $? -eq 0 ]]
    then 
        set_frag_xattr_as_source $file_host $file_entry $size
    else
        set_frag_xattr_as_sink $file_host $file_entry
    fi
}

function backup_file_fragment()
{
    mkdir 
}

function main ()
{
    while read -r heal_entry
    do
        echo ${heal_entry}
        file_stat=`echo $heal_entry | cut -d "|" -f 1`
        frag_size=`echo $file_stat | rev | cut -d ":" -f 1 | rev`
        total_size="$(total_file_size_in_hex $frag_size)"
        file_paths=`echo $heal_entry | cut -d "|" -f 2`

        for bpath in ${file_paths//,/ }
        do
            check_and_correct_fragment $bpath $total_size $file_stat
        done

    done < heal
}

_init "$@" && main "$@"
