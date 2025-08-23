class Global {
  Global._internal();
  static final Global _instance = Global._internal();
  factory Global() => _instance;
  
}
