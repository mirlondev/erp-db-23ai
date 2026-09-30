-- ============================================================
-- APEX SETUP 05 : Branding LITOKO SARL — Logo, CSS, JS
-- ============================================================
-- Crée un "Static Application Files" pour APEX 26.1 :
--   - Logo LITOKO SARL (placeholder data URL SVG)
--   - Feuille de style custom (couleurs Congo)
--   - JS utilitaires (filtres sites, formatage XAF)
--
-- Les blobs sont stockés dans APP_API (workspace REGAL).
-- Pour l'installer dans APEX IDE : Shared Components → Files
-- Static Application Files → upload (un par un) ou utiliser le
-- script ci-dessous pour les précharger.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE

CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   APEX SETUP 05 — Branding LITOKO pour apps APEX
PROMPT ══════════════════════════════════════════════════════════

-- Table de stockage des fichiers statiques LITOKO
-- (équivalent "Static Application Files" d'APEX, version DB-direct)
CREATE TABLE apex_static_file (
  file_id              NUMBER GENERATED ALWAYS AS IDENTITY,
  file_name            VARCHAR2(120) NOT NULL,
  mime_type            VARCHAR2(80)  NOT NULL,
  file_blob            BLOB         NOT NULL,
  file_chars           VARCHAR2(20)  DEFAULT 'UTF-8',
  description          VARCHAR2(500),
  uploaded_by          VARCHAR2(20),
  uploaded_at          TIMESTAMP    DEFAULT SYSTIMESTAMP,
  CONSTRAINT pk_apex_static_file PRIMARY KEY (file_id),
  CONSTRAINT uk_apex_static_file  UNIQUE (file_name)
);

PROMPT
PROMPT [1] Logo LITOKO (SVG inline - placeholder)
INSERT INTO apex_static_file (file_name, mime_type, file_blob, description, uploaded_by)
VALUES (
  'litoko_logo.svg',
  'image/svg+xml',
  UTL_RAW.CAST_TO_RAW('<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 80" width="240" height="80">
  <rect width="240" height="80" fill="#0F4C81"/>
  <circle cx="40" cy="40" r="28" fill="#D4AF37"/>
  <text x="40" y="48" font-family="Arial, sans-serif" font-size="28" font-weight="bold"
        text-anchor="middle" fill="#0F4C81">L</text>
  <text x="80" y="38" font-family="Arial, sans-serif" font-size="22" font-weight="bold"
        fill="#FFFFFF">LITOKO</text>
  <text x="80" y="58" font-family="Arial, sans-serif" font-size="11" fill="#D4AF37">SARL</text>
  <text x="80" y="72" font-family="Arial, sans-serif" font-size="8" fill="#CCCCCC">Pointe-Noire, CG</text>
</svg>'),
  'Logo LITOKO SARL — Pointe-Noire, Congo Brazzaville',
  'LIT_APEX_INIT'
);

PROMPT
PROMPT [2] Feuille de style LITOKO (couleurs Congo + accessibilité)
INSERT INTO apex_static_file (file_name, mime_type, file_blob, description, uploaded_by)
VALUES (
  'litoko_theme.css',
  'text/css',
  UTL_RAW.CAST_TO_RAW('/* LITOKO SARL — Thème APEX 26.1 (Congo) */

/* Couleurs drapeau Congo Brazzaville */
:root {
  --lit-primary:    #0F4C81;   /* Bleu profond */
  --lit-secondary:  #D4AF37;   /* Or */
  --lit-accent:     #2E8B57;   /* Vert forêt tropicale */
  --lit-danger:     #B00020;
  --lit-warning:    #E67E22;
  --lit-success:    #16A34A;
  --lit-bg:         #F5F7FA;
  --lit-bg-card:    #FFFFFF;
  --lit-text:       #1F2937;
  --lit-text-muted: #6B7280;
  --lit-border:     #E5E7EB;
}

/* Top bar universelle */
.t-LIT-header {
  background: linear-gradient(135deg, var(--lit-primary) 0%, #1B5E96 100%);
  color: #FFF;
  padding: 8px 20px;
  border-bottom: 3px solid var(--lit-secondary);
}

.t-LIT-header .t-LIT-logo {
  height: 48px;
  margin-right: 16px;
}

/* Cards KPI LITOKO */
.t-LIT-Card {
  background: var(--lit-bg-card);
  border-radius: 8px;
  padding: 16px;
  box-shadow: 0 1px 3px rgba(15,76,129,.08);
  border-left: 4px solid var(--lit-primary);
  transition: transform .15s ease;
}
.t-LIT-Card:hover { transform: translateY(-2px); }
.t-LIT-Card.t-LIT-Card--gold   { border-left-color: var(--lit-secondary); }
.t-LIT-Card.t-LIT-Card--green  { border-left-color: var(--lit-accent); }
.t-LIT-Card.t-LIT-Card--red    { border-left-color: var(--lit-danger); }
.t-LIT-Card.t-LIT-Card--orange { border-left-color: var(--lit-warning); }

.t-LIT-Card-label {
  font-size: 11px;
  text-transform: uppercase;
  color: var(--lit-text-muted);
  letter-spacing: .05em;
  margin-bottom: 6px;
}

.t-LIT-Card-value {
  font-size: 22px;
  font-weight: 600;
  color: var(--lit-primary);
  font-family: "Helvetica Neue", Arial, sans-serif;
}

.t-LIT-Card-suffix {
  font-size: 12px;
  color: var(--lit-text-muted);
  margin-left: 4px;
}

/* Tableau (IG) — couleur Congo */
.a-IG .a-IG-header {
  background: var(--lit-primary) !important;
  color: #FFF !important;
}

/* Badges statut transfert (compatible workflow pkg_transfer_stock) */
.t-LIT-badge {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 12px;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
}
.t-LIT-badge.DRAFT     { background: #E5E7EB; color: #1F2937; }
.t-LIT-badge.REQUESTED { background: #DBEAFE; color: #1E40AF; }
.t-LIT-badge.APPROVED  { background: #D1FAE5; color: #065F46; }
.t-LIT-badge.PACKED    { background: #FEF3C7; color: #92400E; }
.t-LIT-badge.IN_TRANSIT{ background: #FED7AA; color: #9A3412; }
.t-LIT-badge.RECEIVED  { background: #A7F3D0; color: #064E3B; }
.t-LIT-badge.CLOSED    { background: #16A34A; color: #FFF; }
.t-LIT-badge.CANCELLED { background: #FECACA; color: #B91C1C; }

/* Format montants XAF (séparateur milliers espace) */
.t-LIT-XAF::before { content: "FCFA "; opacity: .6; font-size: .85em; }
.t-LIT-XAF { font-variant-numeric: tabular-nums; font-weight: 500; }

/* Sites multi-sites — restriction visible */
.t-LIT-site-restricted {
  display: inline-block;
  padding: 1px 6px;
  background: var(--lit-secondary);
  color: #0F4C81;
  border-radius: 4px;
  font-size: 10px;
  font-weight: 700;
  margin-left: 8px;
}

/* TVA CEMAC 18.9% — badge spécifique */
.t-LIT-tva-189 {
  background: #FFF7ED;
  color: #9A3412;
  padding: 1px 6px;
  border-radius: 4px;
  font-size: 10px;
  font-weight: 700;
}

/* Responsive — Pointe-Noire mobile */
@media (max-width: 768px) {
  .t-LIT-Card-value { font-size: 18px; }
  .t-LIT-header { padding: 6px 10px; }
}
'),
  'Thème LITOKO — couleurs Congo Brazzaville + responsive',
  'LIT_APEX_INIT'
);

PROMPT
PROMPT [3] JavaScript utilitaire (filtre sites + format XAF)
INSERT INTO apex_static_file (file_name, mime_type, file_blob, description, uploaded_by)
VALUES (
  'litoko_utils.js',
  'application/javascript',
  UTL_RAW.CAST_TO_RAW('/* LITOKO SARL — Utilitaires APEX 26.1 */

// Formatage XAF (séparateur espace, suffixe FCFA)
window.litFormatXAF = function(value) {
  if (value === null || value === undefined) return "-";
  var n = Number(value);
  if (isNaN(n)) return value;
  return new Intl.NumberFormat("fr-FR", {
    maximumFractionDigits: 0
  }).format(n);
};

// Filtre site_code client-side (utilisé dans les LOV APEX)
window.litFilterSites = function(csv, allSites) {
  if (!csv) return allSites; // admin : tous
  var allowed = csv.split(",").map(function(s) { return s.trim(); });
  return allSites.filter(function(s) { return allowed.indexOf(s) >= 0; });
};

// Badge de statut transfert (s'appuie sur pkg_transfer_stock)
window.litBadgeStatus = function(status) {
  var map = {
    "DRAFT":     { class: "DRAFT",     label: "Brouillon" },
    "REQUESTED": { class: "REQUESTED", label: "Demandé" },
    "APPROVED":  { class: "APPROVED",  label: "Approuvé" },
    "PACKED":    { class: "PACKED",    label: "Emballé" },
    "IN_TRANSIT":{ class: "IN_TRANSIT",label: "En transit" },
    "RECEIVED":  { class: "RECEIVED",  label: "Reçu" },
    "CLOSED":    { class: "CLOSED",    label: "Clôturé" },
    "CANCELLED": { class: "CANCELLED", label: "Annulé" }
  };
  var s = map[status] || { class: "DRAFT", label: status };
  return "<span class=\"t-LIT-badge " + s.class + "\">" + s.label + "</span>";
};

// Hook APEX : applique le format XAF aux cellules IR/IG
apex.jQuery(document).ready(function() {
  apex.jQuery(".t-LIT-XAF").each(function() {
    var raw = apex.jQuery(this).text();
    if (raw && !isNaN(parseFloat(raw))) {
      apex.jQuery(this).text(window.litFormatXAF(raw));
    }
  });
});
'),
  'JS utilitaire LITOKO : format XAF, badges statut, filtre sites',
  'LIT_APEX_INIT'
);

PROMPT
PROMPT [4] Vue pratique des fichiers
CREATE OR REPLACE VIEW v_apex_static_files AS
SELECT file_id, file_name, mime_type,
       DBMS_LOB.GETLENGTH(file_blob) AS size_bytes,
       description, uploaded_at
  FROM apex_static_file;

PROMPT
PROMPT [GRANTS] accessible aux apps APEX
GRANT SELECT ON apex_static_file TO app_sales, app_inv, app_pos, app_gl, app_purchase;
GRANT SELECT ON v_apex_static_files TO app_sales, app_inv, app_pos, app_gl, app_purchase;

PROMPT
PROMPT ═══ Validation ═══
SELECT file_name, mime_type,
       DBMS_LOB.GETLENGTH(file_blob) AS size_bytes
  FROM apex_static_file
 ORDER BY file_id;

PROMPT
PROMPT ═══ Instructions d'installation dans APEX IDE ═══
PROMPT
PROMPT 1. Workspace REGAL → App Builder → Shared Components
PROMPT    → Files (Static Application Files) → Upload File
PROMPT    → Pour chaque fichier ci-dessus, uploader depuis la table :
PROMPT      SELECT file_blob FROM app_api.apex_static_file WHERE file_name = '...';
PROMPT    → Ou utiliser APEX_APPLICATION_TEMP_FILES via API.
PROMPT 2. CSS Theme : Edit Application → Shared Components
PROMPT    → User Interface → CSS / File URLs → Ajouter '#APP_FILES#litoko_theme.css'
PROMPT 3. Logo dans le Header : Pages → Layout → Header
PROMPT    → Logo Type: Image, File: #APP_FILES#litoko_logo.svg
PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ BRANDING LITOKO INSTALLÉ
PROMPT   - 3 fichiers : SVG logo + CSS theme + JS utils
PROMPT   - Couleurs Congo Brazzaville (bleu/or/vert)
PROMPT   - Badges statut transfert (compatible pkg_transfer_stock)
PROMPT   - Format XAF (séparateur espace + suffixe FCFA)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
