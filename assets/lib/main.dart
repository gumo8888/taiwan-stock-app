import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;

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
  late final WebViewController _webViewController;
  bool _isWebViewReady = false;
  bool _isDrawingMode = false;
  
  String _currentStockId = "2330";
  String _currentStockName = "台積電";

  // 1. 動態自選股清單（改為非 final，允許執行期動態新增變更）
  List<Map<String, String>> _stockList = [
    {"id": "2330", "name": "台積電"},
    {"id": "2454", "name": "聯發科"},
    {"id": "2317", "name": "鴻海"},
    {"id": "2603", "name": "長榮"},
    {"id": "2882", "name": "國泰金"},
  ];

  // 搜尋控制變數
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  
  String _currentMode = "line";      
  String _selectedColorHex = "#d63031"; 
  int _lineWidth = 2;               
  String _lineStyle = "solid";       
  double _textSize = 16.0;           

  @override
  void initState() {
    super.initState();
    _initWebView();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(onPageFinished: (url) {
          setState(() { _isWebViewReady = true; });
          _fetchHistoryKLines(_currentStockId);
        }),
      )
      ..loadFlutterAsset('assets/chart.html');
  }

  Future<void> _fetchHistoryKLines(String stockId) async {
    if (!_isWebViewReady) return;
    final currentYear = DateTime.now().year;
    final url = Uri.parse('https://finmindtrade.com');
    
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List data = json.decode(response.body)['data'];
        final formattedData = data.map((item) => {
          'time': item['date'], 'open': item['open'], 'high': item['max'], 'low': item['min'], 'close': item['close'],
        }).toList();
        _webViewController.runJavaScript("updateData('${json.encode(formattedData)}')");
      }
    } catch (e) {
      debugPrint("API 數據請求失敗: $e");
    }
  }

  // 2. 異步驗證並動態新增股票至清單中
  Future<void> _addNewStockFromSearch(String stockId) async {
    if (stockId.isEmpty) return;

    // 檢查是否已在清單中
    bool exists = _stockList.any((s) => s['id'] == stockId);
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("此股票已存在於自選清單中"), duration: Duration(seconds: 1)),
      );
      return;
    }

    // 呼叫 API 驗證該代號是否存在，順便撈取一名稱（FinMind API 預設回傳帶有名稱）
    final url = Uri.parse('https://finmindtrade.com');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List data = json.decode(response.body)['data'];
        if (data.isNotEmpty) {
          // 成功驗證，將新股寫入本地狀態記憶體
          setState(() {
            _stockList.add({"id": stockId, "name": "個股 $stockId"});
            _currentStockId = stockId;
            _currentStockName = "個股 $stockId";
            _isDrawingMode = false;
            _searchController.clear(); // 清空搜尋欄
            _searchQuery = "";
          });
          _syncDrawingConfig();
          _fetchHistoryKLines(stockId);
          Navigator.pop(context); // 關閉抽屜
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("成功新增台股 $stockId 至自選清單")),
          );
        } else {
          _showErrorDialog("找不到此台股代號，請檢查輸入是否正確。");
        }
      }
    } catch (e) {
      _showErrorDialog("網路請求失敗，請稍後再試。");
    }
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("提示"),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("確定"))],
      ),
    );
  }

  void _syncDrawingConfig() {
    _webViewController.runJavaScript(
      "setDrawingMode($_isDrawingMode, '$_currentMode', '$_selectedColorHex', $_lineWidth, '$_lineStyle', ${_textSize.toInt()})"
    );
  }

  @override
  Widget build(BuildContext context) {
    // 3. 即時過濾搜尋結果
    List<Map<String, String>> filteredList = _stockList.where((stock) {
      return stock['id']!.contains(_searchQuery) || stock['name']!.contains(_searchQuery);
    }).toList();

    // 判斷精準輸入的 4 位數代號是否不在現有自選中，若是則啟動「強制作業新增」按鈕
    bool isExactNewCode = _searchQuery.length >= 4 && !_stockList.any((s) => s['id'] == _searchQuery);

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
      
      // 升級版側邊智慧選股抽屜
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(top: 50, left: 16, right: 16, bottom: 16),
              color: const Color(0xFF131722),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("台股搜尋與自選", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  // 智慧搜尋輸入框
                  TextField(
                    controller: _searchController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: "輸入台股代號 (如: 2317)",
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty 
                        ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => _searchController.clear())
                        : null,
                      filled: true,
                      fillColor: Colors.black26,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
            
            // 4. 如果是全新股票代號，顯示動態「強制新增欄位」
            if (isExactNewCode)
              Container(
                color: Colors.blueGrey.withOpacity(0.3),
                child: ListTile(
                  leading: const Icon(Icons.add_circle, color: Colors.greenAccent),
                  title: Text("線上尋找並新增 \"$_searchQuery\""),
                  subtitle: const Text("點擊查詢台灣證券交易所數據並加入自選"),
                  onTap: () => _addNewStockFromSearch(_searchQuery),
                ),
              ),

            // 下方過濾清單
            Expanded(
              child: filteredList.isEmpty && !isExactNewCode
                ? const Center(child: Text("無符合的自選股票", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final stock = filteredList[index];
                      bool isCurrent = stock['id'] == _currentStockId;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCurrent ? Colors.redAccent : Colors.grey[800],
                          child: Text(stock['id']!.substring(0, 2), style: const TextStyle(fontSize: 12, color: Colors.white)),
                        ),
                        title: Text(stock['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(stock['id']!),
                        selected: isCurrent,
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              _stockList.removeWhere((s) => s['id'] == stock['id']);
                            });
                          },
                        ),
                        onTap: () {
                          setState(() {
                            _currentStockId = stock['id']!;
                            _currentStockName = stock['name']!;
                            _isDrawingMode = false;
                          });
                          _syncDrawingConfig();
                          _fetchHistoryKLines(_currentStockId);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          Expanded(child: WebViewWidget(controller: _webViewController)),
          // 下方控制面板（維持上一版完好程式碼不變...）
          Container(
            padding: const EdgeInsets.all(12.0),
            color: Colors.black,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _isDrawingMode ? Colors.red : Colors.grey),
                        onPressed: () {
                          setState(() { _isDrawingMode = !_isDrawingMode; });
                          _syncDrawingConfig();
                        },
                        child: Text(_isDrawingMode ? "關閉" : "開啟畫線"),
                      ),
                      const SizedBox(width: 8),
                      if (_isDrawingMode) ...[
                        _toolButton("line", Icons.linear_scale, "直線"),
                        _toolButton("arrow", Icons.trending_flat, "箭頭"),
                        _toolButton("text", Icons.text_fields, "文字註解"),
                      ]
                    ],
                  ),
                  if (_isDrawingMode) ...[
                    const Divider(color: Colors.grey),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text("粗細: ", style: TextStyle(fontSize: 12)),
                            _selectorItem<int>(1, "$_lineWidth", (val) => setState(() => _lineWidth = val)),
                            _selectorItem<int>(2, "$_lineWidth", (val) => setState(() => _lineWidth = val)),
                            _selectorItem<int>(3, "$_lineWidth", (val) => setState(() => _lineWidth = val)),
                          ],
                        ),
                        Row(
                          children: [
                            const Text("樣式: ", style: TextStyle(fontSize: 12)),
                            _selectorItem<String>("solid", _lineStyle, (val) => setState(() => _lineStyle = val), label: "實"),
                            _selectorItem<String>("dashed", _lineStyle, (val) => setState(() => _lineStyle = val), label: "虛"),
                            _selectorItem<String>("dotted", _lineStyle, (val) => setState(() => _lineStyle = val), label: "點"),
                          ],
                        ),
                      ],
                    ),
                    if (_currentMode == "text") ...[
                      Row(
                        children: [
                          const Text("新增字體: ", style: TextStyle(fontSize: 12)),
                          Expanded(
                            child: Slider(
                              value: _textSize,
                              min: 12.0, max: 28.0, divisions: 4,
                              label: "${_textSize.toInt()}px",
                              onChanged: (val) {
                                setState(() { _textSize = val; });
                                _syncDrawingConfig();
                              },
                            ),
                          ),
                        ],
                      )
                    ]
                  ],
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _toolButton(String mode, IconData icon, String label) {
    bool isSelected = _currentMode == mode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: isSelected,
        avatar: Icon(icon, size: 14),
        onSelected: (bool selected) {
          if (selected) {
            setState(() { _currentMode = mode; });
            _syncDrawingConfig();
          }
        },
      ),
    );
  }

  Widget _selectorItem<T>(T value, String currentSelectedStr, Function(T) onTap, {String? label}) {
    bool isSelected = value.toString() == currentSelectedStr;
    return GestureDetector(
      onTap: () {
        onTap(value);
        _syncDrawingConfig();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : Colors.grey,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label ?? value.toString(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
