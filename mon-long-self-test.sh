#!/bin/bash
watch -n 120 -d 'for disk in /dev/sd[a-z]; do printf "$disk : " ; sudo smartctl -c "$disk" | grep "of test remaining" ; echo " " ; done'
