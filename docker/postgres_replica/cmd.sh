until pg_basebackup --pgdata=/var/lib/postgresql/data -R --slot=$PRIMARY_REPLICATION_SLOT --host=$PRIMARY_DATABASE_HOST --port=$PRIMARY_DATABASE_PORT
do
  echo 'Waiting for primary to connect...'
  sleep 1s
done

echo 'Backup done, starting replica...'
chmod 0700 /var/lib/postgresql/data
postgres
