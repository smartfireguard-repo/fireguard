import 'package:mockito/annotations.dart';
import 'package:firebase_database/firebase_database.dart';

@GenerateMocks([
  FirebaseDatabase,
  DatabaseReference,
  DatabaseEvent,
  DataSnapshot,
  Query,
])
void main() {} // This is just needed for code generation
