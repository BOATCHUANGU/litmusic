import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../providers/bilibili_provider.dart';

class BilibiliLoginPage extends StatefulWidget {
  const BilibiliLoginPage({super.key});

  @override
  State<BilibiliLoginPage> createState() => _BilibiliLoginPageState();
}

class _BilibiliLoginPageState extends State<BilibiliLoginPage> {
  InAppWebViewController? _webController;
  bool _isLoading = true;
  double _progress = 0;
  String? _error;

  static const _loginUrl = 'https://passport.bilibili.com/login';

  @override
  void dispose() {
    _webController?.dispose();
    super.dispose();
  }

  Future<void> _checkCookies() async {
    try {
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri('https://.bilibili.com'),
      );

      String? sessdata, biliJct, dedeUserId, dedeUserIdCkMd5, sid;
      for (final cookie in cookies) {
        if (cookie.name == 'SESSDATA') sessdata = cookie.value;
        if (cookie.name == 'bili_jct') biliJct = cookie.value;
        if (cookie.name == 'DedeUserID') dedeUserId = cookie.value;
        if (cookie.name == 'DedeUserID__ckMd5') dedeUserIdCkMd5 = cookie.value;
        if (cookie.name == 'sid') sid = cookie.value;
      }

      if (sessdata != null &&
          sessdata.isNotEmpty &&
          biliJct != null &&
          biliJct.isNotEmpty &&
          dedeUserId != null &&
          dedeUserId.isNotEmpty) {
        // Login success — save cookies and verify
        if (!mounted) return;
        final bili = context.read<BilibiliProvider>();
        await bili.onWebViewLoginSuccess(
          sessdata: sessdata,
          biliJct: biliJct,
          dedeUserId: dedeUserId,
          dedeUserIdCkMd5: dedeUserIdCkMd5,
          sid: sid,
        );
        if (mounted) Navigator.pop(context, true);
      }
    } catch (_) {
      // Ignore cookie check errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: const Text('Bilibili登录',
            style: TextStyle(color: Colors.white)),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_progress > 0 && _progress < 1)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.white10,
              color: Theme.of(context).colorScheme.primary,
            ),
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade900,
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(_loginUrl),
              ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                userAgent:
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              ),
              onWebViewCreated: (controller) {
                _webController = controller;
              },
              onLoadStart: (controller, url) {
                setState(() => _isLoading = true);
              },
              onLoadStop: (controller, url) async {
                setState(() => _isLoading = false);
                // Check cookies after a short delay for them to settle
                await Future.delayed(const Duration(seconds: 1));
                await _checkCookies();
              },
              onProgressChanged: (controller, progress) {
                setState(() => _progress = progress / 100.0);
              },
              onReceivedError: (controller, request, error) {
                setState(() {
                  _isLoading = false;
                  _error = '加载失败: ${error.description}';
                });
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF1a1a2e),
            child: const Text(
              '请在网页中输入Bilibili账号和密码进行登录\n登录成功后会自动返回',
              style: TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
