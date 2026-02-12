# Tap It Documentation

## 1. Project Overview
Tap It is a Flutter-based personal finance application designed to help users track their income, expenses, and debts (ledger). It features a modern UI, dark/light mode support, and seamless synchronization with a backend.

## 2. Architecture & Tech Stack

### Technology Stack
-   **Frontend Framework**: Flutter (Dart)
-   **Backend**: Appwrite (Self-hosted)
-   **State Management**: Provider
-   **Local Storage**: Hive (for offline caching/preferences)
-   **Routing**: Named routes (defined in `main.dart`)

### Key Key Libraries
-   `provider`: State management.
-   `appwrite`: Backend SDK for Auth, Database, and Realtime.
-   `hive_flutter`: fast key-value database.
-   `flutter_animate`: UI animations.
-   `intl`: specific date/number formatting.
-   `google_fonts`: Typography.

## 3. Project Structure

The project follows a feature-first and layer-based architecture:

```
lib/
├── config/           # Configuration constants (Appwrite IDs, Endpoints)
├── models/           # Data models (Transaction, Category, Item, Ledger)
├── providers/        # State management logic
├── screens/          # UI Screens (Login, Home, Ledger)
├── services/         # External services (Appwrite, Auth, Sound)
├── widgets/          # Reusable UI components
└── main.dart         # Entry point and App setup
```

## 4. Key Features

### Authentication
-   Email/Password Login and Signup.
-   Profile management (Name, Phone).
-   Persisted session management via Appwrite.

### Transaction Management
-   **Add Transaction**: Record Income or Expense.
-   **Quick Items**: predefined items for fast entry.
-   **Categories**: Categorize transactions (Food, Transport, etc.).
-   **Usage Tracking**: Frequently used categories/items sort to the top.

### Ledger System
-   Track debts and credits with other people.
-   Uses Phone Number as the unique identifier for linking users.
-   record "You gave" vs "You got" transactions.

### Personal Dashboard
-   Visual graphs of expenses.
-   Theme switching (Dark/Light).

## 5. Configuration & Setup

### Prerequisites
-   Flutter SDK installed.
-   Appwrite Server running (Self-hosted or Cloud).

### Appwrite Configuration
The app relies on a `config/appwrite_config.dart` file. Ensure the following constants match your Appwrite instance:

```dart
class AppwriteConfig {
  static const String projectId = 'YOUR_PROJECT_ID';
  static const String endpoint = 'YOUR_APPWRITE_ENDPOINT'; // e.g., http://localhost/v1
  static const String databaseId = 'YOUR_DATABASE_ID';
  // ... Collection IDs
}
```

*Note: The current configuration points to a local IP `http://192.168.29.161/v1`. Ensure your device is on the same network or update this IP.*

### Running the App
1.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```
2.  **Run**:
    ```bash
    flutter run
    ```

## 6. Services Overview

-   **AppwriteService**: Singleton class wrapping all Appwrite SDK calls. Handles Auth, Database (CRUD for Transactions, Categories, Items, Ledger), and Profile sync.
-   **StorageService** (implied): Handles local persistence using Hive.

## 7. Database Content Structure
-   **Transactions**: Stores amount, date, title, category, type (income/expense).
-   **Categories**: Stores name, icon, type, usage count.
-   **Items**: Stores predefined items for quick entry.
-   **Profiles**: Stores user metadata (Phone number) for Ledger linking.
-   **LedgerTransactions**: Stores shared transaction data between two phone numbers## 8. Detailed Feature Specifications

### 8.1. User Authentication & Profile
**Goal**: Secure user access and maintain distinctive user profiles for ledger interactions.

**Functional Requirements**:
-   **Sign Up**: Users can register using Name, Email, Password, and Phone Number.
-   **Login**: Users authenticate via Email and Password.
-   **Profile Sync**: User details (Name, Phone) are synced to a specific `profiles` collection in the database to allow discovery by other users.
-   **Session Persistence**: The app checks for an active session on startup (`AuthWrapper`) and redirects to Home or Login accordingly.

**Data Flow**:
1.  User submits credentials -> `AuthService` calls Appwrite `create` & `createEmailPasswordSession`.
2.  On success, `createProfile` adds a document to `profiles` collection with `userId`, `name`, `email`, and `phone`.

### 8.2. Personal Finance Dashboard (Home)
**Goal**: Provide an immediate snapshot of the user's financial health.

**UI/UX Details**:
-   **Balance Card**: Displays Total Balance, Total Income, and Total Expenses.
-   **Graphing**:
    -   Switchable view between **Weekly** and **Monthly** expenses.
    -   Uses `fl_chart` (implied by file structure) or custom painting for visual representation.
-   **Quick Actions**: Prominent buttons to "Add Transaction" or viewing history.
-   **Recent Transactions**: List of latest transactions sorted by date.

### 8.3. Transaction Management
**Goal**: Effortless recording of financial activities.

**Functional Requirements**:
-   **Add Transaction**:
    -   **Inputs**: Amount, Title/Description, Date, Type (Income/Expense).
    -   **Categorization**: User selects a Category (e.g., Food, Salary).
    -   **Quick Items**: Users can select from frequently used items (e.g., "Coffee", "Bus Ticket") to auto-fill details.
-   **Edit/Delete**: Long-press or tap on a transaction to edit details or delete it.
-   **Optimistic UI**: Transactions appear instantly in the list before the server confirmation to ensure responsiveness.
-   **Audio Feedback**: Distinct sounds for Income vs. Expense recording (`SoundService`).

**Logic**:
-   Transactions are stored locally in Hive boxes (`transactions` box) for offline access.
-   Optimistically added to local list, then synced to Appwrite.
-   If backend sync fails, the item remains locally but might not persist across re-installs (logic to be enhanced for true offline-first).

### 8.4. Ledger System (Debts & Credits)
**Goal**: Manage shared expenses and debts with friends/contacts.

**Functional Requirements**:
-   **Link Users**: Uses **Phone Number** as the unique key to link two users.
-   **Transaction Types**:
    -   **"You Gave"**: User lent money.
    -   **"You Got"**: User borrowed money.
-   **Dashboard**: Shows net balance with each person.
-   **Settle Up**: Functionality to clear debts (implied).

**Logic**:
-   Queries `ledger_transactions` collection.
-   Fetches both "Sent" (where I am sender) and "Received" (where I am receiver) documents.
-   Merges results to show a complete history with a specific contact.

### 8.5. Configuration & Settings
**Goal**: User customization.

**Features**:
-   **Theme Toggle**: Switch between Light and Dark mode.
-   **Currency**: Select preferred currency symbol.
-   **Security**: Biometric authentication toggle (if available).
-   **Account**: View profile details, Logout.

## 9. Future Roadmap / Pending Requirements
-   **Offline Sync Queue**: Robust queue system to retry failed uploads when internet restores.
-   **Export Data**: PDF/Excel export of transaction history.
-   **Budgeting Goals**: Set monthly limits per category.

