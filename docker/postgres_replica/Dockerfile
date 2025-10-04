FROM docker.io/postgres:17.6-alpine

ENV PRIMARY_DATABASE_HOST=localhost
ENV PRIMARY_DATABASE_PORT=5432
ENV PRIMARY_REPLICATION_SLOT=replication_slot


COPY start_server start_server

USER root
RUN chown -R postgres:postgres start_server
USER postgres
RUN chmod u+x start_server

CMD [ "./start_server" ]
