import 'package:del_pick/Views/Customers/all_stores_view.dart';
import 'package:del_pick/Views/Store/order_detail_store_page.dart';
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
import 'package:del_pick/Views/Customers/contact_driver.dart';
import 'package:del_pick/Views/Customers/rating_cust.dart';
import 'package:del_pick/Views/Store/home_store.dart';
import 'package:del_pick/Views/Store/add_item.dart';
import 'package:del_pick/Views/Store/history_store.dart';
import 'package:del_pick/Views/Store/history_store_detail.dart';
import 'package:del_pick/Views/Store/add_edit_items.dart';
import 'package:del_pick/Views/Store/profil_store.dart';
import 'package:del_pick/Views/Driver/home_driver.dart';
import 'package:del_pick/Views/Driver/history_driver_detail.dart';
import 'package:del_pick/Views/Driver/history_driver.dart';
import 'package:del_pick/Views/Driver/profil_driver.dart';
import 'package:del_pick/Views/SplashScreen/splash_screen.dart';
import 'package:del_pick/Views/Driver/contact_user.dart';

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

import 'Views/Driver/driver_request_detail.dart';
import 'Views/Store/history_store.dart' as StoreHistory;

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
    // Check authentication and token validity first
    final isAuthenticated = await AuthService.isAuthenticated();
    if (!isAuthenticated) {
      throw Exception('Authentication token expired. Please login again.');
    }

    // Use OrderService.getOrderDetail to fetch order details
    final orderData = await OrderService.getOrderById(orderId);

    // Process images if they exist in the order data
    if (orderData['store'] != null && orderData['store']['image_url'] != null) {
      orderData['store']['image_url'] =
          ImageService.getImageUrl(orderData['store']['image_url']);
    }

    // Process customer avatar if present
    if (orderData['customer'] != null &&
        orderData['customer']['avatar'] != null) {
      orderData['customer']['avatar'] =
          ImageService.getImageUrl(orderData['customer']['avatar']);
    }

    // Process driver avatar if present
    if (orderData['driver'] != null && orderData['driver']['avatar'] != null) {
      orderData['driver']['avatar'] =
          ImageService.getImageUrl(orderData['driver']['avatar']);
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

// ✅ Helper function to determine the initial route based on authentication status
Future<String> _determineInitialRoute() async {
  try {
    print('🔍 Determining initial route...');

    // Check if user is authenticated and session is valid
    final isAuthenticated = await AuthService.isAuthenticated();
    print('🔐 Is authenticated: $isAuthenticated');

    if (!isAuthenticated) {
      print('❌ User not authenticated or session expired');
      return LoginPage.route;
    }

    // Get token info for debugging
    final tokenInfo = await AuthService.getTokenInfo();
    print('🎫 Token info: $tokenInfo');

    // Validate session is still valid (not expired after 7 days)
    final isSessionValid = await AuthService.isSessionValid();
    print('✅ Session valid: $isSessionValid');

    if (!isSessionValid) {
      print('⏰ Session expired, clearing token');
      await TokenService.clearAll();
      return LoginPage.route;
    }

    // Get user data to determine role
    final userData = await AuthService.getUserData();
    print('👤 User data: ${userData?.keys.toList()}');

    if (userData == null) {
      print('❌ Invalid user data, clearing token');
      await TokenService.clearAll();
      return LoginPage.route;
    }

    // Determine home route based on user role
    final role = userData['user']?['role']?.toString().toLowerCase() ?? '';
    print('🎭 User role: $role');

    switch (role) {
      case 'customer':
        print('🛍️ Navigating to Customer Home');
        return HomePage.route;
      case 'store':
      case 'store_owner':
        print('🏪 Navigating to Store Home');
        return HomeStore.route;
      case 'driver':
        print('🚗 Navigating to Driver Home');
        return HomeDriverPage.route;
      case 'admin':
        print('👑 Navigating to Admin Home');
        return '/Admin/HomePage';
      default:
        print('❓ Unknown role: $role, redirecting to login');
        return LoginPage.route;
    }
  } catch (e) {
    print('❌ Error determining initial route: $e');
    // Clear potentially corrupted data
    try {
      await TokenService.clearAll();
    } catch (clearError) {
      print('⚠️ Error clearing token: $clearError');
    }
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
      // ========== SPLASH & AUTH ROUTES ==========
      SplashScreen.route: (context) =>
          const InternetConnectivityWrapper(child: SplashScreen()),
      LoginPage.route: (context) =>
          const InternetConnectivityWrapper(child: LoginPage()),

      // ========== CUSTOMER ROUTES ==========
      HomePage.route: (context) =>
          const InternetConnectivityWrapper(child: HomePage()),
      StoreDetail.route: (context) =>
          const InternetConnectivityWrapper(child: StoreDetail()),
      LocationAccessScreen.route: (context) => const LocationAccessScreen(),
      ProfilePage.route: (context) =>
          const InternetConnectivityWrapper(child: ProfilePage()),
      HistoryCustomer.route: (context) =>
          const InternetConnectivityWrapper(child: HistoryCustomer()),

      // Cart Screen with enhanced argument handling
      CartScreen.route: (context) {
        final arguments = ModalRoute.of(context)?.settings.arguments;
        List<MenuItemModel> cartItems = [];
        int storeId = 0;

        try {
          if (arguments is Map) {
            cartItems = arguments['cartItems'] as List<MenuItemModel>? ?? [];
            storeId = arguments['storeId'] as int? ?? 0;
          } else if (arguments is int) {
            storeId = arguments;
          } else {
            print('Invalid arguments for CartScreen: $arguments');
          }
        } catch (e) {
          print('Error processing CartScreen arguments: $e');
        }

        return InternetConnectivityWrapper(
          child: CartScreen(
            cartItems: cartItems,
            storeId: storeId,
            itemQuantities: arguments is Map
                ? arguments['itemQuantities'] as Map<int, int>?
                : null,
          ),
        );
      },

      // All Stores View with enhanced argument handling
      AllStoresView.route: (context) {
        final arguments = ModalRoute.of(context)?.settings.arguments;
        List<StoreModel> stores = [];

        try {
          if (arguments is Map<String, dynamic> &&
              arguments['stores'] != null) {
            stores = arguments['stores'] as List<StoreModel>;
          }
        } catch (e) {
          print('Error processing AllStoresView arguments: $e');
        }

        return InternetConnectivityWrapper(
          child: AllStoresView(stores: stores),
        );
      },

      // ✅ Customer History Detail Page with enhanced error handling
      HistoryDetailPage.route: (context) {
        final arguments = ModalRoute.of(context)?.settings.arguments;

        return InternetConnectivityWrapper(
          child: _buildHistoryDetailPage(arguments),
        );
      },

      // ✅ Customer Rating Page with enhanced error handling
      RatingCustomerPage.route: (context) {
        final arguments = ModalRoute.of(context)?.settings.arguments;

        return InternetConnectivityWrapper(
          child: _buildRatingPage(arguments),
        );
      },

      // ========== DRIVER ROUTES ==========
      HomeDriverPage.route: (context) =>
          const InternetConnectivityWrapper(child: HomeDriverPage()),
      HistoryDriverPage.route: (context) =>
          const InternetConnectivityWrapper(child: HistoryDriverPage()),
      DriverRequestDetailPage.route: (context) =>
          const DriverRequestDetailPage(),
      ProfileDriverPage.route: (context) =>
          const InternetConnectivityWrapper(child: ProfileDriverPage()),

      // Driver History Detail Page with enhanced error handling
      HistoryDriverDetailPage.route: (context) {
        final arguments = ModalRoute.of(context)?.settings.arguments;
        final orderId = arguments as String?;

        return InternetConnectivityWrapper(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _getOrderData(orderId),
            builder: (context, snapshot) => _buildOrderFutureBuilder(
              context,
              snapshot,
              (orderData) {
                final String orderIdValue = orderId ?? '';
                return HistoryDriverDetailPage(orderId: orderIdValue);
              },
            ),
          ),
        );
      },

      // ========== STORE ROUTES ==========
      HomeStore.route: (context) =>
          const InternetConnectivityWrapper(child: HomeStore()),
      AddItemPage.route: (context) =>
          const InternetConnectivityWrapper(child: AddItemPage()),
      AddEditItemForm.route: (context) =>
          const InternetConnectivityWrapper(child: AddEditItemForm()),
      HistoryStorePage.route: (context) =>
          const InternetConnectivityWrapper(child: HistoryStorePage()),
      ProfileStorePage.route: (context) =>
          const InternetConnectivityWrapper(child: ProfileStorePage()),
      StoreHistory.HistoryStorePage.route: (context) =>
          const InternetConnectivityWrapper(
              child: StoreHistory.HistoryStorePage()),

      // Store History Detail Page with enhanced error handling
      HistoryStoreDetailPage.route: (context) {
        final arguments = ModalRoute.of(context)?.settings.arguments;
        final orderId = arguments as String?;

        return InternetConnectivityWrapper(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _getOrderData(orderId),
            builder: (context, snapshot) => _buildOrderFutureBuilder(
              context,
              snapshot,
              (orderData) {
                final String orderIdValue = orderId ?? '';
                return HistoryStoreDetailPage(orderId: orderIdValue);
              },
            ),
          ),
        );
      },

      // ========== ADMIN ROUTES ==========
      '/Admin/HomePage': (context) => const InternetConnectivityWrapper(
            child: Scaffold(
              body: Center(child: Text('Admin Home Page - To be implemented')),
            ),
          ),
    };
  }

  // ✅ Helper methods (same as before)
  Widget _buildHistoryDetailPage(dynamic arguments) {
    if (arguments is OrderModel) {
      print('✅ Direct OrderModel navigation');
      return HistoryDetailPage(order: arguments);
    } else if (arguments is String) {
      print('📡 String ID navigation, will fetch data');
      return FutureBuilder<Map<String, dynamic>>(
        future: _getOrderData(arguments),
        builder: (context, snapshot) => _buildOrderFutureBuilder(
          context,
          snapshot,
          (orderData) {
            final order = OrderModel.fromJson(orderData);
            return HistoryDetailPage(order: order);
          },
        ),
      );
    } else {
      print(
          '⚠️ Invalid arguments for HistoryDetailPage: ${arguments.runtimeType}');
      return _buildErrorPage(
        'Invalid navigation arguments',
        'Please navigate from a valid order list.',
      );
    }
  }

  Widget _buildRatingPage(dynamic arguments) {
    if (arguments is OrderModel) {
      return RatingCustomerPage(order: arguments);
    } else if (arguments is String) {
      return FutureBuilder<Map<String, dynamic>>(
        future: _getOrderData(arguments),
        builder: (context, snapshot) => _buildOrderFutureBuilder(
          context,
          snapshot,
          (orderData) {
            final order = OrderModel.fromJson(orderData);
            return RatingCustomerPage(order: order);
          },
        ),
      );
    } else {
      return _buildErrorPage(
        'Invalid navigation arguments for rating',
        'Please navigate from a completed order.',
      );
    }
  }

  Widget _buildOrderFutureBuilder(
    BuildContext context,
    AsyncSnapshot<Map<String, dynamic>> snapshot,
    Widget Function(Map<String, dynamic>) successBuilder,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading order details...'),
            ],
          ),
        ),
      );
    } else if (snapshot.hasError) {
      final error = snapshot.error.toString();
      print('Error loading order data: $error');

      if (error.contains('token') || error.contains('authentication')) {
        return _buildAuthErrorPage(context);
      }

      return _buildErrorPage(
        'Error loading order',
        error,
        showRetry: true,
        onRetry: () => Navigator.pop(context),
      );
    } else if (!snapshot.hasData) {
      return _buildErrorPage(
        'No order data available',
        'The order information could not be found.',
      );
    }

    try {
      return successBuilder(snapshot.data!);
    } catch (e) {
      print('Error building widget with order data: $e');
      return _buildErrorPage(
        'Error displaying order',
        'There was an error processing the order data.',
      );
    }
  }

  Widget _buildErrorPage(
    String title,
    String message, {
    bool showRetry = true,
    VoidCallback? onRetry,
  }) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              if (showRetry) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onRetry ??
                      () {
                        // Default retry action
                        if (GlobalNavigatorContext
                                .navigatorKey.currentContext !=
                            null) {
                          Navigator.pop(GlobalNavigatorContext
                              .navigatorKey.currentContext!);
                        }
                      },
                  child: const Text('Go Back'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthErrorPage(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 60,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              const Text(
                'Session Expired',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your session has expired after 7 days. Please login again to continue.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await TokenService.clearAll();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    LoginPage.route,
                    (route) => false,
                  );
                },
                child: const Text('Login Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _determineInitialRoute(),
      builder: (context, snapshot) {
        // Show loading splash while determining route
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            title: 'Del Pick',
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(),
            home: const InternetConnectivityWrapper(
              child: Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text(
                        'Loading Del Pick...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // Handle error in route determination
        if (snapshot.hasError) {
          print('❌ Error in _determineInitialRoute: ${snapshot.error}');
          return MaterialApp(
            title: 'Del Pick',
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(),
            home: const InternetConnectivityWrapper(child: LoginPage()),
            routes: _buildRoutes(),
            navigatorKey: GlobalNavigatorContext.navigatorKey,
          );
        }

        // Get the determined initial route
        final initialRoute = snapshot.data ?? LoginPage.route;
        print('🎯 Final initial route: $initialRoute');

        return MaterialApp(
          title: 'Del Pick',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(),
          initialRoute: initialRoute,
          routes: _buildRoutes(),
          navigatorKey: GlobalNavigatorContext.navigatorKey,

          // ✅ Enhanced route generator
          onGenerateRoute: (RouteSettings settings) {
            print('🛣️ onGenerateRoute called for: ${settings.name}');
            print(
                '🛣️ Arguments: ${settings.arguments} (${settings.arguments.runtimeType})');

            try {
              switch (settings.name) {
                case AllStoresView.route:
                  final args = settings.arguments;
                  List<StoreModel> stores = [];

                  if (args is Map<String, dynamic> && args['stores'] != null) {
                    final storesData = args['stores'];
                    if (storesData is List<StoreModel>) {
                      stores = storesData;
                    } else if (storesData is List) {
                      stores = storesData.whereType<StoreModel>().toList();
                    }
                  }

                  return MaterialPageRoute(
                    builder: (context) => InternetConnectivityWrapper(
                      child: AllStoresView(stores: stores),
                    ),
                    settings: settings,
                  );

                case HistoryDetailPage.route:
                  final args = settings.arguments;

                  if (args is OrderModel) {
                    return MaterialPageRoute(
                      builder: (context) => InternetConnectivityWrapper(
                        child: HistoryDetailPage(order: args),
                      ),
                      settings: settings,
                    );
                  } else if (args is String) {
                    return MaterialPageRoute(
                      builder: (context) => InternetConnectivityWrapper(
                        child: _buildHistoryDetailPage(args),
                      ),
                      settings: settings,
                    );
                  }
                  break;

                case ContactDriverPage.route:
                  final args = settings.arguments as Map<String, dynamic>?;
                  if (args != null && args['driver'] != null) {
                    return MaterialPageRoute(
                      builder: (context) => InternetConnectivityWrapper(
                        child: ContactDriverPage(
                          driver: args['driver'],
                          serviceType: args['serviceType'] ?? 'jastip',
                        ),
                      ),
                      settings: settings,
                    );
                  }

                  return MaterialPageRoute(
                    builder: (context) => InternetConnectivityWrapper(
                      child: _buildErrorPage(
                        'Driver data not provided',
                        'Please select a driver from the list',
                      ),
                    ),
                    settings: settings,
                  );

                case ContactUserPage.route:
                  final args = settings.arguments as Map<String, dynamic>?;
                  if (args != null && args['orderId'] != null) {
                    return MaterialPageRoute(
                      builder: (context) => InternetConnectivityWrapper(
                        child: ContactUserPage(
                          serviceOrderId: args['orderId'],
                          serviceOrderData: args['orderData'],
                        ),
                      ),
                      settings: settings,
                    );
                  }

                  return MaterialPageRoute(
                    builder: (context) => InternetConnectivityWrapper(
                      child: _buildErrorPage(
                        'Order ID not provided',
                        'Invalid order data for jasa titip',
                      ),
                    ),
                    settings: settings,
                  );

                default:
                  return null;
              }
            } catch (e) {
              print('❌ Error in onGenerateRoute: $e');
              return MaterialPageRoute(
                builder: (context) => InternetConnectivityWrapper(
                  child: _buildErrorPage(
                    'Navigation Error',
                    'An error occurred while navigating: $e',
                  ),
                ),
                settings: settings,
              );
            }

            return null;
          },

          builder: (context, child) {
            GlobalNavigatorContext.context = context;
            return child!;
          },
        );
      },
    );
  }
}

// ✅ Global navigator context for error handling
class GlobalNavigatorContext {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static BuildContext? context;
}
