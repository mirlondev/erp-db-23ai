-- ============================================================
-- SCRIPT 48 : Module RH / Paie (5 tables app_hr)
-- ============================================================
-- 5 tables pour la gestion du personnel et de la paie :
--   app_hr.mpf_employee        : fiche salarié (compte OHADA classe 2)
--   app_hr.payroll_period     : période de paie (mensuelle / hebdomadaire)
--   app_hr.payroll_run        : cycle de paie (brouillon → validé)
--   app_hr.payroll_slip       : bulletin individuel par salarié par période
--   app_hr.payroll_slip_line  : ligne détail (base, taux, retenue, cotisation)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA

PROMPT ══════════════════════════════════════════════════════════
PROMPT   MODULE RH / PAIE (5 tables app_hr)
PROMPT ══════════════════════════════════════════════════════════

GRANT SELECT, INSERT ON app_party.party TO app_hr;
GRANT SELECT, INSERT ON app_org.org_company TO app_hr;



CONNECT app_hr/AppHr#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT [1/5] mpf_employee — fiche salarié (OHADA classe 2)
CREATE TABLE mpf_employee (
  employee_id            NUMBER GENERATED ALWAYS AS IDENTITY,
  matricule              VARCHAR2(20)  NOT NULL,             -- 'EMP-2026-001'
  party_code             VARCHAR2(32)  NOT NULL,             -- FK logique vers app_party.party
  company_code           VARCHAR2(12)  NOT NULL,
  full_name              VARCHAR2(120) NOT NULL,
  -- type de contrat / poste / classification OHADA
  contract_type          VARCHAR2(20)  DEFAULT 'CDI',         -- CDI | CDD | STAGE | INDEPENDANT | APPRENTI
  position               VARCHAR2(120),
  category               VARCHAR2(20)  DEFAULT 'AGENT',       -- OUVRIER | EMPLOYE | AGENT | CADRE | DIRIGEANT
  classification_level   NUMBER(2)     DEFAULT 1,            -- niveau 1-12 (convention collective)
  sector_code            VARCHAR2(20),                       -- branche professionnelle
  -- dates
  hire_date              DATE          NOT NULL,
  contract_end_date      DATE,                               -- fin CDD
  seniority_date         DATE,                               -- ancienneté
  termination_date       DATE,
  termination_reason     VARCHAR2(200),
  -- carrière
  manager_id             NUMBER,                            -- hiérarchie (auto-FK)
  location_code          VARCHAR2(20),                       -- poste/site
  warehouse_code         VARCHAR2(5),                        -- DEP01/DEP02 si ops
  -- paie
  monthly_salary_brut    NUMBER(16,4) NOT NULL,             -- salaire brut de base
  hourly_rate            NUMBER(16,4),                       -- taux horaire
  payment_method         VARCHAR2(20)  DEFAULT 'BANK_TRANSFER',
  bank_account           VARCHAR2(40),
  bank_code              VARCHAR2(20),
  -- CNPS / CNaPS / IPS / UC
  social_security_no     VARCHAR2(40),                       -- CNPS (BJ/CI/SN/TG/CI), CNaPS (MG)
  -- autres
  marital_status         VARCHAR2(20),                       -- SINGLE | MARRIED | DIVORCED | WIDOWED
  dependents_count       NUMBER(2)     DEFAULT 0,
  is_active              BOOLEAN       DEFAULT TRUE,
  -- audit
  created_by             VARCHAR2(20),
  created_at             TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_mpf_employee               PRIMARY KEY (employee_id),
  CONSTRAINT uk_mpf_employee_matricule     UNIQUE (matricule),
  CONSTRAINT fk_mpf_employee_manager       FOREIGN KEY (manager_id)
    REFERENCES mpf_employee(employee_id),
  CONSTRAINT ck_mpf_emp_contract           CHECK (contract_type IN ('CDI','CDD','STAGE','INDEPENDANT','APPRENTI','INTERIM')),
  CONSTRAINT ck_mpf_emp_category           CHECK (category IN ('OUVRIER','EMPLOYE','AGENT','CADRE','DIRIGEANT','TECHNICIEN')),
  CONSTRAINT ck_mpf_emp_marital            CHECK (marital_status IN ('SINGLE','MARRIED','DIVORCED','WIDOWED','UNION_LIBRE')),
  CONSTRAINT ck_mpf_emp_salary             CHECK (monthly_salary_brut >= 0)
);

CREATE INDEX ix_mpf_emp_company        ON mpf_employee(company_code, is_active);
CREATE INDEX ix_mpf_emp_party          ON mpf_employee(party_code);
CREATE INDEX ix_mpf_emp_manager        ON mpf_employee(manager_id);
CREATE INDEX ix_mpf_emp_hire_date      ON mpf_employee(hire_date);

PROMPT
PROMPT [2/5] payroll_period — périodes de paie
CREATE TABLE payroll_period (
  period_id              NUMBER GENERATED ALWAYS AS IDENTITY,
  period_code            VARCHAR2(20)  NOT NULL,              -- '2026-03-M'
  company_code           VARCHAR2(12)  NOT NULL,
  period_start           DATE          NOT NULL,
  period_end             DATE          NOT NULL,
  payment_date           DATE          NOT NULL,
  frequency              VARCHAR2(20)  DEFAULT 'MONTHLY',    -- MONTHLY | BIWEEKLY | WEEKLY | DAILY
  status                 VARCHAR2(20)  DEFAULT 'OPEN',        -- OPEN | DRAFT | CLOSED | LOCKED | PAID
  CONSTRAINT pk_payroll_period             PRIMARY KEY (period_id),
  CONSTRAINT uk_payroll_period_code        UNIQUE (period_code, company_code),
  CONSTRAINT ck_payroll_period_freq        CHECK (frequency IN ('MONTHLY','BIWEEKLY','WEEKLY','DAILY','QUARTERLY')),
  CONSTRAINT ck_payroll_period_status      CHECK (status IN ('OPEN','DRAFT','CLOSED','LOCKED','PAID','CANCELLED'))
);

CREATE INDEX ix_payroll_period_status    ON payroll_period(status);

PROMPT
PROMPT [3/5] payroll_run — cycles de paie
CREATE TABLE payroll_run (
  run_id                 NUMBER GENERATED ALWAYS AS IDENTITY,
  period_id              NUMBER        NOT NULL,
  run_number             NUMBER(4)     NOT NULL,              -- 1 (regular), 2 (overtime), 3 (mid-month)
  run_type               VARCHAR2(20)  DEFAULT 'REGULAR',     -- REGULAR | OVERTIME | MIDMONTH | ADJUSTMENT | TERMINATION
  started_at             TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  completed_at           TIMESTAMP,
  employee_count         NUMBER(5),
  total_brut             NUMBER(16,4)  DEFAULT 0,
  total_net              NUMBER(16,4)  DEFAULT 0,
  total_employer_cost    NUMBER(16,4)  DEFAULT 0,
  status                 VARCHAR2(20)  DEFAULT 'DRAFT',       -- DRAFT | VALIDATED | LOCKED | POSTED
  approved_by            VARCHAR2(20),
  approved_at            TIMESTAMP,
  CONSTRAINT pk_payroll_run                 PRIMARY KEY (run_id),
  CONSTRAINT uk_payroll_run_period_type     UNIQUE (period_id, run_number, run_type),
  CONSTRAINT fk_payroll_run_period          FOREIGN KEY (period_id)
    REFERENCES payroll_period(period_id) ON DELETE CASCADE,
  CONSTRAINT ck_payroll_run_type            CHECK (run_type IN ('REGULAR','OVERTIME','MIDMONTH','ADJUSTMENT','TERMINATION','BONUS')),
  CONSTRAINT ck_payroll_run_status          CHECK (status IN ('DRAFT','VALIDATED','LOCKED','POSTED','CANCELLED'))
);

PROMPT
PROMPT [4/5] payroll_slip — bulletin individuel
CREATE TABLE payroll_slip (
  slip_id                NUMBER GENERATED ALWAYS AS IDENTITY,
  run_id                 NUMBER        NOT NULL,
  employee_id            NUMBER        NOT NULL,
  period_id              NUMBER        NOT NULL,
  -- accumulés
  work_days              NUMBER(5,2)   DEFAULT 0,
  worked_hours           NUMBER(10,2)  DEFAULT 0,             -- heures travaillées
  overtime_hours         NUMBER(10,2)  DEFAULT 0,
  -- gains
  brut                   NUMBER(16,4)  DEFAULT 0,             -- salaire brut total
  primes                 NUMBER(16,4)  DEFAULT 0,
  overtime               NUMBER(16,4)  DEFAULT 0,
  -- retenues
  cnps_employee          NUMBER(16,4)  DEFAULT 0,             -- cotisation employé CNPS
  ipes_employee          NUMBER(16,4)  DEFAULT 0,             -- UEMOA prévoyance retraite
  irpp                   NUMBER(16,4)  DEFAULT 0,             -- impôt progressif retenu
  total_employee_cost    NUMBER(16,4)  DEFAULT 0,             -- = (brut + primes) - retenues employe
  net                    NUMBER(16,4)  DEFAULT 0,             -- = total_employee_cost (utilisé pour le net)
  -- charges patronales
  cnps_employer          NUMBER(16,4)  DEFAULT 0,             -- part patronale CNPS
  ipes_employer          NUMBER(16,4)  DEFAULT 0,
  total_employer_cost    NUMBER(16,4)  DEFAULT 0,
  -- compta
  gl_entry_id            NUMBER,                              -- écriture comptable
  payroll_slip_doc_id    NUMBER,                              -- bulletin PDF stocké
  -- workflow
  status                 VARCHAR2(20)  DEFAULT 'DRAFT',       -- DRAFT | VALIDATED | PAID | SENT
  paid_at                TIMESTAMP,
  CONSTRAINT pk_payroll_slip              PRIMARY KEY (slip_id),
  CONSTRAINT fk_payroll_slip_run          FOREIGN KEY (run_id)
    REFERENCES payroll_run(run_id) ON DELETE CASCADE,
  CONSTRAINT fk_payroll_slip_employee     FOREIGN KEY (employee_id)
    REFERENCES mpf_employee(employee_id),
  CONSTRAINT fk_payroll_slip_period       FOREIGN KEY (period_id)
    REFERENCES payroll_period(period_id),
  CONSTRAINT uk_payroll_slip_emp_period   UNIQUE (employee_id, period_id, run_id),
  CONSTRAINT ck_payroll_slip_status       CHECK (status IN ('DRAFT','VALIDATED','PAID','SENT','CANCELLED'))
);

CREATE INDEX ix_payroll_slip_run      ON payroll_slip(run_id);
CREATE INDEX ix_payroll_slip_emp      ON payroll_slip(employee_id, period_id);

PROMPT
PROMPT [5/5] payroll_slip_line — détail ligne bulletin
CREATE TABLE payroll_slip_line (
  line_id                NUMBER GENERATED ALWAYS AS IDENTITY,
  slip_id                NUMBER        NOT NULL,
  line_no                NUMBER(4)     NOT NULL,
  category               VARCHAR2(20)  NOT NULL,              -- GAIN | RETENUE | COTISATION | BONUS | DEDUCTION
  code                   VARCHAR2(20)  NOT NULL,              -- 'IRPP', 'CNPS', 'HEURES_SUP', 'PRIME'
  label                  VARCHAR2(120) NOT NULL,              -- libellé bulletin
  quantity               NUMBER(10,2)  DEFAULT 0,             -- base (heures, jours...)
  rate                   NUMBER(7,4),                         -- taux (0.05, 0.18, etc.)
  amount                 NUMBER(16,4)  NOT NULL,              -- montant final
  is_employer_part       BOOLEAN       DEFAULT FALSE,         -- TRUE = part patronale
  CONSTRAINT pk_payroll_slip_line           PRIMARY KEY (line_id),
  CONSTRAINT fk_payroll_slip_line_slip      FOREIGN KEY (slip_id)
    REFERENCES payroll_slip(slip_id) ON DELETE CASCADE,
  CONSTRAINT ck_payroll_slip_line_cat       CHECK (category IN ('GAIN','RETENUE','COTISATION','BONUS','DEDUCTION','CHARGES_PATRONALES')),
  CONSTRAINT uk_payroll_slip_line_order     UNIQUE (slip_id, line_no)
);

-- Vue bulletin simplifié
PROMPT
PROMPT [Vue pratique] v_payroll_bulletin
CREATE OR REPLACE VIEW v_payroll_bulletin AS
SELECT s.slip_id, s.run_id, e.matricule, e.full_name,
       c.company_code,
       p.period_code, p.period_start, p.period_end,
       s.work_days, s.worked_hours, s.overtime_hours,
       s.brut, s.primes, s.overtime,
       s.cnps_employee AS cnps_emp, s.cnps_employer AS cnps_patron, s.ipes_employee AS ipes_emp,
       s.irpp,
       s.net,
       s.total_employer_cost, s.status, s.paid_at
  FROM payroll_slip s
  JOIN mpf_employee e      ON e.employee_id = s.employee_id
  JOIN payroll_run r       ON r.run_id = s.run_id
  JOIN payroll_period p    ON p.period_id = s.period_id
  JOIN app_org.org_company c ON c.company_code = e.company_code
 ORDER BY p.period_start DESC, e.matricule;

-- Privilèges
CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA

GRANT SELECT ON app_hr.mpf_employee        TO app_api;
GRANT SELECT ON app_hr.payroll_period     TO app_api;
GRANT SELECT ON app_hr.payroll_run        TO app_api;
GRANT SELECT ON app_hr.payroll_slip       TO app_api;
GRANT SELECT ON app_hr.payroll_slip_line  TO app_api;
GRANT SELECT ON app_hr.payroll_slip       TO app_gl;
GRANT SELECT ON app_hr.payroll_run        TO app_gl;
GRANT SELECT ON app_hr.mpf_employee       TO app_ar;

PROMPT
PROMPT ═══ Validation ═══
CONNECT app_hr/AppHr#2026@localhost:1521/FREEPDB1
SELECT table_name, num_rows
  FROM user_tables
 WHERE table_name IN ('MPF_EMPLOYEE','PAYROLL_PERIOD','PAYROLL_RUN','PAYROLL_SLIP','PAYROLL_SLIP_LINE')
 ORDER BY table_name;

SELECT object_name, object_type, status
  FROM user_objects WHERE status = 'INVALID';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ MODULE RH / PAIE TERMINÉ (5 tables app_hr)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
