// Dart models mirroring the EthioPromo backend entities & enums.
// Field names match the Java JSON exactly so Dio responses parse directly.

/// Account platform type — mirrors backend AccountTypeEnum.
/// Built-in platforms retain their wire codes; admins can add more platforms.
class AccountType {
  static const telegram = AccountType('TELEGRAM', 'Telegram');
  static const youtube = AccountType('YOUTUBE', 'YouTube');
  static const tiktok = AccountType('TIKTOK', 'TikTok');
  static const facebook = AccountType('FACEBOOK', 'Facebook');
  static const instagram = AccountType('INSTAGRAM', 'Instagram');
  static const values = [telegram, youtube, tiktok, facebook, instagram];

  const AccountType(this.wire, this.label);
  final String wire; // exact enum name sent/received
  final String label; // human label

  static AccountType? fromWire(String? v) {
    if (v == null) return null;
    for (final t in AccountType.values) {
      if (t.wire == v) return t;
    }
    return AccountType(v, v.replaceAll('_', ' '));
  }

  factory AccountType.fromJson(Map<String, dynamic> j) =>
      AccountType(j['code'] as String, j['name'] as String);

  @override
  bool operator ==(Object other) => other is AccountType && other.wire == wire;

  @override
  int get hashCode => wire.hashCode;
}

/// Mirrors backend PriceTypeEnum.
enum PriceType {
  perClick('PER_CLICK', 'Per click'),
  perView('PER_VIEW', 'Per view'),
  perDay('PER_DAY', 'Per day');

  const PriceType(this.wire, this.label);
  final String wire;
  final String label;

  static PriceType? fromWire(String? v) {
    if (v == null) return null;
    for (final t in PriceType.values) {
      if (t.wire == v) return t;
    }
    return null;
  }
}

/// Mirrors backend PromotionRequestStatus (full lifecycle).
enum PromotionStatus {
  requested('REQUESTED', 'Requested'),
  adminApproved('ADMIN_APPROVED', 'Admin approved'),
  adminRejected('ADMIN_REJECTED', 'Admin rejected'),
  ownerApproved('ACCOUNT_OWNER_APPROVED', 'Owner approved'),
  ownerRejected('ACCOUNT_OWNER_REJECTED', 'Owner rejected'),
  businessCanceled('BUSINESS_OWNER_CANCELED', 'Canceled'),
  running('RUNNING', 'Running'),
  fulfilled('FULFILLED', 'Fulfilled');

  const PromotionStatus(this.wire, this.label);
  final String wire;
  final String label;

  static PromotionStatus? fromWire(String? v) {
    if (v == null) return null;
    for (final s in PromotionStatus.values) {
      if (s.wire == v) return s;
    }
    return null;
  }
}

class UserAddress {
  final String? street;
  final String? city;

  UserAddress({this.street, this.city});

  factory UserAddress.fromJson(Map<String, dynamic> j) =>
      UserAddress(street: j['street'] as String?, city: j['city'] as String?);

  String get display =>
      [street, city].where((e) => (e ?? '').isNotEmpty).join(', ');
}

/// Mirrors backend UserProfileModel returned by GET /user.
class UserProfile {
  final String? userPublicId;
  final String? firstName;
  final String? lastName;
  final String? userName; // phone
  final String? email;
  final UserAddress? address;
  final List<String> roles;

  UserProfile({
    this.userPublicId,
    this.firstName,
    this.lastName,
    this.userName,
    this.email,
    this.address,
    this.roles = const [],
  });

  String get fullName =>
      [firstName, lastName].where((e) => (e ?? '').isNotEmpty).join(' ').trim();

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    userPublicId: j['userPublicId'] as String?,
    firstName: j['firstName'] as String?,
    lastName: j['lastName'] as String?,
    userName: j['userName'] as String?,
    email: j['email'] as String?,
    address: j['address'] is Map<String, dynamic>
        ? UserAddress.fromJson(j['address'] as Map<String, dynamic>)
        : null,
    roles: (j['roles'] as List?)?.map((e) => e.toString()).toList() ?? const [],
  );
}

/// Admin-facing user summary (from GET /admin/user-list).
class AdminUser {
  final String? userPublicId;
  final String? firstName;
  final String? lastName;
  final String? userName; // phone
  final String? email;
  final List<String> roles;
  final bool enabled;
  final bool locked;

  AdminUser({
    this.userPublicId,
    this.firstName,
    this.lastName,
    this.userName,
    this.email,
    this.roles = const [],
    this.enabled = true,
    this.locked = false,
  });

  String get fullName =>
      [firstName, lastName].where((e) => (e ?? '').isNotEmpty).join(' ').trim();

  bool get isCandidate => roles.contains('CANDIDATE');
  bool get isInfluencer => roles.contains('INFLUENCER');
  bool get isAdmin => roles.contains('ADMIN');

  factory AdminUser.fromJson(Map<String, dynamic> j) {
    final rawRoles = j['roles'];
    final roles = <String>[];
    if (rawRoles is List) {
      for (final r in rawRoles) {
        if (r is Map && r['name'] != null) {
          roles.add(r['name'].toString());
        } else if (r != null) {
          roles.add(r.toString());
        }
      }
    }
    return AdminUser(
      userPublicId: j['userPublicId'] as String?,
      firstName: j['firstName'] as String?,
      lastName: j['lastName'] as String?,
      userName: j['userName'] as String?,
      email: j['email'] as String?,
      roles: roles,
      enabled: j['enabled'] as bool? ?? j['isEnabled'] as bool? ?? true,
      locked: j['locked'] as bool? ?? j['isLocked'] as bool? ?? false,
    );
  }
}

class AccountCategory {
  final int? id;
  final String? categoryName;
  final String? categoryImageUrl;
  final int? displayOrder;

  AccountCategory({
    this.id,
    this.categoryName,
    this.categoryImageUrl,
    this.displayOrder,
  });

  factory AccountCategory.fromJson(Map<String, dynamic> j) => AccountCategory(
    id: (j['id'] as num?)?.toInt(),
    categoryName: j['categoryName'] as String?,
    categoryImageUrl: j['categoryImageUrl'] as String?,
    displayOrder: (j['displayOrder'] as num?)?.toInt(),
  );

  // Value equality by id so dropdowns match across different instances
  // (e.g. a pre-filled category vs. one from the fetched list).
  @override
  bool operator ==(Object other) => other is AccountCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class PriceOptions {
  final int? id;
  final PriceType? priceType;
  final double cost;
  final String? remark;

  PriceOptions({this.id, this.priceType, this.cost = 0, this.remark});

  factory PriceOptions.fromJson(Map<String, dynamic> j) => PriceOptions(
    id: (j['id'] as num?)?.toInt(),
    priceType: PriceType.fromWire(j['priceType'] as String?),
    cost: (j['cost'] as num?)?.toDouble() ?? 0,
    remark: j['remark'] as String?,
  );

  Map<String, dynamic> toJson() => {
    if (priceType != null) 'priceType': priceType!.wire,
    'cost': cost,
    if (remark != null) 'remark': remark,
  };
}

class InfluencerAccount {
  final int? id;
  final String? accountPublicId;
  final String? title;
  final String? description;
  final String? accountURL;
  final String? imageURL;
  final AccountType? accountType;
  final int audienceCount;
  final int minViewPerPostCount;
  final int maxViewPerPostCount;
  final List<PriceOptions> priceOptions;
  final bool approved;
  final bool verified;
  final AccountCategory? category;

  InfluencerAccount({
    this.id,
    this.accountPublicId,
    this.title,
    this.description,
    this.accountURL,
    this.imageURL,
    this.accountType,
    this.audienceCount = 0,
    this.minViewPerPostCount = 0,
    this.maxViewPerPostCount = 0,
    this.priceOptions = const [],
    this.approved = false,
    this.verified = false,
    this.category,
  });

  double? get lowestCost {
    if (priceOptions.isEmpty) return null;
    return priceOptions.map((p) => p.cost).reduce((a, b) => a < b ? a : b);
  }

  /// Body for the update endpoint (keeps accountPublicId + id so the
  /// backend can locate the record).
  Map<String, dynamic> toUpdateJson() => {
    if (id != null) 'id': id,
    if (accountPublicId != null) 'accountPublicId': accountPublicId,
    'title': title,
    'description': description,
    'accountURL': accountURL,
    if (imageURL != null) 'imageURL': imageURL,
    if (accountType != null) 'accountType': accountType!.wire,
    'audienceCount': audienceCount,
    'minViewPerPostCount': minViewPerPostCount,
    'maxViewPerPostCount': maxViewPerPostCount,
    'priceOptions': priceOptions.map((p) => p.toJson()).toList(),
  };

  factory InfluencerAccount.fromJson(Map<String, dynamic> j) =>
      InfluencerAccount(
        id: (j['id'] as num?)?.toInt(),
        accountPublicId: j['accountPublicId'] as String?,
        title: j['title'] as String?,
        description: j['description'] as String?,
        accountURL: j['accountURL'] as String?,
        imageURL: j['imageURL'] as String?,
        accountType: j['platform'] is Map<String, dynamic>
            ? AccountType.fromJson(j['platform'] as Map<String, dynamic>)
            : AccountType.fromWire(j['accountType'] as String?),
        audienceCount: (j['audienceCount'] as num?)?.toInt() ?? 0,
        minViewPerPostCount: (j['minViewPerPostCount'] as num?)?.toInt() ?? 0,
        maxViewPerPostCount: (j['maxViewPerPostCount'] as num?)?.toInt() ?? 0,
        priceOptions: ((j['priceOptions'] as List?) ?? const [])
            .map((e) => PriceOptions.fromJson(e as Map<String, dynamic>))
            .toList(),
        approved: j['approved'] as bool? ?? false,
        verified: j['verified'] as bool? ?? false,
        category: j['category'] is Map<String, dynamic>
            ? AccountCategory.fromJson(j['category'] as Map<String, dynamic>)
            : null,
      );
}

class PromotionRequest {
  final int? id;
  final String? promotionRequestPublicId;
  final InfluencerAccount? influencerAccount;
  final List<DateTime> dateList;
  final String? promotionText;
  final String? promoImageURL;
  final String? feedback;
  final PromotionStatus? status;

  PromotionRequest({
    this.id,
    this.promotionRequestPublicId,
    this.influencerAccount,
    this.dateList = const [],
    this.promotionText,
    this.promoImageURL,
    this.feedback,
    this.status,
  });

  factory PromotionRequest.fromJson(Map<String, dynamic> j) => PromotionRequest(
    id: (j['id'] as num?)?.toInt(),
    promotionRequestPublicId: j['promotionRequestPublicId'] as String?,
    influencerAccount: j['influencerAccount'] is Map<String, dynamic>
        ? InfluencerAccount.fromJson(
            j['influencerAccount'] as Map<String, dynamic>,
          )
        : null,
    dateList: ((j['dateList'] as List?) ?? const [])
        .map((e) => DateTime.tryParse(e.toString()))
        .whereType<DateTime>()
        .toList(),
    promotionText: j['promotionText'] as String?,
    promoImageURL: j['promoImageURL'] as String?,
    feedback: j['feedback'] as String?,
    status: PromotionStatus.fromWire(j['promotionRequestStatus'] as String?),
  );
}

/// Generic parser for Spring Data's `Page<T>` JSON shape.
/// Falls back to a plain List if the server returns an array.
class PageResult<T> {
  final List<T> content;
  final int totalElements;
  final int totalPages;
  final int number; // current page index
  final bool last;

  PageResult({
    required this.content,
    this.totalElements = 0,
    this.totalPages = 0,
    this.number = 0,
    this.last = true,
  });

  static PageResult<T> fromJson<T>(
    dynamic data,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    if (data is List) {
      final items = data
          .map((e) => itemFromJson(e as Map<String, dynamic>))
          .toList();
      return PageResult<T>(
        content: items,
        totalElements: items.length,
        totalPages: 1,
        last: true,
      );
    }
    final map = data as Map<String, dynamic>;
    final rawContent = (map['content'] as List?) ?? const [];
    return PageResult<T>(
      content: rawContent
          .map((e) => itemFromJson(e as Map<String, dynamic>))
          .toList(),
      totalElements: (map['totalElements'] as num?)?.toInt() ?? 0,
      totalPages: (map['totalPages'] as num?)?.toInt() ?? 0,
      number: (map['number'] as num?)?.toInt() ?? 0,
      last: map['last'] as bool? ?? true,
    );
  }
}
