//---------------------------------------------------------------------
// Rental Manager
// Copyright (C) 2026 wjust4435
// License: GNU General Public License v3.0 or later (GPL-3.0-or-later)
//---------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Added for debugPrint
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
import 'package:fl_chart/fl_chart.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RentalManagerApp());
  unawaited(_initializeServicesInBackground());
}

Future<void> _initializeServicesInBackground() async {
  try {
    await NotificationService.initialize();
  } catch (_) {
    // Keep app startup resilient even if a platform service init fails.
  }
}

//------------------------------------------
// Unified State Provider & Shared Utilities
//------------------------------------------
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

    int days = end.difference(checkout).inDays;
    if (days < 0) days = 0;
    return days == 0 ? 1 : days;
  }
}



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

// =================================================
// Theme Notifier
// =================================================
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

// =================================================
// App Settings Notifier
// =================================================
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
  String _appIcon            = 'default';
  bool   _allowFinalInvoiceEditing = true;

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
    _appIcon                   = p.getString('appIcon')                   ?? 'default';
    _allowFinalInvoiceEditing  = p.getBool('allowFinalInvoiceEditing')    ?? true;
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
}

// =================================================
// Notification Service
// =================================================
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static const String _channelId   = 'siteyard_main';
  static const String _channelName = 'SITEYARD Alerts';

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

    // Request notification permission with error handling
    try {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      if (granted == false) {
        // Permission denied - notifications will not work
        // You could show a dialog here if needed, but keeping it silent for now
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

    // Check if any notifications are actually enabled before doing anything
    if (!s.notifyOverdue && !s.notifyPendingPayments && !s.notifySummary) return;

    Future<bool> once(String key) async {
      if (prefs.getString('notif_$key') == today) return false;
      await prefs.setString('notif_$key', today);
      return true;
    }

    // Offload processing to avoid UI jank during emulator startup
    Future.microtask(() async {
      final needsGroups = (s.notifyPendingPayments && prefs.getString('notif_pending') != today) ||
          (s.notifySummary && prefs.getString('notif_summary') != today);

      List<RentalGroup> cachedGroups = [];
      if (needsGroups) {
        // Optimized fetch: We only need returned/unsettled items for notifications
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

// =================================================
// Globals
// =================================================
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
// App Root
// =================================================
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

// =================================================
// Database Helper
// =================================================
class DatabaseHelper {
  static const int _dbVersion = 26;
  static Database? _db;

  static Future<void> closeDatabase() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }

  static Future<Database> getDatabase() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/siteyard_v3.db';
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, v) async {
        // v26 Schema updates included in base creation
        await db.execute(
            "CREATE TABLE items(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, category TEXT DEFAULT 'General', total INTEGER NOT NULL DEFAULT 0, rented INTEGER DEFAULT 0, lostQty INTEGER DEFAULT 0, notes TEXT DEFAULT '', purchasePrice REAL DEFAULT 0, purchaseDate TEXT DEFAULT '', expectedLifeMonths INTEGER DEFAULT 0)"
        );
        await db.execute(
            "CREATE TABLE rentals(id INTEGER PRIMARY KEY AUTOINCREMENT, itemId INTEGER, orderId INTEGER, customerId INTEGER, contractor TEXT, phone TEXT, phone2 TEXT DEFAULT '', address TEXT, advanceDeposit REAL DEFAULT 0, discount REAL DEFAULT 0, badDebt REAL DEFAULT 0, qty INTEGER, checkoutDate TEXT, rentalRate REAL DEFAULT 0, returned INTEGER DEFAULT 0, returnDate TEXT, notes TEXT DEFAULT '', isSettled INTEGER DEFAULT 0, paymentMethod TEXT DEFAULT '', penaltyFee REAL DEFAULT 0, damagedQty INTEGER DEFAULT 0, isCancelled INTEGER DEFAULT 0, invoiceNumber TEXT DEFAULT '', voidedAt TEXT DEFAULT '')"
        );
        await db.execute(
            "CREATE TABLE customers(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, phone TEXT, phone2 TEXT DEFAULT '', email TEXT DEFAULT '', address TEXT, notes TEXT DEFAULT '', joinedDate TEXT DEFAULT '', isBlacklisted INTEGER DEFAULT 0)"
        );
        await db.execute(
            "CREATE TABLE orders(id INTEGER PRIMARY KEY AUTOINCREMENT, customerId INTEGER, customerName TEXT, createdDate TEXT, proformaNumber TEXT DEFAULT '', invoiceNumber TEXT DEFAULT '', voidedAt TEXT DEFAULT '')"
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
        if (oldV < 23) {
          try { await db.execute("ALTER TABLE rentals ADD COLUMN isCancelled INTEGER DEFAULT 0"); } catch (e, st) { debugPrint('Migration v23 error: $e\n$st'); }
        }
        if (oldV < 24) {
          try {
            await db.execute("ALTER TABLE items ADD COLUMN lostQty INTEGER DEFAULT 0");
            await db.execute("ALTER TABLE rentals ADD COLUMN damagedQty INTEGER DEFAULT 0");
          } catch (e, st) { debugPrint('Migration v24 error: $e\n$st'); }
        }
        if (oldV < 25) {
          try {
            await db.execute("CREATE TABLE sequences(seqKey TEXT PRIMARY KEY, seqValue INTEGER)");
            await db.execute("ALTER TABLE orders ADD COLUMN proformaNumber TEXT DEFAULT ''");
            await db.execute("ALTER TABLE orders ADD COLUMN invoiceNumber TEXT DEFAULT ''");
            await db.execute("ALTER TABLE rentals ADD COLUMN invoiceNumber TEXT DEFAULT ''");
            await db.execute("ALTER TABLE business_info ADD COLUMN fyStartMonth INTEGER DEFAULT 4");

            // --- OLD DATA INTELLIGENT BACKFILL ENGINE ---
            final bizRows = await db.query('business_info', where: 'id=1');
            final fyStartMonth = bizRows.isNotEmpty ? (bizRows.first['fyStartMonth'] as int? ?? 4) : 4;
            final existingOrders = await db.query('orders', orderBy: 'id ASC');

            for (final o in existingOrders) {
              final orderId = o['id'] as int;

              // 1. Generate Proforma based on Checkout Date
              final dt = DateTime.tryParse(o['createdDate'] as String? ?? '') ?? DateTime.now();
              final proformaFy = getFiscalYear(dt, fyStartMonth);
              final pSeqKey = 'ORD-$proformaFy';

              final pRows = await db.query('sequences', where: 'seqKey=?', whereArgs: [pSeqKey]);
              int pNext = 1;
              if (pRows.isEmpty) { await db.insert('sequences', {'seqKey': pSeqKey, 'seqValue': 1}); }
              else { pNext = (pRows.first['seqValue'] as int) + 1; await db.update('sequences', {'seqValue': pNext}, where: 'seqKey=?', whereArgs: [pSeqKey]); }

              final proformaNum = 'ORD-$proformaFy-$pNext';
              await db.update('orders', {'proformaNumber': proformaNum}, where: 'id=?', whereArgs: [orderId]);

              // 2. If Fully Returned, Generate Invoice based on Return Date
              final activeCount = (await db.rawQuery('SELECT COUNT(*) as c FROM rentals WHERE orderId=? AND (returned=0 OR returned IS NULL)', [orderId])).first['c'] as int? ?? 0;
              if (activeCount == 0) {
                final rentalRows = await db.query('rentals', where: 'orderId=?', whereArgs: [orderId]);
                if (rentalRows.isNotEmpty) {
                  DateTime latestReturn = DateTime(2000);
                  for(final r in rentalRows) {
                    final rd = DateTime.tryParse(r['returnDate'] as String? ?? '');
                    if (rd != null && rd.isAfter(latestReturn)) latestReturn = rd;
                  }
                  if (latestReturn.year == 2000) latestReturn = dt;

                  final invFy = getFiscalYear(latestReturn, fyStartMonth);
                  final iSeqKey = 'INV-$invFy';

                  final iRows = await db.query('sequences', where: 'seqKey=?', whereArgs: [iSeqKey]);
                  int iNext = 1;
                  if (iRows.isEmpty) { await db.insert('sequences', {'seqKey': iSeqKey, 'seqValue': 1}); }
                  else { iNext = (iRows.first['seqValue'] as int) + 1; await db.update('sequences', {'seqValue': iNext}, where: 'seqKey=?', whereArgs: [iSeqKey]); }

                  final invoiceNum = 'INV-$invFy-$iNext';
                  await db.update('orders', {'invoiceNumber': invoiceNum}, where: 'id=?', whereArgs: [orderId]);
                }
              }
            }
          } catch (e, st) { debugPrint('Migration v25 error: $e\n$st'); }
        }

        if (oldV < 26) {
          try {
            await db.execute("CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, category TEXT NOT NULL, amount REAL NOT NULL, paymentMethod TEXT, vendor TEXT, receiptPath TEXT, notes TEXT)");
            await db.execute("ALTER TABLE items ADD COLUMN purchasePrice REAL DEFAULT 0");
            await db.execute("ALTER TABLE items ADD COLUMN purchaseDate TEXT DEFAULT ''");
            await db.execute("ALTER TABLE items ADD COLUMN expectedLifeMonths INTEGER DEFAULT 0");
            await db.execute("ALTER TABLE payment_logs ADD COLUMN isCleared INTEGER DEFAULT 0");
            await db.execute("ALTER TABLE rentals ADD COLUMN voidedAt TEXT DEFAULT ''");
            await db.execute("ALTER TABLE orders ADD COLUMN voidedAt TEXT DEFAULT ''");
          } catch (e, st) { debugPrint('Migration v26 error: $e\n$st'); }
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

  static Future<int> insertExpense(String date, String category, double amount, String method, String vendor, String notes) async {
    final db = await getDatabase();
    return db.insert('expenses', {
      'date': date, 'category': category, 'amount': amount, 'paymentMethod': method, 'vendor': vendor, 'notes': notes, 'receiptPath': ''
    });
  }

  static Future<void> deleteExpense(int id) async {
    final db = await getDatabase();
    await db.delete('expenses', where: 'id=?', whereArgs: [id]);
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

  static Future<void> recoverBadDebt(int firstId, double amount, String method, List<int> allIds, bool isFullyRecovered) async {
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
        'paidAt': DateTime.now().toIso8601String(),
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

  static String isoDate(DateTime dt) => dt.toIso8601String().split('T')[0];
  static String isoNow() => isoDate(DateTime.now());

  // =================================================
  // SQL SCALABILITY & PAGINATION ENGINE
  // =================================================
  static Future<Map<String, dynamic>> getDashboardData() async {
    final db = await getDatabase();
    const daysSql = "MAX(1, CAST(julianday(IFNULL(NULLIF(returnDate, ''), date('now', 'localtime'))) - julianday(checkoutDate) AS INTEGER))";
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

  // =================================================
  // Ledger Search & Filtering (Outstanding tab)
  // =================================================
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
      'returned': q(await db.rawQuery('SELECT COUNT(*) as c FROM rentals WHERE returned=1')),
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

  static Future<void> insertItem(String name, int total, String category, String notes) async {
    final db = await getDatabase();
    await db.insert('items', {
      'name': name,
      'total': total,
      'rented': 0,
      'category': category,
      'notes': notes
    });
  }

  static Future<void> updateItem(int id, String name, int total, String category, String notes) async {
    final db = await getDatabase();
    final rows = await db.query('items', columns: ['rented'], where: 'id=?', whereArgs: [id]);
    final rented = rows.firstOrNull?['rented'] as int? ?? 0;
    await db.update('items', {
      'name': name,
      'total': total,
      'rented': rented > total ? total : rented,
      'category': category,
      'notes': notes
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
            'paidAt': checkoutDate
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
            'customerId': rental['customerId'], // NEW DB BINDING
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

  static Future<void> addPaymentToRentalGroup(int firstId, double amount, bool isFull, List<int> allIds, {String paymentMethod = '', double discountAmount = 0.0}) async {
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
          'paidAt': DateTime.now().toIso8601String(),
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

  static Future<List<Map<String, dynamic>>> getCustomers({String? search}) async {
    final db = await getDatabase();
    if (search != null && search.isNotEmpty) {
      return db.query('customers', where: 'name LIKE ? OR phone LIKE ?', whereArgs: ['%$search%', '%$search%'], orderBy: 'name ASC');
    }
    return db.query('customers', orderBy: 'name ASC');
  }

  static Future<int> insertCustomer(String name, String phone, String phone2, String email, String address, {String notes = '', String joinedDate = ''}) async {
    final db = await getDatabase();
    return db.insert('customers', {
      'name': name, 'phone': phone, 'phone2': phone2, 'email': email, 'address': address,
      'notes': notes, 'joinedDate': joinedDate.isNotEmpty ? joinedDate : isoNow(), 'isBlacklisted': 0
    });
  }

  static Future<void> updateCustomer(int id, String name, String phone, String phone2, String email, String address, {String notes = '', String joinedDate = '', int isBlacklisted = 0}) async {
    final db = await getDatabase();
    await db.update('customers', {
      'name': name, 'phone': phone, 'phone2': phone2, 'email': email, 'address': address,
      'notes': notes, 'joinedDate': joinedDate, 'isBlacklisted': isBlacklisted
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
        "SELECT rentals.*, items.name as itemName FROM rentals JOIN items ON rentals.itemId=items.id WHERE rentals.customerId=? OR (rentals.customerId IS NULL AND rentals.contractor=?) ORDER BY rentals.checkoutDate ASC, rentals.id ASC",
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
      final fyStartMonth = bizRows.isNotEmpty ? (bizRows.first['fyStartMonth'] as int? ?? 4) : 4;
      final dt = DateTime.parse(createdDate);
      final fyPrefix = getFiscalYear(dt, fyStartMonth);
      final proformaNum = await generateNextSequence(txn, 'ORD', fyPrefix);

      return await txn.insert('orders', {
        'customerId': customerId,
        'customerName': customerName,
        'createdDate': createdDate,
        'proformaNumber': proformaNum
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
          'customerId': it['customerId'], // NEW DB BINDING
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

  static Future<Map<String, dynamic>> getBusinessInfo() async {
    final db = await getDatabase();
    final rows = await db.query('business_info', where: 'id=?', whereArgs: [1]);
    if (rows.isEmpty) {
      return {
        'name': '', 'phone': '', 'phone2': '', 'email': '', 'address': '', 'upiId': '', 'upiName': '',
        'taxProfile': 'No Tax', 'taxType': 'none', 'taxRate': 0.0, 'taxMode': 'exclusive', 'taxRegNo': '', 'fyStartMonth': 4,
      };
    }
    return rows.first;
  }

  static Future<void> saveBusinessInfo(
      String name, String phone, String phone2, String email, String address, String upiId, String upiName, {
        String taxProfile = 'No Tax', String taxType = 'none', double taxRate = 0.0, String taxMode = 'exclusive', String taxRegNo = '', int fyStartMonth = 4,
      }) async {
    final db = await getDatabase();
    await db.update('business_info', {
      'name': name,
      'phone': phone,
      'phone2': phone2,
      'email': email,
      'address': address,
      'upiId': upiId,
      'upiName': upiName,
      'taxProfile': taxProfile,
      'taxType': taxType,
      'taxRate': taxRate,
      'taxMode': taxMode,
      'taxRegNo': taxRegNo,
      'fyStartMonth': fyStartMonth,
    }, where: 'id=?', whereArgs: [1]);
  }

  // =================================================
  // Tax Configuration & Calculation
  // =================================================
  static Map<String, dynamic> _taxSettingsFromBiz(Map<String, dynamic> biz) {
    final typeRaw = (biz['taxType'] as String? ?? 'none').trim().toLowerCase();
    final modeRaw = (biz['taxMode'] as String? ?? 'exclusive').trim().toLowerCase();
    final rateRaw = (biz['taxRate'] as num?)?.toDouble() ?? double.tryParse((biz['taxRate'] ?? '').toString()) ?? 0.0;
    final type = {'none','gst','vat','sales','consumption'}.contains(typeRaw) ? typeRaw : 'none';
    final mode = modeRaw == 'inclusive' ? 'inclusive' : 'exclusive';
    final rate = rateRaw.clamp(0.0, 100.0);
    final enabled = type != 'none' && rate > 0;
    final regNo = (biz['taxRegNo'] as String? ?? '').trim();
    return {
      'type': type,
      'mode': mode,
      'rate': rate,
      'enabled': enabled,
      'regNo': regNo,
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

  // =================================================
  // PROFORMA & INVOICE NUMBER SETTING AS PER FY
  // =================================================

  static String getFiscalYear(DateTime date, int fyStartMonth) {
    if (date.month >= fyStartMonth) {
      return date.year.toString();
    } else {
      return (date.year - 1).toString();
    }
  }

  static Future<String> generateNextSequence(Transaction txn, String docType, String fyPrefix) async {
    final seqKey = '$docType-$fyPrefix'; // e.g., 'ORD-2024' or 'INV-2025'
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

  // =================================================
  // PDF Invoice Generation
  // =================================================
  static Future<Uint8List> generatePdfProformaForOrder(int orderId, {String pageSize = 'A4'}) async {
    final db = await getDatabase();
    final orderList = await db.query('orders', where: 'id=?', whereArgs: [orderId]);
    if (orderList.isEmpty) throw Exception('Order not found');
    final order = orderList.first;
    final rentals = await getRentalsByOrder(orderId);
    final biz = await getBusinessInfo();

    final isCancelled = rentals.any((r) => (r['isCancelled'] as int? ?? 0) == 1);
    final is57mm = pageSize == '57mm';
    final format = is57mm ? const PdfPageFormat(57*PdfPageFormat.mm, 200*PdfPageFormat.mm, marginAll:4*PdfPageFormat.mm) : PdfPageFormat.a4;
    final fs = is57mm ? 8.0 : 11.0;

    final fonts = await _loadPdfFonts();
    final fontRegular = fonts['regular']!;
    final fontBold    = fonts['bold']!;
    final fontItalic  = fonts['italic']!;
    final showSigs    = appSettingsNotifier.showProformaSignatures;

    String s(String k) => (biz[k] as String?) ?? '';
    final bizName = s('name');
    final bizPhone = s('phone');
    final bizPhone2 = s('phone2');
    final bizEmail = s('email');
    final bizAddress = s('address');
    final bizUpi = s('upiId');
    final bizUpiName = s('upiName');

    final tax = _taxSettingsFromBiz(biz);
    final taxEnabled = tax['enabled'] == true;
    final taxLabel = (tax['label'] as String?) ?? 'Tax';
    final taxRate = (tax['rate'] as num?)?.toDouble() ?? 0.0;
    final taxMode = (tax['mode'] as String?) ?? 'exclusive';
    final taxRegNo = (tax['regNo'] as String?) ?? '';
    final taxRegLabel = (tax['regLabel'] as String?) ?? 'Tax Reg. No.';

    final currencyCode = _getCurrencyCode(appSettingsNotifier.currencySymbol);
    final upiString = 'upi://pay?pa=$bizUpi&pn=${Uri.encodeComponent(bizUpiName)}&cu=$currencyCode';
    final advance = rentals.fold(0.0, (sum, r) => sum + ((r['advanceDeposit'] as num?)?.toDouble() ?? 0.0));

    pw.TextStyle ts({double d = 0, bool bold = false, bool italic = false, PdfColor color = PdfColors.black}) => pw.TextStyle(
      fontSize: fs + d,
      font: bold ? fontBold : italic ? fontItalic : fontRegular,
      color: color,
    );

    pw.Widget watermark() => pw.Center(
      child: pw.Transform.rotate(
        angle: 0.5,
        child: pw.Text('CANCELLED', style: ts(d: 40, bold: true, color: PdfColors.red100)),
      ),
    );

    pw.Widget sigLine(String label) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(width: 120, height: 1, color: PdfColors.black),
          pw.SizedBox(height: 4),
          pw.Text(label, style: ts(d: -1))
        ]
    );

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: format,
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold, italic: fontItalic),
          buildBackground: (ctx) => isCancelled ? pw.FullPage(ignoreMargins: true, child: watermark()) : pw.SizedBox(),
        ),
        build: (ctx) => [
          if (bizName.isNotEmpty) pw.Text(bizName, style: ts(d: 4, bold: true)),
          if (bizPhone.isNotEmpty || bizPhone2.isNotEmpty) pw.Text('Ph: $bizPhone${bizPhone2.isNotEmpty ? ' / $bizPhone2' : ''}', style: ts()),
          if (bizEmail.isNotEmpty) pw.Text(bizEmail, style: ts()),
          if (bizAddress.isNotEmpty) pw.Text(bizAddress, style: ts()),
          if (taxEnabled) pw.Text('$taxLabel: ${taxRate.toStringAsFixed(2)}% (${taxMode == 'inclusive' ? 'Inclusive' : 'Exclusive'})', style: ts()),
          if (taxEnabled && taxRegNo.isNotEmpty) pw.Text('$taxRegLabel: $taxRegNo', style: ts()),
          if (bizUpi.isNotEmpty) pw.Text('UPI: $bizUpi', style: ts()),
          pw.Divider(),
          pw.Text('PROFORMA', style: ts(d: 2, bold: true)),
          pw.SizedBox(height: 4),
          pw.Text('Proforma #: ${order['proformaNumber']?.toString().isNotEmpty == true ? order['proformaNumber'] : 'ORD-$orderId'}', style: ts()),
          pw.Text('Date: ${formatDateString(order['createdDate'] as String? ?? '')}', style: ts()),
          pw.Divider(),
          pw.Row(children: [pw.Text('BILL TO: ', style: ts(bold: true)), pw.Text('${order['customerName'] ?? 'N/A'}', style: ts())]),
          if (rentals.isNotEmpty) ...[
            if (((rentals.first['phone'] as String?) ?? '').isNotEmpty) pw.Text('Ph: ${rentals.first['phone']}', style: ts()),
            if (((rentals.first['address'] as String?) ?? '').isNotEmpty) pw.Text('Site: ${rentals.first['address']}', style: ts()),
          ],
          pw.Divider(),
          pw.TableHelper.fromTextArray(
            headerStyle: ts(bold: true),
            cellStyle: ts(),
            headers: ['Item', 'Qty', 'Rate/Day'],
            headerAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.center, 2: pw.Alignment.centerRight},
            cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.center, 2: pw.Alignment.centerRight},
            data: [
              for (final r in rentals) [
                r['itemName'] ?? '',
                (r['qty'] ?? 0).toString(),
                formatMoney(((r['rentalRate'] as num?)?.toDouble() ?? 0.0))
              ]
            ],
          ),
          pw.Divider(),
          if (advance > 0) pw.Text('Advance/Security: ${formatMoney(advance)}', style: ts()),
          pw.Text('Note: This is a Proforma (estimated rental summary).', style: ts(d: -1, italic: true)),
          pw.SizedBox(height: 6),
          pw.Text('Thank you for your business!', style: ts(italic: true)),

          if (showSigs) ...[
            pw.SizedBox(height: 40),
            pw.Align(alignment: pw.Alignment.center, child: sigLine('Customer Signature')),
            pw.SizedBox(height: 40),
            pw.Align(alignment: pw.Alignment.center, child: sigLine('Vendor Signature')),
          ],

          if (bizUpi.isNotEmpty) ...[
            pw.SizedBox(height: 30),
            pw.Center(
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: upiString, width: 70, height: 70),
                      pw.SizedBox(height: 6),
                      if (bizUpiName.isNotEmpty) pw.Text(bizUpiName, style: ts(bold: true)),
                      pw.Text('UPI: $bizUpi', style: ts(d: -2)),
                    ]
                )
            ),
          ],
        ]));
    return doc.save();
  }

  static Future<Uint8List> generatePdfFinalInvoiceForOrder(int orderId, {String pageSize = 'A4'}) async {
    final db = await getDatabase();
    final orderList = await db.query('orders', where: 'id=?', whereArgs: [orderId]);
    if (orderList.isEmpty) throw Exception('Order not found');
    final order = orderList.first;
    final rentals = await getRentalsByOrder(orderId);
    if (rentals.isEmpty) throw Exception('No rentals found for order');
    final biz = await getBusinessInfo();

    final isCancelled = rentals.any((r) => (r['isCancelled'] as int? ?? 0) == 1);
    final pMap = await getPaymentLogsForGroups([RentalGroup(orderId: orderId, items: rentals)]);
    final logs = pMap.values.firstOrNull ?? [];

    final is57mm = pageSize == '57mm';
    final format = is57mm ? const PdfPageFormat(57*PdfPageFormat.mm, 220*PdfPageFormat.mm, marginAll:4*PdfPageFormat.mm) : PdfPageFormat.a4;
    final fs = is57mm ? 8.0 : 11.0;

    final fonts = await _loadPdfFonts();
    final fontRegular = fonts['regular']!;
    final fontBold    = fonts['bold']!;
    final fontItalic  = fonts['italic']!;
    final showSigs    = appSettingsNotifier.showInvoiceSignatures;

    String s(String k) => (biz[k] as String?) ?? '';
    final bizName = s('name');
    final bizPhone = s('phone');
    final bizPhone2 = s('phone2');
    final bizEmail = s('email');
    final bizAddress = s('address');
    final bizUpi = s('upiId');
    final bizUpiName = s('upiName');

    final tax = _taxSettingsFromBiz(biz);
    final taxEnabled = tax['enabled'] == true;
    final taxLabel = (tax['label'] as String?) ?? 'Tax';
    final taxRegLabel = (tax['regLabel'] as String?) ?? 'Tax Reg. No.';
    final taxRegNo = (tax['regNo'] as String?) ?? '';
    final taxRate = (tax['rate'] as num?)?.toDouble() ?? 0.0;

    final currencyCode = _getCurrencyCode(appSettingsNotifier.currencySymbol);
    final upiString = 'upi://pay?pa=$bizUpi&pn=${Uri.encodeComponent(bizUpiName)}&cu=$currencyCode';

    // Financial accumulation used by both table rows and totals section.
    double lineSubtotal = 0.0;
    double totalPenalty = 0.0;
    final lineData = <List<String>>[];
    final penaltyData = <Map<String, dynamic>>[];
    DateTime? finalReturnDate;

    for (final r in rentals) {
      final qty = r['qty'] as int? ?? 0;
      final rate = (r['rentalRate'] as num?)?.toDouble() ?? 0.0;
      final penalty = (r['penaltyFee'] as num?)?.toDouble() ?? 0.0;
      final days = _rentalChargeDays(r);
      final lineTotal = rate * qty * days;
      final returnText = formatDateString(r['returnDate'] as String?);

      lineSubtotal += lineTotal;
      if (penalty > 0) {
        totalPenalty += penalty;
        penaltyData.add({'name': r['itemName'], 'qty': qty, 'amount': penalty});
      }

      final itemName = '${r['itemName'] ?? ''}';

      lineData.add([
        '$itemName | Return: ${returnText.isEmpty ? 'Pending' : returnText}',
        qty.toString(),
        formatMoney(rate),
        days.toString(),
        formatMoney(lineTotal),
      ]);
      final rd = _safeParseDate(r['returnDate']);
      if (rd != null && (finalReturnDate == null || rd.isAfter(finalReturnDate))) {
        finalReturnDate = rd;
      }
    }

    final discount = rentals.fold(0.0, (sum, r) => sum + ((r['discount'] as num?)?.toDouble() ?? 0.0));
    final subtotalAfterDiscount = (lineSubtotal + totalPenalty) - discount;
    final totals = _taxBreakdown(subtotalAfterDiscount, tax);
    final taxableBase = totals['taxableBase'] ?? subtotalAfterDiscount;
    final taxAmount = totals['taxAmount'] ?? 0.0;
    final grandTotal = totals['grandTotal'] ?? subtotalAfterDiscount;

    // Prefer explicit payment logs for paid total; fallback to stored advance for legacy data.
    double totalPaid = 0.0;
    if (logs.isNotEmpty) {
      for (final l in logs) {
        totalPaid += (l['amount'] as num).toDouble();
      }
    } else {
      totalPaid = rentals.fold(0.0, (sum, r) => sum + ((r['advanceDeposit'] as num?)?.toDouble() ?? 0.0));
    }

    final badDebt = rentals.fold(0.0, (sum, r) => sum + ((r['badDebt'] as num?)?.toDouble() ?? 0.0));
    final balance = grandTotal - totalPaid - badDebt;
    final isSettled = rentals.every((r) => (r['isSettled'] as int? ?? 0) == 1);
    final finalReturnText = finalReturnDate == null ? 'Pending' : formatDateFromDt(finalReturnDate);

    double lineTotalOf(Map<String, dynamic> r) {
      final qty = r['qty'] as int? ?? 0;
      final rate = (r['rentalRate'] as num?)?.toDouble() ?? 0.0;
      final days = _rentalChargeDays(r);
      return rate * qty * days;
    }

    pw.TextStyle ts({double d = 0, bool bold = false, bool italic = false, PdfColor color = PdfColors.black}) => pw.TextStyle(
      fontSize: fs + d,
      font: bold ? fontBold : italic ? fontItalic : fontRegular,
      color: color,
    );

    pw.Widget watermark() => pw.Center(
      child: pw.Transform.rotate(
        angle: 0.5,
        child: pw.Text('CANCELLED', style: ts(d: is57mm ? 30 : 60, bold: true, color: PdfColors.red100)),
      ),
    );

    pw.Widget sigLine(String label) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(width: is57mm ? 75 : 120, height: 1, color: PdfColors.black),
        pw.SizedBox(height: 4),
        pw.Text(label, style: ts(d: -1)),
      ],
    );

    pw.Widget thermalItemRow(Map<String, dynamic> r) {
      final ret = formatDateString(r['returnDate'] as String?);
      final qty = r['qty'] ?? 0;
      final rate = (r['rentalRate'] as num?)?.toDouble() ?? 0.0;
      final days = _rentalChargeDays(r);
      final amount = lineTotalOf(r);

      final itemNameText = (r['itemName'] ?? '').toString();

      pw.Widget cell(String text, {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: pw.Text(text, style: ts(d: -1, bold: bold), textAlign: align),
      );

      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '$itemNameText | Return date: ${ret.isEmpty ? 'Pending' : ret}',
              style: ts(d: -0.5, bold: true),
            ),
            pw.SizedBox(height: 1),
            pw.Table(
              border: const pw.TableBorder(
                top: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
                bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
                left: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
                right: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
                horizontalInside: pw.BorderSide(width: 0.4, color: PdfColors.grey600),
                verticalInside: pw.BorderSide(width: 0.4, color: PdfColors.grey600),
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.1),
                1: const pw.FlexColumnWidth(2.0),
                2: const pw.FlexColumnWidth(1.1),
                3: const pw.FlexColumnWidth(2.0),
              },
              children: [
                pw.TableRow(children: [
                  cell('Qty', bold: true, align: pw.TextAlign.center),
                  cell('Rate/Day', bold: true, align: pw.TextAlign.center),
                  cell('Days', bold: true, align: pw.TextAlign.center),
                  cell('Amount', bold: true, align: pw.TextAlign.right),
                ]),
                pw.TableRow(children: [
                  cell('$qty', align: pw.TextAlign.center),
                  cell(formatMoney(rate), align: pw.TextAlign.center),
                  cell('$days', align: pw.TextAlign.center),
                  cell(formatMoney(amount), bold: true, align: pw.TextAlign.right),
                ]),
              ],
            ),
          ],
        ),
      );
    }

    // Render one canonical invoice document from already-computed financial values.
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: format,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold, italic: fontItalic),
        buildBackground: (ctx) => isCancelled ? pw.FullPage(ignoreMargins: true, child: watermark()) : pw.SizedBox(),
      ),
      build: (ctx) => [
        if (bizName.isNotEmpty) pw.Text(bizName, style: ts(d: 4, bold: true)),
        if (bizPhone.isNotEmpty || bizPhone2.isNotEmpty) pw.Text('Ph: $bizPhone${bizPhone2.isNotEmpty ? ' / $bizPhone2' : ''}', style: ts()),
        if (bizEmail.isNotEmpty) pw.Text(bizEmail, style: ts()),
        if (bizAddress.isNotEmpty) pw.Text(bizAddress, style: ts()),
        if (taxEnabled && taxRegNo.isNotEmpty) pw.Text('$taxRegLabel: $taxRegNo', style: ts()),
        if (bizUpi.isNotEmpty) pw.Text('UPI: $bizUpi', style: ts()),
        pw.Divider(),
        pw.Text('FINAL INVOICE', style: ts(d: 2, bold: true)),
        pw.SizedBox(height: 4),
        pw.Text('Invoice #: ${order['invoiceNumber']?.toString().isNotEmpty == true ? order['invoiceNumber'] : 'INV-$orderId'}', style: ts()),
        if (order['proformaNumber']?.toString().isNotEmpty == true) pw.Text('Ref Proforma: ${order['proformaNumber']}', style: ts(d: -1, italic: true)),
        pw.Text('Order Date: ${formatDateString(order['createdDate'] as String? ?? '')}', style: ts()),
        pw.Text('Invoice/Return Date: $finalReturnText', style: ts()),
        pw.Divider(),
        pw.Row(children: [pw.Text('BILL TO: ', style: ts(bold: true)), pw.Text('${order['customerName'] ?? 'N/A'}', style: ts())]),
        if (rentals.isNotEmpty) ...[
          if (((rentals.first['phone'] as String?) ?? '').isNotEmpty) pw.Text('Ph: ${rentals.first['phone']}', style: ts()),
          if (((rentals.first['address'] as String?) ?? '').isNotEmpty) pw.Text('Site: ${rentals.first['address']}', style: ts()),
        ],
        pw.Divider(),
        if (is57mm) ...[
          for (final r in rentals) ...[
            thermalItemRow(r),
            pw.SizedBox(height: 2),
          ],
        ] else ...[
          pw.TableHelper.fromTextArray(
            headerStyle: ts(bold: true),
            cellStyle: ts(d: -1),
            headers: ['Item', 'Qty', 'Rate/Day', 'Days', 'Line Total'],
            headerAlignments: {
              0: pw.Alignment.centerLeft, 1: pw.Alignment.center, 2: pw.Alignment.centerRight, 3: pw.Alignment.center, 4: pw.Alignment.centerRight
            },
            cellAlignments: {
              0: pw.Alignment.centerLeft, 1: pw.Alignment.center, 2: pw.Alignment.centerRight, 3: pw.Alignment.center, 4: pw.Alignment.centerRight
            },
            data: lineData,
          ),
        ],
        pw.SizedBox(height: 4),
        // --- FINANCIAL BREAKDOWN START ---
        pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 0.5),

        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Rentals Subtotal:', style: ts()),
          pw.Text(formatMoney(lineSubtotal, decimals: is57mm ? 0 : 2), style: ts()),
        ]),

        for (final p in penaltyData)
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Damage Penalty (${p['name']}):', style: ts()),
            pw.Text('+ ${formatMoney(p['amount'], decimals: is57mm ? 0 : 2)}', style: ts()),
          ]),

        if (discount > 0) pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Discount:', style: ts()),
          pw.Text('- ${formatMoney(discount, decimals: is57mm ? 0 : 2)}', style: ts()),
        ]),

        // CONDITIONAL TAX RENDERING
        if (taxEnabled) ...[
          pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 0.5),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Net Subtotal:', style: ts(bold: true)),
            pw.Text(formatMoney(taxableBase, decimals: is57mm ? 0 : 2), style: ts(bold: true)),
          ]),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('$taxLabel ${taxRate.toStringAsFixed(2)}%:', style: ts()),
            pw.Text('+ ${formatMoney(taxAmount, decimals: is57mm ? 0 : 2)}', style: ts()),
          ]),
        ],

        // GRAND TOTAL
        pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 0.5),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('TOTAL BILLED:', style: ts(bold: true)),
          pw.Text(formatMoney(grandTotal, decimals: is57mm ? 0 : 2), style: ts(bold: true)),
        ]),

        // PAYMENTS & DEDUCTIONS
        if (badDebt > 0) pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Written Off (Bad Debt):', style: ts()),
          pw.Text('- ${formatMoney(badDebt, decimals: is57mm ? 0 : 2)}', style: ts()),
        ]),

        if (logs.isNotEmpty) ...[
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Advance/Security:', style: ts()),
            pw.Text('- ${formatMoney(logs.first['amount'] as double, decimals: is57mm ? 0 : 2)}', style: ts()),
          ]),
          for (int i = 1; i < logs.length; i++)
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text((logs[i]['amount'] as num) < 0
                  ? 'Refunded ${((logs[i]['method'] as String?) ?? '').isEmpty ? '' : logs[i]['method']}:'
                  : 'Paid ${((logs[i]['method'] as String?) ?? '').isEmpty ? 'Payment' : logs[i]['method']}:', style: ts()),
              pw.Text(((logs[i]['amount'] as num) < 0 ? '+ ' : '- ') + formatMoney((logs[i]['amount'] as num).abs(), decimals: is57mm ? 0 : 2), style: ts()),
            ]),
        ] else if (totalPaid > 0) ...[
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Advance/Security Paid:', style: ts()),
            pw.Text('- ${formatMoney(totalPaid, decimals: is57mm ? 0 : 2)}', style: ts()),
          ]),
        ],

        // FINAL BALANCE
        pw.Divider(thickness: is57mm ? 1.0 : 1.0),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(balance > 0 ? 'BALANCE DUE:' : balance < 0 ? 'REFUND DUE:' : 'BALANCE:', style: ts(bold: true, d: 1)),
          pw.Text(formatMoney(balance.abs(), decimals: is57mm ? 0 : 2), style: ts(bold: true, d: 1)),
        ]),

        pw.SizedBox(height: 8),
        pw.Center(child: pw.Text(
            isSettled ? '*** SETTLED ***' : '*** PENDING ***',
            style: ts(bold: true, d: 1)
        )),
        pw.SizedBox(height: 8),
        // --- FINANCIAL BREAKDOWN END ---

        if (showSigs) ...[
          pw.SizedBox(height: is57mm ? 18 : 30),
          pw.Align(alignment: pw.Alignment.center, child: sigLine('Customer Signature')),
          pw.SizedBox(height: 5),
          pw.SizedBox(height: is57mm ? 18 : 30),
          pw.Align(alignment: pw.Alignment.center, child: sigLine('Vendor Signature')),
        ],

        pw.SizedBox(height: 8),
        pw.Text('This is the final invoice based on actual return dates.', style: ts(d: -1, italic: true)),
        if (bizUpi.isNotEmpty) ...[
          pw.SizedBox(height: 20),
          pw.Center(
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: upiString, width: 70, height: 70),
                    pw.SizedBox(height: 6),
                    if (bizUpiName.isNotEmpty) pw.Text(bizUpiName, style: ts(bold: true)),
                    pw.Text('UPI: $bizUpi', style: ts(d: -2)),
                  ]
              )
          ),
        ],
      ],
    ));
    return doc.save();
  }

  static Future<String> exportBackup() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final bytes = await File('${dir.path}/siteyard_v3.db').readAsBytes();
      final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Database Backup',
          fileName: 'siteyard_backup.db',
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
      await closeDatabase();
      final dir = await getApplicationDocumentsDirectory();
      await File(result.files.single.path!).copy('${dir.path}/siteyard_v3.db');
      return 'Restored successfully. Please restart the app.';
    } catch (e) {
      return 'Restore failed: $e';
    }
  }
}

// =================================================
// Shared Models & Grouping
// =================================================
class RentalGroup {
  final int? orderId, fallbackId;
  final List<Map<String, dynamic>> items;
  RentalGroup({this.orderId, this.fallbackId, required this.items});

  String get proformaNumber => items.first['proformaNumber'] as String? ?? '';
  String get invoiceNumber => items.first['invoiceNumber'] as String? ?? '';

  bool get isGroup         => orderId != null;
  bool get isFullyReturned => items.every((r) => r['returned'] == 1);
  bool get isSettled       => items.every((r) => r['isSettled'] == 1);
  bool get isCancelled     => items.any((r) => (r['isCancelled'] as int? ?? 0) == 1);
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
  double get balance => calculateTotalCost() - advance - discount - badDebt;

  double calculateTotalCost() {
    if (isCancelled) return 0.0;
    double total = 0.0;
    for (final r in items) {
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

// =================================================
// Universal Rental Card
// =================================================
class UniversalRentalCard extends StatelessWidget {
  final RentalGroup group;
  final List<Map<String, dynamic>>? paymentLogs;
  final bool showCustomerName;
  final VoidCallback? onEdit;
  final VoidCallback? onReturn;
  final VoidCallback? onSettle;
  final VoidCallback? onPdf;
  final VoidCallback? onProforma;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;
  final VoidCallback? onViewPayments;

  const UniversalRentalCard({
    super.key,
    required this.group,
    this.paymentLogs,
    this.showCustomerName = true,
    this.onEdit,
    this.onReturn,
    this.onSettle,
    this.onPdf,
    this.onProforma,
    this.onCancel,
    this.onDelete,
    this.onViewPayments,
  });

  @override
  Widget build(BuildContext context) {
    final settings = AppProvider.of(context);
    final compact = settings.cardDensity == 'compact';
    final dividerHeight = compact ? 10.0 : 16.0;

    DateTime checkoutDt;
    try {
      checkoutDt = DateTime.parse(group.checkoutDate);
    } catch (_) {
      checkoutDt = DateTime.now();
    }

    final dayCount = DateTime.now().difference(checkoutDt).inDays;
    final isOverdue = !group.isFullyReturned && dayCount > settings.overdueDays;
    final totalCost = group.calculateTotalCost();
    final balance = group.balance;

    double initialAdvance = 0.0;
    double laterPaid = 0.0;
    if (group.isFullyReturned) {
      final payments = paymentLogs ?? const <Map<String, dynamic>>[];
      if (payments.isNotEmpty) {
        initialAdvance = (payments.first['amount'] as num?)?.toDouble() ?? 0.0;
        for (int j = 1; j < payments.length; j++) {
          laterPaid += (payments[j]['amount'] as num?)?.toDouble() ?? 0.0;
        }
      } else {
        initialAdvance = group.advance;
      }
    }

    return Card(
      margin: EdgeInsets.only(bottom: compact ? 8 : 10),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: isOverdue
            ? const BoxDecoration(border: Border(left: BorderSide(color: Colors.orange, width: 4)))
            : null,
        child: Padding(
          padding: settings.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (isOverdue)
                    Padding(
                      padding: EdgeInsets.only(right: compact ? 4 : 6),
                      child: Icon(Icons.warning_amber_rounded, color: Colors.orange, size: compact ? 16 : 18),
                    ),
                  Expanded(
                    child: showCustomerName
                        ? Text.rich(
                      TextSpan(children: [
                        TextSpan(text: group.contractor, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        if (group.phone.isNotEmpty)
                          TextSpan(
                            text: '  | Ph# ${group.phone}${group.phone2.isNotEmpty ? ' / ${group.phone2}' : ''}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Theme.of(context).textTheme.bodySmall?.color),
                          ),
                      ]),
                      overflow: TextOverflow.ellipsis,
                    )
                        : Text(
                      group.orderId != null
                          ? (group.invoiceNumber.isNotEmpty
                          ? '${group.invoiceNumber}${group.proformaNumber.isNotEmpty ? " ref ${group.proformaNumber}" : ""}'
                          : (group.proformaNumber.isNotEmpty ? group.proformaNumber : 'ORD-${group.orderId}'))
                          : (group.isFullyReturned ? 'Settled Rental' : 'Active Rental'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (group.isCancelled)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                      child: const Text('CANCELLED', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                  else if (group.badDebt > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                      child: const Text('BAD DEBT', style: TextStyle(color: Colors.redAccent, fontSize: 10.5, fontWeight: FontWeight.bold)),
                    )
                  else if (group.isFullyReturned && group.isSettled)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                        child: const Text('PAID', style: TextStyle(color: Colors.greenAccent, fontSize: 10.5, fontWeight: FontWeight.bold)),
                      ),
                  SizedBox(
                    width: 32,
                    child: PopupMenuButton<String>(
                      tooltip: 'Options',
                      onSelected: (val) {
                        if (val == 'edit') onEdit?.call();
                        if (val == 'cancel') onCancel?.call();
                        if (val == 'delete') onDelete?.call();
                        if (val == 'pdf' && group.orderId != null) onPdf?.call();
                        if (val == 'proforma' && group.orderId != null) onProforma?.call();
                      },
                      itemBuilder: (_) => [
                        if (onEdit != null)
                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit')])),
                        if (onProforma != null && group.orderId != null)
                          const PopupMenuItem(value: 'proforma', child: Row(children: [Icon(Icons.description_outlined, size: 18, color: Colors.blueAccent), SizedBox(width: 8), Text('View Proforma', style: TextStyle(color: Colors.blueAccent))])),
                        if (onPdf != null && group.orderId != null)
                          const PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf_outlined, size: 18, color: Colors.amber), SizedBox(width: 8), Text('Final Invoice', style: TextStyle(color: Colors.amber))])),
                        if (onCancel != null && !group.isCancelled)
                          const PopupMenuItem(value: 'cancel', child: Row(children: [Icon(Icons.cancel_outlined, size: 18, color: Colors.orange), SizedBox(width: 8), Text('Cancel Invoice', style: TextStyle(color: Colors.orange))])),
                        if (onDelete != null)
                          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete Record', style: TextStyle(color: Colors.red))])),
                      ],
                      child: const Align(alignment: Alignment.centerRight, child: Icon(Icons.more_vert, size: 20)),
                    ),
                  ),
                ],
              ),
              if (showCustomerName || group.address.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: compact ? 1 : 2),
                  child: Text.rich(
                    TextSpan(
                        style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color),
                        children: [
                          if (showCustomerName && group.orderId != null) ...[
                            TextSpan(
                                text: group.invoiceNumber.isNotEmpty ? group.invoiceNumber : (group.proformaNumber.isNotEmpty ? group.proformaNumber : 'ORD-${group.orderId}'),
                                style: const TextStyle(fontWeight: FontWeight.bold)
                            ),
                            if (group.invoiceNumber.isNotEmpty && group.proformaNumber.isNotEmpty)
                              TextSpan(
                                text: ' ref ${group.proformaNumber}',
                                style: const TextStyle(fontWeight: FontWeight.normal, fontStyle: FontStyle.italic, fontSize: 12),
                              ),
                            if (group.address.isNotEmpty) const TextSpan(text: '  |  '),
                          ],
                          if (group.address.isNotEmpty)
                            TextSpan(text: 'Site: ${group.address}'),
                        ]
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.only(top: compact ? 1 : 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: const TextStyle(fontSize: 14),
                          children: [
                            TextSpan(text: 'Checkout: ${DatabaseHelper.formatDateString(group.checkoutDate)}'),
                            if (!group.isFullyReturned) ...[
                              const TextSpan(text: '  |  '),
                              TextSpan(
                                text: '$dayCount days',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isOverdue ? Colors.orange : Colors.blue,
                                ),
                              ),
                            ],
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: dividerHeight),
              ...group.items.map((r) {
                final isRet = r['returned'] == 1;
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: compact ? 2 : 4),
                  child: Row(
                    children: [
                      Icon(
                        isRet ? Icons.check_circle : Icons.radio_button_checked,
                        size: compact ? 14 : 16,
                        color: isRet ? Colors.green : Colors.redAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${r['itemName']} x ${r['qty']} @ ${formatMoney(((r['rentalRate'] as num?)?.toDouble() ?? 0.0))}/day',
                          style: TextStyle(fontSize: 13, color: isRet ? Colors.grey : null),
                        ),
                      ),
                      if (isRet)
                        Text(
                          DatabaseHelper.formatDateString(r['returnDate'] as String?),
                          style: const TextStyle(color: Colors.green, fontSize: 11),
                        ),
                    ],
                  ),
                );
              }),
              if (group.notes.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: compact ? 2 : 4),
                  child: Text('Note: ${group.notes}', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12)),
                ),
              Divider(height: dividerHeight),
              if (!group.isFullyReturned) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Live Cost: ${formatMoney(totalCost)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Row(children: [Text('Adv/Security: ${formatMoney(group.advance)}'), _PaymentLabel(group.paymentMethod)]),
                          Text('Balance: ${formatMoney(balance)}', style: TextStyle(color: balance > 0 ? Colors.orangeAccent : Colors.greenAccent, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    if (onReturn != null)
                      ElevatedButton.icon(
                        icon: Icon(Icons.check_circle_outline, size: compact ? 16 : 18),
                        label: const Text('Return Items'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 8 : 10),
                          minimumSize: Size(0, compact ? 32 : 38),
                        ),
                        onPressed: onReturn,
                      ),
                  ],
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Billed: ${formatMoney(totalCost)}', style: TextStyle(decoration: group.isCancelled ? TextDecoration.lineThrough : null)),
                          if (group.items.any((r) => ((r['penaltyFee'] as num?)?.toDouble() ?? 0.0) > 0)) ...group.items.where((r) => ((r['penaltyFee'] as num?)?.toDouble() ?? 0.0) > 0).map((r) => Text('Damage Penalty (${r['itemName']}): + ${formatMoney(((r['penaltyFee'] as num?)?.toDouble() ?? 0.0))}', style: const TextStyle(color: Colors.redAccent))),
                          if (group.discount != 0) Text('Discount: - ${formatMoney(group.discount)}'),
                          if (group.badDebt != 0) Text('Written Off: - ${formatMoney(group.badDebt)}', style: const TextStyle(color: Colors.redAccent)),
                          Text('Advance/Security: - ${formatMoney(initialAdvance)}'),
                          if (laterPaid != 0) Text('Payment(s): - ${formatMoney(laterPaid)}'),
                          const SizedBox(height: 4),
                          Text(
                            group.isSettled ? 'Settled: Balance Cleared' : 'Final Balance: ${formatMoney(balance)}',
                            style: TextStyle(color: group.isSettled ? Colors.grey : (balance > 0 ? Colors.orange : Colors.green), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (onViewPayments != null)
                          SizedBox(
                            width: 32,
                            child: Tooltip(
                              message: 'View Payments',
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: onViewPayments,
                                child: const Align(
                                  alignment: Alignment.centerRight,
                                  child: Icon(Icons.receipt_long, color: Colors.amber, size: 20),
                                ),
                              ),
                            ),
                          ),
                        if (!group.isSettled && onSettle != null) ...[
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            icon: Icon(balance < 0 ? Icons.undo : Icons.payment, size: 16),
                            label: Text(compact ? 'Settle' : (balance < 0 ? 'Record Refund' : 'Record Payment')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: balance < 0 ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                              foregroundColor: balance < 0 ? Colors.greenAccent : Colors.orangeAccent,
                              padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 8 : 10),
                              minimumSize: Size(0, compact ? 32 : 38),
                              visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
                            ),
                            onPressed: onSettle,
                          ),
                        ],
                      ],
                    )
                  ],
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

// =================================================
// Main Shell
// =================================================
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
    // Defer notification checks so the main thread can render the Dashboard first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) NotificationService.checkAndNotify();
      });
    });
  }

  void _nav(Widget screen) { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => screen)); }

  Widget _drawerNavItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    onTap: onTap,
  );

  Widget _drawerHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.4, color: Colors.amber[600])),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Rental Manager'),
      actions: [IconButton(icon: const Icon(Icons.settings_outlined), tooltip: 'Settings', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())))],
    ),
    drawer: _buildDrawer(),
    body: _screens[_idx],
    bottomNavigationBar: NavigationBar(
      selectedIndex: _idx,
      onDestinationSelected: (i) => setState(() => _idx = i),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined),  selectedIcon: Icon(Icons.dashboard),  label: 'Dashboard'),
        NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Inventory'),
        NavigationDestination(icon: Icon(Icons.handshake_outlined),  selectedIcon: Icon(Icons.handshake),  label: 'Rentals'),
        NavigationDestination(icon: Icon(Icons.history_outlined),    selectedIcon: Icon(Icons.history),    label: 'History'),
      ],
    ),
  );

  Widget _buildDrawer() => Drawer(child: SafeArea(child: Column(children: [
    FutureBuilder<Map<String, dynamic>>(
      future: DatabaseHelper.getBusinessInfo(),
      builder: (context, snapshot) {
        final bizName = snapshot.data?['name'] as String? ?? '';
        final displayBizName = bizName.trim().isEmpty ? 'Rental Manager' : bizName;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFF2A2A2A);

        return Material(
          color: bgColor,
          child: InkWell(
            onTap: () => _nav(const BusinessInfoScreen()),
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
    ),
    Expanded(child: ListView(padding: EdgeInsets.zero, children: [
      _drawerHeader('TRANSACTIONS'),
      _drawerNavItem(icon: Icons.account_balance_wallet, title: 'Revenue Ledger', onTap: () => _nav(const PaymentLedgerScreen())),
      _drawerNavItem(icon: Icons.receipt_long, title: 'Proformas & Invoices', onTap: () => _nav(const InvoiceManagerScreen())),

      _drawerHeader('ACCOUNTING'),
      _drawerNavItem(icon: Icons.bar_chart, title: 'Financial Reports', onTap: () => _nav(const FinancialReportsScreen())),
      _drawerNavItem(icon: Icons.outbox, title: 'Business Expenses', onTap: () => _nav(const ExpenseTrackingScreen())),
      _drawerNavItem(icon: Icons.money_off, title: 'Losses & Bad Debt', onTap: () => _nav(const LossesAndBadDebtScreen())),

      const Divider(height: 1),
      _drawerHeader('MANAGEMENT'),
      _drawerNavItem(icon: Icons.store, title: 'Business Info', onTap: () => _nav(const BusinessInfoScreen())),
      _drawerNavItem(icon: Icons.group, title: 'Customers', onTap: () => _nav(const CustomersManagementScreen())),

      const Divider(height: 1),
      _drawerHeader('DATA & SYSTEM'),
      ListTile(leading: const Icon(Icons.save_alt), title: const Text('Export Backup'),
          onTap: () async { final m = ScaffoldMessenger.of(context); Navigator.pop(context); final result = await DatabaseHelper.exportBackup(); m.showSnackBar(SnackBar(content: Text(result))); }),
      ListTile(leading: const Icon(Icons.upload), title: const Text('Restore from Backup'),
          onTap: () async { final m = ScaffoldMessenger.of(context); Navigator.pop(context); final result = await DatabaseHelper.importBackup(); m.showSnackBar(SnackBar(content: Text(result))); }),
    ])),
  ])));
}

// =================================================
// Dashboard Screen
// =================================================
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, int> _stats = {};
  List<Map<String, dynamic>> _overdueRentals = [];
  List<Map<String, dynamic>> _topCustomers = [];
  double _pendingCollections = 0.0;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });

    try {
      final overdueDays = appSettingsNotifier.overdueDays;

      // Offload all heavy calculation directly to the optimized SQLite Engine
      final data = await DatabaseHelper.getDashboardData();
      final overdue = await DatabaseHelper.getOverdueRentals(overdueDays);
      final stats = await DatabaseHelper.getDashboardStats(overdueDays: overdueDays);

      if (!mounted) return;
      setState(() {
        _stats = stats;
        _pendingCollections = data['pendingCollections'];
        _topCustomers = data['topCustomers'];
        _overdueRentals = overdue;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('Dashboard load error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load dashboard data.\nPlease try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    // Safety Net: Handle Uncaught Load Errors Cleanly
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

// Now safely consuming settings from the InheritedNotifier context
    final settings = AppProvider.of(context);
    final showTopCustomers = settings.showTopCustomersByRevenue;

    return RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
      Row(
        children: [
          Expanded(child: _StatCard(label:'Total Items',    value:'${_stats['items']}',         icon:Icons.inventory_2,  color:Colors.blue)),
          const SizedBox(width: 8),
          Expanded(child: _StatCard(label:'Active Lines',   value:'${_stats['activeRentals']}', icon:Icons.handshake,    color:Colors.orange)),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: _StatCard(label:'Customers',      value:'${_stats['customers']}',     icon:Icons.people,       color:Colors.purple)),
          const SizedBox(width: 8),
          Expanded(child: _StatCard(label:'Returned Lines', value:'${_stats['returned']}',      icon:Icons.check_circle, color:Colors.green)),
        ],
      ),
      const SizedBox(height: 14),

      Card(
        child: ListTile(
          leading: const Icon(Icons.account_balance_wallet, color: Colors.orange),
          title: const Text('Pending Collections', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Outstanding amount from returned invoices'),
          trailing: Text(formatMoney(_pendingCollections, decimals: 0),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange)),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentLedgerScreen())),
        ),
      ),
      const SizedBox(height: 20),

      const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),

      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.4, // Keeps the flatter, compact button layout
        children: [
          _QuickAction(icon:Icons.playlist_add,           label:'New Order', onTap:() => Navigator.push(context, MaterialPageRoute(builder:(_) => const NewOrderScreen()))),
          _QuickAction(icon:Icons.account_balance_wallet, label:'Ledger',    onTap:() => Navigator.push(context, MaterialPageRoute(builder:(_) => const PaymentLedgerScreen()))),
          _QuickAction(icon:Icons.store,                  label:'Biz Info',  onTap:() => Navigator.push(context, MaterialPageRoute(builder:(_) => const BusinessInfoScreen()))),
          _QuickAction(icon:Icons.receipt_long,           label:'Proforma',  onTap:() => Navigator.push(context, MaterialPageRoute(builder:(_) => const InvoiceManagerScreen(initialIndex: 0)))),
          _QuickAction(icon:Icons.request_quote,          label:'Invoice',   onTap:() => Navigator.push(context, MaterialPageRoute(builder:(_) => const InvoiceManagerScreen(initialIndex: 1)))),
          _QuickAction(icon:Icons.people,                 label:'Customers', onTap:() => Navigator.push(context, MaterialPageRoute(builder:(_) => const CustomersManagementScreen()))),
        ],
      ),

      if ((_stats['overdue'] ?? 0) > 0) ...[
        const SizedBox(height: 20),
        Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange), const SizedBox(width: 8),
          Text('Overdue Rentals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange[300])),
        ]),
        const SizedBox(height: 8),
        ..._overdueRentals.map((r) {
          final days = DateTime.now().difference(DateTime.tryParse(r['checkoutDate'] as String? ?? '') ?? DateTime.now()).inDays;
          return Card(color: Colors.orange.withValues(alpha:0.15), child: ListTile(
            leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            title: Text('${r['contractor']} - ${r['itemName']}'),
            subtitle: Text('Out since: ${DatabaseHelper.formatDateString(r['checkoutDate'] as String?)} ($days days)'),
          ));
        }),
      ],
      if (showTopCustomers) ...[
        const SizedBox(height: 20),
        const Text('Top Customers By Revenue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (_topCustomers.isEmpty)
          const Card(child: ListTile(title: Text('No customer revenue data yet.')))
        else
          ..._topCustomers.asMap().entries.map((e) {
            final rank = e.key + 1;
            final c = e.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.amber.withValues(alpha: 0.2),
                  child: Text('$rank', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                title: Text((c['name'] as String?) ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Invoices: ${c['invoices']}'),
                trailing: Text(formatMoney((c['revenue'] as double?) ?? 0.0, decimals: 0),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ),
            );
          }),
      ],
    ]));
  }
}

class _StatCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
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
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
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

// =================================================
// Settle Group Dialog (proper StatefulWidget)
// =================================================
class _SettleGroupDialog extends StatefulWidget {
  final RentalGroup group;
  const _SettleGroupDialog({required this.group});
  @override
  State<_SettleGroupDialog> createState() => _SettleGroupDialogState();
}

class _SettleGroupDialogState extends State<_SettleGroupDialog> {
  late final TextEditingController payC;
  late final TextEditingController discC;
  late final GlobalKey<FormState> formKey;
  String method = kPaymentMethods.first;
  String discountType = 'None';
  bool isBadDebtWriteOff = false;

  @override
  void initState() {
    super.initState();
    formKey = GlobalKey<FormState>();
    payC = TextEditingController(text: widget.group.balance.abs().toStringAsFixed(2));
    discC = TextEditingController();
  }

  @override
  void dispose() { payC.dispose(); discC.dispose(); super.dispose(); }

  double _calculateDiscountAmount(double maxAllowed) {
    if (discountType == 'None') return 0.0;
    final val = double.tryParse(discC.text) ?? 0.0;
    if (val <= 0) return 0.0;
    if (discountType == 'Percentage') {
      return (maxAllowed * (val / 100)).clamp(0.0, maxAllowed);
    }
    return val.clamp(0.0, maxAllowed);
  }

  @override
  Widget build(BuildContext context) {
    final isRefund   = widget.group.balance < 0;
    final absBalance = widget.group.balance.abs();
    return AlertDialog(
      title: Text(isRefund ? 'Record Refund' : 'Record Payment'),
      content: SingleChildScrollView(
        child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isRefund
              ? 'Refund Due to Customer: ${formatMoney(absBalance)}'
              : 'Total Remaining Balance: ${formatMoney(absBalance)}'),
          const SizedBox(height: 16),
          TextFormField(
            controller: payC,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: isRefund ? 'Amount Refunded ($curr)' : 'Amount Paid ($curr)', border: const OutlineInputBorder()),
            validator: (v) {
              final val = double.tryParse(v??'');
              if (val==null||val<0) return 'Invalid amount';
              return null;
            },
          ),
          const SizedBox(height: 16),
          if (!isBadDebtWriteOff)
            DropdownButtonFormField<String>(
              initialValue: method,
              decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder(), prefixIcon: Icon(Icons.payment)),
              items: kPaymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) { if (v != null) setState(() => method = v); },
            ),

          if (!isRefund) ...[
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Write off as Bad Debt', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
              subtitle: const Text('Customer absconded or refused payment.'),
              value: isBadDebtWriteOff,
              activeThumbColor: Colors.red, // Modern SDK standard
              onChanged: (v) => setState(() { isBadDebtWriteOff = v; if (v) discountType = 'None'; }),
            ),
          ],

          if (!isBadDebtWriteOff) ...[ // FIX: Correctly opening the array block here
            const SizedBox(height: 24),
            const Text('Apply Discount (Optional)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: discountType,
              decoration: const InputDecoration(labelText: 'Discount Type', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'None', child: Text('None')),
                DropdownMenuItem(value: 'Flat', child: Text('Flat Rate')),
                DropdownMenuItem(value: 'Percentage', child: Text('Percentage (%)')),
              ],
              onChanged: (v) { if (v != null) setState(() => discountType = v); },
            ),
            if (discountType != 'None') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: discC,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: discountType == 'Percentage' ? 'Discount %' : 'Discount ($curr)',
                    border: const OutlineInputBorder()
                ),
              ),
            ],
          ], // FIXED: Added the missing closing bracket and comma
        ])),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              final paidAmt = double.tryParse(payC.text) ?? 0.0;
              final discAmt = isBadDebtWriteOff ? 0.0 : _calculateDiscountAmount(absBalance);
              if (paidAmt + discAmt > absBalance + 0.01) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Total amount cannot exceed the balance.')));
                return;
              }
              Navigator.pop(context, {
                'amount': paidAmt.toString(),
                'method': method,
                'discount': discAmt.toString(),
                'isBadDebt': isBadDebtWriteOff.toString(),
              });
            }
          },
          child: Text(isRefund ? 'Confirm Refund' : 'Save Payment'),
        ),
      ],
    );
  }
}

// =================================================
// Payment Ledger Screen
// =================================================
class PaymentLedgerScreen extends StatefulWidget {
  final int? initialOrderId;
  final int? initialFallbackRentalId;
  final String? initialDisplayDocNumber; // NEW: FY-compliant document number
  final int initialTabIndex;
  const PaymentLedgerScreen({
    super.key,
    this.initialOrderId,
    this.initialFallbackRentalId,
    this.initialDisplayDocNumber,
    this.initialTabIndex = 0,
  });
  @override
  State<PaymentLedgerScreen> createState() => _PaymentLedgerScreenState();
}

class _PaymentLedgerScreenState extends State<PaymentLedgerScreen> {
  List<RentalGroup> _ledger = [];
  String _filterMode = kLedgerFilterOptions.first;
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _debounce;

  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;

  double _totalDue = 0.0;
  double _totalRefund = 0.0;
  int _totalCount = 0;

  late final int _initialTabIndex;
  int? _scopedOrderId;
  int? _scopedFallbackRentalId;
  String? _displayDocNumber;

  @override
  void initState() {
    super.initState();
    // Accept only valid tab indexes: 0 = OUTSTANDING, 1 = HISTORY.
    _initialTabIndex = widget.initialTabIndex < 0 ? 0 : (widget.initialTabIndex > 1 ? 1 : widget.initialTabIndex);
    _scopedOrderId = widget.initialOrderId;
    _scopedFallbackRentalId = widget.initialFallbackRentalId;
    _displayDocNumber = widget.initialDisplayDocNumber;
    _scrollCtrl.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      _fetchPage();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _offset = 0; _hasMore = true; _ledger = []; });
    try {
      // Load summary first, then append page data using the same scoped/search params.
      final totals = await DatabaseHelper.getLedgerTotals(
        filterMode: _filterMode,
        search: _searchCtrl.text,
        orderId: _scopedOrderId,
        fallbackRentalId: _scopedFallbackRentalId,
      );
      if (!mounted) return;
      setState(() {
        _totalDue = totals['totalDue'] ?? 0.0;
        _totalRefund = totals['totalRefund'] ?? 0.0;
        _totalCount = (totals['count'] ?? 0).toInt();
      });

      await _fetchPage();
    } catch (e, st) {
      debugPrint('Ledger load failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _totalDue = 0.0;
        _totalRefund = 0.0;
        _totalCount = 0;
        _hasMore = false;
        _isLoadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load ledger: $e')));
    }
  }

  Future<void> _fetchPage() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      // Pagination is applied after filtering to keep list/totals aligned.
      final newGroups = await DatabaseHelper.getPaginatedLedgerGroups(
          offset: _offset,
          limit: _limit,
          filterMode: _filterMode,
          search: _searchCtrl.text,
          orderId: _scopedOrderId,
          fallbackRentalId: _scopedFallbackRentalId
      );

      if (!mounted) return;
      setState(() {
        if (newGroups.length < _limit) _hasMore = false;
        _ledger.addAll(newGroups);
        _offset += newGroups.length;
        _isLoadingMore = false;
      });
    } catch (e, st) {
      debugPrint('Ledger page load failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        _hasMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load records: $e')));
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _settleGroup(RentalGroup group) async {
    final isRefund   = group.balance < 0;
    final absBalance = group.balance.abs();
    final messenger  = ScaffoldMessenger.of(context);
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _SettleGroupDialog(group: group),
    );
    if (result == null || !mounted) return;

    final amount = double.parse(result['amount']!);
    final method = result['method']!;
    final discount = double.parse(result['discount']!);
    final isBadDebt = result['isBadDebt'] == 'true';
    final isFull = (amount + discount) >= absBalance - 0.01;
    final adjustedAmount = isRefund ? -amount : amount;

    if (isBadDebt) {
      // Fiscal Note: Writing off debt clears the ledger balance and moves the loss to the Bad Debt module.
      await DatabaseHelper.writeOffBadDebt(
        group.items.first['id'] as int,
        amount,
        isFull ? group.items.map((i) => i['id'] as int).toList() : [],
      );
      if (!mounted) return;
      _load();
      messenger.showSnackBar(SnackBar(content: Text(isFull ? 'Balance written off as bad debt. Invoice closed.' : 'Partial bad debt written off.')));
    } else {
      await DatabaseHelper.addPaymentToRentalGroup(
          group.items.first['id'] as int,
          adjustedAmount,
          isFull,
          group.items.map((i) => i['id'] as int).toList(),
          paymentMethod: method,
          discountAmount: discount
      );
      if (!mounted) return;
      _load();
      messenger.showSnackBar(SnackBar(content: Text(isFull
          ? (isRefund ? 'Refund recorded. Invoice settled.' : 'Invoice marked as fully paid & settled.')
          : (isRefund ? 'Partial refund recorded.' : 'Partial payment recorded.'))));
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    initialIndex: _initialTabIndex,
    child: Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TabBar(
          tabs: const [
            Tab(text: 'OUTSTANDING'),
            Tab(text: 'HISTORY'),
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
      body: TabBarView(
        children: [
          _buildLedgerTab(),
          // Rebuild history tab when scoped invoice changes from navigation context.
          PaymentHistoryScreen(
            key: ValueKey('history_${_scopedOrderId ?? 'n'}_${_scopedFallbackRentalId ?? 'n'}'),
            isTab: true,
            initialOrderId: _scopedOrderId,
            initialFallbackRentalId: _scopedFallbackRentalId,
            initialDisplayDocNumber: _displayDocNumber, // NEW: Pass the doc number down to history
          ),
        ],
      ),
    ),
  );

// =================================================
// Outstanding Tab UI
// =================================================
  Widget _buildLedgerTab() => Column(children: [
    if (_scopedOrderId != null || _scopedFallbackRentalId != null)
      Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            const Icon(Icons.link, size: 16, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _displayDocNumber != null
                    ? 'Showing Outstanding for $_displayDocNumber'
                    : 'Showing Outstanding for Invoice #${_scopedOrderId ?? _scopedFallbackRentalId}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    Padding(
      padding: EdgeInsets.fromLTRB(12, (_scopedOrderId != null || _scopedFallbackRentalId != null) ? 8 : 12, 12, 0),
      child: TextField(
        controller: _searchCtrl,
        enabled: _scopedOrderId == null && _scopedFallbackRentalId == null,
        decoration: InputDecoration(
          hintText: _scopedOrderId != null ? 'Filtered by ID' : 'Search customer, phone, or invoice...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
            if (_searchCtrl.text.isNotEmpty)
              IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _load(); }),
            PopupMenuButton<String>(
              icon: Stack(clipBehavior: Clip.none, children: [
                Icon(Icons.filter_list, color: _filterMode != kLedgerFilterOptions.first ? Colors.amber : null),
                if (_filterMode != kLedgerFilterOptions.first) Positioned(
                  right: -2, top: -2,
                  child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)),
                ),
              ]),
              tooltip: 'Filter by',
              initialValue: _filterMode,
              onSelected: (v) { setState(() { _filterMode = v; _load(); }); },
              itemBuilder: (_) => kLedgerFilterOptions.map((opt) => PopupMenuItem(
                value: opt,
                child: Row(children: [
                  Icon(_filterMode == opt ? Icons.radio_button_checked : Icons.radio_button_off, size: 18, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(opt),
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
                  Text('Total Due', style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color)),
                  const SizedBox(height: 2),
                  Text(formatMoney(_totalDue), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Refunds', style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color)),
                  const SizedBox(height: 2),
                  Text(formatMoney(_totalRefund), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            ),
            Text('$_totalCount inv', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
          ],
        ),
      ),
    ),
    Expanded(child: _ledger.isEmpty && !_isLoadingMore
        ? Center(child: Text(
        _scopedOrderId != null ? 'Invoice #$_scopedOrderId is settled or not found.' :
        _filterMode == 'Amount Due' ? 'No pending collections.' :
        _filterMode == 'Refund Due' ? 'No pending refunds.' :
        'All returned invoices are settled!',
        style: const TextStyle(fontSize: 16, color: Colors.green)))
        : RefreshIndicator(onRefresh: _load, child: ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: _ledger.length + (_hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _ledger.length) return const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator()));
        final g = _ledger[i];
        final isRefund = g.balance < 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(side: BorderSide(color: isRefund ? Colors.green : Colors.orange), borderRadius: BorderRadius.circular(12)),
          child: Padding(padding: appSettingsNotifier.cardPadding, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(g.contractor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
              if (g.orderId != null) Text(g.invoiceNumber.isNotEmpty ? g.invoiceNumber : (g.proformaNumber.isNotEmpty ? g.proformaNumber : 'ORD-${g.orderId}'), style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontWeight: FontWeight.w500)),
            ]),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Out: ${DatabaseHelper.formatDateString(g.checkoutDate)}', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 14)),
              if (g.isCancelled) Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.red.withValues(alpha: 0.5), width: 0.8)),
                child: const Text('CANCELLED INVOICE', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ]),
            const Divider(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Billed:'), Text(formatMoney(g.calculateTotalCost()), style: TextStyle(decoration: g.isCancelled ? TextDecoration.lineThrough : null))]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Paid:'), Text('- ${formatMoney(g.advance)}')]),
            if (g.discount > 0) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Discount Applied:'), Text('- ${formatMoney(g.discount)}')]),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(isRefund ? 'Refund Due:' : 'Amount Due:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(formatMoney(g.balance, absolute: true), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isRefund ? Colors.green : Colors.orange)),
            ]),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              icon: Icon(isRefund ? Icons.undo : Icons.payment),
              label: Text(isRefund ? 'Record Refund/Discount' : 'Record Payment/Discount'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isRefund ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                foregroundColor: isRefund ? Colors.greenAccent : Colors.orangeAccent,
              ),
              onPressed: () => _settleGroup(g),
            )),
          ])),
        );
      },
    )),
    ),
  ]);
}

// =================================================
// Payment History Screen
// =================================================
class PaymentHistoryScreen extends StatefulWidget {
  final int? initialOrderId;
  final int? initialFallbackRentalId;
  final String? initialDisplayDocNumber; // NEW: FY-compliant document number
  final bool isTab;
  const PaymentHistoryScreen({
    super.key,
    this.initialOrderId,
    this.initialFallbackRentalId,
    this.initialDisplayDocNumber,
    this.isTab = false,
  });
  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _filterMode = 'All';
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];
  double _totalPayments = 0.0;
  double _totalRefunds = 0.0;
  late final int? _scopedOrderId;
  late final int? _scopedFallbackRentalId;
  late final String? _displayDocNumber;

  @override
  void initState() {
    super.initState();
    _scopedOrderId = widget.initialOrderId;
    _scopedFallbackRentalId = widget.initialFallbackRentalId;
    _displayDocNumber = widget.initialDisplayDocNumber;
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _load() async {
    final rows = await DatabaseHelper.getPaymentHistory(
      search: _searchCtrl.text,
      type: _filterMode,
      orderId: _scopedOrderId,
      fallbackRentalId: _scopedFallbackRentalId,
    );
    double inAmt = 0.0;
    double outAmt = 0.0;
    // Fiscal Note: Accurately separating inbound cash flows from outbound refunds for ledger reconciliation.
    for (final r in rows) {
      final a = (r['amount'] as num?)?.toDouble() ?? 0.0;
      if (a >= 0) {
        inAmt += a;
      } else {
        outAmt += a.abs();
      }
    }
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _totalPayments = inAmt;
      _totalRefunds = outAmt;
      _loading = false;
    });
  }

  String _formatTimeText(String paidAt, String fallbackDate) {
    final raw = paidAt.trim().isNotEmpty ? paidAt.trim() : fallbackDate.trim();
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return formatTimeByPreference(dt);
    } catch (_) {
      return '';
    }
  }

  String _formatDateText(String paidAt, String fallbackDate) {
    final raw = paidAt.trim().isNotEmpty ? paidAt.trim() : fallbackDate.trim();
    if (raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      return DatabaseHelper.formatDateFromDt(dt);
    } catch (_) {
      return DatabaseHelper.formatDateString(raw);
    }
  }

  Widget _tag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
    ),
    child: Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.isTab ? null : AppBar(title: const Text('Payment History')),
    body: Column(
      children: [
        if (_scopedOrderId != null || _scopedFallbackRentalId != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.45)),
            ),
            child: Row(
              children: [
                const Icon(Icons.link, size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _displayDocNumber != null
                        ? 'Showing Payments History for $_displayDocNumber'
                        : (_scopedOrderId != null
                        ? 'Showing payments History for Invoice #$_scopedOrderId'
                        : 'Showing payments History for linked record #$_scopedFallbackRentalId'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(12, (_scopedOrderId != null || _scopedFallbackRentalId != null) ? 8 : 12, 12, 0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search customer, method, or invoice...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                if (_searchCtrl.text.isNotEmpty)
                  IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _load(); }),
                PopupMenuButton<String>(
                  icon: Stack(clipBehavior: Clip.none, children: [
                    Icon(Icons.filter_list, color: _filterMode != 'All' ? Colors.amber : null),
                    if (_filterMode != 'All') Positioned(
                      right: -2, top: -2,
                      child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)),
                    ),
                  ]),
                  tooltip: 'Filter by',
                  initialValue: _filterMode,
                  onSelected: (v) {
                    setState(() {
                      _filterMode = v;
                      _loading = true;
                    });
                    _load();
                  },
                  itemBuilder: (_) => ['All', 'Payment', 'Refund'].map((mode) => PopupMenuItem(
                    value: mode,
                    child: Row(children: [
                      Icon(_filterMode == mode ? Icons.radio_button_checked : Icons.radio_button_off, size: 18, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(mode),
                    ]),
                  )).toList(),
                ),
              ]),
            ),
            onChanged: _onSearch,
          ),
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_rows.isEmpty)
          const Expanded(child: Center(child: Text('No payment history found.')))
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                children: [
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: appSettingsNotifier.cardPadding,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Payments', style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color)),
                                const SizedBox(height: 2),
                                Text(formatMoney(_totalPayments), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Refunds', style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color)),
                                const SizedBox(height: 2),
                                Text(formatMoney(_totalRefunds), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                              ],
                            ),
                          ),
                          Text('${_rows.length} txn', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
                        ],
                      ),
                    ),
                  ),
                  ..._rows.map((r) {
                    final amount = (r['amount'] as num?)?.toDouble() ?? 0.0;
                    final isRefund = amount < 0;
                    final customer = (r['customerName'] as String? ?? '').trim();
                    final method = (r['method'] as String? ?? '').trim();
                    final orderId = r['orderId'] as int?;
                    final fallbackId = r['fallbackRentalId'] as int?;
                    final invNum = r['invoiceNumber'] as String? ?? '';
                    final profNum = r['proformaNumber'] as String? ?? '';

                    final ref = orderId != null
                        ? (invNum.isNotEmpty ? invNum : (profNum.isNotEmpty ? profNum : 'Invoice #$orderId'))
                        : fallbackId != null
                        ? 'Record #$fallbackId'
                        : 'Record';
                    final timeText = _formatTimeText(
                      (r['paidAt'] as String? ?? ''),
                      (r['baseDate'] as String? ?? ''),
                    );
                    final dateText = _formatDateText(
                      (r['paidAt'] as String? ?? ''),
                      (r['baseDate'] as String? ?? ''),
                    );
                    final isCancelled = (r['isCancelled'] as int? ?? 0) == 1;
                    final showTime = appSettingsNotifier.showPaymentHistoryTime;
                    final refLine = showTime && timeText.isNotEmpty
                        ? '$ref  |  $dateText  |  $timeText'
                        : '$ref  |  $dateText';
                    final amountColor = isRefund ? Colors.orange : Colors.green;
                    final isAdvance = !isRefund && (r['id'] == r['firstLogId']);

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
                                CircleAvatar(
                                  radius: 13.5,
                                  backgroundColor: amountColor.withValues(alpha: 0.15),
                                  child: Icon(isRefund ? Icons.undo : Icons.payments, color: amountColor, size: 14.5),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(customer.isEmpty ? 'Unknown Customer' : customer, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text(
                                        refLine,
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.visible,
                                        style: TextStyle(fontSize: 14.0, color: Theme.of(context).textTheme.bodySmall?.color),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${isRefund ? '-' : '+'}${formatMoney(amount, absolute: true)}',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: amountColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _tag(isRefund ? 'Refund' : (isAdvance ? 'Adv/Security' : 'Payment'), amountColor),
                                _tag(method.isEmpty ? 'Method: N/A' : 'Method: $method', Colors.blueGrey),
                                if (isCancelled) _tag('Cancelled Invoice', Colors.red),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

// =================================================
// Losses & Bad Debt Screen
// =================================================
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
    final formKey = GlobalKey<FormState>();

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
              onChanged: (v) { if (v != null) method = v; },
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, {'amount': double.parse(payC.text), 'method': method});
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
        isFullyRecovered
    );

    if (!mounted) return;
    _load();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bad debt recovery recorded successfully.')));
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

// =================================================
// Financial Reports Screen
// =================================================
class FinancialReportsScreen extends StatefulWidget {
  const FinancialReportsScreen({super.key});
  @override
  State<FinancialReportsScreen> createState() => _FinancialReportsScreenState();
}

class _FinancialReportsScreenState extends State<FinancialReportsScreen> {
  bool _loading = true;

  // A/R Aging Data
  double _ar0to30 = 0.0;
  double _ar31to60 = 0.0;
  double _ar61to90 = 0.0;
  double _ar90Plus = 0.0;
  double _totalAR = 0.0;

  // Tax Liability Data
  Map<String, dynamic> _bizInfo = {};
  double _totalPaymentsCollectedFY = 0.0;
  double _taxLiabilityFY = 0.0;
  String _fyString = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = await DatabaseHelper.getDatabase();
    final bizInfo = await DatabaseHelper.getBusinessInfo();

    // 1. Calculate A/R Aging
    final allGroups = groupRentalsByInvoice(await DatabaseHelper.getAllRentals());
    final outstanding = allGroups.where((g) => g.isFullyReturned && !g.isSettled && g.balance > 0).toList();

    double ar0 = 0, ar31 = 0, ar61 = 0, ar90 = 0, totalAr = 0;
    final now = DateTime.now();

    for (final g in outstanding) {
      final checkoutDt = DateTime.tryParse(g.checkoutDate) ?? now;
      final daysOld = now.difference(checkoutDt).inDays;
      final bal = g.balance;

      totalAr += bal;
      if (daysOld <= 30) { ar0 += bal; }
      else if (daysOld <= 60) { ar31 += bal; }
      else if (daysOld <= 90) { ar61 += bal; }
      else { ar90 += bal; }
    }

    // 2. Calculate Cash-Basis Tax Liability for Current FY
    final fyStartMonth = bizInfo['fyStartMonth'] as int? ?? 4;
    final currentYear = now.year;
    final isPastStartMonth = now.month >= fyStartMonth;

    final fyStartDate = DateTime(
        isPastStartMonth ? currentYear : currentYear - 1,
        fyStartMonth,
        1
    );

    _fyString = '${fyStartDate.year}-${fyStartDate.year + 1}';

    // Sum payments collected strictly within this FY
    final payments = await db.rawQuery(
        'SELECT SUM(amount) as total FROM payment_logs WHERE paidAt >= ? AND amount > 0',
        [DatabaseHelper.isoDate(fyStartDate)]
    );

    final totalCollected = (payments.first['total'] as num?)?.toDouble() ?? 0.0;

    // Tax Extraction Logic (Assumes payments collected include tax)
    final taxRate = (bizInfo['taxRate'] as num?)?.toDouble() ?? 0.0;
    final taxType = (bizInfo['taxType'] as String? ?? 'none');
    double taxLiability = 0.0;

    if (taxType != 'none' && taxRate > 0) {
      // Formula: Tax = Total Paid - (Total Paid / (1 + (Rate/100)))
      taxLiability = totalCollected - (totalCollected / (1 + (taxRate / 100.0)));
    }

    if (!mounted) return;
    setState(() {
      _ar0to30 = ar0;
      _ar31to60 = ar31;
      _ar61to90 = ar61;
      _ar90Plus = ar90;
      _totalAR = totalAr;

      _bizInfo = bizInfo;
      _totalPaymentsCollectedFY = totalCollected;
      _taxLiabilityFY = taxLiability;
      _loading = false;
    });
  }

  Widget _buildAgingIndicator(Color color, String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 16, height: 16, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
          Text(formatMoney(amount), style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: TabBar(
            tabs: const [
              Tab(text: 'A/R AGING'),
              Tab(text: 'TAX LIABILITY'),
            ],
            indicator: BoxDecoration(borderRadius: BorderRadius.circular(24), color: Colors.black12),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.black54,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
          children: [
            // TAB 1: Accounts Receivable Aging
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Accounts Receivable Aging Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Unpaid settled invoices categorized by age.', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                  const SizedBox(height: 24),

                  if (_totalAR <= 0)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('Outstanding! Your Accounts Receivable is \$0.00.', style: TextStyle(color: Colors.green, fontSize: 16)),
                    ))
                  else ...[
                    SizedBox(
                      height: 250,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 60,
                          sections: [
                            if (_ar0to30 > 0) PieChartSectionData(color: Colors.green, value: _ar0to30, title: '', radius: 50),
                            if (_ar31to60 > 0) PieChartSectionData(color: Colors.amber, value: _ar31to60, title: '', radius: 50),
                            if (_ar61to90 > 0) PieChartSectionData(color: Colors.orange, value: _ar61to90, title: '', radius: 50),
                            if (_ar90Plus > 0) PieChartSectionData(color: Colors.red, value: _ar90Plus, title: '', radius: 50),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildAgingIndicator(Colors.green, 'Current (0-30 Days)', _ar0to30),
                            const Divider(),
                            _buildAgingIndicator(Colors.amber, 'Overdue (31-60 Days)', _ar31to60),
                            const Divider(),
                            _buildAgingIndicator(Colors.orange, 'Critical (61-90 Days)', _ar61to90),
                            const Divider(),
                            _buildAgingIndicator(Colors.red, 'High Risk (90+ Days)', _ar90Plus),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('TOTAL A/R:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(formatMoney(_totalAR), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]
                ],
              ),
            ),

            // TAB 2: Tax Liability
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Estimated Tax Liability (Cash Basis)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Based on payments received in FY $_fyString.', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                  const SizedBox(height: 24),

                  if (_bizInfo['taxType'] == 'none' || _bizInfo['taxType'] == null)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('Taxes are currently disabled in Business Info.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ))
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Tax Configuration:', style: TextStyle(fontWeight: FontWeight.bold)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                                  child: Text('${(_bizInfo['taxType'] as String).toUpperCase()} @ ${_bizInfo['taxRate']}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const Divider(height: 32),
                            const Text('Total Payments Collected (FY)'),
                            Text(formatMoney(_totalPaymentsCollectedFY), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                            const SizedBox(height: 24),
                            const Text('Estimated Tax Remittance Due'),
                            Text(formatMoney(_taxLiabilityFY), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withValues(alpha: 0.5))),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.info_outline, size: 16, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text('This is a cash-basis estimation extracted from gross payments received. Consult your CPA for final filings.', style: TextStyle(fontSize: 12, color: Colors.orange)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================
// Expense Tracking Screen
// =================================================
class ExpenseTrackingScreen extends StatefulWidget {
  const ExpenseTrackingScreen({super.key});
  @override
  State<ExpenseTrackingScreen> createState() => _ExpenseTrackingScreenState();
}

class _ExpenseTrackingScreenState extends State<ExpenseTrackingScreen> {
  List<Map<String, dynamic>> _expenses = [];
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  double _totalExpenses = 0.0;
  String _sortMode = 'Date (Newest)';

  final List<String> _expenseSortOptions = ['Date (Newest)', 'Date (Oldest)', 'Highest Amount'];

  final List<String> _expenseCategories = [
    'Fuel & Transport', 'Repairs & Maintenance', 'Warehouse Rent',
    'Utilities', 'Payroll', 'Advertising', 'Office Supplies', 'Other'
  ];

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _searchCtrl.dispose(); _debounce?.cancel(); super.dispose(); }

  Future<void> _load() async {
    final rawData = await DatabaseHelper.getExpenses(search: _searchCtrl.text);

    // Create a mutable copy to apply our custom sorting
    List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(rawData);

    // Apply Sorting Rules for Tax/Auditing purposes
    if (_sortMode == 'Date (Newest)') {
      data.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    } else if (_sortMode == 'Date (Oldest)') {
      data.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    } else if (_sortMode == 'Highest Amount') {
      data.sort((a, b) => (b['amount'] as num).compareTo(a['amount'] as num));
    }

    double total = 0.0;
    for (var row in data) {
      total += (row['amount'] as num).toDouble();
    }
    if (!mounted) return;
    setState(() { _expenses = data; _totalExpenses = total; });
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _showExpenseDialog() async {
    final formKey = GlobalKey<FormState>();
    final amountC = TextEditingController();
    final vendorC = TextEditingController();
    final notesC  = TextEditingController();
    String category = _expenseCategories.first;
    String method   = kPaymentMethods.first;
    DateTime selectedDate = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: const Text('Log Business Expense'),
          content: SingleChildScrollView(
            child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: amountC,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Amount ($curr) *', border: const OutlineInputBorder()),
                validator: (v) {
                  final val = double.tryParse(v ?? '');
                  if (val == null || val <= 0) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: _expenseCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) { if (v != null) setSt(() => category = v); },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Paid Via', border: OutlineInputBorder()),
                items: kPaymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) { if (v != null) setSt(() => method = v); },
              ),
              const SizedBox(height: 12),
              TextFormField(controller: vendorC, decoration: const InputDecoration(labelText: 'Vendor / Payee', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextFormField(controller: notesC, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()), maxLines: 2),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Text('Date: ${DatabaseHelper.formatDateFromDt(selectedDate)}')),
                TextButton(
                  onPressed: () async {
                    final p = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime.now());
                    if (p != null) setSt(() => selectedDate = p);
                  },
                  child: const Text('Change'),
                ),
              ]),
            ])),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(ctx, true); },
              child: const Text('Save Expense'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await DatabaseHelper.insertExpense(
        DatabaseHelper.isoDate(selectedDate),
        category,
        double.parse(amountC.text),
        method,
        vendorC.text.trim(),
        notesC.text.trim(),
      );
      _load();
    }
    amountC.dispose(); vendorC.dispose(); notesC.dispose();
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Permanently delete this expense record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await DatabaseHelper.deleteExpense(id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Business Expenses')),
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
                      Icon(Icons.filter_list, color: _sortMode != 'Date (Newest)' ? Colors.amber : null),
                      if (_sortMode != 'Date (Newest)') Positioned(
                        right: -2, top: -2,
                        child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)),
                      ),
                    ]),
                    tooltip: 'Sort by',
                    initialValue: _sortMode,
                    onSelected: (v) { setState(() { _sortMode = v; _load(); }); },
                    itemBuilder: (_) => _expenseSortOptions.map((opt) => PopupMenuItem(
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
                    Text('Total Expenses', style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color)),
                    const SizedBox(height: 2),
                    Text(formatMoney(_totalExpenses), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  ],
                ),
              ),
              Text('${_expenses.length} txn', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
            ],
          ),
        ),
      ),
      Expanded(
        child: _expenses.isEmpty
            ? const Center(child: Text('No expenses logged yet.'))
            : ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _expenses.length,
          itemBuilder: (_, i) {
            final e = _expenses[i];
            final amount = (e['amount'] as num).toDouble();
            final vendor = (e['vendor'] as String? ?? '').trim();
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: appSettingsNotifier.cardPadding,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start, // Absolute top alignment
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                      child: const Icon(Icons.receipt, color: Colors.redAccent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: Text(e['category'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                              Text(formatMoney(amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (vendor.isNotEmpty) Text('Vendor: $vendor', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('Date: ${DatabaseHelper.formatDateString(e['date'])}  |  Via: ${e['paymentMethod']}', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                          if ((e['notes'] as String).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('Note: ${e['notes']}', style: TextStyle(fontStyle: FontStyle.italic, color: Theme.of(context).textTheme.bodySmall?.color)),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 28, // Constrains ripple effect to match UniversalRentalCard
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20),
                        padding: EdgeInsets.zero,
                        tooltip: 'Options',
                        onSelected: (val) {
                          if (val == 'delete') _delete(e['id'] as int);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
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
    ]),
    floatingActionButton: FloatingActionButton(
      onPressed: _showExpenseDialog,
      tooltip: 'Log Expense',
      backgroundColor: Colors.redAccent,
      foregroundColor: Colors.white,
      child: const Icon(Icons.add),
    ),
  );
}

// =================================================
// Inventory Tab
// =================================================

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

  Future<void> _showItemDialog({Map<String, dynamic>? item}) async {
    final isEdit    = item != null;
    final editItem  = item ?? {};
    final formKey   = GlobalKey<FormState>();
    final nameC     = TextEditingController(text: (editItem['name']     ?? '') as String);
    final totalC    = TextEditingController(text: isEdit ? (editItem['total'] ?? '').toString() : '');
    final categoryC = TextEditingController(text: (editItem['category'] ?? 'General') as String);
    final notesC    = TextEditingController(text: (editItem['notes']    ?? '') as String);

    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text(isEdit ? 'Edit Material' : 'Add Material / Equipment'),
      content: SingleChildScrollView(child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: nameC,  decoration: const InputDecoration(labelText: 'Name *'),
            validator: (v) => v==null||v.trim().isEmpty ? 'Name is required' : null),
        TextFormField(controller: totalC, decoration: const InputDecoration(labelText: 'Total Stock *'),
            keyboardType: TextInputType.number,
            validator: (v) { final n = int.tryParse(v??''); return (n==null||n<=0) ? 'Must be a valid positive number' : null; }),
        TextFormField(controller: categoryC, decoration: const InputDecoration(labelText: 'Category')),
        TextFormField(controller: notesC,    decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        if (isEdit) TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () async {
            final nav = Navigator.of(ctx); final messenger = ScaffoldMessenger.of(ctx);
            final ok = await _confirmDialog(ctx, title:'Delete Item', message:'Delete this item? Only possible if no active rentals exist.');
            if (!ok) return;
            try { await DatabaseHelper.deleteItem(editItem['id'] as int); nav.pop(); }
            catch (e) { messenger.showSnackBar(SnackBar(content: Text('Delete failed: $e'))); }
          },
          child: const Text('Delete'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            final nav = Navigator.of(ctx);
            final cat = categoryC.text.trim().isEmpty ? 'General' : categoryC.text.trim();
            if (isEdit) { await DatabaseHelper.updateItem(editItem['id'] as int, nameC.text.trim(), int.parse(totalC.text), cat, notesC.text.trim()); }
            else        { await DatabaseHelper.insertItem(nameC.text.trim(), int.parse(totalC.text), cat, notesC.text.trim()); }
            nav.pop();
          },
          child: const Text('Save'),
        ),
      ],
    ));
    nameC.dispose(); totalC.dispose(); categoryC.dispose(); notesC.dispose();
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
              width: 28,
              child: Tooltip(
                message: 'Edit',
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _showItemDialog(item: it),
                  child: const Align(
                    alignment: Alignment.centerRight,
                    child: Icon(Icons.edit_outlined, size: 20),
                  ),
                ),
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

// =================================================
// Advanced / Partial Return Dialog
// =================================================
class _PartialReturnDialog extends StatefulWidget {
  final List<Map<String, dynamic>> activeItems;
  final DateTime checkoutDate;
  const _PartialReturnDialog({required this.activeItems, required this.checkoutDate});
  @override
  State<_PartialReturnDialog> createState() => _PartialReturnDialogState();
}

class _PartialReturnDialogState extends State<_PartialReturnDialog> {
  final Map<int, TextEditingController> _goodCtrl = {};
  final Map<int, TextEditingController> _lostCtrl = {};
  final Map<int, TextEditingController> _penaltyCtrl = {};
  DateTime _returnDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    for (final r in widget.activeItems) {
      final id = r['id'] as int;
      _goodCtrl[id] = TextEditingController(text: r['qty'].toString()); // Default to all good
      _lostCtrl[id] = TextEditingController(text: '0');
      _penaltyCtrl[id] = TextEditingController(text: '0');
    }
  }

  @override
  void dispose() {
    for (final c in [..._goodCtrl.values, ..._lostCtrl.values, ..._penaltyCtrl.values]) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaWidth = MediaQuery.of(context).size.width;
    return AlertDialog(
      title: const Text('Advanced Return'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 24.0),
      content: SizedBox(
        width: mediaWidth > 600 ? 600 : mediaWidth * 0.95,
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Specify returned quantities and any damage penalties.'),
          const SizedBox(height: 16),
          ...widget.activeItems.map((r) {
            final id = r['id'] as int;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r['itemName']} (Rented: ${r['qty']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(flex: 3, child: TextField(controller: _goodCtrl[id], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Good', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12)))),
                    const SizedBox(width: 8),
                    Expanded(flex: 3, child: TextField(controller: _lostCtrl[id], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Damaged', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12)))),
                    const SizedBox(width: 8),
                    Expanded(flex: 4, child: TextField(controller: _penaltyCtrl[id], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Penalty ($curr)', border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12)))),
                  ]),
                ]),
              ),
            );
          }),
          const Divider(),
          Row(children: [
            Expanded(child: Text('Return Date:\n${DatabaseHelper.formatDateFromDt(_returnDate)}', style: const TextStyle(fontSize: 14))),
            TextButton(
              onPressed: () async { final p = await showDatePicker(context: context, initialDate: _returnDate, firstDate: widget.checkoutDate, lastDate: DateTime(2100)); if (p != null) setState(() => _returnDate = p); },
              child: const Text('Change'),
            ),
          ]),
        ])),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final returns = <Map<String, dynamic>>[];
            final messenger = ScaffoldMessenger.of(context);
            for (final r in widget.activeItems) {
              final id = r['id'] as int;
              final good = int.tryParse(_goodCtrl[id]?.text ?? '0') ?? 0;
              final lost = int.tryParse(_lostCtrl[id]?.text ?? '0') ?? 0;
              final penalty = double.tryParse(_penaltyCtrl[id]?.text ?? '0') ?? 0.0;
              final total = good + lost;

              if (total > (r['qty'] as int)) {
                messenger.showSnackBar(SnackBar(content: Text('Cannot return more than rented for ${r['itemName']}')));
                return;
              }
              if (total > 0) {
                returns.add({'rental': r, 'goodQty': good, 'damagedQty': lost, 'penalty': penalty});
              } else if (penalty > 0) {
                messenger.showSnackBar(const SnackBar(content: Text('You must return at least 1 item to apply a penalty here.')));
                return;
              }
            }
            if (returns.isEmpty) { messenger.showSnackBar(const SnackBar(content: Text('Enter at least one quantity to return'))); return; }
            Navigator.pop(context, {'returns': returns, 'date': DatabaseHelper.isoDate(_returnDate)});
          },
          child: const Text('Confirm Return'),
        ),
      ],
    );
  }
}

// =================================================
// Edit Group Dialog (proper StatefulWidget)
// =================================================
class _EditGroupDialog extends StatefulWidget {
  final RentalGroup group;
  const _EditGroupDialog({required this.group});
  @override
  State<_EditGroupDialog> createState() => _EditGroupDialogState();
}

class _EditGroupDialogState extends State<_EditGroupDialog> {
  late final TextEditingController nameC;
  late final TextEditingController phoneC;
  late final TextEditingController phone2C;
  late final TextEditingController addressC;
  late final TextEditingController advC;
  late final TextEditingController notesC;
  late String editMethod;
  late DateTime selected;

  @override
  void initState() {
    super.initState();
    final g = widget.group;
    nameC    = TextEditingController(text: g.contractor);
    phoneC   = TextEditingController(text: g.phone);
    phone2C  = TextEditingController(text: g.phone2);
    addressC = TextEditingController(text: g.address);
    advC     = TextEditingController(text: g.advance > 0 ? g.advance.toStringAsFixed(2) : '');
    notesC   = TextEditingController(text: g.notes);
    editMethod = g.paymentMethod.isNotEmpty ? g.paymentMethod : kPaymentMethods.first;
    try { selected = DateTime.parse(g.checkoutDate); } catch (_) { selected = DateTime.now(); }
  }

  @override
  void dispose() {
    nameC.dispose(); phoneC.dispose(); phone2C.dispose();
    addressC.dispose(); advC.dispose(); notesC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    return AlertDialog(
      title: Text(g.isGroup ? 'Edit Order #${g.orderId}' : 'Edit Rental'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (g.isGroup) Padding(padding: const EdgeInsets.only(bottom: 8),
            child: Text('Editing shared details for ${g.items.length} records in this order.',
                style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12))),
        TextField(controller: nameC,    decoration: const InputDecoration(labelText: 'Contractor Name')),
        TextField(controller: phoneC,   decoration: const InputDecoration(labelText: 'Primary Phone'),   keyboardType: TextInputType.phone),
        TextField(controller: phone2C,  decoration: const InputDecoration(labelText: 'Alternate Phone'), keyboardType: TextInputType.phone),
        TextField(controller: addressC, decoration: const InputDecoration(labelText: 'Site Address')),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: TextField(controller: advC, decoration: InputDecoration(labelText: 'Advance/Security ($curr)', isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
          const SizedBox(width: 8),
          SizedBox(width: 130, child: DropdownButtonFormField<String>(
            initialValue: editMethod,
            decoration: const InputDecoration(labelText: 'Payment', isDense: true),
            items: kPaymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (v) { if (v != null) setState(() => editMethod = v); },
          )),
        ]),
        TextField(controller: notesC, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('Checkout: ${DatabaseHelper.formatDateFromDt(selected)}')),
          TextButton(
            onPressed: () async {
              final p = await showDatePicker(context: context, initialDate: selected, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (p != null) setState(() => selected = p);
            },
            child: const Text('Change'),
          ),
        ]),
      ])),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () async {
            final nav = Navigator.of(context);
            final messenger = ScaffoldMessenger.of(context);
            final ok = await _confirmDialog(context, title: 'Delete Record', message: 'Permanently delete this entire record? This cannot be undone.');
            if (!ok || !context.mounted) return;
            try {
              await DatabaseHelper.deleteRentalGroup(g.items);
              nav.pop();
            } catch (e) { messenger.showSnackBar(SnackBar(content: Text('Delete failed: $e'))); }
          },
          child: const Text('Delete'),
        ),
        ElevatedButton(
          onPressed: () async {
            final nav = Navigator.of(context);
            final messenger = ScaffoldMessenger.of(context);
            try {
              await DatabaseHelper.updateRentalGroup(
                g,
                contractor: nameC.text.trim(),
                phone: phoneC.text.trim(),
                phone2: phone2C.text.trim(),
                address: addressC.text.trim(),
                advanceDeposit: double.tryParse(advC.text) ?? 0.0,
                paymentMethod: editMethod,
                checkoutDate: DatabaseHelper.isoDate(selected),
                notes: notesC.text.trim(),
              );
              nav.pop();
            } catch (e) { messenger.showSnackBar(SnackBar(content: Text('Save failed: $e'))); }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// =================================================
// Active Rentals Tab
// =================================================
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
    await DatabaseHelper.deleteRentalGroup(group.items);
    if (mounted) _load();
  }

  Future<void> _openProformaPdf(int orderId) async {
    final size = await pickPdfSize(context);
    if (size == null || !mounted) return;
    final bytes = await DatabaseHelper.generatePdfProformaForOrder(orderId, pageSize: size);
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Proforma Preview')), body: PdfPreview(build: (_) async => bytes))));
  }

  Future<void> _editGroup(RentalGroup group) async {
    await showDialog<void>(context: context, builder: (_) => _EditGroupDialog(group: group));
    if (mounted) _load();
  }

  Future<void> _handleReturn(RentalGroup group) async {
    final messenger = ScaffoldMessenger.of(context);
    DateTime checkoutDt; try { checkoutDt = DateTime.parse(group.checkoutDate); } catch (_) { checkoutDt = DateTime(2000); }
    final action = await showDialog<String>(context: context, builder: (d) => AlertDialog(
      title: const Text('Return Action'),
      content: const Text('Are you returning ALL remaining items, or only a partial return?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d,'cancel'),  child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(d,'partial'), child: const Text('Partial Return')),
        ElevatedButton(onPressed: () => Navigator.pop(d,'full'), child: const Text('Full Return')),
      ],
    ));
    if (action == null || action == 'cancel') return;

    if (action == 'partial') {
      final activeItems = group.items.where((r) => r['returned'] == 0).toList();
      if (activeItems.isEmpty) return;
      if (!mounted) return;
      final result = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => _PartialReturnDialog(activeItems: activeItems, checkoutDate: checkoutDt));
      if (result == null) return;
      try { await DatabaseHelper.returnMultiplePartial(result['returns'] as List<Map<String,dynamic>>, result['date'] as String); if (mounted) _load(); }
      catch (e) { if (mounted) messenger.showSnackBar(SnackBar(content: Text('Return failed: $e'))); }
    } else {
      if (!mounted) return;
      final choice = await showDialog<String?>(context: context, builder: (d) => AlertDialog(
        title: const Text('Full Return Date'), content: const Text('When were the remaining items returned?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d),           child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(d,'pick'),    child: const Text('Pick Date')),
          ElevatedButton(onPressed: () => Navigator.pop(d,'today'), child: const Text('Today')),
        ],
      ));
      if (choice == null) return;
      String returnDate = DatabaseHelper.isoNow();
      if (choice == 'pick') {
        if (!mounted) return;
        final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: checkoutDt, lastDate: DateTime(2100));
        if (picked == null) return;
        returnDate = DatabaseHelper.isoDate(picked);
      }
      try {
        await DatabaseHelper.returnOrderGroup(group.items.where((r) => r['returned'] == 0).toList(), returnDate);
        if (!mounted) return;
        _load();
        messenger.showSnackBar(SnackBar(content: Text(group.balance > 0 ? 'Items returned. Remaining balance sent to Payment Ledger.' : 'Remaining items returned successfully.')));
      } catch (e) { if (mounted) messenger.showSnackBar(SnackBar(content: Text('Return failed: $e'))); }
    }
  }

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
    // Both actions open the unified Transactions screen; selected tab changes by intent.
    // Fiscal Note: We intelligently extract the final invoice number, falling back to proforma,
    // to guarantee the UI ledger perfectly mirrors the generated PDF documents.
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
    final size = await pickPdfSize(context);
    if (size == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Generating PDF...')));
    try {
      final bytes = await DatabaseHelper.generatePdfFinalInvoiceForOrder(orderId, pageSize: size);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Final Invoice Preview')),
          body: PdfPreview(build: (_) async => bytes),
        ),
      ));
    } catch (e) { if (mounted) messenger.showSnackBar(SnackBar(content: Text('Failed: $e'))); }
  }

  Future<void> _editGroup(RentalGroup group) async {
    await showDialog<void>(context: context, builder: (_) => _EditGroupDialog(group: group));
    if (mounted) _load();
  }

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

// =================================================
// Business Info Screen
// =================================================
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

// =================================================
// Customers Management Screen
// =================================================
class CustomersManagementScreen extends StatefulWidget {
  const CustomersManagementScreen({super.key});
  @override
  State<CustomersManagementScreen> createState() => _CustomersManagementScreenState();
}

class _CustomersManagementScreenState extends State<CustomersManagementScreen> {
  List<Map<String, dynamic>> _customers = [];
  Map<int, double> _owedBalances = {}; // Changed to track by ID
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _searchCtrl.dispose(); _debounce?.cancel(); super.dispose(); }

  Future<void> _load() async {
    final data = await DatabaseHelper.getCustomers(search: _searchCtrl.text);
    if (!mounted) return;
    setState(() => _customers = data);
    _loadBalances(data);
  }

  Future<void> _loadBalances(List<Map<String, dynamic>> customers) async {
    final balances = <int, double>{};
    for (final c in customers) {
      final id = c['id'] as int;
      final name = c['name'] as String? ?? '';
      balances[id] = await DatabaseHelper.getCustomerOwedBalance(id, name);
    }
    if (!mounted) return;
    setState(() => _owedBalances = balances);
  }

  Future<void> _makePhoneCall(String p1, String p2) async {
    if (p1.isEmpty && p2.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No phone numbers saved for this customer.')));
      return;
    }

    Future<void> dial(String number) async {
      final cleanNum = number.replaceAll(RegExp(r'[^0-9+]'), '');
      final Uri url = Uri.parse('tel:$cleanNum');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch dialer.')));
      }
    }

    if (p1.isNotEmpty && p2.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Choose number to call'),
          children: [
            ListTile(leading: const Icon(Icons.phone, color: Colors.green), title: Text('Primary: $p1'), onTap: () { Navigator.pop(ctx); dial(p1); }),
            ListTile(leading: const Icon(Icons.phone, color: Colors.green), title: Text('Alternate: $p2'), onTap: () { Navigator.pop(ctx); dial(p2); }),
          ],
        ),
      );
    } else {
      dial(p1.isNotEmpty ? p1 : p2);
    }
  }

  void _onSearch(String _) { _debounce?.cancel(); _debounce = Timer(const Duration(milliseconds: 300), _load); }

  Future<void> _showCustomerDialog({Map<String, dynamic>? existing}) async {
    final isEdit   = existing != null;
    final editData = existing ?? {};
    final formKey  = GlobalKey<FormState>();
    final nameC    = TextEditingController(text: (editData['name']    ?? '') as String);
    final phoneC   = TextEditingController(text: (editData['phone']   ?? '') as String);
    final phone2C  = TextEditingController(text: (editData['phone2']  ?? '') as String);
    final emailC   = TextEditingController(text: (editData['email']   ?? '') as String);
    final addressC = TextEditingController(text: (editData['address'] ?? '') as String);
    final notesC   = TextEditingController(text: (editData['notes']   ?? '') as String);
    final joinedDate = (editData['joinedDate'] as String? ?? '').isNotEmpty
        ? (editData['joinedDate'] as String)
        : DatabaseHelper.isoNow();
    bool isBlacklisted = (editData['isBlacklisted'] as int? ?? 0) == 1;

    final saved = await showDialog<bool>(context: context, builder: (d) => StatefulBuilder(
      builder: (ctx, setSt) => AlertDialog(
        title: Text(isEdit ? 'Edit Customer' : 'Add Customer'),
        content: SingleChildScrollView(child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: nameC,    decoration: const InputDecoration(labelText: 'Name *'),          validator: (v) => v==null||v.trim().isEmpty?'Name is required':null),
          const SizedBox(height: 8),
          TextFormField(controller: phoneC,   decoration: const InputDecoration(labelText: 'Primary Phone'),   keyboardType: TextInputType.phone),
          const SizedBox(height: 8),
          TextFormField(controller: phone2C,  decoration: const InputDecoration(labelText: 'Alternate Phone'), keyboardType: TextInputType.phone),
          const SizedBox(height: 8),
          TextFormField(controller: emailC,   decoration: const InputDecoration(labelText: 'Email Address'),   keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 8),
          TextFormField(controller: addressC, decoration: const InputDecoration(labelText: 'Address')),
          const SizedBox(height: 8),
          TextFormField(controller: notesC,   decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
          if (isEdit) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(Icons.block, color: isBlacklisted ? Colors.red : Colors.grey),
              title: const Text('Blacklist Customer'),
              value: isBlacklisted,
              activeThumbColor: Colors.red,
              onChanged: (v) => setSt(() => isBlacklisted = v),
            ),
          ],
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(d, true); }, child: const Text('Save')),
        ],
      ),
    ));

    final nameVal    = nameC.text.trim();
    final phoneVal   = phoneC.text.trim();
    final phone2Val  = phone2C.text.trim();
    final emailVal   = emailC.text.trim();
    final addressVal = addressC.text.trim();
    final notesVal   = notesC.text.trim();
    nameC.dispose(); phoneC.dispose(); phone2C.dispose(); emailC.dispose(); addressC.dispose(); notesC.dispose();
    if (saved == true) {
      if (isEdit) {
        await DatabaseHelper.updateCustomer(
          editData['id'] as int, nameVal, phoneVal, phone2Val, emailVal, addressVal,
          notes: notesVal, joinedDate: joinedDate, isBlacklisted: isBlacklisted ? 1 : 0,
        );
      } else if (nameVal.isNotEmpty) {
        await DatabaseHelper.insertCustomer(nameVal, phoneVal, phone2Val, emailVal, addressVal, notes: notesVal);
      }
      if (mounted) _load();
    }
  }

  Future<void> _delete(int id) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _confirmDialog(context, title:'Delete Customer', message:'Permanently delete this customer?');
    if (!ok) return;
    try {
      await DatabaseHelper.deleteCustomer(id);
      if (mounted) _load();
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('Cannot delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Customers')),
    body: Column(children: [
      _SearchBar(controller: _searchCtrl, hint: 'Search customers...', onClear: () { _searchCtrl.clear(); _load(); }, onChanged: _onSearch),
      Expanded(child: _customers.isEmpty
          ? const Center(child: Text('No customers yet.'))
          : ListView.builder(itemCount: _customers.length, itemBuilder: (_, i) {
        final c             = _customers[i];
        final id            = c['id'] as int;
        final name          = c['name'] as String? ?? '';
        final owed          = _owedBalances[id] ?? 0.0;
        final isBlacklisted = (c['isBlacklisted'] as int? ?? 0) == 1;
        final joinedDate    = c['joinedDate'] as String? ?? '';
        final phone         = c['phone'] as String? ?? '';
        final phone2        = c['phone2'] as String? ?? '';
        final phoneLine     = phone.isNotEmpty ? '$phone${phone2.isNotEmpty ? ' / $phone2' : ''}' : '';

        return Card(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isBlacklisted
                  ? Colors.red.withValues(alpha: 0.45)
                  : Colors.amber.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerProfileScreen(customer: c)));
              _load();
            },
            child: Padding(
              padding: appSettingsNotifier.cardPadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: isBlacklisted ? Colors.red.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.2),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(color: isBlacklisted ? Colors.red : Colors.amber[900], fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        if (isBlacklisted) const Padding(
                          padding: EdgeInsets.only(right: 5),
                          child: Icon(Icons.block, size: 14, color: Colors.red),
                        ),
                        Expanded(child: Text(name, style: TextStyle(fontWeight: FontWeight.w700, color: isBlacklisted ? Colors.red : null))),
                      ]),
                      if (phoneLine.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(phoneLine, style: const TextStyle(fontSize: 13)),
                        ),
                      if (joinedDate.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Since ${DatabaseHelper.formatDateString(joinedDate)}',
                            style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
                          ),
                        ),
                    ]),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 28,
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          padding: EdgeInsets.zero,
                          tooltip: 'Options',
                          onSelected: (val) {
                            if (val == 'call') _makePhoneCall(phone, phone2);
                            if (val == 'edit') _showCustomerDialog(existing: c);
                            if (val == 'delete') _delete(c['id'] as int);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'call', child: Row(children: [Icon(Icons.call, size: 18, color: Colors.green), SizedBox(width: 8), Text('Call')])),
                            PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit')])),
                            PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                          ],
                        ),
                      ),
                      if (owed > 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange, width: 0.8),
                          ),
                          child: Text(
                            'Owes ${formatMoney(owed, decimals: 0)}',
                            style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      })),
    ]),
    floatingActionButton: FloatingActionButton(
      onPressed: () => _showCustomerDialog(),
      tooltip: 'Add Customer',
      child: const Icon(Icons.person_add),
    ),
  );
}

// =================================================
// Customer Profile Screen
// =================================================
class CustomerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> customer;
  const CustomerProfileScreen({super.key, required this.customer});
  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  late Map<String, dynamic> _customer;
  List<RentalGroup> _allHistory = [];
  List<RentalGroup> _history = [];
  Map<String, List<Map<String, dynamic>>> _paymentLogsByGroup = {};
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _sortMode = kSortOptions.first;

  @override
  void initState() { super.initState(); _customer = widget.customer; _load(); }
  @override
  void dispose() { _searchCtrl.dispose(); _debounce?.cancel(); super.dispose(); }

  Future<void> _load() async {
    final id      = _customer['id'] as int;
    final name    = _customer['name'] as String? ?? '';
    final history = await DatabaseHelper.getCustomerRentalHistory(id, name);
    final paymentMap = await DatabaseHelper.getPaymentLogsForGroups(history);
    final stats   = await DatabaseHelper.getCustomerLifetimeStats(id, name);
    final fresh   = await DatabaseHelper.getCustomers();
    final updated = fresh.where((c) => c['id'] == _customer['id']).firstOrNull;
    if (!mounted) return;
    setState(() {
      if (updated != null) _customer = updated;
      _allHistory = history;
      _paymentLogsByGroup = paymentMap;
      _stats   = stats;
      _applyFilter();
      _loading = false;
    });
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => setState(_applyFilter));
  }

  void _applyFilter() {
    List<RentalGroup> filtered = List.from(_allHistory);
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      filtered = filtered.where((g) {
        return (g.orderId?.toString() ?? '').contains(q) ||
            g.items.any((i) => (i['itemName'] as String? ?? '').toLowerCase().contains(q));
      }).toList();
    }
    _applySort(filtered, _sortMode);
    _history = filtered;
  }

  Future<void> _toggleBlacklist() async {
    final current = (_customer['isBlacklisted'] as int? ?? 0) == 1;
    final confirm = await _confirmDialog(
      context,
      title: current ? 'Remove Blacklist Flag' : 'Blacklist Customer',
      message: current
          ? 'Remove the blacklist flag from this customer?'
          : 'Flag this customer as blacklisted? They will be visually marked in the customer list.',
      confirmLabel: current ? 'Remove Flag' : 'Blacklist',
    );
    if (!confirm) return;
    await DatabaseHelper.toggleBlacklist(_customer['id'] as int, !current);
    if (mounted) _load();
  }

  Future<void> _openInvoicePdf(int orderId, {required bool finalInvoice}) async {
    final size = await pickPdfSize(context);
    if (size == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Generating PDF...')));
    try {
      final bytes = finalInvoice
          ? await DatabaseHelper.generatePdfFinalInvoiceForOrder(orderId, pageSize: size)
          : await DatabaseHelper.generatePdfProformaForOrder(orderId, pageSize: size);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(finalInvoice ? 'Final Invoice Preview' : 'Proforma Preview')),
          body: PdfPreview(build: (_) async => bytes),
        ),
      ));
    } catch (e) { if (mounted) messenger.showSnackBar(SnackBar(content: Text('Failed: $e'))); }
  }

  Future<void> _handleReturn(RentalGroup group) async {
    final messenger = ScaffoldMessenger.of(context);
    DateTime checkoutDt; try { checkoutDt = DateTime.parse(group.checkoutDate); } catch (_) { checkoutDt = DateTime(2000); }
    final action = await showDialog<String>(context: context, builder: (d) => AlertDialog(
      title: const Text('Return Action'),
      content: const Text('Are you returning ALL remaining items, or only a partial return?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d,'cancel'),  child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(d,'partial'), child: const Text('Partial Return')),
        ElevatedButton(onPressed: () => Navigator.pop(d,'full'), child: const Text('Full Return')),
      ],
    ));
    if (action == null || action == 'cancel') return;

    if (action == 'partial') {
      final activeItems = group.items.where((r) => r['returned'] == 0).toList();
      if (activeItems.isEmpty) return;
      if (!mounted) return;
      final result = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => _PartialReturnDialog(activeItems: activeItems, checkoutDate: checkoutDt));
      if (result == null) return;
      try { await DatabaseHelper.returnMultiplePartial(result['returns'] as List<Map<String,dynamic>>, result['date'] as String); if (mounted) _load(); }
      catch (e) { if (mounted) messenger.showSnackBar(SnackBar(content: Text('Return failed: $e'))); }
    } else {
      if (!mounted) return;
      final choice = await showDialog<String?>(context: context, builder: (d) => AlertDialog(
        title: const Text('Full Return Date'), content: const Text('When were the remaining items returned?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d),           child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(d,'pick'),    child: const Text('Pick Date')),
          ElevatedButton(onPressed: () => Navigator.pop(d,'today'), child: const Text('Today')),
        ],
      ));
      if (choice == null) return;
      String returnDate = DatabaseHelper.isoNow();
      if (choice == 'pick') {
        if (!mounted) return;
        final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: checkoutDt, lastDate: DateTime(2100));
        if (picked == null) return;
        returnDate = DatabaseHelper.isoDate(picked);
      }
      try {
        await DatabaseHelper.returnOrderGroup(group.items.where((r) => r['returned'] == 0).toList(), returnDate);
        if (!mounted) return;
        _load();
        messenger.showSnackBar(SnackBar(content: Text(group.balance > 0 ? 'Items returned. Remaining balance sent to Payment Ledger.' : 'Remaining items returned successfully.')));
      } catch (e) { if (mounted) messenger.showSnackBar(SnackBar(content: Text('Return failed: $e'))); }
    }
  }

  Future<void> _settleGroup(RentalGroup group) async {
    final isRefund   = group.balance < 0;
    final absBalance = group.balance.abs();
    final messenger  = ScaffoldMessenger.of(context);
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _SettleGroupDialog(group: group),
    );
    if (result == null || !mounted) return;

    final amount = double.parse(result['amount']!);
    final method = result['method']!;
    final discount = double.parse(result['discount']!);
    final isBadDebt = result['isBadDebt'] == 'true';
    final isFull = (amount + discount) >= absBalance - 0.01;
    final adjustedAmount = isRefund ? -amount : amount;

    if (isBadDebt) {
      await DatabaseHelper.writeOffBadDebt(
        group.items.first['id'] as int,
        amount,
        isFull ? group.items.map((i) => i['id'] as int).toList() : [],
      );
      if (!mounted) return;
      _load();
      messenger.showSnackBar(SnackBar(content: Text(isFull ? 'Balance written off as bad debt. Invoice closed.' : 'Partial bad debt written off.')));
    } else {
      await DatabaseHelper.addPaymentToRentalGroup(
          group.items.first['id'] as int,
          adjustedAmount,
          isFull,
          group.items.map((i) => i['id'] as int).toList(),
          paymentMethod: method,
          discountAmount: discount
      );
      if (!mounted) return;
      _load();
      messenger.showSnackBar(SnackBar(content: Text(isFull
          ? (isRefund ? 'Refund recorded. Invoice settled.' : 'Invoice marked as fully paid & settled.')
          : (isRefund ? 'Partial refund recorded.' : 'Partial payment recorded.'))));
    }
  }

  Future<void> _editGroup(RentalGroup group) async {
    await showDialog<void>(context: context, builder: (_) => _EditGroupDialog(group: group));
    if (mounted) _load();
  }

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
    // Reuse the same unified Transactions screen from customer profile as well.
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
              )));
            },
            child: const Row(children: [Icon(Icons.account_balance_wallet, color: Colors.orange), SizedBox(width: 12), Text('Outstanding Ledger')]),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(RentalGroup g) {
    final payments = _paymentLogsByGroup[g.paymentGroupKey];
    return UniversalRentalCard(
      group: g,
      paymentLogs: payments,
      showCustomerName: false,
      onEdit: () => _editGroup(g),
      onReturn: !g.isFullyReturned ? () => _handleReturn(g) : null,
      onSettle: g.isFullyReturned && !g.isSettled ? () => _settleGroup(g) : null,
      onPdf: g.isFullyReturned && g.orderId != null ? () => _openInvoicePdf(g.orderId!, finalInvoice: true) : null,
      onCancel: g.isFullyReturned && !g.isCancelled ? () => _cancel(g) : null,
      onDelete: g.isFullyReturned ? () => _delete(g) : null,
      onViewPayments: () => _openPaymentHistoryForGroup(g),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name          = _customer['name']          as String? ?? '';
    final phone         = _customer['phone']         as String? ?? '';
    final phone2        = _customer['phone2']        as String? ?? '';
    final email         = _customer['email']         as String? ?? '';
    final address       = _customer['address']       as String? ?? '';
    final notes         = _customer['notes']         as String? ?? '';
    final joinedDate    = _customer['joinedDate']    as String? ?? '';
    final isBlacklisted = (_customer['isBlacklisted'] as int? ?? 0) == 1;

    final totalSpent    = (_stats['totalSpent']    as double?) ?? 0.0;
    final totalInvoices = (_stats['totalInvoices'] as int?)    ?? 0;
    final activeRentals = (_stats['activeRentals'] as int?)    ?? 0;
    final owedBalance   = (_stats['owedBalance']   as double?) ?? 0.0;
    final refundBalance = (_stats['refundBalance'] as double?) ?? 0.0;
    final badDebtTotal  = (_stats['badDebt']       as double?) ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            icon: Icon(isBlacklisted ? Icons.block : Icons.person_off_outlined,
                color: isBlacklisted ? Colors.red : null),
            tooltip: isBlacklisted ? 'Remove Blacklist' : 'Blacklist Customer',
            onPressed: _toggleBlacklist,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              // Header card
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: isBlacklisted
                        ? Colors.red.withValues(alpha: 0.15)
                        : Colors.amber.withValues(alpha: 0.2),
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                            color: isBlacklisted ? Colors.red : Colors.amber)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                      if (isBlacklisted) Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red, width: 0.8)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.block, size: 11, color: Colors.red),
                          SizedBox(width: 4),
                          Text('BLACKLISTED', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ]),
                    if (joinedDate.isNotEmpty) Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text('Customer since ${DatabaseHelper.formatDateString(joinedDate)}',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
                    ),
                  ])),
                ]),
                if (phone.isNotEmpty || email.isNotEmpty || address.isNotEmpty || notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  if (phone.isNotEmpty)   _InfoRow(icon: Icons.phone,       text: phone + (phone2.isNotEmpty ? '  /  $phone2' : '')),
                  if (email.isNotEmpty)   _InfoRow(icon: Icons.email,       text: email),
                  if (address.isNotEmpty) _InfoRow(icon: Icons.location_on, text: address),
                  if (notes.isNotEmpty)   _InfoRow(icon: Icons.notes,       text: notes),
                ],
              ]))),

              const SizedBox(height: 12),

              // Stats grid
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.75,
                children: [
                  _MiniStatCard(label: 'Lifetime Billed', value: formatMoney(totalSpent, decimals: 0), icon: Icons.receipt_long, color: Colors.blue),
                  _MiniStatCard(label: 'Total Invoices',  value: '$totalInvoices', icon: Icons.folder_copy, color: Colors.purple),
                  _MiniStatCard(label: 'Active Items',    value: '$activeRentals', icon: Icons.handshake,   color: Colors.orange),
                  if (badDebtTotal > 0)  _MiniStatCard(label: 'Bad Debt',    value: formatMoney(badDebtTotal, decimals: 0),  icon: Icons.money_off, color: Colors.redAccent),
                  if (owedBalance > 0)   _MiniStatCard(label: 'Amount Due',  value: formatMoney(owedBalance, decimals: 0),   icon: Icons.payments, color: Colors.red),
                  if (refundBalance > 0) _MiniStatCard(label: 'Refund Due',  value: formatMoney(refundBalance, decimals: 0), icon: Icons.undo,     color: Colors.green),
                ],
              ),

              // Balance alert banner
              if (owedBalance > 0 || refundBalance > 0) ...[
                const SizedBox(height: 12),
                Card(
                  color: owedBalance > 0
                      ? Colors.orange.withValues(alpha: 0.08)
                      : Colors.green.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: owedBalance > 0 ? Colors.orange : Colors.green, width: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
                    Icon(owedBalance > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                        color: owedBalance > 0 ? Colors.orange : Colors.green, size: 22),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(owedBalance > 0 ? 'Outstanding Balance' : 'Refund Pending',
                          style: TextStyle(fontWeight: FontWeight.bold, color: owedBalance > 0 ? Colors.orange : Colors.green)),
                      Text(owedBalance > 0
                          ? 'This customer owes ${formatMoney(owedBalance)}'
                          : 'You owe this customer ${formatMoney(refundBalance)}',
                          style: const TextStyle(fontSize: 13)),
                    ])),
                  ])),
                ),
              ],

              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.history, size: 18),
                const SizedBox(width: 6),
                Text('Rental History (${_history.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 8),

              // Inline Search and Sort for History
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search invoices...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (_searchCtrl.text.isNotEmpty)
                      IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); setState(_applyFilter); }),
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
                      onSelected: (v) { setState(() { _sortMode = v; _applyFilter(); }); },
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
              const SizedBox(height: 12),

              if (_history.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No rental history matches.', style: TextStyle(color: Colors.grey)),
                ))
              else
                ..._history.map((g) => _buildCard(g)),

              const SizedBox(height: 80),
            ]),
          ),
        ),
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


// =================================================
// New Order Screen
// =================================================
class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key});
  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  List<Map<String, dynamic>> _items = [], _customers = [];
  final Map<int, TextEditingController> _qtyC = {}, _rateC = {};
  int? _selectedCustomerId;
  DateTime _selectedDate = DateTime.now();
  String _selectedPaymentMethod = 'Cash';
  final _advC = TextEditingController(), _notesC = TextEditingController();

  // State boolean to track if the top details form is visible or collapsed
  bool _isFormExpanded = true;
  final _dateCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dateCtrl.text = DatabaseHelper.formatDateFromDt(_selectedDate);
    _load();
  }

  @override
  void dispose() {
    for (final c in [..._qtyC.values,..._rateC.values]) { c.dispose(); }
    _advC.dispose(); _notesC.dispose(); _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await DatabaseHelper.getItems(); final customers = await DatabaseHelper.getCustomers();
    if (!mounted) return;
    setState(() {
      _items=items; _customers=customers;
      for (final it in items) { final id = it['id'] as int; _qtyC[id]??=TextEditingController(); _rateC[id]??=TextEditingController(); }
    });
  }

  Future<void> _saveOrder() async {
    final customer     = _customers.firstWhere((c) => c['id']==_selectedCustomerId, orElse: () => <String,dynamic>{});
    final customerName = (customer['name'] as String?)?.isNotEmpty==true ? customer['name'] as String : 'Walk-in';
    final customerId   = customer.containsKey('id') ? customer['id'] as int? : null;
    final checkoutDateStr = DatabaseHelper.isoDate(_selectedDate);
    final advance = double.tryParse(_advC.text) ?? 0.0;
    final messenger = ScaffoldMessenger.of(context); final nav = Navigator.of(context);
    final sel = <Map<String,dynamic>>[]; bool isFirst = true;

    for (final it in _items) {
      final id = it['id'] as int; final qty = int.tryParse(_qtyC[id]?.text??'')??0;
      if (qty <= 0) continue;
      final rate = double.tryParse(_rateC[id]?.text??'')??0.0;
      sel.add({
        'itemId': id,
        'customerId': customerId, // Fixed Name Collision
        'qty': qty,
        'rate': rate,
        'contractor': customerName,
        'phone': customer['phone'] ?? '',
        'phone2': customer['phone2'] ?? '',
        'address': customer['address'] ?? '',
        'checkoutDate': checkoutDateStr,
        'advanceDeposit': isFirst ? advance : 0.0,
        'notes': _notesC.text.trim(),
        'paymentMethod': isFirst ? _selectedPaymentMethod : ''
      });
      isFirst = false;
    }

    if (sel.isEmpty) { messenger.showSnackBar(const SnackBar(content: Text('Add at least one item with a quantity.'))); return; }
    try {
      final orderId = await DatabaseHelper.createOrder(customerId, customerName, checkoutDateStr);
      await DatabaseHelper.createOrderRentals(orderId, sel);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Order saved successfully!')));
      nav.pop();
    } catch (e) { if (mounted) messenger.showSnackBar(SnackBar(content: Text('Failed to save: $e'))); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New Rental Order')),
    body: Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Customer Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          TextButton.icon(
            onPressed: () => setState(() => _isFormExpanded = !_isFormExpanded),
            icon: Icon(_isFormExpanded ? Icons.expand_less : Icons.expand_more),
            label: Text(_isFormExpanded ? 'Hide Details' : 'Show Details'),
          )
        ]),
      ),
      if (_isFormExpanded)
        Expanded(
          flex: 0,
          child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 2, child: DropdownButtonFormField<int>(
                initialValue: _selectedCustomerId,
                decoration: const InputDecoration(labelText:'Customer', border:OutlineInputBorder(), prefixIcon:Icon(Icons.person), isDense:true),
                items: [const DropdownMenuItem<int>(value:null, child:Text('Select Customer')),
                  ..._customers.map((c) => DropdownMenuItem<int>(value:c['id'] as int, child:Text(c['name'] as String? ?? '')))],
                onChanged: (v) => setState(() => _selectedCustomerId = v),
              )),
              const SizedBox(width: 8),
              Expanded(flex: 1, child: TextFormField(
                readOnly: true,
                controller: _dateCtrl,
                onTap: () async {
                  final p = await showDatePicker(context:context, initialDate:_selectedDate, firstDate:DateTime(2000), lastDate:DateTime(2100));
                  if (p!=null) setState(() { _selectedDate=p; _dateCtrl.text = DatabaseHelper.formatDateFromDt(p); });
                },
                decoration: const InputDecoration(labelText:'Checkout Date', border:OutlineInputBorder(), isDense:true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                style: const TextStyle(fontSize: 14),
              )),
            ]),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 1, child: TextFormField(controller:_advC, decoration:InputDecoration(labelText:'Advance/Security ($curr)', border:const OutlineInputBorder(), isDense:true, prefixIcon:const Icon(Icons.payments)), keyboardType:const TextInputType.numberWithOptions(decimal:true))),
              const SizedBox(width: 8),
              Expanded(flex: 1, child: DropdownButtonFormField<String>(
                initialValue: _selectedPaymentMethod,
                decoration: const InputDecoration(labelText: 'Payment Method', border:OutlineInputBorder(), isDense:true, prefixIcon:Icon(Icons.payment)),
                items: kPaymentMethods.map((m) => DropdownMenuItem(value:m, child:Text(m))).toList(),
                onChanged: (v) { if (v!=null) setState(()=>_selectedPaymentMethod=v); },
              )),
            ]),
            const SizedBox(height: 12),
            TextFormField(controller: _notesC, maxLines:1, decoration:const InputDecoration(labelText:'Order Notes', border:OutlineInputBorder(), prefixIcon:Icon(Icons.notes), isDense:true)),
          ])),
        ),
      Container(width:double.infinity, color:Theme.of(context).colorScheme.surfaceContainerHighest,
          padding:const EdgeInsets.symmetric(horizontal:16,vertical:12),
          child: const Text('Select Equipment to Rent', style:TextStyle(fontWeight:FontWeight.bold))
      ),
      Expanded(child: _items.isEmpty
          ? const Center(child: Text('No items in inventory.\nAdd items first.', textAlign:TextAlign.center))
          : ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal:12,vertical:8), itemCount:_items.length,
        itemBuilder: (_, i) {
          final it=_items[i]; final id=it['id'] as int; final avail=(it['total'] as int? ?? 0)-(it['rented'] as int? ?? 0);
          return Card(margin:const EdgeInsets.only(bottom:8), child:Padding(padding:const EdgeInsets.symmetric(horizontal:10,vertical:12),
              child:Row(crossAxisAlignment:CrossAxisAlignment.center, children:[
                Expanded(flex:3, child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
                  Text(it['name']??'', style:const TextStyle(fontWeight:FontWeight.w600,fontSize:14)), const SizedBox(height:4),
                  _StockChip('Avail: $avail', avail>0?Colors.green:Colors.red),
                ])),
                const SizedBox(width:8),
                Expanded(flex:2, child:TextFormField(controller:_qtyC[id], enabled:avail>0, decoration:const InputDecoration(labelText:'Qty',border:OutlineInputBorder(),isDense:true,contentPadding:EdgeInsets.symmetric(horizontal:8,vertical:10)), keyboardType:TextInputType.number)),
                const SizedBox(width:8),
                Expanded(flex:2, child:TextFormField(controller:_rateC[id], enabled:avail>0, decoration:InputDecoration(labelText:'Rate($curr)',border:const OutlineInputBorder(),isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:8,vertical:10)), keyboardType:const TextInputType.numberWithOptions(decimal:true))),
              ])));
        },
      )),
      Padding(padding:const EdgeInsets.all(12), child:SizedBox(width:double.infinity,
          child:ElevatedButton.icon(icon:const Icon(Icons.check), label:const Text('Confirm Rental'), style:ElevatedButton.styleFrom(padding:const EdgeInsets.symmetric(vertical:12)), onPressed:_saveOrder))),
    ]),
  );
}

// =================================================
// Invoice Manager Screen (Unified)
// =================================================
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

// =================================================
// Orders List Screen
// =================================================
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
    final size = await pickPdfSize(context);
    if (size == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context); final nav = Navigator.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Generating PDF...')));
    try {
      final bytes = await DatabaseHelper.generatePdfProformaForOrder(orderId, pageSize: size);
      if (share) { await Printing.sharePdf(bytes: bytes, filename: 'proforma_order_$orderId.pdf'); }
      else {
        if (!mounted) return;
        await nav.push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Proforma Preview')), body: PdfPreview(build: (_) async => bytes))));
      }
    } catch (e) { if (mounted) messenger.showSnackBar(SnackBar(content: Text('Failed: $e'))); }
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
                      if (val == 'preview') _openPdf(o['id'] as int);
                      if (val == 'share') _openPdf(o['id'] as int, share: true);
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

// =================================================
// Final Invoices Screen
// =================================================
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
    final size = await pickPdfSize(context);
    if (size == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
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
          final billed = g.calculateTotalCost();
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
                        if (val == 'preview') _openPdf(g.orderId!);
                        if (val == 'share') _openPdf(g.orderId!, share: true);
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

// =================================================
// Order Details Screen
// =================================================
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

// =================================================
// Settings Screen - Full Rewrite
// =================================================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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

// ---- dialog helpers ----

  static const _iconChannel = MethodChannel('com.wjust4435.rental_manager/icon');

  Future<void> _changeAppIcon(String iconKey) async {
    final s = appSettingsNotifier;
    final messenger = ScaffoldMessenger.of(context);

    try {
      await _iconChannel.invokeMethod('setIcon', {'iconKey': iconKey});
      await s.setAppIcon(iconKey);

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(iconKey == 'default'
                ? 'App icon reset to default.'
                : 'App icon changed successfully.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to change icon: $e')),
        );
      }
    }
  }

  void _showAppIconDialog() {
    final s = appSettingsNotifier;
    final icons = [
      {'name': 'Default Icon', 'key': 'default'},
      {'name': 'Icon Variant 1', 'key': 'icon1'},
      {'name': 'Icon Variant 2', 'key': 'icon2'},
      {'name': 'Icon Variant 3', 'key': 'icon3'},
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Choose App Icon'),
        children: icons.map((icon) => ListTile(
          leading: const Icon(Icons.app_shortcut, color: Colors.amber),
          title: Text(icon['name']!),
          trailing: s.appIcon == icon['key'] ? const Icon(Icons.check, color: Colors.amber) : null,
          onTap: () {
            Navigator.pop(ctx);
            _changeAppIcon(icon['key']!);
          },
        )).toList(),
      ),
    );
  }

  void _showCardDensityDialog() {
    final s = appSettingsNotifier;
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Card Density'),
        children: [
          ListTile(
            title: const Text('Comfortable'),
            subtitle: const Text('Easier to read, more spacing'),
            trailing: s.cardDensity == 'comfortable' ? const Icon(Icons.check, color: Colors.amber) : null,
            onTap: () { s.setCardDensity('comfortable'); Navigator.pop(ctx); },
          ),
          ListTile(
            title: const Text('Compact'),
            subtitle: const Text('Show more cards at once'),
            trailing: s.cardDensity == 'compact' ? const Icon(Icons.check, color: Colors.amber) : null,
            onTap: () { s.setCardDensity('compact'); Navigator.pop(ctx); },
          ),
        ],
      ),
    );
  }

  void _showFontSizeDialog() {
    final s = appSettingsNotifier;
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Font Size'),
        children: [
          ListTile(
            title: const Text('Small'),
            subtitle: const Text('90% - fits more on screen'),
            trailing: s.fontSize == 'small' ? const Icon(Icons.check, color: Colors.amber) : null,
            onTap: () { s.setFontSize('small'); Navigator.pop(ctx); },
          ),
          ListTile(
            title: const Text('Medium'),
            subtitle: const Text('100% - default size'),
            trailing: s.fontSize == 'medium' ? const Icon(Icons.check, color: Colors.amber) : null,
            onTap: () { s.setFontSize('medium'); Navigator.pop(ctx); },
          ),
          ListTile(
            title: const Text('Large'),
            subtitle: const Text('115% - easier to read'),
            trailing: s.fontSize == 'large' ? const Icon(Icons.check, color: Colors.amber) : null,
            onTap: () { s.setFontSize('large'); Navigator.pop(ctx); },
          ),
        ],
      ),
    );
  }

  void _showCurrencyDialog() {
    final s = appSettingsNotifier;
    final customC = TextEditingController(text: s.currencySymbol);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Currency Symbol'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Choose a symbol:'),
          const SizedBox(height: 12),
          StatefulBuilder(builder: (_, setSt) => Wrap(
            spacing: 8, runSpacing: 8,
            children: ['\u20B9', '\$', '\u20AC', '\u00A3', '\u00A5', '\u0E3F'].map((sym) => ChoiceChip(
              label: Text(sym, style: const TextStyle(fontSize: 18)),
              selected: s.currencySymbol == sym,
              onSelected: (_) { s.setCurrencySymbol(sym); customC.text = sym; setSt(() {}); },
            )).toList(),
          )),
          const SizedBox(height: 16),
          TextField(
            controller: customC,
            decoration: const InputDecoration(
              labelText: 'Or type a custom symbol',
              border: OutlineInputBorder(),
              isDense: true,
              helperText: 'Max 4 characters',
              counterText: '',
            ),
            maxLength: 4,
            onChanged: (v) { if (v.trim().isNotEmpty) s.setCurrencySymbol(v.trim()); },
          ),
        ]),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      ),
    ).then((_) => customC.dispose());
  }

  void _showOverdueDaysDialog() {
    final s = appSettingsNotifier;
    final ctrl = TextEditingController(text: s.overdueDays.toString());
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Overdue Threshold'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Rentals older than this many days will be flagged as overdue.',
              style: TextStyle(fontSize: 13, color: Theme.of(ctx).textTheme.bodySmall?.color)),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              suffixText: 'days',
              isDense: true,
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final n = int.tryParse(ctrl.text);
              if (n != null && n > 0) s.setOverdueDays(n);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) => ctrl.dispose());
  }

  void _showDateFormatDialog() {
    final s = appSettingsNotifier;
    const formats = ['dd/MMM/yyyy', 'dd/MM/yyyy', 'MM/dd/yyyy', 'yyyy-MM-dd'];
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Date Format'),
        children: formats.map((f) => ListTile(
          title: Text(f),
          trailing: s.dateFormat == f ? const Icon(Icons.check, color: Colors.amber) : null,
          onTap: () {
            s.setDateFormat(f);
            Navigator.pop(ctx);
          },
        )).toList(),
      ),
    );
  }

  void _showTimeFormatDialog() {
    final s = appSettingsNotifier;
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Time Format'),
        children: [
          ListTile(
            title: const Text('12-hour (AM/PM)'),
            trailing: s.timeFormat == '12h' ? const Icon(Icons.check, color: Colors.amber) : null,
            onTap: () {
              s.setTimeFormat('12h');
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('24-hour'),
            trailing: s.timeFormat == '24h' ? const Icon(Icons.check, color: Colors.amber) : null,
            onTap: () {
              s.setTimeFormat('24h');
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Privacy & Data'),
        content: const SingleChildScrollView(
          child: Text(
            'Rental Manager is designed for offline-first use.\n\n'
                '- Your business data is stored locally on your device database.\n'
                '- The app does not require internet for normal operation.\n'
                '- Payment and customer records stay on your device unless you export a backup manually.\n'
                '- Keep your backup files secure, because they contain your app data.\n\n'
                'You control your data: export, restore, and deletion actions are initiated by you.',
          ),
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  // ---- section header ----
  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 6),
    child: Text(title,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.amber[700])),
  );

  Widget _infoBox(String text, {Color? color}) => Container(
    margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: (color ?? Colors.blue).withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: (color ?? Colors.blue).withValues(alpha: 0.3)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.info_outline, size: 15, color: color ?? Colors.blue),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color ?? Colors.blue))),
    ]),
  );

  Widget _switchSettingTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => SwitchListTile(
    secondary: Icon(icon, color: color),
    title: Text(title),
    subtitle: Text(subtitle),
    value: value,
    onChanged: onChanged,
  );

  @override
  Widget build(BuildContext context) {
    final s  = appSettingsNotifier;
    final tm = themeModeNotifier.mode;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(children: [

        // ====================================
        // APPEARANCE
        // ====================================
        _sectionHeader('APPEARANCE'),

// Theme
        ListTile(
          leading: Icon(
            tm == ThemeMode.light ? Icons.light_mode :
            tm == ThemeMode.dark  ? Icons.dark_mode  : Icons.brightness_auto,
            color: Colors.amber,
          ),
          title: const Text('Theme'),
          subtitle: Text(tm == ThemeMode.light ? 'Light' : tm == ThemeMode.dark ? 'Dark' : 'System Default'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => themeModeNotifier.setMode(
            tm == ThemeMode.system ? ThemeMode.light :
            tm == ThemeMode.light  ? ThemeMode.dark  : ThemeMode.system,
          ),
        ),

        // App Icon Picker (NEW)
        ListTile(
          leading: const Icon(Icons.app_shortcut, color: Colors.amber),
          title: const Text('App Icon'),
          subtitle: const Text('Change home screen icon'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showAppIconDialog,
        ),

        // Card Density
        ListTile(
          leading: const Icon(Icons.density_medium, color: Colors.amber),
          title: const Text('Card Density'),
          subtitle: Text(s.cardDensity == 'compact' ? 'Compact' : 'Comfortable'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showCardDensityDialog,
        ),

        // Font Size
        ListTile(
          leading: const Icon(Icons.text_fields, color: Colors.amber),
          title: const Text('Font Size'),
          subtitle: Text(s.fontSize == 'small' ? 'Small (90%)' : s.fontSize == 'large' ? 'Large (115%)' : 'Medium (default)'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showFontSizeDialog,
        ),

        const Divider(height: 1),

        // ====================================
        // BUSINESS
        // ====================================
        _sectionHeader('BUSINESS'),

        // Currency Symbol
        ListTile(
          leading: const Icon(Icons.currency_exchange, color: Colors.amber),
          title: const Text('Currency Symbol'),
          subtitle: Text('Currently: ${s.currencySymbol}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showCurrencyDialog,
        ),

        // Overdue Threshold
        ListTile(
          leading: const Icon(Icons.warning_amber_rounded, color: Colors.amber),
          title: const Text('Overdue Threshold'),
          subtitle: Text('Flagged after ${s.overdueDays} days'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showOverdueDaysDialog,
        ),

        _switchSettingTile(
            icon: Icons.draw_outlined,
            color: Colors.amber,
            title: 'Proforma Signatures',
            subtitle: 'Show signature lines on Proforma PDFs',
            value: s.showProformaSignatures,
            onChanged: s.setShowProformaSignatures
        ),

        _switchSettingTile(
            icon: Icons.draw,
            color: Colors.amber,
            title: 'Invoice Signatures',
            subtitle: 'Show signature lines on Final Invoice PDFs',
            value: s.showInvoiceSignatures,
            onChanged: s.setShowInvoiceSignatures
        ),

        _switchSettingTile(
            icon: Icons.edit_document,
            color: Colors.amber,
            title: 'Allow Invoice Editing',
            subtitle: 'Allow modifying records after a Final Invoice is issued',
            value: s.allowFinalInvoiceEditing,
            onChanged: s.setAllowFinalInvoiceEditing
        ),

        const Divider(height: 1),

        // ====================================
        // DASHBOARD
        // ====================================
        _sectionHeader('DASHBOARD'),

        _switchSettingTile(icon: Icons.leaderboard_outlined, color: Colors.amber, title: 'Top Customers by Revenue', subtitle: 'Show/hide Top 5 revenue list on dashboard', value: s.showTopCustomersByRevenue, onChanged: s.setShowTopCustomersByRevenue),
        _switchSettingTile(icon: Icons.history, color: Colors.amber, title: 'Payment History Time Stamp', subtitle: 'Show/hide time (AM/PM) in Payment History entries', value: s.showPaymentHistoryTime, onChanged: s.setShowPaymentHistoryTime),

        const Divider(height: 1),

        // ====================================
        // NOTIFICATIONS
        // ====================================
        _sectionHeader('NOTIFICATIONS'),

        _switchSettingTile(icon: Icons.alarm_on, color: Colors.amber, title: 'Overdue Rental Alert', subtitle: 'Alert when a rental exceeds ${s.overdueDays} days', value: s.notifyOverdue, onChanged: s.setNotifyOverdue),
        _switchSettingTile(icon: Icons.payments_outlined, color: Colors.amber, title: 'Pending Payment Reminder', subtitle: 'Remind about unsettled returned invoices', value: s.notifyPendingPayments, onChanged: s.setNotifyPendingPayments),

        const Divider(height: 1, indent: 16, endIndent: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('SCHEDULED DIGESTS',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.4, color: Colors.amber[600])),
        ),
        _switchSettingTile(icon: Icons.summarize_outlined, color: Colors.amber, title: 'Daily Summary', subtitle: 'A morning snapshot of active rentals and pending collections', value: s.notifySummary, onChanged: s.setNotifySummary),
        _infoBox('Fires once per app open, at most once per day.'),

        const Divider(height: 1),

        // ====================================
        // REGIONAL
        // ====================================
        _sectionHeader('REGIONAL'),

        // Language
        ListTile(
          leading: const Icon(Icons.language, color: Colors.amber),
          title: const Text('Language'),
          subtitle: Text(s.language == 'Hindi' ? 'Hindi (India)' : 'English (US)'),
          trailing: DropdownButton<String>(
            value: s.language,
            underline: const SizedBox(),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: 'English',
                child: Text('English'),
              ),
            ],
            onChanged: (String? v) {
              if (v != null) s.setLanguage(v);
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.date_range_outlined, color: Colors.amber),
          title: const Text('Date Format'),
          subtitle: Text('Currently: ${s.dateFormat}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showDateFormatDialog,
        ),
        ListTile(
          leading: const Icon(Icons.access_time, color: Colors.amber),
          title: const Text('Time Format'),
          subtitle: Text(s.timeFormat == '24h' ? '24-hour' : '12-hour (AM/PM)'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showTimeFormatDialog,
        ),

        const Divider(height: 1),

        // ====================================
        // ABOUT
        // ====================================
        _sectionHeader('ABOUT'),

        const ListTile(
          leading: Icon(Icons.construction, color: Colors.amber),
          title: Text('Rental Manager', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Version 2.6.1  |  Database v26'),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined, color: Colors.amber),
          title: const Text('Privacy & Data'),
          subtitle: const Text('Offline-first data handling and user control'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showPrivacyDialog,
        ),
        ListTile(
          leading: const Icon(Icons.share, color: Colors.amber),
          title: const Text('Tell a Friend'),
          subtitle: const Text('Share the app with others'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Share.share('Check out Rental Manager, a great offline tool for tracking inventory and invoices: https://gitlab.com/wjust4435/rental_manager');
          },
        ),
        const SizedBox(height: 40),
      ]),
    );
  }
}
