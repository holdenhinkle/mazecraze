CREATE TYPE status_type AS ENUM ('pending', 'approved', 'rejected');

CREATE TABLE maze_formulas (
  id serial PRIMARY KEY,
  maze_type text NOT NULL,
  width integer NOT NULL CHECK (width > 0),
  height integer NOT NULL CHECK (height > 0),
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
  