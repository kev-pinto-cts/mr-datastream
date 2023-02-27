import os
import ssl
import uuid
import sqlalchemy
import time
from datetime import datetime
import datetime as dt
from random import randint
import functions_framework
from google.cloud import pubsub_v1


def get_log_date(lookback: int):
    weeks_to_subtract=randint(1,lookback)
    log_date = datetime.now()-dt.timedelta(weeks=weeks_to_subtract)
    # 2023-02-01 00:00:00.000000
    return log_date.strftime('%Y-%m-%d 00:00:00.000000')


def connect_tcp_socket() -> sqlalchemy.engine.base.Engine:
    """Initializes a TCP connection pool for a Cloud SQL instance of Postgres."""
    # Note: Saving credentials in environment variables is convenient, but not
    # secure - consider a more secure solution such as
    # Cloud Secret Manager (https://cloud.google.com/secret-manager) to help
    # keep secrets safe.
    db_host = "127.0.0.1"
    db_user = "postgres"
    db_pass = ""
    db_name = "demodb"
    db_port = 5435

    pool = sqlalchemy.create_engine(
        # Equivalent URL:
        # postgresql+pg8000://<db_user>:<db_pass>@<db_host>:<db_port>/<db_name>
        sqlalchemy.engine.url.URL.create(
            drivername="postgresql+pg8000",
            username=db_user,
            password=db_user,
            host=db_host,
            port=db_port,
            database=db_name,
        ),
    )
    return pool


@functions_framework.http
def main(request):
    PROJECT_ID = ""
    conn = connect_tcp_socket()
    stmt = sqlalchemy.text("SET search_path to data_schema;")
    stmt1 = sqlalchemy.text("INSERT INTO test_datastream(somecol) VALUES (:myval);")
    stmt2 = sqlalchemy.text(
        "INSERT INTO test_datastream_part(somecol,log_date) VALUES (:myval,:log_date);"
    )

    with conn.connect() as conn:
        conn.execute(stmt)
        for ctr in range(1, 2000):
            try:
                conn.execute(stmt1, myval=str(uuid.uuid1()))
                conn.execute(stmt2, myval=str(uuid.uuid1()),
                log_date=get_log_date(50))
                # time.sleep(1)
            except Exception as err:
                print(err)
    return 0


if __name__ == "__main__":
    main(None)
