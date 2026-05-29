DROP INDEX IF EXISTS users_email_idx;
DROP TABLE IF EXISTS users;

-- Drop extensions after the table that depended on the citext type.
DROP EXTENSION IF EXISTS pgcrypto;
DROP EXTENSION IF EXISTS citext;
