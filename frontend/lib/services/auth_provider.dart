import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

final GoogleSignIn googleSignIn = GoogleSignIn(
  clientId: kIsWeb 
    ? '169231317250-nc8otuvk6ic7cqii3sfdd4pbbp8ge9d7.apps.googleusercontent.com' 
    : null,
  );