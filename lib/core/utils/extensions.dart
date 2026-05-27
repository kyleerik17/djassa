import 'package:flutter/material.dart';

/// Extensions utilitaires pour Flutter
extension ContextExtensions on BuildContext {
  /// Navigation avec GoRouter
  void go(String path) {
    // À implémenter avec GoRouter
  }

  void pop() {
    Navigator.of(this).pop();
  }

  /// Affiche un SnackBar
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Affiche un dialog de confirmation
  Future<bool?> showConfirmDialog({
    required String title,
    required String message,
    String confirmText = 'Confirmer',
    String cancelText = 'Annuler',
  }) {
    return showDialog<bool>(
      context: this,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// Taille d'écran
  double get width => MediaQuery.of(this).size.width;
  double get height => MediaQuery.of(this).size.height;
}

/// Extensions sur String
extension StringExtensions on String {
  /// Capitalise la première lettre
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Vérifie si c'est un email valide
  bool get isValidEmail {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(this);
  }

  /// Vérifie si c'est un téléphone valide (format international)
  bool get isValidPhone {
    return RegExp(r'^\+?[1-9]\d{1,14}$')
        .hasMatch(replaceAll(RegExp(r'\D'), ''));
  }

  /// Formate le numéro de téléphone
  String formatPhoneNumber() {
    final digits = replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return this;

    // Formatage simple selon longueur
    if (digits.length == 10) {
      return '${digits.substring(0, 2)} ${digits.substring(2, 4)} ${digits.substring(4, 6)} ${digits.substring(6, 8)} ${digits.substring(8)}';
    }
    return this;
  }
}

/// Extensions sur DateTime
extension DateTimeExtensions on DateTime {
  /// Formate la date en français
  String toFrenchString() {
    const months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre'
    ];

    return '$day ${months[month - 1]} $year à $hour:${minute.toString().padLeft(2, '0')}';
  }

  /// Retourne "Il y a X temps"
  String timeAgo() {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inDays > 365) {
      return 'Il y a ${(difference.inDays / 365).floor()} an(s)';
    } else if (difference.inDays > 30) {
      return 'Il y a ${(difference.inDays / 30).floor()} mois';
    } else if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays} jour(s)';
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours} heure(s)';
    } else if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes} minute(s)';
    } else {
      return 'À l\'instant';
    }
  }
}

/// Extensions sur num pour formater les prix
extension NumExtensions on num {
  /// Formate en prix FCFA
  String toFCFA() {
    return '${toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    )} FCFA';
  }

  /// Formate avec séparateur de milliers
  String withThousandsSeparator() {
    return toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
  }
}
