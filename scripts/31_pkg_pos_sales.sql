-- ============================================================
-- SCRIPT 31 : Package pkg_pos_sales — Enrichissement POS
-- ============================================================
-- Ops POS haut-niveau orchestrant ticket+promo+loyalty côté PL/SQL :
--   - create_ticket_with_loyalty : crée ticket + applique points + met à jour stock
--   - apply_promo_to_ticket       : applique la meilleure promo applicable
--   - close_pos_session           : génère pos_cash_closure + création alertes écart
--   - cancel_ticket               : annule ticket + restaure stock + génère avoir
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

CONNECT app_sales/AppSales#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   PACKAGE pkg_pos_sales
PROMPT ══════════════════════════════════════════════════════════

CREATE OR REPLACE PACKAGE pkg_pos_sales AS
  -- Crée un ticket complet avec calcul automatique des remises + points fidélité
  FUNCTION create_ticket_with_loyalty(
    p_terminal_id    IN VARCHAR2,
    p_session_no     IN NUMBER,
    p_customer_code  IN VARCHAR2,
    p_loyalty_card_id IN NUMBER DEFAULT NULL,
    p_user_code      IN VARCHAR2
  ) RETURN NUMBER;  -- retourne ticket_no

  -- Applique la meilleure promotion applicable au ticket
  FUNCTION apply_best_promo(
    p_terminal_id IN VARCHAR2,
    p_ticket_no   IN NUMBER,
    p_user_code   IN VARCHAR2
  ) RETURN VARCHAR2;  -- promo_code appliquée, ou NULL

  -- Clôture la session POS + calcule écart + crée alerte si écart > seuil
  PROCEDURE close_pos_session(
    p_terminal_code IN VARCHAR2,
    p_session_no    IN NUMBER,
    p_actual_cash   IN NUMBER,
    p_closed_by     IN VARCHAR2,
    p_variance_threshold IN NUMBER DEFAULT 1000
  );

  -- Annulation ticket : restaure stock + génère avoir si refund_method=CASH
  PROCEDURE cancel_ticket(
    p_terminal_id   IN VARCHAR2,
    p_ticket_no     IN NUMBER,
    p_refund_method IN VARCHAR2,
    p_reason        IN VARCHAR2,
    p_processed_by  IN VARCHAR2
  );
END pkg_pos_sales;
/

PROMPT ✓ Spec créée
