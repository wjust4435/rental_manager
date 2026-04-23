# Rental Manager

**Professional offline-first rental management system for Android**

Comprehensive Flutter application for rental businesses to manage inventory, customers, orders, invoices, payments, and financial reporting—all from a local SQLite database with zero internet dependency.

## License

GNU General Public License v3.0 or later (GPL-3.0-or-later). See [LICENSE](LICENSE).

---

## Current Version

- **App Version:** `2.8.4`
- **Database Schema:** `v36`
- **Platform:** Android (Flutter)
- **Database File:** `rental_manager_v1.db`

---

## Core Philosophy

- **100% Offline** – No internet required, complete data privacy
- **Multi-Business Support** – Manage multiple rental accounts
- **CPA-Compliant Financials** – Professional accounting standards
- **Professional Invoicing** – A4 and 57mm thermal PDF formats

---

## Key Features

### 📊 Dashboard
Real-time metrics: inventory, active rentals, overdue alerts, pending collections, revenue stats, Top 5 customers by revenue.

### 🏢 Multi-Business Management
Account switcher, separate databases per business, tax configuration (GST/VAT/Sales Tax), UPI QR code generation, fiscal year setup.

### 📦 Inventory
Item tracking with categories, supplier linking, availability checks, depreciation tracking, maintenance logs, search & filter.

### 👥 Customers & Parties
Customer profiles, supplier management, blacklist flags, lifetime statistics, risk alerts (bad debt warnings), direct phone dialing.

### 🛒 Rental Orders
Multi-item orders, walk-in or saved customers, full/partial returns, damaged/lost tracking, penalty fees, order cancellation, automatic inventory restoration.

### 💰 Transactions
**Outstanding Tab:** Payment ledger with filters (All/Amount Due/Refund Due), smart invoice search, payment recording, discounts, bad debt write-offs.  
**Payment History Tab:** Complete transaction log, payment method tracking, timestamp display, search & filter.

### 📋 Purchase Orders
Supplier POs, multi-item support, payment tracking, vendor payment logs, inventory integration, PO cancellation.

### 📈 Financial Reports
- **P&L Statement:** Gross revenue, EBITDA, depreciation, bad debt, net profit (CPA-compliant)
- **A/R Aging Report:** Receivables by aging buckets (Current, 1-30, 31-60, 61-90, 90+ days)
- **Tax Liability:** Fiscal year tax tracking, collected tax, taxable income
- **Inventory Valuation:** Acquisition cost, book value, accumulated depreciation

### 💸 Expense Tracking
Operating expenses with categories, payment methods, vendor association, receipt attachments, affects P&L calculations.

### 📉 Bad Debt Management
Write-off tracking, recovery workflow, dedicated losses screen, customer lifetime stats integration.

### 📄 Professional Invoicing
**Proforma Invoices:** Pre-rental estimates with optional signatures.  
**Final Invoices:** Post-return official invoices with auto-numbering, tax calculations, payment status, edit protection toggle.

**PDF Features:** A4/57mm thermal formats, tax modes (Exclusive/Inclusive), business branding, UPI QR codes, itemized breakdowns, preview/share/print.

### 🔔 Smart Notifications
Overdue rental alerts, pending payment reminders, daily summary digest (fires once per day max), individual toggles.

### ⚙️ Settings
**Appearance:** Light/Dark/System theme, 4 app icon variants, card density, font size (90%/100%/115%).  
**Business:** Currency symbol, overdue threshold, PDF signature toggles, invoice editing permissions.  
**Dashboard:** Top customers toggle, payment timestamp toggle.  
**Regional:** Date format, time format (12h/24h), language (English).

### 💾 Backup & Restore
Local database export/import via file picker, portable `.db` format, no cloud dependency, user-controlled data sovereignty.

---

## Technology Stack

| Component         | Technology                          |
|-------------------|-------------------------------------|
| Framework         | Flutter (Dart)                      |
| Database          | SQLite (`sqflite` v33 schema)       |
| PDF Generation    | `pdf`, `printing`                   |
| File Operations   | `file_picker`, `path_provider`      |
| Sharing           | `share_plus`                        |
| Notifications     | `flutter_local_notifications`       |
| Charts            | `fl_chart`                          |
| Preferences       | `shared_preferences`                |
| Device Actions    | `url_launcher`                      |

---

## Database Schema v33

**Core Tables:** `business_info`, `items`, `customers`, `suppliers`, `rentals`, `orders`, `payment_logs`, `purchase_orders`, `expenses`, `maintenance_logs`, `sequences`.

**v33 Enhancements:** Healing migration system, safe column addition, financial/tax columns, cancellation flags, invoice tracking, party classification.

---

## Getting Started

```bash
# Clone repository
git clone https://gitlab.com/wjust4435/rental_manager.git
cd rental_manager

# Install dependencies
flutter clean
flutter pub get

# Run app
flutter run
```

### Release Build

```bash
flutter build apk --release --split-per-abi
# Output: build/app/outputs/flutter-apk/
```

## Offline & Privacy

- **Zero Internet:** Release build removes `INTERNET` and `ACCESS_NETWORK_STATE` permissions
- **Local-Only Storage:** All data in SQLite on device
- **No Telemetry:** No external API calls or analytics
- **User Control:** Manual backup/restore only

---

## Credits

**Developed by:** wjust4435  
**Copyright:** © 2026 wjust4435  
**License:** GNU GPL v3.0 or later