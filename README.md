# Liveness App

A Flutter application for liveness detection and user registration. This app uses the device's
camera to perform liveness detection and then registers the user.

## Features

- Liveness detection using the camera.
- User registration.
- Stores user data locally using Hive.

## Dependencies

The project relies on the following packages:

- `flutter`
- `cupertino_icons`
- `camera`
- `permission_handler`
- `google_mlkit_face_detection`
- `tflite_flutter`
- `image`
- `hive`
- `hive_flutter`
- `path_provider`

## Getting Started

Follow these instructions to get a copy of the project up and running on your local machine for
development and testing purposes.

### Prerequisites

You need to have Flutter installed on your machine. If you don't have it installed, please follow
the instructions on the [Flutter website](https://flutter.dev/docs/get-started/install).

### Installation

**Clone the repository:**

   ```bash
   git clone https://github.com/saifsiddiquee/liveness_app.git
   ```

**Navigate to the project directory:**

   ```bash
   cd liveness_app
   ```

**Install the dependencies:**

   ```bash
   flutter pub get
   ```

**Config the tflite**

    Create a folder named assets in the root of your Flutter project (at the same level as lib and pubspec.yaml).
    Download the MobileFaceNet model file. A common one is named mobile_face_net.tflite. You can find it in many face recognition example repositories.
    Place this .tflite file inside your new assets folder.

### Running the App

1. **Run the app on your device or emulator:**

   ```bash
   flutter run
   ```

This command will launch the app on your connected device or emulator.
