-- S00_reset.sql — Nettoyage complet avant seed
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

PROMPT Nettoyage des schémas de seed
BEGIN
  -- app_pos
  EXECUTE IMMEDIATE 'DELETE FROM app_pos.pos_cash_movement';
  EXECUTE IMMEDIATE 'DELETE FROM app_pos.pos_session';
  EXECUTE IMMEDIATE 'DELETE FROM app_pos.pos_terminal';
  -- app_sales
  EXECUTE IMMEDIATE 'DELETE FROM app_sales.ticket_payment';
  EXECUTE IMMEDIATE 'DELETE FROM app_sales.ticket_line';
  EXECUTE IMMEDIATE 'DELETE FROM app_sales.ticket';
  -- app_inv
  EXECUTE IMMEDIATE 'DELETE FROM app_inv.inv_movement';
  EXECUTE IMMEDIATE 'DELETE FROM app_inv.inv_count_line';
  EXECUTE IMMEDIATE 'DELETE FROM app_inv.inv_count_header';
  EXECUTE IMMEDIATE 'DELETE FROM app_inv.inv_stock';
  -- app_gl
  EXECUTE IMMEDIATE 'DELETE FROM app_gl.gl_entry_line';
  EXECUTE IMMEDIATE 'DELETE FROM app_gl.gl_entry';
  EXECUTE IMMEDIATE 'DELETE FROM app_gl.gl_period';
  EXECUTE IMMEDIATE 'DELETE FROM app_gl.gl_subaccount';
  EXECUTE IMMEDIATE 'DELETE FROM app_gl.gl_account';
  EXECUTE IMMEDIATE 'DELETE FROM app_gl.gl_journal';
  EXECUTE IMMEDIATE 'DELETE FROM app_gl.gl_company';
  -- app_cash
  EXECUTE IMMEDIATE 'DELETE FROM app_cash.cash_movement';
  EXECUTE IMMEDIATE 'DELETE FROM app_cash.cash_journal';
  EXECUTE IMMEDIATE 'DELETE FROM app_cash.cash_movement_type';
  EXECUTE IMMEDIATE 'DELETE FROM app_cash.cash_register';
  -- app_party
  EXECUTE IMMEDIATE 'DELETE FROM app_party.party_bank';
  EXECUTE IMMEDIATE 'DELETE FROM app_party.party_address';
  EXECUTE IMMEDIATE 'DELETE FROM app_party.party';
  EXECUTE IMMEDIATE 'DELETE FROM app_party.party_nature';
  -- app_product
  EXECUTE IMMEDIATE 'DELETE FROM app_product.product_price';
  EXECUTE IMMEDIATE 'DELETE FROM app_product.product_barcode';
  EXECUTE IMMEDIATE 'DELETE FROM app_product.product_unit';
  EXECUTE IMMEDIATE 'DELETE FROM app_product.product_photo';
  EXECUTE IMMEDIATE 'DELETE FROM app_product.product';
  EXECUTE IMMEDIATE 'DELETE FROM app_product.prod_subcategory';
  EXECUTE IMMEDIATE 'DELETE FROM app_product.prod_category';
  EXECUTE IMMEDIATE 'DELETE FROM app_product.prod_brand';
  EXECUTE IMMEDIATE 'DELETE FROM app_product.prod_nature';
  EXECUTE IMMEDIATE 'DELETE FROM app_product.prod_shelf';
  EXECUTE IMMEDIATE 'DELETE FROM app_product.prod_price_list';
  -- app_org
  EXECUTE IMMEDIATE 'DELETE FROM app_org.org_pos';
  EXECUTE IMMEDIATE 'DELETE FROM app_org.org_warehouse';
  EXECUTE IMMEDIATE 'DELETE FROM app_org.org_company';
  COMMIT;
END;
/

PROMPT ✅ Nettoyage terminé
EXIT;