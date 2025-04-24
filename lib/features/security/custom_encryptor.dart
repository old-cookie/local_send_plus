import 'package:encrypt_shared_preferences/provider.dart';

class CustomEncryptor implements IEncryptor {
  int _getShift(String key) {
    // Attempt to parse the key as an integer for the shift value.
    // Default to 3 if parsing fails.
    return int.tryParse(key) ?? 3;
  }

  String _caesarCipher(String text, int shift, bool encrypt) {
    StringBuffer result = StringBuffer();
    int actualShift = encrypt ? shift : -shift;

    for (int i = 0; i < text.length; i++) {
      int charCode = text.codeUnitAt(i);

      if (charCode >= 65 && charCode <= 90) { // Uppercase A-Z
        int base = 65;
        result.writeCharCode(((charCode - base + actualShift) % 26 + 26) % 26 + base);
      } else if (charCode >= 97 && charCode <= 122) { // Lowercase a-z
        int base = 97;
        result.writeCharCode(((charCode - base + actualShift) % 26 + 26) % 26 + base);
      } else {
        // Keep non-alphabetic characters unchanged
        result.writeCharCode(charCode);
      }
    }
    return result.toString();
  }

  @override
  String decrypt(String key, String encryptedData) {
    int shift = _getShift(key);
    return _caesarCipher(encryptedData, shift, false); // Decrypt
  }

  @override
  String encrypt(String key, String plainText) {
    int shift = _getShift(key);
    return _caesarCipher(plainText, shift, true); // Encrypt
  }
}
