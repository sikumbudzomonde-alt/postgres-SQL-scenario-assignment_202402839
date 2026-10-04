-- ============================================================
-- SCENARIO 3: Student Hostel Room Allocation
-- ============================================================

DROP TABLE IF EXISTS allocations CASCADE;
DROP TABLE IF EXISTS hostel_rooms CASCADE;

-- 1. Create tables and insert sample data
CREATE TABLE hostel_rooms (
    room_id SERIAL PRIMARY KEY,
    room_number VARCHAR(20) NOT NULL UNIQUE,
    available_beds INT NOT NULL CHECK (available_beds >= 0)
);

CREATE TABLE allocations (
    allocation_id SERIAL PRIMARY KEY,
    room_id INT REFERENCES hostel_rooms(room_id),
    student_number VARCHAR(20) NOT NULL,
    status VARCHAR(20) DEFAULT 'ALLOCATED' -- 'ALLOCATED' or 'CHECKED_OUT'
);

INSERT INTO hostel_rooms (room_number, available_beds) VALUES
('Block A - 101', 4),
('Block A - 102', 1),
('Block A - 103', 0);

-- 2. IF ELSIF ELSE demo
DO $$
DECLARE
    v_beds INT;
    v_room VARCHAR(20);
BEGIN
    SELECT room_number, available_beds INTO v_room, v_beds FROM hostel_rooms WHERE room_id = 2;
    
    IF v_beds = 0 THEN
        RAISE NOTICE 'Room % is full.', v_room;
    ELSIF v_beds = 1 THEN
        RAISE NOTICE 'Room % has one bed space left.', v_room;
    ELSE
        RAISE NOTICE 'Room % has several bed spaces left (% spaces).', v_room, v_beds;
    END IF;
END $$;

-- 3. WHILE loop and Numeric FOR loop
DO $$
DECLARE
    v_day INT := 1;
BEGIN
    -- WHILE loop
    WHILE v_day <= 3 LOOP
        RAISE NOTICE 'Hostel Inspection Day %', v_day;
        v_day := v_day + 1;
    END LOOP;

    -- FOR loop
    FOR check_num IN 1..3 LOOP
        RAISE NOTICE 'Room Check Number %', check_num;
    END LOOP;
END $$;

-- 4. Create allocate_room procedure
CREATE OR REPLACE PROCEDURE allocate_room(
    p_room_id INT,
    p_student_number VARCHAR(20)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_beds INT;
BEGIN
    IF p_student_number IS NULL OR TRIM(p_student_number) = '' THEN
        RAISE EXCEPTION 'Student number cannot be blank.';
    END IF;

    SELECT available_beds INTO v_beds 
    FROM hostel_rooms 
    WHERE room_id = p_room_id FOR UPDATE;

    IF v_beds IS NULL THEN
        RAISE EXCEPTION 'Room ID % does not exist.', p_room_id;
    ELSIF v_beds <= 0 THEN
        RAISE NOTICE 'Allocation failed: Room ID % is completely full.', p_room_id;
    ELSE
        UPDATE hostel_rooms 
        SET available_beds = available_beds - 1 
        WHERE room_id = p_room_id;

        INSERT INTO allocations (room_id, student_number, status)
        VALUES (p_room_id, p_student_number, 'ALLOCATED');

        RAISE NOTICE 'Bed allocated to student % in Room ID %.', p_student_number, p_room_id;
    END IF;
END;
$$;

-- 5. Call allocate_room (2 valid, 1 to full room)
CALL allocate_room(1, '20231001'); -- Valid
CALL allocate_room(2, '20231002'); -- Valid
CALL allocate_room(3, '20231003'); -- Full room

SELECT * FROM hostel_rooms;
SELECT * FROM allocations;

-- 6. Create check_out procedure
CREATE OR REPLACE PROCEDURE check_out(
    p_allocation_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
    v_room_id INT;
BEGIN
    SELECT status, room_id INTO v_status, v_room_id 
    FROM allocations 
    WHERE allocation_id = p_allocation_id FOR UPDATE;

    IF v_status IS NULL THEN
        RAISE NOTICE 'Allocation ID % not found.', p_allocation_id;
    ELSIF v_status = 'CHECKED_OUT' THEN
        RAISE NOTICE 'Allocation ID % is already checked out. Bed count unchanged.', p_allocation_id;
    ELSE
        UPDATE allocations SET status = 'CHECKED_OUT' WHERE allocation_id = p_allocation_id;
        UPDATE hostel_rooms SET available_beds = available_beds + 1 WHERE room_id = v_room_id;
        RAISE NOTICE 'Checkout complete for allocation ID %.', p_allocation_id;
    END IF;
END;
$$;

-- Call check_out twice
CALL check_out(1);
CALL check_out(1);

-- 7. Explicit cursor for full or nearly full rooms
DO $$
DECLARE
    cur_rooms CURSOR FOR 
        SELECT room_id, room_number, available_beds FROM hostel_rooms WHERE available_beds <= 1;
    v_rec RECORD;
BEGIN
    OPEN cur_rooms;
    LOOP
        FETCH cur_rooms INTO v_rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Full/Nearly Full Room -> % (Remaining Beds: %)', v_rec.room_number, v_rec.available_beds;
    END LOOP;
    CLOSE cur_rooms;
END $$;

-- 8. Attempt allocation with blank student number
DO $$
BEGIN
    CALL allocate_room(1, '   ');
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Caught expected exception: %', SQLERRM;
END $$;

-- 9. Final status query
SELECT * FROM hostel_rooms;
SELECT * FROM allocations;
