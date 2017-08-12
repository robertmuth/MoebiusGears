import 'dart:html' as HTML;
import 'dart:math' as Math;
import 'dart:async';
import 'package:vector_math/vector_math.dart' as VM;
import 'package:chronosgl/chronosgl.dart';

import 'option.dart';
import 'webutil.dart';
import 'involute.dart';
import 'logging.dart' as log;
import 'rgb.dart';

Options gOptions;

final ShaderObject lightVertexShaderBlinnPhongSolid =
    new ShaderObject("LightBlinnPhongV")
      ..AddAttributeVars([aPosition, aNormal])
      ..AddVaryingVars([vPosition, vNormal])
      ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix, uNormalMatrix])
      ..SetBody([
        """
void main() {
    vec4 pos = ${uModelMatrix} * vec4(${aPosition}, 1.0);
    gl_Position = ${uPerspectiveViewMatrix} * pos;
    ${vPosition} = pos.xyz;
    ${vNormal} = ${uNormalMatrix} * ${aNormal};
}
"""
      ]);

final ShaderObject lightFragmentShaderBlinnPhongSolid =
    new ShaderObject("LightBlinnPhongF")
      ..AddVaryingVars([vPosition, vNormal])
      ..AddUniformVars([uLightDescs, uShininess, uColor, uColorAmbient])
      ..AddUniformVars([uEyePosition])
      ..SetBodyWithMain([
        """
ColorComponents acc = CombinedLightDirectional(${vPosition},
                                               ${vNormal},
                                               ${uEyePosition},
                                               ${uLightDescs}[0],
                                               ${uShininess});

// plasticy
${oFragColor}.rgb = (acc.diffuse + ${uColorAmbient}) * ${uColor} + acc.specular;
// metallic
//${oFragColor}.rgb = (acc.diffuse + ${uColorAmbient} + acc.specular) * ${uColor};
// flat
//${oFragColor}.rgb = (acc.diffuse + ${uColorAmbient}) * ${uColor};

${oFragColor}.a = 1.0;
"""
      ], prolog: [
        StdLibShader,
      ]);

const double kShadowBias1 = 0.001;
const double kShadowBias2 = 0.999; // not really used - must be proper float

final ShaderObject solidColorVertexShaderWithShadow =
    new ShaderObject("SolidColor")
      ..AddAttributeVars([aPosition])
      ..AddUniformVars(
          [uPerspectiveViewMatrix, uModelMatrix, uLightPerspectiveViewMatrix])
      ..AddVaryingVars([vPosition, vPositionFromLight])
      ..SetBody([
        """
void main() {        
    vec4 pos = ${uModelMatrix} * vec4(${aPosition}, 1.0);
    ${vPositionFromLight} = ${uLightPerspectiveViewMatrix} * pos;
    gl_Position = ${uPerspectiveViewMatrix} * pos;
    ${vPosition} = pos.xyz;
}
        """
      ]);

final ShaderObject solidColorFragmentShaderWithShadow =
    new ShaderObject("SolidColorF")
      ..AddUniformVars([uColor, uShadowMap])
      ..AddVaryingVars([vPosition, vPositionFromLight])
      ..SetBody([
        """
void main() {
    vec3 depth = ${vPositionFromLight}.xyz / ${vPositionFromLight}.w;
    // depth is in [-1, 1] but we want [0, 1] for the texture lookup
    depth = 0.5 * depth + vec3(0.5);
    float shadow = GetShadow(depth, ${uShadowMap}, ${kShadowBias1}, ${kShadowBias2});
    //if (shadow < 0.7) shadow + 0.3;
    ${oFragColor} = vec4( ${uColor} * shadow, 1.0 );
}
        """
      ], prolog: [
        StdLibShader,
        ShadowMapShaderLib,
      ]);

void HandleCommand(String cmd, String param) {
  LogInfo("HandleCommand: ${cmd} ${param}");
  switch (cmd) {
    case "A":
      Toggle(HTML.querySelector(".about"));
      break;
    case "C":
      Toggle(HTML.querySelector(".config"));
      gOptions.SaveToLocalStorage();
      break;
    case "P":
      Toggle(HTML.querySelector(".performance"));
      break;
    case "R":
      gOptions.SaveToLocalStorage();
      HTML.window.location.hash = "";
      HTML.window.location.reload();
      break;
    case "A+":
      Show(HTML.querySelector(".about"));
      break;
    case "A-":
      Hide(HTML.querySelector(".about"));
      break;
    case "F":
      ToggleFullscreen();
      break;
    case "C-":
      Hide(HTML.querySelector(".config"));
      gOptions.SaveToLocalStorage();
      break;
    case "C+":
      Show(HTML.querySelector(".config"));
      break;
    case "X":
      String preset =
          (HTML.querySelector("#preset") as HTML.SelectElement).value;
      gOptions.SetNewSettings(preset);
      HTML.window.location.reload();
      break;
    default:
      break;
  }
}

const String oLogLevel = "logLevel";
const String oBackgroundColor = "backgroundColor";
const String oGearColor = "gearColor";
const String oGearNoise = "gearNoise";
const String oGearThickness = "gearThickness";
const String oGearSpeed = "gearSpeed";
const String oNumGears = "numGears";
const String oNumTeeth = "numTeeth";
const String oRingSpeedX = "ringSpeedX";
const String oRingSpeedY = "ringSpeedY";
const String oRingSpeedTwist = "ringSpeedTwist";

const String oWireFrame = "wireFrame";
const String oShadow = "shadow";

const String oShinyGears = "shinyGears";
const String oHideAbout = "hideAbout";
const String oRandomSeed = "randomSeed";

void OptionsSetup() {
  gOptions = new Options("moebius_gears")
    ..AddOption(oBackgroundColor, "S", "black")
    ..AddOption(oGearColor, "S", "white")
    ..AddOption(oGearNoise, "I", "30")
    ..AddOption(oGearThickness, "D", "15.0")
    ..AddOption(oGearSpeed, "D", "0.01")
    ..AddOption(oNumGears, "I", "17")
    ..AddOption(oNumTeeth, "I", "15")
    ..AddOption(oRingSpeedX, "D", "0.01")
    ..AddOption(oRingSpeedY, "D", "0.01")
    ..AddOption(oRingSpeedTwist, "D", "0.005")
    ..AddOption(oShinyGears, "B", "true")
    ..AddOption(oWireFrame, "B", "false")
    ..AddOption(oShadow, "B", "false")
    ..AddOption(oHideAbout, "B", "false")
    ..AddOption(oRandomSeed, "I", "0")
    // Only in debug mode
    ..AddOption(oLogLevel, "I", "0", true);

  gOptions.AddSetting("Standard", {
    oBackgroundColor: "black",
    oGearThickness: "15",
    oGearColor: "white",
    oGearNoise: "30",
    oGearSpeed: "0.01",
    oNumGears: "17",
    oNumTeeth: "15",
    oRingSpeedX: "0.01",
    oRingSpeedY: "0.01",
    oRingSpeedTwist: "0.0",
    oShinyGears: "true",
    oWireFrame: "false",
    oShadow: "false",
  });

  gOptions.AddSetting("StandardTwist", {
    oBackgroundColor: "black",
    oGearThickness: "15",
    oGearColor: "white",
    oGearNoise: "30",
    oGearSpeed: "0.01",
    oNumGears: "17",
    oNumTeeth: "15",
    oRingSpeedX: "0.0",
    oRingSpeedY: "0.0",
    oRingSpeedTwist: "0.01",
    oShinyGears: "true",
    oWireFrame: "false",
    oShadow: "false",
  });

  gOptions.AddSetting("Red", {
    oBackgroundColor: "black",
    oGearThickness: "15",
    oGearColor: "red",
    oGearNoise: "0",
    oGearSpeed: "0.01",
    oNumGears: "17",
    oNumTeeth: "15",
    oRingSpeedX: "0.01",
    oRingSpeedY: "0.01",
    oRingSpeedTwist: "0.0",
    oShinyGears: "true",
    oWireFrame: "false",
    oShadow: "false",
  });

 gOptions.AddSetting("RedWireFrame", {
    oBackgroundColor: "black",
    oGearThickness: "15",
    oGearColor: "red",
    oGearNoise: "0",
    oGearSpeed: "0.01",
    oNumGears: "17",
    oNumTeeth: "15",
    oRingSpeedX: "0.01",
    oRingSpeedY: "0.01",
    oRingSpeedTwist: "0.0",
    oShinyGears: "true",
    oWireFrame: "true",
    oShadow: "false",
  });

 gOptions.AddSetting("RedShadow", {
    oBackgroundColor: "blue",
    oGearThickness: "15",
    oGearColor: "red",
    oGearNoise: "0",
    oGearSpeed: "0.01",
    oNumGears: "17",
    oNumTeeth: "15",
    oRingSpeedX: "0.01",
    oRingSpeedY: "0.01",
    oRingSpeedTwist: "0.0",
    oShinyGears: "true",
    oWireFrame: "false",
    oShadow: "true",
  });

  gOptions.AddSetting("Blue", {
    oBackgroundColor: "black",
    oGearThickness: "15",
    oGearColor: "blue",
    oGearNoise: "0",
    oGearSpeed: "0.01",
    oNumGears: "17",
    oNumTeeth: "15",
    oRingSpeedX: "0.01",
    oRingSpeedY: "0.01",
    oRingSpeedTwist: "0.0",
    oShinyGears: "true",
    oWireFrame: "false",
    oShadow: "false",
  });

  gOptions.AddSetting("Many", {
    oBackgroundColor: "black",
    oGearThickness: "15",
    oGearColor: "yellow",
    oGearNoise: "20",
    oGearSpeed: "0.01",
    oNumGears: "33",
    oNumTeeth: "15",
    oRingSpeedX: "0.01",
    oRingSpeedY: "0.01",
    oRingSpeedTwist: "0.0",
    oShinyGears: "false",
    oWireFrame: "false",
    oShadow: "false",
  });

  gOptions.AddSetting("Fat", {
    oBackgroundColor: "black",
    oGearThickness: "25",
    oGearColor: "white",
    oGearNoise: "50",
    oGearSpeed: "0.01",
    oNumGears: "33",
    oNumTeeth: "15",
    oRingSpeedX: "0.01",
    oRingSpeedY: "0.01",
    oRingSpeedTwist: "0.0",
    oShinyGears: "false",
    oWireFrame: "false",
    oShadow: "false",
  });

  gOptions.ProcessUrlHash();
  log.gLogLevel = gOptions.GetInt(oLogLevel);
  log.gLogLevel = 0;

  HTML.SelectElement presets = HTML.querySelector("#preset");
  for (String name in gOptions.SettingsNames()) {
    HTML.OptionElement o = new HTML.OptionElement(data: name, value: name);
    presets.append(o);
  }

  if (gOptions.GetBool("hideAbout")) {
    var delay = const Duration(seconds: 4);
    new Timer(delay, () => Hide(HTML.querySelector(".about")));
  }
}

final HTML.Element gFps = HTML.querySelector("#fps");

void PickBestEdge() {
  /*
    double c1 = VM.dot3((contour1[s1] - contour1[n1]).normalized(),
        (contour2[s2] - contour1[n1]).normalized());
    double c2 = VM.dot3((contour1[s1] - contour2[n2]).normalized(),
        (contour2[s2] - contour2[n2]).normalized());
*/
  /*
    double c1 = VM.cross2(
        (contour2[s2] - contour1[n1]).xy, (contour1[s1] - contour2[n2]).xy);
    double c2 = -VM.cross2(
        (contour1[s1] - contour1[n1]).xy, (contour2[s2] - contour1[n1]).xy);
   */
}

bool gPickEdgeEven = false;

bool PickEdge(VM.Vector3 s1, VM.Vector3 s2, VM.Vector3 t1, VM.Vector3 t2) {
  gPickEdgeEven = !gPickEdgeEven;
  return gPickEdgeEven;
}

bool PickEdgeClosest(
    VM.Vector3 s1, VM.Vector3 s2, VM.Vector3 t1, VM.Vector3 t2) {
  double d1 = (s1 - t2).length2;
  double d2 = (s2 - t1).length2;
  return d1 > d2;
}

void LinkClosedContours(
    GeometryBuilder gb, List<VM.Vector3> contour1, List<VM.Vector3> contour2) {
  int s1 = 0;
  int s2 = 0;
  double shortest = (contour1[s1] - contour2[s2]).length2;
  for (int i = 0; i < contour1.length; ++i) {
    for (int j = 0; j < contour2.length; ++j) {
      double d = (contour1[i] - contour2[j]).length2;
      if (d < shortest) {
        shortest = d;
        s1 = i;
        s2 = j;
      }
    }
  }

  final int x1 = s1;
  final int x2 = s2;

  List<int> edges = <int>[];
  edges.add(s1);
  edges.add(s2);
  double last2 = 1e100;
  do {
    int n1 = s1 == contour1.length - 1 ? 0 : s1 + 1;
    int n2 = s2 == contour2.length - 1 ? 0 : s2 + 1;
    if (PickEdgeClosest(
        contour1[s1], contour2[s2], contour1[n1], contour2[n2])) {
      s1 = n1;
    } else {
      s2 = n2;
    }
    edges.add(s1);
    edges.add(s2);
    if (edges.length ~/ 2 > contour1.length + contour2.length) {
      print("possible infinite loop");
      break;
    }
  } while (s1 != x1 || s2 != x2);

  for (int i = 0; i < edges.length - 2; i += 2) {
    int s1 = edges[i + 0];
    int s2 = edges[i + 1];
    int t1 = edges[i + 2];
    int t2 = edges[i + 3];
    if (s1 == t1) {
      gb.AddVerticesFace3([contour1[s1], contour2[s2], contour2[t2]]);
    } else {
      assert(s2 == t2);
      gb.AddVerticesFace3([contour1[s1], contour2[s2], contour1[t1]]);
    }
  }
}

void ExtrudeQuads(
    GeometryBuilder gb, List<VM.Vector3> contour1, List<VM.Vector3> contour2) {
  assert(contour1.length == contour2.length);

  VM.Vector3 last1 = contour1.last;
  VM.Vector3 last2 = contour2.last;
  for (int i = 0; i < contour1.length; ++i) {
    VM.Vector3 curr1 = contour1[i];
    VM.Vector3 curr2 = contour2[i];
    gb.AddVerticesFace4([last1, last2, curr2, curr1]);
    last1 = curr1;
    last2 = curr2;
  }
}

MeshData MakeGear(int numTeeth, double radius, double h, double thickness,
    RenderProgram program) {
  final GeometryBuilder gb = new GeometryBuilder();

  final List<VM.Vector2> path = GearPath(numTeeth, radius, h, kToothHuge);
  final List<VM.Vector2> gradientPath = GetContourGradient(path);

  final double holeR = radius * 0.6;
  final double bevelH = 0.4;
  final double bevelW = 0.05;
  int bevelSteps = 6;

  List<VM.Vector2> supportsTemplate =
      BevelSupportPoints(bevelW, bevelH, bevelSteps);

  List<VM.Vector2> supports = [];
  for (VM.Vector2 v in supportsTemplate.reversed) {
    supports
        .add(new VM.Vector2(v.x * radius, -thickness * (1.0 - bevelH + v.y)));
  }
  for (VM.Vector2 v in supportsTemplate) {
    supports
        .add(new VM.Vector2(v.x * radius, thickness * (1.0 - bevelH + v.y)));
  }

  List<VM.Vector2> supportsSimple = [
    new VM.Vector2(0.0, -thickness),
    new VM.Vector2(0.0, thickness),
  ];
  List<List<VM.Vector3>> stripsPath =
      BevelStrips(path, gradientPath, supports, new VM.Matrix3.identity());

  List<VM.Vector2> hole = CirclePath(2 * numTeeth, holeR);
  final List<VM.Vector2> gradientHole = GetContourGradient(hole);

  gb.AddFaces4Strips(stripsPath, true);
  List<List<VM.Vector3>> stripsHole = BevelStrips(
      hole, gradientHole, supportsSimple, new VM.Matrix3.identity());
  gb.AddFaces4Strips(stripsHole, true, true);

  LinkClosedContours(gb, stripsPath[0], stripsHole[0]);
  LinkClosedContours(gb, stripsHole.last, stripsPath.last);

  gb.GenerateNormalsAssumingTriangleMode();
  gb.GenerateWireframeCenters();
  print("Geometry: ${gb}");
  return GeometryBuilderToMeshData("gear", program, gb);
}

// an odd number of gears enables the Moebius twisting
List<Node> MakeRing(List<Material> mats, RenderProgram program, int numGears,
    int numTeeth, double radius, double toothHeight, double thickness) {
  List<Node> out = [];
  final MeshData gear =
      MakeGear(numTeeth, radius, toothHeight, thickness, program);

  // distance between gears if not moebius-interleaved
  double w = 2 * radius + toothHeight;
  double outer_r = w * numGears / 2.0 / 2.0 / Math.PI;
  double outerAngleStep = 2.0 * Math.PI * 2.0 / numGears;

  for (int i = 0; i < numGears; ++i) {
    //  for turning each gear
    Node node1 = new Node("1", gear, mats[i]);
    //  for turning around diametrical axis
    Node node2 = new Node.Container("2", node1);
    //
    Node node3 = new Node.Container("3", node2);
    node2.setPos(0.0, 0.0, outer_r * 0.95);
    // twist
    node2.rotX(i * Math.PI / numGears);

    // where in the orbit the gear positioned
    Node node4 = new Node.Container("4", node3);
    node3.rotY(i * outerAngleStep);
    out.add(node4);
  }
  return out;
}

const int shadowMapDimension = 1024;

ShadowMap ActivateShadows(
    ChronosGL cgl,
    RenderPhase phase,
    Node ring,
    VM.Vector3 wallColor,
    VM.Matrix4 shadowProjection,
    Perspective perspective,
    Illumination illumination) {
  final Material matWall = new Material("matWall")
    ..SetUniform(uColor, wallColor);

  ShadowMap shadowMap =
      new ShadowMap(cgl, shadowMapDimension, shadowMapDimension, 0.01, 10.0);
  shadowMap.AddShadowCaster(ring);
  matWall
    ..SetUniform(uShadowMap, shadowMap.GetMapTexture())
    ..SetUniform(uLightPerspectiveViewMatrix, shadowProjection);

  RenderProgram progWall = new RenderProgram("wall", cgl,
      solidColorVertexShaderWithShadow, solidColorFragmentShaderWithShadow);

  final Scene sceneWall =
      new Scene("wall", progWall, [perspective, illumination]);
  Node wall = new Node("quad", ShapeQuad(progWall, 100), matWall)
    ..rotY(-Math.PI)
    ..moveBackward(-20.0);

  sceneWall.add(wall);
  phase.add(sceneWall);
  return shadowMap;
}

void main() {
  final HTML.CanvasElement canvas = HTML.document.querySelector('#area');
  canvas.width = HTML.window.innerWidth;
  canvas.height = HTML.window.innerHeight;
  print("startup");
  if (!HasWebGLSupport()) {
    HTML.window.alert("Your browser does not support WebGL.");
    return;
  }
  OptionsSetup();

  int seed = gOptions.GetInt(oRandomSeed);
  if (seed == 0) {
    seed = new DateTime.now().millisecondsSinceEpoch;
  }
  Math.Random rng = new Math.Random(seed);

  ChronosGL cgl = new ChronosGL(canvas, faceCulling: true);
  cgl.enable(GL_CULL_FACE);
  OrbitCamera orbit = new OrbitCamera(10.0, -Math.PI / 2, 0.0, canvas);
  Perspective perspective = new Perspective(orbit, 0.1, 100.0)
    ..AdjustAspect(canvas.width, canvas.height);

  final VM.Vector3 dirLight = new VM.Vector3(0.0, 0.0, 0.2);
  final bool shiny = gOptions.GetBool(oShinyGears);
  final Light light = new DirectionalLight(
      "dir", dirLight, ColorWhite, shiny ? ColorWhite : ColorBlack, 5.0);
  final VM.Matrix4 shadowProjection = light.ExtractShadowProjViewMatrix();
  final Illumination illumination = new Illumination();
  illumination.AddLight(light);

  RenderPhase phase = new RenderPhase("main", cgl)
    ..viewPortW = canvas.width
    ..viewPortH = canvas.height;

  bool useWire = gOptions.GetBool(oWireFrame);
  bool useShadow = gOptions.GetBool(oShadow);

  RenderProgram prog = useWire
      ? new RenderProgram(
          "wire", cgl, wireframeVertexShader, wireframeFragmentShader)
      : new RenderProgram("blinnphong", cgl, lightVertexShaderBlinnPhongSolid,
          lightFragmentShaderBlinnPhongSolid);

  final Scene scene = new Scene("scene", prog, [perspective, illumination]);
  phase.add(scene);

  int numTeeth = gOptions.GetInt(oNumTeeth);
  int numGears = gOptions.GetInt(oNumGears);
  double radius = 1.0;
  double thickness = radius * gOptions.GetDouble(oGearThickness) / 100.0;

  double toothHeight = radius * 0.2;

  final String gearColor = gOptions.Get(oGearColor);
  final double noise = gOptions.GetInt(oGearNoise) / 100.0;

  final List<Material> mats = <Material>[];
  for (int i = 0; i < numGears; ++i) {
    List<double> rgb = MakeColorWithNoise(rng, gearColor, noise);
    VM.Vector3 color = new VM.Vector3.array(rgb);
    mats.add(new Material("mat")
      ..SetUniform(uColorAlpha, new VM.Vector4(color.r, color.g, color.b, 1.0))
      ..SetUniform(uColorAlpha2, new VM.Vector4(0.0, 0.0, 0.0, 0.5))
      ..SetUniform(uColor, color)
      ..SetUniform(uColorAmbient, color * 0.2)
      ..SetUniform(uShininess, 50.0));
  }
  final List<Node> gears = MakeRing(
      mats, scene.program, numGears, numTeeth, radius, toothHeight, thickness);
  final Node ring = new Node.Container("top");
  scene.add(ring);
  for (Node n in gears) {
    ring.add(n);
  }

  final VM.Vector3 bgColor =
      new RGB.fromNameOrRandom(rng, gOptions.Get(oBackgroundColor)).GlColor();
  cgl.clearColor(bgColor.r, bgColor.g, bgColor.b, 0.0);

  ShadowMap shadowMap;
  if (useShadow) {
    shadowMap = ActivateShadows(
        cgl, phase, ring, bgColor, shadowProjection, perspective, illumination);
  }

  HTML.document.body.onKeyDown.listen((HTML.KeyboardEvent e) {
    LogInfo("key pressed ${e.which} ${e.target.runtimeType}");
    if (e.target.runtimeType == HTML.InputElement) {
      return;
    }
    String cmd = new String.fromCharCodes([e.which]);
    HandleCommand(cmd, "");
  });

  HTML.ElementList<HTML.Element> buttons =
      HTML.document.body.querySelectorAll("button");
  LogInfo("found ${buttons.length} buttons");
  buttons.onClick.listen((HTML.Event ev) {
    String cmd = (ev.target as HTML.Element).dataset['cmd'];
    String param = (ev.target as HTML.Element).dataset['param'];
    HandleCommand(cmd, param);
  });

  double _lastTimeMs = 0.0;

  void animate(num timeMs) {
    timeMs = 0.0 + timeMs;
    double elapsed = timeMs - _lastTimeMs;
    _lastTimeMs = timeMs;
    //orbit.azimuth += 0.001;
    orbit.animate(elapsed);

    double gearSpeed = gOptions.GetDouble(oGearSpeed);
    double twistSpeed = gOptions.GetDouble(oRingSpeedTwist);

    ring.rotY(gOptions.GetDouble(oRingSpeedY));
    ring.rotX(gOptions.GetDouble(oRingSpeedX));

    for (int i = 0; i < gears.length; ++i) {
      Node middle = gears[i].children[0].children[0];
      Node leaf = middle.children[0];

      leaf.rotZ((i % 2 == 1) ? gearSpeed : -gearSpeed);
      middle.rotX(twistSpeed);
    }

    List<DrawStats> stats = [];
    if (shadowMap != null) shadowMap.Compute(shadowProjection);
    phase.Draw(stats);
    List<String> out = [];
    int items = 0;
    Duration duration = new Duration();
    for (DrawStats d in stats) {
      items += d.numItems;
      duration += d.duration;
      out.add(d.toString());
    }
    out.add("total ${items} ${duration.inMicroseconds}usec");

    UpdateFrameCount(timeMs, gFps, out.join("\n"));

    HTML.window.animationFrame.then(animate);
  }

  animate(0.0);
}
