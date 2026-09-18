import hashlib
import io
import json
import os
import re
import secrets
import time
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation

from fastapi import Depends, FastAPI, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from sqlalchemy import select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session as DB

from .db import Base, Idempotency, Record, School, Session, User, engine, get_db, now, uid
from .security import hash_password, token_hash, verify_password

app = FastAPI(title='SRC SCHOOL', version='0.1.0')
app.add_middleware(CORSMiddleware, allow_origins=os.getenv('CORS_ORIGINS', 'http://localhost:3000,http://127.0.0.1:3000').split(','), allow_credentials=True, allow_methods=['*'], allow_headers=['*'])
P = '/api/v1'
attempts = defaultdict(list)


def fail(code, message, status=422):
    raise HTTPException(status, {'code': code, 'message': message, 'details': {}})


@app.exception_handler(HTTPException)
async def errors(request, exc):
    return JSONResponse(status_code=exc.status_code, content={'error': exc.detail if isinstance(exc.detail, dict) else {'code': 'ERROR', 'message': exc.detail}, 'request_id': uid()})


@app.exception_handler(IntegrityError)
async def conflict(request, exc):
    return JSONResponse(status_code=409, content={'error': {'code': 'CONFLICT', 'message': 'Cet enregistrement existe déjà.'}})


@app.exception_handler(ValueError)
async def invalid(request, exc):
    return JSONResponse(status_code=422, content={'error': {'code': 'INVALID', 'message': str(exc)}})


@app.exception_handler(InvalidOperation)
async def invalid_decimal(request, exc):
    return JSONResponse(status_code=422, content={'error': {'code': 'INVALID_NUMBER', 'message': 'Nombre décimal invalide.'}})


def public_user(user):
    return {k: getattr(user, k) for k in ['id', 'name', 'email', 'role', 'school_id']}


def identity(request: Request, db: DB = Depends(get_db)):
    bearer = request.headers.get('authorization', '')
    token = bearer[7:] if bearer.startswith('Bearer ') else request.cookies.get('src_session')
    session = db.get(Session, token_hash(token)) if token else None
    if not session or session.expires_at.replace(tzinfo=timezone.utc) < now():
        fail('UNAUTHENTICATED', 'Veuillez vous connecter.', 401)
    if not bearer and request.method not in ['GET', 'HEAD', 'OPTIONS'] and request.headers.get('x-csrf-token') != session.csrf:
        fail('CSRF', 'Session de formulaire invalide.', 403)
    user = db.get(User, session.user_id)
    if not user or not user.active:
        fail('UNAUTHENTICATED', 'Compte désactivé.', 401)
    request.state.session = session
    return user


def school_access(school_id, user, db, roles=None):
    if user.school_id != school_id or user.role == 'super_admin':
        fail('NOT_FOUND', 'Établissement introuvable.', 404)
    school = db.get(School, school_id)
    if not school or not school.active:
        fail('SCHOOL_SUSPENDED', 'Établissement suspendu.', 403)
    if roles and user.role not in roles:
        fail('FORBIDDEN', 'Action non autorisée pour ce rôle.', 403)
    return school


def output(record):
    return {**record.data, 'id': record.id, 'school_id': record.school_id, 'version': record.version, 'created_at': record.created_at.isoformat()}


def rows(db, school_id, kind):
    return list(db.scalars(select(Record).where(Record.school_id == school_id, Record.kind == kind).order_by(Record.created_at, Record.id)))


def get_record(db, school_id, kind, record_id, lock=False):
    q = select(Record).where(Record.id == record_id, Record.school_id == school_id, Record.kind == kind)
    rec = db.scalar(q.with_for_update() if lock else q)
    if not rec:
        fail('NOT_FOUND', 'Ressource introuvable.', 404)
    return rec


def add(db, school_id, kind, data, unique_key=None):
    rec = Record(school_id=school_id, kind=kind, data=data, unique_key=unique_key)
    db.add(rec)
    db.flush()
    return rec


def audit(db, user, action, record_id):
    if user.school_id:
        add(db, user.school_id, 'audit-events', {'actor_id': user.id, 'actor_name': user.name, 'action': action, 'resource_id': record_id})


def session_result(db, user, response):
    token, csrf = secrets.token_urlsafe(40), secrets.token_urlsafe(24)
    db.add(Session(token_hash=token_hash(token), user_id=user.id, csrf=csrf, expires_at=now()+timedelta(hours=12)))
    secure = os.getenv('COOKIE_SECURE', 'false') == 'true'
    response.set_cookie('src_session', token, httponly=True, secure=secure, samesite='lax', max_age=43200, path='/')
    response.set_cookie('src_csrf', csrf, secure=secure, samesite='lax', max_age=43200, path='/')
    school = db.get(School, user.school_id) if user.school_id else None
    return {'access_token': token, 'token_type': 'bearer', 'csrf_token': csrf, 'user': public_user(user), 'memberships': [{'school_id': school.id, 'school_name': school.name, 'role': user.role}] if school else []}


@app.get('/health')
def health(db: DB = Depends(get_db)):
    db.execute(text('SELECT 1'))
    return {'status': 'ok', 'database': engine.dialect.name, 'whatsapp': 'simulated'}


@app.post(P+'/auth/login')
def login(body: dict, request: Request, response: Response, db: DB = Depends(get_db)):
    key = request.client.host if request.client else 'unknown'
    attempts[key] = [x for x in attempts[key] if x > time.time()-60]
    if len(attempts[key]) >= 15:
        fail('RATE_LIMIT', 'Réessayez dans une minute.', 429)
    attempts[key].append(time.time())
    user = db.scalar(select(User).where(User.email == str(body.get('email', '')).lower().strip()))
    if not user or not user.active or not verify_password(str(body.get('password', '')), user.password_hash):
        fail('INVALID_CREDENTIALS', 'Identifiants incorrects.', 401)
    if user.school_id:
        school_access(user.school_id, user, db)
    return session_result(db, user, response)


@app.get(P+'/auth/me')
def me(user: User = Depends(identity), db: DB = Depends(get_db)):
    school = school_access(user.school_id, user, db) if user.school_id else None
    return {'user': public_user(user), 'memberships': [{'school_id': school.id, 'school_name': school.name, 'role': user.role}] if school else []}


@app.post(P+'/auth/logout')
def logout(request: Request, response: Response, user: User = Depends(identity), db: DB = Depends(get_db)):
    db.delete(request.state.session)
    response.delete_cookie('src_session', path='/')
    response.delete_cookie('src_csrf', path='/')
    return {'ok': True}


@app.post(P+'/auth/refresh')
def refresh(request: Request, response: Response, user: User = Depends(identity), db: DB = Depends(get_db)):
    db.delete(request.state.session)
    return session_result(db, user, response)


@app.post(P+'/auth/password-reset/request', status_code=503)
def password_reset_unconfigured():
    fail('RESET_CHANNEL_NOT_CONFIGURED', 'La récupération de mot de passe nécessite un canal d’envoi configuré. Contactez votre administrateur.', 503)


FINANCE = {'fee-definitions', 'charges', 'payments', 'arrears', 'receipts'}
ADMIN = {'academic-years', 'terms', 'classes', 'students', 'guardians', 'enrollments', 'teachers', 'subjects', 'teaching-assignments', 'timetable', 'announcements'}
PEDAGOGY = {'attendance-sessions', 'attendance', 'assessments', 'grades', 'assignments', 'assignment-progress', 'report-cards'}
KINDS = ADMIN | FINANCE | PEDAGOGY | {'messages', 'notifications', 'audit-events', 'jobs'}
LINKS = {'class_id': 'classes', 'student_id': 'students', 'academic_year_id': 'academic-years', 'term_id': 'terms', 'subject_id': 'subjects', 'teacher_id': 'teachers', 'enrollment_id': 'enrollments', 'fee_definition_id': 'fee-definitions', 'charge_id': 'charges'}


def check_kind(kind, user, write=False):
    if kind not in KINDS:
        fail('NOT_FOUND', 'Collection introuvable.', 404)
    if kind in FINANCE and user.role not in ['admin', 'accountant']:
        fail('FORBIDDEN', 'Accès financier interdit.', 403)
    if kind in PEDAGOGY and user.role == 'accountant':
        fail('FORBIDDEN', 'Accès pédagogique interdit.', 403)
    if kind == 'audit-events' and user.role != 'admin':
        fail('FORBIDDEN', 'Accès audit interdit.', 403)
    if write and kind in ADMIN and user.role != 'admin':
        fail('FORBIDDEN', 'Administration requise.', 403)


def teacher_classes(db, user):
    teachers = rows(db, user.school_id, 'teachers')
    teacher_ids = {t.id for t in teachers if t.data.get('user_id') == user.id}
    return {a.data.get('class_id') for a in rows(db, user.school_id, 'teaching-assignments') if a.data.get('teacher_id') in teacher_ids}


def teacher_subjects(db, user):
    teacher_ids = {t.id for t in rows(db, user.school_id, 'teachers') if t.data.get('user_id') == user.id}
    return {(a.data.get('class_id'), a.data.get('subject_id')) for a in rows(db, user.school_id, 'teaching-assignments') if a.data.get('teacher_id') in teacher_ids}


def pedagogical_access(db, user, data, subject=False):
    if user.role != 'teacher':
        return
    if data.get('class_id') not in teacher_classes(db, user):
        fail('FORBIDDEN', 'Classe non affectée.', 403)
    if subject and data.get('subject_id'):
        teacher_ids = {t.id for t in rows(db, user.school_id, 'teachers') if t.data.get('user_id') == user.id}
        if not any(a.data.get('teacher_id') in teacher_ids and a.data.get('class_id') == data.get('class_id') and a.data.get('subject_id') == data.get('subject_id') for a in rows(db, user.school_id, 'teaching-assignments')):
            fail('FORBIDDEN', 'Matière non affectée.', 403)


def validate(db, school_id, kind, data, current_id=None):
    data = {k: v for k, v in data.items() if k not in ['id', 'school_id', 'created_at', 'version', 'expected_version', 'password_hash']}
    for key, related in LINKS.items():
        if data.get(key):
            get_record(db, school_id, related, data[key])
    for student_id in data.get('student_ids', []):
        get_record(db, school_id, 'students', student_id)
    for field in ['first_name', 'last_name', 'name', 'title', 'body', 'email', 'guardian_name', 'guardian_phone', 'phone']:
        if field in data and (not isinstance(data[field], str) or len(data[field]) > (10000 if field == 'body' else 500)):
            fail('VALIDATION', f'Texte invalide : {field}')
    if 'consent' in data and type(data['consent']) is not bool:
        fail('VALIDATION', 'Consentement booléen requis.')
    for field in ['phone', 'guardian_phone']:
        if data.get(field):
            normalized = re.sub(r'[\s().-]', '', data[field])
            if not re.fullmatch(r'\+[1-9][0-9]{7,14}', normalized):
                fail('VALIDATION', 'Numéro au format international requis, par exemple +226…')
            data[field] = normalized
    if kind == 'enrollments':
        classe = get_record(db, school_id, 'classes', data.get('class_id'))
        if classe.data.get('academic_year_id') and classe.data['academic_year_id'] != data.get('academic_year_id'):
            fail('VALIDATION', 'Année incompatible avec la classe.')
    for field in ['date', 'due_date', 'start_date', 'end_date']:
        if data.get(field):
            datetime.strptime(data[field], '%Y-%m-%d')
    required = {'classes': ['name'], 'students': ['first_name', 'last_name'], 'teachers': ['name', 'email'], 'subjects': ['name'], 'academic-years': ['name'], 'terms': ['name', 'academic_year_id'], 'enrollments': ['student_id', 'class_id', 'academic_year_id'], 'charges': ['student_id', 'amount'], 'fee-definitions': ['name', 'amount'], 'attendance-sessions': ['class_id', 'date'], 'assessments': ['name', 'class_id', 'subject_id', 'term_id'], 'assignments': ['title', 'class_id', 'subject_id', 'due_date'], 'teaching-assignments': ['teacher_id', 'class_id', 'subject_id'], 'announcements': ['title', 'body']}
    for key in required.get(kind, []):
        if data.get(key) is None or data.get(key) == '':
            fail('VALIDATION', f'Champ obligatoire : {key}')
    if 'amount' in data and (type(data['amount']) is not int or data['amount'] <= 0):
        fail('INVALID_AMOUNT', 'Le montant doit être un entier positif.')
    for field in ['coefficient', 'max_score']:
        if field in data:
            value = Decimal(str(data[field]))
            if not value.is_finite() or value <= 0:
                fail('INVALID_NUMBER', f'{field} doit être positif.')
    if kind == 'timetable':
        for field in ['day', 'start_time', 'end_time', 'class_id', 'teacher_id']:
            if not data.get(field):
                fail('VALIDATION', f'Champ obligatoire : {field}')
        if data['end_time'] <= data['start_time']:
            fail('VALIDATION', 'Horaire de fin invalide.')
        for other in rows(db, school_id, kind):
            if other.id == current_id:
                continue
            d = other.data
            if d.get('day') == data['day'] and (d.get('class_id') == data['class_id'] or d.get('teacher_id') == data['teacher_id']) and data['start_time'] < d.get('end_time', '') and data['end_time'] > d.get('start_time', ''):
                fail('TIMETABLE_CONFLICT', 'Créneau en conflit.', 409)
    return data


def page(items, request):
    number = max(1, int(request.query_params.get('page', 1)))
    size = min(100, max(1, int(request.query_params.get('page_size', 25))))
    return {'items': items[(number-1)*size:number*size], 'total': len(items), 'page': number, 'page_size': size}


def finance(db, school_id):
    charged = sum(r.data['amount'] for r in rows(db, school_id, 'charges'))
    paid = sum(r.data['amount'] for r in rows(db, school_id, 'payments') if r.data.get('status') == 'confirmed')
    return {'charged': charged, 'paid': paid, 'outstanding': charged-paid, 'total_charged': charged, 'total_paid': paid, 'total_outstanding': charged-paid, 'collection_rate': round(paid/charged*100, 1) if charged else 0, 'currency': 'XOF'}


@app.get(P+'/schools/{school_id}/dashboard')
def dashboard(school_id: str, user: User = Depends(identity), db: DB = Depends(get_db)):
    school = school_access(school_id, user, db)
    allowed = teacher_classes(db, user) if user.role == 'teacher' else None
    classes = [r for r in rows(db, school_id, 'classes') if allowed is None or r.id in allowed]
    students = [r for r in rows(db, school_id, 'students') if not r.data.get('archived') and (allowed is None or r.data.get('class_id') in allowed)]
    result = {'school': {'id': school.id, 'name': school.name}, 'students': len(students), 'classes': len(classes), 'teachers': len(rows(db, school_id, 'teachers')), 'attendance_count': len(rows(db, school_id, 'attendance')), 'demonstration': school.data.get('demonstration', False)}
    if user.role in ['admin', 'accountant']:
        result.update(finance(db, school_id))
    return result


@app.get(P+'/schools/{school_id}/settings')
def school_settings(school_id: str, user: User = Depends(identity), db: DB = Depends(get_db)):
    school = school_access(school_id, user, db)
    return {
        'id': school.id,
        'name': school.name,
        'currency': school.data.get('currency', 'XOF'),
        'demonstration': school.data.get('demonstration', False),
    }


@app.patch(P+'/schools/{school_id}/settings')
def update_school_settings(school_id: str, body: dict, user: User = Depends(identity), db: DB = Depends(get_db)):
    school = school_access(school_id, user, db, ['admin'])
    name = str(body.get('name', school.name)).strip()
    currency = str(body.get('currency', school.data.get('currency', 'XOF'))).strip().upper()
    if not name or len(name) > 200:
        fail('VALIDATION', 'Le nom de l’établissement est obligatoire.')
    if currency not in ['XOF', 'EUR', 'USD']:
        fail('VALIDATION', 'Devise non supportée.')
    if 'demonstration' in body and type(body['demonstration']) is not bool:
        fail('VALIDATION', 'Le statut démonstration doit être booléen.')
    school.name = name
    school.data = {
        **school.data,
        'currency': currency,
        'demonstration': body.get('demonstration', school.data.get('demonstration', False)),
    }
    audit(db, user, 'school.settings.update', school.id)
    return {'id': school.id, 'name': school.name, 'currency': currency, 'demonstration': school.data['demonstration']}


@app.get(P+'/schools/{school_id}/finance/dashboard')
@app.get(P+'/schools/{school_id}/finance/reports')
def finance_dashboard(school_id: str, user: User = Depends(identity), db: DB = Depends(get_db)):
    school_access(school_id, user, db, ['admin', 'accountant'])
    return finance(db, school_id)


def balance(db, school_id, charge):
    allocated = sum(a['amount'] for p in rows(db, school_id, 'payments') if p.data.get('status') == 'confirmed' for a in p.data.get('allocations', []) if a['charge_id'] == charge.id)
    return charge.data['amount']-allocated


@app.get(P+'/schools/{school_id}/students/{student_id}/account')
def account(school_id: str, student_id: str, user: User = Depends(identity), db: DB = Depends(get_db)):
    school_access(school_id, user, db, ['admin', 'accountant'])
    get_record(db, school_id, 'students', student_id)
    charges = [{**output(c), 'remaining_balance': balance(db, school_id, c)} for c in rows(db, school_id, 'charges') if c.data['student_id'] == student_id]
    return {'charges': charges, 'payments': [output(p) for p in rows(db, school_id, 'payments') if p.data['student_id'] == student_id], 'balance': sum(c['remaining_balance'] for c in charges), 'currency': 'XOF'}


def notify(db, school_id, event, student_id=None, class_id=None):
    for student in rows(db, school_id, 'students'):
        if student_id and student.id != student_id or class_id and student.data.get('class_id') != class_id:
            continue
        if student.data.get('consent') and student.data.get('guardian_phone'):
            add(db, school_id, 'messages', {'student_id': student.id, 'recipient': student.data['guardian_phone'], 'event': event, 'status': 'simulated', 'provider': 'mock', 'detail': 'Simulation de développement ; aucun message WhatsApp envoyé.'})


def idempotent(db, school_id, action, request, body, callback):
    key = request.headers.get('idempotency-key')
    if not key or len(key) > 200:
        fail('IDEMPOTENCY_REQUIRED', 'En-tête Idempotency-Key requis.')
    # Serializes financial writes per school, including a concurrent identical retry.
    db.scalar(select(School).where(School.id == school_id).with_for_update())
    identity_key = school_id+':'+action+':'+key
    fingerprint = hashlib.sha256(json.dumps(body, sort_keys=True).encode()).hexdigest()
    prior = db.get(Idempotency, identity_key)
    if prior:
        if prior.fingerprint != fingerprint:
            fail('IDEMPOTENCY_CONFLICT', 'Clé déjà utilisée avec un contenu différent.', 409)
        return prior.response
    result = callback()
    db.add(Idempotency(key=identity_key, fingerprint=fingerprint, response=result))
    return result


@app.post(P+'/schools/{school_id}/payments', status_code=201)
def payment(school_id: str, body: dict, request: Request, user: User = Depends(identity), db: DB = Depends(get_db)):
    school_access(school_id, user, db, ['admin', 'accountant'])
    def create():
        student = get_record(db, school_id, 'students', body.get('student_id'))
        amount = body.get('amount')
        if type(amount) is not int or amount <= 0 or body.get('currency', 'XOF') != 'XOF':
            fail('INVALID_AMOUNT', 'Montant entier positif en XOF requis.')
        allocations = body.get('allocations') or []
        if not allocations:
            remaining = amount
            for charge in rows(db, school_id, 'charges'):
                if charge.data['student_id'] == student.id:
                    part = min(balance(db, school_id, charge), remaining)
                    if part > 0:
                        allocations.append({'charge_id': charge.id, 'amount': part})
                        remaining -= part
        if any(type(a.get('amount')) is not int or a['amount'] <= 0 for a in allocations) or sum(a['amount'] for a in allocations) != amount:
            fail('INVALID_ALLOCATIONS', 'Les allocations doivent totaliser le paiement.')
        if len({a['charge_id'] for a in allocations}) != len(allocations):
            fail('INVALID_ALLOCATIONS', 'Charge répétée.')
        for allocation in allocations:
            charge = get_record(db, school_id, 'charges', allocation['charge_id'], True)
            if charge.data['student_id'] != student.id:
                fail('NOT_FOUND', 'Charge introuvable.', 404)
            if allocation['amount'] > balance(db, school_id, charge):
                fail('OVERPAYMENT', 'Paiement supérieur au solde.', 409)
        if body.get('method', 'cash') not in ['cash', 'bank_transfer', 'mobile_money', 'other']:
            fail('INVALID_METHOD', 'Moyen de paiement invalide.')
        count = len(rows(db, school_id, 'payments'))+1
        receipt_id = uid()
        data = {**body, 'amount': amount, 'allocations': allocations, 'currency': 'XOF', 'status': 'confirmed', 'receipt_id': receipt_id, 'receipt_number': f'{now().year}-{count:06d}', 'actor_id': user.id, 'paid_at': body.get('paid_at', now().isoformat())}
        rec = add(db, school_id, 'payments', data)
        receipt = Record(id=receipt_id, school_id=school_id, kind='receipts', data={'payment_id': rec.id})
        db.add(receipt)
        audit(db, user, 'payment.create', rec.id)
        notify(db, school_id, 'payment.confirmed', student.id)
        return {**output(rec), 'payment_id': rec.id, 'remaining_balance': sum(balance(db, school_id, c) for c in rows(db, school_id, 'charges') if c.data['student_id'] == student.id)}
    return idempotent(db, school_id, 'payment', request, body, create)


@app.post(P+'/schools/{school_id}/payments/{record_id}/reverse')
def reverse(school_id: str, record_id: str, body: dict, request: Request, user: User = Depends(identity), db: DB = Depends(get_db)):
    school_access(school_id, user, db, ['admin', 'accountant'])
    def perform():
        rec = get_record(db, school_id, 'payments', record_id, True)
        if not str(body.get('reason', '')).strip():
            fail('REASON_REQUIRED', 'Motif requis.')
        if rec.data['status'] != 'confirmed':
            fail('ALREADY_REVERSED', 'Paiement déjà annulé.', 409)
        rec.data = {**rec.data, 'status': 'reversed', 'reversal_reason': body['reason'], 'reversed_at': now().isoformat(), 'reversed_by': user.id}
        rec.version += 1
        audit(db, user, 'payment.reverse', rec.id)
        return output(rec)
    return idempotent(db, school_id, 'reverse:'+record_id, request, body, perform)


@app.put(P+'/schools/{school_id}/attendance-sessions/{record_id}/records')
@app.put(P+'/schools/{school_id}/assessments/{record_id}/grades')
@app.put(P+'/schools/{school_id}/assignments/{record_id}/progress')
def batch_records(school_id: str, record_id: str, body: dict, request: Request, user: User = Depends(identity), db: DB = Depends(get_db)):
    school_access(school_id, user, db, ['admin', 'teacher'])
    path = request.url.path
    kind, child = ('attendance-sessions', 'attendance') if path.endswith('/records') else ('assessments', 'grades') if path.endswith('/grades') else ('assignments', 'assignment-progress')
    parent = get_record(db, school_id, kind, record_id, True)
    pedagogical_access(db, user, parent.data, True)
    if parent.data.get('published'):
        fail('LOCKED', 'Évaluation publiée.', 409)
    if body.get('expected_version', parent.version) != parent.version:
        fail('VERSION_CONFLICT', 'Rechargez les dernières données.', 409)
    for data in body.get('records', body.get('grades', [])):
        enrollment = get_record(db, school_id, 'enrollments', data.get('enrollment_id'))
        if enrollment.data['class_id'] != parent.data['class_id']:
            fail('NOT_FOUND', 'Inscription hors classe.', 404)
        if child == 'attendance' and data.get('status') not in ['present', 'absent', 'late', 'excused']:
            fail('VALIDATION', 'Statut de présence invalide.')
        if child == 'grades' and data.get('score') is not None:
            score = Decimal(str(data['score']))
            if not score.is_finite() or score < 0 or score > Decimal(str(parent.data.get('max_score', 20))):
                fail('INVALID_GRADE', 'Note hors barème.')
            data['score'] = str(score)
        if child == 'assignment-progress' and data.get('status') not in ['submitted', 'missing', 'graded']:
            fail('VALIDATION', 'Statut de devoir invalide.')
        key = record_id+':'+enrollment.id
        existing = db.scalar(select(Record).where(Record.school_id == school_id, Record.kind == child, Record.unique_key == key))
        values = {**data, 'parent_id': record_id, 'class_id': parent.data['class_id'], 'student_id': enrollment.data['student_id']}
        previous_status = existing.data.get('status') if existing else None
        if existing:
            existing.data = values
            existing.version += 1
        else:
            add(db, school_id, child, values, key)
        if child == 'attendance' and data.get('status') == 'absent' and previous_status != 'absent':
            notify(db, school_id, 'attendance.absent', enrollment.data['student_id'])
    parent.version += 1
    audit(db, user, kind+'.update', parent.id)
    return {'ok': True, 'version': parent.version}


def pdf_response(title, lines):
    stream = io.BytesIO()
    doc = canvas.Canvas(stream, pagesize=A4)
    doc.setTitle(title)
    y = 800
    for line in [title, '', *lines]:
        doc.setFont('Helvetica', 11)
        doc.drawString(45, y, str(line)[:105])
        y -= 21
        if y < 50:
            doc.showPage()
            y = 800
    doc.save()
    return Response(stream.getvalue(), media_type='application/pdf', headers={'Content-Disposition': 'attachment; filename="src-school.pdf"', 'Cache-Control': 'private, no-store'})


@app.get(P+'/schools/{school_id}/receipts/{record_id}/download')
def receipt(school_id: str, record_id: str, user: User = Depends(identity), db: DB = Depends(get_db)):
    school = school_access(school_id, user, db, ['admin', 'accountant'])
    rec = get_record(db, school_id, 'receipts', record_id)
    pay = get_record(db, school_id, 'payments', rec.data['payment_id'])
    student = get_record(db, school_id, 'students', pay.data['student_id'])
    return pdf_response('SRC SCHOOL - Reçu '+pay.data['receipt_number'], [school.name, student.data['first_name']+' '+student.data['last_name'], str(pay.data['amount'])+' FCFA', 'Moyen : '+pay.data.get('method', 'cash'), 'Date : '+pay.data['paid_at'], 'Statut : '+pay.data['status']])


@app.post(P+'/schools/{school_id}/report-cards/generate', status_code=202)
def generate(school_id: str, body: dict, user: User = Depends(identity), db: DB = Depends(get_db)):
    school = school_access(school_id, user, db, ['admin'])
    term = get_record(db, school_id, 'terms', body.get('term_id'))
    if body.get('student_id'):
        get_record(db, school_id, 'students', body['student_id'])
    if body.get('class_id'):
        get_record(db, school_id, 'classes', body['class_id'])
    ids = []
    for enrollment in rows(db, school_id, 'enrollments'):
        if body.get('student_id') and enrollment.data['student_id'] != body['student_id'] or body.get('class_id') and enrollment.data['class_id'] != body['class_id'] or enrollment.data['academic_year_id'] != term.data['academic_year_id']:
            continue
        student = get_record(db, school_id, 'students', enrollment.data['student_id'])
        subjects = {}
        for assessment in rows(db, school_id, 'assessments'):
            if assessment.data.get('term_id') != term.id or assessment.data['class_id'] != enrollment.data['class_id']:
                continue
            grade = next((g for g in rows(db, school_id, 'grades') if g.data.get('parent_id') == assessment.id and g.data.get('enrollment_id') == enrollment.id), None)
            if not grade or grade.data.get('score') is None:
                fail('MISSING_GRADES', 'Notes manquantes : complétez les évaluations avant de générer le bulletin.', 409)
            subject_id = assessment.data['subject_id']
            part = subjects.setdefault(subject_id, {'sum': Decimal(0), 'weight': Decimal(0)})
            weight = Decimal(str(assessment.data.get('coefficient', 1)))
            part['sum'] += Decimal(grade.data['score'])/Decimal(str(assessment.data.get('max_score', 20)))*20*weight
            part['weight'] += weight
        if not subjects:
            fail('NO_GRADES', 'Aucune évaluation dans cette période.', 409)
        lines, total, weights = [], Decimal(0), Decimal(0)
        for subject_id, part in subjects.items():
            subject = get_record(db, school_id, 'subjects', subject_id)
            average = part['sum']/part['weight']
            weight = Decimal(str(subject.data.get('coefficient', 1)))
            total += average*weight
            weights += weight
            lines.append({'subject': subject.data['name'], 'average': str(average.quantize(Decimal('0.01'))), 'coefficient': str(weight)})
        year = get_record(db, school_id, 'academic-years', enrollment.data['academic_year_id'])
        classe = get_record(db, school_id, 'classes', enrollment.data['class_id'])
        document_version = 1+sum(r.data.get('student_id') == student.id and r.data.get('term_id') == term.id for r in rows(db, school_id, 'report-cards'))
        absences = 0
        for attendance in rows(db, school_id, 'attendance'):
            if attendance.data.get('enrollment_id') != enrollment.id or attendance.data.get('status') != 'absent':
                continue
            session = get_record(db, school_id, 'attendance-sessions', attendance.data['parent_id'])
            date = session.data['date']
            if term.data.get('start_date', year.data.get('start_date', '0000')) <= date <= term.data.get('end_date', year.data.get('end_date', '9999')):
                absences += 1
        rec = add(db, school_id, 'report-cards', {'student_id': student.id, 'class_id': enrollment.data['class_id'], 'term_id': term.id, 'student_name': student.data['first_name']+' '+student.data['last_name'], 'school_name': school.name, 'term_name': term.data['name'], 'academic_year_name': year.data['name'], 'class_name': classe.data['name'], 'absences': absences, 'document_version': document_version, 'subjects': lines, 'average': str((total/weights).quantize(Decimal('0.01'))), 'published': False, 'missing_grades_policy': 'require_complete'})
        ids.append(rec.id)
    job = add(db, school_id, 'jobs', {'status': 'completed', 'report_card_ids': ids})
    return {'job_id': job.id, 'report_card_ids': ids, 'status': 'completed'}


def report_pdf(rec):
    d = rec.data
    return pdf_response('SRC SCHOOL - Bulletin', [d['school_name'], d['student_name'], d.get('class_name', '')+' — '+d.get('academic_year_name', ''), d['term_name'], *[f"{s['subject']} : {s['average']}/20 (coef. {s['coefficient']})" for s in d['subjects']], 'Moyenne générale : '+d['average']+'/20', 'Absences : '+str(d.get('absences', 0)), 'Version : '+str(d.get('document_version', 1)), 'Publié' if d['published'] else 'Brouillon'])


@app.get(P+'/schools/{school_id}/report-cards/{record_id}/download')
def download_report(school_id: str, record_id: str, user: User = Depends(identity), db: DB = Depends(get_db)):
    school_access(school_id, user, db, ['admin', 'teacher'])
    rec = get_record(db, school_id, 'report-cards', record_id)
    pedagogical_access(db, user, rec.data)
    return report_pdf(rec)


@app.post(P+'/schools/{school_id}/report-cards/{record_id}/share-links')
def share(school_id: str, record_id: str, user: User = Depends(identity), db: DB = Depends(get_db)):
    school_access(school_id, user, db, ['admin'])
    rec = get_record(db, school_id, 'report-cards', record_id)
    if not rec.data.get('published'):
        fail('UNPUBLISHED', 'Publiez le bulletin avant partage.', 409)
    token = secrets.token_urlsafe(40)
    link = add(db, school_id, 'document-share-links', {'report_card_id': rec.id, 'token_hash': token_hash(token), 'expires_at': (now()+timedelta(days=7)).isoformat(), 'revoked': False})
    return {'id': link.id, 'url': os.getenv('PUBLIC_API_URL', 'http://localhost:8000')+P+'/documents/shared/'+token, 'expires_at': link.data['expires_at']}


@app.delete(P+'/schools/{school_id}/document-share-links/{record_id}', status_code=204)
def revoke_link(school_id: str, record_id: str, user: User = Depends(identity), db: DB = Depends(get_db)):
    school_access(school_id, user, db, ['admin'])
    rec = get_record(db, school_id, 'document-share-links', record_id)
    rec.data = {**rec.data, 'revoked': True}


@app.get(P+'/documents/shared/{token}')
def shared(token: str, db: DB = Depends(get_db)):
    for rec in db.scalars(select(Record).where(Record.kind == 'document-share-links')):
        if rec.data['token_hash'] == token_hash(token) and not rec.data['revoked'] and datetime.fromisoformat(rec.data['expires_at']) > now():
            school = db.get(School, rec.school_id)
            if school.active:
                return report_pdf(get_record(db, rec.school_id, 'report-cards', rec.data['report_card_id']))
    fail('NOT_FOUND', 'Lien invalide ou expiré.', 404)


@app.post(P+'/schools/{school_id}/{kind}/{record_id}/publish')
@app.post(P+'/schools/{school_id}/{kind}/{record_id}/send')
def publish(school_id: str, kind: str, record_id: str, request: Request, user: User = Depends(identity), db: DB = Depends(get_db)):
    school_access(school_id, user, db, ['admin'] if kind != 'assessments' else ['admin', 'teacher'])
    if kind not in ['assessments', 'report-cards', 'announcements']:
        fail('NOT_FOUND', 'Action introuvable.', 404)
    def perform():
        rec = get_record(db, school_id, kind, record_id, True)
        pedagogical_access(db, user, rec.data, True)
        if not rec.data.get('published'):
            rec.data = {**rec.data, 'published': True, 'published_at': now().isoformat()}
            rec.version += 1
            notify(db, school_id, kind+'.published', rec.data.get('student_id'), rec.data.get('class_id'))
            audit(db, user, kind+'.publish', rec.id)
        return output(rec)
    return idempotent(db, school_id, kind+':publish:'+record_id, request, {}, perform)


@app.post(P+'/schools/{school_id}/arrears/reminders', status_code=202)
def reminders(school_id: str, request: Request, user: User = Depends(identity), db: DB = Depends(get_db)):
    school_access(school_id, user, db, ['admin', 'accountant'])
    def perform():
        students = {c.data['student_id'] for c in rows(db, school_id, 'charges') if balance(db, school_id, c) > 0}
        for student in students:
            notify(db, school_id, 'arrears.reminder', student)
        return {'status': 'simulated', 'students': len(students)}
    return idempotent(db, school_id, 'reminders', request, {}, perform)


@app.post(P+'/schools/{school_id}/charges/batch', status_code=201)
def charge_batch(school_id: str, body: dict, request: Request, user: User = Depends(identity), db: DB = Depends(get_db)):
    school_access(school_id, user, db, ['admin', 'accountant'])
    def perform():
        classe = get_record(db, school_id, 'classes', body.get('class_id'))
        fee = get_record(db, school_id, 'fee-definitions', body.get('fee_definition_id'))
        result = []
        for enrollment in rows(db, school_id, 'enrollments'):
            if enrollment.data['class_id'] == classe.id:
                data = {'student_id': enrollment.data['student_id'], 'enrollment_id': enrollment.id, 'fee_definition_id': fee.id, 'amount': fee.data['amount'], 'name': fee.data['name'], 'due_date': body.get('due_date')}
                result.append(output(add(db, school_id, 'charges', data)))
        audit(db, user, 'charges.batch', classe.id)
        return {'items': result, 'total': len(result)}
    return idempotent(db, school_id, 'charges.batch', request, body, perform)


@app.post(P+'/schools/{school_id}/students/{record_id}/archive')
def archive(school_id: str, record_id: str, user: User = Depends(identity), db: DB = Depends(get_db)):
    school_access(school_id, user, db, ['admin'])
    rec = get_record(db, school_id, 'students', record_id, True)
    rec.data = {**rec.data, 'archived': True}
    rec.version += 1
    audit(db, user, 'student.archive', rec.id)
    return output(rec)


@app.post(P+'/schools/{school_id}/guardians/{record_id}/consents')
def guardian_consent(school_id: str, record_id: str, body: dict, user: User = Depends(identity), db: DB = Depends(get_db)):
    school_access(school_id, user, db, ['admin'])
    rec = get_record(db, school_id, 'guardians', record_id)
    if type(body.get('granted')) is not bool or not body.get('source'):
        fail('VALIDATION', 'Consentement booléen et source requis.')
    rec.data = {**rec.data, 'consent': body['granted'], 'consent_source': body['source'], 'consent_at': now().isoformat()}
    for student_id in rec.data.get('student_ids', []):
        student = get_record(db, school_id, 'students', student_id)
        student.data = {**student.data, 'consent': body['granted'], 'guardian_phone': rec.data.get('phone', ''), 'guardian_name': rec.data.get('name', '')}
    audit(db, user, 'guardian.consent', rec.id)
    return output(rec)


@app.post(P+'/schools/{school_id}/notifications/{record_id}/read')
def read_notification(school_id: str, record_id: str, user: User = Depends(identity), db: DB = Depends(get_db)):
    school_access(school_id, user, db)
    rec = get_record(db, school_id, 'notifications', record_id)
    if rec.data.get('user_id') != user.id:
        fail('NOT_FOUND', 'Notification introuvable.', 404)
    rec.data = {**rec.data, 'read': True}
    return output(rec)


@app.delete(P+'/schools/{school_id}/teaching-assignments/{record_id}', status_code=204)
@app.delete(P+'/schools/{school_id}/timetable/{record_id}', status_code=204)
def remove_assignment(school_id: str, record_id: str, request: Request, user: User = Depends(identity), db: DB = Depends(get_db)):
    school_access(school_id, user, db, ['admin'])
    kind = request.url.path.split('/')[-2]
    rec = get_record(db, school_id, kind, record_id)
    rec.kind = 'archived-'+kind
    audit(db, user, kind+'.archive', rec.id)


@app.get(P+'/schools/{school_id}/{kind}')
def list_records(school_id: str, kind: str, request: Request, user: User = Depends(identity), db: DB = Depends(get_db)):
    school_access(school_id, user, db)
    check_kind(kind, user)
    actual_kind = 'charges' if kind == 'arrears' else kind
    records = rows(db, school_id, actual_kind)
    allowed = teacher_classes(db, user) if user.role == 'teacher' else None
    if user.role == 'teacher' and kind in ['guardians', 'teachers', 'messages', 'jobs']:
        fail('FORBIDDEN', 'Accès non autorisé.', 403)
    items = []
    for rec in records:
        d = output(rec)
        if allowed is not None and kind not in ['subjects', 'academic-years', 'terms', 'notifications'] and (rec.id if kind == 'classes' else d.get('class_id')) not in allowed:
            continue
        if user.role == 'teacher' and kind in ['assessments', 'assignments', 'grades', 'assignment-progress']:
            source = rec
            if kind in ['grades', 'assignment-progress']:
                source = get_record(db, school_id, 'assessments' if kind == 'grades' else 'assignments', d.get('parent_id'))
            if (source.data.get('class_id'), source.data.get('subject_id')) not in teacher_subjects(db, user):
                continue
        if kind == 'notifications' and d.get('user_id') != user.id:
            continue
        if any(d.get(key) != value for key, value in request.query_params.items() if key in LINKS):
            continue
        search = request.query_params.get('search', request.query_params.get('q', '')).lower()
        if search and search not in json.dumps(d, ensure_ascii=False).lower():
            continue
        if kind in ['charges', 'arrears']:
            d['remaining_balance'] = balance(db, school_id, rec)
            if kind == 'arrears' and d['remaining_balance'] <= 0:
                continue
        if kind == 'students' and user.role == 'teacher':
            d = {k: v for k, v in d.items() if k in ['id', 'first_name', 'last_name', 'class_id', 'school_id', 'version']}
        items.append(d)
    return page(items, request)


@app.post(P+'/schools/{school_id}/{kind}', status_code=201)
def create_record(school_id: str, kind: str, body: dict, user: User = Depends(identity), db: DB = Depends(get_db)):
    school_access(school_id, user, db)
    check_kind(kind, user, True)
    if kind not in ADMIN | {'charges', 'fee-definitions', 'attendance-sessions', 'assessments', 'assignments'}:
        fail('FORBIDDEN', 'Utilisez le parcours métier dédié.', 403)
    data = validate(db, school_id, kind, body)
    for protected in ['published', 'published_at', 'user_id', 'status']:
        data.pop(protected, None)
    if kind in PEDAGOGY:
        pedagogical_access(db, user, data, True)
    key = None
    if kind == 'enrollments':
        key = data['student_id']+':'+data['academic_year_id']
        student = get_record(db, school_id, 'students', data['student_id'])
        student.data = {**student.data, 'class_id': data['class_id']}
    if kind == 'attendance-sessions':
        key = data['class_id']+':'+data['date']+':'+str(data.get('slot', 'day'))
    if kind == 'teachers':
        password = data.pop('password', '')
        account_user = User(email=data['email'].lower().strip(), name=data['name'], school_id=school_id, role='teacher', password_hash=hash_password(password))
        db.add(account_user)
        db.flush()
        data['user_id'] = account_user.id
    rec = add(db, school_id, kind, data, key)
    if kind in ['teaching-assignments', 'timetable', 'assignments']:
        class_id = data.get('class_id')
        teacher_ids = {a.data.get('teacher_id') for a in rows(db, school_id, 'teaching-assignments') if a.data.get('class_id') == class_id}
        for teacher in rows(db, school_id, 'teachers'):
            if teacher.id in teacher_ids and teacher.data.get('user_id'):
                add(db, school_id, 'notifications', {'user_id': teacher.data['user_id'], 'class_id': class_id, 'title': 'Mise à jour de votre classe', 'body': data.get('title', 'Nouvelle affectation ou modification du planning.'), 'resource_id': rec.id, 'read': False})
    audit(db, user, kind+'.create', rec.id)
    return output(rec)


@app.get(P+'/schools/{school_id}/{kind}/{record_id}')
def detail(school_id: str, kind: str, record_id: str, user: User = Depends(identity), db: DB = Depends(get_db)):
    school_access(school_id, user, db)
    check_kind(kind, user)
    rec = get_record(db, school_id, kind, record_id)
    if kind == 'notifications' and rec.data.get('user_id') != user.id:
        fail('NOT_FOUND', 'Notification introuvable.', 404)
    if user.role == 'teacher':
        if kind in ['guardians', 'teachers', 'messages', 'jobs']:
            fail('FORBIDDEN', 'Accès non autorisé.', 403)
        if kind not in ['subjects', 'academic-years', 'terms']:
            source_data = rec.data
            if kind in ['grades', 'assignment-progress']:
                source_data = get_record(db, school_id, 'assessments' if kind == 'grades' else 'assignments', rec.data.get('parent_id')).data
            pedagogical_access(db, user, {'class_id': rec.id} if kind == 'classes' else source_data, kind in ['assessments', 'assignments', 'grades', 'assignment-progress'])
    result = output(rec)
    if kind == 'students' and user.role == 'teacher':
        result = {k: v for k, v in result.items() if k in ['id', 'first_name', 'last_name', 'class_id', 'school_id', 'version']}
    return result


@app.patch(P+'/schools/{school_id}/{kind}/{record_id}')
def update_record(school_id: str, kind: str, record_id: str, body: dict, user: User = Depends(identity), db: DB = Depends(get_db)):
    school_access(school_id, user, db)
    check_kind(kind, user, True)
    if kind not in ADMIN | {'fee-definitions', 'assessments', 'assignments'}:
        fail('FORBIDDEN', 'Modification interdite.', 403)
    rec = get_record(db, school_id, kind, record_id, True)
    if body.get('expected_version') != rec.version:
        fail('VERSION_CONFLICT', 'Version attendue requise ; rechargez les données.', 409)
    pedagogical_access(db, user, rec.data, True)
    if rec.data.get('published'):
        fail('LOCKED', 'Document publié.', 409)
    if any(k in body for k in ['password', 'password_hash', 'user_id', 'published', 'published_at']):
        fail('VALIDATION', 'Champ réservé au serveur.')
    if kind == 'enrollments' and any(k in body and body[k] != rec.data.get(k) for k in ['student_id', 'class_id', 'academic_year_id']):
        fail('VALIDATION', 'Une inscription historique ne peut pas être réaffectée.')
    rec.data = validate(db, school_id, kind, {**rec.data, **body}, rec.id)
    pedagogical_access(db, user, rec.data, True)
    if kind == 'teachers' and rec.data.get('user_id'):
        teacher_user = db.get(User, rec.data['user_id'])
        if teacher_user and teacher_user.school_id == school_id:
            teacher_user.name = rec.data['name']
            teacher_user.email = rec.data['email'].lower().strip()
            if 'active' in body:
                if type(body['active']) is not bool:
                    fail('VALIDATION', 'État actif booléen requis.')
                teacher_user.active = body['active']
    rec.version += 1
    audit(db, user, kind+'.update', rec.id)
    return output(rec)


def platform(user):
    if user.role != 'super_admin':
        fail('FORBIDDEN', 'Super administrateur requis.', 403)


@app.get(P+'/platform/dashboard')
@app.get(P+'/platform/usage')
def platform_dashboard(user: User = Depends(identity), db: DB = Depends(get_db)):
    platform(user)
    schools = list(db.scalars(select(School)))
    subscriptions = list(db.scalars(select(Record).where(Record.kind == 'subscriptions')))
    return {'schools': len(schools), 'active_schools': sum(s.active for s in schools), 'suspended_schools': sum(not s.active for s in schools), 'students': len(list(db.scalars(select(Record).where(Record.kind == 'students')))), 'revenue': sum(r.data.get('amount', 0) for r in db.scalars(select(Record).where(Record.kind == 'subscription-payments'))), 'active_subscriptions': sum(r.data.get('status') == 'active' for r in subscriptions), 'expired_subscriptions': sum(r.data.get('status') == 'expired' for r in subscriptions)}


@app.get(P+'/platform/schools')
def schools(request: Request, user: User = Depends(identity), db: DB = Depends(get_db)):
    platform(user)
    return page([{'id': s.id, 'name': s.name, 'active': s.active, 'status': 'active' if s.active else 'suspended', **s.data} for s in db.scalars(select(School).order_by(School.name))], request)


@app.post(P+'/platform/schools', status_code=201)
def create_school(body: dict, user: User = Depends(identity), db: DB = Depends(get_db)):
    platform(user)
    if not str(body.get('name', '')).strip():
        fail('VALIDATION', 'Nom obligatoire.')
    admin_email = str(body.get('admin_email', '')).lower().strip()
    admin_password = str(body.get('admin_password', ''))
    if admin_email and len(admin_password) < 10:
        fail('VALIDATION', 'Le mot de passe administrateur doit contenir au moins 10 caractères.')
    if admin_email and db.scalar(select(User).where(User.email == admin_email)):
        fail('CONFLICT', 'Cet email administrateur existe déjà.', 409)
    school = School(name=body['name'], data={k: v for k, v in body.items() if k not in ['id', 'name', 'active', 'status', 'admin_email', 'admin_password']})
    db.add(school)
    db.flush()
    admin = None
    if admin_email:
        admin = User(email=admin_email, name=body.get('admin_name') or 'Administrateur', role='admin', school_id=school.id, password_hash=hash_password(admin_password))
        db.add(admin)
        db.flush()
    return {'id': school.id, 'name': school.name, 'active': school.active, 'status': 'active', 'admin': public_user(admin) if admin else None}


@app.get(P+'/platform/schools/{school_id}')
def school_detail(school_id: str, user: User = Depends(identity), db: DB = Depends(get_db)):
    platform(user)
    school = db.get(School, school_id)
    if not school:
        fail('NOT_FOUND', 'École introuvable.', 404)
    return {**school.data, 'id': school.id, 'name': school.name, 'active': school.active}


@app.patch(P+'/platform/schools/{school_id}')
def school_update(school_id: str, body: dict, user: User = Depends(identity), db: DB = Depends(get_db)):
    platform(user)
    school = db.get(School, school_id)
    if not school:
        fail('NOT_FOUND', 'École introuvable.', 404)
    if 'name' in body:
        if not str(body['name']).strip():
            fail('VALIDATION', 'Nom obligatoire.')
        school.name = body['name']
    school.data = {**school.data, **{k: v for k, v in body.items() if k not in ['id', 'name', 'active', 'status']}}
    add(db, school_id, 'audit-events', {'actor_id': user.id, 'action': 'school.update'})
    return {**school.data, 'id': school.id, 'name': school.name, 'active': school.active}


@app.post(P+'/platform/schools/{school_id}/administrators', status_code=201)
def create_admin(school_id: str, body: dict, user: User = Depends(identity), db: DB = Depends(get_db)):
    platform(user)
    if not db.get(School, school_id):
        fail('NOT_FOUND', 'École introuvable.', 404)
    role = body.get('role', 'admin')
    if role not in ['admin', 'accountant']:
        fail('VALIDATION', 'Rôle invalide.')
    member = User(name=body['name'], email=body['email'].lower().strip(), password_hash=hash_password(body['password']), role=role, school_id=school_id)
    db.add(member)
    db.flush()
    return public_user(member)


@app.post(P+'/platform/schools/{school_id}/{action}')
def school_status(school_id: str, action: str, body: dict, user: User = Depends(identity), db: DB = Depends(get_db)):
    platform(user)
    school = db.get(School, school_id)
    if not school or action not in ['activate', 'suspend']:
        fail('NOT_FOUND', 'École ou action introuvable.', 404)
    if action == 'suspend' and not body.get('reason'):
        fail('VALIDATION', 'Motif de suspension obligatoire.')
    school.active = action == 'activate'
    add(db, school_id, 'audit-events', {'actor_id': user.id, 'action': 'school.'+action, 'reason': body.get('reason')})
    return {'id': school.id, 'name': school.name, 'active': school.active, 'status': 'active' if school.active else 'suspended'}


@app.get(P+'/platform/{kind}')
def platform_records(kind: str, request: Request, user: User = Depends(identity), db: DB = Depends(get_db)):
    platform(user)
    if kind not in ['plans', 'subscriptions']:
        fail('NOT_FOUND', 'Collection introuvable.', 404)
    return page([output(r) for r in db.scalars(select(Record).where(Record.kind == kind))], request)


@app.post(P+'/platform/{kind}', status_code=201)
def platform_create(kind: str, body: dict, user: User = Depends(identity), db: DB = Depends(get_db)):
    platform(user)
    if kind not in ['plans', 'subscriptions']:
        fail('NOT_FOUND', 'Collection introuvable.', 404)
    school_id = body.get('school_id')
    if kind == 'plans' and not school_id:
        school_id = db.scalar(select(School.id).order_by(School.id))
    if not school_id or not db.get(School, school_id):
        fail('VALIDATION', 'École existante requise.')
    if kind == 'subscriptions':
        plan = db.scalar(select(Record).where(Record.kind == 'plans', Record.id == body.get('plan_id')))
        if not plan:
            fail('VALIDATION', 'Plan existant requis.')
    if body.get('amount') is not None and (type(body['amount']) is not int or body['amount'] < 0):
        fail('VALIDATION', 'Montant invalide.')
    return output(add(db, school_id, kind, body))


@app.patch(P+'/platform/{kind}/{record_id}')
def platform_update(kind: str, record_id: str, body: dict, user: User = Depends(identity), db: DB = Depends(get_db)):
    platform(user)
    if kind not in ['plans', 'subscriptions']:
        fail('NOT_FOUND', 'Collection introuvable.', 404)
    rec = db.scalar(select(Record).where(Record.id == record_id, Record.kind == kind).with_for_update())
    if not rec:
        fail('NOT_FOUND', 'Ressource introuvable.', 404)
    if body.get('expected_version') != rec.version:
        fail('VERSION_CONFLICT', 'Rechargez la dernière version.', 409)
    allowed = {'name', 'amount', 'currency', 'student_limit'} if kind == 'plans' else {'plan_id', 'start_date', 'end_date', 'status'}
    changes = {k: v for k, v in body.items() if k in allowed}
    if 'amount' in changes and (type(changes['amount']) is not int or changes['amount'] < 0):
        fail('VALIDATION', 'Montant invalide.')
    if changes.get('status') and changes['status'] not in ['active', 'expired', 'cancelled', 'trial']:
        fail('VALIDATION', 'État invalide.')
    if changes.get('plan_id') and not db.scalar(select(Record).where(Record.kind == 'plans', Record.id == changes['plan_id'])):
        fail('NOT_FOUND', 'Plan introuvable.', 404)
    rec.data = {**rec.data, **changes}
    rec.version += 1
    add(db, rec.school_id, 'audit-events', {'actor_id': user.id, 'action': kind+'.update', 'resource_id': rec.id})
    return output(rec)


@app.post(P+'/platform/subscriptions/{record_id}/payments', status_code=201)
def subscription_payment(record_id: str, body: dict, request: Request, user: User = Depends(identity), db: DB = Depends(get_db)):
    platform(user)
    subscription = db.scalar(select(Record).where(Record.kind == 'subscriptions', Record.id == record_id))
    if not subscription:
        fail('NOT_FOUND', 'Abonnement introuvable.', 404)
    if type(body.get('amount')) is not int or body['amount'] <= 0:
        fail('VALIDATION', 'Montant entier positif requis.')
    def perform():
        rec = add(db, subscription.school_id, 'subscription-payments', {**body, 'subscription_id': record_id, 'actor_id': user.id, 'currency': 'XOF'})
        add(db, subscription.school_id, 'audit-events', {'actor_id': user.id, 'action': 'subscription.payment', 'resource_id': rec.id})
        return output(rec)
    return idempotent(db, subscription.school_id, 'subscription-payment:'+record_id, request, body, perform)
