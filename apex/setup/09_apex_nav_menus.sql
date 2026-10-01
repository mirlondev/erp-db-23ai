-- ============================================================
-- APEX SETUP 09 : Menus de navigation (5 apps) — REGAL
-- ============================================================
-- Définit 5 menus hiérarchiques (un par app) :
--   - M100_POS : Ventes / Sessions / Retours / Z caisse
--   - M200_STOCK : Stock / Transferts / Inventaires / Lots
--   - M300_ACHATS : Commandes / Réceptions / Fournisseurs
--   - M400_COMPTA : Écritures / Fiscal / Immobilisations
--   - M500_ADMIN : Users / Rôles / Sites / Paramètres
--
-- Stockage : table apex_nav_menu (compatible modèle APEX 26.1).
-- L'IDE APEX utilisera Shared Components → Lists pour chaque app.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF
WHENEVER SQLERROR CONTINUE

CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   APEX SETUP 09 — Menus navigation APEX
PROMPT ══════════════════════════════════════════════════════════

-- Drop propre
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE apex_nav_menu CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE apex_nav_menu (
  menu_id        NUMBER GENERATED ALWAYS AS IDENTITY,
  app_id         NUMBER(3)     NOT NULL,
  parent_id      NUMBER,                            -- null = racine
  seq            NUMBER(3)     NOT NULL,
  label          VARCHAR2(120) NOT NULL,
  target_page    NUMBER(5),                         -- APEX page #
  icon_css       VARCHAR2(80),                      -- classe fa-*
  required_role  VARCHAR2(50),                      -- REGAL_*
  is_active      BOOLEAN       DEFAULT TRUE,
  created_at     TIMESTAMP     DEFAULT SYSTIMESTAMP,
  CONSTRAINT pk_apex_nav_menu PRIMARY KEY (menu_id)
);

-- ============================================================
-- 1) Menu App 100 — POS / Ventes
-- ============================================================
PROMPT
PROMPT [1/5] Menu App 100 — POS / Ventes
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (100, NULL, 10, 'Tableau de bord',           1,   'fa-tachometer-alt',     'REGAL_CAISSIER');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (100, NULL, 20, 'Caisse en cours',           10,  'fa-cash-register',      'REGAL_CAISSIER');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (100, NULL, 30, 'Sessions de caisse',        20,  'fa-clock',              'REGAL_CAISSIER');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (100, NULL, 40, 'Historique tickets',        21,  'fa-receipt',            'REGAL_VENDEUR');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (100, NULL, 50, 'Retours / Avoirs',          30,  'fa-undo',               'REGAL_MANAGER');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (100, NULL, 60, 'Z de caisse / Clôture',     40,  'fa-file-invoice',       'REGAL_MANAGER');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (100, NULL, 70, 'Formats tickets',           50,  'fa-print',              'REGAL_ADMIN');
COMMIT;

-- ============================================================
-- 2) Menu App 200 — Stock / Transferts
-- ============================================================
PROMPT
PROMPT [2/5] Menu App 200 — Stock / Transferts
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (200, NULL, 10, 'Tableau de bord',           1,   'fa-tachometer-alt',     'REGAL_VENDEUR');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (200, NULL, 20, 'Stock par site',            10,  'fa-warehouse',          'REGAL_VENDEUR');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (200, NULL, 30, 'Mouvements',                11,  'fa-exchange-alt',       'REGAL_VENDEUR');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (200, NULL, 40, 'Transferts inter-dépôts',   20,  'fa-truck-loading',      'REGAL_MANAGER');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (200, NULL, 50, 'Inventaires physiques',     30,  'fa-clipboard-list',     'REGAL_MANAGER');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (200, NULL, 60, 'Lots / Péremption',         40,  'fa-boxes',              'REGAL_MANAGER');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (200, NULL, 70, 'Alertes stock bas',         50,  'fa-exclamation-triangle','REGAL_MANAGER');
COMMIT;

-- ============================================================
-- 3) Menu App 300 — Achats / Fournisseurs
-- ============================================================
PROMPT
PROMPT [3/5] Menu App 300 — Achats / Fournisseurs
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (300, NULL, 10, 'Tableau de bord',           1,   'fa-tachometer-alt',     'REGAL_MANAGER');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (300, NULL, 20, 'Bons de commande',          10,  'fa-file-signature',     'REGAL_MANAGER');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (300, NULL, 30, 'Réceptions',                 11,  'fa-truck',              'REGAL_MANAGER');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (300, NULL, 40, 'Fournisseurs',               20,  'fa-users',              'REGAL_VENDEUR');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (300, NULL, 50, 'Catalogue articles',         30,  'fa-tags',               'REGAL_VENDEUR');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (300, NULL, 60, 'Demandes de prix',           40,  'fa-question-circle',    'REGAL_MANAGER');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (300, NULL, 70, 'OTD fournisseur',            50,  'fa-chart-line',         'REGAL_MANAGER');
COMMIT;

-- ============================================================
-- 4) Menu App 400 — Comptabilité OHADA
-- ============================================================
PROMPT
PROMPT [4/5] Menu App 400 — Comptabilité OHADA / Fiscal
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (400, NULL, 10, 'Tableau de bord',           1,   'fa-tachometer-alt',     'REGAL_COMPTABLE');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (400, NULL, 20, 'Plan comptable OHADA',       10,  'fa-sitemap',            'REGAL_COMPTABLE');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (400, NULL, 30, 'Écritures',                  20,  'fa-pen',                'REGAL_COMPTABLE');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (400, NULL, 40, 'Journaux',                   30,  'fa-book',               'REGAL_COMPTABLE');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (400, NULL, 50, 'Lettrage',                   40,  'fa-link',               'REGAL_COMPTABLE');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (400, NULL, 60, 'Déclarations fiscales',       50,  'fa-file-invoice-dollar','REGAL_COMPTABLE');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (400, NULL, 70, 'TVA 18.9% CG',               51,  'fa-percent',            'REGAL_COMPTABLE');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (400, NULL, 80, 'IS / IRCM',                  52,  'fa-building',           'REGAL_COMPTABLE');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (400, NULL, 90, 'Immobilisations',            60,  'fa-cubes',              'REGAL_COMPTABLE');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (400, NULL, 100, 'Amortissements',            61,  'fa-chart-pie',          'REGAL_COMPTABLE');
COMMIT;

-- ============================================================
-- 5) Menu App 500 — Administration
-- ============================================================
PROMPT
PROMPT [5/5] Menu App 500 — Administration
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (500, NULL, 10, 'Tableau de bord',           1,   'fa-tachometer-alt',     'REGAL_ADMIN');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (500, NULL, 20, 'Utilisateurs',               10,  'fa-user',               'REGAL_ADMIN');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (500, NULL, 30, 'Rôles & permissions',        20,  'fa-key',                'REGAL_ADMIN');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (500, NULL, 40, 'Sites & topologie',          30,  'fa-map-marked-alt',     'REGAL_ADMIN');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (500, NULL, 50, 'Paramètres fiscal CG',       40,  'fa-cog',                'REGAL_ADMIN');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (500, NULL, 60, 'Catalogue marques',          50,  'fa-trademark',          'REGAL_ADMIN');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (500, NULL, 70, 'ETL legacy',                 60,  'fa-sync',               'REGAL_ADMIN');
INSERT INTO apex_nav_menu (app_id, parent_id, seq, label, target_page, icon_css, required_role) VALUES
  (500, NULL, 80, 'Audit & logs',               70,  'fa-shield-alt',         'REGAL_SUPERADMIN');
COMMIT;

-- ============================================================
-- 6) Vue apex_nav_menu_v pour APEX
-- ============================================================
PROMPT
PROMPT [6] Vue APEX-ready
CREATE OR REPLACE VIEW apex_nav_menu_v AS
SELECT m.menu_id,
       m.app_id,
       LEVEL AS depth,
       LPAD(' ', (LEVEL-1) * 2) || m.label AS label_indented,
       m.label,
       m.target_page,
       m.icon_css,
       m.required_role,
       CONNECT_BY_ISLEAF AS is_leaf,
       SYS_CONNECT_BY_PATH(m.label, ' / ') AS path
  FROM apex_nav_menu m
 WHERE m.is_active = 'Y'
 START WITH m.parent_id IS NULL
CONNECT BY PRIOR m.menu_id = m.parent_id
 ORDER SIBLINGS BY m.seq;

GRANT SELECT ON apex_nav_menu_v TO app_sys, app_sales, app_inv, app_purchase, app_gl;

PROMPT
PROMPT ═══ Validation ═══
SELECT app_id, COUNT(*) AS nb_items, MAX(depth) AS max_depth
  FROM apex_nav_menu_v GROUP BY app_id ORDER BY app_id;

PROMPT
PROMPT ═══ Aperçu menu 100 (POS) ═══
SELECT label_indented, target_page, icon_css, required_role
  FROM apex_nav_menu_v
 WHERE app_id = 100
 ORDER BY depth, label_indented;

PROMPT
PROMPT ═══ Aperçu menu 400 (Compta) ═══
SELECT label_indented, target_page, icon_css, required_role
  FROM apex_nav_menu_v
 WHERE app_id = 400
 ORDER BY depth, label_indented;

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ APEX SETUP 09 — 5 menus (33 entrées)
PROMPT   - 100 POS    : 7 entrées
PROMPT   - 200 Stock  : 7 entrées
PROMPT   - 300 Achats : 7 entrées
PROMPT   - 400 Compta : 10 entrées
PROMPT   - 500 Admin  : 8 entrées
PROMPT   - Vue apex_nav_menu_v avec hiérarchie CONNECT BY
PROMPT ══════════════════════════════════════════════════════════
EXIT;
