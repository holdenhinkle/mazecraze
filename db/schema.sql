CREATE TYPE formula_status AS ENUM ('pending', 'approved', 'rejected');

CREATE TABLE maze_formulas (
  id serial PRIMARY KEY,
  maze_type text NOT NULL,
  unique_square_set text NOT NULL,
  x integer NOT NULL CHECK (x > 0),
  y integer NOT NULL CHECK (y > 0),
  endpoints integer NOT NULL CHECK (endpoints >= 0),
  barriers integer NOT NULL DEFAULT 0,
  bridges integer NOT NULL DEFAULT 0,
  tunnels integer NOT NULL DEFAULT 0,
  portals integer NOT NULL DEFAULT 0,
  experiment boolean NOT NULL DEFAULT FALSE,
  status formula_status NOT NULL DEFAULT 'pending',
  created timestamp NOT NULL DEFAULT NOW(),
  updated timestamp NOT NULL DEFAULT NOW()
);

CREATE TABLE maze_formula_set_permutations (
  id serial PRIMARY KEY,
  maze_formula_id integer NOT NULL REFERENCES maze_formulas(id) ON DELETE CASCADE,
  permutation text NOT NULL,
  created timestamp NOT NULL DEFAULT NOW(),
  updated timestamp NOT NULL DEFAULT NOW()
);

CREATE TABLE maze_candidates (
  id serial PRIMARY KEY,
  maze_formula_set_permutation_id integer NOT NULL REFERENCES maze_formula_set_permutations(id) ON DELETE CASCADE,
  number_of_solutions integer NOT NULL,
  solutions text NOT NULL,
  created timestamp NOT NULL DEFAULT NOW(),
  updated timestamp NOT NULL DEFAULT NOW()
);

CREATE TYPE job_type AS ENUM ('generate_maze_formulas', 'generate_maze_permutations', 'generate_maze_candidates');

CREATE TYPE job_status AS ENUM ('queued', 'processing', 'completed', 'failed');

CREATE TABLE background_jobs (
  id serial PRIMARY KEY,
  job_type job_type NOT NULL,
  params text NOT NULL,
  status job_status NOT NULL DEFAULT 'queued',
  pid TEXT,
  system_message text,
  created timestamp NOT NULL DEFAULT NOW(),
  updated timestamp NOT NULL DEFAULT NOW()
);
