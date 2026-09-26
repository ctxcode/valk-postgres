# valk-postgres

A package to query PostgreSQL databases. The package is purely written in Valk and has no os-package dependencies.

Requires Valk 0.7.5 or newer.

API documentation: [docs/api.md](docs/api.md), [docs/api-full.md](docs/api-full.md).

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
let users = db.fetch_all() ! panic("Error: %{E.message}")

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
- Single statement queries are prepared and cached.
- SSL: pass `postgres.SslMode.disable`, `prefer` (default), `require` or `verify_full` as the last argument of `connect`. `connect_with` takes a `postgres.SslOptions` instead, which adds a CA file for the server certificate and a client certificate for servers that ask for one.

## Notifications

A connection that ran `LISTEN channel` collects what other sessions send with `NOTIFY`, and
`wait_notification` waits for the next one. It returns null when none arrives within the timeout
(0 waits forever), and inside a coroutine only that coroutine waits:

```rust
db.query("LISTEN jobs") ! panic("%{E.message}")
while true {
    let job = db.wait_notification(30_000) ! panic("%{E.message}")
    if isset(job) : println("new job: " + job.payload)
}
```

Notifications that arrive while other queries run are kept in `db.notifications` until
`wait_notification` hands them out.

## Bulk import and export

`COPY` moves many rows at once, far faster than an `INSERT` per row:

```rust
// Rows of values; null stores NULL
db.copy_rows("users", .{ "name", "age" }, .{ .{ "Ada", 36 }, .{ "Bob", null } }) ! panic("%{E.message}")

// A CSV file straight into a table
let file = fs.stream("users.csv") ! panic("cannot open the file")
db.copy_in("COPY users (name, age) FROM STDIN (FORMAT csv, HEADER)", file) ! panic("%{E.message}")

// A query out to any writer
let out = ByteBuffer.new()
db.copy_out("COPY (SELECT name, age FROM users) TO STDOUT (FORMAT csv, HEADER)", out) ! panic("%{E.message}")
```

Each returns the number of rows. When a row is malformed or reading the input fails, the copy is
called off and none of its rows are kept.

## With valk-sql

`postgres.database(con)` turns a connection into a `sql.Db` of the
[valk-sql](https://github.com/ctxcode/valk-sql) package, which gives every database the same
API: a query builder, migrations, connection pools, and rows read into your own classes. The
same program then runs on another database by opening it with that driver instead.

```rust
use sql
use postgres

let db = postgres.database(postgres.connect("127.0.0.1", "user", "password", "app") ! panic("%{E.message}"))
db.exec("INSERT INTO users (name, age) VALUES (:name, :age)", .{ "name" => "Ada", "age" => 36 }) ! panic("%{E.message}")
let rows = db.all("SELECT * FROM users WHERE age > :age", .{ "age" => 18 }) ! panic("%{E.message}")
```

The connection's own API stays available next to it.

## Development

`make deps` fetches the `valk-sql` package the `database()` adapter needs; the tests build
against it from `vendor/`.

`./tests/servers.sh up` starts the PostgreSQL containers the tests use (Docker), `make test` runs the tests
and `./tests/servers.sh down` removes the containers. `make example` builds and runs the local example.
Override the compiler with `make vc=/path/to/valk test`. `make docs` regenerates the API
documentation in `docs/api.md` (signatures) and `docs/api-full.md` (with descriptions).

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
