-- ============================================================
-- S31 : Seed des 22 tables legacy gap-filler
-- ============================================================
-- Données réalistes pour démonstration fonctionnelle :
--   - 12 tables TT_* (file de transfert Master -> Boutiques)
--   - supplier_product (821 articles fournisseurs)
--   - product_unit_region (26K unites par region)
--   - pos_format + zones (LITOKO print format)
--   - warehouse_pc_auth
--   - payment_history (501K reglements)
--   - sys_message + sys_message_lang (i18n fr/en)
--   - sys_output
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

-- ════════════════════════════════════════════════════════
-- 1) Tables KERNEL.TT_* — file de transfert
-- ════════════════════════════════════════════════════════
CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════
PROMPT   KERNEL.TT_* — Files de transfert (12 tables)
PROMPT ══════════════════════════════════════════════════════

BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM tt_tloc';
  EXECUTE IMMEDIATE 'DELETE FROM tt_rtax';
  EXECUTE IMMEDIATE 'DELETE FROM tt_gcpuni_coeff';
  EXECUTE IMMEDIATE 'DELETE FROM tt_ecr_let';
  EXECUTE IMMEDIATE 'DELETE FROM tt_ecr_gen';
  EXECUTE IMMEDIATE 'DELETE FROM tt_ecr';
  EXECUTE IMMEDIATE 'DELETE FROM tt_caippar';
  EXECUTE IMMEDIATE 'DELETE FROM tt_gcppar';
  EXECUTE IMMEDIATE 'DELETE FROM tt_lum';
  EXECUTE IMMEDIATE 'DELETE FROM tt_brde';
  EXECUTE IMMEDIATE 'DELETE FROM tt_brdd';
  EXECUTE IMMEDIATE 'DELETE FROM tt_brd_office';
  COMMIT;
END;
/

-- TT_BRD_OFFICE : 228K rows (simulation : 100 rows pour démo)
PROMPT
PROMPT ▸ 100 transfers en file d'attente (PNR-OFC -> 4 boutiques)

DECLARE
  v_count NUMBER := 0;
BEGIN
  FOR tgt IN (SELECT site_code FROM site_master WHERE site_code LIKE 'BZV-%' OR site_code = 'DLS-B01' OR site_code = 'PNR-B01') LOOP
    FOR i IN 1..25 LOOP
      INSERT INTO tt_brd_office (source_site_code, target_site_code, codtbrd, idbrd, payload, transfer_state, created_at)
      VALUES (
        'PNR-OFC', tgt.site_code,
        CASE MOD(i, 5) WHEN 0 THEN 'VTE' WHEN 1 THEN 'ACH' WHEN 2 THEN 'INV' WHEN 3 THEN 'TRSF' ELSE 'BON' END,
        i + 1000,
        JSON_OBJECT('idbrd' VALUE i, 'total' VALUE ROUND(dbms_random.value(1000, 50000))),
        CASE WHEN i < 20 THEN 'PENDING' WHEN i < 23 THEN 'SENT' WHEN i < 25 THEN 'ACKED' ELSE 'ERROR' END,
        SYSTIMESTAMP - MOD(i, 30)
      );
      v_count := v_count + 1;
    END LOOP;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('  → ' || v_count || ' transfers crées.');
END;
/

-- TT_LUM : 19.8K lookups (100 pour démo)
INSERT INTO tt_lum (source_table, source_code, target_table, target_code, site_code, transfer_state)
SELECT 'GCPART', 'ART-' || LEVEL, 'PRODUCT', 'P-' || LEVEL,
       DECODE(MOD(LEVEL, 4), 0, 'BZV-B01', 1, 'BZV-B02', 2, 'DLS-B01', 'PNR-B01'),
       CASE WHEN LEVEL < 80 THEN 'PENDING' ELSE 'ACKED' END
  FROM dual CONNECT BY LEVEL <= 100;
COMMIT;

-- TT_GCPPAR : 1.5K paramètres (50 pour démo)
INSERT INTO tt_gcppar (codpar, valpar, site_code, transfer_state)
SELECT 'PAR' || LPAD(LEVEL, 4, '0'), 'VALEUR_' || LEVEL,
       DECODE(MOD(LEVEL, 3), 0, 'BZV-B01', 1, 'DLS-B01', 'PNR-B01'),
       CASE WHEN LEVEL < 40 THEN 'PENDING' ELSE 'DONE' END
  FROM dual CONNECT BY LEVEL <= 50;
COMMIT;

-- TT_CAIPPAR : 160 paramètres caisses (30)
INSERT INTO tt_caippar (codpar, valpar, terminal_code, transfer_state)
SELECT 'CAI' || LPAD(LEVEL, 3, '0'), 'VAL_' || LEVEL,
       'POS-' || DECODE(MOD(LEVEL, 4), 0, 'PNR-01', 1, 'BZV-01', 2, 'BZV-02', 'DLS-01'),
       'PENDING'
  FROM dual CONNECT BY LEVEL <= 30;
COMMIT;

-- TT_ECR, TT_ECR_GEN, TT_ECR_LET : écritures comptables
INSERT INTO tt_ecr (no_jou, no_edi, codmdr, no_maj, transfer_state)
SELECT 'ACH' || LPAD(MOD(LEVEL, 10), 2, '0'), LEVEL, 'VTE', LEVEL,
       CASE WHEN LEVEL < 30 THEN 'PENDING' ELSE 'SENT' END
  FROM dual CONNECT BY LEVEL <= 50;

INSERT INTO tt_ecr_gen (tt_ecr_id, codabr, sen, montant)
SELECT t.tt_id, '401' || LPAD(MOD(t.tt_id, 100), 3, '0'),
       CASE WHEN MOD(t.tt_id, 2) = 0 THEN 'D' ELSE 'C' END,
       ROUND(dbms_random.value(1000, 100000), 2)
  FROM tt_ecr t
  WHERE ROWNUM <= 100;

INSERT INTO tt_ecr_let (tt_ecr_id, codlet)
SELECT tt_id, 'LET' || LPAD(LEVEL, 6, '0')
  FROM tt_ecr
  WHERE ROWNUM <= 30;
COMMIT;

-- TT_GCPUNI_COEFF : 170 coefficients
INSERT INTO tt_gcpuni_coeff (codart, unit_src, unit_dst, coefficient, transfer_state)
SELECT 'ART' || LPAD(LEVEL, 5, '0'),
       CASE MOD(LEVEL, 3) WHEN 0 THEN 'CTN' WHEN 1 THEN 'PCS' ELSE 'KG' END,
       'PCS', ROUND(dbms_random.value(1, 50), 2), 'PENDING'
  FROM dual CONNECT BY LEVEL <= 60;
COMMIT;

-- TT_RTAX : 1.1K taux taxes
INSERT INTO tt_rtax (codrtax, taux, transfer_state)
SELECT 'TX' || LPAD(LEVEL, 4, '0'),
       CASE MOD(LEVEL, 3) WHEN 0 THEN 0.189 WHEN 1 THEN 0.09 ELSE 0 END,
       CASE WHEN LEVEL < 800 THEN 'PENDING' ELSE 'DONE' END
  FROM dual CONNECT BY LEVEL <= 50;
COMMIT;

-- TT_TLOC : 676 localisations
INSERT INTO tt_tloc (codloc, libloc, transfer_state)
SELECT 'LOC' || LPAD(LEVEL, 4, '0'), 'Localisation ' || LEVEL,
       CASE WHEN LEVEL < 500 THEN 'PENDING' ELSE 'DONE' END
  FROM dual CONNECT BY LEVEL <= 30;
COMMIT;

-- TT_BRDD, TT_BRDE : lignes/entêtes (en relation avec TT_BRD_OFFICE)
INSERT INTO tt_brde (tt_brd_id, datbrd, coddep_src, coddep_tgt, codtbrd, transfer_state)
SELECT tt_id, SYSDATE - MOD(tt_id, 30), 'DEP-PNR', 'DEP-BZV', codtbrd, transfer_state
  FROM tt_brd_office
 WHERE ROWNUM <= 30;

INSERT INTO tt_brdd (tt_brd_id, numlig, codart, quantity, payload, transfer_state)
SELECT b.tt_id, ROWNUM, 'ART-' || LPAD(MOD(LEVEL, 100), 4, '0'),
       ROUND(dbms_random.value(1, 100), 0),
       JSON_OBJECT('line' VALUE LEVEL, 'qty' VALUE dbms_random.value(1, 100)),
       'PENDING'
  FROM tt_brde b
  CROSS JOIN (SELECT LEVEL FROM dual CONNECT BY LEVEL <= 5)
  WHERE ROWNUM <= 80;
COMMIT;

PROMPT
PROMPT ═══ Volumétrie TT_* ═══
SELECT 'tt_brd_office'  AS tbl, COUNT(*) AS nb FROM tt_brd_office
UNION ALL SELECT 'tt_brde',      COUNT(*) FROM tt_brde
UNION ALL SELECT 'tt_brdd',      COUNT(*) FROM tt_brdd
UNION ALL SELECT 'tt_lum',       COUNT(*) FROM tt_lum
UNION ALL SELECT 'tt_gcppar',    COUNT(*) FROM tt_gcppar
UNION ALL SELECT 'tt_caippar',   COUNT(*) FROM tt_caippar
UNION ALL SELECT 'tt_ecr',       COUNT(*) FROM tt_ecr
UNION ALL SELECT 'tt_ecr_gen',   COUNT(*) FROM tt_ecr_gen
UNION ALL SELECT 'tt_ecr_let',   COUNT(*) FROM tt_ecr_let
UNION ALL SELECT 'tt_gcpuni_coeff', COUNT(*) FROM tt_gcpuni_coeff
UNION ALL SELECT 'tt_rtax',      COUNT(*) FROM tt_rtax
UNION ALL SELECT 'tt_tloc',      COUNT(*) FROM tt_tloc
 ORDER BY tbl;

-- ════════════════════════════════════════════════════════
-- 2) supplier_product — articles fournisseurs
-- ════════════════════════════════════════════════════════
CONNECT app_purchase/AppPurchase#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT ═══ supplier_product (821 articles fournisseurs) ═══
INSERT INTO supplier_product (
  supplier_code, product_code, supplier_ref, product_name,
  unit_purchase, purchase_price, min_order_qty, lead_time_days, is_preferred
)
SELECT
  DECODE(MOD(LEVEL, 5), 0, 'SUPP01', 1, 'SUPP02', 2, 'SUPP03', 3, 'SUPP04', 'SUPP05'),
  'ART' || LPAD(LEVEL, 5, '0'),
  'SUPREF-' || LPAD(LEVEL, 4, '0'),
  'Article Fournisseur ' || LEVEL,
  CASE MOD(LEVEL, 3) WHEN 0 THEN 'CTN' WHEN 1 THEN 'PCS' ELSE 'KG' END,
  ROUND(dbms_random.value(500, 25000), 2),
  ROUND(dbms_random.value(1, 50), 0),
  ROUND(dbms_random.value(7, 90), 0),
  CASE WHEN MOD(LEVEL, 4) = 0 THEN 1 ELSE 0 END
FROM dual CONNECT BY LEVEL <= 200;  -- démo 200 (cible 821)
COMMIT;
PROMPT 200 supplier_product insérés.

-- ════════════════════════════════════════════════════════
-- 3) product_unit_region — unités par région
-- ════════════════════════════════════════════════════════
CONNECT app_product/AppProduct#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT ═══ product_unit_region (cible 26K) ═══
INSERT INTO product_unit_region (product_code, unit_code, region_code, coefficient, unit_label)
SELECT
  'ART' || LPAD(MOD(LEVEL, 50), 5, '0'),
  CASE MOD(LEVEL, 3) WHEN 0 THEN 'CTN' WHEN 1 THEN 'PCS' ELSE 'KG' END,
  DECODE(MOD(LEVEL, 5), 0, 'PNR', 1, 'BZV', 2, 'DLS', 3, 'OYO', 'IMP'),
  ROUND(dbms_random.value(1, 12), 2),
  'Unite Region ' || LEVEL
FROM dual CONNECT BY LEVEL <= 500;  -- démo 500
COMMIT;
PROMPT 500 product_unit_region insérés.

-- ════════════════════════════════════════════════════════
-- 4) pos_format — formats tickets LITOKO
-- ════════════════════════════════════════════════════════
CONNECT app_pos/AppPos#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT ═══ pos_format + zones ═══
INSERT INTO pos_format (format_code, format_name, paper_width_mm, is_active)
VALUES ('LITOKO-A4', 'Facture A4 LITOKO SARL', 210, 1);
INSERT INTO pos_format (format_code, format_name, paper_width_mm, is_active)
VALUES ('LITOKO-80MM', 'Ticket thermique 80mm LITOKO', 80, 1);
INSERT INTO pos_format (format_code, format_name, paper_width_mm, is_active)
VALUES ('BOUTIQUE-58MM', 'Ticket boutique 58mm', 58, 1);

INSERT INTO pos_format_zone (format_id, zone_code, zone_order, zone_height_mm, content_template)
SELECT f.format_id, z.zone_code, z.zone_order, z.zone_height, z.template
  FROM pos_format f
  CROSS JOIN (
    SELECT 'LOGO'     AS zone_code, 1 AS zone_order, 15 AS zone_height, '{{logo_company}}' AS template FROM dual
    UNION ALL SELECT 'HEADER',    2, 10, 'LITOKO SARL - {{site_name}}' FROM dual
    UNION ALL SELECT 'INFO_VTE',  3, 20, 'Ticket N°{{ticket_no}} du {{sale_date}}' FROM dual
    UNION ALL SELECT 'ITEMS',     4, 80, 'Lignes produits avec TVA détail' FROM dual
    UNION ALL SELECT 'TOTALS',    5, 30, 'Total HT: {{total_ht}} | TVA: {{total_tva}} | TTC: {{total_ttc}}' FROM dual
    UNION ALL SELECT 'PAYMENT',   6, 20, 'Payé: {{payment_method}} {{amount}}' FROM dual
    UNION ALL SELECT 'FOOTER',    7, 15, 'Merci de votre visite - RCCM: CG-PNR-01-2017' FROM dual
    UNION ALL SELECT 'BARCODE',   8, 12, 'CODE128: {{ticket_no}}' FROM dual
  ) z
  WHERE f.format_code IN ('LITOKO-80MM', 'LITOKO-A4');
COMMIT;
PROMPT pos_format + zones LITOKO insérés.

-- ════════════════════════════════════════════════════════
-- 5) warehouse_pc_auth — autorisations PC par dépôt
-- ════════════════════════════════════════════════════════
PROMPT
PROMPT ═══ warehouse_pc_auth ═══
INSERT INTO warehouse_pc_auth (warehouse_code, pc_name, pc_mac, is_authorized, authorized_by, authorized_at)
VALUES ('DEP-PNR', 'PC-CAISSE-PNR-01', 'AA:BB:CC:DD:EE:01', 1, 'ADMIN', SYSTIMESTAMP);
INSERT INTO warehouse_pc_auth (warehouse_code, pc_name, pc_mac, is_authorized, authorized_by, authorized_at)
VALUES ('DEP-PNR', 'PC-CAISSE-PNR-02', 'AA:BB:CC:DD:EE:02', 1, 'ADMIN', SYSTIMESTAMP);
INSERT INTO warehouse_pc_auth (warehouse_code, pc_name, pc_mac, is_authorized, authorized_by, authorized_at)
VALUES ('DEP-BZV', 'PC-CAISSE-BZV-01', 'AA:BB:CC:DD:EE:03', 1, 'ADMIN', SYSTIMESTAMP);
INSERT INTO warehouse_pc_auth (warehouse_code, pc_name, pc_mac, is_authorized, authorized_by, authorized_at)
VALUES ('DEP-BZV', 'PC-CAISSE-BZV-02', 'AA:BB:CC:DD:EE:04', 0, 'ADMIN', SYSTIMESTAMP);
COMMIT;

-- ════════════════════════════════════════════════════════
-- 6) payment_history — historique règlements
-- ════════════════════════════════════════════════════════
CONNECT app_ar/AppAr#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT ═══ payment_history (cible 501K, démo 1000) ═══

DECLARE
  v_payments NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_payments FROM payment;
  DBMS_OUTPUT.PUT_LINE('  → Paiements existants : ' || v_payments);
END;
/

INSERT INTO payment_history (payment_id, party_code, invoice_id, paid_amount, paid_at, payment_method, bank_ref, applied_amount)
SELECT
  p.payment_id,
  p.party_code,
  p.invoice_id,
  p.amount,
  p.payment_date + INTERVAL '1' HOUR,
  p.payment_method,
  'BANKREF-' || LPAD(LEVEL, 8, '0'),
  p.amount
FROM payment p,
     (SELECT LEVEL FROM dual CONNECT BY LEVEL <= 50) gen
WHERE ROWNUM <= 1000;
COMMIT;
PROMPT 1000 payment_history insérés.

-- ════════════════════════════════════════════════════════
-- 7) sys_message + sys_message_lang — i18n
-- ════════════════════════════════════════════════════════
CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT ═══ sys_message + i18n fr/en ═══

INSERT INTO sys_message (message_key, default_text, message_type) VALUES ('CASH.BON.SIGNATURE', 'Signature du bon de caisse', 'LABEL');
INSERT INTO sys_message (message_key, default_text, message_type) VALUES ('POS.TICKET.OK', 'Ticket validé', 'INFO');
INSERT INTO sys_message (message_key, default_text, message_type) VALUES ('POS.TICKET.KO', 'Erreur validation ticket', 'ERROR');
INSERT INTO sys_message (message_key, default_text, message_type) VALUES ('TRANSFER.WAIT', 'Transfert en attente approbation', 'WARN');
INSERT INTO sys_message (message_key, default_text, message_type) VALUES ('INVOICE.OVERDUE', 'Facture en retard', 'WARN');
INSERT INTO sys_message (message_key, default_text, message_type) VALUES ('STOCK.LOW', 'Stock bas : alerte réapprovisionnement', 'WARN');
INSERT INTO sys_message (message_key, default_text, message_type) VALUES ('PAYMENT.RECEIVED', 'Paiement reçu', 'INFO');
INSERT INTO sys_message (message_key, default_text, message_type) VALUES ('USER.AUTH.OK', 'Authentification réussie', 'INFO');
INSERT INTO sys_message (message_key, default_text, message_type) VALUES ('USER.AUTH.KO', 'Identifiants incorrects', 'ERROR');
INSERT INTO sys_message (message_key, default_text, message_type) VALUES ('TAVA.OK', 'TVA collectée OK', 'INFO');

-- Traductions fr/en
INSERT INTO sys_message_lang (message_id, lang_code, translated_text)
SELECT message_id, 'fr', default_text FROM sys_message;

INSERT INTO sys_message_lang (message_id, lang_code, translated_text)
VALUES ((SELECT message_id FROM sys_message WHERE message_key = 'CASH.BON.SIGNATURE'), 'en', 'Cash voucher signature');
INSERT INTO sys_message_lang (message_id, lang_code, translated_text)
VALUES ((SELECT message_id FROM sys_message WHERE message_key = 'POS.TICKET.OK'), 'en', 'Ticket validated');
INSERT INTO sys_message_lang (message_id, lang_code, translated_text)
VALUES ((SELECT message_id FROM sys_message WHERE message_key = 'POS.TICKET.KO'), 'en', 'Ticket validation error');
INSERT INTO sys_message_lang (message_id, lang_code, translated_text)
VALUES ((SELECT message_id FROM sys_message WHERE message_key = 'INVOICE.OVERDUE'), 'en', 'Invoice overdue');
INSERT INTO sys_message_lang (message_id, lang_code, translated_text)
VALUES ((SELECT message_id FROM sys_message WHERE message_key = 'STOCK.LOW'), 'en', 'Low stock: reorder alert');
INSERT INTO sys_message_lang (message_id, lang_code, translated_text)
VALUES ((SELECT message_id FROM sys_message WHERE message_key = 'TAVA.OK'), 'en', 'VAT collected OK');

COMMIT;
PROMPT sys_message + traductions insérés (10 messages, 6 traductions EN).

-- ════════════════════════════════════════════════════════
-- 8) sys_output
-- ════════════════════════════════════════════════════════
PROMPT
PROMPT ═══ sys_output (1.3M cible) ═══
INSERT INTO sys_output (output_type, user_code, document_type, document_id, output_data, created_at, printed_at)
SELECT
  CASE MOD(LEVEL, 4) WHEN 0 THEN 'PRINT' WHEN 1 THEN 'FILE' WHEN 2 THEN 'MAIL' ELSE 'DISPLAY' END,
  'CAISSIER' || MOD(LEVEL, 5),
  CASE MOD(LEVEL, 3) WHEN 0 THEN 'TICKET' WHEN 1 THEN 'INVOICE' ELSE 'REPORT' END,
  LEVEL,
  JSON_OBJECT('doc' VALUE LEVEL, 'site' VALUE 'BZV-B01'),
  SYSTIMESTAMP - dbms_random.value(0, 90),
  CASE WHEN MOD(LEVEL, 3) = 0 THEN NULL ELSE SYSTIMESTAMP END
FROM dual CONNECT BY LEVEL <= 500;  -- démo 500
COMMIT;
PROMPT 500 sys_output insérés.

-- ════════════════════════════════════════════════════════
-- 9) Données de partition effectives
-- ════════════════════════════════════════════════════════
PROMPT
PROMPT ═══ Insertion dans tables partitionnées ═══

CONNECT app_sales/AppSales#2026@localhost:1521/FREEPDB1
INSERT INTO ticket_line_v2 (ticket_id, line_no, product_code, quantity, unit_price,
                              amount_ht, tax_rate, tax_amount, amount_ttc, site_code, sale_date)
SELECT
  t.ticket_id, 1, 'ART' || LPAD(MOD(LEVEL, 50), 5, '0'),
  ROUND(dbms_random.value(1, 10), 0),
  ROUND(dbms_random.value(500, 5000), 0),
  ROUND(dbms_random.value(5000, 50000), 0),
  0.189,
  ROUND(dbms_random.value(945, 9450), 0),
  ROUND(dbms_random.value(5945, 59450), 0),
  DECODE(MOD(LEVEL, 4), 0, 'BZV-B01', 1, 'BZV-B02', 2, 'DLS-B01', 'PNR-B01'),
  SYSDATE - MOD(LEVEL, 180)
FROM ticket t
  CROSS JOIN (SELECT LEVEL FROM dual CONNECT BY LEVEL <= 3) gen
WHERE ROWNUM <= 200;
COMMIT;
PROMPT 200 ticket_line_v2 insérés.

CONNECT app_inv/AppInv#2026@localhost:1521/FREEPDB1
INSERT INTO transfer_line_v2 (transfer_id, line_no, product_code, requested_qty, sent_qty, received_qty,
                                unit_cost, lot_number, site_code, transfer_date)
SELECT
  t.transfer_id, ROWNUM, 'ART' || LPAD(MOD(LEVEL, 50), 5, '0'),
  50, 50, 50, 1500, NULL, 'PNR-OFC', SYSDATE - MOD(LEVEL, 90)
FROM transfer_header t
  CROSS JOIN (SELECT LEVEL FROM dual CONNECT BY LEVEL <= 3) gen
WHERE ROWNUM <= 100;
COMMIT;
PROMPT 100 transfer_line_v2 insérés.

CONNECT app_gl/AppGl#2026@localhost:1521/FREEPDB1
INSERT INTO gl_entry_line_v2 (entry_id, line_no, account_code, debit, credit, fiscal_year, posting_date)
SELECT
  e.entry_id, ROWNUM,
  CASE MOD(LEVEL, 4) WHEN 0 THEN '411000' WHEN 1 THEN '401000' WHEN 2 THEN '701000' ELSE '530000' END,
  CASE MOD(LEVEL, 2) WHEN 0 THEN ROUND(dbms_random.value(1000, 50000), 2) ELSE 0 END,
  CASE MOD(LEVEL, 2) WHEN 1 THEN ROUND(dbms_random.value(1000, 50000), 2) ELSE 0 END,
  EXTRACT(YEAR FROM e.entry_date), e.entry_date
FROM gl_entry e
  CROSS JOIN (SELECT LEVEL FROM dual CONNECT BY LEVEL <= 4) gen
WHERE ROWNUM <= 300;
COMMIT;
PROMPT 300 gl_entry_line_v2 insérés.

-- ════════════════════════════════════════════════════════
-- 10) Demostrations
-- ════════════════════════════════════════════════════════
PROMPT
PROMPT ═══ Demostrations ═══

PROMPT [Q1] Volumétrie totale des nouvelles tables
SELECT 'Tables legacy gap-filler' AS categorie,
       (SELECT COUNT(*) FROM app_sys.tt_brd_office
        + (SELECT COUNT(*) FROM app_sys.tt_brde)
        + (SELECT COUNT(*) FROM app_sys.tt_lum)
        + (SELECT COUNT(*) FROM app_purchase.supplier_product)
        + (SELECT COUNT(*) FROM app_product.product_unit_region)
        + (SELECT COUNT(*) FROM app_ar.payment_history)
        + (SELECT COUNT(*) FROM app_sys.sys_message)
        + (SELECT COUNT(*) FROM app_sys.sys_output)
        + (SELECT COUNT(*) FROM app_pos.pos_format_zone)
       ) AS total_rows
  FROM dual;

PROMPT [Q2] État de la file de transfert TT_BRD_OFFICE
SELECT transfer_state, target_site_code, COUNT(*) AS nb
  FROM app_sys.tt_brd_office
 GROUP BY transfer_state, target_site_code
 ORDER BY transfer_state, target_site_code;

PROMPT [Q3] Partition par site pour ticket_line_v2
SELECT site_code, COUNT(*) AS nb_lines, SUM(amount_ttc) AS total_ca
  FROM app_sales.ticket_line_v2
 GROUP BY site_code
 ORDER BY total_ca DESC;

PROMPT [Q4] Messages i18n disponibles
SELECT m.message_key, m.message_type,
       (SELECT translated_text FROM sys_message_lang WHERE message_id = m.message_id AND lang_code = 'fr') AS fr,
       (SELECT translated_text FROM sys_message_lang WHERE message_id = m.message_id AND lang_code = 'en') AS en
  FROM sys_message m
 WHERE ROWNUM <= 10
 ORDER BY m.message_type, m.message_key;

PROMPT [Q5] Top 5 articles les plus chers (fournisseurs)
SELECT supplier_code, product_code, purchase_price, lead_time_days
  FROM supplier_product
 ORDER BY purchase_price DESC
 FETCH FIRST 5 ROWS ONLY;

PROMPT [Q6] Paiements par mois (payment_history)
SELECT TO_CHAR(paid_at, 'YYYY-MM') AS mois, COUNT(*) AS nb_paiements,
       SUM(paid_amount) AS total
  FROM payment_history
 GROUP BY TO_CHAR(paid_at, 'YYYY-MM')
 ORDER BY 1 DESC;

PROMPT [Q7] Formats LITOKO
SELECT f.format_code, f.format_name, f.paper_width_mm,
       COUNT(z.zone_id) AS nb_zones
  FROM pos_format f
  LEFT JOIN pos_format_zone z ON z.format_id = f.format_id
 GROUP BY f.format_code, f.format_name, f.paper_width_mm
 ORDER BY f.format_code;

PROMPT ══════════════════════════════════════════════════════
PROMPT   ✅ SEED 22 TABLES LEGACY + PARTITIONS — Terminé
PROMPT   - TT_*: 100 transfers en attente, 100 lookups, 50 params
PROMPT   - supplier_product: 200 articles fournisseurs
PROMPT   - product_unit_region: 500 unites par region
PROMPT   - pos_format: 3 formats LITOKO + 8 zones
PROMPT   - payment_history: 1000 reglements
PROMPT   - sys_message: 10 messages (6 traduits EN)
PROMPT   - sys_output: 500 outputs
PROMPT   - ticket_line_v2: 200 lignes / 4 sites
PROMPT   - transfer_line_v2: 100 lignes
PROMPT   - gl_entry_line_v2: 300 lignes sur 2024-2026
PROMPT ══════════════════════════════════════════════════════
EXIT;
