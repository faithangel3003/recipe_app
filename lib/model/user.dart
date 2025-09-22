class AppUser {
  final String uid;
  final String username;
  final String email;
  final String profileImageUrl;
  final List<String> posts; // recipe ids
  final List<String> likedPosts;

  AppUser({
    required this.uid,
    required this.username,
    required this.email,
    required this.profileImageUrl,
    required this.posts,
    required this.likedPosts,
  });

  Map<String, dynamic> toJson() => {
    "uid": uid,
    "username": username,
    "email": email,
    "profileImageUrl": profileImageUrl,
    "posts": posts,
    "likedPosts": likedPosts,
  };

  static AppUser fromJson(Map<String, dynamic> json) => AppUser(
    uid: json["uid"],
    username: json["username"],
    email: json["email"],
    profileImageUrl: json["profileImageUrl"],
    posts: List<String>.from(json["posts"] ?? []),
    likedPosts: List<String>.from(json["likedPosts"] ?? []),
  );
}
