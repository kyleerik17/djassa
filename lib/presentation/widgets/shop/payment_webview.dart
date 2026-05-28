import 'dart:async';
import 'package:flutter/material.dart';
// ✅ Import correct pour webview_flutter ^4.0.0
import 'package:webview_flutter/webview_flutter.dart';
import 'package:app_links/app_links.dart';

class PaymentWebView extends StatefulWidget {
  const PaymentWebView({
    super.key,
    required this.paymentUrl,
    required this.reference,
    this.onPaymentComplete,
    this.onPaymentSuccess,
    this.onPaymentFailed,
  });

  final String paymentUrl;
  final String reference;
  final VoidCallback? onPaymentComplete;
  final VoidCallback? onPaymentSuccess;
  final VoidCallback? onPaymentFailed;

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _error;
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  bool _paymentProcessed = false;

  @override
  void initState() {
    super.initState();
    
    // ✅ Initialisation Android : Hybrid Composition (optionnel avec webview_flutter 4.7+)
    // WebView.platform = SurfaceAndroidWebView(); // Décommenter si problèmes d'affichage Android
    
    _initWebView();
    _initDeepLinks();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10; DjassaApp) AppleWebKit/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _isLoading = false);
            _checkUrlForCompletion(url);
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() => _error = error.description);
            }
          },
          onUrlChange: (url) {
            _checkUrlForCompletion(url.url);
          },
        ),
      )
      ..addJavaScriptChannel(
        'PaymentCallback',
        onMessageReceived: (message) {
          _handlePaymentResult(message.message);
        },
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    // Écouter les deep links (retour après paiement)
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme == 'djassaapp' && uri.host == 'payment-callback') {
        final status = uri.queryParameters['status'];
        _handleDeepLinkResult(status);
      }
    });
  }

  void _checkUrlForCompletion(String? url) {
    if (url == null || _paymentProcessed) return;

    // Détecter les URLs de retour GeniusPay
    if (url.contains('djassaapp://payment-callback')) {
      final uri = Uri.parse(url);
      final status = uri.queryParameters['status'];
      _handleDeepLinkResult(status);
    } else if (url.contains('status=success') || url.contains('payment=success')) {
      _handlePaymentResult('success');
    } else if (url.contains('status=failed') || url.contains('payment=failed')) {
      _handlePaymentResult('failed');
    } else if (url.contains('status=cancelled') || url.contains('payment=cancelled')) {
      _handlePaymentResult('cancelled');
    }
  }

  void _handleDeepLinkResult(String? status) {
    if (_paymentProcessed) return;
    _paymentProcessed = true;

    switch (status) {
      case 'success':
      case 'completed':
        _onSuccess();
        break;
      case 'failed':
      case 'error':
      case 'cancelled':
        _onFailed();
        break;
      default:
        _pollPaymentStatus();
    }
  }

  void _handlePaymentResult(String result) {
    if (_paymentProcessed) return;
    _paymentProcessed = true;

    switch (result.toLowerCase()) {
      case 'success':
      case 'completed':
      case 'paid':
        _onSuccess();
        break;
      case 'failed':
      case 'error':
      case 'cancelled':
        _onFailed();
        break;
      default:
        _pollPaymentStatus();
    }
  }

  Future<void> _pollPaymentStatus() async {
    // Polling de secours : vérifier le statut en DB
    for (int i = 0; i < 6; i++) {
      await Future.delayed(const Duration(seconds: 5));
      
      // TODO: Appeler ton service pour vérifier le statut
      // final status = await GeniusPayService(...).checkPaymentStatus(widget.reference);
      // if (status == 'completed') { _onSuccess(); return; }
      // if (status == 'failed' || status == 'cancelled') { _onFailed(); return; }
    }
    
    widget.onPaymentComplete?.call();
  }

  void _onSuccess() {
    widget.onPaymentSuccess?.call();
    widget.onPaymentComplete?.call();
    if (mounted) Navigator.of(context).pop(true);
  }

  void _onFailed() {
    widget.onPaymentFailed?.call();
    widget.onPaymentComplete?.call();
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement sécurisé'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: Stack(
        children: [
          // ✅ WebViewWidget est le widget correct pour webview_flutter ^4.0.0
          WebViewWidget(controller: _controller),
          
          // Loader
          if (_isLoading)
            Container(
              color: Colors.black12,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          
          // Message d'erreur
          if (_error != null)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: Theme.of(context).colorScheme.error,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Une erreur est survenue',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _controller.reload(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}