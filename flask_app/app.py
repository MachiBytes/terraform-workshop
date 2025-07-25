from flask import Flask, request, jsonify
import boto3
import uuid
from datetime import datetime
import os
from decimal import Decimal
import json

# Custom JSON encoder to handle Decimal types
class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

app = Flask(__name__)
app.json_encoder = DecimalEncoder

# Initialize DynamoDB client
region = os.environ.get('AWS_REGION', 'us-west-2')  # fallback optional
table_name = os.environ.get('DYNAMODB_TABLE_NAME', 'products-072025')

dynamodb = boto3.resource('dynamodb', region_name=region)
table = dynamodb.Table(table_name)

@app.route('/products', methods=['POST'])
def create_product():
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['product_name', 'price', 'brand_name', 'quantity_available']
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'Missing required field: {field}'}), 400
        
        # Create product item
        product_id = str(uuid.uuid4())
        timestamp = datetime.now().isoformat()
        
        item = {
            'product_id': product_id,
            'product_name': data['product_name'],
            'price': Decimal(str(data['price'])),
            'brand_name': data['brand_name'],
            'quantity_available': int(data['quantity_available']),
            'created_at': timestamp
        }
        
        # Save to DynamoDB
        table.put_item(Item=item)
        
        return jsonify({
            'message': 'Product created successfully',
            'product_id': product_id
        }), 201
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/products', methods=['GET'])
def get_products():
    try:
        # Scan the table to get all products
        response = table.scan()
        products = response.get('Items', [])
        
        # Sort products by created_at timestamp
        sorted_products = sorted(products, key=lambda x: x.get('created_at', ''))
        
        return jsonify(sorted_products), 200
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=int(os.environ.get('PORT', 5000)))