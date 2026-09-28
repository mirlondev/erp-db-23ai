-- ============================================================
-- SCRIPT 42 : ETL Squelette — Migration legacy 11g → moderne 23ai
-- ============================================================
-- ATTENTION : Ce script est un SQUELETTE d'ETL.
-- Il montre les patterns de migration pour chaque schéma.
-- À adapter selon le mapping réel entre votre base 11g et la cible 23ai.
--
-- MODE D'EMPLOI :
--   1. Configurer DB_LINK vers la base legacy : CREATE DATABASE LINK ...
--   2. Adapter les mappings colonne-à-colonne
--   3. Tester d'abord en mode DRY_RUN (p_dry_run => TRUE)
--   4. Une fois validé, lancer en mode production (p_dry_run => FALSE)
--
-- Le script NE FAIT PAS de DDL/DML automatique : il génère des
-- instructions SQL paramétrées que vous pouvez rejouer.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ETL SQUELETTE — Migration legacy 11g → moderne 23ai
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT Configuration attendue : DB_LINK 'LEGACY' vers Oracle 11g
PROMPT Exemple :
PROMPT   CREATE DATABASE LINK legacy
PROMPT     CONNECT TO legacy_user IDENTIFIED BY legacy_pwd
PROMPT     USING 'LEGACY_TNS';


PROMPT
PROMPT ════════════════════════════════════════════════════════
PROMPT   SECTION 1 : Mapping des schémas
PROMPT ════════════════════════════════════════════════════════

PROMPT
PROMPT Source (legacy 11g)             → Cible (moderne 23ai)
PROMPT ----------------------------------------------------------
PROMPT CAISSE.CA_PARAM                → app_sys.sys_parameter
PROMPT CAISSE.GCPROMO                 → app_product.promo_*
PROMPT CAISSE.GCPART*                 → app_product.product, product_*
PROMPT CAISSE.GCPART_LOT             → app_inv.inv_product_lot
PROMPT CAISSE.CEPCFCARTE              → app_party.loyalty_card
PROMPT CAISSE.CECFOPER                → app_party.loyalty_operation
PROMPT CAISSE.GCSTOCK_STATUT          → app_inv.inv_stock_status
PROMPT CAISSE.CETICKET                → app_sales.ticket
PROMPT CAISSE.CETICKETLINE            → app_sales.ticket_line
PROMPT CAISSE.GCEXPEDITION            → app_ship.shipment
PROMPT CAISSE.CEBON                   → app_party.voucher_master
PROMPT
PROMPT KERNEL.GCUSER                  → app_sys.sys_user
PROMPT KERNEL.GCACCESS                → app_sys.sys_access_key
PROMPT KERNEL.UTUTI                   → non migré (session techniques legacy)
PROMPT
PROMPT XCPTA.CP_COMPTE                → app_gl.gl_account_ohada (mapping direct)
PROMPT XCPTA.CP_PIECE                 → app_gl.gl_entry
PROMPT XCPTA.CP_ECRITURE              → app_gl.gl_entry_line
PROMPT XCPTA.CP_JOURNAL               → app_gl.gl_journal
PROMPT
PROMPT TRANSFERT.TR_HEADER            → app_inv.transfer_header
PROMPT TRANSFERT.TR_LINE              → app_inv.transfer_line
PROMPT
PROMPT CASH.GCBMVT                    → app_cash.cash_movement
PROMPT ERP_APP                        → varié

PROMPT
PROMPT ════════════════════════════════════════════════════════
PROMPT   SECTION 2 : Package utilitaire pkg_etl_legacy
PROMPT ════════════════════════════════════════════════════════

PROMPT
PROMPT Création du package ETL dans app_api (couche orchestration)
CONNECT system/oracle@localhost:1521/FREEPDB1

GRANT CREATE PROCEDURE, CREATE TYPE TO app_api;

CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

CREATE OR REPLACE PACKAGE pkg_etl_legacy AS
  -- Log global d'exécution ETL
  PROCEDURE log_step(
    p_phase    IN VARCHAR2,
    p_action   IN VARCHAR2,
    p_count    IN NUMBER DEFAULT NULL,
    p_message  IN VARCHAR2 DEFAULT NULL
  );

  -- Migration d'une table : compte source / cible / erreurs
  PROCEDURE migrate_table(
    p_source_table IN VARCHAR2,
    p_target_table IN VARCHAR2,
    p_dry_run      IN BOOLEAN DEFAULT TRUE
  );

  -- Vérification mapping colonne-à-colonne (rapporte colonnes manquantes)
  PROCEDURE verify_mapping(p_source_table IN VARCHAR2, p_target_table IN VARCHAR2) IS
  BEGIN
    -- Squelette : à implémenter avec requêtes sur user_tab_columns via DB_LINK
    log_step('VERIFY_MAPPING', p_source_table || ' -> ' || p_target_table);
  END verify_mapping;

  -- Migration complète par lot (lots R1-R14 + 1A-1F)
  PROCEDURE migrate_lot(
    p_lot_code IN VARCHAR2,
    p_dry_run  IN BOOLEAN DEFAULT TRUE
  );

  -- Rapport final
  FUNCTION get_migration_report RETURN CLOB;
END pkg_etl_legacy;
/

PROMPT ✓ Spec créée

CREATE OR REPLACE PACKAGE BODY pkg_etl_legacy AS

  c_etl_log CONSTANT VARCHAR2(30) := 'ETL_LOG';

  PROCEDURE log_step(p_phase IN VARCHAR2, p_action IN VARCHAR2,
                     p_count IN NUMBER DEFAULT NULL,
                     p_message IN VARCHAR2 DEFAULT NULL) IS
  BEGIN
    -- À adapter : insérer dans une table d'audit ETL
    DBMS_OUTPUT.PUT_LINE(
      TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') || ' | ' ||
      p_phase || ' | ' || p_action || ' | count=' || NVL(TO_CHAR(p_count),'-') ||
      CASE WHEN p_message IS NOT NULL THEN ' | ' || p_message ELSE '' END
    );
  END log_step;

  PROCEDURE verify_mapping(p_source_table IN VARCHAR2, p_target_table IN VARCHAR2) IS
    -- Squelette : à implémenter avec requêtes sur user_tab_columns via DB_LINK
    log_step('VERIFY_MAPPING', p_source_table || ' -> ' || p_target_table);
    -- Exemple :
    -- SELECT column_name FROM user_tab_columns WHERE table_name = p_target_table
    -- MINUS
    -- SELECT column_name FROM legacy_columns@p_link WHERE table_name = p_source_table;
  END verify_mapping;

  PROCEDURE migrate_table(p_source_table IN VARCHAR2, p_target_table IN VARCHAR2,
                          p_dry_run IN BOOLEAN DEFAULT TRUE) IS
  BEGIN
    log_step('MIGRATE_TABLE', p_source_table || ' -> ' || p_target_table,
             NULL, CASE WHEN p_dry_run THEN 'DRY_RUN' ELSE 'PRODUCTION' END);
    -- À implémenter : INSERT...SELECT via DB_LINK + transformation
  END migrate_table;

  PROCEDURE migrate_lot(p_lot_code IN VARCHAR2, p_dry_run IN BOOLEAN DEFAULT TRUE) IS
  BEGIN
    CASE p_lot_code
      WHEN 'R1' THEN
        migrate_table('GCPROMO@legacy', 'promo_header', p_dry_run);
        migrate_table('GCPROMO_ART@legacy', 'promo_product', p_dry_run);
      WHEN 'R2' THEN
        migrate_table('CEPCFCARTE@legacy', 'loyalty_card', p_dry_run);
        migrate_table('CECFOPER@legacy', 'loyalty_operation', p_dry_run);
      WHEN 'R3' THEN
        migrate_table('GCPART_LOT@legacy', 'inv_product_lot', p_dry_run);
        migrate_table('GCSTOCK_STATUT@legacy', 'inv_stock_status', p_dry_run);
      WHEN 'R5' THEN
        migrate_table('CP_FACTURE@legacy', 'invoice', p_dry_run);
        migrate_table('CP_FACTURE_RUBR_CPT@legacy', 'invoice_line', p_dry_run);
      WHEN 'R7' THEN
        migrate_table('CETICKET@legacy', 'ticket', p_dry_run);
        migrate_table('CETICKETLINE@legacy', 'ticket_line', p_dry_run);
      ELSE
        log_step('MIGRATE_LOT', p_lot_code, NULL, 'LOT_NOT_FOUND');
    END CASE;
  END migrate_lot;

  FUNCTION get_migration_report RETURN CLOB IS
    v_report CLOB := '';
  BEGIN
    -- À implémenter : agrégation depuis une table de log ETL
    RETURN v_report;
  END get_migration_report;

END pkg_etl_legacy;
/

PROMPT ✓ Body créé

PROMPT
PROMPT ════════════════════════════════════════════════════════
PROMPT   SECTION 3 : Exemples d'utilisation
PROMPT ════════════════════════════════════════════════════════

PROMPT
PROMPT Pour migrer les produits depuis legacy :
PROMPT   SET SERVEROUTPUT ON
PROMPT   BEGIN
PROMPT     pkg_etl_legacy.migrate_lot('R1', p_dry_run => TRUE);
PROMPT     pkg_etl_legacy.migrate_lot('R3', p_dry_run => TRUE);
PROMPT   END;
PROMPT   /
PROMPT
PROMPT Pour vérifier un mapping :
PROMPT   BEGIN
PROMPT     pkg_etl_legacy.verify_mapping('GCPROMO', 'promo_header');
PROMPT   END;
PROMPT   /
PROMPT
PROMPT Pour rapport final :
PROMPT   SELECT pkg_etl_legacy.get_migration_report() FROM DUAL;

PROMPT
PROMPT ════════════════════════════════════════════════════════
PROMPT   SECTION 4 : CHECKLIST avant migration réelle
PROMPT ════════════════════════════════════════════════════════

PROMPT
PROMPT □ Créer le DB_LINK vers la base legacy
PROMPT □ Mapper les colonnes legacy → modernes (verifier_mapping)
PROMPT □ Tester en DRY_RUN pour chaque table
PROMPT □ Comparer les comptages (COUNT) source vs cible
PROMPT □ Vérifier l'intégrité référentielle (FK)
PROMPT □ Tester sur un échantillon de 100 lignes avant full
PROMPT □ Planifier la fenêtre de maintenance (idéal: week-end)
PROMPT □ Préparer le rollback (snapshot préalable de la cible)
PROMPT □ Auditer après migration (R13 sys_audit_trail)
PROMPT □ Basculer les applications sur la nouvelle base

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ SQUELETTE ETL pkg_etl_legacy INSTALLÉ
PROMPT ══════════════════════════════════════════════════════════
EXIT;
