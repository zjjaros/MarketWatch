# MarketWatch
Sample Project to experiment with new technologies


Alembic flow:
1. Change SQLAlchemy model
          ↓
2. alembic check
          ↓
3. alembic revision --autogenerate
          ↓
4. Review migration
          ↓
5. alembic upgrade head
          ↓
6. Database updated

#Useful commands
cmd: uv run python -m path.to.file  (No .py)
    desc: Run a file WITHIN the known project area.
cmd: uv run python <file>.py
    desc: Run a specific python file
cmd: uv run alembic check
    desc: Alemic checks the state of the models vs the DB state
cmd: uv run alembic revision --autogenerate -m "some message"
    desc: This generates a scaffoleded python file to execute the changes made in models file.
        This file is generated in alembic/versions/<ID>_some_message_.py
cmd: uv run alembic upgrade head
    desc: executes the scaffolded code
cmd: uv run alembic downgrade -1
    desc: reverses the history of the database by 1 "migration"

docker build -t <imagename> .
docker images
docker compose up -d
docker compose ps 
docker compose up -d --build
docker compose exec <imagename> <command>

#get IP of EC2:
aws ec2 describe-instances --filters "Name=tag:Name,Values=marketwatch-api" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].PublicIpAddress" --output text

#ssh
ssh -i "$HOME\.ssh\<YOUR_PEM_FILE>.pem" ubuntu@<YOUR_EC2_PUBLIC_IP>


#copy a file over:
scp -i "$HOME\.ssh\<YOUR_PEM_FILE>.pem" <FILE> ubuntu@<YOUR_EC2_PUBLIC_IP>:/tmp/<FILE>

#PostgreSQL
pg_dump -U postgres -d <DB> -F c -f <DB>_backup.dump

#access RDS from EC2
psql -h marketwatch-db.cbgy00sw8vm2.us-west-2.rds.amazonaws.com -p 5432 -U marketwatch -d marketwatch

#AWS
Manual creating a role for an EC2 instance to use certain permissions:
aws iam create-role `
  --role-name MarketWatchEC2Role `
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

Manually creating a policy for that role:
aws iam put-role-policy `
   --role-name MarketWatchEC2Role `
   --policy-name MarketWatchECRPull `
   --policy-document file://<rel path to your policy>.json

Manually creating an instance profile
aws iam create-instance-profile `
   --instance-profile-name MarketWatchEC2Profile

Manually attaching the role to the instance profile:
aws iam add-role-to-instance-profile `
  --instance-profile-name MarketWatchEC2Profile `
  --role-name MarketWatchEC2Role

Get an instance ID from EC2:
aws ec2 describe-instances `
  --filters "Name=tag:Name,Values=marketwatch-api" `
  --query "Reservations[].Instances[].InstanceId" `
  --output text `
  --region us-west-2

Manually connect the instance with the profile
aws ec2 associate-iam-instance-profile `
  --instance-id i-056e3b718b7235e54 `
  --iam-instance-profile Name=MarketWatchEC2Profile `
  --region us-west-2

#get the arn of a secret:
aws rds describe-db-instances --db-instance-identifier marketwatch-db --region us-west-2 --query "DBInstances[0].MasterUserSecret.SecretArn" --output text

#get the actual text of the secret (be careful here)
aws secretsmanager get-secret-value --secret-id "<your arn secret here>" --region us-west-2 --query SecretString --output text

#SSH:
Get the token (that IP is specificly reserved for EC2 Instance Metadata Service (IMDS))
$TOKEN=$(curl -sS -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

curl -sS \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/info

Ensure apt get is up to date and knows whats available:
sudo apt update

Installing the AWS CLI
sudo apt install -y awscli

Login to docker from AWS instance (using borrowed permissions)
aws ecr get-login-password --region us-west-2 | \
sudo docker login --username AWS --password-stdin \
997956187142.dkr.ecr.us-west-2.amazonaws.com

restore an old backup:
docker cp .\marketwatch_backup.dump marketwatch-postgres-1:/tmp/marketwatch_backup.dump
docker compose exec postgres pg_restore -U postgres -d marketwatch --clean --if-exists /tmp/marketwatch_backup.dump
docker compose exec postgres psql -U postgres -d marketwatch -c "SELECT * FROM price_observations;"


Ideal AWS Structure:
                         Internet
                            │
                            ▼
                    ┌───────────────┐
                    │      ALB      │
                    │ Load Balancer │
                    └───────┬───────┘
                            │
                     ┌──────┴──────┐
                     ▼             ▼
                 ┌───────┐     ┌───────┐
                 │ API 1 │     │ API 2 │
                 │  EC2  │     │  EC2  │
                 └───┬───┘     └───┬───┘
                     │             │
                     └──────┬──────┘
                            ▼
                    ┌───────────────┐
                    │ RDS PostgreSQL│
                    └───────▲───────┘
                            │
                     ┌──────┴──────┐
                     │  Collector  │
                     │    EC2      │
                     └─────────────┘

For the collector, the proper way would be:
Private EC2
    │
    ▼
Private Route Table
    │
    ▼
NAT Gateway  💰
    │
    ▼
Internet Gateway
    │
    ▼
Internet

But this is a $0 budget project, so we're doing something different. In a real business
scenario, there would be NAT gateways everywhere.