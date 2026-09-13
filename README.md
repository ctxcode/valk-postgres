# valk-postgres

A package to query PostgreSQL databases. The package is purely written in Valk: the wire
protocol, MD5 and SCRAM-SHA-256 authentication and SSL are built on the Valk standard
library, without any native library (`.so` / `.dll`) dependencies.

Requires Valk 0.7.0 or newer. Works with PostgreSQL 10 and newer (protocol 3.0).

## Install

```
vman install github.com/ctxcode/valk-postgres
```

## Example

```rust
use postgres

// Connect (port defaults to 5432, SSL is used when the server supports it)
let db = postgres.connect("127.0.0.1", "user", "password", "dbname") ! panic("Failed to connect: %{E.message}")
defer db.close()

// Run a query with named parameters
db.query("UPDATE users SET name = :name WHERE id = :id", .{ "name" => "test", "id" => 1 }) ! panic("Error: %{E.message}")
println("Updated rows: " + db.affected_rows)

// Bind early
db.bind("name", "test")
db.query("UPDATE users SET name = :name WHERE id = :id", .{ "id" => 1 }) ! panic("Error: %{E.message}")

// Positional parameters
db.bindv("test")
db.bindv(10)
db.query("UPDATE users SET name = ? WHERE id = ?") ! panic("Error: %{E.message}")

// Native $1 placeholders work as well
db.bindv(10)
db.query("SELECT * FROM users WHERE id = $1") ! panic("Error: %{E.message}")

// Arrays expand into a list: WHERE id IN ($1,$2,$3)
db.query("SELECT * FROM users WHERE id IN (:ids)", .{ "ids" => Array[int]{ 1, 2, 3 } }) ! panic("Error: %{E.message}")

// Fetch 1-by-1
let user : Map[postgres.Value] = .{}
while db.fetch_row(user) ! panic("Error: %{E.message}") {
    println("name: " + (user["name"] ?? "/"))
}

// Fetch all
db.query("SELECT * FROM users WHERE id > :id", .{ "id" => 10 }) ! panic("Error: %{E.message}")
let users = db.fetch_all() ! panic("Error: %{E.message}")

// Fetch one row (the rest is discarded)
db.query("INSERT INTO users (name) VALUES (:name) RETURNING id", .{ "name" => "new" }) ! panic("Error: %{E.message}")
let row = db.fetch_one() ! panic("Error: %{E.message}")
if isset(row) : println("Inserted id: " + (row["id"] ?? 0).to_int())

// Transactions
db.begin() ! panic("Error: %{E.message}")
db.query("DELETE FROM users WHERE id = :id", .{ "id" => 1 }) ! panic("Error: %{E.message}")
db.commit() ! panic("Error: %{E.message}")
```

### Parameters

`:name` and `?` placeholders are rewritten into PostgreSQL's `$1`, `$2`, ... and the values
are sent separately from the query text, so they never need escaping. Values are sent as
text without a declared type; the server infers the type from where the placeholder is used.
Where the context does not determine a type (for example `SELECT :value`), add a cast:
`SELECT :value::int`.

- `:name` takes its value from `bind` or the map passed to `query`. An array bound to a
  name expands into a comma separated list, for `IN (:ids)`.
- `?` takes the next value from `bindv`. `?` is only treated as a placeholder when values
  were bound with `bindv`, so the jsonb `?` operators keep working otherwise.
- `bindv` values not consumed by `?` are bound to `$1`, `$2`, ... in order. An array bound
  this way is sent as a PostgreSQL array literal, for `= ANY($1::int[])`.
- Text in single or double quotes, dollar quoted text, comments and `::` casts are left alone.

Queries with bound values use the extended protocol and are prepared once per connection;
the prepared statements are cached (`statement_cache_size`, 64 by default). Queries without
bound values are sent as simple queries and may contain several statements separated by `;`.
The rows of every statement are fetched in order.

### Values

Each row is a `Map[postgres.Value]` keyed by column name. Integer columns (`smallint`,
`integer`, `bigint`, `oid`) become `int` values, `real` / `double precision` columns `float`
values, `boolean` columns `bool` values and every other type (`text`, `numeric`, dates and
timestamps, `json`, `uuid`, `bytea`, arrays, ...) keeps the text the server sent. Use
`to_int()`, `to_float()`, `to_bool()`, `to_string()`, `to_json()` and `to_bytes()` (for
`bytea`) to convert, or the `to_*_or_null()` variants when the column may be `NULL`.

`convert(value)` turns integers, floats, bools, strings, `json.Value`s, arrays of those and
nullable values into a `postgres.Value` for binding.

### Results and status

- `affected_rows`: rows affected by the last completed command. For a `SELECT` it is the
  row count, known once all rows have been fetched. Use `RETURNING` to get generated ids.
- `command_tag`: the tag of the last completed command, such as `INSERT 0 1`.
- `in_transaction()` and `transaction_status` (`'I'` idle, `'T'` in a transaction, `'E'` in
  a failed transaction that must be rolled back).
- `parameters`: the runtime parameters reported by the server (`server_version`,
  `TimeZone`, ...); `server_version()` is a shortcut.
- `notifications`: notifications received through `LISTEN`; `last_notice`: the message of
  the last `NOTICE` / `WARNING`.

### Errors

Every method throws `postgres.Error`. A `.error` comes from the server and carries the
SQLSTATE in `E.sqlstate` (for example `23505` for a unique violation) with `E.message`,
`E.detail` and `E.hint`. After an error the connection is ready for the next query; inside
a transaction a `rollback()` is required first. Other codes: `.connect`, `.ssl`, `.auth`,
`.unsupported`, `.protocol` and `.closed`.

### SSL

```rust
let db = postgres.connect(host, user, password, db, 5432, postgres.SslMode.require) !> 
```

`SslMode.prefer` (the default) uses SSL when the server supports it, `disable` never does,
`require` fails without SSL and `verify_full` also verifies the server certificate against
the system CA store and the host name.

### Not implemented

`COPY`, the binary result format, SASLprep of non-ASCII passwords, SCRAM channel binding
and GSSAPI / Kerberos authentication.

## Development

`./tests/servers.sh up` starts three PostgreSQL 16 containers with Docker (user `test`,
password `root`, database `valk_postgres_tests`): SCRAM-SHA-256 on `127.0.0.1:5432`, md5 on
`5433` and SCRAM-SHA-256 over SSL with a self-signed certificate on `5434`. `make test` runs
the integration tests against them, `make example` builds and runs the local example and
`./tests/servers.sh down` removes the containers. Override the compiler with
`make vc=/path/to/valk test`.
