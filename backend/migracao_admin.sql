-- =========================================================
-- MIGRAÇÃO ADMIN - rode no MySQL do Railway
-- =========================================================
-- Se der erro de "Duplicate column", a coluna já existe: ignore e siga.

ALTER TABLE users ADD COLUMN role ENUM('user', 'admin') NOT NULL DEFAULT 'user' AFTER avatar_data;
ALTER TABLE users ADD COLUMN is_banned TINYINT(1) NOT NULL DEFAULT 0 AFTER role;
ALTER TABLE users ADD COLUMN ban_reason VARCHAR(500) DEFAULT NULL AFTER is_banned;
ALTER TABLE users ADD COLUMN banned_at TIMESTAMP NULL DEFAULT NULL AFTER ban_reason;

-- Torne SUA conta admin (troque se o username for outro)
UPDATE users SET role = 'admin' WHERE username = 'YunoYuzuki';

-- Confira:
SELECT id, username, role, is_banned, ban_reason FROM users;
