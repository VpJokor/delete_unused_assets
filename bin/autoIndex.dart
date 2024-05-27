import 'dart:io';

import 'helpers/helpers.dart';

/// 根据图片自动生成资源文件索引
///
/// 脚本的配置信息
/// 使用前一定一定要记得检查脚本配置
/// 注意 注意 ！！！
///
/// flutterProjectPath 和 resourcePath 一定一定要配置 ！！！
///
/// 注意 注意 ！！！
///
///

final flutterProjectPath = '/Users/light/IdeaProjects/AnswerPlanet';
final resourcePath = '$flutterProjectPath/lib/resources';
final rPath = '$resourcePath/R.dart';
final imagePath = '$resourcePath/Image.dart';
void main(List<String> arguments) async {
  createIndexFile();
  scanImages();
}

/// 创建R文件
/// 创建imageIndex文件
File? imageFile;
String imageString = '';
final String imageClassHeader = 'class Image {\n';
final String imageClassEnd = '\n\n}';
final String imageImport = 'import \'Image.dart\';\n\n';
final String imageDesc = '///这里存放的是扫描图片文件夹生成的图片路径\n';

File? rFile;
String rString = '';
final String rDesc =
    '/// 资源文件类由ide自动生成\n/// ide自动生成的资源文件类有\n/// R , Font , Icon , Image , Raw\n/// Color , Dimens , Paddings , Strings , Theme 由用户手动编辑\n';
final String rClass = 'class R {\n  static Image image = Image();\n}';
void createIndexFile() {
  // 读取Image文件
  imageFile = File(imagePath);
  imageFile!.createSync(recursive: true);
  if (imageFile!.existsSync()) {
    imageString = imageFile!.readAsStringSync();
  }
  if (imageString.trim() == '') {
    imageString = imageDesc + imageClassHeader + imageClassEnd;
    imageFile!
        .writeAsString(imageString)
        .then((_) => print('Image.dart 创建成功'))
        .catchError((error) => print('Image.dart 创建失败: $error'));
  }

  // 读取R文件
  rFile = File(rPath);
  rFile!.createSync(recursive: true);
  if (rFile!.existsSync()) {
    rString = rFile!.readAsStringSync();
  }
  if (rString.trim() == '') {
    rString = imageImport + rDesc + rClass;
    rFile!
        .writeAsString(rString)
        .then((_) => print('R.dart 创建成功'))
        .catchError((error) => print('R.dart 创建失败: $error'));
  }
}

final String imageFilesPath = '$resourcePath/images';
void scanImages() {
  imageString = imageFile!.readAsStringSync();
  imageString.replaceFirst(imageClassEnd, '');
  Map<String, String> imageFiles = Helpers.getFilesNameWithPath(
    Directory(imageFilesPath),
    true,
    {},
    ignoreDirectories: ['2.0x', '3.0x'],
  );
  imageString = imageDesc + imageClassHeader;
  String itemName;
  for (String key in imageFiles.keys) {
    itemName = key.split('.')[0];
    if (reservedKeywords.contains(itemName)) itemName = '_$itemName';
    if (startsWithNumber(itemName)) itemName = '_$itemName';
    String item =
        '  static const String $itemName = \'${imageFiles[key]?.replaceFirst('$flutterProjectPath/', '')}\';';
    if (imageString.contains(item)) continue;
    imageString = '$imageString\n$item';
  }
  imageString = imageString + imageClassEnd;
  imageFile!
      .writeAsString(imageString)
      .then((_) => print('Image.dart 创建成功'))
      .catchError((error) => print('Image.dart 创建失败: $error'));
}

List<String> reservedKeywords = [
  'abstract',
  'dynamic',
  'implements',
  'show',
  'as',
  'else',
  'import',
  'static',
  'assert',
  'enum',
  'in',
  'super',
  'async',
  'export',
  'interface',
  'switch',
  'await',
  'extends',
  'is',
  'sync',
  'break',
  'external',
  'library',
  'this',
  'case',
  'factory',
  'mixin',
  'throw',
  'catch',
  'false',
  'new',
  'true',
  'class',
  'final',
  'null',
  'try',
  'const',
  'finally',
  'on',
  'typedef',
  'continue',
  'for',
  'operator',
  'var',
  'covariant',
  'Function',
  'part',
  'void',
  'default',
  'get',
  'rethrow',
  'while',
  'deferred',
  'hide',
  'return',
  'with',
  'do',
  'if',
  'set',
  'yield'
];
bool startsWithNumber(String str) {
  // 使用正则表达式匹配以数字开头的字符串
  RegExp regex = RegExp(r'^[0-9]');
  return regex.hasMatch(str);
}
