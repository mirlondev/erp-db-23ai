-- ============================================================
-- S13 : Seed LOT R5 (Facturation & Avoirs)
-- Données de démo : 3 factures + 1 avoir + 3 règlements + lettrage +
--                    encours 3 clients.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF

CONNECT app_ar/AppAr#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   SEED LOT R5 — Facturation & Avoirs
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [Reset des tables R5]
BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM payment_allocation';
  EXECUTE IMMEDIATE 'DELETE FROM customer_credit';
  EXECUTE IMMEDIATE 'DELETE FROM payment';
  EXECUTE IMMEDIATE 'DELETE FROM credit_note_line';
  EXECUTE IMMEDIATE 'DELETE FROM credit_note';
  EXECUTE IMMEDIATE 'DELETE FROM invoice_line';
  EXECUTE IMMEDIATE 'DELETE FROM invoice';
  COMMIT;
END;
/

PROMPT
PROMPT [1] Facture #1 — Client Dupont, PAYÉE
INSERT INTO invoice (invoice_number, invoice_date, company_code,
                      party_code, party_name, address_1,
                      currency_code, exchange_rate, due_date,
                      payment_method, total_ht, total_tax, total_ttc,
                      total_paid, balance, status, created_by)
VALUES ('FA-2026-001', SYSDATE - 30, 'COMP01',
        'CLI001', 'Client Dupont', 'Abidjan Plateau',
        'XOF', 1, SYSDATE, 'CASH',
        4237.29, 762.71, 5000,
        5000, 0, 'PAID', 'ADMIN');

INSERT INTO invoice_line (invoice_id, line_no, product_code, description,
                           quantity, unit_code, unit_price, amount,
                           tax_rate, tax_amount, amount_ht, amount_ttc)
VALUES (1, 1, 'ART001', 'Cahier 200 pages',
        2, 'UNIT', 2500, 5000, 18, 762.71, 4237.29, 5000);


PROMPT
PROMPT [2] Facture #2 — Client Martin, PARTIELLEMENT payée
INSERT INTO invoice (invoice_number, invoice_date, company_code,
                      party_code, party_name, address_1,
                      currency_code, exchange_rate, due_date,
                      payment_method, total_ht, total_tax, total_ttc,
                      total_paid, balance, status, created_by)
VALUES ('FA-2026-002', SYSDATE - 20, 'COMP01',
        'CLI002', 'Client Martin', 'Abidjan Cocody',
        'XOF', 1, SYSDATE + 10, 'BANK',
        12711.86, 2288.14, 15000,
        10000, 5000, 'PARTIAL', 'ADMIN');

INSERT INTO invoice_line (invoice_id, line_no, product_code, description,
                           quantity, unit_code, unit_price, amount,
                           tax_rate, tax_amount, amount_ht, amount_ttc)
VALUES (2, 1, 'ART003', 'Clé USB 32 Go',
        1, 'UNIT', 15000, 15000, 18, 2288.14, 12711.86, 15000);


PROMPT
PROMPT [3] Facture #3 — Client Durand, en retard (OVERDUE)
INSERT INTO invoice (invoice_number, invoice_date, company_code,
                      party_code, party_name, address_1,
                      currency_code, exchange_rate, due_date,
                      payment_method, total_ht, total_tax, total_ttc,
                      total_paid, balance, status, created_by)
VALUES ('FA-2026-003', SYSDATE - 60, 'COMP01',
        'CLI003', 'Client Durand', 'Abidjan Yopougon',
        'XOF', 1, SYSDATE - 30, 'CHECK',
        21186.44, 3813.56, 25000,
        0, 25000, 'OVERDUE', 'ADMIN');

INSERT INTO invoice_line (invoice_id, line_no, product_code, description,
                           quantity, unit_code, unit_price, amount,
                           tax_rate, tax_amount, amount_ht, amount_ttc)
VALUES (3, 1, 'ART001', 'Cahier 200 pages',
        10, 'UNIT', 2500, 25000, 18, 3813.56, 21186.44, 25000);


PROMPT
PROMPT [4] Avoir #1 — Retour partiel de la facture #1
INSERT INTO credit_note (credit_note_no, credit_note_date, company_code,
                          party_code, party_name,
                          source_invoice_id, currency_code, exchange_rate,
                          total_ht, total_tax, total_ttc,
                          status, reason, created_by)
VALUES ('AV-2026-001', SYSDATE - 10, 'COMP01',
        'CLI001', 'Client Dupont',
        1, 'XOF', 1,
        2118.64, 381.36, 2500,
        'VALID', 'Retour 1 cahier pour défaut', 'ADMIN');

INSERT INTO credit_note_line (credit_note_id, line_no, product_code, description,
                               quantity, unit_price, amount, tax_rate, tax_amount,
                               source_invoice_line_no)
VALUES (1, 1, 'ART001', 'Cahier 200 pages (retour)',
        1, 2500, 2500, 18, 381.36, 1);


PROMPT
PROMPT [5] 3 règlements
INSERT INTO payment (payment_number, payment_date, company_code,
                      party_code, party_name, payment_method, reference,
                      currency_code, amount, amount_allocated,
                      status, created_by)
VALUES ('REG-2026-001', SYSDATE - 30, 'COMP01',
        'CLI001', 'Client Dupont', 'CASH', 'Reçu n°001',
        'XOF', 5000, 5000, 'VALID', 'ADMIN');

INSERT INTO payment (payment_number, payment_date, company_code,
                      party_code, party_name, payment_method, reference,
                      currency_code, amount, amount_allocated,
                      status, created_by)
VALUES ('REG-2026-002', SYSDATE - 15, 'COMP01',
        'CLI002', 'Client Martin', 'BANK', 'VIR-2026-1234',
        'XOF', 10000, 10000, 'VALID', 'ADMIN');

INSERT INTO payment (payment_number, payment_date, company_code,
                      party_code, party_name, payment_method, reference,
                      currency_code, amount, amount_allocated,
                      status, memo, created_by)
VALUES ('REG-2026-003', SYSDATE - 5, 'COMP01',
        'CLI002', 'Client Martin', 'MOBILE', 'OM-789456',
        'XOF', 5000, 0, 'VALID', 'Avance sur prochaine facture', 'ADMIN');


PROMPT
PROMPT [6] Lettrage paiement ↔ facture
-- REG-001 couvre FA-001 (5000 XOF)
INSERT INTO payment_allocation (payment_id, invoice_id, document_type, document_ref, amount_applied)
VALUES (1, 1, 'INVOICE', 'FA-2026-001', 5000);

-- REG-002 couvre FA-002 partiellement (10000/15000)
INSERT INTO payment_allocation (payment_id, invoice_id, document_type, document_ref, amount_applied)
VALUES (2, 2, 'INVOICE', 'FA-2026-002', 10000);

-- REG-003 est une avance non lettrée
INSERT INTO payment_allocation (payment_id, invoice_id, document_type, document_ref, amount_applied)
VALUES (3, NULL, 'ADVANCE', 'AV-2026-CLI002', 5000);

-- Compensation de l'avoir AV-001 sur FA-001 (régularisation comptable)
-- L'avoir réduit le paid, mais on garde la trace dans l'alloc
-- (Note : en pratique on aurait un type CREDIT_NOTE_ALLOC spécifique)


PROMPT
PROMPT [7] Encours client (snapshot)
INSERT INTO customer_credit (party_code, company_code, credit_limit, credit_days,
                              current_balance, overdue_balance,
                              last_invoice_date, last_payment_date,
                              is_blocked, blocked_reason)
VALUES ('CLI001', 'COMP01', 100000, 30,
        0, 0,                    -- payé intégralement
        SYSDATE - 30, SYSDATE - 30,
        FALSE, NULL);

INSERT INTO customer_credit (party_code, company_code, credit_limit, credit_days,
                              current_balance, overdue_balance,
                              last_invoice_date, last_payment_date,
                              is_blocked, blocked_reason)
VALUES ('CLI002', 'COMP01', 50000, 30,
        5000, 0,                 -- 5000 restants (mais une avance de 5000 non lettrée)
        SYSDATE - 20, SYSDATE - 5,
        FALSE, NULL);

INSERT INTO customer_credit (party_code, company_code, credit_limit, credit_days,
                              current_balance, overdue_balance,
                              last_invoice_date, last_payment_date,
                              is_blocked, blocked_reason)
VALUES ('CLI003', 'COMP01', 20000, 30,
        25000, 25000,            -- 25000 échus depuis 30j → DÉPASSE la limite
        SYSDATE - 60, NULL,
        TRUE, 'Dépassement encours - blocage commandes');


COMMIT;

PROMPT
PROMPT ═══ Volumétrie ═══
SELECT 'INVOICE'              AS tbl, COUNT(*) AS nb FROM invoice
UNION ALL SELECT 'INVOICE_LINE',          COUNT(*) FROM invoice_line
UNION ALL SELECT 'CREDIT_NOTE',           COUNT(*) FROM credit_note
UNION ALL SELECT 'CREDIT_NOTE_LINE',      COUNT(*) FROM credit_note_line
UNION ALL SELECT 'PAYMENT',               COUNT(*) FROM payment
UNION ALL SELECT 'PAYMENT_ALLOCATION',    COUNT(*) FROM payment_allocation
UNION ALL SELECT 'CUSTOMER_CREDIT',       COUNT(*) FROM customer_credit
 ORDER BY tbl;

PROMPT
PROMPT ═══ Démos / requêtes ═══

PROMPT [Q1] Chiffre d'affaires facturé HT (par mois)
SELECT TO_CHAR(invoice_date, 'YYYY-MM') AS mois,
       COUNT(*)                          AS nb_factures,
       SUM(total_ht)                     AS ca_ht,
       SUM(total_ttc)                    AS ca_ttc
  FROM invoice
 WHERE status IN ('VALID','PARTIAL','PAID')
 GROUP BY TO_CHAR(invoice_date, 'YYYY-MM')
 ORDER BY mois;

PROMPT [Q2] Factures en retard (OVERDUE)
SELECT invoice_number, party_name, invoice_date, due_date,
       total_ttc, total_paid, balance,
       GREATEST(0, SYSDATE - due_date) AS retard_jours
  FROM invoice
 WHERE status = 'OVERDUE'
 ORDER BY retard_jours DESC;

PROMPT [Q3] Balance âgée par client (Balance âgée)
SELECT i.party_code, i.party_name,
       SUM(CASE WHEN SYSDATE - i.due_date <= 0  THEN i.balance ELSE 0 END) AS non_echu,
       SUM(CASE WHEN SYSDATE - i.due_date BETWEEN 1 AND 30 THEN i.balance ELSE 0 END) AS retard_1_30,
       SUM(CASE WHEN SYSDATE - i.due_date BETWEEN 31 AND 60 THEN i.balance ELSE 0 END) AS retard_31_60,
       SUM(CASE WHEN SYSDATE - i.due_date > 60 THEN i.balance ELSE 0 END) AS retard_60_plus,
       SUM(i.balance) AS total_balance
  FROM invoice i
 WHERE i.status IN ('VALID','PARTIAL','OVERDUE')
 GROUP BY i.party_code, i.party_name
 ORDER BY total_balance DESC;

PROMPT [Q4] Encaissements vs facturé
SELECT TO_CHAR(p.payment_date, 'YYYY-MM') AS mois,
       COUNT(DISTINCT p.payment_id)       AS nb_paiements,
       SUM(p.amount)                       AS encaisse
  FROM payment p
 WHERE p.status = 'VALID'
 GROUP BY TO_CHAR(p.payment_date, 'YYYY-MM')
 ORDER BY mois;

PROMPT [Q5] Clients en dépassement d'encours
SELECT cc.party_code, cc.credit_limit, cc.current_balance,
       cc.overdue_balance, cc.is_blocked, cc.blocked_reason
  FROM customer_credit cc
 WHERE cc.current_balance > cc.credit_limit
    OR cc.is_blocked = TRUE
 ORDER BY cc.current_balance DESC;

PROMPT [Q6] Avoirs émis (par mois)
SELECT TO_CHAR(credit_note_date, 'YYYY-MM') AS mois,
       COUNT(*)                               AS nb_avoirs,
       SUM(total_ttc)                         AS montant_avoirs
  FROM credit_note
 WHERE status IN ('VALID','APPLIED')
 GROUP BY TO_CHAR(credit_note_date, 'YYYY-MM')
 ORDER BY mois;

PROMPT [Q7] Paiements non lettrés (acomptes)
SELECT p.payment_number, p.party_name, p.payment_date, p.amount,
       p.amount_allocated,
       p.amount - p.amount_allocated AS reste_a_letrer
  FROM payment p
 WHERE p.status = 'VALID'
   AND p.amount > p.amount_allocated
 ORDER BY p.payment_date DESC;

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ SEED LOT R5 TERMINÉ
PROMPT ══════════════════════════════════════════════════════════
EXIT;
