-- ============================================================
-- SCRIPT 01 : Schéma app_sys (Noyau)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON

CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT ═══════════════════════════════════════════════════════
PROMPT   CRÉATION DU SCHÉMA app_sys
PROMPT ═══════════════════════════════════════════════════════

PROMPT
PROMPT [1] Table sys_user
CREATE TABLE sys_user (
  user_id           NUMBER GENERATED ALWAYS AS IDENTITY,
  user_code         VARCHAR2(20)  NOT NULL,
  user_name         VARCHAR2(120) NOT NULL,
  password_hash     VARCHAR2(255),
  is_active         BOOLEAN       DEFAULT TRUE,
  email             VARCHAR2(255),
  language_code     VARCHAR2(5)   DEFAULT 'fr',
  password_changed_at DATE,
  created_at        TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  updated_at        TIMESTAMP,
  CONSTRAINT pk_sys_user      PRIMARY KEY (user_id),
  CONSTRAINT uk_sys_user_code UNIQUE (user_code)
);

PROMPT [2] Table sys_access_key
CREATE TABLE sys_access_key (
  access_key_id     NUMBER GENERATED ALWAYS AS IDENTITY,
  access_key_code   VARCHAR2(40)  NOT NULL,
  access_key_name   VARCHAR2(120) NOT NULL,
  is_active         BOOLEAN       DEFAULT TRUE,
  key_type          VARCHAR2(12),
  password          VARCHAR2(40),
  memo              VARCHAR2(1000),
  created_at        TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_sys_access_key      PRIMARY KEY (access_key_id),
  CONSTRAINT uk_sys_access_key_code UNIQUE (access_key_code)
);

PROMPT [3] Table sys_user_access
CREATE TABLE sys_user_access (
  user_id           NUMBER        NOT NULL,
  access_key_id     NUMBER        NOT NULL,
  is_active         BOOLEAN       DEFAULT TRUE,
  valid_from        DATE,
  valid_to          DATE,
  CONSTRAINT pk_sys_user_access PRIMARY KEY (user_id, access_key_id),
  CONSTRAINT fk_sys_user_access_user FOREIGN KEY (user_id) 
    REFERENCES sys_user(user_id),
  CONSTRAINT fk_sys_user_access_key FOREIGN KEY (access_key_id) 
    REFERENCES sys_access_key(access_key_id)
);

PROMPT [4] Table sys_program
CREATE TABLE sys_program (
  program_id      NUMBER GENERATED ALWAYS AS IDENTITY,
  program_code    VARCHAR2(32) NOT NULL,
  parent_code     VARCHAR2(32),
  program_name    VARCHAR2(50) NOT NULL,
  app_code        VARCHAR2(12) NOT NULL,
  created_at      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_sys_program      PRIMARY KEY (program_id),
  CONSTRAINT uk_sys_program_code UNIQUE (program_code)
);

PROMPT [5] Table sys_parameter
CREATE TABLE sys_parameter (
  parameter_id    NUMBER GENERATED ALWAYS AS IDENTITY,
  parameter_code  VARCHAR2(40)  NOT NULL,
  parameter_key   VARCHAR2(12)  NOT NULL,
  parameter_name  VARCHAR2(120) NOT NULL,
  memo            VARCHAR2(1020),
  string_value    VARCHAR2(120),
  number_value    NUMBER(16,4),
  rate_value      NUMBER(5,2),
  created_at      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_sys_parameter PRIMARY KEY (parameter_id),
  CONSTRAINT uk_sys_parameter_key UNIQUE (parameter_code, parameter_key)
);

PROMPT [6] Table sys_currency
CREATE TABLE sys_currency (
  currency_code   VARCHAR2(12)  NOT NULL,
  currency_name   VARCHAR2(120) NOT NULL,
  is_fixed_rate   BOOLEAN       DEFAULT TRUE,
  decimal_places  NUMBER(1)     DEFAULT 2,
  created_at      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_sys_currency PRIMARY KEY (currency_code)
);

PROMPT [7] Table sys_country
CREATE TABLE sys_country (
  country_code    VARCHAR2(3)  NOT NULL,
  country_name    VARCHAR2(30) NOT NULL,
  CONSTRAINT pk_sys_country PRIMARY KEY (country_code)
);

PROMPT [8] Table sys_city
CREATE TABLE sys_city (
  city_code       VARCHAR2(3)  NOT NULL,
  country_code    VARCHAR2(3)  NOT NULL,
  city_name       VARCHAR2(30),
  CONSTRAINT pk_sys_city PRIMARY KEY (city_code),
  CONSTRAINT fk_sys_city_country FOREIGN KEY (country_code) 
    REFERENCES sys_country(country_code)
);

PROMPT
PROMPT [9] Insertion des données de base

INSERT INTO sys_currency VALUES ('XOF', 'Franc CFA', TRUE, 0, SYSTIMESTAMP);
INSERT INTO sys_currency VALUES ('EUR', 'Euro', TRUE, 2, SYSTIMESTAMP);
INSERT INTO sys_currency VALUES ('USD', 'Dollar US', TRUE, 2, SYSTIMESTAMP);

INSERT INTO sys_country VALUES ('CIV', 'Côte d''Ivoire');
INSERT INTO sys_country VALUES ('SEN', 'Sénégal');
INSERT INTO sys_country VALUES ('CMR', 'Cameroun');

INSERT INTO sys_city VALUES ('ABJ', 'CIV', 'Abidjan');
INSERT INTO sys_city VALUES ('DKR', 'SEN', 'Dakar');
INSERT INTO sys_city VALUES ('DLA', 'CMR', 'Douala');

INSERT INTO sys_user (user_code, user_name, is_active, email)
VALUES ('ADMIN', 'Administrateur', TRUE, 'admin@example.com');
INSERT INTO sys_user (user_code, user_name, is_active, email)
VALUES ('CAISSIER1', 'Caissier 1', TRUE, 'caissier1@example.com');

INSERT INTO sys_access_key (access_key_code, access_key_name, is_active, key_type)
VALUES ('POS_SALE', 'Vente en caisse', TRUE, 'POS');
INSERT INTO sys_access_key (access_key_code, access_key_name, is_active, key_type)
VALUES ('POS_CANCEL', 'Annulation ticket', TRUE, 'POS');
INSERT INTO sys_access_key (access_key_code, access_key_name, is_active, key_type)
VALUES ('STOCK_EDIT', 'Modification stock', TRUE, 'STOCK');

INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value)
VALUES ('GENERAL', 'CUR', 'Devise par défaut', 'XOF');
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value)
VALUES ('GENERAL', 'COMPANY_NAME', 'Nom de la société', 'Ma Société');

COMMIT;

PROMPT
PROMPT [10] Validation
SELECT table_name FROM user_tables ORDER BY table_name;

PROMPT
PROMPT [11] Test BOOLEAN natif
SELECT user_code, user_name, is_active
  FROM sys_user
 WHERE is_active = TRUE;

SELECT access_key_code, access_key_name, is_active
  FROM sys_access_key
 WHERE is_active = TRUE;

PROMPT
PROMPT [12] Volumétrie
SELECT 'sys_user'          AS tbl, COUNT(*) AS nb FROM sys_user
UNION ALL SELECT 'sys_access_key',  COUNT(*) FROM sys_access_key
UNION ALL SELECT 'sys_currency',    COUNT(*) FROM sys_currency
UNION ALL SELECT 'sys_country',     COUNT(*) FROM sys_country
UNION ALL SELECT 'sys_city',        COUNT(*) FROM sys_city
UNION ALL SELECT 'sys_parameter',   COUNT(*) FROM sys_parameter;

PROMPT ═══════════════════════════════════════════════════════
PROMPT   ✅ SCHÉMA app_sys TERMINÉ
PROMPT ═══════════════════════════════════════════════════════