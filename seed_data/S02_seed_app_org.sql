-- ============================================================
-- S02 : Seed app_org — VERSION CORRIGÉE (IDs dynamiques)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

CONNECT app_org/AppOrg#2026@localhost:1521/FREEPDB1

PROMPT ===============================================================
PROMPT   SEED app_org — SUPER SONIC
PROMPT ===============================================================

DELETE FROM org_pos;
DELETE FROM org_warehouse;
DELETE FROM org_company;
COMMIT;

PROMPT [1] Société SUPER SONIC
INSERT INTO org_company (company_code, company_name, manager_name, address, country_code, tax_rate)
VALUES ('SS', 'STE SUPER SONIC', 'Direction Générale',
        'Avenue Charles de Gaulle, B.P. 4845, Pointe-Noire', 'CGO', 18.9);

PROMPT [2] Dépôts / Magasins (via sous-requêtes)
INSERT INTO org_warehouse (warehouse_code, company_id, warehouse_name, is_sale_allowed, is_purch_allowed, warehouse_type)
SELECT 'W90', company_id, 'Entrepôt principal Pointe-Noire', TRUE, TRUE, 'M'
  FROM org_company WHERE company_code = 'SS';

INSERT INTO org_warehouse (warehouse_code, company_id, warehouse_name, is_sale_allowed, is_purch_allowed, warehouse_type)
SELECT 'BZV', company_id, 'Magasin Brazzaville', TRUE, TRUE, 'M'
  FROM org_company WHERE company_code = 'SS';

INSERT INTO org_warehouse (warehouse_code, company_id, warehouse_name, is_sale_allowed, is_purch_allowed, warehouse_type)
SELECT 'PNR', company_id, 'Magasin Pointe-Noire', TRUE, TRUE, 'M'
  FROM org_company WHERE company_code = 'SS';

INSERT INTO org_warehouse (warehouse_code, company_id, warehouse_name, is_sale_allowed, is_purch_allowed, warehouse_type)
SELECT 'DOL', company_id, 'Magasin Dolisie', TRUE, TRUE, 'M'
  FROM org_company WHERE company_code = 'SS';

PROMPT [3] Points de vente
INSERT INTO org_pos (pos_code, pos_name, company_id, address)
SELECT 'SSP', 'SUPER SONIC PNR', company_id, 'Pointe-Noire - Grand Marché'
  FROM org_company WHERE company_code = 'SS';

INSERT INTO org_pos (pos_code, pos_name, company_id, address)
SELECT 'SS2', 'SUPER SONIC 2', company_id, 'Pointe-Noire'
  FROM org_company WHERE company_code = 'SS';

INSERT INTO org_pos (pos_code, pos_name, company_id, address)
SELECT 'SSB', 'SUPER SONIC BZV', company_id, 'Brazzaville'
  FROM org_company WHERE company_code = 'SS';

INSERT INTO org_pos (pos_code, pos_name, company_id, address)
SELECT 'S2B', 'SUPER SONIC 2 BZV', company_id, 'Brazzaville'
  FROM org_company WHERE company_code = 'SS';

INSERT INTO org_pos (pos_code, pos_name, company_id, address)
SELECT 'SS3', 'SUPER SONIC 3', company_id, 'Pointe-Noire'
  FROM org_company WHERE company_code = 'SS';

INSERT INTO org_pos (pos_code, pos_name, company_id, address)
SELECT 'SS4', 'SUPER SONIC 4', company_id, 'Pointe-Noire'
  FROM org_company WHERE company_code = 'SS';

INSERT INTO org_pos (pos_code, pos_name, company_id, address)
SELECT 'PP2', 'POS 2', company_id, 'Pointe-Noire'
  FROM org_company WHERE company_code = 'SS';

INSERT INTO org_pos (pos_code, pos_name, company_id, address)
SELECT 'PP3', 'POS 3', company_id, 'Pointe-Noire'
  FROM org_company WHERE company_code = 'SS';

INSERT INTO org_pos (pos_code, pos_name, company_id, address)
SELECT 'PMB', 'POS MB', company_id, 'Pointe-Noire'
  FROM org_company WHERE company_code = 'SS';

INSERT INTO org_pos (pos_code, pos_name, company_id, address)
SELECT 'RDP', 'POS RDP', company_id, 'Pointe-Noire'
  FROM org_company WHERE company_code = 'SS';

INSERT INTO org_pos (pos_code, pos_name, company_id, address)
SELECT 'PNS', 'POS PNS', company_id, 'Pointe-Noire'
  FROM org_company WHERE company_code = 'SS';

INSERT INTO org_pos (pos_code, pos_name, company_id, address)
SELECT 'PLU', 'POS PLU', company_id, 'Pointe-Noire'
  FROM org_company WHERE company_code = 'SS';

COMMIT;

PROMPT [4] Validation
SELECT 'SOCIETE'   AS tbl, COUNT(*) AS nb FROM org_company
UNION ALL SELECT 'ENTREPOT', COUNT(*) FROM org_warehouse
UNION ALL SELECT 'POS',      COUNT(*) FROM org_pos;

PROMPT ✅ S02 terminé
EXIT;