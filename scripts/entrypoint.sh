#!/usr/bin/env bash

##################################################
# Name: entrypoint.sh
# Description: Wrapper for running Kaniko
##################################################

##################################################
# NOTES:
#
# This will always create the following tags each run
#	* latest
#	* image_tag (taken as an argument)
#
# If the extra image tags are enabled, adds these additional
#	* Branch name
#	* Special
#
##################################################

##################################################
# Variables
# REMINDER: https://i.stack.imgur.com/T2Fp8.png
##################################################

# Get a script name for the logs
export SCRIPT=${0##*/}

# Common
export LOGLEVEL="${INPUT_LOGLEVEL:=INFO}"
export ORGANIZATION="${GITHUB_REPOSITORY%%/*}"
export REPOSITORY="${GITHUB_REPOSITORY##*/}"

# Registry
export REGISTRY="${INPUT_REGISTRY:=ghcr.io}"
export REGISTRY_USERNAME="${INPUT_REGISTRY_USERNAME:=$GITHUB_ACTOR}"
export REGISTRY_PASSWORD="${INPUT_REGISTRY_PASSWORD:=$GITHUB_TOKEN}"
export NAMESPACE="${INPUT_REGISTRY_NAMESPACE:=$ORGANIZATION}"

# Image Name and Tags
export IMAGE_NAME="${INPUT_IMAGE_NAME:=$REPOSITORY}"
export IMAGE_TAG_PREFIX"${INPUT_IMAGE_TAG_PREFIX}"
export IMAGE_TAG="${INPUT_IMAGE_TAG##$IMAGE_TAG_PREFIX}"
export IMAGE_TAG_EXTRA="${INPUT_IMAGE_TAG_EXTRA:=FALSE}"
export GIT_BRANCH_SOURCE="${GITHUB_HEAD_REF}"
export GIT_BRANCH_DEST="${GITHUB_DEST_REF}"
export GIT_BRANCH_FULL="${GITHUB_REF}"
export GIT_BRANCH="${GITHUB_REF##*/}"

# Kaniko Cache
export CACHE_ENABLED="${INPUT_CACHE_ENABLED:=FALSE}"
export CACHE_TTL="${INPUT_CACHE_TTL:=336h0m0s}"
export CACHE_REPO="${INPUT_CACHE_REPO:=kaniko-cache}"
export CACHE_DIRECTORY="${INPUT_CACHE_DIRECTORY:=/cache}"

# Kaniko Other
export DOCKERFILE="${INPUT_DOCKERFILE:=Dockerfile}"
export CONTEXT="${GITHUB_WORKSPACE}"
export EXTRA_ARGS="${INPUT_EXTRA_ARGS}"

# Prepare the password in the correct format
REGISTRY_AUTH=$( echo -n "${REGISTRY_USERNAME}:${REGISTRY_PASSWORD}" | base64 )
export REGISTRY_AUTH

#########################
# Declarations
#########################

# All the required external binaries for this script to work.
declare -r REQ_BINS=(
	echo
	date
	git
	gpg
)

#########################
# Pre-reqs
#########################

# Import the required functions
# shellcheck source=functions.sh
source "/scripts/functions.sh" || { echo "Failed to source dependant functions!" ; exit 1 ; }

checkLogLevel "${LOGLEVEL}" || { writeLog "ERROR" "Failed to check the log level" ; exit 1 ; }

checkReqs || { writeLog "ERROR" "Failed to check all requirements" ; exit 1 ; }

# Used if the CI is running a simple test
case "${1,,}" in

	version )
		/kaniko/executor "${1}" || { writeLog "ERROR" "Failed to show Kaniko version!" ; exit 1 ; }
		exit 0
	;;

	*help | *usage )
		usage
		exit 0
	;;

esac

#########################
# Debug
#########################

if [ "${ACTION:-FALSE}" == "TRUE" ];
then

	writeLog "INFO" "Running in GitHub Actions"

fi

if [ "${LOGLEVEL}" == "DEBUG" ];
then

	writeLog "DEBUG" "Dumping diagnostic information for shell ${SHELL} ${BASH_VERSION}"

	writeLog "DEBUG" "########## Environment ##########"
	env

	writeLog "DEBUG" "########## Exported Variables ##########"
	export

	writeLog "DEBUG" "########## Exported Function Names ##########"
	declare -x -F

	writeLog "DEBUG" "########## Exported Function Contents ##########"
	export -f

fi

#########################
# Main
#########################

# Check the minimum required variables are populated
checkVarEmpty "${REGISTRY}" "Registry" && exit 1
checkVarEmpty "${REGISTRY_USERNAME}" "Username" && exit 1
checkVarEmpty "${REGISTRY_PASSWORD}" "Password" && exit 1
checkVarEmpty "${IMAGE_NAME}" "Image Name" && exit 1

#########################
# Registry and Image Name
#########################

writeLog "INFO" "Applying settings for Container registry ${REGISTRY,,}"

# Adjust any special settings for certain package registries
case "${REGISTRY,,}" in

	docker.pkg.github.com )

		# The old GitHub package registry stores the packages at the repository level
		# Example: $REGISTRY/$ORGANIZATION/$REPOSITORY/$IMAGE_NAME
		# Example: docker.pkg.github.com/USER-OR-ORG/REPOSITORY/IMAGE_NAME

		export API_VER="v1"
		export IMAGE="${REGISTRY,,}/${ORGANIZATION,,}/${REPOSITORY,,}/${IMAGE_NAME,,}"

		# The cache needs to be stored within the same package registry
		export CACHE_REPO="${REGISTRY,,}/${ORGANIZATION,,}/${REPOSITORY,,}/${CACHE_REPO,,}"

	;;

	ghcr.io | containers.pkg.github.com )

		# The new GitHub package registry stores the packages at the organization level
		# Example: $REGISTRY/$ORGANIZATION/$IMAGE_NAME
		# Example: containers.pkg.github.com/USER-OR-ORG/IMAGE

		export API_VER="v2"
		export IMAGE="${REGISTRY,,}/${ORGANIZATION,,}/${IMAGE_NAME,,}"

		# The cache needs to be stored within the same package registry
		export CACHE_REPO="${REGISTRY,,}/${ORGANIZATION,,}/${CACHE_REPO,,}"

	;;

	docker.io )

		export API_VER="v2"

		# Correct the URL for docker hub registry access
		export REGISTRY="index.${REGISTRY,,}"

		export IMAGE="${REGISTRY,,}/${NAMESPACE,,}/${IMAGE_NAME,,}"

		# The cache needs to be stored within the same package registry
		export CACHE_REPO="${REGISTRY,,}/${NAMESPACE,,}/${CACHE_REPO,,}"

	;;

	* )

		writeLog "WARN" "Unsupported Container registry ${REGISTRY,,} detected. Attempting default settings..."

		export API_VER="v2"

		export IMAGE="${REGISTRY,,}/${NAMESPACE,,}/${IMAGE_NAME,,}"

		# The cache needs to be stored within the same package registry
		export CACHE_REPO="${REGISTRY,,}/${NAMESPACE,,}/${CACHE_REPO,,}"

	;;

esac

#########################
# Image Cache
#########################

# Set the cache variables if enabled
if [ "${CACHE_ENABLED^^}" = "TRUE" ];
then

	export CACHE_ENABLED="${CACHE_ENABLED:+--cache=true}"
	export CACHE_TTL="${CACHE_TTL:+--cache-ttl=$CACHE_TTL}"
	export IMAGE_CACHE="${CACHE_REPO:+--cache-repo=$CACHE_REPO}"
	export CACHE_DIRECTORY="${CACHE_DIRECTORY:+--cache-dir=$CACHE_DIRECTORY}"

	export CACHE_ARGS="${CACHE_ENABLED} ${CACHE_TTL} ${IMAGE_CACHE} ${CACHE_DIRECTORY}"

fi

#########################
# Kaniko Arguments
#########################

export KANIKO_LOGLEVEL="${LOGLEVEL:+--verbosity=$LOGLEVEL}"
export CONTEXT="${CONTEXT:+--context $CONTEXT}"
export DOCKERFILE="${DOCKERFILE:+--dockerfile $DOCKERFILE}"

#########################
# Kaniko Tags
#########################

# DESTINATION 1: LATEST
# CI always applies the "latest" tag
export DESTINATION1="--destination ${IMAGE}:latest"

# DESTINATION 2: IMAGE_TAG
# Apply the image tag if it was provided.
# It's the users responsibility to provide a valid tag or the CI will fail
if [ "${IMAGE_TAG:-EMPTY}" != "EMPTY" ];
then
	export DESTINATION2="--destination ${IMAGE}:${IMAGE_TAG}"
fi

# Apply opinionated tag options if enabled
if [ "${IMAGE_TAG_EXTRA^^}" == "TRUE" ];
then

	writeLog "INFO" "Applying extra tags"

	# DESTINATION 3: PR SOURCE BRANCH
	# Apply the Git Branch (Pull Request Source)
	if [ "${GIT_BRANCH_SOURCE:-EMPTY}" != "EMPTY" ];
	then

		writeLog "INFO" "Checking for Source branch match on extra tags"

		case "${GIT_BRANCH_SOURCE,,}" in

			*feature/* )
				export DESTINATION3="--destination ${IMAGE}:feature"
				writeLog "INFO" "Source branch match 'feature'"
			;;

			*bug/* )
				export DESTINATION3="--destination ${IMAGE}:bug"
				writeLog "INFO" "Source branch match 'bug'"
			;;

			*hotfix/* )
				export DESTINATION3="--destination ${IMAGE}:hotfix"
				writeLog "INFO" "Source branch match 'hotfix'"
			;;

			*release/* )
				export DESTINATION3="--destination ${IMAGE}:candidate"
				writeLog "INFO" "Source branch match 'candidate'"
			;;

			* )
				writeLog "INFO" "The Source branch ${GIT_BRANCH_SOURCE} did not match any pre-defined extra tags"
			;;

		esac

	fi

	# DESTINATION 4: TRIGGER BRANCH
	# Apply the Git Branch (Trigger)
	if [ "${GIT_BRANCH:-EMPTY}" != "EMPTY" ];
	then

		writeLog "INFO" "Checking for Trigger branch match on extra tags"

		case "${GIT_BRANCH,,}" in

			*feature/* )
				export DESTINATION4="--destination ${IMAGE}:feature"
				writeLog "INFO" "Trigger branch match 'feature'"
			;;

			*bug/* )
				export DESTINATION4="--destination ${IMAGE}:bug"
				writeLog "INFO" "Trigger branch match 'bug'"
			;;

			*hotfix/* )
				export DESTINATION4="--destination ${IMAGE}:hotfix"
				writeLog "INFO" "Trigger branch match 'hotfix'"
			;;

			*release/* )
				export DESTINATION4="--destination ${IMAGE}:candidate"
				writeLog "INFO" "Trigger branch match 'candidate'"
			;;

			* )
				# Catch all, strip invalid characters from branch name and replace with dashes.
				#export DESTINATION4="--destination ${IMAGE}:${GIT_BRANCH//\//-}"
				writeLog "INFO" "The Trigger branch ${GIT_BRANCH} did not match any pre-defined extra tags"
			;;

		esac

	fi

	# DESTINATION 5: FULL BRANCH
	# Apply the Git Branch (Trigger)
	if [ "${GIT_BRANCH_FULL:-EMPTY}" != "EMPTY" ];
	then

		writeLog "INFO" "Checking Full branch match for extra tags"

		case "${GIT_BRANCH_FULL,,}" in

			refs/heads/master | refs/heads/trunk | refs/heads/main )
				export DESTINATION5="--destination ${IMAGE}:stable"
				writeLog "INFO" "Full branch match 'stable'"
			;;&

			refs/heads/feature/* )
				export DESTINATION5="--destination ${IMAGE}:feature"
				writeLog "INFO" "Full branch match 'feature'"
			;;

			refs/heads/bug/* )
				export DESTINATION5="--destination ${IMAGE}:bug"
				writeLog "INFO" "Full branch match 'bug'"
			;;

			refs/head/hotfix/* )
				export DESTINATION5="--destination ${IMAGE}:hotfix"
				writeLog "INFO" "Full branch match 'hotfix'"
			;;

			refs/heads/release/* )
				export DESTINATION5="--destination ${IMAGE}:candidate"
				writeLog "INFO" "Full branch match 'candidate'"
			;;

			* )
				# Catch all, strip invalid characters from branch name and replace with dashes.
				#export DESTINATION5="--destination ${IMAGE}:${GIT_BRANCH_FULL//\//-}"
				writeLog "INFO" "The Full branch ${GIT_BRANCH_FULL} did not match any pre-defined extra tags"
			;;

		esac

	fi

fi

# Define the final args list to pass to Kaniko
export ARGS="${CACHE_ARGS,,} ${CONTEXT,,} ${DOCKERFILE} ${DESTINATION1,,} ${DESTINATION2,,} ${DESTINATION3,,} ${DESTINATION4,,} ${DESTINATION5,,} ${INPUT_EXTRA_ARGS,,}"

#########################
# Kaniko Credentials
#########################

writeLog "INFO" "Creating Kaniko credentials for ${REGISTRY,,}"

cat <<- EOF > "${DOCKER_CONFIG:-/kaniko/.docker/}config.json"

{
	"auths": {
		"https://${REGISTRY,,}/v1/": {
			"auth": "${REGISTRY_AUTH}"
		},
		"https://${REGISTRY,,}/v2/": {
			"auth": "${REGISTRY_AUTH}"
		}
	}
}

EOF

#########################
# Kaniko Executor
#########################

# NOTE: From Kaniko v1.0.0 onward requires '--force' to run outside a container

KANIKO_VERSION=$(/kaniko/executor version | cut -d ":" -f2)
KANIKO_VERSION="${KANIKO_VERSION//[[:space:]]/}"

writeLog "INFO" "Running Kaniko ${KANIKO_VERSION:-unknown} with the following arguments: --force ${ARGS:-unknown}"

/kaniko/executor --force ${ARGS} || { writeLog "ERROR" "Failed to run Kaniko!" ; exit 1 ; }

exit 0
