import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/state/app_providers.dart';
import '../../models/post_item.dart';
import '../../models/section_item.dart';
import '../../models/uploaded_image_item.dart';
import '../../repositories/post_repository.dart';
import '../../core/l10n/ui_text.dart';

class CreatePostState {
  const CreatePostState({
    this.sections = const <SectionItem>[],
    this.clubs = const <ClubItem>[],
    this.loadingSections = true,
    this.userLevel = 2,
    this.userLevelLabel = '二级用户',
    this.isLevelOneUser = false,
    this.submitting = false,
    this.progressText,
    this.error,
  });

  /// Sections one may post to (postableSections).
  final List<SectionItem> sections;
  final List<ClubItem> clubs;
  final bool loadingSections;
  final int userLevel;
  final String userLevelLabel;
  final bool isLevelOneUser;
  final bool submitting;
  final String? progressText;
  final String? error;

  CreatePostState copyWith({
    List<SectionItem>? sections,
    List<ClubItem>? clubs,
    bool? loadingSections,
    int? userLevel,
    String? userLevelLabel,
    bool? isLevelOneUser,
    bool? submitting,
    String? progressText,
    String? error,
    bool clearError = false,
    bool clearProgress = false,
  }) {
    return CreatePostState(
      sections: sections ?? this.sections,
      clubs: clubs ?? this.clubs,
      loadingSections: loadingSections ?? this.loadingSections,
      userLevel: userLevel ?? this.userLevel,
      userLevelLabel: userLevelLabel ?? this.userLevelLabel,
      isLevelOneUser: isLevelOneUser ?? this.isLevelOneUser,
      submitting: submitting ?? this.submitting,
      progressText: clearProgress ? null : (progressText ?? this.progressText),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class UploadPayload {
  UploadPayload({
    required this.fileName,
    required this.contentType,
    required this.dataBase64,
    required this.sizeBytes,
  });

  final String fileName;
  final String contentType;
  final String dataBase64;
  final int sizeBytes;
}

class CreatePostController extends StateNotifier<CreatePostState> {
  CreatePostController(this._ref) : super(const CreatePostState());

  final Ref _ref;

  Future<void> loadSections() async {
    state = state.copyWith(loadingSections: true, clearError: true);
    try {
      final PostRepository repository = _ref.read(postRepositoryProvider);
      final (List<SectionItem> sections, List<ClubItem> clubs) = await (
        repository.fetchSections(),
        repository.fetchClubs(),
      ).wait;
      final profile = await _ref.read(userRepositoryProvider).fetchProfile();
      state = state.copyWith(
        sections: postableSections(sections, clubs),
        clubs: clubs,
        loadingSections: false,
        userLevel: profile.userLevel,
        userLevelLabel: profile.userLevelLabel,
        isLevelOneUser: profile.isLevelOneUser,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        loadingSections: false,
        error: uiTextGlobal(
          zh: '加载分区失败：$error',
          en: 'Could not load sections: $error',
        ),
      );
    }
  }

  Future<PostItem?> submit({
    required String title,
    required String content,
    required bool useMarkdown,
    required SectionItem section,
    required List<String> tags,
    required bool privateOnly,
    required PostStatus status,
    required bool useAnonymousAlias,
    String? anonymousAlias,
    int? pinDurationMinutes,
    required List<UploadPayload> uploadPayloads,
    List<String> preUploadedImageIds = const <String>[],
  }) async {
    state = state.copyWith(
      submitting: true,
      progressText: uploadPayloads.isEmpty
          ? uiTextGlobal(zh: '发布帖子中...', en: 'Publishing...')
          : uiTextGlobal(zh: '上传图片中...', en: 'Uploading images...'),
      clearError: true,
    );

    try {
      final List<String> uploadedIds = List<String>.from(preUploadedImageIds);
      final List<String> uploadedUrls = <String>[];
      for (int i = 0; i < uploadPayloads.length; i += 1) {
        state = state.copyWith(
          progressText: uiTextGlobal(
            zh: '上传图片 ${i + 1}/${uploadPayloads.length}...',
            en: 'Uploading image ${i + 1}/${uploadPayloads.length}...',
          ),
        );
        final UploadPayload payload = uploadPayloads[i];
        final UploadedImageItem uploaded = await _ref
            .read(postRepositoryProvider)
            .uploadImage(
              fileName: payload.fileName,
              contentType: payload.contentType,
              dataBase64: payload.dataBase64,
            );
        uploadedIds.add(uploaded.id);
        uploadedUrls.add(uploaded.url);
      }

      state = state.copyWith(
        progressText: uiTextGlobal(zh: '提交帖子中...', en: 'Submitting post...'),
      );
      final PostItem created = await _ref
          .read(postRepositoryProvider)
          .createPost(
            CreatePostInput(
              title: title,
              content: content,
              contentFormat: useMarkdown ? 'markdown' : 'plain',
              markdownSource: useMarkdown ? content : null,
              section: section,
              publisherClub: publisherClubFor(section, state.clubs),
              tags: tags,
              allowComment: true,
              allowDm: !useAnonymousAlias,
              privateOnly: privateOnly,
              status: status,
              hasImage: uploadedIds.isNotEmpty,
              pinDurationMinutes: pinDurationMinutes,
              imageUploadIds: uploadedIds,
              useAnonymousAlias: useAnonymousAlias,
              anonymousAlias: anonymousAlias,
            ),
          );

      state = state.copyWith(
        submitting: false,
        clearProgress: true,
        clearError: true,
      );

      if (uploadedUrls.isNotEmpty) {
        return created.copyWith(
          imageUrls: uploadedUrls,
          uploadedImageIds: uploadedIds,
        );
      }
      return created;
    } on ApiException catch (error) {
      state = state.copyWith(
        submitting: false,
        clearProgress: true,
        error: uiTextGlobal(
          zh: '发布失败：${error.message}',
          en: 'Publish failed: ${error.message}',
        ),
      );
      return null;
    } catch (error) {
      state = state.copyWith(
        submitting: false,
        clearProgress: true,
        error: uiTextGlobal(zh: '发布失败：$error', en: 'Publish failed: $error'),
      );
      return null;
    }
  }
}

final createPostControllerProvider =
    StateNotifierProvider.autoDispose<CreatePostController, CreatePostState>(
      (Ref ref) => CreatePostController(ref),
    );
