class DashboardSalesData {
  final String label;
  final double totalSales;

  DashboardSalesData({
    required this.label,
    required this.totalSales,
  });

  factory DashboardSalesData.fromJson(Map<String, dynamic> json) {
    dynamic labelValue = json['label'] ?? '';
    String labelString;

    if (labelValue is int) {
      labelString = labelValue.toString();
    } else if (labelValue is double) {
      labelString = labelValue.toInt().toString();
    } else {
      labelString = labelValue.toString();
    }

    return DashboardSalesData(
      label: labelString,
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
    List<String> parsedDates = [];
    final rawDates = json['dates'] ?? [];

    for (var date in rawDates) {
      if (date is int) {
        parsedDates.add(date.toString());
      } else if (date is double) {
        parsedDates.add(date.toInt().toString());
      } else {
        parsedDates.add(date.toString());
      }
    }

    return MultiSeriesSalesData(
      dates: parsedDates,
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

// ============ MODEL PRODUKSI ============

class ProduksiChartData {
  final String tanggal;
  final double totalGram;

  ProduksiChartData({
    required this.tanggal,
    required this.totalGram,
  });

  factory ProduksiChartData.fromJson(Map<String, dynamic> json) {
    return ProduksiChartData(
      tanggal: json['tanggal']?.toString() ?? '',
      totalGram: _toDouble(json['total_gram']),
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

class ProduksiItemData {
  final String itemId;
  final String itemName;
  final double totalQty;
  final double totalGram;

  ProduksiItemData({
    required this.itemId,
    required this.itemName,
    required this.totalQty,
    required this.totalGram,
  });

  factory ProduksiItemData.fromJson(Map<String, dynamic> json) {
    return ProduksiItemData(
      itemId: json['item_id']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      totalQty: _toDouble(json['total_qty']),
      totalGram: _toDouble(json['total_gram']),
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

class ProduksiDivisiData {
  final String divisi;
  final double totalGram;

  ProduksiDivisiData({
    required this.divisi,
    required this.totalGram,
  });

  factory ProduksiDivisiData.fromJson(Map<String, dynamic> json) {
    return ProduksiDivisiData(
      divisi: json['divisi']?.toString() ?? 'Lainnya',
      totalGram: _toDouble(json['total_gram']),
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

class ProduksiResponse {
  final List<ProduksiChartData> chart;
  final List<ProduksiItemData> items;
  final List<ProduksiDivisiData> divisi;
  final double totalGram;
  final double averageGram;
  final int totalDays;

  ProduksiResponse({
    required this.chart,
    required this.items,
    required this.divisi,
    required this.totalGram,
    required this.averageGram,
    required this.totalDays,
  });

  factory ProduksiResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return ProduksiResponse(
      chart: (data['chart'] as List?)?.map((e) => ProduksiChartData.fromJson(e)).toList() ?? [],
      items: (data['items'] as List?)?.map((e) => ProduksiItemData.fromJson(e)).toList() ?? [],
      divisi: (data['divisi'] as List?)?.map((e) => ProduksiDivisiData.fromJson(e)).toList() ?? [],
      totalGram: (data['total_gram'] ?? 0).toDouble(),
      averageGram: (data['average_gram'] ?? 0).toDouble(),
      totalDays: (data['total_days'] ?? 0).toInt(),
    );
  }
}