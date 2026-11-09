-- Runs once, the first time the MySQL container starts with an empty volume.
-- Creates the separate database the automated tests use, so tests never touch your dev data.
CREATE DATABASE IF NOT EXISTS brunchy_test CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
GRANT ALL PRIVILEGES ON brunchy_test.* TO 'brunchy'@'%';
FLUSH PRIVILEGES;
