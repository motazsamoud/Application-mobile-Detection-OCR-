class EditProfileModel {
  final String id;
  final String username;
  final String email;
  final String? dateOfBirth; // Nullable in case API doesn't return it
  final String? status;
  final String role;

  EditProfileModel({
    required this.id,
    required this.username,
    required this.email,
    this.dateOfBirth,
    this.status,
    required this.role,
  });

  factory EditProfileModel.fromJson(Map<String, dynamic> json) {
    return EditProfileModel(
      id: json['_id'] ?? "", // Fix for id mapping
      username: json['username'] ?? "Unknown", // Default value to avoid null issues
      email: json['email'] ?? "Unknown",
      dateOfBirth: json['dateOfBirth'], // Can be null
      status: json['status'], // Can be null
      role: json['role'] ?? "user",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "_id": id,
      "username": username,
      "email": email,
      "dateOfBirth": dateOfBirth,
      "status": status,
      "role": role,
    };
  }
}
