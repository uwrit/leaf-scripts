#!/bin/bash

# start sql server
/opt/mssql/bin/sqlservr &

# wait for startup
until /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "SELECT 1" > /dev/null 2>&1; do
  sleep 5
  echo "Still Waiting for SQL Server to be available..."
done

echo "checking Leaf Database init status..."

until /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "SELECT name from sys.databases" | grep 'LeafDB'; do
  # Run your init script
  echo "Running init ..."

  # populate an empty instance of Leaf
  /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P ${MSSQL_SA_PASSWORD} -C -i /app/LeafDB.sql
  /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P ${MSSQL_SA_PASSWORD} -d LeafDB -C -i /app/LeafDB.Init.sql
  
  # setup an empty local clinical DB where you will stash your data - update your database name in docker-compose to be ClinicalDataDB
  # where you might put your UMLS or OMOP schemas as well as your extract for your instance
  /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P ${MSSQL_SA_PASSWORD} -C -i /app/LeafDB.EmptyLocalClinicalDB.sql

  # setup a service account for use in Docker compose file for API container
  #/opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P ${MSSQL_SA_PASSWORD} -C -i LeafDB.ServiceAccount.sql

  echo "Finished running init."
done 

echo "Leaf Database ready."

wait

