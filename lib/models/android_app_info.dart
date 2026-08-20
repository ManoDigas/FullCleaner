class AndroidAppInfo {
  const AndroidAppInfo({
    required this.name,
    required this.packageName,
    required this.versionName,
  });

  final String name;
  final String packageName;
  final String versionName;

  factory AndroidAppInfo.fromMap(Map<dynamic, dynamic> map) {
    return AndroidAppInfo(
      name: (map['name'] ?? 'Aplicativo').toString(),
      packageName: (map['packageName'] ?? '').toString(),
      versionName: (map['versionName'] ?? '').toString(),
    );
  }
}
