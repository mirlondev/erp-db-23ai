-- ============================================================
-- fix_all.sql — Réparation complète
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF
SET LINESIZE 200

PROMPT ═══════════════════════════════════════════════════════
PROMPT   RÉPARATION COMPLÈTE
PROMPT ═══════════════════════════════════════════════════════

-- [1] Diagnostic trigger
CONNECT app_sales/AppSales#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT [1] Erreurs du trigger TRG_TICKET_AUDIT
SELECT line, position, text
  FROM user_errors
 WHERE name = 'TRG_TICKET_AUDIT'
 ORDER BY sequence;

-- [2] Droits
PROMPT
PROMPT [2] Droits app_sales → app_pos
CONNECT system/oracle@localhost:1521/FREEPDB1

GRANT SELECT, UPDATE ON app_pos.pos_terminal TO app_sales;

-- [3] Recréer le trigger
PROMPT
PROMPT [3] Recréation du trigger
CONNECT app_sales/AppSales#2026@localhost:1521/FREEPDB1

BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_ticket_audit';
      EXCEPTION WHEN OTHERS THEN NULL; END;
/

CREATE OR REPLACE TRIGGER trg_ticket_audit
AFTER INSERT ON ticket
FOR EACH ROW
DECLARE
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  UPDATE app_pos.pos_terminal
     SET last_ticket_no = :NEW.ticket_no
   WHERE terminal_code = :NEW.terminal_id
     AND (last_ticket_no IS NULL OR last_ticket_no < :NEW.ticket_no);
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
END;
/

-- [4] Sessions POS
PROMPT
PROMPT [4] Sessions POS
CONNECT app_pos/AppPos#2026@localhost:1521/FREEPDB1

INSERT INTO pos_session (terminal_id, session_no, user_code, opened_at, closed_at, opening_balance, closing_balance)
SELECT terminal_id, 626, 'VIJJU', DATE '2026-04-18', DATE '2026-04-18', 0, 0
  FROM pos_terminal WHERE terminal_code = 'FP1'
  AND NOT EXISTS (SELECT 1 FROM pos_session WHERE terminal_id = pos_terminal.terminal_id AND session_no = 626);

COMMIT;

-- [5] Charger les tickets
PROMPT
PROMPT [5] Chargement des 9 tickets
CONNECT app_sales/AppSales#2026@localhost:1521/FREEPDB1

INSERT INTO ticket (terminal_id, ticket_no, ticket_date, session_no, customer_code, customer_name,
                    user_code, total_ttc, total_ht, ticket_total, status)
SELECT 'FP1', 1011578, TO_DATE('2026-04-18 12:39:21','YYYY-MM-DD HH24:MI:SS'), 626, 'CL0001', 'POS CASH ACCOUNT',
       'VIJJU', 10000, 8411, 10000, 'V' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM ticket WHERE terminal_id='FP1' AND ticket_no=1011578);

INSERT INTO ticket (terminal_id, ticket_no, ticket_date, session_no, customer_code, customer_name,
                    user_code, total_ttc, total_ht, ticket_total, status)
SELECT 'FP1', 1011579, TO_DATE('2026-04-18 12:53:27','YYYY-MM-DD HH24:MI:SS'), 626, 'CL0001', 'MH',
       'VIJJU', 233000, 221378, 233000, 'V' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM ticket WHERE terminal_id='FP1' AND ticket_no=1011579);

INSERT INTO ticket (terminal_id, ticket_no, ticket_date, session_no, customer_code, customer_name,
                    user_code, total_ttc, total_ht, ticket_total, status)
SELECT 'FP1', 1011576, TO_DATE('2026-04-18 12:16:02','YYYY-MM-DD HH24:MI:SS'), 626, 'CL0001', 'POS CASH ACCOUNT',
       'VIJJU', 113000, 95038, 113000, 'V' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM ticket WHERE terminal_id='FP1' AND ticket_no=1011576);

INSERT INTO ticket (terminal_id, ticket_no, ticket_date, session_no, customer_code, customer_name,
                    user_code, total_ttc, total_ht, ticket_total, status)
SELECT 'FP1', 1011577, TO_DATE('2026-04-18 12:20:22','YYYY-MM-DD HH24:MI:SS'), 626, 'CL0001', 'HONG KONG',
       'VIJJU', 240000, 228029, 240000, 'V' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM ticket WHERE terminal_id='FP1' AND ticket_no=1011577);

INSERT INTO ticket (terminal_id, ticket_no, ticket_date, session_no, customer_code, customer_name,
                    user_code, total_ttc, total_ht, ticket_total, status)
SELECT 'FP1', 1011566, TO_DATE('2026-04-18 08:50:28','YYYY-MM-DD HH24:MI:SS'), 626, 'SFP037', 'MAPAKOU MAJOLIE (VI-JOHN)',
       'VIJJU', 213750, 179773, 213750, 'A' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM ticket WHERE terminal_id='FP1' AND ticket_no=1011566);

INSERT INTO ticket (terminal_id, ticket_no, ticket_date, session_no, customer_code, customer_name,
                    user_code, total_ttc, total_ht, ticket_total, status)
SELECT 'FP1', 1011568, TO_DATE('2026-04-18 09:38:02','YYYY-MM-DD HH24:MI:SS'), 626, 'CL0001', 'POS CASH ACCOUNT',
       'VIJJU', 138500, 116484, 138500, 'V' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM ticket WHERE terminal_id='FP1' AND ticket_no=1011568);

INSERT INTO ticket (terminal_id, ticket_no, ticket_date, session_no, customer_code, customer_name,
                    user_code, total_ttc, total_ht, ticket_total, status)
SELECT 'FP1', 1011574, TO_DATE('2026-04-18 11:12:38','YYYY-MM-DD HH24:MI:SS'), 626, 'CL0001', 'EL BARAKA',
       'VIJJU', 165500, 139193, 165500, 'V' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM ticket WHERE terminal_id='FP1' AND ticket_no=1011574);

INSERT INTO ticket (terminal_id, ticket_no, ticket_date, session_no, customer_code, customer_name,
                    user_code, total_ttc, total_ht, ticket_total, status, loyalty_base_amount)
SELECT 'FP1', 1011580, TO_DATE('2026-06-11 11:41:25','YYYY-MM-DD HH24:MI:SS'), 626, 'CL0001', 'POS CASH ACCOUNT',
       'BABU', 3000, 2523, 3000, 'V', 3000 FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM ticket WHERE terminal_id='FP1' AND ticket_no=1011580);

INSERT INTO ticket (terminal_id, ticket_no, ticket_date, session_no, customer_code, customer_name,
                    user_code, total_ttc, total_ht, ticket_total, status)
SELECT 'FP1', 1011565, TO_DATE('2026-04-18 08:32:39','YYYY-MM-DD HH24:MI:SS'), 626, 'CL0001', 'MARINI',
       'VIJJU', 80000, 67283, 80000, 'V' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM ticket WHERE terminal_id='FP1' AND ticket_no=1011565);

COMMIT;

-- [6] Validation
PROMPT
PROMPT [6] Validation finale
CONNECT system/oracle@localhost:1521/FREEPDB1

SELECT 'TICKETS'           AS tbl, COUNT(*) AS nb FROM app_sales.ticket
UNION ALL SELECT 'SESSIONS',         COUNT(*) FROM app_pos.pos_session
UNION ALL SELECT 'TRIGGERS VALIDES', COUNT(*) FROM all_triggers
                                     WHERE owner='APP_SALES' AND status='ENABLED';

PROMPT
PROMPT [7] Objets invalides restants
SELECT owner, object_type, object_name
  FROM all_objects
 WHERE status = 'INVALID'
   AND owner LIKE 'APP\_%' ESCAPE '\';

EXIT;