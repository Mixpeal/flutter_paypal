library flutter_paypal;

import 'dart:async';
import 'dart:core';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:webview_flutter_x5/webview_flutter.dart';

import 'src/PaypalServices.dart';
import 'src/errors/network_error.dart';

class UsePaypal extends StatefulWidget {
  final Function onFinish, onError;
  final String returnURL, cancelURL, note, clientId, secretKey;
  final List transactions;
  final bool sandboxMode;
  const UsePaypal({
    Key? key,
    required this.onFinish,
    required this.onError,
    required this.returnURL,
    required this.cancelURL,
    required this.transactions,
    required this.clientId,
    required this.secretKey,
    this.sandboxMode = false,
    this.note = '',
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return UsePaypalState();
  }
}

class UsePaypalState extends State<UsePaypal> {
  final Completer<WebViewController> _controller =
      Completer<WebViewController>();
  String checkoutUrl = '';
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  String navUrl = 'https://www.api.paypal.com';
  String executeUrl = '';
  String accessToken = '';
  bool loading = true;
  bool pageloading = true;
  bool loadingError = false;
  late PaypalServices services;
  int pressed = 0;

  Map getOrderParams() {
    Map<String, dynamic> temp = {
      "intent": "sale",
      "payer": {"payment_method": "paypal"},
      "transactions": widget.transactions,
      "note_to_payer": widget.note,
      "redirect_urls": {
        "return_url": widget.returnURL,
        "cancel_url": widget.cancelURL
      }
    };
    return temp;
  }

  loadPayment() async {
    setState(() {
      loading = true;
    });
    try {
      Map getToken = await services.getAccessToken();
      if (getToken['token'] != null) {
        accessToken = getToken['token'];
        final transactions = getOrderParams();
        final res =
            await services.createPaypalPayment(transactions, accessToken);
        if (res["approvalUrl"] != null) {
          setState(() {
            checkoutUrl = res["approvalUrl"].toString();
            navUrl = res["approvalUrl"].toString();
            executeUrl = res["executeUrl"].toString();
            loading = false;
            pageloading = false;
            loadingError = false;
          });
        } else {
          if (res['details'][0] != null && res['details'][0]['issue'] != null) {
            widget.onError("${res['details'][0]['issue']}");
          } else {
            widget.onError("Unable to proceed payment, please try again.");
          }
          setState(() {
            loading = false;
            pageloading = false;
            loadingError = true;
          });
        }
      } else {
        widget.onError("${getToken['message']}");

        setState(() {
          loading = false;
          pageloading = false;
          loadingError = true;
        });
      }
    } catch (e) {
      widget.onError(e);
      setState(() {
        loading = false;
        pageloading = false;
        loadingError = true;
      });
    }
  }

  JavascriptChannel _toasterJavascriptChannel(BuildContext context) {
    return JavascriptChannel(
        name: 'Toaster',
        onMessageReceived: (JavascriptMessage message) {
          widget.onError(message.message);
        });
  }

  @override
  void initState() {
    super.initState();
    services = PaypalServices(
      sandboxMode: widget.sandboxMode,
      clientId: widget.clientId,
      secretKey: widget.secretKey,
    );
    // Enable hybrid composition.
    if (Platform.isAndroid) WebView.platform = SurfaceAndroidWebView();
    loadPayment();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (pressed < 2) {
          setState(() {
            pressed++;
          });
          final snackBar = SnackBar(
              content: Text(
                  'Press back ${3 - pressed} more times to cancel transaction'));
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
          return false;
        } else {
          return true;
        }
      },
      child: Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF272727),
            leading: GestureDetector(
              child: const Icon(Icons.arrow_back_ios),
              onTap: () => Navigator.pop(context),
            ),
            title: Row(
              children: [
                Expanded(
                    child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        color: Uri.parse(navUrl).hasScheme
                            ? Colors.green
                            : Colors.blue,
                        size: 18,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          navUrl,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      SizedBox(width: pageloading ? 5 : 0),
                      pageloading
                          ? const SpinKitFadingCube(
                              color: Color(0xFFEB920D),
                              size: 10.0,
                            )
                          : const SizedBox()
                    ],
                  ),
                ))
              ],
            ),
            elevation: 0,
          ),
          body: SizedBox(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            child: loading
                ? Column(
                    children: const [
                      Expanded(
                        child: Center(
                          child: SpinKitFadingCube(
                            color: Color(0xFFEB920D),
                            size: 30.0,
                          ),
                        ),
                      ),
                    ],
                  )
                : loadingError
                    ? Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: NetworkError(
                                  loadData: loadPayment,
                                  message: "Network error,"),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: WebView(
                              initialUrl: checkoutUrl,
                              javascriptMode: JavascriptMode.unrestricted,
                              gestureNavigationEnabled: true,
                              onWebViewCreated:
                                  (WebViewController webViewController) {
                                _controller.complete(webViewController);
                              },
                              javascriptChannels: <JavascriptChannel>[
                                _toasterJavascriptChannel(context),
                              ].toSet(),
                              navigationDelegate:
                                  (NavigationRequest request) async {
                                if (request.url
                                    .startsWith('https://www.youtube.com/')) {
                                  return NavigationDecision.prevent;
                                }

                                if (request.url.contains(widget.returnURL)) {
                                  setState(() {
                                    navUrl = widget.returnURL;
                                  });
                                  final uri = Uri.parse(request.url);
                                  final payerID =
                                      uri.queryParameters['PayerID'];
                                  if (payerID != null) {
                                    Map params = {
                                      "payerID": payerID,
                                      "paymentId":
                                          uri.queryParameters['paymentId'],
                                      "token": uri.queryParameters['token'],
                                    };
                                    setState(() {
                                      loading = true;
                                    });
                                    await widget.onFinish(params);
                                    setState(() {
                                      loading = false;
                                    });
                                    return NavigationDecision.prevent;
                                  } else {
                                    Navigator.of(context).pop();
                                  }
                                }
                                if (request.url.contains(widget.cancelURL)) {
                                  Navigator.of(context).pop();
                                }
                                return NavigationDecision.navigate;
                              },
                              onPageStarted: (String url) {
                                setState(() {
                                  pageloading = true;
                                  loadingError = false;
                                });
                              },
                              onPageFinished: (String url) {
                                setState(() {
                                  navUrl = url;
                                  pageloading = false;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
          )),
    );
  }
}
