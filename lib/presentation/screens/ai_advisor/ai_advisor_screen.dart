import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/ai_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/ai_topic.dart';
import '../../../domain/models/chat_message.dart';
import '../../../providers/ai_chat_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/soft_screen_scaffold.dart';

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
  int _lastMessageCount = 0;

  @override
  void dispose() {
    _messageController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ai = ref.watch(aiChatProvider);
    final ThemeData theme = Theme.of(context);

    if (ai.isInitialized && ai.activeMessages.length != _lastMessageCount) {
      _lastMessageCount = ai.activeMessages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Advisor'),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: (String value) async {
              if (value == 'clear-topic') {
                await ai.clearTopic(ai.activeTopic);
                return;
              }
              await ai.clearAll();
            },
            itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'clear-topic',
                child: Text('Clear this topic'),
              ),
              PopupMenuItem<String>(
                value: 'clear-all',
                child: Text('Clear all chats'),
              ),
            ],
          ),
        ],
      ),
      body: !ai.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : SoftScreenScaffold(
              heroTitle: 'Ask the field assistant',
              heroSubtitle: 'Crop guidance, livestock support, weather planning, market answers, and image diagnosis now work as one live AI workspace.',
              heroIcon: Icons.auto_awesome_rounded,
              heroVariant: FarmArtworkVariant.dashboard,
              heroBadge: ai.hasApiKey ? 'Gemini powered' : 'Gemini key required',
              trailing: _buildLanguageMenu(context, ai.language),
              sections: <Widget>[
                _buildStatusRow(ai),
                const SizedBox(height: 18),
                const SoftSectionTitle(title: 'Advisory topics'),
                _TopicGrid(
                  activeTopic: ai.activeTopic,
                  onTopicSelected: (AiTopic topic) {
                    ai.setTopic(topic);
                  },
                ),
                const SizedBox(height: 18),
                const SoftSectionTitle(title: 'Quick actions'),
                _QuickActionRow(
                  onDiagnoseTap: () => _pickImage(ImageSource.camera),
                  onWeatherTap: () async {
                    await ai.setTopic(AiTopic.weatherAndClimate);
                    await ai.sendSuggestion('Give me a simple weather-based field work plan for today.');
                  },
                ),
                const SizedBox(height: 18),
                const SoftSectionTitle(title: 'Suggested prompts'),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: ai.suggestedQuestions
                      .map(
                        (String question) => _PromptChip(
                          text: question,
                          onTap: ai.isActiveLoading ? null : () => ai.sendSuggestion(question),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                SoftSectionTitle(
                  title: 'Live conversation',
                  action: Text(
                    '${ai.activeMessageCount} messages',
                    style: theme.textTheme.labelLarge?.copyWith(color: AppColors.primaryMid),
                  ),
                ),
                _ChatPanel(
                  controller: _chatScrollController,
                  messages: ai.activeMessages,
                  topic: ai.activeTopic,
                ),
                const SizedBox(height: 18),
                const SoftSectionTitle(title: 'Ask AI'),
                _ComposerCard(
                  controller: _messageController,
                  isLoading: ai.isActiveLoading,
                  selectedImageBytes: _selectedImageBytes,
                  selectedImageLabel: _selectedImageLabel,
                  onSend: () => _sendMessage(ai),
                  onTakePhoto: () => _pickImage(ImageSource.camera),
                  onUploadImage: () => _pickImage(ImageSource.gallery),
                  onRemoveImage: _clearSelectedImage,
                ),
                if (!ai.hasApiKey) ...<Widget>[
                  const SizedBox(height: 12),
                  _InfoNotice(
                    message: 'AI requests are disabled until a Gemini API key is configured.',
                    tint: const Color(0xFFFFEBD3),
                    icon: Icons.key_off_rounded,
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildLanguageMenu(BuildContext context, String currentLanguage) {
    final ai = ref.read(aiChatProvider);
    final ThemeData theme = Theme.of(context);

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.translate_rounded),
        onSelected: (String language) {
          ai.setLanguage(language);
        },
        itemBuilder: (BuildContext context) {
          return ai.supportedLanguages
              .map(
                (String language) => PopupMenuItem<String>(
                  value: language,
                  child: Row(
                    children: <Widget>[
                      Expanded(child: Text(language)),
                      if (language == currentLanguage)
                        const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.primaryMid),
                    ],
                  ),
                ),
              )
              .toList();
        },
      ),
    );
  }

  Widget _buildStatusRow(AiProvider ai) {
    return Row(
      children: <Widget>[
        Expanded(
          child: SoftInfoChip(
            label: 'Topic',
            value: ai.activeTopic.label,
            color: const Color(0xFFE8F4D8),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SoftInfoChip(
            label: 'Language',
            value: ai.language,
            color: const Color(0xFFDDEEFF),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SoftInfoChip(
            label: 'Model',
            value: ai.modelName,
            color: const Color(0xFFFFEBD3),
          ),
        ),
      ],
    );
  }

  Future<void> _sendMessage(AiProvider ai) async {
    final String text = _messageController.text.trim();
    if (text.isEmpty && _selectedImageBytes == null) {
      return;
    }

    final String message = text.isEmpty
        ? 'Please diagnose this image and explain the likely issue, the signs to confirm, and the practical next step.'
        : text;

    _messageController.clear();
    final Uint8List? imageBytes = _selectedImageBytes;
    _clearSelectedImage();
    await ai.sendMessage(message, imageBytes: imageBytes);
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? file = await _imagePicker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1400,
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
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }
}

class _TopicGrid extends StatelessWidget {
  const _TopicGrid({
    required this.activeTopic,
    required this.onTopicSelected,
  });

  final AiTopic activeTopic;
  final ValueChanged<AiTopic> onTopicSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: AiTopic.values.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemBuilder: (BuildContext context, int index) {
        final AiTopic topic = AiTopic.values[index];
        final bool isActive = topic == activeTopic;

        return AppCard(
          color: isActive
              ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          onTap: () => onTopicSelected(topic),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(_topicIcon(topic), size: 28, color: AppColors.primary),
                const SizedBox(height: 14),
                Text(
                  topic.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    topic.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
                  ),
                ),
                if (isActive)
                  const Align(
                    alignment: Alignment.bottomRight,
                    child: Icon(Icons.check_circle_rounded, color: AppColors.primaryMid),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({
    required this.onDiagnoseTap,
    required this.onWeatherTap,
  });

  final VoidCallback onDiagnoseTap;
  final VoidCallback onWeatherTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _ActionTile(
            title: AppStrings.snapAndDiagnose,
            subtitle: 'Take a fresh photo and ask the AI to inspect it.',
            icon: Icons.camera_alt_rounded,
            color: const Color(0xFFDFF1FF),
            onTap: onDiagnoseTap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionTile(
            title: AppStrings.weatherForecast,
            subtitle: 'Jump straight into weather planning for field work.',
            icon: Icons.wb_cloudy_rounded,
            color: const Color(0xFFE8F4D8),
            onTap: onWeatherTap,
          ),
        ),
      ],
    );
  }
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.controller,
    required this.messages,
    required this.topic,
  });

  final ScrollController controller;
  final List<ChatMessage> messages;
  final AiTopic topic;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SizedBox(
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
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      ),
                    );
                  }

                  return _ChatBubble(message: message);
                },
              ),
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
    required this.onRemoveImage,
  });

  final TextEditingController controller;
  final bool isLoading;
  final Uint8List? selectedImageBytes;
  final String? selectedImageLabel;
  final VoidCallback onSend;
  final VoidCallback onTakePhoto;
  final VoidCallback onUploadImage;
  final VoidCallback onRemoveImage;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            if (selectedImageBytes != null) ...<Widget>[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Row(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(
                        selectedImageBytes!,
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            selectedImageLabel ?? 'Attached image',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'This image will be sent with your next AI question.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onRemoveImage,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: AppTextField(
                    controller: controller,
                    hint: AppStrings.typeYourQuestion,
                    textInputAction: TextInputAction.send,
                    maxLines: 4,
                    minLines: 1,
                    onSubmitted: (_) {
                      if (!isLoading) {
                        onSend();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 56,
                  child: AppButton.primary(
                    onPressed: isLoading ? null : onSend,
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppButton.secondary(
                    onPressed: isLoading ? null : onTakePhoto,
                    child: const Text(AppStrings.takePhoto),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton.secondary(
                    onPressed: isLoading ? null : onUploadImage,
                    child: const Text(AppStrings.uploadImage),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({
    required this.text,
    required this.onTap,
  });

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      backgroundColor: Theme.of(context).colorScheme.surface,
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      label: Text(text),
      onPressed: onTap,
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
  });

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final bool fromUser = message.isFromUser;
    final ThemeData theme = Theme.of(context);
    final Color bubbleColor = fromUser
        ? AppColors.primary
        : message.isError
            ? theme.colorScheme.error.withOpacity(0.14)
            : theme.colorScheme.surface;
    final Color textColor = fromUser
        ? Colors.white
        : message.isError
            ? theme.colorScheme.error
            : theme.colorScheme.onSurface;

    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(22),
            border: fromUser ? null : Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                fromUser ? 'You' : 'Advisor',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: textColor,
                    ),
              ),
              const SizedBox(height: 6),
              if (message.hasImage)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Image attached',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: textColor),
                  ),
                ),
              Text(
                message.text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: textColor,
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

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation({
    required this.topic,
  });

  final AiTopic topic;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(_topicIcon(topic), size: 42, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              'Start a ${topic.label.toLowerCase()} conversation',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.primary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Send a question or attach a photo and the assistant will keep the conversation for this topic.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

IconData _topicIcon(AiTopic topic) {
  switch (topic) {
    case AiTopic.cropManagement:
      return Icons.spa_rounded;
    case AiTopic.animalHealth:
      return Icons.pets_rounded;
    case AiTopic.diseaseAndPest:
      return Icons.bug_report_rounded;
    case AiTopic.soilAndWater:
      return Icons.water_drop_rounded;
    case AiTopic.marketAndFinance:
      return Icons.storefront_rounded;
    case AiTopic.weatherAndClimate:
      return Icons.cloud_queue_rounded;
    case AiTopic.general:
      return Icons.agriculture_rounded;
  }
}

class _InfoNotice extends StatelessWidget {
  const _InfoNotice({
    required this.message,
    required this.tint,
    required this.icon,
  });

  final String message;
  final Color tint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
