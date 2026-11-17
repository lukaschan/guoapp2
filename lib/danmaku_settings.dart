import 'package:flutter/material.dart';

import 'playback_preferences.dart';

const _colorLabels = ['白色', '黄色', '青色', '粉色', '绿色'];

class DanmakuSettings extends StatefulWidget {
  const DanmakuSettings({
    super.key,
    required this.preferences,
    required this.onChanged,
    this.busy = false,
  });

  final PlaybackPreferences preferences;
  final ValueChanged<PlaybackPreferences> onChanged;
  final bool busy;

  @override
  State<DanmakuSettings> createState() => _DanmakuSettingsState();
}

class _DanmakuSettingsState extends State<DanmakuSettings> {
  late double _scale = widget.preferences.danmakuScale;
  late int _color = widget.preferences.danmakuColor;
  late double _opacity = widget.preferences.danmakuOpacity;
  late bool _bold = widget.preferences.danmakuBold;
  late double _stroke = widget.preferences.danmakuStroke;
  late double _shadow = widget.preferences.danmakuShadow;
  late DanmakuCoverage _coverage = widget.preferences.danmakuCoverage;
  late double _speed = widget.preferences.danmakuSpeed;

  @override
  void didUpdateWidget(DanmakuSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.preferences;
    final next = widget.preferences;
    if (next.danmakuScale != old.danmakuScale) _scale = next.danmakuScale;
    if (next.danmakuColor != old.danmakuColor) _color = next.danmakuColor;
    if (next.danmakuOpacity != old.danmakuOpacity) {
      _opacity = next.danmakuOpacity;
    }
    if (next.danmakuBold != old.danmakuBold) _bold = next.danmakuBold;
    if (next.danmakuStroke != old.danmakuStroke) _stroke = next.danmakuStroke;
    if (next.danmakuShadow != old.danmakuShadow) _shadow = next.danmakuShadow;
    if (next.danmakuCoverage != old.danmakuCoverage) {
      _coverage = next.danmakuCoverage;
    }
    if (next.danmakuSpeed != old.danmakuSpeed) _speed = next.danmakuSpeed;
  }

  void _commit() {
    widget.onChanged(
      widget.preferences.copyWith(
        danmakuScale: _scale,
        danmakuColor: _color,
        danmakuOpacity: _opacity,
        danmakuBold: _bold,
        danmakuStroke: _stroke,
        danmakuShadow: _shadow,
        danmakuCoverage: _coverage,
        danmakuSpeed: _speed,
      ),
    );
  }

  Widget _slider({
    required Key key,
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required ValueChanged<double> onChanged,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title)),
            Text(
              label,
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ],
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: colors.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        Slider(
          key: key,
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: widget.busy
              ? null
              : (next) {
                  onChanged(next);
                  setState(() {});
                },
          onChangeEnd: widget.busy ? null : (_) => _commit(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('弹幕外观'),
        const SizedBox(height: 8),
        _slider(
          key: const ValueKey('danmaku-setting-scale'),
          title: '字号',
          subtitle: '相对默认字号的比例',
          value: _scale,
          min: danmakuScaleMin,
          max: danmakuScaleMax,
          divisions: 14,
          label: '${(_scale * 100).round()}%',
          onChanged: (value) => _scale = value,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (index, color) in danmakuColors.indexed)
              ChoiceChip(
                key: ValueKey('danmaku-setting-color-$index'),
                avatar: CircleAvatar(backgroundColor: Color(color)),
                label: Text(_colorLabels[index]),
                selected: _color == color,
                showCheckmark: false,
                shape: const StadiumBorder(),
                onSelected: widget.busy
                    ? null
                    : (_) {
                        setState(() => _color = color);
                        _commit();
                      },
              ),
          ],
        ),
        const SizedBox(height: 8),
        _slider(
          key: const ValueKey('danmaku-setting-opacity'),
          title: '透明度',
          subtitle: '调低后弹幕更透，不挡画面',
          value: _opacity,
          min: .1,
          max: 1,
          divisions: 18,
          label: '${(_opacity * 100).round()}%',
          onChanged: (value) => _opacity = value,
        ),
        SwitchListTile.adaptive(
          key: const ValueKey('danmaku-setting-bold'),
          contentPadding: EdgeInsets.zero,
          title: const Text('加粗'),
          subtitle: const Text('加粗的字在亮背景上更清楚'),
          value: _bold,
          onChanged: widget.busy
              ? null
              : (value) {
                  setState(() => _bold = value);
                  _commit();
                },
        ),
        _slider(
          key: const ValueKey('danmaku-setting-stroke'),
          title: '描边',
          subtitle: _stroke == 0 ? '关闭' : '描边越粗字越突出',
          value: _stroke,
          min: danmakuStrokeMin,
          max: danmakuStrokeMax,
          divisions: 12,
          label: _stroke == 0 ? '关闭' : _stroke.toStringAsFixed(1),
          onChanged: (value) => _stroke = value,
        ),
        _slider(
          key: const ValueKey('danmaku-setting-shadow'),
          title: '阴影',
          subtitle: _shadow == 0 ? '关闭' : '阴影越浓字越清晰',
          value: _shadow,
          min: danmakuShadowMin,
          max: danmakuShadowMax,
          divisions: 12,
          label: _shadow == 0 ? '关闭' : _shadow.toStringAsFixed(1),
          onChanged: (value) => _shadow = value,
        ),
        const SizedBox(height: 12),
        const Text('滚动'),
        const SizedBox(height: 8),
        _slider(
          key: const ValueKey('danmaku-setting-speed'),
          title: '滚动速度',
          subtitle: '弹幕划过屏幕的快慢',
          value: _speed,
          min: danmakuSpeedMin,
          max: danmakuSpeedMax,
          divisions: 15,
          label: '${_speed.toStringAsFixed(1)}x',
          onChanged: (value) => _speed = value,
        ),
        const SizedBox(height: 12),
        const Text('显示区域'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final coverage in DanmakuCoverage.values)
              ChoiceChip(
                key: ValueKey('danmaku-setting-coverage-${coverage.name}'),
                label: Text(coverage.label),
                selected: _coverage == coverage,
                showCheckmark: false,
                shape: const StadiumBorder(),
                onSelected: widget.busy
                    ? null
                    : (_) {
                        setState(() => _coverage = coverage);
                        _commit();
                      },
              ),
          ],
        ),
      ],
    );
  }
}
