ALTER TABLE public.sessions ADD CONSTRAINT sessions_pk PRIMARY KEY (id);
ALTER TABLE public.customers ADD CONSTRAINT customers_pk PRIMARY KEY (id);
ALTER TABLE public.movies ADD CONSTRAINT movies_pk PRIMARY KEY (id);
CREATE INDEX sessions_movie_id_idx ON public.sessions USING btree (movie_id);
CREATE INDEX movies_year_name_idx ON public.movies USING btree (year DESC, name);
CREATE INDEX customers_surname_idx ON public.customers (surname,"name",birthday DESC,id DESC);
CREATE INDEX movies_year_idx ON public.movies ("year" DESC,"name",id DESC);
