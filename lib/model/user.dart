class AppUser {
  final String uid;
  final String username;
  final String email;
  final String profileImageUrl;
  final List<String> posts;
  final List<String> likedPosts;
  final List<String> followers;
  final List<String> following;
  final bool isAdmin;

  AppUser({
    required this.uid,
    required this.username,
    required this.email,
    required this.profileImageUrl,
    required this.posts,
    required this.likedPosts,
    required this.followers,
    required this.following,
    this.isAdmin = false,
  });

  Map<String, dynamic> toJson() => {
    "uid": uid,
    "username": username,
    "email": email,
    "profileImageUrl": profileImageUrl,
    "posts": posts,
    "likedPosts": likedPosts,
    "followers": followers,
    "following": following,
    "isAdmin": isAdmin,
  };

  static AppUser fromJson(Map<String, dynamic> json) => AppUser(
    uid: json["uid"],
    username: json["username"],
    email: json["email"],
    profileImageUrl: json["profileImageUrl"],
    posts: List<String>.from(json["posts"] ?? []),
    likedPosts: List<String>.from(json["likedPosts"] ?? []),
    followers: List<String>.from(json["followers"] ?? []),
    following: List<String>.from(json["following"] ?? []),
    isAdmin: json["isAdmin"] ?? false,
  );
}
