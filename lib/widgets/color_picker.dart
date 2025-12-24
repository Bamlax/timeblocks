import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ColorPicker extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;

  const ColorPicker({
    super.key,
    required this.initialColor,
    required this.onColorChanged,
  });

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  late HSVColor _currentHsv;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _currentHsv = HSVColor.fromColor(widget.initialColor);
    _hexController = TextEditingController(text: _colorToHex(widget.initialColor));
  }

  // Color -> Hex String
  String _colorToHex(Color color) {
    return color.value.toRadixString(16).toUpperCase().padLeft(8, '0').substring(2);
  }

  void _onHsvChanged(HSVColor hsv) {
    setState(() {
      _currentHsv = hsv;
      final color = hsv.toColor();
      // 只有当Hex不一样时才更新文本，避免光标跳动
      if (_colorToHex(color) != _hexController.text) {
        _hexController.text = _colorToHex(color);
      }
    });
    widget.onColorChanged(_currentHsv.toColor());
  }

  void _onHexSubmitted(String value) {
    if (value.length == 6) {
      try {
        final int hexInt = int.parse(value, radix: 16);
        final color = Color(hexInt + 0xFF000000);
        setState(() {
          _currentHsv = HSVColor.fromColor(color);
        });
        widget.onColorChanged(color);
      } catch (e) {
        // ignore error
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. SV 面板 (饱和度 & 亮度) - 提供拖动点
        SizedBox(
          height: 180,
          width: double.infinity,
          child: _SaturationValueBox(
            hsvColor: _currentHsv,
            onChanged: _onHsvChanged,
          ),
        ),
        const SizedBox(height: 16),

        // 2. Hue 滑块 (色相)
        SizedBox(
          height: 30,
          width: double.infinity,
          child: _HueSlider(
            hsvColor: _currentHsv,
            onChanged: _onHsvChanged,
          ),
        ),
        const SizedBox(height: 16),

        // 3. 预览与 Hex 输入
        Row(
          children: [
            // 颜色预览圆圈
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _currentHsv.toColor(),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Hex 输入框
            Expanded(
              child: TextField(
                controller: _hexController,
                decoration: const InputDecoration(
                  labelText: 'Hex Color',
                  prefixText: '#',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                ],
                onChanged: _onHexSubmitted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// --- 子组件：饱和度/亮度选择面板 ---

class _SaturationValueBox extends StatelessWidget {
  final HSVColor hsvColor;
  final ValueChanged<HSVColor> onChanged;

  const _SaturationValueBox({required this.hsvColor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanDown: (details) => _handleGesture(details.localPosition, constraints),
          onPanUpdate: (details) => _handleGesture(details.localPosition, constraints),
          child: Stack(
            children: [
              // 底层：当前色相的纯色
              Container(
                decoration: BoxDecoration(
                  color: HSVColor.fromAHSV(1.0, hsvColor.hue, 1.0, 1.0).toColor(),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              // 中层：白色渐变 (Saturation: 左白 -> 右透明)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.white, Colors.transparent],
                  ),
                ),
              ),
              // 顶层：黑色渐变 (Value: 上透明 -> 下黑)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black],
                  ),
                ),
              ),
              // 拖动点 (Cursor)
              Positioned(
                left: hsvColor.saturation * constraints.maxWidth - 10,
                top: (1 - hsvColor.value) * constraints.maxHeight - 10,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: hsvColor.toColor(),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 2),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleGesture(Offset position, BoxConstraints constraints) {
    double saturation = (position.dx / constraints.maxWidth).clamp(0.0, 1.0);
    double value = 1.0 - (position.dy / constraints.maxHeight).clamp(0.0, 1.0);
    onChanged(hsvColor.withSaturation(saturation).withValue(value));
  }
}

// --- 子组件：色相滑块 ---

class _HueSlider extends StatelessWidget {
  final HSVColor hsvColor;
  final ValueChanged<HSVColor> onChanged;

  const _HueSlider({required this.hsvColor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanDown: (details) => _handleGesture(details.localPosition, constraints),
          onPanUpdate: (details) => _handleGesture(details.localPosition, constraints),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // 彩虹条背景
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00),
                      Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF),
                      Color(0xFFFF0000)
                    ],
                  ),
                ),
              ),
              // 滑块
              Positioned(
                left: (hsvColor.hue / 360) * constraints.maxWidth - 10,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 2),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleGesture(Offset position, BoxConstraints constraints) {
    double hue = (position.dx / constraints.maxWidth * 360).clamp(0.0, 360.0);
    onChanged(hsvColor.withHue(hue));
  }
}