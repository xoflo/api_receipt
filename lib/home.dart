import 'dart:async';
import 'package:apireceipt_new/receipt.dart';
import 'package:date_picker_plus/date_picker_plus.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:thermal_printer/thermal_printer.dart';



class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.token});

  final String token;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {


  int pageNumber = 1;
  String outletName = "CIGAR SECTION";


  DateTime startTime = DateTime.now();
  DateTime endTime = DateTime.now();


  int paperSize = 1;

  bool showUnprinted = true;


  TextEditingController cashierController = TextEditingController();


  final printerManager = PrinterManager.instance;
  List<PrinterDevice> usbDevices = [];
  PrinterDevice? selectedUsb;



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: FutureBuilder(
          future:
          scanUsb(), builder: (BuildContext context, AsyncSnapshot<void> snapshot) {

            return snapshot.connectionState == ConnectionState.done ? StatefulBuilder(
              builder:
                  (BuildContext context, void Function(void Function()) setState) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Sale List",
                              style: TextStyle(
                                  fontSize: 40,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.left)),
                    ),
                    Divider(),
                    Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Align(
                        alignment: Alignment.center,
                        child: FutureBuilder(
                            future: getOutlets(),
                            builder: (BuildContext context,
                                AsyncSnapshot<dynamic> snapshot) {
                              if (!snapshot.hasData) {
                                return Center(
                                  child: Container(
                                    height: 50,
                                    width: 50,
                                    child: CircularProgressIndicator(

                                    ),
                                  ),
                                );
                              }

                              return snapshot.connectionState == ConnectionState
                                  .done
                                  ? Container(
                                height: 50,
                                width: 600,
                                child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: snapshot.data!.length,
                                    itemBuilder: (context, i) {
                                      return Card(
                                        color:
                                        snapshot.data[i]["Name"] == outletName
                                            ? Colors.blue
                                            : null,
                                        child: InkWell(
                                            onTap: () {
                                              outletName =
                                              "${snapshot.data[i]["Name"]}";
                                              setState(() {});
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Text(
                                                  snapshot.data[i]["Name"],
                                                  style: TextStyle(
                                                      color: snapshot.data[i]
                                                      ["Name"] ==
                                                          outletName
                                                          ? Colors.white
                                                          : Colors.black)),
                                            )),
                                      );
                                    }),
                              )
                                  : Container(
                                height: 50,
                                width: 50,
                                child: CircularProgressIndicator(),
                              );
                            }),
                      ),
                    ),
                    outletName == ""
                        ? Container(
                        height: 100,
                        width: 100,
                        child: Center(
                            child: Text("Select Outlet",
                                style: TextStyle(color: Colors.grey))))
                        : FutureBuilder(
                      future: generateInvoice(
                          pageNumber, outletName, startTime, endTime),
                      builder: (BuildContext context,
                          AsyncSnapshot<dynamic> snapshot) {
                        return snapshot.connectionState ==
                            ConnectionState.waiting
                            ? Container(
                          height: 50,
                          width: 50,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.blue,
                            ),
                          ),
                        ) : Builder(builder: (context) {
                          final List<dynamic> data = snapshot.data;


                          return Column(
                            children: [
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  spacing: 10,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      height: 50,
                                      width: 150,
                                      child: TextField(
                                        decoration:
                                        InputDecoration(
                                            hintText:
                                            'Cashier Name'),
                                        controller:
                                        cashierController,
                                        maxLength: 15,
                                      ),
                                    ),
                                    ElevatedButton(onPressed: () async {
                                      final date = await showRangePickerDialog(
                                        context: context,
                                        minDate: DateTime(2021, 1, 1),
                                        maxDate: DateTime(2050, 12, 31),
                                      );

                                      if (date?.start != null &&
                                          date?.end != null) {
                                        startTime = date!.start;
                                        endTime = date!.end;

                                        setState(() {

                                        });
                                      }
                                    },
                                        child: Text(startTime == null
                                            ? "Filter Date"
                                            : "${DateFormat.yMMMMd().format(
                                            startTime)} - ${DateFormat
                                            .yMMMMd()
                                            .format(endTime!)}")),

                                    StatefulBuilder(builder: (context, setState) {
                                      return ElevatedButton(onPressed: () {
                                        showDialog(context: context, builder: (_) => AlertDialog(
                                          content: Container(
                                              height: 400,
                                              width: 400,
                                              child: ListView.builder(
                                                  itemCount: usbDevices.length,
                                                  itemBuilder: (context, i) {
                                                return ListTile(
                                                  title: Text(usbDevices[i].name),
                                                  onTap: () async {
                                                    await selectPrinter(usbDevices[i]);
                                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connected to ${usbDevices[i].name}")));
                                                    Navigator.pop(context);
                                                  },
                                                );
                                              })
                                          ),
                                        ));
                                      }, child: Text(selectedUsb == null ? "Select Printer" : selectedUsb!.name));

                                    }),


                                    /*
                                   StatefulBuilder(builder: (context, setState) {
                                   return ElevatedButton(onPressed: () {
                                     showDialog(context: context, builder: (_) => AlertDialog(
                                       content: SizedBox(
                                         height: 400,
                                         width: 300,
                                         child: FutureBuilder(
                                           future: PrintBluetoothThermal.pairedBluetooths,
                                           builder: (BuildContext context, AsyncSnapshot<List<BluetoothInfo>> devices) {
                                             return devices.connectionState == ConnectionState.done ? Container(
                                               height: 300,
                                               child: devices.data!.isEmpty ? Center(
                                                 child: Text(
                                                   "Ensure Bluetooth is turned on and paired with Printer",
                                                   textAlign: TextAlign.center,),
                                               ) : ListView.builder(
                                                   itemCount: devices.data!.length,
                                                   itemBuilder: (context, i) {
                                                 return ListTile(
                                                   title: Text(devices.data![i].name),
                                                   onTap: () async {
                                                     showDialog(
                                                         barrierDismissible: false,
                                                         context: context, builder: (_) => AlertDialog(
                                                       content: Container(
                                                         height: 100,
                                                         width: 100,
                                                         child: Center(
                                                           child: CircularProgressIndicator(),
                                                         ),
                                                       ),
                                                     ));

                                                     await PrintBluetoothThermal.disconnect;
                                                     await PrintBluetoothThermal.connect(macPrinterAddress: devices.data![i].macAdress);

                                                     Navigator.pop(context);
                                                     Navigator.pop(context);

                                                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connected to ${devices.data![i].name}")));
                                                   },
                                                 );
                                               }),
                                             ) : Center(
                                               child: Container(
                                                 height: 50,
                                                 width: 50,
                                                 child: CircularProgressIndicator(),
                                               ),
                                             );
                                           },
                                         ),
                                       ),
                                     ));
                                   }, child: StreamBuilder(stream: checkConnection(),
                                   builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                                     return Text(snapshot.data == true ? "Connected" : "Select Printer");
                                   } ));
                                 }),

                                  */



                                    TextButton(onPressed: () {
                                      showUnprinted = !showUnprinted;
                                      setState((){});
                                    }, child: Text(showUnprinted == true ? "Show All" : "Show Unprinted")),

                                    StatefulBuilder(builder: (context, setState) {
                                      return TextButton(onPressed: () {
                                        paperSize = paperSize == 1 ? 0 : 1;
                                        setState(() {});
                                      }, child: Text("Paper Size: ${paperSize == 1 ? "mm72" : "mm58"}"));
                                    })
                                  ],
                                ),
                              ),
                              Container(
                                height: 600,
                                width: 500,
                                child: Padding(
                                  padding: const EdgeInsets.all(30.0),
                                  child: ListView.builder(
                                      itemCount: data.length,
                                      itemBuilder: (context, i) {
                                        final Receipt receipt =
                                        Receipt.fromJSON(data[i]);

                                        if (i == 0) {
                                          print(data[i]);
                                        }


                                        return showUnprinted == true && isAlreadyPrinted(receipt.salesInvoiceNumber) ? SizedBox() : InkWell(
                                          child: Card(
                                            child: Container(
                                                height: 100 +
                                                    (20 *
                                                        receipt
                                                            .variants.length
                                                            .toDouble()),
                                                child: Padding(
                                                  padding:
                                                  const EdgeInsets.all(
                                                      10.0),
                                                  child: Column(
                                                      crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .start,
                                                      children: [
                                                        Text(
                                                            "${receipt
                                                                .dateFormatted}",
                                                            style: TextStyle(
                                                                fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                        Text(
                                                            "S.I#: ${receipt
                                                                .salesInvoiceNumber}"),
                                                        Text("Items:"),
                                                        Container(
                                                          height: 20 *
                                                              receipt
                                                                  .variants
                                                                  .length
                                                                  .toDouble(),
                                                          child: ListView
                                                              .builder(
                                                              itemCount: receipt
                                                                  .variants
                                                                  .length,
                                                              itemBuilder:
                                                                  (context,
                                                                  x) {
                                                                return Text(
                                                                    "${receipt
                                                                        .variants[x]
                                                                        .name}");
                                                              }),
                                                        ),
                                                        Text(
                                                            "Total Amount: ${receipt
                                                                .gross}"),
                                                      ]),
                                                )),
                                          ),
                                          onTap: () {
                                            printReceiptUSB(receipt, cashierController.text);
                                          },
                                        );
                                      }),
                                ),
                              ),
                            ],
                          );
                        });
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                            onPressed: () {
                              if (pageNumber == 1) {
                                return;
                              } else {
                                pageNumber -= 1;
                                setState(() {});
                              }
                            },
                            icon: Icon(Icons.arrow_left)),
                        SizedBox(width: 5),
                        Text("$pageNumber"),
                        SizedBox(width: 5),
                        IconButton(
                            onPressed: () {
                              pageNumber += 1;
                              setState(() {});
                            },
                            icon: Icon(Icons.arrow_right)),
                      ],
                    )
                  ],
                );
              },
            ) : Center(
              child: Container(
                  height: 50,
                  width: 50,
                  child: CircularProgressIndicator()),
            );
        },
        ),
      ),
    );
  }

  Future getOutlets() async {
    try {
      final uri = Uri.parse(
          'https://myshop.dealpos.com/api/v3/Outlet'
      ).replace(queryParameters: {
        'Access': 'All',
        'Suspended': 'false',
      });

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Accept': 'application/json',
        },
      );

      print(response.statusCode);

      final dynamic data = await jsonDecode(response.body);

      print(data);

      return data;
    } catch (e) {
      print(e);
    }
  }

  generateInvoice(int page, String outletName, DateTime startTime,
      DateTime endTime) async {
    try {
      final uri = Uri.parse("https://myshop.dealpos.com/api/v3/Report");

      final headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${widget.token}"
      };

      final body = jsonEncode({
        "Outlet": "$outletName",
        "From": startTime.toIso8601String(),
        "To": endTime.toIso8601String(),
        "PageNumber": "$page",
        "PageSize": "10"
      });

      final request = await http.post(uri, headers: headers, body: body);

      print(request.statusCode);

      final dynamic data = await jsonDecode(request.body);

      print(data["Data"]);

      return await data["Data"];
    } catch (e) {
      print(e);
    }
  }

  printReceiptUSB(Receipt receipt, String cashier) async {

    if (selectedUsb == null) {
      return;
    } else {
      final bytes = await generateReceipt(receipt, cashier);



      if (selectedUsb!.name.toString().toUpperCase() == "EPSON TM-U220 RECEIPT") {
        final result = await printerManager.send(
          type: PrinterType.usb,
          bytes: bytes,
        );

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Receipt Printed")));
        savePrinted(receipt.salesInvoiceNumber);
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please Select Only Designated Printer")));
      }

    }


  }


  Future<void> printReceiptBT(Receipt receipt, String cashier) async {
    bool conecctionStatus = await PrintBluetoothThermal.connectionStatus;
    if (conecctionStatus) {
      List<int> ticket = await generateReceipt(receipt, cashier);
      final result = await PrintBluetoothThermal.writeBytes(ticket);

      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Receipt Printed")));
        savePrinted(receipt.salesInvoiceNumber);
        setState(() {});
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ensure Bluetooth is turned on and paired with Printer")));
    }
  }


  Future<List<int>> generateReceipt(Receipt receipt, String cashier) async {
    List<int> bytes = [];

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm72, profile);

    // ---------------------------------
    // HARD RESET (clears everything)
    // ---------------------------------
    bytes += [27, 64]; // ESC @
    bytes += [27, 116, 0]; // ESC t 0 (code table default)

    // ---------------------------------
    // SAFE WIDTH SETTINGS (TM-U220D)
    // ---------------------------------
    const int leftWidth = 28;
    const int rightWidth = 10;

    String twoCol(String left, String right) {
      if (left.length > leftWidth) {
        left = left.substring(0, leftWidth);
      }
      if (right.length > rightWidth) {
        right = right.substring(0, rightWidth);
      }

      return left.padRight(leftWidth) +
          right.padLeft(rightWidth);
    }

    PosStyles normal = PosStyles(
      align: PosAlign.left,
      fontType: PosFontType.fontB,
    );

    PosStyles right = PosStyles(
      align: PosAlign.right,
      fontType: PosFontType.fontB,
    );

    PosStyles center = PosStyles(
      align: PosAlign.center,
      fontType: PosFontType.fontB,
    );

    PosStyles boldCenter = PosStyles(
      align: PosAlign.center,
      bold: true,
      fontType: PosFontType.fontB,
    );

    // ---------------------------------
    // HEADER
    // ---------------------------------
    bytes += generator.text('YBS SHOPWORLD, INC.', styles: boldCenter);
    bytes += generator.text('DONASCO ST. BAG-ONG LUNGSOD,', styles: center);
    bytes += generator.text('TANDAG CITY, SURGAO DEL SUR', styles: center);
    bytes += generator.text('VAT REG TIN: 430-923-946-000', styles: center);
    bytes += generator.text('MIN: 221025020038061', styles: center);
    bytes += generator.text('SERIAL NO: 50026B7783F19B54', styles: center);

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

    bytes += generator.text('-------------------------------------', styles: center);
    bytes += generator.text(twoCol('Item / Barcode   QTY', "Amount"), styles: normal);
    bytes += generator.text('-------------------------------------', styles: center);

    bytes += generator.emptyLines(1);

    // ---------------------------------
    // ITEMS
    // ---------------------------------
    double totalQty = 0.00;
    
    for (var product in receipt.variants) {
      String name = product.name ?? '';

      // Trim product name safely to full width (38)
      if (name.length > (leftWidth + rightWidth)) {
        name = name.substring(0, leftWidth + rightWidth);
      }

      bytes += generator.text(name, styles: normal);
      
      totalQty += product.quantity;

      double total = product.price * product.quantity;

      bytes += generator.text(
        twoCol(
          "    ${product.price.toStringAsFixed(2)} x ${product.quantity.toStringAsFixed(2)}",
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
    bytes += generator.text(
      twoCol('TOTAL AMOUNT:', receipt.gross.toStringAsFixed(2)),
      styles: normal,
    );

    bytes += generator.text(
      twoCol('TENDER AMOUNT:', receipt.gross.toStringAsFixed(2)),
      styles: normal,
    );

    bytes += generator.text(
      twoCol('CHANGE AMOUNT:', '0.00'),
      styles: normal,
    );

    bytes += generator.text(
      twoCol("", "---------"),
      styles: normal,
    );

    bytes += generator.text(
      twoCol('VATABLE SALES:', receipt.vatableSales),
      styles: normal,
    );

    bytes += generator.text(
      twoCol('VAT AMOUNT:', receipt.vatAmount),
      styles: normal,
    );

    bytes += generator.text(
      twoCol('NON-VATABLE SALES:', '0.00'),
      styles: normal,
    );

    bytes += generator.text(
      twoCol('VAT-EXEMPT SALES:', '0.00'),
      styles: normal,
    );

    bytes += generator.text(
      twoCol('ZERO-RATED SALES:', '0.00'),
      styles: normal,
    );


    bytes += generator.text('-------------------------------------', styles: center);

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

  String twoCol(String left, String right) {
    const int width = 42;
    int space = width - left.length - right.length;
    if (space < 1) space = 1;
    return left + ' ' * space + right;
  }


  Stream<bool> checkConnection() {
    return Stream.periodic(Duration(seconds: 30))
        .asyncMap((_) async {
      return await PrintBluetoothThermal.connectionStatus;
    });
  }

  bool isAlreadyPrinted(String siNumber) {
    final box = Hive.box('printedInvoices');
    return box.containsKey(siNumber);
  }

  void savePrinted(String siNumber) {
    final box = Hive.box('printedInvoices');
    box.put(siNumber, true);
  }



  Future<void> scanUsb() async {
    usbDevices.clear();

    printerManager
        .discovery(type: PrinterType.usb)
        .listen((device) {

          print(device.name);
      usbDevices.add(device);
    });


    await selectPrinter(usbDevices[0]);
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
    setState(() {});
  }

}