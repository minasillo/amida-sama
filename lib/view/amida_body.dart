import 'dart:async';
import 'dart:ui' as ui;
import 'package:amidakuji_app/amidakuji_utils.dart';
import 'package:amidakuji_app/model/amida_lottery.dart';
import 'package:amidakuji_app/model/participant.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const double _kColumnSpacing = 60;
const double _kCanvasWidth = 1250;
const double _kCanvasHeight = 500;
const int _kMaxHorizontalLinesPerColumn = 7;

class AmidaBody extends StatefulWidget {
  const AmidaBody({
    required this.participantList,
    required this.wininngImagePath,
    required this.allowManualLines,
    super.key,
  });

  final String wininngImagePath;
  final List<Participant> participantList;
  final bool allowManualLines;

  @override
  State<AmidaBody> createState() => _AmidaBodyState();
}

class _AmidaBodyState extends State<AmidaBody>
    with SingleTickerProviderStateMixin {
  final Set<int> _selectedWinningIndices = {};
  List<HorizontalLine> _horizontalLines = [];
  late List<AmidaLottery> lotteryList;
  List<List<Offset>> _winningLinePaths = [];
  ui.Image? image;
  bool isShowButton = true;

  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _selectedWinningIndices.addAll(_defaultWinningIndices());
    _syncLotteryList();
    _horizontalLines = widget.allowManualLines
        ? []
        : _generateRandomHorizontalLines(widget.participantList.length);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final imageData = await _loadAssetImage(widget.wininngImagePath);
        if (mounted) {
          setState(() {
            image = imageData;
          });
        }
      } catch (e) {
        debugPrint('画像アセットの読み込みに失敗しました: $e');
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<int> _defaultWinningIndices() {
    if (widget.participantList.isEmpty) {
      return const [];
    }

    final count = widget.participantList.length > 2 ? 2 : widget.participantList.length;
    return List<int>.generate(count, (index) => index);
  }

  void _syncLotteryList() {
    lotteryList = List.generate(
      widget.participantList.length,
      (index) => _selectedWinningIndices.contains(index)
          ? AmidaLottery.win
          : AmidaLottery.lose,
    );
  }

  void _toggleWinning(int index) {
    if (!isShowButton) return;
    setState(() {
      if (_selectedWinningIndices.contains(index)) {
        _selectedWinningIndices.remove(index);
      } else {
        _selectedWinningIndices.add(index);
      }
      _syncLotteryList();
    });
  }

  void _handleCanvasTap(TapUpDetails details) {
    if (!widget.allowManualLines || !isShowButton) {
      return;
    }

    final local = details.localPosition;
    final x = local.dx.clamp(0.0, _kCanvasWidth);
    final y = local.dy.clamp(0.0, _kCanvasHeight);
    final columnIndex = (x / _kColumnSpacing).floor();
    final yFactor = (y / _kCanvasHeight).clamp(0.0, 1.0);

    if (columnIndex >= widget.participantList.length - 1) {
      return;
    }

    setState(() {
      final existingIndex = _horizontalLines.indexWhere(
        (line) =>
            line.startColomn == columnIndex &&
            (line.yPositionFactor - yFactor).abs() < 0.05,
      );

      if (existingIndex >= 0) {
        _horizontalLines.removeAt(existingIndex);
      } else {
        _horizontalLines.add(
          HorizontalLine(
            startColomn: columnIndex,
            endColumn: columnIndex + 1,
            yPositionFactor: yFactor,
          ),
        );
      }
    });
  }

  Future<ui.Image> _loadAssetImage(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(data.buffer.asUint8List(), completer.complete);
    return completer.future;
  }

  List<HorizontalLine> _generateRandomHorizontalLines(int columns) {
    const min = 1;
    const max = 20;
    final horizontalLinesList = <HorizontalLine>[];
    final prevYPositionFactors = <double>{};

    for (var i = 0; i < columns - 1; i++) {
      late double newYPositionFactor;
      final tempYPositionFactors = <double>{};
      do {
        newYPositionFactor = randomDecimalInRangeWithStep05(min, max);
        if (!prevYPositionFactors.contains(newYPositionFactor)) {
          tempYPositionFactors.add(newYPositionFactor);
        }
      } while (tempYPositionFactors.length < _kMaxHorizontalLinesPerColumn);

      prevYPositionFactors
        ..clear()
        ..addAll(tempYPositionFactors);

      horizontalLinesList.addAll(
        tempYPositionFactors.map(
          (y) => HorizontalLine(
            startColomn: i,
            endColumn: i + 1,
            yPositionFactor: y,
          ),
        ),
      );
    }

    return horizontalLinesList;
  }

  void _startAnimation() {
    _calculateWinningLinePaths();
    _animationController.forward();
  }

  void _calculateWinningLinePaths() {
    final paths = <List<Offset>>[];
    final winningIndices = [
      for (var i = 0; i < lotteryList.length; i++)
        if (lotteryList[i] == AmidaLottery.win) i,
    ];

    for (final winningIndex in winningIndices) {
      final path = <Offset>[];
      var currentX = winningIndex * _kColumnSpacing;
      var currentY = _kCanvasHeight;
      path.add(Offset(currentX, currentY));
      double? lastProcessedY;

      while (currentY > 0) {
        final availableLines = _horizontalLines.where((line) {
          final lineY = line.yPositionFactor * _kCanvasHeight;
          return lineY < currentY &&
              (lastProcessedY == null || lineY != lastProcessedY) &&
              (line.startColomn * _kColumnSpacing == currentX ||
                  line.endColumn * _kColumnSpacing == currentX);
        }).toList()
          ..sort(
            (a, b) => (b.yPositionFactor * _kCanvasHeight)
                .compareTo(a.yPositionFactor * _kCanvasHeight),
          );

        if (availableLines.isNotEmpty) {
          final nextLine = availableLines.first;
          currentY = nextLine.yPositionFactor * _kCanvasHeight;
          path.add(Offset(currentX, currentY));
          currentX = nextLine.startColomn * _kColumnSpacing == currentX
              ? nextLine.endColumn * _kColumnSpacing
              : nextLine.startColomn * _kColumnSpacing;
          path.add(Offset(currentX, currentY));
          lastProcessedY = currentY;
        } else {
          currentY = 0;
          path.add(Offset(currentX, currentY));
        }
      }

      paths.add(path);
    }

    setState(() {
      _winningLinePaths = paths;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight + 150),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: List.generate(
                        widget.participantList.length,
                        (index) => ChoiceChip(
                          label: Text('${index + 1}'),
                          selected: _selectedWinningIndices.contains(index),
                          onSelected: (_) => _toggleWinning(index),
                          selectedColor: Colors.red.withOpacity(0.25),
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(top: 32, left: 8, right: 8),
                    child: GestureDetector(
                      onTapUp: widget.allowManualLines && isShowButton
                          ? _handleCanvasTap
                          : null,
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) => CustomPaint(
                          size: const Size(_kCanvasWidth, _kCanvasHeight),
                          painter: AmidaPainter(
                            horizontalLines: _horizontalLines,
                            nameList: widget.participantList,
                            lotteryList: lotteryList,
                            winningLinePaths: _winningLinePaths,
                            image: image,
                            animationProgress: _animation.value,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                  if (isShowButton)
                    ElevatedButton(
                      onPressed: () {
                        _startAnimation();
                        setState(() => isShowButton = false);
                      },
                      child: const Text('結果を発表！'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HorizontalLine {
  const HorizontalLine({
    required this.startColomn,
    required this.endColumn,
    required this.yPositionFactor,
  });

  final int startColomn;
  final int endColumn;
  final double yPositionFactor;
}

class AmidaPainter extends CustomPainter {
  AmidaPainter({
    required this.horizontalLines,
    required this.nameList,
    required this.lotteryList,
    required this.winningLinePaths,
    required this.image,
    required this.animationProgress,
  });

  final List<HorizontalLine> horizontalLines;
  final List<Participant> nameList;
  final List<AmidaLottery> lotteryList;
  final List<List<Offset>> winningLinePaths;
  final ui.Image? image;
  final double animationProgress;

  static const _winningColors = [
    Colors.red,
    Colors.orange,
    Colors.blue,
    Colors.green,
    Colors.purple,
    Colors.pink,
    Colors.teal,
    Colors.amber,
    Colors.indigo,
    Colors.cyan,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.brown
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final columnCount = nameList.length;
    for (var i = 0; i < columnCount; i++) {
      final x = i * _kColumnSpacing;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);

      final nameTextPainter = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(text: '${nameList[i].lastName}\n'),
            TextSpan(text: nameList[i].firstName),
          ],
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      nameTextPainter.paint(
        canvas,
        Offset(x - nameTextPainter.width / 2, -nameTextPainter.height - 5),
      );

      if (lotteryList[i] == AmidaLottery.win && image != null) {
        final originalWidth = image!.width.toDouble();
        final originalHeight = image!.height.toDouble();
        final aspectRatio = originalWidth / originalHeight;
        const maxWidth = 50.0;
        const maxHeight = 50.0;
        final drawWidth = aspectRatio > 1 ? maxWidth : maxHeight * aspectRatio;
        final drawHeight = aspectRatio > 1 ? maxWidth / aspectRatio : maxHeight;

        canvas.drawImageRect(
          image!,
          Rect.fromLTWH(0, 0, originalWidth, originalHeight),
          Rect.fromLTWH(x - drawWidth / 2, size.height + 5, drawWidth, drawHeight),
          Paint(),
        );
      }
    }

    for (final line in horizontalLines) {
      final y = size.height * line.yPositionFactor;
      canvas.drawLine(
        Offset(line.startColomn * _kColumnSpacing, y),
        Offset(line.endColumn * _kColumnSpacing, y),
        paint,
      );
    }

    final pathCount = winningLinePaths.length;
    if (pathCount == 0) return;

    for (var pathIndex = 0; pathIndex < pathCount; pathIndex++) {
      final startProgress = pathIndex / pathCount;
      final endProgress = (pathIndex + 1) / pathCount;
      final pathProgress = ((animationProgress - startProgress) /
              (endProgress - startProgress))
          .clamp(0.0, 1.0);
      _paintPath(
        canvas,
        winningLinePaths[pathIndex],
        pathProgress,
        _winningColors[pathIndex % _winningColors.length],
      );
    }
  }

  void _paintPath(Canvas canvas, List<Offset> path, double progress, Color color) {
    if (path.length < 2 || progress <= 0) return;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;
    final segmentCount = path.length - 1;
    final scaledProgress = progress * segmentCount;
    final completedSegments = scaledProgress.floor().clamp(0, segmentCount);

    for (var i = 0; i < completedSegments; i++) {
      canvas.drawLine(path[i], path[i + 1], linePaint);
    }

    if (completedSegments < segmentCount) {
      final t = scaledProgress - completedSegments;
      final start = path[completedSegments];
      final end = path[completedSegments + 1];
      canvas.drawLine(
        start,
        Offset(
          start.dx + (end.dx - start.dx) * t,
          start.dy + (end.dy - start.dy) * t,
        ),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
