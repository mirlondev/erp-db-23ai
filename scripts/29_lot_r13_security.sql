-- ============================================================
-- SCRIPT 29 : LOT R13 - Securite avancee & Audit (FINAL)
-- ============================================================
-- Corrections :
--  * ORA-03050 : RESOURCE est un mot reserve -> renomme en resource_code
--  * ORA-02158 : index partiel WHERE -> index fonctionnel CASE
--  * SP2-0734 : suppression emoji + SQLBLANKLINES ON
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF
SET SQLBLANKLINES ON

CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT ==============================================================
PROMPT   LOT R13 : SECURITE AVANCEE & AUDIT (5 tables)
PROMPT ==============================================================

-- Nettoyage idempotent
DECLARE
  PROCEDURE d(p_t VARCHAR2, p_n VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE 'DROP '||p_t||' '||p_n;
    DBMS_OUTPUT.PUT_LINE('  DROP '||p_t||' '||p_n);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
BEGIN
  d('TABLE','sys_audit_trail');
  d('TABLE','sys_role_permission');
  d('TABLE','sys_permission');
  d('TABLE','sys_user_role');
  d('TABLE','sys_role');
END;
/

PROMPT
PROMPT [1/5] sys_role
CREATE TABLE sys_role (
  role_code           VARCHAR2(20)  NOT NULL,
  role_name           VARCHAR2(120) NOT NULL,
  description         VARCHAR2(1000),
  role_level          NUMBER(2)     DEFAULT 1,
  is_active           BOOLEAN       DEFAULT TRUE,
  requires_mfa        BOOLEAN       DEFAULT FALSE,
  max_session_minutes NUMBER(4)     DEFAULT 480,
  ip_whitelist        VARCHAR2(2000),
  created_by          VARCHAR2(20),
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_sys_role              PRIMARY KEY (role_code),
  CONSTRAINT ck_sys_role_level        CHECK (role_level BETWEEN 1 AND 10),
  CONSTRAINT ck_sys_role_session      CHECK (max_session_minutes > 0)
);

PROMPT
PROMPT [2/5] sys_user_role
CREATE TABLE sys_user_role (
  user_id             NUMBER        NOT NULL,
  role_code           VARCHAR2(20)  NOT NULL,
  assigned_at         TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  assigned_by         VARCHAR2(20),
  valid_from          DATE          DEFAULT SYSDATE,
  valid_to            DATE,
  is_active           BOOLEAN       DEFAULT TRUE,
  CONSTRAINT pk_sys_user_role         PRIMARY KEY (user_id, role_code),
  CONSTRAINT fk_sys_user_role_user    FOREIGN KEY (user_id)
    REFERENCES sys_user(user_id) ON DELETE CASCADE,
  CONSTRAINT fk_sys_user_role_role    FOREIGN KEY (role_code)
    REFERENCES sys_role(role_code) ON DELETE CASCADE,
  CONSTRAINT ck_sys_user_role_validity CHECK (valid_to IS NULL OR valid_to >= valid_from)
);

CREATE INDEX ix_sys_user_role_user   ON sys_user_role(user_id);
CREATE INDEX ix_sys_user_role_role   ON sys_user_role(role_code);
CREATE INDEX ix_sys_user_role_active ON sys_user_role(
  CASE WHEN is_active THEN valid_from END,
  CASE WHEN is_active THEN valid_to END
);

PROMPT
PROMPT [3/5] sys_permission
PROMPT   -- CORRECTION : resource -> resource_code (RESOURCE mot reserve)
CREATE TABLE sys_permission (
  permission_code     VARCHAR2(60)  NOT NULL,
  permission_name     VARCHAR2(120) NOT NULL,
  resource_code       VARCHAR2(60)  NOT NULL,
  action              VARCHAR2(20)  NOT NULL,
  description         VARCHAR2(500),
  is_sensitive        BOOLEAN       DEFAULT FALSE,
  requires_approval   BOOLEAN       DEFAULT FALSE,
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_sys_permission         PRIMARY KEY (permission_code),
  CONSTRAINT ck_sys_perm_action        CHECK (action IN
    ('CREATE','READ','UPDATE','DELETE','CANCEL','APPROVE','REFUND','DISCOUNT','EXPORT','ADMIN','PRINT'))
);

CREATE INDEX ix_sys_perm_resource ON sys_permission(resource_code, action);

PROMPT
PROMPT [4/5] sys_role_permission
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
  CONSTRAINT ck_sys_role_perm_validity CHECK (valid_to IS NULL OR valid_to >= valid_from)
);

CREATE INDEX ix_sys_role_perm_role     ON sys_role_permission(role_code);
CREATE INDEX ix_sys_role_perm_perm     ON sys_role_permission(permission_code);
CREATE INDEX ix_sys_role_perm_validity ON sys_role_permission(valid_from, valid_to);

PROMPT
PROMPT [5/5] sys_audit_trail
CREATE TABLE sys_audit_trail (
  audit_id            NUMBER GENERATED ALWAYS AS IDENTITY,
  user_code           VARCHAR2(20)  NOT NULL,
  user_role_at_time   VARCHAR2(20),
  action_type         VARCHAR2(20)  NOT NULL,
  entity_type         VARCHAR2(60)  NOT NULL,
  entity_id           VARCHAR2(100),
  old_values          JSON,
  new_values          JSON,
  changed_columns     VARCHAR2(2000),
  ip_address          VARCHAR2(45),
  user_agent          VARCHAR2(500),
  session_id          VARCHAR2(64),
  request_id          VARCHAR2(64),
  severity            VARCHAR2(10)  DEFAULT 'INFO',
  performed_at        TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_sys_audit_trail       PRIMARY KEY (audit_id),
  CONSTRAINT ck_sys_audit_action      CHECK (action_type IN
    ('CREATE','READ','UPDATE','DELETE','LOGIN','LOGOUT','EXPORT','APPROVE','REJECT','PRINT','REFUND','VOID','OTHER')),
  CONSTRAINT ck_sys_audit_severity    CHECK (severity IN ('INFO','WARN','CRITICAL'))
);

CREATE INDEX ix_audit_user     ON sys_audit_trail(user_code, performed_at DESC);
CREATE INDEX ix_audit_entity   ON sys_audit_trail(entity_type, entity_id);
CREATE INDEX ix_audit_action   ON sys_audit_trail(action_type, performed_at DESC);
CREATE INDEX ix_audit_session  ON sys_audit_trail(session_id);
CREATE INDEX ix_audit_ip       ON sys_audit_trail(ip_address);

-- CORRECTION ORA-02158 : index partiel -> index fonctionnel
CREATE INDEX ix_audit_severity ON sys_audit_trail(
  CASE WHEN severity IN ('WARN','CRITICAL') THEN severity END,
  CASE WHEN severity IN ('WARN','CRITICAL') THEN performed_at END
);

PROMPT
PROMPT Privileges
CONNECT system/oracle@localhost:1521/FREEPDB1

GRANT SELECT ON app_sys.sys_role             TO app_api;
GRANT SELECT ON app_sys.sys_permission       TO app_api;
GRANT SELECT ON app_sys.sys_role_permission  TO app_api;
GRANT SELECT, INSERT ON app_sys.sys_user_role TO app_api;

GRANT INSERT ON app_sys.sys_audit_trail TO app_sales;
GRANT INSERT ON app_sys.sys_audit_trail TO app_inv;
GRANT INSERT ON app_sys.sys_audit_trail TO app_party;
GRANT INSERT ON app_sys.sys_audit_trail TO app_ar;
GRANT INSERT ON app_sys.sys_audit_trail TO app_product;
GRANT INSERT ON app_sys.sys_audit_trail TO app_gl;
GRANT INSERT ON app_sys.sys_audit_trail TO app_pos;
GRANT INSERT ON app_sys.sys_audit_trail TO app_cash;
GRANT INSERT ON app_sys.sys_audit_trail TO app_doc;

GRANT SELECT ON app_sys.sys_role      TO app_sales;
GRANT SELECT ON app_sys.sys_user_role TO app_sales;
GRANT SELECT ON app_sys.sys_role      TO app_gl;
GRANT SELECT ON app_sys.sys_user_role TO app_gl;

PROMPT
PROMPT Collecte stats
BEGIN
  DBMS_STATS.GATHER_SCHEMA_STATS('APP_SYS', cascade => TRUE);
END;
/

PROMPT
PROMPT Validation - Tables
CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1
SELECT table_name, num_rows FROM user_tables
 WHERE table_name IN ('SYS_ROLE','SYS_USER_ROLE','SYS_PERMISSION',
                      'SYS_ROLE_PERMISSION','SYS_AUDIT_TRAIL')
 ORDER BY table_name;

PROMPT
PROMPT Validation - Objets invalides
SELECT object_name, object_type, status FROM user_objects WHERE status = 'INVALID';

PROMPT ==============================================================
PROMPT   LOT R13 TERMINE
PROMPT ==============================================================
EXIT;