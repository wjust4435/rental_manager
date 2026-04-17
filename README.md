# Rental Manager

Offline-first Flutter app for rental businesses to manage inventory, customer orders, returns, invoices, payments, and bad debt from a local SQLite database.

## License

Rental Manager is licensed under the GNU General Public License v3.0 or later.  
See [LICENSE](LICENSE).

## Current App Scope

- Platform target: Android-first Flutter app (offline operation).
- Version: `2.6.0`
- Local database: `siteyard_v3.db`
- Database schema version in app: `v26`

## Key Features

### Dashboard

- Inventory/rental/customer stats at a glance.
- Overdue rental visibility based on configurable overdue days.
- Pending collection total (unsettled returned invoices).
- Optional top customers by revenue.
- Quick actions to core screens.

### Inventory

- Add/edit/delete inventory items.
- Category and search filtering.
- Availability checks to prevent over-renting.
- Tracks rented quantity and lost/damaged quantity.

### Rentals Workflow

- Create multi-item rental orders for saved customers or walk-ins.
- Full return and partial return support.
- Partial return can capture:
  - good returned quantity
  - damaged/lost quantity
  - penalty fee
- Invoice grouping by order ID (or fallback rental ID for standalone records).

### Transactions (Unified Screen)

- One Transactions page with 2 tabs:
  - `OUTSTANDING` (ledger)
  - `HISTORY` (payment/refund logs)
- Supports scoped navigation from Rental History/Customer Profile:
  - Opens directly for a specific invoice/group.
- Outstanding search supports customer fields and invoice-style input (`15`, `#15`, `INV#15`, `Invoice 15`).

### Payment Ledger (Outstanding)

- Shows returned but unsettled groups by default.
- Filter modes:
  - `All`
  - `Amount Due`
  - `Refund Due`
- Record partial/full payment, refund, discount, and bad debt write-off.
- Auto-settle group when fully cleared.

### Payment History

- Full payment/refund log with method and timestamp.
- Global or scoped-by-invoice view.
- Search and type filters (`All`, `Payment`, `Refund`).

### Losses & Bad Debt

- Dedicated list of written-off groups.
- Recover funds workflow to log recovered money and reduce bad debt.

### Invoices & PDFs

- Unified `Proforma & Invoice` section with tabs:
  - `PROFORMA`
  - `FINAL INVOICE`
- PDF output supports:
  - A4
  - 57mm thermal format
- Tax modes:
  - No Tax
  - GST
  - VAT
  - Sales Tax
  - Consumption Tax
  - Inclusive/Exclusive calculation
- Includes UPI QR details (when configured).

### Customers

- Customer directory with search.
- Customer profile includes:
  - lifetime stats
  - rental history
  - outstanding/refund visibility
  - bad debt visibility
- Blacklist flag support.
- Direct dial action for saved phone numbers.

### Settings

- Theme mode (light/dark/system).
- App icon switcher.
- Card density and font size.
- Currency symbol, date format, and time format.
- Payment history timestamp visibility toggle.
- Notifications toggles:
  - Overdue Rental Alert
  - Pending Payment Reminder
  - Daily Summary
- PDF signatures toggle.
- Privacy & data info panel.

### Backup & Restore

- Export local DB backup through file picker.
- Restore from backup through file picker.
- No cloud dependency required.

## Offline & Permissions

- Main app manifest requests:
  - `POST_NOTIFICATIONS`
  - `VIBRATE`
- Release manifest explicitly removes network permissions:
  - `INTERNET`
  - `ACCESS_NETWORK_STATE`
- Data is stored locally unless user explicitly exports/restores files.

## Tech Stack

| Layer              | Technology                      |
|--------------------|---------------------------------|
| Framework          | Flutter (Dart)                  |
| Database           | SQLite via `sqflite`            |
| Local storage      | `shared_preferences`            |
| PDF/print/share    | `pdf`, `printing`, `share_plus` |
| File import/export | `file_picker`, `path_provider`  |
| Notifications      | `flutter_local_notifications`   |
| Charts             | `fl_chart`                      |
| Device actions     | `url_launcher`                  |

## Getting Started

```bash
git clone https://gitlab.com/wjust4435/rental_manager.git
cd rental_manager
flutter clean
flutter pub get
flutter run
```

Release build:

```bash
flutter build apk --release --split-per-abi
```

