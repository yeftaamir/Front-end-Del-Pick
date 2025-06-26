// // ========================================
// // Driver Order History View - Fixed Version
// // ========================================
//
// import 'package:del_pick/Models/driver_request_model.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:intl/intl.dart';
// import 'package:lottie/lottie.dart';
//
// import 'package:del_pick/app/themes/app_colors.dart';
// import 'package:del_pick/app/themes/app_text_styles.dart';
// import 'package:del_pick/core/constants/order_status_constants.dart';
// import 'package:del_pick/core/widgets/custom_app_bar.dart';
// import 'package:del_pick/core/widgets/loading_widget.dart';
// import 'package:del_pick/core/widgets/error_widget.dart';
// import 'package:del_pick/core/widgets/empty_state_widget.dart';
// import 'package:del_pick/core/widgets/network_image_widget.dart';
// import 'package:del_pick/core/widgets/status_badge.dart';
// import 'package:del_pick/data/models/driver/driver_request_model.dart';
// import 'package:del_pick/features/driver/controllers/driver_order_controller.dart';
// import 'package:del_pick/features/driver/views/driver_order_detail_view.dart';
//
// class DriverOrderHistoryView extends GetView<DriverOrderController> {
//   const DriverOrderHistoryView({Key? key}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return DefaultTabController(
//       length: _tabs.length,
//       child: Scaffold(
//         backgroundColor: AppColors.background,
//         appBar: CustomAppBar(
//           title: 'Riwayat Pesanan',
//           actions: [
//             IconButton(
//               icon: Icon(Icons.refresh, color: AppColors.primary),
//               onPressed: controller.refreshHistory,
//             ),
//           ],
//           bottom: TabBar(
//             isScrollable: true,
//             labelColor: AppColors.primary,
//             unselectedLabelColor: AppColors.textSecondary,
//             labelStyle: AppTextStyles.labelMedium.copyWith(
//               fontWeight: FontWeight.w600,
//             ),
//             indicatorColor: AppColors.primary,
//             indicatorWeight: 3,
//             tabs: _tabs.map((tab) => Tab(text: tab['label'])).toList(),
//           ),
//         ),
//         body: Obx(() {
//           if (controller.isLoading.value && controller.driverRequests.isEmpty) {
//             return const LoadingWidget(message: 'Memuat riwayat pesanan...');
//           }
//
//           if (controller.hasError.value) {
//             return CustomErrorWidget(
//               message: 'Gagal memuat riwayat pesanan',
//               onRetry: controller.refreshHistory,
//             );
//           }
//
//           return TabBarView(
//             children: List.generate(_tabs.length, (tabIndex) {
//               final filteredRequests = _getFilteredRequests(tabIndex);
//
//               if (filteredRequests.isEmpty) {
//                 return EmptyStateWidget(
//                   title:
//                       'Tidak ada pesanan ${_tabs[tabIndex]['label'].toLowerCase()}',
//                   subtitle: 'Belum ada riwayat pesanan untuk kategori ini',
//                   onRetry: controller.refreshHistory,
//                 );
//               }
//
//               return RefreshIndicator(
//                 onRefresh: controller.refreshHistory,
//                 color: AppColors.primary,
//                 child: NotificationListener<ScrollNotification>(
//                   onNotification: (ScrollNotification scrollInfo) {
//                     if (scrollInfo.metrics.pixels ==
//                         scrollInfo.metrics.maxScrollExtent) {
//                       controller.loadMoreHistory();
//                     }
//                     return false;
//                   },
//                   child: ListView.builder(
//                     padding: const EdgeInsets.all(16),
//                     itemCount: filteredRequests.length +
//                         (controller.isLoadingMore.value ? 1 : 0),
//                     itemBuilder: (context, index) {
//                       if (index == filteredRequests.length) {
//                         return const Center(
//                           child: Padding(
//                             padding: EdgeInsets.all(16),
//                             child: CircularProgressIndicator(),
//                           ),
//                         );
//                       }
//                       return _buildRequestCard(
//                           filteredRequests[index], context);
//                     },
//                   ),
//                 ),
//               );
//             }),
//           );
//         }),
//       ),
//     );
//   }
//
//   // Tab categories berdasarkan ORDER STATUS
//   static const List<Map<String, dynamic>> _tabs = [
//     {'label': 'Semua', 'statuses': null},
//     {
//       'label': 'Menunggu',
//       'statuses': ['pending', 'confirmed']
//     },
//     {
//       'label': 'Disiapkan',
//       'statuses': ['preparing', 'ready_for_pickup']
//     },
//     {
//       'label': 'Diantar',
//       'statuses': ['on_delivery']
//     },
//     {
//       'label': 'Selesai',
//       'statuses': ['delivered']
//     },
//     {
//       'label': 'Dibatalkan',
//       'statuses': ['cancelled', 'rejected']
//     },
//   ];
//
//   List<DriverRequestModel> _getFilteredRequests(int tabIndex) {
//     if (tabIndex == 0) return controller.driverRequests;
//
//     final tabStatuses = _tabs[tabIndex]['statuses'] as List<String>?;
//     if (tabStatuses == null) return controller.driverRequests;
//
//     return controller.driverRequests.where((request) {
//       final orderStatus = request.orderStatus.toLowerCase();
//       return tabStatuses.contains(orderStatus);
//     }).toList();
//   }
//
//   Widget _buildRequestCard(DriverRequestModel request, BuildContext context) {
//     final order = request.order;
//     if (order == null) return const SizedBox.shrink();
//
//     final orderDate = request.createdAt;
//     final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(orderDate);
//     final orderStatus = order.orderStatus;
//     final statusColor = orderStatus.color;
//     final statusText = orderStatus.displayName;
//     final customerName = order.customer?.name ?? 'Unknown Customer';
//     final customerAvatar = order.customer?.avatar ?? '';
//     final storeName = order.store?.name ?? 'Unknown Store';
//     final storeImage = order.store?.imageUrl ?? '';
//     final totalItems = order.totalItems;
//     final driverEarnings = request.driverEarnings;
//
//     return Card(
//       elevation: 2,
//       margin: const EdgeInsets.only(bottom: 16),
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: InkWell(
//         borderRadius: BorderRadius.circular(12),
//         onTap: () => _navigateToDetail(request),
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Header
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Expanded(
//                     child: Text(
//                       'Order #${request.orderId}',
//                       style: AppTextStyles.headlineSmall.copyWith(
//                         fontWeight: FontWeight.bold,
//                       ),
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   StatusBadge(
//                     text: statusText,
//                     color: statusColor,
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 12),
//
//               // Customer info
//               Row(
//                 children: [
//                   _buildAvatar(customerAvatar, Icons.person),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           customerName,
//                           style: AppTextStyles.bodyMedium.copyWith(
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           formattedDate,
//                           style: AppTextStyles.bodySmall.copyWith(
//                             color: AppColors.textSecondary,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 12),
//
//               // Store info
//               Row(
//                 children: [
//                   _buildAvatar(storeImage, Icons.store),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           storeName,
//                           style: AppTextStyles.bodyMedium.copyWith(
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           '$totalItems item',
//                           style: AppTextStyles.bodySmall.copyWith(
//                             color: AppColors.textSecondary,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//               const Divider(height: 24),
//
//               // Bottom section
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'Total Pesanan',
//                         style: AppTextStyles.bodySmall.copyWith(
//                           color: AppColors.textSecondary,
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         order.formatTotalAmount(),
//                         style: AppTextStyles.headlineSmall.copyWith(
//                           fontWeight: FontWeight.w600,
//                           color: AppColors.primary,
//                         ),
//                       ),
//                     ],
//                   ),
//                   if (driverEarnings > 0)
//                     _buildEarningsChip(driverEarnings)
//                   else
//                     _buildDetailButton(),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildAvatar(String? imageUrl, IconData fallbackIcon) {
//     return Container(
//       width: 50,
//       height: 50,
//       decoration: BoxDecoration(
//         color: AppColors.surface,
//         borderRadius: BorderRadius.circular(10),
//       ),
//       child: imageUrl != null && imageUrl.isNotEmpty
//           ? ClipRRect(
//               borderRadius: BorderRadius.circular(10),
//               child: NetworkImageWidget(
//                 imageUrl: imageUrl,
//                 width: 50,
//                 height: 50,
//                 fit: BoxFit.cover,
//                 errorWidget: Icon(
//                   fallbackIcon,
//                   color: AppColors.primary,
//                   size: 28,
//                 ),
//               ),
//             )
//           : Icon(
//               fallbackIcon,
//               color: AppColors.primary,
//               size: 28,
//             ),
//     );
//   }
//
//   Widget _buildEarningsChip(double earnings) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       decoration: BoxDecoration(
//         color: AppColors.success.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: AppColors.success.withOpacity(0.3)),
//       ),
//       child: Column(
//         children: [
//           Text(
//             'Penghasilan',
//             style: AppTextStyles.bodySmall.copyWith(
//               color: AppColors.success,
//             ),
//           ),
//           const SizedBox(height: 2),
//           Text(
//             _formatRupiah(earnings),
//             style: AppTextStyles.bodyMedium.copyWith(
//               fontWeight: FontWeight.w600,
//               color: AppColors.success,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDetailButton() {
//     return ElevatedButton(
//       onPressed: null, // Will be handled by card tap
//       style: ElevatedButton.styleFrom(
//         backgroundColor: AppColors.primary,
//         foregroundColor: Colors.white,
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(10),
//         ),
//       ),
//       child: Text(
//         'Lihat Detail',
//         style: AppTextStyles.labelMedium.copyWith(
//           fontWeight: FontWeight.w500,
//           color: Colors.white,
//         ),
//       ),
//     );
//   }
//
//   void _navigateToDetail(DriverRequestModel request) {
//     Get.to(() => DriverOrderDetailView(
//           requestId: request.id.toString(),
//           orderId: request.orderId.toString(),
//         ));
//   }
//
//   String _formatRupiah(double amount) {
//     return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
//           RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
//           (Match m) => '${m[1]}.',
//         )}';
//   }
// }
