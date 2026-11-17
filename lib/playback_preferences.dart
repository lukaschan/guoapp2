import 'video_enhancement_preferences.dart';

const playbackSpeeds = [.5, .75, 1.0, 1.25, 1.5, 2.0, 3.0];

const danmakuColors = [
  0xFFFFFFFF,
  0xFFFFE066,
  0xFF66E0FF,
  0xFFFF8FB8,
  0xFF8CF08C,
];

enum DanmakuCoverage {
  quarter(.25, '顶部四分之一'),
  half(.5, '顶部一半'),
  full(1, '全部');

  const DanmakuCoverage(this.fraction, this.label);

  final double fraction;
  final String label;
}

const danmakuScaleMin = .6;
const danmakuScaleMax = 2.0;

const danmakuStrokeMin = 0.0;
const danmakuStrokeMax = 6.0;

const danmakuShadowMin = 0.0;
const danmakuShadowMax = 12.0;

const danmakuSpeedMin = .5;
const danmakuSpeedMax = 2.0;

class PlaybackPreferences {
  const PlaybackPreferences({
    this.speed = 1,
    this.quality = 0,
    this.autoAdvance = true,
    this.danmaku = true,
    this.danmakuScale = 1,
    this.danmakuColor = 0xFFFFFFFF,
    this.danmakuOpacity = 1,
    this.danmakuBold = true,
    this.danmakuStroke = 0,
    this.danmakuShadow = 3,
    this.danmakuCoverage = DanmakuCoverage.half,
    this.danmakuSpeed = 1,
    this.preload = true,
    this.enhancement = const VideoEnhancementPreferences(),
  });

  final double speed;
  final int quality;
  final bool autoAdvance;
  final bool danmaku;
  final double danmakuScale;
  final int danmakuColor;
  final double danmakuOpacity;
  final bool danmakuBold;
  final double danmakuStroke;
  final double danmakuShadow;
  final DanmakuCoverage danmakuCoverage;
  final double danmakuSpeed;
  final bool preload;
  final VideoEnhancementPreferences enhancement;

  PlaybackPreferences copyWith({
    double? speed,
    int? quality,
    bool? autoAdvance,
    bool? danmaku,
    double? danmakuScale,
    int? danmakuColor,
    double? danmakuOpacity,
    bool? danmakuBold,
    double? danmakuStroke,
    double? danmakuShadow,
    DanmakuCoverage? danmakuCoverage,
    double? danmakuSpeed,
    bool? preload,
    VideoEnhancementPreferences? enhancement,
  }) => PlaybackPreferences(
    speed: speed ?? this.speed,
    quality: quality ?? this.quality,
    autoAdvance: autoAdvance ?? this.autoAdvance,
    danmaku: danmaku ?? this.danmaku,
    danmakuScale: danmakuScale ?? this.danmakuScale,
    danmakuColor: danmakuColor ?? this.danmakuColor,
    danmakuOpacity: danmakuOpacity ?? this.danmakuOpacity,
    danmakuBold: danmakuBold ?? this.danmakuBold,
    danmakuStroke: danmakuStroke ?? this.danmakuStroke,
    danmakuShadow: danmakuShadow ?? this.danmakuShadow,
    danmakuCoverage: danmakuCoverage ?? this.danmakuCoverage,
    danmakuSpeed: danmakuSpeed ?? this.danmakuSpeed,
    preload: preload ?? this.preload,
    enhancement: enhancement ?? this.enhancement,
  );

  Map<String, dynamic> toJson() => {
    'speed': speed,
    'quality': quality,
    'autoAdvance': autoAdvance,
    'danmaku': danmaku,
    'danmakuScale': danmakuScale,
    'danmakuColor': danmakuColor,
    'danmakuOpacity': danmakuOpacity,
    'danmakuBold': danmakuBold,
    'danmakuStroke': danmakuStroke,
    'danmakuShadow': danmakuShadow,
    'danmakuCoverage': danmakuCoverage.name,
    'danmakuSpeed': danmakuSpeed,
    'preload': preload,
    'enhancement': enhancement.toJson(),
  };

  factory PlaybackPreferences.fromJson(Map<String, dynamic> value) {
    final speed = (value['speed'] as num? ?? 1).toDouble();
    final quality = value['quality'] as int? ?? 0;
    final autoAdvance = value['autoAdvance'] as bool? ?? true;
    final danmaku = value['danmaku'] as bool? ?? true;
    final danmakuColor = value['danmakuColor'] as int? ?? 0xFFFFFFFF;
    final preload = value['preload'] as bool? ?? true;
    if (!playbackSpeeds.contains(speed) || quality < 0 || quality > 4320) {
      throw const FormatException('播放偏好无效');
    }
    return PlaybackPreferences(
      speed: speed,
      quality: quality,
      autoAdvance: autoAdvance,
      danmaku: danmaku,
      danmakuScale: (value['danmakuScale'] as num? ?? 1).toDouble().clamp(
        danmakuScaleMin,
        danmakuScaleMax,
      ),
      danmakuColor: danmakuColors.contains(danmakuColor)
          ? danmakuColor
          : 0xFFFFFFFF,
      danmakuOpacity: (value['danmakuOpacity'] as num? ?? 1).toDouble().clamp(
        0.1,
        1.0,
      ),
      danmakuBold: value['danmakuBold'] as bool? ?? true,
      danmakuStroke: (value['danmakuStroke'] as num? ?? 0).toDouble().clamp(
        danmakuStrokeMin,
        danmakuStrokeMax,
      ),
      danmakuShadow: (value['danmakuShadow'] as num? ?? 3).toDouble().clamp(
        danmakuShadowMin,
        danmakuShadowMax,
      ),
      danmakuCoverage:
          DanmakuCoverage.values.asNameMap()[value['danmakuCoverage']] ??
          DanmakuCoverage.half,
      danmakuSpeed: (value['danmakuSpeed'] as num? ?? 1).toDouble().clamp(
        danmakuSpeedMin,
        danmakuSpeedMax,
      ),
      preload: preload,
      enhancement: VideoEnhancementPreferences.fromJson(value['enhancement']),
    );
  }
}
