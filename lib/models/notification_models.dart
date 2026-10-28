class InboxNotification {
  const InboxNotification({
    required this.id,
    required this.type,
    required this.category,
    required this.title,
    required this.body,
    required this.resourceType,
    this.resourceId,
    required this.createdAt,
    this.readAt,
    this.archivedAt,
  });
  final int id;
  final String type, category, title, body, resourceType;
  final String? resourceId;
  final DateTime createdAt;
  final DateTime? readAt, archivedAt;
  bool get unread => readAt == null;
  bool get archived => archivedAt != null;
  factory InboxNotification.fromJson(Map<String, dynamic> j) =>
      InboxNotification(
        id: (j['id'] as num).toInt(),
        type: j['type'] as String,
        category: j['category'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        resourceType: j['resourceType'] as String,
        resourceId: j['resourceId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        readAt: DateTime.tryParse(j['readAt']?.toString() ?? ''),
        archivedAt: DateTime.tryParse(j['archivedAt']?.toString() ?? ''),
      );
}

class NotificationSettings {
  const NotificationSettings({
    this.liveAlerts = true,
    this.promotionAlerts = true,
    this.channelAlerts = true,
    this.accountAlerts = true,
  });
  final bool liveAlerts, promotionAlerts, channelAlerts, accountAlerts;
  bool allows(String category) =>
      liveAlerts &&
      switch (category) {
        'PROMOTIONS' => promotionAlerts,
        'CHANNELS' => channelAlerts,
        'ACCOUNT' => accountAlerts,
        _ => false,
      };
  factory NotificationSettings.fromJson(Map<String, dynamic> j) =>
      NotificationSettings(
        liveAlerts: j['liveAlerts'] as bool? ?? true,
        promotionAlerts: j['promotionAlerts'] as bool? ?? true,
        channelAlerts: j['channelAlerts'] as bool? ?? true,
        accountAlerts: j['accountAlerts'] as bool? ?? true,
      );
  Map<String, dynamic> toJson() => {
    'liveAlerts': liveAlerts,
    'promotionAlerts': promotionAlerts,
    'channelAlerts': channelAlerts,
    'accountAlerts': accountAlerts,
  };
  NotificationSettings copyWith({
    bool? liveAlerts,
    bool? promotionAlerts,
    bool? channelAlerts,
    bool? accountAlerts,
  }) => NotificationSettings(
    liveAlerts: liveAlerts ?? this.liveAlerts,
    promotionAlerts: promotionAlerts ?? this.promotionAlerts,
    channelAlerts: channelAlerts ?? this.channelAlerts,
    accountAlerts: accountAlerts ?? this.accountAlerts,
  );
}

/// Maps server resource types to known routes; never execute a server-supplied URL.
String? notificationRoute(
  InboxNotification n, {
  required bool isAdmin,
  required bool isInfluencer,
}) {
  if (isAdmin) {
    return switch (n.resourceType) {
      'ADMIN_PROMOTIONS' => '/admin/promotions',
      'ADMIN_CHANNELS' => '/admin/channels',
      'ADMIN_USERS' => '/admin/users',
      _ => '/admin',
    };
  }
  final id = n.resourceId;
  return switch (n.resourceType) {
    'CHANNEL' when id != null && isInfluencer =>
      '/channel/${Uri.encodeComponent(id)}',
    'MY_CHANNELS' when isInfluencer => '/browse',
    'CREATOR_REQUEST' when isInfluencer && id != null =>
      '/promotion/${Uri.encodeComponent(id)}?incoming=1',
    'PROMOTION' when id != null => '/promotion/${Uri.encodeComponent(id)}',
    'PROMOTION' => '/sent-promotions',
    'PROFILE' => '/profile',
    _ => null,
  };
}
