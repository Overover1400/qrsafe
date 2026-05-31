import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../codes/application/codes_list_controller.dart';
import '../../codes/application/codes_providers.dart';
import '../../codes/data/code_models.dart';
import '../data/code_payload.dart';
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

  static const _defaultColor = 0xFF3D2E1F; // brownDark

  /// The payload for the currently selected type.
  CodePayload get payload => payloads[type]!;

  /// Whether the current form is complete enough to save.
  bool get isValid => payload.isValid;

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
    final created = await ref.read(codesApiProvider).create(
      type: s.type,
      payload: s.payload.toJson(),
      label: s.label.trim().isEmpty ? null : s.label.trim(),
      isDynamic: s.isDynamic && s.type.supportsDynamic,
    );
    ref.read(codesListControllerProvider.notifier).optimisticallyAddCode(created);
    return created;
  }
}

/// The curated foreground swatches offered in the generator (value ints so they
/// live in immutable state cleanly). Blue and lavender are generator-only;
/// the rest mirror the shared peach palette.
const generatorSwatches = <int>[
  0xFF3D2E1F, // brownDark
  0xFFE96B7A, // coral
  0xFFFFB68A, // peachMid
  0xFF7AA8FF, // blue
  0xFFA88AE8, // lavender
  0xFF2D8F5C, // safe green
];
