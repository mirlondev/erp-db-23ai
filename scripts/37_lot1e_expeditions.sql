-- ============================================================
-- SCRIPT 37 : LOT 1E — Expéditions (nouveau schéma app_ship)
-- Migration Oracle 11g (GCEXPEDITION*) → 23ai/26ai
-- ============================================================
-- 7 nouvelles tables dans un NOUVEAU schéma app_ship.
-- Le schéma est créé dans 00_init_schemas.sql.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

CONNECT app_ship/AppShip#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   LOT 1E : 7 tables expéditions (schéma app_ship créé dans 00_init)
PROMPT ══════════════════════════════════════════════════════════

PROMPT ══════════════════════════════════════════════════════════
PROMPT   LOT 1E : 7 tables expéditions
PROMPT ══════════════════════════════════════════════════════════


PROMPT [1/7] shipment_carrier  (← GCEXPEDITION_TRANSPORTEUR)
CREATE TABLE shipment_carrier (
  carrier_id          NUMBER GENERATED ALWAYS AS IDENTITY,
  carrier_code        VARCHAR2(20)  NOT NULL,
  carrier_name        VARCHAR2(120) NOT NULL,
  carrier_type        VARCHAR2(20)  NOT NULL,             -- ROAD | AIR | SEA | RAIL | COURIER
  api_endpoint        VARCHAR2(500),
  tracking_url_template VARCHAR2(500),
  contact_name        VARCHAR2(120),
  contact_phone       VARCHAR2(40),
  contact_email       VARCHAR2(120),
  is_active           BOOLEAN       DEFAULT TRUE,
  is_preferred        BOOLEAN       DEFAULT FALSE,
  default_pickup_time VARCHAR2(8),                       -- HH24:MI
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_shipment_carrier           PRIMARY KEY (carrier_id),
  CONSTRAINT uk_shipment_carrier_code      UNIQUE (carrier_code),
  CONSTRAINT ck_shipment_carrier_type      CHECK (carrier_type IN ('ROAD','AIR','SEA','RAIL','COURIER','MULTIMODAL'))
);

PROMPT [2/7] shipment  (← GCEXPEDITION) — entête expédition
CREATE TABLE shipment (
  shipment_id         NUMBER GENERATED ALWAYS AS IDENTITY,
  shipment_number     VARCHAR2(20)  NOT NULL,
  shipment_date       DATE          NOT NULL,
  carrier_id          NUMBER,
  shipment_type       VARCHAR2(20)  NOT NULL,             -- OUTBOUND | INBOUND | TRANSFER | RETURN
  source_warehouse    VARCHAR2(5),
  destination_type    VARCHAR2(20)  NOT NULL,             -- CUSTOMER | WAREHOUSE | SUPPLIER | PORT
  destination_name    VARCHAR2(255),
  destination_address VARCHAR2(500),
  destination_city    VARCHAR2(120),
  destination_country VARCHAR2(3),
  incoterm            VARCHAR2(3),
  tracking_number     VARCHAR2(40),
  estimated_pickup_at TIMESTAMP,
  estimated_delivery_at TIMESTAMP,
  actual_pickup_at    TIMESTAMP,
  actual_delivery_at  TIMESTAMP,
  total_weight_kg     NUMBER(12,3),
  total_volume_m3     NUMBER(12,6),
  nb_packages         NUMBER(6),
  total_cost          NUMBER(16,4),
  currency_code       VARCHAR2(3)   DEFAULT 'XOF',
  status              VARCHAR2(20)  DEFAULT 'DRAFT',     -- DRAFT | PICKED_UP | IN_TRANSIT | DELIVERED | EXCEPTION | CANCELLED
  related_doc_id      NUMBER,                            -- FK logique vers app_doc.doc_header
  related_doc_type    VARCHAR2(20),                      -- SALE | PURCHASE | TRANSFER | RETURN
  notes               VARCHAR2(2000),
  created_by          VARCHAR2(20),
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_shipment                   PRIMARY KEY (shipment_id),
  CONSTRAINT uk_shipment_number            UNIQUE (shipment_number),
  CONSTRAINT fk_shipment_carrier           FOREIGN KEY (carrier_id)
    REFERENCES shipment_carrier(carrier_id),
  CONSTRAINT ck_shipment_type              CHECK (shipment_type IN ('OUTBOUND','INBOUND','TRANSFER','RETURN','PICKUP')),
  CONSTRAINT ck_shipment_dest_type         CHECK (destination_type IN ('CUSTOMER','WAREHOUSE','SUPPLIER','PORT','AIRPORT','OTHER')),
  CONSTRAINT ck_shipment_status            CHECK (status IN ('DRAFT','PICKED_UP','IN_TRANSIT','DELIVERED','EXCEPTION','CANCELLED'))
);

CREATE INDEX ix_shipment_status            ON shipment(status);
CREATE INDEX ix_shipment_date              ON shipment(shipment_date);
CREATE INDEX ix_shipment_tracking          ON shipment(tracking_number);
CREATE INDEX ix_shipment_destination_city  ON shipment(destination_city);

PROMPT [3/7] shipment_line  (← GCEXPEDITION_DET)
CREATE TABLE shipment_line (
  shipment_id         NUMBER        NOT NULL,
  line_no             NUMBER(4)     NOT NULL,
  product_code        VARCHAR2(80)  NOT NULL,
  description         VARCHAR2(120),
  quantity            NUMBER(16,4)  NOT NULL,
  unit_code            VARCHAR2(12),
  weight_kg           NUMBER(12,3),
  volume_m3           NUMBER(12,6),
  nb_packages         NUMBER(6),
  package_type        VARCHAR2(20),                      -- CARTON | PALETTE | SAC | VRAC
  source_doc_id       NUMBER,                            -- doc source
  source_line_no      NUMBER(4),
  CONSTRAINT pk_shipment_line              PRIMARY KEY (shipment_id, line_no),
  CONSTRAINT fk_shipment_line_hdr          FOREIGN KEY (shipment_id)
    REFERENCES shipment(shipment_id) ON DELETE CASCADE,
  CONSTRAINT ck_shipment_line_qty          CHECK (quantity > 0),
  CONSTRAINT ck_shipment_line_pkg          CHECK (package_type IS NULL OR package_type IN ('CARTON','PALETTE','SAC','VRAC','COLIS','BIDON'))
);

PROMPT [4/7] shipment_tracking  — événements de tracking temps réel
CREATE TABLE shipment_tracking (
  tracking_id         NUMBER GENERATED ALWAYS AS IDENTITY,
  shipment_id         NUMBER        NOT NULL,
  event_at            TIMESTAMP     NOT NULL,
  event_code          VARCHAR2(40)  NOT NULL,             -- PICKED_UP | IN_TRANSIT | AT_HUB | OUT_FOR_DELIVERY | DELIVERED | EXCEPTION
  location_name       VARCHAR2(120),
  location_lat        NUMBER(9,6),
  location_lon        NUMBER(9,6),
  carrier_status      VARCHAR2(120),
  raw_payload         JSON,                              -- payload brut du webhhok transporteur
  is_terminal         BOOLEAN       DEFAULT FALSE,       -- événement terminal (DELIVERED, EXCEPTION)
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP,
  CONSTRAINT pk_shipment_tracking          PRIMARY KEY (tracking_id),
  CONSTRAINT fk_shipment_tracking_hdr      FOREIGN KEY (shipment_id)
    REFERENCES shipment(shipment_id) ON DELETE CASCADE,
  CONSTRAINT ck_shipment_tracking_event    CHECK (event_code IN
    ('PICKED_UP','IN_TRANSIT','AT_HUB','AT_CUSTOMS','OUT_FOR_DELIVERY',
     'DELIVERED','FAILED_DELIVERY','RETURNED','EXCEPTION','CANCELLED','SCHEDULED'))
);

CREATE INDEX ix_shipment_tracking_date    ON shipment_tracking(shipment_id, event_at);

PROMPT [5/7] shipment_cost  — détail des coûts d'expédition
CREATE TABLE shipment_cost (
  cost_id             NUMBER GENERATED ALWAYS AS IDENTITY,
  shipment_id         NUMBER        NOT NULL,
  cost_type           VARCHAR2(20)  NOT NULL,             -- BASE | FUEL | INSURANCE | CUSTOMS | OVERSIZE | OTHER
  cost_label          VARCHAR2(120),
  amount              NUMBER(16,4)  NOT NULL,
  currency_code       VARCHAR2(3)   DEFAULT 'XOF',
  exchange_rate       NUMBER(10,5)  DEFAULT 1,
  amount_in_local     NUMBER(16,4)  GENERATED ALWAYS AS (amount * exchange_rate),
  tax_rate            NUMBER(5,2),
  is_billable         BOOLEAN       DEFAULT TRUE,         -- facturable au client ?
  CONSTRAINT pk_shipment_cost              PRIMARY KEY (cost_id),
  CONSTRAINT fk_shipment_cost_hdr          FOREIGN KEY (shipment_id)
    REFERENCES shipment(shipment_id) ON DELETE CASCADE,
  CONSTRAINT ck_shipment_cost_type         CHECK (cost_type IN ('BASE','FUEL','INSURANCE','CUSTOMS','OVERSIZE','DOC','HANDLING','OTHER')),
  CONSTRAINT ck_shipment_cost_amount       CHECK (amount >= 0)
);

PROMPT [6/7] shipment_address  — adresses détaillées (pickup / delivery / return)
CREATE TABLE shipment_address (
  address_id          NUMBER GENERATED ALWAYS AS IDENTITY,
  shipment_id         NUMBER        NOT NULL,
  address_type        VARCHAR2(20)  NOT NULL,             -- PICKUP | DELIVERY | RETURN
  contact_name        VARCHAR2(120),
  contact_phone       VARCHAR2(40),
  contact_email       VARCHAR2(120),
  company_name        VARCHAR2(120),
  address_1           VARCHAR2(255),
  address_2           VARCHAR2(255),
  postal_code         VARCHAR2(20),
  city                VARCHAR2(120),
  country_code        VARCHAR2(3),
  latitude            NUMBER(9,6),
  longitude           NUMBER(9,6),
  opening_hours       VARCHAR2(255),                      -- ex. 'Lun-Ven 9h-18h'
  delivery_instructions VARCHAR2(1000),
  CONSTRAINT pk_shipment_address           PRIMARY KEY (address_id),
  CONSTRAINT fk_shipment_address_hdr       FOREIGN KEY (shipment_id)
    REFERENCES shipment(shipment_id) ON DELETE CASCADE,
  CONSTRAINT ck_shipment_address_type      CHECK (address_type IN ('PICKUP','DELIVERY','RETURN','BILLING'))
);

PROMPT [7/7] shipment_exception  — exceptions et litiges transport
CREATE TABLE shipment_exception (
  exception_id        NUMBER GENERATED ALWAYS AS IDENTITY,
  shipment_id         NUMBER        NOT NULL,
  exception_at        TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  exception_type      VARCHAR2(20)  NOT NULL,             -- DAMAGED | LOST | DELAYED | REFUSED | WRONG_ITEM | OTHER
  exception_code      VARCHAR2(40),
  description         VARCHAR2(2000) NOT NULL,
  nb_packages_affected NUMBER(6),
  claim_amount        NUMBER(16,4),
  claim_currency      VARCHAR2(3)   DEFAULT 'XOF',
  claim_ref           VARCHAR2(120),
  is_resolved         BOOLEAN       DEFAULT FALSE,
  resolved_at         TIMESTAMP,
  resolution_notes    VARCHAR2(2000),
  reported_by         VARCHAR2(20),
  reported_at         TIMESTAMP     DEFAULT SYSTIMESTAMP,
  CONSTRAINT pk_shipment_exception         PRIMARY KEY (exception_id),
  CONSTRAINT fk_shipment_exception_hdr     FOREIGN KEY (shipment_id)
    REFERENCES shipment(shipment_id) ON DELETE CASCADE,
  CONSTRAINT ck_shipment_exception_type    CHECK (exception_type IN
    ('DAMAGED','LOST','DELAYED','REFUSED','WRONG_ITEM','ADDRESS_INVALID','CUSTOMS_HOLD','OTHER'))
);

CREATE INDEX ix_shipment_exception_unresolved
  ON shipment_exception(is_resolved, exception_at)
  WHERE is_resolved = FALSE;

PROMPT
PROMPT ═══ Privilèges croisés ═══
CONNECT system/oracle@localhost:1521/FREEPDB1

GRANT SELECT ON app_ship.shipment           TO app_api;
GRANT SELECT ON app_ship.shipment_line      TO app_api;
GRANT SELECT ON app_ship.shipment_tracking  TO app_api;
GRANT SELECT ON app_ship.shipment_cost      TO app_api;
GRANT SELECT ON app_ship.shipment_carrier   TO app_api;
GRANT SELECT ON app_ship.shipment_address   TO app_api;
GRANT SELECT ON app_ship.shipment_exception TO app_api;

GRANT SELECT ON app_ship.shipment           TO app_sales;
GRANT SELECT ON app_ship.shipment_carrier   TO app_sales;
GRANT SELECT ON app_ship.shipment_tracking  TO app_sales;

GRANT SELECT ON app_ship.shipment           TO app_inv;
GRANT SELECT ON app_ship.shipment_line      TO app_inv;

GRANT SELECT, INSERT, UPDATE ON app_ship.shipment          TO app_doc;
GRANT SELECT, INSERT, UPDATE ON app_ship.shipment_line     TO app_doc;
GRANT SELECT, INSERT, UPDATE ON app_ship.shipment_cost     TO app_doc;
GRANT SELECT, INSERT         ON app_ship.shipment_tracking TO app_doc;
GRANT SELECT, INSERT, UPDATE ON app_ship.shipment_address  TO app_doc;
GRANT SELECT, INSERT, UPDATE ON app_ship.shipment_exception TO app_doc;

PROMPT
PROMPT ═══ Validation — Tables ═══
CONNECT app_ship/AppShip#2026@localhost:1521/FREEPDB1
SELECT table_name, num_rows
  FROM user_tables
 WHERE table_name IN ('SHIPMENT_CARRIER','SHIPMENT','SHIPMENT_LINE','SHIPMENT_TRACKING',
                      'SHIPMENT_COST','SHIPMENT_ADDRESS','SHIPMENT_EXCEPTION')
 ORDER BY table_name;

PROMPT
PROMPT [Validation] Objets invalides
SELECT object_name, object_type, status
  FROM user_objects
 WHERE status = 'INVALID';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ LOT 1E TERMINÉ (7 tables dans nouveau schéma app_ship)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
