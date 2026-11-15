// lib/core/utils/image_helper.dart
import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

/// Result of an image compression operation.
class CompressedImageResult {
  final String path;
  final Uint8List bytes;
  final int sizeInBytes;

  const CompressedImageResult({
    required this.path,
    required this.bytes,
    required this.sizeInBytes,
  });

  /// Size formatted in KB (e.g., 84 KB).
  int get sizeInKb => (sizeInBytes / 1024).round();
}

/// Helper service for picking and compressing menu item images to WebP < 150KB.
class ImageHelper {
  ImageHelper({
    ImagePicker? picker,
  }) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Target max size for WebP compression: 150 KB.
  static const int maxFileSizeBytes = 150 * 1024;

  /// Top-level or static isolate function for compressing image bytes to WebP < 150KB.
  static Uint8List compressImageBytesToWebP(Uint8List rawBytes) {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) {
      throw const FormatException('Selected file is not a valid or readable image.');
    }

    // Bake EXIF orientation so the image is properly oriented
    img.Image current = img.bakeOrientation(decoded);

    // Initial clamp to reasonable dimensions for food photos (max 1024px)
    const int initialMaxDim = 1024;
    if (current.width > initialMaxDim || current.height > initialMaxDim) {
      if (current.width >= current.height) {
        current = img.copyResize(current, width: initialMaxDim);
      } else {
        current = img.copyResize(current, height: initialMaxDim);
      }
    }

    // Try lossy WebP encoding starting at 80% quality
    int quality = 80;
    Uint8List webpBytes = img.encodeWebP(current, lossless: false, quality: quality);

    // Reduce quality iteratively if over 150 KB
    while (webpBytes.lengthInBytes > maxFileSizeBytes && quality > 25) {
      quality -= 15;
      webpBytes = img.encodeWebP(current, lossless: false, quality: quality);
    }

    // Downscale resolution iteratively if still over 150 KB
    while (webpBytes.lengthInBytes > maxFileSizeBytes && (current.width > 250 || current.height > 250)) {
      final nextWidth = (current.width * 0.75).round();
      current = img.copyResize(current, width: nextWidth);
      webpBytes = img.encodeWebP(current, lossless: false, quality: 65);
    }

    if (webpBytes.lengthInBytes > maxFileSizeBytes) {
      throw Exception('Image exceeds 150 KB limit and could not be compressed further.');
    }

    return webpBytes;
  }

  /// Check and request permission if needed. Returns true if permitted to proceed.
  static Future<bool> requestPermissionForSource(
    ImageSource source, {
    required BuildContext context,
  }) async {
    // Web and desktop platforms handle picker dialogs without runtime mobile permissions.
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return true;
    }

    if (source == ImageSource.camera) {
      try {
        final status = await Permission.camera.status;
        if (status.isGranted || status.isLimited) {
          return true;
        }

        final requestStatus = await Permission.camera.request();
        if (requestStatus.isGranted || requestStatus.isLimited) {
          return true;
        }

        if (context.mounted) {
          if (requestStatus.isPermanentlyDenied) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Camera permission is permanently denied. Please enable it in App Settings.'),
                action: SnackBarAction(
                  label: 'Settings',
                  onPressed: openAppSettings,
                ),
                backgroundColor: AppColors.errorRed,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Camera permission denied. Cannot take photo.'),
                backgroundColor: AppColors.errorRed,
              ),
            );
          }
        }
        return false;
      } catch (e) {
        // Fallback if permission_handler fails on a specific platform
        return true;
      }
    }

    // On modern Android (API 33+) & iOS, system photo pickers run out-of-process and do not require storage permissions.
    // However, on older Android devices (API <= 32), check storage permission gracefully.
    if (Platform.isAndroid) {
      try {
        final status = await Permission.photos.status;
        if (status.isGranted || status.isLimited) return true;

        final storageStatus = await Permission.storage.status;
        if (storageStatus.isGranted || storageStatus.isLimited) return true;

        // If neither is granted, image_picker will still attempt the system photo picker.
        return true;
      } catch (_) {
        return true;
      }
    }

    return true;
  }

  /// Opens the picker for the given [source], reads the image, compresses it to WebP (< 150 KB),
  /// and saves it to a temporary file. Returns [CompressedImageResult], or `null` if the user cancelled.
  Future<CompressedImageResult?> pickAndCompressImage({
    required ImageSource source,
    required BuildContext context,
  }) async {
    // 1. Permission check
    final hasPermission = await requestPermissionForSource(source, context: context);
    if (!hasPermission) return null;

    // 2. Pick image
    XFile? pickedFile;
    try {
      pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open photo picker: ${e.toString()}'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
      return null;
    }

    // 3. User cancelled picker
    if (pickedFile == null) {
      return null;
    }

    // 4. Read raw image bytes
    final Uint8List rawBytes;
    try {
      rawBytes = await pickedFile.readAsBytes();
      if (rawBytes.isEmpty) {
        throw const FormatException('Selected image file is empty.');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to read selected photo: ${e.toString()}'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
      return null;
    }

    // 5. Compress to WebP under 150 KB
    final Uint8List compressedBytes;
    try {
      // Offload compression and encoding to background isolate
      compressedBytes = await compute(compressImageBytesToWebP, rawBytes);
    } catch (e) {
      if (context.mounted) {
        final message = e is FormatException ? e.message : 'Compression failed: ${e.toString()}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
      return null;
    }

    // 6. Save compressed WebP to temporary file on disk (or keep in-memory on web)
    String savedPath = pickedFile.path;
    try {
      if (!kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final targetFile = File('${tempDir.path}/item_$timestamp.webp');
        await targetFile.writeAsBytes(compressedBytes, flush: true);
        savedPath = targetFile.path;
      }
    } catch (_) {
      // Fallback to picked file path if writing temp file fails
    }

    return CompressedImageResult(
      path: savedPath,
      bytes: compressedBytes,
      sizeInBytes: compressedBytes.lengthInBytes,
    );
  }

  /// Displays a modal bottom sheet prompting the user to select Camera or Gallery.
  static Future<ImageSource?> showPhotoSourceSheet(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      backgroundColor: AppColors.white,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.grey300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Select Item Photo',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandBrown,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Choose camera to take a photo or select from gallery',
                  style: TextStyle(fontSize: 12, color: AppColors.grey600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_outlined, color: AppColors.primaryOrange),
                  ),
                  title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Use camera to photograph the dish'),
                  onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
                ),
                const Divider(height: 1, color: AppColors.grey200),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.vendorTeal.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_outlined, color: AppColors.vendorTeal),
                  ),
                  title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Pick an existing photo or file'),
                  onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        );
      },
    );
  }
}
