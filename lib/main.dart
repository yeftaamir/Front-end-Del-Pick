import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
import 'Views/Store/history_store.dart';
import 'Views/Store/historystore_detail.dart';
import 'Views/Store/add_edit_items.dart';
import 'Views/Driver/home_driver.dart';
import 'Views/Driver/history_driver_detail.dart';
import 'Views/Driver/history_driver.dart';

Future<void> main() async {
  try {
    // Ensure Flutter bindings are initialized
    WidgetsFlutterBinding.ensureInitialized();

    // Load environment variables
    await dotenv.load(fileName: ".env").then((_) {
      print("Environment file loaded successfully");
    }).catchError((error) {
      print("Error loading environment file: $error");
    });

    // Get and verify Mapbox token
    final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'];
    print("Loaded token: ${mapboxToken?.substring(0, 10)}..."); // Print first 10 chars for debugging

    if (mapboxToken == null || mapboxToken.isEmpty) {
      throw Exception('MAPBOX_ACCESS_TOKEN not found in .env file');
    }

    // Set Mapbox access token (removed await since it's void)
    MapboxOptions.setAccessToken(mapboxToken);
    print("Mapbox token set successfully");

    // Run the app
    runApp(const MyApp());
  } catch (e, stackTrace) {
    print('Error initializing app: $e');
    print('Stack trace: $stackTrace');
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 60,
                ),
                const SizedBox(height: 20),
                Text(
                  'Error initializing app: $e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Please check your .env file configuration and ensure MAPBOX_ACCESS_TOKEN is properly set.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _buildTheme() {
    return ThemeData(
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
    );
  }

  Map<String, Widget Function(BuildContext)> _buildRoutes() {
    return {
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
      HomeDriverPage.route: (context) => const HomeDriverPage(),
      HistoryDriverPage.route: (context) => const HistoryDriverPage(),
      HistoryDriverDetailPage.route: (context) => const HistoryDriverDetailPage(
        orderDetail: {
          'storeName': 'Store Name',
          'date': '2022-01-01T00:00:00.000Z',
          'status': 'Completed',
          'amount': 100000,
          'icon': 'https://via.placeholder.com/150',
        },
      ),

      // Store routes
      '/Store/HomePage': (context) => const HomeStore(),
      '/Store/AddItem': (context) => const AddItemPage(),
      HistoryStorePage.route: (context) => const HistoryStorePage(),
      HistoryStoreDetailPage.route: (context) => const HistoryStoreDetailPage(
        orderDetail: {
          'customerName': 'Customer Name',
          'date': '2022-01-01T00:00:00.000Z',
          'status': 'Delivered',
          'amount': 100000,
          'icon': 'https://via.placeholder.com/150',
        },
      ),
      AddEditItemForm.route: (context) => const AddEditItemForm(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Del Pick',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      initialRoute: Login.route,
      routes: _buildRoutes(),
    );
  }
}