import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ota_update/ota_update.dart';
import 'package:espenseai/core/constants/colors.dart';
import 'package:google_fonts/google_fonts.dart';

class UpdateService {
  /// Checks for available updates in Firestore.
  /// If a newer version code is found, prompts the user to update.
  static Future<void> checkAndPromptUpdate(BuildContext context) async {
    // OTA App updates are only applicable/supported for Android direct installations.
    if (!Platform.isAndroid) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('update')
          .get()
          .timeout(const Duration(seconds: 4));

      if (!doc.exists) return;

      final data = doc.data();
      if (data == null) return;

      final latestVersionCode = (data['latest_version_code'] as num?)?.toInt();
      final latestVersionName = data['latest_version_name'] as String? ?? '1.0.0';
      final apkUrl = data['apk_url'] as String? ?? '';
      final releaseNotes = data['release_notes'] as String? ?? 'Bug fixes and performance improvements.';
      final minRequiredVersion = (data['min_required_version'] as num?)?.toInt() ?? 0;

      if (latestVersionCode == null || apkUrl.isEmpty) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      debugPrint('OTA Update Check: latestVersionCode=$latestVersionCode, currentVersionCode=$currentVersionCode, apkUrl=$apkUrl, minRequiredVersion=$minRequiredVersion');

      if (latestVersionCode > currentVersionCode) {
        final isForced = currentVersionCode < minRequiredVersion;
        if (context.mounted) {
          final didChooseUpdate = await showDialog<bool>(
            context: context,
            barrierDismissible: !isForced,
            builder: (dialogContext) => _UpdateDialog(
              versionName: latestVersionName,
              releaseNotes: releaseNotes,
              isForced: isForced,
            ),
          );

          if (didChooseUpdate == true && context.mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (progressContext) => _DownloadProgressDialog(
                apkUrl: apkUrl,
                isForced: isForced,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('In-app update check failed or timed out: $e');
    }
  }
}

class _UpdateDialog extends StatelessWidget {
  final String versionName;
  final String releaseNotes;
  final bool isForced;

  const _UpdateDialog({
    required this.versionName,
    required this.releaseNotes,
    required this.isForced,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: AppColors.cardDark.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.borderDark.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryPurple.withOpacity(0.15),
              blurRadius: 30,
              spreadRadius: 2,
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon Header
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update_alt_rounded,
                    color: AppColors.primaryPurple,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Update Available',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryDark,
                ),
              ),
              const SizedBox(height: 8),

              // Version details
              Text(
                'Version $versionName is now ready.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.electricBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),

              // Release Notes Header
              Text(
                "WHAT'S NEW",
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondaryDark,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),

              // Release Notes List Box
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderDark.withOpacity(0.3)),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    releaseNotes,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textSecondaryDark.withOpacity(0.9),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  if (!isForced) ...[
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Later',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryPurple.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(true); // Close update prompt and return true
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Update Now',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadProgressDialog extends StatefulWidget {
  final String apkUrl;
  final bool isForced;

  const _DownloadProgressDialog({
    required this.apkUrl,
    required this.isForced,
  });

  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0.0;
  String _statusMessage = 'Initializing download...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  void _startDownload() {
    setState(() {
      _hasError = false;
      _progress = 0.0;
      _statusMessage = 'Connecting to server...';
    });

    try {
      OtaUpdate()
          .execute(
        widget.apkUrl,
        destinationFilename: 'espenseai-update.apk',
      )
          .listen(
        (OtaEvent event) {
          if (!mounted) return;
          setState(() {
            switch (event.status) {
              case OtaStatus.DOWNLOADING:
                _progress = double.tryParse(event.value ?? '0') ?? 0.0;
                _statusMessage = 'Downloading: ${_progress.toInt()}%';
                break;
              case OtaStatus.INSTALLING:
              case OtaStatus.INSTALLATION_DONE:
                _progress = 100.0;
                _statusMessage = 'Launching package installer...';
                break;
              case OtaStatus.ALREADY_RUNNING_ERROR:
                _hasError = true;
                _statusMessage = 'Update download already running.';
                break;
              case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                _hasError = true;
                _statusMessage = 'Please grant permission to install packages.';
                break;
              case OtaStatus.INTERNAL_ERROR:
                _hasError = true;
                _statusMessage = 'Internal system error.';
                break;
              case OtaStatus.DOWNLOAD_ERROR:
                _hasError = true;
                _statusMessage = 'Failed to download updated files.';
                break;
              case OtaStatus.CHECKSUM_ERROR:
                _hasError = true;
                _statusMessage = 'Downloaded package checksum mismatch.';
                break;
              case OtaStatus.INSTALLATION_ERROR:
                _hasError = true;
                _statusMessage = 'Installation failed.';
                break;
              case OtaStatus.CANCELED:
                _hasError = true;
                _statusMessage = 'Update was canceled.';
                break;
              default:
                _hasError = true;
                _statusMessage = 'An unexpected update status occurred.';
                break;
            }
          });

          if (event.status == OtaStatus.INSTALLING) {
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) Navigator.of(context).pop();
            });
          }
        },
        onError: (err) {
          if (!mounted) return;
          setState(() {
            _hasError = true;
            _statusMessage = 'Network or system failure: $err';
          });
        },
      );
    } catch (e) {
      setState(() {
        _hasError = true;
        _statusMessage = 'Failed to initialize OTA connection: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent dismissing the dialog by tapping back button
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderDark.withOpacity(0.5)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _hasError ? 'Update Interrupted' : 'Downloading Update',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _hasError ? AppColors.accentPink : AppColors.textPrimaryDark,
                ),
              ),
              const SizedBox(height: 20),
              if (!_hasError) ...[
                // Circular progress matching theme
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: _progress / 100.0,
                        strokeWidth: 6,
                        backgroundColor: AppColors.borderDark,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
                      ),
                    ),
                    Text(
                      '${_progress.toInt()}%',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.accentPink,
                  size: 64,
                ),
              ],
              const SizedBox(height: 20),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              if (_hasError) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (!widget.isForced)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.borderDark),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Close',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                        ),
                      ),
                    if (!widget.isForced) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _startDownload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Retry',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
