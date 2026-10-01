-- ============================================================
-- APEX SETUP 08 : Schémas d'autorisation REGAL (5 rôles)
-- ============================================================
-- Crée 5 schémas d'autorisation APEX liés à app_sys.sys_user_role :
--
--   REGAL_CAISSIER    : ventes, sessions POS, paiements
--   REGAL_VENDEUR     : + stocks, produits (lecture seule prix)
--   REGAL_MANAGER     : + transferts, achats, RH
--   REGAL_COMPTABLE   : + écritures GL, fiscal, déclarations
--   REGAL_ADMIN       : full access, config, BRANDS, USERS
--
-- Chaque schéma APEX utilise un appel à app_sys.fn_apex_has_role()
-- qui vérifie les rôles dans sys_user_role.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF
WHENEVER SQLERROR CONTINUE

CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   APEX SETUP 08 — Authorizations REGAL
PROMPT ══════════════════════════════════════════════════════════

-- ============================================================
-- 1) Tables roles & user_roles
-- ============================================================
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE sys_user_role CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE sys_role (
  role_id         NUMBER GENERATED ALWAYS AS IDENTITY,
  role_code       VARCHAR2(30)  NOT NULL,
  role_name       VARCHAR2(120) NOT NULL,
  role_level      NUMBER(2)     NOT NULL,   -- 1=bas, 5=haut
  description     VARCHAR2(500),
  is_active       BOOLEAN       DEFAULT TRUE,
  created_at      TIMESTAMP     DEFAULT SYSTIMESTAMP,
  CONSTRAINT pk_sys_role PRIMARY KEY (role_id),
  CONSTRAINT uk_sys_role UNIQUE (role_code)
);

CREATE TABLE sys_user_role (
  user_role_id    NUMBER GENERATED ALWAYS AS IDENTITY,
  user_id         NUMBER        NOT NULL,
  role_id         NUMBER        NOT NULL,
  site_code       VARCHAR2(10),             -- null = tous sites
  valid_from      DATE          DEFAULT SYSDATE,
  valid_to        DATE,
  granted_by      VARCHAR2(20),
  granted_at      TIMESTAMP     DEFAULT SYSTIMESTAMP,
  CONSTRAINT pk_sys_user_role PRIMARY KEY (user_role_id),
  CONSTRAINT uk_sys_user_role UNIQUE (user_id, role_id, site_code)
);

ALTER TABLE sys_user_role
  ADD CONSTRAINT fk_user_role_user FOREIGN KEY (user_id) REFERENCES sys_user(user_id) ON DELETE CASCADE,
  ADD CONSTRAINT fk_user_role_role FOREIGN KEY (role_id) REFERENCES sys_role(role_id);

-- ============================================================
-- 2) Seed 5 rôles REGAL
-- ============================================================
PROMPT
PROMPT [1] 5 rôles REGAL
INSERT INTO sys_role (role_code, role_name, role_level, description) VALUES
  ('REGAL_CAISSIER',  'Caissier POS',                1, 'Sessions caisse, tickets, paiements cash/mobile');
INSERT INTO sys_role (role_code, role_name, role_level, description) VALUES
  ('REGAL_VENDEUR',   'Vendeur boutique',            2, 'Lecture stock, produits, prix. Pas d''écritures comptables');
INSERT INTO sys_role (role_code, role_name, role_level, description) VALUES
  ('REGAL_MANAGER',   'Manager magasin',             3, 'Transferts, achats, RH, clôtures sessions');
INSERT INTO sys_role (role_code, role_name, role_level, description) VALUES
  ('REGAL_COMPTABLE', 'Comptable',                   4, 'Écritures GL, fiscal CG, déclarations TVA/IS, immobilisations');
INSERT INTO sys_role (role_code, role_name, role_level, description) VALUES
  ('REGAL_ADMIN',     'Administrateur système',      5, 'Full access : config, BRANDS, USERS, ROLES, paramètres');

-- Admin de l'app (superadmin pour DEV/test)
INSERT INTO sys_role (role_code, role_name, role_level, description) VALUES
  ('REGAL_SUPERADMIN', 'Super administrateur Oracle', 9, 'SYS/DBA — tous droits sur tous les schémas');
COMMIT;

-- ============================================================
-- 3) Seed affectations users (démo)
-- ============================================================
PROMPT
PROMPT [2] Affectations users (démo)
INSERT INTO sys_user_role (user_id, role_id, granted_by)
SELECT u.user_id, r.role_id, 'SYSTEM'
  FROM sys_user u, sys_role r
 WHERE u.user_code = 'ADMIN' AND r.role_code = 'REGAL_SUPERADMIN';

INSERT INTO sys_user_role (user_id, role_id, granted_by)
SELECT u.user_id, r.role_id, 'SYSTEM'
  FROM sys_user u, sys_role r
 WHERE u.user_code = 'CAISSIER_PNR' AND r.role_code = 'REGAL_CAISSIER';

INSERT INTO sys_user_role (user_id, role_id, site_code, granted_by)
SELECT u.user_id, r.role_id, 'PNR-B01', 'SYSTEM'
  FROM sys_user u, sys_role r
 WHERE u.user_code = 'MANAGER_PNR' AND r.role_code = 'REGAL_MANAGER';

INSERT INTO sys_user_role (user_id, role_id, granted_by)
SELECT u.user_id, r.role_id, 'SYSTEM'
  FROM sys_user u, sys_role r
 WHERE u.user_code = 'COMPTABLE_BZV' AND r.role_code = 'REGAL_COMPTABLE';
COMMIT;

-- ============================================================
-- 4) Package fn_apex_has_role
-- ============================================================
PROMPT
PROMPT [3] Package fn_apex_has_role
CREATE OR REPLACE PACKAGE pkg_apex_auth_v2 AS
  -- Vérifie qu'un user APEX a un rôle donné
  FUNCTION has_role(
    p_username VARCHAR2,
    p_role     VARCHAR2,
    p_site     VARCHAR2 DEFAULT NULL
  ) RETURN BOOLEAN;

  -- Vérifie qu'un user a au moins un des rôles
  FUNCTION has_any_role(
    p_username VARCHAR2,
    p_roles    VARCHAR2,  -- CSV 'CAISSIER,VENDEUR'
    p_site     VARCHAR2 DEFAULT NULL
  ) RETURN BOOLEAN;

  -- Liste les sites accessibles
  FUNCTION user_sites(p_username VARCHAR2) RETURN VARCHAR2;  -- CSV
  FUNCTION user_role_codes(p_username VARCHAR2) RETURN VARCHAR2;  -- CSV
  FUNCTION user_role_level(p_username VARCHAR2) RETURN NUMBER;
END pkg_apex_auth_v2;
/

CREATE OR REPLACE PACKAGE BODY pkg_apex_auth_v2 AS

  FUNCTION has_role(p_username VARCHAR2, p_role VARCHAR2, p_site VARCHAR2 DEFAULT NULL)
    RETURN BOOLEAN IS
    v_cnt NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_cnt
      FROM sys_user_role ur
      JOIN sys_user u ON u.user_id = ur.user_id
      JOIN sys_role r ON r.role_id = ur.role_id
     WHERE u.user_code = UPPER(p_username)
       AND u.is_active = 'Y'
       AND r.role_code = UPPER(p_role)
       AND r.is_active = 'Y'
       AND (ur.valid_from IS NULL OR ur.valid_from <= SYSDATE)
       AND (ur.valid_to   IS NULL OR ur.valid_to   >= SYSDATE)
       AND (ur.site_code IS NULL OR ur.site_code = p_site OR p_site IS NULL);
    RETURN v_cnt > 0;
  END has_role;

  FUNCTION has_any_role(p_username VARCHAR2, p_roles VARCHAR2, p_site VARCHAR2 DEFAULT NULL)
    RETURN BOOLEAN IS
    v_ret BOOLEAN := FALSE;
  BEGIN
    FOR r IN (SELECT TRIM(REGEXP_SUBSTR(p_roles, '[^,]+', 1, LEVEL)) AS role_code
                FROM DUAL
             CONNECT BY LEVEL <= REGEXP_COUNT(p_roles, ',') + 1) LOOP
      IF has_role(p_username, r.role_code, p_site) THEN
        v_ret := TRUE;
        EXIT;
      END IF;
    END LOOP;
    RETURN v_ret;
  END has_any_role;

  FUNCTION user_sites(p_username VARCHAR2) RETURN VARCHAR2 IS
    v_csv VARCHAR2(4000);
  BEGIN
    SELECT LISTAGG(site_code, ',') WITHIN GROUP (ORDER BY site_code)
      INTO v_csv
      FROM (SELECT DISTINCT ur.site_code
              FROM sys_user_role ur
              JOIN sys_user u ON u.user_id = ur.user_id
             WHERE u.user_code = UPPER(p_username)
               AND ur.site_code IS NOT NULL);
    RETURN v_csv;
  END user_sites;

  FUNCTION user_role_codes(p_username VARCHAR2) RETURN VARCHAR2 IS
    v_csv VARCHAR2(4000);
  BEGIN
    SELECT LISTAGG(r.role_code, ',') WITHIN GROUP (ORDER BY r.role_code)
      INTO v_csv
      FROM sys_user_role ur
      JOIN sys_user u ON u.user_id = ur.user_id
      JOIN sys_role r ON r.role_id = ur.role_id
     WHERE u.user_code = UPPER(p_username)
       AND r.is_active = 'Y';
    RETURN v_csv;
  END user_role_codes;

  FUNCTION user_role_level(p_username VARCHAR2) RETURN NUMBER IS
    v_max NUMBER := 0;
  BEGIN
    SELECT MAX(r.role_level)
      INTO v_max
      FROM sys_user_role ur
      JOIN sys_user u ON u.user_id = ur.user_id
      JOIN sys_role r ON r.role_id = ur.role_id
     WHERE u.user_code = UPPER(p_username)
       AND r.is_active = 'Y';
    RETURN v_max;
  END user_role_level;

END pkg_apex_auth_v2;
/
GRANT EXECUTE ON pkg_apex_auth_v2 TO app_api;
PROMPT ✓ pkg_apex_auth_v2 créé.

-- ============================================================
-- 5) Génération du script APEX 26.1 pour les authorizations
-- ============================================================
PROMPT
PROMPT [4] Génération script d'enregistrement APEX
SET LINESIZE 300
SET LONG 10000
SET LONGCHUNKSIZE 2000

DECLARE
  v_lines CLOB;
BEGIN
  v_lines := v_lines || '-- ═══ A exécuter en tant qu''ADMIN APEX dans le workspace REGAL ═══' || CHR(10);
  v_lines := v_lines || '-- (Shared Components → Authorization Schemes → Create)' || CHR(10) || CHR(10);

  FOR r IN (
    SELECT role_code, role_name, role_level
      FROM sys_role WHERE is_active = 'Y' ORDER BY role_level
  ) LOOP
    v_lines := v_lines ||
      '-- ▸ Authorization Scheme: ' || r.role_name || CHR(10) ||
      'BEGIN' || CHR(10) ||
      '  APEX_ACL.REMOVE_USER_ROLE(p_application_id => 100, p_user_name => :APP_USER, p_role_static_id => ''' || r.role_code || ''');' || CHR(10) ||
      '  APEX_ACL.GRANT_USER_ROLE(p_application_id => 100, p_user_name => :APP_USER, p_role_static_id => ''' || r.role_code || ''');' || CHR(10) ||
      'END;' || CHR(10) ||
      '/' || CHR(10) || CHR(10);
  END LOOP;

  v_lines := v_lines || '-- PL/SQL Function Body returning BOOLEAN (pour Authorization Scheme PL/SQL):' || CHR(10) ||
    'RETURN app_sys.pkg_apex_auth_v2.has_role(:APP_USER, ''REGAL_CAISSIER'');' || CHR(10);
END;
/

PROMPT
PROMPT ═══ Validation ═══
SELECT role_code, role_name, role_level FROM sys_role ORDER BY role_level;

PROMPT
PROMPT ═══ Tests ═══

PROMPT [T1] ADMIN → SUPERADMIN ?
DECLARE
  v_has BOOLEAN;
BEGIN
  v_has := pkg_apex_auth_v2.has_role('ADMIN', 'REGAL_SUPERADMIN');
  DBMS_OUTPUT.PUT_LINE('  ADMIN REGAL_SUPERADMIN = ' || CASE WHEN v_has THEN 'TRUE' ELSE 'FALSE' END);
END;
/

PROMPT [T2] CAISSIER_PNR → CAISSIER ?
DECLARE
  v_has BOOLEAN;
BEGIN
  v_has := pkg_apex_auth_v2.has_role('CAISSIER_PNR', 'REGAL_CAISSIER', 'PNR-OFC');
  DBMS_OUTPUT.PUT_LINE('  CAISSIER_PNR REGAL_CAISSIER @ PNR-OFC = ' || CASE WHEN v_has THEN 'TRUE' ELSE 'FALSE' END);
END;
/

PROMPT [T3] MANAGER_PNR → sites accessibles
DECLARE
  v_sites VARCHAR2(4000);
BEGIN
  v_sites := pkg_apex_auth_v2.user_sites('MANAGER_PNR');
  DBMS_OUTPUT.PUT_LINE('  MANAGER_PNR sites = ' || NVL(v_sites, '(aucun)'));
END;
/

PROMPT [T4] has_any_role (multi-roles)
DECLARE
  v_has BOOLEAN;
BEGIN
  v_has := pkg_apex_auth_v2.has_any_role('COMPTABLE_BZV', 'REGAL_MANAGER,REGAL_COMPTABLE');
  DBMS_OUTPUT.PUT_LINE('  COMPTABLE_BZV has MANAGER ou COMPTABLE = ' || CASE WHEN v_has THEN 'TRUE' ELSE 'FALSE' END);
END;
/

PROMPT [T5] Volumétrie users / roles
SELECT 'users' AS type, COUNT(*) AS nb FROM sys_user
UNION ALL SELECT 'rôles',     COUNT(*) FROM sys_role
UNION ALL SELECT 'affectations', COUNT(*) FROM sys_user_role;

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ APEX SETUP 08 — 6 rôles + 4 affectations + pkg
PROMPT   - REGAL_CAISSIER, REGAL_VENDEUR, REGAL_MANAGER
PROMPT   - REGAL_COMPTABLE, REGAL_ADMIN, REGAL_SUPERADMIN
PROMPT   - pkg_apex_auth_v2.has_role, user_sites, etc.
PROMPT ══════════════════════════════════════════════════════════
EXIT;
