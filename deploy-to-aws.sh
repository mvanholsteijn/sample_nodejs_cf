#!/bin/bash

#
# all functions
# 
function usage() {
	echo USAGE: $0 application-name zip-file [environment] [solution-stack]>&2
	echo $@
	exit 1
}

function getEnvDescriptor() {
	aws elasticbeanstalk describe-environments \
		--application-name "$1" \
		--environment-name "$2" | \
		jq -r '.Environments | .[]?'
}

function getEnvironmentStatus() {
	local APPNAME="$1"
	local ENV="$2"
	ENV_DESCRIPTOR=$(getEnvDescriptor "$APPNAME" "$ENV")
	ENV_STATUS=$(echo "$ENV_DESCRIPTOR" | jq -r '.Status')
}


function createApplicationIfNotExists() {
local NAME="$1"
APP_DESCRIPTOR=$(aws elasticbeanstalk describe-applications \
	--application-name "$NAME"  | \
	jq -r '.Applications | .[]?')
if [ -z "$APP_DESCRIPTOR" ] ; then
	echo INFO: creating application "$NAME"
	APP_DESCRIPTOR=$(aws elasticbeanstalk create-application \
	--application-name "$NAME" )
else
	echo INFO: application "$NAME" already exists
fi
}

function createAppEnvironmentIfNotExists() {
local NAME="$1"
local ENVNAME="$2"
local STACK="$3"
	createApplicationIfNotExists "$NAME"
	ENV_DESCRIPTOR=$(getEnvDescriptor "$NAME" "$ENVNAME")
	if [ -z "$ENV_DESCRIPTOR" ] ; then
		echo INFO: Creating environment $ENVNAME for "$NAME"
		ENV_DESCRIPTOR=$(aws elasticbeanstalk create-environment \
		--application-name "$NAME" \
		--solution-stack "$STACK" \
		--environment-name "$ENVNAME")
	else
		echo INFO: environment $ENVNAME for "$NAME" already exists
	fi
}

function determineS3BucketAndKey() {
	local FILE="$1"
	local VERSION="$2"
	S3BUCKET=$(aws elasticbeanstalk create-storage-location | jq -r '.S3Bucket')
	S3KEY=$VERSION-$(basename $FILE)
}
function uploadBinaryArtifact() {
	local APPNAME="$1"
	local FILE="$2"
	local VERSION="$3"
	determineS3BucketAndKey "$FILE" "$VERSION"
	local EXISTS=$(aws s3 ls s3://$S3BUCKET/$S3KEY)
	if [ -z "$EXISTS" ] ; then
		echo INFO: Uploading $FILE for "$APPNAME", version $VERSION.
		aws s3 cp $FILE s3://$S3BUCKET/$S3KEY
	else
		echo INFO: Version $VERSION of $FILE already uploaded.
	fi
}

function createApplicationVersionIfNotExists() {
	local APPNAME="$1"
	local VERSION="$2"
	APP_VERSION=$(
		aws elasticbeanstalk describe-application-versions \
			--application-name "$APPNAME" \
			--version-label "$APPNAME-$VERSION" | \
		jq -r '.ApplicationVersions | .[]?')

	if [ -z "$APP_VERSION" ] ; then
		echo Creating version $VERSION of application "$APPNAME"
		APP_VERSION=$(aws elasticbeanstalk create-application-version \
			--application-name "$APPNAME" \
			--version-label "$APPNAME-$VERSION" \
			--source-bundle S3Bucket=$S3BUCKET,S3Key=$S3KEY \
			--auto-create-application)
	else
		echo Version INFO: $VERSION of "$APPNAME" already exists.
	fi
}

function busyWaitEnvironmentStatus() {
	local APPNAME="$1"
	local ENV="$2"
	local STATUS="${3:-Ready}"
	getEnvironmentStatus "$APPNAME" "$ENV"
	while [ "$ENV_STATUS" != "$STATUS" ] ; do 
		echo in status $ENV_STATUS, waiting to get to $STATUS..
		sleep 5
		getEnvironmentStatus "$APPNAME" "$ENV"
	done
}

function updateEnvironment() {
	local APPNAME="$1"
	local ENV="$2"
	local VERSION="$3"
	local ENV_DESCRIPTOR=$(getEnvDescriptor "$APPNAME" $ENV)
	local ENV_VERSION=$(echo "$ENV_DESCRIPTOR" | jq -r '.VersionLabel')
	local ENV_STATUS=$(echo "$ENV_DESCRIPTOR" | jq -r '.Status')

	if [ "$ENV_VERSION" != "$APPNAME-$VERSION" ] ; then
		busyWaitEnvironmentStatus "$APPNAME" "$ENV"
		echo "Updating environment $ENV with version $VERSION of $APPNAME"
		ENV_DESCRIPTOR=$(aws elasticbeanstalk update-environment \
			--environment-name "$ENV" \
			--version-label "$APPNAME-$VERSION")
		busyWaitEnvironmentStatus "$APPNAME" "$ENV"
		echo INFO: Version $VERSION of "$APPNAME" deployed in environment
		echo INFO:  current status is $ENV_STATUS, goto http://$(echo $ENV_DESCRIPTOR | jq -r .CNAME)
	else
		echo INFO: Version $VERSION of "$APPNAME" already deployed in environment
		echo INFO:  current status is $ENV_STATUS, goto http://$(echo $ENV_DESCRIPTOR | jq -r .CNAME)
	fi
}

function checkEnvironment() {
	local APPNAME="$1"
	local ENVNAME="$2"
	local ENV_APP_NAME=$(aws elasticbeanstalk describe-environments --environment-name "$ENVNAME" | \
				jq -r ' .Environments | .[]? | .ApplicationName')
	if [ -n "$ENV_APP_NAME" -a "$APPNAME" != "$ENV_APP_NAME" ] ; then
		echo ERROR: Environment name "$ENVNAME" already taken by application "$ENV_APP_NAME".
		exit 2
	fi
}

APPNAME=$1
FILE=$2
ENV=${3:-development}
SOLUTION_STACK=${4:-64bit Amazon Linux 2014.09 v1.0.8 running Docker 1.2.0}
if [ $# -lt 2 ] ; then
	usage
fi

if [ ! -f $FILE ] ; then
	usage "$2 is not a readable file"
fi
VERSION=$(stat -f %m "$FILE")


checkEnvironment "$APPNAME" "$ENV"
createAppEnvironmentIfNotExists "$APPNAME" "$ENV" "$SOLUTION_STACK"
uploadBinaryArtifact "$APPNAME" "$FILE" "$VERSION"
createApplicationVersionIfNotExists "$APPNAME" "$VERSION"
updateEnvironment "$APPNAME" "$ENV" "$VERSION"

