import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/strava_connection_repository.dart';
import '../domain/strava_connection.dart';

const _stravaClientId = 'YOUR_STRAVA_CLIENT_ID';
const _stravaCallbackDomain = 'snorlax-d2f99.web.app';
const _stravaAuthUrl =
    'https://www.strava.com/oauth/mobile/authorize'
    '?client_id=$_stravaClientId'
    '&redirect_uri=https://$_stravaCallbackDomain/strava-callback.html'
    '&response_type=code'
    '&approval_prompt=auto'
    '&scope=activity:read_all';

class StravaConnectBanner extends StatefulWidget {
  const StravaConnectBanner({super.key, required this.uid, required this.repository});

  final String uid;
  final StravaConnectionRepository repository;

  @override
  State<StravaConnectBanner> createState() => _StravaConnectBannerState();
}

class _StravaConnectBannerState extends State<StravaConnectBanner> {
  bool _connecting = false;
  String? _error;

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
    });

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: _stravaAuthUrl,
        callbackUrlScheme: 'fitnesstracker',
      );
      final code = Uri.parse(result).queryParameters['code'];
      if (code == null) {
        throw StateError('Strava did not return an authorization code.');
      }
      await widget.repository.connect(code);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not connect to Strava. Please try again.');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _disconnect() async {
    await widget.repository.disconnect(widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StravaConnection?>(
      stream: widget.repository.watchConnection(widget.uid),
      builder: (context, snapshot) {
        final connected = snapshot.data != null;

        return GlassCard(
          child: Row(
            children: [
              Expanded(
                child: Text(connected ? 'Strava connected' : 'Connect Strava to sync your runs and rides'),
              ),
              if (_connecting)
                const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (connected)
                TextButton(onPressed: _disconnect, child: const Text('Disconnect'))
              else
                PrimaryButton(label: 'Connect', onPressed: _connect),
              if (_error != null) ...[
                const SizedBox(width: 8),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
            ],
          ),
        );
      },
    );
  }
}
