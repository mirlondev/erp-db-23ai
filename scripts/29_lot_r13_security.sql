-- ============================================================
-- SCRIPT 29 : LOT R13 — Sécurité avancée & Audit
-- Migration Oracle 11g (rôles legacy, audit manuel)
--                  → Oracle 23ai/26ai (RBAC + audit complet app_sys)
-- ============================================================
-- 5 nouvelles tables dans app_sys :
--   sys_role, sys_user_role, sys_permission,
--   sys_role_permission, sys_audit_trail
--
-- Notes de modernisation (vs procedure.txt d'origine) :
--  * BOOLEAN pour is_active, is_sensitive, requires_mfa (legacy Y/N)
--  * VARCHAR2(20) user_code (vs 5 legacy)
--  * JSON pour old_values/new_values (format structuré Oracle 23ai)
--  * RBAC complet : rôle → permissions granulaires par resource+action
--  * VPD-ready : entity_type/entity_id polymorphiques
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   LOT R13 : SÉCURITÉ AVANCÉE & AUDIT (5 tables)
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [1/5] sys_role  — rôles applicatifs
CREATE TABLE sys_role (
  role_code           VARCHAR2(20)  NOT NULL,
  role_name           VARCHAR2(120) NOT NULL,
  description         VARCHAR2(1000),
  role_level          NUMBER(2)     DEFAULT 1,           -- 1=Consult, 2=Cashier, 3=Stock/Account, 4=Manager, 5=Admin
  is_active           BOOLEAN       DEFAULT TRUE,
  requires_mfa        BOOLEAN       DEFAULT FALSE,
  max_session_minutes NUMBER(4)     DEFAULT 480,        -- 8h par défaut
  ip_whitelist        VARCHAR2(2000),                    -- CSV d'IPs autorisées (NULL = tout)
  created_by          VARCHAR2(20),
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_sys_role              PRIMARY KEY (role_code),
  CONSTRAINT ck_sys_role_level        CHECK (role_level BETWEEN 1 AND 10),
  CONSTRAINT ck_sys_role_session      CHECK (max_session_minutes > 0)
);

PROMPT
PROMPT [2/5] sys_user_role  — liaison utilisateurs ↔ rôles (avec validité temporelle)
CREATE TABLE sys_user_role (
  user_id             NUMBER        NOT NULL,           -- FK vers app_sys.sys_user (créé en R0)
  role_code           VARCHAR2(20)  NOT NULL,
  assigned_at         TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  assigned_by         VARCHAR2(20),
  valid_from          DATE          DEFAULT SYSDATE,
  valid_to            DATE,                              -- NULL = permanent
  is_active           BOOLEAN       DEFAULT TRUE,
  CONSTRAINT pk_sys_user_role         PRIMARY KEY (user_id, role_code),
  CONSTRAINT fk_sys_user_role_user    FOREIGN KEY (user_id)
    REFERENCES sys_user(user_id) ON DELETE CASCADE,
  CONSTRAINT fk_sys_user_role_role    FOREIGN KEY (role_code)
    REFERENCES sys_role(role_code) ON DELETE CASCADE,
  CONSTRAINT ck_sys_user_role_validity CHECK (valid_to IS NULL OR valid_to >= valid_from)
);

CREATE INDEX ix_sys_user_role_user     ON sys_user_role(user_id);
CREATE INDEX ix_sys_user_role_role     ON sys_user_role(role_code);
CREATE INDEX ix_sys_user_role_active   ON sys_user_role(is_active, valid_from, valid_to);

PROMPT
PROMPT [3/5] sys_permission  — permissions atomiques (resource + action)
CREATE TABLE sys_permission (
  permission_code     VARCHAR2(60)  NOT NULL,
  permission_name     VARCHAR2(120) NOT NULL,
  resource            VARCHAR2(60)  NOT NULL,           -- SALES | STOCK | PRODUCT | PARTY | AR | REPORT | SYS
  action              VARCHAR2(20)  NOT NULL,           -- CREATE | READ | UPDATE | DELETE | CANCEL | APPROVE | ADMIN
  description         VARCHAR2(500),
  is_sensitive        BOOLEAN       DEFAULT FALSE,      -- opération sensible (audit renforcé)
  requires_approval   BOOLEAN       DEFAULT FALSE,      -- workflow d'approbation
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_sys_permission         PRIMARY KEY (permission_code),
  CONSTRAINT ck_sys_perm_action        CHECK (action IN ('CREATE','READ','UPDATE','DELETE','CANCEL','APPROVE','REFUND','DISCOUNT','EXPORT','ADMIN','PRINT'))
);

CREATE INDEX ix_sys_perm_resource      ON sys_permission(resource, action);

PROMPT
PROMPT [4/5] sys_role_permission  — matrice rôle × permission
CREATE TABLE sys_role_permission (
  role_code           VARCHAR2(20)  NOT NULL,
  permission_code     VARCHAR2(60)  NOT NULL,
  granted_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  granted_by          VARCHAR2(20),
  valid_from          DATE          DEFAULT SYSDATE,
  valid_to            DATE,
  CONSTRAINT pk_sys_role_permission    PRIMARY KEY (role_code, permission_code),
  CONSTRAINT fk_sys_role_perm_role     FOREIGN KEY (role_code)
    REFERENCES sys_role(role_code) ON DELETE CASCADE,
  CONSTRAINT fk_sys_role_perm_perm     FOREIGN KEY (permission_code)
    REFERENCES sys_permission(permission_code) ON DELETE CASCADE,
  CONSTRAINT ck_sys_role_perm_validity  CHECK (valid_to IS NULL OR valid_to >= valid_from)
);

CREATE INDEX ix_sys_role_perm_role      ON sys_role_permission(role_code);
CREATE INDEX ix_sys_role_perm_perm      ON sys_role_permission(permission_code);
CREATE INDEX ix_sys_role_perm_validity  ON sys_role_permission(valid_from, valid_to);

PROMPT
PROMPT [5/5] sys_audit_trail  — journal d'audit applicatif (traçabilité fine)
CREATE TABLE sys_audit_trail (
  audit_id            NUMBER GENERATED ALWAYS AS IDENTITY,
  user_code           VARCHAR2(20)  NOT NULL,
  user_role_at_time   VARCHAR2(20),                     -- rôle au moment de l'action (snapshot)
  action_type         VARCHAR2(20)  NOT NULL,           -- CREATE | READ | UPDATE | DELETE | LOGIN | LOGOUT | EXPORT
  entity_type         VARCHAR2(60)  NOT NULL,           -- table/vue impactée (cross-schema)
  entity_id           VARCHAR2(100),                    -- PK polymorphique
  old_values          JSON,                             -- avant modification (Oracle 23ai JSON natif)
  new_values          JSON,                             -- après modification
  changed_columns     VARCHAR2(2000),                   -- colonnes impactées
  ip_address          VARCHAR2(45),
  user_agent          VARCHAR2(500),
  session_id          VARCHAR2(64),
  request_id          VARCHAR2(64),
  severity            VARCHAR2(10)  DEFAULT 'INFO',     -- INFO | WARN | CRITICAL
  performed_at        TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_sys_audit_trail       PRIMARY KEY (audit_id),
  CONSTRAINT ck_sys_audit_action      CHECK (action_type IN
    ('CREATE','READ','UPDATE','DELETE','LOGIN','LOGOUT','EXPORT','APPROVE','REJECT','PRINT','REFUND','VOID','OTHER')),
  CONSTRAINT ck_sys_audit_severity     CHECK (severity IN ('INFO','WARN','CRITICAL'))
);

CREATE INDEX ix_audit_user        ON sys_audit_trail(user_code, performed_at DESC);
CREATE INDEX ix_audit_entity      ON sys_audit_trail(entity_type, entity_id);
CREATE INDEX ix_audit_action      ON sys_audit_trail(action_type, performed_at DESC);
CREATE INDEX ix_audit_severity    ON sys_audit_trail(severity, performed_at) WHERE severity IN ('WARN','CRITICAL');
CREATE INDEX ix_audit_session     ON sys_audit_trail(session_id);
CREATE INDEX ix_audit_ip          ON sys_audit_trail(ip_address);

PROMPT
PROMPT ═══ Privilèges ═══
CONNECT system/oracle@localhost:1521/FREEPDB1

-- app_api pour exposition JSON des rôles
GRANT SELECT ON app_sys.sys_role             TO app_api;
GRANT SELECT ON app_sys.sys_permission       TO app_api;
GRANT SELECT ON app_sys.sys_role_permission  TO app_api;
GRANT SELECT, INSERT ON app_sys.sys_user_role TO app_api;

-- Tous les schémas métier peuvent écrire dans audit_trail
GRANT INSERT ON app_sys.sys_audit_trail      TO app_sales;
GRANT INSERT ON app_sys.sys_audit_trail      TO app_inv;
GRANT INSERT ON app_sys.sys_audit_trail      TO app_party;
GRANT INSERT ON app_sys.sys_audit_trail      TO app_ar;
GRANT INSERT ON app_sys.sys_audit_trail      TO app_product;
GRANT INSERT ON app_sys.sys_audit_trail      TO app_gl;
GRANT INSERT ON app_sys.sys_audit_trail      TO app_pos;
GRANT INSERT ON app_sys.sys_audit_trail      TO app_cash;
GRANT INSERT ON app_sys.sys_audit_trail      TO app_doc;

-- Lecture des rôles/permissions pour tous
GRANT SELECT ON app_sys.sys_role             TO app_sales;
GRANT SELECT ON app_sys.sys_user_role        TO app_sales;
GRANT SELECT ON app_sys.sys_role             TO app_gl;
GRANT SELECT ON app_sys.sys_user_role        TO app_gl;

PROMPT
PROMPT ═══ Validation — Tables ═══
CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1
SELECT table_name, num_rows
  FROM user_tables
 WHERE table_name IN ('SYS_ROLE','SYS_USER_ROLE','SYS_PERMISSION',
                      'SYS_ROLE_PERMISSION','SYS_AUDIT_TRAIL')
 ORDER BY table_name;

PROMPT
PROMPT ═══ Validation — Contraintes ═══
SELECT constraint_name, constraint_type, status
  FROM user_constraints
 WHERE table_name IN ('SYS_ROLE','SYS_USER_ROLE','SYS_PERMISSION',
                      'SYS_ROLE_PERMISSION','SYS_AUDIT_TRAIL')
 ORDER BY table_name, constraint_name;

PROMPT
PROMPT ═══ Validation — Objets invalides ═══
SELECT object_name, object_type, status
  FROM user_objects
 WHERE status = 'INVALID';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ LOT R13 TERMINÉ (5 tables)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
