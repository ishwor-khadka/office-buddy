import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:office_buddy/constants/asset_source.dart' as assets;

class BirdsAudio {
  // Public domain audio hosted by Wikimedia (royalty-free).
  // If you want a different sound later, replace this URL.
  static const String birdsMp3Url =
      'https://upload.wikimedia.org/wikipedia/commons/transcoded/5/51/Birds_chirping_in_a_garden.ogg/Birds_chirping_in_a_garden.ogg.mp3';

  static const String _cacheFileName = 'office_buddy_birds.mp3';

  static Future<File?> _downloadIfNeeded() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$_cacheFileName');
      if (await file.exists() && (await file.length()) > 1024) {
        return file;
      }

      final resp = await http.get(Uri.parse(birdsMp3Url));
      if (resp.statusCode != 200) return null;
      await file.writeAsBytes(resp.bodyBytes, flush: true);
      return file;
    } catch (e) {
      debugPrint('BirdsAudio download failed: $e');
      return null;
    }
  }

  static Future<void> playOn(AudioPlayer player) async {
    final file = await _downloadIfNeeded();
    if (file != null) {
      await player.play(DeviceFileSource(file.path));
      return;
    }

    // Fallback to bundled asset if download fails.
    await player.play(AssetSource(assets.AssetSource.birdMp3));
  }
}
