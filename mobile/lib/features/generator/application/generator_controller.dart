import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../codes/application/codes_list_controller.dart';
import '../../codes/application/codes_providers.dart';
import '../../codes/data/code_models.dart';
import '../data/code_payload.dart';
import '../data/multi_link.dart';
import '../data/payload_encoder.dart';

/// Immutable form state for the generator: the selected [type], a separate
/// [CodePayload] per type (so switching tabs preserves each form), the dynamic
/// flag, the chosen QR foreground [color], and the [label].
class GeneratorState {
  const GeneratorState({
    required this.type,
    required this.payloads,
    required this.isDynamic,
    required this.color,
    required this.label,
  });

  final CodeType type;
  final Map<CodeType, CodePayload> payloads;
  final bool isDynamic;

  /// QR foreground color (client-side render choice only; not sent to backend).
  final int color;
  final String label;

  /// Initial state: URL type selected, empty forms, brown foreground.
  factory GeneratorState.initial() => GeneratorState(
    type: CodeType.url,
    payloads: {
      for (final t in CodeType.values) t: CodePayload.empty(t),
    },
    isDynamic: false,
    color: _defaultColor,
    label: '',
  );

  static const _defaultColor = 0xFF3D2E1F; // inkDark

  /// The payload for the currently selected type.
  CodePayload get payload => payloads[type]!;

  /// Every tab the user has filled in, in tab order.
  List<CodePayload> get filledPayloads => [
    for (final t in CodeType.values)
      if (payloads[t]!.isValid) payloads[t]!,
  ];

  /// Whether anything at all can be saved. Deliberately not limited to the
  /// visible tab: with two tabs filled, Save stays live while she looks at an
  /// empty third one.
  bool get isValid => filledPayloads.isNotEmpty;

  /// More than one filled tab turns the save into a hosted multi-link page
  /// instead of five separate codes.
  bool get isMultiLink => filledPayloads.length > 1;

  /// The string that would be encoded into the QR for a static code (the live
  /// preview always shows this literal content).
  String get encodedContent => PayloadEncoder.encode(payload);

  GeneratorState copyWith({
    CodeType? type,
    Map<CodeType, CodePayload>? payloads,
    bool? isDynamic,
    int? color,
    String? label,
  }) => GeneratorState(
    type: type ?? this.type,
    payloads: payloads ?? this.payloads,
    isDynamic: isDynamic ?? this.isDynamic,
    color: color ?? this.color,
    label: label ?? this.label,
  );
}

/// Drives the create flow. The generator screen watches this; on save it returns
/// the created [Code] and adds it to the dashboard list optimistically.
final generatorControllerProvider =
    NotifierProvider<GeneratorController, GeneratorState>(
      GeneratorController.new,
    );

class GeneratorController extends Notifier<GeneratorState> {
  @override
  GeneratorState build() => GeneratorState.initial();

  /// Switches the active type. Dynamic is forced off for non-URL types.
  void setType(CodeType type) {
    state = state.copyWith(
      type: type,
      isDynamic: type.supportsDynamic && state.isDynamic,
    );
  }

  /// Replaces the payload for its own type (the form for the current type).
  void updatePayload(CodePayload payload) {
    state = state.copyWith(
      payloads: {...state.payloads, payload.type: payload},
    );
  }

  /// Toggles the dynamic flag. Rejected (kept false) unless the current type
  /// supports dynamic codes (URL only).
  void setDynamic(bool value) {
    if (!state.type.supportsDynamic) {
      state = state.copyWith(isDynamic: false);
      return;
    }
    state = state.copyWith(isDynamic: value);
  }

  void setColor(int color) => state = state.copyWith(color: color);

  void setLabel(String label) => state = state.copyWith(label: label);

  /// Resets the form to its initial state (after a successful save).
  void reset() => state = GeneratorState.initial();

  /// Persists the code via the API, optimistically adds it to the dashboard
  /// list, and returns it. Throws the typed API exception on failure.
  Future<Code> save() async {
    final s = state;
    final label = s.label.trim();
    final filled = s.filledPayloads;
    final api = ref.read(codesApiProvider);

    final Code created;
    if (filled.length > 1) {
      // Several tabs filled: one QR that opens a page holding all of them.
      created = await api.createMulti(
        items: [
          for (final item in buildMultiLinkItems(filled)) item.toJson(),
        ],
        title: label.isEmpty ? null : label,
        label: label.isEmpty ? 'Multi-link' : label,
      );
    } else {
      // Save the one filled tab, which need not be the visible one.
      final payload = filled.isEmpty ? s.payload : filled.first;
      created = await api.create(
        type: payload.type,
        payload: payload.toJson(),
        label: label.isEmpty ? null : label,
        isDynamic: s.isDynamic && payload.type.supportsDynamic,
      );
    }

    ref.read(codesListControllerProvider.notifier).optimisticallyAddCode(created);
    return created;
  }
}

/// The curated foreground swatches offered in the generator (value ints so they
/// live in immutable state cleanly). Blue and lavender are generator-only;
/// the rest mirror the shared teal palette.
const generatorSwatches = <int>[
  0xFF0F3B3F, // inkDark
  0xFF0E5F6B, // deep teal
  0xFF134E8A, // navy
  0xFF5B3FA8, // violet
  0xFF16734A, // forest
  0xFF8A2B3F, // wine
];
