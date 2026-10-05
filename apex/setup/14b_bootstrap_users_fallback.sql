-- ============================================================
-- APEX SETUP 14b : Bootstrap users (FALLBACK inlined hash)
-- ============================================================
-- À utiliser SI pkg_apex_auth.hash_pw n'est pas accessible
-- (par exemple si 03 n'a pas été rejoué après ajout dans la SPEC).
--
-- Ce script calcule le mot de passe EN LIGÉ via DBMS_CRYPTO,
-- sans dépendre de pkg_apex_auth.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF
WHENEVER SQLERROR CONTINUE

CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   APEX SETUP 14b — Bootstrap users (FALLBACK inline)
PROMPT ══════════════════════════════════════════════════════════

-- Vérifier DBMS_CRYPTO
DECLARE
  v_cnt NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_cnt FROM all_objects
   WHERE owner = 'SYS' AND object_name = 'DBMS_CRYPTO';
  IF v_cnt = 0 THEN
    DBMS_OUTPUT.PUT_LINE('  ⚠ DBMS_CRYPTO absent — GRANT EXECUTE requis');
    EXECUTE IMMEDIATE 'GRANT EXECUTE ON SYS.DBMS_CRYPTO TO app_sys';
  END IF;
END;
/

-- 1. Seed users (avec hash inline DBMS_CRYPTO)
PROMPT
PROMPT [1/3] Seed users REGAL (hash inlined)
MERGE INTO sys_user target
USING (
  SELECT 'ADMIN'           AS user_code, 'Administrateur REGAL'   AS user_name,
         'admin@litoko.cg' AS email, 'Admin#2026'                AS plain_pw FROM dual
  UNION ALL SELECT 'CAISSIER_PNR',  'Caissier Pointe-Noire',  'caissier.pnr@litoko.cg',  'CaissierPNR#2026'  FROM dual
  UNION ALL SELECT 'CAISSIER_BZV',  'Caissier Brazzaville',   'caissier.bzv@litoko.cg',  'CaissierBZV#2026'  FROM dual
  UNION ALL SELECT 'MANAGER_PNR',   'Manager Pointe-Noire',   'manager.pnr@litoko.cg',   'ManagerPNR#2026'   FROM dual
  UNION ALL SELECT 'COMPTABLE_BZV', 'Comptable Brazzaville',  'comptable.bzv@litoko.cg', 'ComptableBZV#2026' FROM dual
  UNION ALL SELECT 'COMPTABLE_PNR', 'Comptable Pointe-Noire', 'comptable.pnr@litoko.cg', 'ComptablePNR#2026' FROM dual
  UNION ALL SELECT 'VENDEUR_PNR',   'Vendeur Pointe-Noire',   'vendeur.pnr@litoko.cg',   'VendeurPNR#2026'   FROM dual
) source
ON (target.user_code = source.user_code)
WHEN MATCHED THEN UPDATE SET
  user_name   = source.user_name,
  email       = source.email,
  is_active   = TRUE,
  password_hash = LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(
                    UTL_RAW.CAST_TO_RAW(source.plain_pw), DBMS_CRYPTO.HASH_SH256))),
  password_changed_at = SYSDATE
WHEN NOT MATCHED THEN INSERT
  (user_code, user_name, is_active, email, password_hash, password_changed_at, language_code)
  VALUES
  (source.user_code, source.user_name, TRUE, source.email,
   LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(
            UTL_RAW.CAST_TO_RAW(source.plain_pw), DBMS_CRYPTO.HASH_SH256))),
   SYSDATE, 'fr');
COMMIT;

-- 2. Afficher les credentials
PROMPT
PROMPT [2/3] Credentials DEV
DECLARE
BEGIN
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE(RPAD('USER', 16) || RPAD('EMAIL', 30) || 'PASSWORD');
  DBMS_OUTPUT.PUT_LINE(RPAD('-', 60, '-'));
  FOR r IN (
    SELECT 'ADMIN'           AS user_code, 'admin@litoko.cg'      AS email, 'Admin#2026'          AS pw FROM dual
    UNION ALL SELECT 'CAISSIER_PNR',  'caissier.pnr@litoko.cg',  'CaissierPNR#2026'  FROM dual
    UNION ALL SELECT 'CAISSIER_BZV',  'caissier.bzv@litoko.cg',  'CaissierBZV#2026'  FROM dual
    UNION ALL SELECT 'MANAGER_PNR',   'manager.pnr@litoko.cg',   'ManagerPNR#2026'   FROM dual
    UNION ALL SELECT 'COMPTABLE_BZV', 'comptable.bzv@litoko.cg', 'ComptableBZV#2026' FROM dual
    UNION ALL SELECT 'COMPTABLE_PNR', 'comptable.pnr@litoko.cg', 'ComptablePNR#2026' FROM dual
    UNION ALL SELECT 'VENDEUR_PNR',   'vendeur.pnr@litoko.cg',   'VendeurPNR#2026'   FROM dual
  ) LOOP
    DBMS_OUTPUT.PUT_LINE(RPAD(r.user_code, 16) || RPAD(r.email, 30) || r.pw);
  END LOOP;
END;
/

-- 3. Test authenticate
PROMPT
PROMPT [3/3] Test authenticate
DECLARE
  v_pw VARCHAR2(50);
  v_ok BOOLEAN;
BEGIN
  -- En utilisant pkg_apex_auth.authenticate (l'API publique)
  v_ok := app_sys.pkg_apex_auth.authenticate('ADMIN', 'Admin#2026');
  DBMS_OUTPUT.PUT_LINE('  ADMIN            / Admin#2026          = ' || CASE WHEN v_ok THEN 'OK' ELSE 'KO' END);

  v_ok := app_sys.pkg_apex_auth.authenticate('CAISSIER_PNR', 'CaissierPNR#2026');
  DBMS_OUTPUT.PUT_LINE('  CAISSIER_PNR     / CaissierPNR#2026   = ' || CASE WHEN v_ok THEN 'OK' ELSE 'KO' END);

  v_ok := app_sys.pkg_apex_auth.authenticate('MANAGER_PNR', 'ManagerPNR#2026');
  DBMS_OUTPUT.PUT_LINE('  MANAGER_PNR      / ManagerPNR#2026     = ' || CASE WHEN v_ok THEN 'OK' ELSE 'KO' END);
END;
/

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ SETUP 14b terminé — fallback inlined
PROMPT ══════════════════════════════════════════════════════════
EXIT;