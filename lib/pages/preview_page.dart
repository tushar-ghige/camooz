import 'dart:io';

import 'package:blurrycontainer/blurrycontainer.dart';
import 'package:camera/camera.dart';
import 'package:camooz/utils/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:gallery_saver/gallery_saver.dart';

class PreviewPage extends StatelessWidget {
  const PreviewPage({
    Key? key,
    required this.picture,
  }) : super(key: key);

  final XFile picture;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Image.file(
            File(picture.path),
            fit: BoxFit.cover,
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  BlurryContainer(
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.white,
                      iconSize: 32,
                    ),
                  ),
                  BlurryContainer(
                    child: IconButton(
                      onPressed: () async {
                        final ok = await GallerySaver.saveImage(picture.path);
                        if (ok != null) {
                          if (ok) {
                            AppSnackbar.show(context, "Image Saved");
                          } else {
                            AppSnackbar.show(context, "Cannot Save Image");
                          }
                        }
                      },
                      icon: const Icon(Icons.check_rounded),
                      color: Colors.white,
                      iconSize: 32,
                    ),
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
