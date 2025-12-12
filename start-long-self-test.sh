#!/bin/bash
for disk in /dev/sd[a-z]; do sudo smartctl -t long "$disk" ; done
