# Rental Manager

Offline-first Flutter Android app to manage rentals of any item type.  
It handles inventory, customers, orders, proforma, final invoices, payment ledger, and payment history in one place.

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
- Time display supports AM/PM and can be toggled in Settings.

### Customers And Business Info
- Customer directory with search and profile details.
- Customer profile shows rental history and lifetime stats.
- Business info is stored and used in PDFs.
- UPI details can be included in PDF with QR code.

### Settings
- Theme mode, card density, and font scale.
- Currency symbol selection.
- Overdue-days threshold.
- Notification toggles.
- Top customers on/off toggle.
- Payment History time stamp toggle.

### Backup And Restore
- Export local DB backup file.
- Restore from previous backup file.

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart), Material 3 |
| Database | SQLite via `sqflite` |
| PDF | `pdf` + `printing` |
| Local Storage | `shared_preferences` |
| Notifications | `flutter_local_notifications` |
| File Picking | `file_picker` |
| Paths | `path_provider` |
| Fonts | Local assets: `assets/fonts/Roboto-*.ttf` |

## Database

- Main local file: `siteyard_v3.db`
- Current schema version in app: `v17`
- Includes `payment_logs` table for Payment History events.

## Android Permissions (Current Behavior)

- Network permissions are explicitly removed in manifests (`INTERNET`, `ACCESS_NETWORK_STATE`).
- Notifications are used for local reminders.
- Storage/file access is handled through system file pickers for backup/restore.

## Getting Started

```bash
git clone https://gitlab.com/wjust44351/rental_manager.git
cd rental_manager
flutter clean
flutter pub get
flutter run
```

## Build

```bash
flutter build apk --release
```

## License

MIT (see `LICENSE` file).
