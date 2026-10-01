-- ============================================================
-- S32 : Re-seed des modules avancés avec les VRAIS codes existants
-- ============================================================
-- Les seeds S23-S31 référençaient des codes inventés (DEP01, DEP02, POS01)
-- qui n'existent pas en DB. Ce script :
--
--   1. Liste les vrais codes en DB (W90 = entrepôt unique + 5 caisses FP1/B01/...)
--   2. Re-seed transfer_header/line avec ces codes
--   3. Re-seed OHADA immobilisations + déclarations (compatible v9 sans conflit)
--   4. Re-seed sys_message (démo si vide)
--   5. Re-seed outbox_event (3 events)
--   6. Re-seed transfer2 (DEP01 si manquant — on l'ajoute)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF
WHENEVER SQLERROR CONTINUE

PROMPT ══════════════════════════════════════════════════════════
PROMPT   RE-SEED avec codes RÉELS (W90, FP1, B01, ...)
PROMPT ══════════════════════════════════════════════════════════

-- ============================================================
-- ÉTAPE 0 : Inventaire des codes réels
-- ============================================================
PROMPT
PROMPT [0/8] Inventaire des codes réels en DB
CONNECT app_org/AppOrg#2026@localhost:1521/FREEPDB1
SELECT warehouse_code, warehouse_name FROM org_warehouse ORDER BY warehouse_code;

CONNECT app_pos/AppPos#2026@localhost:1521/FREEPDB1
SELECT terminal_code, terminal_name, warehouse_code, pos_code FROM pos_terminal ORDER BY terminal_code;

CONNECT app_product/AppProduct#2026@localhost:1521/FREEPDB1
SELECT product_code, product_name FROM product WHERE ROWNUM <= 5;

-- ============================================================
-- ÉTAPE 1 : Ajouter DEP01/DEP02 si manquants (pour seeds avancés)
-- ============================================================
CONNECT app_org/AppOrg#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT [1/8] Création DEP01/DEP02 (utilisés par seeds S23-S31)
DECLARE
  v_company_id NUMBER;
  v_count NUMBER;
BEGIN
  SELECT company_id INTO v_company_id FROM org_company WHERE ROWNUM = 1;

  SELECT COUNT(*) INTO v_count FROM org_warehouse WHERE warehouse_code = 'DEP01';
  IF v_count = 0 THEN
    INSERT INTO org_warehouse (warehouse_code, company_id, warehouse_name, is_sale_allowed, is_purch_allowed, warehouse_type)
    VALUES ('DEP01', v_company_id, 'Dépôt Principal REGAL (legacy DEP01)', 1, 1, 'D');
    DBMS_OUTPUT.PUT_LINE('  → DEP01 créé.');
  ELSE
    DBMS_OUTPUT.PUT_LINE('  DEP01 existe déjà.');
  END IF;

  SELECT COUNT(*) INTO v_count FROM org_warehouse WHERE warehouse_code = 'DEP02';
  IF v_count = 0 THEN
    INSERT INTO org_warehouse (warehouse_code, company_id, warehouse_name, is_sale_allowed, is_purch_allowed, warehouse_type)
    VALUES ('DEP02', v_company_id, 'Dépôt Secondaire REGAL (legacy DEP02)', 1, 0, 'D');
    DBMS_OUTPUT.PUT_LINE('  → DEP02 créé.');
  ELSE
    DBMS_OUTPUT.PUT_LINE('  DEP02 existe déjà.');
  END IF;
  COMMIT;
END;
/

-- ============================================================
-- ÉTAPE 2 : Re-seed transfer_header/line (S23 corrigé)
-- ============================================================
CONNECT app_inv/AppInv#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT [2/8] Re-seed transfer_header + transfer_line (compatible W90 + DEP01/DEP02)
DECLARE
  v_count NUMBER;
  v_tid   NUMBER;
  v_tnum  VARCHAR2(20);
BEGIN
  -- Si déjà 5+ transfers, skip pour éviter doublons
  SELECT COUNT(*) INTO v_count FROM transfer_header;
  IF v_count >= 5 THEN
    DBMS_OUTPUT.PUT_LINE('  transfer_header a déjà ' || v_count || ' rows — skip.');
    RETURN;
  END IF;

  -- Transfert 1 : DEP01 → W90 (caisse FP1)
  v_tnum := 'TR-LEGACY-001';
  INSERT INTO transfer_header (
    transfer_number, transfer_date, source_warehouse, target_warehouse,
    status, total_qty, created_by
  ) VALUES (
    v_tnum, SYSDATE, 'DEP01', 'W90', 'CLOSED', 50, 'S32_RE_SEED'
  ) RETURNING transfer_id INTO v_tid;

  INSERT INTO transfer_line (transfer_id, line_no, product_code, requested_qty, sent_qty, received_qty, unit_code, status)
  VALUES (v_tid, 1, 'ART001', 50, 50, 50, 'PCS', 'RECEIVED');

  -- Transfert 2 : DEP02 → W90
  INSERT INTO transfer_header (
    transfer_number, transfer_date, source_warehouse, target_warehouse,
    status, total_qty, created_by
  ) VALUES (
    'TR-LEGACY-002', SYSDATE, 'DEP02', 'W90', 'IN_TRANSIT', 200, 'S32_RE_SEED'
  ) RETURNING transfer_id INTO v_tid;

  INSERT INTO transfer_line (transfer_id, line_no, product_code, requested_qty, sent_qty, received_qty, unit_code, status)
  VALUES (v_tid, 1, 'ART001', 100, 100, 0, 'PCS', 'SENT');
  INSERT INTO transfer_line (transfer_id, line_no, product_code, requested_qty, sent_qty, received_qty, unit_code, status)
  VALUES (v_tid, 2, 'ART002', 100, 100, 0, 'PCS', 'SENT');

  -- Transfert 3 : DEP01 → DEP02 (rééquilibrage)
  INSERT INTO transfer_header (
    transfer_number, transfer_date, source_warehouse, target_warehouse,
    status, total_qty, created_by
  ) VALUES (
    'TR-LEGACY-003', SYSDATE - 1, 'DEP01', 'DEP02', 'APPROVED', 150, 'S32_RE_SEED'
  ) RETURNING transfer_id INTO v_tid;

  INSERT INTO transfer_line (transfer_id, line_no, product_code, requested_qty, sent_qty, received_qty, unit_code, status)
  VALUES (v_tid, 1, 'ART001', 150, 0, 0, 'PCS', 'PENDING');

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('  → 3 transfers + 4 lignes créés.');
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('  ⚠ Erreur seed transfer : ' || SQLERRM);
  ROLLBACK;
END;
/

-- ============================================================
-- ÉTAPE 3 : Re-seed OHADA Immos (S24)
-- ============================================================
CONNECT app_gl/AppGl#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT [3/8] Re-seed immobilisations + amortissement
DECLARE
  v_count NUMBER;
  v_aid   NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM imm_asset;
  IF v_count > 0 THEN
    DBMS_OUTPUT.PUT_LINE('  imm_asset a déjà ' || v_count || ' rows — skip.');
    RETURN;
  END IF;

  -- Immo 1 : Camion Mercedes
  INSERT INTO imm_asset (
    asset_code, company_code, asset_name, category,
    acquisition_date, acquisition_value, residual_value, useful_life_months,
    depreciation_method, gl_account_code, status
  ) VALUES (
    'IMM-CG-001', '01', 'Camion Mercedes Sprinter 2026 (Pointe-Noire)', 'VEHICLE',
    DATE '2026-01-15', 25000000, 5000000, 60, 'LINEAR', '24510000', 'ACTIVE'
  ) RETURNING asset_id INTO v_aid;

  -- 12 dotations mensuelles
  FOR m IN 1..12 LOOP
    INSERT INTO imm_depreciation (
      asset_id, fiscal_year, period_no, period_start, period_end,
      depr_amount, cumulative_depr, residual_value_at
    ) VALUES (
      v_aid, 2026, m,
      ADD_MONTHS(DATE '2026-01-01', m-1),
      LAST_DAY(ADD_MONTHS(DATE '2026-01-01', m-1)),
      ROUND(20000000/60, 0), ROUND(20000000/60, 0) * m, 25000000 - ROUND(20000000/60, 0) * m
    );
  END LOOP;
  UPDATE imm_asset
    SET accumulated_dep = ROUND(20000000/60, 0) * 12,
        net_book_value = 25000000 - ROUND(20000000/60, 0) * 12
  WHERE asset_id = v_aid;

  -- Immo 2 : Bâtiment DEP02
  INSERT INTO imm_asset (
    asset_code, company_code, asset_name, category,
    acquisition_date, acquisition_value, residual_value, useful_life_months,
    depreciation_method, gl_account_code, status
  ) VALUES (
    'IMM-CG-002', '01', 'Bâtiment entrepôt DEP02 (Ouagadougou)', 'BUILDING',
    DATE '2024-02-15', 85000000, 10000000, 240, 'LINEAR', '22110000', 'ACTIVE'
  ) RETURNING asset_id INTO v_aid;
  UPDATE imm_asset
    SET accumulated_dep = ROUND(75000000/240, 0) * 32,  -- 32 mois écoulés
        net_book_value = 85000000 - ROUND(75000000/240, 0) * 32
  WHERE asset_id = v_aid;

  -- Immo 3 : Licence Oracle
  INSERT INTO imm_asset (
    asset_code, company_code, asset_name, category,
    acquisition_date, acquisition_value, residual_value, useful_life_months,
    depreciation_method, gl_account_code, status
  ) VALUES (
    'IMM-CG-003', '01', 'Licence Oracle 26ai Enterprise', 'SOFTWARE',
    DATE '2026-09-15', 6500000, 0, 60, 'LINEAR', '24110000', 'ACTIVE'
  );

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('  → 3 immobilisations + 12 dotations créées.');
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('  ⚠ Erreur immo : ' || SQLERRM);
  ROLLBACK;
END;
/

-- ============================================================
-- ÉTAPE 4 : Re-seed Déclarations fiscales Congo (S25)
-- ============================================================
CONNECT app_gl/AppGl#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT [4/8] Re-seed déclarations TVA LITOKO (mars 2026)
DECLARE
  v_count NUMBER;
  v_did NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM tax_declaration;
  IF v_count > 0 THEN
    DBMS_OUTPUT.PUT_LINE('  tax_declaration a déjà ' || v_count || ' rows — skip.');
    RETURN;
  END IF;

  -- Déclaration TVA LITOKO mars 2026
  INSERT INTO tax_declaration (
    declaration_ref, form_type_id, company_code,
    period_start, period_end, jurisdiction,
    base_amount, tax_due, amount_payable, status
  ) VALUES (
    'DGI-CG-PNR-2026-03-001',
    (SELECT form_type_id FROM tax_form_type WHERE form_code = 'TVA-MENS-CG' AND jurisdiction = 'CG'),
    'LITOKO',
    DATE '2026-03-01', DATE '2026-03-31', 'CG',
    12500000, 2362500, 864000, 'PAID'
  ) RETURNING declaration_id INTO v_did;

  INSERT INTO tax_declaration_line (declaration_id, line_no, rate_type, rate, base_amount, tax_amount, deductible_base, deductible_tax)
  VALUES (v_did, 1, 'NORMAL', 0.189, 10500000, 1984500, 6500000, 1228500);

  -- TVA avril DRAFT
  INSERT INTO tax_declaration (
    declaration_ref, form_type_id, company_code,
    period_start, period_end, jurisdiction,
    base_amount, tax_due, amount_payable, status
  ) VALUES (
    'DGI-CG-PNR-2026-04-001',
    (SELECT form_type_id FROM tax_form_type WHERE form_code = 'TVA-MENS-CG' AND jurisdiction = 'CG'),
    'LITOKO',
    DATE '2026-04-01', DATE '2026-04-30', 'CG',
    13200000, 2494800, 906300, 'DRAFT'
  );

  -- IS T1-2026
  INSERT INTO tax_declaration (
    declaration_ref, form_type_id, company_code,
    period_start, period_end, jurisdiction,
    base_amount, tax_due, amount_payable, status
  ) VALUES (
    'DGI-CG-PNR-IS-2026-T1',
    (SELECT form_type_id FROM tax_form_type WHERE form_code = 'IS-AAC-CG' AND jurisdiction = 'CG'),
    'LITOKO',
    DATE '2026-01-01', DATE '2026-03-31', 'CG',
    18500000, 5550000, 5550000, 'PAID'
  );

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('  → 3 déclarations LITOKO créées.');
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('  ⚠ Erreur tax : ' || SQLERRM);
  ROLLBACK;
END;
/

-- ============================================================
-- ÉTAPE 5 : Re-seed sys_message (i18n)
-- ============================================================
CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT [5/8] Re-seed sys_message (i18n)
DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM sys_message;
  IF v_count > 0 THEN
    DBMS_OUTPUT.PUT_LINE('  sys_message a déjà ' || v_count || ' rows — skip.');
    RETURN;
  END IF;

  INSERT INTO sys_message (message_key, default_text, message_type)
  SELECT c.message_key, c.default_text, c.message_type
    FROM (SELECT 'CASH.BON.SIGNATURE' AS message_key, 'Signature du bon de caisse' AS default_text, 'LABEL' AS message_type FROM dual
          UNION ALL SELECT 'POS.TICKET.OK', 'Ticket validé', 'INFO' FROM dual
          UNION ALL SELECT 'POS.TICKET.KO', 'Erreur validation ticket', 'ERROR' FROM dual
          UNION ALL SELECT 'TRANSFER.WAIT', 'Transfert en attente approbation', 'WARN' FROM dual
          UNION ALL SELECT 'INVOICE.OVERDUE', 'Facture en retard', 'WARN' FROM dual
          UNION ALL SELECT 'STOCK.LOW', 'Stock bas : alerte réapprovisionnement', 'WARN' FROM dual
          UNION ALL SELECT 'PAYMENT.RECEIVED', 'Paiement reçu', 'INFO' FROM dual
          UNION ALL SELECT 'USER.AUTH.OK', 'Authentification réussie', 'INFO' FROM dual
          UNION ALL SELECT 'USER.AUTH.KO', 'Identifiants incorrects', 'ERROR' FROM dual
          UNION ALL SELECT 'TAVA.OK', 'TVA collectée OK', 'INFO' FROM dual) c;

  INSERT INTO sys_message_lang (message_id, lang_code, translated_text)
  SELECT message_id, 'fr', default_text FROM sys_message;

  INSERT INTO sys_message_lang (message_id, lang_code, translated_text)
  SELECT message_id, 'en',
         CASE message_key
           WHEN 'CASH.BON.SIGNATURE' THEN 'Cash voucher signature'
           WHEN 'POS.TICKET.OK' THEN 'Ticket validated'
           WHEN 'POS.TICKET.KO' THEN 'Ticket validation error'
           WHEN 'INVOICE.OVERDUE' THEN 'Invoice overdue'
           WHEN 'STOCK.LOW' THEN 'Low stock: reorder alert'
           WHEN 'TAVA.OK' THEN 'VAT collected OK'
           ELSE default_text
         END
    FROM sys_message;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('  → 10 messages + traductions FR/EN.');
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('  ⚠ Erreur sys_message : ' || SQLERRM);
END;
/

-- ============================================================
-- ÉTAPE 6 : Re-seed outbox_event (CDC demo)
-- ============================================================
PROMPT
PROMPT [6/8] Re-seed outbox_event (events CDC)
DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM outbox_event;
  IF v_count > 0 THEN
    DBMS_OUTPUT.PUT_LINE('  outbox_event a déjà ' || v_count || ' rows — skip.');
    RETURN;
  END IF;

  INSERT INTO outbox_event (object_owner, object_name, primary_key_value, operation,
                              row_data_json, site_code_origin, status)
  VALUES ('APP_PRODUCT', 'PRODUCT', 'ART001', 'UPDATE',
          '{"product_code":"ART001","product_name":"Cahier 200 pages","standard_price":2500}',
          'PNR-OFC', 'PENDING');

  INSERT INTO outbox_event (object_owner, object_name, primary_key_value, operation,
                              row_data_json, site_code_origin, status, published_at)
  VALUES ('APP_PRODUCT', 'PRODUCT', 'ART002', 'UPDATE',
          '{"product_code":"ART002","standard_price":1200}',
          'PNR-OFC', 'DONE', SYSTIMESTAMP - 1);

  INSERT INTO outbox_event (object_owner, object_name, primary_key_value, operation,
                              row_data_json, site_code_origin, status)
  VALUES ('APP_INV', 'TRANSFER_HEADER', 'TR-LEGACY-001', 'INSERT',
          '{"transfer_id":1,"source":"DEP01","target":"W90"}',
          'PNR-OFC', 'PENDING');

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('  → 3 events CDC.');
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('  ⚠ Erreur outbox : ' || SQLERRM);
  ROLLBACK;
END;
/

-- ============================================================
-- ÉTAPE 7 : Re-seed mpf_employee LITOKO (paie)
-- ============================================================
CONNECT app_hr/AppHr#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT [7/8] Re-seed mpf_employee LITOKO (paie)
DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM mpf_employee WHERE company_code = 'LITOKO';
  IF v_count > 0 THEN
    DBMS_OUTPUT.PUT_LINE('  mpf_employee LITOKO a déjà ' || v_count || ' rows — skip.');
    RETURN;
  END IF;

  INSERT INTO mpf_employee (matricule, party_code, company_code, full_name,
    contract_type, position, category, hire_date,
    location_code, warehouse_code, monthly_salary_brut, hourly_rate,
    payment_method, social_security_no, marital_status, dependents_count)
  VALUES ('LIT-2024-001', 'PTY-LITOKO-E001', 'LITOKO', 'MALONGA Patrick', 'CDI',
          'Gérant LITOKO Pointe-Noire', 'DIRIGEANT', DATE '2024-04-01',
          'POS-PNR-01', 'DEP01', 1800000, 10345, 'BANK_TRANSFER', 'CNSS-CG-001-2024',
          'MARRIED', 3);

  INSERT INTO mpf_employee (matricule, party_code, company_code, full_name,
    contract_type, position, category, hire_date,
    location_code, warehouse_code, monthly_salary_brut, marital_status)
  VALUES ('LIT-2024-002', 'PTY-LITOKO-E002', 'LITOKO', 'NGOMA Priscille', 'CDI',
          'Comptable senior', 'CADRE', DATE '2024-05-15',
          'POS-PNR-01', 'DEP01', 950000, 'SINGLE');

  INSERT INTO mpf_employee (matricule, party_code, company_code, full_name,
    contract_type, position, category, hire_date,
    location_code, warehouse_code, monthly_salary_brut, marital_status, dependents_count)
  VALUES ('LIT-2024-003', 'PTY-LITOKO-E003', 'LITOKO', 'BITEMO Jean-Pierre', 'CDI',
          'Magasinier Pointe-Noire', 'AGENT', DATE '2024-09-01',
          'DEP01', 'DEP01', 420000, 'MARRIED', 2);

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('  → 3 employés LITOKO créés.');
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('  ⚠ Erreur RH : ' || SQLERRM);
  ROLLBACK;
END;
/

-- ============================================================
-- ÉTAPE 8 : Re-seed outbox_event (3 events)
-- ============================================================
PROMPT
PROMPT [8/8] Volumétrie finale
SELECT 'transfer_header'      AS tbl, COUNT(*) AS nb FROM app_inv.transfer_header
UNION ALL SELECT 'transfer_line',        COUNT(*) FROM app_inv.transfer_line
UNION ALL SELECT 'imm_asset',            COUNT(*) FROM app_gl.imm_asset
UNION ALL SELECT 'imm_depreciation',     COUNT(*) FROM app_gl.imm_depreciation
UNION ALL SELECT 'tax_declaration',      COUNT(*) FROM app_gl.tax_declaration
UNION ALL SELECT 'tax_declaration_line', COUNT(*) FROM app_gl.tax_declaration_line
UNION ALL SELECT 'tax_form_type',        COUNT(*) FROM app_gl.tax_form_type
UNION ALL SELECT 'sys_message',          COUNT(*) FROM app_sys.sys_message
UNION ALL SELECT 'sys_message_lang',     COUNT(*) FROM app_sys.sys_message_lang
UNION ALL SELECT 'outbox_event',          COUNT(*) FROM app_sys.outbox_event
UNION ALL SELECT 'mpf_employee LITOKO',   COUNT(*) FROM app_hr.mpf_employee WHERE company_code = 'LITOKO'
UNION ALL SELECT 'org_warehouse (DEP01/02)', COUNT(*) FROM app_org.org_warehouse WHERE warehouse_code IN ('DEP01','DEP02')
 ORDER BY tbl;

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ S32 RE-SEED terminé — modules avancés peuplés
PROMPT   - 3 transfers + 4 lignes (DEP01 ↔ W90)
PROMPT   - 3 immobilisations + 12 dotations
PROMPT   - 3 déclarations LITOKO (TVA + IS)
PROMPT   - 10 messages i18n (FR + EN)
PROMPT   - 3 events CDC outbox
PROMPT   - 3 employés LITOKO
PROMPT   - DEP01/DEP02 créés (compat S23-S31)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
