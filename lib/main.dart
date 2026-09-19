//---------------------------------------------------------------------
// Rental Manager
// Copyright (C) 2026 wjust4435
// License: GNU General Public License v3.0 or later (GPL-3.0-or-later)
//---------------------------------------------------------------------

// =================================================
// I. CORE ARCHITECTURE
// =================================================

// ========Imports========
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// ========Rental Manager App========
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RentalManagerApp());
  unawaited(_initializeServicesInBackground());
}

Future<void> _initializeServicesInBackground() async {
  try {
    await DatabaseHelper.getBusinessInfo();
    await NotificationService.initialize();
  } catch (_) {
    // Keep app startup resilient even if a platform service init fails.
  }
}

// ========App Provider========
class AppProvider extends InheritedNotifier<AppSettingsNotifier> {
  const AppProvider({
    super.key,
    required AppSettingsNotifier super.notifier,
    required super.child,
  });

  static AppSettingsNotifier of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<AppProvider>();
    if (provider == null) throw Exception('AppProvider not found in context tree');
    return provider.notifier!;
  }
}

// ========Theme Mode Notifier========
class ThemeModeNotifier extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;
  SharedPreferences? _prefs;

  ThemeModeNotifier() { _load(); }

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> _load() async {
    final prefs = await _getPrefs();
    final saved = prefs.getString('themeMode') ?? 'dark';
    _mode = saved == 'light' ? ThemeMode.light : saved == 'dark' ? ThemeMode.dark : ThemeMode.system;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode m) async {
    _mode = m;
    notifyListeners();
    final prefs = await _getPrefs();
    final val   = m == ThemeMode.light ? 'light' : m == ThemeMode.dark ? 'dark' : 'system';
    await prefs.setString('themeMode', val);
  }
}

// ========App Settings Notifier========
class AppSettingsNotifier extends ChangeNotifier {
  String _currencySymbol     = '\u20B9';
  int    _overdueDays        = 30;
  String _cardDensity        = 'comfortable';
  String _fontSize           = 'medium';
  String _dateFormat         = 'dd/MMM/yyyy';
  String _timeFormat         = '12h';
  bool   _showTopCustomersByRevenue = false;
  bool   _showPaymentHistoryTime = true;
  bool   _showProformaSignatures = true;
  bool   _showInvoiceSignatures  = false;
  bool   _notifyOverdue      = true;
  bool   _notifyPendingPayments = true;
  bool   _notifySummary      = false;
  String _language           = 'English';
  String _appIcon            = 'icon2';
  bool   _allowFinalInvoiceEditing = true;
  List<String> _quickActions = ['New Order', 'Ledgers', 'Biz Info', 'Proforma', 'Invoice', 'Parties'];

  SharedPreferences? _prefs;

  String get currencySymbol      => _currencySymbol;
  String get appIcon             => _appIcon;
  int    get overdueDays         => _overdueDays;
  String get cardDensity         => _cardDensity;
  String get fontSize            => _fontSize;
  String get dateFormat          => _dateFormat;
  String get timeFormat          => _timeFormat;
  bool   get showTopCustomersByRevenue => _showTopCustomersByRevenue;
  bool   get showPaymentHistoryTime => _showPaymentHistoryTime;
  bool   get showProformaSignatures => _showProformaSignatures;
  bool   get showInvoiceSignatures  => _showInvoiceSignatures;
  bool   get notifyOverdue       => _notifyOverdue;
  bool   get notifyPendingPayments => _notifyPendingPayments;
  bool   get notifySummary       => _notifySummary;
  String get language            => _language;
  bool   get allowFinalInvoiceEditing => _allowFinalInvoiceEditing;
  List<String> get quickActions  => _quickActions;

  double get textScale {
    if (_fontSize == 'small') return 0.9;
    if (_fontSize == 'large') return 1.15;
    return 1.0;
  }

  EdgeInsets get cardPadding {
    return EdgeInsets.all(_cardDensity == 'compact' ? 8.0 : 12.0);
  }

  AppSettingsNotifier() {
    _load();
  }

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> _load() async {
    final p = await _getPrefs();
    _currencySymbol            = p.getString('currencySymbol')            ?? '\u20B9';
    _overdueDays               = p.getInt('overdueDays')                  ?? 30;
    _cardDensity               = p.getString('cardDensity')               ?? 'comfortable';
    _fontSize                  = p.getString('fontSize')                  ?? 'medium';
    _dateFormat                = p.getString('dateFormat')                ?? 'dd/MMM/yyyy';
    _timeFormat                = p.getString('timeFormat')                ?? '12h';
    _showTopCustomersByRevenue = p.getBool('showTopCustomersByRevenue')   ?? false;
    _showPaymentHistoryTime    = p.getBool('showPaymentHistoryTime')      ?? true;
    _showProformaSignatures    = p.getBool('showProformaSignatures')      ?? p.getBool('showPdfSignatures') ?? true;
    _showInvoiceSignatures     = p.getBool('showInvoiceSignatures')       ?? p.getBool('showPdfSignatures') ?? false;
    _notifyOverdue             = p.getBool('notifyOverdue')               ?? true;
    _notifyPendingPayments     = p.getBool('notifyPendingPayments')       ?? true;
    _notifySummary             = p.getBool('notifySummary')               ?? false;
    _language                  = p.getString('language')                  ?? 'English';
    String savedIcon           = p.getString('appIcon')                   ?? 'icon2';
    _appIcon                   = savedIcon == 'default' ? 'icon2' : savedIcon;

    _allowFinalInvoiceEditing  = p.getBool('allowFinalInvoiceEditing')    ?? true;
    _quickActions              = p.getStringList('quickActions')          ?? ['New Order', 'Ledgers', 'Biz Info', 'Proforma', 'Invoice', 'Parties'];
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await _getPrefs();
    await p.setString('currencySymbol',      _currencySymbol);
    await p.setInt('overdueDays',            _overdueDays);
    await p.setString('cardDensity',         _cardDensity);
    await p.setString('fontSize',            _fontSize);
    await p.setString('dateFormat',          _dateFormat);
    await p.setString('timeFormat',          _timeFormat);
    await p.setBool('showTopCustomersByRevenue', _showTopCustomersByRevenue);
    await p.setBool('showPaymentHistoryTime', _showPaymentHistoryTime);
    await p.setBool('showProformaSignatures', _showProformaSignatures);
    await p.setBool('showInvoiceSignatures',  _showInvoiceSignatures);
    await p.setBool('notifyOverdue',         _notifyOverdue);
    await p.setBool('notifyPendingPayments', _notifyPendingPayments);
    await p.setBool('notifySummary',         _notifySummary);
    await p.setString('language',            _language);
    await p.setString('appIcon',             _appIcon);
    await p.setBool('allowFinalInvoiceEditing', _allowFinalInvoiceEditing);
  }

  Future<void> setCurrencySymbol(String v)      async { _currencySymbol = v; notifyListeners(); await _save(); }
  Future<void> setOverdueDays(int v)            async { _overdueDays = v.clamp(1, 999); notifyListeners(); await _save(); }
  Future<void> setCardDensity(String v)         async { _cardDensity = v; notifyListeners(); await _save(); }
  Future<void> setFontSize(String v)            async { _fontSize = v; notifyListeners(); await _save(); }
  Future<void> setDateFormat(String v)          async { _dateFormat = v; notifyListeners(); await _save(); }
  Future<void> setTimeFormat(String v)          async { _timeFormat = v; notifyListeners(); await _save(); }
  Future<void> setShowTopCustomersByRevenue(bool v) async { _showTopCustomersByRevenue = v; notifyListeners(); await _save(); }
  Future<void> setShowPaymentHistoryTime(bool v) async { _showPaymentHistoryTime = v; notifyListeners(); await _save(); }
  Future<void> setShowProformaSignatures(bool v) async { _showProformaSignatures = v; notifyListeners(); await _save(); }
  Future<void> setShowInvoiceSignatures(bool v)  async { _showInvoiceSignatures = v; notifyListeners(); await _save(); }
  Future<void> setNotifyOverdue(bool v)         async { _notifyOverdue = v; notifyListeners(); await _save(); }
  Future<void> setNotifyPendingPayments(bool v) async { _notifyPendingPayments = v; notifyListeners(); await _save(); }
  Future<void> setNotifySummary(bool v)         async { _notifySummary = v; notifyListeners(); await _save(); }
  Future<void> setLanguage(String v)            async { _language = v; notifyListeners(); await _save(); }
  Future<void> setAppIcon(String v)             async { _appIcon = v; notifyListeners(); await _save(); }
  Future<void> setAllowFinalInvoiceEditing(bool v) async { _allowFinalInvoiceEditing = v; notifyListeners(); await _save(); }
  Future<void> setQuickActions(List<String> actions) async { _quickActions = actions; notifyListeners(); await _save(); }
}

// ========Notification Service========
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static const String _channelId   = 'rental_manager_main';
  static const String _channelName = 'Rental Manager Alerts';

  static const int _idOverdue     = 1;
  static const int _idPending     = 2;
  static const int _idSummary     = 3;

  static Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));

    try {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      if (granted == false) {
        debugPrint('Notification permission denied by user');
      }
    } catch (e) {
      debugPrint('Failed to request notification permission: $e');
    }
  }

  static Future<void> checkAndNotify() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final s = appSettingsNotifier;

    if (!s.notifyOverdue && !s.notifyPendingPayments && !s.notifySummary) return;

    Future<bool> once(String key) async {
      if (prefs.getString('notif_$key') == today) return false;
      await prefs.setString('notif_$key', today);
      return true;
    }

    Future.microtask(() async {
      final needsGroups = (s.notifyPendingPayments && prefs.getString('notif_pending') != today) ||
          (s.notifySummary && prefs.getString('notif_summary') != today);

      List<RentalGroup> cachedGroups = [];
      if (needsGroups) {
        final allRaw = await DatabaseHelper.getAllRentals();
        cachedGroups = groupRentalsByInvoice(allRaw);
      }

      if (s.notifyOverdue && await once('overdue')) await _checkOverdue(s.overdueDays);
      if (s.notifyPendingPayments && await once('pending')) await _checkPendingPayments(cachedGroups);
      if (s.notifySummary && await once('summary')) await _checkSummary(s.overdueDays, cachedGroups);
    });
  }

  static Future<void> _checkOverdue(int days) async {
    final db     = await DatabaseHelper.getDatabase();
    final cutoff = DatabaseHelper.isoDate(DateTime.now().subtract(Duration(days: days)));
    final rows   = await db.rawQuery(
      'SELECT COUNT(*) as c FROM rentals WHERE (returned=0 OR returned IS NULL) AND checkoutDate<=?',
      [cutoff],
    );
    final count = rows.first['c'] as int? ?? 0;
    if (count == 0) return;
    await _show(
      _idOverdue,
      'Overdue Rentals',
      '$count rental${count > 1 ? 's are' : ' is'} overdue ($days+ days). Tap to review.',
    );
  }

  static Future<void> _checkPendingPayments(List<RentalGroup> groups) async {
    final pending = groups.where((g) => g.isFullyReturned && !g.isSettled && g.balance > 0).toList();
    if (pending.isEmpty) return;
    final total = pending.fold(0.0, (sum, g) => sum + g.balance);
    await _show(
      _idPending,
      'Payment Pending',
      '${pending.length} invoice${pending.length > 1 ? 's' : ''} unpaid - total due: ${formatMoney(total, decimals: 0)}.',
    );
  }

  static Future<void> _checkSummary(int overdueDays, List<RentalGroup> groups) async {
    final stats  = await DatabaseHelper.getDashboardStats(overdueDays: overdueDays);
    final active = stats['activeRentals'] ?? 0;
    final pendingTotal = groups
        .where((g) => g.isFullyReturned && !g.isSettled && g.balance > 0)
        .fold(0.0, (sum, g) => sum + g.balance);
    await _show(
      _idSummary,
      'Daily Summary',
      '$active active rental${active != 1 ? 's' : ''}  |  Pending: ${formatMoney(pendingTotal, decimals: 0)}.',
    );
  }

  static Future<void> _show(int id, String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Rental manager alerts and reminders',
        importance: Importance.high,
        priority:   Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );
    await _plugin.show(id, title, body, details);
  }
}

// =============================
// II. BUSINESS LOGIC LAYER (DATA + MODELS + UTILS)
// =============================

// ========Database Helper========
class DatabaseHelper {
  static const int _dbVersion = 37;
  static Database? _db;
  static String _activeDbFile = 'rental_manager_v1.db';

  // Financial Reversal Logic for Procurement
  static Future<void> deletePurchaseOrder(int poId) async {
    final db = await getDatabase();
    await db.transaction((txn) async {
      final items = await txn.query('purchase_order_items', where: 'poId = ?', whereArgs: [poId]);
      for (var item in items) {
        await txn.rawUpdate('UPDATE items SET total = MAX(0, total - ?) WHERE id = ?', [item['qty'], item['itemId']]);
      }
      await txn.delete('purchase_order_items', where: 'poId = ?', whereArgs: [poId]);
      await txn.delete('purchase_orders', where: 'id = ?', whereArgs: [poId]);
    });
  }

  static Future<void> cancelPurchaseOrder(int poId) async {
    final db = await getDatabase();
    await db.transaction((txn) async {
      final po = (await txn.query('purchase_orders', where: 'id = ?', whereArgs: [poId])).firstOrNull;
      if (po != null && (po['isCancelled'] as int? ?? 0) == 0) {
        final items = await txn.query('purchase_order_items', where: 'poId = ?', whereArgs: [poId]);
        for (var item in items) {
          await txn.rawUpdate('UPDATE items SET total = MAX(0, total - ?) WHERE id = ?', [item['qty'], item['itemId']]);
        }
        await txn.update('purchase_orders', {'isCancelled': 1}, where: 'id = ?', whereArgs: [poId]);
      }
    });
  }

  static Future<void> _ensureVendorPaymentLogsTableExists(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS vendor_payment_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        poId INTEGER NOT NULL,
        amount REAL NOT NULL,
        method TEXT NOT NULL,
        paidAt TEXT NOT NULL
      )
    ''');
  }

  static Future<List<Map<String, dynamic>>> getVendorPaymentHistory({String? poNumber}) async {
    final db = await getDatabase();
    await _ensureVendorPaymentLogsTableExists(db);

    String where = '';
    List<dynamic> args = [];
    if (poNumber != null && poNumber.isNotEmpty) {
      where = 'WHERE po.poNumber = ?';
      args.add(poNumber);
    }

    return await db.rawQuery('''
          SELECT v.*, po.poNumber, po.isCancelled, c.name as supplierName,
                 (SELECT MIN(id) FROM vendor_payment_logs v2 WHERE v2.poId = v.poId) AS firstLogId
          FROM vendor_payment_logs v
          JOIN purchase_orders po ON v.poId = po.id
          LEFT JOIN customers c ON po.supplierId = c.id
          $where
          ORDER BY v.paidAt DESC, v.id DESC
        ''', args);
  }

  static Future<void> closeDatabase() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }

  static Future<Database> getDatabase() async {
    if (_db != null) return _db!;
    final prefs = await SharedPreferences.getInstance();
    _activeDbFile = prefs.getString('active_db_file') ?? 'rental_manager_v1.db';
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$_activeDbFile';
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, v) async {
        await db.execute(
            "CREATE TABLE items(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, category TEXT DEFAULT 'General', total INTEGER NOT NULL DEFAULT 0, rented INTEGER DEFAULT 0, lostQty INTEGER DEFAULT 0, notes TEXT DEFAULT '', purchasePrice REAL DEFAULT 0, purchaseDate TEXT DEFAULT '', expectedLifeMonths INTEGER DEFAULT 0, supplierId INTEGER DEFAULT NULL)"
        );
        await db.execute(
            "CREATE TABLE rentals(id INTEGER PRIMARY KEY AUTOINCREMENT, itemId INTEGER, orderId INTEGER, customerId INTEGER, contractor TEXT, phone TEXT, phone2 TEXT DEFAULT '', address TEXT, advanceDeposit REAL DEFAULT 0, discount REAL DEFAULT 0, badDebt REAL DEFAULT 0, qty INTEGER, checkoutDate TEXT, rentalRate REAL DEFAULT 0, returned INTEGER DEFAULT 0, returnDate TEXT, notes TEXT DEFAULT '', isSettled INTEGER DEFAULT 0, paymentMethod TEXT DEFAULT '', penaltyFee REAL DEFAULT 0, damagedQty INTEGER DEFAULT 0, isCancelled INTEGER DEFAULT 0, invoiceNumber TEXT DEFAULT '', voidedAt TEXT DEFAULT '')"
        );
        await db.execute(
            "CREATE TABLE customers(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, phone TEXT, phone2 TEXT DEFAULT '', email TEXT DEFAULT '', address TEXT, notes TEXT DEFAULT '', joinedDate TEXT DEFAULT '', isBlacklisted INTEGER DEFAULT 0, partyType TEXT DEFAULT 'Customer', taxRegNo TEXT DEFAULT '')"
        );
        await db.execute(
            "CREATE TABLE orders(id INTEGER PRIMARY KEY AUTOINCREMENT, customerId INTEGER, customerName TEXT, createdDate TEXT, proformaNumber TEXT DEFAULT '', invoiceNumber TEXT DEFAULT '', voidedAt TEXT DEFAULT '', taxType TEXT DEFAULT 'none', taxRate REAL DEFAULT 0, taxMode TEXT DEFAULT 'exclusive', taxRegNo TEXT DEFAULT '')"
        );
        await db.execute(
            "CREATE TABLE payment_logs(id INTEGER PRIMARY KEY AUTOINCREMENT, orderId INTEGER, fallbackRentalId INTEGER, amount REAL NOT NULL, method TEXT DEFAULT '', paidAt TEXT DEFAULT '', isCleared INTEGER DEFAULT 0)"
        );
        await db.execute(
            "CREATE TABLE business_info(id INTEGER PRIMARY KEY, name TEXT DEFAULT '', phone TEXT DEFAULT '', phone2 TEXT DEFAULT '', email TEXT DEFAULT '', address TEXT DEFAULT '', upiId TEXT DEFAULT '', upiName TEXT DEFAULT '', taxProfile TEXT DEFAULT 'No Tax', taxType TEXT DEFAULT 'none', taxRate REAL DEFAULT 0, taxMode TEXT DEFAULT 'exclusive', taxRegNo TEXT DEFAULT '', fyStartMonth INTEGER DEFAULT 4)"
        );
        await db.execute(
            "CREATE TABLE sequences(seqKey TEXT PRIMARY KEY, seqValue INTEGER)"
        );
        await db.execute(
            "CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, category TEXT NOT NULL, amount REAL NOT NULL, paymentMethod TEXT, vendor TEXT, receiptPath TEXT, notes TEXT)"
        );
        await db.execute(
            "CREATE TABLE suppliers(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, phone TEXT, email TEXT, address TEXT, taxRegNo TEXT, notes TEXT, joinedDate TEXT)"
        );
        await db.execute(
            "CREATE TABLE purchase_orders(id INTEGER PRIMARY KEY AUTOINCREMENT, supplierId INTEGER, poNumber TEXT, billNumber TEXT DEFAULT '', orderDate TEXT, subtotal REAL DEFAULT 0, taxAmount REAL DEFAULT 0, grandTotal REAL DEFAULT 0, amountPaid REAL DEFAULT 0, notes TEXT, isCancelled INTEGER DEFAULT 0)"
        );
        await db.execute(
            "CREATE TABLE purchase_order_items(id INTEGER PRIMARY KEY AUTOINCREMENT, poId INTEGER, itemId INTEGER, qty INTEGER, unitCost REAL, lineTotal REAL)"
        );

        await db.insert('business_info', {
          'id': 1, 'name': '', 'phone': '', 'phone2': '', 'email': '', 'address': '', 'upiId': '', 'upiName': '', 'taxProfile': 'No Tax', 'taxType': 'none', 'taxRate': 0.0, 'taxMode': 'exclusive', 'taxRegNo': '', 'fyStartMonth': 4
        });
        await db.execute("CREATE INDEX IF NOT EXISTS idx_items_name ON items(name)");
        await db.execute("CREATE INDEX IF NOT EXISTS idx_rentals_checkout ON rentals(checkoutDate)");
        await db.execute("CREATE INDEX IF NOT EXISTS idx_rentals_returned ON rentals(returned)");
        await db.execute("CREATE INDEX IF NOT EXISTS idx_payment_logs_order ON payment_logs(orderId)");
        await db.execute("CREATE INDEX IF NOT EXISTS idx_payment_logs_fallback ON payment_logs(fallbackRentalId)");
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 29) {
          try {
            await db.execute("CREATE TABLE suppliers(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, phone TEXT, email TEXT, address TEXT, taxRegNo TEXT, notes TEXT, joinedDate TEXT)");
            await db.execute("ALTER TABLE items ADD COLUMN supplierId INTEGER DEFAULT NULL");
          } catch (e, st) { debugPrint('Migration v29 error: $e\n$st'); }
        }

        if (oldV < 30) {
          try {
            await db.execute("CREATE TABLE purchase_orders(id INTEGER PRIMARY KEY AUTOINCREMENT, supplierId INTEGER, poNumber TEXT, orderDate TEXT, subtotal REAL DEFAULT 0, taxAmount REAL DEFAULT 0, grandTotal REAL DEFAULT 0, amountPaid REAL DEFAULT 0, notes TEXT)");
            await db.execute("CREATE TABLE purchase_order_items(id INTEGER PRIMARY KEY AUTOINCREMENT, poId INTEGER, itemId INTEGER, qty INTEGER, unitCost REAL, lineTotal REAL)");
          } catch (e, st) { debugPrint('Migration v30 error: $e\n$st'); }
        }

        if (oldV < 31) {
          try {
            await db.execute("ALTER TABLE purchase_orders ADD COLUMN billNumber TEXT DEFAULT ''");
          } catch (e, st) { debugPrint('Migration v31 error: $e\n$st'); }
        }

        if (oldV < 32) {
          try {
            // FINANCIAL SYNC: Ensure existing databases have the cancellation flag for POs
            await db.execute("ALTER TABLE purchase_orders ADD COLUMN isCancelled INTEGER DEFAULT 0");
          } catch (e, st) { debugPrint('Migration v32 error: $e\n$st'); }
        }

        if (oldV < 33) {
          try {
            // HEALING MIGRATION: Restore any missing schemas deleted between v23-v28 in v2.8.1
            // 1. Ensure all auxiliary tables exist safely
            await db.execute("CREATE TABLE IF NOT EXISTS sequences(seqKey TEXT PRIMARY KEY, seqValue INTEGER)");
            await db.execute("CREATE TABLE IF NOT EXISTS expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, category TEXT NOT NULL, amount REAL NOT NULL, paymentMethod TEXT, vendor TEXT, receiptPath TEXT, notes TEXT)");
            await db.execute("CREATE TABLE IF NOT EXISTS suppliers(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, phone TEXT, email TEXT, address TEXT, taxRegNo TEXT, notes TEXT, joinedDate TEXT)");
            await db.execute("CREATE TABLE IF NOT EXISTS purchase_orders(id INTEGER PRIMARY KEY AUTOINCREMENT, supplierId INTEGER, poNumber TEXT, billNumber TEXT DEFAULT '', orderDate TEXT, subtotal REAL DEFAULT 0, taxAmount REAL DEFAULT 0, grandTotal REAL DEFAULT 0, amountPaid REAL DEFAULT 0, notes TEXT, isCancelled INTEGER DEFAULT 0)");
            await db.execute("CREATE TABLE IF NOT EXISTS purchase_order_items(id INTEGER PRIMARY KEY AUTOINCREMENT, poId INTEGER, itemId INTEGER, qty INTEGER, unitCost REAL, lineTotal REAL)");
            await db.execute("CREATE TABLE IF NOT EXISTS vendor_payment_logs(id INTEGER PRIMARY KEY AUTOINCREMENT, poId INTEGER NOT NULL, amount REAL NOT NULL, method TEXT NOT NULL, paidAt TEXT NOT NULL)");
            await db.execute("CREATE TABLE IF NOT EXISTS maintenance_logs(id INTEGER PRIMARY KEY AUTOINCREMENT, itemId INTEGER NOT NULL, description TEXT NOT NULL, cost REAL NOT NULL, logDate TEXT NOT NULL, FOREIGN KEY (itemId) REFERENCES items (id) ON DELETE CASCADE)");

            // 2. Universalized abstract to safely patch missing columns
            Future<void> safeAddColumn(String table, String definition) async {
              try {
                await db.execute("ALTER TABLE $table ADD COLUMN $definition");
              } catch (_) {
                // Ignore duplicate column errors if the user already has it
              }
            }

            // 3. Apply schema patches for data integrity
            await safeAddColumn("items", "supplierId INTEGER DEFAULT NULL");
            await safeAddColumn("purchase_orders", "billNumber TEXT DEFAULT ''");
            await safeAddColumn("purchase_orders", "isCancelled INTEGER DEFAULT 0");
            await safeAddColumn("rentals", "isCancelled INTEGER DEFAULT 0");
            await safeAddColumn("rentals", "invoiceNumber TEXT DEFAULT ''");
            await safeAddColumn("rentals", "voidedAt TEXT DEFAULT ''");
            await safeAddColumn("orders", "invoiceNumber TEXT DEFAULT ''");
            await safeAddColumn("orders", "voidedAt TEXT DEFAULT ''");
            await safeAddColumn("customers", "partyType TEXT DEFAULT 'Customer'");
            await safeAddColumn("customers", "taxRegNo TEXT DEFAULT ''");

            // 4. Financial & Tax System columns
            await safeAddColumn("business_info", "taxProfile TEXT DEFAULT 'No Tax'");
            await safeAddColumn("business_info", "taxType TEXT DEFAULT 'none'");
            await safeAddColumn("business_info", "taxRate REAL DEFAULT 0");
            await safeAddColumn("business_info", "taxMode TEXT DEFAULT 'exclusive'");
            await safeAddColumn("business_info", "taxRegNo TEXT DEFAULT ''");
            await safeAddColumn("business_info", "fyStartMonth INTEGER DEFAULT 4");

          } catch (e, st) {
            debugPrint('Critical Migration v33 error: $e\n$st');
          }
        }

        if (oldV < 34) {
          try {
            // FINANCIAL SYNC: Add explicit type to ledger to support non-operational revenues
            Future<void> safeAddColumn(String table, String definition) async {
              try { await db.execute("ALTER TABLE $table ADD COLUMN $definition"); } catch (_) {}
            }
            await safeAddColumn("expenses", "type TEXT DEFAULT 'Expense'");
          } catch (e, st) {
            debugPrint('Migration v34 error: $e\n$st');
          }
        }

        if (oldV < 35) {
          try {
            // FINANCIAL IMMUTABILITY: Freeze tax settings at the time of order creation.
            Future<void> safeAddColumn(String table, String definition) async {
              try { await db.execute("ALTER TABLE $table ADD COLUMN $definition"); } catch (_) {}
            }
            await safeAddColumn("orders", "taxType TEXT DEFAULT 'none'");
            await safeAddColumn("orders", "taxRate REAL DEFAULT 0");
            await safeAddColumn("orders", "taxMode TEXT DEFAULT 'exclusive'");
            await safeAddColumn("orders", "taxRegNo TEXT DEFAULT ''");

            // HEALING PATCH: Copy current business tax settings to all legacy orders
            // to preserve their exact financial state before this update.
            final bizRows = await db.query('business_info', where: 'id=1');
            if (bizRows.isNotEmpty) {
              final biz = bizRows.first;
              await db.update('orders', {
                'taxType': biz['taxType'] ?? 'none',
                'taxRate': biz['taxRate'] ?? 0.0,
                'taxMode': biz['taxMode'] ?? 'exclusive',
                'taxRegNo': biz['taxRegNo'] ?? ''
              }, where: "taxType = 'none' OR taxType IS NULL");
            }
          } catch (e, st) {
            debugPrint('Migration v35 error: $e\n$st');
          }
        }

        if (oldV < 36) {
          try {
            await db.rawUpdate("UPDATE orders SET taxType = 'none', taxRate = 0, taxRegNo = ''");
          } catch (e, st) {
            debugPrint('Migration v36 error: $e\n$st');
          }
        }

        if (oldV < 37) {
          try {
            // CPA HEALING SCRIPT: Prevent historical settled invoices from "zombifying" due to the strict midnight-to-midnight day calculation fix. Any unpaid variance on already-settled items is absorbed into the discount ledger, permanently locking the balance to exactly $0.00.
            await db.rawUpdate('''
              UPDATE rentals 
              SET discount = (
                (qty * rentalRate * MAX(1, CAST(julianday(date(IFNULL(NULLIF(returnDate, ''), date('now', 'localtime')))) - julianday(date(checkoutDate)) AS INTEGER))) 
                + penaltyFee - advanceDeposit - badDebt
              )
              WHERE isSettled = 1 AND isCancelled = 0
            ''');
          } catch (e, st) {
            debugPrint('Migration v37 error: $e\n$st');
          }
        }
      },
    );
    return _db!;
  }

  // --- EXPENSE TRACKING LOGIC ---
  static Future<List<Map<String, dynamic>>> getExpenses({String? search}) async {
    final db = await getDatabase();
    if (search != null && search.isNotEmpty) {
      return db.query('expenses', where: 'category LIKE ? OR vendor LIKE ? OR notes LIKE ?', whereArgs: ['%$search%', '%$search%', '%$search%'], orderBy: 'date DESC, id DESC');
    }
    return db.query('expenses', orderBy: 'date DESC, id DESC');
  }

  static Future<int> insertExpenseRevenue(String date, String type, String category, double amount, String method, String vendor, String notes) async {
    final db = await getDatabase();
    return db.insert('expenses', {
      'date': date, 'type': type, 'category': category, 'amount': amount, 'paymentMethod': method, 'vendor': vendor, 'notes': notes, 'receiptPath': ''
    });
  }

  static Future<int> deleteExpense(int id) async {
    final db = await getDatabase();
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------
  // PROCUREMENT & SUPPLIER LOGISTICS
  // ------------------------------------------

  static Future<List<Map<String, dynamic>>> getSuppliers() async {
    final db = await getDatabase();
    return await db.query('customers', where: 'partyType = ?', whereArgs: ['Supplier'], orderBy: 'name ASC');
  }

  static Future<int> insertSupplier(Map<String, dynamic> data) async {
    final db = await getDatabase();
    return await db.insert('suppliers', data);
  }

  static Future<int> updateSupplier(int id, Map<String, dynamic> data) async {
    final db = await getDatabase();
    return await db.update('suppliers', data, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteSupplier(int id) async {
    final db = await getDatabase();
    return await db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> createPurchaseOrder(Map<String, dynamic> poData, List<Map<String, dynamic>> items) async {
    final db = await getDatabase();
    int poId = 0;
    await db.transaction((txn) async {
      final passedPoNum = poData['poNumber'] as String? ?? '';

      // Auto-generate PO Sequence by Financial Year
      final bizRows = await txn.query('business_info', where: 'id=1');
      final fyStartMonth = bizRows.isNotEmpty ? (bizRows.first['fyStartMonth'] as int? ?? 4) : 4;
      final dt = DateTime.tryParse(poData['orderDate'] as String? ?? '') ?? DateTime.now();
      final fyPrefix = getFiscalYear(dt, fyStartMonth);

      if (passedPoNum.trim().isEmpty) {
        poData['poNumber'] = await generateNextSequence(txn, 'PO', fyPrefix);
      } else {
        // FINANCIAL SYNC: If user kept the pre-filled sequence, safely bump the tracker to prevent dupes later.
        final seqKey = 'PO-$fyPrefix';
        final rows = await txn.query('sequences', where: 'seqKey=?', whereArgs: [seqKey]);
        int nextVal = rows.isEmpty ? 1 : (rows.first['seqValue'] as int) + 1;
        String expectedNext = 'PO-$fyPrefix-$nextVal';

        if (passedPoNum.trim() == expectedNext) {
          if (rows.isEmpty) {
            await txn.insert('sequences', {'seqKey': seqKey, 'seqValue': 1});
          } else {
            await txn.update('sequences', {'seqValue': nextVal}, where: 'seqKey=?', whereArgs: [seqKey]);
          }
        }
      }

      // FIX: Extract payment method and remove it from the map so SQL doesn't crash
      final paymentMethod = poData.remove('paymentMethod') as String? ?? 'Cash';

      poId = await txn.insert('purchase_orders', poData);

      // FINANCIAL SYNC: Log PO advances strictly to the dedicated A/P payment logs
      final amtPaid = (poData['amountPaid'] as num?)?.toDouble() ?? 0.0;
      if (amtPaid > 0) {
        await _ensureVendorPaymentLogsTableExists(txn);
        await txn.insert('vendor_payment_logs', {
          'poId': poId,
          'amount': amtPaid,
          'method': paymentMethod,
          'paidAt': poData['orderDate'],
        });
      }

      for (var item in items) {
        item['poId'] = poId;
        await txn.insert('purchase_order_items', item);

        await txn.rawUpdate(
            '''
            UPDATE items 
            SET total = total + ?, 
                purchasePrice = ?, 
                supplierId = ?, 
                purchaseDate = ? 
            WHERE id = ?
            ''',
            [
              item['qty'],
              item['unitCost'],
              poData['supplierId'],
              poData['orderDate'],
              item['itemId']
            ]
        );
      }
    });
    return poId;
  }

  static Future<List<Map<String, dynamic>>> getPurchaseOrders() async {
    final db = await getDatabase();
    return await db.rawQuery('''
        SELECT po.*, c.name as supplierName, c.phone, c.phone2,
               (SELECT GROUP_CONCAT(i.name || '|' || poi.qty || '|' || poi.unitCost || '|' || poi.lineTotal, '^') 
                FROM purchase_order_items poi 
                JOIN items i ON poi.itemId = i.id 
                WHERE poi.poId = po.id) as itemsSummary
        FROM purchase_orders po 
        LEFT JOIN customers c ON po.supplierId = c.id 
        ORDER BY po.id DESC
     ''');
  }

  // ------------------------------------------
  // ACCOUNTS PAYABLE (A/P) LEDGER
  // ------------------------------------------
  static Future<void> recordPOPayment(int poId, double amount, String method, String date, String poNumber, String supplierName) async {
    final db = await getDatabase();
    await db.transaction((txn) async {
      await txn.rawUpdate('UPDATE purchase_orders SET amountPaid = amountPaid + ? WHERE id = ?', [amount, poId]);

      await _ensureVendorPaymentLogsTableExists(txn);
      await txn.insert('vendor_payment_logs', {
        'poId': poId,
        'amount': amount,
        'method': method,
        'paidAt': date,
      });
    });
  }

  // ------------------------------------------
  // PROFIT & LOSS ENGINE
  // ------------------------------------------
  static Future<Map<String, dynamic>> getProfitAndLossStatement({String method = 'SLM'}) async {
    final db = await getDatabase();

    // 1. Gross Revenue (Accrual Basis: Total generated from active rentals)
    final revResult = await db.rawQuery('''
      SELECT 
        SUM((qty * rentalRate * MAX(1, CAST(julianday(date(IFNULL(NULLIF(returnDate, ''), date('now', 'localtime')))) - julianday(date(checkoutDate)) AS INTEGER))) + penaltyFee) as totalRev,
        SUM(discount) as totalDisc
      FROM rentals 
      WHERE isCancelled = 0
    ''');
    double grossRevenue = (revResult.first['totalRev'] as num?)?.toDouble() ?? 0.0;
    double totalDiscount = (revResult.first['totalDisc'] as num?)?.toDouble() ?? 0.0;

    // 2. Operating Expenses & Auxiliary Revenue (OPEX - excluding CAPEX equipment purchases)
    final expResult = await db.rawQuery('''
      SELECT SUM(CASE WHEN type = 'Revenue' THEN -amount ELSE amount END) as totalExp 
      FROM expenses 
      WHERE category != 'Asset Procurement (PO)'
    ''');
    double opex = (expResult.first['totalExp'] as num?)?.toDouble() ?? 0.0;

    // 3. Bad Debt (Written off revenue)
    final bdResult = await db.rawQuery('''
      SELECT SUM(badDebt) as totalBd 
      FROM rentals 
      WHERE isCancelled = 0
    ''');
    double badDebt = (bdResult.first['totalBd'] as num?)?.toDouble() ?? 0.0;

    // 4. Asset Depreciation (Linked directly to our valuation engine)
    final valuation = await getInventoryValuationReport(method: method);
    double totalDepreciation = 0.0;
    for (var v in valuation) {
      totalDepreciation += (v['accumulatedDepreciation'] as num?)?.toDouble() ?? 0.0;
    }

    // 5. Standard: EBITDA -> EBIT -> EBT -> Net Profit
    double ebitda = grossRevenue - totalDiscount - opex;
    // Depreciation and Bad Debt (Losses) are deducted to arrive at Net Taxable Profit
    double netProfit = ebitda - totalDepreciation - badDebt;

    return {
      'grossRevenue': grossRevenue,
      'discount': totalDiscount,
      'opex': opex,
      'ebitda': ebitda,
      'badDebt': badDebt,
      'depreciation': totalDepreciation,
      'netProfit': netProfit,
      'depreciationMethod': method
    };
  }

  static Future<void> writeOffBadDebt(int firstId, double amount, List<int> allIds) async {
    final db = await getDatabase();
    await db.transaction((txn) async {
      // Bad debt is tracked on the head rental line for the group.
      await txn.rawUpdate('UPDATE rentals SET badDebt=badDebt+? WHERE id=?', [amount, firstId]);
      // Full write-off closes the rest of the invoice lines.
      for (final id in allIds) {
        await txn.rawUpdate('UPDATE rentals SET isSettled=1 WHERE id=?', [id]);
      }
    });
  }

  static Future<void> recoverBadDebt(int firstId, double amount, String method, List<int> allIds, bool isFullyRecovered, {String? paidAt}) async {
    final db = await getDatabase();
    await db.transaction((txn) async {
      final head = (await txn.query('rentals', columns: ['orderId'], where: 'id=?', whereArgs: [firstId], limit: 1)).firstOrNull;
      final orderId = head?['orderId'] as int?;
      // Recovery is recorded as a normal incoming payment log entry.
      await txn.insert('payment_logs', {
        'orderId': orderId,
        'fallbackRentalId': orderId == null ? firstId : null,
        'amount': amount,
        'method': method,
        'paidAt': paidAt ?? DateTime.now().toIso8601String(),
      });
      await txn.rawUpdate('UPDATE rentals SET badDebt=MAX(0, badDebt-?), advanceDeposit=advanceDeposit+? WHERE id=?', [amount, amount, firstId]);
      if (isFullyRecovered) {
        for (final id in allIds) {
          await txn.rawUpdate('UPDATE rentals SET isSettled=1 WHERE id=?', [id]);
        }
      }
    });
  }

  static String formatDateFromDt(DateTime dt) => formatDateByPreference(dt);

  static String formatDateString(String? s) {
    if (s == null || s.isEmpty) return '';
    try {
      return formatDateFromDt(DateTime.parse(s));
    } catch (_) {
      return s;
    }
  }

  static String isoDate(DateTime dt) => dt.toIso8601String();
  static String isoNow() => DateTime.now().toIso8601String();

  // ------------------------------------------
  // SQL SCALABILITY & PAGINATION ENGINE
  // ------------------------------------------
  static Future<Map<String, dynamic>> getDashboardData() async {
    final db = await getDatabase();
    const daysSql = "MAX(1, CAST(julianday(date(IFNULL(NULLIF(returnDate, ''), date('now', 'localtime')))) - julianday(date(checkoutDate)) AS INTEGER))";
    const lineCostSql = "(rentalRate * qty * $daysSql) + penaltyFee";
    const balanceSql = "($lineCostSql) - advanceDeposit - discount - badDebt";

    const pendingQuery = '''
      SELECT SUM(balance) as totalPending FROM (
        SELECT COALESCE(orderId, id) as groupId, MIN(returned) as allReturned, MIN(isSettled) as allSettled, SUM($balanceSql) as balance
        FROM rentals WHERE isCancelled = 0 GROUP BY COALESCE(orderId, id)
      ) WHERE allReturned = 1 AND allSettled = 0 AND balance > 0
    ''';

    const topCustomersQuery = '''
      SELECT contractor as name, COUNT(DISTINCT COALESCE(orderId, id)) as invoices, SUM($lineCostSql) as revenue 
      FROM rentals WHERE isCancelled = 0 AND contractor != '' 
      GROUP BY contractor ORDER BY revenue DESC LIMIT 5
    ''';

    final pendingResult = await db.rawQuery(pendingQuery);
    final topCustResult = await db.rawQuery(topCustomersQuery);

    return {
      'pendingCollections': pendingResult.first['totalPending'] as double? ?? 0.0,
      'topCustomers': topCustResult.map((r) => {
        'name': r['name'],
        'invoices': r['invoices'],
        'revenue': r['revenue'] as double? ?? 0.0,
      }).toList(),
    };
  }

  static Future<List<Map<String, dynamic>>> getOverdueRentals(int overdueDays) async {
    final db = await getDatabase();
    final cutoff = isoDate(DateTime.now().subtract(Duration(days: overdueDays)));
    return db.rawQuery('''
      SELECT rentals.*, items.name as itemName FROM rentals 
      JOIN items ON rentals.itemId=items.id 
      WHERE (returned=0 OR returned IS NULL) AND checkoutDate <= ? AND isCancelled = 0 ORDER BY checkoutDate ASC
    ''', [cutoff]);
  }

  // ------------------------------------------
  // Ledger Search & Filtering (Outstanding tab)
  // ------------------------------------------
  // Treat invoice-like input as explicit ID intent: "15", "#15", "INV#15", "Invoice 15".
  static bool _isLedgerIdIntent(String rawSearch) {
    final trimmed = rawSearch.trim();
    if (trimmed.isEmpty) return false;
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return false;
    return RegExp(r'^\s*#?\s*\d+\s*$').hasMatch(trimmed) ||
        RegExp(r'\b(?:inv|invoice)\s*#?\s*\d+\b', caseSensitive: false).hasMatch(trimmed);
  }

  static String _normalizeLedgerText(String input) => input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  // Unified invoice key across grouped and fallback rentals.
  static int? _ledgerGroupIdOf(RentalGroup group) =>
      group.orderId ?? group.fallbackId ?? (group.items.firstOrNull?['id'] as int?);

  // Search matcher used only for the Outstanding ledger list.
  // Supports plain text matching plus normalized matching (ignores spaces/symbols).
  static bool _ledgerMatchesSearch(RentalGroup group, String rawSearch) {
    final trimmed = rawSearch.trim();
    if (trimmed.isEmpty) return true;

    final lower = trimmed.toLowerCase();
    final normalized = _normalizeLedgerText(trimmed);
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    final parsedSearchId = int.tryParse(digitsOnly);
    final groupId = _ledgerGroupIdOf(group);

    if (_isLedgerIdIntent(trimmed) && parsedSearchId != null && groupId == parsedSearchId) {
      return true;
    }

    final fields = <String>[
      group.contractor,
      group.phone,
      group.phone2,
      group.address,
      group.proformaNumber,
      group.invoiceNumber,
      if (groupId != null) groupId.toString(),
      ...group.items.map((i) => i['orderCustomerName'] as String? ?? ''),
    ];

    for (final f in fields) {
      final v = f.toLowerCase();
      if (v.contains(lower)) return true;
      if (normalized.isNotEmpty && _normalizeLedgerText(v).contains(normalized)) return true;
    }

    if (parsedSearchId != null && groupId != null && groupId.toString().contains(parsedSearchId.toString())) {
      return true;
    }
    return false;
  }

  static Future<List<RentalGroup>> _getFilteredLedgerGroups({
    required String filterMode,
    required String search,
    int? orderId,
    int? fallbackRentalId,
  }) async {
    final db = await getDatabase();
    // Pull once, then apply business rules in Dart to keep search behavior deterministic.
    final lines = await db.rawQuery(
      "SELECT rentals.*, items.name as itemName, COALESCE(orders.customerName, '') as orderCustomerName, "
          "COALESCE(orders.proformaNumber, '') as proformaNumber, COALESCE(orders.invoiceNumber, '') as invoiceNumber, "
          "orders.taxType, orders.taxRate, orders.taxMode, orders.taxRegNo, "
          "CASE WHEN (rentals.phone2 IS NULL OR rentals.phone2 = '') THEN COALESCE(customers.phone2, '') ELSE rentals.phone2 END as phone2 "
          "FROM rentals JOIN items ON rentals.itemId=items.id "
          "LEFT JOIN customers ON customers.name=rentals.contractor "
          "LEFT JOIN orders ON orders.id=rentals.orderId "
          "WHERE COALESCE(rentals.isCancelled, 0) = 0 "
          "ORDER BY rentals.checkoutDate ASC, rentals.id ASC",
    );

    var groups = groupRentalsByInvoice(lines).where((g) => !g.isCancelled).toList();

    final trimmedSearch = search.trim();
    final digitsOnly = trimmedSearch.replaceAll(RegExp(r'[^0-9]'), '');
    final parsedSearchId = int.tryParse(digitsOnly);
    final scopedGroupId = orderId ??
        fallbackRentalId ??
        ((_isLedgerIdIntent(trimmedSearch) && parsedSearchId != null) ? parsedSearchId : null);

    // Scoped mode (navigation from History/Transactions): bypass global outstanding rules.
    if (scopedGroupId != null) {
      groups = groups.where((g) => _ledgerGroupIdOf(g) == scopedGroupId).toList();
      // Ensure we do not show fully paid/settled records in the Outstanding tab.
      groups = groups.where((g) => !g.isSettled && g.balance != 0).toList();
      return groups;
    }

    // Global Outstanding view rules.
    groups = groups.where((g) => g.isFullyReturned && !g.isSettled).toList();
    if (filterMode == 'Amount Due') {
      groups = groups.where((g) => g.balance > 0).toList();
    } else if (filterMode == 'Refund Due') {
      groups = groups.where((g) => g.balance < 0).toList();
    } else {
      groups = groups.where((g) => g.balance != 0).toList();
    }

    if (trimmedSearch.isNotEmpty) {
      groups = groups.where((g) => _ledgerMatchesSearch(g, trimmedSearch)).toList();
    }

    groups.sort((a, b) {
      final byDate = b.checkoutDate.compareTo(a.checkoutDate);
      if (byDate != 0) return byDate;
      return (_ledgerGroupIdOf(b) ?? 0).compareTo(_ledgerGroupIdOf(a) ?? 0);
    });
    return groups;
  }

  static Future<Map<String, double>> getLedgerTotals({
    required String filterMode,
    required String search,
    int? orderId,
    int? fallbackRentalId
  }) async {
    // Totals are derived from the exact same filtered set as the list to avoid mismatch.
    final groups = await _getFilteredLedgerGroups(
      filterMode: filterMode,
      search: search,
      orderId: orderId,
      fallbackRentalId: fallbackRentalId,
    );
    double totalDue = 0.0;
    double totalRefund = 0.0;
    for (final g in groups) {
      if (g.balance > 0) totalDue += g.balance;
      if (g.balance < 0) totalRefund += g.balance.abs();
    }
    return {
      'totalDue': totalDue,
      'totalRefund': totalRefund,
      'count': groups.length.toDouble(),
    };
  }

  static Future<List<RentalGroup>> getPaginatedLedgerGroups({
    required int offset,
    required int limit,
    required String filterMode,
    required String search,
    int? orderId,
    int? fallbackRentalId
  }) async {
    final groups = await _getFilteredLedgerGroups(
      filterMode: filterMode,
      search: search,
      orderId: orderId,
      fallbackRentalId: fallbackRentalId,
    );
    if (offset >= groups.length || limit <= 0) return [];
    final end = (offset + limit) > groups.length ? groups.length : (offset + limit);
    return groups.sublist(offset, end);
  }

  static Map<String, pw.Font>? _cachedFonts;

  static Future<Map<String, pw.Font>> _loadPdfFonts() async {
    if (_cachedFonts != null) return _cachedFonts!;
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    final italic = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Italic.ttf'));
    _cachedFonts = { 'regular': regular, 'bold': bold, 'italic': italic };
    return _cachedFonts!;
  }

  static Future<Map<String, int>> getDashboardStats({int overdueDays = 30}) async {
    final db = await getDatabase();
    int q(List<Map> r) => r.first['c'] as int? ?? 0;
    final cutoff = isoDate(DateTime.now().subtract(Duration(days: overdueDays)));
    return {
      'items': q(await db.rawQuery('SELECT COUNT(*) as c FROM items')),
      'activeRentals': q(await db.rawQuery('SELECT COUNT(*) as c FROM rentals WHERE returned=0 OR returned IS NULL')),
      'activeOrders': q(await db.rawQuery('SELECT COUNT(DISTINCT orderId) as c FROM rentals WHERE returned=0 OR returned IS NULL')),
      'returned': q(await db.rawQuery('SELECT COUNT(*) as c FROM rentals WHERE returned=1')),
      'returnedOrders': q(await db.rawQuery('SELECT COUNT(DISTINCT orderId) as c FROM rentals WHERE returned=1')),
      'customers': q(await db.rawQuery('SELECT COUNT(*) as c FROM customers')),
      'overdue': q(await db.rawQuery('SELECT COUNT(*) as c FROM rentals WHERE (returned=0 OR returned IS NULL) AND checkoutDate<=?', [cutoff])),
    };
  }

  static Future<List<Map<String, dynamic>>> getItems({String? search, String? category}) async {
    final db = await getDatabase();
    final where = <String>[];
    final args = <dynamic>[];
    if (search != null && search.isNotEmpty) {
      where.add('name LIKE ?');
      args.add('%$search%');
    }
    if (category != null && category != 'All') {
      where.add('category = ?');
      args.add(category);
    }
    return db.query(
        'items',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'name ASC'
    );
  }

  static Future<List<String>> getCategories() async {
    final db = await getDatabase();
    final rows = await db.rawQuery("SELECT DISTINCT category FROM items ORDER BY category ASC");
    return rows.map((r) => r['category'] as String? ?? 'General').toList();
  }

  static Future<void> insertItem(String name, int total, String category, String notes, {double purchasePrice = 0.0, String purchaseDate = '', int expectedLifeMonths = 0}) async {
    final db = await getDatabase();
    await db.insert('items', {
      'name': name,
      'total': total,
      'rented': 0,
      'category': category,
      'notes': notes,
      'purchasePrice': purchasePrice,
      'purchaseDate': purchaseDate,
      'expectedLifeMonths': expectedLifeMonths,
    });
  }

  static Future<void> updateItem(int id, String name, int total, String category, String notes, {double purchasePrice = 0.0, String purchaseDate = '', int expectedLifeMonths = 0}) async {
    final db = await getDatabase();
    final rows = await db.query('items', columns: ['rented'], where: 'id=?', whereArgs: [id]);
    final rented = rows.firstOrNull?['rented'] as int? ?? 0;
    await db.update('items', {
      'name': name,
      'total': total,
      'rented': rented > total ? total : rented,
      'category': category,
      'notes': notes,
      'purchasePrice': purchasePrice,
      'purchaseDate': purchaseDate,
      'expectedLifeMonths': expectedLifeMonths,
    }, where: 'id=?', whereArgs: [id]);
  }

  static Future<void> deleteItem(int id) async {
    final db = await getDatabase();
    final active = (await db.rawQuery("SELECT COUNT(*) as c FROM rentals WHERE itemId=? AND (returned=0 OR returned IS NULL)", [id])).first['c'] as int? ?? 0;
    if (active > 0) throw Exception('Cannot delete: item has active rentals');
    await db.delete('items', where: 'id=?', whereArgs: [id]);
  }

  static Future<List<Map<String, dynamic>>> getAllRentals({String? search, int? limit, int? offset}) async {
    final db = await getDatabase();
    final args = <dynamic>[];
    String where = '';

    if (search != null && search.isNotEmpty) {
      where = "WHERE rentals.contractor LIKE ? OR items.name LIKE ?";
      args.addAll(['%$search%', '%$search%']);
    }

    String limitClause = '';
    if (limit != null) {
      limitClause = " LIMIT $limit";
      if (offset != null) {
        limitClause += " OFFSET $offset";
      }
    }

    final rows = await db.rawQuery(
      "SELECT rentals.*, items.name as itemName, "
          "COALESCE(orders.proformaNumber, '') as proformaNumber, COALESCE(orders.invoiceNumber, '') as invoiceNumber, "
          "orders.taxType, orders.taxRate, orders.taxMode, orders.taxRegNo, "
          "CASE WHEN (rentals.phone2 IS NULL OR rentals.phone2 = '') THEN COALESCE(customers.phone2, '') ELSE rentals.phone2 END as phone2 "
          "FROM rentals JOIN items ON rentals.itemId=items.id "
          "LEFT JOIN customers ON customers.name=rentals.contractor "
          "LEFT JOIN orders ON orders.id=rentals.orderId "
          "$where ORDER BY rentals.checkoutDate ASC, rentals.id ASC$limitClause",
      args.isEmpty ? null : args,
    );
    return rows;
  }

  static Future<void> updateRental(int id, {
    required String contractor, required String phone, required String phone2,
    required String address, required double advanceDeposit, required double rentalRate,
    required String checkoutDate, required String notes, String paymentMethod = ''
  }) async {
    final db = await getDatabase();
    await db.update('rentals', {
      'contractor': contractor,
      'phone': phone,
      'phone2': phone2,
      'address': address,
      'advanceDeposit': advanceDeposit,
      'rentalRate': rentalRate,
      'checkoutDate': checkoutDate,
      'notes': notes,
      'paymentMethod': paymentMethod
    }, where: 'id=?', whereArgs: [id]);
  }

  static Future<void> updateRentalGroup(RentalGroup group, {
    required String contractor, required String phone, required String phone2,
    required String address, required double advanceDeposit, required String paymentMethod,
    required String checkoutDate, required String notes
  }) async {
    final db = await getDatabase();
    await db.transaction((txn) async {
      bool isFirst = true;
      for (final r in group.items) {
        await txn.update('rentals', {
          'contractor': contractor,
          'phone': phone,
          'phone2': phone2,
          'address': address,
          'advanceDeposit': isFirst ? advanceDeposit : 0.0,
          'checkoutDate': checkoutDate,
          'notes': notes,
          'paymentMethod': isFirst ? paymentMethod : ''
        }, where: 'id=?', whereArgs: [r['id']]);
        isFirst = false;
      }

      if (group.orderId != null) {
        // Check if a final invoice already exists for this order
        final orderData = await txn.query('orders', columns: ['invoiceNumber'], where: 'id=?', whereArgs: [group.orderId]);
        final hasInvoice = orderData.isNotEmpty && (orderData.first['invoiceNumber'] as String).isNotEmpty;

        if (hasInvoice && !appSettingsNotifier.allowFinalInvoiceEditing) {
          throw Exception('Cannot edit: A final invoice has already been issued. Change the lock setting in Business Preferences.');
        }

        await txn.update('orders', {'customerName': contractor}, where: 'id=?', whereArgs: [group.orderId]);
      }

      final logQuery = group.orderId != null
          ? await txn.query('payment_logs', where: 'orderId=?', whereArgs: [group.orderId], orderBy: 'id ASC', limit: 1)
          : await txn.query('payment_logs', where: 'fallbackRentalId=?', whereArgs: [group.items.first['id']], orderBy: 'id ASC', limit: 1);

      if (logQuery.isNotEmpty) {
        final logId = logQuery.first['id'] as int;
        if (advanceDeposit.abs() < 0.0001) {
          await txn.delete('payment_logs', where: 'id=?', whereArgs: [logId]);
        } else {
          await txn.update('payment_logs', {
            'amount': advanceDeposit,
            'method': paymentMethod,
          }, where: 'id=?', whereArgs: [logId]);
        }
      } else if (advanceDeposit.abs() > 0.0001) {
        await txn.insert('payment_logs', {
          'orderId': group.orderId,
          'fallbackRentalId': group.orderId == null ? group.items.first['id'] : null,
          'amount': advanceDeposit,
          'method': paymentMethod,
          'paidAt': checkoutDate,
        });
      }
    });
  }

  static Future<void> returnOrderGroup(List<Map<String, dynamic>> items, String returnDate) async {
    final db = await getDatabase();
    await db.transaction((txn) async {
      for (final r in items) {
        final rows = await txn.query('items', columns: ['rented'], where: 'id=?', whereArgs: [r['itemId']]);
        final rented = rows.firstOrNull?['rented'] as int? ?? 0;
        await txn.rawUpdate('UPDATE items SET rented=rented-? WHERE id=?', [(r['qty'] as int).clamp(0, rented), r['itemId']]);
        await txn.rawUpdate('UPDATE rentals SET returned=1, returnDate=? WHERE id=?', [returnDate, r['id']]);
      }

      if (items.isNotEmpty && items.first['orderId'] != null) {
        final orderId = items.first['orderId'] as int;
        final activeCount = (await txn.rawQuery('SELECT COUNT(*) as c FROM rentals WHERE orderId=? AND (returned=0 OR returned IS NULL)', [orderId])).first['c'] as int? ?? 0;
        if (activeCount == 0) {
          final orderRow = (await txn.query('orders', where: 'id=?', whereArgs: [orderId])).firstOrNull;
          if (orderRow != null && (orderRow['invoiceNumber'] as String? ?? '').isEmpty) {
            final bizRows = await txn.query('business_info', where: 'id=1');
            final fyStartMonth = bizRows.isNotEmpty ? (bizRows.first['fyStartMonth'] as int? ?? 4) : 4;
            final dt = DateTime.parse(returnDate);
            final fyPrefix = getFiscalYear(dt, fyStartMonth);
            final invNum = await generateNextSequence(txn, 'INV', fyPrefix);
            await txn.update('orders', {'invoiceNumber': invNum}, where: 'id=?', whereArgs: [orderId]);
          }
        }
      }
    });
  }

  static Future<void> returnMultiplePartial(List<Map<String, dynamic>> returns, String returnDate) async {
    final db = await getDatabase();
    await db.transaction((txn) async {
      int? orderId;
      for (final ret in returns) {
        final rental = ret['rental'] as Map<String, dynamic>;
        orderId ??= rental['orderId'] as int?;
        final goodQty = ret['goodQty'] as int;
        final damagedQty = ret['damagedQty'] as int;
        final penalty = ret['penalty'] as double;
        final totalReturnQty = goodQty + damagedQty;

        if (totalReturnQty <= 0) continue;

        final rentalId = rental['id'] as int;
        final itemId = rental['itemId'] as int;
        final currentQty = rental['qty'] as int;

        await txn.rawUpdate('UPDATE items SET rented=MAX(0, rented-?) WHERE id=?', [totalReturnQty, itemId]);

        if (damagedQty > 0) {
          await txn.rawUpdate('UPDATE items SET lostQty=lostQty+? WHERE id=?', [damagedQty, itemId]);
        }

        if (totalReturnQty >= currentQty) {
          await txn.rawUpdate('UPDATE rentals SET returned=1, returnDate=?, penaltyFee=?, damagedQty=? WHERE id=?', [returnDate, penalty, damagedQty, rentalId]);
        } else {
          await txn.insert('rentals', {
            'itemId': itemId,
            'orderId': rental['orderId'],
            'customerId': rental['customerId'],
            'contractor': rental['contractor'],
            'phone': rental['phone'] ?? '',
            'phone2': rental['phone2'] ?? '',
            'address': rental['address'],
            'advanceDeposit': 0.0,
            'discount': 0.0,
            'qty': totalReturnQty,
            'checkoutDate': rental['checkoutDate'],
            'rentalRate': rental['rentalRate'],
            'returned': 1,
            'returnDate': returnDate,
            'notes': rental['notes'],
            'isSettled': rental['isSettled'] ?? 0,
            'paymentMethod': rental['paymentMethod'] ?? '',
            'penaltyFee': penalty,
            'damagedQty': damagedQty
          });
          await txn.rawUpdate('UPDATE rentals SET qty=qty-? WHERE id=?', [totalReturnQty, rentalId]);
        }
      }

      if (orderId != null) {
        final activeCount = (await txn.rawQuery('SELECT COUNT(*) as c FROM rentals WHERE orderId=? AND (returned=0 OR returned IS NULL)', [orderId])).first['c'] as int? ?? 0;
        if (activeCount == 0) {
          final orderRow = (await txn.query('orders', where: 'id=?', whereArgs: [orderId])).firstOrNull;
          if (orderRow != null && (orderRow['invoiceNumber'] as String? ?? '').isEmpty) {
            final bizRows = await txn.query('business_info', where: 'id=1');
            final fyStartMonth = bizRows.isNotEmpty ? (bizRows.first['fyStartMonth'] as int? ?? 4) : 4;
            final dt = DateTime.parse(returnDate);
            final fyPrefix = getFiscalYear(dt, fyStartMonth);
            final invNum = await generateNextSequence(txn, 'INV', fyPrefix);
            await txn.update('orders', {'invoiceNumber': invNum}, where: 'id=?', whereArgs: [orderId]);
          }
        }
      }
    });
  }

  static Future<void> addPaymentToRentalGroup(int firstId, double amount, bool isFull, List<int> allIds, {String paymentMethod = '', double discountAmount = 0.0, String? paidAt}) async {
    final db = await getDatabase();
    await db.transaction((txn) async {
      // Store an explicit payment/refund log when a monetary amount was entered.
      if (amount.abs() > 0.0001) {
        final head = (await txn.query('rentals', columns: ['orderId'], where: 'id=?', whereArgs: [firstId], limit: 1)).firstOrNull;
        final orderId = head?['orderId'] as int?;
        await txn.insert('payment_logs', {
          'orderId': orderId,
          'fallbackRentalId': orderId == null ? firstId : null,
          'amount': amount,
          'method': paymentMethod,
          'paidAt': paidAt ?? DateTime.now().toIso8601String(),
        });
      }
      // Keep running financial state on the group head row.
      await txn.rawUpdate('UPDATE rentals SET advanceDeposit=advanceDeposit+?, discount=discount+?, paymentMethod=? WHERE id=?', [amount, discountAmount, paymentMethod, firstId]);
      // Full settlement marks all invoice lines as settled.
      if (isFull) {
        for (final id in allIds) {
          await txn.rawUpdate('UPDATE rentals SET isSettled=1 WHERE id=?', [id]);
        }
      }
    });
  }

  static Future<void> deleteRentalGroup(List<Map<String, dynamic>> groupItems) async {
    final db = await getDatabase();
    await db.transaction((txn) async {
      final orderIds = <int>{};
      final fallbackIds = <int>{};

      for (final r in groupItems) {
        if (r['orderId'] != null) {
          orderIds.add(r['orderId'] as int);
        } else if (r['id'] != null) {
          fallbackIds.add(r['id'] as int);
        }
        await txn.delete('rentals', where: 'id=?', whereArgs: [r['id']]);
      }

      for (final oid in orderIds) {
        final count = (await txn.rawQuery('SELECT COUNT(*) as c FROM rentals WHERE orderId=?', [oid])).first['c'] as int? ?? 0;
        if (count == 0) {
          await txn.delete('orders', where: 'id=?', whereArgs: [oid]);
          await txn.delete('payment_logs', where: 'orderId=?', whereArgs: [oid]);
        }
      }
      for (final fid in fallbackIds) {
        await txn.delete('payment_logs', where: 'fallbackRentalId=?', whereArgs: [fid]);
      }
    });
  }

  static Future<void> cancelRentalGroup(List<int> rentalIds) async {
    final db = await getDatabase();
    await db.transaction((txn) async {
      for (final id in rentalIds) {
        // Fetch current rental state to handle inventory
        final List<Map<String, dynamic>> result = await txn.query('rentals', where: 'id=?', whereArgs: [id]);
        if (result.isNotEmpty) {
          final rental = result.first;
          final int itemId = rental['itemId'] as int;
          final int qty = rental['qty'] as int;
          final int returned = rental['returned'] as int? ?? 0;
          final int wasCancelled = rental['isCancelled'] as int? ?? 0;

          if (wasCancelled == 0) {
            // Reclaim inventory if the item was still "Out"
            if (returned == 0) {
              await txn.rawUpdate('UPDATE items SET rented = MAX(0, rented - ?) WHERE id = ?', [qty, itemId]);
            }
            // Mark as cancelled
            await txn.rawUpdate('UPDATE rentals SET isCancelled=1 WHERE id=?', [id]);
          }
        }
      }
    });
  }

  static Future<List<Map<String, dynamic>>> getCustomers({String? search, String partyType = 'Customer'}) async {
    final db = await getDatabase();
    if (search != null && search.isNotEmpty) {
      return db.query('customers', where: 'partyType = ? AND (name LIKE ? OR phone LIKE ?)', whereArgs: [partyType, '%$search%', '%$search%'], orderBy: 'name ASC');
    }
    return db.query('customers', where: 'partyType = ?', whereArgs: [partyType], orderBy: 'name ASC');
  }

  static Future<int> insertCustomer(String name, String phone, String phone2, String email, String address, {String notes = '', String joinedDate = '', String partyType = 'Customer', String taxRegNo = ''}) async {
    final db = await getDatabase();
    return db.insert('customers', {
      'name': name, 'phone': phone, 'phone2': phone2, 'email': email, 'address': address,
      'notes': notes, 'joinedDate': joinedDate.isNotEmpty ? joinedDate : isoNow(), 'isBlacklisted': 0, 'partyType': partyType, 'taxRegNo': taxRegNo
    });
  }

  static Future<void> updateCustomer(int id, String name, String phone, String phone2, String email, String address, {String notes = '', String joinedDate = '', int isBlacklisted = 0, String partyType = 'Customer', String taxRegNo = ''}) async {
    final db = await getDatabase();
    await db.update('customers', {
      'name': name, 'phone': phone, 'phone2': phone2, 'email': email, 'address': address,
      'notes': notes, 'joinedDate': joinedDate, 'isBlacklisted': isBlacklisted, 'partyType': partyType, 'taxRegNo': taxRegNo
    }, where: 'id=?', whereArgs: [id]);
  }

  static Future<void> deleteCustomer(int id) async {
    final db = await getDatabase();
    await db.delete('customers', where: 'id=?', whereArgs: [id]);
  }

  static Future<void> toggleBlacklist(int id, bool blacklist) async {
    final db = await getDatabase();
    await db.update('customers', {'isBlacklisted': blacklist ? 1 : 0}, where: 'id=?', whereArgs: [id]);
  }

  static Future<double> getCustomerOwedBalance(int customerId, String customerName) async {
    final db = await getDatabase();
    final rows = await db.rawQuery(
        "SELECT rentals.*, items.name as itemName, orders.taxType, orders.taxRate, orders.taxMode, orders.taxRegNo FROM rentals JOIN items ON rentals.itemId=items.id LEFT JOIN orders ON orders.id=rentals.orderId WHERE rentals.customerId=? OR (rentals.customerId IS NULL AND rentals.contractor=?) ORDER BY rentals.checkoutDate ASC, rentals.id ASC",
        [customerId, customerName]
    );
    return groupRentalsByInvoice(rows).where((g) => g.isFullyReturned && !g.isSettled && g.balance > 0).fold<double>(0.0, (s, g) => s + g.balance);
  }

  static Future<List<RentalGroup>> getCustomerRentalHistory(int customerId, String customerName) async {
    final db = await getDatabase();
    final rows = await db.rawQuery(
      "SELECT rentals.*, items.name as itemName FROM rentals JOIN items ON rentals.itemId=items.id WHERE rentals.customerId=? OR (rentals.customerId IS NULL AND rentals.contractor=?) ORDER BY rentals.checkoutDate DESC, rentals.id DESC",
      [customerId, customerName],
    );
    return groupRentalsByInvoice(rows);
  }

  static Future<Map<String, dynamic>> getCustomerLifetimeStats(int customerId, String customerName) async {
    final db = await getDatabase();
    final rows = await db.rawQuery(
      "SELECT rentals.*, items.name as itemName FROM rentals JOIN items ON rentals.itemId=items.id WHERE rentals.customerId=? OR (rentals.customerId IS NULL AND rentals.contractor=?) ORDER BY rentals.checkoutDate ASC, rentals.id ASC",
      [customerId, customerName],
    );
    final groups = groupRentalsByInvoice(rows);
    double totalSpent   = 0.0;
    double owedBalance  = 0.0;
    double refundBalance = 0.0;
    double badDebtTotal = 0.0;
    int activeRentals   = 0;

    // Stats are computed per grouped invoice to avoid double counting line items.
    for (final g in groups) {
      totalSpent += g.calculateTotalCost();
      badDebtTotal += g.badDebt;
      if (!g.isFullyReturned) activeRentals += g.items.where((r) => r['returned'] == 0).length;
      if (g.isFullyReturned && !g.isSettled) {
        if (g.balance > 0) owedBalance  += g.balance;
        if (g.balance < 0) refundBalance += g.balance.abs();
      }
    }

    return {
      'totalSpent': totalSpent,
      'totalInvoices': groups.length,
      'activeRentals': activeRentals,
      'owedBalance': owedBalance,
      'refundBalance': refundBalance,
      'badDebt': badDebtTotal,
    };
  }

  static Future<int> createOrder(int? customerId, String customerName, String createdDate) async {
    final db = await getDatabase();
    return db.transaction((txn) async {
      final bizRows = await txn.query('business_info', where: 'id=1');
      final biz = bizRows.isNotEmpty ? bizRows.first : {};
      final fyStartMonth = biz['fyStartMonth'] as int? ?? 4;
      final dt = DateTime.parse(createdDate);
      final fyPrefix = getFiscalYear(dt, fyStartMonth);
      final proformaNum = await generateNextSequence(txn, 'ORD', fyPrefix);

      return await txn.insert('orders', {
        'customerId': customerId,
        'customerName': customerName,
        'createdDate': createdDate,
        'proformaNumber': proformaNum,
        'taxType': biz['taxType'] ?? 'none',
        'taxRate': biz['taxRate'] ?? 0.0,
        'taxMode': biz['taxMode'] ?? 'exclusive',
        'taxRegNo': biz['taxRegNo'] ?? ''
      });
    });
  }

  static Future<void> createOrderRentals(int orderId, List<Map<String, dynamic>> items) async {
    final db = await getDatabase();
    await db.transaction((txn) async {
      double initialAdvance = 0.0;
      String initialMethod = '';
      String initialPaidAt = isoNow();

      for (final it in items) {
        final itemId = it['itemId'] as int;
        final qty = it['qty'] as int;
        final rate = (it['rate'] as num?)?.toDouble() ?? 0.0;
        final advance = (it['advanceDeposit'] as num?)?.toDouble() ?? 0.0;

        if (initialAdvance.abs() < 0.0001 && advance.abs() > 0.0001) {
          initialAdvance = advance;
          initialMethod = (it['paymentMethod'] as String? ?? '').trim();
          initialPaidAt = (it['checkoutDate'] as String? ?? '').trim().isNotEmpty
              ? (it['checkoutDate'] as String)
              : isoNow();
        }

        final rows = await txn.query('items', columns: ['total', 'rented'], where: 'id=?', whereArgs: [itemId]);
        if (rows.isEmpty) throw Exception('Item not found');

        final total = rows.first['total'] as int? ?? 0;
        final rented = rows.first['rented'] as int? ?? 0;
        if (qty > (total - rented)) throw Exception('Not enough stock for item $itemId');

        await txn.insert('rentals', {
          'itemId': itemId,
          'customerId': it['customerId'],
          'contractor': it['contractor'] ?? '',
          'phone': it['phone'] ?? '',
          'phone2': it['phone2'] ?? '',
          'address': it['address'] ?? '',
          'advanceDeposit': it['advanceDeposit'] ?? 0.0,
          'discount': it['discount'] ?? 0.0,
          'rentalRate': rate,
          'qty': qty,
          'checkoutDate': it['checkoutDate'] ?? isoNow(),
          'orderId': orderId,
          'returned': 0,
          'notes': it['notes'] ?? '',
          'isSettled': 0,
          'paymentMethod': it['paymentMethod'] ?? ''
        });
        await txn.update('items', {'rented': rented + qty}, where: 'id=?', whereArgs: [itemId]);
      }

      if (initialAdvance.abs() > 0.0001) {
        await txn.insert('payment_logs', {
          'orderId': orderId,
          'fallbackRentalId': null,
          'amount': initialAdvance,
          'method': initialMethod,
          'paidAt': initialPaidAt,
        });
      }
    });
  }

  static Future<Map<String, List<Map<String, dynamic>>>> getPaymentLogsForGroups(List<RentalGroup> groups) async {
    final orderIds = <int>{};
    final fallbackIds = <int>{};
    for (final g in groups) {
      if (g.orderId != null) {
        orderIds.add(g.orderId!);
      } else if (g.fallbackId != null) {
        fallbackIds.add(g.fallbackId!);
      } else {
        final id = g.items.firstOrNull?['id'] as int?;
        if (id != null) fallbackIds.add(id);
      }
    }
    if (orderIds.isEmpty && fallbackIds.isEmpty) return {};

    final db = await getDatabase();
    final rows = <Map<String, dynamic>>[];

    if (orderIds.isNotEmpty) {
      final placeholders = List.filled(orderIds.length, '?').join(',');
      final result = await db.rawQuery(
        "SELECT id, orderId, fallbackRentalId, amount, method, paidAt "
            "FROM payment_logs WHERE orderId IN ($placeholders) ORDER BY paidAt ASC, id ASC",
        orderIds.toList(),
      );
      rows.addAll(result.map((r) => Map<String, dynamic>.from(r)));
    }

    if (fallbackIds.isNotEmpty) {
      final placeholders = List.filled(fallbackIds.length, '?').join(',');
      final result = await db.rawQuery(
        "SELECT id, orderId, fallbackRentalId, amount, method, paidAt "
            "FROM payment_logs WHERE fallbackRentalId IN ($placeholders) ORDER BY paidAt ASC, id ASC",
        fallbackIds.toList(),
      );
      rows.addAll(result.map((r) => Map<String, dynamic>.from(r)));
    }

    rows.sort((a, b) {
      final byDate = (a['paidAt'] as String? ?? '').compareTo(b['paidAt'] as String? ?? '');
      if (byDate != 0) return byDate;
      return ((a['id'] as int?) ?? 0).compareTo((b['id'] as int?) ?? 0);
    });

    final map = <String, List<Map<String, dynamic>>>{};
    for (final r in rows) {
      final orderId = r['orderId'] as int?;
      final fallbackId = r['fallbackRentalId'] as int?;
      final key = orderId != null ? 'o:$orderId' : 'f:$fallbackId';
      map.putIfAbsent(key, () => []).add(r);
    }
    return map;
  }

  static Future<List<Map<String, dynamic>>> getPaymentHistory({
    String search = '',
    String type = 'All',
    int? orderId,
    int? fallbackRentalId,
  }) async {
    final db = await getDatabase();
    final where = <String>[];
    final args = <dynamic>[];

    // Scoped mode: show logs for one specific invoice group only.
    if (orderId != null) {
      where.add('p.orderId = ?');
      args.add(orderId);
    } else if (fallbackRentalId != null) {
      where.add('p.fallbackRentalId = ?');
      args.add(fallbackRentalId);
    }

    if (type == 'Payment') {
      where.add('p.amount > 0');
    }
    if (type == 'Refund') {
      where.add('p.amount < 0');
    }

    final s = search.trim();
    if (s.isNotEmpty) {
      where.add(
        "(COALESCE(o.customerName, r.contractor, '') LIKE ? "
            "OR COALESCE(o.proformaNumber, '') LIKE ? "
            "OR COALESCE(o.invoiceNumber, '') LIKE ? "
            "OR COALESCE(p.method, '') LIKE ? "
            "OR CAST(COALESCE(p.orderId, p.fallbackRentalId) AS TEXT) LIKE ?)",
      );
      args.addAll(['%$s%', '%$s%', '%$s%', '%$s%', '%$s%']);
    }

    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    // firstLogId helps UI tag the original advance/security entry per invoice group.
    final rows = await db.rawQuery(
      "SELECT p.id, p.orderId, p.fallbackRentalId, p.amount, p.method, p.paidAt, "
          "COALESCE(o.customerName, r.contractor, '') AS customerName, "
          "COALESCE(o.proformaNumber, '') AS proformaNumber, COALESCE(o.invoiceNumber, '') AS invoiceNumber, "
          "COALESCE(o.createdDate, r.checkoutDate, '') AS baseDate, "
          "COALESCE(r.isCancelled, (SELECT MAX(isCancelled) FROM rentals WHERE orderId = p.orderId), 0) AS isCancelled, "
          "(SELECT MIN(id) FROM payment_logs p2 WHERE COALESCE(p2.orderId, -1) = COALESCE(p.orderId, -1) AND COALESCE(p2.fallbackRentalId, -1) = COALESCE(p.fallbackRentalId, -1)) AS firstLogId "
          "FROM payment_logs p "
          "LEFT JOIN orders o ON p.orderId = o.id "
          "LEFT JOIN rentals r ON p.fallbackRentalId = r.id "
          "$whereSql "
          "ORDER BY p.paidAt DESC, p.id DESC",
      args,
    );
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  static Future<List<Map<String, dynamic>>> getOrders() async {
    final db = await getDatabase();
    return db.query('orders', orderBy: 'createdDate DESC');
  }

  static Future<List<Map<String, dynamic>>> getRentalsByOrder(int orderId) async {
    final db = await getDatabase();
    return db.rawQuery("SELECT rentals.*, items.name as itemName FROM rentals JOIN items ON rentals.itemId=items.id WHERE rentals.orderId=?", [orderId]);
  }

  static Map<String, dynamic>? _cachedBizInfo;

  static Future<Map<String, dynamic>> getBusinessInfo() async {
    final db = await getDatabase();
    final rows = await db.query('business_info', where: 'id=?', whereArgs: [1]);
    if (rows.isEmpty) {
      _cachedBizInfo = {
        'name': '', 'phone': '', 'phone2': '', 'email': '', 'address': '', 'upiId': '', 'upiName': '',
        'taxProfile': 'No Tax', 'taxType': 'none', 'taxRate': 0.0, 'taxMode': 'exclusive', 'taxRegNo': '', 'fyStartMonth': 4,
      };
    } else {
      _cachedBizInfo = rows.first;
    }
    return _cachedBizInfo!;
  }

  static Future<void> saveBusinessInfo(
      String name, String phone, String phone2, String email, String address, String upiId, String upiName, {
        String taxProfile = 'No Tax', String taxType = 'none', double taxRate = 0.0, String taxMode = 'exclusive', String taxRegNo = '', int fyStartMonth = 4,
      }) async {
    final db = await getDatabase();

    final updatedData = {
      'name': name, 'phone': phone, 'phone2': phone2, 'email': email, 'address': address, 'upiId': upiId, 'upiName': upiName,
      'taxProfile': taxProfile, 'taxType': taxType, 'taxRate': taxRate, 'taxMode': taxMode, 'taxRegNo': taxRegNo, 'fyStartMonth': fyStartMonth,
    };

    await db.update('business_info', updatedData, where: 'id=?', whereArgs: [1]);
    _cachedBizInfo = updatedData;

    // Update display name cache for the Account Switcher UI
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String currentDb = prefs.getString('active_db_file') ?? 'rental_manager_v1.db';
    await prefs.setString('display_name_$currentDb', name);
  }

  // ------------------------------------------
  // Tax Configuration & Calculation
  // ------------------------------------------
  static Map<String, dynamic> buildTaxSettings(String typeRaw, String modeRaw, double rateRaw, String regNo) {
    final type = {'none','gst','vat','sales','consumption'}.contains(typeRaw.trim().toLowerCase()) ? typeRaw.trim().toLowerCase() : 'none';
    final mode = modeRaw.trim().toLowerCase() == 'inclusive' ? 'inclusive' : 'exclusive';
    final rate = rateRaw.clamp(0.0, 100.0);
    final enabled = type != 'none' && rate > 0;
    return {
      'type': type,
      'mode': mode,
      'rate': rate,
      'enabled': enabled,
      'regNo': regNo.trim(),
      'label': _taxLabel(type),
      'regLabel': _taxRegLabel(type),
    };
  }


  static String _taxLabel(String type) {
    switch (type) {
      case 'gst': return 'GST';
      case 'vat': return 'VAT';
      case 'sales': return 'Sales Tax';
      case 'consumption': return 'Consumption Tax';
      default: return 'Tax';
    }
  }

  static String _taxRegLabel(String type) {
    switch (type) {
      case 'gst': return 'GSTIN';
      case 'vat': return 'VAT No.';
      case 'sales': return 'Sales Tax ID';
      case 'consumption': return 'Tax Reg. No.';
      default: return 'Tax Reg. No.';
    }
  }

  static Map<String, double> _taxBreakdown(double subtotal, Map<String, dynamic> tax) {
    // Inclusive tax: subtotal already includes tax.
    // Exclusive tax: tax is added on top of subtotal.
    final enabled = tax['enabled'] == true;
    final mode = (tax['mode'] as String?) ?? 'exclusive';
    final rate = (tax['rate'] as num?)?.toDouble() ?? 0.0;
    if (!enabled || rate <= 0) {
      return {'taxableBase': subtotal, 'taxAmount': 0.0, 'grandTotal': subtotal};
    }
    if (mode == 'inclusive') {
      final taxableBase = subtotal / (1 + (rate / 100.0));
      final taxAmount = subtotal - taxableBase;
      return {'taxableBase': taxableBase, 'taxAmount': taxAmount, 'grandTotal': subtotal};
    }
    final taxAmount = subtotal * (rate / 100.0);
    return {'taxableBase': subtotal, 'taxAmount': taxAmount, 'grandTotal': subtotal + taxAmount};
  }

  static DateTime? _safeParseDate(dynamic s) {
    if (s == null) return null;
    final v = s.toString();
    if (v.isEmpty) return null;
    try { return DateTime.parse(v); } catch (_) { return null; }
  }

  static int _rentalChargeDays(Map<String, dynamic> r) {
    return RentalUtils.calculateChargeDays(
      r['checkoutDate'] as String?,
      r['returnDate'] as String?,
      r['returned'] as int? ?? 0,
    );
  }

  static String _getCurrencyCode(String symbol) {
    switch (symbol) {
      case '\$': return 'USD';
      case '€': return 'EUR';
      case '£': return 'GBP';
      case '¥': return 'JPY';
      case '฿': return 'THB';
      default: return 'INR';
    }
  }

  // ------------------------------------------
  // PROFORMA & INVOICE NUMBER SETTING AS PER FY
  // ------------------------------------------

  static String getFiscalYear(DateTime date, int fyStartMonth) {
    if (date.month >= fyStartMonth) {
      return date.year.toString();
    } else {
      return (date.year - 1).toString();
    }
  }

  static Future<String> generateNextSequence(Transaction txn, String docType, String fyPrefix) async {
    final seqKey = '$docType-$fyPrefix';
    final rows = await txn.query('sequences', where: 'seqKey=?', whereArgs: [seqKey]);
    int nextVal = 1;

    if (rows.isEmpty) {
      await txn.insert('sequences', {'seqKey': seqKey, 'seqValue': 1});
    } else {
      nextVal = (rows.first['seqValue'] as int) + 1;
      await txn.update('sequences', {'seqValue': nextVal}, where: 'seqKey=?', whereArgs: [seqKey]);
    }

    return '$docType-$fyPrefix-$nextVal';
  }

  static Future<String> peekNextSequence(String docType, DateTime date) async {
    final db = await getDatabase();
    final bizRows = await db.query('business_info', where: 'id=1');
    final fyStartMonth = bizRows.isNotEmpty ? (bizRows.first['fyStartMonth'] as int? ?? 4) : 4;
    final fyPrefix = getFiscalYear(date, fyStartMonth);
    final seqKey = '$docType-$fyPrefix';

    final rows = await db.query('sequences', where: 'seqKey=?', whereArgs: [seqKey]);
    int nextVal = rows.isEmpty ? 1 : (rows.first['seqValue'] as int) + 1;

    return '$docType-$fyPrefix-$nextVal';
  }

  // ------------------------------------------
  // PDF Generation Optimization
  // ------------------------------------------

  static Future<Map<String, dynamic>> _preparePdfTheme(Map<String, dynamic> biz, Map<String, dynamic> tax, double fs, bool is57mm) async {
    final fonts = await _loadPdfFonts();

    pw.TextStyle ts({num d = 0, bool bold = false, bool italic = false, PdfColor color = PdfColors.black}) => pw.TextStyle(fontSize: fs + d.toDouble(), font: bold ? fonts['bold'] : italic ? fonts['italic'] : fonts['regular'], color: color);

    return {
      'fonts': fonts, 'tax': tax, 'ts': ts,
      'upiString': 'upi://pay?pa=${biz['upiId'] ?? ''}&pn=${Uri.encodeComponent(biz['upiName'] as String? ?? '')}&cu=${_getCurrencyCode(appSettingsNotifier.currencySymbol)}',
      'watermark': () => pw.Center(child: pw.Transform.rotate(angle: 0.5, child: pw.Text('CANCELLED', style: ts(d: is57mm ? 30 : 60, bold: true, color: PdfColors.red100)))),
      'sigLine': (String label) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [pw.Container(width: is57mm ? 75 : 120, height: 1, color: PdfColors.black), pw.SizedBox(height: 4), pw.Text(label, style: ts(d: -1))]),
      'header': [
        if ((biz['name'] as String? ?? '').isNotEmpty) pw.Text(biz['name'] as String, style: ts(d: 4, bold: true)),
        if ((biz['phone'] as String? ?? '').isNotEmpty) pw.Text('Ph: ${biz['phone']}${biz['phone2']?.toString().isNotEmpty == true ? ' | ${biz['phone2']}' : ''}', style: ts()),
        if ((biz['email'] as String? ?? '').isNotEmpty) pw.Text(biz['email'] as String, style: ts()),
        if ((biz['address'] as String? ?? '').isNotEmpty) pw.Text(biz['address'] as String, style: ts()),
        if (tax['enabled'] == true) ...[pw.Text('${tax['label']}: ${tax['rate']}% (${tax['mode']})', style: ts()), if ((tax['regNo'] as String? ?? '').isNotEmpty) pw.Text('${tax['regLabel']}: ${tax['regNo']}', style: ts())],
        if ((biz['upiId'] as String? ?? '').isNotEmpty) pw.Text('UPI: ${biz['upiId']}', style: ts()),
        pw.Divider(),
      ],
      'finRow': (String l, String v, {bool bold = false}) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(l, style: ts(bold: bold)), pw.Text(v, style: ts(bold: bold))])
    };
  }

  static Future<Uint8List> generatePdfProformaForOrder(int orderId, {String pageSize = 'A4'}) async {
    final db = await getDatabase();
    final order = (await db.query('orders', where: 'id=?', whereArgs: [orderId])).first;
    final rentals = await getRentalsByOrder(orderId);
    final biz = await getBusinessInfo();
    final custRows = await db.query('customers', where: 'name=?', whereArgs: [order['customerName']], limit: 1);
    final custTaxRegNo = custRows.firstOrNull?['taxRegNo'] as String? ?? '';
    final custEmail = custRows.firstOrNull?['email'] as String? ?? '';

    final is57mm = pageSize == '57mm';
    final tax = buildTaxSettings(order['taxType'] as String? ?? 'none', order['taxMode'] as String? ?? 'exclusive', (order['taxRate'] as num?)?.toDouble() ?? 0.0, order['taxRegNo'] as String? ?? '');
    final theme = await _preparePdfTheme(biz, tax, is57mm ? 8.0 : 11.0, is57mm);
    final pw.TextStyle Function({double d, bool bold, bool italic, PdfColor color}) ts = theme['ts'];

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
        pageTheme: pw.PageTheme(pageFormat: is57mm ? const PdfPageFormat(57*PdfPageFormat.mm, 200*PdfPageFormat.mm, marginAll:4*PdfPageFormat.mm) : PdfPageFormat.a4, theme: pw.ThemeData.withFont(base: theme['fonts']['regular']!, bold: theme['fonts']['bold']!, italic: theme['fonts']['italic']!), buildBackground: (_) => rentals.any((r) => (r['isCancelled'] as int? ?? 0) == 1) ? pw.FullPage(ignoreMargins: true, child: theme['watermark']()) : pw.SizedBox()),
        build: (_) => [
          ...theme['header'],
          pw.Text('PROFORMA', style: ts(d: 2, bold: true)), pw.SizedBox(height: 4),
          pw.Text('Proforma #: ${order['proformaNumber']?.toString().isNotEmpty == true ? order['proformaNumber'] : 'ORD-$orderId'}', style: ts()),
          pw.Text('Date: ${formatDateString(order['createdDate'] as String? ?? '')}', style: ts()), pw.Divider(),
          pw.Row(children: [pw.Text('BILL TO: ', style: ts(bold: true)), pw.Text(order['customerName'] as String? ?? '', style: ts())]),
          if (custTaxRegNo.isNotEmpty && theme['tax']['enabled'] == true) pw.Text('${theme['tax']['regLabel']}: $custTaxRegNo', style: ts()),
          if (rentals.isNotEmpty && ((rentals.first['phone'] as String?) ?? '').isNotEmpty) pw.Text('Ph: ${rentals.first['phone']}${rentals.first['phone2']?.toString().isNotEmpty == true ? ' | ${rentals.first['phone2']}' : ''}', style: ts()),
          if (custEmail.isNotEmpty) pw.Text('Email: $custEmail', style: ts()),
          if (rentals.isNotEmpty && ((rentals.first['address'] as String?) ?? '').isNotEmpty) pw.Text('Site: ${rentals.first['address']}', style: ts()),
          pw.Divider(),
          pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(width: 0.3),
              cellPadding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              headerStyle: ts(bold: true),
              cellStyle: ts(),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
              },
              headers: ['Item', 'Qty', 'Rate/Day'],
              data: rentals.map((r) => [r['itemName'] ?? '', (r['qty'] ?? 0).toString(), formatMoney(((r['rentalRate'] as num?)?.toDouble() ?? 0.0))]).toList()
          ),
          pw.Divider(),
          if (rentals.fold(0.0, (s, r) => s + ((r['advanceDeposit'] as num?)?.toDouble() ?? 0.0)) > 0) pw.Text('Advance/Security: ${formatMoney(rentals.fold(0.0, (s, r) => s + ((r['advanceDeposit'] as num?)?.toDouble() ?? 0.0)))}', style: ts()),
          pw.Text('Note: This is a Proforma (estimated rental summary).', style: ts(d: -1, italic: true)),
          pw.SizedBox(height: 6),
          pw.Center(child: pw.Text('Thank you!', style: ts(italic: true))),
          if (appSettingsNotifier.showProformaSignatures) ...[
            pw.SizedBox(height: 30),
            is57mm
                ? pw.Column(children: [pw.Center(child: theme['sigLine']('Customer Signature')), pw.SizedBox(height: 30), pw.Center(child: theme['sigLine']('Vendor Signature'))])
                : pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [theme['sigLine']('Customer Signature'), theme['sigLine']('Vendor Signature')]),
          ],
          if ((biz['upiId'] as String? ?? '').isNotEmpty) ...[pw.SizedBox(height: 30), pw.Center(child: pw.Column(children: [pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: theme['upiString'], width: 70, height: 70), pw.Text(biz['upiName'] as String? ?? '', style: ts(bold: true)), pw.Text('UPI: ${biz['upiId']}', style: ts(d: -2))]))],
        ]
    ));
    return doc.save();
  }

  static Future<Uint8List> generatePdfFinalInvoiceForOrder(int orderId, {String pageSize = 'A4'}) async {
    final db = await getDatabase();
    final order = (await db.query('orders', where: 'id=?', whereArgs: [orderId])).first;
    final rentals = await getRentalsByOrder(orderId);
    final biz = await getBusinessInfo();
    final custRows = await db.query('customers', where: 'name=?', whereArgs: [order['customerName']], limit: 1);
    final custTaxRegNo = custRows.firstOrNull?['taxRegNo'] as String? ?? '';
    final custEmail = custRows.firstOrNull?['email'] as String? ?? '';
    final logs = (await getPaymentLogsForGroups([RentalGroup(orderId: orderId, items: rentals)])).values.firstOrNull ?? [];

    final is57mm = pageSize == '57mm';
    final tax = buildTaxSettings(order['taxType'] as String? ?? 'none', order['taxMode'] as String? ?? 'exclusive', (order['taxRate'] as num?)?.toDouble() ?? 0.0, order['taxRegNo'] as String? ?? '');
    final theme = await _preparePdfTheme(biz, tax, is57mm ? 8.0 : 11.0, is57mm);
    final pw.TextStyle Function({double d, bool bold, bool italic, PdfColor color}) ts = theme['ts'];
    final pw.Widget Function(String, String, {bool bold}) finRow = theme['finRow'];

    double lineSubtotal = 0.0, totalPenalty = 0.0; DateTime? finalRet;
    final lineData = <List<String>>[];
    final List<pw.Widget> customLineItems57mm = [];

    for (final r in rentals) {
      final days = _rentalChargeDays(r);
      final lineTotal = ((r['rentalRate'] as num?)?.toDouble() ?? 0.0) * (r['qty'] as int? ?? 0) * days;
      lineSubtotal += lineTotal;
      totalPenalty += (r['penaltyFee'] as num?)?.toDouble() ?? 0.0;

      final itemNameFormatted = '${r['itemName']} | Return date: ${formatDateString(r['returnDate'] as String?)}';
      final qtyStr = (r['qty'] ?? 0).toString();
      final rateStr = formatMoney(((r['rentalRate'] as num?)?.toDouble() ?? 0.0));
      final daysStr = days.toString();
      final totalStr = formatMoney(lineTotal);

      lineData.add([itemNameFormatted, qtyStr, rateStr, daysStr, totalStr]);

      if (is57mm) {
        customLineItems57mm.add(
            pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(itemNameFormatted, style: ts(bold: true)),
                  pw.SizedBox(height: 2),
                  pw.TableHelper.fromTextArray(
                    context: null,
                    border: pw.TableBorder.all(width: 0.3),
                    cellPadding: const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 2),
                    headerStyle: ts(bold: true),
                    cellStyle: ts(),
                    headers: ['Qty', 'Rate/Day', 'Days', 'Amount'],
                    data: [[qtyStr, rateStr, daysStr, totalStr]],
                    cellAlignment: pw.Alignment.center,
                  ),
                  pw.SizedBox(height: 6),
                ]
            )
        );
      }

      final rd = _safeParseDate(r['returnDate']); if (rd != null && (finalRet == null || rd.isAfter(finalRet))) finalRet = rd;
    }

    final discount = rentals.fold(0.0, (s, r) => s + ((r['discount'] as num?)?.toDouble() ?? 0.0));
    final totals = _taxBreakdown((lineSubtotal + totalPenalty) - discount, tax);
    final badDebt = rentals.fold(0.0, (s, r) => s + ((r['badDebt'] as num?)?.toDouble() ?? 0.0));

    // [CPA & AAD] Granular Ledger Breakdown for Final Invoice PDF
    double advancePaid = 0.0;
    double laterPayments = 0.0;
    double totalRefunds = 0.0;

    if (logs.isNotEmpty) {
      for (var p in logs) {
        double amt = (p['amount'] as num).toDouble();
        if (amt < 0) {
          totalRefunds += amt.abs();
        } else {
          String pDate = (p['paidAt'] as String).split('T')[0];
          String cDate = (order['createdDate'] as String).split('T')[0];
          if (pDate == cDate && advancePaid == 0.0 && p['id'] == logs.first['id']) {
            advancePaid += amt;
          } else {
            laterPayments += amt;
          }
        }
      }
    } else {
      final rawAdv = rentals.fold(0.0, (s, r) => s + ((r['advanceDeposit'] as num?)?.toDouble() ?? 0.0));
      if (rawAdv < 0) {
        totalRefunds = rawAdv.abs();
      } else {
        advancePaid = rawAdv;
      }
    }

    // Balance = Billed - Advance - Subsequent Payments + Refunds Issued - Bad Debt Written Off
    final balance = (totals['grandTotal'] ?? 0.0) - advancePaid - laterPayments + totalRefunds - badDebt;

    final List<pw.Widget> taxRows = [];
    if (tax['enabled'] == true) {
      taxRows.add(finRow('Taxable Base:', formatMoney(totals['taxableBase'] ?? 0.0)));
      if (tax['type'] == 'gst') {
        bool isInterState = false;
        final bizGst = tax['regNo'] as String? ?? '';
        if (bizGst.length >= 2 && custTaxRegNo.length >= 2) {
          if (bizGst.substring(0, 2) != custTaxRegNo.substring(0, 2)) {
            isInterState = true;
          }
        }
        if (isInterState) {
          taxRows.add(finRow('IGST (${tax['rate']}%):', '+ ${formatMoney(totals['taxAmount'] ?? 0.0)}'));
        } else {
          final halfRate = (tax['rate'] as num).toDouble() / 2;
          final halfTax = (totals['taxAmount'] as num).toDouble() / 2;
          taxRows.add(finRow('CGST (${halfRate.toStringAsFixed(1)}%):', '+ ${formatMoney(halfTax)}'));
          taxRows.add(finRow('SGST (${halfRate.toStringAsFixed(1)}%):', '+ ${formatMoney(halfTax)}'));
        }
      } else {
        taxRows.add(finRow('${tax['label']} (${tax['rate']}%):', '+ ${formatMoney(totals['taxAmount'] ?? 0.0)}'));
      }
    }

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
        pageTheme: pw.PageTheme(pageFormat: is57mm ? const PdfPageFormat(57*PdfPageFormat.mm, 220*PdfPageFormat.mm, marginAll:4*PdfPageFormat.mm) : PdfPageFormat.a4, theme: pw.ThemeData.withFont(base: theme['fonts']['regular']!, bold: theme['fonts']['bold']!, italic: theme['fonts']['italic']!), buildBackground: (_) => rentals.any((r) => (r['isCancelled'] as int? ?? 0) == 1) ? pw.FullPage(ignoreMargins: true, child: theme['watermark']()) : pw.SizedBox()),
        build: (_) => [
          ...theme['header'],
          pw.Text('FINAL INVOICE', style: ts(d: 2, bold: true)), pw.SizedBox(height: 4),
          pw.Text('Invoice #: ${order['invoiceNumber']?.toString().isNotEmpty == true ? order['invoiceNumber'] : 'INV-$orderId'}', style: ts()),
          if (order['proformaNumber']?.toString().isNotEmpty == true) pw.Text('Ref Proforma: ${order['proformaNumber']}', style: ts(d: -1, italic: true)),
          pw.Text('Order Date: ${formatDateString(order['createdDate'] as String? ?? '')}', style: ts()), pw.Text('Invoice Date: ${finalRet == null ? 'Pending' : formatDateFromDt(finalRet)}', style: ts()), pw.Divider(),
          pw.Row(children: [pw.Text('BILL TO: ', style: ts(bold: true)), pw.Text(order['customerName'] as String? ?? '', style: ts())]),
          if (custTaxRegNo.isNotEmpty && tax['enabled'] == true) pw.Text('${tax['regLabel']}: $custTaxRegNo', style: ts()),
          if (rentals.isNotEmpty && ((rentals.first['phone'] as String?) ?? '').isNotEmpty) pw.Text('Ph: ${rentals.first['phone']}${rentals.first['phone2']?.toString().isNotEmpty == true ? ' | ${rentals.first['phone2']}' : ''}', style: ts()),
          if (custEmail.isNotEmpty) pw.Text('Email: $custEmail', style: ts()),
          if (rentals.isNotEmpty && ((rentals.first['address'] as String?) ?? '').isNotEmpty) pw.Text('Site: ${rentals.first['address']}', style: ts()),
          pw.Divider(),

          if (is57mm)
            ...customLineItems57mm
          else
            pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(width: 0.3),
                cellPadding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                headerStyle: ts(bold: true),
                cellStyle: ts(),
                headers: ['Item', 'Qty', 'Rate/Day', 'Days', 'Line Total'],
                data: lineData
            ),

          pw.Divider(borderStyle: pw.BorderStyle.dashed),
          finRow('Rentals Subtotal:', formatMoney(lineSubtotal)),
          if (totalPenalty > 0) finRow('Damage Penalties:', '+ ${formatMoney(totalPenalty)}'),
          if (discount > 0) finRow('Discount:', '- ${formatMoney(discount)}'),
          ...taxRows,
          pw.Divider(),
          finRow('TOTAL BILLED:', formatMoney(totals['grandTotal'] ?? 0.0, absolute: true), bold: true),
          if (advancePaid > 0) finRow('Advance/Security:', '- ${formatMoney(advancePaid)}'),
          if (laterPayments > 0) finRow('Payment(s) Rcvd:', '- ${formatMoney(laterPayments)}'),
          if (totalRefunds > 0) finRow('Refund(s) Issued:', '+ ${formatMoney(totalRefunds)}'),
          if (badDebt > 0) finRow('Written Off (Bad Debt):', '- ${formatMoney(badDebt)}'),
          pw.Divider(),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text(
                balance > 0.001 ? 'BALANCE DUE:' : (balance < -0.001 ? 'REFUND DUE:' : 'BALANCE DUE:'),
                style: theme['ts'](bold: true, d: 1)
            ),
            pw.Text(formatMoney(balance.abs()), style: theme['ts'](bold: true, d: 1))
          ]),
          pw.SizedBox(height: 10), pw.Center(child: pw.Text(rentals.every((r) => (r['isSettled'] as int? ?? 0) == 1) ? '*** SETTLED ***' : '*** PENDING ***', style: ts(bold: true))),
          if (appSettingsNotifier.showInvoiceSignatures) ...[pw.SizedBox(height: 30), theme['sigLine']('Authorized Signature')],
          if ((biz['upiId'] as String? ?? '').isNotEmpty) ...[pw.SizedBox(height: 20), pw.Center(child: pw.Column(children: [pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: theme['upiString'], width: 60, height: 60), pw.Text('Scan to Pay', style: ts(d: -2))]))],
        ]
    ));
    return doc.save();
  }

  static Future<String> exportBackup() async {
    try {
      final biz = await getBusinessInfo();
      final bizName = (biz['name'] as String? ?? '').trim().isEmpty ? 'Rental_Manager' : (biz['name'] as String).trim().replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
      final timeStamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final dynamicFileName = '${bizName}_Backup_$timeStamp.db';

      final prefs = await SharedPreferences.getInstance();
      final currentDbName = prefs.getString('active_db_file') ?? _activeDbFile;

      final dir = await getApplicationDocumentsDirectory();
      final dbFile = File('${dir.path}/$currentDbName');

      if (!await dbFile.exists()) return 'Source database not found.';

      final bytes = await dbFile.readAsBytes();
      final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Database Backup',
          fileName: dynamicFileName,
          type: FileType.any,
          bytes: bytes
      );
      return path == null ? 'Backup cancelled' : 'Backup saved successfully!';
    } catch (e) {
      return 'Backup failed: $e';
    }
  }

  static Future<String> importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null) return 'No file selected';
      final prefs = await SharedPreferences.getInstance();
      final target = prefs.getString('active_db_file') ?? _activeDbFile;
      await closeDatabase();
      final dir = await getApplicationDocumentsDirectory();
      await File(result.files.single.path!).copy('${dir.path}/$target');
      return 'Restored successfully. Please restart the app.';
    } catch (e) { return 'Restore failed: $e'; }
  }

  // ------------------------------------------
  // ADVANCED ACCOUNTING: ASSET DEPRECIATION & ROI
  // ------------------------------------------
  static Future<List<Map<String, dynamic>>> getInventoryValuationReport({String method = 'SLM'}) async {
    final db = await getDatabase();
    final now = DateTime.now();

    // Fetch all capital items (ignoring items with no purchase price to save memory)
    final items = await db.query('items', where: 'purchasePrice > 0');

    List<Map<String, dynamic>> valuationList = [];

    for (final item in items) {
      final id = item['id'] as int;
      final name = item['name'] as String;
      final totalQty = item['total'] as int? ?? 0;
      final unitPrice = (item['purchasePrice'] as num?)?.toDouble() ?? 0.0;
      final lifeMonths = item['expectedLifeMonths'] as int? ?? 0;
      final purchaseDateStr = item['purchaseDate'] as String? ?? '';

      double initialCost = unitPrice * totalQty;
      double currentBookValue = initialCost;
      double accumulatedDepreciation = 0.0;

      if (lifeMonths > 0 && purchaseDateStr.isNotEmpty) {
        final pDate = DateTime.tryParse(purchaseDateStr) ?? now;
        int monthsElapsed = (now.year - pDate.year) * 12 + now.month - pDate.month;
        if (monthsElapsed < 0) monthsElapsed = 0;

        if (method == 'WDV') {
          // Written Down Value (using Double Declining Balance proxy for tax optimization)
          double lifeYears = lifeMonths / 12.0;
          double wdvRate = lifeYears > 0 ? (2.0 / lifeYears) : 1.0;
          if (wdvRate > 1.0) wdvRate = 1.0;

          int fullYears = monthsElapsed ~/ 12;
          int remainingMonths = monthsElapsed % 12;
          double bv = initialCost;

          // Apply full year depreciation sequentially
          for (int i = 0; i < fullYears; i++) {
            bv -= (bv * wdvRate);
          }
          // Apply pro-rata depreciation for the remaining fractional year
          bv -= (bv * wdvRate * (remainingMonths / 12.0));

          currentBookValue = bv > 0 ? bv : 0.0;
          accumulatedDepreciation = initialCost - currentBookValue;

        } else {
          // Straight-Line Method (SLM)
          if (monthsElapsed > lifeMonths) monthsElapsed = lifeMonths;
          final monthlyDepreciation = initialCost / lifeMonths;
          accumulatedDepreciation = monthlyDepreciation * monthsElapsed;
          currentBookValue = initialCost - accumulatedDepreciation;
        }
      }

      // Calculate lifetime ROI for this specific item class
      final rentals = await db.rawQuery(
          '''
        SELECT SUM(
          (qty * rentalRate * MAX(1, CAST(julianday(date(IFNULL(NULLIF(returnDate, ''), date('now', 'localtime')))) - julianday(date(checkoutDate)) AS INTEGER)))
          + penaltyFee - discount
        ) as revenue 
        FROM rentals 
        WHERE itemId = ? AND isCancelled = 0
        ''',
          [id]
      );

      final generatedRevenue = (rentals.first['revenue'] as num?)?.toDouble() ?? 0.0;
      final roiPercentage = initialCost > 0 ? (generatedRevenue / initialCost) * 100 : 0.0;

      valuationList.add({
        'id': id,
        'name': name,
        'totalQty': totalQty,
        'initialCost': initialCost,
        'bookValue': currentBookValue,
        'accumulatedDepreciation': accumulatedDepreciation,
        'generatedRevenue': generatedRevenue,
        'roiPercentage': roiPercentage,
        'depreciationMethod': method,
      });
    }

    // Sort by Highest Revenue Generator by default
    valuationList.sort((a, b) => (b['generatedRevenue'] as double).compareTo(a['generatedRevenue'] as double));

    return valuationList;
  }

  // ------------------------------------------
  // ADVANCED ACCOUNTING: MAINTENANCE & REPAIRS (OPEX)
  // ------------------------------------------

  /// Safely creates the maintenance table dynamically to avoid
  /// conflicting with your existing v26 schema migration logic.
  static Future<void> _ensureMaintenanceTableExists(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS maintenance_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemId INTEGER NOT NULL,
        description TEXT NOT NULL,
        cost REAL NOT NULL,
        logDate TEXT NOT NULL,
        FOREIGN KEY (itemId) REFERENCES items (id) ON DELETE CASCADE
      )
    ''');
  }

  /// Logs a repair against an item AND updates the general ledger (expenses)
  static Future<void> logMaintenance(int itemId, String itemName, String description, double cost, String date) async {
    final db = await getDatabase();
    await _ensureMaintenanceTableExists(db);

    // 1. Log against the specific inventory asset
    await db.insert('maintenance_logs', {
      'itemId': itemId,
      'description': description,
      'cost': cost,
      'logDate': date,
    });

    // 2. Fiscal Link: Automatically inject into the general expenses table
    // Note: Assumes your expense table is named 'expenses' with standard columns.
    try {
      await db.insert('expenses', {
        'type': 'Expense',
        'category': 'Equipment Repair',
        'amount': cost,
        'date': date,
        'notes': 'Auto-logged: [$itemName] $description',
      });
    } catch (e) {
      debugPrint('Warning: Expense ledger injection failed. Check expenses table schema. Error: $e');
    }
  }

  /// Retrieves the repair history for a specific asset
  static Future<List<Map<String, dynamic>>> getMaintenanceHistory(int itemId) async {
    final db = await getDatabase();
    await _ensureMaintenanceTableExists(db);
    return await db.query('maintenance_logs', where: 'itemId = ?', whereArgs: [itemId], orderBy: 'logDate DESC');
  }

  // --- Analytical Reporting Endpoints ---
  static Future<Map<String, dynamic>> getProfitAndLoss(String period) async {
    final db = await getDatabase();
    final revResult = await db.rawQuery("SELECT SUM((qty * rentalRate * MAX(1, CAST(julianday(date(IFNULL(NULLIF(returnDate, ''), date('now', 'localtime')))) - julianday(date(checkoutDate)) AS INTEGER))) + penaltyFee) as rev, SUM(penaltyFee) as pen, SUM(discount) as disc, SUM(badDebt) as bd FROM rentals WHERE isCancelled = 0");
    final expResult = await db.rawQuery("SELECT SUM(CASE WHEN type = 'Revenue' THEN -amount ELSE amount END) as exp FROM expenses WHERE category != 'Asset Procurement (PO)'");
    double rev = (revResult.first['rev'] as num?)?.toDouble() ?? 0.0;
    double pen = (revResult.first['pen'] as num?)?.toDouble() ?? 0.0;
    double disc = (revResult.first['disc'] as num?)?.toDouble() ?? 0.0;
    double bd = (revResult.first['bd'] as num?)?.toDouble() ?? 0.0;
    double exp = (expResult.first['exp'] as num?)?.toDouble() ?? 0.0;
    return {'revenue': rev, 'penalties': pen, 'discounts': disc, 'badDebt': bd, 'expenses': exp, 'net': rev - exp - bd};
  }

  static Future<List<Map<String, dynamic>>> getARAging() async {
    final db = await getDatabase();
    return await db.rawQuery('''
      SELECT contractor as name,
             SUM(CASE WHEN days <= 30 THEN bal ELSE 0 END) as '0_30',
             SUM(CASE WHEN days > 30 AND days <= 60 THEN bal ELSE 0 END) as '31_60',
             SUM(CASE WHEN days > 60 AND days <= 90 THEN bal ELSE 0 END) as '61_90',
             SUM(CASE WHEN days > 90 THEN bal ELSE 0 END) as '90_plus',
             SUM(bal) as total, MAX(days) as oldest_inv
      FROM (SELECT contractor, CAST(julianday(date('now', 'localtime')) - julianday(date(returnDate)) AS INTEGER) as days,
               ((qty * rentalRate * MAX(1, CAST(julianday(date(IFNULL(NULLIF(returnDate, ''), date('now', 'localtime')))) - julianday(date(checkoutDate)) AS INTEGER))) + penaltyFee - advanceDeposit - discount - badDebt) as bal
        FROM rentals WHERE (returned=1) AND isSettled=0 AND isCancelled=0
      ) WHERE bal > 0 GROUP BY contractor ORDER BY total DESC
    ''');
  }

  static Future<Map<String, dynamic>> getTaxLiability(String period) async {
    final db = await getDatabase();

    final lines = await db.rawQuery(
        "SELECT rentals.*, items.name as itemName, "
            "orders.taxType, orders.taxRate, orders.taxMode, orders.taxRegNo "
            "FROM rentals JOIN items ON rentals.itemId=items.id "
            "LEFT JOIN orders ON orders.id=rentals.orderId "
            "WHERE COALESCE(rentals.isCancelled, 0) = 0"
    );

    final groups = groupRentalsByInvoice(lines);
    double totalBase = 0.0;
    double totalTax = 0.0;

    for (final g in groups) {
      final netSubtotal = g.calculateTotalCost() - g.discount;
      final taxSettings = buildTaxSettings(g.taxType, g.taxMode, g.taxRate, g.taxRegNo);
      final breakdown = _taxBreakdown(netSubtotal, taxSettings);

      totalBase += (breakdown['taxableBase'] as num?)?.toDouble() ?? 0.0;
      totalTax += (breakdown['taxAmount'] as num?)?.toDouble() ?? 0.0;
    }

    return {'base': totalBase, 'collected': totalTax};
  }
}

// ========Rental Group & Shared Models========
class RentalGroup {
  final int? orderId, fallbackId;
  final List<Map<String, dynamic>> items;
  RentalGroup({this.orderId, this.fallbackId, required this.items});

  String get proformaNumber => items.first['proformaNumber'] as String? ?? '';
  String get invoiceNumber => items.first['invoiceNumber'] as String? ?? '';

  bool get isGroup         => orderId != null;
  bool get isFullyReturned => items.every((r) => r['returned'] == 1);
  bool get isSettled       => items.every((r) => r['isSettled'] == 1);
  bool get isCancelled     => items.every((r) => (r['isCancelled'] as int? ?? 0) == 1);
  String get contractor    => items.first['contractor']    as String? ?? '';
  String get phone         => items.first['phone']         as String? ?? '';
  String get address       => items.first['address']       as String? ?? '';
  String get checkoutDate  => items.first['checkoutDate']  as String? ?? '';
  String get notes         => items.first['notes']         as String? ?? '';
  String get phone2        => items.first['phone2']        as String? ?? '';
  String get paymentMethod => items.first['paymentMethod'] as String? ?? '';
  String get proformaNo    => items.first['proformaNo']    as String? ?? '';
  String get invoiceNo     => items.first['invoiceNo']     as String? ?? '';

  String get paymentGroupKey => orderId != null
      ? 'o:$orderId'
      : 'f:${fallbackId ?? (items.firstOrNull?['id'] as int? ?? 0)}';
  double get advance => items.fold(0.0, (s, r) => s + ((r['advanceDeposit'] as num?)?.toDouble() ?? 0.0));
  double get discount => items.fold(0.0, (s, r) => s + ((r['discount'] as num?)?.toDouble() ?? 0.0));
  double get badDebt => items.fold(0.0, (s, r) => s + ((r['badDebt'] as num?)?.toDouble() ?? 0.0));

  // CPA FIX: Standalone legacy rentals must default to 'none'/0.0, NOT the live business tax settings to maintain historical immutability.
  String get taxType => orderId != null ? (items.first['taxType'] as String? ?? 'none') : 'none';
  double get taxRate => orderId != null ? ((items.first['taxRate'] as num?)?.toDouble() ?? 0.0) : 0.0;
  String get taxMode => orderId != null ? (items.first['taxMode'] as String? ?? 'exclusive') : 'exclusive';
  String get taxRegNo => orderId != null ? (items.first['taxRegNo'] as String? ?? '') : '';

  double get grandTotal {
    final tax = DatabaseHelper.buildTaxSettings(taxType, taxMode, taxRate, taxRegNo);
    // Standard CPA practice: Calculate net subtotal before applying tax engine
    final netSubtotal = calculateTotalCost() - discount;
    final totals = DatabaseHelper._taxBreakdown(netSubtotal, tax);
    return totals['grandTotal'] ?? netSubtotal;
  }

  double get balance => grandTotal - advance - badDebt;

  double calculateTotalCost() {
    if (isCancelled) return 0.0;
    double total = 0.0;
    for (final r in items) {
      if ((r['isCancelled'] as int? ?? 0) == 1) continue;
      final qty  = r['qty']  as int? ?? 0;
      final rate = (r['rentalRate'] as num?)?.toDouble() ?? 0.0;
      final penalty = (r['penaltyFee'] as num?)?.toDouble() ?? 0.0;
      final days = RentalUtils.calculateChargeDays(
        r['checkoutDate'] as String?,
        r['returnDate'] as String?,
        r['returned'] as int? ?? 0,
      );
      total += (rate * days * qty) + penalty;
    }
    return total;
  }
}

List<RentalGroup> groupRentalsByInvoice(List<Map<String, dynamic>> rawData) {
  // Merge rental lines into invoice groups: by orderId when present, else standalone rental ID.
  final orderMap = <int, List<Map<String, dynamic>>>{};
  final groups   = <RentalGroup>[];
  for (final r in rawData) {
    final oid = r['orderId'] as int?;
    if (oid != null) { orderMap.putIfAbsent(oid, () => []).add(r); }
    else             { groups.add(RentalGroup(fallbackId: r['id'] as int, items: [r])); }
  }
  for (final e in orderMap.entries) { groups.add(RentalGroup(orderId: e.key, items: e.value)); }
  groups.sort((a, b) => b.checkoutDate.compareTo(a.checkoutDate));
  return groups;
}

// ======= class Rental Utils========

class RentalUtils {
  static int calculateChargeDays(String? checkoutDateStr, String? returnDateStr, int returned) {
    DateTime checkout = DateTime.now();
    try {
      if (checkoutDateStr != null && checkoutDateStr.isNotEmpty) {
        checkout = DateTime.parse(checkoutDateStr);
      }
    } catch (_) {}

    DateTime end = DateTime.now();
    if (returned == 1 && returnDateStr != null && returnDateStr.isNotEmpty) {
      try {
        end = DateTime.parse(returnDateStr);
      } catch (_) {}
    }

    // AAD/CPA FIX: Strip time to enforce strict Calendar Day billing.
    // Prevents revenue loss from 23h59m being truncated to 0 days.
    DateTime pureCheckout = DateTime(checkout.year, checkout.month, checkout.day);
    DateTime pureEnd = DateTime(end.year, end.month, end.day);

    int days = pureEnd.difference(pureCheckout).inDays;
    if (days < 0) days = 0;

    // Standard policy: Same day return = 1 day minimum charge
    return days == 0 ? 1 : days;
  }
}

// =============================
// III. ROOT UI APP STRUCTURE
// =============================

// ========App Root========
class RentalManagerApp extends StatefulWidget {
  const RentalManagerApp({super.key});
  @override
  State<RentalManagerApp> createState() => _RentalManagerAppState();
}

class _RentalManagerAppState extends State<RentalManagerApp> {
  @override
  void initState() {
    super.initState();
    themeModeNotifier.addListener(_rebuild);
    // Removed appSettingsNotifier listener; InheritedNotifier handles this natively now.
  }

  @override
  void dispose() {
    themeModeNotifier.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() { if (mounted) setState(() {}); }

  ThemeData _theme(Brightness b) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber, brightness: b),
    appBarTheme: const AppBarTheme(backgroundColor: Colors.amber, foregroundColor: Colors.black87, centerTitle: true, elevation: 2),
    cardTheme: CardThemeData(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  @override
  Widget build(BuildContext context) => AppProvider(
    notifier: appSettingsNotifier,
    child: Builder(
        builder: (appContext) {
          final settings = AppProvider.of(appContext);

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Rental Manager',
            locale: settings.language == 'Hindi' ? const Locale('hi', 'IN') : const Locale('en', 'US'),
            supportedLocales: const [
              Locale('en', 'US'),
              Locale('hi', 'IN'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            themeMode: themeModeNotifier.mode,
            theme: _theme(Brightness.light),
            darkTheme: _theme(Brightness.dark),
            builder: (ctx, child) => MediaQuery(
              data: MediaQuery.of(ctx).copyWith(
                textScaler: TextScaler.linear(settings.textScale),
              ),
              child: child!,
            ),
            home: const MainShell(),
          );
        }
    ),
  );
}

// ========Main Shell & Hamburger Menu========

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _idx = 0;
  final _screens = const [DashboardScreen(), InventoryTab(), ActiveRentalsTab(), HistoryTab()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (mounted) {
          NotificationService.checkAndNotify();
          // Sync current business name to the switcher cache for accurate display
          final biz = await DatabaseHelper.getBusinessInfo();
          if (biz['name'].toString().trim().isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            final currentDb = prefs.getString('active_db_file') ?? 'rental_manager_v1.db';
            await prefs.setString('display_name_$currentDb', biz['name']);
          }
        }
      });
    });
  }

  void _nav(Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Rental Manager'),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
        )
      ],
    ),
    drawer: _buildDrawer(),
    body: _screens[_idx],
    bottomNavigationBar: NavigationBar(
      selectedIndex: _idx,
      onDestinationSelected: (i) => setState(() => _idx = i),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
        NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Inventory'),
        NavigationDestination(icon: Icon(Icons.handshake_outlined), selectedIcon: Icon(Icons.handshake), label: 'Rentals'),
        NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'History'),
      ],
    ),
  );

  Widget _buildDrawer() => Drawer(
    child: SafeArea(
      child: Column(
        children: [
          _buildDrawerBusinessHeader(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const Divider(height: 1),
                _drawerSectionLabel('MANAGEMENT'),
                _drawerNavItem(icon: Icons.store, title: 'Business Info', onTap: () => _nav(const BusinessInfoScreen())),
                _drawerNavItem(icon: Icons.group, title: 'Parties', onTap: () => _nav(const PartiesManagementScreen())),
                _drawerSectionLabel('TRANSACTIONS'),
                _drawerNavItem(icon: Icons.shopping_cart_checkout, title: 'POs & Bills', onTap: () => _nav(const PurchaseOrdersScreen())),
                _drawerNavItem(icon: Icons.account_balance_wallet, title: 'Ledgers', onTap: () => _nav(const PaymentLedgerScreen())),
                _drawerNavItem(icon: Icons.receipt_long, title: 'Proformas & Invoices', onTap: () => _nav(const InvoiceManagerScreen())),
                _drawerSectionLabel('ACCOUNTING'),
                _drawerNavItem(icon: Icons.bar_chart, title: 'Financial Reports', onTap: () => _nav(const FinancialReportsScreen())),
                _drawerNavItem(icon: Icons.swap_horiz, title: 'Expense/Revenue', onTap: () => _nav(const ExpenseRevenueLedgerScreen())),
                _drawerNavItem(icon: Icons.money_off, title: 'Losses & Bad Debt', onTap: () => _nav(const LossesAndBadDebtScreen())),
                const Divider(height: 1),
                _drawerSectionLabel('DATA & SYSTEM'),
                ListTile(
                  leading: const Icon(Icons.save_alt),
                  title: const Text('Export Backup'),
                  onTap: () async {
                    Navigator.pop(context);
                    final result = await DatabaseHelper.exportBackup();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.upload),
                  title: const Text('Restore from Backup'),
                  onTap: () async {
                    final m = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    final result = await DatabaseHelper.importBackup();
                    m.showSnackBar(SnackBar(content: Text(result)));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  // Reorganized Business Info Header (The part you were looking for)
  Widget _buildDrawerBusinessHeader() => FutureBuilder<Map<String, dynamic>>(
    future: DatabaseHelper.getBusinessInfo(),
    builder: (context, snapshot) {
      final bizName = snapshot.data?['name'] as String? ?? '';
      final displayBizName = bizName.trim().isEmpty ? 'Rental Manager' : bizName;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final bgColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFF2A2A2A);

      return Material(
        color: bgColor,
        child: InkWell(
          onTap: _showAccountSwitchDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            width: double.infinity,
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.amber.shade600, width: 2),
                      ),
                      child: const Icon(Icons.person, color: Colors.white70, size: 32),
                    ),
                    Positioned(
                      bottom: -3,
                      right: -3,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent[400],
                          shape: BoxShape.circle,
                          border: Border.all(color: bgColor, width: 2.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        displayBizName,
                        style: TextStyle(color: Colors.amber.shade500, fontSize: 18, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Admin',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _drawerNavItem({required IconData icon, required String title, required VoidCallback onTap}) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    onTap: onTap,
  );

  Widget _drawerSectionLabel(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      title,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.4, color: Colors.amber[600]),
    ),
  );

  // Fiscal Note: Method bound to state to securely rebuild the navigation stack upon ledger change.
  Future<void> _showAccountSwitchDialog() async {
    final prefs = await SharedPreferences.getInstance();
    // Rebranded default file identity to Rental Manager
    final List<String> accountFiles = prefs.getStringList('registered_accounts') ?? ['rental_manager_v1.db'];
    final String currentActive = prefs.getString('active_db_file') ?? 'rental_manager_v1.db';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Switch Business A/C'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select an account to load its inventory and ledgers.', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 10),
              ...accountFiles.map((fileName) {
                final String cachedName = prefs.getString('display_name_$fileName') ?? '';
                final String displayName = cachedName.isNotEmpty
                    ? cachedName
                    : fileName.replaceAll('.db', '').replaceAll('_', ' ').replaceAll('v1', '').replaceAll('v3', '').trim().toUpperCase();

                return ListTile(
                  leading: Icon(Icons.account_balance, color: fileName == currentActive ? Colors.amber : Colors.grey),
                  title: Text(displayName),
                  subtitle: fileName == currentActive ? const Text('Active', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)) : null,
                  onTap: fileName == currentActive ? null : () async {
                    await DatabaseHelper.closeDatabase();
                    await prefs.setString('active_db_file', fileName);

                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();

                    if (!mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const MainShell()),
                          (route) => false,
                    );
                  },
                );
              }),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add_business, color: Colors.blue),
                title: const Text('Add New Business'),
                onTap: () async {
                  final nameC = TextEditingController();
                  final newName = await showDialog<String>(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: const Text('New Business Name'),
                      content: TextField(controller: nameC, decoration: const InputDecoration(hintText: 'e.g. South Branch')),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
                        ElevatedButton(onPressed: () => Navigator.pop(d, nameC.text.trim()), child: const Text('Create')),
                      ],
                    ),
                  );
                  if (!mounted) return;
                  if (newName != null && newName.isNotEmpty) {
                    final newFile = '${newName.replaceAll(' ', '_').toLowerCase()}.db';
                    if (!accountFiles.contains(newFile)) {
                      accountFiles.add(newFile);
                      await prefs.setStringList('registered_accounts', accountFiles);
                      await prefs.setString('display_name_$newFile', newName);
                      await DatabaseHelper.closeDatabase();
                      await prefs.setString('active_db_file', newFile);

                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();

                      // CPA Note: Explicitly check the parent context before stack reset
                      if (!mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const MainShell()),
                            (route) => false,
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }
}

// =============================
// IV. SHARED UI COMPONENTS
// =============================

// ========Universal Rental Card========
class UniversalRentalCard extends StatelessWidget {
  final RentalGroup group;
  final List<Map<String, dynamic>>? paymentLogs;
  final bool showCustomerName;
  final VoidCallback? onEdit, onReturn, onSettle, onPdf, onProforma, onCancel, onDelete, onViewPayments;

  const UniversalRentalCard({
    super.key, required this.group, this.paymentLogs, this.showCustomerName = true,
    this.onEdit, this.onReturn, this.onSettle, this.onPdf, this.onProforma, this.onCancel, this.onDelete, this.onViewPayments,
  });

  Widget _tag(String text, Color color) => Container(
    margin: const EdgeInsets.only(left: 6),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.bold)),
  );

  Widget _finRow(String lbl, String val, {Color? color, bool strike = false, bool bold = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(lbl, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      Text(val, style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal, decoration: strike ? TextDecoration.lineThrough : null))
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final settings = AppProvider.of(context);
    final compact = settings.cardDensity == 'compact';
    final divider = Divider(height: compact ? 10.0 : 16.0);
    final dayCount = RentalUtils.calculateChargeDays(group.checkoutDate, null, group.isFullyReturned ? 1 : 0);
    final isOverdue = !group.isFullyReturned && dayCount > settings.overdueDays;

    if (group.isFullyReturned) {
      final payments = paymentLogs ?? const [];
      if (payments.isNotEmpty) {
      } else {
      }
    }

    return Card(
      margin: EdgeInsets.only(bottom: compact ? 8 : 10),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: isOverdue ? const BoxDecoration(border: Border(left: BorderSide(color: Colors.orange, width: 4))) : null,
        padding: settings.cardPadding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (isOverdue) Padding(padding: EdgeInsets.only(right: compact ? 4 : 6), child: Icon(Icons.warning_amber_rounded, color: Colors.orange, size: compact ? 16 : 18)),
            Expanded(child: showCustomerName
                ? Text.rich(TextSpan(children: [
              TextSpan(text: group.contractor, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              if (group.phone.isNotEmpty) TextSpan(text: '  | Ph# ${group.phone}${group.phone2.isNotEmpty ? ' / ${group.phone2}' : ''}', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
            ]), overflow: TextOverflow.ellipsis)
                : Text(group.orderId != null ? (group.invoiceNumber.isNotEmpty ? '${group.invoiceNumber}${group.proformaNumber.isNotEmpty ? " ref ${group.proformaNumber}" : ""}' : (group.proformaNumber.isNotEmpty ? group.proformaNumber : 'ORD-${group.orderId}')) : (group.isFullyReturned ? 'Settled Rental' : 'Active Rental'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
            if (group.isCancelled) _tag('CANCELLED', Colors.redAccent)
            else if (group.badDebt > 0) _tag('BAD DEBT', Colors.redAccent)
            else if (group.isFullyReturned && group.isSettled) _tag('PAID', Colors.greenAccent),
            SizedBox(width: 32, child: PopupMenuButton<String>(
              tooltip: 'Options',
              onSelected: (val) {
                if (val == 'edit') { onEdit?.call(); }
                if (val == 'cancel') { onCancel?.call(); }
                if (val == 'delete') { onDelete?.call(); }
                if (val == 'pdf' && group.orderId != null) { onPdf?.call(); }
                if (val == 'proforma' && group.orderId != null) { onProforma?.call(); }
              },
              itemBuilder: (_) => [
                if (onEdit != null) const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit')])),
                if (onProforma != null && group.orderId != null) const PopupMenuItem(value: 'proforma', child: Row(children: [Icon(Icons.description_outlined, size: 18, color: Colors.blueAccent), SizedBox(width: 8), Text('View Proforma', style: TextStyle(color: Colors.blueAccent))])),
                if (onPdf != null && group.orderId != null) const PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf_outlined, size: 18, color: Colors.amber), SizedBox(width: 8), Text('Final Invoice', style: TextStyle(color: Colors.amber))])),
                if (onCancel != null && !group.isCancelled) const PopupMenuItem(value: 'cancel', child: Row(children: [Icon(Icons.cancel_outlined, size: 18, color: Colors.orange), SizedBox(width: 8), Text('Cancel Invoice', style: TextStyle(color: Colors.orange))])),
                if (onDelete != null) const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete Record', style: TextStyle(color: Colors.red))])),
              ],
              child: const Align(alignment: Alignment.centerRight, child: Icon(Icons.more_vert, size: 20)),
            )),
          ]),
          if (showCustomerName || group.address.isNotEmpty) Padding(padding: EdgeInsets.only(top: compact ? 1 : 2), child: Text.rich(TextSpan(style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color), children: [
            if (showCustomerName && group.orderId != null) ...[
              TextSpan(text: group.invoiceNumber.isNotEmpty ? group.invoiceNumber : (group.proformaNumber.isNotEmpty ? group.proformaNumber : 'ORD-${group.orderId}'), style: const TextStyle(fontWeight: FontWeight.bold)),
              if (group.invoiceNumber.isNotEmpty && group.proformaNumber.isNotEmpty) TextSpan(text: ' ref ${group.proformaNumber}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
              if (group.address.isNotEmpty) const TextSpan(text: '  |  '),
            ],
            if (group.address.isNotEmpty) TextSpan(text: 'Site: ${group.address}'),
          ]))),
          Padding(padding: EdgeInsets.only(top: compact ? 1 : 2), child: Text.rich(TextSpan(style: const TextStyle(fontSize: 14), children: [
            TextSpan(text: 'Checkout: ${DatabaseHelper.formatDateString(group.checkoutDate)}'),
            if (!group.isFullyReturned) ...[const TextSpan(text: '  |  '), TextSpan(text: '$dayCount days', style: TextStyle(fontWeight: FontWeight.w600, color: isOverdue ? Colors.orange : Colors.blue))],
          ]), overflow: TextOverflow.ellipsis)),
          divider,
          ...group.items.map((r) {
            final isRet = r['returned'] == 1;
            return Padding(padding: EdgeInsets.symmetric(vertical: compact ? 2 : 4), child: Row(children: [
              Icon(isRet ? Icons.check_circle : Icons.radio_button_checked, size: compact ? 14 : 16, color: isRet ? Colors.green : Colors.redAccent),
              const SizedBox(width: 8),
              Expanded(child: Text('${r['itemName']} x ${r['qty']} @ ${formatMoney(((r['rentalRate'] as num?)?.toDouble() ?? 0.0))}/day', style: TextStyle(fontSize: 13, color: isRet ? Colors.grey : null))),
              if (isRet) Text(DatabaseHelper.formatDateString(r['returnDate'] as String?), style: const TextStyle(color: Colors.green, fontSize: 11)),
            ]));
          }),
          if (group.notes.isNotEmpty) Padding(padding: EdgeInsets.only(top: compact ? 2 : 4), child: Text('Note: ${group.notes}', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12))),
          divider,
          Builder(
              builder: (context) {
                final taxRate = group.taxRate;
                final taxType = group.taxType;
                final taxMode = group.taxMode;

                final subtotal = group.calculateTotalCost(); // already contains penalty
                final penalty = group.items.fold(0.0, (s, r) => s + ((r['penaltyFee'] as num?)?.toDouble() ?? 0.0));
                final lineCostOnly = subtotal - penalty;

                double taxableBase = subtotal - group.discount;
                double taxAmount = 0.0;
                if (taxType != 'none' && taxRate > 0) {
                  if (taxMode == 'exclusive') {
                    taxAmount = taxableBase * (taxRate / 100.0);
                  } else {
                    taxAmount = taxableBase - (taxableBase / (1 + (taxRate / 100.0)));
                  }
                }

                double advancePaid = 0.0;
                double laterPayments = 0.0;
                double totalRefunds = 0.0;

                if (group.isFullyReturned) {
                  final payments = paymentLogs ?? const [];
                  if (payments.isNotEmpty) {
                    for (var p in payments) {
                      double amt = (p['amount'] as num).toDouble();
                      if (amt < 0) {
                        totalRefunds += amt.abs();
                      } else {
                        String pDate = (p['paidAt'] as String).split('T')[0];
                        String cDate = group.checkoutDate.split('T')[0];
                        // Check if the payment occurred identically to the checkout date
                        if (pDate == cDate && advancePaid == 0.0 && p['id'] == payments.first['id']) {
                          advancePaid += amt;
                        } else {
                          laterPayments += amt;
                        }
                      }
                    }
                  } else {
                    if (group.advance < 0) {
                      totalRefunds = group.advance.abs();
                    } else {
                      advancePaid = group.advance;
                    }
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!group.isFullyReturned) ...[
                      Text('Estimated Total: ${formatMoney(group.grandTotal)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (group.advance > 0) Row(mainAxisAlignment: MainAxisAlignment.start, children: [Text('Adv/Security: ${formatMoney(group.advance)}'), _PaymentLabel(group.paymentMethod)]),
                      if (group.advance < 0) Row(mainAxisAlignment: MainAxisAlignment.start, children: [Text('Refund Issued: ${formatMoney(group.advance.abs())}'), _PaymentLabel(group.paymentMethod)]),
                    ] else ...[
                      _finRow('Total Billed:', formatMoney(lineCostOnly), strike: group.isCancelled),
                      if (penalty > 0) _finRow('Penalty:', '+ ${formatMoney(penalty)}', color: Colors.redAccent),
                      if (group.discount > 0) _finRow('Discount:', '- ${formatMoney(group.discount)}'),
                      if (taxAmount > 0) _finRow('Tax (${taxRate.toStringAsFixed(1)}%):', '+ ${formatMoney(taxAmount)}'),
                      if (group.badDebt > 0) _finRow('Written Off:', '- ${formatMoney(group.badDebt)}', color: Colors.redAccent),

                      if (advancePaid > 0) _finRow('Advance/Security:', '- ${formatMoney(advancePaid)}'),
                      if (laterPayments > 0) _finRow('Payment(s):', '- ${formatMoney(laterPayments)}'),
                      if (totalRefunds > 0) _finRow('Refund(s):', '+ ${formatMoney(totalRefunds)}'),
                    ],
                  ],
                );
              }
          ),
          const SizedBox(height: 4),
          // Final Balance, Tight Payment Icon & Actions Inline
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  !group.isFullyReturned
                      ? 'Current Balance: ${formatMoney(group.balance)}'
                      : (group.isSettled ? 'Settled: Balance Cleared' : 'Final Balance: ${formatMoney(group.balance)}'),
                  style: TextStyle(
                      color: group.isCancelled ? Colors.grey : (group.isSettled ? Colors.grey : (group.balance > 0 ? Colors.orange : Colors.green)),
                      fontWeight: FontWeight.bold
                  ),
                ),
              ),
              if (onViewPayments != null)
                InkWell(
                  onTap: onViewPayments,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.receipt_long, color: Colors.amber, size: 22),
                  ),
                ),
              if (!group.isFullyReturned && onReturn != null) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Return'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    foregroundColor: Colors.blue,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onReturn,
                ),
              ],
            ],
          ),
        ]),
      ),
    );
  }
}

// ========Universal Search Bar========
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onClear;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.hint, required this.onClear, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: controller.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: onClear) : null,
      ),
      onChanged: onChanged,
    ),
  );
}

// ======== Universal Transaction Dialogs (Optimization Layer) ========
class TransactionDialogs {
  static Future<void> settle(BuildContext context, RentalGroup g, VoidCallback onSuccess) async {
    final payC = TextEditingController(text: g.balance.abs().toStringAsFixed(2));
    final discC = TextEditingController();
    String method = kPaymentMethods.first, discType = 'None';
    bool isBadDebt = false; DateTime payDate = DateTime.now();

    await AppUI.showFormDialog(context, title: g.balance < 0 ? 'Record Refund' : 'Record Payment', onSave: () async {
      final amt = double.tryParse(payC.text) ?? 0.0;
      final dVal = double.tryParse(discC.text) ?? 0.0;
      final absBal = g.balance.abs();
      final disc = isBadDebt ? 0.0 : (discType == 'Percentage' ? (g.calculateTotalCost() * (dVal/100)) : (discType == 'Flat' ? dVal : 0.0)).clamp(0.0, absBal);
      final isFull = (amt + disc) >= absBal - 0.01;

      if (amt + disc > absBal + 0.01) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Total exceeds balance.')));
        throw Exception('Validation Error');
      }

      try {
        if (isBadDebt) {
          await DatabaseHelper.writeOffBadDebt(g.items.first['id'] as int, amt, isFull ? g.items.map((i) => i['id'] as int).toList() : []);
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isFull ? 'Debt written off.' : 'Partial bad debt recorded.')));
        } else {
          await DatabaseHelper.addPaymentToRentalGroup(g.items.first['id'] as int, g.balance < 0 ? -amt : amt, isFull, g.items.map((i) => i['id'] as int).toList(), paymentMethod: method, discountAmount: disc, paidAt: DatabaseHelper.isoDate(payDate));
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isFull ? 'Settled fully.' : 'Partial recorded.')));
        }
        onSuccess();
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Settlement failed: $e')));
        rethrow;
      }
    }, children: [
      StatefulBuilder(builder: (ctx, setSt) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(g.balance < 0 ? 'Refund Due: ${formatMoney(g.balance.abs())}' : 'Total Remaining: ${formatMoney(g.balance.abs())}'),
        const SizedBox(height: 16),
        AppUI.buildTextField(controller: payC, label: g.balance < 0 ? 'Amount Refunded ($curr)' : 'Amount Paid ($curr)', type: const TextInputType.numberWithOptions(decimal: true), validator: (v) => (double.tryParse(v??'')??-1)<0 ? 'Invalid' : null),
        if (!isBadDebt) ...[
          DropdownButtonFormField<String>(initialValue: method, decoration: AppUI.inputDecoration('Method', i: Icons.payment), items: kPaymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: (v) => setSt(() => method = v!)),
          const SizedBox(height: 12), ListTile(contentPadding: EdgeInsets.zero, title: Text('Date: ${DatabaseHelper.formatDateFromDt(payDate)}'), trailing: const Icon(Icons.calendar_month), onTap: () async { final p = await AppUI.pickDateWithCurrentTime(ctx, payDate, lastDate: DateTime.now()); if (p != null) setSt(() => payDate = p); }),
        ],
        if (g.balance > 0) SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Write off Bad Debt', style: TextStyle(color: Colors.red)), subtitle: const Text('Customer defaulted.'), value: isBadDebt, activeThumbColor: Colors.red, onChanged: (v) => setSt(() { isBadDebt = v; if (v) discType = 'None'; })),
        if (!isBadDebt) ...[
          const SizedBox(height: 12), DropdownButtonFormField<String>(initialValue: discType, decoration: AppUI.inputDecoration('Discount'), items: const [DropdownMenuItem(value: 'None', child: Text('None')), DropdownMenuItem(value: 'Flat', child: Text('Flat Rate')), DropdownMenuItem(value: 'Percentage', child: Text('Percentage (%)'))], onChanged: (v) => setSt(() => discType = v!)),
          if (discType != 'None') Padding(padding: const EdgeInsets.only(top: 12), child: AppUI.buildTextField(controller: discC, label: discType == 'Percentage' ? 'Discount %' : 'Discount ($curr)', type: const TextInputType.numberWithOptions(decimal: true))),
        ]
      ]))
    ]);
    payC.dispose(); discC.dispose();
  }

  static Future<void> handleReturn(BuildContext context, RentalGroup g, VoidCallback onSuccess) async {
    final messenger = ScaffoldMessenger.of(context);
    DateTime cDt = DateTime.tryParse(g.checkoutDate) ?? DateTime(2000);
    final act = await showDialog<String>(context: context, builder: (d) => AlertDialog(title: const Text('Return Action'), content: const Text('Return ALL remaining items, or partial?'), actions: [TextButton(onPressed: () => Navigator.pop(d,'cancel'), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(d,'partial'), child: const Text('Partial')), ElevatedButton(onPressed: () => Navigator.pop(d,'full'), child: const Text('Full'))]));
    if (act == null || act == 'cancel' || !context.mounted) return;

    if (act == 'partial') {
      final activeItems = g.items.where((r) => r['returned'] == 0).toList();
      if (activeItems.isEmpty) return;
      final Map<int, TextEditingController> goodC = {}, lostC = {}, penC = {};
      for (final r in activeItems) { final id = r['id'] as int; goodC[id] = TextEditingController(text: r['qty'].toString()); lostC[id] = TextEditingController(text: '0'); penC[id] = TextEditingController(text: '0'); }
      DateTime retDt = DateTime.now();

      await AppUI.showFormDialog(context, title: 'Partial Return', onSave: () async {
        final returns = <Map<String, dynamic>>[];
        for (final r in activeItems) {
          final id = r['id'] as int;
          final good = int.tryParse(goodC[id]!.text) ?? 0, lost = int.tryParse(lostC[id]!.text) ?? 0, pen = double.tryParse(penC[id]!.text) ?? 0.0;
          if (good + lost > (r['qty'] as int)) { messenger.showSnackBar(SnackBar(content: Text('Cannot return > rented for ${r['itemName']}'))); throw Exception('Validation'); }
          if (good + lost > 0) { returns.add({'rental': r, 'goodQty': good, 'damagedQty': lost, 'penalty': pen}); }
          else if (pen > 0) { messenger.showSnackBar(const SnackBar(content: Text('Must return >= 1 item to apply penalty.'))); throw Exception('Validation'); }
        }
        if (returns.isEmpty) { messenger.showSnackBar(const SnackBar(content: Text('Enter at least 1 quantity.'))); throw Exception('Validation'); }
        try {
          await DatabaseHelper.returnMultiplePartial(returns, DatabaseHelper.isoDate(retDt));
          onSuccess();
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text('Return failed: $e')));
          rethrow;
        }
      }, children: [
        StatefulBuilder(builder: (ctx, setSt) => Column(mainAxisSize: MainAxisSize.min, children: [
          ...activeItems.map((r) => Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r['itemName']} (Out: ${r['qty']})', style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
            Row(children: [ Expanded(child: AppUI.buildTextField(controller: goodC[r['id']]!, label: 'Good', type: TextInputType.number)), const SizedBox(width: 8), Expanded(child: AppUI.buildTextField(controller: lostC[r['id']]!, label: 'Lost', type: TextInputType.number)), const SizedBox(width: 8), Expanded(child: AppUI.buildTextField(controller: penC[r['id']]!, label: 'Penalty', type: const TextInputType.numberWithOptions(decimal: true))) ])
          ])))),
          ListTile(contentPadding: EdgeInsets.zero, title: Text('Return Date: ${DatabaseHelper.formatDateFromDt(retDt)}'), trailing: const Icon(Icons.calendar_month), onTap: () async { final p = await AppUI.pickDateWithCurrentTime(ctx, retDt, firstDate: cDt); if (p != null) setSt(() => retDt = p); })
        ]))
      ]);
      for (final c in [...goodC.values, ...lostC.values, ...penC.values]) { c.dispose(); }
    } else {
      final dtOpt = await showDialog<String>(context: context, builder: (d) => AlertDialog(title: const Text('Return Date'), actions: [TextButton(onPressed: () => Navigator.pop(d,'pick'), child: const Text('Pick Date')), ElevatedButton(onPressed: () => Navigator.pop(d,'today'), child: const Text('Today'))]));
      if (dtOpt == null || !context.mounted) return;
      DateTime rDt = DateTime.now();
      if (dtOpt == 'pick') { final p = await AppUI.pickDateWithCurrentTime(context, rDt, firstDate: cDt); if (p == null) return; rDt = p; }
      await DatabaseHelper.returnOrderGroup(g.items.where((r) => r['returned'] == 0).toList(), DatabaseHelper.isoDate(rDt));
      onSuccess();
      messenger.showSnackBar(SnackBar(content: Text(g.balance > 0 ? 'Items returned. Balance sent to Ledger.' : 'Items returned.')));
    }
  }

  static Future<void> editGroup(BuildContext context, RentalGroup g, VoidCallback onSuccess) async {
    final nameC = TextEditingController(text: g.contractor), phoneC = TextEditingController(text: g.phone), phone2C = TextEditingController(text: g.phone2), addC = TextEditingController(text: g.address), advC = TextEditingController(text: g.advance > 0 ? g.advance.toStringAsFixed(2) : ''), noteC = TextEditingController(text: g.notes);
    String meth = g.paymentMethod.isNotEmpty ? g.paymentMethod : kPaymentMethods.first;
    DateTime dt = DateTime.tryParse(g.checkoutDate) ?? DateTime.now();

    await AppUI.showFormDialog(context, title: g.isGroup ? 'Edit Order #${g.orderId}' : 'Edit Rental',
        onDelete: () async {
          if (await _confirmDialog(context, title: 'Delete', message: 'Permanently delete this record?')) {
            await DatabaseHelper.deleteRentalGroup(g.items);
            onSuccess();
            if (context.mounted) Navigator.pop(context);
          }
        },
        onSave: () async {
          try {
            await DatabaseHelper.updateRentalGroup(g, contractor: nameC.text.trim(), phone: phoneC.text.trim(), phone2: phone2C.text.trim(), address: addC.text.trim(), advanceDeposit: double.tryParse(advC.text) ?? 0.0, paymentMethod: meth, checkoutDate: DatabaseHelper.isoDate(dt), notes: noteC.text.trim());
            onSuccess();
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
            rethrow;
          }
        }, children: [
          StatefulBuilder(builder: (ctx, setSt) => Column(mainAxisSize: MainAxisSize.min, children: [
            if (g.isGroup) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Editing shared details for ${g.items.length} records.', style: const TextStyle(fontSize: 12, color: Colors.grey))),
            AppUI.buildTextField(controller: nameC, label: 'Contractor Name'), AppUI.buildTextField(controller: phoneC, label: 'Phone', type: TextInputType.phone), AppUI.buildTextField(controller: phone2C, label: 'Alt Phone', type: TextInputType.phone), AppUI.buildTextField(controller: addC, label: 'Address'),
            Row(children: [ Expanded(child: AppUI.buildTextField(controller: advC, label: 'Advance ($curr)', type: const TextInputType.numberWithOptions(decimal: true))), const SizedBox(width: 8), Expanded(child: DropdownButtonFormField<String>(initialValue: meth, decoration: AppUI.inputDecoration('Method', i: Icons.payment), items: kPaymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: (v) => setSt(() => meth = v!))) ]),
            AppUI.buildTextField(controller: noteC, label: 'Notes', maxLines: 2),
            ListTile(contentPadding: EdgeInsets.zero, title: Text('Checkout: ${DatabaseHelper.formatDateFromDt(dt)}'), trailing: const Icon(Icons.calendar_month), onTap: () async { final p = await AppUI.pickDateWithCurrentTime(ctx, dt); if (p != null) setSt(() => dt = p); })
          ]))
        ]);
    nameC.dispose(); phoneC.dispose(); phone2C.dispose(); addC.dispose(); advC.dispose(); noteC.dispose();
  }
}

// ======== Universal UI Helpers (Optimization Layer) ========
class SearchablePickerSheet<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final bool Function(T, String) filter;
  final Widget Function(T) itemBuilder;

  const SearchablePickerSheet({super.key, required this.title, required this.items, required this.filter, required this.itemBuilder});

  @override
  State<SearchablePickerSheet<T>> createState() => _SearchablePickerSheetState<T>();
}

class _SearchablePickerSheetState<T> extends State<SearchablePickerSheet<T>> {
  final TextEditingController _searchCtrl = TextEditingController();
  late List<T> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter(String query) {
    setState(() {
      _filtered = widget.items.where((i) => widget.filter(i, query)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
              suffixIcon: _searchCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _filter(''); }) : null,
            ),
            onChanged: _filter,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(child: Text('No results found.'))
                : ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final item = _filtered[index];
                return InkWell(
                  onTap: () => Navigator.pop(context, item),
                  child: widget.itemBuilder(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TransactionLineItem {
  int? itemId;
  final TextEditingController qtyC = TextEditingController(text: '1');
  final TextEditingController priceC = TextEditingController(text: '0.00'); // Universal for Rate or Cost

  void dispose() {
    qtyC.dispose();
    priceC.dispose();
  }
}

class AppUI {
  static Widget buildPartyDateRow({
    required BuildContext context, required String partyLabel, required IconData partyIcon, required int? selectedPartyId,
    required List<Map<String, dynamic>> partyList, required bool Function(Map<String, dynamic>, String) filter,
    required Widget Function(Map<String, dynamic>) itemBuilder, required ValueChanged<int?> onPartySelected,
    required DateTime selectedDate, required TextEditingController dateCtrl, required String dateLabel, required ValueChanged<DateTime> onDateSelected,
  }) {
    return Row(children: [
      Expanded(child: InkWell(
        onTap: () async {
          final selected = await showSearchablePicker<Map<String, dynamic>>(context: context, title: 'Select $partyLabel', items: partyList, filter: filter, itemBuilder: itemBuilder);
          if (selected != null) onPartySelected(selected['id']);
        },
        child: IgnorePointer(child: TextFormField(
          key: ValueKey(selectedPartyId),
          initialValue: selectedPartyId != null ? partyList.firstWhere((p) => p['id'] == selectedPartyId, orElse: () => {'name': ''})['name'] : 'Select $partyLabel',
          decoration: inputDecoration(partyLabel, i: partyIcon).copyWith(suffixIcon: const Icon(Icons.search)),
        )),
      )),
      const SizedBox(width: 8),
      Expanded(child: TextFormField(readOnly: true, controller: dateCtrl, decoration: inputDecoration(dateLabel, i: Icons.calendar_today), onTap: () async {
        final p = await AppUI.pickDateWithCurrentTime(context, selectedDate);
        if (p != null) { onDateSelected(p); dateCtrl.text = DatabaseHelper.formatDateFromDt(p); }
      }))
    ]);
  }

  static Widget buildLineItemsList({
    required BuildContext context,
    required List<TransactionLineItem> lines,
    required List<Map<String, dynamic>> inventoryItems,
    required String priceLabel,
    required VoidCallback onAddLine,
    required ValueChanged<int> onRemoveLine,
    required VoidCallback onStateChanged,
  }) {
    Widget buildLineCard(int i, TransactionLineItem line) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () async {
                    final selected = await showSearchablePicker<Map<String, dynamic>>(
                      context: context,
                      title: 'Select Item',
                      items: inventoryItems,
                      filter: (item, q) => (item['name']?.toString().toLowerCase() ?? '').contains(q.toLowerCase()),
                      itemBuilder: (item) {
                        final avail = (item['total'] as int? ?? 0) - (item['rented'] as int? ?? 0);
                        return ListTile(
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Stock: ${item['total']} | Avail: $avail'),
                          trailing: const Icon(Icons.chevron_right, size: 16),
                        );
                      },
                    );
                    if (selected != null) {
                      line.itemId = selected['id'];
                      if (priceLabel.contains('Cost')) {
                        line.priceC.text = (selected['purchasePrice'] as num?)?.toStringAsFixed(2) ?? '0.00';
                      }
                      onStateChanged();
                    }
                  },
                  child: IgnorePointer(
                    child: TextFormField(
                      key: ValueKey(line.itemId),
                      initialValue: line.itemId != null
                          ? inventoryItems.firstWhere((it) => it['id'] == line.itemId, orElse: () => {'name': ''})['name']
                          : 'Select Item',
                      decoration: inputDecoration('Item').copyWith(suffixIcon: const Icon(Icons.search)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: line.qtyC,
                  decoration: inputDecoration('Qty'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onStateChanged(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: line.priceC,
                  decoration: inputDecoration(priceLabel),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => onStateChanged(),
                ),
              ),
              if (lines.length > 1)
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                  onPressed: () => onRemoveLine(i),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        for (final entry in lines.asMap().entries) buildLineCard(entry.key, entry.value),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: onAddLine, icon: const Icon(Icons.add), label: const Text('Add Another Item')),
        ),
      ],
    );
  }

  static Future<T?> showSearchablePicker<T>({
    required BuildContext context,
    required String title,
    required List<T> items,
    required bool Function(T, String) filter,
    required Widget Function(T) itemBuilder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.75,
        child: SearchablePickerSheet<T>(title: title, items: items, filter: filter, itemBuilder: itemBuilder),
      ),
    );
  }

  static InputDecoration inputDecoration(String l, {IconData? i, String? p}) => InputDecoration(
    labelText: l, prefixIcon: i != null ? Icon(i) : null, prefixText: p, border: const OutlineInputBorder(),
    isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );

  static Widget buildTextField({required TextEditingController controller, required String label, IconData? icon, TextInputType? type, String? prefix, int maxLines = 1, String? Function(String?)? validator}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(controller: controller, decoration: inputDecoration(label, i: icon, p: prefix), keyboardType: type, maxLines: maxLines, validator: validator),
  );

  static Future<void> showFormDialog(BuildContext ctx, {required String title, required List<Widget> children, required Future<void> Function() onSave, VoidCallback? onDelete}) {
    final fKey = GlobalKey<FormState>();
    return showDialog(context: ctx, builder: (dCtx) => AlertDialog(
      title: Text(title), content: SingleChildScrollView(child: Form(key: fKey, child: Column(mainAxisSize: MainAxisSize.min, children: children))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
        if (onDelete != null) TextButton(onPressed: onDelete, style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
        ElevatedButton(onPressed: () async { if (fKey.currentState!.validate()) { await onSave(); if (dCtx.mounted) Navigator.pop(dCtx); } }, child: const Text('Save')),
      ],
    ));
  }

  static Future<DateTime?> pickDateWithCurrentTime(BuildContext context, DateTime initialDate, {DateTime? firstDate, DateTime? lastDate}) async {
    final p = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2100),
    );
    if (p == null) return null;
    return DateTime(p.year, p.month, p.day, initialDate.hour, initialDate.minute, initialDate.second);
  }
}

// ========Universal Payment Label========

class _PaymentLabel extends StatelessWidget {
  final String method;
  const _PaymentLabel(this.method);
  @override
  Widget build(BuildContext context) {
    if (method.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Text('  |  '),
      Text(method, style: const TextStyle(color: Colors.blue)),
    ]);
  }
}

// =============================
// V. PRIMARY TABS (USER DAILY FLOW)
// =============================


// ========Dashboard Screen========
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, int> _stats = {};
  List<Map<String, dynamic>> _overdueRentals = [], _topCustomers = [];
  double _pendingCollections = 0.0;
  bool _loading = true; String? _error;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final od = appSettingsNotifier.overdueDays;
      final data = await DatabaseHelper.getDashboardData();
      final overdue = await DatabaseHelper.getOverdueRentals(od);
      final stats = await DatabaseHelper.getDashboardStats(overdueDays: od);
      if (!mounted) return;
      setState(() { _stats = stats; _pendingCollections = data['pendingCollections']; _topCustomers = data['topCustomers']; _overdueRentals = overdue; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load dashboard data.\nPlease try again.'; _loading = false; });
    }
  }

  void _nav(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

  // Dummy actions for metadata; onTap is passed dynamically in the builder
  final Map<String, _QuickAction> _allActions = const {
    'New Order': _QuickAction(icon: Icons.playlist_add, label: 'New Order', onTap: _dummy),
    'Ledgers': _QuickAction(icon: Icons.account_balance_wallet, label: 'Ledgers', onTap: _dummy),
    'Biz Info': _QuickAction(icon: Icons.store, label: 'Biz Info', onTap: _dummy),
    'Proforma': _QuickAction(icon: Icons.receipt_long, label: 'Proforma', onTap: _dummy),
    'Invoice': _QuickAction(icon: Icons.request_quote, label: 'Invoice', onTap: _dummy),
    'Parties': _QuickAction(icon: Icons.people, label: 'Parties', onTap: _dummy),
    'Inventory': _QuickAction(icon: Icons.inventory_2, label: 'Inventory', onTap: _dummy),
    'Reports': _QuickAction(icon: Icons.bar_chart, label: 'Reports', onTap: _dummy),
  };
  static void _dummy() {}

  void _editQuickActions() {
    List<String> currentSelected = List.from(appSettingsNotifier.quickActions);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit Quick Actions'),
            content: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                children: _allActions.keys.map((key) {
                  final isSelected = currentSelected.contains(key);
                  return FilterChip(
                    label: Text(key),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          if (currentSelected.length < 6) currentSelected.add(key);
                        } else {
                          currentSelected.remove(key);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  appSettingsNotifier.setQuickActions(currentSelected);
                  Navigator.pop(ctx);
                  this.setState(() {}); // refresh dashboard
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleQuickAction(String key) {
    switch (key) {
      case 'New Order': _nav(const NewOrderScreen()); break;
      case 'Ledgers': _nav(const PaymentLedgerScreen()); break;
      case 'Biz Info': _nav(const BusinessInfoScreen()); break;
      case 'Proforma': _nav(const InvoiceManagerScreen(initialIndex: 0)); break;
      case 'Invoice': _nav(const InvoiceManagerScreen(initialIndex: 1)); break;
      case 'Parties': _nav(const PartiesManagementScreen()); break;
      case 'Inventory': _nav(const InventoryTab()); break;
      case 'Reports': _nav(const FinancialReportsScreen()); break;
    }
  }

  @override Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline, color: Colors.redAccent, size: 48), const SizedBox(height: 16), Text(_error!), const SizedBox(height: 24), ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry'))]));

    return RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [Expanded(child: _StatCard(label:'Total Items', value:'${_stats['items']}', icon:Icons.inventory_2, color:Colors.blue)), const SizedBox(width: 8), Expanded(child: _StatCard(label:'Active Rental Items', value:'${_stats['activeRentals']}', subtitle: '${_stats['activeOrders'] ?? 0} invoices', icon:Icons.handshake, color:Colors.orange))]),
      const SizedBox(height: 8),
      Row(children: [Expanded(child: _StatCard(label:'Customers', value:'${_stats['customers']}', icon:Icons.people, color:Colors.purple)), const SizedBox(width: 8), Expanded(child: _StatCard(label:'Returned Lines', value:'${_stats['returned']}', subtitle: '${_stats['returnedOrders'] ?? 0} invoices', icon:Icons.check_circle, color:Colors.green))]),
      const SizedBox(height: 14),

      Card(child: ListTile(leading: const Icon(Icons.account_balance_wallet, color: Colors.orange), title: const Text('Pending Collections', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: const Text('Outstanding amount from returned invoices'), trailing: Text(formatMoney(_pendingCollections, decimals: 0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange)), onTap: () => _nav(const PaymentLedgerScreen()))),
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: _editQuickActions, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ],
      ),
      const SizedBox(height: 12),

      GridView.count(
        crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.4,
        children: appSettingsNotifier.quickActions.where((k) => _allActions.containsKey(k)).map((k) {
          final action = _allActions[k] as _QuickAction;
          return _QuickAction(icon: action.icon, label: action.label, onTap: () => _handleQuickAction(k));
        }).toList(),
      ),

      if ((_stats['overdue'] ?? 0) > 0) ...[
        const SizedBox(height: 20), Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.orange), const SizedBox(width: 8), Text('Overdue Rentals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange[300]))]), const SizedBox(height: 8),
        ..._overdueRentals.map((r) => Card(color: Colors.orange.withValues(alpha:0.15), child: ListTile(leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange), title: Text('${r['contractor']} - ${r['itemName']}'), subtitle: Text('Out since: ${DatabaseHelper.formatDateString(r['checkoutDate'])} (${RentalUtils.calculateChargeDays(r['checkoutDate'] as String?, null, 0)} days)')))),
      ],
      if (AppProvider.of(context).showTopCustomersByRevenue) ...[
        const SizedBox(height: 20), const Text('Top Customers By Revenue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
        if (_topCustomers.isEmpty) const Card(child: ListTile(title: Text('No customer revenue data yet.'))) else ..._topCustomers.asMap().entries.map((e) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: CircleAvatar(backgroundColor: Colors.amber.withValues(alpha: 0.2), child: Text('${e.key + 1}', style: const TextStyle(fontWeight: FontWeight.bold))), title: Text((e.value['name'] as String?) ?? '', style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text('Invoices: ${e.value['invoices']}'), trailing: Text(formatMoney((e.value['revenue'] as double?) ?? 0.0, decimals: 0), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))))),
      ],
    ]));
  }
}

// ========Inventory Tab========

class InventoryTab extends StatefulWidget {
  const InventoryTab({super.key});
  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  List<Map<String, dynamic>> _items = [];
  List<String> _categories = ['All'];
  String _selectedCategory = 'All';
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _searchCtrl.dispose(); _debounce?.cancel(); super.dispose(); }

  Future<void> _load() async {
    final items = await DatabaseHelper.getItems(search: _searchCtrl.text, category: _selectedCategory);
    final cats  = await DatabaseHelper.getCategories();
    if (!mounted) return;
    setState(() { _items = items; _categories = ['All', ...cats.where((c) => c.isNotEmpty)]; });
  }

  void _onSearch(String _) { _debounce?.cancel(); _debounce = Timer(const Duration(milliseconds: 300), _load); }

  // =================================================
  // MAINTENANCE ENTRY SCREEN
  // =================================================
  Future<void> _showMaintenanceDialog(Map<String, dynamic> item) async {
    final formKey = GlobalKey<FormState>();
    final descC   = TextEditingController();
    final costC   = TextEditingController();
    DateTime date = DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: Text('Log Repair: ${item['name']}'),
          content: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: descC, decoration: const InputDecoration(labelText: 'Repair Description *'),
                validator: (v) => v==null||v.trim().isEmpty ? 'Required' : null),
            TextFormField(controller: costC, decoration: InputDecoration(labelText: 'Repair Cost ($curr) *'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => double.tryParse(v??'') == null ? 'Invalid cost' : null),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text('Date: ${DatabaseHelper.formatDateFromDt(date)}')),
              TextButton(onPressed: () async {
                final d = await AppUI.pickDateWithCurrentTime(context, date, lastDate: DateTime.now());
                if (d != null) setSt(() => date = d);
              }, child: const Text('Pick Date'))
            ]),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await DatabaseHelper.logMaintenance(item['id'] as int, item['name'] as String, descC.text.trim(), double.parse(costC.text), DatabaseHelper.isoDate(date));
              if (ctx.mounted) Navigator.pop(ctx);
            }, child: const Text('Save Repair')),
          ],
        ),
      ),
    );
    descC.dispose(); costC.dispose();
  }

  Future<void> _showMaintenanceHistory(Map<String, dynamic> item) async {
    final history = await DatabaseHelper.getMaintenanceHistory(item['id'] as int);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Repair History: ${item['name']}'),
        content: SizedBox(
          width: double.maxFinite,
          child: history.isEmpty
              ? const Padding(padding: EdgeInsets.all(20), child: Text('No repair logs found for this item.'))
              : ListView.separated(
            shrinkWrap: true,
            itemCount: history.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (ctx, i) {
              final log = history[i];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(log['description']),
                subtitle: Text(DatabaseHelper.formatDateString(log['logDate'])),
                trailing: Text(formatMoney(log['cost'] as double), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _showItemDialog({Map<String, dynamic>? item}) async {
    final isEdit    = item != null;
    final editData  = item ?? {};
    final nameC     = TextEditingController(text: (editData['name']     ?? '') as String);
    final totalC    = TextEditingController(text: isEdit ? (editData['total'] ?? '').toString() : '');
    final categoryC = TextEditingController(text: (editData['category'] ?? 'General') as String);
    final notesC    = TextEditingController(text: (editData['notes']    ?? '') as String);

    // Financial Controllers for Depreciation Engine
    final priceC    = TextEditingController(text: (editData['purchasePrice'] ?? 0.0).toString());
    final lifeC     = TextEditingController(text: (editData['expectedLifeMonths'] ?? 0).toString());
    DateTime pDate  = DateTime.tryParse(editData['purchaseDate'] as String? ?? '') ?? DateTime.now();

    await AppUI.showFormDialog(context,
      title: isEdit ? 'Edit Material' : 'Add Material',
      onDelete: !isEdit ? null : () async {
        final ok = await _confirmDialog(context, title:'Delete Item', message:'Delete this item? Only possible if no active rentals exist.');
        if (ok) {
          await DatabaseHelper.deleteItem(editData['id'] as int);
          if (!mounted) return;
          Navigator.pop(context);
          _load();
        }
      },
      onSave: () async {
        final cat = categoryC.text.trim().isEmpty ? 'General' : categoryC.text.trim();
        final args = [nameC.text.trim(), int.parse(totalC.text), cat, notesC.text.trim()];
        final kArgs = {'purchasePrice': double.tryParse(priceC.text) ?? 0.0, 'purchaseDate': DatabaseHelper.isoDate(pDate), 'expectedLifeMonths': int.tryParse(lifeC.text) ?? 0};
        isEdit ? await DatabaseHelper.updateItem(editData['id'], args[0] as String, args[1] as int, args[2] as String, args[3] as String, purchasePrice: kArgs['purchasePrice'] as double, purchaseDate: kArgs['purchaseDate'] as String, expectedLifeMonths: kArgs['expectedLifeMonths'] as int)
            : await DatabaseHelper.insertItem(args[0] as String, args[1] as int, args[2] as String, args[3] as String, purchasePrice: kArgs['purchasePrice'] as double, purchaseDate: kArgs['purchaseDate'] as String, expectedLifeMonths: kArgs['expectedLifeMonths'] as int);
        _load();
      },
      children: [
        AppUI.buildTextField(controller: nameC, label: 'Name *', validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
        AppUI.buildTextField(controller: totalC, label: 'Total Stock *', type: TextInputType.number),
        AppUI.buildTextField(controller: categoryC, label: 'Category'),
        AppUI.buildTextField(controller: notesC, label: 'Notes', maxLines: 2),
        const Divider(),
        const Text('Capital Asset Accounting', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        const SizedBox(height: 8),
        AppUI.buildTextField(controller: priceC, label: 'Purchase Price ($curr)', type: const TextInputType.numberWithOptions(decimal: true)),
        AppUI.buildTextField(controller: lifeC, label: 'Expected Life (Months)', type: TextInputType.number),
        StatefulBuilder(builder: (ctx, setSt) => ListTile(
          title: Text('Purchase Date: ${DatabaseHelper.formatDateFromDt(pDate)}', style: const TextStyle(fontSize: 13)),
          trailing: const Icon(Icons.calendar_month),
          onTap: () async { final d = await AppUI.pickDateWithCurrentTime(ctx, pDate, lastDate: DateTime.now()); if (d != null) setSt(() => pDate = d); },
        )),
      ],
    );
    nameC.dispose(); totalC.dispose(); categoryC.dispose(); notesC.dispose();
    priceC.dispose(); lifeC.dispose();
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      _SearchBar(controller: _searchCtrl, hint: 'Search items...', onClear: () { _searchCtrl.clear(); _load(); }, onChanged: _onSearch),
      if (_categories.length > 1)
        SizedBox(height: 44, child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          scrollDirection: Axis.horizontal, itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) { final cat = _categories[i]; return FilterChip(label: Text(cat), selected: cat == _selectedCategory, onSelected: (_) { setState(() => _selectedCategory = cat); _load(); }); },
        )),
      Expanded(child: _items.isEmpty
          ? const Center(child: Text('No items found.\nTap + to add materials.', textAlign: TextAlign.center))
          : RefreshIndicator(onRefresh: _load, child: ListView.builder(
        padding: const EdgeInsets.all(12), itemCount: _items.length,
        itemBuilder: (_, i) {
          final it = _items[i];
          final total = it['total'] as int? ?? 0;
          final rented = it['rented'] as int? ?? 0;
          final lost = it['lostQty'] as int? ?? 0;
          final avail = (total - rented - lost).clamp(0, total);

          return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: appSettingsNotifier.cardPadding, child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(it['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                if ((it['category'] as String? ?? '') != 'General' && (it['category'] as String? ?? '').isNotEmpty)
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: Text(it['category'] as String, style: const TextStyle(fontSize: 10))),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 4, children: [
                _StockChip('Total: $total', Colors.blue),
                _StockChip('Out: $rented', Colors.orange),
                _StockChip('Free: $avail', avail > 0 ? Colors.green : Colors.red),
                if (lost > 0) _StockChip('Lost: $lost', Colors.redAccent)
              ]),
              if ((it['notes'] as String? ?? '').isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text(it['notes'] as String, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12))),
            ])),
            SizedBox(
              width: 32,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_vert, size: 22),
                tooltip: 'Options',
                onSelected: (val) {
                  if (val == 'edit') { _showItemDialog(item: it); }
                  if (val == 'repair') { _showMaintenanceDialog(it); }
                  if (val == 'history') { _showMaintenanceHistory(it); }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit Details')])),
                  PopupMenuItem(value: 'repair', child: Row(children: [Icon(Icons.build_circle_outlined, size: 18, color: Colors.blueGrey), SizedBox(width: 8), Text('Log Repair')])),
                  PopupMenuItem(value: 'history', child: Row(children: [Icon(Icons.history, size: 18, color: Colors.blue), SizedBox(width: 8), Text('Repair History')])),
                ],
              ),
            ),
          ])));
        },
      ))),
    ]),
    floatingActionButton: FloatingActionButton(
      onPressed: _showItemDialog,
      tooltip: 'Add Item',
      child: const Icon(Icons.add),
    ),
  );
}

// ========Active Rentals Tab========

class ActiveRentalsTab extends StatefulWidget {
  const ActiveRentalsTab({super.key});
  @override
  State<ActiveRentalsTab> createState() => _ActiveRentalsTabState();
}

class _ActiveRentalsTabState extends State<ActiveRentalsTab> {
  List<RentalGroup> _groups = [];
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _sortMode = kSortOptions.first;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _searchCtrl.dispose(); _debounce?.cancel(); super.dispose(); }

  Future<void> _load() async {
    final all = groupRentalsByInvoice(await DatabaseHelper.getAllRentals(search: _searchCtrl.text));
    final active = all.where((g) => !g.isFullyReturned).toList();
    _applySort(active, _sortMode);
    if (!mounted) return;
    setState(() => _groups = active);
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _delete(RentalGroup group) async {
    final ok = await _confirmDialog(context, title: 'Delete Active Rental', message: 'Permanently delete this record? This will return items to inventory.');
    if (!ok) return;
    if (!mounted) return;
    await DatabaseHelper.deleteRentalGroup(group.items);
    if (mounted) _load();
  }

  Future<void> _openProformaPdf(int orderId) async {
    final nav = Navigator.of(context);

    final size = await pickPdfSize(context);
    if (size == null || !mounted) return;

    final bytes = await DatabaseHelper.generatePdfProformaForOrder(orderId, pageSize: size);
    if (!mounted) return;
    await nav.push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Proforma Preview')), body: PdfPreview(build: (_) async => bytes))));
  }

  Future<void> _editGroup(RentalGroup group) async { await TransactionDialogs.editGroup(context, group, _load); }
  Future<void> _handleReturn(RentalGroup group) async { await TransactionDialogs.handleReturn(context, group, _load); }

  Widget _buildCard(RentalGroup g) {
    return UniversalRentalCard(
      group: g,
      showCustomerName: true,
      onEdit: () => _editGroup(g),
      onReturn: () => _handleReturn(g),
      onDelete: () => _delete(g),
      onProforma: g.orderId != null ? () => _openProformaPdf(g.orderId!) : null,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search active rentals...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
              if (_searchCtrl.text.isNotEmpty)
                IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _load(); }),
              PopupMenuButton<String>(
                icon: Stack(clipBehavior: Clip.none, children: [
                  Icon(Icons.filter_list, color: _sortMode != kSortOptions.first ? Colors.amber : null),
                  if (_sortMode != kSortOptions.first) Positioned(
                    right: -2, top: -2,
                    child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)),
                  ),
                ]),
                tooltip: 'Sort by',
                initialValue: _sortMode,
                onSelected: (v) { setState(() => _sortMode = v); _load(); },
                itemBuilder: (_) => kSortOptions.map((o) => PopupMenuItem(
                  value: o,
                  child: Row(children: [
                    Icon(_sortMode == o ? Icons.radio_button_checked : Icons.radio_button_off, size: 18, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(o),
                  ]),
                )).toList(),
              ),
            ]),
          ),
          onChanged: _onSearch,
        ),
      ),
      const SizedBox(height: 8),
      Expanded(child: _groups.isEmpty
          ? const Center(child: Text('No active rentals.'))
          : RefreshIndicator(onRefresh: _load, child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        itemCount: _groups.length,
        itemBuilder: (_, i) => _buildCard(_groups[i]),
      ))),
    ]),
    floatingActionButton: FloatingActionButton(
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const NewOrderScreen())).then((_) => _load());
      },
      tooltip: 'Add Rental',
      child: const Icon(Icons.add),
    ),
  );
}

// ========Rental History Tab========

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});
  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  List<RentalGroup> _groups = [];
  Map<String, List<Map<String, dynamic>>> _paymentLogsByGroup = {};
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _sortMode = kSortOptions.first;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _searchCtrl.dispose(); _debounce?.cancel(); super.dispose(); }

  Future<void> _load() async {
    // History tab keeps only fully returned groups (active rentals belong to Active tab).
    final all = groupRentalsByInvoice(await DatabaseHelper.getAllRentals(search: _searchCtrl.text));
    final history = all.where((g) => g.isFullyReturned).toList();
    _applySort(history, _sortMode);
    final paymentMap = await DatabaseHelper.getPaymentLogsForGroups(history);
    if (!mounted) return;
    setState(() {
      _groups = history;
      _paymentLogsByGroup = paymentMap;
    });
  }

  void _onSearch(String _) { _debounce?.cancel(); _debounce = Timer(const Duration(milliseconds: 300), _load); }

  Future<void> _delete(RentalGroup group) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _confirmDialog(context, title:'Delete Invoice Record', message:'Permanently delete this entire invoice history?');
    if (!ok) return;
    await DatabaseHelper.deleteRentalGroup(group.items);
    if (!mounted) return;
    _load();
    messenger.showSnackBar(const SnackBar(content: Text('Invoice history deleted.')));
  }

  Future<void> _cancel(RentalGroup group) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _confirmDialog(context, title:'Cancel Invoice', message:'Are you sure you want to cancel this invoice? It will be permanently marked as CANCELLED.');
    if (!ok) return;
    await DatabaseHelper.cancelRentalGroup(group.items.map((i) => i['id'] as int).toList());
    if (!mounted) return;
    _load();
    messenger.showSnackBar(const SnackBar(content: Text('Invoice successfully cancelled.')));
  }

  void _openPaymentHistoryForGroup(RentalGroup g) {
    final displayDocNumber = g.invoiceNumber.isNotEmpty
        ? g.invoiceNumber
        : (g.proformaNumber.isNotEmpty ? g.proformaNumber : null);

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select View'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentLedgerScreen(
                initialTabIndex: 1,
                initialOrderId: g.orderId,
                initialFallbackRentalId: g.orderId == null ? (g.fallbackId ?? (g.items.firstOrNull?['id'] as int?)) : null,
                initialDisplayDocNumber: displayDocNumber,
              )));
            },
            child: const Row(children: [Icon(Icons.history, color: Colors.blue), SizedBox(width: 12), Text('Payment History')]),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentLedgerScreen(
                initialOrderId: g.orderId,
                initialFallbackRentalId: g.orderId == null ? (g.fallbackId ?? (g.items.firstOrNull?['id'] as int?)) : null,
                initialDisplayDocNumber: displayDocNumber,
              )));
            },
            child: const Row(children: [Icon(Icons.account_balance_wallet, color: Colors.orange), SizedBox(width: 12), Text('Outstanding Ledger')]),
          ),
        ],
      ),
    );
  }

  Future<void> _openInvoicePdf(int orderId) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final size = await pickPdfSize(context);
    if (size == null || !mounted) return;

    messenger.showSnackBar(const SnackBar(content: Text('Generating PDF...')));
    try {
      final bytes = await DatabaseHelper.generatePdfFinalInvoiceForOrder(orderId, pageSize: size);
      if (!mounted) return;
      await nav.push(MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Final Invoice Preview')),
          body: PdfPreview(build: (_) async => bytes),
        ),
      ));
    } catch (e) { if (mounted) messenger.showSnackBar(SnackBar(content: Text('Failed: $e'))); }
  }

  Future<void> _editGroup(RentalGroup group) async { await TransactionDialogs.editGroup(context, group, _load); }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search history...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
              if (_searchCtrl.text.isNotEmpty)
                IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _load(); }),
              PopupMenuButton<String>(
                icon: Stack(clipBehavior: Clip.none, children: [
                  Icon(Icons.filter_list, color: _sortMode != kSortOptions.first ? Colors.amber : null),
                  if (_sortMode != kSortOptions.first) Positioned(
                    right: -2, top: -2,
                    child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)),
                  ),
                ]),
                tooltip: 'Sort by',
                initialValue: _sortMode,
                onSelected: (v) { setState(() => _sortMode = v); _applySort(_groups, v); setState(() {}); },
                itemBuilder: (_) => kSortOptions.map((o) => PopupMenuItem(
                  value: o,
                  child: Row(children: [
                    Icon(_sortMode == o ? Icons.radio_button_checked : Icons.radio_button_off, size: 18, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(o),
                  ]),
                )).toList(),
              ),
            ]),
          ),
          onChanged: _onSearch,
        ),
      ),
      const SizedBox(height: 8),
      Expanded(child: _groups.isEmpty
          ? const Center(child: Text('No complete history yet.'))
          : RefreshIndicator(onRefresh: _load, child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        itemCount: _groups.length,

        itemBuilder: (_, i) {
          final g = _groups[i];
          final payments = _paymentLogsByGroup[g.paymentGroupKey];
          return UniversalRentalCard(
            group: g,
            paymentLogs: payments,
            showCustomerName: true,
            onPdf: g.orderId != null ? () => _openInvoicePdf(g.orderId!) : null,
            onEdit: () => _editGroup(g),
            onCancel: () => _cancel(g),
            onDelete: () => _delete(g),
            onViewPayments: () => _openPaymentHistoryForGroup(g),
          );
        },
      ))),
    ]),
  );
}

// =============================
// VI. MANAGEMENT MODULE (BACK OFFICE)
// =============================

// ========Business Info Screen========
class BusinessInfoScreen extends StatefulWidget {
  const BusinessInfoScreen({super.key});
  @override
  State<BusinessInfoScreen> createState() => _BusinessInfoScreenState();
}

class _BusinessInfoScreenState extends State<BusinessInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController(), _phoneC = TextEditingController(), _phone2C = TextEditingController(),
      _emailC = TextEditingController(), _addressC = TextEditingController(), _upiC = TextEditingController(), _upiNameC = TextEditingController(),
      _taxRateC = TextEditingController(), _taxRegNoC = TextEditingController();
  String _taxProfile = 'No Tax';
  String _taxType = 'none';
  String _taxMode = 'exclusive';
  int _fyStartMonth = 4; // Default to April

  final List<Map<String, dynamic>> _months = [
    {'val': 1, 'name': 'January'}, {'val': 2, 'name': 'February'}, {'val': 3, 'name': 'March'},
    {'val': 4, 'name': 'April'}, {'val': 5, 'name': 'May'}, {'val': 6, 'name': 'June'},
    {'val': 7, 'name': 'July'}, {'val': 8, 'name': 'August'}, {'val': 9, 'name': 'September'},
    {'val': 10, 'name': 'October'}, {'val': 11, 'name': 'November'}, {'val': 12, 'name': 'December'},
  ];

  String _taxTypeLabel(String type) {
    switch (type) {
      case 'gst': return 'GST';
      case 'vat': return 'VAT';
      case 'sales': return 'Sales Tax';
      case 'consumption': return 'Consumption Tax';
      default: return 'No Tax';
    }
  }

  String _taxRegLabel(String type) {
    switch (type) {
      case 'gst': return 'GSTIN';
      case 'vat': return 'VAT No.';
      case 'sales': return 'Sales Tax ID';
      case 'consumption': return 'Tax Reg. No.';
      default: return 'Tax Registration No.';
    }
  }

  String _formatRateText(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  void _applyTaxProfile(String profile) {
    final defaults = taxProfileDefaults(profile);
    setState(() {
      _taxProfile = profile;
      if (profile != 'Custom') {
        _taxType = defaults['taxType'] as String? ?? 'none';
        _taxMode = defaults['taxMode'] as String? ?? 'exclusive';
        final rate = (defaults['taxRate'] as num?)?.toDouble() ?? 0.0;
        _taxRateC.text = _formatRateText(rate);
      }
      if (_taxType == 'none') _taxRegNoC.clear();
    });
  }

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { for (final c in [_nameC,_phoneC,_phone2C,_emailC,_addressC,_upiC,_upiNameC,_taxRateC,_taxRegNoC]) { c.dispose(); } super.dispose(); }

  Future<void> _load() async {
    final info = await DatabaseHelper.getBusinessInfo();
    if (!mounted) return;
    setState(() {
      _nameC.text    = (info['name']    as String?) ?? '';
      _phoneC.text   = (info['phone']   as String?) ?? '';
      _phone2C.text  = (info['phone2']  as String?) ?? '';
      _emailC.text   = (info['email']   as String?) ?? '';
      _addressC.text = (info['address'] as String?) ?? '';
      _upiC.text     = (info['upiId']   as String?) ?? '';
      _upiNameC.text = (info['upiName'] as String?) ?? '';
      _fyStartMonth  = (info['fyStartMonth'] as int?) ?? 4;
      final profile = (info['taxProfile'] as String? ?? 'No Tax').trim();
      _taxProfile = kTaxProfiles.contains(profile) ? profile : 'Custom';
      _taxType = (info['taxType'] as String? ?? 'none').trim().toLowerCase();
      if (!['none','gst','vat','sales','consumption'].contains(_taxType)) _taxType = 'none';
      _taxMode = ((info['taxMode'] as String? ?? 'exclusive').trim().toLowerCase() == 'inclusive') ? 'inclusive' : 'exclusive';
      final taxRate = (info['taxRate'] as num?)?.toDouble() ?? double.tryParse((info['taxRate'] ?? '').toString()) ?? 0.0;
      _taxRateC.text = _formatRateText(taxRate);
      _taxRegNoC.text = (info['taxRegNo'] as String? ?? '').trim();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Business Info')),
    body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Form(key: _formKey, child: Column(children: [
      const Icon(Icons.store, size: 48, color: Colors.amber), const SizedBox(height: 8),
      const Text('This info appears at the top of every invoice.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 20),
      TextFormField(controller: _nameC, decoration: const InputDecoration(labelText:'Business Name *', border:OutlineInputBorder(), prefixIcon:Icon(Icons.business)),
          validator: (v) => v==null||v.trim().isEmpty ? 'Business Name is required' : null),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextFormField(controller: _phoneC,  decoration: const InputDecoration(labelText:'Primary Phone',  border:OutlineInputBorder(), prefixIcon:Icon(Icons.phone)), keyboardType: TextInputType.phone)),
        const SizedBox(width: 12),
        Expanded(child: TextFormField(controller: _phone2C, decoration: const InputDecoration(labelText:'Alternate Phone', border:OutlineInputBorder()), keyboardType: TextInputType.phone)),
      ]),
      const SizedBox(height: 12),
      TextFormField(controller: _emailC,   decoration: const InputDecoration(labelText:'Email Address', border:OutlineInputBorder(), prefixIcon:Icon(Icons.email)), keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 12),
      TextFormField(controller: _addressC, decoration: const InputDecoration(labelText:'Address', border:OutlineInputBorder(), prefixIcon:Icon(Icons.location_on)), maxLines: 2),

      const SizedBox(height: 32),
      const Text('Fiscal & Tax Setup', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
      const SizedBox(height: 12),
      DropdownButtonFormField<int>(
        initialValue: _fyStartMonth,
        decoration: const InputDecoration(labelText: 'Financial Year Start Month', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_month)),
        items: _months.map((m) => DropdownMenuItem<int>(value: m['val'] as int, child: Text(m['name'] as String))).toList(),
        onChanged: (v) { if (v != null) setState(() => _fyStartMonth = v); },
      ),
      const SizedBox(height: 4),
      Text('Proformas and Invoices will use this to generate numbers (e.g., INV-2025-1).', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
      const SizedBox(height: 16),

      DropdownButtonFormField<String>(
        initialValue: _taxProfile,
        decoration: const InputDecoration(labelText: 'Tax Profile', border: OutlineInputBorder(), prefixIcon: Icon(Icons.public)),
        items: kTaxProfiles.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
        onChanged: (v) { if (v != null) _applyTaxProfile(v); },
      ),
      if (_taxProfile == 'Custom') ...[
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _taxType,
          decoration: const InputDecoration(labelText: 'Tax Type', border: OutlineInputBorder(), prefixIcon: Icon(Icons.receipt_long)),
          items: const [
            DropdownMenuItem(value: 'none', child: Text('No Tax')),
            DropdownMenuItem(value: 'gst', child: Text('GST')),
            DropdownMenuItem(value: 'vat', child: Text('VAT')),
            DropdownMenuItem(value: 'sales', child: Text('Sales Tax')),
            DropdownMenuItem(value: 'consumption', child: Text('Consumption Tax')),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _taxType = v;
              if (_taxType == 'none') _taxRegNoC.clear();
            });
          },
        ),
      ],
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: TextFormField(
            controller: _taxRateC,
            enabled: _taxType != 'none',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '${_taxTypeLabel(_taxType)} Rate %',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.percent),
            ),
            validator: (v) {
              if (_taxType == 'none') return null;
              final n = double.tryParse((v ?? '').trim());
              if (n == null) return 'Invalid rate';
              if (n < 0 || n > 100) return 'Use 0 to 100';
              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _taxMode,
            decoration: const InputDecoration(labelText: 'Tax Mode', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'exclusive', child: Text('Exclusive')),
              DropdownMenuItem(value: 'inclusive', child: Text('Inclusive')),
            ],
            onChanged: _taxType == 'none' ? null : (v) {
              if (v == null) return;
              setState(() => _taxMode = v);
            },
          ),
        ),
      ]),
      if (_taxType != 'none') ...[
        const SizedBox(height: 12),
        TextFormField(
          controller: _taxRegNoC,
          decoration: InputDecoration(
            labelText: _taxRegLabel(_taxType),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.badge_outlined),
          ),
        ),
      ],
      const SizedBox(height: 8),
      Text(
        _taxType == 'none'
            ? 'No tax will be applied in final invoice totals.'
            : 'Final invoices will use ${_taxTypeLabel(_taxType)} (${_taxMode == 'inclusive' ? 'inclusive' : 'exclusive'}) at saved rate.',
        style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
      ),
      const SizedBox(height: 24),
      const Text('Payment Details (Invoice QR)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
      const SizedBox(height: 12),
      TextFormField(controller: _upiC,     decoration: const InputDecoration(labelText:'UPI ID (e.g. 9999999999@ybl)', border:OutlineInputBorder(), prefixIcon:Icon(Icons.qr_code_2))),
      const SizedBox(height: 12),
      TextFormField(controller: _upiNameC, decoration: const InputDecoration(labelText:'UPI Account Name', border:OutlineInputBorder(), prefixIcon:Icon(Icons.person))),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        icon: const Icon(Icons.save), label: const Text('Save Business Info'),
        onPressed: () async {
          if (!_formKey.currentState!.validate()) return;
          final messenger = ScaffoldMessenger.of(context); final nav = Navigator.of(context);
          final effectiveType = _taxType;
          final effectiveRate = effectiveType == 'none' ? 0.0 : (double.tryParse(_taxRateC.text.trim()) ?? 0.0);
          final effectiveMode = effectiveType == 'none' ? 'exclusive' : _taxMode;
          final effectiveRegNo = effectiveType == 'none' ? '' : _taxRegNoC.text.trim();
          await DatabaseHelper.saveBusinessInfo(
            _nameC.text.trim(),
            _phoneC.text.trim(),
            _phone2C.text.trim(),
            _emailC.text.trim(),
            _addressC.text.trim(),
            _upiC.text.trim(),
            _upiNameC.text.trim(),
            taxProfile: _taxProfile,
            taxType: effectiveType,
            taxRate: effectiveRate,
            taxMode: effectiveMode,
            taxRegNo: effectiveRegNo,
            fyStartMonth: _fyStartMonth,
          );
          if (!mounted) return;
          messenger.showSnackBar(const SnackBar(content: Text('Business info saved'))); nav.pop();
        },
      )),
    ]))),
  );
}

// ========Parties Management Screen (Customers & Suppliers)========
class PartiesManagementScreen extends StatelessWidget {
  const PartiesManagementScreen({super.key});
  @override Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(titleSpacing: 0, title: TabBar(tabs: const [Tab(text: 'CUSTOMERS'), Tab(text: 'SUPPLIERS')], indicator: BoxDecoration(borderRadius: BorderRadius.circular(24), color: Colors.black12), indicatorSize: TabBarIndicatorSize.tab, dividerColor: Colors.transparent, labelColor: Colors.black, unselectedLabelColor: Colors.black54, labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
      body: const TabBarView(children: [_PartiesListTab(partyType: 'Customer'), _PartiesListTab(partyType: 'Supplier')]),
    ),
  );
}

class _PartiesListTab extends StatefulWidget {
  final String partyType; const _PartiesListTab({required this.partyType});
  @override State<_PartiesListTab> createState() => _PartiesListTabState();
}

class _PartiesListTabState extends State<_PartiesListTab> {
  List<Map<String, dynamic>> _parties = []; Map<int, double> _owedBalances = {};
  final _searchCtrl = TextEditingController(); Timer? _debounce;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _searchCtrl.dispose(); _debounce?.cancel(); super.dispose(); }

  Future<void> _load() async {
    final data = await DatabaseHelper.getCustomers(search: _searchCtrl.text, partyType: widget.partyType);
    if (!mounted) return;
    setState(() => _parties = data);
    if (widget.partyType == 'Customer') {
      final bals = <int, double>{};
      for (final c in data) { bals[c['id'] as int] = await DatabaseHelper.getCustomerOwedBalance(c['id'] as int, c['name'] as String? ?? ''); }
      if (mounted) setState(() => _owedBalances = bals);
    }
  }

  void _onSearch(String _) { _debounce?.cancel(); _debounce = Timer(const Duration(milliseconds: 300), _load); }

  Future<void> _makePhoneCall(String p1, String p2) async {
    if (p1.isEmpty && p2.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No phone numbers saved.')));
      return;
    }
    Future<void> dial(String num) async {
      final u = Uri.parse('tel:${num.replaceAll(RegExp(r'[^0-9+]'), '')}');
      if (await canLaunchUrl(u)) {
        await launchUrl(u);
      }
    }
    if (p1.isNotEmpty && p2.isNotEmpty) {
      if (!mounted) return;
      showDialog(context: context, builder: (ctx) => SimpleDialog(title: const Text('Call'), children: [ListTile(leading: const Icon(Icons.phone, color: Colors.green), title: Text(p1), onTap: () { Navigator.pop(ctx); dial(p1); }), ListTile(leading: const Icon(Icons.phone, color: Colors.green), title: Text(p2), onTap: () { Navigator.pop(ctx); dial(p2); })]));
    } else {
      dial(p1.isNotEmpty ? p1 : p2);
    }
  }

  Future<void> _showPartyDialog({Map<String, dynamic>? existing}) async {
    final biz = await DatabaseHelper.getBusinessInfo();
    if (!mounted) return;
    final isTax = (biz['taxType'] ?? 'none') != 'none', isEdit = existing != null;
    final nC = TextEditingController(text: existing?['name'] ?? ''), p1C = TextEditingController(text: existing?['phone'] ?? ''), p2C = TextEditingController(text: existing?['phone2'] ?? ''), eC = TextEditingController(text: existing?['email'] ?? ''), aC = TextEditingController(text: existing?['address'] ?? ''), ntC = TextEditingController(text: existing?['notes'] ?? ''), tC = TextEditingController(text: existing?['taxRegNo'] ?? '');
    bool isBl = (existing?['isBlacklisted'] as int? ?? 0) == 1;

    await AppUI.showFormDialog(context, title: isEdit ? 'Edit ${widget.partyType}' : 'Add ${widget.partyType}', onSave: () async {
      isEdit ? await DatabaseHelper.updateCustomer(existing['id'], nC.text.trim(), p1C.text.trim(), p2C.text.trim(), eC.text.trim(), aC.text.trim(), notes: ntC.text.trim(), joinedDate: existing['joinedDate'], isBlacklisted: isBl ? 1 : 0, partyType: widget.partyType, taxRegNo: tC.text.trim()) : await DatabaseHelper.insertCustomer(nC.text.trim(), p1C.text.trim(), p2C.text.trim(), eC.text.trim(), aC.text.trim(), notes: ntC.text.trim(), partyType: widget.partyType, taxRegNo: tC.text.trim());
      _load();
    }, children: [
      AppUI.buildTextField(controller: nC, label: 'Name *', validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
      if (isTax) AppUI.buildTextField(controller: tC, label: '${DatabaseHelper._taxRegLabel(biz['taxType'])} (Optional)', icon: Icons.badge_outlined),
      AppUI.buildTextField(controller: p1C, label: 'Primary Phone', type: TextInputType.phone), AppUI.buildTextField(controller: p2C, label: 'Alternate Phone', type: TextInputType.phone),
      AppUI.buildTextField(controller: eC, label: 'Email', type: TextInputType.emailAddress), AppUI.buildTextField(controller: aC, label: 'Address'), AppUI.buildTextField(controller: ntC, label: 'Notes', maxLines: 2),
      if (isEdit) StatefulBuilder(builder: (ctx, setSt) => SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Blacklist Party'), value: isBl, activeThumbColor: Colors.red, onChanged: (v) => setSt(() => isBl = v))),
    ]);
  }

  Future<void> _delete(int id) async {
    if (!await _confirmDialog(context, title:'Delete', message:'Permanently delete?')) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await DatabaseHelper.deleteCustomer(id);
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Cannot delete: $e')));
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      _SearchBar(controller: _searchCtrl, hint: 'Search ${widget.partyType.toLowerCase()}s...', onClear: () { _searchCtrl.clear(); _load(); }, onChanged: _onSearch),
      Expanded(child: _parties.isEmpty ? Center(child: Text('No ${widget.partyType.toLowerCase()}s yet.')) : ListView.builder(itemCount: _parties.length, itemBuilder: (_, i) {
        final c = _parties[i], name = c['name'] as String? ?? '', owed = _owedBalances[c['id']] ?? 0.0, isBl = (c['isBlacklisted'] as int? ?? 0) == 1;
        return Card(margin: const EdgeInsets.fromLTRB(12, 0, 12, 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isBl ? Colors.red.withValues(alpha: 0.45) : Colors.amber.withValues(alpha: 0.25), width: 0.8)),
          child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () async {
            if (widget.partyType == 'Customer') { await Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerProfileScreen(customer: c))); if (!mounted) return; _load(); }
            else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supplier profile features coming soon.'))); }
          }, child: Padding(padding: appSettingsNotifier.cardPadding, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(backgroundColor: isBl ? Colors.red.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.2), child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(color: isBl ? Colors.red : Colors.amber[900], fontWeight: FontWeight.bold))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [if (isBl) const Padding(padding: EdgeInsets.only(right: 5), child: Icon(Icons.block, size: 14, color: Colors.red)), Expanded(child: Text(name, style: TextStyle(fontWeight: FontWeight.w700, color: isBl ? Colors.red : null)))]),
              if ((c['phone'] ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text('${c['phone']}${c['phone2'].isNotEmpty ? ' / ${c['phone2']}' : ''}', style: const TextStyle(fontSize: 13))),
              if ((c['joinedDate'] ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text('Since ${DatabaseHelper.formatDateString(c['joinedDate'])}', style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color))),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              SizedBox(height: 28, child: PopupMenuButton<String>(icon: const Icon(Icons.more_vert, size: 20), padding: EdgeInsets.zero, onSelected: (v) { if (v=='call') { _makePhoneCall(c['phone']??'', c['phone2']??''); } if (v=='edit') { _showPartyDialog(existing: c); } if (v=='delete') { _delete(c['id']); } }, itemBuilder: (_) => const [PopupMenuItem(value: 'call', child: Row(children: [Icon(Icons.call, size: 18, color: Colors.green), SizedBox(width: 8), Text('Call')])), PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit')])), PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))]))])),
              if (owed > 0) Container(margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange, width: 0.8)), child: Text('Owes ${formatMoney(owed, decimals: 0)}', style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold))),
            ])
          ]))),
        );
      })),
    ]),
    floatingActionButton: FloatingActionButton(onPressed: () => _showPartyDialog(), tooltip: 'Add ${widget.partyType}', child: Icon(widget.partyType == 'Customer' ? Icons.person_add : Icons.domain_add)),
  );
}

// ========Customer Profile Screen========
class CustomerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> customer; const CustomerProfileScreen({super.key, required this.customer});
  @override State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  late Map<String, dynamic> _customer; List<RentalGroup> _allHistory = [], _history = []; Map<String, List<Map<String, dynamic>>> _paymentLogsByGroup = {}; Map<String, dynamic> _stats = {};
  bool _loading = true; final _searchCtrl = TextEditingController(); Timer? _debounce; String _sortMode = kSortOptions.first;

  @override void initState() { super.initState(); _customer = widget.customer; _load(); }
  @override void dispose() { _searchCtrl.dispose(); _debounce?.cancel(); super.dispose(); }

  Future<void> _load() async {
    final id = _customer['id'] as int, name = _customer['name'] as String? ?? '';
    final history = await DatabaseHelper.getCustomerRentalHistory(id, name);
    final paymentMap = await DatabaseHelper.getPaymentLogsForGroups(history), stats = await DatabaseHelper.getCustomerLifetimeStats(id, name);
    final updated = (await DatabaseHelper.getCustomers()).where((c) => c['id'] == id).firstOrNull;
    if (!mounted) return;
    setState(() { if (updated != null) _customer = updated; _allHistory = history; _paymentLogsByGroup = paymentMap; _stats = stats; _applyFilter(); _loading = false; });
  }

  void _onSearch(String _) { _debounce?.cancel(); _debounce = Timer(const Duration(milliseconds: 300), () => setState(_applyFilter)); }

  void _applyFilter() {
    var f = List<RentalGroup>.from(_allHistory); final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) f = f.where((g) => (g.orderId?.toString() ?? '').contains(q) || g.items.any((i) => (i['itemName'] as String? ?? '').toLowerCase().contains(q))).toList();
    _applySort(f, _sortMode); _history = f;
  }

  Future<void> _toggleBlacklist() async {
    final cur = (_customer['isBlacklisted'] as int? ?? 0) == 1;
    if (await _confirmDialog(context, title: cur ? 'Remove Flag' : 'Blacklist', message: cur ? 'Remove blacklist?' : 'Flag as blacklisted?', confirmLabel: cur ? 'Remove' : 'Blacklist')) {
      if (!mounted) return;
      await DatabaseHelper.toggleBlacklist(_customer['id'] as int, !cur); _load();
    }
  }

  Future<void> _openInvoicePdf(int orderId, {required bool finalInvoice}) async {
    final size = await pickPdfSize(context); if (size == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF...')));
    try {
      final bytes = finalInvoice ? await DatabaseHelper.generatePdfFinalInvoiceForOrder(orderId, pageSize: size) : await DatabaseHelper.generatePdfProformaForOrder(orderId, pageSize: size);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: Text(finalInvoice ? 'Final Invoice' : 'Proforma')), body: PdfPreview(build: (_) async => bytes))));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'))); }
  }

  Future<void> _handleReturn(RentalGroup g) async => await TransactionDialogs.handleReturn(context, g, _load);
  Future<void> _settleGroup(RentalGroup g) async => await TransactionDialogs.settle(context, g, _load);

  Widget _buildCard(RentalGroup g) => UniversalRentalCard(group: g, paymentLogs: _paymentLogsByGroup[g.paymentGroupKey], showCustomerName: false, onEdit: () => TransactionDialogs.editGroup(context, g, _load), onReturn: !g.isFullyReturned ? () => _handleReturn(g) : null, onSettle: g.isFullyReturned && !g.isSettled ? () => _settleGroup(g) : null, onPdf: g.isFullyReturned && g.orderId != null ? () => _openInvoicePdf(g.orderId!, finalInvoice: true) : null, onCancel: g.isFullyReturned && !g.isCancelled ? () async { final confirmed = await _confirmDialog(context, title: 'Cancel', message: 'Cancel Invoice?'); if (!mounted) return; if (confirmed) { await DatabaseHelper.cancelRentalGroup(g.items.map((i) => i['id'] as int).toList()); _load(); } } : null, onDelete: g.isFullyReturned ? () async { final confirmed = await _confirmDialog(context, title: 'Delete', message: 'Delete history?'); if (!mounted) return; if (confirmed) { await DatabaseHelper.deleteRentalGroup(g.items); _load(); } } : null, onViewPayments: () => showDialog(context: context, builder: (ctx) => SimpleDialog(title: const Text('Select View'), children: [SimpleDialogOption(onPressed: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentLedgerScreen(initialTabIndex: 1, initialOrderId: g.orderId, initialFallbackRentalId: g.orderId == null ? (g.fallbackId ?? g.items.firstOrNull?['id']) : null))); }, child: const Row(children: [Icon(Icons.history, color: Colors.blue), SizedBox(width: 12), Text('Payment History')])), SimpleDialogOption(onPressed: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentLedgerScreen(initialOrderId: g.orderId, initialFallbackRentalId: g.orderId == null ? (g.fallbackId ?? g.items.firstOrNull?['id']) : null))); }, child: const Row(children: [Icon(Icons.account_balance_wallet, color: Colors.orange), SizedBox(width: 12), Text('Outstanding Ledger')]))])));

  @override Widget build(BuildContext context) {
    final name = _customer['name'] as String? ?? '', isBl = (_customer['isBlacklisted'] as int? ?? 0) == 1, owed = (_stats['owedBalance'] as double?) ?? 0.0, ref = (_stats['refundBalance'] as double?) ?? 0.0;
    return Scaffold(
      appBar: AppBar(title: Text(name), actions: [IconButton(icon: Icon(isBl ? Icons.block : Icons.person_off_outlined, color: isBl ? Colors.red : null), onPressed: _toggleBlacklist)]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : Column(children: [
        Expanded(child: RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            Row(children: [CircleAvatar(radius: 28, backgroundColor: isBl ? Colors.red.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.2), child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isBl ? Colors.red : Colors.amber))), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))), if (isBl) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red)), child: const Text('BLACKLISTED', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)))]), if ((_customer['joinedDate'] ?? '').isNotEmpty) Text('Since ${DatabaseHelper.formatDateString(_customer['joinedDate'])}', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color))]))]),
            if ((_customer['phone']??'').isNotEmpty || (_customer['email']??'').isNotEmpty || (_customer['address']??'').isNotEmpty || (_customer['notes']??'').isNotEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
            if ((_customer['phone']??'').isNotEmpty) _InfoRow(icon: Icons.phone, text: '${_customer['phone']}${(_customer['phone2']??'').isNotEmpty ? ' / ${_customer['phone2']}' : ''}'), if ((_customer['email']??'').isNotEmpty) _InfoRow(icon: Icons.email, text: _customer['email']), if ((_customer['address']??'').isNotEmpty) _InfoRow(icon: Icons.location_on, text: _customer['address']), if ((_customer['notes']??'').isNotEmpty) _InfoRow(icon: Icons.notes, text: _customer['notes']),
          ]))),
          const SizedBox(height: 12),
          GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.75, children: [_MiniStatCard(label: 'Lifetime Billed', value: formatMoney(_stats['totalSpent'] ?? 0), icon: Icons.receipt_long, color: Colors.blue), _MiniStatCard(label: 'Total Invoices', value: '${_stats['totalInvoices'] ?? 0}', icon: Icons.folder_copy, color: Colors.purple), _MiniStatCard(label: 'Active Items', value: '${_stats['activeRentals'] ?? 0}', icon: Icons.handshake, color: Colors.orange), if ((_stats['badDebt'] ?? 0) > 0) _MiniStatCard(label: 'Bad Debt', value: formatMoney(_stats['badDebt']), icon: Icons.money_off, color: Colors.redAccent), if (owed > 0) _MiniStatCard(label: 'Amount Due', value: formatMoney(owed), icon: Icons.payments, color: Colors.red), if (ref > 0) _MiniStatCard(label: 'Refund Due', value: formatMoney(ref), icon: Icons.undo, color: Colors.green)]),
          if (owed > 0 || ref > 0) Card(margin: const EdgeInsets.only(top: 12), color: owed > 0 ? Colors.orange.withValues(alpha: 0.08) : Colors.green.withValues(alpha: 0.08), shape: RoundedRectangleBorder(side: BorderSide(color: owed > 0 ? Colors.orange : Colors.green), borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [Icon(owed > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline, color: owed > 0 ? Colors.orange : Colors.green), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(owed > 0 ? 'Outstanding Balance' : 'Refund Pending', style: TextStyle(fontWeight: FontWeight.bold, color: owed > 0 ? Colors.orange : Colors.green)), Text(owed > 0 ? 'Owes ${formatMoney(owed)}' : 'You owe ${formatMoney(ref)}', style: const TextStyle(fontSize: 13))]))]))),
          const SizedBox(height: 16), Row(children: [const Icon(Icons.history, size: 18), const SizedBox(width: 6), Text('Rental History (${_history.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]), const SizedBox(height: 8),
          TextField(controller: _searchCtrl, decoration: InputDecoration(hintText: 'Search invoices...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: EdgeInsets.zero, suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [if (_searchCtrl.text.isNotEmpty) IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); setState(_applyFilter); }), PopupMenuButton<String>(icon: Stack(clipBehavior: Clip.none, children: [Icon(Icons.filter_list, color: _sortMode != kSortOptions.first ? Colors.amber : null), if (_sortMode != kSortOptions.first) Positioned(right: -2, top: -2, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)))]), initialValue: _sortMode, onSelected: (v) => setState(() { _sortMode = v; _applyFilter(); }), itemBuilder: (_) => kSortOptions.map((o) => PopupMenuItem(value: o, child: Row(children: [Icon(_sortMode == o ? Icons.radio_button_checked : Icons.radio_button_off, size: 18, color: Colors.amber), const SizedBox(width: 8), Text(o)]))).toList())])), onChanged: _onSearch),
          const SizedBox(height: 12),
          if (_history.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No rental history matches.', style: TextStyle(color: Colors.grey)))) else ..._history.map(_buildCard),
          const SizedBox(height: 80),
        ]))),
      ]),
    );
  }
}

// Helpers used by CustomerProfileScreen
class _InfoRow extends StatelessWidget {
  final IconData icon; final String text;
  const _InfoRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: Colors.amber),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
    ]),
  );
}

class _MiniStatCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _MiniStatCard({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(10), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(icon, size: 20, color: color),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color)),
        ]),
      ],
    )),
  );
}

// =============================
// VII. TRANSACTION MODULE
// =============================



// ========New Order Screen========

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key});
  @override State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  List<Map<String, dynamic>> _items = [], _customers = [];
  final List<TransactionLineItem> _lines = [];
  int? _selectedCustomerId; DateTime _selectedDate = DateTime.now(); String _selectedPaymentMethod = 'Cash';
  final _advC = TextEditingController(), _notesC = TextEditingController(), _dateCtrl = TextEditingController();
  bool _isFormExpanded = true;

  @override void initState() { super.initState(); _dateCtrl.text = DatabaseHelper.formatDateFromDt(_selectedDate); _addLine(); _load(); }
  @override void dispose() { for (final l in _lines) { l.dispose(); } _advC.dispose(); _notesC.dispose(); _dateCtrl.dispose(); super.dispose(); }

  void _addLine() => setState(() => _lines.add(TransactionLineItem()));
  void _removeLine(int index) { if (_lines.length > 1) { setState(() { _lines[index].dispose(); _lines.removeAt(index); }); } }

  Future<void> _load() async {
    final items = await DatabaseHelper.getItems(), customers = await DatabaseHelper.getCustomers();
    if (!mounted) return;
    setState(() { _items=items; _customers=customers; });
  }

  Future<void> _saveOrder() async {
    if (_selectedCustomerId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a customer.'))); return; }
    final cust = _customers.firstWhere((c) => c['id']==_selectedCustomerId, orElse: () => <String,dynamic>{});

    // CPA Control: Verify financial standing and blacklist status before committing inventory.
    final isBlacklisted = (cust['isBlacklisted'] as int? ?? 0) == 1;
    final stats = await DatabaseHelper.getCustomerLifetimeStats(cust['id'] as int, cust['name'] as String? ?? '');
    if (!mounted) return;
    final badDebt = (stats['badDebt'] as num?)?.toDouble() ?? 0.0;

    if (isBlacklisted || badDebt > 0) {
      final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text('High Risk Customer')]),
            content: Text('Warning:\n\n'
                '${isBlacklisted ? '• This customer is strictly BLACKLISTED.\n' : ''}'
                '${badDebt > 0 ? '• Prior bad debt / write-off: ${formatMoney(badDebt)}.\n' : ''}'
                '\nDo you really want to proceed with this rental?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Proceed Anyway')
              ),
            ],
          )
      );
      if (!mounted) return;
      if (proceed != true) return;
    }

    final sel = <Map<String,dynamic>>[]; bool isFirst = true;
    for (final l in _lines) {
      if (l.itemId == null) continue;
      final qty = int.tryParse(l.qtyC.text) ?? 0; if (qty <= 0) continue;
      sel.add({'itemId': l.itemId, 'customerId': cust['id'], 'qty': qty, 'rate': double.tryParse(l.priceC.text) ?? 0.0, 'contractor': cust['name']?.toString().isNotEmpty==true ? cust['name'] : 'Walk-in', 'phone': cust['phone'] ?? '', 'phone2': cust['phone2'] ?? '', 'address': cust['address'] ?? '', 'checkoutDate': DatabaseHelper.isoDate(_selectedDate), 'advanceDeposit': isFirst ? (double.tryParse(_advC.text) ?? 0.0) : 0.0, 'notes': _notesC.text.trim(), 'paymentMethod': isFirst ? _selectedPaymentMethod : ''});
      isFirst = false;
    }
    if (sel.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one item.'))); return; }
    try {
      final oid = await DatabaseHelper.createOrder(cust['id'], sel.first['contractor'], DatabaseHelper.isoDate(_selectedDate));
      await DatabaseHelper.createOrderRentals(oid, sel);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order saved!')));
      Navigator.pop(context);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'))); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create Rental Order')),
    body: Column(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Customer Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), TextButton.icon(onPressed: () => setState(() => _isFormExpanded = !_isFormExpanded), icon: Icon(_isFormExpanded ? Icons.expand_less : Icons.expand_more), label: Text(_isFormExpanded ? 'Hide' : 'Show'))])),
      if (_isFormExpanded) SingleChildScrollView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: Column(children: [
        AppUI.buildPartyDateRow(
          context: context, partyLabel: 'Customer', partyIcon: Icons.person, selectedPartyId: _selectedCustomerId,
          partyList: _customers, filter: (c, q) => (c['name']?.toString().toLowerCase() ?? '').contains(q.toLowerCase()) || (c['phone']?.toString() ?? '').contains(q),
          itemBuilder: (c) => ListTile(leading: const CircleAvatar(child: Icon(Icons.person, size: 20)), title: Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(c['phone']?.toString().isNotEmpty == true ? c['phone'] : 'No phone'), trailing: const Icon(Icons.chevron_right, size: 16)),
          onPartySelected: (id) => setState(() => _selectedCustomerId = id),
          selectedDate: _selectedDate, dateCtrl: _dateCtrl, dateLabel: 'Checkout Date', onDateSelected: (d) => setState(() => _selectedDate = d),
        ),
        const SizedBox(height: 12),
        Row(children: [ Expanded(child: TextFormField(controller: _advC, decoration: AppUI.inputDecoration('Advance ($curr)', i: Icons.payments), keyboardType: const TextInputType.numberWithOptions(decimal: true))), const SizedBox(width: 8), Expanded(child: DropdownButtonFormField<String>(initialValue: _selectedPaymentMethod, decoration: AppUI.inputDecoration('Method', i: Icons.payment), items: kPaymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: (v) { if (v != null) setState(() => _selectedPaymentMethod = v); })) ]),
        const SizedBox(height: 12), TextFormField(controller: _notesC, decoration: AppUI.inputDecoration('Order Notes', i: Icons.notes)),
      ])),
      Container(width: double.infinity, color: Theme.of(context).colorScheme.surfaceContainerHighest, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: const Text('Select Equipment', style: TextStyle(fontWeight: FontWeight.bold))),
      Expanded(child: AppUI.buildLineItemsList(
        context: context, lines: _lines, inventoryItems: _items, priceLabel: 'Rate ($curr)',
        onAddLine: _addLine, onRemoveLine: _removeLine, onStateChanged: () => setState((){}),
      )),
      Padding(padding: const EdgeInsets.all(12), child: SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: const Icon(Icons.check), label: const Text('Save Rental'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: _saveOrder))),
    ]),
  );
}

// ========Orders List Screen========

class OrdersListScreen extends StatefulWidget {
  final bool isTab;
  const OrdersListScreen({super.key, this.isTab = false});
  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async { final data = await DatabaseHelper.getOrders(); if (!mounted) return; setState(() => _orders = data); }

  Future<void> _openPdf(int orderId, {bool share = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final size = await pickPdfSize(context);
    if (size == null || !mounted) return;

    messenger.showSnackBar(const SnackBar(content: Text('Generating PDF...')));
    try {
      final bytes = await DatabaseHelper.generatePdfProformaForOrder(orderId, pageSize: size);
      if (share) { await Printing.sharePdf(bytes: bytes, filename: 'proforma_order_$orderId.pdf'); }
      else {
        if (!mounted) return;
        await nav.push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Proforma Preview')), body: PdfPreview(build: (_) async => bytes))));
      }
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.isTab ? null : AppBar(title: const Text('Proforma')),
    body: _orders.isEmpty ? const Center(child: Text('No orders yet.'))
        : RefreshIndicator(onRefresh: _load, child: ListView.builder(
      padding: const EdgeInsets.all(12), itemCount: _orders.length,
      itemBuilder: (_, i) {
        final o = _orders[i];
        final name = (o['customerName'] as String? ?? '').isNotEmpty ? o['customerName'] as String : 'Walk-in Customer';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(child: Icon(Icons.receipt_long)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Proforma: ${o['proformaNumber']?.toString().isNotEmpty == true ? o['proformaNumber'] : '#${o['id']}'}', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                      const SizedBox(height: 2),
                      Text('Date: ${DatabaseHelper.formatDateString(o['createdDate'] as String? ?? '')}', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert, size: 20),
                    tooltip: 'Options',
                    onSelected: (val) {
                      if (val == 'preview') { _openPdf(o['id'] as int); }
                      if (val == 'share') { _openPdf(o['id'] as int, share: true); }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'preview', child: Row(children: [Icon(Icons.visibility_outlined, size: 18), SizedBox(width: 8), Text('Preview PDF')])),
                      PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.share_outlined, size: 18), SizedBox(width: 8), Text('Share PDF')])),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    )),
  );
}

// ========Order Details Screen========

class OrderDetailsScreen extends StatefulWidget {
  final int orderId;
  const OrderDetailsScreen({super.key, required this.orderId});
  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  List<Map<String, dynamic>> _rentals = [];

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { final data = await DatabaseHelper.getRentalsByOrder(widget.orderId); if (!mounted) return; setState(() => _rentals = data); }

  @override
  Widget build(BuildContext context) {
    double grandTotal = 0.0;

    return Scaffold(
      appBar: AppBar(title: Text('Order #${widget.orderId}')),
      body: _rentals.isEmpty ? const Center(child: Text('No items in this order.'))
          : Column(children: [
        Expanded(child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: _rentals.length, itemBuilder: (_, i) {
          final r = _rentals[i];
          final qty = r['qty'] as int? ?? 0;
          final rate = (r['rentalRate'] as num?)?.toDouble() ?? 0.0;
          final penalty = (r['penaltyFee'] as num?)?.toDouble() ?? 0.0;

          // Calculate exact days charged
          final days = RentalUtils.calculateChargeDays(
            r['checkoutDate'] as String?,
            r['returnDate'] as String?,
            r['returned'] as int? ?? 0,
          );

          // Calculate true line total including penalties
          final lineTotal = (rate * qty * days) + penalty;
          grandTotal += lineTotal;

          final returnText = DatabaseHelper.formatDateString(r['returnDate'] as String?);
          final statusText = (r['returned'] == 1) ? 'Returned: $returnText' : 'Active (Out)';

          return Card(margin:const EdgeInsets.only(bottom:8), child:ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(r['itemName'] ?? '', style:const TextStyle(fontWeight:FontWeight.bold)),
            subtitle: Text.rich(
              TextSpan(children: [
                TextSpan(text: 'Qty: $qty  |  Rate: ${formatMoney(rate)}/day  |  Days: $days\n'),
                TextSpan(text: statusText),
                if (penalty > 0)
                  TextSpan(text: '\n+ Damage Penalty: ${formatMoney(penalty)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ]),
            ),
            isThreeLine: true,
            trailing: Text(formatMoney(lineTotal), style:const TextStyle(fontWeight:FontWeight.bold, fontSize: 15)),
          ));
        })),
        Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal:16, vertical:12),
            child: Text('Grand Total: ${formatMoney(grandTotal)}', style:const TextStyle(fontSize:16, fontWeight:FontWeight.bold), textAlign:TextAlign.right)
        ),
      ]),
    );
  }
}

// ========Purchase Orders List Screen========

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  List<Map<String, dynamic>> _pos = [];
  Map<int, List<Map<String, dynamic>>> _paymentLogsByPO = {};
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _sortMode = kSortOptions.first;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final data = await DatabaseHelper.getPurchaseOrders();
    final logs = await DatabaseHelper.getVendorPaymentHistory();

    Map<int, List<Map<String, dynamic>>> logMap = {};
    for (var l in logs) {
      final pId = l['poId'] as int;
      logMap.putIfAbsent(pId, () => []).add(l);
    }
    for (var key in logMap.keys) {
      logMap[key]!.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    }

    List<Map<String, dynamic>> filtered = List.from(data);

    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      filtered = filtered.where((p) =>
      (p['supplierName']?.toString().toLowerCase() ?? '').contains(q) ||
          (p['poNumber']?.toString().toLowerCase() ?? '').contains(q)
      ).toList();
    }

    if (_sortMode == 'Date (Newest)') {
      filtered.sort((a, b) => (b['orderDate'] ?? '').compareTo(a['orderDate'] ?? ''));
    } else if (_sortMode == 'Date (Oldest)') {
      filtered.sort((a, b) => (a['orderDate'] ?? '').compareTo(b['orderDate'] ?? ''));
    } else if (_sortMode == 'Highest Balance') {
      filtered.sort((a, b) {
        final balA = ((a['grandTotal'] as num?) ?? 0) - ((a['amountPaid'] as num?) ?? 0);
        final balB = ((b['grandTotal'] as num?) ?? 0) - ((b['amountPaid'] as num?) ?? 0);
        return balB.compareTo(balA);
      });
    }

    if (!mounted) return;
    setState(() {
      _pos = filtered;
      _paymentLogsByPO = logMap;
      _isLoading = false;
    });
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _loadData);
  }


  Widget _tag(String text, Color color) => Container(
    margin: const EdgeInsets.only(left: 6),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.bold)),
  );

  Widget _finRow(String lbl, String val, {Color? color, bool strike = false, bool bold = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(lbl, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      Text(val, style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal, decoration: strike ? TextDecoration.lineThrough : null))
    ]),
  );

  Widget _buildPOCard(Map<String, dynamic> po) {
    final settings = AppProvider.of(context);
    final compact = settings.cardDensity == 'compact';
    final divider = Divider(height: compact ? 10.0 : 16.0);

    final date = DatabaseHelper.formatDateString(po['orderDate'] as String?);
    final grandTotal = (po['grandTotal'] as num?)?.toDouble() ?? 0.0;
    final amountPaid = (po['amountPaid'] as num?)?.toDouble() ?? 0.0;
    final subtotal = (po['subtotal'] as num?)?.toDouble() ?? 0.0;
    final taxAmount = (po['taxAmount'] as num?)?.toDouble() ?? 0.0;
    final discount = (po['discount'] as num?)?.toDouble() ?? 0.0;
    final penalty = (po['penaltyFee'] as num?)?.toDouble() ?? 0.0;
    final isCancelled = (po['isCancelled'] as int? ?? 0) == 1;
    final balance = grandTotal - amountPaid;
    final isSettled = balance <= 0 && !isCancelled;

    final int poId = po['id'] as int;
    final payments = _paymentLogsByPO[poId] ?? [];
    double initialAdvance = 0.0;
    double laterPaid = 0.0;
    double totalRefunds = 0.0;

    if (payments.isNotEmpty) {
      for (var p in payments) {
        double amt = (p['amount'] as num).toDouble();
        if (amt < 0) {
          totalRefunds += amt.abs();
        } else {
          String pDate = (p['paidAt'] as String).split('T')[0];
          String cDate = po['orderDate'].toString().split('T')[0];
          if (pDate == cDate && initialAdvance == 0.0 && p['id'] == payments.first['id']) {
            initialAdvance += amt;
          } else {
            laterPaid += amt;
          }
        }
      }
    } else {
      if (amountPaid < 0) {
        totalRefunds = amountPaid.abs();
      } else {
        initialAdvance = amountPaid;
      }
    }

    final supplierName = po['supplierName'] as String? ?? 'Unknown Supplier';
    final phone = po['phone'] as String? ?? '';
    final phone2 = po['phone2'] as String? ?? '';
    final poNum = po['poNumber'] as String? ?? '';
    final billNum = po['billNumber'] as String? ?? '';

    final itemsSummary = po['itemsSummary'] as String? ?? '';
    final notes = po['notes'] as String? ?? '';
    final List<Widget> itemWidgets = [];
    if (itemsSummary.isNotEmpty) {
      final lines = itemsSummary.split('^');
      for (final line in lines) {
        final parts = line.split('|');
        if (parts.length == 4) {
          itemWidgets.add(
            Padding(
              padding: EdgeInsets.symmetric(vertical: compact ? 2 : 4),
              child: Row(
                children: [
                  Icon(isCancelled ? Icons.cancel : Icons.radio_button_checked, size: compact ? 14 : 16, color: isCancelled ? Colors.redAccent : Colors.blueGrey),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${parts[0]} x ${parts[1]} @ ${formatMoney(double.tryParse(parts[2]) ?? 0.0)}', style: TextStyle(fontSize: 13, decoration: isCancelled ? TextDecoration.lineThrough : null, color: isCancelled ? Colors.grey : null))),
                  Text(formatMoney(double.tryParse(parts[3]) ?? 0.0), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, decoration: isCancelled ? TextDecoration.lineThrough : null, color: isCancelled ? Colors.grey : null)),
                ],
              ),
            ),
          );
        }
      }
    }

    return Card(
      margin: EdgeInsets.only(bottom: compact ? 8 : 10),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: isCancelled ? BoxDecoration(border: Border(left: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5), width: 4))) : null,
        padding: settings.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text.rich(TextSpan(children: [
                  TextSpan(text: supplierName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  if (phone.isNotEmpty) TextSpan(text: '  | Ph# $phone${phone2.isNotEmpty ? ' / $phone2' : ''}', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
                ]), overflow: TextOverflow.ellipsis)),
                if (isCancelled) _tag('CANCELLED', Colors.redAccent) else if (isSettled) _tag('PAID', Colors.greenAccent) else _tag('PAYABLE', Colors.orange),
                SizedBox(
                  width: 32,
                  child: PopupMenuButton<String>(
                    tooltip: 'Options',
                    onSelected: (val) async {
                      if (val == 'cancel') {
                        final ok = await _confirmDialog(context, title: 'Void PO', message: 'Cancel this purchase and reverse inventory?', confirmLabel: 'Void');
                        if (ok) { await DatabaseHelper.cancelPurchaseOrder(po['id'] as int); _loadData(); }
                      } else if (val == 'delete') {
                        final ok = await _confirmDialog(context, title: 'Delete PO', message: 'Permanently remove record and inventory?');
                        if (ok) { await DatabaseHelper.deletePurchaseOrder(po['id'] as int); _loadData(); }
                      }
                    },
                    itemBuilder: (_) => [
                      if (!isCancelled) const PopupMenuItem(value: 'cancel', child: Row(children: [Icon(Icons.cancel_outlined, size: 18, color: Colors.orange), SizedBox(width: 8), Text('Cancel PO', style: TextStyle(color: Colors.orange))])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete PO', style: TextStyle(color: Colors.red))])),
                    ],
                    child: const Align(alignment: Alignment.centerRight, child: Icon(Icons.more_vert, size: 20)),
                  ),
                ),
              ],
            ),
            Padding(padding: EdgeInsets.only(top: compact ? 1 : 2), child: Text.rich(TextSpan(style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color), children: [
              TextSpan(text: poNum, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (billNum.isNotEmpty) TextSpan(text: ' ref $billNum', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
            ]))),
            Padding(padding: EdgeInsets.only(top: compact ? 1 : 2), child: Text('Date: $date', style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color))),
            divider,
            if (itemWidgets.isNotEmpty) ...itemWidgets,
            if (notes.isNotEmpty) Padding(padding: EdgeInsets.only(top: compact ? 2 : 4), child: Text('Note: $notes', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12))),
            if (itemWidgets.isNotEmpty || notes.isNotEmpty) divider,
            // Financial Totals - Standardized Ledger Order
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _finRow('Total Billed:', formatMoney(subtotal), strike: isCancelled),
                if (penalty > 0) _finRow('Penalty:', '+ ${formatMoney(penalty)}', color: Colors.redAccent),
                if (taxAmount > 0) _finRow('Tax:', '+ ${formatMoney(taxAmount)}'),
                if (discount > 0) _finRow('Discount:', '- ${formatMoney(discount)}'),
                if (initialAdvance > 0) _finRow('Advance/Security:', '- ${formatMoney(initialAdvance)}'),
                if (laterPaid > 0) _finRow('Payment(s):', '- ${formatMoney(laterPaid)}'),
                if (totalRefunds > 0) _finRow('Refund(s) Rcvd:', '+ ${formatMoney(totalRefunds)}', color: Colors.orange),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isSettled ? 'Settled: Balance Cleared' : (isCancelled ? 'VOIDED / CANCELLED' : 'Final Balance: ${formatMoney(balance)}'),
                  style: TextStyle(
                      color: isCancelled ? Colors.grey : (isSettled ? Colors.grey : (balance > 0 ? Colors.orange : Colors.green)),
                      fontWeight: FontWeight.bold
                  ),
                ),
                InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => SimpleDialog(
                        title: const Text('Select View'),
                        children: [
                          SimpleDialogOption(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentLedgerScreen(
                                initialLedgerType: 'Vendor Ledger (A/P)',
                                initialTabIndex: 1,
                                initialDisplayDocNumber: po['poNumber'] as String? ?? 'PO#${po['id']}',
                              )));
                            },
                            child: const Row(children: [Icon(Icons.history, color: Colors.blue), SizedBox(width: 12), Text('Payment History')]),
                          ),
                          SimpleDialogOption(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentLedgerScreen(
                                initialLedgerType: 'Vendor Ledger (A/P)',
                                initialTabIndex: 0,
                                initialDisplayDocNumber: po['poNumber'] as String? ?? 'PO#${po['id']}',
                              )));
                            },
                            child: const Row(children: [Icon(Icons.account_balance_wallet, color: Colors.orange), SizedBox(width: 12), Text('Outstanding Ledger')]),
                          ),
                        ],
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.receipt_long, color: Colors.amber, size: 22),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('POs & Bills')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search supplier or PO...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (_searchCtrl.text.isNotEmpty)
                    IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _loadData(); }),
                  PopupMenuButton<String>(
                    icon: Stack(clipBehavior: Clip.none, children: [
                      Icon(Icons.filter_list, color: _sortMode != kSortOptions.first ? Colors.amber : null),
                      if (_sortMode != kSortOptions.first) Positioned(
                        right: -2, top: -2,
                        child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)),
                      ),
                    ]),
                    tooltip: 'Sort by',
                    initialValue: _sortMode,
                    onSelected: (v) { setState(() => _sortMode = v); _loadData(); },
                    itemBuilder: (_) => kSortOptions.map((o) => PopupMenuItem(
                      value: o,
                      child: Row(children: [
                        Icon(_sortMode == o ? Icons.radio_button_checked : Icons.radio_button_off, size: 18, color: Colors.amber),
                        const SizedBox(width: 8),
                        Text(o),
                      ]),
                    )).toList(),
                  ),
                ]),
              ),
              onChanged: _onSearch,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _pos.isEmpty
                ? const Center(child: Text('No Purchase Orders recorded yet.\nTap + to procure new equipment.', textAlign: TextAlign.center))
                : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                itemCount: _pos.length,
                itemBuilder: (context, index) => _buildPOCard(_pos[index]),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const NewPurchaseOrderScreen()));
          if (!mounted) return;
          _loadData();
        },
        tooltip: 'New PO',
        child: const Icon(Icons.add_shopping_cart),
      ),
    );
  }
}

// ========New Purchase Order Screen========

class NewPurchaseOrderScreen extends StatefulWidget {
  const NewPurchaseOrderScreen({super.key});

  @override
  State<NewPurchaseOrderScreen> createState() => _NewPurchaseOrderScreenState();
}

class _NewPurchaseOrderScreenState extends State<NewPurchaseOrderScreen> {
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _inventoryItems = [];

  int? _selectedSupplierId;
  DateTime _orderDate = DateTime.now();
  String _selectedPaymentMethod = 'Cash';
  bool _isFormExpanded = true;

  final _dateCtrl = TextEditingController();
  final _poNumC = TextEditingController();
  final _billNumC = TextEditingController();
  final _notesC = TextEditingController();
  final _taxRateC = TextEditingController(text: '0');
  final _amountPaidC = TextEditingController(text: '0');

  final List<TransactionLineItem> _lines = [];

  @override
  void initState() {
    super.initState();
    _dateCtrl.text = DatabaseHelper.formatDateFromDt(_orderDate);
    _addLine();
    _loadData();
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _poNumC.dispose();
    _billNumC.dispose();
    _notesC.dispose();
    _taxRateC.dispose();
    _amountPaidC.dispose();
    for (var l in _lines) { l.dispose(); }
    super.dispose();
  }

  Future<void> _updatePoNumber(DateTime date) async {
    final nextPo = await DatabaseHelper.peekNextSequence('PO', date);
    if (mounted) setState(() => _poNumC.text = nextPo);
  }

  Future<void> _loadData() async {
    final suppliers = await DatabaseHelper.getSuppliers();
    final items = await DatabaseHelper.getItems();
    if (!mounted) return;
    setState(() {
      _suppliers = suppliers;
      _inventoryItems = items;
    });
    _updatePoNumber(_orderDate);
  }

  void _addLine() => setState(() => _lines.add(TransactionLineItem()));
  void _removeLine(int index) { if (_lines.length > 1) setState(() { _lines[index].dispose(); _lines.removeAt(index); }); }

  double _calculateSubtotal() {
    double sub = 0.0;
    for (var l in _lines) {
      final qty = int.tryParse(l.qtyC.text) ?? 0;
      final cost = double.tryParse(l.priceC.text) ?? 0.0;
      sub += (qty * cost);
    }
    return sub;
  }

  Future<void> _savePO() async {
    if (_selectedSupplierId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a supplier.'))); return; }

    final subtotal = _calculateSubtotal();
    final taxRate = double.tryParse(_taxRateC.text) ?? 0.0;
    final taxAmount = subtotal * (taxRate / 100.0);
    final grandTotal = subtotal + taxAmount;
    final amountPaid = double.tryParse(_amountPaidC.text) ?? 0.0;

    List<Map<String, dynamic>> processedItems = [];
    for (var l in _lines) {
      if (l.itemId == null) continue;
      final qty = int.tryParse(l.qtyC.text) ?? 0;
      final cost = double.tryParse(l.priceC.text) ?? 0.0;
      if (qty <= 0) continue;

      processedItems.add({
        'itemId': l.itemId,
        'qty': qty,
        'unitCost': cost,
        'lineTotal': qty * cost,
      });
    }

    if (processedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one valid item line.')));
      return;
    }

    final poData = {
      'supplierId': _selectedSupplierId,
      'poNumber': _poNumC.text.trim(),
      'billNumber': _billNumC.text.trim(),
      'orderDate': DatabaseHelper.isoDate(_orderDate),
      'subtotal': subtotal,
      'taxAmount': taxAmount,
      'grandTotal': grandTotal,
      'amountPaid': amountPaid,
      'paymentMethod': _selectedPaymentMethod,
      'notes': _notesC.text.trim()
    };

    try {
      await DatabaseHelper.createPurchaseOrder(poData, processedItems);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase Order saved. Inventory costs updated.')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save PO: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = _calculateSubtotal();
    final taxRate = double.tryParse(_taxRateC.text) ?? 0.0;
    final taxAmount = subtotal * (taxRate / 100.0);
    final grandTotal = subtotal + taxAmount;

    return Scaffold(
      appBar: AppBar(title: const Text('New Purchase Order')),
      body: Column(
        children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Vendor Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), TextButton.icon(onPressed: () => setState(() => _isFormExpanded = !_isFormExpanded), icon: Icon(_isFormExpanded ? Icons.expand_less : Icons.expand_more), label: Text(_isFormExpanded ? 'Hide' : 'Show'))])),
          if (_isFormExpanded) Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: Column(children: [
            AppUI.buildPartyDateRow(
                context: context, partyLabel: 'Vendor', partyIcon: Icons.domain, selectedPartyId: _selectedSupplierId, partyList: _suppliers,
                filter: (s, q) => (s['name']?.toString().toLowerCase() ?? '').contains(q.toLowerCase()),
                itemBuilder: (s) => ListTile(leading: const Icon(Icons.domain), title: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)), trailing: const Icon(Icons.chevron_right, size: 16)),
                onPartySelected: (id) => setState(() => _selectedSupplierId = id),
                selectedDate: _orderDate, dateCtrl: _dateCtrl, dateLabel: 'Date', onDateSelected: (d) { setState(() { _orderDate = d; }); _updatePoNumber(d); }
            ),
            const SizedBox(height: 12),
            Row(children: [ Expanded(child: TextFormField(controller: _amountPaidC, decoration: AppUI.inputDecoration('Advance ($curr)', i: Icons.payments), keyboardType: const TextInputType.numberWithOptions(decimal: true))), const SizedBox(width: 8), Expanded(child: DropdownButtonFormField<String>(initialValue: _selectedPaymentMethod, decoration: AppUI.inputDecoration('Method', i: Icons.payment), items: kPaymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: (v) { if (v != null) setState(() => _selectedPaymentMethod = v); })) ]),
            const SizedBox(height: 12),
            Row(children: [ Expanded(child: TextFormField(controller: _poNumC, decoration: AppUI.inputDecoration('PO Number', i: Icons.receipt_long))), const SizedBox(width: 8), Expanded(child: TextFormField(controller: _billNumC, decoration: AppUI.inputDecoration('Vendor Bill No.', i: Icons.receipt))) ]),
            const SizedBox(height: 12), TextFormField(controller: _notesC, decoration: AppUI.inputDecoration('Notes', i: Icons.notes)),
          ])),
          Container(width: double.infinity, color: Theme.of(context).colorScheme.surfaceContainerHighest, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: const Text('Acquisition Items', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Column(children: [
            Expanded(child: AppUI.buildLineItemsList(
              context: context, lines: _lines, inventoryItems: _inventoryItems, priceLabel: 'Cost ($curr)',
              onAddLine: _addLine, onRemoveLine: _removeLine, onStateChanged: () => setState((){}),
            )),
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: Theme.of(context).dividerColor)),
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal:', style: TextStyle(fontWeight: FontWeight.w600)), Text(formatMoney(subtotal), style: const TextStyle(fontWeight: FontWeight.w600))]),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Tax / VAT Rate (%):'), SizedBox(width: 80, child: TextFormField(controller: _taxRateC, textAlign: TextAlign.right, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8), border: OutlineInputBorder()), onChanged: (_) => setState(() {})))]),
                const SizedBox(height: 4), Align(alignment: Alignment.centerRight, child: Text('Tax Amount: + ${formatMoney(taxAmount)}', style: const TextStyle(color: Colors.green, fontSize: 12))), const Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('GRAND TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(formatMoney(grandTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue))]),
              ]),
            ),
          ])),
          Padding(padding: const EdgeInsets.all(12), child: SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: const Icon(Icons.check), label: const Text('Save Purchase Order'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: _savePO))),
        ],
      ),
    );
  }
}

// =============================
// VIII. FINANCIAL SYSTEM
// =============================

// ========Payment Ledger Screen========
class PaymentLedgerScreen extends StatefulWidget {
  final int? initialOrderId, initialFallbackRentalId; final String? initialDisplayDocNumber; final int initialTabIndex;
  final String initialLedgerType;
  const PaymentLedgerScreen({super.key, this.initialOrderId, this.initialFallbackRentalId, this.initialDisplayDocNumber, this.initialTabIndex = 0, this.initialLedgerType = 'Customer Ledger (A/R)'});
  @override State<PaymentLedgerScreen> createState() => _PaymentLedgerScreenState();
}

class _PaymentLedgerScreenState extends State<PaymentLedgerScreen> {
  List<RentalGroup> _ledger = []; List<Map<String, dynamic>> _vendorLedger = [];
  String _filterMode = kLedgerFilterOptions.first; String _ledgerType = 'Customer Ledger (A/R)';
  final _searchCtrl = TextEditingController(), _scrollCtrl = ScrollController(); Timer? _debounce;
  bool _isLoadingMore = false, _hasMore = true; int _offset = 0; final int _limit = 20;
  double _totalDue = 0.0, _totalRefund = 0.0; int _totalCount = 0;
  late final int _initialTabIndex; int? _scopedOrderId, _scopedFallbackRentalId; String? _displayDocNumber;

  @override void initState() { super.initState(); _initialTabIndex = widget.initialTabIndex.clamp(0, 1); _scopedOrderId = widget.initialOrderId; _scopedFallbackRentalId = widget.initialFallbackRentalId; _displayDocNumber = widget.initialDisplayDocNumber; _ledgerType = widget.initialLedgerType; _scrollCtrl.addListener(_onScroll); _load(); }
  @override void dispose() { _searchCtrl.dispose(); _scrollCtrl.dispose(); _debounce?.cancel(); super.dispose(); }

  void _onScroll() { if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) _fetchPage(); }

  Future<void> _load() async {
    if (!mounted) return; setState(() { _offset = 0; _hasMore = true; _ledger = []; _vendorLedger = []; });
    try {
      if (_ledgerType == 'Customer Ledger (A/R)') {
        final totals = await DatabaseHelper.getLedgerTotals(filterMode: _filterMode, search: _searchCtrl.text, orderId: _scopedOrderId, fallbackRentalId: _scopedFallbackRentalId);
        if (!mounted) return; setState(() { _totalDue = totals['totalDue'] ?? 0.0; _totalRefund = totals['totalRefund'] ?? 0.0; _totalCount = (totals['count'] ?? 0).toInt(); });
        await _fetchPage();
      } else {
        final pos = await DatabaseHelper.getPurchaseOrders();
        List<Map<String, dynamic>> outstanding = [];
        double tDue = 0.0;
        double tRef = 0.0;
        final s = _searchCtrl.text.trim().toLowerCase();
        for (var po in pos) {
          final isCancelled = (po['isCancelled'] as int? ?? 0) == 1;
          // Conceptually, a cancelled PO has a billed total of $0.00
          final gt = isCancelled ? 0.0 : (po['grandTotal'] as num?)?.toDouble() ?? 0.0;
          final ap = (po['amountPaid'] as num?)?.toDouble() ?? 0.0;
          final bal = gt - ap;

          if (_displayDocNumber != null && po['poNumber'] != _displayDocNumber) continue;

          // If it's cancelled and fully refunded/unpaid (balance is 0), ignore it.
          // We only care if there is an orphaned advance we need to refund.
          if (isCancelled && bal.abs() <= 0.01) continue;

          // Apply Ledger Filters for A/P
          if (_filterMode == 'Amount Due' && bal <= 0.01) continue;
          if (_filterMode == 'Refund Due' && bal >= -0.01) continue;
          if (_filterMode == 'All' && bal.abs() <= 0.01) continue;

          if (s.isNotEmpty && !(po['supplierName']?.toString().toLowerCase().contains(s) ?? false) && !(po['poNumber']?.toString().toLowerCase().contains(s) ?? false)) continue;

          outstanding.add(po);
          if (bal > 0) tDue += bal;
          if (bal < 0) tRef += bal.abs();
        }
        if (!mounted) return;
        setState(() { _vendorLedger = outstanding; _totalDue = tDue; _totalRefund = tRef; _totalCount = outstanding.length; _hasMore = false; _isLoadingMore = false; });
      }
    } catch (e) { if (mounted) setState(() { _totalDue = 0.0; _totalRefund = 0.0; _totalCount = 0; _hasMore = false; _isLoadingMore = false; }); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
  }

  Future<void> _fetchPage() async {
    if (_isLoadingMore || !_hasMore) return; setState(() => _isLoadingMore = true);
    try {
      final newGroups = await DatabaseHelper.getPaginatedLedgerGroups(offset: _offset, limit: _limit, filterMode: _filterMode, search: _searchCtrl.text, orderId: _scopedOrderId, fallbackRentalId: _scopedFallbackRentalId);
      if (!mounted) return; setState(() { if (newGroups.length < _limit) _hasMore = false; _ledger.addAll(newGroups); _offset += newGroups.length; _isLoadingMore = false; });
    } catch (e) { if (mounted) setState(() { _isLoadingMore = false; _hasMore = false; }); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
  }

  void _onSearch(String _) { _debounce?.cancel(); _debounce = Timer(const Duration(milliseconds: 300), _load); }

  Future<void> _settleGroup(RentalGroup g) async => await TransactionDialogs.settle(context, g, _load);

  Future<void> _recordVendorPayment(Map<String, dynamic> po, {bool isRefund = false, double absBalance = 0.0}) async {
    final payC = TextEditingController(text: absBalance > 0 ? absBalance.toStringAsFixed(2) : ((po['grandTotal'] as num) - (po['amountPaid'] as num)).toStringAsFixed(2));
    String method = kPaymentMethods.first;
    DateTime dt = DateTime.now();
    final formKey = GlobalKey<FormState>();

    final res = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => AlertDialog(
            title: Text(isRefund ? 'Record Vendor Refund' : 'Record Vendor Payment'),
            content: StatefulBuilder(
                builder: (context, setSt) => Form(
                    key: formKey,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(isRefund ? 'Refund Due from Vendor: ${formatMoney(absBalance)}' : 'Amount Due to Vendor: ${formatMoney(absBalance)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextFormField(controller: payC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: isRefund ? 'Amount Refunded ($curr)' : 'Amount Paid ($curr)', border: const OutlineInputBorder()), validator: (v) { final val = double.tryParse(v??''); if (val == null || val <= 0) return 'Invalid'; if (val > absBalance + 0.01) return 'Cannot exceed balance'; return null; }),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(initialValue: method, decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()), items: kPaymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: (v) { if (v != null) method = v; }),
                      const SizedBox(height: 12),
                      ListTile(contentPadding: EdgeInsets.zero, title: Text('Date: ${DatabaseHelper.formatDateFromDt(dt)}'), trailing: const Icon(Icons.calendar_month), onTap: () async { final p = await AppUI.pickDateWithCurrentTime(ctx, dt, lastDate: DateTime.now()); if (p != null) setSt(() => dt = p); }),
                    ])
                )
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(ctx, {'amount': double.parse(payC.text), 'method': method, 'date': DatabaseHelper.isoDate(dt)}); }, child: Text(isRefund ? 'Save Refund' : 'Save')),
            ]
        )
    );
    payC.dispose();
    if (res == null || !mounted) return;

    // ACCOUNTING SYNC: A refund subtracts from the amount paid to the vendor.
    final finalAmount = isRefund ? -(res['amount'] as double) : (res['amount'] as double);

    await DatabaseHelper.recordPOPayment(po['id'] as int, finalAmount, res['method'], res['date'], po['poNumber'] as String? ?? '', po['supplierName'] as String? ?? '');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isRefund ? 'Vendor refund recorded.' : 'Vendor payment recorded.')));
    _load();
  }

  Widget _txtRow(String l, String r, {bool strike = false, bool bld = false, Color? c}) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(fontWeight: bld ? FontWeight.bold : null)), Text(r, style: TextStyle(fontWeight: bld ? FontWeight.bold : null, decoration: strike ? TextDecoration.lineThrough : null, color: c))]);

  @override Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DefaultTabController(length: 2, initialIndex: _initialTabIndex, child: Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: _scopedOrderId != null || _scopedFallbackRentalId != null || _displayDocNumber != null
              ? Text(_ledgerType, style: const TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.bold))
              : DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                  value: _ledgerType,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.black87),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                  dropdownColor: isDark ? Colors.grey[900] : Colors.amber.shade100,
                  selectedItemBuilder: (BuildContext context) {
                    return ['Customer Ledger (A/R)', 'Vendor Ledger (A/P)'].map((String value) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      );
                    }).toList();
                  },
                  items: const [
                    DropdownMenuItem(value: 'Customer Ledger (A/R)', child: Text('Customer Ledger (A/R)')),
                    DropdownMenuItem(value: 'Vendor Ledger (A/P)', child: Text('Vendor Ledger (A/P)')),
                  ],
                  onChanged: (v) { if (v != null) setState((){ _ledgerType = v; _searchCtrl.clear(); _load(); }); }
              )
          ),
        ),
        bottom: TabBar(tabs: const [Tab(text: 'OUTSTANDING'), Tab(text: 'HISTORY')], indicator: BoxDecoration(borderRadius: BorderRadius.circular(24), color: Colors.black12), indicatorSize: TabBarIndicatorSize.tab, dividerColor: Colors.transparent, labelColor: Colors.black, unselectedLabelColor: Colors.black54, labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ),
      body: TabBarView(children: [_buildLedgerTab(), PaymentHistoryScreen(key: ValueKey('hist_${_scopedOrderId??'n'}_${_scopedFallbackRentalId??'n'}_$_ledgerType'), isTab: true, initialOrderId: _scopedOrderId, initialFallbackRentalId: _scopedFallbackRentalId, initialDisplayDocNumber: _displayDocNumber, ledgerType: _ledgerType)]),
    ));
  }

  Widget _buildLedgerTab() => Column(children: [
    if (_scopedOrderId != null || _scopedFallbackRentalId != null || _displayDocNumber != null) Container(width: double.infinity, margin: const EdgeInsets.fromLTRB(12, 12, 12, 0), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber.withValues(alpha: 0.45))), child: Row(children: [const Icon(Icons.link, size: 16, color: Colors.amber), const SizedBox(width: 8), Expanded(child: Text(_displayDocNumber != null ? 'Showing Outstanding for $_displayDocNumber' : 'Showing Outstanding for Invoice #${_scopedOrderId ?? _scopedFallbackRentalId}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))])),
    Padding(padding: EdgeInsets.fromLTRB(12, (_scopedOrderId != null || _scopedFallbackRentalId != null || _displayDocNumber != null) ? 8 : 12, 12, 0), child: TextField(controller: _searchCtrl, enabled: _scopedOrderId == null && _scopedFallbackRentalId == null && _displayDocNumber == null, decoration: InputDecoration(hintText: _displayDocNumber != null || _scopedOrderId != null ? 'Filtered by ID' : (_ledgerType == 'Customer Ledger (A/R)' ? 'Search customer, phone, or invoice...' : 'Search supplier or PO...'), prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [if (_searchCtrl.text.isNotEmpty) IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _load(); }), PopupMenuButton<String>(icon: Stack(clipBehavior: Clip.none, children: [Icon(Icons.filter_list, color: _filterMode != kLedgerFilterOptions.first ? Colors.amber : null), if (_filterMode != kLedgerFilterOptions.first) Positioned(right: -2, top: -2, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)))]), initialValue: _filterMode, onSelected: (v) { setState(() { _filterMode = v; _load(); }); }, itemBuilder: (_) => kLedgerFilterOptions.map((opt) => PopupMenuItem(value: opt, child: Row(children: [Icon(_filterMode == opt ? Icons.radio_button_checked : Icons.radio_button_off, size: 18, color: Colors.amber), const SizedBox(width: 8), Text(opt)]))).toList())])), onChanged: _onSearch)),
    Card(margin: const EdgeInsets.fromLTRB(12, 12, 12, 8), child: Padding(padding: appSettingsNotifier.cardPadding, child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Total Due', style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color)), Text(formatMoney(_totalDue), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))])), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_ledgerType == 'Customer Ledger (A/R)' ? 'Total Refunds' : 'Total Overpaid', style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color)), Text(formatMoney(_totalRefund), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))])), Text('$_totalCount ${_ledgerType == 'Customer Ledger (A/R)' ? 'inv' : 'pos'}', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color))]))),
    Expanded(child: (_ledgerType == 'Customer Ledger (A/R)' ? _ledger.isEmpty : _vendorLedger.isEmpty) && !_isLoadingMore ? Center(child: Text(_scopedOrderId != null || _displayDocNumber != null ? 'Settled or not found.' : 'All ledgers are settled!', style: const TextStyle(fontSize: 16, color: Colors.green))) : RefreshIndicator(onRefresh: _load, child: ListView.builder(controller: _scrollCtrl, padding: const EdgeInsets.fromLTRB(12, 4, 12, 12), itemCount: (_ledgerType == 'Customer Ledger (A/R)' ? _ledger.length : _vendorLedger.length) + (_hasMore ? 1 : 0), itemBuilder: (_, i) {
      if (i == (_ledgerType == 'Customer Ledger (A/R)' ? _ledger.length : _vendorLedger.length)) return const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator()));

      if (_ledgerType == 'Vendor Ledger (A/P)') {
        final g = _vendorLedger[i];
        final isCancelled = (g['isCancelled'] as int? ?? 0) == 1;
        final gt = isCancelled ? 0.0 : (g['grandTotal'] as num).toDouble();
        final ap = (g['amountPaid'] as num).toDouble();
        final bal = gt - ap;
        final isRef = bal < 0;
        final col = isRef ? Colors.green : Colors.orange;

        return Card(margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(side: BorderSide(color: col), borderRadius: BorderRadius.circular(12)), child: Padding(padding: appSettingsNotifier.cardPadding, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(g['supplierName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)), Text(g['poNumber'] ?? '', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontWeight: FontWeight.w500))]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Date: ${DatabaseHelper.formatDateString(g['orderDate'] as String?)}', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 14)), if (isCancelled) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.red.withValues(alpha: 0.5))), child: const Text('CANCELLED PO', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)))]),
          const Divider(height: 20),
          _txtRow('Total Billed:', formatMoney(isCancelled ? (g['grandTotal'] as num).toDouble() : gt), strike: isCancelled), _txtRow('Paid:', '- ${formatMoney(ap)}'),
          const SizedBox(height: 4), _txtRow(isRef ? 'Refund Due:' : 'Amount Due:', formatMoney(bal, absolute: true), bld: true, c: col),
          const SizedBox(height: 16), SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: Icon(isRef ? Icons.undo : Icons.payment), label: Text(isRef ? 'Record Refund' : 'Record Payment'), style: ElevatedButton.styleFrom(backgroundColor: col.withValues(alpha: 0.2), foregroundColor: isRef ? Colors.greenAccent : Colors.orangeAccent), onPressed: () => _recordVendorPayment(g, isRefund: isRef, absBalance: bal.abs()))),
        ])));
      }

      final g = _ledger[i], isRef = g.balance < 0, col = isRef ? Colors.green : Colors.orange;
      return Card(margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(side: BorderSide(color: col), borderRadius: BorderRadius.circular(12)), child: Padding(padding: appSettingsNotifier.cardPadding, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(g.contractor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)), if (g.orderId != null) Text(g.invoiceNumber.isNotEmpty ? g.invoiceNumber : (g.proformaNumber.isNotEmpty ? g.proformaNumber : 'ORD-${g.orderId}'), style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontWeight: FontWeight.w500))]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Out: ${DatabaseHelper.formatDateString(g.checkoutDate)}', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 14)), if (g.isCancelled) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.red.withValues(alpha: 0.5))), child: const Text('CANCELLED INVOICE', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)))]),
        const Divider(height: 20),
        _txtRow('Total Billed:', formatMoney(g.calculateTotalCost()), strike: g.isCancelled), _txtRow('Paid:', '- ${formatMoney(g.advance)}'),
        if (g.discount > 0) _txtRow('Discount:', '- ${formatMoney(g.discount)}'), const SizedBox(height: 4), _txtRow(isRef ? 'Refund Due:' : 'Amount Due:', formatMoney(g.balance, absolute: true), bld: true, c: col),
        const SizedBox(height: 16), SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: Icon(isRef ? Icons.undo : Icons.payment), label: Text(isRef ? 'Record Refund/Discount' : 'Record Payment/Discount'), style: ElevatedButton.styleFrom(backgroundColor: col.withValues(alpha: 0.2), foregroundColor: isRef ? Colors.greenAccent : Colors.orangeAccent), onPressed: () => _settleGroup(g))),
      ])));
    }))),
  ]);
}

// ========Payment History Screen========

class PaymentHistoryScreen extends StatefulWidget {
  final int? initialOrderId, initialFallbackRentalId; final String? initialDisplayDocNumber; final bool isTab;
  final String ledgerType;
  const PaymentHistoryScreen({super.key, this.initialOrderId, this.initialFallbackRentalId, this.initialDisplayDocNumber, this.isTab = false, this.ledgerType = 'Customer Ledger (A/R)'});
  @override State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final _searchCtrl = TextEditingController(); Timer? _debounce; String _filterMode = 'All';
  bool _loading = true; List<Map<String, dynamic>> _rows = []; double _totalPayments = 0.0, _totalRefunds = 0.0;
  late final int? _scopedOrderId, _scopedFallbackRentalId; late final String? _displayDocNumber;

  @override void initState() { super.initState(); _scopedOrderId = widget.initialOrderId; _scopedFallbackRentalId = widget.initialFallbackRentalId; _displayDocNumber = widget.initialDisplayDocNumber; _load(); }
  @override void dispose() { _debounce?.cancel(); _searchCtrl.dispose(); super.dispose(); }

  void _onSearch(String _) { _debounce?.cancel(); _debounce = Timer(const Duration(milliseconds: 300), _load); }

  Future<void> _load() async {
    if (widget.ledgerType == 'Customer Ledger (A/R)') {
      final rows = await DatabaseHelper.getPaymentHistory(search: _searchCtrl.text, type: _filterMode, orderId: _scopedOrderId, fallbackRentalId: _scopedFallbackRentalId);
      double inAmt = 0.0, outAmt = 0.0;
      for (final r in rows) { final a = (r['amount'] as num?)?.toDouble() ?? 0.0; if (a >= 0) { inAmt += a; } else { outAmt += a.abs(); } }
      if (!mounted) return; setState(() { _rows = rows; _totalPayments = inAmt; _totalRefunds = outAmt; _loading = false; });
    } else {
      // Fetch directly from the dedicated Vendor Payment Logs table
      final vendorLogs = await DatabaseHelper.getVendorPaymentHistory(poNumber: _displayDocNumber);
      List<Map<String, dynamic>> apLogs = [];
      double outAmt = 0.0;
      double inAmt = 0.0;
      final s = _searchCtrl.text.trim().toLowerCase();

      for (var v in vendorLogs) {
        final amt = (v['amount'] as num).toDouble();
        if (_filterMode == 'Payment' && amt < 0) continue;
        if (_filterMode == 'Refund' && amt > 0) continue;

        final supplierName = v['supplierName'] as String? ?? 'Unknown';
        final poNum = v['poNumber'] as String? ?? '';
        final method = v['method'] as String? ?? '';

        if (s.isNotEmpty && !supplierName.toLowerCase().contains(s) && !poNum.toLowerCase().contains(s) && !method.toLowerCase().contains(s)) continue;

        apLogs.add({
          'id': v['id'],
          'amount': amt,
          'customerName': supplierName,
          'method': method,
          'paidAt': v['paidAt'],
          'baseDate': v['paidAt'],
          'proformaNumber': poNum,
          'isCancelled': v['isCancelled'] as int? ?? 0,
          'firstLogId': v['firstLogId']
        });

        // outAmt = Outbound to Vendor. inAmt = Inbound Refunds from Vendor.
        if (amt >= 0) { outAmt += amt; } else { inAmt += amt.abs(); }
      }
      if (!mounted) return; setState(() { _rows = apLogs; _totalRefunds = outAmt; _totalPayments = inAmt; _loading = false; });
    }
  }

  String _fmtTm(String p, String f) { final raw = p.trim().isNotEmpty ? p.trim() : f.trim(); return raw.isEmpty ? '' : (DateTime.tryParse(raw) != null ? formatTimeByPreference(DateTime.parse(raw)) : ''); }
  String _fmtDt(String p, String f) { final raw = p.trim().isNotEmpty ? p.trim() : f.trim(); return raw.isEmpty ? '-' : (DateTime.tryParse(raw) != null ? DatabaseHelper.formatDateFromDt(DateTime.parse(raw)) : DatabaseHelper.formatDateString(raw)); }
  Widget _tag(String t, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5), decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(4), border: Border.all(color: c.withValues(alpha: 0.5), width: 0.8)), child: Text(t, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600)));

  @override Widget build(BuildContext context) {
    final isVendor = widget.ledgerType == 'Vendor Ledger (A/P)';
    return Scaffold(
      appBar: widget.isTab ? null : AppBar(title: const Text('Payment History')),
      body: Column(children: [
        if (_scopedOrderId != null || _scopedFallbackRentalId != null || _displayDocNumber != null) Container(width: double.infinity, margin: const EdgeInsets.fromLTRB(12, 12, 12, 0), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber.withValues(alpha: 0.45))), child: Row(children: [const Icon(Icons.link, size: 16, color: Colors.amber), const SizedBox(width: 8), Expanded(child: Text(_displayDocNumber != null ? 'Showing Payments for $_displayDocNumber' : 'Showing payments for Invoice #${_scopedOrderId ?? _scopedFallbackRentalId}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))])),
        Padding(padding: EdgeInsets.fromLTRB(12, (_scopedOrderId != null || _scopedFallbackRentalId != null || _displayDocNumber != null) ? 8 : 12, 12, 0), child: TextField(controller: _searchCtrl, decoration: InputDecoration(hintText: isVendor ? 'Search vendor, method, or PO...' : 'Search customer, method, or invoice...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [if (_searchCtrl.text.isNotEmpty) IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _load(); }), PopupMenuButton<String>(icon: Stack(clipBehavior: Clip.none, children: [Icon(Icons.filter_list, color: _filterMode != 'All' ? Colors.amber : null), if (_filterMode != 'All') Positioned(right: -2, top: -2, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)))]), initialValue: _filterMode, onSelected: (v) { setState(() { _filterMode = v; _loading = true; }); _load(); }, itemBuilder: (_) => ['All', 'Payment', 'Refund'].map((m) => PopupMenuItem(value: m, child: Row(children: [Icon(_filterMode == m ? Icons.radio_button_checked : Icons.radio_button_off, size: 18, color: Colors.amber), const SizedBox(width: 8), Text(m)]))).toList())])), onChanged: _onSearch)),
        if (_loading) const Expanded(child: Center(child: CircularProgressIndicator())) else if (_rows.isEmpty) const Expanded(child: Center(child: Text('No payment history found.'))) else Expanded(child: RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(12), children: [
          Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: appSettingsNotifier.cardPadding, child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(isVendor ? 'Payments Sent' : 'Total Payments', style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color)), Text(formatMoney(isVendor ? _totalRefunds : _totalPayments), style: TextStyle(fontWeight: FontWeight.bold, color: isVendor ? Colors.orange : Colors.green))])), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(isVendor ? 'Refunds Rcvd' : 'Total Refunds', style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color)), Text(formatMoney(isVendor ? _totalPayments : _totalRefunds), style: TextStyle(fontWeight: FontWeight.bold, color: isVendor ? Colors.green : Colors.orange))])), Text('${_rows.length} txn', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color))]))),
          ..._rows.map((r) {
            final amt = (r['amount'] as num?)?.toDouble() ?? 0.0, isRef = amt < 0, cust = (r['customerName'] as String? ?? '').trim(), mth = (r['method'] as String? ?? '').trim(), oId = r['orderId'] as int?, fId = r['fallbackRentalId'] as int?, inv = r['invoiceNumber'] as String? ?? '', prf = r['proformaNumber'] as String? ?? '';
            final ref = isVendor ? prf : (oId != null ? (inv.isNotEmpty ? inv : (prf.isNotEmpty ? prf : 'Invoice #$oId')) : (fId != null ? 'Record #$fId' : 'Record'));
            final tm = _fmtTm(r['paidAt'] ?? '', r['baseDate'] ?? ''), dt = _fmtDt(r['paidAt'] ?? '', r['baseDate'] ?? ''), isCan = (r['isCancelled'] as int? ?? 0) == 1, col = isVendor ? (isRef ? Colors.green : Colors.orange) : (isRef ? Colors.orange : Colors.green);
            final pDate = (r['paidAt'] as String? ?? '').split('T')[0];
            final cDate = (r['baseDate'] as String? ?? '').split('T')[0];
            final isAdv = !isRef && (r['id'] == r['firstLogId']) && (pDate == cDate);

            return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: appSettingsNotifier.cardPadding, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(radius: 13.5, backgroundColor: col.withValues(alpha: 0.15), child: Icon(isVendor ? (isRef ? Icons.undo : Icons.payment) : (isRef ? Icons.undo : Icons.payments), color: col, size: 14.5)), const SizedBox(width: 6),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(cust.isEmpty ? 'Unknown' : cust, style: const TextStyle(fontWeight: FontWeight.w700)), Text(appSettingsNotifier.showPaymentHistoryTime && tm.isNotEmpty ? '$ref  |  $dt  |  $tm' : '$ref  |  $dt', maxLines: 1, overflow: TextOverflow.visible, style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color))])),
                const SizedBox(width: 8), Text('${isVendor ? (isRef ? '+' : '-') : (isRef ? '-' : '+')}${formatMoney(amt, absolute: true)}', style: TextStyle(fontWeight: FontWeight.bold, color: col)),
              ]),
              const SizedBox(height: 8), Wrap(spacing: 6, runSpacing: 6, children: [_tag(isVendor ? (isRef ? 'Vendor Refund' : (isAdv ? 'Adv/Security' : 'Vendor Payment')) : (isRef ? 'Refund' : (isAdv ? 'Adv/Security' : 'Payment')), col), _tag(mth.isEmpty ? 'Method: N/A' : 'Method: $mth', Colors.blueGrey), if (isCan) _tag(isVendor ? 'Cancelled PO' : 'Cancelled Invoice', Colors.red)]),
            ])));
          }),
        ]))),
      ]),
    );
  }
}

// =============================
// IX. ACCOUNTING & REPORTS
// =============================

// ========Financial Reports Screen========

class FinancialReportsScreen extends StatefulWidget {
  const FinancialReportsScreen({super.key});
  @override State<FinancialReportsScreen> createState() => _FinancialReportsScreenState();
}

class _FinancialReportsScreenState extends State<FinancialReportsScreen> {
  Map<String, dynamic> _plData = {}, _taxData = {}; List<Map<String, dynamic>> _arAging = [];
  bool _loading = true; String _period = 'This Month';

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return; setState(() => _loading = true);
    try {
      final pl = await DatabaseHelper.getProfitAndLoss(_period);
      final ar = await DatabaseHelper.getARAging();
      final tax = await DatabaseHelper.getTaxLiability(_period);
      if (!mounted) return; setState(() { _plData = pl; _arAging = ar; _taxData = tax; _loading = false; });
    } catch (e) { if (mounted) { setState(() => _loading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading reports: $e'))); } }
  }

  Widget _finRow(String l, double v, {bool bld = false, Color? c, double fs = 14}) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(fontWeight: bld ? FontWeight.bold : null, fontSize: fs)), Text(formatMoney(v), style: TextStyle(fontWeight: bld ? FontWeight.bold : null, color: c ?? (v < 0 ? Colors.red : null), fontSize: fs))]));
  Widget _hdr(String t) => Padding(padding: const EdgeInsets.only(bottom: 8, top: 8), child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)));

  Widget _buildPLTab() {
    final rev = (_plData['revenue'] as num?)?.toDouble() ?? 0.0;
    final exp = (_plData['expenses'] as num?)?.toDouble() ?? 0.0;
    final disc = (_plData['discounts'] as num?)?.toDouble() ?? 0.0;
    final bd = (_plData['badDebt'] as num?)?.toDouble() ?? 0.0;
    final net = rev - exp - disc - bd;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: appSettingsNotifier.cardPadding, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _hdr('Income Statement'), const Divider(),
        _finRow('Gross Rental Revenue', rev), _finRow('Damages & Penalties Collected', (_plData['penalties'] as num?)?.toDouble() ?? 0.0),
        const Divider(height: 24), _hdr('Deductions & Expenses'),
        _finRow('Discounts Given', -((_plData['discounts'] as num?)?.toDouble() ?? 0.0)), _finRow('Bad Debt Written Off', -((_plData['badDebt'] as num?)?.toDouble() ?? 0.0)), _finRow('Operational Expenses', -exp),
        const Divider(height: 24, thickness: 2), _finRow('NET PROFIT / LOSS', net, bld: true, c: net >= 0 ? Colors.green : Colors.red, fs: 16),
      ]))),
    ]);
  }

  Widget _buildARTab() {
    double t0_30 = 0, t31_60 = 0, t61_90 = 0, t90p = 0;
    for (var r in _arAging) { t0_30 += r['0_30']; t31_60 += r['31_60']; t61_90 += r['61_90']; t90p += r['90_plus']; }
    final total = t0_30 + t31_60 + t61_90 + t90p;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: appSettingsNotifier.cardPadding, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _hdr('A/R Aging Summary'), const Divider(),
        _finRow('0 - 30 Days', t0_30), _finRow('31 - 60 Days', t31_60), _finRow('61 - 90 Days', t61_90, c: Colors.orange), _finRow('90+ Days (High Risk)', t90p, c: Colors.redAccent),
        const Divider(height: 24, thickness: 2), _finRow('TOTAL OUTSTANDING', total, bld: true, c: Colors.orange, fs: 16),
      ]))),
      const SizedBox(height: 16), const Text('Customer Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 8),
      ..._arAging.map((c) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(title: Text(c['name'], style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Oldest: ${c['oldest_inv']} days'), trailing: Text(formatMoney(c['total']), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 15)))))
    ]);
  }

  Widget _buildTaxTab() {
    final tax = (_taxData['collected'] as num?)?.toDouble() ?? 0.0, base = (_taxData['base'] as num?)?.toDouble() ?? 0.0;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: appSettingsNotifier.cardPadding, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _hdr('Tax Liability Report'), const Divider(),
        _finRow('Taxable Base', base), _finRow('Estimated Tax Collected', tax, c: Colors.blue),
        const Divider(height: 24, thickness: 2), _finRow('TOTAL LIABILITY', tax, bld: true, fs: 16),
      ]))),
    ]);
  }

  @override Widget build(BuildContext context) => DefaultTabController(length: 3, child: Scaffold(
    appBar: AppBar(
      title: const Text('Financial Reports'),
      bottom: TabBar(isScrollable: true, tabs: const [Tab(text: 'PROFIT & LOSS'), Tab(text: 'A/R AGING'), Tab(text: 'TAX LIABILITY')], indicator: BoxDecoration(borderRadius: BorderRadius.circular(24), color: Colors.black12), indicatorSize: TabBarIndicatorSize.tab, dividerColor: Colors.transparent, labelColor: Colors.black, unselectedLabelColor: Colors.black54, labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      actions: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _period, icon: const Icon(Icons.calendar_month, color: Colors.black87), selectedItemBuilder: (BuildContext context) => ['This Month', 'Last Month', 'This Year', 'All Time'].map((String val) => Align(alignment: Alignment.centerLeft, child: Text(val, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)))).toList(), items: ['This Month', 'Last Month', 'This Year', 'All Time'].map((String val) => DropdownMenuItem(value: val, child: Text(val))).toList(), onChanged: (v) { if (v != null) { setState(() => _period = v); _load(); } })))      ],
    ),
    body: _loading ? const Center(child: CircularProgressIndicator()) : TabBarView(children: [_buildPLTab(), _buildARTab(), _buildTaxTab()]),
  ));
}

// ========Profit & Loss (Income Statement) Screen========
class ProfitAndLossTab extends StatefulWidget {
  const ProfitAndLossTab({super.key});
  @override
  State<ProfitAndLossTab> createState() => _ProfitAndLossTabState();
}

class _ProfitAndLossTabState extends State<ProfitAndLossTab> {
  String _depreciationMethod = 'SLM';
  Map<String, dynamic> _data = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await DatabaseHelper.getProfitAndLossStatement(method: _depreciationMethod);
    if (!mounted) return;
    setState(() {
      _data = results;
      _loading = false;
    });
  }

  Widget _buildLineItem(String title, double amount, {bool isNegative = false, bool isBold = false, bool isTotal = false}) {
    // Dynamically adjust colors based on Light/Dark theme mode
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final posColor = isDark ? Colors.greenAccent : Colors.green[800];
    final negColor = isDark ? Colors.redAccent : Colors.red[800];

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isTotal ? 12.0 : 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded( // Prevents overflow if the label text is too long
            child: Text(title, style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            )),
          ),
          const SizedBox(width: 8),
          Text(
              isNegative && amount > 0 ? '- ${formatMoney(amount)}' : formatMoney(amount),
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: isTotal ? 16 : 14,
                color: isNegative && amount > 0 ? negColor : (isTotal ? (amount >= 0 ? posColor : negColor) : defaultTextColor),
              )
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(child: Text('Master Income Statement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              const SizedBox(width: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'SLM', label: Text('SLM')),
                  ButtonSegment(value: 'WDV', label: Text('WDV')),
                ],
                selected: {_depreciationMethod},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() => _depreciationMethod = newSelection.first);
                  _load();
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('All-Time Accrual Basis P&L', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
          const SizedBox(height: 24),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('REVENUE', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, letterSpacing: 1.2)),
                  const Divider(),
                  _buildLineItem('Gross Rental Revenue', _data['grossRevenue']),
                  if ((_data['discount'] ?? 0.0) > 0)
                    _buildLineItem('Less: Discounts Provided', _data['discount'], isNegative: true),

                  const SizedBox(height: 16),
                  Text('OPERATING EXPENSES', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, letterSpacing: 1.2)),
                  const Divider(),
                  _buildLineItem('General OPEX & Repairs', _data['opex'], isNegative: true),

                  const Divider(thickness: 2),
                  _buildLineItem('EBITDA', _data['ebitda'], isBold: true),
                  const Divider(thickness: 2),

                  const SizedBox(height: 16),
                  Text('DEDUCTIONS & WRITE-OFFS', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, letterSpacing: 1.2)),
                  const Divider(),
                  _buildLineItem('Bad Debt Write-Offs', _data['badDebt'], isNegative: true),
                  _buildLineItem('Asset Depreciation ($_depreciationMethod)', _data['depreciation'], isNegative: true),

                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: _data['netProfit'] >= 0 ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _data['netProfit'] >= 0 ? Colors.green : Colors.red, width: 1.5)
                    ),
                    child: _buildLineItem('NET PROFIT', _data['netProfit'], isBold: true, isTotal: true),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ========Inventory Valuation & ROI Screen========
class InventoryValuationScreen extends StatefulWidget {
  const InventoryValuationScreen({super.key});
  @override
  State<InventoryValuationScreen> createState() => _InventoryValuationScreenState();
}

class _InventoryValuationScreenState extends State<InventoryValuationScreen> {
  String _depreciationMethod = 'SLM'; // Default to Straight Line
  List<Map<String, dynamic>> _data = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await DatabaseHelper.getInventoryValuationReport(method: _depreciationMethod);
    if (!mounted) return;
    setState(() {
      _data = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    double totalInitialCost = 0;
    double totalBookValue = 0;
    for (var item in _data) {
      totalInitialCost += item['initialCost'];
      totalBookValue += item['bookValue'];
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Depreciation Method:', style: TextStyle(fontWeight: FontWeight.bold)),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'SLM', label: Text('SLM'), tooltip: 'Straight Line Method'),
                  ButtonSegment(value: 'WDV', label: Text('WDV'), tooltip: 'Written Down Value'),
                ],
                selected: {_depreciationMethod},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() => _depreciationMethod = newSelection.first);
                  _load();
                },
              ),
            ],
          ),
        ),

        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.blue.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Net Asset Value', style: TextStyle(fontSize: 12, color: Colors.blue[800])),
                      Text(formatMoney(totalBookValue, decimals: 0), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Initial Investment', style: TextStyle(fontSize: 12, color: Colors.blue[800])),
                      Text(formatMoney(totalInitialCost, decimals: 0), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: _data.isEmpty
              ? const Center(child: Text('No capital equipment with purchase prices found.'))
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _data.length,
            itemBuilder: (ctx, i) {
              final item = _data[i];
              final roi = item['roiPercentage'] as double;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: appSettingsNotifier.cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: roi >= 100 ? Colors.green.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                                'ROI: ${roi.toStringAsFixed(1)}%',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: roi >= 100 ? Colors.green : Colors.amber[900],
                                    fontSize: 11
                                )
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _subStat('Current Value', formatMoney(item['bookValue'])),
                          _subStat('Depreciation', formatMoney(item['accumulatedDepreciation'])),
                          _subStat('Revenue', formatMoney(item['generatedRevenue'])),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (roi / 100).clamp(0, 1.0),
                          backgroundColor: Colors.grey[300],
                          color: roi >= 100 ? Colors.green : Colors.blue,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        roi >= 100 ? 'Asset has paid for itself!' : '${(100-roi).toStringAsFixed(0)}% more needed to break even.',
                        style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _subStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}

// ========Expense & Revenue Ledger Screen========
class ExpenseRevenueLedgerScreen extends StatefulWidget {
  const ExpenseRevenueLedgerScreen({super.key});
  @override
  State<ExpenseRevenueLedgerScreen> createState() => _ExpenseRevenueLedgerScreenState();
}

class _ExpenseRevenueLedgerScreenState extends State<ExpenseRevenueLedgerScreen> {
  List<Map<String, dynamic>> _entries = [];
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  double _totalExpense = 0.0, _totalRevenue = 0.0;

  String _sortMode = 'Date (Newest)';
  String _filterMode = 'All';

  final List<String> _sortOptions = ['Date (Newest)', 'Date (Oldest)', 'Highest Amount'];

  final List<String> _expenseCategories = [
    'Fuel & Transport', 'Repairs & Maintenance', 'Warehouse Rent',
    'Utilities', 'Payroll', 'Advertising', 'Office Supplies', 'Other Expense'
  ];
  final List<String> _revenueCategories = [
    'Retired Asset Sale', 'Consulting / Services', 'Sub-leasing',
    'Scrap Material', 'Sponsorship', 'Other Revenue'
  ];

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _searchCtrl.dispose(); _debounce?.cancel(); super.dispose(); }

  Future<void> _load() async {
    final rawData = await DatabaseHelper.getExpenses(search: _searchCtrl.text);
    List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(rawData);

    if (_filterMode == 'Expenses') {
      data = data.where((e) => (e['type'] as String? ?? 'Expense') == 'Expense').toList();
    } else if (_filterMode == 'Revenues') {
      data = data.where((e) => (e['type'] as String? ?? 'Expense') == 'Revenue').toList();
    }

    if (_sortMode == 'Date (Newest)') {
      data.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    } else if (_sortMode == 'Date (Oldest)') {
      data.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    } else if (_sortMode == 'Highest Amount') {
      data.sort((a, b) => (b['amount'] as num).compareTo(a['amount'] as num));
    }

    double tRev = 0.0, tExp = 0.0;
    for (var row in data) {
      final isRev = (row['type'] as String? ?? 'Expense') == 'Revenue';
      final amt = (row['amount'] as num).toDouble();
      if (isRev) {
        tRev += amt;
      } else {
        tExp += amt;
      }
    }

    if (!mounted) return;
    setState(() { _entries = data; _totalRevenue = tRev; _totalExpense = tExp; });
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _showEntryDialog() async {
    final amtC = TextEditingController(), venC = TextEditingController(), noteC = TextEditingController();
    String entryType = 'Expense';
    String cat = _expenseCategories.first, meth = kPaymentMethods.first;
    DateTime dt = DateTime.now();

    await AppUI.showFormDialog(context,
      title: 'Log Ledger Entry',
      onSave: () async {
        await DatabaseHelper.insertExpenseRevenue(DatabaseHelper.isoDate(dt), entryType, cat, double.parse(amtC.text), meth, venC.text.trim(), noteC.text.trim());
        _load();
      },
      children: [
        StatefulBuilder(builder: (ctx, setSt) => Column(children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Expense', label: Text('Expense'), icon: Icon(Icons.outbox)),
              ButtonSegment(value: 'Revenue', label: Text('Revenue'), icon: Icon(Icons.move_to_inbox)),
            ],
            selected: {entryType},
            onSelectionChanged: (Set<String> newSelection) {
              setSt(() {
                entryType = newSelection.first;
                cat = entryType == 'Expense' ? _expenseCategories.first : _revenueCategories.first;
              });
            },
          ),
          const SizedBox(height: 16),
          AppUI.buildTextField(controller: amtC, label: 'Amount ($curr) *', type: const TextInputType.numberWithOptions(decimal: true), validator: (v) => double.tryParse(v ?? '') == null ? 'Required' : null),
          DropdownButtonFormField<String>(initialValue: cat, decoration: AppUI.inputDecoration('Category'), items: (entryType == 'Expense' ? _expenseCategories : _revenueCategories).map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setSt(() => cat = v ?? cat)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(initialValue: meth, decoration: AppUI.inputDecoration('Transaction Method'), items: kPaymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: (v) => setSt(() => meth = v ?? meth)),
          const SizedBox(height: 12),
          ListTile(contentPadding: EdgeInsets.zero, title: Text('Date: ${DatabaseHelper.formatDateFromDt(dt)}'), trailing: const Icon(Icons.calendar_month), onTap: () async { final p = await AppUI.pickDateWithCurrentTime(ctx, dt, lastDate: DateTime.now()); if (p != null) setSt(() => dt = p); }),
        ])),
        AppUI.buildTextField(controller: venC, label: 'Vendor / Source'),
        AppUI.buildTextField(controller: noteC, label: 'Notes', maxLines: 2),
      ],
    );
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Permanently delete this record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      await DatabaseHelper.deleteExpense(id);
      _load();
    }
  }

  Widget _tag(String t, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5), decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(4), border: Border.all(color: c.withValues(alpha: 0.5), width: 0.8)), child: Text(t, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Expense & Revenue')),
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search category, vendor or notes...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchCtrl.text.isNotEmpty)
                    IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _load(); }),
                  PopupMenuButton<String>(
                    icon: Stack(clipBehavior: Clip.none, children: [
                      Icon(Icons.filter_alt, color: _filterMode != 'All' ? Colors.amber : null),
                      if (_filterMode != 'All') Positioned(
                        right: -2, top: -2,
                        child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)),
                      ),
                    ]),
                    tooltip: 'Filter Type',
                    initialValue: _filterMode,
                    onSelected: (v) { setState(() { _filterMode = v; _load(); }); },
                    itemBuilder: (_) => ['All', 'Expenses', 'Revenues'].map((opt) => PopupMenuItem(
                      value: opt,
                      child: Row(children: [
                        Icon(_filterMode == opt ? Icons.radio_button_checked : Icons.radio_button_off, size: 18, color: Colors.amber),
                        const SizedBox(width: 8),
                        Text(opt),
                      ]),
                    )).toList(),
                  ),
                  PopupMenuButton<String>(
                    icon: Stack(clipBehavior: Clip.none, children: [
                      Icon(Icons.sort, color: _sortMode != 'Date (Newest)' ? Colors.amber : null),
                      if (_sortMode != 'Date (Newest)') Positioned(
                        right: -2, top: -2,
                        child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)),
                      ),
                    ]),
                    tooltip: 'Sort by',
                    initialValue: _sortMode,
                    onSelected: (v) { setState(() { _sortMode = v; _load(); }); },
                    itemBuilder: (_) => _sortOptions.map((opt) => PopupMenuItem(
                      value: opt,
                      child: Row(children: [
                        Icon(_sortMode == opt ? Icons.radio_button_checked : Icons.radio_button_off, size: 18, color: Colors.amber),
                        const SizedBox(width: 8),
                        Text(opt),
                      ]),
                    )).toList(),
                  ),
                ]
            ),
          ),
          onChanged: _onSearch,
        ),
      ),
      Card(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Padding(
          padding: appSettingsNotifier.cardPadding,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Revenues', style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color)),
                    const SizedBox(height: 2),
                    Text(formatMoney(_totalRevenue), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Expenses', style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color)),
                    const SizedBox(height: 2),
                    Text(formatMoney(_totalExpense), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  ],
                ),
              ),
              Text('${_entries.length} txn', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
            ],
          ),
        ),
      ),
      Expanded(
        child: _entries.isEmpty
            ? const Center(child: Text('No records found.'))
            : ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _entries.length,
          itemBuilder: (_, i) {
            final e = _entries[i];
            final amount = (e['amount'] as num).toDouble();
            final vendor = (e['vendor'] as String? ?? '').trim();
            final isRev = (e['type'] as String? ?? 'Expense') == 'Revenue';
            final col = isRev ? Colors.green : Colors.redAccent;
            final mth = (e['paymentMethod'] as String? ?? '').trim();

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: appSettingsNotifier.cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(radius: 13.5, backgroundColor: col.withValues(alpha: 0.15), child: Icon(isRev ? Icons.move_to_inbox : Icons.outbox, color: col, size: 14.5)),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e['category'], style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(
                                      'Date: ${DatabaseHelper.formatDateString(e['date'])}${vendor.isNotEmpty ? '  |  $vendor' : ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.visible,
                                      style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color)
                                  ),
                                ]
                            )
                        ),
                        const SizedBox(width: 8),
                        Text('${isRev ? '+' : '-'} ${formatMoney(amount)}', style: TextStyle(fontWeight: FontWeight.bold, color: col)),
                        SizedBox(
                          width: 28,
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20),
                            padding: EdgeInsets.zero,
                            tooltip: 'Options',
                            onSelected: (val) { if (val == 'delete') { _delete(e['id'] as int); } },
                            itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))]))],
                          ),
                        ),
                      ],
                    ),
                    if ((e['notes'] as String).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Note: ${e['notes']}', style: TextStyle(fontStyle: FontStyle.italic, color: Theme.of(context).textTheme.bodySmall?.color)),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _tag(isRev ? 'Revenue' : 'Expense', col),
                        _tag(mth.isEmpty ? 'Method: N/A' : 'Method: $mth', Colors.blueGrey),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ]),
    floatingActionButton: FloatingActionButton(
      onPressed: _showEntryDialog,
      tooltip: 'Log Entry',
      backgroundColor: Colors.blueAccent,
      foregroundColor: Colors.white,
      child: const Icon(Icons.add),
    ),
  );
}



class _StockChip extends StatelessWidget {
  final String label; final Color color;
  const _StockChip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
    child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
  );
}

// ========Losses & Bad Debt Screen========
class LossesAndBadDebtScreen extends StatefulWidget {
  const LossesAndBadDebtScreen({super.key});
  @override
  State<LossesAndBadDebtScreen> createState() => _LossesAndBadDebtScreenState();
}

class _LossesAndBadDebtScreenState extends State<LossesAndBadDebtScreen> {
  List<RentalGroup> _allBadDebts = [];
  List<RentalGroup> _badDebts = [];
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _sortMode = kSortOptions.first;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _searchCtrl.dispose(); _debounce?.cancel(); super.dispose(); }

  Future<void> _load() async {
    final all = groupRentalsByInvoice(await DatabaseHelper.getAllRentals());
    _allBadDebts = all.where((g) => g.badDebt > 0).toList();
    _applyFilter();
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _applyFilter);
  }

  void _applyFilter() {
    List<RentalGroup> filtered = List.from(_allBadDebts);
    final q = _searchCtrl.text.trim().toLowerCase();

    if (q.isNotEmpty) {
      filtered = filtered.where((g) {
        return g.contractor.toLowerCase().contains(q) ||
            (g.orderId?.toString() ?? '').contains(q);
      }).toList();
    }
    _applySort(filtered, _sortMode);

    if (!mounted) return;
    setState(() { _badDebts = filtered; });
  }

  Future<void> _recoverFunds(RentalGroup group) async {
    final payC = TextEditingController(text: group.badDebt.toStringAsFixed(2));
    String method = kPaymentMethods.first;
    DateTime recoveryDate = DateTime.now();
    final formKey = GlobalKey<FormState>();
    final messenger = ScaffoldMessenger.of(context);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recover Bad Debt'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Customer is making a payment on a previously written-off invoice.'),
            const SizedBox(height: 16),
            Text('Written off amount: ${formatMoney(group.badDebt)}'),
            const SizedBox(height: 16),
            TextFormField(
              controller: payC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Amount Recovered ($curr)', border: const OutlineInputBorder()),
              validator: (v) {
                final val = double.tryParse(v ?? '');
                if (val == null || val <= 0) return 'Invalid amount';
                if (val > group.badDebt + 0.01) return 'Cannot exceed written off amount';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: method,
              decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
              items: kPaymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) { if (v != null) { method = v; } },
            ),
            const SizedBox(height: 12),
            StatefulBuilder(builder: (ctx, setSt) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Date: ${DatabaseHelper.formatDateFromDt(recoveryDate)}'),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final p = await AppUI.pickDateWithCurrentTime(ctx, recoveryDate, lastDate: DateTime.now());
                if (p != null) setSt(() => recoveryDate = p);
              },
            )),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, {'amount': double.parse(payC.text), 'method': method, 'date': DatabaseHelper.isoDate(recoveryDate)});
              }
            },
            child: const Text('Record Recovery'),
          ),
        ],
      ),
    );

    payC.dispose();
    if (result == null || !mounted) return;

    final amount = result['amount'] as double;
    final isFullyRecovered = amount >= group.badDebt - 0.01;

    await DatabaseHelper.recoverBadDebt(
        group.items.first['id'] as int,
        amount,
        result['method'] as String,
        group.items.map((i) => i['id'] as int).toList(),
        isFullyRecovered,
        paidAt: result['date'] as String
    );

    if (!mounted) return;
    _load();
    messenger.showSnackBar(const SnackBar(content: Text('Bad debt recovery recorded successfully.')));
  }

  @override
  Widget build(BuildContext context) {
    final double currentTotalLost = _badDebts.fold(0.0, (sum, g) => sum + g.badDebt);

    return Scaffold(
      appBar: AppBar(title: const Text('Losses & Bad Debt')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search customer or invoice...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                if (_searchCtrl.text.isNotEmpty)
                  IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _applyFilter(); }),
                PopupMenuButton<String>(
                  icon: Stack(clipBehavior: Clip.none, children: [
                    Icon(Icons.filter_list, color: _sortMode != kSortOptions.first ? Colors.amber : null),
                    if (_sortMode != kSortOptions.first) Positioned(
                      right: -2, top: -2,
                      child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)),
                    ),
                  ]),
                  tooltip: 'Sort by',
                  initialValue: _sortMode,
                  onSelected: (v) { setState(() => _sortMode = v); _applyFilter(); },
                  itemBuilder: (_) => kSortOptions.map((o) => PopupMenuItem(
                    value: o,
                    child: Row(children: [
                      Icon(_sortMode == o ? Icons.radio_button_checked : Icons.radio_button_off, size: 18, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(o),
                    ]),
                  )).toList(),
                ),
              ]),
            ),
            onChanged: _onSearch,
          ),
        ),
        Card(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Padding(
            padding: appSettingsNotifier.cardPadding,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Bad Debt', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
                      const SizedBox(height: 2),
                      Text(formatMoney(currentTotalLost), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    ],
                  ),
                ),
                Text('${_badDebts.length} inv', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
              ],
            ),
          ),
        ),
        Expanded(
          child: _badDebts.isEmpty
              ? const Center(child: Text('No bad debt recorded. Awesome!', style: TextStyle(color: Colors.green, fontSize: 16)))
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _badDebts.length,
            itemBuilder: (_, i) {
              final g = _badDebts[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Text(g.contractor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                      if (g.orderId != null) Text(g.invoiceNumber.isNotEmpty ? g.invoiceNumber : (g.proformaNumber.isNotEmpty ? g.proformaNumber : 'ORD-${g.orderId}'), style: const TextStyle(color: Colors.grey)),
                    ]),
                    const SizedBox(height: 8),
                    Text('Out: ${DatabaseHelper.formatDateString(g.checkoutDate)}'),
                    const Divider(),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Total Billed:'), Text(formatMoney(g.calculateTotalCost())),
                    ]),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Written Off (Bad Debt):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                      Text(formatMoney(g.badDebt), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.settings_backup_restore),
                        label: const Text('Recover Funds'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.withValues(alpha: 0.2),
                          foregroundColor: Colors.green,
                        ),
                        onPressed: () => _recoverFunds(g),
                      ),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// =============================
// Globals
// =============================

final themeModeNotifier  = ThemeModeNotifier();
final appSettingsNotifier = AppSettingsNotifier();

String get curr => appSettingsNotifier.currencySymbol;
String get appLocaleTag => appSettingsNotifier.language == 'Hindi' ? 'en_IN' : 'en_US';
Locale get appLocale => appSettingsNotifier.language == 'Hindi' ? const Locale('hi', 'IN') : const Locale('en', 'US');

String formatMoney(num value, {int decimals = 2, bool withSymbol = true, bool absolute = false}) {
  final v = absolute ? value.abs() : value;
  final text = NumberFormat.currency(
    locale: appLocaleTag,
    symbol: '',
    decimalDigits: decimals,
  ).format(v).trim();
  return withSymbol ? '$curr$text' : text;
}

String formatDateByPreference(DateTime dt) {
  switch (appSettingsNotifier.dateFormat) {
    case 'dd/MM/yyyy':
      return DateFormat('dd/MM/yyyy').format(dt);
    case 'MM/dd/yyyy':
      return DateFormat('MM/dd/yyyy').format(dt);
    case 'yyyy-MM-dd':
      return DateFormat('yyyy-MM-dd').format(dt);
    case 'dd/MMM/yyyy':
    default:
      return DateFormat('dd/MMM/yyyy').format(dt);
  }
}

String formatTimeByPreference(DateTime dt) {
  if (appSettingsNotifier.timeFormat == '24h') {
    return DateFormat('HH:mm').format(dt);
  }
  return DateFormat('h:mm a').format(dt);
}

// =================================================
// Constants
// =================================================
const List<String> kPaymentMethods    = ['Cash', 'UPI', 'Bank'];
const List<String> kSortOptions       = ['Date (Newest)', 'Date (Oldest)', 'Highest Balance'];
const List<String> kLedgerFilterOptions = ['All', 'Amount Due', 'Refund Due'];
const List<String> kTaxProfiles = [
  'No Tax',
  'India (GST)',
  'USA (Sales Tax)',
  'UK (VAT)',
  'Germany (VAT)',
  'Japan (Consumption Tax)',
  'China (VAT)',
  'Custom',
];

Map<String, dynamic> taxProfileDefaults(String profile) {
  switch (profile) {
    case 'India (GST)':
      return {'taxType': 'gst', 'taxRate': 18.0, 'taxMode': 'exclusive'};
    case 'USA (Sales Tax)':
      return {'taxType': 'sales', 'taxRate': 0.0, 'taxMode': 'exclusive'};
    case 'UK (VAT)':
      return {'taxType': 'vat', 'taxRate': 20.0, 'taxMode': 'exclusive'};
    case 'Germany (VAT)':
      return {'taxType': 'vat', 'taxRate': 19.0, 'taxMode': 'exclusive'};
    case 'Japan (Consumption Tax)':
      return {'taxType': 'consumption', 'taxRate': 10.0, 'taxMode': 'exclusive'};
    case 'China (VAT)':
      return {'taxType': 'vat', 'taxRate': 13.0, 'taxMode': 'exclusive'};
    case 'No Tax':
      return {'taxType': 'none', 'taxRate': 0.0, 'taxMode': 'exclusive'};
    case 'Custom':
    default:
      return {'taxType': 'none', 'taxRate': 0.0, 'taxMode': 'exclusive'};
  }
}

// =================================================
// Shared Helper Widgets & Functions
// =================================================

Future<bool> _confirmDialog(BuildContext context, {required String title, required String message, String confirmLabel = 'Delete'}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title), content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(d, true), child: Text(confirmLabel)),
      ],
    ),
  );
  return result == true;
}

Future<String?> pickPdfSize(BuildContext ctx) => showDialog<String>(
  context: ctx,
  builder: (d) => SimpleDialog(title: const Text('Select Paper Size'), children: [
    SimpleDialogOption(onPressed: () => Navigator.pop(d, '57mm'), child: const Text('57mm  (Thermal Receipt)')),
    SimpleDialogOption(onPressed: () => Navigator.pop(d, 'A4'),   child: const Text('A4')),
  ]),
);

void _applySort(List<RentalGroup> list, String mode) {
  switch (mode) {
    case 'Date (Newest)':   list.sort((a, b) => b.checkoutDate.compareTo(a.checkoutDate)); break;
    case 'Date (Oldest)':   list.sort((a, b) => a.checkoutDate.compareTo(b.checkoutDate)); break;
    case 'Highest Balance': list.sort((a, b) => b.balance.compareTo(a.balance)); break;
  }
}



class _StatCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color color; final String? subtitle;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color, this.subtitle});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (subtitle != null) ...[
                const SizedBox(width: 6),
                Expanded(child: Text('($subtitle)', style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7)), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]
            ],
          ),
        ],
      ),
    ),
  );
}

class _QuickAction extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      decoration: BoxDecoration(
          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8)
      ),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: Colors.amber),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ]
      ),
    ),
  );
}

// ========Invoice Manager Screen (Unified)========
class InvoiceManagerScreen extends StatelessWidget {
  final int initialIndex;
  const InvoiceManagerScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    initialIndex: initialIndex,
    child: Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TabBar(
          tabs: const [
            Tab(text: 'PROFORMA'),
            Tab(text: 'FINAL INVOICE'),
          ],
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.black12,
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          splashBorderRadius: BorderRadius.circular(24),
        ),
      ),
      body: const TabBarView(
        children: [
          OrdersListScreen(isTab: true),
          FinalInvoicesScreen(isTab: true),
        ],
      ),
    ),
  );
}

// ========Final Invoices Screen========

class FinalInvoicesScreen extends StatefulWidget {
  final bool isTab;
  const FinalInvoicesScreen({super.key, this.isTab = false});
  @override
  State<FinalInvoicesScreen> createState() => _FinalInvoicesScreenState();
}

class _FinalInvoicesScreenState extends State<FinalInvoicesScreen> {
  List<RentalGroup> _invoices = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final all = groupRentalsByInvoice(await DatabaseHelper.getAllRentals());
    final finals = all.where((g) => g.orderId != null && g.isFullyReturned).toList();
    if (!mounted) return;
    setState(() => _invoices = finals);
  }

  String _lastReturnDate(RentalGroup g) {
    DateTime? latest;
    for (final r in g.items) {
      final s = (r['returnDate'] as String?) ?? '';
      if (s.isEmpty) continue;
      try {
        final d = DateTime.parse(s);
        if (latest == null || d.isAfter(latest)) latest = d;
      } catch (_) {}
    }
    return latest == null ? 'Pending' : DatabaseHelper.formatDateFromDt(latest);
  }

  Future<void> _openPdf(int orderId, {bool share = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final size = await pickPdfSize(context);
    if (size == null || !mounted) return;

    messenger.showSnackBar(const SnackBar(content: Text('Generating PDF...')));
    try {
      final bytes = await DatabaseHelper.generatePdfFinalInvoiceForOrder(orderId, pageSize: size);
      if (share) {
        await Printing.sharePdf(bytes: bytes, filename: 'final_invoice_order_$orderId.pdf');
      } else {
        if (!mounted) return;
        await nav.push(MaterialPageRoute(builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Final Invoice Preview')),
          body: PdfPreview(build: (_) async => bytes),
        )));
      }
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.isTab ? null : AppBar(title: const Text('Invoice')),
    body: _invoices.isEmpty
        ? const Center(child: Text('No final invoices yet.\nReturn rented items first.', textAlign: TextAlign.center))
        : RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _invoices.length,
        itemBuilder: (_, i) {
          final g = _invoices[i];
          final billed = g.grandTotal;
          final balance = g.balance;
          final name = g.contractor.isNotEmpty ? g.contractor : 'Walk-in Customer';

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(child: Icon(Icons.request_quote)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: g.invoiceNumber.isNotEmpty ? g.invoiceNumber : 'Invoice #${g.orderId}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              if (g.proformaNumber.isNotEmpty)
                                TextSpan(
                                  text: ' ref ${g.proformaNumber}',
                                  style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.normal),
                                ),
                            ],
                          ),
                          style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text('Out: ${DatabaseHelper.formatDateString(g.checkoutDate)}  |  In: ${_lastReturnDate(g)}', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                        const SizedBox(height: 4),
                        Text(
                          'Billed: ${formatMoney(billed, decimals: 0)}  |  ${balance > 0 ? 'Due' : balance < 0 ? 'Refund' : 'Clear'}: ${formatMoney(balance, decimals: 0, absolute: true)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: balance > 0 ? Colors.orange : balance < 0 ? Colors.green : Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert, size: 20),
                      tooltip: 'Options',
                      onSelected: (val) {
                        if (val == 'preview') { _openPdf(g.orderId!); }
                        if (val == 'share') { _openPdf(g.orderId!, share: true); }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'preview', child: Row(children: [Icon(Icons.visibility_outlined, size: 18), SizedBox(width: 8), Text('Preview PDF')])),
                        PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.share_outlined, size: 18), SizedBox(width: 8), Text('Share PDF')])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

// ==============================
// X. System Configuration
// ==============================

// ========Settings Screen========
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _iconChannel = MethodChannel('com.wjust4435.rental_manager/icon');

  @override
  void initState() {
    super.initState();
    appSettingsNotifier.addListener(_rebuild);
    themeModeNotifier.addListener(_rebuild);
  }

  @override
  void dispose() {
    appSettingsNotifier.removeListener(_rebuild);
    themeModeNotifier.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() { if (mounted) setState(() {}); }

  // Unified selection dialog to replace repetitive list builders
  void _showSelectionDialog({required String title, required String currentVal, required List<Map<String, String>> items, required Function(String) onSelect}) {
    showDialog(context: context, builder: (ctx) => SimpleDialog(
      title: Text(title),
      children: items.map((o) => ListTile(
        title: Text(o['title']!), subtitle: o['sub'] != null ? Text(o['sub']!) : null,
        trailing: currentVal == o['val'] ? const Icon(Icons.check, color: Colors.amber) : null,
        onTap: () { onSelect(o['val']!); Navigator.pop(ctx); },
      )).toList(),
    ));
  }

  Future<void> _changeAppIcon(String iconKey) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _iconChannel.invokeMethod('setIcon', {'iconKey': iconKey});
      await appSettingsNotifier.setAppIcon(iconKey);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(iconKey == 'icon2' ? 'App icon reset to default.' : 'App icon changed successfully.'), duration: const Duration(seconds: 2)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Failed to change icon: $e')));
    }
  }

  void _showCurrencyDialog() {
    final s = appSettingsNotifier;
    final customC = TextEditingController(text: s.currencySymbol);
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Currency Symbol'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Choose a symbol:'), const SizedBox(height: 12),
        StatefulBuilder(builder: (_, setSt) => Wrap(spacing: 8, runSpacing: 8, children: ['\u20B9', '\$', '\u20AC', '\u00A3', '\u00A5', '\u0E3F'].map((sym) => ChoiceChip(
          label: Text(sym, style: const TextStyle(fontSize: 18)), selected: s.currencySymbol == sym,
          onSelected: (_) { s.setCurrencySymbol(sym); customC.text = sym; setSt(() {}); },
        )).toList())),
        const SizedBox(height: 16),
        TextField(controller: customC, decoration: const InputDecoration(labelText: 'Or type custom symbol', border: OutlineInputBorder(), isDense: true, helperText: 'Max 4 chars', counterText: ''), maxLength: 4, onChanged: (v) { if (v.trim().isNotEmpty) s.setCurrencySymbol(v.trim()); }),
      ]),
      actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
    )).then((_) => customC.dispose());
  }

  void _showOverdueDaysDialog() {
    final s = appSettingsNotifier;
    final ctrl = TextEditingController(text: s.overdueDays.toString());
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Overdue Threshold'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Rentals older than this many days will be flagged as overdue.', style: TextStyle(fontSize: 13, color: Theme.of(ctx).textTheme.bodySmall?.color)),
        const SizedBox(height: 16),
        TextField(controller: ctrl, autofocus: true, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: const InputDecoration(border: OutlineInputBorder(), suffixText: 'days', isDense: true)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () { final n = int.tryParse(ctrl.text); if (n != null && n > 0) s.setOverdueDays(n); Navigator.pop(ctx); }, child: const Text('Save')),
      ],
    )).then((_) => ctrl.dispose());
  }

  void _showPrivacyDialog() => showDialog(context: context, builder: (ctx) => AlertDialog(
    title: const Text('Privacy & Data'),
    content: const SingleChildScrollView(child: Text('Rental Manager is offline-first.\n\n- Data is stored locally.\n- No internet required.\n- You control your data exports and deletions.')),
    actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
  ));

  Widget _hdr(String t) => Padding(padding: const EdgeInsets.fromLTRB(16, 24, 16, 6), child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.amber[700])));
  Widget _infoBox(String t) => Container(margin: const EdgeInsets.fromLTRB(16, 4, 16, 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.withValues(alpha: 0.3))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.info_outline, size: 15, color: Colors.blue), const SizedBox(width: 8), Expanded(child: Text(t, style: const TextStyle(fontSize: 12, color: Colors.blue)))]));
  Widget _tile({required IconData i, required String t, required String s, VoidCallback? onTap, Widget? trail}) => ListTile(leading: Icon(i, color: Colors.amber), title: Text(t), subtitle: Text(s), trailing: trail ?? const Icon(Icons.chevron_right), onTap: onTap);
  Widget _swt({required IconData i, required String t, required String s, required bool v, required ValueChanged<bool> onChange}) => SwitchListTile(secondary: Icon(i, color: Colors.amber), title: Text(t), subtitle: Text(s), value: v, onChanged: onChange);

  @override
  Widget build(BuildContext context) {
    final s = appSettingsNotifier;
    final tm = themeModeNotifier.mode;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(children: [
        _hdr('APPEARANCE'),
        _tile(i: tm == ThemeMode.light ? Icons.light_mode : tm == ThemeMode.dark ? Icons.dark_mode : Icons.brightness_auto, t: 'Theme', s: tm == ThemeMode.light ? 'Light' : tm == ThemeMode.dark ? 'Dark' : 'System', onTap: () => themeModeNotifier.setMode(tm == ThemeMode.system ? ThemeMode.light : tm == ThemeMode.light ? ThemeMode.dark : ThemeMode.system)),
        _tile(i: Icons.app_shortcut, t: 'App Icon', s: 'Change home screen icon', onTap: () => _showSelectionDialog(title: 'Choose App Icon', currentVal: s.appIcon, items: [{'title': 'Icon Variant 1', 'val': 'icon1'}, {'title': 'Icon Variant 2 (Default)', 'val': 'icon2'}, {'title': 'Icon Variant 3', 'val': 'icon3'}], onSelect: _changeAppIcon)),
        _tile(i: Icons.density_medium, t: 'Card Density', s: s.cardDensity == 'compact' ? 'Compact' : 'Comfortable', onTap: () => _showSelectionDialog(title: 'Card Density', currentVal: s.cardDensity, items: [{'title': 'Comfortable', 'sub': 'More spacing', 'val': 'comfortable'}, {'title': 'Compact', 'sub': 'Show more cards', 'val': 'compact'}], onSelect: s.setCardDensity)),
        _tile(i: Icons.text_fields, t: 'Font Size', s: s.fontSize == 'small' ? 'Small (90%)' : s.fontSize == 'large' ? 'Large (115%)' : 'Medium', onTap: () => _showSelectionDialog(title: 'Font Size', currentVal: s.fontSize, items: [{'title': 'Small', 'sub': '90%', 'val': 'small'}, {'title': 'Medium', 'sub': '100%', 'val': 'medium'}, {'title': 'Large', 'sub': '115%', 'val': 'large'}], onSelect: s.setFontSize)),
        const Divider(height: 1),

        _hdr('BUSINESS'),
        _tile(i: Icons.currency_exchange, t: 'Currency Symbol', s: 'Currently: ${s.currencySymbol}', onTap: _showCurrencyDialog),
        _tile(i: Icons.warning_amber_rounded, t: 'Overdue Threshold', s: 'Flagged after ${s.overdueDays} days', onTap: _showOverdueDaysDialog),
        _swt(i: Icons.draw_outlined, t: 'Proforma Signatures', s: 'Show signature lines on Proforma PDFs', v: s.showProformaSignatures, onChange: s.setShowProformaSignatures),
        _swt(i: Icons.draw, t: 'Invoice Signatures', s: 'Show signature lines on Final Invoices', v: s.showInvoiceSignatures, onChange: s.setShowInvoiceSignatures),
        _swt(i: Icons.edit_document, t: 'Allow Invoice Editing', s: 'Modify records after Final Invoice is issued', v: s.allowFinalInvoiceEditing, onChange: s.setAllowFinalInvoiceEditing),
        const Divider(height: 1),

        _hdr('DASHBOARD'),
        _swt(i: Icons.leaderboard_outlined, t: 'Top Customers by Revenue', s: 'Show Top 5 list on dashboard', v: s.showTopCustomersByRevenue, onChange: s.setShowTopCustomersByRevenue),
        _swt(i: Icons.history, t: 'Payment History Time Stamp', s: 'Show time (AM/PM) in Payment History', v: s.showPaymentHistoryTime, onChange: s.setShowPaymentHistoryTime),
        const Divider(height: 1),

        _hdr('NOTIFICATIONS'),
        _swt(i: Icons.alarm_on, t: 'Overdue Rental Alert', s: 'Alert when a rental exceeds ${s.overdueDays} days', v: s.notifyOverdue, onChange: s.setNotifyOverdue),
        _swt(i: Icons.payments_outlined, t: 'Pending Payment Reminder', s: 'Remind about unsettled returned invoices', v: s.notifyPendingPayments, onChange: s.setNotifyPendingPayments),
        _hdr('SCHEDULED DIGESTS'),
        _swt(i: Icons.summarize_outlined, t: 'Daily Summary', s: 'Snapshot of active rentals/pending collections', v: s.notifySummary, onChange: s.setNotifySummary),
        _infoBox('Fires once per app open, at most once per day.'),
        const Divider(height: 1),

        _hdr('REGIONAL'),
        _tile(i: Icons.language, t: 'Language', s: s.language == 'Hindi' ? 'Hindi (India)' : 'English (US)', trail: DropdownButton<String>(value: s.language, underline: const SizedBox(), items: const [DropdownMenuItem(value: 'English', child: Text('English'))], onChanged: (v) { if (v != null) { s.setLanguage(v); } })),
        _tile(i: Icons.date_range_outlined, t: 'Date Format', s: 'Currently: ${s.dateFormat}', onTap: () => _showSelectionDialog(title: 'Date Format', currentVal: s.dateFormat, items: [{'title': 'dd/MMM/yyyy', 'val': 'dd/MMM/yyyy'}, {'title': 'dd/MM/yyyy', 'val': 'dd/MM/yyyy'}, {'title': 'MM/dd/yyyy', 'val': 'MM/dd/yyyy'}, {'title': 'yyyy-MM-dd', 'val': 'yyyy-MM-dd'}], onSelect: (v) { s.setDateFormat(v); })),
        _tile(i: Icons.access_time, t: 'Time Format', s: s.timeFormat == '24h' ? '24-hour' : '12-hour (AM/PM)', onTap: () => _showSelectionDialog(title: 'Time Format', currentVal: s.timeFormat, items: [{'title': '12-hour (AM/PM)', 'val': '12h'}, {'title': '24-hour', 'val': '24h'}], onSelect: (v) { s.setTimeFormat(v); })),
        const Divider(height: 1),

        _hdr('ABOUT'),
        const ListTile(leading: Icon(Icons.construction, color: Colors.amber), title: Text('Rental Manager', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Version 2.8.5  |  Database v37')),
        _tile(i: Icons.privacy_tip_outlined, t: 'Privacy & Data', s: 'Offline-first data handling', onTap: _showPrivacyDialog),
        _tile(i: Icons.share, t: 'Tell a Friend', s: 'Share the app with others', onTap: () => Share.share('Check out Rental Manager, a great offline tool for tracking inventory and invoices: https://gitlab.com/wjust4435/rental_manager')),
        const SizedBox(height: 40),
      ]),
    );
  }
}