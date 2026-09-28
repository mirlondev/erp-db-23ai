-- ============================================================
-- SCRIPT 02 : Schéma app_org
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON

CONNECT app_org/AppOrg#2026@localhost:1521/FREEPDB1

PROMPT ═══════════════════════════════════════════════════════
PROMPT   CRÉATION DU SCHÉMA app_org
PROMPT ═══════════════════════════════════════════════════════

PROMPT [1] Table org_company
CREATE TABLE org_company (
  company_id      NUMBER GENERATED ALWAYS AS IDENTITY,
  company_code    VARCHAR2(12)  NOT NULL,
  company_name    VARCHAR2(120) NOT NULL,
  manager_name    VARCHAR2(120),
  address         VARCHAR2(1020),
  country_code    VARCHAR2(3),
  tax_rate        NUMBER(6,3),
  logo_file       VARCHAR2(255),
  created_at      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_org_company      PRIMARY KEY (company_id),
  CONSTRAINT uk_org_company_code UNIQUE (company_code)
);

PROMPT [2] Table org_warehouse
CREATE TABLE org_warehouse (
  warehouse_id    NUMBER GENERATED ALWAYS AS IDENTITY,
  warehouse_code  VARCHAR2(5)   NOT NULL,
  company_id      NUMBER        NOT NULL,
  warehouse_name  VARCHAR2(120) NOT NULL,
  is_sale_allowed BOOLEAN       DEFAULT TRUE,
  is_purch_allowed BOOLEAN      DEFAULT TRUE,
  warehouse_type  VARCHAR2(1),
  created_at      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_org_warehouse      PRIMARY KEY (warehouse_id),
  CONSTRAINT uk_org_warehouse_code UNIQUE (warehouse_code),
  CONSTRAINT fk_org_warehouse_company FOREIGN KEY (company_id) 
    REFERENCES org_company(company_id)
);

PROMPT [3] Table org_pos
CREATE TABLE org_pos (
  pos_id          NUMBER GENERATED ALWAYS AS IDENTITY,
  pos_code        VARCHAR2(3)   NOT NULL,
  pos_name        VARCHAR2(50)  NOT NULL,
  company_id      NUMBER,
  address         VARCHAR2(255),
  created_at      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_org_pos      PRIMARY KEY (pos_id),
  CONSTRAINT uk_org_pos_code UNIQUE (pos_code),
  CONSTRAINT fk_org_pos_company FOREIGN KEY (company_id) 
    REFERENCES org_company(company_id)
);

PROMPT
PROMPT [4] Insertion des données de base

INSERT INTO org_company (company_code, company_name, manager_name, country_code, tax_rate)
VALUES ('COMP01', 'Société Principale', 'Directeur Général', 'CIV', 18);

INSERT INTO org_warehouse (warehouse_code, company_id, warehouse_name, warehouse_type)
VALUES ('DEP01', 1, 'Dépôt principal', 'M');
INSERT INTO org_warehouse (warehouse_code, company_id, warehouse_name, warehouse_type)
VALUES ('DEP02', 1, 'Dépôt secondaire', 'D');

INSERT INTO org_pos (pos_code, pos_name, company_id, address)
VALUES ('01', 'Point de vente 1', 1, 'Abidjan');

COMMIT;

PROMPT
PROMPT [5] Validation
SELECT company_code, company_name, country_code FROM org_company;
SELECT warehouse_code, warehouse_name, is_sale_allowed FROM org_warehouse;
SELECT pos_code, pos_name FROM org_pos;

PROMPT ═══════════════════════════════════════════════════════
PROMPT   ✅ SCHÉMA app_org TERMINÉ
PROMPT ═══════════════════════════════════════════════════════