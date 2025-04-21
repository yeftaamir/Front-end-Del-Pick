import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:provider/provider.dart';

// Import connectivity services
import 'package:del_pick/Views/Controls/connectivity_service.dart';
import 'package:del_pick/Views/Controls/internet_connectivity_wrapper.dart';

// Import models
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/customer.dart';
import 'package:del_pick/Models/driver.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/item_model.dart';
import 'package:del_pick/Models/tracking.dart';
import 'Views/Store/add_edit_items.dart' as add_edit_items;
import 'Views/Store/add_item.dart' as add_item;

// Import views
import 'Views/Controls/login_page.dart';
import 'Views/Customers/home_cust.dart';
import 'Views/Customers/store_detail.dart';
import 'Views/Customers/profile_cust.dart';
import 'Views/Customers/history_cust.dart';
import 'Views/Customers/cart_screen.dart';
import 'Views/Customers/location_access.dart';
import 'Views/Customers/history_detail.dart';
import 'Views/Customers/rating_cust.dart';
import 'Views/Customers/track_cust_order.dart';
import 'Views/Store/home_store.dart';
import 'Views/Store/add_item.dart';
import 'Views/Store/history_store.dart';
import 'Views/Store/historystore_detail.dart';
import 'Views/Store/add_edit_items.dart';
import 'Views/Driver/home_driver.dart';
import 'Views/Driver/history_driver_detail.dart';
import 'Views/Driver/history_driver.dart';
import 'Views/Driver/profil_driver.dart';
import 'Views/Store/profil_store.dart';
import 'Views/SplashScreen/splash_screen.dart';

// Import services
import 'Services/auth_service.dart';
import 'Services/store_service.dart';
import 'Services/core/token_service.dart';
import 'Services/order_service.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    await dotenv.load(fileName: ".env").then((_) {
      print("Environment file loaded successfully");
    }).catchError((error) {
      print("Error loading environment file: $error");
    });

    // Get and verify Mapbox token
    final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'];
    print("Loaded token: ${mapboxToken?.substring(0, 10)}...");

    if (mapboxToken == null || mapboxToken.isEmpty) {
      throw Exception('MAPBOX_ACCESS_TOKEN not found in .env file');
    }

    // Set Mapbox access token
    MapboxOptions.setAccessToken(mapboxToken);
    print("Mapbox token set successfully");

    // Run the app with Provider for connectivity service
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ],
        child: const MyApp(),
      ),
    );
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
      // Add splash screen route
      '/': (context) =>
      const InternetConnectivityWrapper(child: SplashScreen()),

      // Control routes
      LoginPage.route: (context) =>
      const InternetConnectivityWrapper(child: LoginPage()),

      // Customer routes
      HomePage.route: (context) =>
      const InternetConnectivityWrapper(child: HomePage()),
      StoreDetail.route: (context) =>
      const InternetConnectivityWrapper(child: StoreDetail()),
      // Updated ProfilePage route to use the new implementation
      ProfilePage.route: (context) =>
      const InternetConnectivityWrapper(child: ProfilePage()),
      HistoryCustomer.route: (context) =>
      const InternetConnectivityWrapper(child: HistoryCustomer()),
      CartScreen.route: (context) => const InternetConnectivityWrapper(
          child: CartScreen(
            cartItems: [],
            storeId: 0,
          )),
      LocationAccessScreen.route: (context) => InternetConnectivityWrapper(
        child: LocationAccessScreen(
          onLocationSelected: (String location) {
            print('Selected location: $location');
            Navigator.pop(context);
          },
        ),
      ),
      TrackCustOrderScreen.route: (context) =>
      const InternetConnectivityWrapper(child: TrackCustOrderScreen()),
      // Updated HistoryDetailPage route to use Order fetching
      HistoryDetailPage.route: (context) => InternetConnectivityWrapper(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _getOrderData(ModalRoute.of(context)?.settings.arguments as String?),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            } else if (snapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 60, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                ),
              );
            } else if (!snapshot.hasData) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.info_outline, size: 60, color: Colors.orange),
                      const SizedBox(height: 16),
                      const Text('No order data available.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.orange),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final order = Order.fromJson(snapshot.data!);
            return HistoryDetailPage(order: order);
          },
        ),
      ),
      // Updated RatingCustomerPage route to use Order data
      RatingCustomerPage.route: (context) => InternetConnectivityWrapper(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _getOrderData(ModalRoute.of(context)?.settings.arguments as String?),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            } else if (snapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 60, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                ),
              );
            } else if (!snapshot.hasData) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.info_outline, size: 60, color: Colors.orange),
                      const SizedBox(height: 16),
                      const Text('No order data available for rating.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.orange),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final order = Order.fromJson(snapshot.data!);
            return RatingCustomerPage(order: order);
          },
        ),
      ),

      // Admin routes
      '/Admin/HomePage': (context) => const InternetConnectivityWrapper(
        child: Scaffold(
          body: Center(child: Text('Admin Home Page - To be implemented')),
        ),
      ),

      // Driver routes
      HomeDriverPage.route: (context) =>
      const InternetConnectivityWrapper(child: HomeDriverPage()),
      HistoryDriverPage.route: (context) =>
      const InternetConnectivityWrapper(child: HistoryDriverPage()),
      // Updated HistoryDriverDetailPage to use OrderService
      HistoryDriverDetailPage.route: (context) => InternetConnectivityWrapper(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _getOrderData(ModalRoute.of(context)?.settings.arguments as String?),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            } else if (snapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 60, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                ),
              );
            } else if (!snapshot.hasData) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.info_outline, size: 60, color: Colors.orange),
                      const SizedBox(height: 16),
                      const Text('No order data available.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.orange),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Process the order data to match the expected format for HistoryDriverDetailPage
            final orderData = snapshot.data!;
            final Map<String, dynamic> orderDetail = {
              'customerName': orderData['user']?['name'] ?? 'Customer',
              'customerPhone': orderData['user']?['phone'] ?? '-',
              'customerAddress': orderData['deliveryAddress'] ?? '-',
              'storeName': orderData['store']?['name'] ?? 'Store',
              'storePhone': orderData['store']?['phone'] ?? '-',
              'storeAddress': orderData['store']?['address'] ?? '-',
              'storeImage': orderData['store']?['image'] ?? '',
              'status': orderData['order_status'] ?? 'pending',
              'amount': orderData['total'] ?? 0,
              'deliveryFee': orderData['serviceCharge'] ?? 0,
              'items': (orderData['items'] as List<dynamic>?)?.map((item) => {
                'name': item['name'] ?? 'Product',
                'price': item['price'] ?? 0,
                'quantity': item['quantity'] ?? 0,
                'image': item['imageUrl'] ?? '',
              }).toList() ?? [],
            };

            return HistoryDriverDetailPage(orderDetail: orderDetail);
          },
        ),
      ),
      ProfileDriverPage.route: (context) =>
      const InternetConnectivityWrapper(child: ProfileDriverPage()),

      // Store routes
      '/Store/HomePage': (context) =>
      const InternetConnectivityWrapper(child: HomeStore()),
      '/Store/AddItem': (context) =>
          InternetConnectivityWrapper(child: add_item.AddItemPage()),
      AddEditItemForm.route: (context) =>
      const InternetConnectivityWrapper(child: AddEditItemForm()),
      // Updated HistoryStoreDetailPage to use OrderService
      HistoryStoreDetailPage.route: (context) => InternetConnectivityWrapper(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _getOrderData(ModalRoute.of(context)?.settings.arguments as String?),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            } else if (snapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 60, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                ),
              );
            } else if (!snapshot.hasData) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.info_outline, size: 60, color: Colors.orange),
                      const SizedBox(height: 16),
                      const Text('No order data available.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.orange),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Process the order data for HistoryStoreDetailPage
            final orderData = snapshot.data!;
            final Map<String, dynamic> orderDetail = {
              'customerName': orderData['user']?['name'] ?? 'Customer',
              'date': orderData['orderDate'] ?? DateTime.now().toIso8601String(),
              'status': orderData['order_status'] ?? 'pending',
              'amount': orderData['total'] ?? 0,
              'icon': orderData['user']?['avatar'] ?? '',
            };

            return HistoryStoreDetailPage(orderDetail: orderDetail);
          },
        ),
      ),
      HistoryStorePage.route: (context) =>
      const InternetConnectivityWrapper(child: HistoryStorePage()),

      // Updated ProfileStorePage route to use actual service data instead of dummy data
      ProfileStorePage.route: (context) =>
      const InternetConnectivityWrapper(child: ProfileStorePage()),
    };
  }

  // Helper method to get order data
  static Future<Map<String, dynamic>> _getOrderData(String? orderId) async {
    if (orderId == null || orderId.isEmpty) {
      throw Exception('Order ID is required');
    }

    try {
      // Fetch order data using OrderService
      return await OrderService.getOrderById(orderId);
    } catch (e) {
      print('Error fetching order data: $e');
      rethrow; // Rethrow to handle in the FutureBuilder
    }
  }

  // Helper method to get store data from service
  static Future<Store> _getStoreData() async {
    try {
      // Get user data to check if we have a store ID
      final userData = await AuthService.getUserData();

      if (userData == null) {
        throw Exception('User data not found. Please log in again.');
      }

      // If user has a store ID, fetch the store
      final storeId = userData['store_id'] ?? userData['id'];

      if (storeId == null) {
        throw Exception('Store ID not found in user data.');
      }

      // Fetch store data by ID
      return await StoreService.fetchStoreById(storeId);

    } catch (e) {
      print('Error fetching store data: $e');
      rethrow; // Rethrow to handle in the FutureBuilder
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Del Pick',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      initialRoute: '/', // Changed to start with splash screen
      routes: _buildRoutes(),
      // Wrap root level with InternetConnectivityWrapper (optional since we wrapped each route)
      builder: (context, child) {
        // Additional builder could be applied here if needed
        return child!;
      },
    );
  }
}