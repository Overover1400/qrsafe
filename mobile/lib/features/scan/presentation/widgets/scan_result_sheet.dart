import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/verdict_pill.dart';
import '../../application/scan_controller.dart';
import '../../data/scan_models.dart';

/// Modal bottom-sheet content for a scan. Watches [scanControllerProvider] and
/// shows a spinner while the check runs, an error state on failure, or the
/// verdict via [ScanResultView] on success.
///
/// Shown by `ScannerScreen` with `showModalBottomSheet`. The screen is
/// responsible for recording the scan into recent activity once this sheet is
/// dismissed.
class ScanResultSheet extends ConsumerWidget {
  const ScanResultSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scanControllerProvider);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: state.when(
          loading: () => const _SheetMessage(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Checking this link…'),
                ],
              ),
            ),
          ),
          error: (err, _) => _SheetMessage(child: _ErrorBody(error: err)),
          data: (result) => result == null
              ? const SizedBox.shrink()
              : ScanResultView(result: result),
        ),
      ),
    );
  }
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [const _Grabber(), child],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).message
        : "Couldn't check this link. Try again.";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 40, color: context.qrColors.brownLight),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// The verdict view: gradient header (URL + pill), safety-check list, and the
/// per-verdict action. Public so it can be widget-tested directly with a fixed
/// [ScanResult].
class ScanResultView extends StatelessWidget {
  const ScanResultView({super.key, required this.result});

  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Grabber(),
        _HeaderCard(result: result),
        const SizedBox(height: 16),
        _ChecksList(result: result),
        const SizedBox(height: 20),
        _VerdictAction(result: result),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text('Dismiss', style: TextStyle(color: c.brownLight)),
          ),
        ),
      ],
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.qrColors.brownTint.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.result});
  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: context.qrColors.peachGradient,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scanned link',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            result.url.isEmpty ? '(empty)' : result.url,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: VerdictPill(verdict: result.verdict),
          ),
        ],
      ),
    );
  }
}

class _ChecksList extends StatelessWidget {
  const _ChecksList({required this.result});
  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    final reasons = result.reasons;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Safety checks',
          style: TextStyle(
            color: c.brownMid,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        if (reasons.isEmpty)
          _CheckRow(
            icon: Icons.check_circle_rounded,
            color: c.safe,
            text: result.verdict == Verdict.safe
                ? 'No issues found'
                : 'No additional details',
          )
        else
          ...reasons.map(
            (r) => _CheckRow(
              icon: Icons.info_outline_rounded,
              color: c.brownLight,
              text: r.message.isEmpty ? r.code : r.message,
            ),
          ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// The bottom action, which varies by verdict (see brief). DANGER deliberately
/// has no easy path: a disabled-looking primary plus a long-press-only override.
class _VerdictAction extends StatelessWidget {
  const _VerdictAction({required this.result});
  final ScanResult result;

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(result.url);
    final ok = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open this link.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.qrColors;
    switch (result.verdict) {
      case Verdict.safe:
        return PrimaryButton.solid(
          label: 'Open link',
          color: c.brownDark,
          icon: Icons.open_in_new_rounded,
          onPressed: () => _open(context),
        );
      case Verdict.caution:
        return PrimaryButton.solid(
          label: 'Open anyway',
          color: c.caution,
          subtitle: 'We recommend not opening this',
          onPressed: () => _open(context),
        );
      case Verdict.unknown:
        return PrimaryButton.solid(
          label: 'Open link',
          color: c.brownDark,
          subtitle: "Couldn't verify — proceed with caution",
          onPressed: () => _open(context),
        );
      case Verdict.danger:
        return Column(
          children: [
            PrimaryButton.solid(
              label: "Don't open",
              color: c.brownTint,
              onPressed: null, // disabled-looking; no easy way through
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onLongPress: () => _open(context),
              child: Text(
                'Open anyway (not recommended) — long-press',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.danger,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        );
    }
  }
}
