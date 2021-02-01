#!/usr/bin/env bash

##################################################
# Name: functions.sh
# Description: useful shell functions
##################################################

#########################
# Common
#########################

checkBin() {

	# Checks the binary name is available in the path

	local COMMAND="$1"

	#if ( command -v "${COMMAND}" 1> /dev/null ) ; # command breaks with aliases
	if ( type -P "${COMMAND}" &> /dev/null ) ;
	then
		writeLog "DEBUG" "The command $COMMAND is available in the Path"
		return 0
	else
		writeLog "DEBUG" "The command $COMMAND is not available in the Path"
		return 1
	fi

}

checkReqs() {

	# Make sure all the required binaries are available within the path
	for BIN in "${REQ_BINS[@]}" ;
	do
		writeLog "DEBUG" "Checking for dependant binary ${BIN}"
		checkBin "${BIN}" || { writeLog "ERROR" "Please install the ${BIN} binary on this system in order to run ${SCRIPT}" ; return 1 ; }
	done

	return 0

}

checkPermissions () {

	# Checks if the user is running as root

	if [ "${EUID}" -ne 0 ] ;
	then
		return 1
	else
		return 0
	fi

}

checkLogLevel() {

	# Only the following log levels are supported.
	#   DEBUG
	#   INFO or INFORMATION
	#   WARN or WARNING
	#   ERR or ERROR

	local LEVEL="${1}"
	export LOGLEVEL

	# POSIX be gone!
	# LOGLEVEL="$( echo "${1}" | tr '[:lower:]' '[:upper:]' )"
	case "${LEVEL^^}" in

		"DEBUG" | "TRACE" )

			export LOGLEVEL="DEBUG"

		;;

		"INFO" | "INFORMATION" )

			export LOGLEVEL="INFO"

		;;

		"WARN" | "WARNING" )

			export LOGLEVEL="WARN"

		;;

		"ERR" | "ERROR" )

			export LOGLEVEL="ERR"

		;;

		* )

			writeLog "INFO" "An unknown log level of ${LEVEL^^} was provided, defaulting to INFO"
			export LOGLEVEL="INFO"

		;;

	esac

	return 0

}

writeLog() {


	local LEVEL="${1}"
	local MESSAGE="${2}"

	case "${LEVEL^^}" in

		"DEBUG" | "TRACE" )

			LEVEL="DEBUG"

			# Do not show debug messages if the level is > debug
			if [ ! "${LEVEL^^}" = "${LOGLEVEL^^}" ] ;
			then
				return 0
			fi

		;;

		"INFO" | "INFORMATION" )

			LEVEL="INFO"

			# Do not show info messages if the level is > info
			if [ "${LOGLEVEL^^}" = "WARN" ] || [ "${LOGLEVEL^^}" = "ERR" ] ;
			then
				return 0
			fi

		;;

		"WARN" | "WARNING" )

			LEVEL="WARN"

			# Do not show warn messages if the level is > warn
			if [ "${LOGLEVEL^^}" = "ERR" ] ;
			then
				return 0
			fi

		;;

		"ERR" | "ERROR" )

			LEVEL="ERR"

			# Errors are always shown

		;;

		* )

			MESSAGE="Unknown log level ${LEVEL^^} provided to log function. Valid options are DEBUG, INFO, WARN, ERR"
			LEVEL="ERR"

		;;

	esac

	echo "$( date +"%Y/%m/%d %H:%M:%S" ) [${LEVEL^^}] ${MESSAGE}"

	return 0

}

checkVarEmpty() {

	# Returns 0 if the variable is empty

	local VAR_NAME="${1}"
	local VAR_DESC="${2}"

	if [ "${VAR_NAME:-EMPTY}" = "EMPTY" ];
	then

		writeLog "ERROR" "The variable ${VAR_DESC} is empty."
		return 0

	fi

	return 1

}

checkResult () {

	local RESULT="${1}"

	if [ "${RESULT}" -ne 0 ];
	then
		return 1
	else
		return 0
	fi

}

#########################
# Specific
#########################

usage() {

	cat <<- EOF

	# Kaniko

	Flags:
	    --build-arg multi-arg type                  This flag allows you to pass in ARG values at build time. Set it repeatedly for multiple values.
	    --cache                                     Use cache when building image
	    --cache-dir string                          Specify a local directory to use as a cache. (default "/cache")
	    --cache-repo string                         Specify a repository to use as a cache, otherwise one will be inferred from the destination provided
	    --cache-ttl duration                        Cache timeout in hours. Defaults to two weeks. (default 336h0m0s)
	    --cleanup                                   Clean the filesystem at the end
	-c, --context string                            Path to the dockerfile build context. (default "/workspace/")
	    --context-sub-path string                   Sub path within the given context.
	-d, --destination multi-arg type                Registry the final image should be pushed to. Set it repeatedly for multiple destinations.
	    --digest-file string                        Specify a file to save the digest of the built image to.
	-f, --dockerfile string                         Path to the dockerfile to be built. (default "Dockerfile")
	    --force                                     Force building outside of a container
	-h, --help                                      help for executor
	    --image-name-with-digest-file string        Specify a file to save the image name w/ digest of the built image to.
	    --insecure                                  Push to insecure registry using plain HTTP
	    --insecure-pull                             Pull from insecure registry using plain HTTP
	    --insecure-registry multi-arg type          Insecure registry using plain HTTP to push and pull. Set it repeatedly for multiple registries.
	    --label multi-arg type                      Set metadata for an image. Set it repeatedly for multiple labels.
	    --log-format string                         Log format (text, color, json) (default "color")
	    --log-timestamp                             Timestamp in log output
	    --no-push                                   Do not push the image to the registry
	    --oci-layout-path string                    Path to save the OCI image layout of the built image.
	    --registry-certificate key-value-arg type   Use the provided certificate for TLS communication with the given registry. Expected format is 'my.registry.url=/path/to/the/server/certificate'.
	    --registry-mirror string                    Registry mirror to use has pull-through cache instead of docker.io.
	    --reproducible                              Strip timestamps out of the image to make it reproducible
	    --single-snapshot                           Take a single snapshot at the end of the build.
	    --skip-tls-verify                           Push to insecure registry ignoring TLS verify
	    --skip-tls-verify-pull                      Pull from insecure registry ignoring TLS verify
	    --skip-tls-verify-registry multi-arg type   Insecure registry ignoring TLS verify to push and pull. Set it repeatedly for multiple registries.
	    --skip-unused-stages                        Build only used stages if defined to true. Otherwise it builds by default all stages, even the unnecessaries ones until it reaches the target stage / end of Dockerfile
	    --snapshotMode string                       Change the file attributes inspected during snapshotting (default "full")
	    --tarPath string                            Path to save the image in as a tarball instead of pushing
	    --target string                             Set the target build stage to build
	-v, --verbosity string                          Log level (trace, debug, info, warn, error, fatal, panic) (default "info")
	    --whitelist-var-run                         Ignore /var/run directory when taking image snapshot. Set it to false to preserve /var/run/ in destination image. (Default true). (default true)

	EOF

	return 0

}

#########################
# Export
#########################

# Export common functions
export -f checkBin checkReqs checkPermissions checkLogLevel writeLog checkVarEmpty checkResult

# Export specific functions
export -f usage

#########################
# End
#########################

writeLog "INFO" "Sourced and exported functions.sh"
