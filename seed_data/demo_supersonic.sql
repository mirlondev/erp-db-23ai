-- ============================================================
-- demo_supersonic.sql — Démonstration complète
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100

CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

PROMPT ═══════════════════════════════════════════════════════
PROMPT   DÉMO — DONNÉES RÉELLES SUPER SONIC
PROMPT ═══════════════════════════════════════════════════════

PROMPT
PROMPT [1] Catalogue articles (Tefal, Colgate)
SELECT product_code, short_name, category_name, brand_name, standard_price
  FROM v_product
 WHERE category_name IN ('Électroménager','Hygiène / Entretien')
 ORDER BY product_code;

PROMPT
PROMPT [2] Clients SFP (Star Foods)
SELECT party_code, party_name, phone, city_code
  FROM v_customer
 WHERE party_code LIKE 'SFP%'
 ORDER BY party_code
 FETCH FIRST 10 ROWS ONLY;

PROMPT
PROMPT [3] Stock entrepôt W90
SELECT warehouse_code, product_code, product_name, stock_qty
  FROM v_stock
 WHERE warehouse_code = 'W90'
   AND stock_qty > 0
 ORDER BY product_code;

PROMPT
PROMPT [4] Tickets du 18/04/2026 (session 626)
SELECT terminal_id, ticket_no, TO_CHAR(ticket_date,'HH24:MI:SS') AS heure,
       customer_name, total_ttc, status
  FROM v_ticket
 WHERE TRUNC(ticket_date) = DATE '2026-04-18'
 ORDER BY ticket_no;

PROMPT
PROMPT [5] Duality View — Article Tefal en JSON (API-ready)
SELECT JSON_SERIALIZE(data PRETTY)
  FROM dv_product
 WHERE JSON_VALUE(data, '$.productCode') = '31274';

PROMPT
PROMPT [6] Duality View — Client SHENG FENG en JSON
SELECT JSON_SERIALIZE(data PRETTY)
  FROM dv_party
 WHERE JSON_VALUE(data, '$.partyCode') = 'SFP031';

PROMPT
PROMPT [7] Vue JSON — Ticket 1011578 complet (lignes + paiements)
SELECT JSON_SERIALIZE(data PRETTY)
  FROM v_ticket_json
 WHERE JSON_VALUE(data, '$._id') = '1011578';

EXIT;