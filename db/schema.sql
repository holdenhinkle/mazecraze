CREATE TABLE maze_formulas (
  id serial PRIMARY KEY,
  maze_type text NOT NULL,
  width integer NOT NULL,
  height integer NOT NULL,
  endpoints integer NOT NULL,
  barriers integer NOT NULL,
  tunnels integer NOT NULL,
  portals integer NOT NULL,
  experiment boolean NOT NULL default false,
  pending boolean NOT NULL default true,
  approved boolean NOT NULL DEFAULT false
);