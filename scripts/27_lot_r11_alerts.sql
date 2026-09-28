-- ============================================================
-- SCRIPT 27 : LOT R11 — Alertes & Notifications
-- Migration Oracle 11g (alertes legacy, canaux, queue envoi)
--                  → Oracle 23ai/26ai (app_sys)
-- ============================================================
-- 6 nouvelles tables dans app_sys :
--   alert_type, alert_rule, alert_instance,
--   notification_channel, notification_subscription, notification_queue
--
-- Notes de modernisation (vs procedure.txt d'origine) :
--  * BOOLEAN pour is_active (legacy 'Y'/'N')
--  * user_code VARCHAR2(20) (vs 5 legacy)
--  * VARCHAR2(40) pour alert_type_code (vs 20 parfois court)
--  * CHECK explicites sur les statuts
--  * JSON stocké en JSON natif Oracle 23ai (pas en VARCHAR2)
--  * Index composites pour résolution rapide
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   LOT R11 : ALERTES & NOTIFICATIONS (6 tables)
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [1/6] alert_type  — référentiel des types d'alertes
CREATE TABLE alert_type (
  alert_type_code    VARCHAR2(40)  NOT NULL,
  alert_type_name    VARCHAR2(120) NOT NULL,
  category           VARCHAR2(30)  NOT NULL,             -- STOCK | SALES | FRAUD | SECURITY | SYSTEM | BUSINESS
  severity           VARCHAR2(10)  DEFAULT 'MEDIUM',     -- LOW | MEDIUM | HIGH | CRITICAL
  auto_resolve       BOOLEAN       DEFAULT FALSE,
  default_message    VARCHAR2(2000),
  icon_code          VARCHAR2(20),                       -- icône UI
  display_color      VARCHAR2(7),                        -- #RRGGBB
  is_active          BOOLEAN       DEFAULT TRUE,
  created_at         TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_alert_type             PRIMARY KEY (alert_type_code),
  CONSTRAINT ck_alert_severity         CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),
  CONSTRAINT ck_alert_category         CHECK (category IN ('STOCK','SALES','CASH','FRAUD','SECURITY','SYSTEM','BUSINESS','GL','INVENTORY'))
);

PROMPT
PROMPT [2/6] alert_rule  — règles de détection
CREATE TABLE alert_rule (
  rule_id             NUMBER GENERATED ALWAYS AS IDENTITY,
  rule_name           VARCHAR2(120) NOT NULL,
  alert_type_code     VARCHAR2(40)  NOT NULL,
  condition_sql       VARCHAR2(4000),                     -- SQL dynamique exécuté par le job
  threshold           NUMBER(16,4),
  comparison_op       VARCHAR2(2),                       -- >, <, =, >=, <=, !=
  is_active           BOOLEAN       DEFAULT TRUE,
  check_frequency     VARCHAR2(20)  DEFAULT 'DAILY',     -- HOURLY | DAILY | WEEKLY | REALTIME
  notify_roles        VARCHAR2(500),                      -- ex. 'MANAGER,ACCOUNTANT'
  notify_emails       VARCHAR2(1000),
  notify_sms_numbers  VARCHAR2(500),
  cooldown_minutes    NUMBER(6)     DEFAULT 60,          -- ne pas re-déclencher pendant N min
  description         VARCHAR2(1000),
  created_by          VARCHAR2(20),
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  updated_at          TIMESTAMP,
  CONSTRAINT pk_alert_rule              PRIMARY KEY (rule_id),
  CONSTRAINT fk_alert_rule_type         FOREIGN KEY (alert_type_code)
    REFERENCES alert_type(alert_type_code),
  CONSTRAINT ck_alert_rule_freq          CHECK (check_frequency IN ('HOURLY','DAILY','WEEKLY','MONTHLY','REALTIME')),
  CONSTRAINT ck_alert_rule_op            CHECK (comparison_op IS NULL OR comparison_op IN ('>','<','=','>=','<=','!=','IN','NOT IN'))
);

CREATE INDEX ix_alert_rule_active     ON alert_rule(is_active, check_frequency);

PROMPT
PROMPT [3/6] alert_instance  — instances concrètes d'alertes déclenchées
CREATE TABLE alert_instance (
  alert_id            NUMBER GENERATED ALWAYS AS IDENTITY,
  alert_type_code     VARCHAR2(40)  NOT NULL,
  rule_id             NUMBER,                            -- règle à l'origine
  entity_type         VARCHAR2(30),                      -- PRODUCT | PARTY | INVOICE | TICKET | STOCK ...
  entity_id           VARCHAR2(100),                     -- valeur de la PK (mix texte pour cross-schema)
  entity_label        VARCHAR2(255),                     -- libellé humain pour l'UI
  message             VARCHAR2(2000) NOT NULL,
  severity            VARCHAR2(10)  DEFAULT 'MEDIUM',
  status              VARCHAR2(20)  DEFAULT 'OPEN',       -- OPEN | ACK | RESOLVED | IGNORED | EXPIRED
  triggered_at        TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  acknowledged_at     TIMESTAMP,
  acknowledged_by     VARCHAR2(20),
  resolved_at         TIMESTAMP,
  resolved_by         VARCHAR2(20),
  resolution_notes    VARCHAR2(1000),
  payload             JSON,                              -- données contextuelles structurées (JSON natif 23ai)
  expires_at          TIMESTAMP,                         -- auto-expire si non acquittée
  CONSTRAINT pk_alert_instance          PRIMARY KEY (alert_id),
  CONSTRAINT fk_alert_inst_type         FOREIGN KEY (alert_type_code)
    REFERENCES alert_type(alert_type_code),
  CONSTRAINT fk_alert_inst_rule         FOREIGN KEY (rule_id)
    REFERENCES alert_rule(rule_id),
  CONSTRAINT ck_alert_inst_status       CHECK (status IN ('OPEN','ACK','RESOLVED','IGNORED','EXPIRED')),
  CONSTRAINT ck_alert_inst_severity     CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),
  CONSTRAINT ck_alert_inst_ack          CHECK ((status = 'ACK') = (acknowledged_at IS NOT NULL)),
  CONSTRAINT ck_alert_inst_resolved     CHECK ((status IN ('RESOLVED','IGNORED')) = (resolved_at IS NOT NULL))
);

CREATE INDEX ix_alert_status            ON alert_instance(status);
CREATE INDEX ix_alert_entity            ON alert_instance(entity_type, entity_id);
CREATE INDEX ix_alert_triggered         ON alert_instance(triggered_at);
CREATE INDEX ix_alert_severity_status   ON alert_instance(severity, status);
CREATE INDEX ix_alert_open              ON alert_instance(status, triggered_at) WHERE status = 'OPEN';

PROMPT
PROMPT [4/6] notification_channel  — canaux de notification
CREATE TABLE notification_channel (
  channel_id          NUMBER GENERATED ALWAYS AS IDENTITY,
  channel_code        VARCHAR2(20)  NOT NULL,
  channel_name        VARCHAR2(60)  NOT NULL,
  channel_type        VARCHAR2(20)  NOT NULL,           -- EMAIL | SMS | PUSH | WEBHOOK | UI | SLACK
  config_json         JSON,                            -- configuration spécifique au canal (SMTP, Twilio, etc.)
  is_active           BOOLEAN       DEFAULT TRUE,
  rate_limit_per_hour NUMBER(6),                       -- plafond d'envoi (anti-spam)
  description         VARCHAR2(500),
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  updated_at          TIMESTAMP,
  CONSTRAINT pk_notification_channel          PRIMARY KEY (channel_id),
  CONSTRAINT uk_notification_channel_code     UNIQUE (channel_code),
  CONSTRAINT ck_notif_channel_type            CHECK (channel_type IN ('EMAIL','SMS','PUSH','WEBHOOK','UI','SLACK','TEAMS'))
);

PROMPT
PROMPT [5/6] notification_subscription  — abonnements user → canal × type d'alerte
CREATE TABLE notification_subscription (
  subscription_id     NUMBER GENERATED ALWAYS AS IDENTITY,
  user_code           VARCHAR2(20)  NOT NULL,
  channel_id          NUMBER        NOT NULL,
  alert_type_code     VARCHAR2(40),                    -- NULL = tous les types
  destination         VARCHAR2(255),                   -- email, n° tel, device token... override du canal
  is_active           BOOLEAN       DEFAULT TRUE,
  quiet_hours_start   NUMBER(4),                       -- HHMM (ex. 2200 = 22h00) - début silence
  quiet_hours_end     NUMBER(4),                       -- fin silence
  priority_min        VARCHAR2(10)  DEFAULT 'LOW',      -- alerter seulement si severity >= ce seuil
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_notification_subscription      PRIMARY KEY (subscription_id),
  CONSTRAINT fk_notif_sub_channel              FOREIGN KEY (channel_id)
    REFERENCES notification_channel(channel_id) ON DELETE CASCADE,
  CONSTRAINT fk_notif_sub_type                 FOREIGN KEY (alert_type_code)
    REFERENCES alert_type(alert_type_code),
  CONSTRAINT uk_notif_sub_unique               UNIQUE (user_code, channel_id, alert_type_code),
  CONSTRAINT ck_notif_sub_priority             CHECK (priority_min IN ('LOW','MEDIUM','HIGH','CRITICAL')),
  CONSTRAINT ck_notif_sub_quiet_range          CHECK (quiet_hours_start IS NULL OR quiet_hours_start BETWEEN 0 AND 2359)
);

CREATE INDEX ix_notif_sub_user          ON notification_subscription(user_code);

PROMPT
PROJECT [6/6] notification_queue  — file d'attente d'envoi
CREATE TABLE notification_queue (
  queue_id            NUMBER GENERATED ALWAYS AS IDENTITY,
  alert_id            NUMBER,
  subscription_id     NUMBER,
  channel_id          NUMBER        NOT NULL,
  recipient           VARCHAR2(255) NOT NULL,
  subject             VARCHAR2(500),
  body                CLOB,
  body_html           CLOB,
  priority            NUMBER(2)     DEFAULT 5,         -- 1=highest, 10=lowest
  status              VARCHAR2(20)  DEFAULT 'PENDING', -- PENDING | PROCESSING | SENT | FAILED | CANCELLED
  attempts            NUMBER(3)     DEFAULT 0,
  max_attempts        NUMBER(3)     DEFAULT 5,
  next_attempt_at     TIMESTAMP     DEFAULT SYSTIMESTAMP,
  last_attempt_at     TIMESTAMP,
  sent_at             TIMESTAMP,
  error_message       VARCHAR2(2000),
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_notification_queue          PRIMARY KEY (queue_id),
  CONSTRAINT fk_notif_queue_alert           FOREIGN KEY (alert_id)
    REFERENCES alert_instance(alert_id) ON DELETE CASCADE,
  CONSTRAINT fk_notif_queue_subscription    FOREIGN KEY (subscription_id)
    REFERENCES notification_subscription(subscription_id) ON DELETE SET NULL,
  CONSTRAINT fk_notif_queue_channel         FOREIGN KEY (channel_id)
    REFERENCES notification_channel(channel_id),
  CONSTRAINT ck_notif_queue_status           CHECK (status IN ('PENDING','PROCESSING','SENT','FAILED','CANCELLED')),
  CONSTRAINT ck_notif_queue_priority         CHECK (priority BETWEEN 1 AND 10),
  CONSTRAINT ck_notif_queue_attempts        CHECK (attempts >= 0 AND attempts <= max_attempts)
);

CREATE INDEX ix_notif_queue_status        ON notification_queue(status, next_attempt_at);
CREATE INDEX ix_notif_queue_priority      ON notification_queue(priority, status) WHERE status = 'PENDING';
CREATE INDEX ix_notif_queue_alert         ON notification_queue(alert_id);

PROMPT
PROMPT ═══ Privilèges croisés ═══
CONNECT system/oracle@localhost:1521/FREEPDB1

-- app_api : exposition JSON pour UI
GRANT SELECT ON app_sys.alert_type             TO app_api;
GRANT SELECT ON app_sys.alert_instance         TO app_api;
GRANT SELECT ON app_sys.notification_channel  TO app_api;
GRANT SELECT ON app_sys.notification_subscription TO app_api;
GRANT SELECT ON app_sys.notification_queue     TO app_api;

-- Tout le monde peut lire les types d'alertes (référentiel)
GRANT SELECT ON app_sys.alert_type             TO app_sales;
GRANT SELECT ON app_sys.alert_type             TO app_inv;
GRANT SELECT ON app_sys.alert_type             TO app_party;
GRANT SELECT ON app_sys.alert_type             TO app_ar;
GRANT SELECT ON app_sys.alert_type             TO app_product;
GRANT SELECT ON app_sys.alert_type             TO app_gl;
GRANT SELECT ON app_sys.alert_type             TO app_pos;
GRANT SELECT ON app_sys.alert_type             TO app_cash;
GRANT SELECT ON app_sys.alert_type             TO app_doc;

-- Chaque schéma peut écrire ses alertes
GRANT INSERT ON app_sys.alert_instance         TO app_sales;
GRANT INSERT ON app_sys.alert_instance         TO app_inv;
GRANT INSERT ON app_sys.alert_instance         TO app_party;
GRANT INSERT ON app_sys.alert_instance         TO app_ar;
GRANT INSERT ON app_sys.alert_instance         TO app_product;
GRANT INSERT ON app_sys.alert_instance         TO app_gl;
GRANT INSERT ON app_sys.alert_instance         TO app_pos;
GRANT INSERT ON app_sys.alert_instance         TO app_cash;
GRANT INSERT ON app_sys.alert_instance         TO app_doc;

PROMPT
PROMPT ═══ Validation — Tables créées ═══
CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1
SELECT table_name, num_rows
  FROM user_tables
 WHERE table_name IN ('ALERT_TYPE','ALERT_RULE','ALERT_INSTANCE',
                      'NOTIFICATION_CHANNEL','NOTIFICATION_SUBSCRIPTION','NOTIFICATION_QUEUE')
 ORDER BY table_name;

PROMPT
PROMPT [Validation] Contraintes
SELECT constraint_name, constraint_type, status
  FROM user_constraints
 WHERE table_name IN ('ALERT_TYPE','ALERT_RULE','ALERT_INSTANCE',
                      'NOTIFICATION_CHANNEL','NOTIFICATION_SUBSCRIPTION','NOTIFICATION_QUEUE')
 ORDER BY table_name, constraint_name;

PROMPT
PROMPT [Validation] Objets invalides (doit être vide)
SELECT object_name, object_type, status
  FROM user_objects
 WHERE status = 'INVALID';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ LOT R11 TERMINÉ (6 tables)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
