import 'package:apireceipt_new/home.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('printedInvoices');
  await Hive.openBox('settings');
  runApp(const MyApp());

}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Receipt API',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Receipt API'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {



  String resultText = '';
  final user = TextEditingController();
  final secret = TextEditingController();


  final settingsBox = Hive.box('settings');

  bool obscurePin = true;

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title, style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Center(
        child: StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setState) {
            return Column(
              spacing: 10,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  height: 50,
                  width: 200,
                  child: TextField(
                    obscureText: obscurePin,
                    decoration: InputDecoration(
                        hintText: 'Enter PIN'
                    ),
                    controller: secret,
                  ),
                ),
                IconButton(onPressed: () => setState(() => obscurePin = !obscurePin), icon: Icon(Icons.remove_red_eye)),
                Container(
                  height: 50,
                  width: 200,
                  child: ElevatedButton(
                    onPressed: () async {
                      final userValue = user.text;
                      final secretValue = secret.text;
                      String token = "";

                      try {
                        token = await generateToken();
                        print(token);
                      } catch(e) {
                        print(e.toString());
                      }

                      // https://jsonplaceholder.typicode.com/posts
                      // https://gizmoetc.dealpos.com/api/v3/Token/OAuth2

                      if (secretValue == await getPIN() || secretValue == await getAdminPIN()) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => HomeScreen(token: token)));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("PIN Incorrect")));
                      }

                    },
                    child: Text("Sign In"),
                  ),
                ),
                SizedBox(height: 10),
                TextButton(onPressed: () {
                  TextEditingController oldPass = TextEditingController();
                  TextEditingController newPass = TextEditingController();
                  TextEditingController newPassConfirm = TextEditingController();

                  showDialog(context: context, builder: (_) => AlertDialog(
                    content: Container(
                      height: 150,
                      width: 200,
                      child: Column(
                        children: [
                          TextField(
                            decoration: InputDecoration(
                                hintText: 'Old PIN / Admin PIN'
                            ),
                            controller: oldPass,
                          ),

                          TextField(
                            obscureText: true,
                            decoration: InputDecoration(
                                hintText: 'New PIN'
                            ),
                            controller: newPass,
                          ),
                          TextField(
                            obscureText: true,
                            decoration: InputDecoration(
                                hintText: 'Confirm new PIN'
                            ),
                            controller: newPassConfirm,
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () async {
                        if (oldPass.text == await getPIN() || oldPass.text == await getAdminPIN()) {
                          if (newPassConfirm.text == newPass.text) {
                            await setPIN(newPass.text);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("PIN Changed")));
                            Navigator.pop(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("New PIN does not match.")));
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Old PIN Incorrect")));
                        }

                      }, child: Text("Reset"))
                    ],
                  ));
                }, child: Text("Reset PIN"))
              ],
            );
          },
        ),
      ),
       // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Future generateToken() async {

    /*
      "client_id": "21f44ae7-de63-4343-81ef-f1eb0732141c",
      "client_secret": "1bbeab92-e474-4bd1-9c9e-188e3eaff115"

      Gizmo
      "client_id": "5f742dc6-04e8-44dd-9a2a-ad9b78d2b66f",
      "client_secret": "6cc01e9b-9b1e-4b6f-adf3-d1f3c0d062a8"
     */

    final body = jsonEncode({
      "client_id": "21f44ae7-de63-4343-81ef-f1eb0732141c",
      "client_secret": "1bbeab92-e474-4bd1-9c9e-188e3eaff115"
    });


    var headers = {
      'Content-Type': 'application/json',
    };

    //https://cors-anywhere.herokuapp.com

    final uri = Uri.parse('https://myshop.dealpos.com/api/v3/Token/OAuth2');
    var response = await http.post(uri, body: body, headers: headers);

    print(response.body);

    final result = jsonDecode(response.body)['access_token'];

    return result;

  }


  getPIN() async {
    String pin = settingsBox.get('pin', defaultValue: "0000");
    return pin;
  }

  getAdminPIN() async {
    String pin = settingsBox.get('pinAdmin', defaultValue: "0000");
    return pin;
  }

  setPIN(String value) async {
    await settingsBox.put('pin', value);
  }
}
