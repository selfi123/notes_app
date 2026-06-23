import 'package:hive/hive.dart';

part 'app_settings.g.dart';

@HiveType(typeId: 2)
class AppSettings extends HiveObject {
  @HiveField(0)
  bool isPremium;

  @HiveField(1)
  String? razorpaySubscriptionId;

  @HiveField(2)
  DateTime? premiumExpiresAt;

  @HiveField(3)
  bool cloudSyncEnabled;

  @HiveField(4)
  DateTime? lastSyncAt;

  @HiveField(5)
  bool useFolderLayout;

  AppSettings({
    this.isPremium = false,
    this.razorpaySubscriptionId,
    this.premiumExpiresAt,
    this.cloudSyncEnabled = false,
    this.lastSyncAt,
    this.useFolderLayout = false,
  });

  bool get isActivePremium {
    if (!isPremium) return false;
    if (premiumExpiresAt == null) return false;
    return premiumExpiresAt!.isAfter(DateTime.now());
  }
}
