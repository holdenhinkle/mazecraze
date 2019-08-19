CREATE TYPE worker_status AS ENUM ('alive', 'dead');

CREATE TABLE background_workers (
  id serial PRIMARY KEY,
  status worker_status DEFAULT 'alive',
  created timestamp NOT NULL DEFAULT NOW(),
  updated timestamp NOT NULL DEFAULT NOW()
);

CREATE TYPE thread_status AS ENUM ('alive', 'dead');

CREATE TABLE background_threads (
  id serial PRIMARY KEY,
  background_worker_id integer NOT NULL REFERENCES background_workers(id),
  status thread_status NOT NULL DEFAULT 'alive',
  created timestamp NOT NULL DEFAULT NOW(),
  updated timestamp NOT NULL DEFAULT NOW()
);

CREATE TYPE job_type AS ENUM ('generate_maze_formulas', 'generate_set_permutations', 'generate_mazes');

CREATE TYPE job_status AS ENUM ('queued', 'running', 'completed');

CREATE TABLE background_jobs (
  id serial PRIMARY KEY,
  queue_order integer,
  background_worker_id integer REFERENCES background_workers(id),
  background_thread_id integer REFERENCES background_threads(id),
  job_type job_type NOT NULL,
  params text NOT NULL,
  status job_status NOT NULL DEFAULT 'queued',
  created timestamp NOT NULL DEFAULT NOW(),
  updated timestamp NOT NULL DEFAULT NOW(),
  start_time timestamp,
  finish_time timestamp
);

CREATE TYPE formula_status AS ENUM ('pending', 'completed', 'queued');

CREATE TABLE maze_formulas (
  id serial PRIMARY KEY,
  background_job_id integer REFERENCES background_jobs(id) ON DELETE CASCADE,
  maze_type text NOT NULL,
  set text NOT NULL,
  x integer NOT NULL CHECK (x > 0),
  y integer NOT NULL CHECK (y > 0),
  endpoints integer NOT NULL CHECK (endpoints > 0),
  barriers integer NOT NULL DEFAULT 0 CHECK (barriers > -1),
  bridges integer CHECK (bridges > 0),
  tunnels integer CHECK (tunnels > 0),
  portals integer CHECK (portals > 0),
  experiment boolean NOT NULL DEFAULT FALSE,
  status formula_status NOT NULL DEFAULT 'pending',
  created timestamp NOT NULL DEFAULT NOW(),
  updated timestamp NOT NULL DEFAULT NOW()
);

CREATE TYPE permutation_status AS ENUM ('pending', 'completed', 'queued');

CREATE TABLE set_permutations (
  id serial PRIMARY KEY,
  background_job_id integer NOT NULL REFERENCES background_jobs(id) ON DELETE CASCADE,
  maze_formula_id integer NOT NULL REFERENCES maze_formulas(id) ON DELETE CASCADE,
  permutation text NOT NULL,
  status permutation_status NOT NULL DEFAULT 'pending',
  created timestamp NOT NULL DEFAULT NOW(),
  updated timestamp NOT NULL DEFAULT NOW()
);

CREATE TYPE variation AS ENUM ('original', 'rotated_90_degrees', 'rotated_180_degrees', 'rotated_270_degrees', 'flipped_vertically', 'flipped_horizontally');

CREATE TABLE mazes (
  id serial PRIMARY KEY,
  background_job_id integer NOT NULL REFERENCES background_jobs(id) ON DELETE CASCADE,
  set_permutation_id integer NOT NULL REFERENCES set_permutations(id) ON DELETE CASCADE,
  number_of_solutions integer NOT NULL,
  solutions text NOT NULL,
  -- variation text NOT NULL,
  variation text,
  created timestamp NOT NULL DEFAULT NOW(),
  updated timestamp NOT NULL DEFAULT NOW()
);

CREATE TABLE admin_notifications (
  id serial PRIMARY KEY,
  notification TEXT NOT NULL,
  delivered BOOLEAN NOT NULL DEFAULT FALSE,
  created timestamp NOT NULL DEFAULT NOW(),
  updated timestamp NOT NULL DEFAULT NOW()
);

CREATE TABLE settings (
  id serial PRIMARY KEY,
  name text NOT NULL,
  integer_value integer,
  decimal_value decimal,
  text_value text,
  created timestamp NOT NULL DEFAULT NOW(),
  updated timestamp NOT NULL DEFAULT NOW()
);

INSERT INTO settings (name, integer_value) 
  VALUES
    ('number_of_threads', 1),
    ('simple_formula_x_min', 3),
    ('simple_formula_x_max', 10),
    ('simple_formula_y_min', 2),
    ('simple_formula_y_max', 10),
    ('simple_formula_endpoint_min', 1),
    ('simple_formula_endpoint_max', 4),
    ('simple_formula_barrier_min', 0),
    ('simple_formula_barrier_max', 3),
    ('bridge_formula_x_min', 3),
    ('bridge_formula_x_max', 11),
    ('bridge_formula_y_min', 2),
    ('bridge_formula_y_max', 11),
    ('bridge_formula_endpoint_min', 1),
    ('bridge_formula_endpoint_max', 5),
    ('bridge_formula_barrier_min', 0),
    ('bridge_formula_barrier_max', 4),
    ('bridge_formula_bridge_min', 1),
    ('bridge_formula_bridge_max', 4),
    ('tunnel_formula_x_min', 3),
    ('tunnel_formula_x_max', 12),
    ('tunnel_formula_y_min', 2),
    ('tunnel_formula_y_max', 12),
    ('tunnel_formula_endpoint_min', 1),
    ('tunnel_formula_endpoint_max', 6),
    ('tunnel_formula_barrier_min', 0),
    ('tunnel_formula_barrier_max', 5),
    ('tunnel_formula_tunnel_min', 1),
    ('tunnel_formula_tunnel_max', 5),
    ('portal_formula_x_min', 3),
    ('portal_formula_x_max', 13),
    ('portal_formula_y_min', 2),
    ('portal_formula_y_max', 13),
    ('portal_formula_endpoint_min', 1),
    ('portal_formula_endpoint_max', 7),
    ('portal_formula_barrier_min', 0),
    ('portal_formula_barrier_max', 6),
    ('portal_formula_portal_min', 1),
    ('portal_formula_portal_max', 6)
;

INSERT INTO settings (name, decimal_value) 
  VALUES
    ('simple_formula_other_squares_to_normal_squares_ratio', .5),
    ('bridge_formula_other_squares_to_normal_squares_ratio', .5),
    ('tunnel_formula_other_squares_to_normal_squares_ratio', .5),
    ('portal_formula_other_squares_to_normal_squares_ratio', .5)
;