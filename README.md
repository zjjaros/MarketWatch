# MarketWatch README
*Author: Zach Jaros* (<zjaros@hotmail.com>)  
*License: MIT*

## What is MarketWatch?

MarktetWatch is a personal, educational project that allows myself (and any other contributers) to experiment with:
1. Terraform (Infrastructure as Code [__IaC__])
2. Docker (containerization)
3. AWS (cloud infrastructure)
    - Elastic Compute Cloud (__EC2__)
    - Relational Database Service (__RDS__)
    - Elastic Container Registry (__ECR__)
    - Security Groups
    - Identity and Access Management (__IAM__)
    - Virtual Private Cloud (__VPC__)
    - OpenID Connect (__OIDC__)
    - Systems Manager (__SSM__)
    - Secrets Manager
4. FastAPI (amazing python lib for REST APIs)
5. Alembic (Relational DB change-tracking and control)
6. SQLAlchemy (Nifty code-first database design)
7. PostgreSQL (modern, popular relation database)
8. HTML/Javascript (frontend)
9. GitHub Actions

with an emphasis on:
- Simple, one-button-press "Bring-up"/"Tear down" capability without data-loss or manual interventions.
- Secure cloud infrastrucure practices.
    - Effective use of VPC (virtual private cloud) and public/private subnets to protect exposure to the whole internet.
    - Strict as-needed permissions established by IAM Policies and specific resource roles.
- Optimized workflows: Utilizing Github Actions to handle deployment whenever changes are made by a developer. 

## What does MarketWatch do?

Simply put: It reads bitcoin and gold data from external providers and records those values into a database every 5 minutes (via what's called the "collector"). There is a very rudimentary front end that can show basic trends of this collected data. Other REST API calls can retrieve the raw json data from the DB.

More technically

- There are two EC2 instances in AWS:
    1. __marketwatch-api__: Serves the REST API functions.
    2. __marketwatch-collector__: Hits the BTC and gold data providers and enters the gathered data into the PostgreSQL DB (on an RDS instance in AWS)
- There is an RDS instance that hosts the PostgreSQL server

## Cost and Budget
With Amazon AWS Free Tier, you can play around with this infrastructure for a good amount of time before you need to worry, but I would recommend keeping track of expenses as you go (and setting up a budget alert!). You get $100 of free credits, and I got an extra $60 during this process because I inadvertedly hit some AWS incentives.

- __RDS__: Highest cost, but even then its not too pricey
- __EC2__: Second highest cost
- __VPC__: Low cost
- __Security Manager__: Almost negligable (a few cents)

For a reference point, I ran this setup off and on for a week, and it totalled __$3.78__

*Basic rule*: Don't leave this running non-stop for 7 months then realize you burned through many credits.

## Architecture

MarketWatch is a containerized market-data application deployed on AWS using Terraform-managed infrastructure. The system separates data collection, API serving, and persistent storage into independent components.

The application runs on two EC2 instances: one hosts the FastAPI application, while the other runs the data collector. Both connect to a private Amazon RDS for PostgreSQL instance, allowing the collector to continue gathering data independently of API traffic.

### Data Flow

1. The collector retrieves market-price data from external providers.
2. Retrieved observations are persisted to PostgreSQL using SQLAlchemy.
3. The FastAPI application queries PostgreSQL and exposes historical observations and trend data through HTTP endpoints.
4. Clients access the API through its public endpoint.

### Deployment Flow

1. Changes are pushed to the GitHub repository.
2. GitHub Actions builds the application’s Docker image.
3. The image is pushed to Amazon Elastic Container Registry (ECR).
4. GitHub Actions authenticates to AWS using OpenID Connect (OIDC) and initiates deployment through AWS Systems Manager (SSM).
5. The API and collector instances independently pull and run the updated image.

### Infrastructure

Terraform manages the AWS resources, including the VPC, subnets, security groups, EC2 instances, IAM roles, ECR repository, and RDS database.

The database resides in private subnets and is not directly accessible from the public internet. EC2 security groups control application and database connectivity, while AWS Secrets Manager stores the database's managed master credentials.

---

## Application Component: API

The API is built with FastAPI and provides HTTP access to the market observations stored in PostgreSQL.

SQLAlchemy handles database interactions, while Alembic manages schema migrations. This separates application-level data access from database schema evolution and allows migrations to be applied as part of deployment.

### Endpoints

| Endpoint | Description |
|---|---|
| `GET /prices` | Retrieves stored price observations. |
| `GET /prices/{asset}/history` | Retrieves historical observations for a specified asset. |
| `GET /prices/btc/trend` | Retrieves Bitcoin trend data. |

The API runs in a Docker container on a dedicated EC2 instance. Its deployment process retrieves the database connection information from AWS, applies pending Alembic migrations, and starts the updated container.

Separating the API from the collector allows either component to be deployed or restarted without requiring both workloads to share the same compute instance.

---

## Application Component: Collector

The collector is responsible for retrieving external market-price data and persisting observations to PostgreSQL.

It runs independently of the API in its own Docker container on a dedicated EC2 instance. This separation isolates scheduled data collection from API request handling and allows the workloads to be managed independently.

### Data Sources

The collector integrates with external providers for cryptocurrency and gold-price data, including:

- **Binance** — cryptocurrency market data.
- **CoinGecko** — Bitcoin price data in USD.
- **GoldPriceAPI** — gold spot-price data, including the XAU-USD-SPOT instrument.

Collected observations are written to PostgreSQL through SQLAlchemy. The database provides persistent historical records that the API can query for price history and trend calculations.

The collector and API share the same application image but use separate Docker Compose configurations and EC2 instances. This avoids running duplicate collection processes when deploying or restarting the API.

---

## Application Component: Database

MarketWatch uses Amazon RDS for PostgreSQL as its persistent data store. The database is deployed in private subnets and accepts connections from the application components through security-group rules.

### Schema and Persistence

The `price_observations` table stores collected market data, including:

- `id` — observation identifier.
- `asset` — asset or instrument identifier.
- `price` — recorded price.
- `timestamp` — observation timestamp.
- `source` — data provider associated with the observation.

SQLAlchemy provides the application's database access layer, and Alembic tracks and applies schema migrations. This allows database changes to be version-controlled alongside application code.

### Credentials and Security

The RDS instance uses AWS-managed master credentials stored in AWS Secrets Manager. The application retrieves the necessary connection information at deployment time using its EC2 IAM role.

The database is not publicly accessible. Connectivity is restricted to authorized application security groups, keeping database access separate from public API access.

### Backup and Recovery

The project includes PowerShell scripts for infrastructure teardown and recovery:

- `down.ps1` creates an RDS snapshot before destroying Terraform-managed infrastructure.
- `up.ps1` uses the saved recovery configuration to plan and recreate the infrastructure from the selected snapshot.

This approach allows the compute and networking resources to be recreated while preserving historical observations in the database snapshot.

---

## Application Component: Frontend

The current implementation focuses on the data-collection pipeline, PostgreSQL persistence, and HTTP API. A standalone frontend is not yet part of the deployed application.

The API provides the foundation for a future user interface that could display current prices, historical price series, and Bitcoin trend data.

A frontend could be implemented as a separate application consuming the existing API, allowing the presentation layer to evolve independently of data collection and storage.

---

## Local Development

### Prerequisites

The following tools are used for local development:

- Python 3.14
- `uv` for Python environment and dependency management
- Docker and Docker Compose, if running PostgreSQL locally in a container
- Git
- AWS CLI and Terraform for infrastructure management and deployment workflows

### Python Environment

Clone the repository and navigate to the project directory:

```bash
git clone https://github.com/zjjaros/MarketWatch.git
cd MarketWatch
```

Create the virtual environment and install the project dependencies using `uv`:

```bash
uv sync
```

Configure the required environment variables, including `DATABASE_URL`, to point to an accessible PostgreSQL database.

### Database Migrations

Apply the current database schema using Alembic:

```bash
uv run alembic upgrade head
```

This creates or upgrades the database schema to the latest migration revision.

### Running the API

Start the FastAPI development server:

```bash
uv run uvicorn api.main:app --reload
```

The API is then available locally at `http://localhost:8000`, assuming the module path matches the current application entry point.

Interactive API documentation is available at `http://localhost:8000/docs`.

### Running the Collector

In a separate terminal, run the collector:

```bash
uv run python -m collector.main
```

The collector requires a valid database connection and any necessary external-provider configuration.

### Configuration Notes

Keep credentials and environment-specific configuration out of source control. Use local environment variables or an untracked environment file for development, and use AWS IAM and Secrets Manager for deployed workloads.

Local development does not require Terraform or AWS deployment to be run every time application code changes. The API and collector can be tested independently against a development PostgreSQL database.

## IAM Policy Permissions
I concocted this list of permissions through a monumental amount of trial and error. I think this list is preferred over simply giving yourself "AllAccess" to everything. The following is all the permissions you SHOULD need for working on this project:

    "ec2:AssociateIamInstanceProfile",
    "ec2:AssociateRouteTable",
    "ec2:AttachInternetGateway",
    "ec2:AuthorizeSecurityGroupEgress",
    "ec2:AuthorizeSecurityGroupIngress",
    "ec2:CreateInternetGateway",
    "ec2:CreateNetworkAclEntry",
    "ec2:CreateRoute",
    "ec2:CreateRouteTable",
    "ec2:CreateSecurityGroup",
    "ec2:CreateSubnet",
    "ec2:CreateTags",
    "ec2:CreateVpc",
    "ec2:DeleteInternetGateway",
    "ec2:DeleteNetworkAclEntry",
    "ec2:DeleteRoute",
    "ec2:DeleteRouteTable",
    "ec2:DeleteSecurityGroup",
    "ec2:DeleteSubnet",
    "ec2:DeleteVpc",
    "ec2:DescribeIamInstanceProfileAssociations",
    "ec2:DescribeImages",
    "ec2:DescribeInstanceAttribute",
    "ec2:DescribeInstanceCreditSpecifications",
    "ec2:DescribeInstanceStatus",
    "ec2:DescribeInstanceTypes",
    "ec2:DescribeInstances",
    "ec2:DescribeInternetGateways",
    "ec2:DescribeNetworkAcls",
    "ec2:DescribeNetworkInterfaces",
    "ec2:DescribeRouteTables",
    "ec2:DescribeSecurityGroupRules",
    "ec2:DescribeSecurityGroups",
    "ec2:DescribeSubnets",
    "ec2:DescribeTags",
    "ec2:DescribeVolumes",
    "ec2:DescribeVpcAttribute",
    "ec2:DescribeVpcs",
    "ec2:DetachInternetGateway",
    "ec2:DisassociateRouteTable",
    "ec2:GetConsoleOutput",
    "ec2:ModifyVpcAttribute",
    "ec2:RevokeSecurityGroupEgress",
    "ec2:RevokeSecurityGroupIngress",
    "ec2:RunInstances",
    "ec2:TerminateInstances",
    "ecr:BatchCheckLayerAvailability",
    "ecr:BatchGetImage",
    "ecr:CompleteLayerUpload",
    "ecr:CreateRepository",
    "ecr:DeleteRepository",
    "ecr:DescribeImages",
    "ecr:DescribeRepositories",
    "ecr:GetAuthorizationToken",
    "ecr:GetDownloadUrlForLayer",
    "ecr:InitiateLayerUpload",
    "ecr:ListTagsForResource",
    "ecr:PutImage",
    "ecr:UploadLayerPart",
    "iam:AddRoleToInstanceProfile",
    "iam:AttachRolePolicy",
    "iam:CreateInstanceProfile",
    "iam:CreateOpenIDConnectProvider",
    "iam:CreateRole",
    "iam:DeleteInstanceProfile",
    "iam:DeleteOpenIDConnectProvider",
    "iam:DeleteRole",
    "iam:DeleteRolePolicy",
    "iam:DetachRolePolicy",
    "iam:GetInstanceProfile",
    "iam:GetOpenIDConnectProvider",
    "iam:GetRole",
    "iam:GetRolePolicy",
    "iam:ListAttachedRolePolicies",
    "iam:ListInstanceProfilesForRole",
    "iam:ListRolePolicies",
    "iam:ListRoles",
    "iam:PutRolePolicy",
    "iam:RemoveRoleFromInstanceProfile",
    "iam:SimulatePrincipalPolicy",
    "iam:UpdateAssumeRolePolicy",
    "kms:DescribeKey",
    "rds:AddTagsToResource",
    "rds:CreateDBInstance",
    "rds:CreateDBSnapshot",
    "rds:CreateDBSubnetGroup",
    "rds:DeleteDBInstance",
    "rds:DeleteDBSubnetGroup",
    "rds:DescribeDBInstances",
    "rds:DescribeDBSnapshots",
    "rds:DescribeDBSubnetGroups",
    "rds:ListTagsForResource",
    "rds:ModifyDBInstance",
    "rds:ModifyDBSubnetGroup",
    "rds:RemoveTagsFromResource",
    "rds:RestoreDBInstanceFromDBSnapshot",
    "secretsmanager:CreateSecret",
    "secretsmanager:DeleteSecret",
    "secretsmanager:DescribeSecret",
    "secretsmanager:GetSecretValue",
    "secretsmanager:TagResource",
    "secretsmanager:UpdateSecret",
    "ssm:DescribeInstanceInformation",
    "ssm:GetCommandInvocation",
    "ssm:SendCommand"

## Design Decisions
### *Why Terraform?*

Terraform is an excellent choice for working with IaC. After completing the basic tutorial for Terraform provided by HashiCorp, I wanted to test my knowledge with a personal project, and MarketWatch was born.

### *Why RDS instead of hosting PostgreSQL on EC2*

RDS is the industry, production resource for PostgreSQL relational databases. Not only does it have all these under-the-hood support for PSQL DBs, RDS already has consideration for snapshots, recovery, etc. One note: RDS is more costly of a resource than EC2, so if you're really on a shoe-string budget, you could get by using an EC2 instance, but that will come with a number of work-arounds you'll need to make the data-preservation and database creation work.

### *Why Docker and ECR*

Docker containerization just makes life easier. Once the image is made, you can be sure the environment youre running this application is is viable and won't give you trouble. ECR was a no-brainer as a way to store and distribute images to resources that need them.

### *Why OIDC instead of long-lived AWS credentials*

OIDC is closer to professional production environments. I wanted to avoid having passwords/secrets stored in numerous places, so whenever we could have resources "borrow" permissions (safely with policy groups), I did.

### *Why SSM instead of SSH-based deployment*

Similar to the OIDC reasoning. If there is an Amazon resource that can handle this case, without having to store SSH passwords somewhere, I might as well go that route and save myself some hassle.

### *Why the collector runs independently from the API*

They have very distinct, separate responsibilities so it makes sense to separate them. API can focus solely on serving the user. Collector can do it's own thing elsewhere. Neither has to care about the other. They interact indirectly via the relational database, which is good design.

## Annoying Hangups To Watch For
1. Powershell will sometimes put special end of line characters that can have you chasing errors for a while.
2. No empty lines before "#!/bin/bash" in the shell scripts! That one took a minute to find.
3. Careful with partial "apply"s with Terraform. I provided the policy permissions I used for this project, but there were dozens of times where an apply failed because of a missing permission, which then had to be added and another apply operation had to be done. Just make sure you know what terraform state youre in.

## Useful commands
### UV/Python
Run a file within the known project area. __NOTE__: Do not add a *.py* extension to the file. 

    uv run python -m path.to.file

Run a specific python file.

    uv run python <file>.py
### UV/Alembic
Alemic checks the state of the models vs the DB state
    
    uv run alembic check

Generate a scaffoleded python file to execute the changes made in models file. This file is generated in *alembic/versions/<ID>_some_message_.py*
    
    uv run alembic revision --autogenerate -m "some message"

Executes the scaffolded code

    uv run alembic upgrade head

Reverses the history of the database by 1 "migration"

    uv run alembic downgrade -1

### Docker
Build docker image

    docker build -t <imagename> .

List Docker Images

    docker images

Create containers for images (the *-d* skips you past a prompt)

    docker compose up -d

List current containers

    docker compose ps 

Build images, then create containers

    docker compose up -d --build

Execute a command on a container

    docker compose exec <imagename> <command>

### AWS
Get the public IP of EC2:

    aws ec2 describe-instances --filters "Name=tag:Name,Values=<resource name>" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].PublicIpAddress" --output text

example:

    aws ec2 describe-instances --filters "Name=tag:Name,Values=marketwatch-api" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].PublicIpAddress" --output text

__NOTE__: THE FOLLOWING MANUAL ROLE CREATIONS SHOULD BE DONE VIA TERRAFORM IN iam.tf

Manual creating a role for an EC2 instance to use certain permissions

    aws iam create-role `
    --role-name <your rolename> `
    --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

ex:

    aws iam create-role `
    --role-name MarketWatchEC2Role `
    --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

Manually creating a policy for a role:

    aws iam put-role-policy `
    --role-name <your rolename> `
    --policy-name <your policyname> `
    --policy-document file://<rel path to your policy>.json

Manually creating an instance profile:

    aws iam create-instance-profile `
    --instance-profile-name <your profilename>

Manually attaching the role to the instance profile:

    aws iam add-role-to-instance-profile `
    --instance-profile-name <your profilename> `
    --role-name <your rolename>

Manually connect the instance with the profile:

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

Get the actual text of the secret (__NOTE: be careful using this!__)

    aws secretsmanager get-secret-value --secret-id "<your arn secret here>" --region us-west-2 --query SecretString --output text

### Terraform
Get state of a resource:

    terraform state show <resource>

example: 
    
    terraform state show aws_instance.marketwatch_collector

### Shell
SSH onto a resource

    ssh -i "$HOME\.ssh\<YOUR_PEM_FILE>.pem" ubuntu@<PUBLIC_IP>

Copy a file from local machine to a resource:

    scp -i "$HOME\.ssh\<YOUR_PEM_FILE>.pem" <FILE> ubuntu@<YOUR_EC2_PUBLIC_IP>:/tmp/<FILE>

Create a dump file of an existing DB (for restoration later)

    pg_dump -U postgres -d <DB> -F c -f <DB>_backup.dump

Access RDS from EC2

    psql -h marketwatch-db.cbgy00sw8vm2.us-west-2.rds.amazonaws.com -p 5432 -U marketwatch -d marketwatch

__NOTE__: If psql not installed, do the following:

    sudo apt update
    sudo apt install postgresql-client



Get a metadata token (__Note__: This IP (169.254.169.254) is specificly reserved for EC2 Instance Metadata Service (IMDS))

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
    <your user ID>.dkr.ecr.us-west-2.amazonaws.com

### Restore an old backup:

Copy the dumpfile over to your postgresql instance:

    docker cp .\<your dumpfile>.dump <your postgresql instance>:/tmp/<your dumpfile>.dump

Restore the database using your dump file:

    docker compose exec postgres pg_restore -U <username> -d <database> --clean --if-exists /tmp/<your dumpfile>.dump
    
To test:
    
    docker compose exec postgres psql -U <username> -d <database> -c "SELECT * FROM <your table>;"

ex:

    docker cp .\marketwatch_backup.dump marketwatch-postgres-1:/tmp/marketwatch_backup.dump
    docker compose exec postgres pg_restore -U postgres -d marketwatch --clean --if-exists /tmp/marketwatch_backup.dump
    docker compose exec postgres psql -U postgres -d marketwatch -c "SELECT * FROM price_observations;"

