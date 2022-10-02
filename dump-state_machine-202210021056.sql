--
-- PostgreSQL database dump
--

-- Dumped from database version 9.5.3
-- Dumped by pg_dump version 14.2

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

--
-- TOC entry 6 (class 2615 OID 587965)
-- Name: handlers; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA handlers;


--
-- TOC entry 9 (class 2615 OID 580393)
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

-- CREATE SCHEMA public;


--
-- TOC entry 2237 (class 0 OID 0)
-- Dependencies: 9
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- TOC entry 8 (class 2615 OID 587966)
-- Name: sm; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA sm;


SET default_tablespace = '';

--
-- TOC entry 183 (class 1259 OID 587967)
-- Name: transition; Type: TABLE; Schema: sm; Owner: -
--

CREATE TABLE sm.transition (
    input_status_id integer NOT NULL,
    event_id integer NOT NULL,
    output_status_id integer NOT NULL,
    transition_handler text,
    transition_description text,
    id integer NOT NULL
);


--
-- TOC entry 2238 (class 0 OID 0)
-- Dependencies: 183
-- Name: TABLE transition; Type: COMMENT; Schema: sm; Owner: -
--

COMMENT ON TABLE sm.transition IS 'FSM transition table';


--
-- TOC entry 207 (class 1255 OID 587973)
-- Name: alert(integer, sm.transition, jsonb, integer); Type: FUNCTION; Schema: handlers; Owner: -
--

CREATE FUNCTION handlers.alert(instance_id integer, transition sm.transition, context jsonb, log_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
begin
	 raise notice 'Alert: %', instance_id;
	 return true;
end;
$$;


--
-- TOC entry 216 (class 1255 OID 587974)
-- Name: cash(integer, sm.transition, jsonb, integer); Type: FUNCTION; Schema: handlers; Owner: -
--

CREATE FUNCTION handlers.cash(arg_instance_id integer, transition sm.transition, context jsonb, log_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
	amount numeric;
begin
	amount := (context ->> 'amount')::numeric;
	if (amount < 1) then
		raise notice '% Coin NOK: %', arg_instance_id, amount;
		insert into sm.transition_log_ext (id, extra)
		values (log_id, jsonb_build_object('cancelled', 'cheating'));
		return false;
	else
		raise notice '% Coin OK: %', arg_instance_id, amount;
		insert into sm.transition_log_ext (id, extra) 
		values (log_id, jsonb_build_object('amount', amount));
		return true;
	end if;
end;
$$;


--
-- TOC entry 208 (class 1255 OID 587975)
-- Name: pass(integer, sm.transition, jsonb, integer); Type: FUNCTION; Schema: handlers; Owner: -
--

CREATE FUNCTION handlers.pass(instance_id integer, transition sm.transition, context jsonb, log_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
begin
	 raise notice 'Pass: %', instance_id;
	 return true;
end;
$$;


--
-- TOC entry 212 (class 1255 OID 587976)
-- Name: return_cash(integer, sm.transition, jsonb, integer); Type: FUNCTION; Schema: handlers; Owner: -
--

CREATE FUNCTION handlers.return_cash(arg_instance_id integer, transition sm.transition, context jsonb, log_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
	amount numeric;
begin
	amount := (context ->> 'amount')::numeric;
	raise notice '% Coin return: %', arg_instance_id, amount;
	insert into sm.transition_log_ext (id, extra) 
	values (log_id, jsonb_build_object('amount', amount * (-1)));
	return true;
end;
$$;


--
-- TOC entry 209 (class 1255 OID 587977)
-- Name: security_exception(integer, sm.transition, jsonb, integer); Type: FUNCTION; Schema: handlers; Owner: -
--

CREATE FUNCTION handlers.security_exception(instance_id integer, transition sm.transition, context jsonb, log_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
begin
	 raise notice 'Security exception: %', instance_id;
	 return true;
end;
$$;


--
-- TOC entry 210 (class 1255 OID 587978)
-- Name: service_in(integer, sm.transition, jsonb, integer); Type: FUNCTION; Schema: handlers; Owner: -
--

CREATE FUNCTION handlers.service_in(instance_id integer, transition sm.transition, context jsonb, log_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
begin
	 raise notice 'Service in: %', instance_id;
	 return true;
end;
$$;


--
-- TOC entry 211 (class 1255 OID 587979)
-- Name: service_out(integer, sm.transition, jsonb, integer); Type: FUNCTION; Schema: handlers; Owner: -
--

CREATE FUNCTION handlers.service_out(instance_id integer, transition sm.transition, context jsonb, log_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
begin
	 raise notice 'Service out: %', instance_id;
	 return true;
end;
$$;


--
-- TOC entry 213 (class 1255 OID 587980)
-- Name: create_instance(text, text, jsonb); Type: FUNCTION; Schema: sm; Owner: -
--

CREATE FUNCTION sm.create_instance(arg_instance_reference text, arg_instance_description text, arg_instance_data jsonb DEFAULT '{}'::jsonb) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare
    STATUS_INIT constant integer default 0;
    var_id integer;
begin
  insert into sm.instance_object (instance_reference, instance_description, instance_data)
    values (arg_instance_reference, arg_instance_description, arg_instance_data)
    returning id into var_id;
  insert into sm.transition_log (id, instance_id, transition_id, transition_context)
    values (nextval('sm.transition_log_id_seq'), var_id, (select id from sm.transition where input_status_id = STATUS_INIT), '{}'::jsonb);
  return var_id;
end; 
$$;


--
-- TOC entry 221 (class 1255 OID 670305)
-- Name: event_info(integer); Type: FUNCTION; Schema: sm; Owner: -
--

CREATE FUNCTION sm.event_info(event_id integer) RETURNS jsonb
    LANGUAGE sql
    AS $$
 select to_jsonb(tl) from sm.transition_log tl where id = event_id;
$$;


--
-- TOC entry 220 (class 1255 OID 696195)
-- Name: event_infox(integer); Type: FUNCTION; Schema: sm; Owner: -
--

CREATE FUNCTION sm.event_infox(arg_event_id integer) RETURNS jsonb
    LANGUAGE sql
    AS $$
SELECT to_jsonb(t.*)
from
(
 select tl.instance_id, io.instance_reference,
        tr.input_status_id, tr.event_id, tr.output_status_id,
        transition_time, tl.transition_context,
        coalesce(tle.extra, '{}') as extra
  from sm.transition_log tl
  inner join sm.transition tr on tl.transition_id = tr.id
  inner join sm.instance_object io on tl.instance_id = io.id
  left outer join sm.transition_log_ext tle on tl.id = tle.id
  where tl.id = arg_event_id
) t;
$$;


--
-- TOC entry 222 (class 1255 OID 587984)
-- Name: handle_event(integer, integer, jsonb); Type: FUNCTION; Schema: sm; Owner: -
--

CREATE FUNCTION sm.handle_event(arg_instance_id integer, arg_event_id integer, arg_event_context jsonb DEFAULT '{}'::jsonb) RETURNS integer
    LANGUAGE plpgsql STRICT
    AS $_$
DECLARE
    NOINSTANCE   constant integer default -1; -- instance does not exist
    NOTRANSITION constant integer default -2; -- transition does not exist
    GUARDSTOP    constant integer default -3; -- cancelled by guard condition
    DYNSQL       constant text    default 'SELECT %s($1,$2,$3,$4)';

    transition sm.transition%rowtype;
    log_id integer;
    status_id integer;
    trans_handler text;
    permit boolean default true;
BEGIN
    status_id := sm.instance_status(arg_instance_id);
    if (status_id is null) then
        RETURN NOINSTANCE;
    end if;

    transition := sm.transition_id(status_id, arg_event_id);
    if (transition is null) then
        RETURN NOTRANSITION;
    end if;

    log_id := nextval('sm.transition_log_id_seq');
    trans_handler := nullif(trim(transition.transition_handler), '');

    if (trans_handler is not null) then
    /** This function declaration is mandatory for a transition handler except for the function name:
        FUNCTION trans_handler(instance_id integer, transition sm.transition, context jsonb, log_id integer)
        RETURNS boolean;
        FALSE return value aborts the transition. */
        EXECUTE format(DYNSQL, trans_handler) 
           into permit
          using arg_instance_id, transition, arg_event_context, log_id;
    end if;

    if permit then
        INSERT into sm.transition_log (id, instance_id, transition_id, transition_context)
        values (log_id, arg_instance_id, transition.id, arg_event_context);
        RETURN log_id;
    else
        RETURN GUARDSTOP;
    end if;
END;
$_$;


--
-- TOC entry 214 (class 1255 OID 587985)
-- Name: handle_event(text, integer, jsonb); Type: FUNCTION; Schema: sm; Owner: -
--

CREATE FUNCTION sm.handle_event(arg_instance_reference text, arg_event_id integer, arg_event_context jsonb DEFAULT '{}'::jsonb) RETURNS integer
    LANGUAGE sql
    AS $$
	select sm.handle_event(sm.instance_id(arg_instance_reference), arg_event_id, arg_event_context);
$$;


--
-- TOC entry 215 (class 1255 OID 587986)
-- Name: instance_id(text); Type: FUNCTION; Schema: sm; Owner: -
--

CREATE FUNCTION sm.instance_id(arg_instance_reference text) RETURNS integer
    LANGUAGE sql STABLE COST 10
    AS $$
select coalesce
(
	(select io.id from sm.instance_object io where io.instance_reference = arg_instance_reference),
	(-1)
);
$$;


--
-- TOC entry 217 (class 1255 OID 587981)
-- Name: instance_status(integer); Type: FUNCTION; Schema: sm; Owner: -
--

CREATE FUNCTION sm.instance_status(arg_instance_id integer) RETURNS integer
    LANGUAGE sql STABLE
    AS $$ 
 SELECT transition.output_status_id 
	FROM sm.transition_log inner join sm.transition on transition_log.transition_id = transition.id
	WHERE transition_log.instance_id = arg_instance_id
	ORDER BY transition_log.id DESC LIMIT 1; 
$$;


--
-- TOC entry 219 (class 1255 OID 587982)
-- Name: instance_status(text); Type: FUNCTION; Schema: sm; Owner: -
--

CREATE FUNCTION sm.instance_status(arg_instance_reference text) RETURNS integer
    LANGUAGE sql STABLE
    AS $$ 
 SELECT sm.instance_status(sm.instance_id(arg_instance_reference));
$$;


--
-- TOC entry 218 (class 1255 OID 587983)
-- Name: transition_id(integer, integer); Type: FUNCTION; Schema: sm; Owner: -
--

CREATE FUNCTION sm.transition_id(arg_status_id integer, arg_event_id integer) RETURNS sm.transition
    LANGUAGE sql STABLE
    AS $$
 SELECT *
    FROM sm.transition
    WHERE input_status_id = arg_status_id AND event_id = arg_event_id;
$$;


--
-- TOC entry 184 (class 1259 OID 587988)
-- Name: event; Type: TABLE; Schema: sm; Owner: -
--

CREATE TABLE sm.event (
    id integer NOT NULL,
    event_name text NOT NULL,
    event_description text
);


--
-- TOC entry 2239 (class 0 OID 0)
-- Dependencies: 184
-- Name: TABLE event; Type: COMMENT; Schema: sm; Owner: -
--

COMMENT ON TABLE sm.event IS 'FSM input events';


--
-- TOC entry 185 (class 1259 OID 587994)
-- Name: instance_object; Type: TABLE; Schema: sm; Owner: -
--

CREATE TABLE sm.instance_object (
    id integer NOT NULL,
    instance_data jsonb DEFAULT '{}'::jsonb NOT NULL,
    instance_description text,
    instance_reference text
);


--
-- TOC entry 2240 (class 0 OID 0)
-- Dependencies: 185
-- Name: TABLE instance_object; Type: COMMENT; Schema: sm; Owner: -
--

COMMENT ON TABLE sm.instance_object IS 'FSM instances';


--
-- TOC entry 186 (class 1259 OID 588001)
-- Name: instance_object_id_seq; Type: SEQUENCE; Schema: sm; Owner: -
--

CREATE SEQUENCE sm.instance_object_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2241 (class 0 OID 0)
-- Dependencies: 186
-- Name: instance_object_id_seq; Type: SEQUENCE OWNED BY; Schema: sm; Owner: -
--

ALTER SEQUENCE sm.instance_object_id_seq OWNED BY sm.instance_object.id;


--
-- TOC entry 187 (class 1259 OID 588003)
-- Name: status; Type: TABLE; Schema: sm; Owner: -
--

CREATE TABLE sm.status (
    id integer NOT NULL,
    status_name text NOT NULL,
    status_description text
);


--
-- TOC entry 2242 (class 0 OID 0)
-- Dependencies: 187
-- Name: TABLE status; Type: COMMENT; Schema: sm; Owner: -
--

COMMENT ON TABLE sm.status IS 'List of FSM states';


--
-- TOC entry 188 (class 1259 OID 588009)
-- Name: transition_log; Type: TABLE; Schema: sm; Owner: -
--

CREATE TABLE sm.transition_log (
    id integer NOT NULL,
    instance_id integer NOT NULL,
    transition_id integer NOT NULL,
    transition_context jsonb NOT NULL,
    transition_time timestamp without time zone DEFAULT now() NOT NULL
);


--
-- TOC entry 2243 (class 0 OID 0)
-- Dependencies: 188
-- Name: TABLE transition_log; Type: COMMENT; Schema: sm; Owner: -
--

COMMENT ON TABLE sm.transition_log IS 'Transition history & instance state';


--
-- TOC entry 189 (class 1259 OID 588016)
-- Name: transaction_log_v; Type: VIEW; Schema: sm; Owner: -
--

CREATE VIEW sm.transaction_log_v AS
 SELECT tl.id,
    tl.instance_id,
    tr.input_status_id,
    tr.event_id,
    tr.output_status_id,
    tl.transition_context,
    tl.transition_time
   FROM (sm.transition_log tl
     JOIN sm.transition tr ON ((tl.transition_id = tr.id)));


--
-- TOC entry 190 (class 1259 OID 588020)
-- Name: transaction_log_verb; Type: VIEW; Schema: sm; Owner: -
--

CREATE VIEW sm.transaction_log_verb AS
 SELECT tlv.transition_time AS "Timestamp",
    tlv.instance_id AS inst_id,
    io.instance_description AS "Instance",
    tlv.input_status_id AS istat_id,
    ist.status_description AS "Status in",
    tlv.event_id,
    ev.event_description AS "Event",
    tlv.output_status_id AS ostat_id,
    ost.status_description AS "Status out",
    tlv.transition_context AS "Payload"
   FROM ((((sm.transaction_log_v tlv
     JOIN sm.status ist ON ((tlv.input_status_id = ist.id)))
     JOIN sm.status ost ON ((tlv.output_status_id = ost.id)))
     JOIN sm.event ev ON ((tlv.event_id = ev.id)))
     JOIN sm.instance_object io ON ((tlv.instance_id = io.id)));


--
-- TOC entry 191 (class 1259 OID 588025)
-- Name: transition_id_seq; Type: SEQUENCE; Schema: sm; Owner: -
--

CREATE SEQUENCE sm.transition_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2244 (class 0 OID 0)
-- Dependencies: 191
-- Name: transition_id_seq; Type: SEQUENCE OWNED BY; Schema: sm; Owner: -
--

ALTER SEQUENCE sm.transition_id_seq OWNED BY sm.transition.id;


--
-- TOC entry 192 (class 1259 OID 588027)
-- Name: transition_log_ext; Type: TABLE; Schema: sm; Owner: -
--

CREATE TABLE sm.transition_log_ext (
    id integer NOT NULL,
    extra jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- TOC entry 2245 (class 0 OID 0)
-- Dependencies: 192
-- Name: TABLE transition_log_ext; Type: COMMENT; Schema: sm; Owner: -
--

COMMENT ON TABLE sm.transition_log_ext IS 'Transition extra info used by transition handlers';


--
-- TOC entry 193 (class 1259 OID 588035)
-- Name: transition_log_id_seq; Type: SEQUENCE; Schema: sm; Owner: -
--

CREATE SEQUENCE sm.transition_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2246 (class 0 OID 0)
-- Dependencies: 193
-- Name: transition_log_id_seq; Type: SEQUENCE OWNED BY; Schema: sm; Owner: -
--

ALTER SEQUENCE sm.transition_log_id_seq OWNED BY sm.transition_log.id;


--
-- TOC entry 194 (class 1259 OID 588037)
-- Name: transition_v; Type: VIEW; Schema: sm; Owner: -
--

CREATE VIEW sm.transition_v AS
 SELECT t.id,
    t.input_status_id AS istat_id,
    istat.status_description AS "Status in",
    t.event_id,
    evnt.event_description AS "Event",
    t.output_status_id AS ostat_id,
    ostat.status_description AS "Status out",
    t.transition_handler,
    t.transition_description
   FROM (((sm.transition t
     JOIN sm.event evnt ON ((t.event_id = evnt.id)))
     JOIN sm.status istat ON ((t.input_status_id = istat.id)))
     JOIN sm.status ostat ON ((t.output_status_id = ostat.id)))
  ORDER BY t.input_status_id, t.event_id;


--
-- TOC entry 2083 (class 2604 OID 588042)
-- Name: instance_object id; Type: DEFAULT; Schema: sm; Owner: -
--

ALTER TABLE ONLY sm.instance_object ALTER COLUMN id SET DEFAULT nextval('sm.instance_object_id_seq'::regclass);


--
-- TOC entry 2081 (class 2604 OID 588043)
-- Name: transition id; Type: DEFAULT; Schema: sm; Owner: -
--

ALTER TABLE ONLY sm.transition ALTER COLUMN id SET DEFAULT nextval('sm.transition_id_seq'::regclass);


--
-- TOC entry 2224 (class 0 OID 587988)
-- Dependencies: 184
-- Data for Name: event; Type: TABLE DATA; Schema: sm; Owner: -
--

INSERT INTO sm.event VALUES (0, 'init', 'начало на жизнения цикъл');
INSERT INTO sm.event VALUES (1, 'coin', 'плащане');
INSERT INTO sm.event VALUES (2, 'push', 'опит за преминаване');
INSERT INTO sm.event VALUES (3, 'coin_reclaim', 'връщане на монета');
INSERT INTO sm.event VALUES (4, 'service key in', 'поставяне на сервизен ключ');
INSERT INTO sm.event VALUES (5, 'service key out', 'махане на сервизен ключ');
INSERT INTO sm.event VALUES (6, 'security exception', 'отваряне от охраната');


--
-- TOC entry 2225 (class 0 OID 587994)
-- Dependencies: 185
-- Data for Name: instance_object; Type: TABLE DATA; Schema: sm; Owner: -
--

INSERT INTO sm.instance_object VALUES (2, '{}', 'Въртележка на партера', 'Turnstile-a');
INSERT INTO sm.instance_object VALUES (3, '{}', 'Въртележка на първия етаж', 'Turnstile-b');


--
-- TOC entry 2227 (class 0 OID 588003)
-- Dependencies: 187
-- Data for Name: status; Type: TABLE DATA; Schema: sm; Owner: -
--

INSERT INTO sm.status VALUES (0, 'Initial', 'Начално състояние');
INSERT INTO sm.status VALUES (1, 'Locked', 'Затворена врата');
INSERT INTO sm.status VALUES (2, 'Unlocked', 'Отворена врата');
INSERT INTO sm.status VALUES (3, 'InService', 'Сервизен режим');


--
-- TOC entry 2223 (class 0 OID 587967)
-- Dependencies: 183
-- Data for Name: transition; Type: TABLE DATA; Schema: sm; Owner: -
--

INSERT INTO sm.transition VALUES (0, 0, 1, NULL, 'Начало на работа', 1);
INSERT INTO sm.transition VALUES (1, 1, 2, 'handlers.cash', 'Плащане', 2);
INSERT INTO sm.transition VALUES (1, 2, 1, 'handlers.alert', 'Опит за преминаване без да е платено', 3);
INSERT INTO sm.transition VALUES (1, 4, 3, 'handlers.service_in', 'Поставяне на сервизен ключ', 4);
INSERT INTO sm.transition VALUES (1, 6, 2, 'handlers.security_exception', 'Отваряне от охраната', 5);
INSERT INTO sm.transition VALUES (2, 2, 1, 'handlers.pass', 'Преминаване', 6);
INSERT INTO sm.transition VALUES (2, 3, 1, 'handlers.return_cash', 'Връщане на платеното', 7);
INSERT INTO sm.transition VALUES (3, 2, 3, ' ', 'Преминаване в сервизен режим', 8);
INSERT INTO sm.transition VALUES (3, 5, 1, 'handlers.service_out', 'Изваждане на сервизния ключ', 9);


--
-- TOC entry 2228 (class 0 OID 588009)
-- Dependencies: 188
-- Data for Name: transition_log; Type: TABLE DATA; Schema: sm; Owner: -
--

INSERT INTO sm.transition_log VALUES (3, 2, 1, '{}', '2021-01-06 13:39:47.112911');
INSERT INTO sm.transition_log VALUES (4, 3, 1, '{}', '2021-01-06 13:40:36.804298');
INSERT INTO sm.transition_log VALUES (5, 2, 4, '{}', '2021-01-06 13:42:45.319837');
INSERT INTO sm.transition_log VALUES (6, 2, 8, '{}', '2021-01-06 13:43:14.17399');
INSERT INTO sm.transition_log VALUES (9, 2, 9, '{}', '2021-01-06 13:46:00.832901');
INSERT INTO sm.transition_log VALUES (11, 2, 2, '{"amount": 2}', '2021-01-06 13:49:07.879191');


--
-- TOC entry 2230 (class 0 OID 588027)
-- Dependencies: 192
-- Data for Name: transition_log_ext; Type: TABLE DATA; Schema: sm; Owner: -
--

INSERT INTO sm.transition_log_ext VALUES (11, '{"amount": 2}');


--
-- TOC entry 2247 (class 0 OID 0)
-- Dependencies: 186
-- Name: instance_object_id_seq; Type: SEQUENCE SET; Schema: sm; Owner: -
--

SELECT pg_catalog.setval('sm.instance_object_id_seq', 3, true);


--
-- TOC entry 2248 (class 0 OID 0)
-- Dependencies: 191
-- Name: transition_id_seq; Type: SEQUENCE SET; Schema: sm; Owner: -
--

SELECT pg_catalog.setval('sm.transition_id_seq', 9, true);


--
-- TOC entry 2249 (class 0 OID 0)
-- Dependencies: 193
-- Name: transition_log_id_seq; Type: SEQUENCE SET; Schema: sm; Owner: -
--

SELECT pg_catalog.setval('sm.transition_log_id_seq', 11, true);


--
-- TOC entry 2090 (class 2606 OID 588046)
-- Name: event events_pkey; Type: CONSTRAINT; Schema: sm; Owner: -
--

ALTER TABLE ONLY sm.event
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- TOC entry 2092 (class 2606 OID 588048)
-- Name: instance_object instance_object_pkey; Type: CONSTRAINT; Schema: sm; Owner: -
--

ALTER TABLE ONLY sm.instance_object
    ADD CONSTRAINT instance_object_pkey PRIMARY KEY (id);


--
-- TOC entry 2094 (class 2606 OID 588050)
-- Name: instance_object instance_object_un; Type: CONSTRAINT; Schema: sm; Owner: -
--

ALTER TABLE ONLY sm.instance_object
    ADD CONSTRAINT instance_object_un UNIQUE (instance_reference);


--
-- TOC entry 2087 (class 2606 OID 588052)
-- Name: transition sm_transition_pk; Type: CONSTRAINT; Schema: sm; Owner: -
--

ALTER TABLE ONLY sm.transition
    ADD CONSTRAINT sm_transition_pk PRIMARY KEY (id);


--
-- TOC entry 2096 (class 2606 OID 588054)
-- Name: status status_pkey; Type: CONSTRAINT; Schema: sm; Owner: -
--

ALTER TABLE ONLY sm.status
    ADD CONSTRAINT status_pkey PRIMARY KEY (id);


--
-- TOC entry 2100 (class 2606 OID 588056)
-- Name: transition_log_ext transition_log_ext_pkey; Type: CONSTRAINT; Schema: sm; Owner: -
--

ALTER TABLE ONLY sm.transition_log_ext
    ADD CONSTRAINT transition_log_ext_pkey PRIMARY KEY (id);


--
-- TOC entry 2098 (class 2606 OID 588058)
-- Name: transition_log transition_log_pkey; Type: CONSTRAINT; Schema: sm; Owner: -
--

ALTER TABLE ONLY sm.transition_log
    ADD CONSTRAINT transition_log_pkey PRIMARY KEY (id);


--
-- TOC entry 2088 (class 1259 OID 588059)
-- Name: transition_input_status_id_idx; Type: INDEX; Schema: sm; Owner: -
--

CREATE INDEX transition_input_status_id_idx ON sm.transition USING btree (input_status_id, event_id);


--
-- TOC entry 2101 (class 2606 OID 588061)
-- Name: transition transition_input_event_id_fkey; Type: FK CONSTRAINT; Schema: sm; Owner: -
--

ALTER TABLE ONLY sm.transition
    ADD CONSTRAINT transition_input_event_id_fkey FOREIGN KEY (event_id) REFERENCES sm.event(id);


--
-- TOC entry 2102 (class 2606 OID 588066)
-- Name: transition transition_input_status_id_fkey; Type: FK CONSTRAINT; Schema: sm; Owner: -
--

ALTER TABLE ONLY sm.transition
    ADD CONSTRAINT transition_input_status_id_fkey FOREIGN KEY (input_status_id) REFERENCES sm.status(id);


--
-- TOC entry 2104 (class 2606 OID 588081)
-- Name: transition_log transition_log_instance_id_fkey; Type: FK CONSTRAINT; Schema: sm; Owner: -
--

ALTER TABLE ONLY sm.transition_log
    ADD CONSTRAINT transition_log_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES sm.instance_object(id);


--
-- TOC entry 2105 (class 2606 OID 588086)
-- Name: transition_log transition_log_transition_id_fkey; Type: FK CONSTRAINT; Schema: sm; Owner: -
--

ALTER TABLE ONLY sm.transition_log
    ADD CONSTRAINT transition_log_transition_id_fkey FOREIGN KEY (transition_id) REFERENCES sm.transition(id);


--
-- TOC entry 2103 (class 2606 OID 588091)
-- Name: transition transition_output_status_id_fkey; Type: FK CONSTRAINT; Schema: sm; Owner: -
--

ALTER TABLE ONLY sm.transition
    ADD CONSTRAINT transition_output_status_id_fkey FOREIGN KEY (output_status_id) REFERENCES sm.status(id);

--
-- PostgreSQL database dump complete
--
