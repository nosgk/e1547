import 'package:e1547/client/client.dart';
import 'package:e1547/identity/identity.dart';
import 'package:e1547/shared/shared.dart';
import 'package:flutter/material.dart';

class UserDrawerHeader extends StatelessWidget {
  const UserDrawerHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<Client>(
      builder: (context, client, child) => const Padding(
        padding: EdgeInsets.fromLTRB(10, 12, 10, 4),
        child: Center(child: CurrentIdentityTile()),
      ),
    );
  }
}
