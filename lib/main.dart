import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:del_pick/Common/global_style.dart';

// Import models
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/Models/customer.dart';
import 'package:del_pick/Models/driver.dart';
import 'package:del_pick/Models/order.dart';
import 'package:del_pick/Models/item_model.dart';
import 'package:del_pick/Models/tracking.dart';

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
    // Create a demo customer for the profile page
    final demoCustomer = Customer(
      id: 'customer123',
      name: 'John Doe',
      phoneNumber: '+62 812 3456 7890',
      email: 'johndoe@example.com',
      profileImageUrl: null,
    );

    // Create a demo driver for the profile page
    final demoDriver = Driver(
      id: 'driver123',
      name: 'Ahmad Supir',
      phoneNumber: '+62 856 7890 1234',
      email: 'ahmad@driver.com',
      profileImageUrl: null,
      rating: 4.7,
      vehicleNumber: 'B 1234 XYZ',
    );

    // Create a sample order for HistoryDetailPage and HistoryDriverDetailPage
    final sampleOrder = Order.sample();

    // Convert Order object to Map for HistoryDriverDetailPage
    final sampleOrderDetail = {
      'customerName': 'John Doe',
      'customerPhone': '+62 812 3456 7890',
      'customerAddress': 'Jl. Merdeka No. 123, Jakarta',
      'storeName': 'Toko Indonesia',
      'storePhone': '+62 8132635487',
      'storeAddress': 'Jl. Pahlawan No. 123, Jakarta Selatan',
      'storeImage': 'https://storage.googleapis.com/a1aa/image/5Cq_e1zvmarYJk2l1nLIWCqWm-vE7i5hHEUmyboR2mo.jpg',
      'status': 'assigned',
      'amount': 150000,
      'deliveryFee': 10000,
      'items': [
        {
          'name': 'Product 1',
          'price': 50000,
          'quantity': 2,
          'image': 'https://via.placeholder.com/150',
        },
        {
          'name': 'Product 2',
          'price': 40000,
          'quantity': 1,
          'image': 'https://via.placeholder.com/150',
        },
      ],
    };

    return {
      // Add splash screen route
      '/': (context) => const SplashScreen(),

      // Control routes
      Login.route: (context) => const Login(),

      // Customer routes
      HomePage.route: (context) => const HomePage(),
      StoreDetail.route: (context) => const StoreDetail(),
      ProfilePage.route: (context) => ProfilePage(customer: demoCustomer),
      HistoryCustomer.route: (context) => const HistoryCustomer(),
      CartScreen.route: (context) => const CartScreen(cartItems: []),
      LocationAccessScreen.route: (context) => LocationAccessScreen(
        onLocationSelected: (String location) {
          print('Selected location: $location');
          Navigator.pop(context);
        },
      ),
      TrackCustOrderScreen.route: (context) => const TrackCustOrderScreen(),
      // Updated HistoryDetailPage route to use Order model
      HistoryDetailPage.route: (context) => HistoryDetailPage(order: sampleOrder),
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
      // Updated HistoryDriverDetailPage to pass orderDetail parameter instead of order
      HistoryDriverDetailPage.route: (context) => HistoryDriverDetailPage(orderDetail: sampleOrderDetail),

      ProfileDriverPage.route: (context) => ProfileDriverPage(driver: demoDriver),

      // Store routes
      '/Store/HomePage': (context) => const HomeStore(),
      '/Store/AddItem': (context) => const AddItemPage(),
      HistoryStorePage.route: (context) => const HistoryStorePage(),
      // Updated HistoryStoreDetailPage with an example order detail
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
      // Updated ProfileStorePage route to use a temporary dummy store for initialization
      ProfileStorePage.route: (context) {
        // Create a dummy store for initialization
        final dummyStore = StoreModel(
          name: 'Toko Indonesia',
          address: 'Jl. Pahlawan No. 123, Jakarta Selatan',
          openHours: '08:00 - 21:00',
          imageUrl: 'https://storage.googleapis.com/a1aa/image/5Cq_e1zvmarYJk2l1nLIWCqWm-vE7i5hHEUmyboR2mo.jpg',
          phoneNumber: '+62 8132635487',
          productCount: 10,
          rating: 4.8,
          description: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
        );

        return ProfileStorePage(store: dummyStore);
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Del Pick',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      initialRoute: '/', // Changed to start with splash screen
      routes: _buildRoutes(),
    );
  }
}