CREATE TYPE status_type AS ENUM ('pending', 'approved', 'rejected');

CREATE TABLE maze_formulas (
  id serial PRIMARY KEY,
  maze_type text NOT NULL,
  formula_set text NOT NULL,
  x integer NOT NULL CHECK (x > 0),
  y integer NOT NULL CHECK (y > 0),
  endpoints integer NOT NULL CHECK (endpoints >= 0),
  barriers integer NOT NULL DEFAULT 0,
  bridges integer NOT NULL DEFAULT 0,
  tunnels integer NOT NULL DEFAULT 0,
  portals integer NOT NULL DEFAULT 0,
  experiment boolean NOT NULL DEFAULT FALSE,
  status status_type NOT NULL DEFAULT 'pending',
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
