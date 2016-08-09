#!/bin/bash
export PATH=$PATH:/usr/local/bin/:/usr/bin

# Safety feature: exit script if error is returned, or if variables not set.
# Exit if a pipeline results in an error.
set -ue
set -o pipefail

## Automatic Download CloudWatch Metric Script
#
# Written by Bhargav Amin. (http://bhargavamin.com)
# Contact me for all your Amazon Web Services Consulting needs!
# Script Github repo: https://github.com/bhargavamin/automatic-cloudwatch-metrics
#
# PURPOSE: This Bash script can be used to download cloudwatch metrics for all the instances. Script process:
# - Determine the instance ID of the EC2 server on which the script runs
# - Gather a list of all Running Instance IDs
# - Take a cloudwatch metrics for all the instance store at a location
# - Run it daily using crontab


## Variable Declartions ##

# Get Instance Details
instance_id=$(wget -q -O- http://169.254.169.254/latest/meta-data/instance-id)
region=$(wget -q -O- http://169.254.169.254/latest/meta-data/placement/availability-zone | sed -e 's/\([1-9]\).$/\1/g')

# Set Logging Options
logfile="/var/log/cw-metrics.log"
logfile_max_lines="50000"

## Function Declarations ##

# Function: Setup logfile and redirect stdout/stderr.
log_setup() {
    # Check if logfile exists and is writable.
    ( [ -e "$logfile" ] || touch "$logfile" ) && [ ! -w "$logfile" ] && echo "ERROR: Cannot write to $logfile. Check permissions or sudo access." && exit 1

    tmplog=$(tail -n $logfile_max_lines $logfile 2>/dev/null) && echo "${tmplog}" > $logfile
    exec > >(tee -a $logfile)
    exec 2>&1
}

# Function: Log an event.
log() {
    echo "[$(date +"%Y-%m-%d"+"%T")]: $*"
}

# Function: Confirm that the AWS CLI and related tools are installed.
prerequisite_check() {
	for prerequisite in aws wget; do
		hash $prerequisite &> /dev/null
		if [[ $? == 1 ]]; then
			echo "In order to use this script, the executable \"$prerequisite\" must be installed." 1>&2; exit 70
		fi
	done
}

# Function: Snapshot all volumes attached to this instance.
get_cloudwatch_metrics() {
	for instance_id in $instance_list; do
		log "Instance ID is $instance_id"
		
		# Capture the events in log
		log_description="$(hostname)-metriclog-$(date +%Y-%m-%d)"
		
		# Fetch CloudWatch metrics for all the instances
		aws cloudwatch get-metric-statistics --metric-name CPUUtilization --start-time 2016-08-07T23:18:00 --end-time 2016-08-09T23:18:00 --period 360 --namespace AWS/EC2 --statistics Maximum --dimensions Name=InstanceId,Value=$instance_id >> <location>$instance_id.txt
	 
	done
}


## SCRIPT COMMANDS ##

log_setup
prerequisite_check

# Grab all volume IDs attached to this instance
instance_list=$(sudo aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId]'  --filters Name=instance-state-name,Values=running --output text)

get_cloudwatch_metrics
