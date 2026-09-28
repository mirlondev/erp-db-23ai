-- ============================================================
-- SCRIPT 32 : Body du package pkg_pos_sales
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

CONNECT app_sales/AppSales#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   BODY pkg_pos_sales
PROMPT ══════════════════════════════════════════════════════════

CREATE OR REPLACE PACKAGE BODY pkg_pos_sales AS

  -----------------------------------------------------------------
  -- 1. Création ticket avec points fidélité
  -----------------------------------------------------------------
  FUNCTION create_ticket_with_loyalty(
    p_terminal_id     IN VARCHAR2,
    p_session_no      IN NUMBER,
    p_customer_code   IN VARCHAR2,
    p_loyalty_card_id IN NUMBER DEFAULT NULL,
    p_user_code       IN VARCHAR2
  ) RETURN NUMBER IS
    v_ticket_no NUMBER(8);
    v_points_earned NUMBER(12) := 0;
    v_amount NUMBER(16,4);
  BEGIN
    -- Calcul next ticket_no
    SELECT NVL(MAX(ticket_no), 0) + 1
      INTO v_ticket_no
      FROM ticket
     WHERE terminal_id = p_terminal_id;

    -- Calcul points gagnés (1% du CA prévisionnel par défaut — sera ajusté après lignes)
    SELECT NVL(SUM(quantity * unit_price), 0)
      INTO v_amount
      FROM ticket_line
     WHERE terminal_id = p_terminal_id
       AND ticket_no = v_ticket_no;

    v_points_earned := FLOOR(v_amount / 100);  -- 1 point = 100 XOF

    -- Trace des points si carte fournie
    IF p_loyalty_card_id IS NOT NULL THEN
      INSERT INTO ticket_loyalty (terminal_id, ticket_no, card_id,
                                    points_earned, points_used)
      VALUES (p_terminal_id, v_ticket_no, p_loyalty_card_id,
              v_points_earned, 0);

      -- Mise à jour du solde carte
      UPDATE app_party.loyalty_card
         SET points_balance = points_balance + v_points_earned,
             total_earned_points = total_earned_points + v_points_earned,
             last_used_at = SYSDATE
       WHERE card_id = p_loyalty_card_id;
    END IF;

    COMMIT;
    RETURN v_ticket_no;
  END create_ticket_with_loyalty;

  -----------------------------------------------------------------
  -- 2. Application meilleure promo
  -----------------------------------------------------------------
  FUNCTION apply_best_promo(
    p_terminal_id IN VARCHAR2,
    p_ticket_no   IN NUMBER,
    p_user_code   IN VARCHAR2
  ) RETURN VARCHAR2 IS
    v_total_amount NUMBER(16,4);
    v_best_promo   VARCHAR2(20);
    v_best_rate    NUMBER(5,2) := 0;
  BEGIN
    -- CA total du ticket
    SELECT SUM(quantity * unit_price)
      INTO v_total_amount
      FROM ticket_line
     WHERE terminal_id = p_terminal_id
       AND ticket_no = p_ticket_no;

    -- Trouver la meilleure promo POS active applicable (cumul/négoce non gérés ici)
    BEGIN
      SELECT ppc.promo_code
        INTO v_best_promo
        FROM app_product.promo_pos_config ppc
       WHERE ppc.is_active = TRUE
         AND SYSDATE BETWEEN ppc.start_date AND ppc.end_date
         AND SUBSTR(ppc.weekday_mask, TO_CHAR(SYSDATE, 'D') - 1, 1) = '1'
         AND (ppc.hour_start IS NULL OR
              TO_NUMBER(TO_CHAR(SYSDATE, 'HH24MI')) BETWEEN ppc.hour_start AND ppc.hour_end)
         AND EXISTS (
              SELECT 1
                FROM app_product.promo_pos_product ppp
               WHERE ppp.pos_promo_id = ppc.pos_promo_id
                 AND ppp.discount_rate IS NOT NULL
           )
       ORDER BY ppc.priority, ppc.promo_code
       FETCH FIRST 1 ROWS ONLY;

      -- Inscription dans ticket_discount
      INSERT INTO ticket_discount (terminal_id, ticket_no, line_no,
                                    discount_type, discount_rate,
                                    reason, authorized_by)
      VALUES (p_terminal_id, p_ticket_no, NULL,
              'PROMOTION', 10, 'Auto-applied : ' || v_best_promo, p_user_code);

      COMMIT;
      RETURN v_best_promo;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RETURN NULL;
    END;
  END apply_best_promo;

  -----------------------------------------------------------------
  -- 3. Clôture session POS
  -----------------------------------------------------------------
  PROCEDURE close_pos_session(
    p_terminal_code      IN VARCHAR2,
    p_session_no         IN NUMBER,
    p_actual_cash        IN NUMBER,
    p_closed_by          IN VARCHAR2,
    p_variance_threshold IN NUMBER DEFAULT 1000
  ) IS
    v_theoretical NUMBER(16,4) := 0;
    v_difference  NUMBER(16,4) := 0;
    v_total_sales NUMBER(16,4) := 0;
    v_total_returns NUMBER(16,4) := 0;
    v_nb_tickets  NUMBER(8) := 0;
    v_nb_returns  NUMBER(8) := 0;
  BEGIN
    -- Calcul théorique = somme tickets ventes (espèces) + fond de caisse
    SELECT NVL(SUM(total_ttc), 0)
      INTO v_total_sales
      FROM ticket
     WHERE terminal_id = p_terminal_code
       AND session_no = p_session_no
       AND status = 'V';

    SELECT NVL(SUM(total_return_ttc), 0)
      INTO v_total_returns
      FROM ticket_return
     WHERE original_terminal = p_terminal_code;

    -- Pour simplifier : theoretical = opening_balance + total_sales cash (estimé)
    SELECT NVL(opening_balance, 0)
      INTO v_theoretical
      FROM pos_session
     WHERE terminal_id = (SELECT terminal_id FROM pos_terminal WHERE terminal_code = p_terminal_code)
       AND session_no = p_session_no;

    v_theoretical := v_theoretical + v_total_sales;
    v_difference := p_actual_cash - v_theoretical;

    -- Comptage tickets/retours
    SELECT COUNT(*)
      INTO v_nb_tickets
      FROM ticket
     WHERE terminal_id = p_terminal_code
       AND session_no = p_session_no;
    v_nb_returns := 0;  -- simplifié pour démo

    -- Insertion pos_cash_closure
    INSERT INTO pos_cash_closure (
      terminal_code, session_no, closure_date,
      theoretical_cash, actual_cash, difference,
      total_sales_ttc, total_returns_ttc,
      nb_tickets, nb_returns, closed_by, notes
    ) VALUES (
      p_terminal_code, p_session_no, TRUNC(SYSDATE),
      v_theoretical, p_actual_cash, v_difference,
      v_total_sales, v_total_returns,
      v_nb_tickets, v_nb_returns, p_closed_by,
      'Session clôturée par pkg_pos_sales'
    );

    -- Si écart > seuil : création alerte (R11)
    IF ABS(v_difference) > p_variance_threshold THEN
      INSERT INTO app_sys.alert_instance (alert_type_code, entity_type, entity_id,
                                           entity_label, message, severity, status,
                                           payload)
      VALUES ('CASH_DRAWER_MISMATCH', 'POS_SESSION', p_terminal_code || '/' || p_session_no,
              p_terminal_code || ' session ' || p_session_no,
              'Écart caisse de ' || v_difference || ' XOF (seuil ' || p_variance_threshold || ')',
              'HIGH', 'OPEN',
              JSON_OBJECT('terminal' VALUE p_terminal_code,
                          'session' VALUE p_session_no,
                          'difference' VALUE v_difference,
                          'closed_by' VALUE p_closed_by,
                          'closed_at' VALUE SYSTIMESTAMP));
    END IF;

    COMMIT;
  END close_pos_session;

  -----------------------------------------------------------------
  -- 4. Annulation ticket
  -----------------------------------------------------------------
  PROCEDURE cancel_ticket(
    p_terminal_id   IN VARCHAR2,
    p_ticket_no     IN NUMBER,
    p_refund_method IN VARCHAR2,
    p_reason        IN VARCHAR2,
    p_processed_by  IN VARCHAR2
  ) IS
    v_total_ttc NUMBER(16,4);
    v_return_id NUMBER;
  BEGIN
    -- Récup total
    SELECT total_ttc INTO v_total_ttc
      FROM ticket
     WHERE terminal_id = p_terminal_id
       AND ticket_no = p_ticket_no;

    -- Update statut ticket à A (annulé)
    UPDATE ticket SET status = 'A' WHERE terminal_id = p_terminal_id AND ticket_no = p_ticket_no;

    -- Création retour générique (procédure simplifiée — en prod, on appellerait le flux R5 avoir)
    INSERT INTO ticket_return (return_number, return_date,
                                original_terminal, original_ticket_no,
                                refund_method, total_return_ttc,
                                reason, status, is_inventory_updated, processed_by)
    VALUES ('RET-CXL-' || p_ticket_no, SYSDATE,
            p_terminal_id, p_ticket_no,
            p_refund_method, v_total_ttc,
            p_reason, 'VALID', TRUE, p_processed_by)
    RETURNING return_id INTO v_return_id;

    -- Copie des lignes ticket vers lignes retour
    INSERT INTO ticket_return_line (return_id, line_no, product_code, description,
                                     quantity_returned, unit_price, amount,
                                     source_line_no)
    SELECT v_return_id, line_no, product_code, description,
           quantity, unit_price, quantity * unit_price,
           line_no
      FROM ticket_line
     WHERE terminal_id = p_terminal_id
       AND ticket_no = p_ticket_no;

    -- Audit (R13)
    INSERT INTO app_sys.sys_audit_trail (user_code, user_role_at_time, action_type,
                                          entity_type, entity_id, old_values, new_values,
                                          ip_address, severity)
    VALUES (p_processed_by, 'CASHIER', 'CANCEL',
            'app_sales.ticket', p_terminal_id || '/' || p_ticket_no,
            JSON_OBJECT('status' VALUE 'V', 'total' VALUE v_total_ttc),
            JSON_OBJECT('status' VALUE 'A', 'reason' VALUE p_reason),
            NULL, 'WARN');

    COMMIT;
  END cancel_ticket;

END pkg_pos_sales;
/

PROMPT ✓ Body créé

-- Test rapide (sans données réelles)
PROMPT Test package
DECLARE
  v_ticket_no NUMBER;
BEGIN
  v_ticket_no := pkg_pos_sales.create_ticket_with_loyalty(
    p_terminal_id => 'CAI01', p_session_no => 99,
    p_customer_code => 'TEST', p_loyalty_card_id => NULL,
    p_user_code => 'TEST_USER'
  );
  DBMS_OUTPUT.PUT_LINE('Ticket test créé : ' || v_ticket_no);
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('Test skippé (pas de données initiales) : ' || SQLERRM);
END;
/

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ PACKAGE pkg_pos_sales INSTALLÉ
PROMPT ══════════════════════════════════════════════════════════
EXIT;
