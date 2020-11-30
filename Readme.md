### Overview
This script do following:
- Creating VPC with Public and Private subnets across 2 A-Z's
```
----|A public  10.7.0.0/20  us-east-1a
----|B public  10.7.32.0/20 us-east-1d
----|A private 10.7.16.0/20 us-east-1a
----|B private 10.7.48.0/20 us-east-1d
```
- Security Group with following Inbound rules
```
----|Custom TCP	TCP	992	0.0.0.0/0	-
----|SSH	TCP	22	sg-072da09bf5ed5d657 (tp-dev-vpn-server1-SecurityGroup-1MOLWEJH3YI67)	-
----|Custom UDP	UDP	1194	0.0.0.0/0	
----|Custom TCP	TCP	5555	0.0.0.0/0	
----|Custom UDP	UDP	4500	0.0.0.0/0	
----|Custom UDP	UDP	500	    0.0.0.0/0	
----|Custom UDP	UDP	40000 - 44999	0.0.0.0/0
----|HTTPS	TCP	443	        0.0.0.0/0
```
- AWS EC2 Instance
- Deploying SoftEther server to created instance.

As result, we have SoftEther server deployed with this script to AWS by using cloudformation templates
### SoftEther Server configuration

### SoftEther Client configuration


### ToDo
1. Load pre defined softether server configuration durning deploy.
