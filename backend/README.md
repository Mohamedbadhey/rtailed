# Retail Management System Backend

A Node.js backend for a retail management system with features for inventory management, point of sale, customer management, and reporting.

## Features

- User authentication and role-based access control
- Product management with image upload
- Inventory tracking and low stock alerts
- Point of sale system with multiple payment methods
- Customer management with loyalty program
- Sales reporting and analytics
- RESTful API design

## Prerequisites

- Node.js (v14 or higher)
- MySQL (v8.0 or higher)
- npm or yarn

## Installation

1. Clone the repository
2. Navigate to the backend directory:
   ```bash
   cd backend
   ```
3. Install dependencies:
   ```bash
   npm install
   ```
4. Create a `.env` file based on `.env.example`:
   ```bash
   cp .env.example .env
   ```
5. Update the `.env` file with your configuration
6. Create the database and tables:
   ```bash
   mysql -u root -p < src/config/schema.sql
   ```

## Running the Application

Development mode:
```bash
npm run dev
```

Production mode:
```bash
npm start
```

## API Documentation

### Authentication

- POST `/api/auth/register` - Register new user
- POST `/api/auth/login` - Login user
- GET `/api/auth/me` - Get current user

### Products

- GET `/api/products` - Get all products
- GET `/api/products/:id` - Get single product
- POST `/api/products` - Create new product
- PUT `/api/products/:id` - Update product
- DELETE `/api/products/:id` - Delete product
- GET `/api/products/inventory/low-stock` - Get low stock products

### Sales

- POST `/api/sales` - Create new sale
- GET `/api/sales/report` - Get sales report
- GET `/api/sales/top-products` - Get top selling products
- GET `/api/sales/:id` - Get sale details

### Customers

- GET `/api/customers` - Get all customers
- GET `/api/customers/:id` - Get single customer
- POST `/api/customers` - Create new customer
- PUT `/api/customers/:id` - Update customer
- DELETE `/api/customers/:id` - Delete customer
- GET `/api/customers/:id/loyalty` - Get customer loyalty points
- PUT `/api/customers/:id/loyalty` - Update customer loyalty points
- GET `/api/customers/search/:query` - Search customers

### Inventory

- GET `/api/inventory` - Get inventory status
- GET `/api/inventory/low-stock` - Get low stock items
- PUT `/api/inventory/:id/stock` - Update stock quantity
- GET `/api/inventory/transactions` - Get inventory transactions
- GET `/api/inventory/value-report` - Get inventory value report

## Error Handling

The API uses standard HTTP status codes and returns error messages in the following format:

```json
{
  "message": "Error message here"
}
```

## Security

- JWT authentication
- Role-based access control
- Password hashing
- Input validation
- SQL injection prevention
- XSS protection

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request 