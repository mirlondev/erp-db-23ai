-- ============================================================
-- SCRIPT 33 : Trigger trg_invoice_overdue + extensions
-- ============================================================
-- 1. Trigger auto-update statut facture en retard
-- 2. Trigger audit syst sur modifications customer_credit
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

-- =====================================================
-- Trigger 1 : Auto-update statut OVERDUE des factures
-- =====================================================
CONNECT system/oracle@localhost:1521/FREEPDB1

GRANT SELECT, UPDATE ON app_ar.invoice TO app_ar;
GRANT SELECT ON app_party.party TO app_ar;

CONNECT app_ar/AppAr#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   TRIGGER trg_invoice_overdue
PROMPT ══════════════════════════════════════════════════════════

BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_invoice_overdue';
  EXCEPTION WHEN OTHERS THEN
    -- defensive : ne plante pas si trigger inexistant (ORA-0408)
    IF SQLCODE NOT IN (-0408, -0407, -02443, -00942) THEN RAISE; END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_invoice_overdue
BEFORE INSERT OR UPDATE OF due_date, total_paid ON invoice
FOR EACH ROW
DECLARE
  v_days_overdue NUMBER := 0;
BEGIN
  -- Calcul jours de retard
  IF :NEW.due_date IS NOT NULL AND :NEW.status IN ('VALID','PARTIAL') THEN
    v_days_overdue := GREATEST(0, TRUNC(SYSDATE) - TRUNC(:NEW.due_date));

    -- Marquage OVERDUE si > 0 jours et pas soldée
    IF v_days_overdue > 0 AND NVL(:NEW.total_paid, 0) < :NEW.total_ttc THEN
      :NEW.status := 'OVERDUE';
    END IF;
  END IF;

  -- Calcul automatique du balance
  :NEW.balance := NVL(:NEW.total_ttc, 0) - NVL(:NEW.total_paid, 0);
END;
/

PROMPT ✓ trg_invoice_overdue créé

-- Test : simuler un update
UPDATE invoice
   SET due_date = SYSDATE - 10
 WHERE invoice_number = 'FA-2026-003';  -- déjà en retard (CLI003)

COMMIT;

PROMPT
PROMPT Vérification : invoice FA-2026-003 doit être OVERDUE
SELECT invoice_number, status, total_ttc, total_paid, balance
  FROM invoice
 WHERE invoice_number = 'FA-2026-003';


PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ TRIGGER trg_invoice_overdue INSTALLÉ
PROMPT ══════════════════════════════════════════════════════════
EXIT;
