# 🏗️ Rental Manager

A Flutter Android application for managing rentals of any item type, including inventory, customers, invoicing, and payments — all in one place.

---

## ✨ Features

### 📊 Dashboard & Analytics
- High-level stats: total inventory items, active rental lines, total customers, and returned lines.
- Automatically flags overdue rentals based on a configurable threshold (default: 30 days).
- Quick action buttons for fast access to New Order, Payment Ledger, Business Info, Invoices, and Customers.
- Pull-to-refresh support.

### 📦 Inventory Management
- Add, edit, and delete any rentable items.
- Categorize items (defaults to `General`) with optional notes per item.
- Real-time stock levels: **Total / Out / Free** displayed as color-coded chips.
- Category filter chips for quick browsing.
- Search bar with debounced filtering.
- Stock validation prevents over-renting (cannot rent more than available).

### 🤝 Rentals & Orders (Group Rentals)
- Create orders containing one or multiple items in a single flow.
- Link orders to a saved customer (auto-fills name, phone, address) or use walk-in details.
- Record advance deposits, daily rental rates, quantities, checkout dates, and order notes.
- Supports **two phone numbers** (primary + alternate) per rental.
- **Full Return** — mark all remaining items as returned with a date picker (today or custom).
- **Partial Return** — specify exact quantities per item to return independently.
- **Edit Order** — update contractor name, phones, site address, advance, checkout date, payment method, and notes for an entire group at once.
- Active rentals display live cost calculation, advance paid, remaining balance, and overdue warning.

### 💰 Payment Ledger
- Dedicated screen showing all returned-but-unsettled invoices.
- Filter by **All**, **Amount Due** (customer owes you), or **Refund Due** (you owe customer).
- Record full or partial payments with amount + payment method.
- Record full or partial refunds.
- Marks invoices as fully settled once the balance is cleared.
- Balance due/refund displayed in color-coded totals (orange = owed, green = refund).

### 📜 History
- All fully-returned rental groups with **PAID** badge for settled invoices.
- Sort by: **Date (Newest)**, **Date (Oldest)**, or **Highest Balance**.
- Sort indicator dot appears on the filter icon when a non-default sort is active.
- Delete individual invoice history records permanently.

### 🏢 Business & Customer Management
- **Business Info:** Store business name, primary phone, alternate phone, email, address, UPI ID, and UPI account name — auto-populated on every invoice.
- **Customers:** Full directory with name, primary/alternate phone, email, address, and notes. Each customer card shows an **"Owes ₹X"** balance badge if they have unsettled invoices. Auto-fills the New Order form.
- Search support for both customers and inventory.

### 🧾 Invoicing & PDF
- Generate PDF receipts for any order using stored business info and rental details.
- Choose paper size: **57mm Thermal Receipt** or **A4**.
- PDF includes: business header, customer billing info, item table with qty and rate, total paid, signature lines (customer + vendor).
- **UPI QR code** embedded at the bottom of invoices when a UPI ID is configured.
- Preview invoices in-app or share as PDF via installed share targets.
- Roboto font used for full Unicode currency symbol support.

### ⚙️ Settings
**Appearance**
- Theme: Light, Dark, or System Default (cycles on tap).
- Card Density: Comfortable or Compact (adjusts padding across all cards).
- Font Size: Small (90%), Medium (100%), or Large (115%) — applied globally via `TextScaler`.

**Business**
- Currency Symbol: Quick-pick from ₹, $, €, £, ¥, ฿ — or type any custom symbol (up to 4 chars). Applied everywhere in the UI and PDFs.
- Overdue Threshold: Configurable number of days before a rental is flagged as overdue.

**Notifications** *(fires at most once per day per category)*
- ⚠️ Overdue Rental Alert — when rentals exceed the configured threshold.
- 💰 Pending Payment Reminder — unsettled returned invoices with balance due.
- 📊 Daily Summary — active rental count + total pending collections.
- ↩️ Refund Wait Alert — customers waiting for a refund.
- 📅 Rental Anniversary — milestone alerts at 7, 14, 30, 60, and 90 days.

**Backup & Data**
- Auto-Backup Schedule selector: Off / Daily / Weekly / Monthly *(UI ready; background scheduling in a future update)*.
- Manual export/restore available via the drawer menu.

**Regional**
- Language: English / हिंदी *(more coming soon)*.

### 💾 Backup & Restore
- **Export:** Save the full `siteyard_v3.db` SQLite database to any folder on the device via a system file picker.
- **Restore:** Pick a previously exported backup file to replace the current database. Restart required after restore.

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) — Material 3 |
| Database | SQLite via `sqflite` (v2.3.3) |
| PDF Generation | `pdf` (v3.11.1) |
| PDF Preview & Share | `printing` (v5.13.2) |
| File Picking | `file_picker` (v8.1.2) |
| Storage Paths | `path_provider` (v2.1.4) |
| Notifications | `flutter_local_notifications` (v17.2.4) |
| Persistence | `shared_preferences` (v2.3.2) |
| Fonts | Local asset fonts (`assets/fonts/Roboto-*.ttf`) |

---

## 🗄️ Database Schema (v17)

| Table | Key Columns |
|---|---|
| `items` | `id`, `name`, `category`, `total`, `rented`, `notes` |
| `rentals` | `id`, `itemId`, `orderId`, `contractor`, `phone`, `phone2`, `address`, `advanceDeposit`, `qty`, `checkoutDate`, `rentalRate`, `returned`, `returnDate`, `notes`, `isSettled`, `paymentMethod` |
| `customers` | `id`, `name`, `phone`, `phone2`, `email`, `address`, `notes` |
| `orders` | `id`, `customerId`, `customerName`, `createdDate` |
| `business_info` | `id`, `name`, `phone`, `phone2`, `email`, `address`, `upiId`, `upiName` |

Migration path: v11 → v12 → v13 (indexes) → v14 (`paymentMethod`) → v15 (`rentals.phone2`) → v16 (`customers.joinedDate`, `customers.isBlacklisted`) → v17 (`payment_logs`)

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK `>=3.3.0 <4.0.0`
- Android Studio with Android SDK installed
- Java 17 (bundled with Android Studio)

### Setup
```bash
# Clone the repository
git clone <your-repo-url>
cd rental_manager

# Install dependencies
flutter pub get

# Run on connected device or emulator
flutter run
```

### Build APK
```bash
# Single release APK
flutter build apk --release

# Split by architecture (smaller file sizes)
flutter build apk --split-per-abi
```

---

## 🗂️ Project Structure

```
lib/
└── main.dart                        # Single-file architecture
    ├── ThemeModeNotifier            # Light / Dark / System theme state
    ├── AppSettingsNotifier          # Currency, density, font, overdue days, notifications
    ├── NotificationService          # Local notification scheduling & checks
    ├── DatabaseHelper               # SQLite DB (v17), migrations, all data access
    ├── RentalGroup / groupRentalsByInvoice()  # Core grouping model
    ├── MainShell                    # Bottom nav scaffold + drawer
    ├── DashboardScreen              # Stats, overdue alerts, quick actions
    ├── InventoryTab                 # Item list, add/edit/delete, stock chips
    ├── ActiveRentalsTab             # Active rentals grouped by order, return/edit
    ├── HistoryTab                   # Returned rental history, sort, delete
    ├── PaymentLedgerScreen          # Pending collections and refunds
    ├── BusinessInfoScreen           # Business profile for invoices
    ├── CustomersManagementScreen    # Customer directory with balance badges
    ├── NewOrderScreen               # Order creation with collapsible details form
    ├── OrdersListScreen             # Orders list with PDF preview and share
    ├── OrderDetailsScreen           # Per-order item breakdown
    └── SettingsScreen               # Appearance, business, notifications, backup, regional
```

---

## 🔒 Permissions (Android)

Add the following to `AndroidManifest.xml` for file picking and database backup/restore:

```xml
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"/>
```

Notification permission is requested at runtime on Android 13+ via `flutter_local_notifications`.
