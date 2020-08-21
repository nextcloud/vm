#!/usr/bin/env bash
#
# script to prune zfs snapshots over a given age
#
# Author: Dave Eddy <dave@daveeddy.com>
# Date: November 20, 2015
# License: MIT
# https://raw.githubusercontent.com/bahamas10/zfs-prune-snapshots/master/zfs-prune-snapshots

VERSION='v1.1.0'

usage() {
	local prog=${0##*/}
	cat <<-EOF
	usage: $prog [-hnv] [-p <prefix>] [-s <suffix>] <time> [[dataset1] ...]

	remove snapshots from one or more zpools that match given criteria

	examples
	    # $prog 1w
	    remove snapshots older than a week across all zpools

	    # $prog -vn 1w
	    same as above, but with increased verbosity and without
	    actually deleting any snapshots (dry-run)

	    # $prog 3w tank1 tank2/backup
	    remove snapshots older than 3 weeks on tank1 and tank2/backup.
	    note that this script will recurse through *all* of tank1 and
	    *all* datasets below tank2/backup

	    # $prog -p 'autosnap_' 1M zones
	    remove snapshots older than a month on the zones pool that start
	    with the string "autosnap_"

	    # $prog -s '_frequent' 2M tank
	    remove snapshots older than two months on the tank pool that end
	    with the string "_frequent"

	timespec
	    the first argument denotes how old a snapshot must be for it to
	    be considered for deletion - possible specifiers are

	        s seconds
	        m minutes
	        h hours
	        d days
	        w weeks
	        M months
	        y years

	options
	    -h             print this message and exit
	    -n             dry-run, don't actually delete snapshots
	    -p <prefix>    snapshot prefix string to match
	    -s <suffix>    snapshot suffix string to match
	    -q             quiet, do not printout removed snapshots
	    -v             increase verbosity
	    -V             print the version number and exit
	EOF
}

debug() {
	((verbosity >= 1)) && echo "$@"
	return 0
}

# given a time in seconds, return the "human readable" string
human() {
	local seconds=$1
	if ((seconds < 0)); then
		((seconds *= -1))
	fi

	local times=(
	$((seconds / 60 / 60 / 24 / 365)) # years
	$((seconds / 60 / 60 / 24 / 30))  # months
	$((seconds / 60 / 60 / 24 / 7))   # weeks
	$((seconds / 60 / 60 / 24))       # days
	$((seconds / 60 / 60))            # hours
	$((seconds / 60))                 # minutes
	$((seconds))                      # seconds
	)
	local names=(year month week day hour minute second)

	local i
	for ((i = 0; i < ${#names[@]}; i++)); do
		if ((${times[$i]} > 1)); then
			echo "${times[$i]} ${names[$i]}s"
			return
		elif ((${times[$i]} == 1)); then
			echo "${times[$i]} ${names[$i]}"
			return
		fi
	done
	echo '0 seconds'
}

if ! type -P zfs &>/dev/null; then
	echo "Error! zfs command not found. Are you on the right machine?"
	exit 1
fi

dryrun=false
verbosity=0
prefix=
suffix=
quiet=false
while getopts 'hnqp:s:vV' option; do
	case "$option" in
		h) usage; exit 0;;
		n) dryrun=true;;
		p) prefix=$OPTARG;;
		s) suffix=$OPTARG;;
		q) quiet=true;;
		v) ((verbosity++));;
		V) echo "$VERSION"; exit 0;;
		*) usage; exit 1;;
	esac
done
shift "$((OPTIND - 1))"

# extract the first argument - the timespec - and
# convert it to seconds
t=$1
time_re='^([0-9]+)([smhdwMy])$'
seconds=
if [[ $t =~ $time_re ]]; then
	# ex: "21d" becomes num=21 spec=d
	num=${BASH_REMATCH[1]}
	spec=${BASH_REMATCH[2]}

	case "$spec" in
		s) seconds=$((num));;
		m) seconds=$((num * 60));;
		h) seconds=$((num * 60 * 60));;
		d) seconds=$((num * 60 * 60 * 24));;
		w) seconds=$((num * 60 * 60 * 24 * 7));;
		M) seconds=$((num * 60 * 60 * 24 * 30));;
		y) seconds=$((num * 60 * 60 * 24 * 365));;
		*) echo "error: unknown spec '$spec'" >&2; exit 1;;
	esac
elif [[ -z $t ]]; then
	echo 'error: timespec must be specified as the first argument' >&2
	exit 1
else
	echo "error: failed to parse timespec '$t'" >&2
	exit 1
fi

shift
pools=("$@")

now=$(date +%s)
code=0
while read -r creation snapshot; do
	# ensure optional prefix matches
	snapname=${snapshot#*@}
	if [[ -n $prefix && $prefix != "${snapname:0:${#prefix}}" ]]; then
		debug "skipping $snapshot: doesn't match prefix $prefix"
		continue
	fi

	# ensure optional suffix matches
	if [[ -n $suffix && $suffix != "${snapname: -${#suffix}}" ]]; then
		debug "skipping $snapshot: doesn't match suffix $suffix"
		continue
	fi

	# ensure snapshot is older than the cutoff time
	delta=$((now - creation))
	human=$(human "$delta")
	if ((delta <= seconds)); then
		debug "skipping $snapshot: $human old"
		continue
	fi

	# remove the snapshot
	if ! $quiet || $dryrun; then
		echo -n "removing $snapshot: $human old"
	fi
	if $dryrun; then
		echo ' <dry-run: no action taken>'
	else
		if ! $quiet; then
			echo
		fi
		zfs destroy "$snapshot" || code=1
	fi
done < <(zfs list -Hpo creation,name -t snapshot -r "${pools[@]}")
exit "$code"
