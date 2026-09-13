# valk-postgres

A package to query PostgreSQL databases. The package is purely written in Valk and has no os-package dependencies.

Requires Valk 0.7.0 or newer.

## Install

```
vman install github.com/ctxcode/valk-postgres
```

## Example

```rust
// Init
let db = postgres.connect("127.0.0.1", "user", "password", "dbname", 5432) ! panic("Failed to connect: %{E.message}")
defer db.close()

// Run query + parameters
db.query("UPDATE users SET name = :name WHERE id = :id", .{ "name" => "test", "id" => 1 }) ! panic("Error: %{E.message}")

// Bind early
db.bind("name", "test")
db.query("UPDATE users SET name = :name WHERE id = :id", .{ "id" => 1 }) ! panic("Error: %{E.message}")

// Nameless parameters
db.bindv("test")
db.bindv(10)
db.query("UPDATE users SET name = ? WHERE id = ?") ! panic("Error: %{E.message}")

// Select
db.query("SELECT * FROM users WHERE id > :id", .{ "id" => 10 }) ! panic("Error: %{E.message}")

// Fetch 1-by-1
let user : Map[postgres.Value] = .{}
while db.fetch_row(user) ! panic("Error: %{E.message}") {
    println("name: " + (user["name"] ?? "/"))
}

// Fetch all
let users = db.fetch_all() ! { assert(false) return }

// Fetch one
db.query("INSERT INTO users (name) VALUES (:name) RETURNING id", .{ "name" => "new" }) ! panic("Error: %{E.message}")
let row = db.fetch_one() ! panic("Error: %{E.message}")

// Transactions
db.begin() ! panic("Error: %{E.message}")
db.commit() ! panic("Error: %{E.message}")

// Fetch without allocations: values are read straight from the receive buffer
db.query("SELECT id, name FROM users") ! panic("Error: %{E.message}")
while db.next_row() ! panic("Error: %{E.message}") {
    let id = db.col_int(0)
    let name = db.col_string(1) // or db.col_view(1) for a &[u8] that lives until the next row
}
```

Notes:

- `:name` and `?` become `$1`, `$2`, ... and the values are sent separately. Add a cast where the server cannot infer the type: `SELECT :value::int`.
- An array bound to `:name` expands into a list: `WHERE id IN (:ids)`.
- `affected_rows` holds the row count of the last command. Use `RETURNING` for generated ids.
- Server errors carry the SQLSTATE in `E.sqlstate`.
- Single statement queries are prepared and cached. From their second run, integers, floats, bools, dates and timestamps arrive in binary form, which is faster; the values you see are the same.
- SSL: pass `postgres.SslMode.disable`, `prefer` (default), `require` or `verify_full` as the last argument of `connect`.

## Development

`./tests/servers.sh up` starts the PostgreSQL containers the tests use (Docker), `make test` runs the tests
and `./tests/servers.sh down` removes the containers. `make example` builds and runs the local example.
Override the compiler with `make vc=/path/to/valk test`.

## Benchmark

`./bench/run.sh` runs the same scenarios in Valk, Go (pgx) and Rust (tokio-postgres) on one connection.
Operations per second, local PostgreSQL 16:

| scenario              | valk      | go        | rust      |
| --------------------- | --------- | --------- | --------- |
| ping                  | 40,300    | 35,300    | 36,800    |
| select_by_id          | 26,600    | 24,900    | 27,800    |
| fetch_rows            | 4,620,000 | 5,410,000 | 4,920,000 |
| fetch_rows (fast api) | 6,270,000 | -         | -         |
| insert                | 35,900    | 32,300    | 34,800    |
