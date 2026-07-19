/// Extended identity fields for the Profile page (beyond [AppUser]).
class ProfileDetails {
  const ProfileDetails({
    this.username = '',
    this.displayName = '',
    this.bio = '',
    this.country = '',
    this.language = '',
    this.timezone = '',
    this.birthday = '',
    this.gender = '',
    this.website = '',
    this.occupation = '',
    this.company = '',
    this.location = '',
    this.github = '',
    this.linkedin = '',
    this.twitter = '',
    this.instagram = '',
    this.facebook = '',
    this.portfolio = '',
    this.coverUrl,
    this.avatarUrl,
  });

  final String username;
  final String displayName;
  final String bio;
  final String country;
  final String language;
  final String timezone;
  final String birthday;
  final String gender;
  final String website;
  final String occupation;
  final String company;
  final String location;
  final String github;
  final String linkedin;
  final String twitter;
  final String instagram;
  final String facebook;
  final String portfolio;
  final String? coverUrl;
  final String? avatarUrl;

  bool get hasBio => bio.trim().isNotEmpty;
  bool get hasWebsite => website.trim().isNotEmpty;
  bool get hasSocial =>
      github.isNotEmpty ||
      linkedin.isNotEmpty ||
      twitter.isNotEmpty ||
      instagram.isNotEmpty ||
      facebook.isNotEmpty ||
      portfolio.isNotEmpty;

  ProfileDetails copyWith({
    String? username,
    String? displayName,
    String? bio,
    String? country,
    String? language,
    String? timezone,
    String? birthday,
    String? gender,
    String? website,
    String? occupation,
    String? company,
    String? location,
    String? github,
    String? linkedin,
    String? twitter,
    String? instagram,
    String? facebook,
    String? portfolio,
    String? coverUrl,
    String? avatarUrl,
    bool clearCover = false,
    bool clearAvatar = false,
  }) {
    return ProfileDetails(
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      country: country ?? this.country,
      language: language ?? this.language,
      timezone: timezone ?? this.timezone,
      birthday: birthday ?? this.birthday,
      gender: gender ?? this.gender,
      website: website ?? this.website,
      occupation: occupation ?? this.occupation,
      company: company ?? this.company,
      location: location ?? this.location,
      github: github ?? this.github,
      linkedin: linkedin ?? this.linkedin,
      twitter: twitter ?? this.twitter,
      instagram: instagram ?? this.instagram,
      facebook: facebook ?? this.facebook,
      portfolio: portfolio ?? this.portfolio,
      coverUrl: clearCover ? null : (coverUrl ?? this.coverUrl),
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
    );
  }

  Map<String, dynamic> toJson() => {
        'username': username,
        'displayName': displayName,
        'bio': bio,
        'country': country,
        'language': language,
        'timezone': timezone,
        'birthday': birthday,
        'gender': gender,
        'website': website,
        'occupation': occupation,
        'company': company,
        'location': location,
        'github': github,
        'linkedin': linkedin,
        'twitter': twitter,
        'instagram': instagram,
        'facebook': facebook,
        'portfolio': portfolio,
        'coverUrl': coverUrl,
        'avatarUrl': avatarUrl,
      };

  factory ProfileDetails.fromJson(Map<String, dynamic> json) => ProfileDetails(
        username: (json['username'] as String?) ?? '',
        displayName: (json['displayName'] as String?) ?? '',
        bio: (json['bio'] as String?) ?? '',
        country: (json['country'] as String?) ?? '',
        language: (json['language'] as String?) ?? '',
        timezone: (json['timezone'] as String?) ?? '',
        birthday: (json['birthday'] as String?) ?? '',
        gender: (json['gender'] as String?) ?? '',
        website: (json['website'] as String?) ?? '',
        occupation: (json['occupation'] as String?) ?? '',
        company: (json['company'] as String?) ?? '',
        location: (json['location'] as String?) ?? '',
        github: (json['github'] as String?) ?? '',
        linkedin: (json['linkedin'] as String?) ?? '',
        twitter: (json['twitter'] as String?) ?? '',
        instagram: (json['instagram'] as String?) ?? '',
        facebook: (json['facebook'] as String?) ?? '',
        portfolio: (json['portfolio'] as String?) ?? '',
        coverUrl: json['coverUrl'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
      );

  static ProfileDetails empty() => const ProfileDetails();
}
