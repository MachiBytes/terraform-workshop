# Flask DynamoDB Products API

A simple Flask application that provides API endpoints to create and retrieve products from a DynamoDB table.

## API Endpoints

- `POST /products` - Create a new product in the DynamoDB table
- `GET /products` - Retrieve all products from the DynamoDB table, sorted by creation time

cd flask_app
python3 -m venv venv
source venv/bin/activate

## Setup and Running

1. Install dependencies:

```sh
pip install -r requirements.txt
```

2. Make sure you have AWS credentials configured with appropriate permissions to access DynamoDB.

3. Run the application:

```sh
python app.py
```

## Example Usage

### Create a product

```bash
curl -X POST http://localhost:5000/products \
  -H "Content-Type: application/json" \
  -d '{
    "product_name": "Wireless Headphones",
    "price": 99.99,
    "brand_name": "AudioTech",
    "quantity_available": 50
  }'
```

### Get all products

```bash
curl http://localhost:5000/products
```