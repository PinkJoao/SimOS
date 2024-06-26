import 'dart:io';
import 'dart:developer';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:camera/camera.dart';
import 'dart:convert' show json, utf8;
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:photo_view/photo_view.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void showSnackbar(BuildContext context, String message, [int? time]) {
  final snackBar = SnackBar(
    content: Container(
      padding: const EdgeInsets.all(12),
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
        ),
      ),
    ),
    behavior: SnackBarBehavior.floating,
    duration: Duration(seconds: time ?? 3),
    backgroundColor: Colors.transparent,
    elevation: 0,
  );
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

class OneDriveIDs {
  var token;
  var driveID;
  var folderID;
  bool? downloading;

  OneDriveIDs(this.token, this.driveID, this.folderID);

  bool check() {
    if (folderID != null && driveID != null) {
      return true;
    } else {
      log('OneDrive IDs are not available');
      return false;
    }
  }

  bool setDownloading(bool set){
    downloading = set;
    return downloading ?? false;
  }

  bool getDownloading(){
    return downloading ?? false;
  }
}

Future<http.Response?> request(String url, var token, [String? extension, Uint8List? body]) async {
  try {
    http.Response? response;
    
    if(extension != null && body != null){
      if(extension == 'jpg' || extension == 'png' || extension == 'jpeg'){
        response = await http.put(Uri.parse(url), headers: {"Authorization": "Bearer $token","Content-Type": "Image/$extension"}, body: body);
      }else if(extension == 'txt'){
        response = await http.put(Uri.parse(url), headers: {"Authorization": "Bearer $token","Content-Type": "Text/$extension"}, body: body);
      }
    }else{
      response = await http.get(Uri.parse(url), headers: {"Authorization": "Bearer $token"});
    }
    
    return response;
  } catch (error) {
    log('Request error: ${error.toString()}');
    return null;
  }
}

Future<OneDriveIDs?> getOneDriveIDs(var token, String folder) async {
  var response = await request("https://graph.microsoft.com/v1.0/me/drive/sharedWithMe", token);
  if (response == null) {
    return null;
  }
  if (response.statusCode != 200) {
    log('Request error: ${response.statusCode}');
    return null;
  }
  var sharedItens = json.decode(response.body)['value'];

  for (var item in sharedItens) {
    if (item['name'] == folder) {
      var remoteItem = item['remoteItem'];
      var parentReference = remoteItem['parentReference'];
      OneDriveIDs oneDriveIDs = OneDriveIDs(token, parentReference['driveId'], remoteItem['id']);
      return oneDriveIDs;
    }
  }
  log("Folder named [$folder] was NOT found");
  return null;
}

Future<Uint8List?> downloadFile(String fileName, OneDriveIDs oneDriveIDs, [bool? showSnackBar, BuildContext? context]) async {
  if (!oneDriveIDs.check()) {
    return null;
  }

  String url = "https://graph.microsoft.com/v1.0/drives/${oneDriveIDs.driveID}/items/${oneDriveIDs.folderID}:/$fileName:/content";

  var response = await request(url, oneDriveIDs.token);
  if (response == null) {
    return null;
  }

  if (response.statusCode == 200) {
    log("File [$fileName] was successfully downloaded");
    if (showSnackBar == true && context != null) {
      showSnackbar(context, 'Download concluído com sucesso');
    }
    return response.bodyBytes;

  }else {
    log("Failed to download the file [$fileName]");
    log('Status code:[${response.statusCode}]');
    log('Response body:[${response.body}]');
    if (showSnackBar == true && context != null) {
      showSnackbar(context, 'Falha no download, tente novamente');
    }
    return null;
  }
}

Future<bool?> uploadFile(File file, String fileName, String extension, OneDriveIDs oneDriveIDs, [bool? showSnackBar, BuildContext? context]) async {
  if (!oneDriveIDs.check()) {
    return null;
  } // ONE DRIVE IDS CHECK

  Uint8List fileBytes = File(file.path).readAsBytesSync();
  String url = "https://graph.microsoft.com/v1.0/drives/${oneDriveIDs.driveID}/items/${oneDriveIDs.folderID}:/${fileName + '.' + extension}:/content";

  var response = await request(url, oneDriveIDs.token, extension, fileBytes);
  if (response == null) {
    return null;
  }

  if (response.statusCode == 200) {
    log("File [$fileName] already exists on OneDrive");
    if (showSnackBar == true && context != null) {
      showSnackbar(context, 'Arquivo já foi enviado antreriormente');
    }
    return false;
  }
  if (response.statusCode != 201) {
    log("File [$fileName] upload failed");
    log('Status code:[${response.statusCode}]');
    log('Response body:[${response.body}]');
    if (showSnackBar == true && context != null) {
      showSnackbar(context, 'Falha no envio, tente novamente');
    }
    return null;
  }
  log("File [$fileName] uploaded successfully");
  if (showSnackBar == true && context != null) {
    showSnackbar(context, 'Arquivo enviado com sucesso');
  }
  return true;
}

Future<bool?> uploadText(String fileName, String text, OneDriveIDs oneDriveIDs, [bool? showSnackBar, BuildContext? context]) async {
  if (!oneDriveIDs.check()) {
    return null;
  } // ONE DRIVE IDS CHECK
  Uint8List fileBytes = Uint8List.fromList(utf8.encode(text));

  String url = "https://graph.microsoft.com/v1.0/drives/${oneDriveIDs.driveID}/items/${oneDriveIDs.folderID}:/${fileName + '.txt'}:/content";

  var response = await request(url, oneDriveIDs.token, 'txt', fileBytes);
  if (response == null) {
    return null;
  }

  if (response.statusCode == 200) {
    log("File [$fileName] already exists on OneDrive");
    if (showSnackBar == true && context != null) {
      showSnackbar(context, 'Arquivo já foi enviado antreriormente');
    }
    return false;
  }
  if (response.statusCode != 201) {
    log("File [$fileName] upload failed");
    log('Status code:[${response.statusCode}]');
    log('Response body:[${response.body}]');
    if (showSnackBar == true && context != null) {
      showSnackbar(context, 'Falha no envio, tente novamente');
    }
    return null;
  }
  log("File [$fileName] uploaded successfully");
  if (showSnackBar == true && context != null) {
    showSnackbar(context, 'Arquivo enviado com sucesso');
  }
  return true;
}

Future<File?> storeText(String fileName, String text, String folder, Directory directory) async {
  Uint8List fileBytes = Uint8List.fromList(utf8.encode(text));
  File? storedFile = await storeFile(fileBytes, '${fileName.split('.').first}.txt', folder, directory);
  return storedFile;
}

Future<String?> createFolder(String folderName, Directory directory) async {
  final Directory folder = Directory('${directory.path}/$folderName/');

  try {
    if (await folder.exists()) {
      return folder.path;
    } else {
      final Directory newFolder = await folder.create(recursive: true);
      return newFolder.path;
    }
  } catch (error) {
    log('Error creating folder: $error');
    return null;
  }
}

Future<File?> storeFile(Uint8List fileBytes, String fileName, String folder, Directory directory) async {
  await createFolder(folder, directory);
  String filePath = '${directory.path}/$folder/$fileName';
  File newFile = File(filePath);

  try {
    await newFile.writeAsBytes(fileBytes);
    log('File was stored successfully at: [$filePath]');
    return newFile;
  } catch (error) {
    log('Error storing file: $error');
    return null;
  }
}

Future<bool?> deleteFile(String fileName, String folder, Directory directory) async {
  String filePath = '${directory.path}/$folder/$fileName';
  File fileToDelete = File(filePath);

  try {
    if (await fileToDelete.exists()) {
      await fileToDelete.delete();
      log('File [$fileName] deleted successfully from: [$filePath]');
      return true;
    } else {
      log('File [$fileName] does not exist');
      return null;
    }
  } catch (error) {
    log('Error deleting file: $error');
    return false;
  }
}

Future<File?> moveFile(String fileName, String sourceFolder, String destinationFolder, Directory directory) async {
  // Create source and destination folder paths
  String sourcePath = '${directory.path}/$sourceFolder/$fileName';
  String destinationPath = '${directory.path}/$destinationFolder/$fileName';

  // Create a File instance for the source file
  File sourceFile = File(sourcePath);

  try {
    // Check if the source file exists
    if (await sourceFile.exists()) {

      // Ensure the destination folder exists
      await createFolder(destinationFolder, directory);

      // Construct a File instance for the destination file
      File destinationFile = File(destinationPath);

      // Perform the file move by renaming the file
      await sourceFile.rename(destinationPath);

      log('File moved successfully');
      return destinationFile;
    } else {
      log('Source file does not exist');
      return null;
    }
  } catch (error) {
    log('Error moving file: $error');
    return null;
  }
}

Future<List<File>?> getDirectoryFiles(String folder, Directory directory, [String? extension]) async {
  try {
    String folderPath = '${directory.path}/$folder/';
    Directory targetFolder = Directory(folderPath);

    // Check if the target folder exists
    if (await targetFolder.exists()) {
      List<File> files = [];

      // List all files in the folder
      List<FileSystemEntity> entities = targetFolder.listSync(recursive: true, followLinks: false);

      // Iterate through each file and filter by extension
      for (var entity in entities) {
        if (entity is File) {
          if (extension != null) {
            // Check if the file has the specified extension
            if (entity.path.endsWith('.$extension')) {
              files.add(entity);
            }
          } else {
            // If no extension specified, include all files
            files.add(entity);
          }
        }
      }

      return files;
    } else {
      log('Folder [${targetFolder.path}] does not exist');
      return null;
    }
  } catch (error) {
    log('Error retrieving files: $error');
    return null;
  }
}

Future<List<String>?> getDirectoryFileNames(String folder, Directory directory, [String? extension]) async {
  try {
    String folderPath = '${directory.path}/$folder/';
    Directory targetFolder = Directory(folderPath);

    // Check if the target folder exists
    if (await targetFolder.exists()) {
      List<String> fileNames = [];

      // List all files in the folder
      List<FileSystemEntity> entities = targetFolder.listSync(recursive: true, followLinks: false);

      // Iterate through each file and filter by extension
      for (var entity in entities) {
        if (entity is File) {
          if (extension != null) {
            // Check if the file has the specified extension
            if (entity.path.endsWith('.$extension')) {
              fileNames.add(entity.path.split('/').last);
            }
          } else {
            // If no extension specified, include all files
            fileNames.add(entity.path.split('/').last);
          }
        }
      }

      return fileNames;
    } else {
      log('Folder [${targetFolder.path}] does not exist');
      return null;
    }
  } catch (error) {
    log('Error retrieving files: $error');
    return null;
  }
}

double getTotalHeight(BuildContext context) {
  return MediaQuery.of(context).size.height;
}

double getTotalWidth(BuildContext context) {
  return MediaQuery.of(context).size.width;
}

void showInFullScreen(String imagePath, BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => FullScreenImage(imagePath: imagePath),
    ),
  );
}

class FullScreenImage extends StatelessWidget {
  final String imagePath;

  const FullScreenImage({
    Key? key,
    required this.imagePath
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          Navigator.pop(context);
        },
        child: Center(
          child: Hero(
            tag: imagePath,
            child: PhotoView(
              imageProvider: FileImage(File(imagePath)),
              enableRotation: true,
              tightMode: true,
              backgroundDecoration: const BoxDecoration(color: Colors.transparent),
            ),
          ),
        ),
      ),
    );
  }
}

class SafeMenuButton extends StatefulWidget {
  final String defaultItem;
  final List<String> items;
  final Function(String)? onChanged;
  final String recoveryKey;

  const SafeMenuButton({
    Key? key,
    required this.defaultItem,
    required this.items,
    this.onChanged,
    required this.recoveryKey,
  }) : super(key: key);

  @override
  SafeMenuButtonState createState() => SafeMenuButtonState();
}

class SafeMenuButtonState extends State<SafeMenuButton> {
  late String selectedItem;
  late bool _isLoading;

  @override
  void initState() {
    super.initState();
    _isLoading = true;
    _loadSelectedItem();
  }

  Future<void> _loadSelectedItem() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedItem = prefs.getString(widget.recoveryKey) ?? widget.defaultItem;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
    ? const CircularProgressIndicator() // Show a loading indicator while loading from SharedPreferences
    : ElevatedButton(
      style: selectedItem == widget.defaultItem
          ? ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            )
          : null,
      onPressed: () {
        _showDropdownMenu(context);
      },
      child: Text(selectedItem),
    );
  }

  void _showDropdownMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          child: ListView.builder(
            itemCount: widget.items.length,
            itemBuilder: (BuildContext context, int index) {
              return ListTile(
                title: Text(widget.items[index]),
                onTap: () {
                  _updateSelectedItem(widget.items[index]);
                  Navigator.pop(context);
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _updateSelectedItem(String newItem) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(widget.recoveryKey, newItem);
    setState(() {
      selectedItem = newItem;
    });
    if (widget.onChanged != null) {
      widget.onChanged!(selectedItem);
    }
  }
}

String formatTimeOfDay(TimeOfDay timeOfDay) {
  //return 0925 for 9h25m
  return '${timeOfDay.hour.toString().padLeft(2, '0')}${timeOfDay.minute.toString().padLeft(2, '0')}';
}

String formatDateTime(DateTime dateTime) {
  //return 092532 for 9h25m32s
  return '${dateTime.hour.toString().padLeft(2, '0')}${dateTime.minute.toString().padLeft(2, '0')}${dateTime.second.toString().padLeft(2, '0')}';
}

String formatTimeOfDayAlt(TimeOfDay timeOfDay) {
  //return 09h25m
  return '${timeOfDay.hour.toString().padLeft(2, '0')}h${timeOfDay.minute.toString().padLeft(2, '0')}m';
}

String formatDateTimeAlt(DateTime dateTime) {
  //return 09h25m32s
  return '${dateTime.hour.toString().padLeft(2, '0')}h${dateTime.minute.toString().padLeft(2, '0')}m${dateTime.second.toString().padLeft(2, '0')}s';
}

Future<void> requestPermissions() async {
  await requestPermission(Permission.storage);
  await requestPermission(Permission.manageExternalStorage);
  await requestPermission(Permission.mediaLibrary);
  await requestPermission(Permission.camera);
  await requestPermission(Permission.photos);
}

Future<void> requestPermission(Permission permission) async {
  if (!await permission.status.isGranted) {
    await permission.request();
  }
}

MaterialColor orangeColor = MaterialColor(
  0xFFf07f34,
  <int, Color>{
    50: Colors.orange[50]!,
    100: Colors.orange[100]!,
    200: Colors.orange[200]!,
    300: Colors.orange[300]!,
    400: Colors.orange[400]!,
    500: Colors.orange[500]!,
    600: Colors.orange[600]!,
    700: Colors.orange[700]!,
    800: Colors.orange[800]!,
    900: Colors.orange[900]!,
  },
);

class CameraPage extends StatefulWidget {
  @override
  CameraPageState createState() => CameraPageState();
}

class CameraPageState extends State<CameraPage> {
  List<CameraDescription> cameras = [];
  late CameraController cameraController;
  late Future<void> initializeControllerFuture;
  bool isCameraInitialized = false;
  Uint8List? fileBytes;
  File? file;
  bool isFlashOn = false;
  int selectedCameraIndex = 0;
  double currentZoomLevel = 1.0;
  double maxZoomLevel = 1.0;
  Offset? _focusPoint;
  final GlobalKey _cameraKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    try {
      cameras = await availableCameras();
      cameraController = CameraController(
        cameras[selectedCameraIndex],
        ResolutionPreset.max,
      );

      initializeControllerFuture = cameraController.initialize();
      await initializeControllerFuture;

      // Get the maximum zoom level
      maxZoomLevel = await cameraController.getMaxZoomLevel();

      setState(() {
        isCameraInitialized = true;
      });
    } catch (e) {
      log('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: !isCameraInitialized
            ? const CircularProgressIndicator()
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Stack(
                children: [
                  if (fileBytes == null)
                    Align(
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onScaleUpdate: (ScaleUpdateDetails details) {
                          handleScaleUpdate(details);
                        },
                        onTapDown: (TapDownDetails details) {
                          onViewFinderTap(details);
                        },
                        child: CameraPreview(
                          cameraController,
                          key: _cameraKey,
                          child: _focusPoint != null
                            ? Positioned(
                              left: _focusPoint!.dx - 40,
                              top: _focusPoint!.dy - 40,
                              child: Container(
                                height: 80,
                                width: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white)
                                ),
                              ),
                            )
                            : null,
                        ),
                      ),
                    ),

                  


                  if (fileBytes == null)
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 50),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  isFlashOn = !isFlashOn;
                                });
                              },
                              child: Icon(
                                isFlashOn ? Icons.flash_on : Icons.flash_off,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (fileBytes == null)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 30),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            GestureDetector(
                              onTap: selectFromGallery,
                              child: const Icon(
                                Icons.photo_library,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                            GestureDetector(
                              onTap: takePicture,
                              child: const Icon(
                                Icons.camera_outlined,
                                size: 70,
                                color: Colors.orange,
                              ),
                            ),
                            GestureDetector(
                              onTap: switchCamera,
                              child: const Icon(
                                Icons.switch_camera,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (fileBytes != null)
                    Center(
                      child: Hero(
                        tag: fileBytes.toString(),
                        child: PhotoView(
                          imageProvider: Image.memory(fileBytes!).image,
                          enableRotation: true,
                          tightMode: true,
                          backgroundDecoration: const BoxDecoration(color: Colors.transparent),
                        ),
                      ),
                    ),

                  if (fileBytes != null)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 30),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            GestureDetector(
                              onTap: discardPhoto,
                              child: const Icon(
                                CupertinoIcons.clear_circled,
                                size: 70,
                                color: Colors.redAccent,
                              ),
                            ),
                            GestureDetector(
                              onTap: confirmPhoto,
                              child: const Icon(
                                CupertinoIcons.check_mark_circled,
                                size: 70,
                                color: Colors.lightGreenAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> takePicture() async {
    if (isFlashOn) {
      cameraController.setFlashMode(FlashMode.torch);
    }

    try {
      await initializeControllerFuture;
      final XFile image = await cameraController.takePicture();
      File tempfile = File(image.path);
      Uint8List fileData = await tempfile.readAsBytes();

      setState(() {
        file = tempfile;
        fileBytes = fileData;
      });
    } catch (e) {
      log('Error taking picture: $e');
    }

    if (isFlashOn) {
      cameraController.setFlashMode(FlashMode.off);
    }
  }

  void discardPhoto() {
    if (mounted) {
      setState(() {
        file = null;
        fileBytes = null;
      });
    }
  }

  void confirmPhoto() {
    Map result = {
      'bytes':fileBytes,
      'file':file,
    };
    Navigator.pop(context, result);
  }

  void switchCamera() async {
    selectedCameraIndex = (selectedCameraIndex + 1) % cameras.length;
    await initializeCamera();
  }

  Future<void> selectFromGallery() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null) {
        PlatformFile pickedFile = result.files.first;
        Uint8List fileData;

        if (pickedFile.bytes != null) {
          fileData = pickedFile.bytes!;
        } else {
          File file = File(pickedFile.path!);
          fileData = await file.readAsBytes();
        }

        setState(() {
          fileBytes = fileData;
        });
      } else {
        log('No file selected');
      }
    } catch (e) {
      log('Error selecting from gallery: $e');
    }
  }

  void handleScaleUpdate(ScaleUpdateDetails details) {
    double sensitivityFactor = 0.05; // Adjust this value to control sensitivity
    double newZoomLevel = currentZoomLevel + (details.scale - 1.0) * sensitivityFactor;

    if (newZoomLevel < 1.0) {
      newZoomLevel = 1.0;
    } else if (newZoomLevel > maxZoomLevel) {
      newZoomLevel = maxZoomLevel;
    }

    setState(() {
      currentZoomLevel = newZoomLevel;
      cameraController.setZoomLevel(currentZoomLevel);
    });
  }

  void onViewFinderTap(TapDownDetails details) {
    final Offset offset = details.localPosition;
    final RenderBox renderBox = _cameraKey.currentContext?.findRenderObject() as RenderBox;
    final Size size = renderBox.size;
    final Offset focusPoint = Offset(offset.dx / size.width, offset.dy / size.height);

    setState(() {
      _focusPoint = offset;
    });

    cameraController.setFocusPoint(focusPoint);
    cameraController.setExposurePoint(focusPoint);
  }
}

Future<Uint8List?> takePhotoBytes(BuildContext context) async {
  final Map result = await Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => CameraPage()),
  );

  Uint8List? fileBytes = result['bytes'];

  return fileBytes;
}

Future<File?> takePhoto(BuildContext context) async {
  final Map result = await Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => CameraPage()),
  );

  File? file = result['file'];

  return file;
}

Future<bool> takePhotoAndStore(BuildContext context, String prefix, String folder, Directory directory) async {
  final Uint8List? fileBytes = await Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => CameraPage()),
  );

  if (fileBytes != null) {
    File? storedFile = await storeFile(fileBytes, '${prefix}_IMG_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.jpg', folder, directory);
    if (storedFile != null) {
      showSnackbar(context, 'Foto armazenada com sucesso');
      return true;
    }
  }

  return false;
}

/*
class SmartCheckboxListTile extends StatefulWidget {
  final bool initialValue;
  final ValueChanged<bool?>? onChanged;
  final Widget title;
  final Widget? subtitle;
  final bool isThreeLine;
  final bool dense;
  final Widget? secondary;
  final bool selected;
  final Color? activeColor;
  final Color? checkColor;
  final ListTileControlAffinity controlAffinity;
  final bool autofocus;
  final EdgeInsetsGeometry? contentPadding;
  final ShapeBorder? shape;
  final Color? tileColor;
  final Color? selectedTileColor;

  SmartCheckboxListTile({
    Key? key,
    this.initialValue = false,
    this.onChanged,
    required this.title,
    this.subtitle,
    this.isThreeLine = false,
    this.dense = false,
    this.secondary,
    this.selected = false,
    this.activeColor,
    this.checkColor,
    this.controlAffinity = ListTileControlAffinity.platform,
    this.autofocus = false,
    this.contentPadding,
    this.shape,
    this.tileColor,
    this.selectedTileColor,
  }) : super(key: key);

  @override
  _SmartCheckboxListTileState createState() => _SmartCheckboxListTileState();
}

class _SmartCheckboxListTileState extends State<SmartCheckboxListTile> {
  bool check = false;

  @override
  void initState() {
    super.initState();
    check = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: check,
      onChanged: (bool? value) {
        setState(() {
          check = value ?? false;
        });
        if (widget.onChanged != null) {
          widget.onChanged!(value);
        }
      },
      title: widget.title,
      subtitle: widget.subtitle,
      isThreeLine: widget.isThreeLine,
      dense: widget.dense,
      secondary: widget.secondary,
      selected: widget.selected,
      activeColor: widget.activeColor,
      checkColor: widget.checkColor,
      controlAffinity: widget.controlAffinity,
      autofocus: widget.autofocus,
      contentPadding: widget.contentPadding,
      shape: widget.shape,
      tileColor: widget.tileColor,
      selectedTileColor: widget.selectedTileColor,
    );
  }
}*/


class CheckList extends StatefulWidget {
  final List<String>? entries;
  final ValueChanged<Map<String, bool>>? onChanged;
  final ValueChanged<String>? onItemChecked;
  final ValueChanged<String>? onItemUnchecked;
  final bool singleChoice;
  final List<String?> selectedItems;
  final Widget? title;
  final Widget? subtitle;
  final Color? activeColor;
  final Color? checkColor;
  final Icon? checkIcon;
  final Color? tileColor;
  final Color? selectedTileColor;
  final ShapeBorder? checkBoxShape;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? contentPadding;

  CheckList({
    Key? key,
    required this.entries,
    this.onChanged,
    this.onItemChecked,
    this.onItemUnchecked,
    this.singleChoice = false,
    this.selectedItems = const [],
    this.title,
    this.subtitle,
    this.activeColor,
    this.checkColor,
    this.checkIcon,
    this.tileColor,
    this.selectedTileColor,
    this.checkBoxShape,
    this.padding,
    this.contentPadding,
  }) : super(key: key);

  @override
  _CheckListState createState() => _CheckListState();
}

class _CheckListState extends State<CheckList> {
  late Map<String, ValueNotifier<bool>> entriesNotifiers;

  @override
  void initState() {
    super.initState();
    entriesNotifiers = {
      for (String key in widget.entries!)
        key: ValueNotifier(widget.selectedItems.contains(key)),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        if(widget.title != null || widget.subtitle != null)
          ListTile(
            title: widget.title,
            subtitle: widget.subtitle,
          ),

        for (String key in entriesNotifiers.keys)
          if (widget.singleChoice)
            SelectButton(
              title: Text(key),
              valueNotifier: entriesNotifiers[key]!,
              checkIcon: CupertinoIcons.circle_fill,
              checkBoxIcon: CupertinoIcons.circle,
              checkBoxColor: null,
              unCheckBoxIcon: CupertinoIcons.circle,
              tapOutside: true,
              onValueChanged: (value) {
                if (value) {
                  for (String k in entriesNotifiers.keys) {
                    if (k != key) {
                      entriesNotifiers[k]!.value = false;
                    }
                  }
                  if(widget.onItemChecked != null){
                    widget.onItemChecked!(key);
                  }
                }else if(widget.onItemUnchecked != null && value != true){
                  widget.onItemUnchecked!(key);
                }
                if (widget.onChanged != null) {
                  widget.onChanged!(
                    entriesNotifiers.map((k, v) => MapEntry(k, v.value)),
                  );
                }
              },
            )
          else
            SelectButton(
              title: Text(key),
              valueNotifier: entriesNotifiers[key]!,
              tapOutside: true,
              onValueChanged: (value) {
                if (widget.onChanged != null) {
                  widget.onChanged!(
                    entriesNotifiers.map((k, v) => MapEntry(k, v.value)),
                  );
                }
                if(widget.onItemChecked != null && value == true){
                  widget.onItemChecked!(key);
                }
                if(widget.onItemUnchecked != null && value != true){
                  widget.onItemUnchecked!(key);
                }
              },
            ),
      ],
    );
  }

  @override
  void dispose() {
    for (var notifier in entriesNotifiers.values) {
      notifier.dispose();
    }
    super.dispose();
  }
}

class SelectButton extends StatefulWidget {
  final ValueNotifier<bool> valueNotifier;
  final Text title;
  final MainAxisAlignment alignment;
  final VerticalDirection verticalDirection;

  final IconData? checkIcon;
  final Color? checkColor;
  final double? checkIconSize;

  final IconData? unCheckIcon;
  final Color? unCheckColor;
  final double? unCheckIconSize;

  final IconData? checkBoxIcon;
  final Color? checkBoxColor;
  final double? checkBoxIconSize;

  final IconData? unCheckBoxIcon;
  final Color? unCheckBoxColor;
  final double? unCheckBoxIconSize;

  final Widget? prefix;
  final EdgeInsetsGeometry contentPadding;
  final BoxShape boxShape;
  final Color textColor;
  final Color selectedTextColor;
  final Color tileColor;
  final Color selectedTileColor;
  final bool tapOutside;

  final ValueChanged<bool>? onCheck;
  final ValueChanged<bool>? onUncheck;
  final ValueChanged<bool>? onValueChanged;

  final Widget? child;

  SelectButton({
    Key? key,
    required this.valueNotifier,
    required this.title,
    this.alignment = MainAxisAlignment.spaceBetween,
    this.verticalDirection = VerticalDirection.down,

    this.checkIcon = Icons.check,
    this.checkColor,
    this.checkIconSize = 15,

    this.unCheckIcon,
    this.unCheckColor,
    this.unCheckIconSize,

    this.checkBoxIcon = CupertinoIcons.square_fill,
    this.checkBoxColor = Colors.lightBlueAccent,
    this.checkBoxIconSize,

    this.unCheckBoxIcon = CupertinoIcons.square,
    this.unCheckBoxColor,
    this.unCheckBoxIconSize,

    this.prefix,
    this.contentPadding = const EdgeInsets.all(10),
    this.boxShape = BoxShape.rectangle,
    this.textColor = Colors.white,
    this.selectedTextColor = Colors.white,
    this.tileColor = Colors.transparent,
    this.selectedTileColor = Colors.transparent,
    this.tapOutside = false,

    this.onCheck,
    this.onUncheck,
    this.onValueChanged,

    this.child,
  }) : super(key: key);

  @override
  _SelectButtonState createState() => _SelectButtonState();
}

class _SelectButtonState extends State<SelectButton> {
  bool check = false;
  bool selected = false;
  final FocusNode focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    check = widget.valueNotifier.value;

    widget.valueNotifier.addListener(() {
      if(mounted){
        setState(() {
          check = widget.valueNotifier.value;
        });
      }else{
        check = widget.valueNotifier.value;
      }
    });

    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        setState(() {
          selected = false;
        });
      }
    });
  }

  @override
  void dispose() {
    widget.valueNotifier.removeListener(() {});
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: widget.prefix,
      title: widget.title,
      subtitle: widget.child,
      trailing: IconButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          updateCheck(!check);
        },
        icon: Stack(
          alignment: Alignment.center,
          children: [
            if (!check)
              Icon(
                widget.unCheckBoxIcon,
                color: widget.unCheckBoxColor,
                size: widget.unCheckBoxIconSize,
              ),
            if (check)
              Icon(
                widget.checkBoxIcon,
                color: widget.checkBoxColor,
                size: widget.checkBoxIconSize,
              ),
            if (!check && widget.unCheckIcon != null)
              Icon(
                widget.unCheckIcon,
                color: widget.unCheckColor,
                size: widget.unCheckIconSize,
              ),
            if (check)
              Icon(
                widget.checkIcon,
                color: widget.checkColor,
                size: widget.checkIconSize,
              ),
          ],
        ),
      ),
      selectedColor: widget.selectedTextColor,
      textColor: widget.textColor,
      contentPadding: widget.contentPadding,
      onTap: () {
        if (widget.tapOutside) {
          updateCheck(!check);
        } else if(mounted) {
          setState(() {
            selected = true;
          });
          focusNode.requestFocus();
        }
      },
      selected: selected,
      focusNode: focusNode,
      tileColor: widget.tileColor,
      selectedTileColor: widget.selectedTileColor,
      enableFeedback: true,
      //minVerticalPadding:,
      //minLeadingWidth:,
      //minTileHeight:,
      //titleAlignment:,
      
    );
    
    /*Focus(
      focusNode: focusNode,
      child: GestureDetector(
        onTap: () {
          if (widget.tapOutside) {
            updateCheck(!check);
          } else {
            setState(() {
              selected = true;
            });
            focusNode.requestFocus();
          }
        },
        child: Container(
          color: selected ? widget.selectedTileColor : widget.tileColor,
          padding: widget.contentPadding,
          child: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: widget.alignment,
                crossAxisAlignment: CrossAxisAlignment.center,
                verticalDirection: widget.verticalDirection,
                children: [
                  if (widget.prefix != null) widget.prefix!,

                  widget.title,
                  
                  IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      updateCheck(!check);
                    },
                    icon: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (!check)
                          Icon(
                            widget.unCheckBoxIcon,
                            color: widget.unCheckBoxColor,
                            size: widget.unCheckBoxIconSize,
                          ),
                        if (check)
                          Icon(
                            widget.checkBoxIcon,
                            color: widget.checkBoxColor,
                            size: widget.checkBoxIconSize,
                          ),
                        if (!check && widget.unCheckIcon != null)
                          Icon(
                            widget.unCheckIcon,
                            color: widget.unCheckColor,
                            size: widget.unCheckIconSize,
                          ),
                        if (check)
                          Icon(
                            widget.checkIcon,
                            color: widget.checkColor,
                            size: widget.checkIconSize,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.child != null) widget.child!,
            ],
          ),
        ),
      ),
    );*/
  }

  void updateCheck(bool value) {
    if(mounted){
      setState(() {
        check = value;
        selected = true;
      });
    }
    widget.valueNotifier.value = value;
    focusNode.requestFocus();
    if (widget.onValueChanged != null) {
      widget.onValueChanged!(value);
    }
    if (value == true && widget.onCheck != null) {
      widget.onCheck!(value);
    }
    if (value == false && widget.onUncheck != null) {
      widget.onUncheck!(value);
    }
  }
}