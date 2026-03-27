class DashboardSalesData {
  final String label;
  final double totalSales;

  DashboardSalesData({
    required this.label,
    required this.totalSales,
  });

  factory DashboardSalesData.fromJson(Map<String, dynamic> json) {
    return DashboardSalesData(
      label: json['label'] ?? '',
      totalSales: _toDouble(json['total_sales']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class DashboardCategoryData {
  final String category;
  final double totalAmount;

  DashboardCategoryData({
    required this.category,
    required this.totalAmount,
  });

  factory DashboardCategoryData.fromJson(Map<String, dynamic> json) {
    return DashboardCategoryData(
      category: json['category'] ?? 'Unknown',
      totalAmount: _toDouble(json['total_amount']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class DashboardKasirData {
  final String kasir;
  final double totalAmount;

  DashboardKasirData({
    required this.kasir,
    required this.totalAmount,
  });

  factory DashboardKasirData.fromJson(Map<String, dynamic> json) {
    return DashboardKasirData(
      kasir: json['kasir'] ?? 'Unknown',
      totalAmount: _toDouble(json['total_amount']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class DashboardTopItem {
  final String itemName;
  final String category;
  final int totalQty;
  final double totalAmount;

  DashboardTopItem({
    required this.itemName,
    required this.category,
    required this.totalQty,
    required this.totalAmount,
  });

  factory DashboardTopItem.fromJson(Map<String, dynamic> json) {
    return DashboardTopItem(
      itemName: json['item_name'] ?? 'Unknown',
      category: json['category'] ?? '',
      totalQty: _toInt(json['total_qty']),
      totalAmount: _toDouble(json['total_amount']),
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class MultiSeriesSalesData {
  final List<String> dates;
  final List<Map<String, dynamic>> series;

  MultiSeriesSalesData({
    required this.dates,
    required this.series,
  });

  factory MultiSeriesSalesData.fromJson(Map<String, dynamic> json) {
    return MultiSeriesSalesData(
      dates: List<String>.from(json['dates'] ?? []),
      series: List<Map<String, dynamic>>.from(json['series'] ?? []),
    );
  }
}

class DashboardResponse {
  List<DashboardSalesData> sales;
  MultiSeriesSalesData? multiSeriesSales;
  List<DashboardCategoryData> categories;
  List<DashboardKasirData> kasir;
  List<DashboardTopItem> topItems;
  final bool isAllCabang;
  final String groupBy;
  final List<Map<String, dynamic>> cabangList;

  DashboardResponse({
    required this.sales,
    this.multiSeriesSales,
    required this.categories,
    required this.kasir,
    required this.topItems,
    required this.isAllCabang,
    required this.groupBy,
    required this.cabangList,
  });

  factory DashboardResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return DashboardResponse(
      sales: (data['sales'] as List?)?.map((e) => DashboardSalesData.fromJson(e)).toList() ?? [],
      multiSeriesSales: data['multi_series_sales'] != null
          ? MultiSeriesSalesData.fromJson(data['multi_series_sales'])
          : null,
      categories: (data['categories'] as List?)?.map((e) => DashboardCategoryData.fromJson(e)).toList() ?? [],
      kasir: (data['kasir'] as List?)?.map((e) => DashboardKasirData.fromJson(e)).toList() ?? [],
      topItems: (data['top_items'] as List?)?.map((e) => DashboardTopItem.fromJson(e)).toList() ?? [],
      isAllCabang: data['is_all_cabang'] ?? false,
      groupBy: data['group_by'] ?? 'day',
      cabangList: (data['cabang_list'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [],
    );
  }
}