import 'package:intl/intl.dart';

// Safe converters: API values can be null, int, double, or String.
double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}') ?? 0.0;
}

String _str(dynamic v) => v == null ? '' : v.toString();

class Receipt {
  dynamic salesInvoiceNumber;
  dynamic invoiceID;
  dynamic date;
  dynamic dateFormatted;
  dynamic cashier;
  dynamic tid = 'T01';
  dynamic client;
  dynamic transactionType;
  List<Product> variants = [];
  dynamic payments;
  dynamic paymentAmount;
  dynamic change;
  dynamic gross;
  dynamic taxType;
  dynamic vatableSales;
  dynamic vatAmount;

  Receipt(this.salesInvoiceNumber, this.date, this.cashier, this.tid, this.client,
      this.transactionType, this.variants, this.payments, this.gross, this.change);

  Receipt.fromJSON(dynamic json) {
    // "${null}" becomes the literal string "null", so guard it.
    salesInvoiceNumber = "00000000${_str(json['Number'])}";

    // Check the real key in the /Report response. If it's not 'InvoiceID',
    // this used to become "null" and getPaymentNote() would fail.
    invoiceID = _str(json['InvoiceID'] ?? json['ID']);

    date = _str(json['Created']);
    final parsed = DateTime.tryParse(date);
    dateFormatted = parsed == null ? '' : DateFormat('MMM d, yyyy h:mm a').format(parsed);

    final customer = json['Customer'];
    client = customer is Map ? _str(customer['Name']) : '';

    final pays = json['Payments'];
    final firstPay = (pays is List && pays.isNotEmpty) ? pays[0] : null;
    payments = pays;
    transactionType = firstPay == null ? '' : _str(firstPay['Method']);
    paymentAmount = firstPay == null ? 0.0 : _toDouble(firstPay['Amount']);

    gross = _toDouble(json['Gross']);
    taxType = json['TaxType'];

    final rawVariants = json['Variants'];
    variants = rawVariants is List
        ? rawVariants.map<Product>((v) => Product.fromJSON(v)).toList()
        : <Product>[];

    // VAT = gross - vatable so the two always add up to the total exactly.
    final vatable = double.parse((gross / 1.12).toStringAsFixed(2));
    vatableSales = vatable.toStringAsFixed(2);
    vatAmount = (gross - vatable).toStringAsFixed(2);
  }
}

class Product {
  dynamic name;
  dynamic code;
  dynamic quantity;
  dynamic unitQuantity;
  dynamic cost;
  dynamic price;
  dynamic priceOriginal;
  dynamic netPrice;

  Product(this.name, this.code, this.quantity, this.unitQuantity, this.cost, this.price,
      this.priceOriginal, this.netPrice);

  Product.fromJSON(dynamic json) {
    name = _str(json['Name']);
    code = _str(json['Code']);
    quantity = _toDouble(json['Quantity']);
    unitQuantity = _toDouble(json['UnitQuantity']);
    cost = _toDouble(json['Cost']);
    price = _toDouble(json['Price']);
    priceOriginal = _toDouble(json['PriceOriginal']);
    netPrice = _toDouble(json['NetPrice']);
  }
}