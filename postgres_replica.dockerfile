FROM docker.io/postgres:14-alpine

ENV PRIMARY_DATABASE_HOST=localhost
ENV PRIMARY_DATABASE_PORT=5432
ENV PRIMARY_REPLICATION_SLOT=replication_slot


COPY docker/postgres_replica/cmd.sh cmd.sh

USER root
RUN chown -R postgres:postgres cmd.sh
USER postgres
RUN chmod u+x cmd.sh

CMD [ "./cmd.sh" ]
