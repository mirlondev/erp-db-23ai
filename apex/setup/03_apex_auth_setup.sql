-- ============================================================
-- APEX SETUP 03 : Authentification APEX branchée sur app_sys.sys_user
-- ============================================================
-- Pattern "Custom Authorization" + fonction de validation mot de passe.
-- Les rôles APEX (REGAL_CAISSIER, REGAL_MAGASINIER, REGAL_COMPTABLE,
-- REGAL_ADMIN) sont dérivés de app_sys.sys_user_role (script 29).
-- À jouer en SYS AS SYSDBA : accorde DBMS_CRYPTO, puis compile en APP_SYS.
-- Les mots de passe sont hachés en SHA-256, comme le seed existant.
-- Idempotent.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE

-- DBMS_CRYPTO requis pour le hachage SHA-256 des mots de passe
GRANT EXECUTE ON SYS.DBMS_CRYPTO TO app_sys;

CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT APEX SETUP 03 — Package d'auth REGAL pour APEX 26.1
PROMPT ══════════════════════════════════════════════════════════

CREATE OR REPLACE PACKAGE pkg_apex_auth AS
  -- Validation login/mot de passe pour APEX Authentication Scheme "PL/SQL"
  FUNCTION authenticate(
    p_username IN VARCHAR2,
    p_password IN VARCHAR2
  ) RETURN BOOLEAN;

  -- Hash SHA-256 hex du mot de passe (EXPOSÉ pour bootstrap)
  -- ⚠️ Appelé depuis apex/setup/14_bootstrap_users.sql
  --   pour poser sys_user.password_hash à partir d'un mot de passe en clair.
  FUNCTION hash_pw(p_plain IN VARCHAR2) RETURN VARCHAR2;

  -- Rôles actifs d'un utilisateur (liste CSV pour APEX "Is In Role/Group")
  FUNCTION user_roles(p_username IN VARCHAR2) RETURN VARCHAR2;

  -- Droits par site/dépôt (hub-spoke) : filtre les vues APEX
  FUNCTION user_site_codes(p_username IN VARCHAR2) RETURN VARCHAR2;

  -- Audit de session (alimente sys_audit_trail)
  PROCEDURE log_login(p_username IN VARCHAR2, p_success IN BOOLEAN);
END pkg_apex_auth;
/

CREATE OR REPLACE PACKAGE BODY pkg_apex_auth AS

  FUNCTION hash_pw(p_plain IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    -- Stockage existant : SHA-256 hex (compatible seed script 01)
    RETURN LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(
             UTL_RAW.CAST_TO_RAW(p_plain), DBMS_CRYPTO.HASH_SH256)));
  END hash_pw;

  FUNCTION authenticate(p_username VARCHAR2, p_password VARCHAR2) RETURN BOOLEAN IS
    v_cnt          NUMBER;
    v_password_hash VARCHAR2(64);
  BEGIN
    v_password_hash := hash_pw(p_password);
    SELECT COUNT(*) INTO v_cnt
      FROM sys_user u
     WHERE UPPER(u.user_code) = UPPER(p_username)
       AND u.is_active = TRUE
       AND u.password_hash = v_password_hash;
    log_login(p_username, v_cnt > 0);
    RETURN v_cnt > 0;
  EXCEPTION WHEN OTHERS THEN
    log_login(p_username, FALSE);
    RETURN FALSE;
  END authenticate;

  FUNCTION user_roles(p_username VARCHAR2) RETURN VARCHAR2 IS
    v_list VARCHAR2(4000);
  BEGIN
    SELECT LISTAGG(r.role_code, ',') WITHIN GROUP (ORDER BY r.role_code)
      INTO v_list
      FROM sys_user_role ur
      JOIN sys_user u ON u.user_id = ur.user_id
      JOIN sys_role r ON r.role_code = ur.role_code
     WHERE UPPER(u.user_code) = UPPER(p_username)
       AND ur.is_active = TRUE
       AND r.is_active = TRUE
       AND NVL(ur.valid_from, SYSDATE) <= SYSDATE
       AND NVL(ur.valid_to, SYSDATE+1) >= SYSDATE;
    RETURN v_list;
  END user_roles;

  FUNCTION user_site_codes(p_username VARCHAR2) RETURN VARCHAR2 IS
    v_list VARCHAR2(4000);
  BEGIN
    -- Rattache via sys_user_access (script 01) : clé d'accès = dépôt du caissier.
    SELECT LISTAGG(DISTINCT ak.access_key_code, ',') WITHIN GROUP (ORDER BY ak.access_key_code)
      INTO v_list
      FROM sys_user_access ua
      JOIN sys_access_key ak ON ak.access_key_id = ua.access_key_id
      JOIN sys_user u        ON u.user_id = ua.user_id
     WHERE UPPER(u.user_code) = UPPER(p_username)
       AND ua.is_active = TRUE;
    RETURN v_list;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    RETURN NULL; -- pas de restriction = tous sites (admin)
  END user_site_codes;

  PROCEDURE log_login(p_username VARCHAR2, p_success BOOLEAN) IS
  BEGIN
    INSERT INTO sys_audit_trail(user_code, action_type, entity_type, severity)
    VALUES (UPPER(p_username),
            'LOGIN',
            'APEX_SESSION',
            CASE WHEN p_success THEN 'INFO' ELSE 'WARN' END);
    COMMIT;
  EXCEPTION WHEN OTHERS THEN NULL; -- l'audit ne doit jamais bloquer un login
  END log_login;

END pkg_apex_auth;
/
SHOW ERRORS

DECLARE
  v_error_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_error_count
    FROM user_errors
   WHERE name = 'PKG_APEX_AUTH'
     AND type = 'PACKAGE BODY';
  IF v_error_count > 0 THEN
    RAISE_APPLICATION_ERROR(-20002, 'PKG_APEX_AUTH contient des erreurs de compilation.');
  END IF;
END;
/

-- Grants vers le schéma workspace APEX
GRANT EXECUTE ON pkg_apex_auth TO app_api;

PROMPT
PROMPT ── Câblage dans l'IDE APEX (à faire une fois, workspace REGAL) ──
PROMPT 1. Shared Components → Authentication Schemes → Create
PROMPT    Type: "PL/SQL function returning boolean"
PROMPT    Code: RETURN app_sys.pkg_apex_auth.authenticate(:P0_USERNAME, :P0_PASSWORD);
PROMPT 2. Authorizations → Create → Type "Exists"
PROMPT    SQL: SELECT 1 FROM dual WHERE ','||app_sys.pkg_apex_auth.user_roles(
PROMPT              :APP_USER)||',' LIKE '%,'||<ROLE_CODE>||',%'
PROMPT    Rôles: REGAL_ADMIN / REGAL_COMPTABLE / REGAL_MAGASINIER / REGAL_CAISSIER
PROMPT 3. Par page POS : Server-side condition sur user_site_codes(:APP_USER)
PROMPT    pour restreindre aux sites autorisés (hub-spoke).
PROMPT
PROMPT ✅ Package pkg_apex_auth créé.
