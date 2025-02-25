FROM docker.io/postgres:17-alpine

ARG REPLICA_USER=replicator
ARG REPLICA_PASSWORD=replicator
ARG REPLICATION_SLOT_NAME=replication_slot
ARG INIT_SQL=00_init.sql
ARG POSTGRES_LOGGING_COLLECTOR=
ARG POSTGRES_LOG_DESTINATION=
ARG POSTGRES_LOG_STATEMENT=
ENV CONF_SAMPLE="/usr/local/share/postgresql/postgresql.conf.sample"

WORKDIR /docker-entrypoint-initdb.d

USER root

RUN touch $INIT_SQL
RUN chown -R postgres:postgres $INIT_SQL
RUN echo "CREATE USER ${REPLICA_USER} WITH REPLICATION ENCRYPTED PASSWORD '${REPLICA_PASSWORD}';" > $INIT_SQL
RUN echo "SELECT pg_create_physical_replication_slot('${REPLICATION_SLOT_NAME}');" >> $INIT_SQL

# Enable logging collector if given
RUN if [[ ! -z "${POSTGRES_LOGGING_COLLECTOR}" ]]; then sed -i "s/#\(logging_collector = \)off\(.*\)/\1${POSTGRES_LOGGING_COLLECTOR}\2/" ${CONF_SAMPLE}; fi

# Override  default log destination if given
RUN if [[ ! -z "${POSTGRES_LOG_DESTINATION}" ]]; then sed -i "s/#\(log_destination = \)'stderr'\(.*\)/\1'${POSTGRES_LOG_DESTINATION}'\2/" ${CONF_SAMPLE}; fi

# Override log statement if given
RUN if [[ ! -z "${POSTGRES_LOG_STATEMENT}" ]]; then sed -i "s/#\(log_statement = \)'none'\(.*\)/\1'${POSTGRES_LOG_STATEMENT}'\2/" ${CONF_SAMPLE}; fi

WORKDIR /

USER postgres

CMD  ["postgres", "-c", "wal_level=replica", "-c", "hot_standby=on", "-c", "max_wal_senders=10", "-c", "max_replication_slots=10", "-c", "hot_standby_feedback=on" ]
