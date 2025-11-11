import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:liveness_app/models/user_profile.dart';

class DatabaseService {
  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  final Box<UserProfile> _userBox = Hive.box<UserProfile>('userBox');

  // --- Public Methods ---

  /// Saves a new user profile to the Hive database.
  Future<void> saveUser(UserProfile user) async {
    // Using email as a key for simplicity, assuming emails are unique
    await _userBox.put(user.email, user);
  }

  /// Retrieves all user profiles from the database.
  List<UserProfile> getAllUsers() {
    return _userBox.values.toList();
  }

  /// Compares a new face embedding to all saved users.
  /// Returns the matching UserProfile if found, otherwise null.
  UserProfile? findMatchingUser(List<double> newEmbedding) {
    final List<UserProfile> allUsers = getAllUsers();

    // This is the threshold for matching.
    // MobileFaceNet is often around 1.0. Lower is more strict.
    const double matchingThreshold = 1.0;

    UserProfile? bestMatch;
    double lowestDistance = double.infinity;

    for (final UserProfile user in allUsers) {
      double distance = calculateEuclideanDistance(
        user.faceEmbedding,
        newEmbedding,
      );

      if (distance < lowestDistance) {
        lowestDistance = distance;
        bestMatch = user;
      }
    }

    debugPrint('Lowest distance found: $lowestDistance');
    if (lowestDistance <= matchingThreshold) {
      return bestMatch;
    } else {
      return null;
    }
  }

  /// Calculates the squared Euclidean distance between two embeddings.
  double calculateEuclideanDistance(List<double> emb1, List<double> emb2) {
    if (emb1.length != emb2.length) {
      debugPrint("Error: Embeddings have different dimensions.");
      return double.infinity;
    }

    double distance = 0.0;
    for (int i = 0; i < emb1.length; i++) {
      distance += pow((emb1[i] - emb2[i]), 2);
    }
    // We can return the squared distance to save a `sqrt` operation,
    // as we are just comparing which one is smaller.
    // If you need the *actual* distance, return sqrt(distance).
    // For thresholding, comparing squared distances is fine and faster.
    return distance;
  }
}
