-- ============================================================
-- S19 : Seed LOT R11 (Alertes & Notifications)
-- Données de démo : 8 types d'alertes, 5 règles, 6 instances,
--                    4 canaux, 5 abonnements, 8 notifs en queue.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF

CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   SEED LOT R11 — Alertes & Notifications
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [Reset des tables R11]
BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM notification_queue';
  EXECUTE IMMEDIATE 'DELETE FROM notification_subscription';
  EXECUTE IMMEDIATE 'DELETE FROM notification_channel';
  EXECUTE IMMEDIATE 'DELETE FROM alert_instance';
  EXECUTE IMMEDIATE 'DELETE FROM alert_rule';
  EXECUTE IMMEDIATE 'DELETE FROM alert_type';
  COMMIT;
END;
/


PROMPT [1] 8 types d'alertes
INSERT INTO alert_type (alert_type_code, alert_type_name, category, severity,
                         auto_resolve, default_message, icon_code, display_color)
VALUES ('STOCK_LOW', 'Stock bas', 'STOCK', 'MEDIUM', FALSE,
        'Le stock du produit %s est inférieur au seuil minimum', 'stock-low', '#FFA500');

INSERT INTO alert_type (alert_type_code, alert_type_name, category, severity,
                         auto_resolve, default_message, icon_code, display_color)
VALUES ('STOCK_OUT', 'Rupture stock', 'STOCK', 'HIGH', FALSE,
        'Le produit %s est en rupture totale', 'stock-out', '#FF0000');

INSERT INTO alert_type (alert_type_code, alert_type_name, category, severity,
                         auto_resolve, default_message, icon_code, display_color)
VALUES ('INVOICE_OVERDUE', 'Facture en retard', 'BUSINESS', 'HIGH', FALSE,
        'La facture %s est en retard de %s jours', 'invoice-late', '#FF6347');

INSERT INTO alert_type (alert_type_code, alert_type_name, category, severity,
                         auto_resolve, default_message, icon_code, display_color)
VALUES ('CREDIT_LIMIT_EXCEEDED', 'Dépassement encours', 'BUSINESS', 'HIGH', FALSE,
        'Le client %s a dépassé son encours autorisé', 'credit-warn', '#DC143C');

INSERT INTO alert_type (alert_type_code, alert_type_name, category, severity,
                         auto_resolve, default_message, icon_code, display_color)
VALUES ('CASH_DRAWER_MISMATCH', 'Écart caisse', 'CASH', 'HIGH', FALSE,
        'Écart de %s XOF sur la session de caisse %s', 'cash-warn', '#FF4500');

INSERT INTO alert_type (alert_type_code, alert_type_name, category, severity,
                         auto_resolve, default_message, icon_code, display_color)
VALUES ('PRODUCT_EXPIRY_SOON', 'Expiration proche', 'INVENTORY', 'MEDIUM', FALSE,
        'Le lot %s du produit %s expire dans %s jours', 'calendar-warn', '#DAA520');

INSERT INTO alert_type (alert_type_code, alert_type_name, category, severity,
                         auto_resolve, default_message, icon_code, display_color)
VALUES ('PRICE_CHANGED', 'Changement de prix', 'SYSTEM', 'LOW', TRUE,
        'Le prix du produit %s a été modifié', 'price-tag', '#4682B4');

INSERT INTO alert_type (alert_type_code, alert_type_name, category, severity,
                         auto_resolve, default_message, icon_code, display_color)
VALUES ('SUSPICIOUS_LOGIN', 'Connexion suspecte', 'SECURITY', 'CRITICAL', FALSE,
        'Connexion depuis une IP inconnue pour l''utilisateur %s', 'shield-alert', '#8B0000');


PROMPT [2] 5 règles de détection
INSERT INTO alert_rule (rule_name, alert_type_code, condition_sql, threshold, comparison_op,
                        is_active, check_frequency, notify_roles, notify_emails,
                        cooldown_minutes, description, created_by)
VALUES ('Stock sous le minimum',
        'STOCK_LOW',
        'SELECT 1 FROM app_inv.inv_stock s JOIN app_product.product p ON p.product_code=s.product_code WHERE s.stock_qty < p.min_stock_qty',
        NULL, NULL,
        TRUE, 'HOURLY', 'MANAGER,INVENTORY',
        'manager@example.com,inventory@example.com',
        60, 'Détecte tous les produits dont le stock passe sous le minimum',
        'ADMIN');

INSERT INTO alert_rule (rule_name, alert_type_code, threshold, comparison_op,
                        is_active, check_frequency, notify_roles, notify_emails,
                        cooldown_minutes, description, created_by)
VALUES ('Factures en retard > 30j',
        'INVOICE_OVERDUE',
        30, '>',
        TRUE, 'DAILY', 'ACCOUNTANT,MANAGER',
        'compta@example.com',
        1440, 'Toute facture non payée à 30j du due_date',
        'ADMIN');

INSERT INTO alert_rule (rule_name, alert_type_code, condition_sql,
                        is_active, check_frequency, notify_roles, notify_emails,
                        cooldown_minutes, description, created_by)
VALUES ('Détection rupture stock',
        'STOCK_OUT',
        'SELECT 1 FROM app_inv.inv_stock WHERE stock_qty <= 0',
        TRUE, 'REALTIME', 'MANAGER',
        'manager@example.com',
        30, 'Alerte instantanée sur stock = 0',
        'ADMIN');

INSERT INTO alert_rule (rule_name, alert_type_code, threshold, comparison_op,
                        is_active, check_frequency, notify_roles,
                        cooldown_minutes, description, created_by)
VALUES ('Écart caisse > 1000 XOF',
        'CASH_DRAWER_MISMATCH',
        1000, '>',
        TRUE, 'HOURLY', 'MANAGER',
        60, 'Détection écart de caisse supérieur à 1000 XOF',
        'ADMIN');

INSERT INTO alert_rule (rule_name, alert_type_code, threshold, comparison_op,
                        is_active, check_frequency, notify_roles, notify_emails,
                        cooldown_minutes, description, created_by)
VALUES ('Lot expirant sous 7j',
        'PRODUCT_EXPIRY_SOON',
        7, '<',
        TRUE, 'DAILY', 'INVENTORY',
        'inventory@example.com',
        1440, 'Lots dont la date d''expiration est dans moins de 7 jours',
        'ADMIN');


PROMPT [3] 6 instances d'alertes (déjà déclenchées)
INSERT INTO alert_instance (alert_type_code, rule_id, entity_type, entity_id, entity_label,
                            message, severity, status, triggered_at,
                            acknowledged_at, acknowledged_by,
                            payload)
VALUES ('STOCK_LOW', 1, 'PRODUCT', 'ART003', 'Clé USB 32 Go',
        'Le stock de Clé USB 32 Go (40 unités) est inférieur au seuil minimum (50)',
        'MEDIUM', 'OPEN', SYSDATE - 1,
        NULL, NULL,
        JSON_OBJECT('current_stock' VALUE 40, 'min_stock' VALUE 50, 'warehouse' VALUE 'DEP01'));

INSERT INTO alert_instance (alert_type_code, rule_id, entity_type, entity_id, entity_label,
                            message, severity, status, triggered_at,
                            acknowledged_at, acknowledged_by, resolved_at, resolved_by, resolution_notes)
VALUES ('INVOICE_OVERDUE', 2, 'INVOICE', 'FA-2026-003', 'Facture FA-2026-003',
        'La facture FA-2026-003 est en retard de 30 jours',
        'HIGH', 'RESOLVED', SYSDATE - 30,
        SYSDATE - 28, 'MANAGER1', SYSDATE - 25, 'MANAGER1',
        'Plan de paiement convenu avec le client');

INSERT INTO alert_instance (alert_type_code, rule_id, entity_type, entity_id, entity_label,
                            message, severity, status, triggered_at,
                            acknowledged_at, acknowledged_by,
                            payload)
VALUES ('CREDIT_LIMIT_EXCEEDED', NULL, 'PARTY', 'CLI003', 'Client Durand',
        'Le client Client Durand a dépassé son encours autorisé (25000 > 20000)',
        'HIGH', 'ACK', SYSDATE - 2,
        SYSDATE - 1, 'MANAGER1',
        JSON_OBJECT('limit' VALUE 20000, 'current' VALUE 25000));

INSERT INTO alert_instance (alert_type_code, rule_id, entity_type, entity_id, entity_label,
                            message, severity, status, triggered_at,
                            payload)
VALUES ('PRODUCT_EXPIRY_SOON', 5, 'LOT', 'LOT-2026-001-A', 'Cahier 200p LOT-2026-001-A',
        'Le lot LOT-2026-001-A expire dans 100 jours',
        'MEDIUM', 'OPEN', SYSDATE - 5,
        JSON_OBJECT('expiry_date' VALUE '2027-01-15', 'days_remaining' VALUE 100));

INSERT INTO alert_instance (alert_type_code, rule_id, entity_type, entity_id, entity_label,
                            message, severity, status, triggered_at, resolved_at, resolved_by, resolution_notes)
VALUES ('STOCK_OUT', 3, 'PRODUCT', 'ART005', 'Produit ART005',
        'Le produit ART005 est en rupture totale',
        'HIGH', 'RESOLVED', SYSDATE - 10,
        SYSDATE - 8, 'INVENTORY', 'Réappro effectuée - 200 unités en stock');

INSERT INTO alert_instance (alert_type_code, entity_type, entity_id, entity_label,
                            message, severity, status, triggered_at, resolved_at, resolved_by)
VALUES ('PRICE_CHANGED', 'PRODUCT', 'ART002', 'Stylo bleu',
        'Le prix du produit Stylo bleu a été modifié (500 → 550)',
        'LOW', 'RESOLVED', SYSDATE - 15, SYSDATE - 15, 'SYSTEM');


PROMPT [4] 4 canaux de notification
INSERT INTO notification_channel (channel_code, channel_name, channel_type,
                                  config_json, is_active, rate_limit_per_hour, description)
VALUES ('EMAIL_MAIN', 'Email principal', 'EMAIL',
        JSON_OBJECT('smtp_host' VALUE 'smtp.example.com', 'smtp_port' VALUE 587, 'use_tls' VALUE true, 'from' VALUE 'noreply@example.com'),
        TRUE, 1000, 'Canal SMTP principal (notifications transactionnelles)');

INSERT INTO notification_channel (channel_code, channel_name, channel_type,
                                  config_json, is_active, rate_limit_per_hour, description)
VALUES ('SMS_TWILIO', 'SMS via Twilio', 'SMS',
        JSON_OBJECT('account_sid' VALUE 'ACxxxxxxxx', 'from_number' VALUE '+225000000'),
        TRUE, 500, 'Canal SMS (alertes critiques uniquement)');

INSERT INTO notification_channel (channel_code, channel_name, channel_type,
                                  config_json, is_active, description)
VALUES ('PUSH_FCM', 'Push mobile (Firebase)', 'PUSH',
        JSON_OBJECT('project_id' VALUE 'erp-mobile-app', 'service_account' VALUE 'svc-acct.json'),
        TRUE, 'Push notifications mobile app');

INSERT INTO notification_channel (channel_code, channel_name, channel_type,
                                  config_json, is_active, description)
VALUES ('UI_BELL', 'Cloche UI', 'UI',
        JSON_OBJECT('real_time' VALUE true, 'persist_hours' VALUE 24),
        TRUE, 'Badge cloche dans l''interface web');


PROMPT [5] 5 abonnements
INSERT INTO notification_subscription (user_code, channel_id, alert_type_code, destination,
                                       is_active, quiet_hours_start, quiet_hours_end, priority_min)
VALUES ('ADMIN', 1, NULL, 'admin@example.com',
        TRUE, 2200, 700, 'LOW');

INSERT INTO notification_subscription (user_code, channel_id, alert_type_code, destination,
                                       is_active, quiet_hours_start, quiet_hours_end, priority_min)
VALUES ('MANAGER1', 1, NULL, 'manager1@example.com',
        TRUE, 2000, 800, 'MEDIUM');

INSERT INTO notification_subscription (user_code, channel_id, alert_type_code, destination,
                                       is_active, quiet_hours_start, quiet_hours_end, priority_min)
VALUES ('MANAGER1', 2, 'STOCK_OUT', '+225070000001',
        TRUE, NULL, NULL, 'HIGH');

INSERT INTO notification_subscription (user_code, channel_id, alert_type_code, destination,
                                       is_active, priority_min)
VALUES ('INVENTORY', 4, NULL, 'INVENTORY',
        TRUE, 'LOW');

INSERT INTO notification_subscription (user_code, channel_id, alert_type_code, destination,
                                       is_active, priority_min)
VALUES ('ACCOUNTANT', 1, 'INVOICE_OVERDUE', 'compta@example.com',
        TRUE, 'MEDIUM');


PROMPT [6] 8 notifs en queue (diverses)
INSERT INTO notification_queue (alert_id, subscription_id, channel_id, recipient,
                                subject, body, priority, status, attempts, max_attempts,
                                next_attempt_at, sent_at, error_message)
VALUES (1, 4, 4, 'INVENTORY',
        'Stock bas - ART003',
        'Le stock de Clé USB 32 Go (40 unités) est inférieur au seuil minimum (50)',
        5, 'SENT', 1, 5, SYSDATE - 1, SYSDATE - 1, NULL);

INSERT INTO notification_queue (alert_id, subscription_id, channel_id, recipient,
                                subject, body, priority, status, attempts, max_attempts,
                                next_attempt_at, last_attempt_at, error_message)
VALUES (1, 1, 1, 'admin@example.com',
        'Stock bas - ART003',
        'Le stock de Clé USB 32 Go (40 unités) est inférieur au seuil minimum (50)',
        5, 'FAILED', 3, 5, SYSDATE + 1/24, SYSDATE - 2/24,
        'SMTP timeout - retry in 60 min');

INSERT INTO notification_queue (alert_id, subscription_id, channel_id, recipient,
                                subject, body, priority, status, attempts, max_attempts,
                                next_attempt_at)
VALUES (3, 5, 1, 'compta@example.com',
        'Dépassement encours - CLI003',
        'Le client Client Durand a dépassé son encours autorisé (25000 > 20000)',
        3, 'PENDING', 0, 5, SYSDATE);

INSERT INTO notification_queue (alert_id, subscription_id, channel_id, recipient,
                                subject, body, priority, status, attempts, max_attempts,
                                next_attempt_at, sent_at)
VALUES (2, 5, 1, 'compta@example.com',
        'Facture en retard - FA-2026-003',
        'La facture FA-2026-003 est en retard de 30 jours',
        4, 'SENT', 1, 5, SYSDATE - 30, SYSDATE - 30);

INSERT INTO notification_queue (alert_id, subscription_id, channel_id, recipient,
                                subject, body, priority, status, attempts, max_attempts,
                                next_attempt_at)
VALUES (4, 4, 4, 'INVENTORY',
        'Lot expirant sous 100j',
        'Le lot LOT-2026-001-A expire dans 100 jours',
        6, 'PENDING', 0, 5, SYSDATE);

INSERT INTO notification_queue (alert_id, subscription_id, channel_id, recipient,
                                subject, body, priority, status, attempts, max_attempts,
                                next_attempt_at, sent_at)
VALUES (NULL, 1, 1, 'admin@example.com',
        'Bienvenue sur ERP 23ai',
        'Votre compte a été créé avec succès.',
        8, 'SENT', 1, 5, SYSDATE - 60, SYSDATE - 60);

INSERT INTO notification_queue (channel_id, recipient, subject, body, priority, status, attempts, max_attempts,
                                next_attempt_at, last_attempt_at, error_message)
VALUES (1, 'test@example.com', 'Test canal email', 'Hello world', 9, 'CANCELLED', 0, 5,
        SYSDATE - 30, NULL, NULL);

INSERT INTO notification_queue (channel_id, recipient, subject, body, priority, status, attempts, max_attempts,
                                next_attempt_at, error_message)
VALUES (2, '+225070000099', 'Alerte urgente', 'Test SMS', 1, 'PENDING', 0, 5, SYSDATE,
        NULL);

COMMIT;


PROMPT
PROMPT ═══ Volumétrie ═══
SELECT 'ALERT_TYPE'                AS tbl, COUNT(*) AS nb FROM alert_type
UNION ALL SELECT 'ALERT_RULE',                 COUNT(*) FROM alert_rule
UNION ALL SELECT 'ALERT_INSTANCE',             COUNT(*) FROM alert_instance
UNION ALL SELECT 'NOTIFICATION_CHANNEL',       COUNT(*) FROM notification_channel
UNION ALL SELECT 'NOTIFICATION_SUBSCRIPTION',  COUNT(*) FROM notification_subscription
UNION ALL SELECT 'NOTIFICATION_QUEUE',         COUNT(*) FROM notification_queue
 ORDER BY tbl;

PROMPT
PROMPT ═══ Démos / requêtes ═══

PROMPT [Q1] Alertes ouvertes par sévérité
SELECT severity, COUNT(*) AS nb
  FROM alert_instance
 WHERE status = 'OPEN'
 GROUP BY severity
 ORDER BY DECODE(severity, 'CRITICAL',1, 'HIGH',2, 'MEDIUM',3, 'LOW',4);

PROMPT [Q2] Top règles qui se déclenchent
SELECT ar.rule_name, COUNT(ai.alert_id) AS nb_declenchements
  FROM alert_rule ar
  LEFT JOIN alert_instance ai ON ai.rule_id = ar.rule_id
 GROUP BY ar.rule_name
 ORDER BY nb_declenchements DESC;

PROMPT [Q3] File d'attente en cours (PENDING)
SELECT q.queue_id, q.priority, c.channel_type, q.recipient, q.subject, q.attempts
  FROM notification_queue q
  JOIN notification_channel c ON c.channel_id = q.channel_id
 WHERE q.status = 'PENDING'
 ORDER BY q.priority, q.next_attempt_at;

PROMPT [Q4] Taux d'échec par canal
SELECT c.channel_type,
       COUNT(*) AS total,
       SUM(CASE WHEN q.status = 'SENT' THEN 1 ELSE 0 END) AS sent,
       SUM(CASE WHEN q.status = 'FAILED' THEN 1 ELSE 0 END) AS failed,
       ROUND(SUM(CASE WHEN q.status = 'FAILED' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS pct_fail
  FROM notification_queue q
  JOIN notification_channel c ON c.channel_id = q.channel_id
 GROUP BY c.channel_type
 ORDER BY pct_fail DESC;

PROMPT [Q5] Alertes JSON payload (parsing natif 23ai)
SELECT alert_id, message,
       JSON_VALUE(payload, '$.current_stock') AS current_stock,
       JSON_VALUE(payload, '$.min_stock')     AS min_stock
  FROM alert_instance
 WHERE payload IS NOT NULL
 ORDER BY alert_id;

PROMPT [Q6] Abonnements par utilisateur
SELECT s.user_code,
       LISTAGG(c.channel_type, ', ') WITHIN GROUP (ORDER BY c.channel_type) AS canaux,
       COUNT(*) AS nb_abos
  FROM notification_subscription s
  JOIN notification_channel c ON c.channel_id = s.channel_id
 WHERE s.is_active = TRUE
 GROUP BY s.user_code
 ORDER BY s.user_code;

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ SEED LOT R11 TERMINÉ
PROMPT ══════════════════════════════════════════════════════════
EXIT;
