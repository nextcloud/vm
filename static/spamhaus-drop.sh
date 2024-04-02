#!/bin/bash

## Initially forked from cowgill, extended and improved for our mailserver needs.
## Credit: https://github.com/cowgill/spamhaus/blob/master/spamhaus.sh

# based off the following two scripts
# http://www.theunsupported.com/2012/07/block-malicious-ip-addresses/
# http://www.cyberciti.biz/tips/block-spamming-scanning-with-iptables.html

# Thanks to Daniel Hansson for providing a PR motivating bringing v2 of this script.
# https://github.com/enoch85

# path to iptables
IPTABLES="/sbin/iptables"

# list of known spammers
URLS="https://www.spamhaus.org/drop/drop.txt https://www.spamhaus.org/drop/edrop.txt"

# local cache copy
CACHE_FILE="/tmp/drop.txt"

# iptables custom chain name
CHAIN="Spamhaus"

# (don't) skip failed blocklist downloads
SKIP_FAILED_DOWNLOADS=0

# log blocklist hits in iptables
LOG_BLOCKLIST_HITS=1

error() {
	echo "$1" 1>&2
}

die() {
	if [ -n "$1" ]; then
		error "$1"
	fi
	exit 1
}

usage() {
	echo "Basic usage: $(basename "$0") <-u>

Additional options and arguments:
  -u                   Download blocklists and update iptables
  -c=CHAIN_NAME        Override default iptables chain name
  -l=URL_LIST          Override default block list URLs [careful!]
  -f=CACHE_FILE_PATH   Override default cache file path
  -s                   Skip failed blocklist downloads, continuing instead of aborting
  -z                   Update the blocklist from the local cache, don't download new entries
  -d                   Delete the iptables chain (removing all blocklists)
  -o                   Only download the blocklists, don't update iptables
  -t                   Disable logging of blocklist hits in iptables
  -h                   Display this help message
"
}

set_mode() {
	if [ -n "$MODE" ]; then
		die "You must only specify one of -u/-o/-d/-z"
	fi
	MODE="$1"
}

delete_chain_reference() {
	$IPTABLES -L "$1" | tail -n +3 | grep -e "^$CHAIN " > /dev/null && $IPTABLES -D "$1" -j "$CHAIN"
}

delete_chain() {
	if $IPTABLES -L "$CHAIN" -n &> /dev/null; then
		delete_chain_reference INPUT
		delete_chain_reference FORWARD
		if $IPTABLES -F "$CHAIN" && $IPTABLES -X "$CHAIN"; then
			echo "'$CHAIN' chain removed from iptables."
		else
			echo "'$CHAIN' chain NOT removed, please report this issue to https://github.com/wallyhall/spamhaus-drop/"
		fi
	else
		echo "'$CHAIN' does not exist, nothing to delete."
	fi
}

download_rules() {
	TMP_FILE="$(mktemp)"
	
	for URL in $URLS; do
		# get a copy of the spam list
		echo "Fetching '$URL' ..."
		curl -Ss "$URL" | grep -e "" | tee -a "$TMP_FILE" > /dev/null
		if [ "${PIPESTATUS[0]}" -ne 0 ]; then
			if [ $SKIP_FAILED_DOWNLOADS -eq 1 ]; then
				echo "Failed to download '$URL' while skipping is enabled - so continuing."
			else
				rm -f "$TMP_FILE"
				die "Failed to download '$URL', aborting."
			fi
		fi
	done

	mv -f "$TMP_FILE" "$CACHE_FILE"
	rm -f "$TMP_FILE"
}

update_iptables() {
	# refuse to run if the cache file looks insane
	if [ ! -r "$CACHE_FILE" ]; then
		die "Cannot read cache file '$CACHE_FILE'"
	elif [ "$(stat -c '%U' "$CACHE_FILE")" != "root" ]; then
		die "Cache file '$CACHE_FILE' is not owned by root.  Refusing to load it."
	fi

	# check to see if the chain already exists
	if $IPTABLES -L "$CHAIN" -n &> /dev/null; then
		# flush the old rules
		$IPTABLES -F "$CHAIN"

		echo "Flushed old rules. Applying updated Spamhaus list...."
	else
		# create a new chain set
		$IPTABLES -N "$CHAIN"

		# tie chain to input rules so it runs
		$IPTABLES -A INPUT -j "$CHAIN"

		# don't allow this traffic through
		$IPTABLES -A FORWARD -j "$CHAIN"

		echo "'$CHAIN' chain not detected. Creating new chain and adding Spamhaus list...."
	fi;

	# iterate through all known spamming hosts
	SPAMIP="$(cut -d ' ' -f1 "$CACHE_FILE" | tr -d ';' | awk 'NF > 0')"
	for IP in $SPAMIP; do
		if [ $LOG_BLOCKLIST_HITS -eq 1 ]; then
			# add the ip address log rule to the chain
			$IPTABLES -A "$CHAIN" -p 0 -s "$IP" -j LOG --log-prefix "[SPAMHAUS BLOCK]" -m limit --limit 3/min --limit-burst 10
		fi

		# add the ip address to the chain
		$IPTABLES -A "$CHAIN" -p 0 -s "$IP" -j DROP
	done

	echo "'$CHAIN' chain updated with latest rules."
}

download_rules_and_update_iptables() {
	download_rules
	update_iptables
}

if [ "$(whoami)" != "root" ]; then
	die "You must run this command as root."
fi

while getopts "c:l:f:usodtzh" option; do
	case "$option" in
		c)	# override chain name
			CHAIN="$OPTARG"
			;;
		
		l)  # override list of block list URLs
			URLS="$OPTARG"
			;;

		f)  # override rule cache file path
			CACHE_FILE="$OPTARG"
			;;
		
		u)  # update block list
			set_mode download_rules_and_update_iptables
			;;
		
		s)  # skip failed blocklist downloads
			SKIP_FAILED_DOWNLOADS=1
			;;
		
		o)  # download the rules to the cache file, and don't update iptables
			set_mode download_rules
		    ;;
		
		d)  # delete the iptables chain
			set_mode delete_chain
		    ;;

		t)  # disable iptables logging
			LOG_BLOCKLIST_HITS=0
			;;
		
		z)  # update iptables from local cache without downloading
		    set_mode update_iptables
			;;

		h)  # show usage information
		    usage
		    die
		    ;;
		
		:)
			error "Error: -${OPTARG} requires an argument."
			usage
			die
			;;
		
		*)
			error "Invalid argument -${OPTARG} supplied."
			usage
			die
			;;
	esac
done

if [ -z "$MODE" ]; then
	usage 1
fi
$MODE
