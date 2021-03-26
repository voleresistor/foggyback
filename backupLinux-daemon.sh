#!/bin/bash
# Allow users to backup individual homedirs
##Ver:0.0.1

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

# Version comparison
compareVer ()
{
    if [ -z ${1+x} ] || [ -z ${2+x} ]
    then
        echo "Not enough data provided."
        return -1
    fi

    # Split version and read it out
    IFS='.'
    read -ra SRCVER <<< "$1"
    read -ra CURVER <<< "$2"

    # I don't want to hard code the upper boundary here but ^_______^
    for i in {0..2}
    do
        # Always replace local file if version mismatch
        if [ $(expr ${SRCVER[$i]} - ${CURVER[$i]}) -ne 0 ]
        then
            return 1
        fi
    done

    # No new ver
    return 0
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
		writelog $1 "Treating this as an initial seed."
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

# Just stormin' the variables
readonly BACKUP_ROOT="rsync://$BACKUP_HOST/$BACKUP_MODULE"
readonly BACKUP_DATE="$(date '+%Y-%m-%d')"
readonly BACKUP_URL="$BACKUP_ROOT/$BACKUP_DATE"
readonly LOCAL_SBIN="/usr/sbin"
readonly BACKUP_DATA="/var/salinasbackup"
readonly BACKUP_LAST="$BACKUP_DATA/last"

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

# Check if the latest backup is at least 24 hours old
#if [ $MIN_AGE -lt $LAST_DATE ]
#then
#	writelog $ACTIVITY_LOG "Last backup was $(expr $(expr $(date +%s) - $LAST_DATE) / 3600) hour(s) ago."
#	exit 0
#fi

# Create backup dir
#writelog $ACTIVITY_LOG "Creating new folder for this backup: $BACKUP_PATH"
#mkdir -p "$BACKUP_PATH"

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
			--link-dest "/$BACKUP_LAST" \
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

# Prune backups older than 30 days
#writelog $ACTIVITY_LOG "Delete backups older than 30 days."
#find $BACKUP_PATH -maxdepth 1 -mtime +30 -exec rm -rf "{}" \;

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
