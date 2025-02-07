// File: lib/main.dart

import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';

// Import views
import 'Views/Controls/login_page.dart';
import 'Views/Customers/home_cust.dart';
import 'Views/Customers/store_detail.dart';
import 'Views/Customers/list_store.dart';
import 'Views/Customers/profile_cust.dart';
import 'Views/Customers/history_cust.dart';
import 'Views/Customers/cart_screen.dart';
import 'Views/Customers/location_access.dart';
import 'Views/Customers/history_detail.dart';
import 'Views/Customers/rating_cust.dart';
import 'Views/Store/home_store.dart';
import 'Views/Store/add_item.dart';

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
        ListStore.route: (context) => const ListStore(),
        ProfilePage.route: (context) => const ProfilePage(),
        HistoryCustomer.route: (context) => const HistoryCustomer(),
        CartScreen.route: (context) => const CartScreen(cartItems: []),
        LocationAccessScreen.route: (context) => const LocationAccessScreen(),
        HistoryDetailPage.route: (context) => const HistoryDetailPage(
          storeName: 'Store Name',
          date: '2022-01-01T00:00:00.000Z',
          amount: 100000,
        ),
        RatingCustomerPage.route: (context) => const RatingCustomerPage(
          storeName: 'Store Name',
          driverName: 'Driver Name',
          vehicleNumber: 'B 1234 ABC',
          orderItems: [],
        ),

        // Admin routes
        '/Admin/HomePage': (context) => const Scaffold(
          body: Center(child: Text('Admin Home Page - To be implemented')),
        ),

        // Driver routes
        '/Driver/HomePage': (context) => const Scaffold(
          body: Center(child: Text('Driver Home Page - To be implemented')),
        ),

        // Store routes
        '/Store/HomePage': (context) => const HomeStore(),
        '/Store/AddItem': (context) => const AddItemPage(),
      },
    );
  }
}