// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'dart:async';
// import '../services/stokin_service.dart';
// import '../services/do_service.dart';
// import '../services/api_service.dart';
// import '../services/session_manager.dart';
// import '../models/stokin_model.dart';
// import '../widgets/base_layout.dart';
// import 'add_item_modal.dart';
// import 'load_do_dialog.dart';
//
// class StokinFormScreen extends StatefulWidget {
//   final Map<String, dynamic>? stokinHeader;
//   final VoidCallback onStokinSaved;
//
//   const StokinFormScreen({
//     super.key,
//     this.stokinHeader,
//     required this.onStokinSaved,
//   });
//
//   @override
//   State<StokinFormScreen> createState() => _StokinFormScreenState();
// }
//
// class _StokinFormScreenState extends State<StokinFormScreen> with SingleTickerProviderStateMixin {
//   final TextEditingController _searchController = TextEditingController();
//   final TextEditingController _keteranganController = TextEditingController();
//   final TextEditingController _barcodeController = TextEditingController();
//   final Map<int, TextEditingController> _qtyControllers = {};
//   final FocusNode _barcodeFocusNode = FocusNode();
//   final FocusNode _searchFocusNode = FocusNode();
//   final FocusNode _keteranganFocusNode = FocusNode();
//   final FocusNode _globalFocusNode = FocusNode();
//
//   final Color _primaryDark = const Color(0xFF2C3E50);
//   final Color _primaryLight = const Color(0xFF34495E);
//   final Color _accentGold = const Color(0xFFF6A918);
//   final Color _accentMint = const Color(0xFF06D6A0);
//   final Color _accentCoral = const Color(0xFFFF6B6B);
//   final Color _accentSky = const Color(0xFF4CC9F0);
//   final Color _bgSoft = const Color(0xFFF8FAFC);
//   final Color _surfaceWhite = Colors.white;
//   final Color _textDark = const Color(0xFF1A202C);
//   final Color _textMedium = const Color(0xFF718096);
//   final Color _textLight = const Color(0xFFA0AEC0);
//   final Color _borderSoft = const Color(0xFFE2E8F0);
//   final Color _shadowColor = const Color(0xFF2C3E50).withOpacity(0.1);
//
//   final Color _primarySoft = const Color(0xFF2C3E50).withOpacity(0.1);
//   final Color _accentGoldSoft = const Color(0xFFF6A918).withOpacity(0.1);
//   final Color _accentMintSoft = const Color(0xFF06D6A0).withOpacity(0.1);
//
//   DateTime _selectedDate = DateTime.now();
//   bool _isLoading = false;
//   bool _isSaving = false;
//   bool _scannerActive = true;
//
//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;
//   late Animation<Offset> _slideAnimation;
//
//   List<StokinItem> _allItems = [];
//   List<StokinItem> _filteredItems = [];
//   List<StokinItem> _selectedItems = [];
//
//   String? _nomorStokin;
//
//   bool _isFromPenjualan = false;
//   List<String> _referensiList = [];
//
//   bool _isFromDo = false;
//   String? _currentDoNomor;
//
//   String _barcodeBuffer = '';
//   Timer? _barcodeTimer;
//
//   bool _isSearching = false;
//
//   final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
//
//   @override
//   void initState() {
//     super.initState();
//
//     _animationController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 300),
//     );
//     _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
//     );
//     _slideAnimation = Tween<Offset>(
//       begin: const Offset(0, 0.1),
//       end: Offset.zero,
//     ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
//
//     _animationController.forward();
//
//     if (widget.stokinHeader != null) {
//       _nomorStokin = widget.stokinHeader!['sti_nomor'];
//       _selectedDate = DateTime.parse(widget.stokinHeader!['sti_tanggal']);
//       _keteranganController.text = widget.stokinHeader!['sti_keterangan'] ?? '';
//       _loadStokinDetail();
//     }
//
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       FocusScope.of(context).requestFocus(_globalFocusNode);
//     });
//   }
//
//   @override
//   void dispose() {
//     _animationController.dispose();
//     _searchController.dispose();
//     _keteranganController.dispose();
//     _barcodeController.dispose();
//     _barcodeFocusNode.dispose();
//     _searchFocusNode.dispose();
//     _keteranganFocusNode.dispose();
//     _globalFocusNode.dispose();
//     _qtyControllers.values.forEach((controller) => controller.dispose());
//     _barcodeTimer?.cancel();
//     super.dispose();
//   }
//
//   void _handleRawKeyEvent(RawKeyEvent event) {
//     if (event is! RawKeyDownEvent) return;
//     if (!_scannerActive) return;
//
//     final focusedNode = FocusScope.of(context).focusedChild;
//     if (focusedNode != null) {
//       final isSearchField = focusedNode == _searchFocusNode;
//       final isKeteranganField = focusedNode == _keteranganFocusNode;
//       final isBarcodeField = focusedNode == _barcodeFocusNode;
//
//       if (isSearchField || isKeteranganField) {
//         if (!isBarcodeField) {
//           return;
//         }
//       }
//     }
//
//     final logicalKey = event.logicalKey;
//     final keyLabel = logicalKey.keyLabel;
//
//     if (logicalKey == LogicalKeyboardKey.enter || logicalKey == LogicalKeyboardKey.tab) {
//       _processBarcodeFromBuffer();
//       return;
//     }
//
//     if (_isValidBarcodeCharacter(keyLabel)) {
//       _barcodeBuffer += keyLabel;
//       _resetBarcodeTimer();
//     }
//   }
//
//   bool _isValidBarcodeCharacter(String char) {
//     if (char.isEmpty || char.length > 1) return false;
//     if (char == 'Enter' || char == 'Tab' || char == 'Escape') return false;
//
//     final code = char.codeUnitAt(0);
//     return (code >= 48 && code <= 57) ||
//         (code >= 65 && code <= 90) ||
//         (code >= 97 && code <= 122) ||
//         char == '-' || char == '.' || char == '_' || char == '/';
//   }
//
//   void _resetBarcodeTimer() {
//     _barcodeTimer?.cancel();
//     _barcodeTimer = Timer(const Duration(milliseconds: 100), () {
//       if (_barcodeBuffer.isNotEmpty && _barcodeBuffer.length >= 3) {
//         _processBarcodeFromBuffer();
//       } else {
//         _barcodeBuffer = '';
//       }
//     });
//   }
//
//   void _processBarcodeFromBuffer() {
//     if (_barcodeBuffer.isEmpty) return;
//     final barcode = _barcodeBuffer.trim();
//     _barcodeBuffer = '';
//     _processBarcode(barcode);
//   }
//
//   Future<void> _processBarcode(String barcode) async {
//     final cleanBarcode = barcode.trim();
//     if (cleanBarcode.isEmpty) return;
//
//     final itemId = int.tryParse(cleanBarcode);
//     if (itemId == null) {
//       _showToast('Format barcode tidak valid', type: ToastType.error);
//       return;
//     }
//
//     setState(() => _isLoading = true);
//
//     try {
//       final existingIndex = _selectedItems.indexWhere((item) => item.itemId == itemId);
//
//       if (existingIndex >= 0) {
//         final existingItem = _selectedItems[existingIndex];
//         final newQty = existingItem.qty + 1;
//         _qtyControllers[itemId]?.text = newQty.toString();
//         _updateItemQty(itemId, newQty);
//         _showToast('${existingItem.itemNama} +1 (Qty: $newQty)', type: ToastType.success);
//         HapticFeedback.lightImpact();
//       } else {
//         if (_isFromDo) {
//           _showToast('Tidak bisa menambah item baru karena berasal dari DO', type: ToastType.info);
//           HapticFeedback.heavyImpact();
//         } else {
//           final items = await StokinService.getItemsForStokIn();
//           Map<String, dynamic>? itemData;
//
//           for (var item in items) {
//             if (item['item_id'] == itemId) {
//               itemData = item;
//               break;
//             }
//           }
//
//           if (itemData != null) {
//             final newItem = StokinItem(
//               itemId: itemId,
//               itemNama: itemData['item_nama']?.toString() ?? '',
//               qty: 1,
//             );
//
//             setState(() {
//               _selectedItems.add(newItem);
//               _filteredItems = List.from(_selectedItems);
//             });
//
//             _qtyControllers[itemId] = TextEditingController(text: '1');
//
//             _showToast('Item ditambahkan: ${newItem.itemNama} (Qty: 1)', type: ToastType.success);
//             HapticFeedback.mediumImpact();
//           } else {
//             _showToast('Item dengan ID $itemId tidak ditemukan', type: ToastType.error);
//             HapticFeedback.heavyImpact();
//           }
//         }
//       }
//     } catch (e) {
//       _showToast('Error: ${e.toString()}', type: ToastType.error);
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
//
//   void _showToast(String message, {required ToastType type}) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(
//           children: [
//             Icon(
//               type == ToastType.success ? Icons.check_circle_rounded :
//               type == ToastType.error ? Icons.error_rounded :
//               Icons.info_rounded,
//               color: Colors.white,
//               size: 16,
//             ),
//             const SizedBox(width: 8),
//             Expanded(
//               child: Text(
//                 message,
//                 style: GoogleFonts.montserrat(color: Colors.white, fontSize: 11),
//               ),
//             ),
//           ],
//         ),
//         backgroundColor: type == ToastType.success ? _accentMint :
//         type == ToastType.error ? _accentCoral : _accentSky,
//         behavior: SnackBarBehavior.floating,
//         margin: const EdgeInsets.all(12),
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//         duration: const Duration(seconds: 2),
//       ),
//     );
//   }
//
//   Future<Map<String, String>> _getHeaders() async {
//     final token = await SessionManager.getToken();
//     return {
//       'Content-Type': 'application/json',
//       if (token != null) 'Authorization': 'Bearer $token',
//     };
//   }
//
//   Future<void> _loadStokinDetail() async {
//     if (_nomorStokin == null) return;
//     setState(() => _isLoading = true);
//
//     try {
//       final detail = await StokinService.getStokInDetail(_nomorStokin!);
//       final details = List<Map<String, dynamic>>.from(detail['details']);
//
//       setState(() {
//         _selectedItems = details.map((detail) {
//           return StokinItem(
//             itemId: detail['stid_item_id'],
//             itemNama: detail['item_nama'] ?? '',
//             qty: detail['stid_qty']?.toInt() ?? 0,
//             referensi: detail['referensi'],
//           );
//         }).toList();
//
//         _filteredItems = _selectedItems;
//         _initializeControllers();
//       });
//     } catch (e) {
//       _showToast('Gagal memuat detail: ${e.toString()}', type: ToastType.error);
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
//
//   void _initializeControllers() {
//     for (var item in _selectedItems) {
//       _qtyControllers[item.itemId] = TextEditingController(
//           text: item.qty > 0 ? item.qty.toString() : ''
//       );
//     }
//   }
//
//   void _filterItems(String query) {
//     setState(() {
//       if (query.isEmpty) {
//         _filteredItems = _selectedItems;
//       } else {
//         final searchLower = query.toLowerCase();
//         _filteredItems = _selectedItems.where((item) {
//           return item.itemNama.toLowerCase().contains(searchLower);
//         }).toList();
//       }
//     });
//   }
//
//   void _updateItemQty(int itemId, int newQty) {
//     setState(() {
//       final index = _selectedItems.indexWhere((item) => item.itemId == itemId);
//       if (index != -1) {
//         _selectedItems[index] = StokinItem(
//           itemId: _selectedItems[index].itemId,
//           itemNama: _selectedItems[index].itemNama,
//           qty: newQty,
//         );
//
//         final filteredIndex = _filteredItems.indexWhere((item) => item.itemId == itemId);
//         if (filteredIndex != -1) {
//           _filteredItems[filteredIndex] = StokinItem(
//             itemId: _filteredItems[filteredIndex].itemId,
//             itemNama: _filteredItems[filteredIndex].itemNama,
//             qty: newQty,
//           );
//         }
//       }
//     });
//   }
//
//   void _deleteItem(StokinItem item) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         title: Text('Hapus Item', style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600)),
//         content: Text(
//           'Hapus ${item.itemNama} dari daftar?',
//           style: GoogleFonts.montserrat(fontSize: 11, color: _textMedium),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Batal', style: GoogleFonts.montserrat(fontSize: 10, color: _textMedium)),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               setState(() {
//                 _selectedItems.removeWhere((i) => i.itemId == item.itemId);
//                 _filteredItems = List.from(_selectedItems);
//                 _qtyControllers[item.itemId]?.dispose();
//                 _qtyControllers.remove(item.itemId);
//               });
//               Navigator.pop(context);
//               _showToast('${item.itemNama} dihapus', type: ToastType.info);
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: _accentCoral,
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
//               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//             ),
//             child: Text('Hapus', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _showAddItemModal() async {
//     HapticFeedback.selectionClick();
//     final selectedItems = await showModalBottomSheet<List<StokinItem>>(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => Container(
//         decoration: const BoxDecoration(
//           color: Colors.transparent,
//         ),
//         child: AddItemModal(
//           existingItems: _selectedItems,
//         ),
//       ),
//     );
//
//     if (selectedItems != null && selectedItems.isNotEmpty) {
//       setState(() {
//         for (var newItem in selectedItems) {
//           final existingIndex = _selectedItems.indexWhere((item) => item.itemId == newItem.itemId);
//           if (existingIndex >= 0) {
//             _selectedItems[existingIndex].qty += newItem.qty;
//           } else {
//             _selectedItems.add(newItem);
//           }
//         }
//         _filteredItems = List.from(_selectedItems);
//         _initializeControllers();
//         _isFromDo = false;
//         _currentDoNomor = null;
//       });
//       _showToast('${selectedItems.length} item ditambahkan', type: ToastType.success);
//     }
//   }
//
//   Future<void> _selectDate(BuildContext context) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _selectedDate,
//       firstDate: DateTime(2020),
//       lastDate: DateTime.now(),
//       builder: (context, child) {
//         return Theme(
//           data: ThemeData.light().copyWith(
//             colorScheme: ColorScheme.light(
//               primary: _primaryDark,
//               onPrimary: Colors.white,
//               surface: _surfaceWhite,
//               onSurface: _textDark,
//             ),
//             dialogBackgroundColor: _surfaceWhite,
//           ),
//           child: child!,
//         );
//       },
//     );
//
//     if (picked != null && picked != _selectedDate) {
//       setState(() => _selectedDate = picked);
//     }
//   }
//
//   void _updateAllQtyFromControllers() {
//     for (var entry in _qtyControllers.entries) {
//       final itemId = entry.key;
//       final controller = entry.value;
//       final intValue = int.tryParse(controller.text) ?? 0;
//       _updateItemQty(itemId, intValue);
//     }
//   }
//
//   Future<void> _saveStokin() async {
//     if (_keteranganController.text.trim().isEmpty) {
//       _showToast('Keterangan harus diisi!', type: ToastType.error);
//       return;
//     }
//
//     _updateAllQtyFromControllers();
//
//     final itemsWithQty = _selectedItems.where((item) => item.qty > 0).toList();
//     if (itemsWithQty.isEmpty) {
//       _showToast('Minimal satu item harus memiliki quantity!', type: ToastType.error);
//       return;
//     }
//
//     setState(() => _isSaving = true);
//     HapticFeedback.mediumImpact();
//
//     try {
//       final tanggalStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
//
//       final Map<String, dynamic> requestData = {
//         'tanggal': tanggalStr,
//         'keterangan': _keteranganController.text.trim(),
//         'items': itemsWithQty.map((item) => item.toJson()).toList(),
//       };
//
//       if (_isFromPenjualan && _referensiList.isNotEmpty) {
//         requestData['source'] = 'penjualan';
//         requestData['referensi_list'] = _referensiList.join(',');
//       }
//
//       if (_isFromDo && _currentDoNomor != null) {
//         requestData['sti_do_nomor'] = _currentDoNomor;
//       }
//
//       final result = widget.stokinHeader == null
//           ? await StokinService.createStokIn(requestData)
//           : await StokinService.updateStokIn({
//         'nomor': _nomorStokin!,
//         'tanggal': tanggalStr,
//         'keterangan': _keteranganController.text.trim(),
//         'items': itemsWithQty.map((item) => item.toJson()).toList(),
//         'source': _isFromPenjualan && _referensiList.isNotEmpty ? 'penjualan' : null,
//         'referensi_list': _isFromPenjualan && _referensiList.isNotEmpty
//             ? _referensiList.join(',')
//             : null,
//         'sti_do_nomor': _isFromDo ? _currentDoNomor : null,
//       });
//
//       if (result['success']) {
//         _showToast(result['message'], type: ToastType.success);
//         widget.onStokinSaved();
//         Navigator.pop(context);
//       } else {
//         _showToast(result['message'], type: ToastType.error);
//       }
//     } catch (e) {
//       _showToast('Error: ${e.toString()}', type: ToastType.error);
//     } finally {
//       setState(() => _isSaving = false);
//     }
//   }
//
//   int get _totalItemsWithQty {
//     return _selectedItems.where((item) => item.qty > 0).length;
//   }
//
//   int get _totalQuantity {
//     return _selectedItems.fold(0, (sum, item) => sum + item.qty);
//   }
//
//   Future<void> _loadPenjualan() async {
//     final tanggalStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
//
//     setState(() {
//       _isLoading = true;
//       _isFromDo = false;
//       _currentDoNomor = null;
//     });
//
//     try {
//       final penjualanData = await StokinService.loadPenjualan(tanggalStr);
//
//       if (penjualanData.isEmpty) {
//         _showToast('Tidak ada data penjualan', type: ToastType.info);
//         setState(() => _isLoading = false);
//         return;
//       }
//
//       final newItems = <StokinItem>[];
//       final referensiList = <String>[];
//
//       for (var data in penjualanData) {
//         final itemId = int.parse(data['item_id'].toString());
//         final qty = int.parse(data['qty'].toString());
//         final referensi = data['referensi_list'].toString();
//         final itemNama = data['item_nama'].toString();
//
//         bool exists = false;
//         for (int i = 0; i < _selectedItems.length; i++) {
//           if (_selectedItems[i].itemId == itemId) {
//             exists = true;
//             break;
//           }
//         }
//
//         if (!exists) {
//           newItems.add(StokinItem(
//             itemId: itemId,
//             itemNama: itemNama,
//             qty: qty,
//             referensi: referensi,
//           ));
//
//           if (referensi.isNotEmpty) {
//             final refs = referensi.split(',');
//             for (var r in refs) {
//               final trimmed = r.trim();
//               if (trimmed.isNotEmpty) {
//                 referensiList.add(trimmed);
//               }
//             }
//           }
//         }
//       }
//
//       final updatedSelectedItems = List<StokinItem>.from(_selectedItems);
//       updatedSelectedItems.addAll(newItems);
//
//       setState(() {
//         _selectedItems = updatedSelectedItems;
//         _filteredItems = List.from(updatedSelectedItems);
//         _isFromPenjualan = true;
//         _referensiList = referensiList.toSet().toList();
//         _initializeControllers();
//       });
//
//       _showToast('Berhasil load ${newItems.length} item', type: ToastType.success);
//       HapticFeedback.lightImpact();
//     } catch (e) {
//       _showToast('Error: $e', type: ToastType.error);
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
//
//   Future<void> _showDoSelectionDialog() async {
//     await showDialog(
//       context: context,
//       builder: (context) => LoadDoDialog(
//         onLoad: _loadDoItems,
//       ),
//     );
//   }
//
//   Future<void> _loadDoItems(String doNomor) async {
//     setState(() {
//       _isLoading = true;
//       _isFromDo = true;
//       _currentDoNomor = doNomor;
//       _isFromPenjualan = false;
//       _referensiList.clear();
//     });
//
//     try {
//       final data = await DoService.getDoDetailForStokIn(doNomor);
//       final header = data['header'];
//       final details = data['details'];
//
//       final newItems = details.map<StokinItem>((detail) {
//         return StokinItem(
//           itemId: detail['item_id'],
//           itemNama: detail['item_nama'],
//           qty: 0,
//         );
//       }).toList();
//
//       setState(() {
//         _selectedItems = newItems;
//         _filteredItems = List.from(newItems);
//         _keteranganController.text = header['do_nomor'] ?? '';
//         _initializeControllers();
//       });
//
//       _showToast('Berhasil load ${newItems.length} item dari DO', type: ToastType.success);
//       HapticFeedback.lightImpact();
//     } catch (e) {
//       _showToast('Error: $e', type: ToastType.error);
//       setState(() {
//         _isFromDo = false;
//         _currentDoNomor = null;
//       });
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
//
//   Widget _buildScanToggle() {
//     return Container(
//       height: 28,
//       margin: const EdgeInsets.only(right: 8),
//       child: Material(
//         color: _scannerActive ? _accentMint : _bgSoft,
//         borderRadius: BorderRadius.circular(6),
//         child: InkWell(
//           onTap: () {
//             setState(() {
//               _scannerActive = !_scannerActive;
//               if (_scannerActive) {
//                 _globalFocusNode.requestFocus();
//                 _showToast('Mode scan aktif', type: ToastType.success);
//               } else {
//                 _showToast('Mode scan nonaktif', type: ToastType.info);
//               }
//             });
//           },
//           borderRadius: BorderRadius.circular(6),
//           child: Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//             child: Row(
//               children: [
//                 Icon(
//                   _scannerActive ? Icons.qr_code_scanner : Icons.keyboard_hide,
//                   size: 14,
//                   color: _scannerActive ? Colors.white : _textDark,
//                 ),
//                 const SizedBox(width: 4),
//                 Text(
//                   _scannerActive ? 'Scan ON' : 'Scan OFF',
//                   style: GoogleFonts.montserrat(
//                     fontSize: 9,
//                     fontWeight: FontWeight.w500,
//                     color: _scannerActive ? Colors.white : _textDark,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final isEdit = widget.stokinHeader != null;
//
//     return RawKeyboardListener(
//       focusNode: _globalFocusNode,
//       onKey: _handleRawKeyEvent,
//       child: BaseLayout(
//         title: isEdit ? 'Edit Stock In' : 'Tambah Stock In',
//         showBackButton: true,
//         showSidebar: true,
//         isFormScreen: true,
//         actions: [
//           _buildScanToggle(),
//         ],
//         child: FadeTransition(
//           opacity: _fadeAnimation,
//           child: SlideTransition(
//             position: _slideAnimation,
//             child: Container(
//               color: _bgSoft,
//               child: Column(
//                 children: [
//                   Expanded(
//                     child: SingleChildScrollView(
//                       physics: const BouncingScrollPhysics(),
//                       padding: const EdgeInsets.all(12),
//                       child: Column(
//                         children: [
//                           _buildInfoCard(),
//                           const SizedBox(height: 12),
//                           _buildItemsCard(),
//                         ],
//                       ),
//                     ),
//                   ),
//                   _buildModernBottomBar(isEdit),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildInfoCard() {
//     return Container(
//       decoration: BoxDecoration(
//         color: _surfaceWhite,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: _borderSoft),
//         boxShadow: [
//           BoxShadow(
//             color: _shadowColor,
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Row(
//           children: [
//             Expanded(
//               child: InkWell(
//                 onTap: () => _selectDate(context),
//                 borderRadius: BorderRadius.circular(8),
//                 child: Container(
//                   height: 40,
//                   padding: const EdgeInsets.symmetric(horizontal: 10),
//                   decoration: BoxDecoration(
//                     color: _bgSoft,
//                     borderRadius: BorderRadius.circular(8),
//                     border: Border.all(color: _borderSoft),
//                   ),
//                   child: Row(
//                     children: [
//                       Icon(Icons.calendar_today_rounded, color: _primaryDark, size: 14),
//                       const SizedBox(width: 8),
//                       Expanded(
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text('Tanggal', style: GoogleFonts.montserrat(fontSize: 9, color: _textMedium)),
//                             Text(
//                               DateFormat('dd/MM/yyyy').format(_selectedDate),
//                               style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: _textDark),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(width: 8),
//             Expanded(
//               flex: 2,
//               child: Container(
//                 height: 40,
//                 decoration: BoxDecoration(
//                   color: _bgSoft,
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(color: _borderSoft),
//                 ),
//                 child: Row(
//                   children: [
//                     Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 10),
//                       child: Icon(Icons.description_rounded, color: _primaryDark, size: 14),
//                     ),
//                     Expanded(
//                       child: TextFormField(
//                         controller: _keteranganController,
//                         focusNode: _keteranganFocusNode,
//                         style: GoogleFonts.montserrat(fontSize: 11, color: _textDark),
//                         decoration: InputDecoration(
//                           hintText: 'Keterangan...',
//                           hintStyle: GoogleFonts.montserrat(fontSize: 11, color: _textLight),
//                           border: InputBorder.none,
//                           contentPadding: EdgeInsets.zero,
//                           isDense: true,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildItemsCard() {
//     return Container(
//       decoration: BoxDecoration(
//         color: _surfaceWhite,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: _borderSoft),
//         boxShadow: [
//           BoxShadow(
//             color: _shadowColor,
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(12),
//             child: Row(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(6),
//                   decoration: BoxDecoration(
//                     color: _primarySoft,
//                     borderRadius: BorderRadius.circular(6),
//                   ),
//                   child: Icon(Icons.inventory_2_rounded, color: _primaryDark, size: 14),
//                 ),
//                 const SizedBox(width: 8),
//                 Text('Daftar Item', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: _textDark)),
//                 const Spacer(),
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                   decoration: BoxDecoration(
//                     color: _bgSoft,
//                     borderRadius: BorderRadius.circular(20),
//                     border: Border.all(color: _borderSoft),
//                   ),
//                   child: Row(
//                     children: [
//                       Icon(Icons.shopping_bag_rounded, size: 10, color: _primaryDark),
//                       const SizedBox(width: 4),
//                       Text('${_selectedItems.length} items', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w500, color: _textDark)),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
//             child: Column(
//               children: [
//                 Row(
//                   children: [
//                     Expanded(
//                       flex: 3,
//                       child: Container(
//                         height: 40,
//                         decoration: BoxDecoration(
//                           color: _bgSoft,
//                           borderRadius: BorderRadius.circular(8),
//                           border: Border.all(color: _borderSoft),
//                         ),
//                         child: Row(
//                           children: [
//                             Padding(
//                               padding: const EdgeInsets.symmetric(horizontal: 10),
//                               child: Icon(Icons.search_rounded, color: _primaryDark, size: 14),
//                             ),
//                             Expanded(
//                               child: TextField(
//                                 controller: _searchController,
//                                 focusNode: _searchFocusNode,
//                                 style: GoogleFonts.montserrat(fontSize: 11),
//                                 onChanged: _filterItems,
//                                 decoration: InputDecoration(
//                                   hintText: 'Cari item...',
//                                   hintStyle: GoogleFonts.montserrat(fontSize: 11, color: _textLight),
//                                   border: InputBorder.none,
//                                   contentPadding: EdgeInsets.zero,
//                                   isDense: true,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     Expanded(
//                       flex: 2,
//                       child: Container(
//                         height: 40,
//                         decoration: BoxDecoration(
//                           color: _bgSoft,
//                           borderRadius: BorderRadius.circular(8),
//                           border: Border.all(color: _borderSoft),
//                         ),
//                         child: Row(
//                           children: [
//                             Padding(
//                               padding: const EdgeInsets.symmetric(horizontal: 10),
//                               child: Icon(Icons.qr_code_scanner_rounded, color: _accentMint, size: 14),
//                             ),
//                             Expanded(
//                               child: TextField(
//                                 controller: _barcodeController,
//                                 focusNode: _barcodeFocusNode,
//                                 style: GoogleFonts.montserrat(fontSize: 11),
//                                 onSubmitted: (value) {
//                                   if (value.isNotEmpty) {
//                                     _processBarcode(value);
//                                     _barcodeController.clear();
//                                   }
//                                 },
//                                 decoration: InputDecoration(
//                                   hintText: 'Scan barcode...',
//                                   hintStyle: GoogleFonts.montserrat(fontSize: 11, color: _textLight),
//                                   border: InputBorder.none,
//                                   contentPadding: EdgeInsets.zero,
//                                   isDense: true,
//                                 ),
//                               ),
//                             ),
//                             if (_barcodeController.text.isNotEmpty)
//                               Padding(
//                                 padding: const EdgeInsets.only(right: 8),
//                                 child: GestureDetector(
//                                   onTap: () => _barcodeController.clear(),
//                                   child: Icon(Icons.close_rounded, color: _textLight, size: 12),
//                                 ),
//                               ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 10),
//                 Row(
//                   children: [
//                     _buildModernActionButton(
//                       label: 'Add',
//                       icon: Icons.add_rounded,
//                       color: _accentSky,
//                       onPressed: _isFromDo ? null : _showAddItemModal,
//                     ),
//                     const SizedBox(width: 4),
//                     _buildModernActionButton(
//                       label: 'Penjualan',
//                       icon: Icons.download_rounded,
//                       color: _accentMint,
//                       onPressed: _loadPenjualan,
//                     ),
//                     const SizedBox(width: 4),
//                     _buildModernActionButton(
//                       label: 'DO',
//                       icon: Icons.local_shipping_rounded,
//                       color: _accentGold,
//                       onPressed: _showDoSelectionDialog,
//                     ),
//                     const Spacer(),
//                     Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                       decoration: BoxDecoration(color: _primarySoft, borderRadius: BorderRadius.circular(6)),
//                       child: Text('${_selectedItems.length}', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _primaryDark)),
//                     ),
//                     const SizedBox(width: 4),
//                     Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                       decoration: BoxDecoration(color: _accentMintSoft, borderRadius: BorderRadius.circular(6)),
//                       child: Text('$_totalQuantity', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _accentMint)),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 12),
//                 if (_filteredItems.isEmpty)
//                   _buildEmptyState()
//                 else
//                   ListView.separated(
//                     shrinkWrap: true,
//                     physics: const NeverScrollableScrollPhysics(),
//                     itemCount: _filteredItems.length,
//                     separatorBuilder: (context, index) => const SizedBox(height: 6),
//                     itemBuilder: (context, index) => _buildModernItemCard(_filteredItems[index]),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildModernActionButton({
//     required String label,
//     required IconData icon,
//     required Color color,
//     required VoidCallback? onPressed,
//   }) {
//     return Container(
//       height: 28,
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [color, color.withOpacity(0.8)],
//           begin: Alignment.centerLeft,
//           end: Alignment.centerRight,
//         ),
//         borderRadius: BorderRadius.circular(6),
//         boxShadow: [
//           BoxShadow(
//             color: color.withOpacity(0.2),
//             blurRadius: 4,
//             offset: const Offset(0, 1),
//           ),
//         ],
//       ),
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           onTap: onPressed,
//           borderRadius: BorderRadius.circular(6),
//           child: Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 10),
//             child: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(icon, size: 11, color: Colors.white),
//                 const SizedBox(width: 4),
//                 Text(label, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildModernItemCard(StokinItem item) {
//     if (!_qtyControllers.containsKey(item.itemId)) {
//       _qtyControllers[item.itemId] = TextEditingController(text: item.qty > 0 ? item.qty.toString() : '');
//     }
//
//     final controller = _qtyControllers[item.itemId]!;
//     final hasQty = item.qty > 0;
//
//     return Container(
//       decoration: BoxDecoration(
//         color: _surfaceWhite,
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(
//           color: hasQty ? _primaryDark.withOpacity(0.3) : _borderSoft,
//           width: hasQty ? 1.5 : 1,
//         ),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(8),
//         child: Row(
//           children: [
//             Container(
//               width: 36,
//               height: 36,
//               decoration: BoxDecoration(
//                 color: hasQty ? _primaryDark : _bgSoft,
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Center(
//                 child: Icon(
//                   Icons.inventory_2_outlined,
//                   color: hasQty ? Colors.white : _textLight,
//                   size: 16,
//                 ),
//               ),
//             ),
//             const SizedBox(width: 8),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     item.itemNama,
//                     style: GoogleFonts.montserrat(
//                       fontSize: 11,
//                       fontWeight: FontWeight.w600,
//                       color: _textDark,
//                     ),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                   const SizedBox(height: 2),
//                   Row(
//                     children: [
//                       Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
//                         decoration: BoxDecoration(
//                           color: _bgSoft,
//                           borderRadius: BorderRadius.circular(4),
//                         ),
//                         child: Text('ID: ${item.itemId}', style: GoogleFonts.montserrat(fontSize: 8, color: _textMedium)),
//                       ),
//                       if (hasQty) ...[
//                         const SizedBox(width: 4),
//                         Container(
//                           padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
//                           decoration: BoxDecoration(
//                             color: _accentMintSoft,
//                             borderRadius: BorderRadius.circular(4),
//                           ),
//                           child: Text('Qty: ${item.qty}', style: GoogleFonts.montserrat(fontSize: 8, fontWeight: FontWeight.w600, color: _accentMint)),
//                         ),
//                       ],
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//             SizedBox(
//               width: 60,
//               height: 32,
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: _bgSoft,
//                   borderRadius: BorderRadius.circular(6),
//                   border: Border.all(color: hasQty ? _primaryDark.withOpacity(0.3) : _borderSoft),
//                 ),
//                 child: TextField(
//                   controller: controller,
//                   keyboardType: TextInputType.number,
//                   textAlign: TextAlign.center,
//                   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                   style: GoogleFonts.montserrat(
//                     fontSize: 11,
//                     fontWeight: FontWeight.w600,
//                     color: hasQty ? _primaryDark : _textLight,
//                   ),
//                   decoration: InputDecoration(
//                     hintText: '0',
//                     border: InputBorder.none,
//                     contentPadding: EdgeInsets.zero,
//                     isDense: true,
//                     hintStyle: GoogleFonts.montserrat(fontSize: 11, color: _textLight),
//                   ),
//                   onChanged: (value) {
//                     final intValue = int.tryParse(value) ?? 0;
//                     _updateItemQty(item.itemId, intValue);
//                   },
//                 ),
//               ),
//             ),
//             const SizedBox(width: 6),
//             GestureDetector(
//               onTap: () => _deleteItem(item),
//               child: Container(
//                 width: 28,
//                 height: 28,
//                 decoration: BoxDecoration(
//                   color: _accentCoral.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(6),
//                 ),
//                 child: Icon(Icons.delete_outline, size: 14, color: _accentCoral),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildEmptyState() {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 24),
//       child: Column(
//         children: [
//           Container(
//             width: 64,
//             height: 64,
//             decoration: BoxDecoration(
//               color: _bgSoft,
//               shape: BoxShape.circle,
//             ),
//             child: Icon(
//               _searchController.text.isEmpty
//                   ? Icons.inventory_2_outlined
//                   : Icons.search_off_rounded,
//               size: 32,
//               color: _textLight,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             _searchController.text.isEmpty
//                 ? 'Belum ada item'
//                 : 'Item tidak ditemukan',
//             style: GoogleFonts.montserrat(
//               fontSize: 12,
//               fontWeight: FontWeight.w500,
//               color: _textDark,
//             ),
//           ),
//           const SizedBox(height: 2),
//           Text(
//             _searchController.text.isEmpty
//                 ? 'Tambah item dengan tombol di atas atau scan barcode'
//                 : 'Coba kata kunci lain',
//             style: GoogleFonts.montserrat(
//               fontSize: 10,
//               color: _textLight,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildModernBottomBar(bool isEdit) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: _surfaceWhite,
//         border: Border(top: BorderSide(color: _borderSoft)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.02),
//             blurRadius: 8,
//             offset: const Offset(0, -2),
//           ),
//         ],
//       ),
//       child: SafeArea(
//         child: Row(
//           children: [
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text('Item dengan QTY', style: GoogleFonts.montserrat(fontSize: 9, color: _textLight)),
//                   Row(
//                     children: [
//                       Icon(Icons.check_circle_rounded, size: 12, color: _accentMint),
//                       const SizedBox(width: 4),
//                       Text(
//                         '$_totalItemsWithQty dari ${_selectedItems.length}',
//                         style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: _textDark),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//             Container(
//               width: 120,
//               height: 40,
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [_primaryDark, _primaryLight],
//                   begin: Alignment.centerLeft,
//                   end: Alignment.centerRight,
//                 ),
//                 borderRadius: BorderRadius.circular(8),
//                 boxShadow: [
//                   BoxShadow(
//                     color: _primaryDark.withOpacity(0.2),
//                     blurRadius: 6,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: Material(
//                 color: Colors.transparent,
//                 child: InkWell(
//                   onTap: _isSaving ? null : _saveStokin,
//                   borderRadius: BorderRadius.circular(8),
//                   child: Center(
//                     child: _isSaving
//                         ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
//                         : Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(isEdit ? Icons.edit_rounded : Icons.save_rounded, color: Colors.white, size: 14),
//                         const SizedBox(width: 6),
//                         Text(isEdit ? 'Update' : 'Simpan', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// enum ToastType { success, error, info }