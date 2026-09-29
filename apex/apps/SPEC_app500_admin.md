# Spécifications UI — App 500 « Administration système » (APEX 26.1)

Schéma : `APP_SYS` · Auth : `app_sys.pkg_apex_auth` · Rôle requis : `REGAL_ADMIN`

## Pages

| Page | Type | Source | Composants | Actions |
|---|---|---|---|---|
| 1 | Dashboard | vues ci-dessous | Cards KPI, Chart (events/min), IR | — |
| 2 | Outbox / CDC | `app_sys.outbox_event` | IG en lecture seule + bouton *Reprocess* | PL/SQL: maj `status='PENDING'` où `status='FAILED'` |
| 3 | Transferts Master→Boutiques | `app_sys.v_tt_pending` (script 53) | Faceted Search + IR | drill-down par table TT_* |
| 4 | Jobs & Scheduler | `dba_scheduler_jobs` (filtre `JOB_NAME LIKE 'REGAL%'`) | Report + boutons Run/Enable | `DBMS_SCHEDULER.RUN_JOB` via APEX_EXEC |
| 5 | Messages i18n | `sys_message` + `sys_message_lang` | Master-Detail (IG) | DML direct (few rows/séquentiel) |
| 6 | Sécurité PC/dépôt | `warehouse_pc_auth` | IG | DML + revoke (`revoked_at = SYSTIMESTAMP`) |
| 7 | Audit trail | `sys_audit_trail` partitionné (script 56) | IR + filtres date sévère | export CSV |

## KPI dashboard (page 1)

```sql
-- Events outbox par statut (24h)
SELECT status, COUNT(*) n
  FROM app_sys.outbox_event
 WHERE created_at > SYSTIMESTAMP - INTERVAL '1' DAY
 GROUP BY status;

-- Retard de réplication (minutes)
SELECT ROUND((SYSTIMESTAMP - MIN(created_at)) AT TIME ZONE 'UTC' * 1440) lag_min
  FROM app_sys.outbox_event WHERE status = 'PENDING';
```

## Règles legacy (ne pas casser les WS)

- Page 2 : le reprocess passe par le package sync (script 52), **jamais** par update direct des `TT_*`.
- Page 6 : l'écran écrit dans `warehouse_pc_auth` ; un trigger outbox (déjà livré en 52)
  propage vers les boutiques — identique à l'ancien comportement GCPDEP_AUTH_PC.
