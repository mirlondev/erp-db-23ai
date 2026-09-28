-- ============================================================
-- PATCH script 38 : correction des INSERT gl_account_ohada
-- (ORA-00947 : not enough values)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF
SET SQLBLANKLINES ON

CONNECT app_gl/AppGl#2026@localhost:1521/FREEPDB1

PROMPT ============================================================
PROMPT   PATCH script 38 - reprise apres ORA-00947
PROMPT ============================================================

PROMPT
PROMPT === 1. Correction des 6 INSERT defectueux ===

-- 411000 Clients (manquait la valeur is_receivable)
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable)
VALUES ('411000', 'Clients', '4', FALSE, TRUE);

-- 411100 Clients ventes (manquait la valeur is_receivable)
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_receivable)
VALUES ('411100', 'Clients - ventes de marchandises', '4', TRUE, TRUE);

-- 411900 Clients RRR (manquait la valeur is_letterable)
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_letterable)
VALUES ('411900', 'Clients - RRR a obtenir', '4', TRUE, TRUE);

-- 401000 Fournisseurs (manquait la valeur is_payable)
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_payable)
VALUES ('401000', 'Fournisseurs', '4', FALSE, TRUE);

-- 401100 Fournisseurs achats (manquait la valeur is_payable)
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_payable)
VALUES ('401100', 'Fournisseurs - achats de marchandises', '4', TRUE, TRUE);

-- 530000 Caisse (manquait la valeur is_cash)
INSERT INTO gl_account_ohada (account_code, account_name, account_class, is_post, is_cash)
VALUES ('530000', 'Caisse', '5', TRUE, TRUE);

PROMPT
PROMPT === 2. Reprise des INSERT suivants (deja presents mais verifions) ===

-- Les autres INSERT (443000, 445000, 521000, 601000, etc.) sont corrects
-- et ont probablement reussi avant l'erreur. On ne les refait pas.

PROMPT
PROMPT === 3. Insertion des axes analytiques ===
INSERT INTO gl_cost_center_axis (axis_code, axis_name, axis_type, display_order)
VALUES ('AX_PROJ', 'Axes Projets', 'PROJECT', 10);

INSERT INTO gl_cost_center_axis (axis_code, axis_name, axis_type, display_order)
VALUES ('AX_ACT', 'Axes Activites', 'ACTIVITY', 20);

INSERT INTO gl_cost_center_axis (axis_code, axis_name, axis_type, display_order)
VALUES ('AX_DEP', 'Axes Departements', 'STANDARD', 30);

PROMPT
PROMPT === 4. Insertion des centres de cout ===

INSERT INTO gl_cost_center (cost_center_code, cost_center_name, parent_id, axis_id, manager_name, valid_from)
SELECT 'CC_DIRECTION', 'Direction Generale', NULL, id, 'DG', DATE '2026-01-01'
  FROM gl_cost_center_axis WHERE axis_code = 'AX_DEP';

INSERT INTO gl_cost_center (cost_center_code, cost_center_name, parent_id, axis_id, manager_name, valid_from)
SELECT 'CC_COMMERCIAL', 'Service Commercial', NULL, id, 'Directeur Commercial', DATE '2026-01-01'
  FROM gl_cost_center_axis WHERE axis_code = 'AX_DEP';

INSERT INTO gl_cost_center (cost_center_code, cost_center_name, parent_id, axis_id, manager_name, valid_from)
SELECT 'CC_LOGISTIQUE', 'Service Logistique', NULL, id, 'Responsable Logistique', DATE '2026-01-01'
  FROM gl_cost_center_axis WHERE axis_code = 'AX_DEP';

INSERT INTO gl_cost_center (cost_center_code, cost_center_name, parent_id, axis_id, manager_name, valid_from)
SELECT 'CC_MAGASIN_ABJ', 'Magasin Abidjan', NULL, id, 'Chef magasin Abidjan', DATE '2026-01-01'
  FROM gl_cost_center_axis WHERE axis_code = 'AX_DEP';

INSERT INTO gl_cost_center (cost_center_code, cost_center_name, parent_id, axis_id, manager_name, valid_from)
SELECT 'CC_MAGASIN_DKR', 'Magasin Dakar', NULL, id, 'Chef magasin Dakar', DATE '2026-01-01'
  FROM gl_cost_center_axis WHERE axis_code = 'AX_DEP';

COMMIT;

PROMPT
PROMPT === 5. Validation ===

SELECT account_class, COUNT(*) AS nb_comptes
  FROM gl_account_ohada
 GROUP BY account_class
 ORDER BY account_class;

SELECT ax.axis_code, cc.cost_center_code, cc.cost_center_name
  FROM gl_cost_center cc
  JOIN gl_cost_center_axis ax ON ax.axis_id = cc.axis_id
 ORDER BY ax.display_order, cc.cost_center_code;

SELECT object_name, object_type, status
  FROM user_objects
 WHERE status = 'INVALID';

PROMPT ============================================================
PROMPT   PATCH 38 TERMINE
PROMPT ============================================================
EXIT;