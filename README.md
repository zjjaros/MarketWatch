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