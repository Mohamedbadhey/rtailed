# Retail Management System Frontend

A Flutter-based frontend for the retail management system, providing a modern and intuitive user interface for managing inventory, sales, customers, and reports.

## Features

- **User Authentication**
  - Login and registration
  - Role-based access control
  - Profile management

- **Dashboard**
  - Key metrics and statistics
  - Recent activities
  - Sales trends

- **Point of Sale**
  - Quick product search
  - Category-based browsing
  - Shopping cart management
  - Customer selection
  - Payment processing

- **Inventory Management**
  - Product catalog
  - Stock tracking
  - Low stock alerts
  - Inventory transactions
  - Category management

- **Customer Management**
  - Customer database
  - Loyalty program
  - Purchase history
  - Contact information

- **Reports & Analytics**
  - Sales reports
  - Inventory reports
  - Customer reports
  - Export functionality

- **Settings**
  - User preferences
  - System configuration
  - Data backup and restore

## Prerequisites

- Flutter SDK (2.19.0 or higher)
- Dart SDK (2.19.0 or higher)
- Android Studio / VS Code with Flutter extensions
- Git

## Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd retail-management/frontend
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Create a `.env` file in the root directory and add your configuration:
   ```
   API_URL=http://localhost:3000/api
   ```

4. Run the code generation:
   ```bash
   flutter pub run build_runner build
   ```

## Running the Application

1. Start the backend server (see backend README for instructions)

2. Run the Flutter application:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── main.dart
├── models/
│   ├── customer.dart
│   ├── inventory_transaction.dart
│   ├── product.dart
│   ├── sale.dart
│   └── user.dart
├── providers/
│   ├── auth_provider.dart
│   └── cart_provider.dart
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   └── home/
│       ├── dashboard_screen.dart
│       ├── inventory_screen.dart
│       ├── pos_screen.dart
│       ├── reports_screen.dart
│       └── settings_screen.dart
├── services/
│   └── api_service.dart
├── utils/
│   ├── api.dart
│   └── theme.dart
└── widgets/
    └── custom_text_field.dart
```

## State Management

The application uses the Provider package for state management. Key providers include:

- `AuthProvider`: Manages user authentication state
- `CartProvider`: Manages shopping cart state

## API Integration

The application communicates with the backend through the `ApiService` class, which handles all API calls using the Dio package. The service includes methods for:

- Authentication
- Product management
- Customer management
- Sales processing
- Inventory management
- Reporting

## Theme

The application uses a custom theme defined in `utils/theme.dart`, supporting both light and dark modes. The theme includes:

- Color schemes
- Typography
- Component styles
- Input decorations

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details. 