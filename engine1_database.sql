DROP DATABASE IF EXISTS attendance_db;
CREATE DATABASE attendance_db;
USE attendance_db;

CREATE TABLE faculty (
    faculty_id INT AUTO_INCREMENT PRIMARY KEY,
    faculty_name VARCHAR(100) NOT NULL,
    department VARCHAR(50) NOT NULL DEFAULT 'BCA',
    email VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE course (
    course_id INT AUTO_INCREMENT PRIMARY KEY,
    course_code VARCHAR(20) NOT NULL UNIQUE,
    course_title VARCHAR(120) NOT NULL,
    total_hours INT NOT NULL CHECK (total_hours > 0),
    credits INT NOT NULL CHECK (credits > 0)
);

CREATE TABLE student (
    usn VARCHAR(20) PRIMARY KEY,
    student_name VARCHAR(100) NOT NULL,
    semester INT NOT NULL CHECK (semester BETWEEN 1 AND 6),
    section CHAR(1) NOT NULL CHECK (section IN ('A', 'B', 'C')),
    email VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE attendance_session (
    session_id INT AUTO_INCREMENT PRIMARY KEY,
    course_id INT NOT NULL,
    faculty_id INT NOT NULL,
    session_date DATE NOT NULL,
    period_number INT NOT NULL CHECK (period_number BETWEEN 1 AND 8),
    CONSTRAINT fk_session_course FOREIGN KEY (course_id) REFERENCES course(course_id) ON DELETE CASCADE,
    CONSTRAINT fk_session_faculty FOREIGN KEY (faculty_id) REFERENCES faculty(faculty_id) ON DELETE CASCADE,
    CONSTRAINT uq_course_date_slot UNIQUE (course_id, session_date, period_number)
);

CREATE TABLE attendance_record (
    record_id INT AUTO_INCREMENT PRIMARY KEY,
    session_id INT NOT NULL,
    usn VARCHAR(20) NOT NULL,
    status ENUM('P', 'A', 'OD') NOT NULL,
    CONSTRAINT fk_record_session FOREIGN KEY (session_id) REFERENCES attendance_session(session_id) ON DELETE CASCADE,
    CONSTRAINT fk_record_student FOREIGN KEY (usn) REFERENCES student(usn) ON DELETE CASCADE,
    CONSTRAINT uq_session_student UNIQUE (session_id, usn)
);

CREATE TABLE condonation_record (
    condonation_id INT AUTO_INCREMENT PRIMARY KEY,
    usn VARCHAR(20) NOT NULL,
    course_id INT NOT NULL,
    leave_type ENUM('Medical', 'On-Duty') NOT NULL,
    approved_hours INT NOT NULL CHECK (approved_hours > 0),
    approval_date DATE NOT NULL,
    CONSTRAINT fk_cond_student FOREIGN KEY (usn) REFERENCES student(usn) ON DELETE CASCADE,
    CONSTRAINT fk_cond_course FOREIGN KEY (course_id) REFERENCES course(course_id) ON DELETE CASCADE
);

CREATE OR REPLACE VIEW view_attendance_shortage AS
SELECT 
    s.usn,
    s.student_name,
    c.course_code,
    COUNT(ar.record_id) AS total_held,
    SUM(CASE WHEN ar.status IN ('P', 'OD') THEN 1 ELSE 0 END) AS total_attended,
    ROUND((SUM(CASE WHEN ar.status IN ('P', 'OD') THEN 1 ELSE 0 END) * 100.0) / COUNT(ar.record_id), 2) AS percentage,
    CASE 
        WHEN (SUM(CASE WHEN ar.status IN ('P', 'OD') THEN 1 ELSE 0 END) * 100.0) / COUNT(ar.record_id) >= 75.0 THEN 'Safe'
        WHEN (SUM(CASE WHEN ar.status IN ('P', 'OD') THEN 1 ELSE 0 END) * 100.0) / COUNT(ar.record_id) >= 65.0 THEN 'Shortage Warning'
        ELSE 'Critical Detention'
    END AS status_badge,
    GREATEST(0, CEIL(((0.75 * COUNT(ar.record_id)) - SUM(CASE WHEN ar.status IN ('P', 'OD') THEN 1 ELSE 0 END)) / 0.25)) AS recovery_needed
FROM student s
CROSS JOIN course c
LEFT JOIN attendance_session ses ON c.course_id = ses.course_id
LEFT JOIN attendance_record ar ON ses.session_id = ar.session_id AND s.usn = ar.usn
GROUP BY s.usn, s.student_name, c.course_id, c.course_code
HAVING total_held > 0;


