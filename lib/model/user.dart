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
    uid: (json["uid"] as String?) ?? '',
    username: (json["username"] as String?) ?? '',
    email: (json["email"] as String?) ?? '',
    profileImageUrl: (json["profileImageUrl"] as String?) ?? '',
    posts: (json["posts"] is List)
        ? List<String>.from((json["posts"] as List).map((e) => e.toString()))
        : <String>[],
    likedPosts: (json["likedPosts"] is List)
        ? List<String>.from(
            (json["likedPosts"] as List).map((e) => e.toString()),
          )
        : <String>[],
    followers: (json["followers"] is List)
        ? List<String>.from(
            (json["followers"] as List).map((e) => e.toString()),
          )
        : <String>[],
    following: (json["following"] is List)
        ? List<String>.from(
            (json["following"] as List).map((e) => e.toString()),
          )
        : <String>[],
    isAdmin: json["isAdmin"] ?? false,
  );
}
