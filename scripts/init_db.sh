#!/usr/bin/env bash
set -x
set -eo pipefail

if ! [ -x "$(command -v docker)" ]; then
    echo >&2 "Error: docker is not installed."
    exit 1
fi

if ! [ -x "$(command -v sqlx)" ]; then
    echo >&2 "Error: sqlx is not installed."
    echo >&2 "Use:"
    echo >&2 "      cargo install sqlx-cli --no-default-features --features rustls,postgres"
    echo >&2 "to install it."
    exit 1
fi

# Check if a custom user has been set, otherwise default to postgres
DB_USER="${POSTGRES_USER:=postgres}"
# Check if a custom password has been set, otherwise default to 'password'
DB_PASSWORD="${POSTGRES_PASSWORD:=password}"
# Check if a custom database name has been set, otherwise default to newsletter
DB_NAME="${POSTGRES_DB:=newsletter}"
# Check if a custom port has been set, otherwise default to 5432
DB_PORT="${POSTGRES_PORT:=5432}"
# Check if a custom host has been set, otherwise default to localhost
DB_HOST="${POSTGRES_HOST:=localhost}"

# Docker container name
CONTAINER_NAME="zero2prod-postgres"

# Launch postgres using Docker
if [[ -z "${SKIP_DOCKER}" ]]
then
    docker run \
    --name "${CONTAINER_NAME}" \
    -e POSTGRES_USER=${DB_USER} \
    -e POSTGRES_PASSWORD=${DB_PASSWORD} \
    -e POSTGRES_DB=${DB_NAME} \
    -p "${DB_PORT}":5432 \
    -d postgres:17 \
    postgres -N 1000
fi

sleep 2

# Keep pinging postgres until it's ready to accept commands
export PGPASSWORD="${DB_PASSWORD}"
until docker exec "${CONTAINER_NAME}" psql -h "${DB_HOST}" -U "${DB_USER}" -p "${DB_PORT}" -d "postgres" -c '\q'; do
    >&2 echo "Postgres is still unavailable - sleeping"
    sleep 1
done

>&2 echo "Postgres is up and running on port ${DB_PORT}!"

# Export DATABASE_URL
DATABASE_URL=postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}
export DATABASE_URL
sqlx database create
sqlx migrate run

>&2 echo "Postgres has been migrated, ready to go!"
