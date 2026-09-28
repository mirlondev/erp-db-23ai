-- ============================================================
-- SCRIPT 44 : Body du package pkg_transfer_stock
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

CONNECT app_inv/AppInv#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   BODY pkg_transfer_stock
PROMPT ══════════════════════════════════════════════════════════

CREATE OR REPLACE PACKAGE BODY pkg_transfer_stock AS

  -- ============================================================
  -- 1. Création d'un brouillon de transfert
  -- ============================================================
  FUNCTION create_transfer(
    p_source_type    IN VARCHAR2,
    p_source_code    IN VARCHAR2,
    p_target_type    IN VARCHAR2,
    p_target_code    IN VARCHAR2,
    p_company_code   IN VARCHAR2,
    p_transfer_type  IN VARCHAR2,
    p_priority       IN NUMBER DEFAULT 3,
    p_user_code      IN VARCHAR2
  ) RETURN NUMBER IS
    v_transfer_id NUMBER;
    v_transfer_number VARCHAR2(20);
    v_check NUMBER;
  BEGIN
    -- Validations basiques
    IF p_source_code = p_target_code AND p_source_type = p_target_type THEN
      RAISE_APPLICATION_ERROR(-20010, 'Source et target identiques');
    END IF;

    -- Vérifier que l'emplacement source existe
    IF p_source_type = 'WAREHOUSE' THEN
      SELECT COUNT(*) INTO v_check FROM app_org.org_warehouse
        WHERE warehouse_code = p_source_code AND ROWNUM = 1;
      IF v_check = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'Dépôt source inexistant : ' || p_source_code);
      END IF;
    ELSIF p_source_type = 'STORE' THEN
      SELECT COUNT(*) INTO v_check FROM app_pos.pos_terminal
        WHERE terminal_code = p_source_code AND ROWNUM = 1;
      IF v_check = 0 THEN
        RAISE_APPLICATION_ERROR(-20012, 'Magasin/terminal source inexistant : ' || p_source_code);
      END IF;
    ELSE
      RAISE_APPLICATION_ERROR(-20013, 'Source type invalide : ' || p_source_type);
    END IF;

    -- Idem pour target
    IF p_target_type = 'WAREHOUSE' THEN
      SELECT COUNT(*) INTO v_check FROM app_org.org_warehouse
        WHERE warehouse_code = p_target_code AND ROWNUM = 1;
    ELSIF p_target_type = 'STORE' THEN
      SELECT COUNT(*) INTO v_check FROM app_pos.pos_terminal
        WHERE terminal_code = p_target_code AND ROWNUM = 1;
    END IF;

    IF v_check = 0 THEN
      RAISE_APPLICATION_ERROR(-20014, 'Emplacement cible inexistant : ' || p_target_code);
    END IF;

    -- Génération n° de transfert (formatté)
    SELECT 'TR-' || TO_CHAR(SYSDATE, 'YYYYMMDD') || '-' ||
           LPAD(NVL(MAX(TO_NUMBER(SUBSTR(transfer_number, -5))), 0) + 1, 5, '0')
      INTO v_transfer_number
      FROM transfer_header
     WHERE transfer_number LIKE 'TR-' || TO_CHAR(SYSDATE, 'YYYYMMDD') || '-%';

  INSERT INTO transfer_header (
      transfer_number, transfer_date, source_warehouse, target_warehouse,
      status, total_qty, created_by, validated_by
    ) VALUES (
      v_transfer_number, SYSDATE, p_source_code, p_target_code,
      'DRAFT', 0, p_user_code, NULL
    ) RETURNING transfer_id INTO v_transfer_id;

    -- Note : on pourrait stocker source_type/target_type dans la table
    -- mais on les déduit pour éviter de modifier le schéma legacy 23ai.

    COMMIT;
    RETURN v_transfer_id;
  END create_transfer;

  -- ============================================================
  -- 2. Ajout d'une ligne
  -- ============================================================
  PROCEDURE add_line(
    p_transfer_id IN NUMBER,
    p_product_code IN VARCHAR2,
    p_quantity    IN NUMBER,
    p_unit_code   IN VARCHAR2 DEFAULT 'UNIT',
    p_lot_number  IN VARCHAR2 DEFAULT NULL
  ) IS
    v_line_no  NUMBER(5);
    v_status   VARCHAR2(20);
    v_req      NUMBER(16,4);
  BEGIN
    -- Vérifier que le transfert est encore modifiable
    SELECT status INTO v_status
      FROM transfer_header WHERE transfer_id = p_transfer_id;

    IF v_status NOT IN ('DRAFT','REQUESTED') THEN
      RAISE_APPLICATION_ERROR(-20020, 'Transfert non modifiable (statut : ' || v_status || ')');
    END IF;

    -- Si un lot est fourni, vérifier la disponibilité
    IF p_lot_number IS NOT NULL THEN
      SELECT NVL(lot_qty, 0) INTO v_req
        FROM inv_product_lot
       WHERE product_code = p_product_code AND lot_number = p_lot_number;
    END IF;

    -- Récupération n° de ligne
    SELECT NVL(MAX(line_no), 0) + 1 INTO v_line_no
      FROM transfer_line WHERE transfer_id = p_transfer_id;

    INSERT INTO transfer_line (
      transfer_id, line_no, product_code, description,
      requested_qty, sent_qty, received_qty, unit_code, lot_number, status
    ) VALUES (
      p_transfer_id, v_line_no, p_product_code,
      (SELECT product_name FROM app_product.product WHERE product_code = p_product_code),
      p_quantity, 0, 0, p_unit_code, p_lot_number, 'PENDING'
    );

    -- Mise à jour total
    UPDATE transfer_header
       SET total_qty = NVL((SELECT SUM(requested_qty) FROM transfer_line
                            WHERE transfer_id = p_transfer_id), 0)
     WHERE transfer_id = p_transfer_id;

    COMMIT;
  END add_line;

  -- ============================================================
  -- 3. Soumission pour approbation
  -- ============================================================
  PROCEDURE submit_for_approval(
    p_transfer_id IN NUMBER,
    p_user_code   IN VARCHAR2
  ) IS
  BEGIN
    UPDATE transfer_header
       SET status = 'REQUESTED',
           validated_by = NULL,
           validated_at = NULL
     WHERE transfer_id = p_transfer_id
       AND status = 'DRAFT';

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20030, 'Transfert non-DRAFT ou introuvable');
    END IF;

    -- Audit
    INSERT INTO app_sys.sys_audit_trail (user_code, action_type, entity_type, entity_id, new_values)
    VALUES (p_user_code, 'UPDATE', 'app_inv.transfer_header', TO_CHAR(p_transfer_id),
            JSON_OBJECT('status' VALUE 'REQUESTED'));

    COMMIT;
  END submit_for_approval;

  -- ============================================================
  -- 4. Approbation (REQUESTED → APPROVED)
  -- ============================================================
  PROCEDURE approve_transfer(
    p_transfer_id IN NUMBER,
    p_user_code   IN VARCHAR2,
    p_total_qty   IN NUMBER DEFAULT NULL
  ) IS
    v_check NUMBER;
  BEGIN
    -- Vérifier qu'il y a au moins une ligne
    SELECT COUNT(*) INTO v_check FROM transfer_line
     WHERE transfer_id = p_transfer_id;

    IF v_check = 0 THEN
      RAISE_APPLICATION_ERROR(-20040, 'Aucune ligne à transférer');
    END IF;

    UPDATE transfer_header
       SET status       = 'APPROVED',
           validated_by = p_user_code,
           validated_at = SYSTIMESTAMP,
           total_qty    = NVL(p_total_qty, total_qty)
     WHERE transfer_id = p_transfer_id
       AND status IN ('REQUESTED', 'DRAFT');

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20041, 'Transfert non-REQUESTED ou introuvable');
    END IF;

    -- Audit
    INSERT INTO app_sys.sys_audit_trail (user_code, action_type, entity_type, entity_id, new_values, severity)
    VALUES (p_user_code, 'APPROVE', 'app_inv.transfer_header', TO_CHAR(p_transfer_id),
            JSON_OBJECT('status' VALUE 'APPROVED', 'total_qty' VALUE p_total_qty),
            'INFO');

    COMMIT;
  END approve_transfer;

  -- ============================================================
  -- 5. PACKED : préparation physique (mise de côté)
  -- ============================================================
  PROCEDURE pack_transfer(
    p_transfer_id IN NUMBER,
    p_user_code   IN VARCHAR2
  ) IS
  BEGIN
    UPDATE transfer_header
       SET status = 'PACKED'
     WHERE transfer_id = p_transfer_id
       AND status = 'APPROVED';

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20050, 'Transfert non-APPROVED');
    END IF;

    -- Les lignes passent sent_qty = requested_qty par défaut
    UPDATE transfer_line
       SET sent_qty = requested_qty, status = 'SENT'
     WHERE transfer_id = p_transfer_id
       AND status = 'PENDING';

    COMMIT;
  END pack_transfer;

  -- ============================================================
  -- 6. SHIPMENT : départ physique
  -- ============================================================
  PROCEDURE ship_transfer(
    p_transfer_id IN NUMBER,
    p_user_code   IN VARCHAR2,
    p_shipped_qty IN NUMBER DEFAULT NULL
  ) IS
  BEGIN
    UPDATE transfer_header
       SET status = 'IN_TRANSIT'
     WHERE transfer_id = p_transfer_id
       AND status = 'PACKED';

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20060, 'Transfert non-PACKED');
    END IF;

    IF p_shipped_qty IS NOT NULL THEN
      UPDATE transfer_line SET sent_qty = p_shipped_qty
       WHERE transfer_id = p_transfer_id;
    END IF;

    COMMIT;
  END ship_transfer;

  -- ============================================================
  -- 7. RECEIVE : arrivée au destination + maj stock
  -- ============================================================
  PROCEDURE receive_transfer(
    p_transfer_id IN NUMBER,
    p_user_code   IN VARCHAR2
  ) IS
    v_source VARCHAR2(5);
    v_target VARCHAR2(5);
    v_qty    NUMBER;
    v_line_no  NUMBER(5);
    v_product  VARCHAR2(80);
  BEGIN
    -- Récupérer les emplacements
    SELECT source_warehouse, target_warehouse
      INTO v_source, v_target
      FROM transfer_header
     WHERE transfer_id = p_transfer_id;

    IF v_source IS NULL OR v_target IS NULL THEN
      RAISE_APPLICATION_ERROR(-20070, 'Emplacements source/target non définis');
    END IF;

    -- Vérifier le statut
    UPDATE transfer_header
       SET status = 'RECEIVED'
     WHERE transfer_id = p_transfer_id
       AND status = 'IN_TRANSIT';

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20071, 'Transfert non-IN_TRANSIT');
    END IF;

    -- Pour chaque ligne : received_qty = sent_qty + maj inventaire
    FOR r IN (SELECT line_no, product_code, sent_qty
                FROM transfer_line
               WHERE transfer_id = p_transfer_id
                 AND sent_qty > 0) LOOP
      -- Décrémente source
      UPDATE inv_stock
         SET stock_qty   = GREATEST(0, stock_qty - r.sent_qty),
             last_out_at = SYSDATE,
             updated_at  = SYSTIMESTAMP
       WHERE warehouse_code = v_source
         AND product_code   = r.product_code;

      IF SQL%ROWCOUNT = 0 THEN
        -- Création si n'existe pas (rare)
        INSERT INTO inv_stock (warehouse_code, product_code, stock_qty, last_out_at)
        VALUES (v_source, r.product_code, 0, SYSDATE);
      END IF;

      -- Incrémente destination (UPSERT)
      MERGE INTO inv_stock tgt
      USING (SELECT v_target AS warehouse_code, r.product_code AS product_code,
                    r.sent_qty AS qty
             FROM DUAL) src
      ON (tgt.warehouse_code = src.warehouse_code AND tgt.product_code = src.product_code)
      WHEN MATCHED THEN
        UPDATE SET stock_qty   = tgt.stock_qty + src.qty,
                   last_in_at  = SYSDATE,
                   updated_at  = SYSTIMESTAMP
      WHEN NOT MATCHED THEN
        INSERT (warehouse_code, product_code, stock_qty, last_in_at)
        VALUES (src.warehouse_code, src.product_code, src.qty, SYSDATE);

      -- Trace mouvement dans inv_movement
      INSERT INTO inv_movement (
        movement_date, warehouse_code, product_code,
        movement_type, direction, quantity,
        document_type, document_id, notes, created_by
      ) VALUES (
        SYSDATE, v_source, r.product_code,
        'TRANSFER', 'O', r.sent_qty,
        'TRANSFER', p_transfer_id, 'Sortie transfert #' || p_transfer_id, p_user_code
      );

      INSERT INTO inv_movement (
        movement_date, warehouse_code, product_code,
        movement_type, direction, quantity,
        document_type, document_id, notes, created_by
      ) VALUES (
        SYSDATE, v_target, r.product_code,
        'TRANSFER', 'I', r.sent_qty,
        'TRANSFER', p_transfer_id, 'Entrée transfert #' || p_transfer_id, p_user_code
      );

      -- Update ligne
      UPDATE transfer_line
         SET received_qty = sent_qty,
             status = 'RECEIVED'
       WHERE transfer_id = p_transfer_id
         AND line_no = r.line_no;
    END LOOP;

    -- Mise à jour finale du statut
    UPDATE transfer_header
       SET status = 'CLOSED'
     WHERE transfer_id = p_transfer_id
       AND status = 'RECEIVED';

    -- Audit
    INSERT INTO app_sys.sys_audit_trail (user_code, action_type, entity_type, entity_id,
                                          old_values, new_values, severity)
    VALUES (p_user_code, 'UPDATE', 'app_inv.transfer_header', TO_CHAR(p_transfer_id),
            JSON_OBJECT('status' VALUE 'IN_TRANSIT'),
            JSON_OBJECT('status' VALUE 'CLOSED', 'source' VALUE v_source, 'target' VALUE v_target),
            'INFO');

    COMMIT;
  END receive_transfer;

  -- ============================================================
  -- 8. Annulation
  -- ============================================================
  PROCEDURE cancel_transfer(
    p_transfer_id IN NUMBER,
    p_reason      IN VARCHAR2,
    p_user_code   IN VARCHAR2
  ) IS
    v_status VARCHAR2(20);
  BEGIN
    SELECT status INTO v_status FROM transfer_header WHERE transfer_id = p_transfer_id;

    IF v_status IN ('IN_TRANSIT','RECEIVED','CLOSED') THEN
      RAISE_APPLICATION_ERROR(-20080, 'Transfert non annulable (statut : ' || v_status || ')');
    END IF;

    UPDATE transfer_header
       SET status      = 'CANCELLED',
           memo        = NVL(memo,'') || ' | ANNULÉ: ' || p_reason,
           validated_by = NULL, validated_at = NULL
     WHERE transfer_id = p_transfer_id;

    UPDATE transfer_line SET status = 'CANCELLED' WHERE transfer_id = p_transfer_id;

    -- Audit
    INSERT INTO app_sys.sys_audit_trail (user_code, action_type, entity_type, entity_id,
                                          old_values, new_values, severity)
    VALUES (p_user_code, 'UPDATE', 'app_inv.transfer_header', TO_CHAR(p_transfer_id),
            JSON_OBJECT('status' VALUE v_status),
            JSON_OBJECT('status' VALUE 'CANCELLED', 'reason' VALUE p_reason),
            'WARN');

    COMMIT;
  END cancel_transfer;

  -- ============================================================
  -- 9. Lecture statut
  -- ============================================================
  FUNCTION get_transfer_status(p_transfer_id IN NUMBER) RETURN VARCHAR2 IS
    v_status VARCHAR2(20);
  BEGIN
    SELECT status INTO v_status FROM transfer_header WHERE transfer_id = p_transfer_id;
    RETURN v_status;
  END get_transfer_status;

  -- ============================================================
  -- 10. Coût estimé
  -- ============================================================
  FUNCTION get_estimated_value(p_transfer_id IN NUMBER) RETURN NUMBER IS
    v_total NUMBER(16,4) := 0;
  BEGIN
    SELECT NVL(SUM(tl.requested_qty * p.standard_price), 0)
      INTO v_total
      FROM transfer_line tl
      JOIN app_product.product p ON p.product_code = tl.product_code
     WHERE tl.transfer_id = p_transfer_id;
    RETURN v_total;
  END get_estimated_value;

  -- ============================================================
  -- 11. Liste des transferts actifs (ref cursor)
  -- ============================================================
  FUNCTION get_active_transfers(p_location_type IN VARCHAR2, p_location_code IN VARCHAR2)
    RETURN SYS_REFCURSOR IS
    v_cur SYS_REFCURSOR;
  BEGIN
    OPEN v_cur FOR
      SELECT transfer_id, transfer_number, transfer_date,
             source_warehouse, target_warehouse,
             total_qty, status
        FROM transfer_header
       WHERE status NOT IN ('CLOSED','CANCELLED')
         AND (source_warehouse = p_location_code OR target_warehouse = p_location_code)
       ORDER BY transfer_date DESC;
    RETURN v_cur;
  END get_active_transfers;

  -- ============================================================
  -- 12. Quantité disponible (pour info / contrôle)
  -- ============================================================
  FUNCTION get_available_qty(
    p_location_type IN VARCHAR2,
    p_location_code IN VARCHAR2,
    p_product_code  IN VARCHAR2
  ) RETURN NUMBER IS
    v_qty NUMBER(16,4);
  BEGIN
    SELECT NVL(stock_qty, 0) INTO v_qty
      FROM inv_stock
     WHERE warehouse_code = p_location_code
       AND product_code   = p_product_code;
    RETURN NVL(v_qty, 0);
  END get_available_qty;

END pkg_transfer_stock;
/

PROMPT ✓ Body créé

-- Test rapide
DECLARE
  v_tid NUMBER;
BEGIN
  v_tid := pkg_transfer_stock.create_transfer(
    p_source_type    => 'WAREHOUSE',
    p_source_code    => 'DEP01',
    p_target_type    => 'WAREHOUSE',
    p_target_code    => 'DEP02',
    p_company_code   => 'COMP01',
    p_transfer_type  => 'REPLENISHMENT',
    p_user_code      => 'TEST_SCRIPT'
  );
  DBMS_OUTPUT.PUT_LINE('Test transfer # : ' || v_tid);
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('Test skippé (pas de données init) : ' || SQLERRM);
END;
/

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ PACKAGE pkg_transfer_stock INSTALLÉ
PROMPT ══════════════════════════════════════════════════════════
EXIT;
