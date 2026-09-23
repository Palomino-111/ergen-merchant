import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'state.dart';

class WebViewLogic extends GetxController {
  final WebViewState state = WebViewState();

  @override
  void onInit() {
    super.onInit();
  }

  void initWebEngin(BuildContext context) {
    // #docregion platform_features
    // 根据不同的WebView引擎设置对应的WebView引擎的参数
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);
    // #enddocregion platform_features

    controller

      // 允许加载JS
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          // TODO 进度条
          onProgress: (int progress) {
            debugPrint('WebView is loading (progress : $progress%)');
          },

          // TODO URL拦截，应用内打开和第三方应用打开
          onPageStarted: (String url) {
            debugPrint('Page started loading: $url');
          },
          onPageFinished: (String url) {
            debugPrint('Page finished loading: $url');
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('''
Page resource error:
  code: ${error.errorCode}
  description: ${error.description}
  errorType: ${error.errorType}
  isForMainFrame: ${error.isForMainFrame}
          ''');
          },

          // TODO URL拦截，应用内打开和第三方应用打开
          onNavigationRequest: (NavigationRequest request) {
            // if (request.url.startsWith('https://www.xxx.com/')) {
            //   debugPrint('blocking navigation to ${request.url}');
            //   return NavigationDecision.prevent;
            // }
            debugPrint('allowing navigation to ${request.url}');
            return NavigationDecision.navigate;
          },

          // TODO HTTP错误处理
          onHttpError: (HttpResponseError error) {
            debugPrint('Error occurred on page: ${error.response?.statusCode}');
          },

          // TODO URL拦截，应用内打开和第三方应用打开
          onUrlChange: (UrlChange change) {
            debugPrint('url change to ${change.url}');
          },

          // Web页面需要身份验证时调用，好像没什么作用
          onHttpAuthRequest: (HttpAuthRequest request) {},
        ),
      )

      // TODO 注入JS对象，让JS可以调用Native
      ..addJavaScriptChannel(
        'Toaster',
        onMessageReceived: (JavaScriptMessage message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message.message)),
          );
        },
      )

      // web console 的输出，一般没必要打开，要调试时才打开
      // ..setOnConsoleMessage(
      //   (JavaScriptConsoleMessage consoleMessage) {
      //     debugPrint(
      //         '== JS == ${consoleMessage.level.name}: ${consoleMessage.message}');
      //   },
      // )
      // 如果URL异常就默认访问官网
      ..loadRequest(Uri.parse('http://www.flomozzr.com/dist'));

    // setBackgroundColor is not currently supported on macOS.
    if (kIsWeb || !Platform.isMacOS) {
      // 这个配置好像不管用
      controller.setBackgroundColor(const Color(0x80000000));
    }

    // #docregion platform_features
    // 仅Android配置
    if (controller.platform is AndroidWebViewController) {
      // 关闭WebView调试摸索
      AndroidWebViewController.enableDebugging(false);

      // 媒体播放需要用户手上
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(true);
    }
    // #enddocregion platform_features

    state.webViewController = controller;
  }
}
