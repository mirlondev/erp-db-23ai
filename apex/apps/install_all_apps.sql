-- ============================================================
-- Runner : Installation des 5 apps APEX 26.1 REGAL
-- ============================================================
-- Usage :
--   sqlplus sys/oracle@localhost:1521/FREEPDB1 as sysdba \
--     @apex/apps/install_all_apps.sql
--
-- Prérequis : 12_apex_health_check.sql passe ✓
--             setup/01-11 joués ✓
-- ============================================================

PROMPT ══════════════════════════════════════════════════════════
PROMPT   Installation des 5 apps APEX REGAL
PROMPT ══════════════════════════════════════════════════════════

@install_app100_pos.sql
@install_app200_300_400_500.sql

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ Les 5 apps sont installées !
PROMPT
PROMPT   URLs d'accès (après démarrage ORDS) :
PROMPT   - App 100 POS      : http://localhost:8080/apex/f?p=100:10
PROMPT   - App 200 Stock    : http://localhost:8080/apex/f?p=200:10
PROMPT   - App 300 Achats   : http://localhost:8080/apex/f?p=300:10
PROMPT   - App 400 Compta   : http://localhost:8080/apex/f?p=400:10
PROMPT   - App 500 Admin    : http://localhost:8080/apex/f?p=500:10
PROMPT
PROMPT   Login : ADMIN / <password APEX admin>
PROMPT ══════════════════════════════════════════════════════════
EXIT;
