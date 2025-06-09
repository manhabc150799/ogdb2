SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

CREATE FUNCTION public.addcustomer(type boolean) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare
	id int;
begin
	INSERT INTO Customer(CustomerType)
	VALUES(type)
	RETURNING customer_id INTO id;
	RETURN id;
end;
$$;


ALTER FUNCTION public.addcustomer(type boolean) OWNER TO postgres;

CREATE PROCEDURE public.addstudent(IN in_mssv integer, IN in_name character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
	id int;
BEGIN
	INSERT INTO Customer(customertype)
	VALUES (false)
	RETURNING customer_id INTO id;
	INSERT INTO Student(customer_id, fullname, mssv)
	VALUES (id, in_name, in_mssv);
END;
$$;


ALTER PROCEDURE public.addstudent(IN in_mssv integer, IN in_name character varying) OWNER TO postgres;

CREATE FUNCTION public.addvisitor() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
declare
	id int;
	ticket varchar;
begin
	INSERT INTO Customer(CustomerType)
	VALUES(true)
	RETURNING customer_id INTO id;
	INSERT INTO Visitor(customer_id)
	VALUES(id)
	RETURNING ticketid INTO ticket;
	RETURN ticket;
end;
$$;


ALTER FUNCTION public.addvisitor() OWNER TO postgres;

CREATE FUNCTION public.check_one_vehicle_per_student() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Kiểm tra xem có xe nào của student vẫn đang được gửi

    IF EXISTS (
		SELECT 1
		FROM park JOIN vehicle USING(vehicle_id)
		WHERE customer_id = (SELECT customer_id
							FROM vehicle n WHERE n.vehicle_id = NEW.vehicle_id)
			AND exit_time IS NULL
    ) THEN
        -- Nếu có, báo lỗi và không cho phép chèn bản ghi mới
        RAISE EXCEPTION 'Mỗi sinh viên chỉ được gửi một xe tại một thời điểm';
    END IF;
    -- Nếu không có xe nào đang gửi, cho phép chèn bản ghi mới
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_one_vehicle_per_student() OWNER TO postgres;

CREATE FUNCTION public.delete_student() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
BEGIN
	DELETE FROM customer WHERE customer_id = OLD.customer_id;
	RETURN OLD;
END;
$$;


ALTER FUNCTION public.delete_student() OWNER TO postgres;

CREATE FUNCTION public.delete_visitor() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
BEGIN
	DELETE FROM customer WHERE customer_id = OLD.customer_id;
	RETURN OLD;
END;
$$;


ALTER FUNCTION public.delete_visitor() OWNER TO postgres;

CREATE FUNCTION public.getavailablespots(input_parkinglotid integer, input_size integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
	DECLARE
		spot_id int;
	BEGIN
		SELECT parkingspot_id INTO spot_id
		FROM parking_spot p
		WHERE
			parkinglot_id = input_parkinglotid
			AND input_size = (SELECT size FROM spot_type s WHERE p.spottype_id = s.spottype_id)
			AND NOT occupied
		ORDER BY parkingspot_id
		LIMIT 1;
		RETURN spot_id;
	END;
$$;


ALTER FUNCTION public.getavailablespots(input_parkinglotid integer, input_size integer) OWNER TO postgres;

CREATE FUNCTION public.getcustomerid(input_mssv character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
	customer_id INT;
BEGIN
	IF length(input_mssv) = 8 THEN
		SELECT customer_id INTO customer_id
		FROM student WHERE mssv = input_mssv;
	ELSE
		SELECT customer_id INTO customer_id
		FROM visitor WHERE ticketid::varchar = input_mssv;
	END IF;
	If customer_id IS NOT NULL then
			RETURN customer_id;
		ELSE
			RAISE 'Khong ton tai mssv';
		END IF;
END;
$$;


ALTER FUNCTION public.getcustomerid(input_mssv character varying) OWNER TO postgres;

CREATE FUNCTION public.getparkinglotid(input_staffid integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
	parkinglot int;
BEGIN
	SELECT parkinglot_id INTO parkinglot FROM staff where staff_id = input_staffid;
	RETURN parkinglot;
END;
$$;


ALTER FUNCTION public.getparkinglotid(input_staffid integer) OWNER TO postgres;

CREATE FUNCTION public.getvehicleid(string character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$-- Hiện tại đang sai vì vehicle không còn là những xe đang đỗ
DECLARE
    o_vehicle_id INT;
BEGIN
-- Nếu là mssv
    IF length(string) = 8 THEN
        SELECT vehicle_id INTO o_vehicle_id
        FROM vehicle
        WHERE customer_id IN (
            SELECT customer_id
            FROM student
            WHERE mssv = string
        );
-- Nếu là uuid
	ELSE
		SELECT vehicle_id INTO o_vehicle_id
		FROM vehicle
		WHERE customer_id IN (
			SELECT customer_id
			FROM visitor
			WHERE ticketid::varchar = string
		);
	END IF;
	IF o_vehicle_id IS NOT NULL THEN
    RETURN o_vehicle_id;
	ELSE raise 'Không tìm thấy!';
	END IF;
END;
$$;


ALTER FUNCTION public.getvehicleid(string character varying) OWNER TO postgres;

CREATE FUNCTION public.is_occuppied() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	BEGIN
		UPDATE parking_spot
		SET occupied = TRUE
		WHERE parkingspot_id = new.parkingspot_id;
		RETURN NEW;
	END;
$$;


ALTER FUNCTION public.is_occuppied() OWNER TO postgres;

CREATE FUNCTION public.payin_log_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
   INSERT INTO transaction (customer_id, amount, time, transaction_type)
   VALUES (getCustomerId(NEW.mssv),
		   abs(OLD.balance - NEW.balance),
		   current_timestamp,
		   (OLD.balance - NEW.balance) < 0);
   RETURN NEW;
END;
$$;





ALTER FUNCTION public.payin_log_func() OWNER TO postgres;

CREATE FUNCTION public.trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
   INSERT INTO transaction (mssv, amount, time, transaction_type)
   VALUES (NEW.mssv, NEW.balance - OLD.balance, 1);
   RETURN NEW;
END;
$$;


ALTER FUNCTION public.trigger_function() OWNER TO postgres;

CREATE FUNCTION public.update_capacity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
BEGIN
	UPDATE parking_lot
	SET capacity = capacity + 1
	WHERE parkinglot_id = OLD.parkinglot_id;
	RETURN OLD;
END;
$$;


ALTER FUNCTION public.update_capacity() OWNER TO postgres;

CREATE FUNCTION public.update_parking_spot_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Kiểm tra nếu exit_time được đặt (từ NULL sang một giá trị không NULL)
    IF NEW.exit_time IS NOT NULL AND OLD.exit_time IS NULL THEN
        -- Cập nhật bảng parking_spot, đặt occupied thành FALSE
		RAISE NOTICE 'REAL';
        UPDATE parking_spot
        SET occupied = FALSE
        WHERE parkingspot_id = NEW.parkingspot_id;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_parking_spot_status() OWNER TO postgres;

CREATE PROCEDURE public.vehicle_out(IN string character varying)
    LANGUAGE plpgsql
    AS $$DECLARE
	x int;
BEGIN
	IF length(string) = 8 THEN
		UPDATE park
		SET exit_time = now()
		FROM vehicle, student
		WHERE park.exit_time IS NULL
		AND park.vehicle_id = vehicle.vehicle_id
		AND vehicle.customer_id = getCustomerId(string);
	ELSE
		-- Dành cho vé
		UPDATE park
		SET exit_time = now()
		WHERE park.vehicle_id = (SELECT vehicle_id FROM vehicle WHERE customer_id = getCustomerId(string))
		RETURNING parkId INTO x;
		IF (x IS NULL) THEN RAISE 'Vé không đúng';
		END IF;
	END IF;
END;
$$;


ALTER PROCEDURE public.vehicle_out(IN string character varying) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

CREATE TABLE public.application (
    id integer NOT NULL,
    fullname character(50) NOT NULL,
    datebirth date NOT NULL,
    email character(50) NOT NULL
);


ALTER TABLE public.application OWNER TO postgres;

CREATE SEQUENCE public.application_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.application_id_seq OWNER TO postgres;

ALTER SEQUENCE public.application_id_seq OWNED BY public.application.id;


CREATE TABLE public.customer (
    customer_id integer NOT NULL,
    customertype boolean NOT NULL
);


ALTER TABLE public.customer OWNER TO postgres;

CREATE SEQUENCE public.customer_customer_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.customer_customer_id_seq OWNER TO postgres;

ALTER SEQUENCE public.customer_customer_id_seq OWNED BY public.customer.customer_id;


CREATE SEQUENCE public.customer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.customer_id_seq OWNER TO postgres;

CREATE TABLE public.vehicle (
    vehicle_id integer NOT NULL,
    vehicletype_id integer,
    license_plate character varying(15),
    color character varying(15),
    customer_id integer
);


ALTER TABLE public.vehicle OWNER TO postgres;

CREATE TABLE public.park (
    park_id integer NOT NULL,
    vehicle_id integer NOT NULL,
    parkingspot_id integer NOT NULL,
    entry_time timestamp without time zone DEFAULT now() NOT NULL,
    exit_time timestamp without time zone
);


ALTER TABLE public.park OWNER TO postgres;

CREATE SEQUENCE public.park_park_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.park_park_id_seq OWNER TO postgres;

ALTER SEQUENCE public.park_park_id_seq OWNED BY public.park.park_id;


CREATE TABLE public.parking_lot (
    parkinglot_id integer NOT NULL,
    name character varying(16) NOT NULL,
    capacity integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.parking_lot OWNER TO postgres;

CREATE SEQUENCE public.parking_lot_parkinglot_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.parking_lot_parkinglot_id_seq OWNER TO postgres;

ALTER SEQUENCE public.parking_lot_parkinglot_id_seq OWNED BY public.parking_lot.parkinglot_id;


CREATE TABLE public.parking_spot (
    parkingspot_id integer NOT NULL,
    spottype_id integer NOT NULL,
    parkinglot_id integer NOT NULL,
    occupied boolean DEFAULT false NOT NULL
);


ALTER TABLE public.parking_spot OWNER TO postgres;

CREATE SEQUENCE public.parking_spot_parkingspot_id_seq
    AS integer
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.parking_spot_parkingspot_id_seq OWNER TO postgres;

ALTER SEQUENCE public.parking_spot_parkingspot_id_seq OWNED BY public.parking_spot.parkingspot_id;


CREATE TABLE public.spot_type (
    spottype_id integer NOT NULL,
    size smallint NOT NULL
);


ALTER TABLE public.spot_type OWNER TO postgres;

CREATE SEQUENCE public.spot_type_spottype_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.spot_type_spottype_id_seq OWNER TO postgres;

ALTER SEQUENCE public.spot_type_spottype_id_seq OWNED BY public.spot_type.spottype_id;


CREATE TABLE public.staff (
    staff_id integer NOT NULL,
    fullname character varying(256) NOT NULL,
    password character varying DEFAULT '12345678'::character varying NOT NULL,
    parkinglot_id integer NOT NULL,
    CONSTRAINT staff_password_check CHECK ((length((password)::text) >= 8))
);


ALTER TABLE public.staff OWNER TO postgres;

CREATE SEQUENCE public.staff_staff_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.staff_staff_id_seq OWNER TO postgres;

ALTER SEQUENCE public.staff_staff_id_seq OWNED BY public.staff.staff_id;


CREATE TABLE public.student (
    customer_id integer NOT NULL,
    fullname character varying(255) NOT NULL,
    mssv character varying(8) NOT NULL,
    balance integer DEFAULT 0 NOT NULL,
    password character varying DEFAULT '123456'::character varying NOT NULL
);


ALTER TABLE public.student OWNER TO postgres;

CREATE TABLE public.transaction (
    transaction_id integer NOT NULL,
    amount integer NOT NULL,
    "time" timestamp without time zone DEFAULT now() NOT NULL,
    transaction_type boolean NOT NULL,
    customer_id integer NOT NULL
);


ALTER TABLE public.transaction OWNER TO postgres;

CREATE SEQUENCE public.transaction_transaction_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.transaction_transaction_id_seq OWNER TO postgres;

ALTER SEQUENCE public.transaction_transaction_id_seq OWNED BY public.transaction.transaction_id;


CREATE TABLE public.vehicle_type (
    vehicletype_id integer NOT NULL,
    name character varying(15) NOT NULL,
    price integer DEFAULT 0 NOT NULL,
    size smallint NOT NULL,
    CONSTRAINT vehicle_type_price_check CHECK ((price >= 0))
);


ALTER TABLE public.vehicle_type OWNER TO postgres;

CREATE SEQUENCE public.vehicle_type_vehicletype_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.vehicle_type_vehicletype_id_seq OWNER TO postgres;

ALTER SEQUENCE public.vehicle_type_vehicletype_id_seq OWNED BY public.vehicle_type.vehicletype_id;


CREATE SEQUENCE public.vehicle_vehicle_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.vehicle_vehicle_id_seq OWNER TO postgres;

ALTER SEQUENCE public.vehicle_vehicle_id_seq OWNED BY public.vehicle.vehicle_id;


CREATE TABLE public.visitor (
    customer_id integer NOT NULL,
    ticketid uuid DEFAULT gen_random_uuid() NOT NULL
);




ALTER TABLE public.visitor OWNER TO postgres;

ALTER TABLE ONLY public.application ALTER COLUMN id SET DEFAULT nextval('public.application_id_seq'::regclass);


ALTER TABLE ONLY public.customer ALTER COLUMN customer_id SET DEFAULT nextval('public.customer_customer_id_seq'::regclass);


ALTER TABLE ONLY public.vehicle ALTER COLUMN vehicle_id SET DEFAULT nextval('public.vehicle_vehicle_id_seq'::regclass);


ALTER TABLE ONLY public.park ALTER COLUMN park_id SET DEFAULT nextval('public.park_park_id_seq'::regclass);


ALTER TABLE ONLY public.parking_lot ALTER COLUMN parkinglot_id SET DEFAULT nextval('public.parking_lot_parkinglot_id_seq'::regclass);


ALTER TABLE ONLY public.parking_spot ALTER COLUMN parkingspot_id SET DEFAULT nextval('public.parking_spot_parkingspot_id_seq'::regclass);


ALTER TABLE ONLY public.spot_type ALTER COLUMN spottype_id SET DEFAULT nextval('public.spot_type_spottype_id_seq'::regclass);


ALTER TABLE ONLY public.staff ALTER COLUMN staff_id SET DEFAULT nextval('public.staff_staff_id_seq'::regclass);


ALTER TABLE ONLY public.transaction ALTER COLUMN transaction_id SET DEFAULT nextval('public.transaction_transaction_id_seq'::regclass);


ALTER TABLE ONLY public.vehicle_type ALTER COLUMN vehicletype_id SET DEFAULT nextval('public.vehicle_type_vehicletype_id_seq'::regclass);


COPY public.application (id, fullname, datebirth, email) FROM stdin;
\.


COPY public.customer (customer_id, customertype) FROM stdin;
1	f
2	f
3	f
4	f
5	f
6	t
7	t
8	t
9	t
10	t
11	t
15	t
16	f
17	f
20	f
22	f
24	t
25	t
26	t
27	t
28	t
31	t
32	f
34	t
35	t
36	t
\.


COPY public.vehicle (vehicle_id, vehicletype_id, license_plate, color, customer_id) FROM stdin;
67	1	37a	red	22
72	2	\N	blue	22
74	1	37a1	red	4
75	2	\N	brown	22
76	3	37a	red	22
77	3	37aaa	red	34
78	3	37A225	red	35
79	1	red	37a	22
\.


COPY public.park (park_id, vehicle_id, parkingspot_id, entry_time, exit_time) FROM stdin;
52	77	2051	2024-05-31 09:07:54.438975	2024-05-31 09:09:27.270994
53	78	2051	2024-05-31 09:22:19.139139	2024-05-31 09:29:14.855839
54	79	1501	2024-05-31 09:30:21.983113	2024-05-31 09:32:54.269658
61	67	1501	2024-05-31 10:14:56.292069	2024-05-31 15:51:06.123483
62	67	1501	2024-05-31 16:10:00.280164	\N
34	67	1502	2024-05-25 12:24:01.498882	2024-05-31 08:57:14.418882
36	67	1502	2024-05-25 12:34:32.08139	2024-05-31 08:57:14.418882
40	67	1501	2024-05-25 12:52:57.018588	2024-05-31 08:57:14.418882
41	72	1501	2024-05-25 13:16:09.965423	2024-05-31 08:57:14.418882
42	72	1501	2024-05-25 13:17:11.695253	2024-05-31 08:57:14.418882
44	67	1501	2024-05-26 16:31:24.044915	2024-05-31 08:57:14.418882
45	74	1502	2024-05-26 16:32:50.827904	2024-05-31 08:57:14.418882
46	72	1501	2024-05-26 16:45:43.278512	2024-05-31 08:57:14.418882
48	75	1501	2024-05-26 22:43:48.71691	2024-05-31 08:57:14.418882
49	67	2051	2024-05-27 14:21:53.921852	2024-05-31 08:57:14.418882
50	67	2051	2024-05-27 14:24:53.631101	2024-05-31 08:57:14.418882
51	76	2051	2024-05-27 14:31:27.827354	2024-05-31 08:57:14.418882
\.


COPY public.parking_lot (parkinglot_id, name, capacity) FROM stdin;
1	B1	300
3	D35	600
4	C7	800
\.


COPY public.parking_spot (parkingspot_id, spottype_id, parkinglot_id, occupied) FROM stdin;
2121	3	4	f
2122	3	4	f
2123	3	4	f
2124	3	4	f
2125	3	4	f
2126	3	4	f
2127	3	4	f
2128	3	4	f
1502	1	4	f
1501	1	4	t
2129	3	4	f
2130	3	4	f
2162	3	4	f
2163	3	4	f
2164	3	4	f
2165	3	4	f
2166	3	4	f
2167	3	4	f
2168	3	4	f
2169	3	4	f
2170	3	4	f
2171	3	4	f
2051	3	4	f
2172	3	4	f
2173	3	4	f
@@ -1154,231 +1154,231 @@ COPY public.parking_spot (parkingspotid, spottypeid, parkinglotid, occupied) FRO
2022	2	4	f
2023	2	4	f
2024	2	4	f
2025	2	4	f
2026	2	4	f
2027	2	4	f
2028	2	4	f
2029	2	4	f
2030	2	4	f
2031	2	4	f
2032	2	4	f
2033	2	4	f
2034	2	4	f
2035	2	4	f
2293	3	4	f
2294	3	4	f
2295	3	4	f
2296	3	4	f
2297	3	4	f
2298	3	4	f
2299	3	4	f
2300	3	4	f
\.


COPY public.spot_type (spottype_id, size) FROM stdin;
1	1
2	1
3	2
4	2
\.


COPY public.staff (staff_id, fullname, password, parkinglot_id) FROM stdin;
2	Nguyễn Nhân Viên	12345678	1
3	Nguyễn Đức Quân	12345678	4
5	Nguyễn Đức Nghĩa	12345678	4
\.


COPY public.student (customer_id, fullname, mssv, balance, password) FROM stdin;
5	Pham Thi Mai Anh\n	20225884	87000	123456
4	Tran Minh Tuan	20225883	0	123456
36	Ngô Anh Tú	20220029	100000	123456
22	Nguyễn Văn Mạnh	20225880	146000	123456
3	Le Van Anh	20225882	100000	123456
17	Nguyễn Văn Dũng	20225879	100000	123456
20	Nguyễn Hồng Nhung	20221555	100000	123456
32	Văn Đức Cường	20220021	100000	123456
\.


COPY public.transaction (transaction_id, amount, "time", transaction_type, customer_id) FROM stdin;
51	-3000	2024-05-31 10:14:56.292069	t	22
52	50000	2024-05-31 10:22:04.041037	f	22
53	23000	2024-05-31 10:24:03.542639	t	22
54	3000	2024-05-31 16:10:00.280164	f	22
55	20000	2024-06-01 10:08:38.238722	t	22
56	20000	2024-06-01 10:10:04.135523	t	22
57	100000	2024-06-01 10:12:25.073966	t	36
\.


COPY public.vehicle_type (vehicletype_id, name, price, size) FROM stdin;
1	Xe máy	3000	1
2	Xe đạp	2000	1
3	Ô tô	5000	2
\.


COPY public.visitor (customer_id, ticketid) FROM stdin;
8	50e27aeb-f96a-49ab-a673-f7bfbb63717b
9	d4cf6761-34e8-4cf5-9083-d197ac563bca
10	d1a86334-898f-4d86-9a1f-156e84d28101
11	0ef8665b-2c8d-4653-ad7d-a08807b6ed42
15	5749c5b8-c8bc-468b-b578-5cbd7831f6bf
24	325cc84e-fad2-4d7f-a420-93b2592c913e
25	34c54b78-7c77-416c-b6df-302409d341b5
26	f2975886-45ae-44a6-84e2-3785d4da6ac9
27	eeb3670d-6942-4993-9cc5-34a57e858d11
28	9d6be76d-8ccf-446e-b23d-9b72e67622cb
31	373b4f8e-395b-4327-a43f-1ca05928061d
34	3d065c0d-00f2-43b5-a00c-0b2567e0273c
35	f12d390f-4c30-4716-912c-d098ed1f48f7
\.


SELECT pg_catalog.setval('public.application_id_seq', 1, true);


SELECT pg_catalog.setval('public.customer_customer_id_seq', 36, true);


SELECT pg_catalog.setval('public.customer_id_seq', 1, false);


SELECT pg_catalog.setval('public.park_park_id_seq', 62, true);


SELECT pg_catalog.setval('public.parking_lot_parkinglot_id_seq', 2, true);


SELECT pg_catalog.setval('public.parking_spot_parkingspot_id_seq', 2300, true);


SELECT pg_catalog.setval('public.spot_type_spottype_id_seq', 1, false);


SELECT pg_catalog.setval('public.staff_staff_id_seq', 6, true);


SELECT pg_catalog.setval('public.transaction_transaction_id_seq', 57, true);


SELECT pg_catalog.setval('public.vehicle_type_vehicletype_id_seq', 1, false);


SELECT pg_catalog.setval('public.vehicle_vehicle_id_seq', 81, true);


ALTER TABLE ONLY public.application
    ADD CONSTRAINT application_pkey PRIMARY KEY (id);


ALTER TABLE ONLY public.customer
    ADD CONSTRAINT customer_pkey PRIMARY KEY (customer_id);


ALTER TABLE ONLY public.park
    ADD CONSTRAINT park_pkey PRIMARY KEY (park_id);


ALTER TABLE ONLY public.parking_lot
    ADD CONSTRAINT parking_lot_pkey PRIMARY KEY (parkinglot_id);


ALTER TABLE ONLY public.parking_spot
    ADD CONSTRAINT parking_spot_pkey PRIMARY KEY (parkingspot_id);


ALTER TABLE ONLY public.spot_type
    ADD CONSTRAINT spot_type_pkey PRIMARY KEY (spottype_id);


ALTER TABLE ONLY public.staff
    ADD CONSTRAINT staff_pkey PRIMARY KEY (staff_id);


ALTER TABLE ONLY public.student
    ADD CONSTRAINT student_mssv_key UNIQUE (mssv);


ALTER TABLE public.student
    ADD CONSTRAINT student_password_check CHECK ((length((password)::text) >= 6)) NOT VALID;


ALTER TABLE ONLY public.student
    ADD CONSTRAINT student_pkey PRIMARY KEY (mssv);


ALTER TABLE ONLY public.vehicle
    ADD CONSTRAINT vehicle_pkey PRIMARY KEY (vehicle_id);


ALTER TABLE ONLY public.vehicle_type
    ADD CONSTRAINT vehicle_type_pkey PRIMARY KEY (vehicletype_id);


ALTER TABLE ONLY public.visitor
    ADD CONSTRAINT visitor_pkey PRIMARY KEY (ticketid);


CREATE TRIGGER auto_update_occupied AFTER INSERT ON public.park FOR EACH ROW WHEN ((new.exit_time IS NULL)) EXECUTE FUNCTION public.is_occuppied();


CREATE TRIGGER delete_student AFTER DELETE ON public.student FOR EACH ROW EXECUTE FUNCTION public.delete_student();


CREATE TRIGGER delete_visitor AFTER DELETE ON public.visitor FOR EACH ROW EXECUTE FUNCTION public.delete_visitor();


CREATE TRIGGER payin_log AFTER UPDATE OF balance ON public.student FOR EACH ROW EXECUTE FUNCTION public.payin_log_func();


CREATE TRIGGER set_exit_time_trigger AFTER UPDATE OF exit_time ON public.park FOR EACH ROW WHEN (((old.exit_time IS NULL) AND (new.exit_time IS NOT NULL))) EXECUTE FUNCTION public.update_parking_spot_status();


CREATE TRIGGER trigger_check_one_vehicle_per_student BEFORE INSERT ON public.park FOR EACH ROW EXECUTE FUNCTION public.check_one_vehicle_per_student();


CREATE TRIGGER update_capacity AFTER INSERT ON public.parking_spot FOR EACH ROW EXECUTE FUNCTION public.update_capacity();


ALTER TABLE ONLY public.transaction
    ADD CONSTRAINT "Customer" FOREIGN KEY (customer_id) REFERENCES public.customer(customer_id) NOT VALID;


ALTER TABLE ONLY public.park
    ADD CONSTRAINT park_parkingspotid_fkey FOREIGN KEY (parkingspot_id) REFERENCES public.parking_spot(parkingspot_id);


ALTER TABLE ONLY public.park
    ADD CONSTRAINT park_vehicleid_fkey FOREIGN KEY (vehicle_id) REFERENCES public.vehicle(vehicle_id) NOT VALID;


ALTER TABLE ONLY public.parking_spot
    ADD CONSTRAINT parking_spot_parkinglotid_fkey FOREIGN KEY (parkinglot_id) REFERENCES public.parking_lot(parkinglot_id);


ALTER TABLE ONLY public.parking_spot
    ADD CONSTRAINT parking_spot_spottypeid_fkey FOREIGN KEY (spottype_id) REFERENCES public.spot_type(spottype_id);


ALTER TABLE ONLY public.staff
    ADD CONSTRAINT staff_parkinglotid_fkey FOREIGN KEY (parkinglot_id) REFERENCES public.parking_lot(parkinglot_id);


ALTER TABLE ONLY public.student
    ADD CONSTRAINT student_customerid_fkey FOREIGN KEY (customer_id) REFERENCES public.customer(customer_id);


ALTER TABLE ONLY public.vehicle
    ADD CONSTRAINT vehicle_customerid_fkey FOREIGN KEY (customer_id) REFERENCES public.customer(customer_id);


ALTER TABLE ONLY public.vehicle
    ADD CONSTRAINT vehicle_vehicletypeid_fkey FOREIGN KEY (vehicletype_id) REFERENCES public.vehicle_type(vehicletype_id);


ALTER TABLE ONLY public.visitor
    ADD CONSTRAINT visitor_customerid_fkey FOREIGN KEY (customer_id) REFERENCES public.customer(customer_id);