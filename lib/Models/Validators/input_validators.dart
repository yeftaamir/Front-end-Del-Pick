// lib/models/validators/input_validators.dart
class InputValidators {
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }

    const pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}';
    final regex = RegExp(pattern);

    if (!regex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }

    if (password.length < 6) {
      return 'Password must be at least 6 characters long';
    }

    return null;
  }

  static String? validateName(String? name) {
    if (name == null || name.isEmpty) {
      return 'Name is required';
    }

    if (name.length < 2) {
      return 'Name must be at least 2 characters long';
    }

    return null;
  }

  static String? validatePhone(String? phone) {
    if (phone == null || phone.isEmpty) {
      return 'Phone number is required';
    }

    // Indonesian phone number pattern
    const pattern = r'^(\+62|62|0)8[1-9][0-9]{6,9}';
    final regex = RegExp(pattern);

    if (!regex.hasMatch(phone)) {
      return 'Please enter a valid Indonesian phone number';
    }

    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validateRating(int? rating) {
    if (rating == null) {
      return 'Rating is required';
    }

    if (rating < 1 || rating > 5) {
      return 'Rating must be between 1 and 5';
    }

    return null;
  }

  static String? validateQuantity(int? quantity) {
    if (quantity == null || quantity <= 0) {
      return 'Quantity must be greater than 0';
    }

    return null;
  }
}