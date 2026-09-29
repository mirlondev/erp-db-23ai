-- ============================================================
-- 47b : Création de app_gl.tax_form_type (si absent)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

CONNECT app_gl/AppGl#2026@localhost:1521/FREEPDB1

DECLARE
  v_cnt NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_cnt FROM user_tables WHERE table_name = 'TAX_FORM_TYPE';
  IF v_cnt = 0 THEN
    EXECUTE IMMEDIATE '
      CREATE TABLE tax_form_type (
        form_type_id    NUMBER GENERATED ALWAYS AS IDENTITY,
        form_code       VARCHAR2(20)  NOT NULL,
        form_label      VARCHAR2(120) NOT NULL,
        form_type       VARCHAR2(20)  NOT NULL,
        frequency       VARCHAR2(20)  NOT NULL,
        jurisdiction    VARCHAR2(20)  NOT NULL,
        base_amount     NUMBER(16,4)  NOT NULL,
        rate            NUMBER(7,4),
        legal_basis     VARCHAR2(255),
        due_day         NUMBER(2),
        CONSTRAINT pk_tax_form_type      PRIMARY KEY (form_type_id),
        CONSTRAINT uk_tax_form_code      UNIQUE (form_code, jurisdiction),
        CONSTRAINT ck_tax_form_type_kind CHECK (form_type IN
          (''TVA'',''IS'',''IR'',''AAS'',''PATENTE'',''CESS'',''TAXE_HABITATION'',''FORM_UNIQUE'',''OTHER'')),
        CONSTRAINT ck_tax_form_frequency CHECK (frequency IN
          (''MONTHLY'',''QUARTERLY'',''ANNUAL'',''EVENT'',''BIANNUAL''))
      )';
    DBMS_OUTPUT.PUT_LINE('  -> tax_form_type créée');
  ELSE
    DBMS_OUTPUT.PUT_LINE('  -> tax_form_type existe déjà');
  END IF;
END;
/
EXIT;