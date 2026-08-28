-- =========================================================
-- Limbo of Memories - Schema MySQL (completo)
-- =========================================================

CREATE TABLE IF NOT EXISTS users (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    username      VARCHAR(50)  NOT NULL UNIQUE,
    email         VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    nickname      VARCHAR(50)  DEFAULT NULL,
    bio           VARCHAR(300) DEFAULT NULL,
    avatar_data   LONGTEXT     DEFAULT NULL,
    role          ENUM('user', 'admin') NOT NULL DEFAULT 'user',
    is_banned     TINYINT(1)   NOT NULL DEFAULT 0,
    ban_reason    VARCHAR(500) DEFAULT NULL,
    banned_at     TIMESTAMP    NULL DEFAULT NULL,
    nickname_changed_at TIMESTAMP NULL DEFAULT NULL,
    password_changed_at TIMESTAMP NULL DEFAULT NULL,
    last_seen     DATETIME NULL DEFAULT NULL,
    banner_color  VARCHAR(7) NULL DEFAULT '#8b5cf6',
    email_verified TINYINT(1) NOT NULL DEFAULT 0,
    email_verify_token VARCHAR(64) NULL DEFAULT NULL,
    email_verify_expires DATETIME NULL DEFAULT NULL,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS game_progress (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    user_id          INT NOT NULL UNIQUE,
    playtime_seconds INT     NOT NULL DEFAULT 0,
    fitas_normais    TINYINT NOT NULL DEFAULT 0,
    fitas_douradas   TINYINT NOT NULL DEFAULT 0,
    cartas           TINYINT NOT NULL DEFAULT 0,
    updated_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_progress_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS community_posts (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    user_id    INT NOT NULL,
    content    VARCHAR(500) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_post_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS bug_reports (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    user_id    INT NOT NULL,
    title      VARCHAR(120) NOT NULL,
    description VARCHAR(1000) NOT NULL,
    status     ENUM('open', 'reviewing', 'resolved') NOT NULL DEFAULT 'open',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_bug_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_progress_playtime ON game_progress (playtime_seconds ASC);
CREATE INDEX idx_posts_created ON community_posts (created_at DESC);
CREATE INDEX idx_bugs_status ON bug_reports (status, created_at DESC);


CREATE TABLE IF NOT EXISTS cloud_saves (
    user_id INT NOT NULL,
    slot INT NOT NULL,
    save_json LONGTEXT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, slot),
    CONSTRAINT fk_cloud_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
