# ☀️ Dual-Axis Solar Tracker App (FYP)

> **🏆 Most Innovative Award Winner**
> **Event:** THE PROJEXHIBITION 2025
> **Project Type:** Final Year Project (FYP)

## 📖 Overview
This project is an intelligent **IoT-based Solar Tracking System** designed to maximize energy generation by automatically aligning solar panels with the sun's position. It features a dual-axis mechanism controlled via a mobile application, allowing for real-time monitoring and manual override capabilities.

The system significantly increases energy efficiency compared to static panels and was recognized with the **Most Innovative Award** at PROJEXHIBITION 2025 for its novel integration of mobile control and renewable energy technology.

## ✨ Key Features
* **Dual-Axis Tracking:** Automatically adjusts the panel's azimuth and elevation to follow the sun.
* **Mobile Dashboard:** Real-time monitoring of voltage (V), current (A), and power output (W) via the app.
* **Remote Control:** Manual override mode allows users to position the panels via the mobile interface.
* **Efficiency Analytics:** Visual data comparing tracking efficiency vs. static placement.
* **Cloud Integration:** Live data syncing using Firebase.

## 🛠️ Tech Stack
* **Mobile App:** Flutter (Dart)
* **Hardware / IoT:** ESP32 / Arduino, LDR Sensors, Servo Motors
* **Backend & Database:** Firebase Realtime Database
* **Connectivity:** Wi-Fi / Bluetooth

## 📸 Project Screenshots
| Dashboard | Manual Control | Stats View |
|:---:|:---:|:---:|
| *(Upload screenshot here)* | *(Upload screenshot here)* | *(Upload screenshot here)* |

## 🚀 Installation
1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/jhloi225/Dual-Axis-Solar-Tracker-APP-FYP.git](https://github.com/jhloi225/Dual-Axis-Solar-Tracker-APP-FYP.git)
    ```
2.  **Install Dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Firebase Setup:**
    * This project uses Firebase. You must provide your own `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) in the respective app directories.
4.  **Run the App:**
    ```bash
    flutter run
    ```

## ⚠️ Hardware Requirements
* Solar Panel mechanism with 2 Servo Motors (Horizontal & Vertical).
* 4 LDR Sensors for light detection.
* Microcontroller (ESP32 recommended) with Wi-Fi capability.
<img width="1630" height="1110" alt="image_2025-12-21_15-19-35" src="https://github.com/user-attachments/assets/7da0f743-a3f2-4cf9-a8fb-ec2edf9f9245" />

---
*Developed by jhloi225*
