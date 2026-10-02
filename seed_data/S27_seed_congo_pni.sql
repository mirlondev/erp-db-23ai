-- ============================================================
-- S27 : Seed Congo Brazzaville — LITOKO SARL (Pointe-Noire)
-- ============================================================
-- Scénario réaliste : société LITOKO SARL basée à Pointe-Noire
--   - Siège social : Av. Charles de Gaulle, Centre-ville, Pointe-Noire
--   - Dépôt principal (DEP-PNR) : Zone industrielle, Pointe-Noire
--   - Magasin 1 (POS-BZV) : Centre-ville Brazzaville (succursale)
--   - Centre des impôts : CG-PNR (Pointe-Noire)
--   - Réf. dossiers : conforme aux factures LITOKO du dossier docs/
--
-- Fiscale : CEMAC 18.9% TVA, CNSS 10%/19.5%, IRPP 8 tranches
-- Devise : XAF (BEAC)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   SEED LITOKO SARL — Pointe-Noire, Congo Brazzaville
PROMPT ══════════════════════════════════════════════════════════

-- ═══ 1. Société LITOKO SARL (Pointe-Noire) ═══
CONNECT app_org/AppOrg#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT ▸ Inscription de la société LITOKO SARL à Pointe-Noire

DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM org_company WHERE company_code = 'LITOKO';
  IF v_count = 0 THEN
    INSERT INTO org_company (
      company_code, company_name, country_code, tax_rate, address
    ) VALUES (
      'LITOKO', 'LITOKO SARL', 'CG', 18.9,
      'Avenue Charles de Gaulle, Pointe-Noire'
    );
    DBMS_OUTPUT.PUT_LINE('  → LITOKO SARL créée.');
  ELSE
    DBMS_OUTPUT.PUT_LINE('  → LITOKO SARL déjà présente.');
  END IF;
  COMMIT;
END;
/

-- ═══ 2. Dépôt principal Pointe-Noire ═══
PROMPT
PROMPT ▸ Dépôt LITOKO-DEP-PNR (Pointe-Noire, zone industrielle)

INSERT INTO org_warehouse (warehouse_code, company_id, warehouse_name, is_sale_allowed, is_purch_allowed, warehouse_type)
SELECT 'LIT01', company_id, 'Dépôt central Pointe-Noire', TRUE, TRUE, 'D'
  FROM org_company WHERE company_code = 'LITOKO';

INSERT INTO org_warehouse (warehouse_code, company_id, warehouse_name, is_sale_allowed, is_purch_allowed, warehouse_type)
SELECT 'LIT02', company_id, 'Dépôt secondaire Brazzaville', TRUE, TRUE, 'D'
  FROM org_company WHERE company_code = 'LITOKO';

COMMIT;

-- ═══ 3. Magasins LITOKO ═══
PROMPT
PROMPT ▸ Magasins LITOKO (Brazzaville, Pointe-Noire)

CONNECT app_pos/AppPos#2026@localhost:1521/FREEPDB1
INSERT INTO pos_terminal (terminal_code, terminal_name, currency_code, access_key,
        warehouse_code, price_list_code, pos_code)
VALUES ('LBZV01', 'Boutique LITOKO Brazzaville Centre', 'XAF', 'LITOKO_POS', 'LIT02', '0', 'LB1');
INSERT INTO pos_terminal (terminal_code, terminal_name, currency_code, access_key,
        warehouse_code, price_list_code, pos_code)
VALUES ('LBZV02', 'Boutique LITOKO Poto-Poto', 'XAF', 'LITOKO_POS', 'LIT02', '0', 'LB2');
INSERT INTO pos_terminal (terminal_code, terminal_name, currency_code, access_key,
        warehouse_code, price_list_code, pos_code)
VALUES ('LPNR01', 'Boutique LITOKO Pointe-Noire Centre', 'XAF', 'LITOKO_POS', 'LIT01', '0', 'LP1');
INSERT INTO pos_terminal (terminal_code, terminal_name, currency_code, access_key,
        warehouse_code, price_list_code, pos_code)
VALUES ('LPNR02', 'Boutique LITOKO Mpita', 'XAF', 'LITOKO_POS', 'LIT01', '0', 'LP2');
INSERT INTO pos_terminal (terminal_code, terminal_name, currency_code, access_key,
        warehouse_code, price_list_code, pos_code)
VALUES ('LDLS01', 'Boutique LITOKO Dolisie', 'XAF', 'LITOKO_POS', 'LIT01', '0', 'LD1');

COMMIT;
PROMPT 5 magasins LITOKO créés.

-- ═══ 4. Stock initial LITOKO — articles catalogue ═══
CONNECT app_inv/AppInv#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT ▸ Stock initial — Articles catalogue LITOKO

INSERT INTO inv_stock (warehouse_code, product_code, stock_qty, last_in_at)
SELECT 'LIT01', p.product_code, 200, SYSDATE
  FROM app_product.product p
 WHERE p.status = 'ACTIVE' AND p.is_stock_managed = TRUE;

INSERT INTO inv_stock (warehouse_code, product_code, stock_qty, last_in_at)
SELECT 'LIT02', p.product_code, 100, SYSDATE
  FROM app_product.product p
 WHERE p.status = 'ACTIVE' AND p.is_stock_managed = TRUE;

COMMIT;

PROMPT
PROMPT ═══ Volumétrie ═══
SELECT 'LITOKO Dépôts' AS element, COUNT(*) AS nb FROM app_org.org_warehouse
 WHERE warehouse_code IN ('LIT01','LIT02')
UNION ALL SELECT 'LITOKO Magasins', COUNT(*) FROM app_pos.pos_terminal
 WHERE terminal_code IN ('LBZV01','LBZV02','LPNR01','LPNR02','LDLS01')
UNION ALL SELECT 'LITOKO Stock PNR', SUM(stock_qty) FROM inv_stock WHERE warehouse_code = 'LIT01'
UNION ALL SELECT 'LITOKO Stock BZV', SUM(stock_qty) FROM inv_stock WHERE warehouse_code = 'LIT02'
 ORDER BY 1;

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ LITOKO Pointe-Noire : 1 société, 2 dépôts, 5 magasins
PROMPT ══════════════════════════════════════════════════════════
EXIT;
