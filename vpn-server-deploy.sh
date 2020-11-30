
#!/bin/bash
# a script that create a VPC peering between VPC and RDS.
set -e # exit on error

# Helper functions
echoerr() { 
    tput bold;
    tput setaf 1;
    echo "$@";
    tput sgr0; 1>&2; }
# Prints success/info $MESSAGE in green foreground color
#
# For e.g. You can use the convention of using GREEN color for [S]uccess messages
green_echo() {
    echo -e "\x1b[1;32m[S] $SELF_NAME: $MESSAGE\e[0m"
}

simple_green_echo() {
    echo -e "\x1b[1;32m$MESSAGE\e[0m"
}
blue_echo() {
    echo -e "\x1b[1;34m[I] $SELF_NAME: $MESSAGE\e[0m"
}

simple_blue_echo() {
    echo -e "\x1b[1;34m$MESSAGE\e[0m"
}
# Define Directory
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_usage() {
 
print_usage() {
    echo "Create VPC then deploy softether vpn server"
    echo "  --vpn_vpc_name=          |   - Name for Vpn Vpc stack. Keep name convention: tp-dev-vpn-vpc"
    echo "  --vpn-vpc-cidr-block=    |   - VPN VPC IPv4 CIDR. Class B of VPC (10.XXX.0.0/16). Pay attention.Should be not owerwite EKS CIDR."
    echo "  --vpn-name=              |   - Name for Vpn server stack. Keep name convention: tp-dev-vpn-server"
    echo "  --vpn-pre-shared-key=    |   - Specify the IPsec Pre-Shared Key."
    echo "  --instance-type=         |   - Chooce what instance type to use. Recomended: for dev - t3a.small . For production - t3a.medium  "    
    echo "  --ssh-key-name=          |   - AWS ssh key name for accessing vpn instance over ssh."  
    echo "  --subdomain=             |   - Subdomain for Vpn server. Currently not used." 
    echo "  --vpn-admin-password=    |   - VPNAdminPassword" 
    echo "  --vpn-user-name=         |   - We creating some default user for easyly testing: VPNUserName" 
    echo "  --vpn-user-password=     |   - VPNUserPassword"  
    echo "  --default-region=        |   - region for cluster deployment (e.g us-east-1)"
    echo "  --aws_access_key_id=     |   - AWS access key"
    echo "  --aws_secret_access_key= |   - AWS secret key"    
    echo "  --force                  |   - Force the operation (don't wait for user input)"
    echo ""
    echo "If AWS credentials already added to the environment (cat ~/.aws/credentials) we can leave blank  the [--aws_access_key_id==] and [--aws_secret_access_key=] parameters"
    echo "Example usage: ./$(basename $0) --vpn_vpc_name=dev-vpn-vpc --vpn-vpc-cidr-block=7 --vpn-name=dev-vpn-server --vpn-pre-shared-key=test --instance-type=t3a.small --ssh-key-name=vpn-test --subdomain=vpn.dev --vpn-admin-password=12345678 --vpn-user-name=user1 --vpn-user-password=12345678 --default-region=us-east-1 --aws_access_key_id= --aws_secret_access_key="
}

# Prepare env and path solve the docker copy on windows when using bash
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        MYPATH=$PWD
        echo "Operation System dedected is:$OSTYPE"
        echo "MYPATH set to: $MYPATH"
        echo "HOME set to: $HOME"
elif [[ "$OSTYPE" == "darwin"* ]]; then
        # Mac OSX
        MYPATH=$PWD
        echo "Operation System dedected is:$OSTYPE"
        echo "MYPATH set to: $MYPATH"
        echo "HOME set to: $HOME"
elif [[ "$OSTYPE" == "cygwin" ]]; then
        # POSIX compatibility layer and Linux environment emulation for Windows
        MYPATH="$(cygpath -w $PWD)"
        HOME="$(cygpath -w $HOME)"
        echo "Operation System dedected is:$OSTYPE"
        echo "MYPATH set to: $MYPATH"
        echo "HOME set to: $HOME"
elif [[ "$OSTYPE" == "msys" ]]; then
        # Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
        MYPATH="$(cygpath -w $PWD)"
        HOME="$(cygpath -w $HOME)"
        echo "Operation System dedected is:$OSTYPE"
        echo "MYPATH set to: $MYPATH"
        echo "HOME set to: $HOME"
elif [[ "$OSTYPE" == "win32" ]]; then
        # I'm not sure this can happen.
        MYPATH="$(cygpath -w $PWD)"
        HOME="$(cygpath -w $HOME)"
        echo "Operation System dedected is:$OSTYPE"
        echo "MYPATH set to: $MYPATH"
        echo "HOME set to: $HOME"
elif [[ "$OSTYPE" == "freebsd"* ]]; then
        MYPATH=$PWD
        echo "Operation System dedected is:$OSTYPE"
        echo "MYPATH set to: $MYPATH"
        echo "HOME set to: $HOME"
fi
# Parse command line arguments
for i in "$@"
do
case $i in
    -h|--help)
    print_usage
    exit 0
    ;;
    -e=*|--env=*)
    VPN_CLIENT_ENV="${i#*=}"
    shift # past argument=value
    ;;
    -vpc=*|--vpn_vpc_name=*)
    VPN_VPC_STACK_NAME="${i#*=}"
    shift # past argument=value
    ;;
    -v=*|--vpn-vpc-cidr-block=*)
    VPN_VPC_CIDR_BLOCK="${i#*=}"
    shift # past argument=value
    ;;
    -vpn=*|--vpn_name=*)
    VPN_STACK_NAME="${i#*=}"
    shift # past argument=value
    ;;
    -pks=*|--vpn-pre-shared-key=*)
    VPN_PRE_SHARED_KEY="${i#*=}"
    shift # past argument=value
    ;;    
    -i=*|--instance-type==*)
    VPN_SERVER_INATANCE_TYPE="${i#*=}"
    shift # past argument=value
    ;;
    -k=*|--ssh-key-name=*)
    SSH_KEY_NAME="${i#*=}"
    shift # past argument=value
    ;;
    -s=*|--subdomain=*)
    SUBDOMAIN="${i#*=}"
    shift # past argument=value
    ;;
    -p=*|--vpn-admin-password=*)
    VPN_ADMIN_PASSWORD="${i#*=}"
    shift # past argument=value
    ;;
    -u=*|--vpn-user-name=*)
    VPN_USERNAME="${i#*=}"
    shift # past argument=value
    ;;
    -up=*|--vpn-user-password=*)
    VPN_USER_PASSWORD="${i#*=}"
    shift # past argument=value
    ;;
    -key_id=*|--aws_access_key_id=*)
    AWS_ACCESS_KEY_ID="${i#*=}"
    shift # past argument=value
    ;;
    -access_key=*|--aws_secret_access_key=*)
    AWS_SECRET_ACCESS_KEY="${i#*=}"
    shift # past argument=value
    ;;
    -r=*|--default-region=*)
    AWS_REGION="${i#*=}"
    shift # past argument=value
    ;;
    -f|--force)
    FORCE=1
    ;;
    *)
    echoerr "ERROR: Unknown argument"
    print_usage
    exit 1
    # unknown option
    ;;
esac
done
### Print total arguments and their values
# Validate mandatory input
if [ -z "$MYPATH" ]; then
    echoerr "Error: local path is not set"
    print_usage
    exit 1
fi
if [ -z "${VPN_VPC_STACK_NAME}" ]; then
    echoerr "Vpn Vpc cloudformation stack name required! Use name convention like: tp-dev-vpn-vpc"
    print_usage
    exit 1
 fi
 if [ -z "${VPN_STACK_NAME}" ]; then
    echoerr "vpn stack name required! Use name convention like: tp-dev-vpn-server"
    print_usage
    exit 1
 fi
if [ -z "${VPN_SERVER_INATANCE_TYPE}" ]; then
    echoerr "Aws instance type is required! "
    print_usage
    exit 1
 fi
 if [ -z "$AWS_REGION" ]; then
    echoerr "Error: AWS_REGION is not set"
    print_usage
    exit 1
fi
if [ -z "${VPN_CLIENT_ENV}" ]; then
    echoerr "Target environment not selected!"
    print_usage
    exit 1
elif [[ "${VPN_CLIENT_ENV}" != "dev" && "${VPN_CLIENT_ENV}" != "prd" ]]; then
    echoerr "Unsupported environment: ${VPN_CLIENT_ENV} , supported ([dev] or [prd]) "
    exit 1
fi
if [ -z "${VPN_VPC_CIDR_BLOCK}" ]; then
  echoerr "VPN Client IPv4 CIDR , only number between 7-9"
  print_usage
  exit 1
fi
 if [ -z "$SSH_KEY_NAME" ]; then
    echoerr "Error: AWS ssh key name for accessing vpn instance over ssh is missed"
    print_usage
    exit 1
fi
 if [ -z "$SUBDOMAIN" ]; then
    echoerr "SUBDOMAIN is missed"
    print_usage
    exit 1
fi

 if [ -z "$VPN_ADMIN_PASSWORD" ]; then
    echoerr "VPN_ADMIN_PASSWORD not provided."
    print_usage
    exit 1
fi
 if [ -z "$VPN_USERNAME" ]; then
    echoerr "VPN_USERNAME not provided."
    print_usage
    exit 1
fi
 if [ -z "$VPN_USER_PASSWORD" ]; then
    echoerr "VPN_USER_PASSWORD not provided."
    print_usage
    exit 1
fi
 # recreate the container with the configuration directory contains setup files and aws credentials.
CONTAINER_ID=$(\
docker run  \
  -v ~/.aws/credentials:/root/.aws/credentials:ro \
  -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
  -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
  -t -d testproject-aws-tools \
  ) &&  echo "Container running with id: $CONTAINER_ID"
MESSAGE="- - - Stage 1: Create VPN VPC " ; blue_echo
echo -e "Please wait....."

# Create environments directory and copy cloud formation template files to runnung container
docker cp environments/. $CONTAINER_ID:/environments
VPN_VPC_STACK_TEMPLATE="/environments/${VPN_CLIENT_ENV}/vpc-vpn-2azs.yaml"
echo "CloudFormation template for VPN VPC we going to use: $VPN_VPC_STACK_TEMPLATE"
# Validating
 #echo "Validating AWS client VPN template (executed on docker)..."
 # docker exec -it $CONTAINER_ID bash \
 # -c "aws cloudformation validate-template --template-body  file://$VPN_VPC_STACK_TEMPLATE --output text --region $AWS_REGION"  1> /dev/null
 # [ $? -eq 0 ] || { echoerr "Stack validation failed!"; exit 1; }

echo "Starting Cloudformation deploymnet."
COMMAND="aws cloudformation --region $AWS_REGION deploy \
  --stack-name $VPN_VPC_STACK_NAME \
  --template-file  $VPN_VPC_STACK_TEMPLATE\
  --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND \
  --parameter-overrides \
        ClassB=$VPN_VPC_CIDR_BLOCK \
  --tags Name=$VPN_VPC_STACK_NAME    
"
echo "$COMMAND"
# Execute
docker exec -it $CONTAINER_ID bash \
-c "${COMMAND}"
## Find the Stack ID
 VPN_VPC_STACK_ID=$(docker exec  -ti $CONTAINER_ID bash -c " \
 aws cloudformation describe-stacks --region $AWS_REGION \
--stack-name $VPN_VPC_STACK_NAME   | jq -r '.Stacks[].StackId'")
 echo $VPN_VPC_STACK_ID
 echo -e "\x1b[1;32m[S]Waiting on ${VPN_VPC_STACK_ID} creation completion...\e[0m"
 docker exec -it $CONTAINER_ID bash -c " \
 aws cloudformation --region $AWS_REGION \
 wait stack-create-complete --stack-name ${VPN_VPC_STACK_ID}; \
 aws cloudformation --region $AWS_REGION  \
 describe-stacks --stack-name ${VPN_VPC_STACK_ID} | jq .Stacks[0].Parameters"

### If successful - return  VPC ID
 echo "Checking if VPN VPC stack was actual created"
 VPN_VPC_ID=$(docker exec  -ti $CONTAINER_ID  aws cloudformation describe-stacks \
--region $AWS_REGION \
--stack-name $VPN_VPC_STACK_NAME \
--output text --query "Stacks[0].Outputs[?OutputKey=='VPC'].OutputValue")  1> /dev/null
[ $? -eq 0 ] || { echoerr "VPN VPC creation failed!"; exit 1; }
MESSAGE="Stack created successfully  VPN VPC ID: $VPN_VPC_ID" ; simple_green_echo
####### End Stage1 VPN VPC creation ########
####### Start Stage2 ########
MESSAGE="- - - Stage 2: Deploying SoftEther vpn server to created VPN VPC " ; blue_echo
echo -e "Please wait....."
docker cp environments/. $CONTAINER_ID:/environments
VPN_SERVER_STACK_TEMPLATE="/environments/${VPN_CLIENT_ENV}/vpn_bastion.yaml"
echo "CloudFormation template for VPN VPC we going to use: $VPN_SERVER_STACK_TEMPLATE"

echo "Starting Cloudformation deploymnet."
COMMAND2="aws cloudformation --region $AWS_REGION deploy \
  --stack-name $VPN_STACK_NAME \
  --template-file  $VPN_SERVER_STACK_TEMPLATE\
  --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND \
  --parameter-overrides \
        InstanceType=$VPN_SERVER_INATANCE_TYPE \
        KeyName=$SSH_KEY_NAME \
        ParentVPCStack=$VPN_VPC_STACK_NAME \
        SubDomainNameWithDot=$SUBDOMAIN \
        VPNPSK=$VPN_PRE_SHARED_KEY \
        VPNAdminPassword=$VPN_ADMIN_PASSWORD \
        VPNUserName=$VPN_USERNAME \
        VPNUserPassword=$VPN_USER_PASSWORD \
  --tags Name=$VPN_STACK_NAME   
"
echo "$COMMAND2"
# Execute
docker exec -it $CONTAINER_ID bash \
-c "${COMMAND2}"
## Find the Stack ID
 VPN_SERVER_STACK_ID=$(docker exec  -ti $CONTAINER_ID bash -c " \
 aws cloudformation describe-stacks --region $AWS_REGION \
--stack-name $VPN_STACK_NAME   | jq -r '.Stacks[].StackId'")
 echo $VPN_SERVER_STACK_ID
 echo -e "\x1b[1;32m[S]Waiting on ${VPN_SERVER_STACK_ID} creation completion...\e[0m"
 docker exec -it $CONTAINER_ID bash -c " \
 aws cloudformation --region $AWS_REGION \
 wait stack-create-complete --stack-name ${VPN_SERVER_STACK_ID}; \
 aws cloudformation --region $AWS_REGION  \
 describe-stacks --stack-name ${VPN_SERVER_STACK_ID} | jq .Stacks[0].Parameters"

### If successful - return  VPC ID
 echo "Checking if VPN Server stack was actual created"
 VPN_SERVER_IP=$(docker exec  -ti $CONTAINER_ID  aws cloudformation describe-stacks \
--region $AWS_REGION \
--stack-name $VPN_STACK_NAME \
--output text --query "Stacks[0].Outputs[?OutputKey=='IPAddress'].OutputValue")  1> /dev/null
[ $? -eq 0 ] || { echoerr "VPN VPC creation failed!"; exit 1; }
MESSAGE="Stack created successfully. We can access that server by IPAddress: $VPN_SERVER_IP" ; simple_green_echo
####### End Stage2 VPN SERVER creation ########

# We are done - Removing container 
docker rm -f $CONTAINER_ID &>/dev/null && echo "We are done - container removed"
