import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:easy_localization/easy_localization.dart';

class ChartsPage extends StatefulWidget {
  final double solPrice;
  final double dailyChange;
  final double weeklyChange;
  final double monthlyChange;

  const ChartsPage({
    super.key,
    required this.solPrice,
    required this.dailyChange,
    required this.weeklyChange,
    required this.monthlyChange,
  });

  @override
  State<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  String _selectedPeriod = '24H';

  final List<String> _periods = ['1H', '24H', '7D', '30D'];
  Timer? _updateTimer;
  bool _isLoading = false;
  double _currentPrice = 0.0;
  double _currentDailyChange = 0.0;
  double _currentWeeklyChange = 0.0;
  double _currentMonthlyChange = 0.0;
  List<Map<String, dynamic>> _realTimeData = [];
  DateTime _lastUpdate = DateTime.now();

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentPrice = widget.solPrice;
    _currentDailyChange = widget.dailyChange;
    _currentWeeklyChange = widget.weeklyChange;
    _currentMonthlyChange = widget.monthlyChange;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startRealTimeUpdates() {
    _updateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchRealTimeData();
    });
    _fetchRealTimeData();
  }

  Future<void> _fetchRealTimeData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://api.coingecko.com/api/v3/simple/price?ids=solana&vs_currencies=usd&include_24hr_change=true&include_7d_change=true&include_30d_change=true'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newPrice = data['solana']['usd'].toDouble();

        setState(() {
          _currentPrice = newPrice;
          _currentDailyChange = data['solana']['usd_24h_change']?.toDouble() ?? 0.0;
          _currentWeeklyChange = data['solana']['usd_7d_change']?.toDouble() ?? 0.0;
          _currentMonthlyChange = data['solana']['usd_30d_change']?.toDouble() ?? 0.0;
          _lastUpdate = DateTime.now();

          _realTimeData.add({
            'price': newPrice,
            'timestamp': DateTime.now(),
          });

          if (_realTimeData.length > 100) {
            _realTimeData.removeAt(0);
          }
        });

        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }

        _animationController.reset();
        _animationController.forward();
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Real-time data fetch error: $e');
      setState(() {
        _realTimeData.add({
          'price': _currentPrice,
          'timestamp': DateTime.now(),
        });
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  String _getLastUpdateTime() {
    final now = DateTime.now();
    final difference = now.difference(_lastUpdate);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds} saniye önce güncellendi';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dakika önce güncellendi';
    } else {
      return '${difference.inHours} saat önce güncellendi';
    }
  }

  List<double> _generateChartData() {
    if (_realTimeData.isNotEmpty && _selectedPeriod == '1H') {
      return _realTimeData.map((e) => e['price'] as double).toList();
    }

    final random = Random();
    final basePrice = _currentPrice;
    final change = _getChangeForPeriod();

    List<double> data = [];
    int dataPoints = _getDataPointsForPeriod();

    for (int i = 0; i < dataPoints; i++) {
      final progress = i / (dataPoints - 1);
      final trend = basePrice * (1 + (change / 100) * progress);
      final noise = (random.nextDouble() - 0.5) * basePrice * 0.02;
      data.add(trend + noise);
    }
    return data;
  }

  int _getDataPointsForPeriod() {
    switch (_selectedPeriod) {
      case '1H':
        return _realTimeData.length;
      case '24H':
        return 24;
      case '7D':
        return 7;
      case '30D':
        return 30;
      default:
        return 24;
    }
  }

  double _getChangeForPeriod() {
    switch (_selectedPeriod) {
      case '1H':
      case '24H':
        return _currentDailyChange;
      case '7D':
        return _currentWeeklyChange;
      case '30D':
        return _currentMonthlyChange;
      default:
        return _currentDailyChange;
    }
  }

  Widget _buildGlassCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFF6B35).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: _periods.map((period) {
        final isSelected = period == _selectedPeriod;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedPeriod = period;
              });
              _animationController.reset();
              _animationController.forward();
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFF6B35)
                    : (isDark ? Colors.black : Colors.white).withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFFF6B35)
                      : const Color(0xFFFF6B35).withOpacity(0.2),
                ),
              ),
              child: Text(
                period,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChart() {
    final data = _generateChartData();
    if (data.isEmpty) {
      return Center(
        child: Text(''),
      );
    }

    final maxValue = data.reduce(max);
    final minValue = data.reduce(min);
    final isPositive = _getChangeForPeriod() >= 0;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: 250,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: Container(
              width: data.length * 15.0,
              child: CustomPaint(
                size: Size(data.length * 15.0, 250),
                painter: ChartPainter(
                  data: data,
                  maxValue: maxValue,
                  minValue: minValue,
                  progress: _animation.value,
                  isPositive: isPositive,
                  showPrices: _selectedPeriod == '1H',
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                const Spacer(),
                Icon(
                  _getChangeForPeriod() >= 0 ? Icons.trending_up : Icons.trending_down,
                  color: _getChangeForPeriod() >= 0 ? Colors.green : Colors.red,
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: (isDark ? Colors.white : Colors.black87).withOpacity(0.8),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: (isDark ? Colors.white : Colors.black87).withOpacity(0.6),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final change = _getChangeForPeriod();
    final isPositive = change >= 0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'charts'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: (isDark ? Colors.black : Colors.white).withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFF6B35).withOpacity(0.3),
              ),
            ),
            child: IconButton(
              onPressed: _isLoading ? null : _fetchRealTimeData,
              icon: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                ),
              )
                  : const Icon(
                Icons.refresh,
                color: Color(0xFFFF6B35),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
              const Color(0xFF000000),
              const Color(0xFF1A1A1A),
              const Color(0xFF2D1810),
            ]
                : [
              Colors.grey[50]!,
              Colors.grey[100]!,
              const Color(0xFFFFF5F0),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                _buildGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B35).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.show_chart,
                                color: Color(0xFFFF6B35),
                                size: 24,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _isLoading ? Colors.orange : Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isLoading ? 'Güncelleniyor...' : 'Canlı',
                                    style: TextStyle(
                                      color: _isLoading ? Colors.orange : Colors.green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: (isPositive ? Colors.green : Colors.red).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPositive ? Icons.trending_up : Icons.trending_down,
                                    color: isPositive ? Colors.green : Colors.red,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${isPositive ? '+' : ''}${change.toStringAsFixed(2)}%',
                                    style: TextStyle(
                                      color: isPositive ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '\$${_currentPrice.toStringAsFixed(4)}',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              '${'sol'}/${'usd'}',
                              style: TextStyle(
                                color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _getLastUpdateTime(),
                              style: TextStyle(
                                color: (isDark ? Colors.white : Colors.black87).withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                _buildPeriodSelector(),

                const SizedBox(height: 24),

                _buildGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Fiyat Hareketi ($_selectedPeriod)',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            if (_selectedPeriod == '1H')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Kaydırılabilir',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildChart(),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: 'En Yüksek',
                        value: '\$${(_currentPrice * 1.05).toStringAsFixed(2)}',
                        subtitle: _selectedPeriod,
                        icon: Icons.keyboard_arrow_up,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        title: 'En Düşük',
                        value: '\$${(_currentPrice * 0.95).toStringAsFixed(2)}',
                        subtitle: _selectedPeriod,
                        icon: Icons.keyboard_arrow_down,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: 'Ortalama',
                        value: '\$${_currentPrice.toStringAsFixed(2)}',
                        subtitle: _selectedPeriod,
                        icon: Icons.remove,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Volatilite',
                        value: '${(change.abs() * 0.8).toStringAsFixed(1)}%',
                        subtitle: _selectedPeriod,
                        icon: Icons.show_chart,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                _buildGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.data_usage,
                            color: Colors.purple,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Veri Noktaları',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_realTimeData.length} canlı veri noktası',
                                style: TextStyle(
                                  color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '10s güncelleme',
                            style: TextStyle(
                              color: Colors.purple,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChartPainter extends CustomPainter {
  final List<double> data;
  final double maxValue;
  final double minValue;
  final double progress;
  final bool isPositive;
  final bool showPrices;

  ChartPainter({
    required this.data,
    required this.maxValue,
    required this.minValue,
    required this.progress,
    required this.isPositive,
    this.showPrices = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = isPositive ? Colors.green : Colors.red
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          (isPositive ? Colors.green : Colors.red).withOpacity(0.3),
          (isPositive ? Colors.green : Colors.red).withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    final range = maxValue - minValue;
    if (range == 0) return;

    final stepX = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - ((data[i] - minValue) / range) * size.height;

      if (x.isNaN || y.isNaN || x.isInfinite || y.isInfinite) continue;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      if (i / (data.length - 1) > progress) break;
    }

    final lastIndex = (data.length * progress).floor();
    if (lastIndex > 0 && lastIndex < data.length) {
      final lastX = lastIndex * stepX;
      fillPath.lineTo(lastX, size.height);
    }
    fillPath.close();

    canvas.drawPath(fillPath, gradientPaint);

    canvas.drawPath(path, paint);

    final dotPaint = Paint()
      ..color = isPositive ? Colors.green : Colors.red
      ..style = PaintingStyle.fill;

    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 8,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(
          color: Colors.black.withOpacity(0.8),
          offset: const Offset(1, 1),
          blurRadius: 2,
        ),
      ],
    );

    for (int i = 0; i < data.length; i++) {
      if (i / (data.length - 1) > progress) break;

      final x = i * stepX;
      final y = size.height - ((data[i] - minValue) / range) * size.height;

      if (x.isNaN || y.isNaN || x.isInfinite || y.isInfinite) continue;

      if (i % 3 == 0) {
        canvas.drawCircle(Offset(x, y), 2.5, dotPaint);
      }

      if (showPrices && i % 5 == 0) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: '\$${data[i].toStringAsFixed(2)}',
            style: textStyle,
          ),
        );
        textPainter.layout();

        final textX = x - textPainter.width / 2;
        final textY = y - textPainter.height - 8;

        if (textX >= 0 && textX + textPainter.width <= size.width && textY >= 0) {
          textPainter.paint(canvas, Offset(textX, textY));
        }
      }
    }

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 4; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (int i = 0; i <= 4; i++) {
      final x = (size.width / 4) * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
