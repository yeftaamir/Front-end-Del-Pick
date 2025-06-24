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
import 'package:del_pick/Models/order_review.dart';
import 'package:del_pick/Models/order_enum.dart';
import 'package:del_pick/Models/menu_item.dart';
import 'package:del_pick/Models/order_item.dart';

// Import views
import 'package:del_pick/Views/Controls/login_page.dart';
import 'package:del_pick/Views/Customers/home_cust.dart';
import 'package:del_pick/Views/Customers/store_detail.dart';
import 'package:del_pick/Views/Customers/profile_cust.dart';
import 'package:del_pick/Views/Customers/history_cust.dart';
import 'package:del_pick/Views/Customers/cart_screen.dart';
import 'package:del_pick/Views/Customers/location_access.dart';
import 'package:del_pick/Views/Customers/history_detail.dart';
import 'package:del_pick/Views/Customers/rating_cust.dart';
import 'package:del_pick/Views/Store/home_store.dart';
import 'package:del_pick/Views/Store/add_item.dart';
import 'package:del_pick/Views/Store/history_store.dart';
import 'package:del_pick/Views/Store/historystore_detail.dart';
import 'package:del_pick/Views/Store/add_edit_items.dart';
import 'package:del_pick/Views/Store/profil_store.dart';
import 'package:del_pick/Views/Driver/home_driver.dart';
import 'package:del_pick/Views/Driver/history_driver_detail.dart';
import 'package:del_pick/Views/Driver/history_driver.dart';
import 'package:del_pick/Views/Driver/profil_driver.dart';
import 'package:del_pick/Views/SplashScreen/splash_screen.dart';

// Import services
import 'package:del_pick/Services/auth_service.dart';
import 'package:del_pick/Services/store_service.dart';
import 'package:del_pick/Services/core/token_service.dart';
import 'package:del_pick/Services/order_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/driver_service.dart';
import 'package:del_pick/Services/tracking_service.dart';
import 'package:del_pick/Services/menu_service.dart';
import 'package:del_pick/Services/customer_service.dart';

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

// Helper function to get order data using OrderService
Future<Map<String, dynamic>> _getOrderData(String? orderId) async {
  if (orderId == null || orderId.isEmpty) {
    throw Exception('Order ID is required');
  }

  try {
    // Get token to verify authentication
    final token = await TokenService.getToken();

    if (token == null) {
      throw Exception('Authentication token not found. Please login again.');
    }

    // Use OrderService.getOrderDetail to fetch order details
    final orderData = await OrderService.getOrderById(orderId);

    // Process images if they exist in the order data
    if (orderData['store'] != null && orderData['store']['image_url'] != null) {
      orderData['store']['image_url'] = ImageService.getImageUrl(orderData['store']['image_url']);
    }

    // Process customer avatar if present
    if (orderData['customer'] != null && orderData['customer']['avatar'] != null) {
      orderData['customer']['avatar'] = ImageService.getImageUrl(orderData['customer']['avatar']);
    }

    // Process driver avatar if present
    if (orderData['driver'] != null && orderData['driver']['avatar'] != null) {
      orderData['driver']['avatar'] = ImageService.getImageUrl(orderData['driver']['avatar']);
    }

    // Process order item images if present
    if (orderData['items'] != null && orderData['items'] is List) {
      for (var item in orderData['items']) {
        if (item['image_url'] != null) {
          item['image_url'] = ImageService.getImageUrl(item['image_url']);
        }
      }
    }

    return orderData;
  } catch (e) {
    print('Error fetching order data: $e');
    throw Exception('Failed to load order details: $e');
  }
}

// Helper function to determine the initial route based on authentication status
Future<String> _determineInitialRoute() async {
  try {
    final token = await TokenService.getToken();

    if (token == null) {
      return LoginPage.route;
    }

    // Verify token and get user role
    final userData = await AuthService.getUserData();

    if (userData == null) {
      // Token exists but is invalid or expired
      await TokenService.clearToken();
      return LoginPage.route;
    }

    // Determine home route based on user role
    final role = userData['role']?.toString().toLowerCase() ?? '';

    switch (role) {
      case 'customer':
        return HomePage.route;
      case 'store':
      case 'store_owner':
        return HomeStore.route;
      case 'driver':
        return HomeDriverPage.route;
      case 'admin':
        return '/Admin/HomePage';
      default:
        return LoginPage.route;
    }
  } catch (e) {
    print('Error determining initial route: $e');
    return LoginPage.route;
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
      LocationAccessScreen.route: (context) => const LocationAccessScreen(),
      ProfilePage.route: (context) =>
      const InternetConnectivityWrapper(child: ProfilePage()),
      HistoryCustomer.route: (context) =>
      const InternetConnectivityWrapper(child: HistoryCustomer()),
      CartScreen.route: (context) {
        final arguments = ModalRoute.of(context)?.settings.arguments;
        List<MenuItemModel> cartItems = [];
        int storeId = 0;

        if (arguments is Map) {
          cartItems = arguments['cartItems'] as List<MenuItemModel>? ?? [];
          storeId = arguments['storeId'] as int? ?? 0;
        } else if (arguments is int) {
          storeId = arguments;
        } else {
          print('Invalid arguments for CartScreen: $arguments');
        }

        return InternetConnectivityWrapper(
          child: CartScreen(
            cartItems: cartItems,
            storeId: storeId,
          ),
        );
      },
      // Customer History Detail Page route with Order fetching
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

            final order = OrderModel.fromJson(snapshot.data!);
            return HistoryDetailPage(order: order);
          },
        ),
      ),

      // Customer Rating Page route with Order data
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

            final order = OrderModel.fromJson(snapshot.data!);
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

      // Driver History Detail Page with OrderService
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
              'customerName': orderData['customer']?['name'] ?? 'Customer',
              'customerPhone': orderData['customer']?['phone'] ?? '-',
              'customerAddress': orderData['delivery_address'] ?? '-',
              'storeName': orderData['store']?['name'] ?? 'Store',
              'storePhone': orderData['store']?['phone'] ?? '-',
              'storeAddress': orderData['store']?['address'] ?? '-',
              'storeImage': orderData['store']?['image_url'] ?? '',
              'status': orderData['order_status'] ?? 'pending',
              'amount': orderData['total_amount'] ?? 0,
              'deliveryFee': orderData['delivery_fee'] ?? 0,
              'items': (orderData['items'] as List<dynamic>?)?.map((item) => {
                'name': item['name'] ?? 'Product',
                'price': item['price'] ?? 0,
                'quantity': item['quantity'] ?? 0,
                'image': item['image_url'] ?? '',
              }).toList() ?? [],
            };

            return HistoryDriverDetailPage(orderDetail: orderDetail);
          },
        ),
      ),
      ProfileDriverPage.route: (context) =>
      const InternetConnectivityWrapper(child: ProfileDriverPage()),

      // Store routes
      HomeStore.route: (context) =>
      const InternetConnectivityWrapper(child: HomeStore()),
      AddItemPage.route: (context) =>
      const InternetConnectivityWrapper(child: AddItemPage()),
      AddEditItemForm.route: (context) =>
      const InternetConnectivityWrapper(child: AddEditItemForm()),

      // Store History Detail Page with OrderService
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

            final String orderId = ModalRoute.of(context)?.settings.arguments as String? ?? '';
            return HistoryStoreDetailPage(orderId: orderId);
          },
        ),
      ),
      HistoryStorePage.route: (context) =>
      const InternetConnectivityWrapper(child: HistoryStorePage()),
      ProfileStorePage.route: (context) =>
      const InternetConnectivityWrapper(child: ProfileStorePage()),
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Del Pick',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      initialRoute: '/', // Start with splash screen which will handle authentication
      routes: _buildRoutes(),
      // Wrap root level with InternetConnectivityWrapper (optional since we wrapped each route)
      builder: (context, child) {
        // Additional builder could be applied here if needed
        return child!;
      },
    );
  }
}