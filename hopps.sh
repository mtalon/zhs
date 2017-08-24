#!/bin/bash
header="HOPPS v1.2\nProperty of Michael Talon\n"
config=/home/mtalon/zpd/hopps.cfg		
tabs=5

Startup(){
	# Check if root, remake tmp file
	
	PathCheck $config
	if [[ "$(id -u)" != "0" ]]; then
		Error note "Running as unprivileged user"
	fi
	if [[ -e _hopps.tmp ]]; then
		Error note "Previous attempt was interrupted"
		rm _hopps.tmp
	fi
	touch _hopps.tmp
}

Error(){
	# Prints an error message
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

PathCheck(){
	# Check if a path exists
	
	if [[ ! -e $1 ]]; then
		Error fatal "Missing $1"
	elif [[ ! -r $1 ]]; then
		Error fatal "Denied read access to $1"
	else
		echo "Found $1"
	fi
}

ConfigCheck(){
	# Check that hopps.cfg is sane
	# If yes, return 1
	echo ""
	r=0
	if [[ ! -d $base ]]; then
		Error warn "Base doesnt exist: $base"
	elif [[ ! -w $base ]]; then
		Error warn "Base isn't writable: $base"
	elif [[ ! -d $dir_hopps ]]; then
		Error note "Creating working directory, since it doesnt exist"
		mkdir $dir_hopps
		r=1
	elif [[ ! -d $dir_results ]]; then
		Error warn "Path for results doesn't exist: $dir_results"
	elif [[ ! -d $scope ]]; then
		Error warn "Invalid scope: $scope"
	elif [[ ! -w $scope ]]; then
		Error warn "Scope points to a location I can't write to!"
	elif [[ ! -r $scope ]]; then
		Error warn "Dont have privledges to read files from scope!"
	else
		r=1
	fi
	
	if [[ $cutoff_date -le 1 ]]; then
		Error note "Setting cutoff_date to 100, since configured value doesn't make sense"
		cutoff_date=100
	fi
	
	# Temp fix - we can't be deleting user directories
	if [[ $delete_if_inactive == "yes" ]] && [[ $scope == "/home" ]]; then
		Error note "Ignoring request to delete inactive users from home directory"
		delete_if_inactive=no
	fi
	
	if [[ $delete_if_nomail == "yes" ]] && [[ $scope == "/home" ]]; then
		Error note "Ignoring request to delete accounts with no mail from home directory"
		delete_if_nomail=no
	fi
	
	if [[ $delete_if_old == "yes" ]] && [[ $scope == "/home" ]]; then
		Error note "Ignoring request to delete old user accounts from home directory"
		delete_if_old=no
	fi
	echo ""
}	

CountFiles(){
	# Count the number of files in a specfied directory
	
	num_files=$(ls -ld $1/* | wc -l)
}

CheckIfValidUser(){
	# Add user to array if they meet criteria for valid user
	
	if [[ ! -e $1/mail ]]; then
		if [[ $delete_if_nomail == "yes" ]]; then
			if [[ $verbose_log == "yes" ]]; then
				echo "$1 has no mail - removing"
			fi
			rm -f $file
		else
			if [[ $verbose_log == "yes" ]]; then
				echo "$1 has no mail - ignoring"
			fi
		fi
	else
		if [[ $verbose_log == "yes" ]]; then
			echo "$1 has mail"
		fi
		valid_user[$x]=$1
		((x++))
	fi
}

CheckIfActiveUser(){
	# Out of valid users, check if they are active.
	# These are now "clean users"
	
	if [[ $(find $1 -type f -atime +$cutoff_date -print) ]]; then
		if [[ $verbose_log == "yes" ]]; then
			echo "$1 is inactive - ignoring"
		fi
	else
		if [[ $verbose_log == "yes" ]]; then
			echo "$1 is active"
		fi
		clean_user[$x]=$1
		((x++))
	fi
}

CountWilde(){
	# Look for evidence of a wilde infilration
	# "Active" users have wilde's crontask running
	# Save the list into a file
	if [[ -e $wilde_payload ]]; then
		local wilde_sig=$(cat $wilde_payload)
	else
		Error note "Can't find wilde's payload at $wilde_payload"
		echo "      I'll search for him anyway, but results may not be accurate"
		echo ""
		local wilde_sig="# Its called a hustle, sweetheart"
	fi	
	local present=0
	local active=0
	local broken=0
	local failed=0
	if [[ -e $dir_hopps/InfectedUsers.hopps ]]; then
		rm -f $dir_hopps/InfectedUsers.hopps
	fi
	
	for i in ${clean_user[@]}; do
		local x=0
		name=${i##$scope/}
		for f in $(find $i -type f); do
			ct=$(crontab -u ${i##$scope/} -l 2>&1)
			if [[ ! -d $f ]]; then
				if [[ $(cat $f) == *"$wilde_sig"* ]]; then
					x=1
					((present++))
					if [[ "$ct" == *"wilde"* ]]; then
						echo "PAYLOAD PRESENT AND ACTIVE:      $i"
						((active++))
					else
						echo "Payload present:                 $i"
					fi
				fi
				if [[ "$ct" == *"wilde"* ]]; then
					if [[ $x == 0 ]]; then
						echo "PAYLOAD MISSING - CRONJOB ACTIVE: $i"
						((broken++))
					fi
				fi
				if [[ $f =~ *".f"* ]]; then
					echo "PAYLOAD FAILED TO EXECUTE:        $i"
					((failed++))
				fi
			fi
		done
		#ct=
	done
	if [[ $present == 0 ]]; then
		echo "Wilde not found in $scope"
	else
		echo -ne "\n   ------- [ WILDE STATISTICS] ------- \n\n"
		echo "      Active Infections:   $active of $present"
		echo "      Missing Payloads:    $broken of $present"
		echo "      Execution failures:  $failed of $present"
		echo -ne "\n   -----------------------------------   \n"
	fi
}

NarrowScope(){
	# For each "file" in scope, check if they're valid users,
	# then check if the valid users are active.
	# This SHOULD narrow the results to user directories worth
	# infecting
	
	
	echo -ne "\n---> Narrowing scope...\n"
	num_files=0
	x=0
	for file in $scope/*; do
		CheckIfValidUser $file
	done
	x=0
	for i in ${valid_user[@]}; do
		CheckIfActiveUser $i
	done
	if [[ -z $valid_user ]]; then
		echo "No valid users found in scope :("
	else
		echo -ne "\nNarrowed scope to active users with mail:\n"
		if [[ -e $dir_hopps/ValidUsers ]]; then
			rm $dir_hopps/ValidUsers
		fi
		touch $dir_hopps/ValidUsers
		if [[ $gen_histlist == "yes" ]] && [[ -e $base/targets.d/targets_HoppsHitList.bogo ]]; then
			rm $base/targets.d/targets_HoppsHitList.bogo
		fi
		for i in ${clean_user[@]}; do
			echo $i
			echo $i >> $dir_hopps/ValidUsers
			if [[ $gen_hitlist == "yes" ]]; then
				echo ${i##$scope/} >> $base/targets.d/targets_HoppsHitList.bogo
			fi
		done
		if [[ $gen_hitlist == "yes" ]]; then
			echo "Added above users to hitlist for bogo"
		fi
	fi
}

SearchKeywords(){
	echo -ne "\n---> Searching for keywords...\n"
	if [[ -e $dir_hopps/hits.txt ]]; then
		if [[ -e $dir_hopps/hits.txt.old ]]; then
			Error note "Moving previous hits.txt to hits.txt.old"
		fi
		mv -f $dir_hopps/hits.txt $dir_hopps/hits.txt.old
	fi
	touch $dir_hopps/hits.txt
	h=0
	for i in ${keywords[@]}; do
		for file in $dir_hopps/usermail/*; do
			if [[ -e $file/Sent ]]; then
				if [[ $(cat $file/Sent | grep $i) ]]; then
					echo "Got a hit for $i in $file/Sent!"
					echo -ne "\n$i in $file/Sent:\n\n" >> $dir_hopps/hits.txt
					echo $(cat $file/Sent | grep $i) >> $dir_hopps/hits.txt
					echo "-------------------------------" >> $dir_hopps/hits.txt
					((h++))
				fi
			fi
			if [[ -e $file/Trash ]]; then
				if [[ $(cat $file/Trash | grep $i) ]]; then
					echo "Got a hit for $i in $file/Trash!"
					echo -ne "\n$i in $file/Trash:\n\n" >> $dir_hopps/hits.txt
					echo $(cat $file/Trash | grep $i) >> $dir_hopps/hits.txt
					echo "-------------------------------" >> $dir_hopps/hits.txt
					((h++))
				fi
			fi
			if [[ -e $file/Drafts ]]; then
				if [[ $(cat $file/Drafts | grep $i) ]]; then
					echo "Got a hit for $i in $file/Drafts!"
					echo -ne "\n$i in $file/Drafts:\n\n" >> $dir_hopps/hits.txt
					echo $(cat $file/Drafts | grep $i) >> $dir_hopps/hits.txt
					echo "-------------------------------" >> $dir_hopps/hits.txt
					((h++))
				fi
			fi
			if [[ -e $file/Recieved ]]; then
				if [[ $(cat $file/Recieved | grep $i) ]]; then
					echo "Got a hit for $i in $file/Recieved!"
					echo -ne "\n$i in $file/Recieved:\n\n" >> $dir_hopps/hits.txt
					echo $(cat $file/Recieved | grep $i) >> $dir_hopps/hits.txt
					echo "-------------------------------" >> $dir_hopps/hits.txt
					((h++))
				fi
			fi
		done
	done
	if [[ $h == 0 ]]; then
		echo -ne "\nNo hits in mail :(\n"
	else
		echo -ne "\nFound $h hits! :D\n"
	fi
	echo -ne "\nResults saved to $dir_hopps/hits.txt\n"
}

FindWilde(){
	echo -ne "\n---> Looking for wilde...\n\n"
	CountWilde $scope
}

GrabMail(){
	if [[ -z  $clean_user ]]; then
		echo "There are no valid users to grab mail from :("
	else
		echo -ne "\n---> Consolidating mail...\n"
		for i in ${clean_user[@]}; do
			name=${i##$scope/}
			echo -e "$name\\t--> $dir_hopps/usermail/$name"
			if [[ ! -e $dir_hopps/usermail ]]; then
				mkdir $dir_hopps/usermail
			fi
			if [[ ! -e $dir_hopps/usermail/$name ]]; then
				mkdir $dir_hopps/usermail/$name
			fi
			if [[ -e $i/mail/Sent ]]; then
				cp -f $i/mail/Sent $dir_hopps/usermail/$name/
			fi
			if [[ -e $i/mail/Drafts ]]; then
				cp -f $i/mail/Drafts $dir_hopps/usermail/$name/
			fi
			if [[ -e $i/mail/Trash ]]; then
				cp -f $i/mail/Trash $dir_hopps/usermail/$name/
			fi
			cp -f /var/spool/mail/$name $dir_hopps/usermail/$name/Recieved
		done
		chmod 755 -R $dir_hopps
	fi
}

LocalExec(){
	# Still need to do more, but this is a start
	
	if [[ -e /usr/bin/$1 ]] || [[ -e /bin/$1 ]]; then
		return 1
	fi
	
	return 0
}

clear
echo -ne "$header\n"
Startup
source $config
ConfigCheck

if [[ $r != 1 ]]; then
	Error fatal "hopps.cfg contains errors!"
else
	echo "Configuation is ok"
fi
if [[ -e $base/tasks.hopps ]]
		echo "Sourcing $base/tasks.hopps"
		source $base/tasks.hopps
fi
CountFiles $scope
if [[ $num_files -le 0 ]]; then
	Error fatal "Theres nothing in scope!"
else
	echo "$num_files targets in scope"
fi

if [[ -z $tasks ]]; then
	echo -ne "\nSomeone forgot to give me tasks!\n"
	rm -f _hopps.tmp
else
	rm -f _hopps.tmp
	for i in ${tasks[@]}; do
		# **** UBER DANGEROUS ****
		LocalExec $i
		if [[ $? != 0 ]]; then
			echo "Skipping foreign executable \"$i\"... tsk tsk"
		else
			echo -ne "\nExecute $i? (Y/N) "
			read aa
			if [[ $aa == "Y" ]] || [[ $aa == "y" ]]; then
				$i
			fi
		fi
	done
	rm -f _hopps.tmp
	echo -ne "\nDone!\n"
fi
