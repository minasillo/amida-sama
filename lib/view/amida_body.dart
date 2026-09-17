import 'dart:async';
import 'dart:ui' as ui;
import 'package:amidakuji_app/amidakuji_utils.dart';
import 'package:amidakuji_app/model/amida_lottery.dart';
import 'package:amidakuji_app/model/participant.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// あみだのスペース
const double _kColumnSpacing = 60;

// キャンバスのサイズ
const double _kCanvasWidth = 1250;
const double _kCanvasHeight = 500;

// カラムスペース間の横線の数のMAX値
const int _kMaxHorizontalLinesPerColumn = 7;

class AmidaBody extends StatefulWidget {
  const AmidaBody({
    required this.participantList,
    required this.wininngImagePath,
    super.key,
  });

  final String wininngImagePath;
  final List<Participant> participantList;

  @override
  State<AmidaBody> createState() => _AmidaBodyState();
}

class _AmidaBodyState extends State<AmidaBody>
    with SingleTickerProviderStateMixin {
  List<HorizontalLine> _horizontalLines = [];
  late List<AmidaLottery> lotteryList = [
    // 当たりは2つだけ
    AmidaLottery.win,
    AmidaLottery.win,
    ...List.generate(
      widget.participantList.length - 2,
      (_) => AmidaLottery.lose,
    ),
  ]..shuffle();
  List<List<Offset>> _winningLinePaths = [];
  ui.Image? image;

  bool isShowButton = true;

  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _horizontalLines =
        _generateRandomHorizontalLines(widget.participantList.length);

    // アニメーションの設定（1本ずつ見せるため、少し長めの8秒に設定）
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear, // 等速で滑らかにバトンタッチさせるためlinearに変更
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
        tempYPositionFactors
            .map(
              (y) => HorizontalLine(
                startColomn: i,
                endColumn: i + 1,
                yPositionFactor: y,
              ),
            )
            .toList(),
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

    // "当たり"の列を探す
    final winningIndices = [
      for (var i = 0; i < lotteryList.length; i++)
        if (lotteryList[i] == AmidaLottery.win) i,
    ];

    for (final winningIndex in winningIndices) {
      final path = <Offset>[];

      // 開始点（"当たり"の位置から上方向に進む）
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

          currentX = (nextLine.startColomn * _kColumnSpacing == currentX)
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
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight + 150,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          return CustomPaint(
                            size: const Size(_kCanvasWidth, _kCanvasHeight),
                            painter: AmidaPainter(
                              horizontalLines: _horizontalLines,
                              nameList: widget.participantList,
                              lotteryList: lotteryList,
                              winningLinePaths: _winningLinePaths,
                              image: image,
                              animationProgress: _animation.value,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 60),
                    if (isShowButton)
                      ElevatedButton(
                        onPressed: () {
                          _startAnimation();
                          setState(() {
                            isShowButton = false;
                          });
                        },
                        child: const Text('結果を発表！'),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
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

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.brown
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    for (var i = 0;
        i < horizontalLines.length / _kMaxHorizontalLinesPerColumn + 1;
        i++) {
      final x = i * _kColumnSpacing;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);

      if (i < nameList.length) {
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

        final nameOffset = Offset(
          x - nameTextPainter.width / 2,
          -nameTextPainter.height - 5,
        );
        nameTextPainter.paint(canvas, nameOffset);
      }

      if (i < lotteryList.length && lotteryList[i] == AmidaLottery.win) {
        if (image != null) {
          final originalWidth = image!.width.toDouble();
          final originalHeight = image!.height.toDouble();
          final aspectRatio = originalWidth / originalHeight;

          const maxWidth = 50.0;
          const maxHeight = 50.0;

          late double drawWidth;
          late double drawHeight;

          if (aspectRatio > 1) {
            drawWidth = maxWidth;
            drawHeight = maxWidth / aspectRatio;
          } else {
            drawHeight = maxHeight;
            drawWidth = maxHeight * aspectRatio;
          }

          final imageX = x - drawWidth / 2;
          final imageY = size.height + 5;

          final dstRect = Rect.fromLTWH(imageX, imageY, drawWidth, drawHeight);
          final srcRect = Rect.fromLTWH(0, 0, originalWidth, originalHeight);

          canvas.drawImageRect(image!, srcRect, dstRect, Paint());
        }
      }
    }

    for (final line in horizontalLines) {
      final startColumn = line.startColomn;
      final endColumn = line.endColumn;
      final yFactor = line.yPositionFactor;

      final startX = startColumn * _kColumnSpacing;
      final endX = endColumn * _kColumnSpacing;
      final y = size.height * yFactor;

      canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
    }

    // 1本ずつ順番に走るようにアニメーション進行度の計算を調整
    if (winningLinePaths.isNotEmpty && winningLinePaths.length == 2) {
      // --- 1人目の当選者（赤色）：進捗 0.0 〜 0.5 の間で動く ---
      final redPaint = Paint()
        ..color = Colors.red
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke;

      final redProgress = (animationProgress * 2).clamp(0.0, 1.0);

      final redLinePath = winningLinePaths.first;
      for (var i = 0; i < redLinePath.length - 1; i++) {
        final start = redLinePath[i];
        final end = redLinePath[i + 1];

        final progress = (i + 1) / redLinePath.length;
        if (redProgress >= progress) {
          canvas.drawLine(start, end, redPaint);
        } else if (redProgress >= i / redLinePath.length) {
          final t =
              (redProgress - i / redLinePath.length) * redLinePath.length;
          final partialEnd = Offset(
            start.dx + (end.dx - start.dx) * t,
            start.dy + (end.dy - start.dy) * t,
          );
          canvas.drawLine(start, partialEnd, redPaint);
          break;
        }
      }

      // --- 2人目の当選者（オレンジ色）：進捗 0.5 〜 1.0 の間で動く ---
      final orangePaint = Paint()
        ..color = Colors.orange
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke;

      final orangeProgress = animationProgress < 0.5
          ? 0.0
          : ((animationProgress - 0.5) * 2).clamp(0.0, 1.0);

      final orangeLinePath = winningLinePaths.last;
      for (var i = 0; i < orangeLinePath.length - 1; i++) {
        final start = orangeLinePath[i];
        final end = orangeLinePath[i + 1];

        final progress = (i + 1) / orangeLinePath.length;
        if (orangeProgress >= progress) {
          canvas.drawLine(start, end, orangePaint);
        } else if (orangeProgress >= i / orangeLinePath.length) {
          final t = (orangeProgress - i / orangeLinePath.length) *
              orangeLinePath.length;
          final partialEnd = Offset(
            start.dx + (end.dx - start.dx) * t,
            start.dy + (end.dy - start.dy) * t,
          );
          canvas.drawLine(start, partialEnd, orangePaint);
          break;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
