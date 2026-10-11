############################
# MarketWatch README
############################

############################
# What is MarketWatch?
############################
MarktetWatch is a personal, educational project that allows myself (and any other contributers) to experiment with:
    1. Terraform (Infrastructure as Code [IaC])
    2. Docker (containerization)
    3. AWS (cloud infrastructure)
        - EC2
        - RDS
        - ECR
        - SSM
        - IAM
        - VPC
        - Secrets Manager
    4. FastAPI (amazing python lib for REST APIs)
    5. Alembic (Relational DB change tracking and control)
    6. SQLAlchemy (Nifty code-first database design)
    7. PostgreSQL (modern, popular relation database)
    8. HTML/Javascript (frontend)
    9. GitHub Actions
With an emphasis on:
    A. Simple, one-button-press "Bring-up"/"Tear down" without dataloss or manual interventions.
    B. Secure cloud infrastrucure practices.
        - Effective use of VPC (virtual private cloud) and public/private subnets to protect exposure to the whole internet.
        - Strict as-needed permissions established by IAM Policies and specific resource roles.
    C. Optimized workflows: Utilizing Github Actions to handle deployment whenever changes are made by a developer. 

############################
# What does MarketWatch do?
############################

Simply put: It reads bitcoin and gold data from external providers and records those values into a database every 5 minutes (via what's called the "collector"). There is a very rudimentary front end that can show basic trends of this collected data. Other REST API calls can retrieve the raw json data from the DB.

More technically:
    There are two EC2 instances in AWS:
        1. marketwatch-api: Serves the REST API functions.
        2. marketwatch-collector: Hits the BTC and gold data providers and enters the gathered data into the PostgreSQL DB (on an RDS instance in AWS)
    There is an RDS instance that hosts the PostgreSQL server

############################
# Cost and Budget
############################


############################
# Architecture
############################

############################
# Application Component: API
############################

############################
# Application Component: Collector
############################

############################
# Application Component: Database
############################

############################
# Application Component: Frontend
############################

############################
# Local Development
############################

############################
# IAM Policy Permissions
############################
I concocted this list of permissions through a monumental amount of trial and error. The following is all the permissions you SHOULD need for working on this project:



############################
# Design Decisions
############################
1. Why Terraform?
    Terraform is an excellent choice for working with IaC. After completing the basic tutorial for Terraform provided by HashiCorp, I wanted to test my knowledge with a personal project, and MarketWatch was born.
2. Why RDS instead of hosting PostgreSQL on EC2
    RDS is the industry, production resource for PostgreSQL relational databases. Not only does it have all these under-the-hood support for PSQL DBs, RDS already has consideration for snapshots, recovery, etc. One note: RDS is more costly of a resource than EC2, so if you're really on a shoe-string budget, you could get by using an EC2 instance, but that will come with a number of work-arounds you'll need to make the data-preservation and database creation work.
3. Why Docker and ECR
    Docker containerization just makes life easier. Once the image is made, you can be sure the environment youre running this application is is viable and won't give you trouble. ECR was a no-brainer as a way to store and distribute images to resources that need them.
4. Why OIDC instead of long-lived AWS credentials
    OIDC is closer to professional production environments. I wanted to avoid having passwords/secrets stored in numerous places, so whenever we could have resources "borrow" permissions (safely with policy groups), I did.
5. Why SSM instead of SSH-based deployment
    Similar to the OIDC reasoning. If there is an Amazon resource that can handle this case, without having to store SSH passwords somewhere, I might as well go that route and save myself some hassle.
6. Why the collector runs independently from the API
    They have very distinct, separate responsibilities so it makes sense to separate them. API can focus solely on serving the user. Collector can do it's own thing elsewhere. Neither has to care about the other. They interact indirectly via the relational database, which is good design.


############################
# Annoying Hangups To Watch For
############################
1. Powershell will sometimes put special end of line characters that can have you chasing errors for a while.
2. No empty lines before "#!/bin/bash" in the shell scripts! That one took a minute to find.
3. Careful with partial "apply"s with Terraform. I provided the policy permissions I used for this project, but there were dozens of times where an apply failed because of a missing permission, which then had to be added and another apply operation had to be done. Just make sure you know what terraform state youre in.

############################
#   Useful commands
############################
Run a file WITHIN the known project area.
    uv run python -m path.to.file  (No .py)
Run a specific python file
    uv run python <file>.py
Alemic checks the state of the models vs the DB state
    uv run alembic check
This generates a scaffoleded python file to execute the changes made in models file. This file is generated in alembic/versions/<ID>_some_message_.py
    uv run alembic revision --autogenerate -m "some message"
Executes the scaffolded code
    uv run alembic upgrade head
Reverses the history of the database by 1 "migration"
    uv run alembic downgrade -1
    
Build docker image
    docker build -t <imagename> .
List Docker Images
    docker images
Create containers for images
    docker compose up -d
List current containers
    docker compose ps 
Build images, then create containers
    docker compose up -d --build
Execute a command on a container
    docker compose exec <imagename> <command>

Get the public IP of EC2:
    aws ec2 describe-instances --filters "Name=tag:Name,Values=marketwatch-api" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].PublicIpAddress" --output text

Get state of a resource:
    terraform state show <resource>
    ex: terraform state show aws_instance.marketwatch_collector

SSH onto a resource
    ssh -i "$HOME\.ssh\<YOUR_PEM_FILE>.pem" ubuntu@<PUBLIC_IP>

Copy a file from local machine to a resource:
    scp -i "$HOME\.ssh\<YOUR_PEM_FILE>.pem" <FILE> ubuntu@<YOUR_EC2_PUBLIC_IP>:/tmp/<FILE>

Create a dump file of an existing DB (for restoration later)
    pg_dump -U postgres -d <DB> -F c -f <DB>_backup.dump

Access RDS from EC2
    psql -h marketwatch-db.cbgy00sw8vm2.us-west-2.rds.amazonaws.com -p 5432 -U marketwatch -d marketwatch

    if psql not installed, do the following
        sudo apt update
        sudo apt install postgresql-client


NOTE: THESE MANUAL ROLE CREATIONS SHOULD BE DONE VIA TERRAFORM IN iam.tf

Manual creating a role for an EC2 instance to use certain permissions
    aws iam create-role `
    --role-name <your rolename> `
    --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

    ex:
        aws iam create-role `
        --role-name MarketWatchEC2Role `
        --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

Manually creating a policy for a role
    aws iam put-role-policy `
    --role-name <your rolename> `
    --policy-name <your policyname> `
    --policy-document file://<rel path to your policy>.json

Manually creating an instance profile
    aws iam create-instance-profile `
    --instance-profile-name <your profilename>

Manually attaching the role to the instance profile:
    aws iam add-role-to-instance-profile `
    --instance-profile-name <your profilename> `
    --role-name <your rolename>

Manually connect the instance with the profile
    aws ec2 associate-iam-instance-profile `
    --instance-id <your instanceID> `
    --iam-instance-profile Name=<your instanceprofile> `
    --region us-west-2

Get an instance ID from EC2:
    aws ec2 describe-instances `
    --filters "Name=tag:Name,Values=<your instancename>" `
    --query "Reservations[].Instances[].InstanceId" `
    --output text `
    --region us-west-2

    ex:
    aws ec2 describe-instances `
    --filters "Name=tag:Name,Values=marketwatch-api" `
    --query "Reservations[].Instances[].InstanceId" `
    --output text `
    --region us-west-2

Get the arn of a secret:
    aws rds describe-db-instances --db-instance-identifier <your instancename> --region us-west-2 --query "DBInstances[0].MasterUserSecret.SecretArn" --output text
    
    ex:
    aws rds describe-db-instances --db-instance-identifier marketwatch-db --region us-west-2 --query "DBInstances[0].MasterUserSecret.SecretArn" --output text

Get the actual text of the secret (be careful here)
aws secretsmanager get-secret-value --secret-id "<your arn secret here>" --region us-west-2 --query SecretString --output text

Get the token (that IP is specificly reserved for EC2 Instance Metadata Service (IMDS))
$TOKEN=$(curl -sS -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

curl -sS \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/info


Install the AWS CLI
    sudo apt install -y awscli

Login to docker from AWS instance (using borrowed permissions)
    aws ecr get-login-password --region us-west-2 | \
    sudo docker login --username AWS --password-stdin \
    997956187142.dkr.ecr.us-west-2.amazonaws.com

Restore an old backup:
    docker cp .\<your dumpfile>.dump <your postgresql instance>:/tmp/<your dumpfile>.dump
    docker compose exec postgres pg_restore -U <username> -d <database> --clean --if-exists /tmp/<your dumpfile>.dump
    To test:
    docker compose exec postgres psql -U <username> -d <database> -c "SELECT * FROM <your table>;"

    ex:
    docker cp .\marketwatch_backup.dump marketwatch-postgres-1:/tmp/marketwatch_backup.dump
    docker compose exec postgres pg_restore -U postgres -d marketwatch --clean --if-exists /tmp/marketwatch_backup.dump
    docker compose exec postgres psql -U postgres -d marketwatch -c "SELECT * FROM price_observations;"

