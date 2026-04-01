# Rental Manager

Offline-first Flutter Android app to manage rentals of any item type.  
It handles inventory, customers, orders, proforma, final invoices, payment ledger, and payment history in one place.

## License

Rental Manager is free software licensed under the
GNU General Public License v3.0 or later.

See [LICENSE](LICENSE) for full details.

## What The App Does

- Tracks inventory stock (`Total`, `Out`, `Free`) with category and search support.
- Creates multi-item rental orders tied to a saved customer or walk-in details.
- Supports full return and partial return workflows.
- Generates two PDF types:
- `Proforma`: estimated rental summary.
- `Invoice`: final bill with return details and totals.
- Tracks pending collections and refunds in Payment Ledger.
- Stores every payment/refund event in Payment History.
- Works offline using local SQLite + local asset fonts for PDF rendering.

## Features

### Dashboard
- Summary stats for inventory, rentals, customers, and returned lines.
- Overdue rental visibility based on configurable overdue days.
- Top 5 customers by revenue (can be turned on/off in Settings).
- Quick actions for common pages.

### Inventory
- Add, edit, delete items.
- Category + notes support.
- Search and category filtering.
- Stock validation prevents over-renting.

### Active Rentals
- Grouped by invoice/order identity.
- Live calculation for billed amount, paid amount, and balance.
- Full return and partial return with return date capture.
- Group edit support (customer details, rates, notes, etc.).

### Proforma
- Page name is `Proforma` in app menu.
- Shows estimated rental information (item, qty, rate/day, etc.).
- Includes customer/vendor signature lines in generated PDF.

### Invoice
- Separate `Invoice` page for fully returned groups.
- Final invoice PDF includes full billing overview and return info.
- Keeps the same identity number as its order/proforma (`#` value stays consistent).

### Payment Ledger
- Shows returned but unsettled invoices.
- Filter options for due/refund states.
- Records partial/full payments and refunds.
- Marks invoice settled when balance reaches zero.

### Payment History
- Dedicated page for logged payment/refund events.
- Can open globally or scoped to one invoice from History card button.
- Time display can be toggled and formatted as 12-hour or 24-hour in Settings.

### Customers And Business Info
- Customer directory with search and profile details.
- Customer profile shows rental history and lifetime stats.
- Business info is stored and used in PDFs.
- Tax profile can be configured (`No Tax`, `GST`, `VAT`, `Sales Tax`, `Consumption Tax`) with inclusive/exclusive mode and tax registration number.
- UPI details can be included in PDF with QR code.

### Settings
- Theme mode, card density, and font scale.
- Currency symbol selection.
- Locale-aware number grouping for money values.
- Overdue-days threshold.
- Date format selector (`dd/MMM/yyyy`, `dd/MM/yyyy`, `MM/dd/yyyy`, `yyyy-MM-dd`).
- Time format selector (12-hour or 24-hour).
- Language selector (English/Hindi).
- Notification toggles.
- Top customers on/off toggle.
- Payment History time stamp toggle.
- Privacy & Data information dialog.

### Backup And Restore
- Manual export of local DB backup file.
- Manual restore from previous backup file.

## Tech Stack

| Layer         | Technology                                |
|---------------|-------------------------------------------|
| Framework     | Flutter (Dart), Material 3                |
| Database      | SQLite via `sqflite`                      |
| PDF           | `pdf` + `printing`                        |
| Local Storage | `shared_preferences`                      |
| Notifications | `flutter_local_notifications`             |
| File Picking  | `file_picker`                             |
| Paths         | `path_provider`                           |
| Fonts         | Local assets: `assets/fonts/Roboto-*.ttf` |


## Database Architecture
- Main local file: `siteyard_v3.db`
- Current schema version in app: `v21`
- Includes `payment_logs` table for Payment History events.
- Upgraded to support advanced tracking (`discount`, `penaltyFee`, and `badDebt`).

## Android Permissions (Current Behavior)

- Release build removes network permissions (`INTERNET`, `ACCESS_NETWORK_STATE`) to enforce offline production behavior.
- Debug/profile builds keep localhost internet access for Flutter run/debug tooling.
- Notifications are used for local reminders.
- Storage/file access is handled through system file pickers for backup/restore.

## Getting Started

```bash
git clone [https://gitlab.com/wjust4435/rental_manager.git](https://gitlab.com/wjust4435/rental_manager.git)
cd rental_manager
flutter clean
flutter pub get
flutter run

flutter build apk --release