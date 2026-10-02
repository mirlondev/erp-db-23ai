-- ============================================================
-- SCRIPT 41 : Body du package pkg_doc
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

CONNECT app_doc/AppDoc#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   BODY pkg_doc
PROMPT ══════════════════════════════════════════════════════════

CREATE OR REPLACE PACKAGE BODY pkg_doc AS

  -----------------------------------------------------------------
  -- 1. Création devis avec entête + recalcul auto des totaux
  -----------------------------------------------------------------
  FUNCTION create_quote(
    p_company_code   IN VARCHAR2,
    p_party_code     IN VARCHAR2,
    p_party_name     IN VARCHAR2,
    p_currency_code  IN VARCHAR2 DEFAULT 'XOF',
    p_user_code      IN VARCHAR2
  ) RETURN NUMBER IS
    v_doc_id NUMBER;
    v_doc_no NUMBER(8);
  BEGIN
    -- Génération n° doc (compteur simple)
    SELECT NVL(MAX(doc_no), 0) + 1
      INTO v_doc_no
      FROM doc_header
     WHERE doc_type_code = 'QUOTE';

    INSERT INTO doc_header (
      doc_type_code, doc_no, company_code,
      doc_date, party_code, party_name,
      currency_code, status, created_by
    ) VALUES (
      'QUOTE', v_doc_no, p_company_code,
      SYSDATE, p_party_code, p_party_name,
      p_currency_code, 'DRAFT', p_user_code
    ) RETURNING doc_id INTO v_doc_id;

    -- Audit
    INSERT INTO app_sys.sys_audit_trail (user_code, action_type, entity_type, entity_id, new_values)
    VALUES (p_user_code, 'CREATE', 'app_doc.doc_header', TO_CHAR(v_doc_id),
            JSON_OBJECT('doc_type' VALUE 'QUOTE', 'party' VALUE p_party_code));

    COMMIT;
    RETURN v_doc_id;
  END create_quote;

  -----------------------------------------------------------------
  -- 2. Conversion devis → commande
  -----------------------------------------------------------------
  FUNCTION convert_quote_to_order(
    p_quote_doc_id IN NUMBER,
    p_user_code    IN VARCHAR2
  ) RETURN NUMBER IS
    v_new_doc_id  NUMBER;
    v_new_doc_no  NUMBER(8);
    v_company     VARCHAR2(12);
    v_party_code  VARCHAR2(32);
    v_party_name  VARCHAR2(120);
    v_currency    VARCHAR2(12);
    v_price_list  VARCHAR2(8);
  BEGIN
    -- Lecture entête devis
    SELECT company_code, party_code, party_name, currency_code, price_list_code
      INTO v_company, v_party_code, v_party_name, v_currency, v_price_list
      FROM doc_header
     WHERE doc_id = p_quote_doc_id
       AND doc_type_code = 'QUOTE';

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20001, 'Devis introuvable ou type incorrect');
    END IF;

    -- Génération n° commande
    SELECT NVL(MAX(doc_no), 0) + 1
      INTO v_new_doc_no
      FROM doc_header
     WHERE doc_type_code = 'PURCHASE';

    -- Création entête nouvelle commande
    INSERT INTO doc_header (
      doc_type_code, doc_no, company_code,
      doc_date, party_code, party_name,
      currency_code, price_list_code, status, created_by,
      document_ref
    ) VALUES (
      'PURCHASE', v_new_doc_no, v_company,
      SYSDATE, v_party_code, v_party_name,
      v_currency, v_price_list, 'DRAFT', p_user_code,
      'QUOTE-' || p_quote_doc_id
    ) RETURNING doc_id INTO v_new_doc_id;

    -- Copie des lignes
    INSERT INTO doc_line (doc_id, line_no, order_no, doc_type_code,
                          warehouse_code, product_code, description_1, description_2,
                          quantity, unit_code, unit_price, amount, sale_price,
                          line_type, unit_price_ht, amount_ht,
                          coefficient, tax_rate, tax_amount)
    SELECT v_new_doc_id, line_no, order_no, 'PURCHASE',
           warehouse_code, product_code, description_1, description_2,
           quantity, unit_code, unit_price, amount, sale_price,
           line_type, unit_price_ht, amount_ht,
           coefficient, tax_rate, tax_amount
      FROM doc_line
     WHERE doc_id = p_quote_doc_id;

    -- Lien inter-documents
    INSERT INTO doc_commercial_link (source_doc_id, source_doc_type, target_doc_id, target_doc_type, link_type, created_by)
    VALUES (p_quote_doc_id, 'QUOTE', v_new_doc_id, 'PURCHASE', 'TRANSFORM', p_user_code);

    -- Audit
    INSERT INTO app_sys.sys_audit_trail (user_code, action_type, entity_type, entity_id, new_values)
    VALUES (p_user_code, 'UPDATE', 'app_doc.doc_header', TO_CHAR(v_new_doc_id),
            JSON_OBJECT('from_doc' VALUE p_quote_doc_id, 'transformation' VALUE 'QUOTE_TO_PURCHASE'));

    COMMIT;
    RETURN v_new_doc_id;
  END convert_quote_to_order;

  -----------------------------------------------------------------
  -- 3. Validation document : recalcul totaux + status DRAFT→VALID
  -----------------------------------------------------------------
  PROCEDURE validate_document(
    p_doc_id    IN NUMBER,
    p_user_code IN VARCHAR2
  ) IS
    v_total_ht  NUMBER(16,4);
    v_total_tax NUMBER(16,4);
    v_total_ttc NUMBER(16,4);
  BEGIN
    -- Recalcul totaux depuis les lignes
    SELECT NVL(SUM(amount_ht), 0), NVL(SUM(tax_amount), 0), NVL(SUM(amount), 0)
      INTO v_total_ht, v_total_tax, v_total_ttc
      FROM doc_line
     WHERE doc_id = p_doc_id;

    -- Update entête
    UPDATE doc_header
       SET total_ht    = v_total_ht,
           total_tax_1 = v_total_tax,
           total_ttc   = v_total_ttc,
           status      = 'VALID',
           updated_by  = p_user_code,
           updated_at  = SYSDATE
     WHERE doc_id = p_doc_id
       AND status = 'DRAFT';

    -- Si c'est une vente (type=SALE), décrémente le stock via trigger existant
    -- (déjà géré par trg_ticket_line_after_insert si c'est un ticket)

    -- Audit
    INSERT INTO app_sys.sys_audit_trail (user_code, action_type, entity_type, entity_id, old_values, new_values)
    VALUES (p_user_code, 'UPDATE', 'app_doc.doc_header', TO_CHAR(p_doc_id),
            JSON_OBJECT('status' VALUE 'DRAFT'),
            JSON_OBJECT('status' VALUE 'VALID', 'total_ttc' VALUE v_total_ttc));

    COMMIT;
  END validate_document;

  -----------------------------------------------------------------
  -- 4. Annulation document
  -----------------------------------------------------------------
  PROCEDURE cancel_document(
    p_doc_id    IN NUMBER,
    p_reason    IN VARCHAR2,
    p_user_code IN VARCHAR2
  ) IS
    v_status     VARCHAR2(20);
    v_doc_type   VARCHAR2(20);
  BEGIN
    SELECT status, doc_type_code INTO v_status, v_doc_type
      FROM doc_header WHERE doc_id = p_doc_id;

    IF v_status = 'CANCELLED' THEN
      RAISE_APPLICATION_ERROR(-20002, 'Document déjà annulé');
    END IF;

    UPDATE doc_header
       SET status     = 'CANCELLED',
           memo       = SUBSTR(memo || ' | ANNULÉ: ' || p_reason, 1, 4000),
           updated_by = p_user_code,
           updated_at = SYSDATE
     WHERE doc_id = p_doc_id;

    -- Log
    INSERT INTO doc_log (doc_id, operation_at, user_code, operation_label)
    VALUES (p_doc_id, SYSDATE, p_user_code, 'ANNULÉ: ' || p_reason);

    -- Audit
    INSERT INTO app_sys.sys_audit_trail (user_code, action_type, entity_type, entity_id,
                                  old_values, new_values, severity)
    VALUES (p_user_code, 'CANCEL', 'app_doc.doc_header', TO_CHAR(p_doc_id),
            JSON_OBJECT('status' VALUE v_status),
            JSON_OBJECT('status' VALUE 'CANCELLED', 'reason' VALUE p_reason),
            'WARN');

    COMMIT;
  END cancel_document;

  -----------------------------------------------------------------
  -- 5. Lien inter-documents
  -----------------------------------------------------------------
  FUNCTION link_documents(
    p_source_doc_id   IN NUMBER,
    p_target_doc_id   IN NUMBER,
    p_link_type       IN VARCHAR2,
    p_user_code       IN VARCHAR2
  ) RETURN NUMBER IS
    v_link_id  NUMBER;
    v_src_type VARCHAR2(20);
    v_tgt_type VARCHAR2(20);
  BEGIN
    SELECT doc_type_code INTO v_src_type FROM doc_header WHERE doc_id = p_source_doc_id;
    SELECT doc_type_code INTO v_tgt_type FROM doc_header WHERE doc_id = p_target_doc_id;

    INSERT INTO doc_commercial_link (
      source_doc_id, source_doc_type,
      target_doc_id, target_doc_type,
      link_type, created_by
    ) VALUES (
      p_source_doc_id, v_src_type,
      p_target_doc_id, v_tgt_type,
      p_link_type, p_user_code
    ) RETURNING link_id INTO v_link_id;

    COMMIT;
    RETURN v_link_id;
  END link_documents;

END pkg_doc;
/

PROMPT ✓ Body pkg_doc créé

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ PACKAGE pkg_doc INSTALLÉ
PROMPT ══════════════════════════════════════════════════════════
EXIT;
