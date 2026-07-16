class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
    this.plan = 'free',
    this.isGuest = false,
  });

  final String id;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final String plan; // 'free' | 'pro' | 'enterprise'
  final bool isGuest;

  bool get isPro => plan == 'pro' || plan == 'enterprise';

  String get displayName {
    if (fullName != null && fullName!.isNotEmpty) return fullName!;
    if (isGuest) return 'Guest';
    return email.split('@').first;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'fullName': fullName,
        'avatarUrl': avatarUrl,
        'plan': plan,
        'isGuest': isGuest,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['fullName'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        plan: (json['plan'] as String?) ?? 'free',
        isGuest: (json['isGuest'] as bool?) ?? false,
      );

  AppUser copyWith({String? fullName, String? avatarUrl, String? plan}) =>
      AppUser(
        id: id,
        email: email,
        fullName: fullName ?? this.fullName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        plan: plan ?? this.plan,
        isGuest: isGuest,
      );
}
