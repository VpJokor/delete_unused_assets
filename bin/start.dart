import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as path;

import 'helpers/console.dart';
import 'helpers/helpers.dart';

/// 脚本的配置信息
/// 使用前一定一定要记得检查脚本配置

/// 是否展示日志
bool isShowLog = true;

/// 是否对扫描出的未使用的资源文件进行删除操作
bool isDeleteUnUsedAsserts = true;

/// 被扫的功能根目录
final flutterProjectPath = Directory.current.path;

///资源文件夹
String assetsFolderPath = '$flutterProjectPath/lib/resources/images';

///被删除后的资源存放位置
String deletedAssetFolderName = '$flutterProjectPath/deleted_assets';

/// 忽略，不被脚本扫的文件夹
final ignoreDirectories = [
  assetsFolderPath,
  deletedAssetFolderName,
  'assets',
  'android',
  'build',
  'ios',
  'web',
  '.dart_tool',
  '.git',
  '.gradle',
  'plugin',
  'resources',
  'deleted_assets',
];

void main(List<String> arguments) async {
  /// 删除放到资源文件夹，但是没有被代码引用到的文件
  delUnUsedAssertFromProgect(arguments);
}

// 项目文件
Map<String, String> projectFiles = {};
//资源文件夹
Map<String, String> assetsFiles = {};
// 工程资源文件数
int assetsFilesCount = 0;
// 被项目文件引用到到资源文件数
int usedAssetsCount = 0;
// 没被项目文件引用到的资源文件数
int unUsedAssetsCount = 0;
//没有被项目直接引用的资源文件
Iterable<String> unUsedAssetsPaths = {};
//imageNames.dart未引用的资源目录
final unUsedFilePath = <String, String>{};
// imageNames.dart中所有的变量
final allRows = <String>{};
// imageNames.dart中所有符合的规则的变量
// static const String popLiveText_zh = imageBasePath + '/popLiveText_zh.png';
final matchRows = <String>{};
// imageNames.dart中不符合的规则的变量
final unMatchRows = <String>{};
// imageNames.dart中特殊的变量(数组，方法等)
final specialRows = <String>{};
// 资源文件夹路径
final Map<String, String> assertPath = {};
final Map<String, String> filePath = {};
final Map<String, String> itemRecords = {};
final Map<String, Set<String>> specialPath = {};
// imageNames.dart中没有被引用到的文件数
int unUsedImgCount = 0;
// imageNames.dart中所有的文件数
int allImgCount = 0;
// imageNames.dart 的文件路径
String imageNamesPath = '';
void delUnUsedAssertFromProgect(List<String> arguments) async {
  if (arguments.firstOrNull == '-h') {
    write(
      'Hi,\nYou Can use me like this\nflutter pub run delete_un_used_assets:start assetsPath',
      colorType: ConsoleColorType.info,
    );
  }
  try {
    await Helpers.callWithStopwatch(
      () async {
        write(
          '\nDon\'t worry I\'m not deleting any asset,\nI just moving it to $deletedAssetFolderName\n',
          colorType: ConsoleColorType.info,
        );

        final assetsPath = path.join(flutterProjectPath, assetsFolderPath);

        /// 资源文件
        assetsFiles = Helpers.callWithStopwatch(
          () => Helpers.getFilesNameWithPath(Directory(assetsPath), true, {}),
          whenDone: (milliseconds) => write(
            'collect assetsFiles: $milliseconds ms',
          ),
        );

        projectFiles = Helpers.callWithStopwatch(
          () => Helpers.getFilesNameWithPath(
            Directory(flutterProjectPath),
            false,
            {},
            ignoreDirectories: ignoreDirectories,
          ),
          whenDone: (milliseconds) =>
              write('collect projectFiles: $milliseconds ms'),
        );

        final usedAssetsNames = <String>{};

        /// imageNames.dart文件路径

        /// 扫描项目文件，判断资源是否被引用
        print('开始扫描项目文件,判断图片是否被引用，请稍后...');
        Helpers.callWithStopwatch(
          () {
            final projectFilesPaths = projectFiles.values;
            int i = 0;
            for (final path in projectFilesPaths) {
              if (isShowLog) print('项目文件[$i]: $path ，判断资源文件被引用的情况...');
              if (path.contains('imageNames.dart')) imageNamesPath = path;
              final fileString = Helpers.tryDo(
                    () => File(path).readAsStringSync(),
                    orElse: (__, _) => '',
                  ) ??
                  '';
              final assetsFilesNames = assetsFiles.keys;
              final assetsFilesNamesWithoutAlreadyUsed = assetsFilesNames.where(
                (element) => !usedAssetsNames.contains(element),
              );
              for (final assetFileName in assetsFilesNamesWithoutAlreadyUsed) {
                if (fileString.contains(assetFileName)) {
                  usedAssetsNames.add(assetFileName);
                }
              }
              i++;
            }
          },
          whenDone: (milliseconds) => write('search: $milliseconds ms'),
        );

        print('项目文件扫描结束');

        /// 扫描项目文件，得出的扫描结果
        final unUsedAssets = assetsFiles.entries
            .where((element) => !usedAssetsNames.contains(element.key));
        final unUsedAssetsNames = unUsedAssets.map((asset) => asset.key);
        unUsedAssetsPaths = unUsedAssets.map((asset) => asset.value);

        assetsFilesCount = assetsFiles.length;
        usedAssetsCount = usedAssetsNames.length;
        unUsedAssetsCount = unUsedAssetsNames.length;
      },
      whenDone: (milliseconds) => write('Total Time: $milliseconds ms'),
    );

    write(
      'Make sure that the paths of these deleted files are not used in pubspec.yaml',
      colorType: ConsoleColorType.attention,
    );
  } on Exception catch (e) {
    stdout.addError('$e');
  }

  /// 删除 imageNames中无引用到的资源
  delUnUsedAssertFromImageNames(
      arguments.firstOrNull ?? 'lib/resources/images');
  if (isDeleteUnUsedAsserts) dealResult();

  printResult();
}

/// 删除 imageNames中无引用到的资源
/// 1. 从 imageNames.dart 中读取文件信息
///   扫描imageNames.dart 的想法
///   A. 扫描整个imageNames.dart
///   B. 通过正则匹配出Key & Value
///   eg. static const String audioReadingImage_zh = imageBasePath + '/audioReadingImage_zh.png';
///   匹配出 key: audioReadingImage_zh , value: audioReadingImage_zh.png
///   匹配普通的样本
///   static const String popText = imageBasePath + '/popText.png';
///   static const String premiumChatImage =
///     imageBasePath + '/premiumChatImage.png';
///   特殊记录样本
///   A.文件夹路径：static const String imageBasePath = 'lib/resources/images';
///   B.特殊文件名常量
///   绝对路径
///   static const String loginVideoFirstFrame =
///       'lib/resources/videos/loginVideoFirstFrame.png';
///   $使用
///   static const String searchEmptyImg = '$imageBasePath/searchEmptyImg.png';
///   换行 + $ 使用
///   static const String bgOrderMultiAdvisorEntrance =
///     '$imageBasePath/bgOrderMultiEntrance.png';
///   换行 + " 使用
///   static const String notificationBellIcon =
///     imageBasePath + "/notificationBellIcon.png";
///   " 使用
///   static const String rewardDialogBg = imageBasePath + "/rewardDialogBg.png";
/// 2. 全局每个文件去扫看 imageNames样本记录有没有被引用到
void delUnUsedAssertFromImageNames(String assetsFolder) {
  if (isShowLog) printHeader(imageNamesPath);
  final imageNamesString = Helpers.tryDo(
        () => File(imageNamesPath).readAsStringSync(),
        orElse: (__, _) => '',
      ) ??
      '';

  RegExp regex =
      RegExp(r"static const String \w+ =\s?\n?\s*\w+ \+ '/\S+\.png';");
  Iterable<Match> matches = regex.allMatches(imageNamesString); // 找出所有匹配项
  for (Match match in matches) {
    matchRows.add(match.group(0) ?? '');
    if (isShowLog) print('找到匹配: ${match.group(0)}');
  }

  RegExp resultExp = RegExp(r"static const .* =\s?\n?\s*.*;");
  Iterable<Match> resultMatches = resultExp.allMatches(imageNamesString);
  for (Match match in resultMatches) {
    allRows.add(match.group(0) ?? '');
    if (!matchRows.contains(match.group(0) ?? '')) {
      unMatchRows.add(match.group(0) ?? '');
    }
    if (isShowLog) print('匹配的变量: ${match.group(0)}');
  }

  matchRows.remove('');
  unMatchRows.remove('');

  print('开始对特殊记录进行处理');
  for (String item in unMatchRows) {
    if (item.contains("lib/resources")) {
      if (!item.contains('.')) {
        // 资源文件夹路径
        RegExp regExp = RegExp(
            r"(static|const)\s+String\s+([a-zA-Z_]\w*)\s*=\s*'([^;]+)';");
        Match? match = regExp.firstMatch(item);
        if (match != null) {
          String variableName = match.group(2) ?? '';
          String variableValue = match.group(3) ?? '';
          assertPath[variableName] = variableValue;
        }
      } else {
        // 资源文件绝对路径
        RegExp regExp = RegExp(
            r"(static|const)\s+String\s+([a-zA-Z_]\w*)\s*=\s*'([^;]+)';");
        Match? match = regExp.firstMatch(item);
        if (match != null) {
          String variableName = 'ImageNames.${match.group(2) ?? ''}';
          String variableValue = match.group(3) ?? '';
          filePath[variableName] = variableValue;
          itemRecords[variableName] = item;
          if (isShowLog) {
            print(
                "样本记录/从资源文件绝对路径提取 , key: $variableName , value: $variableValue ");
          }
        }
      }
    } else {
      filePath[getvariableName(item)] = getVariableValue(item, assertPath);
      itemRecords[getvariableName(item)] = item;
      if (isShowLog) {
        print(
            "样本记录/匹配到的特殊记录提取 , key: ${getvariableName(item)} , value: ${getVariableValue(item, assertPath)} ");
      }
    }
  }

  ///对匹配到的每一行进行处理
  /// 1. 提取key
  /// 2. 转化文件路径
  print('开始对每一条记录进行提取');
  print('----------------------------------');
  for (String item in matchRows) {
    filePath[getvariableName(item)] = getVariableValue(item, assertPath);
    itemRecords[getvariableName(item)] = item;
    if (isShowLog) {
      print(
          "样本记录/从匹配到的资源记录提取 , key: ${getvariableName(item)} , value: ${getVariableValue(item, assertPath)} ");
    }
  }

  /// 还有未匹配到的特殊样本未处理,如果不做处理会误删
  dealSpecialRecords(imageNamesString, assertPath);

  /// 2. 全局每个文件去扫看 imageNames样本记录有没有被引用到
  /// C.参考文件扫描全局搜索有没有出现 'ImageNames.$key', 出现过则记录key
  /// D.遍历查出未出现过的key
  /// E. imageNames.dart 删除的记录，并加入到deleted_assets/ImageNames/deletedNames.dart 中 ， 删除对应文件

  print('开始扫描项目文件,判断图片是否被引用');
  try {
    Helpers.callWithStopwatch(
      () async {
        final Map<String, String> usedFilePath = {};
        final Map<String, Set<String>> usedSpecialPath = {};
        final usedFile = <String>{};

        /// 扫描项目文件，判断资源是否被引用
        print('开始扫描项目文件,判断图片是否被引用');
        Helpers.callWithStopwatch(
          () {
            final projectFilesPaths = projectFiles.values;
            int i = 0;
            for (final path in projectFilesPaths) {
              if (isShowLog)
                print('扫描项目文件[$i]: $path , 判断imageNames.dart 被引用的情况');
              final fileString = Helpers.tryDo(
                    () => File(path).readAsStringSync(),
                    orElse: (__, _) => '',
                  ) ??
                  '';

              // print('文件path $path');

              ///判断 imageNames.xxxx 的变量名有没有被使用
              ///被使用则加入到 usedFilePath(变量)或usedSpecialPath(数组，方法等等) 中
              for (String key in filePath.keys) {
                if (fileString.contains(key)) {
                  usedFilePath[key] = filePath[key] ?? '';
                  usedFile.add(filePath[key] ?? '');
                }
              }
              for (String key in specialPath.keys) {
                if (fileString.contains(key)) {
                  usedSpecialPath[key] = specialPath[key] ?? {};
                  usedFile.addAll(specialPath[key] as Iterable<String>);
                }
              }
              i++;
            }
          },
          whenDone: (milliseconds) => write('search: $milliseconds ms'),
        );

        /// 扫描目录，得出的扫描结果
        filePath.forEach((key, value) {
          if (!usedFilePath.containsKey(key)) {
            unUsedFilePath[key] = value;
          }
        });
        final Map<String, Set<String>> unUsedSpecialPath = {};
        specialPath.forEach((key, value) {
          if (!usedSpecialPath.containsKey(key)) {
            unUsedSpecialPath[key] = value;
          }
        });

        if (isShowLog) {
          for (String key in unUsedFilePath.keys) {
            print(
                '未在项目中使用的资源 key: $key , value: ${unUsedFilePath[key]} , record: ${itemRecords[key]}');
          }
        }
        // imageNames.dart中没有被引用到的文件数
        unUsedImgCount = unUsedFilePath.length;
        // imageNames.dart中所有的文件数
        allImgCount = usedFilePath.length;
      },
      whenDone: (milliseconds) => write('Total Time: $milliseconds ms'),
    );
  } on Exception catch (e) {
    stdout.addError('$e');
  }
}

//  特殊样本1
//  static String coin(int level) {
//     List<String> coins = [
//       imageBasePath + '/coin1.png',
//       imageBasePath + '/coin2.png',
//       imageBasePath + '/coin3.png',
//       imageBasePath + '/coin4.png',
//       imageBasePath + '/coin5.png',
//       imageBasePath + '/coin6.png',
//       imageBasePath + '/coin7.png',
//     ];
//     return coins[level - 1];
//   }
//  特殊样本2
// static const List<String> specificSkillIcons = [
//     imageBasePath + '/clairvoyant.png',
//     imageBasePath + '/Tarot.png',
//     imageBasePath + '/dreamAnalysis.png',
//     imageBasePath + '/Horoscope.png',
//     imageBasePath + '/oracleGuidance.png',
//     imageBasePath + '/empath.png',
//     imageBasePath + '/AngelInsight.png',
//     imageBasePath + '/notSure.png'
//   ];
/// 如果有其他特殊样本，一定记得要在这里处理
/// 处理未匹配到的特殊样本,如果不做处理会误删
void dealSpecialRecords(
    String imageNamesString, Map<String, String> assertPath) {
  print('处理未匹配到的特殊样本,如果不做处理会误删');

  ///处理特殊样本1
  RegExp regex = RegExp(r'static String \w+\(\w+ \w+\) \{[\s\S]*?\}');
  Iterable<Match> matches = regex.allMatches(imageNamesString);
  for (Match match in matches) {
    String matchStr = match.group(0) ?? '';
    specialRows.add(matchStr);
    String special1VariableName =
        'ImageNames.${getSpecial1VariableName(matchStr)}(';
    // print('提取到特殊样本1 的方法名 $special1VariableName');
    RegExp valueRegex = RegExp(r"\S+ \+ '/\S+\.png'");
    Iterable<Match> valueMatches = valueRegex.allMatches(matchStr);
    //放提取的资源
    final reSource = <String>{};
    for (Match match in valueMatches) {
      // print('提取前 ' + (match.group(0) ?? ''));
      String strValue = getVariableValue(match.group(0) ?? '', assertPath);
      // print('提取到特殊样本1 的资源: $strValue');
      reSource.add('$assetsFolderPath/$strValue');
    }
    specialPath[special1VariableName] = reSource;
    itemRecords[special1VariableName] = matchStr;
    if (isShowLog)
      print('样本记录/从特殊样本1提取 ，key: $special1VariableName , value: $reSource');
  }
  // print('特殊样本1资源提取完毕 $specialPath');

  ///处理特殊样本2
  RegExp regex2 = RegExp(r'static const List<String> \w+ = \[[\s\S]*?\];');
  Iterable<Match> matches2 = regex2.allMatches(imageNamesString);
  for (Match match in matches2) {
    String matchStr = match.group(0) ?? '';
    specialRows.add(matchStr);
    // print('匹配到的样本资源2:\n' + matchStr);
    String special2VariableName =
        'ImageNames.${getSpecial2VariableName(matchStr)}';
    // print('提取到特殊样本2 的资源名 $special2VariableName');
    RegExp valueRegex = RegExp(r"\S+ \+ '/\S+\.png'");
    Iterable<Match> valueMatches = valueRegex.allMatches(matchStr);
    //放提取的资源
    final reSource = <String>{};
    for (Match match in valueMatches) {
      // print('提取前 ' + (match.group(0) ?? ''));
      String strValue = getVariableValue(match.group(0) ?? '', assertPath);
      // print('提取到特殊样本2 的资源: $strValue');
      reSource.add('$assetsFolderPath/$strValue');
    }
    specialPath[special2VariableName] = reSource;
    itemRecords[special2VariableName] = matchStr;
    if (isShowLog)
      print('样本记录/从特殊样本2提取 ，key: $special2VariableName , value: $reSource');
  }
  print('特殊样本资源提取完毕 $specialPath');
}

String getSpecial1VariableName(String matchStr) {
  RegExp regExp = RegExp(r'static String\s+(\w+)\s*\(.*?\)\s*{');
  Match? match = regExp.firstMatch(matchStr);
  return match?.group(1) ?? '';
}

String getSpecial2VariableName(String matchStr) {
  RegExp regExp = RegExp(r'static const List<String> (\S+) =');
  Match? match = regExp.firstMatch(matchStr);
  return match?.group(1) ?? '';
}

String getvariableName(String item) {
  RegExp regex = RegExp(r"static const String (\S+) =");
  Match? match = regex.firstMatch(item);
  String variableName = match?.group(1) ?? '';
  return 'ImageNames.$variableName';
}

String getVariableValue(String contentData, Map<String, String> assertPath) {
  /// 提取出资源文件夹路径
  String assertDicPath = '';
  for (String item in assertPath.keys) {
    if (contentData.contains(item)) {
      assertDicPath = assertPath[item] ?? '';
      break;
    }
  }
  // print('assertDicPath: $assertDicPath ');
  RegExp regex = RegExp(r"/(\S+\.[a-zA-Z]+)");
  Match? match = regex.firstMatch(contentData);
  String variableValue = match?.group(1) ?? '';
  String filePath = "$assertDicPath/$variableValue";
  // print('getVariableValue: $filePath ');
  return '$flutterProjectPath/$filePath';
}

void printHeader(String imageNamesPath) {
  print(
      '===================================================================================================================');
  print(
      '===================================================================================================================');
  print(
      '===================================================================================================================');
  print(
      '===================================================================================================================');
  print(
      '===================================================================================================================');
  print(
      '===================================================================================================================');
  print(
      '===================================================================================================================');
  print(
      '===================================================================================================================');
  print('imageNames.dart的path为：$imageNamesPath');
  print(
      '================== 开始扫描 imageNames.dart 文件 ====================================================================');
  print(
      '===================================================================================================================');
  print(
      '===================================================================================================================');
  print(
      '===================================================================================================================');
  print(
      '===================================================================================================================');
  print(
      '===================================================================================================================');
  print(
      '===================================================================================================================');
  print(
      '===================================================================================================================');
  print(
      '===================================================================================================================');
}

/// 删除无用的文件
void dealResult() {
  DateTime now = DateTime.now();
  String currentTime =
      '${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}_${now.minute.toString().padLeft(2, '0')}_${now.second.toString().padLeft(2, '0')}';

  write('开始删除项目中的无用资源文件', colorType: ConsoleColorType.attention);
  Helpers.deleteFilesByPaths(
    paths: unUsedAssetsPaths,
    assetFolderName: assetsFolderPath,
    deletedAssetFolderName: '$deletedAssetFolderName/$currentTime/from_project',
  );

  write('开始删除 imageNames.dart 中的无用资源文件', colorType: ConsoleColorType.attention);

  /// 要处理的数据
  // for (String key in unUsedFilePath.keys) {
  //    print('未在项目中使用的资源 key: $key , value: ${unUsedFilePath[key]} , record: ${itemRecords[key]}');
  //  }
  // key:  ImageNames.iconShare ,
  // value: /Users/light/IdeaProjects/AnswerPlanet/lib/resources/newImages/iconShare.png ,
  // record: static const String iconShare = newImageBasePath + '/iconShare.png';
  /// 数据处理流程
  // 1.在deletedAssetFolderName目录创建 deal文件，文件名 deal_imageNames_时间_records , deal_imageNames_时间_log
  // 2.对数据逐条进行处理，操作 写入文件 deal_imageNames_时间_records , deal_imageNames_时间_log

  /// 删文件
  Helpers.deleteFilesByPaths(
    paths: unUsedFilePath.values,
    assetFolderName: assetsFolderPath,
    deletedAssetFolderName:
        '$deletedAssetFolderName/$currentTime/from_imageNames/files',
  );

  String imageNamesString = Helpers.tryDo(
        () => File(imageNamesPath).readAsStringSync(),
        orElse: (__, _) => '',
      ) ??
      '';
  File imageNamesBak = File(
      '$deletedAssetFolderName/$currentTime/from_imageNames/imageNames.dart');
  imageNamesBak.createSync(recursive: true);
  imageNamesBak
      .writeAsString(imageNamesString)
      .then((_) => print('imageNames.dart 备份成功'))
      .catchError((error) => print('imageNames.dart 备份失败: $error'));

  File recordFile =
      File('$deletedAssetFolderName/$currentTime/from_imageNames/records');
  recordFile.createSync(recursive: true);
  File logFile =
      File('$deletedAssetFolderName/$currentTime/from_imageNames/log');
  var logSink = logFile.openWrite();
  var recordSink = recordFile.openWrite();
  for (String key in unUsedFilePath.keys) {
    write(
        '删除文件 key: $key value: ${unUsedFilePath[key]} \n record: ${itemRecords[key]}\n',
        colorType: ConsoleColorType.info);

    ///删除 imageNames.darth中的记录
    if (itemRecords[key] != null) {
      imageNamesString =
          imageNamesString.replaceFirst('  ${itemRecords[key]!}\n', '');
    }

    ///处理日志
    logSink.write(
        '删除文件\n key: $key \n value: ${unUsedFilePath[key]} \n record: ${itemRecords[key]}\n\n');
    recordSink.write('${itemRecords[key]}\n');
  }
  recordSink.close();
  logSink.close();

  File imageNamesFile = File(imageNamesPath);
  imageNamesFile
      .writeAsString(imageNamesString)
      .then((_) => print('imageNames.dart 写入成功'))
      .catchError((error) => print('imageNames.dart 写入失败: $error'));
}

///打印最后的输出结果
void printResult() {
  for (String item in unUsedAssetsPaths) {
    print('未在项目中直接被使用的资源: $item');
  }
  // for (String item in allRows) {
  //   print('变量记录 $item');
  // }
  // for (String item in specialRows) {
  //   print('特殊文件记录 $item');
  // }
  write('资源文件夹路径 $assertPath');
  write('匹配到结果 ${matchRows.length} 条记录');
  write('匹配到${unMatchRows.length} 条特殊记录 , 其中有${assertPath.length} 条是资源文件夹路径');
  write('一共有${allRows.length} 原始条记录');
  write('处理未匹配到到特殊记录共 ${specialPath.keys.length}条');
  write("共${filePath.length + specialPath.keys.length}条样本记录");

  write('未项目文件引用到的资源文件数: $unUsedAssetsCount,工程资源文件数: $assetsFilesCount',
      colorType: ConsoleColorType.attention);
  write('imageNames.dart未在工程中使用的变量共$unUsedImgCount个 , 使用中的变量共$allImgCount个',
      colorType: ConsoleColorType.attention);
}
