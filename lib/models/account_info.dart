class AccountInfo {
  final String? status;
  final bool isTrial;
  final String? activeConnections;
  final String? maxConnections;
  final DateTime? expiresAt;

  const AccountInfo({
    this.status,
    required this.isTrial,
    this.activeConnections,
    this.maxConnections,
    this.expiresAt,
  });

  factory AccountInfo.fromJson(Map<String, dynamic> json) {
    DateTime? expiresAt;
    final expDateRaw = json['exp_date'];
    if (expDateRaw != null) {
      final seconds = int.tryParse(expDateRaw.toString());
      if (seconds != null) {
        expiresAt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    }

    return AccountInfo(
      status: json['status'] as String?,
      isTrial: json['is_trial']?.toString() == '1',
      activeConnections: json['active_cons']?.toString(),
      maxConnections: json['max_connections']?.toString(),
      expiresAt: expiresAt,
    );
  }
}
