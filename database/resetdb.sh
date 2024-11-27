export PGPASSWORD='postgres'
psql -U postgres -h localhost -c "DROP DATABASE IF EXISTS zui;"
psql -U postgres -h localhost -c "CREATE DATABASE zui;"
