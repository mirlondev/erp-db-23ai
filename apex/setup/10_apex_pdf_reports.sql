-- ============================================================
-- APEX SETUP 10 : Templates PDF & Reporting — REGAL
-- ============================================================
-- Crée 6 templates de rapports PDF prêts à l'emploi pour
-- l'impression en boutique Congo (papier A4 / A5 / ticket 80mm) :
--
--   R1. Ticket de caisse (80mm thermal)
--   R2. Facture A4
--   R3. Bon de livraison A5
--   R4. Z de caisse (clôture session)
--   R5. Déclaration TVA mensuelle
--   R6. Bulletin de paie
--
-- APEX 26.1 supporte les PDF via :
--   1) Report Queries + Report Layouts (Classic / Interactive)
--   2) BI Publisher (XML + RTF/XSLX)
--   3) Custom PL/SQL → UTL_FILE
--
-- On stocke ici les définitions dans apex_report_template pour
-- exploitation par l'IDE APEX (Shared Components → Report Layouts).
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF
WHENEVER SQLERROR CONTINUE

CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   APEX SETUP 10 — Templates PDF REGAL
PROMPT ══════════════════════════════════════════════════════════

BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE apex_report_template CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE apex_report_template (
  template_id       NUMBER GENERATED ALWAYS AS IDENTITY,
  template_code     VARCHAR2(40)  NOT NULL,
  template_name     VARCHAR2(120) NOT NULL,
  paper_format      VARCHAR2(10)  NOT NULL,   -- A4, A5, 80mm
  orientation       VARCHAR2(2)   DEFAULT 'P',-- P ou L
  source_query      CLOB,                      -- SQL du rapport
  layout_xml        CLOB,                      -- XML BI Publisher
  layout_format     VARCHAR2(20)  DEFAULT 'RTF', -- RTF/FO/XSLX
  is_active         BOOLEAN       DEFAULT TRUE,
  created_at        TIMESTAMP     DEFAULT SYSTIMESTAMP,
  CONSTRAINT pk_apex_report_tpl PRIMARY KEY (template_id),
  CONSTRAINT uk_apex_report_tpl UNIQUE (template_code)
);

-- ============================================================
-- R1. Ticket de caisse 80mm
-- ============================================================
PROMPT
PROMPT [1/6] R1 — Ticket de caisse 80mm
INSERT INTO apex_report_template (template_code, template_name, paper_format, source_query)
VALUES (
  'TICKET_RECEIPT_80MM',
  'Ticket de caisse thermique 80mm',
  '80mm',
  q'[SELECT t.terminal_id,
            t.ticket_no,
            t.ticket_date,
            t.customer_name,
            tl.product_code,
            p.product_name,
            tl.quantity,
            tl.unit_price,
            tl.amount_ttc,
            t.total_ht,
            t.total_ttc,
            t.tax_amount_1 AS total_tva
       FROM app_sales.ticket t
       JOIN app_sales.ticket_line tl ON tl.terminal_id = t.terminal_id
                                    AND tl.ticket_no   = t.ticket_no
       JOIN app_product.product p   ON p.product_code  = tl.product_code
      WHERE t.terminal_id = :P_TERMINAL
        AND t.ticket_no   = :P_TICKET_NO
      ORDER BY tl.line_no]'
);
COMMIT;

-- ============================================================
-- R2. Facture A4
-- ============================================================
PROMPT
PROMPT [2/6] R2 — Facture A4
INSERT INTO apex_report_template (template_code, template_name, paper_format, orientation, source_query)
VALUES (
  'INVOICE_A4',
  'Facture format A4',
  'A4', 'P',
  q'[SELECT i.invoice_no,
            i.invoice_date,
            i.due_date,
            c.party_code, c.party_name, c.address_1, c.city, c.country,
            c.tax_regime, c.email,
            l.line_no, l.product_code, p.product_name,
            l.quantity, l.unit_price, l.discount_pct,
            l.amount_ht, l.tax_rate, l.tax_amount, l.amount_ttc,
            i.total_ht, i.total_tva, i.total_ttc,
            i.amount_due, i.currency_code
       FROM app_ar.invoice i
       JOIN app_party.party c ON c.party_id = (SELECT party_id FROM app_party.party
                                                 WHERE party_code = i.customer_code)
       JOIN app_ar.invoice_line l ON l.invoice_id = i.invoice_id
       JOIN app_product.product p  ON p.product_code = l.product_code
      WHERE i.invoice_id = :P_INVOICE_ID
      ORDER BY l.line_no]'
);
COMMIT;

-- ============================================================
-- R3. Bon de livraison A5
-- ============================================================
PROMPT
PROMPT [3/6] R3 — Bon de livraison A5
INSERT INTO apex_report_template (template_code, template_name, paper_format, orientation, source_query)
VALUES (
  'DELIVERY_NOTE_A5',
  'Bon de livraison A5',
  'A5', 'P',
  q'[SELECT d.doc_number AS delivery_no,
            d.doc_date,
            c.party_code, c.party_name, c.address_1, c.city,
            dl.line_no, dl.product_code, p.product_name,
            dl.quantity, dl.unit_code,
            w.warehouse_code, w.warehouse_name,
            d.total_qty, d.total_weight
       FROM app_doc.doc_header d
       JOIN app_party.party c  ON c.party_code = d.party_code
       JOIN app_doc.doc_line dl ON dl.doc_id = d.doc_id
       JOIN app_product.product p ON p.product_code = dl.product_code
       JOIN app_org.org_warehouse w ON w.warehouse_id = d.warehouse_id
      WHERE d.doc_type = 'BON'
        AND d.doc_id   = :P_DOC_ID
      ORDER BY dl.line_no]'
);
COMMIT;

-- ============================================================
-- R4. Z de caisse
-- ============================================================
PROMPT
PROMPT [4/6] R4 — Z de caisse (clôture session)
INSERT INTO apex_report_template (template_code, template_name, paper_format, source_query)
VALUES (
  'POS_SESSION_Z',
  'Z de caisse — Clôture session',
  'A4',
  q'[SELECT s.terminal_id, s.session_no, s.user_code,
            s.opened_at, s.closed_at,
            s.opening_balance, s.closing_balance, s.theoretical_balance,
            (s.closing_balance - s.theoretical_balance) AS ecart,
            t.terminal_name, t.warehouse_code,
            (SELECT COUNT(*) FROM app_sales.ticket tk
              WHERE tk.terminal_id = t.terminal_code
                AND tk.session_no  = s.session_no) AS nb_tickets,
            (SELECT NVL(SUM(total_ht),  0) FROM app_sales.ticket tk
              WHERE tk.terminal_id = t.terminal_code
                AND tk.session_no  = s.session_no) AS ca_ht,
            (SELECT NVL(SUM(total_ttc), 0) FROM app_sales.ticket tk
              WHERE tk.terminal_id = t.terminal_code
                AND tk.session_no  = s.session_no) AS ca_ttc,
            (SELECT NVL(SUM(tax_amount_1), 0) FROM app_sales.ticket tk
              WHERE tk.terminal_id = t.terminal_code
                AND tk.session_no  = s.session_no) AS ca_tva
       FROM app_pos.pos_session s
       JOIN app_pos.pos_terminal t ON t.terminal_id = s.terminal_id
      WHERE s.terminal_id = :P_TERMINAL_ID
        AND s.session_no  = :P_SESSION_NO]'
);
COMMIT;

-- ============================================================
-- R5. Déclaration TVA mensuelle Congo
-- ============================================================
PROMPT
PROMPT [5/6] R5 — Déclaration TVA mensuelle CG (18.9%)
INSERT INTO apex_report_template (template_code, template_name, paper_format, source_query)
VALUES (
  'TVA_DECLARATION_CG',
  'Déclaration TVA mensuelle Congo (DGID)',
  'A4',
  q'[SELECT d.declaration_ref,
            d.period_start, d.period_end,
            d.jurisdiction, d.company_code,
            d.base_amount AS base_ht_total,
            d.tax_due AS tva_collectee,
            d.amount_payable AS net_a_payer,
            d.status,
            l.line_no, l.rate_type, l.rate, l.base_amount, l.tax_amount,
            l.deductible_base, l.deductible_tax,
            f.form_code, f.form_label
       FROM app_gl.tax_declaration d
       JOIN app_gl.tax_declaration_line l ON l.declaration_id = d.declaration_id
       JOIN app_gl.tax_form_type f        ON f.form_type_id    = d.form_type_id
      WHERE d.declaration_id = :P_DECLARATION_ID
      ORDER BY l.line_no]'
);
COMMIT;

-- ============================================================
-- R6. Bulletin de paie Congo
-- ============================================================
PROMPT
PROMPT [6/6] R6 — Bulletin de paie LITOKO
INSERT INTO apex_report_template (template_code, template_name, paper_format, source_query)
VALUES (
  'PAYSLIP_CG',
  'Bulletin de paie Congo (LITOKO)',
  'A4',
  q'[SELECT e.matricule, e.full_name, e.position, e.category,
            e.contract_type, e.hire_date,
            e.monthly_salary_brut,
            e.company_code,
            p.period_start, p.period_end,
            p.cnss_salarie, p.cnss_patron,
            p.irpp_brut, p.irpp_net,
            p.salaire_net,
            p.montant_a_payer,
            p.rib_bancaire,
            p.cnss_no
       FROM app_hr.mpf_employee e
       JOIN app_hr.mpf_payslip p ON p.matricule = e.matricule
      WHERE p.payslip_id = :P_PAYSLIP_ID]'
);
COMMIT;

PROMPT
PROMPT ═══ Validation ═══
SELECT template_id, template_code, template_name, paper_format
  FROM apex_report_template
 ORDER BY template_id;

PROMPT
PROMPT ═══ Test : liste les colonnes d'un template ═══
DECLARE
  v_query CLOB;
BEGIN
  SELECT source_query INTO v_query
    FROM apex_report_template
   WHERE template_code = 'TICKET_RECEIPT_80MM';
  DBMS_OUTPUT.PUT_LINE('TICKET_RECEIPT_80MM (extrait) :');
  DBMS_OUTPUT.PUT_LINE(SUBSTR(v_query, 1, 200) || '...');
END;
/

-- ============================================================
-- 7) Fonction helper : récupère le source_query
-- ============================================================
PROMPT
PROMPT [7] Package apex_report_api
CREATE OR REPLACE PACKAGE apex_report_api AS
  FUNCTION get_query(p_template_code VARCHAR2) RETURN CLOB;
  FUNCTION get_layout(p_template_code VARCHAR2) RETURN CLOB;
  FUNCTION get_format(p_template_code VARCHAR2) RETURN VARCHAR2;
END apex_report_api;
/

CREATE OR REPLACE PACKAGE BODY apex_report_api AS
  FUNCTION get_query(p_template_code VARCHAR2) RETURN CLOB IS
    v_q CLOB;
  BEGIN
    SELECT source_query INTO v_q
      FROM apex_report_template
     WHERE template_code = p_template_code AND is_active = 'Y';
    RETURN v_q;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    RETURN 'SELECT ''TEMPLATE_NOT_FOUND'' AS d FROM DUAL';
  END get_query;

  FUNCTION get_layout(p_template_code VARCHAR2) RETURN CLOB IS
    v_l CLOB;
  BEGIN
    SELECT layout_xml INTO v_l
      FROM apex_report_template
     WHERE template_code = p_template_code AND is_active = 'Y';
    RETURN v_l;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    RETURN NULL;
  END get_layout;

  FUNCTION get_format(p_template_code VARCHAR2) RETURN VARCHAR2 IS
    v_f VARCHAR2(20);
  BEGIN
    SELECT layout_format INTO v_f
      FROM apex_report_template
     WHERE template_code = p_template_code AND is_active = 'Y';
    RETURN v_f;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    RETURN 'RTF';
  END get_format;
END apex_report_api;
/
GRANT EXECUTE ON apex_report_api TO app_sales, app_inv, app_purchase, app_gl, app_hr, app_ar;

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ APEX SETUP 10 — 6 templates PDF
PROMPT   - Ticket 80mm, Facture A4, BL A5
PROMPT   - Z caisse, TVA CG, Bulletin paie
PROMPT ══════════════════════════════════════════════════════════
EXIT;
