import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:aad_oauth/aad_oauth.dart';
import 'package:aad_oauth/model/config.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import 'mylib.dart';
import 'home.dart';


void main() {
  runApp(const MainApp());
}

final navigatorKey = GlobalKey<NavigatorState>();

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Símic | Tree',
      theme: ThemeData(
        useMaterial3: false,
        brightness: Brightness.dark,
        primaryColor: Colors.grey[900],
        appBarTheme: AppBarTheme(
          color: orangeColor,
          titleTextStyle: TextStyle(
            color: Colors.grey[900],
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        primarySwatch: orangeColor,
      ),
      home: LoginPage(),
    );
  }
} 

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  bool loading = false;
  static final Config config = Config(
    tenant: 'cd6259c8-7fcd-4de7-a4c4-9059729e62e7',
    clientId: 'd86c4aed-2b6d-4faa-b1bb-95f042e5ff9e',
    scope: 'openid profile offline_access',
    redirectUri: 'https://login.microsoftonline.com/common/oauth2/nativeclient',
    navigatorKey: navigatorKey,
  );
  final AadOAuth oauth = new AadOAuth(config);

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/simOSWallpaper.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: loading
          ? Padding(
            padding: EdgeInsets.symmetric(vertical: 160),
            child: Align(
              alignment: Alignment.bottomCenter,
              child:
                  CircularProgressIndicator(color: Color(0xFFf07f34)),
            ),
          )
          : Padding(
            padding: EdgeInsets.symmetric(vertical: 160),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: getTotalHeight(context) / 13,
                width: getTotalWidth(context) / 3,
                child: FilledButton(
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all<Color>(Color.fromARGB(45, 255, 255, 255)),
                    shape: MaterialStateProperty.all<RoundedRectangleBorder>(RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                      side: BorderSide(
                        color: Color(0xFFf07f34), 
                        width: 2
                        ),
                      ),
                    ),
                  ),
                  onPressed: loading
                      ? null
                      : () async {
                          await login();
                        },
                  child: Text(
                    'Entrar',
                    style: TextStyle(
                      fontSize: getTotalWidth(context) / 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          )
        ),
      ),
    );
  }

  Future login() async {
    setState(() { loading = true; });

    if(await InternetConnectionChecker().hasConnection == false){
      if(await offlineModeDialog('Falha na conexão') == true){
        goToHomeScreen();
        return null;
      }else{
        setState(() { loading = false; });
        return null;
      }
    }

    var loginResult;

    try {
      loginResult = await oauth.login();
    } catch (error) {
      log('Authentication failed: $error');
      if (await offlineModeDialog('Falha na autenticação') == true) {
        goToHomeScreen();
        return null;
      } else {
        setState(() { loading = false; });
        return null;
      }
    }

    if(loginResult != null){
      loginResult.fold(
        (failure) async {
          log('Authentication failed: $failure');
          if(await offlineModeDialog() == true){
            goToHomeScreen();
            return null;
          }else{
            setState(() { loading = false; });
            return null;
          }
          
        },
        (token) {
          log('Authentication successful');
          goToHomeScreen(token.accessToken);
          return null;
        },
      );
    }else{
      if (await offlineModeDialog() == true) {
        goToHomeScreen();
        return null;
      } else {
        setState(() { loading = false; });
        return null;
      }
    }

    setState(() {
      loading = false;
    });
  }

  Future<bool?> offlineModeDialog([String? message]) async {
    bool? offlineMode = false;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: message != null
            ? Text(message + ', deseja entrar em modo OFFLINE?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: getTotalWidth(context) / 20),
            ) 
            : Text('Deseja entrar em modo OFFLINE?', 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: getTotalWidth(context) / 20),
            ),
          actionsAlignment: MainAxisAlignment.spaceAround,
          alignment: Alignment.bottomCenter,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20.0))),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: Text('Sim',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: getTotalWidth(context) / 20)
              )
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: Text('Não',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: getTotalWidth(context) / 20)
              )
            ),
          ],
        );
      },
    ).then((value) {offlineMode = value;});

    return offlineMode;
  }

  goToHomeScreen([String? token]){
    Timer(const Duration(seconds: 2), (){log('Awaiting 2 seconds');});
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(token: token),
      ),
    );
  }
}
