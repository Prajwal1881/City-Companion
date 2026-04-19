import requests, datetime
res = requests.post('http://localhost:8000/v1/auth/send-otp', json={'phone': '+911234567890'})
otp = res.json().get('dev_otp')
res = requests.post('http://localhost:8000/v1/auth/verify-otp', json={'phone': '+911234567890', 'otp': otp})
token = res.json().get('access_token')
plan_data = {
    'category': 'food', 'title': 'Test Plan', 'description': 'Testing members array', 
    'plan_date': (datetime.datetime.now(datetime.UTC) + datetime.timedelta(days=1)).isoformat()
}
res = requests.post('http://localhost:8000/v1/plans/', headers={'Authorization': f'Bearer {token}'}, json=plan_data)
print('Created plan members:', res.json().get('members'))
