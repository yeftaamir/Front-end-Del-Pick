import 'package:del_pick/Common/global_style.dart';
import 'package:flutter/material.dart';

// Import views
import 'Views/Controls/login_page.dart';
import 'Views/Customers/home_cust.dart';
import 'Views/Customers/store_detail.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Del Pick',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        fontFamily: GlobalStyle.fontFamily,
        primaryColor: GlobalStyle.primaryColor,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          color: GlobalStyle.primaryColor,
          elevation: 0,
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(
            color: GlobalStyle.fontColor,
            fontSize: GlobalStyle.fontSize,
          ),
          bodyMedium: TextStyle(
            color: GlobalStyle.fontColor,
            fontSize: GlobalStyle.fontSize,
          ),
        ),
      ),
      initialRoute: Login.route,
      routes: {
        // Control routes
        Login.route: (context) => const Login(),

        // Customer routes
        HomePage.route: (context) => const HomePage(),
        StoreDetail.route: (context) => const StoreDetail(),

        // Admin routes
        '/Admin/HomePage': (context) => const Scaffold(
          body: Center(child: Text('Admin Home Page - To be implemented')),
        ),

        // Driver routes
        '/Driver/HomePage': (context) => const Scaffold(
          body: Center(child: Text('Driver Home Page - To be implemented')),
        ),

        // Store routes
        '/Store/HomePage': (context) => const Scaffold(
          body: Center(child: Text('Store Home Page - To be implemented')),
        ),
      },
    );
  }
}