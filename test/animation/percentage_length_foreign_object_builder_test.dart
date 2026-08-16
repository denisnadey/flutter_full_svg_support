import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';

void main() {
  testWidgets('foreignObjectBuilder receives percentage-resolved geometry', (
    tester,
  ) async {
    SvgForeignObjectInfo? receivedInfo;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedSvgPicture.string(
            '''
              <svg viewBox="0 0 200 100">
                <foreignObject id="foreign" x="25%" y="10%"
                               width="50%" height="50%"/>
              </svg>
            ''',
            width: 200,
            height: 100,
            foreignObjectBuilder: (context, info) {
              receivedInfo = info;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(receivedInfo, isNotNull);
    expect(receivedInfo!.id, 'foreign');
    expect(receivedInfo!.x, 50);
    expect(receivedInfo!.y, 10);
    expect(receivedInfo!.width, 100);
    expect(receivedInfo!.height, 50);
  });
}
