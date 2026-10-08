-- ============================================================
-- APEX SETUP 15 : Vues pour app-achats et app-admin
-- ============================================================
-- Cree les vues app_api.v_achats_kpi_cards et app_api.v_admin_kpi_cards
-- utilisees par les pages dashboard des apps 400 et 500.
--
-- A executer APRES 14_bootstrap_users.sql
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF
WHENEVER SQLERROR EXIT FAILURE

CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT ================================================================
PROMPT   [1/2] Vue v_achats_kpi_cards (app 400)
PROMPT ================================================================

CREATE OR REPLACE VIEW app_api.v_achats_kpi_cards AS
SELECT 'Demandes ouvertes'       AS label, 'COUNT' AS unit,
       (SELECT COUNT(*) FROM app_purchase.purchase_request
         WHERE status IN ('OPEN','QUOTED')) AS valeur, 10 AS cible FROM DUAL
UNION ALL
SELECT 'Commandes en cours', 'COUNT',
       (SELECT COUNT(*) FROM app_purchase.purchase_order
         WHERE status IN ('DRAFT','VALIDATED','PARTIAL')) AS valeur, 30 AS cible FROM DUAL
UNION ALL
SELECT 'Receptions en attente', 'COUNT',
       (SELECT COUNT(*) FROM app_purchase.delivery_note
         WHERE status IN ('OPEN','PARTIAL')) AS valeur, 15 AS cible FROM DUAL
UNION ALL
SELECT 'Fournisseurs actifs', 'COUNT',
       (SELECT COUNT(*) FROM app_party.party
         WHERE nature_id = 2 AND is_blocked = 'N') AS valeur, NULL FROM DUAL
UNION ALL
SELECT 'Montant achats MTD', 'XAF',
       (SELECT NVL(SUM(total_ttc), 0) FROM app_purchase.purchase_order
         WHERE TRUNC(po_date, 'MM') = TRUNC(SYSDATE, 'MM')) AS valeur, NULL FROM DUAL
UNION ALL
SELECT 'OTD global', 'PCT',
       (SELECT NVL(ROUND(100 * SUM(CASE WHEN status='CLOSED' AND received_on_time = 1 THEN 1 ELSE 0 END) /
                              NULLIF(SUM(CASE WHEN status='CLOSED' THEN 1 ELSE 0 END), 0)), 95)
          FROM app_purchase.delivery_note
         WHERE delivery_date >= trunc(sysdate) - 90) AS valeur, NULL FROM DUAL
/

PROMPT
PROMPT [T1] Verification v_achats_kpi_cards
SELECT label, valeur, cible
  FROM app_api.v_achats_kpi_cards
 ORDER BY decode(label,'Demandes ouvertes',1,'Commandes en cours',2,'Receptions en attente',3,
                  'Fournisseurs actifs',4,'Montant achats MTD',5,'OTD global',6);

PROMPT
PROMPT ================================================================
PROMPT   [2/2] Vue v_admin_kpi_cards (app 500)
PROMPT ================================================================

CREATE OR REPLACE VIEW app_api.v_admin_kpi_cards AS
SELECT 'Utilisateurs actifs'      AS label, 'COUNT' AS unit,
       (SELECT COUNT(*) FROM app_sys.sys_user WHERE is_active = 1) AS valeur, NULL FROM DUAL
UNION ALL
SELECT 'Roles configures', 'COUNT',
       (SELECT COUNT(*) FROM app_sys.sys_role WHERE is_active = 1) AS valeur, NULL FROM DUAL
UNION ALL
SELECT 'Evenements outbox', 'COUNT',
       (SELECT COUNT(*) FROM app_sys.outbox_event
         WHERE status IN ('PENDING','FAILED','RETRYING')
           AND created_at > systimestamp - INTERVAL '24' HOUR) AS valeur, 0 AS cible FROM DUAL
UNION ALL
SELECT 'Sites deployes', 'COUNT',
       (SELECT COUNT(*) FROM app_sys.site_master WHERE is_active = 1) AS valeur, NULL FROM DUAL
UNION ALL
SELECT 'Alertes ouvertes', 'COUNT',
       (SELECT COUNT(*) FROM app_sys.alert_instance WHERE status = 'OPEN') AS valeur, NULL FROM DUAL
UNION ALL
SELECT 'API erreurs 24h', 'COUNT',
       (SELECT COUNT(*) FROM app_sys.interface_log
         WHERE status IN ('ERROR','TIMEOUT','SERVER_ERROR')
           AND created_at > SYSDATE - 1/24) AS valeur, 0 AS cible FROM DUAL
/

PROMPT
PROMPT [T2] Verification v_admin_kpi_cards
SELECT label, valeur, cible
  FROM app_api.v_admin_kpi_cards
 ORDER BY decode(label,'Utilisateurs actifs',1,'Roles configures',2,
                  'Evenements outbox',3,'Sites deployes',4,
                  'Alertes ouvertes',5,'API erreurs 24h',6);

PROMPT
PROMPT ================================================================
PROMPT   SETUP 15 termine — 2 vues creees
PROMPT ================================================================
EXIT;