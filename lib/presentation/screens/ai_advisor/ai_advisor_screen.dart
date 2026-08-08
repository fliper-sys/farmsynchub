import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/ai_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/ai_topic.dart';
import '../../../domain/models/chat_message.dart';
import '../../../providers/ai_chat_provider.dart';
import '../../../providers/app_preferences_provider.dart';

/// A focused, chat-first AI advisor screen: the message list is the whole
/// screen, the composer stays fixed at the bottom, and everything else
/// (topic switching, quick-start suggestions) lives in compact, dismissable
/// surfaces instead of permanent hero/grid chrome above the conversation.
class AiAdvisorScreen extends ConsumerStatefulWidget {
  const AiAdvisorScreen({super.key});

  @override
  ConsumerState<AiAdvisorScreen> createState() => _AiAdvisorScreenState();
}

class _AiAdvisorScreenState extends ConsumerState<AiAdvisorScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  Uint8List? _selectedImageBytes;
  String? _selectedImageLabel;
  int _lastMessageCount = -1;
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    _chatScrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!_chatScrollController.hasClients) return;
    final double distanceFromBottom = _chatScrollController.position.maxScrollExtent -
        _chatScrollController.position.pixels;
    final bool shouldShow = distanceFromBottom > 240;
    if (shouldShow != _showScrollToBottom) {
      setState(() => _showScrollToBottom = shouldShow);
    }
  }

  @override
  void dispose() {
    _chatScrollController.removeListener(_handleScroll);
    _messageController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AiProvider ai = ref.watch(aiChatProvider);
    final AppLanguage language = ref.watch(appLanguageProvider);

    if (!ai.isInitialized) {
      return const _AiLoadingScreen();
    }

    if (ai.activeMessages.length != _lastMessageCount) {
      _lastMessageCount = ai.activeMessages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    final List<ChatMessage> messages = ai.activeMessages;
    final bool isBusy = ai.isActiveLoading || ai.isActiveCoolingDown;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _aiBackground(context),
      appBar: AppBar(
        backgroundColor: _aiBackground(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).canPop()
              ? Navigator.of(context).pop()
              : context.go('/dashboard'),
        ),
        title: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openTopicSwitcher(context, ai, language),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(ai.activeTopic.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      ai.activeTopic.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _aiText(context),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      ai.modelName,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: _aiMuted(context)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.expand_more_rounded, size: 18, color: _aiMuted(context)),
            ],
          ),
        ),
        actions: <Widget>[
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: _aiText(context)),
            onSelected: (String value) async {
              if (value == 'clear-topic') {
                await ai.clearTopic(ai.activeTopic);
              } else if (value == 'clear-all') {
                await ai.clearAll();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'clear-topic',
                enabled: messages.isNotEmpty,
                child: Text(language.tr(
                    en: 'Clear this conversation',
                    ha: 'Share wannan tattaunawar',
                    fr: 'Effacer cette conversation')),
              ),
              PopupMenuItem<String>(
                value: 'clear-all',
                child: Text(language.tr(
                    en: 'Clear all conversations',
                    ha: 'Share dukkan tattaunawa',
                    fr: 'Effacer toutes les conversations')),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (!ai.hasApiKey) _OfflineNotice(language: language),
            Expanded(
              child: messages.isEmpty
                  ? _EmptyState(
                      language: language,
                      topic: ai.activeTopic,
                      onSuggestionTap: (AiStudioAction action) =>
                          _runStudioAction(ai, action),
                    )
                  : Stack(
                      children: <Widget>[
                        ListView.builder(
                          controller: _chatScrollController,
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                          itemCount: messages.length,
                          itemBuilder: (BuildContext context, int index) {
                            final ChatMessage message = messages[index];
                            if (message.isLoading) {
                              return const Padding(
                                padding: EdgeInsets.only(bottom: 10),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _TypingBubble(),
                                ),
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ChatBubble(language: language, message: message),
                            );
                          },
                        ),
                        if (_showScrollToBottom)
                          Positioned(
                            bottom: 8,
                            right: 0,
                            left: 0,
                            child: Center(
                              child: _ScrollToBottomButton(onTap: () {
                                _scrollToBottom();
                              }),
                            ),
                          ),
                      ],
                    ),
            ),
            if (ai.isActiveCoolingDown)
              _CooldownBanner(
                seconds: ai.cooldownRemainingFor(ai.activeTopic).inSeconds + 1,
                language: language,
              ),
            _Composer(
              language: language,
              controller: _messageController,
              isBusy: isBusy,
              selectedImageBytes: _selectedImageBytes,
              selectedImageLabel: _selectedImageLabel,
              onSend: () => _sendMessage(ai),
              onAttach: () => _showAttachSheet(context),
              onRemoveImage: _clearSelectedImage,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage(AiProvider ai) async {
    if (ai.isActiveLoading || ai.isActiveCoolingDown) {
      return;
    }

    final String text = _messageController.text.trim();
    if (text.isEmpty && _selectedImageBytes == null) {
      return;
    }

    final String message = text.isEmpty
        ? 'Please inspect this image carefully. Provide a likely diagnosis, specific signs I should look for to confirm, and a practical list of next steps for my farm.'
        : text;

    _messageController.clear();
    final Uint8List? imageBytes = _selectedImageBytes;
    _clearSelectedImage();
    await ai.sendMessage(message, imageBytes: imageBytes);
  }

  Future<void> _runStudioAction(AiProvider ai, AiStudioAction action) async {
    if (ai.isActiveLoading || ai.isActiveCoolingDown) {
      return;
    }

    await ai.setTopic(action.topic);
    await ai.sendSuggestion(action.prompt);
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? file = await _imagePicker.pickImage(
      source: source,
      imageQuality: 78,
      maxWidth: 1600,
    );
    if (file == null || !mounted) {
      return;
    }

    final Uint8List bytes = await file.readAsBytes();
    setState(() {
      _selectedImageBytes = bytes;
      _selectedImageLabel = file.name;
    });

    await ref.read(aiChatProvider).setTopic(AiTopic.diseaseAndPest);
  }

  void _clearSelectedImage() {
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedImageBytes = null;
      _selectedImageLabel = null;
    });
  }

  void _scrollToBottom() {
    if (!_chatScrollController.hasClients) {
      return;
    }
    _chatScrollController.animateTo(
      _chatScrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _showAttachSheet(BuildContext context) async {
    final AppLanguage language = ref.read(appLanguageProvider);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _aiSurface(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _aiBorder(context)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.camera_alt_rounded, color: _aiText(context)),
                title: Text(
                  language.tr(en: 'Take a photo', ha: 'Dauki hoto', fr: 'Prendre une photo'),
                  style: TextStyle(color: _aiText(context)),
                ),
                subtitle: Text(
                  language.tr(
                      en: 'For diagnosing crop, leaf, or animal issues',
                      ha: 'Domin gano matsalar amfanin gona, ganye, ko dabba',
                      fr: 'Pour diagnostiquer les problemes de culture, de feuille ou d\'animal'),
                  style: TextStyle(color: _aiMuted(context), fontSize: 12),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.image_outlined, color: _aiText(context)),
                title: Text(
                  language.tr(en: 'Choose from gallery', ha: 'Zaba daga zauren hoto', fr: 'Choisir dans la galerie'),
                  style: TextStyle(color: _aiText(context)),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openTopicSwitcher(
      BuildContext context, AiProvider ai, AppLanguage language) async {
    final AiTopic? selected = await showModalBottomSheet<AiTopic>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => _TopicSwitcherSheet(
        language: language,
        activeTopic: ai.activeTopic,
        countFor: (AiTopic topic) => ai
            .messagesFor(topic)
            .where((ChatMessage m) => !m.isLoading)
            .length,
      ),
    );
    if (selected != null) {
      await ai.setTopic(selected);
    }
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE1B8).withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.wifi_off_rounded, size: 18, color: Color(0xFF7A4B00)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              language.tr(
                  en: 'AI advisor needs an internet connection to answer questions or inspect photos.',
                  ha: 'Mai ba da shawara na AI yana bukatar hanyar sadarwa domin amsa tambayoyi ko duba hotuna.',
                  fr: 'Le conseiller IA a besoin d\'une connexion internet pour repondre aux questions ou inspecter des photos.'),
              style: const TextStyle(color: Color(0xFF7A4B00), fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _CooldownBanner extends StatelessWidget {
  const _CooldownBanner({required this.seconds, required this.language});

  final int seconds;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE1B8).withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.timer_outlined, size: 18, color: Color(0xFF7A4B00)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              language.tr(
                en: 'Please wait $seconds seconds before sending another request.',
                ha: 'Da fatan za a jira dakiku $seconds kafin aika wata bukata.',
                fr: 'Veuillez patienter $seconds secondes avant d\'envoyer une autre demande.',
              ),
              style: const TextStyle(color: Color(0xFF7A4B00), fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicSwitcherSheet extends StatelessWidget {
  const _TopicSwitcherSheet({
    required this.language,
    required this.activeTopic,
    required this.countFor,
  });

  final AppLanguage language;
  final AiTopic activeTopic;
  final int Function(AiTopic topic) countFor;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        decoration: BoxDecoration(
          color: _aiSurface(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _aiBorder(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              language.tr(en: 'Switch topic', ha: 'Sauya batu', fr: 'Changer de sujet'),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: _aiText(context), fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              language.tr(
                  en: 'Jump back into a topic thread - each keeps its own history.',
                  ha: 'Koma cikin batun tattaunawa - kowanne yana da tarihinsa.',
                  fr: 'Reprenez un fil de discussion - chacun garde son propre historique.'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _aiMuted(context)),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final AiTopic topic in AiTopic.values)
                    ListTile(
                      leading: Text(topic.emoji, style: const TextStyle(fontSize: 20)),
                      title: Text(topic.label, style: TextStyle(color: _aiText(context), fontWeight: FontWeight.w600)),
                      subtitle: Text(topic.description, style: TextStyle(color: _aiMuted(context), fontSize: 12)),
                      trailing: topic == activeTopic
                          ? Icon(Icons.check_circle_rounded, color: AppColors.primary)
                          : countFor(topic) > 0
                              ? CircleAvatar(
                                  radius: 11,
                                  backgroundColor: _aiBorder(context),
                                  child: Text(
                                    '${countFor(topic)}',
                                    style: TextStyle(fontSize: 10, color: _aiText(context)),
                                  ),
                                )
                              : null,
                      onTap: () => Navigator.of(context).pop(topic),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.language,
    required this.topic,
    required this.onSuggestionTap,
  });

  final AppLanguage language;
  final AiTopic topic;
  final ValueChanged<AiStudioAction> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    final List<AiStudioAction> suggestions = _studioActionsFor(language);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      children: <Widget>[
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 30),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          language.tr(
              en: 'Ask me anything about your farm',
              ha: 'Yi mini tambaya kan gonarka',
              fr: 'Posez-moi une question sur votre ferme'),
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: _aiText(context), fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          language.tr(
              en: 'Type a question or attach a photo for a diagnosis. Try one of these to get started:',
              ha: 'Rubuta tambaya ko haɗa hoto domin gano matsala. Gwada daya daga cikin wadannan domin farawa:',
              fr: 'Tapez une question ou joignez une photo pour un diagnostic. Essayez l\'une de ces suggestions pour commencer :'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _aiMuted(context)),
        ),
        const SizedBox(height: 20),
        for (final AiStudioAction action in suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SuggestionTile(action: action, onTap: () => onSuggestionTap(action)),
          ),
      ],
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.action, required this.onTap});

  final AiStudioAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _aiSurfaceAlt(context),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: action.tint.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(action.icon, size: 19, color: action.tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(action.title,
                        style: TextStyle(color: _aiText(context), fontWeight: FontWeight.w700, fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text(action.subtitle,
                        style: TextStyle(color: _aiMuted(context), fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _aiMuted(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.language,
    required this.controller,
    required this.isBusy,
    required this.selectedImageBytes,
    required this.selectedImageLabel,
    required this.onSend,
    required this.onAttach,
    required this.onRemoveImage,
  });

  final AppLanguage language;
  final TextEditingController controller;
  final bool isBusy;
  final Uint8List? selectedImageBytes;
  final String? selectedImageLabel;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onRemoveImage;

  @override
  Widget build(BuildContext context) {
    // A floating pill card with visible margin on every side (rather than
    // an edge-to-edge bar with a top border) so the background shows
    // through around it, matching Claude's own floating composer.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: BoxDecoration(
          color: _aiSurfaceAlt(context),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _aiBorder(context)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(_aiIsDark(context) ? 0.25 : 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (selectedImageBytes != null) ...<Widget>[
              _AttachmentPreview(
                bytes: selectedImageBytes!,
                label: selectedImageLabel ??
                    language.tr(en: 'Attached image', ha: 'Hoton da aka haɗa', fr: 'Image jointe'),
                onRemove: onRemoveImage,
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              style: TextStyle(color: _aiText(context), height: 1.4),
              decoration: InputDecoration(
                hintText: language.tr(
                    en: 'Write a message...',
                    ha: 'Rubuta sako...',
                    fr: 'Ecrivez un message...'),
                hintStyle: TextStyle(color: _aiMuted(context)),
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              onSubmitted: (_) {
                if (!isBusy) onSend();
              },
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: isBusy ? null : onAttach,
                  icon: Icon(Icons.add_circle_outline_rounded, color: _aiText(context)),
                  tooltip: language.tr(en: 'Attach photo', ha: 'Haɗa hoto', fr: 'Joindre une photo'),
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                _SendButton(isLoading: isBusy, onTap: isBusy ? null : onSend),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.isLoading,
    required this.onTap,
  });

  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onTap == null ? AppColors.primary.withOpacity(0.4) : AppColors.primary,
        ),
        child: isLoading
            ? const Padding(
                padding: EdgeInsets.all(13),
                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
              )
            : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.bytes,
    required this.label,
    required this.onRemove,
  });

  final Uint8List bytes;
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _aiSurfaceAlt(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _aiBorder(context)),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(bytes, width: 44, height: 44, fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _aiText(context), fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(Icons.close_rounded, size: 18, color: _aiMuted(context)),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Renders a chat turn the way Claude's own chat surface does: the user's
/// own message sits in a compact right-aligned pill, while the assistant's
/// reply is plain full-width text with no bubble/border - just the answer,
/// with lightweight **bold** and "- " bullet support so structured advice
/// (steps, headings) reads clearly without a markdown package.
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.language, required this.message});

  final AppLanguage language;
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final bool fromUser = message.isFromUser;

    if (fromUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (message.hasImage)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.image_rounded, size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          language.tr(en: 'Image attached', ha: 'Hoto ya hade', fr: 'Image jointe'),
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                SelectableText(
                  message.text,
                  style: const TextStyle(color: Colors.white, height: 1.5, fontSize: 14.5),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: _MarkdownLiteText(text: message.text, color: _aiText(context)),
    );
  }
}

/// A minimal **bold** + "- bullet" renderer - enough to read Gemini's
/// structured answers (headings, numbered steps, bullet lists) as intended
/// without pulling in a full markdown package.
class _MarkdownLiteText extends StatelessWidget {
  const _MarkdownLiteText({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final List<String> lines = text.split('\n');
    return SelectableText.rich(
      TextSpan(
        children: <InlineSpan>[
          for (int i = 0; i < lines.length; i++) ...<InlineSpan>[
            if (i > 0) const TextSpan(text: '\n'),
            ..._lineSpans(lines[i]),
          ],
        ],
      ),
      style: TextStyle(color: color, height: 1.55, fontSize: 14.5),
    );
  }

  List<InlineSpan> _lineSpans(String rawLine) {
    final bool isBullet = rawLine.trimLeft().startsWith('- ') || rawLine.trimLeft().startsWith('* ');
    final String line = isBullet ? '•  ${rawLine.trimLeft().substring(2)}' : rawLine;
    final List<InlineSpan> spans = <InlineSpan>[];
    final RegExp boldPattern = RegExp(r'\*\*(.+?)\*\*');
    int cursor = 0;
    for (final RegExpMatch match in boldPattern.allMatches(line)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: line.substring(cursor, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ));
      cursor = match.end;
    }
    if (cursor < line.length) {
      spans.add(TextSpan(text: line.substring(cursor)));
    }
    return spans;
  }
}

class _ScrollToBottomButton extends StatelessWidget {
  const _ScrollToBottomButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _aiSurfaceAlt(context),
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _aiBorder(context))),
          child: Icon(Icons.arrow_downward_rounded, size: 18, color: _aiText(context)),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _aiSurfaceAlt(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _aiBorder(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const <Widget>[
          _Dot(delay: 0),
          SizedBox(width: 4),
          _Dot(delay: 150),
          SizedBox(width: 4),
          _Dot(delay: 300),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.delay});

  final int delay;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _AiLoadingScreen extends StatelessWidget {
  const _AiLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _aiBackground(context),
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

class AiStudioAction {
  const AiStudioAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.topic,
    required this.prompt,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final AiTopic topic;
  final String prompt;
}

List<AiStudioAction> _studioActionsFor(AppLanguage language) => <AiStudioAction>[
      AiStudioAction(
        title: language.tr(en: 'Text writer', ha: 'Marubucin Rubutu', fr: 'Redacteur de texte'),
        subtitle: language.tr(
            en: 'Turn a farm idea into a clear update.',
            ha: 'Mayar da tunanin gona zuwa sabuntawa mai fayyace.',
            fr: 'Transformez une idee agricole en une mise a jour claire.'),
        icon: Icons.edit_note_rounded,
        tint: const Color(0xFFFF4FD8),
        topic: AiTopic.general,
        prompt: 'Help me write a clear farm update for farmers about what I am doing this week.',
      ),
      AiStudioAction(
        title: language.tr(en: 'Image doctor', ha: 'Likitan Hoto', fr: 'Docteur image'),
        subtitle: language.tr(
            en: 'Inspect a crop, leaf, or animal photo.',
            ha: 'Duba hoton amfanin gona, ganye, ko dabba.',
            fr: 'Inspectez une photo de culture, de feuille ou d\'animal.'),
        icon: Icons.camera_alt_rounded,
        tint: const Color(0xFF37D7FF),
        topic: AiTopic.diseaseAndPest,
        prompt: 'Inspect this image and help me diagnose the likely problem and next action.',
      ),
      AiStudioAction(
        title: language.tr(en: 'Crop planner', ha: 'Mai Tsara Amfanin Gona', fr: 'Planificateur de cultures'),
        subtitle: language.tr(
            en: 'Build planting and feeding schedules.',
            ha: 'Gina jadawalin shuka da ciyarwa.',
            fr: 'Etablissez des calendriers de plantation et d\'alimentation.'),
        icon: Icons.spa_rounded,
        tint: const Color(0xFF7C3AED),
        topic: AiTopic.cropManagement,
        prompt: 'Create a practical crop management plan with tasks I should do this week.',
      ),
      AiStudioAction(
        title: language.tr(en: 'Animal coach', ha: 'Kocin Dabbobi', fr: 'Coach animalier'),
        subtitle: language.tr(
            en: 'Ask about feeding, hygiene, and health.',
            ha: 'Yi tambaya kan ciyarwa, tsafta, da lafiya.',
            fr: 'Posez des questions sur l\'alimentation, l\'hygiene et la sante.'),
        icon: Icons.pets_rounded,
        tint: const Color(0xFFFFC271),
        topic: AiTopic.animalHealth,
        prompt: 'Review my livestock care routine and give me practical advice for today.',
      ),
      AiStudioAction(
        title: language.tr(en: 'Weather plan', ha: 'Shirin Yanayi', fr: 'Plan meteo'),
        subtitle: language.tr(
            en: 'Plan work around weather patterns.',
            ha: 'Tsara aiki bisa yanayin sararin samaniya.',
            fr: 'Planifiez le travail selon les conditions meteorologiques.'),
        icon: Icons.wb_cloudy_rounded,
        tint: const Color(0xFF1ED6A8),
        topic: AiTopic.weatherAndClimate,
        prompt: 'Give me a weather-aware work plan for today and the next few days.',
      ),
      AiStudioAction(
        title: language.tr(en: 'Market notes', ha: 'Bayanan Kasuwa', fr: 'Notes de marche'),
        subtitle: language.tr(
            en: 'Pricing, sales, and profitability help.',
            ha: 'Taimako kan farashi, tallace-tallace, da riba.',
            fr: 'Aide sur les prix, les ventes et la rentabilite.'),
        icon: Icons.storefront_rounded,
        tint: const Color(0xFFFFA24C),
        topic: AiTopic.marketAndFinance,
        prompt: 'Help me think through pricing, sales timing, and profitability for my farm.',
      ),
    ];

bool _aiIsDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

Color _aiBackground(BuildContext context) {
  return _aiIsDark(context) ? const Color(0xFF0A0A0E) : const Color(0xFFF7F5EF);
}

Color _aiSurface(BuildContext context) {
  return _aiIsDark(context) ? const Color(0xFF121216) : Theme.of(context).colorScheme.surface;
}

Color _aiSurfaceAlt(BuildContext context) {
  return _aiIsDark(context)
      ? const Color(0xFF17171C)
      : Theme.of(context).colorScheme.surfaceContainerHighest;
}

Color _aiBorder(BuildContext context) {
  return _aiIsDark(context) ? Colors.white.withOpacity(0.08) : Theme.of(context).colorScheme.outlineVariant;
}

Color _aiText(BuildContext context) {
  return _aiIsDark(context) ? Colors.white : Theme.of(context).colorScheme.onSurface;
}

Color _aiMuted(BuildContext context) {
  return _aiIsDark(context) ? Colors.white70 : Theme.of(context).colorScheme.onSurfaceVariant;
}
