import os
from concurrent.futures import ThreadPoolExecutor

import pytest

if not os.getenv('TEST_DATABASE_URL'):
    pytest.skip('TEST_DATABASE_URL requis : base dédiée PostgreSQL', allow_module_level=True)
os.environ['DATABASE_URL'] = os.environ['TEST_DATABASE_URL']
from fastapi.testclient import TestClient
from app.db import Base, School, SessionLocal, User, engine
from app.main import app, attempts
from app.security import hash_password


@pytest.fixture()
def ctx():
    assert engine.dialect.name == 'postgresql'
    assert 'test' in engine.url.database
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    attempts.clear()
    with SessionLocal.begin() as db:
        a, b = School(name='A'), School(name='B')
        db.add_all([a, b]); db.flush()
        aid, bid = a.id, b.id
        for name, role, sid in [('admin', 'admin', aid), ('other', 'admin', bid), ('teacher', 'teacher', aid), ('accountant', 'accountant', aid), ('super', 'super_admin', None)]:
            db.add(User(email=name+'@test.local', name=name, role=role, school_id=sid, password_hash=hash_password('Test-password-123')))
    client = TestClient(app)
    tokens = {}
    for name in ['admin', 'other', 'teacher', 'accountant', 'super']:
        res = client.post('/api/v1/auth/login', json={'email': name+'@test.local', 'password': 'Test-password-123'})
        assert res.status_code == 200, res.text
        tokens[name] = {'Authorization': 'Bearer '+res.json()['access_token']}
    return client, '/api/v1/schools/'+aid, '/api/v1/schools/'+bid, tokens


def create(client, base, token, kind, body):
    res = client.post(base+'/'+kind, headers=token, json=body)
    assert res.status_code == 201, res.text
    return res.json()


def test_isolation_roles_suspension_and_sessions(ctx):
    c, a, b, t = ctx
    student = create(c, b, t['other'], 'students', {'first_name': 'Other', 'last_name': 'School'})
    assert c.get(b+'/students', headers=t['admin']).status_code == 404
    assert c.get(a+'/students/'+student['id'], headers=t['admin']).status_code == 404
    assert c.post(a+'/charges', headers=t['admin'], json={'student_id': student['id'], 'amount': 10}).status_code == 404
    assert c.get(a+'/payments', headers=t['teacher']).status_code == 403
    assert c.get(a+'/grades', headers=t['accountant']).status_code == 403
    assert c.get('/api/v1/platform/schools', headers=t['admin']).status_code == 403
    assert c.get(a+'/students', headers=t['super']).status_code == 404
    sid = a.split('/')[-1]
    assert c.post('/api/v1/platform/schools/'+sid+'/suspend', headers=t['super'], json={'reason': 'test'}).status_code == 200
    assert c.get(a+'/students', headers=t['admin']).status_code == 403
    c.post('/api/v1/platform/schools/'+sid+'/activate', headers=t['super'], json={})
    assert c.get(a+'/students', headers=t['admin']).status_code == 200
    assert c.post('/api/v1/auth/logout', headers=t['admin']).status_code == 200
    assert c.get('/api/v1/auth/me', headers=t['admin']).status_code == 401


def test_payment_idempotence_pdf_and_reversal(ctx):
    c, a, b, t = ctx
    student = create(c, a, t['admin'], 'students', {'first_name': 'Fictif', 'last_name': 'Élève'})
    charge = create(c, a, t['admin'], 'charges', {'student_id': student['id'], 'amount': 10000})
    body = {'student_id': student['id'], 'amount': 4000, 'allocations': [{'charge_id': charge['id'], 'amount': 4000}]}
    headers = {**t['accountant'], 'Idempotency-Key': 'pay-1'}
    first = c.post(a+'/payments', headers=headers, json=body)
    assert first.status_code == 201, first.text
    assert c.post(a+'/payments', headers=headers, json=body).json() == first.json()
    assert c.post(a+'/payments', headers=headers, json={**body, 'amount': 5000}).status_code == 409
    pay = first.json()
    receipt = c.get(a+'/receipts/'+pay['receipt_id']+'/download', headers=t['accountant'])
    assert receipt.content.startswith(b'%PDF')
    assert c.get(b+'/receipts/'+pay['receipt_id']+'/download', headers=t['other']).status_code == 404
    assert c.get(a+'/students/'+student['id']+'/account', headers=t['admin']).json()['balance'] == 6000
    res = c.post(a+'/payments/'+pay['id']+'/reverse', headers={**t['accountant'], 'Idempotency-Key': 'reverse-1'}, json={'reason': 'Erreur de caisse'})
    assert res.status_code == 200
    assert c.get(a+'/finance/dashboard', headers=t['admin']).json()['paid'] == 0


def test_concurrent_payments_prevent_overpayment(ctx):
    c, a, _, t = ctx
    student = create(c, a, t['admin'], 'students', {'first_name': 'Test', 'last_name': 'Concurrence'})
    charge = create(c, a, t['admin'], 'charges', {'student_id': student['id'], 'amount': 10000})
    body = {'student_id': student['id'], 'amount': 7000, 'allocations': [{'charge_id': charge['id'], 'amount': 7000}]}
    def send(i):
        with TestClient(app) as client:
            return client.post(a+'/payments', headers={**t['accountant'], 'Idempotency-Key': 'concurrent-'+str(i)}, json=body).status_code
    with ThreadPoolExecutor(max_workers=2) as pool:
        assert sorted(pool.map(send, [1, 2])) == [201, 409]


def test_pedagogy_report_links_and_csrf(ctx):
    c, a, _, t = ctx
    y = create(c, a, t['admin'], 'academic-years', {'name': '2026'})
    term = create(c, a, t['admin'], 'terms', {'name': 'T1', 'academic_year_id': y['id']})
    cl = create(c, a, t['admin'], 'classes', {'name': '6e'})
    sub = create(c, a, t['admin'], 'subjects', {'name': 'Maths', 'coefficient': '2'})
    student = create(c, a, t['admin'], 'students', {'first_name': 'Test', 'last_name': 'PDF'})
    enr = create(c, a, t['admin'], 'enrollments', {'student_id': student['id'], 'class_id': cl['id'], 'academic_year_id': y['id']})
    assessment = create(c, a, t['admin'], 'assessments', {'name': 'Test', 'class_id': cl['id'], 'subject_id': sub['id'], 'term_id': term['id']})
    grade_url = a+'/assessments/'+assessment['id']+'/grades'
    body = {'records': [{'enrollment_id': enr['id'], 'score': '15.5'}]}
    assert c.put(grade_url, headers=t['teacher'], json=body).status_code == 403
    assert c.put(grade_url, headers=t['admin'], json={'records': [{'enrollment_id': enr['id'], 'score': '21'}]}).status_code == 422
    assert c.put(grade_url, headers=t['admin'], json=body).status_code == 200
    job = c.post(a+'/report-cards/generate', headers=t['admin'], json={'class_id': cl['id'], 'term_id': term['id']})
    assert job.status_code == 202, job.text
    report_id = job.json()['report_card_ids'][0]
    report = c.get(a+'/report-cards/'+report_id, headers=t['admin']).json()
    assert report['average'] == '15.50'
    assert c.post(a+'/report-cards/'+report_id+'/publish', headers={**t['admin'], 'Idempotency-Key': 'publish-1'}).status_code == 200
    link = c.post(a+'/report-cards/'+report_id+'/share-links', headers=t['admin']).json()
    path = '/api/v1/documents/shared/'+link['url'].split('/')[-1]
    assert c.get(path).content.startswith(b'%PDF')
    assert c.delete(a+'/document-share-links/'+link['id'], headers=t['admin']).status_code == 204
    assert c.get(path).status_code == 404
    c.post('/api/v1/auth/login', json={'email': 'admin@test.local', 'password': 'Test-password-123'})
    assert c.post(a+'/classes', json={'name': 'CSRF'}).status_code == 403


def test_teacher_assignment_and_atomic_attendance(ctx):
    c, a, b, t = ctx
    y = create(c, a, t['admin'], 'academic-years', {'name': '2026'})
    term = create(c, a, t['admin'], 'terms', {'name': 'T1', 'academic_year_id': y['id']})
    cl = create(c, a, t['admin'], 'classes', {'name': '6e'})
    other_class = create(c, a, t['admin'], 'classes', {'name': '5e'})
    maths = create(c, a, t['admin'], 'subjects', {'name': 'Maths'})
    french = create(c, a, t['admin'], 'subjects', {'name': 'Français'})
    teacher = create(c, a, t['admin'], 'teachers', {'name': 'New teacher', 'email': 'newteacher@test.local', 'password': 'Test-password-123'})
    create(c, a, t['admin'], 'teaching-assignments', {'teacher_id': teacher['id'], 'class_id': cl['id'], 'subject_id': maths['id']})
    login = c.post('/api/v1/auth/login', json={'email': 'newteacher@test.local', 'password': 'Test-password-123'}).json()
    token = {'Authorization': 'Bearer '+login['access_token']}
    assert [r['id'] for r in c.get(a+'/classes', headers=token).json()['items']] == [cl['id']]
    student = create(c, a, t['admin'], 'students', {'first_name': 'Test', 'last_name': 'Élève', 'guardian_phone': '+22670000000', 'consent': True})
    enr = create(c, a, t['admin'], 'enrollments', {'student_id': student['id'], 'class_id': cl['id'], 'academic_year_id': y['id']})
    session = create(c, a, token, 'attendance-sessions', {'class_id': cl['id'], 'date': '2026-09-15'})
    assert c.post(a+'/attendance-sessions', headers=token, json={'class_id': other_class['id'], 'date': '2026-09-15'}).status_code == 403
    endpoint = a+'/attendance-sessions/'+session['id']+'/records'
    body = {'records': [{'enrollment_id': enr['id'], 'status': 'absent'}]}
    assert c.put(endpoint, headers=token, json=body).status_code == 200
    assert c.put(endpoint, headers=token, json=body).status_code == 200
    assert c.get(a+'/attendance', headers=t['admin']).json()['total'] == 1
    messages = c.get(a+'/messages', headers=t['admin']).json()['items']
    assert len(messages) == 1 and messages[0]['status'] == 'simulated'
    assessment = create(c, a, t['admin'], 'assessments', {'name': 'Français', 'class_id': cl['id'], 'subject_id': french['id'], 'term_id': term['id']})
    assert c.get(a+'/assessments', headers=token).json()['total'] == 0
    assert c.get(a+'/assessments/'+assessment['id'], headers=token).status_code == 403
    response = c.put(endpoint, headers=token, json={'records': [{'enrollment_id': enr['id'], 'status': 'present'}, {'enrollment_id': 'inconnu', 'status': 'present'}]})
    assert response.status_code == 404
    assert c.get(a+'/attendance', headers=t['admin']).json()['items'][0]['status'] == 'absent'

def test_super_admin_creates_school_and_admin(ctx):
    c, a, _, t = ctx
    created = c.post('/api/v1/platform/schools', headers=t['super'], json={'name':'Nouvelle école','city':'Bobo-Dioulasso','admin_name':'Admin Nouveau','admin_email':'nouveau@test.local','admin_password':'Test-password-123'})
    assert created.status_code == 201, created.text
    assert created.json()['admin']['email'] == 'nouveau@test.local'
    login = c.post('/api/v1/auth/login', json={'email':'nouveau@test.local','password':'Test-password-123'})
    assert login.status_code == 200
    assert login.json()['user']['school_id'] == created.json()['id']

def test_super_admin_assigns_subscription_plan(ctx):
    c, a, _, t = ctx
    school = c.get('/api/v1/platform/schools', headers=t['super']).json()['items'][0]
    plan = c.post('/api/v1/platform/plans', headers=t['super'], json={'name':'Essentiel','amount':25000,'currency':'XOF','student_limit':300}).json()
    subscription = c.post('/api/v1/platform/subscriptions', headers=t['super'], json={'school_id':school['id'],'plan_id':plan['id'],'start_date':'2026-09-01','end_date':'2027-08-31','status':'active'})
    assert subscription.status_code == 201, subscription.text
    assert subscription.json()['status'] == 'active'
    stats = c.get('/api/v1/platform/dashboard', headers=t['super']).json()
    assert stats['active_subscriptions'] == 1
