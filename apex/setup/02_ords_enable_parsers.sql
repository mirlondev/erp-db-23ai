-- ============================================================
-- APEX SETUP 02 : Activation ORDS sur les schémas APP_* (REST)
-- ============================================================
-- Prérequis : ORDS installé, APEXSetupRole accordé, et le rôle
--   CREATE/rest_admin droits pour l'utilisateur exécutant.
-- À jouer en SYS as sysdba sur FREEPDB1. Idempotent.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT ══════════════════════════════════════════════════════════
PROMPT APEX SETUP 02 — Enable ORDS schemas REGAL
PROMPT ══════════════════════════════════════════════════════════

-- Activation via ORDS_ADMIN.ENABLE_SCHEMA.
-- Idempotent : vérifie user_ords_enabled avant d'appeler.
DECLARE
  v_cnt     NUMBER;
  v_status  VARCHAR2(20);
BEGIN
  SELECT COUNT(*) INTO v_cnt FROM all_procedures
   WHERE owner = 'ORDS_METADATA'
     AND object_name = 'ORDS_ADMIN'
     AND procedure_name = 'ENABLE_SCHEMA';
  IF v_cnt = 0 THEN
    DBMS_OUTPUT.PUT_LINE('!! ORDS non installé dans ce PDB.');
    DBMS_OUTPUT.PUT_LINE('   Lancer d''abord: java -jar ords.war install');
    DBMS_OUTPUT.PUT_LINE('   (ou: ords enable --schema APP_API --alias regal-api ...)');
    RETURN;
  END IF;
  DBMS_OUTPUT.PUT_LINE('ORDS détecté — activation des schémas...');

  FOR r IN (SELECT username FROM all_users
            WHERE username IN ('APP_API','APP_SALES','APP_INV','APP_GL',
                               'APP_SYS','APP_PURCHASE','APP_POS')) LOOP
    BEGIN
      EXECUTE IMMEDIATE
        'SELECT status FROM ords_metadata.dba_ords_schemas WHERE parsing_schema = :1'
        INTO v_status USING r.username;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN v_status := 'DISABLED';
      WHEN OTHERS        THEN v_status := 'DISABLED';
    END;

    IF v_status = 'ENABLED' THEN
      DBMS_OUTPUT.PUT_LINE('  • '||r.username||' déjà activé — skip.');
    ELSE
      EXECUTE IMMEDIATE
        'BEGIN ORDS_ADMIN.ENABLE_SCHEMA(p_enabled => TRUE, p_schema => :1, p_url_mapping_type => :2, p_url_mapping_pattern => :3, p_auto_rest_auth => FALSE); END;'
        USING r.username, 'BASE_PATH', 'regal-' || LOWER(SUBSTR(r.username, 5));
      DBMS_OUTPUT.PUT_LINE('  ✓ '||r.username||' → /ords/regal-'||LOWER(SUBSTR(r.username,5)));
    END IF;
  END LOOP;
END;
/

COMMIT;

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT ✅ Schémas ORDS activés (ou instructions CLI affichées).
PROMPT    Les JSON Duality Views du script 12 (app_api) sont ainsi
PROMPT    exposées: /ords/regal-api/product-v2, /party-v2, ...
PROMPT    → consommables par l'app mobile hors-ligne des boutiques.
PROMPT ══════════════════════════════════════════════════════════
