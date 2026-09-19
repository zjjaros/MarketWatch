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

#PostgreSQL
pg_dump -U postgres -d <DB> -F c -f <DB>_backup.dump


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