import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_fire/shared/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Chatting extends StatefulWidget {
  final String freindId;
  final String freindAvatar;
  final String freindName;

  Chatting({@required this.freindId, @required this.freindAvatar, @required this.freindName});

  @override
  _ChattingState createState() =>
      _ChattingState(fId: freindId, fAvatar: freindAvatar , fName: freindName);
}

class _ChattingState extends State<Chatting> {
  _ChattingState({@required this.fId, @required this.fAvatar, @required this.fName});

  String fName;
  String fId;
  String fAvatar;
  String myId;

  var listMessage;
  String groupChatId;
  SharedPreferences sharedPreferences;

  File imageFile;
  bool isLoading;
  bool isShowSticker;
  String imageUrl;

  TextEditingController textEditingController = TextEditingController();
  ScrollController listScrollController = ScrollController();
  FocusNode focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    groupChatId = '';
    isLoading = false;
    imageUrl = '';

    readLocal();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      appBar: AppBar(
        title: Text(fName),
        centerTitle: true,
        elevation: 0.0,
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30.0),
            topRight: Radius.circular(30.0),
          ),
        ),
        child: Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                // List of messages
                buildListMessage(),

                // Input content
                sendMessageBar(),
              ],
            ),

            // Loading
            buildLoading()
          ],
        ),
      ),
    );
  }

  readLocal() async {
    sharedPreferences = await SharedPreferences.getInstance();
    myId = sharedPreferences.getString('uid');
    if (myId.hashCode <= fId.hashCode) {
      groupChatId = '$myId-$fId';
    } else {
      groupChatId = '$fId-$myId';
    }

    // Firestore.instance
    //     .collection('users')
    //     .document(myId)
    //     .updateData({'chattingWith': fId});

    setState(() {});
  }

  Future getImage() async {
    imageFile = await ImagePicker.pickImage(source: ImageSource.gallery);

    if (imageFile != null) {
      setState(() {
        isLoading = true;
      });
      uploadFile();
    }
  }

  Future uploadFile() async {
    String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    StorageReference reference = FirebaseStorage.instance.ref().child(fileName);
    StorageUploadTask uploadTask = reference.putFile(imageFile);
    StorageTaskSnapshot storageTaskSnapshot = await uploadTask.onComplete;
    storageTaskSnapshot.ref.getDownloadURL().then((downloadUrl) {
      imageUrl = downloadUrl;
      setState(() {
        isLoading = false;
        onSendMessage(imageUrl, 1);
      });
    }, onError: (err) {
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(msg: 'This file is not an image');
    });
  }

  void onSendMessage(String content, int type) {
    // type: 0 = text, 1 = image, 2 = sticker
    if (content.trim() != '') {
      textEditingController.clear();

      var documentReference = Firestore.instance
          .collection('messages')
          .document(groupChatId)
          .collection(groupChatId)
          .document(DateTime.now().millisecondsSinceEpoch.toString());

      Firestore.instance.runTransaction((transaction) async {
        await transaction.set(
          documentReference,
          {
            'idFrom': myId,
            'idTo': fId,
            'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
            'content': content,
            'type': type
          },
        );
      });
      listScrollController.animateTo(0.0,
          duration: Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      Fluttertoast.showToast(msg: 'Nothing to send');
    }
  }

  Widget buildListMessage() {
    return Flexible(
      child: groupChatId == ''
          ? Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(themeColor)))
          : StreamBuilder(
              stream: Firestore.instance
                  .collection('messages')
                  .document(groupChatId)
                  .collection(groupChatId)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                    ),
                  );
                } else {
                  listMessage = snapshot.data.documents;
                  return ListView.builder(
                    padding: EdgeInsets.all(10.0),
                    itemBuilder: (context, index) =>
                        buildItem(index, snapshot.data.documents[index]),
                    itemCount: snapshot.data.documents.length,
                    reverse: true,
                    controller: listScrollController,
                  );
                }
              },
            ),
    );
  }

  Widget buildItem(int index, DocumentSnapshot document) {
    if (document['idFrom'] == myId) {
      // right 'My messages'
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          document['type'] == 0
              ? Container(
                  child: Text(
                    document['content'],
                    style: TextStyle(color: myMessageText),
                  ),
                  padding: EdgeInsets.fromLTRB(15.0, 10.0, 15.0, 10.0),
                  width: 200.0,
                  decoration: BoxDecoration(
                    color: myMessageTheme,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  margin: EdgeInsets.only(
                      bottom: 10.0,
                      //  isLastMessageRight(index) ? 20.0 : 10.0,
                      right: 10.0),
                )
              : Container(
                  //image
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FlatButton(
                      child: CachedNetworkImage(
                        placeholder: (context, url) => Container(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              themeColor,
                            ),
                          ),
                          width: 200.0,
                          height: 200.0,
                          padding: EdgeInsets.all(70.0),
                          decoration: BoxDecoration(
                            color: myMessageTheme,
                            borderRadius: BorderRadius.all(
                              Radius.circular(12.0),
                            ),
                          ),
                        ),
                        errorWidget: (context, error, url) => Material(
                          child: Image.asset(
                            'assets/img_not_available.jpeg',
                            width: 200.0,
                            height: 200.0,
                            fit: BoxFit.cover,
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(8.0)),
                          clipBehavior: Clip.hardEdge,
                        ),
                        imageUrl: document['content'],
                        width: 200.0,
                        height: 200.0,
                        fit: BoxFit.cover,
                      ),
                      onPressed: () {},
                      padding: EdgeInsets.all(0),
                    ),
                  ),
                  margin: EdgeInsets.only(
                    bottom: 10.0,
                    // isLastMessageRight(index) ? 20.0 : 10.0,
                    right: 10.0,
                  ),
                ),
          // Time
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              child: Text(
                DateFormat('dd MMM kk:mm').format(
                  DateTime.fromMillisecondsSinceEpoch(
                    int.parse(document['timestamp']),
                  ),
                ),
                style: TextStyle(
                  color: greyColor,
                  fontSize: 12.0,
                  fontStyle: FontStyle.italic,
                ),
              ),
              margin: EdgeInsets.only(right: 12.0),
            ),
          )
        ],
      );
    } else {
      //left 'frend message
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          document['type'] == 0
              ? Container(
                  child: Text(
                    document['content'],
                    style: TextStyle(color: fmessageText),
                  ),
                  padding: EdgeInsets.fromLTRB(15.0, 10.0, 15.0, 10.0),
                  width: 200.0,
                  decoration: BoxDecoration(
                      color: fMessageTheme,
                      borderRadius: BorderRadius.circular(8.0)),
                  margin: EdgeInsets.only(left: 10.0, top: 4.0, bottom: 8.0),
                )
              : Container(
                  child: FlatButton(
                    child: Material(
                      child: CachedNetworkImage(
                        placeholder: (context, url) => Container(
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(themeColor),
                          ),
                          width: 200.0,
                          height: 200.0,
                          padding: EdgeInsets.all(70.0),
                          decoration: BoxDecoration(
                            color: fMessageTheme,
                            borderRadius:
                                BorderRadius.all(Radius.circular(8.0)),
                          ),
                        ),
                        errorWidget: (context, url, error) => Material(
                          child: Image.asset(
                            'images/img_not_available.jpeg',
                            width: 200.0,
                            height: 200.0,
                            fit: BoxFit.cover,
                          ),
                          borderRadius: BorderRadius.all(
                            Radius.circular(8.0),
                          ),
                          clipBehavior: Clip.hardEdge,
                        ),
                        imageUrl: document['content'],
                        width: 200.0,
                        height: 200.0,
                        fit: BoxFit.cover,
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(12.0)),
                      clipBehavior: Clip.hardEdge,
                    ),
                    onPressed: () {},
                    padding: EdgeInsets.all(0),
                  ),
                  margin: EdgeInsets.only(left: 10.0, bottom: 10.0),
                ),

          // Time
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              child: Text(
                DateFormat('dd MMM kk:mm').format(
                  DateTime.fromMillisecondsSinceEpoch(
                    int.parse(document['timestamp']),
                  ),
                ),
                style: TextStyle(
                  color: greyColor,
                  fontSize: 12.0,
                  fontStyle: FontStyle.italic,
                ),
              ),
              margin: EdgeInsets.only(left: 12.0),
            ),
          )
        ],
      );
    }
  }

  Widget buildLoading() {
    return Positioned(
      child: isLoading
          ? Container(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                ),
              ),
              color: Colors.white.withOpacity(0.8),
            )
          : Container(),
    );
  }

  Widget sendMessageBar() {
    return Container(
      margin: EdgeInsets.all(8.0),
      width: double.infinity,
      height: 50.0,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(45.0)),
        color: Colors.blue[50],
      ),
      child: Row(
        children: <Widget>[
          // buttom send Message
          Container(
            margin: EdgeInsets.only(left: 8.0),
            child: IconButton(
              icon: Icon(Icons.image, color: themeColor),
              onPressed: getImage,
            ),
          ),

          // Edit Text
          Flexible(
            child: TextField(
              style: TextStyle(color: primaryColor, fontSize: 14.0),
              controller: textEditingController,
              decoration: InputDecoration.collapsed(
                hintText: 'Type Your Message...',
                hintStyle: TextStyle(color: greyColor),
              ),
              focusNode: focusNode,
            ),
          ),

          IconButton(
            icon: Icon(Icons.send),
            onPressed: () => onSendMessage(textEditingController.text, 0),
            color: themeColor,
          ),
        ],
      ),
    );
  }
}
