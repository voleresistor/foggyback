#!/bin/bash
##Ver:0.0.3

# Simple wrapper to manage execution and updating of the actual script.

# Check for and download updates to the main script
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
	remoteScript='https://raw.githubusercontent.com/voleresistor/foggyback/main/backupLinux-daemon.sh'
	localScript="/usr/sbin/backupLinux-daemon.sh"
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
	echo Result: $newVer
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

# Update the backup script
doUpdateScript

# Track script's exit code and return it to systemd
exit $( /usr/sbin/backupLinux-daemon.sh )