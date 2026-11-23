import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../play_providers.dart';

/// 次元城登录弹窗（用户名 + 密码）。
///
/// 账号由站点管理，本应用只保存登录态；凭据不落盘、不上传。
class CycaniLoginDialog extends ConsumerStatefulWidget {
  const CycaniLoginDialog({super.key});

  /// 打开并等待结果；返回 true 表示登录成功。
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const CycaniLoginDialog(),
    );
    return result ?? false;
  }

  @override
  ConsumerState<CycaniLoginDialog> createState() => _CycaniLoginDialogState();
}

class _CycaniLoginDialogState extends ConsumerState<CycaniLoginDialog> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final username = _username.text.trim();
    final password = _password.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = '用户名和密码都要填');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(cycaniSessionProvider.notifier).login(username, password);
      // 登录前失败的线路请求会被缓存，这里清掉，让播放页重新取
      ref.invalidate(playLinesProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _friendly(Object error) {
    final text = '$error';
    if (text.contains('401')) return '用户名或密码不正确';
    if (text.contains('SocketException') || text.contains('timeout')) {
      return '网络不通，检查代理或稍后重试';
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('登录次元城'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _username,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '用户名',
                hintText: '注册时填的用户名',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: '密码'),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              '登录态只保存在本机（Windows 凭据管理器），不会上传或共享。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('登录'),
        ),
      ],
    );
  }
}
