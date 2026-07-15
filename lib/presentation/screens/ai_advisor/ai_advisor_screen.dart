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

class AiAdvisorScreen extends ConsumerStatefulWidget {
  const AiAdvisorScreen({super.key});

  @override
  ConsumerState<AiAdvisorScreen> createState() => _AiAdvisorScreenState();
}

class _AiAdvisorScreenState extends ConsumerState<AiAdvisorScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  Uint8List? _selectedImageBytes;
  String? _selectedImageLabel;
  int _lastMessageCount = -1;

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AiProvider ai = ref.watch(aiChatProvider);
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    if (!ai.isInitialized) {
      return const _AiLoadingScreen();
    }

    if (ai.activeMessages.length != _lastMessageCount) {
      _lastMessageCount = ai.activeMessages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _aiBackground(context),
      body: Stack(
        children: <Widget>[
          _StudioBackdrop(isDark: isDark),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _TopBar(
                            onBack: () => Navigator.of(context).canPop()
                                ? Navigator.of(context).pop()
                                : context.go('/dashboard'),
                            onPremiumTap: () => _showPremiumSnack(context),
                            onMenuAction: (String value) async {
                              if (value == 'clear-topic') {
                                await ai.clearTopic(ai.activeTopic);
                              } else if (value == 'clear-all') {
                                await ai.clearAll();
                              }
                            },
                          ),
                          const SizedBox(height: 18),
                          _HeroCard(
                            ai: ai,
                            onPremiumTap: () => _showPremiumSnack(context),
                            onQuickPrompt: (String prompt) => _sendQuickPrompt(ai, prompt),
                          ),
                          const SizedBox(height: 14),
                          _SearchBar(
                            controller: _searchController,
                            onSubmitted: (String text) => _runSearchPrompt(ai, text),
                          ),
                          const SizedBox(height: 18),
                          _StatusRow(ai: ai),
                          const SizedBox(height: 18),
                          _SectionHeader(
                            title: 'Studio tools',
                            subtitle: 'One-tap prompts for the most common farm tasks.',
                            trailing: Text(
                              ai.modelName,
                              style: theme.textTheme.labelLarge?.copyWith(color: _aiMuted(context)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _StudioGrid(
                            onTapAction: (AiStudioAction action) => _runStudioAction(ai, action),
                          ),
                          const SizedBox(height: 20),
                          _SectionHeader(
                            title: 'For you',
                            subtitle: 'Jump back into a topic thread or start fresh from a saved context.',
                            trailing: TextButton(
                              style: TextButton.styleFrom(foregroundColor: _aiText(context)),
                              onPressed: () => ai.setTopic(AiTopic.general),
                              child: const Text('General'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _HistoryRail(
                            ai: ai,
                            onTopicSelected: (AiTopic topic) => ai.setTopic(topic),
                          ),
                          const SizedBox(height: 20),
                          _SectionHeader(
                            title: 'Live chat',
                            subtitle: 'Ask a question, attach a photo, and keep the conversation focused on one topic.',
                            trailing: Text(
                              '${ai.activeMessageCount} messages',
                              style: theme.textTheme.labelLarge?.copyWith(color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _ChatSurface(
                            topic: ai.activeTopic,
                            messages: ai.activeMessages,
                            controller: _chatScrollController,
                            onClearTopic: () => ai.clearTopic(ai.activeTopic),
                          ),
                          if (ai.isActiveCoolingDown) ...<Widget>[
                            const SizedBox(height: 12),
                            _NoticeCard(
                              icon: Icons.timer_outlined,
                              tint: const Color(0xFFFFE1B8),
                              message:
                                  'Please wait ${ai.cooldownRemainingFor(ai.activeTopic).inSeconds + 1} seconds before sending another request.',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ComposerCard(
                    controller: _messageController,
                    isLoading: ai.isActiveLoading || ai.isActiveCoolingDown,
                    selectedImageBytes: _selectedImageBytes,
                    selectedImageLabel: _selectedImageLabel,
                    onSend: () => _sendMessage(ai),
                    onTakePhoto: () => _pickImage(ImageSource.camera),
                    onUploadImage: () => _pickImage(ImageSource.gallery),
                    onVoiceTap: () => _showVoiceComingSoon(context),
                    onRemoveImage: _clearSelectedImage,
                  ),
                ],
              ),
            ),
          ),
        ],
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

  Future<void> _runSearchPrompt(AiProvider ai, String text) async {
    if (ai.isActiveLoading || ai.isActiveCoolingDown) {
      return;
    }

    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _searchController.clear();
    await ai.setTopic(AiTopic.general);
    await ai.sendSuggestion(trimmed);
  }

  Future<void> _sendQuickPrompt(AiProvider ai, String prompt) async {
    if (ai.isActiveLoading || ai.isActiveCoolingDown) {
      return;
    }

    await ai.setTopic(AiTopic.general);
    await ai.sendSuggestion(prompt);
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

  void _showPremiumSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Premium AI tools can be added here later.')),
    );
  }

  void _showVoiceComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voice input is coming soon.')),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onBack,
    required this.onPremiumTap,
    required this.onMenuAction,
  });

  final VoidCallback onBack;
  final VoidCallback onPremiumTap;
  final ValueChanged<String> onMenuAction;

  @override
  Widget build(BuildContext context) {
    final bool isDark = _aiIsDark(context);
    return Row(
      children: <Widget>[
        _GlassButton(
          icon: Icons.arrow_back_rounded,
          onTap: onBack,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Farmsync AI',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _aiText(context),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        GestureDetector(
          onTap: onPremiumTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF17171C) : Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _aiBorder(context)),
            ),
            child: Text(
              'Try premium',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: _aiText(context),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        PopupMenuButton<String>(
          color: _aiSurface(context),
          icon: Icon(Icons.more_vert_rounded, color: _aiText(context)),
          onSelected: onMenuAction,
          itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
            PopupMenuItem<String>(value: 'clear-topic', child: Text('Clear this topic')),
            PopupMenuItem<String>(value: 'clear-all', child: Text('Clear all chats')),
          ],
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.ai,
    required this.onPremiumTap,
    required this.onQuickPrompt,
  });

  final AiProvider ai;
  final VoidCallback onPremiumTap;
  final ValueChanged<String> onQuickPrompt;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = _aiIsDark(context);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121216) : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: _aiBorder(context)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.35) : Colors.black.withOpacity(0.08),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -16,
              right: -14,
              child: _GlowOrb(
                diameter: 120,
                colors: <Color>[
                  const Color(0xFFFF4FD8).withOpacity(0.35),
                  const Color(0xFF7C3AED).withOpacity(0.18),
                ],
              ),
            ),
            Positioned(
              bottom: -18,
              right: 70,
              child: _GlowOrb(
                diameter: 78,
                colors: <Color>[
                  const Color(0xFFFF6B6B).withOpacity(0.18),
                  const Color(0xFFFFC271).withOpacity(0.08),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1A20) : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _aiBorder(context)),
                      ),
                      child: Text(
                        'Farm AI workspace',
                        style: theme.textTheme.labelMedium?.copyWith(color: _aiMuted(context)),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onPremiumTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: const LinearGradient(
                            colors: <Color>[Color(0xFFFF4FD8), Color(0xFF7C3AED)],
                          ),
                        ),
                        child: Text(
                          'Premium',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Create, explore,\nbe inspired',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontFamily: 'DM Serif Display',
                    height: 0.96,
                    color: _aiText(context),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Ask for field plans, diagnose with images, review market ideas, and keep crop, livestock, and finance advice in one beautiful workspace.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _aiMuted(context),
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    _QuickBadge(
                      icon: Icons.spa_rounded,
                      label: 'Crop plans',
                      onTap: () => onQuickPrompt('Create a simple crop management plan for my farm this week.'),
                    ),
                    _QuickBadge(
                      icon: Icons.pets_rounded,
                      label: 'Animal care',
                      onTap: () => onQuickPrompt('Review my livestock care routine and suggest improvements.'),
                    ),
                    _QuickBadge(
                      icon: Icons.camera_alt_rounded,
                      label: 'Image check',
                      onTap: () => onQuickPrompt('Look at this image and help me diagnose the issue.'),
                    ),
                    _QuickBadge(
                      icon: Icons.storefront_rounded,
                      label: 'Market help',
                      onTap: () => onQuickPrompt('Help me plan a practical market and pricing strategy.'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                  child: _HeroStat(
                        label: 'Topic',
                        value: ai.activeTopic.label,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroStat(
                        label: 'Language',
                        value: ai.language,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroStat(
                        label: 'Model',
                        value: ai.modelName,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final bool isDark = _aiIsDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141418) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _aiBorder(context)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.search_rounded, color: _aiMuted(context)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(color: _aiText(context)),
              decoration: InputDecoration(
                hintText: 'Search or ask something farming-related...',
                hintStyle: TextStyle(color: _aiMuted(context)),
                border: InputBorder.none,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmitted,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.ai});

  final AiProvider ai;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatusPill(
            icon: Icons.track_changes_rounded,
            label: 'Topic',
            value: ai.activeTopic.label,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatusPill(
            icon: Icons.translate_rounded,
            label: 'Language',
            value: ai.language,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatusPill(
            icon: Icons.memory_rounded,
            label: 'Model',
            value: ai.modelName,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final bool isDark = _aiIsDark(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121216) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _aiBorder(context)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
            child: Icon(icon, size: 18, color: _aiText(context)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: _aiMuted(context))),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _aiText(context),
                        fontWeight: FontWeight.w700,
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Color textColor = _aiText(context);
    final Color mutedColor = _aiMuted(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: mutedColor,
                      height: 1.4,
                    ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

class _StudioGrid extends StatelessWidget {
  const _StudioGrid({required this.onTapAction});

  final ValueChanged<AiStudioAction> onTapAction;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _studioActions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.08,
      ),
      itemBuilder: (BuildContext context, int index) {
        final AiStudioAction action = _studioActions[index];
        return _StudioCard(
          action: action,
          onTap: () => onTapAction(action),
        );
      },
    );
  }
}

class _StudioCard extends StatelessWidget {
  const _StudioCard({
    required this.action,
    required this.onTap,
  });

  final AiStudioAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = _aiIsDark(context);
    return Material(
      color: isDark ? const Color(0xFF121216) : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _aiBorder(context)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Stack(
              children: <Widget>[
                Positioned(
                  top: -12,
                  right: -12,
                  child: _GlowOrb(
                    diameter: 84,
                    colors: <Color>[
                      action.tint.withOpacity(0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: action.tint.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(action.icon, color: _aiText(context)),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      action.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _aiText(context),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        action.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _aiMuted(context),
                              height: 1.45,
                            ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Icon(Icons.arrow_outward_rounded, color: _aiMuted(context)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryRail extends StatelessWidget {
  const _HistoryRail({
    required this.ai,
    required this.onTopicSelected,
  });

  final AiProvider ai;
  final ValueChanged<AiTopic> onTopicSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: AiTopic.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (BuildContext context, int index) {
          final AiTopic topic = AiTopic.values[index];
          final List<ChatMessage> messages = ai.messagesFor(topic).where((ChatMessage item) => !item.isLoading).toList(growable: false);
          final ChatMessage? lastMessage = messages.isEmpty ? null : messages.last;
          return _HistoryCard(
            topic: topic,
            messageCount: messages.length,
            preview: lastMessage?.text ?? 'No messages yet',
            onTap: () => onTopicSelected(topic),
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.topic,
    required this.messageCount,
    required this.preview,
    required this.onTap,
  });

  final AiTopic topic;
  final int messageCount;
  final String preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = _aiIsDark(context);
    return SizedBox(
      width: 220,
      child: Material(
        color: isDark ? const Color(0xFF121216) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _aiBorder(context)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(topic.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        topic.label,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: _aiText(context),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Text(
                    topic.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _aiMuted(context), height: 1.4),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$messageCount messages',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: 6),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _aiMuted(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatSurface extends StatelessWidget {
  const _ChatSurface({
    required this.topic,
    required this.messages,
    required this.controller,
    required this.onClearTopic,
  });

  final AiTopic topic;
  final List<ChatMessage> messages;
  final ScrollController controller;
  final VoidCallback onClearTopic;

  @override
  Widget build(BuildContext context) {
    final bool isDark = _aiIsDark(context);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101014) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _aiBorder(context)),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(topic.emoji, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        topic.label,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: _aiText(context),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Chat history for this topic stays here.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _aiMuted(context)),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: messages.isEmpty ? null : onClearTopic,
                  child: Text(
                    'Clear',
                    style: TextStyle(
                      color: messages.isEmpty ? Colors.white38 : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x1FFFFFFF)),
          SizedBox(
            height: 420,
            child: messages.isEmpty
                ? _EmptyConversation(topic: topic)
                : ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final ChatMessage message = messages[index];
                      if (message.isLoading) {
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: _TypingBubble(),
                        );
                      }
                      return _ChatBubble(message: message);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ComposerCard extends StatelessWidget {
  const _ComposerCard({
    required this.controller,
    required this.isLoading,
    required this.selectedImageBytes,
    required this.selectedImageLabel,
    required this.onSend,
    required this.onTakePhoto,
    required this.onUploadImage,
    required this.onVoiceTap,
    required this.onRemoveImage,
  });

  final TextEditingController controller;
  final bool isLoading;
  final Uint8List? selectedImageBytes;
  final String? selectedImageLabel;
  final VoidCallback onSend;
  final VoidCallback onTakePhoto;
  final VoidCallback onUploadImage;
  final VoidCallback onVoiceTap;
  final VoidCallback onRemoveImage;

  @override
  Widget build(BuildContext context) {
    final bool isDark = _aiIsDark(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121216) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _aiBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (selectedImageBytes != null) ...<Widget>[
            _AttachmentPreview(
              bytes: selectedImageBytes!,
              label: selectedImageLabel ?? 'Attached image',
              onRemove: onRemoveImage,
            ),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF17171C) : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _aiBorder(context)),
            ),
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              style: TextStyle(color: _aiText(context), height: 1.5),
              decoration: InputDecoration(
                hintText: 'Send a message, ask for a plan, or describe what you see...',
                hintStyle: TextStyle(color: _aiMuted(context)),
                border: InputBorder.none,
              ),
              onSubmitted: (_) {
                if (!isLoading) {
                  onSend();
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _RoundActionButton(
                icon: Icons.camera_alt_rounded,
                label: 'Photo',
                onTap: isLoading ? null : onTakePhoto,
              ),
              _RoundActionButton(
                icon: Icons.image_outlined,
                label: 'Gallery',
                onTap: isLoading ? null : onUploadImage,
              ),
              _RoundActionButton(
                icon: Icons.mic_none_rounded,
                label: 'Voice',
                onTap: isLoading ? null : onVoiceTap,
              ),
              _SendButton(
                isLoading: isLoading,
                onTap: isLoading ? null : onSend,
              ),
            ],
          ),
        ],
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
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFFFF4FD8), Color(0xFF7C3AED)],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFFFF4FD8).withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: isLoading
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
              )
            : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = _aiIsDark(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF17171C) : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _aiBorder(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 18, color: _aiText(context)),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: _aiText(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
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
    final bool isDark = _aiIsDark(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF17171C) : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _aiBorder(context)),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(bytes, width: 68, height: 68, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: _aiText(context))),
                const SizedBox(height: 4),
                Text(
                  'This will be sent with the next AI request.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _aiMuted(context)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(Icons.close_rounded, color: _aiMuted(context)),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final bool fromUser = message.isFromUser;
    final ThemeData theme = Theme.of(context);
    final bool isDark = _aiIsDark(context);
    final Color bubbleSurface = isDark ? const Color(0xFF17171C) : theme.colorScheme.surfaceContainerHighest;

    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Container(
          decoration: BoxDecoration(
            gradient: fromUser
                ? const LinearGradient(
                    colors: <Color>[Color(0xFFFF4FD8), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: fromUser ? null : bubbleSurface,
            borderRadius: BorderRadius.circular(24),
            border: fromUser ? null : Border.all(color: _aiBorder(context)),
            boxShadow: <BoxShadow>[
              if (fromUser)
                BoxShadow(
                  color: const Color(0xFFFF4FD8).withOpacity(0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: fromUser ? Colors.white.withOpacity(0.15) : AppColors.primary.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      fromUser ? Icons.person_rounded : Icons.auto_awesome_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    fromUser ? 'You' : 'Advisor',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: fromUser ? Colors.white : _aiText(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (message.hasImage)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Image',
                        style: theme.textTheme.labelSmall?.copyWith(color: fromUser ? Colors.white : _aiText(context)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SelectableText(
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: fromUser ? Colors.white : _aiText(context),
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final bool isDark = _aiIsDark(context);
    return Container(
      width: 92,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF17171C) : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _aiBorder(context)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _Dot(),
          SizedBox(width: 5),
          _Dot(),
          SizedBox(width: 5),
          _Dot(),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot();

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = _aiIsDark(context);
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: isDark ? Colors.white70 : Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation({required this.topic});

  final AiTopic topic;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.16),
                borderRadius: BorderRadius.circular(26),
              ),
              alignment: Alignment.center,
              child: Text(topic.emoji, style: const TextStyle(fontSize: 32)),
            ),
            const SizedBox(height: 14),
            Text(
              'Start a ${topic.label.toLowerCase()} conversation',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _aiText(context),
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ask for a plan, attach a photo, or give a crop and livestock context. The assistant keeps the thread organized by topic.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _aiMuted(context),
                    height: 1.6,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.message,
    required this.tint,
    required this.icon,
  });

  final String message;
  final Color tint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final bool isDark = _aiIsDark(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121216) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _aiBorder(context)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.black87),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _aiMuted(context),
                    height: 1.45,
                  ),
            ),
          ),
        ],
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
      body: const Center(
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
    );
  }
}

class _StudioBackdrop extends StatelessWidget {
  const _StudioBackdrop({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Container(color: isDark ? const Color(0xFF0A0A0E) : const Color(0xFFF7F5EF)),
        Positioned(
          top: -80,
          right: -50,
          child: _GlowOrb(
            diameter: 260,
            colors: <Color>[
              const Color(0xFFFF4FD8).withOpacity(isDark ? 0.18 : 0.10),
              const Color(0xFF7C3AED).withOpacity(isDark ? 0.06 : 0.04),
            ],
          ),
        ),
        Positioned(
          top: 220,
          left: -80,
          child: _GlowOrb(
            diameter: 220,
            colors: <Color>[
              const Color(0xFF37D7FF).withOpacity(isDark ? 0.10 : 0.06),
              const Color(0xFF7C3AED).withOpacity(isDark ? 0.04 : 0.03),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.diameter,
    required this.colors,
  });

  final double diameter;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}

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
  return _aiIsDark(context)
      ? Colors.white.withOpacity(0.08)
      : Theme.of(context).colorScheme.outlineVariant;
}

Color _aiText(BuildContext context) {
  return _aiIsDark(context) ? Colors.white : Theme.of(context).colorScheme.onSurface;
}

Color _aiMuted(BuildContext context) {
  return _aiIsDark(context) ? Colors.white70 : Theme.of(context).colorScheme.onSurfaceVariant;
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = _aiIsDark(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1D1D24) : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _aiBorder(context)),
        ),
        child: Icon(icon, color: _aiText(context), size: 26),
      ),
    );
  }
}

class _QuickBadge extends StatelessWidget {
  const _QuickBadge({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = _aiIsDark(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A20) : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _aiBorder(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: _aiText(context)),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: _aiText(context),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final bool isDark = _aiIsDark(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF17171C) : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _aiBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: _aiMuted(context))),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _aiText(context),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
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

const List<AiStudioAction> _studioActions = <AiStudioAction>[
  AiStudioAction(
    title: 'Text writer',
    subtitle: 'Turn a farm idea into a clear update.',
    icon: Icons.edit_note_rounded,
    tint: Color(0xFFFF4FD8),
    topic: AiTopic.general,
    prompt: 'Help me write a clear farm update for farmers about what I am doing this week.',
  ),
  AiStudioAction(
    title: 'Image doctor',
    subtitle: 'Inspect a crop, leaf, or animal photo.',
    icon: Icons.camera_alt_rounded,
    tint: Color(0xFF37D7FF),
    topic: AiTopic.diseaseAndPest,
    prompt: 'Inspect this image and help me diagnose the likely problem and next action.',
  ),
  AiStudioAction(
    title: 'Crop planner',
    subtitle: 'Build planting and feeding schedules.',
    icon: Icons.spa_rounded,
    tint: Color(0xFF7C3AED),
    topic: AiTopic.cropManagement,
    prompt: 'Create a practical crop management plan with tasks I should do this week.',
  ),
  AiStudioAction(
    title: 'Animal coach',
    subtitle: 'Ask about feeding, hygiene, and health.',
    icon: Icons.pets_rounded,
    tint: Color(0xFFFFC271),
    topic: AiTopic.animalHealth,
    prompt: 'Review my livestock care routine and give me practical advice for today.',
  ),
  AiStudioAction(
    title: 'Weather plan',
    subtitle: 'Plan work around weather patterns.',
    icon: Icons.wb_cloudy_rounded,
    tint: Color(0xFF1ED6A8),
    topic: AiTopic.weatherAndClimate,
    prompt: 'Give me a weather-aware work plan for today and the next few days.',
  ),
  AiStudioAction(
    title: 'Market notes',
    subtitle: 'Pricing, sales, and profitability help.',
    icon: Icons.storefront_rounded,
    tint: Color(0xFFFFA24C),
    topic: AiTopic.marketAndFinance,
    prompt: 'Help me think through pricing, sales timing, and profitability for my farm.',
  ),
];
