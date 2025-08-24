# Partial Credit System Guide

## Overview

The Partial Credit System allows customers to pay a portion of their total purchase amount upfront and get credit for the remaining balance. This is different from the existing full credit system where customers pay nothing upfront.

## How It Works

### 1. Partial Credit Sale Creation
When a customer wants to make a partial payment:

1. **Select Payment Method**: Choose "Partial Credit" from the payment methods
2. **Enter Partial Payment**: Specify how much the customer will pay now
3. **System Calculates**: Automatically calculates the remaining credit amount
4. **Customer Info**: Customer phone number is required for partial credit sales
5. **Sale Status**: Sale is marked as "partially_paid"

### 2. Database Structure
The system uses the existing `sales` table with new fields:

```sql
-- New payment method added
payment_method ENUM('evc', 'edahab', 'merchant', 'credit', 'partial_credit', 'cash', 'card', 'mobile_payment')

-- New sale status
status VARCHAR(32) -- 'completed', 'unpaid', 'partially_paid', 'paid'

-- Partial credit specific fields (sent in request)
partial_payment_amount DECIMAL(10,2)
remaining_credit_amount DECIMAL(10,2)
```

### 3. Cash Flow Tracking
- **Partial Payment**: Recorded as cash inflow (increases cash in hand)
- **Remaining Credit**: Not recorded in cash flow (remains as receivable)

## Frontend Implementation

### New Payment Method
- Added "Partial Credit" to payment methods dropdown
- Shows "Deyn Qayb ah" in Somali language

### Partial Credit Fields
When "Partial Credit" is selected, the following fields appear:

1. **Customer Phone**: Required field for customer identification
2. **Partial Payment Amount**: Input field for customer's upfront payment
3. **Remaining Credit Amount**: Read-only display showing credit balance
4. **New Customer Fields**: Option to create new customer if needed

### Real-time Calculation
- Partial payment amount updates automatically
- Remaining credit amount is calculated in real-time
- Validation ensures partial payment < total amount

## Backend Implementation

### New Endpoints

#### 1. Enhanced Sales Creation (`POST /api/sales`)
```javascript
// New fields for partial credit
{
  "payment_method": "partial_credit",
  "partial_payment_amount": 150.00,
  "remaining_credit_amount": 50.00,
  "customer_phone": "1234567890"
}
```

#### 2. Partial Credit Payment (`POST /api/sales/:id/partial-credit-payment`)
```javascript
{
  "amount": 25.00,
  "payment_method": "evc"
}
```

### Validation Rules
1. **Partial Payment**: Must be > 0 and < total amount
2. **Customer Phone**: Required for partial credit sales
3. **Amount Match**: Partial + remaining must equal total
4. **Customer ID**: Required for all credit sales

### Sale Status Flow
```
New Sale → partially_paid → paid (when fully paid)
```

## Usage Examples

### Example 1: Basic Partial Credit Sale
- **Total Amount**: $200.00
- **Partial Payment**: $150.00 (customer pays now)
- **Remaining Credit**: $50.00 (customer owes later)
- **Sale Status**: "partially_paid"

### Example 2: Partial Credit Payment
- **Original Credit**: $50.00
- **Customer Pays**: $25.00
- **Remaining Credit**: $25.00
- **Sale Status**: Still "partially_paid"

### Example 3: Final Payment
- **Remaining Credit**: $25.00
- **Customer Pays**: $25.00
- **Sale Status**: "paid"

## Benefits

1. **Flexible Payment**: Customers can pay what they can afford
2. **Cash Flow**: Immediate cash inflow from partial payments
3. **Customer Retention**: Builds customer loyalty through credit
4. **Risk Management**: Reduces total credit exposure
5. **Business Growth**: Enables more sales with flexible payment terms

## Integration with Existing Systems

### Sales Reports
- Partial credit sales are included in total sales
- Credit payments are tracked separately
- No double-counting of revenue

### Customer Management
- Customer credit history is maintained
- Loyalty points are awarded based on total amount
- Phone numbers are required for credit tracking

### Inventory Management
- Stock is deducted immediately upon sale
- No difference in inventory handling

## Testing

Use the provided test file `test_partial_credit.js` to verify functionality:

```bash
cd backend
npm install axios
node test_partial_credit.js
```

## Troubleshooting

### Common Issues

1. **Validation Errors**
   - Ensure partial payment < total amount
   - Customer phone is required
   - Customer ID must be provided

2. **Payment Recording**
   - Check that payment amount doesn't exceed remaining credit
   - Verify payment method is valid

3. **Status Updates**
   - Sale status updates automatically when fully paid
   - Check database for correct status values

### Debug Information
- Backend logs show detailed validation steps
- Frontend shows real-time calculation updates
- Database queries are logged for troubleshooting

## Future Enhancements

1. **Credit Limits**: Set maximum credit amounts per customer
2. **Payment Plans**: Structured payment schedules
3. **Interest Calculation**: Optional interest on credit balances
4. **Credit Reports**: Customer creditworthiness analysis
5. **Automated Reminders**: Payment due date notifications

## Security Considerations

1. **Authentication**: All endpoints require valid JWT tokens
2. **Business Isolation**: Users can only access their business data
3. **Input Validation**: All amounts and data are validated
4. **Audit Trail**: All credit transactions are logged

## Conclusion

The Partial Credit System provides a flexible payment solution that benefits both customers and businesses. It maintains the existing credit system's functionality while adding the ability to accept partial payments upfront, improving cash flow and customer satisfaction.
