# 🚀 Cloud Infrastructure Engineer Challenge

## Description
This repository contains the infrastructure and application code required to deploy an API Gateway Endpoint that triggers an AWS Lambda function. The Lambda connects to an Amazon RDS (PostgreSQL) instance within a Virtual Private Cloud (VPC) to perform a simple database status check + database information gathering and then returns the result via Amazon API Gateway.
This project uses Docker Compose to create a local development environment.

## Architecture Overview
This was all done on an AWS Free Tier Subscription account.
1. A **VPC** that contains two subnets, a **private** and a **public** one.
2. The **Security Groups** for connection between resources.
3. An **RDS** database instance.
4. The necessary **IAM roles** and **policies** for the Lambda function.
5. A **Lambda** function that generates **CloudWatch** logs via the **AWSLambdaBasicExecutionRole IAM Policy**.
6. An **API Gateway** that triggers the **Lambda** function.

## Prerequisites
To deploy the solution, the following packages must be installed:
**Python3.13**, **pip**, **git**, **pre-commit**, **tflint**, **trivy (tfsec)**, **terraform** and **Docker**.

For all the terraform related binaries I used choco since I am working on a Windows machine. To install choco do the following:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

Terraform, trivy and tflint:
```powershell
choco install terraform
chocolatey install trivy
choco install tflint
```

For Git and Python I used my web browser: 

https://git-scm.com/downloads

https://www.python.org/downloads/

And then I followed the next instructions to install pip: https://pip.pypa.io/en/stable/installation/

Then I installed pre-commit using pip:
```
pip install pre-commit
```

And lastly, for Docker, I downloaded Docker Desktop: https://docs.docker.com/desktop/setup/install/windows-install/



## Decisions
During the challenge there were many decisions that I had to take and I'd like to detail my train of thought in this block.

First of all, since I was using an AWS Free Tier account, I thought it was best to first deploy everything using the UI and making sure the solution worked fine, so I started with the VPC components.
### VPC
I started with the creation of the VPC and the subnets. One would be a private subnet and the other one a public subnet.
This was a great learning point for me since I never had to deploy a VPC config from scratch. All the places I've worked at had already solved that issue so even though I understood the theory of it, I never had the chance to do it. Creating the Internet Gateway and the NAT Gateway for the public subnet, and then associating the NAT route table to the private subnet was super informative.
### Backend
It was time to create the backend. The first thing that came to mind was RDS. I felt that it was a much simpler approach for the specific requirement since it didn’t need as much configuration as an EC2 with an installed database or a deployed application (which would make the task much more complex since the database/application installation and configuration should be automated). The type of instance that I felt would be best was an Aurora Serverless, since it checks the auto-scaling requirement. Sadly, due to my account being Free Tier I couldn't deploy one. Also the deployment wasn't MultiAZ since it isn't supported by Free Tier (for the record, if I would have been able to, I would have created a MultiAZ deployment with a Subnet Group that used 2 Private Subnets and an Aurora Serverless RDS). For a brief moment I also explored the possibility of an EC2 with an ASG and an AWS AMI that came with the database installed but it was discarded since it felt like too much of a hassle compared to the RDS solution, which is also something that I am much more familiarized with since I’ve done this type of integrations with Lambda before. What I had never done before was authenticating to an RDS database using IAM. I decided to authenticate this way since I felt it was way cleaner than using credentials, since I would have to also manage the credentials with Secret Manager or Parameter Store. I am also generating a random string for the root user of the RDS that is shown as an output once the deployment is finished. I know this is wrong and I would also manage this by using secret manager but I took this approach for the sake of simplicity. After reviewing the code, you'll probably notice that the RDS is publicly accessible. I know this is neither clean nor secure but it was the way I managed to set up the postgres provider to automate the creation of the role and then grant permissions to the role inside the database since terraform is creating a connection from my host to the RDS. A way to fix this would be having an EC2 in the same VPC with all the dependencies installed do the whole deployment.
### Terraform State management
For the sake of simplicity I decided to maintain the terraform state locally. If this were to be a productive environment I would take a different approach by having a **remote backend state** using S3 and DynamoDB.
1. **S3 Bucket**: The Terraform state files (.tfstate) would be stored in a private bucket. This way I can have a persistent and versioned storage for the state which would make it super practical and safe for team collaboration.
2. **DynamoDB**: Then a DynamoDB would be used to implement state locking. This way, when working with a team, simoultaneous modification of the infrastructure state can be avoided and data corruption, prevented.

## Tool Selection Justification
The tools used during the challenge were:
1. **An AWS Free Tier account**: I decided to use an AWS Free Tier account instead of LocalStack mainly because it is what I felt the most comfortable with. I've been working with AWS for a while now and I knew that trying anything new was a recipe for disaster, so I tried to keep it simple by using what I know the most. Using AWS allowed me to plan every step carefully and making mistakes and correcting them was much easier due to the UI.
2. **Terraform**: Same as AWS, I went with Terraform because I know it the most. I've used CDK in the past but I'm not as comfortable as I am with Terraform. Maybe it is because I have been using it for a while but I feel like the code is much easier to understand visually.
3. **Docker and Docker-compose**: I didn't have much experience using Docker and Docker compose aside from a few personal projects that I did in the past so I decided to go with these tools to try and hone my knowledge. I found it super pleasurable since I managed to deploy everything with almost no problems, it felt like after a few years of  working with AWS all the Docker concepts that used to feel hard to understand came very naturally.
4. **Python**: In the past year I had to deploy a few Lambda functions and I wrote the scripts with Python and boto3. I felt like these were the right tools to create the Lambda needed for the solution.

## Local Development & Testing
Before deploying to AWS, you can test the Lambda and Database integration locally using Docker Compose.
### 1. Build and Run Services
First make sure that Docker is running.
From the project root directory run the following commands to access the docker directory and build the Lambda image, start the Lambda container, and start the PostgreSQL container in the background:
```
cd docker
docker-compose up --build -d
```
### 2. Test the Local Endpoint
Once the containers are running, send a simulated API Gateway request to your Lambda service running on port 9000.
```
curl -XPOST 'http://localhost:9000/2015-03-31/functions/function/invocations' \
     -H 'Content-Type: application/json' \
     -d '{"httpMethod": "GET", "queryStringParameters": null, "body": null}'
```
Note: This uses a POST request to the Lambda Runtime Interface Emulator (RIE), and the JSON payload simulates the actual API Gateway request.

You should now see a JSON object containing the database version.

## AWS Deployment
First, make sure your AWS credentials are configured and accessible by Terraform

Then check the following variables in the terraform.tfvars file and assign values to them, since they will be needed to perform a succesful deployment:
```
# the sns-email where you want to receive notifications
sns-email = ""
# your public ip "x.x.x.x/32"
my-public-ip = ""
# your desired deployment region (otherwise it will default to us-east-1 as defined in the variables.tf)
region = ""
```
### 1. Initialize and Validate
```
terraform init
terraform validate
tflint --init
```
### 2. Run Pre-Deployment Checks
```
tflint
trivy config .
```
### 3 Deployment
Review the planned changes and apply the configuration.
```
terraform plan
terraform apply
```
### 4 Testing
After deployment, copy the URL of the API Gateway given by the output and paste it into your browser.

You should now see a JSON object detailing information about the RDS.

Once you've tested the function, you can test the alarms by connecting to the database and executing the .sql scripts in the "alarm testing" directory (remember to accept the subscription created by SNS that was sent to the configured sns email). First you'll need to connect to the database. For this I used pgAdmin4. The user is "postgres" and the password is printed as an output on your terminal once the infrastructure is deployed. It will be shown like this:
```
rds-random-password = "ABCDEFG123456"
```
This random string is created by the resource called "random_string" in the rds.tf file.

To connect to the database using pgAdmin4 and run the scripts do the following:
1. Right click on "Servers" on the top left side of the UI, Register -> Server.
2. In the "General" tab, add your desired session name in the "Name" field.
3. Then access the "Connection" tab. There you will add the RDS endpoint as the "Host name/address". Leave the username as "postgres" and paste the password that was printed on your terminal as a terraform output. Once that is done click on "Save" and you should be connected to the RDS. 
4. Select the target database on the browser tree (left panel) where you want to execute the script (in this case, the database is called "postgres".
5. Open the Query Tool by right-clicking on the selected database, navigating to Tools, and then clicking on Query Tool.
6. In the Query Tool window, click the Open File button (folder icon) in the toolbar. Browse to and select your .sql file called:
```
simulate_load.psql
```
Then open 5 to 7 sessions on the database and do the same with the next script:
```
high_cpu_load.sql
```
After a while you should get all 3 emails, one for each alert.

### 5 Cleanup
To clean everything up the following commands must be executed:
```
terraform state rm postgresql_role.nanlabs_user
terraform state rm postgresql_grant_role.grant_rds_iam
```
If the postgresql provider resources aren't removed from the state, when the destruction command is executed, terraform will try to connect to the rds database. Once this is done we can run:
```
terraform destroy
```
Note: There is a weird dependency between the lambda and the private subnet which I think is related to how much time it takes for the network interface of the lambda to be dettached. The consequence of this is the destroy operation taking a while to complete (around 20min).

## Takeaways
It was a great and very informative experience. I got the chance to do a lot of new things that either weren't necessary in my current and previous jobs or that were already solved (such as all the VPC configs).
I got to create a pipeline from scratch (and I even tested it with a terraform plan! But I removed it from the repo since I didn't want my iam user credentials to be stored in GitHub Secrets) and I also got to build and deploy two working containers that communicated with eachother, and I learned how to configure pre-commits for my future repositories.

I know that my final submission won't be perfect but overall I am very happy with how this turned out.