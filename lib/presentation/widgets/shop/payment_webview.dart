import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/djassa_theme.dart'; // Assurez-vous que ce chemin est correct

const String _paymentReturnUrl =
    'https://wtfygkiuzjmndnirtevy.supabase.co/functions/v1/payment-return';

typedef PaymentStatusChecker = Future<String?> Function(String reference);

class PaymentWebView extends StatefulWidget {
  const PaymentWebView({
    super.key,
    required this.paymentUrl,
    required this.reference,
    this.checkStatus,
    this.onPaymentComplete,
    this.onPaymentSuccess,
    this.onPaymentFailed,
  });

  final String paymentUrl;
  final String reference;
  final PaymentStatusChecker? checkStatus;
  final VoidCallback? onPaymentComplete;
  final VoidCallback? onPaymentSuccess;
  final VoidCallback? onPaymentFailed;

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController _controller;

  bool _isLoading = true;
  bool _paymentProcessed = false;
  bool _confirmingSuccess = false;
  String? _error;

  Timer? _pollingTimer;
  int _pollCount = 0;
  String? _detectedReference;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    if (!widget.paymentUrl.startsWith('http')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _error = 'URL de paiement invalide';
            _isLoading = false;
          });
        }
      });
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(DjassaTheme.backgroundPrimary)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10; DjassaApp) AppleWebKit/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _isLoading = false);
            _detectCallback(url);
          },
          onUrlChange: (change) {
            if (change.url != null) _detectCallback(change.url!);
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _error = error.description;
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));

    _startPolling();
  }

  void _detectCallback(String url) {
    if (_paymentProcessed) return;

    final uri = Uri.tryParse(url);
    final urlReference = uri?.queryParameters['reference'] ??
        uri?.queryParameters['transaction_id'] ??
        uri?.queryParameters['payment_reference'];
    if (urlReference != null && urlReference.isNotEmpty) {
      _detectedReference = urlReference;
    }

    if (url.contains('djassaapp://payment-callback')) {
      _handleResult(uri?.queryParameters['status']);
      return;
    }

    if (_isSuccessUrl(url)) {
      _handleResult('completed');
      return;
    }

    if (_isErrorUrl(url)) {
      _handleResult('failed');
      return;
    }

    final statusParam = uri?.queryParameters['status'];
    if (statusParam != null) {
      _handleResult(statusParam);
    }
  }

  bool _isSuccessUrl(String url) =>
      url.contains('/success') ||
      url.contains('/paiement/succes') ||
      url.contains('status=success') ||
      url.contains('payment=success') ||
      url.contains('payment_status=success');

  bool _isErrorUrl(String url) =>
      url.contains('/failed') ||
      url.contains('/error') ||
      url.contains('/cancelled') ||
      url.contains('/paiement/echec') ||
      url.contains('status=failed') ||
      url.contains('status=cancelled') ||
      url.contains('payment=failed') ||
      url.contains('payment=cancelled');

  void _handleResult(String? status) {
    if (_paymentProcessed) return;

    final lowerStatus = status?.toLowerCase();
    switch (lowerStatus) {
      case 'completed':
      case 'success':
      case 'paid':
        _confirmSuccess();
        break;
      case 'failed':
      case 'error':
      case 'cancelled':
      case 'expired':
        _onFailed();
        break;
      default:
        // Si le statut est null ou inconnu (ex: "pending"), on ne fait rien.
        // Le Timer continuera de poller jusqu'à la limite maximale.
        debugPrint('⏳ Statut de paiement en attente ou inconnu : $lowerStatus');
        break;
    }
  }

  void _startPolling() {
    final checker = widget.checkStatus;
    if (checker == null || widget.reference.isEmpty) return;

    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_paymentProcessed) {
        timer.cancel();
        return;
      }

      _pollCount++;
      // 40 tentatives * 5 secondes = 200 secondes (3 minutes 20 secondes)
      // C'est une durée largement suffisante pour un paiement mobile.
      if (_pollCount > 40) {
        debugPrint('⏰ Délai d\'attente du paiement dépassé (40 tentatives).');
        timer.cancel();
        _onFailed(); // ✅ CORRECTION CRUCIALE : On échoue proprement au lieu de laisser l'écran bloqué
        return;
      }

      try {
        final status = await checker(widget.reference);
        _handleResult(status);
      } catch (e) {
        debugPrint('❌ Erreur lors du polling : $e');
        // On ignore l'erreur réseau et on réessaiera au prochain tick du timer
      }
    });
  }

  Future<void> _confirmSuccess() async {
    if (_paymentProcessed || _confirmingSuccess) return;

    final checker = widget.checkStatus;
    if (checker == null || widget.reference.isEmpty) {
      _onSuccess();
      return;
    }

    _confirmingSuccess = true;
    try {
      final reference = _detectedReference?.isNotEmpty == true
          ? _detectedReference!
          : widget.reference;
          
      await _notifyPaymentReturn(reference);
      
      final status = (await checker(reference))?.toLowerCase();
      switch (status) {
        case 'completed':
        case 'success':
        case 'paid':
          _onSuccess();
          break;
        case 'failed':
        case 'error':
        case 'cancelled':
        case 'expired':
          _onFailed();
          break;
        default:
          // Si toujours incertain après la redirection, on annule la confirmation et on laisse le timer continuer
          _confirmingSuccess = false;
          debugPrint('⚠️ Confirmation de succès inconclusive, le polling continue.');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la confirmation de succès : $e');
      _confirmingSuccess = false;
    }
  }

  Future<void> _notifyPaymentReturn(String reference) async {
    if (reference.isEmpty) return;

    final uri = Uri.parse(_paymentReturnUrl).replace(
      queryParameters: {
        'status': 'success',
        'reference': reference,
      },
    );

    try {
      await http.get(uri).timeout(const Duration(seconds: 8));
    } catch (_) {
      // On ignore les erreurs ici, le polling reste la source de vérité.
    }
  }

  void _onSuccess() {
    if (_paymentProcessed) return;
    _paymentProcessed = true;
    _pollingTimer?.cancel();
    widget.onPaymentSuccess?.call();
    widget.onPaymentComplete?.call();
    if (mounted) Navigator.of(context).pop(true);
  }

  void _onFailed() {
    if (_paymentProcessed) return;
    _paymentProcessed = true;
    _pollingTimer?.cancel();
    widget.onPaymentFailed?.call();
    widget.onPaymentComplete?.call();
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DjassaTheme.backgroundSecondary,
      appBar: AppBar(
        backgroundColor: DjassaTheme.backgroundSecondary,
        title: const Text('Paiement sécurisé'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              if (_error != null) {
                setState(() {
                  _error = null;
                  _isLoading = true;
                });
              }
              _controller.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_error == null) WebViewWidget(controller: _controller),
          if (_isLoading && _error == null)
            Container(
              color: DjassaTheme.backgroundSecondary.withValues(alpha: 0.85),
              child: const Center(
                child: CircularProgressIndicator(
                  color: DjassaTheme.accentOrange,
                ),
              ),
            ),
          if (_error != null)
            Container(
              color: DjassaTheme.backgroundSecondary,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    'Connexion instable',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: DjassaTheme.accentOrange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Réessayer'),
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _isLoading = true;
                      });
                      _controller.reload();
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
