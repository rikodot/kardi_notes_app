import 'package:encrypt/encrypt.dart';

//https://github.com/wanttobeno/Study_Diffie_Hellman_Key_Exchange/blob/master/main.c
class DH {
  static int p = 2147483647;
  static int g = 5;

  //calc a * b % p, avoid 64bit overflow
  static int mul_mod_p(int a, int b) {
    int res = 0;
    a %= p;
    while (b > 0) {
      if (b % 2 == 1) {
        res = (res + a) % p;
      }
      a = (a * 2) % p;
      b = b ~/ 2;
    }
    return res;
  }

  //calc a ^ b % p, avoid 64bit overflow
  static int pow_mod_p(int a, int b) {
    int res = 1;
    if (a > p) {
      a%=p;
    }
    while (b > 0) {
      if (b % 2 == 1) {
        res = mul_mod_p(res, a);
      }
      a = mul_mod_p(a, a);
      b = b ~/ 2;
    }
    return res;
  }

  /*static test() {
    int client_priv = Utils.randomInt();
    int server_priv = Utils.randomInt();

    int client_pub = DH.pow_mod_p(DH.g, client_priv);
    int server_pub = DH.pow_mod_p(DH.g, server_priv);

    int client_calc = DH.pow_mod_p(server_pub, client_priv);
    int server_calc = DH.pow_mod_p(client_pub, server_priv);

    //print everything
    print("client_priv: $client_priv");
    print("server_priv: $server_priv");
    print("client_pub: $client_pub");
    print("server_pub: $server_pub");
    print("client_calc: $client_calc");
    print("server_calc: $server_calc");
  }*/

  static gen_random(int finalKey, {int length = 32, int shift = 76})
  {
    String allowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    String randomString = "";
    for (int i = 0; i < length; ++i)
    {
      if (finalKey - shift < 0) { finalKey = DH.mul_mod_p(finalKey, shift); }
      else { finalKey -= shift; }
      randomString += allowedChars[finalKey % allowedChars.length];
    }
    return randomString;
  }

  //encrypt and decrypt functions (dynamic to avoid mitm etc etc for communication only)
  static String enc(String text, String key, String iv)
  {
    final encrypter = Encrypter(AES(Key.fromUtf8(key), mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(text, iv: IV.fromUtf8(iv));
    return encrypted.base64;
  }
  static String dec(String text, String key, String iv)
  {
    final encrypter = Encrypter(AES(Key.fromUtf8(key), mode: AESMode.cbc));
    final decrypted = encrypter.decrypt64(text, iv: IV.fromUtf8(iv));
    return decrypted;
  }
}