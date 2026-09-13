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
```

Notes:

- `:name` and `?` become `$1`, `$2`, ... and the values are sent separately. Add a cast where the server cannot infer the type: `SELECT :value::int`.
- An array bound to `:name` expands into a list: `WHERE id IN (:ids)`.
- `affected_rows` holds the row count of the last command. Use `RETURNING` for generated ids.
- Server errors carry the SQLSTATE in `E.sqlstate`.
- SSL: pass `postgres.SslMode.disable`, `prefer` (default), `require` or `verify_full` as the last argument of `connect`.

## Development

`./tests/servers.sh up` starts the PostgreSQL containers the tests use (Docker), `make test` runs the tests
and `./tests/servers.sh down` removes the containers. `make example` builds and runs the local example.
Override the compiler with `make vc=/path/to/valk test`.

## Benchmark

`./bench/run.sh` runs the same scenarios in Valk, Go (pgx) and Rust (tokio-postgres) on one connection.
Operations per second, local PostgreSQL 16:

| scenario     | valk      | go        | rust      |
| ------------ | --------- | --------- | --------- |
| ping         | 31,400    | 28,100    | 28,000    |
| select_by_id | 22,200    | 19,300    | 19,900    |
| fetch_rows   | 2,940,000 | 5,400,000 | 4,500,000 |
| insert       | 28,600    | 23,500    | 26,500    |
