-- ============================================================
-- APEX SETUP 08 : Seed rôles REGAL (sans pkg_apex_auth_v2 inventé)
-- ============================================================
-- ⚠️ FIX 2026-10-03 : supprime pkg_apex_auth_v2.has_role/has_any_role
-- (INVENTÉ — n'existe pas dans la base). On utilise UNIQUEMENT
-- les fonctions qui existent dans pkg_apex_auth :
--   - authenticate(p_username, p_password) RETURN BOOLEAN
--   - user_roles(p_username)               RETURN VARCHAR2 (CSV)
--   - user_site_codes(p_username)          RETURN VARCHAR2 (CSV)
--   - log_login(p_username, p_success)
--   - hash_pw(p_plain)                     RETURN VARCHAR2
--
-- Schéma R13 :
--   sys_role(role_code, role_name, role_level, description, is_active, ...)
--   sys_user_role(user_id, role_code, is_active, valid_from, valid_to, ...)
--   sys_role_permission(role_code, permission_code, ...)
--
-- Ce script seed UNIQUEMENT les rôles REGAL_* dans sys_role
-- et les affectations user→role dans sys_user_role.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE

CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   APEX SETUP 08 — Seed rôles REGAL
PROMPT ══════════════════════════════════════════════════════════

-- Prérequis : R13 doit avoir créé sys_role et sys_user_role
DECLARE
  v_cnt NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_cnt FROM all_tables
   WHERE owner = 'APP_SYS' AND table_name = 'SYS_ROLE';
  IF v_cnt = 0 THEN
    DBMS_OUTPUT.PUT_LINE('⚠ Table SYS_ROLE absente — exécuter scripts/29_lot_r13_security.sql avant.');
  END IF;

  SELECT COUNT(*) INTO v_cnt FROM all_tables
   WHERE owner = 'APP_SYS' AND table_name = 'SYS_USER_ROLE';
  IF v_cnt = 0 THEN
    DBMS_OUTPUT.PUT_LINE('⚠ Table SYS_USER_ROLE absente — exécuter scripts/29_lot_r13_security.sql avant.');
  END IF;
END;
/

-- 1. Seed des rôles REGAL dans sys_role (idempotent)
PROMPT
PROMPT [1/3] MERGE INTO sys_role (rôles REGAL)
MERGE INTO sys_role target
USING (
  SELECT 'REGAL_CAISSIER'    AS role_code, 'Caissier POS'                 AS role_name,
         1                   AS role_level,
         'Sessions caisse, tickets, paiements cash/mobile' AS description
    FROM dual
  UNION ALL SELECT 'REGAL_VENDEUR',     'Vendeur boutique',        2, 'Lecture stock, produits'         FROM dual
  UNION ALL SELECT 'REGAL_MANAGER',     'Manager magasin',         3, 'Transferts, achats et RH'         FROM dual
  UNION ALL SELECT 'REGAL_COMPTABLE',   'Comptable',               4, 'Comptabilité, fiscal, immo'      FROM dual
  UNION ALL SELECT 'REGAL_ADMIN',       'Administrateur REGAL',    5, 'Administration REGAL'             FROM dual
  UNION ALL SELECT 'REGAL_SUPERADMIN',  'Super Admin Oracle',      9, 'Tous droits (SYS, DBA, superuser)' FROM dual
) source
ON (target.role_code = source.role_code)
WHEN MATCHED THEN UPDATE SET
  role_name   = source.role_name,
  role_level  = source.role_level,
  description = source.description,
  is_active   = TRUE
WHEN NOT MATCHED THEN INSERT (role_code, role_name, role_level, description, is_active)
  VALUES (source.role_code, source.role_name, source.role_level, source.description, TRUE);

-- 2. Affectations user → role (idempotent)
PROMPT
PROMPT [2/3] MERGE INTO sys_user_role
MERGE INTO sys_user_role target
USING (
  SELECT u.user_id, seed.role_code
    FROM (
      SELECT 'ADMIN'           AS user_code, 'REGAL_SUPERADMIN' AS role_code FROM dual
      UNION ALL SELECT 'ADMIN', 'REGAL_ADMIN'       FROM dual
      UNION ALL SELECT 'CAISSIER_PNR', 'REGAL_CAISSIER' FROM dual
      UNION ALL SELECT 'CAISSIER_BZV', 'REGAL_CAISSIER' FROM dual
      UNION ALL SELECT 'MANAGER_PNR',  'REGAL_MANAGER'  FROM dual
      UNION ALL SELECT 'COMPTABLE_BZV','REGAL_COMPTABLE'FROM dual
      UNION ALL SELECT 'COMPTABLE_PNR','REGAL_COMPTABLE'FROM dual
      UNION ALL SELECT 'VENDEUR_PNR',  'REGAL_VENDEUR'  FROM dual
    ) seed
    JOIN sys_user u ON u.user_code = seed.user_code
) source
ON (target.user_id = source.user_id AND target.role_code = source.role_code)
WHEN MATCHED THEN UPDATE SET is_active = TRUE
WHEN NOT MATCHED THEN INSERT (user_id, role_code, assigned_by, is_active)
  VALUES (source.user_id, source.role_code, 'SYSTEM', TRUE);
COMMIT;

-- 3. Helper VIEW : roles + level pour APEX (utilise UNIQUEMENT pkg_apex_auth.user_roles)
PROMPT
PROMPT [3/3] Vue helper regal_auth_user_roles
CREATE OR REPLACE VIEW regal_auth_user_roles_v AS
SELECT u.user_code,
       u.user_name,
       u.is_active,
       app_sys.pkg_apex_auth.user_roles(u.user_code) AS role_codes,
       app_sys.pkg_apex_auth.user_site_codes(u.user_code) AS site_codes
  FROM sys_user u;

GRANT SELECT ON regal_auth_user_roles_v TO app_api;

-- Vérification
PROMPT
PROMPT ═══ Validation ═══
SELECT role_code, role_name, role_level, is_active
  FROM sys_role
 WHERE role_code LIKE 'REGAL_%'
 ORDER BY role_level;

PROMPT
SELECT user_code, is_active, password_hash IS NOT NULL AS a_password
  FROM sys_user
 WHERE user_code IN ('ADMIN','CAISSIER_PNR','MANAGER_PNR','COMPTABLE_BZV','VENDEUR_PNR')
 ORDER BY user_code;

PROMPT
SELECT u.user_code, ur.role_code, ur.is_active
  FROM sys_user u
  JOIN sys_user_role ur ON ur.user_id = u.user_id
 WHERE ur.role_code LIKE 'REGAL_%'
 ORDER BY u.user_code, ur.role_code;

PROMPT
PROMPT ═══ Test fonction user_roles() ═══
DECLARE
  v_roles VARCHAR2(4000);
  v_sites VARCHAR2(4000);
BEGIN
  v_roles := app_sys.pkg_apex_auth.user_roles('ADMIN');
  v_sites := app_sys.pkg_apex_auth.user_site_codes('ADMIN');
  DBMS_OUTPUT.PUT_LINE('  ADMIN    roles=' || NVL(v_roles, 'NULL') || ' sites=' || NVL(v_sites, 'NULL'));

  v_roles := app_sys.pkg_apex_auth.user_roles('CAISSIER_PNR');
  DBMS_OUTPUT.PUT_LINE('  CAISSIER_PNR  roles=' || NVL(v_roles, 'NULL'));

  v_roles := app_sys.pkg_apex_auth.user_roles('COMPTABLE_BZV');
  DBMS_OUTPUT.PUT_LINE('  COMPTABLE_BZV roles=' || NVL(v_roles, 'NULL'));
END;
/

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ SETUP 08 terminé
PROMPT   - 6 rôles REGAL_* dans sys_role
PROMPT   - 8 affectations user→role
PROMPT   - Vue regal_auth_user_roles_v (pour debug)
PROMPT   - AUCUN pkg_apex_auth_v2 inventé
PROMPT   - Authentification via pkg_apex_auth.authenticate() (réel)
PROMPT ══════════════════════════════════════════════════════════
EXIT;