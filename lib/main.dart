//import 'dart:convert';
//import 'dart:html';
import 'dart:io';
import 'dart:typed_data';

import 'package:english_words/english_words.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
//import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snapping_sheet/snapping_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App());
  //runApp(const MyApp());

}


final snappingSheetController = SnappingSheetController();

class App extends StatelessWidget {
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();

  @override Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
              body: Center(
                  child: Text(snapshot.error.toString(),
                      textDirection: TextDirection.ltr)));
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return const MyApp();
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider (
      providers:[
        ChangeNotifierProvider<Authentication>(create: (ctx) => Authentication(),),
        ChangeNotifierProvider<Favorite>(create: (ctx) => Favorite(),),
      ],
     child :MaterialApp (
      title: 'Startup Name Generator',
        theme: ThemeData(          // Add the 5 lines from here...
        appBarTheme: const AppBarTheme(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.black,
        ),
        ),
    home: const RandomWords(),
    ));
  }
}

class Snappingsheet extends StatelessWidget {
  const Snappingsheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SnappingSheet(
      child: RandomWords(),
      grabbingHeight: 75,
    );
  }
}




class RandomWords extends StatefulWidget {
  const RandomWords({Key? key}) : super(key: key);

  @override
  State<RandomWords> createState() => _RandomWordsState();
}

class GrabbinWidget extends StatefulWidget {
  const GrabbinWidget({Key? key}) : super(key: key);

  @override
  State<GrabbinWidget> createState() => _GrabbinWidgetState();
}

class _GrabbinWidgetState extends State<GrabbinWidget> {
  late bool _position = false;
  @override
  Widget build(BuildContext context) {
    return context.read<Authentication>()._status == Status.Authenticated ? Container(
      decoration: const BoxDecoration(
        color: Colors.grey,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [

          Text("  Welcome back, ${context.read<Authentication>()._user.email}", style: const TextStyle(
            fontSize: 20,

          ),
          ),
          InkWell(
            onTap: (){
              _position?
              snappingSheetController.setSnappingSheetPosition(35):
              snappingSheetController.setSnappingSheetPosition(140);

              setState(() {
                _position = !_position;
              });
            },
            child: const Icon(Icons.arrow_drop_up, size: 50),
          ),

        ],
      ),
    ) : const SizedBox.shrink();
  }
}




class _RandomWordsState extends State<RandomWords> {
  final _suggestions = <WordPair>[]; // NEW
  final _saved = <WordPair>{}; // NEW
  final _biggerFont = const TextStyle(fontSize: 18); // NEW
  var url;
  @override
  Widget build(BuildContext context) {
    _setImage();
    return Scaffold( // NEW from here ...
        appBar: AppBar(
          title: const Text('Startup Name Generator'),
          actions: [
            IconButton(
              icon: const Icon(Icons.star),
              onPressed: _updateSaved,
              tooltip: 'Saved Suggestions',
            ),
            IconButton(
              icon: context.watch<Authentication>()._status == Status.Authenticated ?
              const Icon(Icons.exit_to_app) : const Icon(Icons.login),
              onPressed : context.watch<Authentication>()._status == Status.Authenticated ? _logout : _login,
              tooltip: 'Login',
            ),
          ],
        ),
        body: Stack (children :[
          ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemBuilder: (context, i) {

              if (i.isOdd) return const Divider();

              final index = i ~/ 2;
              if (index >= _suggestions.length) {
                _suggestions.addAll(generateWordPairs().take(10));
              }
              final alreadySaved = _saved.contains(_suggestions[index]); // NEW
              return ListTile(
                  title: Text(
                    _suggestions[index].asPascalCase,
                    style: _biggerFont,
                  ),
                  trailing: Icon( // NEW from here ...
                    alreadySaved ? Icons.favorite : Icons.favorite_border,
                    color: alreadySaved ? Colors.red : null,
                    semanticLabel: alreadySaved ? 'Remove from saved' : 'Save',
                  ),
                  onTap: () async {
                    if (context
                        .read<Authentication>()
                        ._status == Status.Authenticated){
                      context.read<Favorite>()._firestore.collection('users')
                          .doc(context.read<Authentication>()._user.uid)
                          .get().then((DocumentSnapshot documentSnapshot){
                        if(documentSnapshot.exists){
                          Map<String, dynamic> data = documentSnapshot.data()! as Map<String, dynamic>;
                          final beforeCapitalLetter = RegExp(r"(?=[A-Z])");
                          var data2 = <String>{};
                          String newData = data['name'].replaceAll('{', '');
                          String newData2 = newData.replaceAll('}', '');
                          List splittedData = newData2.split(", ");
                          var i = 0;
                          while(i != splittedData.length){ // splittedData[i].isNotEmpty
                            data2.add(splittedData[i]);
                            i++;
                          }
                          setState(() {
                            for (var element in data2) {
                              var parts = element.split(beforeCapitalLetter);
                              if(parts.length >= 2){
                                var pair = WordPair(parts[0].toLowerCase(), parts[1].toLowerCase());
                                _saved.add(pair);
                              }
                            }
                            if (alreadySaved) {
                              _saved.remove(_suggestions[index]);
                            } else {
                              _saved.add(_suggestions[index]);
                            }
                            if (context
                                .read<Authentication>()
                                ._status == Status.Authenticated) {
                              context.read<Favorite>()
                                  .addUser(context.read<Authentication>()._user.uid, _saved);
                            }
                          });
                        }
                      });
                    } else {
                      setState(() {
                        if (alreadySaved) {
                          _saved.remove(_suggestions[index]);
                        } else {
                          _saved.add(_suggestions[index]);
                        }
                      });
                    }
                  }
              );
            },
          ),
          context.read<Authentication>()._status == Status.Authenticated ? SnappingSheet(
            //child: const Text("Welcome back,"),
            grabbingHeight : 75,
            snappingPositions: const [
              SnappingPosition.factor(
                positionFactor: 0.0,
                snappingCurve: Curves.easeOutExpo,
                snappingDuration: Duration(seconds: 1),
                grabbingContentOffset: GrabbingContentOffset.top,
              ),
              SnappingPosition.pixels(
                positionPixels: 400,
                snappingCurve: Curves.elasticOut,
                snappingDuration: Duration(milliseconds: 1750),
              ),
              SnappingPosition.factor(
                positionFactor: 1.0,
                snappingCurve: Curves.bounceOut,
                snappingDuration: Duration(seconds: 1),
                grabbingContentOffset: GrabbingContentOffset.bottom,
              ),
            ],
            controller: snappingSheetController,
            sheetBelow: context.read<Authentication>()._status == Status.Authenticated ? SnappingSheetContent(

              sizeBehavior: SheetSizeStatic(size: 300),
              draggable: true,
              child: Container(
                color: Colors.white,
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget> [
                      Column( children: <Widget> [
                        Padding(
                          padding: EdgeInsets.only(left:15.0,right: 15.0,top:15,bottom: 0),
                          child: _getWidget(),
                        ),]
                      ),
                      Column(
                        children: <Widget> [
                          Padding(
                              padding: EdgeInsets.only(left:15.0,right: 15.0,top:15,bottom: 0),
                              //padding: EdgeInsets.symmetric(horizontal: 15),
                              child: Text('${context.read<Authentication>()._user.email}', style: const TextStyle(
                                fontSize: 25,
                              ))),

                          ElevatedButton(onPressed:() async {
                            FilePickerResult? result = await FilePicker.platform.pickFiles();

                            if (result != null) {
                              final path = result.files.single.path;
                              //final filename = result.files.single.name;
                              await context.read<Favorite>().uploadFile(path!, context.read<Authentication>()._user.email!);
                              final ref = FirebaseStorage.instance.ref().child(context.read<Authentication>()._user.email!);
                              var myUrl = await ref.getDownloadURL();
                              //print(myUrl);
                              setState(() {
                                url = myUrl;
                              });
                            }
                          },
                              child: const Text("Change avatar")),

                        ],
                      )
                    ]
                )),
            ) : null,
            grabbing: const GrabbinWidget(),
          )
        : const SizedBox.shrink()]),

    );
  }

  Future<void> _setFavorite() async {
    if(context.read<Authentication>()._status == Status.Authenticated){

    }
  }

  Future<void> _setImage() async {
    if(context.read<Authentication>()._status == Status.Authenticated){
      //try{
        final ref = FirebaseStorage.instance.ref().child(context.read<Authentication>()._user.email!);
       // print(ref);
        if(ref != null){
          var myUrl = await ref.getDownloadURL();
       //   print(myUrl);
          setState(() {
            url = myUrl;
          }) ;
        }


     // } on FirebaseException catch (e){
    //    print(e);
     // }
    }
  }

  Widget _getWidget() {
    if(url!=null){
      return Container(
        width: 70,
        height: 70,
        decoration:  BoxDecoration(

          shape: BoxShape.circle,
          image:  DecorationImage(
              image: NetworkImage(url),
              fit: BoxFit.fill
          ) ,
        ),
      );
    }
    else {
      return const SizedBox.shrink();
    }
  }

  Future<void> _updateSaved() async{
    if(context.read<Authentication>()._status == Status.Authenticated) {
      context
          .read<Favorite>()
          ._firestore
          .collection('users')
          .doc(context
          .read<Authentication>()
          ._user
          .uid)
          .get()
          .then((DocumentSnapshot documentSnapshot) {
        if (documentSnapshot.exists) {
          Map<String, dynamic> data = documentSnapshot.data()! as Map<
              String,
              dynamic>;
          final beforeCapitalLetter = RegExp(r"(?=[A-Z])");
          var data2 = <String>{};
          String newData = data['name'].replaceAll('{', '');
          String newData2 = newData.replaceAll('}', '');
          List splittedData = newData2.split(", ");
          var i = 0;
          while (i != splittedData.length) { // splittedData[i].isNotEmpty
            data2.add(splittedData[i]);
            i++;
          }
          if(mounted){setState(() {
            for (var element in data2) {
              var parts = element.split(beforeCapitalLetter);
              if(parts.length >= 2){
                var pair = WordPair(parts[0].toLowerCase(), parts[1].toLowerCase());
                _saved.add(pair);
              }
            }
            if (context
                .read<Authentication>()
                ._status == Status.Authenticated) {
              context.read<Favorite>()
                  .addUser(context
                  .read<Authentication>()
                  ._user
                  .uid, _saved);
            }
          });}
        }
      });
    }

    _pushSaved();
  }

  void _pushSaved() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {


         final tiles = _saved.map(
                (pair) {
              return Dismissible(
                  background: Container(
                    color: Colors.deepPurple,
                    child:  Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.delete),
                        Text('Delete Suggestion'),
                      ],
                    )
              ),
                  key: ValueKey(pair.asPascalCase),
                  direction: DismissDirection.startToEnd,
                  confirmDismiss: (val)  async {
                    return await  showDialog(context : context,
                    builder: (BuildContext context){
                      return AlertDialog(
                        title: Text('Delete Suggestion'),
                        content: Text('Are you sure you want to delete ${pair.asPascalCase} from your saved suggestions'),
                        actions:[
                          TextButton(
                              child:Text("Yes"),
                              onPressed:()=>Navigator.pop(context,true)
                          ),
                          TextButton(
                              child:Text("No"),
                              onPressed:()=>Navigator.pop(context,false)
                          ),
                        ],
                      );
                    });
                  },
                  onDismissed: (startToEnd) async{
                    setState(() {
                      _saved.remove(pair);
                    });
                    //Navigator.of(context, rootNavigator:true).pop('dialog');
                    if (context
                        .read<Authentication>()
                        ._status == Status.Authenticated) {
                      await context.read<Favorite>()
                          .addUser(context.read<Authentication>()._user.uid, _saved);
                    }
                     },
                  child: ListTile(
                    title: Text(
                      pair.asPascalCase,
                      style: _biggerFont,
                    ),
                  )
              );
            },
          );
          final divided = tiles.isNotEmpty
              ? ListTile.divideTiles(
            context: context,
            tiles: tiles,
          ).toList()
              : <Widget>[];

          return Scaffold(
            appBar: AppBar(
              title: const Text('Saved Suggestions'),
            ),
            body: ListView(children: divided),
          );
        },
      ),
    );
  }

  void _logout(){
    context.read<Authentication>()._auth.signOut();
    _saved.clear();
    url = null;
    const snackBar = SnackBar(
      content: Text('Sucessfully logged out'),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _login() {
    Navigator.of(context).push(

      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          final emailController = TextEditingController();
          final passwordController =  TextEditingController();
          final confirmationController = TextEditingController();;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Login'),
            ),
            body: SingleChildScrollView(
              child: Column(
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.only(left:15.0,right: 15.0,top:15,bottom: 0),
                      //padding: EdgeInsets.symmetric(horizontal: 15),
                      child: Text('Welcome to Startup Names Generator, please log in!')
                    ),
                    Padding(
                    padding: const EdgeInsets.only(left:15.0,right: 15.0,top:15,bottom: 0),
                    //padding: EdgeInsets.symmetric(horizontal: 15),
                    child: TextField(
                      decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Email',
                          hintText: 'Enter valid email id as abc@gmail.com'),
                      controller: emailController,
                    ),
                  ),
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 15.0, right: 15.0, top: 15, bottom: 0),
                      //padding: EdgeInsets.symmetric(horizontal: 15),
                      child: TextField(
                        obscureText: true,
                        decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Password',
                            hintText: 'Enter secure password'),
                        controller: passwordController,
                      ),
                    ),
                    Container(
                        height: 50, width: 350,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: context.read<Authentication>()._status == Status.Authenticating ? const Icon(Icons.access_time) : FloatingActionButton.extended(
                          backgroundColor: Colors.deepPurple,
                          heroTag: "login",
                          onPressed: () async  {
                            await context.read<Authentication>().signIn(emailController.text,
                                  passwordController.text);
                            final ref = FirebaseStorage.instance.ref().child(context.read<Authentication>()._user.email!);

                            var myUrl = await ref.getDownloadURL();
                        //    print(myUrl);
                            context.read<Favorite>()._firestore.collection('users')
                            .doc(context.read<Authentication>()._user.uid)
                                .get().then((DocumentSnapshot documentSnapshot) async {
                              if(documentSnapshot.exists){
                                Map<String, dynamic> data = documentSnapshot.data()! as Map<String, dynamic>;
                                final beforeCapitalLetter = RegExp(r"(?=[A-Z])");
                                var data2 = <String>{};
                                String newData = data['name'].replaceAll('{', '');
                                String newData2 = newData.replaceAll('}', '');
                                List splittedData = newData2.split(", ");
                                var i = 0;
                                while(i != splittedData.length){ // splittedData[i].isNotEmpty
                                  data2.add(splittedData[i]);
                                  i++;
                                }
                                setState(() {
                                  for (var element in data2) {
                                    var parts = element.split(beforeCapitalLetter);
                                    if(parts.length >= 2){
                                      var pair = WordPair(parts[0].toLowerCase(), parts[1].toLowerCase());
                                      _saved.add(pair);
                                    }
                                  }
                                  if (context
                                      .read<Authentication>()
                                      ._status == Status.Authenticated) {
                                    context.read<Favorite>()
                                        .addUser(context.read<Authentication>()._user.uid, _saved);
                                  }
                                  if(context.read<Authentication>()._status == Status.Authenticated){

                                    Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(builder: (context) => const MyApp()),
                                            (r) => false
                                    );
                                  }
                                  else {
                                    const snackBar = SnackBar(
                                      content: Text('There was an error logging into app'),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                  }
                                    url = myUrl;

                                });
                              }
                            });

                            }, label: const Text('Login'),
                        )
                    ),
                    Container(
                        height: 50, width: 350,
                        padding: const EdgeInsets.symmetric(
                            vertical: 10),
                        //padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                        child: context.read<Authentication>()._status == Status.Authenticating ? const Icon(Icons.access_time) : FloatingActionButton.extended(
                          // style: const ButtonStyle(backgroundColor: MaterialStatePropertyAll<Color>(Colors.blue)),
                          // child: const Text('Sign Up'),
                          heroTag: "signup",
                          onPressed: () async { if(emailController.text.isNotEmpty && passwordController.text.isNotEmpty){
                            showModalBottomSheet(context: context, isScrollControlled: true, builder: (BuildContext context){
                              return Padding (padding: MediaQuery.of(context).viewInsets,
                                  child: Wrap(

                                  children:  [
                                  ListTile(title: Text("Please confirm your password below:")),
                                  ListTile(title: TextField(obscureText: true,
                                    decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        labelText: 'Password',
                                        hintText: 'Enter confirmation password'),
                                    controller: confirmationController,
                                  ),),
                                  Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 150.0),
                                    child: ElevatedButton(
                                        onPressed:() async {
                                        //  print(confirmationController.text);
                                        //  print(passwordController.text);
                                          if(confirmationController.text == passwordController.text){
                                            Navigator.pop(context);
                                          await Provider.of<Authentication>(context, listen: false).signUp(
                                              emailController.text,
                                              passwordController.text
                                          );
                                          if(context.read<Authentication>()._status == Status.Authenticated){
                                            await context.read<Favorite>()._firestore
                                                .collection('users').doc(context.read<Authentication>()._user.uid)
                                                .set({
                                              'name' : ''
                                            });
                                            Navigator.pushAndRemoveUntil(
                                                context,
                                                MaterialPageRoute(builder: (context) => const MyApp()),
                                                    (r) => false
                                            );
                                          }
                                          else {
                                            const snackBar = SnackBar(
                                              content: Text('There was an error logging into app'),
                                            );
                                            ScaffoldMessenger.of(context).showSnackBar(snackBar);;
                                          }
                                        }
                                        else{
                                          const snackBar = SnackBar(
                                            content: Text('There was an error logging into app'),
                                          );
                                          ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                        }
                                        },

                                        child: Text("Confirm")),
                                  )

                                ]

                              ));
                            }); }




                            }, label: const Text('New user? Click to sign up'),
                        )
                    ),
                  ]),
            ),
          );
        }
    )
    );
  }

}

enum Status {
  Authenticating,
  Authenticated,
  Unauthenticated,
}
/*
class FavoriteList{
  late var _data = List<String>;
  FavoriteList(List<String> data){
    _data = data as Type;
  }
  FavoriteList.fromJson(Map Json): this(json['name']);
}*/

class Favorite extends ChangeNotifier{
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  //final _favoriteList = FavoriteList();

  Future<void> uploadFile(String filepath, String filename) async{
    File file = File(filepath);
    try{
      await _storage.ref(filename).putFile(file);
    } on FirebaseException catch (e){
      print (e);
    }
  }

  Future<ListResult> listFiles() async {
    ListResult results = await _storage.ref('images').listAll();
    return results;
  }

  Future<void> addUser(String userId, Set<WordPair> data) {
    var data2 = <String>{};
    data.forEach((element) {data2.add(element.asPascalCase);});
    return _firestore
        .collection('users').doc(userId)
        .set({
        'name': data2.toString()
        });
  }

  Future<void> deleteUser(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .delete();
  }

  Future<StreamBuilder> getData(String userId) async {
    final Stream<QuerySnapshot> _usersStream = _firestore.collection('users').snapshots();
    return StreamBuilder<QuerySnapshot>(
      stream: _usersStream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot){
        return ListView(
          children: snapshot.data!.docs.map((DocumentSnapshot document){
            Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
            return ListTile(
              title: Text(data['name']),
            );
          }).toList(),
        );
      },
    );
  }

    /*var document = _firestore
        .collection('users')
        .doc(userId)
        .get();
  }*/
}



class Authentication extends ChangeNotifier {

  Status _status = Status.Unauthenticated;
  late User _user;
  final _auth = FirebaseAuth.instance;

  Authentication(){
    _auth.authStateChanges().listen( (User? firebaseUser) async {
      if (firebaseUser == null) {
        //_user = null;
        _status = Status.Unauthenticated;
      }
      else {
        _user = firebaseUser;
        _status = Status.Authenticated;
      }
      notifyListeners();
    } );
  }

  Future<UserCredential?> signUp(String email, String password) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      return await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password
      );
    }
    catch (e) {
      print(e);
      _status = Status.Unauthenticated;
      notifyListeners();
      return null;
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(
          email: email,
          password: password
      );
      return true;
    }
    catch (e) {
      print(e);
      _status = Status.Unauthenticated;
      notifyListeners();
      return false;
    }

  }


}


