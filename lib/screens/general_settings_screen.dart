import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Subtitle Settings
  String _subtitleFont = 'Default';
  Color _subtitleBackgroundColor = Colors.black.withAlpha((255 * 0.7).round());
  double _subtitleTextSize = 16.0;
  String _subtitlePosition = 'Bottom';
  bool _subtitlesEnabled = true;
  Color _subtitleTextColor = Colors.white;

  // In-App Video Player Settings
  bool _enableTheaterMode = false;
  bool _enablePictureInPicture = true;
  double _playerControlsTimeout = 5.0; // seconds
  bool _enableGestureControls = true;
  bool _enableFreezeDetection = true;
  bool _enableAdBlocking = true;
  bool _showPlayButton = true;

  final List<String> _fontOptions = [
    'Default',
    'Arial',
    'Roboto',
    'Open Sans',
    'Montserrat',
  ];
  final List<String> _positionOptions = ['Top', 'Center', 'Bottom'];


  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      // Load subtitle settings
      _subtitleFont = prefs.getString('subtitle_font') ?? 'Default';
      _subtitleTextSize = prefs.getDouble('subtitle_text_size') ?? 16.0;
      _subtitlePosition = prefs.getString('subtitle_position') ?? 'Bottom';
      _subtitlesEnabled = prefs.getBool('subtitles_enabled') ?? true;

      // Load subtitle colors
      // ignore: deprecated_member_use
      final bgColorValue =
          prefs.getInt('subtitle_bg_color') ??
          Colors.black.withAlpha((255 * 0.7).round()).value;
      _subtitleBackgroundColor = Color(bgColorValue);
      // ignore: deprecated_member_use
      final textColorValue =
          prefs.getInt('subtitle_text_color') ?? Colors.white.value;
      _subtitleTextColor = Color(textColorValue);

      // Load in-app video player settings
      _enableTheaterMode = prefs.getBool('inapp_theater_mode') ?? false;
      _enablePictureInPicture = prefs.getBool('inapp_pip_enabled') ?? true;
      _playerControlsTimeout =
          prefs.getDouble('inapp_controls_timeout') ?? 5.0;
      _enableGestureControls = prefs.getBool('inapp_gesture_controls') ?? true;
      _enableFreezeDetection = prefs.getBool('inapp_freeze_detection') ?? true;
      _enableAdBlocking = prefs.getBool('inapp_ad_blocking') ?? true;
      _showPlayButton = prefs.getBool('inapp_show_play_button') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // Save subtitle settings
      await prefs.setString('subtitle_font', _subtitleFont);
      await prefs.setDouble('subtitle_text_size', _subtitleTextSize);
      await prefs.setString('subtitle_position', _subtitlePosition);
      await prefs.setBool('subtitles_enabled', _subtitlesEnabled);
      // ignore: deprecated_member_use
      await prefs.setInt('subtitle_bg_color', _subtitleBackgroundColor.value);
      // ignore: deprecated_member_use
      await prefs.setInt('subtitle_text_color', _subtitleTextColor.value);

      // Save in-app video player settings
      await prefs.setBool('inapp_theater_mode', _enableTheaterMode);
      await prefs.setBool('inapp_pip_enabled', _enablePictureInPicture);
      await prefs.setDouble('inapp_controls_timeout', _playerControlsTimeout);
      await prefs.setBool('inapp_gesture_controls', _enableGestureControls);
      await prefs.setBool('inapp_freeze_detection', _enableFreezeDetection);
      await prefs.setBool('inapp_ad_blocking', _enableAdBlocking);
      await prefs.setBool('inapp_show_play_button', _showPlayButton);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'General Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.red,
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveSettings,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.red,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.subtitles), text: 'Subtitles'),
            Tab(icon: Icon(Icons.movie), text: 'In-App Player'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSubtitlesTab(),
          _buildInAppPlayerTab(),
        ],
      ),
    );
  }

  Widget _buildSubtitlesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Subtitle Settings'),
          const SizedBox(height: 16),

          // Enable/Disable Subtitles
          _buildSwitchTile(
            title: 'Enable Subtitles',
            subtitle: 'Show subtitles when available',
            value: _subtitlesEnabled,
            onChanged: (value) => setState(() => _subtitlesEnabled = value),
          ),

          const SizedBox(height: 24),

          // Font Selection
          _buildDropdownTile(
            title: 'Font Family',
            subtitle: 'Choose subtitle font',
            value: _subtitleFont,
            items: _fontOptions,
            onChanged: (value) => setState(() => _subtitleFont = value!),
          ),

          const SizedBox(height: 16),

          // Text Size
          _buildSliderTile(
            title: 'Text Size',
            subtitle: 'Adjust subtitle text size',
            value: _subtitleTextSize,
            min: 12.0,
            max: 24.0,
            divisions: 12,
            onChanged: (value) => setState(() => _subtitleTextSize = value),
            valueDisplay: '${_subtitleTextSize.round()}px',
          ),

          const SizedBox(height: 16),

          // Position
          _buildDropdownTile(
            title: 'Position',
            subtitle: 'Subtitle position on screen',
            value: _subtitlePosition,
            items: _positionOptions,
            onChanged: (value) => setState(() => _subtitlePosition = value!),
          ),

          const SizedBox(height: 24),

          // Text Color
          _buildColorTile(
            title: 'Text Color',
            subtitle: 'Subtitle text color',
            color: _subtitleTextColor,
            onColorChanged: (color) =>
                setState(() => _subtitleTextColor = color),
          ),

          const SizedBox(height: 16),

          // Background Color
          _buildColorTile(
            title: 'Background Color',
            subtitle: 'Subtitle background color',
            color: _subtitleBackgroundColor,
            onColorChanged: (color) =>
                setState(() => _subtitleBackgroundColor = color),
          ),

          const SizedBox(height: 24),

          // Preview Section
          _buildSubtitlePreview(),
        ],
      ),
    );
  }

  Widget _buildInAppPlayerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('In-App Video Player Features'),
          const SizedBox(height: 16),

          // Theater Mode
          _buildSwitchTile(
            title: 'Theater Mode',
            subtitle: 'Expand video to fill screen',
            value: _enableTheaterMode,
            onChanged: (value) => setState(() => _enableTheaterMode = value),
          ),

          const SizedBox(height: 16),

          // Picture in Picture
          _buildSwitchTile(
            title: 'Picture in Picture',
            subtitle: 'Enable floating video window',
            value: _enablePictureInPicture,
            onChanged: (value) =>
                setState(() => _enablePictureInPicture = value),
          ),

          const SizedBox(height: 16),

          // Gesture Controls
          _buildSwitchTile(
            title: 'Gesture Controls',
            subtitle: 'Enable double-tap & swipe controls',
            value: _enableGestureControls,
            onChanged: (value) =>
                setState(() => _enableGestureControls = value),
          ),

          const SizedBox(height: 16),

          // Show Play Button
          _buildSwitchTile(
            title: 'Show Play Button',
            subtitle: 'Display center play/pause button',
            value: _showPlayButton,
            onChanged: (value) => setState(() => _showPlayButton = value),
          ),

          const SizedBox(height: 16),

          // Freeze Detection
          _buildSwitchTile(
            title: 'Freeze Detection',
            subtitle: 'Detect and notify when player freezes',
            value: _enableFreezeDetection,
            onChanged: (value) =>
                setState(() => _enableFreezeDetection = value),
          ),

          const SizedBox(height: 16),

          // Ad Blocking
          _buildSwitchTile(
            title: 'Ad Blocking',
            subtitle: 'Block ads in embedded content',
            value: _enableAdBlocking,
            onChanged: (value) => setState(() => _enableAdBlocking = value),
          ),

          const SizedBox(height: 24),

          // Controls Timeout
          _buildSliderTile(
            title: 'Controls Timeout',
            subtitle: 'Auto-hide controls after seconds',
            value: _playerControlsTimeout,
            min: 2.0,
            max: 15.0,
            divisions: 13,
            onChanged: (value) =>
                setState(() => _playerControlsTimeout = value),
            valueDisplay: '${_playerControlsTimeout.toStringAsFixed(1)}s',
          ),

          const SizedBox(height: 24),

          // Reset to Defaults
          _buildResetInAppPlayerButton(),
        ],
      ),
    );
  }

  Widget _buildResetInAppPlayerButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: const Icon(Icons.restore, color: Colors.orange),
        title: const Text(
          'Reset In-App Player Settings',
          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
        ),
        subtitle: const Text(
          'Restore player settings to default values',
          style: TextStyle(color: Colors.grey),
        ),
        onTap: _resetInAppPlayerToDefaults,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.red,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String subtitle,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
        trailing: DropdownButton<String>(
          value: value,
          onChanged: onChanged,
          dropdownColor: const Color(0xFF2A2A2A),
          style: const TextStyle(color: Colors.white),
          underline: Container(),
          items: items.map((String item) {
            return DropdownMenuItem<String>(value: item, child: Text(item));
          }).toList(),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required String valueDisplay,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                Text(
                  valueDisplay,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.red,
                inactiveTrackColor: Colors.grey[700],
                thumbColor: Colors.red,
                overlayColor: Colors.red.withOpacity(0.2),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                trackHeight: 4,
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorTile({
    required String title,
    required String subtitle,
    required Color color,
    required ValueChanged<Color> onColorChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
        trailing: GestureDetector(
          onTap: () => _showColorPicker(color, onColorChanged),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildSubtitlePreview() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Preview',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  // Fake video background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.grey[800]!, Colors.grey[600]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                  // Subtitle preview
                  if (_subtitlesEnabled)
                    Positioned(
                      left: 16,
                      right: 16,
                      top: _subtitlePosition == 'Top' ? 16 : null,
                      bottom: _subtitlePosition == 'Bottom' ? 16 : null,
                      child: _subtitlePosition == 'Center'
                          ? Center(child: _buildPreviewSubtitle())
                          : _buildPreviewSubtitle(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSubtitle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _subtitleBackgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Sample subtitle text',
        style: TextStyle(
          color: _subtitleTextColor,
          fontSize: _subtitleTextSize,
          fontFamily: _subtitleFont == 'Default' ? null : _subtitleFont,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  void _showColorPicker(
    Color currentColor,
    ValueChanged<Color> onColorChanged,
  ) {
    final colors = [
      Colors.white,
      Colors.black,
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.cyan,
      Colors.grey,
      Colors.brown,
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Choose Color',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 300,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: colors.length,
            itemBuilder: (context, index) {
              final color = colors[index];
              return GestureDetector(
                onTap: () {
                  onColorChanged(color);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: currentColor == color ? Colors.red : Colors.white,
                      width: currentColor == color ? 3 : 1,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _resetInAppPlayerToDefaults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Reset In-App Player Settings',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Restore in-app player settings to defaults?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _enableTheaterMode = false;
                _enablePictureInPicture = true;
                _playerControlsTimeout = 5.0;
                _enableGestureControls = true;
                _enableFreezeDetection = true;
                _enableAdBlocking = true;
                _showPlayButton = true;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('In-App Player settings reset to defaults'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
