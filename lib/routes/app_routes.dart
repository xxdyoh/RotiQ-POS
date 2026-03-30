import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import '../screens/dashboard_screen.dart';
import '../screens/login_screen.dart';
import '../screens/setengahjadi_list_screen.dart';
import '../screens/item_list_screen.dart';
import '../screens/category_list_screen.dart';
import '../screens/discount_list_screen.dart';
import '../screens/home_screen.dart';
import '../screens/tutup_kasir_form_screen.dart';
import '../screens/stokin_list_screen.dart';
import '../screens/stokstjin_list_screen.dart';
import '../screens/uangmuka_list_screen.dart';
import '../screens/return_list_screen.dart';
import '../screens/jurnal_list_screen.dart';
import '../screens/sales_by_item_screen.dart';
import '../screens/sales_by_invoice_screen.dart';
import '../screens/sales_order_screen.dart';
import '../screens/return_produksi_screen.dart';
import '../screens/void_items_screen.dart';
import '../screens/setoran_screen.dart';
import '../screens/stock_report_screen.dart';
import '../screens/setengahjadi_stock_report_screen.dart';
import '../screens/printer_settings_screen.dart';
import '../screens/printer_config_screen.dart';
import '../screens/pos_screen.dart';
import '../screens/minta_list_screen.dart';
import '../screens/minta_form_screen.dart';
import '../screens/minta_report_screen.dart';
import '../screens/serah_terima_list_screen.dart';
import '../screens/spk_list_screen.dart';
import '../screens/do_form_screen.dart';
import '../screens/do_list_screen.dart';
import '../screens/user_permission_screen.dart';
import '../screens/koreksi_list_screen.dart';

class AppRoutes {
  static const String dashboard = '/dashboard';
  static const String login = '/';

  static const String setengahJadiList = '/setengah-jadi';
  static const String itemList = '/items';
  static const String categoryList = '/categories';
  static const String discountList = '/discounts';

  static const String pos = '/pos';
  static const String tutupKasir = '/tutup-kasir';
  static const String stockInList = '/stock-in';
  static const String penerimaanSetengahJadi = '/penerimaan-setengah-jadi';
  static const String uangMukaList = '/uang-muka';
  static const String returnProduction = '/return-production';
  static const String biayaLain = '/biaya-lain';

  static const String salesByItem = '/reports/sales-by-item';
  static const String salesByInvoice = '/reports/sales-by-invoice';
  static const String salesOrderList = '/reports/sales-order';
  static const String returnProductionList = '/reports/return-production-list';
  static const String voidList = '/reports/void';
  static const String setoran = '/reports/setoran';
  static const String lapStock = '/reports/lap-stock';
  static const String stockSetengahJadi = '/reports/stock-setengah-jadi';

  static const String mintaList = '/minta-list';
  static const String mintaForm = '/minta-form';

  static const String connectPrinter = '/utility/connect-printer';
  static const String settingPrinter = '/utility/setting-printer';

  static const String setengahJadiForm = '/setengah-jadi/form';
  static const String itemForm = '/items/form';
  static const String categoryForm = '/categories/form';
  static const String discountForm = '/discounts/form';
  static const String tutupKasirForm = '/tutup-kasir/form';
  static const String stockInForm = '/stock-in/form';
  static const String penerimaanSetengahJadiForm = '/penerimaan-setengah-jadi/form';
  static const String uangMukaForm = '/uang-muka/form';
  static const String returnProductionForm = '/return-production/form';
  static const String biayaLainForm = '/biaya-lain/form';
  static const String mintaReport = '/minta-report';

  static const String serahTerimaList = '/serah-terima';
  static const String serahTerimaForm = '/serah-terima/form';

  static const String doList = '/do';
  static const String doForm = '/do/form';

  static const String spkList = '/spk';

  static const String userPermissions = '/user-permissions';

  static const String koreksiList = '/koreksi';
  static const String koreksiForm = '/koreksi-form';

  static Map<String, WidgetBuilder> get routes {
    return {
      dashboard: (context) => DashboardScreen(),
      login: (context) => LoginScreen(),

      setengahJadiList: (context) => SetengahJadiListScreen(),
      itemList: (context) => ItemListScreen(),
      categoryList: (context) => CategoryListScreen(),
      discountList: (context) => DiscountListScreen(),

      pos: (context) => POSScreen(),
      tutupKasir: (context) => TutupKasirFormScreen(onTutupKasirSuccess: () {}),
      stockInList: (context) => StokinListScreen(),
      penerimaanSetengahJadi: (context) => StokStjinListScreen(),
      uangMukaList: (context) => UangMukaListScreen(),
      returnProduction: (context) => ReturnListScreen(),
      biayaLain: (context) => JurnalListScreen(),
      mintaList: (context) => const MintaListScreen(),
      mintaForm: (context) => MintaFormScreen(
        onMintaSaved: () {},
      ),

      doList: (context) => DoListScreen(),
      doForm: (context) => DoFormScreen(
        onDoSaved: () {},
      ),

      spkList: (context) => SpkListScreen(),

      salesByItem: (context) => SalesByItemScreen(),
      salesByInvoice: (context) => SalesByInvoiceScreen(),
      salesOrderList: (context) => SalesOrderScreen(),
      returnProductionList: (context) => ReturnProduksiScreen(),
      voidList: (context) => VoidItemsScreen(),
      setoran: (context) => SalesDepositScreen(),
      lapStock: (context) => StockReportScreen(),
      stockSetengahJadi: (context) => SetengahJadiStockReportScreen(),
      mintaReport: (context) => MintaReportScreen(),

      serahTerimaList: (context) => SerahTerimaListScreen(),

      connectPrinter: (context) => PrinterSettingsScreen(),
      settingPrinter: (context) => PrinterConfigScreen(),
      userPermissions: (context) => UserPermissionScreen(),

      koreksiList: (context) => KoreksiListScreen(),
    };
  }

  static bool isMainScreen(String routeName) {
    final mainScreens = [
      dashboard,
      setengahJadiList,
      itemList,
      categoryList,
      discountList,
      salesByItem,
      salesByInvoice,
    ];
    return mainScreens.contains(routeName);
  }

  static bool isFormScreen(String routeName) {
    final formScreens = [
      setengahJadiForm,
      itemForm,
      categoryForm,
      discountForm,
      tutupKasirForm,
      stockInForm,
      penerimaanSetengahJadiForm,
      uangMukaForm,
      returnProductionForm,
      biayaLainForm
    ];
    return formScreens.contains(routeName);
  }
}