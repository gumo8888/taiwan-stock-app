import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() => runApp(const TaiwanStockApp());

class TaiwanStockApp extends StatelessWidget {
  const TaiwanStockApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: const StockChartScreen(),
    );
  }
}

class StockChartScreen extends StatefulWidget {
  const StockChartScreen({Key? key}) : super(key: key);
  @override
  _StockChartScreenState createState() => _StockChartScreenState();
}

class _StockChartScreenState extends State<StockChartScreen> {
  // 嚴格遵循新版 webview_flutter 規範的控制器結構
  late final WebViewController _webViewController;
  bool _isDrawingMode = false;
  String _currentStockId = "2330";
  String _currentStockName = "台積電";

  final List<Map<String, String>> _stockList = [
    {"id": "2330", "name": "台積電"},
    {"id": "2454", "name": "聯發科"},
    {"id": "2317", "name": "鴻海"},
    {"id": "2603", "name": "長榮"},
    {"id": "2882", "name": "國泰金"},
  ];

  @override
  void initState() {
    super.initState();
    // 官方新版標準初始化流程，確保雲端編譯絕對不報錯
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _webViewController.runJavaScript("changeStock('$_currentStockId')");
          },
        ),
      )
      ..loadFlutterAsset('assets/chart.html');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("$_currentStockId $_currentStockName"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            onPressed: () => _webViewController.runJavaScript("clearAllLines()"),
          )
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF131722)),
              child: Center(child: Text("台股自選清單", style: TextStyle(fontSize: 18))),
            ),
            ..._stockList.map((stock) => ListTile(
              title: Text(stock['name']!),
              subtitle: Text(stock['id']!),
              selected: stock['id'] == _currentStockId,
              onTap: () {
                setState(() {
                  _currentStockId = stock['id']!;
                  _currentStockName = stock['name']!;
                  _isDrawingMode = false;
                });
                _webViewController.runJavaScript("changeStock('$_currentStockId')");
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: WebViewWidget(controller: _webViewController)),
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.black,
            child: SafeArea(
              child: Row(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isDrawingMode ? Colors.red : Colors.grey,
                    ),
                    onPressed: () {
                      setState(() { _isDrawingMode = !_isDrawingMode; });
                      _webViewController.runJavaScript(
                        "setDrawingMode($_isDrawingMode, 'line', '#d63031', 2, 'solid', 16)"
                      );
                    },
                    child: Text(_isDrawingMode ? "關閉畫線" : "開啟畫線"),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
