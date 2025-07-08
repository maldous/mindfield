-- Create keycloak database and user
CREATE DATABASE keycloak;
GRANT ALL PRIVILEGES ON DATABASE keycloak TO lixit;
ALTER ROLE lixit WITH PASSWORD 'lixit_dev_password';
