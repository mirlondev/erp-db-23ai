-- ============================================================
-- SCRIPT 38 : Squelette Module Comptabilité OHADA/SYSCOHADA
-- Migration Oracle 11g (CP_*, GCPTIE*, GCEXP*) → 23ai/26ai (app_gl enrichi)
-- ============================================================
-- 8 nouvelles tables dans app_gl :
--   gl_account_class, gl_account_ohada (plan SYSCOHADA officiel),
--   gl_cost_center, gl_cost_center_axis, gl_analytical_entry
--   gl_fiscal_year, gl_fiscal_period, gl_budget
--
-- Le plan SYSCOHADA révisé est partiellement préchargé (comptes racines).
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

CONNECT app_gl/AppGl#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   SQUELETTE MODULE COMPTABILITÉ OHADA/SYSCOHADA
PROMPT ══════════════════════════════════════════════════════════


PROMPT
PROMPT [1/8] gl_account_class  — classes du plan comptable OHADA (1-9)
CREATE TABLE gl_account_class (
  class_code          VARCHAR2(1)   NOT NULL,             -- '1' = Ressources durables, '2' = Actif immobilisé ...
  class_name          VARCHAR2(120) NOT NULL,
  class_type          VARCHAR2(20)  NOT NULL,             -- ASSET | LIABILITY | EQUITY | INCOME | EXPENSE
  normal_balance      VARCHAR2(6)   NOT NULL,             -- DEBIT | CREDIT
  description         VARCHAR2(1000),
  is_active           BOOLEAN       DEFAULT TRUE,
  CONSTRAINT pk_gl_account_class        PRIMARY KEY (class_code),
  CONSTRAINT ck_gl_account_class_type   CHECK (class_type IN ('ASSET','LIABILITY','EQUITY','INCOME','EXPENSE','MEMO')),
  CONSTRAINT ck_gl_account_class_bal    CHECK (normal_balance IN ('DEBIT','CREDIT','MEMO'))
);

PROMPT
PROMPT [2/8] gl_account_ohada  — plan comptable officiel SYSCOHADA (référentiel)
CREATE TABLE gl_account_ohada (
  account_code        VARCHAR2(8)   NOT NULL,             -- ex. '411000', '401000', '701000'
  account_name        VARCHAR2(255) NOT NULL,             -- libellé officiel SYSCOHADA
  account_class       VARCHAR2(1)   NOT NULL,
  parent_account      VARCHAR2(8),                        -- compte parent (postes)
  is_post             BOOLEAN       DEFAULT FALSE,        -- TRUE = compte mouvementable
  normal_balance      VARCHAR2(6),
  is_receivable       BOOLEAN       DEFAULT FALSE,        -- client (411)
  is_payable          BOOLEAN       DEFAULT FALSE,        -- fournisseur (401)
  is_cash             BOOLEAN       DEFAULT FALSE,        -- trésorerie (5)
  is_letterable       BOOLEAN       DEFAULT FALSE,        -- lettrable
  is_active           BOOLEAN       DEFAULT TRUE,
  description         VARCHAR2(1000),
  -- Lien logique vers gl_account (mapping pays/commerce)
  legacy_gl_account_code VARCHAR2(8),                     -- ancien code dans l'ERP legacy
  CONSTRAINT pk_gl_account_ohada        PRIMARY KEY (account_code),
  CONSTRAINT fk_gl_account_ohada_class  FOREIGN KEY (account_class)
    REFERENCES gl_account_class(class_code),
  CONSTRAINT ck_gl_account_ohada_class  CHECK (account_class BETWEEN '1' AND '9'),
  CONSTRAINT ck_gl_account_ohada_bal    CHECK (normal_balance IS NULL OR normal_balance IN ('DEBIT','CREDIT'))
);

CREATE INDEX ix_gl_account_ohada_class  ON gl_account_ohada(account_class);
CREATE INDEX ix_gl_account_ohada_post    ON gl_account_ohada(is_post);
CREATE INDEX ix_gl_account_ohada_legacy ON gl_account_ohada(legacy_gl_account_code);

PROMPT
PROMPT [3/8] gl_cost_center_axis  — définition des axes analytiques
CREATE TABLE gl_cost_center_axis (
  axis_id             NUMBER GENERATED ALWAYS AS IDENTITY,
  axis_code           VARCHAR2(8)   NOT NULL,
  axis_name           VARCHAR2(120) NOT NULL,
  axis_type           VARCHAR2(20)  DEFAULT 'STANDARD',   -- STANDARD | PROJECT | ACTIVITY | OTHER
  is_active           BOOLEAN       DEFAULT TRUE,
  display_order       NUMBER(3)     DEFAULT 100,
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_gl_cost_center_axis       PRIMARY KEY (axis_id),
  CONSTRAINT uk_gl_cost_center_axis_code  UNIQUE (axis_code)
);

PROMPT
PROMPT [4/8] gl_cost_center  — centres de coût (sections analytiques)
CREATE TABLE gl_cost_center (
  cost_center_id      NUMBER GENERATED ALWAYS AS IDENTITY,
  cost_center_code    VARCHAR2(20)  NOT NULL,
  cost_center_name    VARCHAR2(120) NOT NULL,
  parent_id          NUMBER,                              -- hiérarchie
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
  CONSTRAINT ck_gl_cost_center_validity   CHECK (valid_to IS NULL OR valid_to >= valid_from)
);

CREATE INDEX ix_gl_cost_center_parent    ON gl_cost_center(parent_id);
CREATE INDEX ix_gl_cost_center_axis       ON gl_cost_center(axis_id);

PROMPT
PROMPT [5/8] gl_analytical_entry  — ventilation analytique des écritures
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
  CONSTRAINT fk_gl_analytical_entry_line  FOREIGN KEY (company_code, entry_no, line_no)
    REFERENCES gl_entry_line(company_code, entry_no, line_no) ON DELETE CASCADE,
  CONSTRAINT fk_gl_analytical_entry_cc    FOREIGN KEY (cost_center_id)
    REFERENCES gl_cost_center(cost_center_id),
  CONSTRAINT ck_gl_analytical_entry_amt   CHECK (amount <> 0)
);

CREATE INDEX ix_gl_analytical_entry_cc   ON gl_analytical_entry(cost_center_id);
CREATE INDEX ix_gl_analytical_entry_comp ON gl_analytical_entry(company_code, entry_no);

PROMPT
PROMPT [6/8] gl_fiscal_year  — exercices comptables
CREATE TABLE gl_fiscal_year (
  fiscal_year_id      NUMBER GENERATED ALWAYS AS IDENTITY,
  company_code        VARCHAR2(12)  NOT NULL,
  fiscal_year         NUMBER(4)     NOT NULL,
  start_date          DATE          NOT NULL,
  end_date            DATE          NOT NULL,
  status              VARCHAR2(20)  DEFAULT 'OPEN',       -- OPEN | CLOSED | LOCKED
  closed_by           VARCHAR2(20),
  closed_at           TIMESTAMP,
  closure_journal     NUMBER(8),                          -- pièce de clôture
  CONSTRAINT pk_gl_fiscal_year             PRIMARY KEY (fiscal_year_id),
  CONSTRAINT uk_gl_fiscal_year             UNIQUE (company_code, fiscal_year),
  CONSTRAINT ck_gl_fiscal_year_status      CHECK (status IN ('OPEN','CLOSED','LOCKED')),
  CONSTRAINT ck_gl_fiscal_year_range       CHECK (end_date >= start_date),
  CONSTRAINT ck_gl_fiscal_year_valid       CHECK (fiscal_year BETWEEN 2000 AND 2099)
);

CREATE INDEX ix_gl_fiscal_year_status     ON gl_fiscal_year(status);

PROMPT
PROMPT [7/8] gl_fiscal_period  — périodes mensuelles (12/exercice)
CREATE TABLE gl_fiscal_period (
  fiscal_period_id    NUMBER GENERATED ALWAYS AS IDENTITY,
  fiscal_year_id      NUMBER        NOT NULL,
  period_number       NUMBER(2)     NOT NULL,
  start_date          DATE          NOT NULL,
  end_date            DATE          NOT NULL,
  status              VARCHAR2(20)  DEFAULT 'OPEN',       -- OPEN | IN_PROGRESS | CLOSED | LOCKED
  closed_by           VARCHAR2(20),
  closed_at           TIMESTAMP,
  CONSTRAINT pk_gl_fiscal_period           PRIMARY KEY (fiscal_period_id),
  CONSTRAINT uk_gl_fiscal_period           UNIQUE (fiscal_year_id, period_number),
  CONSTRAINT fk_gl_fiscal_period_year      FOREIGN KEY (fiscal_year_id)
    REFERENCES gl_fiscal_year(fiscal_year_id) ON DELETE CASCADE,
  CONSTRAINT ck_gl_fiscal_period_n         CHECK (period_number BETWEEN 1 AND 16),     -- 12 normales + 4 clotures éventuelles
  CONSTRAINT ck_gl_fiscal_period_status    CHECK (status IN ('OPEN','IN_PROGRESS','CLOSED','LOCKED')),
  CONSTRAINT ck_gl_fiscal_period_range     CHECK (end_date >= start_date)
);

CREATE INDEX ix_gl_fiscal_period_status   ON gl_fiscal_period(status);

PROMPT
PROMPT [8/8] gl_budget  — budgets par compte/période/centre
CREATE TABLE gl_budget (
  budget_id           NUMBER GENERATED ALWAYS AS IDENTITY,
  company_code        VARCHAR2(12)  NOT NULL,
  fiscal_year_id      NUMBER        NOT NULL,
  account_code        VARCHAR2(8)   NOT NULL,
  cost_center_id      NUMBER,
  budget_amount       NUMBER(16,4)  NOT NULL,
  budget_type         VARCHAR2(20)  DEFAULT 'ORIGINAL',   -- ORIGINAL | REVISED | ROLLING
  parent_budget_id    NUMBER,                             -- pour révisions successives
  is_active           BOOLEAN       DEFAULT TRUE,
  approved_by         VARCHAR2(20),
  approved_at         TIMESTAMP,
  notes               VARCHAR2(500),
  CONSTRAINT pk_gl_budget                   PRIMARY KEY (budget_id),
  CONSTRAINT uk_gl_budget                   UNIQUE (company_code, fiscal_year_id, account_code, cost_center_id, budget_type),
  CONSTRAINT fk_gl_budget_year             FOREIGN KEY (fiscal_year_id)
    REFERENCES gl_fiscal_year(fiscal_year_id),
  CONSTRAINT fk_gl_budget_cc               FOREIGN KEY (cost_center_id)
    REFERENCES gl_cost_center(cost_center_id),
  CONSTRAINT fk_gl_budget_parent           FOREIGN KEY (parent_budget_id)
    REFERENCES gl_budget(budget_id),
  CONSTRAINT ck_gl_budget_amount           CHECK (budget_amount >= 0),
  CONSTRAINT ck_gl_budget_type             CHECK (budget_type IN ('ORIGINAL','REVISED','ROLLING','FORECAST'))
);

CREATE INDEX ix_gl_budget_account          ON gl_budget(account_code, fiscal_year_id);
CREATE INDEX ix_gl_budget_cc               ON gl_budget(cost_center_id);


PROMPT
PROMPT ═══ Données initiales — Plan SYSCOHADA (comptes racines) ═══
INSERT INTO gl_account_class (class_code, class_name, class_type, normal_balance, description)
VALUES ('1', 'Comptes de ressources durables',   'EQUITY',    'CREDIT', 'Capitaux propres, emprunts et dettes à long terme');
INSERT INTO gl_account_class (class_code, class_name, class_type, normal_balance, description)
VALUES ('2', 'Comptes d''actif immobilisé',     'ASSET',     'DEBIT',  'Immobilisations incorporelles, corporelles, financières');
INSERT INTO gl_account_class (class_code, class_name, class_type, normal_balance, description)
VALUES ('3', 'Comptes de stocks',               'ASSET',     'DEBIT',  'Stocks de marchandises, matières, en-cours');
INSERT INTO gl_account_class (class_code, class_name, class_type, normal_balance, description)
VALUES ('4', 'Comptes de tiers',                'MEMO',      'MEMO',   'Créances et dettes (clients, fournisseurs, personnel, État)');
INSERT INTO gl_account_class (class_code, class_name, class_type, normal_balance, description)
VALUES ('5', 'Comptes de trésorerie',           'ASSET',     'DEBIT',  'Banque, chèques postaux, caisse, virements internes');
INSERT INTO gl_account_class (class_code, class_name, class_type, normal_balance, description)
VALUES ('6', 'Comptes de charges des activités ordinaires', 'EXPENSE', 'DEBIT',  'Achats, transports, services extérieurs');
INSERT INTO gl_account_class (class_code, class_name, class_type, normal_balance, description)
VALUES ('7', 'Comptes de produits des activités ordinaires', 'INCOME',  'CREDIT', 'Ventes, travaux, services produits, autres produits');
INSERT INTO gl_account_class (class_code, class_name, class_type, normal_balance, description)
VALUES ('8', 'Comptes des autres charges et des autres produits', 'EXPENSE', 'DEBIT',  'Charges et produits hors activités ordinaires');
INSERT INTO gl_account_class (class_code, class_name, class_type, normal_balance, description)
VALUES ('9', 'Comptes de la comptabilité analytique de gestion — engagements hors bilan',
        'MEMO', 'MEMO', 'Comptabilité interne, engagements, résultat analytique');

PROMPT
PROMPT Insertion des comptes racines SYSCOHADA
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post)
VALUES ('101000', 'Capital social',                          '1', FALSE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post)
VALUES ('211000', 'Terrains',                                '2', FALSE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post)
VALUES ('244100', 'Matériel de bureau',                       '2', FALSE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post)
VALUES ('310000', 'Stocks de marchandises',                  '3', FALSE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post)
VALUES ('311000', 'Stocks de matières premières',             '3', FALSE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable)
VALUES ('411000', 'Clients',                                 '4', FALSE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable)
VALUES ('411100', 'Clients - ventes de marchandises',         '4', TRUE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_letterable)
VALUES ('411900', 'Clients - RRR à obtenir',                  '4', TRUE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_payable)
VALUES ('401000', 'Fournisseurs',                             '4', FALSE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_payable)
VALUES ('401100', 'Fournisseurs - achats de marchandises',     '4', TRUE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post)
VALUES ('443000', 'TVA facturée',                              '4', TRUE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post)
VALUES ('445000', 'TVA récupérable',                           '4', TRUE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post)
VALUES ('521000', 'Banque',                                    '5', TRUE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_cash)
VALUES ('530000', 'Caisse',                                    '5', TRUE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post)
VALUES ('601000', 'Achats de marchandises',                    '6', TRUE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post)
VALUES ('604000', 'Achats stockés - Matières premières',       '6', TRUE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post)
VALUES ('622000', 'Locations et charges locatives',            '6', TRUE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post)
VALUES ('627000', 'Services bancaires',                        '6', TRUE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post)
VALUES ('701000', 'Ventes de marchandises',                    '7', TRUE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post)
VALUES ('706000', 'Prestations de services',                   '7', TRUE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post)
VALUES ('758000', 'Produits divers',                           '7', TRUE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post)
VALUES ('801000', 'Charges HAO',                               '8', TRUE);
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post)
VALUES ('851000', 'Produits HAO',                              '8', TRUE);

PROMPT
PROMPT Insertion axes analytiques + centres de coût
INSERT INTO gl_cost_center_axis (axis_code, axis_name, axis_type, display_order)
VALUES ('AX_PROJ', 'Axes Projets',  'PROJECT', 10);
INSERT INTO gl_cost_center_axis (axis_code, axis_name, axis_type, display_order)
VALUES ('AX_ACT',  'Axes Activités', 'ACTIVITY', 20);
INSERT INTO gl_cost_center_axis (axis_code, axis_name, axis_type, display_order)
VALUES ('AX_DEP',  'Axes Départements', 'STANDARD', 30);

INSERT INTO gl_cost_center (cost_center_code, cost_center_name, parent_id, axis_id, manager_name, valid_from)
SELECT 'CC_DIRECTION',   'Direction Générale',     NULL, id, 'DG',            DATE '2026-01-01' FROM gl_cost_center_axis WHERE axis_code = 'AX_DEP'
UNION ALL
SELECT 'CC_COMMERCIAL',  'Service Commercial',     NULL, id, 'Directeur Commercial', DATE '2026-01-01' FROM gl_cost_center_axis WHERE axis_code = 'AX_DEP'
UNION ALL
SELECT 'CC_LOGISTIQUE',  'Service Logistique',      NULL, id, 'Responsable Logistique', DATE '2026-01-01' FROM gl_cost_center_axis WHERE axis_code = 'AX_DEP'
UNION ALL
SELECT 'CC_MAGASIN_ABJ', 'Magasin Abidjan',         NULL, id, 'Chef magasin Abidjan',  DATE '2026-01-01' FROM gl_cost_center_axis WHERE axis_code = 'AX_DEP'
UNION ALL
SELECT 'CC_MAGASIN_DKR', 'Magasin Dakar',           NULL, id, 'Chef magasin Dakar',    DATE '2026-01-01' FROM gl_cost_center_axis WHERE axis_code = 'AX_DEP';

COMMIT;

PROMPT
PROMPT ═══ Validation — Tables ═══
SELECT table_name, num_rows
  FROM user_tables
 WHERE table_name IN ('GL_ACCOUNT_CLASS','GL_ACCOUNT_OHADA','GL_COST_CENTER_AXIS',
                      'GL_COST_CENTER','GL_ANALYTICAL_ENTRY','GL_FISCAL_YEAR',
                      'GL_FISCAL_PERIOD','GL_BUDGET')
 ORDER BY table_name;

PROMPT
PROMPT [Validation] Contraintes
SELECT constraint_name, constraint_type, status
  FROM user_constraints
 WHERE table_name IN ('GL_ACCOUNT_CLASS','GL_ACCOUNT_OHADA','GL_COST_CENTER_AXIS',
                      'GL_COST_CENTER','GL_ANALYTICAL_ENTRY','GL_FISCAL_YEAR',
                      'GL_FISCAL_PERIOD','GL_BUDGET')
 ORDER BY table_name, constraint_name;

PROMPT
PROMPT [Validation] Classes et comptes par classe
SELECT class_code, class_name, class_type
  FROM gl_account_class
 ORDER BY class_code;

SELECT account_class, COUNT(*) AS nb_comptes
  FROM gl_account_ohada
 GROUP BY account_class
 ORDER BY account_class;

PROMPT
PROMPT [Validation] Centres de coût par axe
SELECT ax.axis_code, cc.cost_center_code, cc.cost_center_name
  FROM gl_cost_center cc
  JOIN gl_cost_center_axis ax ON ax.axis_id = cc.axis_id
 ORDER BY ax.display_order, cc.cost_center_code;

PROMPT
PROMPT [Validation] Objets invalides
SELECT object_name, object_type, status
  FROM user_objects
 WHERE status = 'INVALID';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ SQUELETTE OHADA INSTALLÉ (8 tables + plan SYSCOHADA seeds)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
