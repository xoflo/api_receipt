import 'package:intl/intl.dart';


class Receipt {
  dynamic salesInvoiceNumber;
  dynamic date;
  dynamic dateFormatted;
  dynamic cashier;
  dynamic tid = 'T01';
  dynamic client;
  dynamic transactionType;
  List<Product> variants = [];
  dynamic payments;
  dynamic gross;
  dynamic taxType;
  dynamic vatableSales;
  dynamic vatAmount;

  Receipt(this.salesInvoiceNumber, this.date, this.cashier, this.tid, this.client, this.transactionType, this.variants, this.payments, this.gross);

  Receipt.fromJSON(dynamic json) {
    this.salesInvoiceNumber = "00000000${json['Number']}";
    this.date = json['Created'];
    this.dateFormatted = DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(json['Created']));
    this.client = json['Customer']['Name'];
    this.transactionType = json['Payments'] == null ? "" : json['Payments'][0]['Method'];
    this.gross = json['Gross'];
    this.taxType = json['TaxType'];

    List<dynamic> variants = json['Variants'];
    List<Product> realVariants = [];
    for (int i = 0; i < variants.length; i++) {
      realVariants.add(Product.fromJSON(variants[i]));
    }

    this.variants = realVariants;

    print("gross: $gross");


    this.vatableSales = (double.parse(gross.toString()) / 1.12).toStringAsFixed(2);
    this.vatAmount = (double.parse(vatableSales.toString()) * .12).toStringAsFixed(2);
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

  Product(this.name, this.code, this.quantity, this.unitQuantity, this.cost, this.price, this.priceOriginal, this.netPrice);

  Product.fromJSON(dynamic json) {
    this.name = json['Name'];
    this.code = json['Code'];
    this.quantity = json['Quantity'];
    this.unitQuantity = json['UnitQuantity'];
    this.cost = json['Cost'];
    this.price = json['Price'];
    this.priceOriginal = json['PriceOriginal'];
    this.netPrice = json['NetPrice'];
  }

}