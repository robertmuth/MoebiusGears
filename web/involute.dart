library involute;

import 'dart:math';
import 'dart:math' as Math;

import 'package:vector_math/vector_math.dart' as VM;

/*
From xscreen-saver's mobious gear

Approximate shape of an "involute" gear tooth.

                                 (TH)
                 th0 th2 th4 th6 th8 t10 t12 t14 th16  th18   th20
                   :  :  :   :    :    :   :  :  :      :      :
                   :  :  :   :    :    :   :  :  :      :      :
        r0 ........:..:..:...___________...:..:..:......:......:..
                   :  :  :  /:    :    :\  :  :  :      :      :
                   :  :  : / :    :    : \ :  :  :      :      :
                   :  :  :/  :    :    :  \:  :  :      :      :
        r2 ........:.....@...:....:....:...@..:..:......:......:..
                   :  : @:   :    :    :   :@ :  :      :      :
    (R) ...........:...@.:...:....:....:...:.@..........:......:......
                   :  :@ :   :    :    :   : @:  :      :      :
        r4 ........:..@..:...:....:....:...:..@:........:......:..
                   : /:  :   :    :    :   :  :\ :      :      :
                   :/ :  :   :    :    :   :  : \:      :      : /
        r6 ......__/..:..:...:....:....:...:..:..\______________/
                   :  :  :   :    :    :   :  :  :      :      :
                   |  :  :   :    :    :   :  :  |      :      :
                   :  :  :   :    :    :   :  :  :      :      :
                   |  :  :   :    :    :   :  :  |      :      :
        r8 ......__:_____________________________:________________
*/

// Each of these needs to be multiplied by tooth._h and then added to the radius
// Each tooth has unit width.
final List<List<double>> kToothSmall = [
  [-0.5, -0.5],
  [0.0, 0.5],
];

final List<List<double>> kToothMedium = [
  // degree (x) - radius (y)
  [-0.41, -0.5],
  [-0.1, 0.5],
  // middle
  [0.1, 0.5],
  [0.41, -0.5],
];

final List<List<double>> kToothLarge = [
  // degree (x) - radius (y)
  [-0.45, -0.5],
  [-0.3, -0.25],
  [-0.16, 0.25],
  [-0.04, 0.5],
  // middle
  [0.04, 0.5],
  [0.16, 0.25],
  [0.3, -0.25],
  [0.45, -0.5],
  // gap
  [0.5, -0.5],
];

final List<List<double>> kToothHuge = [
  // degree (x) - radius (y)
  [-0.45, -0.5],
  [-0.375, -0.4],
  [-0.3, -0.25],
  [-0.23, 0.05],
  [-0.16, 0.25],
  [-0.1, 0.4],
  [-0.04, 0.5],

  ///
  [0.0, 0.5],
  // middle
  [0.04, 0.5],
  [0.1, 0.4],
  [0.16, 0.25],
  [0.23, -0.05],
  [0.3, -0.25],
  [0.375, -0.4],
  [0.45, -0.5],
  // gap
  [0.47, -0.5],
  [0.50, -0.5],
  [0.53, -0.5],
];

// Poking out
List ScaledTooth(
    int numTeethPerCircle, double radius, double h, List normTooth) {
  final double arc = 2 * PI / numTeethPerCircle;
  return normTooth.map((x) => [arc * x[0], radius + h * x[1]]).toList();
}

// Poking in
List<List<double>> ScaledToothInverted(int numTeethPerCircle, double radius,
    double h, List<List<double>> normTooth) {
  final double arc = 2 * PI / numTeethPerCircle;
  return normTooth.map((x) => [arc * x[0], radius - h * x[1]]).toList();
}

// Gear Contour
List<VM.Vector2> GearPath(
    int numTeeth, double radius, double h, List normTooth) {
  List tooth = ScaledToothInverted(numTeeth, radius, h, normTooth);
  List<VM.Vector2> out = [];

  for (int i = 0; i < numTeeth; ++i) {
    double angle = 2 * Math.PI * i / numTeeth;
    for (var polar in tooth) {
      double x = polar[1] * Math.cos(angle + polar[0]);
      double y = polar[1] * Math.sin(angle + polar[0]);
      out.add(new VM.Vector2(x, y));
    }
  }
  return out;
}

// Circle Contour
List<VM.Vector2> CirclePath(int segments, double radius, [int offset = 0]) {
  List<VM.Vector2> out = [];
  for (int i = 0; i < segments; ++i) {
    double angle = 2 * Math.PI * (i + offset) / segments;
    double x = radius * Math.cos(angle);
    double y = radius * Math.sin(angle);
    out.add(new VM.Vector2(x, y));
  }
  return out;
}
