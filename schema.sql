-- -----------------------------------------
-- DATABASE & COLLATION
-- -----------------------------------------
CREATE DATABASE IF NOT EXISTS dragon_shield_core 
  CHARACTER SET utf8mb4 
  COLLATE utf8mb4_unicode_ci;

USE dragon_shield_core;

-- Users
CREATE TABLE users (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  parent_id BIGINT UNSIGNED DEFAULT NULL,
  reseller_level TINYINT DEFAULT 0,
  username VARCHAR(64) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  email VARCHAR(128) UNIQUE,
  status ENUM('active', 'suspended', 'expired', 'pending') DEFAULT 'pending',
  exp_date DATETIME NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  last_login DATETIME NULL,
  timezone VARCHAR(64) DEFAULT 'UTC',
  api_token VARCHAR(128) NULL,
  api_token_expiry DATETIME NULL,
  fingerprint_hash VARCHAR(128) NULL,
  ip_lock_enabled TINYINT DEFAULT 0,
  allowed_ip VARCHAR(45) NULL, -- ✅ Fix: VARCHAR(45) în loc de CIDR
  credit_balance DECIMAL(10,2) DEFAULT 0.00,
  max_connections INT DEFAULT 1,
  bandwidth_limit_kbps INT DEFAULT 0,
  branding JSON NULL,
  INDEX idx_username (username),
  INDEX idx_parent (parent_id),
  INDEX idx_status (status),
  INDEX idx_token (api_token),
  FOREIGN KEY (parent_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Streams
CREATE TABLE streams (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  reseller_id BIGINT UNSIGNED NOT NULL,
  type ENUM('live', 'vod', 'series', 'radio', 'youtube') NOT NULL,
  name VARCHAR(256) NOT NULL,
  stream_source TEXT NOT NULL,
  is_protected TINYINT DEFAULT 1,
  transcoding_profile JSON NULL,
  abr_enabled TINYINT DEFAULT 0,
  abr_profiles JSON NULL,
  hls_segment_duration SMALLINT DEFAULT 4,
  output_path VARCHAR(512) NOT NULL,
  yt_dlp_proxy TINYINT DEFAULT 0,
  custom_ffmpeg_cmd TEXT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  active TINYINT DEFAULT 1,
  INDEX idx_reseller (reseller_id),
  INDEX idx_type (type),
  INDEX idx_name (name),
  FOREIGN KEY (reseller_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Series
CREATE TABLE series (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  reseller_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(256) NOT NULL,
  cover_url VARCHAR(512) NULL,
  year YEAR NULL,
  description TEXT NULL,
  imdb_id VARCHAR(32) NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_title (title),
  INDEX idx_imdb (imdb_id),
  FOREIGN KEY (reseller_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Episodes
CREATE TABLE episodes (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  series_id BIGINT UNSIGNED NOT NULL,
  season_num SMALLINT NOT NULL,
  episode_num SMALLINT NOT NULL,
  title VARCHAR(256) NULL,
  stream_id BIGINT UNSIGNED NOT NULL,
  duration_sec INT NULL,
  released_date DATE NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_series_season (series_id, season_num),
  INDEX idx_stream (stream_id),
  FOREIGN KEY (series_id) REFERENCES series(id) ON DELETE CASCADE,
  FOREIGN KEY (stream_id) REFERENCES streams(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- VOD Files
CREATE TABLE vod_files (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  reseller_id BIGINT UNSIGNED NOT NULL,
  filename VARCHAR(512) NOT NULL,
  filepath VARCHAR(1024) NOT NULL,
  title VARCHAR(256) NOT NULL,
  year YEAR NULL,
  genre VARCHAR(128) NULL,
  director VARCHAR(128) NULL,
  cast TEXT NULL,
  duration_sec INT NULL,
  cover_url VARCHAR(512) NULL,
  stream_id BIGINT UNSIGNED NOT NULL,
  status ENUM('pending', 'transcoding', 'ready', 'failed') DEFAULT 'pending',
  metadata_source ENUM('filename', 'tmdb', 'manual') DEFAULT 'filename',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_title (title),
  INDEX idx_filepath (filepath(255)),
  INDEX idx_status (status),
  FOREIGN KEY (reseller_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (stream_id) REFERENCES streams(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Bouquets
CREATE TABLE bouquets (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  reseller_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(128) NOT NULL,
  type ENUM('tv', 'radio', 'movie', 'series') DEFAULT 'tv',
  is_public TINYINT DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_reseller (reseller_id),
  FOREIGN KEY (reseller_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Bouquet-Stream Mapping
CREATE TABLE bouquet_streams (
  bouquet_id BIGINT UNSIGNED,
  stream_id BIGINT UNSIGNED,
  position INT DEFAULT 0,
  PRIMARY KEY (bouquet_id, stream_id),
  FOREIGN KEY (bouquet_id) REFERENCES bouquets(id) ON DELETE CASCADE,
  FOREIGN KEY (stream_id) REFERENCES streams(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Server Nodes
CREATE TABLE server_nodes (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  hostname VARCHAR(128) NOT NULL,
  ip_address VARCHAR(45) NOT NULL, -- ✅ Fix: VARCHAR(45) în loc de INET
  type ENUM('master', 'edge') DEFAULT 'edge',
  load_weight INT DEFAULT 100,
  is_active TINYINT DEFAULT 1,
  last_heartbeat DATETIME NULL,
  cpu_usage DECIMAL(5,2) DEFAULT 0.00,
  mem_usage DECIMAL(5,2) DEFAULT 0.00,
  stream_count INT DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_ip (ip_address),
  INDEX idx_active (is_active)
) ENGINE=InnoDB;

-- Stream Tokens
CREATE TABLE stream_tokens (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  stream_id BIGINT UNSIGNED NOT NULL,
  token VARCHAR(64) NOT NULL,
  signature VARCHAR(128) NOT NULL,
  expires_at DATETIME NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  used_count INT DEFAULT 0,
  max_allowed INT DEFAULT 1,
  revoked TINYINT DEFAULT 0,
  INDEX idx_token (token),
  INDEX idx_user_stream (user_id, stream_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (stream_id) REFERENCES streams(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Activity Logs
CREATE TABLE activity_logs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NULL,
  action VARCHAR(64) NOT NULL,
  ip_address VARCHAR(45) NOT NULL, -- ✅ Fix: VARCHAR(45) în loc de INET
  user_agent TEXT NULL,
  details JSON NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user (user_id),
  INDEX idx_action (action),
  INDEX idx_ip (ip_address),
  INDEX idx_created (created_at)
) ENGINE=InnoDB;

-- System Config
CREATE TABLE system_config (
  id INT AUTO_INCREMENT PRIMARY KEY,
  config_key VARCHAR(128) UNIQUE NOT NULL,
  value JSON NOT NULL,
  description TEXT,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  version INT DEFAULT 1
) ENGINE=InnoDB;
