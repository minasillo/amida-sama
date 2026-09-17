import 'package:amidakuji_app/model/couple_role.dart';
import 'package:amidakuji_app/model/participant.dart';
import 'package:amidakuji_app/view/amida_body.dart';
import 'package:amidakuji_app/view/data_upload_body.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('あみだくじ'),
          bottom: TabBar(
            tabs: [
              Tab(text: CoupleRole.groom.roleName),
              Tab(text: CoupleRole.bride.roleName),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _HomeBody(
              wininngImagePath: CoupleRole.groom.winningImagePath,
              allowManualLines: false,
            ),
            _HomeBody(
              wininngImagePath: CoupleRole.bride.winningImagePath,
              allowManualLines: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeBody extends StatefulWidget {
  const _HomeBody({required this.wininngImagePath, required this.allowManualLines});

  final String wininngImagePath;
  final bool allowManualLines;

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody>
    with AutomaticKeepAliveClientMixin {
  bool isUpload = false;
  List<Participant> participantList = [];

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return isUpload
        ? AmidaBody(
            participantList: participantList,
            wininngImagePath: widget.wininngImagePath,
            allowManualLines: widget.allowManualLines,
          )
        : Padding(
            padding: const EdgeInsets.all(16),
            child: DataUploadBody(
              onGenerated: (list) {
                setState(() {
                  isUpload = true;
                  participantList = list;
                });
              },
            ),
          );
  }
}
