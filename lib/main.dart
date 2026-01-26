import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'routes/app_routes.dart';
import 'screens/setengahjadi_form_screen.dart';
import 'screens/item_form_screen.dart';
import 'screens/category_form_screen.dart';
import 'screens/discount_form_screen.dart';
import 'screens/tutup_kasir_form_screen.dart';
import 'screens/stokin_form_screen.dart';
import 'screens/stokstjin_form_screen.dart';
import 'screens/uangmuka_form_screen.dart';
import 'screens/return_form_screen.dart';
import 'screens/jurnal_form_screen.dart';
import 'services/session_manager.dart';
import 'services/universal_printer_service.dart';
import 'services/receipt_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [],
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  ));

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [],
  );

  await initializeDateFormatting('id_ID', null);
  await _requestPermissions();

  runApp(const MyApp());
}

Future<void> _requestPermissions() async {
  try {
    await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
      Permission.storage,
    ].request();
  } catch (e) {
    print('Permission error: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RotiQ',
      debugShowCheckedModeBanner: false,

      initialRoute: AppRoutes.login,

      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: GoogleFonts.montserrat().fontFamily,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: Colors.black87, size: 20),
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarBrightness: Brightness.dark,
            statusBarIconBrightness: Brightness.dark,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF6A918),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          surfaceTintColor: Colors.transparent,
        ),
        dialogTheme: DialogTheme(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      routes: AppRoutes.routes,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case AppRoutes.setengahJadiForm:
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => SetengahJadiFormScreen(
                setengahJadi: args?['setengahJadi'],
                onSetengahJadiSaved: args?['onSaved'],
              ),
            );

          case AppRoutes.itemForm:
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => ItemFormScreen(
                categories: args?['categories'] ?? [],
                item: args?['item'],
                onItemSaved: args?['onSaved'],
              ),
            );

          case AppRoutes.categoryForm:
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => CategoryFormScreen(
                category: args?['category'],
                onCategorySaved: args?['onSaved'],
              ),
            );

          case AppRoutes.discountForm:
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => DiscountFormScreen(
                discount: args?['discount'],
                onDiscountSaved: args?['onSaved'],
              ),
            );

          case AppRoutes.tutupKasirForm:
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => TutupKasirFormScreen(
                onTutupKasirSuccess: args?['onSaved'] ?? () {},
              ),
            );

          case AppRoutes.stockInForm:
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => StokinFormScreen(
                stokinHeader: args?['stokinHeader'],
                onStokinSaved: args?['onSaved'],
              ),
            );

          case AppRoutes.penerimaanSetengahJadiForm:
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => StokStjinFormScreen(
                stokStjinHeader: args?['stokStjinHeader'],
                onStokStjinSaved: args?['onSaved'],
              ),
            );

          case AppRoutes.uangMukaForm:
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => UangMukaFormScreen(
                uangMuka: args?['uangMuka'],
                onUangMukaSaved: args?['onSaved'],
              ),
            );

          case AppRoutes.returnProductionForm:
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => ReturnFormScreen(
                returnHeader: args?['returnHeader'],
                onReturnSaved: args?['onSaved'],
              ),
            );

          case AppRoutes.biayaLainForm:
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => JurnalFormScreen(
                jurnalHeader: args?['jurnalHeader'],
                onJurnalSaved: args?['onSaved'],
              ),
            );

          default:
            return null;
        }
      },
    );
  }
}