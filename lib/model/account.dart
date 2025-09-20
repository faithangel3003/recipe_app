class Account {
  final String userId; // Firebase Auth uid
  final String name; // username / display name
  final String email;
  final String profileImg; // profile picture URL
  final List<String> posts; // recipeIds created by this user
  final List<String> likedPosts; // recipeIds liked by this user
  final int followers;
  final int following;

  Account({
    required this.userId,
    required this.name,
    required this.email,
    required this.profileImg,
    required this.posts,
    required this.likedPosts,
    required this.followers,
    required this.following,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'profileImg': profileImg,
      'posts': posts,
      'likedPosts': likedPosts,
      'followers': followers,
      'following': following,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      profileImg: map['profileImg'] ?? '',
      posts: List<String>.from(map['posts'] ?? []),
      likedPosts: List<String>.from(map['likedPosts'] ?? []),
      followers: map['followers'] ?? 0,
      following: map['following'] ?? 0,
    );
  }
}
