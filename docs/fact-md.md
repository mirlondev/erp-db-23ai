{# ═══════════════════════════════════════════════════════════════
   LITOKO SARL — Print Format SALES INVOICE (Facture Client)
   ERPNext v16 — wkhtmltopdf — Données 100% dynamiques
   ═══════════════════════════════════════════════════════════════ #}

<style>
  @page { size: A4; margin: 8mm 10mm 10mm 10mm; }
  body { font-family: Arial, Helvetica, sans-serif; font-size: 8pt; line-height: 1.25; color: #333; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .lt-doc { width: 100%; }
  .lt-doc table { border-collapse: collapse; width: 100%; }

  .lt-wm-draft { border: 1.5px solid #c9a227; color: #c9a227; background: #fffbea; text-align: center; font-size: 10pt; font-weight: bold; letter-spacing: 4px; padding: 2px; margin-bottom: 4px; border-radius: 2px; }
  .lt-wm-cancel { border: 1.5px solid #b00020; color: #b00020; background: #fdecea; text-align: center; font-size: 10pt; font-weight: bold; letter-spacing: 4px; padding: 2px; margin-bottom: 4px; border-radius: 2px; }

  .lt-header { width: 100%; margin-bottom: 3px; }
  .lt-header td { vertical-align: top; padding: 0; }
  .lt-logo-cell { width: 48px; }
  .lt-logo { width: 42px; height: 42px; background: #0F4C81; border-radius: 4px; color: #D4AF37; font-size: 18pt; font-weight: bold; text-align: center; line-height: 42px; border: 2px solid #D4AF37; }
  .lt-company-cell { padding-left: 8px; }
  .lt-company-name { font-size: 13pt; font-weight: bold; color: #0F4C81; letter-spacing: 0.5px; }
  .lt-company-tag { font-size: 6.5pt; color: #D4AF37; font-weight: bold; margin-top: 1px; letter-spacing: 0.5px; }
  .lt-company-addr { font-size: 7pt; color: #555; margin-top: 2px; line-height: 1.35; }
  .lt-company-ids { font-size: 6.5pt; color: #666; margin-top: 1px; line-height: 1.35; }
  .lt-qr-cell { width: 70px; text-align: right; }
  .lt-qr-box { width: 32px; height: 32px; border: 1px solid #ccc; display: inline-block; text-align: center; line-height: 32px; font-size: 6pt; color: #999; margin-bottom: 2px; }
  .lt-bc-text { font-size: 6.5pt; color: #666; font-family: "Courier New", monospace; }

  .lt-title-band { background: #0F4C81; color: #fff; text-align: center; font-size: 13pt; font-weight: bold; letter-spacing: 2px; padding: 3px 0; margin: 3px 0 2px 0; border-bottom: 2px solid #D4AF37; } /* Marge inférieure réduite */
  .lt-title-docno { font-size: 8pt; font-weight: normal; display: block; margin-top: 1px; color: #F5F7FA; }

  .lt-meta { width: 100%; margin: 1px 0 3px 0; font-size: 6.5pt; line-height: 1.25; } /* Marge réduite */
  .lt-meta td { vertical-align: top; padding: 0; }
  .lt-meta-left { width: 48%; padding-right: 6px; }
  .lt-meta-left .lbl { font-weight: bold; color: #0F4C81; }
  .lt-meta-right { width: 52%; }
  .lt-client-line { margin-bottom: 1px; }
  .lt-client-name { font-weight: bold; color: #333; }
  .lt-client-addr { font-size: 6pt; color: #555; }

  .lt-items { width: 100%; border: 1px solid #0F4C81; border-collapse: collapse; margin-top: 0px; } /* Marge supérieure réduite */
  .lt-items thead th { background: #0F4C81; color: #fff; border: 1px solid #0F4C81; padding: 3px 4px; font-size: 7pt; font-weight: bold; text-align: center; text-transform: uppercase; }
  .lt-items tbody td { border-left: 1px solid #ccc; border-right: 1px solid #ccc; border-top: none; border-bottom: 1px solid #ddd; padding: 2px 4px; font-size: 7.5pt; vertical-align: top; }
  .lt-items td.r { text-align: right; white-space: nowrap; }
  .lt-items td.c { text-align: center; white-space: nowrap; }
  .lt-items td.desig { text-align: left; }
  .lt-items td.desig strong { color: #0F4C81; font-size: 7.5pt; }
  .lt-items td.desig .desc { font-size: 6.5pt; color: #666; font-style: italic; }
  .lt-items td.desig .bc { font-size: 6.5pt; color: #444; font-family: "Courier New", monospace; }
  .lt-items tbody tr:nth-child(odd) td { background: #fff; }
  .lt-items tbody tr:nth-child(even) td { background: #F5F7FA; }
  .lt-items tbody tr { page-break-inside: avoid; }

  /* Lignes vides pour remplir l'espace */
  .lt-items tbody tr.lt-empty-row td {
    border-left: 1px solid #ccc; border-right: 1px solid #ccc; border-top: none; border-bottom: 1px solid #ddd;
    padding: 0; height: 14px; /* Hauteur approximative d'une ligne vide */
  }
  .lt-items tbody tr.lt-empty-row td:last-child {
    border-right: 1px solid #0F4C81; /* Bordure droite du tableau */
  }
  .lt-items tbody tr.lt-empty-row td:first-child {
    border-left: 1px solid #0F4C81; /* Bordure gauche du tableau */
  }

  .lt-recap-outer { border: 1px solid #0F4C81; border-top: none; page-break-inside: avoid; margin-top: 0; } /* Marge supérieure supprimée */
  .lt-recap-outer td { vertical-align: top; padding: 5px 6px; }
  .lt-recap-left { width: 36%; border-right: 1px solid #ddd; }
  .lt-recap-mid { width: 34%; border-right: 1px solid #ddd; }
  .lt-recap-right { width: 30%; text-align: center; vertical-align: middle; }
  .lt-vat { width: 100%; border-collapse: collapse; }
  .lt-vat th, .lt-vat td { border: 1px solid #ddd; padding: 2px 4px; font-size: 7pt; }
  .lt-vat th { background: #E8EEF4; text-align: center; color: #0F4C81; font-weight: bold; }
  .lt-vat td.r { text-align: right; } .lt-vat td.c { text-align: center; }
  .lt-totals { width: 100%; }
  .lt-totals td { padding: 2px 0; font-size: 8pt; border: none; }
  .lt-totals td.lbl { font-weight: bold; color: #555; }
  .lt-totals td.num { text-align: right; font-weight: bold; white-space: nowrap; color: #333; }
  .lt-totals tr.net-row td { border-top: 1px solid #ddd; padding-top: 3px; color: #0F4C81; }
  .lt-net-box { background: #0F4C81; border-radius: 4px; padding: 8px 6px; color: #fff; text-align: center; border: 2px solid #D4AF37; }
  .lt-net-label { font-size: 8pt; font-weight: bold; text-transform: uppercase; letter-spacing: 1px; color: #D4AF37; }
  .lt-net-amount { font-size: 14pt; font-weight: bold; margin-top: 3px; }
  .lt-net-cur { font-size: 7pt; color: #D4AF37; margin-top: 2px; }
  .lt-words { border: 1px solid #0F4C81; border-top: none; text-align: center; padding: 5px; font-size: 8pt; background: #FDFCF5; }
  .lt-words-label { color: #666; font-style: italic; font-size: 7pt; }
  .lt-words-value { color: #0F4C81; font-weight: bold; font-size: 9pt; }

  .lt-pay-outer { border: 1px solid #ddd; border-top: none; page-break-inside: avoid; margin-top: 0; } /* Marge supérieure supprimée */
  .lt-pay-outer td { vertical-align: top; padding: 5px 6px; font-size: 7pt; line-height: 1.5; }
  .lt-pay-left { width: 50%; border-right: 1px solid #eee; }
  .lt-pay-right { width: 50%; }
  .lt-pay-title { font-size: 7pt; font-weight: bold; color: #0F4C81; text-transform: uppercase; margin-bottom: 3px; }
  .lt-pay-box { width: 14px; height: 12px; border: 1px solid #999; text-align: center; font-size: 9pt; display: inline-block; line-height: 10px; }
  .lt-bank-line { font-size: 7pt; margin-bottom: 1px; }
  .lt-bank-line strong { color: #0F4C81; }

  .lt-sign-outer { border: 1px solid #ddd; border-top: none; page-break-inside: avoid; margin-top: 0; } /* Marge supérieure supprimée */
  .lt-sign-outer td { vertical-align: top; padding: 5px; text-align: center; width: 33.33%; }
  .lt-sign-title { font-size: 7pt; font-weight: bold; color: #0F4C81; text-transform: uppercase; margin-bottom: 20px; }
  .lt-sign-line { border-top: 1px solid #999; margin: 0 10px; }

  .lt-legal { font-size: 6pt; color: #777; text-align: center; border-top: 1px solid #ddd; padding-top: 3px; margin-top: 0; line-height: 1.4; } /* Marge supérieure supprimée */
  .lt-pageno { text-align: center; font-size: 7pt; color: #0F4C81; font-weight: bold; margin-top: 2px; }
  .page-break { page-break-before: always; }
</style>

{%- macro render_header() -%}
  {%- set company = frappe.get_doc("Company", doc.company) -%}
  {%- set company_niu = company.tax_id or "M22000000184337W" -%}
  {%- set company_rccm = company.registration_details or "CG/PNR/2017/B/____" -%}
  {%- set company_phone = company.phone_no or "+242 05 339 89 57" -%}
  {%- set company_email = company.email or "contact@litoko.cg" -%}
  {%- set company_web = company.website or "www.litoko.cg" -%}
  <table class="lt-header">
    <tr>
      <td class="lt-logo-cell"><div class="lt-logo">L</div></td>
      <td class="lt-company-cell">
        <div class="lt-company-name">{{ doc.company|upper }}</div>
        <div class="lt-company-tag">Supermarché · Distribution · Électronique · Électroménager · Informatique</div>
        <div class="lt-company-addr">Grand Marché, Ligne 8 — Pointe-Noire, République du Congo &nbsp;|&nbsp; Tél : {{ company_phone }} &nbsp;|&nbsp; B.P. 603</div>
        <div class="lt-company-ids">NIU : {{ company_niu }} &nbsp;|&nbsp; RCCM : {{ company_rccm }} &nbsp;|&nbsp; Régime : Réel &nbsp;|&nbsp; {{ company_email }} &nbsp;|&nbsp; {{ company_web }}</div>
      </td>
      <td class="lt-qr-cell">
        <div class="lt-qr-box">QR</div>
        <div class="lt-bc-text">{{ doc.name[-10:] }}</div>
      </td>
    </tr>
  </table>
  <div class="lt-title-band">
    {% if doc.is_return %}FACTURE D'AVOIR{% else %}FACTURE{% endif %}
    <span class="lt-title-docno">N° {{ doc.name }} &nbsp;—&nbsp; {{ frappe.utils.format_date(doc.posting_date, "dd/MM/yyyy") }}</span>
  </div>
{%- endmacro -%}

{%- macro render_meta() -%}
  {%- set addr = None -%}
  {%- if doc.customer_address -%}
    {%- set addr = frappe.db.get_value("Address", doc.customer_address, ["address_line1","address_line2","city","phone","email_id"], as_dict=True) -%}
  {%- endif -%}

  <table class="lt-meta">
    <tr>
      <td class="lt-meta-left">
        <div class="lt-meta-line"><span class="lbl">BL :</span> {{ doc.delivery_note or "—" }} &nbsp;|&nbsp; <span class="lbl">Échéance :</span> {{ frappe.utils.format_date(doc.due_date, "dd/MM/yyyy") if doc.due_date else "—" }} &nbsp;|&nbsp; <span class="lbl">Devise :</span> {{ doc.currency or "XAF" }} &nbsp;|&nbsp; <span class="lbl">Type :</span> {% if doc.is_pos %}Comptant (POS){% else %}Crédit{% endif %} &nbsp;|&nbsp; <span class="lbl">Code client :</span> {{ doc.customer or "—" }}</div>
        <div class="lt-meta-line"><span class="lbl">Commercial :</span> {{ sales_person or frappe.db.get_value("User", doc.owner, "full_name") or doc.owner }} &nbsp;|&nbsp; <span class="lbl">V/Réf. :</span> {{ doc.po_no or "—" }} &nbsp;|&nbsp; <span class="lbl">TVA client :</span> {{ frappe.db.get_value("Customer", doc.customer, "tax_id") or "—" }}</div>
      </td>
      <td class="lt-meta-right">
        <div class="lt-client-line"><span class="lt-client-name">{{ doc.customer_name or doc.customer or "—" }}</span> &nbsp;—&nbsp; <span class="lt-client-addr">{{ addr.address_line1 or "" }}{% if addr.address_line2 %}, {{ addr.address_line2 }}{% endif %}{% if addr.city %}, {{ addr.city }}{% endif %}{% if addr.phone %} ({{ addr.phone }}){% endif %}</span></div>
      </td>
    </tr>
  </table>
{%- endmacro -%}

{%- macro render_recap() -%}
  <div class="lt-recap-outer">
    <table style="width:100%; border-collapse:collapse;">
      <tr>
        <td class="lt-recap-left">
          {% if doc.taxes and doc.taxes|length > 0 %}
            <table class="lt-vat">
              <thead><tr><th>Taux</th><th>Base HT</th><th>Montant TVA</th></tr></thead>
              <tbody>
                {% for tax in doc.taxes %}
                  {% if tax.tax_amount %}
                  <tr>
                    <td class="c">{{ "%g"|format(tax.rate|float) }}%</td>
                    <td class="r">{{ frappe.utils.fmt_money(tax.total, currency="") }}</td>
                    <td class="r">{{ frappe.utils.fmt_money(tax.tax_amount, currency="") }}</td>
                  </tr>
                  {% endif %}
                {% endfor %}
              </tbody>
            </table>
          {% else %}
            <div style="color:#7a8290; font-size:7.6pt; text-align:center; padding:4px;">Aucune taxe applicable</div>
          {% endif %}
        </td>
        <td class="lt-recap-mid">
          <table class="lt-totals">
            <tr><td class="lbl">Total HT brut</td><td class="num">{{ frappe.utils.fmt_money(doc.total, currency="") }}</td></tr>
            {% if doc.discount_amount %}
            <tr><td class="lbl">Remise HT</td><td class="num">-{{ frappe.utils.fmt_money(doc.discount_amount, currency="") }}</td></tr>
            {% endif %}
            <tr class="net-row"><td class="lbl">Total Net HT</td><td class="num">{{ frappe.utils.fmt_money(doc.net_total, currency="") }}</td></tr>
            {% for tax in doc.taxes %}
              {% if tax.tax_amount %}
              <tr><td class="lbl">{{ tax.description or "TVA" }} ({{ "%g"|format(tax.rate|float) }}%)</td><td class="num">{{ frappe.utils.fmt_money(tax.tax_amount, currency="") }}</td></tr>
              {% endif %}
            {% endfor %}
            {% if doc.rounded_total and doc.rounded_total != doc.grand_total %}
            <tr><td class="lbl">Arrondi</td><td class="num">{{ frappe.utils.fmt_money(doc.rounded_total, currency="") }}</td></tr>
            {% endif %}
          </table>
        </td>
        <td class="lt-recap-right">
          <div class="lt-net-box">
            <div class="lt-net-label">NET À PAYER</div>
            <div class="lt-net-amount">{{ frappe.utils.fmt_money(doc.grand_total, currency="") }}</div>
            <div class="lt-net-cur">{{ doc.currency or "XAF" }}</div>
          </div>
        </td>
      </tr>
    </table>
  </div>
  <div class="lt-words">
    <span class="lt-words-label">Arrêté la présente facture à la somme de :</span><br>
    <strong class="lt-words-value">( {{ (doc.in_words or "")|upper }} )</strong>
  </div>
{%- endmacro -%}

{%- macro render_payment() -%}
  <table class="lt-pay-outer">
    <tr>
      <td class="lt-pay-left">
        <div class="lt-pay-title">Mode de Paiement</div>
        <table style="width:100%;"><tr>
          <td>Espèces <span class="lt-pay-box">{% if doc.is_pos %}✓{% endif %}</span></td>
          <td>Carte bancaire <span class="lt-pay-box"></span></td>
        </tr><tr>
          <td>Mobile Money <span class="lt-pay-box"></span></td>
          <td>Virement <span class="lt-pay-box">{% if not doc.is_pos %}✓{% endif %}</span></td>
        </tr></table>
        {% if doc.paid_amount and doc.paid_amount > 0 %}
        <div style="margin-top:4px; font-size:7.5pt;">
          <strong>Montant payé :</strong> {{ frappe.utils.fmt_money(doc.paid_amount, currency="") }} &nbsp;|&nbsp;
          <strong>Reste :</strong> {{ frappe.utils.fmt_money(doc.outstanding_amount, currency="") }}
        </div>
        {% endif %}
        <div class="lt-pay-title" style="margin-top:4px;">Coordonnées Bancaires</div>
        <div class="lt-bank-line"><strong>CDCO</strong> &nbsp;RIB : 30011-00010-10132663000-67</div>
        <div class="lt-bank-line"><strong>BGFI</strong> &nbsp;RIB : 30008-03200-42008098013-84</div>
        <div class="lt-bank-line"><strong>ECOBANK</strong> &nbsp;RIB : 30014-00002-37220025342-66</div>
        <div class="lt-bank-line"><strong>BCI</strong> &nbsp;RIB : 30013-02000-03001245590-45</div>
      </td>
      <td class="lt-pay-right">
        <div class="lt-pay-title">Signatures</div>
        <table style="width:100%;"><tr>
          <td style="text-align:center; width:33%;"><div style="font-size:7pt; color:#666; margin-bottom:15px;">Client</div><div style="border-top:1px solid #999; margin:0 5px;"></div></td>
          <td style="text-align:center; width:33%;"><div style="font-size:7pt; color:#666; margin-bottom:15px;">Caissier</div><div style="border-top:1px solid #999; margin:0 5px;"></div></td>
          <td style="text-align:center; width:33%;"><div style="font-size:7pt; color:#666; margin-bottom:15px;">Cachet</div><div style="border-top:1px solid #999; margin:0 5px;"></div></td>
        </tr></table>
        <div style="margin-top:5px; font-size:6.5pt; color:#777; text-align:center;">
          Édité par <strong style="color:#0F4C81;">{{ frappe.db.get_value("User", doc.owner, "full_name") or doc.owner }}</strong>
          &nbsp;le&nbsp; <strong style="color:#0F4C81;">{{ frappe.utils.format_date(frappe.utils.nowdate(), "dd/MM/yyyy") }}</strong>
          &nbsp;à&nbsp; <strong style="color:#0F4C81;">{{ frappe.utils.nowtime()[:5] }}</strong>
        </div>
      </td>
    </tr>
  </table>
{%- endmacro -%}

<div id="header-html" class="visible-pdf lt-doc">
  {%- if doc.meta.is_submittable and doc.docstatus == 2 -%}<div class="lt-wm-cancel">*** FACTURE ANNULÉE ***</div>
  {%- elif doc.meta.is_submittable and doc.docstatus == 0 and (print_settings == None or print_settings.add_draft_heading) -%}<div class="lt-wm-draft">*** BROUILLON ***</div>{%- endif -%}
  {{ render_header() }}
  {{ render_meta() }}
</div>

<div class="lt-doc">
  <div style="text-align:right; font-size:6.5pt; margin-bottom:2px; color:#666;">Montants exprimés en {{ doc.currency or "XAF" }}</div>
  {% set items_per_page = 12 %}
  {% set all_items = doc.items or [] %}
  {% set item_pages = all_items|batch(items_per_page)|list %}
  {% if item_pages|length == 0 %}{% set item_pages = [[]] %}{% endif %}
  {% for item_page in item_pages %}
    {% set page_offset = loop.index0 * items_per_page %}
    <div{% if not loop.first %} class="page-break"{% endif %}>
      <table class="lt-items">
        <colgroup>
          <col style="width:4%;">
          <col style="width:38%;">
          <col style="width:8%;">
          <col style="width:6%;">
          <col style="width:10%;">
          <col style="width:6%;">
          <col style="width:7%;">
          <col style="width:7%;">
          <col style="width:12%;">
        </colgroup>
        <thead>
          <tr>
            <th>N°</th>
            <th style="text-align:left;">Désignation</th>
            <th>Qté</th>
            <th>Unité</th>
            <th>Prix HT</th>
            <th>Rem.</th>
            <th>TVA</th>
            <th>Packg</th>
            <th>Montant</th>
          </tr>
        </thead>
        <tbody>
          {% if item_page|length > 0 %}
            {% for item in item_page %}
              {% set barcode = frappe.db.get_value("Item Barcode", {"parent": item.item_code}, "barcode") %}
              {% set tax_rates = frappe.utils.parse_json(item.item_tax_rate) if item.item_tax_rate else {} %}
              <tr>
                <td class="c">{{ page_offset + loop.index }}</td>
                <td class="desig">
                  <strong>{{ item.item_name or item.item_code or "—" }}</strong>
                  {% if item.description and item.description != item.item_name %}
                    <br><span class="desc">{{ item.description }}</span>
                  {% endif %}
                  {% if barcode %}
                    <br><span class="bc">{{ barcode }}</span>
                  {% endif %}
                </td>
                <td class="r">{{ "%g"|format(item.qty|float) }}</td>
                <td class="c">{{ item.uom or "PCS" }}</td>
                <td class="r">{{ frappe.utils.fmt_money(item.net_rate, currency="") }}</td>
                <td class="c">{{ "%g"|format(item.discount_percentage|float) if item.discount_percentage else "0" }}</td>
                <td class="c">
                  {%- for k, v in tax_rates.items() -%}
                    {{ "%g"|format(v|float) }}%{% if not loop.last %}/{% endif %}
                  {%- endfor -%}
                </td>
                <td class="c">{{ item.stock_uom or "—" }}</td>
                <td class="r">{{ frappe.utils.fmt_money(item.net_amount, currency="") }}</td>
              </tr>
            {% endfor %}
          {% else %}
            <tr>
              <td class="c">—</td>
              <td class="desig" style="text-align:center; font-style:italic; padding:10px;" colspan="8">Aucun article</td>
            </tr>
          {% endif %}

          <!-- Lignes vides pour remplir l'espace -->
          {% set remaining_lines = items_per_page - item_page|length %}
          {% for i in range(remaining_lines) %}
            <tr class="lt-empty-row">
              <td>&nbsp;</td>
              <td>&nbsp;</td>
              <td>&nbsp;</td>
              <td>&nbsp;</td>
              <td>&nbsp;</td>
              <td>&nbsp;</td>
              <td>&nbsp;</td>
              <td>&nbsp;</td>
              <td>&nbsp;</td>
            </tr>
          {% endfor %}

        </tbody>
      </table>
      {% if loop.last %}
        {{ render_recap() }}
        {{ render_payment() }}
        <div class="lt-legal">Facture établie conformément au <strong>SYSCOHADA révisé</strong> et au <strong>Code Général des Impôts de la République du Congo</strong>.<br>« Document informatisé — valeur légale équivalente au document manuscrit ». Merci pour votre confiance.</div>
      {% endif %}
    </div>
  {% endfor %}
</div>

<div id="footer-html" class="visible-pdf lt-doc">
  <div class="lt-pageno">Page <span class="page"></span> / <span class="topage"></span></div>
</div>
