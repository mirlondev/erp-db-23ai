-- ============================================================
-- S21 : Seed LOT R13 (Sécurité avancée & Audit)
-- Données de démo : 6 rôles, 12 permissions, 35 role_permissions,
--                    3 assignations user↔role, 12 audit entries.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF

CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   SEED LOT R13 — Sécurité avancée & Audit
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [Reset tables R13]
BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM sys_audit_trail';
  EXECUTE IMMEDIATE 'DELETE FROM sys_role_permission';
  EXECUTE IMMEDIATE 'DELETE FROM sys_user_role';
  EXECUTE IMMEDIATE 'DELETE FROM sys_permission';
  EXECUTE IMMEDIATE 'DELETE FROM sys_role';
  COMMIT;
END;
/


PROMPT [1] 6 rôles applicatifs
INSERT INTO sys_role (role_code, role_name, description, role_level,
                      is_active, requires_mfa, max_session_minutes)
VALUES ('ADMIN', 'Administrateur', 'Accès total au système', 5,
        TRUE, TRUE, 480);

INSERT INTO sys_role (role_code, role_name, description, role_level,
                      is_active, requires_mfa, max_session_minutes)
VALUES ('MANAGER', 'Manager', 'Gestion opérationnelle - clients et reporting', 4,
        TRUE, FALSE, 600);

INSERT INTO sys_role (role_code, role_name, description, role_level,
                      is_active, requires_mfa, max_session_minutes)
VALUES ('CASHIER', 'Caissier', 'Ventes en caisse uniquement', 2,
        TRUE, FALSE, 480);

INSERT INTO sys_role (role_code, role_name, description, role_level,
                      is_active, requires_mfa, max_session_minutes)
VALUES ('STOCK', 'Gestionnaire de stock', 'Gestion inventaire et approvisionnement', 3,
        TRUE, FALSE, 480);

INSERT INTO sys_role (role_code, role_name, description, role_level,
                      is_active, requires_mfa, max_session_minutes)
VALUES ('ACCOUNT', 'Comptable', 'Facturation, règlements, compta', 3,
        TRUE, TRUE, 480);

INSERT INTO sys_role (role_code, role_name, description, role_level,
                      is_active, requires_mfa, max_session_minutes)
VALUES ('VIEWER', 'Consultation', 'Lecture seule, pas d''écriture', 1,
        TRUE, FALSE, 240);

PROMPT
PROMPT [2] 12 permissions atomiques
INSERT INTO sys_permission VALUES ('SALES_CREATE',     'Créer une vente',        'SALES',  'CREATE',   NULL, FALSE, FALSE, SYSTIMESTAMP);
INSERT INTO sys_permission VALUES ('SALES_CANCEL',     'Annuler une vente',      'SALES',  'CANCEL',   'Annulation ticket - sensible', TRUE, TRUE, SYSTIMESTAMP);
INSERT INTO sys_permission VALUES ('SALES_DISCOUNT',   'Appliquer remise',       'SALES',  'DISCOUNT', NULL, FALSE, FALSE, SYSTIMESTAMP);
INSERT INTO sys_permission VALUES ('STOCK_VIEW',       'Voir le stock',          'STOCK',  'READ',     NULL, FALSE, FALSE, SYSTIMESTAMP);
INSERT INTO sys_permission VALUES ('STOCK_ADJUST',     'Ajuster le stock',       'STOCK',  'UPDATE',   'Ajustement inventaire - sensible', TRUE, TRUE, SYSTIMESTAMP);
INSERT INTO sys_permission VALUES ('PRICE_EDIT',       'Modifier les prix',      'PRODUCT','UPDATE',   'Changement prix - sensible', TRUE, TRUE, SYSTIMESTAMP);
INSERT INTO sys_permission VALUES ('CUSTOMER_EDIT',    'Modifier les clients',   'PARTY',  'UPDATE',   NULL, FALSE, FALSE, SYSTIMESTAMP);
INSERT INTO sys_permission VALUES ('INVOICE_CREATE',   'Créer une facture',      'AR',     'CREATE',   NULL, FALSE, FALSE, SYSTIMESTAMP);
INSERT INTO sys_permission VALUES ('INVOICE_CANCEL',   'Annuler une facture',    'AR',     'CANCEL',   'Annulation facture - sensible', TRUE, TRUE, SYSTIMESTAMP);
INSERT INTO sys_permission VALUES ('PAYMENT_REGISTER', 'Enregistrer paiement',   'AR',     'CREATE',   NULL, FALSE, FALSE, SYSTIMESTAMP);
INSERT INTO sys_permission VALUES ('REPORT_VIEW',      'Voir les rapports',      'REPORT', 'READ',     NULL, FALSE, FALSE, SYSTIMESTAMP);
INSERT INTO sys_permission VALUES ('REPORT_EXPORT',    'Exporter des rapports',  'REPORT', 'EXPORT',   'Export de données', TRUE, TRUE, SYSTIMESTAMP);
INSERT INTO sys_permission VALUES ('USER_MANAGE',      'Gérer les utilisateurs', 'SYS',    'ADMIN',    NULL, TRUE, TRUE, SYSTIMESTAMP);
INSERT INTO sys_permission VALUES ('CONFIG_EDIT',      'Modifier la config',     'SYS',    'ADMIN',    NULL, TRUE, TRUE, SYSTIMESTAMP);
INSERT INTO sys_permission VALUES ('AUDIT_VIEW',       'Voir les logs d''audit', 'SYS',    'READ',     NULL, FALSE, FALSE, SYSTIMESTAMP);

PROMPT
PROMPT [3] Matrice role × permission
-- ADMIN : tout
INSERT INTO sys_role_permission (role_code, permission_code)
SELECT 'ADMIN', permission_code FROM sys_permission;

-- MANAGER : sales (lecture+cancel+discount), stock read, reports, clients
INSERT INTO sys_role_permission (role_code, permission_code)
SELECT 'MANAGER', permission_code FROM sys_permission
 WHERE action IN ('CREATE','CANCEL','DISCOUNT','READ','UPDATE','EXPORT');

-- CASHIER : juste CREATE vente + READ stock
INSERT INTO sys_role_permission (role_code, permission_code) VALUES ('CASHIER', 'SALES_CREATE');
INSERT INTO sys_role_permission (role_code, permission_code) VALUES ('CASHIER', 'STOCK_VIEW');

-- STOCK : stock view/adjust + reports
INSERT INTO sys_role_permission (role_code, permission_code) VALUES ('STOCK', 'STOCK_VIEW');
INSERT INTO sys_role_permission (role_code, permission_code) VALUES ('STOCK', 'STOCK_ADJUST');
INSERT INTO sys_role_permission (role_code, permission_code) VALUES ('STOCK', 'REPORT_VIEW');

-- ACCOUNT : AR + reports + audit view
INSERT INTO sys_role_permission (role_code, permission_code) VALUES ('ACCOUNT', 'INVOICE_CREATE');
INSERT INTO sys_role_permission (role_code, permission_code) VALUES ('ACCOUNT', 'INVOICE_CANCEL');
INSERT INTO sys_role_permission (role_code, permission_code) VALUES ('ACCOUNT', 'PAYMENT_REGISTER');
INSERT INTO sys_role_permission (role_code, permission_code) VALUES ('ACCOUNT', 'REPORT_VIEW');
INSERT INTO sys_role_permission (role_code, permission_code) VALUES ('ACCOUNT', 'REPORT_EXPORT');
INSERT INTO sys_role_permission (role_code, permission_code) VALUES ('ACCOUNT', 'AUDIT_VIEW');

-- VIEWER : read-only
INSERT INTO sys_role_permission (role_code, permission_code) VALUES ('VIEWER', 'STOCK_VIEW');
INSERT INTO sys_role_permission (role_code, permission_code) VALUES ('VIEWER', 'REPORT_VIEW');

PROMPT
PROMPT [4] 5 assignations user ↔ rôle
-- ADMIN user (id=1) a tous les rôles
INSERT INTO sys_user_role (user_id, role_code, assigned_by)
SELECT 1, role_code, 'SYSTEM' FROM sys_role;

-- Caissier 1 user (id=2) : juste CASHIER
INSERT INTO sys_user_role (user_id, role_code, assigned_by) VALUES (2, 'CASHIER', 'ADMIN');

-- Ajout d'utilisateurs supplémentaires pour le seed
INSERT INTO sys_user (user_code, user_name, password_hash, is_active, email)
VALUES ('MANAGER1', 'Manager Principal', 'hashed_xxx', TRUE, 'manager1@example.com');

INSERT INTO sys_user_role (user_id, role_code, assigned_by)
SELECT MAX(user_id), 'MANAGER', 'ADMIN' FROM sys_user WHERE user_code='MANAGER1';

INSERT INTO sys_user_role (user_id, role_code, assigned_by)
SELECT MAX(user_id), 'STOCK', 'ADMIN' FROM sys_user WHERE user_code='MANAGER1';

INSERT INTO sys_user (user_code, user_name, password_hash, is_active, email)
VALUES ('INVENTORY', 'Gestionnaire Stock', 'hashed_xxx', TRUE, 'inventory@example.com');

INSERT INTO sys_user_role (user_id, role_code, assigned_by)
SELECT MAX(user_id), 'STOCK', 'ADMIN' FROM sys_user WHERE user_code='INVENTORY';

PROMPT
PROMPT [5] 14 entrées d'audit (mix d'actions, dont 3 critiques)
INSERT INTO sys_audit_trail (user_code, user_role_at_time, action_type,
                              entity_type, entity_id, old_values, new_values,
                              ip_address, user_agent, session_id, severity)
VALUES ('ADMIN', 'ADMIN', 'LOGIN', 'sys_user', '1', NULL,
        JSON_OBJECT('logged_at' VALUE SYSTIMESTAMP),
        '192.168.1.10', 'Chrome 120', 'SESS-001', 'INFO');

INSERT INTO sys_audit_trail (user_code, user_role_at_time, action_type,
                              entity_type, entity_id, old_values, new_values,
                              ip_address, user_agent, session_id)
VALUES ('CAISSIER1', 'CASHIER', 'CREATE', 'app_sales.ticket', 'CAI01/1',
        NULL,
        JSON_OBJECT('total_ttc' VALUE 5000, 'customer' VALUE 'CLI001'),
        '192.168.1.20', 'POS-CAI01/Firefox', 'SESS-CAISS-001');

INSERT INTO sys_audit_trail (user_code, user_role_at_time, action_type,
                              entity_type, entity_id, old_values, new_values,
                              ip_address, user_agent, severity)
VALUES ('MANAGER1', 'MANAGER', 'CANCEL', 'app_sales.ticket', 'CAI01/2',
        JSON_OBJECT('status' VALUE 'V', 'total_ttc' VALUE 15000),
        JSON_OBJECT('status' VALUE 'A', 'cancel_reason' VALUE 'RET-2026-002'),
        '192.168.1.45', 'ManagerUI/Chrome', 'WARN');

INSERT INTO sys_audit_trail (user_code, user_role_at_time, action_type,
                              entity_type, entity_id, old_values, new_values,
                              ip_address, severity)
VALUES ('INVENTORY', 'STOCK', 'UPDATE', 'app_inv.inv_stock', 'DEP01/ART002',
        JSON_OBJECT('stock_qty' VALUE 500),
        JSON_OBJECT('stock_qty' VALUE 450, 'reason' VALUE 'Casse'),
        '192.168.1.55', 'INFO');

INSERT INTO sys_audit_trail (user_code, user_role_at_time, action_type,
                              entity_type, entity_id, new_values,
                              ip_address, user_agent, severity)
VALUES ('UNKNOWN_USER', NULL, 'LOGIN', 'sys_user', '0',
        JSON_OBJECT('attempt' VALUE 'failed', 'reason' VALUE 'invalid password'),
        '203.0.113.42', 'curl/8.4', 'CRITICAL');

INSERT INTO sys_audit_trail (user_code, user_role_at_time, action_type,
                              entity_type, entity_id, old_values, new_values,
                              ip_address, severity)
VALUES ('ADMIN', 'ADMIN', 'UPDATE', 'app_product.product', 'ART001',
        JSON_OBJECT('standard_price' VALUE 2500),
        JSON_OBJECT('standard_price' VALUE 2700, 'reason' VALUE 'Inflation'),
        '192.168.1.10', 'WARN');

INSERT INTO sys_audit_trail (user_code, user_role_at_time, action_type,
                              entity_type, entity_id, new_values,
                              ip_address)
VALUES ('ADMIN', 'ADMIN', 'CREATE', 'sys_role', 'AUDITOR',
        JSON_OBJECT('role_code' VALUE 'AUDITOR', 'role_level' VALUE 3),
        '192.168.1.10');

INSERT INTO sys_audit_trail (user_code, user_role_at_time, action_type,
                              entity_type, entity_id,
                              ip_address, severity)
VALUES ('CAISSIER1', 'CASHIER', 'LOGOUT', 'sys_user', '2',
        '192.168.1.20', 'INFO');

INSERT INTO sys_audit_trail (user_code, user_role_at_time, action_type,
                              entity_type, entity_id, new_values,
                              ip_address, user_agent, session_id, severity)
VALUES ('ACCOUNTANT', 'ACCOUNT', 'EXPORT', 'app_ar.invoice',
        'FA-2026-*',
        JSON_OBJECT('format' VALUE 'CSV', 'nb_records' VALUE 124, 'size_kb' VALUE 87),
        '192.168.1.60', 'Excel/2403', 'SESS-ACC-004', 'WARN');

INSERT INTO sys_audit_trail (user_code, user_role_at_time, action_type,
                              entity_type, entity_id,
                              ip_address, severity)
VALUES ('CAISSIER1', 'CASHIER', 'UPDATE', 'app_inv.inv_stock', 'DEP01/ART003',
        '192.168.1.20', 'INFO');

INSERT INTO sys_audit_trail (user_code, user_role_at_time, action_type,
                              entity_type, entity_id, old_values, new_values,
                              ip_address, severity)
VALUES ('MANAGER1', 'MANAGER', 'APPROVE', 'app_inv.inventory_adjustment', '1',
        JSON_OBJECT('status' VALUE 'PENDING', 'amount' VALUE 1800),
        JSON_OBJECT('status' VALUE 'APPROVED', 'approved_by' VALUE 'MANAGER1'),
        '192.168.1.45', 'INFO');

INSERT INTO sys_audit_trail (user_code, user_role_at_time, action_type,
                              entity_type, entity_id, new_values,
                              ip_address, severity)
VALUES ('ADMIN', 'ADMIN', 'CREATE', 'sys_user_role', '4/MANAGER',
        JSON_OBJECT('user_id' VALUE 4, 'role_code' VALUE 'MANAGER'),
        '192.168.1.10', 'INFO');

INSERT INTO sys_audit_trail (user_code, user_role_at_time, action_type,
                              entity_type, entity_id, new_values,
                              ip_address, severity)
VALUES ('ADMIN', 'ADMIN', 'CREATE', 'sys_user_role', '5/STOCK',
        JSON_OBJECT('user_id' VALUE 5, 'role_code' VALUE 'STOCK'),
        '192.168.1.10', 'INFO');

INSERT INTO sys_audit_trail (user_code, action_type,
                              entity_type, entity_id, new_values,
                              ip_address, severity)
VALUES ('INVENTORY', 'UPDATE', 'app_inv.inv_count_header', '1',
        JSON_OBJECT('status' VALUE 'VALIDATED'),
        '192.168.1.55', 'INFO');

COMMIT;

PROMPT
PROMPT ═══ Volumétrie ═══
SELECT 'SYS_ROLE'                 AS tbl, COUNT(*) AS nb FROM sys_role
UNION ALL SELECT 'SYS_USER_ROLE',           COUNT(*) FROM sys_user_role
UNION ALL SELECT 'SYS_PERMISSION',          COUNT(*) FROM sys_permission
UNION ALL SELECT 'SYS_ROLE_PERMISSION',     COUNT(*) FROM sys_role_permission
UNION ALL SELECT 'SYS_AUDIT_TRAIL',         COUNT(*) FROM sys_audit_trail
UNION ALL SELECT 'SYS_USER',                COUNT(*) FROM sys_user
 ORDER BY tbl;

PROMPT
PROMPT ═══ Démos / requêtes ═══

PROMPT [Q1] Matrice complète rôle × nb permissions
SELECT r.role_code, r.role_name, r.role_level,
       COUNT(rp.permission_code) AS nb_permissions
  FROM sys_role r
  LEFT JOIN sys_role_permission rp ON rp.role_code = r.role_code
 GROUP BY r.role_code, r.role_name, r.role_level
 ORDER BY r.role_level DESC, r.role_code;

PROMPT [Q2] Permissions par ressource
SELECT resource, COUNT(*) AS nb,
       LISTAGG(action, ',') WITHIN GROUP (ORDER BY action) AS actions
  FROM sys_permission
 GROUP BY resource
 ORDER BY resource;

PROMPT [Q3] Toutes les permissions d'un utilisateur
SELECT u.user_code, r.role_code, r.role_name,
       COUNT(rp.permission_code) AS nb_permissions,
       LISTAGG(rp.permission_code, ',') WITHIN GROUP (ORDER BY rp.permission_code) AS perms
  FROM sys_user u
  JOIN sys_user_role ur ON ur.user_id = u.user_id
  JOIN sys_role r ON r.role_code = ur.role_code
  LEFT JOIN sys_role_permission rp ON rp.role_code = r.role_code
 GROUP BY u.user_code, r.role_code, r.role_name
 ORDER BY u.user_code, r.role_code;

PROMPT [Q4] Permissions sensibles (audit renforcé)
SELECT permission_code, resource, action, is_sensitive, requires_approval
  FROM sys_permission
 WHERE is_sensitive = TRUE
 ORDER BY resource, action;

PROMPT [Q5] Activité utilisateur (admin)
SELECT user_code, COUNT(*) AS actions,
       SUM(CASE WHEN severity = 'CRITICAL' THEN 1 ELSE 0 END) AS critiques,
       SUM(CASE WHEN severity = 'WARN' THEN 1 ELSE 0 END) AS warnings,
       MAX(performed_at) AS derniere_action
  FROM sys_audit_trail
 GROUP BY user_code
 ORDER BY actions DESC;

PROMPT [Q6] Tentatives de connexion échouées (sécurité)
SELECT user_code, ip_address, user_agent, performed_at, severity,
       JSON_VALUE(new_values, '$.reason') AS raison_echec
  FROM sys_audit_trail
 WHERE action_type = 'LOGIN'
   AND severity = 'CRITICAL'
 ORDER BY performed_at DESC;

PROMPT [Q7] Toutes les actions sensibles récentes
SELECT user_code, action_type, entity_type, entity_id, severity, performed_at
  FROM sys_audit_trail
 WHERE severity IN ('WARN','CRITICAL')
 ORDER BY performed_at DESC
 FETCH FIRST 10 ROWS ONLY;

PROMPT [Q8] Rôles avec MFA obligatoire
SELECT role_code, role_name, requires_mfa, max_session_minutes
  FROM sys_role
 WHERE requires_mfa = TRUE
 ORDER BY role_code;

PROMPT [Q9] Permissions inutilisées (jamais assignées)
SELECT p.permission_code, p.resource, p.action
  FROM sys_permission p
 WHERE p.permission_code NOT IN (SELECT permission_code FROM sys_role_permission)
 ORDER BY p.resource, p.action;

PROMPT [Q10] Export par utilisateur (surveillance RGPD)
SELECT user_code, COUNT(*) AS nb_exports,
       MAX(performed_at) AS dernier_export,
       LISTAGG(DISTINCT entity_type, ',') WITHIN GROUP (ORDER BY entity_type) AS cibles
  FROM sys_audit_trail
 WHERE action_type = 'EXPORT'
 GROUP BY user_code
 ORDER BY nb_exports DESC;

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ SEED LOT R13 TERMINÉ
PROMPT ══════════════════════════════════════════════════════════
EXIT;
