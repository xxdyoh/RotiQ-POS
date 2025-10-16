import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';
import 'package:image/image.dart' as img;
import 'printer_service.dart';


class ReceiptService {
  static final currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final PrinterService _printerService = PrinterService();

  static final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');
  static final timeFormat = DateFormat('HH:mm:ss');

  // Cache logo untuk performance
  static pw.MemoryImage? _cachedLogo;

  // Load logo dari assets (optional)
  static Future<pw.MemoryImage?> _loadLogo() async {
    if (_cachedLogo != null) return _cachedLogo;

    try {
      // Jika ada logo di assets, uncomment ini:
      final logo = await rootBundle.load('assets/logo.png');
      _cachedLogo = pw.MemoryImage(logo.buffer.asUint8List());
      return _cachedLogo;
    } catch (e) {
      // Jika tidak ada logo, return null
      print('Logo not found: $e');
      return null;
    }
  }

  // Generate PDF Receipt
  static Future<pw.Document> generateReceiptPDF(Order order, String orderId) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogo();
    final igIcon = await _loadInstagramIcon();

    // ✅ HITUNG UNTUK PDF JUGA
    final subtotal = order.items.fold(0.0, (sum, item) => sum + item.total); // sudah termasuk diskon item
    final globalDiscountAmount = subtotal * (order.globalDiscount / 100);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(8),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header - Logo/Nama Toko
              pw.Center(
                child: pw.Column(
                  children: [
                    // Logo (jika ada)
                    if (logoImage != null) ...[
                      pw.Image(
                        logoImage,
                        width: 50,
                        height: 50,
                        fit: pw.BoxFit.contain,
                      ),
                      pw.SizedBox(height: 6),
                    ],

                    // Nama Toko
                    // pw.Text(
                    //   'ROTI-Q',
                    //   style: pw.TextStyle(
                    //     fontSize: 24,
                    //     fontWeight: pw.FontWeight.bold,
                    //   ),
                    // ),
                    // pw.SizedBox(height: 4),

                    // Alamat
                    pw.Text(
                      'Busukan RT 002  RW 017 Mojosongo Solo',
                      style: const pw.TextStyle(fontSize: 10),
                      textAlign: pw.TextAlign.center,
                    ),

                    // Telepon
                    pw.Text(
                      '0821-1532-9182',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // Order Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    dateFormat.format(order.createdAt),
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    timeFormat.format(order.createdAt),
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('No Bon', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(orderId, style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Kasir', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(
                    order.userName ?? 'ADMIN',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Jenis Customer', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(order.customer.name, style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Divider(thickness: 1),

              // Items
              ...order.items.map((item) {
                final hasDiscount = item.discount > 0;
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            item.product.name.toUpperCase(),
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Text(
                          'x${item.quantity}',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                        pw.SizedBox(width: 16),
                        pw.Text(
                          currencyFormat.format(hasDiscount ? item.total : item.subtotal),
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                    // Tampilkan harga coret jika ada discount
                    if (hasDiscount) ...[
                      pw.SizedBox(height: 2),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Text(
                            currencyFormat.format(item.subtotal),
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey600,
                              decoration: pw.TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (item.notes.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '  Note: ${item.notes}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                    pw.SizedBox(height: 6),
                  ],
                );
              }).toList(),

              pw.Divider(thickness: 1),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Item', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('${order.items.length}', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Qty', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(
                    '${order.items.fold(0, (sum, item) => sum + item.quantity)}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.Divider(thickness: 1),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Sub Total', style: const pw.TextStyle(fontSize: 11)),
                  pw.Text(
                    currencyFormat.format(subtotal),
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ],
              ),
              if (order.globalDiscount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Disc', style: const pw.TextStyle(fontSize: 11)),
                    pw.Text(
                      '-${currencyFormat.format(globalDiscountAmount)}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),

              // Grand Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Grand Total',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    currencyFormat.format(order.grandTotal),
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('DP', style: const pw.TextStyle(fontSize: 11)),
                  pw.Text('0', style: const pw.TextStyle(fontSize: 11)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    order.paymentMethod == 'cash' ? 'Tunai' : 'Transfer',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.Text(
                    currencyFormat.format(order.paidAmount),
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ],
              ),
              if (order.change > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Kembali', style: const pw.TextStyle(fontSize: 11)),
                    pw.Text(
                      currencyFormat.format(order.change),
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),

              pw.Divider(thickness: 1),
              pw.SizedBox(height: 8),

              // Footer - Instagram
              pw.Center(
                child: pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Image(igIcon, width: 12, height: 12),
                    pw.SizedBox(width: 4),
                    pw.Text(
                      'Rotiq_solo',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Center(
                child: pw.Text(
                  'Terima kasih',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  // Print to thermal printer
  static Future<bool> printThermalReceipt(Order order, String orderId) async {
    try {
      final items = order.items.map((item) {
        return {
          'product_name': item.product.name,
          'quantity': item.quantity,
          'price': item.product.price,
          'total': item.total,
          'discount': item.discountAmount,
        };
      }).toList();

      // ✅ HITUNG AMOUNT DARI ORDER (jika perlu)
      final subtotal = order.items.fold(0.0, (sum, item) => sum + item.subtotal);
      final itemDiscounts = order.items.fold(0.0, (sum, item) => sum + item.discountAmount);
      final orderDiscountAmount = order.globalDiscountAmount; // dari Order model

      final success = await _printerService.printReceipt(
        orderId: orderId,
        customerName: order.customer.name,
        items: items,
        subtotal: subtotal,
        orderDiscountAmount: orderDiscountAmount,
        grandTotal: order.grandTotal,
        paidAmount: order.paidAmount,
        change: order.change,
        paymentMethod: order.paymentMethod,
        cashierName: order.userName ?? 'ADMIN',
        createdAt: order.createdAt,
      );

      return success;
    } catch (e) {
      print('Thermal print error: $e');
      return false;
    }
  }

  // Print Receipt
  static Future<void> printReceipt(Order order, String orderId, {bool useThermal = false}) async {
    if (useThermal) {
      final success = await printThermalReceipt(order, orderId);
      if (!success) {
        // Fallback to PDF printing if thermal fails
        await Printing.layoutPdf(
          onLayout: (format) async => (await generateReceiptPDF(order, orderId)).save(),
          name: 'struk_$orderId.pdf',
        );
      }
    } else {
      // Use PDF printing
      await Printing.layoutPdf(
        onLayout: (format) async => (await generateReceiptPDF(order, orderId)).save(),
        name: 'struk_$orderId.pdf',
      );
    }
  }

  // di ReceiptService
  static Future<pw.MemoryImage> _loadInstagramIcon() async {
    final data = await rootBundle.load('assets/instagram.png');
    return pw.MemoryImage(data.buffer.asUint8List());
  }

  // Generate and Share Receipt dengan pilihan format
  static Future<void> shareReceipt(Order order, String orderId, {bool asImage = false}) async {
    try {
      final pdf = await generateReceiptPDF(order, orderId);

      if (asImage) {
        // Share as JPG
        await _shareAsImage(pdf, order, orderId);
      } else {
        // Share as PDF
        await _shareAsPDF(pdf, order, orderId);
      }
    } catch (e) {
      throw Exception('Gagal share struk: ${e.toString()}');
    }
  }

  // Share as PDF
  static Future<void> _shareAsPDF(pw.Document pdf, Order order, String orderId) async {
    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/struk_$orderId.pdf');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Struk Pembelian - Order #$orderId\nTotal: ${currencyFormat.format(order.grandTotal)}',
      subject: 'Struk #$orderId',
    );
  }

  // Share as Image (JPG)
  static Future<void> _shareAsImage(
      pw.Document pdf, Order order, String orderId) async {
    try {
      // Simpan PDF ke bytes
      final pdfBytes = await pdf.save();

      // Rasterize jadi stream halaman
      final pages = Printing.raster(pdfBytes, dpi: 300);

      // Ambil halaman pertama
      final firstPage = await pages.first; // Future<PdfRaster>
      final pngBytes = await firstPage.toPng();

      // Decode image dan tambahkan background putih
      final image = img.decodeImage(pngBytes);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/struk_$orderId.jpg');

      if (image != null) {
        // Buat canvas putih
        final whiteBackground = img.Image(
          width: image.width,
          height: image.height,
        );
        img.fill(whiteBackground, color: img.ColorRgb8(255, 255, 255));

        // Tempel hasil raster di atas background putih
        img.compositeImage(whiteBackground, image);

        // Encode ke JPEG
        final jpgBytes = img.encodeJpg(whiteBackground, quality: 90);
        await file.writeAsBytes(jpgBytes);
      } else {
        // fallback kalau decode gagal
        await file.writeAsBytes(pngBytes);
      }

      // Share file
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
        'Struk Pembelian - Order #$orderId\nTotal: ${currencyFormat.format(order.grandTotal)}',
        subject: 'Struk #$orderId',
      );
    } catch (e) {
      throw Exception('Gagal share struk: $e');
    }
  }

  // Generate and Share Receipt (DEPRECATED - gunakan shareReceipt)
  @deprecated
  static Future<void> generateAndShareReceipt(Order order, String orderId) async {
    await shareReceipt(order, orderId, asImage: false);
  }

  // Generate Receipt as Image (JPG)
  static Future<File> generateReceiptImage(Order order, String orderId) async {
    try {
      // 1. Generate dokumen PDF
      final pdf = await generateReceiptPDF(order, orderId);

      // 2. Convert PDF ke stream raster (halaman-halaman)
      final pages = Printing.raster(
        await pdf.save(),
        dpi: 300,
      );

      // 3. Ambil halaman pertama dari stream
      final firstPage = await pages.first; // Future<PdfRaster>
      final imageBytes = await firstPage.toPng(); // Uint8List

      // 4. Simpan ke file sementara
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/struk_$orderId.jpg');
      await file.writeAsBytes(imageBytes);

      return file;
    } catch (e) {
      throw Exception('Gagal generate image struk: ${e.toString()}');
    }
  }

  // Share Receipt as Image to WhatsApp (DEPRECATED)
  @deprecated
  static Future<void> shareReceiptToWhatsApp(Order order, String orderId) async {
    await shareReceipt(order, orderId, asImage: true);
  }
}