#! /bin/bash

__logfiles=""
__logpath=""
__logszipped=false
__logpipe=""
__logsredirected=false
__logredirfile=""

function die()
{
    ${__logsredirected} && end_log_redirect
    echo "ERROR! ${1}" >&2
    exit 1
}

# Initialise logging by creating an empty folder
# $1 should contain the base path for log files
function init_logging()
{
	[[ -n "${__logpath}" ]] && die "Logging already initialised."
	[[ -z "${1}" ]] && die "A valid path must be supplied to init_logging()"

	__logpath="${1}"
	mkdir -p "${__logpath}" 2>/dev/null || die "Unable to create ${__logpath} in init_logging()" 
	[[ ! -w ${__logpath} ]] && die "Unable to write to ${__logpath} in init_logging()"

	rm "${__logpath}"/* -f || die "Unable to remove all files in ${__logpath} in init_logging()"
}

# Redirect stdout and stderr to a file.
# $1 should contain the name of the file to log to 
function redirect_output_to_file()
{
	[[ -z "${1}" ]] && die "log file name required when calling redirect_output_to_file()"
	${__logsredirected} && die "logs already redirected in redirect_output_to_file()"
	[[ -z "${__logpath}" ]] && die "Logging not initialised in redirect_output_to_file() - you must call init_logging() first"
	
	# Store the current stdout and stderr file descriptors and redirect both to the log.
	__logredirfile="${1}"
	exec 5<&1 6<&2
	exec 1>> "${__logpath}/${__logredirfile}"
	exec 2>> "${__logpath}/${__logredirfile}"
	
	__logsredirected=true
}

# Tee stdout and stderr to a file and stdout.
# $1 should contain the name of the file to log to 
function tee_output_to_file_stdout()
{
	[[ -z "${1}" ]] && die "log file name required when calling tee_output_to_file_stdout()"
	${__logsredirected} && die "logs already redirected in tee_output_to_file_stdout()"
    [[ -z "${__logpath}" ]] && die "Logging not initialised in tee_output_to_file_stdout() - you must call init_logging() first"

	# Store the current stdout file descriptor.
	exec 5<&1 6<&2
	
	# Tee a randomly named pipe to the log and stdout
	__logpipe="/tmp/outloger_$(uuidgen -t).pipe"
	__logredirfile="${1}"
	trap 'rm -f ${__logpipe}' EXIT
	mknod "${__logpipe}" p
	tee < "${__logpipe}" "${__logpath}/${__logredirfile}" &
	
	# Redirect stdout and stderr to the pipe
	exec 1>> "${__logpipe}"
	exec 2>> "${__logpipe}"
	
	__logsredirected=true
}

# Execute a command and log stdout and stderr to files
# $1 should contain the base file name
# $2+ should contain the command to execute and any parameters
# If the log files are zero size they are deleted, any remaining log files are
# added to __logfiles list.
function exec_and_log()
{
	[[ -z "${1}" ]] && die "A file name is expected when calling exec_and_log()"
	[[ -z "${2}" ]] && die "A command is expected when calling exec_and_log()"
    [[ -z "${__logpath}" ]] && die "Logging not initialised when calling exec_and_log() - you must call init_logging() first"

	l1="${__logpath}/${1}.out.log"
	l2="${__logpath}/${1}.err.log"
	
	shift
	eval "${@}" 1>> "$l1" 2>> "$l2"
	rs=$?

	[[ ! -s ${l1} ]] && rm "${l1}" -f
	[[ ! -s ${l2} ]] && rm "${l2}" -f
	
	[[ -e ${l1} ]] && __logfiles="${__logfiles} ${l1}"
	[[ -e ${l2} ]] && __logfiles="${__logfiles} ${l2}"
	
	return $rs
}

# Add auxilery log files to the list
# $1 should contain the base file name
function add_aux_logs()
{
    [[ -z "${1}" ]] && die "A file name is expected when calling add_aux_logs()"
	[[ -z "${__logpath}" ]] && die "Logging not initialised when calling add_aux_logs() - you must call init_logging() first"
	
	logs=( "${__logpath}"/"${1}".*.aux.*.log )
	for l in "${logs[@]}"
	do
		[[ ! -s ${l} ]] && rm "${l}" -f
		[[ -e ${l} ]] && __logfiles="${__logfiles} ${l}"
	done
}

# End the redirection of logging configured using redirect_output_to_file() or tee_output_to_file_stdout()
function end_log_redirect()
{ 
	${__logsredirected} || die "logs not redirected when calling end_log_redirect()"

	# End logging redirect by restoring stdout and stderr and killing the pipe if there is one
	[[ -n "${__logpipe}" ]] && rm -f "${__logpipe}"
	sleep 0.1
	exec 1>&5 2>&6

	__logsredirected=false
}

# Bzip log files greater then a specified size
# $1 should contain the minimum size of the log before bzip will be used
function bzip_large_logs()
{
    (( "${1}" == 0 )) && die "A minimum size (in bytes) is required when calling bzip_large_logs()"
    [[ -z "${__logpath}" ]] && die "Logging not initialised when calling bzip_large_logs()"
	${__logszipped} && die "Logs already bzipped when calling bzip_large_logs()"

	nlf=""
	for lf in ${__logfiles}
	do
		fs=$(stat -c%s "${lf}")
		(( fs > ${1} )) && bzip2 -9 "${lf}" && nlf="${nlf} ${lf}.bz2"
		(( fs <= ${1} )) && nlf="${nlf} ${lf}"
	done
	__logfiles="${nlf}"
	__logszipped=true
}

# Returns a list of log files in $1
function get_log_files()
{
	[[ -z "${__logpath}" ]] && die "Logging not initialised when calling get_log_files()"

	export OFS="|"
	eval "$1=\"${__logfiles}\""
	unset OFS
}

# Send the logs by email
# $1 should contain the message subject
# $2 should contain the recipient
function send_logs_by_email()
{
	[[ -z "${__logpath}" ]] && die "Logging not initialised when calling send_logs_by_email()"
	[[ -z "${__logredirfile}" ]] && die "send_logs_by_email() requires logs to be redirected first"
	[[ -z "${1}" ]] && die "send_logs_by_email() requires a subject as parameter 1"
	[[ -z "${2}" ]] && die "send_logs_by_email() requires a recipient as parameter 2"

	mutt -s "${1}" \
         -a "${__logfiles}" \
         -- "${2}" < "${__logpath}/${__logredirfile}"
}

# Displays a list of the log files.
function display_log_paths()
{
	echo "Logs can be found at:"
	[[ -n "${__logsredirected}" ]] && echo "    ${__logpath}/${__logredirfile}"
	for lf in ${__logfiles}
	do
		echo "    ${lf}"
	done
}

# Removes all log files
function clean_up_logs()
{
	[[ -z "${__logpath}" ]] && die "Logging not initialised when calling clean_up_logs()"

	for lf in ${__logfiles}
	do
		rm "${lf}"
	done
}
