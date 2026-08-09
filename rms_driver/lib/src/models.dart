int _int(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
double? _dbl(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

/// A branch/outlet of the restaurant tenant (from GET /restaurant/branches).
class BranchModel {
  BranchModel(this.id, this.name, this.code, this.isHeadOffice, this.configured);
  final String id;
  final String name;
  final String? code;
  final bool isHeadOffice;
  final bool configured;

  factory BranchModel.from(Map<String, dynamic> j) => BranchModel(
        j['id'] as String,
        j['name'] as String,
        j['code'] as String?,
        j['isHeadOffice'] == true,
        j['configured'] == true,
      );
}

class Delivery {
  Delivery({
    required this.id,
    required this.deliveryNo,
    required this.orderNo,
    required this.provider,
    required this.status,
    required this.address,
    required this.etaMinutes,
    required this.lat,
    required this.lng,
    required this.driver,
  });

  final String id;
  final String deliveryNo;
  final String orderNo;
  final String provider;
  final String status;
  final String? address;
  final int? etaMinutes;
  final double? lat;
  final double? lng;
  final String? driver;

  bool get isOwnFleet => provider == 'OWN';
  bool get isTerminal => const ['DELIVERED', 'FAILED', 'CANCELLED'].contains(status);
  bool get isActive => const ['PENDING', 'ASSIGNED', 'PICKED_UP', 'EN_ROUTE'].contains(status);
  bool get canTrack => const ['ASSIGNED', 'PICKED_UP', 'EN_ROUTE'].contains(status);
  bool get canComplete => const ['PICKED_UP', 'EN_ROUTE'].contains(status);

  factory Delivery.from(Map<String, dynamic> j) {
    final loc = j['location'] as Map<String, dynamic>?;
    return Delivery(
      id: j['id'] as String,
      deliveryNo: j['deliveryNo'] as String,
      orderNo: j['orderNo'] as String,
      provider: j['provider'] as String,
      status: j['status'] as String,
      address: j['address'] as String?,
      etaMinutes: j['etaMinutes'] == null ? null : _int(j['etaMinutes']),
      lat: _dbl(loc?['lat']),
      lng: _dbl(loc?['lng']),
      driver: j['driverEmployeeId'] as String?,
    );
  }
}
