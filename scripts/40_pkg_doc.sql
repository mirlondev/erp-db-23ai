-- ============================================================
-- SCRIPT 40 : Package pkg_doc — API haut-niveau documents
-- ============================================================
-- Ops sur documents commerciaux :
--   - create_quote : crée devis (type=QUOTE) + génère doc_lines
--   - convert_quote_to_order : transforme devis en commande
--   - validate_document : passe DRAFT → VALID avec recalcul totaux + audit
--   - cancel_document : annule document + restore stock si applicable
--   - link_documents : crée doc_commercial_link entre 2 docs
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

CONNECT app_doc/AppDoc#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   PACKAGE pkg_doc
PROMPT ══════════════════════════════════════════════════════════

CREATE OR REPLACE PACKAGE pkg_doc AS
  -- Crée un devis avec ses lignes (montants HT/TTC auto-calculés)
  FUNCTION create_quote(
    p_company_code   IN VARCHAR2,
    p_party_code     IN VARCHAR2,
    p_party_name     IN VARCHAR2,
    p_currency_code  IN VARCHAR2 DEFAULT 'XOF',
    p_user_code      IN VARCHAR2
  ) RETURN NUMBER;  -- retourne doc_id

  -- Convertit un devis (type=QUOTE) en commande (type=PURCHASE)
  FUNCTION convert_quote_to_order(
    p_quote_doc_id IN NUMBER,
    p_user_code    IN VARCHAR2
  ) RETURN NUMBER;  -- retourne doc_id de la commande créée

  -- Valide un document : recalcule totaux + passe status DRAFT → VALID
  PROCEDURE validate_document(
    p_doc_id    IN NUMBER,
    p_user_code IN VARCHAR2
  );

  -- Annule un document (DRAFT/VALID → CANCELLED) + restore stock si ventes
  PROCEDURE cancel_document(
    p_doc_id    IN NUMBER,
    p_reason    IN VARCHAR2,
    p_user_code IN VARCHAR2
  );

  -- Crée un lien entre 2 documents (TRANSFORM / REFERENCE / COPY)
  FUNCTION link_documents(
    p_source_doc_id   IN NUMBER,
    p_target_doc_id   IN NUMBER,
    p_link_type       IN VARCHAR2,
    p_user_code       IN VARCHAR2
  ) RETURN NUMBER;
END pkg_doc;
/

PROMPT ✓ Spec pkg_doc créée
