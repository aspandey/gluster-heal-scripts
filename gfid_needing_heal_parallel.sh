#!/bin/bash

#
# This script provides a list of all the files which can be healed or not healed.
# It also generates two files, heal and noheal, which contains the information
# of all theose files. These files could be used by correct_pending_heals.sh to correct
# the fragmnets so that files could be healed by shd.
#

function _init ()
{
    if [ $# -ne 1 ]; then
	echo "usage: $0 <gluster volume name>";
    echo "This script provides a list of all the files which can be healed or not healed.
It also generates two files, heal and noheal, which contains the information
of all theose files. These files could be used by correct_pending_heals.sh to correct
the fragmnets so that files could be healed by shd."
	exit 2;
    fi

    volume=$1;
}

function get_pending_entries ()
{
    local volume_name=$1

    gluster volume heal "$volume_name" info | grep -v ":/" | grep -v "Number of entries" | grep -v "Status:" | sort -u | sed '/^$/d'
}

function get_entry_path_on_brick()
{
    local path="$1"
    local gfid_string=""
    if [[ "${path:0:1}" == "/" ]];
    then
        echo "$path"
    else
        gfid_string="$(echo "$path" | cut -f2 -d':' | cut -f1 -d '>')"
        echo "/.glusterfs/${gfid_string:0:2}/${gfid_string:2:2}/$gfid_string"
    fi
}

function get_stat_for_entry_from_brick()
{
	local subvolume="$1"
	local h="$2"
	local cmd="$3"
	local stat_output
        stat_output=$(ssh -n "${h}" "${cmd}")
#        stat_output= eval $cmd
	if [ ! -z "$stat_output" ]
	then
            echo "$subvolume:$stat_output"
	fi
}

function get_entry_path_all_bricks ()
{
    local entry="$1"
    local bricks="$2"
    local subvolume=0
    local h=""
    local b=""
    local cmd=""
    local stat_output=""
    for brick in $bricks
    do
        if [[ "$((subvolume % 6))" == "0" ]]
        then
            subvolume=$((subvolume+1))
        fi
        h=$(echo "$brick" | cut -f1 -d':')
        b=$(echo "$brick" | cut -f2 -d':')

	echo "$brick$(get_entry_path_on_brick "$entry")"
    done | tr '\n' ','
}

function get_stat_for_entry_from_all_bricks ()
{
    local entry="$1"
    local bricks="$2"
    local subvolume=0
    local h=""
    local b=""
    local cmd=""
    local stat_output=""
    for brick in $bricks
    do
        if [[ "$((subvolume % 6))" == "0" ]]
        then
            subvolume=$((subvolume+1))
        fi
        h=$(echo "$brick" | cut -f1 -d':')
        b=$(echo "$brick" | cut -f2 -d':')

	cmd="stat --format=%F:%b:%B:%s $b$(get_entry_path_on_brick "$entry") 2>/dev/null"
	get_stat_for_entry_from_brick "$subvolume" "${h}" "${cmd}" &
    done | sort | uniq -c | sort -rnk1
}

function get_bricks_from_volume()
{
    local v="$volume"
    gluster volume info "$v" | grep -E "^Brick[0-9][0-9]*:" | cut -f2- -d':'
}

function print_entry_gfid()
{
    local h="$1"
    local dirpath="$2"
    local e="$3"
    local gfid
    gfid="$(ssh -n "${h}" "getfattr -d -m. -e hex $dirpath/$e 2>/dev/null | grep trusted.gfid=|cut -f2 -d'='")"
    echo "$e" - "$gfid"
}

function print_brick_directory_info()
{
    local h="$1"
    local dirpath="$2"
    while read -r e
    do
        print_entry_gfid "${h}" "${dirpath}" "${e}"
    done < <(ssh -n "${h}" "ls $dirpath 2>/dev/null")
}

function print_directory_info()
{
    local entry="$1"
    local bricks="$2"
    local h
    local b
    local gfid
    for brick in $bricks;
    do
        h="$(echo "$brick" | cut -f1 -d':')"
        b="$(echo "$brick" | cut -f2 -d':')"
        dirpath="$b$(get_entry_path_on_brick "$entry")"
	print_brick_directory_info "${h}" "${dirpath}" &
    done | sort | uniq -c
}

function print_entries_needing_heal()
{
    local quorum=0
    local entry="$1"
    local bricks="$2"
    while read -r line
    do
        quorum=$(echo "$line" | awk '{print $1}')
        if [[ "$quorum" -lt 4 ]]
        then
            echo "$line - Not in Quorum"
        else
            echo "$line - In Quorum"
        fi
    done < <(print_directory_info "$entry" "$bricks")
}

function main ()
{
    local bricks
    local quorum=0
    local stat_info=""
    local file_type=""
    bricks=$(get_bricks_from_volume "$volume")
    while read -r heal_entry
    do
        echo "------------------------------------------------------------------"
        echo "$heal_entry"
        file_path="$(get_entry_path_all_bricks "$heal_entry" "$bricks")"
        stat_info="$(get_stat_for_entry_from_all_bricks "$heal_entry" "$bricks")"
        echo "$stat_info"
        quorum=$(echo "$stat_info" | head -1 | awk '{print $1}')
        good_stat=$(echo "$stat_info" | head -1 | awk '{print $3}')
        file_type="$(echo "$stat_info" | head -1 | cut -f2 -d':')"
        if [[ "$file_type" == "directory" ]]
        then
            print_entries_needing_heal "$heal_entry" "$bricks"
        else
            if [[ "$quorum" -ge 4 ]]
            then

                echo "Verdict: Healable"
                echo "${good_stat}|$file_path" >> heal
            else
                echo "${good_stat}|$file_path" >> noheal
                echo "Verdict: Not Healable"
            fi
        fi
    done < <(get_pending_entries "$volume")
}

_init "$@" && main "$@"
