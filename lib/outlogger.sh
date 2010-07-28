#! /bin/bash

__logfiles=""
__logpath=""
__logszipped=false

# Initialise logging by creating an empty folder
# $1 should contain the base path for log files
function init_logging()
{
	[[ -n "${__logpath}" ]] && echo "ERROR! Logging already initialised." >&2 && exit 127

	__logpath="${1}"
	mkdir -p ${__logpath}
	rm ${__logpath}/* -f
	
	[[ ! -w ${__logpath} ]] && echo "ERROR! Unable to write to ${__logpath}" >&2 && exit 127
}

# Execute a command and log stdout and stderr to files
# $1 should contain the base file name
# $2 should contain the command to execute
# If the log files are zero size they are deleted, any remaining log files are
# added to __logfiles list.
function exec_and_log()
{
	[[ -z "${__logpath}" ]] && echo "ERROR! Logging not initialised." >&2 && exit 127

	l1="${__logpath}/${1}.out.log"
	l2="${__logpath}/${1}.err.log"

	$( ${2} 1>> $l1 2>> $l2 )
	rs=$?

	[[ ! -s ${l1} ]] && rm ${l1} -f
	[[ ! -s ${l2} ]] && rm ${l2} -f
	
	[[ -e ${l1} ]] && __logfiles="${__logfiles} ${l1}"
	[[ -e ${l2} ]] && __logfiles="${__logfiles} ${l2}"
	
	return $rs
}

# Add auxilery log files to the list
# $1 should contain the base file name
function add_aux_logs()
{
	[[ -z "${__logpath}" ]] && echo "ERROR! Logging not initialised." >&2 && exit 127
	
	logs=${__logpath}/${1}.*.aux.*.log
	for l in ${logs}
	do
		[[ ! -s ${l} ]] && rm ${l} -f
		[[ -e ${l} ]] && __logfiles="${__logfiles} ${l}"
	done
}

# Bzip log files greater then a specified size
# $1 should contain the minimum size of the log before bzip will be used
function bzip_large_logs()
{
	[[ -z "${__logpath}" ]] && echo "ERROR! Logging not initialised." >&2 && exit 127
	if ${__logszipped} ; then echo "ERROR! Logs already bzipped." >&2 && exit 127 ; fi

	nlf=""
	for lf in ${__logfiles}
	do
		fs=$(stat -c%s "${lf}")
		(( ${fs} > ${1} )) && bzip2 -9 ${lf} && nlf="${nlf} ${lf}.bz2"
		(( ${fs} <= ${1} )) && nlf="${nlf} ${lf}"
	done
	__logfiles="${nlf}"
	__logszipped=true
}

# Returns a list of log files in $1
function get_log_files()
{
	[[ -z "${__logpath}" ]] && echo "ERROR! Logging not initialised." >&2 && exit 127 

	OFS="|"
	eval "$1=\"${__logfiles}\""
	unset OFS
}

# Removes all log files
function clean_up_logs()
{
	[[ -z "${__logpath}" ]] && echo "ERROR! Logging not initialised." >&2 && exit 127

	for lf in ${__logfiles}
	do
		rm ${lf}
	done
}
