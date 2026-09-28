-- ============================================================
-- S01 : Seed app_sys — données SUPER SONIC
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200

CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT ===============================================================
PROMPT   SEED app_sys — Données SUPER SONIC
PROMPT ===============================================================

-- Nettoyage
DELETE FROM sys_user_access;
DELETE FROM sys_user;
DELETE FROM sys_access_key;
DELETE FROM sys_parameter;
DELETE FROM sys_city;
DELETE FROM sys_country;
DELETE FROM sys_currency;
COMMIT;

PROMPT [1] Devises (Congo = XAF/XOF)
INSERT INTO sys_currency (currency_code, currency_name, is_fixed_rate, decimal_places)
VALUES ('XAF', 'Franc CFA BEAC', TRUE, 0);
INSERT INTO sys_currency (currency_code, currency_name, is_fixed_rate, decimal_places)
VALUES ('XOF', 'Franc CFA BCEAO', TRUE, 0);
INSERT INTO sys_currency (currency_code, currency_name, is_fixed_rate, decimal_places)
VALUES ('USD', 'Dollar Américain', TRUE, 2);
INSERT INTO sys_currency (currency_code, currency_name, is_fixed_rate, decimal_places)
VALUES ('EUR', 'Euro', TRUE, 2);

PROMPT [2] Pays
INSERT INTO sys_country VALUES ('CGO', 'Congo');
INSERT INTO sys_country VALUES ('COD', 'RD Congo');
INSERT INTO sys_country VALUES ('CMR', 'Cameroun');
INSERT INTO sys_country VALUES ('GAB', 'Gabon');
INSERT INTO sys_country VALUES ('TCD', 'Tchad');
INSERT INTO sys_country VALUES ('CAF', 'Centrafrique');

PROMPT [3] Villes
INSERT INTO sys_city VALUES ('PNR', 'CGO', 'Pointe-Noire');
INSERT INTO sys_city VALUES ('BZV', 'CGO', 'Brazzaville');
INSERT INTO sys_city VALUES ('DOL', 'CGO', 'Dolisie');
INSERT INTO sys_city VALUES ('OLL', 'CGO', 'Oyo-Ollombo');
INSERT INTO sys_city VALUES ('MKL', 'CGO', 'Makélékélé');
INSERT INTO sys_city VALUES ('NGK', 'CGO', 'Nkayi');

PROMPT [4] Utilisateurs (d'après les CODUTI réels)
INSERT INTO sys_user (user_code, user_name, is_active, email)
VALUES ('ROOT', 'Administrateur système', TRUE, 'root@supersonic-cg.com');
INSERT INTO sys_user (user_code, user_name, is_active, email)
VALUES ('VIJJU', 'Caissier VIJJU', TRUE, NULL);
INSERT INTO sys_user (user_code, user_name, is_active, email)
VALUES ('BABU', 'Caissier BABU', TRUE, 'babu@supersonic-cg.com');
INSERT INTO sys_user (user_code, user_name, is_active, email)
VALUES ('MANOJ', 'Gestion stock MANOJ', TRUE, NULL);
INSERT INTO sys_user (user_code, user_name, is_active, email)
VALUES ('KAMAL', 'Gestion stock KAMAL', TRUE, NULL);
INSERT INTO sys_user (user_code, user_name, is_active, email)
VALUES ('MANNU', 'Gestion stock MANNU', TRUE, NULL);
INSERT INTO sys_user (user_code, user_name, is_active, email)
VALUES ('JT', 'Gestion stock JT', TRUE, NULL);
INSERT INTO sys_user (user_code, user_name, is_active, email)
VALUES ('DIVYA', 'Gestion stock DIVYA', TRUE, NULL);
INSERT INTO sys_user (user_code, user_name, is_active, email)
VALUES ('RGCML', 'Responsable RGCML', TRUE, NULL);
INSERT INTO sys_user (user_code, user_name, is_active, email)
VALUES ('DHARM', 'Gestion stock DHARM', TRUE, NULL);
INSERT INTO sys_user (user_code, user_name, is_active, email)
VALUES ('NIKHI', 'Gestion stock NIKHI', TRUE, NULL);
INSERT INTO sys_user (user_code, user_name, is_active, email)
VALUES ('SQL', 'Utilisateur SQL', TRUE, NULL);
INSERT INTO sys_user (user_code, user_name, is_active, email)
VALUES ('XXXX', 'Utilisateur historique', FALSE, NULL);

PROMPT [5] Clés d'accès (d'après les profils réels)
INSERT INTO sys_access_key (access_key_code, access_key_name, is_active, key_type) VALUES ('VEN_ANN', 'Annulation ticket', TRUE, 'SALES');
INSERT INTO sys_access_key (access_key_code, access_key_name, is_active, key_type) VALUES ('VEN_REM', 'Accès taux de remise', TRUE, 'SALES');
INSERT INTO sys_access_key (access_key_code, access_key_name, is_active, key_type) VALUES ('VEN_PU',  'Accès PU de vente', TRUE, 'SALES');
INSERT INTO sys_access_key (access_key_code, access_key_name, is_active, key_type) VALUES ('VEN_QTE', 'Saisie des quantités', TRUE, 'SALES');
INSERT INTO sys_access_key (access_key_code, access_key_name, is_active, key_type) VALUES ('VEN_REMB','Saisie des remboursements', TRUE, 'SALES');
INSERT INTO sys_access_key (access_key_code, access_key_name, is_active, key_type) VALUES ('VEN_AVOIR','Saisie des avoirs', TRUE, 'SALES');
INSERT INTO sys_access_key (access_key_code, access_key_name, is_active, key_type) VALUES ('VEN_CLOT','Clôture caisse', TRUE, 'POS');
INSERT INTO sys_access_key (access_key_code, access_key_name, is_active, key_type) VALUES ('VEN_REED','Réédition ticket', TRUE, 'SALES');
INSERT INTO sys_access_key (access_key_code, access_key_name, is_active, key_type) VALUES ('VEN_FACT','Facturation/Réédition', TRUE, 'SALES');
INSERT INTO sys_access_key (access_key_code, access_key_name, is_active, key_type) VALUES ('VEN_LIGNE','Modification ligne (Qte/PU/Rem)', TRUE, 'SALES');
INSERT INTO sys_access_key (access_key_code, access_key_name, is_active, key_type) VALUES ('BRD_OFFICE','Bordereaux Office', TRUE, 'STOCK');
INSERT INTO sys_access_key (access_key_code, access_key_name, is_active, key_type) VALUES ('BRD_WHSE','Bordereaux Entrepôt', TRUE, 'STOCK');
INSERT INTO sys_access_key (access_key_code, access_key_name, is_active, key_type) VALUES ('BRD_SALES','Bordereaux Ventes', TRUE, 'SALES');
INSERT INTO sys_access_key (access_key_code, access_key_name, is_active, key_type) VALUES ('BRD_SR','Bordereaux Service', TRUE, 'STOCK');
INSERT INTO sys_access_key (access_key_code, access_key_name, is_active, key_type) VALUES ('BRD_CRS_MD','Bordereaux Crédit Marchandise', TRUE, 'SALES');
INSERT INTO sys_access_key (access_key_code, access_key_name, is_active, key_type) VALUES ('BRD_PC','Bordereaux Pertes/Casses', TRUE, 'STOCK');
INSERT INTO sys_access_key (access_key_code, access_key_name, is_active, key_type) VALUES ('CASH_DATE','Modification date', TRUE, 'POS');
INSERT INTO sys_access_key (access_key_code, access_key_name, is_active, key_type) VALUES ('CASH_REED','Réédition reçu', TRUE, 'POS');
INSERT INTO sys_access_key (access_key_code, access_key_name, is_active, key_type) VALUES ('ADM_SES','Accès multi-sessions', TRUE, 'ADMIN');
INSERT INTO sys_access_key (access_key_code, access_key_name, is_active, key_type) VALUES ('VEN_ZPOS','Saisie ZTC/ZOP', TRUE, 'SALES');
INSERT INTO sys_access_key (access_key_code, access_key_name, is_active, key_type) VALUES ('VEN_REMDEP','Dépassement plafond remise', TRUE, 'SALES');

PROMPT [6] Paramètres système (PARGEN extraits)
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'DEV', 'Devise par défaut', 'XAF', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'TAR', 'Tarif standard', '1', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'PRO', 'Tarif promotionnel', '9', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'ESP', 'Mode de règlement espèces', 'ESP', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'EAN', 'Code barre EAN 13', 'O', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'RLA', 'Retour à la ligne auto', 'O', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'T2B', 'Ticket to Invoice/BL auto', 'O', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'ABC', 'Activer bon', 'O', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'MSC', 'MAJ stock / VTE caisse', 'O', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'FEX', 'Fidélité externe', 'O', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'RCP', 'Récap/Enregistrement du ticket', 'O', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'ITL', 'Indicatif téléphonique national', '242', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'MCA', 'Profil modification code article', 'NOT_ALLOWED', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'HMR', 'Hide menu bar on receipt', 'O', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'LDB', 'Affichage liste/doublon code-barre', 'O', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'DSN', 'Durée stock négatif avant blocage', NULL, 7, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'MQT', 'Maximum qté sur vente caisse', NULL, 9999, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'BCA', 'Bordereau ventes/caisse', 'VC', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'TVC', 'Tiers bordereau vente/caisse', 'CL0001', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'MBA', 'Mode règlement bon achat', 'BSO', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'MBE', 'Mode règlement bon expatrié', 'AEX', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'MBC', 'Mode règlement bon cadeau', NULL, NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'MTN', 'MTN / Airtel Money', 'MTN', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'RBA', 'Réédition bon', 'O', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'BFP', 'Bon format papier', 'O', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'DTA', 'Désactiver fonction ticket attente', 'N', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'IST', 'Interdire suppression ticket en cours', 'O', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'MBI', 'Mode règlement bon interne', 'BPR', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'ZTC', 'Code article ZTC', '0000000', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'CLO', 'Profil accès clôture caisse', 'VEN_CLOT', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'PRT', 'Profil réédition ticket', 'VEN_REED', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'PRF', 'Profil facturation/réédition', 'VEN_FACT', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'REM', 'Profil accès taux remise', 'VEN_REM', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'PUV', 'Profil accès PU de vente', 'VEN_PU', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'QTE', 'Profil saisie des quantités', 'VEN_QTE', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'RMB', 'Profil saisie des remboursements', 'VEN_REMB', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'AVR', 'Profil saisie des avoirs', 'VEN_AVOIR', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'SES', 'Profil accès multi-sessions', 'ADM_SES', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'ANN', 'Profil annulation ticket', 'VEN_ANN', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'LIG', 'Profil accès ligne en modif', 'VEN_LIGNE', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'RTS', 'Répertoire transfert session', 'D:\ECHANGES\OUT', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'BZ',  'Répertoire stockage bande Z', 'C:\TEMP', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'CLS', 'Clôture sessions caissières', 'N', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'MCF', 'Mode règlement carte fidélité', 'FCD', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'MCB', 'Mode règlement carte bancaire', 'CTB', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'T01', 'Compte client par défaut', 'CL0001', NULL, NULL);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, string_value, number_value, rate_value)
VALUES ('PARGEN', 'RPA', 'Code reprise avoir', 'RPA', NULL, NULL);

-- Billeterie (BILLETERIE)
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, number_value)
VALUES ('BILLETERIE', 'B1', 'Billet 10000', 10000);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, number_value)
VALUES ('BILLETERIE', 'B2', 'Billet 5000', 5000);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, number_value)
VALUES ('BILLETERIE', 'B3', 'Billet 2000', 2000);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, number_value)
VALUES ('BILLETERIE', 'B4', 'Billet 1000', 1000);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, number_value)
VALUES ('BILLETERIE', 'B5', 'Billet 500', 500);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, number_value)
VALUES ('BILLETERIE', 'P1', 'Pièce 500', 500);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, number_value)
VALUES ('BILLETERIE', 'P2', 'Pièce 100', 100);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, number_value)
VALUES ('BILLETERIE', 'P3', 'Pièce 50', 50);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, number_value)
VALUES ('BILLETERIE', 'P5', 'Pièce 25', 25);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, number_value)
VALUES ('BILLETERIE', 'P6', 'Pièce 10', 10);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, number_value)
VALUES ('BILLETERIE', 'P7', 'Pièce 5', 5);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, number_value)
VALUES ('BILLETERIE', 'P8', 'Pièce 2', 2);
INSERT INTO sys_parameter (parameter_code, parameter_key, parameter_name, number_value)
VALUES ('BILLETERIE', 'P9', 'Pièce 1', 1);

COMMIT;

PROMPT [7] Validation
SELECT 'DEVISE'  AS tbl, COUNT(*) AS nb FROM sys_currency
UNION ALL SELECT 'PAYS',    COUNT(*) FROM sys_country
UNION ALL SELECT 'VILLE',   COUNT(*) FROM sys_city
UNION ALL SELECT 'USER',    COUNT(*) FROM sys_user
UNION ALL SELECT 'CLE',     COUNT(*) FROM sys_access_key
UNION ALL SELECT 'PARAM',   COUNT(*) FROM sys_parameter;

PROMPT ✅ S01 terminé
EXIT;