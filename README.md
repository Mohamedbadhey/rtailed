# Retail Management System

A complete retail management system with Node.js backend and Flutter frontend.

## 🏗️ Architecture

- **Backend**: Node.js + Express + MySQL
- **Frontend**: Flutter Web
- **Database**: MySQL
- **Authentication**: JWT

## 📋 Prerequisites

- Node.js (v14 or higher)
- MySQL (v8.0 or higher)
- Flutter SDK (v3.0 or higher)
- Git

## 🚀 Quick Start

### 1. Database Setup

First, create and populate the database:

```sql
-- Create database
CREATE DATABASE retail_management;

-- Run the schema
mysql -u root -p retail_management < backend/src/config/schema.sql

-- Populate with sample data
mysql -u root -p retail_management < backend/populate_database.sql
```

### 2. Backend Setup

```bash
cd backend

# Install dependencies
npm install

# Create .env file (copy from .env.example if available)
# Or create manually with:
# DB_HOST=localhost
# DB_USER=root
# DB_PASSWORD=your_password
# DB_NAME=retail_management
# JWT_SECRET=your-super-secret-jwt-key
# PORT=3000

# Start the server
npm start
```

**Or use the provided script:**
```bash
start_backend.bat
```

### 3. Frontend Setup

```bash
cd frontend

# Get Flutter dependencies
flutter pub get

# Start Flutter web server
flutter run -d web-server --web-port 8080
```

**Or use the provided script:**
```bash
start_frontend.bat
```

## 🔗 API Endpoints

### Authentication
- `POST /api/auth/login` - User login
- `POST /api/auth/register` - User registration
- `GET /api/auth/me` - Get current user profile

### Products
- `GET /api/products` - Get all products
- `GET /api/products/:id` - Get single product
- `POST /api/products` - Create product
- `PUT /api/products/:id` - Update product
- `DELETE /api/products/:id` - Delete product

### Customers
- `GET /api/customers` - Get all customers
- `POST /api/customers` - Create customer
- `PUT /api/customers/:id` - Update customer
- `DELETE /api/customers/:id` - Delete customer

### Sales
- `GET /api/sales` - Get all sales
- `POST /api/sales` - Create sale
- `GET /api/sales/report` - Get sales report

### Inventory
- `GET /api/inventory/transactions` - Get inventory transactions
- `POST /api/inventory/transactions` - Create inventory transaction
- `GET /api/inventory/value-report` - Get inventory value report

## 🗄️ Database Schema

The system includes the following tables:
- `users` - User accounts and authentication
- `categories` - Product categories
- `products` - Product information and inventory
- `customers` - Customer information
- `sales` - Sales transactions
- `sale_items` - Individual items in sales
- `inventory_transactions` - Inventory movement tracking

## 🔐 Authentication

The system uses JWT tokens for authentication. Include the token in the Authorization header:

```
Authorization: Bearer <your-jwt-token>
```

## 📊 Sample Data

The database comes pre-populated with:
- 3 user accounts (admin, manager, cashier)
- 5 product categories
- 15 sample products
- 10 sample customers
- 10 sample sales transactions

## 🛠️ Development

### Backend Development
```bash
cd backend
npm run dev  # Uses nodemon for auto-restart
```

### Frontend Development
```bash
cd frontend
flutter run -d web-server --web-port 8080 --hot-reload
```

## 🔧 Configuration

### Environment Variables (Backend)

Create a `.env` file in the backend directory:

```env
# Database Configuration
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=retail_management

# JWT Configuration
JWT_SECRET=your-super-secret-jwt-key-change-this-in-production

# Server Configuration
PORT=3000

# CORS Configuration
CORS_ORIGIN=https://api.kismayoict.com:8080
```

### Frontend Configuration

The frontend is configured to connect to `https://api.kismayoict.com/api` by default. You can modify this in:
- `lib/services/api_service.dart`
- `lib/utils/api.dart`
- `lib/utils/connection_test.dart`

## 🧪 Testing Connection

You can test the backend connection using the health check endpoint:

```bash
curl https://api.kismayoict.com/api/health
```

Or use the Flutter connection test utility:

```dart
import 'package:retail_management/utils/connection_test.dart';

final status = await ConnectionTest.getConnectionStatus();
print(status);
```

## 📁 Project Structure

```
rtail/
├── backend/
│   ├── src/
│   │   ├── config/
│   │   ├── middleware/
│   │   ├── routes/
│   │   └── index.js
│   ├── package.json
│   └── populate_database.sql
├── frontend/
│   ├── lib/
│   │   ├── models/
│   │   ├── providers/
│   │   ├── screens/
│   │   ├── services/
│   │   ├── utils/
│   │   └── widgets/
│   └── pubspec.yaml
├── start_backend.bat
├── start_frontend.bat
└── README.md
```

## 🚨 Troubleshooting

### Common Issues

1. **Database Connection Failed**
   - Ensure MySQL is running
   - Check database credentials in `.env`
   - Verify database exists

2. **CORS Errors**
   - Backend CORS is configured for `https://api.kismayoict.com:8080`
   - Ensure frontend is running on the correct port

3. **Authentication Errors**
   - Check JWT_SECRET in `.env`
   - Verify token is included in requests

4. **Port Already in Use**
   - Change PORT in `.env` for backend
   - Use different web-port for Flutter

## 📝 License

This project is for educational purposes.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request 