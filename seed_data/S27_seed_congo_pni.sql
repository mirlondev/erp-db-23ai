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
      company_code, company_name, country_code, currency_code,
      tax_id, rccm, address, city, postal_code, phone, email
    ) VALUES (
      'LITOKO', 'LITOKO SARL', 'CG', 'XAF',
      'CG-MF-MOYA-2017-001',  -- Numéro contribuable
      'RCCM-CG-PNR-01-2017-B-12345',  -- Registre du Commerce
      'Avenue Charles de Gaulle, Centre-ville',
      'Pointe-Noire',
      'BP 1234',
      '+242 05 555 0100',
      'contact@litoko.cg'
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

INSERT INTO org_warehouse (warehouse_code, company_code, warehouse_name, address, city,
                            is_active, is_main, surface_area_m2, manager_code)
VALUES ('DEP-PNR', 'LITOKO', 'Dépôt central Pointe-Noire',
        'Zone Industrielle, Route de l''Aéroport', 'Pointe-Noire',
        'Y', 'Y', 850, 'LIT-MGR-001');

INSERT INTO org_warehouse (warehouse_code, company_code, warehouse_name, address, city, is_active, is_main, surface_area_m2)
VALUES ('DEP-BZV', 'LITOKO', 'Dépôt secondaire Brazzaville',
        'Avenue de l''Indépendance, Zone portuaire', 'Brazzaville',
        'Y', 'N', 320);

COMMIT;

-- ═══ 3. Magasins LITOKO ═══
PROMPT
PROMPT ▸ Magasins LITOKO (Brazzaville, Pointe-Noire)

INSERT INTO app_pos.pos_terminal (terminal_code, terminal_name, company_code,
                                    warehouse_code, address, city, is_active, opened_at)
VALUES ('POS-BZV-01', 'Boutique LITOKO Brazzaville Centre', 'LITOKO',
        'DEP-BZV', 'Avenue de la Libération', 'Brazzaville', 'Y', SYSTIMESTAMP);

INSERT INTO app_pos.pos_terminal (terminal_code, terminal_name, company_code,
                                    warehouse_code, address, city, is_active, opened_at)
VALUES ('POS-BZV-02', 'Boutique LITOKO Poto-Poto', 'LITOKO',
        'DEP-BZV', 'Avenue Poto-Poto, Marché central', 'Brazzaville', 'Y', SYSTIMESTAMP);

INSERT INTO app_pos.pos_terminal (terminal_code, terminal_name, company_code,
                                    warehouse_code, address, city, is_active, opened_at)
VALUES ('POS-PNR-01', 'Boutique LITOKO Pointe-Noire Centre', 'LITOKO',
        'DEP-PNR', 'Avenue Charles de Gaulle', 'Pointe-Noire', 'Y', SYSTIMESTAMP);

INSERT INTO app_pos.pos_terminal (terminal_code, terminal_name, company_code,
                                    warehouse_code, address, city, is_active, opened_at)
VALUES ('POS-PNR-02', 'Boutique LITOKO Mpita', 'LITOKO',
        'DEP-PNR', 'Quartier Mpita, Marché', 'Pointe-Noire', 'Y', SYSTIMESTAMP);

INSERT INTO app_pos.pos_terminal (terminal_code, terminal_name, company_code,
                                    warehouse_code, address, city, is_active, opened_at)
VALUES ('POS-DLS-01', 'Boutique LITOKO Dolisie', 'LITOKO',
        'DEP-PNR', 'Avenue de l''Indépendance', 'Dolisie', 'Y', SYSTIMESTAMP);

COMMIT;
PROMPT 5 magasins LITOKO créés.

-- ═══ 4. Stock initial LITOKO — articles catalogue ═══
CONNECT app_inv/AppInv#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT ▸ Stock initial — Articles catalogue LITOKO

INSERT INTO inv_stock (warehouse_code, product_code, stock_qty, last_in_at)
SELECT 'DEP-PNR', p.product_code, 200, SYSDATE
  FROM app_product.product p
 WHERE p.is_active = 'Y';

INSERT INTO inv_stock (warehouse_code, product_code, stock_qty, last_in_at)
SELECT 'DEP-BZV', p.product_code, 100, SYSDATE
  FROM app_product.product p
 WHERE p.is_active = 'Y';

COMMIT;

PROMPT
PROMPT ═══ Volumétrie ═══
SELECT 'LITOKO Dépôts' AS element, COUNT(*) AS nb FROM app_org.org_warehouse WHERE company_code = 'LITOKO'
UNION ALL SELECT 'LITOKO Magasins',     COUNT(*) FROM app_pos.pos_terminal  WHERE company_code = 'LITOKO'
UNION ALL SELECT 'LITOKO Stock PNR',    SUM(stock_qty) FROM inv_stock WHERE warehouse_code = 'DEP-PNR'
UNION ALL SELECT 'LITOKO Stock BZV',    SUM(stock_qty) FROM inv_stock WHERE warehouse_code = 'DEP-BZV'
 ORDER BY 1;

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ LITOKO Pointe-Noire : 1 société, 2 dépôts, 5 magasins
PROMPT ══════════════════════════════════════════════════════════
EXIT;
