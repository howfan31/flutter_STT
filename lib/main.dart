import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  runApp(const SpeechHelperApp());
}

class SpeechHelperApp extends StatelessWidget {
  const SpeechHelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '語音小幫手',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const SpeechHomePage(),
    );
  }
}

class SpeechHomePage extends StatefulWidget {
  const SpeechHomePage({super.key});

  @override
  State<SpeechHomePage> createState() => _SpeechHomePageState();
}

class _SpeechHomePageState extends State<SpeechHomePage> {
  final SpeechToText _speechToText = SpeechToText();
  final List<String> _history = [];

  bool _isInitializing = true;
  bool _isSpeechAvailable = false;
  bool _isListening = false;
  String _recognizedText = '';
  String _statusMessage = '正在初始化語音辨識...';
  String? _errorMessage;
  String? _selectedLocaleId;
  String? _selectedLanguageCode;

  @override
  void initState() {
    super.initState();
    _initializeSpeechRecognition();
  }

  Future<void> _initializeSpeechRecognition() async {
    try {
      final isAvailable = await _speechToText.initialize(
        onStatus: _handleSpeechStatus,
        onError: _handleSpeechError,
      );

      if (!isAvailable) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isInitializing = false;
          _isSpeechAvailable = false;
          _statusMessage = '語音辨識無法使用';
          _errorMessage = '請確認已允許麥克風權限，且裝置支援語音辨識服務。';
        });
        return;
      }

      String? selectedLocaleId;
      String? selectedLanguageCode;
      String? localeWarning;
      try {
        selectedLocaleId = await _supportedLocaleId('zh');
        if (selectedLocaleId != null) {
          selectedLanguageCode = 'zh';
        } else {
          localeWarning = '裝置未提供繁體中文，將使用系統預設語言。';
        }
      } catch (error) {
        localeWarning = '無法讀取語言清單，將使用系統預設語言：$error';
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializing = false;
        _isSpeechAvailable = true;
        _selectedLocaleId = selectedLocaleId;
        _selectedLanguageCode = selectedLanguageCode;
        _statusMessage = selectedLocaleId == null
            ? '準備完成（系統預設語言）'
            : '準備完成（繁體中文）';
        _errorMessage = localeWarning;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializing = false;
        _isSpeechAvailable = false;
        _statusMessage = '初始化失敗';
        _errorMessage = '無法初始化語音辨識：$error';
      });
    }
  }

  Future<String?> _supportedLocaleId(String languageCode) async {
    final locales = await _speechToText.locales();
    final preferredLocaleId = switch (languageCode) {
      'zh' => 'zh_tw',
      'en' => 'en_us',
      _ => languageCode,
    };

    for (final locale in locales) {
      if (locale.localeId.toLowerCase() == preferredLocaleId) {
        return locale.localeId;
      }
    }

    if (languageCode == 'en') {
      for (final locale in locales) {
        if (locale.localeId.toLowerCase().startsWith('en_')) {
          return locale.localeId;
        }
      }
    }

    return null;
  }

  Future<void> _selectLanguage(String languageCode) async {
    if (!_isSpeechAvailable || _isListening) {
      return;
    }

    try {
      final localeId = await _supportedLocaleId(languageCode);
      if (!mounted) {
        return;
      }
      if (localeId == null) {
        setState(() {
          _errorMessage = languageCode == 'zh'
              ? '此裝置不支援繁體中文（zh_TW）語音辨識。'
              : '此裝置不支援英文語音辨識。';
        });
        return;
      }

      setState(() {
        _selectedLanguageCode = languageCode;
        _selectedLocaleId = localeId;
        _errorMessage = null;
        _statusMessage = languageCode == 'zh' ? '已切換為繁體中文辨識' : '已切換為英文辨識';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '無法檢查裝置支援的語言：$error';
      });
    }
  }

  Future<void> _startListening() async {
    if (!_isSpeechAvailable || _isInitializing || _isListening) {
      return;
    }

    setState(() {
      _recognizedText = '';
      _errorMessage = null;
      _isListening = true;
      _statusMessage = '辨識中...';
    });

    try {
      await _speechToText.listen(
        onResult: _handleSpeechResult,
        listenOptions: SpeechListenOptions(
          localeId: _selectedLocaleId,
          partialResults: true,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isListening = false;
        _statusMessage = '無法開始辨識';
        _errorMessage = '開始語音辨識時發生錯誤：$error';
      });
    }
  }

  Future<void> _stopListening() async {
    if (!_isListening) {
      return;
    }

    _saveCurrentResult();
    try {
      await _speechToText.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _isListening = false;
        _statusMessage = '已停止辨識';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isListening = false;
        _statusMessage = '停止辨識時發生錯誤';
        _errorMessage = '無法停止語音辨識：$error';
      });
    }
  }

  void _handleSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) {
      return;
    }
    setState(() {
      _recognizedText = result.recognizedWords;
    });

    if (result.finalResult) {
      _saveCurrentResult();
    }
  }

  void _handleSpeechStatus(String status) {
    if (!mounted) {
      return;
    }

    final hasStopped = status == 'done' || status == 'notListening';
    if (hasStopped) {
      _saveCurrentResult();
    }

    setState(() {
      _isListening = status == 'listening';
      _statusMessage = switch (status) {
        'listening' => '辨識中...',
        'done' || 'notListening' => '已停止辨識',
        _ => '語音狀態：$status',
      };
    });
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    if (!mounted) {
      return;
    }
    _saveCurrentResult();
    setState(() {
      _isListening = false;
      _statusMessage = '辨識發生錯誤';
      _errorMessage = '語音辨識錯誤：${error.errorMsg}';
    });
  }

  void _saveCurrentResult() {
    final text = _recognizedText.trim();
    if (text.isEmpty || _history.contains(text) || !mounted) {
      return;
    }

    setState(() {
      _history.insert(0, text);
      if (_history.length > 3) {
        _history.removeLast();
      }
    });
  }

  void _clearHistory() {
    setState(_history.clear);
  }

  @override
  void dispose() {
    if (_speechToText.isListening) {
      _speechToText.stop();
    }
    super.dispose();
  }

  Color _statusColor(ColorScheme colorScheme) {
    if (_errorMessage != null) {
      return colorScheme.error;
    }
    if (_isListening) {
      return colorScheme.primary;
    }
    return colorScheme.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final buttonEnabled = _isSpeechAvailable && !_isInitializing;

    return Scaffold(
      appBar: AppBar(title: const Text('語音小幫手')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 12, color: _statusColor(colorScheme)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: TextStyle(color: colorScheme.error)),
            ],
            const SizedBox(height: 24),
            InputDecorator(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '辨識語言',
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedLanguageCode,
                  hint: const Text('系統預設語言'),
                  items: const [
                    DropdownMenuItem(value: 'zh', child: Text('繁體中文（zh_TW）')),
                    DropdownMenuItem(value: 'en', child: Text('英文')),
                  ],
                  onChanged: buttonEnabled && !_isListening
                      ? (languageCode) {
                          if (languageCode != null) {
                            _selectLanguage(languageCode);
                          }
                        }
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('目前辨識文字', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(minHeight: 170),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _recognizedText.isEmpty
                    ? (_isListening ? '請開始說話...' : '按下麥克風開始語音辨識')
                    : _recognizedText,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: FilledButton.icon(
                onPressed: buttonEnabled
                    ? (_isListening ? _stopListening : _startListening)
                    : null,
                icon: Icon(_isListening ? Icons.stop : Icons.mic),
                label: Text(_isListening ? '停止辨識' : '開始辨識'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(190, 58),
                  textStyle: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '最近辨識紀錄',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: _history.isEmpty ? null : _clearHistory,
                  child: const Text('清除紀錄'),
                ),
              ],
            ),
            if (_history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('尚無辨識紀錄，開始說話後會顯示在這裡。'),
              )
            else
              ..._history.map(
                (text) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(text),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
