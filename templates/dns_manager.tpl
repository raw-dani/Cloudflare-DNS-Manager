{*
 * Cloudflare DNS Manager Template - Clean Modern Design v2
 *
 * Semua fungsi utama dipertahankan:
 *  - Alert sukses/galat ($success/$error/$verifyStatus/$verifyMessage)
 *  - Kartu nameserver Cloudflare + langkah update + tombol Verify Nameservers (POST verifyNameservers)
 *  - Banner scan & import (POST scanDnsRecords)
 *  - Form tambah record (POST addRecord) dengan field dinamis per tipe
 *  - Tabel records dari $mergedRecords dengan pencarian & filter tipe (client-side)
 *  - Aksi baris: Edit/Delete (cloudflare), Retry Sync/Delete Local (lokal)
 *  - Bulk delete: seleksi multi record via checkbox (POST bulkDelete)
 *  - Modal detail konten & modal edit record (POST editRecord)
 *}
<style>
/* ===== DESIGN TOKENS ===== */
:root {
  --dns-primary: #2563eb;
  --dns-primary-soft: #eff6ff;
  --dns-primary-dark: #1e40af;
  --dns-success: #16a34a;
  --dns-success-soft: #f0fdf4;
  --dns-warning: #d97706;
  --dns-warning-soft: #fffbeb;
  --dns-danger: #dc2626;
  --dns-danger-soft: #fef2f2;
  --dns-info: #0891b2;
  --dns-info-soft: #ecfeff;
  --dns-gray-25: #fafafa;
  --dns-gray-50: #f8fafc;
  --dns-gray-100: #f1f5f9;
  --dns-gray-200: #e2e8f0;
  --dns-gray-300: #cbd5e1;
  --dns-gray-400: #94a3b8;
  --dns-gray-500: #64748b;
  --dns-gray-600: #475569;
  --dns-gray-700: #334155;
  --dns-gray-800: #1e293b;
  --dns-white: #ffffff;
  --dns-radius: 10px;
  --dns-radius-lg: 14px;
  --dns-shadow-sm: 0 1px 2px rgba(15,23,42,.06);
  --dns-shadow: 0 1px 3px rgba(15,23,42,.08), 0 1px 2px rgba(15,23,42,.04);
  --dns-shadow-md: 0 10px 24px -6px rgba(15,23,42,.14);
  --dns-mono: ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, monospace;
}

/* ===== BASE ===== */
.dns-manager-container {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
  color: var(--dns-gray-600);
  font-size: 14.5px;
  line-height: 1.6;
}

.dns-manager-container *,
.dns-manager-container *::before,
.dns-manager-container *::after {
  box-sizing: border-box;
}

.dns-manager-container h1,
.dns-manager-container h2,
.dns-manager-container h3,
.dns-manager-container h4,
.dns-manager-container h5 {
  color: var(--dns-gray-800);
  font-weight: 650;
  margin: 0;
  letter-spacing: -.01em;
}

.dns-manager-container p {
  margin: 0;
}

.dns-manager-container small {
  color: var(--dns-gray-400);
}

.dns-mono {
  font-family: var(--dns-mono);
  font-size: .92em;
}

/* ===== LAYOUT ===== */
.dns-page {
  max-width: 1080px;
  margin: 0 auto;
  padding: 28px 16px 48px;
}

.dns-page-header {
  display: flex;
  align-items: center;
  gap: 14px;
  flex-wrap: wrap;
  padding: 22px 26px;
  background: linear-gradient(135deg, var(--dns-primary-dark) 0%, var(--dns-primary) 60%, #3b82f6 100%);
  border-radius: var(--dns-radius-lg);
  color: var(--dns-white);
  box-shadow: var(--dns-shadow-md);
  margin-bottom: 20px;
}

.dns-page-header .dns-logo {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  background: rgba(255,255,255,.16);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.dns-page-header svg {
  width: 26px;
  height: 26px;
}

.dns-page-title {
  flex: 1;
  min-width: 220px;
  color: var(--dns-white);
}

.dns-page-title h2 {
  color: var(--dns-white);
  font-size: 19px;
}

.dns-page-title p {
  opacity: .82;
  font-size: 13px;
}

.dns-zone-chip {
  background: rgba(255,255,255,.14);
  border: 1px solid rgba(255,255,255,.22);
  border-radius: 999px;
  padding: 6px 14px;
  font-family: var(--dns-mono);
  font-size: 12px;
  white-space: nowrap;
  max-width: 260px;
  overflow: hidden;
  text-overflow: ellipsis;
}

/* ===== MAIN TABS ===== */
.dns-main-nav {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 14px;
  margin-bottom: 24px;
}

@media (max-width: 640px) {
  .dns-main-nav {
    grid-template-columns: 1fr;
  }
}

.dns-main-tab {
  display: flex;
  align-items: flex-start;
  gap: 14px;
  padding: 16px 18px;
  background: var(--dns-white);
  border: 1.5px solid var(--dns-gray-200);
  border-radius: var(--dns-radius-lg);
  cursor: pointer;
  transition: all .2s ease;
  user-select: none;
  text-align: left;
  box-shadow: var(--dns-shadow-sm);
  position: relative;
}

.dns-main-tab:hover {
  border-color: var(--dns-gray-300);
  background: var(--dns-gray-50);
  transform: translateY(-1px);
}

.dns-main-tab.active {
  background: #f8fafc;
  border-color: var(--dns-primary);
  box-shadow: 0 0 0 2px rgba(37,99,235,.15), var(--dns-shadow-sm);
}

.dns-tab-icon {
  width: 40px;
  height: 40px;
  border-radius: 10px;
  background: var(--dns-gray-100);
  color: var(--dns-gray-600);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  transition: all .2s;
}

.dns-main-tab.active .dns-tab-icon {
  background: var(--dns-primary);
  color: var(--dns-white);
}

.dns-tab-icon svg {
  width: 20px;
  height: 20px;
}

.dns-tab-info {
  flex: 1;
}

.dns-tab-title {
  display: block;
  font-size: 14.5px;
  font-weight: 700;
  color: var(--dns-gray-800);
  margin-bottom: 3px;
}

.dns-main-tab.active .dns-tab-title {
  color: var(--dns-primary-dark);
}

.dns-tab-desc {
  display: block;
  font-size: 12.5px;
  color: var(--dns-gray-500);
  line-height: 1.4;
  font-weight: normal;
}

.dns-tab-pane {
  display: block;
}

.dns-tab-pane.dns-hidden-tab {
  display: none !important;
}

/* ===== ANALYTICS STYLES ===== */
.dns-analytics-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 16px;
  padding: 16px 20px;
  background: var(--dns-white);
  border: 1px solid var(--dns-gray-200);
  border-radius: var(--dns-radius-lg);
  box-shadow: var(--dns-shadow-sm);
  margin-bottom: 20px;
}

.dns-analytics-bar-header h4 {
  font-size: 15px;
  font-weight: 700;
  color: var(--dns-gray-800);
  margin: 0 0 4px 0;
  display: flex;
  align-items: center;
  gap: 8px;
}

.dns-analytics-bar-header p {
  font-size: 12.5px;
  color: var(--dns-gray-500);
  margin: 0;
}

.dns-stat-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(210px, 1fr));
  gap: 14px;
  margin-bottom: 20px;
}

.dns-stat-card {
  background: var(--dns-white);
  border: 1px solid var(--dns-gray-200);
  border-radius: var(--dns-radius-lg);
  padding: 18px 20px;
  box-shadow: var(--dns-shadow-sm);
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.dns-stat-label {
  font-size: 12px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: .05em;
  color: var(--dns-gray-500);
  display: flex;
  align-items: center;
  gap: 6px;
}

.dns-stat-value {
  font-size: 26px;
  font-weight: 700;
  color: var(--dns-gray-800);
  line-height: 1.2;
}

.dns-stat-sub {
  font-size: 12px;
  color: var(--dns-gray-400);
}

.dns-chart-container {
  min-height: 280px;
  position: relative;
  width: 100%;
}

.dns-chart-card-desc {
  font-size: 13px;
  color: var(--dns-gray-500);
  line-height: 1.45;
  margin-bottom: 16px;
  padding-bottom: 12px;
  border-bottom: 1px dashed var(--dns-gray-200);
}

.dns-chart-summary-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: var(--dns-gray-50);
  border: 1px solid var(--dns-gray-200);
  border-radius: var(--dns-radius);
  padding: 10px 14px;
  margin-top: 14px;
  font-size: 13px;
  color: var(--dns-gray-700);
}

.dns-type-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-top: 14px;
}

.dns-type-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px 12px;
  background: var(--dns-gray-50);
  border: 1px solid var(--dns-gray-200);
  border-radius: 8px;
  font-size: 13px;
}

.dns-type-item-name {
  display: flex;
  align-items: center;
  gap: 8px;
  font-weight: 600;
  color: var(--dns-gray-800);
}

.dns-type-item-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  flex-shrink: 0;
}

.dns-type-item-stats {
  display: flex;
  align-items: center;
  gap: 12px;
  color: var(--dns-gray-600);
}

.dns-analytics-table-wrap {
  overflow-x: auto;
}

.dns-analytics-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13.5px;
}

.dns-analytics-table th,
.dns-analytics-table td {
  padding: 10px 14px;
  border-bottom: 1px solid var(--dns-gray-100);
}

.dns-analytics-table th {
  background: var(--dns-gray-50);
  color: var(--dns-gray-500);
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: .04em;
  font-weight: 600;
  text-align: left;
}

.dns-analytics-table tr:hover td {
  background: var(--dns-gray-50);
}

.dns-analytics-progress-bg {
  width: 100%;
  max-width: 160px;
  height: 8px;
  background: var(--dns-gray-200);
  border-radius: 999px;
  overflow: hidden;
  display: inline-block;
  vertical-align: middle;
  margin-right: 8px;
}

.dns-analytics-progress-bar {
  height: 100%;
  background: var(--dns-primary);
  border-radius: 999px;
}

/* ===== CARDS ===== */
.dns-card {
  background: var(--dns-white);
  border: 1px solid var(--dns-gray-200);
  border-radius: var(--dns-radius-lg);
  box-shadow: var(--dns-shadow-sm);
  margin-bottom: 18px;
  overflow: hidden;
}

.dns-card-header {
  padding: 15px 22px;
  border-bottom: 1px solid var(--dns-gray-100);
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
}

.dns-card-header .dns-card-title {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 15px;
  font-weight: 650;
  color: var(--dns-gray-800);
}

.dns-card-header .dns-card-title svg {
  width: 17px;
  height: 17px;
  color: var(--dns-primary);
  flex-shrink: 0;
}

.dns-card-body {
  padding: 22px;
}

.dns-card-body > :last-child {
  margin-bottom: 0;
}

@media (min-width: 861px) {
  .dns-grid-2 {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 18px;
    align-items: start;
  }
  .dns-grid-2 > .dns-card {
    margin-bottom: 18px;
  }
}

/* ===== ALERTS ===== */
.dns-alert {
  padding: 13px 16px;
  border-radius: var(--dns-radius);
  margin-bottom: 14px;
  display: flex;
  align-items: flex-start;
  gap: 11px;
  font-size: 13.5px;
  border: 1px solid transparent;
}

.dns-alert:last-child {
  margin-bottom: 0;
}

.dns-alert svg {
  width: 17px;
  height: 17px;
  flex-shrink: 0;
  margin-top: 2px;
}

.dns-alert-success {
  background: var(--dns-success-soft);
  border-color: #bbf7d0;
  color: #166534;
}
.dns-alert-error {
  background: var(--dns-danger-soft);
  border-color: #fecaca;
  color: #991b1b;
}
.dns-alert-warning {
  background: var(--dns-warning-soft);
  border-color: #fde68a;
  color: #92400e;
}
.dns-alert-info {
  background: var(--dns-info-soft);
  border-color: #a5f3fc;
  color: #155e75;
}

.dns-alert-actions {
  margin-left: auto;
  flex-shrink: 0;
}

/* ===== NAMESERVERS ===== */
.dns-ns-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

@media (max-width: 520px) {
  .dns-ns-grid {
    grid-template-columns: 1fr;
  }
}

.dns-ns-box {
  border: 1px solid var(--dns-gray-200);
  border-radius: var(--dns-radius);
  padding: 12px 14px;
  background: var(--dns-gray-50);
}

.dns-ns-label {
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .06em;
  color: var(--dns-gray-400);
  margin-bottom: 4px;
}

.dns-ns-value {
  font-family: var(--dns-mono);
  font-size: 13px;
  color: var(--dns-gray-800);
  word-break: break-all;
}

.dns-collapsible summary {
  cursor: pointer;
  list-style: none;
  padding: 10px 14px;
  margin: 14px -14px -12px;
  border-top: 1px dashed var(--dns-gray-200);
  font-size: 13px;
  font-weight: 600;
  color: var(--dns-primary);
  user-select: none;
}

.dns-collapsible summary::-webkit-details-marker {
  display: none;
}

.dns-collapsible ol {
  margin: 0;
  padding: 12px 14px 4px 32px;
  font-size: 13px;
  color: var(--dns-gray-500);
}

.dns-collapsible li {
  margin-bottom: 6px;
}

/* ===== FORMS ===== */
.dns-form-row {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(190px, 1fr));
  gap: 14px;
}

.dns-form-group {
  margin-bottom: 14px;
}

.dns-label {
  display: block;
  font-size: 12.5px;
  font-weight: 600;
  color: var(--dns-gray-700);
  margin-bottom: 6px;
}

.dns-input,
.dns-select,
.dns-textarea {
  width: 100%;
  padding: 9px 12px;
  border: 1px solid var(--dns-gray-300);
  border-radius: 8px;
  font-size: 13.5px;
  font-family: inherit;
  color: var(--dns-gray-800);
  background: var(--dns-white);
  transition: border-color .15s, box-shadow .15s;
}

.dns-input:focus,
.dns-select:focus,
.dns-textarea:focus {
  outline: none;
  border-color: var(--dns-primary);
  box-shadow: 0 0 0 3px rgba(37,99,235,.12);
}

.dns-input.mono,
.dns-textarea.mono {
  font-family: var(--dns-mono);
  font-size: 12.5px;
}

.dns-help-text {
  display: block;
  font-size: 11.5px;
  color: var(--dns-gray-400);
  margin-top: 5px;
}

.dns-checkbox-card {
  display: flex;
  align-items: center;
  gap: 11px;
  border: 1px solid var(--dns-gray-300);
  border-radius: 8px;
  padding: 11px 14px;
  background: var(--dns-gray-50);
  cursor: pointer;
  user-select: none;
}

.dns-checkbox-card input[type='checkbox'] {
  width: 16px;
  height: 16px;
  accent-color: var(--dns-primary);
  margin: 0;
  flex-shrink: 0;
}

.dns-checkbox-card strong {
  display: block;
  font-size: 13px;
  color: var(--dns-gray-800);
}

.dns-checkbox-card small {
  font-size: 11.5px;
}

.dns-hidden-field {
  display: none !important;
}

/* ===== BUTTONS ===== */
.dns-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 7px;
  padding: 9px 18px;
  border-radius: 8px;
  border: 1px solid transparent;
  font-size: 13.5px;
  font-weight: 600;
  font-family: inherit;
  cursor: pointer;
  text-decoration: none;
  line-height: 1.35;
  transition: background-color .15s, border-color .15s, color .15s;
}

.dns-btn svg {
  width: 15px;
  height: 15px;
  flex-shrink: 0;
}

.dns-btn:focus-visible {
  outline: 2px solid var(--dns-primary);
  outline-offset: 2px;
}

.dns-btn-primary {
  background: var(--dns-primary);
  color: var(--dns-white);
}
.dns-btn-primary:hover {
  background: var(--dns-primary-dark);
}

.dns-btn-secondary {
  background: var(--dns-white);
  color: var(--dns-gray-700);
  border-color: var(--dns-gray-300);
}
.dns-btn-secondary:hover {
  background: var(--dns-gray-50);
  border-color: var(--dns-gray-400);
}

.dns-btn-warning {
  background: var(--dns-warning-soft);
  color: #92400e;
  border-color: #fde68a;
}
.dns-btn-warning:hover {
  background: #fef3c7;
}

.dns-btn-sm {
  padding: 6px 12px;
  font-size: 12.5px;
}

.dns-icon-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  height: 26px;
  padding: 0 11px;
  border-radius: 7px;
  border: 1px solid var(--dns-gray-200);
  background: var(--dns-white);
  color: var(--dns-gray-500);
  font-size: 11.5px;
  font-weight: 700;
  font-family: inherit;
  letter-spacing: .03em;
  text-transform: uppercase;
  cursor: pointer;
  transition: all .15s;
}

.dns-icon-btn:hover {
  border-color: var(--dns-gray-300);
  background: var(--dns-gray-50);
}

.dns-icon-btn.edit:hover {
  color: var(--dns-primary);
  background: var(--dns-primary-soft);
  border-color: #bfdbfe;
}

.dns-icon-btn.delete:hover {
  color: var(--dns-danger);
  background: var(--dns-danger-soft);
  border-color: #fecaca;
}

.dns-icon-btn.sync:hover {
  color: var(--dns-warning);
  background: var(--dns-warning-soft);
  border-color: #fde68a;
}

.dns-row-actions {
  display: inline-flex;
  gap: 5px;
}

.dns-row-action-form {
  display: inline;
}

/* ===== TOOLBAR (search + filter) ===== */
.dns-toolbar {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
  align-items: center;
  margin-bottom: 14px;
}

.dns-search-wrap {
  position: relative;
  flex: 1;
  min-width: 210px;
}

.dns-search-wrap svg {
  position: absolute;
  left: 12px;
  top: 50%;
  transform: translateY(-50%);
  width: 15px;
  height: 15px;
  color: var(--dns-gray-400);
  pointer-events: none;
}

.dns-search-wrap .dns-input {
  padding-left: 36px;
}

.dns-chips {
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
  margin-bottom: 14px;
}

.dns-chip {
  padding: 5px 13px;
  border-radius: 999px;
  border: 1px solid var(--dns-gray-200);
  background: var(--dns-white);
  color: var(--dns-gray-500);
  font-size: 12.5px;
  font-weight: 600;
  font-family: inherit;
  cursor: pointer;
  transition: all .15s;
}

.dns-chip:hover {
  border-color: var(--dns-gray-300);
  color: var(--dns-gray-700);
}

.dns-chip.active {
  background: var(--dns-primary-soft);
  border-color: var(--dns-primary);
  color: var(--dns-primary-dark);
}

.dns-result-meta {
  font-size: 12.5px;
  color: var(--dns-gray-400);
}

/* ===== TABLE ===== */
.dns-table-wrap {
  overflow-x: auto;
  border: 1px solid var(--dns-gray-200);
  border-radius: var(--dns-radius);
}

.dns-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13.5px;
  min-width: 900px;
}

.dns-table thead th {
  background: var(--dns-gray-50);
  color: var(--dns-gray-500);
  font-size: 11.5px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .05em;
  text-align: left;
  padding: 11px 14px;
  border-bottom: 1px solid var(--dns-gray-200);
  white-space: nowrap;
}

.dns-table tbody td {
  padding: 11px 14px;
  border-bottom: 1px solid var(--dns-gray-100);
  vertical-align: middle;
  color: var(--dns-gray-700);
}

.dns-table tbody tr:last-child td {
  border-bottom: none;
}

.dns-table tbody tr {
  transition: background-color .12s;
}

.dns-table tbody tr:hover {
  background: var(--dns-gray-50);
}

.dns-record-name {
  font-family: var(--dns-mono);
  font-size: 12.5px;
  word-break: break-all;
}

.dns-content-cell {
  max-width: 260px;
}

.dns-content-preview {
  font-family: var(--dns-mono);
  font-size: 12px;
  color: var(--dns-gray-500);
  word-break: break-all;
  display: -webkit-box;
  -webkit-line-clamp: 1;
  -webkit-box-orient: vertical;
  overflow: hidden;
  cursor: pointer;
}

.dns-content-preview:hover {
  color: var(--dns-primary);
}

.dns-center {
  text-align: center;
}

.dns-text-center {
  text-align: center;
}

.full-content {
  display: none !important;
}

/* ===== BULK SELECTION ===== */
.dns-bulk-bar {
  display: none;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
  padding: 10px 14px;
  margin-bottom: 14px;
  background: var(--dns-primary-soft);
  border: 1px solid #bfdbfe;
  border-radius: var(--dns-radius);
  font-size: 13px;
  color: var(--dns-primary-dark);
}

.dns-bulk-bar.active {
  display: flex;
}

.dns-bulk-bar strong {
  font-weight: 700;
}

.dns-bulk-bar .dns-bulk-hint {
  color: #64748b;
  font-size: 12px;
}

.dns-bulk-bar .dns-bulk-actions {
  margin-left: auto;
  display: flex;
  gap: 8px;
}

.dns-table input[type="checkbox"] {
  width: 15px;
  height: 15px;
  accent-color: var(--dns-primary);
  cursor: pointer;
  margin: 0;
  vertical-align: middle;
}

.dns-table tr.row-selected {
  background: var(--dns-primary-soft);
}

.dns-btn-danger {
  background: var(--dns-danger);
  color: var(--dns-white);
}
.dns-btn-danger:hover {
  background: #b91c1c;
}

.dns-btn-success {
  background: var(--dns-success);
  color: var(--dns-white);
}
.dns-btn-success:hover {
  background: #15803d;
}

/* ===== BADGES ===== */
.dns-badge {
  display: inline-block;
  padding: 3px 9px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: .02em;
  border: 1px solid transparent;
  white-space: nowrap;
}

.dns-badge-type {
  background: var(--dns-gray-100);
  border-color: var(--dns-gray-200);
  color: var(--dns-gray-600);
  font-family: var(--dns-mono);
  letter-spacing: .04em;
}

.dns-badge-blue {
  background: var(--dns-primary-soft);
  border-color: #bfdbfe;
  color: var(--dns-primary-dark);
}

.dns-badge-green {
  background: var(--dns-success-soft);
  border-color: #bbf7d0;
  color: #166534;
}

.dns-badge-amber {
  background: var(--dns-warning-soft);
  border-color: #fde68a;
  color: #92400e;
}

.dns-badge-red {
  background: var(--dns-danger-soft);
  border-color: #fecaca;
  color: #991b1b;
}

.dns-badge-teal {
  background: var(--dns-info-soft);
  border-color: #a5f3fc;
  color: #155e75;
}

.dns-badge-muted {
  background: var(--dns-gray-100);
  border-color: var(--dns-gray-200);
  color: var(--dns-gray-400);
}

/* ===== MODALS ===== */
.dns-modal-overlay {
  display: none;
  position: fixed;
  inset: 0;
  background: rgba(15,23,42,.55);
  z-index: 99999;
  align-items: center;
  justify-content: center;
  padding: 16px;
}

.dns-modal-overlay.open {
  display: flex;
}

.dns-modal {
  background: var(--dns-white);
  border-radius: var(--dns-radius-lg);
  box-shadow: var(--dns-shadow-md);
  width: 100%;
  max-width: 520px;
  max-height: calc(100vh - 40px);
  overflow-y: auto;
}

.dns-modal-header {
  padding: 16px 22px;
  border-bottom: 1px solid var(--dns-gray-100);
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.dns-modal-header h3 {
  font-size: 15.5px;
}

.dns-modal-close {
  width: 30px;
  height: 30px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border: none;
  background: var(--dns-gray-100);
  border-radius: 8px;
  color: var(--dns-gray-500);
  font-size: 16px;
  line-height: 1;
  cursor: pointer;
}

.dns-modal-close:hover {
  background: var(--dns-gray-200);
  color: var(--dns-gray-700);
}

.dns-modal-body {
  padding: 22px;
}

.dns-modal-footer {
  padding: 14px 22px;
  border-top: 1px solid var(--dns-gray-100);
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}

.dns-record-content {
  background: var(--dns-gray-50);
  border: 1px solid var(--dns-gray-200);
  border-radius: var(--dns-radius);
  padding: 14px;
  font-family: var(--dns-mono);
  font-size: 12.5px;
  word-break: break-all;
  white-space: pre-wrap;
  max-height: 280px;
  overflow-y: auto;
  color: var(--dns-gray-700);
}

/* ===== EMPTY STATE ===== */
.dns-empty {
  text-align: center;
  padding: 44px 20px;
  color: var(--dns-gray-400);
}

.dns-empty svg {
  width: 38px;
  height: 38px;
  margin-bottom: 10px;
  opacity: .45;
}

.dns-empty strong {
  display: block;
  font-size: 14px;
  color: var(--dns-gray-600);
  margin-bottom: 3px;
}

.dns-empty p {
  font-size: 13px;
}

/* ===== RESPONSIVE ===== */
@media (max-width: 768px) {
  .dns-card-body {
    padding: 15px;
  }
  .dns-card-header {
    padding: 13px 15px;
  }
  .dns-page {
    padding: 16px 10px 36px;
  }
  .dns-page-header {
    padding: 16px 18px;
  }
  .dns-alert-actions {
    margin-left: 0;
    width: 100%;
  }
  .dns-alert {
    flex-wrap: wrap;
  }
}

/* ===== SCROLLBAR ===== */
.dns-record-content::-webkit-scrollbar,
.dns-modal::-webkit-scrollbar,
.dns-table-wrap::-webkit-scrollbar {
  height: 6px;
  width: 6px;
}

.dns-record-content::-webkit-scrollbar-track,
.dns-modal::-webkit-scrollbar-track,
.dns-table-wrap::-webkit-scrollbar-track {
  background: transparent;
}

.dns-record-content::-webkit-scrollbar-thumb,
.dns-modal::-webkit-scrollbar-thumb,
.dns-table-wrap::-webkit-scrollbar-thumb {
  background: var(--dns-gray-300);
  border-radius: 3px;
}

/* ===== WHMCS INTEGRATION ===== */
#tabDownloads,
#tabAddons,
#tabChangepw {
  display: none !important;
}
</style>

<div class="dns-manager-container">
<div class="dns-page">

  {* ============ PAGE HEADER ============ *}
  <div class="dns-page-header">
    <div class="dns-logo">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z"/></svg>
    </div>
    <div class="dns-page-title">
      <h2>Manage DNS Records</h2>
      <p>{$LANG.cfdnsmanager.manageDnsRecords} <strong>{$domain}</strong></p>
    </div>
    {if $zoneId}
      <div style="display:flex; align-items:center; gap:10px;">
        <div class="dns-zone-chip" title="Cloudflare Zone ID">Zone: {$zoneId}</div>
        <form method="post" action="" style="display:inline;"
              onsubmit="return confirm('Bersihkan SEMUA cache Cloudflare untuk {$domain}? Pengunjung akan mendapat versi file terbaru dari origin, namun load awal akan lebih lambat sesaat.');">
          <input type="hidden" name="cfdnsmanager_action" value="flushCache">
          <button type="submit" class="dns-btn dns-btn-sm" style="background:rgba(255,255,255,.14); border-color:rgba(255,255,255,.3); color:#fff;" title="Purge Everything: hapus semua file cache Cloudflare">
            Flush Cache
          </button>
        </form>
      </div>
    {/if}
  </div>

  {* ============ ALERTS ============ *}
  {if $success}
    <div class="dns-alert dns-alert-success">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21.8 10A10 10 0 1 1 17 3.34"/><path d="m9 11 3 3L22 4"/></svg>
      <span>{$success}</span>
    </div>
  {/if}

  {if $error}
    <div class="dns-alert dns-alert-error">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
      <span>{$error}</span>
    </div>
  {/if}

  {if $verifyMessage}
    <div class="dns-alert dns-alert-{if $verifyStatus eq 'error'}error{elseif $verifyStatus eq 'warning'}warning{elseif $verifyStatus eq 'success'}success{else}info{/if}">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>
      <span>{$verifyMessage}</span>
    </div>
  {/if}

  {if !$zoneId}
    <div class="dns-card">
      <div class="dns-card-body dns-text-center">
        <p style="margin-bottom:14px; color:#334155;"><strong>Zona Cloudflare belum tersedia untuk domain ini.</strong> Tambahkan zona secara manual untuk mulai mengelola DNS.</p>
        <form method="post" action="">
          <input type="hidden" name="cfdnsmanager_action" value="addZoneManually">
          <button type="submit" class="dns-btn dns-btn-primary">Add Zone Manually</button>
        </form>
      </div>
    </div>
  {else}

  {* ============ MAIN NAVIGATION TABS ============ *}
  <div class="dns-main-nav">
    <button type="button" class="dns-main-tab active" data-target="tabRecords">
      <div class="dns-tab-icon">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 6h16M4 12h16M4 18h7"/></svg>
      </div>
      <div class="dns-tab-info">
        <span class="dns-tab-title">{$LANG.cfdnsmanager.tabRecords}</span>
        <span class="dns-tab-desc">{$LANG.cfdnsmanager.tabRecordsDesc}</span>
      </div>
    </button>
    <button type="button" class="dns-main-tab" data-target="tabAnalytics">
      <div class="dns-tab-icon">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/></svg>
      </div>
      <div class="dns-tab-info">
        <span class="dns-tab-title">{$LANG.cfdnsmanager.tabAnalytics}</span>
        <span class="dns-tab-desc">{$LANG.cfdnsmanager.tabAnalyticsDesc}</span>
      </div>
    </button>
  </div>

  {* ============ TAB 1: DNS RECORDS & ROUTING ============ *}
  <div class="dns-tab-pane" id="tabRecords">

  {* ============ NAMESERVERS CARD ============ *}
  <div class="dns-grid-2">
    <div class="dns-card">
      <div class="dns-card-header">
        <span class="dns-card-title">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="2" width="20" height="8" rx="2"/><rect x="2" y="14" width="20" height="8" rx="2"/><line x1="6" y1="6" x2="6.01" y2="6"/><line x1="6" y1="18" x2="6.01" y2="18"/></svg>
          Cloudflare Nameservers
        </span>
        <form method="post" action="" style="display:inline;">
          <input type="hidden" name="cfdnsmanager_action" value="verifyNameservers">
          <button type="submit" class="dns-btn dns-btn-secondary dns-btn-sm">{$LANG.cfdnsmanager.verifyNameservers}</button>
        </form>
      </div>
      <div class="dns-card-body">
        {if $whmcsNameservers.0 && $whmcsNameservers.1}
          <div class="dns-ns-grid">
            <div class="dns-ns-box">
              <div class="dns-ns-label">Nameserver 1</div>
              <div class="dns-ns-value">{$whmcsNameservers.0}</div>
            </div>
            <div class="dns-ns-box">
              <div class="dns-ns-label">Nameserver 2</div>
              <div class="dns-ns-value">{$whmcsNameservers.1}</div>
            </div>
          </div>
          <small style="display:block; margin-top:12px;">{$LANG.cfdnsmanager.propagationNotice}</small>
          <details class="dns-collapsible">
            <summary>{$LANG.cfdnsmanager.howToUpdateNameservers}</summary>
            <ol>
              <li>{$LANG.cfdnsmanager.step1}</li>
              <li>{$LANG.cfdnsmanager.step2}</li>
              <li>{$LANG.cfdnsmanager.step3}</li>
              <li>{$LANG.cfdnsmanager.step4}</li>
            </ol>
          </details>
        {else}
          <div class="dns-alert dns-alert-warning" style="margin-bottom:0;">
            <span>{$LANG.cfdnsmanager.nameserversNotAvailable}</span>
          </div>
        {/if}
      </div>
    </div>

    {* ============ ADD RECORD CARD ============ *}
    <div class="dns-card">
      <div class="dns-card-header">
        <span class="dns-card-title">Add DNS Record</span>
      </div>
      <div class="dns-card-body">
        <form method="post" action="" id="dnsAddForm">
          <input type="hidden" name="cfdnsmanager_action" value="addRecord">
          <input type="hidden" name="zoneId" value="{$zoneId}">

          <div class="dns-form-row" style="margin-bottom:14px;">
            <div>
              <label class="dns-label" for="type">{$LANG.cfdnsmanager.type}</label>
              <select name="type" id="type" class="dns-select">
                <option value="A">A</option>
                <option value="AAAA">AAAA</option>
                <option value="CNAME">CNAME</option>
                <option value="MX">MX</option>
                <option value="TXT">TXT</option>
                <option value="NS">NS</option>
                <option value="CAA">CAA</option>
                <option value="SRV">SRV</option>
              </select>
            </div>
            <div>
              <label class="dns-label" for="ttl">{$LANG.cfdnsmanager.ttl}</label>
              <select name="ttl" id="ttl" class="dns-select">
                <option value="1">Auto</option>
                <option value="60">1 minute</option>
                <option value="300">5 minutes</option>
                <option value="900">15 minutes</option>
                <option value="1800">30 minutes</option>
                <option value="3600">1 hour</option>
                <option value="7200">2 hours</option>
                <option value="18000">5 hours</option>
                <option value="43200">12 hours</option>
                <option value="86400">1 day</option>
              </select>
            </div>
          </div>

          <div class="dns-form-group dns-hidden-field" id="add_srvSummary" style="font-size:13px; color:var(--dns-gray-600); background:var(--dns-gray-50); border:1px solid var(--dns-gray-200); border-radius:8px; padding:10px 12px; margin-bottom:14px;">
            <strong id="add_srvSummary_name" style="color:var(--dns-gray-800);">[name]</strong> points to <strong id="add_srvSummary_target" style="color:var(--dns-gray-800);">[target]</strong> and listens on <strong id="add_srvSummary_port" style="color:var(--dns-gray-800);">[port]</strong>.
          </div>

          <div class="dns-form-group" id="standardNameCol">
            <label class="dns-label" for="name">{$LANG.cfdnsmanager.name}</label>
            <input type="text" name="name" id="name" class="dns-input mono" placeholder="@" required>
            <small class="dns-help-text">Gunakan @ untuk root ({$domain}) atau subdomain seperti www. Nama akan otomatis dilengkapi dengan domain.</small>
          </div>

          {* SRV Name + Priority Row *}
          <div class="dns-form-row dns-hidden-field" id="srvNameRow" style="margin-bottom:14px;">
            <div>
              <label class="dns-label" for="srv_name">Name</label>
              <input type="text" name="srv_name" id="srv_name" class="dns-input mono" placeholder="E.g. _sip._tcp.example.com">
              <small class="dns-help-text">Format: _service._proto (e.g. _sip._tcp)</small>
            </div>
            <div>
              <label class="dns-label" for="srv_priority">Priority</label>
              <input type="number" name="srv_priority" id="srv_priority" class="dns-input" value="10" min="0">
            </div>
          </div>

          {* SRV Weight + Port Row *}
          <div class="dns-form-row dns-hidden-field" id="srvWeightPortRow" style="margin-bottom:14px;">
            <div>
              <label class="dns-label" for="srv_weight">Weight</label>
              <input type="number" name="srv_weight" id="srv_weight" class="dns-input" value="5" min="0">
            </div>
            <div>
              <label class="dns-label" for="srv_port">Port</label>
              <input type="number" name="srv_port" id="srv_port" class="dns-input" placeholder="e.g. 5060" min="1" max="65535">
            </div>
          </div>

          {* SRV Target *}
          <div class="dns-form-group dns-hidden-field" id="srvTargetRow">
            <label class="dns-label" for="srv_target">Target</label>
            <input type="text" name="srv_target" id="srv_target" class="dns-input mono" placeholder="E.g. www.example.com">
          </div>

          <div class="dns-form-group" id="standardContentCol">
            <label class="dns-label" for="content">{$LANG.cfdnsmanager.content}</label>
            <textarea name="content" id="content" class="dns-textarea mono" rows="2" placeholder="192.0.2.1" required></textarea>
            <small class="dns-help-text" id="contentHelp"></small>
          </div>

          <div class="dns-form-group dns-hidden-field" id="priorityCol">
            <label class="dns-label" for="priority">{$LANG.cfdnsmanager.priority}</label>
            <input type="number" name="priority" id="priority" class="dns-input" value="0" min="0">
            <small class="dns-help-text">Angka lebih kecil = prioritas lebih tinggi.</small>
          </div>

          <div class="dns-form-group dns-hidden-field" id="proxyCol">
            <label class="dns-checkbox-card" for="proxied">
              <input type="checkbox" name="proxied" id="proxied" value="1">
              <span>
                <strong>Enable Cloudflare Proxy</strong>
                <small>DDoS protection, SSL, and caching.</small>
              </span>
            </label>
          </div>

          <button type="submit" class="dns-btn dns-btn-primary" style="width:100%;">Add Record</button>
        </form>
      </div>
    </div>
  </div>{* /.dns-grid-2 *}

  {* ============ SCAN & IMPORT BANNER ============ *}
  <div class="dns-alert dns-alert-warning">
    <span style="flex:1; min-width:200px;">
      <strong>Sebelum pindah nameserver:</strong> pindai &amp; impor DNS record yang ada ke Cloudflare agar layanan tidak terputus.
    </span>
    <span class="dns-alert-actions">
      <form method="post" action="" class="dns-row-action-form"
            onsubmit="return confirm('This will scan your current DNS records from the previous nameservers and import them to Cloudflare. Continue?');">
        <input type="hidden" name="cfdnsmanager_action" value="scanDnsRecords">
        <button type="submit" class="dns-btn dns-btn-warning dns-btn-sm">Scan &amp; Import</button>
      </form>
    </span>
  </div>

  {* ============ URL REDIRECTS CARD (Page Rules) ============ *}
  <div class="dns-card">
    <div class="dns-card-header">
      <span class="dns-card-title">URL Redirects</span>
    </div>
    <div class="dns-card-body">

      {* Form tambah redirect *}
      <form method="post" action="" id="dnsRedirectForm">
        <input type="hidden" name="cfdnsmanager_action" value="addRedirect">
        <input type="hidden" name="zoneId" value="{$zoneId}">
        <div class="dns-form-row" style="margin-bottom:12px;">
          <div>
            <label class="dns-label" for="redirectSource">From (URL pattern)</label>
            <input type="text" name="redirectSource" id="redirectSource" class="dns-input mono"
                   placeholder="old.example.com/*" required>
          </div>
          <div>
            <label class="dns-label" for="redirectTarget">To (target URL)</label>
            <input type="text" name="redirectTarget" id="redirectTarget" class="dns-input mono"
                   placeholder="https://new-domain.com/$1" required>
          </div>
          <div style="max-width:150px;">
            <label class="dns-label" for="redirectStatus">Type</label>
            <select name="redirectStatus" id="redirectStatus" class="dns-select">
              <option value="301">301 Permanent</option>
              <option value="302">302 Temporary</option>
            </select>
          </div>
        </div>
        <small class="dns-help-text" style="margin-bottom:14px;">
          Gunakan * sebagai wildcard. <code>$1</code> pada target menggantikan isi wildcard pertama.
          Contoh: <code>*example.com/blog/*</code> &rarr; <code>https://new.com/posts/$2</code>.
          Redirect hanya aktif untuk trafik yang melewati proxy Cloudflare (orange cloud).
        </small>
        <button type="submit" class="dns-btn dns-btn-primary dns-btn-sm">Add Redirect</button>
      </form>

      {* Daftar redirect aktif *}
      {if $pageRules}
      <div class="dns-table-wrap" style="margin-top:18px;">
        <table class="dns-table" style="min-width:560px;">
          <thead>
            <tr>
              <th>From</th>
              <th>To</th>
              <th class="dns-center">Code</th>
              <th class="dns-center">{$LANG.cfdnsmanager.actions}</th>
            </tr>
          </thead>
          <tbody>
          {foreach from=$pageRules item=rule}
            <tr>
              <td><span class="dns-record-name">{$rule.pattern}</span></td>
              <td><span class="dns-record-name">{$rule.target_url}</span></td>
              <td class="dns-center">
                {if $rule.status_code == 302}
                  <span class="dns-badge dns-badge-teal">302</span>
                {else}
                  <span class="dns-badge dns-badge-green">301</span>
                {/if}
              </td>
              <td class="dns-center">
                <form method="post" action="" class="dns-row-action-form"
                      onsubmit="return confirm('Delete this redirect rule?');">
                  <input type="hidden" name="cfdnsmanager_action" value="deleteRedirect">
                  <input type="hidden" name="zoneId" value="{$zoneId}">
                  <input type="hidden" name="ruleId" value="{$rule.id}">
                  <button type="submit" class="dns-icon-btn delete" title="Delete redirect rule">Del</button>
                </form>
              </td>
            </tr>
          {/foreach}
          </tbody>
        </table>
      </div>
      {else}
      <p style="margin-top:16px; font-size:13px;" class="dns-text-muted">No redirect rules yet.</p>
      {/if}

    </div>
  </div>

  {* ============ EXISTING RECORDS CARD ============ *}
  <div class="dns-card">
    <div class="dns-card-header">
      <span class="dns-card-title">{$LANG.cfdnsmanager.existingDnsRecords}</span>
      <span class="dns-result-meta" id="dnsResultMeta">{count($mergedRecords)} record</span>
    </div>
    <div class="dns-card-body">

      {if $mergedRecords}
      {* Toolbar: pencarian + filter tipe (satu tabel bersama) *}
      <div class="dns-toolbar">
        <div class="dns-search-wrap">
          <input type="text" id="dnsSearch" class="dns-input" placeholder="Search records by name, content, or type..." aria-label="Search DNS records">
        </div>
        <button type="button" id="clearSearch" class="dns-btn dns-btn-secondary dns-btn-sm">Clear</button>
      </div>

      <div class="dns-chips" id="dnsChips">
        <button type="button" class="dns-chip active" data-type="">All Types</button>
        <button type="button" class="dns-chip" data-type="A">A</button>
        <button type="button" class="dns-chip" data-type="AAAA">AAAA</button>
        <button type="button" class="dns-chip" data-type="CNAME">CNAME</button>
        <button type="button" class="dns-chip" data-type="MX">MX</button>
        <button type="button" class="dns-chip" data-type="TXT">TXT</button>
        <button type="button" class="dns-chip" data-type="NS">NS</button>
        <button type="button" class="dns-chip" data-type="CAA">CAA</button>
        <button type="button" class="dns-chip" data-type="SRV">SRV</button>
      </div>

      {* Bulk delete: form terpisah, input di tabel merujuk via atribut form= (hindari nested form) *}
      <form method="post" action="" id="dnsBulkForm">
        <input type="hidden" name="cfdnsmanager_action" value="bulkDelete">
      </form>

      {* Bulk proxy toggle: ID dikumpulkan via JS ke form ini saat submit *}
      <form method="post" action="" id="dnsProxyForm">
        <input type="hidden" name="cfdnsmanager_action" value="bulkSetProxy">
        <input type="hidden" name="proxied" value="0" id="proxyTargetValue">
      </form>

      <div class="dns-bulk-bar" id="dnsBulkBar">
        <span><strong><span id="dnsBulkCount">0</span> selected</strong></span>
        <span class="dns-bulk-hint">Delete atau ubah proxy untuk record terpilih.</span>
        <span class="dns-bulk-actions">
          <button type="button" class="dns-btn dns-btn-secondary dns-btn-sm" onclick="return bulkProxy(false);"
                  title="Matikan Cloudflare proxy (DNS-only / grey cloud)">Proxy Off</button>
          <button type="button" class="dns-btn dns-btn-success dns-btn-sm" onclick="return bulkProxy(true);"
                  title="Aktifkan Cloudflare proxy (orange cloud)">Proxy On</button>
          <button type="submit" form="dnsBulkForm" class="dns-btn dns-btn-danger dns-btn-sm"
                  onclick="return bulkConfirm();">Delete Selected</button>
        </span>
      </div>

      <div class="dns-table-wrap">
        <table class="dns-table">
          <thead>
            <tr>
              <th class="dns-center" style="width:36px;">
                <input type="checkbox" id="checkAll" aria-label="Select all visible records">
              </th>
              <th>{$LANG.cfdnsmanager.type}</th>
              <th>{$LANG.cfdnsmanager.name}</th>
              <th>{$LANG.cfdnsmanager.content}</th>
              <th class="dns-center">{$LANG.cfdnsmanager.ttl}</th>
              <th class="dns-center">{$LANG.cfdnsmanager.priority}</th>
              <th class="dns-center">Proxy</th>
              <th class="dns-center">Status</th>
              <th class="dns-center">{$LANG.cfdnsmanager.actions}</th>
            </tr>
          </thead>
          <tbody>
          {foreach from=$mergedRecords item=record}
            <tr class="dns-record-row" data-type="{$record.type}" data-record-id="{$record.id}"
                data-source="{if $record.source == 'cloudflare'}cloudflare{else}local{/if}"
                data-ttl="{$record.ttl|default:'1'}"
                data-priority="{$record.priority|default:'0'}"
                data-srv-weight="{$record.srv_weight|default:'0'}"
                data-srv-port="{$record.srv_port|default:'0'}"
                data-srv-target="{$record.srv_target|default:''}"
                data-proxied="{if isset($record.proxied) && $record.proxied}1{else}0{/if}">
              <td class="dns-center">
                <input type="checkbox" class="dns-row-check" form="dnsBulkForm"
                       value="{$record.id}"
                       data-kind="{if $record.source == 'cloudflare'}cloudflare{else}local{/if}"
                       aria-label="Select record {$record.name}">
              </td>
              <td><span class="dns-badge dns-badge-type">{$record.type}</span></td>
              <td><span class="dns-record-name">{$record.name}</span></td>
              <td class="dns-content-cell">
                <span class="full-content">{$record.content}</span>
                {if strlen($record.content) > 42}
                  <span class="dns-content-preview" onclick="showRecordDetails('{$record.id}')" title="Click to view full content">{$record.content|truncate:42:"..."}</span>
                {else}
                  <span class="dns-content-preview" onclick="showRecordDetails('{$record.id}')">{$record.content}</span>
                {/if}
              </td>
              <td class="dns-center">
                {if $record.ttl eq 1}<span class="dns-badge dns-badge-muted">Auto</span>{else}{$record.ttl}{/if}
              </td>
              <td class="dns-center">
                {if $record.type == 'MX' || $record.type == 'SRV'}
                  <span class="dns-badge dns-badge-blue">{$record.priority}</span>
                {else}
                  <span class="dns-badge dns-badge-muted">-</span>
                {/if}
              </td>
              <td class="dns-center">
                {if $record.type == 'A' || $record.type == 'AAAA' || $record.type == 'CNAME'}
                  {if isset($record.proxied) && $record.proxied}
                    <span class="dns-badge dns-badge-green">On</span>
                  {else}
                    <span class="dns-badge dns-badge-muted">Off</span>
                  {/if}
                {else}
                  <span class="dns-badge dns-badge-muted">-</span>
                {/if}
              </td>
              <td class="dns-center">
                {if $record.source == 'cloudflare'}
                  <span class="dns-badge dns-badge-blue">Cloudflare</span>
                {elseif $record.sync_status == 'synced'}
                  <span class="dns-badge dns-badge-green">Synced</span>
                {elseif $record.sync_status == 'pending'}
                  <span class="dns-badge dns-badge-teal">Pending</span>
                {elseif $record.sync_status == 'failed'}
                  <span class="dns-badge dns-badge-red">Failed</span>
                {elseif $record.sync_status == 'scanned'}
                  <span class="dns-badge dns-badge-amber">Scanned</span>
                {else}
                  <span class="dns-badge dns-badge-muted">Local</span>
                {/if}
              </td>
              <td class="dns-center">
                <span class="dns-row-actions">
                  {if $record.source == 'cloudflare'}
                    <button type="button" class="dns-icon-btn edit" title="Edit record" onclick='openEditModal("{$record.id}")'>
                      Edit
                    </button>
                    <form method="post" action="" class="dns-row-action-form" onsubmit="return confirm('{$LANG.cfdnsmanager.confirmDelete}');">
                      <input type="hidden" name="cfdnsmanager_action" value="deleteRecord">
                      <input type="hidden" name="zoneId" value="{$zoneId}">
                      <input type="hidden" name="recordId" value="{$record.id}">
                      <button type="submit" class="dns-icon-btn delete" title="Delete record">Del</button>
                    </form>
                  {else}
                    {if $record.sync_status == 'failed'}
                      <form method="post" action="" class="dns-row-action-form">
                        <input type="hidden" name="cfdnsmanager_action" value="retrySync">
                        <input type="hidden" name="localRecordId" value="{$record.id}">
                        <button type="submit" class="dns-icon-btn sync" title="Retry sync to Cloudflare">Retry</button>
                      </form>
                    {/if}
                    <form method="post" action="" class="dns-row-action-form" onsubmit="return confirm('Delete this local record?');">
                      <input type="hidden" name="cfdnsmanager_action" value="deleteLocalRecord">
                      <input type="hidden" name="localRecordId" value="{$record.id}">
                      <button type="submit" class="dns-icon-btn delete" title="Delete local record">Del</button>
                    </form>
                  {/if}
                </span>
              </td>
            </tr>
          {/foreach}
          </tbody>
        </table>
      </div>

      {else}
      <div class="dns-empty">
        <strong>No DNS Records Found</strong>
        <p>{$LANG.cfdnsmanager.noRecordsFound} {$domain}.</p>
      </div>
      {/if}

    </div>
  </div>
  </div>{* /#tabRecords *}

  {* ============ TAB 2: DNS ANALYTICS ============ *}
  <div class="dns-tab-pane dns-hidden-tab" id="tabAnalytics">

    {* Filter & Notice Bar *}
    <div class="dns-analytics-bar">
      <div class="dns-analytics-bar-header">
        <h4>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="width:18px; height:18px; color:var(--dns-primary);"><line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/></svg>
          {$LANG.cfdnsmanager.analyticsBarTitle}
        </h4>
        <p>{$LANG.cfdnsmanager.analyticsBarSubtitle}</p>
      </div>

      <div style="display:flex; align-items:center; gap:12px; flex-wrap:wrap;">
        <div style="display:flex; align-items:center; gap:6px;">
          <span style="font-size:12px; font-weight:600; color:var(--dns-gray-500); margin-right:4px;">Rentang:</span>
          <button type="button" class="dns-chip active dns-analytics-range" data-range="24h">{$LANG.cfdnsmanager.range24h}</button>
          <button type="button" class="dns-chip dns-analytics-range" data-range="7d">{$LANG.cfdnsmanager.range7d}</button>
          <button type="button" class="dns-chip dns-analytics-range" data-range="30d">{$LANG.cfdnsmanager.range30d}</button>
        </div>
        <div style="font-size:12px; color:var(--dns-gray-400); display:flex; align-items:center; gap:5px;" title="Cloudflare GraphQL Analytics API">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="width:13px; height:13px; color:var(--dns-primary);"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>
          <span>Free Tier GraphQL</span>
        </div>
      </div>
    </div>

    {* Loading Indicator *}
    <div id="analyticsLoading" style="display:none; text-align:center; padding:40px 20px;">
      <div style="display:inline-block; width:32px; height:32px; border:3px solid var(--dns-gray-200); border-top-color:var(--dns-primary); border-radius:50%; animation:dns-spin 1s linear infinite;"></div>
      <p style="margin-top:12px; font-size:13.5px; color:var(--dns-gray-500);">Memuat data analitik dari Cloudflare GraphQL...</p>
    </div>

    {* Analytics Error Message *}
    <div id="analyticsError" class="dns-alert dns-alert-error" style="display:none;">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
      <span id="analyticsErrorMessage"></span>
    </div>

    {* Main Analytics Data Content *}
    <div id="analyticsContent">
      {* Stat Summary Cards *}
      <div class="dns-stat-grid">
        <div class="dns-stat-card">
          <div class="dns-stat-label">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="width:14px; height:14px;"><circle cx="12" cy="12" r="10"/><path d="m4.93 4.93 4.24 4.24"/></svg>
            {$LANG.cfdnsmanager.totalQueries}
          </div>
          <div class="dns-stat-value" id="statTotalQueries">0</div>
          <div class="dns-stat-sub">Semua query DNS</div>
        </div>

        <div class="dns-stat-card">
          <div class="dns-stat-label">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="width:14px; height:14px; color:#16a34a;"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
            {$LANG.cfdnsmanager.noErrorCount}
          </div>
          <div class="dns-stat-value" id="statNoError" style="color:#16a34a;">0</div>
          <div class="dns-stat-sub" id="statSuccessRate">100% success rate</div>
        </div>

        <div class="dns-stat-card">
          <div class="dns-stat-label">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="width:14px; height:14px; color:#d97706;"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
            {$LANG.cfdnsmanager.nxDomainCount}
          </div>
          <div class="dns-stat-value" id="statNxDomain" style="color:#d97706;">0</div>
          <div class="dns-stat-sub">Query record tidak ada</div>
        </div>

        <div class="dns-stat-card">
          <div class="dns-stat-label">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="width:14px; height:14px; color:#2563eb;"><path d="m12 3-1.9 5.8a2 2 0 0 1-1.3 1.3L3 12l5.8 1.9a2 2 0 0 1 1.3 1.3L12 21l1.9-5.8a2 2 0 0 1 1.3-1.3L21 12l-5.8-1.9a2 2 0 0 1-1.3-1.3Z"/></svg>
            {$LANG.cfdnsmanager.topQueriedHost}
          </div>
          <div class="dns-stat-value" id="statTopHost" style="font-size:16px; word-break:break-all; font-family:var(--dns-mono);">-</div>
          <div class="dns-stat-sub">Resolusi terbanyak</div>
        </div>
      </div>

      {* Charts Grid *}
      <div class="dns-grid-2">
        {* Volume Over Time *}
        <div class="dns-card">
          <div class="dns-card-header">
            <span class="dns-card-title">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>
              {$LANG.cfdnsmanager.queryVolume}
            </span>
          </div>
          <div class="dns-card-body">
            <p class="dns-chart-card-desc">
              Grafik menunjukkan fluktuasi jumlah resolusi kueri nama domain Anda dari waktu ke waktu. Puncak (peak) menandakan lonjakan traffic atau akses pengunjung.
            </p>
            <div class="dns-chart-container" style="height:280px;">
              <canvas id="chartVolume"></canvas>
            </div>
            <div class="dns-chart-summary-bar" id="chartVolumeSummary">
              <span>Rata-rata kueri per interval: <strong id="valAvgQueries">0</strong></span>
              <span>Puncak tertinggi: <strong id="valPeakQueries" style="color:var(--dns-primary);">0</strong></span>
            </div>
          </div>
        </div>

        {* Queries by Record Type *}
        <div class="dns-card">
          <div class="dns-card-header">
            <span class="dns-card-title">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21.21 15.89A10 10 0 1 1 8 2.83"/><path d="M22 12A10 10 0 0 0 12 2v10z"/></svg>
              {$LANG.cfdnsmanager.queryTypeBreakdown}
            </span>
          </div>
          <div class="dns-card-body">
            <p class="dns-chart-card-desc">
              Proporsi jenis DNS record yang paling banyak diminta oleh pengunjung atau aplikasi luar (misal: <strong>A/AAAA</strong> untuk website, <strong>MX</strong> untuk email).
            </p>
            <div class="dns-chart-container" style="height:280px;">
              <canvas id="chartType"></canvas>
            </div>
            <div id="chartTypeBreakdownList" class="dns-type-list">
              <!-- Item breakdown list rendered via JS -->
            </div>
          </div>
        </div>
      </div>

      {* Top Queries Table *}
      <div class="dns-card">
        <div class="dns-card-header">
          <span class="dns-card-title">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/></svg>
            {$LANG.cfdnsmanager.topQueriesTitle}
          </span>
        </div>
        <div class="dns-card-body" style="padding:0;">
          <div class="dns-analytics-table-wrap">
            <table class="dns-analytics-table">
              <thead>
                <tr>
                  <th style="width:50px;">#</th>
                  <th>Hostname / Query Name</th>
                  <th style="text-align:right; width:130px;">Queries</th>
                  <th style="width:200px;">Distribusi</th>
                </tr>
              </thead>
              <tbody id="topQueriesTableBody">
                <tr>
                  <td colspan="4" class="dns-text-center" style="padding:20px; color:var(--dns-gray-400);">Belum ada data query DNS.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

    </div>{* /#analyticsContent *}

  </div>{* /#tabAnalytics *}

  {/if}{* end zoneId check *}

</div>{* /.dns-page *}

{* ============ RECORD DETAILS MODAL ============ *}
<div class="dns-modal-overlay" id="recordDetailsOverlay">
  <div class="dns-modal">
    <div class="dns-modal-header">
      <h3>Record Content</h3>
      <button type="button" class="dns-modal-close" onclick="closeModals()" aria-label="Close">x</button>
    </div>
    <div class="dns-modal-body">
      <div class="dns-record-content" id="recordDetailsContent"></div>
    </div>
    <div class="dns-modal-footer">
      <button type="button" class="dns-btn dns-btn-secondary" onclick="closeModals()">{$LANG.cfdnsmanager.close}</button>
    </div>
  </div>
</div>

{* ============ EDIT RECORD MODAL ============ *}
<div class="dns-modal-overlay" id="editRecordOverlay">
  <div class="dns-modal">
    <div class="dns-modal-header">
      <h3>{$LANG.cfdnsmanager.editDnsRecord}</h3>
      <button type="button" class="dns-modal-close" onclick="closeModals()" aria-label="Close">x</button>
    </div>
    <form method="post" action="" id="dnsEditForm">
      <input type="hidden" name="cfdnsmanager_action" value="editRecord">
      <input type="hidden" name="zoneId" value="{$zoneId}">
      <input type="hidden" name="recordId" value="" id="edit_recordId">
      <div class="dns-modal-body">
        <div class="dns-form-row" style="margin-bottom:14px;">
          <div>
            <label class="dns-label" for="edit_type">{$LANG.cfdnsmanager.type}</label>
            <select name="type" id="edit_type" class="dns-select">
              <option value="A">A</option>
              <option value="AAAA">AAAA</option>
              <option value="CNAME">CNAME</option>
              <option value="MX">MX</option>
              <option value="TXT">TXT</option>
              <option value="NS">NS</option>
              <option value="CAA">CAA</option>
              <option value="SRV">SRV</option>
            </select>
          </div>
          <div>
            <label class="dns-label" for="edit_ttl">{$LANG.cfdnsmanager.ttl}</label>
            <select name="ttl" id="edit_ttl" class="dns-select">
              <option value="1">Auto</option>
              <option value="60">1 minute</option>
              <option value="300">5 minutes</option>
              <option value="900">15 minutes</option>
              <option value="1800">30 minutes</option>
              <option value="3600">1 hour</option>
              <option value="7200">2 hours</option>
              <option value="18000">5 hours</option>
              <option value="43200">12 hours</option>
              <option value="86400">1 day</option>
            </select>
          </div>
        </div>

        <div class="dns-form-group dns-hidden-field" id="edit_srvSummary" style="font-size:13px; color:var(--dns-gray-600); background:var(--dns-gray-50); border:1px solid var(--dns-gray-200); border-radius:8px; padding:10px 12px; margin-bottom:14px;">
          <strong id="edit_srvSummary_name" style="color:var(--dns-gray-800);">[name]</strong> points to <strong id="edit_srvSummary_target" style="color:var(--dns-gray-800);">[target]</strong> and listens on <strong id="edit_srvSummary_port" style="color:var(--dns-gray-800);">[port]</strong>.
        </div>

        <div class="dns-form-group" id="edit_standardNameGroup">
          <label class="dns-label" for="edit_name">{$LANG.cfdnsmanager.name}</label>
          <input type="text" name="name" id="edit_name" class="dns-input mono" required>
          <small class="dns-help-text">Nama akan otomatis dilengkapi dengan domain jika belum lengkap.</small>
        </div>

        {* SRV Name + Priority Row *}
        <div class="dns-form-row dns-hidden-field" id="edit_srvNameRow" style="margin-bottom:14px;">
          <div>
            <label class="dns-label" for="edit_srv_name">Name</label>
            <input type="text" name="srv_name" id="edit_srv_name" class="dns-input mono" placeholder="E.g. _sip._tcp.example.com">
            <small class="dns-help-text">Format: _service._proto (e.g. _sip._tcp)</small>
          </div>
          <div>
            <label class="dns-label" for="edit_srv_priority">Priority</label>
            <input type="number" name="srv_priority" id="edit_srv_priority" class="dns-input" value="10" min="0">
          </div>
        </div>

        {* SRV Weight + Port Row *}
        <div class="dns-form-row dns-hidden-field" id="edit_srvWeightPortRow" style="margin-bottom:14px;">
          <div>
            <label class="dns-label" for="edit_srv_weight">Weight</label>
            <input type="number" name="srv_weight" id="edit_srv_weight" class="dns-input" value="5" min="0">
          </div>
          <div>
            <label class="dns-label" for="edit_srv_port">Port</label>
            <input type="number" name="srv_port" id="edit_srv_port" class="dns-input" placeholder="e.g. 5060" min="1" max="65535">
          </div>
        </div>

        {* SRV Target *}
        <div class="dns-form-group dns-hidden-field" id="edit_srvTargetRow">
          <label class="dns-label" for="edit_srv_target">Target</label>
          <input type="text" name="srv_target" id="edit_srv_target" class="dns-input mono" placeholder="E.g. www.example.com">
        </div>

        <div class="dns-form-group" id="edit_standardContentGroup">
          <label class="dns-label" for="edit_content">{$LANG.cfdnsmanager.content}</label>
          <textarea name="content" id="edit_content" class="dns-textarea mono" rows="2" required></textarea>
        </div>

        <div class="dns-form-group dns-hidden-field" id="edit_priorityGroup">
          <label class="dns-label" for="edit_priority">{$LANG.cfdnsmanager.priority}</label>
          <input type="number" name="priority" id="edit_priority" class="dns-input" value="0" min="0">
        </div>

        <div class="dns-form-group dns-hidden-field" id="edit_proxyGroup">
          <label class="dns-checkbox-card" for="edit_proxied">
            <input type="checkbox" name="proxied" id="edit_proxied" value="1">
            <span><strong>Enable Cloudflare Proxy</strong></span>
          </label>
        </div>
      </div>
      <div class="dns-modal-footer">
        <button type="button" class="dns-btn dns-btn-secondary" onclick="closeModals()">{$LANG.cfdnsmanager.close}</button>
        <button type="submit" class="dns-btn dns-btn-primary">{$LANG.cfdnsmanager.saveChanges}</button>
      </div>
    </form>
  </div>
</div>
</div>{* /.dns-manager-container *}

<script>
{literal}
(function () {
  'use strict';

  /* ---------- Helper: Update SRV live sentence summary ---------- */
  function updateSrvSummary(nameVal, targetVal, portVal, nameEl, targetEl, portEl) {
    if (nameEl) { nameEl.textContent = nameVal ? nameVal : '[name]'; }
    if (targetEl) { targetEl.textContent = targetVal ? targetVal : '[target]'; }
    if (portEl) { portEl.textContent = portVal ? portVal : '[port]'; }
  }

  /* ---------- Helper: tampilkan/sembunyikan field per tipe record ---------- */
  function applyTypeVisibility(typeEl, priorityGroup, proxyGroup, isEdit) {
    var t = (typeEl.value || '').toUpperCase();
    var isSrv = (t === 'SRV');
    var isMx = (t === 'MX');

    if (priorityGroup) {
      priorityGroup.classList.toggle('dns-hidden-field', !(isMx));
    }
    if (proxyGroup) {
      proxyGroup.classList.toggle('dns-hidden-field', !(t === 'A' || t === 'AAAA' || t === 'CNAME'));
    }

    var prefix = isEdit ? 'edit_' : '';
    var srvSummary       = document.getElementById(isEdit ? 'edit_srvSummary' : 'add_srvSummary');
    var srvNameRow       = document.getElementById(isEdit ? 'edit_srvNameRow' : 'srvNameRow');
    var srvWeightPortRow = document.getElementById(isEdit ? 'edit_srvWeightPortRow' : 'srvWeightPortRow');
    var srvTargetRow     = document.getElementById(isEdit ? 'edit_srvTargetRow' : 'srvTargetRow');
    var stdNameCol       = document.getElementById(isEdit ? 'edit_standardNameGroup' : 'standardNameCol');
    var stdContentCol    = document.getElementById(isEdit ? 'edit_standardContentGroup' : 'standardContentCol');

    if (srvSummary) { srvSummary.classList.toggle('dns-hidden-field', !isSrv); }
    if (srvNameRow) { srvNameRow.classList.toggle('dns-hidden-field', !isSrv); }
    if (srvWeightPortRow) { srvWeightPortRow.classList.toggle('dns-hidden-field', !isSrv); }
    if (srvTargetRow) { srvTargetRow.classList.toggle('dns-hidden-field', !isSrv); }

    if (stdNameCol) { stdNameCol.classList.toggle('dns-hidden-field', isSrv); }
    if (stdContentCol) { stdContentCol.classList.toggle('dns-hidden-field', isSrv); }

    var stdNameInput = document.getElementById(isEdit ? 'edit_name' : 'name');
    var stdContentInput = document.getElementById(isEdit ? 'edit_content' : 'content');
    if (stdNameInput) {
      if (isSrv) { stdNameInput.removeAttribute('required'); } else { stdNameInput.setAttribute('required', 'required'); }
    }
    if (stdContentInput) {
      if (isSrv) { stdContentInput.removeAttribute('required'); } else { stdContentInput.setAttribute('required', 'required'); }
    }
  }

  /* ---------- Add form: field dinamis + placeholder konten ---------- */
  var addForm = document.getElementById('dnsAddForm');
  if (addForm) {
    var typeEl      = document.getElementById('type');
    var contentEl   = document.getElementById('content');
    var contentHelp = document.getElementById('contentHelp');

    var srvNameInput   = document.getElementById('srv_name');
    var srvPortInput   = document.getElementById('srv_port');
    var srvTargetInput = document.getElementById('srv_target');

    function refreshAddSrvSummary() {
      updateSrvSummary(
        srvNameInput ? srvNameInput.value.trim() : '',
        srvTargetInput ? srvTargetInput.value.trim() : '',
        srvPortInput ? srvPortInput.value.trim() : '',
        document.getElementById('add_srvSummary_name'),
        document.getElementById('add_srvSummary_target'),
        document.getElementById('add_srvSummary_port')
      );
    }

    if (srvNameInput) { srvNameInput.addEventListener('input', refreshAddSrvSummary); }
    if (srvPortInput) { srvPortInput.addEventListener('input', refreshAddSrvSummary); }
    if (srvTargetInput) { srvTargetInput.addEventListener('input', refreshAddSrvSummary); }

    var placeholders = {
      A: '192.0.2.1',
      AAAA: '2001:db8::1',
      CNAME: 'target.example.com',
      MX: 'mail.example.com',
      TXT: 'v=spf1 include:_spf.mx.cloudflare.net ~all',
      NS: 'ns1.cloudflare.com',
      CAA: '0 issue "letsencrypt.org"'
    };

    var helps = {
      A: 'IPv4 address, contoh: 192.0.2.1',
      AAAA: 'IPv6 address, contoh: 2001:db8::1',
      CNAME: 'Target hostname, contoh: example.com',
      MX: 'Mail server hostname, contoh: mail.example.com',
      TXT: 'Nilai teks bebas, misalnya SPF/DKIM/verifikasi',
      NS: 'Authoritative nameserver, contoh: ns1.example.com',
      CAA: 'Format: flags tag "value", contoh: 0 issue "letsencrypt.org"',
      SRV: 'Format: _service._proto, Priority, Weight, Port, Target'
    };

    function onAddTypeChange() {
      var t = typeEl.value.toUpperCase();
      applyTypeVisibility(
        typeEl,
        document.getElementById('priorityCol'),
        document.getElementById('proxyCol'),
        false
      );
      contentEl.placeholder = placeholders[t] || '';
      if (contentHelp) { contentHelp.textContent = helps[t] || ''; }
      if (t === 'SRV') { refreshAddSrvSummary(); }
    }

    typeEl.addEventListener('change', onAddTypeChange);
    onAddTypeChange();

    addForm.addEventListener('submit', function (e) {
      var t = typeEl.value.toUpperCase();
      if (t === 'SRV') {
        var sName = srvNameInput ? srvNameInput.value.trim() : '';
        var sTarget = srvTargetInput ? srvTargetInput.value.trim() : '';
        var sPort = srvPortInput ? srvPortInput.value.trim() : '';
        if (!sName || !sTarget || !sPort) {
          e.preventDefault();
          alert('Silakan lengkapi Name, Target, dan Port untuk SRV record.');
          return false;
        }
        var stdName = document.getElementById('name');
        var stdContent = document.getElementById('content');
        if (stdName) { stdName.value = sName; }
        if (stdContent) { stdContent.value = sTarget; }
        return true;
      }

      var name = document.getElementById('name').value.trim();
      var content = contentEl.value.trim();
      if (!name || !content) {
        e.preventDefault();
        alert('Please fill in all required fields.');
        return false;
      }
      return true;
    });
  }

  /* ---------- Edit form: SRV live summary & submit check ---------- */
  var editForm = document.getElementById('dnsEditForm');
  if (editForm) {
    var editSrvNameInput   = document.getElementById('edit_srv_name');
    var editSrvPortInput   = document.getElementById('edit_srv_port');
    var editSrvTargetInput = document.getElementById('edit_srv_target');

    function refreshEditSrvSummary() {
      updateSrvSummary(
        editSrvNameInput ? editSrvNameInput.value.trim() : '',
        editSrvTargetInput ? editSrvTargetInput.value.trim() : '',
        editSrvPortInput ? editSrvPortInput.value.trim() : '',
        document.getElementById('edit_srvSummary_name'),
        document.getElementById('edit_srvSummary_target'),
        document.getElementById('edit_srvSummary_port')
      );
    }

    if (editSrvNameInput) { editSrvNameInput.addEventListener('input', refreshEditSrvSummary); }
    if (editSrvPortInput) { editSrvPortInput.addEventListener('input', refreshEditSrvSummary); }
    if (editSrvTargetInput) { editSrvTargetInput.addEventListener('input', refreshEditSrvSummary); }

    editForm.addEventListener('submit', function (e) {
      var editType = document.getElementById('edit_type');
      var t = editType ? editType.value.toUpperCase() : '';
      if (t === 'SRV') {
        var sName = editSrvNameInput ? editSrvNameInput.value.trim() : '';
        var sTarget = editSrvTargetInput ? editSrvTargetInput.value.trim() : '';
        var sPort = editSrvPortInput ? editSrvPortInput.value.trim() : '';
        if (!sName || !sTarget || !sPort) {
          e.preventDefault();
          alert('Silakan lengkapi Name, Target, dan Port untuk SRV record.');
          return false;
        }
        var stdName = document.getElementById('edit_name');
        var stdContent = document.getElementById('edit_content');
        if (stdName) { stdName.value = sName; }
        if (stdContent) { stdContent.value = sTarget; }
        return true;
      }

      var name = document.getElementById('edit_name').value.trim();
      var content = document.getElementById('edit_content').value.trim();
      if (!name || !content) {
        e.preventDefault();
        alert('Please fill in all required fields.');
        return false;
      }
      return true;
    });
  }

  /* ---------- Filter chips + pencarian (satu tabel bersama) ---------- */
  var currentTypeFilter = '';

  function applyFilters() {
    var searchInput = document.getElementById('dnsSearch');
    var term = searchInput ? searchInput.value.toLowerCase().trim() : '';
    var visible = 0;

    document.querySelectorAll('.dns-record-row').forEach(function (row) {
      var matchType = !currentTypeFilter || (row.getAttribute('data-type') || '').toUpperCase() === currentTypeFilter;
      var matchTerm = !term || row.textContent.toLowerCase().indexOf(term) !== -1;
      var show = matchType && matchTerm;
      row.style.display = show ? '' : 'none';
      if (show) { visible++; }
    });

    var meta = document.getElementById('dnsResultMeta');
    if (meta) {
      meta.textContent = visible === 1 ? '1 record' : visible + ' records';
    }
  }

  document.querySelectorAll('#dnsChips .dns-chip').forEach(function (chip) {
    chip.addEventListener('click', function () {
      document.querySelectorAll('#dnsChips .dns-chip').forEach(function (c) { c.classList.remove('active'); });
      chip.classList.add('active');
      currentTypeFilter = (chip.getAttribute('data-type') || '').toUpperCase();
      applyFilters();
    });
  });

  var searchInput = document.getElementById('dnsSearch');
  if (searchInput) {
    searchInput.addEventListener('input', applyFilters);
    var clearBtn = document.getElementById('clearSearch');
    if (clearBtn) {
      clearBtn.addEventListener('click', function () {
        searchInput.value = '';
        applyFilters();
        searchInput.focus();
      });
    }
  }

  /* ---------- Bulk selection ---------- */
  var bulkBar   = document.getElementById('dnsBulkBar');
  var bulkCount = document.getElementById('dnsBulkCount');

  function refreshBulkBar() {
    var checked = document.querySelectorAll('.dns-row-check:checked').length;
    if (bulkBar) { bulkBar.classList.toggle('active', checked > 0); }
    if (bulkCount) { bulkCount.textContent = checked; }
  }

  document.addEventListener('change', function (e) {
    var el = e.target;
    if (!el.classList) { return; }

    if (el.classList.contains('dns-row-check')) {
      var tr = el.closest ? el.closest('tr') : null;
      if (tr) { tr.classList.toggle('row-selected', el.checked); }
      refreshBulkBar();
      return;
    }

    /* Select all: hanya baris yang terlihat (sesuai filter aktif) */
    if (el.id === 'checkAll') {
      document.querySelectorAll('.dns-record-row').forEach(function (row) {
        if (row.style.display === 'none') { return; }
        var cb = row.querySelector('.dns-row-check');
        if (!cb) { return; }
        cb.checked = el.checked;
        row.classList.toggle('row-selected', el.checked);
      });
      refreshBulkBar();
    }
  });

  window.bulkConfirm = function () {
    var n = document.querySelectorAll('.dns-row-check:checked').length;
    if (!n) { return false; }
    return confirm('Hapus permanen ' + n + ' record terpilih dari Cloudflare dan database? Tindakan ini tidak bisa dibatalkan.');
  };

  /* ---------- Bulk toggle proxy (hanya A/AAAA/CNAME) ---------- */
  var PROXYABLE_TYPES = ['A', 'AAAA', 'CNAME'];

  window.bulkProxy = function (enable) {
    var proxyForm = document.getElementById('dnsProxyForm');
    if (!proxyForm) { return false; }

    var eligibleIds = [];
    var skippedNonProxyable = 0;

    document.querySelectorAll('.dns-row-check:checked').forEach(function (cb) {
      var row = cb.closest ? cb.closest('.dns-record-row') : null;
      if (!row) { return; }
      /* Hanya record cloudflare yang bisa diubah (local/pending belum ada di Cloudflare) */
      if ((row.getAttribute('data-source') || '') !== 'cloudflare') { return; }
      var t = (row.getAttribute('data-type') || '').toUpperCase();
      if (PROXYABLE_TYPES.indexOf(t) === -1) {
        skippedNonProxyable++;
        return;
      }
      eligibleIds.push(cb.value);
    });

    if (!eligibleIds.length) {
      alert(
        'Tidak ada record yang bisa diproxy.' +
        (skippedNonProxyable > 0
          ? '\n\n' + skippedNonProxyable + ' record dilewati karena hanya tipe A, AAAA, dan CNAME yang mendukung Cloudflare Proxy.'
          : '')
      );
      return false;
    }

    var warnText = enable
      ? 'Aktifkan Cloudflare Proxy untuk ' + eligibleIds.length + ' record?'
      : 'Matikan Cloudflare Proxy untuk ' + eligibleIds.length + ' record? (DNS-only / grey cloud)';
    if (skippedNonProxyable > 0) {
      warnText += '\n\nCatatan: ' + skippedNonProxyable + ' record tipe non-proxy akan dilewati.';
    }
    warnText += '\n\nPerubahan memengaruhi SSL/caching/DDoS protection pada record terkait.';

    if (!confirm(warnText)) { return false; }

    /* Kumpulkan ID ke form proxy sebagai input tersembunyi */
    proxyForm.querySelectorAll('input[name="recordIds[]"]').forEach(function (inp) { inp.remove(); });
    eligibleIds.forEach(function (id) {
      var inp = document.createElement('input');
      inp.type = 'hidden';
      inp.name = 'recordIds[]';
      inp.value = id;
      proxyForm.appendChild(inp);
    });

    document.getElementById('proxyTargetValue').value = enable ? '1' : '0';
    proxyForm.submit();
    return true;
  };

  /* ---------- Modals ---------- */
  window.closeModals = function () {
    document.querySelectorAll('.dns-modal-overlay').forEach(function (o) { o.classList.remove('open'); });
  };

  ['recordDetailsOverlay', 'editRecordOverlay'].forEach(function (id) {
    var el = document.getElementById(id);
    if (el) {
      el.addEventListener('click', function (e) { if (e.target === el) { window.closeModals(); } });
    }
  });

  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') { window.closeModals(); }
  });

  /* ---------- Detail konten record ---------- */
  window.showRecordDetails = function (recordId) {
    var row = document.querySelector('.dns-record-row[data-record-id="' + recordId + '"]');
    var target = document.getElementById('recordDetailsContent');
    if (!row || !target) { return; }
    var full = row.querySelector('.full-content');
    target.textContent = full ? full.textContent : '(no content)';
    document.getElementById('recordDetailsOverlay').classList.add('open');
  };

  /* ---------- Edit modal: prefill dari data attributes baris ---------- */
  window.openEditModal = function (recordId) {
    var row = document.querySelector('.dns-record-row[data-record-id="' + recordId + '"]');
    if (!row) { return; }

    var ds = row.dataset || {};
    var type = (ds.type || '').toUpperCase();

    function setSelect(id, val) {
      var sel = document.getElementById(id);
      if (!sel) { return; }
      for (var i = 0; i < sel.options.length; i++) {
        if (String(sel.options[i].value) === String(val)) { sel.selectedIndex = i; return; }
      }
      sel.selectedIndex = 0;
    }

    setSelect('edit_type', type);

    /* TTL dari data-ttl (nilai 1 = Auto) */
    var ttlVal = parseInt(ds.ttl, 10);
    setSelect('edit_ttl', isNaN(ttlVal) || ttlVal <= 0 ? 1 : ttlVal);

    document.getElementById('edit_recordId').value = recordId;

    var nameEl = row.querySelector('.dns-record-name');
    var rawName = nameEl ? nameEl.textContent.trim() : '';
    document.getElementById('edit_name').value = rawName;

    var full = row.querySelector('.full-content');
    var rawContent = full ? full.textContent.trim() : '';
    document.getElementById('edit_content').value = rawContent;

    /* Priority dari data-priority (hanya relevan MX/SRV) */
    var prioVal = parseInt(ds.priority, 10);
    var effectivePriority = isNaN(prioVal) || prioVal < 0 ? 0 : prioVal;
    document.getElementById('edit_priority').value = effectivePriority;

    /* SRV specific fields population */
    var srvPrioInput = document.getElementById('edit_srv_priority');
    var srvWeightInput = document.getElementById('edit_srv_weight');
    var srvPortInput = document.getElementById('edit_srv_port');
    var srvTargetInput = document.getElementById('edit_srv_target');
    var srvNameInput = document.getElementById('edit_srv_name');

    if (srvNameInput) { srvNameInput.value = rawName; }
    if (srvPrioInput) { srvPrioInput.value = effectivePriority; }

    var weightVal = parseInt(ds.srvWeight, 10);
    var portVal = parseInt(ds.srvPort, 10);
    var targetVal = ds.srvTarget || '';

    // If dataset doesn't have it (e.g. raw content like "5 5060 target.com" or "10 5 5060 target.com")
    if ((!portVal || !targetVal) && type === 'SRV' && rawContent) {
      var parts = rawContent.split(/\s+/);
      if (parts.length === 3) {
        weightVal = parseInt(parts[0], 10) || 0;
        portVal = parseInt(parts[1], 10) || 0;
        targetVal = parts[2] || '';
      } else if (parts.length >= 4) {
        if (!effectivePriority) { effectivePriority = parseInt(parts[0], 10) || 0; }
        weightVal = parseInt(parts[1], 10) || 0;
        portVal = parseInt(parts[2], 10) || 0;
        targetVal = parts[3] || '';
      }
    }

    if (srvWeightInput) { srvWeightInput.value = isNaN(weightVal) ? 0 : weightVal; }
    if (srvPortInput) { srvPortInput.value = isNaN(portVal) ? '' : (portVal > 0 ? portVal : ''); }
    if (srvTargetInput) { srvTargetInput.value = targetVal || (type === 'SRV' ? rawContent : ''); }

    updateSrvSummary(
      rawName,
      targetVal || rawContent,
      portVal > 0 ? portVal : '',
      document.getElementById('edit_srvSummary_name'),
      document.getElementById('edit_srvSummary_target'),
      document.getElementById('edit_srvSummary_port')
    );

    /* Proxy dari data-proxied */
    document.getElementById('edit_proxied').checked = ds.proxied === '1';

    applyTypeVisibility(
      document.getElementById('edit_type'),
      document.getElementById('edit_priorityGroup'),
      document.getElementById('edit_proxyGroup'),
      true
    );

    /* Reaktif saat tipe diubah di dalam modal edit */
    var editType = document.getElementById('edit_type');
    editType.onchange = function () {
      applyTypeVisibility(
        editType,
        document.getElementById('edit_priorityGroup'),
        document.getElementById('edit_proxyGroup'),
        true
      );
    };

    document.getElementById('editRecordOverlay').classList.add('open');
  };

  /* =========================================================================
   * MAIN TAB SWITCHER (Records vs Analytics)
   * ========================================================================= */
  var mainTabs = document.querySelectorAll('.dns-main-tab');
  var currentActiveTab = 'tabRecords';
  var analyticsLoaded = false;
  var currentAnalyticsRange = '24h';

  mainTabs.forEach(function (tab) {
    tab.addEventListener('click', function () {
      var targetId = tab.getAttribute('data-target');
      if (!targetId || targetId === currentActiveTab) { return; }

      mainTabs.forEach(function (t) { t.classList.remove('active'); });
      tab.classList.add('active');

      document.querySelectorAll('.dns-tab-pane').forEach(function (pane) {
        pane.classList.add('dns-hidden-tab');
      });

      var activePane = document.getElementById(targetId);
      if (activePane) {
        activePane.classList.remove('dns-hidden-tab');
      }

      currentActiveTab = targetId;

      if (targetId === 'tabAnalytics' && !analyticsLoaded) {
        loadDnsAnalytics(currentAnalyticsRange);
      }
    });
  });

  /* =========================================================================
   * DNS ANALYTICS (Cloudflare GraphQL Analytics API)
   * ========================================================================= */
  var rangeButtons = document.querySelectorAll('.dns-analytics-range');
  rangeButtons.forEach(function (btn) {
    btn.addEventListener('click', function () {
      rangeButtons.forEach(function (b) { b.classList.remove('active'); });
      btn.classList.add('active');
      currentAnalyticsRange = btn.getAttribute('data-range') || '24h';
      loadDnsAnalytics(currentAnalyticsRange);
    });
  });

  function loadDnsAnalytics(range) {
    var loadingEl = document.getElementById('analyticsLoading');
    var contentEl = document.getElementById('analyticsContent');
    var errorEl   = document.getElementById('analyticsError');
    var errMsgEl  = document.getElementById('analyticsErrorMessage');

    if (loadingEl) { loadingEl.style.display = 'block'; }
    if (contentEl) { contentEl.style.opacity = '0.35'; }
    if (errorEl)   { errorEl.style.display = 'none'; }

    var url = window.location.href.split('#')[0];
    var sep = url.indexOf('?') !== -1 ? '&' : '?';
    var fetchUrl = url + sep + 'cfdnsmanager_action=getDnsAnalytics&range=' + encodeURIComponent(range);

    fetch(fetchUrl, {
      method: 'GET',
      headers: { 'X-Requested-With': 'XMLHttpRequest' }
    })
    .then(function (res) { return res.json(); })
    .then(function (data) {
      if (loadingEl) { loadingEl.style.display = 'none'; }
      if (contentEl) { contentEl.style.opacity = '1'; }

      if (!data || !data.success) {
        if (errorEl) {
          errMsgEl.textContent = (data && data.message) ? data.message : 'Gagal memuat analitik DNS dari Cloudflare.';
          errorEl.style.display = 'flex';
        }
        return;
      }

      analyticsLoaded = true;
      renderDnsAnalytics(data);
    })
    .catch(function (err) {
      if (loadingEl) { loadingEl.style.display = 'none'; }
      if (contentEl) { contentEl.style.opacity = '1'; }
      if (errorEl) {
        errMsgEl.textContent = 'Terjadi kesalahan koneksi saat mengambil data GraphQL: ' + err.message;
        errorEl.style.display = 'flex';
      }
    });
  }

  function formatNumber(num) {
    return (num || 0).toLocaleString();
  }

  function renderDnsAnalytics(data) {
    var summary = data.summary || {};
    var timeSeries = data.timeSeries || [];
    var byQueryType = data.byQueryType || [];
    var byResponseCode = data.byResponseCode || [];
    var topQueries = data.topQueries || [];

    // 1. KPI Cards
    var elTotal = document.getElementById('statTotalQueries');
    var elNoError = document.getElementById('statNoError');
    var elNx = document.getElementById('statNxDomain');
    var elRate = document.getElementById('statSuccessRate');
    var elTopHost = document.getElementById('statTopHost');

    if (elTotal) { elTotal.textContent = formatNumber(summary.totalQueries); }
    if (elNoError) { elNoError.textContent = formatNumber(summary.noErrorCount); }
    if (elNx) { elNx.textContent = formatNumber(summary.nxDomainCount); }
    if (elRate) { elRate.textContent = (summary.successRate || 100) + '% success rate'; }
    if (elTopHost) { elTopHost.textContent = summary.topQuery || '-'; }

    // 2. Charts
    drawVolumeChart('chartVolume', timeSeries);
    drawTypePieChart('chartType', byQueryType);

    // 3. Top Queries Table
    var tbody = document.getElementById('topQueriesTableBody');
    if (tbody) {
      if (!topQueries.length) {
        tbody.innerHTML = '<tr><td colspan="4" class="dns-text-center" style="padding:22px; color:var(--dns-gray-400);">Tidak ada catatan query DNS pada periode ini.</td></tr>';
      } else {
        var total = summary.totalQueries > 0 ? summary.totalQueries : 1;
        var html = '';
        topQueries.forEach(function (item, idx) {
          var name = (item.dimensions && item.dimensions.queryName) ? item.dimensions.queryName : '-';
          var count = item.count || 0;
          var pct = Math.round((count / total) * 100);
          html += '<tr>' +
            '<td style="color:var(--dns-gray-400); font-weight:600;">' + (idx + 1) + '</td>' +
            '<td><strong class="dns-mono" style="color:var(--dns-gray-800);">' + escapeHtml(name) + '</strong></td>' +
            '<td style="text-align:right; font-weight:600;">' + formatNumber(count) + '</td>' +
            '<td>' +
              '<div class="dns-analytics-progress-bg">' +
                '<div class="dns-analytics-progress-bar" style="width:' + pct + '%;"></div>' +
              '</div>' +
              '<span style="font-size:12px; color:var(--dns-gray-500);">' + pct + '%</span>' +
            '</td>' +
          '</tr>';
        });
        tbody.innerHTML = html;
      }
    }
  }

  function escapeHtml(str) {
    return String(str || '').replace(/[&<>"']/g, function (m) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' }[m];
    });
  }

  /* Canvas Bar / Smooth Area Chart for Volume Over Time */
  function drawVolumeChart(canvasId, series) {
    var canvas = document.getElementById(canvasId);
    if (!canvas) { return; }
    var ctx = canvas.getContext('2d');
    var w = canvas.offsetWidth || 500;
    var h = 280;
    canvas.width = w * window.devicePixelRatio || w;
    canvas.height = h * window.devicePixelRatio || h;
    ctx.scale(window.devicePixelRatio || 1, window.devicePixelRatio || 1);

    ctx.clearRect(0, 0, w, h);

    if (!series || !series.length) {
      ctx.fillStyle = '#94a3b8';
      ctx.font = '14px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('Belum ada data volume kueri pada rentang waktu ini', w / 2, h / 2);
      var avgEl = document.getElementById('valAvgQueries');
      var peakEl = document.getElementById('valPeakQueries');
      if (avgEl) { avgEl.textContent = '0'; }
      if (peakEl) { peakEl.textContent = '0'; }
      return;
    }

    var max = 0;
    var sum = 0;
    series.forEach(function (s) {
      var c = parseInt(s.count, 10) || 0;
      sum += c;
      if (c > max) { max = c; }
    });
    if (max === 0) { max = 1; }

    var avg = Math.round(sum / series.length);
    var avgEl = document.getElementById('valAvgQueries');
    var peakEl = document.getElementById('valPeakQueries');
    if (avgEl) { avgEl.textContent = formatNumber(avg) + ' queries'; }
    if (peakEl) { peakEl.textContent = formatNumber(max) + ' queries'; }

    var paddingLeft = 50;
    var paddingBottom = 32;
    var paddingTop = 20;
    var chartW = w - paddingLeft - 20;
    var chartH = h - paddingBottom - paddingTop;

    // Draw horizontal grid lines & labels
    ctx.strokeStyle = '#e2e8f0';
    ctx.lineWidth = 1;
    ctx.setLineDash([4, 4]);

    for (var i = 0; i <= 4; i++) {
      var y = paddingTop + (chartH / 4) * i;
      ctx.beginPath();
      ctx.moveTo(paddingLeft, y);
      ctx.lineTo(w - 16, y);
      ctx.stroke();

      var val = Math.round(max - (max / 4) * i);
      ctx.fillStyle = '#64748b';
      ctx.font = '11px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
      ctx.textAlign = 'right';
      ctx.fillText(formatNumber(val), paddingLeft - 8, y + 4);
    }
    ctx.setLineDash([]);

    // Calculate bar positions
    var n = series.length;
    var slotW = chartW / n;
    var barWidth = Math.max(4, Math.min(28, slotW * 0.65));

    // Draw Gradient Bars
    series.forEach(function (s, idx) {
      var c = parseInt(s.count, 10) || 0;
      var barH = Math.max(3, (c / max) * chartH);
      var x = paddingLeft + (idx * slotW) + (slotW - barWidth) / 2;
      var y = paddingTop + (chartH - barH);

      var grad = ctx.createLinearGradient(0, y, 0, paddingTop + chartH);
      grad.addColorStop(0, '#2563eb');
      grad.addColorStop(1, '#93c5fd');

      ctx.fillStyle = grad;
      ctx.beginPath();
      if (ctx.roundRect) {
        ctx.roundRect(x, y, barWidth, barH, [4, 4, 0, 0]);
      } else {
        ctx.rect(x, y, barWidth, barH);
      }
      ctx.fill();

      // Timestamp labels (show 4 to 6 evenly spaced labels)
      var step = Math.max(1, Math.ceil(n / 6));
      if (idx % step === 0 || idx === n - 1) {
        var dt = s.dimensions && s.dimensions.datetime ? s.dimensions.datetime : '';
        var lbl = '';
        if (dt) {
          var d = new Date(dt);
          lbl = ('0' + (d.getMonth() + 1)).slice(-2) + '/' + ('0' + d.getDate()).slice(-2) + ' ' + ('0' + d.getHours()).slice(-2) + ':00';
        }
        ctx.fillStyle = '#64748b';
        ctx.font = '10.5px sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText(lbl, x + barWidth / 2, h - 10);
      }
    });
  }

  /* Canvas Donut Chart & Detailed Breakdown List */
  function drawTypePieChart(canvasId, items) {
    var canvas = document.getElementById(canvasId);
    if (!canvas) { return; }
    var ctx = canvas.getContext('2d');
    var w = canvas.offsetWidth || 400;
    var h = 280;
    canvas.width = w * window.devicePixelRatio || w;
    canvas.height = h * window.devicePixelRatio || h;
    ctx.scale(window.devicePixelRatio || 1, window.devicePixelRatio || 1);

    ctx.clearRect(0, 0, w, h);

    var listContainer = document.getElementById('chartTypeBreakdownList');

    if (!items || !items.length) {
      ctx.fillStyle = '#94a3b8';
      ctx.font = '14px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('Belum ada data tipe record', w / 2, h / 2);
      if (listContainer) {
        listContainer.innerHTML = '<div style="text-align:center; padding:12px; color:var(--dns-gray-400); font-size:13px;">Tidak ada kueri tercatat.</div>';
      }
      return;
    }

    var total = 0;
    items.forEach(function (it) { total += (parseInt(it.count, 10) || 0); });
    if (total === 0) { total = 1; }

    var colors = ['#2563eb', '#10b981', '#f59e0b', '#8b5cf6', '#ec4899', '#06b6d4', '#64748b', '#e11d48'];
    var cx = w / 2;
    var cy = (h / 2) - 10;
    var radius = Math.min(85, (h / 2) - 25);
    var innerRadius = radius * 0.62;

    var startAngle = -Math.PI / 2;

    items.forEach(function (it, idx) {
      var cnt = parseInt(it.count, 10) || 0;
      var slice = (cnt / total) * 2 * Math.PI;
      var endAngle = startAngle + slice;
      var color = colors[idx % colors.length];

      ctx.fillStyle = color;
      ctx.beginPath();
      ctx.arc(cx, cy, radius, startAngle, endAngle);
      ctx.arc(cx, cy, innerRadius, endAngle, startAngle, true);
      ctx.closePath();
      ctx.fill();

      // subtle separator border
      ctx.strokeStyle = '#ffffff';
      ctx.lineWidth = 2;
      ctx.stroke();

      startAngle = endAngle;
    });

    // Donut Center Text
    ctx.fillStyle = '#0f172a';
    ctx.font = '700 18px sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText(formatNumber(total), cx, cy + 2);

    ctx.fillStyle = '#64748b';
    ctx.font = '11px sans-serif';
    ctx.fillText('Total Kueri', cx, cy + 18);

    // Populate Detailed Breakdown List under the chart
    if (listContainer) {
      var html = '';
      items.forEach(function (it, idx) {
        var color = colors[idx % colors.length];
        var name = (it.dimensions && it.dimensions.queryType) ? it.dimensions.queryType : 'Unknown';
        var cnt = parseInt(it.count, 10) || 0;
        var pct = ((cnt / total) * 100).toFixed(1);

        html += '<div class="dns-type-item">' +
          '<div class="dns-type-item-name">' +
            '<span class="dns-type-item-dot" style="background:' + color + ';"></span>' +
            '<span>Record <strong>' + escapeHtml(name) + '</strong></span>' +
          '</div>' +
          '<div class="dns-type-item-stats">' +
            '<span><strong>' + formatNumber(cnt) + '</strong> kueri</span>' +
            '<span class="dns-badge dns-badge-blue" style="font-size:11.5px; padding:2px 8px;">' + pct + '%</span>' +
          '</div>' +
        '</div>';
      });
      listContainer.innerHTML = html;
    }
  }
})();
{/literal}
</script>
