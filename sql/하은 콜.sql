출근기록 등록
CALL check_in(2, 1, '2026-01-26', '2026-01-26 08:50:00');
CALL check_in(3, 1, '2026-01-27', '2026-01-27 09:10:00');

퇴근기록 등록
CALL check_out(2, '2026-01-26', '2026-01-26 23:20:00');    
CALL check_out(3, '2026-01-27', '2026-01-28 02:00:00');   

결근기록
CALL attendance_finalize_daily('2026-01-25');

출퇴근 기록 조회
-- 개인 조회
CALL attendance_record_select(2, NULL, '2026-01-01', '2026-01-31');
-- 부서 조회
CALL attendance_record_select(NULL, 1, '2026-01-01', '2026-01-31');
-- 기간 조회
CALL attendance_record_select(NULL, NULL, '2026-01-01', '2026-01-31');

초과근무 신청 등록
CALL overtime_record_create(3, '2026-01-27', '야간근무 포함 연장근무');

초과근무 승인
CALL overtime_record_approve(1, 2);

초과근무 반려
CALL overtime_record_approve(9, 1);
CALL overtime_record_reject(2, 3, '사전 신청 누락');

휴가신청 등록
CALL leave_request_create(2, 1, '2026-02-03', '2026-02-03', '개인사유', 1.0);
CALL leave_request_create(3, 1, '2026-02-04', '2026-02-04', '개인사유', 0.5);
CALL leave_request_create(3, 4, '2026-02-06', '2026-02-08', '예비군', 3);
CALL leave_request_create(2, 1, '2026-01-25', '2026-01-26', '개인사유', 2);

휴가신청 취소
CALL leave_request_cancel(1);

휴가 승인
CALL leave_request_approve(2, 1);

휴가 반려
CALL leave_request_reject(3, 1, '증빙 서류 미첨부');

근태 기록 수정
CALL attendance_record_update(3, 'LATE', NULL);

개인 근태 이력 조회
CALL attendance_record_find_by_emp(3);

특정 부서 사원들의 N월 근태 기록 조회
CALL attendance_record_find_by_dept_period(1, '2026-01-01', '2026-01-31');

부서 근태 통계
CALL attendance_stats_by_dept('2026-01-01', '2026-01-31');
