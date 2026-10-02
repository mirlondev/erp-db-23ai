-- ============================================================
-- SCRIPT 27 : LOT R11 — Alertes & Notifications (CORRIGÉ)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   LOT R11 : ALERTES & NOTIFICATIONS (6 tables) — v2
PROMPT ══════════════════════════════════════════════════════════

-- Nettoyage idempotent (nécessaire car le 1er run a partiellement échoué)
DECLARE
  PROCEDURE d(p_t VARCHAR2, p_n VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE 'DROP '||p_t||' '||p_n;
    DBMS_OUTPUT.PUT_LINE('  DROP '||p_t||' '||p_n);
  EXCEPTION WHEN OTHERS THEN NULL; END;
BEGIN
  d('TABLE','notification_queue');
  d('TABLE','notification_subscription');
  d('TABLE','notification_channel');
  d('TABLE','alert_instance');
  d('TABLE','alert_rule');
  d('TABLE','alert_type');
END;
/

-- [1/6] alert_type
PROMPT
PROMPT [1/6] alert_type
CREATE TABLE alert_type (
  alert_type_code    VARCHAR2(40)  NOT NULL,
  alert_type_name    VARCHAR2(120) NOT NULL,
  category           VARCHAR2(30)  NOT NULL,
  severity           VARCHAR2(10)  DEFAULT 'MEDIUM',
  auto_resolve       BOOLEAN       DEFAULT FALSE,
  default_message    VARCHAR2(2000),
  icon_code          VARCHAR2(20),
  display_color      VARCHAR2(7),
  is_active          BOOLEAN       DEFAULT TRUE,
  created_at         TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_alert_type       PRIMARY KEY (alert_type_code),
  CONSTRAINT ck_alert_severity   CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),
  CONSTRAINT ck_alert_category   CHECK (category IN ('STOCK','SALES','CASH','FRAUD','SECURITY','SYSTEM','BUSINESS','GL','INVENTORY'))
);

-- [2/6] alert_rule
PROMPT
PROMPT [2/6] alert_rule
CREATE TABLE alert_rule (
  rule_id             NUMBER GENERATED ALWAYS AS IDENTITY,
  rule_name           VARCHAR2(120) NOT NULL,
  alert_type_code     VARCHAR2(40)  NOT NULL,
  condition_sql       VARCHAR2(4000),
  threshold           NUMBER(16,4),
  comparison_op       VARCHAR2(2),
  is_active           BOOLEAN       DEFAULT TRUE,
  check_frequency     VARCHAR2(20)  DEFAULT 'DAILY',
  notify_roles        VARCHAR2(500),
  notify_emails       VARCHAR2(1000),
  notify_sms_numbers  VARCHAR2(500),
  cooldown_minutes    NUMBER(6)     DEFAULT 60,
  description         VARCHAR2(1000),
  created_by          VARCHAR2(20),
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  updated_at          TIMESTAMP,
  CONSTRAINT pk_alert_rule          PRIMARY KEY (rule_id),
  CONSTRAINT fk_alert_rule_type     FOREIGN KEY (alert_type_code)
    REFERENCES alert_type(alert_type_code),
  CONSTRAINT ck_alert_rule_freq     CHECK (check_frequency IN ('HOURLY','DAILY','WEEKLY','MONTHLY','REALTIME')),
  CONSTRAINT ck_alert_rule_op       CHECK (comparison_op IS NULL OR comparison_op IN ('>','<','=','>=','<=','!=','IN','NOT IN'))
);

-- ⚠️ BOOLEAN non indexable directement → index fonctionnel
CREATE INDEX ix_alert_rule_active ON alert_rule(
  CASE WHEN is_active THEN check_frequency END
);

-- [3/6] alert_instance
PROMPT
PROMPT [3/6] alert_instance
CREATE TABLE alert_instance (
  alert_id            NUMBER GENERATED ALWAYS AS IDENTITY,
  alert_type_code     VARCHAR2(40)  NOT NULL,
  rule_id             NUMBER,
  entity_type         VARCHAR2(30),
  entity_id           VARCHAR2(100),
  entity_label        VARCHAR2(255),
  message             VARCHAR2(2000) NOT NULL,
  severity            VARCHAR2(10)  DEFAULT 'MEDIUM',
  status              VARCHAR2(20)  DEFAULT 'OPEN',
  triggered_at        TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  acknowledged_at     TIMESTAMP,
  acknowledged_by     VARCHAR2(20),
  resolved_at         TIMESTAMP,
  resolved_by         VARCHAR2(20),
  resolution_notes    VARCHAR2(1000),
  payload             JSON,
  expires_at          TIMESTAMP,
  CONSTRAINT pk_alert_instance       PRIMARY KEY (alert_id),
  CONSTRAINT fk_alert_inst_type      FOREIGN KEY (alert_type_code)
    REFERENCES alert_type(alert_type_code),
  CONSTRAINT fk_alert_inst_rule      FOREIGN KEY (rule_id)
    REFERENCES alert_rule(rule_id),
  CONSTRAINT ck_alert_inst_status    CHECK (status IN ('OPEN','ACK','RESOLVED','IGNORED','EXPIRED')),
  CONSTRAINT ck_alert_inst_severity  CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),
  CONSTRAINT ck_alert_inst_ack       CHECK ((status = 'ACK') = (acknowledged_at IS NOT NULL)),
  CONSTRAINT ck_alert_inst_resolved  CHECK ((status IN ('RESOLVED','IGNORED')) = (resolved_at IS NOT NULL))
);

CREATE INDEX ix_alert_status            ON alert_instance(status);
CREATE INDEX ix_alert_entity            ON alert_instance(entity_type, entity_id);
CREATE INDEX ix_alert_triggered         ON alert_instance(triggered_at);
CREATE INDEX ix_alert_severity_status   ON alert_instance(severity, status);

-- ✅ CORRECTION ORA-02158 : index fonctionnel au lieu de WHERE
PROMPT   → ix_alert_open (index fonctionnel)
CREATE INDEX ix_alert_open ON alert_instance(
  CASE WHEN status = 'OPEN' THEN status END,
  CASE WHEN status = 'OPEN' THEN triggered_at END
);

-- [4/6] notification_channel
PROMPT
PROMPT [4/6] notification_channel
CREATE TABLE notification_channel (
  channel_id          NUMBER GENERATED ALWAYS AS IDENTITY,
  channel_code        VARCHAR2(20)  NOT NULL,
  channel_name        VARCHAR2(60)  NOT NULL,
  channel_type        VARCHAR2(20)  NOT NULL,
  config_json         JSON,
  is_active           BOOLEAN       DEFAULT TRUE,
  rate_limit_per_hour NUMBER(6),
  description         VARCHAR2(500),
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  updated_at          TIMESTAMP,
  CONSTRAINT pk_notification_channel       PRIMARY KEY (channel_id),
  CONSTRAINT uk_notification_channel_code  UNIQUE (channel_code),
  CONSTRAINT ck_notif_channel_type         CHECK (channel_type IN ('EMAIL','SMS','PUSH','WEBHOOK','UI','SLACK','TEAMS'))
);

-- [5/6] notification_subscription
PROMPT
PROMPT [5/6] notification_subscription
CREATE TABLE notification_subscription (
  subscription_id     NUMBER GENERATED ALWAYS AS IDENTITY,
  user_code           VARCHAR2(20)  NOT NULL,
  channel_id          NUMBER        NOT NULL,
  alert_type_code     VARCHAR2(40),
  destination         VARCHAR2(255),
  is_active           BOOLEAN       DEFAULT TRUE,
  quiet_hours_start   NUMBER(4),
  quiet_hours_end     NUMBER(4),
  priority_min        VARCHAR2(10)  DEFAULT 'LOW',
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_notification_subscription  PRIMARY KEY (subscription_id),
  CONSTRAINT fk_notif_sub_channel          FOREIGN KEY (channel_id)
    REFERENCES notification_channel(channel_id) ON DELETE CASCADE,
  CONSTRAINT fk_notif_sub_type             FOREIGN KEY (alert_type_code)
    REFERENCES alert_type(alert_type_code),
  CONSTRAINT uk_notif_sub_unique           UNIQUE (user_code, channel_id, alert_type_code),
  CONSTRAINT ck_notif_sub_priority         CHECK (priority_min IN ('LOW','MEDIUM','HIGH','CRITICAL')),
  CONSTRAINT ck_notif_sub_quiet_range      CHECK (quiet_hours_start IS NULL OR quiet_hours_start BETWEEN 0 AND 2359)
);

CREATE INDEX ix_notif_sub_user ON notification_subscription(user_code);

-- [6/6] notification_queue
PROMPT
PROMPT [6/6] notification_queue
CREATE TABLE notification_queue (
  queue_id            NUMBER GENERATED ALWAYS AS IDENTITY,
  alert_id            NUMBER,
  subscription_id     NUMBER,
  channel_id          NUMBER        NOT NULL,
  recipient           VARCHAR2(255) NOT NULL,
  subject             VARCHAR2(500),
  body                CLOB,
  body_html           CLOB,
  priority            NUMBER(2)     DEFAULT 5,
  status              VARCHAR2(20)  DEFAULT 'PENDING',
  attempts            NUMBER(3)     DEFAULT 0,
  max_attempts        NUMBER(3)     DEFAULT 5,
  next_attempt_at     TIMESTAMP     DEFAULT SYSTIMESTAMP,
  last_attempt_at     TIMESTAMP,
  sent_at             TIMESTAMP,
  error_message       VARCHAR2(2000),
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_notification_queue       PRIMARY KEY (queue_id),
  CONSTRAINT fk_notif_queue_alert        FOREIGN KEY (alert_id)
    REFERENCES alert_instance(alert_id) ON DELETE CASCADE,
  CONSTRAINT fk_notif_queue_subscription FOREIGN KEY (subscription_id)
    REFERENCES notification_subscription(subscription_id) ON DELETE SET NULL,
  CONSTRAINT fk_notif_queue_channel      FOREIGN KEY (channel_id)
    REFERENCES notification_channel(channel_id),
  CONSTRAINT ck_notif_queue_status       CHECK (status IN ('PENDING','PROCESSING','SENT','FAILED','CANCELLED')),
  CONSTRAINT ck_notif_queue_priority     CHECK (priority BETWEEN 1 AND 10),
  CONSTRAINT ck_notif_queue_attempts     CHECK (attempts >= 0 AND attempts <= max_attempts)
);

CREATE INDEX ix_notif_queue_status   ON notification_queue(status, next_attempt_at);

-- ✅ CORRECTION ORA-02158
PROMPT   → ix_notif_queue_priority (index fonctionnel)
CREATE INDEX ix_notif_queue_priority ON notification_queue(
  CASE WHEN status = 'PENDING' THEN priority END,
  CASE WHEN status = 'PENDING' THEN next_attempt_at END
);

CREATE INDEX ix_notif_queue_alert    ON notification_queue(alert_id);

-- Stats
PROMPT
PROMPT ═══ Collecte stats ═══
BEGIN
  DBMS_STATS.GATHER_SCHEMA_STATS('APP_SYS', cascade => TRUE);
END;
/

-- Privilèges
PROMPT
PROMPT ═══ Privilèges ═══
CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA

GRANT SELECT ON app_sys.alert_type                TO app_api;
GRANT SELECT ON app_sys.alert_instance            TO app_api;
GRANT SELECT ON app_sys.notification_channel      TO app_api;
GRANT SELECT ON app_sys.notification_subscription TO app_api;
GRANT SELECT ON app_sys.notification_queue        TO app_api;

GRANT SELECT ON app_sys.alert_type TO app_sales;
GRANT SELECT ON app_sys.alert_type TO app_inv;
GRANT SELECT ON app_sys.alert_type TO app_party;
GRANT SELECT ON app_sys.alert_type TO app_ar;
GRANT SELECT ON app_sys.alert_type TO app_product;
GRANT SELECT ON app_sys.alert_type TO app_gl;
GRANT SELECT ON app_sys.alert_type TO app_pos;
GRANT SELECT ON app_sys.alert_type TO app_cash;
GRANT SELECT ON app_sys.alert_type TO app_doc;

GRANT INSERT ON app_sys.alert_instance TO app_sales;
GRANT INSERT ON app_sys.alert_instance TO app_inv;
GRANT INSERT ON app_sys.alert_instance TO app_party;
GRANT INSERT ON app_sys.alert_instance TO app_ar;
GRANT INSERT ON app_sys.alert_instance TO app_product;
GRANT INSERT ON app_sys.alert_instance TO app_gl;
GRANT INSERT ON app_sys.alert_instance TO app_pos;
GRANT INSERT ON app_sys.alert_instance TO app_cash;
GRANT INSERT ON app_sys.alert_instance TO app_doc;

-- Validation
PROMPT
PROMPT ═══ Validation ═══
CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1
SELECT table_name, num_rows FROM user_tables
 WHERE table_name IN ('ALERT_TYPE','ALERT_RULE','ALERT_INSTANCE',
                      'NOTIFICATION_CHANNEL','NOTIFICATION_SUBSCRIPTION','NOTIFICATION_QUEUE')
 ORDER BY table_name;

SELECT object_name, object_type, status FROM user_objects WHERE status = 'INVALID';

PROMPT ✅ LOT R11 TERMINÉ
EXIT;