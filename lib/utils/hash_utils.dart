import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Utilities for hashing and secure random generation.
class HashUtils {
  /// Hashes a password with the provided salt using SHA-256.
  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    return sha256.convert(bytes).toString();
  }

  /// Generates a cryptographically secure random base64url salt.
  static String generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(values);
  }

  /// Generates numeric OTP code of specified length.
  static String generateNumericOtp([int length = 6]) {
    final random = Random.secure();
    return List.generate(length, (_) => random.nextInt(10)).join();
  }

  /// Generates random hex token.
  static String generateRandomToken([int byteLength = 24]) {
    final random = Random.secure();
    final values = List<int>.generate(byteLength, (_) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
