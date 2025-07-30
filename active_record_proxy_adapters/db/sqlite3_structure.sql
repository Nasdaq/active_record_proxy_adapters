CREATE TABLE schema_migrations (
    version character varying(255) NOT NULL
);
CREATE TABLE users (
    id integer PRIMARY KEY NOT NULL,
    name text NOT NULL,
    email text NOT NULL,
    created_at timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE UNIQUE INDEX unique_schema_migrations ON schema_migrations (version);
