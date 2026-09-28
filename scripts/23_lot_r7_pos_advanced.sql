-- ============================================================
-- SCRIPT 23 : LOT R7 — POS avancé
-- Migration Oracle 11g (retours/remises/fidelité/clôture caisse terminal)
--                  → Oracle 23ai/26ai (app_sales)
-- ============================================================
-- 5 nouvelles tables dans app_sales :
--   ticket_return, ticket_return_line, ticket_discount,
--   ticket_loyalty, pos_cash_closure
--
-- Notes de modernisation (vs procedure.txt d'origine) :
--  * VARCHAR2(20) pour user_code (vs 5 legacy)
--  * Statut unique CHECK explicite par table
--  * FK CASCADE sur lignes enfants (retour line, discount, loyalty)
--  * FK cross-schema ticket_loyalty.card_id → app_party.loyalty_card
--  * Différenciation explicite :
--    - pos_cash_closure (R7, app_sales) = front-office terminal
--    - cash_register_session (R6, app_ar) = back-office reconciliation
--    Les deux sont complémentaires, pas redondants.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

CONNECT app_sales/AppSales#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   LOT R7 : POS AVANCÉ (5 tables)
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [1/5] ticket_return  — entête retour ticket
CREATE TABLE ticket_return (
  return_id            NUMBER GENERATED ALWAYS AS IDENTITY,
  return_number        VARCHAR2(20)  NOT NULL,
  return_date          DATE          NOT NULL,
  original_terminal    VARCHAR2(12)  NOT NULL,           -- terminal d'origine de la vente
  original_ticket_no   NUMBER(8)     NOT NULL,           -- ticket d'origine
  customer_code        VARCHAR2(32),                     -- client (nullable : retour anonyme possible)
  customer_name        VARCHAR2(120),
  refund_method        VARCHAR2(12),                     -- CASH | CARD | CHECK | STORE_CREDIT | ORIGINAL
  total_return_ttc     NUMBER(16,4)  DEFAULT 0,
  total_return_ht      NUMBER(16,4)  DEFAULT 0,
  total_tax            NUMBER(16,4)  DEFAULT 0,
  reason               VARCHAR2(255),                    -- motif : defect, customer_change_of_mind, etc.
  status               VARCHAR2(20)  DEFAULT 'VALID',     -- DRAFT | VALID | CANCELLED
  is_inventory_updated BOOLEAN       DEFAULT FALSE,       -- stock remis en rayon ?
  processed_by         VARCHAR2(20),
  processed_at         TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_ticket_return            PRIMARY KEY (return_id),
  CONSTRAINT uk_ticket_return_no         UNIQUE (return_number),
  CONSTRAINT fk_ticket_return_ticket     FOREIGN KEY (original_terminal, original_ticket_no)
    REFERENCES ticket(terminal_id, ticket_no),
  CONSTRAINT ck_ticket_return_status     CHECK (status IN ('DRAFT','VALID','CANCELLED')),
  CONSTRAINT ck_ticket_return_amounts    CHECK (total_return_ttc >= 0 AND total_return_ht >= 0)
);

CREATE INDEX ix_ticket_return_date        ON ticket_return(return_date);
CREATE INDEX ix_ticket_return_original    ON ticket_return(original_terminal, original_ticket_no);
CREATE INDEX ix_ticket_return_customer    ON ticket_return(customer_code);

PROMPT
PROMPT [2/5] ticket_return_line  — lignes du retour
CREATE TABLE ticket_return_line (
  return_id            NUMBER        NOT NULL,
  line_no              NUMBER(3)     NOT NULL,
  product_code         VARCHAR2(80)  NOT NULL,
  description          VARCHAR2(120),
  quantity_returned    NUMBER(16,4)  NOT NULL,
  unit_price           NUMBER(16,4),
  amount               NUMBER(16,4),
  tax_rate             NUMBER(5,2),
  tax_amount           NUMBER(16,4),
  amount_ht            NUMBER(16,4),
  source_line_no       NUMBER(3),                        -- ligne du ticket d'origine
  reason               VARCHAR2(255),
  restock_status       VARCHAR2(20)  DEFAULT 'PENDING',   -- PENDING | RESTOCKED | DISCARDED | EXCHANGED
  CONSTRAINT pk_ticket_return_line           PRIMARY KEY (return_id, line_no),
  CONSTRAINT fk_ticket_return_line_hdr       FOREIGN KEY (return_id)
    REFERENCES ticket_return(return_id) ON DELETE CASCADE,
  CONSTRAINT ck_ticket_return_line_qty       CHECK (quantity_returned > 0),
  CONSTRAINT ck_ticket_return_line_restock   CHECK (restock_status IN ('PENDING','RESTOCKED','DISCARDED','EXCHANGED'))
);

CREATE INDEX ix_ticket_return_line_prod      ON ticket_return_line(product_code);

PROMPT
PROMPT [3/5] ticket_discount  — remises ligne ou globales sur ticket
CREATE TABLE ticket_discount (
  discount_id          NUMBER GENERATED ALWAYS AS IDENTITY,
  terminal_id          VARCHAR2(12)  NOT NULL,
  ticket_no            NUMBER(8)     NOT NULL,
  line_no              NUMBER(3),                        -- NULL = remise globale
  discount_type        VARCHAR2(20)  NOT NULL,           -- MANUAL | PROMOTION | LOYALTY | STAFF | SPLIT_PAYMENT
  discount_rate        NUMBER(5,2),                      -- pourcentage (ex. 10 pour -10%)
  discount_amount      NUMBER(16,4),                     -- montant fixe
  reason               VARCHAR2(255),
  authorized_by        VARCHAR2(20),                     -- si > seuil autorisation
  promo_id             NUMBER,                           -- si lié à une promo R1
  loyalty_card_id      NUMBER,
  created_at           TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_ticket_discount          PRIMARY KEY (discount_id),
  CONSTRAINT fk_ticket_discount_ticket   FOREIGN KEY (terminal_id, ticket_no)
    REFERENCES ticket(terminal_id, ticket_no) ON DELETE CASCADE,
  CONSTRAINT ck_ticket_discount_type     CHECK (discount_type IN ('MANUAL','PROMOTION','LOYALTY','STAFF','BULK','SPLIT_PAYMENT','OTHER')),
  CONSTRAINT ck_ticket_discount_xor      CHECK ((discount_rate IS NOT NULL) OR (discount_amount IS NOT NULL)),
  CONSTRAINT ck_ticket_discount_pct      CHECK (discount_rate IS NULL OR (discount_rate > 0 AND discount_rate <= 100)),
  CONSTRAINT ck_ticket_discount_amt      CHECK (discount_amount IS NULL OR discount_amount > 0)
);

CREATE INDEX ix_ticket_discount_ticket    ON ticket_discount(terminal_id, ticket_no);
CREATE INDEX ix_ticket_discount_type      ON ticket_discount(discount_type);

PROMPT
PROMPT [4/5] ticket_loyalty  — points gagnés/utilisés sur le ticket
CREATE TABLE ticket_loyalty (
  loyalty_id           NUMBER GENERATED ALWAYS AS IDENTITY,
  terminal_id          VARCHAR2(12)  NOT NULL,
  ticket_no            NUMBER(8)     NOT NULL,
  card_id              NUMBER,                           -- FK vers app_party.loyalty_card
  card_number          VARCHAR2(20),                      -- snapshot du numéro (si la carte est supprimée)
  points_earned        NUMBER(12)    DEFAULT 0,
  points_used          NUMBER(12)    DEFAULT 0,
  conversion_amount    NUMBER(16,4)  DEFAULT 0,          -- valeur en XOF de la conversion
  expiry_date          DATE,                             -- expiration des points gagnés
  created_at           TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_ticket_loyalty           PRIMARY KEY (loyalty_id),
  CONSTRAINT fk_ticket_loyalty_ticket   FOREIGN KEY (terminal_id, ticket_no)
    REFERENCES ticket(terminal_id, ticket_no) ON DELETE CASCADE,
  CONSTRAINT ck_ticket_loyalty_earned    CHECK (points_earned >= 0),
  CONSTRAINT ck_ticket_loyalty_used      CHECK (points_used >= 0),
  CONSTRAINT ck_ticket_loyalty_xor       CHECK (points_earned > 0 OR points_used > 0)
);

CREATE INDEX ix_ticket_loyalty_ticket     ON ticket_loyalty(terminal_id, ticket_no);
CREATE INDEX ix_ticket_loyalty_card       ON ticket_loyalty(card_id);

PROMPT
PROMPT [5/5] pos_cash_closure  — clôture de caisse terminal (front-office)
-- Volontairement séparé de app_ar.cash_register_session (back-office).
-- pos_cash_closure = état temps-réel du terminal (fin de session caissier)
-- cash_register_session = réconciliation comptable (fin de journée)
CREATE TABLE pos_cash_closure (
  closure_id           NUMBER GENERATED ALWAYS AS IDENTITY,
  terminal_code        VARCHAR2(12)  NOT NULL,
  session_no           NUMBER(8)     NOT NULL,
  closure_date         DATE          NOT NULL,
  theoretical_cash     NUMBER(16,4),                     -- attendu
  actual_cash          NUMBER(16,4),                     -- compté
  difference           NUMBER(16,4)  DEFAULT 0,           -- actual - theoretical
  total_sales_ttc      NUMBER(16,4)  DEFAULT 0,
  total_returns_ttc    NUMBER(16,4)  DEFAULT 0,
  total_discounts_ttc  NUMBER(16,4)  DEFAULT 0,
  total_loyalty_used   NUMBER(16,4)  DEFAULT 0,           -- valeur en XOF des pts utilisés
  nb_tickets           NUMBER(8)     DEFAULT 0,
  nb_returns           NUMBER(8)     DEFAULT 0,
  nb_voided            NUMBER(8)     DEFAULT 0,           -- tickets annulés
  closed_by            VARCHAR2(20),
  closed_at            TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  notes                VARCHAR2(500),
  CONSTRAINT pk_pos_cash_closure         PRIMARY KEY (closure_id),
  CONSTRAINT uk_pos_cash_closure         UNIQUE (terminal_code, session_no),
  CONSTRAINT ck_pos_closure_amounts      CHECK (NVL(total_sales_ttc, 0) >= 0
                                             AND NVL(total_returns_ttc, 0) >= 0
                                             AND NVL(total_discounts_ttc, 0) >= 0)
);

CREATE INDEX ix_pos_closure_date          ON pos_cash_closure(closure_date);
CREATE INDEX ix_pos_closure_terminal      ON pos_cash_closure(terminal_code);

PROMPT
PROMPT ═══ Privilèges croisés (FK vers app_party.loyalty_card) ═══
CONNECT system/oracle@localhost:1521/FREEPDB1

-- app_sales a besoin de référencer loyalty_card : on autorise la FK
GRANT SELECT ON app_party.loyalty_card          TO app_sales;
GRANT SELECT ON app_party.loyalty_card_type     TO app_sales;
GRANT SELECT ON app_party.loyalty_operation_type TO app_sales;

-- app_ar peut lire les retours (impact sur facturation)
GRANT SELECT ON app_sales.ticket_return         TO app_ar;
GRANT SELECT ON app_sales.ticket_return_line    TO app_ar;
GRANT SELECT ON app_sales.pos_cash_closure      TO app_ar;

-- app_api pour exposition JSON
GRANT SELECT ON app_sales.ticket_return         TO app_api;
GRANT SELECT ON app_sales.ticket_return_line    TO app_api;
GRANT SELECT ON app_sales.ticket_discount      TO app_api;
GRANT SELECT ON app_sales.ticket_loyalty       TO app_api;
GRANT SELECT ON app_sales.pos_cash_closure      TO app_api;

-- app_gl pour comptabilisation
GRANT SELECT ON app_sales.ticket_discount       TO app_gl;
GRANT SELECT ON app_sales.pos_cash_closure      TO app_gl;

PROMPT
PROMPT ═══ Validation — Tables créées ═══
CONNECT app_sales/AppSales#2026@localhost:1521/FREEPDB1
SELECT table_name, num_rows
  FROM user_tables
 WHERE table_name IN ('TICKET_RETURN','TICKET_RETURN_LINE','TICKET_DISCOUNT',
                      'TICKET_LOYALTY','POS_CASH_CLOSURE')
 ORDER BY table_name;

PROMPT
PROMPT [Validation] Contraintes
SELECT constraint_name, constraint_type, status
  FROM user_constraints
 WHERE table_name IN ('TICKET_RETURN','TICKET_RETURN_LINE','TICKET_DISCOUNT',
                      'TICKET_LOYALTY','POS_CASH_CLOSURE')
 ORDER BY table_name, constraint_name;

PROMPT
PROMPT [Validation] Objets invalides (doit être vide)
SELECT object_name, object_type, status
  FROM user_objects
 WHERE status = 'INVALID';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ LOT R7 TERMINÉ (5 tables)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
