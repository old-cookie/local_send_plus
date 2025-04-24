import 'package:flutter_gemma/core/model.dart';
import 'package:flutter_gemma/pigeon.g.dart';

/// Represents the available AI models.
enum Model {
  /// Gemma3 1B IT model running locally on the GPU using a local asset.
  gemma3GpuLocalAsset(
    /// The path to the local model asset.
    url: 'assets/models/gemma3-1b-it-int4.task', // Corrected path to match pubspec
    /// The filename of the model.
    filename: 'gemma3-1b-it-int4.task',
    /// The display name for the model in the UI.
    displayName: 'Gemma3 1B IT (CPU / Local)',
    /// The URL to the model's license information.
    licenseUrl: '',
    /// Indicates if authentication is required to use the model.
    needsAuth: false,
    /// Indicates if the model is stored locally.
    localModel: true,
    /// The preferred backend for running the model (GPU).
    preferredBackend: PreferredBackend.gpu,
    /// The type of the model (Gemma IT).
    modelType: ModelType.gemmaIt,
    /// The temperature setting for model generation (controls randomness).
    temperature: 0.1,
    /// The top-K sampling parameter.
    topK: 64,
    /// The top-P (nucleus) sampling parameter.
    topP: 0.95,
  ),

  /// Gemma3 1B IT model running remotely on the GPU.
  gemma3Gpu(
    /// The URL to download the remote model.
    url: 'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task',
    /// The filename of the model.
    filename: 'gemma3-1b-it-int4.task',
    /// The display name for the model in the UI.
    displayName: 'Gemma3 1B IT (GPU / Remote)',
    /// The URL to the model's license information on Hugging Face.
    licenseUrl: 'https://huggingface.co/litert-community/Gemma3-1B-IT',
    /// Indicates if authentication is required to use the model (likely for downloading).
    needsAuth: true,
    /// The preferred backend for running the model (GPU).
    preferredBackend: PreferredBackend.gpu,
    /// The type of the model (Gemma IT).
    modelType: ModelType.gemmaIt,
    /// The temperature setting for model generation (controls randomness).
    temperature: 0.1,
    /// The top-K sampling parameter.
    topK: 64,
    /// The top-P (nucleus) sampling parameter.
    topP: 0.95,
  );

  /// The URL or path to the model file.
  final String url;
  /// The filename of the model.
  final String filename;
  /// The user-friendly display name for the model.
  final String displayName;
  /// The URL pointing to the license of the model.
  final String licenseUrl;
  /// Whether the model requires authentication (e.g., for downloading).
  final bool needsAuth;
  /// Whether the model is stored locally or needs to be downloaded.
  final bool localModel;
  /// The preferred backend (CPU or GPU) for running the model inference.
  final PreferredBackend preferredBackend;
  /// The specific type or variant of the model.
  final ModelType modelType;
  /// Controls the randomness of the output. Lower values make the output more deterministic.
  final double temperature;
  /// Limits the sampling pool to the top K most likely tokens.
  final int topK;
  /// Limits the sampling pool to the smallest set of tokens whose cumulative probability exceeds P.
  final double topP;

  /// Creates a new Model enum instance.
  const Model({
    required this.url,
    required this.filename,
    required this.displayName,
    required this.licenseUrl,
    required this.needsAuth,
    this.localModel = false,
    required this.preferredBackend,
    required this.modelType,
    required this.temperature,
    required this.topK,
    required this.topP,
  });
}
