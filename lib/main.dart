import 'package:api_receipt/home.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
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

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {



  String resultText = '';
  final user = TextEditingController();
  final secret = TextEditingController();

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title, style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              height: 50,
              width: 200,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'User'
                ),
                controller: user,
              ),
            ),
            SizedBox(height: 10),
            Container(
              height: 50,
              width: 200,
              child: TextField(
                decoration: InputDecoration(
                    hintText: 'Password'
                ),
                controller: secret,
              ),
            ),
            SizedBox(height: 20),
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



                  Navigator.push(context, MaterialPageRoute(builder: (_) => HomeScreen(token: token)));



                },
                child: Text("Sign In"),
              ),
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
       // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Future generateToken() async {

    /*

      "client_id": "21f44ae7-de63-4343-81ef-f1eb0732141c",
      "client_secret": "1bbeab92-e474-4bd1-9c9e-188e3eaff115"
     */

    final body = jsonEncode({
      "client_id": "5f742dc6-04e8-44dd-9a2a-ad9b78d2b66f",
      "client_secret": "6cc01e9b-9b1e-4b6f-adf3-d1f3c0d062a8"
    });


    var headers = {
      'Content-Type': 'application/json',
    };

    final uri = Uri.parse('https://gizmoetc.dealpos.com/api/v3/Token/OAuth2');
    var response = await http.post(uri, body: body, headers: headers);

    final result = jsonDecode(response.body);
    return result['access_token'];

  }
}
