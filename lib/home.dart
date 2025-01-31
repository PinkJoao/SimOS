import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'dart:developer';
import 'dart:convert' show utf8;
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:align_positioned/align_positioned.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_range_picker/time_range_picker.dart' as time_range;
import 'package:lecle_downloads_path_provider/lecle_downloads_path_provider.dart';

import 'mylib.dart';

class HomePage extends StatefulWidget {
  final String? token;

  const HomePage({Key? key, required this.token}) : super(key: key);

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {

  ImagePicker imagePicker = ImagePicker();

  late SharedPreferences preferences;
  late Directory downloadDir;
  late OneDriveIDs oneDriveIDs;

  int maxPhotos = 20;

  String testFolder = 'testFolderTI';
  String oneDriveFolder = 'Ordens West Solar';
  String uploadfolder = 'Ordens West Solar';
  String pendingFolder = 'Pendentes SimOS';
  String storageFolder = 'Fotos SimOS';
  String trashFolder = 'Lixeira SimOS';
  String currentDateString = DateFormat('yyyyMMdd').format(DateTime.now());
  String currentDateStringAlt = DateFormat('dd/MM/yyyy').format(DateTime.now());

  CarouselController mainCarouselController = CarouselController();

  TextEditingController obsTextController = TextEditingController();
  String? obsText;

  TextEditingController orderNumberTextController = TextEditingController();
  String? orderNumberText;

  String? client;
  String? operator;
  String? lastLogDate;

  TimeOfDay? startTime;
  TimeOfDay? endTime;
  DateTime? executionDate;

  List<File> photoFiles = [];
  List<Widget> photoWidgets = [];

  List<List<File>> pendingFileLists = [];
  List<List<File>> sentFileLists = [];
  List<File> selectedFiles = [];

  List<String> logList = [];
  List<String> logHistory = [];

  bool logSended = false;
  bool loading = false;
  bool drawerLoading = false;
  bool offlineMode = true;
  bool executionCheck = true;
  bool adminTrigger1 = false;
  bool adminTrigger2 = false;
  bool adminMode = false;

  List<String> operators = [
    'EVANDI',
    'EDINELMA',
    'PAULO',
    'GABRIEL WEVERTON',
    'RAFAEL WEMERSON',
    'HITALO KEVEM',
    'VICUNHA 03 MANHÃ', 
    'VICUNHA 03 TARDE', 
    'VICUNHA 03 NOITE',
  ];

  @override
  void initState() {
    super.initState();
    initialize();
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: AppBar(
        title: Text(adminMode == false ?'Símic | SimOS' : 'Admin | SimOS'),
        iconTheme: IconThemeData(color: Colors.grey[900]),
      ),
      drawerScrimColor: Colors.transparent,
      drawerEnableOpenDragGesture: false,
      drawer: loading
      ? null
      : Container(
          width: getTotalWidth(context),
          height: getTotalHeight(context),
          child: Drawer(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: GestureDetector(
              onHorizontalDragEnd: (v) {/* do nothing */},
              child: Row(
                children: [
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                    child: Container(
                      width: getTotalWidth(context) / 10 * 7,
                      height: getTotalHeight(context),
                      color: Colors.grey[900],
                      child: Stack(
                        children: [
                          SingleChildScrollView(
                            padding: EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                DrawerHeader(
                                  decoration: const BoxDecoration( color: Color(0xFFf07f34), ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.grey[900],
                                        ),
                                        child: GestureDetector(
                                          child: Image.asset('assets/images/simicLogo.png'),
                                          onLongPress: () {
                                            HapticFeedback.mediumImpact();
                                            if(mounted){
                                              setState(() {
                                                adminTrigger1 = !adminTrigger1;

                                                if(adminTrigger1 && adminTrigger2){
                                                  adminMode = true;
                                                  uploadfolder = testFolder;
                                                  showSnackbar(context, 'Admin mode on');
                                                  updateIDs();
                                                }else{
                                                  adminMode = false;
                                                  uploadfolder = oneDriveFolder;
                                                  updateIDs();
                                                }
                                              });
                                            }
                                            HapticFeedback.vibrate();
                                          },
                                        ),
                                      ),

                                      const SizedBox( height: 10, ),

                                      Text(
                                        'Fotos pendentes',
                                        style: TextStyle(
                                          color: Colors.grey[900],
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold
                                        ),
                                      ),

                                      Text(
                                        '${pendingFileLists.sublist(0, pendingFileLists.length < maxPhotos ? pendingFileLists.length : maxPhotos).length}/$maxPhotos',
                                        style: TextStyle(
                                          color: Colors.grey[900],
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold
                                        ),
                                      ),
                                    ],
                                  )
                                ),
                                const SizedBox(),

                                //for(List<File> fileList in pendingFileLists)
                                for(List<File> fileList in pendingFileLists.sublist(0, pendingFileLists.length < maxPhotos ? pendingFileLists.length : maxPhotos))
                                  SelectButton(
                                    valueNotifier: ValueNotifier(false), 
                                    title: Text(fileList.first.path.split('/').last.split('_').first),
                                    child: CarouselSlider(
                                      items: [for(File file in fileList)
                                        GestureDetector(
                                          onTap: () { showInFullScreen(file.path, context); },
                                          child: Hero(
                                            tag: file.path,
                                            child: Image.file(file),
                                          ),
                                        )
                                      ],
                                      options: CarouselOptions(
                                        height: getTotalHeight(context) / 4,
                                        viewportFraction: 1,
                                        enableInfiniteScroll: false,
                                        enlargeCenterPage: true,
                                      ),
                                    ),
                                    onCheck: (value){
                                      selectedFiles.addAll(fileList);
                                      log(selectedFiles.toString());
                                    },
                                    onUncheck: (value){
                                      selectedFiles.removeWhere((element) => fileList.contains(element));
                                      log(selectedFiles.toString());
                                    },
                                  )
                              ] //+ pendingWidgets,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft, 
                          end: Alignment.centerRight,
                          stops: [0 , 0.5],
                          colors: [
                            Color.fromARGB(155, 0, 0, 0), 
                            Colors.transparent,
                          ]
                        )
                      ),
                      child: Stack(
                        children: [
                          
                          GestureDetector(
                            onTap: drawerLoading
                            ? null
                            : () { Navigator.pop(context); },
                            onHorizontalDragEnd: drawerLoading
                            ? null
                            : (v) { Navigator.pop(context); },
                          ),

                          AlignPositioned(
                            alignment: Alignment.bottomCenter,
                            touch: Touch.inside,
                            moveByChildHeight: -2,
                            child: FloatingActionButton(
                              heroTag: UniqueKey().toString(),
                              backgroundColor: Colors.redAccent,
                              onPressed: drawerLoading
                                ? null
                                : () async { await deleteSelected(); },
                              child: const Icon(Icons.delete_forever_rounded),
                            ),
                          ),

                          AlignPositioned(
                            alignment: Alignment.bottomCenter,
                            touch: Touch.inside,
                            moveByChildHeight: -0.5,
                            child: FloatingActionButton(
                              heroTag: UniqueKey().toString(),
                              backgroundColor: drawerLoading || offlineMode
                              ? Colors.grey
                              : Colors.greenAccent,
                              onPressed: drawerLoading || offlineMode
                                ? null
                                : () async { await uploadSelected(); },
                              child: const Icon(Icons.cloud_upload_rounded),
                            ),
                          ),
                        ],
                      ),
                    )
                  ),
                ],
              ),
            ),
          ),
        ),
      onDrawerChanged: (bool isDrawerOpened) async {
        if (isDrawerOpened) {
          await onDrawerOpened();
        } else if (!isDrawerOpened) {
          await onDrawerClosed();
        }
      },
      endDrawer: loading
      ? null
      : Container(
          width: getTotalWidth(context),
          height: getTotalHeight(context),
          child: Drawer(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: GestureDetector(
              onHorizontalDragEnd: (v) {/* do nothing */},
              child: Row(
                children: [
                  Expanded(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            stops: [0 , 0.5],
                            colors: [
                              Color.fromARGB(155, 0, 0, 0), 
                              Colors.transparent,
                            ]
                          )
                        ),
                        child: GestureDetector(
                          onTap: () { Navigator.pop(context); },
                          onHorizontalDragEnd: (v) { Navigator.pop(context); },
                        ),
                      )
                    ),
                  ),
                  Container(
                    width: getTotalWidth(context) / 10 * 7,
                    height: getTotalHeight(context),
                    color: Colors.grey[900],
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          padding: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DrawerHeader(
                                decoration: const BoxDecoration( color: Color(0xFFf07f34), ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.grey[900],
                                      ),
                                      child: GestureDetector(
                                        child: Image.asset('assets/images/simicLogo.png'),
                                        onLongPress: () {
                                          HapticFeedback.mediumImpact();
                                          if(mounted){
                                            setState(() {
                                              adminTrigger2 = !adminTrigger2;

                                              if(adminTrigger1 && adminTrigger2){
                                                adminMode = true;
                                                uploadfolder = testFolder;
                                                showSnackbar(context, 'Admin mode on');
                                                updateIDs();
                                              }else{
                                                adminMode = false;
                                                uploadfolder = oneDriveFolder;
                                                updateIDs();
                                              }
                                            });
                                          }
                                          HapticFeedback.vibrate();
                                        },
                                      ),
                                    ),

                                    const SizedBox( height: 10, ),

                                    Text(
                                      'Fotos enviadas',
                                      style: TextStyle(
                                        color: Colors.grey[900],
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold
                                      ),
                                    ),

                                    Text(
                                      'Últimas $maxPhotos',
                                      style: TextStyle(
                                        color: Colors.grey[900],
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold
                                      ),
                                    ),
                                  ],
                                )
                              ),
                              const SizedBox(),

                              for(List<File> fileList in sentFileLists.sublist(0, sentFileLists.length < maxPhotos ? sentFileLists.length : maxPhotos))
                                ListTile(
                                  title: Text(fileList.first.path.split('/').last.split('_').first),
                                  subtitle: CarouselSlider(
                                    items: [for(File file in fileList) 
                                      GestureDetector(
                                        onTap: () { showInFullScreen(file.path, context); },
                                        child: Hero(
                                          tag: file.path,
                                          child: Image.file(file),
                                        ),
                                      )
                                    ],
                                    options: CarouselOptions(
                                      height: getTotalHeight(context) / 4,
                                      viewportFraction: 1,
                                      enableInfiniteScroll: false,
                                      enlargeCenterPage: true,
                                    ),
                                  ),
                                )
                                // image slider
                            ]// + sentActivityWidgets,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      onEndDrawerChanged: (bool isEndDrawerOpened) async {
        if (isEndDrawerOpened) {
          //await onDrawerOpened();
        } else if (!isEndDrawerOpened) {
          //await onDrawerClosed();
        }
      },
      body: Center(
        child: loading
        ? CircularProgressIndicator( color: orangeColor, )
        : Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: SafeMenuButton(
                      defaultItem: 'Selecionar operador',
                      items: operators,
                      recoveryKey: 'operator',
                      onChanged: (selectedItem) {
                        setState(() { operator = selectedItem; });
                        setClient();
                      },
                    )
                  ),
                  
                  const SizedBox(width: 8),
                        
                  Expanded(
                    child: ElevatedButton(
                      onPressed: loading 
                      ? null 
                      : selectExecutionDate,
                      child: Text(executionDate == null ? 'Data de execução' : DateFormat('dd/MM/yyyy').format(executionDate!)
                      )
                    )
                  ),

                  if(operator == 'HITALO KEVEM')
                    const SizedBox(width: 8),
                  if (operator == 'HITALO KEVEM')
                    Expanded(
                      child: SafeMenuButton(
                        defaultItem: 'Cliente',
                        items: const ['WEST', 'SOLAR'],
                        recoveryKey: 'client',
                        onChanged: (selectedItem) {
                          setClient(selectedItem);
                        },
                      )
                    )
                ],
              ),
              
              Expanded(
                child: Stack(
                  children: [
                    CarouselSlider(
                      carouselController: mainCarouselController,
                      items: photoWidgets,
                      options: CarouselOptions(
                        height: getTotalHeight(context),
                        viewportFraction: 1,
                        enableInfiniteScroll: false,
                        enlargeCenterPage: true,
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        mainAxisSize: MainAxisSize.max,
                        children: photoWidgets.isEmpty
                        ? []
                        : [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 0, 0, 10),
                            child: IconButton(
                              onPressed: () async { await mainCarouselController.previousPage(); },
                              icon: const Icon(Icons.arrow_back_ios_rounded)
                            )
                          ),

                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              executionCheck == true
                              ? 'ORDEM EXECUTADA'
                              : 'ORDEM CANCELADA',
                              style: TextStyle(
                                fontSize: 16,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 5,
                                  )
                                ],
                                fontWeight: FontWeight.bold,
                                color: executionCheck == true
                                ? Colors.greenAccent
                                : Colors.red
                              ),
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Switch(
                              value: executionCheck,
                              activeColor: Colors.greenAccent,
                              inactiveTrackColor: Colors.red.withAlpha(150),
                              inactiveThumbColor: Colors.red,
                              onChanged: (bool value) {
                                setState(() { executionCheck = value; });
                              },
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 0, 10, 10),
                            child: IconButton(
                              onPressed: () async {
                                await mainCarouselController.nextPage();
                              },
                              icon: const Icon(Icons.arrow_forward_ios_rounded)
                            ),
                          ),
                        ],
                      )
                    )
                  ],
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: photoFiles.isEmpty || photoWidgets.isEmpty
                      ? ElevatedButton.styleFrom( backgroundColor: Colors.redAccent, )
                      : null,
                      onPressed: loading 
                      ? null 
                      : addPhoto,
                      child: const Text('Adicionar foto',)
                    )
                  ),

                  const SizedBox(width: 8),
                  
                  Expanded(
                    child: ElevatedButton(
                      style: endTime == null || startTime == null
                      ? ElevatedButton.styleFrom( backgroundColor: Colors.redAccent, )
                      : null,
                      onPressed: loading 
                      ? null 
                      : selectWorkTime,
                      child: const Text('Tempo de execução'),
                    )
                  ),
                ],
              ),

              TextField(
                controller: orderNumberTextController,
                onChanged: loading
                ? null
                : (value) {
                  setState(() { orderNumberText = value; });
                },
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: InputDecoration(
                  hintText: 'Número da ordem',
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: orderNumberText == null || orderNumberText!.isEmpty || orderNumberText!.length < 8
                      ? Colors.redAccent
                      : Colors.grey[600]!,
                    ),
                  ),
                  border: const OutlineInputBorder(),
                    hintStyle: TextStyle(
                    color: Colors.grey[600],
                  ),
                  contentPadding: const EdgeInsets.symmetric( horizontal: 15, vertical: 10, ),
                ),
              ),

              TextField(
                controller: obsTextController,
                onChanged: loading
                ? null
                : (value) {
                  setState(() { obsText = value; });
                },
                decoration: InputDecoration(
                  hintText: 'Observações',
                  border: const OutlineInputBorder(),
                  hintStyle: TextStyle( color: Colors.grey[600], ),
                  contentPadding: const EdgeInsets.symmetric( horizontal: 15, vertical: 10, ),
                ),
              ),

              ElevatedButton(
                onPressed: !loading && (photoFiles.isNotEmpty && photoWidgets.isNotEmpty) && orderNumberText != null && orderNumberText!.length == 8 && (endTime != null && startTime != null)
                ? () async {
                  if(pendingFileLists.length < maxPhotos){
                    await storeReport();
                  }else{
                    showSnackbar(context, 'Limite de $maxPhotos ordens pendentes atingido');
                  }
                }
                : null,
                child: const Text('Guardar atividade')
              ),
            ],
          ),
        )
      ),
    );
  }

  Future updateIDs() async {
    if (widget.token != null) {
      OneDriveIDs? ids = await getOneDriveIDs(widget.token, uploadfolder);
      if (ids != null) {
        oneDriveIDs = ids;
        offlineMode = false;
      } else {
        showSnackbar(context, 'Atenção, SimOS está em modo OFFLINE');
      }
    } else {
      showSnackbar(context, 'Atenção, SimOS está em modo OFFLINE');
    }
  }

  Future initialize() async {/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    setLoading(true);

    downloadDir = await DownloadsPath.downloadsDirectory() ?? await getApplicationDocumentsDirectory();
    preferences = await SharedPreferences.getInstance();
    operator = preferences.getString('operator');
    lastLogDate = preferences.getString('lastLogDate');
    logHistory = preferences.getStringList('logHistory') ?? logHistory;

    await getStoredPhotos();

    if (widget.token != null) {
      OneDriveIDs? ids = await getOneDriveIDs(widget.token, uploadfolder);
      if (ids != null) {
        oneDriveIDs = ids;
        offlineMode = false;
      } else {
        showSnackbar(context, 'Atenção, SimOS está em modo OFFLINE');
      }
    } else {
      showSnackbar(context, 'Atenção, SimOS está em modo OFFLINE');
    }

    setClient();

    await uploadLog();

    setLoading(false);
  }

  Future onDrawerOpened() async {//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    if (loading) {
      return null;
    }
  }

  Future onDrawerClosed() async {//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    if (loading) {
      return null;
    }
  }

  Future getStoredPhotos() async {
    List<File> pendingFiles = await getDirectoryFiles(pendingFolder, downloadDir) ?? [];
    List<File> sentFiles = await getDirectoryFiles(storageFolder, downloadDir) ?? [];
    
    pendingFileLists.clear();
    sentFileLists.clear();

    List<File> auxList = [];

    for(File file in pendingFiles){
      String fileName = file.path.split('/').last.split('.').first;
      if(auxList.isEmpty || !fileName.endsWith('_0')){
        auxList.add(file);
      }else{
        pendingFileLists.add(List.from(auxList));
        auxList.clear();
        auxList.add(file);
      }
    }

    if(auxList.isNotEmpty){
      pendingFileLists.add(List.from(auxList));
      auxList.clear();
    }

    for(File file in sentFiles){
      String fileName = file.path.split('/').last.split('.').first;
      if(auxList.isEmpty || !fileName.endsWith('_0')){
        auxList.add(file);
      }else{
        sentFileLists.add(List.from(auxList));
        auxList.clear();
        auxList.add(file);
      }
    }

    if(auxList.isNotEmpty){
      sentFileLists.add(List.from(auxList));
      auxList.clear();
    }

    pendingFileLists.sort((a,b) => a.first.path.split('/').last.split('-').last.compareTo(b.first.path.split('/').last.split('-').last));
    sentFileLists.sort((a,b) => b.first.path.split('/').last.split('-').last.compareTo(a.first.path.split('/').last.split('-').last));

    if(mounted){
      setState(() {});
    }
  }
  
  String getFileName(String fileExtension, [int? index]) {/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    String executionDateString = executionDate != null
    ? DateFormat('yyyyMMdd').format(executionDate!)
    : currentDateString;
    String startTimeString = formatTimeOfDay(startTime!);
    String endTimeString = formatTimeOfDay(endTime!);
    String indexString = index != null ? '_${index.toString()}' : '';
    //String fileName = '${executionDateString}_${operator}_${orderNumberText}_${startTimeString}_${endTimeString}${indexString}.${fileExtension}';
    String fileName = '${client}-${orderNumberText}-${operator}-DATE-${executionDateString}-START-${startTimeString}-END-${endTimeString}-${executionCheck.toString().toUpperCase()}-${currentDateString}_${formatDateTime(DateTime.now())}${indexString}.${fileExtension}';

    return fileName;
  }

  Future storeReport() async {///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    if (loading == true) {
      return null;
    }

    setLoading(true);

    List<List> fileTuples = [];

    for (File photoFile in photoFiles) {
      int index = photoFiles.indexOf(photoFile);
      fileTuples.add([
        File(photoFile.path).readAsBytesSync(),
        getFileName(photoFile.path.split('.').last, photoFiles.indexOf(photoFile))
      ]);
    }

    if (obsText != null) {
      fileTuples.add([Uint8List.fromList(utf8.encode(obsText!)), getFileName('txt')]);
    }

    List<File> activityFileList = [];
    List<List> willBeRemoved = [];

    for (List tuple in fileTuples) {
      int index = fileTuples.indexOf(tuple);
      File? newFile = await storeFile(tuple[0], tuple[1], pendingFolder, downloadDir);
      if (newFile != null) {
        activityFileList.add(newFile);
        updateLogHistory('Arquivo [${newFile.path.split('/').last}] foi armazenado');
        if (!tuple[1].endsWith('txt')) {
          willBeRemoved.add([photoFiles[index], photoWidgets[index]]);
        }
      }
    }

    for (List removeTuple in willBeRemoved) {
      photoFiles.remove(removeTuple[0]);
      photoWidgets.remove(removeTuple[1]);
    }

    await getStoredPhotos();

    setLoading(false);

    if (photoFiles.isEmpty) {
      await clearData();
      showSnackbar(context, 'Armazenamento concluído');
    } else {
      showSnackbar(context, 'Algumas fotos NÃO foram armazenadas');
    }
  }

  Future<void> selectExecutionDate() async {/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    DateTime? selectedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2023),
        lastDate: DateTime.now());

    if (selectedDate != null) {
      setState(() {
        executionDate = selectedDate;
      });
    }
  }

  Future<void> selectWorkTime() async {///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    final result = await time_range.showTimeRangePicker(
      context: context,
      strokeColor: Colors.orange[500],
      handlerColor: Colors.orange[600],
      selectedColor: Colors.orange[700],
      fromText: 'Início',
      toText: 'Término',
      labels: ["0h", "3h", "6h", "9h", "12h", "15h", "18h", "21h"].asMap().entries.map((e) {return time_range.ClockLabel.fromIndex(idx: e.key, length: 8, text: e.value);}).toList(),
      maxDuration: const Duration(hours: 12),
      minDuration: const Duration(minutes: 1),
      interval: const Duration(minutes: 1),
      clockRotation: 180,
      ticks: 24,
      start: TimeOfDay(hour: (TimeOfDay.now().hour - 5), minute: (TimeOfDay.now().minute)),
      end: TimeOfDay.now(),
    );

    if (result != null) {
      setState(() {
        startTime = result.startTime;
        endTime = result.endTime;
      });
    }
  }

  Future<void> addPhoto() async {/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    File? image;
    
    try {
      image = await takePhoto(context);

    } catch (e) {
      showSnackbar(context, 'Falha ao adicionar foto');
      log('Error adding photo: $e');
    }

    log(image.toString());

    if(image == null){
      return;
    }

    log(image.path);
      
    setState(() {
      photoFiles.insert(0, image!);

      UniqueKey stackKey = UniqueKey();
      photoWidgets.insert(
        0,
        Stack(
          key: stackKey, 
          children: [
            GestureDetector(
              onTap: () {
                showInFullScreen(image!.path, context);
              },
              child: Hero(
                tag: stackKey,
                child: Image.file(image),
              ),
            ),

            Positioned(
              top: 5,
              right: 15,
              child: GestureDetector(
                onTap: () {
                  int index = photoWidgets.indexOf(photoWidgets.firstWhere((widget) => widget.key == stackKey));
                  setState(() {
                    photoFiles.removeAt(index);
                    photoWidgets.removeAt(index);
                  });
                },
                child: const Text(
                  'x',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 40.0,
                  ),
                ),
              ),
            ),
          ]
        )
      );
    });
  }

  Future uploadSelected() async {//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    if (loading == true || drawerLoading == true) {
      return null;
    }
    setState(() {
      loading = true;
      drawerLoading = true;
    });

    if (offlineMode == false) {
      for (File file in selectedFiles) {
        String fullFileName = file.path.split('/').last;
        String fileName = fullFileName.split('.').first;
        String extension = fullFileName.split('.').last;
        bool? check = await uploadFile(file, fileName, extension, oneDriveIDs);
        if (check == true) {
          await moveFile(fullFileName, pendingFolder, storageFolder, downloadDir);
          updateLogHistory('Arquivo [$fullFileName] foi enviado');
        }else{
          updateLogHistory('Falha no envio do arquivo [$fullFileName]');
        }
      }
    }

    await getStoredPhotos();
    //await getPendingActivities();
    //await getSentActivities();

    await uploadLog();

    setState(() {
      loading = false;
      drawerLoading = false;
    });
  }

  updateLogHistory(String event) {
    logHistory = preferences.getStringList('logHistory') ?? logHistory;

    logHistory.add(event + ' em [${DateFormat('dd/MM/yyyy').format(DateTime.now())}] às [${formatDateTimeAlt(DateTime.now())}]');

    preferences.setStringList('logHistory', logHistory);
  }

  Future uploadLog() async {
    if (offlineMode || operator == null || client == null || lastLogDate == currentDateString) {
      return null;
    }


    String fileName = client! + '-LOG-' + operator! + '-' + currentDateString + '-' + formatTimeOfDay(TimeOfDay.now());

    String logTitle = 'Histórico de eventos da data [$currentDateStringAlt] enviado por [${operator!}] às ${formatTimeOfDayAlt(TimeOfDay.now())}:';

    List<File>? pendingFiles = await getDirectoryFiles(pendingFolder, downloadDir);
    List<File>? sentFiles = await getDirectoryFiles(storageFolder, downloadDir);
    List<File>? deletedFiles = await getDirectoryFiles(trashFolder, downloadDir);

    List<String> eventStrings = ['\n\nEventos registrados:'];
    List<String> pendingFilesStrings = ['\n\nArquivos pendentes no dispositivo:'];
    List<String> sentFilesStrings = ['\n\nArquivos enviados por este dispositivo:'];
    List<String> deletedFilesStrings = ['\n\nArquivos excluídos neste dispositivo:'];

    if(logHistory.isNotEmpty){
      eventStrings.addAll(logHistory);
    }else{
      eventStrings = ['\n\nNenhum evento foi registrado neste dispositivo.'];
    }

    if(pendingFiles != null && pendingFiles.isNotEmpty){
      for (File file in pendingFiles) {
        pendingFilesStrings.add(file.path.split('/').last);
      }
    }else{
      pendingFilesStrings = ['\n\nNão foram encontrados arquivos pendentes neste dispositivo.'];
    }

    if(sentFiles != null && sentFiles.isNotEmpty){
      for (File file in sentFiles) {
        sentFilesStrings.add(file.path.split('/').last);
      }
    }else{
      sentFilesStrings = ['\n\nNão foram encontrados arquivos enviados neste dispositivo.'];
    }
  
    if(deletedFiles != null && deletedFiles.isNotEmpty){
      for (File file in deletedFiles) {
        deletedFilesStrings.add(file.path.split('/').last);
      }
    }else{
      deletedFilesStrings = ['\n\nNão foram encontrados arquivos excluídos neste dispositivo.'];
    }

    String logText = logTitle + eventStrings.join('\n') + pendingFilesStrings.join('\n') + sentFilesStrings.join('\n') + deletedFilesStrings.join('\n');

    bool? check = await uploadText(fileName, logText, oneDriveIDs); 
    if (check == true) {
      preferences.setString('lastLogDate', currentDateString);
      preferences.setStringList('logHistory', []);
    }
  }

  Future deleteSelected() async {//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    if (loading == true || drawerLoading == true) {
      return null;
    }
    for (File file in selectedFiles) {
      String fileName = file.path.split('/').last;
      await moveFile(fileName, pendingFolder, trashFolder, downloadDir);
      updateLogHistory('Arquivo [$fileName] foi excluído');
    }
    await getStoredPhotos();
  }

  void setClient([String? newClient]){
    if(newClient != null){
      setState(() {
        client = newClient;
      });
      return;
    }

    if (operator == 'EVANDI' || operator == 'EDINELMA' || operator == 'PAULO') {
      setState(() {
        client = 'SOLAR';
      });
      return;
    } 
    
    if (operator == 'GABRIEL WEVERTON' || operator == 'RAFAEL WEMERSON') {
      setState(() {
        client = 'WEST';
      });
      return;
    }

    if (operator == 'VICUNHA 03 MANHÃ' || operator == 'VICUNHA 03 TARDE' || operator == 'VICUNHA 03 NOITE') {
      setState(() {
        client = 'VICUNHA';
      });
      return;
    }
    
    if (operator == 'HITALO KEVEM') {
      setState(() {
        client = preferences.getString('client');
      });
      print('object');
      return;
    }
  }

  void setLoading(bool set){
    setState(() {
      loading = set;
    });
  }

  Future clearData() async {///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    if (loading == true) {
      return null;
    }
    /*
    print('__________________________________________');
    print('');
    print('photoFiles:    ' + photoFiles.toString()   );
    print('photoWidgets:  ' + photoWidgets.toString() );
    print('orderNumberText:  ' + orderNumberText.toString() );
    print('obsText:       ' + obsText.toString()      );
    print('executionDate: ' + executionDate.toString());
    print('startTime:     ' + startTime.toString()    );
    print('endTime:       ' + endTime.toString()      );
    print('__________________________________________');*/

    setState(() {
      photoFiles.clear();
      photoWidgets.clear();
      orderNumberTextController.clear();
      obsTextController.clear();
      orderNumberText = null;
      obsText = null;
      executionDate = null;
      startTime = null;
      endTime = null;
    });

    /*
    print('');
    print('photoFiles:    ' + photoFiles.toString()   );
    print('photoWidgets:  ' + photoWidgets.toString() );
    print('orderNumberText:  ' + orderNumberText.toString() );
    print('obsText:       ' + obsText.toString()      );
    print('executionDate: ' + executionDate.toString());
    print('startTime:     ' + startTime.toString()    );
    print('endTime:       ' + endTime.toString()      );
    print('__________________________________________');*/
  }
}
