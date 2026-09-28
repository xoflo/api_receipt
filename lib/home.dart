import 'dart:async';
import 'dart:convert';

import 'package:apireceipt_new/receipt.dart';
import 'package:date_picker_plus/date_picker_plus.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:thermal_printer/thermal_printer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.token});

  final String token;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final settingsBox = Hive.box('settings');
  final invoiceBox = Hive.box('printedInvoices');

  int pageNumber = 1;
  String outletName = "WHOLESALE SECTION";

  DateTime startTime = DateTime.now();
  DateTime endTime = DateTime.now();

  int paperSize = 1;
  bool showUnprinted = true;
  bool hiddenSettings = false;

  TextEditingController cashierController = TextEditingController();

  final printerManager = PrinterManager.instance;
  List<PrinterDevice> usbDevices = [];
  PrinterDevice? selectedUsb;

  // Polling / rate-limit state.
  // The future and stream are created ONCE here (not inside build), so
  // setState no longer fires extra API calls.
  static const int pollSeconds = 10; // normal polling interval
  static const int backoffSeconds = 30; // interval after a 429
  late Future<void> _scanFuture;
  Stream<List<Receipt>>? _invoiceStream;
  int _streamGen = 0;
  List<Receipt> _lastReceipts = [];
  bool _rateLimited = false;

  @override
  void initState() {
    super.initState();
    _scanFuture = scanUsb();
    _rebuildStream();
  }

  @override
  void dispose() {
    _streamGen++; // stops the polling loop
    cashierController.dispose();
    super.dispose();
  }

  /// Call this only when page, date range, or sort changes (or on refresh).
  void _rebuildStream() {
    final gen = ++_streamGen;
    _invoiceStream = _poll(gen, pageNumber, outletName, startTime, endTime);
  }

  Stream<List<Receipt>> _poll(
      int gen, int page, String outlet, DateTime start, DateTime end) async* {
    while (mounted && gen == _streamGen) {
      final result = await generateInvoice(page, outlet, start, end);
      if (!mounted || gen != _streamGen) return;
      yield result;
      await Future.delayed(
          Duration(seconds: _rateLimited ? backoffSeconds : pollSeconds));
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: hiddenSettings
          ? Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
              onPressed: _showChangeAdminPin,
              child: const Icon(Icons.password)),
        ],
      )
          : const SizedBox(),
      body: GestureDetector(
        onLongPress: () => setState(() => hiddenSettings = !hiddenSettings),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: FutureBuilder(
            future: _scanFuture,
            builder: (context, scanSnap) {
              if (scanSnap.connectionState != ConnectionState.done) {
                return const Center(
                  child: SizedBox(
                      height: 50, width: 50, child: CircularProgressIndicator()),
                );
              }

              return Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Sale List",
                          style: TextStyle(
                              fontSize: 40,
                              color: Colors.black,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.left),
                    ),
                  ),
                  const Divider(),

                  // Outlet name is hardcoded, so no API call needed here.
                  Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Chip(
                      label: Text(outletName),
                      backgroundColor: Colors.blue,
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                  ),

                  _buildControls(),

                  IconButton(
                    tooltip: "Refresh",
                    onPressed: () {
                      _rebuildStream();
                      setState(() {});
                    },
                    icon: const Icon(Icons.refresh),
                  ),

                  StreamBuilder<List<Receipt>>(
                    stream: _invoiceStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox(
                          height: 50,
                          width: 50,
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: Colors.blue)),
                        );
                      }
                      // Hide receipts printed since the last poll right away
                      // (local Hive check, no API call).
                      final receipts = showUnprinted
                          ? snapshot.data!
                          .where((r) =>
                      !isAlreadyPrinted(r.salesInvoiceNumber))
                          .toList()
                          : snapshot.data!;
                      return _buildReceiptList(receipts);
                    },
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                          onPressed: () {
                            if (pageNumber == 1) return;
                            pageNumber -= 1;
                            _rebuildStream();
                            setState(() {});
                          },
                          icon: const Icon(Icons.arrow_left)),
                      const SizedBox(width: 5),
                      Text("$pageNumber"),
                      const SizedBox(width: 5),
                      IconButton(
                          onPressed: () {
                            pageNumber += 1;
                            _rebuildStream();
                            setState(() {});
                          },
                          icon: const Icon(Icons.arrow_right)),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 50,
            width: 140,
            child: TextField(
              decoration: const InputDecoration(hintText: 'Cashier Name'),
              controller: cashierController,
              maxLength: 15,
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final date = await showRangePickerDialog(
                context: context,
                minDate: DateTime(2021, 1, 1),
                maxDate: DateTime(2050, 12, 31),
              );
              if (date != null) {
                startTime = date.start;
                endTime = date.end;
                _rebuildStream();
                setState(() {});
              }
            },
            child: Text(
                "${DateFormat.yMMMMd().format(startTime)} - ${DateFormat.yMMMMd().format(endTime)}"),
          ),
          ElevatedButton(
            onPressed: _showPrinterDialog,
            child: Text(selectedUsb == null ? "Select Printer" : selectedUsb!.name),
          ),
          TextButton(
            onPressed: _toggleSort,
            child: Text(showUnprinted ? "Sort: To Print" : "Sort: All"),
          ),
          TextButton(
            onPressed: _toggleAutoPrint,
            child: Text("Autoprint: ${autoPrintOn ? "On" : "Off"}"),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptList(List<Receipt> receipts) {
    return SizedBox(
      height: 600,
      width: 500,
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: receipts.isEmpty
            ? const Center(
            child: Text("No invoice to print",
                style: TextStyle(color: Colors.grey)))
            : ListView.builder(
          itemCount: receipts.length,
          itemBuilder: (context, i) {
            final r = receipts[i];
            return InkWell(
              onTap: () async {
                await printReceiptUSB(r, cashierController.text);
              },
              child: Card(
                child: SizedBox(
                  height: 120 + (20 * r.variants.length.toDouble()),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${r.dateFormatted}",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        Text("S.I#: ${r.salesInvoiceNumber}"),
                        const Text("Items:"),
                        SizedBox(
                          height: 20 * r.variants.length.toDouble(),
                          child: ListView.builder(
                            itemCount: r.variants.length,
                            itemBuilder: (context, x) =>
                                Text("${r.variants[x].name}"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Dialogs
  // ─────────────────────────────────────────────

  void _showChangeAdminPin() {
    final oldPass = TextEditingController();
    final newPass = TextEditingController();
    final newPassConfirm = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: SizedBox(
          height: 150,
          width: 200,
          child: Column(
            children: [
              TextField(
                  decoration: const InputDecoration(hintText: 'Old PIN'),
                  controller: oldPass),
              TextField(
                  obscureText: true,
                  decoration: const InputDecoration(hintText: 'New PIN'),
                  controller: newPass),
              TextField(
                  obscureText: true,
                  decoration: const InputDecoration(hintText: 'Confirm new PIN'),
                  controller: newPassConfirm),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (oldPass.text == await getAdminPIN()) {
                if (newPassConfirm.text == newPass.text) {
                  await setAdminPIN(newPass.text);
                  _snack("PIN Changed");
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } else {
                  _snack("New PIN does not match.");
                }
              } else {
                _snack("Old PIN Incorrect");
              }
            },
            child: const Text("Reset"),
          ),
        ],
      ),
    );
  }

  void _showPrinterDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: SizedBox(
          height: 400,
          width: 400,
          child: ListView.builder(
            itemCount: usbDevices.length,
            itemBuilder: (context, i) {
              return ListTile(
                title: Text(usbDevices[i].name),
                onTap: () async {
                  await selectPrinter(usbDevices[i]);
                  if (mounted) setState(() {});
                  _snack("Connected to ${usbDevices[i].name}");
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _toggleSort() {
    // Going back to "To Print" needs no PIN.
    if (!showUnprinted) {
      showUnprinted = true;
      _rebuildStream();
      setState(() {});
      return;
    }

    // Showing all receipts needs the admin PIN.
    final pass = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: SizedBox(
          height: 80,
          width: 120,
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(hintText: 'Admin Password'),
                obscureText: true,
                controller: pass,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (pass.text == await getAdminPIN()) {
                showUnprinted = false;
                _rebuildStream();
                if (mounted) setState(() {});
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } else {
                _snack("PIN Incorrect");
              }
            },
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }

  void _toggleAutoPrint() {
    final current = autoPrintOn;
    final pass = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: SizedBox(
          height: 100,
          width: 100,
          child: Column(
            children: [
              TextField(
                obscureText: true,
                controller: pass,
                decoration: const InputDecoration(hintText: 'Enter Admin Pin'),
              ),
              Text(current == false
                  ? "Ensure all receipts are printed before changing this setting."
                  : ""),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (pass.text == await getAdminPIN()) {
                await setAutoPrint(!current);
                _snack("Autoprint: ${!current ? "On" : "Off"}");
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) setState(() {});
              } else {
                _snack("PIN Incorrect");
              }
            },
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // API
  // ─────────────────────────────────────────────

  Future<List<Receipt>> generateInvoice(
      int page, String outletName, DateTime startTime, DateTime endTime) async {
    try {
      final response = await http.post(
        Uri.parse("https://myshop.dealpos.com/api/v3/Report"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}",
        },
        body: jsonEncode({
          "Outlet": outletName,
          "From": startTime.toIso8601String(),
          "To": endTime.toIso8601String(),
          "PageNumber": "$page",
          "PageSize": "10",
        }),
      );

      if (response.statusCode == 429) {
        // Rate limited: keep showing the last list and slow down.
        _rateLimited = true;
        debugPrint("429 rate limited - backing off to ${backoffSeconds}s");
        return _lastReceipts;
      }
      _rateLimited = false;

      if (response.statusCode != 200) {
        debugPrint("Report failed: ${response.statusCode}");
        return _lastReceipts;
      }

      final data = jsonDecode(response.body);
      final jsonData = data is Map ? data["Data"] : null;

      if (jsonData is! List) {
        _lastReceipts = [];
        return [];
      }

      // Parse each receipt on its own so one bad one doesn't kill the list.
      final receipts = <Receipt>[];
      for (final e in jsonData) {
        try {
          receipts.add(Receipt.fromJSON(e));
        } catch (err) {
          debugPrint("Skipped bad receipt: $err");
        }
      }

      final epoch = DateTime.fromMillisecondsSinceEpoch(0);
      receipts.sort((a, b) => (DateTime.tryParse(b.date.toString()) ?? epoch)
          .compareTo(DateTime.tryParse(a.date.toString()) ?? epoch));

      if (showUnprinted) {
        receipts.removeWhere((r) => isAlreadyPrinted(r.salesInvoiceNumber));

        if (autoPrintOn) {
          int printCount = 0;
          for (final r in List<Receipt>.from(receipts)) {
            final ok =
            await printReceiptUSB(r, cashierController.text, quiet: true);
            if (ok) printCount++;
          }
          receipts.removeWhere((r) => isAlreadyPrinted(r.salesInvoiceNumber));
          if (printCount != 0) _snack("Printed $printCount receipts");
        }
      }

      _lastReceipts = receipts;
      return receipts;
    } catch (e) {
      debugPrint("generateInvoice error: $e");
      return _lastReceipts;
    }
  }

  /// Total tender amount across all payments, or null if unavailable.
  Future<String?> getPaymentNote(String invoiceId) async {
    if (invoiceId.trim().isEmpty) return null;

    try {
      final response = await http.get(
        Uri.parse("https://myshop.dealpos.com/api/v3/Invoice/ID")
            .replace(queryParameters: {"ID": invoiceId.trim()}),
        headers: {
          "Authorization": "Bearer ${widget.token.trim()}",
          "Accept": "application/json",
        },
      );

      if (response.statusCode == 429) {
        _rateLimited = true;
        return null;
      }
      if (response.statusCode != 200) {
        debugPrint("Invoice request failed: ${response.statusCode}");
        return null;
      }

      final data = jsonDecode(response.body);
      final pays = data is Map ? data['Payments'] : null;
      if (pays is! List || pays.isEmpty) return null;

      double total = 0;
      for (final p in pays) {
        if (p is! Map) continue;
        final v = p['BuyerPaidAmount'] ?? p['Amount'];
        total += v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
      }
      return total > 0 ? total.toStringAsFixed(2) : null;
    } catch (e) {
      debugPrint("getPaymentNote error: $e");
      return null;
    }
  }

  /// Tender amount with fallbacks: invoice payments -> report payment -> gross.
  Future<String> _tenderAmount(Receipt receipt) async {
    final note = await getPaymentNote(receipt.invoiceID.toString());
    if (note != null) return note;

    final amt = receipt.paymentAmount is num
        ? (receipt.paymentAmount as num).toDouble()
        : 0.0;
    final gross =
    receipt.gross is num ? (receipt.gross as num).toDouble() : 0.0;
    return (amt > 0 ? amt : gross).toStringAsFixed(2);
  }

  // ─────────────────────────────────────────────
  // Printing
  // ─────────────────────────────────────────────

  /// Returns true if the receipt was sent to the printer.
  /// [quiet] = true for autoprint (no per-receipt snackbars).
  Future<bool> printReceiptUSB(Receipt receipt, String cashier,
      {bool quiet = false}) async {
    if (selectedUsb == null) {
      if (!quiet) _snack("Select a printer first");
      return false;
    }

    // Check the printer BEFORE calling the API, so a wrong printer
    // doesn't burn API calls every poll.
    final designated = (await getDesignatedPrinter()).toString().toUpperCase();
    if (selectedUsb!.name.toString().toUpperCase() != designated) {
      if (!quiet) _snack("Please Select Only Designated Printer");
      return false;
    }

    try {
      final paid = await _tenderAmount(receipt);
      final bytes = await generateReceipt(receipt, cashier, paid);

      await printerManager.send(type: PrinterType.usb, bytes: bytes);

      savePrinted(receipt.salesInvoiceNumber);
      if (!quiet) {
        _snack("Receipt Printed");
        if (mounted) setState(() {});
      }
      return true;
    } catch (e) {
      debugPrint("Print failed: $e");
      if (!quiet) _snack("Print failed: $e");
      return false;
    }
  }

  Future<void> printReceiptBT(Receipt receipt, String cashier) async {
    final bool connectionStatus = await PrintBluetoothThermal.connectionStatus;
    if (!connectionStatus) {
      _snack("Ensure Bluetooth is turned on and paired with Printer");
      return;
    }

    final paid = await _tenderAmount(receipt);
    final List<int> ticket = await generateReceipt(receipt, cashier, paid);
    final result = await PrintBluetoothThermal.writeBytes(ticket);

    if (result == true) {
      _snack("Receipt Printed");
      savePrinted(receipt.salesInvoiceNumber);
      if (mounted) setState(() {});
    }
  }

  Future<List<int>> generateReceipt(
      Receipt receipt, String cashier, String buyerPaidAmount) async {
    List<int> bytes = [];

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm72, profile);

    final double gross =
    receipt.gross is num ? (receipt.gross as num).toDouble() : 0.0;
    final double paid = double.tryParse(buyerPaidAmount) ?? gross;

    // ---------------------------------
    // HARD RESET (clears everything)
    // ---------------------------------
    bytes += [27, 64]; // ESC @
    bytes += [27, 116, 0]; // ESC t 0 (code table default)

    // ---------------------------------
    // SAFE WIDTH SETTINGS (TM-U220D)
    // ---------------------------------
    const int leftWidth = 30;
    const int rightWidth = 10;

    String twoCol(String left, String right) {
      if (left.length > leftWidth) left = left.substring(0, leftWidth);
      if (right.length > rightWidth) right = right.substring(0, rightWidth);
      return left.padRight(leftWidth) + right.padLeft(rightWidth);
    }

    const normal = PosStyles(align: PosAlign.left, fontType: PosFontType.fontB);
    const center =
    PosStyles(align: PosAlign.center, fontType: PosFontType.fontB);
    const boldCenter = PosStyles(
        align: PosAlign.center, bold: true, fontType: PosFontType.fontB);

    // ---------------------------------
    // HEADER
    // ---------------------------------
    bytes += generator.text('YBS SHOPWORLD, INC.', styles: boldCenter);
    bytes += generator.text('DONASCO ST. BAG-ONG LUNGSOD,', styles: center);
    bytes += generator.text('TANDAG CITY, SURIGAO DEL SUR', styles: center);
    bytes += generator.text('VAT REG TIN: 430-923-946-000', styles: center);
    bytes += generator.text('MIN: 22030216030993690', styles: center);
    bytes += generator.text('SERIAL NO: 30055796266', styles: center);

    // MIN CIGAR: 23072708254599051
    // SN CIGAR: 50026B7381DB1AEF

    // MIN WS: 22030216030993690
    // SN WS: 30055796266

    bytes += generator.emptyLines(1);
    bytes += generator.text('OFFICIAL RECEIPT', styles: center);
    bytes += generator.emptyLines(1);

    // ---------------------------------
    // INFO
    // ---------------------------------
    bytes += generator.emptyLines(1);
    bytes += generator.text('S.I#: ${receipt.salesInvoiceNumber}', styles: normal);
    bytes += generator.text('Cashier: $cashier', styles: normal);
    bytes += generator.text('Date: ${receipt.dateFormatted}', styles: normal);
    bytes += generator.text(
      'TID: ${receipt.tid}  Type: ${receipt.transactionType}',
      styles: normal,
    );
    bytes += generator.text('Client: ${receipt.client}', styles: normal);

    bytes += generator.emptyLines(1);

    bytes += generator.text('--------------------------------------', styles: center);
    bytes += generator.text(twoCol('Item / Barcode   QTY', "Amount"), styles: normal);
    bytes += generator.text('--------------------------------------', styles: center);

    bytes += generator.emptyLines(1);

    // ---------------------------------
    // ITEMS
    // ---------------------------------
    double totalQty = 0.00;

    for (var product in receipt.variants) {
      String name = (product.name ?? '').toString();

      // Trim product name safely to full width (40)
      if (name.length > (leftWidth + rightWidth)) {
        name = name.substring(0, leftWidth + rightWidth);
      }

      bytes += generator.text(name, styles: normal);

      final double price =
      product.price is num ? (product.price as num).toDouble() : 0.0;
      final double qty =
      product.quantity is num ? (product.quantity as num).toDouble() : 0.0;

      totalQty += qty;
      final double total = price * qty;

      bytes += generator.text(
        twoCol(
          "    ${price.toStringAsFixed(2)} x ${qty.toStringAsFixed(2)}",
          "${total.toStringAsFixed(2)} V",
        ),
        styles: normal,
      );
    }

    bytes += generator.text(
      twoCol("${totalQty.toStringAsFixed(2)}    Item(s)", "---------"),
      styles: normal,
    );

    // ---------------------------------
    // TOTALS
    // ---------------------------------
    bytes += generator.text(twoCol('TOTAL AMOUNT:', gross.toStringAsFixed(2)),
        styles: normal);
    bytes += generator.text(twoCol('TENDER AMOUNT:', paid.toStringAsFixed(2)),
        styles: normal);
    bytes += generator.text(
        twoCol('CHANGE AMOUNT:', (paid - gross).toStringAsFixed(2)),
        styles: normal);
    bytes += generator.text(twoCol("", "---------"), styles: normal);
    bytes += generator.text(
        twoCol('VATABLE SALES:', receipt.vatableSales.toString()),
        styles: normal);
    bytes += generator.text(twoCol('VAT AMOUNT:', receipt.vatAmount.toString()),
        styles: normal);
    bytes += generator.text(twoCol('NON-VATABLE SALES:', '0.00'), styles: normal);
    bytes += generator.text(twoCol('VAT-EXEMPT SALES:', '0.00'), styles: normal);
    bytes += generator.text(twoCol('ZERO-RATED SALES:', '0.00'), styles: normal);

    bytes += generator.text('---------------------------------------', styles: center);

    bytes += generator.emptyLines(1);

    // ---------------------------------
    // CUSTOMER DETAILS
    // ---------------------------------
    bytes += generator.text('NAME: __________________________', styles: center);
    bytes += generator.text('ADDRESS: _______________________', styles: center);
    bytes += generator.text('TIN: ___________________________', styles: center);

    bytes += generator.emptyLines(1);

    // ---------------------------------
    // FOOTER
    // ---------------------------------
    bytes += generator.text('POS45 ENTERPRISES', styles: center);
    bytes += generator.text('BRGY. VALENCIA AURORA BLVD QC.', styles: center);
    bytes += generator.text('NON-VAT REG TIN: 902-732-994-000', styles: center);
    bytes += generator.text('ACCREG: 25A9027329942018030881', styles: center);
    bytes += generator.text('DATE ISSUED: JUNE 03, 2019', styles: center);
    bytes += generator.text('PTU: FP102022-106-0352440-00000', styles: center);
    bytes += generator.text('THIS SERVES AS AN OFFICIAL RECEIPT', styles: center);

    bytes += generator.emptyLines(6);

    // Force line feed
    bytes += [10];

    // Small print buffer flush (print and feed 1 line)
    bytes += [27, 100, 1]; // ESC d 1

    // ---------------------------------
    // FINAL HARD RESET
    // ---------------------------------
    bytes += [27, 64]; // ESC @

    return bytes;
  }

  // ─────────────────────────────────────────────
  // Settings / storage
  // ─────────────────────────────────────────────

  Stream<bool> checkConnection() {
    return Stream.periodic(const Duration(seconds: 30))
        .asyncMap((_) async => await PrintBluetoothThermal.connectionStatus);
  }

  bool isAlreadyPrinted(dynamic siNumber) {
    return invoiceBox.containsKey(siNumber.toString());
  }

  void savePrinted(dynamic siNumber) {
    invoiceBox.put(siNumber.toString(), true);
  }

  bool get autoPrintOn =>
      settingsBox.get('autoPrint', defaultValue: false) == true;

  Future<void> setAutoPrint(bool value) async {
    await settingsBox.put('autoPrint', value);
  }

  Future<void> setDesignatedPrinter(String printerName) async {
    await settingsBox.put('designatedPrinter', printerName);
  }

  Future<bool> getAutoPrint() async => autoPrintOn;

  Future<String> getDesignatedPrinter() async {
    return settingsBox
        .get('designatedPrinter', defaultValue: "EPSON TM-U220 RECEIPT")
        .toString();
  }

  Future<String> getAdminPIN() async {
    return settingsBox.get('pinAdmin', defaultValue: "admin").toString();
  }

  Future<void> setAdminPIN(String value) async {
    await settingsBox.put('pinAdmin', value);
  }

  // ─────────────────────────────────────────────
  // USB printer
  // ─────────────────────────────────────────────

  Future<void> scanUsb() async {
    usbDevices.clear();

    printerManager.discovery(type: PrinterType.usb).listen((device) async {
      usbDevices.add(device);

      if (device.name.toString().toUpperCase() ==
          (await getDesignatedPrinter()).toUpperCase()) {
        await selectPrinter(device);
        if (mounted) setState(() {});
      }
    });
  }

  Future<void> selectPrinter(PrinterDevice device) async {
    await printerManager.disconnect(type: PrinterType.usb);
    selectedUsb = device;

    await printerManager.connect(
      type: PrinterType.usb,
      model: UsbPrinterInput(
        name: selectedUsb!.name,
        vendorId: selectedUsb!.vendorId,
        productId: selectedUsb!.productId,
      ),
    );
  }
}