--
-- PostgreSQL database dump
--

\restrict dldBfvq03gdUp5sI8x9FPYk8nql7S9M4LrHRZhQpHAagD3GF1XC19KuU6anCBmW

-- Dumped from database version 18.4
-- Dumped by pg_dump version 18.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'WIN1252';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: directorio_personal; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.directorio_personal (
    empleado_id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre character varying(100) NOT NULL,
    apellido character varying(100) NOT NULL,
    departamento character varying(100) NOT NULL,
    email character varying(150)
);


ALTER TABLE public.directorio_personal OWNER TO postgres;

--
-- Name: rfc_document_index; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rfc_document_index (
    index_id uuid DEFAULT gen_random_uuid() NOT NULL,
    file_name character varying(255) NOT NULL,
    file_type character varying(50) NOT NULL,
    project_id character varying(100)
);


ALTER TABLE public.rfc_document_index OWNER TO postgres;

--
-- Name: rfc_records; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rfc_records (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id character varying(100) NOT NULL,
    environment character varying(50) NOT NULL,
    project_name character varying(255) NOT NULL,
    impacted_platforms integer NOT NULL,
    CONSTRAINT rfc_records_environment_check CHECK (((environment)::text = ANY ((ARRAY['Dev'::character varying, 'QA'::character varying, 'PROD'::character varying])::text[])))
);


ALTER TABLE public.rfc_records OWNER TO postgres;

--
-- Name: COLUMN rfc_records.environment; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.rfc_records.environment IS 'Ambiente de despliegue objetivo: Dev, QA o PROD';


--
-- Name: rfc_responsables; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rfc_responsables (
    asignacion_id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id character varying(100),
    empleado_id uuid,
    rol_asignado character varying(100) NOT NULL
);


ALTER TABLE public.rfc_responsables OWNER TO postgres;

--
-- Data for Name: directorio_personal; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.directorio_personal (empleado_id, nombre, apellido, departamento, email) FROM stdin;
bbbfca17-0e70-40b8-b3c0-b0816899cf7f	Christian	Santos	Arquitectura	\N
1755219f-96eb-4e17-8506-e48e9188931a	Raziel	Martinez	Project Management	\N
6c7e496f-095c-4d15-974a-9aaa20360c51	Luis	Dominguez	Desarrollo	\N
a616ce48-652f-491a-ac27-e06525503e64	Jose	Zarate	Tecnología	\N
\.


--
-- Data for Name: rfc_document_index; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.rfc_document_index (index_id, file_name, file_type, project_id) FROM stdin;
91540212-0232-4b78-af7c-0520627197c1	RFC PROD  td189-bf25 Incidencia S3 control documental.xlsx	xlsx	td189-bf25
\.


--
-- Data for Name: rfc_records; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.rfc_records (id, project_id, environment, project_name, impacted_platforms) FROM stdin;
c1af1723-971b-4d76-aeb0-d617adcb617d	td189-bf25	PROD	Incidencia S3 control documental 	0
\.


--
-- Data for Name: rfc_responsables; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.rfc_responsables (asignacion_id, project_id, empleado_id, rol_asignado) FROM stdin;
58f0235e-aa0a-4555-a675-2076681ac0eb	td189-bf25	bbbfca17-0e70-40b8-b3c0-b0816899cf7f	Arquitecto
5a231628-302a-460b-85e3-2585ac1bd856	td189-bf25	1755219f-96eb-4e17-8506-e48e9188931a	Project Manager
e154ccb9-092b-4c74-8bcd-d5f7686d25eb	td189-bf25	6c7e496f-095c-4d15-974a-9aaa20360c51	Lider de Celula
5a2335bd-08da-417b-88bf-0ffd10ce9fe6	td189-bf25	a616ce48-652f-491a-ac27-e06525503e64	Lider Tecnico
\.


--
-- Name: directorio_personal directorio_personal_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.directorio_personal
    ADD CONSTRAINT directorio_personal_pkey PRIMARY KEY (empleado_id);


--
-- Name: rfc_document_index rfc_document_index_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rfc_document_index
    ADD CONSTRAINT rfc_document_index_pkey PRIMARY KEY (index_id);


--
-- Name: rfc_records rfc_records_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rfc_records
    ADD CONSTRAINT rfc_records_pkey PRIMARY KEY (id);


--
-- Name: rfc_responsables rfc_responsables_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rfc_responsables
    ADD CONSTRAINT rfc_responsables_pkey PRIMARY KEY (asignacion_id);


--
-- Name: rfc_document_index unique_project_file; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rfc_document_index
    ADD CONSTRAINT unique_project_file UNIQUE (project_id, file_name);


--
-- Name: rfc_records unique_rfc_project_id; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rfc_records
    ADD CONSTRAINT unique_rfc_project_id UNIQUE (project_id);


--
-- Name: rfc_document_index fk_document_project_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rfc_document_index
    ADD CONSTRAINT fk_document_project_id FOREIGN KEY (project_id) REFERENCES public.rfc_records(project_id) ON DELETE CASCADE;


--
-- Name: rfc_responsables rfc_responsables_empleado_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rfc_responsables
    ADD CONSTRAINT rfc_responsables_empleado_id_fkey FOREIGN KEY (empleado_id) REFERENCES public.directorio_personal(empleado_id);


--
-- Name: rfc_responsables rfc_responsables_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rfc_responsables
    ADD CONSTRAINT rfc_responsables_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.rfc_records(project_id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict dldBfvq03gdUp5sI8x9FPYk8nql7S9M4LrHRZhQpHAagD3GF1XC19KuU6anCBmW

