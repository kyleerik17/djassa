class CourierAssignment {
  final String id;
  final String orderId;
  final int distanceMeters;
  final double score;
  final DateTime sentAt;

  CourierAssignment({
    required this.id,
    required this.orderId,
    required this.distanceMeters,
    required this.score,
    required this.sentAt,
  });

  factory CourierAssignment.fromJson(Map<String, dynamic> json) {
    return CourierAssignment(
      id: json['id'],
      orderId: json['order_id'],
      distanceMeters: json['distance_meters'] ?? 0,
      score: (json['score'] ?? 0.0).toDouble(),
      sentAt: DateTime.parse(json['sent_at']),
    );
  }
}