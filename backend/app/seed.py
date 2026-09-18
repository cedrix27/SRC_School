"""Explicit fictitious dataset. Password must be provided by the operator."""
import os
from sqlalchemy import select
from .db import Record, School, SessionLocal, User
from .main import add
from .migrate import migrate
from .security import hash_password


def seed():
    password = os.environ['DEMO_PASSWORD']
    migrate()
    with SessionLocal.begin() as db:
        if db.scalar(select(User).where(User.email == 'admin@src.demo')):
            print('Démonstration déjà initialisée.')
            return
        school = School(name='École Horizon — Démonstration', data={'demonstration': True, 'city': 'Ouagadougou'})
        second = School(name='École Baobab — Démonstration', data={'demonstration': True})
        db.add_all([school, second])
        db.flush()
        users = []
        for email, name, role, school_id in [('superadmin@src.demo', 'Direction SRC', 'super_admin', None), ('admin@src.demo', 'Administration Horizon', 'admin', school.id), ('comptable@src.demo', 'Comptabilité Horizon', 'accountant', school.id), ('enseignant@src.demo', 'Enseignant Horizon', 'teacher', school.id), ('admin2@src.demo', 'Administration Baobab', 'admin', second.id)]:
            user = User(email=email, name=name, role=role, school_id=school_id, password_hash=hash_password(password))
            db.add(user)
            users.append(user)
        db.flush()
        year = add(db, school.id, 'academic-years', {'name': '2026–2027', 'start_date': '2026-09-01', 'end_date': '2027-07-31'})
        term = add(db, school.id, 'terms', {'name': 'Premier trimestre', 'academic_year_id': year.id})
        classe = add(db, school.id, 'classes', {'name': '6e A', 'academic_year_id': year.id})
        add(db, school.id, 'classes', {'name': '5e A', 'academic_year_id': year.id})
        subject = add(db, school.id, 'subjects', {'name': 'Mathématiques', 'coefficient': '3'})
        teacher = add(db, school.id, 'teachers', {'name': 'Enseignant Horizon', 'email': 'enseignant@src.demo', 'user_id': users[3].id})
        add(db, school.id, 'teaching-assignments', {'teacher_id': teacher.id, 'class_id': classe.id, 'subject_id': subject.id, 'academic_year_id': year.id})
        add(db, school.id, 'timetable', {'teacher_id': teacher.id, 'class_id': classe.id, 'subject_id': subject.id, 'day': 'Lundi', 'start_time': '08:00', 'end_time': '10:00'})
        assessment = add(db, school.id, 'assessments', {'name': 'Devoir 1', 'class_id': classe.id, 'subject_id': subject.id, 'term_id': term.id, 'max_score': '20', 'coefficient': '1'})
        for index, (first, last) in enumerate([('Amina', 'Exemple'), ('Issa', 'Démo'), ('Mariam', 'Fictive'), ('Paul', 'Exemple')]):
            student = add(db, school.id, 'students', {'first_name': first, 'last_name': last, 'class_id': classe.id, 'guardian_name': 'Tuteur fictif', 'guardian_phone': '', 'consent': False})
            enrollment = add(db, school.id, 'enrollments', {'student_id': student.id, 'class_id': classe.id, 'academic_year_id': year.id}, student.id+':'+year.id)
            add(db, school.id, 'charges', {'student_id': student.id, 'amount': 75000, 'name': 'Scolarité démonstration', 'due_date': '2026-10-01'})
            add(db, school.id, 'grades', {'parent_id': assessment.id, 'class_id': classe.id, 'student_id': student.id, 'enrollment_id': enrollment.id, 'score': str(12+index)}, assessment.id+':'+enrollment.id)
        add(db, school.id, 'assignments', {'title': 'Exercices sur les fractions', 'class_id': classe.id, 'subject_id': subject.id, 'due_date': '2026-09-22', 'body': 'Résoudre les exercices 1 à 5.'})
        add(db, second.id, 'students', {'first_name': 'Élève', 'last_name': 'Autre école'})
        print('Démonstration initialisée. Comptes : superadmin@src.demo, admin@src.demo, comptable@src.demo, enseignant@src.demo, admin2@src.demo.')


if __name__ == '__main__':
    seed()
