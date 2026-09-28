# Changelog

Toutes les modifications notables sont documentées ici.
Format : [Date] - [Lot/Section] - Description

## [2026-09-28] - Session principale (~ 36% couverture legacy)

### Quick wins (Q1-Q4)
- **package pkg_pos_sales** : orchestration ticket + promo + fidélité (4 fonctions)
- **trigger trg_invoice_overdue** : auto-update statut + calcul balance
- **dv_invoice / dv_payment / dv_customer_credit** : Duality Views REST
- **v_dashboard_executive + v_top_kpi_dashboard** : 16 KPI temps réel

### Lot 1A-1F (Documents + Achats)
- **1A** (5 tables) : doc_imputation, doc_line_lot/serial/shortage/cost
- **1B** (6 tables) : doc_advance_lettering, doc_loading_note, doc_delivery_option, doc_foreign_header (incoterms), doc_request, doc_attachment
- **1C** (4 tables) : doc_extra_cost (ventilation multi-lignes), doc_tax_detail, doc_pricing_rule
- **1D** (4 tables) : doc_commercial_status, doc_commercial_link, doc_followup, doc_signature (SHA-256)
- **1E** (7 tables + **app_ship**) : shipment_carrier, shipment, shipment_line, shipment_tracking, shipment_cost, shipment_address, shipment_exception
- **1F** (4 tables + **app_purchase**) : purchase_request, purchase_request_line, supplier_quote, supplier_quote_line

### Package pkg_doc
- Spec + body du package document commercial
- create_quote, convert_quote_to_order, validate_document, cancel_document, link_documents
- Audit via sys_audit_trail (R13)

### ETL Squelette
- **pkg_etl_legacy** : package de migration 11g → 23ai
- migrate_table, migrate_lot, verify_mapping, get_migration_report
- Mapping documenté (CAISSE → app_pos/party/product, XCPTA → app_gl, etc.)
- Stratégie DRY_RUN obligatoire avant production

### OHADA Squelette
- **8 nouvelles tables app_gl** : gl_account_class, gl_account_ohada, gl_cost_center_axis, gl_cost_center, gl_analytical_entry, gl_fiscal_year, gl_fiscal_period, gl_budget
- Plan SYSCOHADA préchargé (411/401/701/601/521/530/443/445...)

## [2026-09-28] - Lots R1-R14 (Retail complet)

### R14 - Interfaces & Intégrations (5 tables)
- interface_endpoint, interface_log, sync_queue, import_batch, export_config

### R13 - Sécurité avancée & Audit (5 tables)
- sys_role, sys_user_role, sys_permission, sys_role_permission, sys_audit_trail

### R12 - KPI & Reporting (5 tables + 3 MV + 3 vues)
- kpi_definition, kpi_daily_snapshot, sales_target, report_definition, report_execution
- mv_hourly_sales, mv_monthly_top_products, mv_customer_performance
- v_kpi_today, v_critical_stock, v_customer_balance

### R11 - Alertes & Notifications (6 tables)
- alert_type, alert_rule, alert_instance, notification_channel, notification_subscription, notification_queue

### R10 - Cartes cadeaux & Bons (5 tables)
- voucher_type, voucher_master, voucher_lot, voucher_transaction, voucher_audit

### R9 - Inventaire physique complet (3 tables)
- inventory_count_zone, inventory_count_detail, inventory_adjustment

### R8 - Promotions POS avancé (5 tables)
- promo_pos_config, promo_pos_product, promo_pos_hours, loyalty_status_config, loyalty_status_rule

### R7 - POS avancé (5 tables)
- ticket_return, ticket_return_line, ticket_discount, ticket_loyalty, pos_cash_closure

### R6 - Règlements clients avancés (6 tables)
- payment_method_ref, cash_register_session, invoice_payment_link, customer_statement, aging_balance, dunning_log

### R5 - Facturation & Avoirs (7 tables dans nouveau **app_ar**)
- invoice, invoice_line, credit_note, credit_note_line, payment, payment_allocation, customer_credit

### R4 - Réappro & Transferts (6 tables)
- transfer_header, transfer_line, replenishment_suggestion, purchase_order_header, purchase_order_line, stock_valuation

### R3 - Stock avancé (7 tables)
- inv_avg_cost, inv_product_lot, inv_status_ref, inv_stock_status, inv_count_zone, inv_movement_status, inv_reorder

### R2 - Fidélité client (7 tables)
- loyalty_card_type, loyalty_card, loyalty_operation_type, loyalty_operation, loyalty_lot, loyalty_app, loyalty_log

### R1 - Promotions & Remises (8 tables)
- promo_header, promo_product, promo_quantity, promo_customer_family, promo_pos, price_tier, price_tier_quantity, price_tier_product

## [2026-09-28] - Bootstrap initial (R0)

### Schémas créés (16)
- app_sys, app_org, app_product, app_party, app_inv, app_doc, app_pos, app_sales, app_gl, app_cash, app_hist, app_api, app_ar (R5), app_ship (1E), app_purchase (1F)

### Tables cœur (R0)
- sys_*, org_*, prod_*, product, party_*, inv_stock, doc_*, pos_*, ticket*, gl_*, cash_*, hist_*
- 4 packages initial : pkg_pricing, pkg_inventory, pkg_sales, pkg_gl
- 4 triggers : ticket, inventory, stock alert, audit document
- 3 Materialized Views initiales (écrasées par R12)
- 3 DBMS_SCHEDULER jobs
- Duality Views : dv_product, dv_party (avec workaround PK composite via v_*_json)

### Hotfix
- 00_init_schemas.sql : suppression du leak de chemins absolus qui plantait SQL*Plus

## État actuel

| Catégorie | Quantité |
|---|---:|
| Schémas | 16 (incluant 4 ajoutés en cours de route) |
| Tables | ~ 140 modernes (cible : 391 legacy → 35% couvert) |
| Foreign Keys | ~ 250 (héritage legacy) |
| Indexes | ~ 80 |
| Vues classiques | ~ 12 |
| Materialized Views | 3 |
| Duality Views | 5 |
| Packages PL/SQL | 7 (4 core + pkg_pos_sales + pkg_doc + pkg_etl_legacy) |
| Triggers | 6 |
| Schedulers | 3 |
| Seeds (S00-S22) | 22 fichiers |
| Scripts DDL (00-42) | ~ 30 scripts |
