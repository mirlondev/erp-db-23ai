-- ============================================================
-- SCRIPT 04 : Schéma app_party (Clients / Fournisseurs)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON

CONNECT app_party/AppParty#2026@localhost:1521/FREEPDB1

PROMPT ═══════════════════════════════════════════════════════
PROMPT   CRÉATION DU SCHÉMA app_party
PROMPT ═══════════════════════════════════════════════════════

PROMPT [1] Table party_nature
CREATE TABLE party_nature (
  nature_id       NUMBER GENERATED ALWAYS AS IDENTITY,
  nature_code     VARCHAR2(12)  NOT NULL,
  nature_name     VARCHAR2(120) NOT NULL,
  nature_type     VARCHAR2(12),
  is_active       BOOLEAN       DEFAULT TRUE,
  CONSTRAINT pk_party_nature      PRIMARY KEY (nature_id),
  CONSTRAINT uk_party_nature_code UNIQUE (nature_code)
);

PROMPT [2] Table party
CREATE TABLE party (
  party_id            NUMBER GENERATED ALWAYS AS IDENTITY,
  party_code          VARCHAR2(32)  NOT NULL,
  party_name          VARCHAR2(50)  NOT NULL,
  nature_id           NUMBER        NOT NULL,
  currency_code       VARCHAR2(12),
  is_blocked          BOOLEAN       DEFAULT FALSE,
  is_misc             BOOLEAN       DEFAULT FALSE,
  tax_regime          VARCHAR2(12),
  payment_method      VARCHAR2(12),
  payment_terms       VARCHAR2(12),
  price_list_id       NUMBER,
  can_change_price    BOOLEAN       DEFAULT FALSE,
  can_change_unit_price BOOLEAN     DEFAULT FALSE,
  invoice_option      VARCHAR2(4),
  credit_limit        NUMBER(16,4),
  credit_days         NUMBER(3),
  address_1           VARCHAR2(120),
  address_2           VARCHAR2(120),
  address_3           VARCHAR2(120),
  address_4           VARCHAR2(120),
  postal_code         VARCHAR2(80),
  country             VARCHAR2(12),
  city_code           VARCHAR2(3),
  contact_name        VARCHAR2(120),
  contact_position    VARCHAR2(12),
  phone               VARCHAR2(60),
  fax                 VARCHAR2(120),
  email               VARCHAR2(120),
  website             VARCHAR2(120),
  tax_id              VARCHAR2(30),
  trade_register      VARCHAR2(30),
  bank_name           VARCHAR2(80),
  bank_code           VARCHAR2(40),
  bank_agency         VARCHAR2(80),
  bank_account        VARCHAR2(80),
  bank_key            VARCHAR2(80),
  iban                VARCHAR2(50),
  swift               VARCHAR2(50),
  status              VARCHAR2(10)  DEFAULT 'ACTIVE',
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  created_by          VARCHAR2(5),
  updated_at          TIMESTAMP,
  updated_by          VARCHAR2(5),
  CONSTRAINT pk_party             PRIMARY KEY (party_id),
  CONSTRAINT uk_party_code        UNIQUE (party_code),
  CONSTRAINT fk_party_nature      FOREIGN KEY (nature_id) 
    REFERENCES party_nature(nature_id),
  CONSTRAINT ck_party_status      CHECK (status IN ('ACTIVE','INACTIVE','DELETED'))
);

CREATE INDEX ix_party_name   ON party(party_name);
CREATE INDEX ix_party_nature ON party(nature_id);

PROMPT [3] Table party_address
CREATE TABLE party_address (
  address_id      NUMBER GENERATED ALWAYS AS IDENTITY,
  party_id        NUMBER        NOT NULL,
  address_code    VARCHAR2(4)   NOT NULL,
  party_name      VARCHAR2(120) NOT NULL,
  address_1       VARCHAR2(120),
  address_2       VARCHAR2(120),
  address_3       VARCHAR2(120),
  address_4       VARCHAR2(120),
  postal_code     VARCHAR2(80),
  country         VARCHAR2(12),
  city_code       VARCHAR2(3),
  contact_name    VARCHAR2(120),
  phone           VARCHAR2(120),
  fax             VARCHAR2(120),
  CONSTRAINT pk_party_address      PRIMARY KEY (address_id),
  CONSTRAINT uk_party_address_code UNIQUE (party_id, address_code),
  CONSTRAINT fk_party_address_party FOREIGN KEY (party_id) 
    REFERENCES party(party_id)
);

PROMPT [4] Table party_bank
CREATE TABLE party_bank (
  party_id        NUMBER        NOT NULL,
  bank_code       VARCHAR2(30)  NOT NULL,
  bank_name       VARCHAR2(50),
  bank_address    VARCHAR2(255),
  bank_account    VARCHAR2(50),
  iban            VARCHAR2(50),
  swift           VARCHAR2(50),
  beneficiary     VARCHAR2(50),
  CONSTRAINT pk_party_bank PRIMARY KEY (party_id, bank_code),
  CONSTRAINT fk_party_bank_party FOREIGN KEY (party_id) 
    REFERENCES party(party_id)
);

PROMPT
PROMPT [5] Insertion des données

INSERT INTO party_nature (nature_code, nature_name, nature_type)
VALUES ('CUSTOMER', 'Client', 'CUSTOMER');
INSERT INTO party_nature (nature_code, nature_name, nature_type)
VALUES ('SUPPLIER', 'Fournisseur', 'SUPPLIER');
INSERT INTO party_nature (nature_code, nature_name, nature_type)
VALUES ('EMPLOYEE', 'Employé', 'EMPLOYEE');

INSERT INTO party (party_code, party_name, nature_id, phone, email, address_1)
VALUES ('CLI001', 'Client Dupont', 1, '+225 01 02 03 04', 'dupont@example.com', 'Abidjan Plateau');
INSERT INTO party (party_code, party_name, nature_id, phone, email, address_1)
VALUES ('CLI002', 'Client Martin', 1, '+225 05 06 07 08', 'martin@example.com', 'Abidjan Cocody');
INSERT INTO party (party_code, party_name, nature_id, phone, email, address_1)
VALUES ('CLI003', 'Client Durand', 1, '+225 09 10 11 12', 'durand@example.com', 'Abidjan Yopougon');
INSERT INTO party (party_code, party_name, nature_id, phone, email, address_1)
VALUES ('FOU001', 'Fournisseur ABC', 2, '+225 13 14 15 16', 'contact@abc.com', 'Zone industrielle');
INSERT INTO party (party_code, party_name, nature_id, phone, email, address_1)
VALUES ('FOU002', 'Fournisseur XYZ', 2, '+225 17 18 19 20', 'contact@xyz.com', 'Zone industrielle');

COMMIT;

PROMPT
PROMPT [6] Validation
SELECT party_code, party_name, is_blocked, status
  FROM party
 WHERE is_blocked = FALSE;

SELECT COUNT(*) AS nb_party FROM party;

PROMPT ═══════════════════════════════════════════════════════
PROMPT   ✅ SCHÉMA app_party TERMINÉ
PROMPT ═══════════════════════════════════════════════════════