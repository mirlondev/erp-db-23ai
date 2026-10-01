-- ============================================================
-- APEX SETUP 08 : Autorisations REGAL sur le modèle sécurité du script 29
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE

CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   APEX SETUP 08 — Authorizations REGAL
PROMPT ══════════════════════════════════════════════════════════

-- SYS_ROLE et SYS_USER_ROLE sont créées par scripts/29_lot_r13_security.sql.
MERGE INTO sys_role target
USING (
  SELECT 'REGAL_CAISSIER' role_code, 'Caissier POS' role_name, 1 role_level,
         'Sessions caisse, tickets, paiements cash/mobile' description FROM dual
  UNION ALL SELECT 'REGAL_VENDEUR', 'Vendeur boutique', 2,
         'Lecture stock et produits' FROM dual
  UNION ALL SELECT 'REGAL_MANAGER', 'Manager magasin', 3,
         'Transferts, achats et RH' FROM dual
  UNION ALL SELECT 'REGAL_COMPTABLE', 'Comptable', 4,
         'Comptabilité et déclarations fiscales' FROM dual
  UNION ALL SELECT 'REGAL_ADMIN', 'Administrateur système', 5,
         'Administration REGAL' FROM dual
  UNION ALL SELECT 'REGAL_SUPERADMIN', 'Super administrateur Oracle', 9,
         'Administration complète' FROM dual
) source
ON (target.role_code = source.role_code)
WHEN MATCHED THEN UPDATE SET
  role_name = source.role_name,
  role_level = source.role_level,
  description = source.description,
  is_active = TRUE
WHEN NOT MATCHED THEN INSERT (role_code, role_name, role_level, description)
  VALUES (source.role_code, source.role_name, source.role_level, source.description);

BEGIN
  EXECUTE IMMEDIATE 'CREATE TABLE apex_user_site_access (
    user_id NUMBER NOT NULL REFERENCES sys_user(user_id) ON DELETE CASCADE,
    site_code VARCHAR2(30) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    valid_from DATE DEFAULT SYSDATE NOT NULL,
    valid_to DATE,
    CONSTRAINT pk_apex_user_site_access PRIMARY KEY (user_id, site_code))';
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE != -955 THEN RAISE; END IF;
END;
/

MERGE INTO sys_user_role target
USING (
  SELECT u.user_id, seed.role_code
    FROM (
      SELECT 'ADMIN' user_code, 'REGAL_SUPERADMIN' role_code FROM dual
      UNION ALL SELECT 'CAISSIER_PNR', 'REGAL_CAISSIER' FROM dual
      UNION ALL SELECT 'MANAGER_PNR', 'REGAL_MANAGER' FROM dual
      UNION ALL SELECT 'COMPTABLE_BZV', 'REGAL_COMPTABLE' FROM dual
    ) seed
    JOIN sys_user u ON u.user_code = seed.user_code
) source
ON (target.user_id = source.user_id AND target.role_code = source.role_code)
WHEN MATCHED THEN UPDATE SET is_active = TRUE
WHEN NOT MATCHED THEN INSERT (user_id, role_code, assigned_by, is_active)
  VALUES (source.user_id, source.role_code, 'SYSTEM', TRUE);

MERGE INTO apex_user_site_access target
USING (
  SELECT u.user_id, seed.site_code
    FROM (
      SELECT 'CAISSIER_PNR' user_code, 'PNR-OFC' site_code FROM dual
      UNION ALL SELECT 'MANAGER_PNR', 'PNR-B01' FROM dual
    ) seed
    JOIN sys_user u ON u.user_code = seed.user_code
) source
ON (target.user_id = source.user_id AND target.site_code = source.site_code)
WHEN MATCHED THEN UPDATE SET is_active = TRUE
WHEN NOT MATCHED THEN INSERT (user_id, site_code, is_active)
  VALUES (source.user_id, source.site_code, TRUE);
COMMIT;

CREATE OR REPLACE PACKAGE pkg_apex_auth_v2 AS
  FUNCTION has_role(
    p_username VARCHAR2,
    p_role     VARCHAR2,
    p_site     VARCHAR2 DEFAULT NULL
  ) RETURN BOOLEAN;

  FUNCTION has_any_role(
    p_username VARCHAR2,
    p_roles    VARCHAR2,
    p_site     VARCHAR2 DEFAULT NULL
  ) RETURN BOOLEAN;

  FUNCTION user_sites(p_username VARCHAR2) RETURN VARCHAR2;
  FUNCTION user_role_codes(p_username VARCHAR2) RETURN VARCHAR2;
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
      JOIN sys_role r ON r.role_code = ur.role_code
     WHERE UPPER(u.user_code) = UPPER(p_username)
       AND u.is_active = TRUE
       AND ur.is_active = TRUE
       AND r.is_active = TRUE
       AND r.role_code = UPPER(p_role)
       AND (ur.valid_from IS NULL OR ur.valid_from <= SYSDATE)
       AND (ur.valid_to IS NULL OR ur.valid_to >= SYSDATE)
       AND (p_site IS NULL
            OR r.role_code IN ('REGAL_ADMIN', 'REGAL_SUPERADMIN')
            OR EXISTS (
                 SELECT 1
                   FROM apex_user_site_access usa
                  WHERE usa.user_id = u.user_id
                    AND usa.site_code = p_site
                    AND usa.is_active = TRUE
                    AND usa.valid_from <= SYSDATE
                    AND (usa.valid_to IS NULL OR usa.valid_to >= SYSDATE)));
    RETURN v_cnt > 0;
  END has_role;

  FUNCTION has_any_role(p_username VARCHAR2, p_roles VARCHAR2, p_site VARCHAR2 DEFAULT NULL)
    RETURN BOOLEAN IS
    v_ret BOOLEAN := FALSE;
  BEGIN
    FOR role_row IN (
      SELECT TRIM(REGEXP_SUBSTR(p_roles, '[^,]+', 1, LEVEL)) AS role_code
        FROM dual
      CONNECT BY LEVEL <= REGEXP_COUNT(p_roles, ',') + 1
    ) LOOP
      IF has_role(p_username, role_row.role_code, p_site) THEN
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
      FROM (
        SELECT DISTINCT usa.site_code
          FROM apex_user_site_access usa
          JOIN sys_user u ON u.user_id = usa.user_id
         WHERE UPPER(u.user_code) = UPPER(p_username)
           AND u.is_active = TRUE
           AND usa.is_active = TRUE
           AND usa.valid_from <= SYSDATE
           AND (usa.valid_to IS NULL OR usa.valid_to >= SYSDATE)
      );
    RETURN v_csv;
  END user_sites;

  FUNCTION user_role_codes(p_username VARCHAR2) RETURN VARCHAR2 IS
    v_csv VARCHAR2(4000);
  BEGIN
    SELECT LISTAGG(r.role_code, ',') WITHIN GROUP (ORDER BY r.role_code)
      INTO v_csv
      FROM sys_user_role ur
      JOIN sys_user u ON u.user_id = ur.user_id
      JOIN sys_role r ON r.role_code = ur.role_code
     WHERE UPPER(u.user_code) = UPPER(p_username)
       AND u.is_active = TRUE
       AND ur.is_active = TRUE
       AND r.is_active = TRUE
       AND (ur.valid_from IS NULL OR ur.valid_from <= SYSDATE)
       AND (ur.valid_to IS NULL OR ur.valid_to >= SYSDATE);
    RETURN v_csv;
  END user_role_codes;

  FUNCTION user_role_level(p_username VARCHAR2) RETURN NUMBER IS
    v_level NUMBER;
  BEGIN
    SELECT NVL(MAX(r.role_level), 0)
      INTO v_level
      FROM sys_user_role ur
      JOIN sys_user u ON u.user_id = ur.user_id
      JOIN sys_role r ON r.role_code = ur.role_code
     WHERE UPPER(u.user_code) = UPPER(p_username)
       AND u.is_active = TRUE
       AND ur.is_active = TRUE
       AND r.is_active = TRUE
       AND (ur.valid_from IS NULL OR ur.valid_from <= SYSDATE)
       AND (ur.valid_to IS NULL OR ur.valid_to >= SYSDATE);
    RETURN v_level;
  END user_role_level;

END pkg_apex_auth_v2;
/
SHOW ERRORS

DECLARE
  v_error_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_error_count
    FROM user_errors
   WHERE name = 'PKG_APEX_AUTH_V2'
     AND type IN ('PACKAGE', 'PACKAGE BODY');
  IF v_error_count > 0 THEN
    RAISE_APPLICATION_ERROR(-20003, 'PKG_APEX_AUTH_V2 contient des erreurs de compilation.');
  END IF;
END;
/

GRANT EXECUTE ON pkg_apex_auth_v2 TO app_api;

PROMPT
PROMPT APEX authorization function examples (one scheme per role):
PROMPT RETURN app_sys.pkg_apex_auth_v2.has_role(:APP_USER, 'REGAL_CAISSIER');
PROMPT Return FALSE for site-specific access unless a site is assigned.

SELECT role_code, role_name, role_level
  FROM sys_role
 WHERE is_active = TRUE
 ORDER BY role_level;

PROMPT APEX SETUP 08 terminé.
