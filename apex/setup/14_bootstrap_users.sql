-- ============================================================
-- APEX SETUP 14 : Bootstrap users + passwords pour REGAL
-- ============================================================
-- ⚠️ RÈGLE D'OR : on utilise UNIQUEMENT les fonctions qui existent :
--   - app_sys.pkg_apex_auth.hash_pw(p_plain)  ← créé par 03
--   - app_sys.pkg_apex_auth.authenticate()    ← créé par 03
--
-- Ce script :
--   1. Crée les users REGAL manquants (idempotent)
--   2. Pose les mots de passe via hash_pw() (SHA-256 hex)
--   3. Vérifie chaque user peut être authentifié
--   4. Affiche les credentials en clair (DEV ONLY)
--
-- ⚠️ DEV ONLY : en production, le sys_user.password_hash doit être
--    posé via une procédure sécurisée (pas en clair dans un script)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE

CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   APEX SETUP 14 — Bootstrap users + passwords
PROMPT ══════════════════════════════════════════════════════════

-- 1. Liste des users REGAL avec mots de passe par défaut (DEV)
PROMPT
PROMPT [1/4] Seed users REGAL avec mots de passe
MERGE INTO sys_user target
USING (
  SELECT 'ADMIN'           AS user_code, 'Administrateur REGAL'   AS user_name, 'admin@litoko.cg'      AS email, 'Admin#2026'          AS plain_pw FROM dual
  UNION ALL SELECT 'CAISSIER_PNR',  'Caissier Pointe-Noire',   'caissier.pnr@litoko.cg',  'CaissierPNR#2026'  FROM dual
  UNION ALL SELECT 'CAISSIER_BZV',  'Caissier Brazzaville',    'caissier.bzv@litoko.cg',  'CaissierBZV#2026'  FROM dual
  UNION ALL SELECT 'MANAGER_PNR',   'Manager Pointe-Noire',    'manager.pnr@litoko.cg',   'ManagerPNR#2026'   FROM dual
  UNION ALL SELECT 'COMPTABLE_BZV', 'Comptable Brazzaville',   'comptable.bzv@litoko.cg', 'ComptableBZV#2026' FROM dual
  UNION ALL SELECT 'COMPTABLE_PNR', 'Comptable Pointe-Noire',  'comptable.pnr@litoko.cg', 'ComptablePNR#2026' FROM dual
  UNION ALL SELECT 'VENDEUR_PNR',   'Vendeur Pointe-Noire',    'vendeur.pnr@litoko.cg',   'VendeurPNR#2026'   FROM dual
) source
ON (target.user_code = source.user_code)
WHEN MATCHED THEN UPDATE SET
  user_name   = source.user_name,
  email       = source.email,
  is_active   = TRUE,
  password_hash = app_sys.pkg_apex_auth.hash_pw(source.plain_pw),
  password_changed_at = SYSDATE
WHEN NOT MATCHED THEN INSERT
  (user_code, user_name, is_active, email, password_hash, password_changed_at, language_code)
  VALUES
  (source.user_code, source.user_name, TRUE, source.email,
   app_sys.pkg_apex_auth.hash_pw(source.plain_pw),
   SYSDATE, 'fr');
COMMIT;

-- 2. Afficher les credentials (DEV ONLY)
PROMPT
PROMPT [2/4] Credentials (DEV ONLY — À CHANGER EN PROD)
DECLARE
  v_pw  VARCHAR2(50);
  v_pwd VARCHAR2(100);
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
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-- 3. Test de chaque user (vérifie que authenticate() fonctionne)
PROMPT
PROMPT [3/4] Test authenticate() pour chaque user
DECLARE
  v_pw VARCHAR2(50);
  v_ok BOOLEAN;
BEGIN
  v_pw := 'Admin#2026';
  v_ok := app_sys.pkg_apex_auth.authenticate('ADMIN', v_pw);
  DBMS_OUTPUT.PUT_LINE('  ADMIN            / Admin#2026          = ' || CASE WHEN v_ok THEN '✓ OK' ELSE '✗ KO' END);

  v_pw := 'CaissierPNR#2026';
  v_ok := app_sys.pkg_apex_auth.authenticate('CAISSIER_PNR', v_pw);
  DBMS_OUTPUT.PUT_LINE('  CAISSIER_PNR     / CaissierPNR#2026   = ' || CASE WHEN v_ok THEN '✓ OK' ELSE '✗ KO' END);

  v_pw := 'CaissierBZV#2026';
  v_ok := app_sys.pkg_apex_auth.authenticate('CAISSIER_BZV', v_pw);
  DBMS_OUTPUT.PUT_LINE('  CAISSIER_BZV     / CaissierBZV#2026   = ' || CASE WHEN v_ok THEN '✓ OK' ELSE '✗ KO' END);

  v_pw := 'ManagerPNR#2026';
  v_ok := app_sys.pkg_apex_auth.authenticate('MANAGER_PNR', v_pw);
  DBMS_OUTPUT.PUT_LINE('  MANAGER_PNR      / ManagerPNR#2026     = ' || CASE WHEN v_ok THEN '✓ OK' ELSE '✗ KO' END);

  v_pw := 'ComptableBZV#2026';
  v_ok := app_sys.pkg_apex_auth.authenticate('COMPTABLE_BZV', v_pw);
  DBMS_OUTPUT.PUT_LINE('  COMPTABLE_BZV    / ComptableBZV#2026   = ' || CASE WHEN v_ok THEN '✓ OK' ELSE '✗ KO' END);

  v_pw := 'ComptablePNR#2026';
  v_ok := app_sys.pkg_apex_auth.authenticate('COMPTABLE_PNR', v_pw);
  DBMS_OUTPUT.PUT_LINE('  COMPTABLE_PNR    / ComptablePNR#2026   = ' || CASE WHEN v_ok THEN '✓ OK' ELSE '✗ KO' END);

  v_pw := 'VendeurPNR#2026';
  v_ok := app_sys.pkg_apex_auth.authenticate('VENDEUR_PNR', v_pw);
  DBMS_OUTPUT.PUT_LINE('  VENDEUR_PNR      / VendeurPNR#2026     = ' || CASE WHEN v_ok THEN '✓ OK' ELSE '✗ KO' END);
END;
/

-- 4. Vérification finale
PROMPT
PROMPT [4/4] État final des users
SELECT user_code,
       user_name,
       email,
       language_code,
       is_active,
       password_hash IS NOT NULL AS a_password,
       TO_CHAR(password_changed_at, 'DD/MM/YYYY HH24:MI') AS pw_changed
  FROM sys_user
 WHERE user_code IN ('ADMIN','CAISSIER_PNR','CAISSIER_BZV','MANAGER_PNR',
                      'COMPTABLE_BZV','COMPTABLE_PNR','VENDEUR_PNR')
 ORDER BY user_code;

PROMPT
PROMPT ═══ Pour se connecter ═══
PROMPT
PROMPT   1. Ouvre l'app REGAL POS (http://localhost:8080/apex/f?p=100:9999)
PROMPT   2. Login : ADMIN    / Admin#2026         (superadmin)
PROMPT   3. Login : CAISSIER_PNR / CaissierPNR#2026  (caissier)
PROMPT   4. Login : MANAGER_PNR  / ManagerPNR#2026    (manager)
PROMPT   5. etc.
PROMPT
PROMPT   ⚠️ DEV ONLY — En production, change TOUS les mots de passe.
PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ SETUP 14 terminé — 7 users REGAL avec mots de passe
PROMPT ══════════════════════════════════════════════════════════
EXIT;
