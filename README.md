<div>

<img src="https://raw.githubusercontent.com/Ajallen14/WalletPulse/main/assets/images/folia_logo.png" alt="FOLIA Logo" width="80" />

# FOLIA
</div>

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
[![SQLite](https://img.shields.io/badge/sqlite-%2307405e.svg?style=for-the-badge&logo=sqlite&logoColor=white)](https://www.sqlite.org/)

---

## App Description
Managing money shouldn't feel like a spreadsheet. **FOLIA** transforms personal finance into a highly visual, intuitive experience. Built with a stunning dark-mode aesthetic, glowing glassmorphic accents, and buttery-smooth animations, the app gives users instant clarity on their spending habits and shared expenses.

Whether you are scanning a receipt from lunch, checking how close you are to your monthly grocery limit, or generating a beautiful watermarked image to remind a friend they owe you for dinner, FOLIA handles the math effortlessly. Because everything is stored securely on your local device via SQLite, your financial data remains completely private.

---

## Key Features

### Financial Command Center
* **Dynamic Pie Charts:** Get a clear visual breakdown of your spending by category (Groceries, Dining, Entertainment, etc.).
* **Smart Filtering:** Instantly toggle between expenses from Today, This Month, Last Month, or All Time.
* **Swipe-to-Delete:** Easily manage the recent receipt log with intuitive swipe gestures.

### Smart Budget Tracking
* **Custom Monthly Limits:** Set specific budgets for different spending categories.
* **Smart Progress Bars:** Visual bars track your spending against your limits, automatically changing color when a budget is exceeded.
* **Quick Editing:** A sleek 3-dot menu allows you to instantly update or delete budget constraints.

### Friends & Shared Balances 
* **Detailed Ledger System:** Track exactly who owes you money and for which specific bills.
* **Granular Settlement:** Mark entire balances as paid or check off individual receipts one by one.
* **Branded Receipt Export:** Generate and share a beautifully formatted, watermarked image of a split bill directly to WhatsApp, iMessage, or email so friends can see exactly what they are paying for.

---

## 📁 Project Structure
 
```
lib/
├── main.dart                         # App entry point
├── splash_screen.dart                # Animated splash screen
│
├── core/
│   ├── database/
│   │   └── database_helper.dart      # SQLite setup & query helpers
│   └── widgets/
│       └── processing_overlay.dart   # Shared loading overlay widget
│
└── features/
    ├── dashboard/
    │   ├── presentation/
    │   │   └── widgets/
    │   │       ├── budget_section.dart       # Budget progress bar cards
    │   │       ├── receipt_list_item.dart    # Individual expense row
    │   │       ├── home_screen.dart          # Main dashboard screen
    │   │       └── main_layout.dart          # Bottom nav & page scaffold
    │   └── providers/
    │       └── receipt_provider.dart         # Expense state (Riverpod)
    │
    ├── scanner/
    │   ├── presentation/
    │   │   ├── camera_screen.dart            # Live camera capture
    │   │   ├── manual_entry_screen.dart      # Manual expense form
    │   │   └── receipt_preview_screen.dart   # AI-parsed receipt review
    │   └── providers/
    │       └── gemini_provider.dart          # Google Generative AI integration
    │
    └── splits/
        └── presentation/
            └── widgets/
                ├── export_receipt_widget.dart  # Hidden widget → PNG export
                ├── balances_screen.dart         # Per-friend balance view
                ├── split_detail_screen.dart     # Individual bill breakdown
                └── splits_screen.dart           # Friends ledger overview
```

---

## Screenshots


---

## The Tech Stack

### Core Framework & Architecture
* **Frontend:** Flutter (Dart)
* **State Management:** Riverpod
* **Local Storage:** SQLite

### Key Packages & Libraries
* **fl_chart:** Highly customizable, animated pie charts for the dashboard.
* **intl:** Precise currency (`₹`) and date formatting.
* **share_plus & path_provider:** Capturing, saving, and exporting generated receipt images.
* **flutter_dotenv:** Secure management of configuration files.
* **flutter_launcher_icons:** Automated generation of the FOLIA app icon across iOS and Android.

---

## Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) `>=3.x` (Dart SDK `^3.10.4`)
- Android SDK / Xcode (for device/emulator builds)
- A Google Generative AI API key (for receipt scanning)

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/Ajallen14/WalletPulse.git
cd Folia
 
# 2. Install dependencies
flutter pub get
 
# 3. Set up environment variables
cp .env.example .env
# Add your GEMINI_API_KEY inside .env
 
# 4. Run on your device or emulator
flutter run
```
 
### Building for Release
 
```bash
# Android APK
flutter build apk --release
 
# iOS (requires macOS + Xcode)
flutter build ios --release
```