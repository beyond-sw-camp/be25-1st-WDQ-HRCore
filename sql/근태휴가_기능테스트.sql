USE hr_system;

SELECT DATABASE();

-- ==============================================================
-- 근무유형 기준관리
-- ==============================================================


-- 근무유형 등록 (요구사항 코드 : WORK_TYPE_001)
INSERT INTO work_type (work_type_code, work_type_name, start_time, end_time, use_yn)
VALUES
('REG_0900_1800', '정규근무(09:00-18:00)', '09:00:00', '18:00:00', 'Y'),
('REMOTE', '재택근무(09:00-18:00)', '09:00:00', '18:00:00', 'Y'),
('BIZ_TRIP', '외근/출장(09:00-18:00)', '09:00:00', '18:00:00', 'Y'),
('SHORT', '단축근무', NULL, NULL, 'Y');

SELECT * FROM work_type;

-- 근무유형 수정 (요구사항 코드 : WORK_TYPE_002)
-- work_type_id=1 근유형명 수정 예시
UPDATE work_type
SET work_type_name = '정규근무(09:00-18:00)_수정',
    updated_at = NOW()
WHERE work_type_id = 1;

SELECT * FROM work_type WHERE work_type_id = 1;

-- 근무유형 활성/비활성 (요구사항 코드 : WORK_TYPE_003)
UPDATE work_type
SET use_yn = 'N',
    updated_at = NOW()
WHERE work_type_id = 4; -- 예: SHORT 비활성

SELECT * FROM work_type WHERE work_type_id = 4;

-- 근무유형 조회 (요구사항 코드 : WORK_TYPE_004)
-- 비활성 포함 전체 조회
SELECT
    work_type_id, work_type_code, work_type_name, start_time, end_time, use_yn, created_at, updated_at
FROM work_type;


-- ==============================================================
-- 근무시간 기준관
-- (현재 ERD/명세서 구조상 work_type의 start_time/end_time을 "근무시간 기준"으로 관리)
-- 별도 테이블 없음 → work_type 수정으로 처리
-- ==============================================================

-- 근무시간 기준 등록 (요구사항 코드: WORK_TIME_001)
-- 이미 WORK_TYPE_001에서 등록되므로, 별도 등록 예시는 "추가 근무유형"으로 보여줌
INSERT INTO work_type (work_type_code, work_type_name, start_time, end_time, use_yn)
VALUES ('REG_1000_1900', '정규근무(10:00-19:00)', '10:00:00', '19:00:00', 'Y');

SELECT * FROM work_type WHERE work_type_code = 'REG_1000_1900';

-- 근무시간 기준 수정 (요구사항 코드 : WORK_TIME_002)
UPDATE work_type
SET start_time = '09:30:00',
    end_time   = '18:30:00',
    updated_at = NOW()
WHERE work_type_code = 'REG_1000_1900';

SELECT * FROM work_type WHERE work_type_code = 'REG_1000_1900';

-- 근무시간 기준 조회 (요구사항 코드 : WORK_TIME_003)
SELECT
    work_type_id, work_type_code, work_type_name, start_time, end_time, use_yn
FROM work_type
ORDER BY work_type_id;

-- 초과근무 기준 등록 (요구사항 코드: WORK_TIME_004)
-- 따라서 DB에 기준을 저장하지 않고, 업무 규칙으로 고정(문서/로직)하여 overtime_record.overtime_type으로 기록함.
-- 예: 18~22 = EXTEND, 22~06 = NIGHT (저장 위치: overtime_record.overtime_type)
-- (DB 변경 없이 요구사항을 만족하는 방식)


-- =========================================================
-- 근태상태 코드관리
-- =========================================================

-- 근태상태코드 등록 (요구사항 코드: WORK_CON_001)
INSERT INTO attendance_status (status_code, status_name, use_yn)
VALUES
('NORMAL', '정상', 'Y'),
('LATE',   '지각', 'Y'),
('EARLY',  '조퇴', 'Y'),
('ABSENT', '결석', 'Y'),
('LEAVE',  '휴가', 'Y');

SELECT * FROM attendance_status;

-- 근태상태코드 수정 (요구사항 코드 : WORK_CON_002)
UPDATE attendance_status
SET status_name = '지각(수정)',
    updated_at = NOW()
WHERE status_code = 'LATE';

SELECT * FROM attendance_status WHERE status_code = 'LATE';

-- 근태상태코드 활성/비활성 (요구사항 코드 : WORK_CON_003)
UPDATE attendance_status
SET use_yn = 'N',
    updated_at = NOW()
WHERE status_code = 'EARLY';

SELECT * FROM attendance_status WHERE status_code = 'EARLY';

-- 근태상태코드 조회 (요구사항 코드 : WORK_CON_004)
SELECT
    status_id, status_code, status_name, use_yn, created_at, updated_at
FROM attendance_status;


-- =========================================================
-- 휴가기준관리
-- =========================================================

-- 휴가기준 등록 (요구사항 코드: VAC_001)
INSERT INTO leave_type (leave_type_name, annual_max_days, use_yn)
VALUES
('연차', 15, 'Y'),
('반차', NULL, 'Y'),
('병가', NULL, 'Y'),
('경조', NULL, 'Y'),
('공가', NULL, 'Y');

SELECT * FROM leave_type;

-- 휴가기준 수정 (요구사항 코드: VAC_002)
UPDATE leave_type
SET annual_max_days = 16,
    updated_at = NOW()
WHERE leave_type_name = '연차';

SELECT * FROM leave_type WHERE leave_type_name = '연차';

-- 휴가기준 조회 (요구사항 코드 : VAC_003)
-- 비활성 포함 전체 조회
SELECT
    leave_type_id, leave_type_name, annual_max_days, use_yn, created_at, updated_at
FROM leave_type;


-- =========================================================
-- 근태기록관리
-- =========================================================

-- 출퇴근 기록 등록 (요구사항 코드: INOUT_001)
-- 규칙: 출근이 기준시간(start_time)보다 늦으면 지각(LATE), 아니면 정상(NORMAL)

DROP PROCEDURE IF EXISTS hr_system.inout_check_in;

DELIMITER $$
CREATE PROCEDURE hr_system.inout_check_in (
    IN p_emp_id BIGINT,
    IN p_work_type_id BIGINT,
    IN p_work_date DATE,
    IN p_check_in_time DATETIME
)
BEGIN
    DECLARE v_start_time TIME;
    DECLARE v_status_id BIGINT;

    -- 에러 원문을 담을 변수
    DECLARE v_sqlstate CHAR(5) DEFAULT '00000';
    DECLARE v_errmsg TEXT DEFAULT '';

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_sqlstate = RETURNED_SQLSTATE, v_errmsg = MESSAGE_TEXT;
        ROLLBACK;
        -- CONCAT을 쓰지 말고 일단 에러 메시지만 그대로 보냅니다.
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_errmsg; 
    END;
    
    START TRANSACTION;

    SELECT start_time
      INTO v_start_time
      FROM work_type
     WHERE work_type_id = p_work_type_id;

    IF v_start_time IS NULL THEN
        SELECT status_id INTO v_status_id
          FROM attendance_status
         WHERE status_code = 'NORMAL';
    ELSEIF TIME(p_check_in_time) > v_start_time THEN
        SELECT status_id INTO v_status_id
          FROM attendance_status
         WHERE status_code = 'LATE';
    ELSE
        SELECT status_id INTO v_status_id
          FROM attendance_status
         WHERE status_code = 'NORMAL';
    END IF;

    INSERT INTO attendance_record (
        emp_id, work_type_id, status_id, work_date, check_in_time
    ) VALUES (
        p_emp_id, p_work_type_id, v_status_id, p_work_date, p_check_in_time
    );

    COMMIT;
END$$
DELIMITER ;


SELECT * FROM attendance_record 
WHERE emp_id = 1 AND work_date = '2026-01-19';

SHOW PROCEDURE STATUS WHERE Db = 'hr_system';

-- 퇴근 기록 등록 (요구사항 코드: INOUT_001 - 퇴근 처리)
-- 규칙: 퇴근이 기준시간(end_time)보다 빠르면 조퇴(EARLY)로 변경
DROP PROCEDURE IF EXISTS inout_check_out;
DELIMITER $$

CREATE PROCEDURE inout_check_out (
    IN p_emp_id BIGINT,
    IN p_work_date DATE,
    IN p_check_out_time DATETIME
)
BEGIN
    DECLARE v_end_time TIME;
    DECLARE v_early_status_id BIGINT;

    -- diagnostics
    DECLARE v_sqlstate CHAR(5) DEFAULT '00000';
    DECLARE v_errmsg TEXT;

    -- NOT FOUND(조회 결과 없음) 처리
    DECLARE EXIT HANDLER FOR NOT FOUND
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '퇴근 등록(INOUT_001) 실패: 해당 사원의 출근 기록이 없거나 기준시간을 찾을 수 없습니다.';
    END;

    -- 예외 처리(실제 DB 에러 메시지 그대로 전달)
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_sqlstate = RETURNED_SQLSTATE,
            v_errmsg   = MESSAGE_TEXT;
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_errmsg;
    END;

    START TRANSACTION;

    -- 해당 날짜 출근 기록의 work_type 기준 퇴근 시간 조회
    SELECT wt.end_time INTO v_end_time
    FROM attendance_record ar
    JOIN work_type wt ON ar.work_type_id = wt.work_type_id
    WHERE ar.emp_id = p_emp_id
      AND ar.work_date = p_work_date;

    -- 조퇴 status_id 조회
    SELECT status_id INTO v_early_status_id
    FROM attendance_status
    WHERE status_code = 'EARLY';

    -- 퇴근 시간 업데이트 + 조퇴 판정
    UPDATE attendance_record
    SET check_out_time = p_check_out_time,
        status_id = CASE
            WHEN v_end_time IS NOT NULL AND TIME(p_check_out_time) < v_end_time THEN v_early_status_id
            ELSE status_id
        END,
        updated_at = CURRENT_TIMESTAMP
    WHERE emp_id = p_emp_id
      AND work_date = p_work_date;

    -- 업데이트 대상이 없으면(출근 기록 없음 등) 강제로 에러
    IF ROW_COUNT() = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '퇴근 등록(INOUT_001) 실패: 업데이트할 출근 기록이 없습니다.';
    END IF;

    COMMIT;
END$$
DELIMITER ;

-- 테스트
CALL inout_check_out(1, '2026-01-19', '2026-01-19 17:30:00');
SELECT * FROM attendance_record WHERE emp_id = 1 AND work_date = '2026-01-19';



-- 출퇴근 기록 조회 (요구사항 코드 : INOUT_002)
-- 1) 개인 + 기간 조회
SELECT *
FROM attendance_record
WHERE emp_id = 1
  AND work_date BETWEEN '2026-01-01' AND '2026-01-31'
ORDER BY work_date;

-- 2) 부서 + 기간 조회
SELECT ar.*
FROM attendance_record ar
JOIN employee e ON ar.emp_id = e.emp_id
WHERE e.dept_id = 1
  AND ar.work_date BETWEEN '2026-01-01' AND '2026-01-31'
ORDER BY ar.work_date;


-- 초과근무 기록 등록 (요구사항 코드 : INOUT_003)
-- overtime_type 예시: EXTEND(연장), NIGHT(야간)
INSERT INTO overtime_record (
    emp_id, work_date, overtime_minutes, approval_status, overtime_type
) VALUES (
    1, '2026-01-19', 120, 'PENDING', 'EXTEND'
);

SELECT * FROM overtime_record WHERE emp_id = 1 AND work_date = '2026-01-19';




-- 초과근무 승인/반려 (요구사항 코드 : INOUT_003)
-- 승인/반려 모두: 대상 없으면(ROW_COUNT=0) 직접 에러

-- 승인(approved_at 기록)
UPDATE overtime_record
SET approval_status = 'APPROVED',
    approved_at = NOW(),
    updated_at = NOW()
WHERE overtime_id = 1;

-- 대상이 없었는지 확인
SELECT ROW_COUNT() AS affected_rows;

SELECT * FROM overtime_record WHERE overtime_id = 1;

-- 반려 예시
UPDATE overtime_record
SET approval_status = 'REJECTED',
    approved_at = NOW(),
    updated_at = NOW()
WHERE overtime_id = 1;

SELECT * FROM overtime_record WHERE overtime_id = 1;



-- 휴가 신청 등록 (요구사항 코드 : INOUT_004)
INSERT INTO leave_request (
    emp_id, leave_type_id, start_date, end_date, reason, use_days, approval_status
) VALUES (
    1,
    1, -- 연차
    '2026-02-03',
    '2026-02-03',
    '개인 사유',
    1.0,
    'PENDING'
);

SELECT * FROM leave_request WHERE emp_id = 1 ORDER BY leave_request_id DESC;

-- 휴가신청 취소
-- 승인 전(PENDING)일 때만 취소 가능
UPDATE leave_request
SET approval_status = 'CANCELED',
    updated_at = NOW()
WHERE leave_request_id = 1
  AND approval_status = 'PENDING';

SELECT * FROM leave_request WHERE leave_request_id = 1;

-- 휴가 승인(프로시저) (요구사항 코드 : INOUT_004) - 안정화버전
-- SQLEXCEPTION: GET DIAGNOSTICS로 원문 메시지 전달 (CONCAT 없음)
--  NOT FOUND: 신청 자체가 없을 때 명확히 에러
--  ROW_COUNT: PENDING이 아니면 승인 실패 처리

DROP PROCEDURE IF EXISTS approve_leave_request;

DELIMITER $$

CREATE PROCEDURE approve_leave_request (
    IN p_leave_request_id BIGINT
)
BEGIN
    DECLARE v_use_days DECIMAL(3,1);

    -- diagnostics
    DECLARE v_sqlstate CHAR(5) DEFAULT '00000';
    DECLARE v_errmsg TEXT;

    -- 조회 결과 없음(leave_request_id 자체가 없음)
    DECLARE EXIT HANDLER FOR NOT FOUND
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '휴가 승인(INOUT_004) 실패: 해당 휴가 신청을 찾을 수 없습니다.';
    END;

    -- DB 예외 원문 그대로 던지기
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_sqlstate = RETURNED_SQLSTATE,
            v_errmsg   = MESSAGE_TEXT;
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_errmsg;
    END;

    START TRANSACTION;

    -- use_days 확보 (없으면 NOT FOUND로 위 핸들러)
    SELECT use_days INTO v_use_days
    FROM leave_request
    WHERE leave_request_id = p_leave_request_id;

    -- PENDING -> APPROVED
    UPDATE leave_request
    SET approval_status = 'APPROVED',
        updated_at = CURRENT_TIMESTAMP
    WHERE leave_request_id = p_leave_request_id
      AND approval_status = 'PENDING';

    -- 이미 APPROVED/REJECTED/CANCELED면 업데이트 0건 -> 실패 처리
    IF ROW_COUNT() = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '휴가 승인(INOUT_004) 실패: PENDING 상태인 요청만 승인할 수 있습니다.';
    END IF;

    -- 승인 성공 시에만 이력 생성 (leave_request_id UNIQUE면 중복 방지)
    INSERT INTO leave_history (leave_request_id, use_days)
    VALUES (p_leave_request_id, v_use_days);

    COMMIT;
END$$
DELIMITER ;

CALL approve_leave_request(1);
SELECT * FROM leave_request WHERE leave_request_id = 1;
SELECT * FROM leave_history WHERE leave_request_id = 1;




-- 근태 기록 수정 (관리자 강제 수정) (요구사항 코드 : INOUT_005)
UPDATE attendance_record ar
JOIN attendance_status s ON s.status_code = 'ABSENT'
SET ar.status_id = s.status_id,
    ar.updated_at = CURRENT_TIMESTAMP
WHERE ar.emp_id = 1
  AND ar.work_date = '2026-01-20';

SELECT * FROM attendance_record WHERE emp_id = 1 AND work_date = '2026-01-20';




-- ==============================================================
-- CHECK (근태조회 및 통계)
-- ==============================================================
-- 개인별 근태 이력 통합 조회 (요구사항 코드 : CHECK_001)
SELECT
    e.emp_id,
    e.`name`,
    ar.work_date,
    wt.work_type_name,
    s.status_name,
    ar.check_in_time,
    ar.check_out_time
FROM attendance_record ar
JOIN employee e ON ar.emp_id = e.emp_id
JOIN work_type wt ON ar.work_type_id = wt.work_type_id
JOIN attendance_status s ON ar.status_id = s.status_id
WHERE ar.emp_id = 1
ORDER BY ar.work_date;

-- 사원별/부서별 근태 기록 조회(부서+기간)
SELECT
    d.dept_name,
    e.emp_id,
    e.`name`,
    ar.work_date,
    s.status_name
FROM attendance_record ar
JOIN employee e ON ar.emp_id = e.emp_id
LEFT JOIN department d ON e.dept_id = d.dept_id
JOIN attendance_status s ON ar.status_id = s.status_id
WHERE e.dept_id = 1
  AND ar.work_date BETWEEN '2026-01-01' AND '2026-01-31'
ORDER BY e.emp_id, ar.work_date;

-- 부서/개인 근태 통계 (부서별 지각/결석) (요구사항 코드 : CHECK_003)
SELECT
    d.dept_name,
    SUM(CASE WHEN s.status_code = 'LATE' THEN 1 ELSE 0 END)   AS late_count,
    SUM(CASE WHEN s.status_code = 'ABSENT' THEN 1 ELSE 0 END) AS absent_count,
    COUNT(*) AS total_days
FROM attendance_record ar
JOIN employee e ON ar.emp_id = e.emp_id
LEFT JOIN department d ON e.dept_id = d.dept_id
JOIN attendance_status s ON ar.status_id = s.status_id
WHERE ar.work_date BETWEEN '2026-01-01' AND '2026-01-31'
GROUP BY d.dept_id, d.dept_name
ORDER BY d.dept_name;






