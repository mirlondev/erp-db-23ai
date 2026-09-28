-- ============================================================
-- S16 : Seed LOT R8 (Promotions POS avancé)
-- Données de démo : 3 promos POS temporelles + 5 niveaux fidélité.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF

CONNECT app_product/AppProduct#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   SEED LOT R8 — Promotions POS avancé
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [Reset des tables R8]
BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM loyalty_status_rule';
  EXECUTE IMMEDIATE 'DELETE FROM loyalty_status_config';
  EXECUTE IMMEDIATE 'DELETE FROM promo_pos_hours';
  EXECUTE IMMEDIATE 'DELETE FROM promo_pos_product';
  EXECUTE IMMEDIATE 'DELETE FROM promo_pos_config';
  COMMIT;
END;
/


PROMPT [1] 3 promos POS
-- Promo 1 : Happy Hour 18h-20h en semaine (sauf dimanche), -10% sur IT
INSERT INTO promo_pos_config (promo_code, promo_name, is_active,
                               start_date, end_date, weekday_mask,
                               hour_start, hour_end,
                               action_type, multiplier, min_amount,
                               priority, memo, updated_by, created_by)
VALUES ('POS-PROMO-001', 'Happy Hour Soir -10%',
        TRUE, DATE '2026-01-01', DATE '2026-12-31', '1111110',
        1800, 2000,
        'MT', NULL, 5000,
        20, 'Tous les soirs 18h-20h sauf dimanche, -10% sur rayon IT', 'ADMIN', 'ADMIN');

-- Promo 2 : Multiplicateur de points x2 le samedi
INSERT INTO promo_pos_config (promo_code, promo_name, is_active,
                               start_date, end_date, weekday_mask,
                               hour_start, hour_end,
                               action_type, multiplier,
                               priority, memo, updated_by, created_by)
VALUES ('POS-PROMO-002', 'Weekend Points x2',
        TRUE, DATE '2026-01-01', DATE '2026-12-31', '0000011',
        NULL, NULL,
        'PN', 2.0,
        30, 'Points x2 tous les samedis et dimanches', 'ADMIN', 'ADMIN');

-- Promo 3 : BOGO sur les cahiers le lundi matin (10h-12h)
INSERT INTO promo_pos_config (promo_code, promo_name, is_active,
                               start_date, end_date, weekday_mask,
                               hour_start, hour_end,
                               action_type,
                               priority, memo, updated_by, created_by)
VALUES ('POS-PROMO-003', 'Lundi Matin Cahiers -1 Gratuit',
        TRUE, DATE '2026-09-01', DATE '2026-12-31', '1000000',
        1000, 1200,
        'BG',
        10, 'BOGO sur ART001 chaque lundi matin', 'ADMIN', 'ADMIN');


PROMPT [2] Lignes produits éligibles
-- IT subcategory pour POS-PROMO-001
INSERT INTO promo_pos_product (pos_promo_id, line_no, nature_code, category_code,
                                subcategory_code, product_group, discount_rate, updated_by)
VALUES (1, 1, 'FINISHED', 'IT', 'ACCESSORY', 'INFORMATIQUE', 10, 'ADMIN');

-- ART001 = Cahiers pour POS-PROMO-003 (BOGO)
INSERT INTO promo_pos_product (pos_promo_id, line_no, product_code, product_label, updated_by)
VALUES (3, 1, 'ART001', 'Cahier 200 pages A4', 'ADMIN');


PROMPT [3] Plages horaires
-- POS-PROMO-003 : lundi 10h-12h (couvre tout déjà dans config mais on détaille)
INSERT INTO promo_pos_hours (pos_promo_id, weekday, start_time, end_time, updated_by)
VALUES (3, 1, 1000, 1200, 'ADMIN');
INSERT INTO promo_pos_hours (pos_promo_id, weekday, start_time, end_time, updated_by)
VALUES (3, 1, 1400, 1600, 'ADMIN');

-- POS-PROMO-001 : déjà couvert par hour_start=1800 dans config, mais on ajoute une exception samedi 12h-14h
INSERT INTO promo_pos_hours (pos_promo_id, weekday, start_time, end_time, updated_by)
VALUES (1, 6, 1200, 1400, 'ADMIN');


PROMPT [4] 5 niveaux fidélité (Bronze → Diamond)
INSERT INTO loyalty_status_config (app_code, status_level, status_name,
                                    customer_type_code, points_threshold,
                                    inactivity_delay, point_value,
                                    display_color, icon_code, memo, is_active)
VALUES ('FID01', 1, 'Bronze',   'BRONZE',         0,    365, 100, '#CD7F32', 'bronze',   'Niveau par défaut', TRUE);
INSERT INTO loyalty_status_config (app_code, status_level, status_name,
                                    customer_type_code, points_threshold,
                                    inactivity_delay, point_value,
                                    display_color, icon_code, memo, is_active)
VALUES ('FID01', 2, 'Silver',   'SILVER',         500,  365, 80,  '#C0C0C0', 'silver',   'Atteint après 500 pts', TRUE);
INSERT INTO loyalty_status_config (app_code, status_level, status_name,
                                    customer_type_code, points_threshold,
                                    inactivity_delay, point_value,
                                    display_color, icon_code, memo, is_active)
VALUES ('FID01', 3, 'Gold',     'GOLD',           2000, 365, 50,  '#FFD700', 'gold',     'Atteint après 2000 pts', TRUE);
INSERT INTO loyalty_status_config (app_code, status_level, status_name,
                                    customer_type_code, points_threshold,
                                    inactivity_delay, point_value,
                                    display_color, icon_code, memo, is_active)
VALUES ('FID01', 4, 'Platinum', 'PLATINUM',       10000,180, 30,  '#E5E4E2', 'platinum', 'Niveau premium', TRUE);
INSERT INTO loyalty_status_config (app_code, status_level, status_name,
                                    customer_type_code, points_threshold,
                                    inactivity_delay, point_value,
                                    display_color, icon_code, memo, is_active)
VALUES ('FID01', 5, 'Diamond',  'DIAMOND',        50000,90,  10,  '#B9F2FF', 'diamond',  'Niveau ultime VIP', TRUE);


PROMPT [5] Quelques règles par POS
-- Gold dans le POS CAI01 : bonus +2%
INSERT INTO loyalty_status_rule (app_code, status_level, pos_code, point_value_override, bonus_rate_override)
VALUES ('FID01', 3, '01', 50, 2.0);

-- Platinum + 5% sur POS 02
INSERT INTO loyalty_status_rule (app_code, status_level, pos_code, point_value_override, bonus_rate_override)
VALUES ('FID01', 4, '02', 30, 5.0);

-- Diamond + 10% sur POS 02
INSERT INTO loyalty_status_rule (app_code, status_level, pos_code, point_value_override, bonus_rate_override)
VALUES ('FID01', 5, '02', 10, 10.0);

COMMIT;

PROMPT
PROMPT ═══ Volumétrie ═══
SELECT 'PROMO_POS_CONFIG'         AS tbl, COUNT(*) AS nb FROM promo_pos_config
UNION ALL SELECT 'PROMO_POS_PRODUCT',       COUNT(*) FROM promo_pos_product
UNION ALL SELECT 'PROMO_POS_HOURS',         COUNT(*) FROM promo_pos_hours
UNION ALL SELECT 'LOYALTY_STATUS_CONFIG',   COUNT(*) FROM loyalty_status_config
UNION ALL SELECT 'LOYALTY_STATUS_RULE',     COUNT(*) FROM loyalty_status_rule
 ORDER BY tbl;

PROMPT
PROMPT ═══ Démos / requêtes ═══

PROMPT [Q1] Promos actives actuellement
SELECT promo_code, promo_name, weekday_mask, hour_start, hour_end,
       action_type, multiplier, priority
  FROM promo_pos_config
 WHERE is_active = TRUE
   AND SYSDATE BETWEEN start_date AND end_date
 ORDER BY priority, promo_code;

PROMPT [Q2] Promos s'appliquant maintenant (date+hour+weekday)
SELECT ppc.promo_code, ppc.promo_name, ppc.action_type, ppp.discount_rate
  FROM promo_pos_config ppc
  LEFT JOIN promo_pos_product ppp ON ppp.pos_promo_id = ppc.pos_promo_id
 WHERE ppc.is_active = TRUE
   AND SYSDATE BETWEEN ppc.start_date AND ppc.end_date
   -- masque weekday_mask[day_of_week-1] = '1'
   AND SUBSTR(ppc.weekday_mask, TO_CHAR(SYSDATE, 'D') - 1, 1) = '1'
   -- heure actuelle entre hour_start et hour_end si définis
   AND (ppc.hour_start IS NULL OR TO_NUMBER(TO_CHAR(SYSDATE, 'HH24MI')) BETWEEN ppc.hour_start AND ppc.hour_end)
 ORDER BY ppc.priority;

PROMPT [Q3] Pyramide des niveaux fidélité
SELECT status_level, status_name, points_threshold, point_value,
       display_color
  FROM loyalty_status_config
 WHERE app_code = 'FID01'
 ORDER BY status_level;

PROMPT [Q4] Règles spécifiques POS
SELECT lsr.app_code, lsc.status_name, lsr.pos_code,
       lsr.point_value_override, lsr.bonus_rate_override
  FROM loyalty_status_rule lsr
  JOIN loyalty_status_config lsc
    ON lsc.app_code = lsr.app_code AND lsc.status_level = lsr.status_level
 ORDER BY lsr.pos_code, lsr.status_level;

PROMPT [Q5] Prochain palier pour chaque carte
SELECT lc.card_number, lc.points_balance,
       (SELECT MIN(points_threshold)
          FROM loyalty_status_config
         WHERE app_code = 'FID01'
           AND points_threshold > lc.points_balance) AS prochain_palier,
       (SELECT status_name
          FROM loyalty_status_config
         WHERE app_code = 'FID01'
           AND points_threshold = (SELECT MAX(points_threshold)
                                     FROM loyalty_status_config
                                    WHERE app_code = 'FID01'
                                      AND points_threshold <= lc.points_balance)) AS niveau_actuel
  FROM loyalty_card lc
 WHERE lc.status = 'A'
 ORDER BY lc.points_balance DESC;

PROMPT [Q6] Promos applicables ce samedi (weekday_mask position 6)
SELECT promo_code, promo_name, action_type
  FROM promo_pos_config
 WHERE SUBSTR(weekday_mask, 6, 1) = '1'
   AND is_active = TRUE;

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ SEED LOT R8 TERMINÉ
PROMPT ══════════════════════════════════════════════════════════
EXIT;
