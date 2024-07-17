import 'dart:io';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await startFlaskServer();
  runApp(MyApp());
}

Future<void> startFlaskServer() async {
  var scriptDir = File.fromUri(Platform.script).parent;
  var backendDir = Directory('${scriptDir.path}/backend');
  if (await backendDir.exists()) {
    var result = await Process.run('python', ['app.py'],
        workingDirectory: backendDir.path);
    if (result.exitCode == 0) {
      print('Flask server started successfully');
    } else {
      print('Failed to start Flask server: ${result.stderr}');
    }
  } else {
    print('Backend directory not found');
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Background Remover',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Uint8List? _imageBytes;
  Uint8List? _processedImageBytes;
  String? _imageName;
  bool _isLoading = false;
  String _statusMessage = '';

  Future<void> _getImage() async {
    final html.FileUploadInputElement input = html.FileUploadInputElement()
      ..accept = 'image/*';
    input.click();

    await input.onChange.first;
    if (input.files!.isNotEmpty) {
      final file = input.files![0];
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;

      setState(() {
        _imageBytes = reader.result as Uint8List;
        _imageName = file.name;
        _processedImageBytes = null;
        _statusMessage = 'Image selected: ${file.name}';
      });
    }
  }

  Future<void> _removeBackground() async {
    if (_imageBytes == null) {
      setState(() {
        _statusMessage = 'Please select an image first';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _statusMessage = 'Processing image...';
    });
    try {
      final url = Uri.parse('http://localhost:5000/remove_background');
      var request = http.MultipartRequest('POST', url);
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        _imageBytes!,
        filename: _imageName ?? 'image.jpg',
      ));
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        setState(() {
          _processedImageBytes = response.bodyBytes;
          _statusMessage = 'Background removed successfully';
        });
      } else {
        throw Exception('Failed to remove background: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _saveImage() {
    if (_processedImageBytes == null) {
      setState(() {
        _statusMessage = 'No processed image to save';
      });
      return;
    }

    final blob = html.Blob([_processedImageBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute("download", "background_removed.png")
      ..click();

    html.Url.revokeObjectUrl(url);

    setState(() {
      _statusMessage = 'Image download started';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Background Remover')),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_imageBytes != null) Image.memory(_imageBytes!, height: 200),
              if (_processedImageBytes != null)
                Image.memory(_processedImageBytes!, height: 200),
              SizedBox(height: 20),
              Text(_statusMessage),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _getImage,
                child: Text('Select Image'),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: _isLoading ? null : _removeBackground,
                child: _isLoading
                    ? CircularProgressIndicator()
                    : Text('Remove Background'),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: _processedImageBytes != null ? _saveImage : null,
                child: Text('Download Image'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
