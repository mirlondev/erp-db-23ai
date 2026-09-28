-- ============================================================
-- fix_invalid.sql — Réparation des objets invalides
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200

CONNECT system/oracle@localhost:1521/FREEPDB1

PROMPT ═══════════════════════════════════════════════════════
PROMPT   RÉPARATION DES OBJETS INVALIDES
PROMPT ═══════════════════════════════════════════════════════

PROMPT
PROMPT [1] Diagnostic — Erreurs de compilation
SELECT owner, name, type, line, position, text
  FROM all_errors
 WHERE owner LIKE 'APP\_%' ESCAPE '\'
 ORDER BY owner, name, sequence;

PROMPT
PROMPT [2] Tentative de recompilation globale
EXEC UTL_RECOMP.RECOMP_SERIAL('APP_SALES');
EXEC UTL_RECOMP.RECOMP_SERIAL('APP_API');
EXEC UTL_RECOMP.RECOMP_SERIAL('APP_PRODUCT');
EXEC UTL_RECOMP.RECOMP_SERIAL('APP_INV');
EXEC UTL_RECOMP.RECOMP_SERIAL('APP_POS');
EXEC UTL_RECOMP.RECOMP_SERIAL('APP_PARTY');

PROMPT
PROMPT [3] État après recompilation
SELECT owner, object_type, object_name, status
  FROM all_objects
 WHERE status = 'INVALID'
   AND owner LIKE 'APP\_%' ESCAPE '\'
 ORDER BY owner, object_type, object_name;

EXIT;