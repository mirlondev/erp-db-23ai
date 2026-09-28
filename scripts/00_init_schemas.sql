-- ============================================================
-- SCRIPT 00 : Nettoyage + Création des schémas modernes
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK ON

PROMPT ═══════════════════════════════════════════════════════
PROMPT   INITIALISATION — Schémas modernes
PROMPT ═══════════════════════════════════════════════════════

-- Se placer dans FREEPDB1
ALTER SESSION SET CONTAINER = FREEPDB1;

PROMPT
PROMPT [1] Suppression des anciens schémas
BEGIN
  FOR u IN (SELECT username FROM dba_users 
             WHERE username IN (
               'APP_SYS','APP_ORG','APP_PRODUCT','APP_PARTY',
               'APP_INV','APP_DOC','APP_POS','APP_SALES',
               'APP_GL','APP_CASH','APP_HIST','APP_API','APP_AR','APP_SHIP','APP_PURCHASE'
             )
               AND oracle_maintained = 'N') LOOP
    EXECUTE IMMEDIATE 'DROP USER '||u.username||' CASCADE';
    DBMS_OUTPUT.PUT_LINE('  Drop ' || u.username);
  END LOOP;
END;
/

PROMPT
PROMPT [2] Création des 12 schémas
CREATE USER app_sys     IDENTIFIED BY "AppSys#2026"     
  DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
CREATE USER app_org     IDENTIFIED BY "AppOrg#2026"     
  DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
CREATE USER app_product IDENTIFIED BY "AppProduct#2026" 
  DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
CREATE USER app_party   IDENTIFIED BY "AppParty#2026"   
  DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
CREATE USER app_inv     IDENTIFIED BY "AppInv#2026"     
  DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
CREATE USER app_doc     IDENTIFIED BY "AppDoc#2026"     
  DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
CREATE USER app_pos     IDENTIFIED BY "AppPos#2026"     
  DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
CREATE USER app_sales   IDENTIFIED BY "AppSales#2026"   
  DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
CREATE USER app_gl      IDENTIFIED BY "AppGl#2026"      
  DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
CREATE USER app_cash    IDENTIFIED BY "AppCash#2026"    
  DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
CREATE USER app_hist    IDENTIFIED BY "AppHist#2026"    
  DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
CREATE USER app_api     IDENTIFIED BY "AppApi#2026"     
  DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
CREATE USER app_ar      IDENTIFIED BY "AppAr#2026"
  DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
CREATE USER app_ship    IDENTIFIED BY "AppShip#2026"
  DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
CREATE USER app_purchase IDENTIFIED BY "AppPurchase#2026"
  DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;

PROMPT
PROMPT [3] Attribution des privilèges
BEGIN
  FOR u IN (SELECT username FROM dba_users 
             WHERE username LIKE 'APP\_%' ESCAPE '\'
               AND oracle_maintained = 'N') LOOP
    EXECUTE IMMEDIATE 'GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, 
                              CREATE SEQUENCE, CREATE PROCEDURE, 
                              CREATE TRIGGER, CREATE SYNONYM, CREATE TYPE,
                              CREATE MATERIALIZED VIEW, CREATE JOB,
                              CREATE DOMAIN TO '||u.username;
  END LOOP;
END;
/

-- (Fin de la phase d'attribution des privileges)

PROMPT
PROMPT [4] Validation — Schémas créés
SELECT username, 
       default_tablespace, 
       account_status
  FROM dba_users
 WHERE username LIKE 'APP\_%' ESCAPE '\'
   AND oracle_maintained = 'N'
 ORDER BY username;

PROMPT ═══════════════════════════════════════════════════════
PROMPT   ✅ INITIALISATION TERMINÉE
PROMPT ═══════════════════════════════════════════════════════