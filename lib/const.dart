

// PDF SAVED


/*

  printFunc(Receipt receipt, String cashier) async {
    var f = NumberFormat("###,###.0#", "en_US");

    pdf.addPage(pw.Page(
        theme: pw.ThemeData(defaultTextStyle: pw.TextStyle(fontSize: 10)),
        pageFormat: PdfPageFormat(215, (500 + (receipt.variants.length * 23))),
        build: (pw.Context context) {
          return pw.Padding(
              padding: pw.EdgeInsets.all(10),
              child: pw.Column(children: [
                pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text("WHOLESALE SECTION",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text("YBS SHOPWORLD, INC."),
                      pw.Text("DONASCO ST. BAG-ONG LUNGSOD,",
                          textAlign: pw.TextAlign.center),
                      pw.Text("TANDAG CITY, SURIGAO DEL SUR",
                          textAlign: pw.TextAlign.center),
                      pw.Text("VAT REG TIN: 430-923-946-000"),
                      pw.Text("MIN: 221025020038061"),
                      pw.Text("SERIAL NO: 50026B7783F19B54"),
                      pw.SizedBox(height: 10),
                      pw.Text("OFFICIAL RECEIPT"),
                      pw.SizedBox(height: 10),
                    ]),
                pw.Row(children: [
                  pw.Text('S.I#:  ${receipt.salesInvoiceNumber}'),
                  pw.Text('  Cashier: $cashier'),
                ]),
                pw.Row(children: [
                  pw.Text('Date:   ${receipt.dateFormatted}'),
                ]),
                pw.Row(children: [
                  pw.Text('TID:  ${receipt.tid}'),
                  pw.Text('  Trans type: ${receipt.transactionType}'),
                ]),
                pw.Row(children: [
                  pw.Text('Client: ${receipt.client}'),
                ]),
                pw.SizedBox(height: 5),
                pw.Divider(),
                pw.SizedBox(height: 5),
                pw.ListView.builder(
                    itemBuilder: (context, i) {
                      return pw.Column(children: [
                        pw.Row(children: [
                          nameFormat(receipt.variants[i].name.toString()),
                          pw.Spacer(),
                          pw.Text('v'),
                        ]),
                        pw.Row(children: [
                          pw.Text(''),
                          pw.Spacer(),
                          pw.Text(
                              '${receipt.variants[i].price}x${receipt.variants[i].unitQuantity}    ${f.format(double.parse(receipt.variants[i].price.toString()) * double.parse(receipt.variants[i].unitQuantity.toString()))}'),
                        ]),
                      ]);
                    },
                    itemCount: receipt.variants.length),
                pw.SizedBox(height: 5),
                pw.Divider(),
                pw.SizedBox(height: 5),
                pw.Row(children: [
                  pw.Text('TOTAL AMOUNT:'),
                  pw.Spacer(),
                  pw.Text('${receipt.gross}'),
                ]),
                pw.Row(children: [
                  pw.Text('TENDER AMOUNT:'),
                  pw.Spacer(),
                  pw.Text('${receipt.gross}'),
                ]),
                pw.Row(children: [
                  pw.Text('CHANGE AMOUNT:'),
                  pw.Spacer(),
                  pw.Text('000.00'),
                ]),
                pw.Row(children: [
                  pw.Text(''),
                  pw.Spacer(),
                  pw.Text('----------------'),
                ]),
                pw.Row(children: [
                  pw.Text('VATABLE SALES:'),
                  pw.Spacer(),
                  pw.Text('${receipt.vatableSales}'),
                ]),
                pw.Row(children: [
                  pw.Text('VAT AMOUNT:'),
                  pw.Spacer(),
                  pw.Text('${receipt.vatAmount}'),
                ]),
                pw.Row(children: [
                  pw.Text('NON-VATABLE SALES:'),
                  pw.Spacer(),
                  pw.Text('000.00'),
                ]),
                pw.Row(children: [
                  pw.Text('VAT-EXEMPT SALES:'),
                  pw.Spacer(),
                  pw.Text('000.00'),
                ]),
                pw.Row(children: [
                  pw.Text('ZERO-RATED SALES:'),
                  pw.Spacer(),
                  pw.Text('000.00'),
                ]),
                pw.SizedBox(height: 5),
                pw.Divider(),
                pw.SizedBox(height: 5),
                pw.Text("NAME: _________________________"),
                pw.Text("ADDRESS: ______________________"),
                pw.Text("TIN: _________________________"),
                pw.SizedBox(height: 5),
                pw.Text("POS45 ENTERPRISES"),
                pw.Text("BRGY. VALENCIA AURORA BLVD QC."),
                pw.Text("NON-VAT REG TIN: 902-732-994-000"),
                pw.Text("ACCREG: 25A9027329942018030881"),
                pw.Text("DATE ISSUED: JUNE 03, 2019"),
                pw.Text("PTU: FP102022-106-0352440-00000"),
                pw.Text("THIS SERVES AS AN OFFICIAL RECEIPT",
                    textAlign: pw.TextAlign.center),
              ])); // Center
        })); // Page

    try {
      /*
      var savedFile = await pdf.save();
      List<int> fileInts = List.from(savedFile);
      AnchorElement()
        ..href =
            "data:application/octet-stream;charset=utf-16le;base64,${base64.encode(fileInts)}"
        ..setAttribute(
            "download", "${DateTime.now().millisecondsSinceEpoch}.pdf")
        ..click();
       */

      /*

      await Printing.directPrintPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(), printer: Printer(url: url));
       */

    } catch (e) {
      print(e);
    }
  }

   nameFormat(String name) {
    switch (name.length) {
      case > 20 && < 25:
        return pw.Text('$name', textScaleFactor: 0.8);
      case > 25:
        return pw.Text('$name', textScaleFactor: 0.6);
      default:
        return pw.Text('$name');
    }
  }
   */
