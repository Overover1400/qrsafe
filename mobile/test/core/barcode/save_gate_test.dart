import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrsafe_mobile/core/barcode/barcode_image.dart';
import 'package:qrsafe_mobile/features/generator/application/generator_controller.dart';
import 'package:qrsafe_mobile/features/generator/data/code_payload.dart';

void main() {
  test('Save turns on once a barcode value can be encoded', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final c = container.read(generatorControllerProvider.notifier);

    c.setType(CodeType.barcode);
    var s = container.read(generatorControllerProvider);

    c.updatePayload(
      const BarcodePayload(symbology: BarcodeSymbology.code128, value: '12345'),
    );
    s = container.read(generatorControllerProvider);

    expect(s.isValid, isTrue);
  });
}
