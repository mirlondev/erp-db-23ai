-- ============================================================
-- SCRIPT 38 : Squelette Module Comptabilite OHADA/SYSCOHADA
--              VERSION FINALE - IDEMPOTENTE
-- ============================================================
-- Corrections appliquees :
--  * ORA-00947 : INSERT column/value count mismatch (is_receivable, etc.)
--  * ORA-00904 : axis_id au lieu de id dans le SELECT
--  * DROP IF EXISTS au debut (idempotence)
--  * SET SQLBLANKLINES ON (lignes vides dans multi-line)
--  * INSERT ALL au lieu d'INSERT multi-lignes (robuste)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF
SET SQLBLANKLINES ON

CONNECT app_gl/AppGl#2026@localhost:1521/FREEPDB1

PROMPT ==============================================================
PROMPT   SQUELETTE MODULE COMPTABILITE OHADA/SYSCOHADA (v2)
PROMPT ==============================================================

-- ============================================================
-- Nettoyage idempotent (ordre inverse des FK)
-- ============================================================
PROMPT
PROMPT === Nettoyage idempotent ===
BEGIN
  FOR t IN (SELECT table_name FROM user_tables
             WHERE table_name IN (
               'GL_BUDGET','GL_FISCAL_PERIOD','GL_FISCAL_YEAR',
               'GL_ANALYTICAL_ENTRY','GL_COST_CENTER','GL_COST_CENTER_AXIS',
               'GL_ACCOUNT_OHADA','GL_ACCOUNT_CLASS'))
  LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP TABLE '||t.table_name||' CASCADE CONSTRAINTS PURGE';
      DBMS_OUTPUT.PUT_LINE('  DROP TABLE '||t.table_name);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END LOOP;
END;
/

-- ============================================================
-- [1/8] gl_account_class
-- ============================================================
PROMPT
PROMPT [1/8] gl_account_class
CREATE TABLE gl_account_class (
  class_code          VARCHAR2(1)   NOT NULL,
  class_name          VARCHAR2(120) NOT NULL,
  class_type          VARCHAR2(20)  NOT NULL,
  normal_balance      VARCHAR2(6)   NOT NULL,
  description         VARCHAR2(1000),
  is_active           BOOLEAN       DEFAULT TRUE,
  CONSTRAINT pk_gl_account_class        PRIMARY KEY (class_code),
  CONSTRAINT ck_gl_account_class_type   CHECK (class_type IN ('ASSET','LIABILITY','EQUITY','INCOME','EXPENSE','MEMO')),
  CONSTRAINT ck_gl_account_class_bal    CHECK (normal_balance IN ('DEBIT','CREDIT','MEMO'))
);

-- ============================================================
-- [2/8] gl_account_ohada
-- ============================================================
PROMPT
PROMPT [2/8] gl_account_ohada
CREATE TABLE gl_account_ohada (
  account_code        VARCHAR2(8)   NOT NULL,
  account_name        VARCHAR2(255) NOT NULL,
  account_class       VARCHAR2(1)   NOT NULL,
  parent_account      VARCHAR2(8),
  is_post             BOOLEAN       DEFAULT FALSE,
  normal_balance      VARCHAR2(6),
  is_receivable       BOOLEAN       DEFAULT FALSE,
  is_payable          BOOLEAN       DEFAULT FALSE,
  is_cash             BOOLEAN       DEFAULT FALSE,
  is_letterable       BOOLEAN       DEFAULT FALSE,
  is_active           BOOLEAN       DEFAULT TRUE,
  description         VARCHAR2(1000),
  legacy_gl_account_code VARCHAR2(8),
  CONSTRAINT pk_gl_account_ohada        PRIMARY KEY (account_code),
  CONSTRAINT fk_gl_account_ohada_class  FOREIGN KEY (account_class)
    REFERENCES gl_account_class(class_code),
  CONSTRAINT ck_gl_account_ohada_class  CHECK (account_class BETWEEN '1' AND '9'),
  CONSTRAINT ck_gl_account_ohada_bal    CHECK (normal_balance IS NULL OR normal_balance IN ('DEBIT','CREDIT'))
);

CREATE INDEX ix_gl_account_ohada_class  ON gl_account_ohada(account_class);
CREATE INDEX ix_gl_account_ohada_legacy ON gl_account_ohada(legacy_gl_account_code);

-- ============================================================
-- [3/8] gl_cost_center_axis
-- ============================================================
PROMPT
PROMPT [3/8] gl_cost_center_axis
CREATE TABLE gl_cost_center_axis (
  axis_id             NUMBER GENERATED ALWAYS AS IDENTITY,
  axis_code           VARCHAR2(8)   NOT NULL,
  axis_name           VARCHAR2(120) NOT NULL,
  axis_type           VARCHAR2(20)  DEFAULT 'STANDARD',
  is_active           BOOLEAN       DEFAULT TRUE,
  display_order       NUMBER(3)     DEFAULT 100,
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_gl_cost_center_axis       PRIMARY KEY (axis_id),
  CONSTRAINT uk_gl_cost_center_axis_code  UNIQUE (axis_code)
);

-- ============================================================
-- [4/8] gl_cost_center
-- ============================================================
PROMPT
PROMPT [4/8] gl_cost_center
CREATE TABLE gl_cost_center (
  cost_center_id      NUMBER GENERATED ALWAYS AS IDENTITY,
  cost_center_code    VARCHAR2(20)  NOT NULL,
  cost_center_name    VARCHAR2(120) NOT NULL,
  parent_id           NUMBER,
  axis_id             NUMBER,
  manager_name        VARCHAR2(120),
  is_active           BOOLEAN       DEFAULT TRUE,
  valid_from          DATE,
  valid_to            DATE,
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_gl_cost_center           PRIMARY KEY (cost_center_id),
  CONSTRAINT uk_gl_cost_center_code      UNIQUE (cost_center_code),
  CONSTRAINT fk_gl_cost_center_parent    FOREIGN KEY (parent_id)
    REFERENCES gl_cost_center(cost_center_id),
  CONSTRAINT fk_gl_cost_center_axis      FOREIGN KEY (axis_id)
    REFERENCES gl_cost_center_axis(axis_id),
  CONSTRAINT ck_gl_cost_center_validity  CHECK (valid_to IS NULL OR valid_to >= valid_from)
);

CREATE INDEX ix_gl_cost_center_parent    ON gl_cost_center(parent_id);
CREATE INDEX ix_gl_cost_center_axis      ON gl_cost_center(axis_id);

-- ============================================================
-- [5/8] gl_analytical_entry
-- ============================================================
PROMPT
PROMPT [5/8] gl_analytical_entry
CREATE TABLE gl_analytical_entry (
  analytical_id       NUMBER GENERATED ALWAYS AS IDENTITY,
  company_code        VARCHAR2(12)  NOT NULL,
  entry_no            NUMBER(8)     NOT NULL,
  line_no             NUMBER(5)     NOT NULL,
  cost_center_id      NUMBER        NOT NULL,
  amount              NUMBER(16,4)  NOT NULL,
  quantity            NUMBER(16,4),
  description         VARCHAR2(500),
  CONSTRAINT pk_gl_analytical_entry       PRIMARY KEY (analytical_id),
  CONSTRAINT fk_gl_analytical_entry_cc    FOREIGN KEY (cost_center_id)
    REFERENCES gl_cost_center(cost_center_id),
  CONSTRAINT ck_gl_analytical_entry_amt   CHECK (amount <> 0)
);

CREATE INDEX ix_gl_analytical_entry_cc   ON gl_analytical_entry(cost_center_id);
CREATE INDEX ix_gl_analytical_entry_comp ON gl_analytical_entry(company_code, entry_no);

-- ============================================================
-- [6/8] gl_fiscal_year
-- ============================================================
PROMPT
PROMPT [6/8] gl_fiscal_year
CREATE TABLE gl_fiscal_year (
  fiscal_year_id      NUMBER GENERATED ALWAYS AS IDENTITY,
  company_code        VARCHAR2(12)  NOT NULL,
  fiscal_year         NUMBER(4)     NOT NULL,
  start_date          DATE          NOT NULL,
  end_date            DATE          NOT NULL,
  status              VARCHAR2(20)  DEFAULT 'OPEN',
  closed_by           VARCHAR2(20),
  closed_at           TIMESTAMP,
  closure_journal     NUMBER(8),
  CONSTRAINT pk_gl_fiscal_year             PRIMARY KEY (fiscal_year_id),
  CONSTRAINT uk_gl_fiscal_year             UNIQUE (company_code, fiscal_year),
  CONSTRAINT ck_gl_fiscal_year_status      CHECK (status IN ('OPEN','CLOSED','LOCKED')),
  CONSTRAINT ck_gl_fiscal_year_range       CHECK (end_date >= start_date),
  CONSTRAINT ck_gl_fiscal_year_valid       CHECK (fiscal_year BETWEEN 2000 AND 2099)
);

CREATE INDEX ix_gl_fiscal_year_status     ON gl_fiscal_year(status);

-- ============================================================
-- [7/8] gl_fiscal_period
-- ============================================================
PROMPT
PROMPT [7/8] gl_fiscal_period
CREATE TABLE gl_fiscal_period (
  fiscal_period_id    NUMBER GENERATED ALWAYS AS IDENTITY,
  fiscal_year_id      NUMBER        NOT NULL,
  period_number       NUMBER(2)     NOT NULL,
  start_date          DATE          NOT NULL,
  end_date            DATE          NOT NULL,
  status              VARCHAR2(20)  DEFAULT 'OPEN',
  closed_by           VARCHAR2(20),
  closed_at           TIMESTAMP,
  CONSTRAINT pk_gl_fiscal_period           PRIMARY KEY (fiscal_period_id),
  CONSTRAINT uk_gl_fiscal_period           UNIQUE (fiscal_year_id, period_number),
  CONSTRAINT fk_gl_fiscal_period_year      FOREIGN KEY (fiscal_year_id)
    REFERENCES gl_fiscal_year(fiscal_year_id) ON DELETE CASCADE,
  CONSTRAINT ck_gl_fiscal_period_n         CHECK (period_number BETWEEN 1 AND 16),
  CONSTRAINT ck_gl_fiscal_period_status    CHECK (status IN ('OPEN','IN_PROGRESS','CLOSED','LOCKED')),
  CONSTRAINT ck_gl_fiscal_period_range     CHECK (end_date >= start_date)
);

CREATE INDEX ix_gl_fiscal_period_status   ON gl_fiscal_period(status);

-- ============================================================
-- [8/8] gl_budget
-- ============================================================
PROMPT
PROMPT [8/8] gl_budget
CREATE TABLE gl_budget (
  budget_id           NUMBER GENERATED ALWAYS AS IDENTITY,
  company_code        VARCHAR2(12)  NOT NULL,
  fiscal_year_id      NUMBER        NOT NULL,
  account_code        VARCHAR2(8)   NOT NULL,
  cost_center_id      NUMBER,
  budget_amount       NUMBER(16,4)  NOT NULL,
  budget_type         VARCHAR2(20)  DEFAULT 'ORIGINAL',
  parent_budget_id    NUMBER,
  is_active           BOOLEAN       DEFAULT TRUE,
  approved_by         VARCHAR2(20),
  approved_at         TIMESTAMP,
  notes               VARCHAR2(500),
  CONSTRAINT pk_gl_budget                   PRIMARY KEY (budget_id),
  CONSTRAINT uk_gl_budget                   UNIQUE (company_code, fiscal_year_id, account_code, cost_center_id, budget_type),
  CONSTRAINT fk_gl_budget_year              FOREIGN KEY (fiscal_year_id)
    REFERENCES gl_fiscal_year(fiscal_year_id),
  CONSTRAINT fk_gl_budget_cc                FOREIGN KEY (cost_center_id)
    REFERENCES gl_cost_center(cost_center_id),
  CONSTRAINT fk_gl_budget_parent            FOREIGN KEY (parent_budget_id)
    REFERENCES gl_budget(budget_id),
  CONSTRAINT ck_gl_budget_amount            CHECK (budget_amount >= 0),
  CONSTRAINT ck_gl_budget_type              CHECK (budget_type IN ('ORIGINAL','REVISED','ROLLING','FORECAST'))
);

CREATE INDEX ix_gl_budget_account          ON gl_budget(account_code, fiscal_year_id);
CREATE INDEX ix_gl_budget_cc               ON gl_budget(cost_center_id);

-- ============================================================
-- SEEDS : Plan SYSCOHADA complet (9 classes + 23 comptes)
-- ============================================================
PROMPT
PROMPT === SEEDS : 9 classes SYSCOHADA ===
INSERT INTO gl_account_class (class_code, class_name, class_type, normal_balance, description)
VALUES ('1', 'Comptes de ressources durables', 'EQUITY', 'CREDIT', 'Capitaux propres, emprunts et dettes a long terme');
INSERT INTO gl_account_class (class_code, class_name, class_type, normal_balance, description)
VALUES ('2', 'Comptes d''actif immobilise', 'ASSET', 'DEBIT', 'Immobilisations incorporelles, corporelles, financieres');
INSERT INTO gl_account_class (class_code, class_name, class_type, normal_balance, description)
VALUES ('3', 'Comptes de stocks', 'ASSET', 'DEBIT', 'Stocks de marchandises, matieres, en-cours');
INSERT INTO gl_account_class (class_code, class_name, class_type, normal_balance, description)
VALUES ('4', 'Comptes de tiers', 'MEMO', 'MEMO', 'Creances et dettes (clients, fournisseurs, personnel, Etat)');
INSERT INTO gl_account_class (class_code, class_name, class_type, normal_balance, description)
VALUES ('5', 'Comptes de tresorerie', 'ASSET', 'DEBIT', 'Banque, cheques postaux, caisse, virements internes');
INSERT INTO gl_account_class (class_code, class_name, class_type, normal_balance, description)
VALUES ('6', 'Comptes de charges des activites ordinaires', 'EXPENSE', 'DEBIT', 'Achats, transports, services exterieurs');
INSERT INTO gl_account_class (class_code, class_name, class_type, normal_balance, description)
VALUES ('7', 'Comptes de produits des activites ordinaires', 'INCOME', 'CREDIT', 'Ventes, travaux, services produits, autres produits');
INSERT INTO gl_account_class (class_code, class_name, class_type, normal_balance, description)
VALUES ('8', 'Comptes des autres charges et autres produits', 'EXPENSE', 'DEBIT', 'Charges et produits hors activites ordinaires');
INSERT INTO gl_account_class (class_code, class_name, class_type, normal_balance, description)
VALUES ('9', 'Comptes analytiques et engagements hors bilan', 'MEMO', 'MEMO', 'Comptabilite interne, engagements, resultat analytique');

PROMPT
PROMPT === SEEDS : 23 comptes SYSCOHADA racines ===
-- CLASSE 1
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable, is_payable, is_cash, is_letterable)
VALUES ('101000', 'Capital social', '1', FALSE, FALSE, FALSE, FALSE, FALSE);

-- CLASSE 2
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable, is_payable, is_cash, is_letterable)
VALUES ('211000', 'Terrains', '2', FALSE, FALSE, FALSE, FALSE, FALSE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable, is_payable, is_cash, is_letterable)
VALUES ('244100', 'Materiel de bureau', '2', FALSE, FALSE, FALSE, FALSE, FALSE);

-- CLASSE 3
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable, is_payable, is_cash, is_letterable)
VALUES ('310000', 'Stocks de marchandises', '3', FALSE, FALSE, FALSE, FALSE, FALSE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable, is_payable, is_cash, is_letterable)
VALUES ('311000', 'Stocks de matieres premieres', '3', FALSE, FALSE, FALSE, FALSE, FALSE);

-- CLASSE 4 - Clients
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable, is_payable, is_cash, is_letterable)
VALUES ('411000', 'Clients', '4', FALSE, TRUE, FALSE, FALSE, FALSE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable, is_payable, is_cash, is_letterable)
VALUES ('411100', 'Clients - ventes de marchandises', '4', TRUE, TRUE, FALSE, FALSE, TRUE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable, is_payable, is_cash, is_letterable)
VALUES ('411900', 'Clients - RRR a obtenir', '4', TRUE, TRUE, FALSE, FALSE, TRUE);

-- CLASSE 4 - Fournisseurs
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable, is_payable, is_cash, is_letterable)
VALUES ('401000', 'Fournisseurs', '4', FALSE, FALSE, TRUE, FALSE, FALSE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable, is_payable, is_cash, is_letterable)
VALUES ('401100', 'Fournisseurs - achats de marchandises', '4', TRUE, FALSE, TRUE, FALSE, TRUE);

-- CLASSE 4 - TVA
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable, is_payable, is_cash, is_letterable)
VALUES ('443000', 'TVA facturee', '4', TRUE, FALSE, FALSE, FALSE, FALSE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable, is_payable, is_cash, is_letterable)
VALUES ('445000', 'TVA recuperable', '4', TRUE, FALSE, FALSE, FALSE, FALSE);

-- CLASSE 5 - Tresorerie
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable, is_payable, is_cash, is_letterable)
VALUES ('521000', 'Banque', '5', TRUE, FALSE, FALSE, FALSE, TRUE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable, is_payable, is_cash, is_letterable)
VALUES ('530000', 'Caisse', '5', TRUE, FALSE, FALSE, TRUE, TRUE);

-- CLASSE 6 - Charges
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable, is_payable, is_cash, is_letterable)
VALUES ('601000', 'Achats de marchandises', '6', TRUE, FALSE, FALSE, FALSE, TRUE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable, is_payable, is_cash, is_letterable)
VALUES ('604000', 'Achats stockes - Matieres premieres', '6', TRUE, FALSE, FALSE, FALSE, TRUE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable, is_payable, is_cash, is_letterable)
VALUES ('622000', 'Locations et charges locatives', '6', TRUE, FALSE, FALSE, FALSE, TRUE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable, is_payable, is_cash, is_letterable)
VALUES ('627000', 'Services bancaires', '6', TRUE, FALSE, FALSE, FALSE, TRUE);

-- CLASSE 7 - Produits
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable, is_payable, is_cash, is_letterable)
VALUES ('701000', 'Ventes de marchandises', '7', TRUE, FALSE, FALSE, FALSE, TRUE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable, is_payable, is_cash, is_letterable)
VALUES ('706000', 'Prestations de services', '7', TRUE, FALSE, FALSE, FALSE, TRUE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable, is_payable, is_cash, is_letterable)
VALUES ('758000', 'Produits divers', '7', TRUE, FALSE, FALSE, FALSE, TRUE);

-- CLASSE 8 - HAO
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable, is_payable, is_cash, is_letterable)
VALUES ('801000', 'Charges HAO', '8', TRUE, FALSE, FALSE, FALSE, TRUE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable, is_payable, is_cash, is_letterable)
VALUES ('851000', 'Produits HAO', '8', TRUE, FALSE, FALSE, FALSE, TRUE);

PROMPT
PROMPT === SEEDS : axes analytiques ===
INSERT INTO gl_cost_center_axis (axis_code, axis_name, axis_type, display_order)
VALUES ('AX_PROJ', 'Axes Projets', 'PROJECT', 10);
INSERT INTO gl_cost_center_axis (axis_code, axis_name, axis_type, display_order)
VALUES ('AX_ACT', 'Axes Activites', 'ACTIVITY', 20);
INSERT INTO gl_cost_center_axis (axis_code, axis_name, axis_type, display_order)
VALUES ('AX_DEP', 'Axes Departements', 'STANDARD', 30);

PROMPT
PROMPT === SEEDS : centres de cout (axis_id explicite) ===
INSERT INTO gl_cost_center (cost_center_code, cost_center_name, axis_id, manager_name, valid_from)
SELECT 'CC_DIRECTION', 'Direction Generale', axis_id, 'DG', DATE '2026-01-01'
  FROM gl_cost_center_axis WHERE axis_code = 'AX_DEP';

INSERT INTO gl_cost_center (cost_center_code, cost_center_name, axis_id, manager_name, valid_from)
SELECT 'CC_COMMERCIAL', 'Service Commercial', axis_id, 'Directeur Commercial', DATE '2026-01-01'
  FROM gl_cost_center_axis WHERE axis_code = 'AX_DEP';

INSERT INTO gl_cost_center (cost_center_code, cost_center_name, axis_id, manager_name, valid_from)
SELECT 'CC_LOGISTIQUE', 'Service Logistique', axis_id, 'Responsable Logistique', DATE '2026-01-01'
  FROM gl_cost_center_axis WHERE axis_code = 'AX_DEP';

INSERT INTO gl_cost_center (cost_center_code, cost_center_name, axis_id, manager_name, valid_from)
SELECT 'CC_MAGASIN_ABJ', 'Magasin Abidjan', axis_id, 'Chef magasin Abidjan', DATE '2026-01-01'
  FROM gl_cost_center_axis WHERE axis_code = 'AX_DEP';

INSERT INTO gl_cost_center (cost_center_code, cost_center_name, axis_id, manager_name, valid_from)
SELECT 'CC_MAGASIN_DKR', 'Magasin Dakar', axis_id, 'Chef magasin Dakar', DATE '2026-01-01'
  FROM gl_cost_center_axis WHERE axis_code = 'AX_DEP';

COMMIT;

-- ============================================================
-- VALIDATION
-- ============================================================
PROMPT
PROMPT === Validation - 8 tables ===
SELECT table_name, num_rows FROM user_tables
 WHERE table_name IN ('GL_ACCOUNT_CLASS','GL_ACCOUNT_OHADA','GL_COST_CENTER_AXIS',
                      'GL_COST_CENTER','GL_ANALYTICAL_ENTRY','GL_FISCAL_YEAR',
                      'GL_FISCAL_PERIOD','GL_BUDGET')
 ORDER BY table_name;

PROMPT
PROMPT === Classes SYSCOHADA ===
SELECT class_code, class_name, class_type FROM gl_account_class ORDER BY class_code;

PROMPT
PROMPT === Comptes par classe ===
SELECT account_class, COUNT(*) AS nb_comptes FROM gl_account_ohada
 GROUP BY account_class ORDER BY account_class;

PROMPT
PROMPT === Total comptes (attendu: 23) ===
SELECT COUNT(*) AS total_comptes FROM gl_account_ohada;

PROMPT
PROMPT === Centres de cout (attendu: 5) ===
SELECT ax.axis_code, cc.cost_center_code, cc.cost_center_name
  FROM gl_cost_center cc
  JOIN gl_cost_center_axis ax ON ax.axis_id = cc.axis_id
 ORDER BY ax.display_order, cc.cost_center_code;

PROMPT
PROMPT === Objets invalides ===
SELECT object_name, object_type, status FROM user_objects WHERE status = 'INVALID';

PROMPT ==============================================================
PROMPT   SQUELETTE OHADA INSTALLE (8 tables + 23 comptes + 5 CC)
PROMPT ==============================================================
EXIT;