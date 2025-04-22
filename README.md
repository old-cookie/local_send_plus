# local_send_plus

A Flutter application enabling secure, local network file and text sharing between devices. Features include automatic device discovery, media editing capabilities, and an integrated AI chat assistant powered by a local Gemma model.

## ✨ Features

* **Local Network Discovery:** Automatically discover other devices running `local_send_plus` on the same network using `network_info_plus` and custom discovery logic (`lib/features/discovery/`).
* **Secure File & Text Transfer:** Share files (`file_picker`) and text messages (`clipboard`) directly between devices using a local HTTP server (`shelf`, `shelf_router`, `shelf_multipart`).
* **Image Editing:** Basic image editing functionalities provided by `image_editor_plus`.
* **Video Editing:** Basic video editing functionalities using `video_editor` and `ffmpeg_kit_flutter_new`.
* **AI Chat Assistant:** Chat with an onboard AI assistant using the Gemma model (`flutter_gemma`, `flutter_markdown`). The model runs locally (`assets/models/gemma3-1b-it-int4.task`).
* **Cross-Platform:** Built with Flutter, targeting Android, iOS, Web, Windows, macOS, and Linux.
* **Security:** Utilizes local authentication features (`local_auth`).

## 📸 Screenshots / Demo


## 🚀 Getting Started

### Prerequisites

* Flutter SDK installed (check `pubspec.yaml` for version constraints, currently `>=3.7.2 <4.0.0`)
* Platform-specific build tools (Android Studio/Xcode/Visual Studio/etc. depending on your target platform)

### Installation & Setup

1. **Clone the repository:**

    ```bash
    # Replace <repository-url> with the actual URL
    git clone <repository-url>
    cd local_send_plus
    ```

2.  **Install dependencies:**

    ```bash
    flutter pub get
    ```

3.  **Download AI Model:**

    * The AI chat feature requires the `gemma3-1b-it-int4.task` model file.
    * *(Placeholder: Add instructions on where users can download this specific model file.)*
    * Place the downloaded model file in the `assets/models/` directory within the project.

### Running the App

1. Connect a device or start an emulator/simulator.
2. Run the app from your IDE or using the command line:

    ```bash
    flutter run
    ```

*(Note: Ensure necessary permissions (network, storage, camera, etc.) are granted, potentially handled by `permission_handler`.)*

## 💻 Usage

*(Placeholder: Briefly describe the user flow)*

1. Launch the app on two or more devices connected to the same local network.
2. Devices should automatically appear in the discovery list.
3. Select a device to initiate a connection or send data.
4. Use the interface to send files, text messages, or start an AI chat session.
5. Access image/video editing features through the relevant options (e.g., after selecting media).

## 🛠️ Technology Stack

* **Framework:** Flutter (`sdk: '>=3.7.2 <4.0.0'`)
* **State Management:** Riverpod (`flutter_riverpod: ^2.5.1`)
* **Local Server/Networking:** Shelf (`^1.4.1`), Shelf Router (`^1.1.4`), Shelf Multipart (`^2.0.1`), http (`^1.2.2`), network_info_plus (`^6.1.3`)
* **AI:** flutter_gemma (`^0.8.4`), flutter_markdown (`^0.7.1`)
* **Media Handling:** image_editor_plus (`^1.0.6`), video_editor (`^3.0.0`), ffmpeg_kit_flutter_new (`^1.1.0`), file_picker (`^8.0.1`), path_provider (`^2.1.3`), image_picker (`^1.0.7`)
* **Permissions & Device Info:** permission_handler (`^11.4.0`), device_info_plus (`^11.3.3`)
* **Security:** local_auth (`^2.3.0`)
* **Utilities:** cupertino_icons (`^1.0.8`), mime (`^2.0.0`), uuid (`^4.4.2`), basic_utils (`^5.8.2`), path (`^1.9.1`), clipboard (`^0.1.3`), shared_preferences (`^2.2.4`)
