-- ============================================================
-- S22 : Seed LOT R14 (Interfaces & Intégrations)
-- Données de démo : 6 endpoints, 12 logs (mix succès/erreur),
--                    8 sync_queue entries, 4 batches import, 5 exports.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF

CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   SEED LOT R14 — Interfaces & Intégrations
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [Reset tables R14]
BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM export_config';
  EXECUTE IMMEDIATE 'DELETE FROM import_batch';
  EXECUTE IMMEDIATE 'DELETE FROM sync_queue';
  EXECUTE IMMEDIATE 'DELETE FROM interface_log';
  EXECUTE IMMEDIATE 'DELETE FROM interface_endpoint';
  COMMIT;
END;
/


PROMPT [1] 6 endpoints API
INSERT INTO interface_endpoint (endpoint_code, endpoint_name, url, http_method,
                                 auth_type, auth_config, timeout_seconds,
                                 retry_count, retry_delay_sec, rate_limit_per_min,
                                 description, is_active)
VALUES ('LOYALTY_API', 'API Programme Fidélité',
        'https://api.loyalty.example.com/v1', 'POST',
        'OAUTH2', JSON_OBJECT('token_url' VALUE 'https://auth.example.com/token',
                              'client_id' VALUE 'erp-client',
                              'scope' VALUE 'wallet.read wallet.write'),
        30, 3, 60, 100,
        'API externe de fidélité (RFC contract v1)', TRUE);

INSERT INTO interface_endpoint (endpoint_code, endpoint_name, url, http_method,
                                 auth_type, auth_config, timeout_seconds,
                                 retry_count, retry_delay_sec, rate_limit_per_min,
                                 description, is_active)
VALUES ('SHIPPING_API', 'API Expédition',
        'https://api.shipping.example.com/v2/shipments', 'POST',
        'BEARER', JSON_OBJECT('token_env' VALUE 'SHIPPING_TOKEN'),
        20, 2, 30, 60,
        'API expédition (DHL/DPD)', TRUE);

INSERT INTO interface_endpoint (endpoint_code, endpoint_name, url, http_method,
                                 auth_type, auth_config, timeout_seconds,
                                 retry_count, retry_delay_sec, rate_limit_per_min,
                                 description, is_active)
VALUES ('PAYMENT_GATEWAY', 'Passerelle de paiement',
        'https://api.payment.example.com/v3/charges', 'POST',
        'API_KEY', JSON_OBJECT('api_key_env' VALUE 'PAYMENT_KEY'),
        60, 5, 120, 200,
        'Stripe-like gateway', TRUE);

INSERT INTO interface_endpoint (endpoint_code, endpoint_name, url, http_method,
                                 auth_type, auth_config, timeout_seconds,
                                 retry_count, retry_delay_sec, rate_limit_per_min,
                                 description, is_active)
VALUES ('ACCOUNTING_WEBHOOK', 'Webhook comptabilité',
        'https://accounting.example.com/api/webhook/gl', 'POST',
        'HMAC', JSON_OBJECT('secret_env' VALUE 'ACCOUNTING_SECRET', 'algo' VALUE 'SHA256'),
        15, 5, 60, 500,
        'Webhook pour sync des écritures compta', TRUE);

INSERT INTO interface_endpoint (endpoint_code, endpoint_name, url, http_method,
                                 auth_type, auth_config,
                                 timeout_seconds, retry_count,
                                 rate_limit_per_min, description, is_active)
VALUES ('BI_FEED', 'Flux BI',
        'https://bi.example.com/api/feed/invoices', 'GET',
        'BASIC', JSON_OBJECT('user' VALUE 'bi_reader', 'password_env' VALUE 'BI_PASS'),
        120, 1, 5,
        'Pull quotidien vers Data Lake', TRUE);

INSERT INTO interface_endpoint (endpoint_code, endpoint_name, url, http_method,
                                 auth_type,
                                 timeout_seconds, retry_count,
                                 description, is_active)
VALUES ('BANK_RECONCILIATION', 'Réconciliation bancaire',
        'https://api.bank.example.com/v1/statements', 'GET',
        'CERT',
        45, 3,
        'Pull des relevés bancaires', FALSE);


PROMPT [2] 12 entrées de log (mix succès/erreur/timeout)
INSERT INTO interface_log (endpoint_code, direction, request_payload,
                            response_payload, http_status, duration_ms,
                            status, retry_attempt, entity_type, entity_id,
                            correlation_id, ip_address)
VALUES ('LOYALTY_API', 'OUT',
        JSON_OBJECT('card' VALUE 'LC-0001', 'points' VALUE 50),
        JSON_OBJECT('status' VALUE 'ok', 'new_balance' VALUE 170, 'transaction_id' VALUE 'LT-998877'),
        200, 245, 'SUCCESS', 1, 'LOYALTY_CARD', '1',
        'CORR-LOY-2026-001', '192.168.1.20');

INSERT INTO interface_log (endpoint_code, direction, request_payload,
                            response_payload, http_status, duration_ms,
                            status, retry_attempt, entity_type, entity_id,
                            correlation_id)
VALUES ('LOYALTY_API', 'OUT',
        JSON_OBJECT('card' VALUE 'LC-0999', 'points' VALUE 99999),
        JSON_OBJECT('error' VALUE 'card_not_found', 'message' VALUE 'Card number unknown'),
        404, 152, 'CLIENT_ERROR', 1, 'LOYALTY_CARD', '999',
        'CORR-LOY-2026-002');

INSERT INTO interface_log (endpoint_code, direction, request_payload,
                            response_payload, http_status, duration_ms,
                            status, retry_attempt, error_message, correlation_id)
VALUES ('PAYMENT_GATEWAY', 'OUT',
        JSON_OBJECT('amount' VALUE 1500000, 'currency' VALUE 'XOF', 'method' VALUE 'CARD'),
        NULL, NULL, 30045, 'TIMEOUT', 2,
        'Connection timeout after 30s', 'CORR-PAY-2026-001');

INSERT INTO interface_log (endpoint_code, direction, request_payload,
                            response_payload, http_status, duration_ms,
                            status, retry_attempt, entity_type, entity_id, correlation_id)
VALUES ('PAYMENT_GATEWAY', 'OUT',
        JSON_OBJECT('amount' VALUE 1500000, 'currency' VALUE 'XOF'),
        JSON_OBJECT('status' VALUE 'declined', 'reason' VALUE 'insufficient_funds'),
        402, 2450, 'CLIENT_ERROR', 1, 'PAYMENT', 'REG-2026-005', 'CORR-PAY-2026-002');

INSERT INTO interface_log (endpoint_code, direction, request_payload,
                            response_payload, http_status, duration_ms,
                            status, retry_attempt, correlation_id)
VALUES ('SHIPPING_API', 'OUT',
        JSON_OBJECT('order_id' VALUE 'BC-2026-001', 'packages' VALUE 3),
        JSON_OBJECT('tracking' VALUE 'DHL-998877-A', 'cost' VALUE 12000),
        201, 1850, 'SUCCESS', 1, 'CORR-SHIP-2026-001');

INSERT INTO interface_log (endpoint_code, direction, request_payload,
                            response_payload, http_status, duration_ms,
                            status, retry_attempt, correlation_id)
VALUES ('SHIPPING_API', 'OUT',
        JSON_OBJECT('order_id' VALUE 'BC-2026-002'),
        JSON_OBJECT('error' VALUE 'invalid_address', 'field' VALUE 'postal_code'),
        422, 1020, 'CLIENT_ERROR', 1, 'CORR-SHIP-2026-002');

INSERT INTO interface_log (endpoint_code, direction, request_payload,
                            response_payload, http_status, duration_ms,
                            status, retry_attempt, entity_type, entity_id,
                            correlation_id)
VALUES ('ACCOUNTING_WEBHOOK', 'OUT',
        JSON_OBJECT('event' VALUE 'gl.entry.created', 'data' VALUE 'entry-001'),
        JSON_OBJECT('received' VALUE true, 'processed_at' VALUE SYSTIMESTAMP),
        200, 320, 'SUCCESS', 1, 'GL_ENTRY', '1', 'CORR-ACC-001');

INSERT INTO interface_log (endpoint_code, direction, request_payload,
                            response_payload, http_status, duration_ms,
                            status, retry_attempt, error_message, correlation_id)
VALUES ('ACCOUNTING_WEBHOOK', 'OUT',
        JSON_OBJECT('event' VALUE 'gl.entry.created'),
        JSON_OBJECT('error' VALUE 'unauthorized', 'message' VALUE 'Invalid HMAC signature'),
        401, 198, 'CLIENT_ERROR', 3, 'HMAC signature mismatch', 'CORR-ACC-002');

INSERT INTO interface_log (endpoint_code, direction, request_payload,
                            response_payload, http_status, duration_ms, status,
                            retry_attempt, correlation_id)
VALUES ('BI_FEED', 'IN',
        JSON_OBJECT('source' VALUE 'bi-pull'),
        JSON_OBJECT('rows_pulled' VALUE 124, 'etag' VALUE 'W/"abc123"'),
        200, 3850, 'SUCCESS', 1, 'CORR-BI-2026-001');

INSERT INTO interface_log (endpoint_code, direction,
                            http_status, duration_ms, status,
                            retry_attempt, error_code, error_message, correlation_id)
VALUES ('BI_FEED', 'IN',
        503, 60500, 'SERVER_ERROR', 1, 'BI-503', 'Service Unavailable', 'CORR-BI-2026-002');

INSERT INTO interface_log (endpoint_code, direction, http_status,
                            duration_ms, status, error_message, correlation_id)
VALUES ('BANK_RECONCILIATION', 'IN',
        NULL, 45030, 'TIMEOUT', 'Cert verification failed', 'CORR-BANK-001');

INSERT INTO interface_log (endpoint_code, direction, request_payload,
                            response_payload, http_status, duration_ms, status)
VALUES ('PAYMENT_GATEWAY', 'OUT',
        JSON_OBJECT('amount' VALUE 5000, 'currency' VALUE 'XOF'),
        JSON_OBJECT('status' VALUE 'captured', 'transaction_id' VALUE 'PG-998877'),
        200, 1240, 'SUCCESS');


PROMPT [3] 8 sync_queue entries (mix statuts)
INSERT INTO sync_queue (entity_type, entity_id, operation, payload,
                        target_system, priority, status, attempts,
                        next_attempt_at, last_attempt_at, processed_at, locked_by)
VALUES ('TICKET', 'CAI01/3', 'INSERT',
        JSON_OBJECT('total_ttc' VALUE 15000, 'customer' VALUE 'CLI003'),
        'BI', 5, 'PENDING', 0, SYSTIMESTAMP, NULL, NULL, NULL);

INSERT INTO sync_queue (entity_type, entity_id, operation, payload,
                        target_system, priority, status, attempts,
                        next_attempt_at, last_attempt_at, error_message)
VALUES ('TICKET', 'CAI01/4', 'INSERT',
        JSON_OBJECT('total_ttc' VALUE 7500),
        'BI', 5, 'FAILED', 3, SYSTIMESTAMP + 30/86400, SYSTIMESTAMP - 1/24,
        'BI endpoint timeout (3 retries)');

INSERT INTO sync_queue (entity_type, entity_id, operation, payload,
                        target_system, priority, status, attempts,
                        next_attempt_at, last_attempt_at, locked_by, locked_at)
VALUES ('INVOICE', 'FA-2026-001', 'INSERT',
        JSON_OBJECT('invoice_id' VALUE 1, 'total_ttc' VALUE 5000),
        'ECOMMERCE', 3, 'PROCESSING', 1, SYSTIMESTAMP, SYSTIMESTAMP,
        'WORKER-01', SYSTIMESTAMP);

INSERT INTO sync_queue (entity_type, entity_id, operation, payload,
                        target_system, priority, status, attempts,
                        next_attempt_at, last_attempt_at, processed_at)
VALUES ('INVOICE', 'FA-2026-002', 'UPDATE',
        JSON_OBJECT('status' VALUE 'PARTIAL', 'paid' VALUE 10000),
        'ECOMMERCE', 3, 'SUCCESS', 1, SYSTIMESTAMP - 1, SYSTIMESTAMP - 1, SYSTIMESTAMP - 1);

INSERT INTO sync_queue (entity_type, entity_id, operation, payload,
                        target_system, priority, status, attempts,
                        next_attempt_at, last_attempt_at)
VALUES ('PRODUCT', 'ART001', 'UPDATE',
        JSON_OBJECT('standard_price' VALUE 2700, 'trigger' VALUE 'price_change'),
        'CRM', 8, 'PENDING', 0, SYSTIMESTAMP + 5/86400, NULL);

INSERT INTO sync_queue (entity_type, entity_id, operation, payload,
                        target_system, priority, status, attempts,
                        next_attempt_at, last_attempt_at, error_message)
VALUES ('PRODUCT', 'ART002', 'UPDATE',
        JSON_OBJECT('is_promo' VALUE true),
        'MOBILE', 10, 'FAILED', 5, SYSTIMESTAMP + 60/86400, SYSTIMESTAMP,
        'Max attempts reached - manual intervention needed');

INSERT INTO sync_queue (entity_type, entity_id, operation, payload,
                        target_system, priority, status,
                        next_attempt_at, processed_at)
VALUES ('PARTY', 'CLI001', 'UPSERT',
        JSON_OBJECT('party_code' VALUE 'CLI001', 'name' VALUE 'Client Dupont', 'balance' VALUE 0),
        'DATA_LAKE', 6, 'SUCCESS', SYSTIMESTAMP - 7, SYSTIMESTAMP - 7);

INSERT INTO sync_queue (entity_type, entity_id, operation, payload,
                        target_system, priority, status,
                        next_attempt_at, processed_at)
VALUES ('PARTY', 'CLI004', 'INSERT',
        JSON_OBJECT('party_code' VALUE 'CLI004', 'name' VALUE 'Nouveau Client'),
        'DATA_LAKE', 6, 'CANCELLED',
        SYSTIMESTAMP, SYSTIMESTAMP);


PROMPT [4] 4 batches d'import
INSERT INTO import_batch (batch_code, import_type, source_file,
                           source_format, source_system,
                           total_rows, success_rows, error_rows,
                           status, started_at, completed_at, duration_ms,
                           started_by, parameters_json)
VALUES ('IMP-2026-001', 'PRODUCTS', '/data/imports/products_2026_09.csv',
        'CSV', 'LEGACY_11G',
        1240, 1235, 5, 'PARTIAL',
        SYSDATE - 7, SYSDATE - 7 + 35/60/60, 2100000,
        'ADMIN',
        JSON_OBJECT('mapping' VALUE 'auto', 'skip_errors' VALUE true, 'update_existing' VALUE true));

INSERT INTO import_batch (batch_code, import_type, source_file,
                           source_format, source_system,
                           total_rows, success_rows,
                           status, started_at, completed_at, duration_ms,
                           started_by)
VALUES ('IMP-2026-002', 'CUSTOMERS', '/data/imports/clients_2026_09.xlsx',
        'XLSX', 'WEB_FORM',
        320, 320, 'SUCCESS',
        SYSDATE - 5, SYSDATE - 5 + 12/60/60, 720000,
        'INVENTORY');

INSERT INTO import_batch (batch_code, import_type, source_file,
                           source_format, source_system,
                           total_rows, success_rows, error_rows, skipped_rows,
                           status, started_at, duration_ms, started_by,
                           parameters_json)
VALUES ('IMP-2026-003', 'STOCK', '/data/imports/stock_init.csv',
        'CSV', 'WAREHOUSE_SCAN',
        580, 575, 0, 5,
        'SUCCESS', SYSDATE - 2, 450000,
        'INVENTORY',
        JSON_OBJECT('update_existing' VALUE true, 'dry_run' VALUE false));

INSERT INTO import_batch (batch_code, import_type, source_file,
                           source_format, status,
                           total_rows, started_at, started_by)
VALUES ('IMP-2026-004', 'INVOICES', '/data/pending/invoices_ar.csv',
        'CSV', 'RUNNING',
        1580, SYSTIMESTAMP, 'ACCOUNTANT');


PROMPT [5] 5 exports config
INSERT INTO export_config (export_code, export_name, target_system, format,
                           query_sql, file_pattern, output_path,
                           schedule_cron, compression_type, include_header,
                           delimiter_char, is_active,
                           last_run_at, last_run_status, last_run_row_count,
                           created_by)
VALUES ('EXP_SALES_DAILY', 'Ventes quotidiennes vers Data Lake',
        'DATA_LAKE', 'PARQUET',
        'SELECT t.ticket_no, t.ticket_date, t.customer_code, l.product_code, l.quantity, l.unit_price FROM app_sales.ticket t JOIN app_sales.ticket_line l ON l.terminal_id=t.terminal_id AND l.ticket_no=t.ticket_no WHERE t.status=''V''',
        'sales_%YYYY%MM%DD.parquet',
        '/exports/data_lake/sales/',
        '0 1 * * *', 'GZIP', FALSE, NULL,
        TRUE, SYSDATE - 1, 'SUCCESS', 4582,
        'ADMIN');

INSERT INTO export_config (export_code, export_name, target_system, format,
                           query_sql, file_pattern, output_path,
                           schedule_cron, compression_type, is_active,
                           last_run_at, last_run_status, last_run_row_count,
                           created_by)
VALUES ('EXP_INV_TO_BI', 'Factures vers BI',
        'BI', 'CSV',
        'SELECT * FROM app_ar.invoice WHERE status IN (''VALID'',''PARTIAL'',''PAID'',''OVERDUE'')',
        'invoices_%YYYY%MM%DD.csv',
        '/exports/bi/',
        '0 2 * * *', 'ZIP', TRUE, ',',
        TRUE, SYSDATE - 1, 'SUCCESS', 248,
        'ADMIN');

INSERT INTO export_config (export_code, export_name, target_system, format,
                           query_sql, file_pattern, output_path,
                           schedule_cron, is_active,
                           last_run_at, last_run_status, last_run_row_count,
                           last_run_file_path, created_by)
VALUES ('EXP_CUST_TO_CRM', 'Clients vers CRM',
        'CRM', 'CSV',
        'SELECT party_code, party_name, phone, email, address_1, credit_limit FROM app_party.party WHERE status=''ACTIVE''',
        'customers_%YYYY%MM%DD.csv',
        '/exports/crm/',
        '0 3 * * 0', TRUE,
        SYSDATE - 7, 'SUCCESS', 1847,
        '/exports/crm/customers_20260922.csv', 'ADMIN');

INSERT INTO export_config (export_code, export_name, target_system, format,
                           query_sql, file_pattern, output_path,
                           schedule_cron, is_active,
                           created_by)
VALUES ('EXP_STOCK_TO_PARTNER', 'Stock vers partenaire logistique',
        'PARTNER', 'XLSX',
        'SELECT s.warehouse_code, s.product_code, p.product_name, s.stock_qty, p.standard_price FROM app_inv.inv_stock s JOIN app_product.product p ON p.product_code=s.product_code',
        'stock_%YYYY%MM%DD.xlsx',
        '/exports/partner/',
        '0 6 * * *', TRUE,
        'ADMIN');

INSERT INTO export_config (export_code, export_name, target_system, format,
                           query_sql, file_pattern,
                           schedule_cron, is_active,
                           last_run_at, last_run_status, error_message,
                           created_by)
VALUES ('EXP_GL_TO_ACCOUNT', 'Écritures compta vers logiciel externe',
        'PARTNER', 'XML',
        'SELECT e.entry_no, e.accounting_date, e.journal_code, e.entry_label, el.account_code, el.direction, el.company_debit, el.company_credit FROM app_gl.gl_entry e JOIN app_gl.gl_entry_line el ON el.company_code=e.company_code AND el.entry_no=e.entry_no',
        'gl_%YYYY%MM.xml',
        '0 23 * * *', TRUE,
        SYSDATE - 1, 'FAILED', 'Format XML non supporté - migration vers JSON en cours',
        'ADMIN');

COMMIT;


PROMPT
PROMPT ═══ Volumétrie ═══
SELECT 'INTERFACE_ENDPOINT'      AS tbl, COUNT(*) AS nb FROM interface_endpoint
UNION ALL SELECT 'INTERFACE_LOG',        COUNT(*) FROM interface_log
UNION ALL SELECT 'SYNC_QUEUE',           COUNT(*) FROM sync_queue
UNION ALL SELECT 'IMPORT_BATCH',         COUNT(*) FROM import_batch
UNION ALL SELECT 'EXPORT_CONFIG',        COUNT(*) FROM export_config
 ORDER BY tbl;

PROMPT
PROMPT ═══ Démos / requêtes ═══

PROMPT [Q1] Taux de succès par endpoint
SELECT endpoint_code,
       COUNT(*) AS total,
       SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) AS success,
       SUM(CASE WHEN status IN ('CLIENT_ERROR','SERVER_ERROR') THEN 1 ELSE 0 END) AS errors,
       ROUND(AVG(duration_ms), 0) AS avg_ms,
       ROUND(SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS pct_success
  FROM interface_log
 GROUP BY endpoint_code
 ORDER BY pct_success DESC;

PROMPT [Q2] Files d'attente par status
SELECT target_system, status,
       COUNT(*) AS nb,
       AVG(attempts) AS avg_attempts
  FROM sync_queue
 GROUP BY target_system, status
 ORDER BY target_system, status;

PROMPT [Q3] Sync items bloqués (>3 tentatives)
SELECT entity_type, entity_id, target_system, attempts, error_message, last_attempt_at
  FROM sync_queue
 WHERE attempts >= 3
 ORDER BY attempts DESC;

PROMPT [Q4] Batches d'import par statut
SELECT status,
       COUNT(*) AS nb_batches,
       SUM(NVL(total_rows, 0)) AS total_lignes,
       SUM(NVL(success_rows, 0)) AS lignes_ok,
       SUM(NVL(error_rows, 0)) AS lignes_erreur,
       ROUND(SUM(NVL(success_rows,0)) * 100.0 / NULLIF(SUM(NVL(total_rows,0)), 0), 1) AS pct_success
  FROM import_batch
 GROUP BY status
 ORDER BY status;

PROMPT [Q5] Exports actifs par destination
SELECT target_system, format,
       COUNT(*) AS nb_exports,
       SUM(CASE WHEN last_run_status = 'SUCCESS' THEN 1 ELSE 0 END) AS last_run_ok,
       SUM(NVL(last_run_row_count, 0)) AS total_rows_exportedes
  FROM export_config
 WHERE is_active = TRUE
 GROUP BY target_system, format
 ORDER BY target_system, format;

PROMPT [Q6] Erreurs timeouts par endpoint (top 5)
SELECT endpoint_code, COUNT(*) AS nb_timeouts
  FROM interface_log
 WHERE status = 'TIMEOUT'
 GROUP BY endpoint_code
 ORDER BY nb_timeouts DESC;

PROMPT [Q7] Exports en échec (à investiguer)
SELECT export_code, export_name, target_system,
       last_run_at, last_run_status, error_message
  FROM export_config
 WHERE last_run_status = 'FAILED';

PROMPT [Q8] Trafic par direction (IN/OUT)
SELECT direction, COUNT(*) AS nb,
       ROUND(AVG(duration_ms), 0) AS avg_ms,
       SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) AS success
  FROM interface_log
 GROUP BY direction
 ORDER BY nb DESC;

PROMPT [Q9] Latence p95 par endpoint (approximation)
SELECT endpoint_code,
       COUNT(*) AS nb,
       MIN(duration_ms) AS min_ms,
       ROUND(AVG(duration_ms), 0) AS avg_ms,
       MAX(duration_ms) AS max_ms
  FROM interface_log
 GROUP BY endpoint_code
 ORDER BY avg_ms DESC;

PROMPT [Q10] Items sync lockés (worker actif)
SELECT entity_type, entity_id, target_system, locked_by, locked_at
  FROM sync_queue
 WHERE locked_by IS NOT NULL
 ORDER BY locked_at DESC;

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ SEED LOT R14 TERMINÉ — FIN DU PLAN COMPLET
PROMPT ══════════════════════════════════════════════════════════
EXIT;
