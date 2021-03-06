#!/bin/bash
set -o pipefail
set -eu

# Check required parameters has a value
if [ -z "$INPUT_SONARPROJECTKEY" ]; then
    echo "Input parameter sonarProjectKey is required"
    exit 1
fi
if [ -z "$INPUT_SONARPROJECTNAME" ]; then
    echo "Input parameter sonarProjectName is required"
    exit 1
fi
#if [ -z "$INPUT_SONARTOKEN" ]; then
#    echo "Environment parameter SONAR_TOKEN is required"
#    echo "$INPUT_SONARTOKEN"
#    exit 1
#fi
if [ -z "$INPUT_SONARENABLESCAN" ]; then
    echo "Enable/disable sonarscan is required"
    exit 1
fi

# List Environment variables that's set by Github Action input parameters (defined by user)
echo "Github Action input parameters"
echo "INPUT_SONARPROJECTKEY: $INPUT_SONARPROJECTKEY"
echo "INPUT_SONARPROJECTNAME: $INPUT_SONARPROJECTNAME"
echo "INPUT_SONARORGANIZATION: $INPUT_SONARORGANIZATION"
echo "INPUT_DOTNETBUILDARGUMENTS: $INPUT_DOTNETBUILDARGUMENTS"
echo "INPUT_DOTNETTESTARGUMENTS: $INPUT_DOTNETTESTARGUMENTS"
echo "INPUT_DOTNETDISABLETESTS: $INPUT_DOTNETDISABLETESTS"
echo "INPUT_SONARBEGINARGUMENTS: $INPUT_SONARBEGINARGUMENTS"
echo "INPUT_SONARHOSTNAME: $INPUT_SONARHOSTNAME"
echo "INPUT_SONARENABLESCAN: $INPUT_SONARENABLESCAN"

# Environment variables that need to be mapped in Github Action 
#     env:
#       SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
#       GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
#
# SONAR_TOKEN=[your_token_from_sonarqube]
# GITHUB_TOKEN=[your_token_from_github]

# Environment variables automatically set by Github Actions automatically passed on to the docker container
#
# Example pull request
# GITHUB_REPOSITORY=theowner/therepo
# GITHUB_EVENT_NAME=pull_request
# GITHUB_REF=refs/pull/1/merge
# GITHUB_HEAD_REF=somenewcodewithouttests
# GITHUB_BASE_REF=master
#
# Example normal push
# GITHUB_REPOSITORY=theowner/therepo
# GITHUB_EVENT_NAME="push"
# GITHUB_REF=refs/heads/master
# GITHUB_HEAD_REF=""
# GITHUB_BASE_REF=""

# ---------------------------------------------
# DEBUG: How to run container manually
# ---------------------------------------------
# export SONAR_TOKEN="your_token_from_sonarqube"

# Simulate Github Action input variables  
# export INPUT_SONARPROJECTKEY="your_projectkey"
# export INPUT_SONARPROJECTNAME="your_projectname"
# export INPUT_SONARORGANIZATION="your_organization"
# export INPUT_DOTNETBUILDARGUMENTS=""
# export INPUT_DOTNETTESTARGUMENTS=""
# export INPUT_DOTNETDISABLETESTS=""
# export INPUT_SONARBEGINARGUMENTS=""
# export INPUT_SONARHOSTNAME="https://sonarcloud.io"

# Simulate Github Action built-in environment variables
# export GITHUB_REPOSITORY=theowner/therepo
# export GITHUB_EVENT_NAME="push"
# export GITHUB_REF=refs/heads/master
# export GITHUB_HEAD_REF=""
# export GITHUB_BASE_REF=""
#
# Build local Docker image
# docker build -t sonarscan-dotnet .
# Execute Docker container
# docker run --name sonarscan-dotnet --workdir /github/workspace --rm -e INPUT_SONARPROJECTKEY -e INPUT_SONARPROJECTNAME -e INPUT_SONARORGANIZATION -e INPUT_DOTNETBUILDARGUMENTS -e INPUT_DOTNETTESTARGUMENTS -e INPUT_DOTNETDISABLETESTS -e INPUT_SONARBEGINARGUMENTS -e INPUT_SONARHOSTNAME -e SONAR_TOKEN -e GITHUB_EVENT_NAME -e GITHUB_REPOSITORY -e GITHUB_REF -e GITHUB_HEAD_REF -e GITHUB_BASE_REF -v "/var/run/docker.sock":"/var/run/docker.sock" -v $(pwd):"/github/workspace" sonarscan-dotnet

#-----------------------------------
# Build Sonarscanner begin command
#-----------------------------------
if [[ "$INPUT_SONARENABLESCAN" == "true" ]]; then
    sonar_begin_cmd="sonar-scanner -Dsonar.projectKey=\"${INPUT_SONARPROJECTKEY}\" -Dsonar.projectName=\"${INPUT_SONARPROJECTNAME}\" -Dsonar.login=\"${INPUT_SONARTOKEN}\" -Dsonar.host.url=\"${INPUT_SONARHOSTNAME}\" -Dsonar.scm.provider=git"" -Dsonar.projectBaseDir=/github/workspace"
    if [ -n "$INPUT_SONARORGANIZATION" ]; then
        sonar_begin_cmd="$sonar_begin_cmd /o:\"${INPUT_SONARORGANIZATION}\""
    fi
    if [ -n "$INPUT_SONARBEGINARGUMENTS" ]; then
        sonar_begin_cmd="$sonar_begin_cmd $INPUT_SONARBEGINARGUMENTS"
    fi
    # Check Github environment variable GITHUB_EVENT_NAME to determine if this is a pull request or not. 
    if [[ $GITHUB_EVENT_NAME == 'pull_request' ]]; then
        # Sonarqube wants these variables if build is started for a pull request
        # Sonarcloud parameters: https://sonarcloud.io/documentation/analysis/pull-request/
        # sonar.pullrequest.key	                Unique identifier of your PR. Must correspond to the key of the PR in GitHub or TFS. E.G.: 5
        # sonar.pullrequest.branch	            The name of your PR Ex: feature/my-new-feature
        # sonar.pullrequest.base	            The long-lived branch into which the PR will be merged. Default: master E.G.: master
        # sonar.pullrequest.github.repository	SLUG of the GitHub Repo (owner/repo)

        # Extract Pull Request numer from the GITHUB_REF variable
        PR_NUMBER=$(echo $GITHUB_REF | awk 'BEGIN { FS = "/" } ; { print $3 }')

        # Add pull request specific parameters in sonar scanner
        sonar_begin_cmd="$sonar_begin_cmd -Dsonar.pullrequest.key=$PR_NUMBER -Dsonar.pullrequest.branch=$GITHUB_HEAD_REF -Dsonar.pullrequest.base=$GITHUB_BASE_REF -Dsonar.pullrequest.github.repository=$GITHUB_REPOSITORY -Dsonar.pullrequest.provider=github"

    fi
fi
#-----------------------------------
# Build Sonarscanner end command
#-----------------------------------
set -e

if [[ "${GITHUB_EVENT_NAME}" == "pull_request" ]]; then
	EVENT_ACTION=$(jq -r ".action" "${GITHUB_EVENT_PATH}")
	if [[ "${EVENT_ACTION}" != "opened" ]]; then
		echo "No need to run analysis. It is already triggered by the push event."
		exit
	fi
fi

# ----------------------------------
# Run Sonarscanner command
# ----------------------------------
sh -c "$sonar_begin_cmd"
