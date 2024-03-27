import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<dynamic> searchResults = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, bool> favoritesMap = {};

  @override
  void initState() {
    super.initState();
    fetchUserFavorites();
  }

  Future<void> fetchUserFavorites() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot<Map<String, dynamic>> snapshot =
      await _firestore.collection('users').doc(user.uid).get();
      if (snapshot.exists) {
        Map<String, dynamic>? data = snapshot.data();
        if (data != null && data.containsKey('favorites')) {
          setState(() {
            favoritesMap = Map<String, bool>.fromIterable(
              List<String>.from(data['favorites']),
              key: (item) => item,
              value: (_) => true,
            );
          });
        }
      }
    }
  }

  Future<void> addToFavorites(dynamic song) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'favorites': FieldValue.arrayUnion([song['trackId'].toString()]),
        }, SetOptions(merge: true));
        setState(() {
          favoritesMap[song['trackId'].toString()] = true;
        });
      }
    } catch (e) {
      print('Error adding to favorites: $e');
    }
  }

  Future<void> removeFromFavorites(dynamic song) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'favorites': FieldValue.arrayRemove([song['trackId'].toString()]),
        }, SetOptions(merge: true));
        setState(() {
          favoritesMap[song['trackId'].toString()] = false;
        });
      }
    } catch (e) {
      print('Error removing from favorites: $e');
    }
  }

  Future<void> searchSongs(String term) async {
    final response = await http.get(Uri.parse(
        'https://itunes.apple.com/search?term=$term&entity=song&limit=20'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        searchResults = data['results'];
      });
    } else {
      print('Failed to load songs');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search song'),
      ),
      body: Column(
        children: [
          TextField(
            onSubmitted: (value) {
              searchSongs(value);
            },
            decoration: InputDecoration(
              labelText: 'Songs',
              contentPadding: EdgeInsets.all(16.0),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                final song = searchResults[index];
                final isFavorite =
                    favoritesMap[song['trackId'].toString()] ?? false;
                return ListTile(
                  title: Text(song['trackName']),
                  subtitle: Text(song['artistName']),
                  trailing: IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : null,
                    ),
                    onPressed: () {
                      if (isFavorite) {
                        removeFromFavorites(song);
                      } else {
                        addToFavorites(song);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
