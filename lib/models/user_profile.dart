import 'package:hive/hive.dart';

// This pragma is necessary to avoid warnings
part 'user_profile.g.dart';

@HiveType(typeId: 0)
class UserProfile extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String email;

  @HiveField(2)
  String gender;

  @HiveField(3)
  String contactNumber;

  @HiveField(4)
  List<double> faceEmbedding;

  UserProfile({
    required this.name,
    required this.email,
    required this.gender,
    required this.contactNumber,
    required this.faceEmbedding,
  });
}
