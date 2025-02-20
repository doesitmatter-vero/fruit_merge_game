import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:math';

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF533483).withOpacity(0.1)
      ..strokeWidth = 1;

    // Yatay çizgiler
    for (double i = 0; i < size.height; i += 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    // Dikey çizgiler
    for (double i = 0; i < size.width; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class FruitTile {
  int? value;
  Offset offset;
  bool isNew;

  FruitTile({
    this.value,
    this.offset = Offset.zero,
    this.isNew = false,
  });

  FruitTile copyWith({
    int? value,
    Offset? offset,
    bool? isNew,
  }) {
    return FruitTile(
      value: value ?? this.value,
      offset: offset ?? this.offset,
      isNew: isNew ?? this.isNew,
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  // Reklam ID'leri
  static const bool isTestMode = true; // Test modunu kontrol etmek için

  // Banner reklam ID'leri
  static const String testBannerAdId = 'ca-app-pub-3940256099942544/6300978111';
  static const String realBannerAdId = 'ca-app-pub-2895679082247228/1153156375';
  
  // Geçiş (Interstitial) reklam ID'leri
  static const String testInterstitialAdId = 'ca-app-pub-3940256099942544/1033173712';
  static const String realInterstitialAdId = 'ca-app-pub-2895679082247228/1153156375';

  // Kullanılacak reklam ID'leri
  String get bannerAdId => isTestMode ? testBannerAdId : realBannerAdId;
  String get interstitialAdId => isTestMode ? testInterstitialAdId : realInterstitialAdId;

  static const int gridSize = 4;
  static const Map<int, String> fruitEmojis = {
    1: '🍒', // Kiraz
    2: '🍎', // Elma
    3: '🍐', // Armut
    4: '🍊', // Portakal
    5: '🍋', // Limon
    6: '🍇', // Üzüm
    7: '🍉', // Karpuz
    8: '🍍', // Ananas
    9: '🥝', // Kivi
    10: '🥭', // Mango
    11: '🍓', // Çilek
    12: '🥥', // Hindistan cevizi
    13: '🥑', // Avokado
    14: '🍑', // Şeftali
  };

  late List<List<FruitTile>> grid;
  int score = 0;
  bool isGameOver = false;
  bool hasReachedStrawberry = false; // Çilek seviyesine ulaşıldı mı
  int highScore = 0; // En yüksek skor değişkeni
  final Random random = Random();
  final FocusNode _focusNode = FocusNode();
  
  // Kaydırma için değişkenler
  Offset? dragStart;
  Offset? dragEnd;
  static const double minSwipeDistance = 10.0; // Minimum kaydırma mesafesi

  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;

  @override
  void initState() {
    super.initState();
    // MobileAds'i başlat ve test cihazını ekle
    MobileAds.instance.initialize().then((InitializationStatus status) {
      print('MobileAds başlatıldı: ${status.adapterStatuses}');
      // Test cihazını ekle
      MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: ['kgmcb358c04242a5f33']), // Emülatör için test cihaz ID'si
      );
      _loadAd(); // Banner reklam yüklemeyi başlat
      _loadInterstitialAd(); // Geçiş reklamını yükle
    });
    
    grid = List.generate(
      gridSize,
      (i) => List.generate(
        gridSize,
        (j) => FruitTile(),
      ),
    );
    addNewFruit();
    addNewFruit();
    WidgetsBinding.instance.addObserver(this);
    _focusNode.requestFocus();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: bannerAdId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('Banner reklam başarıyla yüklendi!');
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          print('Banner reklam yüklenemedi! Hata: ${error.message}, Kod: ${error.code}');
          ad.dispose();
          _bannerAd = null;
        },
        onAdOpened: (ad) => print('Banner reklam açıldı.'),
        onAdClosed: (ad) => print('Banner reklam kapandı.'),
        onAdImpression: (ad) => print('Banner reklam gösterildi.'),
      ),
    );

    print('Banner reklam yükleme başlatıldı...');
    _bannerAd?.load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          print('Geçiş reklamı başarıyla yüklendi!');
          _interstitialAd = ad;
          _isInterstitialAdReady = true;

          _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              print('Geçiş reklamı kapatıldı.');
              _isInterstitialAdReady = false;
              _loadInterstitialAd(); // Yeni reklam yükle
              // Oyuna devam et
              setState(() {
                isGameOver = false;
                // Mevcut puanı koru ama oynanabilir bir durum oluştur
                // Tahtanın yarısını boşalt
                for (int i = 0; i < gridSize; i++) {
                  for (int j = 0; j < gridSize; j++) {
                    if (random.nextBool()) {
                      grid[i][j] = FruitTile();
                    }
                  }
                }
                // En az 2 boş alan olduğundan emin ol
                int emptyCount = 0;
                for (int i = 0; i < gridSize && emptyCount < 2; i++) {
                  for (int j = 0; j < gridSize && emptyCount < 2; j++) {
                    if (grid[i][j].value != null) {
                      grid[i][j] = FruitTile();
                      emptyCount++;
                    }
                  }
                }
                // Yeni meyveler ekle
                addNewFruit();
                addNewFruit();
              });
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('Geçiş reklamı gösterilemedi: $error');
              _isInterstitialAdReady = false;
              ad.dispose();
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          print('Geçiş reklamı yüklenemedi: ${error.message}');
          _isInterstitialAdReady = false;
          _loadInterstitialAd();
        },
      ),
    );
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    _bannerAd?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    super.dispose();
  }

  void addNewFruit() {
    List<Point<int>> emptySpots = [];
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (grid[i][j].value == null) {
          emptySpots.add(Point(i, j));
        }
      }
    }

    if (emptySpots.isNotEmpty) {
      final spot = emptySpots[random.nextInt(emptySpots.length)];
      setState(() {
        // %60 olasılıkla 1. seviye, %40 olasılıkla 2. seviye meyve ekle
        final value = random.nextDouble() < 0.6 ? 1 : 2;
        grid[spot.x][spot.y] = FruitTile(value: value, isNew: true);
      });
    }
  }

  bool isGameOverCheck() {
    // Boş hücre var mı kontrol et
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (grid[i][j].value == null) return false;
      }
    }

    // Yatayda birleştirilebilir meyve var mı
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize - 1; j++) {
        if (grid[i][j].value == grid[i][j + 1].value) return false;
      }
    }

    // Dikeyde birleştirilebilir meyve var mı
    for (int j = 0; j < gridSize; j++) {
      for (int i = 0; i < gridSize - 1; i++) {
        if (grid[i][j].value == grid[i + 1][j].value) return false;
      }
    }

    return true;
  }

  void checkForStrawberry(FruitTile tile) {
    if (!hasReachedStrawberry && tile.value == 11) { // Çilek seviyesi (11)
      setState(() {
        hasReachedStrawberry = true;
      });
      showWinDialog();
    }
  }

  void showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Tebrikler! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Çilek seviyesine ulaştınız! 🍓'),
            const SizedBox(height: 16),
            Text(
              'Puanınız: $score',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              resetGame();
            },
            child: const Text('Yeniden Başla'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );
  }

  void resetGame() {
    setState(() {
      grid = List.generate(
        gridSize,
        (i) => List.generate(
          gridSize,
          (j) => FruitTile(),
        ),
      );
      if (score > highScore) { // En yüksek skoru güncelle
        highScore = score;
      }
      score = 0;
      isGameOver = false;
      hasReachedStrawberry = false;
      addNewFruit();
      addNewFruit();
    });
  }

  void handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent && !isGameOver) {
      print('Tuş basıldı: ${event.logicalKey}');
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        print('Sol ok tuşuna basıldı');
        moveLeft();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        print('Sağ ok tuşuna basıldı');
        moveRight();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        print('Yukarı ok tuşuna basıldı');
        moveUp();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        print('Aşağı ok tuşuna basıldı');
        moveDown();
      }
    }
  }

  void moveLeft() {
    bool changed = false;
    List<List<FruitTile>> newGrid = List.generate(
      gridSize,
      (i) => List.generate(gridSize, (j) => FruitTile()),
    );

    for (int i = 0; i < gridSize; i++) {
      int writePos = 0;
      
      // Önce sola doğru kaydır
      for (int j = 0; j < gridSize; j++) {
        if (grid[i][j].value != null) {
          newGrid[i][writePos] = grid[i][j].copyWith(
            offset: Offset((j - writePos).toDouble(), 0),
          );
          if (j != writePos) changed = true; // Sadece pozisyon değiştiyse true yap
          writePos++;
        }
      }
      
      // Birleştirmeleri kontrol et
      for (int j = 0; j < gridSize - 1; j++) {
        if (newGrid[i][j].value != null && 
            newGrid[i][j].value == newGrid[i][j+1].value) {
          newGrid[i][j] = newGrid[i][j].copyWith(
            value: newGrid[i][j].value! + 1,
          );
          newGrid[i][j+1] = FruitTile();
          score += newGrid[i][j].value! * 10;
          changed = true;
          checkForStrawberry(newGrid[i][j]);
        }
      }
      
      // Boşlukları kapat
      List<FruitTile> row = List.generate(gridSize, (_) => FruitTile());
      writePos = 0;
      for (int j = 0; j < gridSize; j++) {
        if (newGrid[i][j].value != null) {
          row[writePos] = newGrid[i][j].copyWith(
            offset: Offset((j - writePos).toDouble(), 0),
          );
          writePos++;
        }
      }
      newGrid[i] = row;
    }

    if (changed) {
      setState(() {
        grid = newGrid;
      });

      Future.delayed(const Duration(milliseconds: 150), () {
        setState(() {
          for (int i = 0; i < gridSize; i++) {
            for (int j = 0; j < gridSize; j++) {
              grid[i][j] = grid[i][j].copyWith(offset: Offset.zero);
            }
          }
        });
        
        Future.delayed(const Duration(milliseconds: 50), () {
          addNewFruit();
          if (isGameOverCheck()) {
            setState(() {
              isGameOver = true;
            });
          }
        });
      });
    }
  }

  void moveRight() {
    bool changed = false;
    List<List<FruitTile>> newGrid = List.generate(
      gridSize,
      (i) => List.generate(gridSize, (j) => FruitTile()),
    );

    for (int i = 0; i < gridSize; i++) {
      int writePos = gridSize - 1;
      
      // Önce sağa doğru kaydır
      for (int j = gridSize - 1; j >= 0; j--) {
        if (grid[i][j].value != null) {
          newGrid[i][writePos] = grid[i][j].copyWith(
            offset: Offset((j - writePos).toDouble(), 0),
          );
          if (j != writePos) changed = true; // Sadece pozisyon değiştiyse true yap
          writePos--;
        }
      }
      
      // Birleştirmeleri kontrol et
      for (int j = gridSize - 1; j > 0; j--) {
        if (newGrid[i][j].value != null && 
            newGrid[i][j].value == newGrid[i][j-1].value) {
          newGrid[i][j] = newGrid[i][j].copyWith(
            value: newGrid[i][j].value! + 1,
          );
          newGrid[i][j-1] = FruitTile();
          score += newGrid[i][j].value! * 10;
          changed = true;
          checkForStrawberry(newGrid[i][j]);
        }
      }
      
      // Boşlukları kapat
      List<FruitTile> row = List.generate(gridSize, (_) => FruitTile());
      writePos = gridSize - 1;
      for (int j = gridSize - 1; j >= 0; j--) {
        if (newGrid[i][j].value != null) {
          row[writePos] = newGrid[i][j].copyWith(
            offset: Offset((j - writePos).toDouble(), 0),
          );
          writePos--;
        }
      }
      newGrid[i] = row;
    }

    if (changed) {
      setState(() {
        grid = newGrid;
      });

      Future.delayed(const Duration(milliseconds: 150), () {
        setState(() {
          for (int i = 0; i < gridSize; i++) {
            for (int j = 0; j < gridSize; j++) {
              grid[i][j] = grid[i][j].copyWith(offset: Offset.zero);
            }
          }
        });
        
        Future.delayed(const Duration(milliseconds: 50), () {
          addNewFruit();
          if (isGameOverCheck()) {
            setState(() {
              isGameOver = true;
            });
          }
        });
      });
    }
  }

  void moveUp() {
    bool changed = false;
    List<List<FruitTile>> newGrid = List.generate(
      gridSize,
      (i) => List.generate(gridSize, (j) => FruitTile()),
    );

    for (int j = 0; j < gridSize; j++) {
      int writePos = 0;
      
      // Önce yukarı doğru kaydır
      for (int i = 0; i < gridSize; i++) {
        if (grid[i][j].value != null) {
          newGrid[writePos][j] = grid[i][j].copyWith(
            offset: Offset(0, (i - writePos).toDouble()),
          );
          if (i != writePos) changed = true; // Sadece pozisyon değiştiyse true yap
          writePos++;
        }
      }
      
      // Birleştirmeleri kontrol et
      for (int i = 0; i < gridSize - 1; i++) {
        if (newGrid[i][j].value != null && 
            newGrid[i][j].value == newGrid[i+1][j].value) {
          newGrid[i][j] = newGrid[i][j].copyWith(
            value: newGrid[i][j].value! + 1,
          );
          newGrid[i+1][j] = FruitTile();
          score += newGrid[i][j].value! * 10;
          changed = true;
          checkForStrawberry(newGrid[i][j]);
        }
      }
      
      // Boşlukları kapat
      List<FruitTile> col = List.generate(gridSize, (_) => FruitTile());
      writePos = 0;
      for (int i = 0; i < gridSize; i++) {
        if (newGrid[i][j].value != null) {
          col[writePos] = newGrid[i][j].copyWith(
            offset: Offset(0, (i - writePos).toDouble()),
          );
          writePos++;
        }
      }
      for (int i = 0; i < gridSize; i++) {
        newGrid[i][j] = col[i];
      }
    }

    if (changed) {
      setState(() {
        grid = newGrid;
      });

      Future.delayed(const Duration(milliseconds: 150), () {
        setState(() {
          for (int i = 0; i < gridSize; i++) {
            for (int j = 0; j < gridSize; j++) {
              grid[i][j] = grid[i][j].copyWith(offset: Offset.zero);
            }
          }
        });
        
        Future.delayed(const Duration(milliseconds: 50), () {
          addNewFruit();
          if (isGameOverCheck()) {
            setState(() {
              isGameOver = true;
            });
          }
        });
      });
    }
  }

  void moveDown() {
    bool changed = false;
    List<List<FruitTile>> newGrid = List.generate(
      gridSize,
      (i) => List.generate(gridSize, (j) => FruitTile()),
    );

    for (int j = 0; j < gridSize; j++) {
      int writePos = gridSize - 1;
      
      // Önce aşağı doğru kaydır
      for (int i = gridSize - 1; i >= 0; i--) {
        if (grid[i][j].value != null) {
          newGrid[writePos][j] = grid[i][j].copyWith(
            offset: Offset(0, (i - writePos).toDouble()),
          );
          if (i != writePos) changed = true; // Sadece pozisyon değiştiyse true yap
          writePos--;
        }
      }
      
      // Birleştirmeleri kontrol et
      for (int i = gridSize - 1; i > 0; i--) {
        if (newGrid[i][j].value != null && 
            newGrid[i][j].value == newGrid[i-1][j].value) {
          newGrid[i][j] = newGrid[i][j].copyWith(
            value: newGrid[i][j].value! + 1,
          );
          newGrid[i-1][j] = FruitTile();
          score += newGrid[i][j].value! * 10;
          changed = true;
          checkForStrawberry(newGrid[i][j]);
        }
      }
      
      // Boşlukları kapat
      List<FruitTile> col = List.generate(gridSize, (_) => FruitTile());
      writePos = gridSize - 1;
      for (int i = gridSize - 1; i >= 0; i--) {
        if (newGrid[i][j].value != null) {
          col[writePos] = newGrid[i][j].copyWith(
            offset: Offset(0, (i - writePos).toDouble()),
          );
          writePos--;
        }
      }
      for (int i = 0; i < gridSize; i++) {
        newGrid[i][j] = col[i];
      }
    }

    if (changed) {
      setState(() {
        grid = newGrid;
      });

      Future.delayed(const Duration(milliseconds: 150), () {
        setState(() {
          for (int i = 0; i < gridSize; i++) {
            for (int j = 0; j < gridSize; j++) {
              grid[i][j] = grid[i][j].copyWith(offset: Offset.zero);
            }
          }
        });
        
        Future.delayed(const Duration(milliseconds: 50), () {
          addNewFruit();
          if (isGameOverCheck()) {
            setState(() {
              isGameOver = true;
            });
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: handleKeyEvent,
      autofocus: true,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF16213E),
          elevation: 0,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F3460),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE94560),
                    width: 2,
                  ),
                ),
                child: Text(
                  'Puan: $score',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F3460),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE94560),
                    width: 2,
                  ),
                ),
                child: Text(
                  'En Yüksek: $highScore',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            // Arka plan deseni
            Positioned.fill(
              child: CustomPaint(
                painter: GridPainter(),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE94560), // Neon kırmızımsı çerçeve
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE94560).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: GestureDetector(
                        onPanStart: (details) => dragStart = details.localPosition,
                        onPanUpdate: (details) => dragEnd = details.localPosition,
                        onPanEnd: (details) {
                          if (dragStart == null || dragEnd == null) return;
                          
                          final dx = dragEnd!.dx - dragStart!.dx;
                          final dy = dragEnd!.dy - dragStart!.dy;
                          
                          // Minimum kaydırma mesafesini kontrol et
                          if (dx.abs() < minSwipeDistance && dy.abs() < minSwipeDistance) {
                            dragStart = null;
                            dragEnd = null;
                            return;
                          }
                          
                          // Yatay hareket dikey hareketten daha büyükse
                          if (dx.abs() > dy.abs()) {
                            if (dx > 0) {
                              moveRight();
                            } else {
                              moveLeft();
                            }
                          } else {
                            if (dy > 0) {
                              moveDown();
                            } else {
                              moveUp();
                            }
                          }
                          
                          dragStart = null;
                          dragEnd = null;
                        },
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16.0),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: gridSize,
                            crossAxisSpacing: 4.0,
                            mainAxisSpacing: 4.0,
                          ),
                          itemCount: gridSize * gridSize,
                          itemBuilder: (context, index) {
                            final row = index ~/ gridSize;
                            final col = index % gridSize;
                            final tile = grid[row][col];

                            return Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F3460), // Koyu mavi hücre
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(
                                  color: const Color(0xFF533483).withOpacity(0.5), // Mor çerçeve
                                  width: 1,
                                ),
                              ),
                              child: AnimatedSlide(
                                offset: tile.offset,
                                duration: const Duration(milliseconds: 150),
                                curve: Curves.easeInOut,
                                child: Center(
                                  child: AnimatedOpacity(
                                    opacity: tile.value != null ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 150),
                                    child: Text(
                                      tile.value != null ? fruitEmojis[tile.value]! : '',
                                      style: const TextStyle(fontSize: 30),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  if (_isAdLoaded)
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFE94560).withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: _bannerAd!.size.width.toDouble(),
                          height: _bannerAd!.size.height.toDouble(),
                          child: AdWidget(ad: _bannerAd!),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: resetGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE94560),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      'Yeniden Başla',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isGameOver)
              Container(
                color: Colors.black87,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(32),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16213E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE94560),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE94560).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Oyun Bitti!',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE94560),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F3460),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: const Color(0xFFE94560),
                              width: 2,
                            ),
                          ),
                          child: Text(
                            'Puan: $score',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isInterstitialAdReady)
                              ElevatedButton.icon(
                                onPressed: () {
                                  _interstitialAd?.show();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2EB086),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                icon: const Icon(Icons.play_circle_outline, color: Colors.white),
                                label: const Text(
                                  'Reklam İzle ve\nDevam Et',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: resetGame,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE94560),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              icon: const Icon(Icons.refresh, color: Colors.white),
                              label: const Text(
                                'Yeniden\nBaşla',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 