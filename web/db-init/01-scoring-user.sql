CREATE USER "snb-admin" WITH PASSWORD 'snb-password';
GRANT ALL PRIVILEGES ON DATABASE national_bank TO "snb-admin";
GRANT ALL PRIVILEGES ON TABLE users TO "snb-admin";
GRANT ALL PRIVILEGES ON TABLE accounts TO "snb-admin";
GRANT ALL PRIVILEGES ON TABLE transactions TO "snb-admin";
