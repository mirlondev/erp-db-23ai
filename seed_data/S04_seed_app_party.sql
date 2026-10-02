-- ============================================================
-- S04 : Seed app_party — VERSION CORRIGÉE
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

CONNECT app_party/AppParty#2026@localhost:1521/FREEPDB1

PROMPT ===============================================================
PROMPT   SEED app_party
PROMPT ===============================================================

DELETE FROM party_bank;
DELETE FROM party_address;
DELETE FROM party;
DELETE FROM party_nature;
COMMIT;

PROMPT [1] Natures
INSERT INTO party_nature (nature_code, nature_name, nature_type, is_active) VALUES ('SFP', 'Client Star Foods PNR', 'CUSTOMER', TRUE);
INSERT INTO party_nature (nature_code, nature_name, nature_type, is_active) VALUES ('CL0', 'Client standard', 'CUSTOMER', TRUE);
INSERT INTO party_nature (nature_code, nature_name, nature_type, is_active) VALUES ('CPO', 'Compte divers', 'CUSTOMER', TRUE);
INSERT INTO party_nature (nature_code, nature_name, nature_type, is_active) VALUES ('FOU', 'Fournisseur', 'SUPPLIER', TRUE);
INSERT INTO party_nature (nature_code, nature_name, nature_type, is_active) VALUES ('PER', 'Personnel', 'EMPLOYEE', TRUE);

PROMPT [2] Clients (via sous-requête sur nature_code = 'SFP')
INSERT INTO party (party_code, party_name, nature_id, currency_code, phone, address_1, city_code, status, created_by)
SELECT 'SFP001', 'CLIENT DIVERS CASH STAR FOODS PNR', nature_id, 'XAF', NULL, NULL, 'BZV', 'ACTIVE', 'KAMAL'
  FROM party_nature WHERE nature_code = 'SFP';

INSERT INTO party (party_code, party_name, nature_id, currency_code, phone, address_1, city_code, status, created_by)
SELECT 'SFP002', 'CLIENT DIVERS CREDIT STAR FOODS PNR', nature_id, 'XAF', NULL, NULL, 'BZV', 'ACTIVE', 'KAMAL'
  FROM party_nature WHERE nature_code = 'SFP';

INSERT INTO party (party_code, party_name, nature_id, currency_code, phone, address_1, city_code, status, created_by)
SELECT 'SFP031', 'SHENG FENG', nature_id, 'XAF', '05-598-99-66', 'GRAND MARCHE, POINTE-NOIRE', 'PNR', 'ACTIVE', 'KAMAL'
  FROM party_nature WHERE nature_code = 'SFP';

INSERT INTO party (party_code, party_name, nature_id, currency_code, phone, address_1, city_code, status, created_by)
SELECT 'SFP033', 'OCEANICS', nature_id, 'XAF', '05-539-44-44', 'GRAND MARCHE, POINTE-NOIRE', 'PNR', 'ACTIVE', 'KAMAL'
  FROM party_nature WHERE nature_code = 'SFP';

INSERT INTO party (party_code, party_name, nature_id, currency_code, phone, address_1, city_code, status, created_by)
SELECT 'SFP034', 'DJAM-DJAM & FILS', nature_id, 'XAF', '04-414-43-28', 'GRAND MARCHE, POINTE-NOIRE', 'PNR', 'ACTIVE', 'KAMAL'
  FROM party_nature WHERE nature_code = 'SFP';

INSERT INTO party (party_code, party_name, nature_id, currency_code, phone, address_1, city_code, status, created_by)
SELECT 'SFP035', 'ESPOIR', nature_id, 'XAF', '05-089-49-44', 'FOND TIE TIE', 'PNR', 'ACTIVE', 'KAMAL'
  FROM party_nature WHERE nature_code = 'SFP';

INSERT INTO party (party_code, party_name, nature_id, currency_code, phone, address_1, city_code, status, created_by)
SELECT 'SFP037', 'MAPAKOU MAJOLIE (VI-JOHN)', nature_id, 'XAF', NULL, 'GRAND MARCHE, POINTE-NOIRE', 'PNR', 'ACTIVE', 'KAMAL'
  FROM party_nature WHERE nature_code = 'SFP';

INSERT INTO party (party_code, party_name, nature_id, currency_code, phone, address_1, city_code, status, created_by)
SELECT 'SFP051', 'N SAT CONGO', nature_id, 'XAF', '04-489-53-10', 'MONGO-KAMBA, TCHYSTERE', 'PNR', 'ACTIVE', 'KAMAL'
  FROM party_nature WHERE nature_code = 'SFP';

INSERT INTO party (party_code, party_name, nature_id, currency_code, phone, address_1, city_code, status, created_by)
SELECT 'SFP052', 'BOINADJI', nature_id, 'XAF', '06-507-15-10', 'MONGO-KAMBA, TCHYSTERE', 'PNR', 'ACTIVE', 'KAMAL'
  FROM party_nature WHERE nature_code = 'SFP';

INSERT INTO party (party_code, party_name, nature_id, currency_code, phone, address_1, city_code, status, created_by)
SELECT 'SFP054', 'ETS SOFIA SERVICES', nature_id, 'XAF', '05-559-6173', 'ZONE-GRAND MARCHE', 'PNR', 'ACTIVE', 'KAMAL'
  FROM party_nature WHERE nature_code = 'SFP';

INSERT INTO party (party_code, party_name, nature_id, currency_code, phone, address_1, city_code, status, created_by)
SELECT 'SFP055', 'HAYATE', nature_id, 'XAF', '04-419-04-04', 'GRAND MARCHE, POINTE-NOIRE', 'PNR', 'ACTIVE', 'KAMAL'
  FROM party_nature WHERE nature_code = 'SFP';

INSERT INTO party (party_code, party_name, nature_id, currency_code, phone, address_1, city_code, status, created_by)
SELECT 'SFP065', 'O.BEDDI', nature_id, 'XAF', '05-751-28-28', 'GRAND MARCHE, POINTE-NOIRE', 'PNR', 'ACTIVE', 'KAMAL'
  FROM party_nature WHERE nature_code = 'SFP';

INSERT INTO party (party_code, party_name, nature_id, currency_code, phone, address_1, city_code, status, created_by)
SELECT 'SFP067', 'SHANA', nature_id, 'XAF', '04-454-02-06', 'GRAND MARCHE, POINTE-NOIRE', 'PNR', 'ACTIVE', 'KAMAL'
  FROM party_nature WHERE nature_code = 'SFP';

INSERT INTO party (party_code, party_name, nature_id, currency_code, phone, address_1, city_code, status, created_by)
SELECT 'SFP003', 'ATHANASE', nature_id, 'XAF', '05-321-07-97', 'GRAND MARCHE, POINTE-NOIRE', 'PNR', 'ACTIVE', 'KAMAL'
  FROM party_nature WHERE nature_code = 'SFP';

INSERT INTO party (party_code, party_name, nature_id, currency_code, phone, address_1, city_code, status, created_by)
SELECT 'SFP042', 'MACECE TDL', nature_id, 'XAF', '05-650-43-29', 'FOND TIE TIE, POINTE-NOIRE', 'PNR', 'ACTIVE', 'KAMAL'
  FROM party_nature WHERE nature_code = 'SFP';

-- Section [3]
INSERT INTO party (party_code, party_name, nature_id, currency_code, is_misc, status, created_by)
SELECT 'CL0001', 'POS CASH ACCOUNT', nature_id, 'XAF', TRUE, 'ACTIVE', 'ADMIN'
  FROM party_nature WHERE nature_code = 'CPO';

INSERT INTO party (party_code, party_name, nature_id, currency_code, is_misc, status, created_by)
SELECT 'CL0005', 'TIMBRE ELECTRONIQUE CGO', nature_id, 'XAF', TRUE, 'ACTIVE', 'ADMIN'
  FROM party_nature WHERE nature_code = 'CPO';
  COMMIT;

-- Section [4]
INSERT INTO party (party_code, party_name, nature_id, currency_code, status, created_by)
SELECT 'MH', 'MH', nature_id, 'XAF', 'ACTIVE', 'ADMIN' FROM party_nature WHERE nature_code = 'CL0';
INSERT INTO party (party_code, party_name, nature_id, currency_code, status, created_by)
SELECT 'HONG KONG', 'HONG KONG', nature_id, 'XAF', 'ACTIVE', 'ADMIN' FROM party_nature WHERE nature_code = 'CL0';
INSERT INTO party (party_code, party_name, nature_id, currency_code, status, created_by)
SELECT 'EL BARAKA', 'EL BARAKA', nature_id, 'XAF', 'ACTIVE', 'ADMIN' FROM party_nature WHERE nature_code = 'CL0';
INSERT INTO party (party_code, party_name, nature_id, currency_code, status, created_by)
SELECT 'MARINI', 'MARINI', nature_id, 'XAF', 'ACTIVE', 'ADMIN' FROM party_nature WHERE nature_code = 'CL0';
COMMIT;

PROMPT [5] Validation
SELECT 'PARTY_NATURE' AS tbl, COUNT(*) AS nb FROM party_nature
UNION ALL SELECT 'PARTY',     COUNT(*) FROM party;

PROMPT ✅ S04 terminé
EXIT;
