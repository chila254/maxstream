import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/cloud_sync_service.dart';
import '../services/supabase_sync_service.dart';

/// Starts the cloud sync listener while the user is signed in and stops it
/// when they sign out, on any platform (phone or TV).
class CloudSyncBootstrap extends StatefulWidget {
  final Widget child;

  const CloudSyncBootstrap({super.key, required this.child});

  @override
  State<CloudSyncBootstrap> createState() => _CloudSyncBootstrapState();
}

class _CloudSyncBootstrapState extends State<CloudSyncBootstrap> {
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        CloudSyncService.stopListening();
        CloudSyncService.startListening();
        SupabaseSyncService.stopListening();
        SupabaseSyncService.startListening();
        SupabaseSyncService.pullToDevice();
      } else {
        CloudSyncService.stopListening();
        SupabaseSyncService.stopListening();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    CloudSyncService.stopListening();
    SupabaseSyncService.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
