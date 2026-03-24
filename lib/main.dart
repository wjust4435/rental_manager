import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  runApp(const RentalManagerApp());
}

// =================================================
// Theme Notifier
// =================================================
class ThemeModeNotifier extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  ThemeModeNotifier() { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('themeMode') ?? 'system';
    _mode = saved == 'light' ? ThemeMode.light : saved == 'dark' ? ThemeMode.dark : ThemeMode.system;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode m) async {
    _mode = m;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
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
  String _cardDensity        = 'comfortable'; // 'comfortable' | 'compact'
  String _fontSize           = 'medium';      // 'small' | 'medium' | 'large'
  String _firstDayOfWeek     = 'Monday';      // 'Monday' | 'Sunday'
  String _autoBackupSchedule = 'off';         // 'off' | 'daily' | 'weekly' | 'monthly'
  bool   _showTopCustomersByRevenue = true;
  bool   _showPaymentHistoryTime = true;
  bool   _notifyOverdue      = true;
  bool   _notifyPendingPayments = true;
  bool   _notifySummary      = false;
  bool   _notifyRefundWait   = true;
  bool   _notifyAnniversary  = false;
  String _language           = 'English';     // 'English' | 'Hindi'

  String get currencySymbol      => _currencySymbol;
  int    get overdueDays         => _overdueDays;
  String get cardDensity         => _cardDensity;
  String get fontSize            => _fontSize;
  String get firstDayOfWeek      => _firstDayOfWeek;
  String get autoBackupSchedule  => _autoBackupSchedule;
  bool   get showTopCustomersByRevenue => _showTopCustomersByRevenue;
  bool   get showPaymentHistoryTime => _showPaymentHistoryTime;
  bool   get notifyOverdue       => _notifyOverdue;
  bool   get notifyPendingPayments => _notifyPendingPayments;
  bool   get notifySummary       => _notifySummary;
  bool   get notifyRefundWait    => _notifyRefundWait;
  bool   get notifyAnniversary   => _notifyAnniversary;
  String get language            => _language;

  double get textScale  => _fontSize == 'small' ? 0.9 : _fontSize == 'large' ? 1.15 : 1.0;
  EdgeInsets get cardPadding => EdgeInsets.all(_cardDensity == 'compact' ? 8.0 : 12.0);

  AppSettingsNotifier() { _load(); }

  String _normalizeLanguage(String? v) {
    if (v == 'Hindi' || v == 'हिंदी' || v == 'à¤¹à¤¿à¤‚à¤¦à¥€') return 'Hindi';
    return 'English';
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _currencySymbol       = p.getString('currencySymbol')       ?? '\u20B9';
    _overdueDays          = p.getInt('overdueDays')             ?? 30;
    _cardDensity          = p.getString('cardDensity')          ?? 'comfortable';
    _fontSize             = p.getString('fontSize')             ?? 'medium';
    _firstDayOfWeek       = p.getString('firstDayOfWeek')       ?? 'Monday';
    _autoBackupSchedule   = p.getString('autoBackupSchedule')   ?? 'off';
    _showTopCustomersByRevenue = p.getBool('showTopCustomersByRevenue') ?? true;
    _showPaymentHistoryTime = p.getBool('showPaymentHistoryTime') ?? true;
    _notifyOverdue        = p.getBool('notifyOverdue')          ?? true;
    _notifyPendingPayments= p.getBool('notifyPendingPayments')  ?? true;
    _notifySummary        = p.getBool('notifySummary')          ?? false;
    _notifyRefundWait     = p.getBool('notifyRefundWait')       ?? true;
    _notifyAnniversary    = p.getBool('notifyAnniversary')      ?? false;
    _language             = _normalizeLanguage(p.getString('language'));
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('currencySymbol',      _currencySymbol);
    await p.setInt('overdueDays',            _overdueDays);
    await p.setString('cardDensity',         _cardDensity);
    await p.setString('fontSize',            _fontSize);
    await p.setString('firstDayOfWeek',      _firstDayOfWeek);
    await p.setString('autoBackupSchedule',  _autoBackupSchedule);
    await p.setBool('showTopCustomersByRevenue', _showTopCustomersByRevenue);
    await p.setBool('showPaymentHistoryTime', _showPaymentHistoryTime);
    await p.setBool('notifyOverdue',         _notifyOverdue);
    await p.setBool('notifyPendingPayments', _notifyPendingPayments);
    await p.setBool('notifySummary',         _notifySummary);
    await p.setBool('notifyRefundWait',      _notifyRefundWait);
    await p.setBool('notifyAnniversary',     _notifyAnniversary);
    await p.setString('language',            _language);
  }

  Future<void> setCurrencySymbol(String v)      async { _currencySymbol      = v; notifyListeners(); await _save(); }
  Future<void> setOverdueDays(int v)             async { _overdueDays         = v.clamp(1, 999); notifyListeners(); await _save(); }
  Future<void> setCardDensity(String v)          async { _cardDensity         = v; notifyListeners(); await _save(); }
  Future<void> setFontSize(String v)             async { _fontSize            = v; notifyListeners(); await _save(); }
  Future<void> setFirstDayOfWeek(String v)       async { _firstDayOfWeek      = v; notifyListeners(); await _save(); }
  Future<void> setAutoBackupSchedule(String v)   async { _autoBackupSchedule  = v; notifyListeners(); await _save(); }
  Future<void> setShowTopCustomersByRevenue(bool v) async { _showTopCustomersByRevenue = v; notifyListeners(); await _save(); }
  Future<void> setShowPaymentHistoryTime(bool v) async { _showPaymentHistoryTime = v; notifyListeners(); await _save(); }
  Future<void> setNotifyOverdue(bool v)          async { _notifyOverdue       = v; notifyListeners(); await _save(); }
  Future<void> setNotifyPendingPayments(bool v)  async { _notifyPendingPayments = v; notifyListeners(); await _save(); }
  Future<void> setNotifySummary(bool v)          async { _notifySummary       = v; notifyListeners(); await _save(); }
  Future<void> setNotifyRefundWait(bool v)       async { _notifyRefundWait    = v; notifyListeners(); await _save(); }
  Future<void> setNotifyAnniversary(bool v)      async { _notifyAnniversary   = v; notifyListeners(); await _save(); }
  Future<void> setLanguage(String v)             async { _language            = _normalizeLanguage(v); notifyListeners(); await _save(); }
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
  static const int _idRefund      = 4;
  static const int _idAnniversary = 5;

  static Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> checkAndNotify() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final s     = appSettingsNotifier;

    Future<bool> once(String key) async {
      if (prefs.getString('notif_$key') == today) return false;
      await prefs.setString('notif_$key', today);
      return true;
    }

    if (s.notifyOverdue        && await once('overdue'))     await _checkOverdue(s.overdueDays);
    if (s.notifyPendingPayments && await once('pending'))    await _checkPendingPayments();
    if (s.notifyRefundWait     && await once('refund'))      await _checkRefundWait();
    if (s.notifyAnniversary    && await once('anniversary')) await _checkAnniversaries();
    if (s.notifySummary        && await once('summary'))     await _checkSummary(s.overdueDays);
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

  static Future<void> _checkPendingPayments() async {
    final groups  = groupRentalsByInvoice(await DatabaseHelper.getAllRentals());
    final pending = groups.where((g) => g.isFullyReturned && !g.isSettled && g.balance > 0).toList();
    if (pending.isEmpty) return;
    final total = pending.fold(0.0, (sum, g) => sum + g.balance);
    final sym   = appSettingsNotifier.currencySymbol;
    await _show(
      _idPending,
      'Payment Pending',
      '${pending.length} invoice${pending.length > 1 ? 's' : ''} unpaid - total due: $sym${total.toStringAsFixed(0)}.',
    );
  }

  static Future<void> _checkRefundWait() async {
    final groups  = groupRentalsByInvoice(await DatabaseHelper.getAllRentals());
    final refunds = groups.where((g) => g.isFullyReturned && !g.isSettled && g.balance < 0).toList();
    if (refunds.isEmpty) return;
    await _show(
      _idRefund,
      'Refund Pending',
      '${refunds.length} customer${refunds.length > 1 ? 's are' : ' is'} waiting for a refund.',
    );
  }

  static Future<void> _checkAnniversaries() async {
    final db     = await DatabaseHelper.getDatabase();
    final active = await db.rawQuery(
      'SELECT rentals.contractor, items.name as itemName, rentals.checkoutDate '
          'FROM rentals JOIN items ON rentals.itemId=items.id '
          'WHERE rentals.returned=0 OR rentals.returned IS NULL',
    );
    const milestones = [7, 14, 30, 60, 90];
    final hits = <String>[];
    for (final r in active) {
      try {
        final days = DateTime.now()
            .difference(DateTime.parse(r['checkoutDate'] as String))
            .inDays;
        if (milestones.contains(days)) {
          hits.add('${r['contractor']} - ${r['itemName']} ($days days)');
        }
      } catch (_) {}
    }
    if (hits.isEmpty) return;
    final body = hits.first + (hits.length > 1 ? '  +${hits.length - 1} more' : '');
    await _show(_idAnniversary, 'Rental Milestone', body);
  }

  static Future<void> _checkSummary(int overdueDays) async {
    final stats  = await DatabaseHelper.getDashboardStats(overdueDays: overdueDays);
    final active = stats['activeRentals'] ?? 0;
    final groups = groupRentalsByInvoice(await DatabaseHelper.getAllRentals());
    final pendingTotal = groups
        .where((g) => g.isFullyReturned && !g.isSettled && g.balance > 0)
        .fold(0.0, (sum, g) => sum + g.balance);
    final sym = appSettingsNotifier.currencySymbol;
    await _show(
      _idSummary,
      'Daily Summary',
      '$active active rental${active != 1 ? 's' : ''}  |  Pending: $sym${pendingTotal.toStringAsFixed(0)}.',
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
    appSettingsNotifier.addListener(_rebuild);
  }

  @override
  void dispose() {
    themeModeNotifier.removeListener(_rebuild);
    appSettingsNotifier.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() { if (mounted) setState(() {}); }

  ThemeData _theme(Brightness b) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber, brightness: b),
    appBarTheme: const AppBarTheme(backgroundColor: Colors.amber, foregroundColor: Colors.black87, centerTitle: true, elevation: 2),
    cardTheme: CardThemeData(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Rental Manager',
    themeMode: themeModeNotifier.mode,
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(ctx).copyWith(
        textScaler: TextScaler.linear(appSettingsNotifier.textScale),
      ),
      child: child!,
    ),
    home: const MainShell(),
  );
}

// =================================================
// Constants
// =================================================
const List<String> kPaymentMethods    = ['Cash', 'UPI', 'Bank'];
const List<String> kSortOptions       = ['Date (Newest)', 'Date (Oldest)', 'Highest Balance'];
const List<String> kLedgerFilterOptions = ['All', 'Amount Due', 'Refund Due'];

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

class _PaymentBreakdownLine extends StatelessWidget {
  final double totalPaid;
  final List<Map<String, dynamic>> payments;
  final String fallbackMethod;
  final double fontSize;

  const _PaymentBreakdownLine({
    required this.totalPaid,
    required this.payments,
    required this.fallbackMethod,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final methodTotals = <String, double>{};
    for (final p in payments) {
      final method = (p['method'] as String? ?? '').trim();
      final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
      if (amount.abs() < 0.0001) continue;
      final key = method.isEmpty ? 'Payment' : method;
      methodTotals[key] = (methodTotals[key] ?? 0.0) + amount;
    }

    final loggedSum = methodTotals.values.fold<double>(0.0, (s, v) => s + v);
    final diff = totalPaid - loggedSum;

    if (methodTotals.isEmpty && totalPaid.abs() > 0.0001) {
      final key = fallbackMethod.trim().isEmpty ? 'Payment' : fallbackMethod.trim();
      methodTotals[key] = totalPaid;
    } else if (methodTotals.isNotEmpty && diff.abs() > 0.009) {
      final base = fallbackMethod.trim().isEmpty ? 'Adjustment' : '${fallbackMethod.trim()} Adj.';
      methodTotals[base] = (methodTotals[base] ?? 0.0) + diff;
    }

    final sign = totalPaid < 0 ? '-' : '';
    final paidText = 'Paid: $sign$curr${totalPaid.abs().toStringAsFixed(2)}';
    final parts = methodTotals.entries.map((e) {
      final partSign = e.value < 0 ? '-' : '';
      return '${e.key}: $partSign$curr${e.value.abs().toStringAsFixed(2)}';
    }).toList();

    final style = TextStyle(fontSize: fontSize);
    final paidStyle = TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...parts.map((p) => Text(p, style: style)),
        if (parts.isNotEmpty) const SizedBox(height: 2),
        Text(paidText, style: paidStyle),
      ],
    );
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
  static const int _dbVersion = 17;

  static Future<Database> getDatabase() async {
    final dir  = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/siteyard_v3.db';
    return openDatabase(path, version: _dbVersion,
      onCreate: (db, v) async {
        await db.execute("CREATE TABLE items(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,category TEXT DEFAULT 'General',total INTEGER NOT NULL DEFAULT 0,rented INTEGER DEFAULT 0,notes TEXT DEFAULT '')");
        await db.execute("CREATE TABLE rentals(id INTEGER PRIMARY KEY AUTOINCREMENT,itemId INTEGER,orderId INTEGER,contractor TEXT,phone TEXT,phone2 TEXT DEFAULT '',address TEXT,advanceDeposit REAL DEFAULT 0,qty INTEGER,checkoutDate TEXT,rentalRate REAL DEFAULT 0,returned INTEGER DEFAULT 0,returnDate TEXT,notes TEXT DEFAULT '',isSettled INTEGER DEFAULT 0,paymentMethod TEXT DEFAULT '')");
        await db.execute("CREATE TABLE customers(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT,phone TEXT,phone2 TEXT DEFAULT '',email TEXT DEFAULT '',address TEXT,notes TEXT DEFAULT '',joinedDate TEXT DEFAULT '',isBlacklisted INTEGER DEFAULT 0)");
        await db.execute("CREATE TABLE orders(id INTEGER PRIMARY KEY AUTOINCREMENT,customerId INTEGER,customerName TEXT,createdDate TEXT)");
        await db.execute("CREATE TABLE payment_logs(id INTEGER PRIMARY KEY AUTOINCREMENT,orderId INTEGER,fallbackRentalId INTEGER,amount REAL NOT NULL,method TEXT DEFAULT '',paidAt TEXT DEFAULT '')");
        await db.execute("CREATE TABLE business_info(id INTEGER PRIMARY KEY,name TEXT DEFAULT '',phone TEXT DEFAULT '',phone2 TEXT DEFAULT '',email TEXT DEFAULT '',address TEXT DEFAULT '',upiId TEXT DEFAULT '',upiName TEXT DEFAULT '')");
        await db.insert('business_info', {'id':1,'name':'','phone':'','phone2':'','email':'','address':'','upiId':'','upiName':''});
        await db.execute("CREATE INDEX IF NOT EXISTS idx_items_name ON items(name)");
        await db.execute("CREATE INDEX IF NOT EXISTS idx_rentals_checkout ON rentals(checkoutDate)");
        await db.execute("CREATE INDEX IF NOT EXISTS idx_rentals_returned ON rentals(returned)");
        await db.execute("CREATE INDEX IF NOT EXISTS idx_payment_logs_order ON payment_logs(orderId)");
        await db.execute("CREATE INDEX IF NOT EXISTS idx_payment_logs_fallback ON payment_logs(fallbackRentalId)");
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 11) {
          for (final sql in ["ALTER TABLE rentals ADD COLUMN orderId INTEGER","ALTER TABLE rentals ADD COLUMN notes TEXT DEFAULT ''","ALTER TABLE items ADD COLUMN category TEXT DEFAULT 'General'","ALTER TABLE items ADD COLUMN notes TEXT DEFAULT ''","ALTER TABLE customers ADD COLUMN notes TEXT DEFAULT ''"]) {
            try { await db.execute(sql); } catch (_) {}
          }
          try {
            await db.execute("CREATE TABLE IF NOT EXISTS business_info(id INTEGER PRIMARY KEY,name TEXT DEFAULT '',phone TEXT DEFAULT '',address TEXT DEFAULT '',upiId TEXT DEFAULT '')");
            if ((await db.query('business_info')).isEmpty) await db.insert('business_info', {'id':1,'name':'','phone':'','address':'','upiId':''});
          } catch (_) {}
        }
        if (oldV < 12) {
          for (final sql in ["ALTER TABLE business_info ADD COLUMN phone2 TEXT DEFAULT ''","ALTER TABLE business_info ADD COLUMN email TEXT DEFAULT ''","ALTER TABLE business_info ADD COLUMN upiName TEXT DEFAULT ''","ALTER TABLE customers ADD COLUMN phone2 TEXT DEFAULT ''","ALTER TABLE customers ADD COLUMN email TEXT DEFAULT ''","ALTER TABLE rentals ADD COLUMN isSettled INTEGER DEFAULT 0"]) {
            try { await db.execute(sql); } catch (_) {}
          }
        }
        if (oldV < 13) {
          for (final sql in ["CREATE INDEX IF NOT EXISTS idx_items_name ON items(name)","CREATE INDEX IF NOT EXISTS idx_rentals_checkout ON rentals(checkoutDate)","CREATE INDEX IF NOT EXISTS idx_rentals_returned ON rentals(returned)"]) {
            try { await db.execute(sql); } catch (_) {}
          }
        }
        if (oldV < 14) { try { await db.execute("ALTER TABLE rentals ADD COLUMN paymentMethod TEXT DEFAULT ''"); } catch (_) {} }
        if (oldV < 15) { try { await db.execute("ALTER TABLE rentals ADD COLUMN phone2 TEXT DEFAULT ''"); } catch (_) {} }
        if (oldV < 16) {
          for (final sql in [
            "ALTER TABLE customers ADD COLUMN joinedDate TEXT DEFAULT ''",
            "ALTER TABLE customers ADD COLUMN isBlacklisted INTEGER DEFAULT 0",
          ]) { try { await db.execute(sql); } catch (_) {} }
        }
        if (oldV < 17) {
          for (final sql in [
            "CREATE TABLE IF NOT EXISTS payment_logs(id INTEGER PRIMARY KEY AUTOINCREMENT,orderId INTEGER,fallbackRentalId INTEGER,amount REAL NOT NULL,method TEXT DEFAULT '',paidAt TEXT DEFAULT '')",
            "CREATE INDEX IF NOT EXISTS idx_payment_logs_order ON payment_logs(orderId)",
            "CREATE INDEX IF NOT EXISTS idx_payment_logs_fallback ON payment_logs(fallbackRentalId)",
          ]) { try { await db.execute(sql); } catch (_) {} }

          // Backfill one payment record per legacy group so old data still shows a method.
          try {
            final rows = await db.rawQuery(
              "SELECT id, orderId, advanceDeposit, paymentMethod, checkoutDate "
              "FROM rentals WHERE advanceDeposit != 0 ORDER BY id ASC",
            );
            final seen = <String>{};
            for (final r in rows) {
              final amount = (r['advanceDeposit'] as num?)?.toDouble() ?? 0.0;
              if (amount.abs() < 0.0001) continue;
              final orderId = r['orderId'] as int?;
              final rentalId = r['id'] as int?;
              if (orderId == null && rentalId == null) continue;
              final key = orderId != null ? 'o:$orderId' : 'f:$rentalId';
              if (seen.contains(key)) continue;
              seen.add(key);
              final method = (r['paymentMethod'] as String? ?? '').trim();
              final paidAt = (r['checkoutDate'] as String? ?? '').trim();
              await db.insert('payment_logs', {
                'orderId': orderId,
                'fallbackRentalId': orderId == null ? rentalId : null,
                'amount': amount,
                'method': method,
                'paidAt': paidAt.isNotEmpty ? paidAt : DateTime.now().toIso8601String(),
              });
            }
          } catch (_) {}
        }
      },
    );
  }

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  static String formatDateFromDt(DateTime dt) => '${dt.day.toString().padLeft(2,'0')}/${_months[dt.month-1]}/${dt.year}';
  static String formatDateString(String? s) { if (s==null||s.isEmpty) return ''; try { return formatDateFromDt(DateTime.parse(s)); } catch (_) { return s; } }
  static String isoDate(DateTime dt) => dt.toIso8601String().split('T')[0];
  static String isoNow() => isoDate(DateTime.now());

  // Load bundled Roboto fonts from assets for fully offline PDF rendering.
  static Future<Map<String, pw.Font>> _loadPdfFonts() async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    final italic = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Italic.ttf'));
    return {
      'regular': regular,
      'bold': bold,
      'italic': italic,
    };
  }

  static Future<Map<String, int>> getDashboardStats({int overdueDays = 30}) async {
    final db = await getDatabase();
    int q(List<Map> r) => r.first['c'] as int? ?? 0;
    final cutoff = isoDate(DateTime.now().subtract(Duration(days: overdueDays)));
    return {
      'items':         q(await db.rawQuery('SELECT COUNT(*) as c FROM items')),
      'activeRentals': q(await db.rawQuery('SELECT COUNT(*) as c FROM rentals WHERE returned=0 OR returned IS NULL')),
      'returned':      q(await db.rawQuery('SELECT COUNT(*) as c FROM rentals WHERE returned=1')),
      'customers':     q(await db.rawQuery('SELECT COUNT(*) as c FROM customers')),
      'overdue':       q(await db.rawQuery('SELECT COUNT(*) as c FROM rentals WHERE (returned=0 OR returned IS NULL) AND checkoutDate<=?', [cutoff])),
    };
  }

  static Future<double> getPendingCollectionsTotal() async {
    final groups = groupRentalsByInvoice(await getAllRentals());
    return groups
        .where((g) => g.isFullyReturned && !g.isSettled && g.balance > 0)
        .fold<double>(0.0, (sum, g) => sum + g.balance);
  }

  static Future<List<Map<String, dynamic>>> getTopCustomersByRevenue({int limit = 5}) async {
    final groups = groupRentalsByInvoice(await getAllRentals());
    final totals = <String, double>{};
    final invoices = <String, int>{};

    for (final g in groups) {
      final name = g.contractor.trim();
      if (name.isEmpty) continue;
      totals[name] = (totals[name] ?? 0.0) + g.calculateTotalCost();
      invoices[name] = (invoices[name] ?? 0) + 1;
    }

    final rows = totals.entries
        .map((e) => <String, dynamic>{
              'name': e.key,
              'revenue': e.value,
              'invoices': invoices[e.key] ?? 0,
            })
        .toList();

    rows.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
    if (rows.length > limit) return rows.take(limit).toList();
    return rows;
  }

  static Future<List<Map<String, dynamic>>> getItems({String? search, String? category}) async {
    final db = await getDatabase();
    final where = <String>[]; final args = <dynamic>[];
    if (search != null && search.isNotEmpty) { where.add('name LIKE ?'); args.add('%$search%'); }
    if (category != null && category != 'All') { where.add('category = ?'); args.add(category); }
    return db.query('items', where: where.isEmpty ? null : where.join(' AND '), whereArgs: args.isEmpty ? null : args, orderBy: 'name ASC');
  }

  static Future<List<String>> getCategories() async =>
      (await (await getDatabase()).rawQuery("SELECT DISTINCT category FROM items ORDER BY category ASC")).map((r) => r['category'] as String? ?? 'General').toList();

  static Future<void> insertItem(String name, int total, String category, String notes) async =>
      (await getDatabase()).insert('items', {'name':name,'total':total,'rented':0,'category':category,'notes':notes});

  static Future<void> updateItem(int id, String name, int total, String category, String notes) async {
    final db = await getDatabase();
    final rented = (await db.query('items', columns:['rented'], where:'id=?', whereArgs:[id])).firstOrNull?['rented'] as int? ?? 0;
    await db.update('items', {'name':name,'total':total,'rented':rented>total?total:rented,'category':category,'notes':notes}, where:'id=?', whereArgs:[id]);
  }

  static Future<void> deleteItem(int id) async {
    final db = await getDatabase();
    final active = (await db.rawQuery("SELECT COUNT(*) as c FROM rentals WHERE itemId=? AND (returned=0 OR returned IS NULL)", [id])).first['c'] as int? ?? 0;
    if (active > 0) throw Exception('Cannot delete: item has active rentals');
    await db.delete('items', where:'id=?', whereArgs:[id]);
  }

  static Future<List<Map<String, dynamic>>> getAllRentals({String? search}) async {
    final db = await getDatabase(); final args = <dynamic>[]; String where = '';
    if (search != null && search.isNotEmpty) { where = "WHERE rentals.contractor LIKE ? OR items.name LIKE ?"; args.addAll(['%$search%','%$search%']); }
    final rows = await db.rawQuery(
      "SELECT rentals.*, items.name as itemName, "
          "CASE WHEN (rentals.phone2 IS NULL OR rentals.phone2 = '') THEN COALESCE(customers.phone2, '') ELSE rentals.phone2 END as phone2 "
          "FROM rentals JOIN items ON rentals.itemId=items.id "
          "LEFT JOIN customers ON customers.name=rentals.contractor "
          "$where ORDER BY rentals.checkoutDate ASC, rentals.id ASC",
      args.isEmpty ? null : args,
    );
    return rows;
  }

  static Future<void> updateRental(int id, {required String contractor, required String phone, required String phone2, required String address, required double advanceDeposit, required double rentalRate, required String checkoutDate, required String notes, String paymentMethod = ''}) async =>
      (await getDatabase()).update('rentals', {'contractor':contractor,'phone':phone,'phone2':phone2,'address':address,'advanceDeposit':advanceDeposit,'rentalRate':rentalRate,'checkoutDate':checkoutDate,'notes':notes,'paymentMethod':paymentMethod}, where:'id=?', whereArgs:[id]);

  static Future<void> returnOrderGroup(List<Map<String, dynamic>> items, String returnDate) async {
    final db = await getDatabase();
    await db.transaction((txn) async {
      for (final r in items) {
        final rented = (await txn.query('items', columns:['rented'], where:'id=?', whereArgs:[r['itemId']])).firstOrNull?['rented'] as int? ?? 0;
        await txn.rawUpdate('UPDATE items SET rented=rented-? WHERE id=?', [(r['qty'] as int).clamp(0,rented), r['itemId']]);
        await txn.rawUpdate('UPDATE rentals SET returned=1,returnDate=? WHERE id=?', [returnDate, r['id']]);
      }
    });
  }

  static Future<void> returnMultiplePartial(List<Map<String, dynamic>> returns, String returnDate) async {
    final db = await getDatabase();
    await db.transaction((txn) async {
      for (final ret in returns) {
        final rental = ret['rental'] as Map<String, dynamic>;
        final returnQty = ret['qty'] as int;
        if (returnQty <= 0) continue;
        final rentalId = rental['id'] as int; final itemId = rental['itemId'] as int; final currentQty = rental['qty'] as int;
        final rented = (await txn.query('items', columns:['rented'], where:'id=?', whereArgs:[itemId])).firstOrNull?['rented'] as int? ?? 0;
        await txn.rawUpdate('UPDATE items SET rented=rented-? WHERE id=?', [returnQty.clamp(0,rented), itemId]);
        if (returnQty >= currentQty) {
          await txn.rawUpdate('UPDATE rentals SET returned=1,returnDate=? WHERE id=?', [returnDate, rentalId]);
        } else {
          await txn.insert('rentals', {'itemId':itemId,'orderId':rental['orderId'],'contractor':rental['contractor'],'phone':rental['phone']??'','phone2':rental['phone2']??'','address':rental['address'],'advanceDeposit':0.0,'qty':returnQty,'checkoutDate':rental['checkoutDate'],'rentalRate':rental['rentalRate'],'returned':1,'returnDate':returnDate,'notes':rental['notes'],'isSettled':rental['isSettled']??0,'paymentMethod':rental['paymentMethod']??''});
          await txn.rawUpdate('UPDATE rentals SET qty=qty-? WHERE id=?', [returnQty, rentalId]);
        }
      }
    });
  }

  static Future<void> addPaymentToRentalGroup(int firstId, double amount, bool isFull, List<int> allIds, {String paymentMethod = ''}) async {
    final db = await getDatabase();
    await db.transaction((txn) async {
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
      await txn.rawUpdate('UPDATE rentals SET advanceDeposit=advanceDeposit+?,paymentMethod=? WHERE id=?', [amount, paymentMethod, firstId]);
      if (isFull) { for (final id in allIds) { await txn.rawUpdate('UPDATE rentals SET isSettled=1 WHERE id=?', [id]); } }
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
        await txn.delete('rentals', where:'id=?', whereArgs:[r['id']]);
      }
      for (final oid in orderIds) {
        final count = (await txn.rawQuery('SELECT COUNT(*) as c FROM rentals WHERE orderId=?', [oid])).first['c'] as int? ?? 0;
        if (count == 0) {
          await txn.delete('orders', where:'id=?', whereArgs:[oid]);
          await txn.delete('payment_logs', where:'orderId=?', whereArgs:[oid]);
        }
      }
      for (final fid in fallbackIds) {
        await txn.delete('payment_logs', where:'fallbackRentalId=?', whereArgs:[fid]);
      }
    });
  }

  static Future<List<Map<String, dynamic>>> getCustomers({String? search}) async {
    final db = await getDatabase();
    if (search != null && search.isNotEmpty) return db.query('customers', where:'name LIKE ? OR phone LIKE ?', whereArgs:['%$search%','%$search%'], orderBy:'name ASC');
    return db.query('customers', orderBy:'name ASC');
  }

  static Future<int> insertCustomer(String name, String phone, String phone2, String email, String address, {String notes = '', String joinedDate = ''}) =>
      getDatabase().then((db) => db.insert('customers', {'name':name,'phone':phone,'phone2':phone2,'email':email,'address':address,'notes':notes,'joinedDate':joinedDate.isNotEmpty ? joinedDate : isoNow(),'isBlacklisted':0}));

  static Future<void> updateCustomer(int id, String name, String phone, String phone2, String email, String address, {String notes = '', String joinedDate = '', int isBlacklisted = 0}) async =>
      (await getDatabase()).update('customers', {'name':name,'phone':phone,'phone2':phone2,'email':email,'address':address,'notes':notes,'joinedDate':joinedDate,'isBlacklisted':isBlacklisted}, where:'id=?', whereArgs:[id]);

  static Future<void> deleteCustomer(int id) async =>
      (await getDatabase()).delete('customers', where:'id=?', whereArgs:[id]);

  static Future<void> toggleBlacklist(int id, bool blacklist) async =>
      (await getDatabase()).update('customers', {'isBlacklisted': blacklist ? 1 : 0}, where:'id=?', whereArgs:[id]);

  static Future<double> getCustomerOwedBalance(String customerName) async {
    if (customerName.isEmpty) return 0.0;
    final rows = await (await getDatabase()).rawQuery("SELECT rentals.*, items.name as itemName FROM rentals JOIN items ON rentals.itemId=items.id WHERE rentals.contractor=? ORDER BY rentals.checkoutDate ASC, rentals.id ASC", [customerName]);
    return groupRentalsByInvoice(rows).where((g) => g.isFullyReturned && !g.isSettled && g.balance > 0).fold<double>(0.0, (s, g) => s + g.balance);
  }

  static Future<List<RentalGroup>> getCustomerRentalHistory(String customerName) async {
    if (customerName.isEmpty) return [];
    final rows = await (await getDatabase()).rawQuery(
      "SELECT rentals.*, items.name as itemName FROM rentals JOIN items ON rentals.itemId=items.id WHERE rentals.contractor=? ORDER BY rentals.checkoutDate DESC, rentals.id DESC",
      [customerName],
    );
    return groupRentalsByInvoice(rows);
  }

  static Future<Map<String, dynamic>> getCustomerLifetimeStats(String customerName) async {
    if (customerName.isEmpty) return {'totalSpent': 0.0, 'totalInvoices': 0, 'activeRentals': 0, 'refundBalance': 0.0, 'owedBalance': 0.0};
    final rows = await (await getDatabase()).rawQuery(
      "SELECT rentals.*, items.name as itemName FROM rentals JOIN items ON rentals.itemId=items.id WHERE rentals.contractor=? ORDER BY rentals.checkoutDate ASC, rentals.id ASC",
      [customerName],
    );
    final groups = groupRentalsByInvoice(rows);
    double totalSpent   = 0.0;
    double owedBalance  = 0.0;
    double refundBalance = 0.0;
    int activeRentals   = 0;
    for (final g in groups) {
      totalSpent += g.calculateTotalCost();
      if (!g.isFullyReturned) activeRentals += g.items.where((r) => r['returned'] == 0).length;
      if (g.isFullyReturned && !g.isSettled) {
        if (g.balance > 0) owedBalance  += g.balance;
        if (g.balance < 0) refundBalance += g.balance.abs();
      }
    }
    return {
      'totalSpent':    totalSpent,
      'totalInvoices': groups.length,
      'activeRentals': activeRentals,
      'owedBalance':   owedBalance,
      'refundBalance': refundBalance,
    };
  }

  static Future<int> createOrder(int? customerId, String customerName, String createdDate) =>
      getDatabase().then((db) => db.insert('orders', {'customerId':customerId,'customerName':customerName,'createdDate':createdDate}));

  static Future<void> createOrderRentals(int orderId, List<Map<String, dynamic>> items) async {
    final db = await getDatabase();
    await db.transaction((txn) async {
      double initialAdvance = 0.0;
      String initialMethod = '';
      String initialPaidAt = isoNow();
      for (final it in items) {
        final itemId = it['itemId'] as int; final qty = it['qty'] as int; final rate = (it['rate'] as num?)?.toDouble() ?? 0.0;
        final advance = (it['advanceDeposit'] as num?)?.toDouble() ?? 0.0;
        if (initialAdvance.abs() < 0.0001 && advance.abs() > 0.0001) {
          initialAdvance = advance;
          initialMethod = (it['paymentMethod'] as String? ?? '').trim();
          initialPaidAt = (it['checkoutDate'] as String? ?? '').trim().isNotEmpty
              ? (it['checkoutDate'] as String)
              : isoNow();
        }
        final rows = await txn.query('items', columns:['total','rented'], where:'id=?', whereArgs:[itemId]);
        if (rows.isEmpty) throw Exception('Item not found');
        final total = rows.first['total'] as int? ?? 0; final rented = rows.first['rented'] as int? ?? 0;
        if (qty > (total - rented)) throw Exception('Not enough stock for item $itemId');
        await txn.insert('rentals', {'itemId':itemId,'contractor':it['contractor']??'','phone':it['phone']??'','phone2':it['phone2']??'','address':it['address']??'','advanceDeposit':it['advanceDeposit']??0.0,'rentalRate':rate,'qty':qty,'checkoutDate':it['checkoutDate']??isoNow(),'orderId':orderId,'returned':0,'notes':it['notes']??'','isSettled':0,'paymentMethod':it['paymentMethod']??''});
        await txn.update('items', {'rented':rented+qty}, where:'id=?', whereArgs:[itemId]);
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

    if (orderId != null) {
      where.add('p.orderId = ?');
      args.add(orderId);
    } else if (fallbackRentalId != null) {
      where.add('p.fallbackRentalId = ?');
      args.add(fallbackRentalId);
    }

    if (type == 'Payment') where.add('p.amount > 0');
    if (type == 'Refund') where.add('p.amount < 0');

    final s = search.trim();
    if (s.isNotEmpty) {
      where.add(
        "(COALESCE(o.customerName, r.contractor, '') LIKE ? "
        "OR COALESCE(p.method, '') LIKE ? "
        "OR CAST(COALESCE(p.orderId, p.fallbackRentalId) AS TEXT) LIKE ?)",
      );
      args.addAll(['%$s%', '%$s%', '%$s%']);
    }

    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await db.rawQuery(
      "SELECT p.id, p.orderId, p.fallbackRentalId, p.amount, p.method, p.paidAt, "
      "COALESCE(o.customerName, r.contractor, '') AS customerName, "
      "COALESCE(o.createdDate, r.checkoutDate, '') AS baseDate "
      "FROM payment_logs p "
      "LEFT JOIN orders o ON p.orderId = o.id "
      "LEFT JOIN rentals r ON p.fallbackRentalId = r.id "
      "$whereSql "
      "ORDER BY p.paidAt DESC, p.id DESC",
      args,
    );
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  static Future<List<Map<String, dynamic>>> getOrders() async => (await getDatabase()).query('orders', orderBy:'createdDate DESC');

  static Future<List<Map<String, dynamic>>> getRentalsByOrder(int orderId) async =>
      (await getDatabase()).rawQuery("SELECT rentals.*, items.name as itemName FROM rentals JOIN items ON rentals.itemId=items.id WHERE rentals.orderId=?", [orderId]);

  static Future<Map<String, dynamic>> getBusinessInfo() async {
    final rows = await (await getDatabase()).query('business_info', where:'id=?', whereArgs:[1]);
    if (rows.isEmpty) return {'name':'','phone':'','phone2':'','email':'','address':'','upiId':'','upiName':''};
    return rows.first;
  }

  static Future<void> saveBusinessInfo(String name, String phone, String phone2, String email, String address, String upiId, String upiName) async =>
      (await getDatabase()).update('business_info', {'name':name,'phone':phone,'phone2':phone2,'email':email,'address':address,'upiId':upiId,'upiName':upiName}, where:'id=?', whereArgs:[1]);

  static DateTime? _safeParseDate(dynamic s) {
    if (s == null) return null;
    final v = s.toString();
    if (v.isEmpty) return null;
    try { return DateTime.parse(v); } catch (_) { return null; }
  }

  static int _rentalChargeDays(Map<String, dynamic> r) {
    DateTime checkout = DateTime.now();
    try { checkout = DateTime.parse(r['checkoutDate'] as String? ?? ''); } catch (_) {}
    DateTime end = DateTime.now();
    if (r['returned'] == 1 && (r['returnDate'] as String?)?.isNotEmpty == true) {
      try { end = DateTime.parse(r['returnDate'] as String); } catch (_) {}
    }
    int days = end.difference(checkout).inDays;
    if (days < 0) days = 0;
    return days == 0 ? 1 : days;
  }

  static Future<Uint8List> generatePdfProformaForOrder(int orderId, {String pageSize = 'A4'}) async {
    final db = await getDatabase();
    final orderList = await db.query('orders', where:'id=?', whereArgs:[orderId]);
    if (orderList.isEmpty) throw Exception('Order not found');
    final order = orderList.first; final rentals = await getRentalsByOrder(orderId); final biz = await getBusinessInfo();
    final is57mm = pageSize == '57mm';
    final format = is57mm ? const PdfPageFormat(57*PdfPageFormat.mm, 200*PdfPageFormat.mm, marginAll:4*PdfPageFormat.mm) : PdfPageFormat.a4;
    final fs = is57mm ? 8.0 : 11.0;

    final fonts = await _loadPdfFonts();
    final fontRegular = fonts['regular']!;
    final fontBold    = fonts['bold']!;
    final fontItalic  = fonts['italic']!;

    final pdfCurr = appSettingsNotifier.currencySymbol;

    String s(String k) => (biz[k] as String?) ?? '';
    final bizName=s('name'),bizPhone=s('phone'),bizPhone2=s('phone2'),bizEmail=s('email'),bizAddress=s('address'),bizUpi=s('upiId'),bizUpiName=s('upiName');
    final upiString = 'upi://pay?pa=$bizUpi&pn=${Uri.encodeComponent(bizUpiName)}&cu=INR';
    final advance = rentals.fold(0.0, (sum, r) => sum + ((r['advanceDeposit'] as num?)?.toDouble() ?? 0.0));

    pw.TextStyle ts({double d=0, bool bold=false, bool italic=false}) => pw.TextStyle(
      fontSize: fs + d,
      font:      bold ? fontBold : italic ? fontItalic : fontRegular,
      fontBold:  fontBold,
      fontItalic: fontItalic,
    );

    pw.Widget sigLine(String label) => pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.center, children:[pw.Container(width:120,height:1,color:PdfColors.black),pw.SizedBox(height:4),pw.Text(label,style:ts(d:-1))]);
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
        pageFormat: format,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold, italic: fontItalic),
        build:(ctx) => [
          if (bizName.isNotEmpty)    pw.Text(bizName, style:ts(d:4,bold:true)),
          if (bizPhone.isNotEmpty || bizPhone2.isNotEmpty) pw.Text('Ph: $bizPhone${bizPhone2.isNotEmpty?' / $bizPhone2':''}', style:ts()),
          if (bizEmail.isNotEmpty)   pw.Text(bizEmail, style:ts()),
          if (bizAddress.isNotEmpty) pw.Text(bizAddress, style:ts()),
          if (bizUpi.isNotEmpty)     pw.Text('UPI: $bizUpi', style:ts()),
          pw.Divider(),
          pw.Text('PROFORMA', style:ts(d:2,bold:true)), pw.SizedBox(height:4),
          pw.Text('Proforma #: $orderId', style:ts()),
          pw.Text('Date: ${formatDateString(order['createdDate'] as String? ?? '')}', style:ts()),
          pw.Divider(), pw.Text('BILL TO:', style:ts(bold:true)),
          pw.Text('${order['customerName']??'N/A'}', style:ts()),
          if (rentals.isNotEmpty) ...[
            if (((rentals.first['phone'] as String?)??'').isNotEmpty)   pw.Text('Ph: ${rentals.first['phone']}', style:ts()),
            if (((rentals.first['address'] as String?)??'').isNotEmpty) pw.Text('Site: ${rentals.first['address']}', style:ts()),
          ],
          pw.Divider(),
          pw.TableHelper.fromTextArray(
            headerStyle:ts(bold:true), cellStyle:ts(),
            headers:['Item','Qty','Rate/Day'],
            headerAlignments:{0:pw.Alignment.centerLeft,1:pw.Alignment.center,2:pw.Alignment.centerRight},
            cellAlignments:{0:pw.Alignment.centerLeft,1:pw.Alignment.center,2:pw.Alignment.centerRight},
            data:[for (final r in rentals) [r['itemName']??'',(r['qty']??0).toString(),'$pdfCurr ${((r['rentalRate'] as num?)?.toDouble()??0.0).toStringAsFixed(2)}']],
          ),
          pw.Divider(),
          if (advance > 0) pw.Text('Advance Paid: $pdfCurr ${advance.toStringAsFixed(2)}', style:ts()),
          pw.Text('Note: This is a Proforma (estimated rental summary).', style:ts(d:-1, italic:true)),
          pw.SizedBox(height:6), pw.Text('Thank you for your business!', style:ts(italic:true)),
          pw.SizedBox(height:40), pw.Align(alignment:pw.Alignment.center, child:sigLine('Customer Signature')),
          pw.SizedBox(height:40), pw.Align(alignment:pw.Alignment.center, child:sigLine('Vendor Signature')),
          if (bizUpi.isNotEmpty) ...[
            pw.SizedBox(height:30),
            pw.Center(child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.center, children:[
              pw.BarcodeWidget(barcode:pw.Barcode.qrCode(), data:upiString, width:70, height:70),
              pw.SizedBox(height:6),
              if (bizUpiName.isNotEmpty) pw.Text(bizUpiName, style:ts(bold:true)),
              pw.Text('UPI: $bizUpi', style:ts(d:-2)),
            ])),
          ],
        ]));
    return doc.save();
  }

  static Future<Uint8List> generatePdfFinalInvoiceForOrder(int orderId, {String pageSize = 'A4'}) async {
    final db = await getDatabase();
    final orderList = await db.query('orders', where:'id=?', whereArgs:[orderId]);
    if (orderList.isEmpty) throw Exception('Order not found');
    final order = orderList.first;
    final rentals = await getRentalsByOrder(orderId);
    if (rentals.isEmpty) throw Exception('No rentals found for order');
    final biz = await getBusinessInfo();
    final is57mm = pageSize == '57mm';
    final format = is57mm ? const PdfPageFormat(57*PdfPageFormat.mm, 220*PdfPageFormat.mm, marginAll:4*PdfPageFormat.mm) : PdfPageFormat.a4;
    final fs = is57mm ? 8.0 : 11.0;

    final fonts = await _loadPdfFonts();
    final fontRegular = fonts['regular']!;
    final fontBold    = fonts['bold']!;
    final fontItalic  = fonts['italic']!;
    final pdfCurr = appSettingsNotifier.currencySymbol;

    String s(String k) => (biz[k] as String?) ?? '';
    final bizName=s('name'),bizPhone=s('phone'),bizPhone2=s('phone2'),bizEmail=s('email'),bizAddress=s('address'),bizUpi=s('upiId'),bizUpiName=s('upiName');
    final upiString = 'upi://pay?pa=$bizUpi&pn=${Uri.encodeComponent(bizUpiName)}&cu=INR';

    double totalBilled = 0.0;
    final lineData = <List<String>>[];
    DateTime? finalReturnDate;
    for (final r in rentals) {
      final qty = r['qty'] as int? ?? 0;
      final rate = (r['rentalRate'] as num?)?.toDouble() ?? 0.0;
      final days = _rentalChargeDays(r);
      final lineTotal = rate * qty * days;
      final returnText = formatDateString(r['returnDate'] as String?);
      totalBilled += lineTotal;
      lineData.add([
        '${(r['itemName'] ?? '').toString()} | Return: ${returnText.isEmpty ? 'Pending' : returnText}',
        qty.toString(),
        '$pdfCurr ${rate.toStringAsFixed(2)}',
        days.toString(),
        '$pdfCurr ${lineTotal.toStringAsFixed(2)}',
      ]);
      final rd = _safeParseDate(r['returnDate']);
      if (rd != null && (finalReturnDate == null || rd.isAfter(finalReturnDate))) {
        finalReturnDate = rd;
      }
    }

    final advance = rentals.fold(0.0, (sum, r) => sum + ((r['advanceDeposit'] as num?)?.toDouble() ?? 0.0));
    final balance = totalBilled - advance;
    final isSettled = rentals.every((r) => (r['isSettled'] as int? ?? 0) == 1);
    final finalReturnText = finalReturnDate == null ? 'Pending' : formatDateFromDt(finalReturnDate);

    double lineTotalOf(Map<String, dynamic> r) {
      final qty = r['qty'] as int? ?? 0;
      final rate = (r['rentalRate'] as num?)?.toDouble() ?? 0.0;
      final days = _rentalChargeDays(r);
      return rate * qty * days;
    }

    String money(double v, {bool compact = false}) {
      if (compact && v == v.roundToDouble()) return v.toStringAsFixed(0);
      return v.toStringAsFixed(2);
    }

    pw.TextStyle ts({double d=0, bool bold=false, bool italic=false}) => pw.TextStyle(
      fontSize: fs + d,
      font: bold ? fontBold : italic ? fontItalic : fontRegular,
      fontBold: fontBold,
      fontItalic: fontItalic,
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
      final rate = money((r['rentalRate'] as num?)?.toDouble() ?? 0.0, compact: true);
      final days = _rentalChargeDays(r);
      final amount = money(lineTotalOf(r), compact: true);
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
              '${(r['itemName'] ?? '').toString()} | Return date: ${ret.isEmpty ? 'Pending' : ret}',
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
                1: const pw.FlexColumnWidth(2.5),
                2: const pw.FlexColumnWidth(1.1),
                3: const pw.FlexColumnWidth(1.5),
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
                  cell('$pdfCurr $rate', align: pw.TextAlign.center),
                  cell('$days', align: pw.TextAlign.center),
                  cell('$pdfCurr $amount', bold: true, align: pw.TextAlign.right),
                ]),
              ],
            ),
          ],
        ),
      );
    }

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: format,
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold, italic: fontItalic),
      build:(ctx) => [
        if (bizName.isNotEmpty)    pw.Text(bizName, style:ts(d:4,bold:true)),
        if (bizPhone.isNotEmpty || bizPhone2.isNotEmpty) pw.Text('Ph: $bizPhone${bizPhone2.isNotEmpty?' / $bizPhone2':''}', style:ts()),
        if (bizEmail.isNotEmpty)   pw.Text(bizEmail, style:ts()),
        if (bizAddress.isNotEmpty) pw.Text(bizAddress, style:ts()),
        if (bizUpi.isNotEmpty)     pw.Text('UPI: $bizUpi', style:ts()),
        pw.Divider(),
        pw.Text('FINAL INVOICE', style:ts(d:2,bold:true)),
        pw.SizedBox(height:4),
        pw.Text('Invoice #: $orderId', style:ts()),
        pw.Text('Order Date: ${formatDateString(order['createdDate'] as String? ?? '')}', style:ts()),
        pw.Text('Final Return Date: $finalReturnText', style:ts()),
        pw.Divider(),
        pw.Text('BILL TO:', style:ts(bold:true)),
        pw.Text('${order['customerName'] ?? 'N/A'}', style:ts()),
        if (rentals.isNotEmpty) ...[
          if (((rentals.first['phone'] as String?) ?? '').isNotEmpty)   pw.Text('Ph: ${rentals.first['phone']}', style:ts()),
          if (((rentals.first['address'] as String?) ?? '').isNotEmpty) pw.Text('Site: ${rentals.first['address']}', style:ts()),
        ],
        pw.Divider(),
        if (is57mm) ...[
          for (final r in rentals) ...[
            thermalItemRow(r),
            pw.Divider(height: 4),
          ],
        ] else ...[
          pw.TableHelper.fromTextArray(
            headerStyle:ts(bold:true),
            cellStyle:ts(d:-1),
            headers:['Item','Qty','Rate/Day','Days','Line Total'],
            headerAlignments:{
              0:pw.Alignment.centerLeft,1:pw.Alignment.center,2:pw.Alignment.centerRight,3:pw.Alignment.center,4:pw.Alignment.centerRight
            },
            cellAlignments:{
              0:pw.Alignment.centerLeft,1:pw.Alignment.center,2:pw.Alignment.centerRight,3:pw.Alignment.center,4:pw.Alignment.centerRight
            },
            data: lineData,
          ),
        ],
        pw.Divider(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(is57mm ? 'Total:' : 'Total Billed:', style: ts(bold:true)),
          pw.Text('$pdfCurr ${money(totalBilled, compact: is57mm)}', style: ts(bold:true)),
        ]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(is57mm ? 'Advance:' : 'Advance Paid:', style: ts()),
          pw.Text('- $pdfCurr ${money(advance, compact: is57mm)}', style: ts()),
        ]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(balance > 0 ? (is57mm ? 'Due:' : 'Balance Due:') : balance < 0 ? (is57mm ? 'Refund:' : 'Refund Due:') : 'Balance:', style: ts(bold:true)),
          pw.Text('$pdfCurr ${money(balance.abs(), compact: is57mm)}', style: ts(bold:true)),
        ]),
        pw.Text(isSettled ? 'Payment Status: Settled' : 'Payment Status: Pending', style: ts()),
        pw.SizedBox(height: is57mm ? 18 : 30),
        pw.Align(alignment: pw.Alignment.center, child: sigLine('Customer Signature')),
        pw.SizedBox(height: is57mm ? 18 : 30),
        pw.Align(alignment: pw.Alignment.center, child: sigLine('Vendor Signature')),
        pw.SizedBox(height:8),
        pw.Text('This is the final invoice based on actual return dates.', style:ts(d:-1, italic:true)),
        if (bizUpi.isNotEmpty) ...[
          pw.SizedBox(height:20),
          pw.Center(child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.center, children:[
            pw.BarcodeWidget(barcode:pw.Barcode.qrCode(), data:upiString, width:70, height:70),
            pw.SizedBox(height:6),
            if (bizUpiName.isNotEmpty) pw.Text(bizUpiName, style:ts(bold:true)),
            pw.Text('UPI: $bizUpi', style:ts(d:-2)),
          ])),
        ],
      ],
    ));
    return doc.save();
  }

  static Future<Uint8List> generatePdfInvoiceForOrder(int orderId, {String pageSize = 'A4'}) =>
      generatePdfFinalInvoiceForOrder(orderId, pageSize: pageSize);

  static Future<String> exportBackup() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final bytes = await File('${dir.path}/siteyard_v3.db').readAsBytes();
      final path  = await FilePicker.platform.saveFile(dialogTitle:'Save Database Backup', fileName:'siteyard_backup.db', type:FileType.any, bytes:bytes);
      return path == null ? 'Backup cancelled' : 'Backup saved successfully!';
    } catch (e) { return 'Backup failed: $e'; }
  }

  static Future<String> importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null) return 'No file selected';
      final dir = await getApplicationDocumentsDirectory();
      await File(result.files.single.path!).copy('${dir.path}/siteyard_v3.db');
      return 'Restored successfully. Please restart the app.';
    } catch (e) { return 'Restore failed: $e'; }
  }
}

// =================================================
// Shared Models & Grouping
// =================================================
class RentalGroup {
  final int? orderId, fallbackId;
  final List<Map<String, dynamic>> items;
  RentalGroup({this.orderId, this.fallbackId, required this.items});

  bool get isGroup         => orderId != null;
  bool get isFullyReturned => items.every((r) => r['returned'] == 1);
  bool get isSettled       => items.every((r) => r['isSettled'] == 1);
  String get contractor    => items.first['contractor']    as String? ?? '';
  String get phone         => items.first['phone']         as String? ?? '';
  String get address       => items.first['address']       as String? ?? '';
  String get checkoutDate  => items.first['checkoutDate']  as String? ?? '';
  String get notes         => items.first['notes']         as String? ?? '';
  String get phone2        => items.first['phone2']        as String? ?? '';
  String get paymentMethod => items.first['paymentMethod'] as String? ?? '';
  String get paymentGroupKey => orderId != null
      ? 'o:$orderId'
      : 'f:${fallbackId ?? (items.firstOrNull?['id'] as int? ?? 0)}';
  double get advance => items.fold(0.0, (s, r) => s + ((r['advanceDeposit'] as num?)?.toDouble() ?? 0.0));
  double get balance => calculateTotalCost() - advance;

  double calculateTotalCost() {
    double total = 0.0;
    for (final r in items) {
      final qty  = r['qty']  as int? ?? 0;
      final rate = (r['rentalRate'] as num?)?.toDouble() ?? 0.0;
      DateTime checkout = DateTime.now();
      try { checkout = DateTime.parse(r['checkoutDate'] as String? ?? ''); } catch (_) {}
      DateTime end = DateTime.now();
      if (r['returned'] == 1 && (r['returnDate'] as String?)?.isNotEmpty == true) {
        try { end = DateTime.parse(r['returnDate'] as String); } catch (_) {}
      }
      int days = end.difference(checkout).inDays;
      if (days < 0) days = 0;
      total += rate * (days == 0 ? 1 : days) * qty;
    }
    return total;
  }
}

List<RentalGroup> groupRentalsByInvoice(List<Map<String, dynamic>> rawData) {
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
    // Run notification checks each time the app is opened.
    // Each check fires at most once per day per category.
    NotificationService.checkAndNotify();
  }

  void _nav(Widget screen) { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => screen)); }

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
    Container(
      padding: const EdgeInsets.symmetric(vertical: 20), width: double.infinity, color: Colors.amber,
      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.construction, size: 40, color: Colors.black87), SizedBox(height: 10),
        Text('Rental Manager', style: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold)),
      ]),
    ),
    Expanded(child: ListView(padding: EdgeInsets.zero, children: [
      ListTile(leading: const Icon(Icons.account_balance_wallet), title: const Text('Payment Ledger', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () => _nav(const PaymentLedgerScreen())),
      ListTile(leading: const Icon(Icons.history), title: const Text('Payment History'), onTap: () => _nav(const PaymentHistoryScreen())),
      const Divider(height: 1),
      ListTile(leading: const Icon(Icons.store),        title: const Text('Business Info'),     onTap: () => _nav(const BusinessInfoScreen())),
      ListTile(leading: const Icon(Icons.group),        title: const Text('Manage Customers'),  onTap: () => _nav(const CustomersManagementScreen())),
      ListTile(leading: const Icon(Icons.receipt_long), title: const Text('Proforma'), onTap: () => _nav(const OrdersListScreen())),
      ListTile(leading: const Icon(Icons.request_quote), title: const Text('Invoice'), onTap: () => _nav(const FinalInvoicesScreen())),
      const Divider(height: 1),
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

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final overdueDays = appSettingsNotifier.overdueDays;
    final stats   = await DatabaseHelper.getDashboardStats(overdueDays: overdueDays);
    final pending = await DatabaseHelper.getPendingCollectionsTotal();
    final topCust = await DatabaseHelper.getTopCustomersByRevenue(limit: 5);
    final cutoff  = DateTime.now().subtract(Duration(days: overdueDays));
    final db      = await DatabaseHelper.getDatabase();
    final active  = await db.rawQuery("SELECT rentals.*, items.name as itemName FROM rentals JOIN items ON rentals.itemId=items.id WHERE rentals.returned=0 OR rentals.returned IS NULL");
    final overdue = active.where((r) { try { return DateTime.parse(r['checkoutDate'] as String? ?? '').isBefore(cutoff); } catch (_) { return false; } }).toList();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _pendingCollections = pending;
      _topCustomers = topCust;
      _overdueRentals = overdue;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final overdueDays = appSettingsNotifier.overdueDays;
    final showTopCustomers = appSettingsNotifier.showTopCustomersByRevenue;
    return RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
      GridView.count(crossAxisCount:2, shrinkWrap:true, physics:const NeverScrollableScrollPhysics(), crossAxisSpacing:12, mainAxisSpacing:12, childAspectRatio:1.6, children: [
        _StatCard(label:'Total Items',    value:'${_stats['items']}',         icon:Icons.inventory_2,  color:Colors.blue),
        _StatCard(label:'Active Lines',   value:'${_stats['activeRentals']}', icon:Icons.handshake,    color:Colors.orange),
        _StatCard(label:'Customers',      value:'${_stats['customers']}',     icon:Icons.people,       color:Colors.purple),
        _StatCard(label:'Returned Lines', value:'${_stats['returned']}',      icon:Icons.check_circle, color:Colors.green),
      ]),
      const SizedBox(height: 14),
      Card(
        child: ListTile(
          leading: const Icon(Icons.account_balance_wallet, color: Colors.orange),
          title: const Text('Pending Collections', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Outstanding amount from returned invoices'),
          trailing: Text('$curr${_pendingCollections.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange)),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentLedgerScreen())),
        ),
      ),
      if (showTopCustomers) ...[
        const SizedBox(height: 14),
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
                trailing: Text('$curr${((c['revenue'] as double?) ?? 0.0).toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ),
            );
          }),
      ],
      if ((_stats['overdue'] ?? 0) > 0) ...[
        const SizedBox(height: 20),
        Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange), const SizedBox(width: 8),
          Text('Overdue Rentals ($overdueDays+ days)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange[300])),
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
      const SizedBox(height: 20),
      const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _QuickAction(icon:Icons.playlist_add,          label:'New Order',  onTap:() => Navigator.push(context, MaterialPageRoute(builder:(_) => const NewOrderScreen()))),
        _QuickAction(icon:Icons.account_balance_wallet, label:'Ledger',    onTap:() => Navigator.push(context, MaterialPageRoute(builder:(_) => const PaymentLedgerScreen()))),
        _QuickAction(icon:Icons.store,                 label:'Biz Info',   onTap:() => Navigator.push(context, MaterialPageRoute(builder:(_) => const BusinessInfoScreen()))),
        _QuickAction(icon:Icons.receipt_long,          label:'Proforma',   onTap:() => Navigator.push(context, MaterialPageRoute(builder:(_) => const OrdersListScreen()))),
        _QuickAction(icon:Icons.request_quote,         label:'Invoice',    onTap:() => Navigator.push(context, MaterialPageRoute(builder:(_) => const FinalInvoicesScreen()))),
        _QuickAction(icon:Icons.people,                label:'Customers',  onTap:() => Navigator.push(context, MaterialPageRoute(builder:(_) => const CustomersManagementScreen()))),
      ]),
    ]));
  }
}

class _StatCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [Icon(icon, color: color, size: 28), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
    ])],
  )));
}

class _QuickAction extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(border: Border.all(color: Colors.amber.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(12)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18, color: Colors.amber), const SizedBox(width: 6), Text(label, style: const TextStyle(fontWeight: FontWeight.w600))]),
  ));
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
  late final GlobalKey<FormState> formKey;
  String method = kPaymentMethods.first;

  @override
  void initState() {
    super.initState();
    formKey = GlobalKey<FormState>();
    payC = TextEditingController(text: widget.group.balance.abs().toStringAsFixed(2));
  }

  @override
  void dispose() { payC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isRefund   = widget.group.balance < 0;
    final absBalance = widget.group.balance.abs();
    return AlertDialog(
      title: Text(isRefund ? 'Record Refund' : 'Record Payment'),
      content: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isRefund
            ? 'Refund Due to Customer: $curr${absBalance.toStringAsFixed(2)}'
            : 'Total Remaining Balance: $curr${absBalance.toStringAsFixed(2)}'),
        const SizedBox(height: 16),
        TextFormField(
          controller: payC,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: isRefund ? 'Amount Refunded ($curr)' : 'Amount Paid ($curr)', border: const OutlineInputBorder()),
          validator: (v) { final val = double.tryParse(v??''); if (val==null||val<=0) return 'Invalid amount'; if (val>absBalance) return 'Cannot exceed ${isRefund ? 'refund amount' : 'balance'}'; return null; },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: method,
          decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder(), prefixIcon: Icon(Icons.payment)),
          items: kPaymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
          onChanged: (v) { if (v != null) setState(() => method = v); },
        ),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(context, {'amount': payC.text, 'method': method}); },
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
  const PaymentLedgerScreen({super.key});
  @override
  State<PaymentLedgerScreen> createState() => _PaymentLedgerScreenState();
}

class _PaymentLedgerScreenState extends State<PaymentLedgerScreen> {
  List<RentalGroup> _allPending = [];
  List<RentalGroup> _ledger     = [];
  String _filterMode = kLedgerFilterOptions.first;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _searchCtrl.dispose(); _debounce?.cancel(); super.dispose(); }

  Future<void> _load() async {
    final all = groupRentalsByInvoice(await DatabaseHelper.getAllRentals());
    final pending = all.where((g) => g.isFullyReturned && !g.isSettled && g.balance != 0).toList();
    if (!mounted) return;
    setState(() { _allPending = pending; _applyFilter(); });
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(_applyFilter);
    });
  }

  void _applyFilter() {
    List<RentalGroup> filtered;
    switch (_filterMode) {
      case 'Amount Due':  filtered = _allPending.where((g) => g.balance > 0).toList(); break;
      case 'Refund Due':  filtered = _allPending.where((g) => g.balance < 0).toList(); break;
      default:            filtered = List.from(_allPending);
    }

    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      filtered = filtered.where((g) {
        final contractor = g.contractor.toLowerCase();
        final phone = g.phone.toLowerCase();
        final phone2 = g.phone2.toLowerCase();
        final address = g.address.toLowerCase();
        final inv = g.orderId?.toString() ?? '';
        return contractor.contains(q) || phone.contains(q) || phone2.contains(q) || address.contains(q) || inv.contains(q);
      }).toList();
    }
    _ledger = filtered;
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
    final isFull = amount >= absBalance - 0.01;
    final adjustedAmount = isRefund ? -amount : amount;
    await DatabaseHelper.addPaymentToRentalGroup(group.items.first['id'] as int, adjustedAmount, isFull, group.items.map((i) => i['id'] as int).toList(), paymentMethod: method);
    if (!mounted) return;
    _load();
    messenger.showSnackBar(SnackBar(content: Text(isFull
        ? (isRefund ? 'Refund recorded. Invoice settled.' : 'Invoice marked as fully paid & settled.')
        : (isRefund ? 'Partial refund recorded.' : 'Partial payment recorded.'))));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Payment Ledger')),
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search customer, phone, or invoice...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
              if (_searchCtrl.text.isNotEmpty)
                IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); setState(_applyFilter); }),
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
                onSelected: (v) => setState(() { _filterMode = v; _applyFilter(); }),
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
      const SizedBox(height: 4),
      Expanded(child: _ledger.isEmpty
          ? Center(child: Text(
          _filterMode == 'Amount Due' ? 'No pending collections.' :
          _filterMode == 'Refund Due' ? 'No pending refunds.' :
          'All returned invoices are settled!',
          style: const TextStyle(fontSize: 16, color: Colors.green)))
          : RefreshIndicator(onRefresh: _load, child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        itemCount: _ledger.length,
        itemBuilder: (_, i) {
          final g = _ledger[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(side: BorderSide(color: g.balance < 0 ? Colors.green : Colors.orange), borderRadius: BorderRadius.circular(12)),
            child: Padding(padding: appSettingsNotifier.cardPadding, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text(g.contractor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                if (g.orderId != null) Text('INV #${g.orderId}', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
              ]),
              const SizedBox(height: 8),
              Text('Out: ${DatabaseHelper.formatDateString(g.checkoutDate)}'),
              const Divider(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Billed:'), Text('$curr${g.calculateTotalCost().toStringAsFixed(2)}')]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Paid:'), Text('- $curr${g.advance.toStringAsFixed(2)}')]),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(g.balance < 0 ? 'Refund Due:' : 'Amount Due:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('$curr${g.balance.abs().toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: g.balance < 0 ? Colors.green : Colors.orange)),
              ]),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                icon: Icon(g.balance < 0 ? Icons.undo : Icons.payment),
                label: Text(g.balance < 0 ? 'Record Refund' : 'Record Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: g.balance < 0 ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                  foregroundColor: g.balance < 0 ? Colors.greenAccent : Colors.orangeAccent,
                ),
                onPressed: () => _settleGroup(g),
              )),
            ])),
          );
        },
      )),
      ),
    ]),
  );
}

// =================================================
// Payment History Screen
// =================================================
class PaymentHistoryScreen extends StatefulWidget {
  final int? initialOrderId;
  final int? initialFallbackRentalId;
  const PaymentHistoryScreen({super.key, this.initialOrderId, this.initialFallbackRentalId});
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

  @override
  void initState() {
    super.initState();
    _scopedOrderId = widget.initialOrderId;
    _scopedFallbackRentalId = widget.initialFallbackRentalId;
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
      final h12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final meridiem = dt.hour >= 12 ? 'PM' : 'AM';
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$h12:$mm $meridiem';
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
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
    ),
    child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Payment History')),
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
                    _scopedOrderId != null
                        ? 'Showing payments for Invoice #$_scopedOrderId'
                        : 'Showing payments for linked record #$_scopedFallbackRentalId',
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
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
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
                                Text('Total Payments', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
                                const SizedBox(height: 2),
                                Text('$curr${_totalPayments.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Refunds', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
                                const SizedBox(height: 2),
                                Text('$curr${_totalRefunds.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
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
                    final ref = orderId != null
                        ? 'Invoice #$orderId'
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
                    final showTime = appSettingsNotifier.showPaymentHistoryTime;
                    final refLine = showTime && timeText.isNotEmpty
                        ? '$ref  |  $dateText  |  $timeText'
                        : '$ref  |  $dateText';
                    final amountColor = isRefund ? Colors.orange : Colors.green;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: appSettingsNotifier.cardPadding,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: amountColor.withValues(alpha: 0.15),
                              child: Icon(isRefund ? Icons.undo : Icons.payments, color: amountColor, size: 17),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(customer.isEmpty ? 'Unknown Customer' : customer, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text(refLine, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
                                  const SizedBox(height: 5),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _tag(isRefund ? 'Refund' : 'Payment', amountColor),
                                      _tag(method.isEmpty ? 'Method: N/A' : 'Method: $method', Colors.blueGrey),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${isRefund ? '-' : '+'}$curr${amount.abs().toStringAsFixed(2)}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: amountColor),
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
          final it = _items[i]; final total = it['total'] as int? ?? 0; final rented = it['rented'] as int? ?? 0; final avail = (total - rented).clamp(0, total);
          return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: appSettingsNotifier.cardPadding, child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(it['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                if ((it['category'] as String? ?? '') != 'General' && (it['category'] as String? ?? '').isNotEmpty)
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: Text(it['category'] as String, style: const TextStyle(fontSize: 10))),
              ]),
              const SizedBox(height: 6),
              Row(children: [_StockChip('Total: $total', Colors.blue), const SizedBox(width: 8), _StockChip('Out: $rented', Colors.orange), const SizedBox(width: 8), _StockChip('Free: $avail', avail > 0 ? Colors.green : Colors.red)]),
              if ((it['notes'] as String? ?? '').isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text(it['notes'] as String, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12))),
            ])),
            IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Edit', onPressed: () => _showItemDialog(item: it)),
          ])));
        },
      ))),
    ]),
    floatingActionButton: FloatingActionButton.extended(onPressed: _showItemDialog, icon: const Icon(Icons.add), label: const Text('Add Item')),
  );
}

class _StockChip extends StatelessWidget {
  final String label; final Color color;
  const _StockChip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
    child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
  );
}

// =================================================
// Partial Return Dialog
// =================================================
class _PartialReturnDialog extends StatefulWidget {
  final List<Map<String, dynamic>> activeItems;
  final DateTime checkoutDate;
  const _PartialReturnDialog({required this.activeItems, required this.checkoutDate});
  @override
  State<_PartialReturnDialog> createState() => _PartialReturnDialogState();
}

class _PartialReturnDialogState extends State<_PartialReturnDialog> {
  final Map<int, TextEditingController> _ctrl = {};
  DateTime _returnDate = DateTime.now();

  @override
  void initState() { super.initState(); for (final r in widget.activeItems) { _ctrl[r['id'] as int] = TextEditingController(text: '0'); } }
  @override
  void dispose() { for (final c in _ctrl.values) { c.dispose(); } super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Partial Return'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Enter the quantity to return for each item:'), const SizedBox(height: 16),
      ...widget.activeItems.map((r) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
        Expanded(child: Text('${r['itemName']}\n(Max: ${r['qty']})', style: const TextStyle(fontSize: 14))),
        SizedBox(width: 80, child: TextField(controller: _ctrl[r['id'] as int], keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true), textAlign: TextAlign.center)),
      ]))),
      const Divider(),
      Row(children: [
        Expanded(child: Text('Return Date:\n${DatabaseHelper.formatDateFromDt(_returnDate)}', style: const TextStyle(fontSize: 14))),
        TextButton(
          onPressed: () async { final p = await showDatePicker(context: context, initialDate: _returnDate, firstDate: widget.checkoutDate, lastDate: DateTime(2100)); if (p != null) setState(() => _returnDate = p); },
          child: const Text('Change'),
        ),
      ]),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ElevatedButton(
        onPressed: () {
          final returns = <Map<String, dynamic>>[];
          final messenger = ScaffoldMessenger.of(context);
          for (final r in widget.activeItems) {
            final id = r['id'] as int; final q = int.tryParse(_ctrl[id]?.text ?? '0') ?? 0;
            if (q > (r['qty'] as int)) { messenger.showSnackBar(SnackBar(content: Text('Cannot return more than rented for ${r['itemName']}'))); return; }
            if (q > 0) returns.add({'rental': r, 'qty': q});
          }
          if (returns.isEmpty) { messenger.showSnackBar(const SnackBar(content: Text('Enter at least one quantity to return'))); return; }
          Navigator.pop(context, {'returns': returns, 'date': DatabaseHelper.isoDate(_returnDate)});
        },
        child: const Text('Confirm Return'),
      ),
    ],
  );
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
          Expanded(child: TextField(controller: advC, decoration: InputDecoration(labelText: 'Advance ($curr)', isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
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
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            final nav = Navigator.of(context);
            final messenger = ScaffoldMessenger.of(context);
            try {
              bool isFirst = true;
              for (final r in g.items) {
                await DatabaseHelper.updateRental(r['id'] as int,
                    contractor: nameC.text.trim(), phone: phoneC.text.trim(), phone2: phone2C.text.trim(),
                    address: addressC.text.trim(),
                    advanceDeposit: isFirst ? (double.tryParse(advC.text) ?? 0.0) : 0.0,
                    rentalRate: (r['rentalRate'] as num?)?.toDouble() ?? 0.0,
                    checkoutDate: DatabaseHelper.isoDate(selected),
                    notes: notesC.text.trim(),
                    paymentMethod: isFirst ? editMethod : '');
                isFirst = false;
              }
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

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _searchCtrl.dispose(); _debounce?.cancel(); super.dispose(); }

  Future<void> _load() async {
    final all = groupRentalsByInvoice(await DatabaseHelper.getAllRentals(search: _searchCtrl.text));
    if (!mounted) return;
    setState(() => _groups = all.where((g) => !g.isFullyReturned).toList());
  }

  void _onSearch(String _) { _debounce?.cancel(); _debounce = Timer(const Duration(milliseconds: 300), _load); }

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
          TextButton(onPressed: () => Navigator.pop(d,'today'),   child: const Text('Today')),
          ElevatedButton(onPressed: () => Navigator.pop(d,'pick'), child: const Text('Pick Date')),
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

  Future<void> _editGroup(RentalGroup group) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _EditGroupDialog(group: group),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      _SearchBar(controller: _searchCtrl, hint: 'Search by contractor or item...', onClear: () { _searchCtrl.clear(); _load(); }, onChanged: _onSearch),
      Expanded(child: _groups.isEmpty
          ? const Center(child: Text('No active rentals.'))
          : RefreshIndicator(onRefresh: _load, child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        itemCount: _groups.length,
        itemBuilder: (_, i) => _buildCard(_groups[i]),
      ))),
    ]),
    floatingActionButton: FloatingActionButton.extended(
      icon: const Icon(Icons.add), label: const Text('New Rental'),
      onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const NewOrderScreen())); if (mounted) _load(); },
    ),
  );

  Widget _buildCard(RentalGroup g) {
    DateTime checkoutDt; try { checkoutDt = DateTime.parse(g.checkoutDate); } catch (_) { checkoutDt = DateTime.now(); }
    final overdueDays = appSettingsNotifier.overdueDays;
    final isOverdue = DateTime.now().difference(checkoutDt).inDays > overdueDays;
    final totalCost = g.calculateTotalCost(); final balance = totalCost - g.advance;
    final dayCount = DateTime.now().difference(checkoutDt).inDays;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: isOverdue
            ? const BoxDecoration(border: Border(left: BorderSide(color: Colors.orange, width: 4)))
            : null,
        child: Padding(padding: appSettingsNotifier.cardPadding, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Row 1: Contractor name + phone(s) + edit button
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            if (isOverdue) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18)),
            Expanded(child: Text.rich(
              TextSpan(children: [
                TextSpan(text: g.contractor, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                if (g.phone.isNotEmpty) TextSpan(
                  text: '  | Ph# ${g.phone}${g.phone2.isNotEmpty ? ' / ${g.phone2}' : ''}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Theme.of(context).textTheme.bodySmall?.color),
                ),
              ]),
              overflow: TextOverflow.ellipsis,
            )),
            IconButton(icon: const Icon(Icons.edit_outlined, size: 20), tooltip: 'Edit', onPressed: () => _editGroup(g)),
          ]),
          // Row 2: Site address
          if (g.address.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 2), child: Text('Site: ${g.address}', style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color))),
          // Row 3: Invoice # + Checkout date + days pill inline
          Padding(padding: const EdgeInsets.only(top: 2), child: Row(children: [
            Expanded(child: Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 12),
                children: [
                  if (g.orderId != null) ...[
                    TextSpan(text: 'Invoice #${g.orderId}', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                    const TextSpan(text: '  |  '),
                  ],
                  TextSpan(text: 'Checkout: ${DatabaseHelper.formatDateString(g.checkoutDate)}'),
                  const TextSpan(text: '  |  '),
                  TextSpan(
                    text: '$dayCount days',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isOverdue ? Colors.orange : Colors.blue,
                    ),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            )),
          ])),
          const Divider(height: 16),
          // Items list
          ...g.items.map((r) {
            final isRet = r['returned'] == 1;
            return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
              Icon(isRet ? Icons.check_circle : Icons.radio_button_checked, size: 16, color: isRet ? Colors.green : Colors.redAccent),
              const SizedBox(width: 8),
              Expanded(child: Text('${r['itemName']} x ${r['qty']} @ $curr${((r['rentalRate'] as num?)?.toDouble()??0.0).toStringAsFixed(2)}', style: TextStyle(fontSize: 13, color: isRet ? Colors.grey : null))),
              if (isRet) Text('Returned ${DatabaseHelper.formatDateString(r['returnDate'] as String?)}', style: const TextStyle(color: Colors.green, fontSize: 11)),
            ]));
          }),
          if (g.notes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Note: ${g.notes}', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12))),
          const Divider(height: 16),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Live Cost: $curr${totalCost.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              Row(children: [Text('Advance: $curr${g.advance.toStringAsFixed(2)}'), _PaymentLabel(g.paymentMethod)]),
              Text('Balance: $curr${balance.toStringAsFixed(2)}', style: TextStyle(color: balance>0?Colors.orangeAccent:Colors.greenAccent, fontWeight: FontWeight.bold)),
            ])),
            ElevatedButton.icon(icon: const Icon(Icons.check_circle_outline, size: 18), label: const Text('Return Items'), onPressed: () => _handleReturn(g)),
          ]),
        ])),
      ),
    );
  }
}

// =================================================
// History Tab
// =================================================
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});
  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
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
    final history = all.where((g) => g.isFullyReturned).toList();
    _applySort(history, _sortMode);
    if (!mounted) return;
    setState(() {
      _groups = history;
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

  void _openPaymentHistoryForGroup(RentalGroup g) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentHistoryScreen(
          initialOrderId: g.orderId,
          initialFallbackRentalId: g.orderId == null
              ? (g.fallbackId ?? (g.items.firstOrNull?['id'] as int?))
              : null,
        ),
      ),
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
          final g = _groups[i]; final totalCost = g.calculateTotalCost(); final balance = totalCost - g.advance;
          return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: appSettingsNotifier.cardPadding, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Row 1: Contractor name + phone(s) + PAID badge + delete
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: g.contractor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (g.phone.isNotEmpty) TextSpan(
                    text: '  | Ph# ${g.phone}${g.phone2.isNotEmpty ? ' / ${g.phone2}' : ''}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                ]),
                overflow: TextOverflow.ellipsis,
              )),
              if (g.isSettled) Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                child: const Text('PAID', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                width: 28,
                child: Tooltip(
                  message: 'Delete',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _delete(g),
                    child: const Align(
                      alignment: Alignment.centerRight,
                      child: Icon(Icons.delete_outline, size: 20),
                    ),
                  ),
                ),
              ),
            ]),
            // Row 2: Site address
            if (g.address.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 2), child: Text('Site: ${g.address}', style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color))),
            // Row 3: Invoice # + Checkout date
            Padding(padding: const EdgeInsets.only(top: 2), child: Row(children: [
              if (g.orderId != null) ...[
                Text('Invoice #${g.orderId}', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
                const Text('  |  ', style: TextStyle(fontSize: 12)),
              ],
              Text('Checkout: ${DatabaseHelper.formatDateString(g.checkoutDate)}', style: const TextStyle(fontSize: 12)),
            ])),
            const Divider(height: 16),
            // Items list
            ...g.items.map((r) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
              const Icon(Icons.check_circle, size: 14, color: Colors.green), const SizedBox(width: 8),
              Expanded(child: Text('${r['itemName']} x ${r['qty']} @ $curr${((r['rentalRate'] as num?)?.toDouble()??0.0).toStringAsFixed(2)}', style: const TextStyle(fontSize: 13))),
              Text(DatabaseHelper.formatDateString(r['returnDate'] as String?), style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ]))),
            if (g.notes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4, bottom: 4), child: Text('Note: ${g.notes}', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12))),
            const Divider(height: 16),
            Text('Total Billed: $curr${totalCost.toStringAsFixed(2)}'),
            Text('Paid: $curr${g.advance.toStringAsFixed(2)}'),
            Row(
              children: [
                Expanded(
                  child: Text(
                    g.isSettled ? 'Settled: Balance Paid' : 'Final Balance: $curr${balance.toStringAsFixed(2)}',
                    style: TextStyle(color: g.isSettled ? Colors.grey : (balance>0?Colors.orange:Colors.green), fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Tooltip(
                    message: 'View Payments',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _openPaymentHistoryForGroup(g),
                      child: const Align(
                        alignment: Alignment.centerRight,
                        child: Icon(Icons.receipt_long, color: Colors.amber, size: 18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ])));
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
      _emailC = TextEditingController(), _addressC = TextEditingController(), _upiC = TextEditingController(), _upiNameC = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { for (final c in [_nameC,_phoneC,_phone2C,_emailC,_addressC,_upiC,_upiNameC]) { c.dispose(); } super.dispose(); }

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
          await DatabaseHelper.saveBusinessInfo(_nameC.text.trim(), _phoneC.text.trim(), _phone2C.text.trim(), _emailC.text.trim(), _addressC.text.trim(), _upiC.text.trim(), _upiNameC.text.trim());
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
  Map<String, double> _owedBalances = {};
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
    final balances = <String, double>{};
    for (final c in customers) {
      final name = c['name'] as String? ?? '';
      if (name.isNotEmpty) balances[name] = await DatabaseHelper.getCustomerOwedBalance(name);
    }
    if (!mounted) return;
    setState(() => _owedBalances = balances);
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

    // Capture text values BEFORE disposing controllers to avoid the red-screen crash
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
    final ok = await _confirmDialog(context, title:'Delete Customer', message:'Delete this customer? Their rental history will remain.');
    if (!ok) return;
    await DatabaseHelper.deleteCustomer(id);
    if (mounted) _load();
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
        final name          = c['name'] as String? ?? '';
        final owed          = _owedBalances[name] ?? 0.0;
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Edit', onPressed: () => _showCustomerDialog(existing: c)),
                      IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Delete', onPressed: () => _delete(c['id'] as int)),
                    ]),
                  ]),
                  if (owed > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange, width: 0.8),
                      ),
                      child: Text(
                        'Owes $curr${owed.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      })),
    ]),
    floatingActionButton: FloatingActionButton.extended(icon: const Icon(Icons.person_add), label: const Text('Add Customer'), onPressed: () => _showCustomerDialog()),
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
  List<RentalGroup> _history = [];
  Map<String, List<Map<String, dynamic>>> _paymentLogsByGroup = {};
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() { super.initState(); _customer = widget.customer; _load(); }

  Future<void> _load() async {
    final name    = _customer['name'] as String? ?? '';
    final history = await DatabaseHelper.getCustomerRentalHistory(name);
    final paymentMap = await DatabaseHelper.getPaymentLogsForGroups(history);
    final stats   = await DatabaseHelper.getCustomerLifetimeStats(name);
    final fresh   = await DatabaseHelper.getCustomers();
    final updated = fresh.where((c) => c['id'] == _customer['id']).firstOrNull;
    if (!mounted) return;
    setState(() {
      if (updated != null) _customer = updated;
      _history = history;
      _paymentLogsByGroup = paymentMap;
      _stats   = stats;
      _loading = false;
    });
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
          : RefreshIndicator(
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
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red, width: 0.8)),
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
              _MiniStatCard(label: 'Lifetime Billed', value: '$curr${totalSpent.toStringAsFixed(0)}', icon: Icons.receipt_long, color: Colors.blue),
              _MiniStatCard(label: 'Total Invoices',  value: '$totalInvoices', icon: Icons.folder_copy, color: Colors.purple),
              _MiniStatCard(label: 'Active Items',    value: '$activeRentals', icon: Icons.handshake,   color: Colors.orange),
              if (owedBalance > 0)   _MiniStatCard(label: 'Amount Due',  value: '$curr${owedBalance.toStringAsFixed(0)}',   icon: Icons.payments, color: Colors.red),
              if (refundBalance > 0) _MiniStatCard(label: 'Refund Due',  value: '$curr${refundBalance.toStringAsFixed(0)}', icon: Icons.undo,     color: Colors.green),
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
                      ? 'This customer owes $curr${owedBalance.toStringAsFixed(2)}'
                      : 'You owe this customer $curr${refundBalance.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13)),
                ])),
              ])),
            ),
          ],

          const SizedBox(height: 16),

          // Rental history
          Row(children: [
            const Icon(Icons.history, size: 18),
            const SizedBox(width: 6),
            Text('Rental History (${_history.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),

          if (_history.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No rental history yet.', style: TextStyle(color: Colors.grey)),
            ))
          else
            ..._history.map((g) {
              final totalCost = g.calculateTotalCost();
              final balance   = totalCost - g.advance;
              final isActive  = !g.isFullyReturned;
              final payments = _paymentLogsByGroup[g.paymentGroupKey] ?? const <Map<String, dynamic>>[];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: isActive
                        ? Colors.red.withValues(alpha: 0.45)
                        : g.isSettled
                        ? Colors.green.withValues(alpha: 0.35)
                        : Colors.orange.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Header row
                  Row(children: [
                    _StatusBadge(isActive ? 'ACTIVE' : g.isSettled ? 'SETTLED' : 'PENDING',
                        isActive ? Colors.red : g.isSettled ? Colors.green : Colors.orange),
                    const SizedBox(width: 8),
                    if (g.orderId != null) Text('Invoice #${g.orderId}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(DatabaseHelper.formatDateString(g.checkoutDate),
                        style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
                    if (g.orderId != null) IconButton(
                      padding: const EdgeInsets.only(left: 8), constraints: const BoxConstraints(),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Colors.amber),
                      tooltip: g.isFullyReturned ? 'View Final Invoice' : 'View Proforma',
                      onPressed: () => _openInvoicePdf(g.orderId!, finalInvoice: g.isFullyReturned),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  // Items
                  ...g.items.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(children: [
                      Icon(r['returned'] == 1 ? Icons.check_circle : Icons.radio_button_checked,
                          size: 13, color: r['returned'] == 1 ? Colors.green : Colors.redAccent),
                      const SizedBox(width: 6),
                      Expanded(child: Text(
                        '${r['itemName']} x ${r['qty']} @ $curr${((r['rentalRate'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}/day',
                        style: TextStyle(fontSize: 13, color: r['returned'] == 1 ? Colors.grey : null),
                      )),
                    ]),
                  )),
                  const Divider(height: 12),
                  // Financials
                  Text('Billed: $curr${totalCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
                  _PaymentBreakdownLine(totalPaid: g.advance, payments: payments, fallbackMethod: g.paymentMethod, fontSize: 13),
                  const SizedBox(height: 2),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(
                      g.isSettled ? 'Settled'
                          : balance > 0 ? 'Due: $curr${balance.toStringAsFixed(2)}'
                          : balance < 0 ? 'Refund: $curr${balance.abs().toStringAsFixed(2)}'
                          : 'Clear',
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold,
                        color: g.isSettled ? Colors.green
                            : balance > 0 ? Colors.orange
                            : balance < 0 ? Colors.green
                            : Colors.grey,
                      ),
                    ),
                  ]),
                ])),
              );
            }),

          const SizedBox(height: 80),
        ]),
      ),
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

class _StatusBadge extends StatelessWidget {
  final String label; final Color color;
  const _StatusBadge(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
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
      sel.add({'itemId':id,'qty':qty,'rate':rate,'contractor':customerName,'phone':customer['phone']??'','phone2':customer['phone2']??'','address':customer['address']??'','checkoutDate':checkoutDateStr,'advanceDeposit':isFirst?advance:0.0,'notes':_notesC.text.trim(),'paymentMethod':isFirst?_selectedPaymentMethod:''});
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
              Expanded(flex: 1, child: TextFormField(controller:_advC, decoration:InputDecoration(labelText:'Advance ($curr)', border:const OutlineInputBorder(), isDense:true, prefixIcon:const Icon(Icons.payments)), keyboardType:const TextInputType.numberWithOptions(decimal:true))),
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
// Orders List Screen
// =================================================
class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});
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
    appBar: AppBar(title: const Text('Proforma')),
    body: _orders.isEmpty ? const Center(child: Text('No orders yet.'))
        : RefreshIndicator(onRefresh: _load, child: ListView.builder(
      padding: const EdgeInsets.all(12), itemCount: _orders.length,
      itemBuilder: (_, i) {
        final o = _orders[i];
        final name = (o['customerName'] as String? ?? '').isNotEmpty ? o['customerName'] as String : 'Order #${o['id']}';
        return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Date: ${DatabaseHelper.formatDateString(o['createdDate'] as String? ?? '')}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.visibility_outlined), tooltip:'Preview', onPressed: () => _openPdf(o['id'] as int)),
            IconButton(icon: const Icon(Icons.share_outlined),      tooltip:'Share',   onPressed: () => _openPdf(o['id'] as int, share:true)),
            IconButton(icon: const Icon(Icons.chevron_right),       tooltip:'Details', onPressed: () => Navigator.push(context, MaterialPageRoute(builder:(_) => OrderDetailsScreen(orderId: o['id'] as int)))),
          ]),
        ));
      },
    )),
  );
}

// =================================================
// Final Invoices Screen
// =================================================
class FinalInvoicesScreen extends StatefulWidget {
  const FinalInvoicesScreen({super.key});
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
    appBar: AppBar(title: const Text('Invoice')),
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
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.request_quote)),
              title: Text(g.contractor.isNotEmpty ? g.contractor : 'Invoice #${g.orderId}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                'Invoice #${g.orderId}  •  Returned: ${_lastReturnDate(g)}\n'
                    'Billed: $curr${billed.toStringAsFixed(0)}  •  '
                    '${balance > 0 ? 'Due' : balance < 0 ? 'Refund' : 'Clear'}: $curr${balance.abs().toStringAsFixed(0)}',
              ),
              isThreeLine: true,
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.visibility_outlined), tooltip:'Preview', onPressed: () => _openPdf(g.orderId!)),
                IconButton(icon: const Icon(Icons.share_outlined),      tooltip:'Share',   onPressed: () => _openPdf(g.orderId!, share:true)),
                IconButton(icon: const Icon(Icons.chevron_right),       tooltip:'Details', onPressed: () => Navigator.push(context, MaterialPageRoute(builder:(_) => OrderDetailsScreen(orderId: g.orderId!)))),
              ]),
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
    final grandTotal = _rentals.fold<double>(0, (s, r) => s + ((r['qty'] as int? ?? 0) * ((r['rentalRate'] as num?)?.toDouble() ?? 0.0)));
    return Scaffold(
      appBar: AppBar(title: Text('Order #${widget.orderId}')),
      body: _rentals.isEmpty ? const Center(child: Text('No items in this order.'))
          : Column(children: [
        Expanded(child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: _rentals.length, itemBuilder: (_, i) {
          final r=_rentals[i]; final qty=r['qty'] as int? ?? 0; final rate=(r['rentalRate'] as num?)?.toDouble()??0.0;
          return Card(margin:const EdgeInsets.only(bottom:8), child:ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(r['itemName']??'', style:const TextStyle(fontWeight:FontWeight.bold)),
            subtitle: Text('Qty: $qty  *  Rate: $curr${rate.toStringAsFixed(2)}/day\nCheckout: ${DatabaseHelper.formatDateString(r['checkoutDate'] as String?)}'),
            isThreeLine: true,
            trailing: Text('$curr${(qty*rate).toStringAsFixed(2)}', style:const TextStyle(fontWeight:FontWeight.bold)),
          ));
        })),
        Container(width:double.infinity, color:Theme.of(context).colorScheme.surfaceContainerHighest, padding:const EdgeInsets.symmetric(horizontal:16,vertical:12),
            child:Text('Grand Total: $curr${grandTotal.toStringAsFixed(2)}/day', style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold), textAlign:TextAlign.right)),
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

        const Divider(height: 1),

        // ====================================
        // DASHBOARD
        // ====================================
        _sectionHeader('DASHBOARD'),

        SwitchListTile(
          secondary: const Icon(Icons.leaderboard_outlined, color: Colors.orange),
          title: const Text('Top Customers by Revenue'),
          subtitle: const Text('Show/hide Top 5 revenue list on dashboard'),
          value: s.showTopCustomersByRevenue,
          onChanged: s.setShowTopCustomersByRevenue,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.history, color: Colors.orange),
          title: const Text('Payment History Time Stamp'),
          subtitle: const Text('Show/hide time (AM/PM) in Payment History entries'),
          value: s.showPaymentHistoryTime,
          onChanged: s.setShowPaymentHistoryTime,
        ),

        const Divider(height: 1),

        // ====================================
        // NOTIFICATIONS
        // ====================================
        _sectionHeader('NOTIFICATIONS'),

        SwitchListTile(
          secondary: const Icon(Icons.alarm_on, color: Colors.orange),
          title: const Text('Overdue Rental Alert'),
          subtitle: Text('Alert when a rental exceeds ${s.overdueDays} days'),
          value: s.notifyOverdue,
          onChanged: s.setNotifyOverdue,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.payments_outlined, color: Colors.orange),
          title: const Text('Pending Payment Reminder'),
          subtitle: const Text('Remind about unsettled returned invoices'),
          value: s.notifyPendingPayments,
          onChanged: s.setNotifyPendingPayments,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.undo, color: Colors.orange),
          title: const Text('Refund Wait Alert'),
          subtitle: const Text('Alert when a customer has been waiting too long for a refund'),
          value: s.notifyRefundWait,
          onChanged: s.setNotifyRefundWait,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.event_note_outlined, color: Colors.orange),
          title: const Text('Rental Anniversary Alert'),
          subtitle: const Text('Notify on milestone days - 7, 14, 30, 60...'),
          value: s.notifyAnniversary,
          onChanged: s.setNotifyAnniversary,
        ),

        const Divider(height: 1),

        // ====================================
        // BACKUP & DATA
        // ====================================
        _sectionHeader('BACKUP & DATA'),

        ListTile(
          leading: const Icon(Icons.schedule_outlined, color: Colors.amber),
          title: const Text('Auto-Backup Schedule'),
          subtitle: const Text('Automatic database backup to local storage'),
          trailing: DropdownButton<String>(
            value: s.autoBackupSchedule,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'off',     child: Text('Off')),
              DropdownMenuItem(value: 'daily',   child: Text('Daily')),
              DropdownMenuItem(value: 'weekly',  child: Text('Weekly')),
              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
            ],
            onChanged: (v) { if (v != null) s.setAutoBackupSchedule(v); },
          ),
        ),
        _infoBox('Background scheduling will be activated in a future update. Manual backup is available via the drawer menu.', color: Colors.amber[800]),

        const Divider(height: 1, indent: 16, endIndent: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('SCHEDULED DIGESTS',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.4, color: Colors.amber[600])),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.summarize_outlined, color: Colors.amber),
          title: const Text('Daily Summary'),
          subtitle: const Text('A morning snapshot of active rentals and pending collections'),
          value: s.notifySummary,
          onChanged: s.setNotifySummary,
        ),
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
          subtitle: const Text('More languages coming soon'),
          trailing: DropdownButton<String>(
            value: s.language,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'English', child: Text('English')),
              DropdownMenuItem(value: 'Hindi',   child: Text('Hindi')),
            ],
            onChanged: (v) { if (v != null) s.setLanguage(v); },
          ),
        ),

        const Divider(height: 1),

        // ====================================
        // ABOUT
        // ====================================
        _sectionHeader('ABOUT'),

        const ListTile(
          leading: Icon(Icons.construction, color: Colors.amber),
          title: Text('Rental Manager', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Version 2.0.0  |  Database v17'),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }
}
