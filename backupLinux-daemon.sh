#!/bin/bash
##Ver:0.0.3

# Allow users to backup individual homedirs

#'''
#Backup local computer to mounted NFS share.
#Requires that a backup location with automount capability is defined in fstab.
#Run as root.
#
#-h: Show the help
#-i: Initial backup of new system
#--host: Hostname. Can be easily passed in with --host $HOST
#--path: root of backup path
#'''

# Some settings? I'm not sure what this is
set -o errexit
set -o pipefail
#set -o nounset
#set -o xtrace		# Bash script tracing for debugging

# Log writing function
writelog ()
{
	# Pass log path and message in that order
	#echo $1
	#echo $2
	echo "$(date '+%y/%m/%d-%H:%M:%S.%N')>> $2" >> $1
}

# Check for and download updates to the wrapper
doUpdateScript()
{
	# Compare remote and local versions
	compareVer ()
	{
	    if [ -z ${1+x} ] || [ -z ${2+x} ]
	    then
	        #echo "Not enough data provided."
	        echo -1
	    fi

	    # Split version and read it out
	    IFS='.'
	    read -ra REMVER <<< "$1"
	    read -ra LOCVER <<< "$2"

	    # I don't want to hard code the upper boundary here but ^_______^
	    for i in {0..2}
	    do
	        # Always replace local file if version mismatch
	        if [ $(expr ${REMVER[$i]} - ${LOCVER[$i]}) -gt 0 ]; then
				# Return 1 means new version
	            echo 1
				exit
            elif [ $(expr ${REMVER[$i]} - ${LOCVER[$i]}) -lt 0 ]; then
                # Return 2 means something weird is happening
                echo 2
				exit
	        fi
	    done

	    # No new ver
	    echo 0
	}

	# Get the latest version available remotely
	getLatestRemote()
	{
		# Provide the URL to the remote file and the grep string
		# in that order
		# ex: getLatestRemote 'https://example.com/remote.sh' '##Ver:'

		# Try to get the data from the remote file
		rawVer=$(curl -m 10 -s "$1" | grep -m 1 "$2")

		# If successful, separate the final version number
		if [ $? == 0 ]; then
			finalVer=$(echo $rawVer | awk -F ':' '{print $2}')
		fi

		# If $finalVer is null then say -1 else return it
		if [ -z ${finalVer+x } ]; then
			echo -1
		else
			echo $finalVer
		fi
	}

	# Get the version of the locally installed script
	getLocal()
	{
		# Provide the path to the local file and the grep string
		# in that order
		# ex: getLatestRemote '/usr/sbin/local.sh' '##Ver:'

		# Try to get the data from the remote file
		rawVer=$(grep -m 1 "$2" $1)

		# If successful, separate the final version number
		if [ $? == 0 ]; then
			finalVer=$(echo $rawVer | awk -F ':' '{print $2}')
		fi

		# If $finalVer is null then say -1 else return it
		if [ -z ${finalVer+x } ]; then
			echo -1
		else
			echo $finalVer
		fi
	}

	# Update local file
	doCopyNewVer()
	{
		# Transform inputs into more easily readable vars
		remoteFile="$1"
		localFile="$2"

		# Get a temp file to download to
		myTmp=$(mktemp)

		# Copy remote file to temp file
		curl -s "$remoteFile" > "$myTmp"

		# Check checksum of downloaded file vs remote

		# Copy tmp file to $localScript
		cp -f "$myTmp" "$localFile"

		# Remove temp file
		rm -f "$myTmp"
	}

	# File locations and search string
	remoteScript='https://raw.githubusercontent.com/voleresistor/foggyback/main/foggyback.sh'
	localScript="/usr/sbin/foggyback.sh"
	#localScript="/home/aogden/dev/test/target.sh"
	verStr="##Ver:"

	# Get remote ver
	remoteVer=$(getLatestRemote "$remoteScript" "$verStr")
	if [ "$remoteVer" == -1 ]; then
		echo "Unable to get remote file version."
	fi
    echo RemoteVer: $remoteVer

	# Get local ver
	localVer=$(getLocal "$localScript" "$verStr")
	if [ "$localver" == -1 ]; then
		echo "Unable to get local file version."
	fi
    echo LocalVer: $localVer
 
	# if local ver != remote ver
	newVer=$(compareVer "$remoteVer" "$localVer")
	#echo Result: $newVer
	if [ "$newVer" == 1 ]; then
		# copy remote ver over local ver
		echo "We have a new version!"
		doCopyNewVer "$remoteVer" "$localVer"
    elif [ "$newVer" == 2 ]; then
        echo "Funny things happening."
    else
        echo "No update required."
	fi
}

# Verify that network is up and backup host is reachable
checkNetwork()
{
	#Verifies that at least one network interface is online
	#and the backup host can be contacted.
	#
	#Requires the backup host as the first and only argument
	
	# Network info is stored in this path
	netinfo="/sys/class/net"

	# track online state
	online=false

	# Exit if no host was passed
	if [ -z ${1+x} ]; then
		echo 2
		exit
	fi

	# For all net interfaces
    for n in $netinfo/*; do
		# Skip loopback interface
		if [[ "$n" =~ .*/lo$ ]]; then
			continue
		fi

		# Verify that operstate is up
		operstate=$(cat "$n/operstate")
		if [ $operstate == "up" ]; then
			# Try contacting the backup host
			ping -c 1 $1 > /dev/null
			if [ $? == 0 ]; then
				online=true
			fi
		fi

		# All checks passed, ready to go
		if [ $online == true ]; then
			echo 0
			exit
		fi
	done

	# Default state is to assume we're not online
	echo 1
	exit
}

# Log things
readonly LOG_ROOT="/var/log/salinasbak"
readonly ERROR_LOG="$LOG_ROOT/error.log"
readonly ACTIVITY_LOG="$LOG_ROOT/backup.log"

mkdir -p $LOG_ROOT
touch $ERROR_LOG
touch $ACTIVITY_LOG
writelog $ACTIVITY_LOG "Starting up backup script..."

# Handle command line switches
while [[ -n "$1" ]]
do
	case "$1" in
	-i)
		# Initial seed of a new user and/or computer
		INITIAL="true"
		writelog $ACTIVITY_LOG "Treating this as an initial seed."
	esac
	case "$1" in
	--module)
		# Hostname for finding the correct backup folder
		shift
		BACKUP_MODULE=$1
		writelog $ACTIVITY_LOG "User provided module: $BACKUP_MODULE."
	esac
    case "$1" in
	-m)
		# Hostname for finding the correct backup folder
		shift
		BACKUP_MODULE=$1
		writelog $ACTIVITY_LOG "User provided module: $BACKUP_MODULE."
	esac
    case "$1" in
	-h)
		# Hostname for finding the correct backup folder
		shift
		BACKUP_HOST=$1
		writelog $ACTIVITY_LOG "User provided hostname: $BACKUP_HOST."
	esac
    case "$1" in
	--host)
		# Hostname for finding the correct backup folder
		shift
		BACKUP_HOST=$1
		writelog $ACTIVITY_LOG "User provided hostname: $BACKUP_HOST."
	esac
	shift
done

# Quit if no host was specified
if [ -z ${BACKUP_HOST+x} ]
then
	writelog $ERROR_LOG "No backup host specified. Specify a host with -h or --host."
    exit 1
fi

# Gather hostname if it wasn't provided
if [ -z ${BACKUP_MODULE+x} ]
then
	BACKUP_MODULE=$(hostname)
	writelog $ACTIVITY_LOG "Computer provided module name: $BACKUP_MODULE."
fi

# Verify that a network interface is up and backup host is reachable
echo "Checking network..."
#checkNetwork $BACKUP_HOST
netstate=$(checkNetwork $BACKUP_HOST)
if [ "$netstate" != 0 ]; then
	writelog $ACTIVITY_LOG "No active network connection. $netstate"
	exit $netstate
fi

# Just stormin' the variables
readonly BACKUP_ROOT="rsync://$BACKUP_HOST/$BACKUP_MODULE"
readonly BACKUP_DATE="$(date '+%Y-%m-%d')"
readonly BACKUP_URL="$BACKUP_ROOT/$BACKUP_DATE"
readonly LOCAL_SBIN="/usr/sbin"
readonly BACKUP_DATA="/var/salinasbackup"
readonly BACKUP_LAST="$BACKUP_DATA/last"

writelog $ACTIVITY_LOG "BACKUP_ROOT: $BACKUP_ROOT"
writelog $ACTIVITY_LOG "BACKUP_DATE: $BACKUP_DATE"
writelog $ACTIVITY_LOG "BACKUP_URL: $BACKUP_URL"
writelog $ACTIVITY_LOG "LOCAL_SBIN: $LOCAL_SBIN"
writelog $ACTIVITY_LOG "BACKUP_DATA: $BACKUP_DATA"
writelog $ACTIVITY_LOG "BACKUP_LAST: $BACKUP_LAST"
#exit

# Where is the backup going?
writelog $ACTIVITY_LOG "Backup URL: $BACKUP_URL"

# Get time of last backup
if [ -z ${INITIAL+x} ]
then
	LAST_DATE=$(cat $BACKUP_LAST)
else
    mkdir -p $BACKUP_DATA
    touch $BACKUP_LAST
fi

# List of dirs to backup
BACKUP_DIRS=(
	"/home"
	"/etc"
	"/boot"
	"/root"
	"/opt"
	"/srv"
	"/usr/local/sbin"
	"/usr/local/bin"
	"/var"
)

# The || true tells bash to continue if the rsync commands returns an error
for d in "${BACKUP_DIRS[@]}"
do
	writelog $ACTIVITY_LOG "Backing up $d."
	# Verify that the folder exists
	if [[ !(-f "$d") ]]
	then
		# Folder exists so back it up
		rsync -av --delete \
			"$d" \
			--link-dest "$BACKUP_LAST" \
			--exclude=".cache" \
			--exclude=".steam" \
			--exclude=".steampath" \
			--exclude=".steampid" \
			--exclude="Steam" \
			--exclude="Trash" \
			--exclude="tmp" \
			--exclude="log" \
            --exclude="cache" \
			"$BACKUP_URL" || true
	else
		# Folder doesn't exist so do nothing
		writelog $ACTIVITY_LOG "Skipping $d."
	fi
done

# Update $BACKUP_LAST
writelog $ACTIVITY_LOG "Update last file: $BACKUP_LAST with $BACKUP_DATE."
echo $BACKUP_DATE > $BACKUP_LAST

# Check versions of local and remote wrapper
#curver=grep "##Ver:" "$LOCAL_SBIN/runBackup.sh" | awk '{print $2}'
#srcver=grep "##Ver:" "$BACKUP_ROOT/script/runBackup.sh" | awk '{print $2}'

# Check for updated local wrapper
#writelog $ACTIVITY_LOG "Checking for local wrapper updates."
#compareVer $srcver $curver
#wrapperver=$?

#if [ $wrapperver == 1 ]
#then
#	writelog $ACTIVITY_LOG "Replacing local wrapper (v:$curver) with new version from source (v:$srcver)..."
#	cp -f "$BACKUP_ROOT/script/runBackup.sh" "$LOCAL_SBIN/runBackup.sh"
#else
#	writelog $ACTIVITY_LOG "Local wrapper is up to date."
#fi

# Log a successful exit
writelog $ACTIVITY_LOG "Backup completed with no errors."
exit 0