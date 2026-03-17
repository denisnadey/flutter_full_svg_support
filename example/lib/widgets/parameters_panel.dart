import 'package:flutter/material.dart';
import '../state/app_state.dart';

/// Панель для настройки параметров AnimatedSvgPicture
class ParametersPanel extends StatelessWidget {
  final AppState state;

  const ParametersPanel({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(left: BorderSide(color: Colors.grey.shade300)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildSizeControls(),
            const Divider(height: 32),
            _buildPlaybackControls(),
            const Divider(height: 32),
            _buildLayoutControls(),
            const Divider(height: 32),
            _buildBackgroundControl(),
            const Divider(height: 32),
            _buildResetButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.tune, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Text('Parameters', style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }

  Widget _buildSizeControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Size', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildSlider(
          label: 'Width: ${state.width.toInt()}',
          value: state.width,
          min: 100,
          max: 600,
          onChanged: state.setWidth,
        ),
        const SizedBox(height: 8),
        _buildSlider(
          label: 'Height: ${state.height.toInt()}',
          value: state.height,
          min: 100,
          max: 600,
          onChanged: state.setHeight,
        ),
      ],
    );
  }

  Widget _buildPlaybackControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Playback', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Auto Play'),
          value: state.autoPlay,
          onChanged: state.setAutoPlay,
        ),
        const SizedBox(height: 8),
        _buildSlider(
          label: 'Speed: ${state.playbackRate.toStringAsFixed(1)}x',
          value: state.playbackRate,
          min: 0.1,
          max: 5.0,
          divisions: 49,
          onChanged: state.setPlaybackRate,
        ),
      ],
    );
  }

  Widget _buildLayoutControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Layout', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildDropdown<BoxFit>(
          label: 'Fit',
          value: state.fit,
          items: BoxFit.values,
          onChanged: (value) => state.setFit(value!),
          itemBuilder: (fit) => Text(_fitToString(fit)),
        ),
        const SizedBox(height: 12),
        _buildDropdown<Alignment>(
          label: 'Alignment',
          value: state.alignment,
          items: [
            Alignment.topLeft,
            Alignment.topCenter,
            Alignment.topRight,
            Alignment.centerLeft,
            Alignment.center,
            Alignment.centerRight,
            Alignment.bottomLeft,
            Alignment.bottomCenter,
            Alignment.bottomRight,
          ],
          onChanged: (value) => state.setAlignment(value!),
          itemBuilder: (alignment) => Text(_alignmentToString(alignment)),
        ),
      ],
    );
  }

  Widget _buildBackgroundControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Background', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildColorChip(null, 'None'),
            _buildColorChip(Colors.white, 'White'),
            _buildColorChip(Colors.black, 'Black'),
            _buildColorChip(Colors.grey.shade200, 'Gray'),
            _buildColorChip(Colors.blue.shade50, 'Blue'),
            _buildColorChip(Colors.green.shade50, 'Green'),
          ],
        ),
      ],
    );
  }

  Widget _buildColorChip(Color? color, String label) {
    final isSelected = state.backgroundColor == color;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => state.setBackgroundColor(color),
      avatar: color != null
          ? Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                border: Border.all(color: Colors.grey),
                shape: BoxShape.circle,
              ),
            )
          : const Icon(Icons.block, size: 16),
    );
  }

  Widget _buildResetButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: state.resetToDefaults,
        icon: const Icon(Icons.restart_alt),
        label: const Text('Reset to Defaults'),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required Widget Function(T) itemBuilder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          initialValue: value,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: items.map((item) {
            return DropdownMenuItem<T>(value: item, child: itemBuilder(item));
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  String _fitToString(BoxFit fit) {
    switch (fit) {
      case BoxFit.contain:
        return 'Contain';
      case BoxFit.cover:
        return 'Cover';
      case BoxFit.fill:
        return 'Fill';
      case BoxFit.fitWidth:
        return 'Fit Width';
      case BoxFit.fitHeight:
        return 'Fit Height';
      case BoxFit.none:
        return 'None';
      case BoxFit.scaleDown:
        return 'Scale Down';
    }
  }

  String _alignmentToString(Alignment alignment) {
    if (alignment == Alignment.topLeft) return 'Top Left';
    if (alignment == Alignment.topCenter) return 'Top Center';
    if (alignment == Alignment.topRight) return 'Top Right';
    if (alignment == Alignment.centerLeft) return 'Center Left';
    if (alignment == Alignment.center) return 'Center';
    if (alignment == Alignment.centerRight) return 'Center Right';
    if (alignment == Alignment.bottomLeft) return 'Bottom Left';
    if (alignment == Alignment.bottomCenter) return 'Bottom Center';
    if (alignment == Alignment.bottomRight) return 'Bottom Right';
    return 'Unknown';
  }
}
