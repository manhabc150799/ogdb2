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
	RETURNING customerid INTO id;
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
	RETURNING customerid INTO id;
	INSERT INTO Student(customerid, fullname, mssv) 
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
	RETURNING customerid INTO id;
	INSERT INTO Visitor(customerid)
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
		FROM park JOIN now_vehicle USING(vehicleId)
		WHERE customerId = (SELECT customerId
							FROM now_vehicle n WHERE n.vehicleId = NEW.vehicleId)
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
	DELETE FROM customer WHERE customerid = OLD.customerid;
	RETURN OLD;
END;
$$;


ALTER FUNCTION public.delete_student() OWNER TO postgres;

CREATE FUNCTION public.delete_visitor() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE 
BEGIN 
	DELETE FROM customer WHERE customerid = OLD.customerid;
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
		SELECT parkingspotid INTO spot_id
		FROM parking_spot p
		WHERE 
			parkinglotid = input_parkinglotid
			AND input_size = (SELECT size FROM spot_type s WHERE p.spottypeid = s.spottypeid)
			AND NOT occupied 
		ORDER BY parkingspotid
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
		SELECT customerid INTO customer_id
		FROM student WHERE mssv = input_mssv;
	ELSE 
		SELECT customerid INTO customer_id
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
	SELECT parkinglotid INTO parkinglot FROM staff where staffid = input_staffid;
	RETURN parkinglot;
END;
$$;


ALTER FUNCTION public.getparkinglotid(input_staffid integer) OWNER TO postgres;

CREATE FUNCTION public.getvehicleid(string character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$-- Hiện tại đang sai vì vehicle không còn là những xe đang đỗ
DECLARE
    o_vehicleId INT;
BEGIN
-- Nếu là mssv
    IF length(string) = 8 THEN
        SELECT vehicleid INTO o_vehicleId
        FROM now_vehicle
        WHERE customerid IN (
            SELECT customerid
            FROM student
            WHERE mssv = string
        );
-- Nếu là uuid
	ELSE 
		SELECT vehicleid INTO o_vehicleId
		FROM now_vehicle 
		WHERE customerid IN (
			SELECT customerid
			FROM visitor
			WHERE ticketid::varchar = string
		);
	END IF;
	IF o_vehicleId IS NOT NULL THEN
    RETURN o_vehicleId;
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
		WHERE parkingspotid = new.parkingspotid;
		RETURN NEW;
	END;
$$;


ALTER FUNCTION public.is_occuppied() OWNER TO postgres;

CREATE FUNCTION public.payin_log_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
   INSERT INTO transaction (customerid, amount, time, tranaction_type)
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
   INSERT INTO transaction (mssv, amount, time, tranaction_type)
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
	WHERE parkinglotid = OLD.parkinglotid;
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
        WHERE parkingspotid = NEW.parkingspotid;
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
		FROM now_vehicle, student
		WHERE park.exit_time IS NULL
		AND park.vehicleId = now_vehicle.vehicleId
		AND now_vehicle.customerid = getCustomerId(string);
	ELSE
		-- Dành cho vé
		UPDATE park
		SET exit_time = now()
		WHERE park.vehicleid = (SELECT vehicleid FROM now_vehicle WHERE customerid = getCustomerId(string))
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
    customerid integer NOT NULL,
    customertype boolean NOT NULL
);


ALTER TABLE public.customer OWNER TO postgres;

CREATE SEQUENCE public.customer_customerid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.customer_customerid_seq OWNER TO postgres;

ALTER SEQUENCE public.customer_customerid_seq OWNED BY public.customer.customerid;


CREATE SEQUENCE public.customerid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.customerid_seq OWNER TO postgres;

CREATE TABLE public.now_vehicle (
    vehicleid integer NOT NULL,
    vehicletypeid integer,
    license_plate character varying(15),
    color character varying(15),
    customerid integer
);


ALTER TABLE public.now_vehicle OWNER TO postgres;

CREATE TABLE public.park (
    parkid integer NOT NULL,
    vehicleid integer NOT NULL,
    parkingspotid integer NOT NULL,
    entry_time timestamp without time zone DEFAULT now() NOT NULL,
    exit_time timestamp without time zone
);


ALTER TABLE public.park OWNER TO postgres;

CREATE SEQUENCE public.park_parkid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.park_parkid_seq OWNER TO postgres;

ALTER SEQUENCE public.park_parkid_seq OWNED BY public.park.parkid;


CREATE TABLE public.parking_lot (
    parkinglotid integer NOT NULL,
    name character varying(16) NOT NULL,
    capacity integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.parking_lot OWNER TO postgres;

CREATE SEQUENCE public.parking_lot_parkinglotid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.parking_lot_parkinglotid_seq OWNER TO postgres;

ALTER SEQUENCE public.parking_lot_parkinglotid_seq OWNED BY public.parking_lot.parkinglotid;


CREATE TABLE public.parking_spot (
    parkingspotid integer NOT NULL,
    spottypeid integer NOT NULL,
    parkinglotid integer NOT NULL,
    occupied boolean DEFAULT false NOT NULL
);


ALTER TABLE public.parking_spot OWNER TO postgres;

CREATE SEQUENCE public.parking_spot_parkingspotid_seq
    AS integer
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.parking_spot_parkingspotid_seq OWNER TO postgres;

ALTER SEQUENCE public.parking_spot_parkingspotid_seq OWNED BY public.parking_spot.parkingspotid;


CREATE TABLE public.spot_type (
    spottypeid integer NOT NULL,
    size smallint NOT NULL
);


ALTER TABLE public.spot_type OWNER TO postgres;

CREATE SEQUENCE public.spot_type_spottypeid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.spot_type_spottypeid_seq OWNER TO postgres;

ALTER SEQUENCE public.spot_type_spottypeid_seq OWNED BY public.spot_type.spottypeid;


CREATE TABLE public.staff (
    staffid integer NOT NULL,
    fullname character varying(256) NOT NULL,
    password character varying DEFAULT '12345678'::character varying NOT NULL,
    parkinglotid integer NOT NULL,
    CONSTRAINT staff_password_check CHECK ((length((password)::text) >= 8))
);


ALTER TABLE public.staff OWNER TO postgres;

CREATE SEQUENCE public.staff_staffid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.staff_staffid_seq OWNER TO postgres;

ALTER SEQUENCE public.staff_staffid_seq OWNED BY public.staff.staffid;


CREATE TABLE public.student (
    customerid integer NOT NULL,
    fullname character varying(255) NOT NULL,
    mssv character varying(8) NOT NULL,
    balance integer DEFAULT 0 NOT NULL,
    password character varying DEFAULT '123456'::character varying NOT NULL
);


ALTER TABLE public.student OWNER TO postgres;

CREATE TABLE public.transaction (
    transactionid integer NOT NULL,
    amount integer NOT NULL,
    "time" timestamp without time zone DEFAULT now() NOT NULL,
    tranaction_type boolean NOT NULL,
    customerid integer NOT NULL
);


ALTER TABLE public.transaction OWNER TO postgres;

CREATE SEQUENCE public.transaction_transactionid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.transaction_transactionid_seq OWNER TO postgres;

ALTER SEQUENCE public.transaction_transactionid_seq OWNED BY public.transaction.transactionid;


CREATE TABLE public.vehicle_type (
    vehicletypeid integer NOT NULL,
    name character varying(15) NOT NULL,
    price integer DEFAULT 0 NOT NULL,
    size smallint NOT NULL,
    CONSTRAINT vehicle_type_price_check CHECK ((price >= 0))
);


ALTER TABLE public.vehicle_type OWNER TO postgres;

CREATE SEQUENCE public.vehicle_type_vehicletypeid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.vehicle_type_vehicletypeid_seq OWNER TO postgres;

ALTER SEQUENCE public.vehicle_type_vehicletypeid_seq OWNED BY public.vehicle_type.vehicletypeid;


CREATE SEQUENCE public.vehicle_vehicleid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.vehicle_vehicleid_seq OWNER TO postgres;

ALTER SEQUENCE public.vehicle_vehicleid_seq OWNED BY public.now_vehicle.vehicleid;


CREATE TABLE public.visitor (
    customerid integer NOT NULL,
    ticketid uuid DEFAULT gen_random_uuid() NOT NULL
);


ALTER TABLE public.visitor OWNER TO postgres;

ALTER TABLE ONLY public.application ALTER COLUMN id SET DEFAULT nextval('public.application_id_seq'::regclass);


ALTER TABLE ONLY public.customer ALTER COLUMN customerid SET DEFAULT nextval('public.customer_customerid_seq'::regclass);


ALTER TABLE ONLY public.now_vehicle ALTER COLUMN vehicleid SET DEFAULT nextval('public.vehicle_vehicleid_seq'::regclass);


ALTER TABLE ONLY public.park ALTER COLUMN parkid SET DEFAULT nextval('public.park_parkid_seq'::regclass);


ALTER TABLE ONLY public.parking_lot ALTER COLUMN parkinglotid SET DEFAULT nextval('public.parking_lot_parkinglotid_seq'::regclass);


ALTER TABLE ONLY public.parking_spot ALTER COLUMN parkingspotid SET DEFAULT nextval('public.parking_spot_parkingspotid_seq'::regclass);


ALTER TABLE ONLY public.spot_type ALTER COLUMN spottypeid SET DEFAULT nextval('public.spot_type_spottypeid_seq'::regclass);


ALTER TABLE ONLY public.staff ALTER COLUMN staffid SET DEFAULT nextval('public.staff_staffid_seq'::regclass);


ALTER TABLE ONLY public.transaction ALTER COLUMN transactionid SET DEFAULT nextval('public.transaction_transactionid_seq'::regclass);


ALTER TABLE ONLY public.vehicle_type ALTER COLUMN vehicletypeid SET DEFAULT nextval('public.vehicle_type_vehicletypeid_seq'::regclass);


COPY public.application (id, fullname, datebirth, email) FROM stdin;
\.


COPY public.customer (customerid, customertype) FROM stdin;
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


COPY public.now_vehicle (vehicleid, vehicletypeid, license_plate, color, customerid) FROM stdin;
67	1	37a	red	22
72	2	\N	blue	22
74	1	37a1	red	4
75	2	\N	brown	22
76	3	37a	red	22
77	3	37aaa	red	34
78	3	37A225	red	35
79	1	red	37a	22
\.


COPY public.park (parkid, vehicleid, parkingspotid, entry_time, exit_time) FROM stdin;
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


COPY public.parking_lot (parkinglotid, name, capacity) FROM stdin;
1	B1	300
3	D35	600
4	C7	800
\.


COPY public.parking_spot (parkingspotid, spottypeid, parkinglotid, occupied) FROM stdin;
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
2174	3	4	f
2175	3	4	f
2176	3	4	f
2177	3	4	f
2178	3	4	f
2179	3	4	f
2180	3	4	f
2181	3	4	f
2182	3	4	f
2183	3	4	f
2184	3	4	f
2185	3	4	f
2186	3	4	f
2187	3	4	f
2188	3	4	f
2189	3	4	f
2190	3	4	f
2191	3	4	f
2192	3	4	f
2193	3	4	f
2194	3	4	f
2195	3	4	f
2196	3	4	f
2197	3	4	f
2198	3	4	f
2199	3	4	f
2200	3	4	f
2201	3	4	f
2202	3	4	f
2203	3	4	f
2204	3	4	f
2205	3	4	f
2206	3	4	f
2207	3	4	f
2208	3	4	f
2209	3	4	f
2210	3	4	f
2211	3	4	f
2212	3	4	f
2213	3	4	f
2214	3	4	f
2215	3	4	f
2216	3	4	f
2217	3	4	f
2218	3	4	f
2219	3	4	f
2220	3	4	f
2221	3	4	f
2222	3	4	f
2223	3	4	f
2224	3	4	f
2225	3	4	f
2226	3	4	f
2227	3	4	f
2228	3	4	f
2229	3	4	f
2230	3	4	f
2231	3	4	f
2232	3	4	f
2233	3	4	f
2234	3	4	f
2235	3	4	f
2236	3	4	f
2237	3	4	f
2238	3	4	f
2239	3	4	f
2240	3	4	f
2241	3	4	f
2242	3	4	f
2243	3	4	f
2244	3	4	f
2245	3	4	f
2246	3	4	f
2247	3	4	f
2248	3	4	f
2249	3	4	f
2250	3	4	f
2251	3	4	f
2252	3	4	f
2253	3	4	f
2254	3	4	f
2255	3	4	f
2256	3	4	f
2257	3	4	f
2258	3	4	f
2259	3	4	f
2260	3	4	f
2261	3	4	f
2262	3	4	f
2263	3	4	f
2264	3	4	f
2265	3	4	f
2266	3	4	f
2267	3	4	f
2268	3	4	f
2269	3	4	f
2270	3	4	f
2271	3	4	f
2272	3	4	f
2273	3	4	f
2274	3	4	f
2275	3	4	f
2276	3	4	f
2277	3	4	f
2278	3	4	f
2279	3	4	f
2280	3	4	f
2281	3	4	f
2282	3	4	f
2283	3	4	f
2284	3	4	f
2285	3	4	f
2286	3	4	f
2287	3	4	f
2288	3	4	f
2289	3	4	f
2290	3	4	f
2291	3	4	f
2292	3	4	f
2131	3	4	f
2132	3	4	f
2133	3	4	f
2134	3	4	f
2135	3	4	f
2136	3	4	f
2137	3	4	f
2138	3	4	f
2052	3	4	f
2139	3	4	f
2140	3	4	f
1	1	1	f
2	1	1	f
3	1	1	f
4	1	1	f
5	1	1	f
6	1	1	f
7	1	1	f
8	1	1	f
9	1	1	f
10	1	1	f
11	1	1	f
12	1	1	f
13	1	1	f
14	1	1	f
15	1	1	f
16	1	1	f
17	1	1	f
18	1	1	f
19	1	1	f
20	1	1	f
21	1	1	f
22	1	1	f
23	1	1	f
24	1	1	f
25	1	1	f
26	1	1	f
27	1	1	f
28	1	1	f
29	1	1	f
30	1	1	f
31	1	1	f
32	1	1	f
33	1	1	f
34	1	1	f
35	1	1	f
36	1	1	f
37	1	1	f
38	1	1	f
39	1	1	f
40	1	1	f
41	1	1	f
42	1	1	f
43	1	1	f
44	1	1	f
45	1	1	f
46	1	1	f
47	1	1	f
48	1	1	f
49	1	1	f
50	1	1	f
51	2	1	f
52	2	1	f
53	2	1	f
54	2	1	f
55	2	1	f
56	2	1	f
57	2	1	f
58	2	1	f
59	2	1	f
60	2	1	f
61	2	1	f
62	2	1	f
63	2	1	f
64	2	1	f
65	2	1	f
66	2	1	f
67	2	1	f
68	2	1	f
69	2	1	f
70	2	1	f
71	2	1	f
72	2	1	f
73	2	1	f
74	2	1	f
75	2	1	f
76	2	1	f
77	2	1	f
78	2	1	f
79	2	1	f
80	2	1	f
81	2	1	f
82	2	1	f
83	2	1	f
84	2	1	f
85	2	1	f
86	2	1	f
87	2	1	f
88	2	1	f
89	2	1	f
90	2	1	f
91	2	1	f
92	2	1	f
93	2	1	f
94	2	1	f
95	2	1	f
96	2	1	f
97	2	1	f
98	2	1	f
99	2	1	f
100	2	1	f
101	2	1	f
102	2	1	f
103	2	1	f
104	2	1	f
105	2	1	f
106	2	1	f
107	2	1	f
108	2	1	f
109	2	1	f
110	2	1	f
111	2	1	f
112	2	1	f
113	2	1	f
114	2	1	f
115	2	1	f
116	2	1	f
117	2	1	f
118	2	1	f
119	2	1	f
120	2	1	f
121	2	1	f
122	2	1	f
123	2	1	f
124	2	1	f
125	2	1	f
126	2	1	f
127	2	1	f
128	2	1	f
129	2	1	f
130	2	1	f
131	2	1	f
132	2	1	f
133	2	1	f
134	2	1	f
135	2	1	f
136	2	1	f
137	2	1	f
138	2	1	f
139	2	1	f
140	2	1	f
141	2	1	f
142	2	1	f
143	2	1	f
144	2	1	f
145	2	1	f
146	2	1	f
147	2	1	f
148	2	1	f
149	2	1	f
150	2	1	f
151	2	1	f
152	2	1	f
153	2	1	f
154	2	1	f
155	2	1	f
156	2	1	f
157	2	1	f
158	2	1	f
159	2	1	f
160	2	1	f
161	2	1	f
162	2	1	f
163	2	1	f
164	2	1	f
165	2	1	f
166	2	1	f
167	2	1	f
168	2	1	f
169	2	1	f
170	2	1	f
171	2	1	f
172	2	1	f
173	2	1	f
174	2	1	f
175	2	1	f
176	2	1	f
177	2	1	f
178	2	1	f
179	2	1	f
180	2	1	f
181	2	1	f
182	2	1	f
183	2	1	f
184	2	1	f
185	2	1	f
186	2	1	f
187	2	1	f
188	2	1	f
189	2	1	f
190	2	1	f
191	2	1	f
192	2	1	f
193	2	1	f
194	2	1	f
195	2	1	f
196	2	1	f
197	2	1	f
198	2	1	f
199	2	1	f
200	2	1	f
2036	2	4	f
2037	2	4	f
2038	2	4	f
2039	2	4	f
2040	2	4	f
2041	2	4	f
2042	2	4	f
2043	2	4	f
2044	2	4	f
2045	2	4	f
2046	2	4	f
2047	2	4	f
2048	2	4	f
2049	2	4	f
2050	2	4	f
2053	3	4	f
2054	3	4	f
2055	3	4	f
2056	3	4	f
2057	3	4	f
2058	3	4	f
2059	3	4	f
2060	3	4	f
2061	3	4	f
2062	3	4	f
2063	3	4	f
2064	3	4	f
2065	3	4	f
2066	3	4	f
2067	3	4	f
2068	3	4	f
2069	3	4	f
2070	3	4	f
2071	3	4	f
2072	3	4	f
2073	3	4	f
2074	3	4	f
2075	3	4	f
2076	3	4	f
2077	3	4	f
2078	3	4	f
2079	3	4	f
2080	3	4	f
2081	3	4	f
2082	3	4	f
2083	3	4	f
2084	3	4	f
2085	3	4	f
2086	3	4	f
2087	3	4	f
2088	3	4	f
2089	3	4	f
2090	3	4	f
2091	3	4	f
2092	3	4	f
2093	3	4	f
2094	3	4	f
2095	3	4	f
2096	3	4	f
2097	3	4	f
1398	4	3	f
1954	2	4	f
2098	3	4	f
2099	3	4	f
2100	3	4	f
2101	3	4	f
2102	3	4	f
2103	3	4	f
2104	3	4	f
2105	3	4	f
2106	3	4	f
2107	3	4	f
2108	3	4	f
2109	3	4	f
2110	3	4	f
2111	3	4	f
2112	3	4	f
2113	3	4	f
2114	3	4	f
2115	3	4	f
2116	3	4	f
2117	3	4	f
2118	3	4	f
2119	3	4	f
2120	3	4	f
1391	4	3	f
1847	2	4	f
2001	2	4	f
2002	2	4	f
2003	2	4	f
2004	2	4	f
2005	2	4	f
2006	2	4	f
2007	2	4	f
2008	2	4	f
2009	2	4	f
2010	2	4	f
2011	2	4	f
2012	2	4	f
2013	2	4	f
2014	2	4	f
2015	2	4	f
2016	2	4	f
2017	2	4	f
2018	2	4	f
2019	2	4	f
2020	2	4	f
2021	2	4	f
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


COPY public.spot_type (spottypeid, size) FROM stdin;
1	1
2	1
3	2
4	2
\.


COPY public.staff (staffid, fullname, password, parkinglotid) FROM stdin;
2	Nguyễn Nhân Viên	12345678	1
3	Nguyễn Đức Quân	12345678	4
5	Nguyễn Đức Nghĩa	12345678	4
\.


COPY public.student (customerid, fullname, mssv, balance, password) FROM stdin;
5	Pham Thi Mai Anh\n	20225884	87000	123456
4	Tran Minh Tuan	20225883	0	123456
36	Ngô Anh Tú	20220029	100000	123456
22	Nguyễn Văn Mạnh	20225880	146000	123456
3	Le Van Anh	20225882	100000	123456
17	Nguyễn Văn Dũng	20225879	100000	123456
20	Nguyễn Hồng Nhung	20221555	100000	123456
32	Văn Đức Cường	20220021	100000	123456
\.


COPY public.transaction (transactionid, amount, "time", tranaction_type, customerid) FROM stdin;
51	-3000	2024-05-31 10:14:56.292069	t	22
52	50000	2024-05-31 10:22:04.041037	f	22
53	23000	2024-05-31 10:24:03.542639	t	22
54	3000	2024-05-31 16:10:00.280164	f	22
55	20000	2024-06-01 10:08:38.238722	t	22
56	20000	2024-06-01 10:10:04.135523	t	22
57	100000	2024-06-01 10:12:25.073966	t	36
\.


COPY public.vehicle_type (vehicletypeid, name, price, size) FROM stdin;
1	Xe máy	3000	1
2	Xe đạp	2000	1
3	Ô tô	5000	2
\.


COPY public.visitor (customerid, ticketid) FROM stdin;
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


SELECT pg_catalog.setval('public.customer_customerid_seq', 36, true);


SELECT pg_catalog.setval('public.customerid_seq', 1, false);


SELECT pg_catalog.setval('public.park_parkid_seq', 62, true);


SELECT pg_catalog.setval('public.parking_lot_parkinglotid_seq', 2, true);


SELECT pg_catalog.setval('public.parking_spot_parkingspotid_seq', 2300, true);


SELECT pg_catalog.setval('public.spot_type_spottypeid_seq', 1, false);


SELECT pg_catalog.setval('public.staff_staffid_seq', 6, true);


SELECT pg_catalog.setval('public.transaction_transactionid_seq', 57, true);


SELECT pg_catalog.setval('public.vehicle_type_vehicletypeid_seq', 1, false);


SELECT pg_catalog.setval('public.vehicle_vehicleid_seq', 81, true);


ALTER TABLE ONLY public.application
    ADD CONSTRAINT application_pkey PRIMARY KEY (id);


ALTER TABLE ONLY public.customer
    ADD CONSTRAINT customer_pkey PRIMARY KEY (customerid);


ALTER TABLE ONLY public.park
    ADD CONSTRAINT park_pkey PRIMARY KEY (parkid);


ALTER TABLE ONLY public.parking_lot
    ADD CONSTRAINT parking_lot_pkey PRIMARY KEY (parkinglotid);


ALTER TABLE ONLY public.parking_spot
    ADD CONSTRAINT parking_spot_pkey PRIMARY KEY (parkingspotid);


ALTER TABLE ONLY public.spot_type
    ADD CONSTRAINT spot_type_pkey PRIMARY KEY (spottypeid);


ALTER TABLE ONLY public.staff
    ADD CONSTRAINT staff_pkey PRIMARY KEY (staffid);


ALTER TABLE ONLY public.student
    ADD CONSTRAINT student_mssv_key UNIQUE (mssv);


ALTER TABLE public.student
    ADD CONSTRAINT student_password_check CHECK ((length((password)::text) >= 6)) NOT VALID;


ALTER TABLE ONLY public.student
    ADD CONSTRAINT student_pkey PRIMARY KEY (mssv);


ALTER TABLE ONLY public.now_vehicle
    ADD CONSTRAINT vehicle_pkey PRIMARY KEY (vehicleid);


ALTER TABLE ONLY public.vehicle_type
    ADD CONSTRAINT vehicle_type_pkey PRIMARY KEY (vehicletypeid);


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
    ADD CONSTRAINT "Customer" FOREIGN KEY (customerid) REFERENCES public.customer(customerid) NOT VALID;


ALTER TABLE ONLY public.park
    ADD CONSTRAINT park_parkingspotid_fkey FOREIGN KEY (parkingspotid) REFERENCES public.parking_spot(parkingspotid);


ALTER TABLE ONLY public.park
    ADD CONSTRAINT park_vehicleid_fkey FOREIGN KEY (vehicleid) REFERENCES public.now_vehicle(vehicleid) NOT VALID;


ALTER TABLE ONLY public.parking_spot
    ADD CONSTRAINT parking_spot_parkinglotid_fkey FOREIGN KEY (parkinglotid) REFERENCES public.parking_lot(parkinglotid);


ALTER TABLE ONLY public.parking_spot
    ADD CONSTRAINT parking_spot_spottypeid_fkey FOREIGN KEY (spottypeid) REFERENCES public.spot_type(spottypeid);


ALTER TABLE ONLY public.staff
    ADD CONSTRAINT staff_parkinglotid_fkey FOREIGN KEY (parkinglotid) REFERENCES public.parking_lot(parkinglotid);


ALTER TABLE ONLY public.student
    ADD CONSTRAINT student_customerid_fkey FOREIGN KEY (customerid) REFERENCES public.customer(customerid);


ALTER TABLE ONLY public.now_vehicle
    ADD CONSTRAINT vehicle_customerid_fkey FOREIGN KEY (customerid) REFERENCES public.customer(customerid);


ALTER TABLE ONLY public.now_vehicle
    ADD CONSTRAINT vehicle_vehicletypeid_fkey FOREIGN KEY (vehicletypeid) REFERENCES public.vehicle_type(vehicletypeid);


ALTER TABLE ONLY public.visitor
    ADD CONSTRAINT visitor_customerid_fkey FOREIGN KEY (customerid) REFERENCES public.customer(customerid);