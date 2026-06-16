import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  /// Uploads a file (image receipt) from local storage or memory to Cloudinary.
  /// Returns the secure URL of the uploaded image if successful, otherwise null.
  Future<String?> uploadReceipt(XFile file) async {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'];

    if (cloudName == null ||
        cloudName.trim().isEmpty ||
        uploadPreset == null ||
        uploadPreset.trim().isEmpty) {
      debugPrint('Cloudinary upload skipped: missing upload configuration.');
      return null;
    }

    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    
    try {
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset;

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: file.name,
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', file.path));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['secure_url'] as String?;
      } else {
        debugPrint('Cloudinary upload failed with status: ${response.statusCode}');
        debugPrint('Body: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Exception during Cloudinary upload: $e');
      return null;
    }
  }
}
