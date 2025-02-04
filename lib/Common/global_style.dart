import 'package:flutter/material.dart';

class GlobalStyle {
  static Color primaryColor = const Color(0xff3E90E9);
  static Color lightColor = const Color(0xffB9D7EA);
  static Color borderColor = const Color(0xffD6E6F2);
  static Color disableColor = const Color(0xffDEDEDE);
  static Color fontColor = const Color(0xff686262);

  static String fontFamily = "Poppins-Medium";
  static double fontSize = 12;

  // ignore: unused_element
  static MaterialColor _generateMaterialColor(Color myColor){
    int red = myColor.red;
    int green = myColor.green;
    int blue = myColor.blue;

    Map<int, Color> myColorCodes =
    {
      50: Color.fromRGBO(red, green, blue, .1),
      100:Color.fromRGBO(red, green, blue, .2),
      200:Color.fromRGBO(red, green, blue, .3),
      300:Color.fromRGBO(red, green, blue, .4),
      400:Color.fromRGBO(red, green, blue, .5),
      500:Color.fromRGBO(red, green, blue, .6),
      600:Color.fromRGBO(red, green, blue, .7),
      700:Color.fromRGBO(red, green, blue, .8),
      800:Color.fromRGBO(red, green, blue, .9),
      900:Color.fromRGBO(red, green, blue, 1),
    };

    return MaterialColor(myColor.value, myColorCodes);
  }
}