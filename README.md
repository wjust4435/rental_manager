# Rental Manager

Offline-first Flutter Android app to manage rentals of any item type.  
It handles inventory, customers, orders, proforma, final invoices, payment ledger, payment history, and bad debt tracking in one place.

## License

Rental Manager is free software licensed under the
GNU General Public License v3.0 or later.

See [LICENSE](LICENSE) for full details.

## What The App Does

- Tracks inventory stock (`Total`, `Out`, `Free`) with category and search support.
- Creates multi-item rental orders tied to a saved customer or walk-in details.
- Supports full return and advanced partial return workflows (including damage/penalty fees).
- Generates two PDF types (supports both A4 and 57mm Thermal Receipt sizes):
  - `Proforma`: estimated rental summary.
  - `Invoice`: final bill with return details, applied discounts, and totals.
- Tracks pending collections, refunds, and bad debt in the Payment Ledger.
- Stores every payment/refund event with exact timestamps in Payment History.
- Works entirely offline using local SQLite + local asset fonts for PDF rendering.

### Dashboard
- Summary stats for inventory, rentals, customers, and returned lines.
- Overdue rental visibility based on configurable overdue days.
- Top 5 customers by revenue (can be toggled in Settings).
- Quick actions for common pages.
- Live tracking of outstanding pending collections.

### Inventory
- Add, edit, delete items.
- Category grouping + notes support.
- Search and category filtering.
- Strict stock validation prevents over-renting.

### Active Rentals
- Grouped by invoice/order identity.
- Live calculation for billed amount, paid amount, and balance.
- Advanced Return Actions:
  - **Full Return:** Marks all items returned on a selected date.
  - **Partial Return:** Specify exactly how many items were returned in good condition, how many were damaged/lost, and apply specific penalty fees.
- Edit/Delete workflows for maintaining clean records.

### Proforma
- Shows estimated rental information (item, qty, rate/day, etc.).
- Includes customer/vendor signature lines in generated PDF.
- PDF generation supports A4 standard and 57mm thermal printers.

### Invoice
- Final invoice PDF includes full billing overview, exact return dates, and applied discounts.
- Keeps the same identity number as its order/proforma (`#` value stays consistent).
- Support for inclusive/exclusive tax rendering and UPI QR code generation.

### Payment Ledger
- Shows returned but unsettled invoices.
- Filter options for due/refund states.
- Records partial/full payments, refunds, and custom discounts (flat or percentage).
- Ability to write off uncollectible balances directly to Bad Debt.
- Marks invoice settled when balance reaches zero.

### Payment History
- Dedicated page for logged payment/refund events.
- Optimized tag layout for high visibility of payment methods and states.
- Can open globally or be scoped to a single invoice from the History card button.
- Time display can be toggled and formatted as 12-hour or 24-hour.

### Losses & Bad Debt (New)
- Dedicated tracking for invoices written off due to non-payment.
- Features a "Recover Funds" workflow to log payments if an absconded customer later settles their bill.

### Customers And Business Info
- Customer directory with search and profile details.
- Customer profile shows deep rental history, lifetime spend, active rentals, and lifetime bad debt.
- Ability to flag problematic clients with a "Blacklisted" tag.
- Tax profile configuration (`No Tax`, `GST`, `VAT`, `Sales Tax`, `Consumption Tax`) with inclusive/exclusive modes.

### Settings
- UI Customization: Theme mode, Card Density, and Font Scale.
- App Icon Customization: Dynamically switch the Android launcher icon.
- Locale-aware number grouping and custom currency symbol input.
- Date/Time formatting and Language selector (English/Hindi).
- Granular Notification toggles (Overdue, Pending, Refunds, Anniversaries).
- Privacy & Data information dialog.

### Backup And Restore
- Manual export of local DB backup file (`siteyard_v3.db`).
- Manual restore from previous backup files for total data ownership.

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
- Current schema version in app: `v23`
- Includes `payment_logs` table for precise auditing.
- Features optimized migration paths (legacy `<v20` migrations purged for faster initialization).
- Supports advanced tracking models: `discount`, `penaltyFee`, `badDebt`, and `isCancelled`.

## Android Permissions (Current Behavior)

- Release build removes network permissions (`INTERNET`, `ACCESS_NETWORK_STATE`) to strictly enforce offline production behavior.
- `POST_NOTIFICATIONS` is requested to drive local reminder digests.
- Storage/file access is securely handled through native system file pickers for backup/restore operations.

## Getting Started

```bash
git clone [https://gitlab.com/wjust4435/rental_manager.git](https://gitlab.com/wjust4435/rental_manager.git)
cd rental_manager
flutter clean
flutter pub get
flutter run

flutter build apk --release --split-per-abi