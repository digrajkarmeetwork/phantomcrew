import 'dart:async';
import 'package:flutter/material.dart';
import '../../ui/theme.dart';
import '../models/game_state.dart';
import '../models/player_model.dart';
import '../network/relay_client.dart';
import '../network/room_manager.dart';

class MeetingScreen extends StatefulWidget {
  final GameState state;
  final RelayClient relay;
  final RoomManager roomManager;
  const MeetingScreen({super.key, required this.state, required this.relay, required this.roomManager});

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> {
  final _chatCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _timer;
  String? _myVote;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChange);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
      if (widget.state.meetingTimeRemaining == Duration.zero) {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    _timer?.cancel();
    widget.state.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (!mounted) return;
    if (!widget.state.meetingActive) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendChat() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    widget.roomManager.sendChat(text);
    _chatCtrl.clear();
  }

  void _vote(String targetId) {
    if (_myVote != null) return;
    if (!widget.state.isVotingPhase) return;
    setState(() => _myVote = targetId);
    widget.roomManager.sendVote(targetId);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final remaining = state.meetingTimeRemaining;
    final isVoting = state.isVotingPhase;
    final alivePlayers = state.alivePlayers;
    final myId = state.localPlayerId;
    final local = state.localPlayer;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/ui/meeting_overlay.png', fit: BoxFit.cover),
          ),
          Positioned.fill(child: Container(color: Colors.black.withAlpha(190))),
          SafeArea(
            child: Column(
              children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: PhantomTheme.panelBg,
                border: Border(bottom: BorderSide(color: PhantomTheme.divider)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.crisis_alert, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVoting ? 'VOTING IN PROGRESS' : 'EMERGENCY ASSEMBLY',
                          style: const TextStyle(fontFamily: 'Orbitron', fontSize: 13, color: Colors.amber),
                        ),
                        Text(
                          'Called by: ${state.players[state.meetingCallerId]?.name ?? "Unknown"}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  // Timer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: remaining.inSeconds < 10 ? PhantomTheme.red.withAlpha(30) : PhantomTheme.cardBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${remaining.inSeconds}s',
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        fontSize: 16,
                        color: remaining.inSeconds < 10 ? PhantomTheme.red : PhantomTheme.teal,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Row(
                children: [
                  // Player list / voting panel
                  SizedBox(
                    width: 160,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(isVoting ? 'VOTE TO EJECT' : 'CREW',
                            style: const TextStyle(color: PhantomTheme.textSecondary, fontSize: 11, letterSpacing: 1)),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            children: [
                              ...alivePlayers.map((p) => _VoteCard(
                                player: p,
                                isLocal: p.id == myId,
                                myVote: _myVote,
                                voteCount: state.room?.voteResults[p.id] ?? 0,
                                canVote: isVoting && _myVote == null && local?.isAlive == true,
                                onVote: () => _vote(p.id),
                              )),
                              if (isVoting && _myVote == null && local?.isAlive == true)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: GestureDetector(
                                    onTap: () => _vote('skip'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: PhantomTheme.cardBg,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: _myVote == 'skip' ? PhantomTheme.teal : PhantomTheme.divider),
                                      ),
                                      child: const Center(child: Text('SKIP', style: TextStyle(color: PhantomTheme.textSecondary, fontSize: 11, fontFamily: 'Orbitron'))),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Chat
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.all(8),
                            itemCount: state.chatMessages.length,
                            itemBuilder: (_, i) {
                              final msg = state.chatMessages[i];
                              final isMe = msg.senderId == myId;
                              return Align(
                                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  constraints: const BoxConstraints(maxWidth: 200),
                                  decoration: BoxDecoration(
                                    color: isMe ? PhantomTheme.teal.withAlpha(30) : PhantomTheme.cardBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: isMe ? PhantomTheme.teal.withAlpha(80) : PhantomTheme.divider),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (!isMe) Text(msg.senderName, style: const TextStyle(color: PhantomTheme.teal, fontSize: 10, fontWeight: FontWeight.bold)),
                                      Text(msg.text, style: const TextStyle(color: PhantomTheme.textPrimary, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Chat input (only during discussion, not voting, and only if alive)
                        if (!isVoting && local?.isAlive == true)
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _chatCtrl,
                                    maxLength: 120,
                                    decoration: const InputDecoration(
                                      hintText: 'Say something...',
                                      counterText: '',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      isDense: true,
                                    ),
                                    onSubmitted: (_) => _sendChat(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.send, color: PhantomTheme.teal),
                                  onPressed: _sendChat,
                                ),
                              ],
                            ),
                          ),
                        if (local?.isGhost == true)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('Ghosts cannot speak.', style: TextStyle(color: PhantomTheme.textSecondary, fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoteCard extends StatelessWidget {
  final PlayerModel player;
  final bool isLocal;
  final String? myVote;
  final int voteCount;
  final bool canVote;
  final VoidCallback onVote;

  const _VoteCard({
    required this.player,
    required this.isLocal,
    required this.myVote,
    required this.voteCount,
    required this.canVote,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final isVoted = myVote == player.id;
    return GestureDetector(
      onTap: canVote ? onVote : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isVoted ? player.color.withAlpha(30) : PhantomTheme.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isVoted ? player.color : (isLocal ? PhantomTheme.teal.withAlpha(80) : PhantomTheme.divider),
            width: isVoted ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(width: 16, height: 16, decoration: BoxDecoration(color: player.color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Expanded(child: Text(player.name, style: const TextStyle(color: PhantomTheme.textPrimary, fontSize: 12), overflow: TextOverflow.ellipsis)),
            if (voteCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: PhantomTheme.red.withAlpha(40), borderRadius: BorderRadius.circular(4)),
                child: Text('$voteCount', style: const TextStyle(color: PhantomTheme.red, fontSize: 11, fontFamily: 'Orbitron')),
              ),
          ],
        ),
      ),
    );
  }
}
