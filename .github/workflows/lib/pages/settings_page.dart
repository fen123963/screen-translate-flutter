// settings_page.dart - 设置页
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return ListView(
            children: [
              // 外观设置
              _buildSectionHeader('外观'),
              _buildSwitchTile(
                icon: Icons.dark_mode,
                title: '夜间模式',
                subtitle: '使用深色主题',
                value: appState.isDarkMode,
                onChanged: (value) {
                  appState.setDarkMode(value);
                },
              ),
              
              const Divider(),
              
              // 翻译设置
              _buildSectionHeader('翻译设置'),
              _buildSliderTile(
                icon: Icons.opacity,
                title: '译文透明度',
                value: appState.translationOpacity,
                min: 0.5,
                max: 1.0,
                divisions: 10,
                onChanged: (value) {
                  appState.setTranslationOpacity(value);
                },
              ),
              
              const Divider(),
              
              // 识别设置
              _buildSectionHeader('识别设置'),
              _buildIntervalTile(
                context: context,
                icon: Icons.timer,
                title: '识别间隔',
                currentInterval: appState.captureInterval,
                onChanged: (value) {
                  appState.setCaptureInterval(value);
                },
              ),
              
              _buildCropHeightTile(
                context: context,
                icon: Icons.crop_top,
                title: '顶部屏蔽高度',
                currentHeight: appState.topCropHeight,
                onChanged: (value) {
                  appState.setTopCropHeight(value);
                },
              ),
              
              const Divider(),
              
              // 关于
              _buildSectionHeader('关于'),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('版本'),
                subtitle: const Text('1.0.0'),
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('开源许可'),
                subtitle: const Text('查看开源组件许可'),
                onTap: () {
                  // 显示许可信息
                  showLicensePage(
                    context: context,
                    applicationName: '屏幕翻译',
                    applicationVersion: '1.0.0',
                  );
                },
              ),
              
              const SizedBox(height: 24),
              
              // 重置设置
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showResetDialog(context, appState);
                  },
                  icon: const Icon(Icons.restore),
                  label: const Text('重置所有设置'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blue[700],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildSliderTile({
    required IconData icon,
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required Function(double) onChanged,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: '${(value * 100).round()}%',
        onChanged: onChanged,
      ),
      trailing: Text('${(value * 100).round()}%'),
    );
  }

  Widget _buildIntervalTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required int currentInterval,
    required Function(int) onChanged,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text('每 ${currentInterval} 秒识别一次'),
      trailing: DropdownButton<int>(
        value: currentInterval,
        items: [1, 2, 3, 5].map((value) {
          return DropdownMenuItem<int>(
            value: value,
            child: Text('$value 秒'),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
      ),
    );
  }

  Widget _buildCropHeightTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required int currentHeight,
    required Function(int) onChanged,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text('屏蔽顶部 ${currentHeight} 像素'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: currentHeight > 0 
                ? () => onChanged(currentHeight - 10)
                : null,
          ),
          Text('$currentHeight'),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: currentHeight < 200 
                ? () => onChanged(currentHeight + 10)
                : null,
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('重置设置'),
          content: const Text('确定要重置所有设置到默认值吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                appState.setDarkMode(false);
                appState.setTranslationOpacity(0.9);
                appState.setCaptureInterval(2);
                appState.setTopCropHeight(0);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('设置已重置')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('重置'),
            ),
          ],
        );
      },
    );
  }
}
