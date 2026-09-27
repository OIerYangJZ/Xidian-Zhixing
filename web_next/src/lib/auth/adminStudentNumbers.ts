import 'server-only';

export function getAdminStudentNumbers() {
  return new Set(
    (process.env.ADMIN_STUDENT_NUMBERS || '')
      .split(',')
      .map((value) => value.trim().toUpperCase())
      .filter((value) => /^[A-Z0-9]{6,20}$/.test(value)),
  );
}
