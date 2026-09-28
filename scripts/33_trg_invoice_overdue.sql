-- ============================================================
-- SCRIPT 33 : Trigger trg_invoice_overdue + extensions
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

-- =====================================================
-- Droits croisés
-- =====================================================
CONNECT system/oracle@localhost:1521/FREEPDB1

-- (déjà accordés par le script 21 mais on reste idempotent)
BEGIN EXECUTE IMMEDIATE 'GRANT SELECT, UPDATE ON app_ar.invoice TO app_ar'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'GRANT SELECT ON app_party.party TO app_ar';         EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- =====================================================
-- Trigger : auto-update statut OVERDUE
-- =====================================================
CONNECT app_ar/AppAr#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   TRIGGER trg_invoice_overdue
PROMPT ══════════════════════════════════════════════════════════

-- Drop tolérant : peu importe le code d'erreur, on continue
BEGIN
  EXECUTE IMMEDIATE 'DROP TRIGGER trg_invoice_overdue';
  DBMS_OUTPUT.PUT_LINE('  → Ancien trigger supprimé');
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('  → Pas de trigger existant, on continue (' || SQLCODE || ')');
END;
/

CREATE OR REPLACE TRIGGER trg_invoice_overdue
BEFORE INSERT OR UPDATE OF due_date, total_paid, total_ttc ON invoice
FOR EACH ROW
DECLARE
  v_days_overdue NUMBER := 0;
BEGIN
  -- 1) Calcul du balance TOUJOURS
  :NEW.balance := NVL(:NEW.total_ttc, 0) - NVL(:NEW.total_paid, 0);

  -- 2) Si soldé → statut PAID (sauf si annulé)
  IF NVL(:NEW.total_paid, 0) >= NVL(:NEW.total_ttc, 0)
     AND NVL(:NEW.total_ttc, 0) > 0
     AND :NEW.status NOT IN ('CANCELLED','DRAFT') THEN
    :NEW.status := 'PAID';
    RETURN;
  END IF;

  -- 3) Sinon, calcul du retard
  IF :NEW.due_date IS NOT NULL
     AND :NEW.status IN ('VALID','PARTIAL','OVERDUE','PAID') THEN
    v_days_overdue := GREATEST(0, TRUNC(SYSDATE) - TRUNC(:NEW.due_date));

    IF v_days_overdue > 0 AND NVL(:NEW.total_paid, 0) < :NEW.total_ttc THEN
      :NEW.status := 'OVERDUE';
    ELSIF v_days_overdue = 0
          AND :NEW.status = 'OVERDUE'
          AND NVL(:NEW.total_paid, 0) > 0 THEN
      :NEW.status := 'PARTIAL';
    END IF;
  END IF;
END;
/

PROMPT ✓ trg_invoice_overdue créé

-- =====================================================
-- Test
-- =====================================================
UPDATE invoice
   SET due_date = SYSDATE - 10
 WHERE invoice_number = 'FA-2026-003';

COMMIT;

PROMPT
PROMPT Vérification : FA-2026-003 doit être OVERDUE
SELECT invoice_number, status, total_ttc, total_paid, balance
  FROM invoice
 WHERE invoice_number = 'FA-2026-003';

PROMPT
PROMPT État du trigger
SELECT trigger_name, status
  FROM user_triggers
 WHERE trigger_name = 'TRG_INVOICE_OVERDUE';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ TRIGGER trg_invoice_overdue INSTALLÉ
PROMPT ══════════════════════════════════════════════════════════
EXIT;